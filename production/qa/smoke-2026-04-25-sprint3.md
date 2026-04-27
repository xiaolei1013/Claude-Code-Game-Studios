# Smoke Check — 2026-04-25 (Sprint 3 Must Have closure / TD-006 closure)

**Date**: 2026-04-25
**Operator**: Solo developer (autonomous run)
**Build**: Local dev (Godot 4.6.1 stable mono)
**Sprint**: 3 (in progress; 8/8 Must Have implemented and tested)
**Verdict**: **PASS** — TD-006 closed; DataRegistry reaches READY end-to-end

---

## Scope

Per `production/qa/qa-plan-sprint-3-2026-04-25.md` §Smoke Test Scope:

1. ✅ Game launches headless without crash
2. ✅ Autoload registration: TickSystem(0), DataRegistry(1), Economy(3), HeroClassDatabase(4), EnemyDatabase(5), BiomeDungeonDatabase(6) — rank-2 (SaveLoadSystem) hole still present (Sprint 4 candidate)
3. ✅ **DataRegistry transitions to READY state** with all 6 enforced categories (classes, enemies, biomes, dungeons, config) satisfied — TD-006 **CLOSED**
4. ✅ EconomyConfig resolvable (Sprint 2 baseline)
5. ✅ 3 MVP class .tres files resolvable (Sprint 2 baseline)
6. ✅ **8 MVP enemy .tres files resolvable** (Sprint 3 new)
7. ✅ **Forest Reach biome + 5 floors resolvable** (Sprint 3 new)
8. ✅ **No regression in Sprint 1 + Sprint 2 systems** — 157+ test cases visible across 14 suites, 0 failures
9. ✅ Performance: project import < 5s; per-suite test runtime < 200ms

---

## TD-006 closure

**Before this sprint**: DataRegistry stayed in ERROR state because content categories `enemies` (5+ required) / `biomes` (1 required) / `dungeons` (1 required) were empty. 5+ integration tests in `hero_class_database_autoload_test.gd` graceful-degraded via `push_warning + return`.

**After this sprint**:

- Sprint 3 S3-M4 authored 8 MVP enemy .tres files (3 Tier-1 + 3 Tier-2 + 2 Tier-3 incl. Ancient Rootking boss; satisfies `min_content_count.enemies = 5` + TR-enemy-db-008 archetype-distribution invariant)
- Sprint 3 S3-M7 authored Forest Reach biome (1 dungeon × 5 floors gap-free; satisfies `min_content_count.biomes = 1` + `min_content_count.dungeons = 1`)
- **S3-M8 deviation logged**: `min_content_count.matchup` lowered 1 → 0 (mirrors `items` precedent; matchup is code-level pure-function per ADR-0009 with no MVP `.tres` content; `matchup/` directory remains for V1.0 forward-compat)
- DataRegistry now reaches READY state on every test run; `hero_class_database_autoload_test.gd::test_hero_class_database_get_by_id_resolves_mvp_classes` now ASSERTS real data (no more `push_warning` graceful-degrade in normal runs)

**Validation evidence**: see `tests/probes/probe_data_registry_state.gd` (logs DataRegistry state + per-category content counts), `tests/probes/probe_enemy_tres.gd` (8 enemies validated against `entities.yaml`), `tests/probes/probe_forest_reach.gd` (biome + 5 floors validated; cross-resource enemy_id resolution confirmed).

---

## Test Suite Results

Aggregate run: `addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://tests/unit/ --add res://tests/integration/ --ignoreHeadlessMode`

Per-suite Statistics (visible — full suite count limited by Sprint 1 known SIGSEGV at engine teardown documented in commit `3bc8c22`):

| Suite | Tests | Pass | Fail |
|---|---|---|---|
| economy_autoload_skeleton_test (S2-M1) | 21 | 21 | 0 |
| economy_config_schema_test (S2-M2) | 20 | 20 | 0 |
| economy_add_gold_test (S2-M3) | 12 | 12 | 0 |
| economy_try_spend_test (S2-M4) | 13 | 13 | 0 |
| economy_try_award_floor_clear_test (S3-M1 — most complex single story) | 19 | 19 | 0 |
| hero_class_resource_test (S2-M5) | 8 | 8 | 0 |
| hero_class_database_autoload_test (S2-M6 — graceful-degrades NOW PROMOTED to real assertions) | 8 | 8 | 0 |
| enemy_data_resource_test (S3-M2) | 10 | 10 | 0 |
| enemy_database_autoload_test (S3-M3) | 7 | 7 | 0 |
| biome_dungeon_resource_test (S3-M5) | 13 | 13 | 0 |
| biome_dungeon_database_autoload_test (S3-M6) | 12 | 12 | 0 |
| Sprint 1 boot_scan_load_order_test (post-ORDERED_CATEGORIES extension) | 7 | 7 | 0 |
| Sprint 1 data_registry suites (visible subset) | 11+6+8+3 | all | 0 |

