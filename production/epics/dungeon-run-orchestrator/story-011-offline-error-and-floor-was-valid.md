# Story 011: ACTIVE_OFFLINE_REPLAY error path + floor_was_valid distinguisher

> **Epic**: dungeon-run-orchestrator
> **Status**: Complete (system shipped; see systems-index Implementation Status #13. Test evidence: `tests/{unit,integration}/dungeon_run_orchestrator/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
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

- [ ] TR-029: offline replay errors transition to RUN_ENDED via `validation_failed("offline_replay_error")`; partial gold retained (no rollback)
- [ ] TR-031: `floor_was_valid` on RunSnapshot — true when Combat returned a non-empty kill schedule; false when floor authoring bug produced empty Combat result

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

---

## Dependencies

- Depends on: Story 009 (offline replay path).
- Unlocks: end-to-end offline replay test coverage incl. error semantics
