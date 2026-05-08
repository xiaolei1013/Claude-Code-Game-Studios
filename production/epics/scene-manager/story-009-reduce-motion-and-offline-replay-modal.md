# Story 009: `reduce_motion` accessibility flag + offline-replay cozy-modal coordination

> **Epic**: scene-manager
> **Status**: Complete (per-AC verification 2026-05-08 — audit-cascade caveat resolved; required test file exists and passes; ACs ticked.)
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/scene-screen-manager.md`
**Requirements**: TR-scene-manager-006, TR-scene-manager-027, TR-scene-manager-036
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary — §`reduce_motion` accessibility — saved as user preference) + ADR-0014 (Offline replay cozy modal at ≥100ms threshold via `SceneManager.show_modal`) + ADR-0008 (Settings overlay uses parchment theme; accessibility setting exposed in Settings)
**ADR Decision Summary**: `reduce_motion` accessibility flag clamps ALL standard transitions (CROSS_FADE, SLIDE_*, FADE_TO_BLACK, PUSH_MODAL) to 50ms total duration; replaces CEREMONY with an instant cut + reward number reveal; touch feedback (1.05× scale, 80ms) stays (per-button, not transition). Persisted to `user://settings.cfg` via Godot `ConfigFile` as the interim path; migrates to Save/Load envelope when Settings GDD #30 lands (OQ-7). ADR-0014 coordination: OfflineProgressionEngine calls `SceneManager.show_modal(_progress_modal)` at the ≥100ms replay threshold; modal auto-dismisses on `offline_rewards_collected` signal emission. `SceneManager.show_modal` and `hide_modal` are thin wrappers over Story 007's `push_overlay` / `pop_overlay` with `pause_on_open = false` (the offline replay needs the tick loop running to process the replay batches — though replay bypasses `tick_fired` per ADR-0005, the UI animations on the modal itself must keep running).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `ConfigFile` is stable since 4.0. `user://settings.cfg` path uses Godot's per-platform user data directory. Reading the flag at SceneManager boot is synchronous and cheap. For `reduce_motion`, clamp tween durations BEFORE calling `tween_property` (not after — tweens don't retroactively shorten). For CEREMONY instant-cut: skip `animation_player.play()` entirely; directly show the reward number and call `_on_ceremony_finished` on the next frame. Offline-replay modal: the `_progress_modal` instance is OWNED by OfflineProgressionEngine (per ADR-0014 §State container) and passed IN to `SceneManager.show_modal(modal_instance)` — so `show_modal` takes a `Control` instance, not a registry id. This is a distinct API surface from `push_overlay(overlay_id, pause_on_open)`.

