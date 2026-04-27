# Sprint 7 — 2026-08-03 to 2026-08-21 (3 weeks)

## Sprint Goal

Land the Vertical Slice harness and reach Pre-Production → Production gate-PASS. Implement matchup-resolver MVP + combat-resolution MVP, wire them into a playable end-to-end loop with HeroRoster + DungeonRunOrchestrator, run ≥3 internal playtest sessions, and author character visual profiles for the 3 hero classes.

**Definition of Sprint 7 success**: `/gate-check production` returns **PASS** (or **CONCERNS** with non-blocking issues), advancing `production/stage.txt` from `Pre-Production` to `Production`.

## Capacity

- Total days: 18 (3 weeks at 6 days/week)
- Buffer (20%): 3.6 days reserved for unplanned work
- Available: **14.4 days**

## Tasks

### Must Have (Critical Path — VS gate-PASS contractual)

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S7-M1 | TD-010 cleanup: DataRegistry boot scan + SceneManager registry_ready coupling fix | 0.5 | none | 2 defensively-skipped DataRegistry tests un-skip and pass; SceneManager._on_registry_ready guards against missing MainRoot in headless test env |
| S7-M2 | matchup-resolver Story 001: MatchupResolver base + MatchupResult value type | 0.13 | none | TR-matchup-resolver-001/002/005/006/007 |
| S7-M3 | matchup-resolver Story 002: DefaultMatchupResolver + `_is_class_counter` + `resolve_formation_matchup` | 0.25 | S7-M2 | TR-003/008/010-014/016/017/020 |
| S7-M4 | matchup-resolver Story 003: `resolve_floor_matchup` + edge-case error guards | 0.19 | S7-M3 | TR-009/015/018/019 |
| S7-M5 | combat-resolution Story 001: CombatResolver base + 4 value types + equals() | 0.19 | none | TR-combat-001/013-017/028 |
| S7-M6 | combat-resolution Story 002: combat_config.tres tuning constants | 0.13 | none | TR-combat-031 |
| S7-M7 | combat-resolution Story 003: DefaultCombatResolver + action_cooldown_ticks | 0.13 | S7-M5 + S7-M6 | TR-combat-004/005/011/032 |
| S7-M8 | combat-resolution Story 004: formation_dps + hp_bonus + survived/losing_run | 0.19 | S7-M7 | TR-combat-006/008/009 |
| S7-M9 | combat-resolution Story 005: `_kill_schedule_for_loop` + effective_dps + ticks_to_kill | 0.19 | S7-M8 | TR-combat-007/010/011/025 |
| S7-M10 | combat-resolution Story 006: `emit_events_in_range` (foreground entry point) | 0.25 | S7-M9 | TR-combat-002/014/026/029 |
| S7-M11 | combat-resolution Story 008: MatchupResolver DI + per-archetype call cache | 0.19 | S7-M3 + S7-M10 | TR-combat-004/012/030 |
| S7-M12 | dungeon-run-orchestrator Story 005: ACTIVE_FOREGROUND tick subscription + dup-tick guard | 0.25 | S7-M10 | tick_fired drives Combat.emit_events_in_range; dup-tick guard rejects identical tick numbers |
| S7-M13 | **VS harness assembly**: wire HeroRoster + Orchestrator + MatchupResolver + CombatResolver into a playable round-trip (DispatchScreen → DungeonRunView → ReturnToApp); existing screen scenes from Sprint 5 are the entry points | 1.5 | S7-M3 + S7-M11 + S7-M12 | one full [select formation → dispatch → tick-driven kills → run end → return-to-app] cycle runs end-to-end without crashes; manual smoke test passes |
| S7-M14 | Character visual profiles: 3 hero classes (warrior, mage, rogue) | 0.5 | none | `design/art/character-profiles/` exists with `warrior.md`, `mage.md`, `rogue.md`, each profile covering silhouette + colour palette + proposed pose + matchup-counter visual cue |
| S7-M15 | Playtest session #1 — new player experience | 0.25 | S7-M13 | report at `production/playtests/playtest-01-new-player-2026-08-XX.md`; identifies whether "core fantasy" matches the hero-roster GDD's Player Fantasy section |
| S7-M16 | Playtest session #2 — mid-game pacing | 0.25 | S7-M15 | report at `production/playtests/playtest-02-mid-game-2026-08-XX.md` |
| S7-M17 | Playtest session #3 — offline + return-to-app | 0.25 | S7-M16 | report at `production/playtests/playtest-03-offline-return-2026-08-XX.md` |
| S7-M18 | Pre-Production → Production gate-PASS retry: `/gate-check production` | 0.13 | S7-M14 + S7-M17 + S7-M1 | gate returns PASS or CONCERNS (no FAIL items); `production/stage.txt` updates to `Production` |

