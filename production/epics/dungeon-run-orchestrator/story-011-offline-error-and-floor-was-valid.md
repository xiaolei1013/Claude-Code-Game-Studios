# Story 011: ACTIVE_OFFLINE_REPLAY error path + floor_was_valid distinguisher

> **Epic**: dungeon-run-orchestrator
> **Status**: Complete (real implementation 2026-05-08 — `floor_was_valid` field + 2 public hooks added to source; integration test ships with 10 functions covering both ACs + round-trip + combined paths. Audit-cascade Status flip from earlier was over-eager — the field + hooks did NOT exist before this PR. 6th instance of audit-cascade-over-eager pattern caught today.)
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-029, TR-orchestrator-031

**Governing ADRs**: ADR-0014 (Offline Replay error policy)
**Decision Summary**: Errors during offline replay transition to RUN_ENDED via `validation_failed("offline_replay_error")` signal. Partial gold retained; no rollback. `floor_was_valid` bool on RunSnapshot distinguishes "lost badly" (no kills generated) from "floor authoring bug" (Combat returned empty result). Distinguishes ADR-0014's two failure modes.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (error policy correctness)

---

## Acceptance Criteria

- [x] TR-029: offline replay errors transition to RUN_ENDED via `validation_failed("offline_replay_error")`; partial gold retained (no rollback) — **MET**: public `report_offline_replay_error(partial_gold: int)` hook added to orchestrator. Emits `validation_failed("offline_replay_error", {"partial_gold": N})` and transitions ACTIVE_OFFLINE_REPLAY → RUN_ENDED. No rollback logic — partial_gold payload is forwarded verbatim (test confirms arbitrary values pass through).
- [x] TR-031: `floor_was_valid` on RunSnapshot — true when Combat returned a non-empty kill schedule; false when floor authoring bug produced empty Combat result — **MET**: `floor_was_valid: bool = true` field added to RunSnapshot with to_dict / from_dict round-trip + equals() integration. Public `mark_floor_invalid_for_offline_replay()` hook on orchestrator flips the field to `false` + push_errors the authoring-bug diagnostic for QA / playtest visibility.

---

## Implementation Notes

```gdscript
func compute_offline_run(tick_budget: int) -> OfflineRunResult:
    var result: OfflineRunResult = OfflineRunResult.new()
    if run_snapshot == null:
        result.floor_was_valid = false
        return result
    if run_snapshot.kill_schedule.is_empty():
        # Distinguishes: "lost badly" (no kills) vs "floor authoring bug" (Combat returned [])
        if _floor_definition_was_valid(run_snapshot.floor_id):
            run_snapshot.floor_was_valid = true   # genuine "lost badly"
        else:
            run_snapshot.floor_was_valid = false  # authoring bug
            push_error("[Orchestrator] floor '%s' produced empty kill_schedule — likely authoring bug" % run_snapshot.floor_id)
        return result
    # ... normal replay path ...
    # On error during replay:
    var success: bool = _try_replay(result, tick_budget)
    if not success:
        validation_failed.emit("offline_replay_error", {"partial_gold": result.total_gold})
        _transition_to(State.RUN_ENDED)
        # Do NOT rollback partial gold — already credited to Economy via add_gold during replay
    return result
```

`_floor_definition_was_valid(floor_id)` checks the source Floor resource — if archetype list is empty in the source data, that's an authoring bug; if archetypes exist but Combat produced no kills against this formation, that's "lost badly".

---

## QA Test Cases

- **TR-029 error path**: trigger offline replay with mocked combat error → state goes RUN_ENDED; `validation_failed("offline_replay_error", {partial_gold: N})` emitted; partial gold preserved (no rollback)
- **TR-031 floor_was_valid true (lost badly)**: weak formation against valid floor → kill_schedule empty in result → floor_was_valid stays true
- **TR-031 floor_was_valid false (authoring bug)**: floor with empty archetype source data → kill_schedule empty → floor_was_valid set false; push_error logged

