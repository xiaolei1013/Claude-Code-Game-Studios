# Story 011: compute_offline_batch perf budget < 500 ms (8h cap)

> **Epic**: economy-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/economy-system.md` §H-10
**Requirements**: TR-economy-004 (perf side: closed-form is O(1); 576k-tick budget < 500 ms)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0014 (adaptive 12 ms-per-chunk; `await get_tree().process_frame` yield) + ADR-0013 (perf budget AC H-10)
**ADR Decision Summary**: `compute_offline_batch(576_000)` MUST complete in < 500 ms wall-clock on minimum-spec reference hardware; per-tick average < 0.87 μs. Adaptive chunking (target 12 ms per chunk, initial 5000 ticks, deadband ±25%) yields the main thread between chunks via `await get_tree().process_frame` to keep the cozy-modal threshold (100 ms latency rule per ADR-0014) from kicking in for short replays.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `await get_tree().process_frame` is the documented main-thread yield pattern; `Time.get_ticks_msec()` for wall-clock measurement. Min-spec hardware: see `production/qa/minimum-spec.md`.

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: adaptive chunking with target 12 ms per chunk; initial 5000 ticks; min 500 / max 50_000; deadband ±25%; adjust ratio 0.6. — ADR-0014
- **Required**: `await get_tree().process_frame` between chunks (NOT WorkerThreadPool). — ADR-0014
- **Forbidden**: `worker_thread_pool_for_offline_replay_in_mvp`. — ADR-0014
- **Required**: total wall-clock for 576_000-tick budget < 500 ms; per-chunk wall < 16 ms BLOCKING. — ADR-0014

---

## Acceptance Criteria

- [ ] **H-10**: GIVEN fresh Economy + benchmark state, WHEN `compute_offline_batch(576_000)` is called (no signal emission, no UI callbacks), THEN wall-clock elapsed < 500 ms on minimum-spec; per-tick average < 0.87 μs; test fails if ANY single run > 500 ms (not just the average)
- [ ] Adaptive chunking: chunk size adjusts toward 12 ms target; initial 5000; min 500; max 50_000; deadband ±25%; adjust ratio 0.6 per ADR-0014
- [ ] `await get_tree().process_frame` yields between chunks (verified by frame counter delta over the call)
- [ ] Per-chunk wall time ≤ 16 ms (BLOCKING — min-spec mobile ANR headroom)
- [ ] Determinism preserved across chunked vs unchunked execution (final state identical)
- [ ] Cozy-modal threshold: short replays (< 100 ms total) MUST NOT trigger the `PROGRESS_MODAL_THRESHOLD_MS = 100` modal (UI side; this AC is about Economy emitting the right signal cadence)

---

## Implementation Notes

*Derived from ADR-0014 §Decision §adaptive chunking:*

- Pseudocode:
  ```
  func compute_offline_batch(tick_budget: int) -> OfflineResult:
      _is_offline_replay = true
      var result := OfflineResult.new()
      var ticks_remaining := tick_budget
      var chunk_size := 5000  # initial
      var balance_before := _gold_balance
      while ticks_remaining > 0:
          var chunk := min(chunk_size, ticks_remaining)
          var chunk_start_ms := Time.get_ticks_msec()
          # Closed-form drip for `chunk` ticks (single multiplication)
          # Batched kill events whose `tick_offset` falls in [tick_budget - ticks_remaining, ...current chunk window]
          # Batched floor clears similarly
          # ... (mirror Story 010 semantics, just over the chunk window)
          var chunk_wall := Time.get_ticks_msec() - chunk_start_ms
          # Adaptive resize: if chunk_wall > 12 * 1.25, shrink by 0.6; if < 12 * 0.75, grow by 1/0.6
          if chunk_wall > 15:
              chunk_size = max(int(chunk_size * 0.6), 500)
          elif chunk_wall < 9:
              chunk_size = min(int(chunk_size / 0.6), 50_000)
          ticks_remaining -= chunk
          if ticks_remaining > 0:
              await get_tree().process_frame
      result.total_gold = _gold_balance - balance_before
      _is_offline_replay = false
      gold_changed.emit(_gold_balance, result.total_gold, OFFLINE_REPLAY_REASON)
      return result
  ```
- For closed-form drip, this loop with chunking looks redundant — the math is O(1). The chunking is for **batched kill/clear event processing** (which is O(N_events)), not the drip arm. Optimize the drip arm to a single multiplication outside the loop; chunk the events arm only.
- The 500 ms budget at 576_000-tick scale (the 8h offline cap × 20 Hz) is generous for closed-form drip; the budget exists primarily to bound the events-arm cost on heavy-event runs.
- Min-spec hardware reference is in `production/qa/minimum-spec.md` (Sprint 1 landed). Use that for the test runner config.
- Test method: instrument `Time.get_ticks_msec()` start/end; run 100 iterations; assert max < 500 ms (not just average).
- Document p50/p95/p99 wall-clock to `production/qa/evidence/economy-offline-[date].md` per H-10 §Verification.

---

## Out of Scope

- Story 010: closed-form determinism contract (this story builds on it)
- OfflineProgressionEngine's RunSnapshot iteration (Feature epic)
- Cozy-modal UI work (Presentation layer)
- Cross-platform determinism (PC vs mobile float-precision micro-drift; documented risk)

---

## QA Test Cases

- **AC H-10: budget compliance**
  - **Given**: fresh Economy on min-spec reference hardware (or simulator with throttle); EconomyConfig at default values; mock empty kill/clear arrays in snapshot; tick_budget = 576_000
  - **When**: `compute_offline_batch(576_000)` invoked 100 times sequentially
  - **Then**: every single run completes in < 500 ms wall-clock; max-of-100 < 500 ms (not just mean)
  - **Edge cases**: log p50/p95/p99 to `production/qa/evidence/economy-offline-[date].md`; smaller tick_budgets (1000, 10_000, 100_000) also profiled for trend confirmation

- **AC: per-chunk wall ≤ 16 ms**
  - **Given**: instrumented chunk loop logging `chunk_wall` per iteration
  - **When**: `compute_offline_batch(576_000)` runs
  - **Then**: max(chunk_wall over all chunks) ≤ 16 ms; p95(chunk_wall) ≤ 12 ms (target)
  - **Edge cases**: under heavy event load (mock 1000 kill events in snapshot), chunk_wall MUST still respect 16 ms ceiling (chunk size shrinks to compensate)

- **AC: adaptive chunking convergence**
  - **Given**: instrumented chunk_size logging
  - **When**: `compute_offline_batch(576_000)` runs
  - **Then**: chunk_size sequence converges toward a stable value within a few iterations (e.g., starts at 5000, settles in [500, 50_000] band per per-chunk timing)
  - **Edge cases**: extreme initial mis-estimation (manually inject `chunk_size = 50_000` start) recovers within 3 chunks

- **AC: main-thread yield**
  - **Given**: frame counter snapshot before/after the call
  - **When**: `compute_offline_batch(576_000)` runs to completion
  - **Then**: at least 2 frames advanced during the call (yields happened); total monotonically increases
  - **Edge cases**: very small tick_budgets (single-chunk completion) may yield zero frames — that's allowed

- **AC: determinism preserved despite chunking**
  - **Given**: two Economy instances; A runs with chunking enabled; B runs with chunking forced to single chunk (chunk_size = INF)
  - **When**: both call `compute_offline_batch(576_000)` with identical setup
  - **Then**: final state bit-exact equal (Story 010 contract preserved)
  - **Edge cases**: identical drip totals, identical events_log

---

## Test Evidence

**Story Type**: Integration (perf-class — but evidence is automated assertion + an evidence doc with p50/p95/p99 numbers)
**Required evidence**:
- `tests/integration/economy/economy_offline_batch_perf_test.gd` — must exist and pass
- `production/qa/evidence/economy-offline-[date].md` — p50/p95/p99 numbers per H-10 §Verification

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 010 (closed-form correctness), Story 002 (EconomyConfig), Sprint 1's TickSystem (for `tick_fired` cadence reference)
- **Unlocks**: OfflineProgressionEngine Feature epic; pre-Production gate H-10 verification
