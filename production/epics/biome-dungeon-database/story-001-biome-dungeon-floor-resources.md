# Story 001: Biome / Dungeon / Floor resource subclasses

> **Epic**: biome-dungeon-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/biome-dungeon-database.md` §C (schema)
**Requirements**: TR-biome-dungeon-db-001, TR-biome-dungeon-db-002, TR-biome-dungeon-db-003, TR-biome-dungeon-db-004, TR-biome-dungeon-db-005
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (Resource Schemas Core Databases — three nested resource types: `class_name Biome/Dungeon/Floor extends GameData`)
**ADR Decision Summary**: Three Resource subclasses extending GameData (id + display_name inherited). Biome owns Dungeons; Dungeon owns Floors. Floor.enemy_list is a deterministic `Array[Dictionary]` of `{enemy_id, count}` — no RNG, no probabilistic spawns.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Typed `Array[Floor]`, `Array[Dictionary]` syntax stable ≥ Godot 4.4 (precedent-verified via Sprint 2). Nested resource references (Biome holds `dungeons: Array[Dungeon]`) use Godot's standard Resource composition.

**Control Manifest Rules (Core Layer)**:
- **Required**: three nested types (Biome/Dungeon/Floor) per ADR-0011. — ADR-0011
- **Required**: Floor.enemy_list is deterministic Array[Dictionary] — no RNG. — ADR-0011
- **Required**: read-only at runtime; no mutation methods. — ADR-0011

---

## Acceptance Criteria

- [ ] `class_name Biome extends GameData` declared in `src/core/biome_dungeon_database/biome.gd`
- [ ] `class_name Dungeon extends GameData` declared in `src/core/biome_dungeon_database/dungeon.gd`
- [ ] `class_name Floor extends GameData` declared in `src/core/biome_dungeon_database/floor.gd`
- [ ] **TR-biome-dungeon-db-002 Biome schema**: `primary_palette_key: String`, `dominant_archetypes: Array[String]`, `dungeons: Array[Dungeon]`, `environmental_storytelling: Array[String]`, `flavor_text: String`, `status: String` (default `"active"`)
- [ ] **TR-biome-dungeon-db-003 Dungeon schema**: `biome_id: String` (back-ref), `floors: Array[Floor]` (ordered by floor_index)
- [ ] **TR-biome-dungeon-db-004 Floor schema**: `floor_index: int`, `enemy_list: Array[Dictionary]`, `expected_clear_time_seconds: int`, `is_boss_floor: bool`, `flavor_text: String`
- [ ] **TR-biome-dungeon-db-005**: `Floor.enemy_list` entries have shape `{ "enemy_id": String, "count": int }` — deterministic; no RNG fields, no probabilistic spawn weights
- [ ] All schema fields are `@export`-annotated for inspector authoring
- [ ] `id` and `display_name` inherited from `GameData` — NOT redeclared in any of the 3 subclasses
- [ ] Default `Biome.new()`, `Dungeon.new()`, `Floor.new()` each instantiate without args
- [ ] `is_boss_floor` defaults `false`; `status` defaults `"active"`

---

## Implementation Notes

*Derived from ADR-0011 §Decision §nested resource types:*

- File layout:
  ```
  src/core/biome_dungeon_database/
    biome.gd                       # class_name Biome extends GameData
    dungeon.gd                     # class_name Dungeon extends GameData
    floor.gd                       # class_name Floor extends GameData
    biome_dungeon_database.gd      # autoload (Story 002)
  ```
- Mirror the HeroClass + EnemyData pattern from Sprint 2 / Sprint 3 enemy-database Story 001.
- For each subclass:
  - Doc-comment header citing ADR-0011 + ADR-0006 + GDD §C
  - Note that `id` + `display_name` are inherited from GameData
  - Use `@export` for all schema fields
- `Biome.dungeons: Array[Dungeon]` — typed array of nested resources. Inspector authoring will show "Add Dungeon" button.
- `Dungeon.floors: Array[Floor]` — same nested pattern.
- `Floor.enemy_list: Array[Dictionary]` — typed array of untyped dicts. Inspector authoring shows "Add Element" button. Authoring contract: each dict has exactly two keys, `"enemy_id"` (String) and `"count"` (int). Validation lands in Story 004.
- `Biome.dominant_archetypes: Array[String]` — informational hint about which archetypes dominate this biome (consumed by matchup-resolver pre-fight scout). Strings should be `EnemyArchetypes.MVP_SET` members but not enforced at this layer (validation Story 004).
- DO NOT add helper methods — keep schema-only.
- Resource files (`.tres`) for Forest Reach MVP land in Story 003.

---

## Out of Scope

- Story 002: BiomeDungeonDatabase autoload (typed accessor wrapper)
- Story 003: actual Forest Reach `.tres` content
- Story 004: load-time validation (enemy_id resolution, floor_index uniqueness, etc.)
- Story 005: V1.0 stub biome
- Story 006: cross-system enemy_id resolution test
- Story 007: save id-stability

---

## QA Test Cases

- **TR-biome-dungeon-db-001/002/003/004: three resource shapes**
  - **Given**: `Biome.new()`, `Dungeon.new()`, `Floor.new()`
  - **When**: introspect each via `get_property_list()` filtered to `@export`
  - **Then**: Biome has 6 net-new properties (+ 2 inherited = 8); Dungeon has 2 net-new (+ 2 = 4); Floor has 5 net-new (+ 2 = 7) with correct types
  - **Edge cases**: instantiation must not require args; default values must be valid

- **TR-biome-dungeon-db-005: Floor.enemy_list determinism**
  - **Given**: a Floor with `enemy_list = [{"enemy_id": "hollow_brute", "count": 3}, {"enemy_id": "bog_caster", "count": 2}]`
  - **When**: introspect the schema and a sample entry
  - **Then**: schema declares `enemy_list: Array[Dictionary]` (typed); each entry has exactly the 2 expected keys with the expected types
  - **Edge cases**: empty enemy_list is valid at the schema level (rejected by Story 004 validator if non-boss floor); single-entry list is valid

- **AC: nested resource composition**
  - **Given**: a Biome with `dungeons = [Dungeon.new()]`; that Dungeon has `floors = [Floor.new()]`
  - **When**: read `biome.dungeons[0].floors[0]`
  - **Then**: returns the Floor instance; nested access works without errors
  - **Edge cases**: empty arrays at every level handled gracefully (no nil-deref)

- **AC: defaults for boolean + status**
  - **Given**: fresh Floor and Biome
  - **When**: read `Floor.is_boss_floor` and `Biome.status`
  - **Then**: `is_boss_floor == false`; `status == "active"`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/biome_dungeon_database/biome_dungeon_resource_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Sprint 1 GameData base class
- **Unlocks**: Story 002 (autoload), Story 003 (Forest Reach .tres), all downstream
