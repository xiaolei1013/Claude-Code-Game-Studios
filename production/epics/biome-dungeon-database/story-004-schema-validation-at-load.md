# Story 004: Cross-resource schema validation at load time

> **Epic**: biome-dungeon-database
> **Status**: Complete (system shipped; see systems-index Implementation Status #8. Test evidence: `tests/{unit,integration}/biome_dungeon_database/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/biome-dungeon-database.md` §C, §E, §H-03, §H-04, §H-05, §H-09
**Requirements**: TR-biome-dungeon-db-007, TR-biome-dungeon-db-008, TR-biome-dungeon-db-009, TR-biome-dungeon-db-010, TR-biome-dungeon-db-011, TR-biome-dungeon-db-012
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (per-resource validation + cascading UNAVAILABLE state)
**ADR Decision Summary**: Each of Biome/Dungeon/Floor implements `_validate() -> Array[String]`. Floor validation cross-checks `enemy_list[].enemy_id` against EnemyDatabase. Invalid Floor cascades Dungeon → Biome to UNAVAILABLE state without dropping the rest of the catalog. Empty enemy_list on non-boss floor → hard load rejection.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Cross-resource validation requires EnemyDatabase to be loaded BEFORE BiomeDungeonDatabase — guaranteed by ORDERED_CATEGORIES (enemies before biomes/dungeons/floors).

**Control Manifest Rules (Core Layer)**:
- **Required**: per-resource `_validate()` per ADR-0011. — ADR-0011 / ADR-0006
- **Required**: enemy_id references resolved at load time. — ADR-0011 / TR-biome-dungeon-db-010
- **Required**: cascading UNAVAILABLE state for invalid floors → dungeons → biomes. — ADR-0011

---

## Acceptance Criteria

- [ ] Biome declares `_validate() -> Array[String]`
- [ ] Dungeon declares `_validate() -> Array[String]`
- [ ] Floor declares `_validate() -> Array[String]`
- [ ] **TR-biome-dungeon-db-007 Floor validation**: `enemy_list` non-empty for non-boss floors (else hard load rejection per AC H-09); all `enemy_id` strings resolve via EnemyDatabase; `floor_index >= 1`
- [ ] **TR-biome-dungeon-db-008 + AC H-05**: if `is_boss_floor == true`, `enemy_list` contains at least one entry whose enemy has `is_boss == true`
- [ ] **TR-biome-dungeon-db-009 Biome validation**: `status ∈ {"active", "planned_v1"}`; all `Dungeon.biome_id` back-refs match this Biome's id
- [ ] **TR-biome-dungeon-db-011 Dungeon validation**: `floor_index` values within `floors` array are unique (no duplicates); load-time rejection on duplicate
- [ ] **TR-biome-dungeon-db-012 + AC H-09**: empty `enemy_list` on a non-boss floor → hard load rejection with error
- [ ] **TR-biome-dungeon-db-010 + AC H-04**: any unresolvable `enemy_id` causes the containing Floor to enter UNAVAILABLE state; cascades to Dungeon (UNAVAILABLE) and Biome (UNAVAILABLE) without dropping the entire catalog
- [ ] DataRegistry per-type validators call each resource's `_validate()`; non-empty result + cross-resource failures → resource rejected with descriptive `push_error`

---

## Implementation Notes

*Derived from ADR-0011 §Load-Time Validation Semantics + cascading UNAVAILABLE state:*

- Each resource implements `_validate()` per the HeroClass / EnemyData precedent. Floor validation needs cross-system resolution against EnemyDatabase — this requires EnemyDatabase to already be loaded by the time Floor validates. Per ADR-0006 + ORDERED_CATEGORIES, "enemies" loads before "biomes"/"dungeons"/"floors", so this is safe at boot.
- Pseudocode for Floor:
  ```
  func _validate() -> Array[String]:
      var errors: Array[String] = []
      if floor_index < 1:
          errors.append("floor_index=%d must be >= 1" % floor_index)
      if not is_boss_floor and enemy_list.is_empty():
          errors.append("enemy_list empty on non-boss floor")
      for entry in enemy_list:
          if not entry.has("enemy_id") or not entry.has("count"):
              errors.append("enemy_list entry missing required keys")
              continue
          var enemy: EnemyData = EnemyDatabase.get_by_id(entry.enemy_id)
          if enemy == null:
              errors.append("enemy_id='%s' does not resolve in EnemyDatabase" % entry.enemy_id)
          if entry.count <= 0:
              errors.append("enemy_list[%s] count=%d must be > 0" % [entry.enemy_id, entry.count])
      if is_boss_floor:
          var has_boss := false
          for entry in enemy_list:
              var enemy: EnemyData = EnemyDatabase.get_by_id(entry.enemy_id)
              if enemy != null and enemy.is_boss:
                  has_boss = true
                  break
          if not has_boss:
              errors.append("is_boss_floor=true but enemy_list contains no is_boss=true enemy")
      return errors
  ```
- Dungeon validation: floor_index uniqueness within `floors` array; biome_id back-ref consistency.
- Biome validation: status ∈ {"active", "planned_v1"}; basic field non-emptiness.
- **Cascading UNAVAILABLE state** is the trickiest semantic. Implementation approach: when a Floor's `_validate()` returns errors, mark its containing Dungeon as UNAVAILABLE in the registry (or via a `status` field on Dungeon). Any reference traversal to that Dungeon should treat it as absent. Same upward cascade to Biome. Detail TBA — verify with ADR-0011 §Cascading UNAVAILABLE State at story pickup.
- DataRegistry's per-type validator hookup may need extension to handle three resource types in this single category structure. May produce another out-of-scope deviation (similar to S2-M2 ORDERED_CATEGORIES extension). Budget the 4h sprint buffer for this.

---

## Out of Scope

- Story 003: Forest Reach `.tres` content
- Story 005: V1.0 stub biome content
- Story 006: cross-system enemy_id integration test
- Implementation of UNAVAILABLE-state propagation in DataRegistry beyond what's needed for this story (data-registry epic Story 008 territory)

---

## QA Test Cases

- **AC: valid Forest Reach passes**
  - **Given**: Forest Reach .tres (Story 003) + 7+ MVP enemies (Sprint 3 enemy-db S003)
  - **When**: each resource's `_validate()` runs
  - **Then**: each returns empty array
  - **Edge cases**: re-running over the full set after any data edit; CI guard

- **AC H-09 + TR-biome-dungeon-db-012: empty enemy_list on non-boss floor**
  - **Given**: a fixture Floor with `is_boss_floor=false` and `enemy_list=[]`
  - **When**: `_validate()`
  - **Then**: returns array with "enemy_list empty on non-boss floor"
  - **Edge cases**: boss floor with empty enemy_list → also rejected (no boss enemy present)

- **AC H-04 + TR-biome-dungeon-db-010: unresolvable enemy_id**
  - **Given**: a fixture Floor with `enemy_list = [{ "enemy_id": "phantom_dragon", "count": 1 }]` (id doesn't exist)
  - **When**: `_validate()`
  - **Then**: returns violation listing the unresolvable enemy_id; resource rejected at load
  - **Edge cases**: Floor enters UNAVAILABLE state; containing Dungeon and Biome cascade to UNAVAILABLE

- **AC H-05: boss floor invariant**
  - **Given**: a fixture Floor with `is_boss_floor=true` but `enemy_list` containing only non-boss enemies
  - **When**: `_validate()`
  - **Then**: returns violation listing boss-mismatch
  - **Edge cases**: boss floor with multiple is_boss enemies (V1.0 hypothetical) — accepted (only need ≥ 1)

- **AC: floor_index uniqueness within dungeon**
  - **Given**: a fixture Dungeon with two floors both having `floor_index = 3`
  - **When**: Dungeon's `_validate()`
  - **Then**: returns violation "duplicate floor_index 3"
  - **Edge cases**: gap (e.g., floors 1, 2, 4) — fail; non-contiguous (e.g., 1, 3, 5) — also fail

- **AC: biome status enum**
  - **Given**: a fixture Biome with `status = "deprecated"`
  - **When**: `_validate()`
  - **Then**: returns violation
  - **Edge cases**: "ACTIVE" (case-mismatched) — fails; trailing whitespace — fails

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/biome_dungeon_database/biome_dungeon_validation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (resource schemas), Sprint 3 enemy-database Story 002 (EnemyDatabase autoload — required for Floor.enemy_id cross-resolution), data-registry epic Story 005 (per-type validator hookup — currently no-op stub; tests can call `_validate()` directly without DataRegistry integration if needed)
- **Unlocks**: Production-readiness for biome-dungeon content; safer authoring loop for designers
