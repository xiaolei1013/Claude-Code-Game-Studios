# Story 001: SaveLoadSystem autoload skeleton + CONSUMER_PATHS + state machine

> **Epic**: save-load-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md`
**Requirements**: TR-save-load-031, TR-save-load-032, TR-save-load-033, TR-save-load-034, TR-save-load-045, TR-save-load-046, TR-save-load-055, TR-save-load-057, TR-save-load-058
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0003 (primary — autoload rank table, Amendment #3 zero-arg `_init`, CONSUMER_PATHS), ADR-0004 (envelope owner), ADR-0007 (signal subscription wiring at `_ready()`)
**ADR Decision Summary**: SaveLoadSystem is autoload rank 2 with a hardcoded 6-entry ordered `CONSUMER_PATHS` list; consumers resolved per-call via `get_node_or_null` (never cached). Autoload script `_init` MUST be zero-arg.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Autoload script `_init` zero-arg invariant (Claim 4 VERIFIED per ADR-0003 Amendment #3). Signal subscription across any rank pair at `_ready()` is safe per Claim 1 VERIFIED. `get_node_or_null(path)` + explicit nil-check contract (per-call, no caching).

**Control Manifest Rules (Foundation Layer, SaveLoadSystem)**:
- **Required**: Autoload identifier `SaveLoadSystem` at rank 2; `class_name SaveLoadSystem extends Node`; zero-arg `_init`. `CONSUMER_PATHS` is a hardcoded ordered `PackedStringArray` of exactly 6 entries in rank order: `/root/Economy`, `/root/HeroRoster`, `/root/FloorUnlock`, `/root/FormationAssignment`, `/root/Recruitment`, `/root/DungeonRunOrchestrator`. Resolve consumers via per-call `get_node_or_null(path)` with explicit nil-check + fatal assert. At `_ready()`: connect `TimeSystem.flag_suspicious_timestamp_emitted` + `SceneManager.scene_boundary_persist`; check `DataRegistry.state`; invoke load pipeline. State machine: `UNLOADED | LOADING | READY | PERSISTING | CORRUPT | MIGRATION`. `PERSISTING → PERSISTING` overlap drops new trigger + `push_warning`. `LoadResult` enum has exactly 7 codes: `OK, ERR_FILE_ABSENT, ERR_TAMPER_SUSPECTED, ERR_REGISTRY_UNAVAILABLE, ERR_CORRUPT_BOTH, ERR_SCHEMA_MISMATCH, ERR_IO`.
- **Forbidden**: Reordering autoload ranks. Caching consumer references in instance vars. Consumers self-registering via `add_to_group("save_consumer")` or runtime registration. Same-or-backward state reads at `_ready()`. Declaring `_init(...)` with required parameters.

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] Autoload registered in `project.godot` at rank 2 (after `DataRegistry`, before `Economy`)
- [ ] `class_name SaveLoadSystem extends Node` with zero-arg `_init` (no required params)
- [ ] `const CONSUMER_PATHS: PackedStringArray = ["/root/Economy", "/root/HeroRoster", "/root/FloorUnlock", "/root/FormationAssignment", "/root/Recruitment", "/root/DungeonRunOrchestrator"]`
- [ ] State enum declared with exactly 6 values (`UNLOADED, LOADING, READY, PERSISTING, CORRUPT, MIGRATION`)
- [ ] `LoadResult` typed result (enum `ResultCode` with 7 values + `code: ResultCode` field) per TR-save-load-055
- [ ] `_ready()` connects `TimeSystem.flag_suspicious_timestamp_emitted` + `SceneManager.scene_boundary_persist`; checks `DataRegistry.state`
- [ ] Signals declared: `save_completed`, `save_failed`, `tamper_detected_on_load`, `first_launch`, `corrupt_both_acknowledged`
- [ ] State transition guard rejects invalid transitions with `push_warning`; `PERSISTING → PERSISTING` coalesces (drops new trigger)
- [ ] Helper `_resolve_consumer(path: String) -> Node` does `get_node_or_null` + nil-check + fatal guard in production (`push_error` + `get_tree().quit(1)`)

---

## Implementation Notes

- Use `enum State { UNLOADED, LOADING, READY, PERSISTING, CORRUPT, MIGRATION }` plus `var _state: State = State.UNLOADED`
- State machine transitions routed through a single private `_transition_to(next: State)` method with a hardcoded transition table; same-state no-ops; illegal transitions `push_warning` and short-circuit
- Signal subscription MUST be at `_ready()` (Claim 1 VERIFIED: signal objects exist at Node instantiation; rank-2 may subscribe to rank-0 TickSystem and rank ≥6 SceneManager)
- DataRegistry state read at `_ready()` is valid (rank 1 < rank 2; its `_ready()` has already fired)
- `LoadResult` is `class_name LoadResult extends RefCounted` with `code: ResultCode` + optional `detail: String`; return-by-value
- Consumer resolution helper exits via `push_error` + `get_tree().quit(1)` pattern, NOT `assert()` (assert is stripped from release builds per ADR-0004 Rule 14 mirror / TR-save-load-051)
- Heartbeat and full-envelope persist entry points stub out here (`request_full_persist(reason)`, `request_heartbeat_persist(time_fields)`) — bodies filled in later stories
- `first_launch` signal deferred to Story 007 hydration path; declaration lives here
- `scene_boundary_persist(reason)` handler is a stub that logs in this story; actual async await-and-commit wiring is Story 012

---

## Out of Scope

- Story 002: envelope binary layout
- Story 004 / 005: HMAC key derivation + RFC 4231 conformance
- Story 007: consumer persist/hydrate loop body
- Story 008: atomic write + iOS/Android fallback
- Story 011: heartbeat partial-envelope body
- Story 012: scene-boundary async await + abort modal

---

## QA Test Cases

- **TR-save-load-031 / TR-save-load-034**: SaveLoadSystem autoload rank + CONSUMER_PATHS list
  - **Given**: The project boots with `project.godot` autoloads registered
  - **When**: Test queries `/root/SaveLoadSystem.CONSUMER_PATHS`
  - **Then**: Returned `PackedStringArray` is exactly 6 entries in the canonical order
  - **Edge cases**: Fails if any path is reordered, added, or removed without lockstep GDD + project.godot edit

- **TR-save-load-032**: `_ready()` signal wiring
  - **Given**: `TimeSystem` and `SceneManager` autoloads exist
  - **When**: SaveLoadSystem `_ready()` completes
  - **Then**: `TimeSystem.flag_suspicious_timestamp_emitted.is_connected(...)` returns true; `SceneManager.scene_boundary_persist.is_connected(...)` returns true
  - **Edge cases**: Signal connection count is exactly 1 per signal (no double-connect on reload)

- **TR-save-load-045**: State machine enum
  - **Given**: Fresh autoload instantiation
  - **When**: Test inspects `State` enum
  - **Then**: Exactly 6 members (`UNLOADED, LOADING, READY, PERSISTING, CORRUPT, MIGRATION`); initial `_state == UNLOADED`

- **TR-save-load-046**: PERSISTING → PERSISTING overlap
  - **Given**: State is `PERSISTING` (in-flight persist)
  - **When**: A second `request_full_persist(reason)` fires before the first completes
  - **Then**: New trigger is dropped; `push_warning` is emitted once; state stays `PERSISTING`; no second persist executes
  - **Edge cases**: Must not call `push_error`; must not enter an invalid state

- **TR-save-load-055**: LoadResult enum completeness
  - **Given**: `LoadResult.ResultCode` enum declared
  - **When**: Test enumerates values
  - **Then**: Exactly 7 codes present with canonical names `OK, ERR_FILE_ABSENT, ERR_TAMPER_SUSPECTED, ERR_REGISTRY_UNAVAILABLE, ERR_CORRUPT_BOTH, ERR_SCHEMA_MISMATCH, ERR_IO`

- **TR-save-load-034 (guard path)**: Consumer resolve nil-check
  - **Given**: Debug test strips the `Economy` autoload from `/root`
  - **When**: `_resolve_consumer("/root/Economy")` runs
  - **Then**: In debug builds, a captured `push_error` + process-exit mechanism fires (test asserts via a debug-only interception hook; production behavior is `get_tree().quit(1)`)

- **ADR-0003 Amendment #3**: Zero-arg `_init`
  - **Given**: SaveLoadSystem autoload script
  - **When**: Grep scan runs (or reflection test invokes `_init()` with zero args)
  - **Then**: `_init` either omitted or declared with all-default parameters — instantiation succeeds
  - **Edge cases**: CI grep `autoload_init_with_required_args` MUST return zero hits against `save_load_system.gd`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/save_load/autoload_skeleton_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None (this is the epic entry point; DataRegistry rank 1 + TickSystem rank 0 + SceneManager assumed present as autoload shells)
- **Unlocks**: Story 002 (envelope layout), Story 007 (consumer loop), Story 012 (scene-boundary)
