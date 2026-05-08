# Sprint 3 — 2026-05-25 to 2026-06-05

> **Generated**: 2026-04-25 by `/sprint-plan` (autonomous; solo review mode)
> **Status**: Complete (elapsed; closed by sprint-4 kickoff. Sprint plan retained for historical audit.)
> **Engine**: Godot 4.6 (pinned 2026-02-12)

## Sprint Goal

Complete the Core-layer data backbone (Enemy DB + BiomeDungeon DB), close
TD-006 (DataRegistry ERROR-state gap), close Sprint 2 carryover
(`try_award_floor_clear` monotonic ledger), and land main-menu + pause UX
specs — so Sprint 4 can start Feature-layer epics on a fully booted Core.

## Capacity

- Total: 10 working days × 2 effective hours/day = 20 effective hours
- Buffer (20%): 4 h reserved for unplanned work / Sprint 2 tech-debt
- Available: 16 h for new stories
- Sprint 1+2 baseline: ~20 h delivered per sprint (compressed)

## Pre-flight (Sprint entry criteria — NOT counted against sprint capacity)

Before any S3-M2..M7 story can be picked up, the underlying story files must
be authored:

1. `/create-stories enemy-database` — produces `production/epics/enemy-database/story-*.md`
2. `/create-stories biome-dungeon-database` — produces `production/epics/biome-dungeon-database/story-*.md`

Estimated effort: ~1 h total (mechanical authoring; both EPICs are already in
place from `/create-epics layer: core` in this session). Track as Sprint 3
preparation, not as Must Have story work.

## Tasks

### Must Have (Critical Path)

| ID | Task | Story File (post-pre-flight) | Type | Est. (h) | Depends On | ADR(s) |
|----|------|------------------------------|------|----------|-----------|--------|
| S3-M1 | `try_award_floor_clear` monotonic-credit ledger (5 sub-ACs; **Sprint 2 S2-S1 carryover**) | [`economy-system/story-005`](../epics/economy-system/story-005-try-award-floor-clear-monotonic-ledger.md) | Logic | 4 | Sprint 2 S2-M3 (`add_gold`) | ADR-0002, ADR-0013 |
| S3-M2 | EnemyData resource + EnemyArchetypes consumer | enemy-database Story 001 (TBA pre-flight) | Logic | 1.5 | S2-M5 (HeroClass + EnemyArchetypes) | ADR-0011 |
| S3-M3 | EnemyDatabase autoload (rank 5) + accessors | enemy-database Story 002 (TBA) | Integration | 1.5 | S3-M2 | ADR-0011, ADR-0006, ADR-0003 |
| S3-M4 | 7+ MVP enemy `.tres` files (Tier-1 / Tier-2 / Tier-3 boss) satisfying TR-enemy-db-008 archetype distribution | enemy-database Story 003 (TBA) | Config/Data | 3 | S3-M2, S3-M3 | ADR-0011 |
| S3-M5 | Biome / Dungeon / Floor resource subclasses + cascading UNAVAILABLE validator | biome-dungeon-database Story 001 (TBA) | Logic | 2 | S3-M2 (Floor.enemy_id refs EnemyData) | ADR-0011 |
| S3-M6 | BiomeDungeonDatabase autoload (rank 6) + accessors | biome-dungeon-database Story 002 (TBA) | Integration | 2 | S3-M5 + S3-M3 | ADR-0011, ADR-0006, ADR-0003 |
| S3-M7 | Forest Reach MVP biome — 1 dungeon × 5 floors, gap-free `floor_index`, F5 boss=Ancient Rootking | biome-dungeon-database Story 003 (TBA) | Config/Data | 2.5 | S3-M5, S3-M6, S3-M4 (enemy_id resolution) | ADR-0011 |
| S3-M8 | TD-006 closure: smoke check verifies DataRegistry reaches READY end-to-end with all 7 categories satisfied | (this story is the smoke-check + report) | Config/Data | 0.5 | S3-M4 + S3-M7 | TD-006 |

