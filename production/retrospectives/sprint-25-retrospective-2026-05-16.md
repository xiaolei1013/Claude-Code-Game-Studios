# Sprint 25 Retrospective — 2026-05-16

> **Sprint Mapping**: S25-M5-rev (playtest gate + retro authoring per the Sprint 25 plan + addendum).
> **Sprint Window**: 2026-06-26 to 2026-07-09 nominal; actual close 2026-05-16 (thirteenth consecutive same-day-compressed sprint).
> **Review Mode**: Solo.
> **Status**: COMMITTED 2026-06-23 (light-touch) — closed on the user's aggregate verbal PASS of the unified playtest 16/17/18 session ("playtest done, core gameplay working"). The 5 playtest-16 per-check rows were not individually graded; closed on the aggregate verbal sign-off per the playtest-driven-closure precedent (cf. the Sprint 19/20 one-line verdicts).

## Sprint Goal — TBD pending playtest

> **Original goal (Day-0)**: Ship implementation of Floor Unlock System + Onboarding First-Session — both already-authored GDDs that hadn't been implemented.
>
> **Revised goal (post-addendum)**: Pivot to player-visible content + UX polish after grep audit revealed BOTH GDDs were already implemented (Floor Unlock = 576 lines + 4 test files + Dispatch wiring; Onboarding GDD explicitly forbids overlays per §A).

