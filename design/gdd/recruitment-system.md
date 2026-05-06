# Recruitment System

**Status**: Authored (Sprint 11 S11-X3 — first design pass, 2026-05-05)
**Layer**: Feature (rank 12)
**Owners**: game-designer (cost-curve calibration + cozy pacing) + economy-designer (gold-spend transaction surface) + gameplay-programmer (orchestration code)
**Last Verified**: 2026-05-05

---

## A. Overview

The Recruitment System orchestrates the gold-spend → roster-add transaction that lets the player acquire new heroes between dungeon runs. It is a **thin coordinator** — the actual money is in `Economy.try_spend`, the actual roster mutation is in `HeroRoster.add_hero`, and the actual cost-curve math is in `Economy.recruit_cost`. This system's job is to (a) own the **recruit pool** (the set of class_ids currently offered to the player), (b) atomically chain the cost-lookup → spend → add-hero sequence so partial failures cannot leak (e.g., gold spent but hero not added), and (c) emit the `hero_recruited` signal that UI + telemetry subscribers consume.

The recruit pool generation strategy is **NOT locked in this GDD** — Sprint 12+ implementation depends on **ADR-X04 (Recruitment pool generation determinism)** authoring first. ADR-X04 must answer three questions: (1) is the pool RNG-seeded from save state (replayable across save-load) or session-only; (2) what refresh cadence triggers a pool roll (per-clear? per-day? on-demand?); (3) how does the cost curve interact with the pool (does each pool slot have an independent `copies_owned` count, or is `copies_owned` a global counter per class_id?). This GDD surfaces those questions as OPEN QUESTIONS §I.1–§I.3 with concrete tradeoff analysis; ADR-X04 picks one option and locks it.

For MVP scope, this GDD covers:
- The orchestrator pattern + atomic transaction discipline.
- The `try_recruit(pool_index)` public API + `RecruitOutcome` enum.
- The `hero_recruited` signal contract.
- Save/Load consumer surface (deferred — empty payload until ADR-X04 picks the determinism strategy).
- Failure-path semantics (insufficient gold, roster full, unresolvable class_id).
- The CI grep contract: `HeroRoster.add_hero` has exactly one production caller — Recruitment.

---

## B. Player Fantasy

Recruitment is the **growth surface** of the game. Per the game-concept §3 ("Roster Recruitment & Leveling — spend loot to recruit new classes and level existing heroes"), it's where accumulated gold turns into roster expansion. The fantasy is:

1. **Anticipation, not anxiety.** When the player opens the recruit screen, they see what's available, see what each hero costs, and make a *decision* — not a *gamble*. The cost curve is deterministic per ADR-0013 (`recruit_cost(class_id, copies_owned)` is a closed-form function); a pool slot's cost does not change between when the player sees it and when they tap "recruit." This protects against the cozy-incompatible "the game changed the price on me" feeling.

2. **No gachapon.** The pool itself may be randomly generated (ADR-X04 OPEN QUESTION), but per Pillar 1 commitment to no fail state, the player NEVER pays gold for an unknown outcome. They see the class. They see the cost. They tap. The hero arrives. There is no "loot-box reveal" delay between spend and outcome.

3. **Ownership progression.** The cost curve scales with `copies_owned` per ADR-0013 — the second Warrior costs more than the first. This expresses the player-fantasy that "your guild is becoming famous; rare classes don't double-up easily." The math is visible in the UI; the player can plan around it.

4. **Reward, not punishment.** Insufficient-gold failure shows a soft message ("Save up XYZ more gold for this hero") with no penalty. Roster-full failure shows the same shape. The system NEVER takes gold without delivering a hero — that's the atomic-transaction discipline §C.4.

The system is intentionally narrow scope. The fantasy is owned by the screen UX (Sprint 12+ — recruit-screen.tscn / recruit-screen.gd not yet implemented); this GDD codifies the contracts that protect the screen's cozy promise from regressing.

---

## C. Detailed Rules

### C.1 Public API surface

Per `architecture.md` §Recruitment (rank 12) + ADR-0013 cost-curve contract:

