# Story 006: Save file enemy reference id-stability after restore

> **Epic**: enemy-database
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/enemy-database.md` §H-09
**Requirements**: TR-enemy-db-019
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (resource cache consistency invariant), ADR-0006 (DataRegistry resource resolution)
**ADR Decision Summary**: Save files store enemy references by `id` string (not by Resource object). On session restore, `DataRegistry.resolve("enemies", id)` must return the same Resource object instance as a fresh boot — i.e., Godot's resource cache reuses the same Resource for the same path. This invariant means hero-vs-enemy combat state survives save/load without object-identity drift.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot resource cache (`ResourceLoader.CACHE_MODE_REUSE` default) provides this invariant out of the box. Story is mostly verification rather than implementation.

**Control Manifest Rules (Core Layer)**:
- **Required**: save files store id strings only (never Resource refs). — ADR-0011
- **Required**: id-stable across sessions; filename-independent lookup. — ADR-0011

---

## Acceptance Criteria

- [ ] **AC H-09**: `DataRegistry.resolve("enemies", id)` returns the same Resource instance across two separate boot+resolve cycles for the same id
- [ ] **TR-enemy-db-019**: after a hypothetical save/load round-trip (mock if SaveLoadSystem Foundation epic hasn't landed), restored enemy id references resolve to the same Resource objects as the pre-save instances
- [ ] Object-identity check via `==` (Godot Resource equality is reference equality)
- [ ] No reliance on `ResourceLoader.CACHE_MODE_REPLACE` or other cache-busting modes — defaults must yield identity

---

## Implementation Notes

*Derived from ADR-0011 §resource cache invariant. Mirror the hero-class-database Story 002 / S2-M6 AC H-07 pattern.*

- This story is primarily verification. No new source code needed if Stories 001 + 002 are correctly implemented (they already use `DataRegistry.resolve` which leverages Godot's resource cache).
- Test pseudocode:
  ```
  func test_enemy_id_resolves_to_same_instance_across_calls() -> void:
      var ref_a: EnemyData = EnemyDatabase.get_by_id("hollow_brute")
      var ref_b: EnemyData = EnemyDatabase.get_by_id("hollow_brute")
      assert_object(ref_a == ref_b).is_true()  # object-identity via Godot resource cache
  ```
- For the save/load round-trip leg: if SaveLoadSystem (Foundation epic, blocked rank-2 hole) hasn't landed by Sprint 3, simulate the save/load cycle by serializing the id string and re-resolving:
  ```
  var pre_save: EnemyData = EnemyDatabase.get_by_id("hollow_brute")
  var saved_id: String = pre_save.id  # what would land in save file
  # ... simulated save/load happens here ...
  var post_load: EnemyData = EnemyDatabase.get_by_id(saved_id)
  assert(pre_save == post_load)  # same Resource instance
  ```
- Document the mock/simulation in Test Evidence; promote the test to actual SaveLoadSystem integration when Sprint 4-5 lands save infrastructure.

---

## Out of Scope

- SaveLoadSystem Foundation epic (Sprint 4 candidate)
- Cross-platform save-file portability (mobile vs PC) — V1.0 concern
- Save schema versioning (covered by Save/Load epic)

---

## QA Test Cases

- **AC: id-stability across calls**
  - **Given**: an enemy id (e.g., "hollow_brute")
  - **When**: `EnemyDatabase.get_by_id("hollow_brute")` called twice in succession
  - **Then**: both calls return the same Resource instance (object-identity equal via `==`)
  - **Edge cases**: also test across all 7+ MVP enemies for failure-isolation

- **AC H-09: id-stability after save/load (simulated)**
  - **Given**: a pre-save reference; an id string captured as if persisted to save
  - **When**: simulated save/load cycle (re-resolve via the captured id)
  - **Then**: post-load reference is the same Resource instance as pre-save
  - **Edge cases**: SaveLoadSystem real integration deferred to Sprint 4; document the simulation in test comments

- **AC: filename-independent lookup**
  - **Given**: an enemy `.tres` file at `assets/data/enemies/hollow_brute.tres` with `id = "hollow_brute"`
  - **When**: `EnemyDatabase.get_by_id("hollow_brute")`
  - **Then**: returns the resource regardless of filename (id is the canonical lookup key, not filename)
  - **Edge cases**: a .tres file where filename and id differ — id wins (per ADR-0011 spec)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/enemy_database/enemy_id_stability_test.gd` — must exist and pass; **note**: SaveLoadSystem-real integration deferred to Sprint 4+

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (EnemyData schema), Story 002 (EnemyDatabase autoload), Story 003 (`.tres` files)
- **Unlocks**: HeroRoster save serialization (Feature epic) which references enemies-killed-this-run; SaveLoadSystem integration (Sprint 4+)
