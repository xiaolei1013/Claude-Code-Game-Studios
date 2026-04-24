# Story 005: Per-type validators, duplicate id detection, and min_content_count

> **Epic**: data-registry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/data-loading.md`
**Requirements**: [TR-data-loading-005, TR-data-loading-016, TR-data-loading-017, TR-data-loading-023]
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0006 (primary) + ADR-0011 (per-type validator specifications)
**ADR Decision Summary**: Per-type validators run in `ordered_categories` sequence with enumerated failure actions (ERROR vs `push_warning`); duplicate id within a content type and category-count below `min_content_count` both transition to ERROR; malformed `.tres` files are skipped with a structured warning and the load continues.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ResourceLoader.load` returns `null` on parse failure (stable 4.0+). Regex via `RegEx.new().compile(...)` for snake_case id check is stable 4.0+. No post-cutoff engine APIs used in this story.

**Control Manifest Rules (Core Layer, Resource schemas — applied during Foundation Layer boot scan)**:
- **Required**: "`id` non-empty, `id` snake_case (regex `^[a-z][a-z0-9_]*$`), `id` globally unique within content_type → ERROR state on failure." — ADR-0011 §Load-Time Validation Semantics (Universal)
- **Required**: "Every content field on a GameData subclass MUST be `@export`-decorated (otherwise not surfaced / serialized)." — ADR-0011
- **Required**: "`HeroClass.counter_archetype` and `EnemyData.archetype` MUST validate against `EnemyArchetypes.is_valid()` (single source of truth); `HeroClass.role` MUST validate against `ClassRoles.is_valid()`; `Biome.status` MUST be in `{\"active\", \"planned_v1\"}`." — ADR-0011
- **Required**: "Validation failure actions: fatal (duplicate id, DAG cycle, below-minimum count, unresolvable required cross-ref) → `ERROR` state; non-fatal (soft-limit overrun, asset-path empty) → `push_warning` + load-with-value-retained." — ADR-0011
- **Forbidden**: "Never use derive-from-filename ID assignment (`filename_as_id`) — `id` is the stable cross-system key." — ADR-0011

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-DLS-NN) or TR-registry (TR-data-loading-NNN):*

- [ ] TR-data-loading-005: Every resource declares `id: String` as first `@export` field; snake_case; globally unique within type
- [ ] TR-data-loading-016: Duplicate id within content type → ERROR state; first resource retained, second rejected, log structured error
- [ ] TR-data-loading-017: Malformed `.tres` file skipped with structured warning; state remains READY unless below `MIN_CONTENT_COUNT`
- [ ] TR-data-loading-023: `min_content_count` per-category default `{classes:3, enemies:5, biomes:1, dungeons:1, matchup:1}`; below → ERROR
- [ ] AC-DLS-03: **GIVEN** two `.tres` files in `assets/data/classes/` both declare `id = "hero_warrior"`, **WHEN** the Data Loading System enumerates that category, **THEN** the system logs `[DataRegistry] DUPLICATE ID: 'hero_warrior' in classes — {path_a} vs {path_b}. Second file skipped.`; state transitions to `ERROR`; `registry_error(DuplicateId, "hero_warrior")` is emitted; the first registered resource is retained; dependent systems remain uninitialized.
- [ ] AC-DLS-05: **GIVEN** one `.tres` file in `assets/data/enemies/` is syntactically corrupt, **WHEN** the Data Loading System encounters that file, **THEN** the file is skipped with a structured warning `[DataRegistry] MALFORMED FILE: {path} — skipped. Reason: {parse_error}`; all other valid files continue loading; if count falls below `MIN_CONTENT_COUNT["enemies"]`, state transitions to ERROR; otherwise READY; no unhandled exception propagates.

---

## Implementation Notes

*Derived from ADR-0006/0011 Implementation Guidelines:*

- Declare `@export var min_content_count: Dictionary = {"classes": 3, "enemies": 5, "biomes": 1, "dungeons": 1, "matchup": 1}` on DataRegistry (defaults per ADR-0006 §Key interfaces).
- Extend `_load_category(category)` from Story 003 so each `ResourceLoader.load(path)` is wrapped: `null` return → `push_warning("[DataRegistry] MALFORMED FILE: %s — skipped. Reason: %s" % [path, parse_error])` and continue.
- Before inserting into `_categories[category]`: (1) verify `id` non-empty, (2) match against compiled regex `^[a-z][a-z0-9_]*$`, (3) check for duplicate id in the category dict. Any failure → transition to ERROR, emit `registry_error(reason, details)`, and short-circuit (fail-fast per ADR-0011 validation-ordering contract).
- Duplicate-id log format MUST match AC-DLS-03 exactly: `[DataRegistry] DUPLICATE ID: 'hero_warrior' in classes — {path_a} vs {path_b}. Second file skipped.`; `registry_error` payload uses `reason = "DuplicateId"`, `details = {"id": id, "content_type": category, "paths": [path_a, path_b]}`.
- Per-type field validators (enumerated in ADR-0011 §Load-Time Validation Semantics) for HeroClass/EnemyData/Biome/Dungeon/Floor MUST run in per-category order. In this story, wire a pluggable validator callback per category; the concrete subclass schema bodies (HeroClass/EnemyData/etc.) live under the Core DB epics — provide the hook + contract here so ADR-0011 validators slot in without re-opening this story.
- After a category finishes loading, run `_validate_min_content_count(category)`: if `_categories[category].size() < min_content_count.get(category, 0)` → transition to ERROR with `reason = "MinContentCount"`, `details = {"content_type": category, "loaded": n, "required": min}`.
- `missing_id_behavior == ASSERT` does NOT apply here — it governs `resolve()` miss policy (Story 004), not load-time validation.
- Guard against `filename_as_id` regression: authoring-time CI grep per ADR-0011 (`filename_as_id` forbidden pattern). No runtime code for this; document in PR.

