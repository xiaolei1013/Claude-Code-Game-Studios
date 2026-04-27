# Sprint 8 — 2026-08-24 to 2026-09-11 (3 weeks)

## Sprint Goal

Deliver the Vertical Slice **playable build**: assemble DispatchScreen + DungeonRunView UI on top of the verified-runnable kernel from Sprint 7, run ≥3 internal playtest sessions, and reach Pre-Production → Production gate-PASS.

**Definition of Sprint 8 success**: `/gate-check production` returns **PASS** (or **CONCERNS** with non-blocking issues), advancing `production/stage.txt` from `Pre-Production` to `Production`.

This is the **second half** of Sprint 7's contractual VS gate-PASS goal. Sprint 7 delivered the kernel + character profiles autonomously; Sprint 8 delivers the UI surface + playtests that turn the kernel into a build a person can sit in front of.

## Capacity

- Total days: 18 (3 weeks at 6 days/week)
- Buffer (20%): 3.6 days reserved for unplanned work
- Available: **14.4 days**

## Tasks

### Must Have (Critical Path — VS gate-PASS contractual)

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S8-M1 | DispatchScreen UI: 3-slot formation picker (pulling HeroRoster) + floor selector (forest_reach floor 1) + Dispatch button | 1.5 | none (kernel ready) | Player can select 3 heroes from roster, pick floor 1 of forest_reach, press Dispatch; orchestrator.dispatch() is invoked with the selected formation; validation_failed surfaces a visible toast/label on empty/locked-floor failure |
| S8-M2 | DungeonRunView UI: live tick + kill_count display reading from orchestrator.run_snapshot; run-end indicator | 1.0 | S8-M1 | While ACTIVE_FOREGROUND, view shows current_tick + kill_count updating per tick; on RUN_ENDED, view shows "Run Complete" overlay with kill_count summary; ≥30 FPS in real Godot run on dev machine |
| S8-M3 | Return-to-app transition: RUN_ENDED → SceneManager.transition_to MainMenu via existing scene-manager registry | 0.5 | S8-M2 | When orchestrator state advances to RUN_ENDED, DungeonRunView fades out and SceneManager loads MainMenu within ≤500ms; tick subscription cleanly disconnects (verified via existing integration test pattern) |
| S8-M4 | Internal manual smoke session: author drives full dispatch in real Godot 4.6 run | 0.25 | S8-M3 | `production/qa/smoke-sprint-8-vs-harness-2026-09-XX.md` exists; documents one full [open MainMenu → DispatchScreen → select 3 heroes + floor → Dispatch → DungeonRunView → run completes → return to MainMenu] cycle; verdict PASS or PASS WITH WARNINGS |
| S8-M5 | Playtest session #1 — new player experience (carryover from S7-M15) | 0.25 | S8-M4 | `production/playtests/playtest-01-new-player-2026-09-XX.md` exists; identifies whether "core fantasy" matches the hero-roster GDD's Player Fantasy section; ≥1 unprompted statement of player intent captured |
| S8-M6 | Playtest session #2 — mid-game pacing (carryover from S7-M16) | 0.25 | S8-M5 | `production/playtests/playtest-02-mid-game-2026-09-XX.md` exists; covers 2nd or 3rd dispatch including offline-aware ticks if applicable |
| S8-M7 | Playtest session #3 — offline + return-to-app (carryover from S7-M17) | 0.25 | S8-M6 | `production/playtests/playtest-03-offline-return-2026-09-XX.md` exists; covers app-background → app-resume cycle with at least one "real elapsed time > 60s" gap |
| S8-M8 | Pre-Production → Production gate-PASS retry: `/gate-check production` (carryover from S7-M18) | 0.13 | S8-M7 | Gate returns PASS or CONCERNS (no FAIL items); `production/stage.txt` updates to `Production` |

**Must Have total**: ~4.1 days base; **~6 days realistic** with UI integration discovery + Godot 4.6 idiom learning curve. Comfortably within 14.4-day available capacity, leaving ~8 days for Should Have absorption.

### Should Have (carryovers from Sprint 7 — kernel already supports these)

