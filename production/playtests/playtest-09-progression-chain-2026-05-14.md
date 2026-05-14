# Playtest 09 — Multi-biome progression chain

> **Sprint Mapping**: S17-M6 (originating in Sprint 16 retro action item #1). `production/sprints/sprint-17.md`.
> **AC**: Sprint 16 progression-gate chain — clearing Frostmire F5 unlocks Ember Wastes; clearing Ember Wastes F5 unlocks Hollow Stair. Cozy-register unlock moments per Floor/Biome Unlock System GDD §B.
> **Status**: PASS — original bug fixed, chain works end-to-end. Light-touch sign-off per project memory `feedback_playtest_driven_closure.md`.

## Session Info

- **Date**: 2026-05-14
- **Build**: v0.0.0.37 (post-PR #90 Economy multi-biome ledger fix)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build, Apple M2 Max)
- **Input Method**: Mouse
- **Session Type**: Full progression-chain validation run.

## Hypothesis Under Test

PR #90 widened Economy's `_floor_clear_bonus_credited` ledger from `Dictionary[int, int]` to `Dictionary[String, int]` keyed by `"<biome_id>_f<floor_index>"`, fixing the cross-biome collision that silently bricked boss-floor progression in every non-starter biome. The question for S17-M6: does the live build now let the player clear Forest Reach → Frostmire → unlock Ember Wastes → clear → unlock Hollow Stair as the Sprint 16 progression chain designed?

## Findings

**Original issue fixed.** Tester reports: *"The original issue is fixed. It works great."*

The multi-biome ledger collision is gone. Boss floors advance the unlock counter in every biome. The progression-gate chain fires as designed:
- Frostmire F5 first-clear → Ember Wastes appears in the biome list (the "you unlocked X" beat lands)
- Ember Wastes F5 first-clear → Hollow Stair appears

Cozy-register unlock moment reads correctly per Floor/Biome Unlock System GDD §B — "the lantern moved one step further" rather than "NEW CHAPTER UNLOCKED!!!"

## Test Suite Impact

- Cumulative tests at fix landing: 2190 PASS.
- New regression suite shipped with PR #90: `tests/integration/economy/multi_biome_floor_clear_ledger_test.gd` (6 tests, all PASS).
- The pre-fix bug was invisible to the existing test suite — every test was authored against the MVP single-biome assumption, so the cross-biome ledger collision was structurally undetectable until the playtest. Process lesson recorded in the Sprint 17 retro action items.

## Files Touched This Session

- This file (new playtest report only).

## Verdict

**S17-M6: CLOSED.** Multi-biome progression chain validated end-to-end. The Sprint 16 content drop (5 biomes + 2 progression gates) is now actually playable past Forest Reach.

## Notes

- Light-touch sign-off matches Sprint 14 playtest-06/07 and Sprint 15 playtest-08 pattern. Playtest-driven closure rule was the right tool — the human-eye signal "it works great" is the load-bearing sign-off; no replay-script substitute would have been more rigorous.
- The bug PR #90 fixed (Sprint 17 S17-M6 surfaced it; Sprint 16 shipped the broken state) is the canonical example for the project memory's `feedback_playtest_driven_closure` lesson: 2190 unit + integration tests passed with 100% green while a load-bearing-for-the-player feature was silently broken across half the game's content. The playtest caught what no automated suite could.
