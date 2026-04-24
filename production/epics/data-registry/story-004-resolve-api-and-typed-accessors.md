# Story 004: `resolve()` API and typed category accessors

> **Epic**: data-registry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/data-loading.md`
**Requirements**: [TR-data-loading-014, TR-data-loading-015, TR-data-loading-019, TR-data-loading-024, TR-data-loading-006]
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0006 (primary)
**ADR Decision Summary**: `resolve(content_type, id) -> Resource | null` returns the live cached instance; missing IDs log WARN (production default) or ASSERT in test builds; `get_all_by_type(category) -> Array[Resource]` returns the loaded array post-`registry_ready`, or an empty array + warning if called earlier.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript 4.6 does not support union return types; `resolve()` is typed `-> Resource` and returns `null` on miss (documented). `assert()` in debug builds is the ASSERT branch; `push_warning()` is the WARN branch. No post-cutoff engine APIs used in this story.

**Control Manifest Rules (Foundation Layer, DataRegistry)**:
- **Required**: "`resolve(content_type, id) -> Resource | null` returns null on miss with WARN log in production, ASSERT in test builds when `missing_id_behavior == ASSERT`." — ADR-0006
- **Required**: "Resources returned by `get_all_by_type()` / `resolve()` are immutable by convention; consumers MUST NOT mutate `@export` fields (Godot resource cache returns the same object — mutation corrupts every cached holder)." — ADR-0006
- **Forbidden**: "Never call `.duplicate()` / `.duplicate_deep()` inside DataRegistry accessors — accessor returns cached instance directly." — ADR-0006
- **Forbidden**: "Never mutate a Resource returned by DataRegistry accessors (`mutating_loaded_resource`) — corrupts every cached holder." — ADR-0006

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-DLS-NN) or TR-registry (TR-data-loading-NNN):*

- [ ] TR-data-loading-014: Resolver API: `resolve(content_type: String, id: String) -> Resource or null` — silent substitution forbidden
- [ ] TR-data-loading-015: Typed accessors per category: `get_all_classes`, `get_class_by_id`, `get_all_enemies`, `get_enemy_by_id`, etc.
- [ ] TR-data-loading-019: Missing ref: `resolve` returns null, logs warning; caller (Save/Load) applies fallback policy
- [ ] TR-data-loading-024: `missing_id_behavior` enum: `WARN` (prod default) or `ASSERT` (tests)
- [ ] TR-data-loading-006: `id` is canonical cross-system key; filename is developer hint only, renaming must not break saves
- [ ] AC-DLS-02: **GIVEN** a resource `warrior.tres` with `id = "hero_warrior"` has been loaded into the registry, and a downstream save-file reference uses the string `"hero_warrior"`, **WHEN** the `.tres` file is renamed on disk to `hero_warrior_v2.tres` (same `id` field, different filename) and the app relaunches, **THEN** `DataRegistry.resolve("classes", "hero_warrior")` returns the same resource object as before the rename; no error is logged; no consumer call sites require changes.
- [ ] AC-DLS-04: **GIVEN** a save file contains a serialized reference to `"classes", id = "hero_berserker"`, and no `.tres` resource with that id exists, **WHEN** `DataRegistry.resolve("classes", "hero_berserker")` is called by Save/Load during session restore, **THEN** `resolve()` returns `null` (not a crash, not a default stub); an error is logged: `[DataRegistry] MISSING REF: classes id='hero_berserker' — no resource registered`; Save/Load receives `null` and applies its own fallback policy; session restore continues for all other valid references.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

- Implement `func resolve(content_type: String, id: String) -> Resource` per ADR-0006: look up the category dictionary (two Dictionary lookups, sub-microsecond); return `null` on miss, branching on `missing_id_behavior`.
- Declare `enum MissingIdBehavior { WARN, ASSERT }` with `@export var missing_id_behavior: int = MissingIdBehavior.WARN` (ProjectSettings or constant-driven; `ASSERT` is test-build default).
- WARN branch: `push_warning("[DataRegistry] MISSING REF: %s id='%s' — no resource registered" % [content_type, id])`. ASSERT branch: `assert(false, "[DataRegistry] resolve: id '%s' not found in '%s'" % [id, content_type])`.
- Implement `func get_all_by_type(content_type: String) -> Array[Resource]`: if `state != State.READY`, return empty array and `push_warning` per ADR-0006 "Before registry_ready" semantics. Otherwise return an Array built from the category dictionary's values. Typed `Array[Resource]`.
- Do NOT call `.duplicate()` / `.duplicate_deep()` inside accessors — they return cached instances directly; consumers are responsible for duplication when they need mutable copies (documented in ADR-0006 §Read-only contract).
- Typed accessor aliases (convenience, optional if consumer DBs wrap these directly): `get_all_classes() -> Array[HeroClass]`, `get_class_by_id(id) -> HeroClass`, `get_all_enemies() -> Array[EnemyData]`, `get_enemy_by_id(id) -> EnemyData`, etc. TR-015 lists the pattern; implementation may defer these to the per-DB consumer stories (HeroClassDatabase etc.) if preferred — document the decision in this story's PR.
- Filename-stability (TR-006 / AC-DLS-02): no additional code — comes for free because the `_categories` dictionary is keyed by `resource.id`, not by filename. Ensure the test in this story renames the on-disk `.tres` and verifies `resolve()` still returns the same object.
- Before the first gameplay frame, `registry_ready` is assumed to have fired (gates SaveLoadSystem per ADR-0006 cross-GDD contract). Accessors called pre-`registry_ready` warn and return empty.

---

## Out of Scope

- Story 005: Duplicate-id ERROR + malformed-file handling + `min_content_count` transitions.
- Story 006: Cross-reference DAG validation.
- Story 007: Read-only contract enforcement (AC-DLS-08) + hot-reload.
- Full end-to-end SaveLoadSystem hydration integration test (Story 007 covers the DataRegistry side; SaveLoadSystem side lives in the save-load epic).
- Typed accessor aliases may optionally be provided here or deferred to per-DB consumer stories per the team preference noted above.

---

## QA Test Cases

- **TR-data-loading-014 / TR-data-loading-019 / AC-DLS-04**: `resolve()` returns null on missing id with WARN log
  - **Given**: A loaded registry with `classes["hero_warrior"]` but no `hero_berserker`; `missing_id_behavior == WARN`.
  - **When**: `DataRegistry.resolve("classes", "hero_berserker")` is called.
  - **Then**: Returns `null`; a `push_warning` log with the exact format `[DataRegistry] MISSING REF: classes id='hero_berserker' — no resource registered` is emitted; no exception is raised; a subsequent `resolve("classes", "hero_warrior")` still returns the correct resource.
  - **Edge cases**: Unknown `content_type` (e.g., `"nonsense"`) likewise returns `null` with WARN; calling `resolve` before `registry_ready` returns `null` with a distinct warning.

- **TR-data-loading-024**: `missing_id_behavior == ASSERT` crashes with stack trace in test builds
  - **Given**: A loaded registry with `missing_id_behavior == MissingIdBehavior.ASSERT`.
  - **When**: `resolve("classes", "hero_berserker")` is called.
  - **Then**: An assertion fires with a message containing the id and content type; the test harness captures it as a failure (test-build behavior).
  - **Edge cases**: Production builds with ASSERT configured (unusual) should still assert; WARN must never assert.

- **TR-data-loading-015**: `get_all_by_type` returns the full loaded array
  - **Given**: Loaded registry with three classes and eight enemies.
  - **When**: `get_all_by_type("classes")` and `get_all_by_type("enemies")` are called post-`registry_ready`.
  - **Then**: Results are typed `Array[Resource]` of size 3 and 8 respectively; each element is the same cached instance returned by `resolve()` for its id.
  - **Edge cases**: Called before `registry_ready` (state != READY) returns empty array + warning; called with unknown category returns empty array.

- **TR-data-loading-006 / AC-DLS-02**: Rename-transparent resolution
  - **Given**: A test fixture with `warrior.tres` (id = `"hero_warrior"`) loaded into the registry.
  - **When**: The file is renamed on disk to `hero_warrior_v2.tres` (same id field) and the registry re-enumerates (simulated via a fresh boot in the test).
  - **Then**: `resolve("classes", "hero_warrior")` still returns a resource; `resource.id == "hero_warrior"`; no error logged for the rename.
  - **Edge cases**: Changing the `id` field itself (not just the filename) would fail resolution — this is intentional per ADR-0006 §Stable id convention.

- **AC-DLS-08 (partial — read-only CONVENTION only; enforcement in Story 007)**: Accessor returns cached instance (no duplication)
  - **Given**: A loaded HeroClass with `id == "hero_warrior"`.
  - **When**: `resolve("classes", "hero_warrior")` is called twice.
  - **Then**: Both calls return the same object reference (identity equality, not value equality); no `.duplicate()` happens inside the accessor.
  - **Edge cases**: `get_all_by_type("classes")[0]` and `resolve("classes", "hero_warrior")` must be identity-equal for the same id.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/data_registry/resolve_api_and_typed_accessors_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 003
- **Unlocks**: Story 005, Story 006, Story 007


## Completion Notes

**Completed**: 2026-04-24
**Criteria**: 7/7 passing
**Story Type**: Logic
**Test Evidence**: tests/unit/data_registry/resolve_api_and_typed_accessors_test.gd (10/10 pass)
**Deviations**: Typed per-category accessors (get_all_classes/get_class_by_id/etc.) deferred to future per-DB consumer stories per ADR-0006 and story Out-of-Scope. Only category-agnostic resolve()/get_all_by_type() shipped.
**Code Review**: Skipped — review mode solo (per production/review-mode.txt)
**Next**: Sprint-close sequence (/smoke-check sprint → /team-qa sprint → /gate-check)
