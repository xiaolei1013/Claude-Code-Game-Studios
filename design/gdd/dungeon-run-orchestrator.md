# Dungeon Run Orchestrator GDD — Lantern Guild

> **GDD #13 in design order** (System #13 in systems index)
> **Status**: In Design — Pass 5D applied 2026-04-20 (AC Triangulation Sweep; 17/17 re-review BLOCKERs closed; ready for Pass 5E gate re-run) + **Pass 5F-propagation applied 2026-04-21 (Save/Load element-layer HeroInstance method-name canonicalization — RunSnapshot `to_dict` / `from_dict` now calls `hero.to_dict()` / `hero.from_dict()` per Save/Load GDD #3 Rule 11 + Hero Roster Rule 4; 4 hits at lines 112, 115, 158, 207 + 1 straggler at line 729 Save/Load dependency row; all classified element-layer — Orchestrator is not itself a Save/Load consumer, its namespace key `"orchestrator"` is handled by the parent RunSnapshot serialization which the Orchestrator exposes via its own consumer-layer `get_save_data / load_save_data` pair already documented in §F)** + **Pass-I.15-fix applied 2026-04-21 (Floor Unlock #16 Pass-9 I.15 resolution — silent Pillar 1 violation on offline first-clears CLOSED: C.4 `compute_offline_run` now emits `floor_cleared_first_time(floor_index, biome_id, losing_run)` in lockstep with C.3 foreground emission; foreground/offline-parity invariant #1 in §F extended to cover signal-emission parity; AC-ORC-09 THEN extended to assert signal count + payload parity between the two paths)** + **Pass-ADR-0014-SYNC applied 2026-04-22 — ADR-0014 Accepted: RunSnapshot schema codified at ADR level (11 primitive fields + `formation_ids: Array[int]` size 3 + `matched_archetypes: Array[String]`); `DungeonRunOrchestrator.compute_offline_batch(tick_budget)` now consumed per-chunk by OfflineProgressionEngine rank 15 autoload (not a single call); AC-TICK-10 clarified as two distinct budgets (per-chunk CPU wall time ≤16ms BLOCKING vs total wall-clock-including-yield ≤5s ADVISORY ANR headroom); RunSnapshot persistence via ADR-0004 consumer contract with orphan-hero recovery path (`run_snapshot_discarded_orphan` signal triggering Economy refund); §J.1 Option A setter-DI pattern unchanged — ADR-0014 inherits the locked wiring verbatim.**
> **Created**: 2026-04-20
> **Last Updated**: 2026-04-22 (**Pass-INIT-PROBE-SYNC — confirmation-only entry**: `§J.1 Wiring model — Script autoload with lazy-default DI (locked Option A)` is now codified at ADR level by ADR-0009 (Matchup Resolver DI) + ADR-0003 Amendment #3, same day. **No pattern change to this GDD** — §J.1 already correctly anticipated Godot's autoload `_init` zero-arg constraint (§J.1 line ~1105 documents this explicitly) and chose Pattern A (lazy-default with public setters + two `set_*_resolver` test-facing methods). Empirical evidence backing §J.1's foresight: `docs/engine-reference/godot/modules/autoload.md` Claim 4 [VERIFIED] via Pass-INIT-PROBE 2026-04-22 on Godot 4.6.1.stable.mono.official. Cross-session note: ADR-0009's initial draft (same day) proposed the §J.7 Option E equivalent (`wire_dependencies` one-shot method); mid-lockstep review caught the contradiction with §J.1's locked decision and the ADR draft was rolled back to codify Pattern A verbatim. §J content is unchanged by this pass; this Last-Updated entry records the ADR-level codification only.) Previously: 2026-04-21 (Pass 5F-propagation — 5 hits renamed from element-layer `HeroInstance.save_to_dict / load_from_dict` to canonical `HeroInstance.to_dict / from_dict` per Save/Load Rule 11 + Hero Roster Rule 4; `KillEvent.to_dict / from_dict` remained unchanged — already canonical). Prior: Pass 5D — AC Triangulation Sweep closing the final 4 re-review BLOCKERs + 4 residual items: AC-ORC-01 `push_error` via §J.4 recording_logger Callable; AC-ORC-02 oracle API replaced with `CombatBatchResult` fields (no new Combat public helpers needed); AC-ORC-04 Economy spy source-tagging contract (Pattern 1 — drip-disabled fixture) + two alternatives documented; AC-ORC-07 NO_RUN→RUN_ENDED body↔Summary reconciled against C.1 + AC-ORC-13 pattern; AC-ORC-08 DataRegistry mock contract specified (real DataRegistry with Forest Reach fixture + Godot ResourceLoader caching invariant); AC-ORC-09 tick-step=1 excluded, parameterization tightened to {50, 200, 1000}; Sub-AC 03-no-call-if-no-tick-advance aligned with C.3 guard tightening `<` → `<=` (duplicate-tick silent rejection; strict-rewind branch still warns); C.3 pseudocode updated; D.4 `_build_matchup_cache` coverage contract (every archetype in kill_schedule); C.4 `OfflineRunResult.new(...)` keyword-arg syntax (invalid GDScript 4.6) rewritten as positional + property-setter pattern. **13/13 writeable ACs post-Pass-5D; 17/17 independent re-review BLOCKERs closed cumulatively.** Pass 5C — new §J Production Wiring + MatchupResolver Pass 5C DI conversion (Cluster α closed). Pass 5B — Economy GDD ADR-0002 implementation + D.6 F5 drip fix + Registry LOSING notes + Save/Load Rule 11 addendum. Pass 5A — author decisions 17a + 17b (ADR-0001 + ADR-0002). Pass 4D — AC-ORC-03 + AC-ORC-05 spy-subclass sub-ACs. Pass 4C: EventBus dropped; C.7 option (c); browse/commit signal split. Pass 4A: complete 5×6 matrix; D.3 clock-rewind; D.4 loop-walk; E.12–E.14.)
> **Authors**: systems-designer + game-designer + main session
> **Depends on**: Combat Resolution (#11) — Approved Pass 3 + targeted re-review pending; Biome/Dungeon DB (#7) — Approved; Game Time & Tick (#1) — Approved; Hero Roster (#9) — Approved; Matchup Resolver (#10) — Approved
> **Indirect upstreams**: Economy (#4), Hero Class DB (#5), Enemy DB (#6)
> **Referenced by**: Offline Progression Engine (#12, undesigned), Dungeon Run View (#24, undesigned), Floor Unlock System (#16, Designed 2026-04-20 pending review), Formation Assignment (#17, undesigned), Recruit/Leveling/Guild Hall UI (undesigned)
> **Implements Pillar**: Pillar 1 (deterministic offline replay — Orchestrator owns the run state Combat is stateless about) + Pillar 3 (indirect — Orchestrator routes MatchupResolver output into per-kill gold; the player feels matchup via cadence and gold rate, not a separate matchup UI; Pass 4C: Pillar 3 claim is indirect, not direct — see Section B G5 note)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

---

## A. Overview

The Dungeon Run Orchestrator is the run lifecycle coordinator. It owns all per-dispatch state (`run_snapshot` — formation, floor, cached DPS, kill schedule, loop counter, idempotency flags), subscribes to Game Time's `tick_fired(n)` signal in foreground mode, and calls Combat Resolution's two pure-function entry points (`emit_events_in_range` foreground, `compute_offline_batch` offline) to drive the dungeon loop. Its single purpose is to be the **stateful host** that lets Combat Resolution remain stateless. Everything else — gold attribution to Economy, kill-pop signals to Dungeon Run View, the once-per-dispatch first-clear gate, the boss fanfare trigger, the LOSING_RUN_LOOT_FACTOR multiplier — is a routing decision the Orchestrator makes between Combat's outputs and the rest of the game's signal consumers. The Orchestrator does not author new mechanics; it wires existing ones together. This GDD locks five contracts that Combat Resolution explicitly deferred here (AC-COMBAT-07b end-to-end LOSING gold attribution, AC-COMBAT-09b once-per-dispatch first-clear emission, E.5 LOSING re-run after first-clear contract, I.Q7 mid-run formation reassignment policy, I.Q8 boss-fanfare trigger placement) and resolves I.Q11 (the `floor_was_valid: bool` field judgment).

## B. Player Fantasy

The player closes the app on the way to bed. They wake up, open the game, and in the next two seconds they need to feel that **the dungeon kept running honestly while they were gone** — same kill cadence, same matchup payoffs, same first-clear bonus they'd have earned if they'd watched the whole run live. They will never see the Orchestrator. They will see its work product — the Return-to-App screen's "+22g × 18 kills, F3 cleared" summary in offline mode, and the `+120g` gold pop arriving every 22 seconds in foreground mode — and the work product must be **identical between the two modes for the same inputs**. Pillar 1 ("Respect the Player's Time") says the offline run cannot cheat the player either way (less generous OR more generous than foreground). The Orchestrator is the system that keeps that promise.

The Orchestrator is **infrastructure** — Path B framing per the skill's player-fantasy classification. The player feels what it enables (foreground/offline parity, deterministic kill cadence, the satisfying single boss-death fanfare at the climax of a 170s F5 fight, the quiet absence of duplicate first-clear bonuses on a re-run). They do not interact with the Orchestrator any more than they interact with a database transaction commit. But the difference between an Orchestrator that keeps Pillar 1 and one that quietly drifts is the difference between a player who trusts the offline math and one who closes the app. The fantasy is **trust through invisibility** — the cozy register of the broader game lives or dies in this layer's correctness.

> **G3 fantasy-honesty note (Pass 4C)**: The "trust through invisibility" claim is fully realized by the Orchestrator's foreground/offline parity guarantee (AC-ORC-09) and the correct serialization / replay path (AC-ORC-12). However, the complete player-facing realization of that trust depends on two downstream GDDs that are not yet designed: Return-to-App Screen (#20, which surfaces the "+22g × 18 kills, F3 cleared" summary) and the Offline Progression Engine (#12, which calls `compute_offline_run`). The Orchestrator delivers the mathematical contract; the perceived trustworthiness is complete only when those downstream GDDs are authored and implemented. This note does not change any Orchestrator rules — it is an honest statement of MVP scaffolding scope.

> **G5 Pillar 3 indirect-routing note (Pass 4C)**: The Orchestrator's Pillar 3 contribution ("Matchup Is a Decision, Not a Reflex") is **indirect**. The Orchestrator routes `MatchupResolver.is_advantaged` output into `attribute_kill_gold`'s `MATCHUP_GOLD_MULTIPLIER` branch — the player perceives matchup via kill gold rate and cadence variance, not via a dedicated matchup UI panel. The Orchestrator does not own matchup decision-making (that is Matchup Resolver #10 + Formation Assignment #17); it is the reward-routing layer. The player *feels* the decision's payoff through gold accumulation tempo.

## C. Detailed Design

### C.1 Run Lifecycle State Machine

The Orchestrator's runtime state is a single FSM with five states. State is owned exclusively by the Orchestrator and persisted via Save/Load (#3) when the app suspends.

**State descriptions:**

| State | Description |
|---|---|
| `NO_RUN` | No formation dispatched. Default state at app launch and after `RUN_ENDED → NO_RUN` (player explicitly clears). |
| `DISPATCHING` | Validating formation + floor inputs; computing run snapshot via one-shot `compute_offline_batch(formation, floor, 0)` to derive `formation_dps_per_tick`, `hp_bonus_factor`, `ticks_per_loop`, and the first-loop kill schedule. Lasts <1 frame. |
| `ACTIVE_FOREGROUND` | App visible. Subscribed to `tick_fired`. Per-tick: calls `combat_resolver.emit_events_in_range(formation, floor, last_emitted_tick, current_tick)` and routes returned `CombatTickEvents`. |
| `ACTIVE_OFFLINE_REPLAY` | One-shot `compute_offline_batch(formation, floor, tick_budget)` per dispatched floor. Returned `CombatBatchResult` is folded into Economy + Return-to-App events log. Owned by Offline Progression Engine (#12); Orchestrator is the callee. |
| `RUN_ENDED` | Snapshot retained for Return-to-App display until next dispatch overwrites it. No active subscription to ticks. |

**Complete state × trigger matrix (5 states × 6 triggers — every cell defined):**

Trigger legend:
- `dispatch_pressed` — player taps Dispatch button on Formation Assignment Screen
- `formation_changed` — `formation_reassignment_committed(new_formation: Array[HeroInstance])` signal fired (player confirmed a hero swap in Formation Assignment; NOT fired by `formation_browse_opened`). Pass 4C: this trigger is now owned by the write-side signal only — see C.7 for the read/write signal split.
- `app_suspended` — app goes to background (mobile sleep, Steam Deck suspend, desktop minimize)
- `app_resumed` — app returns to foreground from background
- `offline_replay_complete` — `compute_offline_batch` call finished (Offline Engine signals completion)
- `run_ended` — internal trigger fired when validation fails at DISPATCHING, or player explicitly recalls formation

| Current State | `dispatch_pressed` | `formation_changed` | `app_suspended` | `app_resumed` | `offline_replay_complete` | `run_ended` |
|---|---|---|---|---|---|---|
| `NO_RUN` | → `DISPATCHING` (begin validation + snapshot) | **Invalid** — `push_error`; remain `NO_RUN` (no active run to modify) | → `NO_RUN` (no-op; nothing to persist) | → `NO_RUN` (no-op; no run was active) | **Invalid** — `push_error`; remain `NO_RUN` (no replay was running) | **Invalid** — `push_error`; remain `NO_RUN` (no run to end) |
| `DISPATCHING` | **Invalid** — `push_error`; remain `DISPATCHING` (belt-and-braces; debounce normally catches this) | **Invalid** — `push_error`; remain `DISPATCHING` (formation snapshot already frozen; reassignment during <1-frame DISPATCHING is a race that must not succeed) | **Invalid** — `push_error`; remain `DISPATCHING` (suspend arriving during the <1-frame DISPATCHING window is treated as an error; Orchestrator must complete or abort before processing further signals) | **Invalid** — `push_error`; remain `DISPATCHING` (resume while DISPATCHING is nonsensical — DISPATCHING is synchronous, not async) | **Invalid** — `push_error`; remain `DISPATCHING` (no replay was running) | → `RUN_ENDED` (validation failed: empty formation per AC-ORC-07, locked floor per AC-ORC-13, or `floor_was_valid=false` per E.11; snapshot retained in minimal form for UI error display; see C.4 note D.3) |
| `ACTIVE_FOREGROUND` | **Invalid** — `push_error`; remain `ACTIVE_FOREGROUND` (must end run first; dispatch while running is a UI bug) | → `RUN_ENDED` then immediately → `DISPATCHING` with new formation snapshot (C.7 mid-run reassignment policy; ends current run, begins new dispatch) | → `ACTIVE_OFFLINE_REPLAY` (persist snapshot; Offline Engine takes over) | → `ACTIVE_FOREGROUND` (no-op; already foreground) | **Invalid** — `push_error`; remain `ACTIVE_FOREGROUND` (no replay was running) | → `RUN_ENDED` (player explicitly recalls formation, or internal error path) |
| `ACTIVE_OFFLINE_REPLAY` | **Invalid** — `push_error`; remain `ACTIVE_OFFLINE_REPLAY` (cannot dispatch during a replay; must wait for replay to complete) | → `RUN_ENDED` (formation changed during offline replay — reassignment policy applies; replay result is discarded; a new dispatch with the new formation begins after `RUN_ENDED → DISPATCHING` on the next player action) | → `ACTIVE_OFFLINE_REPLAY` (no-op; already in offline replay) | → `ACTIVE_OFFLINE_REPLAY` if replay still computing; otherwise → `ACTIVE_FOREGROUND` on `offline_replay_complete` | → `ACTIVE_FOREGROUND` (replay complete and app is now visible) OR → `RUN_ENDED` (replay complete and player tapped Recall) | → `RUN_ENDED` (via `replay_failed` error path; see C.4 error transition note below) |
| `RUN_ENDED` | → `DISPATCHING` (player begins a new dispatch) | **Invalid** — `push_error`; remain `RUN_ENDED` (run is already over; `formation_changed` after end is a no-op until next dispatch) | → `RUN_ENDED` (no-op; snapshot already frozen, nothing active to persist) | → `RUN_ENDED` (no-op; no active run) | **Invalid** — `push_error`; remain `RUN_ENDED` (no replay was running) | → `NO_RUN` (player explicitly clears the run; optional UI affordance) |

**Invalid cell behavior**: every "Invalid — `push_error`" cell logs a message in the format `"Orchestrator: invalid trigger [trigger] in state [state]; ignoring"` and leaves state unchanged. This is not a crash — the Orchestrator must remain operational even under signal-ordering edge cases.

**Invariant**: Combat is called only from `DISPATCHING`, `ACTIVE_FOREGROUND`, and `ACTIVE_OFFLINE_REPLAY`. In `NO_RUN` and `RUN_ENDED`, Combat is silent (no `tick_fired` subscription, no batch calls).

### C.2 Run Snapshot (Orchestrator-Owned State)

The `RunSnapshot` is a `RefCounted` value type holding all per-dispatch state. Persisted via Save/Load (#3) using `to_dict() / from_dict()` round-trip per Save/Load Rules 10–14 and AC-ORC-12.

```gdscript
class_name RunSnapshot extends RefCounted

# Frozen at DISPATCHING; never mutated mid-run
var formation_snapshot:    Array[HeroInstance]   # deep copy from HeroRoster.get_formation_heroes()
var floor:                 Floor                 # resource ref from Biome/Dungeon DB; serialized by floor.id (String)
var dispatched_at_tick:    int                   # absolute tick at DISPATCHING entry

# Cached from compute_offline_batch(formation, floor, 0) during DISPATCHING — NEVER recomputed mid-dispatch
var formation_dps_per_tick: float                # raw, per Combat D.2
var hp_bonus_factor:        float                # per Combat D.6, cached for Pillar 2
var ticks_per_loop:         int                  # per Combat D.4 / Rule 8
var kill_schedule:          Array[KillEvent]     # loop-relative, per Combat D.5
var losing_run:             bool                 # Pass 4B-SaveLoad: serialized explicitly; NOT re-derived from hp_bonus_factor on load

# Mutated during foreground/offline progression
var last_emitted_tick:      int                  # foreground watermark; advances per tick_fired
var loop_counter:           int                  # incremented each time the kill schedule wraps
var floor_clear_emitted:    bool                 # per-dispatch idempotency flag (AC-COMBAT-09b)
var matchup_cache:          Dictionary[StringName, bool]  # per-archetype advantaged lookup, built at DISPATCHING

# Optional richer-contract field (Combat I.Q11 — RECOMMENDED, not BLOCKING)
var floor_was_valid:        bool                 # true if Combat returned a non-empty kill schedule at DISPATCHING

func to_dict() -> Dictionary:
    # Pass 4B-SaveLoad: serialize all fields. RefCounted arrays use per-element to_dict().
    # Floor serialized by id only (serialize-by-id convention — Save/Load Rule 12).
    # losing_run serialized explicitly alongside hp_bonus_factor (Save/Load Rule 14).
    var d: Dictionary = {
        "dispatched_at_tick":     dispatched_at_tick,
        "formation_dps_per_tick": formation_dps_per_tick,
        "hp_bonus_factor":        hp_bonus_factor,
        "ticks_per_loop":         ticks_per_loop,
        "losing_run":             losing_run,         # explicit bool — do NOT re-derive on load
        "last_emitted_tick":      last_emitted_tick,
        "loop_counter":           loop_counter,
        "floor_clear_emitted":    floor_clear_emitted,
        "floor_was_valid":        floor_was_valid,
        "floor_id":               floor.id,           # String — resolve via DataRegistry on load
    }
    # Array[HeroInstance] → Array[Dictionary] (per-element to_dict — Pass-5F-propagation 2026-04-21: element-layer canonical method name per Save/Load GDD #3 Rule 11 + Hero Roster Rule 4)
    var formation_arr: Array[Dictionary] = []
    for hero in formation_snapshot:
        formation_arr.append(hero.to_dict())
    d["formation_snapshot"] = formation_arr
    # Array[KillEvent] → Array[Dictionary] (per-element to_dict — requires Combat Pass 3F)
    var schedule_arr: Array[Dictionary] = []
    for kill in kill_schedule:
        schedule_arr.append(kill.to_dict())
    d["kill_schedule"] = schedule_arr
    # matchup_cache: Dictionary[StringName, bool] → plain Dictionary (StringName keys JSON as String)
    var cache_plain: Dictionary = {}
    for archetype in matchup_cache:
        cache_plain[String(archetype)] = matchup_cache[archetype]
    d["matchup_cache"] = cache_plain
    return d

static func from_dict(d: Dictionary) -> RunSnapshot:
    # Pass 4B-SaveLoad: reconstruct snapshot. Returns null on any hard deserialization failure.
    # The Orchestrator consumer treats null as NO_RUN (Save/Load Rule 10 error contract).
    if d == null or d.is_empty():
        return null
    # Resolve floor by id (serialize-by-id — Save/Load Rule 12)
    var floor_id: String = d.get("floor_id", "")
    if floor_id == "":
        push_error("RunSnapshot.from_dict: missing floor_id — resetting to NO_RUN")
        return null
    var resolved_floor: Floor = DataRegistry.resolve("floors", floor_id)
    if resolved_floor == null:
        push_error("RunSnapshot.from_dict: floor_id '%s' could not be resolved — resetting to NO_RUN" % floor_id)
        return null
    var snap := RunSnapshot.new()
    snap.floor                 = resolved_floor
    snap.dispatched_at_tick    = d.get("dispatched_at_tick",     0)
    snap.formation_dps_per_tick= d.get("formation_dps_per_tick", 0.0)
    snap.hp_bonus_factor       = d.get("hp_bonus_factor",        1.0)
    snap.ticks_per_loop        = d.get("ticks_per_loop",         1)
    snap.losing_run            = d.get("losing_run",             false)  # authoritative — not re-derived
    snap.last_emitted_tick     = d.get("last_emitted_tick",      0)
    snap.loop_counter          = d.get("loop_counter",           0)
    snap.floor_clear_emitted   = d.get("floor_clear_emitted",    false)
    snap.floor_was_valid       = d.get("floor_was_valid",        false)
    # Reconstruct Array[HeroInstance] from Array[Dictionary] (Pass-5F-propagation 2026-04-21: element-layer canonical `from_dict` per Save/Load Rule 11 + Hero Roster Rule 4)
    snap.formation_snapshot = []
    for hero_dict in d.get("formation_snapshot", []):
        var hero := HeroInstance.new()
        hero.from_dict(hero_dict)
        snap.formation_snapshot.append(hero)
    # Reconstruct Array[KillEvent] from Array[Dictionary] (requires Combat Pass 3F)
    snap.kill_schedule = []
    for kill_dict in d.get("kill_schedule", []):
        var kill: KillEvent = KillEvent.from_dict(kill_dict)
        if kill != null:
            snap.kill_schedule.append(kill)
        else:
            push_error("RunSnapshot.from_dict: KillEvent.from_dict returned null for entry — entry skipped")
    # Reconstruct matchup_cache: plain Dictionary → Dictionary[StringName, bool]
    snap.matchup_cache = {}
    for key in d.get("matchup_cache", {}):
        snap.matchup_cache[StringName(key)] = d["matchup_cache"][key]
    return snap

func equals(other: RunSnapshot) -> bool:
    # Field-equality used by save/load round-trip test (AC-ORC-12).
    # losing_run is compared directly (explicit bool field — Save/Load Rule 14).
    # hp_bonus_factor uses is_equal_approx (DPS-range float — Save/Load Rule 13).
    if other == null: return false
    if formation_snapshot.size() != other.formation_snapshot.size(): return false
    for i in formation_snapshot.size():
        if not formation_snapshot[i].equals(other.formation_snapshot[i]): return false
    if floor.id != other.floor.id: return false  # null guard: floor must be non-null (from_dict enforces this)
    if not is_equal_approx(formation_dps_per_tick, other.formation_dps_per_tick): return false
    if not is_equal_approx(hp_bonus_factor, other.hp_bonus_factor): return false
    if ticks_per_loop != other.ticks_per_loop: return false
    if kill_schedule.size() != other.kill_schedule.size(): return false
    for i in kill_schedule.size():
        if not kill_schedule[i].equals(other.kill_schedule[i]): return false
    # matchup_cache: Dictionary[StringName, bool] — key-by-key walk
    if matchup_cache.size() != other.matchup_cache.size(): return false
    for key in matchup_cache:
        if not other.matchup_cache.has(key): return false
        if matchup_cache[key] != other.matchup_cache[key]: return false
    return (dispatched_at_tick == other.dispatched_at_tick
        and last_emitted_tick == other.last_emitted_tick
        and loop_counter == other.loop_counter
        and floor_clear_emitted == other.floor_clear_emitted
        and losing_run == other.losing_run
        and floor_was_valid == other.floor_was_valid)
```

**Persistence contract**: The Orchestrator extends Combat's stateless purity by being the single holder of mutable run state. Save/Load (#3) serializes this snapshot when the app suspends; Resume reconstructs it from the saved dict + the elapsed offline tick budget computed by Game Time (#1).

**Pass 4B-SaveLoad contract notes**:
- `floor` is serialized as `floor.id: String` (key `"floor_id"` in dict) — not inline. Resolved via `DataRegistry.resolve("floors", floor_id)` on load. If resolve fails, `from_dict` returns `null` → Orchestrator resets to `NO_RUN`.
- `losing_run` is serialized as an explicit `bool` field (`"losing_run"`) alongside `"hp_bonus_factor"`. On load, `losing_run` is read directly from the dict — it is NOT recomputed from `hp_bonus_factor < 0.5`. This prevents float-boundary flip at exactly 0.5 (Save/Load Rule 14, B4 resolution).
- `formation_snapshot` (Array[HeroInstance]) and `kill_schedule` (Array[KillEvent]) use per-element `to_dict()` (Pass-5F-propagation 2026-04-21: HeroInstance element-layer canonical method name aligned with Save/Load Rule 11 + Hero Roster Rule 4 — both HeroInstance and KillEvent now share the `to_dict / from_dict` element contract). `KillEvent.to_dict()` and `KillEvent.from_dict()` require **Combat Pass 3F** (currently unimplemented — flagged, not blocked for this GDD; `from_dict` skips and logs on null return).
- `matchup_cache` (Dictionary[StringName, bool]) is serialized as a plain `Dictionary[String, bool]` (StringName keys coerce to String in JSON; reconstructed via `StringName(key)` on load).

### C.3 Foreground Tick Loop

In `ACTIVE_FOREGROUND`, the Orchestrator is the only subscriber to `GameTime.tick_fired(n)` related to dungeon-run progression (Economy's drip subscription is independent — Orchestrator does not own drip).

```gdscript
# Inside DungeonRunOrchestrator (Node, autoloaded)

func _on_tick_fired(current_tick: int) -> void:
    if state != State.ACTIVE_FOREGROUND: return
    var events: CombatTickEvents = combat_resolver.emit_events_in_range(
        snapshot.formation_snapshot,
        snapshot.floor,
        snapshot.last_emitted_tick,        # exclusive
        current_tick                        # inclusive
    )
    _process_tick_events(events, current_tick)
    snapshot.last_emitted_tick = current_tick

func _process_tick_events(events: CombatTickEvents, current_tick: int) -> void:
    # Per-event UI + gold attribution
    for kill in events.kills:
        # Pass 5C: instance call on injected _matchup_resolver (was MatchupResolver.resolve_*
        # static form pre-Pass-5C; see §J Production Wiring).
        var advantaged: bool = _matchup_resolver.resolve_formation_matchup(
            snapshot.formation_snapshot, kill.archetype
        ).is_advantaged
        var gold: int = _attribute_kill_gold(kill.tier, advantaged, snapshot.losing_run)
        Economy.add_gold(gold)
        enemy_killed.emit(kill.tier, kill.archetype, advantaged)  # Dungeon Run View consumer (signal on Orchestrator autoload)
        if kill.is_boss:
            boss_killed.emit(kill.enemy_id)                       # boss fanfare (signal on Orchestrator autoload)
    # Loop completions + first-clear idempotency
    snapshot.loop_counter += events.loop_completed_ticks.size()
    if events.first_clear_in_range and not snapshot.floor_clear_emitted:
        var clear_bonus: int = _attribute_floor_clear_bonus(
            snapshot.floor.floor_index, snapshot.losing_run
        )
        Economy.try_award_floor_clear(snapshot.floor.floor_index, clear_bonus)
        snapshot.floor_clear_emitted = true
        floor_cleared_first_time.emit(snapshot.floor.floor_index, snapshot.biome_id, snapshot.losing_run)  # signal on Orchestrator autoload; payload extended 2026-04-20 per Floor-Unlock-Propagation-Edit-3 (GDD #16 §F edit #3). RunSnapshot gains `biome_id: String` cached at DISPATCHING from the dispatched Dungeon resource (MVP hardcoded to "forest_reach" via `_active_biome_id()` helper; V1.0 sourced from biome-context injection). Existing subscribers (Economy, Dungeon Run View #24) remain compatible — additive payload extension, not signature break.
```

**Per-tick performance budget**: ≤2 ms p95 on min-spec mobile (well under the 50 ms tick window). Combat's AC-COMBAT-14 budget (100 ms p95 for an 8h batch) dominates — per-tick foreground work is trivially small (typically 0–1 kill events per tick at L13 W+M+R cadence).

### C.4 Offline Replay Path

In `ACTIVE_OFFLINE_REPLAY`, the Orchestrator is called by the Offline Progression Engine (#12) once per dispatched floor in the offline budget (typically just one — the player can only dispatch one formation at a time in MVP).

```gdscript
func compute_offline_run(tick_budget: int) -> OfflineRunResult:
    assert(state == State.ACTIVE_OFFLINE_REPLAY)
    var batch: CombatBatchResult = combat_resolver.compute_offline_batch(
        snapshot.formation_snapshot,
        snapshot.floor,
        tick_budget
    )
    # First-clear: same idempotency contract as foreground (C.6).
    # I.15 FIX (Pass-I.15 2026-04-21): the offline path MUST emit floor_cleared_first_time
    # in lockstep with the foreground path (C.3 line 249). Without this emission, a player
    # who earns a first-clear while offline returns to a guild where gold was credited but
    # the next floor stays LOCKED — a silent Pillar 1 violation flagged by Floor Unlock #16
    # Pass-9 as I.15. Floor Unlock's _on_floor_cleared_first_time listener is the sole
    # unlock-advancement path; skipping the offline emission was the root cause. The signal
    # is safe to fire during ACTIVE_OFFLINE_REPLAY because Floor Unlock's listener only
    # mutates internal unlock state (no UI calls, no await points); the Return-to-App
    # screen surfaces the event separately via OfflineRunResult.gold_clear_bonus below.
    var clear_bonus: int = 0
    if batch.first_clear_tick > 0 and not snapshot.floor_clear_emitted:
        clear_bonus = _attribute_floor_clear_bonus(
            snapshot.floor.floor_index, snapshot.losing_run
        )
        Economy.try_award_floor_clear(snapshot.floor.floor_index, clear_bonus)
        snapshot.floor_clear_emitted = true
        # I.15 emission — foreground/offline parity per Pillar 1 (see C.3 line 249 for the
        # mirror emission in the foreground path). Payload matches C.3 exactly.
        floor_cleared_first_time.emit(snapshot.floor.floor_index, snapshot.biome_id, snapshot.losing_run)
    # Aggregate kill gold attribution via ordered kill-schedule loop-walk (D.4).
    # Pass 5D (re-review δ item 11 closure): _build_matchup_cache pre-populates an entry
    # for EVERY archetype present in kill_schedule (which is a superset of any archetype
    # that could appear in partial_loop_kills, because partial_loop_kills ⊆ one_full_loop ⊆ kill_schedule).
    # This guarantees the cache has coverage for every lookup the walks below perform,
    # eliminating the KeyError risk flagged in the re-review.
    var matchup_cache: Dictionary[StringName, bool] = _build_matchup_cache(snapshot.formation_snapshot, snapshot.kill_schedule)
    var aggregated: Dictionary = _aggregate_kill_gold_offline(snapshot.kill_schedule, batch.loops_completed, batch.partial_loop_kills, matchup_cache, snapshot.losing_run)
    Economy.add_gold(aggregated.total_kill_gold)
    snapshot.loop_counter += batch.loops_completed
    snapshot.last_emitted_tick = batch.final_tick
    # Pass 5D (re-review δ item 12 closure): GDScript 4.6 does NOT support keyword
    # argument syntax in `.new(...)` calls. Construct + assign properties explicitly.
    # OfflineRunResult is a RefCounted value type with public fields (see C.4 schema).
    var result := OfflineRunResult.new()
    result.kills_by_archetype = batch.kills_by_archetype
    result.kills_by_tier      = batch.kills_by_tier
    result.gold_kills         = aggregated.total_kill_gold
    result.gold_clear_bonus   = clear_bonus
    result.loops_completed    = batch.loops_completed
    result.floor_index        = snapshot.floor.floor_index
    result.losing_run         = snapshot.losing_run
    return result
```

**Per-archetype matchup cache**: Because the formation is frozen at `DISPATCHING` and the matchup decision depends only on `(formation, archetype)`, the Orchestrator caches the result of `_matchup_resolver.resolve_formation_matchup` (Pass 5C — instance call on the injected `_matchup_resolver: MatchupResolver` field; see §J) per distinct archetype in the floor's enemy_list (≤5 entries per MVP floor). This collapses 15,000+ resolver calls per offline batch into ≤5. AC-ORC-11 verifies this with a spy subclass of `MatchupResolver`.

**Aggregate kill gold derivation**: The Orchestrator uses the loop-walk algorithm (D.4) over `snapshot.kill_schedule` — the ordered list of `KillEvent` entries cached at `DISPATCHING`. This walk correctly handles partial loops by stopping at the first kill whose `kill_tick > tick_budget mod ticks_per_loop`. See D.4 for the full algorithm. Note: `CombatBatchResult.kills_by_archetype` and `kills_by_tier` are retained for UI summary and telemetry via `OfflineRunResult`, but are **NOT used for gold attribution** (they cannot recover `(archetype, tier)` pairs for mixed-tier floors).

**ACTIVE_OFFLINE_REPLAY error transition (D.2 state machine fix)**: If `compute_offline_batch` throws an unhandled error, returns a malformed result, or `snapshot.floor` becomes invalid mid-replay, the Orchestrator transitions `ACTIVE_OFFLINE_REPLAY → RUN_ENDED` via the `run_ended` trigger with a `validation_failed("offline_replay_error", {reason: msg})` signal. Gold credited up to the error point is retained (no rollback); the player is shown an error toast. This path prevents the Orchestrator from becoming permanently stuck in `ACTIVE_OFFLINE_REPLAY`. See E.13.

### C.5 Per-Kill Gold Attribution

```
_attribute_kill_gold(tier: int, advantaged: bool, losing_run: bool) -> int:
    var matchup_multiplier: float = MATCHUP_GOLD_MULTIPLIER if advantaged else 1.0
    var loot_factor: float = LOSING_RUN_LOOT_FACTOR if losing_run else 1.0
    return floori(BASE_KILL[tier] * matchup_multiplier * loot_factor)
```

Pure function. Reads Economy's `BASE_KILL[tier]` lookup + `MATCHUP_GOLD_MULTIPLIER` + `LOSING_RUN_LOOT_FACTOR` constants. Identical implementation in foreground (per-event) and offline (aggregated). The same function is the gate for foreground/offline parity (AC-ORC-09 / Section H) — both paths MUST produce identical totals for the same `(tier, advantaged, losing_run)` distribution.

### C.6 First-Clear Idempotency (AC-COMBAT-09b)

**Three-layer idempotency** (per Combat Rule 7 + Economy AC H-03):

1. **Combat (stateless)** — emits `CombatTickEvents.first_clear_in_range = true` whenever the loop counter crosses 0→1 inside the tick range of the current call. Combat cannot know whether a previous call already saw the transition; it just reports facts.
2. **Orchestrator (per-dispatch)** — the `floor_clear_emitted: bool` flag on `RunSnapshot` (C.2) gates the emission. The Orchestrator sets it true on first observation and never re-emits within the same dispatch, regardless of how many subsequent foreground/offline calls also return `first_clear_in_range = true`.
3. **Economy (per-save-lifetime, monotonic)** — `floor_clear_bonus_credited[floor_index]: int` (Economy C.2.3 + AC H-03, reshaped per ADR-0002) is the authoritative gate against over-payment across the player's entire save. The Orchestrator calls `Economy.try_award_floor_clear(floor_index, bonus_amount)`; Economy credits `max(0, bonus_amount - already_credited)` and stores the new ceiling. On WIN clears the delta is the full `FLOOR_CLEAR_BONUS[floor_index]`; on LOSING first-clears the delta is the halved amount; on a WIN following a LOSING first-clear, the delta is the un-paid remainder (see E.15 + ADR-0002).

The Orchestrator's job is to make sure Economy is called **at most once per dispatch**. Economy's job is to make sure the total lifetime credit for a floor **never exceeds `FLOOR_CLEAR_BONUS[floor_index]`**. Both layers are required; neither alone is sufficient. ADR-0002's monotonic-credit semantic preserves anti-exploit (no over-payment) while enabling LOSING first-clear re-claim on a subsequent WIN (Pillar 1 "no fail state" expressed mechanically).

### C.7 Mid-Run Formation Reassignment Policy (Combat I.Q7)

**Pass 4C (G1 reframe): Three options enumerated; option (a) is the MVP lock; option (c) is the V1.0-deferred cozy path.**

**Pass 5A (17a — accepted trade-off, authority: ADR-0001):** Option (a) is locked for MVP. The following risk is explicit, not residual:

> **⚠ Risk — Intentional mid-F5-boss reassignment destroys loop progress.** A player 140s into a 170s F5 boss fight who commits a formation swap (e.g., swapping in a specialist they just recruited) will trigger the `ACTIVE_FOREGROUND → RUN_ENDED → DISPATCHING → ACTIVE_FOREGROUND` chain and lose the entire 140s of progress on that loop. The browse/commit signal split (below) prevents the *accidental* version of this; it does **not** prevent the *intentional* version. The `MID_RUN_REASSIGN_WARNING_ENABLED = true` UX dialog (G.1) surfaces this before the commit but does not recover the progress.

> **V1.1 upgrade path — Option (c) deferred queue.** If vertical-slice playtest telemetry (`mid_run_reassignments_during_floor_5_boss`, RECOMMENDED counter) shows this risk is a live pain point, option (c) is the named upgrade: add `queued_formation: Array[HeroInstance]` (nullable) to `RunSnapshot`; on commit during an active run, store the queued formation and apply it at the next natural dispatch boundary. No mid-dispatch snapshot mutation; no Pillar 1 parity violation. See ADR-0001 §Rollback for the rollback/upgrade procedure.

#### Signal Split: read vs. write (Pass 4C)

The Formation Assignment Screen (#17, undesigned) owns two distinct signal surfaces:

- `formation_browse_opened` — **read-only, informational**. Emitted when the player opens the Formation Assignment Screen to browse heroes (no formation change committed). The Orchestrator **ignores this signal completely** — browsing the roster does not end the run. This prevents the anti-cozy fail state where a player accidentally opens the roster panel during an active run and loses their progress.
- `formation_reassignment_committed(new_formation: Array[HeroInstance])` — **write signal**. Emitted only when the player explicitly confirms a hero swap via the Formation Assignment Screen's commit action (button press, not panel open). This is the signal that triggers the Orchestrator's reassignment policy below.

The `MID_RUN_REASSIGN_WARNING_ENABLED = true` knob (G.1) gates the UX confirmation dialog: the dialog fires *before* `formation_reassignment_committed` is emitted, giving the player a chance to cancel. The signal is only emitted on confirmed intent.

> **Design note (Pass 4C)**: The signal split is critical for Pillar 1 cozy preservation. Without it, a player who opens the Formation Assignment Screen during an active run to plan their *next* dispatch — a natural, low-intent action — would inadvertently trigger run-end. Separating `formation_browse_opened` (informational) from `formation_reassignment_committed` (intent-confirmed write) removes the accidental-run-end failure mode. This is a UI contract enforced at the Formation Assignment Screen boundary, not the Orchestrator boundary.

#### Option (a) — End run + restart dispatch (MVP lock)

**Decision: option (a) is the MVP default.**

When `formation_reassignment_committed(new_formation)` fires, the Orchestrator transitions: `ACTIVE_FOREGROUND → RUN_ENDED → DISPATCHING → ACTIVE_FOREGROUND`. The new dispatch uses the new formation snapshot; all per-dispatch idempotency flags reset (`floor_clear_emitted = false` on the new snapshot — the player can re-clear a floor under a new formation if it qualifies as a first-clear under the new dispatch's lifetime tracking, though Economy's per-lifetime gate in C.6 still prevents bonus double-payment).

**Rationale** (from Combat I.Q7 framing): Matches "respect the player's intent." End-and-restart is also simpler — no mid-dispatch snapshot mutation, no stale `kill_schedule` after a hero swap, no need to recompute `formation_dps_per_tick` mid-loop.

**Trade-off accepted**: A player who reassigns 30 seconds into a 170s F5 boss fight loses progress on that loop. Rationale: this is the cost of changing your mind; the alternative (mid-loop snapshot mutation) violates Combat's stateless contract and breaks Pillar 1's foreground/offline parity invariant. UI affordance: Formation Assignment Screen displays "Reassigning will end your current run" warning (gated by `MID_RUN_REASSIGN_WARNING_ENABLED`) before emitting the commit signal.

#### Option (b) — Reject reassignment until player explicitly recalls (not selected)

When `formation_reassignment_committed` fires during an active run, the Orchestrator emits `validation_failed("reassignment_blocked_during_run", {})` and does NOT transition. The Formation Assignment Screen must show a "You cannot reassign during an active run — recall your formation first" message. Player must explicitly end the run via a separate Recall Formation action before reassignment is permitted.

**Not selected**: This blocks a natural player action and produces a potential UI dead state. It is the most predictable option for engine correctness but the least cozy.

#### Option (c) — Deferred reassignment (V1.0-deferred, recommended cozy path)

When `formation_reassignment_committed` fires during an active run, the Orchestrator **queues** the new formation rather than immediately ending the run. The queued formation is applied at the next **dispatch boundary** — i.e., when the current run ends naturally (floor cleared or recalled), the Orchestrator begins the new dispatch with the queued formation automatically, without requiring a second player action.

**Not the MVP default** — option (a) ships for MVP due to simpler snapshot management. However, if first-playtest reveals that players are frustrated by losing run progress through roster browsing (even with the `formation_browse_opened` split), option (c) is the recommended V1.0 upgrade path. It is the most cozy option: the player can plan their next formation during an active run without paying a penalty for looking.

**Implementation note for V1.0**: Requires adding `queued_formation: Array[HeroInstance]` to `RunSnapshot` (nullable) and a dispatch-boundary check in the `RUN_ENDED` → `DISPATCHING` transition logic. No mid-dispatch snapshot mutation; no parity invariant violation.

#### Summary table

| Option | Trigger handling | Cozy score | Complexity | Selected |
|---|---|---|---|---|
| (a) End run + restart | `formation_reassignment_committed` → ends run immediately | Medium — clear feedback but progress loss | Low | **MVP default** |
| (b) Reject until recall | `formation_reassignment_committed` → blocked, must recall first | Low — forced player action | Low | Not selected |
| (c) Deferred queue | `formation_reassignment_committed` → queued for next dispatch boundary | High — no penalty for planning | Medium | V1.0-deferred |

### C.8 Boss Fanfare Trigger Placement (Combat I.Q8)

**Decision**: The Orchestrator emits `DungeonRunOrchestrator.boss_killed.emit(enemy_id)` (signal owned by the Orchestrator autoload — Pass 4C: EventBus dropped; see signal ownership note below) whenever a `KillEvent` with `is_boss == true` is processed, **regardless of queue position in the floor's enemy_list**. The Orchestrator does not enforce the "boss is last enemy" convention — that is an authoring guideline owned by Biome/Dungeon DB (Biome E.5 + QA-catch via Biome H-05) and a defensive log line at floor load time, not a runtime gate.

**Rationale** (from Combat I.Q8 framing): Combat propagates `is_boss` per-event faithfully (Combat E.10). The Orchestrator's job is to forward facts, not to second-guess content. If a future floor author places a boss in a mid-queue position by accident, the fanfare fires when that enemy dies — surfacing the authoring bug visibly is more useful than silently suppressing it. The `boss_killed` signal is consumed by Dungeon Run View (#24) for the boss-death cinematic + by Audio (TBD) for the fanfare cue.

### C.9 Interactions with Other Systems

| Consumer / Provider | Direction | Data Interface | What flows |
|---|---|---|---|
| **Game Time & Tick (#1)** | Orchestrator subscribes (foreground only) | `tick_fired(int)` signal | Drives `_on_tick_fired` per-tick execution. Orchestrator is the **only** dungeon-run subscriber to this signal (Economy's drip subscription is independent). |
| **Hero Roster (#9)** | Orchestrator reads at `DISPATCHING` only | `roster.get_formation_heroes() -> Array[HeroInstance]` | Snapshot is deep-copied into `RunSnapshot.formation_snapshot` and frozen for the dispatch. Subsequent Roster mutations do NOT affect the active run (until reassignment per C.7). |
| **Combat Resolution (#11)** | Orchestrator calls (via injected `combat_resolver: CombatResolver` instance — Pass 3D) | `combat_resolver.emit_events_in_range(formation, floor, range_start, range_end, error_logger?) -> CombatTickEvents` per foreground tick; `combat_resolver.compute_offline_batch(formation, floor, tick_budget, error_logger?) -> CombatBatchResult` per offline replay; one-shot `combat_resolver.compute_offline_batch(..., 0)` at `DISPATCHING` to derive snapshot caches. The Orchestrator holds ONE instance injected at construction (production: `DefaultCombatResolver.new()`; tests: spy subclass of `CombatResolver`). See Combat GDD #11 Pass 3D for the DI shape. | Returns kill events, loop completions, first-clear marker, hp_bonus_factor, survived flag. Orchestrator owns all signal emission to Economy + UI; Combat itself emits no signals. All calls are instance method calls — no static dispatch. |
| **Matchup Resolver (#10)** | Orchestrator calls (per-kill foreground; per-archetype cached offline) | `MatchupResolver.resolve_formation_matchup(formation_snapshot, archetype) -> MatchupResult` | Returns `is_advantaged: bool`. Used to select `MATCHUP_GOLD_MULTIPLIER` for kill-gold attribution. (Note: Combat ALSO calls Resolver internally per Pass 2B for the throughput-factor path. The Orchestrator's call is the gold-path, independent of Combat's tempo-path. Both paths converge on the same `is_advantaged` boolean per the Resolver's stateless contract.) |
| **Biome/Dungeon DB (#7)** | Orchestrator reads at `DISPATCHING` | `Floor` resource lookup | Reads `floor.enemy_list`, `floor.floor_index`, `floor.is_boss_floor`, `floor.expected_clear_time_seconds`. Floor reference is held on snapshot for the duration of the dispatch. |
| **Economy System (#4)** | Orchestrator calls | `Economy.add_gold(int)`, `Economy.try_award_floor_clear(floor_index, bonus_amount)` | All gold attribution flows through these two entry points. Economy's `try_award_floor_clear` is the per-lifetime idempotency dispatcher (C.6 layer 3). Drip is NOT routed through Orchestrator — Economy subscribes to `tick_fired` independently for drip. |
| **Save/Load System (#3)** | Orchestrator persists | `RunSnapshot.to_dict() / from_dict()` via Save/Load's serialization layer | Snapshot is saved on app suspend + on dispatch transitions. Restored on app resume; resume path uses elapsed offline tick budget from Game Time (#1) to feed `compute_offline_run`. |
| **Offline Progression Engine (#12, undesigned)** | Orchestrator is called by | `DungeonRunOrchestrator.compute_offline_run(tick_budget) -> OfflineRunResult` | Single batch call per dispatched floor in the offline budget. Result feeds Return-to-App screen's events log + Economy's gold credit. |
| **Dungeon Run View (#24, undesigned)** | Orchestrator emits to (signals on Orchestrator autoload) | `enemy_killed(tier, archetype, advantaged)`, `boss_killed(enemy_id)`, `floor_cleared_first_time(floor_index)` signals | UI consumes for kill-pop animation, boss-death cinematic, floor-clear UI moment. Orchestrator owns all signal emission; UI is a passive consumer. Subscribers connect via `DungeonRunOrchestrator.enemy_killed.connect(...)` etc. at `_ready`. Pass 4C: signals are owned by the Orchestrator autoload, not a separate EventBus. |
| **Floor Unlock System (#16, Designed 2026-04-20 pending review)** | Orchestrator queries at `DISPATCHING` | `FloorUnlock.is_unlocked(floor_index) -> bool` | Validation gate. Locked floors return `NO_RUN` from `DISPATCHING` with a UI hint. |
| **Formation Assignment (#17, undesigned)** | Orchestrator listens to (direct signal on Formation Assignment node) | `formation_reassignment_committed(new_formation: Array[HeroInstance])` signal (write intent, triggers C.7 reassignment policy). `formation_browse_opened` (informational only — Orchestrator ignores). Pass 4C: signals split into read/write per C.7. | Orchestrator connects to `formation_reassignment_committed` at `_ready`. Casual roster browse does NOT trigger run-end; only explicit commit does. `MID_RUN_REASSIGN_WARNING_ENABLED` confirmation dialog gates commit emission. |

**Bidirectional consistency guarantees**:

1. **Foreground/offline parity (Pillar 1)** — Orchestrator's foreground tick loop (C.3) and offline replay path (C.4) MUST produce identical `(kills_by_archetype, kills_by_tier, total_gold, floor_clear_bonus_paid, floor_cleared_first_time signal-emission count and payload)` for any `(formation, floor, T)` tuple. Combat AC-COMBAT-10 guarantees the underlying event determinism; Orchestrator AC-ORC-09 (Section H) verifies the gold-attribution layer end-to-end. **I.15 FIX 2026-04-21** — `floor_cleared_first_time` signal-emission parity was added to this invariant after Floor Unlock #16 Pass-9 flagged that C.4 was silently omitting the emission (foreground emitted at C.3 line 249; offline at C.4 pre-fix emitted nothing). Silent omission caused a Pillar 1 violation for any player earning a first-clear while offline — gold credited, next floor stayed LOCKED. Regression test: AC-ORC-09 must assert signal count == 1 with matching payload in both paths.
2. **Combat statelessness preserved** — Orchestrator MUST NOT mutate Combat's input arrays (`formation_snapshot.duplicate(true)` at DISPATCHING; floor reference is read-only by contract). Combat AC-COMBAT-01 + AC-COMBAT-18 verify Combat's side; Orchestrator AC-ORC-08 verifies the snapshot's deep-copy invariant.
3. **Idempotency layers are non-overlapping** — Combat (stateless markers) / Orchestrator (per-dispatch flag) / Economy (per-lifetime flag). Each layer's failure mode is bounded: a Combat marker bug shows as duplicate first-clear emissions in tests; an Orchestrator flag bug shows as duplicate `Economy.try_award_floor_clear` calls (Economy still no-ops correctly); an Economy flag bug shows as actual duplicate gold credit. Defense in depth.

## D. Formulas

The Orchestrator owns very few formulas in its own right — most of the math is upstream (Combat owns DPS/ticks_per_loop/kill schedule; Economy owns BASE_KILL/BASE_DRIP/FLOOR_CLEAR_BONUS lookups). The formulas below are the routing layer that combines upstream values into the gold-attribution and tick-windowing decisions the Orchestrator is responsible for.

Notation follows Combat D-header convention: `floori`/`ceili`/`maxi`/`mini` (int-returning variants per GDScript 4.6) — never `floor`/`ceil` (float-returning).

### D.1 attribute_kill_gold

The `attribute_kill_gold` formula is defined as:

`attribute_kill_gold(tier, advantaged, losing_run) = floori(BASE_KILL[tier] × matchup_multiplier × loot_factor)`

where `matchup_multiplier = MATCHUP_GOLD_MULTIPLIER if advantaged else 1.0` and `loot_factor = LOSING_RUN_LOOT_FACTOR if losing_run else 1.0`.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| enemy tier | `tier` | int | 1 – 3 | From `KillEvent.tier`; index into Economy's `BASE_KILL` lookup |
| matchup advantage | `advantaged` | bool | true/false | From `_matchup_resolver.resolve_formation_matchup(formation, archetype).is_advantaged` (Pass 5C instance call on injected MatchupResolver; see §J). |
| losing flag | `losing_run` | bool | true/false | From `RunSnapshot.losing_run` (cached at DISPATCHING from `hp_bonus_factor < 0.5`) |
| base kill bonus | `BASE_KILL[tier]` | int | 10 – 80 | Economy lookup: `BASE_KILL[1]=10`, `BASE_KILL[2]=35`, `BASE_KILL[3]=80` |
| matchup multiplier | `MATCHUP_GOLD_MULTIPLIER` | float | 1.5 (default) | Registry constant; safe range 1.0–2.5 |
| losing loot factor | `LOSING_RUN_LOOT_FACTOR` | float | 0.5 (default) | Registry constant; safe range 0.0–0.95 |
| output | `attribute_kill_gold` | int | 5 – 120 | Gold credited to Economy per kill |

**Output Range**: `5` (tier-1 kill, neutral, losing → `floori(10 × 1.0 × 0.5) = 5`) to `120` (tier-3 kill, advantaged, non-losing → `floori(80 × 1.5 × 1.0) = 120`).

**Worked example — L13 W+M+W on F4 (advantaged on bruiser, non-losing), kills a Thorn Guardian (tier 3 bruiser):**
```
matchup_multiplier = 1.5  (W+M+W has n=2 Warriors counter-bruiser → advantaged)
loot_factor        = 1.0  (hp_bonus_factor saturates at 1.0 on F4 → losing_run = false)
attribute_kill_gold = floori(80 × 1.5 × 1.0) = floori(120.0) = 120
```

**Worked example — Synthetic LOSING run, tier-1 bruiser kill, neutral matchup:**
```
matchup_multiplier = 1.0
loot_factor        = 0.5  (hp_bonus_factor < 0.5 triggered LOSING)
attribute_kill_gold = floori(10 × 1.0 × 0.5) = floori(5.0) = 5
```

### D.2 attribute_floor_clear_bonus

`attribute_floor_clear_bonus(floor_index, losing_run) = floori(FLOOR_CLEAR_BONUS[floor_index] × loot_factor)`

where `loot_factor = LOSING_RUN_LOOT_FACTOR if losing_run else 1.0`.

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| floor index | int | 1 – 5 | From `RunSnapshot.floor.floor_index` |
| `FLOOR_CLEAR_BONUS[floor_index]` | int | 500 – 18000 | Economy lookup: **1-based index** — `FLOOR_CLEAR_BONUS[1]=500, [2]=1200, [3]=3000, [4]=7500, [5]=18000`. `FLOOR_CLEAR_BONUS[0]` is undefined (sentinel / out-of-range — must never be accessed; guard: `assert(floor_index >= 1 and floor_index <= 5)`). |
| `LOSING_RUN_LOOT_FACTOR` | float | 0.5 (default) | Registry constant |
| output | int | 250 – 18000 | One-shot gold credit on first-clear |

**FLOOR_CLEAR_BONUS indexing convention (locked in Pass 4A)**: The array is **1-based**. `floor_index` is 1–5 throughout the Orchestrator and matches the bonus array index directly — no off-by-one arithmetic (`FLOOR_CLEAR_BONUS[floor_index]`, never `FLOOR_CLEAR_BONUS[floor_index - 1]`). This convention eliminates a class of off-by-one footguns and aligns with the F1–F5 naming convention used everywhere else. `FLOOR_CLEAR_BONUS[0]` is reserved as an undefined sentinel; runtime code must assert `floor_index ∈ [1, 5]` before indexing. See registry entry notes for the authoritative convention declaration.

**Output Range**: `250` (F1 first-clear under LOSING → `floori(500 × 0.5)`) to `18000` (F5 first-clear non-losing). Per Combat Rule 9 + Pass 2B locked decision 4: **first-clear bonus is NOT exempt from LOSING** — a player who first-clears a floor on an underlevelled run gets the diminished (50%) bonus *immediately*. **Pass 5A (ADR-0002) supersedes the prior "cannot be re-cleared later to reclaim" claim**: a subsequent non-LOSING clear of the same floor credits the remaining delta up to `FLOOR_CLEAR_BONUS[floor_index]` via Economy's monotonic-credit gate (`floor_clear_bonus_credited: Dictionary[int, int]`). The per-lifetime *ceiling* is unchanged (total credited ≤ `FLOOR_CLEAR_BONUS[floor_index]`); the per-lifetime *shape* now permits partial first-clear → full reclaim on WIN. See E.5, E.15, and ADR-0002 for the full walkthrough.

**Worked example — F3 first-clear, non-losing run:**
```
floor_index = 3
FLOOR_CLEAR_BONUS[3] = 3000
loot_factor = 1.0
attribute_floor_clear_bonus = floori(3000 × 1.0) = 3000
```

**Worked example — F1 first-clear, LOSING run:**
```
floor_index = 1
FLOOR_CLEAR_BONUS[1] = 500
loot_factor = 0.5
attribute_floor_clear_bonus = floori(500 × 0.5) = 250
```

### D.3 next_emit_window

Foreground tick-range arithmetic for `emit_events_in_range`:

`next_emit_window(last_emitted_tick, current_tick) = (last_emitted_tick, current_tick]`

(Half-open interval: `last_emitted_tick` exclusive, `current_tick` inclusive.) Combat's `emit_events_in_range` interprets this as "emit events whose `kill_tick` falls in `(range_start, range_end]`." Combat AC-COMBAT-10 (foreground/offline parity) depends on this windowing being non-overlapping and gap-free across consecutive tick calls.

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `last_emitted_tick` | int | 0 – 576000 | Watermark on `RunSnapshot`; advances per tick. Initialized to `dispatched_at_tick` on entry to `ACTIVE_FOREGROUND`. |
| `current_tick` | int | last_emitted_tick + 1 ... | Argument passed by `tick_fired(n)` |

**Edge case — duplicate-tick / zero-width range (Pass 5D — re-review β item 4 closure)**: If `current_tick == last_emitted_tick`, the range is zero-width. The Orchestrator **rejects this case at the guard level** (`<=` comparison — see `_on_tick_fired` below) rather than calling Combat with an empty range. Rationale: the duplicate-tick case produces no observable work (Combat's empty-result contract is well-defined, but the call is pure overhead) and asserting "no call on duplicate tick" is simpler than "call with empty range returns empty events." Sub-AC 03-no-call-if-no-tick-advance codifies this at the test layer. The initial-tick case (immediately after entering `ACTIVE_FOREGROUND` from `DISPATCHING`) still works because Game Time always delivers `tick_fired(dispatched_at_tick + 1)` on the next emission (Game Time #1 Rule 4 — tick counter monotonically increments), so the first post-dispatch call satisfies `current_tick > snapshot.last_emitted_tick` and enters the normal path.

**Edge case — clock rewind (D.3 guard, Pass 4A)**: If `current_tick < last_emitted_tick` (caused by system clock rollback from timezone change, manual adjustment, or aggressive NTP correction), the half-open interval `(last_emitted_tick, current_tick]` is inverted — passing this range to `emit_events_in_range` would produce undefined behavior. The Orchestrator guards this at the top of `_on_tick_fired`:

```gdscript
func _on_tick_fired(current_tick: int) -> void:
    if state != State.ACTIVE_FOREGROUND: return
    # Combined guard (Pass 5D — β item 4): rejects both clock-rewind (<) AND duplicate-tick (==)
    # via a single <= comparison. Normal ticks satisfy current_tick > last_emitted_tick strictly.
    if current_tick <= snapshot.last_emitted_tick:
        if current_tick < snapshot.last_emitted_tick:
            push_warning("Orchestrator: clock rewind detected (current=%d, last_emitted=%d); snapping to last_emitted_tick" % [current_tick, snapshot.last_emitted_tick])
            # Clamp forward — do NOT replay missed ticks; player is never penalized (Pillar 1)
        # duplicate-tick case (== ) is silent — no warning, no emit; next real tick resumes.
        return
    # ... proceed with normal emit_events_in_range call
```

This guard ensures the player is never penalized (Pillar 1) — a rewind is treated as a brief stall, not a rollback. See E.14 for the full edge case specification.

### D.4 aggregate_kill_gold_offline (Pass 4A — loop-walk rewrite)

**Design note (Pass 4A)**: The prior version of D.4 used a dict-walk over `CombatBatchResult.kills_by_archetype`. That approach had two compounding defects: (1) it produced different totals from the foreground path on partial loops (dict-walk attributes gold as if the final loop completed fully; foreground stops at the actual kill boundary); (2) `kills_by_archetype` collapses tier information — a tier-1 bruiser and tier-3 bruiser are both "bruiser", so `attribute_kill_gold(tier, ...)` cannot recover the correct `tier` per kill. The fix: walk the **ordered kill schedule** in tick order, attribute gold per kill, stop when the kill's loop-relative tick exceeds the partial-loop budget. This is the correct algorithm. `kills_by_archetype` and `kills_by_tier` from `CombatBatchResult` are retained for UI summary and telemetry purposes only and are **NOT used for gold attribution**.

**Data structure note (Pass 4A contract for Combat GDD)**: The loop-walk requires an ordered per-kill list with `(archetype, tier, is_boss)` recoverable per kill. `RunSnapshot.kill_schedule` (an `Array[KillEvent]` cached at DISPATCHING from Combat's `_kill_schedule_for_loop` output) already has this shape. `CombatBatchResult` does NOT need to surface an ordered kill list for complete loops — the Orchestrator reconstructs these from `snapshot.kill_schedule × loops_completed`. However, the partial final loop's kills MUST be recoverable per kill in tick order. **See flagged Combat contract addendum (Pass 3E)** at the end of this section for the `partial_loop_kills` field requirement.

**Algorithm (ordered loop-walk):**

```
aggregate_kill_gold_offline(
    kill_schedule:       Array[KillEvent],   # from RunSnapshot — loop-relative, in kill_tick order
    loops_completed:     int,                # from CombatBatchResult.loops_completed (complete loops only)
    partial_loop_kills:  Array[KillEvent],   # from CombatBatchResult — ordered kills in the partial final loop
    matchup_cache:       Dictionary[StringName, bool],
    losing_run:          bool
) -> Dictionary:  # { total_kill_gold: int }

    var total: int = 0

    # --- Complete loops ---
    # All entries in kill_schedule fired exactly `loops_completed` times.
    # O(kill_schedule.size()) regardless of loops_completed.
    for kill in kill_schedule:
        var advantaged: bool = matchup_cache[kill.archetype]
        var per_kill_gold: int = attribute_kill_gold(kill.tier, advantaged, losing_run)  # D.1
        total += per_kill_gold * loops_completed

    # --- Partial final loop ---
    # Walk partial_loop_kills in tick order (already ordered by Combat).
    # These are enemies that died within the partial loop before tick_budget expired.
    for kill in partial_loop_kills:
        var advantaged: bool = matchup_cache[kill.archetype]
        var per_kill_gold: int = attribute_kill_gold(kill.tier, advantaged, losing_run)  # D.1
        total += per_kill_gold

    return { total_kill_gold = total }
```

**Why this is correct on partial loops**: Suppose `tick_budget` expires mid-loop after enemies 1 and 2 die but before enemy 3. The complete-loop walk attributes gold for enemies 1+2+3 exactly `loops_completed` times (correct — all complete loops ran to completion). The partial-loop walk then attributes gold for enemies 1 and 2 only (via `partial_loop_kills`, which Combat populates with the kills that occurred before `tick_budget` expired). Enemy 3 receives no gold — it did not die this offline session. The foreground path produces the same result by definition: `emit_events_in_range` returns only kill events whose `kill_tick` fell within the tick window, which is exactly what the partial-loop kills represent.

**Full-loop case**: If `tick_budget` aligns exactly with a loop boundary, `partial_loop_kills` is empty — the partial-loop walk contributes 0 gold. The algorithm degenerates correctly to the complete-loop-only case with no special handling.

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `kill_schedule` | `Array[KillEvent]` | ≤5 entries per MVP floor | From `RunSnapshot.kill_schedule`, fixed at DISPATCHING; loop-relative kill events in tick order |
| `loops_completed` | int | 0 – 3740 (F1 worst case) | From `CombatBatchResult.loops_completed` (complete loops only, not counting the partial) |
| `partial_loop_kills` | `Array[KillEvent]` | 0 – kill_schedule.size() | From `CombatBatchResult.partial_loop_kills` (new field — see Pass 3E flagged note); ordered kills in the partial final loop; empty if budget aligned to a loop boundary |
| `matchup_cache` | `Dictionary[StringName, bool]` | ≤5 entries | Per-archetype advantaged lookup, built once at DISPATCHING. **Coverage contract (Pass 5D — re-review δ item 11 closure)**: `_build_matchup_cache(formation, kill_schedule)` MUST insert a `(archetype, bool)` entry for **every distinct archetype present in `kill_schedule`** before returning. Since `partial_loop_kills ⊆ one_full_loop ⊆ kill_schedule`, the complete-loop walk and the partial-loop walk CANNOT encounter an archetype that is not already a key in the cache — no `KeyError` is possible. If a future refactor introduces a path where partial_loop_kills could contain an archetype not in kill_schedule (e.g., mid-run enemy injection — V1.0 scope speculation), the cache builder MUST be extended first, and this AC + the coverage contract updated. A defensive `cache.get(archetype, false)` would hide a legitimate bug. |
| `losing_run` | bool | true/false | From `RunSnapshot.losing_run` |
| `total_kill_gold` | int | 0 – unbounded | Total kill gold credited to Economy for this offline batch |

**Performance**: O(kill_schedule.size() + partial_loop_kills.size()) = O(enemies_per_floor) regardless of `loops_completed`. For the AC-COMBAT-14 worst case (3,740 loops on F1, 4 enemies/loop), complete-loop work = `4` multiplications + `4 × 3740` integer additions. Under 1 ms on min-spec mobile.

**Worked example — F1 offline batch, 3 complete loops + partial with 2 kills:**

F1 kill schedule (loop-relative): `[{archetype: bruiser, tier: 1, kill_tick: 40}, {archetype: caster, tier: 1, kill_tick: 80}, {archetype: armored, tier: 1, kill_tick: 115}, {archetype: bruiser, tier: 1, kill_tick: 154}]`

Formation: L1 W+M+R, advantaged on bruiser + caster (matchup_cache = {bruiser: true, caster: true, armored: false}). `losing_run = false`.

```
Complete loops (loops_completed = 3):
  bruiser kill: attribute_kill_gold(1, true, false) = floori(10 × 1.5 × 1.0) = 15  → 15 × 3 = 45
  caster kill:  attribute_kill_gold(1, true, false) = 15  → 15 × 3 = 45
  armored kill: attribute_kill_gold(1, false, false) = floori(10 × 1.0 × 1.0) = 10  → 10 × 3 = 30
  bruiser kill: 15  → 15 × 3 = 45
Complete loop subtotal = 45 + 45 + 30 + 45 = 165

Partial final loop (partial_loop_kills = [bruiser, caster]):
  bruiser kill: 15
  caster kill:  15
Partial subtotal = 30

total_kill_gold = 165 + 30 = 195
```

**Foreground path verification (parity check)**: The same F1 run via foreground across T ticks producing 3 complete loops + 2 partial kills yields: (3 bruiser loops × 15) + (3 caster loops × 15) + (3 armored loops × 10) + (3 bruiser loops × 15) + (1 partial bruiser × 15) + (1 partial caster × 15) = 165 + 30 = 195. Parity confirmed.

---

**Flagged Combat contract addendum — Pass 3E required:**

The loop-walk requires `CombatBatchResult.partial_loop_kills: Array[KillEvent]` — an ordered list of kill events that occurred in the partial final loop (between the start of the last incomplete loop and `tick_budget`). As of Pass 4A, `CombatBatchResult` (Combat GDD #11 C.4) does NOT expose this field; it only exposes `kills_by_archetype` and `kills_by_tier` (aggregate counts). A small Combat GDD addendum (Pass 3E) is required to add this field. The field can be derived from the same per-tick walk Combat already performs internally to compute `loops_completed` — no new algorithm is needed, only the result surfaced.

Until Pass 3E lands, the Orchestrator MUST NOT use `kills_by_archetype` dict-walk for gold attribution. MVP interim option: if `partial_loop_kills` is absent, derive the partial-loop kills by walking `snapshot.kill_schedule` from index 0 and stopping at the first entry whose `kill_tick > (tick_budget % snapshot.ticks_per_loop)`. This is arithmetically equivalent because the kill schedule is stable across loops (Combat Rule 8). Explicit partial-loop kill list from Combat is preferred for clarity and test-assertability (AC-ORC-09 parity test can compare per-kill attribution directly).

## E. Edge Cases

### E.1 Player closes app mid-foreground-run

**Scenario**: App is in `ACTIVE_FOREGROUND` with `loop_counter = 7`, `last_emitted_tick = 28543`. Player suspends the app (mobile background, desktop alt-tab, Steam Deck sleep).

**Behavior**: Save/Load (#3) writes `RunSnapshot.to_dict()` to disk on app suspend. Orchestrator transitions `ACTIVE_FOREGROUND → ACTIVE_OFFLINE_REPLAY` (or stays in `ACTIVE_FOREGROUND` if the suspend was brief — under `REWIND_TOLERANCE_SECONDS = 300`, which Game Time #1 manages). On resume, Game Time computes elapsed tick budget; Offline Engine #12 calls `compute_offline_run(budget)`; Orchestrator advances `last_emitted_tick`, accumulates gold, then transitions back to `ACTIVE_FOREGROUND` if the app is now visible. Per Pillar 1: the player gets the same total gold they would have earned watching foreground for the full elapsed time.

### E.2 tick_fired skipped (frame drop / pause)

**Scenario**: `tick_fired` arrives at tick 100, then again at tick 105 (5-tick gap). Orchestrator's `last_emitted_tick = 100`, then `current_tick = 105`.

**Behavior**: Orchestrator calls `emit_events_in_range(formation, floor, 100, 105)`. Combat returns all kill events in `(100, 105]`. No state is lost — the closed-form schedule is time-anchored, not tick-incremented (Combat E.7). `last_emitted_tick` advances to 105 for the next call. This is the same property that lets foreground and offline produce identical event sequences (Combat Rule 2 invariant).

### E.3 Player reassigns formation mid-run

**Scenario**: Player has an active L8 formation on Floor 3, opens Roster screen, swaps a Mage for a Rogue.

**Behavior** (per C.7): Orchestrator transitions `ACTIVE_FOREGROUND → RUN_ENDED → DISPATCHING → ACTIVE_FOREGROUND` with the new formation snapshot. All idempotency flags reset on the new snapshot. The previous in-progress loop is **discarded** (no partial-loop gold credited — the player loses progress on that loop). UI affordance: confirmation dialog "Reassigning will end your current run" before the swap commits.

### E.4 Empty formation reaches DISPATCHING

**Scenario**: Player taps "Dispatch" with no heroes assigned (UI bug or test fixture).

**Behavior**: Orchestrator validates at `DISPATCHING` entry: `if formation.is_empty(): state = NO_RUN; emit_validation_failed("empty_formation"); return`. No `compute_offline_batch` call is made. UI displays an inline hint via the `validation_failed` signal; Formation Assignment Screen highlights the empty slots. Combat is never called with an empty formation (defensive depth — Combat's E.1 also handles this gracefully if it slips through).

### E.5 LOSING re-run after first-clear already awarded full bonus (Combat E.5 deferred contract)

**Scenario**: Player first-cleared F4 yesterday under a strong L13 W+M+W formation — full 7,500g first-clear bonus awarded; Economy's `floor_clear_bonus_credited[4] = 7500` per ADR-0002. Today they dispatch a deliberately weak formation on a synthetic LOSING fixture (or V1.0 hard-mode floor where `hp_bonus_factor < 0.5` is reachable).

**Behavior**: Orchestrator in `ACTIVE_FOREGROUND` or `ACTIVE_OFFLINE_REPLAY` processes kills with `losing_run = true` → `attribute_kill_gold` applies `LOSING_RUN_LOOT_FACTOR = 0.5`. When the loop counter eventually crosses 0→1, Combat emits `first_clear_in_range = true`. Orchestrator's per-dispatch flag (`floor_clear_emitted`) is initially false (new dispatch), so it calls `Economy.try_award_floor_clear(4, attribute_floor_clear_bonus(4, true) = 3750)`. **Economy's monotonic gate detects `bonus_amount = 3750 <= floor_clear_bonus_credited[4] = 7500` and NO-OPS the call** (per ADR-0002) — the bonus is not paid again. The kill bonuses still flow at half rate. Net effect: the LOSING re-run earns half-rate kill gold + **full-rate drip** + zero clear bonus (the already-credited path). Drip is unaffected by `losing_run` per Pass 4B-Economy A2 (Pass 2B decision 4 superseded — drip is run-outcome-independent by architecture; see Economy review log Pass 4B-Economy entry + Economy C.2.3 LOSING_RUN scope note).

This is the contract Combat E.5 deferred: **per-lifetime first-clear gate beats per-dispatch idempotency on re-runs**. The Orchestrator's `floor_clear_emitted` flag prevents within-dispatch duplicate emission; Economy's `floor_clear_bonus_credited` prevents cross-dispatch over-payment via the monotonic-ceiling semantic. Both layers fire correctly here — the Orchestrator emits once (to Economy, which no-ops), but the kill-gold halving still applies to all kills regardless of whether the floor has been previously cleared. Pass 5A (ADR-0002) reshaped the per-lifetime gate from boolean to monotonic int; the semantic in this scenario (WIN-first-then-LOSING → no additional credit) is unchanged, but the gate now also handles the inverse ordering (E.15 below).

### E.15 LOSING first-clear, then WIN re-claim (ADR-0002 "no fail state" path)

**Scenario**: Player's first-ever clear of F3 happens on a LOSING run — a weak formation reached the loop boundary but `hp_bonus_factor = 0.35 < 0.5`. Orchestrator credits `floori(FLOOR_CLEAR_BONUS[3] × 0.5) = floori(2500 × 0.5) = 1250g`. Economy records `floor_clear_bonus_credited[3] = 1250`. A week later, the player re-dispatches F3 with a stronger L10 formation; `hp_bonus_factor = 0.9 > 0.5` → `losing_run = false`.

**Behavior**: The WIN re-run's first-clear transition passes `Economy.try_award_floor_clear(3, 2500)`. Economy detects `bonus_amount = 2500 > floor_clear_bonus_credited[3] = 1250`, credits the delta `2500 - 1250 = 1250g`, and updates `floor_clear_bonus_credited[3] = 2500`. The player's total lifetime F3 first-clear bonus is now the full 2,500g, paid in two installments (1,250g LOSING + 1,250g WIN). This is the "no fail state — losing run returns partial loot" pillar expressed mechanically: the halved portion is deferred, not destroyed.

**Further re-runs on F3** are all no-ops regardless of outcome, because `bonus_amount ≤ 2500 = already_credited` in every case. This preserves the anti-exploit monotonic-ceiling property (see ADR-0002 §Semantic consequences table).

**Orchestrator-side invariant**: The Orchestrator itself is unchanged — it still emits exactly one `try_award_floor_clear(floor_index, amount)` call per dispatch gated by `snapshot.floor_clear_emitted`. The re-claim logic is entirely Economy-owned. The Orchestrator's AC-ORC-04 Sub-AC "losing-then-win" verifies the two-call sequence end-to-end at the Orchestrator boundary.

**Player-facing framing** (Narrative team owns final copy): Return-to-App screen on the LOSING clear reads "F3 first clear (losing run) — 1,250g, +1,250g pending on win"; on the WIN re-claim it reads "F3 completed — reclaimed 1,250g." This prevents the "why did I only get half?" confusion that 17b BLOCKING-2 surfaced.

### E.6 Save loaded mid-run (resume path)

**Scenario**: Player suspended the app at `last_emitted_tick = 28543, loop_counter = 7, floor_clear_emitted = true` (cleared F3 during this dispatch). 4 hours pass. Player relaunches.

**Behavior**: Save/Load (#3) restores `RunSnapshot` from disk. Game Time (#1) computes `elapsed_offline_seconds = 14400` → `offline_tick_budget = 288000` (well under the 576000 cap). Offline Engine (#12) calls `Orchestrator.compute_offline_run(288000)`. Orchestrator processes the batch in `ACTIVE_OFFLINE_REPLAY`: `floor_clear_emitted` is already true (preserved from the suspend snapshot), so no second first-clear emission even if the loop counter wraps thousands of times during the offline period — the per-dispatch idempotency holds across save/load. After replay, transitions to `ACTIVE_FOREGROUND` if app is now visible.

### E.7 Floor unlocked mid-run on a not-yet-unlocked floor

**Scenario**: Save corruption or test fixture causes Orchestrator to receive a `DISPATCHING` request for F5 when F5 is not unlocked (Floor Unlock #16 returns `is_unlocked(5) = false`).

**Behavior**: Orchestrator queries Floor Unlock at `DISPATCHING` entry: `if not FloorUnlock.is_unlocked(floor.floor_index): state = NO_RUN; emit_validation_failed("floor_locked", floor_index); return`. UI hint via `validation_failed` signal directs the player to the Floor Unlock requirements screen. No `compute_offline_batch` call. Defensive: even if Floor Unlock reports inconsistent state, the floor cannot enter active execution.

### E.8 Boss enemy in mid-queue position (Combat I.Q8 resolution)

**Scenario** (per Combat E.10): A future floor has `enemy_list = [hollow_brute×3, ancient_rootking×1, glowmoth×1]` — boss in position 4 of 5.

**Behavior** (per C.8): Orchestrator forwards Combat's `is_boss = true` flag faithfully. `boss_killed(enemy_id)` fires when entry index 3 (the boss) dies, regardless of whether it's mid-queue. The fanfare cinematic plays mid-loop; the loop continues to entry index 4 (glowmoth) afterward. Floor-clear emission still fires only at the loop boundary (entry 4's death), not at the boss's death. Authoring guideline (Biome E.5) recommends bosses always be the last entry; Orchestrator does not enforce.

### E.9 hp_bonus_factor exactly at 0.5 boundary

**Scenario** (per Combat E.8): `formation_total_hp / floor_total_enemy_attack == 0.5` exactly (e.g., 60/120 on a synthetic floor).

**Behavior**: Orchestrator caches `losing_run = (hp_bonus_factor < 0.5)` at DISPATCHING. At exactly 0.5, the strict-less comparison is FALSE → `losing_run = false` → no LOSING multipliers applied. Matches Combat Rule 9 + Combat E.8 inclusive `>=` semantics on `survived`. Tested by AC-ORC-04 boundary fixture (mirrors Combat AC-COMBAT-06-boundary).

### E.10 Offline tick_budget = 0 (e.g., relaunch within seconds of last save)

**Scenario**: Player suspended app 5 seconds ago, relaunches. Game Time computes `offline_tick_budget = 100` ticks. Or in the corner case: relaunch within the same tick → budget = 0.

**Behavior**: For `tick_budget = 0`, Orchestrator's `compute_offline_run(0)` calls Combat's `compute_offline_batch(formation, floor, 0)` which returns `loops_completed = 0, first_clear_tick = -1, kills_by_* = {}, final_tick = 0`. Orchestrator credits zero gold, no first-clear emission, transitions to `ACTIVE_FOREGROUND`. No-op path. For very small budgets (1–100 ticks), partial loop processing applies — Combat may return 0 or 1 kills depending on the kill schedule, Orchestrator credits accordingly.

### E.11 Combat returns empty CombatBatchResult (Combat E.3 — empty enemy_list)

**Scenario** (defensive depth — should never happen per Biome E.5 floor-load validation): Floor reaches DISPATCHING with `enemy_list = []`.

**Behavior**: Combat returns `{kills_by_archetype={}, kills_by_tier={}, loops_completed=0, first_clear_tick=-1, hp_bonus_factor=0.0, survived=false, final_tick=tick_budget}` and logs `push_error("CombatResolver: floor [floor.id] has empty enemy_list; aborting run")`. Orchestrator's `RunSnapshot.floor_was_valid = false` (the optional field per C.2 / Combat I.Q11). State transitions to `RUN_ENDED` with a validation error surfaced to UI. Economy receives no gold credit. **No floor-clear bonus is awarded** even though `loops_completed = 0` could trivially be misread as "first clear" — the Orchestrator's `floor_was_valid` gate prevents the misread. This is the value of the Combat I.Q11 `floor_was_valid` field: it lets the Orchestrator distinguish "formation lost badly" (kills = 0 with `floor_was_valid = true`) from "floor authoring bug" (kills = 0 with `floor_was_valid = false`) without pattern-matching on empty kills arrays.

### E.12 Fresh-save player attempts F5 dispatch — SUPERSEDED by Floor Unlock GDD #16 (Floor-Unlock-Propagation-Edit-3, 2026-04-20)

**Status**: The F1-only MVP stub described below is **superseded 2026-04-20** by Floor Unlock GDD #16 (`design/gdd/floor-unlock-system.md`). The Orchestrator no longer inlines an `is_unlocked` stub — it delegates to `FloorUnlockSystem.is_unlocked(floor_index)` per GDD #16 §C.1 R1 + §C.3. AC-ORC-13 is **promoted from ADVISORY to BLOCKING** in the Classification Summary.

**Scenario (historical, for audit trail)**: Player has a fresh save (no prior floors unlocked). They navigate to Formation Assignment and somehow select F5 (UI bug, test fixture, or if the UI does not gate floor selection). They tap Dispatch.

**Behavior under the now-superseded Pass 4A stub**: The Orchestrator's inline `is_unlocked` returned `true` only for `floor_index == 1`. For `floor_index == 5`, `is_unlocked(5)` returned `false`. DISPATCHING validation fails → `run_ended` trigger → `RUN_ENDED` with `validation_failed("floor_locked", {floor_index: 5})`.

**Behavior under GDD #16 (authoritative 2026-04-20+)**: `FloorUnlockSystem` (autoload rank 4, before Orchestrator at rank 5) owns `_unlock_state: Dictionary[String, int]` per-biome. On fresh save, `_unlock_state = {"forest_reach": 0}` — `is_unlocked(1)` returns `true`, `is_unlocked(2..5)` returns `false` until progressive first-clears advance the counter. Same fresh-save outcome for F5 dispatch (rejected with `validation_failed("floor_locked", {floor_index: 5})`); same end-state `RUN_ENDED`. **The MVP playtest pathology described in the original rationale (18-min-per-kill F5 on fresh save) remains prevented.** AC-ORC-13 (now BLOCKING) verifies this at the Orchestrator/FloorUnlockSystem integration boundary; GDD #16 AC-FU-13 provides the independent integration-test anchor.

**Rationale for the original F1-only stub (preserved for context)**: The prior fallback ("all floors unlocked") would permit a fresh-save dispatch to F5, where a Level-1 formation faces a ~4818 HP boss and generates one kill every 18 minutes of sim time — a scenario that would surface as a broken-looking Return-to-App screen in first-playtest ("0 kills, 0 gold" after 8h offline). The F1-only fallback prevented this without requiring #16 to be designed first.

### E.13 ACTIVE_OFFLINE_REPLAY error path (D.2 state machine fix)

**Scenario**: The Offline Progression Engine calls `compute_offline_run(tick_budget)` while the Orchestrator is in `ACTIVE_OFFLINE_REPLAY`. During execution, `combat_resolver.compute_offline_batch(...)` throws an unhandled error (e.g., DataRegistry returns null for an enemy ID that was valid at dispatch but became invalid after a hot-reload in development), or `snapshot.floor` becomes null (corrupted save recovery edge case).

**Behavior**: The Orchestrator catches the error, logs `push_error("Orchestrator: offline replay failed — [error message]")`, fires `validation_failed.emit("offline_replay_error", {reason: msg})`, and transitions `ACTIVE_OFFLINE_REPLAY → RUN_ENDED` via the `run_ended` trigger. Any gold credited to Economy before the error is retained (no rollback — partial credit is better than a silent zero, per Pillar 1). The Return-to-App screen shows a partial rewards summary plus an error toast. The player can dispatch again from `RUN_ENDED`.

**State machine note**: This is the `ACTIVE_OFFLINE_REPLAY + run_ended → RUN_ENDED` cell in the C.1 matrix (also reached via a `replay_failed` trigger which maps to the `run_ended` trigger internally). The Orchestrator must never be left permanently stuck in `ACTIVE_OFFLINE_REPLAY` — this error transition is the safety valve.

### E.14 Clock rewind during ACTIVE_FOREGROUND (D.3 rewind guard)

**Scenario**: Player is on an active foreground run (`ACTIVE_FOREGROUND`, `last_emitted_tick = 5000`). The system clock rewinds — e.g., the player manually adjusts the clock backward by 10 minutes, or NTP corrects a clock that was running ahead, or the Steam Deck wakes from a suspend state where the clock rolled back during sleep. The next `tick_fired(current_tick)` call arrives with `current_tick = 4800` (< `last_emitted_tick = 5000`).

**Behavior**: The D.3 clock-rewind guard in `_on_tick_fired` fires: `push_warning("Orchestrator: clock rewind detected (current=4800, last_emitted=5000); snapping to last_emitted_tick")`. The tick is discarded (early return). `last_emitted_tick` is NOT updated (stays at 5000). The Orchestrator resumes normally on the next `tick_fired` that arrives with `current_tick >= 5000`. The player loses no gold from the rewind — the ticks that "didn't happen" (4800–5000 range) are simply not re-emitted. This is strictly better for the player than a re-emit (which would duplicate the kills in that range) and strictly better than a crash.

**Why not `snap and replay`**: Replaying backwards ticks would duplicate kill events already processed at tick 5000 for kills in the range (4800, 5000], awarding duplicate gold. That would violate AC-ORC-05 (first-clear exactly once) and Economy correctness. The clamp-forward approach (ignore the rewind) is the Pillar-1-correct choice: the player is never penalized, and economy correctness is preserved.

**NTP vs clock-manipulation distinction**: The `REWIND_TOLERANCE_SECONDS` guard in Game Time (#1) handles large rewinds at session-launch (anti-cheat). The D.3 guard handles mid-session rewinds in the foreground tick loop — a different code path. Both guards exist independently; neither replaces the other.

## F. Dependencies

### Upstream Dependencies (systems Orchestrator reads from)

| Upstream | Hard/Soft | Interface | Locked contract |
|---|---|---|---|
| **Game Time & Tick** (`design/gdd/game-time-and-tick.md`) | Hard | `tick_fired(n: int)` signal in foreground; `offline_elapsed_seconds`/`offline_tick_budget` derivations on resume | Orchestrator subscribes to `tick_fired` only in `ACTIVE_FOREGROUND`; unsubscribes on transition out. |
| **Hero Roster** (`design/gdd/hero-roster.md`) | Hard | `roster.get_formation_heroes() -> Array[HeroInstance]` at `DISPATCHING` only | Snapshot is deep-copied (`.duplicate(true)`); never re-read mid-dispatch. |
| **Combat Resolution** (`design/gdd/combat-resolution.md`) | Hard | `combat_resolver.compute_offline_batch(...)` (called at DISPATCHING + per offline replay); `combat_resolver.emit_events_in_range(...)` (called per foreground tick). Pass 3D — DI shape: `combat_resolver: CombatResolver` is injected at Orchestrator construction; production wiring passes `DefaultCombatResolver.new()`; tests pass a spy subclass to assert call arguments and control return values. See Combat GDD #11 Pass 3D. | Combat is stateless per Combat Rule 1; Orchestrator passes immutable snapshot inputs and consumes typed return values. All calls are instance method calls on the injected field — no static dispatch. |
| **Matchup Resolver** (`design/gdd/class-vs-enemy-matchup-resolver.md`) | Hard | `matchup_resolver.resolve_formation_matchup(formation, archetype) -> MatchupResult` (Pass 5C — instance method on injected `_matchup_resolver: MatchupResolver`; production wiring uses `DefaultMatchupResolver.new()`; tests inject a spy subclass per §J Mode-1 pattern). See Matchup Resolver GDD #10 Pass 5C Rule 1. | Per-kill in foreground; per-archetype cached in offline. Stateless per Resolver Rule 12 (the pure-function rule). |
| **Biome/Dungeon DB** (`design/gdd/biome-dungeon-database.md`) | Hard | `Floor` resource lookup | Floor reference is read-only; Orchestrator does not mutate. |
| **Save/Load System** (`design/gdd/save-load-system.md`) | Hard | `orchestrator.get_save_data() -> Dictionary` / `orchestrator.load_save_data(data)` consumer contract; namespace key `"orchestrator"`; `RunSnapshot.to_dict()` / `from_dict()` round-trip per Save/Load Rules 10–14 (Pass 4B-SaveLoad) | Returns `{"active_run": snapshot.to_dict()}` if run active; `{}` if NO_RUN. `to_dict` serializes: formation as Array[Dict] (per-element hero.to_dict — Pass-5F-propagation 2026-04-21 element-layer canonical); floor as `floor_id: String` (serialize-by-id); kill_schedule as Array[Dict] (per-element kill.to_dict — Combat Pass 3F required); losing_run as explicit bool; matchup_cache as plain Dict[String, bool]. `from_dict` resolves floor via DataRegistry; returns null on failure → NO_RUN. Save/Load AC-ORC-12 is the verification gate. |
| **Floor Unlock System** (#16, undesigned) | Soft (transitive — falls back to **"only F1 unlocked"** on fresh save until #16 ships; MVP scaffolding decision, Pass 4A) | `FloorUnlock.is_unlocked(floor_index) -> bool` at `DISPATCHING` | When Floor Unlock GDD lands, the contract here is fixed. Pre-#16 MVP scaffolding: Orchestrator's `is_unlocked` stub returns `true` only for `floor_index == 1`; all other floors return `false` and are rejected at DISPATCHING with `validation_failed("floor_locked", {floor_index: n})`. This prevents a fresh-save player from dispatching to F5 and hitting the 18-min/kill scenario (see E.7 + E.12). Remove when #16 GDD lands. |

### Downstream Dependents (systems that depend on Orchestrator)

| Consumer | Hard/Soft | Interface | What they consume |
|---|---|---|---|
| **Offline Progression Engine** (#12, undesigned) | Hard | `Orchestrator.compute_offline_run(tick_budget) -> OfflineRunResult` | Single batch call per dispatched floor in offline budget. |
| **Economy System** (`design/gdd/economy-system.md`) | Hard | `Economy.add_gold(int)`, `Economy.try_award_floor_clear(floor_index, bonus_amount)` (ADR-0002: monotonic-credit semantic — Economy credits `max(0, bonus_amount - already_credited)` against `floor_clear_bonus_credited[floor_index]: int`; supersedes the Pass 4B-Economy boolean-gate design, which is retired in Economy Pass 5B) | Per-kill gold + first-clear bonus payments. LOSING first-clear leaves a pending delta reclaimable on a subsequent WIN (see E.5 + E.15 + ADR-0002). |
| **Dungeon Run View** (#24, undesigned) | Hard | Orchestrator-owned signals: `enemy_killed(tier, archetype, advantaged)`, `boss_killed(enemy_id)`, `floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool)`, `validation_failed(reason, payload)` — connect via `DungeonRunOrchestrator.[signal].connect(...)` at `_ready` | Kill-pop animation, boss cinematic, floor-clear UI, error toasts. Pass 4C: signals moved from non-existent EventBus to Orchestrator autoload. **2026-04-20 Floor-Unlock-Propagation-Edit-3**: `floor_cleared_first_time` payload extended with `biome_id` + `losing_run` to support Floor Unlock GDD #16 subscription (also consumed by Unlock/Victory UI #25 for new-high vs replay classification). Additive extension — #24 may ignore the new params in MVP. |
| **Formation Assignment** (#17, undesigned) | Soft | `formation_reassignment_committed(new_formation: Array[HeroInstance])` signal (write-intent; triggers C.7 option a). `formation_browse_opened` (informational only; Orchestrator ignores). Pass 4C: browse/commit signal split per C.7. | Formation Assignment owns its UI flow; Orchestrator owns the lifecycle response. Casual roster browse does NOT end the run. |
| **Return-to-App Screen** (#20, undesigned) | Soft | Reads `OfflineRunResult` produced by `compute_offline_run` (typically via Offline Engine's chain) | Display "+22g × 18 kills, F3 cleared" summary. |
| **Class Synergy System** (#32, V1.0 first-pass 2026-05-09) | Hard — formula + RunSnapshot extension | New: `DungeonRunOrchestrator.snapshot_synergy_for_run(formation_snapshot)` adds `synergy_id: String` to `RunSnapshot` (frozen at dispatch; immutable for the run per ADR-0001 mid-run reassignment policy). Per-kill `attribute_kill_gold` and new `attribute_kill_xp` formulas extend with a `synergy_multiplier` factor — see `class-synergy-system.md` §C.3. The 5-factor product becomes `BASE_KILL × matchup × loot × synergy × prestige`. |
| **Prestige System** (#31, V1.0 first-pass 2026-05-09) | Hard — formula extension | Per-kill `attribute_kill_gold` + `attribute_kill_xp` formulas extend with a `prestige_multiplier` factor sourced via `HeroRoster.get_prestige_multiplier()`. No RunSnapshot field needed (multiplier is global, not run-scoped). Per `prestige-system.md` §C.3. |

### Bidirectional Consistency

- `design/gdd/combat-resolution.md` — Combat C.2 lists Orchestrator-owned states (`NO_RUN`, `DISPATCHING`, `ACTIVE_FOREGROUND`, `ACTIVE_OFFLINE_REPLAY`, `RUN_ENDED`). This GDD's C.1 is the canonical implementation; matches.
- `design/gdd/combat-resolution.md` — Combat Rule 7 + AC-COMBAT-09b explicitly defer per-dispatch idempotency to Orchestrator. This GDD's C.6 + AC-ORC-05 implement that contract.
- `design/gdd/combat-resolution.md` — Combat E.5 LOSING re-run contract is implemented in this GDD's E.5 + AC-ORC-04.
- `design/gdd/combat-resolution.md` — Combat I.Q7 (mid-run reassignment), I.Q8 (boss fanfare), I.Q11 (floor_was_valid) all RESOLVED by this GDD's C.7, C.8, and C.2 respectively.
- `design/gdd/economy-system.md` — Economy AC H-03 per-lifetime first-clear idempotency is the Layer 3 of C.6's three-layer model. Orchestrator calls `Economy.try_award_floor_clear`; Economy's gate is authoritative. **Pass 5A / ADR-0002** reshapes this gate from boolean (`floors_cleared_bonus_awarded: Dictionary[int, bool]`) to monotonic int (`floor_clear_bonus_credited: Dictionary[int, int]`) — enables LOSING first-clear re-claim on a subsequent WIN; Economy GDD Pass 5B will land the spec-doc changes.
- `design/gdd/economy-system.md` — Economy's `add_gold` signature (`int`) and `try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool` signature match. **RESOLVED 2026-04-20 (Pass 4B-Economy A1)**: Economy GDD #4 C.2.3a defines the method; AC H-14 covers per-lifetime idempotency.

### New Contracts This GDD Introduces

1. `DungeonRunOrchestrator` autoloaded Node with state machine + `compute_offline_run(tick_budget) -> OfflineRunResult` public API. **Pass 3D (Combat GDD #11 DI revision)**: The Orchestrator receives `combat_resolver: CombatResolver` at construction. Production wiring passes `DefaultCombatResolver.new()` at game boot (e.g., in the autoload `_ready` or via explicit injection from a bootstrap scene); tests pass a spy subclass of `CombatResolver` to assert call arguments and control return values. No consumer should call `CombatResolver.new()` directly — always `DefaultCombatResolver.new()` in production.
2. `RunSnapshot` value type (RefCounted) with `to_dict()`, `from_dict()`, `equals()`
3. `OfflineRunResult` value type (RefCounted) — schema TBD pending Return-to-App / Offline Engine GDD work (Open Q I.1)
4. **Orchestrator-owned signals** (Pass 4C: previously attributed to a non-existent `EventBus` autoload; now owned directly by the `DungeonRunOrchestrator` autoload Node per Godot idiom for node-owned signals): `enemy_killed(tier: int, archetype: StringName, advantaged: bool)`, `boss_killed(enemy_id: StringName)`, `floor_cleared_first_time(floor_index: int)`, `validation_failed(reason: StringName, payload: Dictionary)`. Subscribers connect via `DungeonRunOrchestrator.enemy_killed.connect(...)` etc. at `_ready`. Rationale for dropping EventBus: Godot idiom for node-owned signals; narrow publisher/subscriber topology (one publisher, ≤3 downstream consumers) does not justify a project-wide bus. Future systems with cross-cutting signal topology may reintroduce a bus via a separate GDD and ADR.
5. Economy interface: `Economy.try_award_floor_clear(floor_index: int, bonus_amount: int)` — to be added to Economy GDD #4 in next revision

## G. Tuning Knobs

The Orchestrator owns very few knobs in its own right — most of the system's behavior is determined by upstream knobs (Combat's `SPEED_BASE`, Economy's `BASE_KILL`/`BASE_DRIP`/`FLOOR_CLEAR_BONUS`, Game Time's `offline_cap_seconds`).

### G.1 Primary Knobs

| Knob | Default | Safe range | Category | What it affects | Risk if pushed high | Risk if pushed low |
|---|---|---|---|---|---|---|
| `DISPATCH_DEBOUNCE_MS` | **250** | 100 – 1000 | UX | Anti-spam on the Dispatch button — minimum interval between consecutive `DISPATCHING` transitions. Prevents accidental double-tap re-dispatch. | Player feels the button is laggy; double-tap intent (rapid re-dispatch on a different floor) blocked. | Accidental double-dispatch fires twice; UI dead state during the duplicate `DISPATCHING` frame. |
| `OFFLINE_REPLAY_CHUNK_TICKS` | **0** *(disabled — single-shot)* | 0 – 576000 | Performance | If non-zero, splits offline replay into chunks of this size (Offline Engine #12 caller may chunk for frame-budget reasons). Default 0 = single `compute_offline_batch` call per floor. | Chunks too large: visible frame hitches on resume from long offline. | Chunks too small: dispatch overhead dominates; resume becomes slow. |
| `MID_RUN_REASSIGN_WARNING_ENABLED` | **true** | true / false | UX | If true, Formation Assignment Screen displays "Reassigning will end your current run" confirmation (per C.7 + ADR-0001). Surfaces the mid-F5-boss progress-loss risk to the player before commit; does not recover the loss. Pass 5A recommends pairing with telemetry counter `mid_run_reassignments_during_floor_5_boss` (not MVP-blocking) to monitor whether the V1.0-deferred option (c) upgrade path becomes warranted. | N/A | Players accidentally lose run progress; trust in Pillar 1 erodes. |

### G.2 Why No Per-Floor / Per-Class Knobs

The Orchestrator does not own any per-floor difficulty knobs, per-class behavior knobs, or per-archetype routing knobs. Per-floor difficulty lives in Biome DB (`floor_total_hp`, `expected_clear_time_seconds`). Per-class stats live in Class DB. Per-archetype matchup factors live in Combat (`MATCHUP_THROUGHPUT_FACTOR_*`) and Economy (`MATCHUP_GOLD_MULTIPLIER`). Orchestrator's job is to *route* — the values it routes between are owned by upstream systems. This separation lets a designer tune combat tempo (Combat's `SPEED_BASE`) or gold pace (Economy's `BASE_KILL` table) without touching Orchestrator code, and lets Orchestrator be tuned for UX (button debounce, replay chunking) without touching content.

## H. Acceptance Criteria

All criteria use Given-When-Then format. **13 criteria total: 12 BLOCKING + 1 ADVISORY.** Includes the Combat-deferred pair (AC-ORC-04 covers AC-COMBAT-07b; AC-ORC-05 covers AC-COMBAT-09b).

### AC-ORC-01 — State Machine Transitions Valid (Logic, BLOCKING)

*Pass 5D (re-review γ item 5 closure): `push_error` exactly-once assertion now uses the §J.4 `error_logger: Callable` DI instead of a GdUnit4-mock of the global `push_error` (which has no reliable intercept mechanism). Closes GD9 at the AC layer.*

**GIVEN** the Orchestrator in any state from {`NO_RUN`, `DISPATCHING`, `ACTIVE_FOREGROUND`, `ACTIVE_OFFLINE_REPLAY`, `RUN_ENDED`}, constructed via §J Mode-1 with an injected **`recording_logger: Callable`** set via `orchestrator.set_error_logger(recording_logger)` before any trigger fires (the recorder is a closure that appends its message argument to a test-owned `Array[String]`),
**WHEN** any state-transition trigger fires (`dispatch_pressed`, `formation_changed`, `app_suspended`, `app_resumed`, `offline_replay_complete`, `run_ended`),
**THEN** the resulting state matches the complete 5×6 matrix defined in C.1; every valid transition lands in the documented next state; every "Invalid" cell causes **exactly one** invocation of the injected `recording_logger` (observed via `recorded_messages.size() == 1` + message content containing the state + trigger pair). Zero invocations for valid transitions. The Orchestrator's call-site pattern `if _error_logger.is_valid(): _error_logger.call(msg) else: push_error(msg)` (per §J.4) routes the message to the recorder during test + to `push_error` in production.

*Verification*: parameterized unit test exhaustively walking **all 30 cells** of the 5×6 state×trigger matrix per `tests/unit/orchestrator/test_state_machine_transitions.gd`. Setup:

```gdscript
var recorded_messages: Array[String] = []
var recording_logger: Callable = func(msg: String) -> void: recorded_messages.append(msg)
var orchestrator := DungeonRunOrchestrator.new()
orchestrator.set_combat_resolver(SpyCombatResolver.new())
orchestrator.set_matchup_resolver(DefaultMatchupResolver.new())
orchestrator.set_error_logger(recording_logger)
add_child(orchestrator)
```

For each cell: drive the trigger; assert post-trigger state equals the documented next state (or remains unchanged for invalid cells); for valid cells assert `recorded_messages.is_empty()`; for invalid cells assert `recorded_messages.size() == 1` + the message contains the exact state + trigger names. The test covers all 30 combinations — no cells left unasserted. Pass 4A: 19 previously-undefined invalid cells specified. Pass 5D: error-intercept mechanism via §J.4 error_logger DI specified.

### AC-ORC-02 — Dispatch Snapshot Caches Combat Outputs (Logic, BLOCKING)

*Pass 5D (re-review γ item 6 closure): prior spec referenced `Combat.formation_dps_per_tick()` and `Combat.hp_bonus_factor()` as oracle APIs — these are NOT public methods on the Pass 3D `CombatResolver` interface (they are internal helpers inside `_kill_schedule_for_loop`). Rewritten to use the `CombatBatchResult` fields returned by the DISPATCHING-time `compute_offline_batch(formation, floor, 0)` one-shot call as the oracle — these ARE contract-public per Combat Pass 3 §Rule 3. This avoids introducing new public helpers on CombatResolver (which would be a Combat Pass 3E scope item).*

**GIVEN** an L13 W+M+R formation + F4 + state `NO_RUN`; a spy `CombatResolver` that records the one-shot dispatch call and returns a fixed `CombatBatchResult` with known fields (e.g., `formation_dps_per_tick = 1.580, hp_bonus_factor = 0.9523, ticks_per_loop = 3240, kill_schedule` = array of 4 `KillEvent`s matching F4's 4-Thorn-Guardian enemy_list),
**WHEN** the player dispatches (state → `DISPATCHING`), the one-shot `combat_resolver.compute_offline_batch(formation, floor, 0)` completes and the Orchestrator caches its outputs into `RunSnapshot`,
**THEN** the resulting `RunSnapshot` satisfies (all fields sourced from the spy's return value or the Orchestrator's derivation):
- `snapshot.formation_dps_per_tick` passes `is_equal_approx(snapshot.formation_dps_per_tick, 1.580)` — exact match with spy return
- `snapshot.hp_bonus_factor` passes `is_equal_approx(snapshot.hp_bonus_factor, 0.9523)` — exact match with spy return
- `snapshot.ticks_per_loop == 3240` — exact match with spy return (int equality, no tolerance)
- `snapshot.kill_schedule.size() == 4` — matches spy return's array length AND F4's `enemy_list.size()`
- `snapshot.losing_run == (snapshot.hp_bonus_factor < 0.5)` — evaluated at DISPATCHING against the cached `hp_bonus_factor`; for 0.9523, `losing_run == false`. *Note:* `losing_run` is an **Orchestrator-derived** field (not a Combat return field); AC-ORC-09 boundary sub-AC verifies the strict-less-than at exactly 0.5.
- `snapshot.floor_clear_emitted == false` — Orchestrator-initialized at DISPATCHING; never true at dispatch time
- `snapshot.last_emitted_tick == snapshot.dispatched_at_tick` — Orchestrator-initialized; foreground tick loop starts from this baseline
- `snapshot.loop_counter == 0` — Orchestrator-initialized; no loops completed yet

*Verification*: unit test in `tests/unit/orchestrator/test_dispatch_snapshot_cache.gd` using §J Mode-1 test pattern. `SpyCombatResolver` overrides `compute_offline_batch(...)` to return a fixture `CombatBatchResult` with known field values. Test asserts the snapshot field-by-field against the fixture return + Orchestrator's derivations. No public helpers on `CombatResolver` required; the test treats Combat as a black box whose return value is the oracle. If Combat Pass 3E later adds public `formation_dps_per_tick(formation)` / `hp_bonus_factor(formation, floor)` helpers for use by Matchup Assignment Screen (#23) or other consumers, this AC remains valid — its oracle is the `CombatBatchResult` contract, which is independent of those helpers.

### AC-ORC-03 — Foreground Tick Window Forwarding (Logic, BLOCKING)

**GIVEN** state `ACTIVE_FOREGROUND` with an L13 W+M+R formation on F4, and `snapshot.last_emitted_tick = 100`,
**WHEN** `tick_fired(105)` is received,
**THEN** the Orchestrator calls `combat_resolver.emit_events_in_range` exactly once on the injected instance with arguments `(snapshot.formation_snapshot, snapshot.floor, 100, 105)` (exclusive-start 100, inclusive-end 105 per Combat Rule 2); after the call, `snapshot.last_emitted_tick == 105`.

**Sub-AC 03-initial-tick** — **GIVEN** a fresh `ACTIVE_FOREGROUND` transition where `snapshot.last_emitted_tick == snapshot.dispatched_at_tick` (no ticks emitted yet for this dispatch), **WHEN** the first `tick_fired(dispatched_at_tick + 1)` arrives, **THEN** the spy records exactly one call with `range_start_tick = dispatched_at_tick` and `range_end_tick = dispatched_at_tick + 1`; `snapshot.last_emitted_tick == dispatched_at_tick + 1`. Covers the initial-tick boundary condition (S11).

**Sub-AC 03-no-call-if-no-tick-advance** *(Pass 5D — re-review β item 4 closure; the C.3 guard `<` was tightened to `<=` so this sub-AC is achievable against the shipping code)* — **GIVEN** `snapshot.last_emitted_tick = 100`, **WHEN** `tick_fired(100)` arrives (duplicate tick — same value as `last_emitted_tick`; a zero-width window), **THEN** the Orchestrator does NOT call `combat_resolver.emit_events_in_range`; the spy records zero invocations for this event; `snapshot.last_emitted_tick` remains 100; state remains `ACTIVE_FOREGROUND`; no `push_warning` fires (the duplicate-tick branch is silent per the C.3 pseudocode — only the strict-rewind branch warns). Defensive guard against duplicate tick delivery; relies on the `<=` guard in C.3 (Pass 5D).

*Verification*: Unit test in `tests/unit/orchestrator/test_foreground_tick_forwarding.gd`. Uses a spy subclass of `CombatResolver` (Pass 3D DI shape):

```gdscript
class SpyCombatResolver extends CombatResolver:
    var recorded_calls: Array = []
    func emit_events_in_range(
        formation: Array,
        floor,
        range_start_tick: int,
        range_end_tick: int,
        error_logger: Callable = Callable()
    ) -> CombatTickEvents:
        recorded_calls.append({
            "formation": formation,
            "floor": floor,
            "range_start_tick": range_start_tick,
            "range_end_tick": range_end_tick
        })
        return CombatTickEvents.new()
```

Orchestrator is constructed via §J Mode-1 test pattern (Pass 5C): `var orchestrator := DungeonRunOrchestrator.new(); orchestrator.set_combat_resolver(combat_spy); orchestrator.set_matchup_resolver(DefaultMatchupResolver.new()); add_child(orchestrator)` (the `add_child` triggers `_ready()`, which sees the pre-populated fields and does NOT overwrite them per §J.2). The pre-Pass-5C `DungeonRunOrchestrator.new(combat_resolver: spy)` constructor form is **replaced by setter-based DI** — Node autoloads cannot accept constructor args in production wiring, so the tests standardize on setters for call-site parity. Each sub-AC asserts `combat_spy.recorded_calls.size()` (1 for the primary and 03-initial-tick cases; 0 for 03-no-call-if-no-tick-advance), the exact call args, and `snapshot.last_emitted_tick` post-state.

### AC-ORC-04 — LOSING_RUN_LOOT_FACTOR End-to-End (Integration, BLOCKING — covers AC-COMBAT-07b)

**`test_floor_high_attack` fixture spec (Pass 4C, Q2)**: This test uses a synthetic floor that does NOT exist in the production `FloorDatabase` / DataRegistry. Construct it directly as a local `Floor.new()` in the test file — do NOT add it to `assets/data/floors/` or any data registry.

```
# test-only fixture — construct inline, never load from DataRegistry
var test_floor_high_attack := Floor.new()
test_floor_high_attack.floor_index = 99          # sentinel — outside valid F1-F5 range, unique to tests
test_floor_high_attack.floor_id    = "test_floor_high_attack"
test_floor_high_attack.enemy_list  = [
    { "enemy_id": "synthetic_bruiser", "archetype": StringName("bruiser"), "tier": 1,
      "enemy_attack": 120, "enemy_hp": 200, "is_boss": false }
]
# hp_bonus_factor derivation: formation_total_hp / floor_total_enemy_attack
#   Solo L1 Rogue: current_hp ≈ 55 (per Class DB baseline)
#   floor_total_enemy_attack = 120
#   hp_bonus_factor = 55 / 120 = 0.458  →  losing_run = true (< 0.5 threshold)
```

**GIVEN** the `test_floor_high_attack` fixture (above), formation = solo L1 Rogue (HP ≈ 55), `tick_budget = 60000`, kill schedule producing exactly N kills per loop with M loops in budget,
**WHEN** `compute_offline_run(60000)` is called on the Orchestrator with `combat_resolver` spy injected,
**THEN** total gold credited to Economy via `add_gold` calls equals `expected_kill_gold × LOSING_RUN_LOOT_FACTOR (0.5)` to within ±1 gold (integer truncation tolerance), AND if a first-clear fired, the `try_award_floor_clear` argument equals `floori(FLOOR_CLEAR_BONUS[floor_index] × 0.5)` (halved per Combat Rule 9). **Drip is NOT asserted in this test** — drip is run-outcome-independent per Pass 4B-Economy A2 (Pass 2B locked decision 4 superseded; the halving now applies to kill gold + floor-clear bonus only). If Economy's drip subscription fires during the test, it fires at full rate; the test must not assert a halved drip total.

*Verification*: Economy spy capturing all `add_gold` and `try_award_floor_clear` calls; sum and compare against expected formula output: `expected_kill_gold = sum over all kills of floori(BASE_KILL[kill.tier] × 1.0 × 0.5)` (neutral matchup — solo Rogue vs bruiser is neutral per Resolver). `test_floor_high_attack` is a test-only fixture; it does NOT ship in production FloorDatabase. Resolves Combat AC-COMBAT-07b end-to-end.

**Economy spy source-tagging contract (Pass 5D — re-review γ item 7 closure)**: Drip gold (from Economy's independent `tick_fired` subscription) and kill gold (from the Orchestrator's `Economy.add_gold(attributed_kill_gold)` calls) both flow into `Economy.add_gold(amount: int)` in production, making a naive `recorded_add_gold_total` non-deterministic for this AC (drip would inflate the sum by a run-duration-dependent amount). The test's Economy spy MUST distinguish kill gold from drip gold; three acceptable patterns (pick one per test file, use consistently across all Economy-involving ACs):

1. **Recommended — drip-disabled fixture**: inject an Economy spy whose `tick_fired` subscription is not connected (the spy never accumulates drip). The spy's `add_gold` only receives Orchestrator-routed kill gold + `try_award_floor_clear` amounts. Simplest; chosen default for AC-ORC-04, AC-ORC-05, AC-ORC-09, AC-ORC-11.
2. **Per-source tagged methods**: spy exposes `add_kill_gold(amount)` + `add_drip_gold(amount)` as wrappers; production `Economy.add_gold` is split at the spy layer only. Requires Orchestrator + Drip to call distinct methods, which does not match production (single `add_gold` path). Rejected for AC-ORC-04 because it would require production API changes; acceptable only for integration tests that explicitly need both paths live.
3. **Time-windowed subtraction**: enable drip but record `gold_balance_before` and `gold_balance_after`, then subtract expected drip (`expected_drip_total = tick_budget × BASE_DRIP × formation_factor`) to isolate kill gold. Works but introduces a derivation dependency on Economy's drip formula — fragile to drip-curve rebalance (Pass 3B open item). Not chosen for Pass 5D; flagged for a later integration test if a genuine both-paths-live scenario requires it.

For AC-ORC-04: use Pattern 1. The Economy spy is constructed as `var economy_spy := EconomySpy.new()` where `EconomySpy` is a test-only class whose `add_gold(int)` records to `recorded_kill_gold_calls: Array[int]` and whose `try_award_floor_clear(int, int)` records to `recorded_floor_clear_calls: Array[Dictionary]`. The spy is NOT connected to `GameTimeAndTick.tick_fired`. Assertions: `sum(recorded_kill_gold_calls) == expected_kill_gold` + `recorded_floor_clear_calls.size() <= 1` with the correct args iff first-clear fires.

**Sub-AC 04-losing-first-clear-then-win-credits-delta** (Pass 5A, per ADR-0002 — "no fail state" re-claim path)

**GIVEN** `test_floor_high_attack` fixture as above; Economy spy with initial state `floor_clear_bonus_credited = {}` (empty — F3-equivalent floor_index 99 has never been cleared); solo L1 Rogue formation (LOSING path — `hp_bonus_factor ≈ 0.458 < 0.5`); dispatch run to completion,
**WHEN** the LOSING dispatch's first-clear transition fires, **AND THEN** a second dispatch is run with a *different* formation that is NOT LOSING on the same synthetic floor (e.g., a test-only strong formation fixture whose `hp_bonus_factor > 0.5` — construct inline; synthetic matching the test fixture's attack value),
**THEN** after the first dispatch: Economy spy records `try_award_floor_clear(99, floori(FLOOR_CLEAR_BONUS[99] × 0.5))` called once; `floor_clear_bonus_credited[99] == floori(FLOOR_CLEAR_BONUS[99] × 0.5)`; the spy's running `add_gold` total equals the half-bonus amount (no kill gold counted — assume zero kills in the minimal fixture, or subtract kill gold from the running total). After the second (WIN) dispatch: Economy spy records `try_award_floor_clear(99, FLOOR_CLEAR_BONUS[99])` called once; the *delta* credited (second dispatch's `add_gold` total minus the second dispatch's kill gold) equals `FLOOR_CLEAR_BONUS[99] - floori(FLOOR_CLEAR_BONUS[99] × 0.5)`; `floor_clear_bonus_credited[99] == FLOOR_CLEAR_BONUS[99]` (fully credited).

*Fixture note*: For the assertion target to be unambiguous, the fixture sets a convenient `FLOOR_CLEAR_BONUS[99] = 1000` in the test-only registry stub — the split becomes 500 LOSING + 500 WIN re-claim. Production `FLOOR_CLEAR_BONUS[1..5]` values are untouched by this test. `test_floor_high_attack` and its WIN-variant companion `test_floor_winnable` are both test-only fixtures constructed inline, not registered with DataRegistry.

*Verification*: The sub-AC's assertion is on the ECONOMY spy's running state after each dispatch — not on the Orchestrator's state (the Orchestrator's `floor_clear_emitted` resets between dispatches by design; that's not the re-claim property). This is explicitly an integration test of the contract defined by ADR-0002. Resolves 17b BLOCKING-2 end-to-end.

### AC-ORC-05 — First-Clear Bonus Once Per Dispatch (Integration, BLOCKING — covers AC-COMBAT-09b)

**GIVEN** a single offline dispatch on F1 with `tick_budget = 576000` (8h cap) producing 3,740 complete loops at `ticks_per_loop = 154` (per Combat AC-COMBAT-08) and `snapshot.floor_clear_emitted == false` at dispatch start,
**WHEN** `compute_offline_run(576000)` is called with a spy subclass of `CombatResolver` injected and an Economy spy capturing `try_award_floor_clear` calls,
**THEN** `Economy.try_award_floor_clear(1, 500)` is called **exactly once** (on the loop counter's 0→1 transition; `FLOOR_CLEAR_BONUS[1] = 500` for a non-LOSING run), regardless of the 3,740 loop completions; `snapshot.floor_clear_emitted == true` after the call; `snapshot.loop_counter == 3740`.

**Sub-AC 05-multi-call** — **GIVEN** a foreground dispatch where `tick_fired` arrives N times and the spy subclass of `CombatResolver` returns `CombatTickEvents.first_clear_in_range = true` on every call (simulating a pathological or buggy Combat re-reporting the transition every tick), **WHEN** all N calls process, **THEN** `Economy.try_award_floor_clear` is called exactly once (the Orchestrator's `snapshot.floor_clear_emitted` flag gates all subsequent calls); `snapshot.floor_clear_emitted == true` after the first emission.

**Sub-AC 05-foreground-first-clear** — **GIVEN** foreground `ACTIVE_FOREGROUND` on F1 with `snapshot.loop_counter = 0` and `snapshot.floor_clear_emitted == false`, **WHEN** the first `tick_fired` call returns a `CombatTickEvents` with `first_clear_in_range = true` (the 0→1 loop boundary fell within that tick's range), **THEN** `Economy.try_award_floor_clear(1, 500)` is called exactly once; `snapshot.loop_counter` increments to 1; `snapshot.floor_clear_emitted == true`. Subsequent `tick_fired` calls that cross further loop boundaries (loop_counter 1→2, 2→3, …) do NOT re-call `try_award_floor_clear` — the flag gates them.

**Sub-AC 05-losing-first-clear** — **GIVEN** a LOSING run on F1 (`snapshot.losing_run = true`, meaning `hp_bonus_factor < 0.5`) with `snapshot.floor_clear_emitted == false`, **WHEN** the first-clear transition occurs (foreground or offline), **THEN** `Economy.try_award_floor_clear(1, 250)` is called exactly once (`floori(500 × 0.5) = 250` per Combat Rule 9 + Pass 4B-Economy A2 — floor-clear bonus is halved on LOSING runs; drip is NOT halved per the same decision). If `try_award_floor_clear` is called a second time (e.g., by a re-dispatched run after the per-lifetime Economy gate already fired), the Economy method returns `false` (idempotent no-op) and no gold is awarded. The Orchestrator's `floor_clear_emitted` flag independently prevents the second call at the Orchestrator boundary.

*Verification*: Integration test in `tests/unit/orchestrator/test_first_clear_once.gd`. Uses two spies:

1. A spy subclass of `CombatResolver` (Pass 3D DI shape) that controls the `first_clear_in_range` flag on the returned `CombatTickEvents` (foreground path) or the `first_clear_tick` value on `CombatBatchResult` (offline path).
2. An Economy spy (injected via the same DI pattern) that captures all `try_award_floor_clear(floor_index, bonus_amount)` invocations — records count and args.

For each sub-AC, assert `economy_spy.recorded_calls.size() == 1`, the exact `(floor_index, bonus_amount)` args, and `snapshot.floor_clear_emitted == true`. The 05-multi-call sub-AC additionally drives N > 1 `tick_fired` calls with `first_clear_in_range = true` each time and asserts the count remains 1. Resolves Combat AC-COMBAT-09b end-to-end at the Orchestrator boundary.

### AC-ORC-06 — Mid-Run Reassignment Ends Run (Integration, BLOCKING)

**GIVEN** state `ACTIVE_FOREGROUND` with `loop_counter = 3, last_emitted_tick = 5000`,
**WHEN** `formation_reassignment_committed(new_formation)` fires (player confirmed a hero swap via Formation Assignment; Pass 4C — write-side signal per C.7 browse/commit split, NOT fired by `formation_browse_opened`),
**THEN** state transitions `ACTIVE_FOREGROUND → RUN_ENDED → DISPATCHING → ACTIVE_FOREGROUND` within one frame; new `RunSnapshot` reflects the new formation; `floor_clear_emitted == false` on the new snapshot; `last_emitted_tick == new_dispatched_at_tick` (not the prior watermark).

### AC-ORC-07 — Empty Formation Rejected at DISPATCHING (Logic, BLOCKING)

*Pass 5D (re-review β, item 3 closure — body↔Summary contradiction): prior body said "state remains NO_RUN"; Classification Summary said "transitions to RUN_ENDED". Per C.1 state matrix (Pass 4A: `DISPATCHING → run_ended → RUN_ENDED` on validation failure), RUN_ENDED is the correct post-state — it's what the UI observes, what AC-ORC-13 asserts for the sibling case (locked floor), and what Return-to-App / Guild Hall screens listen for. The "remains NO_RUN" wording was a Pass-1 artifact not updated when the validation-failure path was formalized in Pass 4A. Fixed below.*

**GIVEN** state `NO_RUN` and an empty formation array `[]`,
**WHEN** dispatch is triggered,
**THEN** state transitions `NO_RUN → DISPATCHING → RUN_ENDED` (via `run_ended` trigger on validation failure per C.1); `validation_failed.emit("empty_formation", {})` fires during the DISPATCHING phase; state is `RUN_ENDED` after the sequence (matches AC-ORC-13 pattern for consistency across all dispatch-time validation failures); `CombatResolver` is not called; `_matchup_resolver.resolve_formation_matchup` is not called (empty formation short-circuits before any resolver call). The Orchestrator's `set_error_logger`-injected recorder (§J.4 pattern) captures zero error messages — the empty-formation case is a **validation failure**, not an error, and routes through `validation_failed` rather than `push_error`.

*Verification*: unit test in `tests/unit/orchestrator/test_empty_formation_rejected.gd`. Subscribes to `validation_failed`; asserts exactly one emission with reason `"empty_formation"`; asserts final state `== State.RUN_ENDED`; asserts `combat_spy.recorded_calls.is_empty()`. Uses §J Mode-1 test pattern with `DefaultMatchupResolver.new()` (any matchup_resolver works — the test short-circuits before matchup is consulted). Re-review β item 3 closed.

### AC-ORC-08 — Snapshot Deep-Copy Invariant (Logic, BLOCKING)

*Pass 4C rewrite (Q4): prior assertion shape was ambiguous — "snapshot is unchanged" without specifying which mutations and which fields to check. Rewritten with 3 concrete sub-ACs.*

**Sub-AC 08-array-identity — Formation array is a distinct instance**

**GIVEN** an active dispatch with `snapshot.formation_snapshot` holding a deep copy of 3 HeroInstance objects from HeroRoster,
**WHEN** the original Roster's formation array has a new hero appended AFTER `DISPATCHING` (array size goes from 3 → 4),
**THEN** `snapshot.formation_snapshot.size() == 3` (unchanged); `snapshot.formation_snapshot` is a **different Array instance** from the Roster's formation array (identity check: they are not the same object reference). The append affected only the source array; the snapshot array is independent.

**Sub-AC 08-field-mutation — Hero field mutation does not reach snapshot**

**GIVEN** the same dispatch, with `snapshot.formation_snapshot[0].current_level == 13` at DISPATCHING,
**WHEN** the caller mutates the original HeroRoster hero's `current_level` to 14 AFTER `DISPATCHING` (source hero changes level),
**THEN** `snapshot.formation_snapshot[0].current_level == 13` (unchanged); the mutation of the source HeroInstance does NOT appear in the frozen snapshot copy. Subsequent Combat calls receive `current_level = 13`.

**Sub-AC 08-floor-reference — Floor is a shared reference, not a deep copy**

**GIVEN** the same dispatch, with `snapshot.floor` resolving to a Floor resource from DataRegistry (e.g., `"forest_reach_f4"`),
**WHEN** the test inspects whether `snapshot.floor` is a deep copy or a reference,
**THEN** `snapshot.floor` is the **same Floor resource instance** as DataRegistry returns for `"forest_reach_f4"` (reference share, not deep copy). This is by design per Save/Load Rule 12: Resources are immutable in practice and serialized by id; deep-copying them is unnecessary. AC-ORC-08 explicitly asserts this to avoid confusion with the formation deep-copy: formation is deep-copied (mutable HeroInstances); Floor resource is NOT (immutable by DataRegistry convention).

*Verification*: unit tests in `tests/unit/orchestrator/test_snapshot_deep_copy.gd`. Sub-ACs 08-array-identity and 08-field-mutation use a mock Roster that exposes the source array and source hero object for identity comparison. Sub-AC 08-floor-reference asserts reference identity via `snapshot.floor == DataRegistry.resolve("floors", "forest_reach_f4")` (same pointer).

**DataRegistry mock contract (Pass 5D — re-review γ item 10 closure)**: Sub-AC 08-floor-reference requires that `DataRegistry.resolve(namespace, id)` returns the **same `Floor` resource instance** across repeated calls with the same `(namespace, id)` pair — otherwise the identity check would be a tautology (any call would produce a fresh object). The mock/fixture contract for this AC:

1. **Real DataRegistry with a loaded fixture** (recommended for Sub-AC 08-floor-reference): the test loads Forest Reach data into the real `DataRegistry` autoload at `before_all`, uses `DataRegistry.resolve("floors", "forest_reach_f4")` throughout, and relies on DataRegistry's internal identity guarantee (Resource caching per Godot 4.6 `ResourceLoader` default behaviour — once loaded, the same `Resource.resource_path` resolves to the same in-memory instance). Assertion `snapshot.floor == DataRegistry.resolve("floors", "forest_reach_f4")` (`==` on RefCounted types is reference equality; Floor extends Resource which extends RefCounted).
2. **MockDataRegistry for Sub-ACs 08-array-identity and 08-field-mutation** (roster mutation sub-ACs): where identity of the Floor resource is not under test, use a minimal `MockDataRegistry` stub that returns any non-null Floor — the sub-ACs assert formation array/field identity, not floor identity.

The mock's identity guarantee is a documented contract: DataRegistry **MUST** return reference-identical Floor instances for identical `(namespace, id)` pairs within a session. This is asserted by a separate DataRegistry AC (owned by that GDD when authored); until then, the MVP implementation's reliance on Godot's ResourceLoader caching satisfies it transitively. If a post-launch refactor of DataRegistry breaks this invariant, Sub-AC 08-floor-reference will fail — which is the intended regression signal. No additional test-shape change needed; the mock contract lives as prose in this AC + is cross-referenced from §F Dependencies Biome/Dungeon DB row.

### AC-ORC-09 — Foreground/Offline Gold Parity (Integration, BLOCKING)

**GIVEN** identical formation, floor, and total tick range `[0, T]`,
**WHEN** the same dispatch is run twice — once via foreground (sequence of `tick_fired` calls totaling T ticks) and once via offline (`compute_offline_run(T)`),
**THEN** total gold credited to Economy (sum of all `add_gold` calls + all `try_award_floor_clear` amounts) is equal between foreground and offline; per-archetype kill counts (sum of foreground `enemy_killed` events grouped by archetype) equal the offline path's per-kill counts (derived from the loop-walk, not from `kills_by_archetype` dict); **`floor_cleared_first_time` signal emission count and payload are identical between the two paths (I.15 FIX 2026-04-21 — prior to this fix, C.4 omitted the emission; post-fix, both paths emit exactly once with payload `(floor_index, biome_id, losing_run)` when `batch.first_clear_tick > 0` / `events.first_clear_in_range == true` AND `snapshot.floor_clear_emitted` was false at entry).**

*Verification*: parameterized integration test with T ∈ {10000, 60000, 576000} and tick-step sizes `∈ {50, 200, 1000}` for the foreground path. Pass 4A change: offline gold is now attributed via the D.4 loop-walk (not dict-walk), so this AC verifies that `sum(foreground per-kill gold)` == `sum(complete-loop walk gold + partial-loop walk gold)`. Both paths call the same `attribute_kill_gold(tier, advantaged, losing_run)` per kill — parity is structural. Combat AC-COMBAT-10 guarantees event determinism; this AC verifies the gold-attribution routing layer adds no drift. The `CHUNK` parameter from the prior spec is renamed to tick-step to avoid confusion with `OFFLINE_REPLAY_CHUNK_TICKS` (a separate Orchestrator tuning knob); same parameterization intent. Economy spy per AC-ORC-04's Pattern 1 (drip-disabled fixture).

**Test-budget ceiling (Pass 5D — re-review γ item 8 closure)**: `tick-step = 1` is **explicitly excluded** from the parameterization. At T = 576,000 × 1 tick/step = 576,000 `tick_fired` calls × ~100 μs/call = ~57.6 s wall clock — exceeds GdUnit4's default 30 s per-test timeout. The parameterization above (`{50, 200, 1000}`) keeps the largest run at T = 576,000 / 50 = 11,520 calls × ~100 μs = ~1.2 s, well under the 30 s ceiling with headroom for slower hardware. If a future test genuinely needs tick-step = 1 (e.g., to catch a per-tick boundary bug), split it into its own test file with an explicit `@GodotTestSuite(timeout = 120000)` annotation and document the rationale; AC-ORC-09's baseline parameterization stays at the three-value set above. Per-archetype kill-count parity assertion runs against all 3 × 3 = 9 (T, tick-step) combinations; total test execution budget for this AC is < 15 s wall clock.

### AC-ORC-10 — boss_killed Signal Fires on is_boss=true (Logic, BLOCKING)

**GIVEN** an F5 dispatch with `enemy_list = [{ancient_rootking, 1}]` (single boss enemy),
**WHEN** the boss kill event fires (in foreground after ~3401 ticks at L13 W+M+R, or in offline batch),
**THEN** `DungeonRunOrchestrator.boss_killed.emit("ancient_rootking")` fires exactly once (Pass 4C: signal owned by Orchestrator autoload, not EventBus); `DungeonRunOrchestrator.enemy_killed.emit(3, "bruiser", advantaged_per_resolver)` also fires.

**Sub-AC 10-mid-queue** — **GIVEN** a hypothetical floor with the boss in mid-queue position (per Combat E.10 + this GDD E.8), **WHEN** the boss kill event fires mid-loop, **THEN** `boss_killed.emit(...)` fires regardless of queue position; subsequent kills in the same loop continue normally.

### AC-ORC-11 — Per-Archetype Matchup Gold Attribution Correctness (Logic, BLOCKING)

*Pass 4C rewrite (Q8): prior spec asserted cache *population* (`matchup_cache[archetype] == expected_bool`), which tests an internal optimization rather than the arithmetic the cache enables. Rewritten to assert per-archetype gold totals — the observable behavior the cache exists to produce.*
*Pass 5C rewrite (re-review γ + α): synthetic "MatchupResolver stub" replaced with a concrete `SpyMatchupResolver extends MatchupResolver` subclass per Pass 5C DI (see §J Mode-1 test pattern). The spy additionally asserts the cache-vs-resolver call count invariant that AC-ORC-09 parity depends on.*

**GIVEN** an F3 dispatch (mixed archetypes: bruiser, caster, armored) with L13 W+M+R formation; a `SpyMatchupResolver extends MatchupResolver` injected via `orchestrator.set_matchup_resolver(spy)` that returns `MatchupResult { is_advantaged = true, matched_archetypes = [archetype] }` for archetypes in `{bruiser, caster}` and `MatchupResult { is_advantaged = false, matched_archetypes = [] }` for `armored`, AND records every `resolve_formation_matchup(formation, archetype)` invocation (count + args); `losing_run = false`; F3 kill schedule producing exactly `{bruiser: 2, caster: 1, armored: 1}` kills per complete loop at tier 1; `tick_budget = 60000` producing exactly N complete loops (no partial — use a tick budget that aligns to a loop boundary),
**WHEN** `compute_offline_run(60000)` executes the D.4 loop-walk,
**THEN** total gold credited via `Economy.add_gold` calls equals the per-archetype expected values:
- bruiser gold = `N × 2 × attribute_kill_gold(tier=1, advantaged=true, losing_run=false)` = `N × 2 × 15` = `30N`
- caster gold = `N × 1 × attribute_kill_gold(tier=1, advantaged=true, losing_run=false)` = `N × 15` = `15N`
- armored gold = `N × 1 × attribute_kill_gold(tier=1, advantaged=false, losing_run=false)` = `N × 10` = `10N`
- total = `55N` gold

**Sub-AC 11-cache-population** *(new Pass 5C — the DI contract itself)* — **GIVEN** the same fixture, **WHEN** `compute_offline_run` runs to completion, **THEN** the spy's `resolve_formation_matchup` call count == **exactly 3** (one per distinct floor archetype: bruiser, caster, armored). The three calls fire at DISPATCHING (cache-build phase). **Zero additional** calls during the per-kill offline replay loop — the Orchestrator reads `snapshot.matchup_cache[archetype]` for each kill, never the injected resolver. This is the Rule-14 snapshot-pattern invariant that AC-ORC-09 parity depends on, asserted at the Orchestrator boundary. If this sub-AC fails, the Orchestrator has re-introduced per-kill resolver invocation in the hot path (regression against the Pass 5C cache design).

**Sub-AC 11-mixed-advantage** — **GIVEN** the same F3 setup but the spy returns mixed results per archetype (e.g., bruiser advantaged, caster NOT advantaged, armored NOT advantaged), **WHEN** the offline run processes the same kill schedule, **THEN** per-archetype gold uses the correct `advantaged` flag per kill's archetype: bruiser kills award `15` gold each, caster kills award `10` gold each, armored kills award `10` gold each. Changing the advantage of one archetype does NOT affect the gold awarded for other archetypes (correctness of per-archetype routing is asserted by differential comparison across fixtures). The spy still records exactly 3 calls total (mixed-advantage does not change the cache-build call count).

**Sub-AC 11-ticks-per-loop-pinned** *(new Pass 5C — re-review γ item 9 closure)* — **GIVEN** the fixture above where "exactly N complete loops" is stated, **WHEN** the test is authored, **THEN** the test MUST pin `ticks_per_loop` to an explicit literal derived from the F3 kill schedule at L13 (per Combat AC-COMBAT-08 derivation: sum of per-enemy kill ticks at the formation's DPS and matchup-throughput factors). The test does not derive `ticks_per_loop` from `Orchestrator.snapshot.ticks_per_loop` (which would make the SUT its own oracle); instead the fixture embeds the pre-computed literal (e.g., `const TICKS_PER_LOOP_L13_F3_ADVANTAGED := 3240`) + asserts `snapshot.ticks_per_loop == TICKS_PER_LOOP_L13_F3_ADVANTAGED` at dispatch. If Combat Pass 3E/3F changes any per-enemy timing, this literal must be updated — the inversion is intentional (forces the test to break on a real contract change rather than silently absorbing drift).

*Verification*: parameterized integration test in `tests/unit/orchestrator/test_matchup_cache_gold.gd` with `SpyMatchupResolver extends MatchupResolver` per Pass 5C DI. Spy records every `resolve_formation_matchup` invocation (count + args + return value). Economy spy captures all `add_gold` calls and groups by archetype (cross-referenced via the kill event tick → archetype map from `RunSnapshot.kill_schedule`). Assertions are against per-archetype gold totals AND the spy's cache-build call count (exactly 3, zero during replay) AND the pinned `ticks_per_loop` literal. Tests remain valid if a future refactor inlines the cache into D.4's loop-walk — the observable behavior (per-archetype gold + zero-per-kill-resolver-calls + pinned loop tick count) is what matters.

### AC-ORC-12 — Save/Load Snapshot Round-Trip (Integration, BLOCKING)

*Pass 4B-SaveLoad rewrite (2026-04-20): prior spec was unverifiable — no concrete fixture, no typed field coverage, no error-path sub-ACs. Fully rewritten below.*

**GIVEN** a populated `RunSnapshot` fixture with all typed fields:
- `formation_snapshot`: Array[HeroInstance] with 3 heroes — `{instance_id:1, class_id:"warrior", display_name:"Theron", current_level:13, xp:0}`, `{instance_id:2, class_id:"mage", display_name:"Sera", current_level:13, xp:0}`, `{instance_id:3, class_id:"rogue", display_name:"Dusk", current_level:13, xp:0}`
- `floor`: Floor resource `"forest_reach_f4"` (resolved from DataRegistry — 4 Thorn Guardians, floor_index=4)
- `kill_schedule`: Array[KillEvent] with 4 entries — `{enemy_id:"thorn_guardian", archetype:"bruiser", tier:3, is_boss:false, kill_tick:431}`, `{kill_tick:862}`, `{kill_tick:1293}`, `{kill_tick:0}` (last one placeholder; adapt from D.5 fixture)
- `loop_counter`: 3
- `last_emitted_tick`: 5000
- `hp_bonus_factor`: 0.5 (boundary value — exactly on the threshold)
- `losing_run`: false (explicitly set as per-save-time derivation; NOT re-derived from hp_bonus_factor on load)
- `floor_clear_emitted`: false
- `matchup_cache`: `{StringName("bruiser"): true, StringName("caster"): false, StringName("armored"): false}` (3 entries; L13 W+M+W has bruiser advantage)
- `dispatched_at_tick`: 0; `formation_dps_per_tick`: 1.580; `ticks_per_loop`: 1293; `floor_was_valid`: true

**WHEN** `snapshot.to_dict()` is called → result is JSON-serialized → JSON-deserialized → `RunSnapshot.from_dict(data)` produces `reconstructed`,

**THEN** all of the following must hold:
- `snapshot.equals(reconstructed) == true`
- Every element of `reconstructed.formation_snapshot` field-equals the source (5 fields each: instance_id, class_id, display_name, current_level, xp)
- `reconstructed.floor.id == "forest_reach_f4"` and `reconstructed.floor` is a non-null Floor resource (resolved from DataRegistry, not a copy)
- All 4 elements of `reconstructed.kill_schedule` field-equal source elements (using `KillEvent.equals()`)
- `reconstructed.losing_run == false` — the boundary value did NOT flip to true (save-time value is authoritative; hp_bonus_factor == 0.5 exactly did NOT trigger re-derivation)
- `reconstructed.matchup_cache.size() == 3`; each key-value pair matches source
- `reconstructed.hp_bonus_factor` passes `is_equal_approx(reconstructed.hp_bonus_factor, 0.5)` (float round-trip fidelity)

*Verification*: integration test using `RunSnapshot.equals()` from C.2 as the gate. Fixture uses real DataRegistry with Forest Reach data loaded. `floor.id == "forest_reach_f4"` resolved to the same Floor resource object as the original (same pointer is acceptable; field equality on `id` is the canonical check inside `equals()`).

**Sub-AC 12-floor-missing**: **GIVEN** a save payload `{"active_run": {"floor_id": "forest_reach_f99", ...other fields...}}` where `"forest_reach_f99"` does not exist in DataRegistry, **WHEN** `RunSnapshot.from_dict(data)` is called, **THEN** `DataRegistry.resolve("floors", "forest_reach_f99")` returns `null`; `push_error` fires with a message containing `"floor_id"` and `"forest_reach_f99"`; `from_dict` returns `null`; the Orchestrator receives `null` and transitions to `NO_RUN`; no crash; session continues loading other consumers normally.

**Sub-AC 12-boundary**: **GIVEN** `hp_bonus_factor = 0.5` exactly and `losing_run = false` in the source snapshot (as in the main fixture above), **WHEN** `to_dict()` → JSON round-trip → `from_dict()` completes, **THEN** `reconstructed.losing_run == false` — the boolean did not flip to true. The float 0.5 round-tripped without precision loss; the `losing_run` field was read directly from the dict without recomputation.

*Prerequisites*: Sub-AC 12 and main AC both require `KillEvent.to_dict()` / `KillEvent.from_dict()` (Combat Pass 3F). Until Pass 3F lands, the test may stub `kill_schedule` as an empty array and add a coverage note; the formation and floor+losing_run round-trip assertions remain executable immediately.

### AC-ORC-13 — Locked Floor Rejected at DISPATCHING (Logic, BLOCKING)

**GIVEN** state `NO_RUN`, `Floor` reference for F5, and `FloorUnlockSystem` (real autoload, not inline stub) with `_unlock_state["forest_reach"] == 0` (fresh save — so `is_unlocked(5) == false`),
**WHEN** dispatch is triggered,
**THEN** state transitions `NO_RUN → DISPATCHING → RUN_ENDED` (via `run_ended` trigger on validation failure); `validation_failed.emit("floor_locked", {floor_index: 5})` fires; state is `RUN_ENDED` after the sequence; `CombatResolver` is not called.

**Sub-AC 13-fresh-save** (integration with GDD #16): **GIVEN** a fresh-save `FloorUnlockSystem` (`_unlock_state = {"forest_reach": 0}`), **WHEN** dispatch is triggered for any `floor_index > 1`, **THEN** the validation fails as above; only `floor_index == 1` succeeds. This AC is the integration-side anchor for GDD #16's AC-FU-13 (Floor Unlock-side) — both must pass in lockstep.

*Gate = BLOCKING* (promoted from ADVISORY 2026-04-20 via Floor-Unlock-Propagation-Edit-3): Floor Unlock GDD #16 landed 2026-04-20; `FloorUnlockSystem.is_unlocked(floor_index)` is the real implementation, replacing the Pass 4A inline F1-only stub. AC-ORC-13 is now a full BLOCKING integration gate. Verification uses GDD #16's real `FloorUnlockSystem` node (no inline stub). Sub-AC 13-fresh-save is a BLOCKING CI gate (not a smoke-test assertion).

### Classification Summary

| ID | Description | Type | Gate | Pass 4A change |
|---|---|---|---|---|
| AC-ORC-01 | State machine — complete 5×6 matrix (all 30 cells) | Logic | BLOCKING | Rewritten: 19 previously-undefined invalid cells now specified; all 30 cells verifiable |
| AC-ORC-02 | Dispatch snapshot caches Combat outputs correctly | Logic | BLOCKING | No change |
| AC-ORC-03 | Foreground tick window forwarded to Combat | Logic | BLOCKING | No change |
| AC-ORC-04 | LOSING_RUN_LOOT_FACTOR end-to-end (Combat AC-07b) | Integration | BLOCKING | Pass 5A: added Sub-AC 04-losing-first-clear-then-win-credits-delta (ADR-0002 reclaim path) |
| AC-ORC-05 | First-clear bonus exactly once per dispatch (Combat AC-09b) | Integration | BLOCKING | No change |
| AC-ORC-06 | Mid-run reassignment ends run + restarts dispatch | Integration | BLOCKING | No change |
| AC-ORC-07 | Empty formation rejected at DISPATCHING | Logic | BLOCKING | Validation failure transitions DISPATCHING → RUN_ENDED (not NO_RUN); test must assert RUN_ENDED |
| AC-ORC-08 | Snapshot deep-copy invariant | Logic | BLOCKING | No change |
| AC-ORC-09 | Foreground/offline gold parity | Integration | BLOCKING | Updated: offline now uses D.4 loop-walk, not dict-walk; "CHUNK" renamed to tick-step |
| AC-ORC-10 | boss_killed signal fires on is_boss=true | Logic | BLOCKING | No change |
| AC-ORC-11 | Per-archetype matchup cache correctness | Logic | BLOCKING | Pass 5C: rewritten with `SpyMatchupResolver extends MatchupResolver` DI; added Sub-AC 11-cache-population (call-count invariant) + Sub-AC 11-ticks-per-loop-pinned (re-review γ item 9) |
| AC-ORC-12 | Save/Load snapshot round-trip | Integration | BLOCKING | No change (Pass 4B) |
| AC-ORC-13 | Locked floor rejected at DISPATCHING | Logic | BLOCKING (promoted 2026-04-20 Floor-Unlock-Propagation-Edit-3) | Pass 4A: F1-only stub behavior asserted in new Sub-AC 13-fresh-save. **2026-04-20**: Floor Unlock GDD #16 landed; AC-ORC-13 promoted ADVISORY → BLOCKING; verification now uses real `FloorUnlockSystem` (no inline stub); paired with GDD #16 AC-FU-13 integration anchor |

**Total: 13 (13 BLOCKING + 0 ADVISORY — AC-ORC-13 promoted from ADVISORY to BLOCKING 2026-04-20 via Floor-Unlock-Propagation-Edit-3 when Floor Unlock GDD #16 landed). Pass 4A: AC-ORC-01, -07, -09, -13 updated. Pass 5A: AC-ORC-04 extended with ADR-0002 reclaim sub-AC; no new ACs. Pass 5C: AC-ORC-11 rewritten for MatchupResolver DI (Spy pattern + cache-population invariant + ticks-per-loop pin); no new ACs; re-review γ items 9, 10, 11 partially addressed via AC-ORC-11 rewrite. Pass 5D (AC triangulation sweep): AC-ORC-01 `push_error` mechanism via §J.4 DI (γ item 5); AC-ORC-02 oracle API replaced with `CombatBatchResult` fields (γ item 6); AC-ORC-04 Economy spy source-tagging contract documented (γ item 7); AC-ORC-07 NO_RUN→RUN_ENDED body↔Summary reconciled (β item 3); AC-ORC-08 DataRegistry mock contract specified (γ item 10); AC-ORC-09 test-budget ceiling — tick-step=1 excluded (γ item 8); Sub-AC 03-no-call-if-no-tick-advance aligned with C.3 `<=` guard (β item 4). D.4 `_build_matchup_cache` coverage contract + C.4 `OfflineRunResult` positional-property construction (δ items 11 + 12). No new ACs.**

## I. Open Questions

| # | Question | Owner | Target Resolution |
|---|---|---|---|
| 1 | **`OfflineRunResult` schema** — exact field set TBD pending Return-to-App Screen (#20) and Offline Progression Engine (#12) GDDs. Provisional fields documented in C.4 (kills_by_archetype, kills_by_tier, gold_kills, gold_clear_bonus, loops_completed, floor_index, losing_run); may need extension for UI display (per-tier gold breakdown? per-loop highlights for sparkline?). | game-designer + ux-designer | During Return-to-App + Offline Engine GDD authoring |
| 2 | **`DISPATCH_DEBOUNCE_MS` default (250 ms)** — first-playtest tuning. Too low → accidental double-dispatch; too high → button feels laggy. | game-designer + ux-designer | First MVP playtest |
| 3 | **Multi-floor offline progression** — MVP design assumes player dispatches one formation on one floor at a time. V1.0 may unlock multi-formation guilds (multiple parallel dispatches). If so, Orchestrator would manage N concurrent `RunSnapshot`s and Offline Engine would call `compute_offline_run` per snapshot. Not a Combat schema change; Orchestrator schema extension only. | game-designer | V1.0 scope planning |
| 4 | **Validation failure UX (locked floor, empty formation, save corruption)** — Orchestrator emits `validation_failed(reason, payload)` signals; UX for surfacing these is owned by Formation Assignment Screen (#17) + Guild Hall Screen (#19). Need consistent toast/inline-hint pattern. | ux-designer | During UI Framework + Formation Assignment GDDs |
| ~~5~~ | ~~**Economy `try_award_floor_clear(floor_index, bonus_amount)` interface**~~ **RESOLVED 2026-04-20 (Pass 4B-Economy A1)**: Economy GDD #4 C.2.3a defines `try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool` with per-lifetime idempotency (AC H-14). Orchestrator calls it at C.3 + C.4 foreground/offline first-clear paths. | ✅ economy-designer | ✅ Resolved Pass 4B-Economy 2026-04-20 |
| 6 | **`OFFLINE_REPLAY_CHUNK_TICKS` default (0 = disabled)** — Default assumes Offline Engine #12 calls `compute_offline_run(full_budget)` once per dispatched floor. If first-playtest reveals visible frame hitches on resume from 8h offline, enable chunking with a default chunk size derived from per-tick performance budget (e.g., 50,000-tick chunks targeting <16ms per chunk). | systems-designer + performance-analyst | First impl sprint perf profiling |
| 7 | **`floor_was_valid` field promotion** — Currently RECOMMENDED per Combat I.Q11; this GDD includes it on `RunSnapshot`. If Orchestrator tests reveal the field is unused in practice (no caller distinguishes "lost badly" from "floor authoring bug"), can be removed. Decision after AC-ORC-07 + E.11 implementations land. | game-designer | First impl sprint |
| 8 | **High-frequency kill-signal debouncing** — At AC-COMBAT-08 worst case (3,740 loops × 4 kills/loop = 14,960 kill events in 8h offline), the Orchestrator autoload emits 14,960 `enemy_killed` signals (Pass 4C: signals are owned by the Orchestrator autoload, not a separate EventBus). UI consumers (Dungeon Run View) may need to coalesce. Open question for Dungeon Run View GDD; not Orchestrator's responsibility but flagged here. | game-designer + ui-programmer | During Dungeon Run View GDD authoring |

---

## J. Production Wiring (Pass 5C, 2026-04-20)

*This section is authored in Pass 5C to close the independent re-review's Cluster α BLOCKERs: (1) Node autoload constructor wiring for DI; (2) MatchupResolver DI parity with CombatResolver. §J is a companion to §C.9 Dependencies — §C.9 specifies the **contracts**; §J specifies the **wiring that satisfies the contracts at runtime and under test**.*

### J.1 Wiring model — Script autoload with lazy-default DI (locked)

The `DungeonRunOrchestrator` is registered as a **script autoload** in `project.godot`:

```ini
[autoload]
DungeonRunOrchestrator="*res://src/gameplay/dungeon_run/dungeon_run_orchestrator.gd"
```

The `*` prefix makes the autoload a global singleton accessible as `DungeonRunOrchestrator.*` from any script after project load. Godot instantiates the script at project load and calls `_init()` with no arguments, then calls `_ready()` after the scene tree is available. This is the standard Godot 4.6 autoload pattern and matches the project's technical preferences (no GDExtension, no engine-level hooks).

**DI pattern selected — Option A (lazy-default with public setters)**:

```gdscript
class_name DungeonRunOrchestrator extends Node

var _combat_resolver: CombatResolver = null
var _matchup_resolver: MatchupResolver = null
var _error_logger: Callable = Callable()        # invalid Callable = fall-through to push_error

# Called by Godot on autoload load. Does NOT create resolvers — that's _ready's job.
# _init must be safe to call with no args (autoload constraint) and must not touch
# DataRegistry (autoload ordering is not guaranteed for dependent autoloads at _init time).
func _init() -> void:
    pass

# Called by Godot after the scene tree is ready. Lazy-constructs default resolvers
# iff no test has pre-injected via set_combat_resolver() / set_matchup_resolver().
# This is the production wiring default — zero-config in shipped builds.
func _ready() -> void:
    if _combat_resolver == null:
        _combat_resolver = DefaultCombatResolver.new()
    if _matchup_resolver == null:
        _matchup_resolver = DefaultMatchupResolver.new()

# Test-facing setters. Production code never calls these. Tests call them BEFORE
# the first dispatch to substitute spy subclasses of the Resolver base classes.
# If called after _ready() on the real autoload instance, the call overwrites
# whatever _ready installed — this is intentional for test scenarios that
# exercise late-construction paths.
func set_combat_resolver(resolver: CombatResolver) -> void:
    assert(resolver != null, "DungeonRunOrchestrator.set_combat_resolver: null not permitted")
    _combat_resolver = resolver

func set_matchup_resolver(resolver: MatchupResolver) -> void:
    assert(resolver != null, "DungeonRunOrchestrator.set_matchup_resolver: null not permitted")
    _matchup_resolver = resolver

func set_error_logger(logger: Callable) -> void:
    # May be an invalid Callable (Callable()) to restore the default push_error fallthrough.
    _error_logger = logger
```

**Why Option A (lazy-default) over Options B, C, D**: see J.7 below.

### J.2 `_ready()` default construction contract

- `_combat_resolver` defaults to `DefaultCombatResolver.new()` iff null at `_ready` time. One instance for the lifetime of the game session — the resolver is stateless per Combat Pass 3D §Rule 1, so re-using it across dispatches is safe.
- `_matchup_resolver` defaults to `DefaultMatchupResolver.new()` iff null at `_ready` time. Same lifetime and stateless contract as CombatResolver (MatchupResolver Pass 5C §Rule 1).
- `_error_logger` defaults to invalid `Callable()` (never `set_error_logger()` in production). Invalid Callables short-circuit to `push_error(msg)` per Combat Pass 3D §AC-COMBAT-11 — this is the documented production fallthrough. The field is **never nil-checked by Orchestrator call sites** — every call writes `if _error_logger.is_valid(): _error_logger.call(msg) else: push_error(msg)`. This keeps test injection a one-line operation and production injection a no-op.
- No other construction happens at `_ready`. Tick subscription (`GameTimeAndTick.tick_fired`) is wired inside the foreground-state entry per C.3 (not at `_ready`) so that an Orchestrator in `NO_RUN` does not receive ticks. Signal connections from downstream consumers (Dungeon Run View, Economy, Return-to-App) happen in their own `_ready` via `DungeonRunOrchestrator.enemy_killed.connect(...)` patterns — Orchestrator is a passive signal publisher at `_ready`.

### J.3 Test wiring pattern (unit tests on the Orchestrator autoload)

Tests need three modes of instantiation depending on what's being asserted:

**Mode 1 — Unit test constructing a fresh `DungeonRunOrchestrator` (no autoload involvement)**:

```gdscript
# For tests that are pure logic and don't need the autoload's signal surface.
var orchestrator: DungeonRunOrchestrator = DungeonRunOrchestrator.new()
var combat_spy := SpyCombatResolver.new()     # extends CombatResolver per Pass 3D
var matchup_spy := SpyMatchupResolver.new()   # extends MatchupResolver per Pass 5C
orchestrator.set_combat_resolver(combat_spy)
orchestrator.set_matchup_resolver(matchup_spy)
# _ready is NOT called automatically on a bare .new() Node — add as child to a test
# scene if you need _ready(); otherwise call orchestrator._ready() directly after
# the set_*_resolver() calls (the setters above will have already populated the
# fields, so _ready's null-checks are satisfied and no defaults are constructed).
add_child(orchestrator)                        # triggers _ready()
```

This is the standard pattern for AC-ORC-01 (state machine), AC-ORC-02 (snapshot caches), AC-ORC-06 (mid-run reassignment), AC-ORC-07 (empty formation), AC-ORC-08 (deep-copy invariant), AC-ORC-10 (boss signal), AC-ORC-11 (matchup cache), AC-ORC-13 (locked floor). Nine of thirteen ACs use this pattern.

**Mode 2 — Integration test against the real autoload (signal connections verified)**:

```gdscript
# For tests that verify signal emission to real downstream consumers.
# DungeonRunOrchestrator is the project's registered autoload, so it's
# accessible as the global singleton. BEFORE dispatch, inject spies.
DungeonRunOrchestrator.set_combat_resolver(combat_spy)
DungeonRunOrchestrator.set_matchup_resolver(matchup_spy)

# Now drive a dispatch — signal consumers downstream (stub Economy, stub Dungeon Run View)
# receive emissions via the real signal connections.
```

Used for AC-ORC-04 (LOSING end-to-end integration), AC-ORC-05 (first-clear-once integration), AC-ORC-09 (foreground/offline parity), AC-ORC-12 (save/load round-trip integration). Four of thirteen ACs use this pattern.

**Mode 3 — Test autoload isolation**: A test that needs to run the Orchestrator in a non-autoload context (e.g., to exercise multiple concurrent instances for V1.0 multi-formation work per Open Question I.3) constructs via `DungeonRunOrchestrator.new()` + `add_child(...)` + `set_*_resolver(...)` — identical to Mode 1 but with the explicit intent of bypassing the autoload. The autoload singleton remains at `NO_RUN` and untouched; the test-created instance is its own subject. No registry or singleton contention.

### J.4 `error_logger: Callable` DI policy (GD9 closure)

The re-review RECOMMENDED item GD9 flagged that `error_logger: Callable` was mentioned but its DI path was left unresolved. §J.1 + §J.2 close that gap:

- **Orchestrator field**: `_error_logger: Callable = Callable()` (invalid by default).
- **Injection point**: `set_error_logger(logger: Callable)` — called by tests only. Production never calls it.
- **Call-site pattern** (every Orchestrator site that would call `push_error` for Pillar-1-visible failures):
  ```gdscript
  var msg := "DungeonRunOrchestrator: [specific reason]"
  if _error_logger.is_valid():
      _error_logger.call(msg)
  else:
      push_error(msg)
  ```
- **Forwarding**: When the Orchestrator calls `_combat_resolver.emit_events_in_range(..., error_logger)`, it forwards its own `_error_logger` value. Same for `compute_offline_batch`. This means a test that injects an error logger at the Orchestrator boundary observes both Orchestrator-level and Combat-level errors through the same spy Callable.
- **AC-ORC-01 "push_error exactly once" verification**: the test injects a `recording_logger` Callable and asserts `recorder.recorded_messages.size() == 1` + message content. Matches re-review RECOMMENDED GD9 closure.

### J.5 MatchupResolver DI — parity with CombatResolver

Pass 5C converts `MatchupResolver` from static-only to injectable instance class (see `design/gdd/class-vs-enemy-matchup-resolver.md` §Rule 1). The Orchestrator holds `_matchup_resolver: MatchupResolver` alongside `_combat_resolver: CombatResolver`. All per-kill + per-archetype-cache calls that previously read `MatchupResolver.resolve_formation_matchup(...)` become `_matchup_resolver.resolve_formation_matchup(...)`.

**Call-site migration** (this GDD — all landing in Pass 5C):

- `C.3` foreground tick loop: per-kill `matchup_resolver.resolve_formation_matchup(snapshot.formation_snapshot, killed_enemy.archetype)` for gold attribution.
- `C.4` offline replay: per-archetype cache build at DISPATCHING reads `matchup_resolver.resolve_formation_matchup(...)` once per distinct archetype on the floor; stored in `snapshot.matchup_cache: Dictionary[StringName, bool]`. Per-kill replay reads `snapshot.matchup_cache[enemy.archetype]` — does NOT re-call the resolver (Rule 14 snapshot pattern; the resolver call count during offline replay MUST be zero, per MatchupResolver AC H-17 + this GDD's AC-ORC-11).
- `AC-ORC-11` (matchup cache correctness) — now a writeable test against a `SpyMatchupResolver` that records how many times its `resolve_formation_matchup` is invoked. The AC asserts: (a) exactly one call per distinct archetype at DISPATCHING; (b) zero calls during the per-kill offline replay loop; (c) `snapshot.matchup_cache` key set matches the floor's deduplicated archetype set.

**Combat GDD #11 — bridge state**: Combat's `_kill_schedule_for_loop` internal path still uses the pre-Pass-5C static-dispatch form as a temporary bridge (see `design/gdd/class-vs-enemy-matchup-resolver.md` §C Dependencies table, Combat row). Combat Pass 3E will land the full injection by adding a `matchup_resolver: MatchupResolver` parameter to `CombatResolver.emit_events_in_range` / `compute_offline_batch`, forwarded from the Orchestrator's `_matchup_resolver` field. Until Pass 3E, Combat's internal resolver calls are not mockable at the Combat boundary — but they are mockable at the Orchestrator boundary (AC-ORC-11 suffices for MVP coverage).

### J.6 `_ready()` order of operations (pseudocode)

The Orchestrator's `_ready()` method runs this sequence exactly once at project load:

```
1. Lazy-construct _combat_resolver if null    (production path)
2. Lazy-construct _matchup_resolver if null   (production path)
3. State := NO_RUN
4. Initialize tuning knobs from combat_config.tres / registry constants
5. [Tick subscription is NOT made here — it is made on entry to ACTIVE_FOREGROUND per C.3]
6. [Signal emissions are NOT made here — the autoload is passive at _ready]
```

Items 1+2 are the only DI-sensitive steps. A test that called `set_*_resolver()` before `_ready` (Mode 1 pattern) has already populated the fields, so the null-checks short-circuit and no production defaults are instantiated.

### J.7 Alternatives considered

**Option B — Scene autoload + bootstrap node**: project.godot points to `bootstrap.tscn`; bootstrap's `_ready()` explicitly constructs resolvers and passes them to a child `DungeonRunOrchestrator` via a public `initialize(combat, matchup)` method. *Rejected*: adds an indirection layer (the bootstrap scene) with no benefit for the MVP — the lazy-default pattern (A) already provides the same zero-config production + test-override capability without the extra scene.

**Option C — RefCounted Orchestrator + thin signal-host wrapper**: Orchestrator becomes `RefCounted` (clean DI via `_init(combat, matchup)`); a separate `OrchestratorHost extends Node` autoload forwards the signals. *Rejected*: clean DI is not worth the class-split cost. The Orchestrator's signal surface is large (at least 6 signals) and splitting it between a signal-host and a logic-owner creates an invisible "where does this signal live?" cost across the entire codebase.

**Option D — Service locator pattern**: a separate `ServiceRegistry` autoload holds the resolvers; Orchestrator queries it on first use. *Rejected*: introduces an anti-pattern (service locator is widely considered inferior to DI in most language ecosystems) with no MVP benefit. GDScript's lazy-default pattern is strictly better for a fixed-dependency-count autoload.

**Option E — Explicit `initialize()` method (no lazy defaults)**: Orchestrator exposes `initialize(combat, matchup)` that MUST be called before dispatch; `_ready` does nothing. *Rejected*: production code would need a separate bootstrap that calls `initialize()` — reintroduces Option B's indirection without Option A's zero-config win. Fails open (dispatch before `initialize()` would crash) rather than failing closed (lazy-default-safe production path).

**Decision record**: Option A locked. If a future production-wiring need emerges (e.g., a configuration-driven resolver choice in V1.0 hard-mode), re-open this section + add a `ResolverFactory` layer between `_ready` and `Default*.new()`. No ADR yet — this section is the authoritative spec until an ADR supersedes it.

### J.8 Validation

- [x] AC-ORC-03 + AC-ORC-05 verifiable against spy subclasses of `CombatResolver` via Mode-1 test pattern (Pass 3D + Pass 5C § compatible).
- [x] AC-ORC-11 verifiable against a spy subclass of `MatchupResolver` via Mode-1 test pattern.
- [x] AC-ORC-01 "push_error exactly once" verifiable via a `recording_logger: Callable` injected through `set_error_logger` (closes re-review RECOMMENDED GD9).
- [ ] **Story-level BLOCKERs downstream**: when the Orchestrator implementation story is authored, the story must embed a test that runs Mode-1 against all three resolver DI setters + asserts the lazy-default path constructs `DefaultCombatResolver` + `DefaultMatchupResolver` by default. (Test shape belongs in the story, not this GDD.)
- [ ] **Bootstrap audit during first vertical slice**: verify that `project.godot`'s autoload entry matches §J.1's script path + that no other autoload accidentally registers `DungeonRunOrchestrator` (a defensive CI grep; story-level, not GDD-level).

### J.9 Cross-reference

- Combat GDD #11 §Rule 2 + §Pass 3D DI shape — companion pattern for CombatResolver.
- Matchup Resolver GDD #10 §Rule 1 + §Rule 4 — companion pattern for MatchupResolver; Pass 5C conversion.
- Orchestrator §C.9 Dependencies row for Combat Resolution + Matchup Resolver — contract side of this wiring spec.
- Orchestrator §H AC-ORC-03 / AC-ORC-05 / AC-ORC-11 — ACs that depend on §J's wiring shape being satisfied.
- Re-review 2026-04-20 Cluster α BLOCKING items 1 + 2 (closed by this section).