**Must Have total**: 17 h. M2→M3→M4 chain unblocks M5→M6→M7→M8. M1 parallelizable with the rest.

### Should Have

| ID | Task | Story File | Type | Est. (h) | Depends On |
|----|------|-----------|------|----------|-----------|
| S3-S1 | UX spec: main menu (`/ux-design main-menu`) | `design/ux/main-menu.md` (TBA) | UI (spec) | 1.5 | None |
| S3-S2 | UX spec: pause menu (`/ux-design pause-menu`) | `design/ux/pause-menu.md` (TBA) | UI (spec) | 1.5 | None |
| S3-S3 | `stat_at_level` helper + L15 sanity (Sprint 2 S2-S2 carryover) | [`hero-class-database/story-004`](../epics/hero-class-database/story-004-stat-at-level-helper.md) | Logic | 2 | S2-M5 (HeroClass) |

**Should Have total**: 5 h

### Nice to Have (Stretch)

| ID | Task | Story File | Type | Est. (h) | Depends On |
|----|------|-----------|------|----------|-----------|
| S3-N1 | HeroClass schema validation at load (Sprint 2 S2-N2 carryover) | [`hero-class-database/story-008`](../epics/hero-class-database/story-008-schema-validation-at-load.md) | Logic | 3 | S2-M5, data-registry per-type validator |
| S3-N2 | `is_class_counter` helper (Sprint 2 S2-N1 carryover) | [`hero-class-database/story-006`](../epics/hero-class-database/story-006-is-class-counter.md) | Logic | 1 | S2-M5 |

**Nice to Have total**: 4 h

**Sprint scope**: 26 h max ceiling vs 20 h delivery target. Must Have is contractual.

## Carryover from Sprint 2

