# Story 006: Cross-system enemy_id resolution + archetype distribution

> **Epic**: biome-dungeon-database
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/biome-dungeon-database.md` §H-04, §H-06; `design/gdd/enemy-database.md` (cross-reference)
**Requirements**: TR-biome-dungeon-db-007 (cross-resource validation), TR-enemy-db-005 (DataRegistry resolve)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (cross-resource references via DataRegistry); ADR-0006 (load-order discipline ensures EnemyDatabase ready before BiomeDungeonDatabase)
**ADR Decision Summary**: Floor.enemy_list[].enemy_id strings must resolve via EnemyDatabase. Boot ORDERED_CATEGORIES guarantees enemies load before biomes/dungeons/floors. This story is the integration test that ties Sprint 3's two new Core epics together at runtime.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core Layer)**:
- **Required**: enemy_id resolution at boot via EnemyDatabase. — ADR-0011
- **Required**: biome `dominant_archetypes` field consistent with floor enemy archetypes (advisory). — ADR-0011

---

## Acceptance Criteria

- [ ] **AC H-04 + TR-biome-dungeon-db-007**: integration test loads Forest Reach and verifies for each floor, for each `enemy_list` entry, `EnemyDatabase.get_by_id(entry.enemy_id)` returns non-null EnemyData
- [ ] Test asserts the count: total enemy_id references across all 5 floors of Forest Reach (e.g., F1 has 3 distinct ids × counts; F5 has Ancient Rootking + minions). Every reference resolves.
- [ ] **AC H-06**: F1–F4 each cover at least one MVP archetype (BRUISER / CASTER / ARMORED) — i.e., for each non-boss floor, the union of `enemy.archetype` for its enemy_list entries is non-empty AND each archetype is in `EnemyArchetypes.MVP_SET`
- [ ] **AC H-06 distribution**: across F1-F4, all 3 MVP archetypes appear at least once (verified by union of all non-boss floors' archetypes)
- [ ] F5 (boss floor) excluded from archetype-distribution check — boss floor identity isn't constrained by archetype variety
- [ ] **Biome `dominant_archetypes` consistency** (advisory): `forest_reach.dominant_archetypes` contains exactly the MVP archetypes that appear in F1-F4 (Story 003 authoring concern; this test verifies)

---

## Implementation Notes

*Derived from ADR-0011 §cross-resource validation + GDD §H:*

- This story does NOT add new code to BiomeDungeon or Enemy schemas. It's an integration test that ties Sprint 3 enemy-database + biome-dungeon-database content together at runtime.
- Pseudocode:
  ```
  func test_forest_reach_enemy_ids_all_resolve() -> void:
      var biome: Biome = BiomeDungeonDatabase.get_biome_by_id("forest_reach")
      assert_object(biome).is_not_null()
      var dungeon: Dungeon = biome.dungeons[0]
      for floor in dungeon.floors:
          for entry in floor.enemy_list:
              var enemy: EnemyData = EnemyDatabase.get_by_id(entry.enemy_id)
              assert_object(enemy).append_failure_message(
                  "Floor %d enemy_id='%s' did not resolve" % [floor.floor_index, entry.enemy_id]
              ).is_not_null()
              assert_int(entry.count).is_greater(0)

  func test_forest_reach_archetype_distribution_f1_to_f4() -> void:
      var biome: Biome = BiomeDungeonDatabase.get_biome_by_id("forest_reach")
      var dungeon: Dungeon = biome.dungeons[0]
      var observed_archetypes: Dictionary = {}
      for floor in dungeon.floors:
          if floor.is_boss_floor:
              continue
          for entry in floor.enemy_list:
              var enemy: EnemyData = EnemyDatabase.get_by_id(entry.enemy_id)
              if enemy != null:
                  observed_archetypes[enemy.archetype] = true
      # Assert all 3 MVP archetypes appear in F1-F4
      assert_bool(observed_archetypes.has(EnemyArchetypes.BRUISER)).is_true()
      assert_bool(observed_archetypes.has(EnemyArchetypes.CASTER)).is_true()
      assert_bool(observed_archetypes.has(EnemyArchetypes.ARMORED)).is_true()
  ```
- This test depends on EnemyDatabase + BiomeDungeonDatabase both being in READY state. After Sprint 3 enemy-database S003 + this epic S003 land, the smoke check (Sprint 3 S3-M8) will confirm DataRegistry reaches READY end-to-end. This integration test runs in that confirmed-good state.
- The `dominant_archetypes` consistency check is advisory — designer-authored value should match observed archetypes in F1-F4. If they diverge, push_warning at load (not error).

---

## Out of Scope

- Story 003 / 004 / 005 — sibling stories
- Per-floor enemy count balance (gameplay tuning) — covered by /balance-check skill in later sprints
- Matchup-multiplier kill-gold formula — covered by enemy-database epic Story 005

---

## QA Test Cases

- **AC H-04 + TR-biome-dungeon-db-007: enemy_id resolution**
  - **Given**: Forest Reach loaded; 7+ MVP enemies loaded
  - **When**: traverse all 5 floors × all enemy_list entries
  - **Then**: every `enemy_id` resolves to non-null EnemyData; counts > 0
  - **Edge cases**: failure message identifies which floor + which id failed (for diagnosability)

- **AC H-06: archetype distribution F1-F4**
  - **Given**: same setup
  - **When**: collect distinct enemy archetypes across F1-F4 (excluding F5 boss)
  - **Then**: set contains all 3 MVP archetypes (BRUISER, CASTER, ARMORED)
  - **Edge cases**: any archetype absent from F1-F4 → fail with note about which is missing

- **AC: biome.dominant_archetypes consistency (advisory)**
  - **Given**: Forest Reach loaded
  - **When**: compare `biome.dominant_archetypes` (designer-authored) against observed archetypes in F1-F4
  - **Then**: sets equal exactly (or warning if drift)
  - **Edge cases**: empty `dominant_archetypes` field → push_warning, not error (advisory)

- **AC: ORDERED_CATEGORIES load-order safety**
  - **Given**: DataRegistry boot scan
  - **When**: Floor `_validate()` (Story 004) calls `EnemyDatabase.get_by_id` during boot
  - **Then**: lookup succeeds — enemies already in READY state when biomes load (per ADR-0006)
  - **Edge cases**: hypothetical reverse-order boot would fail; verifying ORDERED_CATEGORIES guard

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/biome_dungeon_database/cross_system_enemy_id_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 003 (Forest Reach content), Sprint 3 enemy-database Story 003 (enemy `.tres` files), Story 004 (validator already enforces enemy_id resolution at load — this test confirms post-load runtime)
- **Unlocks**: Confidence in enemy + biome data integrity for downstream Combat / Orchestrator Feature epics
