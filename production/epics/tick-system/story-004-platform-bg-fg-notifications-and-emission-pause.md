# Story 004: Platform BG/FG notifications and tick-emission pause with residual preservation

> **Epic**: tick-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-008, TR-time-009, TR-time-010, TR-time-015, TR-time-034
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract
**ADR Decision Summary**: Tick emission is foreground-only and freezes on the platform BG trigger (`NOTIFICATION_APPLICATION_PAUSED` mobile / `NOTIFICATION_WM_WINDOW_FOCUS_OUT` desktop), preserving the fractional-delta accumulator residual across pause; FG return does NOT re-compute offline elapsed. UI pause is a substate of FOREGROUND — `_process` still runs, only `tick_fired` emission is suppressed.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Platform notification mapping — mobile `NOTIFICATION_APPLICATION_PAUSED/RESUMED` has post-cutoff verify need per project VERSION.md; desktop `NOTIFICATION_WM_WINDOW_FOCUS_OUT/IN` standard. Verify `NOTIFICATION_APPLICATION_PAUSED` name/value via `docs/engine-reference/godot/` before shipping.

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: Platform notification mapping: `NOTIFICATION_APPLICATION_PAUSED` / `RESUMED` (mobile) AND `NOTIFICATION_WM_WINDOW_FOCUS_OUT` / `IN` (desktop); `NOTIFICATION_WM_CLOSE_REQUEST` triggers full-state graceful-exit persist. — ADR-0005
- **Required**: `tick_fired` is foreground-only: freeze on BG entry; preserve accumulator residual across pause. — ADR-0005
- **Forbidden**: Never reset `_tick_accumulator_seconds` on pause entry (`discarding_accumulator_residual_on_pause`). — ADR-0005

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [ ] AC-TICK-04: "GIVEN the game is in FOREGROUND and emitting ticks, WHEN the platform-appropriate BG trigger fires (mobile: `NOTIFICATION_APPLICATION_PAUSED`; PC: `NOTIFICATION_WM_WINDOW_FOCUS_OUT`), THEN tick emission halts before the next `_process` frame completes; `last_persist_unix` is written to the save buffer with the current wall-clock timestamp; `t_session_high_water` is updated to `max(prev, now)`; no partial-interval tick is emitted after the trigger fires. AND WHEN the platform-appropriate FG trigger fires (mobile: `NOTIFICATION_APPLICATION_RESUMED`; PC: `NOTIFICATION_WM_WINDOW_FOCUS_IN`), THEN the system does NOT recompute offline elapsed (that is cold-launch only); foreground ticking resumes; the total count of `tick_fired` emissions attributable to the background interval is exactly zero ... AND the `_process` fractional-delta accumulator is preserved across the pause: if accumulator residual was `R` seconds (0 ≤ R < 0.05) when BG fired, accumulator on FG resumption equals `R` ± 1e-9; the first post-resume tick fires after exactly `(0.05 − R)` additional accumulated delta..."
- [ ] TR-time-008: "Pause states: mobile BACKGROUNDED, PC focus-loss, UI pause; wall clock never paused"
- [ ] TR-time-009: "While paused, tick_fired NOT emitted; pause at source, not ignore-and-suppress"
- [ ] TR-time-010: "_process fractional-delta accumulator preserved across pause; never reset to 0 on unpause"
- [ ] TR-time-015: "Platform notifications: mobile NOTIFICATION_APPLICATION_PAUSED/RESUMED; PC NOTIFICATION_WM_WINDOW_FOCUS_OUT/IN"
- [ ] TR-time-034: "UI pause is substate of FOREGROUND - _process still runs (heartbeat fires), only tick emission suppressed"

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- Implement `_notification(what)` with the exact `match` from ADR-0005 Decision §"Platform-specific notification mapping". Route both `NOTIFICATION_APPLICATION_PAUSED` + `NOTIFICATION_WM_WINDOW_FOCUS_OUT` → `_on_backgrounded()`; both `NOTIFICATION_APPLICATION_RESUMED` + `NOTIFICATION_WM_WINDOW_FOCUS_IN` → `_on_foregrounded()`. Leave `NOTIFICATION_WM_CLOSE_REQUEST` → `_on_graceful_exit()` stubbed for Story 008.
- Add a state enum `_state: State {FOREGROUND, BACKGROUNDED}` and a separate `_ui_paused: bool` substate.
- In `_process(delta)`: early-return if `_state != FOREGROUND` OR `_ui_paused == true`. Critically, do NOT touch `_tick_accumulator_seconds` on pause entry — the accumulator must retain its value so resumption continues from residual (ADR-0005 §Consequences Row 4 forbids `discarding_accumulator_residual_on_pause`).
- On BG entry, write `_last_persist_unix = _read_wall_clock_unix_time()` and `_session_high_water = max(_session_high_water, _last_persist_unix)` (max-preserving assignment; ADR-0005 Decision bullet on heartbeat+BG).
- On FG return, do NOT emit `offline_elapsed_seconds` (the one-shot flag in Story 005 enforces this). Heartbeat interval timer (Story 008) may be reset on FG return, but the offline replay path never re-fires.
- UI pause toggle API: `set_ui_paused(paused: bool) -> void`; when true the state stays FOREGROUND but tick emission suppressed; heartbeat continues because `_process` still runs.
- On Godot 4.6, verify `NOTIFICATION_APPLICATION_PAUSED` name/value via `docs/engine-reference/godot/` before shipping — this is the MEDIUM engine-risk surface called out in ADR-0005 Engine Compatibility.

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- Story 005: offline one-shot emission on cold launch (this story only handles BG↔FG non-re-fire)
- Story 008: heartbeat persist timer wired to `SaveLoadSystem.request_heartbeat_persist`
- Story 009: offline replay `tick_fired` suppression

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **AC-TICK-04 (tick halt + no partial-interval emission)**: Integration
  - **Given**: TickSystem in FOREGROUND emitting ticks; 10 baseline `_process(0.05)` frames have fired 10 ticks
  - **When**: `_notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)` is invoked, then another `_process(0.05)` frame runs
  - **Then**: no additional `tick_fired` emits; `_last_persist_unix` equals current wall ts; `_session_high_water == max(prev, _last_persist_unix)`
  - **Edge cases**: BG fires mid-accumulator (residual 0.03) → accumulator stays at 0.03, NOT reset

