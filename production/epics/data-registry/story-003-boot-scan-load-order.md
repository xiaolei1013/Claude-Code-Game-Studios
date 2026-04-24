# Story 003: Boot scan load order and per-category enumeration

> **Epic**: data-registry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/data-loading.md`
**Requirements**: [TR-data-loading-001, TR-data-loading-002, TR-data-loading-003, TR-data-loading-007, TR-data-loading-008, TR-data-loading-022, TR-data-loading-025, TR-data-loading-026]
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0006 (primary)
**ADR Decision Summary**: Boot scan is eager + synchronous via `ResourceLoader.load(path)` over the fixed ordered category list `classes → enemies → biomes → dungeons → items → matchup`; adding a category requires explicit edit of `ordered_categories` + `min_content_count` (no auto-discovery).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ResourceLoader.load(path)` synchronous path is stable 4.0+; `DirAccess` for directory enumeration stable 4.0+. `Array[Dictionary]` inspector limits flagged for consumer schemas (Floor.enemy_list) but not this story — the boot scan only returns typed arrays of loaded resources. No `load_threaded_request` in MVP.

**Control Manifest Rules (Foundation Layer, DataRegistry)**:
- **Required**: "DataRegistry boot scan is eager + synchronous via `ResourceLoader.load(path)` (NOT `load_threaded_request` for MVP)." — ADR-0006
- **Required**: "Deterministic load order: `classes → enemies → biomes → dungeons → items → matchup` (PackedStringArray `ordered_categories`)." — ADR-0006
- **Required**: "Adding a new content category requires explicit edit to `DataRegistry.ordered_categories` AND `min_content_count`; auto-discovery from directory presence FORBIDDEN." — ADR-0006
- **Required**: "Content lives ONLY under `assets/data/{classes,enemies,biomes,dungeons,items,matchup}/`; `.tres` is the only authored format." — ADR-0006
- **Forbidden**: "Never call `ResourceLoader.load(\"res://assets/data/...\")` directly from non-DataRegistry code — all content access flows through DataRegistry." — ADR-0006
- **Forbidden**: "Never auto-discover content categories from directory presence — explicit registration only." — ADR-0006

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-DLS-NN) or TR-registry (TR-data-loading-NNN):*

- [ ] TR-data-loading-001: DataRegistry autoload enumerates all `.tres` under `assets/data/` at boot; rank 1 (first)
- [ ] TR-data-loading-002: Content directory structure: `classes/`, `enemies/`, `biomes/`, `dungeons/`, `items/`, `matchup/` under `assets/data/`
- [ ] TR-data-loading-003: `.tres` (Godot text resource) is the only authored format; `.res` permitted only as `.pck` compression artifact
- [ ] TR-data-loading-007: Eager-load all content at boot during LOADING state before consumer access
- [ ] TR-data-loading-008: Cross-reference DAG rule: no cycles; load order `classes → enemies → biomes → dungeons → items → matchup` *(cycle detection lives in Story 006; this story covers the deterministic load order only)*
- [ ] TR-data-loading-022: Tuning knob `data_root_path` default `res://assets/data`; dev/test override allows fixture datasets
- [ ] TR-data-loading-025: `lazy_load_categories` `Array[String]` knob for V1.0 migration path; MVP empty
- [ ] TR-data-loading-026: Forward-compat: Godot loads by field name, unknown fields ignored, missing fields default — no per-file version stamp

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

- Add the deterministic category list as a private constant in `data_registry.gd`: `const ORDERED_CATEGORIES: PackedStringArray = ["classes", "enemies", "biomes", "dungeons", "items", "matchup"]`. Edit-in-lockstep with `min_content_count` keys per ADR-0006.
- Declare `@export var data_root_path: String = "res://assets/data"` (dev override only; production builds may assert default at boot per ADR-0006 §Content directory layout).
- Declare `@export var lazy_load_categories: PackedStringArray = []` — MVP leaves empty; wiring is Story 008's knob surface, but the field exists here.
- Implement `_boot_scan()` per ADR-0006 §Eager synchronous boot scan:
  ```
  for category in ORDERED_CATEGORIES:
      if not _load_category(category):
          return  # already transitioned to ERROR with details
  # DAG validation + min-count checks deferred to Stories 005/006
  _state = State.READY
  registry_ready.emit()
  ```
