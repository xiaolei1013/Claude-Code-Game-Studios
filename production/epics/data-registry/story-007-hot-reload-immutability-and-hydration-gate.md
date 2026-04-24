# Story 007: Hot-reload, immutability enforcement, and SaveLoadSystem hydration gate

> **Epic**: data-registry
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/data-loading.md`
**Requirements**: [TR-data-loading-009, TR-data-loading-010, TR-data-loading-013, TR-data-loading-027, TR-data-loading-028]
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0006 (primary) + ADR-0003 (registry_ready signal-edge contract for SaveLoadSystem)
**ADR Decision Summary**: `hot_reload(content_type)` is runtime-gated by `OS.is_debug_build()` and re-enumerates only the target category; production builds no-op. Resources returned by accessors are immutable by convention, with post-test snapshot comparison enforcing in debug/test builds. SaveLoadSystem gates hydration on `DataRegistry.state == READY` before consuming the `resolve()` API.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `OS.is_debug_build()` runtime gate is the ADR-0006 stripping strategy (not a compile-time `const`). `duplicate_deep()` (4.5+) is NOT used inside accessors by design; consumers call it explicitly — and critically, `duplicate_deep()` does NOT cross `ExtResource()` boundaries (cross-file refs remain shared). Hot-reload during an active run leaves consumers holding stale refs until `hot_reload_complete` is observed and re-fetched — documented as "best effort dev convenience, not a player-facing feature."

**Control Manifest Rules (Foundation Layer, DataRegistry)**:
- **Required**: "`hot_reload(content_type)` runtime-gated by `OS.is_debug_build()`; production no-op; never invoked from production code paths." — ADR-0006
- **Required**: "Resources returned by `get_all_by_type()` / `resolve()` are immutable by convention; consumers MUST NOT mutate `@export` fields (Godot resource cache returns the same object — mutation corrupts every cached holder)." — ADR-0006
- **Required**: "For mutable copies, consumers MUST explicitly `template.duplicate()` (shallow) or `template.duplicate_deep()` (4.5+); `duplicate_deep()` does NOT cross `ExtResource()` boundaries." — ADR-0006
- **Required**: "State machine: `UNLOADED → LOADING → READY | ERROR | HOT_RELOAD`; `ERROR` is terminal; SaveLoadSystem checks `DataRegistry.state == READY` before hydrating." — ADR-0006
- **Forbidden**: "Never mutate a Resource returned by DataRegistry accessors (`mutating_loaded_resource`)." — ADR-0006
- **Forbidden**: "Never call `hot_reload(...)` from production code paths or UI affordances — content-injection vector." — ADR-0006

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-DLS-NN) or TR-registry (TR-data-loading-NNN):*

- [ ] TR-data-loading-009: Read-only contract: resolved resources immutable at runtime; no consumer mutates `@export` fields
- [ ] TR-data-loading-010: Hot-reload (dev only) via `hot_reload(content_type)` gated by `is_dev_build` compile flag; stripped from shipped builds
- [ ] TR-data-loading-013: Emits `hot_reload_complete(content_type)` signal after dev re-enumeration
- [ ] TR-data-loading-027: Patch-time live content updates NOT supported at runtime; next launch rebuilds full index
- [ ] TR-data-loading-028: Read-only enforcement check in debug/test builds via post-test property snapshot comparison
- [ ] AC-DLS-01: **GIVEN** the app launches with `assets/data/` containing the full MVP content set and no file is malformed, **WHEN** the Data Loading System completes enumeration and registration, **THEN** the system emits `registry_ready` and transitions internal state from `LOADING` to `READY`; `DataRegistry.state == READY` is observable by all dependents before the first gameplay frame; typed accessors for all six content categories return non-null collections with expected cardinality.
- [ ] AC-DLS-08: **GIVEN** a resolved resource instance is obtained via `DataRegistry.resolve("classes", "hero_warrior")`, **WHEN** any consumer attempts to mutate a property, **THEN** in debug/test builds, the mutation either raises an assertion or is caught by a post-test integrity check comparing property values against the load-time snapshot; the registered resource's stored state is unchanged after the test; release builds do not enforce at runtime, but the unit test suite includes at least one test catching this pattern.
- [ ] AC-DLS-09: **GIVEN** the game runs in the Godot editor or a debug export build and `DataRegistry.hot_reload_enabled == true`, **WHEN** `DataRegistry.hot_reload("classes")` is called, **THEN** only the `classes` category is re-enumerated and re-registered; other category registries are unmodified; `resolve()` calls after the reload return updated values from modified `.tres` files; the reload completes without restarting the scene tree; log confirms `[DataRegistry] HOT RELOAD: classes — {N} resources re-registered in {Ms}ms`.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

- Implement `hot_reload(content_type: String)` per ADR-0006 §Hot-reload:
  ```
  func hot_reload(content_type: String) -> void:
      if not OS.is_debug_build():
          return
      if _state != State.READY:
          push_warning("[DataRegistry] hot_reload requested while state=%s; ignoring" % _state)
          return
      _state = State.HOT_RELOAD
      _categories.erase(content_type)
      _load_category(content_type)
      # Re-run any per-type validators + cross-type invariants for the category
      _state = State.READY
      hot_reload_complete.emit(content_type)
  ```
- Log format on success: `[DataRegistry] HOT RELOAD: classes — {N} resources re-registered in {Ms}ms` (measured via `Time.get_ticks_msec()` bracketing).
- `hot_reload_enabled` knob defaults to `OS.is_debug_build()` per ADR-0006 §Tuning Knobs; production builds return early.
- Read-only enforcement (AC-DLS-08): implement a debug-only `_snapshot_for_integrity_check()` helper that captures `@export` field values per registered resource at load time. A post-test helper compares live resource state against the snapshot and flags mismatch. At least one unit test must deliberately mutate a resolved resource and confirm the check surfaces the mismatch. Release builds do NOT enforce — defensive `.duplicate()` per-read would burn budget and defeat the cache.
- SaveLoadSystem hydration integration (AC-DLS-01): add a test that instantiates DataRegistry headlessly, waits for `registry_ready`, then asserts `DataRegistry.state == State.READY` and every accessor for the six categories returns a non-null typed array with size ≥ per-category minimum. SaveLoadSystem's own hydration subscription (`await DataRegistry.registry_ready` or `DataRegistry.registry_ready.connect(...)` in its `_ready`) is covered in the save-load epic — this story only proves DataRegistry's side of the contract.
- TR-027 (no patch-time live updates): document in the class header that the in-memory index is populated once per boot; re-populating only via a full restart or dev `hot_reload`. No code — this is an invariant statement.
- Empty-catalog ERROR: the `min_content_count` check from Story 005 already covers it; a fresh hot_reload into an empty directory must route through the same ERROR transition (cross-check in a test here).

---

## Out of Scope

- Story 008: Performance budget AC-DLS-07 (<200 ms on min-spec mobile).
- SaveLoadSystem's own hydration logic (owned by the save-load epic; this story only exercises the DataRegistry-side contract).
- Runtime UI affordance for hot-reload (dev menu) — out of scope for the content backbone; a debug scene may expose it but is not required by this story.

---

## QA Test Cases

- **AC-DLS-01**: Full boot sequence hits READY with populated accessors before first gameplay frame
  - **Given**: The full MVP fixture dataset under `tests/fixtures/data_registry/mvp_full/` meeting per-category minimums for `classes`, `enemies`, `biomes`, `dungeons`, `items`, `matchup`.
  - **When**: DataRegistry runs a complete boot scan headlessly.
  - **Then**: `registry_ready` emits exactly once; `state == State.READY`; `get_all_by_type(cat).size() >= MIN_CONTENT_COUNT[cat]` for each category; the transition happens synchronously inside `_ready()` (no deferred emission).
  - **Edge cases**: Any consumer subscribing in its own `_ready()` (rank 2+) receives the signal per ADR-0003 Amendment #1.

- **TR-data-loading-009 / TR-data-loading-028 / AC-DLS-08**: Read-only contract enforcement in debug/test builds
  - **Given**: A loaded `HeroClass` fixture resource obtained via `resolve("classes", "hero_warrior")`.
  - **When**: A test deliberately mutates `resource.base_attack = 999` then invokes the integrity-check helper.
  - **Then**: The snapshot comparison reports the mismatch with the field name, the original value, and the observed value; the test is flagged as failing (AC-DLS-08 BLOCKING in test builds).
  - **Edge cases**: Release builds do NOT enforce at runtime (confirmed by guard); a second `resolve` on the same id still returns the same cached (now-mutated) instance, illustrating why the contract matters; the test restores the original value for hygiene.

- **TR-data-loading-010 / TR-data-loading-013 / AC-DLS-09**: Hot-reload re-enumerates only the target category
  - **Given**: Debug build with `hot_reload_enabled == true`; registry in `READY` state; a test harness modifies `classes/hero_warrior.tres` on disk (changes `display_name`).
  - **When**: `DataRegistry.hot_reload("classes")` is called.
  - **Then**: `state` transitions `READY → HOT_RELOAD → READY`; `hot_reload_complete` emits exactly once with `content_type == "classes"`; `resolve("classes", "hero_warrior").display_name` returns the new value; `resolve("enemies", …)` / `resolve("biomes", …)` results are object-identical to pre-reload (other categories untouched); log matches `[DataRegistry] HOT RELOAD: classes — {N} resources re-registered in {Ms}ms`.
  - **Edge cases**: Production build (`OS.is_debug_build() == false`) — the call is a no-op; `hot_reload` called during `LOADING` or `ERROR` state is ignored with `push_warning`; hot_reload that produces a duplicate id transitions to ERROR (propagates from Story 005's validator).

- **TR-data-loading-027**: No patch-time live updates
  - **Given**: An already-initialized registry and a new `.tres` file dropped into `assets/data/classes/` at runtime (without calling `hot_reload`).
  - **When**: `get_all_by_type("classes")` is queried.
  - **Then**: The new file is NOT in the returned array; only the explicit `hot_reload` API or a fresh boot picks it up.
  - **Edge cases**: Production builds cannot pick up new files even via `hot_reload` (no-op); this is the expected invariant.

- **AC-DLS-01 (integration)**: SaveLoadSystem hydration gate
  - **Given**: A test double for SaveLoadSystem that subscribes to `DataRegistry.registry_ready` in its own `_ready()`.
  - **When**: DataRegistry boots headlessly with the MVP fixture.
  - **Then**: The SaveLoadSystem double receives the signal; at the moment it runs its hydration body, `DataRegistry.state == State.READY` and `resolve("classes", known_id)` returns the loaded resource; if DataRegistry instead transitions to ERROR, the double observes `registry_error` and refuses hydration (ADR-0006 contract).
  - **Edge cases**: ERROR-state hydration must NEVER be attempted; the signal-subscription-across-ranks pattern is safe at `_ready()` per ADR-0003 Amendment #1.

- **Empty-catalog ERROR on hot_reload**
  - **Given**: Debug build, registry `READY`, then all `classes/*.tres` files are moved out of the directory.
  - **When**: `hot_reload("classes")` is called.
  - **Then**: `state` transitions `READY → HOT_RELOAD → ERROR` (due to `min_content_count` failure); `registry_error(reason = "MinContentCount", details = …)` emitted; `hot_reload_complete` is NOT emitted.
  - **Edge cases**: The hot_reload transition observing ERROR is terminal for the rest of the session.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/data_registry/hot_reload_immutability_and_hydration_gate_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 006
- **Unlocks**: Story 008
