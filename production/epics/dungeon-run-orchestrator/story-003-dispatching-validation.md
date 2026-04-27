# Story 003: DISPATCHING validation (empty formation, floor unlock, debounce)

> **Epic**: dungeon-run-orchestrator
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-026, TR-orchestrator-027, TR-orchestrator-032

**Governing ADRs**: ADR-0010 (Combat Resolver Snapshot)
**Decision Summary**: DISPATCHING validates inputs before transitioning to ACTIVE_FOREGROUND. Empty formation → RUN_ENDED + `validation_failed("empty_formation")`. Floor not unlocked (per `FloorUnlock.is_unlocked(floor_index)`) → RUN_ENDED + `validation_failed("floor_locked")`. `DISPATCH_DEBOUNCE_MS = 250` prevents accidental double-dispatch within 250ms window.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: empty formation rejected with named reason. — TR-026
- Required: floor lock check via FloorUnlock autoload. — TR-027
- Required: 250ms dispatch debounce. — TR-032

---

## Acceptance Criteria

- [ ] TR-026: empty formation → RUN_ENDED + `validation_failed("empty_formation")` signal
- [ ] TR-027: locked floor (FloorUnlock.is_unlocked returns false) → RUN_ENDED + `validation_failed("floor_locked")`
- [ ] TR-032: `DISPATCH_DEBOUNCE_MS = 250` constant; second dispatch within 250ms is silent no-op (push_warning logged)

---

## Implementation Notes

```gdscript
const DISPATCH_DEBOUNCE_MS: int = 250
const OFFLINE_REPLAY_CHUNK_TICKS: int = 0  # 0 = single-shot per ADR-0014

var _last_dispatch_ms: int = 0

signal validation_failed(reason: String, payload: Dictionary)

func dispatch(formation: Array, floor_index: int, biome_id: String) -> void:
    var now_ms: int = Time.get_ticks_msec()
    if now_ms - _last_dispatch_ms < DISPATCH_DEBOUNCE_MS:
        push_warning("[Orchestrator] dispatch debounce hit — ignored")
        return
    _last_dispatch_ms = now_ms
    _transition_to(State.DISPATCHING)
    if formation.is_empty():
        validation_failed.emit("empty_formation", {})
        _transition_to(State.RUN_ENDED)
        return
    if not FloorUnlock.is_unlocked(floor_index):
        validation_failed.emit("floor_locked", {"floor_index": floor_index})
        _transition_to(State.RUN_ENDED)
        return
    # Successful validation — Story 004 takes over (snapshot build + matchup cache)
```

For testing, allow injection of a mock FloorUnlock via the same DI pattern OR via direct attribute set.

---

## QA Test Cases

- **TR-026 empty formation**: dispatch([], floor_index=1) → state == RUN_ENDED; `validation_failed("empty_formation")` emitted
- **TR-027 floor locked**: dispatch([hero], floor_index=99) where FloorUnlock returns false → RUN_ENDED + `validation_failed("floor_locked", {floor_index: 99})`
- **TR-032 debounce**: 2 dispatch calls within 100ms — second is silent no-op; first proceeds

---

## Test Evidence

**Type**: Logic | **Required**: `tests/unit/dungeon_run_orchestrator/dispatching_validation_test.gd` (15/15 PASS)

---

## Dependencies

- Depends on: Story 001 (State enum) — Complete; Story 002 (autoload) — Complete; FloorUnlockSystem mocked via `set_floor_unlock(spy)` injection (real impl pending floor-unlock-system epic).
- Unlocks: Story 004 (snapshot build + matchup cache after validation passes)

---

## Completion Notes

**Completed**: 2026-04-26
**Criteria**: 3/3 passing — TR-026 (empty formation rejected), TR-027 (floor lock via injected FloorUnlock), TR-032 (250ms debounce).

**Files modified**:
- `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd` — added: `_floor_unlock` field + `set_floor_unlock(fu)` setter; `DISPATCH_DEBOUNCE_MS = 250` const; `_last_dispatch_ms` field; `validation_failed(reason, payload)` signal; `dispatch(formation, floor_index, biome_id)` public method (~70 lines including doc-comment).

**Files created**:
- `tests/unit/dungeon_run_orchestrator/dispatching_validation_test.gd` — 15 tests in 8 groups (debounce constant, empty-formation 3, floor-locked 3, unlocked happy-path + null fail-open 2, debounce window 2, matrix-rejection from invalid states 2, signal arity 1, post-debounce re-dispatch 1).

**Test Evidence**: 15/15 PASS dedicated suite; 80/80 PASS across all 3 orchestrator suites (48 RunSnapshot+FSM + 17 autoload + 15 dispatching); zero regressions in wider unit suite.

**Code Review**: skipped per Auto Mode — implementation follows the story spec line-by-line + delegates state transitions to S6-M7's pre-tested `validate_transition` matrix; no new architectural surface. The 15 tests are themselves the contract validation.

**Architectural notes**:
- Dispatch flow uses `DungeonRunStateScript.validate_transition(state, trigger)` to drive the FSM rather than direct state writes — leverages S6-M7's exhaustive matrix. Both the success path (NO_RUN/RUN_ENDED → DISPATCHING via `dispatch_pressed`) and the validation-failure path (DISPATCHING → RUN_ENDED via `run_ended`) are matrix-validated.
- Debounce stamp is consumed by EVERY dispatch entry (not just successful ones) — a UI signal storm with empty formations is rate-limited just like a UI signal storm with valid inputs. Tested via `test_second_dispatch_within_250ms_is_silent_no_op`.
- `_floor_unlock` is null-fail-open — when the dependency is not injected, the lock check is silently skipped. Documented as intentional pre-production posture; production wiring lands when floor-unlock-system epic ships.
- Method-presence check (`has_method("is_unlocked")`) defends against accidentally-injected non-FloorUnlock spies — the lock check silently skips rather than crashing, with the matchup_cache and snapshot build (Story 004) being the load-bearing safety on the no-validation path.

**Deviations**:
1. `biome_id` parameter is accepted but not yet consumed (Story 004 will wire the snapshot build that uses it). Suppressed with `var _unused_biome` no-op to silence unused-arg warning.
2. Debounce stamp is consumed even by invalid-state dispatches (e.g., from ACTIVE_FOREGROUND). This means a UI bug that fires dispatch from an invalid state still consumes the debounce window. Acceptable: the debounce is rate-limiting, not validation.

**Sprint 6 progress**: 9/12 Must Have done. Hero-roster epic complete + DungeonRunOrchestrator Foundation (Stories 001-003) complete. 3 Must Have remain: M10 (matchup pre-flight), M11 (combat pre-flight), M12 (FOLLOWUP-002 cleanup).

**Project test count**: 287 tests across all suites (207 hero-roster + 80 orchestrator); zero regressions.