Final status (technical surface, pending playtest verdict):
- (a) M2-rev paladin class (PR #152) — ✅ shipped; tier-2 cozy-tank with role="defender" + counter="caster"
- (b) M3-rev boss floor visual (PR #153) — ✅ shipped; F5 darkens to 65% RGB intensity via `set_biome_for_floor`
- (c) S2-rev archer class (PR #154) — ✅ shipped; tier-2 ranged-DPS with role="ranged" + counter="swarm"
- (d) N2-rev floor lock indicator (PR #155) — ✅ shipped; 🔒 prefix + tooltip "Clear floor N first"
- (e) M5-rev playtest + retro — ✅ closed 2026-06-23 via the unified playtest 16/17/18 session (light-touch aggregate verbal PASS; see Status header)

## By the Numbers

- **PRs this sprint**: 6 (1 Day-0 plan + 1 addendum + 4 content/UX PRs)
- **Player-visible PRs**: 4 of 6 (vs Sprint 24's 2 of 10) — content-pivot delivered on the player-surface ratio
- **Cumulative tests at sprint close**: ~2293 (was ~2270 at start of S25; +23 net new across 4 new test files)
- **Regressions**: TBD on full-suite run (no known regressions; all PRs were additive)
- **New ADRs**: 0
- **GDD authoring**: 0 NEW. 0 amendments. The addendum closed the loop on "GDDs already exist; stop scoping authoring stories." See [[feedback_grep_first_check_must_run_pre_planning]].
- **New player-visible surface**:
  - 2 new classes (paladin + archer; class count 3 → 5)
  - F5 boss floor visual differentiation (every biome)
  - 🔒 lock indicator on locked floors with prerequisite tooltip
- **Locale keys added**: 1 (`floor_locked_tooltip_format`)
- **Scene/overlay registry**: unchanged
- **Version**: 0.0.0.65 → ~0.0.0.69 across the sprint (4 implementation PRs)
- **Solo same-day cadence**: 13th consecutive sprint (S14 → S25)

## What Worked

- **Grep-first check fired correctly and saved 3.5 days of duplicate work.** Immediately after merging the Day-0 plan, the grep audit surfaced Floor Unlock implementation + 6 biomes + Onboarding-as-diegetic-flow all already shipped. The addendum re-scoped Sprint 25 in the same session, before any wasted implementation time. The new memory entry `feedback_grep_first_check_must_run_pre_planning` makes this a hard skill-level step for future planning.
- **Per-task PR with `base=main` continued from Sprint 24 → 25.** Zero stacked-PR cascade issues. All 6 sprint PRs merged cleanly in numerical order.
- **Content addition without infrastructure changes.** Both paladin and archer dropped in as pure data (`.tres` + tests). DataRegistry's scan auto-discovers; ClassPortraitFactory's deterministic hash auto-generates portraits; Recruitment's pool generation auto-includes new classes. **Zero engine/system changes needed to grow the roster from 3 → 5 classes.** This is the data-driven payoff of the existing infrastructure investment.
- **Boss floor visual differentiation kept backward-compat.** New `set_biome_for_floor(biome_id, floor_index)` method added alongside existing `set_biome(biome_id)`; only DungeonRunView opted in. Victory Moment + Guild Hall + Recruit etc. continue using `set_biome` unchanged. Migration is per-screen on demand.
- **Floor lock UX polish used additive engine state.** The 🔒 prefix is purely visual; `disabled = true` still gates pointer/keyboard activation. Accessibility preserved.

## What Could Be Better

- **The Day-0 plan duplicated infrastructure-debt-drift mistakes within minutes of writing the warning memory entry.** This was the most uncomfortable finding of the sprint. The memory entry `feedback_infrastructure_debt_drift.md` was written in the same session as the Sprint 25 Day-0 plan, and the plan then scoped exactly the failure mode the memory described. The addendum self-corrected within the session, but the meta-lesson is: **memory entries do not self-enforce.** Lessons require workflow-level checks, not just documented warnings. Recorded as `feedback_grep_first_check_must_run_pre_planning`.
- **Sprint 25 still had a 33% non-player-visible PR ratio.** 2 of 6 PRs were planning/addendum (Day-0 plan, addendum). Those are not content — they're meta-work. The actual player-visible ratio is 4 of 6. Better than Sprint 24's 2 of 10, but still room for improvement if Sprint 26 aims for ≥80%.
- **No real-art ingestion happened.** Sprint 25 N3 was contingent on the art workstream landing an ETA. The art workstream has no ETA. ClassPortraitFactory continues to be the production path; the player still sees programmatic placeholder portraits. If the art workstream remains stalled into Sprint 26+, the project should either commit to "programmatic placeholders are the V1.0 art bar" or escalate art sourcing.
- **Sprint 25 did not address core-loop variety.** The 2 new classes expanded the comp space, and F5 visual differentiation made the boss read as bigger, but the actual moment-to-moment gameplay (tap Dispatch → watch counter tick → see reward) is unchanged. If the playtest-16 verdict is "still not progressing," the content gap is core-loop variety, not class/biome count.

## What I'd Do Differently Next Time

1. **Run the grep-first check BEFORE writing the Day-0 plan, not after.** Sprint 25 caught the mistake via the addendum, but a cleaner workflow would prevent the Day-0 plan from being scoped wrong in the first place. The grep-first check needs to live in `/sprint-plan new` as a hard step.
2. **Sprint 26 plan should explicitly grade each candidate task on "what does the player see different?"** before adding it to Must Have. If the answer is vague or infrastructure-shaped, push to Should Have or Nice to Have. Make this an explicit row in the plan template.
3. **Two grading axes per playtest, not just "is it working."** Playtest-16 already does this (5 specific per-check axes). Future playtests should always have per-check granularity tied to specific PRs, so a PARTIAL/FAIL can be traced back to a specific change.
4. **Treat the human-blocked playtest gate as the source of truth, not as a formality.** Sprint 24's retro said "TECHNICAL: MET; STRATEGIC: FAILED" because the playtester said the game wasn't progressing. Sprint 25 trusted that signal and pivoted. Future sprints should not declare success on technical metrics alone — the playtest verdict is load-bearing.

## Sprint 26 Recommendations (provisional, pending playtest-16 verdict)

**If playtest-16 grades 4–5 of 5 PASS**: Sprint 25 succeeded. Sprint 26 continues content-first cadence:
- Real product art ingestion (if art workstream has ETA)
- Equipment / items system (NEW mechanic layer — needs GDD authoring, but with grep-first check first)
- 1–2 more classes (cleric for healer archetype? engineer for support?)
- Core-loop variety: per-floor enemy escalation, mid-run choices, sub-floor variant rooms

**If playtest-16 grades 2–3 of 5 PASS**: Sprint 25 was directionally correct but had wiring gaps. Sprint 26 starts with carryforward stories for the failed checks.

**If playtest-16 grades 0–1 of 5 PASS**: Sprint 25 misread the actual gap. Sprint 26 must escalate further. Likely escalation paths:
- Real art (replacing programmatic placeholders) — biggest single visual upgrade
- Equipment/items as a new mechanic layer — adds depth not just breadth
- Player-driven choice during runs (mid-run reassignment is already shipped — make it matter more by adding consequence)

**Anti-pattern to actively avoid in Sprint 26 planning**: scoping more GDD authoring or test fixture hygiene or engine polish stories. The infrastructure-debt-drift + grep-first memory entries are canonical guardrails.

## Files Touched This Session

- `production/sprints/sprint-25.md` — NEW (Day-0 plan PR #150) + addendum (PR #151)
- `production/sprint-status.yaml` — Sprint 24 archived, Sprint 25 stories block (PR #150)
- `production/retrospectives/sprint-24-retrospective-2026-05-16.md` — NEW (PR #150)
- `assets/data/classes/paladin.tres` — NEW (PR #152)
- `tests/unit/hero_class_database/paladin_registration_test.gd` — NEW (PR #152)
- `assets/screens/_shared/biome_background.gd` — `set_biome_for_floor` + `BOSS_FLOOR_DARKEN_FACTOR` (PR #153)
- `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd` — `get_dispatched_floor_index` accessor (PR #153)
- `assets/screens/dungeon_run_view/dungeon_run_view.gd` — opt-in to `set_biome_for_floor` (PR #153)
- `tests/unit/biome_background/set_biome_for_floor_test.gd` — NEW (PR #153)
- `tests/unit/dungeon_run_orchestrator/get_dispatched_floor_index_test.gd` — NEW (PR #153)
- `assets/data/classes/archer.tres` — NEW (PR #154)
- `tests/unit/hero_class_database/archer_registration_test.gd` — NEW (PR #154)
- `assets/screens/formation_assignment/formation_assignment.gd` — 🔒 + tooltip on locked floor buttons (PR #155)
- `assets/locale/en.csv` — `floor_locked_tooltip_format` key (PR #155)
- `tests/unit/formation_assignment/floor_picker_lock_indicator_test.gd` — NEW (PR #155)
- `production/playtests/playtest-16-sprint-25-content-pivot-2026-05-16.md` — NEW (this PR)
- `production/retrospectives/sprint-25-retrospective-2026-05-16.md` — NEW (this PR; DRAFT until playtest verdict)

## Memory Recorded This Sprint

- `feedback_grep_first_check_must_run_pre_planning.md` — **load-bearing**: agent committed infrastructure-debt-drift mistake within minutes of writing the warning memory; lesson is that memory entries don't self-enforce; grep-first must be a workflow-level step.

## Carryover Acknowledged

- **None mandatory**. Sprint 25 was the content pivot, and all the addendum's revised Must Haves either landed or were closed as VERIFIED-IN-PLACE. The Day-0 Must Haves (Floor Unlock implementation + Onboarding overlay) were closed without carryforward — they did not need implementation.
- **Sprint 24 S24-S1 polish carryforward**: DEFERRED PERMANENTLY per Sprint 24 retro. Confirmed deferred this sprint — none of the items (Guild Hall empty-state, Dispatch empty-slot hints, tap-target audit, Primary Button audit) re-entered Sprint 25 scope.
- **Sprint 24 S24-S3 remaining test-fixture sites**: DEFERRED until those test files are touched for unrelated reasons. Helper is non-breaking; coexistence is fine.

## Sprint Goal — Final Disposition

**PENDING**. Sprint 25 ships 4 player-visible PRs (paladin, boss floor visual, archer, lock indicator). The strategic verdict — did this turn the corner on the "uiux and functions are not progressing" signal? — depends on playtest-16. This retro will flip from DRAFT to COMMITTED once the tester grades the 5 per-check rows in `playtest-16-sprint-25-content-pivot-2026-05-16.md`.
