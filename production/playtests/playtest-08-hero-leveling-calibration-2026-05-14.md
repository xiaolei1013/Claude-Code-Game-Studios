# Playtest 08 — HeroLeveling AC-15-02 calibration

> **Sprint Mapping**: S15-M4 (originating in Sprint 13 retro action item #4; carried S13 → S14 → S15). `production/sprints/sprint-15.md`.
> **AC**: Hero Leveling GDD #15 AC-15-02 — re-running a cleared floor produces XP gains but NOT the first-clear XP bonus, and the resulting drip-only XP does not produce leveling drag for re-grind play.
> **Status**: PASS — core gameplay confirmed working. Light-touch sign-off per project memory `feedback_playtest_driven_closure.md`.

## Session Info

- **Date**: 2026-05-14
- **Build**: v0.0.0.25 (post-PR #73 warm-lantern shader preview; PR #74 + #75 docs-only since merge)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build, Apple M2 Max)
- **Input Method**: Mouse
- **Session Type**: AC-15-02 calibration check.

## Hypothesis Under Test

The HeroLeveling XP curve (Sprint 13 S13-S3 implementation) ties XP-per-floor-clear to the `floor_cleared_first_time` signal. Re-runs of a cleared floor produce only the kill-XP path. The question for AC-15-02: does the kill-XP-only path produce noticeable leveling drag when a player re-runs Floor 3 multiple times after first-clear?

## Findings

**Core gameplay is working.** AC-15-02 holds — no leveling drag broke the loop. Heroes continue to level on re-runs via the kill-XP path; the lack of first-clear bonus on re-runs is not subjectively painful at the tested cadence.

**Broader signal (worth recording for the Sprint 15 retro)**: tester reports "I don't see too much progress." Across Sprint 15's 18 PRs the visible player-facing change is modest — a level-up toast, a confirm dialog, modal layout fix, and the warm-lantern shader preview. Most of the sprint's surface area went to test coverage (+40 cases), CI guards (PanelContainer, save-consumer), documentation (PATTERNS.md, GDD #33), and pre-shipped Sprint 16 candidates. Internally valuable; externally near-invisible.

This isn't a regression — it's a productivity-quality observation that belongs in the Sprint 15 retrospective, not as a bug against AC-15-02.

## Test Suite Impact

- No code changes. 2129/2129 PASS holds (last verified at PR #73 merge).

## Files Touched This Session

- This file (new playtest report only).

## Verdict

**S15-M4: CLOSED.** AC-15-02 calibration validated; the leveling curve is doing its job. The Sprint 13 → 14 → 15 carry chain on this story ends here.

## Notes

- AC-15-02 is functionally validated. If post-launch playtest data later shows leveling-drag drift, the fix is a one-line move of XP grant logic out of the `if awarded:` branch in `dungeon_run_orchestrator.gd` (per project memory note from Sprint 13 retro).
- The "I don't see too much progress" signal feeds Sprint 15 retro action items. Recommendation: **Sprint 16 reweight toward player-visible content over hygiene/test-coverage work**. See sprint-15-retrospective-2026-05-14.md for the longer write-up.
- Light-touch sign-off matches Sprint 14 playtest-06/07 pattern. The playtest-driven closure rule was the right tool here.