- **AC-TICK-04 (residual preservation)**: Integration
  - **Given**: accumulator residual `R = 0.03` at BG entry
  - **When**: BG for 10 seconds (no process frames counted), then FG resume, then `_process(0.02)` fires
  - **Then**: `_tick_accumulator_seconds` post-resume == 0.03 ± 1e-9; after feeding 0.02 more, residual reaches 0.05 exactly → one `tick_fired` emits; if instead we fed 0.01, no emission (0.04 residual)
  - **Edge cases**: residual 0.0 at BG → normal resumption, next tick after 0.05 accumulated delta; residual 0.049999 at BG → first `_process(0.000001)` post-resume fires a tick

- **AC-TICK-04 (no zero-ticks during BG window)**: Integration
  - **Given**: instrumented listener recording (frame_index, tick_number) tuples
  - **When**: cold-launch → 100 FG frames → BG → 100 simulated BG frames (which should not call `_process`) → FG → 100 more FG frames
  - **Then**: no recorded emission has a frame_index within the BG window
  - **Edge cases**: repeated BG↔FG cycling within 1 real second must not emit ticks during any BG interval

- **TR-time-015 (mobile path)**: Integration
  - **Given**: `_notification(NOTIFICATION_APPLICATION_PAUSED)` invoked (mobile simulation)
  - **When**: subsequent `_process(0.05)` fires
  - **Then**: no `tick_fired` emits; `_state == BACKGROUNDED`
  - **Edge cases**: on Android, `NOTIFICATION_APPLICATION_PAUSED` may fire concurrently with `NOTIFICATION_WM_WINDOW_FOCUS_OUT`; state must remain BACKGROUNDED (idempotent); platform-specific Godot 4.6 engine-reference must be consulted to confirm constant values.

- **TR-time-034 (UI pause substate)**: Integration
  - **Given**: `_state == FOREGROUND`, `set_ui_paused(true)` called
  - **When**: 10 `_process(0.05)` frames run
  - **Then**: zero `tick_fired` emits; `_process` body still entered (heartbeat accumulator advances — verify via counter side effect in Story 008); `_state` remains FOREGROUND (NOT BACKGROUNDED)
  - **Edge cases**: `set_ui_paused(false)` re-enables emission from the preserved residual

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tick_system/platform_notifications_bg_fg_pause_residual_preservation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 must be DONE
- **Unlocks**: Story 008


## Completion Notes

**Completed**: 2026-04-24
**Criteria**: 6/6 passing
**Story Type**: Integration
**Test Evidence**: tests/integration/tick_system/platform_notifications_bg_fg_pause_residual_preservation_test.gd (5/5 pass)
**Deviations**: MEDIUM-risk engine verification still pending: mobile `NOTIFICATION_APPLICATION_PAUSED` hardware handshake on Steam Deck + mobile simulator. Unit-level behavior fully verified.
**Code Review**: Skipped — review mode solo (per production/review-mode.txt)
**Next**: Sprint-close sequence (/smoke-check sprint → /team-qa sprint → /gate-check)
