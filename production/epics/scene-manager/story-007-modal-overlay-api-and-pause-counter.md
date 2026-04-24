# Story 007: Modal overlay API (`push_overlay` / `pop_overlay`) + counter-based `_modal_pause_count`

> **Epic**: scene-manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/scene-screen-manager.md`
**Requirements**: TR-scene-manager-007, TR-scene-manager-018
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary — §Modal overlay API + §`get_tree().paused` ↔ Time System sim-clock pause coupling + Risks counter-based pause row) + ADR-0005 (cross-system pause contract: TickSystem's tick loop runs under `PROCESS_MODE_ALWAYS` + explicit `if get_tree().paused: return` guard)
**ADR Decision Summary**: Modal overlays use `OverlayLayer` and do NOT replace `current_screen`. `push_overlay(overlay_id, pause_on_open=true)` instantiates the overlay into `OverlayLayer`, calls `current_screen.on_pause()`, sets state to PAUSED; if `pause_on_open == true`, increments `_modal_pause_count` and sets `get_tree().paused = true`. `pop_overlay(overlay_id)` reverses: decrement counter; if count reaches zero, unpause; call `on_resume()`. Counter-based pause is a load-bearing invariant — it prevents the race where a Settings-close + immediate Settings-open would leave the tree paused with no overlay visible (ADR-0007 Risks row 7: High impact "entire game frozen — player perceives crash").

**Engine**: Godot 4.6 | **Risk**: MEDIUM-HIGH
**Engine Notes**: `get_tree().paused = true` freezes nodes with `PROCESS_MODE_PAUSABLE`. `OverlayLayer.PROCESS_MODE_ALWAYS` means overlays continue to animate. `PersistentHUDLayer.PROCESS_MODE_ALWAYS` means HUD tweens continue. Only `ScreenContainer.PROCESS_MODE_PAUSABLE` children (the actual game screens) freeze — which is the desired UI↔Sim separation per AC H-08. `MOUSE_FILTER_STOP` does NOT cascade to children in 4.5+ (ADR-0008 LOAD-BEARING note) — if the overlay wants to dim-and-block the underlying screen, it must place a full-screen `Control` with `MOUSE_FILTER_STOP` as its first child. The `get_tree().paused` write is a ForbiddenPattern for code OUTSIDE SceneManager's modal API (`get_tree_paused_external_write`) — this story owns the only legitimate write site.

**Control Manifest Rules (Foundation Layer, SceneManager)**:
- **Required**: Modal overlay with `pause_on_open=true` sets `get_tree().paused = true`; close sets `false`. TickSystem honors via `PROCESS_MODE_ALWAYS` + explicit `if get_tree().paused: return` guard. — ADR-0007
- **Required**: Pause uses counter-based `_modal_pause_count` to prevent race-condition stuck-pause. — ADR-0007
- **Required**: `push_overlay(overlay_id, pause_on_open)` / `pop_overlay(overlay_id)` for modals. — ADR-0007
- **Forbidden**: Never add children to `OverlayLayer` directly from outside SceneManager — use `push_overlay` / `pop_overlay`. — ADR-0007
- **Forbidden**: Never write `get_tree().paused = true/false` from outside SceneManager modal API. — ADR-0007
- **Forbidden**: Never assume `MOUSE_FILTER_STOP` cascades to children — only `MOUSE_FILTER_IGNORE` cascades in 4.5+. — ADR-0007, ADR-0008

---

## Acceptance Criteria

*Verbatim from tr-registry:*

- [ ] TR-scene-manager-007: "Modal overlays use OverlayLayer; do NOT replace current_screen; on_pause/on_resume lifecycle fires"
- [ ] TR-scene-manager-018: "get_tree().paused = true during PAUSED; Time System uses PROCESS_MODE_ALWAYS + if paused:return guard"

*Verbatim from GDD §H:*

- [ ] **AC H-08 (BLOCKING, Integration)**: Given manager IDLE with a sim-clock-dependent screen active, when a modal overlay (Settings) is pushed via overlay API and manager → PAUSED, then Time System sim clock pause fires (tick accumulation stops); UI animations and tweens in `PersistentHUDLayer` and `OverlayLayer` continue running; no frame stutter from pause; on overlay dismiss, sim clock resumes from exact tick paused at with no tick debt or skip.

*Additional from ADR-0007 Risks Note 7 (counter invariant):*

- [ ] `_modal_pause_count` never goes negative (stray `pop_overlay` when count is 0 logs `push_warning` and no-ops)
- [ ] Rapid close/open sequences ending with an open overlay leave the tree paused; ending with no overlay leave the tree unpaused — no stuck-pause under any interleaving

---

## Implementation Notes

*Derived from ADR-0007 §Modal overlay API + §`get_tree().paused` ↔ Time System sim-clock pause coupling + Risks row 7:*

- Add internal state to `SceneManager`:
  ```gdscript
  var _modal_pause_count: int = 0               # counter; tree paused iff > 0
  var _active_overlays: Dictionary = {}         # overlay_id -> Control instance
  var _overlay_registry: Dictionary = {}        # overlay_id -> PackedScene (loaded at init)
  var _queued_modal: Dictionary = {}            # held if a modal push arrives during TRANSITIONING
  ```
- `push_overlay` body:
  ```gdscript
  func push_overlay(overlay_id: String, pause_on_open: bool = true) -> void:
      if state == State.TRANSITIONING:
          _queued_modal = {"overlay_id": overlay_id, "pause_on_open": pause_on_open}
          return
      if state == State.UNINITIALIZED:
          push_warning("[SceneManager] push_overlay before registry_ready — ignored")
          return
      assert(not _active_overlays.has(overlay_id),
          "Overlay '%s' already active" % overlay_id)
      var packed: PackedScene = _overlay_registry.get(overlay_id)
      assert(packed != null, "Unknown overlay_id '%s'" % overlay_id)
      var overlay: Control = packed.instantiate()
      _overlay_layer.add_child(overlay)
      _active_overlays[overlay_id] = overlay
      if current_screen:
          current_screen.on_pause()
      state = State.PAUSED
      if pause_on_open:
          _modal_pause_count += 1
          get_tree().paused = (_modal_pause_count > 0)
  ```
- `pop_overlay` body:
  ```gdscript
  func pop_overlay(overlay_id: String) -> void:
      if not _active_overlays.has(overlay_id):
          push_warning("[SceneManager] pop_overlay '%s' — not active; no-op" % overlay_id)
          return
      var overlay: Control = _active_overlays[overlay_id]
      _active_overlays.erase(overlay_id)
      var was_pausing := overlay.get_meta("scene_manager_pause_on_open", true)
      overlay.queue_free()
      if was_pausing:
          _modal_pause_count = maxi(0, _modal_pause_count - 1)
          get_tree().paused = (_modal_pause_count > 0)
      if _active_overlays.is_empty():
          state = State.IDLE
          if current_screen:
              current_screen.on_resume()
      # If state stays PAUSED (other overlays remain), on_resume is NOT called yet
  ```
- Store `pause_on_open` as metadata on the overlay instance (`overlay.set_meta("scene_manager_pause_on_open", pause_on_open)`) so `pop_overlay` can reverse exactly what `push_overlay` did — avoids the developer passing different `pause_on_open` at pop time silently corrupting the counter.
- Counter invariant — the bullet-proof-against-race pattern from ADR-0007 Risks row 7:
  ```gdscript
  # Pause state is derived from the counter, not directly written by any code path.
  # Helper to centralize:
  func _apply_pause_state() -> void:
      get_tree().paused = (_modal_pause_count > 0)
  ```
- Ensure Settings overlay close is the first exercise: test case "Settings open → Settings close" must end with `get_tree().paused == false AND _modal_pause_count == 0`. Interleaved test case "Settings open → immediate Settings open (duplicate)" — the `assert` on duplicate push ensures we don't silently double-increment. Test case "rapid Settings open + close in same frame" must settle back to 0 via the `call_deferred`/frame-boundary semantics.
- Defensive: log a `push_error` if `_modal_pause_count < 0` is ever reached (should be impossible via `maxi(0, ...)`); also log if `get_tree().paused == true` but `_modal_pause_count == 0` on frame-start (would indicate external tampering — a canary for the ForbiddenPattern).
- `_queued_modal` drains in `_on_transition_finished` AFTER a pending `_queued_request` drains (per ADR-0007 Risks row 4 "Queued modals execute in IDLE regardless of save_failed outcome"). Story 010 verifies the queue-with-max-1 edge cases for modals too.

---

## Out of Scope

- Story 005: PUSH_MODAL tween timing (this story reuses the PUSH_MODAL transition type for the slide-down visual; the tween itself lives in Story 005)
- Story 008: `scene_boundary_persist` save-failure modal — uses this story's `push_overlay` helper but the save-failed policy is Story 008's concern
- Story 009: `reduce_motion` clamp on modal open/close slide — via Story 005's timing knobs
- Story 010: Queue-with-max-1 edge cases for modals
- Overlay authoring (Settings screen, Hero Detail overlay, etc.) — owned by Presentation-layer epics

---

## QA Test Cases

- **TR-scene-manager-007**: Overlay pushes onto OverlayLayer, not ScreenContainer
  - **Given**: SceneManager in IDLE; `current_screen` is screen A
  - **When**: `push_overlay("settings", true)` called
  - **Then**: `OverlayLayer.get_child_count() == 1`; `ScreenContainer.get_child_count() == 1` (still A); `current_screen` unchanged; `A.on_pause` was called exactly once; state == PAUSED
  - **Edge cases**: a `push_overlay` on a non-registered `overlay_id` asserts-fails (not silent)

- **TR-scene-manager-018 / AC H-08 (BLOCKING)**: `get_tree().paused` coupling + counter
  - **Given**: SceneManager IDLE with a screen active; TickSystem is accumulating ticks
  - **When**: `push_overlay("settings", true)` called; test samples `get_tree().paused` and `TickSystem.current_tick` over 2 frames
  - **Then**: `_modal_pause_count == 1`; `get_tree().paused == true`; `TickSystem.current_tick` does not advance between samples (TickSystem's tick loop honors the `if get_tree().paused: return` guard per ADR-0005). HUD layer tweens (on `PersistentHUDLayer`) continue running over the same 2 frames.
  - Then (on close): `pop_overlay("settings")` restores `_modal_pause_count == 0`, `get_tree().paused == false`; TickSystem resumes from the exact tick it was paused at (no debt, no skip; accumulator residual preserved per ADR-0005).
  - **Edge cases**: (1) `push_overlay("settings", true)` twice in rapid succession (blocked by the duplicate-assert) — test captures the assert. (2) Nested overlays: `push_overlay("settings", true) + push_overlay("confirm_save", true)` then `pop_overlay("confirm_save")` → `_modal_pause_count == 1`, `get_tree().paused == true`; then `pop_overlay("settings")` → `_modal_pause_count == 0`, `get_tree().paused == false`. (3) Mixed pause modes: `push_overlay("hero_detail", false)` (non-pausing) + `push_overlay("settings", true)` (pausing) — counter is 1, tree paused; pop hero_detail first → counter still 1, tree still paused; pop settings → counter 0, tree unpaused.

- **ADR-0007 Risks row 7**: `_modal_pause_count` never negative
  - **Given**: SceneManager IDLE; no overlays active; `_modal_pause_count == 0`
  - **When**: `pop_overlay("ghost_overlay")` called (stray pop — overlay never pushed)
  - **Then**: `push_warning` fires; `_modal_pause_count` still 0; `get_tree().paused == false`
  - **Edge cases**: try invoking `pop_overlay` 5× in a row with no active overlays — counter stays at 0

- **Lifecycle order on modal cycle**:
  - **Given**: screen A active; connect spies to `A.on_pause` and `A.on_resume`
  - **When**: `push_overlay("settings", true)` + `pop_overlay("settings")` back-to-back across 2 frames
  - **Then**: `A.on_pause` fired exactly once before `A.on_resume`; `on_resume` fired only after ALL overlays closed (state back to IDLE)
  - **Edge cases**: double-nested overlays — `on_pause` still fires only once on the outermost push; `on_resume` fires only on the outermost pop

---

## Test Evidence

**Story Type**: Logic (with Integration for the TickSystem coupling assertion)
**Required evidence**: `tests/unit/scene_manager/modal_overlay_counter_test.gd` for counter invariants + `tests/integration/scene_manager/modal_pause_tick_coupling_test.gd` for AC H-08.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (OverlayLayer exists), Story 002 (state enum), Story 004 (`Screen.on_pause` / `on_resume` declared)
- **Unlocks**: Story 008 (save-failure modal uses `push_overlay`), Story 009 (`reduce_motion` in Settings overlay reads/writes the flag)
