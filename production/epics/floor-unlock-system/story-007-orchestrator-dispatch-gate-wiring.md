# Story 007: Orchestrator DISPATCHING gate — FloorUnlock.is_unlocked check

> **Epic**: floor-unlock-system
> **Status**: Complete (real implementation 2026-05-08 — added lazy-bind in orchestrator `_ready()` + new integration test (5 functions) covering all 4 ACs. Type widened from `RefCounted` to `Object` to accept the Node autoload. 2 adjacent tests updated for the AC-mandated fail-open removal.)
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/floor-unlock-system.md`
**Requirements**: TR-floor-unlock-026

**Governing ADR**: ADR-0009 (DI lazy-default)
**Decision Summary**: At DISPATCHING transition (per dungeon-run-orchestrator Story 003), the orchestrator queries `FloorUnlock.is_unlocked(floor_index)`; if false, emits `validation_failed("floor_locked", {"floor_index": ...})` and transitions to RUN_ENDED. The orchestrator already has `set_floor_unlock(fu)` injection seam from Sprint 7; this story replaces the test-spy default with the production `FloorUnlock` autoload binding. Lazy-default: when `_floor_unlock` is null at orchestrator `_ready()`, bind to the `FloorUnlock` autoload via `get_node_or_null("/root/FloorUnlock")`.

**Engine**: Godot 4.6 | **Risk**: LOW (existing seam from Sprint 7; this story just replaces the null-fail-open path with production binding)

**Control Manifest Rules**:
- Required: orchestrator's `_floor_unlock` field is bound to FloorUnlock autoload at `_ready()` if not already injected (TR-026)
- Required: dispatch-time `is_unlocked(floor_index)` check fires BEFORE snapshot construction (Sprint 7 dispatching-validation order — already in place)
- Required: when locked, `validation_failed.emit("floor_locked", {"floor_index": ...})` and state transitions to RUN_ENDED (no snapshot built, no Combat call, no Economy mutation)

---

## Acceptance Criteria

- [x] TR-026 lazy-bind: orchestrator `_ready()` auto-binds `_floor_unlock = FloorUnlock` when no spy injected; pre-injected spy survives
- [x] TR-026 locked rejection: dispatch with `floor_index` where `FloorUnlock.is_unlocked(floor_index) == false` triggers `validation_failed("floor_locked", {"floor_index": <i>})` and state → RUN_ENDED
- [x] TR-026 unlocked passes: dispatch with valid floor proceeds normally (snapshot built, ACTIVE_FOREGROUND entered)
- [x] TR-026 fail-open removed: with production FloorUnlock bound, `is_unlocked(0)` returns false (sentinel); previous test-env null-fail-open path no longer reached in production

---

## Implementation Notes

The orchestrator's `dispatch()` already has the floor-locked check from Sprint 7 S6-M11 / S7's dispatching_validation:

```gdscript
# src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd
if _floor_unlock != null and not _floor_unlock.is_unlocked(floor_index):
	validation_failed.emit("floor_locked", {"floor_index": floor_index})
	# transition to RUN_ENDED via matrix
	...
```

This story:
1. Adds a lazy-default to `_ready()` that binds `_floor_unlock` to the FloorUnlock autoload when not pre-injected.
2. Removes the comment that called the null-path "fail-open" (production now has a real FloorUnlock; null is a bug-by-omission).
3. Adds an integration test that dispatches against a locked floor with the production FloorUnlock autoload and verifies the locked rejection.

```gdscript
func _ready() -> void:
	# ... existing resolver lazy-defaults ...
	if _floor_unlock == null:
		_floor_unlock = get_node_or_null("/root/FloorUnlock")
```

---

## Out of Scope

- DispatchScreen UI's pre-emptive lock badge — Sprint 8 Must Have S8-M1 (UI epic territory)

---

## QA Test Cases

- **AC TR-026 lazy-bind**:
  - Given: orchestrator instantiated; FloorUnlock autoload registered
  - When: orchestrator `_ready()` completes
  - Then: `orch._floor_unlock` is the FloorUnlock autoload Node (`get_node("/root/FloorUnlock")`)

- **AC TR-026 spy survival**:
  - Given: spy FloorUnlock injected via `set_floor_unlock(spy)` BEFORE add_child
  - When: `_ready()` runs
  - Then: `orch._floor_unlock` is the spy, NOT the autoload (lazy-default doesn't overwrite)

- **AC TR-026 locked floor rejection**:
  - Given: production FloorUnlock with `_unlock_state["forest_reach"] = 0` (only floor 1 unlocked); orchestrator with valid formation
  - When: `orch.dispatch([hero1, hero2, hero3], 5, "forest_reach")` — floor 5 is locked
  - Then: `validation_failed("floor_locked", {"floor_index": 5})` emitted; state == RUN_ENDED; no run_snapshot built

- **AC TR-026 unlocked floor passes**:
  - Given: same FloorUnlock state (floor 1 unlocked); valid formation
  - When: `orch.dispatch(..., 1, "forest_reach")`
  - Then: state advances to ACTIVE_FOREGROUND; no validation_failed emission

- **AC TR-026 sentinel rejection**:
  - When: `orch.dispatch(..., 0, "forest_reach")`
  - Then: rejected (FloorUnlock.is_unlocked(0) returns false per TR-011)

---

## Test Evidence

**Story Type**: Integration
**Required**: `tests/integration/floor_unlock/orchestrator_dispatch_gate_test.gd`

---

## Dependencies

- **Depends on**: Stories 001-006 + DungeonRunOrchestrator dispatch validation (Sprint 7 in place)
- **Unlocks**: Sprint 8 S8-M1 DispatchScreen UI (validation_failed → toast)