```gdscript
class_name Recruitment extends Node

# ---------------------------------------------------------------------------
# Public types
# ---------------------------------------------------------------------------

## Outcome of a try_recruit() attempt. Maps the failure-path taxonomy from
## §C.4 (atomic transaction discipline) to a single returned enum.
enum RecruitOutcome {
	SUCCESS,                  # Gold spent, hero added, signal emitted.
	INSUFFICIENT_GOLD,        # Economy.try_spend returned false; no mutations.
	ROSTER_FULL,              # HeroRoster.max_roster_size reached; no spend, no add.
	INVALID_POOL_INDEX,       # pool_index out of range; no mutations.
	UNRESOLVABLE_CLASS_ID,    # DataRegistry.resolve("classes", id) returned null;
	                           # no mutations. Signals authoring bug, not player error.
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Atomic recruit transaction. Validates → looks up cost → spends gold via
## Economy.try_spend → adds hero via HeroRoster.add_hero → emits
## hero_recruited. Each step is gated; failure at any step returns the
## corresponding RecruitOutcome and performs ZERO mutations after the
## failure point.
##
## [param pool_index]: 0-based index into the current recruit pool. Caller
##   (recruit screen) supplies the index of the row the player tapped.
##
## Returns: RecruitOutcome enum value.
##
## ADR-0013 §recruit_cost contract; this GDD §C.4 atomic transaction.
func try_recruit(pool_index: int) -> RecruitOutcome

## Returns the current recruit pool as an Array[String] of class_ids. The
## screen reads this to render rows. Order matters: the pool's index is
## the same as the pool_index argument to try_recruit.
##
## Pool generation determinism is NOT locked in this GDD — see §I.1.
## Sprint 12+ ADR-X04 authoring picks the strategy. Pre-ADR-X04, this
## method's behavior is undefined.
func get_recruit_pool() -> Array[String]

## Returns the cost (in gold) for the recruit at pool_index. Read-side
## convenience for screen UI — equivalent to:
##   Economy.recruit_cost(get_recruit_pool()[pool_index],
##                        HeroRoster.get_copies_owned(class_id))
## but routed through this system so the screen has a single API surface
## for "what's the cost for this row."
##
## Returns -1 for invalid pool_index OR if the pool entry is unresolvable.
func get_recruit_cost(pool_index: int) -> int

## Forces a pool refresh. Sprint 12+ ADR-X04 picks the trigger semantics
## (per-clear / per-day / on-demand). MVP exposure as a public method
## supports debug/QA + future cadence work without API changes.
##
## Idempotent: calling twice in a row produces the same pool (per
## determinism strategy from ADR-X04).
func refresh_pool() -> void

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted on successful recruit. Subscribers: RecruitScreen (refresh row
## states), Telemetry (recruit-event tracking), V1.0 Roster Detail screen
## (highlight newly-added hero).
##
## Order of operations within try_recruit(): Economy.try_spend completes →
## HeroRoster.add_hero completes → THIS signal emits. By the time
## subscribers handle this signal, gold balance is reduced AND the new
## hero exists in the roster.
##
## [param hero_instance_id]: The instance_id assigned by HeroRoster
##   (HeroInstance allocates a fresh id on add_hero). Subscribers can
##   resolve via HeroRoster.get_hero(instance_id) for the full HeroInstance.
## [param class_id]: The class_id that was recruited (mirrors the value
##   from the recruit pool entry).
## [param cost_paid]: The actual gold amount deducted (matches what
##   Economy.recruit_cost returned at try_spend time — caller-side value).
signal hero_recruited(hero_instance_id: int, class_id: String, cost_paid: int)

## Emitted when the recruit pool is refreshed (initial generation,
## refresh_pool() call, ADR-X04 cadence trigger). Subscribers: RecruitScreen
## (re-render rows), Telemetry. The new pool is provided in the payload so
## subscribers don't need a redundant get_recruit_pool() call.
##
## Sprint 12+ implementation may also fire this on initial pool seeding
## at boot (after _ready loads from save or generates fresh).
signal pool_refreshed(new_pool: Array[String])
```

### C.2 Pool ownership

The recruit pool is a `Array[String]` of class_ids that the player can recruit. **The pool is OWNED by this system** — neither HeroClassDatabase (which is a static catalog) nor HeroRoster (which holds *recruited* heroes) holds it.

Pool size + composition + refresh cadence + RNG-determinism are ALL ADR-X04-pending. This GDD locks ONLY:
- The pool is an `Array[String]` (not a more complex shape).
- Each entry is a `class_id` resolvable via `DataRegistry.resolve("classes", id)`.
- The pool's index ordering is stable until the next `pool_refreshed` signal — i.e., between two refresh events, `get_recruit_pool()[i]` returns the same class_id every call.
- The pool is exposed as a snapshot via `get_recruit_pool()` — mutations to the returned Array do NOT mutate internal state (the system returns a copy or duplicates).

### C.3 Recruitment transaction flow

