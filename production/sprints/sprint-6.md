# Sprint 6 — 2026-07-06 to 2026-07-17

> **Generated**: 2026-04-26 by `/sprint-plan` (autonomous; solo review mode)
> **Status**: Complete (elapsed; closed by sprint-7 kickoff. Sprint plan retained for historical audit.)
> **Engine**: Godot 4.6 (pinned 2026-02-12)

## Sprint Goal

Land the **Vertical Slice's structural foundation**: full HeroRoster Foundation
(Stories 001–008) + DungeonRunOrchestrator structural setup (Stories 001–005) +
MatchupResolver / CombatResolution pre-flight `/create-stories` + Sprint 5
sign-off conditions cleanup. The Pre-Production → Production gate-PASS is a
**Sprint 7** outcome (requires Matchup/Combat impl + VS harness assembly +
≥3 playtest sessions + character visual profiles — items that benefit from
real-hardware testing and art-pipeline work).

After Sprint 6, the 4-system core loop (HeroRoster + Orchestrator + Matchup +
Combat) has its data layer and state machines complete; Sprint 7 wires them
into a playable VS harness, runs playtests, and authors character visuals →
gate-PASS.

## Capacity

- Total: 10 working days × 2 effective hours/day = 20 effective hours
- Buffer (20%): 4 h reserved for unplanned work / GDScript runtime gotchas
  (Sprint 6's #1 risk: more `String()` constructor surprises like the one
  caught in hero-roster Story 001)
- Available: 16 h for new stories
- Sprint 1+2+3+4+5 baseline: ~20 h delivered per sprint (compressed in solo runs)

## Tasks

### Must Have (Critical Path)

| ID | Task | File / Path | Type | Est. h | Dependencies | Acceptance Criteria |
|----|------|-------------|------|--------|--------------|---------------------|
| S6-M1 | hero-roster Story 001: HeroInstance RefCounted + 5-field schema | `production/epics/hero-roster/story-001-hero-instance-resource.md` | Logic | 0.5 | none | **DONE 2026-04-26** — 16/16 tests pass; `String()` GDScript bug surfaced + fixed |
| S6-M2 | hero-roster Story 002: HeroRoster autoload skeleton + state | `production/epics/hero-roster/story-002-hero-roster-autoload-skeleton.md` | Logic | 1.5 | S6-M1 ✓ | autoload at /root/HeroRoster; rank > 2; `_heroes` Dictionary; zero-arg `_init` |
| S6-M3 | hero-roster Story 003: roster_config.tres tuning knobs | `production/epics/hero-roster/story-003-roster-config-tuning-knobs.md` | Config/Data | 1 | S6-M2 | roster_config.tres exists; MAX_ROSTER_SIZE=30; FORMATION_SIZE=3; LEVEL_CAP=15; constraint validated at load |
| S6-M4 | hero-roster Story 004: add_hero + 3 signals | `production/epics/hero-roster/story-004-add-hero-and-signals.md` | Logic | 2 | S6-M2, S6-M3 | add_hero/remove_hero bodies; `hero_recruited`/`hero_leveled`/`hero_removed` signals; cap + unresolvable-class guards |
| S6-M5 | hero-roster Story 005: set_hero_level + set_formation_slot | `production/epics/hero-roster/story-005-mutation-api-level-and-formation.md` | Logic | 2 | S6-M2, S6-M3, S6-M4 | clamping to [1, LEVEL_CAP]; auto-clear duplicate formation placement; `hero_leveled` emission |
| S6-M6 | hero-roster Story 006: get_save_data / load_save_data round-trip | `production/epics/hero-roster/story-006-save-load-round-trip.md` | Integration | 2 | S6-M1..M5; SaveLoadSystem (Sprint 4) | save dict shape per TR-019; signal suppression during load_save_data; HeroRoster registered in CONSUMER_PATHS |
| S6-M7 | dungeon-run-orchestrator Story 001: RunSnapshot + 5-state FSM | `production/epics/dungeon-run-orchestrator/story-001-run-snapshot-and-state-machine.md` | Logic | 2 | none (parallelizable with hero-roster chain) | RunSnapshot RefCounted with to_dict/from_dict/equals; 5-state enum; state-trigger matrix |
| S6-M8 | dungeon-run-orchestrator Story 002: autoload + DI setters + lazy resolvers | `production/epics/dungeon-run-orchestrator/story-002-autoload-skeleton-and-di.md` | Logic | 2 | S6-M7 | autoload at /root/DungeonRunOrchestrator; 3 DI setters; lazy-default resolver pattern in _ready |
| S6-M9 | dungeon-run-orchestrator Story 003: DISPATCHING validation | `production/epics/dungeon-run-orchestrator/story-003-dispatching-validation.md` | Logic | 1.5 | S6-M7, S6-M8 | empty formation rejection; floor-locked rejection; 250ms dispatch debounce; `validation_failed` signal |
| S6-M10 | Pre-flight: `/create-stories matchup-resolver` (Sprint 5 S5-S3 carryover) | `production/epics/matchup-resolver/EPIC.md` | Config/Data (story authoring) | 1 | none | matchup-resolver epic fully decomposed into story files |
| S6-M11 | Pre-flight: `/create-stories combat-resolution` (Sprint 5 S5-S3 carryover) | `production/epics/combat-resolution/EPIC.md` | Config/Data (story authoring) | 1 | none | combat-resolution epic fully decomposed into story files |
| S6-M12 | FOLLOWUP-002 cleanup: data_registry test-env (Sprint 5 sign-off condition) | `tests/unit/data_registry/autoload_skeleton_and_state_machine_test.gd` | Logic | 1 | none | 3 pre-existing test failures resolved via test-env fix or per-test guards; full project test count reaches 471/471 PASS |

