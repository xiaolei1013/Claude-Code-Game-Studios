# Sprint 26 Retrospective — 2026-05-16

> **Sprint Mapping**: S26-M5 (playtest gate + retro authoring per the Sprint 26 retroactive Day-0 plan).
> **Sprint Window**: 2026-07-10 to 2026-07-23 nominal; actual close 2026-05-16 (thirteenth consecutive same-day-compressed sprint).
> **Review Mode**: Solo.
> **Status**: DRAFT — pending playtest-17 verdict per `production/playtests/playtest-17-sprint-26-content-pivot-2026-05-16.md`. Will flip to COMMITTED once the tester grades the 5 per-check rows.

## Sprint Goal — Technically MET, awaiting playtest verdict

Original retroactive goal: *"Continue the content-pivot from Sprint 25 — expand the class roster, surface progression-gated biomes correctly in Dispatch, and close the synergy gap created by the new tier-2 classes."*

Final status (technical surface):
- (a) M1 Dispatch picker R7 compliance — ✅ shipped (PR #158)
- (b) M2 Berserker class — ✅ shipped (PR #159)
- (c) N1 Test helper Rule-of-Three refactor — ✅ shipped (PR #160)
- (d) M3 Cleric class — ✅ shipped (PR #161)
- (e) `/simplify+/review` cleanup — ✅ shipped (PR #162)
- (f) Parse-error hotfix — ✅ shipped (PR #163)
- (g) M4 Tier-2 class synergies — ✅ shipped (PR #164)
- (h) M5 playtest + retro — ⚠️ playtest TBD; this retro is DRAFT until tester grades playtest-17

## By the Numbers

- **PRs this sprint**: 7 (5 content/UX + 1 refactor + 1 hotfix)
- **Player-visible PRs**: 5 of 7 (71%) — improvement over Sprint 24 (20%), on par with Sprint 25 (66%)
- **Cumulative tests at sprint close**: ~2335 (was ~2293 at start of S26; +42 net new across 4 new test files)
- **Regressions**: 0 (one parse error caught in same session and hotfixed via PR #163)
- **New ADRs**: 0
- **GDD authoring**: 0 NEW. 1 AMENDMENT to `class-synergy-system.md` §C.6 V2 Tier Ladder (adding 4 new tier-2 synergies to the Gold row + the synergy_id_to_tier code block)
- **New player-visible surface**:
  - 2 new classes (berserker + cleric; class count 5 → 7)
  - 4 new mono-class synergies (Bastion / Volley / Frenzy / Vigil) with detection AND multiplier resolution
  - Dispatch screen shows only unlocked biomes (4 starter → 5 → 6 as chains fire), not all 6 from session 1
- **Locale keys added**: 4 (class_synergy_badge_bastion / _volley / _frenzy / _vigil)
- **Version**: ~0.0.0.69 → ~0.0.0.75 across the sprint (~7 PRs)
- **Solo same-day cadence**: 13th consecutive sprint (S14 → S26)

## What Worked

- **Grep-first GDD-existence check ran cleanly throughout planning.** Zero duplicate GDD authoring this sprint. The Sprint 25 mistake (S25 Day-0 plan scoped already-shipped GDDs) did not repeat.
- **Content addition via pure data extension.** Both new classes (berserker, cleric) shipped as `.tres` + tests only. DataRegistry auto-discovers, Recruitment auto-pools, ClassPortraitFactory auto-portraits. The data-driven infrastructure investment from Sprints 16-24 paid off.
- **Rule-of-Three refactor at the right moment.** Berserker (3rd tier-2 class) triggered the ClassRegistrationTestHelper extraction. Cleric immediately benefitted (~50 LOC test file vs ~100 LOC pre-helper).
- **Tier-2 synergy work used the existing AC-CS-18 forward-compat path.** Orchestrator's `_:` fallback returned 1.0 for unknown synergy_ids; adding 4 new match arms was purely additive, no system surgery.
- **R7 compliance fix surfaced via grep audit, not playtest.** Sprint 26 M1 caught the Dispatch screen reading DataRegistry directly instead of FloorUnlock.get_available_biomes(); this was a latent UX gap (all 6 biomes visible from session 1) that the player would have eventually noticed.
- **Hotfix turnaround was fast.** Parse error caught + fixed within the same session as the cleanup PR (PRs #162 → #163 same-session).

## What Could Be Better

- **Parse error landed on main before being caught.** The `const VALID_STAT_NAMES: PackedStringArray = PackedStringArray([...])` violation should have been caught BEFORE merging PR #162. Running `godot --headless --check-only` (or just opening the editor once) would have surfaced it in seconds. Process learning: run a parse check on test-helper changes pre-merge.
- **Hand-written placeholder UIDs don't survive editor scan.** `uid://b2berserkermvp001` and similar were invalid Godot UID format; the editor regenerated them. Process learning: never hand-author UIDs — leave the attribute off and let Godot fill on first import. Recorded in Sprint 26 Process Rules.
- **No Day-0 plan PR for Sprint 26.** Work shipped directly (#158 → #161 → #160 → #164 → #162 → #163). Sprint tracking was implicit until this retroactive doc landed. Sprint 27 should bundle the Day-0 plan into the first content PR.
- **Sprint 25 retro still DRAFT (compounded scope).** Sprint 26 shipped MORE content on top of Sprint 25's pending playtest. The tester now has 5 axes from playtest-16 + 5 axes from playtest-17 to grade. A single deep playthrough can cover both (noted in playtest-17 §"Notes on stacked Sprint 25 + 26 grading"), but it's a heavier ask than per-sprint playtest cadence.
- **`/simplify+/review` agents flagged "stringly-typed stat_name" but I fixed it with a runtime guard, not an enum.** A real fix would be a `Stat` enum that maps to property names. The guard is defensive but doesn't prevent typo at write time. Defer to Sprint 27+ if the helper sees frequent use.

## What I'd Do Differently Next Time

1. **Open the Godot editor once per session before/after substantial test-helper changes.** Sprint 26's parse error landed on main; a 30-second editor open would have caught it.
2. **Skip hand-written UIDs on new .tres files.** Let Godot regenerate on first import. Saves 2 redundant edits per new class.
3. **Bundle Sprint Day-0 plan into the first content PR.** Saves the retroactive-authoring step + makes the sprint's intent visible at first PR open.
4. **Run playtest after every 4-5 content PRs.** Sprint 26's content surface compounded on top of Sprint 25's — playtest grading scope doubled.
5. **Adopt a Stat enum for the helper instead of a stat_name string.** Would have caught typos at write time, not runtime. Defer until the helper sees more callers.

## Sprint 27 Recommendations

**Provisional, pending playtest verdicts (both Sprint 25 + Sprint 26).**

If playtest 16+17 verdict is positive:
- **Synergy effect-text on Dispatch label.** Right now player sees "Synergy: Gold (Bastion)" but doesn't know "+25% gold vs caster". Append the effect description when a conditional synergy is active.
- **Recruit pool size tuning.** With 7 classes and pool size 3, P(specific class) per refresh is ~37%. Players building 3-of-a-kind may find this slow. Consider pool size 4 or 5, or a "draft" mechanic.
- **Real product art ingestion** if workstream lands. ClassPortraitFactory continues as production fallback.

If verdict shows gaps:
- Address named gap first; defer broader expansion.

**Anti-pattern guardrails** (carried from Sprint 25 + 26 memories):
- No new GDD authoring without grep-first check
- No test fixture hygiene unless Rule-of-Three is met (and ROI is clear at 3rd occurrence)
- No engine optimization stories that produce zero player-visible change

## Files Touched This Session

Sprint 26 content / UX:
- `assets/data/classes/berserker.tres` + test (PR #159)
- `assets/data/classes/cleric.tres` + test (PR #161)
- `assets/screens/formation_assignment/formation_assignment.gd` — biome filter R7 compliance + biome_unlocked handler (PR #158); 4 new SYNERGY_* consts + detect_active_synergy extension (PR #164); /simplify cleanup (PR #162)
- `src/core/formation_assignment/formation_assignment.gd` — 4 new SYNERGY_* consts + detect_active_synergy extension (PR #164)
- `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd` — 4 new multiplier consts + match arms (PR #164)
- `src/ui/ui_framework.gd` — synergy_id_to_tier extension (PR #164)
- `assets/locale/en.csv` — 4 new badge keys (PR #164)
- `design/gdd/class-synergy-system.md` §C.6 — V2 Tier Ladder updated (PR #164)
- `tests/helpers/class_registration_test_helper.gd` (NEW PR #160; stat-name guard PR #162; parse error fix PR #163)
- `tests/unit/helpers/class_registration_test_helper_test.gd` (NEW PR #160; canary test PR #162)
- `tests/unit/hero_class_database/paladin_registration_test.gd` + `archer_registration_test.gd` — refactored to use helper (PR #160)
- `tests/unit/formation_assignment/tier2_synergy_detection_test.gd` (NEW PR #164)
- `tests/unit/dungeon_run_orchestrator/tier2_synergy_multipliers_test.gd` (NEW PR #164)
- `tests/unit/formation_assignment/floor_picker_available_biomes_filter_test.gd` (NEW PR #158)

Sprint 26 meta-work (this PR):
- `production/sprints/sprint-26.md` (NEW — retroactive Day-0 plan)
- `production/playtests/playtest-17-sprint-26-content-pivot-2026-05-16.md` (NEW — grading template)
- `production/retrospectives/sprint-26-retrospective-2026-05-16.md` (NEW — this file, DRAFT)
- `production/sprint-status.yaml` — Sprint 25 archived, Sprint 26 stories block

## Memory Recorded This Sprint

- No NEW memory entries. The prior memories (`feedback_infrastructure_debt_drift`, `feedback_grep_first_check_must_run_pre_planning`) both held — Sprint 26 honored them. Process learnings (parse-check before merge; skip hand-written UIDs) recorded inline in Sprint 26 Process Rules instead of separate memory files; if they recur, promote to memory entries.

## Carryover Acknowledged

- **None mandatory.** All Sprint 26 stories shipped. The two new process learnings (parse-check, UIDs) are codified in Sprint 26 Process Rules and carry to Sprint 27 planning.

## Sprint Goal — Final Disposition

**PENDING playtest-17.** Sprint 26 shipped 5 player-visible PRs (M1 biome filter, M2 berserker, M3 cleric, M4 tier-2 synergies, N1 helper-refactor support). The strategic verdict — did this turn the corner on the "uiux and functions are not progressing" signal? — depends on the tester's grading. This retro will flip from DRAFT to COMMITTED once the playtest doc grades the 5 per-check rows.
