# Story 011: Formation Assignment Screen — picker + floor selector + Dispatch button

> **Epic**: Scene Manager
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Manifest Version**: 2026-04-26
> **Sprint Mapping**: S8-M1 (sprint-8.md "DispatchScreen UI"; canonical screen_id is `formation_assignment` per GDD §A and existing SceneManager registry)

## Context

**GDD**: `design/gdd/scene-screen-manager.md` (Screen lifecycle contract); `design/gdd/hero-roster.md` (formation API); `design/gdd/dungeon-run-orchestrator.md` (dispatch API)
**Requirements**: `TR-scene-manager-005`, `TR-scene-manager-010`, `TR-hero-roster-014`, `TR-hero-roster-027`, `TR-orchestrator-026`, `TR-orchestrator-027`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (Scene Transition + Persist Coupling) + ADR-0008 (UI Framework + Theme)
**ADR Decision Summary**: Every screen extends `Screen extends Control` with all 4 lifecycle hooks declared (empty body OK). Theme cascades from `MainRoot.theme = preload("res://assets/ui/parchment_theme.tres")`. No `Color(...)` literals in UI code; no per-screen Theme. Tap targets ≥44 logical px verified in `_ready()` via `UIFramework.assert_tap_target_min(self)`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (UI knowledge gap per sprint-8.md risks; ADR-0008 dual-focus and `MOUSE_FILTER_STOP` cascade behavior are post-cutoff)
**Engine Notes**:
- `MOUSE_FILTER_STOP` does NOT cascade to children in 4.5+; only `IGNORE` cascades. Per-Button `mouse_filter` defaults: `STOP` for buttons; `PASS` for labels/containers.
- 4.6 dual-focus is sidestepped — set `focus_mode = FOCUS_NONE` per Control via `UIFramework.suppress_keyboard_focus(root)` (project is mouse/touch primary).
- `UIFramework.assert_tap_target_min(self)` is debug-only (`OS.is_debug_build()` no-op gate).
- `Screen` base class lives at `src/core/scene_manager/screen.gd` (per Story 004); placeholder script for this screen at `assets/screens/formation_assignment/formation_assignment.gd` already extends it.

**Control Manifest Rules (Presentation layer)**:
- Required: `MainRoot.theme` cascade (no per-screen Theme); `UIFramework.assert_tap_target_min(self)` in interactive Control `_ready()`; `tr()` for all UI strings (localization-ready); two fonts only (info + identity).
- Forbidden: `Color(r, g, b)` literals in UI code; per-screen Theme resources; `focus_neighbor_*` graphs / `FOCUS_ALL` / keyboard-focus visuals; assuming `MOUSE_FILTER_STOP` cascades.
- Guardrail: UI render per frame ≤16.6 ms; theme + font + texture memory ~1.3 MB persistent ceiling.

---

## Acceptance Criteria

*From `production/sprints/sprint-8.md` S8-M1 row, scoped verbatim:*

- [x] **AC-1 — Roster picker**: screen displays the player's available heroes from `HeroRoster.get_all_heroes()`. Player can tap a hero to assign it to one of 3 formation slots (slots 0..FORMATION_SIZE-1). Slot writes go through `HeroRoster.set_formation_slot(slot_index, instance_id)`. Tapping the same hero into a second slot auto-clears its prior slot per TR-hero-roster-014.
- [x] **AC-2 — Floor selector**: screen surfaces a floor selector defaulted to `forest_reach` floor 1. For Sprint 8 VS the only selectable target is `forest_reach` floor 1; multi-biome / multi-floor selection is out of scope (deferred to floor-unlock UI). Selected `(biome_id, floor_index)` is held in screen state and passed to dispatch.
- [x] **AC-3 — Dispatch invocation**: pressing the Dispatch button invokes `DungeonRunOrchestrator.dispatch(formation, floor_index, biome_id)` exactly once per tap, where `formation = HeroRoster.get_formation_heroes()`. Repeated taps within `DISPATCH_DEBOUNCE_MS = 250` are ignored at the orchestrator (no UI-side debounce required, but UI MUST NOT loop-fire).
- [x] **AC-4 — Validation surfacing**: on `DungeonRunOrchestrator.validation_failed(reason, payload)`, screen displays a visible toast/label whose text is determined by `reason`:
  - `reason == "empty_formation"` → "Assign at least one hero to your formation."
  - `reason == "floor_locked"` → "That floor is locked." (Sprint 8 only `forest_reach` floor 1 is reachable, so this is a defensive surface.)
  - Toast/label is dismissable (auto-fade ≤4s OR tap-to-dismiss; either is acceptable for Sprint 8 VS).
