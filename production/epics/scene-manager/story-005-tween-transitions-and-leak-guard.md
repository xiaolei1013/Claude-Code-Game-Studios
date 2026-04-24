# Story 005: Tween-based 5 standard transitions + `_active_transition_tween` leak guard + H-01 timing

> **Epic**: scene-manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/scene-screen-manager.md`
**Requirements**: TR-scene-manager-020, TR-scene-manager-023, TR-scene-manager-024, TR-scene-manager-026, TR-scene-manager-029, TR-scene-manager-032, TR-scene-manager-033, TR-scene-manager-034
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary — §Tween vs AnimationPlayer choice + Risks Notes 1 & 2)
**ADR Decision Summary**: All five standard transitions (`CROSS_FADE`, `SLIDE_UP`, `SLIDE_LEFT`, `SLIDE_DOWN`, `FADE_TO_BLACK`, `PUSH_MODAL`) use `create_tween()` — single-property interpolations with fixed easing. SceneManager MUST maintain a `_active_transition_tween: Tween` reference and `kill()` any valid prior reference before each new `create_tween()` call — this is an implementation requirement, not advisory, to satisfy H-11 (no memory leaks) and to prevent orphan tweens from modulating freed nodes. Lifecycle order is strict: `A.on_exit() → tween start → tween end → B.on_enter()`. AC H-01 (BLOCKING) requires cross-fade total wall-clock of 150ms ± 10ms.

**Engine**: Godot 4.6 | **Risk**: MEDIUM-HIGH
**Engine Notes**: `create_tween()` returns a `Tween` bound to the calling node's scene tree; default pause mode is `TWEEN_PAUSE_BOUND` (inherits pausable state from the node that created it) — since SceneManager is an autoload (PROCESS_MODE_INHERIT → defaults to PAUSABLE unless overridden), transition tweens must be created on a `PROCESS_MODE_ALWAYS` node so they don't freeze if a pause race occurs mid-transition. Preferred pattern: `_active_transition_tween = _transition_layer.create_tween()` (TransitionLayer is PROCESS_MODE_ALWAYS). `Tween.kill()` is cheap and idempotent on already-invalid tweens; `Tween.is_valid()` check is the safety gate. `ease_out_quad` is the standard easing for all slide transitions (Art Bible "heavy objects settling into place"). Screen-local tweens (touch-feedback pulses etc.) are outside this story — they default to TWEEN_PAUSE_BOUND inherited from the screen, which is usually correct (ADR-0007 Risks Note 1).

**Control Manifest Rules (Foundation Layer, SceneManager)**:
- **Required**: Tween for 5 standard transitions (`CROSS_FADE`, `SLIDE_*`, `FADE_TO_BLACK`, `PUSH_MODAL`); `AnimationPlayer` exclusively for the `CEREMONY` transition. — ADR-0007
- **Required**: SceneManager MUST maintain `_active_transition_tween: Tween` reference and `kill()` any valid prior reference before `create_tween()`. — ADR-0007
- **Guardrail**: Standard cross-fade: 150 ms ± 10 ms — [BLOCKING AC H-01]. — ADR-0007

---

## Acceptance Criteria

*Verbatim from tr-registry:*

- [ ] TR-scene-manager-020: "Use create_tween() for all MVP transitions (cross-fade, slide, fade-to-black, push modal) - single-property interpolations"
- [ ] TR-scene-manager-023: "Cross-fade 150ms total (75ms out + 10ms overlap + 75ms in) linear alpha"
- [ ] TR-scene-manager-024: "Slide transitions 180ms with ease_out_quad; fade-to-black 300ms linear"
- [ ] TR-scene-manager-026: "Touch feedback: 1.05x scale pulse 80ms owned by screen nodes (not SceneManager)" — documented as NOT owned by this story; the API surface (Screen's `transition_override_ms`) is respected
- [ ] TR-scene-manager-029: "transition_input_policy enum: BLOCK (default, silent drop) or QUEUE_ONE" — enum declared; BLOCK path is wired (QUEUE_ONE is documented-but-not-recommended per GDD §G)
- [ ] TR-scene-manager-032: "Cross-fade timing bound 150ms +/- 10ms; logged to production/qa/evidence/screen-manager-timing"
- [ ] TR-scene-manager-033: "Lifecycle order: A.on_exit -> transition starts -> transition ends -> B.on_enter; never interleaved"
- [ ] TR-scene-manager-034: "Emits screen_changed(new_screen_id, old_screen_id) signal for Audio System crossfade subscription"

*Verbatim from GDD §H:*

- [ ] **AC H-01 (BLOCKING, Integration+Performance)**: Given IDLE + current screen ≠ `guild_hall`, when `request_screen("guild_hall", TransitionType.CROSS_FADE)` is called, then outgoing `on_exit` fires first; cross-fade starts within the same frame; incoming `on_enter` fires; IDLE reached; total wall-clock from call to IDLE is **150ms ± 10ms**; logged to `production/qa/evidence/screen-manager-timing-[date].md`.
- [ ] **AC H-02 (BLOCKING, Logic)**: Given screen A active and screen B a different registered screen, when `request_screen(B.id, any_transition)` completes, then call order is `A.on_exit() → transition_start → transition_end → B.on_enter()`; `A.on_exit` never skipped; `B.on_enter` never called before `A.on_exit` returns.

---

## Implementation Notes

*Derived from ADR-0007 §Tween vs AnimationPlayer choice + Risks Notes 1 & 2:*

- Maintain a single `_active_transition_tween: Tween` member on `SceneManager`. Before every `create_tween()` in the transition dispatcher:
  ```gdscript
  if _active_transition_tween and _active_transition_tween.is_valid():
      _active_transition_tween.kill()
  _active_transition_tween = _transition_layer.create_tween()
  ```
  Creating the tween ON the `TransitionLayer` (PROCESS_MODE_ALWAYS) guarantees the tween is not frozen by a race-condition pause.
- Cross-fade implementation (150ms total, 75 + 10-overlap + 75, linear alpha, on `TransitionLayer`'s full-screen `ColorRect`):
  ```gdscript
  func _transition_cross_fade(new_screen_callable: Callable) -> void:
      var rect: ColorRect = _transition_color_rect
      rect.modulate.a = 0.0
      _active_transition_tween = _transition_layer.create_tween()
      _active_transition_tween.tween_property(rect, "modulate:a", 1.0, 0.075)
      _active_transition_tween.tween_callback(new_screen_callable)  # swap happens at peak opacity
      _active_transition_tween.tween_interval(0.010)                # 10ms overlap hold
      _active_transition_tween.tween_property(rect, "modulate:a", 0.0, 0.075)
      _active_transition_tween.finished.connect(_on_transition_finished, CONNECT_ONE_SHOT)
  ```
  The `new_screen_callable` invokes the node-swap (`_complete_swap_body`) at the 75ms mark — the incoming screen replaces the outgoing one BEHIND a fully-opaque ColorRect, so no visual cut is seen. Per ADR-0007's node-swap contract: `on_exit` fired before tween start; `on_enter` fires after the callable (still under the ColorRect).
- Slide transitions (180ms, `ease_out_quad`): tween the `ScreenContainer` position delta (or the incoming screen's position). `SLIDE_UP`, `SLIDE_DOWN`, `SLIDE_LEFT` each differ only in the axis+sign of the start offset.
- `FADE_TO_BLACK` (300ms total: 150ms fade-out + 50ms hold + 100ms fade-in): same `ColorRect` as cross-fade, different timing constants; color stays opaque black during the 50ms hold where the swap occurs.
- `PUSH_MODAL` (150-200ms, `ease_out_quad`, slide down from top of viewport): used by the overlay API (Story 007) as a helper — document the shared tween in this story, but the overlay push flow lives in Story 007.
- Load `scene_manager_config.tres` once at init (Story 003 loads the Resource; this story reads the timing knobs):
  - `default_crossfade_ms: int = 150` (safe range 80–300)
  - `slide_duration_ms: int = 180` (safe range 100–300)
  - `fade_to_black_ms: int = 300` (safe range 200–500)
  - `touch_feedback_scale: float = 1.05`
  - `touch_feedback_ms: int = 80`
  - `transition_input_policy: int = INPUT_POLICY_BLOCK` (0 = BLOCK, 1 = QUEUE_ONE; BLOCK is the only supported path in this story — QUEUE_ONE is declared but logs a `push_warning("QUEUE_ONE policy not implemented in MVP — falling back to BLOCK")` if selected)
- Respect per-screen override: if `incoming_screen.transition_override_ms > 0`, replace the matching knob for this transition only.
- Emit signals at the right moments:
  - `screen_changed(new_id, old_id)` — at the **start** of the tween callback (pre-`on_enter`), so Audio System can crossfade music with the visual transition rather than on the back-edge
  - `transition_complete(screen_id, transition_type)` — in the `finished` handler, after state returns to IDLE
- `_on_transition_finished`:
  ```gdscript
  func _on_transition_finished() -> void:
      state = State.IDLE
      transition_complete.emit(current_screen_id, _current_transition_type)
      _drain_queued_request_if_any()
  ```
- Evidence logging: on every CROSS_FADE transition, write a single line to `production/qa/evidence/screen-manager-timing-[date].md` with `start_ms`, `end_ms`, `duration_ms`, and pass/fail vs the 140–160ms window. The test harness can then aggregate across 10+ transitions. (Debug-build only — gate with `OS.is_debug_build()`.)
- `reduce_motion` clamp is NOT wired in this story — Story 009 owns that. Document in this story that the current timing is the "full-motion" path.

---

## Out of Scope

- Story 006: CEREMONY transition via `AnimationPlayer` (different tech; separate story)
- Story 007: Modal overlay push/pop (uses `PUSH_MODAL` timing from this story but owns its own state machine)
- Story 009: `reduce_motion` clamp to 50ms across all standard transitions
- Story 010: Transition input-block `MOUSE_FILTER_STOP` activation + queue-with-max-1 edge cases
- Touch feedback per-button pulse (1.05× scale, 80ms) — owned by individual screen nodes per TR-026 and ADR-0008's `UIFramework.wire_touch_feedback`

---

## QA Test Cases

- **AC H-01 (BLOCKING) / TR-scene-manager-023 / TR-scene-manager-032**: Cross-fade within 150ms ± 10ms
  - **Given**: SceneManager in IDLE with current screen ≠ `guild_hall`; `reduce_motion = false`
  - **When**: `request_screen("guild_hall", TransitionType.CROSS_FADE)` called; test uses `Time.get_ticks_msec()` to mark start and listens for `transition_complete` for end
  - **Then**: elapsed wall-clock is within **140 ≤ t ≤ 160 ms**; evidence line written to `production/qa/evidence/screen-manager-timing-<date>.md`
  - **Edge cases**: running headless at >60fps virtual rates may compress timing; test asserts `OS.get_main_loop().physics_interpolation == false` and runs at 60fps fixed. At 30fps sustained, the ±10ms bound is half a frame — OQ flagged in GDD §I; test harness logs fps at capture time

- **AC H-02 (BLOCKING) / TR-scene-manager-033**: Lifecycle hook order
  - **Given**: screen A (placeholder spy) and screen B (placeholder spy) registered; A is current
  - **When**: `request_screen("screen_b", TransitionType.CROSS_FADE)`; both spies record timestamps in their hooks
  - **Then**: spy A's `on_exit` timestamp < tween-start timestamp < tween-end timestamp < spy B's `on_enter` timestamp; `A.on_exit` fired exactly once; `B.on_enter` fired exactly once
  - **Edge cases**: Hook that `await`s inside `on_exit` must not delay the tween start (the contract is that the hook returns before the tween starts — `await`-based hooks are advisory-bad-practice and flagged in review, but this story asserts synchronous ordering of the returned coroutine)

- **TR-scene-manager-020 / TR-scene-manager-024**: Tween is the chosen primitive with correct timings + easing
  - **Given**: SceneManager code
  - **When**: grep for `create_tween` in transition dispatchers
  - **Then**: all five standard transitions use `create_tween()`; no `AnimationPlayer.play()` or `AnimationPlayer.queue()` appears in standard-transition code paths; slide dispatchers use `Tween.TRANS_QUAD` + `Tween.EASE_OUT` (`ease_out_quad`)
  - **Edge cases**: a developer using `AnimationPlayer` for a slide transition would be a spec regression — code review + CI grep (optional) catches it

- **ADR-0007 Risks Note 2 / `_active_transition_tween` leak guard**: Prior tween killed before new one created
  - **Given**: a test that issues two back-to-back `request_screen` calls via the queue path (first call starts a tween; second call is queued and fires immediately after first tween completes)
  - **When**: the queued request triggers `_execute_transition` which calls `_transition_cross_fade`
  - **Then**: before `create_tween()`, `_active_transition_tween.is_valid()` returns false (because the first tween completed and Godot invalidated it); `kill()` is a no-op; the new tween is created cleanly. Additional probe: force a mid-transition abort (Story 008 save_failed) and assert the in-progress tween was `kill()`'d
  - **Edge cases**: orphan-tween leak manifests as ColorRect alpha "sticking" or "double fading" — visual test evidence in `production/qa/evidence/` also documents this

- **TR-scene-manager-034**: `screen_changed` signal emission
  - **Given**: test subscriber connected to `SceneManager.screen_changed`
  - **When**: cross-fade from screen A to screen B
  - **Then**: subscriber receives exactly one emission with `(new_id="screen_b", old_id="screen_a")`; emission happens before `on_enter` on screen B (so Audio System can schedule music crossfade with lead time)
  - **Edge cases**: same-screen no-op (Story 003) must NOT emit `screen_changed`

---

## Test Evidence

**Story Type**: Logic (with Integration+Performance validation for H-01)
**Required evidence**: `tests/unit/scene_manager/tween_transitions_test.gd` AND `tests/integration/scene_manager/crossfade_timing_test.gd` — both must exist and pass. Timing evidence doc at `production/qa/evidence/screen-manager-timing-<date>.md`.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (TransitionLayer + ColorRect exist), Story 003 (`_execute_transition` infrastructure), Story 004 (`Screen.transition_override_ms` export)
- **Unlocks**: Story 006 (CEREMONY transition parallel path), Story 007 (PUSH_MODAL timing reused for modal push), Story 008 (transition can be aborted mid-tween), Story 009 (`reduce_motion` clamps into this story's timing constants), Story 010 (H-11 memory-leak soak exercises this story's leak-guard)
