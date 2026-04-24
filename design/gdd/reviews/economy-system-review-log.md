# Economy System — Review Log

First review log entry for `design/gdd/economy-system.md`. Earlier work is captured in the Combat review log (Pass 3B BASE_DRIP[5] edit 2026-04-20) and the Orchestrator review log (2026-04-20 Cluster A flagging). This log begins at the first Economy-owned revision pass.

## Review — 2026-04-20 — Pass 4B-Economy Applied — Verdict: CLUSTER A RESOLVED

**Scope**: Cluster A (5 cross-GDD contract items surfaced by Orchestrator GDD #13 design-review, 2026-04-20 MAJOR REVISION NEEDED verdict). Economy is the primary touchpoint; Combat + Orchestrator propagation was applied in the same pass to keep cross-GDD contracts coherent. Cluster B (Save/Load contract surface, 6 items) is out of scope — deferred to Pass 4B-SaveLoad as a separate pass.

### A1 — `Economy.try_award_floor_clear(floor_index, bonus_amount) -> bool` defined

Added the public method to Economy C.2.3a with full signature + behavior contract:
- `func try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool`
- First-call-per-floor: `add_gold(bonus_amount)`, set `floors_cleared_bonus_awarded[floor_index] = true`, emit `first_clear_awarded(floor_index)` signal, return `true`.
- Subsequent calls for the same `floor_index`: return `false`, no gold credited, no state mutation.
- Out-of-range `floor_index` (≤ 0 or > 5): `push_error`, return `false`.
- Negative `bonus_amount`: `push_error`, return `false`, do NOT mark the floor as cleared (player gets another chance with a corrected call).
- **Bonus_amount pre-multiplied**: the Orchestrator applies `LOSING_RUN_LOOT_FACTOR` (if `losing_run`) BEFORE calling `try_award_floor_clear`. Economy does NOT apply the factor independently.

Economy AC H-14 added covering idempotency + boundary + negative-bonus sub-ACs. AC H-03 was already in the GDD covering the three-layer idempotency model (Orchestrator C.6 layer 3); H-14 is the direct write-test for the interface contract.

### A2 — LOSING drip routing: **Option Y chosen** (Pass 2B decision 4 superseded)

**Decision**: LOSING runs do NOT halve drip. `LOSING_RUN_LOOT_FACTOR` applies to kill gold + floor-clear bonus only. Drip is run-outcome-independent by architecture.

**Rationale**: drip is owned entirely by Economy's independent `tick_fired` subscription path. Economy has no access to `RunSnapshot`; the Orchestrator has no architectural home for communicating `losing_run` to Economy's drip path without introducing a cross-system coupling (Option X — new `run_losing_state_changed(bool)` signal subscriber pattern) that has no testable ordering guarantee against `tick_fired` and would require a new idempotency layer for signal/tick race conditions. Cleaner boundary: **run-outcome-dependent rewards halve; run-outcome-independent rewards don't**. The LOSING feel already punches visibly through kill-gold and floor-clear halving. Halving drip would add UX confusion (idle income mysteriously slower without a visible losing-run indicator) without adding mechanical or narrative weight.

**Pillar impact**: Pillar 1 (no fail state) preserved. Pillar 2 (HP investment matters) retains teeth via kill-gold + floor-clear halving. Pillar 3 (matchup-driven cadence as the economic hook) unaffected — matchup still routes through kill-gold attribution independent of `losing_run`.

**MVP note**: `losing_run` is architecturally unreachable on naturally-constructable MVP formations — lowest natural `hp_bonus_factor` is solo L1 Rogue on F4 = 0.573, well above the 0.5 LOSING trigger. Player impact of the A2 decision in MVP is effectively zero; the knob is a V1.0-hard-content safety net.

**Files edited to propagate A2**:
- `design/gdd/economy-system.md` — C.2.3 LOSING_RUN scope note narrows halving to kill bonuses + first-clear only; C.2.3a prose notes the Orchestrator owns pre-multiplication; Dependencies table row for Orchestrator explicitly calls out drip-subscription as run-outcome-independent.
- `design/gdd/combat-resolution.md` — Rule 9 prose: halving scope narrowed from "drip + per-kill bonuses + FLOOR_CLEAR_BONUS" to "per-kill bonuses and FLOOR_CLEAR_BONUS only"; explicit superseded note citing this log.
- `design/gdd/dungeon-run-orchestrator.md` — E.5 second-clear-path prose: "half-rate drip" → "full-rate drip"; AC-ORC-04 verification clause: explicit note that drip is NOT asserted in LOSING end-to-end test.
- `design/gdd/reviews/combat-resolution-review-log.md` — Amendment appended: "Pass 2B Locked Decision 4 Superseded by Pass 4B-Economy" with full rationale trail.

**Flagged follow-up**:
- Economy GDD D.6 pacing math was computed under the Pass 2B-original scope (drip halved on LOSING). Because `losing_run` is architecturally unreachable in MVP, pacing should be indistinguishable from the old numbers — but a quick pass through D.6 at next tuning review is prudent. Flagged as tech debt, not blocking.
- `LOSING_RUN_LOOT_FACTOR` registry notes field still describes the old scope. Low-priority housekeeping; next `/consistency-check` will catch.

### A3 — `BASE_KILL[1]` reconciled to 10

Canonical value: **10**. This matches the registry (`attribute_kill_gold` formula notes: `BASE_KILL[1]=10`) and the Orchestrator GDD D.1 (output range 5–120 with lower bound `floori(10 × 1.0 × 0.5) = 5`, which requires `BASE_KILL[1] = 10`).

The Economy GDD had listed `BASE_KILL[1] = 15` in a pre-`LOSING_RUN_LOOT_FACTOR` draft where the minimum output was 15 (neutral, non-losing, tier 1). With the LOSING multiplier path added, the correct minimum is 5 → `BASE_KILL[1] = 10`. Economy GDD text updated to 10 throughout with a `> **A3 reconciliation**` inline callout. All pacing calculations using `BASE_KILL[1]` must be re-verified — noted in the flagged follow-up above.

No change to registry or Orchestrator GDD for A3 (both already had 10).

### A4 — `kill_bonus` delegated to `attribute_kill_gold`

Economy's previous `kill_bonus` formula produced a slightly different output range than Orchestrator's `attribute_kill_gold`. The formulas were arithmetically similar but carried independent variables + rounding; divergence was a ticking time bomb.

**Resolution**: Economy's `kill_bonus` is **deprecated in favour of Orchestrator's `attribute_kill_gold`**. The Orchestrator is the canonical call-site — it owns `losing_run` state, matchup lookup, and per-kill attribution. Economy receives `add_gold(amount)` post-attribution and does not recompute. Economy's formula section retains a reference pointer ("see Orchestrator D.1 for the authoritative formula") but no longer defines an independent formula.

Documentation-only change — no runtime behavior delta because the Orchestrator was already the sole caller of `add_gold` for kill gold.

### A5 — C.2.4 "33% faster" corrected to 2.25× combined

The Economy C.2.4 pacing claim "33% faster under matchup advantage" was arithmetically wrong in the Pass 2B-era text. The actual effect is **2.25× combined throughput+gold** under a full matchup advantage — because `MATCHUP_THROUGHPUT_FACTOR_ADV = 1.5` (Combat tempo) × `MATCHUP_GOLD_MULTIPLIER = 1.5` (Orchestrator gold) = 2.25× total per-enemy gold rate. The 33% figure conflated a single-multiplier path with the combined.

**Resolution**: C.2.4 prose rewritten to explicitly call out both multipliers and the 2.25× combined effect. Economy D.6 pacing table verified against the corrected figure — existing cells are consistent; the error was only in the narrative claim, not the numbers.

Flagged Orchestrator review E8 item ("MATCHUP double-dip 2.25× combined (not 1.5×); Economy D.6 pacing wrong by 33%") — D.6 pacing table verified correct; E8 is narrative-only and closed by A5.

### BLOCKERs closed (5 of 13 remaining post-Pass-4A)

Cluster A (5): **A1 / E1 (try_award_floor_clear)**, **A2 / E2 (LOSING drip routing)**, **A3 / E3 (BASE_KILL[1] reconciliation)**, **A4 / E4 (kill_bonus vs attribute_kill_gold)**, **A5 / E8 (C.2.4 33% claim)**. All five Cluster A BLOCKERs closed.

### BLOCKERs remaining after Pass 4B-Economy

- **Cluster B** (6 items, Pass 4B-SaveLoad): RunSnapshot Save/Load wiring, `Array[KillEvent]`/`Array[HeroInstance]` per-element to_dict/from_dict, `var floor: Floor` serialization path, `floor.id` null guard, `Floor.id` type unspecified, `is_equal_approx` on `hp_bonus_factor` 0.5 boundary.
- **Cluster F** (1 item, Pass 4C): EventBus autoload decision.
- **G1 reframe** (Pass 4C): enumerate option (c) deferred reassignment + separate read/write signals.
- **Q2/Q4/Q5/Q8** (Pass 4C): test-plan polish items.
- **AC-ORC-03/05 rewrite** (Pass 4D, unblocked by Combat Pass 3D earlier same day).

### Pass 3B Open Question — drip curve holistic rebalance (from Combat Pass 3 / Economy D.1)

**Not closed in this pass.** Reduction of `BASE_DRIP[5]` from 20 → 8 was done in Pass 3B (interim fix); full F1–F5 holistic rebalance requires playtest data that doesn't exist yet (the Offline Progression Engine prototype hasn't been built; Combat per-floor cadence is locked but per-floor drip feel is untested). **Flagged to remain open until first playtest of a vertical-slice build containing F1–F5 drip curves + offline progression.** Should be revisited paired with `/playtest-report` once that data exists.

