# Story 003: `request_screen` sole external API + `ScreenContainer` node-swap + first-launch routing

> **Epic**: scene-manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/scene-screen-manager.md`
**Requirements**: TR-scene-manager-003, TR-scene-manager-004, TR-scene-manager-010, TR-scene-manager-011, TR-scene-manager-014, TR-scene-manager-022, TR-scene-manager-037, TR-scene-manager-038, TR-scene-manager-039
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary) + ADR-0003 (cross-rank read of TickSystem `offline_elapsed_seconds` for routing decision at foreground) + ADR-0014 (coordination note — the return-to-app auto-route is triggered by offline replay result, not by this story directly)
**ADR Decision Summary**: ADR-0007 substantive correction: `SceneTree.change_scene_to_*` is FORBIDDEN. All screen changes happen via `request_screen(screen_id, transition_type)` — the SOLE external API — which performs a `ScreenContainer` node-swap: `current_screen.on_exit()` → `queue_free()` → `call_deferred("_complete_swap", new_scene_instance)` → `add_child` on next frame → `current_screen.on_enter()`. Same-screen requests are a silent no-op (push_warning only). First-launch routes to `guild_hall`; resume-with-offline-gains routes to `return_to_app` via `SLIDE_DOWN`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `queue_free()` defers deallocation to end of current frame; `call_deferred("add_child", ...)` runs next frame. At most one old screen instance in "pending free" state (back-to-back guarded by TRANSITIONING state — full queue semantics in Story 010). `call_deferred` is preferred over `await get_tree().process_frame` because the await pattern introduces a visible one-frame stall / black frame at 60fps (per GDD §C.6 VALIDATE). All 7 MVP screens preloaded as `PackedScene` constants at boot (<10MB total). The `screen_registry` is a static dictionary on `SceneManager` — simple bounded-set resolution.

**Control Manifest Rules (Foundation Layer, SceneManager)**:
- **Required**: `request_screen(screen_id, transition_type)` is the SOLE external API for screen changes. — ADR-0007
- **Required**: Screens are swapped via the node-swap pattern (not `SceneTree.change_scene_to_*`). — ADR-0007
- **Required**: Same-screen request is a silent no-op — `push_warning` only. — ADR-0007
- **Forbidden**: Never call `SceneTree.change_scene_to_packed()` / `change_scene_to_file()` or any equivalent — all changes via `SceneManager.request_screen`. — ADR-0007
- **Forbidden**: Never call `queue_free()` on a Screen instance or `add_child()` to `ScreenContainer` from outside SceneManager. — ADR-0007

---

## Acceptance Criteria

*Verbatim from tr-registry:*

- [ ] TR-scene-manager-003: "current_screen is exactly one Control-based Node child of ScreenContainer"
- [ ] TR-scene-manager-004: "Screen swap pattern: on_exit -> queue_free -> call_deferred add_child new instance -> on_enter after frame boundary"
- [ ] TR-scene-manager-010: "Sole external API: request_screen(screen_id: String, transition: TransitionType)"
- [ ] TR-scene-manager-011: "TransitionType enum: CROSS_FADE, SLIDE_UP, SLIDE_LEFT, SLIDE_DOWN, FADE_TO_BLACK, PUSH_MODAL, CEREMONY"
- [ ] TR-scene-manager-014: "Same-screen request: detect and return early; no transition, no queue_free, push_warning only"
- [ ] TR-scene-manager-022: "All 7 MVP screens preloaded as PackedScene constants at boot (<10MB total memory)"
- [ ] TR-scene-manager-037: "scene_manager_config.tres Resource loaded at Autoload init holds tuning knobs" (subset — load the Resource; tune-knob consumption lives in Stories 005/009)
- [ ] TR-scene-manager-038: "First-launch no-save: DataRegistry ready -> route to guild_hall directly (Return-to-App never shown)"
- [ ] TR-scene-manager-039: "On resume with offline gains>0: request_screen('return_to_app', SLIDE_DOWN)"

*Verbatim from GDD §H (AC-scoped to this story):*

- [ ] **AC H-03 (BLOCKING)**: Given current screen is `guild_hall` and manager in IDLE, when `request_screen("guild_hall", any_transition)` called, then no transition starts; manager stays IDLE; `on_exit` not called on current; `on_enter` not called; returns immediately; silent (`push_warning` only, no error signal).
- [ ] **AC H-06 (BLOCKING, complete)**: Given game just launched and `DataRegistry.registry_ready` has NOT yet fired, when scene manager `_ready()` is called, then manager is UNINITIALIZED; any `request_screen` call before `registry_ready` is queued via `_queued_request`; manager does not transition to IDLE until `registry_ready` received; after fires, manager processes queued request.

---

## Implementation Notes

*Derived from ADR-0007 §Persistent root scene architecture (the contract) + §`request_screen()` — sole external API:*

- Implement the node-swap in `scene_manager.gd`:
  ```gdscript
  func _execute_transition(screen_id: String, transition: int) -> void:
      assert(state == State.IDLE, "_execute_transition requires IDLE")
      state = State.TRANSITIONING
      var packed: PackedScene = _screen_registry.get(screen_id)
      assert(packed != null, "Unknown screen_id '%s'" % screen_id)

      var old_screen: Control = current_screen
      var old_id: String = current_screen_id
      if old_screen:
          old_screen.on_exit()
          old_screen.queue_free()   # deallocates at end of frame

      var new_screen: Control = packed.instantiate()
      call_deferred("_complete_swap", new_screen, screen_id, transition, old_id)

  func _complete_swap(new_screen: Control, screen_id: String, transition: int, old_id: String) -> void:
      _screen_container.add_child(new_screen)
      current_screen = new_screen
      current_screen_id = screen_id
      new_screen.on_enter()
      # Transition animation kicks off in Story 005; for this story treat as instant + emit complete.
      screen_changed.emit(screen_id, old_id)
      state = State.IDLE
      transition_complete.emit(screen_id, transition)
      _drain_queued_request_if_any()
  ```
- `_screen_registry` — a `Dictionary[String, PackedScene]` populated at `_ready()` time from preloaded constants:
  ```gdscript
  const GUILD_HALL := preload("res://assets/screens/guild_hall/guild_hall.tscn")
  const RETURN_TO_APP := preload("res://assets/screens/return_to_app/return_to_app.tscn")
  # ... 7 total (placeholders acceptable while screen epics are pending)
  var _screen_registry := {
      "guild_hall": GUILD_HALL,
      "return_to_app": RETURN_TO_APP,
      # ...
  }
  ```
  Placeholders are acceptable for screens whose Presentation-layer epics have not landed — a one-line `Screen`-extending `.tscn` suffices. Missing registry entries must assert-fail (not silent no-op).
- Same-screen detection (AC H-03):
  ```gdscript
  if screen_id == current_screen_id:
      push_warning("[SceneManager] Same-screen request '%s' — no-op" % screen_id)
      return
  ```
- Full `request_screen` body folds in the UNINITIALIZED queue path from Story 002 and the TRANSITIONING queue path from Story 010 (leave the TRANSITIONING branch as `push_warning` + overwrite queue slot; full max-1 policy is locked in Story 010):
  ```gdscript
  func request_screen(screen_id: String, transition: int = TransitionType.CROSS_FADE) -> void:
      if state == State.UNINITIALIZED:
          _queued_request = {"screen_id": screen_id, "transition": transition}
          return
      if state == State.TRANSITIONING:
          if _queued_request:
              push_warning("[SceneManager] Overwriting queued request '%s' with '%s'" %
                  [_queued_request.get("screen_id"), screen_id])
          _queued_request = {"screen_id": screen_id, "transition": transition}
          return
      if screen_id == current_screen_id:
          push_warning("[SceneManager] Same-screen request '%s' — no-op" % screen_id)
          return
      _execute_transition(screen_id, transition)
  ```
- First-launch / resume routing in `_on_registry_ready()` (completes the stub from Story 002):
  ```gdscript
  func _on_registry_ready() -> void:
      state = State.IDLE
      # If a request was queued while UNINITIALIZED, drain it first (caller-requested route wins).
      if _queued_request:
          var pending := _queued_request.duplicate()
          _queued_request = {}
          _execute_transition(pending.screen_id, pending.transition)
          return
      # Default boot route: check TickSystem for offline gains.
      # TickSystem rank 0 < SceneManager rank (≥6) — STATE READ at _ready is safe (ADR-0003).
      # offline_elapsed_seconds fires asynchronously; for the boot-sync path, consult
      # TickSystem.get_last_persist_ts() / get_session_high_water() indirectly via
      # OfflineProgressionEngine's pending_summary flag when it lands (ADR-0014).
      # For MVP this story defaults to guild_hall; the return_to_app branch is documented
      # here and fully wired when OfflineProgressionEngine.offline_rewards_collected
      # triggers a post-boot request_screen("return_to_app", SLIDE_DOWN) — see Story 009.
      _execute_transition("guild_hall", TransitionType.CROSS_FADE)
  ```
- Load `scene_manager_config.tres` at autoload init (create with default values per GDD §G if missing). `Resource` fields mirror the `@export` knobs from ADR-0007; this story just loads and stores — actual consumption lives in Stories 005/009.
- `_drain_queued_request_if_any()` helper: pops `_queued_request` and re-invokes `_execute_transition`. Called at end of `_complete_swap` AND at end of `push_overlay` abort paths (Story 007). Intentionally simple — full max-1 semantics locked in Story 010.

---

## Out of Scope

- Story 004: `Screen` base class declaration (this story invokes `on_exit`/`on_enter` on Control subclasses; the base class contract is Story 004)
- Story 005: Tween-based transition animation (this story does the node-swap; the cross-fade / slide / fade-to-black animation is Story 005)
- Story 007: `push_overlay` / `pop_overlay` bodies + modal pause counter
- Story 008: `scene_boundary_persist` emission on dungeon_run_view / victory_moment
- Story 010: Full back-to-back queue-with-max-1 edge-case verification + `push_warning` on overwrite

---

## QA Test Cases

- **TR-scene-manager-003** / **TR-scene-manager-004**: Node-swap correctness
  - **Given**: SceneManager in IDLE; `current_screen` is screen A (placeholder `Screen` subclass)
  - **When**: `request_screen("screen_b", TransitionType.CROSS_FADE)` called; test awaits `transition_complete` signal
  - **Then**: `ScreenContainer.get_child_count() == 1`; `current_screen` is a screen B instance (not screen A); screen A's `queue_free` was called; screen B's `on_enter` was called AFTER screen A's `on_exit`
  - **Edge cases**: if the new scene fails to instantiate, `_complete_swap` must assert-fail rather than leave `ScreenContainer` empty

- **TR-scene-manager-010**: Sole external API
  - **Given**: codebase with CI grep enforcement
  - **When**: grep for any `change_scene_to_packed\|change_scene_to_file\|ScreenContainer\.add_child\|ScreenContainer\.remove_child` outside `src/core/scene_manager/`
  - **Then**: zero hits
  - **Edge cases**: test files themselves may legitimately call internal APIs — exclude `tests/` from the enforcement grep

- **TR-scene-manager-011**: TransitionType enum completeness
  - **Given**: SceneManager script loaded
  - **When**: `SceneManager.TransitionType` inspected
  - **Then**: exactly seven values in order — `CROSS_FADE, SLIDE_UP, SLIDE_LEFT, SLIDE_DOWN, FADE_TO_BLACK, PUSH_MODAL, CEREMONY`
  - **Edge cases**: adding an eighth value would be a spec change requiring an ADR amendment

- **TR-scene-manager-014 / AC H-03**: Same-screen no-op
  - **Given**: `current_screen_id == "guild_hall"`; state == IDLE
  - **When**: `request_screen("guild_hall", TransitionType.CROSS_FADE)` called
  - **Then**: no `on_exit` fires; no `queue_free` called; state remains IDLE; `push_warning` emitted (caught via test spy on `OS.get_stderr()` or Godot's log capture); no `screen_changed` or `transition_complete` signal fires
  - **Edge cases**: transitions of a different type against the same screen must also no-op (the transition type parameter is irrelevant when `screen_id` matches)

- **TR-scene-manager-022**: 7 MVP screens preloaded
  - **Given**: SceneManager autoload booted
  - **When**: test reads `_screen_registry.size()`
  - **Then**: == 7 (or documented placeholder count if presentation epics pending); total in-memory PackedScene payload <10MB via `Performance.get_monitor(Performance.MEMORY_STATIC)` delta probe
  - **Edge cases**: if any entry fails to preload at script-parse time, Godot surfaces a parse error — verify boot-pass is the hard fail mode

- **TR-scene-manager-038 / AC H-06**: First-launch routes to guild_hall
  - **Given**: clean save (no offline gains); DataRegistry not yet ready
  - **When**: `DataRegistry.registry_ready` fires
  - **Then**: `SceneManager._on_registry_ready` drains empty queue; auto-routes to `guild_hall`; `current_screen_id == "guild_hall"`; `return_to_app` never became current
  - **Edge cases**: a request queued during UNINITIALIZED (e.g. from a test harness) must take precedence over the default `guild_hall` route

- **TR-scene-manager-039**: Resume with offline gains routes to return_to_app
  - **Given**: SceneManager in IDLE; offline replay completed and `OfflineProgressionEngine.offline_rewards_collected` has emitted with `summary.gains > 0`
  - **When**: (owner system per ADR-0014) invokes `SceneManager.request_screen("return_to_app", SceneManager.TransitionType.SLIDE_DOWN)`
  - **Then**: transition executes normally; `current_screen_id == "return_to_app"`
  - **Edge cases**: this story only verifies the API accepts the call; the offline-replay trigger lives in the Tick-System / Offline-Progression epic — cross-referenced here for coverage

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene_manager/request_screen_and_node_swap_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (MainRoot scene), Story 002 (autoload + state enum + `_queued_request` slot), Story 004 (`Screen` base class with `on_enter`/`on_exit` — can be parallel-developed; this story calls the hooks, Story 004 declares them)
- **Unlocks**: Story 005 (transition animations hook into `_execute_transition`), Story 008 (`scene_boundary_persist` gates into `_execute_transition`), Story 010 (full queue semantics)