```
try_recruit(pool_index):
  STEP 0: Validate pool_index in [0, pool.size())
    fail → return INVALID_POOL_INDEX (no mutations)

  STEP 1: Resolve class_id via the pool entry
    var class_id: String = pool[pool_index]
    Resolve via DataRegistry.resolve("classes", class_id)
    fail (null) → return UNRESOLVABLE_CLASS_ID (no mutations)

  STEP 2: Roster-capacity check
    if HeroRoster.get_all_heroes().size() >= HeroRoster.max_roster_size():
      return ROSTER_FULL (no spend, no add)

  STEP 3: Cost lookup
    var copies_owned: int = HeroRoster.get_copies_owned(class_id)  // helper §F
    var cost: int = Economy.recruit_cost(class_id, copies_owned)
    if cost < 0: return UNRESOLVABLE_CLASS_ID  // ADR-0013 sentinel
                                                 // (defensive — should match
                                                 // STEP 1 outcome)

  STEP 4: Atomic transaction
    var spend_ok: bool = Economy.try_spend(cost, "recruit_" + class_id)
    if not spend_ok:
      return INSUFFICIENT_GOLD  // Gold balance unchanged, no add.

    var instance: RefCounted = HeroRoster.add_hero(class_id)
    if instance == null:
      // CRITICAL: gold was spent but hero was not added.
      // This is a contract violation by HeroRoster — add_hero is supposed
      // to succeed if max_roster_size was not exceeded (we already checked
      // STEP 2). Refund + push_error.
      Economy.add_gold(cost, "recruit_refund_" + class_id)
      push_error("[Recruitment] HeroRoster.add_hero returned null after
                  capacity check passed — refunding cost. CONTRACT BUG.")
      return UNRESOLVABLE_CLASS_ID  // Closest non-success outcome.

  STEP 5: Emit signal
    hero_recruited.emit(instance.instance_id, class_id, cost)

  return SUCCESS
```

The rules-as-prose in §C.3 above are mirrored in §H AC-RC-04 through AC-RC-08 — those ACs are the test contract for each step's failure mode.

### C.4 Atomic transaction discipline

The transaction MUST be atomic in the player-perceived sense: either gold AND hero both arrive, OR neither does. Partial states (gold spent, hero not added; hero added, gold not spent) are FORBIDDEN. The §C.3 flow has three guard layers:

1. **Pre-spend validation** (Steps 0–3): all checks that can fail without mutating state run before any mutation.
2. **Post-spend rollback** (Step 4 secondary path): if `add_hero` fails after `try_spend` succeeded — the contract violation case — Recruitment refunds via `Economy.add_gold(cost, "recruit_refund_*")`. This is the only place in production code that legitimately calls `Economy.add_gold` with a refund reason; CI grep enforces.
3. **Ordering**: signal emission is the LAST step. Subscribers see post-mutation state.

### C.5 Single-writer enforcement (HeroRoster.add_hero contract)

Per `hero-roster.md` §C, `add_hero(class_id)` is the canonical recruit-side mutation method. This GDD enforces that **Recruitment.try_recruit is the only production caller of `HeroRoster.add_hero`** outside of HeroRoster's own `seed_first_launch_state()` (Sprint 6 tutorial Warrior seeding) and test fixtures.

CI grep enforces: production code (excluding tests + `seed_first_launch_state` + `add_hero` itself) must contain at most ONE `HeroRoster.add_hero(` call site, located in `src/core/recruitment/recruitment.gd`. Forbidden-pattern entry: `add_hero_outside_recruitment` (added to ADR-0003 forbidden-patterns registry alongside `formation_slot_write_outside_formation_assignment` from S11-X2).

### C.6 Save/Load consumer surface (MVP: deferred)

Recruitment is in `SaveLoadSystem.CONSUMER_PATHS` (rank-12 slot). The persisted state depends entirely on ADR-X04's pool determinism choice:

- **Option A (session-only pool)**: pool is regenerated fresh on every load. `get_save_data() → {}` empty. Load is a no-op.
- **Option B (deterministic / replayable pool)**: pool RNG seed is persisted. `get_save_data() → {"rng_seed": int, "refresh_state": Dictionary}`. Load restores seed + replays the deterministic pool.
- **Option C (hybrid)**: cost-curve `copies_owned` snapshots persist (for cost stability across reload), pool itself regenerates from current roster state.

MVP scope: implement Option A (session-only pool, empty save payload) so the consumer-contract surface is satisfied. ADR-X04 picking Option B/C is a Sprint 13+ migration with additive schema (existing empty payloads load as "no persisted pool state" without a version bump).

```gdscript
# MVP — Option A:
func get_save_data() -> Dictionary:
	return {}

func load_save_data(d: Dictionary) -> void:
	# No-op in MVP. Sprint 13+ ADR-X04 may extend this.
	pass
```