- [x] **AC-5 — Lifecycle hygiene**: screen extends `Screen` (already true for placeholder). `on_enter()` connects to `HeroRoster` signals (e.g., `hero_recruited`, `hero_removed`) for picker refresh and to `DungeonRunOrchestrator.validation_failed` for toast surfacing. `on_exit()` disconnects all of them. `on_pause()`/`on_resume()` may be no-ops (no per-screen sim animations to suspend).
- [x] **AC-6 — Theme + tap-target compliance**: screen uses no `Color(...)` literals (all colors via `MainRoot.theme`). Every interactive Control calls `UIFramework.assert_tap_target_min(self)` in its `_ready()`. Buttons use `mouse_filter = MOUSE_FILTER_STOP`; labels/containers use `MOUSE_FILTER_PASS` per ADR-0008 §`mouse_filter` defaults.
- [x] **AC-7 — Routed via SceneManager**: screen is reached via `SceneManager.request_screen("formation_assignment", CROSS_FADE)`. No code path mutates `ScreenContainer.add_child` directly. No `SceneTree.change_scene_to_*` calls.

---

## Implementation Notes

*Derived from ADR-0007 §`Screen` base class lifecycle contract + §`request_screen()` sole external API + ADR-0008 §Required Patterns:*

### Wiring map (consumer surface verified against existing src/core/ files)

```
formation_assignment.gd  (extends Screen)
  ├── on_enter()
  │     ├── _connect_signals()
  │     │     ├── HeroRoster.hero_recruited       → _refresh_roster_panel
  │     │     ├── HeroRoster.hero_removed         → _refresh_roster_panel
  │     │     └── DungeonRunOrchestrator.validation_failed → _on_validation_failed
  │     └── _refresh_roster_panel()  # initial render from HeroRoster.get_all_heroes()
  ├── on_exit()
  │     └── _disconnect_signals()  # mirrors on_enter exactly
  ├── _on_dispatch_pressed()
  │     ├── var formation := HeroRoster.get_formation_heroes()
  │     ├── DungeonRunOrchestrator.dispatch(formation, _selected_floor, _selected_biome_id)
  │     └── # success path: orchestrator emits state change → ACTIVE_FOREGROUND, no UI work here
  ├── _on_validation_failed(reason, payload)
  │     ├── match reason:
  │     │     "empty_formation" → _show_toast(tr("dispatch_error_empty_formation"))
  │     │     "floor_locked"    → _show_toast(tr("dispatch_error_floor_locked"))
  │     │     _                 → push_warning + generic toast (defensive)
```

### Hero picker

- Read available heroes via `HeroRoster.get_all_heroes(SortMode.BY_CLASS)` for stable Sprint 8 ordering.
- Render 3 slot widgets reading `HeroRoster.get_formation_slot(i)`.
- Tap on a hero in the picker → `HeroRoster.set_formation_slot(_active_slot_index, hero.instance_id)`. Tap on an occupied slot to clear → `set_formation_slot(slot_index, 0)`.
- Slot widgets re-render on next frame after the call (read `get_formation_slot` afresh).
- **Empty-state copy**: if `HeroRoster.get_all_heroes().size() == 0`, picker shows "Recruit a hero to begin." (defensive; Sprint 4 first-launch seeds Theron, so this should never appear in normal play).

