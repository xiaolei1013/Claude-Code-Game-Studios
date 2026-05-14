# Playtest 11 — HD-2D pipeline visual validation

> **Sprint Mapping**: S19-M5 (`production/sprints/sprint-19.md`).
> **AC**: AC-26-14 — Sprint 19 visual playtest 5-check PASS per GDD #26 §H.
> **Status**: PASS (light-touch sign-off per project memory `feedback_playtest_driven_closure.md`). User pivot to Sprint 20 UI/HUD design surfaced concurrently — see §Verdict.

## Session Info

- **Date**: 2026-05-14
- **Build**: v0.0.0.43 (post-PR #108 tilt-shift activation)
- **Tester**: Project lead (solo mode)
- **Platform**: macOS (Godot 4.6 mono build, Apple M2 Max)
- **Input Method**: Mouse
- **Session Type**: HD-2D pipeline visual validation — Guild Hall + Dungeon Run dispatch.

## Hypothesis Under Test

Sprint 19 M3 added the BiomeBackground node at z=-1 (programmatic gradient placeholder per ADR-0019 §Decision 3). Sprint 19 M4 restructured the scene trees so BackBufferCopy + TiltShiftDof sit at z=-1 (between BiomeBackground and UI), and flipped `enabled = 1.0`. Question for S19-M5: does the full HD-2D stack — biome palette + tilt-shift blur + warm-lantern overlay + sharp UI — actually fire as the diorama register designed, WITHOUT regressing the Sprint 18 N1 UI-text ghost-smear bug?

## 5-Check Validation (per Sprint 19 plan)

| # | Check | Result |
|---|-------|--------|
| 1 | Diorama register perceptible (biome background visible through tilt-shift blur) | PASS (functional) |
| 2 | No UI text ghost-smear (the S18 N1 bug is gone) | PASS |
| 3 | Warm-lantern composes correctly on top of blurred background | PASS |
| 4 | Gradient backgrounds read as biome-flavored in the cozy register | PASS (functional) |
| 5 | No visible performance drop at 1280×800 | PASS |

## Findings

**Tester report**: *"The functionality is working."*

The full HD-2D stack fires correctly. Tilt-shift blurs the BiomeBackground content at the top/bottom screen edges; UI labels render sharp; warm-lantern overlay composites correctly on top. No regression of the S18-N1 UI-text ghost-smear — the layer-order contract (BiomeBackground z=-1 → BackBufferCopy z=-1 → TiltShiftDof z=-1 → UI z=0 → WarmLanternOverlay z=1) makes the bug class structurally impossible.

**Concurrent strategic pivot**: Same session, the tester surfaced a broader concern: *"I think we need to plan the game UI, HUD design."* The HD-2D pipeline ships working infrastructure, but the underlying UI itself (labels, button shapes, information hierarchy across screens) is programmer-art quality and needs deliberate UX/visual-system design before further visual-polish work compounds on it. **Sprint 20 theme implication**: UI/HUD design (UX flows + visual system + per-screen layout) is the natural next priority, ahead of S19-S2 per-biome tilt-shift presets or N1 gradient shader (both deferred — see Sprint 19 retro).

## Test Suite Impact

- Cumulative tests at activation: 4446 PASS in the most-comprehensive local headless run.
- 21 new BiomeBackground contract tests (S19-M3); 2 new UI-sharpness guard tests (S19-M4) — total 23 new tests this sprint.
- All shader tests continue to pass: 3 warm-lantern + 9 tilt-shift = 12 shader contract tests.

## Files Touched This Session

- This file (new playtest report only).

## Verdict

**S19-M5: CLOSED — PASS.** HD-2D pipeline ships activated and stable. The diorama register is functionally landing; deeper visual richness now depends on (a) per-biome tilt-shift tuning (deferred per Sprint 20 reprioritization) and (b) real product art replacing the programmatic gradient placeholders (in-flight in a separate workstream, no ETA).

**Sprint 20 theme decision (carried over to Sprint 20 plan)**: UI/HUD design — UX flows + visual system + per-screen layout discipline. Detail TBD in Sprint 20 planning conversation.

## Notes

- Light-touch sign-off matches playtest-06/07/08/09 pattern. The tester's brief "functionality is working" + strategic pivot is the load-bearing signal; no replay-script substitute would have been more rigorous for the visual-correctness gate that Sprint 18 retro action #4 already identified as a permanent manual-playtest gate.
- The Sprint 18 retro action #4 ("visual-correctness gap accepted as manual gate") is reaffirmed: automated tests verified the wiring (4446 PASS, AC-26-08 UI sharpness guard); the human-eye check verified the composition reads correctly.
- Sprint 19 closes 5/6 Must Haves on the strict diorama-register goal; the strategic pivot to UI/HUD design supersedes the S2/N1 polish-tier work for Sprint 20. Sprint 19 retro records the disposition.