---

## D. Formulas

### D.1 Cost lookup (delegates to Economy)

This system has no math of its own. The cost curve lives in `Economy.recruit_cost(class_id, copies_owned)` per ADR-0013 §recruit_cost:

```
cost = recruit_cost(class_id, copies_owned)
     = ECONOMY_BASE_RECRUIT_COST_PER_TIER[tier] * (1 + COPIES_OWNED_MULT * copies_owned)
```

where `tier = DataRegistry.resolve("classes", class_id).tier` per ADR-0006 / ADR-0011 (Economy resolves internally).

Recruitment's `get_recruit_cost(pool_index)` is a thin wrapper that supplies the `copies_owned` argument from `HeroRoster.get_copies_owned(class_id)`.

### D.2 Pool composition strategy (ADR-X04-pending)

ADR-X04 picks one of three candidate strategies (and refines the parameters):

**Candidate 1: "Always all classes available"**: pool is the full Array[String] of `status="active"` classes from HeroClassDatabase. Static pool, zero RNG, simplest possible. Cost curve via `copies_owned` is the gating mechanism. Refresh cadence is irrelevant.

**Candidate 2: "Random N-of-M with refresh"**: pool is N random classes (e.g., N=3) drawn from active classes. Refreshed on a cadence (per-clear, per-day, or via in-game refresh-button cost). RNG is seeded from save state for replayability OR session-only for variety. ADR-X04 picks N + cadence + seed strategy.

**Candidate 3: "Tier-rotation pool"**: pool is curated to span the available tiers (e.g., always 1 of each tier the player has unlocked). Less RNG, more designed pacing.

This GDD does NOT recommend a candidate — the pacing/cost-curve interplay is a design-pass concern that requires playtest data. ADR-X04 authoring is the gating step.

### D.3 Refresh cadence (ADR-X04-pending)

Three candidate cadences:

- **On dungeon-clear**: `floor_cleared_first_time` signal triggers refresh. Pool changes feel earned; ties to gameplay loop.
- **On real-time interval**: `heartbeat` or daily timer. Pool changes feel "new shop arrived"; cozy-game register.
- **On-demand**: player presses a refresh button (free or for gold). Pool changes feel agentic; player drives the loop.

ADR-X04 may pick one OR offer multiple (e.g., free per-clear refresh + paid on-demand refresh).

---

## E. Edge Cases

### E.1 try_recruit during ROSTER_FULL state

Returns `ROSTER_FULL` outcome. No spend, no add, no signal. The screen UI should disable the recruit buttons when `HeroRoster.get_all_heroes().size() >= HeroRoster.max_roster_size()` so this branch is a defensive guard, not a normal player-facing failure path.

### E.2 try_recruit with insufficient gold

Returns `INSUFFICIENT_GOLD`. Economy.try_spend returns false; no Economy state change; no roster mutation; no signal. The screen shows soft message ("Save up X more gold").

### E.3 try_recruit with corrupt pool entry (unresolvable class_id)

Returns `UNRESOLVABLE_CLASS_ID`. `DataRegistry.resolve("classes", id)` returned null. This is an authoring bug (or save corruption / content patch removed the class). No mutations; push_error logged so QA + telemetry catch it.

### E.4 try_recruit with invalid pool_index

Returns `INVALID_POOL_INDEX`. Index out of range for current pool. No mutations. push_warning logged (caller bug — screen wired to wrong index).

### E.5 try_recruit succeeds but signal listener throws

Godot signal emission propagates exceptions from listeners. Recruitment's own state (gold spent, hero added) is already committed by the time the signal fires; a listener exception does NOT roll back the transaction. This is correct behavior — the listener is a downstream consumer (UI, telemetry); its failure should not corrupt the gameplay state.

### E.6 Pool refresh during in-flight try_recruit

Recruitment is single-threaded (Godot main thread). `try_recruit` runs to completion before any other call (including a `refresh_pool` triggered by a signal handler) can begin. No race. The signal-handler-induced refresh would see post-mutation Roster state and recompute cost-stable pool entries.

### E.7 First-launch: empty roster, fresh save

`HeroRoster.seed_first_launch_state()` seeds 1 Warrior at first launch (Sprint 6 tutorial path). Recruitment's `_ready` MUST run AFTER HeroRoster's `_ready` (rank 12 > rank 7 → safe per ADR-0003). The pool is generated against the post-seed roster state.

### E.8 Save/Load with deferred-pool-strategy MVP impl

