# Story 002: BiomeDungeonDatabase autoload + accessors

> **Epic**: biome-dungeon-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/biome-dungeon-database.md` §C (autoload pattern), §H-01 (resolution), §H-08 (V1.0 filter)
**Requirements**: TR-biome-dungeon-db-006, TR-biome-dungeon-db-014
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (resource schema + DataRegistry resolve contract), ADR-0006 (boot scan), ADR-0003 (autoload rank 6 + zero-arg `_init`)
**ADR Decision Summary**: BiomeDungeonDatabase is a thin typed-accessor autoload (rank 6 — last in the rank table) wrapping `DataRegistry.resolve("biomes" | "dungeons" | "floors", id)`. Mirrors the Sprint 2 HeroClassDatabase + Sprint 3 EnemyDatabase pattern. Provides ergonomic helpers including `get_playable_biomes()` which filters out V1.0 stubs.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core Layer)**:
- **Required**: BiomeDungeonDatabase autoload at rank 6 in project.godot. — ADR-0003 / ADR-0011
- **Required**: zero-arg `_init`. — ADR-0003 Amendment #3
- **Required**: get_playable_biomes() filters by `status == "active"`. — ADR-0011 / TR-biome-dungeon-db-014

---

## Acceptance Criteria

- [ ] `extends Node` autoload at `src/core/biome_dungeon_database/biome_dungeon_database.gd`; NO `class_name BiomeDungeonDatabase` (matches Sprint 1+2 lesson)
- [ ] Registered at rank 6 in `project.godot [autoload]` after EnemyDatabase(5)
- [ ] `_init() -> void` zero-arg
- [ ] **TR-biome-dungeon-db-006**: three category-aware accessors:
  - `get_biome_by_id(id: String) -> Biome` returns Biome or null
  - `get_dungeon_by_id(id: String) -> Dungeon` returns Dungeon or null
  - `get_floor_by_id(id: String) -> Floor` returns Floor or null
- [ ] **TR-biome-dungeon-db-014 + AC H-08**: `get_playable_biomes() -> Array[Biome]` returns only `status == "active"` biomes (V1.0 stubs filtered out); sorted by id
- [ ] Helper: `get_floors_for_dungeon(dungeon_id: String) -> Array[Floor]` returns dungeon's floors ordered by `floor_index`
- [ ] Helper: `get_all_biome_ids() -> Array[String]` returns sorted list of all loaded biome ids (active + planned_v1)
- [ ] **AC H-01**: `get_biome_by_id("forest_reach")` returns non-null after DataRegistry boot completes
- [ ] Null contract: missing id returns null without push_error (callers handle null)

---

## Implementation Notes

*Derived from ADR-0011 §Decision §typed-accessor pattern. Mirror Sprint 2/3 patterns:*

- Pseudocode:
  ```
  # src/core/biome_dungeon_database/biome_dungeon_database.gd
  extends Node

  func _init() -> void:
      pass

  func _ready() -> void:
      pass

  func get_biome_by_id(id: String) -> Biome:
      return DataRegistry.resolve("biomes", id) as Biome

  func get_dungeon_by_id(id: String) -> Dungeon:
      return DataRegistry.resolve("dungeons", id) as Dungeon

  func get_floor_by_id(id: String) -> Floor:
      return DataRegistry.resolve("floors", id) as Floor

  func get_playable_biomes() -> Array[Biome]:
      var result: Array[Biome] = []
      for r: Resource in DataRegistry.get_all_by_type("biomes"):
          if r is Biome and (r as Biome).status == "active":
              result.append(r as Biome)
      result.sort_custom(func(a, b): return a.id < b.id)
      return result

  func get_all_biome_ids() -> Array[String]:
      var ids: Array[String] = []
      for r: Resource in DataRegistry.get_all_by_type("biomes"):
          if r is Biome:
              ids.append((r as Biome).id)
      ids.sort()
      return ids

  func get_floors_for_dungeon(dungeon_id: String) -> Array[Floor]:
      var dungeon: Dungeon = get_dungeon_by_id(dungeon_id)
      if dungeon == null:
          return []
      var floors: Array[Floor] = dungeon.floors.duplicate()
      floors.sort_custom(func(a, b): return a.floor_index < b.floor_index)
      return floors
  ```
- DataRegistry's ORDERED_CATEGORIES already includes "biomes", "dungeons" — but **does it include "floors"**? Verify before implementation. If not, this story may need an out-of-scope deviation similar to S2-M2 (extending ORDERED_CATEGORIES to include "floors"). Floors live INSIDE Dungeon resources by ADR-0011 design — not as standalone .tres files. So `get_floor_by_id` may need to crawl all dungeons. Re-read ADR-0011 §Resource layout to clarify before implementation; if floors are nested-only (no standalone .tres), implement `get_floor_by_id` as a cross-dungeon search.
- Rank 6 registration: this is the LAST autoload in the canonical rank table per ADR-0003. After landing, all 4 Foundation + 4 Core autoloads are registered. SaveLoadSystem (rank 2) hole still present.

---

## Out of Scope

- Story 003: Forest Reach MVP `.tres` content
- Story 004: schema validation
- Story 005: V1.0 stub biome content
- Story 006: cross-system enemy_id resolution
- Story 007: save id-stability

---

## QA Test Cases

- **AC H-01: biome resolvable post-boot**
  - **Given**: DataRegistry in READY state with Forest Reach biome `.tres` loaded (Story 003 fixture)
  - **When**: `BiomeDungeonDatabase.get_biome_by_id("forest_reach")`
  - **Then**: returns non-null Biome with `id == "forest_reach"`, `status == "active"`, non-empty `display_name`
  - **Edge cases**: pre-READY state — graceful-degrade pattern

- **AC: null contract**
  - **Given**: DataRegistry READY
  - **When**: `get_biome_by_id("does_not_exist")`, `get_dungeon_by_id("nope")`, `get_floor_by_id("phantom")`
  - **Then**: each returns null; **no** push_error
  - **Edge cases**: empty string returns null

- **TR-biome-dungeon-db-014 + AC H-08: V1.0 filter in get_playable_biomes**
  - **Given**: Forest Reach (status="active") + 1+ V1.0 stub biome (status="planned_v1") loaded
  - **When**: `get_playable_biomes()`
  - **Then**: returned array contains Forest Reach but NOT the V1.0 stub
  - **Edge cases**: each V1.0 stub still individually resolvable via `get_biome_by_id` (filter is one-way)

- **AC: get_floors_for_dungeon returns ordered list**
  - **Given**: Forest Reach dungeon with 5 floors (Story 003)
  - **When**: `get_floors_for_dungeon("forest_reach_main")` (or whatever the dungeon id is)
  - **Then**: returned `Array[Floor]` length 5, sorted by `floor_index 1..5` gap-free
  - **Edge cases**: unknown dungeon id → empty array, no error

- **AC: zero-arg _init + autoload rank**
  - **Given**: fresh boot
  - **When**: introspect autoload list
  - **Then**: BiomeDungeonDatabase at index 6 (rank); no autoload-construction errors

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/biome_dungeon_database/biome_dungeon_database_autoload_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (Biome/Dungeon/Floor schemas), Sprint 3 EnemyDatabase Story 002 (rank 5 — must precede rank 6), Sprint 1 DataRegistry resolve API
- **Unlocks**: Story 003 (.tres testing), Story 005 (V1.0 stub filter test); FloorUnlockSystem + FormationAssignment Feature epics