**Must Have total**: ~5.6 days base estimate; **~7-8 days realistic with discovery + review + bug-decode overhead** (per Sprint 6 actuals).

### Should Have

| ID | Task | Est. Days | Dependencies |
|----|------|-----------|--------------|
| S7-S1 | combat-resolution Story 007: `compute_offline_batch` + foreground/offline parity | 0.5 | S7-M10 |
| S7-S2 | combat-resolution Story 009: edge cases + signal-free + RNG-free invariants | 0.19 | S7-M10 |
| S7-S3 | matchup-resolver Story 004: `effectiveness_label` hook (S4-N1 quick-spec carryover) | 0.13 | S7-M4 |
| S7-S4 | dungeon-run-orchestrator Story 004: snapshot deep-copy + matchup cache | 0.25 | S7-M3 + S7-M10 |
| S7-S5 | dungeon-run-orchestrator Story 006: kill attribution + 4 signals + boss_killed | 0.25 | S7-M12 |
| S7-S6 | hero-roster Story 007: Boot validation + orphan handling + last-write-wins (S6-S1 carryover) | 0.25 | none |
| S7-S7 | hero-roster Story 008: First-launch Theron seed (S6-S2 carryover) | 0.13 | none |
| S7-S8 | TD-009 cleanup: HeroRoster._load_config defensive-branch tests (closes when S7-M1 lands) | 0.13 | S7-M1 |

**Should Have total**: ~1.8 days

### Nice to Have

| ID | Task | Est. Days | Dependencies |
|----|------|-----------|--------------|
| S7-N1 | combat-resolution Story 010: perf bench + orchestrator synchronous integration | 0.5 | S7-S1 |
| S7-N2 | matchup-resolver Story 005: determinism + offline-replay invariants | 0.5 | S7-M3 + S7-S4 |
| S7-N3 | matchup-resolver Story 008: perf bench + structural CI lint + equality test pattern | 0.25 | S7-M4 |
| S7-N4 | hero-roster Story 010: formation strength + accessors + AC H-14 perf (S6-N2 carryover) | 0.25 | none |
| S7-N5 | dungeon-run-orchestrator Story 007: floor-clear bonus + 3-layer idempotency | 0.25 | S7-S5 |
| S7-N6 | matchup-resolver Story 006: Orchestrator DI integration + spy-subclass test pattern | 0.25 | S7-M3 |
| S7-N7 | matchup-resolver Story 007: Economy + Combat consumer wiring | 0.25 | S7-M11 |
| S7-N8 | Floor-unlock-system epic pre-flight: `/create-stories floor-unlock-system` | 0.13 | none |

**Nice to Have total**: ~2.4 days

## Carryover from Previous Sprint

Sprint 6 closed all 12 Must Have stories — **zero implementation carryover**.

Carried-over backlog items absorbed into S7 Should Have / Nice to Have:
- S6-S1 (hero-roster Story 007) → S7-S6
- S6-S2 (hero-roster Story 008) → S7-S7
- S6-S3 (orchestrator Story 004) → S7-S4
- S6-S4 (orchestrator Story 005 ACTIVE_FOREGROUND tick) → **promoted to S7-M12** (critical for VS harness)
- S6-N1 (hero-roster Story 009 name pool) → deferred to Sprint 8
- S6-N2 (hero-roster Story 010 formation strength) → S7-N4
- S6-N3 (orchestrator Story 006 kill attribution) → S7-S5
- S6-N4 (orchestrator Story 007 floor-clear) → S7-N5
- S6-N5 (TD-008 ADR-0007 amendment) → deferred (LOW severity doc cleanup)
- S6-N6 (Sprint 5 quick-spec ADR propagation) → deferred

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **VS harness assembly complexity** unknown until M3+M11 land — wiring 4 stateful systems through UI screens may surface integration bugs | MEDIUM | HIGH | Sequence M13 mid-sprint to allow buffer; first run is "smoke harness" without polish; manual debugging accepted |
| **TD-010 fix risks SceneManager regression** (131 tests pass currently) | LOW | MEDIUM | M1 ships with full scene_manager test suite re-run as gate; revert if regressions appear |
| **Playtest coordination** requires human in the loop — autonomous mode cannot fully complete M15-M17 | HIGH | MEDIUM | Schedule playtests as discrete user-driven activities; AI assists with documentation post-session |
| **Combat perf budget** (576k-tick replay <100ms p95 per TR-combat-024) untested until S7-N1 lands | LOW | MEDIUM | Defer perf bench to Sprint 8 if VS harness consumes Must Have time; budget verified via manual profiling at first |
| **Solo mode review skip** means no qa-lead test-case pre-authoring for new stories | LOW | LOW | Existing Sprint 6 inline-review-during-/code-review pattern works; QA gate at sprint close catches regressions |