| ID | Task | Est. Days | Dependencies |
|----|------|-----------|--------------|
| S8-S1 | combat-resolution Story 007: `compute_offline_batch` + foreground/offline parity (S7-S1 carry) | 0.5 | none (kernel ready) |
| S8-S2 | dungeon-run-orchestrator Story 004: snapshot deep-copy + matchup cache (S7-S4 carry) | 0.25 | none |
| S8-S3 | dungeon-run-orchestrator Story 006: kill attribution + 4 signals + boss_killed (S7-S5 carry) | 0.25 | S8-S2 |
| S8-S4 | hero-roster Story 007: Boot validation + orphan handling + last-write-wins (S7-S6 carry) | 0.25 | none |
| S8-S5 | hero-roster Story 008: First-launch Theron seed (S7-S7 carry) | 0.13 | none |
| S8-S6 | matchup-resolver Story 004: `effectiveness_label` hook (S7-S3 carry) | 0.13 | none |
| S8-S7 | combat-resolution Story 009: edge cases + signal-free + RNG-free invariants (S7-S2 carry) | 0.19 | none |
| S8-S8 | TD-009 cleanup: HeroRoster._load_config defensive-branch tests (S7-S8 carry — unblocked by S7-M1 ✅) | 0.13 | none |
| S8-S9 | TD-011 follow-up: revise hero-class GDD §F.5 stat-at-level range table or accept current values | 0.25 | none |

**Should Have total**: ~2.0 days

### Nice to Have

| ID | Task | Est. Days | Dependencies |
|----|------|-----------|--------------|
| S8-N1 | combat-resolution Story 010: perf bench + orchestrator synchronous integration (S7-N1 carry) | 0.5 | S8-S1 |
| S8-N2 | matchup-resolver Story 005: determinism + offline-replay invariants (S7-N2 carry) | 0.5 | S8-S2 |
| S8-N3 | matchup-resolver Story 008: perf bench + structural CI lint (S7-N3 carry) | 0.25 | none |
| S8-N4 | hero-roster Story 010: formation strength accessor + AC H-14 perf (S7-N4 carry) | 0.25 | none |
| S8-N5 | dungeon-run-orchestrator Story 007: floor-clear bonus + 3-layer idempotency (S7-N5 carry) | 0.25 | S8-S3 |
| S8-N6 | matchup-resolver Story 006: Orchestrator DI integration + spy-subclass test pattern (S7-N6 carry) | 0.25 | none |
| S8-N7 | matchup-resolver Story 007: Economy + Combat consumer wiring (S7-N7 carry) | 0.25 | none |
| S8-N8 | Floor-unlock-system epic pre-flight: `/create-stories floor-unlock-system` (S7-N8 carry) | 0.13 | none |
| S8-N9 | hero-roster Story 009: name pool generation (S6-N1 → S7 deferred) | 0.5 | S8-S4 |
| S8-N10 | AD-ART-BIBLE sign-off: art bible 9-section completeness review | 0.5 | none |

**Nice to Have total**: ~3.4 days

## Carryover from Previous Sprint (Sprint 7)

Sprint 7 closed **14/18 Must Have** stories autonomously. The remaining 4 (S7-M15/M16/M17 playtests + S7-M18 gate retry) physically required (a) a UI surface and (b) a human playtester — neither possible during the autonomous run. They roll forward as **S8-M5/M6/M7/M8** with their original acceptance criteria intact.

Sprint 7 also deferred the **DispatchScreen UI portion of S7-M13** to Sprint 8 (per S7-M13 closure note: kernel data path verified; UI assembly is Sprint 8 work). This becomes Sprint 8's **S8-M1 + S8-M2 + S8-M3** — the first three Must Haves and the load-bearing pieces of the sprint.

All Sprint 7 Should Have / Nice to Have items were untouched (autonomous mode focused on Must Have only) and roll forward as Sprint 8 Should/Nice items above with original IDs preserved in parentheses.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **DispatchScreen UI integration complexity** — wiring HeroRoster + orchestrator + scene transitions through Godot 4.6 Control nodes is novel territory for this codebase | MEDIUM | HIGH | Sequence S8-M1/M2/M3 as a tight loop in Week 1 with explicit "first-pass smoke test" milestone S8-M4; accept ugly UI for VS, polish in Sprint 9 |
| **Godot 4.6 UI-toolkit knowledge gap** — LLM training cutoff is May 2025; 4.6 Control + signal patterns post-cutoff | MEDIUM | MEDIUM | Reference `docs/engine-reference/godot/` for verified patterns; spawn godot-specialist for any UI architecture decisions |
| **Playtest coordination requires human in the loop** — autonomous mode cannot complete S8-M5/M6/M7 | HIGH | MEDIUM | These are user-driven by design; AI assists with documentation post-session. Schedule playtests as discrete user activities. |
| **First playtest exposes core-loop fun gap** — possible the dispatch → tick → kill → return loop does not actually feel rewarding | MEDIUM | HIGH | Build minimal version first (S8-M1-M3), playtest immediately (S8-M5), iterate before second playtest. Pivot scope rather than gold-plate. |
| **Run pacing too fast (sub-second runs) or too slow (multi-minute runs) on default tuning** — combat formulas are TR-correct but TR ranges may not match playable feel | MEDIUM | MEDIUM | Use S8-M4 smoke to measure; expose CombatConfig hot-tunables (already exists per S7-M6); tune in S8-S1 if needed |

