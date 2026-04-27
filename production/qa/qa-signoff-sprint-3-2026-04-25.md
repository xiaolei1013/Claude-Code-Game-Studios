# QA Sign-Off Report — Sprint 3

**Sprint**: Sprint 3 — Core Backbone Completion (Enemy DB + BiomeDungeon DB + TD-006 Closure)
**Dates**: 2026-05-25 → 2026-06-05
**Report Date**: 2026-04-25
**Stage**: Pre-Production
**QA Lead**: Approved by QA Lead — 2026-04-25
**Review Mode**: solo (`production/review-mode.txt`)

---

## QA Strategy Verdict

### Story Classification Table

| Story | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|
| S3-M1 `try_award_floor_clear` monotonic ledger | Logic | `tests/unit/economy/economy_try_award_floor_clear_test.gd` ✅ | None | NO |
| S3-M2 EnemyData resource subclass | Logic | `tests/unit/enemy_database/enemy_data_resource_test.gd` ✅ | None | NO |
| S3-M3 EnemyDatabase autoload + accessors | Integration | `tests/integration/enemy_database/enemy_database_autoload_test.gd` ✅ | Smoke check ✅ | NO |
| S3-M4 8 MVP enemy .tres files | Config/Data | `tests/probes/probe_enemy_tres.gd` ✅ | Smoke check ✅ | NO |
| S3-M5 Biome / Dungeon / Floor resource subclasses | Logic | `tests/unit/biome_dungeon_database/biome_dungeon_resource_test.gd` ✅ | None | NO |
| S3-M6 BiomeDungeonDatabase autoload + accessors | Integration | `tests/integration/biome_dungeon_database/biome_dungeon_database_autoload_test.gd` ✅ | Smoke check ✅ | NO |
| S3-M7 Forest Reach MVP biome content | Config/Data | `tests/probes/probe_forest_reach.gd` ✅ | Smoke check ✅ | NO |
| S3-M8 TD-006 smoke closure | Config/Data | (smoke report is the deliverable) | `production/qa/smoke-2026-04-25-sprint3.md` PASS ✅ | NO |

All 8 Must Have stories: automated test evidence present and verified on disk.

### Smoke Check Carry-Forward

**PASS** — Reference: `production/qa/smoke-2026-04-25-sprint3.md` (2026-04-25)

TD-006 CLOSED. DataRegistry transitions to READY state end-to-end. All 6 enforced categories
(classes, enemies, biomes, dungeons, config, items-placeholder-at-0) satisfy `min_content_count`.
`min_content_count.matchup` lowered 1 → 0 per ADR-0009 rationale (matchup is code-level pure-function;
no MVP `.tres` content; mirrors `items` precedent). Logged as TD-007 successor.

The 5 of 8 `hero_class_database_autoload_test.gd` tests that previously graceful-degraded with
`push_warning + return` now ASSERT real data. All 8 tests in that suite pass without warning.

### Phase 4 + Phase 6 Recommendation

**Phase 4 (manual test case writing) and Phase 6 (manual QA execution): SKIPPED.**

Sprint 3 contains zero Visual/Feel and zero UI stories. The 2 UI (UX-spec) stories (S3-S1
main-menu spec, S3-S2 pause-menu spec) were deferred to Sprint 4 stretch — they are in `backlog`
status and out of scope for this close-out. All 8 Must Have stories are Logic (3), Integration (2),
or Config/Data (3). Appropriate evidence for all types is present as automated test files plus the
smoke check report. This is identical to the Sprint 1 and Sprint 2 precedent recorded in
`production/session-state/active.md`.

---

## Test Coverage Summary

