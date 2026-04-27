# Story 002: EnemyDatabase autoload + DataRegistry accessor wrapper

> **Epic**: enemy-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/enemy-database.md` §C (autoload pattern), §H-01 (resolution)
**Requirements**: TR-enemy-db-005 (DataRegistry.resolve contract), TR-enemy-db-022 (null contract)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (resource schema + DataRegistry resolve contract), ADR-0006 (boot scan), ADR-0003 (autoload rank 5 + zero-arg `_init`)
**ADR Decision Summary**: EnemyDatabase is a thin typed-accessor autoload (rank 5) wrapping `DataRegistry.resolve("enemies", id)`. Mirrors the Sprint 2 HeroClassDatabase pattern (rank 4). Provides ergonomic helpers (`get_by_id`, `get_all_ids`) so consumers don't need to know the registry category string.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Standard autoload pattern; no post-cutoff APIs.

**Control Manifest Rules (Core Layer)**:
- **Required**: EnemyDatabase autoload at rank 5 in project.godot. — ADR-0003 / ADR-0011
- **Required**: zero-arg `_init`. — ADR-0003 Amendment #3
- **Required**: consumers read EnemyData via DataRegistry only (no writes back; immutable runtime). — ADR-0011

---

## Acceptance Criteria

- [ ] `extends Node` autoload script at `src/core/enemy_database/enemy_database.gd`; NO `class_name EnemyDatabase` (matches Sprint 1+2 lesson)
- [ ] Registered at rank 5 in `project.godot [autoload]` after HeroClassDatabase(4); architecture.md rank table verified in lockstep
- [ ] `_init() -> void` zero-arg
- [ ] **TR-enemy-db-005**: `get_by_id(id: String) -> EnemyData` returns EnemyData or null
- [ ] **AC H-01**: `get_by_id("hollow_brute")` etc. each return non-null EnemyData after DataRegistry boot completes; `result.id == query`; `result.tier ∈ {1,2,3}`; `result.display_name` non-empty
- [ ] **TR-enemy-db-022**: null return is documented contract — `get_by_id("nonexistent")` returns null without `push_error` (callers handle null)
- [ ] **Resource cache consistency**: same id queries return same Resource instance (Godot resource cache)
- [ ] Helper: `get_all_ids() -> Array[String]` returns sorted list of all loaded enemy ids

---

## Implementation Notes

*Derived from ADR-0011 §Decision §typed-accessor pattern + ADR-0006 §DataRegistry.resolve. Mirror the Sprint 2 HeroClassDatabase implementation precisely:*

- Pseudocode:
  ```
  # src/core/enemy_database/enemy_database.gd
  extends Node

  func _init() -> void:
      pass

  func _ready() -> void:
      pass

  func get_by_id(id: String) -> EnemyData:
      return DataRegistry.resolve("enemies", id) as EnemyData

  func get_all_ids() -> Array[String]:
      var ids: Array[String] = []
      for r: Resource in DataRegistry.get_all_by_type("enemies"):
          if r is EnemyData:
              ids.append((r as EnemyData).id)
      ids.sort()
      return ids
  ```
- Do NOT cache results inside EnemyDatabase. DataRegistry holds the cache; this autoload is a thin typed wrapper.
- Rank 5 autoload registration: Economy(3), HeroClassDatabase(4), **EnemyDatabase(5)**, BiomeDungeonDatabase(6).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: actual `.tres` files for the 7+ MVP enemies
- Story 004: schema validation hook
- Story 005: kill-gold cross-system formula
- Story 006: save id-stability test

---

## QA Test Cases

- **AC H-01: enemies resolvable post-boot**
  - **Given**: DataRegistry in READY state with MVP enemy `.tres` files loaded (Story 003 fixture)
  - **When**: `EnemyDatabase.get_by_id("hollow_brute")` etc.
  - **Then**: each returns non-null EnemyData; `id` matches query; `tier ∈ {1,2,3}`; `display_name` non-empty
  - **Edge cases**: pre-READY state queries — apply graceful-degrade pattern (push_warning + return) per Sprint 2 precedent

- **TR-enemy-db-022: null contract**
  - **Given**: DataRegistry READY
  - **When**: `get_by_id("does_not_exist")`
  - **Then**: returns null; **no** push_error fired
  - **Edge cases**: empty string returns null

- **AC: resource cache consistency**
  - **Given**: a loaded enemy id
  - **When**: `get_by_id("hollow_brute")` called twice
  - **Then**: returned Resource instance is `==` (object-identity) to the prior return — Godot resource cache reuses same Resource objects for the same path
  - **Edge cases**: across save/load round-trip — defer to Story 006

- **AC: get_all_ids enumerates enemies**
  - **Given**: 7+ MVP enemies loaded (Story 003 fixture)
  - **When**: `get_all_ids()` returns
  - **Then**: returned `Array[String]` has length ≥ 7, sorted alphabetical, contains exactly the registered ids
  - **Edge cases**: zero enemies loaded → empty array, no error

- **AC: zero-arg _init + autoload rank**
  - **Given**: fresh boot
  - **When**: introspect autoload list
  - **Then**: EnemyDatabase at index 5 (rank); no autoload-construction errors

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/enemy_database/enemy_database_autoload_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (EnemyData resource schema), Sprint 2 HeroClassDatabase (rank 4 — must precede rank 5 in project.godot), Sprint 1 DataRegistry resolve API
- **Unlocks**: Story 003 (.tres testing), Story 005 (kill-gold cross-system), BiomeDungeonDatabase epic (Floor.enemy_id resolution)
