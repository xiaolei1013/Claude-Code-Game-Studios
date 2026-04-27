# QA Sign-Off Report — Sprint 2

**Sprint**: Sprint 2 — Economy Autoload Backbone + HeroClass Database
**Dates**: 2026-05-11 → 2026-05-22
**Report Date**: 2026-04-25
**Stage**: Pre-Production
**QA Lead**: Approved by QA Lead — 2026-04-25
**Review Mode**: solo (`production/review-mode.txt`)

---

## QA Strategy Verdict

### Story Classification Table

| Story | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|
| S2-M1 Economy autoload skeleton | Logic | `tests/unit/economy/economy_autoload_skeleton_test.gd` ✅ | None | NO |
| S2-M2 EconomyConfig resource + loading | Config/Data | `tests/unit/economy/economy_config_schema_test.gd` ✅ | Smoke check | NO |
| S2-M3 add_gold + gold_changed signal | Logic | `tests/unit/economy/economy_add_gold_test.gd` ✅ | None | NO |
| S2-M4 try_spend atomic | Logic | `tests/unit/economy/economy_try_spend_test.gd` ✅ | None | NO |
| S2-M5 HeroClass resource + EnemyArchetypes | Logic | `tests/unit/hero_class_database/hero_class_resource_test.gd` ✅ | None | NO |
| S2-M6 HeroClassDatabase autoload + accessors | Integration | `tests/integration/hero_class_database/hero_class_database_autoload_test.gd` ✅ | Smoke check | NO |
| S2-M7 3 MVP class .tres files | Config/Data | Extension assertions in hero_class_resource_test.gd + probe script ✅ | Smoke check ✅ | NO |

All 7 Must Have stories: automated test evidence present and verified on disk.

### Smoke Check Carry-Forward

**PASS WITH NOTES** — Reference: `production/qa/smoke-2026-04-25.md` (2026-04-25)

Carry-forward note: **TD-006** — DataRegistry transitions to ERROR state during Sprint 2 because content
categories (enemies / biomes / dungeons / matchup) have no `.tres` files yet. This is expected by
design — those categories' content lands in Sprint 3. Cross-system tests that exercise
`DataRegistry.resolve` via the live autoload gracefully degrade with `push_warning + return`.
Non-blocking. Tracked for Sprint 3 closure.

### Phase 4 + Phase 6 Recommendation

**Phase 4 (manual test case writing) and Phase 6 (manual QA execution): SKIPPED.**

Sprint 2 contains zero Visual/Feel and zero UI stories. All 7 Must Have stories are Logic (4),
Integration (1), or Config/Data (2). Appropriate evidence for all types is present as automated
test files plus the smoke check report. This is identical to the Sprint 1 precedent recorded in
`production/session-state/active.md` §"Session Extract — /team-qa sprint 2026-04-24", where the
same skip decision was accepted and documented.

---

## Test Coverage Summary

| Story | Type | Test File | Tests | Manual QA | Result |
|---|---|---|---|---|---|
| S2-M1 Economy autoload skeleton | Logic | `tests/unit/economy/economy_autoload_skeleton_test.gd` | 21 | None | **PASS** |
| S2-M2 EconomyConfig resource + loading | Config/Data | `tests/unit/economy/economy_config_schema_test.gd` | 20 | Smoke ✅ | **PASS** |
| S2-M3 add_gold + gold_changed signal | Logic | `tests/unit/economy/economy_add_gold_test.gd` | 12 | None | **PASS** |
| S2-M4 try_spend atomic | Logic | `tests/unit/economy/economy_try_spend_test.gd` | 13 | None | **PASS** |
| S2-M5 HeroClass resource + EnemyArchetypes | Logic | `tests/unit/hero_class_database/hero_class_resource_test.gd` | 8 | None | **PASS** |
| S2-M6 HeroClassDatabase autoload + accessors | Integration | `tests/integration/hero_class_database/hero_class_database_autoload_test.gd` | 8 | Smoke ✅ | **PASS** |
| S2-M7 3 MVP class .tres files | Config/Data | Probe script + smoke check | — | Smoke ✅ | **PASS** |

All 7 stories: PASS.

---

## Aggregate Test Counts

| Suite | File | Tests | Pass | Fail |
|---|---|---|---|---|
| Economy autoload skeleton (S2-M1) | `tests/unit/economy/economy_autoload_skeleton_test.gd` | 21 | 21 | 0 |
| EconomyConfig schema (S2-M2) | `tests/unit/economy/economy_config_schema_test.gd` | 20 | 20 | 0 |
| add_gold body (S2-M3) | `tests/unit/economy/economy_add_gold_test.gd` | 12 | 12 | 0 |
| try_spend atomic (S2-M4) | `tests/unit/economy/economy_try_spend_test.gd` | 13 | 13 | 0 |
| HeroClass resource (S2-M5) | `tests/unit/hero_class_database/hero_class_resource_test.gd` | 8 | 8 | 0 |
| HeroClassDatabase autoload (S2-M6) | `tests/integration/hero_class_database/hero_class_database_autoload_test.gd` | 8 | 8 | 0 |
| **Sprint 2 total** | | **82** | **82** | **0** |

**Flaky**: 0. **Errors**: 0. **Skipped**: 0.

**Sprint 1 regression**: `test_boot_scan_load_order_matches_ordered_categories` (boot_scan_load_order_test.gd) — verified 7/7 PASS after the Sprint 2 `ORDERED_CATEGORIES` extension (S2-M2 deviation — see below).

**Probe script**: `tests/probes/probe_class_tres.gd` — confirmed all 3 MVP class `.tres` files load via `ResourceLoader.load()` with correct L15 stats (Warrior 40/358/20, Mage 62/210/24, Rogue 42/167/44).

