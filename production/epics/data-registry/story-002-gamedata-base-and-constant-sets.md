# Story 002: GameData abstract base and archetype/role constant sets

> **Epic**: data-registry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/data-loading.md`
**Requirements**: [TR-data-loading-004, TR-data-loading-005]
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0006 (primary) + ADR-0011 (archetype/role constant set authority)
**ADR Decision Summary**: All content resources extend `@abstract class_name GameData extends Resource` with `id: String` (snake_case, globally unique within content type) and `display_name: String`; archetype and role strings come from single canonical constant-set modules.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `@abstract` keyword is a Godot 4.5+ post-cutoff feature (verification inherited from ADR-0006). Editor "New Resource" UI on `@abstract GameData` is undocumented — expected behavior is a clear editor error rather than silent misconstruction; designers are instructed to extend HeroClass / Enemy / Biome / Dungeon / Floor, never `GameData` directly. `PackedStringArray` + `static func` are stable 4.0+ patterns.

**Control Manifest Rules (Foundation Layer, DataRegistry)**:
- **Required**: "`@abstract class_name GameData extends Resource` with `id: String` (snake_case, globally unique within content type) + `display_name: String`; subclasses MUST NOT redeclare these." — ADR-0006, ADR-0011
- **Required**: "Archetype constant set: `EnemyArchetypes extends RefCounted` at `assets/data/archetypes/enemy_archetypes.gd` with 6 const strings (`bruiser`, `caster`, `armored`, `beast`, `construct`, `incorporeal`); `MVP_SET` = 3, `ALL_SET` = 6; static `is_valid(s)` + `is_mvp(s)`." — ADR-0011
- **Required**: "Role constant set: `ClassRoles extends RefCounted` at `assets/data/roles/class_roles.gd` with 6 const strings (`tank`, `striker`, `precision`, `support`, `ranged`, `commander`); `ALL_SET` + `is_valid(s)`." — ADR-0011
- **Forbidden**: "Never hardcode archetype string literals (`\"bruiser\"`, `[\"bruiser\",\"caster\"]`) outside `enemy_archetypes.gd` (`archetype_string_hardcoded_outside_constant_set`)." — ADR-0011
- **Forbidden**: "Never hardcode role string literals outside `class_roles.gd` (`role_string_hardcoded_outside_constant_set`)." — ADR-0011

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-DLS-NN) or TR-registry (TR-data-loading-NNN):*

- [ ] TR-data-loading-004: All content resources extend abstract `GameData` base (`id: String`, `display_name: String`) using 4.5+ `@abstract`
- [ ] TR-data-loading-005: Every resource declares `id: String` as first `@export` field; snake_case; globally unique within type *(unique-within-type check lives in Story 005; this story covers the base-class declaration and snake_case authoring convention only)*

---

## Implementation Notes

*Derived from ADR-0006/0011 Implementation Guidelines:*

- Create `assets/data/_base/game_data.gd` containing `@abstract` + `class_name GameData extends Resource` + `@export var id: String = ""` + `@export var display_name: String = ""`. No virtual methods, no polymorphic behavior — pure data contract.
- Create `assets/data/archetypes/enemy_archetypes.gd` per ADR-0011 §"Archetype constant set": `class_name EnemyArchetypes extends RefCounted`; 6 `const` strings; `MVP_SET` (3) + `ALL_SET` (6) `PackedStringArray`; `static func is_valid(s: String) -> bool` and `static func is_mvp(s: String) -> bool`.
- Create `assets/data/roles/class_roles.gd` per ADR-0011 §"Role constant set": `class_name ClassRoles extends RefCounted`; 6 `const` strings; `ALL_SET`; `static func is_valid(s: String) -> bool`.
- Use `RefCounted` (not `Object`) for the constant-set modules — safe base if `.new()` is ever accidentally called.
- Probe verification: before MVP ship, confirm `@abstract` on a Resource-derived base class behaves correctly on Godot 4.6.1 (one-time scratch test per ADR-0006 §Engine Compatibility). AC-DLS-01 implicitly covers the end-to-end path.
- Subclasses will not be written in this story — HeroClass / EnemyData / Biome / Dungeon / Floor schemas are authored under their own Core DB epics (ADR-0011 unblocks those). This story only provides the base class and the two constant-set modules so downstream stories can reference them.
- CI grep check (author in this story or the next validator story): `ResourceLoader.load("res://assets/data/...")` outside `src/core/data_registry.gd` must return zero hits; archetype and role string literals outside their constant-set files must return zero hits.

