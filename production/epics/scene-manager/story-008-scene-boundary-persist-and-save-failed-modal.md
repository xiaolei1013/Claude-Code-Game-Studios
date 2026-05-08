# Story 008: `scene_boundary_persist` narrow trigger + `save_failed` abort path + cozy modal

> **Epic**: scene-manager
> **Status**: Complete (system shipped; see systems-index Implementation Status #4. Test evidence: `tests/{unit,integration}/scene_manager/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/scene-screen-manager.md`
**Requirements**: TR-scene-manager-015, TR-scene-manager-016, TR-scene-manager-035
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary — §`scene_boundary_persist` signal contract + §Persist-failure UX: hard-stop the transition) + ADR-0004 (Save envelope — `scene_boundary_persist` triggers a full-envelope persist; the receiving side's contract) + ADR-0005 (Time System — heartbeat and graceful-exit persist paths are SEPARATE; this story MUST NOT duplicate them)
**ADR Decision Summary**: `scene_boundary_persist(reason: String)` fires at EXACTLY two points: BEFORE `request_screen("dungeon_run_view", FADE_TO_BLACK)` begins its transition animation (reason = `"enter_dungeon_run_view"`), and AFTER `request_screen` from `victory_moment` to anything (reason = `"exit_victory_moment"`). On `SaveLoadSystem.save_failed`, the transition is ABORTED and SceneManager stays on the current screen with a non-blocking cozy modal: "Couldn't save your progress right now. Your guild is waiting on the storage to settle. Try again? [Try Again / Stay Here]" (ADR-0007 §Persist-failure UX — resolves architecture.md OQ-3 with the hard-stop policy).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: The persist call happens BEFORE the transition animation starts — the transition "awaits" `save_completed` or `save_failed`. In GDScript this is an explicit sequencing, not `await`, because SaveLoadSystem's persist API in ADR-0004 is synchronous-returning-bool (plus signal emission for async-completion of atomic write). Use signal-driven flow: (1) `scene_boundary_persist.emit("enter_dungeon_run_view")`; (2) connect to `SaveLoadSystem.save_completed` + `save_failed` with `CONNECT_ONE_SHOT`; (3) whichever fires first drives `_continue_pending_transition` or `_abort_pending_transition`. Godot 4.6 `Signal.connect(..., CONNECT_ONE_SHOT)` is stable. The cozy modal is pushed via Story 007's `push_overlay("persist_failure", true)`.

**Control Manifest Rules (Foundation Layer, SceneManager)**:
- **Required**: `scene_boundary_persist(reason)` fires before entering `dungeon_run_view` AND after exiting `victory_moment` — no other transitions trigger it. — ADR-0007
- **Required**: On `save_failed` from SaveLoad, transition is ABORTED; SceneManager stays on current screen; non-blocking modal with "Try Again / Stay Here" cozy copy (resolves OQ-3 hard-stop). — ADR-0007
- **Guardrail**: Scene-boundary persist: aborted on `save_failed` (hard-stop) — [BLOCKING AC H-07]. — ADR-0007
- **Forbidden**: Never duplicate heartbeat or graceful-exit persist paths — those are TickSystem's responsibility per ADR-0005. SceneManager does NOT fire `scene_boundary_persist` on app-background or app-close.

---

## Acceptance Criteria

*Verbatim from tr-registry:*

- [ ] TR-scene-manager-015: "Emits scene_boundary_persist signal before dungeon_run_view enter and on victory_moment exit"
- [ ] TR-scene-manager-016: "Save/Load persist is async: await save_completed OR save_failed before committing transition; abort on save_failed"
- [ ] TR-scene-manager-035: "Emits save_failed pathway handling - stays on current screen if scene_boundary_persist fails"

*Verbatim from GDD §H:*

- [ ] **AC H-07 (BLOCKING, Integration)**: Given current screen is not `dungeon_run_view`, when `request_screen("dungeon_run_view", TransitionType.FADE_TO_BLACK)` is called, then `scene_boundary_persist` signal is emitted BEFORE transition animation begins; `SaveLoad.persist()` is called; if `persist()` returns error (`save_failed` signal), transition is aborted and manager stays on current screen.

---

## Implementation Notes

*Derived from ADR-0007 §`scene_boundary_persist` signal contract + §Persist-failure UX: hard-stop the transition:*

- Intercept `_execute_transition` in `SceneManager` to check for the two narrow trigger points BEFORE running the node-swap:
  ```gdscript
  func _execute_transition(screen_id: String, transition: int) -> void:
      # Narrow scene_boundary_persist trigger BEFORE dungeon_run_view entry.
      if screen_id == "dungeon_run_view":
          _begin_persist_gated_transition(screen_id, transition, "enter_dungeon_run_view")
          return
      # Narrow scene_boundary_persist trigger AFTER exiting victory_moment.
      if current_screen_id == "victory_moment":
          # Fire persist first, let it settle; then continue transition regardless
          # (post-victory persist is logging, not gating — per GDD §C.2 row 3).
          scene_boundary_persist.emit("exit_victory_moment")
          # Continue normally; no abort-on-fail for post-victory.
      _proceed_with_transition(screen_id, transition)
  ```
  **Note**: GDD §C.2 frames the pre-`dungeon_run_view` persist as gating (H-07 BLOCKING) and the post-`victory_moment` persist as a consequence of the transition. Only the `enter_dungeon_run_view` path aborts on failure; `exit_victory_moment` emits and proceeds (persist-failure there is a separate cozy-modal story — if the player returns to Guild Hall and save fails, the persist banner from Save/Load system surfaces; we do NOT block them on the Victory screen).
- `_begin_persist_gated_transition` and its resolve handlers:
  ```gdscript
  var _pending_transition: Dictionary = {}      # {screen_id, transition}

  func _begin_persist_gated_transition(screen_id: String, transition: int, reason: String) -> void:
      _pending_transition = {"screen_id": screen_id, "transition": transition}
      SaveLoadSystem.save_completed.connect(_on_persist_resolve.bind(true), CONNECT_ONE_SHOT)
      SaveLoadSystem.save_failed.connect(_on_persist_resolve.bind(false), CONNECT_ONE_SHOT)
      scene_boundary_persist.emit(reason)
      # SaveLoadSystem subscribes to scene_boundary_persist and calls its persist routine.

  func _on_persist_resolve(success: bool) -> void:
      # One-shot connects; disconnect the opposite handler defensively.
      if SaveLoadSystem.save_completed.is_connected(_on_persist_resolve.bind(true)):
          SaveLoadSystem.save_completed.disconnect(_on_persist_resolve.bind(true))
      if SaveLoadSystem.save_failed.is_connected(_on_persist_resolve.bind(false)):
          SaveLoadSystem.save_failed.disconnect(_on_persist_resolve.bind(false))
      if not success:
          _abort_pending_transition()
          return
      var pending := _pending_transition.duplicate()
      _pending_transition = {}
      _proceed_with_transition(pending.screen_id, pending.transition)
  ```
  (Note on `Callable.bind` + `is_connected` — the bound Callable equality semantics changed through 4.x; verify on 4.6 that `connect` + `disconnect` on the same bound-Callable pair works, or store the bound Callables in members for exact equality.)
- `_abort_pending_transition`:
  ```gdscript
  func _abort_pending_transition() -> void:
      _pending_transition = {}
      state = State.IDLE   # ensure we return to IDLE cleanly (we never entered TRANSITIONING for the gated path)
      push_overlay("persist_failure", true)
  ```
- Register the cozy persist-failure modal in `_overlay_registry["persist_failure"]` — a simple Control with two buttons wired to `save_failed_modal_dismissed(retry_requested: bool)` signal (declared on SceneManager per ADR-0007 §Key interfaces):
  - **Try Again** button: emits `save_failed_modal_dismissed(true)`, pops the overlay, re-emits `scene_boundary_persist` after a short delay. On second failure, the modal closes and a persistent corner banner appears ("Save failed — check storage; will retry") managed by the HUD layer (not SceneManager — hand off to Save/Load system per GDD §I OQ #5).
  - **Stay Here** button: emits `save_failed_modal_dismissed(false)`, pops the overlay, no further automatic retry until next user-initiated transition.
- Modal copy (verbatim per ADR-0007 §Persist-failure UX):
  > *"Couldn't save your progress right now. Your guild is waiting on the storage to settle. Try again? [Try Again / Stay Here]"*
  Cozy tone per Pass-5E style; non-accusatory; reassures continuity.
- `_proceed_with_transition` is a private helper: does exactly what the original `_execute_transition` did (set state = TRANSITIONING, dispatch to the tween/AnimationPlayer path from Stories 005/006).
- Defensive assertion: `SaveLoadSystem.scene_boundary_persist` subscription must be present. If `SaveLoadSystem` is not an autoload at this rank, the connect call fails silently — CI grep or startup assert verifies the connection pair exists.
- Do NOT fire `scene_boundary_persist` on any other transition. TickSystem owns heartbeat + graceful-exit persist paths per ADR-0005.

---

## Out of Scope

- Story 007: `push_overlay` / `pop_overlay` mechanics (this story uses them for the persist-failure modal)
- Story 010: Queue-with-max-1 interaction with aborted transitions — the "a new request_screen arrived while the persist was in flight" edge case (tested in Story 010)
- Save/Load persist routine itself — owned by the Save/Load epic; this story only consumes the `save_completed` / `save_failed` signals
- Second-failure persistent corner banner UX — owned by HUD / Save/Load epic

---

## QA Test Cases

- **TR-scene-manager-015 / AC H-07 (BLOCKING, happy path)**: `scene_boundary_persist` fires before `dungeon_run_view` entry
  - **Given**: SceneManager IDLE; current screen ≠ `dungeon_run_view`; mock `SaveLoadSystem` that emits `save_completed` on receiving `scene_boundary_persist`; test subscriber on `scene_boundary_persist`
  - **When**: `request_screen("dungeon_run_view", TransitionType.FADE_TO_BLACK)` called
  - **Then**: (1) `scene_boundary_persist.emit("enter_dungeon_run_view")` happens BEFORE any Tween / transition animation starts (spy on `_active_transition_tween` creation); (2) `SaveLoadSystem.save_completed` fires; (3) transition proceeds normally; (4) `current_screen_id == "dungeon_run_view"` at end
  - **Edge cases**: signal emission order — subscriber to `scene_boundary_persist` must see the emission before any tween-related signal

- **TR-scene-manager-016 / TR-scene-manager-035 / AC H-07 (BLOCKING, failure path)**: `save_failed` aborts transition
  - **Given**: SceneManager IDLE; current screen = `guild_hall`; mock `SaveLoadSystem` that emits `save_failed` on receiving `scene_boundary_persist`
  - **When**: `request_screen("dungeon_run_view", TransitionType.FADE_TO_BLACK)` called
  - **Then**: transition is aborted; `current_screen_id == "guild_hall"` (unchanged); persist-failure modal is visible on `OverlayLayer` (via `push_overlay("persist_failure", true)`); `_modal_pause_count == 1`; `get_tree().paused == true`
  - **Edge cases**: hitting **Try Again** button re-emits `scene_boundary_persist` — a second save_failed must again abort with the modal, eventually escalating to the corner-banner handoff; hitting **Stay Here** pops the overlay and leaves the player on `guild_hall`

- **TR-scene-manager-015 (exit path)**: `scene_boundary_persist` fires after `victory_moment` exit
  - **Given**: SceneManager IDLE; `current_screen_id == "victory_moment"`; subscriber connected
  - **When**: `request_screen("guild_hall", TransitionType.CROSS_FADE)` called
  - **Then**: `scene_boundary_persist.emit("exit_victory_moment")` fires; the transition proceeds regardless of `save_completed` / `save_failed` (post-victory persist is log-only, not gating)
  - **Edge cases**: if `save_failed` fires during exit, a corner banner surfaces (not a blocking modal) — this story does NOT handle banner UX; cross-linked to Save/Load epic

- **Narrow trigger (no false positives)**:
  - **Given**: SceneManager IDLE across a sequence of transitions that are NOT dungeon_run_view entry and NOT victory_moment exit (e.g., guild_hall → roster, roster → recruit, recruit → guild_hall)
  - **When**: each transition fires
  - **Then**: `scene_boundary_persist` subscriber receives ZERO emissions across the entire sequence
  - **Edge cases**: entering `matchup_assignment` does NOT fire `scene_boundary_persist` — only `dungeon_run_view` does

- **Counter invariant on modal push**:
  - **Given**: save_failed abort path triggered; persist-failure modal visible
  - **When**: user hits Stay Here → modal closes
  - **Then**: `_modal_pause_count == 0`; `get_tree().paused == false`; state == IDLE

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene_manager/scene_boundary_persist_test.gd` AND `tests/integration/scene_manager/save_failed_abort_path_test.gd` — both must exist and pass. Mock `SaveLoadSystem` fixture lives in `tests/helpers/`.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 003 (`_execute_transition` infrastructure), Story 005 (`FADE_TO_BLACK` transition type wired), Story 007 (`push_overlay` for persist-failure modal)
- **Unlocks**: Story 010 (edge case: new request_screen arriving mid-persist gate)