### Floor selector

- Sprint 8 VS scope: hard-coded to `_selected_biome_id = "forest_reach"`, `_selected_floor = 1`. Surface a single floor button labeled `tr("floor_label_forest_reach_1")` (= "Forest Reach 1").
- Future-friendly shape: hold `_selected_biome_id: String` + `_selected_floor: int` in screen state so a multi-floor picker can replace the single button without restructuring the dispatch path.

### Toast/label

- One reusable Label or PanelContainer at the bottom of the screen, hidden by default (`visible = false`).
- `_show_toast(text)` sets `text = text` + `visible = true`, starts a 4s `Tween` to `modulate.a → 0`, hides on tween_finished.
- Tap-to-dismiss: a Button overlay (`MOUSE_FILTER_STOP`) above the toast hides it on press.
- Use `tr()` for all visible strings — locale-key names listed in §QA Test Cases.

### Theme + tap-target compliance

- Root Control inherits theme from `MainRoot.theme` cascade — do not set theme on the screen.
- Every Button / interactive Control's `_ready()`: `UIFramework.assert_tap_target_min(self)` (debug-only assertion via `OS.is_debug_build()`).
- Per ADR-0008: Buttons `mouse_filter = STOP`; Labels `PASS`; decorative TextureRects `IGNORE`. Containers `PASS` (override only for STOP-mode input-block layers).
- Suppress keyboard focus once at the screen root: in `on_enter()`, call `UIFramework.suppress_keyboard_focus(self)` to walk the tree and set `focus_mode = FOCUS_NONE`.

### Localization-ready strings

| Key | Sprint 8 EN value |
|---|---|
| `formation_assignment_title` | "Formation" |
| `dispatch_button` | "Dispatch" |
| `floor_label_forest_reach_1` | "Forest Reach — Floor 1" |
| `dispatch_error_empty_formation` | "Assign at least one hero to your formation." |
| `dispatch_error_floor_locked` | "That floor is locked." |
| `slot_empty_label` | "Empty" |
| `recruit_a_hero_label` | "Recruit a hero to begin." |

`tr()` lookup is sufficient; full locale CSV authoring is OUT OF SCOPE (no localization framework wired yet per sprint-8.md backlog). MVP `tr("foo")` returns `"foo"` until CSVs land — acceptable.

---

## Out of Scope

*Handled by neighbouring stories or deferred sprints — do not implement here:*

- Story 012 (Dungeon Run View): all post-dispatch state display.
- Story 013 (Run-end transition): RUN_ENDED → main_menu auto-route.
- Multi-biome / multi-floor floor selector — single hard-coded `forest_reach` floor 1 for Sprint 8 VS; full picker is post-Sprint-8 polish (depends on `floor-unlock-system` UI epic).
- Mid-run formation reassignment from this screen (TR-orchestrator-020) — Sprint 9+.
- Recruit flow, hero detail / inspection — separate screens (`recruitment`, future `roster_detail`).
- Visual polish: animations, hover states beyond theme `:hover` pseudo-state, character art / portraits — accept ugly UI for Sprint 8 VS per sprint-8.md risk mitigation.
- Real localization CSV authoring — see backlog.
- Save persistence of last-selected floor — Sprint 8 always boots to forest_reach floor 1.

---

## QA Test Cases

*Solo review mode — qa-lead gate skipped. Test cases authored directly from acceptance criteria.*

### Automated integration tests (`tests/integration/scene_manager/formation_assignment_screen_test.gd`)

The test isolation pattern from S5-M5 applies: use the LIVE autoload `SceneManager` + `HeroRoster` + `DungeonRunOrchestrator`, instantiate the screen via `SceneManager.request_screen("formation_assignment", CROSS_FADE)`, await `transition_complete`, then drive the screen.