| Story | Type | Test File | Tests | Manual QA | Result |
|---|---|---|---|---|---|
| S3-M1 `try_award_floor_clear` monotonic ledger | Logic | `tests/unit/economy/economy_try_award_floor_clear_test.gd` | 19 | None | **PASS** |
| S3-M2 EnemyData resource subclass | Logic | `tests/unit/enemy_database/enemy_data_resource_test.gd` | 10 | None | **PASS** |
| S3-M3 EnemyDatabase autoload + accessors | Integration | `tests/integration/enemy_database/enemy_database_autoload_test.gd` | 7 | Smoke ✅ | **PASS** |
| S3-M4 8 MVP enemy .tres files | Config/Data | `tests/probes/probe_enemy_tres.gd` (8 enemies) | — | Smoke ✅ | **PASS** |
| S3-M5 Biome / Dungeon / Floor resource subclasses | Logic | `tests/unit/biome_dungeon_database/biome_dungeon_resource_test.gd` | 13 | None | **PASS** |
| S3-M6 BiomeDungeonDatabase autoload + accessors | Integration | `tests/integration/biome_dungeon_database/biome_dungeon_database_autoload_test.gd` | 12 | Smoke ✅ | **PASS** |
| S3-M7 Forest Reach MVP biome content | Config/Data | `tests/probes/probe_forest_reach.gd` (5 floors + cross-ref) | — | Smoke ✅ | **PASS** |
| S3-M8 TD-006 smoke closure | Config/Data | (smoke report deliverable) | — | Smoke ✅ | **PASS** |

All 8 stories: PASS.

---

## Aggregate Test Counts

| Suite | File | Tests | Pass | Fail |
|---|---|---|---|---|
| Economy: try_award_floor_clear (S3-M1) | `tests/unit/economy/economy_try_award_floor_clear_test.gd` | 19 | 19 | 0 |
| Enemy: EnemyData resource (S3-M2) | `tests/unit/enemy_database/enemy_data_resource_test.gd` | 10 | 10 | 0 |
| Enemy: EnemyDatabase autoload (S3-M3) | `tests/integration/enemy_database/enemy_database_autoload_test.gd` | 7 | 7 | 0 |
| BiomeDungeon: resource subclasses (S3-M5) | `tests/unit/biome_dungeon_database/biome_dungeon_resource_test.gd` | 13 | 13 | 0 |
| BiomeDungeon: database autoload (S3-M6) | `tests/integration/biome_dungeon_database/biome_dungeon_database_autoload_test.gd` | 12 | 12 | 0 |
| **Sprint 3 net new total** | | **61** | **61** | **0** |

**Probe scripts** (Config/Data evidence, not counted in suite totals):
- `tests/probes/probe_enemy_tres.gd` — 8 enemies validated (tier distribution, archetype distribution,
  `is_boss` exactly one, HP tier-band compliance, sprite_path + death_anim_key non-empty)
- `tests/probes/probe_forest_reach.gd` — Forest Reach 1×5 floors + cross-resource enemy_id resolution
  confirmed; F5 boss floor contains Ancient Rootking
- `tests/probes/probe_data_registry_state.gd` — DataRegistry READY verification (debugging probe;
  not gating; confirms all category counts post-boot)

**Cumulative across Sprint 1 + Sprint 2 + Sprint 3**: 157+ visible test cases / 0 failures.

Sprint 1 known issue: SIGSEGV at engine teardown (commit `3bc8c22`) means full combined-suite
invocation does not always report a clean aggregate exit code. Per-suite invocations are all clean.
Cumulative count is a lower-bound on tests present (157+ visible as of the Sprint 3 smoke check run).

**Regression check**: Sprint 1 and Sprint 2 test suites verified clean post-Sprint-3 content addition.
`hero_class_database_autoload_test.gd` (8 tests) previously graceful-degraded; all 8 now PASS with
real assertions following TD-006 closure.

**Flaky**: 0. **Errors**: 0. **Skipped**: 0.

---

## Bugs Found

**None.**

Zero test failures across 157+ test cases. Zero S1 (Critical) or S2 (Major) bugs. No manual QA
was performed (none required for this sprint type mix). No bugs filed.

| Bug ID | Severity | Summary | Status |
|---|---|---|---|
| — | — | No bugs | — |

---

## Sprint-Close Gates (Solo Mode)

