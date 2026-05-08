# Story 009: Offline replay coordination — `tick_fired` suppression + signal ordering invariant

> **Epic**: tick-system
> **Status**: Complete (system shipped; see systems-index Implementation Status #1. Test evidence: `tests/{unit,integration}/tick_system/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-014, TR-time-033
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract + ADR-0014: Offline Replay Batch Chunking + RunSnapshot Schema
**ADR Decision Summary**: Offline replay bypasses `tick_fired` — OfflineProgressionEngine (rank 15) drives the replay by calling `consumer.compute_offline_batch(n)` directly. TickSystem must suppress `tick_fired` emission during the replay window (an `_offline_replay_active` flag set by OfflineProgressionEngine); the accumulator is cleared at replay end to prevent a post-replay burst. `offline_elapsed_seconds` must emit before the first `tick_fired` in the process.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: MEDIUM risk from cross-rank coordination with OfflineProgressionEngine rank 15 + `await get_tree().process_frame` yield pattern per ADR-0014 §3.

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: Offline replay path bypasses `tick_fired`: `OfflineProgressionEngine` calls `consumer.compute_offline_batch(n)` directly. — ADR-0005
- **Forbidden**: Never emit `tick_fired` during offline replay (`tick_fired_during_offline_replay`) — offline path uses batch APIs. — ADR-0005

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [ ] AC-TICK-08: "GIVEN the Economy System exposes `compute_offline_batch(tick_count: int) -> OfflineResult` and the Offline Progression Engine is wired between TickSystem and Economy, WHEN TickSystem emits `offline_elapsed_seconds` and `cap_reached` at cold launch with `offline_tick_budget = N`, THEN the Offline Progression Engine invokes `economy.compute_offline_batch(N)` exactly once; `tick_fired` is NOT emitted during the offline replay (recorded emission count for the replay window is zero); the returned gold delta equals the closed-form expectation (e.g., for a constant drip rate `R`: `gold_delta == N × R`); and a subsequent N foreground `tick_fired` emissions on the same stubbed Economy produces the same `N × R` gold delta."
- [ ] TR-time-014: "Offline replay does NOT emit tick_fired; Offline Engine invokes batch APIs (compute_offline_batch) directly"
- [ ] TR-time-033: "Offline replay signal order: offline_elapsed_seconds and cap_reached emitted BEFORE first tick_fired"
- [ ] CI grep assertion: no `tick_fired.emit` call inside `OfflineProgressionEngine` or any `_is_replaying=true` code path

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- TickSystem's role in offline replay is passive: it emits `offline_elapsed_seconds(secs, cap_reached)` ONCE at cold launch (Story 005). OfflineProgressionEngine (rank 15, owned by ADR-0014) subscribes to this signal and drives the replay via direct `consumer.compute_offline_batch(n)` calls.
- Critical invariant for this story: TickSystem MUST NOT emit `tick_fired` during the replay window. The replay may span multiple frames (ADR-0014 §3 adaptive chunking with `await get_tree().process_frame` between chunks). TickSystem's `_process` continues to run during replay — the accumulator increments — so `tick_fired` emissions could leak.
- Mitigation option A: block `tick_fired` emission during replay by checking an OfflineProgressionEngine-owned flag `_is_replaying` (reads from `OfflineProgressionEngine._is_replaying` via named method `is_offline_replay_in_progress()`). Option B: block emission in TickSystem by a private flag `_offline_replay_active: bool` set/cleared by OfflineProgressionEngine via a setter (`set_offline_replay_active(bool)`). Pick Option B — cleaner ownership, and OfflineProgressionEngine at rank 15 can call rank 0 TickSystem methods at its own `_ready()`/replay dispatch time.
- While `_offline_replay_active == true`, `_process(delta)` still runs, still accumulates for the heartbeat, but `tick_fired` emission is suppressed (accumulator continues to advance, ticks queue up). On replay complete (flag cleared), the accumulated ticks drain naturally — OR clear the accumulator to prevent a post-replay burst. **Decision**: clear the tick accumulator at replay completion to avoid a burst of N stale ticks; document as an ADR-0014 coordination decision. This is a refinement needing godot-specialist validation.
- CI grep rule: `grep -rn "tick_fired.emit\|tick_fired\.emit" src/offline_progression_engine/ src/economy/` returns zero hits — only TickSystem's internal emission is allowed.
- For AC-TICK-08 signal-ordering invariant: the test harness records a sequence of `(signal_name, tick_count)` events. The `offline_elapsed_seconds` signal MUST appear before any `tick_fired` in that sequence.

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- OfflineProgressionEngine's adaptive chunking implementation (owned by ADR-0014 under a separate epic)
- Economy's `compute_offline_batch` semantics (owned by ADR-0013)

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **AC-TICK-08**: Offline batch delivery + tick suppression + parity
  - **Given**: stubbed Economy with `compute_offline_batch(n)` incrementing counter by `n × R` and `_on_tick` incrementing by `R`; OfflineProgressionEngine test-double connected to TickSystem; TickSystem mocked to emit `offline_elapsed_seconds(50.0, false)` → `offline_tick_budget = 1000`
  - **When**: cold launch replay runs
  - **Then**: `compute_offline_batch` called exactly once with argument 1000; `tick_fired` emission count across the replay window is zero; Economy counter delta == `1000 × R`
  - **Edge cases**: separately run 1000 foreground ticks → Economy counter advances by `1000 × R` (parity between offline and foreground paths)

- **TR-time-014 (tick suppression during replay)**: Integration
  - **Given**: `_offline_replay_active = true`; 10 `_process(0.05)` frames run (normally 10 ticks)
  - **When**: emission-capture spy listens for `tick_fired`
  - **Then**: zero `tick_fired` emissions during the replay window; accumulator is cleared at replay end; first post-replay `_process(0.05)` fires exactly one tick
  - **Edge cases**: replay spans multiple frames (ADR-0014 chunking) — no tick leaks in any frame

- **TR-time-033 (signal order)**: Integration
  - **Given**: instrumented signal collector recording `(timestamp, signal_name)` tuples
  - **When**: cold launch completes through to first foreground tick
  - **Then**: `offline_elapsed_seconds` timestamp < first `tick_fired` timestamp
  - **Edge cases**: if OfflineProgressionEngine hasn't finished replay by the time TickSystem's `_process` wants to fire → the suppression flag blocks `tick_fired` until replay completes; ordering invariant preserved

- **CI grep**: `tick_fired` emission outside TickSystem
  - **Given**: full `src/` tree
  - **When**: CI runs `grep -rn "tick_fired" src/` and filters for `.emit`
  - **Then**: matches appear ONLY inside TickSystem source; OfflineProgressionEngine, Economy, Orchestrator, Roster have zero `tick_fired.emit` calls
  - **Edge cases**: the CI rule runs on every push per ADR-0014's `per_chunk_domain_signal_emission_during_offline_replay` forbidden pattern enforcement

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tick_system/offline_replay_coordination_tick_fired_suppression_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 005 must be DONE
- **Unlocks**: Story 011