MVP `get_save_data() → {}`. On load, `load_save_data({})` is a no-op. The pool is regenerated fresh post-load (Option A semantics). When ADR-X04 picks Option B/C, the migration is additive: new save fields appear; old empty-payload saves load as "no persisted pool state" without a version bump.

### E.9 Recruitment autoload absent at boot

Per ADR-0003: missing required autoload is a fatal architecture violation. SaveLoadSystem._resolve_consumer fatals via get_tree().quit(1) when /root/Recruitment is missing. This system MUST be registered before any save persist can succeed.

### E.10 Concurrent try_recruit + refresh_pool from different signal sources

Hypothetical: a `floor_cleared_first_time` signal handler (which triggers a pool refresh per ADR-X04 Candidate 2) fires WHILE a try_recruit call is in flight. Single-threaded reasoning: signal handlers run synchronously inside the `emit()` call site; the only way refresh could fire mid-try_recruit is if try_recruit's internal calls (`Economy.try_spend`, `HeroRoster.add_hero`) emit signals whose handlers call back into `refresh_pool`. This would be a re-entrancy concern. Sprint 12+ implementation should defensively snapshot the pool entry's class_id BEFORE Step 4 (the spend), so a mid-transaction refresh that mutates the pool internal state does not affect the in-flight transaction.

---

## F. Dependencies

### Hard dependencies

| System | Why | Surface used |
|---|---|---|
| `Economy` (rank 3) | Cost curve + atomic gold-spend | `recruit_cost(class_id, copies_owned) -> int`; `try_spend(amount, reason) -> bool`; `add_gold(amount, reason) -> void` (refund path only) |
| `HeroRoster` (rank 7) | Roster mutation target + `copies_owned` lookup + capacity check | `add_hero(class_id) -> RefCounted`; `get_copies_owned(class_id) -> int` (helper to be added in Sprint 12+ alongside Recruitment impl); `get_all_heroes()`; `max_roster_size() -> int` |
| `HeroClassDatabase` (rank 4) | Class-id resolution + class metadata for pool composition | `DataRegistry.resolve("classes", id) -> Resource` (via the standard DataRegistry lookup pattern, not a HeroClassDatabase-specific method) |
| `DataRegistry` (rank 1) | The actual class-id resolver | `resolve("classes", id)` |
| `SaveLoadSystem` (rank 2) | Consumer-discovery iteration includes `/root/Recruitment` per CONSUMER_PATHS | `get_save_data() -> Dictionary`; `load_save_data(d: Dictionary) -> void` |

### Cross-system contract additions required

This GDD identifies one HeroRoster API gap that Sprint 12+ implementation will close:

- **`HeroRoster.get_copies_owned(class_id: String) -> int`** — helper that returns the count of heroes in `_heroes` whose `class_id` matches. Used by Recruitment to pass `copies_owned` to `Economy.recruit_cost`. NOT currently in hero-roster.md §C. **Adding this method is a hero-roster.md GDD update + ADR-0012 Amendment** in lockstep with Recruitment Sprint 12+ Story 1.

### Signal-source dependencies

Pre-ADR-X04: zero subscriptions in MVP. Recruitment is a pure responder to `try_recruit` calls.

Post-ADR-X04 (if Candidate 2 cadence is "on dungeon-clear"):
- Subscribe to `DungeonRunOrchestrator.floor_cleared_first_time(floor_index, biome_id, losing_run)` to trigger pool refresh.

### Reverse dependencies (subscribers of Recruitment signals)

| Signal | Subscriber | Purpose |
|---|---|---|
| `hero_recruited(instance_id, class_id, cost_paid)` | RecruitScreen (Sprint 12+ UI) | Refresh row state + gold-spent confirmation animation |
| `hero_recruited` | Telemetry (Sprint 13+) | Recruit-event tracking |
| `pool_refreshed(new_pool)` | RecruitScreen | Re-render rows |

### Bidirectional consistency

This GDD's contracts cross-reference:
- `economy-system.md` §C.3.1 + §D.3 — recruit_cost formula + try_spend contract.
- `hero-roster.md` §C — add_hero / max_roster_size / get_copies_owned (get_copies_owned is a Sprint 12+ addition flagged in §F above).
- `architecture.md` rank 12 row + Recruitment API section.
- `architecture.md` ADR-X04 row — locked at "TBD pool generation determinism + refresh cadence + cost curve interaction."
- `save-load-system.md` Rule 10 — consumer contract shape.
- `ADR-0013` — cost-curve `recruit_cost(class_id, copies_owned)` signature locked.
- `ADR-0012` — HeroRoster.add_hero mutation API.

---

## G. Tuning Knobs

### G.1 Designer-tunable (cost-curve — Owned by Economy)

