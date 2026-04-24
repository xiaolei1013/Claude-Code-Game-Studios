# Combat Resolution System — Review Log

GDD: `design/gdd/combat-resolution.md` (#11 in design order)

---

## Review — 2026-04-19 — Verdict: MAJOR REVISION NEEDED

**Scope signal**: L (if pillar issues deferred) → XL (if pillar issues fully addressed)
**Specialists**: game-designer, systems-designer, qa-lead, economy-designer, godot-gdscript-specialist, creative-director (synthesis)
**Review mode**: solo (CD-GDD-ALIGN gate skipped)
**Blocking items**: 14 (deduplicated across specialists; raw count 23 before dedup)
**Recommended items**: ~12
**Prior verdict resolved**: First review

### Summary

Structurally excellent GDD (8 sections present, registry hygiene strong, 18 ACs explicit) with three compounding categories of content problems:

1. **Arithmetic poisoning in D.7** — F1 actual DPS is 0.266 vs claimed 0.258; F4 actual is 1.14 vs claimed 1.217; D.2/D.4 "practical MVP range" upper bound 4.25 doesn't exist. Game-designer's downstream pillar analysis cites these wrong numbers, so some pillar verdicts may shift after recompute.
2. **Engine type contracts undefined** — `CombatResolver` lacks `extends RefCounted`; `CombatTickEvents` / `CombatBatchResult` / `KillEvent` / `CombatRunSnapshot` value types never typed. AC-COMBAT-01's "field-equal" test cannot be implemented without explicit `equals()` methods. The deterministic pillar (project's #1 promise) cannot be tested as designed. `ceil()` vs `ceili()` distinction missing.
3. **Pillar 2/3 fantasy disconnects** — Warrior HP is mechanically vacuous (soft survivability check almost never fires; SURVIVAL_MARGIN cannot produce a meaningful soft cliff at any value in safe range; three specialists independently flagged). Pillar 3 inaudible in foreground (Combat doesn't call MatchupResolver in MVP, so tempo doesn't vary with formation matchup, contradicting Section B's "tempo IS the receipt" claim).

### Blocking Items (14, deduplicated)

1. Warrior HP / Pillar 2 vacuous — formula structurally cannot fire at F4 multi-hero or F5 any-formation [game-designer + economy-designer ×2]
2. Pillar 3 inaudible in MVP — tempo doesn't vary with matchup [game-designer ×2]
3. D.7 calibration table arithmetically wrong — recompute every row from `stat_at_level` [systems-designer ×2]
4. Rule 3 says SPEED_BASE = 800; everywhere else 2400 [systems-designer]
5. Engine type contracts unspecified — RefCounted + equals() methods needed [godot-gdscript ×3]
6. D-section header "integer arithmetic" misleads; `ceil()` vs `ceili()` [godot-gdscript]
7. Stateless logging contradiction (push_error "once per dispatch" impossible) [godot-gdscript + qa-lead]
8. AC-COMBAT-02 "lossless integer assertion" fails in IEEE 754 [systems-designer + godot-gdscript]
9. D.6 `formation_total_hp` lower bound 175 conflicts with registry 55; upper bound 735 wrong (3× L15 Warrior = 1074) [systems-designer]
10. AC-07 + AC-09 require Orchestrator (#13 undesigned); split into Combat-side + DEFERRED-Orchestrator-side [qa-lead ×2]
11. AC-COMBAT-14 references non-existent `tests/performance/BASELINES.md` [qa-lead]
12. AC-15 + D.1 `speed=0` division-by-zero (max() guard fires after divide) [qa-lead + systems-designer]
13. F5 boss HP 2200→4900 cascade incomplete (8 references, 6 documents); F4→F5 ratio breaks ×1.08 → ×2.40 [economy-designer]
14. Combat Rule 7 ("once per dispatch") contradicts Economy C.2.3 ("once per lifetime") — Orchestrator carries undocumented idempotency burden [economy-designer]

### Specialist Disagreements

1. **D.7 numerical accuracy** — systems-designer correct; game-designer's pillar analysis built on wrong numbers and needs re-derivation after recompute.
2. **F1 overnight gold (1.18–1.38M)** — economy-designer correctly scoped this as a pre-existing Economy GDD problem that Combat surfaces, NOT a Combat defect. Flag for Economy revision before Combat ships, or Combat will be wrongly blamed at QA.
3. **Closed-form vs discrete drift (BLOCKING-SD-2)** — systems-designer's nuance (implementation can stay; rationale is false) was missed by other specialists. Editorial fix, not architectural.

No disagreements on Warrior HP, type contracts, or AC-14.

### Senior Verdict (creative-director)

> "23 BLOCKING findings across 5 specialists, with three compounding categories. The structure of the GDD is excellent (8-section discipline, registry hygiene, explicit acceptance criteria), but the content has too many compounding errors to land in one revision. Three specialists independently flag Warrior survivability — that level of convergence on a class identity issue is a vision problem, not a tuning problem."

**Recommended revision shape: two passes**

- **Pass 1 (mechanical, ~days)**: Fix items 3, 4, 5, 6, 8, 9, 10, 11, 12 — recompute D.7 from stat_at_level, fix Rule 3 SPEED_BASE narrative, type-spec all value types as RefCounted with `equals()`, replace `ceil()` with `ceili()`, split AC-07/09, create BASELINES.md (or remove AC-14), add D.1 `if speed <= 0: return 1` pre-clause, fix AC-02 lossless assertion. Unblocks ~9 of 14 BLOCKING items.
- **Pass 2 (design judgment, requires decision)**: Fix items 1, 2, 13, 14 — decide Warrior HP fate (replace formula vs raise SURVIVAL_MARGIN above safe range vs explicitly defer to V1.0 Cleric and rewrite Section B + G.1); decide Pillar 3 audibility (rewrite Section B foreground fantasy honestly OR allow matchup to affect kill cadence); execute F5 HP cascade across 6 documents OR adopt per-floor difficulty modifier at Orchestrator layer; reconcile Combat Rule 7 with Economy C.2.3.

**Do not let the two passes merge into one revision.** Pass 1 is mechanical; Pass 2 needs design judgment that cascades into Section B/F/G rewrites and may need additional specialist consultation.

### User decision (2026-04-19)

Stop here, revise in fresh session. Run `/clear` then start a fresh `/design-system` or `/quick-design` pass. With 14 BLOCKING items and recommended two-pass structure, fresh context is safer than revising in this 60%+ used session. This review log + the systems-index NEEDS REVISION marker are sufficient handoff artifacts.

### Cascade items flagged for other GDDs (action by next session)

- **Economy GDD #4 D.6** — placeholder "1 kill / 10 sec" now factually wrong (Combat D.7 supersedes); cascade impact ~1% (drip dominates) but doc must update.
- **Economy GDD #4 D.6** — F1 overnight 1.18–1.38M gold vs ~80K Day-1 cumulative target (14–17× over) is a pre-existing Economy bug that Combat surfaces. Tier-2 milestone reachable Day 2 morning, not Day 3-4. Needs Economy revision pass independent of Combat fixes.
- **Biome DB #7** — F3 expected_clear_time revision (60 → 85s) and F5 boss HP question must close together with the still-open clear-bonus retrigger policy; closing separately produces inconsistent offline math.
- **Enemy DB #6** — `ancient_rootking.base_hp` change pending F5 calibration decision (Combat I.2 + Biome DB Open Q).
- **entities.yaml registry** — `referenced_by` arrays incomplete for `ancient_rootking` (missing biome-dungeon-database.md and combat-resolution.md); add before any HP edit so future cascades are traceable.
- **Hero Class DB #5** — Open Q4 (speed semantics) is locked by Combat Rule 3 to "cooldown divisor"; Class DB Open Q4 should close after Combat revision lands.

---

## Review — 2026-04-19 (Pass 1 Re-Review) — Verdict: MAJOR REVISION NEEDED

**Scope signal**: L → XL (Pillar 3 routing decision upgrades scope)
**Specialists**: game-designer, systems-designer, economy-designer, qa-lead, godot-gdscript-specialist, creative-director (synthesis)
**Review mode**: solo
**Blocking items**: 15 (deduplicated; 4 Pass 1 regressions + 3 Pass 1 omissions + 4 live Pass 2 design-judgment items + 2 QA AC FAILs + 1 contract gap; Pass 2 item #4 Rule 7 ↔ Economy C.2.3 DOWNGRADED to NICE per economy-designer re-verdict)
**Recommended items**: ~13
**Prior verdict resolved**: Partial — 9 of 14 prior BLOCKING addressed by Pass 1; remaining 5 confirmed; 7 NEW BLOCKING introduced by Pass 1

### Summary

Pass 1 cleared 9 of 14 prior items mechanically. Two compounding new categories of problems:

1. **C.4 Type Contracts regressions (godot-gdscript ×4 BLOCKING)** — `CombatResolver extends RefCounted` is wrong base for static class; `@export var` on transient per-call value types is wrong serialization signal; **`Dictionary.hash()` equality is unsound — can silently pass determinism tests on non-deterministic results, breaking Pillar 1 testability**; `CombatRunSnapshot.equals()` "omitted for brevity" hides a float-equality hazard.
2. **Pass 1 omissions in registry/appendix (systems-designer ×3 BLOCKING)** — entities.yaml expressions still use `ceil`/`floor`/`max`; `ancient_rootking.referenced_by` missing cross-refs; appendix line 872 still has stale `[0.0, ~5.0]` output range.
3. **Pillar 2/3 fantasy disconnects unchanged** (game-designer × confirmed) — Warrior HP still vacuous at default margin (5 of 5 floors); Section B's "tempo IS the receipt" claim still false (matchup is gold-only, tempo identical regardless of composition).

### Disagreement RESOLVED — Pass 2 item #4 (Rule 7 ↔ Economy C.2.3)

**economy-designer re-verdict: RESOLVED — no design gap.** The three-layer split (Combat signals first-clear-in-range → Orchestrator guards per-dispatch → Economy guards per-lifetime via H-03) is coherent. Economy H-03 explicitly handles duplicate-signal dedup. Remaining piece is a UI-fanfare doc note belonging in Orchestrator GDD #13, not Combat. **Creative-director endorses.** Pass 2 list shrinks from 5 to 4 items.

### User decisions locked (4 design-judgment Qs, 2026-04-19)

1. **Pillar 3** → Option A: Route matchup into `ticks_per_loop` (matched formations literally clear faster). Cascades into Resolver C.3 (V1.0-reserved → MVP consumer). Scope upgrades to XL.
2. **Pillar 2 / Warrior HP** → Option B: Replace boolean survival check with continuous HP-efficiency → kill cadence (or gold) bonus. `hp_bonus_factor = mini(formation_total_hp / HP_THRESHOLD, 1.0)`.
3. **F5 boss** → Raise HP to 4818 (precise: 170×20×1.417 = 4817.8 → ceili = 4818). Biome F5 target stays 170s. 6-doc cascade.
4. **LOSING_RUN_LOOT_FACTOR scope** → Halve everything including first-clear bonus on losing first-clear. Rule 9 "all gold" stays literal.

### Pass 2A applied THIS session (mechanical, ~10 edits)

1. C.4 `CombatResolver` — bare `class_name`, removed `extends RefCounted`; documented compile-time `class_name` registration correctly.
2. C.4 all four value types — `@export var` → `var`; documented why (transient, never serialized).
3. C.4 `CombatBatchResult.equals()` — replaced unsound `Dictionary.hash()` with explicit `_dict_equals()` key-walk helper. **Pillar 1 testability restored.**
4. C.4 `CombatRunSnapshot.equals()` — written in full; float field uses `is_equal_approx`; deep-walks `kill_schedule` array.
5. C.4 typed `Dictionary[StringName, int]` / `Dictionary[int, int]`; comment added on typed-array element-wise `!=`.
6. C.4 contract summary — fully rewritten to reflect new patterns.
7. AC-COMBAT-04 — rewritten to use lossless integer reference path `ceili(216 × 2400 / 496)` instead of literal float `0.20667`.
8. AC-COMBAT-11 — pre-condition block added (GdUnit4 push_error API uncertainty promoted from session-state to GDD body, with three resolution options).
9. AC-COMBAT-01 — verification step rewritten to call `equals()` as primary BLOCKING gate + key-walk for dictionaries.
10. AC-COMBAT-09a — duplicate determinism sentence removed; type/value assertions strengthened.
11. Rule 7 — formal Orchestrator invariant added (normative "MUST emit / MUST NOT emit again" breadcrumb for #13).
12. Appendix line 872 — `formation_dps_per_tick output [0.0, ~5.0]` → `[0.0, 2.31]` with rationale.
13. Registry `entities.yaml` — `ticks_per_loop.expression` ceil → ceili; `action_cooldown_ticks.expression` max/floor → maxi/floori with explicit pre-guard documentation; `ancient_rootking.referenced_by` extended to include biome-dungeon-database.md + combat-resolution.md.

### Pass 2B remaining (DEFERRED to fresh session — XL scope)

The following require cross-file design rewrites under context budget Pass 2A could not safely take on:

1. **Pillar 3 routing into ticks_per_loop** — Combat Section A/B/C.3/Rule 4-5/D.2-D.7/AC-02-05 + Resolver GDD C.3 (V1.0-reserved → MVP consumer) + entities.yaml `formation_dps_per_tick` expression + new tuning knobs `MATCHUP_THROUGHPUT_FACTOR_*` + AC for matchup-throughput parity. Section B "tempo IS the receipt" claim becomes TRUE under this change.
2. **Pillar 2 HP-efficiency formula** — D.6 replacement, Section B Warrior identity rewrite, G.1 SURVIVAL_MARGIN re-analysis (likely deprecated, replaced by HP_THRESHOLD), Cleric V1.0 hook re-routed.
3. **F5 cascade** — Combat D.4/D.6/D.7 tables recomputed under HP=4818; Enemy DB ancient_rootking.base_hp 2200 → 4818; Biome DB F5 Open Q closed; entities.yaml `floor_total_hp` upper bound recomputed; Economy D.6 re-validation (Day 3-4 milestone rescaling).
4. **LOSING_RUN_LOOT_FACTOR scope clarification** — Rule 9 explicit "drip + per-kill + first-clear all halved"; Economy C.2.3 mention.
5. **F3 expected_clear_time revision** — Biome DB 60 → 85s (Combat D.7 calibration item 1).
6. **Section B "brisk tempo" honesty** — depends on Pillar 3 Option A landing first; once Pillar 3 routes through ticks_per_loop, the tempo-varies-with-matchup fantasy claim becomes accurate.
7. **E.3 contract gap** (creative-director soften to RECOMMENDED): one-sentence breadcrumb in Section I about Orchestrator's negative obligation; defer `floor_was_valid: bool` addition unless Orchestrator GDD #13 author requests it.

### Senior Verdict (creative-director synthesis)

Pass 1 made real progress (9/14 priors cleared); Pass 2A in this session made another 10 mechanical fixes including the **critical Pillar 1 testability restoration** (Dictionary.hash → key-walk). But Pass 2B remains: the four creative decisions (Pillar 3, Pillar 2, F5, LOSING_RUN scope) are locked but their cross-doc execution is XL-scope and was correctly deferred to a fresh-context session. **Verdict remains MAJOR REVISION NEEDED** until Pass 2B lands; re-review after Pass 2B.

### Cascade items remaining for Pass 2B and beyond

Same as prior review log entry (Economy D.6 re-validation, Biome F3/F5, Enemy DB ancient_rootking.base_hp, entities.yaml floor_total_hp upper bound, Class DB Open Q4 closure). Plus newly added: Resolver GDD C.3 needs update from "V1.0 reserved consumer" → "MVP consumer (dispatch-time matchup_throughput_factor read)" once Pillar 3 routing lands.

---

## Review — 2026-04-20 — Pass 2B Applied — Verdict: ALL LOCKED DECISIONS EXECUTED, AWAITING RE-REVIEW

**Scope signal**: XL (7 cross-doc items, ~55 edits, 5 files touched)
**Specialists**: none spawned this pass (execution session, not review session)
**Review mode**: solo
**Blocking items resolved this pass**: all 7 Pass 2B items
**Prior verdict resolved**: Yes — Pass 2B now complete; triggers re-review under full mode before APPROVED verdict

### User decisions locked before execution (2 new clarifications this session)

8. **Pillar 3 matchup factors**: `MATCHUP_THROUGHPUT_FACTOR_ADV = 1.5`, `MATCHUP_THROUGHPUT_FACTOR_DIS = 1.0` (asymmetric — advantaged boost, disadvantaged baseline, never punish). Mirrors `MATCHUP_GOLD_MULTIPLIER` default.
9. **Pillar 3 matchup grain**: per-enemy inside `_kill_schedule_for_loop` (not per-floor). Faithful to Resolver's per-kill majority semantic; required restructure of Rule 10 / D.5 into per-enemy accumulator.
10. **Pillar 2 application point**: throughput multiplier (affects `ticks_per_loop` via effective_dps, NOT loot multiplier). Cleanly couples with Pillar 3 routing — both factors multiply raw_dps at the same call site.
11. **LOSING_RUN vs hp_bonus_factor relationship**: continuous hp_bonus_factor applies always (throughput); LOSING_RUN_LOOT_FACTOR additionally triggers when `hp_bonus_factor < 0.5` (halves ALL run gold including first-clear bonus). Double-signal but MVP-inert on naturally constructable formations.
12. **HP_THRESHOLD calibration**: uses per-floor `floor_total_enemy_attack` (already in Combat D.6) — no new tunable knob. MVP economy-neutral; Warrior payoff shifts to V1.0 hard content.

### Pass 2B execution summary

1. **Pillar 3 routing** (24 edits, 3 files) — Combat A/B-preamble/C.3/Rule 4/Rule 8/Rule 10/D.4/D.5/D.7/F/G.1/AC-04/AC-05/AC-08/AC-17/I.Q1/I.Q2 + Resolver GDD #10 C.3 + F.2 (V1.0-reserved → MVP consumer) + entities.yaml (2 new constants, formation_dps_per_tick notes, ticks_per_loop expression). **AC numerics shifted**: per-enemy integer ceiling replaces cumulative ceiling → AC-04 expected value 1046 → 1047, AC-05 schedule (128,255,383,530) → (128,256,384,532), AC-08 ticks_per_loop 153 → 154 and loops 3764 → 3740, AC-17 loops 392 → 389. Economy delta <1%.
2. **Pillar 2 hp_bonus_factor** (14 edits, 2 files) — Combat Rule 9 / Rule 10 / Rule 4 / C.4 / D.4 / D.6 / E.1 / E.3 / E.8 / AC-06 / AC-07a / G.1 / I.Q5 + entities.yaml (SURVIVAL_MARGIN → deprecated, `survived` formula rewritten, new `hp_bonus_factor` formula). AC-06 rewrite: synthetic fixture for boundary (formation_total_hp=60 vs floor_total_enemy_attack=120 → exact 0.5). AC-07a: two-fixture rewrite (MVP non-LOSING + synthetic LOSING).
3. **F5 HP 2200 → 4818** (12 edits, 5 files) — Combat D.4 upper bound / D.7 F5 row / I.Q2 CLOSED + Enemy DB (6 locations across C.2/C.3/D.2/D.3/G.1/G.2/G.3/I) + Biome DB (F5 validate row, registry consistency, D.1 growth ratios) + Economy D.6 revalidation note + entities.yaml (floor_total_hp upper bound 2200 → 4818, ancient_rootking.base_hp unset PROVISIONAL → 4818 final).
4. **LOSING scope clarification** (2 edits) — Combat Rule 9 explicit "first-clear NOT exempt" + Economy C.2.3 explicit LOSING_RUN handoff contract.
5. **F3 60s → 85s** (4 edits, 1 file) — Biome DB F3 enemy_list expected_clear_time, F3 rationale, C.7 F3 validate row, G.2 per-floor table, I Open Q F3 CLOSED.
6. **Section B brisk-tempo honesty** (2 edits, 1 file) — Combat Section B paragraph 1 rewrite (W+M+W at L13 F4 with Pillar 3 audibility made explicit) + paragraph 2 language discipline ("brisk" reserved for F1 onboarding, "measured/tight" for deeper floors).
7. **E.3 RECOMMENDED soften** (1 edit) — Combat Section I Q11 added: `floor_was_valid: bool` field deferred to Orchestrator GDD #13 judgment (RECOMMENDED not BLOCKING).
8. **Systems-index + review log + session state** (3 edits) — systems-index status updated to Pass 2B Applied, this review log entry appended, production/session-state/active.md refreshed (pending).

**Total edits**: ~58 across `design/gdd/combat-resolution.md`, `design/gdd/class-vs-enemy-matchup-resolver.md`, `design/gdd/enemy-database.md`, `design/gdd/biome-dungeon-database.md`, `design/gdd/economy-system.md`, `design/registry/entities.yaml`, `design/gdd/systems-index.md`, `design/gdd/reviews/combat-resolution-review-log.md`.

### Next step

Run `/design-review design/gdd/combat-resolution.md --depth full` in a fresh session. Expected verdict path: the 15 BLOCKING items from the 2026-04-19 re-review should all be resolvable under Pass 2B. Remaining open flags carried forward: Open Flags 1-7 from session-state (MATCHUP_GOLD_MULTIPLIER playtest recalibration, Tier-2 8,000g playtest, GdUnit4 push_error API, F5 boss archetype tension, F1 Rogue-counter deferral, F1 overnight gold, Day 3-4 milestone under F3's 85s cadence). These are all playtest-pending, not implementation-blocking.

---

## Review — 2026-04-20 — Pass 2B Re-Review — Verdict: NEEDS REVISION

**Scope signal**: M (surgical Pass 3 — 9 blockers, most CSS/text-edit-sized, plus one design decision on F5 economy)
**Specialists**: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, economy-designer, creative-director (synthesis)
**Review mode**: solo
**Blocking items**: 9 (post-dedup) | **Recommended**: 17 | **Nice-to-have**: 6
**Prior verdict resolved**: Yes — all 15 BLOCKING from 2026-04-19 Pass 1 re-review correctly addressed by Pass 2B. New BLOCKING items are (mostly) Pass-2B-introduced regressions + one material design gap (F5 economy slope) + one AC pre-condition that was known-open from Pass 2A.

### Summary

Pass 2B did its stated job on the 15 prior BLOCKERs. What's left is a small, tight set of regressions plus one real design gap — exactly the shape a large cross-doc edit produces. Cross-model convergence (game-designer + systems-designer independently flagging Rule 4; game + economy independently flagging Pillar 2 MVP invisibility; systems-designer + economy-designer independently flagging Pass 2B cascade-misses across appendix/G.2/Biome DB F5 rationale) is the strongest signal and points at real issues. The document is sound — it has drifted from its own state.

### Blocking items (9, creative-director-synthesized and deduplicated)

1. **[cross-model G1 + S1]** Rule 4 per-hero divisor narrative uses stale `SPEED_BASE=800` (`62×24/800 = 1.86` etc.) contradicting default 2400 (correct values: 0.62, 0.77, 0.33). Poisons Pillar 2 identity teaching text.
2. **[systems-designer S2 + S3; economy-designer E10; game-designer G7 as NICE but creative-director promoted to BLOCKING]** Pass 2B cascade-miss cluster — treat as one fix:
   - Appendix (lines 1051–1072) still lists `SURVIVAL_MARGIN = 0.2` as a live constant + stale `survived` formula variables.
   - G.2 calibration table F5 row shows 78s (pre-cascade HP=2200); must read 170s at HP=4818.
   - Biome DB C.2 F5 rationale still reads "Total HP = 2200" and uses deprecated round-model.
3. **[game-designer G3; systems-designer S4 as RECOMMENDED; creative-director adjudicated BLOCKING]** D.5 worked-example pseudocode silently drops `hp_bonus_factor` from `effective_dps` (shows `dps × factor`, not `dps × factor × hp_factor`). Rule 10 block correct; D.5 example-text wrong. Implementers read worked examples as reference implementations.
4. **[economy-designer E6]** F5 endgame economy slope not revalidated by Pass 2B. F5 drip 24,000g/min × 170s per loop = 67,920g × 169 loops/8h = **~11.5M gold overnight** vs ~147K to max all three Tier-1 heroes (~78×). "10–14 days cumulative play to max" pillar promise is broken at F5 unlock. Pass 2B Chunk 3 revalidation note addressed kill income only; missed drip. *Design decision required — not pure tuning.*
5. **[qa-lead Q1]** AC-COMBAT-11 pre-condition leaves three options (a/b/c) open; AC cannot be sprint-assigned. Fix: commit to option (c) `error_logger: Callable` injection and write the fixture spec concretely.
6. **[godot-gdscript-specialist GD1]** C.4 `CombatResolver` "bare `class_name` with no `extends`" rationale is factually wrong — GDScript implicitly inherits RefCounted; `new()` silently succeeds. Fix: promote `@abstract class_name CombatResolver extends Object` (Godot 4.5+, confirmed in 4.6) from "optional stronger enforcement" to the default pattern.
7. **[godot-gdscript-specialist GD2]** `_dict_equals` underscore convention (private-by-convention) contradicts AC-01/10 requirement to call it externally. Fix: rename to `dict_equals` (public) OR explicitly document "test-public despite underscore".
8. **[game-designer G6 + economy-designer E4, independent convergence]** Pillar 2 MVP invisibility undisclosed. Header declares "Implements Pillar 1+3" (Pillar 2 omitted) but Section B claims Warrior HP contributes to tempo. `hp_bonus_factor = 1.0` saturates for every naturally-constructable 3-hero formation on every MVP floor. LOSING_RUN provably unreachable (min natural ratio 55/96 = 0.573 on F4). Fix: pick one path — (a) state Pillar 2 HP dimension is V1.0 commitment and rewrite Section B accordingly, OR (b) add `HP_THRESHOLD[floor_index]` vector so the continuous factor varies in the 0.7–1.0 band on F3/F4.
9. **[game-designer G2]** Section B "~22s vs ~33s" pop cadence on F4 is not derivable from D.7 table (actual L13 W+M+W advantaged ≈ 21.5s; L13 W+M+R neutral ≈ 24s; no pairing produces 33s). Section B "ticks_per_loop drops from ~1800 to ~1200" uses L11 numbers in an L13-framed paragraph. Fix: recompute cadence values from D.7 or commit to a consistent L11 frame.

### Specialist disagreements (adjudicated by creative-director)

1. **D.5 `hp_bonus_factor` omission severity** — game-designer BLOCKING, systems-designer RECOMMENDED. Resolved BLOCKING: implementers use worked examples as reference implementations.
2. **G.2 F5 row severity** — game-designer NICE, systems-designer BLOCKING. Resolved BLOCKING: a calibration table that lies about current values misleads every future balance pass.
3. **No disagreement** on Rule 4 (cross-model agreement), F5 economy slope, Pillar 2 invisibility, or AC-11 pre-condition.

### Recommended revisions (17, source-tagged)

- `[S9]` HP=4818 vs D.7 ticks=3401 one-tick internal inconsistency (HP=4817 matches 3401).
- `[S12]` D.6 formula block missing explicit `floor_total_enemy_attack=0` pre-guard (only in E.3).
- `[Q2]` AC-14 "single performance core" spec unenforceable; `BASELINES.md` absent.
- `[Q5]` AC-05 advantaged branch needs explicit GDScript code block for integer-lifted 1.5× path.
- `[Q7]` AC-01 `_dict_equals` call form undocumented.
- `[Q8]` "Update in lockstep" Biome DB drift warning missing on AC-08/10/17.
- `[Q9]` Fixture naming collision: `test_floor_synthetic` (AC-06) vs `test_floor_high_attack` (AC-07a) — standardize.
- `[Q10]` AC-04 cross-module MatchupResolver import path should be stated.
- `[Q11]` `thorn_guardian` stats in AC-16 not revision-locked.
- `[GD3]` C.4 `is_equal_approx` comment conflates two fields' justifications.
- `[GD4]` "32-bit hash" claim factually incorrect for Godot 4.6 (64-bit).
- `[GD5]` Typed dict "type-checks at assignment" needs runtime-trap caveat.
- `[G4]` Section B "1800 → 1200" uses L11 numbers in L13-framed paragraph.
- `[G5]` Pillar 3 full per-enemy expression exists only on F3 (mid-unlock floor).
- `[E1]` F1 overnight gold bug (Open Flag #6) has no entry in Economy GDD — homeless.
- `[E3]` `MATCHUP_GOLD_MULTIPLIER × MATCHUP_THROUGHPUT_FACTOR_ADV` double-dip reaches 1.26× gold/s for 3×Warrior on F4; entities.yaml rationale understates single-archetype-floor compounding.
- `[E5]` Economy C.2.3 + Combat Rule 9 don't cover "LOSING re-run after full-value first-clear already awarded" — Orchestrator author risk.
- `[E8]` Economy D.6 "revalidation" is a deferral note with broken I.2 cross-reference.

### Nice-to-have (6)

- `[Q6]` AC-06 `0.4917` literal → `59.0/120.0` reference.
- `[Q12]` Pass 2B migration notes in AC bodies should move to appendix.
- `[S16]` E.9 edge-case example still uses HP=2200.
- `[GD6]` `equals()` pattern not documented as project-wide convention.
- `[GD7]` D.1 guard comment incomplete on negative speed.
- `[G8]` "Vindicated foresight" emotional payoff structurally inaccessible in offline-dominant session shape (Return-to-App shows counts, not cadence deltas).

### Senior Verdict (creative-director synthesis)

> "This is the third review of a GDD that has already absorbed two substantial revision passes. Pass 2B did its job on the 15 prior BLOCKERs. What's left is a small, tight set of regressions plus one real design gap — exactly the shape you'd expect from a large cross-doc edit. The blockers are concentrated, not structural. The design is sound — the document has drifted from its own state. **NEEDS REVISION, not MAJOR REVISION.** One consolidated Pass 3 with a targeted re-review on just the 9 blockers is the right shape."

Recommended revision shape (Pass 3, single session, 3 sub-passes):

- **Pass 3A (mechanical, ~2 hrs)**: Blockers 1, 2, 3, 5, 6, 7, 9 — Rule 4 divisors, cascade-miss cluster, D.5 worked example, AC-11 option (c), C.4 class_name rationale, `_dict_equals` rename, Section B cadence numbers.
- **Pass 3B (design decision + tuning, ~1 hr)**: Blocker 4 — F5 economy slope. Reduce `BASE_DRIP[5]`, rescale Tier-2 cost curve, or cap F5 offline drip. Creative-director recommended: reduce F5 drip rate because "10–14 days" is a pillar promise to the player.
- **Pass 3C (pillar commitment, ~30 min)**: Blocker 8 — pick Pillar 2 path (V1.0 commitment + Section B rewrite OR HP_THRESHOLD vector now) and propagate.

Total Pass 3 estimate: 3–4 hours focused session. Re-review scope: targeted pass on just the 9 blockers, not a full 5-specialist sweep.

### Cascade items for other GDDs (action by next session)

- **Economy GDD #4**: F5 drip slope (Blocker 4) — requires design decision + formula change. E1 (F1 overnight bug entry), E3 (double-dip rationale), E5 (LOSING re-run contract clarification), E8 (D.6 revalidation broken I.2 xref).
- **Biome DB #7**: F5 rationale still says "Total HP = 2200" (part of Blocker 2 cluster).
- **entities.yaml registry**: appendix mismatch is internal to Combat GDD; entities.yaml already correct per Pass 2B.
- **Orchestrator GDD #13** (future): AC-07b + AC-09b + E5 LOSING re-run clarification.

### User decision (2026-04-20)

**Stop here, revise in a separate session (chosen).** Context already at ~70%; fresh session safer than pushing Pass 3 in this session. This review log entry + systems-index NEEDS REVISION marker are sufficient handoff.

---

## Review — 2026-04-20 — Pass 3 Applied — Verdict: ALL 9 BLOCKERS EXECUTED, AWAITING TARGETED RE-REVIEW

**Scope signal**: M (single fresh-context session; ~3 hours; touches 3 files: combat-resolution.md, biome-dungeon-database.md, economy-system.md; ~24 edits)
**Specialists**: none spawned this pass (execution session, not review session — re-review will spawn the targeted set)
**Review mode**: solo
**Blocking items resolved this pass**: all 9 from 2026-04-20 Pass 2B Re-Review
**Prior verdict resolved**: Pending re-review confirmation; Pass 3 expected to flip verdict to APPROVED if no new regressions surface

### Pass 3A — Mechanical (7 blockers)

1. **Rule 4 stale SPEED_BASE=800 divisor** — Per-hero identity examples corrected: Mage L15 `62×24/2400 = 0.62`, Rogue L15 `42×44/2400 = 0.77`, Warrior L15 `40×20/2400 = 0.333` (was `1.86 / 2.31 / 1.0` under stale 800 divisor). Pillar 2 teaching text now matches the default `SPEED_BASE = 2400`. Rogue-highest-DPS-because-of-speed framing preserved (44 vs 24 vs 20 SPD).
2. **Pass 2B cascade-miss cluster (3 docs)** —
   - **Combat appendix (lines 1051-1072)**: `SURVIVAL_MARGIN = 0.2` removed from live Constants list (now flagged as DEPRECATED with save-data forward-compat note); `MATCHUP_THROUGHPUT_FACTOR_ADV/_DIS` constants added; `survived` formula updated to derive from `hp_bonus_factor` (not SURVIVAL_MARGIN); `hp_bonus_factor` formula entry added; `ticks_per_loop` rewritten to reference per-enemy derivation per Pass 2B.
   - **Combat G.2 calibration table**: F5 column header now references HP=4818 (Pass 2B); F5 row at SPEED_BASE=2400 reads **170 s** (was 78 s — pre-cascade HP=2200); other SPEED_BASE rows recomputed at HP=4818 (800→57s, 1600→113s, 3200→227s, 5300→376s); commentary "Best matches Biome targets" updated to reflect F1/F2/F4/F5 ✓ at default 2400 with revised F3 target 85s.
   - **Biome DB C.2 F5 rationale**: "Total HP = 2200" + "~17 rounds × 130 ATK × 10s/round = 170s" deprecated round-model replaced with explicit Pass 2B derivation (`ceili(170 × 20 × 1.417) = 4818`) and cross-reference to Combat D.7 / G.2.
3. **D.5 worked-example pseudocode** — `effective_dps` line now reads `dps × mu_factor × hp_factor` (was missing `hp_factor`); `hp_factor = hp_bonus_factor(formation, floor)` added as a floor-level constant before the loop; explicit comment that worked examples below collapse `hp_factor = 1.0` because all MVP formations saturate the cap (NOT a license to drop the factor from reference implementations).
5. **AC-COMBAT-11 committed to option (c)** — Replaced three-options-open pre-condition block with a concrete dependency-injection contract: `compute_offline_batch` and `emit_events_in_range` accept an optional `error_logger: Callable = Callable()` parameter; production callers omit it (fallback `push_error`); tests inject an in-memory recorder Callable. Stateless invariant preserved (per-call, not stored). C.4 method signatures + contract summary updated. AC body rewritten with four concrete sub-assertions (skipped hero contributes 0 + result fields reflect 2-hero values + recorder captures exactly one matching message + control-mode smoke test). No GdUnit4 stream-capture API dependency.
6. **C.4 `CombatResolver` rationale corrected + promoted** — Promoted `@abstract class_name CombatResolver extends Object` (Godot 4.5+) from "optional stronger enforcement" to **default pattern**. Prose paragraph rewritten to explain that bare `class_name` (the prior Pass 2A pattern) implicitly inherits RefCounted, so `CombatResolver.new()` would silently succeed and produce a heap-allocated do-nothing object — the accidental-instantiation hazard `@abstract` exists to prevent. `extends Object` (not RefCounted) chosen deliberately to avoid per-instance refcount overhead. Contract summary first bullet updated.
7. **`_dict_equals` → `dict_equals` rename** — All 4 occurrences updated (definition + 2 callers in `CombatBatchResult.equals()` + contract summary). Inline comment added explaining the public name choice (AC-COMBAT-01 / AC-COMBAT-10 call it from test code as the determinism gate; underscore prefix would falsely signal "private — do not use externally" and contradict the AC contract).
9. **Section B cadence numbers recomputed** — Old "~22s vs ~33s" + "1800 → 1200" replaced with derivable contrast: L13 W+M+W advantaged on F4 ≈ 22 s/pop (precise 21.55s), L11 W+M+R neutral on F4 ≈ 30 s/pop (precise 29.85s); `ticks_per_loop` drop "~1800 → ~1300" (precise 1791 → 1293). Player journey assumes a level-up (L11→L13) plus a specialization (Rogue→Warrior) between sessions. Full derivation block added immediately below the prose paragraph as an audit anchor against D.7 / D.5 (weighted_sum 2528 / 2736 / DPS 1.0533 / 1.140 / per-thorn ticks_to_kill 431 / 597 / floor totals 1293 / 1791).

### Pass 3B — F5 endgame economy slope (Blocker 4)

`BASE_DRIP[5]` reduced **20 → 8** in Economy GDD #4 D.1 BASE_DRIP table + G.1 knobs row. Pre-Pass-3B F5 overnight drip was ~11.5M gold at `factor = 1.0` (~34M at L13 `factor = 3.0`) — roughly 78× the cumulative cost to max all three Tier-1 heroes (~147K). The "10–14 days to max" pillar promise was broken at F5 unlock. New rate: ~4.6M at factor 1.0 / ~13.8M at L13 — still high but no longer pillar-breaking. **Intentionally breaks the previously-monotonic drip curve** (F1–F5: 2/4/7/12/8 — F5 now LOWER than F4); design intent is that F5's "endgame feel" comes from Tier-3 boss kill bonuses + the 18,000g `FLOOR_CLEAR_BONUS[5]` one-shot, not from sustained drip dominance. **New Economy Open Question added (gates Combat #11 final approval)**: full F1–F5 drip curve revalidation against the pillar promise + Tier-2 cost; likely outcomes are (a) reduce F1–F4 proportionally to restore monotonicity at lower scale, (b) raise Tier-2/level costs, or (c) shorten `offline_cap_seconds` for higher floors. Combat I.Q3 updated to reference both the per-floor pacing revalidation AND the Pass 3B drip rebalance work.

### Pass 3C — Pillar 2 commitment (Blocker 8)

**Path (b) chosen**: Pillar 2 (Warrior HP as identity) committed as **V1.0-deferred + MVP-invisible safety net**. Header pillar disclaimer rewritten to acknowledge the structural-vs-mechanical distinction explicitly: `hp_bonus_factor` formula is *structurally present* but saturates at 1.0 for every constructable MVP formation (lowest natural ratio is solo L1 Rogue on F4 = 0.573, well above the 0.5 LOSING trigger). Rule 9 prose updated to describe the formula as the "engine surface for Pillar 2 hook" rather than "mechanical expression of Pillar 2". D.6 commentary rewritten to make the `1.0` saturation across all MVP fixtures explicit. Section I Open Q5 marked CLOSED with the path (b) lock. Warrior MVP identity framed as "the safety slot whose HP investment pays off in V1.0 hard content" — narrative copy and onboarding (future Hero Roster / UI screens) should frame the L1 Warrior as a deliberate present-day investment for future-content payoff, not a stat that's silently doing nothing.

### Files modified this session (~24 edits across 3 files)

- `design/gdd/combat-resolution.md` — 14 edits: header pillar disclaimer, Section B paragraph 1 + cadence derivation block, Rule 4 divisor examples, Rule 9 hp_bonus_factor framing, D.5 pseudocode + commentary, D.6 commentary, C.4 method signatures + CombatResolver rationale + contract summary, AC-COMBAT-11 rewrite, dict_equals rename ×4, G.2 SPEED_BASE table, Section I Q3 + Q5, appendix Constants/Formulas
- `design/gdd/biome-dungeon-database.md` — 1 edit: F5 rationale rewrite (deprecated round-model → Pass 2B derivation cross-ref)
- `design/gdd/economy-system.md` — 4 edits: D.1 BASE_DRIP table F5 row + Pass 3B rationale block, G.1 BASE_DRIP[5] knobs row, Section I new "drip curve holistic rebalance" Open Question
- `design/gdd/systems-index.md` — 2 edits: Last Updated header, row 11 status flip to "Pass 3 Applied"
- `design/gdd/reviews/combat-resolution-review-log.md` — this entry
- `production/session-state/active.md` — refresh to reflect Pass 3 complete

### Next step

Run **targeted re-review** on `design/gdd/combat-resolution.md`, scoped to the 9 blockers from 2026-04-20 Pass 2B Re-Review (NOT a full 5-specialist sweep). Suggested invocation: `/design-review design/gdd/combat-resolution.md --depth focused --blockers 1,2,3,4,5,6,7,8,9` or single-specialist verification per blocker (Rule 4 → game-designer; cascade-miss + G.2 → systems-designer; AC-11 → qa-lead; C.4 + dict_equals → godot-gdscript-specialist; F5 economy + drip-curve Open Q → economy-designer; Pillar 2 commitment → game-designer + creative-director). Expected verdict: APPROVED if no Pass 3 regressions surface; otherwise small surgical Pass 4. Cascade items remaining for next pass: Economy holistic drip-curve rebalance (the new Open Question gates final Combat approval) and Orchestrator GDD #13 (carries AC-07b, AC-09b, E.5, E3 LOSING re-run).

## Review — 2026-04-20 — Pass 3D Applied — Verdict: DI INTRODUCED, AC-ORC-03+05 NOW WRITEABLE

**Scope**: targeted shape change — convert `CombatResolver` from `@abstract class_name CombatResolver extends Object` (static-only, Pass 3) to injectable instance class `class_name CombatResolver extends RefCounted` with instance methods. Zero behavior changes; all Pass 3 invariants preserved (SPEED_BASE=2400, per-enemy matchup routing, statelessness, `error_logger: Callable` injection, public `dict_equals`). Surfaced by Orchestrator GDD #13 design-review Cluster E (2026-04-20) — GdUnit4 cannot mock static methods on `@abstract` classes, rendering Orchestrator AC-ORC-03 and AC-ORC-05 architecturally unwriteable.

**DI shape chosen — option (a) injectable instance interface**: concrete base class `CombatResolver extends RefCounted` with public instance methods (`emit_events_in_range`, `compute_offline_batch`, plus the public `dict_equals` helper); `DefaultCombatResolver extends CombatResolver` is the sole production implementation (instantiated once at game boot and passed to `DungeonRunOrchestrator._init(combat_resolver)`); tests extend `CombatResolver` directly to create spy/stub subclasses that record call arguments or override return values. Option (b) (abstract protocol + separate default implementation) was considered and rejected — GDScript has no true interface type, so "protocol" is just an abstract base class with one additional layer of indirection over option (a). The `@abstract` annotation is removed from the base class since instantiation is now required for tests; construction-via-`CombatResolver.new()` is still non-idiomatic in production (prefer `DefaultCombatResolver.new()`) but no longer architecturally blocked.

**Statelessness preserved**: `CombatResolver` instances accumulate no per-run state. Every call to `emit_events_in_range` or `compute_offline_batch` is a pure function of its arguments; the instance is a dependency container, not a state container. Injecting the same `CombatResolver` instance across multiple Orchestrator dispatches is safe — there is nothing to reset between runs. Combat Rule 1 is satisfied by construction, as before.

**Files edited**:
- `design/gdd/combat-resolution.md` — class declaration switched to `class_name CombatResolver extends RefCounted`; public methods changed from `static func` to `func`; C.4 rewritten with Pass 3D note + `DefaultCombatResolver` concrete impl section; Dependencies table Combat/Orchestrator row updated to describe injected instance; ACs that previously asserted static dispatch rewritten to assert instance calls on injected spy subclasses; appendix Contracts/Constants/Formulas refreshed to reflect instance shape; prose throughout updated to say "injected `combat_resolver`" rather than "`CombatResolver` static class".
- `design/gdd/dungeon-run-orchestrator.md` — every `CombatResolver.xxx(...)` static reference → `combat_resolver.xxx(...)` instance call (state table C.1 `ACTIVE_FOREGROUND` row, pseudocode blocks in C.3/C.4, Dependencies section row 218, Dependencies narrative row 417); AC-ORC-03 + AC-ORC-05 verification clauses rewritten to describe "spy subclass of `CombatResolver` injected into the Orchestrator at construction; assert the spy recorded calls with expected args"; New Contracts section (row 444) notes Pass 3D DI wiring; prose mentions of `CombatResolver.new()` corrected to `DefaultCombatResolver.new()` in production context. Scope kept strictly to DI-touch points — no edits to Clusters A/B/C/D/F (those remain for Pass 4A/4B/4C).
- `design/registry/entities.yaml` — no change. Registry tracks constants and formulas, not class shapes. No constant or formula entry referenced the old `CombatResolver.static_method` form in its `notes` field (verified via grep). If a future entry is added for the Orchestrator's `combat_resolver` constructor dependency, it can be introduced then.
- `design/gdd/systems-index.md` — row 11 status bumped from "Pass 3 Applied — awaiting targeted re-review" to "Pass 3D Applied — Pass 3 + DI revision; CombatResolver now `extends RefCounted` instance class, injectable; unblocks Orchestrator AC-ORC-03+05. Awaiting targeted re-review on Pass 3 blockers (Pass 3D did not re-open those)." Header Last Updated note appended with a one-sentence Pass 3D summary.
- `design/gdd/reviews/combat-resolution-review-log.md` — this entry.
- `production/session-state/active.md` — Pass 3D checkbox ticked; Last updated timestamp refreshed; Key Decisions / Combat bullet updated to reflect the new class declaration; Next Action options pruned (Combat 3D removed; Orchestrator 4A surfaced as next).

**Pass 3 invariants preserved**: statelessness (instance carries no per-run state), SPEED_BASE=2400, per-enemy matchup routing via `_kill_schedule_for_loop`, continuous `hp_bonus_factor` with Pillar 2 V1.0-deferred framing, `error_logger: Callable` injection pattern, public `dict_equals` helper, `@abstract` on no class (was on `CombatResolver extends Object`; removed because instantiation is now required). No Formulas changes; no ACs weakened.

**Unblocks**: Orchestrator GDD #13 **AC-ORC-03 (Logic, BLOCKING)** and **AC-ORC-05 (Integration, BLOCKING, covers AC-COMBAT-09b)** — both previously architecturally unwriteable. Orchestrator Pass 4D (DI inheritance) can now proceed in parallel with Pass 4A (internal correctness) / 4B (cross-GDD contracts) / 4C (engine conventions).

**Flags carried forward**: none new. Combat GDD is still awaiting the pre-Pass-3D targeted re-review on Pass 3's 9 blockers — Pass 3D does not gate that re-review and does not re-open any Pass 3 decisions; they can re-review Pass 3 in parallel with Pass 3D. The Pass 2B LOSING drip routing architectural gap (Orchestrator review Cluster E2) is **NOT** addressed by Pass 3D — that remains pending on the Economy revision pass / Orchestrator Pass 4B.

### Next step

Run **Orchestrator Pass 4A** (`design/gdd/dungeon-run-orchestrator.md`) — internal correctness, ~2 hours, self-contained, closes Clusters C + D + S3 (~12 BLOCKERs). See `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` 2026-04-20 entry for scope. Pass 3D does not need re-review in isolation (shape-only change, no behavior delta); it will be verified indirectly when Orchestrator Pass 4D writes AC-ORC-03+05 against the new DI shape.

## Flag — 2026-04-20 — Pass 3E Required — `CombatBatchResult.partial_loop_kills` Field

**Source**: Orchestrator Pass 4A D.4 rewrite. The new ordered kill-schedule loop-walk requires Combat to surface the partial final loop's kill events as an ordered list, not collapsed into `kills_by_archetype`/`kills_by_tier` dicts (which lose both ordering and tier information).

**What's needed**: Add `partial_loop_kills: Array[KillEvent]` to `CombatBatchResult` (Combat GDD C.4). Schema:

```
partial_loop_kills: Array[KillEvent]
# KillEvent reuses the existing shape from Rule 10 / D.5:
# { tick: int, archetype: StringName, tier: int, is_boss: bool, is_advantaged: bool }
# Ordered by tick (ascending). Empty if tick_budget aligned exactly to a loop boundary.
# Derivable from Combat's existing per-tick walk in `_kill_schedule_for_loop` — no new algorithm needed, just surface the partial-loop result.
```

**Why**: Orchestrator D.4 walks `snapshot.kill_schedule × loops_completed` for complete loops, then walks `partial_loop_kills` for the final partial loop. Without this field, the Orchestrator cannot correctly attribute gold for the partial loop — the dict-walk approach was arithmetically wrong on partial loops AND tier-losing.

**Interim fallback (documented in Orchestrator D.4 until Pass 3E lands)**: Orchestrator may derive partial-loop kills client-side by walking `snapshot.kill_schedule` from index 0 and stopping at the first kill whose `kill_tick > (tick_budget % snapshot.ticks_per_loop)`. Arithmetically equivalent because kill schedule is stable across loops (Combat Rule 8). Explicit Combat-surfaced field is preferred for test assertability — AC-ORC-09 parity test can compare per-kill attribution directly between foreground and offline paths.

**Scope**: Single field addition. One data-structure edit in C.4; no new formulas; no new ACs required at Combat layer (Orchestrator's AC-ORC-09 covers parity). Similar surface to Pass 3D in touch-lightness. Does not affect Pass 3 invariants (statelessness, SPEED_BASE, matchup routing, error_logger).

**Blocks**: Nothing immediately — Orchestrator D.4 documents the interim fallback so Orchestrator Pass 4A can proceed to implementation without waiting. Pass 3E unblocks a cleaner AC-ORC-09 parity test and removes the fallback documentation.

**Next step**: Author Pass 3E as a single-edit pass when Combat next receives attention — likely paired with the Pass 3 targeted re-review (same session, minimal additional scope).

## Amendment — 2026-04-20 — Pass 2B Locked Decision 4 Superseded by Pass 4B-Economy

**Trigger**: Pass 4B-Economy A2 re-litigation of LOSING drip routing (Orchestrator review Cluster A E2 — "LOSING drip halving has no implementation path under current architecture; vision-level question").

**Original Pass 2B decision 4 (2026-04-20)**: `LOSING_RUN_LOOT_FACTOR` (0.5) applies to **all gold from the run** — drip + per-kill bonuses + `FLOOR_CLEAR_BONUS[floor_index]`. Scope: "uniformly halved."

**Superseded to**: `LOSING_RUN_LOOT_FACTOR` applies to **per-kill bonuses and `FLOOR_CLEAR_BONUS[floor_index]` only — NOT to drip**. Drip per-tick output is run-outcome-independent by architecture. Effective date: 2026-04-20 (Pass 4B-Economy same-day).

**Rationale (A2, Option Y)**: Drip is owned entirely by Economy's independent `tick_fired` subscription path. Economy has no access to `RunSnapshot`; the Orchestrator has no architectural home for communicating `losing_run` to Economy's drip path without introducing a cross-system coupling (a new `run_losing_state_changed(bool)` signal subscriber pattern — Option X) that has no testable ordering guarantee against `tick_fired`. Cleaner boundary: **run-outcome-dependent rewards (kill gold, floor-clear) halve; run-outcome-independent rewards (drip) do not.** The LOSING feel already punches visibly through kill-gold and floor-clear halving — halving drip adds UX confusion ("why is my idle income slower?" without a visible losing-run indicator) without adding pedagogical weight. Pillar 1 (no fail state) is preserved. Pillar 2 (HP investment matters) retains mechanical teeth via kill-gold + floor-clear halving. MVP note: `losing_run` is architecturally unreachable on naturally-constructable formations (lowest natural `hp_bonus_factor` is solo L1 Rogue on F4 = 0.573), so MVP player impact is effectively zero — the knob is a V1.0-hard-content safety net.

**Files edited for this amendment**:
- `design/gdd/combat-resolution.md` — Rule 9 prose: halving scope narrowed from "drip + per-kill bonuses + FLOOR_CLEAR_BONUS" to "per-kill bonuses and FLOOR_CLEAR_BONUS only"; explicit superseded note citing Pass 4B-Economy and Economy review log A2.
- `design/gdd/dungeon-run-orchestrator.md` — E.5 second-clear-path prose: "half-rate drip" corrected to "full-rate drip"; AC-ORC-04 verification clause: explicit note that drip is NOT asserted in the LOSING end-to-end test + citation to superseded decision.
- `design/gdd/economy-system.md` — already reflects the superseded decision (C.2.3 LOSING_RUN scope note lines out drip; Pass 4B-Economy authored the narrowed scope as the primary source of truth).

**Not edited**:
- `design/registry/entities.yaml` — `LOSING_RUN_LOOT_FACTOR` constant's `notes` field may benefit from a scope update in a future housekeeping pass but is not load-bearing for the decision; Economy's C.2.3 prose is authoritative. Flag for tech debt if it comes up again.
- Combat AC-COMBAT-07b — asserted at Combat layer; Combat itself does not touch drip (drip is not in `compute_offline_batch` output shape), so AC-COMBAT-07b was already correctly scoped. No change.

**Flagged for tech debt**:
- `LOSING_RUN_LOOT_FACTOR` registry constant notes field may drift without a `notes` refresh — low priority; can be caught by the next `/consistency-check` pass.
- Economy GDD D.6 pacing table assumed the Pass 2B-original scope; verify pacing math is still consistent now that drip is un-halved. Flagged as follow-up in Economy review log Pass 4B-Economy.

## Flag — 2026-04-20 — Pass 3F Required — `KillEvent.to_dict` / `KillEvent.from_dict` Methods

**Source**: Orchestrator GDD #13 Pass 4B-SaveLoad (Cluster B) — Save/Load Rule 11 (Array-element serialization pattern) + AC SL-13 + Orchestrator AC-ORC-12 require `KillEvent` to be round-trippable through the Save/Load layer. Pass 3 Pass 3A locked `KillEvent.equals()` but did not add serialization methods because `KillEvent` was treated as a transient object at that time. Pass 4B-SaveLoad surfaced the gap.

**What's needed**: add two methods to `KillEvent` (Combat GDD C.4):
```
func to_dict() -> Dictionary:
    return {
        "tick": tick,
        "archetype": archetype,         # StringName
        "tier": tier,
        "is_boss": is_boss,
        "is_advantaged": is_advantaged,
    }

static func from_dict(d: Dictionary) -> KillEvent:
    if not d.has_all(["tick", "archetype", "tier", "is_boss", "is_advantaged"]):
        push_error("KillEvent.from_dict: missing required keys — got %s" % d.keys())
        return null
    var k: KillEvent = KillEvent.new()
    k.tick          = d.tick
    k.archetype     = d.archetype
    k.tier          = d.tier
    k.is_boss       = d.is_boss
    k.is_advantaged = d.is_advantaged
    return k
```

**Why**: `RunSnapshot.kill_schedule` is an `Array[KillEvent]`; Save/Load Rule 11 serializes each element via `.to_dict()` and reconstructs via `KillEvent.from_dict`. Without these methods, AC-ORC-12 and AC SL-13 are unwriteable.

**Scope**: Two method additions on one class. Zero behavior delta. No AC changes at Combat layer (Orchestrator + Save/Load own the round-trip tests). Similar surface to Pass 3D + Pass 3E — touch-light, no Pass 3 invariants at risk.

**Blocks**: AC-ORC-12 (Orchestrator) and AC SL-13 (Save/Load) are documented as "blocked on Pass 3F" — writeable on paper, not runnable until Pass 3F lands.

**Bundle recommendation**: **Batch Pass 3E + Pass 3F together** — both are single-field / single-class additions to Combat's type contracts (`CombatBatchResult.partial_loop_kills` + `KillEvent.to_dict` / `KillEvent.from_dict`). Bundle also with the still-pending Combat Pass 3 targeted re-review (9 pre-existing blockers from Pass 2B Re-Review) since all three are natural Combat-attention items. Combined ~1.5 hrs.

**Next step**: author Pass 3E + Pass 3F + Pass 3 targeted re-review as a single Combat-attention session.