Per `production/review-mode.txt = solo`:

- **LP-CODE-REVIEW**: SKIPPED (solo mode)
- **QL-TEST-COVERAGE**: SKIPPED (solo mode)

---

## Out-of-Scope Deviations Documented in Completion Notes

Five deviations from story boundary were made during Sprint 3 implementation. All five are
documented in the relevant story Completion Notes and are architecturally consistent.

### Deviation 1 — S3-M2: `@export_range` constraints added

**Story**: S3-M2 EnemyData resource subclass
**What changed**: `@export_range` constraints added to `tier`, `base_hp`, `base_attack`, and
`base_speed` fields for inspector safety — authoring guard against out-of-range values.
**Assessment**: Architecturally consistent with HeroClass precedent from Sprint 2 S2-M5. Not
prohibited by story spec; a cosmetic improvement. Not a regression.

### Deviation 2 — S3-M5: typed `Array[Dungeon]` / `Array[Floor]` confirmed working in Godot 4.6

**Story**: S3-M5 Biome / Dungeon / Floor resource subclasses
**What changed**: Story spec noted that a fallback to `Array[Resource]` might be needed if typed
nested-resource arrays failed in Godot 4.6. Fallback was NOT required — `Array[Dungeon]` and
`Array[Floor]` work correctly in Godot 4.6. No deviation from spec; a risk that did not materialize.
**Assessment**: Positive outcome. Typed arrays retained for correctness and IDE support.

### Deviation 3 — S3-M6: `get_floor_by_id` uses cross-dungeon search (Option B)

**Story**: S3-M6 BiomeDungeonDatabase autoload + accessors
**What changed**: `get_floor_by_id(id)` iterates across all dungeons' floor lists to find the floor
by id, rather than a direct registry category lookup. Floors are not in `ORDERED_CATEGORIES` by
design (nested-resource architecture per ADR-0011 — Floors are owned by Dungeons; they are NOT
top-level DataRegistry entries).
**Assessment**: Correct by architecture. Option B (cross-dungeon search) is the appropriate
implementation given the nested-resource data model. Not a performance concern at MVP data volumes.

### Deviation 4 — S3-M7: Biome at biomes/ + Dungeon at dungeons/ via ext_resource; 5 inline sub_resource Floors

**Story**: S3-M7 Forest Reach MVP biome content
**What changed**: Implementation split the biome+dungeon structure across two `.tres` files:
`assets/data/biomes/forest_reach.tres` (Biome, referencing Dungeon via `[ext_resource]`) and
`assets/data/dungeons/forest_reach_dungeon_01.tres` (Dungeon with 5 inline `[sub_resource]` Floor
blocks), rather than a single monolithic `.tres`.
**Assessment**: Consistent with DataRegistry boot-scan expectations. Both
`get_biome_by_id("forest_reach")` and `get_dungeon_by_id("forest_reach_dungeon_01")` resolve via
DataRegistry. Floors resolve via the `get_floor_by_id` cross-dungeon search documented in
Deviation 3. Slightly higher granularity than the single-file recommendation in the story spec, but
cleaner for future dungeon additions.

### Deviation 5 — S3-M8: TD-006 root-cause fix — `min_content_count.matchup` lowered 1 → 0

**Story**: S3-M8 TD-006 smoke closure
**What changed**: `data_registry.gd` `min_content_count["matchup"]` adjusted from 1 to 0. Matchup
is a code-level pure-function per ADR-0009 — there are no MVP matchup config `.tres` files, and
the `matchup/` directory is a forward-compat placeholder only. This mirrors the `items` precedent
where `min_content_count["items"] = 0` was already in place.
**Assessment**: Correct by architecture. The matchup resolver is implemented in GDScript (not driven
by data tables in MVP). Logged as TD-007 successor: raise `min_content_count["matchup"]` back to 1+
when V1.0 matchup config tables land as `.tres` files. Non-blocking; a known-gap placeholder.

---

## Tech Debt Items

