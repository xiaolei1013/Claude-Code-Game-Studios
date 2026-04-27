# Story 007: Save file biome/floor reference id-stability after restore

> **Epic**: biome-dungeon-database
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/biome-dungeon-database.md` §H-10
**Requirements**: TR-biome-dungeon-db-020
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (resource cache consistency invariant), ADR-0006 (DataRegistry resource resolution)
**ADR Decision Summary**: Save files store biome/floor references by `id` string (not by Resource object). On session restore, `BiomeDungeonDatabase.get_*_by_id(id)` must return the same Resource object instance as a fresh boot. This invariant means active-run state (current biome, current floor) survives save/load without object-identity drift.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot resource cache (`ResourceLoader.CACHE_MODE_REUSE` default) provides this invariant out of the box. Mirror enemy-database Story 006 pattern.

**Control Manifest Rules (Core Layer)**:
- **Required**: save files store id strings only (never Resource refs). — ADR-0011
- **Required**: id-stable across sessions; filename-independent lookup. — ADR-0011

---

## Acceptance Criteria

- [ ] **AC H-10**: `BiomeDungeonDatabase.get_biome_by_id(id)` returns the same Resource instance across two separate boot+resolve cycles for the same id
- [ ] Same for `get_dungeon_by_id` and `get_floor_by_id`
- [ ] **TR-biome-dungeon-db-020**: after a hypothetical save/load round-trip (mock if SaveLoadSystem Foundation epic hasn't landed), restored references resolve to the same Resource objects as the pre-save instances
- [ ] Object-identity check via `==`
- [ ] No reliance on `ResourceLoader.CACHE_MODE_REPLACE` or other cache-busting modes — defaults must yield identity

---

## Implementation Notes

*Mirror enemy-database Story 006 + Sprint 2 hero-class-database Story 002 AC H-07 patterns:*

- Verification-only story; no new source code if Stories 001 + 002 are correctly implemented (they use `DataRegistry.resolve` which leverages Godot's resource cache).
- Test pseudocode:
  ```
  func test_biome_id_resolves_to_same_instance() -> void:
      var ref_a: Biome = BiomeDungeonDatabase.get_biome_by_id("forest_reach")
      var ref_b: Biome = BiomeDungeonDatabase.get_biome_by_id("forest_reach")
      assert_object(ref_a == ref_b).is_true()
  ```
- Floor identity check: floors are nested within dungeons; the same nested-resource instance should be reachable via both `dungeon.floors[0]` and `BiomeDungeonDatabase.get_floor_by_id("[floor_id]")` (if the database wires floor resolution by walking dungeons; verify implementation in Story 002).
- Simulated save/load: serialize `biome.id` string + `floor.id` string; re-resolve via the captured ids; assert post-load reference is same as pre-save.
- Document SaveLoadSystem real-integration deferral for Sprint 4+.

---

## Out of Scope

- SaveLoadSystem Foundation epic real integration (Sprint 4 candidate)
- Save schema versioning
- Cross-platform save-file portability

---

## QA Test Cases

- **AC: id-stability for biome / dungeon / floor**
  - **Given**: Forest Reach loaded
  - **When**: each of `get_biome_by_id("forest_reach")`, `get_dungeon_by_id("forest_reach_main")`, `get_floor_by_id("[floor_id]")` called twice
  - **Then**: each pair of calls returns the same Resource instance (object-identity)
  - **Edge cases**: traversal-based access (`biome.dungeons[0].floors[0]`) returns the same instance as `get_floor_by_id` lookup

- **AC H-10 + TR-biome-dungeon-db-020: id-stability after save/load (simulated)**
  - **Given**: pre-save references; id strings captured as if persisted
  - **When**: simulated save/load cycle (re-resolve via captured ids)
  - **Then**: post-load references are same Resource instances as pre-save
  - **Edge cases**: SaveLoadSystem real integration deferred to Sprint 4

- **AC: filename-independent lookup**
  - **Given**: a `.tres` file at `assets/data/biomes/forest_reach.tres` with `id = "forest_reach"`
  - **When**: `get_biome_by_id("forest_reach")`
  - **Then**: returns the resource regardless of filename (id is canonical lookup key)
  - **Edge cases**: filename and id divergence — id wins

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/biome_dungeon_database/biome_id_stability_test.gd` — must exist and pass; SaveLoadSystem-real integration deferred to Sprint 4+

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (resource schemas), Story 002 (autoload), Story 003 (Forest Reach `.tres` content)
- **Unlocks**: DungeonRunOrchestrator save state (Feature epic) which references current biome/floor; SaveLoadSystem integration (Sprint 4+)
