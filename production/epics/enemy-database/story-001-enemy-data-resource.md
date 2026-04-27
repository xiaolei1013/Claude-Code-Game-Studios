# Story 001: EnemyData resource subclass + EnemyArchetypes consumer

> **Epic**: enemy-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/enemy-database.md` §C (schema), §H-02 (archetype tags)
**Requirements**: TR-enemy-db-001, TR-enemy-db-002, TR-enemy-db-004, TR-enemy-db-007
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (Resource Schemas Core Databases — `class_name EnemyData extends Resource`/`GameData`; archetype-tag references through `EnemyArchetypes` constants)
**ADR Decision Summary**: EnemyData is a `Resource` subclass extending GameData (id + display_name inherited). Schema is read-only/static at runtime: no leveling, no per-enemy loot override, no resistances in MVP. Archetype field references `EnemyArchetypes` constants (already published Sprint 1 at `assets/data/archetypes/enemy_archetypes.gd`) — no magic strings.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class_name X extends GameData` + `@export` properties stable ≥ Godot 4.0; no post-cutoff APIs.

**Control Manifest Rules (Core Layer)**:
- **Required**: Schema fields per ADR-0011 (id, display_name, tier, archetype, biome, base_hp, base_attack, base_speed, sprite_path, death_anim_key, flavor_text, is_boss). — ADR-0011
- **Required**: archetype field references `EnemyArchetypes` constants — no magic strings. — ADR-0011
- **Required**: enemies are read-only/static; no leveling fields, no per-enemy loot_override, no resistances in MVP. — ADR-0011

---

## Acceptance Criteria

- [ ] `class_name EnemyData extends GameData` declared in `src/core/enemy_database/enemy_data.gd`
- [ ] EnemyData schema (per ADR-0011 + GDD §C): `tier: int`, `archetype: String`, `biome: String`, `base_hp: int`, `base_attack: int`, `base_speed: int`, `sprite_path: String`, `death_anim_key: String`, `flavor_text: String`, `is_boss: bool`
- [ ] All schema fields are `@export`-annotated for inspector authoring
- [ ] `id` and `display_name` inherited from `GameData` — NOT redeclared
- [ ] Default `EnemyData.new()` instantiates without args; `is_boss` defaults to `false`
- [ ] No magic archetype strings in `enemy_data.gd` — all references go through `EnemyArchetypes.X` constants from `assets/data/archetypes/enemy_archetypes.gd`
- [ ] No leveling fields, no `loot_override`, no resistance fields present in MVP schema (TR-enemy-db-004 + TR-enemy-db-023)

---

## Implementation Notes

*Derived from ADR-0011 §Decision §EnemyData schema:*

- File layout:
  ```
  src/core/enemy_database/
    enemy_data.gd            # class_name EnemyData extends GameData
    enemy_database.gd        # autoload (Story 002)
  ```
- Mirror the HeroClass pattern from `src/core/hero_class_database/hero_class.gd` (Sprint 2 S2-M5):
  - `class_name EnemyData` + `extends GameData`
  - Doc-comment header citing ADR-0011 + ADR-0006 + GDD §C
  - Comment that `id` and `display_name` are inherited
- Use `@export` for all 10 net-new schema fields. Sensible defaults so `EnemyData.new()` succeeds:
  - `tier: int = 1`, `archetype: String = ""`, `biome: String = ""`, `base_hp: int = 0`, `base_attack: int = 0`, `base_speed: int = 0`, `sprite_path: String = ""`, `death_anim_key: String = ""`, `flavor_text: String = ""`, `is_boss: bool = false`
- DO NOT redeclare `id` / `display_name` (inherited from GameData per Sprint 2 precedent).
- DO NOT add helper methods (e.g., no `is_archetype_counter` — that's hero-class side; no `damage_at_level` — enemies don't level).
- Resource files (`.tres`) for the 7+ MVP enemies land in Story 003.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: EnemyDatabase autoload (typed accessor wrapper)
- Story 003: actual `.tres` files
- Story 004: load-time schema validation (`_validate()` method)
- Story 005: cross-system kill-gold formula consistency
- Story 006: save file id-stability test

---

## QA Test Cases

- **TR-enemy-db-001/002: EnemyData resource shape**
  - **Given**: `var ed := EnemyData.new()`
  - **When**: introspect via `get_property_list()` filtered to `@export`
  - **Then**: 10 net-new schema properties enumerated (plus inherited `id` + `display_name` = 12 total) with correct types
  - **Edge cases**: instantiation must not require args; default values must be valid; `is_boss` defaults `false`

- **TR-enemy-db-004: read-only/static enemies**
  - **Given**: EnemyData schema introspection
  - **When**: search for fields named `level`, `current_level`, `loot_override`, `resistance_*`
  - **Then**: zero matches — schema has no leveling/override/resistance fields in MVP
  - **Edge cases**: future V1.0 expansion is OK (per TR-enemy-db-023 noting V1.0 may add); MVP must NOT have them

- **TR-enemy-db-007: archetype string references via EnemyArchetypes**
  - **Given**: source tree under `src/core/enemy_database/enemy_data.gd`
  - **When**: grep for literal archetype strings (`"bruiser"`, `"caster"`, `"armored"`, `"beast"`, `"construct"`, `"incorporeal"`)
  - **Then**: zero matches in `enemy_data.gd` (mirror Sprint 2 hero_class_resource_test pattern using `assert_str(source).not_contains(...)`)
  - **Edge cases**: also check default archetype value is `""` (empty, not a literal archetype string)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy_database/enemy_data_resource_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Sprint 1 GameData base class (already landed); Sprint 1 EnemyArchetypes constants (`assets/data/archetypes/enemy_archetypes.gd` — already landed)
- **Unlocks**: Story 002 (autoload), Story 003 (.tres files), Story 004 (validation), Story 005 (cross-system), Story 006 (id-stability)
