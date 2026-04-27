# Story 008: Mid-run formation reassignment terminates run (ADR-0001)

> **Epic**: dungeon-run-orchestrator
> **Status**: Ready
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

- [ ] TR-020: `formation_reassignment_committed` while in ACTIVE_FOREGROUND triggers ACTIVE_FOREGROUND → RUN_ENDED → DISPATCHING cascade (with new formation)
- [ ] TR-021: `formation_browse_opened` signal is IGNORED — no state change

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

---

## Dependencies

- Depends on: Story 002 (autoload), Story 003 (dispatch entry point), Story 005 (ACTIVE_FOREGROUND state). FormationAssignment autoload from its epic (or mocked).
- Unlocks: end-to-end test of player UX: open Formation screen, swap a hero, current run terminates and new run begins
