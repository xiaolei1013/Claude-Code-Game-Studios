# Sprint 22 Retrospective — 2026-05-15

> **Sprint Mapping**: S22-M5 (folded with M5 playtest gate per the Sprint 22 plan).
> **Sprint Window**: 2026-05-15 to 2026-05-28 nominal; actual close 2026-05-15 (ninth consecutive same-day-compressed sprint).
> **Review Mode**: Solo.
> **Status**: DRAFT — finalize after M5 playtest verdict lands in `playtest-14`.

## Sprint Goal — [Pending M5 playtest verdict; preliminary assessment: MET on structural axes]

> **Reduce 10 scenes to 7 by collapsing the redundant ones, fold the matchup picker into Formation Assignment as a unified Dispatch screen, then run a clarity pass on every screen with the now-visible parchment theme.**

Preliminary status against the 6 success conditions defined in the plan (final verdict pending playtest-14):
- (a) `main_menu` retired; run-end + boot route directly to Guild Hall — PR #126 OPEN (orthogonal). Code change is trivial; merge is the only step left.
- (b) `matchup_assignment` folded into `formation_assignment` as a Dispatch screen — ✅ PR #127 merged. Player no longer leaves Dispatch to change floor.
- (c) `hall_of_retired_heroes` → tab on Guild Hall — DEFERRED to Sprint 23 (was S22-S2; not landed).
- (d) `pause_menu` modal scene built — DEFERRED to Sprint 23 (was S22-S3; not landed).
- (e) BiomeBackground visible on Recruit, Dispatch, Victory, Return-to-App — ✅ PR #128 merged.
- (f) Per-screen clarity pass: IdentityHeader on every screen + Dispatch GoldCounter — ✅ PR #129 merged. Items (c)(d)(e) from the M4 checklist (empty-state clarity, tap-target verification, Primary Button on CTAs) deferred to M5 playtest signal.
- (g) Visual playtest validates the consolidated architecture — PENDING playtest-14.
- (h) Sprint 22 retro committed — IN PROGRESS (this file).

## By the Numbers

