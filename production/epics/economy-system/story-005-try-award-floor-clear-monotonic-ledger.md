# Story 005: try_award_floor_clear monotonic-credit ledger (ADR-0002)

> **Epic**: economy-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/economy-system.md` §H-03, §H-14 (with 5 sub-ACs: losing-first-then-win-reclaim, win-then-losing-no-reclaim, boundary, negative-bonus, zero-bonus)
**Requirements**: TR-economy-relevant + ADR-0002 monotonic-credit semantic
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0002 (Losing First-Clear Reclaimable on Win — monotonic ledger semantics) + ADR-0013 (Economy as authoritative gate; `try_award_floor_clear` signature + Layer-3 idempotency role)
**ADR Decision Summary**: Economy owns the `_floor_clear_bonus_credited: Dictionary[int, int]` per-floor monotonic-credit ledger. `try_award_floor_clear(floor_index, bonus_amount)` credits the **delta** above the prior ceiling (`add_gold(bonus_amount - already_credited)`), advances the ceiling, and emits `first_clear_awarded` only on the FIRST credit for that floor. Subsequent calls at-or-below the ceiling return false silently. Orchestrator applies `LOSING_RUN_LOOT_FACTOR` BEFORE calling Economy — Economy never reads `losing_run`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Typed `Dictionary[int, int]` operations; `dict.get(key, default)` pattern; signal emission discipline.

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: `try_award_floor_clear` is the canonical Layer-3 idempotency gate; Orchestrator's `floor_clear_emitted: bool` is Layer-2 single-dispatch defense — they coexist. — ADR-0002 / ADR-0013
- **Required**: `add_gold` is the only mutation path; floor-clear credits MUST funnel through it (so `_lifetime_gold_earned` updates correctly). — ADR-0013
- **Forbidden**: `economy_reads_losing_run_state` — Economy never reads `Orchestrator.losing_run` / `survived` / `hp_bonus_factor`. — ADR-0013

---

## Acceptance Criteria

- [ ] **H-03**: First call `try_award_floor_clear(3, 3000)` on fresh state credits 3000 via `add_gold`, fires `first_clear_awarded(3)` exactly once, sets `_floor_clear_bonus_credited[3] = 3000`, returns `true`. Second call same args returns `false`, credits zero gold, does NOT re-emit signal, ledger unchanged.
- [ ] **H-14 main**: Sequence `(3, 3000)` → `(3, 3000)` → `(3, 1500)` → first credits 3000 + emits signal once; second returns false; third returns false (LOSING after WIN). Total credited = 3000.
- [ ] **Sub-AC 14-losing-first-then-win-reclaim**: Sequence `(3, 1500)` → `(3, 3000)` → first credits 1500 + emits `first_clear_awarded(3)` once; second credits delta 1500 via `add_gold(1500)` and **does NOT re-emit** the signal; ledger advances to 3000. Total credited = 3000. Subsequent `(3, anything)` returns false.
- [ ] **Sub-AC 14-win-then-losing-no-reclaim**: Sequence `(3, 3000)` → `(3, 1500)` → first credits 3000 + emits; second returns false (LOSING below WIN ceiling); credits zero. Total = 3000.
- [ ] **Sub-AC 14-boundary**: `floor_index = 0` or `floor_index = 6` → `push_error("Economy.try_award_floor_clear: floor_index=X out of range [1,5]")`; returns `false`; ledger NOT mutated for the bad key (no `{0: 0}` insert).
- [ ] **Sub-AC 14-negative-bonus**: `bonus_amount = -100` → `push_error("Economy.try_award_floor_clear: bonus_amount=X is negative (authoring bug)")`; returns `false`; ledger NOT mutated. The floor remains uncredited so a subsequent valid call can still credit.
- [ ] **Sub-AC 14-zero-bonus**: `try_award_floor_clear(1, 0)` on uncredited floor returns `false` (gate catches degenerate case); ledger remains absent / 0 (not marked credited). Subsequent `try_award_floor_clear(1, 500)` WIN still credits 500.
- [ ] During `_is_offline_replay == true`: `add_gold` call still happens, but `first_clear_awarded` emission is suppressed; Story 010 handles aggregate emit after replay flag clears.

---

## Implementation Notes

*Derived from ADR-0002 §Decision and ADR-0013 §Decision §try_award_floor_clear:*

- Pseudocode:
  ```
  func try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool:
      if floor_index < 1 or floor_index > 5:
          push_error("Economy.try_award_floor_clear: floor_index=%d out of range [1,5]" % floor_index)
          return false
      if bonus_amount < 0:
          push_error("Economy.try_award_floor_clear: bonus_amount=%d is negative (authoring bug)" % bonus_amount)
          return false
      var already := _floor_clear_bonus_credited.get(floor_index, 0)
      if bonus_amount <= already:
          return false  # at-or-below ceiling; covers zero-bonus, repeat-WIN, LOSING-after-WIN
      var delta := bonus_amount - already
      add_gold(delta)  # routes through the canonical mutation site; updates lifetime
      _floor_clear_bonus_credited[floor_index] = bonus_amount
      var is_first := already == 0  # was uncredited
      if is_first and not _is_offline_replay:
          first_clear_awarded.emit(floor_index)
      return true
  ```
- The "credit the delta" pattern is critical for the LOSING-then-WIN reclaim path. The first LOSING call credits the halved bonus; the WIN follow-up credits the remaining gap; the floor's first-clear milestone (`first_clear_awarded` signal) only fires on the LOSING call (the milestone has already happened — the WIN reclaim is a delta credit, not a fresh milestone).
- Anti-exploit invariant: the credited total for any floor never exceeds the highest `bonus_amount` ever observed for that floor.
- Layer-3 authoritative role: this method MUST handle duplicate Orchestrator dispatch (replay edge case) gracefully — the Layer-2 `floor_clear_emitted: bool` flag in Orchestrator is single-dispatch defense, not a global guarantee.
- Orchestrator-applies-LOSING invariant: do NOT read `Orchestrator.losing_run` here. The bonus_amount arg is already post-factor.

---

## Out of Scope

- Story 003: `add_gold` itself (called by this story)
- Story 012: Save/Load round-trip of the ledger dict (separately tested)
- Orchestrator's `floor_clear_emitted: bool` Layer-2 flag (lives in DungeonRunOrchestrator Feature epic)

---

## QA Test Cases

- **AC H-03 + main path**: idempotent first credit + repeat
  - **Given**: fresh `_floor_clear_bonus_credited = {}`, `_gold_balance = 0`
  - **When**: `try_award_floor_clear(3, 3000)` called twice
  - **Then**: first → returns true, gold becomes 3000, ledger `{3: 3000}`, exactly one `first_clear_awarded(3)` emission, exactly one `gold_changed` emission with delta=3000; second → returns false, no add_gold call, no signal emissions, ledger unchanged
  - **Edge cases**: gold spy + signal spy assert call counts precisely; restoring then repeating must yield same behavior

- **Sub-AC 14-losing-first-then-win-reclaim** (the headline reclaim path)
  - **Given**: fresh ledger, `_gold_balance = 0`
  - **When**: `try_award_floor_clear(3, 1500)` then `try_award_floor_clear(3, 3000)`
  - **Then**: first → true, gold +1500, ledger `{3: 1500}`, `first_clear_awarded(3)` fires once; second → true, gold +1500 (delta), ledger `{3: 3000}`, `first_clear_awarded` does NOT fire again; total gold = 3000
  - **Edge cases**: a third call `(3, 3000)` returns false; `(3, 1500)` returns false; `(3, 3001)` returns true with delta 1 (any future-bonus increase is still credited)

- **Sub-AC 14-win-then-losing-no-reclaim**
  - **Given**: fresh ledger
  - **When**: `(3, 3000)` then `(3, 1500)`
  - **Then**: first credits + emits; second returns false, zero credit, no emission; total = 3000
  - **Edge cases**: `(3, 0)` after WIN also returns false

- **Sub-AC 14-boundary**: out-of-range floor_index
  - **Given**: any state
  - **When**: `try_award_floor_clear(0, 500)`, `try_award_floor_clear(6, 500)`, `try_award_floor_clear(-1, 500)`
  - **Then**: each fires `push_error`, returns false; ledger remains empty; no `add_gold` calls; no signal emissions
  - **Edge cases**: ensure no `_floor_clear_bonus_credited[0]` insert (dictionary `.get(key, default)` pattern protects against this — but explicit assertion needed)

- **Sub-AC 14-negative-bonus**
  - **Given**: any state
  - **When**: `try_award_floor_clear(1, -100)`
  - **Then**: `push_error`; returns false; ledger NOT mutated; floor 1 remains uncredited; subsequent `(1, 500)` valid call still credits 500
  - **Edge cases**: `INT64_MIN` should not crash

- **Sub-AC 14-zero-bonus**
  - **Given**: fresh ledger
  - **When**: `try_award_floor_clear(1, 0)` then `try_award_floor_clear(1, 500)`
  - **Then**: first returns false, no credit, no signal, ledger remains empty (NOT `{1: 0}`); second returns true, credits 500, fires `first_clear_awarded(1)`
  - **Edge cases**: must verify ledger has NO key for 1 after the zero-bonus call (use `.has(1) == false` assertion)

- **AC: offline-replay signal suppression**
  - **Given**: `_is_offline_replay = true`, fresh ledger
  - **When**: `try_award_floor_clear(3, 3000)`
  - **Then**: returns true, gold credited via `add_gold` (which itself suppresses `gold_changed`), ledger advances, but **zero** `first_clear_awarded` emissions; flag cleared post-replay → next valid call emits normally
  - **Edge cases**: aggregate emit pattern for offline replay handled in Story 010

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economy/economy_try_award_floor_clear_test.gd` — must exist and pass; minimum **8 distinct test functions** (one per Sub-AC + main + offline-replay)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload + signals + ledger field), Story 003 (`add_gold` body — the credit path uses it)
- **Unlocks**: Story 010 (`compute_offline_batch` calls this internally for offline floor clears), DungeonRunOrchestrator Feature epic