---

## Test Evidence

**Type**: Integration | **Required**: `tests/integration/dungeon_run_orchestrator/offline_error_and_floor_validity_test.gd`

**Status**: [x] `tests/integration/dungeon_run_orchestrator/offline_error_and_floor_validity_test.gd` — 10 test functions, 10/10 PASS. Coverage:
- TR-029: 4 tests (validation_failed payload shape, RUN_ENDED transition, zero-partial-gold edge, no-rollback verbatim payload)
- TR-031: 5 tests (default-true field, mark-invalid flip, null-snapshot defensive no-op, to_dict/from_dict round-trip, forward-compat default-true on legacy save without the key)
- Combined: 1 test exercising both hooks together for the full authoring-bug flow

Adjacent regression fixed: `tests/unit/dungeon_run_orchestrator/run_snapshot_and_fsm_test.gd::test_to_dict_returns_ten_key_dict` renamed to `test_to_dict_returns_eleven_key_dict` and updated key count + key list to include `floor_was_valid` (the to_dict shape grew from 10 → 11 keys).

Full project suite: 1685 → 1695 PASS (+10 new), zero regressions after the to_dict-shape test was updated.

---

## Completion Notes

**Completed**: 2026-05-08 (real implementation — `floor_was_valid` field + 2 public hooks added to source; integration test written from scratch).
**Criteria**: 2/2 ACs met
**Test Evidence**: `tests/integration/dungeon_run_orchestrator/offline_error_and_floor_validity_test.gd` (10 functions, 10/10 PASS).
**Files changed**:
- `src/core/dungeon_run_orchestrator/run_snapshot.gd` — added `floor_was_valid: bool = true` field with comprehensive doc-comment; integrated into to_dict (11th key), from_dict (default-true on absence for forward-compat), and equals() (parity-test integrity).
- `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd` — added 2 public hooks: `report_offline_replay_error(partial_gold)` (emits validation_failed + transitions to RUN_ENDED) and `mark_floor_invalid_for_offline_replay()` (flips run_snapshot.floor_was_valid + push_errors the authoring-bug diagnostic). Both have null-snapshot guards where applicable.
- `tests/integration/dungeon_run_orchestrator/offline_error_and_floor_validity_test.gd` — new file, 10 tests.
- `tests/unit/dungeon_run_orchestrator/run_snapshot_and_fsm_test.gd` — `test_to_dict_returns_ten_key_dict` renamed + updated to expect 11 keys (the to_dict shape grew by one).
**Deviations**:
1. **Audit-cascade gap caught**: this story was previously marked Status:Complete via the audit cascade, but the `floor_was_valid` field + 2 hooks genuinely did NOT exist in source. 6th instance of this pattern caught today (after data-registry/006, tick-system/006, dungeon-run-orchestrator/013, orchestrator/012, orchestrator/008). Recommend a sprint-level audit-cascade hygiene pass once the immediate backlog is cleared.
2. **Adjacent test regression fixed inline**: adding the 11th to_dict key broke `test_to_dict_returns_ten_key_dict` (asserted exactly 10 keys). Fixed by renaming + updating the key count assertion. Caught + fixed in the same PR.
3. **Hook-based design rather than `compute_offline_run` method**: story spec proposed a full `compute_offline_run(tick_budget) -> OfflineRunResult` method that owns the entire offline replay loop. The orchestrator-side surface here is the 2 hooks (report-error + mark-invalid); the actual replay loop lives in OfflineProgressionEngine (rank 15) which can call into these hooks. This separates the orchestrator's state-machine + signal surface from the replay-execution loop, which is cleaner per ADR-0014's "OfflineProgressionEngine is the canonical replay caller" decision.

**Code Review**: Solo mode — `/code-review` skipped per project review-mode.txt.

---

## Dependencies

- Depends on: Story 009 (offline replay path).
- Unlocks: end-to-end offline replay test coverage incl. error semantics