- **PRs merged this sprint**: 4 sprint-execution + 1 plan = 5 (#125 plan, #127 matchup fold, #128 biome backgrounds, #129 clarity polish). #126 (main_menu retire) OPEN at retro time — orthogonal.
- **Cumulative tests at sprint close**: 358 PASS / 0 errors / 0 failures (focused regression at M4 close; full-suite re-run pending M5 playtest cycle).
- **Regressions**: 0.
- **New ADRs**: 0 (scene consolidation is structural cleanup, not architectural decision-making).
- **GDD status transitions**: 0.
- **New contract tests**: 3 (M3 BiomeBackground on every screen + base-type drift guard + M4 IdentityHeader presence guard).
- **Scene registry**: 9 → 8 entries (M2 fold; pending → 7 on M1 merge).
- **Version**: 0.0.0.47 → 0.0.0.50 across the sprint (3 implementation PRs — #127 → 48, #128 → 49, #129 → 50; #126 will be 51 post-merge; plan PR #125 does not bump version).
- **Solo same-day cadence**: 9th consecutive sprint (S14 → S22).

## What Worked

- **The theme-inheritance fix (PR #124, from late S21) unlocked everything Sprint 22 attempted.** Without the `ScreenContainer` type=Node → Control fix, the BiomeBackground + IdentityHeader + GoldCounter work in Sprint 22 would have been invisible (rendered with Godot defaults). The Sprint 22 plan correctly identified PR #124 as the prerequisite; merging it first made M3 + M4 meaningful instead of cosmetic theater.
- **The "discovery: feature is already dead code" pattern shipped twice this sprint.** S22-M1 found that no live code path reached `main_menu` (boot → Guild Hall; RUN_ENDED → victory_moment). What looked like a refactor became deletion. Sprint 23+ should adopt this as a default first-step for any "retire X" task: search live paths BEFORE planning the migration.
- **Pattern-overlay reuse on M2.** Folding `matchup_assignment` into `formation_assignment` reused the existing `MidRunReassignConfirmation` overlay structure 1:1. The FloorPickerOverlay node tree (full-rect Control + DimBackdrop + centered PickerPanel + content stack) was a direct copy of an in-scene pattern. No new design needed; just consistent application.
- **Per-check playtest template FINALLY shipped (S22-S1).** Fourth-time carry from S19 retro #5 / S20 retro #6 / S21 retro action #2 — `_template-visual-playtest.md` lives at `production/playtests/`. Used by S22-M5 playtest-14 going forward. The pattern: explicit PASS / PARTIAL / FAIL per row, aggregate is advisory. Removes the "one-line verdict hides specific gaps" failure mode that bit Sprints 19-21.
- **Solo same-day cadence held for ninth consecutive sprint.** S14 → S22. The 1-day plan-to-close pace is structural baseline, not aspirational.
- **Process trial #1 (sprint-status flip-on-merge) and #3 (git status --short verification) carried cleanly** through Sprint 22's PRs. No mis-staged commits, no stale sprint-status entries (this PR will flip M2-M4 to done in the same commit per trial #1).

## What Hurt

- **Sprint 22 plan deferred S22-S1 to fourth time.** The playtest checklist template's repeated carry was a process tell — "Should Haves only if Must Haves done with headroom" kept pushing the meta-process work out of every sprint. The fix this time was bundling S22-S1 INTO M5 setup (this PR) rather than treating it as a separate item. Lesson for Sprint 23: meta-process work that's blocked 3+ sprints in a row should be promoted to Must Have or it never lands.
- **PR #126 (main_menu retire) sat OPEN through M2-M5.** Discovered as dead code by S22-M1 investigation; the PR shipped clean and CI-green, but the user merged #127/#128/#129 without merging #126. The Sprint 22 scene-consolidation goal (10 → 7) requires #126 to merge — without it the registry is at 8, not 7. **Action for Sprint 23**: explicit PR-ordering ritual when a sprint has cross-PR ordering constraints. The Sprint 22 plan's "pre-plan disposition" comment block was the right idea but not enforced at merge time.
- **S22-S2 (hall_of_retired_heroes → tab on Guild Hall) and S22-S3 (Pause Menu modal) didn't land.** Both were Should Haves at 0.75d each. The 1.5d of Should Have scope was theoretically achievable inside the 8d available days, but the sprint was front-loaded with Must Haves M1-M4 (4.75d) + S1 setup work + the discovery work on M1/M2 that came with surprises. Realistic capacity for Should Haves on a 9th-consecutive-same-day-close sprint is ~0 — momentum is on Must Haves only.
- **Items (c)(d)(e) of the M4 clarity checklist deferred to M5 playtest signal.** Empty-state clarity, tap-target ≥44×44 verification, Primary Button on CTAs — these were in the M4 scope but not addressed. The deferral is defensible (playtest can drive prioritization rather than blind-applying all 3 items), but it's an admission that M4 didn't fully execute its checklist.

## Action Items for Sprint 23

| # | Action | Priority | Owner |
|---|--------|----------|-------|
| 1 | **Merge PR #126 (S22-M1 main_menu retire)** before Sprint 23 work begins. Trivial merge; closes the 10 → 7 scene consolidation goal. | **HIGH** | user |
| 2 | **S22-S2 hall_of_retired_heroes → tab on Guild Hall** — carried from Sprint 22; promoted to Sprint 23 Must Have if scope holds. Currently 0.75d; pull in if user confirms. | HIGH | godot-gdscript-specialist |
| 3 | **S22-S3 Pause Menu modal scene** — carried from Sprint 22; same logic as #2. Currently 0.75d. Pull in if scope holds. | MED | godot-gdscript-specialist |
| 4 | **M4 clarity follow-up** — if playtest-14 surfaces specific gaps in empty-state copy, tap targets, or unstyled CTAs, ship a follow-up PR before declaring Sprint 22 fully closed. | depends on M5 verdict | claude-code |
| 5 | **PR-ordering ritual** — when a sprint has merge-order dependencies, explicitly verify upstream PRs are merged before subsequent ones. The Sprint 22 plan's pre-plan-disposition block was the right pattern but wasn't enforced. Codify as a checklist item. | LOW (process) | claude-code |
| 6 | **Promote meta-process Should Haves to Must Have on 3rd carry.** S22-S1 took 4 sprints to land. The rule: if a Should Have carries 3 sprints, the next sprint promotes it. Apply going forward. | LOW (process) | producer |
| 7 | **S20-N1 ClassPortrait placeholder art** — twice-carried from S20 and S21. Same pattern as #6 — promote to Sprint 23 Should Have at minimum. Real-art workstream hasn't shipped an ETA. | MED | claude-code + godot-shader-specialist |

## Process Improvements

- **Per-check playtest verdicts are now the project default** (via S22-S1 template). The Sprint 19-21 "one-line verdict" failure mode is structurally retired.
- **"Dead code first" investigation pattern.** S22-M1 confirmed `main_menu` was already dead before any retire work; M2 confirmed `matchup_assignment` was a screen-transition that could become an inline overlay without behavior change. Both saved significant migration effort by finding the simpler path first. Adopt as a default Sprint 23 onward: before designing a refactor, grep for the live paths to confirm what's actually in use.
- **Pre-plan PR-disposition blocks need ENFORCEMENT, not just documentation.** The Sprint 22 plan's "MERGE FIRST" + "MERGE after #124" comments were correct guidance but didn't prevent PR #126 from sitting open. Future sprints with merge-order dependencies need a checklist item or a CI gate.
- **Process trial #1 (sprint-status flip-on-merge) and #3 (git status --short) graduated to baseline.** Both shipped cleanly through 4 PRs in Sprint 22 without any mis-staged commits or stale status entries. They're no longer trials — they're how we work.

## Notes

- **Sprint 22 closes [4/5 Must Haves DONE; 0/3 Should Haves; 0/1 Nice to Have]** at retro time. M5 verdict pending playtest-14. Sprint goal preliminary status: structurally MET on the scene consolidation + clarity polish axes; final verdict on whether the post-Sprint-22 build reads clearer than the 2026-05-15 morning screenshots is the M5 playtest gate.
- **Day-0 plan + same-day close: ninth consecutive sprint.** S14 → S15 → S16 → S17 → S18 → S19 → S20 → S21 → S22. The cadence is structural baseline.
- **19 ADRs cumulative.** Sprint 22 added 0 (scene cleanup is structural maintenance).
- **The theme-inheritance bug (PR #124) cost the project 5 sprints of invisible visual work.** Sprint 22 was effectively the "make the visible visible" sprint — every M2/M3/M4 PR depended on the parchment theme actually rendering. Without #124's one-line fix, Sprint 22 would have shipped correct code that nobody could see, repeating the Sprint 10-21 pattern.
- **Scene consolidation: 10 → 8 at retro time; → 7 after #126 merges.** The Sprint 22 plan's central numerical goal lands when the orthogonal PR #126 merges.
- **The 2026-05-15 morning playtest screenshots are the load-bearing reference for the M5 verdict.** Tester walks the same flow against the post-Sprint-22 build. If the subjective register feels meaningfully clearer, Sprint 22 closes PASS. If it still reads "demo quality," Sprint 23 starts with another clarity pass.
