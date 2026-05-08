# Sprint 2 — 2026-05-11 to 2026-05-22

> **Generated**: 2026-04-25 by `/sprint-plan` (autonomous; solo review mode)
> **Status**: Complete (elapsed; closed by sprint-3 kickoff. Sprint plan retained for historical audit.)
> **Engine**: Godot 4.6 (pinned 2026-02-12)

## Sprint Goal

Land the Economy autoload backbone + the HeroClass database, so Sprint 3 can
build a Vertical Slice harness on real Core-layer data instead of mocks.

## Capacity

- Total: 10 working days × 2 effective hours/day = 20 effective hours
- Buffer (20%): 4 h reserved for unplanned work / Sprint 1 tech-debt
- Available: 16 h for new stories
- Sprint 1 baseline: 9 stories, ~20 effective hours delivered (compressed)

## Tasks

### Must Have (Critical Path)

| ID | Task | Story File | Est. (h) | Depends On | ADR(s) |
|----|------|-----------|----------|-----------|--------|
| S2-M1 | Economy autoload skeleton + signals + zero-arg `_init` | [economy-system/story-001](../epics/economy-system/story-001-economy-autoload-skeleton.md) | 2 | Sprint 1 (TickSystem rank 0 + DataRegistry rank 1 landed) | ADR-0013, ADR-0003 |
| S2-M2 | EconomyConfig resource + tuning knob loading via DataRegistry | [economy-system/story-002](../epics/economy-system/story-002-economy-config-resource-and-loading.md) | 3 | S2-M1 + data-registry epic Story 002 (GameData base) + Story 005 (per-type validators) | ADR-0011, ADR-0006, ADR-0013 |
| S2-M3 | add_gold body + gold_changed signal + sanity cap clamp | [economy-system/story-003](../epics/economy-system/story-003-add-gold-and-gold-changed-signal.md) | 2 | S2-M2 | ADR-0013 |
| S2-M4 | try_spend atomic — insufficient/sufficient/zero/negative | [economy-system/story-004](../epics/economy-system/story-004-try-spend-atomic.md) | 2 | S2-M1 | ADR-0013 |
| S2-M5 | HeroClass resource + EnemyArchetypes constants | [hero-class-database/story-001](../epics/hero-class-database/story-001-hero-class-resource-and-archetype-constants.md) | 2 | None | ADR-0011 |
| S2-M6 | HeroClassDatabase autoload + accessors | [hero-class-database/story-002](../epics/hero-class-database/story-002-hero-class-database-autoload-and-accessors.md) | 2 | S2-M5 + Sprint 1 DataRegistry resolve | ADR-0011, ADR-0006, ADR-0003 |
| S2-M7 | 3 MVP class .tres files (warrior/mage/rogue) | [hero-class-database/story-003](../epics/hero-class-database/story-003-mvp-class-tres-files.md) | 2 | S2-M5, S2-M6 | ADR-0011 |

**Must Have total**: 15 h

### Should Have

| ID | Task | Story File | Est. (h) | Depends On | ADR(s) |
|----|------|-----------|----------|-----------|--------|
| S2-S1 | try_award_floor_clear monotonic-credit ledger (5 sub-ACs) | [economy-system/story-005](../epics/economy-system/story-005-try-award-floor-clear-monotonic-ledger.md) | 4 | S2-M3 | ADR-0002, ADR-0013 |
| S2-S2 | stat_at_level helper + L15 sanity + level clamp | [hero-class-database/story-004](../epics/hero-class-database/story-004-stat-at-level-helper.md) | 2 | S2-M5, S2-M7 | ADR-0011 |

**Should Have total**: 6 h

### Nice to Have (Stretch)

| ID | Task | Story File | Est. (h) | Depends On | ADR(s) |
|----|------|-----------|----------|-----------|--------|
| S2-N1 | is_class_counter helper | [hero-class-database/story-006](../epics/hero-class-database/story-006-is-class-counter.md) | 1 | S2-M5 | ADR-0011 |
| S2-N2 | HeroClass schema validation at load time | [hero-class-database/story-008](../epics/hero-class-database/story-008-schema-validation-at-load.md) | 3 | S2-M5 + data-registry per-type validator | ADR-0011, ADR-0006 |

**Nice to Have total**: 4 h

**Sprint scope**: 25 h max ceiling vs 20 h delivery target. Must Have is the
contractual bar; Should Have lands when Must Have closes early; Nice to Have
is bonus.

## Carryover from Sprint 1

None. Sprint 1 closed all 9 stories with **COMPLETE WITH NOTES** verdict.

