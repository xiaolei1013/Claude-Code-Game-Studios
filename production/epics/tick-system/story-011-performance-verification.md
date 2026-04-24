# Story 011: Performance verification — per-tick dispatch + offline replay budget + heartbeat envelope size

> **Epic**: tick-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration (Performance)
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-028, TR-time-029
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract (+ ADR-0014 for 576k budget)
**ADR Decision Summary**: Three performance budgets must be verified against min-spec target: per-tick dispatch ≤150 µs p99 with 4 subscribers (AC-TICK-09 ADVISORY), offline replay of 576k-tick cap maximum either ≤500 ms total OR chunked ≤16 ms/chunk (AC-TICK-10 BLOCKING), and heartbeat envelope payload ≤512 bytes (AC-TICK-11 BLOCKING size component). No new implementation — this story verifies the budgets the prior stories implemented.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: MEDIUM risk from cross-device measurement on min-spec mobile + Steam Deck proxy; ADR-0014 per-chunk budget coordination. No new post-cutoff engine APIs introduced.

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: inherits all TickSystem rules; this story asserts the guardrails rather than introducing new rules.
- **Forbidden**: (inherits all TickSystem forbidden patterns)
- **Guardrail**: Heartbeat envelope size: ≤512 bytes — [BLOCKING via AC-TICK-11]. — ADR-0005
- **Guardrail**: Per-tick dispatch budget: <1 ms PC / <5 ms mobile — [ADVISORY AC-TICK-09]. — ADR-0005 (this story's ≤150 µs p99 is tighter than the manifest's 1ms PC guardrail — ADR-0005 Performance Implications table is load-bearing; document that AC-TICK-09's 150 µs is the authoritative figure)
- **Guardrail**: Offline chunk CPU wall time: ≤16 ms/chunk on min-spec mobile — [BLOCKING AC-TICK-10]. — ADR-0014
- **Guardrail**: Offline replay total wall-clock-with-yield: ≤5 s for 8 h cap (ANR headroom) — [ADVISORY]. — ADR-0014

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [ ] AC-TICK-09 (ADVISORY): "GIVEN the game is running in FOREGROUND at 20 Hz with 4 active subscribers (Economy, Dungeon Run Orchestrator, UI HUD, Stats) connected to `tick_fired`, WHEN a tick interval boundary is crossed within `_process(delta)`, THEN the TickSystem's own CPU time to fan out the signal and update the accumulator — measured via `Time.get_ticks_usec()` before and after the emit — is **≤ 150 µs p99** on minimum-spec target hardware ... the TickSystem does not perform I/O, pathfinding, or per-entity iteration."
- [ ] AC-TICK-10 (BLOCKING): "GIVEN an offline tick budget of exactly 576 000 ticks (default cap maximum) and the Economy System's `compute_offline_batch(576_000)` is invoked on minimum-spec mobile hardware, WHEN the Offline Progression Engine executes the replay, THEN EITHER the total wall-clock time for `compute_offline_batch` to return does not exceed 500 ms, OR the replay is chunked across multiple frames with no single frame exceeding 16 ms in `compute_offline_batch`-attributable time; no single call stack ever blocks the main thread for more than 5 seconds (Android ANR watchdog threshold); during the replay window no visible UI freeze is perceptible beyond a loading affordance."
- [ ] AC-TICK-11 (BLOCKING, size component): "each write payload is ≤ 512 bytes (per Rule 10)" — measured in CI telemetry
- [ ] TR-time-028: "Offline replay must complete <=500ms OR chunk per-frame <=16ms on min-spec mobile; never block >5s (ANR)"
- [ ] TR-time-029: "Per-tick dispatch <=150us p99 with 4 subscribers on min-spec hardware"

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- This story is purely verification — no new TickSystem code. The implementation under test was completed in Stories 001-010 + the Economy/OfflineProgressionEngine stubs needed to run the 576k replay.
- Per-tick dispatch test: attach 4 no-op slots to `tick_fired`; run 1000 consecutive ticks; measure `Time.get_ticks_usec()` before/after `tick_fired.emit()`; assert p99 ≤ 150 µs (AC-TICK-09 ADVISORY, revised upward from 50 µs per ADR-0005 per-performance-implications table).
- Offline replay test: stub `Economy.compute_offline_batch(576_000)` and `DungeonRunOrchestrator.compute_offline_batch(576_000)` with closed-form O(1) implementations (ADR-0013 Economy contract); invoke via OfflineProgressionEngine; measure total wall time. If total ≤ 500 ms → PASS. If chunked: measure each chunk's `compute_offline_batch`-attributable CPU time; each chunk ≤ 16 ms → PASS. No single call stack blocks > 5 s (ANR headroom per ADR-0014 §coordination).
- Heartbeat envelope size: capture 10 heartbeat dicts from a 10-minute simulated run; serialize each via JSON; assert `len(serialized) + 44 ≤ 512` bytes. Verify `_meta` overhead per ADR-0004 (XOR mask seed + HMAC + headers).
- Target hardware: Snapdragon 6xx-class ARM @ 2 GHz or equivalent (per AC-TICK-09/10 GDD language). Steam Deck acceptable as conservative desktop proxy. CI runs on whatever the test-runner machine has; record results and compare budgets proportionally (documented headroom).
- If AC-TICK-10 fails at 576k: per GDD §D.3 + Tuning Knobs note, either reduce `offline_cap_seconds`, adopt adaptive chunking more aggressively (ADR-0014 §3 is the owner there), or push Economy/Orchestrator toward a closed-form multiply-only batch. This story surfaces the finding — the fix lives in the relevant domain epic.

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- Reducing offline cap / adopting closed-form batch API if AC-TICK-10 fails — that's a separate design/ADR-0013 discussion
- ADR-0014's adaptive chunking implementation proper (owned by OfflineProgressionEngine epic; verified here only at the TickSystem-visible boundary of ≤500ms total OR ≤16ms/chunk)

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **AC-TICK-09 (ADVISORY)**: Per-tick dispatch
  - **Given**: 4 no-op slots connected to `tick_fired`; test harness on min-spec target (or Steam Deck proxy)
  - **When**: 1000 consecutive ticks emitted via `_process(0.05) × 1000`
  - **Then**: measured p99 of `(end_usec - start_usec)` for each emit ≤ 150 µs
  - **Edge cases**: p50/p95/p99 distribution recorded; outliers investigated; ADVISORY status means failure surfaces as a warning, not a CI blocker; budget well under 1% of 16.6 ms frame

- **AC-TICK-10 (BLOCKING)**: Offline replay 576k
  - **Given**: stubbed Economy + Orchestrator with O(1) closed-form batch; target or proxy hardware
  - **When**: `compute_offline_batch(576_000)` invoked via OfflineProgressionEngine
  - **Then**: total wall time ≤ 500 ms OR (chunked with each chunk ≤ 16 ms AND no single call stack > 5 s); no visible UI freeze beyond a loading affordance
  - **Edge cases**: if O(1) assumption fails (Economy does per-tick work despite ADR-0013 requiring closed-form), per-chunk budget likely violated — surface as a regression against Economy epic, not TickSystem

- **AC-TICK-11 (size component)**: Heartbeat envelope size
  - **Given**: 10 heartbeat writes captured during a 600-second simulated run
  - **When**: each payload serialized to bytes including ADR-0004 envelope header + HMAC (44 bytes total overhead)
  - **Then**: every serialized envelope ≤ 512 bytes
  - **Edge cases**: int64 max values in all three fields — worst-case JSON size ~80 bytes + 44 overhead = 124 bytes, well under budget

- **TR-time-028 (ANR headroom)**: Integration
  - **Given**: offline replay running across simulated slow target
  - **When**: single call-stack duration measured
  - **Then**: no blocking call > 5 s (ANR threshold); chunking yields control via `await get_tree().process_frame` between chunks per ADR-0014 §3
  - **Edge cases**: replay of 576k ticks in a single non-chunked call on the slowest supported device — if it exceeds 5 s, chunking is mandatory (not optional)

---

## Test Evidence

**Story Type**: Integration (Performance)
**Required evidence**: `tests/integration/tick_system/performance_verification_tick_offline_heartbeat_budgets_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 008, Story 009, Story 010 must be DONE
- **Unlocks**: None (epic terminal story)