| Task | Sprint 2 Status | Reason | New Estimate |
|------|------|--------|-------------|
| economy-system 005 monotonic ledger | Should Have, NOT STARTED | Highest-complexity story in project (5 sub-ACs); blocks DungeonRunOrchestrator Feature epic | 4 h (unchanged) — promoted to Must |
| hero-class-database 004 `stat_at_level` | Should Have, NOT STARTED | Helper consumed by Combat Feature epic | 2 h — kept Should |
| hero-class-database 006 `is_class_counter` | Nice to Have, NOT STARTED | Helper consumed by Matchup Resolver Feature epic | 1 h — Nice (stretch) |
| hero-class-database 008 schema validation | Nice to Have, NOT STARTED | Content safety net | 3 h — Nice (stretch) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| S3-M1 is the most complex single story in the project (5 sub-ACs + reclaim semantics) | MEDIUM | HIGH | If estimate slips beyond 5 h, descope S3-S3/N1/N2 rather than cutting Must. Land it first while energy is high. |
| Enemy fixture count: TR-enemy-db-008 requires tier distribution + Ancient Rootking boss; min_content_count default = 5 but content invariants push to 7-8 files | MEDIUM | LOW | S3-M4 estimated 3 h to absorb. Author minimum satisfying BOTH min_content_count(5) AND tier-distribution invariants. |
| BiomeDungeon nested resource validation (Biome → Dungeon → Floor → enemy_id) introduces cross-resource cascade that Sprint 1's per-type validator didn't address | MEDIUM | MEDIUM | S3-M5 ACs include the cascade per ADR-0011 + TR-biome-dungeon-db-007/008/010. If hookup proves complex, file follow-on as Sprint 4 story. |
| `/create-stories enemy-database` + `biome-dungeon-database` may surface story-author-time issues (similar to S2-M2's `ORDERED_CATEGORIES` extension) | LOW | LOW | Pattern proven in Sprint 2. Pre-flight scope-deviation budget reserved in the 4 h sprint buffer. |
| Vertical Slice still missing post-Sprint-3 — gate stays FAIL | HIGH | LOW (expected) | Sprint 3 explicitly does not target the gate; closing it is Sprint 4-6 work. |

## Dependencies on External Factors

- All Foundation infrastructure landed in Sprint 1 + 2
- ADR-0011 + ADR-0006 + ADR-0014 (Accepted) cover all Sprint 3 work
- No external blockers
- Audio system (ADR-C03 + GDD) remains BLOCKED — out of Sprint 3 scope

## Definition of Done for Sprint 3

- [ ] All Must Have stories closed via `/story-done` with passing tests
- [ ] All Logic stories have unit tests in `tests/unit/[system]/`
- [ ] All Integration stories have integration tests in `tests/integration/[system]/`
- [ ] Smoke check passes (`/smoke-check sprint`) — DataRegistry reaches READY end-to-end (TD-006 closed)
- [ ] QA sign-off APPROVED or APPROVED WITH CONDITIONS via `/team-qa sprint`
- [ ] Forest Reach MVP biome present (1 dungeon × 5 floors, gap-free)
- [ ] All MVP enemy `.tres` files present satisfying TR-enemy-db-008 archetype distribution invariant
- [ ] `design/registry/entities.yaml` updated with new enemy + biome entries (cross-check existing Sprint 1 prior art at `entities.yaml` ~line 110+)
- [ ] No S1/S2 bugs
- [ ] Sprint retrospective in `production/retrospectives/sprint-3.md`

## What Sprint 3 deliberately does NOT include (rationale)

- **Vertical Slice playable build** — requires HeroRoster + DungeonRunOrchestrator + Combat + Matchup Resolver + SaveLoadSystem (Feature-layer epics not yet decomposed). Sprint 4–6 territory. Gate stays FAIL through Sprint 3.
- **Save/Load Foundation epic** — HIGH risk; dedicated Sprint 4 (or Sprint 5).
- **Scene-manager Foundation epic implementation** — needed for UI runtime; main-menu/pause UX specs in Sprint 3 are design-only (no code).
- **Audio system epic** — GDD + ADR-C03 unauthored; Sprint 5+ candidate.
- **Prototype-finding propagation** (matchup-viz revision to `class-vs-enemy-matchup-resolver.md` and `dungeon-run-orchestrator.md` GDDs) — can land via `/quick-design` in parallel; not blocking Sprint 3 stories. Recommend addressing before Presentation-layer epic decomposition.

## QA Plan

✅ **QA Plan**: [`../qa/qa-plan-sprint-3-2026-04-25.md`](../qa/qa-plan-sprint-3-2026-04-25.md)

Type breakdown: 7 Logic + 2 Integration + 3 Config/Data + 2 UI (spec only) + 1 smoke task = 15 deliverables. Heavy automated coverage on the data backbone; light manual QA (smoke + entities.yaml diff + UX-spec sign-off). Zero playtest sessions required (no playable surface yet — same as Sprint 2).

S3-M1's 5 sub-ACs have detailed pre-authored test cases in the story file's `## QA Test Cases` section. S3-M2..M7 per-AC specifics will land in their story files when `/create-stories enemy-database` and `/create-stories biome-dungeon-database` run during pre-flight.

## Scope Check

> If stories are added beyond the original epic scope during sprint execution
> (likely candidate: any expansion needed in `enemy-database` or
> `biome-dungeon-database` after `/create-stories` runs), run
> `/scope-check enemy-database` and `/scope-check biome-dungeon-database`
> before implementation begins.

## Reference

- Previous sprint: [`sprint-2.md`](sprint-2.md) — 7/7 Must Have closed 2026-04-25, APPROVED WITH CONDITIONS (TD-006 attached)
- Sprint 2 sign-off: [`../qa/qa-signoff-sprint-2-2026-04-25.md`](../qa/qa-signoff-sprint-2-2026-04-25.md)
- Sprint 2 smoke check: [`../qa/smoke-2026-04-25.md`](../qa/smoke-2026-04-25.md)
- Gate-check (post-Sprint-2 re-run, 2026-04-25): FAIL — Vertical Slice missing; Sprint 3 explicitly doesn't target gate
- Epic index: [`../epics/index.md`](../epics/index.md)
- Sprint status (machine-readable): [`../sprint-status.yaml`](../sprint-status.yaml)