## Dependencies on External Factors

- **Playtest participants**: S8-M5/M6/M7 require ≥1 human playtester per session (3 distinct sessions). Solo mode allows the project lead to be the tester for all 3.
- **Godot 4.6 IDE access** for manual smoke session (S8-M4). Headless test environment proven sufficient for kernel validation but not for UI feel verification.
- **No external API/SDK dependencies**.

## Definition of Done for Sprint 8

- [ ] All Must Have tasks (S8-M1 through S8-M8) closed via `/story-done` with COMPLETE or COMPLETE WITH NOTES verdict
- [ ] DispatchScreen + DungeonRunView UI exist as `.tscn` scenes in `src/ui/` (or appropriate subdirectory) with `.gd` controller scripts
- [ ] At least one integration test covers UI → orchestrator wiring (e.g., "press Dispatch with valid formation triggers orchestrator state advance")
- [ ] QA plan exists at `production/qa/qa-plan-sprint-8.md`
- [ ] Smoke check passed (S8-M4) with PASS or PASS WITH WARNINGS verdict
- [ ] QA sign-off report verdict: APPROVED or APPROVED WITH CONDITIONS
- [ ] No S1 or S2 bugs in delivered features
- [ ] **`/gate-check production` returns PASS or CONCERNS** — `production/stage.txt` advances to `Production`
- [ ] **VS Validation 4/4** — VS UI exists, ≥3 playtests documented, no fun-blocker bugs, core mechanic feels good (subjective, user-confirmed)
- [ ] Code reviewed (inline review during `/code-review` per Sprint 6/7 pattern)
- [ ] Tech debt items TD-009 closed (S8-S8); TD-011 either resolved or accepted with rationale (S8-S9)

## Sprint 8 sequencing recommendation

**Week 1 (S8-M1, S8-M2, S8-M3, S8-M4)**: UI assembly + first smoke
- Days 1-2: S8-M1 (DispatchScreen — formation picker + floor selector + Dispatch button)
- Days 3-4: S8-M2 (DungeonRunView — live tick/kill display + run-end overlay)
- Day 5: S8-M3 (Return-to-app SceneManager transition)
- Day 6: S8-M4 (manual smoke session — first playable end-to-end run)

**Week 2 (S8-M5, S8-M6, S8-M7)**: Playtest cycle
- Day 1: S8-M5 (playtest #1 — new player experience)
- Day 2: Iterate on findings if any S1/S2 bugs surfaced
- Day 3: S8-M6 (playtest #2 — mid-game pacing)
- Day 4: S8-M7 (playtest #3 — offline + return-to-app)
- Days 5-6: Bug fixes from playtests; should/nice absorption begins

**Week 3 (S8-M8 + Should Have)**: Gate + carryover absorption
- Day 1: S8-M8 (gate-check retry — expected PASS)
- Days 2-6: Should Have items in priority order (S8-S1 offline batch is highest leverage as it closes the offline parity loop the GDD has been designed around since Sprint 1)

**Anti-pattern to avoid**: do NOT begin S8-M5 until S8-M4 documents a clean smoke run. Playtesting against an unstable build wastes the playtester's attention.

## QA Plan

**QA Plan**: `production/qa/qa-plan-sprint-8-2026-04-27.md` (authored 2026-04-27)

Covers all 8 Must Have + 9 Should Have stories with:
- Integration tests for UI stories (S8-M1/M2/M3) — concrete file paths + test counts
- Unit tests for kernel carryover Logic stories (S8-S1 through S8-S7)
- Manual UI walkthrough checklists for S8-M1/M2/M3
- VS Smoke Path (15-step) for S8-M4 — the gate before playtests
- Playtest protocol per session (S8-M5/M6/M7) with pass conditions
- Sprint-level Definition of Done

The Production → Polish gate (Sprint 9/10 close, depending on velocity) requires a QA sign-off report; this plan defines what test cases that report will roll up.

## Backlog (post-Sprint-8)

Sprint 9+ candidates, deferred from Sprint 8 Nice to Have or earlier:
- audio system (still blocked on GDD + ADR — likely Sprint 9 design + Sprint 10 implementation)
- TD-008 (ADR-0007 architecture diagram MainRoot Control vs Node amendment)
- Sprint 5 quick-spec ADR propagation (matchup-viz + enemy-viz)
- Polish-stage UI work (icon art for hero classes, background environments for forest_reach floors, ambient SFX hooks)
- Localization framework wiring (currently no player-facing strings are externalised)
- First-run onboarding flow (game-concept GDD has tutorial requirements not yet scheduled)
