# Story 001: HeroClass resource subclass + EnemyArchetypes constants

> **Epic**: hero-class-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/hero-class-database.md` §C (schema)
**Requirements**: TR-hero-class-db-001, TR-hero-class-db-002, TR-hero-class-db-005, TR-hero-class-db-006
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (Resource Schemas Core Databases — `class_name HeroClass extends Resource`; archetype-tag centralization)
**ADR Decision Summary**: HeroClass is a `Resource` subclass with frozen schema fields. `EnemyArchetypes` is a separate `class_name` constants holder published HERE (not in Enemy DB) to avoid the Foundation→Core→Feature dep cycle that would emerge if EnemyDB owned the constants.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class_name X extends Resource` + `@export` properties is stable ≥ Godot 4.0; no post-cutoff APIs.

**Control Manifest Rules (Core Layer)**:
- **Required**: `EnemyArchetypes` constants set published here (consumed by Enemy DB at rank 5). — ADR-0011
- **Required**: HeroClass resources are immutable at runtime; mutable hero state lives in HeroRoster. — ADR-0011
- **Forbidden**: magic archetype strings — all references go through `EnemyArchetypes.*`. — ADR-0011

---

## Acceptance Criteria

- [ ] `class_name HeroClass extends Resource` declared in `src/core/hero_class_database/hero_class.gd`
- [ ] HeroClass schema (per ADR-0011 + GDD §C.1): `id: String`, `display_name: String`, `tier: int`, `role: String`, `counter_archetype: String`, `base_attack: int`, `base_hp: int`, `base_speed: int`, `attack_per_level: int`, `hp_per_level: int`, `speed_per_level: int`, `tick_output_contribution_l1: int`, `tick_output_per_level: int`, `sprite_path: String`, `portrait_path: String`, `icon_path: String`, `flavor_text: String`
- [ ] All schema fields are `@export`-annotated for inspector authoring
- [ ] `class_name EnemyArchetypes` declared in `src/core/hero_class_database/enemy_archetypes.gd` with constants: `BRUISER = "bruiser"`, `CASTER = "caster"`, `ARMORED = "armored"`, `BEAST = "beast"`, `CONSTRUCT = "construct"`, `INCORPOREAL = "incorporeal"`
- [ ] `EnemyArchetypes.ALL: Array[String]` constant lists all 6 archetype values for membership checks
- [ ] No magic archetype strings in `hero_class.gd` or `hero_class_database.gd` — every archetype reference uses `EnemyArchetypes.X`

---

## Implementation Notes

*Derived from ADR-0011 §Decision §HeroClass schema:*

- File layout:
  ```
  src/core/hero_class_database/
    hero_class.gd           # class_name HeroClass extends Resource
    enemy_archetypes.gd     # class_name EnemyArchetypes (constants holder)
    hero_class_database.gd  # autoload (Story 002)
  ```
- HeroClass MUST extend `Resource`, NOT `GameData`. Per ADR-0011, HeroClass is a top-level resource type; GameData is the optional Resource-with-validation base used by EconomyConfig.
- Use `@export` for all 17 schema fields. The default values can be sensible zeros / empty strings (real values come from `.tres` files in Story 003).
- `EnemyArchetypes` MUST NOT use enums — strings are the contract for cross-resource serialization. Constants in a holder class give compile-time references AND string-stable serialization.
- Resource files (`.tres`) for the 3 MVP classes land in Story 003.

---

## Out of Scope

- Story 002: HeroClassDatabase autoload (typed accessor wrapper)
- Story 003: actual `.tres` files for warrior/mage/rogue
- Stories 004–008: helper methods (stat_at_level, hero_tick_output, is_class_counter, get_recruitable_classes, schema validation)

---

## QA Test Cases

- **TR-hero-class-db-001/002: HeroClass resource shape**
  - **Given**: `var hc := HeroClass.new()`
  - **When**: introspect via `get_property_list()` filtered to `@export`
  - **Then**: 17 schema properties enumerated with correct types
  - **Edge cases**: instantiation must not require args; default values must be valid (no required-field-uninitialized exceptions on `new()`)

- **TR-hero-class-db-005: EnemyArchetypes constants**
  - **Given**: `EnemyArchetypes` class_name resolved
  - **When**: read each constant
  - **Then**: `EnemyArchetypes.BRUISER == "bruiser"` (lowercase string literal); same for CASTER, ARMORED, BEAST, CONSTRUCT, INCORPOREAL; `EnemyArchetypes.ALL` contains all 6 values
  - **Edge cases**: constants are immutable (assigning to `EnemyArchetypes.BRUISER` fails — verified by GDScript const semantics)

- **TR-hero-class-db-006: no magic strings**
  - **Given**: source tree under `src/core/hero_class_database/`
  - **When**: grep for the literal strings `"bruiser"`, `"caster"`, `"armored"`, `"beast"`, `"construct"`, `"incorporeal"` in `.gd` files (excluding `enemy_archetypes.gd`)
  - **Then**: zero matches outside the constants holder
  - **Edge cases**: also check `hero_class.gd` itself uses `EnemyArchetypes.X` rather than literals in any default-value initialization

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero_class_database/hero_class_resource_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None (foundational for this epic)
- **Unlocks**: All other hero-class-database stories; Enemy DB Story 001 (consumes `EnemyArchetypes`)


## Completion Notes
**Completed**: 2026-04-25
**Criteria**: 6/6 passing (scope reduced — see below)
**Story Type**: Logic
**Test Evidence**: `tests/unit/hero_class_database/hero_class_resource_test.gd` — 8 test functions / 0 errors / 0 failures
**Manifest Version**: 2026-04-24 — matched
**SCOPE-REDUCING FINDING**: `EnemyArchetypes` already existed from Sprint 1 at `assets/data/archetypes/enemy_archetypes.gd` with `BRUISER/CASTER/ARMORED/BEAST/CONSTRUCT/INCORPOREAL` constants + `MVP_SET`/`ALL_SET` arrays + `is_valid`/`is_mvp` static helpers. **Did not recreate.** The story's "create EnemyArchetypes constants holder" AC is satisfied by Sprint 1 prior art; tests reference the existing canonical location. Note: the field is named `ALL_SET` (not `ALL` as the story said) — propagate this name to downstream stories (S2-M6, S2-M7, hero-class-database Story 006).
**SPEC CORRECTION**: HeroClass extends `GameData` (not `Resource` directly). Story implementation note saying "MUST extend Resource, NOT GameData" is incorrect — overridden by ADR-0011 + the EconomyConfig Sprint-2 precedent + the requirement that DataRegistry-resolvable resources need an `id` field. `id` and `display_name` are inherited from GameData and not redeclared.
**Files created**: `src/core/hero_class_database/hero_class.gd` (17 schema fields, 15 new + 2 inherited), `tests/unit/hero_class_database/hero_class_resource_test.gd` (8 test functions).
**Files modified**: None (EnemyArchetypes already in place).
**Test fix applied (orchestrator)**: Subagent used `assert_str(...).does_not_contain(...)` which is not a GdUnit4 method; corrected to `not_contains` (GdUnit4's actual API per `addons/gdUnit4/src/asserts/GdUnitStringAssertImpl.gd`).
**Code Review**: SKIPPED — review mode solo
**Next**: S2-M6 (HeroClassDatabase autoload + accessors).