## Completion Notes
**Completed**: 2026-04-25 (Sprint 3 S3-M1 — closed Sprint 2 S2-S1 carryover)
**Criteria**: 8/8 ACs + 5 sub-ACs all passing
**Story Type**: Logic
**Test Evidence**: `tests/unit/economy/economy_try_award_floor_clear_test.gd` — 19 test functions / 0 errors / 0 failures
**Aggregate suite**: 85 economy test cases across S2-M1+M2+M3+M4 + S3-M1 — all green
**Manifest Version**: 2026-04-24 — matched
**Deviations**: NONE. Implementation matches ADR-0002 + ADR-0013 pseudocode verbatim. The critical `is_first := already == 0` capture-before-`add_gold` ordering was honored; LOSING-first-then-WIN reclaim path verified to suppress re-emission of `first_clear_awarded` (milestone fires only on the LOSING first credit).
**Related test update**: Sprint 2 S2-M1's stub test `test_economy_try_award_floor_clear_returns_false_stub` was renamed to `test_economy_try_award_floor_clear_credits_and_returns_true` and re-asserted against the real body (returns true; balance=500 from a fresh state). Within sprint scope (sibling test file).
**Anti-exploit invariant**: verified — credited total per floor never exceeds the highest `bonus_amount` ever observed (sub-AC 14-win-then-losing-no-reclaim).
**Code Review**: SKIPPED — review mode solo
**Next**: S3-M2 (EnemyData resource subclass — switches to enemy-database epic).
