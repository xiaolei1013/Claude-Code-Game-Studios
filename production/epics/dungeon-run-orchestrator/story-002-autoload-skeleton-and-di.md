# Story 002: Orchestrator autoload skeleton + DI setters + lazy-default resolvers

> **Epic**: dungeon-run-orchestrator
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-023, TR-orchestrator-024

**Governing ADRs**: ADR-0009 (Matchup Resolver DI) + ADR-0003 Amendment #3 (zero-arg `_init`)
**Decision Summary**: Orchestrator is autoload at `/root/DungeonRunOrchestrator`. Zero-arg `_init` (autoload constraint). Resolvers (CombatResolver + MatchupResolver) wired via lazy-default-with-public-setters: `set_combat_resolver(spy)` / `set_matchup_resolver(spy)` / `set_error_logger(spy)` for test injection BEFORE `_ready()`. In `_ready()`, IF resolver is still null, instantiate the default via `DefaultMatchupResolver.new()` / `DefaultCombatResolver.new()`.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: zero-arg `_init` per ADR-0003 Amendment #3. — TR-023
- Required: lazy-default resolver pattern. — TR-024
- Forbidden: required-arg `_init` on autoload (would crash boot).

---

## Acceptance Criteria

- [ ] TR-023: registered as autoload at `/root/DungeonRunOrchestrator`; resolvers lazy-default in `_ready()` if not pre-injected
- [ ] TR-024: 3 DI setters: `set_combat_resolver(r)`, `set_matchup_resolver(r)`, `set_error_logger(l)`; tests can inject spies before `_ready()` fires

---

## Implementation Notes

```gdscript
extends Node  # NO class_name — autoload identifier provides global access

var _combat_resolver: RefCounted = null
var _matchup_resolver: RefCounted = null
var _error_logger: RefCounted = null
var state: State = State.NO_RUN
var run_snapshot: RunSnapshot = null

func _init() -> void:
    pass  # ADR-0003 Amendment #3 zero-arg

func _ready() -> void:
    if _matchup_resolver == null:
        _matchup_resolver = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd").new()
    if _combat_resolver == null:
        _combat_resolver = preload("res://src/core/combat/default_combat_resolver.gd").new()
    # error_logger remains null in MVP; push_error/push_warning are the default

func set_combat_resolver(r: RefCounted) -> void: _combat_resolver = r
func set_matchup_resolver(r: RefCounted) -> void: _matchup_resolver = r
func set_error_logger(l: RefCounted) -> void: _error_logger = l
```

Register in `project.godot` after HeroRoster (rank order per ADR-0003 §Editing Protocol — claim a vacant slot).

---

## QA Test Cases

- **TR-023 autoload**: `get_tree().root.get_node_or_null("DungeonRunOrchestrator")` returns non-null
- **TR-024 setters**: inject spy resolver via `set_matchup_resolver(spy)`; assert `_matchup_resolver is spy_class` after `_ready`
- **TR-024 lazy-default**: instantiate fresh non-autoload Orchestrator; call `_ready()` without injection; assert `_combat_resolver` and `_matchup_resolver` are non-null defaults
- **Zero-arg `_init`**: `OrchestratorScript.new()` succeeds without args

---

## Test Evidence

**Type**: Logic | **Required**: `tests/unit/dungeon_run_orchestrator/autoload_skeleton_and_di_test.gd` (17/17 PASS)

---

## Dependencies

- Depends on: Story 001 (State enum referenced) — Complete
- Unlocks: Stories 003-012 (all use orchestrator instance + resolver injection)

---

## Completion Notes

**Completed**: 2026-04-26
**Criteria**: 2/2 passing — TR-023 (autoload + lazy-default), TR-024 (3 DI setters with spy-injection-before-_ready).

**Files created**:
- `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd` — autoload skeleton (~120 lines): zero-arg `_init` + `_ready()` lazy-default + 3 DI setters + state field initialized to `DungeonRunState.State.NO_RUN`.
- `src/core/matchup_resolver/default_matchup_resolver.gd` — Sprint 6 stub (RefCounted; production impl pending matchup-resolver epic).
- `src/core/combat/default_combat_resolver.gd` — Sprint 6 stub (RefCounted; production impl pending combat-resolution epic).
- `tests/unit/dungeon_run_orchestrator/autoload_skeleton_and_di_test.gd` — 17 tests in 8 groups (autoload registration, zero-arg init, state init, 3 DI setters, spy-survives-_ready, lazy-default-instantiates, live autoload state, setter-after-_ready replaces default).

**Files modified**:
- `project.godot` — added `DungeonRunOrchestrator="*res://..."` after `SceneManager` (claims next vacant rank slot per ADR-0003 §Editing Protocol).

**Test Evidence**: 17/17 PASS dedicated suite; zero regressions across full unit + integration suites.

**Code Review**: skipped per Auto Mode — implementation is a no-architecture-risk autoload skeleton matching the documented ADR-0009 + ADR-0003 patterns 1:1. The 17 tests are themselves the contract validation. (Per Auto Mode; reviewers reserved for higher-risk Logic/Integration stories.)

**Architectural notes**:
- Stub `Default*Resolver` scripts are deliberate placeholders — they exist solely to make the orchestrator's `preload(...)` paths resolve at parse time. Both have `is_stub() -> String` accessors returning a marker so tests can verify "the lazy default was instantiated" without depending on production resolver shape.
- Production resolver impls land in matchup-resolver and combat-resolution epics (story bundles via S6-M10/M11 pre-flight `/create-stories`). When they ship, the stub files can be deleted — the orchestrator's preload paths will pick up the real impls automatically (provided file paths match).
- `_error_logger` has NO lazy default — push_error / push_warning are the MVP fallback. Story 003+ may inject a recording_logger Callable per GDD §J.4.
- ADR-0014 specifies orchestrator at rank 14; current registration claims next vacant slot (rank 12 given current autoload count). Slot ordering is not load-bearing in MVP since the orchestrator's _ready() doesn't subscribe to lower-rank autoloads — Story 005 will add the TickSystem subscription and ordering becomes relevant.

**Deviations**:
1. `state` field type declared as `int` (with default `DungeonRunStateScript.State.NO_RUN`) instead of typed enum reference. GDScript 4 can't name-reference an enum via `class_name`-script-loaded constant in field type position; the int + manual constant pattern is the working alternative. Doc-comment notes the field is one of `DungeonRunState.State`.

**Sprint 6 progress**: 8/12 Must Have done (M1-M6 hero-roster + M7 RunSnapshot/FSM + M8 autoload skeleton). 4 Must Have remain (M9 DISPATCHING validation, M10 matchup pre-flight, M11 combat pre-flight, M12 FOLLOWUP-002 cleanup).

**Project test count**: 207 hero-roster + 65 orchestrator (48 + 17) = 272 passing tests across all suites; zero regressions.
