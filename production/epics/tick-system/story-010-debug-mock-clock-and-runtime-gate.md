# Story 010: Debug-only mock clock + `debug_emit_suspicious_timestamp` + runtime gate

> **Epic**: tick-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-020, TR-time-021 (verification side — routing installed in Story 003, mock integration completes here)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract
**ADR Decision Summary**: Three debug-only methods (`debug_set_unix_time`, `debug_clear_unix_time`, `debug_emit_suspicious_timestamp`) are runtime-gated by `OS.is_debug_build()` and no-op in release; the mock wall ts is spliced into `_read_wall_clock_unix_time()` so Formula D.2 and heartbeats see the mock without touching the single-call-site invariant. The debug suspicious-timestamp emission bypasses the session bool so Save/Load fixtures can trigger the signal deterministically.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff engine APIs used in this story.

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: Debug-only methods (`debug_set_unix_time`, `debug_clear_unix_time`) MUST runtime-gate: `if not OS.is_debug_build(): return`. — ADR-0005
- **Forbidden**: (no new forbidden pattern — AC-SL-TAMPER-05 CI scan handles leaked exposure)

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [ ] TR-time-020: "Debug-only: debug_set_unix_time(t), debug_clear_unix_time(), debug_emit_suspicious_timestamp(prev, curr) all runtime-gated by OS.is_debug_build()"
- [ ] TR-time-021 (integration): mock propagates through `_read_wall_clock_unix_time()` into Formula D.2; direct calls to `Time.get_unix_time_from_system()` inside TickSystem remain a regression
- [ ] Release-build behavior: all three debug methods no-op (body returns immediately) — verified by toggling a mock `OS.is_debug_build()` stub in tests or by a release-build CI job

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- Implement the three methods from GDD §"Debug-Only Test Surface" verbatim:
  - `debug_set_unix_time(t: int) -> void` — gate on `if not OS.is_debug_build(): return`; validate `t >= 0` (push_error on negative); set `_debug_mock_unix_time = t`
  - `debug_clear_unix_time() -> void` — gate on `OS.is_debug_build()`; set `_debug_mock_unix_time = -1`
  - `debug_emit_suspicious_timestamp(prev: int, curr: int) -> void` — gate on `OS.is_debug_build()`; emit `flag_suspicious_timestamp_emitted.emit(prev, curr)` directly WITHOUT touching the session-scoped bool (per GDD Pass-TS-DEBUG-API note)
- Splice the mock into the Story 003 `_read_wall_clock_unix_time()` function: `if OS.is_debug_build() and _debug_mock_unix_time != -1: return _debug_mock_unix_time` before the real `Time.get_unix_time_from_system()` call.
- Sentinel `-1` means "no mock active" — matches ADR-0005 Decision §Debug-Only Test Surface.
- AC-SL-TAMPER-05 CI scan pattern (from Save/Load epic) greps for debug method bodies outside `OS.is_debug_build()` guards. This story's TickSystem methods must pass that scan.
- Test-pattern: every test using `debug_set_unix_time` MUST call `debug_clear_unix_time()` in `after_each()` to prevent mock leakage across tests (GDD test-usage pattern).

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- Save/Load's AC-SL-05/09/TAMPER-04 tests themselves (separate epic) — this story only delivers the hooks they consume
- `debug_advance_ticks(n)` / `debug_set_session_high_water(t)` / `debug_force_background_state()` — explicitly out of scope per GDD "Scope limits — what this surface does NOT provide"

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **TR-time-020 (runtime gate)**: Debug build
  - **Given**: Godot debug build (`OS.is_debug_build() == true`)
  - **When**: `TickSystem.debug_set_unix_time(1_745_000_000)` called
  - **Then**: `_debug_mock_unix_time == 1_745_000_000`; subsequent `_read_wall_clock_unix_time()` returns `1_745_000_000` instead of OS wall ts
  - **Edge cases**: `debug_set_unix_time(-1)` triggers `push_error` + no mock applied; `debug_set_unix_time(0)` is accepted (0 is a valid Unix ts at epoch); nested calls overwrite (last write wins)

- **TR-time-020 (release no-op)**: Release build
  - **Given**: mocked `OS.is_debug_build()` returning `false`
  - **When**: `debug_set_unix_time(1_745_000_000)` called
  - **Then**: `_debug_mock_unix_time` remains `-1`; `_read_wall_clock_unix_time()` returns real OS value (via the guard check on `_debug_mock_unix_time != -1`)
  - **Edge cases**: `debug_emit_suspicious_timestamp(0, 0)` in release → no signal emitted (gate fires early-return); release exports genuinely have `OS.is_debug_build() == false` — AC-SL-TAMPER-05 CI scan is the secondary defense

- **TR-time-021 (mock propagation through D.2)**: Integration
  - **Given**: debug build; `TickSystem.debug_set_unix_time(T_MOCK)`; `_last_persist_ts = _session_high_water = T_MOCK - 1000`
  - **When**: `_compute_offline_elapsed()` runs
  - **Then**: `elapsed_raw == 1000`; `elapsed_offline_seconds == 1000.0`; mock propagated correctly through `_read_wall_clock_unix_time()` routing
  - **Edge cases**: after `debug_clear_unix_time()`, `_read_wall_clock_unix_time()` returns real OS ts again; no residual mock state

- **`debug_emit_suspicious_timestamp` does not set session bool**: Logic
  - **Given**: `_flag_suspicious_timestamp == false`
  - **When**: `debug_emit_suspicious_timestamp(100, 50)` called
  - **Then**: signal `flag_suspicious_timestamp_emitted(100, 50)` emits; `_flag_suspicious_timestamp` REMAINS false (bool untouched per GDD Pass-TS-DEBUG-API note)
  - **Edge cases**: used by Save/Load AC-SL-09 fixture to trigger listener deterministically without driving D.2

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tick_system/debug_api_mock_clock_propagation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 007 must be DONE
- **Unlocks**: Story 011