---

## Out of Scope

- Story 002: GameData base class + archetype/role constant set files (prerequisite).
- Story 006: Cross-type DAG validation (archetype-distribution, boss-uniqueness, `is_boss_floor` coupling) and cycle detection.
- Story 007: Hot-reload + read-only contract enforcement (AC-DLS-08).
- Concrete HeroClass/EnemyData/Biome/Dungeon/Floor schema bodies (owned by Core DB epics under ADR-0011).

---

## QA Test Cases

- **TR-data-loading-016 / AC-DLS-03**: Duplicate id within a content type surfaces as ERROR state
  - **Given**: Fixture with two valid `.tres` files in `classes/` both declaring `id = "hero_warrior"`.
  - **When**: DataRegistry enumerates the `classes/` category.
  - **Then**: `state == State.ERROR`; `registry_error` emitted with `reason == "DuplicateId"` and details containing the id and the two paths; the log line matches the AC-DLS-03 format exactly; the first-registered file is retained, the second is dropped.
  - **Edge cases**: Three+ collisions — the second triggers ERROR; the third is unprocessed (fail-fast); accessors return empty arrays until resolved.

- **TR-data-loading-017 / AC-DLS-05**: Malformed file is skipped without propagating an exception
  - **Given**: Fixture with one zero-byte `enemies/corrupt.tres` alongside valid enemy files totalling ≥ `MIN_CONTENT_COUNT["enemies"]` remaining after skip.
  - **When**: Boot scan runs.
  - **Then**: `push_warning` log matches `[DataRegistry] MALFORMED FILE: .../corrupt.tres — skipped. Reason: ...`; other valid enemies load normally; `state == State.READY`; no unhandled exception.
  - **Edge cases**: If the skipped file drops the category below `min_content_count`, state must transition to ERROR instead (bridge to TR-023).

- **TR-data-loading-023**: Category below `min_content_count` transitions to ERROR
  - **Given**: Fixture with only 2 class `.tres` files (`min_content_count["classes"] == 3`).
  - **When**: Boot scan finishes the `classes/` category.
  - **Then**: `state == State.ERROR`; `registry_error` emitted with `reason == "MinContentCount"`, `details == {"content_type": "classes", "loaded": 2, "required": 3}`; subsequent categories are NOT enumerated (fail-fast).
  - **Edge cases**: Exactly at the minimum passes (`loaded == required`); unknown categories default to 0 required; `items/` min is not enumerated in the MVP defaults (absent from dict).

- **TR-data-loading-005**: Snake_case id regex + non-empty id
  - **Given**: Fixture with a class `.tres` declaring `id = "HeroWarrior"` (PascalCase — violation).
  - **When**: Boot scan runs.
  - **Then**: `state == State.ERROR`; `registry_error` emitted with `reason == "InvalidId"` and details including the offending id and path.
  - **Edge cases**: `id == ""` also errors; `id` starting with a digit (`"1_warrior"`) errors; `id` with hyphens (`"hero-warrior"`) errors.

- **ADR-0011 per-type field validator hook**: HeroClass `role` / `counter_archetype` validation
  - **Given**: A fixture HeroClass with `role = "healer"` (not in `ClassRoles.ALL_SET`).
  - **When**: The per-type validator runs for `classes/`.
  - **Then**: `state == State.ERROR`; `registry_error` emitted with `reason == "InvalidRole"` (or a per-ADR-0011 equivalent), detailing the invalid value.
  - **Edge cases**: `counter_archetype = "flying"` (not in `EnemyArchetypes.ALL_SET`) likewise errors; case-sensitivity (`"TANK"` vs `"tank"`) is load-bearing.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/data_registry/per_type_validators_and_duplicate_id_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 003, Story 004
- **Unlocks**: Story 006


## Completion Notes

**Completed**: 2026-04-24
**Criteria**: 6/6 passing
**Story Type**: Logic
**Test Evidence**: tests/unit/data_registry/per_type_validators_and_duplicate_id_test.gd (3/3 pass — plus 5 id-validation micro-tests)
**Deviations**: Per-type field validator hook (_validate_resource_fields) ships as no-op seam; concrete HeroClass/EnemyData/Biome/Dungeon/Floor validators land with Core DB epics (ADR-0011) outside Sprint 1.
**Code Review**: Skipped — review mode solo (per production/review-mode.txt)
**Next**: Sprint-close sequence (/smoke-check sprint → /team-qa sprint → /gate-check)