## Dependencies on External Factors

- **Playtest participants**: M15-M17 require ≥1 human playtester per session (3 distinct sessions). Solo mode allows the project lead to be the tester for all 3.
- **Visual profile inputs**: M14 may benefit from external concept-art reference but is not blocked on it (text-only profiles meet the gate's requirement).
- **No external API/SDK dependencies**.

## Definition of Done for Sprint 7

- [ ] All Must Have tasks (S7-M1 through S7-M18) closed via `/story-done` with COMPLETE or COMPLETE WITH NOTES verdict
- [ ] All Logic/Integration stories have passing unit/integration tests (target: ~250+ new test cases on top of Sprint 6's 664)
- [ ] QA plan exists at `production/qa/qa-plan-sprint-7.md`
- [ ] Smoke check passed (PASS or PASS WITH WARNINGS verdict)
- [ ] QA sign-off report verdict: APPROVED or APPROVED WITH CONDITIONS
- [ ] No S1 or S2 bugs in delivered features
- [ ] **`/gate-check production` returns PASS or CONCERNS** — `production/stage.txt` advances to `Production`
- [ ] **VS Validation 4/4** — VS harness exists, ≥3 playtests documented, no fun-blocker bugs, core mechanic feels good (subjective, user-confirmed)
- [ ] Character visual profiles for 3 hero classes exist at `design/art/character-profiles/`
- [ ] Code reviewed (inline review during `/code-review` per Sprint 6 pattern)
- [ ] Tech debt items TD-009 + TD-010 closed (logged Sprint 6; resolved by S7-M1 + S7-S8)

## Backlog (post-Sprint-7)

Sprint 8+ candidates, deferred from Sprint 7 Nice to Have:
- hero-roster Story 009 (name pool generation)
- audio system (still blocked on GDD + ADR)
- AD-ART-BIBLE sign-off (full art bible review with all 9 sections complete)
- TD-008 (ADR-0007 architecture diagram MainRoot Control vs Node amendment)
- Sprint 5 S5-N4 quick-spec ADR propagation (matchup-viz + enemy-viz)

## QA Plan

**QA Plan**: NOT YET CREATED — run `/qa-plan sprint` after this sprint plan is approved.

The Production → Polish gate (Sprint 8 / Sprint 9 close, depending on velocity) requires a QA sign-off report, which requires a QA plan. Run `/qa-plan sprint` before starting implementation of Must Have stories.

## Sprint 7 sequencing recommendation

Suggested implementation order to hit VS gate-PASS efficiently:

**Week 1 (M1-M9)**: Foundation cleanup + Combat MVP first 5 stories
- Day 1: S7-M1 (TD-010 cleanup) — clears 2 defensive skips before integration tests pile up
- Day 1.5: S7-M2 + S7-M5 in parallel (matchup base + combat base — both foundation-only)
- Days 2-3: S7-M3, S7-M6, S7-M7, S7-M8, S7-M9 — Combat formula chain

**Week 2 (M10-M13)**: Combat foreground entry + VS harness
- Day 1: S7-M10 (emit_events_in_range)
- Day 1.5: S7-M4 + S7-M11 (matchup floor + combat matchup-DI cache)
- Day 2: S7-M12 (orchestrator tick subscription)
- Days 3-4: **S7-M13 (VS harness assembly)** — load-bearing milestone

**Week 3 (M14-M18)**: Art + playtests + gate
- Day 1: S7-M14 (character profiles)
- Days 2-4: S7-M15 + S7-M16 + S7-M17 (3 playtest sessions)
- Day 5: S7-M18 (gate-check retry)
- Buffer / Should Have items if time remains

**Anti-pattern to avoid**: do NOT start playtests (M15-M17) before S7-M13 (VS harness) is functional; playtests against a half-wired build produce noise rather than signal.