**Must Have subtotal**: ~17.5 h (with S6-M1 already complete at 0.5h, ~17h
remaining vs ~16h capacity — slightly above target; accept the overage as
Sprint 5 cleanup-condition pressure).

### Should Have

| ID | Task | File / Path | Type | Est. h | Dependencies | Acceptance Criteria |
|----|------|-------------|------|--------|--------------|---------------------|
| S6-S1 | hero-roster Story 007: Boot validation + orphan handling + last-write-wins | `production/epics/hero-roster/story-007-boot-validation-and-orphan-handling.md` | Integration | 2 | S6-M6 | 4-step validation order; `_orphaned_heroes` tracking; duplicate id last-write-wins |
| S6-S2 | hero-roster Story 008: First-launch Theron seed | `production/epics/hero-roster/story-008-first-launch-theron-seed.md` | Logic | 1 | S6-M2..M5 | `seed_first_launch_state` creates Warrior id=1, name="Theron", slot 0; emits hero_recruited |
| S6-S3 | dungeon-run-orchestrator Story 004: snapshot deep-copy + matchup cache build | `production/epics/dungeon-run-orchestrator/story-004-snapshot-build-and-matchup-cache.md` | Logic | 2 | S6-M7..M9 | formation deep-copy; floor by id; matchup cache pre-populated for every archetype; built once at DISPATCHING |
| S6-S4 | dungeon-run-orchestrator Story 005: ACTIVE_FOREGROUND tick subscription + dup-tick guard | `production/epics/dungeon-run-orchestrator/story-005-active-foreground-tick-subscription.md` | Integration | 2 | S6-S3, TickSystem (Sprint 1) | tick_fired subscription lifecycle; dup-tick early return; rewind warning |

**Should Have subtotal**: ~7 h. Stretch beyond 16h capacity — pull in if Must Have closes early.

### Nice to Have

