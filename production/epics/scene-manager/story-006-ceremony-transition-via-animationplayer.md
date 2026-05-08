# Story 006: CEREMONY transition exclusively via `AnimationPlayer`

> **Epic**: scene-manager
> **Status**: Complete (system shipped; see systems-index Implementation Status #4. Test evidence: `tests/{unit,integration}/scene_manager/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/scene-screen-manager.md`
**Requirements**: TR-scene-manager-021, TR-scene-manager-025
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary — §Tween vs AnimationPlayer choice)
**ADR Decision Summary**: The `CEREMONY` transition (for Victory / Unlock Moment) is authored exclusively via `AnimationPlayer`, NOT via `create_tween()`. Total duration 400–800ms (default 600ms). The primary reward number MUST render within the first 100ms of the ceremony window — even if decorative animation continues to 800ms. Reason: ceremony is multi-node multi-property sequenced keyframes (lantern-flare particle + reward number tween + audio cue + screen tint); AnimationPlayer's editor timeline is the right tool for this. All five standard transitions stay on `create_tween()` (Story 005).

**Engine**: Godot 4.6 | **Risk**: MEDIUM-HIGH
**Engine Notes**: `AnimationPlayer` is stable since 4.0, but authoring a `.tres` `AnimationLibrary` is a content-pipeline handoff concern. AnimationPlayer defaults to `PROCESS_CALLBACK_IDLE` — verify this against `TransitionLayer.PROCESS_MODE_ALWAYS` so the ceremony does not pause if a pause race occurs. The lantern-flare particle emitter is owned by the (deferred) VFX System GDD #27 — this story triggers the emitter via an `AnimationPlayer` track but does NOT own the particle asset. Asset authoring for the ceremony `AnimationLibrary` may be a Visual/Feel collaboration with art-director; until the ceremony asset lands, a placeholder `.tres` with the correct timing envelope is acceptable.

**Control Manifest Rules (Foundation Layer, SceneManager)**:
- **Required**: Tween for 5 standard transitions (CROSS_FADE, SLIDE_*, FADE_TO_BLACK, PUSH_MODAL); `AnimationPlayer` exclusively for the CEREMONY transition. — ADR-0007
- **Required**: SceneManager MUST maintain `_active_transition_tween: Tween` reference and `kill()` any valid prior reference before `create_tween()`. — ADR-0007 (note: the ceremony path does NOT create a tween, so this guardrail is inactive during CEREMONY — but if a standard transition interrupts a ceremony, the tween-leak guard MUST re-engage; the ceremony AnimationPlayer MUST also be stopped via `animation_player.stop()`)

---

## Acceptance Criteria

*Verbatim from tr-registry:*

- [ ] TR-scene-manager-021: "Reserve AnimationPlayer for Victory Ceremony only (multi-node multi-property sequenced keyframes)"
- [ ] TR-scene-manager-025: "Ceremony 400-800ms with primary reward number rendered within first 100ms"

*Derived from GDD §D.1 and §C.6:*

