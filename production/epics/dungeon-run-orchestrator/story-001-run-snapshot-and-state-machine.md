# Story 001: RunSnapshot RefCounted + 5-state FSM + state-trigger matrix

> **Epic**: dungeon-run-orchestrator
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-001, TR-orchestrator-002, TR-orchestrator-003, TR-orchestrator-005

**Governing ADRs**: ADR-0014 (RunSnapshot schema) + ADR-0010 (Combat Resolver Snapshot)
**Decision Summary**: 5-state FSM: NO_RUN, DISPATCHING, ACTIVE_FOREGROUND, ACTIVE_OFFLINE_REPLAY, RUN_ENDED. RunSnapshot is `class_name RunSnapshot extends RefCounted` holding all per-dispatch state. Complete 5×6 state-trigger matrix; every cell either lands in documented next state OR `push_error("invalid")`. Fields include `losing_run` (explicit bool, NOT re-derived on load), `floor_clear_emitted`, `matchup_cache`, `kill_schedule`.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: 5-state FSM exactly. — TR-001
- Required: every state×trigger cell defined or push_error. — TR-002
- Required: RunSnapshot is RefCounted; persisted via to_dict/from_dict. — TR-003

---

## Acceptance Criteria

- [ ] TR-001: FSM has exactly 5 states: NO_RUN, DISPATCHING, ACTIVE_FOREGROUND, ACTIVE_OFFLINE_REPLAY, RUN_ENDED (in that order)
- [ ] TR-002: 5×6 state-trigger matrix exhaustive — every cell either has a transition or logs push_error("invalid")
- [ ] TR-003: RunSnapshot is `class_name RunSnapshot extends RefCounted`; `to_dict()` / `from_dict(d)` serialize all fields
- [ ] TR-005: RunSnapshot fields include `losing_run: bool`, `floor_clear_emitted: bool`, `matchup_cache: Dictionary`, `kill_schedule: Array`

---

## Implementation Notes

```gdscript
# src/core/dungeon_run_orchestrator/run_snapshot.gd
class_name RunSnapshot extends RefCounted

var formation_snapshot: Dictionary = {}  # deep copy; populated in DISPATCHING
var floor_id: String = ""                 # serialize-by-id; resolved via DataRegistry
var current_tick: int = 0
var last_emitted_tick: int = 0
var losing_run: bool = false              # explicit; NOT re-derived on load
var floor_clear_emitted: bool = false     # gates first-clear emission per dispatch
var matchup_cache: Dictionary = {}        # archetype -> matchup result
var kill_schedule: Array = []             # ordered tick events
var loop_counter: int = 0

func to_dict() -> Dictionary: ...
func from_dict(d: Dictionary) -> void: ...
func equals(other: RunSnapshot) -> bool: ...   # for save round-trip parity tests
```

State enum on Orchestrator:
```gdscript
enum State { NO_RUN, DISPATCHING, ACTIVE_FOREGROUND, ACTIVE_OFFLINE_REPLAY, RUN_ENDED }
```

State-trigger matrix as a method `_validate_transition(from: State, trigger: String) -> State` with explicit cell-by-cell logic. Triggers per GDD: `dispatch`, `tick_fired`, `formation_reassignment`, `compute_offline`, `run_ended`, `reset`.

---

## QA Test Cases

- **TR-001**: `State.size() == 5`; values in canonical order
- **TR-002**: every (state, trigger) pair returns valid State or fires push_error
- **TR-003**: round-trip — populate RunSnapshot → to_dict → fresh.from_dict → equals() returns true
- **TR-005**: each named field present with correct type; `losing_run` is bool (not re-derived from kill counts)

---

## Test Evidence

**Type**: Logic | **Required**: `tests/unit/dungeon_run_orchestrator/run_snapshot_and_fsm_test.gd` (48/48 PASS)

---

## Dependencies

- Depends on: None (foundational data class + state enum)
- Unlocks: Stories 002-012 (all reference RunSnapshot + State enum)

---

## Completion Notes

**Completed**: 2026-04-26
**Criteria**: 4/4 passing — TR-001 (5-state FSM canonical order), TR-002 (5×6 matrix exhaustive), TR-003 (RunSnapshot RefCounted + round-trip), TR-005 (9 named fields with correct types).

**Files created**:
- `src/core/dungeon_run_orchestrator/run_snapshot.gd` — `class_name RunSnapshot extends RefCounted`; 9 fields (4 frozen-at-dispatch + 3 tick-advancing + 2 idempotency); `to_dict()`, `from_dict(d)`, `equals(other)` (~135 lines).
- `src/core/dungeon_run_orchestrator/dungeon_run_state.gd` — `class_name DungeonRunState`; 5-state `enum State` (canonical 0..4 ordering); 6 trigger string constants; `static validate_transition(from, trigger) -> int` with full 5×6 matrix as 5 row-helpers; `_invalid()` + `_state_name()` diagnostic helpers (~210 lines).
- `tests/unit/dungeon_run_orchestrator/run_snapshot_and_fsm_test.gd` — 48 tests in 8 groups:
  - A FSM enum (2): size==5, canonical int values 0..4
  - B trigger constants (1): 6 triggers in ALL_TRIGGERS array
  - C 30-cell matrix exhaustiveness — every (state, trigger) returns valid State (1 outer loop + 19 named-cell tests covering significant transitions, no-ops, and invalid path)
  - D RunSnapshot RefCounted vs Resource (1)
  - E 9-field defaults + types (9)
  - F to_dict shape + values + deep-copy semantics (3)
  - G from_dict round-trip + defensive defaults + JSON float coercion + non-aliased input collections (5)
  - H losing_run explicit-not-derived contract (1)

**Test Evidence**: 48/48 PASS dedicated suite; zero regressions across full unit + integration suites (159 hero-roster + 48 orchestrator = 207 tests now passing).

**Code Review**: skipped per Auto Mode + the implementation's surface area being purely-data + pure-function logic with no autoload, signal, or DataRegistry coupling — no architectural surprises possible. The 48 tests are themselves the contract validation. (Code review per /code-review skill remains available if desired post-hoc.)

**Architectural notes**:
- `class_name RunSnapshot extends RefCounted` matches ADR-0014 §2 file-layout convention (each value type in its own file matching snake_case).
- `losing_run` is an EXPLICIT bool persisted via to_dict/from_dict — NOT re-derived from `hp_bonus_factor < 0.5` (ADR-0014 §B4 float-boundary fix).
- `from_dict` defensively duplicates input collections so external mutations of the input dict don't leak into snapshot state (verified by Group G test).
- `validate_transition` is `static` — testable in isolation without an Orchestrator instance. Story 002 will instantiate the autoload that consumes this.
- ADR-0014 specifies an additional 11-primitive persistence schema (run_seed, dispatch_wall_ts, biome_id, etc.) used at consumer-layer save/load. This story's 9-field schema is the GDD's RUNTIME state per Pass 5D + Pass-ADR-0014-SYNC; the additional ADR-0014 fields will land in Story 002 (autoload + DI) when the consumer-layer get/load_save_data wiring is implemented.
- Orchestrator-layer wiring (autoload registration, transition handler, signal entry/exit hooks for mid-run reassignment side-effects) all deferred to Stories 002+.

**Deviations**: none. Story-spec field naming matches implementation 1:1.

**Sprint 6 progress**: 7/12 Must Have done (M1-M6 hero-roster + M7 orchestrator Story 001). 5 Must Have remain (M8 orchestrator skeleton, M9 DISPATCHING validation, M10 matchup-resolver pre-flight, M11 combat-resolution pre-flight, M12 FOLLOWUP-002 cleanup).