**Control Manifest Rules (Foundation Layer, SceneManager)**:
- **Required**: `reduce_motion` accessibility flag: clamps standard transitions to 50ms; replaces ceremony with instant cut + reward number reveal; persisted (interim `user://settings.cfg`; migrates to Save/Load envelope when Settings GDD #30 lands). — ADR-0007
- **Required**: Aggregate post-replay signal emission order: (1) `Economy.gold_changed`, (2) `Economy.first_clear_awarded` ×N, (3) `Orchestrator.floor_cleared_first_time` ×N, (4) `OfflineProgressionEngine.offline_rewards_collected(summary)` (last; triggers SceneManager transition). — ADR-0014
- **Required**: Time-gated UX: silent for replays <100 ms estimated; cozy modal at ≥100 ms via `SceneManager.show_modal(_progress_modal)`; modal auto-dismisses on `offline_rewards_collected`. — ADR-0014
- **Forbidden**: Never write `reduce_motion` directly to the Save/Load envelope in MVP — the interim ConfigFile path is architecturally mandated until Settings GDD #30. — ADR-0007 OQ-7

---

## Acceptance Criteria

*Verbatim from tr-registry:*

- [x] TR-scene-manager-006: "Transitions not player-skippable; all standard 150-300ms, ceremony up to 800ms" (with reduce_motion clamp override)
- [x] TR-scene-manager-027: "reduce_motion accessibility knob: clamps all transitions to 50ms, ceremony becomes instant cut; persisted in save"
- [x] TR-scene-manager-036: "Ceremony ColorRect alpha cut is instantaneous when reduce_motion=true"

*Verbatim from GDD §G Tuning Knobs:*

- [x] `reduce_motion` default is `false`; toggle exposed in Settings overlay (surface owned by Settings GDD #30 — the plumbing is wired here)
- [x] When `reduce_motion == true`: all standard transitions (CROSS_FADE, SLIDE_*, FADE_TO_BLACK, PUSH_MODAL) clamp to **50ms**; CEREMONY becomes instant cut + reward number reveal; touch feedback 1.05× / 80ms stays

*From ADR-0014 coordination:*

- [x] `SceneManager.show_modal(modal: Control)` adds the modal to `OverlayLayer` with `pause_on_open = false`; `SceneManager.hide_modal(modal: Control)` removes it
- [x] Modal auto-dismisses when `OfflineProgressionEngine.offline_rewards_collected` fires (owned by OfflineProgressionEngine side; SceneManager exposes the `hide_modal` API)

---

## Implementation Notes

*Derived from ADR-0007 §`reduce_motion` accessibility and ADR-0014 §Time-gated UX implementation:*

- Add `reduce_motion` state on SceneManager:
  ```gdscript
  var reduce_motion: bool = false   # interim source of truth; persisted to user://settings.cfg
  const REDUCE_MOTION_CLAMP_MS: int = 50
  ```
- Boot-time load (in SceneManager `_ready`, after DataRegistry ready):
  ```gdscript
  func _load_interim_settings() -> void:
      var cfg := ConfigFile.new()
      var err := cfg.load("user://settings.cfg")
      if err == OK:
          reduce_motion = bool(cfg.get_value("accessibility", "reduce_motion", false))
      # else: defaults stand (reduce_motion = false); file will be created on first save
  ```
- Persist path — exposed as public setter + internal writer (called by Settings overlay in the UI Framework epic):
  ```gdscript
  func set_reduce_motion(value: bool) -> void:
      if reduce_motion == value:
          return
      reduce_motion = value
      var cfg := ConfigFile.new()
      cfg.load("user://settings.cfg")   # ignore error; we're rewriting
      cfg.set_value("accessibility", "reduce_motion", value)
      var save_err := cfg.save("user://settings.cfg")
      if save_err != OK:
          push_warning("[SceneManager] Failed to persist reduce_motion to user://settings.cfg (err=%d)" % save_err)
  ```
- Apply clamp in Story 005's transition dispatchers:
  ```gdscript
  func _resolved_duration_ms(transition: int, incoming_override_ms: int) -> int:
      if reduce_motion:
          return REDUCE_MOTION_CLAMP_MS
      if incoming_override_ms > 0:
          return incoming_override_ms
      match transition:
          TransitionType.CROSS_FADE: return default_crossfade_ms
          TransitionType.SLIDE_UP, TransitionType.SLIDE_LEFT, TransitionType.SLIDE_DOWN: return slide_duration_ms
          TransitionType.FADE_TO_BLACK: return fade_to_black_ms
          TransitionType.PUSH_MODAL: return default_crossfade_ms  # push_modal reuses crossfade base by default
          _: return default_crossfade_ms
  ```
  All Story 005 `tween_property(..., duration)` calls route through this helper.
- CEREMONY reduce_motion branch in Story 006's dispatcher:
  ```gdscript
  func _transition_ceremony(new_screen_callable: Callable) -> void:
      if reduce_motion:
          _instant_ceremony_cut(new_screen_callable)
          return
      # ... (existing AnimationPlayer.play path from Story 006)

  func _instant_ceremony_cut(new_screen_callable: Callable) -> void:
      _ceremony_container.visible = true
      # Directly show the reward number (no fade).
      var reward := _ceremony_container.get_node_or_null("RewardNumber") as Control
      if reward:
          reward.modulate.a = 1.0
      new_screen_callable.call()
      # One-frame delay so the reward reveal is visible before state returns to IDLE.
      await get_tree().process_frame
      _ceremony_container.visible = false
      state = State.IDLE
      transition_complete.emit(current_screen_id, TransitionType.CEREMONY)
      _drain_queued_request_if_any()
  ```
- ADR-0014 modal API wrappers:
  ```gdscript
  # Offline-replay cozy modal entry points — used by OfflineProgressionEngine.
  # Distinct from push_overlay/pop_overlay because the caller owns the modal instance.
  func show_modal(modal: Control) -> void:
      assert(modal != null, "show_modal received null")
      _overlay_layer.add_child(modal)
      _active_freestanding_modals.append(modal)
      if current_screen:
          current_screen.on_pause()
      state = State.PAUSED
      # Do NOT increment _modal_pause_count — offline replay does not pause the tree
      # (replay path bypasses tick_fired anyway; UI animations on the modal must render).

  func hide_modal(modal: Control) -> void:
      if not _active_freestanding_modals.has(modal):
          push_warning("[SceneManager] hide_modal: modal not tracked; no-op")
          return
      _active_freestanding_modals.erase(modal)
      modal.queue_free()
      if _active_freestanding_modals.is_empty() and _active_overlays.is_empty():
          state = State.IDLE
          if current_screen:
              current_screen.on_resume()
  ```
  `_active_freestanding_modals: Array[Control]` is a new SceneManager member. The distinction between `_active_overlays` (Dictionary indexed by `overlay_id`) and `_active_freestanding_modals` (Array of instances) reflects the two API surfaces: registry-based `push_overlay` vs instance-based `show_modal`.
- Document OQ-7 resolution plan in a code comment: "When Settings/Accessibility GDD #30 lands, migrate `reduce_motion` read/write from `user://settings.cfg` to Save/Load envelope under a `settings` namespace. On first boot after migration: read both paths; write only to envelope; delete ConfigFile entry after first successful envelope save with the field present."

---

## Out of Scope

- Story 005: Base tween durations (this story clamps them; Story 005 owns the defaults)
- Story 006: CEREMONY default-motion path (this story branches to instant-cut when `reduce_motion == true`)
- Story 007: `push_overlay` / `pop_overlay` — `show_modal` / `hide_modal` are a SEPARATE API for ADR-0014; this story declares both
- Settings overlay UI (toggle control, label, a11y screen-reader hooks) — owned by Settings GDD #30
- OfflineProgressionEngine itself (modal instance authoring, replay orchestration) — owned by the Offline/Tick epic

---

## QA Test Cases

- **TR-scene-manager-027 / TR-scene-manager-036**: `reduce_motion` clamp and CEREMONY cut
  - **Given**: SceneManager IDLE; `reduce_motion` flipped to `true` via `SceneManager.set_reduce_motion(true)`
  - **When**: (1) `request_screen("guild_hall", TransitionType.CROSS_FADE)` from a different screen; (2) `request_screen("victory_moment", TransitionType.CEREMONY)`
  - **Then**: (1) cross-fade total wall-clock is ~50ms (±5ms tolerance); (2) CEREMONY completes within 2 frames (~33ms); reward number is visible at first sample after call; no `AnimationPlayer.play` called during CEREMONY path (spy assertion)
  - **Edge cases**: flipping `reduce_motion` mid-transition does not abort the in-flight tween (the clamp applies only to future `_resolved_duration_ms` calls); test verifies the mid-flight transition completes at its started duration, and the NEXT transition respects the new clamp

- **TR-scene-manager-006**: Transitions not player-skippable even with `reduce_motion`
  - **Given**: `reduce_motion == true`; a 50ms cross-fade in progress
  - **When**: simulated tap during transition
  - **Then**: input-blocker (Story 010) consumes the tap; no shortcut mechanism fast-forwards the transition
  - **Edge cases**: player cannot combine `reduce_motion` with a "skip transition" input — there is no such input

- **`reduce_motion` ConfigFile persistence**:
  - **Given**: `user://settings.cfg` absent at test start
  - **When**: `SceneManager.set_reduce_motion(true)` called; game closed; game re-launched; `SceneManager._ready` runs `_load_interim_settings`
  - **Then**: `reduce_motion == true` on fresh launch; `user://settings.cfg` contains `[accessibility]\nreduce_motion=true`
  - **Edge cases**: malformed cfg file must not crash boot — `ConfigFile.load` returning non-OK falls back to defaults with a `push_warning`

- **ADR-0014 coordination**: `show_modal` / `hide_modal` for offline-replay cozy modal
  - **Given**: SceneManager IDLE; a `Control` instance (mock progress modal) passed in
  - **When**: `SceneManager.show_modal(modal)` called
  - **Then**: modal is a child of `OverlayLayer`; state == PAUSED; `current_screen.on_pause` called; `_modal_pause_count` is UNCHANGED (0); `get_tree().paused == false` (offline replay must still be running tick batches inside OfflineProgressionEngine)
  - When `SceneManager.hide_modal(modal)` called
  - **Then**: modal removed from `OverlayLayer` via `queue_free`; state back to IDLE; `current_screen.on_resume` called
  - **Edge cases**: hide a modal that was never shown → `push_warning` + no-op; show two modals in sequence without intervening hide → both end up as children of OverlayLayer; `hide_modal` resolves them independently

- **ADR-0014 signal emission ordering**:
  - **Given**: offline replay completes via OfflineProgressionEngine
  - **When**: `offline_rewards_collected(summary)` emits
  - **Then**: the modal is hidden (via OfflineProgressionEngine calling `hide_modal`), `return_to_app` screen transition fires LAST after all aggregate signals (`gold_changed`, `first_clear_awarded`, `floor_cleared_first_time`, `offline_rewards_collected`) — this is the handoff point where Story 003's TR-039 fires
  - **Edge cases**: `offline_rewards_collected` firing without a preceding `show_modal` (replay was <100ms) is the silent path — no-op on SceneManager side

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene_manager/reduce_motion_clamp_test.gd` AND `tests/integration/scene_manager/offline_replay_modal_coordination_test.gd` — both must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 005 (transition durations routed through `_resolved_duration_ms` helper), Story 006 (CEREMONY dispatcher branches on `reduce_motion`), Story 007 (overlay API infrastructure)
- **Unlocks**: Story 010 (performance soak verifies clamp behavior under load)
