# Story 001: DataRegistry autoload skeleton and state machine

> **Epic**: data-registry
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/data-loading.md`
**Requirements**: [TR-data-loading-001, TR-data-loading-007, TR-data-loading-011, TR-data-loading-012, TR-data-loading-013]
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0006 (primary) + ADR-0003 (autoload rank + Amendment #3 zero-arg `_init`)
**ADR Decision Summary**: DataRegistry is the rank-1 autoload with a synchronous `_ready()` boot scan that drives the `UNLOADED → LOADING → READY | ERROR | HOT_RELOAD` state machine; `ERROR` is terminal and SaveLoadSystem gates hydration on `state == READY`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff engine APIs used in this story. Autoload init and signal declaration are stable since Godot 4.0; zero-arg `_init` is the mandated pattern per ADR-0003 Amendment #3 (Claim 4 [VERIFIED]).

**Control Manifest Rules (Foundation Layer, DataRegistry)**:
- **Required**: "DataRegistry autoload identifier = `DataRegistry` (rank 1); use bare-identifier resolution `DataRegistry.registry_ready.connect(...)`." — ADR-0006
- **Required**: "State machine: `UNLOADED → LOADING → READY | ERROR | HOT_RELOAD`; `ERROR` is terminal (game cannot proceed); SaveLoadSystem checks `DataRegistry.state == READY` before hydrating." — ADR-0006
- **Required**: "Autoload script `_init` (if declared) MUST have ZERO required parameters (Claim 4 [VERIFIED]); all params must default." — ADR-0003 Amendment #3
- **Forbidden**: "Never reorder existing autoload ranks — would silently break forward-only signal/state-read invariants." — ADR-0003
- **Forbidden**: "Never declare `func _init(...)` with required parameters on an autoload script (`autoload_init_with_required_args`)." — ADR-0003 Amendment #3

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-DLS-NN) or TR-registry (TR-data-loading-NNN):*

- [ ] TR-data-loading-001: DataRegistry autoload enumerates all `.tres` under `assets/data/` at boot; rank 1 (first)
- [ ] TR-data-loading-007: Eager-load all content at boot during LOADING state before consumer access
- [ ] TR-data-loading-011: States: `UNLOADED`, `LOADING`, `READY`, `ERROR`, `HOT_RELOAD`
- [ ] TR-data-loading-012: Emits `registry_ready` signal on successful boot; `registry_error(reason, details)` on fatal load errors
- [ ] TR-data-loading-013: Emits `hot_reload_complete(content_type)` signal after dev re-enumeration

---

## Implementation Notes

*Derived from ADR-0006/0003 Implementation Guidelines:*

- Create `src/core/data_registry.gd` with `class_name DataRegistry extends Node`; register in `project.godot` `[autoload]` at rank 1 (first entry).
- Declare `enum State { UNLOADED, LOADING, READY, ERROR, HOT_RELOAD }`; expose `var state: State = State.UNLOADED` (public read; internal writes only).
- Declare zero-arg `func _init() -> void: pass` (Claim 4 [VERIFIED] — required-arg `_init` on autoload fails instantiation).
- Declare signals: `signal registry_ready`, `signal registry_error(reason: String, details: Dictionary)`, `signal hot_reload_complete(content_type: String)`.
- `_ready()` enters `State.LOADING` and delegates to `_boot_scan()` (stubbed in this story; downstream stories 003/005/006 fill the body). On successful completion set `State.READY` and emit `registry_ready` synchronously. On failure, set `State.ERROR`, emit `registry_error(reason, details)`, and return — do NOT emit `registry_ready` after an error.
- Provide a minimal `hot_reload(content_type: String)` stub that enforces the `OS.is_debug_build()` runtime gate and the `state == READY` precondition (full re-enumeration is Story 007).
- `ERROR` is terminal: no transition out; this story only needs to prevent re-entry from `ERROR`.
- `_init` must not read or subscribe to other autoloads (ADR-0003 state-read invariant at `_ready` only).

---

## Out of Scope

- Story 002: `GameData` abstract base + archetype/role constant set modules.
- Story 003: Per-category enumeration, `ordered_categories` walk, synchronous `ResourceLoader.load` calls.
- Story 004: `resolve()` / `get_all_by_type()` public API.
- Story 005: Per-type validators, duplicate-id detection, `min_content_count` enforcement.
- Story 006: Cross-type DAG + archetype-distribution + boss-uniqueness invariants.
- Story 007: Hot-reload re-enumeration body + immutability guard + SaveLoadSystem hydration-gate integration test.
- Story 008: Boot scan performance budget (<200 ms min-spec mobile).

---

## QA Test Cases

- **TR-data-loading-001 / TR-data-loading-011**: DataRegistry autoload exists at rank 1 and boots into LOADING state
  - **Given**: A fresh Godot session with `project.godot` registering `DataRegistry` as rank-1 autoload.
  - **When**: The engine calls `_ready()` on DataRegistry.
  - **Then**: `DataRegistry.state` transitions `UNLOADED → LOADING` synchronously before any consumer `_ready()` runs; the node is reachable via bare-identifier resolution.
  - **Edge cases**: Required-arg `_init` instantiation failure (regression check — must not compile); a second autoload registration at rank 1 would be an editing error caught by `/architecture-review`.

- **TR-data-loading-007 / TR-data-loading-012**: Successful boot transitions to READY and emits `registry_ready` exactly once
  - **Given**: A stubbed `_boot_scan()` that completes successfully.
  - **When**: `_ready()` runs to completion.
  - **Then**: `state == State.READY`; `registry_ready` has been emitted exactly one time; subscribers connected in `_ready()` receive it.
  - **Edge cases**: `registry_ready` must NOT fire a second time if hot-reload cycles later (hot_reload uses its own signal); subscription by a rank-2+ consumer in its own `_ready()` is safe per ADR-0003 Amendment #1.

- **TR-data-loading-012**: Fatal load error transitions to ERROR and emits `registry_error` instead of `registry_ready`
  - **Given**: A stubbed `_boot_scan()` that signals a fatal error (e.g., via an injected fault).
  - **When**: `_ready()` evaluates the failure.
  - **Then**: `state == State.ERROR`; `registry_error(reason: String, details: Dictionary)` has been emitted with a non-empty `reason`; `registry_ready` has NOT been emitted.
  - **Edge cases**: ERROR is terminal — no further state transitions; subsequent `hot_reload()` calls must no-op.

- **TR-data-loading-013**: `hot_reload_complete(content_type)` signal is declared with the correct shape
  - **Given**: A debug build (`OS.is_debug_build() == true`) with state `READY`.
  - **When**: The signal is inspected via reflection.
  - **Then**: `hot_reload_complete` carries one `String` argument named `content_type`.
  - **Edge cases**: Full emission behavior is verified in Story 007; this story only checks the declaration.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/data_registry/autoload_skeleton_and_state_machine_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None
- **Unlocks**: Story 002, Story 003
