# Story 008: Mid-run formation reassignment terminates run (ADR-0001)

> **Epic**: dungeon-run-orchestrator
> **Status**: Complete (real implementation 2026-05-08 — handler + autoload subscription added to source; integration test ships with 7 functions covering both ACs + cascade-step verification. Audit-cascade Status flip from earlier was over-eager: the source handler did NOT exist before this PR, despite the system-level claim.)
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-020, TR-orchestrator-021

**Governing ADRs**: ADR-0001 (Mid-Run Formation Reassignment Forbidden)
**Decision Summary**: Mid-run formation reassignment is **forbidden** — the formation is locked at dispatch. Receiving `formation_reassignment_committed` while in ACTIVE_FOREGROUND triggers state cascade: ACTIVE_FOREGROUND → RUN_ENDED → DISPATCHING (with the new formation). `formation_browse_opened` is IGNORED (read-only signal); only `formation_reassignment_committed` triggers run-end.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (cross-system signal handling + state cascade)

---

## Acceptance Criteria

- [x] TR-020: `formation_reassignment_committed` while in ACTIVE_FOREGROUND triggers ACTIVE_FOREGROUND → RUN_ENDED → DISPATCHING cascade (with new formation) — **MET**: cascade verified end-to-end (intermediate transitions captured via `state_changed` spy in `test_tr020_cascade_emits_state_changed_at_each_intermediate_step`); end state is ACTIVE_FOREGROUND again because dispatch() success continues through to the live state, which is the correct UX (new run live, not stuck mid-cascade).
- [x] TR-021: `formation_browse_opened` signal is IGNORED — no state change — **MET**: orchestrator does not subscribe to the signal at all; verified by inspecting FormationAssignment autoload's `formation_browse_opened.get_connections()` — orchestrator's handler is absent from the connection list.

---

## Implementation Notes

```gdscript
func _ready() -> void:
    # ... existing setup ...
    if FormationAssignment != null:  # autoload may be present
        FormationAssignment.formation_reassignment_committed.connect(_on_formation_reassigned)
        # NOTE: formation_browse_opened is intentionally NOT connected (read-only)

func _on_formation_reassigned(new_formation: Array) -> void:
    if state != State.ACTIVE_FOREGROUND:
        return  # only mid-run reassignment cascades
    # Cascade: terminate current run, immediately dispatch with new formation
    _transition_to(State.RUN_ENDED)
    var prev_floor_id: String = run_snapshot.floor_id if run_snapshot else ""
    var prev_biome_id: String = _get_biome_id() if run_snapshot else ""
    if not prev_floor_id.is_empty():
        var floor: Floor = DataRegistry.resolve("floors", prev_floor_id) as Floor
        if floor != null:
            dispatch(new_formation, floor.index, prev_biome_id)
```

---

## QA Test Cases

- **TR-020 cascade**: orchestrator in ACTIVE_FOREGROUND with run_snapshot for floor 1; `formation_reassignment_committed` fires with new formation → state goes RUN_ENDED then DISPATCHING; new run_snapshot has the new formation
- **TR-021 browse ignored**: orchestrator in ACTIVE_FOREGROUND; `formation_browse_opened` signal fires → state unchanged (still ACTIVE_FOREGROUND)
- **State guard**: `formation_reassignment_committed` fires while orchestrator is in NO_RUN → ignored (no transition)

---

## Test Evidence

**Type**: Integration | **Required**: `tests/integration/dungeon_run_orchestrator/mid_run_reassignment_test.gd`

**Status**: [x] `tests/integration/dungeon_run_orchestrator/mid_run_reassignment_test.gd` — 7 test functions, 7/7 PASS:
- `test_tr020_formation_reassignment_in_active_foreground_cascades_then_re_dispatches` (TR-020 end-state + snapshot identity)
- `test_tr020_cascade_emits_state_changed_at_each_intermediate_step` (TR-020 intermediate-state verification via signal spy)
- `test_tr021_orchestrator_does_not_subscribe_to_formation_browse_opened` (TR-021)
- `test_state_guard_no_run_ignores_formation_reassignment_committed` (state guard NO_RUN)
- `test_state_guard_run_ended_ignores_formation_reassignment_committed` (state guard RUN_ENDED)
- `test_state_guard_dispatching_ignores_formation_reassignment_committed` (state guard DISPATCHING — edge case)
- `test_end_to_end_formation_assignment_signal_routes_to_orchestrator_handler` (production routing path: autoload emit → handler invocation)

Full project suite: 1685/1685 PASS (was 1678, +7 net), zero regressions.

---

## Completion Notes

**Completed**: 2026-05-08 (real implementation — handler + autoload subscription added to source; integration test written from scratch).
**Criteria**: 2/2 ACs met
**Test Evidence**: `tests/integration/dungeon_run_orchestrator/mid_run_reassignment_test.gd` (7 functions, 7/7 PASS).
**Files changed**:
- `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd` — added `_subscribe_to_formation_reassignment()` helper called from `_ready()`; added `_on_formation_reassignment_committed(new_formation)` handler implementing the cascade (state guard, capture floor/biome, `_set_state(RUN_ENDED)`, clear debounce, `dispatch(new_formation, captured_floor, captured_biome)`).
- `tests/integration/dungeon_run_orchestrator/mid_run_reassignment_test.gd` — new file, 7 tests.
**Deviations**:
1. **Audit-cascade gap caught**: this story was previously marked Status:Complete via the 2026-04-26-ish audit cascade, but the source handler genuinely did NOT exist before this PR. `formation_reassignment_committed` was being emitted by FormationAssignment but not consumed by the orchestrator. The cascade behavior in ADR-0001 was unenforced. This PR adds the missing implementation. (5th instance of the audit-cascade-over-eager-flip pattern caught today.)
2. **End-state semantics**: AC text reads "ACTIVE_FOREGROUND → RUN_ENDED → DISPATCHING" — these are the INTERMEDIATE transitions during the cascade. The end state with valid inputs is ACTIVE_FOREGROUND again (new run live). Verified via signal spy that the intermediate states are reached in the correct order; documented in test header comments.
3. **Debounce bypass on cascade**: the cascade clears `_last_dispatch_ms = 0` before re-dispatching so the cascade isn't rejected as a rapid-fire double-dispatch. Documented in handler doc-comment with rationale (cascade is internally-triggered by player intent, not a UI signal storm).

**Code Review**: Solo mode — `/code-review` skipped per project review-mode.txt.

---

## Dependencies

- Depends on: Story 002 (autoload), Story 003 (dispatch entry point), Story 005 (ACTIVE_FOREGROUND state). FormationAssignment autoload from its epic (or mocked).
- Unlocks: end-to-end test of player UX: open Formation screen, swap a hero, current run terminates and new run begins
