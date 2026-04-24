# Story 012: Scene-boundary persist + `save_failed` abort modal coupling

> **Epic**: save-load-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md` §Persist Triggers (scene_boundary_persist row)
**Requirements**: TR-save-load-008 (trigger list), TR-save-load-009 (async signal pattern), TR-save-load-057 (signals)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary — scene transition + persist coupling + hard-stop modal), ADR-0004 (full-envelope contract consumed here)
**ADR Decision Summary**: `scene_boundary_persist(reason)` fires before entering `dungeon_run_view` and after exiting `victory_moment`. SceneManager calls SaveLoadSystem's persist method and awaits `save_completed` / `save_failed` before committing the transition. On `save_failed`, transition is ABORTED; SceneManager surfaces cozy modal "Couldn't save your progress right now. Your guild is waiting on the storage to settle. Try again? [Try Again / Stay Here]". Resolves architecture.md OQ-3 hard-stop.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (async signal pattern timing: the persist must yield the frame to avoid transition animation hitch, then re-enter SceneManager on the next frame)
**Engine Notes**: `await signal` (no `yield()`); signal subscription across rank pair safe per ADR-0003 Amendment #1. SceneManager handles the transition animation; SaveLoadSystem owns the persist timing.

**Control Manifest Rules (Foundation Layer, scene-boundary)**:
- **Required**: Scene boundary persist is async-signal pattern: SceneManager awaits `save_completed`/`save_failed` before committing transition. `save_completed` and `save_failed` signals emitted for SceneManager await pattern. On `save_failed` from SaveLoad, transition is ABORTED; SceneManager stays on current screen; non-blocking modal with "Try Again / Stay Here" cozy copy (resolves OQ-3 hard-stop).
- **Forbidden**: Synchronous persist on scene-boundary (50 ms mobile target blocks main thread → visible animation hitch). Auto-retry on `save_failed` without user choice (must offer "Try Again / Stay Here" agency).
- **Guardrail**: Scene-boundary persist aborted on `save_failed` [BLOCKING AC H-07].

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] SaveLoadSystem `_ready()` connects to `SceneManager.scene_boundary_persist(reason: String)` signal (Story 001 hooked this up; this story implements the handler)
- [ ] Handler `_on_scene_boundary_persist(reason: String)`: transitions state to `PERSISTING`; invokes the full-state persist via Story 007 loop + Story 008 atomic write; on success emits `save_completed(reason)`; on failure emits `save_failed(reason, error_detail)`
- [ ] SaveLoadSystem exposes `save_completed(reason: String)` and `save_failed(reason: String, error_detail: String)` signals
- [ ] Async yield: after composing the envelope and before invoking `DirAccess.rename` (Story 008), the handler `await get_tree().process_frame` at least once so the transition's starting frame renders without blocking
- [ ] SceneManager's await contract: SceneManager registers its listener on `save_completed` / `save_failed` THEN calls the trigger; SaveLoadSystem emits after persist completes; SceneManager commits or aborts the transition
- [ ] On `save_failed`: SceneManager stays on current screen; surfaces non-blocking modal with Pass-5E approved copy: "Couldn't save your progress right now. Your guild is waiting on the storage to settle. Try again? [Try Again / Stay Here]"
- [ ] "Try Again" modal action: re-emits `scene_boundary_persist(reason)` after short delay (SceneManager owns the retry; SaveLoadSystem merely re-runs)
- [ ] Persistent corner banner on second failure: "Save failed — check storage; will retry" until next successful persist (SceneManager owns)
- [ ] Scene-boundary persist reasons limited to 2 values: `"enter_dungeon_run_view"` and `"exit_victory_moment"` (other transitions do NOT trigger this signal per ADR-0007)

---

## Implementation Notes

- Async pattern rough shape:
  ```gdscript
  func _on_scene_boundary_persist(reason: String) -> void:
      if _state == State.PERSISTING:
          push_warning("[SaveLoad] scene_boundary_persist coalesced")
          return
      _transition_to(State.PERSISTING)
      var envelope := _compose_full_envelope()
      await get_tree().process_frame  # yield to render loop
      var ok := _atomic_persist(envelope)
      _transition_to(State.READY)
      if ok:
          save_completed.emit(reason)
      else:
          save_failed.emit(reason, "io_error")
  ```
- Why yield BEFORE `_atomic_persist`: the transition animation's first frame renders before the disk I/O begins, avoiding the visible hitch. SceneManager can show the transition effect while the persist runs in the background.
- `await get_tree().process_frame` yields the current frame; next-frame execution continues the handler. Per Godot 4.x, this is safe in `_process`-adjacent contexts (signal handlers are called from `_process` for most cases)
- Full-envelope compose is the same Story 007 loop body; no branching from heartbeat (Story 011)
- Modal copy is LOCKED per Pass-5E 2026-04-21 writer sign-off — do not re-litigate:
  > "Couldn't save your progress right now. Your guild is waiting on the storage to settle. Try again? [Try Again / Stay Here]"
- The modal's ownership is SceneManager, NOT SaveLoadSystem. SaveLoadSystem only emits `save_failed(reason, error_detail)`; SceneManager's handler shows the modal. This preserves the layering: SaveLoadSystem doesn't know about UI.
- AC-SL-02 (atomic write survives mid-persist kill) is tested via this path + Story 008's `debug_pause_before_rename` hook
- "Exactly 2 reasons" constraint: SaveLoadSystem logs a `push_warning` if it receives an unknown reason string (defense against wiring regression); SceneManager is source of truth for valid reasons
- First-failure vs second-failure UX: SaveLoadSystem fires one `save_failed` signal per failure; SceneManager tracks the retry count and escalates from modal → corner banner after second fail

---

## Out of Scope

- Story 013: generic tamper-detected-on-load UX (different trigger, different modal)
- Story 015: performance budget measurement (<10ms/<50ms — this story owns the path; Story 015 measures)
- SceneManager-side modal implementation (owned by Scene Manager epic)

---

## QA Test Cases

- **TR-save-load-008 / TR-save-load-009 (happy path)**
  - **Given**: SceneManager fires `scene_boundary_persist("enter_dungeon_run_view")`; disk writable; all consumers healthy
  - **When**: SaveLoadSystem handler runs
  - **Then**: State `READY → PERSISTING → READY`; one `await get_tree().process_frame` yield; atomic write succeeds; `save_completed("enter_dungeon_run_view")` emitted; SceneManager commits transition
  - **Edge cases**: `exit_victory_moment` reason exercises the same path

- **TR-save-load-009 (async yield verified)**
  - **Given**: A test frame-counting hook around the handler
  - **When**: Handler runs
  - **Then**: Frame count between handler entry and persist completion is ≥2 (one yield enforced); the transition animation's first frame is rendered before persist begins
  - **Edge cases**: This asserts the non-blocking contract; synchronous implementations would fail

- **TR-save-load-057 (save_failed emission)**
  - **Given**: Atomic write fails (e.g., `store_buffer` returns false via test hook)
  - **When**: Handler completes
  - **Then**: `save_failed(reason, error_detail)` emitted exactly once; NO `save_completed` emitted; state returns to `READY`
  - **Edge cases**: Multiple concurrent failures — handler coalesces per PERSISTING state overlap rule

- **ADR-0007 H-07 (BLOCKING): Transition aborted on save_failed**
  - **Given**: SaveLoadSystem emits `save_failed(...)`
  - **When**: SceneManager's listener fires
  - **Then**: SceneManager stays on current screen; modal shown with Pass-5E copy; NO screen change
  - **Edge cases**: User taps "Stay Here" — no retry fires; user taps "Try Again" — SceneManager re-emits `scene_boundary_persist(reason)` after brief delay

- **Reason limit**
  - **Given**: An unknown reason `"random_transition"` is fired (regression scenario)
  - **When**: Handler runs
  - **Then**: `push_warning` emitted; persist proceeds defensively; does not crash
  - **Edge cases**: Only `"enter_dungeon_run_view"` and `"exit_victory_moment"` are expected — all others log warning

- **Modal copy (writer sign-off)**
  - **Given**: `save_failed` path
  - **When**: SceneManager modal surfaces
  - **Then**: Copy matches Pass-5E 2026-04-21 canonical string exactly (byte-for-byte); [Try Again / Stay Here] buttons present
  - **Edge cases**: No emoji in copy (per project style); `tr()` localization wrapper applied (ADR-0008 rule)

- **Second-failure banner**
  - **Given**: User tapped "Try Again" after first `save_failed`; second persist also fails
  - **When**: SceneManager's retry handler receives the second `save_failed`
  - **Then**: Modal dismissed; persistent corner banner "Save failed — check storage; will retry" visible until next successful persist
  - **Edge cases**: Next successful persist auto-dismisses banner (SceneManager subscribes to `save_completed`)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/save_load/scene_boundary_persist_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (signal subscription), Story 007 (full consumer loop), Story 008 (atomic write), Story 009 (`_meta` updates on persist)
- **Unlocks**: Story 015 (performance measurement on scene-boundary path); indirectly unlocks ADR-0007 H-07 BLOCKING
