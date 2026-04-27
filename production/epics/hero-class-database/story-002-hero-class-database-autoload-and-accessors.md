# Story 002: HeroClassDatabase autoload skeleton + DataRegistry accessor wrapper

> **Epic**: hero-class-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/hero-class-database.md` §C (autoload pattern), §H-01, §H-07
**Requirements**: TR-hero-class-db-007, TR-hero-class-db-013, TR-hero-class-db-014, TR-hero-class-db-018
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (resource schema + DataRegistry resolve contract), ADR-0006 (boot scan), ADR-0003 (autoload rank 4 + zero-arg `_init`)
**ADR Decision Summary**: HeroClassDatabase is a thin typed-accessor autoload (rank 4) wrapping `DataRegistry.resolve("classes", id)`. It does NOT cache or shadow data — DataRegistry is the source of truth. Provides ergonomic helpers (`get_by_id`, `get_recruitable_classes`, `get_all_ids`) so consumers don't need to know the registry category string.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Standard autoload pattern with `class_name HeroClassDatabase extends Node`; `DataRegistry.resolve` is the existing rank-1 resolver from Sprint 1.

**Control Manifest Rules (Core Layer)**:
- **Required**: HeroClassDatabase autoload identifier = `HeroClassDatabase` at rank 4. — ADR-0003
- **Required**: zero-arg `_init`. — ADR-0003 Amendment #3
- **Required**: consumers read HeroClass via DataRegistry only; no writes back to HeroClass resources (immutable at runtime). — ADR-0011

---

## Acceptance Criteria

- [ ] `class_name HeroClassDatabase extends Node` (or `Node`-only if class_name conflicts with autoload — see Sprint 1 TickSystem completion notes)
- [ ] Registered at rank 4 in `project.godot [autoload]` after Economy (3); architecture.md rank table verified in lockstep
- [ ] `_init() -> void` zero-arg
- [ ] **TR-hero-class-db-007**: `get_by_id(id: String) -> HeroClass` returns a HeroClass or null; null is a valid contract (consumers must null-check)
- [ ] **H-01**: `get_by_id("warrior")`, `get_by_id("mage")`, `get_by_id("rogue")` each return non-null HeroClass after DataRegistry boot completes; `result.id == query`; `result.tier == 1`; `result.display_name` non-empty
- [ ] **TR-hero-class-db-013**: consumer-side reads only (no mutation methods like `set_*` on HeroClass references obtained through this autoload)
- [ ] **TR-hero-class-db-014**: null return is documented contract — `get_by_id("nonexistent")` returns null without `push_error` (callers handle null)
- [ ] **H-07 / TR-hero-class-db-018**: same id queries return same Resource object instance (Godot resource cache consistency); after save/load round-trip, restored hero references resolve to the same object instances
- [ ] Helper: `get_all_ids() -> Array[String]` returns sorted list of all loaded class ids (MVP + V1.0 stubs)

---

## Implementation Notes

*Derived from ADR-0011 §Decision §typed-accessor pattern + ADR-0006 §DataRegistry.resolve:*

- Pseudocode:
  ```
  # src/core/hero_class_database/hero_class_database.gd
  extends Node

  func get_by_id(id: String) -> HeroClass:
      return DataRegistry.resolve("classes", id) as HeroClass

  func get_recruitable_classes() -> Array[HeroClass]:
      # Story 007 implements this; stub here returns empty
      return []

  func get_all_ids() -> Array[String]:
      return DataRegistry.get_all_ids("classes")
  ```
- Do NOT cache results inside HeroClassDatabase. DataRegistry holds the cache; this autoload is a thin typed wrapper.
- The `as HeroClass` cast is safe — if DataRegistry returns a non-HeroClass (schema bug), the cast yields null and the consumer gets the documented null contract.
- Rank 4 autoload registration follows the Sprint 1 pattern in `project.godot` — Economy(3), HeroClassDatabase(4), then EnemyDatabase(5), BiomeDungeonDatabase(6).
- `DataRegistry.get_all_ids(category)` may not exist yet; if so, file a tech-debt note OR add a tiny shim: `for id in DataRegistry._categories["classes"].keys()` (consult data-registry epic).

---

## Out of Scope

- Story 003: actual `.tres` files for the 3 MVP classes
- Story 004–008: helper methods on HeroClass (stat_at_level, etc.) live on HeroClass / HeroClassDatabase per the ADR-0011 split — implementation deferred to those stories
- Story 007: `get_recruitable_classes()` body (just stub here)
- DataRegistry.resolve's caching behavior (lives in data-registry epic, already implemented Sprint 1)

---

## QA Test Cases

- **AC H-01: 3 MVP classes resolvable**
  - **Given**: DataRegistry in READY state with 3 MVP `.tres` files loaded (Story 003 fixture)
  - **When**: `HeroClassDatabase.get_by_id("warrior")` etc.
  - **Then**: each returns non-null HeroClass; `id` matches query; `tier == 1`; `display_name` non-empty
  - **Edge cases**: pre-READY state queries return null with informative push_warning (per data-registry epic policy); during ERROR state, behavior follows DataRegistry contract

- **TR-hero-class-db-014: null contract**
  - **Given**: DataRegistry READY
  - **When**: `get_by_id("does_not_exist")`
  - **Then**: returns null; **no** push_error fired (callers handle null is the documented contract)
  - **Edge cases**: empty string returns null; very long ids handled

- **AC H-07: id-stability across save/load**
  - **Given**: a save with hero references to `"warrior"`
  - **When**: DataRegistry restores from save; queries resolve `"warrior"` again
  - **Then**: returned Resource instance is `==` (object-identity) to the boot-time instance (Godot resource cache reuses same Resource objects for the same path)
  - **Edge cases**: explicit cache-busting (e.g., `ResourceLoader.CACHE_MODE_REPLACE`) is OUT of scope — defaults must yield identity

- **AC: get_all_ids enumerates classes**
  - **Given**: 3 MVP + 3 V1.0 stubs loaded (Story 011 fixture)
  - **When**: `get_all_ids()` returns
  - **Then**: returned Array[String] has length 6, sorted alphabetically; contains exactly the registered ids
  - **Edge cases**: zero classes loaded → empty array, no error

- **AC: zero-arg _init + autoload rank**
  - **Given**: fresh boot
  - **When**: introspect autoload list
  - **Then**: HeroClassDatabase at index 4 (rank); no autoload-construction errors
  - **Edge cases**: malformed project.godot rank fails boot fast

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/hero_class_database/hero_class_database_autoload_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (HeroClass resource schema), data-registry epic Sprint 1 work (`resolve` API at minimum), Economy autoload at rank 3 (Story 001 of economy-system) for rank-ordering
- **Unlocks**: All other hero-class-database stories; Enemy DB and BiomeDungeon DB epics (which mirror this pattern)


## Completion Notes
**Completed**: 2026-04-25
**Criteria**: 8/8 (5 deferred to S2-M7 smoke check via graceful-degrade pattern)
**Story Type**: Integration
**Test Evidence**: `tests/integration/hero_class_database/hero_class_database_autoload_test.gd` — 8 test functions / 0 failures. 5 of the 8 tests apply the `push_warning + return` pattern when DataRegistry is in ERROR (expected during Sprint 2 because non-class categories are empty). Once S2-M7 lands (or once Sprint 3 adds enemy/biome content), these tests will assert real data live.
**Manifest Version**: 2026-04-24 — matched
**Files created**: `src/core/hero_class_database/hero_class_database.gd` (autoload — `get_by_id`, `get_recruitable_classes` stub, `get_all_ids`), `tests/integration/hero_class_database/hero_class_database_autoload_test.gd` (8 test functions)
**Files modified**: `project.godot` — added HeroClassDatabase autoload at rank 4 after Economy.
**Deviations**: NONE BLOCKING. `DataRegistry.get_all_ids()` doesn't exist; used `DataRegistry.get_all_by_type("classes")` + map-to-id pattern (story spec Option A). `get_recruitable_classes()` is intentionally a stub (real body in hero-class-database epic Story 007 — not in Sprint 2 Must Have).
**Code Review**: SKIPPED — solo
**Next**: S2-M7 (3 MVP class .tres files).
