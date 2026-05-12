# Sprint 13 — 2026-05-13 to 2026-05-22 (9 working days)

> **Status: PARTIALLY CLOSED 2026-05-13** — Day 0 audit revealed substantial pre-emptive completion: S13-M1 (ADR-0016 silent-MVP), S13-M2 (Return-to-App Screen 282-line impl + tests), S13-S1 (OE E2E test 411 lines), S13-S3 (real XP curve in HeroRoster.add_xp + Orchestrator.xp_per_floor_clear), S13-N2 (PATTERNS.md 460 lines) were all shipped during the 2026-05-06 → 2026-05-09 autonomous-execution window. S13-S4 (scaffold archival) closed this session. S13-M4 (Hero Detail) deferred to Sprint 14 pending UX pass. S13-S2 (Settings overlay) deferred to Sprint 14 pending UX pass. S13-M3 (AC-9 close-reload smoke) remains the one outstanding human-gated Must Have.
>
> **Pre-emptive audit lesson**: This sprint's authoring (2026-05-13) didn't first verify what was already in the codebase from the pre-emptive cadence. 5 of 12 stories turned out to be already-done. Future real-time sprint planning should run a "what's already shipped" sweep against the proposed scope before finalizing Must Haves.
>
> **Original status**: REAL-TIME AUTHORED 2026-05-13 — first sprint authored under the new playtest-driven cadence after the Sprint 21 pre-emptive cadence retirement. Replaces the pre-emptive Sprint 13 scaffold from 2026-05-06.

## Sprint Goal

**Close the offline-experience endcap + decide on audio + start polishing the placeholder overlays.** Sprint 12 (v0.0.0.9, shipped 2026-05-13) closed the cozy idle-game register playable end-to-end through 5 floors. Sprint 13 closes the three visible gaps from playtest-05: (1) no UI for offline rewards on relaunch, (2) silent audio (cues fire but no `.wav` / `.ogg`), (3) Settings and Hero Detail overlays are 8-line placeholders.

**Definition of Sprint 13 success**: A player who closes the app for 30+ minutes and reopens sees a cozy summary modal with accumulated offline gold + level-ups; the audio sourcing decision is made (and either implemented OR documented as silent-MVP); the Hero Detail overlay is reachable with real content and a close affordance.

## Capacity

