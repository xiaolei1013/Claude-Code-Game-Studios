# Story 010: Save/Load consumer contract + RunSnapshot round-trip

> **Epic**: dungeon-run-orchestrator
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-030

**Governing ADRs**: ADR-0004 (Save Envelope) + ADR-0014 (RunSnapshot persist)
**Decision Summary**: Orchestrator implements Save/Load consumer contract: `get_save_data() -> Dictionary` and `load_save_data(d: Dictionary) -> void`. Namespace key `"orchestrator"`. Round-trip via `RunSnapshot.equals()` semantic equality check. Persists `state` enum + full `run_snapshot` (RunSnapshot.to_dict).

**Engine**: Godot 4.6 | **Risk**: LOW (round-trip serialization)

---

## Acceptance Criteria

- [ ] TR-030: `get_save_data() / load_save_data()` element-layer naming
- [ ] TR-030: namespace key `"orchestrator"` in CONSUMER_PATHS
- [ ] TR-030: round-trip preserves state + run_snapshot via `RunSnapshot.equals()`

---

## Implementation Notes

```gdscript
func get_save_data() -> Dictionary:
    return {
        "state": int(state),
        "run_snapshot": run_snapshot.to_dict() if run_snapshot != null else {},
        "last_dispatch_ms": _last_dispatch_ms,
    }

func load_save_data(d: Dictionary) -> void:
    state = d.get("state", State.NO_RUN) as State
    var snap_dict: Dictionary = d.get("run_snapshot", {})
    if snap_dict.is_empty():
        run_snapshot = null
    else:
        run_snapshot = RunSnapshot.new()
        run_snapshot.from_dict(snap_dict)
        # Validate floor_id resolves
        if DataRegistry.resolve("floors", run_snapshot.floor_id) == null:
            push_warning("[Orchestrator] saved floor_id '%s' unresolvable on load; resetting to NO_RUN" % run_snapshot.floor_id)
            run_snapshot = null
            state = State.NO_RUN
    _last_dispatch_ms = int(d.get("last_dispatch_ms", 0))
    # If loaded into ACTIVE_FOREGROUND, re-subscribe TickSystem connection
    if state == State.ACTIVE_FOREGROUND and run_snapshot != null:
        _enter_active_foreground()
```

Register `"DungeonRunOrchestrator"` in `SaveLoadSystem.CONSUMER_PATHS` (after HeroRoster).

---

## QA Test Cases

- **TR-030 round-trip**: dispatch + 5 ticks → snapshot has 5 emitted ticks → get_save_data → fresh orchestrator.load_save_data → run_snapshot.equals(original) is true
- **TR-030 unresolvable floor**: save with floor_id "deleted_floor" → load → state goes NO_RUN; run_snapshot is null; push_warning emitted
- **State preservation**: load with state=ACTIVE_FOREGROUND → tick subscription re-established (is_connected returns true)

---

## Test Evidence

**Type**: Integration | **Required**: `tests/integration/dungeon_run_orchestrator/save_load_round_trip_test.gd`

---

## Dependencies

- Depends on: Story 001 (RunSnapshot.to_dict/from_dict/equals), Story 002 (autoload), Story 005 (re-subscribe on load). SaveLoadSystem from Sprint 4.
- Unlocks: end-to-end save/load testing across full dispatch lifecycle