This system has no cost-tuning knobs of its own. All cost-curve tuning lives in `economy_config.tres` per ADR-0013:

| Knob (Economy-owned) | Type | Default | Owner |
|---|---|---|---|
| `BASE_RECRUIT_COST_PER_TIER[1..5]` | Array[int] | per economy-system.md §D.3 | EconomyConfig.tres |
| `COPIES_OWNED_MULT` | float | per economy-system.md §D.3 | EconomyConfig.tres |

### G.2 Designer-tunable (pool — ADR-X04-pending)

Sprint 12+ ADR-X04 will add (or not) tuning knobs depending on candidate choice:

- **Candidate 1**: zero new knobs.
- **Candidate 2**: `RECRUIT_POOL_SIZE: int` (e.g., 3); `RECRUIT_REFRESH_CADENCE_TICKS: int` (e.g., per-clear); `RECRUIT_REFRESH_COST_GOLD: int` (if on-demand refresh costs gold).
- **Candidate 3**: `TIER_ROTATION_BIAS: float` (per-tier weight).

These land in a new `recruitment_config.tres` (analogous to `economy_config.tres`) when ADR-X04 picks a candidate.

### G.3 Debug/dev (not shipped)

- `debug_force_recruit_pool: Array[String]` — allows tests to bypass the generator and inject a fixed pool. Guarded by `OS.is_debug_build()`.

### G.4 V1.0 forward-compat surface

- "Featured class" / "limited-time class" pool entries (V1.0 live-ops) — additive to the pool schema.

---

## H. Acceptance Criteria

**AC-RC-01 — Autoload registered at rank 12**
At cold boot, `/root/Recruitment` resolves to the Recruitment autoload. `project.godot [autoload]` lists the entry between rank-11 (FormationAssignment) and rank-13 (HeroLeveling). Rank invariant: Recruitment._ready() runs after HeroRoster._ready() (rank 7) AND after Economy._ready() (rank 3).

**AC-RC-02 — Public API method existence + RecruitOutcome enum**
The autoload exposes `try_recruit(pool_index) -> RecruitOutcome`, `get_recruit_pool() -> Array[String]`, `get_recruit_cost(pool_index) -> int`, `refresh_pool() -> void`, `get_save_data() -> Dictionary`, `load_save_data(d) -> void`. The `RecruitOutcome` enum has exactly 5 values: SUCCESS, INSUFFICIENT_GOLD, ROSTER_FULL, INVALID_POOL_INDEX, UNRESOLVABLE_CLASS_ID.

**AC-RC-03 — Signal declarations**
The autoload declares `hero_recruited(hero_instance_id: int, class_id: String, cost_paid: int)` (3-arg) and `pool_refreshed(new_pool: Array[String])` (1-arg).

**AC-RC-04 — try_recruit success path mutates Economy + Roster atomically**
Pre: Economy.gold_balance = 1000; HeroRoster has 0 heroes; pool[0] = "warrior"; Economy.recruit_cost("warrior", 0) = 100. Act: try_recruit(0). Asserts: returns SUCCESS; Economy.gold_balance == 900; HeroRoster has 1 "warrior" hero; hero_recruited signal fired exactly once with `(new_id, "warrior", 100)`.

**AC-RC-05 — INSUFFICIENT_GOLD branch makes zero mutations**
Pre: Economy.gold_balance = 50; recruit_cost = 100. Act: try_recruit(0). Asserts: returns INSUFFICIENT_GOLD; gold_balance unchanged at 50; HeroRoster size unchanged; signal NOT emitted.

**AC-RC-06 — ROSTER_FULL branch makes zero mutations**
Pre: HeroRoster at max_roster_size; gold > cost. Act: try_recruit(0). Asserts: returns ROSTER_FULL; gold_balance unchanged; roster size unchanged; signal NOT emitted.

**AC-RC-07 — INVALID_POOL_INDEX branch makes zero mutations**
Act: try_recruit(-1) and try_recruit(pool.size()). Asserts: both return INVALID_POOL_INDEX; gold + roster + signal all unchanged.

**AC-RC-08 — UNRESOLVABLE_CLASS_ID branch makes zero mutations**
Pre: pool[0] = "fake_class_id"; DataRegistry.resolve("classes", "fake_class_id") returns null. Act: try_recruit(0). Asserts: returns UNRESOLVABLE_CLASS_ID; gold + roster + signal all unchanged.

**AC-RC-09 — add_hero contract violation triggers refund**
Pre: Inject a spy HeroRoster where add_hero returns null even though max_roster_size is not exceeded. Act: try_recruit(0). Asserts: Economy.add_gold("recruit_refund_*") was called with the same amount that try_spend deducted; net gold change is zero; push_error was logged; returns UNRESOLVABLE_CLASS_ID (the closest non-success outcome).