- Total days: 9 working (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

**Calibration note**: This is the FIRST real-time sprint. Sprints 11-12 absorbed pre-emptive surface area (0.6× plan estimate ratio); Sprint 13 will surface real day-by-day variance. Hold strict 1.0× plan estimates and defer aggressively if any Must Have hits >1.5× its estimate.

## Pre-flight checklist (Day 0)

- [ ] Sprint 12 closure verified — v0.0.0.9 merged to main as PR #50, e242418
- [ ] `tests/` is green at Sprint 13 start (2058/2058 PASS expected, per Sprint 12 close)
- [ ] `production/session-state/active.md` reflects Sprint 12 closure
- [ ] `user://settings.cfg` does NOT exist on dev machine (clean before Settings overlay work in S13-S2)
- [ ] Pre-emptive Sprint 14-21 scaffolds identified for archival in S13-S4 (`production/sprints/sprint-14.md` through `sprint-21.md`)

## Tasks

### Must Have (Critical Path — close playtest-05 gaps)

| ID | Task | Owner | Est. Days | Dep | Acceptance Criteria |
|----|------|-------|-----------|-----|---------------------|
| S13-M1 | **Audio sourcing decision — ADR-0016 (already accepted)** — silent-MVP with documented pivot triggers (3+ playtests flag missing audio · ≥$200 budget approval · mobile port milestone · sprint capacity surplus). `game-concept.md` §Audio Needs already cites the ADR. Sprint 13 acknowledges the decision is binding; S13-N1 sourcing remains gated on a pivot trigger firing. | audio-director + creative-director | **DONE 2026-05-07 (pre-emptive)** — verified 2026-05-13 | none | ADR-0016 accepted; `game-concept.md` §Audio Needs cites it; no Sprint 13 work required. |
| S13-M2 | **Return-to-App Screen wire-up — DONE pre-emptive** — full implementation at `assets/screens/return_to_app/return_to_app.gd` (282 lines): subscribes to `OfflineProgressionEngine.offline_rewards_collected` + `cap_reached`; reads cached summary via `OfflineProgressionEngine.last_summary()`; renders gold/kills/floors + cap notice; Acknowledge → `SceneManager.request_screen("guild_hall")`. Locale strings at `assets/locale/en.csv` (`return_to_app_*` keys). OfflineProgressionEngine.gd:368 routes to `return_to_app` on replay completion. Integration test at `tests/integration/return_to_app/return_to_app_screen_test.gd` passes. | ui-programmer + ux-designer | **DONE (verified 2026-05-13)** | none | Existing test suite covers signal connections, render paths, signal disconnect on exit; UX polish (animated counters, particle burst) deferred to Sprint 14+. |
| S13-M3 | **Story 016 AC-9 manual close-reload smoke + report** — deferred from playtest-05. Real Godot build session: dispatch → clear → quit → reopen → verify state preserved (heroes, gold, formation, floor unlock). Document at `production/playtests/playtest-06-ac9-close-reload-2026-05-??.md`. | producer + qa-tester | 0.5d | none | Playtest report committed; explicit PASS or list of regressions; if regressions, file P0 issues. |
| S13-M4 | **Hero Detail overlay real content — DEFERRED to Sprint 14** — modal implementation IS pre-emptively shipped (584-line `assets/screens/hero_detail/hero_detail_modal.gd` extending Screen, with set_target_hero API, full lifecycle, integration tests). BLOCKER: there's no UI surface that currently invokes it. The GDD says "Guild Hall HeroCard tap" but Guild Hall has no hero cards; Formation Assignment's hero tap already means "assign to slot". Wire-up requires UX pass + Guild Hall HeroCard implementation. Defer to Sprint 14 after `/ux-design hero-detail-overlay` + `/ux-design guild-hall-roster-panel`. | ui-programmer + ux-designer | 0.0d (deferred) | UX pass | DEFERRED: see Sprint 14+ candidates. The modal exists; wire-up is the gap. |

**Must Have total**: 3.5 days. Within 7.2-day available with ~3.7d for Should Have absorption.

### Should Have

| ID | Task | Owner | Est. Days | Dep |
|----|------|-------|-----------|-----|
| S13-S1 | **OE Story 10 — E2E offline replay budget verification test** (per `offline-progression-engine.md` §J Story 10). `tests/integration/offline_progression_engine/end_to_end_offline_replay_test.gd` asserts AC-OE-12 (5s ADVISORY total wall-clock budget — flagged ADVISORY because min-spec mobile cannot be modeled in headless CI) + AC-OE-13 (16ms BLOCKING per-chunk wall-clock budget, verified via `summary.total_replay_wall_time_ms / summary.chunks_consumed` proxy). | qa-tester + gameplay-programmer | 0.5d | S13-M2 done |
| S13-S2 | **Settings overlay real content** — 8-line placeholder → volume slider (Master + Music + SFX, wired to AudioRouter API) + reduce_motion toggle (wired to `SceneManager._settings_cfg_path` pattern from S12-S2) + Close button. Reachable from a new gear icon on Guild Hall (small additive .tscn change). | ui-programmer + audio-director | 1.0d | none |
| S13-S3 | **HeroLeveling — real XP curve** — replace the S10-M4 "+1 per clear" stub with the per-class XP curve from `hero-class-database.md`. Adds `add_xp(amount)` + `xp_to_next_level` getter; level-up triggers on threshold; `hero_leveled` signal payload includes new_level. | gameplay-programmer + economy-designer | 1.0d | none |
| S13-S4 | **Archive Sprint 14-21 pre-emptive scaffolds** — move `production/sprints/sprint-14.md` through `sprint-21.md` to `production/sprints/archive/` and add a `PRE-EMPTIVE-CADENCE-RETIRED.md` README at the sprints root explaining the cadence retirement decision (per Sprint 21 S21-S3 scope, which never executed). | producer + claude-code | 0.5d | none |

**Should Have total**: 3.0 days. Realistic absorption depends on Must Have actuals.

### Nice to Have

| ID | Task | Owner | Est. Days | Dep |
|----|------|-------|-----------|-----|
| S13-N1 | **Audio asset sourcing (non-silent branch only)** — IF S13-M1 decision is non-silent: source 11 SFX cues + 2 music beds + 2 stingers per `audio-system.md` §C.2/§C.3 + place at canonical paths. | audio-director | 1.5d | S13-M1 non-silent |
| S13-N2 | **`tests/PATTERNS.md`** — distill captured patterns from Sprints 11-12 retros + project memory entries (gdunit4 signal API, Array-spy lambda, hygiene-barrier reset, ConfigFile path-override, async-API-change-regression-audit, debug-build spy field pattern) into a discoverable doc. | qa-lead + godot-gdscript-specialist | 0.25d | none |
| S13-N3 | **Recruit pool refresh on `first_launch` boundary** — if playtest-06 surfaces "pool feels stale," ship a daily-reset boundary. Currently resets on every app boot per ADR-0015 OQ-0015-1 MVP scope. | gameplay-programmer | 0.5d | playtest-06 signal |
| S13-N4 | **Sprint 13 retrospective** at `production/retrospectives/sprint-13-retrospective-<date>.md` | producer + claude-code | 0.25d | sprint close |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|--------------|
| Story 016 AC-9 close-reload smoke | Deferred from S12-S1 (playtest-05 session was consumed by the 9 wiring fixes) | → S13-M3 (0.5d) |
| Return-to-App Screen UI | GDD OE Story 9 deferred from S12-S3 | → S13-M2 (1.0d) |
| Audio binary assets | Deferred from S12-S5 (architecture only shipped) | → S13-M1 decision + S13-N1 sourcing |
| OE E2E perf test | GDD OE Story 10 deferred from S12-S3 | → S13-S1 (0.5d) |

## Sprint 13 sequencing recommendation

- **Day 1 morning**: S13-M1 audio sourcing decision (gating). Time-box at half a day; silent-MVP fallback is documented.
- **Day 1 afternoon**: optional `/ux-design` passes for Hero Detail + Settings (parallel; quick spec for S13-M4 + S13-S2).
- **Day 2–3**: S13-M2 Return-to-App Screen authoring + SceneManager modal integration.
- **Day 3–5**: S13-M4 Hero Detail overlay + formation_assignment tap wire.
- **Day 5**: S13-M3 close-reload manual smoke (real build session). Schedule in advance — it's a 15-min session.
- **Day 6–7**: Should Have cherry-pick — S13-S1 (E2E test; depends on M2), S13-S2 (Settings overlay), S13-S4 (archive scaffolds).
- **Day 7+**: S13-S3 HeroLeveling XP curve (largest Should Have; may slip to Sprint 14 if Must Haves run long).
- **Day 9**: buffer + S13-N4 retrospective.

**Anti-pattern to avoid**: do NOT autonomously execute through carryover Should Haves the way Sprints 11-12 did. Real-time means: ship Must Haves, validate via playtest-06, write retro, plan Sprint 14 from retro signal. Don't pile on.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **S13-M1 audio sourcing decision turns into a long debate** — commission vs. license vs. AI-under-license vs. silent is a creative-direction call with no clear default | MEDIUM | LOW (silent fallback is clean) | Time-box decision to Day 1 morning. Silent-MVP is the documented fallback. Don't let scope of S13-N1 sourcing block S13-M2 implementation. |
| **S13-M4 Hero Detail UX has no design pass** — no `/ux-design` for the stat card layout has run; could ship looking generic | MEDIUM | MEDIUM | Run quick `/ux-design hero-detail-overlay` on Day 1 (parallel with S13-M1). If no UX bandwidth, ship a minimum-viable parchment-themed list-of-stats layout. Polish iteration in Sprint 14. |
| **First real-time sprint surfaces day-by-day slippage masked by pre-emptive absorption** | HIGH | MEDIUM | Plan for 1.0× estimates, not 0.6×. Defer aggressively if Must Have slips >1.5×. Don't autonomous-execute through carryover Should Haves — bring them up next sprint. |
| **playtest-06 (S13-M3) surfaces save-persist regressions** | LOW (Sprint 11 round-trip tests cover the core path) | HIGH (would block release) | Treat regressions as P0 immediately; pause other Must Haves to fix. Hotfix branch off main if needed. |
| **The 9 fixes from playtest-05 introduce subtle regressions visible only in extended play** | MEDIUM | LOW–MEDIUM | Sprint 13 includes S13-M3 playtest as the primary detection mechanism. If regressions surface, escalate to a hotfix sprint. |

## Dependencies on External Factors

- **Audio sourcing budget / vendor availability** — gates S13-N1 non-silent path. Out of engineering scope; needs project-level approval at S13-M1 decision point.
- **`/ux-design hero-detail-overlay` + `/ux-design settings-overlay`** — should run Day 1 if time allows; S13-M4 and S13-S2 can ship without formal UX pass but will need polish iteration in Sprint 14.
- **Real Godot build for S13-M3 close-reload smoke** — human-gated; cannot be autonomous-doable. Schedule a 15-minute session before Day 5.
- **No external API/SDK dependencies.**

## Definition of Done for Sprint 13

- [ ] All 4 Must Have tasks (S13-M1 through S13-M4) closed via `/story-done` with COMPLETE or COMPLETE WITH NOTES
- [ ] ADR-0017 audio sourcing decision committed (silent OR non-silent)
- [ ] Return-to-App Screen renders on `offline_rewards_collected` and dismisses to guild_hall cleanly
- [ ] Hero Detail overlay reachable from formation_assignment hero card tap; shows class + level + stats; close affordance works
- [ ] Story 016 AC-9 close-reload manual smoke executed + playtest-06 report committed
- [ ] Full test suite ≥2075 (2058 baseline + new tests for M2/M4 + S1) with 0 failures
- [ ] Sprint 13 retrospective committed (S13-N4)
- [ ] No regressions surfaced from the 9 playtest-05 fixes
- [ ] QA plan exists at `production/qa/qa-plan-sprint-13-<date>.md`

## Sprint 14+ candidates (post-Sprint-13)

- HeroLeveling UI work (level-up toast polish, XP bar on hero cards)
- Recruitment Stories 5-7 RecruitScreen UI refactor + cost-stability invariant tests
- FormationAssignment Stories 5-7 (RecruitScreen-style refactor + named-presets V1.0 surface)
- First-run onboarding flow per Onboarding GDD #29 (now that gold seed wiring is shipped)
- Multi-biome unlock + Matchup Assignment polish (Forest Reach is the only biome; biome 2 design pass needed)
- Steam Deck verification rehearsal (1280×800 native, 60fps stable)
- Audio asset sourcing follow-through (if S13-M1 = silent decision and we want non-silent for v0.1.0)
- Telemetry events V1.0 implementation (per the pre-emptive S20-N3 taxonomy doc in the archived scaffold)

## Notes

- **Real-time authored 2026-05-13** following the Sprint 21 pre-emptive cadence retirement. This is the canonical pattern for Sprint 14+.
- **playtest-driven** — Must Have items map directly to playtest-05 findings, not autonomous-loop output. See `production/playtests/playtest-05-sprint-12-2026-05-12.md` for the source signal.
- **Solo review mode** — no PR-SPRINT producer gate per `production/review-mode.txt`.
- **Pattern captured in project memory**: see `feedback_playtest_driven_closure.md` for the "100% tests pass ≠ shipped" lesson driving this sprint's playtest-first prioritization.