- `_load_category(category)`: enumerate `%s/%s` % [data_root_path, category] via `DirAccess.get_files_at(path)`; for each `.tres` file call `ResourceLoader.load(full_path)` synchronously; store the loaded `Resource` keyed by `resource.id` inside `_categories[category]: Dictionary`.
- Skip files whose extension is not `.tres` (guardrail against stray `.res` or `.import` files in source; `.res` only ships as `.pck` artifact).
- The empty-category ERROR transition is Story 005's responsibility (via `min_content_count`); THIS story allows empty categories during the load walk (Story 003's loop must not crash when `items/` is empty in MVP).
- Forward-compat (TR-026) is a property of Godot's resource loader, not explicit code — document it in a comment near `_load_category` so reviewers understand unknown fields are silently ignored and missing fields default. No behavioral code.
- Keep the per-category dictionary structure plain `Dictionary` keyed by `id: String → Resource`; typed accessors are Story 004.

---

## Out of Scope

- Story 002: `GameData` base + constant-set files (prerequisite).
- Story 004: `resolve()` and `get_all_by_type()` public API.
- Story 005: Per-type validators + duplicate-id detection + `min_content_count` ERROR transitions.
- Story 006: Cross-reference DAG validation (cycle detection).
- Story 007: Hot-reload re-enumeration.
- Story 008: `<200 ms` performance budget AC-DLS-07.

---

## QA Test Cases

- **TR-data-loading-001 / TR-data-loading-007**: Boot scan enumerates all `.tres` under the six category subdirectories synchronously
  - **Given**: A test fixture under `tests/fixtures/data_registry/mvp_minimal/` with at least one valid `.tres` per category (`classes/*.tres`, `enemies/*.tres`, etc.), and `data_root_path` overridden to that path.
  - **When**: DataRegistry `_ready()` runs.
  - **Then**: Every `.tres` file under each category subdirectory has been passed through `ResourceLoader.load(path)` once; the internal `_categories[category]` dictionary contains one entry per loaded resource keyed by `resource.id`; all loads complete before `_ready()` returns (synchronous).
  - **Edge cases**: Empty `items/` directory must not abort the scan; non-.tres files (e.g., `.gd`, `.import`, `.res`) must be skipped.

- **TR-data-loading-008**: Category load order is deterministic
  - **Given**: Fixture resources authored such that a Dungeon's `biome_id` `ExtResource` ref resolves correctly only if `biomes/` loaded before `dungeons/`.
  - **When**: Boot scan runs.
  - **Then**: The observed invocation order is `classes → enemies → biomes → dungeons → items → matchup`; cross-file references (`ExtResource`) resolve against already-cached resources at parse time.
  - **Edge cases**: Reordering the `ORDERED_CATEGORIES` constant must break this test — protects against silent reorder regressions; a loaded Dungeon's nested Biome ref must be non-null post-load.

- **TR-data-loading-002 / TR-data-loading-003**: Content is only read from the six canonical subdirectories and only `.tres` is authored
  - **Given**: An adversarial fixture containing `assets/data/bonus_category/` and `classes/warrior.res` (binary).
  - **When**: Boot scan runs.
  - **Then**: The `bonus_category/` is NOT enumerated (auto-discovery forbidden); the `.res` file is skipped (authored format contract); no runtime error is raised for their presence.
  - **Edge cases**: Adding `"bonus_category"` to `ORDERED_CATEGORIES` must be a two-file edit per the manifest rule — this test proves auto-discovery is not the path.

- **TR-data-loading-022**: `data_root_path` override redirects the boot scan
  - **Given**: `data_root_path` set to `res://tests/fixtures/data_registry/mvp_minimal/` before `_ready()` runs.
  - **When**: Boot scan executes.
  - **Then**: Enumeration reads from the override path, NOT `res://assets/data/`.
  - **Edge cases**: Empty / non-existent override path should surface as an ERROR (tested fully under Story 005's min-count check).

- **TR-data-loading-025 / TR-data-loading-026**: MVP knob defaults + forward-compat inspection
  - **Given**: A fresh DataRegistry instance post-boot.
  - **When**: Tuning knobs are inspected.
  - **Then**: `lazy_load_categories == []`; a `.tres` fixture with an unknown extra field loads successfully (field silently ignored) and a `.tres` missing an optional field loads with declared defaults.
  - **Edge cases**: Populating `lazy_load_categories` is a V1.0 concern — no lazy path is exercised in MVP.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/data_registry/boot_scan_load_order_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001, Story 002
- **Unlocks**: Story 004, Story 005


## Completion Notes

**Completed**: 2026-04-24
**Criteria**: 8/8 passing
**Story Type**: Logic
**Test Evidence**: tests/unit/data_registry/boot_scan_load_order_test.gd (7/7 pass)
**Deviations**: `const ORDERED_CATEGORIES: PackedStringArray = PackedStringArray([...])` changed to `const ... = Array[String] = [...]`. Tests updated to call `_make_registry()` helper (adds `min_content_count = {}`) after S1-N1 thresholds landed.
**Code Review**: Skipped — review mode solo (per production/review-mode.txt)
**Next**: Sprint-close sequence (/smoke-check sprint → /team-qa sprint → /gate-check)
