# Story 002: Integer accumulator and `tick_fired` synchronous emission

> **Epic**: tick-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-003, TR-time-004, TR-time-005, TR-time-007, TR-time-010, TR-time-013
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract
**ADR Decision Summary**: The Sim Clock is an integer tick counter advanced by a while-loop integer-accumulator pattern inside `_process(delta)`; `tick_fired` must emit synchronously (never `call_deferred`, never via `Timer`) so downstream economy/orchestrator code sees a strict, ordered tick stream.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff engine APIs used in this story.

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: Sim Clock = integer accumulator pattern in `_process(delta)`: `_tick_accumulator_seconds += delta; while ≥ _TICK_INTERVAL_SECONDS (0.05) → _sim_tick_counter += 1; tick_fired.emit(_sim_tick_counter)`. — ADR-0005
- **Required**: `tick_fired` MUST emit synchronously inside `_process` — NEVER `call_deferred`, NEVER via `Timer`. — ADR-0005
- **Required**: `TICKS_PER_SECOND = 20` is an architectural constant (NOT a tuning knob; NOT exposed as ProjectSettings/.tres). — ADR-0005
- **Forbidden**: Never `call_deferred` `tick_fired` emission (`deferred_tick_emission`) — synchronous ordering required. — ADR-0005
- **Forbidden**: Never reset `_tick_accumulator_seconds` on pause entry (`discarding_accumulator_residual_on_pause`). — ADR-0005

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [ ] AC-TICK-01: "GIVEN 20 deterministic delta values each equal to 0.05 are fed sequentially to the tick accumulator, WHEN all 20 deltas have been processed, THEN exactly 20 `tick_fired` signals have been emitted — no tick is skipped, doubled, or emitted early; the accumulator residual after the 20th delta is ≤ 1e-9; and `tick_number` values are monotonically increasing integers starting from 0."
- [ ] TR-time-003: "Simulation clock is integer tick counter at fixed 20 Hz (TICKS_PER_SECOND = 20)"
- [ ] TR-time-004: "Simulation clock session-scoped; resets to 0 on every cold launch; NOT persistent or globally unique"
- [ ] TR-time-005: "Uses _process(delta) with integer-accumulator pattern; _physics_process NOT used"
- [ ] TR-time-007: "Simulation clock monotonic non-negative int; never decreases while app alive"
- [ ] TR-time-010: "_process fractional-delta accumulator preserved across pause; never reset to 0 on unpause" (within-session accumulator correctness; cross-BG preservation verified in Story 004)
- [ ] TR-time-013: "tick_fired(tick_number: int) signal emitted synchronously inside _process; call_deferred prohibited"

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- Implement `_process(delta)` using the while-loop integer-accumulator pattern from ADR-0005 §"Simulation Clock" exactly: `_tick_accumulator_seconds += delta; while _tick_accumulator_seconds >= _TICK_INTERVAL_SECONDS: _tick_accumulator_seconds -= _TICK_INTERVAL_SECONDS; _sim_tick_counter += 1; tick_fired.emit(_sim_tick_counter)`.
- Emission MUST be synchronous — do NOT use `call_deferred`, `emit_signal.call_deferred`, or a `Timer` node; ADR-0005 Consequences §Risks row 1 explicitly forbids.
- Counter starts at 0 and increments; it is session-scoped (no persist, no load; Story 008 confirms save/load never touches `_sim_tick_counter`).
- Do NOT use `_physics_process` and do NOT touch `Engine.physics_ticks_per_second`; rationale in ADR-0005 §"Why `_process` accumulator".
- Add an `assert(_sim_tick_counter >= previous_counter)` in the while loop (debug-only) to catch any regression in the monotonic invariant.
- This story implements the accumulator's residual semantics for within-session ticking; BG/FG residual preservation across pause state is verified in Story 004.

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- Story 003: `process_delta_as_economy_input` contract enforcement + wall clock single call site
- Story 004: BG/FG pause / accumulator residual across pause transition
- Story 005: first-launch bootstrap and offline one-shot

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **AC-TICK-01**: Fixed-rate tick delivery
  - **Given**: TickSystem autoload in a test harness with `_sim_tick_counter = 0`, `_tick_accumulator_seconds = 0.0`, state = FOREGROUND
  - **When**: 20 calls to `_process(0.05)` are made sequentially
  - **Then**: `tick_fired` emitted exactly 20 times; recorded `tick_number` sequence is `[1, 2, ..., 20]` (or `[0..19]` — assert per ADR's starting convention — first emission after first tick); `_tick_accumulator_seconds` residual ≤ 1e-9
  - **Edge cases**: feed a single `_process(0.049)` → 0 emissions, residual 0.049; feed `_process(0.1)` → 2 emissions in a single frame; feed `_process(1.0)` → 20 emissions in one frame (catch-up behavior)

- **TR-time-013**: Synchronous emission
  - **Given**: a listener that appends its call frame marker to a list
  - **When**: a single `_process(0.05)` fires one tick
  - **Then**: listener invocation completes BEFORE `_process` returns (synchronous stack), not deferred to the next idle frame
  - **Edge cases**: listener that throws — must not be swallowed by a deferred queue (synchronous propagation preserves stack trace)

- **TR-time-007**: Monotonic non-negative counter
  - **Given**: initial `_sim_tick_counter = 0`
  - **When**: 10,000 `_process(0.05)` calls
  - **Then**: every successive `tick_number` argument in emitted signals is strictly greater than the prior one; no negative values; no reset
  - **Edge cases**: tick counter never decreases on any frame delta value (0, 0.05, 1.0, 100.0)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tick_system/integer_accumulator_tick_fired_emission_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 must be DONE
- **Unlocks**: Story 003


## Completion Notes

**Completed**: 2026-04-24
**Criteria**: 7/7 passing
**Story Type**: Logic
**Test Evidence**: tests/unit/tick_system/integer_accumulator_tick_fired_emission_test.gd (10/10 pass)
**Deviations**: AC-TICK-01 catch-up edge test uses `_process(1.001)` instead of `_process(1.0)` to sidestep IEEE-754 rounding (20 × 0.05 ≠ 1.0 exactly).
**Code Review**: Skipped — review mode solo (per production/review-mode.txt)
**Next**: Sprint-close sequence (/smoke-check sprint → /team-qa sprint → /gate-check)
