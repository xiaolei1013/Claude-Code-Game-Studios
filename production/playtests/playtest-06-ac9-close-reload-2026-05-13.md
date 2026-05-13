# Playtest 06 — Story 016 AC-9 close-reload smoke

> **Sprint Mapping**: S14-M4 (carryover from S13-M3, which originated in S12-S1). `production/sprints/sprint-14.md`.
> **AC**: Story 016 AC-9 — player state (gold, roster, floor unlocks, prestige records) survives a full quit/reopen of the Godot build.
> **Status**: PASS — light-touch sign-off. No regressions observed across multiple close/reopen cycles.

## Session Info

- **Date**: 2026-05-13
- **Build**: v0.0.0.18 (post-PR #59 `show_modal` lifecycle hardening merge)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build, Apple M2 Max)
- **Input Method**: Mouse
- **Session Type**: Manual close-reload smoke. Multiple short cycles across one evening.

## Hypothesis Under Test

`SaveLoadSystem` persists Economy + HeroRoster + DungeonRun progress on the documented save boundaries, and the next launch's autoload `_ready` cycle restores them with no drift. Specifically: gold balance, recruited heroes (including any that have been prestiged into the Hall), and the unlocked floor set must all survive a `Cmd-Q`/relaunch round trip.

**Result**: hypothesis HELD. State preserved across every observed cycle.

## Walkthrough (high level)

- [x] Launch fresh → state from prior session present (gold balance, roster, prestige count, Hall button visibility match the last known state pre-quit)
- [x] Perform some action (recruit, dispatch, level-up) → quit via `Cmd-Q`
- [x] Relaunch → action's effect persists; no rollback, no double-application
- [x] Repeat across multiple cycles → no drift

## Findings

None. Save round-trip pipeline (Sprint 11's S11-M1 → S11-M4 work) is doing its job. The 2042 → 2097 tests over the persist surface evidently translate to real-world stability.

## Test Suite Impact

- No code changes. 2097/2097 PASS still in effect from v0.0.0.18.

## Files Touched This Session

- This file (new playtest report only).

## Verdict

**S14-M4: CLOSED.** Story 016 AC-9 confirmed in production build. The S12-S1 → S13-M3 → S14-M4 carry chain ends here.

## Notes

- Light-touch sign-off per project memory `feedback_playtest_driven_closure.md`: "100% tests passing ≠ shipped." This playtest is the human-signal closure step.
- No deep-dive notes captured — user explicitly chose the light-touch path. Future regressions in this area would be caught by `tests/integration/save_load_system/` round-trip suite first; a fresh playtest is only needed if those go red.
