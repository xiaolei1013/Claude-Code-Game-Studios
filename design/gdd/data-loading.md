# Data Loading System

> **Status**: Designed (pending independent review)
> **Author**: systems-designer + qa-lead + main session
> **Last Updated**: 2026-04-18
> **Implements Pillar**: Indirect — Pillar 2 (Every Class Feels Distinct) via data-driven class/enemy iteration; Pillar 4 (HD-2D Pixel Pride) via enabling content variety
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

---

## Overview

The Data Loading System is the read-only content backbone of *Lantern Guild*. It enumerates every `.tres` resource under `assets/data/` at boot, registers each under a stable `id: String` field, and provides typed accessors to downstream databases (Hero Class DB, Enemy DB, Biome & Dungeon DB) plus a resolver API (`resolve(content_type, id)`) that Save/Load calls to translate save-file references back into live resource instances.

This is pure infrastructure. It does not own mutable player state (Save/Load does). It does not own content authoring (designers own that via Godot's resource editor). Its job is to be the single, deterministic pattern by which the game reads its content — so that adding a hero class, editing an enemy's stats, or renaming a resource file never requires special-case handling anywhere else in the codebase.

The design is deliberately minimal: eager-load everything at boot (content volume is tiny — <400 KB MVP, <5 MB V1.0), enforce stable `id` fields as the cross-system key, treat Godot's built-in resource cache as the authoritative runtime store, and fail loudly on authoring errors (duplicate ids, malformed files) rather than silently substituting defaults.

---

## Player Fantasy

This system has no direct player fantasy — players never see it. The indirect fantasy it serves: **"every hero class in my roster feels hand-made, and the designers can change one without breaking another."**

Data-driven content is what makes Pillar 2 (Every Class Feels Distinct) affordable at indie scope. If every class required bespoke code to define, the MVP's 3-class roster and V1.0's 15-class ambition would compete for the same engineering time. This system ensures adding a class is a content task (one `.tres` file), not an engineering task. The cozy-curation fantasy depends on it.

---

## Detailed Design

### Core Rules

**1. Content directory structure.** All static game-content data lives under `assets/data/`, organized by content type:

```
assets/data/
  classes/        # HeroClass resources
  enemies/        # Enemy resources
  biomes/         # Biome resources
  dungeons/       # Dungeon resources
  items/          # Item resources
  matchup/        # MatchupRule resources (class-vs-enemy modifiers)
```

Each subdirectory is self-contained. No content resource may live outside `assets/data/`. Test-only datasets may shadow this path via the `data_root_override` tuning knob (dev builds only).

**2. Single authoring format.** `.tres` (Godot text resource) is the only authored format. It is human-readable, diff-friendly in Git, and supports `@export` metadata used by the content pipeline. `.res` (binary resource) is permitted only as a compression artifact in shipped `.pck` files and must never appear in source control. Conversion from `.tres` to `.res` is a build step, not a hand-edit step.

**3. Resource base class strategy.** All content resources extend a shared abstract base `GameData` (using Godot 4.5+ `@abstract`):

```
GameData          # @abstract — id: String, display_name: String
  ├── HeroClass
  ├── EnemyData    # literal class name — per enemy-database.md §C.1 + ADR-0011
  ├── Biome
  ├── Dungeon
  ├── Item         # deferred — no GDD yet (blocks ADR-C03 Audio)
  └── MatchupRule  # deferred — no GDD yet (blocks ADR-X04 Recruitment)
```

`GameData` provides the two fields every consumer and the Save/Load resolver need: `id` and `display_name`. Concrete subclasses add their domain fields. No polymorphic runtime behavior lives in `GameData` — it is a data contract, not a base service class. *(Verify `@abstract` keyword availability against `docs/engine-reference/godot/breaking-changes.md` before story work — it is a 4.5+ feature.)*

**4. Stable `id` field convention.** Every content resource declares `id: String` as its first `@export` field. The value is `snake_case`, globally unique within its content type (uniqueness is enforced at load time — see Edge Cases). `id` is the canonical cross-system key: save files reference heroes by class `id`, dungeon runs reference enemies by `id`, and the Save/Load resolver calls `resolve(content_type, id)` to convert saved strings back to live resource instances.

The filename of a `.tres` file is a hint to developers, not a contract. Renaming `hero_warrior.tres` to `warrior_shield.tres` does not change the `id` field and does not break any save file. This intentional decoupling is the core stability guarantee.

**5. Eager load at boot.** All content directories are enumerated and all resources parsed during the `LOADING` state, before any consumer accesses the registry. Rationale: MVP content is trivially small (<2 MB); idle game sessions begin with the Return-to-App screen, which needs hero and dungeon data immediately; eager loading gives a consistent, deterministic READY state that consumers can depend on without null-checks. Lazy loading per category is available as a future tuning knob if V1.0 content volume demands it.

**6. Cross-reference DAG rule.** Resources may reference other resources within `assets/data/` via Godot `ExtResource()` links (e.g., a `Dungeon` resource embedding an `Array[Floor]` which references `EnemyData` via id-string per ADR-0011 §5). These references must form a directed acyclic graph (DAG). Specifically: `Dungeon` may reference `EnemyData` (transitively via `Floor.enemy_list[].enemy_id` id-string resolution — NOT inline `ExtResource` ref, per ADR-0011 rationale for hot-reload safety); `MatchupRule` may reference `HeroClass` and `EnemyData`; nothing may form a cycle. Cycles cause Godot's resource loader to stall or return null references. Where ordering must be explicit, directories are loaded in the sequence: `classes/ → enemies/ → biomes/ → dungeons/ → items/ → matchup/`.

**7. Read-only contract.** Resources returned by this system are immutable at runtime. Consumers call accessors (`get_class_by_id`, `get_all_enemies`, `resolve`) and treat the returned resource as a value. No consumer may write to `@export` fields on a loaded resource. Violation would corrupt every other consumer holding the same cached instance (Godot's resource cache returns the same object for the same path).

**8. Hot-reload (dev builds only).** In development builds, the system exposes `hot_reload(content_type: String)` which re-enumerates the target directory and re-registers its resources. This is gated behind a compile-time flag (`is_dev_build`) and stripped from shipped builds. Hot-reload transitions the system through `HOT_RELOAD` state and back to `READY`.

### States and Transitions

| State | Description |
|-------|-------------|
| `UNLOADED` | Initial state before boot. No content is accessible. |
| `LOADING` | Enumerating `assets/data/` subdirectories and parsing `.tres` files. Consumers must not be initialized during this state. |
| `READY` | All content registered. Accessors return valid resources. Normal runtime state. |
| `ERROR` | Fatal load condition detected (duplicate id, circular ref, content count below minimum). Consumers remain uninitialized. |
| `HOT_RELOAD` | Dev-only transient state. System is re-enumerating one content directory. |

| From | To | Trigger | Boundary Action |
|------|----|---------|-----------------|
| `UNLOADED` | `LOADING` | Engine `_ready()` on `DataRegistry` autoload | Begin directory enumeration; block all consumer access |
| `LOADING` | `READY` | All directories enumerated, no fatal errors | Emit `registry_ready` signal; unblock consumer access |
| `LOADING` | `ERROR` | Duplicate id, DAG cycle, or content count below minimum | Emit `registry_error(reason, details)`; game cannot proceed |
| `READY` | `HOT_RELOAD` | Dev call to `hot_reload(content_type)` | Clear target category index; begin re-enumeration |
| `HOT_RELOAD` | `READY` | Re-enumeration complete | Re-register category; emit `hot_reload_complete(content_type)` |

### Interactions with Other Systems

**Hero Class Database.** Receives the full `Array[HeroClass]` via `get_all_by_type("classes")` after `registry_ready`. Exposes `get_class_by_id(id: String) -> HeroClass` and `get_all_classes() -> Array[HeroClass]`. The Class DB is a thin indexed wrapper around this system's output — it does not re-parse files.

**Enemy Database.** Same pattern. Receives `Array[EnemyData]`, exposes `get_enemy_by_id(id: String) -> EnemyData` and `get_all_enemies() -> Array[EnemyData]`. (Class name `EnemyData` per enemy-database.md §C.1 + ADR-0011.)

**Biome & Dungeon Database.** Receives `Array[Biome]` and `Array[Dungeon]`. Because `Dungeon` resources embed enemy references via `ExtResource`, Godot resolves those links at parse time; the Dungeon DB receives fully hydrated objects.

**Save/Load System.** Calls the resolver API to convert `id: String` values stored in save files back to live resource instances. The resolver contract:

```
resolve(content_type: String, id: String) -> Resource | null
```

`content_type` is one of `"classes"`, `"enemies"`, `"biomes"`, `"dungeons"`, `"items"`, `"matchup"`. Returns the live resource if found, `null` if not. Deciding what to do when `null` is returned is Save/Load's responsibility — this system's only obligation is honest reporting, not fallback policy.

---

## Formulas

There are no mathematical formulas in this system. It is an I/O pipeline: enumerate files, parse resources, index by `id`, return on demand. Fabricating formulas here would add noise without precision.

The relevant numeric constraints are **budgets**, stated as tuning knobs (see Section G):

**Load time budget**: Eager boot load must complete within **200 ms** on minimum mobile spec (~2 GB RAM, Cortex-A53 class). At MVP scale (<2 MB across all content directories, ~50 resource files), a synchronous `ResourceLoader.load()` pass is well within this bound. If profiling at V1.0 scale (15-20 classes, 5 biomes) threatens the bound, the migration path is `ResourceLoader.load_threaded_request()` with a loading screen; the API contract for consumers does not change.

**Memory budget per category** (targets, not enforced caps):

| Category | MVP file count | Target max loaded KB |
|----------|---------------|---------------------|
| `classes/` | 3 | 50 KB |
| `enemies/` | 8 | 100 KB |
| `biomes/` | 1 | 20 KB |
| `dungeons/` | 5 (floors) | 60 KB |
| `items/` | ~10 | 80 KB |
| `matchup/` | ~24 rules | 40 KB |
| **Total MVP** | **~50 files** | **< 400 KB** |

The 256 MB mobile ceiling is not threatened at any realistic content scale for this game. The table exists so V1.0 planning has a baseline to multiply from.

---

## Edge Cases

- **If a content file referenced by a save is missing** (e.g., `hero_warrior.tres` deleted in a patch): `resolve("classes", "class_warrior")` returns `null`. The Data Loading System logs a warning: `[DataRegistry] WARN: id 'class_warrior' not found in 'classes'`. Save/Load receives `null` and applies its own fallback policy. *Rationale*: silent substitution would mask authoring errors during development.

- **If a content file is malformed or cannot be parsed**: `ResourceLoader.load()` returns `null`. The Data Loading System logs `[DataRegistry] ERROR: failed to parse '...'`. The file is skipped; all other files in the directory load normally. If file count falls below `MIN_CONTENT_COUNT[type]`, the system enters `ERROR` state.

- **If two resources declare the same `id` within a content type** (collision): At registration time, if a new resource's `id` is already in the index, the Data Loading System logs an error: `[DataRegistry] ERROR: id collision 'class_warrior' in 'classes' — second file 'hero_warrior_v2.tres' rejected` and transitions to `ERROR` state. The first-registered resource is retained. *Rationale*: collisions are bugs, not feature behavior, and must surface loudly.

- **If a resource references a non-existent `id` in another resource type**: Godot's `ExtResource()` link resolves at parse time. If the target file is missing, Godot logs a parse warning and the field is null after load. Database-layer initialization (e.g., Dungeon DB) asserts expected fields are non-null and catches the problem.

- **If a circular resource reference exists** (A → B → A): Godot's resource loader detects cycles and logs a parse error; one side resolves to `null`. The DAG rule (Rule 6) makes cycles authoring bugs. Post-load DAG validation reports `[DataRegistry] ERROR: CIRCULAR REF: dungeon_A → biome_B → dungeon_A` and transitions to `ERROR` state.

- **If a `.tres` file was authored by a future version of the game** (version mismatch): Godot loads by field name; unknown fields are silently ignored, missing fields default to declared defaults. Forward compatibility is free. Backward compatibility requires care: if a new content version removes a field, old saves referencing that field's resource by `id` still load — the resource exists, the removed field defaults. No per-file version stamp required; content versioning is a build-level concern (`.pck` version).

- **If eager load finishes but memory is near the mobile ceiling**: Not a realistic scenario at this game's content scale (<400 KB total vs 256 MB ceiling). If V1.0 content grows toward 50+ MB, introduce lazy loading per category via the `lazy_load_categories` knob before adding eviction complexity.

- **If hot-reload fires in dev while a save game is active** (resource instance identity changes): Hot-reload replaces instances in the index. Any system holding a direct reference now holds a stale object. The `hot_reload_complete(content_type)` signal notifies subscribers to re-fetch. Hot-reload is stripped from shipped builds so this is never a player-facing issue.

- **If a developer renames a content file but forgets to update its `id` field**: The resource loads under the new filename; the old `id` is preserved; save files continue to resolve correctly. The only symptom is filename/id mismatch — a code-review catch, not a runtime failure. Rule 4 exists precisely so filename changes are safe non-events.

- **If new content is added in a patch** (updated `.pck`) and the game is already running: The in-memory index is populated at boot and is not live-updated from `.pck` patches at runtime. Patching while running is not supported; next launch rebuilds the full index.

---

## Dependencies

### Upstream Dependencies

**None.** This is a Foundation-layer system with no prerequisites. It reads directly from Godot engine APIs (`ResourceLoader`, `DirAccess`, `Resource`).

### Downstream Dependents

| Consumer | Hard/Soft | Data Interface | Direction |
|---|---|---|---|
| Hero Class Database | Hard | `get_all_by_type("classes") -> Array[HeroClass]` at `registry_ready`; `resolve("classes", id)` on demand | Data Loading → Class DB |
| Enemy Database | Hard | `get_all_by_type("enemies") -> Array[EnemyData]` at `registry_ready`; `resolve("enemies", id)` on demand (class name `EnemyData` per enemy-database.md §C.1 + ADR-0011) | Data Loading → Enemy DB |
| Biome & Dungeon Database | Hard | `get_all_by_type("biomes")`, `get_all_by_type("dungeons")` at `registry_ready` | Data Loading → Biome/Dungeon DB |
| Save/Load System | Hard | `resolve(content_type, id) -> Resource \| null` for every reference during session restore | Data Loading → Save/Load |
| Matchup Resolver | Hard | `get_all_by_type("matchup") -> Array[MatchupRule]` at `registry_ready` | Data Loading → Matchup Resolver |

**No soft dependencies.** Every listed consumer needs this system to function — this is the load-bearing foundation for all content-driven gameplay.

---

## Tuning Knobs

| Knob | Type | Default | Safe Range | Effect |
|------|------|---------|------------|--------|
| `data_root_path` | `String` | `"res://assets/data"` | Any valid `res://` path | Redirects all content loading to an alternate directory. Use in automated tests to load a minimal fixture dataset. Dev builds only. |
| `hot_reload_enabled` | `bool` | `true` (dev) / `false` (ship) | Boolean | Enables `hot_reload(content_type)` and the `HOT_RELOAD` state. Stripped from shipped builds via compile flag. |
| `load_time_budget_ms` | `int` | `200` | 50–500 | Target maximum milliseconds for the full eager-load pass at boot. Profiling reports a warning if exceeded. Not a hard abort. |
| `missing_id_behavior` | `enum` | `WARN` | `WARN`, `ASSERT` | Controls how `resolve()` handles a missing `id`. `WARN` logs and returns `null` (production default). `ASSERT` crashes with stack trace (automated tests). |
| `lazy_load_categories` | `Array[String]` | `[]` | Subset of content type names | If non-empty, listed categories are not eagerly loaded at boot; they load on first access. Migration path for V1.0. MVP leaves empty. |
| `min_content_count` | `Dictionary` | `{"classes": 3, "enemies": 5, "biomes": 1, "dungeons": 1, "matchup": 1}` | per-category ≥ 0 | Minimum file count per category below which the system enters `ERROR` state. Catches catastrophic content deletion. |

---

## Visual / Audio Requirements

**None.** Pure infrastructure. A loading screen may be required if load time grows beyond a few hundred ms at V1.0 scale — that is a UI concern owned by the Scene/Screen Manager and Guild Hall Screen GDDs.

---

## UI Requirements

**None.** This system has no UI. It emits signals and exposes accessors only.

---

## Acceptance Criteria

All criteria use Given-When-Then format. Story type: **Logic / Integration (Foundation layer)**. All criteria are BLOCKING except AC-DLS-09 which is ADVISORY in release builds, BLOCKING for dev workflow.

### AC-DLS-01: Boot Sequence — LOADING to READY (Integration, BLOCKING)

**GIVEN** the app launches with `assets/data/` containing the full MVP content set (classes, enemies, biomes, dungeons, items, matchup rules) and no file is malformed,
**WHEN** the Data Loading System completes enumeration and registration of all `.tres` files,
**THEN** the system emits `registry_ready` and transitions internal state from `LOADING` to `READY`; `DataRegistry.state == READY` is observable by all dependents before the first gameplay frame; typed accessors for all six content categories return non-null collections with expected cardinality (e.g., `get_all_classes().size() >= MIN_CONTENT_COUNT["classes"]`).

*Verification*: integration test — boot headlessly; assert state transition, assert all accessor counts meet per-category minimums.

### AC-DLS-02: Stable ID Contract — File Rename Transparent to Resolver (Logic, BLOCKING)

**GIVEN** a resource `warrior.tres` with `id = "hero_warrior"` has been loaded into the registry, and a downstream save-file reference uses the string `"hero_warrior"`,
**WHEN** the `.tres` file is renamed on disk to `hero_warrior_v2.tres` (same `id` field, different filename) and the app relaunches,
**THEN** `DataRegistry.resolve("classes", "hero_warrior")` returns the same resource object as before the rename; no error is logged; no consumer call sites require changes.

*Verification*: unit test — register under original filename; rename file; re-run enumeration; assert `resolve()` returns the resource and `resource.id == "hero_warrior"`.

### AC-DLS-03: Duplicate ID Detection — Hard Conflict at Load Time (Logic, BLOCKING)

**GIVEN** two `.tres` files in `assets/data/classes/` both declare `id = "hero_warrior"`,
**WHEN** the Data Loading System enumerates that category,
**THEN** the system logs `[DataRegistry] DUPLICATE ID: 'hero_warrior' in classes — {path_a} vs {path_b}. Second file skipped.`; state transitions to `ERROR` (not `READY`); `registry_error(DuplicateId, "hero_warrior")` is emitted; the first registered resource is retained and the second is dropped (not a crash); dependent systems remain uninitialized until the conflict is resolved.

*Verification*: unit test — inject two test resources with matching `id`; assert state is `ERROR`, error signal payload correct, accessor returns exactly one result.

### AC-DLS-04: Missing Reference — Graceful Resolver Failure (Integration, BLOCKING)

**GIVEN** a save file contains a serialized reference to `"classes", id = "hero_berserker"`, and no `.tres` resource with that id exists,
**WHEN** `DataRegistry.resolve("classes", "hero_berserker")` is called by Save/Load during session restore,
**THEN** `resolve()` returns `null` (not a crash, not a default stub); an error is logged: `[DataRegistry] MISSING REF: classes id='hero_berserker' — no resource registered`; Save/Load receives `null` and applies its own fallback policy; session restore continues for all other valid references.

*Verification*: integration test — load registry without "hero_berserker"; call `resolve()`; assert return is `null`, error logged, no exception raised, unrelated `resolve()` calls still return correct resources.

### AC-DLS-05: Malformed File — Parse Failure Isolated (Logic, BLOCKING)

**GIVEN** one `.tres` file in `assets/data/enemies/` is syntactically corrupt (truncated, invalid resource type, or missing `id` field),
**WHEN** the Data Loading System encounters that file,
**THEN** the file is skipped with a structured warning `[DataRegistry] MALFORMED FILE: {path} — skipped. Reason: {parse_error}`; all other valid files in the same category continue loading; if count falls below `MIN_CONTENT_COUNT["enemies"]`, state transitions to `ERROR`; otherwise `READY`; no unhandled exception propagates.

*Verification*: unit test — inject a zero-byte `.tres` alongside valid files; assert warning log, valid files resolve correctly, state is `READY` if minimums still met.

### AC-DLS-06: Cross-Reference DAG Integrity — Circular Reference Detected (Logic, BLOCKING)

**GIVEN** two resources form a circular reference (`dungeon_A → biome_B → dungeon_A`, or any cycle length ≥ 2),
**WHEN** the Data Loading System performs post-load DAG validation,
**THEN** the cycle is detected and reported: `[DataRegistry] CIRCULAR REF: dungeon_A → biome_B → dungeon_A`; state transitions to `ERROR`; neither resource in the cycle is available via `resolve()`; all other non-cyclic resources remain accessible.

*Verification*: unit test — construct two test resources with mutually referencing ids; run DAG validation; assert `ERROR` state, both ids in log, cycle members return `null`.

### AC-DLS-07: Load-Time Performance Budget — MVP Under 200ms on Mobile (Performance, BLOCKING)

**GIVEN** the device meets minimum mobile spec (~2 GB RAM, ~Cortex-A53 equivalent) and `assets/data/` contains exactly the MVP content set,
**WHEN** the Data Loading System runs full enumeration + parse + registration from cold start (no OS file cache),
**THEN** elapsed time from `DataRegistry._ready()` entry to `registry_ready` emission is **< 200 ms**, measured via `Time.get_ticks_msec()` bracketing those two points; measured on real hardware, not editor/emulator.

*Verification*: performance integration test — 10 trials on minimum-spec hardware; assert p95 < 200 ms; log p50/p95/p99 to `production/qa/evidence/dls-perf-[date].md` with device spec.

### AC-DLS-08: Read-Only Contract Enforcement (Logic, BLOCKING in test builds)

**GIVEN** a resolved resource instance is obtained via `DataRegistry.resolve("classes", "hero_warrior")`,
**WHEN** any consumer attempts to mutate a property (e.g., `resource.base_attack = 999`),
**THEN** in debug/test builds, the mutation either raises an assertion or is caught by a post-test integrity check comparing property values against the load-time snapshot; the registered resource's stored state is unchanged after the test; release builds do not enforce at runtime (performance), but the unit test suite includes at least one test catching this pattern.

*Verification*: unit test — resolve a resource; mutate a property; run integrity check; assert snapshot mismatch is detected and reported.

### AC-DLS-09: Dev Hot-Reload — Category Re-Read Without App Restart (Integration, BLOCKING dev / ADVISORY release)

**GIVEN** the game runs in the Godot editor or a `debug` export build and `DataRegistry.hot_reload_enabled == true`,
**WHEN** `DataRegistry.hot_reload("classes")` is called,
**THEN** only the `classes` category is re-enumerated and re-registered; other category registries are unmodified; `resolve()` calls after the reload return updated values from modified `.tres` files; the reload completes without restarting the scene tree; log confirms `[DataRegistry] HOT RELOAD: classes — {N} resources re-registered in {Ms}ms`.

*Verification*: integration test (debug build) — load registry; modify a test `.tres`; call `hot_reload("classes")`; assert updated value returned, enemy/biome registries unchanged, scene tree not re-entered.

### Story Type Classification

| AC ID | Type | Gate |
|---|---|---|
| AC-DLS-01 | Integration | BLOCKING |
| AC-DLS-02 | Logic | BLOCKING |
| AC-DLS-03 | Logic | BLOCKING |
| AC-DLS-04 | Integration | BLOCKING |
| AC-DLS-05 | Logic | BLOCKING |
| AC-DLS-06 | Logic | BLOCKING |
| AC-DLS-07 | Performance | BLOCKING |
| AC-DLS-08 | Logic | BLOCKING |
| AC-DLS-09 | Integration | BLOCKING dev / ADVISORY release |

AC-DLS-07 is the only criterion requiring real hardware — cannot verify in CI. Evidence file goes to `production/qa/evidence/dls-perf-[date].md`.

---

## Open Questions

| Question | Owner | Target Resolution |
|---|---|---|
| `@abstract` keyword availability in Godot 4.6 — needed for `GameData` base class. If not available, fall back to a concrete base class + convention. Verify against `docs/engine-reference/godot/breaking-changes.md`. | godot-gdscript-specialist | Before first story implementing `GameData` |
| Should `min_content_count` enforcement be waivable via a dev override to allow testing with partial datasets? Currently ERROR state blocks any consumer init. | systems-designer | Before Save/Load GDD (the system most likely to want a waiver) |
| V1.0 trigger for migrating to `load_threaded_request()` — what content volume in KB/file-count warrants the switch? Decide after /balance-check on V1.0 content plan. | performance-analyst | Before V1.0 content phase |
| Patch-time live content update — needed for post-launch seasonal content? Currently "next launch rebuilds index." If live-ops wants hot content drops, this must be designed. | live-ops-designer | Post-launch |
| Content manifest checksum for anti-tamper — should this system verify that shipped `.tres` files haven't been edited by a cheater? Or is that Save/Load's concern exclusively? | security-engineer | Before shipping MVP |

---

*This GDD does not introduce new registry entities/formulas/constants. The `id` convention is a cross-cutting pattern documented here as the canonical reference; other GDDs should cite "Data Loading System Rule 4" when using stable id references.*