**AC-RC-10 — get_recruit_pool returns a copy (mutation-isolation)**
Mutating the returned Array does NOT mutate internal pool state. Asserts: `get_recruit_pool().clear()` does not affect the next `get_recruit_pool()` call's return.

**AC-RC-11 — get_recruit_cost matches Economy.recruit_cost contract**
For each entry in pool, get_recruit_cost(i) == Economy.recruit_cost(pool[i], HeroRoster.get_copies_owned(pool[i])). Locks the cost-stability invariant: cost shown to player matches cost charged at try_recruit time (provided no recruit happens between the calls).

**AC-RC-12 — pool_refreshed signal fires on refresh_pool() call**
Connect a spy. Call refresh_pool. Asserts: signal fired exactly once; payload equals the new pool.

**AC-RC-13 — Save/Load consumer surface**

> **SUPERSEDED 2026-05-06 (Sprint 13 S13-S3 reconciliation)** by ADR-0015 (Sprint 11 S11-X8 — Recruitment Pool Determinism + Refresh + Cost-Curve). The original "MVP empty payload" wording reflected the Pass-1 draft hypothesis (OQ-RC-1 deferred determinism to ADR-X04). ADR-0015 RESOLVED OQ-RC-1 by selecting deterministic save-seeded pool generation (Option B), which requires persisting 3 fields. The implementation in `src/core/recruitment/recruitment.gd:372-411` reflects ADR-0015, NOT this AC's pre-resolution wording.

Canonical AC text (post-supersession):

get_save_data() returns a 3-field Dictionary:
- `save_pool_seed: int` — RNG seed for deterministic pool generation across save-load
- `refresh_counter: int` — increments per refresh; mixed with save_pool_seed via XOR for the per-pool RNG seed
- `current_pool: Array[String]` — the most recent pool snapshot (so reload-after-close shows the same pool until next refresh trigger)

load_save_data(d) restores all 3 fields if present; non-int / non-string entries are filtered with `push_warning` (per skeleton tests `test_load_save_data_ignores_non_int_seed_and_re_inits` + `test_load_save_data_filters_non_string_pool_entries`). Empty Dict triggers a fresh save_pool_seed init via `randi()` (first-launch path). Forward-compat: unknown keys are ignored silently.

Test coverage already lands per the skeleton suite at `tests/unit/recruitment/recruitment_skeleton_test.gd:204-305`.

**AC-RC-14 — CI grep: HeroRoster.add_hero has exactly one production caller (Recruitment)**
Repository-level grep finds at most one `HeroRoster.add_hero(` call site in `src/` outside of HeroRoster's own `seed_first_launch_state()` and `add_hero` itself. The site is in `src/core/recruitment/recruitment.gd`. Forbidden-pattern entry: `add_hero_outside_recruitment`.

---

## I. Open Questions & ADR Candidates

**OQ-RC-1 — Pool generation determinism (ADR-X04 question 1) — RESOLVED 2026-05-05 (S11-X8 / ADR-0015)**
~~Is the recruit pool deterministic (RNG seeded from save state, replayable across save-load) or session-only (regenerated fresh on each load)?~~
- **Resolution**: deterministic, save-seeded. `_save_pool_seed XOR _refresh_counter` drives `RandomNumberGenerator.seed`. Reload-after-close shows the same pool until the next refresh trigger fires (cozy UX); save-scum reload cannot re-roll the pool (cheat-defense). See ADR-0015 for full rationale + V1.0 cloud-save-validation enabling.

**OQ-RC-2 — Refresh cadence (ADR-X04 question 2) — RESOLVED 2026-05-05 (S11-X8 / ADR-0015)**
~~What triggers a pool refresh?~~
- **Resolution**: on-clear + paid on-demand (hybrid). `floor_cleared_first_time` signal triggers a free refresh; `refresh_pool_paid()` lets the player force a refresh for `refresh_cost(refreshes_today)` gold (curve: `BASE × (1 + MULT × n)`, base=100, mult=2.0). Real-time-interval refresh REJECTED (FOMO + clock-tamper attack vector). See ADR-0015 §OQ-RC-2 + Alternative B for tradeoff analysis.