| ID | Severity | Description | Gate |
|---|---|---|---|
| TD-007 | NEW — LOW | `min_content_count.matchup = 0` is a forward-compat placeholder. Matchup data tables have no `.tres` representation in MVP. Raise back to 1+ when V1.0 matchup config lands. Manual addition to `docs/tech-debt-register.md` recommended. | Raise when V1.0 matchup config `.tres` files land |
| TD-006 | **CLOSED** this sprint | DataRegistry ERROR-state gap closed by Sprint 3 enemy/biome content + `min_content_count.matchup` adjustment. 5 graceful-degrading integration tests in `hero_class_database_autoload_test.gd` now ASSERT real data. | Closed 2026-04-25 |
| TD-005 | existing — LOW | `tests/gdunit4_runner.gd` broken; CI uses `addons/gdUnit4/bin/GdUnitCmdTool.gd` directly. Unchanged from Sprint 1 + Sprint 2. | No milestone gate assigned |

**Carry-forward (not tech debt — tracked as Sprint 4 candidate):**
- Rank-2 SaveLoadSystem hole: Economy's `get_save_data` / `load_save_data` cross-system testing
  remains incomplete until SaveLoadSystem Foundation epic lands. The consumer-contract integration
  test (`economy_save_load_round_trip_test.gd` per Sprint 2 Story 012) remains deferred.
  This is NOT logged as a tech debt item — it is a planned Sprint 4 story, not a code defect.

TD-001 (MEDIUM, `@abstract` editor-UI probe) and TD-002 (MEDIUM, mobile
`NOTIFICATION_APPLICATION_PAUSED` hardware handshake) carry forward unchanged from Sprint 1 + Sprint 2.

---

## Verdict

**APPROVED WITH CONDITIONS**

All 8 Sprint 3 Must Have stories are Complete. Every Logic and Integration story has passing
automated test evidence at the required path — verified on disk. Both Config/Data stories have
probe scripts and smoke check confirmation. Sprint 3 net new: 61 test cases / 0 failures.
Cumulative 157+ visible cases across Sprint 1 + Sprint 2 + Sprint 3 / 0 failures / 0 errors.
TD-006 closed. No S1 or S2 bugs open or observed.

The single condition is TD-007: `min_content_count.matchup` remains at 0 in `data_registry.gd`.
This is a forward-compat-friendly placeholder — matchup is a code-level pure-function in MVP with
no data-table representation — but it should be raised to 1+ when V1.0 matchup config tables land.
Non-blocking for Sprint 4 start. The `docs/tech-debt-register.md` should receive a manual TD-007
entry before Sprint 4 begins.

---

## Conditions

**TD-007 (LOW) — `min_content_count.matchup = 0` placeholder**

`data_registry.gd` currently accepts zero matchup entries as a READY condition. This is correct
for MVP (the matchup resolver is pure GDScript, not data-driven at Sprint 3). When V1.0 matchup
config tables land as `.tres` files under `assets/data/matchup/`, raise `min_content_count["matchup"]`
back to 1+ and author a probe script to validate the matchup content count at boot.

Recommended action before Sprint 4 begins:
1. Add TD-007 entry to `docs/tech-debt-register.md` (manual step; QA Lead cannot write that file
   without a story in scope).
2. No code change required now — the placeholder is intentional.

---

## Next Step

Build is ready for `/gate-check production` to validate Pre-Production → Production stage
advancement.

Note: this gate is expected to still return FAIL at this point. The Pre-Production → Production
gate requires Vertical Slice Validation (4/4 items: playable loop, player-facing UI, save/load
round-trip, first playtest pass), none of which are satisfied by Sprint 3. Sprint 3's contribution
is the complete Core data backbone (Enemy DB + BiomeDungeon DB + Economy + HeroClass DB +
DataRegistry reaching READY state) that makes the Vertical Slice buildable in Sprint 4+. Running
the gate check will confirm the remaining blockers and produce a prioritized plan for Sprint 4.