| ID | Task | File / Path | Type | Est. h | Dependencies | Acceptance Criteria |
|----|------|-------------|------|--------|--------------|---------------------|
| S6-N1 | hero-roster Story 009: Name pool generation + DataRegistry name_pools | `production/epics/hero-roster/story-009-name-pool-generation.md` | Integration | 2 | S6-M4; DataRegistry | uniform random over unused pool; ordinal fallback; ≥20 names per MVP class; name_pools category in DataRegistry |
| S6-N2 | hero-roster Story 010: Formation strength + accessors + AC H-14 perf | `production/epics/hero-roster/story-010-formation-strength-and-accessors.md` | Logic (Performance) | 2 | S6-M2, S6-M5 | formation strength formula; sort modes; p99 < 50µs |
| S6-N3 | dungeon-run-orchestrator Story 006: Kill attribution + 4 signals + boss_killed | `production/epics/dungeon-run-orchestrator/story-006-kill-attribution-and-signals.md` | Logic | 2 | S6-S4 | kill gold formula; Economy.add_gold routing; 4 owned signals declared with exact arity |
| S6-N4 | dungeon-run-orchestrator Story 007: floor-clear + 3-layer idempotency | `production/epics/dungeon-run-orchestrator/story-007-floor-clear-and-idempotency.md` | Integration | 2 | S6-N3; Economy.try_award_floor_clear (Sprint 3) | FLOOR_CLEAR_BONUS [1..5]; once-per-dispatch flag; LOSING factor pre-applied |
| S6-N5 | TD-008 cleanup: ADR-0007 architecture diagram amendment | `docs/architecture/ADR-0007-scene-transition-and-persist-coupling.md` | Config/Data | 0.25 | none | 1-line diagram fix `MainRoot (Node)` → `MainRoot (Control)` |
| S6-N6 | Sprint 5 S5-N4 carryover: quick-spec ADR propagation (matchup-viz + enemy-viz) | `design/quick-specs/{matchup-visualization-revision,dungeon-enemy-visualization}.md` → ADR-0009 + ADR-0008 | Config/Data | 2 | none | both quick-specs propagated into ADR amendments; control-manifest version bumped |

**Nice to Have subtotal**: ~10.25 h. Total max ceiling ~35 h vs ~20 h target — Must Have is contractual.

## Carryover from Previous Sprint (Sprint 5)