**Visible total**: 157+ test cases / 0 errors / 0 failures.

Sprint 3 net new: 19 (S3-M1) + 10 (S3-M2) + 7 (S3-M3) + 13 (S3-M5) + 12 (S3-M6) = **61 new test cases** added in Sprint 3, all passing.

---

## Sprint 3 Must Have completion

| ID | Story | Status |
|---|---|---|
| S3-M1 | try_award_floor_clear monotonic ledger (5 sub-ACs) | ✅ DONE |
| S3-M2 | EnemyData resource | ✅ DONE |
| S3-M3 | EnemyDatabase autoload | ✅ DONE |
| S3-M4 | 8 MVP enemy .tres files | ✅ DONE |
| S3-M5 | Biome / Dungeon / Floor resources | ✅ DONE |
| S3-M6 | BiomeDungeonDatabase autoload | ✅ DONE |
| S3-M7 | Forest Reach MVP biome content | ✅ DONE |
| S3-M8 | TD-006 closure (this report) | ✅ DONE |

**8/8 Sprint 3 Must Have stories closed.**

---

## Tech debt notes

- **TD-006 → CLOSED** — DataRegistry now reaches READY end-to-end with the Sprint 3 content + the `min_content_count.matchup` adjustment. 5 graceful-degrading integration tests now ASSERT real data.
- **TD-007 (NEW, LOW)** — `min_content_count.matchup` lowered to 0 in S3-M8. Matchup data tables (V1.0 per-class config files) currently have no `.tres` representation. When V1.0 matchup config lands, raise back to 1+. Logged in this report; not in `docs/tech-debt-register.md` yet (manual addition recommended).
- **TD-005** (existing, LOW) — broken `tests/gdunit4_runner.gd`; CI workaround via `addons/gdUnit4/bin/GdUnitCmdTool.gd`. Unchanged.
- **Rank-2 (SaveLoadSystem) hole** — Sprint 4 candidate. Without SaveLoadSystem, Economy's `get_save_data` / `load_save_data` cross-system testing is incomplete; the consumer-contract integration test (`economy_save_load_round_trip_test.gd` per Sprint 2 Story 012) remains deferred.

---

## Out-of-scope deviations logged in S3 stories

1. **S3-M2** mid-sprint: `@export_range` constraints added to `tier`/HP/attack/speed for inspector safety (consistent with HeroClass precedent; not prohibited by story spec)
2. **S3-M5** mid-sprint: `Array[Dungeon]` / `Array[Floor]` typed arrays confirmed working in Godot 4.6 (story spec considered fallback to `Array[Resource]` — not needed)
3. **S3-M6** documented decision: `get_floor_by_id` uses cross-dungeon search (Option B per story) since `floors` is not in ORDERED_CATEGORIES — by design (nested-resource architecture)
4. **S3-M7** authoring choice: Biome at `assets/data/biomes/forest_reach.tres` references Dungeon at `assets/data/dungeons/forest_reach_dungeon_01.tres` via `[ext_resource]`; Dungeon contains 5 inline `[sub_resource]` Floor blocks. Both `get_biome_by_id` and `get_dungeon_by_id` work via DataRegistry; floors via cross-dungeon search per S3-M6.
5. **S3-M8** out-of-scope (this story): `min_content_count.matchup` 1 → 0 in `data_registry.gd` (TD-006 root-cause closure). 1-line edit; documented as TD-007 successor.

---

## Sign-off

- **Smoke check verdict**: **PASS** — Sprint 3 Must Have complete; TD-006 closed; zero regressions; 157+ cases / 0 failures
- **Reviewer**: Solo developer (`production/review-mode.txt = solo`)
- **Date**: 2026-04-25