---

## Out of Scope

- Story 003: The synchronous boot scan that actually loads the `.tres` content under `assets/data/` subdirectories.
- Story 005: The per-type validator that enforces `EnemyArchetypes.is_valid` on `HeroClass.counter_archetype` / `EnemyData.archetype`, and `ClassRoles.is_valid` on `HeroClass.role`, and the snake_case-id regex.
- HeroClass / EnemyData / Biome / Dungeon / Floor subclass schema files — owned by the Core DB epics (ADR-0011).

---

## QA Test Cases

- **TR-data-loading-004**: `GameData` base class is `@abstract` and declares inherited fields
  - **Given**: The file `assets/data/_base/game_data.gd` exists.
  - **When**: The class is inspected.
  - **Then**: It carries the `@abstract` annotation; `class_name GameData`; `extends Resource`; declares `@export var id: String = ""` and `@export var display_name: String = ""` as the only fields.
  - **Edge cases**: Attempting to instantiate `GameData` directly at runtime (`GameData.new()`) is expected to fail or warn per 4.5+ `@abstract` semantics; a concrete subclass extending GameData must be able to load from a `.tres` file (behavior verified end-to-end in AC-DLS-01 / Story 003).

- **TR-data-loading-005**: Authoring convention — `id` is the inherited first field with snake_case values
  - **Given**: A subclass extending `GameData` (stub created in test fixture).
  - **When**: The subclass is loaded from a `.tres` fixture with `id = "class_warrior"`.
  - **Then**: `resource.id == "class_warrior"`; subclass does NOT redeclare `id` or `display_name` (inheritance-only).
  - **Edge cases**: Redeclaring `id` on a subclass is forbidden (`gamedata_inherited_field_redeclaration`) — Story 005's validator confirms snake_case regex `^[a-z][a-z0-9_]*$`; this story only verifies the inheritance contract.

- **EnemyArchetypes constant set is the single source of truth**
  - **Given**: The file `assets/data/archetypes/enemy_archetypes.gd` exists.
  - **When**: The module is loaded and inspected.
  - **Then**: `class_name EnemyArchetypes extends RefCounted`; `MVP_SET` contains exactly `["bruiser", "caster", "armored"]`; `ALL_SET` contains exactly the MVP three plus `["beast", "construct", "incorporeal"]`; `EnemyArchetypes.is_valid("bruiser") == true`; `EnemyArchetypes.is_valid("TANK") == false` (case-sensitive); `EnemyArchetypes.is_mvp("beast") == false`; `EnemyArchetypes.is_mvp("bruiser") == true`.
  - **Edge cases**: Unknown strings (`"flying"`, `""`, `"Bruiser"`) must all return `false` for both checks; case-sensitivity is load-bearing for ADR-0011 field validation.

- **ClassRoles constant set is the single source of truth**
  - **Given**: The file `assets/data/roles/class_roles.gd` exists.
  - **When**: The module is loaded and inspected.
  - **Then**: `class_name ClassRoles extends RefCounted`; `ALL_SET` contains exactly `["tank", "striker", "precision", "support", "ranged", "commander"]`; `ClassRoles.is_valid("tank") == true`; `ClassRoles.is_valid("healer") == false`.
  - **Edge cases**: Empty string, wrong case, V1.0-reserved typos all return `false`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/data_registry/gamedata_base_and_constant_sets_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload skeleton)
- **Unlocks**: Story 003, Story 005


## Completion Notes

**Completed**: 2026-04-24
**Criteria**: 2/2 passing
**Story Type**: Logic
**Test Evidence**: tests/unit/data_registry/gamedata_base_and_constant_sets_test.gd (6/6 pass)
**Deviations**: `const MVP_SET/ALL_SET = PackedStringArray([...])` changed to `const ... = Array[String]` — constructor calls aren't constant expressions in Godot 4.6. MEDIUM-risk engine verification still pending: `@abstract` keyword editor 'New Resource' UI probe on Godot 4.6.1.
**Code Review**: Skipped — review mode solo (per production/review-mode.txt)
**Next**: Sprint-close sequence (/smoke-check sprint → /team-qa sprint → /gate-check)
