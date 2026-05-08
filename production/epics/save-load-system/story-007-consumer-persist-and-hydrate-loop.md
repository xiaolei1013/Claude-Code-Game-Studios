# Story 007: Consumer persist/hydrate contract + ordered consumer loop

> **Epic**: save-load-system
> **Status**: Complete (system shipped; see systems-index Implementation Status #3. Test evidence: `tests/{unit,integration}/save_load/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md` §F Consumer Contract
**Requirements**: TR-save-load-006, TR-save-load-007 (version-gate pairing), TR-save-load-033, TR-save-load-034, TR-save-load-035, TR-save-load-036, TR-save-load-037, TR-save-load-038, TR-save-load-039, TR-save-load-040, TR-save-load-043, TR-save-load-044, TR-save-load-056, TR-save-load-058
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0003 (primary — CONSUMER_PATHS contract + per-call get_node_or_null), ADR-0004 (top-level dict shape with consumer namespaces + `_meta`), ADR-0014 (RunSnapshot as Orchestrator consumer payload)
**ADR Decision Summary**: SaveLoadSystem iterates `CONSUMER_PATHS` on every persist and load, resolving each via per-call `get_node_or_null(path)` + nil-check. Each consumer exposes `get_save_data() -> Dictionary` and `load_save_data(data: Dictionary) -> void`. The top-level JSON dict has one key per consumer (snake-cased basename) + `_meta`. Consumers initialize persisted state ONLY in `load_save_data`, NEVER in `_ready`. Boot validation inside `load_save_data` must run before any signal emission.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (cross-consumer wiring; ordering assumptions; resource-resolve failures must not crash)
**Engine Notes**: `get_node_or_null(path)` is the canonical per-call resolver (stable); autoload rank ordering guarantees consumer autoloads exist before SaveLoadSystem `_ready()` runs its load pipeline. However, their `_ready()` has NOT yet fired when rank-2 SaveLoadSystem calls `load_save_data` on them — this is the intended contract (per GDD §C.3 table).

**Control Manifest Rules (Foundation Layer, consumer contract)**:
- **Required**: Each consumer exposes `get_save_data()` and `load_save_data(data)`. Consumers initialize persisted state ONLY in `load_save_data`, never in `_ready`. Consumer discovery via hardcoded `CONSUMER_PATHS` resolved per-call via `get_node_or_null` + assert. On `DataRegistry.state != READY`, transition to CORRUPT (AC-SL-08); do not hydrate. Per-consumer null-resolve fallback: roster hero removed, floor relocked, assignment cleared.
- **Forbidden**: Caching consumer references in instance vars. Consumers self-registering or touching `_meta`. Reading/writing `_meta` from any consumer. Consumers initializing state in `_ready()` (overwrites hydrated state).

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] `_collect_consumer_data() -> Dictionary` iterates `CONSUMER_PATHS` in order; for each path: `get_node_or_null(path)`; nil-check → `push_error` + `get_tree().quit(1)` in production; call `consumer.get_save_data()`; namespace under snake-cased basename key in the top-level dict
- [ ] `_hydrate_consumer_data(data: Dictionary)` iterates `CONSUMER_PATHS` in order; per consumer: nil-check; pass sub-dict `data[snake_name]` (NOT full envelope) to `consumer.load_save_data(sub_dict)`
- [ ] Top-level dict contains 7 keys: 6 consumer namespaces (`economy`, `hero_roster`, `floor_unlock`, `formation_assignment`, `recruitment`, `dungeon_run_orchestrator`) + `_meta`
- [ ] Unknown top-level keys present in the dict are silently ignored (forward-compatible)
- [ ] Missing consumer-namespace key in loaded data → pass empty `Dictionary()` to that consumer's `load_save_data` (consumer owns default-seed logic)
- [ ] First-launch bootstrap: when no save file exists, emit `first_launch` signal AFTER consumers exist but BEFORE any consumer `load_save_data` call; consumers use the signal to seed initial state (TR-save-load-058)
- [ ] DataRegistry guard: at `_ready()`, if `DataRegistry.state != READY`, transition to CORRUPT and do NOT hydrate (TR-save-load-043, AC-SL-08)
- [ ] Element-level serialization for `Array[KillEvent]` and `Array[HeroInstance]`: per TR-save-load-035, consumers use per-element `to_dict()/from_dict()` routing (SaveLoadSystem does NOT enforce this at the dict level — consumer's `get_save_data` already returns JSON-safe types)
- [ ] Deserialization loop guard: `if not d is Dictionary: continue` per TR-save-load-036 (AC-SL-04 no-exception contract)
- [ ] `tamper_detected_on_load` signal fires EXACTLY ONCE before any `consumer.load_save_data` call on HMAC failure (TR-save-load-056) — implementation routes the HMAC-fail branch to emit + skip hydration
- [ ] Per-consumer fallback on `DataRegistry.resolve()` null: delegated to each consumer's `load_save_data` (TR-save-load-044 — e.g., Roster drops unresolvable hero, Floor relocks, Formation clears)

---

## Implementation Notes

- Snake-casing convention: `/root/Economy` → `"economy"`, `/root/HeroRoster` → `"hero_roster"`, `/root/FloorUnlock` → `"floor_unlock"`, `/root/FormationAssignment` → `"formation_assignment"`, `/root/Recruitment` → `"recruitment"`, `/root/DungeonRunOrchestrator` → `"dungeon_run_orchestrator"`. Implement a deterministic helper `_path_to_namespace(path: String) -> String` so test + runtime agree
- Ordered iteration: iterate `CONSUMER_PATHS` as a `PackedStringArray` using index (NOT Dictionary iteration order); persist order == load order == rank order
- Consumer resolution is per-call: every persist AND every load boundary calls `get_node_or_null(path)` — references are NOT cached on any instance var (TR-save-load-034). The same pattern appears for both `_collect_consumer_data` and `_hydrate_consumer_data`
- Nil-check guard uses the runtime pattern `if not OS.is_debug_build() and node == null: push_error(...); get_tree().quit(1)` (NOT `assert(...)` per TR-save-load-051 — assert is stripped from release)
- Why pass the sub-dict (not the full envelope) to `load_save_data`: per Pass-5C 2026-04-21 "namespace unwrapping fix" — SaveLoadSystem owns namespacing on write AND read. Passing the full envelope to a consumer would force each consumer to re-implement the unwrap, leaking the schema across boundaries.
- Consumers MUST NOT read/write `_meta` — enforced by grep + code review (Story 014). This story's implementation never exposes `_meta` in the sub-dicts passed to consumers
- `first_launch` signal: emitted BEFORE consumer `load_save_data` calls on the no-save path. Consumers listening to `first_launch` can seed initial state (e.g., HeroRoster seeds Theron at instance_id=1). When saves exist, consumers hydrate from dicts; when no save exists, `first_launch` drives seeding and `load_save_data` is called with empty dicts (so `load_save_data` bodies MUST tolerate empty-dict input)
- Consumer order rationale: Economy first (lifetime_gold_earned for display on any modal), HeroRoster next (floor_unlock needs class ids resolvable), FloorUnlock next (formation assignment needs floor context), etc. The authoritative ordering is ADR-0003 rank table

---

## Out of Scope

- Story 008: atomic write mechanics (the persist path's disk write)
- Story 009: `_meta` namespace management (slot_index, save_sequence_number, tamper_suspicious_count, backup_restore_events)
- Story 010: schema migration (version < CURRENT_SAVE_VERSION handling)
- Story 011: heartbeat partial-envelope path (bypasses the full consumer loop)
- Story 013: tamper-detection UX (this story fires `tamper_detected_on_load`; the UX/modal is downstream)

---

## QA Test Cases

- **TR-save-load-006 / TR-save-load-034**: Ordered consumer iteration
  - **Given**: Six stub-consumer autoloads that record invocation order
  - **When**: `_collect_consumer_data()` runs
  - **Then**: `get_save_data` is called on each in exactly `CONSUMER_PATHS` order (Economy, HeroRoster, FloorUnlock, FormationAssignment, Recruitment, DungeonRunOrchestrator); zero calls to any non-listed node; every call is preceded by a fresh `get_node_or_null` invocation (test spies on the resolver)
  - **Edge cases**: Same ordering must hold on `_hydrate_consumer_data`; no reference caching between persist-then-load

- **TR-save-load-034 (nil-check)**: Missing consumer triggers fatal guard
  - **Given**: The `Economy` autoload is stripped from `/root` in a debug test
  - **When**: `_collect_consumer_data()` hits the `/root/Economy` iteration
  - **Then**: In debug mode, a test-captured `push_error` is emitted; in production, `get_tree().quit(1)` would fire
  - **Edge cases**: Never silently skip — the missing-consumer bug is catastrophic (its namespace vanishes from the save)

- **TR-save-load-006 (sub-dict unwrap)**: Load passes sub-dict, not full envelope
  - **Given**: A loaded top-level dict `{economy: {gold: 100}, hero_roster: {...}, _meta: {...}}`
  - **When**: `_hydrate_consumer_data(data)` runs
  - **Then**: `economy.load_save_data(arg)` is called with `arg == {gold: 100}` (NOT the full top-level dict)
  - **Edge cases**: `_meta` is never passed to any consumer

- **TR-save-load-036**: Non-dict array-element guard
  - **Given**: A loaded consumer sub-dict containing an array field where one element is not a Dictionary (e.g., `[ {valid: true}, "malformed_string", {valid: true} ]`)
  - **When**: Consumer `load_save_data` iterates with `for d in serialized: if not d is Dictionary: continue`
  - **Then**: Loop continues to next element; no GDScript exception propagates (AC-SL-04 contract)
  - **Edge cases**: Null elements, wrong-typed elements all skip silently with optional `push_warning`

- **TR-save-load-043 / AC-SL-08**: DataRegistry ERROR refuses hydration
  - **Given**: `DataRegistry.state == ERROR` (simulated via a test hook)
  - **When**: SaveLoadSystem `_ready()` runs its load pipeline
  - **Then**: Transitions to CORRUPT state; `tamper_detected_on_load` is NOT emitted (this is a content-layer failure, not tamper); save file is NOT modified (per Rule 8 — "your save is safe"); AC-SL-08 modal copy is queued for Story 013 UX
  - **Edge cases**: `state == LOADING` or `UNLOADED` at `_ready()` time is unexpected (rank 1 < rank 2); if observed, same CORRUPT transition with a distinct error code

- **TR-save-load-058**: `first_launch` signal on no-save bootstrap
  - **Given**: No file exists at `user://save_slot_1.dat` and no `.bak`
  - **When**: SaveLoadSystem `_ready()` completes its load path
  - **Then**: `first_launch` signal emits exactly once BEFORE any `consumer.load_save_data` call; consumers receive empty `Dictionary()` inputs in `load_save_data`
  - **Edge cases**: Consumer seeding happens in response to `first_launch` (HeroRoster's `seed_first_launch_state()` per ADR-0012); no consumer should duplicate-seed in `load_save_data({})`

- **TR-save-load-056**: `tamper_detected_on_load` emission gate
  - **Given**: Validation returns `{ok: false, failure: "hmac"}` per Story 006
  - **When**: HMAC-fail branch runs
  - **Then**: `tamper_detected_on_load` emits EXACTLY ONCE; NO consumer `load_save_data` is called in this session; state transitions await Story 013's `.bak` retry path
  - **Edge cases**: Both `.dat` and `.bak` fail — signal still emits once; no double-fire

- **TR-save-load-044 (roster fallback)**: Missing class_id drops hero without crash (AC-SL-04)
  - **Given**: A valid save containing a hero with `class_id = "deleted_class"` that no longer exists in DataRegistry
  - **When**: HeroRoster's `load_save_data` runs and `DataRegistry.resolve("classes", "deleted_class")` returns null
  - **Then**: The orphan hero is dropped; formation slot referencing that instance_id is cleared; no exception; no save-data corruption; consumer fallback behavior is verified (per ADR-0012 boot validation 4-step order)
  - **Edge cases**: This exercises the consumer's fallback logic, not SaveLoadSystem's — but the contract "no exception propagates through `load_save_data`" is SaveLoadSystem's gate; test asserts the whole pipeline completes

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/save_load/consumer_loop_test.gd` — must exist and pass (stub consumers sufficient; real consumers covered by AC-SL-01 after all stories land)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload skeleton + CONSUMER_PATHS), Story 006 (validation pipeline — only called on success)
- **Unlocks**: Story 008 (atomic write of the composed envelope), Story 011 (heartbeat is the alternative path that skips this loop), Story 015 (performance verification — full round-trip needs this loop working)
