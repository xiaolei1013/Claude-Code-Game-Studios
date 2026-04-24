# Story 010: Edge cases (input-block, back-to-back queue, BG mid-transition) + performance verification (H-10, H-11, H-12)

> **Epic**: scene-manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration (Performance)
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/scene-screen-manager.md`
**Requirements**: TR-scene-manager-008, TR-scene-manager-013, TR-scene-manager-017, TR-scene-manager-030, TR-scene-manager-031
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0007 (primary — §Queue-with-max-1 back-to-back transition policy + §Transition input-blocking + §App-backgrounded mid-transition + performance budgets H-10/H-11) + ADR-0008 (`MOUSE_FILTER_STOP` does NOT cascade to children — LOAD-BEARING; the full-screen input-block Control is authoritative) + ADR-0005 (TickSystem's `NOTIFICATION_APPLICATION_PAUSED` / `WM_WINDOW_FOCUS_OUT` — SceneManager defers its own handling until active transition completes)
**ADR Decision Summary**: This final story verifies the bullet-proofing invariants: (1) transition input-block via full-screen `Control` with `MOUSE_FILTER_STOP` on `TransitionLayer`; (2) queue-with-max-1 policy — `request_screen` during TRANSITIONING queues; additional calls overwrite with `push_warning`; (3) app backgrounded mid-transition — the active transition completes BEFORE the background handler runs; (4) AC H-10 performance — SceneManager code path (excluding tween + DataRegistry + `_ready`) completes in <5ms on min-spec mobile; (5) AC H-11 — zero memory leaks over 10 consecutive transitions cycling ≥3 distinct screens; (6) AC H-12 ADVISORY — touch feedback begins within 16ms of input, 80ms duration (owned per-button per TR-026; SceneManager only blocks taps during TRANSITIONING per H-04).

**Engine**: Godot 4.6 | **Risk**: MEDIUM-HIGH
**Engine Notes**: Full-screen `Control` child of `TransitionLayer` with `mouse_filter = MOUSE_FILTER_STOP`. `MOUSE_FILTER_STOP` does NOT cascade — a sibling child Control with `MOUSE_FILTER_STOP` anchored full-rect is the only way to block pointer events from reaching the `ScreenContainer` underneath (per ADR-0008 LOAD-BEARING note). Active only during TRANSITIONING; `mouse_filter` is set to `MOUSE_FILTER_IGNORE` on return to IDLE. Performance: `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)` is the baseline measurement for H-11. Soak test: 10 consecutive `request_screen` calls cycling through ≥3 distinct screens must return `OBJECT_NODE_COUNT` to baseline ± 2. Per-call timing via `Time.get_ticks_usec()` deltas measured OUTSIDE the tween+DataRegistry work (bracket the SceneManager own code). App-background: `NOTIFICATION_WM_WINDOW_FOCUS_OUT` is the OS trigger; SceneManager sets `_pending_background_action = true` and waits for `tween_finished` / `_on_ceremony_finished` / `_on_transition_finished`. TickSystem is the owner of the actual BG-persist heartbeat per ADR-0005 — SceneManager does NOT duplicate.

**Control Manifest Rules (Foundation Layer, SceneManager)**:
- **Required**: Transition input-block via full-screen Control on `TransitionLayer` with `mouse_filter = MOUSE_FILTER_STOP`; silent-drop policy (taps consumed + discarded, not queued). — ADR-0007
- **Required**: Back-to-back transitions: queue depth max 1; overwriting fires `push_warning` (NOT error). — ADR-0007
- **Required**: App backgrounded mid-transition: in-progress transition completes BEFORE background handler runs. — ADR-0007
- **Forbidden**: Never assume `MOUSE_FILTER_STOP` cascades to children — only `MOUSE_FILTER_IGNORE` cascades in 4.5+. — ADR-0007, ADR-0008
- **Guardrail**: Transition overhead (SceneManager code path, excluding tween / DataRegistry / `_ready`): <5 ms on min-spec mobile — [BLOCKING AC H-10]. — ADR-0007
- **Guardrail**: Zero memory leaks over 10 consecutive transitions — [BLOCKING AC H-11]. — ADR-0007
- **Guardrail**: Touch feedback pulse: begins within 16 ms of input receipt; 80 ms duration — [ADVISORY AC H-12]. — ADR-0007, ADR-0008

---

## Acceptance Criteria

*Verbatim from tr-registry:*

- [ ] TR-scene-manager-008: "TransitionLayer input-block: full-screen Control with mouse_filter = MOUSE_FILTER_STOP during active transition"
- [ ] TR-scene-manager-013: "Back-to-back request: queue with max-1 slot; additional calls overwrite queued with push_warning"
- [ ] TR-scene-manager-017: "App-background: await active transition completion (<=300ms) before handling; set _pending_background_action"
- [ ] TR-scene-manager-030: "Transition overhead (excluding tween time) <5ms on min-spec mobile for request_screen code path"
- [ ] TR-scene-manager-031: "No memory leaks: Performance.OBJECT_NODE_COUNT returns to baseline +/-2 after 10 transitions cycling >=3 screens"

*Verbatim from GDD §H:*

- [ ] **AC H-04 (BLOCKING, Integration)**: Given a cross-fade transition is in progress (TRANSITIONING state), when a simulated touch/mouse click reaches the input layer, then event consumed by input-block layer; doesn't propagate to any screen; no button `pressed` signal fires; no gameplay state mutation; input unblocks in same frame manager returns to IDLE.
- [ ] **AC H-05 (BLOCKING, Logic)**: Given a transition from A to B is in progress (TRANSITIONING), when `request_screen("screen_c", any_transition)` is called before first transition completes, then manager queues the second request in `_queued_request` slot; executes immediately when first transition reaches IDLE. Additional calls during same TRANSITIONING window overwrite the queued request with `push_warning` (max 1 in queue); no crash, no orphaned screen instance, no stuck TRANSITIONING state.
- [ ] **AC H-09 (BLOCKING, Logic)**: Given a transition is in progress (TRANSITIONING), when OS sends `NOTIFICATION_WM_WINDOW_FOCUS_OUT`, then in-progress transition completes fully before background handler runs; `on_enter` and `on_exit` not interrupted; manager reaches IDLE before yielding to background; after resume, manager is IDLE with correct destination screen active.
- [ ] **AC H-10 (BLOCKING, Performance)**: Given SceneManager on minimum-spec mobile, when `request_screen(any, any_transition)` called, then scene manager's own code path (excluding tween time, screen `_ready` time, DataRegistry queries) completes in <**5ms** wall-clock; logged to `production/qa/evidence/screen-manager-perf-[date].md`.
- [ ] **AC H-11 (BLOCKING, Performance)**: Given scene manager in clean IDLE, when 10 consecutive `request_screen` calls cycling through ≥3 distinct screens, then memory (via `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)`) returns to baseline ±2 nodes; no orphaned `Screen` instances in SceneTree; `queue_free` confirmed called on each outgoing screen in same frame its `on_exit` returns.
- [ ] **AC H-12 (ADVISORY, Integration)**: Given any interactive button in a managed screen, when touch/click press event received, then 1.05× scale pulse tween begins within **16ms** of input receipt (1 frame at 60fps); completes after **80ms**; pulse fires in IDLE and PAUSED states (not in TRANSITIONING — H-04 blocks input).

---

## Implementation Notes

*Derived from ADR-0007 §Queue-with-max-1, §Transition input-blocking, §App-backgrounded mid-transition, and §Performance Implications:*

### Transition input-block (TR-008 / AC H-04)

- At `MainRoot.tscn` (Story 001) a placeholder `Control` child of `TransitionLayer` already exists. This story wires its activation:
  ```gdscript
  @onready var _transition_input_blocker: Control = $MainRoot/TransitionLayer/InputBlocker

  func _set_input_blocker(active: bool) -> void:
      # Full-rect anchoring + MOUSE_FILTER_STOP is the authoritative block —
      # ADR-0008 LOAD-BEARING: MOUSE_FILTER_STOP does NOT cascade, but a single
      # full-screen Control ABOVE ScreenContainer does block all pointer events.
      _transition_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
      _transition_input_blocker.visible = active  # invisible in IDLE to avoid draw call
  ```
- Engage at transition start (inside `_execute_transition` / `_proceed_with_transition`); disengage in `_on_transition_finished` / `_on_ceremony_finished`. The disengage happens in the same frame state returns to IDLE (no lingering block).
- `visible = false` when idle is a micro-optimization: CanvasLayer still composites invisible Controls but the input system short-circuits faster. Document the choice.

### Queue-with-max-1 policy (TR-013 / AC H-05)

- The `_queued_request` slot is already established in Stories 002/003. This story adds the explicit `push_warning` on overwrite (if not already in Story 003) and verifies edge cases:
  ```gdscript
  # Already in Story 003's request_screen body — restated here for clarity:
  if state == State.TRANSITIONING:
      if _queued_request:
          push_warning("[SceneManager] Overwriting queued request '%s' with '%s'" %
              [_queued_request.get("screen_id"), screen_id])
      _queued_request = {"screen_id": screen_id, "transition": transition}
      return
  ```
- Edge cases to lock in this story's tests:
  1. Single back-to-back: A→B in progress; C requested → C executes after B lands. Final state: `current_screen_id == "c"`.
  2. Triple back-to-back: A→B in progress; C requested → queue has C; D requested → queue overwrites to D (push_warning); final state: `current_screen_id == "d"`; `C` never became current.
  3. Same-screen queued request: A→B in progress; request `current_screen_id == "a"` (same as starting screen) — the queue DOES store this, and when B lands, the queued request becomes a same-screen no-op B→B (push_warning, stay on B). Alternative: detect same-final at queue time — the GDD §E "Same-screen request" rule treats this as a no-op silent path; implement consistent behavior.
  4. Queue drain on save_failed (Story 008 abort): transition aborted before TRANSITIONING entered; queued request should STILL execute after modal closes — test verifies.
  5. Queue + modal: a `push_overlay` arriving during TRANSITIONING lands in `_queued_modal` (separate slot); both the queued request AND queued modal drain in order on IDLE (request first per ADR-0007 Risks row 4).

### App backgrounded mid-transition (TR-017 / AC H-09)

- Handle OS notifications in `_notification`:
  ```gdscript
  var _pending_background_action: bool = false

  func _notification(what: int) -> void:
      match what:
          NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
              if state == State.TRANSITIONING:
                  _pending_background_action = true
              else:
                  _yield_to_background()
          NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
              # TickSystem owns the offline_elapsed_seconds emission per ADR-0005;
              # SceneManager does not double-trigger. If offline gains arrive, Story 003
              # TR-039 handles the return_to_app route via OfflineProgressionEngine hand-off.
              pass

  func _yield_to_background() -> void:
      # No-op on SceneManager side — TickSystem's heartbeat fires independently.
      # Per ADR-0005, SceneManager MUST NOT duplicate the persist.
      pass
  ```
  In `_on_transition_finished` / `_on_ceremony_finished`, after state → IDLE:
  ```gdscript
  if _pending_background_action:
      _pending_background_action = false
      _yield_to_background()
  ```

### Performance — H-10 and H-11 instrumentation

- H-10 measurement: bracket the SceneManager own-code path explicitly. Do NOT include tween wall-clock (that's Story 005's H-01 measurement). Do NOT include `DataRegistry.resolve` (DataRegistry boot scan is ADR-0006's AC-DLS-07). Do NOT include the incoming screen's `_ready`:
  ```gdscript
  func request_screen(screen_id: String, transition: int = TransitionType.CROSS_FADE) -> void:
      var t0 := Time.get_ticks_usec() if OS.is_debug_build() else 0
      # ... existing body ...
      if OS.is_debug_build():
          var elapsed_us := Time.get_ticks_usec() - t0
          _log_perf_sample(screen_id, elapsed_us)
          # Split measurement: _execute_transition's own wrapper time
          # (excluding tween.play) goes into a separate bucket.
  ```
  Aggregate samples into `production/qa/evidence/screen-manager-perf-<date>.md` with p50/p95 per transition type. Target: p95 < 5ms on min-spec mobile.
- H-11 soak test (lives in the test file, not in SceneManager):
  ```gdscript
  func test_ten_transition_soak_no_memory_leak() -> void:
      await get_tree().process_frame   # settle baseline
      var baseline := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
      var screens := ["guild_hall", "roster", "recruit"]
      for i in range(10):
          SceneManager.request_screen(screens[i % 3], SceneManager.TransitionType.CROSS_FADE)
          await SceneManager.transition_complete   # each completes before next
      await get_tree().process_frame   # settle final queue_frees
      await get_tree().process_frame
      var final := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
      assert(abs(final - baseline) <= 2, "Node count drift %d > ±2" % (final - baseline))
  ```

### Touch feedback (H-12 ADVISORY)

- Per TR-026, per-button pulse is NOT owned by SceneManager. This story verifies:
  1. During TRANSITIONING, the input-blocker swallows taps — no pulse fires (H-04 enforcement).
  2. During IDLE and PAUSED, the per-button pulse (owned by the UI Framework's `wire_touch_feedback` helper per ADR-0008) fires within 16ms and lasts 80ms.
- The test lives in UI Framework territory; this story cross-references and asserts the non-fire condition during TRANSITIONING.

---

## Out of Scope

- Story 005: The actual tween timing (H-01 150ms ± 10ms is Story 005's evidence)
- Story 006: CEREMONY AnimationPlayer internals
- Story 008: `scene_boundary_persist` — Story 008's abort path is tested separately; this story tests the INTERACTION with queued requests mid-persist-gate
- TickSystem's own BG-persist heartbeat — owned by ADR-0005 / tick-system epic
- Per-button touch feedback pulse implementation — owned by ADR-0008 / UI Framework epic

---

## QA Test Cases

- **TR-scene-manager-008 / AC H-04 (BLOCKING)**: Input blocked during TRANSITIONING
  - **Given**: SceneManager IDLE; `request_screen("roster", CROSS_FADE)` called; state == TRANSITIONING; test spy on a button in `current_screen`
  - **When**: `Input.parse_input_event(InputEventMouseButton.new(...))` simulates a click at the button's screen position
  - **Then**: button's `pressed` signal does NOT fire; `_transition_input_blocker.mouse_filter == MOUSE_FILTER_STOP` for the duration of TRANSITIONING; filter returns to `MOUSE_FILTER_IGNORE` in the same frame state returns to IDLE
  - **Edge cases**: rapid tap burst during TRANSITIONING — all consumed; none queued; none fire after IDLE

- **TR-scene-manager-013 / AC H-05 (BLOCKING)**: Queue-with-max-1 edge cases
  - **Given**: SceneManager IDLE; A is current
  - **When**: sequence (i) `request_screen("b")`; (ii) `request_screen("c")` (queue slot = c); (iii) `request_screen("d")` (queue overwrites, push_warning fires, slot = d); await transition_complete loop
  - **Then**: after (i) → TRANSITIONING; after (ii) → queue has c; after (iii) → queue has d + push_warning logged; after first tween completes → d begins transition; after second tween completes → state IDLE, `current_screen_id == "d"`; C was NEVER the current screen; exactly one `push_warning` fired
  - **Edge cases**: same-screen queued request (request `a` while transitioning A→B) — when B lands, queued request to go back to A executes normally (A→B→A is valid). Queue + modal interleaving — request_screen + push_overlay during TRANSITIONING both queue; on IDLE, request executes first, then modal opens (per ADR-0007 Risks row 4).

- **TR-scene-manager-017 / AC H-09 (BLOCKING)**: Backgrounded mid-transition
  - **Given**: SceneManager TRANSITIONING; a cross-fade is in flight
  - **When**: test fires `SceneManager._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)` mid-tween
  - **Then**: `_pending_background_action == true`; tween runs to completion; `_on_transition_finished` reaches IDLE; `_yield_to_background` called AFTER state == IDLE; `current_screen` is the destination screen; no interruption of `on_enter` / `on_exit`
  - **Edge cases**: notification firing during CEREMONY — same pattern: `_on_ceremony_finished` runs to completion before `_yield_to_background`; `NOTIFICATION_WM_WINDOW_FOCUS_OUT` on desktop behaves identically to mobile `APPLICATION_PAUSED`

- **TR-scene-manager-030 / AC H-10 (BLOCKING, Performance)**: SceneManager overhead <5ms
  - **Given**: SceneManager in IDLE on a Godot debug build running on a reference "min-spec mobile" profile (documented in evidence as device + OS)
  - **When**: 100 `request_screen` calls cycling across ≥3 screens; each measures `Time.get_ticks_usec()` wrapper around the SceneManager own-code path (EXCLUDES tween animation wall-clock AND incoming screen `_ready` AND DataRegistry queries)
  - **Then**: p95 < 5000 µs (5ms); p99 < 8ms (budget headroom); results logged to `production/qa/evidence/screen-manager-perf-<date>.md`
  - **Edge cases**: first-call warm-up is discarded (p95 over samples 2..100). Debug-build overhead is called out; release build expected to be tighter

- **TR-scene-manager-031 / AC H-11 (BLOCKING, Performance)**: No memory leaks over 10 transitions
  - **Given**: SceneManager clean IDLE; `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)` sampled as baseline after 2 frame-settle waits
  - **When**: 10 consecutive `request_screen` calls cycling through screens `["guild_hall", "roster", "recruit"]` (indices i % 3); await `transition_complete` between each
  - **Then**: after 2 frame-settle waits following the 10th completion, node count is within baseline ± 2; `ScreenContainer.get_child_count() == 1`; no "PREVIOUS" Screen-typed nodes detectable via `get_tree().get_nodes_in_group()` scan
  - **Edge cases**: forced leak probe — a fixture Screen that deliberately FAILS to `queue_free` on `on_exit` must cause the test to FAIL — demonstrates the test is detective

- **AC H-12 (ADVISORY)**: Touch feedback during TRANSITIONING vs IDLE
  - **Given**: a button wired with `UIFramework.wire_touch_feedback(button)` (per ADR-0008); SceneManager cycling through IDLE → TRANSITIONING → IDLE
  - **When**: tap at 3 different phases — (1) in IDLE; (2) during TRANSITIONING; (3) back in IDLE
  - **Then**: (1) pulse begins within 16ms, lasts 80ms; (2) no pulse (tap consumed by input-blocker); (3) pulse begins within 16ms
  - **Edge cases**: touch feedback ownership is UI Framework — this test is a CROSS-EPIC assertion that SceneManager does not interfere during IDLE/PAUSED

---

## Test Evidence

**Story Type**: Integration (Performance) — BLOCKING on H-04, H-05, H-09, H-10, H-11; ADVISORY on H-12
**Required evidence**:
- `tests/integration/scene_manager/input_block_during_transition_test.gd` (H-04)
- `tests/integration/scene_manager/back_to_back_queue_max_one_test.gd` (H-05)
- `tests/integration/scene_manager/background_mid_transition_test.gd` (H-09)
- `tests/integration/scene_manager/transition_overhead_perf_test.gd` (H-10) + `production/qa/evidence/screen-manager-perf-<date>.md`
- `tests/integration/scene_manager/memory_leak_soak_test.gd` (H-11)
- Cross-reference to UI Framework `tests/integration/ui_framework/touch_feedback_test.gd` (H-12)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: All prior stories (001–009). This is the final verification story: the invariants and performance budgets can only be measured once the full SceneManager is assembled.
- **Unlocks**: Epic DoD — all 12 GDD acceptance criteria verified; CI grep + memory-leak soak + transition-overhead evidence in place.