**OQ-RC-3 — Cost-curve / pool interaction (ADR-X04 question 3) — RESOLVED 2026-05-05 (S11-X8 / ADR-0015)**
~~Does each pool slot have an independent `copies_owned` count, or is `copies_owned` a global counter per class_id?~~
- **Resolution**: global per-class. `Recruitment.get_recruit_cost(pool_index)` reads `HeroRoster.get_copies_owned(class_id)` (roster count, not pool count). Aligns with ADR-0013's existing convention; same-class duplicate pool slots show the same cost (with the cost incrementing on the second row only AFTER the first is recruited, on next render). See ADR-0015 §OQ-RC-3 + Alternative C for tradeoff analysis.

**OQ-RC-4 — get_copies_owned HeroRoster API addition — RESOLVED 2026-05-05 (S11-X5)**
~~Recruitment needs `HeroRoster.get_copies_owned(class_id) -> int` to compute `copies_owned`. This method is NOT currently in hero-roster.md §C. Adding it is a Sprint 12+ hero-roster.md GDD update + ADR-0012 Amendment in lockstep with Recruitment Story 1. Out of MVP scope; ADR-X04 OR a separate ADR-0012 Amendment owns the lockstep edit.~~

**Resolution (S11-X5)**: Investigation found that `hero-roster.md` §C.B.1 read-API table line 111 ALREADY specified `get_copies_owned(class_id: String) -> int` — the method was designed but never implemented. Sprint 11 S11-X5 ships the implementation in `src/core/hero_roster/hero_roster.gd` with a 10-test suite (`tests/unit/hero_roster/get_copies_owned_test.gd`). No ADR-0012 Amendment needed — the method was already in the spec; this is a closure of an unimplemented designed-API. Sprint 12+ Recruitment Story 0b prereq is now complete.

**OQ-RC-5 — `_warning_logger` / `_error_logger` DI consistency**
Sprint 12+ implementation should adopt the DI-logger pattern used by FloorUnlockSystem (S11-X1) + FormationAssignment GDD §C.1 for testability. Not a design decision — a code-style consistency.

**OQ-RC-6 — Refund-path cost telemetry**
Should the refund path (§C.4 add_hero contract violation) emit a distinct telemetry signal (`recruit_refund`) so this rare failure is observable post-launch? Sprint 13+ telemetry design.

**OQ-RC-7 — Signal arity for V1.0 multi-recruit affordances**
V1.0 "recruit 5 warriors at once" affordance would either:
- Emit `hero_recruited` 5 times (subscribers iterate).
- Emit a new `bulk_recruited(Array[(int, String, int)])` signal.
The MVP API signature (try_recruit takes a single pool_index) does not preclude bulk recruit; the signal shape is the V1.0 design call.

---

## J. Implementation Sequencing (Sprint 12+ candidate)

This GDD describes the design surface; ADR-X04 must be authored BEFORE Sprint 12+ implementation begins. Sequence:

1. **Pre-implementation (~0.25d each)**:
   - **Story 0a — ADR-X04 authoring** — pick OQ-RC-1/2/3 candidates per playtest data. Output: `docs/architecture/ADR-XXXX-recruitment-pool-determinism.md`.
   - **Story 0b — `HeroRoster.get_copies_owned` API addition** — hero-roster.md GDD update + ADR-0012 Amendment + implementation + tests.

2. **Recruitment implementation (~2.0d total)**:
   - **Story 1 (~0.5d)** — `Recruitment` autoload skeleton + project.godot rank-12 lockstep + ADR-0003 Amendment.
   - **Story 2 (~0.5d)** — `try_recruit` happy path + the 4 failure-path branches + tests (AC-RC-04 through AC-RC-08).
   - **Story 3 (~0.25d)** — Refund path on add_hero contract violation (AC-RC-09).
   - **Story 4 (~0.25d)** — Pool generation per ADR-X04 candidate + `pool_refreshed` signal + tests (AC-RC-10, AC-RC-12).
   - **Story 5 (~0.25d)** — `get_recruit_cost` cost-stability invariant + tests (AC-RC-11).
   - **Story 6 (~0.25d)** — Save/Load consumer surface + tests (AC-RC-13).
   - **Story 7 (~0.25d)** — RecruitScreen wire-up (Sprint 12+ UI work owns the screen; this story is the autoload-side hook).
   - **Story 8 (~0.25d)** — CI grep for AC-RC-14 forbidden-pattern + add to ADR-0003 forbidden-patterns registry.

3. **Post-Recruitment** — `request_full_persist` happy-path round-trip testing (Story 007's deferred sentinel test) becomes possible once Recruitment lands. Closing this is the final Sprint 12+ milestone.

Total Sprint 12+ scope: ~3.0 days assuming ADR-X04 lands in a focused design pass first. The ADR is the gating step; without it, Sprint 12+ Story 4 (pool generation) is undefined.
