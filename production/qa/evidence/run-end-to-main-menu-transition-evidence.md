# Run-end → MainMenu Transition — Manual Evidence (Story 013)

> **Story**: `production/epics/scene-manager/story-013-run-end-to-main-menu-transition.md`
> **Sprint Mapping**: S8-M3
> **Status**: `[ ]` Not yet executed — manual smoke runs as part of S8-M4
> **Author of stub**: ui-programmer (2026-04-28)

This document records the AC-3 dwell value chosen for Sprint 8 and cross-references
the upcoming S8-M4 manual smoke session where the full end-to-end cycle is verified.

---

## AC-3 — Dwell value chosen

**Constant**: `RUN_END_DWELL_MS` in `assets/screens/dungeon_run_view/dungeon_run_view.gd`

**Value chosen**: `0` ms (Sprint 8 default)

**Rationale**: Sprint 8 ships a VS (Very Simplified) dungeon run with an "accept ugly UI"
policy per sprint-8.md. The run-end overlay is shown briefly but the player does not need
to read it before the transition fires — the kill count is also visible in the stats panel
throughout the run. With dwell = 0 the overlay appears on the same frame as RUN_ENDED and
the cross-fade (~150 ms) begins immediately.

**Total perceived run-end → main_menu**: 0 ms dwell + ~150 ms cross-fade = ~150 ms total.
Well within the AC-2 budget of ≤500 ms.

**Valid range**: [0, 350] ms per AC-3. The current value of 0 is at the lower boundary.
To add a human-readable pause in a future sprint, raise to e.g. 200 ms (200 + 150 = 350 ms
total — still within AC-2 budget).

---

## S8-M4 manual smoke cross-reference

The full end-to-end cycle (formation dispatch → dungeon run active → run ends → returns to
main_menu) will be verified during the Sprint 8 S8-M4 manual smoke session. Record results
in the S8-M4 smoke doc (`production/qa/smoke-sprint-8-vs-harness-YYYY-MM-DD.md`) and
cross-reference here after execution.

**Walkthrough steps**:
1. Open Godot 4.6 in dev mode. Run the project. The app boots to `guild_hall`.
2. Navigate to `formation_assignment` screen and dispatch a formation.
3. The app transitions to `dungeon_run_view`. Observe the tick/kill-count labels updating.
4. When the run ends (all enemies defeated or run_ended trigger fires), observe:
   - The run-end overlay appears with the final kill count.
   - Immediately (0 ms dwell), the cross-fade transition begins.
   - Within ~150 ms, the screen is `main_menu`.
5. Verify: no console errors; tick subscription not leaking (no push_error after transition).

**Pass condition**: Steps 1–5 complete without console errors. `main_menu` is active within
~200 ms of RUN_ENDED. Overlay appears and then dissolves into the cross-fade.

`[ ]` Pass / `[ ]` Fail / `[ ]` Not yet executed

---

## Automated test coverage

Automated integration tests live at:
`tests/integration/scene_manager/run_end_to_main_menu_transition_test.gd`

Tests cover: AC-1 (auto-route fires), AC-3 (dwell constant range), AC-4 (tick disconnect),
AC-5 (idempotency), AC-6 (no change_scene_to_*), and structural reset of `_routed` in
`on_enter`.