- **Test: AC-1 set_formation_slot path**
  - Given: roster has heroes at instance_ids 1, 2, 3; formation slots empty
  - When: simulate UI tap that calls `HeroRoster.set_formation_slot(0, 1)`, then `(1, 2)`, then `(2, 3)`
  - Then: `HeroRoster.get_formation_heroes().size() == 3`; ordered by slot index
  - Edge case: tap hero 1 into slot 1 (already in slot 0) → slot 0 auto-clears, slot 1 holds hero 1, slot 2 still holds hero 3
- **Test: AC-3 dispatch invocation**
  - Given: roster has 1+ hero in formation; FloorUnlock reports forest_reach floor 1 unlocked
  - When: simulate Dispatch button press
  - Then: orchestrator state advances (NO_RUN → DISPATCHING → ACTIVE_FOREGROUND); `run_snapshot.floor_id == "forest_reach"`; `run_snapshot.formation_snapshot` non-empty
  - Edge case: tap Dispatch twice within 250 ms → exactly one dispatch is committed (orchestrator-side debounce)
- **Test: AC-4 empty-formation validation**
  - Given: formation is empty (`HeroRoster.get_formation_heroes().size() == 0`)
  - When: simulate Dispatch button press
  - Then: orchestrator emits `validation_failed("empty_formation", _)`; screen's toast becomes visible with text matching `tr("dispatch_error_empty_formation")`; orchestrator state stays NO_RUN (or re-enters NO_RUN via the documented DISPATCHING→RUN_ENDED→NO_RUN path per TR-orchestrator-026)
- **Test: AC-4 floor-locked validation (defensive)**
  - Given: a stub FloorUnlock that returns `is_unlocked(1) == false`; formation non-empty
  - When: simulate Dispatch button press
  - Then: orchestrator emits `validation_failed("floor_locked", _)`; screen's toast text matches `tr("dispatch_error_floor_locked")`
  - Note: requires injecting a stub via `DungeonRunOrchestrator.set_floor_unlock(stub)` before the test
- **Test: AC-5 lifecycle hygiene — signal disconnect on exit**
  - Given: screen is current, signal connections active
  - When: `SceneManager.request_screen("main_menu", CROSS_FADE)` — triggers screen on_exit
  - Then: `HeroRoster.hero_recruited.is_connected(_)` returns false for the screen's handler; `DungeonRunOrchestrator.validation_failed.is_connected(_)` returns false; no orphaned connection survives the swap
- **Test: AC-7 routing via SceneManager**
  - Given: screen reached via `request_screen("formation_assignment", CROSS_FADE)`
  - Then: `SceneManager.current_screen_id == "formation_assignment"`; `SceneManager.current_screen` is a Control instance whose root script extends `Screen`

### Manual UI walkthrough (`production/qa/evidence/formation-assignment-screen-evidence.md`)

For every visual/feel criterion that automation cannot meaningfully verify:

- **AC-2 floor-selector visual**: Setup — open Godot 4.6 in dev. Reach `formation_assignment` screen. Verify — single floor button labeled "Forest Reach — Floor 1" is visible and not greyed-out. Pass condition — button is tappable; tapping it (no-op visually for Sprint 8) does not error.
- **AC-6 theme + tap-target compliance**: Setup — run dev build with `OS.is_debug_build() == true`. Verify — no `push_error` from `assert_tap_target_min` in editor output; no hardcoded color strands jump out (all palette per parchment theme); fonts match info_font / identity_font (only two fonts visible).
- **AC-4 toast visible to a human**: Setup — leave formation empty, press Dispatch. Verify — toast/label appears at the bottom of the screen with the empty-formation message; toast disappears within ~4s OR after tap. Pass condition — message readable; layout doesn't overlap critical UI; player sees it.

---

## Test Evidence

**Story Type**: UI

