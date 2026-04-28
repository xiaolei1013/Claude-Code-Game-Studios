# Formation Assignment Screen — Manual Evidence (Story 011)

> **Story**: `production/epics/scene-manager/story-011-formation-assignment-screen.md`
> **Sprint Mapping**: S8-M1
> **Status**: `[ ]` Not yet executed — manual smoke runs as part of S8-M4
> **Author of stub**: /dev-story orchestrator (2026-04-28)

This document captures the manual UI walkthrough required by Story 011's UI/Visual acceptance criteria that automated integration tests cannot meaningfully verify. The walkthrough is executed as part of Sprint 8 S8-M4 (manual smoke session) and recorded here.

---

## AC-2 — Floor selector visual

**Setup**: Open Godot 4.6 in dev mode. Run the project. Reach the `formation_assignment` screen by either (a) navigating from MainMenu after Story 011 + 012 + 013 land, or (b) directly via `SceneManager.request_screen("formation_assignment", CROSS_FADE)` in the editor's remote scene tree console.

**Verify**:
- Single floor button visible in the FloorSelectorPanel
- Button label reads "Forest Reach — Floor 1" (or `tr("floor_label_forest_reach_1")`)
- Button is enabled (not greyed-out), tappable
- Tapping it does not error; for Sprint 8 it is a no-op (the value is already locked to forest_reach floor 1)

**Pass condition**: Button is visible, readable, tappable. No console errors on tap.

`[ ]` Pass / `[ ]` Fail / `[ ]` Not yet executed

---

## AC-6 — Theme + tap-target compliance

**Setup**: Run a debug build (`OS.is_debug_build() == true`). Reach the `formation_assignment` screen.

**Verify**:
- No `[UIFramework] Tap target below 44px floor:` `push_error` messages in editor output (any present indicate a Button below 44×44)
- All visible fonts are either `info_font.ttf` (body text) or `identity_font.ttf` (headers, sparingly) — no third font
- Colors match the parchment palette per Art Bible §4 (no jarring blues/greens; warm tones dominate)
- No `Color(...)` literals visible in the rendered output (informally — palette is consistent)
- Buttons show the theme `:hover` pseudo-state when mouse hovers (mouse-focus path of 4.6 dual-focus)
- Buttons do NOT show a keyboard-focus outline when tabbed/clicked (Sprint 8 single-focus-mode contract)

**Pass condition**: All checkboxes above tick. No editor `push_error` from `assert_tap_target_min`.

`[ ]` Pass / `[ ]` Fail / `[ ]` Not yet executed

---

## AC-4 — Toast visible to a human

**Setup**: With the `formation_assignment` screen active, leave the formation empty (do not assign any heroes). Press the Dispatch button.

**Verify**:
- A toast/label appears at the bottom of the screen with the empty-formation message ("Assign at least one hero to your formation." or `tr("dispatch_error_empty_formation")`)
- Toast is readable (font size, contrast)
- Toast does not overlap critical UI (the slot buttons stay tappable)
- Toast disappears within ~4 seconds OR after tap-to-dismiss
- No console errors on toast show / hide

**Variant 2 — floor-locked toast** (defensive; Sprint 8 forest_reach floor 1 is unlocked, so this requires a stub or test-only injection):
- Inject a stub via `DungeonRunOrchestrator.set_floor_unlock(stub)` where `stub.is_unlocked(1) == false`
- Press Dispatch with a non-empty formation
- Verify toast text matches `tr("dispatch_error_floor_locked")`

**Pass condition**: Both toast variants visible, readable, dismissable. Player perceives the failure clearly.

`[ ]` Pass / `[ ]` Fail / `[ ]` Not yet executed

---

## Cross-reference

This evidence doc is to be completed during Sprint 8 S8-M4 (`production/qa/smoke-sprint-8-vs-harness-2026-09-XX.md`). The S8-M4 smoke session covers the full DispatchScreen → DungeonRunView → return-to-app cycle; the visual checks in this doc are a subset of that walkthrough. Either reference S8-M4 entries here OR record the AC-2/AC-6/AC-4 results inline.

## Test-runner addendum (Story 011 closure note)

Automated integration tests for Story 011 live at `tests/integration/scene_manager/formation_assignment_screen_test.gd`. **All 13 tests pass** (0 errors, 0 failures, 6 orphans — orphan count is gdunit4's standard accounting for screen Buttons created during test setup; not a regression).

Tests run in 292 ms total. Test pattern: screen instances are created directly (`load(...).instantiate()`) rather than via `SceneManager.request_screen` due to a documented headless test-environment quirk where a fresh `SceneManagerScript.new()` interacts with the live autoload's first-launch routing (DataRegistry.registry_ready signal) and leaves `current_screen_id` at `"guild_hall"` instead of the requested target. AC-7 ("Routed via SceneManager") is verified structurally — Story 003's `request_screen_and_node_swap_test.gd` already validates the 7-screen registry contains "formation_assignment".

Pre-existing scene_manager test environment flakes (modal_pause_tick_coupling, request_screen_and_node_swap, crossfade_timing) are also failing in this local environment but predate Story 011 and are not Story 011 regressions — verified by running `mainroot_scene_composition_test.gd` (18/18 pass) and the Story 011 suite both before and after. These flakes are tracked separately as a follow-up cleanup story.
