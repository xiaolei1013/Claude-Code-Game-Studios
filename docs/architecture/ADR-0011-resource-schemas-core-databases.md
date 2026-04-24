# ADR-0011: Resource Schemas for HeroClass / EnemyData / Biome / Dungeon / Floor

## Status

Accepted (promoted Proposed → Accepted 2026-04-22d as the same-day follow-up to `/architecture-review 2026-04-22d` — no content change from the Proposed draft; sole dependency ADR-0006 was already Accepted. Authored 2026-04-22 to cover the top unwritten Required ADR flagged by `/architecture-review 2026-04-22c` as "ADR-C02: Resource schemas for HeroClass / Enemy / Biome / Dungeon / Floor `.tres` files"; unblocks 3 Core DB systems ~57 TRs across hero-class-db + enemy-db + biome-dungeon-db gap pools. Coverage crosses 75% threshold post-Accept.)

## Date

2026-04-22

## Last Verified

2026-04-22

## Decision Makers

- Author (user) — final decision
- godot-gdscript-specialist — Step 4.5 engine pattern validation (see §Specialist Review below)
- technical-director — SKIPPED (review-mode.txt = solo; gate TD-ADR not invoked per Director-Gates §TD-ADR)

## Summary

Locks the concrete `.tres` field schemas for the five `GameData` subclasses that have authoritative GDDs: `HeroClass`, `EnemyData`, `Biome`, `Dungeon`, `Floor`. ADR-0006 already established the shared abstract base (`@abstract class_name GameData extends Resource` with inherited `id: String` + `display_name: String`), the directory layout (`assets/data/{classes,enemies,biomes,dungeons,items,matchup}/`), the ordered-category load sequence, the DAG rule for `ExtResource` cross-references, and the read-only runtime contract. This ADR codifies the **subclass field sets** + **load-time validation semantics** (what constitutes a schema violation, and what action the DataRegistry takes on each). Items and MatchupRules are deferred to their respective GDDs + ADRs (ADR-C03 Audio consumes Item; ADR-X04 Recruitment consumes MatchupRule; neither GDD is authored).

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (Resource subclassing via `class_name X extends GameData`; `@export` typed fields including `Array[T]` and `Array[Dictionary]`; `ExtResource` cross-file references; 4.5+ `@abstract` inherited from ADR-0006's base) |
| **Knowledge Risk** | **LOW** — schema mechanics (`class_name ... extends GameData`, `@export var field_name: Type`, `Array[T]`, `ExtResource()`) are stable since Godot 4.0. The only post-cutoff dependency is the `@abstract` keyword on the base class, which is ADR-0006's responsibility and already catalogued (`autoload.md` Claim 3 [INCONCLUSIVE] for editor-UI hint rendering; base-class abstractness itself is stable). `ExtResource` DAG resolution semantics are covered by `docs/engine-reference/godot/breaking-changes.md` 4.4+ `duplicate_deep()` entry — ADR-C02's cross-file refs use shallow `ExtResource` links, which is the idiomatic 4.6 pattern. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/breaking-changes.md` (`@abstract` 4.5+; `duplicate_deep()` 4.4+); `docs/engine-reference/godot/deprecated-apis.md`; ADR-0006 §Decision (GameData base + directory layout + ordered_categories + DAG rule); ADR-0010 `Floor` opaque consumption; `design/gdd/data-loading.md` §§3-6; `design/gdd/hero-class-database.md` §C.1; `design/gdd/enemy-database.md` §C.1; `design/gdd/biome-dungeon-database.md` §C.1 |
| **Post-Cutoff APIs Used** | `@abstract` decorator (Godot 4.5+) — inherited from ADR-0006; no new post-cutoff API introduced by this ADR. `Array[Dictionary]` typed-array-of-untyped-Dictionary syntax (Godot 4.4+) used for `Floor.enemy_list`. |
| **Verification Required** | None new. `@abstract` verification is inherited from ADR-0006 (pre-MVP-ship probe). All schema primitives (`@export var`, `Array[T]`, `ExtResource`) are stable 4.0+ patterns with empirical coverage in the codebase. |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | ADR-0006 (Accepted — provides `@abstract GameData extends Resource` base class, `assets/data/` directory layout, `ordered_categories` deterministic load order `classes → enemies → biomes → dungeons → items → matchup`, DAG rule for cross-file `ExtResource` references, read-only runtime contract, stable snake_case `id: String` convention, schema-validation-at-load-time contract) |
| **Enables** | Hero Class DB implementation stories (TR-hero-class-db-001..024); Enemy DB implementation stories (TR-enemy-db-001..023); Biome-Dungeon DB implementation stories (TR-biome-dungeon-db-001..028); ADR-X02 (offline-replay snapshot schema — requires `Floor` type fully locked to carry `Floor.enemy_list` frozen-at-dispatch copy); ADR-0010 Combat implementation stories (`Floor` is the opaque parameter type; now fully locked). Story authoring across 3 Core DB systems (~57 TRs) |
| **Blocks** | Any `.tres` content-authoring story (no authoring tool can validate fields without schema); any Combat / Orchestrator implementation story that consumes `Floor`; any Formation Assignment story that reads `Biome.dominant_archetypes`; any Dungeon Run View story that reads `Biome.primary_palette_key` / `Floor.flavor_text`. Blocks `/create-epics layer: core` for the 3 Core DB systems until Accepted |
| **Ordering Note** | Author AFTER ADR-0006 (which is Accepted). Author BEFORE ADR-X02 (offline snapshot cites `Floor` schema). ADR-C01 (Economy) + ADR-X03 (Hero Roster) do NOT strictly depend on C02 (Economy reads `tier` generically; Roster stores `HeroInstance` referencing `HeroClass` by `id` only) but their story streams benefit from C02 landing first so implementation can cite concrete field names. |

## Context

### Problem Statement

ADR-0006 established the `@abstract GameData` base class, the directory layout, and the DataRegistry's read/load contract — but deferred the concrete subclass **field schemas** to the per-system GDDs. Those GDDs (hero-class-database.md Pass 1, enemy-database.md Pass 1, biome-dungeon-database.md Pass 1) now exist and authoritatively lock each resource's field set, types, and load-time validation rules.

Without an ADR codifying these schemas:

1. **No single authoritative citation for content-authoring tools.** Designer-facing authoring helpers, `.tres` linting, and CI schema checks need one source-of-truth reference; scattering across three GDDs creates the same drift problem that ADR-0003 Amendment #3 fixed for the DI seam.
2. **ADR-0010 consumes `Floor` as an opaque parameter type.** The Combat Resolver signature `compute_offline_batch(formation, floor: Floor, tick_budget, error_logger)` leaves `Floor` underspecified — Combat implementers need to know what `floor.enemy_list` returns (array of dicts per biome-dungeon-database.md §C.1, not array of `EnemyData` refs — a common mistake since enemy_list embeds `{enemy_id, count}` dicts, not inline Enemy resources).
3. **ADR-X02 (offline snapshot, to author next) needs locked `Floor` shape.** The offline-replay snapshot freezes `Floor.enemy_list` at dispatch time (per `dungeon-run-orchestrator.md` §J.1 + ADR-0009 §Offline replay zero-call invariant). The snapshot schema cannot finalize until `Floor.enemy_list`'s element type is locked.
4. **Load-time validation semantics are GDD-scattered.** Each GDD describes its own validation rules (archetype strings, status enums, floor-index uniqueness, DAG refs, boss-floor invariant). DataRegistry's implementation needs a single list of which checks fire, in what order, and what each check's failure action is (ERROR state vs push_warning vs silent-skip).
5. **Story authoring is blocked.** `/architecture-review 2026-04-22c` counted ~57 TRs across hero-class-db + enemy-db + biome-dungeon-db pools as gap — all trace back to "ADR-C02 not yet written."

### Current State

- ADR-0006 Accepted (2026-04-22). Base class locked. Directory layout locked. Ordered load locked. DAG rule locked. Read-only contract locked. `id` convention locked. Schema-validation-at-load-time contract locked as a policy; specific validators per subclass NOT enumerated.
- `design/gdd/hero-class-database.md` Pass 1 (approved) — 16-field HeroClass schema with field-by-field justification, role taxonomy (6 roles), enemy archetype taxonomy (3 MVP + 3 V1.0 constants), V1.0 stub rationale, 12 ACs.
- `design/gdd/enemy-database.md` Pass 1 (approved) — 13-field EnemyData schema, archetype distribution invariant, 8 MVP enemies with stat blocks, boss HP locked at 4818 per Combat GDD Pass 2B.
- `design/gdd/biome-dungeon-database.md` Pass 1 (approved) — three nested schemas (Biome 7 fields / Dungeon 4 fields / Floor 7 fields), Forest Reach MVP composition, archetype distribution validation matrix.
- `design/gdd/data-loading.md` Rule 3 shows GameData tree with node labeled `Enemy` — minor naming drift; enemy-database.md (authoritative) uses `class_name EnemyData extends GameData`. This ADR locks `EnemyData` and flags data-loading.md for a cosmetic sync.
- `tr-registry.yaml` has 24 TR-hero-class-db + 23 TR-enemy-db + 28 TR-biome-dungeon-db + 2 TR-data-loading entries routed to ADR-C02.
- No `.tres` files exist yet in `assets/data/`. This ADR is pure design codification.
- `docs/registry/architecture.yaml` has the GameData base + directory layout + DAG rule already registered under ADR-0006; this ADR adds field-schema interfaces, validation-rule forbidden-patterns, and the `content_reference_resolution_order` api_decision.

### Constraints

- **ADR-0006 inheritance (no redeclaration)**: Base class, directory layout, ordered_categories, DAG rule, and read-only runtime contract are ADR-0006's stances. This ADR re-uses them via `referenced_by` bumps on the existing registry entries, NOT by redeclaration. Duplication creates `/architecture-review` drift.
- **GDD authority**: Each subclass's field set is locked by its authoritative GDD. This ADR ratifies those field sets + adds the cross-subclass validation rules (DAG cross-refs, archetype-distribution invariant, boss-floor invariant) that span multiple GDDs.
- **No RNG, no runtime mutation, no polymorphism**: Subclasses are pure data records. `GameData` has no virtual methods; subclasses must not override. No subclass may declare class-scope mutable state (`var` without `@export`); all data is `@export`-exposed for `.tres` authoring.
- **Stable `id`, filename-as-hint**: Per ADR-0006 Rule 4. Renaming a `.tres` file must not change any resource's `id`. CI grep forbids filename-derived `id` assignment.
- **Save-file compatibility**: Per ADR-0006 + save-load-system.md Rule 37 — resource references in save files are serialized by `id: String` only. Adding, removing, or changing a field's persisted semantics requires ADR-0004's `schema_version` bump + migration pass. Additive fields with sensible defaults are the safe path.
- **Pillar 2 (every class feels distinct)**: Field set intentionally minimal — no `defense`, no `crit_chance`, no `ability_slot` for MVP. The minimality IS the design; ADR must not inflate the schema.
- **Pillar 3 (matchup IS the strategic verb)**: `counter_archetype: String` on HeroClass and `archetype: String` on EnemyData MUST come from the SAME enum constant set. Schema validation enforces.

### Requirements

- Each schema MUST declare exactly the field set specified in its authoritative GDD, with the specified GDScript types.
- Each field MUST be `@export`-decorated so it surfaces in the Godot editor for `.tres` authoring (no non-exported content fields).
- The archetype-string universe MUST be a single closed set of 6 constants (`bruiser`, `caster`, `armored`, `beast`, `construct`, `incorporeal`) declared in ONE location — `assets/data/archetypes/enemy_archetypes.gd` per hero-class-database.md §C.2. Both `HeroClass.counter_archetype` and `EnemyData.archetype` read from this set. Schema validator cross-checks.
- The role-string universe MUST be a single closed set of 6 constants (`tank`, `striker`, `precision`, `support`, `ranged`, `commander`) declared in ONE location — `assets/data/roles/class_roles.gd` (new file per this ADR). `HeroClass.role` reads from this set.
- The status-string universe for `Biome.status` MUST be exactly `{"active", "planned_v1"}`. Schema validator rejects any other value with `push_error` and transitions DataRegistry to ERROR state.
- `Floor.enemy_list` is `Array[Dictionary]` with each element exactly `{enemy_id: String, count: int}` — NOT `Array[EnemyData]` inline refs. Enemy refs are id-string so save-file references resolve via `DataRegistry.resolve("enemies", id)` and hot-reload-in-dev doesn't produce stale object references in Floor resources.
- `Dungeon.floors: Array[Floor]` is inline (embedded `ExtResource` links to separate `.tres` files or inline sub-resources — Godot authoring supports both). `Biome.dungeons: Array[Dungeon]` is inline likewise.
- The DAG cross-reference contract (ADR-0006 Rule 6) MUST hold: `Floor.enemy_list[].enemy_id` resolves against Enemy DB; `Dungeon.biome_id` resolves against Biome DB; `HeroClass.counter_archetype` resolves against the archetype constant set; `EnemyData.archetype` resolves against the archetype constant set. No back-references. No cycles.
- Load-time validators MUST run in a documented order (see §Load-Time Validation Semantics below) so failure messages are predictable.
- All five schemas MUST survive round-trip: `DataRegistry` loads a `.tres`; serializer reads every `@export` field; persists nothing mutable to save file (save file stores only consumer-owned state + id-references, per save-load-system.md).
- Validation failures MUST surface via the ADR-0006-defined channels: fatal (duplicate id, DAG cycle, below-minimum count, unresolvable cross-ref for required field) → `ERROR` state; non-fatal (soft-limit overrun on `flavor_text`, unknown-but-reserved status string) → `push_warning` and load-with-value-retained.

## Decision

### Base class (inherited from ADR-0006; not redeclared here)

```gdscript
# assets/data/game_data.gd (ADR-0006; cited here for clarity, NOT re-introduced)
@abstract
class_name GameData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
```

All five subclasses below extend `GameData` and inherit `id` + `display_name`. Neither field is redeclared in subclasses; subclasses add their domain fields only.

### Archetype constant set (new file — canonical)

```gdscript
# assets/data/archetypes/enemy_archetypes.gd
# extends RefCounted (not Object): RefCounted handles its own memory, so
# an accidental EnemyArchetypes.new() call in a test cannot leak a
# tracked engine instance. This is a pure static-constant module —
# there are no instance vars and no instance methods; .new() should
# never be called, but RefCounted is the safe base if it ever is.
class_name EnemyArchetypes
extends RefCounted

const BRUISER     := "bruiser"
const CASTER      := "caster"
const ARMORED     := "armored"
const BEAST       := "beast"        # V1.0
const CONSTRUCT   := "construct"    # V1.0
const INCORPOREAL := "incorporeal"  # V1.0

const MVP_SET: PackedStringArray = ["bruiser", "caster", "armored"]
const ALL_SET: PackedStringArray = ["bruiser", "caster", "armored", "beast", "construct", "incorporeal"]

static func is_valid(archetype: String) -> bool:
    return ALL_SET.has(archetype)

static func is_mvp(archetype: String) -> bool:
    return MVP_SET.has(archetype)
```

### Role constant set (new file — canonical)

```gdscript
# assets/data/roles/class_roles.gd
# extends RefCounted (not Object): same rationale as EnemyArchetypes —
# safe base for a static-constant module if .new() is ever accidentally called.
class_name ClassRoles
extends RefCounted

const TANK       := "tank"
const STRIKER    := "striker"
const PRECISION  := "precision"
const SUPPORT    := "support"      # V1.0 (Cleric)
const RANGED     := "ranged"       # V1.0 (Ranger)
const COMMANDER  := "commander"    # V1.0 (Tactician)

const ALL_SET: PackedStringArray = ["tank", "striker", "precision", "support", "ranged", "commander"]

static func is_valid(role: String) -> bool:
    return ALL_SET.has(role)
```

### 1. `HeroClass extends GameData` — 16 fields (14 new + 2 inherited)

```gdscript
# assets/data/game_classes/hero_class.gd
class_name HeroClass
extends GameData

# Inherited from GameData (NOT redeclared here):
#   @export var id: String = ""
#   @export var display_name: String = ""

@export var tier: int = 1
@export var role: String = ""                        # MUST be in ClassRoles.ALL_SET
@export var counter_archetype: String = ""           # MUST be in EnemyArchetypes.ALL_SET

@export_group("Stats — Base")
@export var base_attack: int = 0
@export var base_hp: int = 0
@export var base_speed: int = 0

@export_group("Stats — Per-Level Scaling")
@export var attack_per_level: int = 0
@export var hp_per_level: int = 0
@export var speed_per_level: int = 0

@export_group("Tick Output (Orchestrator forward-decl)")
@export var tick_output_contribution_l1: int = 0
@export var tick_output_per_level: int = 0

@export_group("Art")
@export var sprite_path: String = ""
@export var portrait_path: String = ""
@export var icon_path: String = ""

@export_group("Flavor")
@export var flavor_text: String = ""                 # soft limit 120 chars (push_warning if over)
```

**Field authority**: `design/gdd/hero-class-database.md` §C.1 (full justification), §C.3 (MVP stat values), §C.4 (V1.0 stub values), §G (tuning-knob safe ranges). Role taxonomy: §C.1 role table. Archetype reference: §C.2.

### 2. `EnemyData extends GameData` — 13 fields (11 new + 2 inherited)

**Class name locked**: `EnemyData` (per enemy-database.md §C.1). The `data-loading.md` Rule 3 tree-diagram label "Enemy" is a cosmetic drift fixed in lockstep with this ADR.

```gdscript
# assets/data/enemies/enemy_data.gd
class_name EnemyData
extends GameData

# Inherited from GameData (NOT redeclared):
#   @export var id: String = ""
#   @export var display_name: String = ""

@export var tier: int = 1                            # 1 | 2 | 3
@export var archetype: String = ""                   # MUST be in EnemyArchetypes.ALL_SET
@export var biome: String = ""                       # forward-compat; MVP: "forest_reach" only

@export_group("Stats")
@export var base_hp: int = 0
@export var base_attack: int = 0
@export var base_speed: int = 0

@export_group("Art")
@export var sprite_path: String = ""
@export var death_anim_key: String = "death"         # overridable for boss

@export_group("Flavor + Role")
@export var flavor_text: String = ""                 # soft limit 120 chars
@export var is_boss: bool = false                    # MVP: true ONLY on ancient_rootking (F5)
```

**Field authority**: `design/gdd/enemy-database.md` §C.1 (full field set), §C.3 (8 MVP stat blocks, HP calibration — note `ancient_rootking.base_hp = 4818` per Pass 2B, not 2200).

### 3. `Biome extends GameData` — 7 fields (5 new + 2 inherited)

```gdscript
# assets/data/biomes/biome.gd
class_name Biome
extends GameData

# Inherited from GameData (NOT redeclared):
#   @export var id: String = ""
#   @export var display_name: String = ""

@export var primary_palette_key: String = ""        # Art Bible reference; not runtime-validated
@export var dominant_archetypes: Array[String] = [] # each element MUST be in EnemyArchetypes.ALL_SET
@export var dungeons: Array[Dungeon] = []           # inline or ExtResource refs — MVP: exactly 1 dungeon per biome
@export var environmental_storytelling: Array[String] = []  # prop keys; ≥2 per Art Bible §4
@export var flavor_text: String = ""                # soft limit 200 chars
@export var status: String = "active"               # MUST be in {"active", "planned_v1"}
```

**Field authority**: `design/gdd/biome-dungeon-database.md` §C.1 Biome table.

### 4. `Dungeon extends GameData` — 4 fields (2 new + 2 inherited)

```gdscript
# assets/data/dungeons/dungeon.gd
class_name Dungeon
extends GameData

# Inherited from GameData (NOT redeclared):
#   @export var id: String = ""
#   @export var display_name: String = ""

@export var biome_id: String = ""                   # MUST resolve against a loaded Biome.id
@export var floors: Array[Floor] = []               # inline or ExtResource refs; ordered by floor_index
```

**Field authority**: `design/gdd/biome-dungeon-database.md` §C.1 Dungeon table.

### 5. `Floor extends GameData` — 7 fields (5 new + 2 inherited)

```gdscript
# assets/data/floors/floor.gd
class_name Floor
extends GameData

# Inherited from GameData (NOT redeclared):
#   @export var id: String = ""                    # convention: {biome_id}_f{floor_index}
#   @export var display_name: String = ""

@export var floor_index: int = 1                    # 1-based; unique within parent Dungeon; no gaps
@export var enemy_list: Array[Dictionary] = []      # each element EXACTLY {enemy_id: String, count: int}
@export var expected_clear_time_seconds: int = 0    # design target (QA pacing); NOT runtime-enforced
@export var is_boss_floor: bool = false             # true ⇒ enemy_list contains an EnemyData with is_boss=true
@export var flavor_text: String = ""                # soft limit 120 chars
```

**Field authority**: `design/gdd/biome-dungeon-database.md` §C.1 Floor table; §C.2 Forest Reach composition locks MVP values.

**`enemy_list: Array[Dictionary]` contract — key point**: this is `Array[Dictionary]`, NOT `Array[EnemyData]`. Each element is a small dict `{enemy_id: String, count: int}` where `enemy_id` is the stable `id` string that resolves via `DataRegistry.resolve("enemies", enemy_id)`. Rationale:

1. **Save-file reference stability**: Floor resources are static content; saved runs reference them via `Floor.id`. But the run snapshot freezes the enemy_list at dispatch time (per ADR-0009 + dungeon-run-orchestrator.md §J.1). Freezing stable id strings beats freezing RefCounted `EnemyData` references — a dev-build hot-reload of `enemies/*.tres` would otherwise leave stale instance pointers in frozen snapshots.
2. **DAG direction**: Floor → Enemy by id string is a looser coupling than Floor → Enemy by inline ref. Godot's `ExtResource` cycle detection is path-based; using id-strings across the Floor→Enemy boundary avoids accidental circularity if an Enemy resource ever needs a reverse Floor hint (future V1.0 concern).
3. **Content authoring**: `.tres` authoring of `[{enemy_id: "hollow_brute", count: 3}, {enemy_id: "glowmoth", count: 1}]` is more legible in diff review than an array of ExtResource `uid://` strings.

### Load-Time Validation Semantics

DataRegistry (ADR-0006) runs validators in this order during `LOADING` state, per content type. Failure action per validator is enumerated. The table is the implementation spec for `tests/ci/data_registry_schema_test.gd`.

#### Universal (all GameData subclasses)

| Validator | Failure Action | Notes |
|---|---|---|
| `id` non-empty | `ERROR` state | Per ADR-0006 Rule 4 |
| `id` snake_case (regex `^[a-z][a-z0-9_]*$`) | `ERROR` state | Prevents space/hyphen typos |
| `id` globally unique within content_type | `ERROR` state | Per ADR-0006 Rule 4 |
| `display_name` non-empty | `push_warning` + load | UI shows "<unnamed>" as fallback; does not block load |

#### HeroClass

| Validator | Failure Action |
|---|---|
| `tier ∈ {1, 2}` (3-5 reserved) | `ERROR` |
| `role ∈ ClassRoles.ALL_SET` | `ERROR` |
| `counter_archetype ∈ EnemyArchetypes.ALL_SET` | `ERROR` |
| `base_attack ≥ 0 AND base_hp ≥ 0 AND base_speed ≥ 0` | `ERROR` |
| `attack_per_level ≥ 0 AND hp_per_level ≥ 0 AND speed_per_level ≥ 0` | `ERROR` |
| `tick_output_contribution_l1 ≥ 0 AND tick_output_per_level ≥ 0` | `ERROR` |
| `sprite_path / portrait_path / icon_path` non-empty | `push_warning` (asset-review concern) |
| `flavor_text.length ≤ 120` | `push_warning` (UI truncates with ellipsis) |

#### EnemyData

| Validator | Failure Action |
|---|---|
| `tier ∈ {1, 2, 3}` | `ERROR` |
| `archetype ∈ EnemyArchetypes.ALL_SET` | `ERROR` |
| `biome` non-empty (MVP: must equal `"forest_reach"`; V1.0 relaxes) | `ERROR` |
| `base_hp > 0 AND base_attack ≥ 0 AND base_speed ≥ 0` | `ERROR` (zero-HP enemy cannot be killed; infinite combat) |
| `sprite_path / death_anim_key` non-empty | `push_warning` |
| `flavor_text.length ≤ 120` | `push_warning` |

#### Biome

| Validator | Failure Action |
|---|---|
| `status ∈ {"active", "planned_v1"}` | `ERROR` |
| Every `dominant_archetypes[i] ∈ EnemyArchetypes.ALL_SET` | `ERROR` |
| `environmental_storytelling.size() ≥ 2` | `push_warning` (Art Bible §4 soft requirement) |
| `flavor_text.length ≤ 200` | `push_warning` |
| `dungeons.size() ≥ 1` if `status == "active"` | `ERROR` |
| `dungeons.size() == 0` if `status == "planned_v1"` | `push_warning` (stubs should be empty per biome-dungeon-database.md §C.3) |

#### Dungeon

| Validator | Failure Action |
|---|---|
| `biome_id` resolves via `DataRegistry.resolve("biomes", biome_id) != null` | `ERROR` (DAG required ref) |
| `floors.size() ≥ 1` | `ERROR` |
| `floors` ordered strictly ascending by `floor_index` | `ERROR` |

#### Floor

| Validator | Failure Action |
|---|---|
| `floor_index ≥ 1` | `ERROR` |
| `floor_index` unique within parent Dungeon | `ERROR` |
| `enemy_list.size() ≥ 1` | `ERROR` |
| Every `enemy_list[i]` is Dictionary with keys exactly `{"enemy_id", "count"}` | `ERROR` |
| Every `enemy_list[i].enemy_id` resolves via `DataRegistry.resolve("enemies", enemy_id) != null` | `ERROR` (DAG required ref) |
| Every `enemy_list[i].count ≥ 1` | `ERROR` |
| `is_boss_floor == true` ⇒ ∃ `enemy_list[i]` where resolved EnemyData `.is_boss == true` | `ERROR` |
| `is_boss_floor == false` ⇒ ∀ `enemy_list[i]`, resolved EnemyData `.is_boss == false` | `ERROR` |
| `flavor_text.length ≤ 120` | `push_warning` |
| `expected_clear_time_seconds > 0` | `push_warning` (QA-pacing-only; no runtime enforcement) |

#### Cross-Type (run after per-type validators complete)

| Validator | Failure Action |
|---|---|
| **Archetype distribution invariant**: For all `Dungeon d` with `d.biome.status == "active"`, floors 1–3 (indices 1-3) MUST collectively cover all 3 MVP archetypes (`bruiser`, `caster`, `armored`) in their `enemy_list` enemy archetypes. Per enemy-database.md §C.2 lock. | `ERROR` |
| **Boss uniqueness**: Within a Dungeon, exactly one Floor has `is_boss_floor == true`. | `ERROR` |
| **HeroClass counter_archetype coverage (MVP)**: Every MVP (`tier==1`) HeroClass's `counter_archetype` MUST be in `EnemyArchetypes.MVP_SET`. | `ERROR` |

### Validation-ordering contract

Per-type validators run in the ADR-0006 `ordered_categories` sequence (`classes → enemies → biomes → dungeons → items → matchup`). Cross-type validators run AFTER all per-type validation completes — this ensures DAG refs are resolvable (e.g., Floor's `enemy_id` cross-check requires `enemies/` category fully loaded first). If any per-type validator transitions DataRegistry to `ERROR`, cross-type validation is skipped (fail-fast per ADR-0006).

### Architecture diagram

```
                      Godot ResourceLoader
                             │
                             │  enumerate per ordered_categories (ADR-0006)
                             ▼
        ┌──────────────────────────────────────────────────────┐
        │  DataRegistry (rank 1 autoload, ADR-0006)            │
        │                                                       │
        │  LOADING → parse .tres → per-type validators →        │
        │                          cross-type validators →      │
        │                          READY | ERROR                │
        └──────────────────────────────────────────────────────┘
                             │
                             │  (ADR-0011 locks subclass field schemas)
                             ▼
    @abstract GameData extends Resource       ← ADR-0006
        │          id: String                    (inherited by ALL below)
        │          display_name: String
        │
        ├── HeroClass        (16 fields; this ADR §1)
        │       counter_archetype ─────────────┐
        │       role ──────┐                   │
        │                  │                   │
        │        ClassRoles.ALL_SET            │
        │                                      │
        ├── EnemyData       (13 fields; this ADR §2)
        │       archetype ─────────────────────┤
        │       is_boss                        │
        │                                      │
        │                     EnemyArchetypes.ALL_SET
        │                     (canonical constant set —
        │                      HeroClass + EnemyData both
        │                      validate against same set)
        │
        ├── Biome           (7 fields; this ADR §3)
        │       dungeons: Array[Dungeon]  ─────┐
        │       dominant_archetypes ───────────┤
        │       status ∈ {"active","planned_v1"}
        │
        ├── Dungeon         (4 fields; this ADR §4)
        │       biome_id ──────→ (resolves via DataRegistry "biomes")
        │       floors: Array[Floor]  ─────────┐
        │                                      │
        ├── Floor           (7 fields; this ADR §5)
        │       floor_index (unique within Dungeon)
        │       enemy_list: Array[Dictionary]
        │            each {enemy_id: String,  ──→ (resolves via DataRegistry "enemies")
        │                  count: int}
        │       is_boss_floor (paired with EnemyData.is_boss)
        │
        ├── Item            (DEFERRED to ADR-C03; GDD not authored)
        └── MatchupRule     (DEFERRED to ADR-X04; GDD not authored)

   DAG direction (per ADR-0006 Rule 6):
     Biome   → Dungeon  → Floor  → enemy_id  → EnemyData
                                              ↓ (no back-ref)
     HeroClass → counter_archetype ─┐
                                    ▼
     EnemyData → archetype ──────→ EnemyArchetypes constant set (sink; no resolves)

   Consumers (read-only, per ADR-0006 Rule 7):
     HeroClassDatabase (rank 4)   → DataRegistry.get_all_by_type("classes")   → HeroClass[]
     EnemyDatabase     (rank 5)   → DataRegistry.get_all_by_type("enemies")   → EnemyData[]
     BiomeDungeonDatabase (rank 6)→ DataRegistry.get_all_by_type("biomes")    → Biome[]
                                  → DataRegistry.get_all_by_type("dungeons")  → Dungeon[]
                                  (floors accessed via Dungeon.floors)
     CombatResolver (ADR-0010)    → consumes Floor opaquely via injected arg
     FloorUnlockSystem (rank 10)  → reads Floor.floor_index, Floor.is_boss_floor
     DungeonRunOrchestrator (14)  → freezes Floor snapshot at dispatch
```

### Key Interfaces (all extend `GameData`; content authored as `.tres`)

Interfaces are the class name + field set above. DataRegistry exposes them via the ADR-0006 `get_all_by_type` / `resolve` API — no new DataRegistry methods added by this ADR.

## Alternatives Considered

### Alternative 1: Split into three per-DB ADRs (HeroClass / EnemyData / Biome+Dungeon+Floor)

- **Description**: ADR-C02a covers HeroClass + archetype constants + role constants. ADR-C02b covers EnemyData (reading C02a's archetype set). ADR-C02c covers Biome+Dungeon+Floor + the cross-type invariants.
- **Pros**: Smaller per-ADR scope; granular approval/revert; easier parallel review.
- **Cons**: The archetype constant set is cross-cutting (HeroClass.counter_archetype ↔ EnemyData.archetype use the same enum); splitting the ADR splits the constant set's authority. The archetype-distribution invariant lives in Enemy DB (C.2) but validates against Floor (biome-dungeon-database.md §C.4) — splitting puts the invariant's authority in one ADR and its validation code in another. The cross-type validators are the whole point of this ADR landing now; splitting forces them into either ADR-C02c (which would depend on C02a+C02b in a way that invites drift) or leaves them orphaned.
- **Rejection Reason**: The 5 schemas are tightly coupled by cross-refs (Floor.enemy_id → EnemyData; Dungeon.biome_id → Biome; HeroClass.counter_archetype ↔ EnemyData.archetype shared enum). Single ADR = single place where all invariants live. Per-review-report authoring order also listed them as a single slot.

### Alternative 2: Defer archetype/role constants to runtime constants (not declared in this ADR)

- **Description**: Leave `role` and `counter_archetype` as free `String` fields with NO constant-set validation at load time. Rely on downstream CI checks in Matchup Resolver / Recruitment to catch typos.
- **Pros**: Simpler schema; adding a new role/archetype in V1.0 needs zero ADR edit.
- **Cons**: Typo safety: `"tank"` vs `"tnak"` is caught at runtime on a live save, not at build time. Hero-class-database.md §C.1 says "role is a closed enum in the design. In the .tres file it is a String field, not an `@export_enum`. This is intentional: a hard enum prevents adding roles without a code change, which would block future classes. The tradeoff is that typos are possible. Mitigation: the Data Loading System should validate `role` against the known list at load time and `push_warning` on an unrecognized value." — the GDD explicitly asks for the load-time validator this ADR provides. Relying on downstream DB validation means each consumer re-implements its own check; constant set centralizes the authority.
- **Rejection Reason**: The GDDs explicitly request load-time validation. Typo risk is high enough (6 archetypes × MVP+V1 sets across two fields on two different classes) that the constant-set file + DataRegistry validator is the right safety floor. Adding a V1.0 archetype/role still requires ONE file edit (`enemy_archetypes.gd` or `class_roles.gd`) + V1.0 schema bump tracked in that pass's ADR — the ADR-editable-enum friction is not meaningfully different from editing an `@export_enum` GDScript list.

### Alternative 3: Use `@export_enum` GDScript annotation instead of constant-set + string validator

- **Description**: Declare `@export_enum("tank", "striker", "precision", "support", "ranged", "commander") var role: int = 0` on HeroClass. Godot editor shows a dropdown; `role` is persisted as int index.
- **Pros**: Strongest possible editor-UX: dropdown-only, impossible to typo. No custom validator needed.
- **Cons**: The persisted value is an int index, not a string. Reordering the enum changes every existing `.tres` file's meaning silently (if the author moves `"tank"` from index 0 to index 3, every Warrior.tres now claims role=0 which is now `"striker"`). The Matchup Resolver / Recruitment / UI would need to map int→string for logging, display, and save-file storage — re-introducing a string as the canonical representation. save-load-system.md TR-save-load-037 requires resource references to serialize by stable id STRING only; enum-int would need a separate string-conversion layer that the constant-set approach already provides natively.
- **Rejection Reason**: String is the canonical cross-system key (per ADR-0006 Rule 4 for `id`; same principle applies to `role` / `archetype`). `@export_enum` trades string-stability for dropdown-UX; the tradeoff is wrong for content that saves references to roles and archetypes in player save files.

### Alternative 4: Inline `EnemyData` references in `Floor.enemy_list` instead of id-string dicts

- **Description**: `@export var enemy_list: Array[Dictionary]` → `@export var enemy_list: Array[EnemyListEntry]` where `EnemyListEntry extends RefCounted { enemy: EnemyData; count: int }`. Or even simpler: `@export var enemies: Array[EnemyData]` with a parallel `@export var counts: Array[int]`.
- **Pros**: Direct `EnemyData` ref — no `resolve()` round-trip at consume time. Type-safe in editor (drag-and-drop only valid EnemyData resources).
- **Cons**: Dev-build hot-reload of `enemies/*.tres` would leave Floor resources holding stale `EnemyData` instance pointers — the ADR-0006 `hot_reload_complete(content_type)` signal notifies consumers to re-fetch, but Floor resources are data, not consumers; they can't re-fetch. Dungeon snapshots (per ADR-0010 + ADR-X02) freeze Floor state at dispatch time — freezing stale instance pointers would produce undefined behavior on long offline replays where `enemies/*.tres` was hot-reloaded between dispatch and replay. save-load-system.md TR-save-load-037 requires id-string serialization; inline refs force a translate step at persist time (add a `to_save_dict()` on EnemyListEntry that converts to id strings — every load would need the reverse). The simplicity claim is illusory.
- **Rejection Reason**: Save-file stability + hot-reload safety. `Array[Dictionary]` with `{enemy_id: String, count: int}` matches the GDD contract exactly (biome-dungeon-database.md §C.1 Floor field table) and matches ADR-0009's offline-snapshot pattern (freeze stable strings, resolve at consume time).

### Alternative 5: Single monolithic `GameContent` resource holding all game data

- **Description**: One `.tres` file at the top — e.g., `assets/data/game_content.tres` — with `Array[HeroClass]`, `Array[EnemyData]`, `Array[Biome]` fields inline. No per-subdirectory enumeration.
- **Pros**: Simpler DataRegistry implementation (one `load` call, no directory scan).
- **Cons**: Every content edit locks one giant file — conflicts with data-loading.md Rule 1 (directory structure), Rule 2 (`.tres` diff-friendly), ADR-0006 ordered_categories + explicit registration forbidden pattern. Content-authoring workflow (Godot inspector on individual resources) breaks down when every change is a single 500-KB resource. Hot-reload granularity becomes file-scope instead of category-scope.
- **Rejection Reason**: Contradicts ADR-0006 at multiple stances. Non-starter — would require superseding ADR-0006.

## Consequences

### Positive

- **Cross-system archetype safety**: Single `EnemyArchetypes` constant set means `HeroClass.counter_archetype` and `EnemyData.archetype` can never diverge. Typos caught at load time, not at first save after deploy.
- **Content authoring legibility**: Every content field is `@export`-decorated → Godot inspector shows each field with its type, grouping, and default. `.tres` diffs in Git are field-by-field readable.
- **Load-time validation enumerated**: DataRegistry implementation has a precise spec for what checks fire, in what order, with what failure action. `tests/ci/data_registry_schema_test.gd` can drive ERROR-state + push_warning coverage directly from this ADR's tables.
- **ADR-0010 fully unblocked**: `Floor` is now a concrete type. Combat implementers have exactly one authoritative reference for `floor.enemy_list`'s element shape (`Array[Dictionary]` of `{enemy_id: String, count: int}`).
- **ADR-X02 ready to author**: Offline-replay snapshot schema can now finalize — `snapshot.frozen_floor_enemy_list: Array[Dictionary]` mirrors Floor's shape; `snapshot.frozen_floor_id: String` + `snapshot.frozen_enemy_ids: PackedStringArray` both reference stable ids.
- **Save-file stability**: All cross-resource references serialize by id-string (per ADR-0006 Rule 4 + this ADR's §Floor.enemy_list contract). Renaming a `.tres` filename or hot-reloading a category does not invalidate any player's save.
- **V1.0 runway clean**: Adding Cleric / Ranger / Tactician classes requires zero schema change (same field set, tier=2). Adding Sunken Ruins / Ember Cavern / Thornwood Depths / Arcane Spire biomes requires zero schema change (same field set, status="planned_v1" → flip to "active" at V1.0 land). New archetype (e.g., "incorporeal") requires a one-line edit to `EnemyArchetypes.ALL_SET`.
- **Pillar-3 structural guarantee**: The cross-type archetype-distribution invariant (F1-F3 cover all 3 MVP archetypes) is CI-enforced, not review-enforced. Content designer cannot accidentally ship a dungeon that breaks the Pillar 3 matchup-is-the-verb intent.

### Negative

- **Two new constant files introduced**: `assets/data/archetypes/enemy_archetypes.gd` + `assets/data/roles/class_roles.gd`. Both are `class_name X extends Object` with const + static helpers — small cost. Mitigation: documented as load-time contracts; no V1.0-breaking if they need to grow.
- **Schema changes require ADR supersession**: Adding a field (e.g., `HeroClass.defense: int` for V1.0 combat depth) requires an ADR that supersedes this one + Save/Load schema_version bump. This is the intended cost — schema is load-bearing for save-file compatibility.
- **`Floor.enemy_list` is `Array[Dictionary]`, not a typed array**: Type checker cannot catch a malformed `{enemy_id: int, count: "foo"}` entry at authoring time. Mitigation: load-time validator catches all such errors with `ERROR` state + precise error messages; `tests/integration/content/` fixtures cover the error paths.
- **`Array[Dictionary]` is NOT inspector-editable in Godot 4.6**: the Godot editor renders `Array[Dictionary]` fields as an array of generic Variant elements with no dict-element editor — content authors cannot visually inspect or edit individual `{enemy_id, count}` entries from the inspector. Floor `.tres` authoring is effectively a hand-editing workflow (edit the `.tres` text file directly, or use `yaml`-style frontmatter per the biome-dungeon-database.md §C.2 composition snippets). A future custom `EditorInspectorPlugin` story can add per-element editing UI without changing the serialized schema; tracked as a V1.0 content-authoring-quality-of-life item, not an MVP blocker (MVP's 5 Forest Reach floors are hand-authored once and rarely edited). Typed-dictionary syntax (`Array[Dictionary[StringName, Variant]]`, 4.4+) was considered but REJECTED because it would force typed-key discipline across all callers and the mixed-type-value case (`enemy_id: String + count: int`) is awkward to express; `Array[Dictionary]` is the correct schema choice, with the inspector-UX limitation as a documented tradeoff.
- **6 static "planned_v1" enum values still declared**: `BEAST`, `CONSTRUCT`, `INCORPOREAL` in `EnemyArchetypes`; `SUPPORT`, `RANGED`, `COMMANDER` in `ClassRoles` — used by V1.0 stubs that MVP builds carry but filter. This is intentional forward-compatibility; MVP still loads the V1.0 stubs to validate the schema covers them (per hero-class-database.md AC H-09).
- **`data-loading.md` Rule 3 carries cosmetic drift**: tree diagram labels the enemy subclass `Enemy`; this ADR locks `EnemyData`. Flagged for a sync-in-lockstep edit (see §GDD Sync Check below).

### Neutral

- `Biome.dungeons: Array[Dungeon]` and `Dungeon.floors: Array[Floor]` are **inline** — each element is either an inline sub-resource or an `ExtResource` link to a separate `.tres` file. Godot authoring supports both forms and DataRegistry treats them identically post-load. Content authors choose per-resource based on size.
- Tier bounds differ by subclass: `HeroClass.tier ∈ {1, 2}` (tiers 3-5 reserved); `EnemyData.tier ∈ {1, 2, 3}` (per enemy-database.md §C.3 which uses 3 tiers). Not a conflict — they index into different Economy constants (`BASE_RECRUIT[class_tier]` vs `BASE_KILL[enemy_tier]`); just a schema asymmetry that reflects domain difference.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| A V1.0 ADR adds a new archetype (`"beast"`) to `EnemyArchetypes.MVP_SET` by mistake, believing it's an MVP archetype | Low | Medium (matchup-distribution invariant starts enforcing "beast" coverage on floors, failing the MVP Forest Reach dungeon schema at load time) | `EnemyArchetypes.MVP_SET` has a clear comment "MVP archetypes only — V1.0 additions MUST go to ALL_SET only"; CI test asserts MVP_SET size is exactly 3 |
| Content author manually edits a `.tres` file and changes `id` to match the filename (violates ADR-0006 Rule 4's "filename is hint, not contract") | Medium | High (save files referencing the old id silently break on next load) | Forbidden pattern `filename_as_id` already registered under ADR-0006 (`docs/registry/architecture.yaml`); CI lint pass runs at build time. The `referenced_by` list on that stance gets bumped by this ADR. |
| `Floor.enemy_list` dictionary structure changes subtly (e.g., adds a `boss_override: bool` key) and existing `.tres` files load without the key | Medium | Medium (Godot's dict parse ignores missing keys; downstream consumer reads undefined value) | Schema validator requires keys exactly `{"enemy_id", "count"}` — additional keys produce `push_warning`. Any new key requires ADR supersession + Save/Load schema_version bump. |
| `expected_clear_time_seconds` is misinterpreted as runtime enforcement (Orchestrator reads it and kills a run that exceeds target) | Low | Medium (Pillar 1 violation — player's run-progress stolen by a pacing QA knob) | Biome-dungeon-database.md §C.1 Floor table explicitly says "design target, NOT runtime enforcement". This ADR's §Floor schema comment repeats the warning. Registry forbidden pattern `expected_clear_time_seconds_as_runtime_gate` added. |
| `Dungeon.biome_id` holds an empty string or stale id from a deleted Biome | Low | Medium (Dungeon loads but has no biome; Dungeon Run View can't resolve palette) | Load-time validator requires `biome_id` resolves via `DataRegistry.resolve("biomes", biome_id)`. Fails with `ERROR` state if unresolvable — surfaces the bad content at build time, not at player's first run. |
| Godot ResourceLoader circular detection fails on a content cycle the GDD didn't anticipate (e.g., V1.0 introduces a reverse Enemy→Floor hint field) | Low | High (cycle → loader stalls or returns null → DataRegistry stuck in LOADING) | ADR-0006 Rule 6 (DAG rule) already registered as forbidden_pattern `content_circular_reference`. This ADR's §Floor.enemy_list uses id-strings (loose coupling) specifically to avoid reverse-ref cycles. V1.0 additions require an ADR revisiting the DAG. |
| `HeroClass.counter_archetype` points to a V1.0 archetype (e.g., `"beast"`) for an MVP tier-1 class by authoring error | Low | Medium (MVP playable but matchup always false for that class; player silently under-paid) | Cross-type validator: every `tier==1` HeroClass's `counter_archetype` MUST be in `MVP_SET`. `ERROR` state on violation. |
| Content authoring tool (future) generates `Array[Dictionary]` entries with non-String `enemy_id` values (e.g., `StringName` vs `String`) | Medium | Medium (validator is type-strict; legitimate content fails load) | Schema validator accepts both `String` and `StringName` for `enemy_id` via `typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME`, then normalizes to String before resolve. Documented in the CI test. |

## GDD Requirements Addressed

| GDD Document | Requirement | How This ADR Addresses It |
|---|---|---|
| `design/gdd/hero-class-database.md` §C.1 | 16-field HeroClass schema with types + descriptions | §1 `HeroClass extends GameData` — identical field set with `@export` annotations + grouping |
| `design/gdd/hero-class-database.md` §C.1 Role taxonomy | 6-role closed enum validated at load | §Role constant set `class_roles.gd` + HeroClass `role` validator |
| `design/gdd/hero-class-database.md` §C.2 Enemy Archetype Taxonomy | 6-archetype closed constant set (3 MVP + 3 V1.0); `EnemyArchetypes` GDScript constant file | §Archetype constant set `enemy_archetypes.gd` — verbatim |
| `design/gdd/hero-class-database.md` H-01..H-12 ACs | All 12 ACs traceable to either load-time validators or schema field declarations | §Load-Time Validation Semantics HeroClass table + §Cross-Type validators |
| `design/gdd/enemy-database.md` §C.1 | 13-field EnemyData schema with types + descriptions | §2 `EnemyData extends GameData` — identical field set |
| `design/gdd/enemy-database.md` §C.2 Archetype distribution invariant | F1-F3 must cover all 3 MVP archetypes; F4-F5 single-archetype allowed | §Cross-Type validator `Archetype distribution invariant` — verbatim invariant |
| `design/gdd/enemy-database.md` §C.3 | 8 MVP enemies with stat blocks including `ancient_rootking.base_hp = 4818` per Pass 2B | Schema accommodates any non-negative stats; §2 field-set allows the authored values |
| `design/gdd/biome-dungeon-database.md` §C.1 Biome schema | 7 fields (id, display_name, primary_palette_key, dominant_archetypes, dungeons, environmental_storytelling, flavor_text, status) | §3 `Biome extends GameData` — identical field set |
| `design/gdd/biome-dungeon-database.md` §C.1 Dungeon schema | 4 fields (id, display_name, biome_id, floors) | §4 `Dungeon extends GameData` — identical field set |
| `design/gdd/biome-dungeon-database.md` §C.1 Floor schema | 7 fields (id, floor_index, display_name, enemy_list, expected_clear_time_seconds, is_boss_floor, flavor_text); `enemy_list` is `Array[Dictionary]` of `{enemy_id, count}` | §5 `Floor extends GameData` — identical field set + explicit rationale for `Array[Dictionary]` vs alternatives |
| `design/gdd/biome-dungeon-database.md` §C.2 Forest Reach composition | F1 enemy_list, F2 enemy_list, ..., F5 boss floor; `ancient_rootking` on F5 is the only boss | §Cross-Type validators enforce: boss-uniqueness-within-Dungeon, is_boss_floor↔EnemyData.is_boss parity |
| `design/gdd/biome-dungeon-database.md` §C.5 Validation contract | Schema validation at load time: enemy_list non-empty, all enemy_id strings resolve, floor_index unique, is_boss_floor↔is_boss parity, status ∈ {active, planned_v1} | §Load-Time Validation Semantics Floor + Biome tables — verbatim |
| `design/gdd/data-loading.md` Rule 3 — GameData @abstract base | Locked by ADR-0006; this ADR is the subclass layer | Inherited via `extends GameData`; not redeclared |
| `design/gdd/data-loading.md` Rule 4 — Stable snake_case `id` | Locked by ADR-0006 + inherited | §Universal validator table |
| `design/gdd/data-loading.md` Rule 6 — DAG contract | Locked by ADR-0006 + inherited | §Load-Time Validation Semantics cross-ref validators |
| `design/gdd/data-loading.md` Rule 7 — Read-only runtime | Locked by ADR-0006 + inherited | All fields `@export`; no runtime setters; mutation is ADR-0006 forbidden_pattern territory |
| `design/gdd/save-load-system.md` TR-save-load-037 | Resource references serialize by stable id String only | §Floor.enemy_list `Array[Dictionary]` with `enemy_id: String` element — matches contract |
| `docs/architecture/ADR-0010-combat-resolver-snapshot-and-parity.md` | `Floor` type consumed opaquely by `CombatResolver.compute_offline_batch(formation, floor: Floor, tick_budget, error_logger)` | §5 `Floor` schema fully locks the opaque parameter type; ADR-0010's `referenced_by` in registry gets bumped |
| `docs/architecture/ADR-0009-matchup-resolver-di-and-majority-threshold.md` | Offline-replay `matched_archetypes` frozen at dispatch | §Floor.enemy_list id-string contract enables freezing archetypes as strings; snapshot cites Floor fields |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (load time — per-type validators, MVP content) | N/A | <10ms total across all 5 subclasses (MVP: 3 classes + 8 enemies + 1 biome + 1 dungeon + 5 floors = 18 resource files) | ADR-0006 registered `boot_scan_time` budget — 200ms BLOCKING on min-spec mobile; validation is <5% of that |
| CPU (load time — cross-type validators, MVP) | N/A | <1ms (4 validators × ~3-5 resources checked each) | Negligible |
| Memory (per resource) | N/A | HeroClass ~200 bytes (16 fields, mostly ints + short strings); EnemyData ~150 bytes; Biome ~300 bytes (with inline dungeons); Dungeon ~50 bytes; Floor ~200 bytes (with enemy_list dicts) | ADR-0006 registered `total_loaded_memory` budget; MVP content well under 400 KB total |
| Memory (archetype + role constant sets) | N/A | ~200 bytes (12 const strings × ~10 chars + 2 PackedStringArray) | Negligible |

**No new performance budget registered.** All costs fit inside ADR-0006's existing `boot_scan_time` + `total_loaded_memory` budgets.

## Migration Plan

**No migration needed.** No content resources exist yet. When the first content-authoring story lands:

1. Create `assets/data/archetypes/enemy_archetypes.gd` per §Archetype constant set.
2. Create `assets/data/roles/class_roles.gd` per §Role constant set.
3. Create `assets/data/game_classes/hero_class.gd` declaring `class_name HeroClass extends GameData` per §1 field set.
4. Create `assets/data/enemies/enemy_data.gd` declaring `class_name EnemyData extends GameData` per §2 field set.
5. Create `assets/data/biomes/biome.gd`, `assets/data/dungeons/dungeon.gd`, `assets/data/floors/floor.gd` per §3-5 field sets.
6. Add `tests/ci/data_registry_schema_test.gd` implementing all §Load-Time Validation Semantics validators + per-table failure-action assertions.
7. Create MVP content `.tres` files driven by the authored GDDs:
   - `assets/data/game_classes/warrior.tres`, `mage.tres`, `rogue.tres` (+ 3 V1.0 stubs per hero-class-database.md §C.4)
   - `assets/data/enemies/hollow_brute.tres`, ..., `ancient_rootking.tres` (8 per enemy-database.md §C.3)
   - `assets/data/biomes/forest_reach.tres` (1 MVP + 4 V1.0 stubs per biome-dungeon-database.md §C.3)
   - `assets/data/dungeons/forest_reach_dungeon_01.tres`
   - `assets/data/floors/forest_reach_f1.tres`..`forest_reach_f5.tres`
8. DataRegistry's `LOADING` state runs all §Load-Time Validation Semantics validators on each `.tres` load.

**Rollback plan**: If post-MVP authoring discovers a field needs to be added or changed (e.g., `HeroClass.defense: int` for V1.0 combat depth), the fix is a superseding ADR + Save/Load schema_version bump + migration pass in SaveLoadSystem's `MIGRATION` state (per save-load-system.md Rule 7). This ADR's core shape (`GameData` base, `@export` field sets, constant-set validators, Array-of-dict `enemy_list`) is not expected to require rollback.

## Validation Criteria

- [ ] `assets/data/archetypes/enemy_archetypes.gd` exists with exactly one `class_name EnemyArchetypes extends Object`; declares 6 const strings + `MVP_SET` + `ALL_SET` + `is_valid(s)` + `is_mvp(s)` static methods.
- [ ] `assets/data/roles/class_roles.gd` exists with exactly one `class_name ClassRoles extends Object`; declares 6 const strings + `ALL_SET` + `is_valid(s)` static method.
- [ ] `EnemyArchetypes.MVP_SET.size() == 3` (CI test asserts); `EnemyArchetypes.ALL_SET.size() == 6`.
- [ ] `hero_class.gd`, `enemy_data.gd`, `biome.gd`, `dungeon.gd`, `floor.gd` each declare `class_name X extends GameData`; no subclass redeclares `id` or `display_name`.
- [ ] Every field in §1-§5 is `@export`-decorated (grep returns presence); no non-export content fields.
- [ ] `tests/ci/data_registry_schema_test.gd` implements every validator in §Load-Time Validation Semantics; per-validator assertion covers both pass + fail paths.
- [ ] CI asserts `HeroClass.counter_archetype` validator is `EnemyArchetypes.is_valid()` (reads the constant set, does NOT hardcode the strings).
- [ ] CI asserts `EnemyData.archetype` validator is `EnemyArchetypes.is_valid()` (same source of truth — single location changes propagate).
- [ ] CI asserts archetype-distribution invariant: for MVP Forest Reach dungeon, floors 1-3 collectively have enemy archetypes covering `["bruiser", "caster", "armored"]`.
- [ ] CI asserts boss-uniqueness: exactly one floor in forest_reach_dungeon_01 has `is_boss_floor == true` (F5) and its resolved enemy_list's EnemyData `.is_boss == true`.
- [ ] CI asserts `Floor.enemy_list` element validator: each dict has exactly `{"enemy_id", "count"}` keys (no extras, no missing).
- [ ] Integration test: load all MVP `.tres` content; DataRegistry transitions UNLOADED → LOADING → READY; emits `registry_ready`.
- [ ] Integration test: mutate `warrior.tres` to set `counter_archetype = "made_up_archetype"`; DataRegistry transitions to ERROR state with an error message naming the field + resource.
- [ ] Integration test: mutate `forest_reach_f5.tres` to set `is_boss_floor = false`; DataRegistry transitions to ERROR (cross-type validator catches parity break).
- [ ] Save-file round-trip: a Hero stored with `class_id: "warrior"` loads against the locked schema; `DataRegistry.resolve("classes", "warrior")` returns the same instance as fresh boot.
- [ ] Hot-reload (dev only): `hot_reload("enemies")` with a modified `hollow_brute.tres` re-enters READY; Floor.enemy_list `enemy_id` strings still resolve (tests the id-string vs inline-ref rationale).

## Specialist Review

godot-gdscript-specialist **APPROVE-WITH-NOTES** (2026-04-22). No mechanically-wrong GDScript claims; all core patterns idiomatic for Godot 4.6 Resource schemas + static-constant modules. Ten notes issued across the review scope; two load-bearing (folded in-place), eight forward-looking (retained for implementation-story awareness):

- **NOTE #4 (folded — load-bearing)** — §Negative Consequences expanded: `Array[Dictionary]` is not inspector-editable in Godot 4.6 (no dict-element editor UI); Floor `.tres` authoring is a hand-editing workflow. Custom `EditorInspectorPlugin` tracked as V1.0 content-authoring-quality-of-life item (not MVP blocker; 5 Forest Reach floors are authored once). `Array[Dictionary[StringName, Variant]]` typed-dictionary alternative considered + rejected (forces typed-key discipline across all callers; mixed-type-value is awkward).
- **NOTE #5 (folded — load-bearing)** — §Archetype constant set + §Role constant set: changed `extends Object` → `extends RefCounted`. Rationale inline comment added: RefCounted handles its own memory, so an accidental `EnemyArchetypes.new()` call in a test cannot leak a tracked engine instance. Pure static-constant modules should extend RefCounted (or drop `extends` entirely — both produce equivalent 4.x behavior).
- **NOTE #1 (no change)** — `class_name X extends GameData` subclass pattern confirmed idiomatic 4.0+; `@abstract` on `GameData` does not affect subclass instantiation. `[gd_resource type="HeroClass"]` header in `.tres` resolves to concrete subclass.
- **NOTE #2 (no change)** — `@export_group` confirmed working on Resource subclasses; groups render in declaration order; inherited `id` + `display_name` surface as implicit "ungrouped" section before subclass groups.
- **NOTE #3 (no change)** — `Array[Dungeon]` / `Array[Floor]` typed-array exports confirmed valid; inline sub-resources vs `ExtResource` links treated identically post-load (matches ADR-0006 Note 2 on `duplicate_deep()` boundary).
- **NOTE #6 (no change)** — `@export` inheritance confirmed: subclasses inherit the annotation from `GameData`; inspector surfaces `id` + `display_name` without redeclaration. The ADR's "subclasses do NOT redeclare" requirement is correct.
- **NOTE #7 (no change)** — Default values (`0`, `""`, `[]`, `false`) idiomatic. `Array[T] = []` does share a class-level literal, but Godot initializes a fresh array per-resource instance at `.tres` load time — no shared-mutable-default hazard.
- **NOTE #8 (no change)** — `push_error`/ERROR + `push_warning`/load-with-value pattern is correct for load-time validation. `_validate_property()` (editor hook) rejected as inappropriate — fires at editor property-set time, not DataRegistry load; not suitable for cross-resource invariants. `@tool` approach would catch single-field invariants at author-time but adds `@tool` complexity to all 5 resource scripts — DataRegistry's LOADING-state validator table is the cleaner separation.
- **NOTE #9 (no change)** — `static func is_valid(s: String) -> bool` idiomatic for exposing validators on a pure-constant class.
- **NOTE #10a (forward-looking)** — Content authors will see plain text inputs (not dropdowns) for `role` / `counter_archetype` / `archetype` / `status` String fields in the inspector. Custom `EditorInspectorPlugin` can add dropdowns without changing serialized type. Tracked as content-authoring-UX story (not MVP blocker; `.tres` linting at load time catches typos).
- **NOTE #10b (forward-looking)** — `PackedStringArray.has(stringname)` does NOT coerce `StringName` → `String`. Typed-GDScript callers to `EnemyArchetypes.is_valid(archetype: String)` get auto-coercion; untyped callers or `call("is_valid", &"bruiser")` via dynamic dispatch may miss. Implementation stories should document: callers pass `String`, not `StringName`.
- **NOTE #10c (forward-looking)** — `StringName` vs `String` micro-optimization not needed at MVP scale (18 content resources, 6 archetype strings, compared at load time + occasionally at matchup-resolve). `StringName` optimization applies to thousands-of-compares-per-frame cases (animation keys); content-DB fields are not that.

**Inherited findings not re-proven by this review**: `@abstract` keyword verification (ADR-0006 deferred to pre-MVP-ship probe); `.tres` round-trip semantics with `ExtResource` refs (ADR-0006 stable-since-4.0 baseline); `duplicate_deep()` cross-file boundary behavior (ADR-0006 Note 2, folded there). This ADR composes verified primitives; no novel engine mechanism introduced.

## Related Decisions

- **ADR-0006 (Accepted)** — locks `@abstract GameData extends Resource` base, directory layout, ordered_categories, DAG rule, read-only contract, stable `id` convention, schema-validation-at-load-time contract. This ADR adds the subclass layer + field-schema validators.
- **ADR-0010 (Accepted 2026-04-22c)** — consumes `Floor` opaquely in Combat signatures. This ADR locks the opaque type fully.
- **ADR-0009 (Accepted 2026-04-22b)** — `MatchupResult.matched_archetypes: Array[String]` archetype-strings come from this ADR's `EnemyArchetypes` constant set.
- **ADR-X02 (to author — offline batch chunking + snapshot schema)** — will cite this ADR's `Floor.enemy_list` shape as the snapshot-freeze target; offline-replay snapshot stores frozen Floor id-refs + enemy-id strings.
- **ADR-C01 (to author — Economy state shape)** — reads `HeroClass.tier` for `BASE_RECRUIT[tier]` lookup, `EnemyData.tier` for `BASE_KILL[tier]` lookup. Does not require this ADR's Accepted-state to start authoring (Economy reads tier as int, not as schema).
- **ADR-X03 (to author — Hero Roster mutation)** — `HeroInstance` stores `class_id: String` referencing `HeroClass.id`. This ADR locks the `id` contract.
- **ADR-C03 (deferred — Audio)** — will cover `Item extends GameData` schema when Audio GDD is authored.
- **ADR-X04 (deferred — Recruitment)** — will cover `MatchupRule extends GameData` schema when Recruitment GDD is authored.
- `design/gdd/hero-class-database.md` — authoritative GDD for §1 (HeroClass schema).
- `design/gdd/enemy-database.md` — authoritative GDD for §2 (EnemyData schema).
- `design/gdd/biome-dungeon-database.md` — authoritative GDD for §3-5 (Biome/Dungeon/Floor schemas).
- `design/gdd/data-loading.md` Rule 3 — carries cosmetic drift (`Enemy` label); this ADR flags for sync (see §GDD Sync Check in authoring pass).
- `docs/architecture/architecture.md` §Module Ownership Map — HeroClassDatabase / EnemyDatabase / BiomeDungeonDatabase rows reference the subclass types this ADR locks.
- `docs/architecture/tr-registry.yaml` TR-hero-class-db-001..024 / TR-enemy-db-001..023 / TR-biome-dungeon-db-001..028 — the 75 TRs this ADR codifies structurally.