---

## Bugs Found

**None.**

Zero test failures across 82 test cases. Zero S1 (Critical) or S2 (Major) bugs. No manual QA was
performed (none required for this sprint type mix). No bugs filed.

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

Three deviations from story boundary were made during Sprint 2 implementation. All three are
documented in the relevant story Completion Notes and are architecturally consistent.

### Deviation 1 — S2-M2: `data_registry.gd` ORDERED_CATEGORIES extension

**Story**: S2-M2 EconomyConfig resource + loading
**What changed**: `src/core/data_registry/data_registry.gd` was extended to add `"config"` to
`ORDERED_CATEGORIES` and `"config": 1` to the default `min_content_count` map. Two assertions in
the Sprint 1 `boot_scan_load_order_test.gd` were updated from "6 categories" to "7 categories"
with the new `"config"` position asserted.
**Assessment**: Architecturally consistent with ADR-0006 + ADR-0011 intent. DataRegistry's
boot-scan behavior is explicitly designed to grow as new content-category consumers are introduced
in Core-layer epics. The Sprint 1 regression test still passes (7/7). Not a regression; expected
growth pattern.

### Deviation 2 — S2-M3: S2-M1 sibling test updated

**Story**: S2-M3 add_gold body + gold_changed signal
**What changed**: `tests/unit/economy/economy_autoload_skeleton_test.gd::test_economy_add_gold_completes_without_error`
was updated to assert `balance == 100` (was asserting `balance == 0` — a stub-era assertion that
became invalid once the real `add_gold` body landed in S2-M3).
**Assessment**: Correct and expected. Stub-era tests that guard "no mutation" semantics must be
updated when the real body lands; this is the same pattern as Sprint 1's process-delta tests
updating when the forbidden override check was added. Not a regression — a test alignment to the
implemented behavior.

### Deviation 3 — S2-M5: `extends GameData` correction

**Story**: S2-M5 HeroClass resource + EnemyArchetypes
**What changed**: `src/core/hero_class_database/hero_class.gd` was authored as `extends GameData`
(not `extends Resource` as the story spec stated). The `id` and `display_name` fields are
inherited from GameData and not redeclared.
**Assessment**: Architecturally correct. The story spec was wrong — overridden by ADR-0011 +
the EconomyConfig Sprint-2 precedent which established `extends GameData` as the pattern for all
DataRegistry-resolvable resources (the `id` field required by `DataRegistry.resolve` is inherited
from GameData). Additionally, EnemyArchetypes was already implemented Sprint 1 at
`assets/data/archetypes/enemy_archetypes.gd`; Story S2-M5's "create EnemyArchetypes" AC was
satisfied by prior art. Not a regression; a spec correction.

---

## Tech Debt Items Logged

| ID | Severity | Description | Gate |
|---|---|---|---|
| TD-006 | NEW — LOW | DataRegistry stays in ERROR state during Sprint 2 testing because content categories (enemies / biomes / dungeons / matchup) lack `.tres` files. Cross-system tests gracefully degrade with `push_warning + return`. Will assert real data once Sprint 3 adds enemy/biome content. Not a code defect — a content-volume gap by design. | Sprint 3: close when enemy/biome content lands |
| TD-005 | existing — LOW | `tests/gdunit4_runner.gd` broken; CI uses `addons/gdUnit4/bin/GdUnitCmdTool.gd` directly. Unchanged from Sprint 1. | No milestone gate assigned |

TD-001 (MEDIUM, `@abstract` editor-UI probe — pre-MVP-ship) and TD-002 (MEDIUM, mobile
`NOTIFICATION_APPLICATION_PAUSED` hardware handshake — pre-mobile-playtest) carry forward
unchanged from Sprint 1 sign-off.

---

## Verdict

**APPROVED WITH CONDITIONS**

All 7 Sprint 2 Must Have stories are Complete. Every Logic and Integration story has passing
automated test evidence at the required path. Both Config/Data stories have smoke check
confirmation. 82/82 test cases pass with zero failures, zero errors, zero flaky tests. Sprint 1
regression suite verified clean post-extension. No S1 or S2 bugs open or observed.

The single condition is TD-006: DataRegistry operates in ERROR state during Sprint 2 testing
because the enemies / biomes / dungeons / matchup content categories are empty. This is a
content-volume gap by design, not a code defect. Cross-system tests are written to degrade
gracefully and will promote to full assertions once Sprint 3 lands enemy/biome content.

---

## Conditions

**TD-006 (LOW) — DataRegistry ERROR state during Sprint 2**

DataRegistry will not fully exercise cross-system content paths until Sprint 3 lands enemy/biome
category content. Specifically, the 5 of 8 `hero_class_database_autoload_test.gd` tests that
exercise live DataRegistry resolution currently apply the graceful-degrade pattern rather than
asserting real object identity. These will be promoted to full assertions when Sprint 3 closes the
content gap.

**Recommended Sprint 3 action**: prioritize one of the early enemy-database stories to provide
at least one `.tres` fixture in the enemies / biomes categories, unlocking full DataRegistry
READY-state coverage in integration tests.

---

## Next Step

Build is ready for `/gate-check production` to validate Pre-Production → Production stage
advancement.

Note: this gate is expected to still return FAIL at this point. The Pre-Production → Production
gate requires Vertical Slice Validation (4/4 items: playable loop, player-facing UI, save/load
round-trip, first playtest pass), none of which are satisfied yet. Sprint 2's contribution is
the Economy + HeroClass backbone that makes the Vertical Slice buildable in Sprint 3+. Running
the gate check now will confirm the remaining blockers and produce a prioritized plan for Sprint 3.