### Files modified this pass

- `design/gdd/economy-system.md` — C.2.3 LOSING_RUN scope narrative (supersedes Pass 2B decision 4); C.2.3a new public method spec; `> **A3 reconciliation**` callout + all BASE_KILL[1] references updated to 10; C.2.4 prose corrected for 2.25× claim; Dependencies table row for Orchestrator refreshed; AC H-14 added with 3 sub-ACs; Classification Summary table updated; header Last Updated note appended.
- `design/gdd/combat-resolution.md` — Rule 9 halving scope narrowed + superseded note + Pass 4B-Economy citation.
- `design/gdd/dungeon-run-orchestrator.md` — E.5 prose corrected ("full-rate drip"); AC-ORC-04 verification clause updated with drip-exclusion note + superseded citation.
- `design/registry/entities.yaml` — no change in this pass (values already matched). `LOSING_RUN_LOOT_FACTOR` notes-field scope update flagged for next `/consistency-check`.
- `design/gdd/reviews/combat-resolution-review-log.md` — Amendment appended: "Pass 2B Locked Decision 4 Superseded by Pass 4B-Economy."
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — Pass 4B-Economy sub-entry appended under 2026-04-20 header (closes Cluster A; defers Cluster B to Pass 4B-SaveLoad).
- `design/gdd/reviews/economy-system-review-log.md` — this file (created).
- `design/gdd/systems-index.md` — row 5 (Economy) bumped to "Pass 4B-Economy Applied — Cluster A resolved"; row 11 (Combat) refreshed for Rule 9 narrowing; row 13 (Orchestrator) refreshed for Cluster A close-out; header Last Updated appended.
- `production/session-state/active.md` — Pass 4B-Economy items ticked; open flags 18–24 refreshed; Last Updated refreshed.