Sprint 1 tech-debt register (advisory; tracked separately, NOT in Sprint 2 scope):
- TD-001 `@abstract` editor-UI probe on Godot 4.6 — pre-MVP-ship gate
- TD-002 mobile `NOTIFICATION_APPLICATION_PAUSED` hardware handshake — pre-mobile-playtest gate
- Advisory: Typed per-category DataRegistry accessors deferred to per-DB consumer stories (Story S2-M6 picks up the HeroClass-typed accessor)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ADR-0013 §Decision references `attribute_kill_gold` as 8th method, but the ADR text describes "7 methods + 2 signals" — Story 007 flagged this | MEDIUM | LOW | Re-read ADR-0013 at S2-M1 start; if a clarifying amendment is needed, file `/architecture-decision` mid-sprint and fold into the 4 h buffer |
| `EconomyConfig.tres` field shape may drift from GDD §G's 26 knobs during inspector authoring | MEDIUM | MEDIUM | S2-M2 AC explicitly asserts 26-knob count + per-knob name + safe-range; cross-check against GDD §G as the ACCEPTANCE for that story |
| S2-S1 (monotonic ledger) is the most complex story; 5 sub-ACs + cross-system invariants | MEDIUM | HIGH | If estimate slips beyond 5 h, descope to a Sprint 3 candidate rather than cutting Must Have |
| HeroClass schema field count + types may drift between Story 001 and `.tres` files in Story 003 | LOW | MEDIUM | S2-M7 has explicit "matches §D.4 sanity table at L15" assertion — catches drift via Story 004 once it lands |
| Sprint 1 TD-001/TD-002 surface as bugs in S2 | LOW | LOW | Park; not Sprint 2 scope |

## Dependencies on External Factors

- All needed Foundation infrastructure landed in Sprint 1 (TickSystem rank 0, DataRegistry rank 1, partial validation chain)
- ADR-0013 + ADR-0014 + ADR-0011 + ADR-0006 + ADR-0005 + ADR-0003 + ADR-0002 all Accepted
- No external blockers

## Definition of Done

- [ ] All Must Have stories closed via `/story-done` with passing tests
- [ ] All Logic stories have unit tests in `tests/unit/economy/` or `tests/unit/hero_class_database/`
- [ ] Integration story (S2-M6) has integration test in `tests/integration/hero_class_database/`
- [ ] Smoke check passes (`/smoke-check sprint`)
- [ ] QA sign-off APPROVED or APPROVED WITH CONDITIONS via `/team-qa sprint`
- [ ] `assets/data/config/economy_config.tres` populated with all 26 knobs
- [ ] 3 MVP class `.tres` files present in `assets/data/classes/`
- [ ] `design/registry/entities.yaml` updated with 3 new class entries
- [ ] No S1 or S2 bugs in delivered features
- [ ] Sprint retrospective in `production/retrospectives/sprint-2.md`

## What this sprint deliberately does NOT include (rationale)

- **Save/Load Foundation epic** — HIGH risk + HMAC from scratch; deserves a dedicated Sprint 3
- **Scene-manager Foundation epic** — needed for UI but not for Economy-only validation work; Sprint 3 candidate
- **economy-system Stories 006/007/010/011/012/013** — drip per tick (006) needs DungeonRunOrchestrator mock; offline batch (010/011) is heavy; save-load (012) is blocked on Save/Load Foundation; CI grep (013) defer until more code exists to enforce
- **enemy-database / biome-dungeon-database epics** — stories not yet authored; their decomposition depends on `EnemyArchetypes` (S2-M5) being published. Schedule `/create-stories enemy-database` mid-Sprint 2 after S2-M5 lands; same for biome-dungeon-database

## QA Plan

✅ **QA Plan**: [`production/qa/qa-plan-sprint-2-2026-04-25.md`](../qa/qa-plan-sprint-2-2026-04-25.md)

Type breakdown: 8 Logic + 1 Integration + 2 Config/Data + 0 Visual/Feel + 0 UI.
Heavy automated coverage; light manual QA (smoke check + entity-registry diff
only). Zero playtest sessions required this sprint. ~110 unit/integration test
cases projected across 11 stories.

## Scope Check

> If stories are added beyond the original epic scope during sprint execution,
> run `/scope-check economy-system` and `/scope-check hero-class-database` to
> detect scope creep before implementation begins.

## Reference

- Previous sprint: [`sprint-1.md`](sprint-1.md) — closed 2026-04-24, COMPLETE WITH NOTES
- Sprint status (machine-readable): [`../sprint-status.yaml`](../sprint-status.yaml)
- Epic index: [`../epics/index.md`](../epics/index.md)
- Pre-Production gate report: [`../gate-checks/2026-04-24-technical-setup-to-pre-production.md`](../gate-checks/2026-04-24-technical-setup-to-pre-production.md)
