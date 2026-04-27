# Story 003: Forest Reach MVP biome content (1 dungeon × 5 floors)

> **Epic**: biome-dungeon-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/biome-dungeon-database.md` §C, §D, §H-01, §H-02, §H-03, §H-05
**Requirements**: TR-biome-dungeon-db-026, TR-biome-dungeon-db-027, TR-biome-dungeon-db-028
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (`.tres` authoring + cross-resource enemy_id resolution)
**ADR Decision Summary**: Forest Reach is the MVP biome: exactly 1 dungeon × 5 floors with `floor_index {1..5}` gap-free. Exactly one floor (F5) has `is_boss_floor = true` and contains the Ancient Rootking. Each floor's `enemy_list` references valid Enemy DB ids (cross-resource validation in Story 004).

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Core Layer)**:
- **Required**: Forest Reach exactly 1 dungeon × 5 floors. — TR-biome-dungeon-db-026
- **Required**: F5 is boss floor; contains Ancient Rootking. — TR-biome-dungeon-db-027
- **Required**: All `enemy_id` references must resolve via EnemyDatabase. — ADR-0011

---

## Acceptance Criteria

- [ ] `assets/data/biomes/forest_reach.tres` exists with `id="forest_reach"`, `status="active"`, `display_name="Forest Reach"`, non-empty `flavor_text`, `dominant_archetypes` listing the archetypes that appear in floors 1-4
- [ ] `Forest Reach` Biome contains exactly 1 Dungeon (e.g. `forest_reach_main`)
- [ ] **TR-biome-dungeon-db-026 + AC H-02**: dungeon contains exactly 5 Floors with `floor_index ∈ {1, 2, 3, 4, 5}` gap-free
- [ ] **AC H-03**: `floor_index` values unique within the dungeon, sequential, gap-free
- [ ] **TR-biome-dungeon-db-027 + AC H-05**: exactly one floor has `is_boss_floor = true` (F5); F5's `enemy_list` contains the Ancient Rootking enemy_id
- [ ] All 5 floors have non-empty `enemy_list` (Story 004 validator enforces this; here we assert content)
- [ ] **AC H-04**: each floor's `enemy_list` entries reference valid enemy ids (exist in EnemyDatabase from Sprint 3 Story 003); cross-resource resolution succeeds at boot
- [ ] **TR-biome-dungeon-db-028**: `Biome.dungeons` Array supports length > 1 (forward-compat); MVP uses 1
- [ ] All resources resolvable via `BiomeDungeonDatabase.get_biome_by_id("forest_reach")` and `get_floors_for_dungeon("forest_reach_main")` after boot scan
- [ ] `design/registry/entities.yaml` updated with Forest Reach biome + dungeon + 5 floor entries (or confirmed already present from Sprint 1 prior art)

---

## Implementation Notes

*Derived from ADR-0011 §Decision + GDD §D pacing tables:*

- Author the .tres via Godot inspector (or hand-author text format mirroring Sprint 2 + Sprint 3 .tres precedent).
- Suggested structure (concrete ids):
  - `assets/data/biomes/forest_reach.tres` — Biome with `dungeons = [forest_reach_main]`
  - The Biome holds dungeons inline. Dungeons hold floors inline. So the entire Biome+Dungeon+5Floors structure may live in a SINGLE `.tres` file (`forest_reach.tres`) with nested resources, OR split across multiple `.tres` if standalone Dungeon/Floor resources are preferred for hot-reload granularity.
  - Decision at story pickup: the GDD §C suggests "Biome owns Dungeon owns Floor" composition, which is consistent with a single nested-resource .tres. Recommend single-file authoring for MVP (simpler), with the option to split later if needed.
- Floor enemy_list authoring per GDD §D pacing tables. Example F1:
  ```
  enemy_list = [
      { "enemy_id": "hollow_brute", "count": 3 },
      { "enemy_id": "bog_caster", "count": 2 },
  ]
  ```
- F5 (boss floor): `is_boss_floor = true`, `enemy_list` contains `{ "enemy_id": "ancient_rootking", "count": 1 }` plus optional minion entries
- Floor `expected_clear_time_seconds` per GDD §D pacing tables (e.g., F1 ~30s; scales upward to F5 minutes).
- Floor `flavor_text` ≤ 120 chars per advisory limit.
- Biome `dominant_archetypes` — derive from F1-F4 enemy mix (not F5 because boss floor doesn't determine the biome's archetype identity).

---

## Out of Scope

- Story 004: load-time validation (ensures enemy_id refs resolve, etc.)
- Story 005: V1.0 stub biome content
- V1.0 multi-dungeon biomes (TR-biome-dungeon-db-028 forward-compat declared but not exercised in MVP)
- Sprite art / palette swatches (separate `/asset-spec` work)

---

## QA Test Cases

- **AC: Forest Reach loads**
  - **Given**: `forest_reach.tres` (and any nested files) at `assets/data/biomes/`
  - **When**: `BiomeDungeonDatabase.get_biome_by_id("forest_reach")`
  - **Then**: returns non-null Biome with expected schema values; `dungeons.size() == 1`
  - **Edge cases**: malformed .tres triggers DataRegistry ERROR

- **AC H-02 + TR-biome-dungeon-db-026: 1 dungeon × 5 floors**
  - **Given**: Forest Reach loaded
  - **When**: traverse `biome.dungeons[0].floors`
  - **Then**: array length is exactly 5
  - **Edge cases**: > 5 or < 5 → fail

- **AC H-03 + TR-biome-dungeon-db-026: floor_index gap-free**
  - **Given**: 5 floors loaded
  - **When**: collect `floor_index` values
  - **Then**: sorted set equals `{1, 2, 3, 4, 5}` exactly; no duplicates, no gaps
  - **Edge cases**: any deviation → Story 004 validator rejects at load

- **AC H-05 + TR-biome-dungeon-db-027: exactly one boss floor**
  - **Given**: 5 floors loaded
  - **When**: count floors with `is_boss_floor == true`
  - **Then**: exactly 1; that floor has `floor_index == 5`; its `enemy_list` contains an entry with `enemy_id == "ancient_rootking"`
  - **Edge cases**: 0 boss floors → fail; 2+ boss floors → fail

- **AC: enemy_id references resolve**
  - **Given**: Forest Reach loaded; EnemyDatabase loaded with 7+ MVP enemies
  - **When**: for each floor, for each `enemy_list` entry, call `EnemyDatabase.get_by_id(entry.enemy_id)`
  - **Then**: every lookup returns non-null
  - **Edge cases**: any enemy_id mismatch → Story 004 validator rejects + cascades to UNAVAILABLE state for that Floor

- **AC: entities.yaml registration**
  - **Given**: `design/registry/entities.yaml` post-update
  - **When**: parse the YAML
  - **Then**: Forest Reach + dungeon + 5 floor entries present; cross-check Sprint 1 prior art
  - **Edge cases**: missing entry triggers entity-registry consistency-check failure

- **Smoke check**: full boot + Forest Reach traversal
  - **Given**: clean Godot project with all enemy + biome `.tres` in place
  - **When**: `godot --headless --quit-after 1` boots
  - **Then**: zero ERROR-level logs; **DataRegistry transitions to READY** (TD-006 closure); Forest Reach traversal succeeds

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `assets/data/biomes/forest_reach.tres` (and any nested `.tres` if split)
- `design/registry/entities.yaml` updated
- `tests/probes/probe_biome_dungeon_tres.gd` (one-shot probe — mirror Sprint 2 / Sprint 3 probe patterns)
- A passing smoke check report at `production/qa/smoke-*.md` confirming DataRegistry READY end-to-end

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (Biome/Dungeon/Floor schemas), Story 002 (BiomeDungeonDatabase autoload), Sprint 3 enemy-database Story 003 (enemy `.tres` files for enemy_id resolution)
- **Unlocks**: Sprint 3 S3-M8 (TD-006 smoke verification — Forest Reach + 7+ enemies satisfy all min_content_count thresholds for DataRegistry READY); FloorUnlockSystem + DungeonRunOrchestrator Feature epics