| Task | Reason | New Estimate |
|------|--------|--------------|
| FOLLOWUP-002 (S6-M12) | Sprint 5 sign-off condition; 3 pre-existing data_registry test-env failures | 1 h |
| TD-008 (S6-N5) | Sprint 5 sign-off advisory; ADR-0007 diagram says `MainRoot (Node)` but contract needs Control | 0.25 h |
| Matchup/Combat pre-flight (S6-M10/M11) | Sprint 5 S5-S3 carryover (was Should Have, didn't reach) | 2 h |
| Sprint 5 S5-N4 quick-spec → ADR propagation (S6-N6) | Sprint 5 Nice to Have, didn't reach | 2 h |

**Sprint 5 Should Have / Nice to Have NOT pulled into Sprint 6**:
- S5-S1 CEREMONY transition Story 006 — Sprint 7 (paired with Tween animation polish)
- S5-S2 scene_boundary_persist Story 008 — Sprint 7 (uses HeroRoster save/load)
- S5-N1 reduce_motion Story 009 — Sprint 7 (accessibility polish)
- S5-N2 H-10/H-11/H-12 edge cases + perf Story 010 — Sprint 7
- S5-N3 floor-unlock-system pre-flight — Sprint 7

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| GDScript runtime surprises (à la `String()` constructor non-existence in hero-roster Story 001) | HIGH | LOW | QA-driven type-coercion tests on every from_dict/Dictionary deserializer; pattern note in session state to use `str()` not `String()`. Spend buffer hours on debug-mode discovery during dev-story runs. |
| HeroRoster + DungeonRunOrchestrator parallel-development conflict | MEDIUM | MEDIUM | They have ZERO source-file overlap; HeroRoster.formation_snapshot is consumed by Orchestrator via parameter passing (no shared writable state). Risk is integration timing — S6-S3 (orchestrator snapshot build) needs HeroRoster Story 002+ to exist; coordinate ordering. |
| FOLLOWUP-002 fix scope creep (test-env deep-dive turns into refactor) | MEDIUM | MEDIUM | Time-box S6-M12 at 1h. If the fix requires touching DataRegistry boot logic itself, scope-cut to "gate the 3 affected tests with `if not DataRegistry.is_ready: return # test-env limitation`" and defer the underlying EconomyConfig fixture seeding to Sprint 7. |
| Sprint 6 scope > 16h capacity (Must Have at 17.5h) | MEDIUM | LOW | Accept the modest overage. If a Must Have story slips, the closest cut is S6-M12 (FOLLOWUP-002) — defer to Sprint 7 since the underlying tests are pre-existing failures, not Sprint 6 regressions. |
| Vertical Slice gate-PASS expectations | LOW | HIGH | Frame Sprint 6 as "structural foundation"; the gate-PASS is Sprint 7 work. Communicate clearly to avoid disappointment — VS playtests + character visual profiles are NOT Sprint 6 deliverables. |

## Dependencies on External Factors

- DataRegistry must be in READY state at runtime for HeroRoster/Orchestrator integration tests. Sprint 3 fixed this for content-bearing categories; HeroRoster Story 003 introduces `roster_config` category and Story 009 introduces `name_pools` category — DataRegistry ORDERED_CATEGORIES extension required (mirrors Sprint 2 EconomyConfig pattern).
- SaveLoadSystem (Sprint 4) must accept HeroRoster as CONSUMER_PATHS entry #1 (after Economy at #0). Story 006 is the registration site — verify Sprint 4's CONSUMER_PATHS is editable in Sprint 6.
- TickSystem (Sprint 1) is required for orchestrator Story 005 (S6-S4) tick subscription — verified bootable since Sprint 3 close.
- Economy (Sprint 2 + S3-M1) is required for orchestrator Story 006 (S6-N3) and Story 007 (S6-N4) — Economy.add_gold + try_award_floor_clear public API.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-6-2026-04-26.md`) — see Phase 5 widget
- [ ] All Logic / Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] FOLLOWUP-002 closed in tech-debt register
- [ ] Cumulative project test count ≥ 250 in active suites (currently 235)
- [ ] HeroRoster integrated into SaveLoadSystem CONSUMER_PATHS
- [ ] Both pre-flighted Feature-layer epics (matchup-resolver, combat-resolution) have story files

## Sprint 6 Deliberately Excludes (with rationale)

- **Vertical Slice playable harness assembly** — Sprint 7. Requires all 4 Feature-layer systems (HeroRoster + Orchestrator + Matchup + Combat) in working state plus integration into SceneManager screen routing.
- **Matchup / Combat IMPLEMENTATION** — Sprint 7. Pre-flight authoring only this sprint.
- **≥3 playtest sessions** — Sprint 7. Requires playable VS build.
- **Character visual profiles** — Sprint 7 art-spec work.
- **AD-ART-BIBLE sign-off** — solo mode skip; defer to pre-MVP-ship gate.
- **Audio system** — still blocked (no GDD / no ADR-C03).
- **Floor-unlock pre-flight** — Sprint 7 (S5-N3 carryover).

## Path to Pre-Production → Production Gate PASS

Per `production/gate-checks/2026-04-26-pre-production-to-production-sprint5-close.md`:

- **Sprint 6** (this sprint): structural foundation — HeroRoster Foundation + Orchestrator structural setup + Matchup/Combat pre-flight. **Vertical Slice still missing** at end of Sprint 6.
- **Sprint 7**: Matchup + Combat impl + VS harness assembly + character visual profiles + ≥3 playtest sessions + VS playtest report.
- **Sprint 7 close**: re-run `/gate-check production` — VS Validation 4/4 → expected PASS.

## QA Plan

**QA Plan**: `production/qa/qa-plan-sprint-6-2026-04-26.md` (landed 2026-04-26)

22 stories aggregated; 9 Logic + 5 Integration + 7 Config/Data + 1 Logic-Performance. Zero Visual/Feel; zero UI. Manual QA Phase 4 + Phase 6 SKIPPED per qa-lead recommendation (same pattern as Sprints 1-5). ~150-180 net-new test cases projected. Cross-cutting patterns from Sprint 5 + S6-M1: use `str()` not `String()` in from_dict deserializers; Object cast for "is NOT" assertions. Zero playtest sessions required this sprint (VS playtests are Sprint 7).

## Carry-Over Items for Sprint 7 Planning

- HeroRoster Stories 009 (name pool) + 010 (formation strength) — Nice to Have this sprint; will likely carry
- DungeonRunOrchestrator Stories 008-012 — definitely carry
- Matchup + Combat IMPLEMENTATION — full Sprint 7 scope after pre-flight
- VS harness assembly + ≥3 playtests + character visual profiles + VS playtest report — Sprint 7 contractual
- Sprint 5 carryovers (S5-S1, S5-S2, S5-N1, S5-N2, S5-N3, S5-N4 if not pulled into Sprint 6 N5/N6)
- TD-005 / FOLLOWUP-001 — already CLOSED in Sprint 5 ✓
- AD-ART-BIBLE sign-off — defer until pre-MVP-ship gate