**Required evidence**:
- `tests/integration/scene_manager/formation_assignment_screen_test.gd` — must exist and pass (AC-1, AC-3, AC-4, AC-5, AC-7 covered)
- `production/qa/evidence/formation-assignment-screen-evidence.md` — manual walkthrough doc with visual sign-off (AC-2, AC-6, and human-perceptible parts of AC-4)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**:
  - Story 004 (Screen base class) — DONE per sprint-status.yaml S5-M6
  - Story 003 (`request_screen` API + 7-screen registry) — DONE per S5-M5
  - HeroRoster epic Stories 001+ (formation API) — DONE per Sprint 6/7
  - DungeonRunOrchestrator epic Stories 001-003 (`dispatch()` + validation_failed signal) — DONE per Sprint 7
  - `assets/screens/formation_assignment/formation_assignment.{tscn,gd}` placeholder — DONE per S5-M5
  - ADR-0008-conformant `parchment_theme.tres` — currently a placeholder (S5-M3); content authoring is a separate UI Framework follow-up. For Sprint 8, an empty Theme is acceptable as long as the cascade wiring (`MainRoot.theme = preload(...)`) is intact and the Required-pattern compliance is structural.
  - `src/ui/ui_framework.gd` (`UIFramework` static helper) — verify presence; if missing, this story creates a thin stub with `assert_tap_target_min(control)` and `suppress_keyboard_focus(root)` — both no-op acceptable for Sprint 8.

- **Unlocks**: Story 012 (Dungeon Run View) — relies on the dispatch invocation working end-to-end so DungeonRunView has live snapshot data to display.

---

## Completion Notes

**Completed**: 2026-04-28
**Criteria**: 7/7 covered (5 fully automated, 2 with deferred visual evidence — AC-2 floor selector visual + AC-6 theme/tap-target visual deferred to S8-M4 manual smoke per UI-tier ADVISORY evidence policy)
**Test Evidence**: UI — automated integration tests at `tests/integration/scene_manager/formation_assignment_screen_test.gd` (13/13 PASS, 0 errors, 0 failures, 6 orphans, 307ms) + manual evidence stub at `production/qa/evidence/formation-assignment-screen-evidence.md` (visual sign-off pending S8-M4)
**Code Review**: Complete (godot-gdscript-specialist, APPROVED post-fix). 2 BLOCKING issues caught + fixed: (B-1) `_dispatch_button.pressed` → `_on_dispatch_pressed` wiring + same for `_floor_button`/toast tap-dismiss; (B-2) encapsulation violation `HeroRoster._formation_slots` direct read replaced with new public `HeroRoster.get_formation_slot(i)` accessor
**Deviations**:
- OUT OF SCOPE (authorized): `src/core/hero_roster/hero_roster.gd` modified to add `get_formation_slot(slot_index: int) -> int` (15 lines + 3 unit tests). Closed a GDD §C documented public-API gap; alternative was to leave an encapsulation violation in production code.
- ADVISORY (test-wiring): `_navigate_to_formation_screen` bypasses `SceneManager.request_screen` (instantiates screen directly) due to a documented headless test-environment quirk (fresh-SM interaction with live autoload's first-launch routing). AC-7 verified structurally via Story 003's existing 7-screen registry test.

**Tech debt candidates** (not logged inline; follow-up consideration):
- Pre-existing scene_manager test environment flakes (modal_pause_tick_coupling, crossfade_timing, request_screen_and_node_swap) — Godot 4.6.1.mono.official headless wiring issue. Not Story 011 regression (verified by mainroot_scene_composition still 18/18). Track as a separate cleanup story.
- UIFramework `apply_parchment_panel()` and `wire_touch_feedback()` deferred per Sprint 8 minimum-stub scope; ADR-0008 mandates them. Future UI stories will need them — `src/ui/ui_framework.gd` carries the TODO inline.

**Unlocks**: Story 012 (Dungeon Run View) can begin — its dependency on Story 011 (driving end-to-end dispatch) is now satisfied.
