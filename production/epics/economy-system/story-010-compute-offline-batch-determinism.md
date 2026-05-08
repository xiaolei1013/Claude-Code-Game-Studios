# Story 010: compute_offline_batch closed-form drip + determinism

> **Epic**: economy-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/economy-system.md` §H-09, §C.6, §D.6
**Requirements**: TR-economy-004 (closed-form O(1) drip; not per-tick replay)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0014 (Offline Replay Batch Chunking + RunSnapshot Schema) + ADR-0013 (`compute_offline_batch` signature, signal suppression policy, OfflineResult shape)
**ADR Decision Summary**: `compute_offline_batch(tick_budget) -> OfflineResult` is the closed-form drip path used during offline replay. Sets `_is_offline_replay = true`, computes drip in O(1) via multiplication (NOT per-tick signal replay), processes batched kill events (also O(N_kills), NOT per-tick), advances ledger via the same `try_award_floor_clear` semantic for any floor-clears, then sets `_is_offline_replay = false` and emits ONE aggregate `gold_changed(total, total_delta, OFFLINE_REPLAY_REASON)` signal. RNG seed = `t_last_persist XOR offline_tick_budget` for any deterministic event placement.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `RandomNumberGenerator` seeding stable; `class OfflineResult extends RefCounted` inline class per ADR-0013 NOTE #9 (memory leak prevention); `await get_tree().process_frame` chunking yield is the ADR-0014 contract — but this story is about determinism, NOT chunking (Story 011 covers chunking + perf budget).

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: closed-form drip (single multiplication), NOT per-tick replay loop. — ADR-0013
- **Required**: signal suppression during replay; aggregate emit AFTER. — ADR-0013
- **Forbidden**: `offline_replay_progressed_domain_subscriber` — Economy MUST NOT subscribe to `progressed` signal during replay. — ADR-0014
- **Forbidden**: `economy_signal_emission_during_offline_replay` per-call (EXEMPT: aggregate `gold_changed.emit` AFTER `_is_offline_replay = false`). — ADR-0013
- **Forbidden**: `worker_thread_pool_for_offline_replay_in_mvp` — Economy stays on main thread. — ADR-0014

---

## Acceptance Criteria

- [x] **H-09**: GIVEN identical starting state (gold=0, floor=2, formation_strength=1.0, matchup=1.0, no kills, no clears) on two Economy instances, WHEN instance A calls `compute_offline_batch(576000)` AND instance B processes 576000 ticks foreground via `tick_fired`, THEN both report identical final `gold_balance` AND identical `lifetime_gold_earned`. Determinism is bit-exact.
- [x] Repeated runs produce zero variance (re-running A's computation 100× yields the same result)
- [x] Closed-form drip: total_drip = `floori(BASE_DRIP[floor] × formation_strength × matchup_drip × tick_budget)`; computed in a single multiplication, NOT a loop over ticks
- [x] Signal suppression: during the call, `_is_offline_replay = true` for the batch duration; zero `gold_changed` or `first_clear_awarded` emissions occur DURING the computation
- [x] Aggregate emit AFTER: exactly ONE `gold_changed(new_balance, total_delta, "offline_replay")` emission fires AFTER `_is_offline_replay = false`
- [x] Returns `OfflineResult` (RefCounted inline class) with at minimum: `total_gold: int`, `floors_cleared: Array[int]`, `events_log: Array` (high-level event summary for HUD)
- [x] `OfflineResult` is `RefCounted`, NOT `Object` (per ADR-0013 NOTE #9 — prevents memory leak when unparented)
- [~] RNG seed = `t_last_persist XOR offline_tick_budget` for any seeded RNG used in event-cadence estimation — **DOCUMENTED, NOT EXERCISED**: the closed-form drip path consumes no random numbers, so no RNG instance exists to seed. The contract is documented in `compute_offline_batch`'s doc-comment for forward-compat; Story 011's chunking + kill-event integration is the first arm that will actually consume the seed.
- [x] `tick_budget == 0` → returns `OfflineResult` with all-zero / empty fields; no signal emission (also covers negative `tick_budget` defensively)

---

## Implementation Notes

*Derived from ADR-0013 + ADR-0014 §Decision sections:*

- This story is the **determinism contract**. Story 011 covers the perf-budget side (< 500 ms wall clock, adaptive 12 ms-per-chunk via `await get_tree().process_frame`).
- For unit-test determinism, run the closed-form path WITHOUT chunking (or with a very large chunk size that completes in one go). Story 011's adaptive chunking can yield mid-replay but MUST not affect final-state determinism.
- Pseudocode (high-level):
  ```
  class OfflineResult extends RefCounted:
      var total_gold: int = 0
      var floors_cleared: Array[int] = []
      var events_log: Array = []  # high-level summary entries for HUD

  func compute_offline_batch(tick_budget: int) -> OfflineResult:
      var result := OfflineResult.new()
      if tick_budget <= 0:
          return result
      _is_offline_replay = true
      var balance_before := _gold_balance
      # 1. Closed-form drip
      var fs := HeroRoster.get_formation_strength()  # snapshot at start
      var floor_index := DungeonRunOrchestrator.current_floor_index_for_offline()  # snapshot
      var base := EconomyConfig.BASE_DRIP[floor_index - 1]
      var drip_total := floori(base * fs * EconomyConfig.MATCHUP_DRIP_BONUS * tick_budget)
      add_gold(drip_total)
      # 2. Batched kill events from RunSnapshot (passed by Orchestrator/OfflineProgressionEngine)
      # ... iterate snapshot.kill_events; call attribute_kill_gold for each (still suppressed via flag)
      # 3. Floor clears (also batched from snapshot)
      # ... iterate snapshot.floor_clears; call try_award_floor_clear for each
      # 4. Compute summary
      result.total_gold = _gold_balance - balance_before
      _is_offline_replay = false
      gold_changed.emit(_gold_balance, result.total_gold, OFFLINE_REPLAY_REASON)
      return result
  ```
- The kill-events and floor-clears arms depend on RunSnapshot data structure (defined in ADR-0014). For this story's tests, **mock the snapshot** with empty arrays — the determinism check is primarily on the closed-form drip arm.
- Determinism note: `pow(float, int)` is bit-deterministic on a given platform per IEEE-754. Cross-platform replay (mobile vs PC) may produce micro-differences if mixed; for MVP we assume single-platform replay (player on Steam returns to Steam). Document as a known risk.
- The constant `OFFLINE_REPLAY_REASON = "offline_replay"` is allowlisted in `economy.gd` per ADR-0013 (one of two structural-constant exceptions to the no-hardcoded-balance rule, alongside `GOLD_SANITY_CAP`).

---

## Out of Scope

- Story 011: perf budget (< 500 ms) + adaptive chunking + `await get_tree().process_frame` yield
- Story 012: Save/Load round-trip of state (separate concern)
- OfflineProgressionEngine Feature epic — owns the RunSnapshot read + drives this method

---

## QA Test Cases

- **AC H-09: foreground-vs-batch equivalence**
  - **Given**: two Economy instances A and B with identical starting state (gold=0, ledger={}, lifetime=0); mock floor=2, formation_strength=1.0, matchup_drip_bonus=1.0; no kill events, no floor clears
  - **When**: A calls `compute_offline_batch(576_000)`; B has its `_on_tick` called 576_000 times via mock TickSystem
  - **Then**: `A._gold_balance == B._gold_balance`; `A._lifetime_gold_earned == B._lifetime_gold_earned`; bit-exact equality
  - **Edge cases**: `tick_budget = 1` (single-tick equivalence — both produce same drip); `tick_budget = 1_000_000` (very large)

- **AC: deterministic across repeated runs**
  - **Given**: identical fresh Economy instance
  - **When**: `compute_offline_batch(576_000)` invoked 100 times (resetting state between calls)
  - **Then**: all 100 results have identical `_gold_balance`, `_lifetime_gold_earned`, `OfflineResult.total_gold`
  - **Edge cases**: also assert `OfflineResult` field equality (events_log content match)

- **AC: closed-form (single multiplication, not loop)**
  - **Given**: instrumented `add_gold` (count call invocations)
  - **When**: `compute_offline_batch(576_000)` runs
  - **Then**: `add_gold` is called a small constant number of times (1 for drip + N_kills + N_clears), NOT 576_000 times
  - **Edge cases**: assert call count <= 100 even for large tick_budget

- **AC: signal suppression during replay**
  - **Given**: signal spies on `gold_changed` and `first_clear_awarded`
  - **When**: `compute_offline_batch(100_000)` runs with mock kills + clears in snapshot
  - **Then**: zero emissions during the call; exactly ONE `gold_changed(_, total, "offline_replay")` emission AFTER the call returns
  - **Edge cases**: zero emissions even when balance is changed by 1_000_000 inside the call

- **AC: zero tick_budget**
  - **Given**: any state
  - **When**: `compute_offline_batch(0)`
  - **Then**: returns `OfflineResult` with `total_gold == 0` and empty arrays; no signal emission; `_is_offline_replay` flag is false at entry/exit
  - **Edge cases**: negative tick_budget (defensive; document behavior)

- **AC: OfflineResult is RefCounted**
  - **Given**: `var r = compute_offline_batch(100)` then `r = null`
  - **When**: ref count drops to zero
  - **Then**: `OfflineResult` instance is freed automatically (no leak); verify by repeated calls in a loop without growing memory
  - **Edge cases**: holding a reference longer-lived (e.g., for HUD display) keeps it alive — standard RefCounted semantics

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/economy/economy_offline_batch_determinism_test.gd` — must exist and pass