### Next step

**Pass 4B-SaveLoad** — Cluster B (6 BLOCKERs), separate pass, ~2 hours. Requires Save/Load owner alignment; touches Save/Load GDD #3 contract addendum + Orchestrator RunSnapshot wiring. Independent of Pass 4C and Pass 4D — can run in parallel or sequentially.

**OR Pass 4C** (engine conventions + polish, independent, ~2 hours) if Save/Load owner alignment is not immediately available.

**OR Pass 4D** (AC-ORC-03+05 rewrite, unblocked by Combat Pass 3D, ~1 hour).

**OR targeted re-review on Combat Pass 3 9 blockers** (still pending — Pass 3D + Pass 3E flag + Pass 2B decision 4 supersede did not re-open; all three can re-review in parallel).

Sequencing recommendation: any order; all four are now independent. Pass 4B-SaveLoad is the next cross-GDD item and closes the final 6 BLOCKERs before Orchestrator can move from MAJOR REVISION NEEDED to CONCERNS/APPROVED.

---

## Pass 5B — Upstream Reconciliation (2026-04-20)

**Pass type**: Structured sub-pass of Pass 5 (second after Pass 5A). Executes the Economy/Registry/Save-Load reconciliation flagged by the 2026-04-20 independent re-review (Clusters δ + ε) and the Pass 5A ADRs.
**Scope**: Economy GDD rewrite for ADR-0002 reclaim semantic; Economy D.6 upstream drift fixes; Registry `LOSING_RUN_LOOT_FACTOR` notes; Save/Load Rule 11 field-rename addendum.
**Review mode**: solo
**Duration**: ~1.5 hr
**Blocks closed**: 7 of 17 re-review BLOCKERs (Cluster ε's 3 items + partial Cluster δ item 13).

### What changed

**Economy GDD #4** (`design/gdd/economy-system.md`):

1. **C.2.3 Floor-Clear Bonus** — prose rewritten to describe the monotonic `floor_clear_bonus_credited: Dictionary[int, int]` gate, the LOSING first-clear halving + reclaim-on-WIN semantic (per ADR-0002), and the anti-exploit ceiling (total credited ≤ `FLOOR_CLEAR_BONUS[floor_index]`).
2. **C.2.3a Public Method `try_award_floor_clear`** — full rewrite against ADR-0002 credit-the-gap behaviour. Eight-step behaviour spec (range guard, negative-bonus guard, ceiling lookup, `bonus_amount <= already_credited` gate, delta credit, ceiling advance, conditional `first_clear_awarded` emission on `already_credited == 0` only, return). Six-row semantic-consequences table embedded verbatim from ADR-0002 §Decision. Migration note + return contract clarified.
3. **AC H-03** — rewritten from boolean gate to monotonic-credit idempotency; two successive 3000g calls return (true, false) and credit 3000 + 0.
4. **AC H-11** — Save round-trip fixture changed from `floors_cleared_bonus_awarded = [true, true, false, false, false]` (Array[bool]) to `floor_clear_bonus_credited = {1: 500, 2: 1200, 3: 1500}` (Dictionary[int, int], with F3 representing a pending LOSING first-clear reclaim). Post-load reclaim assertion added (subsequent `try_award_floor_clear(3, 3000)` credits delta 1500).
5. **AC H-14** — expanded from 1 primary + 2 sub-ACs to 1 primary + 5 sub-ACs: **14-losing-first-then-win-reclaim** (new — the "no fail state" reclaim path; signal fires once on first LOSING credit, not re-fired on WIN delta credit); **14-win-then-losing-no-reclaim** (new — inverse-order anti-exploit check); **14-boundary** (retained); **14-negative-bonus** (retained); **14-zero-bonus** (new — promoted from RECOMMENDED, degenerate `LOSING_RUN_LOOT_FACTOR = 0.0` case).
6. **D.6 pacing table** — F5 drip row corrected: `24,000 gold/min → 9,600 gold/min` (pre-Pass-3B stale value; `BASE_DRIP[5] = 8 × 20 ticks/sec × 60 sec = 9,600` at factor 1.0). Tier-2 recruit cost row corrected: `2,500 → 8,000 gold` (matches C.2 calibration note already at 8,000). "Adjust if too fast" footnote removed — 8,000 is the locked value.
7. **D.6 Calibration flag** — rewritten as **Calibration — Tier-2 recruit cost (locked)**: 8,000g locked; 2,500 figure flagged as deprecated commentary; safe range 2,500–20,000 retained for post-launch tuning.
8. **C.4 States table + C.8 Dependencies + Open Questions consumer list** — three `save_to_dict` key lists updated from `floors_cleared_bonus_awarded` to `floor_clear_bonus_credited` with ADR-0002 citation.
9. **Header Last-Updated line** — Pass 5B summary prepended to the existing Pass 4B-Economy summary.

**Registry** (`design/registry/entities.yaml`):

10. `LOSING_RUN_LOOT_FACTOR` — `notes` rewritten: removed "drip + kill bonuses + clear bonus" scope (Pass 4B-Economy A2 supersession now reflected in the notes); added Pass 5A / ADR-0002 reclaim semantic summary; safe range lower bound tightened `0.0 → 0.5` per re-review Cluster δ item 13 (at 0.0 the halved floor-clear bonus collapses the output range); `referenced_by` extended to include `economy-system.md` + `ADR-0002`; `revised` date set.

**Save/Load GDD #3** (`design/gdd/save-load-system.md`):

11. Rule 11 — new addendum paragraph **"Non-RefCounted dictionary fields (field-rename note — Pass 5B)"** noting Economy's field rename/re-type (`Array[bool] → Dictionary[int, int]`); clarifies Rule 11's per-element `to_dict()`/`from_dict()` pattern does NOT apply (plain JSON-native dict); Rule 13's float epsilon does NOT apply (int equality); no migration path required (pre-MVP).

### Files modified

- `design/gdd/economy-system.md` — header + C.2.3 + C.2.3a + AC H-03 + AC H-11 + AC H-14 + D.6 pacing table + D.6 calibration note + C.4 Save/Load row + C.8 Save/Load dependency row + Open Questions consumer-list entry.
- `design/registry/entities.yaml` — `LOSING_RUN_LOOT_FACTOR` notes + referenced_by + revised date.
- `design/gdd/save-load-system.md` — Rule 11 field-rename addendum paragraph.
- `design/gdd/reviews/economy-system-review-log.md` — THIS entry.
- `design/gdd/reviews/save-load-system-review-log.md` — Pass 5B sub-entry (separate file, appended this pass).
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — Pass 5B completion note appended under the Pass 5A entry.

### Not in scope (deferred to Pass 5C / 5D)

- Cluster α (Node autoload wiring + MatchupResolver DI) — Pass 5C.
- Cluster β (AC-ORC-07/13 NO_RUN vs RUN_ENDED; Sub-AC 03 vs C.3 `<` guard) — Pass 5D.
- Cluster γ (6 AC verification-gap items) — Pass 5D (plus Pass 5B on Combat GDD oracle API additions if Combat Pass 3E/3F ships first).
- Remaining Cluster δ items (matchup_cache KeyError, `OfflineRunResult.new(kw=...)` GDScript, full `LOSING_RUN_LOOT_FACTOR=0.0` clamp — note: safe-range tightening landed here, but the formula-level guard in `try_award_floor_clear` Sub-AC 14-zero-bonus is the complementary protection) — Pass 5C / 5D split.
- Pass 3B drip-curve holistic rebalance — still playtest-blocked (tuning, not contract).

### Next step

**Pass 5C — Orchestrator Production Wiring Spec** (~3 hrs). Authoring: Orchestrator §J "Production Wiring" covering Node autoload lifecycle + DI injection path (setter-based vs bootstrap-scene); `_ready()` default construction contract; `error_logger: Callable` policy; MatchupResolver conversion to injectable instance class (`class_name MatchupResolver extends RefCounted` + `DefaultMatchupResolver`, mirroring CombatResolver Pass 3D pattern).

After Pass 5C: Pass 5D (AC Triangulation Sweep, ~2 hrs) → Pass 5E (gate re-run). Full arc estimate ~5 hrs remaining.

### Editorial framing

Pass 5B is the "boring but necessary" arithmetic-and-citation pass. Nothing here changes the game; everything here keeps the game's authoritative documents internally consistent. The F5 drip correction (24,000 → 9,600 g/min) is the single biggest numerical change — a 60% reduction — but it was latent across multiple documents before this pass; Pass 5B makes it visible and citable in one place. The ADR-0002 Economy rewrite is the largest text surface-area change; the engine-level shape is simple (one Dictionary field, one max() comparison) but the documentation surface touches six sections of Economy GDD and one of Save/Load GDD. Pass 5B closes 7 of 17 re-review BLOCKERs with zero new design decisions — consistent with a "reconciliation" sub-pass.