- [ ] CEREMONY dispatcher in `SceneManager` calls `animation_player.play("ceremony")` — NOT `create_tween()`
- [ ] `AnimationLibrary` asset at `assets/animations/scene_manager/ceremony.tres` (or placeholder) has a track that sets the primary-reward-number node's `modulate.a` (or equivalent visibility property) to the visible state at t ≤ 0.100s
- [ ] If a `CEREMONY` transition is interrupted by another `request_screen` (via Story 010's queue path), `animation_player.stop()` is called before the new transition begins

---

## Implementation Notes

*Derived from ADR-0007 §Tween vs AnimationPlayer choice + GDD §D.1 Ceremony row:*

- Add a dedicated `AnimationPlayer` child to `TransitionLayer` (or to the Victory/Unlock Moment screen — architectural choice: for MVP, place it on `TransitionLayer` so the AnimationPlayer outlives any screen swap and can compose above the TransitionLayer's ColorRect). Node path: `MainRoot/TransitionLayer/CeremonyAnimationPlayer`.
- Create `assets/animations/scene_manager/ceremony.tres` as an `AnimationLibrary` resource containing a single `Animation` named `ceremony`. Total length = 600ms (default; tunable via `scene_manager_config.tres` `ceremony_min_ms = 400`, `ceremony_max_ms = 800`). Tracks:
  1. `TransitionLayer/CeremonyContainer/RewardNumber:modulate:a` — keyframe 0.0 = 0.0, keyframe 0.095 = 1.0 (primary reward number visible by 100ms). `InterpolationType.LINEAR`.
  2. `TransitionLayer/CeremonyContainer/LanternFlare:emitting` — keyframe 0.0 = false, keyframe 0.005 = true (particle emitter triggers immediately; asset owned by VFX GDD #27 — placeholder `GPUParticles2D` with empty process material is acceptable).
  3. `TransitionLayer/CeremonyContainer/ScreenTint:modulate:a` — keyframe 0.0 = 0.0, keyframe 0.400 = 0.35, keyframe 0.600 = 0.0 (warm-glow wash). Curve per Art Bible §7 custom easing.
  4. Method call track at t = 0.600: call `SceneManager._on_ceremony_finished()` — triggers state transition back to IDLE and emits `transition_complete`.
- `CeremonyContainer` is a `Control` child of `TransitionLayer`, visible only during CEREMONY transitions. `visible = false` at rest; set `true` when `_dispatch_ceremony()` starts; set `false` after `_on_ceremony_finished()` fires.
- Dispatcher:
  ```gdscript
  func _transition_ceremony(new_screen_callable: Callable) -> void:
      # No _active_transition_tween here — CEREMONY is AnimationPlayer only.
      _ceremony_container.visible = true
      _ceremony_animation_player.play("ceremony")
      # Swap happens mid-ceremony at a quieter moment (300ms) — scheduled via a
      # method call track OR via a one-shot timer; keep logic simple: swap NOW
      # (before the animation plays), so the new screen is behind the ceremony layer.
      new_screen_callable.call()
      # _on_ceremony_finished is called by the animation method-call track.

  func _on_ceremony_finished() -> void:
      _ceremony_container.visible = false
      _ceremony_animation_player.stop()
      state = State.IDLE
      transition_complete.emit(current_screen_id, TransitionType.CEREMONY)
      _drain_queued_request_if_any()
  ```
- Interrupt path: if a new `request_screen` arrives while CEREMONY is playing, it is queued (Story 010). When the queued request begins executing in `_on_ceremony_finished`, the ceremony animation has already stopped naturally. Defensive: `_execute_transition` at the head should call `_ceremony_animation_player.stop()` if it is still playing.
- `reduce_motion` interaction (handled fully in Story 009): when `reduce_motion == true`, the dispatcher instead calls `_instant_ceremony_cut()` which directly shows the reward number and calls `_on_ceremony_finished()` on the next frame — NO AnimationPlayer play, NO tween. Document the hook here; implement in Story 009.
- AnimationPlayer `process_callback` — set to `ANIMATION_PROCESS_IDLE` (default). Verify `CeremonyContainer` has `process_mode = PROCESS_MODE_ALWAYS` since it lives on `TransitionLayer` (which is ALWAYS) — the animation should not pause if a pause race occurs (ceremony is typically a post-victory moment where modals are not expected, but defensive).

---

## Out of Scope

- Story 005: Tween-based 5 standard transitions (separate primitive; different story)
- Story 008: `scene_boundary_persist` emission on `victory_moment` EXIT — that's a Save/Load contract handled in Story 008; this story only runs the CEREMONY animation on entry to `victory_moment`
- Story 009: `reduce_motion` clamp — replaces CEREMONY with instant cut; this story documents the hook and implements the default-motion path
- VFX GDD #27 lantern-flare particle asset — placeholder sufficient; real asset lands in VFX epic

---

## QA Test Cases

*CEREMONY is a Visual/Feel transition; use Visual/Feel QA format for the ceremony itself, plus standard Given/When/Then for the API contract.*

- **TR-scene-manager-021 (API contract)**: AnimationPlayer is the chosen primitive
  - **Given**: SceneManager code
  - **When**: grep for `TransitionType.CEREMONY` branch in the transition dispatcher
  - **Then**: the CEREMONY branch calls `_ceremony_animation_player.play("ceremony")`; no `create_tween()` appears inside the CEREMONY dispatcher
  - **Edge cases**: a developer later adding a tween for a CEREMONY-specific tint would be a spec regression; CI grep asserts CEREMONY branch contains only AnimationPlayer calls (allow helper method calls but not direct tween creation)

- **TR-scene-manager-025**: Reward number visible within 100ms
  - **Given**: CEREMONY transition triggered with a named reward-number node under `CeremonyContainer`
  - **When**: `_transition_ceremony` is called; test samples `reward_number.modulate.a` at `Time.get_ticks_msec() + 100`
  - **Then**: `modulate.a >= 0.95` within the 100ms mark (using a ±5ms tolerance for scheduling jitter)
  - **Edge cases**: at 30fps sustained, 100ms is exactly 3 frames — the keyframe at t=0.095s is well-placed to land on frame 3; test logs actual fps at capture time

- **AC (Visual/Feel — CEREMONY default-motion path)**:
  - **Setup**: launch game in debug build; trigger a Victory moment (or invoke `SceneManager.request_screen("victory_moment", SceneManager.TransitionType.CEREMONY)` directly via a debug console)
  - **Verify**: (a) lantern-flare particles visible within first 50ms; (b) reward number fades in by 100ms; (c) warm screen tint peaks near 400ms and fades back to transparent by 600ms; (d) total ceremony window between 400 and 800ms (default 600ms)
  - **Pass condition**: the sequence reads as a "deliberate reward moment" per Art Bible §7 "stately warm snappiness"; no visual clipping, no stuck-at-end state; state returns to IDLE; screenshot saved to `production/qa/evidence/ceremony-sequence-<date>/`

- **ADR-0007 / Story 010 interrupt path**: `animation_player.stop()` on interrupt
  - **Given**: a CEREMONY transition is playing (AnimationPlayer active)
  - **When**: a new `request_screen` is queued via Story 010's queue path and begins executing in `_on_ceremony_finished`; OR the ceremony completes naturally
  - **Then**: `_ceremony_animation_player.is_playing()` returns false after `_on_ceremony_finished`; `CeremonyContainer.visible == false`
  - **Edge cases**: interrupting mid-ceremony (if Story 010 chooses to honor a pre-empt) must call `animation_player.stop()` BEFORE the new transition starts — test asserts via a spy on the AnimationPlayer

---

## Test Evidence

**Story Type**: Integration (with Visual/Feel validation)
**Required evidence**: `tests/integration/scene_manager/ceremony_transition_test.gd` for the API contract + reward-number-within-100ms assertion. Additionally `tests/evidence/ceremony-sequence-<date>.md` for the Visual/Feel walkthrough and screenshot.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (TransitionLayer exists; `CeremonyContainer` added as child), Story 003 (`_execute_transition` dispatches on TransitionType), Story 004 (Screen base class — Victory/Unlock Moment screens extend it)
- **Unlocks**: Story 008 (`scene_boundary_persist` emits on victory_moment EXIT — independent of the CEREMONY entry animation), Story 009 (`reduce_motion` replaces CEREMONY with instant cut)
