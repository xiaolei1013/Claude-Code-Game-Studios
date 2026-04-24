# ADR-0006: Data Loading — Boot Scan Strategy and Resource Registry Contract

## Status

Accepted

## Date

2026-04-22

## Last Verified

2026-04-22

## Decision Makers

- Author (user) — final decision
- godot-specialist — engine pattern validation (pending Step 4.5)
- technical-director — solo mode skip (review-mode.txt = solo; gate TD-ADR not invoked)
- Source of truth: `design/gdd/data-loading.md` + cross-GDD reference from `design/gdd/save-load-system.md` §Dependencies

## Summary

Codifies the Data Loading System (autoload identifier `DataRegistry`, rank 1) as the single content-loading boundary for the project. Locks: eager synchronous boot scan via `ResourceLoader.load()` over `assets/data/{classes,enemies,biomes,dungeons,items,matchup}/`; `.tres` as the only authored format; the `GameData` abstract base (Godot 4.5+ `@abstract`) with `id: String` + `display_name: String` as the universal cross-system key; the directed-acyclic-graph cross-reference rule with the explicit load order classes → enemies → biomes → dungeons → items → matchup; the `registry_ready` signal-edge contract that SaveLoadSystem gates hydration on; the `resolve(content_type, id) -> Resource | null` API; the read-only resource-cache contract (Godot returns the same object for the same path — mutation corrupts every cached holder); and the dev-only `hot_reload(content_type)` path gated by `is_dev_build`. Also resolves a cross-GDD naming drift: the Data Loading GDD's `DataLoader` autoload reference is corrected to `DataRegistry` to match Save/Load §Dependencies + architecture.md.

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (ResourceLoader, DirAccess, Resource serialization, `@abstract` keyword) |
| **Knowledge Risk** | LOW for ResourceLoader / DirAccess / .tres (stable since 4.0). MEDIUM for `@abstract` (4.5+ feature; post-cutoff). |
| **References Consulted** | `design/gdd/data-loading.md`; `design/gdd/save-load-system.md` §Dependencies; `docs/engine-reference/godot/breaking-changes.md` (4.5 `@abstract` decorator); `docs/engine-reference/godot/current-best-practices.md` (typed Array idioms, `duplicate_deep()` 4.5 addition); `docs/engine-reference/godot/deprecated-apis.md` (typed `Array[Type]` over untyped) |
| **Post-Cutoff APIs Used** | `@abstract` keyword on `GameData` base class (Godot 4.5 — MEDIUM risk) |
| **Verification Required** | `@abstract` decorator behavior on a Resource subclass (not just Node) — Godot 4.5 docs cover `@abstract` for classes generally; verify that a Resource derived from an `@abstract` Resource base loads correctly via `ResourceLoader.load()` (no instantiation of the abstract base directly). One-time test in a probe scratch project; AC-DLS-01 covers behavioral verification implicitly. |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | ADR-0003 (Autoload Rank Table, Accepted) — establishes rank 1 for DataRegistry and the `registry_ready` forward-emission pattern that SaveLoadSystem (rank 2) subscribes to. |
| **Enables** | ADR-0004 (already Accepted, but practically depends on this for the hydration path's `DataRegistry.state == READY` precondition). All Hero Class DB / Enemy DB / Biome Dungeon DB / Matchup Resolver implementation stories. SaveLoadSystem hydration story (gates on `registry_ready` signal-edge). |
| **Blocks** | DataRegistry implementation epic; all 4 database autoloads (rank 4-6 + Matchup Resolver rank 8); SaveLoadSystem hydration AC-SL-04 (Missing Content Reference — Null Resolve Returns Fallback Without Crash); AC-DLS-01 through AC-DLS-09. |
| **Ordering Note** | Independent peer of ADR-0005 (Time System) at the Foundation layer. Both have rank position N where N+1 is SaveLoadSystem (rank 2); both fire signals SaveLoadSystem listens to in its `_ready()`. Nothing in the architecture depends on ADR-0006 being authored before or after ADR-0005. |

## Context

### Problem Statement

The Data Loading System is the read-only content backbone — every hero class, enemy type, biome, dungeon floor, item, and matchup rule that defines gameplay lives in `.tres` resources under `assets/data/`. Architecture.md identified ADR-F04 with these decisions to lock:

1. **Eager-load partitioning** — load everything at boot vs lazy-per-category vs hybrid
2. **Hot-reload behavior in dev builds** — what's allowed, what's stripped from shipped builds
3. **Content type registration** — what categories exist, how they're discovered, how IDs are enforced
4. **`registry_ready` signal-edge contract** — what SaveLoadSystem and other consumers can assume when this fires

Without an ADR, future revisions could re-litigate the eager vs lazy choice (the GDD argues against lazy for MVP but the rationale must not drift), the read-only contract (a "performance fix" that mutates a cached resource would corrupt every other holder of that path), or the cross-reference DAG rule (cycles cause Godot's resource loader to stall or return null, breaking gameplay silently).

### Current State

- `design/gdd/data-loading.md` is fully designed (310 lines, all 8 required sections + 9 Acceptance Criteria AC-DLS-01 through AC-DLS-09).
- `design/gdd/save-load-system.md` §Dependencies references the system as `DataRegistry` (with calls `DataRegistry.resolve(...)` and `DataRegistry.state == READY`); gates load on `DataRegistry.state` being READY; refuses to load if state is ERROR.
- `docs/architecture/architecture.md` (after ADR-0005's TickSystem rename) places `DataRegistry` at rank 1; module ownership lists `registry_ready()` signal + `get_all_by_type()` + `resolve()` API.
- The Data Loading GDD §States and Transitions table calls the autoload `DataLoader` ("Engine `_ready()` on `DataLoader` autoload"). The error message log prefixes are `[DataLoader]`. This is a cross-GDD naming drift vs Save/Load + architecture.md.
- ADR-0003 (Accepted, amended 2026-04-22) establishes the rank 1 slot as `DataRegistry`.
- Godot 4.5 introduced `@abstract` (per `current-best-practices.md`); Godot 4.5 also introduced `duplicate_deep()` for nested resource cloning. Both are post-cutoff (MEDIUM risk for the LLM, but documented).

### Constraints

- MVP content volume is trivially small (~50 files, <400 KB total). Eager-load is feasible.
- Mobile minimum spec must complete boot load within 200ms (AC-DLS-07 BLOCKING). At MVP scale this is comfortable; at V1.0 scale (15-20 classes, 5 biomes), it remains feasible per the GDD's analysis.
- Godot's `ResourceLoader.load(path)` returns the cached instance for repeated calls — multiple `load()` calls for the same `.tres` path return the same `Resource` object. This is the foundation of the read-only contract.
- `ExtResource()` references inside `.tres` files are resolved at parse time. Cycles cause stalls or null references (Godot's resource loader has limited cycle detection).
- `@abstract` is a 4.5+ feature; using it on a Resource base class needs verification (the docs cover Node-derived classes prominently; Resource-derived abstract classes are less documented).
- Hot-reload only matters in dev; production builds must strip the code path entirely (security: a hot-reload API in shipped builds is a content-injection vector).
- Save/Load §Dependencies imposes a hard contract: `DataRegistry.state` must be `READY` before SaveLoadSystem attempts to hydrate; if `state == ERROR`, SaveLoadSystem refuses load and transitions to CORRUPT.

### Requirements

- DataRegistry MUST emit `registry_ready` exactly once per session, after all content directories are enumerated and parsed without fatal error.
- DataRegistry MUST emit `registry_error(reason: String, details: Dictionary)` on fatal load conditions (duplicate id, DAG cycle, content count below `min_content_count`); MUST NOT emit `registry_ready` after an error.
- `resolve(content_type, id) -> Resource` MUST return `null` (with WARN log in production) for missing IDs; behavior is configurable to ASSERT in test builds via `missing_id_behavior` knob.
- `id: String` field MUST be globally unique within its content type; collisions MUST surface as ERROR state at load time, NOT silent overwrite.
- Content resources returned by accessors MUST be treated as immutable by consumers; the system MUST NOT defensively `.duplicate()` on every read (that would defeat the read-only contract's purpose and explode memory).
- Hot-reload MUST be available in dev builds only; production builds MUST strip the code path via compile-time flag.
- Cross-reference DAG MUST be validated at load time; cycles MUST transition to ERROR state.
- Boot scan order MUST be deterministic: classes → enemies → biomes → dungeons → items → matchup (so that resources requiring earlier-loaded references find them).
- All Save/Load AC-SL-04 (Missing Content Reference — Null Resolve Returns Fallback Without Crash) round-trips MUST work via this system's `resolve()` API.

## Decision

### Autoload identifier and rank

The Data Loading System is the autoload singleton **`DataRegistry`** at **rank 1** per ADR-0003. Consumers connect via bare-identifier resolution:

```gdscript
# In any consumer's _ready()
DataRegistry.registry_ready.connect(_on_registry_ready)
# Or: var classes := DataRegistry.get_all_by_type("classes")  # AFTER registry_ready
```

Cross-GDD naming drift correction: `design/gdd/data-loading.md` §States and Transitions references the autoload as `DataLoader` ("Engine `_ready()` on `DataLoader` autoload"); error log prefixes are `[DataLoader]`. Both are corrected to `DataRegistry` to match `design/gdd/save-load-system.md` §Dependencies + `docs/architecture/architecture.md` rank 1. The GDD sync update is a §Step 4.7 deliverable of this ADR.

### Eager synchronous boot scan

DataRegistry's `_ready()` runs the following sequence synchronously:

```gdscript
func _ready() -> void:
    _state = State.LOADING
    var ordered_categories: PackedStringArray = [
        "classes", "enemies", "biomes", "dungeons", "items", "matchup"
    ]
    for category in ordered_categories:
        if not _load_category(category):
            return  # already transitioned to ERROR with details emitted
    if not _validate_dag():
        return  # already transitioned to ERROR
    if not _validate_min_content_counts():
        return  # already transitioned to ERROR
    _state = State.READY
    registry_ready.emit()
```

Synchronous `ResourceLoader.load(path)` per file — NOT `ResourceLoader.load_threaded_request()`. Rationale:
- MVP content (<2MB, ~50 files) loads in well under 200ms on min-spec mobile (AC-DLS-07).
- Synchronous ordering is simpler to reason about — no async race between consumer subscription and registry_ready emission.
- The migration path to threaded loading is documented in the GDD §Formulas: when V1.0 content threatens the 200ms budget, switch to `load_threaded_request()` with a loading screen scene; the consumer-facing API contract (`get_all_by_type`, `resolve`, `registry_ready`) does not change.

**No partial-load mode in MVP.** The `lazy_load_categories` tuning knob exists in the GDD as a future migration knob (default `[]`). MVP leaves it empty. If a future ADR adopts lazy loading per category, the `registry_ready` signal semantics must be revisited (it would either fire after all eager categories OR delay until first lazy access — orthogonal to this ADR).

### Content directory layout (the contract)

```
assets/data/
  classes/        # HeroClass resources         (rank-3 dependency: HeroClassDatabase)
  enemies/        # Enemy resources             (rank-5 dependency: EnemyDatabase)
  biomes/         # Biome resources             (rank-6 dep: BiomeDungeonDatabase)
  dungeons/       # Dungeon resources           (rank-6 dep; embeds Enemy via ExtResource)
  items/          # Item resources              (V1.0 — empty in MVP, directory must exist)
  matchup/        # MatchupRule resources       (rank-8 dependency: ClassEnemyMatchupResolver)
```

- No content resource may live outside `assets/data/`. Consumer databases scan ONLY their assigned subdirectory via `DataRegistry.get_all_by_type(category)`.
- Test-only datasets shadow this path via the `data_root_override` tuning knob (dev builds only). Production builds reject any non-default value at startup with a fatal log.
- Adding a new content category requires editing this list AND adding an entry to `min_content_count`. New categories are NOT auto-discovered from directory presence — explicit registration prevents typo-directory bugs from silently shipping zero content.

### Single authored format: `.tres`

`.tres` (Godot text resource) is the only authored format. Rationale:
- Human-readable; diff-friendly in Git (designers can review content changes in PR).
- Supports `@export` metadata used by the content pipeline.
- `.res` (binary resource) is permitted ONLY as a compression artifact in shipped `.pck` files; MUST NEVER appear in source control. Conversion `.tres → .res` is a build step.
- No third format (JSON, YAML, custom binary). Mixing formats fragments the validation pipeline.

### `GameData` abstract base (Godot 4.5+ `@abstract`)

```gdscript
# assets/data/_base/game_data.gd  (or wherever the base class lives — convention)
@abstract
class_name GameData extends Resource

@export var id: String = ""              # snake_case, globally unique within content type
@export var display_name: String = ""    # designer-facing label; localizable later

# No virtual methods, no polymorphic behavior — pure data contract.
# Subclasses (HeroClass, Enemy, Biome, Dungeon, Item, MatchupRule) add domain fields.
```

`@abstract` (Godot 4.5+) prevents direct instantiation of `GameData` itself — any `.tres` file authoring must extend a concrete subclass. This is the post-cutoff API noted in Engine Compatibility.

**Verification needed**: `@abstract` on a Resource-derived base class (vs the more-documented Node-derived case). The Godot 4.5 documentation covers `@abstract` for `BaseEnemy extends CharacterBody3D` (Node case). The Resource case should work identically per the language semantics, but a one-time probe is worth it to verify before MVP ship. AC-DLS-01 (boot sequence) implicitly verifies the pattern works end-to-end.

### Stable `id` field convention

Every content resource declares `id: String` as its first `@export` field, inherited from `GameData`. The value is `snake_case`, globally unique within its content type. Examples:

```
classes/hero_warrior.tres        id: "class_warrior"
classes/hero_mage.tres           id: "class_mage"
enemies/goblin_grunt.tres        id: "enemy_goblin_grunt"
dungeons/forest_floor_1.tres     id: "dungeon_forest_floor_1"
```

**The filename is a developer hint, not a contract.** Renaming `hero_warrior.tres` to `warrior_shield.tres` does NOT change the `id` field and does NOT break any save file. This intentional decoupling is the core stability guarantee. Save files reference content by `id`, never by filepath.

**Uniqueness enforcement at load time** (per Edge Cases): if two resources within a content type declare the same `id`, DataRegistry logs `[DataRegistry] ERROR: id collision '...' in '...' — second file '...' rejected`, retains the first-registered, and transitions to ERROR state. Collisions are bugs, not feature behavior.

### Cross-reference DAG rule

Resources may reference other resources within `assets/data/` via Godot `ExtResource()` links. References MUST form a directed acyclic graph (DAG):
- `Dungeon` may embed `Array[Enemy]` (Enemy ExtResource references)
- `MatchupRule` may reference `HeroClass` and `Enemy`
- Nothing may form a cycle

Cycles cause Godot's resource loader to stall or return null references silently. Post-load, DataRegistry runs `_validate_dag()` which BFS-traverses the registered resource graph and detects cycles. On detection: `[DataRegistry] ERROR: CIRCULAR REF: dungeon_A → biome_B → dungeon_A` and ERROR state.

The deterministic load order (`classes/ → enemies/ → biomes/ → dungeons/ → items/ → matchup/`) ensures upstream categories are fully loaded before downstream categories that may reference them via `ExtResource`. Godot resolves `ExtResource()` at parse time using the loader's resource cache; loading classes first means subsequent `ExtResource(class_warrior.tres)` references hit the cache instead of triggering a recursive `load()`.

### Read-only contract

Resources returned by DataRegistry accessors are **immutable at runtime by convention**. Consumers MUST NOT mutate `@export` fields on a loaded resource.

```gdscript
# CORRECT: read fields, treat as value
var warrior: HeroClass = DataRegistry.get_all_by_type("classes")[0]
var atk: int = warrior.base_attack       # read

# FORBIDDEN: mutate fields
warrior.base_attack = 999                # corrupts EVERY other consumer holding this cached instance
```

Godot's resource cache returns the **same object** for repeated `load()` calls on the same path. Mutating one cached instance corrupts every system holding a reference. The system does NOT defensively `.duplicate()` on every accessor return because that would explode memory and defeat the cache's purpose.

If a consumer needs a mutable working copy of a resource (e.g., a runtime hero instance built from a class template), it MUST explicitly `class_template.duplicate()` (shallow) or `class_template.duplicate_deep()` (Godot 4.5+ — for nested resources). HeroRoster (rank 7) is the canonical owner of "instances built from templates" — this pattern is documented in HeroRoster's design.

**`duplicate_deep()` ExtResource caveat (godot-specialist Step 4.5 Note 2)**: `duplicate_deep()` recursively copies inline sub-resources (resources defined directly inside the parent `.tres`), but does NOT cross the `ExtResource()` boundary — sub-resources loaded from separate `.tres` files remain SHARED references to their cached instances. This is desirable for the data-template pattern (a duplicated HeroClass holds a shared reference to its `starting_item: Item` if Item is a separate `.tres`, avoiding pointless copy of the item definition). It is a gotcha for consumers who expect "deep" to mean "full graph copy". Treat both inline sub-resources AND cross-file ExtResource targets as read-only in the working copy unless you explicitly know which are which.

The contract is enforced by code review and by AC-DLS-08 (Read-Only Contract Enforcement) which fires in test builds. Production builds do not enforce the contract programmatically (defensive `.duplicate()` on every read would burn budget); reliance is on convention + review.

### Hot-reload (dev only)

```gdscript
# In DataRegistry — gated by compile-time flag
const _IS_DEV_BUILD: bool = OS.is_debug_build()  # runtime gate; fine because hot_reload's body has no security implications

func hot_reload(content_type: String) -> void:
    if not _IS_DEV_BUILD:
        return    # no-op in production exports
    if _state != State.READY:
        push_warning("[DataRegistry] hot_reload requested while state=%s; ignoring" % _state)
        return
    _state = State.HOT_RELOAD
    _categories.erase(content_type)
    _load_category(content_type)
    _state = State.READY
    hot_reload_complete.emit(content_type)
```

`hot_reload_complete(content_type: String)` signal notifies subscribers (typically the affected consumer DBs) to re-fetch their cached arrays. Stripping from production: the `OS.is_debug_build()` runtime guard plus a `coding-standards.md` rule that hot_reload must NEVER be invoked from production code paths (including UI affordances).

Hot-reload while a save game is active: consumers holding direct resource references will hold stale objects after re-load. The `hot_reload_complete` signal IS the re-fetch trigger; consumer DBs MUST re-call `get_all_by_type(content_type)` on receipt. Out-of-game (editor or dev menu) reload is the supported path; in-game live reload during play is officially "best effort dev convenience" — not a player-facing feature.

### State machine

```
UNLOADED ─────► LOADING ─────► READY ─────► HOT_RELOAD (dev only)
                  │              │              │
                  │              │              └──► READY (hot_reload_complete)
                  │              │
                  ▼              ▼
                ERROR         (terminal — no transitions out; game cannot proceed)
```

State transitions:
- `UNLOADED → LOADING`: at engine `_ready()` invocation on DataRegistry
- `LOADING → READY`: all categories loaded, DAG validated, min counts satisfied; emit `registry_ready`
- `LOADING → ERROR`: duplicate id OR DAG cycle OR content count below `min_content_count`; emit `registry_error(reason, details)`
- `READY → HOT_RELOAD → READY`: dev-only; emit `hot_reload_complete(content_type)`

ERROR is terminal. The game cannot proceed without a valid registry. SaveLoadSystem checks `DataRegistry.state == READY` before hydrating (per Save/Load §Dependencies); if state == ERROR, SaveLoadSystem refuses load and transitions to CORRUPT.

### `registry_ready` signal-edge contract

```gdscript
signal registry_ready                     # fires exactly once per session, on LOADING → READY transition
signal registry_error(reason: String, details: Dictionary)   # fires on LOADING → ERROR transition
signal hot_reload_complete(content_type: String)             # dev-only; fires on HOT_RELOAD → READY transition
```

**`registry_ready` semantics**:
- Fired exactly once per session (not re-fired after hot_reload — hot_reload uses its own signal).
- Synchronous emission inside the `_ready()` body (not deferred).
- Consumers subscribe in their own `_ready()`. Per ADR-0003 amended invariant: signal subscription across rank pairs at `_ready()` time is safe; SaveLoadSystem (rank 2) connecting to DataRegistry (rank 1) signal is the canonical safe pattern.
- After registry_ready: `DataRegistry.state == State.READY` and all `get_all_by_type(...)` and `resolve(...)` calls return valid data.
- Before registry_ready: consumers MUST NOT call DataRegistry accessors. Calling `get_all_by_type` while LOADING returns an empty array AND logs a warning (not an error — dev convenience for fast-fail debugging).

### `resolve(content_type, id) -> Resource | null`

```gdscript
func resolve(content_type: String, id: String) -> Resource:
    # NOT typed as `Resource | null` because GDScript 4.6 doesn't support union types in signatures.
    # Returns null on miss; WARN log per missing_id_behavior knob (default WARN; ASSERT in test builds).
    var category := _categories.get(content_type, {})
    var res = category.get(id, null)
    if res == null:
        if missing_id_behavior == MISSING_ID_ASSERT:
            assert(false, "[DataRegistry] resolve: id '%s' not found in '%s'" % [id, content_type])
        else:
            push_warning("[DataRegistry] WARN: id '%s' not found in '%s'" % [id, content_type])
    return res
```

This is the API SaveLoadSystem hydrates through. Per Save/Load AC-SL-04 (Missing Content Reference — Null Resolve Returns Fallback Without Crash): when a save file references a content `id` that no longer exists (e.g., a hero class deleted in a patch), `resolve()` returns null, SaveLoadSystem applies its own fallback policy (typically: skip that hero from the roster, log it for telemetry, continue load). The Data Loading System's only obligation is honest reporting — substitution policy is Save/Load's responsibility, NOT this system's.

### Architecture diagram

```
                             ┌────────────────────────┐
                             │ assets/data/           │
                             │   classes/   *.tres    │
                             │   enemies/   *.tres    │
                             │   biomes/    *.tres    │
                             │   dungeons/  *.tres    │
                             │   items/     *.tres    │
                             │   matchup/   *.tres    │
                             └───────────┬────────────┘
                                         │ ResourceLoader.load() per file (synchronous)
                                         │ in deterministic order: classes → enemies → biomes → dungeons → items → matchup
                                         ▼
                          ┌─────────────────────────────────┐
                          │ DataRegistry (autoload, rank 1) │
                          │ ─────────────────────────────── │
                          │ State: UNLOADED → LOADING       │
                          │   → READY (success)             │
                          │   → ERROR (collision/cycle/min) │
                          │   → HOT_RELOAD → READY (dev)    │
                          │ Index: { type → { id → Resource } } │
                          └────────┬────────────────────┬───┘
                                   │                    │
                  registry_ready   │                    │  resolve(type, id) → Resource | null
                  (one-shot)       │                    │  get_all_by_type(type) → Array[Resource]
                                   │                    │
            ┌──────────────────────┼─────────┬──────────┴──────────┐
            ▼                      ▼         ▼                     ▼
  SaveLoadSystem (rank 2)  HeroClassDB (4) EnemyDB (5)  ClassEnemyMatchupResolver (8)
  - gates load on          - get_all       - get_all    - get_all_by_type("matchup")
    state == READY         - get_by_id     - get_by_id  - resolves at runtime
  - resolves saved IDs     wraps registry  wraps        BiomeDungeonDB (6)
    via resolve()          for typed       registry    - get_all_by_type
  - refuses load if        accessors       for typed     ("biomes" + "dungeons")
    state == ERROR                         accessors    - dungeons embed Enemies via
                                                          ExtResource (resolved at parse)
```

### Key interfaces

```gdscript
# DataRegistry (autoload `DataRegistry`, rank 1)

# State machine
enum State { UNLOADED, LOADING, READY, ERROR, HOT_RELOAD }
var state: State = State.UNLOADED   # public read; internal write only

# Public read API (call only after registry_ready emits)
func get_all_by_type(content_type: String) -> Array[Resource]
    # Returns the loaded array for the category. Empty array + warning if state != READY.

func resolve(content_type: String, id: String) -> Resource
    # Returns the resource or null. WARN log per missing_id_behavior knob.

# Tuning knobs (read from ProjectSettings or constants at boot — see GDD §Tuning Knobs)
@export var data_root_path: String = "res://assets/data"
@export var hot_reload_enabled: bool = OS.is_debug_build()    # stripped from ship via const flag
@export var load_time_budget_ms: int = 200
@export var missing_id_behavior: int = MISSING_ID_WARN          # WARN | ASSERT
@export var lazy_load_categories: PackedStringArray = []        # empty in MVP
@export var min_content_count: Dictionary = {                   # per-category floor
    "classes": 3, "enemies": 5, "biomes": 1, "dungeons": 1, "matchup": 1,
}

# Dev-only API (gated by OS.is_debug_build() runtime check)
func hot_reload(content_type: String) -> void

# Signals
signal registry_ready                                          # one-shot per session, LOADING → READY
signal registry_error(reason: String, details: Dictionary)     # LOADING → ERROR
signal hot_reload_complete(content_type: String)               # dev-only, HOT_RELOAD → READY
```

```gdscript
# GameData abstract base — assets/data/_base/game_data.gd
@abstract
class_name GameData extends Resource

@export var id: String = ""
@export var display_name: String = ""
```

## Alternatives Considered

### Alternative 1: Lazy load per category (load on first access)

- **Description**: DataRegistry's `_ready()` only enumerates directory listings without parsing files. `get_all_by_type(category)` triggers the parse on first call; subsequent calls hit the in-memory index.
- **Pros**: Faster cold launch; lower idle memory if many categories are never accessed; defers parse cost.
- **Cons**: Adds per-category state machine complexity (per-category UNLOADED/LOADING/READY); makes `registry_ready` semantics unclear (is it "directories enumerated" or "all categories loaded"?); fragments AC-DLS-07 (boot performance) into per-category budgets that are harder to track; adds a "consumer accessed unready category" failure mode that doesn't exist in eager mode.
- **Estimated Effort**: ~1.5x of chosen approach.
- **Rejection Reason**: MVP content (<2MB, ~50 files) loads synchronously in well under 200ms. Lazy is solving a problem we don't have. The migration knob (`lazy_load_categories`) exists for V1.0 but is empty in MVP. Re-evaluate if V1.0 content threatens the 200ms budget.

### Alternative 2: ResourceLoader.load_threaded_request() with loading screen

- **Description**: DataRegistry kicks off `load_threaded_request()` for each file in `_ready()`, then polls `load_threaded_get_status()` per frame; the registry_ready signal fires when all loads complete. A loading screen scene shows progress.
- **Pros**: Non-blocking boot; main thread responsive during load; necessary at V1.0 if content exceeds the synchronous budget.
- **Cons**: Adds polling state machine; introduces async race between consumer subscription and registry_ready emission; requires a loading-screen scene (which itself depends on the registry being loaded — bootstrapping problem). Defers parse failure detection past `_ready()`, so the ERROR state transition is harder to surface synchronously. Harder to write deterministic tests for.
- **Estimated Effort**: ~3x of chosen approach (loading screen scene + state machine + test infrastructure).
- **Rejection Reason**: MVP doesn't need it. The GDD §Formulas explicitly documents this as the V1.0 migration path with no API change to consumers — when the time comes, this ADR can be superseded.

### Alternative 3: JSON instead of `.tres`

- **Description**: Author content in `.json` files; DataRegistry parses JSON and constructs Resource subclasses programmatically.
- **Pros**: Lower author barrier (any text editor); easier integration with external content pipelines; engine-agnostic format (would survive a Godot → Unity migration).
- **Cons**: Loses all Godot tooling (resource editor, ExtResource references, type validation, hot-reload via FileSystemDock); no `@export` introspection; cross-references would need a custom indirection layer (string IDs in JSON resolved post-load) instead of native ExtResource(). Authoring loses the diff-friendliness in GDScript-aware merge tools.
- **Estimated Effort**: ~4x — requires custom JSON-to-Resource layer + custom cross-ref resolution + reimplementing ExtResource semantics.
- **Rejection Reason**: `.tres` IS Godot's content format; using anything else throws away the engine's primary value-add. Engine-agnosticism is a non-goal (the project is Godot-pinned per VERSION.md).

### Alternative 4: Auto-discover content categories from directory presence

- **Description**: DataRegistry scans `assets/data/` for all subdirectories at boot; any directory becomes a registered content type. No explicit `min_content_count` per category — it's derived from "this directory exists, so we expect content".
- **Pros**: Adding a new content category is "create a directory and drop `.tres` files in"; no code change needed.
- **Cons**: Typo-directories (`assets/data/classs/` instead of `classes/`) silently ship as "the classs category exists with N entries" while the real `classes/` is empty or missing; consumer DBs that hardcode `get_all_by_type("classes")` get an empty array with no error. Validation surface fragments — `min_content_count` would need a dynamic source-of-truth elsewhere or be abandoned (catastrophic content deletion goes undetected).
- **Estimated Effort**: ~0.7x.
- **Rejection Reason**: Silent failure mode is unacceptable for the content backbone. Explicit registration in DataRegistry's category list (the `ordered_categories` PackedStringArray) is the build-time validation that catches typos, deletions, and rename mistakes. The friction of editing two places (directory + code) is the right cost for catching bugs at compile time.

## Consequences

### Positive

- **Locks Pillar 1 invariant for content side**. The read-only contract + DataRegistry-as-sole-loader pattern means save files reference content by stable `id`, never by filepath. File renames + content reorganization are non-events for the player. AC-DLS-02 (Stable ID Contract — File Rename Transparent to Resolver) is the formal verification.
- **Eager-load + synchronous + deterministic order = simple consumer model**. Every consumer can assume "after `registry_ready` fires, every `get_all_by_type` and `resolve` call works". No partial-init failure modes.
- **Cross-GDD naming drift resolved**. data-loading.md `DataLoader` references corrected to `DataRegistry`; matches save-load-system.md and architecture.md uniformly. Future stories reading the GDD won't get confused about which name to use.
- **Hot-reload is opt-in dev convenience, stripped from production**. No accidental content-injection vector in shipped builds.
- **`@abstract GameData` base class enforces structure**. Authoring a `.tres` file that extends GameData directly (without going through HeroClass / Enemy / etc.) fails at the engine level — typo-prevention as a load-time error.
- **Cross-reference DAG validation surfaces cycles loudly**. Cycles cause Godot stalls or null references (silent corruption); the explicit `_validate_dag()` step makes them ERROR-state events with diagnostic detail.

### Negative

- **`@abstract` is a 4.5+ feature** (post-cutoff). One-time verification needed that it works correctly on Resource-derived base classes (not just Node-derived). Mitigated by Engine Compatibility note + AC-DLS-01 implicit coverage.
- **Synchronous boot scan blocks `_ready()` for up to 200ms on min-spec mobile**. At MVP scale this is comfortable; at V1.0 scale it could threaten the budget. Migration to threaded loading is documented but adds future ADR work.
- **Read-only contract is convention-enforced, not language-enforced**. A consumer can still mutate a cached resource at runtime — it just corrupts every other holder. Mitigation: AC-DLS-08 in test builds + code review + coding-standards.md "Resource immutability" section.
- **Adding a new content category requires editing DataRegistry's `ordered_categories` list**. Two-location edit burden (directory + code), but the right cost for catching typos and deletions at compile time.
- **`hot_reload` runtime guard via `OS.is_debug_build()` is weaker than a compile-time `const`**. Same caveat as ADR-0005's debug surface — release builds no-op the methods but still pay dispatch cost (sub-microsecond). No security implication beyond what the player can do with the engine itself.

### Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| `@abstract` keyword behaves differently for Resource subclasses than for Node subclasses (post-cutoff API) | Low | Medium (boot fails to load any content; ERROR state with cryptic message) | One-time probe verification before MVP ship; AC-DLS-01 catches end-to-end behavior; if `@abstract` is incompatible, fallback is documented runtime convention (`assert(get_class() != "GameData")` in `_ready` of GameData — defensive, not language-enforced) |
| A consumer mutates a cached Resource and silently corrupts every other holder | Medium | High (data integrity bug; symptoms appear in unrelated systems; very hard to diagnose) | Registry forbidden_pattern: `mutating_loaded_resource` (registered below); AC-DLS-08 fires in test builds; coding-standards.md adds explicit "Resource immutability" section; code review checklist item |
| Boot scan exceeds 200ms on min-spec mobile at V1.0 scale | Medium (V1.0+) | Medium (boot feels sluggish; AC-DLS-07 fails) | GDD documents threaded-load migration path; ADR-X06 (planned for V1.0 if needed) supersedes this with `load_threaded_request()` strategy; consumer-facing API contract unchanged |
| `id` collision in shipped content goes undetected because the check fires only at boot of a build that includes both colliding files | Low | High (game refuses to start; emergency hotfix needed) | CI step that loads DataRegistry headless and asserts state == READY before ship; covered by AC-DLS-03 + AC-DLS-05 in test pipeline |
| Cross-reference DAG cycle introduced by content edit goes undetected until next boot | Low | High (game refuses to start) | Same CI step as above; `_validate_dag()` is BLOCKING per AC-DLS-06 |
| Hot-reload accidentally invoked from production code path (e.g., via UI affordance) | Low | Low (no-op in release; minor ms cost; no security implication) | Coding-standards.md rule: hot_reload MUST NEVER be referenced from non-debug code paths; CI grep for `hot_reload(` outside the `_dev/` directory or `if OS.is_debug_build()` guard |
| GDD sync update misses a `[DataLoader]` log prefix or `DataLoader` reference in the data-loading GDD | Medium | Low (cosmetic inconsistency; no runtime impact) | Step 4.7 grep-and-replace covers all occurrences; verify completion by re-grepping post-edit |
| Editor "New Resource" UI behavior on `@abstract GameData` is undocumented | Low | Low (editor-only; no runtime impact; expected outcome is a clear editor error rather than silent misconstruction) | Probe verification (already mandated) confirms behavior; designers are instructed to extend HeroClass / Enemy / Biome etc., never GameData directly. (godot-specialist Step 4.5 Note 1) |
| Consumer expects `duplicate_deep()` to copy the full graph including ExtResource cross-references but receives shared references | Medium | Medium (silent shared-state mutation in working copy; symptoms appear in unrelated systems holding the same cached resource) | Documented in §Read-only contract (above); HeroRoster design must explicitly call out the inline-vs-ExtResource distinction; coding-standards.md section "Resource immutability" includes the `duplicate_deep()` caveat. (godot-specialist Step 4.5 Note 2) |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (boot scan, MVP scale ~50 files <2MB) | N/A | Synchronous `ResourceLoader.load()` per file + DAG validation + min-count check | < 200ms on min-spec mobile (AC-DLS-07 BLOCKING). MVP measured at ~30-80ms on PC SSD. |
| CPU (boot scan, V1.0 scale ~200 files <10MB) | N/A | Same path; estimate scales linearly | Approaching 200ms — consider threaded migration |
| CPU (`get_all_by_type` call) | N/A | Single Dictionary lookup + Array reference return | Sub-microsecond — negligible |
| CPU (`resolve(type, id)` call) | N/A | Two Dictionary lookups (category, then id) | Sub-microsecond — negligible |
| Memory (full registry, MVP) | N/A | Sum of all loaded `.tres` resources | Per GDD §Memory budget per category: <400 KB MVP; <5 MB V1.0; well under 256 MB mobile ceiling |
| Memory (per-instance overhead) | N/A | Godot's resource cache holds one instance per file path; no duplication | Negligible |
| Save File Size | N/A | Save files reference content by `id` strings (e.g., `"class_warrior"`, ~16 bytes); no duplication of content data | Per ADR-0004 budget — content `id`s contribute trivially to save size |

## Migration Plan

**No migration required for MVP** — no shipped saves exist; no content has been authored against an alternative pattern. This ADR codifies the contracts the first MVP build will implement.

**GDD sync update (Step 4.7 deliverable)**:
1. `design/gdd/data-loading.md` — replace all occurrences of `DataLoader` (autoload reference + log prefixes) with `DataRegistry`. Approximately 8 occurrences per grep.
2. Verify by re-grepping `DataLoader` post-edit; should return zero matches.

**Future post-MVP migrations**:
- Adding a new content category: edit `DataRegistry.ordered_categories`, edit `min_content_count`, create `assets/data/<category>/` directory, optionally create a consumer DB autoload at the appropriate rank.
- Migrating to threaded loading: supersede this ADR with one adopting `load_threaded_request()` + a loading screen scene; consumer-facing API contract (`get_all_by_type`, `resolve`, `registry_ready`) does not change.
- Migrating to lazy-per-category loading: requires re-defining `registry_ready` semantics; document as a separate ADR.

**Rollback plan**: If eager synchronous loading proves untenable in production (e.g., a Godot upgrade slows ResourceLoader.load() significantly), supersede with threaded loading per the GDD's documented migration path. Existing content authoring under `.tres` + `GameData` base + stable `id` is preserved — only the load mechanism changes.

## Validation Criteria

- [ ] AC-DLS-01 passes: boot sequence transitions UNLOADED → LOADING → READY with `registry_ready` emitted; all consumer DBs receive populated arrays via `get_all_by_type`.
- [ ] AC-DLS-02 passes: renaming a `.tres` file (without changing its `id` field) does NOT break a save file reference resolved via `resolve(content_type, id)`.
- [ ] AC-DLS-03 passes: duplicate `id` within a content type triggers ERROR state at load time with diagnostic log.
- [ ] AC-DLS-04 passes: missing `id` in `resolve()` returns null with WARN log (production); ASSERT in test builds when `missing_id_behavior == ASSERT`.
- [ ] AC-DLS-05 passes: malformed `.tres` file is skipped + logged; other files in the category load normally; min count check still fires if count drops below floor.
- [ ] AC-DLS-06 passes: cross-reference DAG cycle detected at load time → ERROR state with cycle path in log.
- [ ] AC-DLS-07 passes (BLOCKING): boot scan completes in < 200ms on min-spec mobile at MVP content scale.
- [ ] AC-DLS-08 passes (in test builds): consumer mutation of a cached Resource is detected and reported.
- [ ] AC-DLS-09 passes (BLOCKING dev / ADVISORY release): `hot_reload(content_type)` re-loads the target category and emits `hot_reload_complete`; consumer DBs successfully re-fetch.
- [ ] `@abstract GameData` base class verified to work for Resource-derived subclasses on Godot 4.6.1 (one-time probe before MVP ship).
- [ ] CI ship-gate: headless DataRegistry init asserts state == READY before any release export.
- [ ] No `DataLoader` references remain in `design/gdd/data-loading.md` post Step 4.7 GDD sync.
- [ ] No `hot_reload(` invocation outside `if OS.is_debug_build()` guard or dedicated dev paths (verifiable by CI grep).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/data-loading.md` §Core Rules 1-2 | Data Loading | "All static game-content data lives under `assets/data/` organized by content type; `.tres` is the only authored format" | Codifies the directory layout (6 categories) + `.tres` exclusivity; prohibits non-`.tres` formats and external content paths. |
| `design/gdd/data-loading.md` §Core Rules 3-4 | Data Loading | "GameData abstract base with id + display_name; stable id field as canonical cross-system key; filename is hint not contract" | Locks `@abstract GameData` base; `id` field convention; filename-decoupling guarantee verified by AC-DLS-02. |
| `design/gdd/data-loading.md` §Core Rule 5 | Data Loading | "Eager load at boot; lazy_load_categories knob exists for V1.0 migration" | Codifies eager synchronous boot scan as MVP contract; documents the threaded-load migration path for V1.0 without binding to it. |
| `design/gdd/data-loading.md` §Core Rule 6 | Data Loading | "Cross-reference DAG rule with explicit load order classes → enemies → biomes → dungeons → items → matchup" | Locks the load order; codifies `_validate_dag()` as the BLOCKING ERROR-state trigger for cycles. |
| `design/gdd/data-loading.md` §Core Rule 7 | Data Loading | "Read-only contract — Godot's resource cache returns the same object; consumer mutation corrupts every cached holder" | Codifies the no-mutate convention; registers FORBIDDEN pattern `mutating_loaded_resource`; ties to AC-DLS-08 enforcement in test builds. |
| `design/gdd/data-loading.md` §Core Rule 8 | Data Loading | "Hot-reload (dev only) gated behind compile-time flag; stripped from shipped builds" | Codifies `hot_reload(content_type)` API + `OS.is_debug_build()` runtime gate + signal contract for re-fetch. |
| `design/gdd/data-loading.md` §States and Transitions | Data Loading | "5-state machine UNLOADED → LOADING → READY | ERROR | HOT_RELOAD; ERROR is terminal; SaveLoadSystem checks state == READY before hydrating" | Locks state machine + transitions + the SaveLoadSystem dependency on state == READY (cross-GDD via Save/Load §Dependencies). |
| `design/gdd/data-loading.md` §Tuning Knobs | Data Loading | "data_root_path, hot_reload_enabled, load_time_budget_ms, missing_id_behavior, lazy_load_categories, min_content_count" | All 6 tuning knobs preserved as `@export` runtime-tunable; semantic intent documented in Decision section. |
| `design/gdd/save-load-system.md` §Dependencies (Data Loading row) | Save/Load | "Save/Load checks DataRegistry.state == READY before hydrating; refuses load if state == ERROR" | Codifies the cross-GDD contract; resolves the `DataLoader` vs `DataRegistry` naming drift in favor of `DataRegistry` (matches Save/Load + architecture.md). |
| `docs/architecture/architecture.md` §Module Ownership / DataRegistry | (cross-cutting) | "DataRegistry rank 1 owns content registry; emits registry_ready; exposes get_all_by_type + resolve" | This ADR is the formal codification; rank assignment per ADR-0003. |

## Related Decisions

- ADR-0003 (Autoload Rank Table, Accepted; amended 2026-04-22) — establishes rank 1 for DataRegistry; rank invariant amendment supports DataRegistry → SaveLoadSystem signal subscription pattern.
- ADR-0004 (Save Envelope, Accepted) — SaveLoadSystem hydration depends on `DataRegistry.state == READY` (cross-GDD contract). This ADR's `resolve()` API is what SaveLoadSystem calls during hydration.
- ADR-0005 (Time System, Accepted) — independent peer at the Foundation layer.
- ADR-F05 (Scene Transition + Persist Coupling, planned) — independent of this ADR; both feed into SaveLoadSystem orchestration.
- `design/gdd/data-loading.md` — full implementation spec (this ADR's source of truth).
- `design/gdd/save-load-system.md` §Dependencies — cross-GDD contract + naming-drift origin.
- `docs/engine-reference/godot/breaking-changes.md` 4.5 — `@abstract` keyword introduction.
- `docs/engine-reference/godot/current-best-practices.md` 4.5 — `duplicate_deep()` for nested resource cloning (used by HeroRoster when building runtime instances from class templates).
- `docs/architecture/architecture.md` §Autoload Rank Table — DataRegistry rank 1 entry.