**Status**: [x] `tests/integration/economy/economy_offline_batch_determinism_test.gd` — 10 test functions, 10/10 PASS. Full project suite: 1632/1632 PASS, zero regressions. Existing skeleton test (`economy_autoload_skeleton_test.gd::test_economy_compute_offline_batch_returns_null_stub`) updated to assert the implemented zero-budget contract instead of the prior null-stub behavior.

---

## Completion Notes

**Completed**: 2026-05-08
**Criteria**: 9/9 functional ACs passing + 1 contract-only AC documented (RNG seed — not yet exercised because closed-form drip arm has no random numbers; Story 011 will activate it)
**Test Evidence**: `tests/integration/economy/economy_offline_batch_determinism_test.gd` — 10 test functions, 10/10 PASS. Full project suite: 1632/1632 PASS, zero regressions.
**Files changed**:
- `src/core/economy/economy.gd` — populated `OfflineResult` with `total_gold`/`floors_cleared`/`events_log`; replaced `compute_offline_batch(_tick_budget)` stub with full body (defensive zero/negative guards, single-multiplication drip, signal-suppressed `add_gold` call, post-replay aggregate `gold_changed` emit with `OFFLINE_REPLAY_REASON`); added `set_offline_replay_inputs(formation_strength, floor_index)` test-only DI seam + private `_resolve_offline_replay_formation_strength()` / `_resolve_offline_replay_floor_index()` resolvers (production reads from HeroRoster autoload with safe fallback to FS=1.0 / floor=1).
- `tests/integration/economy/economy_offline_batch_determinism_test.gd` — new file, 10 test functions covering H-09 equivalence at 1 / 576_000 / 1_000_000 ticks, 100-run determinism, single-aggregate-signal closed-form proof, post-replay flag-state-at-emission contract, zero/negative defensive paths, RefCounted no-leak proof, events_log shape.
- `tests/unit/economy/economy_autoload_skeleton_test.gd` — flipped one stub-era test from "compute_offline_batch returns null" to "compute_offline_batch(0) returns empty RefCounted result" matching the implemented contract.
**Deviations**: None blocking. Two follow-up items captured (see TD-013 below):
1. **DungeonRunOrchestrator floor-index accessor missing**: the story Implementation Notes pseudocode references `DungeonRunOrchestrator.current_floor_index_for_offline()`, which doesn't exist on the orchestrator yet. The implementation falls back to floor=1 when no DI override is set; production callers must use `set_offline_replay_inputs(...)` until the orchestrator/RunSnapshot integration lands. Acceptable because the OfflineProgressionEngine Feature epic (the future production caller) is out of scope here and will own that wiring.
2. **HeroRoster.get_formation_strength() autoload-read coupling**: the production resolver does `get_node_or_null("/root/HeroRoster")` + duck-types `.has_method`. Tests bypass via DI. This is consistent with existing patterns (see `_fire_heartbeat` in `tick_system.gd`) but is worth flagging for the OfflineProgressionEngine integration to potentially replace with a snapshot-passed value.
**Code Review**: Solo mode — `/code-review` skipped per project review-mode.txt. Implementation follows the same pattern audited under data-registry/story-007 the same day.

---

## Dependencies

- **Depends on**: Story 001 (autoload + flag), Story 002 (EconomyConfig), Story 003 (`add_gold`), Story 005 (`try_award_floor_clear`), Story 006 (drip math reference for foreground-equivalence test), Story 007 (`attribute_kill_gold` reference); also data-registry epic Story 004 for `resolve`
- **Unlocks**: Story 011 (perf budget); OfflineProgressionEngine Feature epic
