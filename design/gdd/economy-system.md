# Economy System GDD — Lantern Guild

> **GDD #4 in design order** (system #5 in systems index)
> **Status**: Designed (Pass 5B applied 2026-04-20 + **Pass 5F-propagation applied 2026-04-21 — Save/Load consumer-contract method-name canonicalization** + **Pass-I.15-fix-ripple applied 2026-04-21 — §E.4 offline first-clear edge case triple-contradiction closed**)
> **Created**: 2026-04-18
> **Last Updated**: 2026-04-22 (Pass-ADR-0013-SYNC 2026-04-22 — signature harmonization with `docs/architecture/ADR-0013-economy-state-and-cost-curves.md` + `docs/architecture/architecture.md` §Economy API Boundaries. Four signature drift items resolved in lockstep with ADR-0013 authoring: (1) `try_spend(amount: int) -> bool` → `try_spend(amount: int, reason: String) -> bool` at §C.5 + §F deps + §E.7 code block (pre-existing drift vs architecture.md; now closed); (2) `Economy.add_gold(amount: int)` → `Economy.add_gold(amount: int, reason := "credit") -> void` at §F Orchestrator row (pre-existing drift vs architecture.md; now closed); (3) `recruit_cost(class_tier, copies_owned)` → `recruit_cost(class_id: String, copies_owned: int) -> int` at §D.3 formula + variable table + examples (NEW drift introduced by ADR-0013 — contract tightened so callers pass the class_id string they already have; Economy resolves tier internally via `DataRegistry.resolve("classes", id).tier` per ADR-0006/ADR-0011 inheritance; matches ADR-0012 id-string consumer pattern); (4) `gold_changed(new_balance: int)` → `gold_changed(new_balance: int, delta: int, reason: String)` at §F Guild Hall Screen row (pre-existing drift vs architecture.md; now closed). ACs H-05/H-06/H-12 left intact — they describe behavior that is invariant under the signature expansion (callers supply any `reason` string; ACs assert balance + signal behavior, not the reason value). Prior: 2026-04-21 Pass-I.15-fix-ripple — Edge Case §E.4 "Floor-Clear Bonus Awarded During Offline Replay" fully rewritten to close three stale references that each predated a separate subsequent design decision: (a) `floors_cleared_bonus_awarded: Array[bool]` field name inherited from pre-ADR-0002 schema — superseded by `floor_clear_bonus_credited: Dictionary[int, int]`; (b) `floor_cleared_first_time(floor_index: 3)` Economy-as-signal-consumer framing — superseded by Pass-4B-A1 Orchestrator → Economy direct-call direction via `try_award_floor_clear`; (c) "immediately adds `FLOOR_CLEAR_BONUS[3] = 3000`" flat-credit description — superseded by ADR-0002 reclaim-aware credit-the-gap semantic. Corrected prose now reflects: Orchestrator C.4 offline replay → `Economy.try_award_floor_clear(3, bonus_amount)` → Economy credits gap + emits `first_clear_awarded(3)` if first non-zero credit → Orchestrator then emits `floor_cleared_first_time(3, biome_id, losing_run)` in lockstep with C.3 foreground pattern (Pass-I.15-fix in Orchestrator C.4). Floor Unlock listener advances + persists unlock. Prior: Pass 5F-propagation 2026-04-21 — 7 hits renamed from deprecated `save_to_dict / load_from_dict` pair to canonical Save/Load consumer contract `get_save_data / load_save_data` per `save-load-system.md` Rule 3 + AC-SL-01 §F consumer discovery; lines affected: 6, 129, 191, 535, 554, 679, 746; all classified consumer-layer (no HeroInstance-style element-layer references in Economy — `try_award_floor_clear` + `compute_offline_batch` remain unchanged). Prior: Pass 5B — per ADR-0002: `floors_cleared_bonus_awarded: Array[bool]` replaced by `floor_clear_bonus_credited: Dictionary[int, int]`; `try_award_floor_clear` rewritten to credit-the-gap semantic; 6-row semantic table embedded in C.2.3a; AC H-03 + H-11 + H-14 rewritten against the new contract; Sub-AC 14-losing-first-then-win-reclaim + Sub-AC 14-win-then-losing-no-reclaim + Sub-AC 14-zero-bonus added; D.6 F5 pacing row corrected 24,000 → 9,600 g/min (Pass 3B supersession); D.6 Tier-2 recruit cost row corrected 2,500 → 8,000g (matches C.2 calibration note); get_save_data key list updated; Dependencies Save/Load row updated. Pass 4B-Economy: A1 `try_award_floor_clear` method defined; A2 Pass 2B decision 4 re-litigated — LOSING drip NOT halved, drip is run-outcome-independent; A3 `BASE_KILL[1]` reconciled to 10; A4 `kill_bonus` formula deprecated in favour of Orchestrator's `attribute_kill_gold`; A5 "33% faster" prose corrected to 2.25× combined throughput+gold.)
> **Authors**: economy-designer + systems-designer + qa-lead + main session
> **Depends on**: `design/gdd/game-time-and-tick.md`, `design/gdd/save-load-system.md`
> **Referenced by**: Recruitment System, Hero Leveling System, Offline Progression Engine, Dungeon Run Orchestrator
> **Implements Pillar**: Pillar 1 (Respect Player Time — offline accrual feels fair), Pillar 3 (Matchup Is a Decision — matchup-advantaged kills earn meaningfully more)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

---

## A. Overview

The Economy System owns the single currency in *Lantern Guild*: Gold. It is the read-through-and-write boundary for every faucet (per-tick idle drip, enemy kill bonuses, first-clear floor bonuses, matchup-advantage multipliers) and every sink (hero recruitment, hero level-up). It runs deterministically both in foreground (via the Time System's 20 Hz `tick_fired` signal) and during offline replay (via a batch call from the Offline Progression Engine), producing identical output for identical input — the foundation on which Pillar 1's "offline gains feel fair" promise rests.

The system is architected around two invariants: **gold is stored as a single `int64` with a 1 T sanity cap** (no BigInt library needed for MVP or V1.0), and **every formula uses integer arithmetic with `floor()` truncation** to prevent floating-point drift from ever entering the save file. Cost curves are geometric (1.8× recruit ratio, 1.6× level ratio) — the standard idle-genre shape, calibrated through the Section D.6 pacing table to hit the emotional milestones defined in the concept doc: first recruit in Session 1, all Tier-1 classes by Day 1, first Tier-2 class as a Day 3-4 breakthrough, Floor 5 cleared by end of Week 1.

Matchup advantage is concentrated in enemy kill bonuses (1.5× multiplier) rather than the per-tick drip, because kills are audible/visible punctuation moments where the reward can be legibly felt — this is the Pillar 3 economic hook. Drip stays neutral by default; a `MATCHUP_DRIP_BONUS` knob exists for playtest tuning but defaults to 1.0.

---

---

## B. Player Fantasy

Economy is **mixed** — infrastructure under the hood (player never thinks about ticks, formulas, or int64 counters) but directly felt at three moments: the Return-to-App screen enumerating offline gains, the "+N gold" pop when an enemy dies, and the satisfying click of a Recruit or Level-Up button that the balance finally supports.

The indirect fantasy served: **"my guild is accumulating value while I'm away, and every time I come back, I find a reward I can spend on making them stronger."** Every number the player sees is the Economy System's output. When that number lands correctly — generous enough to feel like reward, scarce enough that spending requires a small decision — the whole cozy-idle promise works. When it lands wrong (inflated and meaningless, or stingy and frustrating), nothing else in the game rescues the loop.

The direct fantasy, at the kill-bonus moment, is the Balatro payoff: numbers go up, and up a little more than expected when you made the right class-matchup decision. The combined 2.25× matchup effect (1.5× kill gold × 1.5× throughput via `ticks_per_loop`, per Combat Pass 2B) is calibrated to be visibly legible — matched formations clear noticeably faster AND earn more per kill — without being overwhelming. A decision that matters, not a decision that forces.

---

---

## C. Detailed Design

### C.1 Resources

**Gold** is the sole currency in MVP.

| Attribute | Value |
|---|---|
| Storage type | `int64` (GDScript native integer; never overflows within V1.0 number range) |
| Minimum value | 0 (balance is never negative; `try_spend` rejects if insufficient) |
| Practical sanity cap | 1 000 000 000 000 (1 T gold) — set via `GOLD_SANITY_CAP` tuning knob; any drip or bonus that would exceed this is silently clamped to the cap |
| int64 headroom | `int64` holds up to ~9.2 × 10¹⁸; the sanity cap (1 T) is ~10¹² — gives six orders of magnitude of headroom before overflow risk |
| Save key | `gold_balance` (int64 in human-auditable JSON) |

**Display format** — abbreviations trigger at these thresholds:

| Balance range | Display format | Example |
|---|---|---|
| 0 – 999 | Raw integer | `847` |
| 1 000 – 999 999 | `#.##K` (drop trailing zeros) | `12.5K` |
| 1 000 000 – 999 999 999 | `#.##M` | `3.07M` |
| 1 000 000 000 – 999 999 999 999 | `#.##B` | `1.25B` |
| 1 000 000 000 000 + | `#.##T` | `4.80T` |

All display thresholds are tuning knobs (see Section G). The raw `int64` balance is never shown to the player — the display layer always abbreviates at or above 1 000.

---

### C.2 Faucets (Gold Sources)

Every gold entry point is logged as a lifetime statistic in the save file (`lifetime_gold_earned: int64`). No additional currencies, no item drops in MVP.

#### C.2.1 Per-Tick Drip — Active Dungeon Run

When a formation is dispatched to a dungeon floor, gold accrues on every simulation tick. The Dungeon Run Orchestrator owns the run state; the Economy System receives `current_drip_per_tick` from it and increments `gold_balance` on each `tick_fired` signal.

- Drip is **0** when no formation is assigned (IDLE state).
- Drip scales with floor tier and formation strength (see Section D.1).
- Drip is processed identically in foreground (ACTIVE) and offline replay (OFFLINE_REPLAY) — no separate offline drip rate.

#### C.2.2 Enemy Kill Bonus

Each enemy death during a run fires a one-shot gold burst. The Dungeon Run Orchestrator emits `enemy_killed(enemy_tier, matchup_advantage: bool)` which Economy handles.

- Kill bonuses are significantly larger than drip per event; they provide the satisfying "pop" audio/visual feedback.
- Matchup advantage (class counters enemy type) multiplies the bonus by `MATCHUP_GOLD_MULTIPLIER` (see Section D.2).

#### C.2.3 Floor-Clear Bonus

On the **first clear** of a floor, a one-shot bonus is awarded. The per-lifetime credited total for each floor is tracked in save file as `floor_clear_bonus_credited: Dictionary[int, int]` (key: floor_index 1–5; value: total gold credited so far for that floor's first-clear bonus; absent key ≡ 0). The credited total for a floor is **monotonically non-decreasing** and **never exceeds `FLOOR_CLEAR_BONUS[floor_index]`** — once a floor's full non-LOSING bonus has been credited, every further clear is a no-op.

- Floor-clear bonuses are the largest single gold events in early-game and serve as reward punctuation for milestone moments.
- Awarded during offline replay if the first clear occurred offline; shown in the Return-to-App screen's "while you were away" summary.
- **LOSING_RUN scope (Pass 2B locked decision 4, superseded by Pass 4B-Economy 2026-04-20; further refined by Pass 5A / ADR-0002)**: when Combat reports `survived == false` (i.e., `hp_bonus_factor < 0.5` per Combat GDD #11 Rule 9 / D.6), `LOSING_RUN_LOOT_FACTOR` (default 0.5) applies to **kill bonuses and this first-clear bonus only — NOT to drip**. On a LOSING first-clear, the Orchestrator passes the halved amount `floori(FLOOR_CLEAR_BONUS[floor_index] × 0.5)` into `try_award_floor_clear`; Economy credits it and records that amount as the current ceiling. **Pass 5A / ADR-0002 — "no fail state" re-claim semantic**: the halved portion is **not permanently forfeit**. A subsequent non-LOSING clear of the same floor passes the full `FLOOR_CLEAR_BONUS[floor_index]`; Economy credits the delta (`FLOOR_CLEAR_BONUS[floor_index] - already_credited`) and advances the ceiling to full. Anti-exploit is preserved: the credited total for a floor is monotonically capped at `FLOOR_CLEAR_BONUS[floor_index]`, no matter how many clears — LOSING or WIN — occur. See C.2.3a for the full contract + ADR-0002 §Decision §Semantic consequences for the six-row table.
- Rationale for excluding drip from the LOSING factor: per-tick drip is owned entirely by Economy's independent `tick_fired` subscription path; the Orchestrator has no mechanism to communicate run-outcome state to that path without introducing a cross-system coupling that has no architectural home (see A2 analysis in Economy review log Pass 4B-Economy entry). Drip is run-outcome-independent by architecture; kill gold and floor-clear bonuses are run-outcome-dependent and are correctly routed through the Orchestrator which owns `losing_run` state. The Orchestrator applies `LOSING_RUN_LOOT_FACTOR` to both kill gold (via `_attribute_kill_gold`) and floor-clear bonus (via `_attribute_floor_clear_bonus`) before calling `Economy.add_gold()` and `Economy.try_award_floor_clear()`. Economy does not apply the factor independently. Pillar 1 (no fail state) is preserved mechanically: on a LOSING run the milestone pop fires at a diminished value, and the remaining half becomes a narrative hook ("come back and win this one properly") that is redeemed on the next WIN clear. In MVP floors (F1-F5, enemy attack 35-96), the LOSING trigger is near-unreachable on naturally constructable formations; the knob is a V1.0 hard-content safety net. Combat and Economy each own their layer of the idempotency contract: Combat's `survived` flag is a per-run signal; Economy's `floor_clear_bonus_credited` dictionary is the per-lifetime monotonic-ceiling gate (AC H-03).

#### C.2.3a Public Method: `try_award_floor_clear(floor_index, bonus_amount) -> bool`

**(A1 — added Pass 4B-Economy 2026-04-20; rewritten Pass 5B 2026-04-20 per ADR-0002 — credit-the-gap semantic replaces boolean gate.)**

This method is the Economy's public entry point for first-clear bonus awards. It is called by the Dungeon Run Orchestrator from both the foreground path (C.3 above, line `Economy.try_award_floor_clear(...)`) and the offline replay path (C.4 above, same call). It forms layer 3 of the three-layer idempotency model defined in Orchestrator C.6.

**Signature:**
```gdscript
func try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool
```

**Behaviour (monotonic-credit — ADR-0002):**
1. **Range guard**: if `floor_index < 1 or floor_index > 5`, `push_error("Economy.try_award_floor_clear: floor_index=X out of range [1,5]")` and return `false`. (1-based convention locked in Orchestrator Pass 4A; `floor_index == 0` is a sentinel.)
2. **Negative-bonus guard**: if `bonus_amount < 0`, `push_error("Economy.try_award_floor_clear: bonus_amount=X is negative (authoring bug)")` and return `false`. The floor's credited ceiling is NOT advanced by a bad call — the player can retry with a correct value.
3. **Look up the current ceiling**: `already_credited = floor_clear_bonus_credited.get(floor_index, 0)`.
4. **Gate**: if `bonus_amount <= already_credited`, return `false` immediately. No gold is credited. No signal is emitted. This covers three distinct cases — repeat-WIN-clear, LOSING-after-full-WIN, LOSING-equal-or-below-prior-LOSING — with a single comparison.
5. **Credit the gap**: `delta = bonus_amount - already_credited`; call `add_gold(delta)`. The Orchestrator has already applied `LOSING_RUN_LOOT_FACTOR` to `bonus_amount` before passing it in; Economy does NOT apply the factor again.
6. **Advance the ceiling**: `floor_clear_bonus_credited[floor_index] = bonus_amount`.
7. **Emit `first_clear_awarded(floor_index: int)`** if and only if `already_credited == 0` (true first-ever credit for this floor). Consumers: Return-to-App screen (#20), narrative team, analytics/telemetry. This fires **exactly once per floor per save lifetime**; the reclaim-on-WIN path does NOT re-fire it (the floor was already "first-cleared" — the WIN reclaim is a delta credit, not a milestone event).
8. Return `true`.

**Semantic consequences** (embedded verbatim from ADR-0002 §Decision; this is the authoritative contract):

| Sequence | Call pattern | Total credited per floor |
|---|---|---|
| WIN clear only | `try_award(1, 500)` → credits 500 | 500 |
| LOSING first-clear, no re-entry | `try_award(1, 250)` → credits 250 | 250 (reclaimable; `first_clear_awarded` fired once) |
| LOSING first-clear, then WIN | `try_award(1, 250)` (credits 250, fires signal) + `try_award(1, 500)` (credits 250, signal NOT re-fired) | 500 |
| WIN first-clear, then LOSING re-entry | `try_award(1, 500)` (credits 500, fires signal) + `try_award(1, 250)` (no-op, 250 ≤ 500) | 500 |
| Two WINs | `try_award(1, 500)` (credits 500, fires signal) + `try_award(1, 500)` (no-op) | 500 |
| LOSING, then LOSING | `try_award(1, 250)` (credits 250, fires signal) + `try_award(1, 250)` (no-op, 250 ≤ 250) | 250 (still reclaimable on a later WIN) |

The rightmost column never exceeds `FLOOR_CLEAR_BONUS[floor_index]`. The monotonic credited total preserves anti-exploit: no sequence of calls can credit more than the full bonus.

**Implementation note:** `floor_clear_bonus_credited` is a persisted `Dictionary[int, int]` (absent key ≡ 0 gold credited for that floor). It is included in `get_save_data()` and restored in `load_save_data()`. See AC H-11 for the save round-trip assertion. Signal `first_clear_awarded` is fired at most once per floor per save lifetime; once fired, the per-floor ceiling is non-zero, and the step-7 condition `already_credited == 0` will never be satisfied again for that floor (the reclaim path advances the ceiling without re-firing the signal). Consumers like analytics should still handle duplicates defensively across save loads, but Economy guarantees at-most-once emission per floor per save file.

**Return contract:**
- `true` — `bonus_amount > already_credited`; `delta = bonus_amount - already_credited` gold was credited; `floor_clear_bonus_credited[floor_index]` advanced from `already_credited` to `bonus_amount`.
- `false` — gate no-op'd; gold was NOT credited; floor's ceiling unchanged. Possible causes: `bonus_amount <= already_credited` (already fully credited, or new call is equal/lower LOSING), `floor_index` out of range, or `bonus_amount` negative.

This `bool` return allows callers (the Orchestrator) to write cleaner AC assertions (e.g., "AC-ORC-04: first LOSING call returns true; second WIN call returns true; third repeat call returns false; gold balance increases exactly twice, once by halved bonus and once by the remaining delta"). The contract is intentionally symmetric: `true` always means "something was credited," `false` always means "no-op." Callers do not need to inspect the ceiling directly; the return bool is sufficient for idempotency + reclaim detection at the call site.

**Migration note (pre-MVP only):** Pass 4B-Economy A1 introduced the method with a `Dictionary[int, bool]` gate (`floors_cleared_bonus_awarded`). Pass 5B / ADR-0002 replaces that shape with `Dictionary[int, int]` (`floor_clear_bonus_credited`). Because MVP has not yet shipped, no live saves exist that were authored against the superseded boolean gate; no migration path is needed at launch. If a post-MVP retrofit ever becomes necessary, ADR-0002 §Migration Plan applies.

#### C.2.4 Matchup Advantage Multiplier

Not a faucet by itself, but an amplifier applied to kill bonuses (and optionally drip — see Section D). The matchup gate is **per-kill, per-archetype, majority-threshold** — owned by the Matchup Resolver (GDD #10 Rule 6 + D.2). For each enemy death, if a majority of the dispatched formation slots (more than `formation.size() / 2`) hold a hero whose `counter_archetype` matches the dying enemy's archetype, `MATCHUP_GOLD_MULTIPLIER = 1.5×` is applied to that one kill's bonus. There is no concept of a "dungeon's primary enemy type" — a mixed-archetype floor produces independent per-kill outcomes. This is the Pillar 3 hook: matchup-optimal play earns ~50% more gold on the kills it dominates (via `MATCHUP_GOLD_MULTIPLIER = 1.5`) AND clears those enemies faster (via `MATCHUP_THROUGHPUT_FACTOR_ADV = 1.5` on throughput, per Combat Rule 10 / D.5). The **combined effect is 2.25× effective gold/second on advantaged enemy kills** (1.5× gold per kill × 1.5× throughput factor = 1.5 × 1.5 kills faster = 2.25× gold/time). This double-benefit is intentional and is the core Pillar 3 economic signal — a specialist W+W+M formation on a bruiser floor doesn't just earn more per kill, it earns kills faster too. The pacing table (D.6) and calibration figures account for the 2.25× combined ceiling; references to "~50% more gold" describe per-kill magnitude only (not the throughput component). A generalist W+M+R formation crosses the majority threshold for zero archetypes and receives neither benefit; a specialist W+W+M crosses it for bruiser only.

> **Calibration errata (2026-04-19):** Earlier drafts of this section described the gate as per-run against "the dungeon's primary enemy type." That model is superseded by the per-kill majority model defined above. Tuning of `MATCHUP_GOLD_MULTIPLIER`, the Day 3-4 Tier-2 milestone (8,000g), and offline gold projections must be re-validated against the per-kill majority hit-rate, which produces meaningfully fewer matchup-advantaged kills than the prior per-run model. See Resolver GDD #10 Section I "Open Questions" for the playtest-validation plan.

---

### C.3 Sinks (Gold Costs)

#### C.3.1 Hero Recruitment

Recruiting a hero removes gold immediately. Cost depends on the class tier of the hero being recruited and how many heroes of that class the player already owns (per-copy escalation, inspired by Cookie Clicker and Idle Champions).

- **Tier 1 classes** (Warrior, Mage, Rogue): lower base cost.
- **Tier 2 classes** (unlocked at progression milestones): higher base cost reflecting their later unlock gate.
- Per-copy multiplier prevents trivially stacking identical classes for overpowered formations.
- Formulas in Section D.3.

#### C.3.2 Hero Level-Up

Leveling a hero removes gold immediately. Cost scales geometrically with current level within the hero's class tier. Level cap in MVP is **15** for all classes.

- First few levels are cheap (teaches the mechanic in Session 1).
- Upper levels (12–15) are expensive enough to require meaningful saving between sessions.
- Formulas in Section D.4.

---

### C.4 States

| State | Description | Drip Active | Kill Bonuses | Notes |
|---|---|---|---|---|
| **IDLE** | No formation assigned to any dungeon | No | No | Gold balance unchanged. Player sees static balance. |
| **ACTIVE** | Formation dispatched; session foreground | Yes | Yes | `tick_fired` → `_on_tick()` → increment gold. |
| **OFFLINE_REPLAY** | Session-start replay of elapsed offline ticks | Yes (batch) | Yes (batch) | Same per-tick math as ACTIVE; no per-tick allocations; O(N) loop. |
| **PAUSED** | UI settings panel open mid-session | No | No | Tick System does NOT emit `tick_fired` while paused (pause happens at source — see `game-time-and-tick.md` Rule 5). Economy receives no ticks during pause; no "ignore" branch is required on the consumer side. Paused duration does NOT count toward session but DOES count toward offline elapsed on next launch if app is killed while paused. |

State is not persisted — it is re-derived on session start from roster assignment data.

---

### C.5 System Interactions

| System | Interaction Type | Direction | Contract |
|---|---|---|---|
| **Game Time & Tick System** | Signal subscription | Tick → Economy | Economy's `_on_tick(tick_number: int)` subscribes to `tick_fired`. Never reads `_process(delta)`. |
| **Dungeon Run Orchestrator** | Data pull (each tick) | Economy reads Orchestrator | Economy calls `orchestrator.get_current_drip_per_tick() -> int` each tick when ACTIVE. |
| **Dungeon Run Orchestrator** | Direct method call | Orchestrator → Economy | Orchestrator calls `Economy.add_gold(amount)` directly (with loot factors already applied) for kill gold, and `Economy.try_award_floor_clear(floor_index, bonus_amount) -> bool` for first-clear bonus (see C.2.3a). Economy no longer relies on a `floor_cleared_first_time` signal for gold crediting; signal-receive pattern deprecated for the first-clear path in favour of the direct method call (the Orchestrator owns `losing_run` state and must compute the correct `bonus_amount` before calling). |
| **Recruitment System** | Spend request | Recruitment → Economy | `economy.try_spend(amount: int, reason: String) -> bool` (ADR-0013). If `gold_balance >= amount`, subtracts and returns `true`; else returns `false` unchanged. `reason` is a free-text category string (e.g., `"recruit_warrior"`) used for telemetry + HUD coalesce filtering. |
| **Hero Leveling System** | Spend request | Leveling → Economy | Same `try_spend(amount, reason)` contract as Recruitment. |
| **Hero Roster** | Read-only query | Economy reads Roster | Economy reads roster state via `roster.get_formation_strength() -> float` to pass into drip formula. |
| **Save/Load System** | Serialization | Both directions | Economy exposes `get_save_data() -> Dictionary` and `load_save_data(data: Dictionary)`. Keys: `gold_balance`, `lifetime_gold_earned`, `floor_clear_bonus_credited` (Pass 5B / ADR-0002 — replaces `floors_cleared_bonus_awarded: Array[bool]`). No direct file I/O. |
| **Offline Progression Engine** | Tick replay | Engine → Economy | Engine calls `economy.compute_offline_batch(tick_budget: int) -> OfflineResult` — NOT 576k individual tick calls. See Section C.6 for the hybrid replay strategy contract. |

---

### C.6 Systems Integration Notes — Offline Replay Contract

*Validation by systems-designer against Time System's < 500 ms batch replay budget (576 000 ticks max × 0.87 μs per tick).*

**Per-tick budget reality check:**
- **SAFE** — int64 gold increment: ~1–5 ns. Run per-tick during replay without concern.
- **SAFE** — Dictionary/array matchup lookup: ~10–50 ns. Safe if pre-resolved scalar, not walked per tick.
- **WARN** — Roster walk per tick (up to 3 heroes × 20–50 ns × 576k ticks = 35–87 ms): **must be amortized**. Compute `gold_per_tick` once at replay start from the frozen formation snapshot; use scalar for all ticks.
- **WARN** — `gold_changed` signal dispatch: 200–500 ns × 576k = 230 ms alone — **blows the budget**. A replay flag (`is_offline_replay: bool`) must suppress all UI-bound signals during replay; emit once with total delta after replay completes.

**Replay strategy (locked — Hybrid / Option C):**
Economy exposes `compute_offline_batch(tick_budget: int) -> OfflineResult` which:
1. Reads the static formation snapshot (frozen at last persist — no live roster walk).
2. Closed-form computes drip total: `drip_per_tick × tick_budget` (O(1) multiply).
3. Batch-processes discrete events (enemy kills, floor clears) by estimating event cadence from the formation's effective output and the dungeon's enemy density; resolves each event with a seeded RNG.
4. Returns an `OfflineResult` struct: `{gold_earned, kills_by_tier, floors_cleared, events_log}` — UI consumes `events_log` for the Return-to-App screen.

**Pure per-tick replay (Option A) is forbidden** — GDScript function-call overhead alone (100–300 ns × 576 000 = 58–173 ms before any work) would exhaust the budget.

**Signal routing during replay:**
- `tick_fired` signal is **not** emitted to Economy during offline replay. The Offline Engine calls `compute_offline_batch()` directly, bypassing the signal bus.
- This means Economy has two execution paths: (a) foreground `_on_tick(tick_number)` subscribing to `tick_fired`; (b) `compute_offline_batch(tick_budget)` called directly by Offline Engine. Both must produce identical results for identical input.

**Determinism requirements (enforced):**
- All random decisions during replay use a seeded `RandomNumberGenerator` (seed = `t_last_persist XOR offline_tick_budget`). Same seed → same loot/kill outcomes every replay.
- All internal counters are int64 with `floor()` truncation. **No float accumulation across ticks** — the closed-form path eliminates this concern by construction.
- No economy field is updated in `_process(delta)` — architecture violation if found. Time System Rule 3 already forbids this at the source.

**Int64 overflow Fermi check** (passes): At aggressive V1.0 rates (10 000 gold/tick sustained, 10 years of 8h/day idle), lifetime accumulation ~2.1 × 10^16 vs int64 ceiling of 9.2 × 10^18 → **400× margin**. No BigInt needed. Prestige reset (V1.0) zeroes the counter periodically regardless.

---

## D. Formulas

All formulas use integer arithmetic throughout (GDScript `int`). Where a formula produces a fractional intermediate, it is `floor()`-truncated before being added to `gold_balance`. This prevents any float-precision drift from accumulating in the save file.

---

### D.1 Per-Tick Drip — Active Dungeon Run

**Formula:**

```
drip_per_tick = floor(BASE_DRIP[floor_tier] * formation_strength_factor * matchup_drip_factor)
```

**Variables:**

| Variable | Type | Description |
|---|---|---|
| `BASE_DRIP[floor_tier]` | int (lookup) | Base gold drip per tick for the given dungeon floor (see table below) |
| `formation_strength_factor` | float | Scales drip by how upgraded the dispatched formation is. Range: 1.0–3.0. Formula: `clamp(1.0 + (avg_formation_level - 1) * 0.2, 1.0, 3.0)`. **Owned by Hero Roster GDD #9** (`HeroRoster.get_formation_strength()`); see `hero-roster.md` D.1 for full variable definitions. `avg_formation_level` is the mean `current_level` across active formation heroes (skips empty slots); empty formation returns 1.0 directly via guard clause. |
| `matchup_drip_factor` | float | 1.0 (no advantage) or `MATCHUP_DRIP_BONUS` (advantage). Default: 1.0 — matchup advantage primarily amplifies kill bonuses, not drip. See design note below. |

**BASE_DRIP table (gold per tick, at formation_strength_factor = 1.0):**

| Floor | `BASE_DRIP` | Gold/sec at factor 1.0 | Gold/min at factor 1.0 |
|---|---|---|---|
| 1 | 2 | 40 | 2 400 |
| 2 | 4 | 80 | 4 800 |
| 3 | 7 | 140 | 8 400 |
| 4 | 12 | 240 | 14 400 |
| 5 | **8** *(reduced from 20 — Combat Pass 3B 2026-04-20)* | 160 | 9 600 |

**Pass 3B 2026-04-20 — F5 drip rebalance**: Reduced from 20 → 8 to preserve the "10–14 days to max" pillar promise. The pre-Pass-3B F5 drip yielded ~11.5M gold over a single 8h offline cap (`24,000 g/min × 170 s/loop × 169 loops = ~11.5M`) at `formation_strength_factor = 1.0`, and ~34M at L13 (`factor = 3.0`) — roughly 78× the cumulative cost to max all three Tier-1 heroes (~147K). One overnight session would have collapsed the multi-day end-game arc. New rate is ~4.6M/8h at factor 1.0 / ~13.8M at L13. **This intentionally breaks the previously-documented monotonic progression curve (×1, ×2, ×3.5, ×6, ×10):** F5 drip is now LOWER than F4 drip. The design intent is that F5's "endgame feel" comes from Tier-3 boss kill bonuses + the 18,000 g `FLOOR_CLEAR_BONUS[5]` one-shot, not from sustained drip dominance. **The full drip curve (F1–F5) requires holistic rebalancing in the next Economy revision pass — see Section I new Open Question.** Until that pass lands, treat the F4→F5 drip step as a known regression scoped to "interim fix that closes Combat GDD #11 Pass 2B Re-Review Blocker 4 without redesigning the entire economy in a Combat-side revision."

**Design note on `matchup_drip_factor`**: Matchup advantage is concentrated in kill bonuses rather than drip because drip is invisible to the player mid-session (it accrues silently). Kill bonuses fire at the moment of enemy death and can be visually and audibly punctuated — so the Pillar 3 reward is most legible there. `matchup_drip_factor` defaults to 1.0; the tuning knob exists to test a small boost (e.g., 1.15) if playtesting reveals the kill bonus alone is insufficient incentive.

**Output range:** 2 gold/tick (floor 1, level 1 heroes) to 60 gold/tick (floor 5, max formation strength).

**Worked example — Session 3, Floor 2, `avg_formation_level = 4`:**
```
formation_strength_factor = clamp(1.0 + (4 - 1) * 0.2, 1.0, 3.0) = 1.6
drip_per_tick = floor(4 * 1.6 * 1.0) = floor(6.4) = 6
gold per second = 6 * 20 = 120
gold per 3-minute session = 120 * 180 = 21 600
```

---

### D.2 Enemy Kill Bonus

**Formula:**

```
kill_bonus = floor(BASE_KILL[enemy_tier] * matchup_multiplier)
```

**Variables:**

| Variable | Type | Description |
|---|---|---|
| `BASE_KILL[enemy_tier]` | int (lookup) | Base gold burst per enemy kill, by enemy tier (see table below) |
| `matchup_multiplier` | float | 1.0 (neutral) or `MATCHUP_GOLD_MULTIPLIER` (1.5) per the per-kill majority gate (Resolver GDD #10 Rule 6 + Economy C.2.4). Evaluated independently for each enemy death; mixed-archetype floors produce a mix of 1.0 and 1.5 within a single run. |

**BASE_KILL table:**

| Enemy tier | `BASE_KILL` | With matchup (×1.5) |
|---|---|---|
| 1 (floor 1-2 enemies) | **10** | 15 |
| 2 (floor 3 enemies) | 35 | 52 |
| 3 (floor 4-5 enemies) | 80 | 120 |

> **A3 reconciliation (Pass 4B-Economy 2026-04-20)**: `BASE_KILL[1]` was incorrectly listed as 15 in earlier Economy GDD drafts. The authoritative value is **10**, consistent with the entity registry (`attribute_kill_gold.notes: BASE_KILL[1]=10`) and the Orchestrator GDD D.1 (output range 5–120 with lower bound `floori(10 × 1.0 × 0.5) = 5`). The stale value of 15 was a copy-paste error from a pre-`LOSING_RUN_LOOT_FACTOR` draft where the minimum output was 15 (neutral, non-losing, tier 1). With the LOSING multiplier path, the correct minimum is 5. All Economy ACs and pacing calculations must use `BASE_KILL[1] = 10`.

**Kill frequency assumption**: approximate kill cadence is set by Combat Resolution System (see Combat GDD D.7). At floor 1 (L1–L2 formation), kills arrive roughly every 40 s; at floor 3 (L6 formation), roughly every 17 s. The earlier "1 kill per 10 seconds" placeholder is superseded by Combat D.7's authoritative cadence table.

**Output range:** `5` gold (tier 1, neutral, LOSING) to `120` gold (tier 3, matchup advantage, non-LOSING). Note: Economy does **not** apply `LOSING_RUN_LOOT_FACTOR` directly — the Orchestrator applies it inside `_attribute_kill_gold` before calling `Economy.add_gold(amount)`. Economy receives the post-factor amount.

**Worked example — Floor 3, matchup advantage:**
```
kill_bonus = floor(35 * 1.5) = floor(52.5) = 52 gold per kill
18 kills in 3-min session = 936 gold from kills alone
```

**Matchup economic impact**: Over a 3-minute floor 3 session, matchup advantage earns ~312 extra gold from kills alone versus neutral formation (936 − 624). However, this understates the true Pillar 3 payoff. Because Pass 2B routes matchup advantage through `ticks_per_loop` as well (Combat Rule 10 / D.5 — `MATCHUP_THROUGHPUT_FACTOR_ADV = 1.5`), an advantaged formation clears floor 3 enemies **50% faster** AND earns **50% more per kill**. The combined economic benefit for per-enemy gold/second is `1.5 × 1.5 = 2.25×` on matched enemies. In a 3-minute window on a fully-matched floor, the advantaged formation kills approximately 50% more enemies than neutral (faster cadence) AND earns 50% more per kill — making the total gold from the kill channel roughly 2.25× that of a neutral formation for the same wall-clock time. Drip income is unaffected by matchup (drip faucet is run-outcome-independent). Across a floor 3 session (drip-dominant at 8,400 g/min vs ~312 kill bonus delta), the net acceleration toward a 6,000 g purchase is modest in absolute terms — but the player directly sees the cadence accelerate, and that legibility IS the Pillar 3 payoff. See C.2.4 for the full 2.25× combined multiplier discussion.

> **A5 correction (Pass 4B-Economy 2026-04-20)**: Prior drafts of this section stated "~33% faster accumulation." That figure was stale — it predated Pass 2B's throughput routing and described the per-kill gold bonus alone relative to purchase cost (312/6000 ≈ 5%, not 33%). The correct characterisation is 2.25× combined gold/second on advantaged enemies (1.5× per-kill gold × 1.5× kill cadence). The "~33% faster" figure is removed.

---

### D.3 Hero Recruitment Cost

**Signature (ADR-0013):**

```gdscript
func recruit_cost(class_id: String, copies_owned: int) -> int
```

Callers pass the `class_id` string (they already have it — the Recruitment UI knows which class row the player tapped). Economy resolves `tier = DataRegistry.resolve("classes", class_id).tier` internally per ADR-0006 / ADR-0011. Returns **-1** on unresolvable `class_id` (authoring bug) or negative `copies_owned` (authoring bug); else returns the computed cost.

**Formula (Economy-internal, after tier resolution):**

```
recruit_cost(class_id, copies_owned):
    tier = DataRegistry.resolve("classes", class_id).tier
    return floori(BASE_RECRUIT[tier] * RECRUIT_RATIO ^ copies_owned)
```

**Variables:**

| Variable | Type | Description |
|---|---|---|
| `class_id` | String | Stable id of the class being recruited (e.g. `"warrior"`, `"mage"`, `"rogue"`). Resolves to `HeroClass` via `DataRegistry.resolve("classes", class_id)` per ADR-0006 / ADR-0011. |
| `tier` | int | Resolved internally from `HeroClass.tier`; not a caller-supplied parameter. Used as `BASE_RECRUIT` lookup key. |
| `BASE_RECRUIT[tier]` | int (lookup) | Starting cost for first copy of a class at this tier. Stored on `economy_config.tres` (ADR-0013). |
| `RECRUIT_RATIO` | float | Geometric ratio for each additional copy. Default: `1.8`. Stored on `economy_config.tres`. |
| `copies_owned` | int | Number of heroes of this exact class already in the roster. `0` for first purchase. Caller-supplied (queryable via `HeroRoster.get_copies_owned(class_id)` per ADR-0012). |

**Justification for 1.8×**: The classic idle standard is 1.5× (Cookie Clicker, Adventure Capitalist). For Lantern Guild, per-copy stacking is a deliberate sink for players who want multiples of the same class. 1.8× makes the third copy of a class cost 3.24× the first, which is expensive enough to require a decision without being punishing. Players should be able to recruit one copy of each class without encountering the per-copy escalation until they deliberately try to stack.

**BASE_RECRUIT table:**

| Class tier | `BASE_RECRUIT` | 1st copy | 2nd copy (×1.8) | 3rd copy (×3.24) |
|---|---|---|---|---|
| Tier 1 (Warrior, Mage, Rogue) | 150 | 150 | 270 | 486 |
| Tier 2 (3 post-MVP classes) | **8 000** | 8 000 | 14 400 | 25 920 |

**Output range:** 150 gold (first Tier 1 recruit) to ~25 920 gold (third copy of a Tier 2 class — unlikely in MVP play).

**Worked example — Recruiting a second Warrior (copies_owned = 1):**
```
recruit_cost("warrior", 1)
  → HeroClass.tier resolves to 1 via DataRegistry.resolve("classes", "warrior")
  → floori(150 * 1.8 ^ 1) = floori(270.0) = 270 gold
```

**Worked example — First Tier 2 class (Day 3-4 milestone):**
```
recruit_cost("cleric", 0)                       # or "ranger" / "tactician"
  → HeroClass.tier resolves to 2
  → floori(8000 * 1.8 ^ 0) = 8000 gold
```

> **Calibration note**: The Tier-2 base was set to 8 000 rather than the initial 2 500 explored in D.6 below. At 2 500 gold, the first Tier-2 purchase would be reachable within minutes of arriving at Floor 3 — violating the "breakthrough moment / requires saving" emotional target. 8 000 gold sits at roughly one half-day of Floor 3 income, producing the intended ~0.5–1 day saving period. Flagged for first playtest verification.

---

### D.4 Hero Level-Up Cost

**Formula:**

```
level_cost(class_tier, current_level) = floor(BASE_LEVEL[class_tier] * LEVEL_RATIO ^ (current_level - 1))
```

**Variables:**

| Variable | Type | Description |
|---|---|---|
| `BASE_LEVEL[class_tier]` | int (lookup) | Cost to level from 1 → 2 |
| `LEVEL_RATIO` | float | Geometric ratio per level. Default: `1.6` |
| `current_level` | int | Hero's current level before the level-up (1 = starting level) |
| Level cap | 15 | Maximum level for all MVP classes |

**Justification for 1.6×**: Steeper than recruitment ratio (1.8×) but with a lower base, making early levels cheap and accessible while placing levels 12–15 well into saving territory. 1.6× gives a total cost-to-max that requires roughly 10–14 days of cumulative play at normal session cadence, providing long-term engagement.

**BASE_LEVEL table (cost for level N → N+1):**

| Level | Tier 1 cost | Tier 2 cost |
|---|---|---|
| 1 → 2 | 40 | 600 |
| 2 → 3 | 64 | 960 |
| 3 → 4 | 102 | 1 536 |
| 4 → 5 | 164 | 2 458 |
| 5 → 6 | 262 | 3 932 |
| 6 → 7 | 419 | 6 291 |
| 7 → 8 | 671 | 10 066 |
| 8 → 9 | 1 074 | 16 106 |
| 9 → 10 | 1 718 | 25 769 |
| 10 → 11 | 2 749 | 41 231 |
| 11 → 12 | 4 399 | 65 970 |
| 12 → 13 | 7 038 | 105 552 |
| 13 → 14 | 11 261 | 168 883 |
| 14 → 15 | 18 018 | 270 213 |
| **Total 1→15** | **48 978** | **734 667** |

*(Values rounded to nearest integer; derived from `floor(BASE * 1.6 ^ (level - 1))`)*

**Worked example — Leveling a Warrior from 3 to 4:**
```
level_cost(tier_1, 3) = floor(40 * 1.6 ^ 2) = floor(40 * 2.56) = floor(102.4) = 102 gold
```

---

### D.5 Floor-Clear Bonus (One-Shot)

Awarded once per floor, on first clear only. Represents the "milestone reward" punctuation.

| Floor | Clear bonus | Ratio to previous |
|---|---|---|
| 1 | 500 | — |
| 2 | 1 200 | ×2.4 |
| 3 | 3 000 | ×2.5 |
| 4 | 7 500 | ×2.5 |
| 5 | 18 000 | ×2.4 |

Rationale: Floor 1 clear bonus (~500) covers the cost of the second hero recruit outright. Floor 5 clear bonus (18 000) is roughly equivalent to 45 minutes of floor 5 drip income — a meaningful windfall that funds a large chunk of the next upgrade tier without replacing the ongoing idle income.

---

### D.6 Pacing Validation — Milestone Table

The following models expected gold balance, recruits, and levels at each target milestone. Assumptions: player completes 2-minute active sessions (plus offline accumulation between sessions), assigns to the highest floor currently accessible, and spends all available gold each session. Kill count estimated at 1 per 10 seconds active.

> **Pass 2B revalidation (2026-04-20)**: Combat GDD #11 D.7 now owns the canonical per-floor kill cadence (replacing this section's "1 kill per 10 seconds" placeholder). Under Combat's tick-model: F1 = ~10 s/kill at L2 formation; F3 = ~17 s/kill at L6 formation; F5 = 170 s/boss-kill at L13 formation (HP raised 2200 → 4818 in Pass 2B). Economy milestones below are **drip-dominated** at every floor (floor-3 drip = 8,400 gold/min vs kill bonus ≤ 40 gold/kill × 3.5 kills/min = 140 gold/min). The slower F3/F5 kill cadences reduce kill income by ~40% at F3 and ~94% at F5 vs the placeholder, but drip + clear bonus absorb the delta — milestones remain achievable. **Flag carried forward**: playtest must confirm Day 3-4 Tier-2 milestone reachability under F3's 17 s/kill reality. See Open Question (I.2) for details.

**Session cadence model**: 2 sessions Day 1 (Session 1 = 5 min tutorial; Sessions 2-4 = 3 min standard), then 3-4 sessions/day thereafter. Offline gap between sessions: 4–6 hours average.

| Milestone | Target timing | Modeled gold at decision point | Spend | Meets target? |
|---|---|---|---|---|
| First level-up (Warrior L1→2) | Session 1, ~1 min | ~100 gold earned from floor 1 drip (20 ticks/sec × 2 gold × 60 sec = 2 400 gold in 1 min) | 40 gold | **Yes** — affordable within 30 seconds |
| First recruit (2nd hero joins) | Session 1, ~3-5 min | ~7 200 gold from 3 min drip + ~270 from kills | 150 gold | **Yes** — affordable within first 90 seconds; first recruit feels trivially accessible on purpose |
| Floor 1 cleared | Session 1 end | ~12 000 gold drip + 500 clear bonus | — | **Yes** — floor 1 is designed to clear in ~5–8 min of active time |
| All 3 Tier-1 classes recruited | End of Day 1 (~4 sessions) | ~80 000 gold cumulative (drip + kills + clear bonuses floors 1-2) | 150 + 150 + 150 = 450 total | **Yes** — 450 gold is trivial; bottleneck is floor progression not gold |
| Floor 3 cleared | End of Day 3 | ~300 000 gold cumulative; balance ~40 000 after leveling | — | **Yes** — hero levels 4-6 are affordable by Day 2-3 |
| First Tier-2 recruit (4th class) | Day 3-4 | Balance needs to reach **8 000 gold** (Pass 5B — corrected from the stale 2 500 in prior draft; 8 000 is the C.2 locked value per calibration note) | 8 000 gold | **Yes** — requires ~1 saved half-day of floor 3 income (floor 3 drip = 8 400/min; 8 000 is ~57 sec of floor 3 drip at factor 1.0, but realistic play pauses for level-ups and recruit-ladder spends, producing the intended ~0.5–1 day emotional breakthrough). See C.2 "Calibration note" for rationale. |
| Floor 5 cleared | End of Week 1 | Balance fluctuates; player is spending heavily on levels 8-12 | — | **Yes** — level costs 7–12 are in the 1 000–7 000 range; floor 5 drip **9 600 gold/min** (Pass 5B — corrected from the stale 24 000 in prior draft; `BASE_DRIP[5] = 8` post-Pass-3B × 20 ticks/sec × 60 sec at factor 1.0) covers a ~5 000g mid-range level-up every ~31 seconds. The lower drip rate means F5 feels meaningfully less generous than the pre-Pass-3B projection; pacing absorbs the delta via clear bonuses + kill gold; playtest-monitored. |

**Calibration — Tier-2 recruit cost (locked)**: `BASE_RECRUIT[tier_2] = 8 000` gold is the locked value (Pass 5B — was 2 500 in pre-4B drafts; 8 000 matches the C.2 calibration note and the Pass 5B milestone-table row above). The "breakthrough moment / requires saving" emotional target is met at 8 000 because it sits at roughly one half-day of Floor 3 income, producing the intended ~0.5–1 day saving period. The 2 500 figure appears only in deprecated commentary below; do not use it as an authoritative value. Playtest will verify the feel and the knob has a safe range of 2 500 – 20 000 for post-launch tuning.

**Nothing-to-spend sessions**: With the pacing above, a player who spends all gold each session will always have at least one level-up available (40–400 gold cost, earned in seconds at floor 1). The only dry spell risk is if the player has maxed all affordable levels and hasn't reached the next floor for the clear bonus. The floor-clear bonus table is specifically sized to always fund the next logical upgrade tier.

---

## E. Edge Cases

### E.1 Gold Balance Would Exceed GOLD_SANITY_CAP (1 T gold)

**Scenario**: Offline replay or active play drip/bonus would push `gold_balance` past 1 000 000 000 000.

**Behavior**: Before adding any gold amount, the Economy System checks:
```
if gold_balance >= GOLD_SANITY_CAP:
    return  # no-op; do not add
else:
    gold_balance = min(gold_balance + amount, GOLD_SANITY_CAP)
```
`lifetime_gold_earned` still accumulates unbounded (it is a statistic, not a spendable balance — int64 headroom is sufficient for decades of play). The cap is never displayed to the player; it is a silent engineering ceiling. At V1.0 scope (level cap 15, 6 tier-2 classes), the maximum meaningful spend is approximately 750 000 gold total; reaching 1 T is only possible from years of idle accumulation at floor 5.

### E.2 Player Returns After 8+ Hours (Offline Cap)

**Scenario**: Player left the app open (or more precisely, dismissed it) for 12 hours. `offline_elapsed_seconds` returns `clamp(12h, 0, 8h) = 28800`. Formation state is frozen at the time of last persist.

**Formation state**: The Economy System reads formation state from the snapshot persisted at last save, not the current live roster. If the player changed a formation assignment and then the app was killed before the next auto-save, the last-saved formation is used. This is a known acceptable edge case (documented to the player as "your last-saved assignment was used").

**Empty formation**: If the formation was empty at last save (no heroes assigned), `get_current_drip_per_tick()` returns 0, and `enemy_killed` signals never fire during replay. The player returns to find no offline gold. This is correct and expected — closing the app without assigning a formation means no idle income. The UI should display "Your guild was idle — assign heroes before closing" as a one-time hint.

**Behavior**: No special case required beyond the tick cap already enforced by `offline_tick_budget`. Economy processes exactly `min(elapsed * 20, 576000)` ticks.

### E.3 IDLE State — No Formation Assigned, Previous Dungeon Selected

**Scenario**: Player previously had a dungeon selected, then removed all heroes from the formation but left the dungeon tab open. The UI shows a dungeon but no active income is accruing.

**Behavior**: `drip_per_tick = floor(BASE_DRIP × 1.0 × 1.0) = BASE_DRIP` numerically, but Dungeon Run Orchestrator does not dispatch an empty formation — no run is active, so no `tick_fired` is consumed by this faucet. Per Hero Roster GDD #9 D.1, `get_formation_strength()` returns `1.0` for an empty formation via explicit guard clause (no divide-by-zero; no `factor = 0`). The economy is correctly idle because the Orchestrator suppresses dispatch, not because the factor is zero. The UI must clearly signal "no heroes assigned" rather than showing a running-but-zero income figure, to avoid player confusion. This is a UI design constraint, not an economy behavior.

### E.4 Floor-Clear Bonus Awarded During Offline Replay

**Scenario**: During an 8-hour offline session, the dispatched formation clears Floor 3 for the first time. The player was not present.

**Behavior (Pass-I.15-fix rewrite 2026-04-21 — closes triple-contradiction flagged by Floor Unlock #16 Pass-9 + cross-referenced from session state).** The prior version of this edge case contained three stale references that each predated a separate subsequent design decision:

1. It referenced `floors_cleared_bonus_awarded[3] = true` as the idempotency field. **Superseded by Pass 5B / ADR-0002** — the field is now `floor_clear_bonus_credited: Dictionary[int, int]` (credit-the-gap semantic, see §C.2 + §C.2.3a). The Array[bool] schema no longer exists.
2. It described the Orchestrator emitting `floor_cleared_first_time(floor_index: 3)` and Economy handling it as a signal consumer. **Superseded by Pass 4B-Economy A1** — the Orchestrator calls `Economy.try_award_floor_clear(floor_index, bonus_amount) -> bool` directly (a method call, not a signal round-trip). Economy never subscribes to any Orchestrator-owned signal; the call direction is Orchestrator → Economy, not the reverse.
3. It described Economy "immediately adding `FLOOR_CLEAR_BONUS[3] = 3000`" as a flat credit. **Superseded by ADR-0002** — `try_award_floor_clear` is reclaim-aware: it credits the gap `(bonus_amount - already_credited)`, which can be 0 (already credited at or above this amount), partial (LOSING first-clear followed by WIN reclaim credits the LOSING→WIN delta), or full (first credit of any kind for this floor).

**Corrected behavior**: During the 8-hour offline replay, the Dungeon Run Orchestrator's `compute_offline_run(tick_budget)` path (Orchestrator GDD #13 §C.4) detects the first-clear inside the replay window via `batch.first_clear_tick > 0` and the per-dispatch `snapshot.floor_clear_emitted == false` guard, then executes two side-effects in sequence:

1. **Economy call**: `Economy.try_award_floor_clear(floor_index=3, bonus_amount=_attribute_floor_clear_bonus(3, snapshot.losing_run))`. Economy's implementation (§C.2.3a step 7) runs the credit-the-gap formula against `floor_clear_bonus_credited[3]` (absent key ≡ 0), credits `(bonus_amount - already_credited)` gold via `gold_balance += delta`, updates `floor_clear_bonus_credited[3] = bonus_amount`, and — if and only if this was the first non-zero credit — emits `first_clear_awarded(3)` exactly once (see §C.2.3a step 7 contract).
2. **Orchestrator signal emission** (**Pass-I.15-fix 2026-04-21**): `floor_cleared_first_time.emit(snapshot.floor.floor_index=3, snapshot.biome_id, snapshot.losing_run)` fires on the Orchestrator autoload — identical payload and count to the foreground-path emission at Orchestrator §C.3 line 249. The Floor Unlock System (#16) is the sole subscriber; its `_on_floor_cleared_first_time(floor_index, biome_id, losing_run)` listener advances `_highest_cleared_floor` and unlocks the next floor. **Prior to Pass-I.15-fix, C.4 omitted this emission** — offline first-clears credited gold but the next floor stayed LOCKED. Silent Pillar 1 violation (player returns to a guild where gold appeared but progression didn't). Fix: mirror the C.3 emission pattern exactly (same signal, same payload, same idempotency guard).

On session resume, the Return-to-App screen (#20) reads `OfflineRunResult` (populated by Orchestrator §C.4) including `gold_clear_bonus`, `gold_kills`, `kills_by_archetype` totals, and displays "Floor 3 cleared while you were away! +3,000 gold." The floor-unlock advancement is already on disk by that point — Floor Unlock persisted the unlock state through the heartbeat-driven `get_save_data` path before the screen renders (Save/Load GDD #3 Rule 5 heartbeat cadence + AC-SL-01 round-trip).

**Double-credit prevention**: three idempotency layers apply (Orchestrator §F invariant #3): (a) Combat emits `first_clear_in_range` / `batch.first_clear_tick > 0` statelessly per call — each call reports facts; (b) Orchestrator's `snapshot.floor_clear_emitted: bool` per-dispatch flag prevents same-dispatch re-emission in both C.3 and C.4; (c) Economy's `floor_clear_bonus_credited[floor_index]` dict makes `try_award_floor_clear` no-op on `bonus_amount <= already_credited`. A bug in any single layer fails loudly in tests (AC-ORC-09 foreground/offline parity; Economy AC H-14 per-lifetime idempotency; Combat AC-COMBAT-10 determinism) without producing silent double-credit in production.

### E.5 Matchup Multiplier Applied to a Class the Player No Longer Owns

**Scenario**: Save file records `formation_slot_1 = "rogue"`. Between the last save and this session, a data update or load error causes the Rogue class definition to be missing. The formation is partially invalid.

**Behavior**: The Formation Assignment System is responsible for validating formation integrity at load time (per Save/Load GDD fallback rules). Economy does not independently re-validate class definitions. If the Formation Assignment System emits `formation_invalid` and resets the slot to empty, Economy sees `copies_owned = 0` for Rogue and `drip_per_tick = 0` for that slot. Matchup multiplier is never applied to a missing class because the Matchup Resolver only evaluates classes present in the validated formation. Economy is a passive consumer here — it never owns class registry state.

### E.6 try_spend Race Condition — Double-Click on Recruit Button

**Scenario**: The player taps "Recruit Warrior" twice in rapid succession. Both UI events fire before the first `try_spend` completes and the UI updates to reflect the new balance.

**Behavior**: `try_spend` is a synchronous function that mutates `gold_balance` atomically within GDScript's single-threaded execution model. GDScript does not have true concurrency — signal handlers and method calls execute sequentially on the main thread. The second call to `try_spend` will see the post-first-deduction balance. If the player can afford two recruits, both succeed (intended). If they can only afford one, the second `try_spend` returns `false` and the Recruitment System rejects the second recruit without charging gold. No over-charge is possible under GDScript's execution model.

**UI responsibility**: The Recruit button must disable itself immediately on the first tap and re-enable only after `try_spend` returns and the UI has refreshed. This is a UI constraint, not an economy constraint — but documented here because the failure mode (rapid double-spend) is visible at the economy layer.

### E.7 Negative Balance Attempted

**Scenario**: `try_spend(amount)` is called with `amount > gold_balance`.

**Behavior**:
```gdscript
func try_spend(amount: int, reason: String) -> bool:
    # Signature locked by docs/architecture/ADR-0013 §Decision §2.
    # `reason` is required free-text (e.g. "recruit_warrior", "level_up_mage_3")
    # for telemetry + HUD coalesce filtering. Call sites never pass "".
    if amount < 0:
        push_error("try_spend called with negative amount: " + str(amount))
        return false
    if amount == 0:
        return true  # AC H-12 no-op success (§H)
    if gold_balance < amount:
        return false  # silent rejection; caller handles UI feedback
    gold_balance -= amount
    # gold_changed(new_balance, -amount, reason) emitted unless _is_offline_replay
    return true
```
Balance is never negative. Callers (Recruitment, Leveling) are responsible for querying `gold_balance` before offering the purchase as available and for displaying appropriate "insufficient gold" feedback on `false` return. Economy emits no signal on rejection — UI already knows the balance.

### E.8 Save File Older Than 180 Days (Long-Term Idle)

**Scenario**: Player installs, plays Day 1, closes app, and returns 6 months later.

**Behavior**: `offline_elapsed_seconds` is clamped to `offline_cap_seconds = 28800` (8 hours), regardless of actual elapsed time. The player receives at most 8 hours of offline income — the same as any normal overnight gap. Gold accumulates at the offline cap amount, not 180 days' worth. This is explicitly by design (Pillar 1: no FOMO — but also no exploit where absence is economically optimal over engagement). The player returns to a capped reward and must resume normal session cadence to progress further. No special behavior is required; the existing cap handles this automatically.

### E.9 Tuning Knob Change in a Patch Affecting Existing Saves

**Scenario**: A post-launch patch lowers `RECRUIT_RATIO` from 1.8 to 1.6, making existing heroes cheaper. A player who bought 3 Warrior copies at the old cost effectively overpaid relative to the new costs.

**Behavior**: Economy does not recompute or refund historical spend. Saved `gold_balance` is unchanged. Future `recruit_cost()` calls use the new ratio — existing players benefit from lower future costs but are not refunded past spend. This is the standard incremental balance policy in idle games: tuning changes apply forward-only, not retroactively. Rationale: retroactive recalculation could invalidate other progression assumptions (e.g., a player at max level who would have had extra gold to spend differently). Document all tuning knob changes in the patch notes with this forward-only policy explicitly stated. If a change is so large it materially disadvantages existing saves (e.g., doubling all recruit costs mid-game), the patch should include a one-time compensation gold grant, implemented as a save-migration step in the Save/Load system.

---

## F. Dependencies

### Upstream Dependencies (systems this one depends on)

| Upstream | Hard/Soft | Interface | Locked contracts |
|---|---|---|---|
| **Game Time & Tick System** (`design/gdd/game-time-and-tick.md`) | Hard | Subscribes to `tick_fired(tick_number: int)` signal at 20 Hz; reads `TICKS_PER_SECOND=20`, `offline_cap_seconds=28800` from registry | Never uses `_process(delta)`; replay path does not emit `tick_fired` signals (Offline Engine calls batch method directly) |
| **Save/Load System** (`design/gdd/save-load-system.md`) | Hard | Exposes `get_save_data() -> Dictionary` / `load_save_data(data)`; persisted keys: `gold_balance`, `lifetime_gold_earned`, `floor_clear_bonus_credited` (Dictionary[int, int] per ADR-0002; supersedes the Pass 4B-Economy `floors_cleared_bonus_awarded: Array[bool]`) | No direct file I/O; Save/Load orchestrates persistence |
| **Hero Roster** (system #9) | Hard | Reads `roster.get_formation_strength() -> float` for drip calculation | Contract locked by `docs/architecture/ADR-0012-hero-roster-mutation-and-identity.md` §Decision §2 (return range [1.0, 3.0]; empty-formation guard returns 1.0; read per foreground tick + once per offline-replay batch start per §C.6 replay contract) |
| **Dungeon Run Orchestrator** (system #13 — Pass 4A applied) | Hard | Reads `orchestrator.get_current_drip_per_tick() -> int` (each foreground tick); exposes `Economy.add_gold(amount: int, reason := "credit") -> void` (called by Orchestrator per kill, with `LOSING_RUN_LOOT_FACTOR` already applied by Orchestrator; `reason` string identifies the credit source e.g. `"kill_tier_2"`, `"floor_clear_3"`, `"tick_drip"` — ADR-0013 signature); exposes `Economy.try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool` (first-clear award, see C.2.3a) | Orchestrator owns `losing_run` state and applies `LOSING_RUN_LOOT_FACTOR` before calling Economy. Economy does NOT independently apply the loot factor (codified by ADR-0013 §Decision §5 forbidden pattern `economy_reads_losing_run_state`). Drip subscription (`tick_fired`) is independent of run-outcome state (see A2, Economy review log Pass 4B-Economy) |

### Downstream Dependents (systems that depend on this)

| Consumer | Hard/Soft | Interface | What they read/write |
|---|---|---|---|
| **Recruitment System** (#14) | Hard | `economy.try_spend(amount: int, reason: String) -> bool` (ADR-0013); reads `recruit_cost(class_id: String, copies_owned: int) -> int` (ADR-0013 — id-string keyed; Economy resolves tier internally) | Spend on hero purchase |
| **Hero Leveling System** (#15) | Hard | `economy.try_spend(amount: int, reason: String) -> bool` (ADR-0013); reads `level_cost(class_tier: int, current_level: int) -> int` (returns -1 at cap — AC H-08) | Spend on level-up |
| **Offline Progression Engine** (#12) | Hard | Calls `economy.compute_offline_batch(tick_budget: int) -> OfflineResult` | Batch replay of elapsed ticks |
| **Dungeon Run Orchestrator** (#13) | Hard | Pushes `current_drip_per_tick`, emits kill/clear signals | Bidirectional — Economy reads and receives |
| **Return-to-App / Offline Rewards Screen** (#20) | Hard | Reads `OfflineResult.events_log` to render "while you were away" summary | Read-only display |
| **Guild Hall Screen** (#19) | Hard | Subscribes to `gold_changed(new_balance: int, delta: int, reason: String)` signal (ADR-0013 — 3-arg payload; `reason` enables HUD filtering of drip vs. kill vs. floor-clear credit surfaces) for HUD refresh | Read-only display |
| **Recruit Screen** (#21), **Roster/Hero Detail** (#22) | Soft | Reads `gold_balance` to grey out unaffordable buttons | Read-only display |
| **Class Synergy System** (#32, V1.0 first-pass 2026-05-09) | Hard — config storage | New constants in `economy_config.tres`: `STEEL_WALL_GOLD_MULT = 1.25`, `TRIPLE_THREAT_GOLD_MULT = 1.15`, `ARCANE_ELITE_XP_MULT = 1.20`, `BASE_XP_PER_KILL = 10`, `class_synergy_audio_suppress_window_seconds = 2.0`. Per `class-synergy-system.md` §G. No formula change to Economy itself. AC-CS-16 enforces ≤+50% multiplier cap via static analysis. |
| **Prestige System** (#31, V1.0 first-pass 2026-05-09) | Hard — config storage | New constants in `economy_config.tres`: `PRESTIGE_GAIN_PER = 0.05`, `PRESTIGE_MULTIPLIER_CAP = 2.0`, `PRESTIGE_MAX = 20`, `prestige_audio_suppress_window_seconds = 2.0`, `hall_card_animation_duration_seconds = 0.3`. Per `prestige-system.md` §G. AC-PR-16 enforces the GAIN_PER × MAX = CAP - 1.0 invariant. |

### Bidirectional Consistency

- `design/gdd/game-time-and-tick.md` Dependencies section: ✅ lists Economy as hard dependent with `tick_fired` + `TICKS_PER_SECOND` interface
- `design/gdd/save-load-system.md` Dependencies section: ✅ lists Economy as hard dependent with `get_save_data`/`load_save_data` contract
- Undesigned downstream GDDs (Recruitment, Leveling, Offline Engine, Dungeon Run Orchestrator, Return-to-App) will cite "depends on Economy System" when authored. Their GDDs must respect the `try_spend` and `compute_offline_batch` contracts defined above.

---

---

## G. Tuning Knobs

All knobs live in a single data resource `assets/data/economy_config.tres` (or equivalent external config), loaded at startup by the Data Loading System. No economy value is hardcoded in GDScript — every constant below is a field on this resource.

| Knob name | Default value | Safe range | What it affects | Risk if pushed high | Risk if pushed low |
|---|---|---|---|---|---|
| `BASE_DRIP[1]` | 2 | 1 – 5 | Floor 1 gold income per tick | Trivially abundant early-game gold; all early recruits feel free; removes cost decisions | First session feels stingy; players may not see a spend opportunity in Session 1 |
| `BASE_DRIP[2]` | 4 | 2 – 10 | Floor 2 gold income per tick | Floors 1-2 gap collapses; no incentive to progress | Floor 2 barely improves income |
| `BASE_DRIP[3]` | 7 | 3 – 18 | Floor 3 gold income per tick | Tier-2 class becomes affordable before Day 3 breakthrough moment | Mid-game saving periods stretch to frustration |
| `BASE_DRIP[4]` | 12 | 5 – 30 | Floor 4 gold income per tick | Late-game levels trivially affordable | Late-game levels require weeks |
| `BASE_DRIP[5]` | **8** *(was 20 pre-Pass-3B)* | 4 – 25 | Floor 5 gold income per tick; the endgame income rate. **Reduced 2026-04-20 to preserve the "10–14 days to max" pillar promise — see D.1 rationale.** Currently lower than F4 drip; the curve is intentionally non-monotonic pending full revalidation. | End-game overshoots; prestige layer (V1.0) never creates scarcity; pillar broken | Floor 5 feels no better than floor 4 (current state — accepted as temporary) |
| `MATCHUP_GOLD_MULTIPLIER` | 1.5 | 1.0 – 2.5 | Per-kill gold bonus when class counters enemy type | Matchup becomes overwhelming — neutral formation feels useless | Matchup advantage is economically invisible; Pillar 3 fails |
| `MATCHUP_DRIP_BONUS` | 1.0 | 1.0 – 1.3 | Per-tick drip multiplier for matchup-advantaged formations | Combined with kill bonus, may make mismatched formations feel punishing | No effect (1.0 = disabled) |
| `BASE_RECRUIT[tier_1]` | 150 | 50 – 500 | Cost of first copy of Warrior, Mage, or Rogue | First session recruit cost too high — no "free" second hero feeling | First recruit costs nothing; no spend hook in Session 1 |
| `BASE_RECRUIT[tier_2]` | 8 000 | 2 500 – 20 000 | Cost of first Tier-2 class; the Day 3-4 breakthrough gate | Tier-2 is unreachable within MVP's 1-week window; players never see new classes | Tier-2 feels trivially unlocked; breakthrough moment deflated |
| `RECRUIT_RATIO` | 1.8 | 1.2 – 2.5 | Geometric escalation for each additional copy of the same class | Stacking identical classes is effectively impossible; only one of each class makes sense | Players trivially stack the best class; formation diversity disappears |
| `BASE_LEVEL[tier_1]` | 40 | 15 – 100 | Cost to level a Tier-1 hero from L1 → L2 | Early level-ups require saving; first level-up delayed past Session 1 target | First level-up is functionally free; no spend hook in first minute |
| `BASE_LEVEL[tier_2]` | 600 | 200 – 1 500 | Cost to level a Tier-2 hero from L1 → L2 | Tier-2 heroes are never leveled; players sit them at L1 forever | Tier-2 heroes instantly outscale Tier-1 |
| `LEVEL_RATIO` | 1.6 | 1.3 – 2.0 | Geometric escalation per hero level | High levels (12-15) are multi-week grinds; level cap feels unreachable | All levels affordable quickly; level cap hit in Day 2; no long-term sink |
| `LEVEL_CAP` | 15 | 10 – 20 | Maximum hero level in MVP | More upper-range levels needed; risk of "too many sessions to hit a wall" | Players hit cap too early; no spend destinations mid-week |
| `FLOOR_CLEAR_BONUS[1]` | 500 | 200 – 1 500 | One-shot reward for first Floor 1 clear | Overshoots Tier-1 recruit cost; clear bonus funds too much progression at once | Clear bonus feels like a rounding error |
| `FLOOR_CLEAR_BONUS[2]` | 1 200 | 500 – 3 500 | One-shot reward for first Floor 2 clear | Same overshoot risk | Same undershoot risk |
| `FLOOR_CLEAR_BONUS[3]` | 3 000 | 1 200 – 8 000 | One-shot reward for first Floor 3 clear | Significantly accelerates Tier-2 recruit timeline | Milestone reward feels underwhelming |
| `FLOOR_CLEAR_BONUS[4]` | 7 500 | 3 000 – 20 000 | One-shot reward for first Floor 4 clear | Overshoots multiple level-up costs simultaneously | Deep-game clear feels unrewarding |
| `FLOOR_CLEAR_BONUS[5]` | 18 000 | 7 500 – 50 000 | One-shot reward for first Floor 5 clear; the MVP "beat game" reward | Covers entire remaining cost to max one hero; may deflate end-of-week grind | Anticlimactic at the MVP finale |
| `GOLD_SANITY_CAP` | 1 000 000 000 000 | 100 000 000 – int64 max | Engineering ceiling; silently clamps balance | (No gameplay effect in MVP — only matters if V1.0 scale changes) | Could create an artificial ceiling that players hit; display must cap at T notation |
| `offline_cap_seconds` | 28 800 | 14 400 – 43 200 | Maximum creditable offline time (8h default) — defined in Game Time GDD; referenced here | 12h cap: players who sleep 8h and commute 4h always get full credit; more generous | 4h cap: players who sleep normal hours lose offline income; FOMO-adjacent |
| `DISPLAY_K_THRESHOLD` | 1 000 | 500 – 2 000 | Balance value at which display switches from raw to K notation | Large raw numbers visible in early-game | "K" appears too soon; feels like inflated numbers |
| `DISPLAY_M_THRESHOLD` | 1 000 000 | 500 000 – 2 000 000 | Balance at M threshold | (No practical game effect) | (No practical game effect) |
| `DISPLAY_B_THRESHOLD` | 1 000 000 000 | — | Balance at B threshold | (No practical effect in MVP) | (No practical effect in MVP) |
| `DISPLAY_T_THRESHOLD` | 1 000 000 000 000 | — | Balance at T threshold; matches sanity cap | (No practical effect in MVP) | (No practical effect in MVP) |

**Recommended first-playtest tuning pass order** (highest leverage knobs to tune first):
1. `BASE_RECRUIT[tier_2]` — governs the Day 3-4 breakthrough moment
2. `BASE_DRIP[1]` and `BASE_DRIP[3]` — set the income pace of Sessions 1 and mid-game
3. `MATCHUP_GOLD_MULTIPLIER` — verify Pillar 3 payoff is legible without being dominant
4. `LEVEL_RATIO` — governs how long levels remain meaningful as a sink
5. `FLOOR_CLEAR_BONUS[3]` through `[5]` — milestone reward feel

---

## H. Acceptance Criteria

All criteria use Given-When-Then format. 13 criteria total (12 BLOCKING + 1 ADVISORY).

### H-01 — Active Dungeon Drip Rate (Integration, BLOCKING)

**GIVEN** a dungeon run is active on floor 3, `formation_strength_factor = 1.2`, `matchup_drip_factor = 1.0`, `BASE_DRIP[3] = 7`,
**WHEN** `tick_fired` fires one tick,
**THEN** `add_gold` is called with exactly `floor(7 × 1.2 × 1.0) = 8`; `gold_changed` is emitted only if the delta crosses the display threshold; the raw int64 balance reflects the exact amount with no floating-point residue.

### H-02 — Enemy Kill Bonus (Integration, BLOCKING)

**GIVEN** a Tier-2 enemy dies during an active run, `matchup_multiplier = 1.5`, `BASE_KILL[2] = 35`,
**WHEN** Economy receives the `enemy_killed(2, true)` signal,
**THEN** gold increases by exactly `floor(35 × 1.5) = 52`; the bonus is applied once (not per-tick); no additional drip adjustment from this event.

### H-03 — Floor-Clear Bonus Monotonic-Credit Idempotent (Logic, BLOCKING)

*(Pass 5B / ADR-0002 rewrite — boolean gate replaced by monotonic-int ceiling.)*

**GIVEN** floor 3 has never been credited (`floor_clear_bonus_credited.get(3, 0) == 0`),
**WHEN** `try_award_floor_clear(3, 3000)` is called (non-LOSING full bonus), and then `try_award_floor_clear(3, 3000)` is called a second time in the same session due to a duplicate signal from Orchestrator (replay edge case),
**THEN** the first call credits 3000 gold via `add_gold(3000)`, fires `first_clear_awarded(3)` exactly once, sets `floor_clear_bonus_credited[3] = 3000`, and returns `true`; the second call returns `false` (bonus_amount = 3000 ≤ already_credited = 3000), credits zero gold, does NOT re-emit `first_clear_awarded`, and leaves `floor_clear_bonus_credited[3]` unchanged at 3000. Total gold credited across the two calls = 3000.

*Contract clarification*: Economy owns the `floor_clear_bonus_credited: Dictionary[int, int]` tracking dictionary (persisted in save). Dungeon Run Orchestrator may fire duplicate signals under replay edge cases; Economy is responsible for the monotonic-credit idempotency guard (Orchestrator's `floor_clear_emitted: bool` flag is Layer 2 defense-in-depth within a single dispatch; Economy's ceiling is Layer 3 authoritative across the save lifetime).

### H-04 — Matchup Advantage Multiplier (Logic, BLOCKING)

**GIVEN** a dungeon run with matchup multiplier M (M ≠ 1.0),
**WHEN** one tick fires and one enemy kill is processed in the same tick,
**THEN** drip = `base_drip × formation_factor × matchup_drip_factor` (drip uses `MATCHUP_DRIP_BONUS`, default 1.0); kill bonus = `base_kill × MATCHUP_GOLD_MULTIPLIER`; both read M from state at the tick moment, not from a cached earlier value.

### H-05 — try_spend Atomic: Insufficient Returns False, No Mutation (Logic, BLOCKING)

**GIVEN** player has 100 gold,
**WHEN** `try_spend(150)` is called,
**THEN** returns `false`; balance remains exactly 100; no `gold_changed` signal emitted; no partial deduction.

### H-06 — try_spend Atomic: Sufficient Deducts Exactly (Logic, BLOCKING)

**GIVEN** player has 500 gold,
**WHEN** `try_spend(200)` is called,
**THEN** returns `true`; balance is exactly 300; `gold_changed` emitted if 300 differs from 500 by at least the display-refresh threshold.

### H-07 — Geometric Recruit Cost — 1.8× per Copy (Logic, BLOCKING)

**GIVEN** a Tier-1 class with `BASE_RECRUIT[tier_1] = 150`, player owns N copies (N = 0, 1, 2, 3),
**WHEN** the recruit cost is queried for copy N+1,
**THEN** cost = `floor(150 × 1.8^N)`: N=0→150, N=1→270, N=2→486, N=3→874; ratio of cost(N+1)/cost(N) = 1.8 within integer rounding; verified for N = 0..3 as independent sub-cases.

### H-08 — Geometric Level Cost + Cap Enforcement (Logic, BLOCKING)

**GIVEN** a Tier-1 hero at current_level L (L = 1..14), `BASE_LEVEL[tier_1] = 40`, `LEVEL_RATIO = 1.6`, `LEVEL_CAP = 15`,
**WHEN** level-up cost is queried for L+1,
**THEN** cost = `floor(40 × 1.6^(L-1))`; L=1→40, L=2→64, ..., L=14→18018; querying for L=15→16 returns **-1** (sentinel for "past cap"), not a valid gold amount.

*Contract clarification*: `level_cost` returns `-1` for any query past `LEVEL_CAP`. Callers (Hero Leveling UI) must check for -1 before offering the purchase and display "max level reached" instead.

### H-09 — Offline Replay Determinism (Integration, BLOCKING)

**GIVEN** identical starting state (gold=0, floor=2, formation_strength=1.0, matchup=1.0, no kills, no clears) applied to two Economy instances,
**WHEN** instance A calls `compute_offline_batch(576000)` and instance B processes the same 576 000 ticks foreground (via `tick_fired` signal),
**THEN** both report identical final gold balances and identical `lifetime_gold_earned`; repeated runs produce zero variance; RNG seed = `t_last_persist XOR offline_tick_budget` is used in batch replay to ensure determinism.

### H-10 — Offline Replay Performance (Performance, BLOCKING)

**GIVEN** a fresh Economy instance with standard benchmark state,
**WHEN** `compute_offline_batch(576000)` is called (no signal emission, no UI callbacks),
**THEN** wall-clock elapsed time < **500 ms** on minimum-spec reference hardware; per-tick average < 0.87 μs; test fails if any single run exceeds 500 ms (not just the average).

*Verification*: performance integration test; log p50/p95/p99 to `production/qa/evidence/economy-offline-[date].md`.

### H-11 — Save Round-Trip (Integration, BLOCKING)

*(Pass 5B — field rename: `floors_cleared_bonus_awarded: Array[bool]` → `floor_clear_bonus_credited: Dictionary[int, int]`.)*

**GIVEN** an Economy instance with `gold_balance = 12345`, `lifetime_gold_earned = 98765`, `floor_clear_bonus_credited = {1: 500, 2: 1200, 3: 1500}` (F1 fully credited at its full bonus; F2 fully credited; F3 LOSING-first-cleared so only half credited; F4 + F5 absent keys ≡ 0 / not yet credited),
**WHEN** `get_save_data()` is called, a new instance is created, and `load_save_data(data)` is called,
**THEN** restored instance reports gold = 12345, lifetime = 98765, `floor_clear_bonus_credited` dictionary matches exactly key-for-key and value-for-value (including absent keys — the restored dict has exactly the three keys present in the original, not five); new instance can immediately process ticks and accept `try_spend` without reinitialization. Subsequent `try_award_floor_clear(3, 3000)` on the restored instance credits the delta `3000 - 1500 = 1500` gold (per ADR-0002 reclaim path); `floor_clear_bonus_credited[3]` advances to 3000.

### H-12 — try_spend(0) No-Op (Logic, BLOCKING)

**GIVEN** player has any balance B (including B = 0),
**WHEN** `try_spend(0)` is called,
**THEN** returns `true`; balance remains B; no `gold_changed` signal emitted. Defensive: `try_spend` with negative amount returns `false` with `push_error`.

### H-13 — Display Threshold Abbreviations (Logic, ADVISORY)

**GIVEN** a display formatter connected to `gold_changed`,
**WHEN** gold crosses 1 000, 1 000 000, 1 000 000 000 respectively,
**THEN** [0, 999] → raw integers; [1K, 999 999] → `#.##K`; [1M, 999.99M] → `#.##M`; [1B, 999.99B] → `#.##B`; ≥ 1T → `#.##T`; inclusive at lower bound.

*Gate = ADVISORY*: a broken formatter does not corrupt gold state; can ship as known visual issue if needed.

### H-14 — try_award_floor_clear Monotonic-Credit Idempotency (Logic, BLOCKING)

*(Pass 5B / ADR-0002 rewrite — WIN-first path + anti-exploit gate.)*

**GIVEN** an Economy instance with `floor_clear_bonus_credited = {}` (fresh save; F1–F5 all at implicit 0 credit),
**WHEN** `try_award_floor_clear(3, 3000)` is called (WIN first-clear, full bonus), then `try_award_floor_clear(3, 3000)` is called again (duplicate signal), then `try_award_floor_clear(3, 1500)` (later LOSING re-run with halved `bonus_amount`),
**THEN** the first call returns `true`, credits 3000 gold via `add_gold(3000)`, fires `first_clear_awarded(3)` signal exactly once, and sets `floor_clear_bonus_credited[3] = 3000`; the second call returns `false` (bonus_amount = 3000 ≤ already_credited = 3000), credits zero gold, and does NOT re-emit `first_clear_awarded`; the third call returns `false` (bonus_amount = 1500 ≤ already_credited = 3000 — LOSING after full WIN), credits zero gold. Total gold credited across the three calls = 3000. Anti-exploit: the credited total for F3 never exceeds `FLOOR_CLEAR_BONUS[3] = 3000`.

**Sub-AC 14-losing-first-then-win-reclaim** *(Pass 5B / ADR-0002 — "no fail state" reclaim path; new)* — **GIVEN** a fresh save (`floor_clear_bonus_credited = {}`), **WHEN** `try_award_floor_clear(3, 1500)` is called (LOSING first-clear, halved bonus = `floori(3000 × 0.5)`), then `try_award_floor_clear(3, 3000)` is called (later non-LOSING WIN on the same floor, full bonus), **THEN** the first call returns `true`, credits 1500 gold via `add_gold(1500)`, fires `first_clear_awarded(3)` signal exactly once, and sets `floor_clear_bonus_credited[3] = 1500`; the second call returns `true`, credits the delta `3000 - 1500 = 1500` gold via `add_gold(1500)`, **does NOT re-emit** `first_clear_awarded` (the floor's first-clear milestone already fired on the LOSING path — the reclaim is a delta credit, not a milestone event), and advances `floor_clear_bonus_credited[3] = 3000`. Total gold credited across the two calls = 3000 (full bonus, delivered in two installments). A subsequent third call of any kind (`try_award_floor_clear(3, 3000)` WIN-repeat, or `try_award_floor_clear(3, 1500)` LOSING-repeat) returns `false` and credits zero gold — the floor is now fully credited.

**Sub-AC 14-win-then-losing-no-reclaim** *(Pass 5B / ADR-0002 — inverse-order anti-exploit check; new)* — **GIVEN** a fresh save, **WHEN** `try_award_floor_clear(3, 3000)` is called (WIN first-clear), then `try_award_floor_clear(3, 1500)` is called (later LOSING re-run), **THEN** the first call credits 3000 and fires the signal; the second call returns `false` (1500 ≤ 3000) and credits zero — the player who won the first clear on a WIN cannot "reclaim" anything on a LOSING re-run (there is no reclaim below the established ceiling). Total credited = 3000.

**Sub-AC 14-boundary** — **GIVEN** `floor_index = 0` or `floor_index = 6` (out-of-range), **WHEN** `try_award_floor_clear` is called, **THEN** `push_error("Economy.try_award_floor_clear: floor_index=X out of range [1,5]")`; returns `false`; no gold credited; no state mutation (including no insert into `floor_clear_bonus_credited` for the bad key).

**Sub-AC 14-negative-bonus** — **GIVEN** `bonus_amount = -100` (authoring-bug sentinel), **WHEN** `try_award_floor_clear(1, -100)` is called on an unclaimed floor, **THEN** `push_error("Economy.try_award_floor_clear: bonus_amount=X is negative (authoring bug)")`; returns `false`; no gold credited; `floor_clear_bonus_credited[1]` remains absent / 0 (the floor is NOT marked credited by a bad call — the player gets another chance with a correct value).

**Sub-AC 14-zero-bonus** *(re-review ε: AC-H-14-zero-bonus — promoted from RECOMMENDED to BLOCKING via Pass 5B)* — **GIVEN** an unclaimed floor (e.g., `floor_clear_bonus_credited[1]` absent), **WHEN** `try_award_floor_clear(1, 0)` is called (degenerate — would happen only if Orchestrator computed `floori(FLOOR_CLEAR_BONUS[1] × 0.0) = 0` with `LOSING_RUN_LOOT_FACTOR = 0.0`; ADR-0002 recommends clamping the lower bound to 0.5, but 0.0 remains technically reachable), **THEN** returns `false` (bonus_amount = 0 ≤ already_credited = 0 — the gate catches the degenerate case without issuing any signal or gold credit); `floor_clear_bonus_credited[1]` remains absent / 0. The floor is NOT recorded as credited, so a subsequent `try_award_floor_clear(1, 500)` WIN still credits the full 500g.

*Verification*: unit test per `tests/unit/economy/test_try_award_floor_clear_idempotency.gd`. Gold spy on `add_gold` calls; signal spy on `first_clear_awarded` (asserts exactly one emission for the true-first-clear case, zero re-emissions on any reclaim or repeat path); direct dictionary read on `floor_clear_bonus_credited`. Resolves Orchestrator C.6 layer-3 idempotency contract (Economy is the authoritative monotonic-credit gate; Orchestrator's `floor_clear_emitted` is defense-in-depth within a single dispatch). Also verifies the Orchestrator-side AC-ORC-04 Sub-AC 04-losing-first-clear-then-win-credits-delta at the Economy boundary. Pass 4B-Economy A1 introduction + Pass 5B / ADR-0002 reclaim semantic.

### Classification Summary

| ID | Description | Type | Gate |
|---|---|---|---|
| H-01 | Active dungeon drip rate | Integration | BLOCKING |
| H-02 | Kill bonus on enemy death | Integration | BLOCKING |
| H-03 | Floor-clear bonus idempotent | Logic | BLOCKING |
| H-04 | Matchup multiplier applied correctly | Logic | BLOCKING |
| H-05 | try_spend atomic (insufficient) | Logic | BLOCKING |
| H-06 | try_spend atomic (sufficient) | Logic | BLOCKING |
| H-07 | Geometric recruit cost | Logic | BLOCKING |
| H-08 | Geometric level cost + cap → -1 | Logic | BLOCKING |
| H-09 | Offline replay determinism | Integration | BLOCKING |
| H-10 | Offline replay < 500ms | Performance | BLOCKING |
| H-11 | Save round-trip | Integration | BLOCKING |
| H-12 | try_spend(0) no-op | Logic | BLOCKING |
| H-13 | Display abbreviations | Logic | ADVISORY |
| H-14 | try_award_floor_clear per-lifetime idempotency | Logic | BLOCKING |

---

## I. Open Questions

| Question | Owner | Target Resolution |
|---|---|---|
| ~~`formation_strength_factor` final formula~~ **RESOLVED 2026-04-19**: Hero Roster GDD #9 locks the formula as `clamp(1.0 + (avg_formation_level - 1) * 0.2, 1.0, 3.0)`, implemented in `HeroRoster.get_formation_strength()`. Variable name is `avg_formation_level` (mean `current_level` across active formation heroes). Empty formation returns 1.0 via guard clause. Economy calls Roster each tick. | ✅ economy-designer + systems-designer | ✅ Resolved with Hero Roster GDD (2026-04-19) |
| Kill frequency assumption — "1 kill per 10 seconds active" is a placeholder for pacing math. Actual rate is owned by Combat Resolution System (GDD #11). Revisit Section D.6 pacing table once Combat Resolution locks kill cadence. | economy-designer (reviews Combat Resolution output) | Before `/prototype` of Offline Engine |
| **Drip curve holistic rebalance (Pass 3B regression)** — Pass 3B reduced `BASE_DRIP[5]` 20 → 8 to close Combat GDD #11 Pass 2B Re-Review Blocker 4 (F5 overnight drip ~78× max-Tier-1 cost). The fix breaks the previously-documented monotonic progression (F1–F5: 2/4/7/12/8). Need a full curve revalidation against the "10–14 days to max" pillar: validate cumulative gold across 10 days × 8h overnight + active play vs total max-everything cost (Tier-1 + Tier-2 recruits + level-15 across roster + clear bonuses). Likely outcomes: (a) reduce F1–F4 proportionally to restore monotonicity at lower absolute scale, OR (b) raise Tier-2/level costs, OR (c) shorten `offline_cap_seconds` for higher floors. **MUST resolve before first MVP playtest** — the current curve will mislead playtest pacing data. | economy-designer (lead) + game-designer | Before first MVP playtest — gates Combat GDD #11 final approval |
| Tier-2 recruit cost (8 000 gold) — playtest verification. The D.6 model says ~half-day of Floor 3 income, which should match "Day 3-4 breakthrough" target. Verify in playtest; adjust the `BASE_RECRUIT[tier_2]` knob within its safe range (2 500 – 20 000) based on feel. | economy-designer | First MVP playtest |
| `MATCHUP_DRIP_BONUS` — defaults to 1.0 (disabled). If kill-only matchup bonus is too subtle in playtest, flip to 1.15 and re-tune kill bonus downward. | economy-designer | First MVP playtest |
| Consumer list for AC-SL-01 integration test (in Save/Load GDD) — this GDD now documents Economy's `get_save_data` keys (`gold_balance`, `lifetime_gold_earned`, `floor_clear_bonus_credited` per Pass 5B / ADR-0002). Other consumers (Roster, Unlock, Formation) will add theirs. | main session (coordinating) | As downstream GDDs are written |
| Closed-form drip batch — if a mid-replay formation change or dungeon switch becomes possible in V1.0, the O(1) closed-form breaks. For MVP, formation is frozen at last persist; revisit only if V1.0 allows mid-offline formation swaps. | systems-designer | V1.0 scope planning |
| Prestige resets (V1.0) — how do they interact with `lifetime_gold_earned`? Reset it? Keep it? Both possible; decision is part of Prestige System GDD. | economy-designer + game-designer | During Prestige System GDD |
| Patch-time compensation grant policy — if a tuning knob change disadvantages existing saves significantly, the save-migration step grants compensation gold. Threshold and formula are policy questions, not MVP blockers. | live-ops-designer | Post-launch |
