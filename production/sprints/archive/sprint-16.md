# Sprint 16 — 2026-07-09 to 2026-07-18 (9 working days, nominal)

> **Status: GROUNDWORK AUTHORED 2026-05-07** by post-Sprint-15-S15-N2 autonomous-execution session, continuing the pre-emptive Sprint-N+1 plan cadence (Sprint 14 plan → Sprint 15 plan → this Sprint 16 plan all authored during prior sprint windows). Re-validate via `/sprint-plan` if anything material changes between now and Sprint 16 kickoff. **The Sprint 13 retro tracking observation applies**: this is the 6th consecutive sprint authored before its nominal window; pre-emption ratio is the dominant cadence reality.

## Sprint Goal

**Implement the screen UIs whose first-pass GDDs converged cleanly via /design-review.** Sprint 15 processes the design-review backlog (9 first-pass GDDs); Sprint 16 implements the screens whose GDDs flipped to APPROVED or CONCERNS-only verdicts. The exact scope depends on Sprint 15's review velocity — Sprint 16 plans both the optimistic case (5 screens reviewed → 5 implementations) AND the conservative case (2 screens reviewed → 2 implementations + buffer for the rest).

**Definition of Sprint 16 success**: (a) at least 2 of the drafted UI screens have implementations live in the build; (b) all S15 deferred items either complete or re-deferred with explicit reason; (c) Sprint 17+ plan groundwork authored (continuing the pre-emptive pattern).

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

**Calibration warning** (continuing Sprint 12-15 retros): 6 consecutive sprints at >95% pre-emption. Sprint 16 starts after Sprint 15 has done its actual nominal-window work (which mostly involves human-driven design-review + manual playtest sessions). Plan at 1.0× estimates; the autonomous surface in Sprint 16 is largely SCREEN UI IMPLEMENTATION (which IS autonomously-doable for code-only logic + .tscn scaffolding, but visually needs eventual human verification).

## Pre-flight checklist (Day 0)

- [ ] Sprint 15 retrospective committed (`production/retrospectives/sprint-15-retrospective-<date>.md`)
- [ ] Sprint 15 verdict known: at minimum, M1 (Settings GDD review) verdict committed; M2 (Settings overlay UI) shipped or re-deferred
- [ ] At least 2 first-pass GDDs flipped from DRAFT to APPROVED or CONCERNS-only via S15-M3 batch review
- [ ] Sprint 15 deferred items audited (which carry to Sprint 16 vs Sprint 17+)
- [ ] All S14+S15 commits pushed to main
- [ ] `tests/` is green at Sprint 15 close (≥1521 tests / 0 failures expected)

## Tasks — OPTIMISTIC CASE (Sprint 15 reviewed 4+ GDDs cleanly)

### Must Have (Critical Path)

| Story ID | Task | Owners | Estimate (days) | Dep | Notes / AC |
|---|---|---|---|---|---|
| S16-M1 | **Recruit Screen UI implementation** (S14-S4 → S15-S1 → here) — 5 stories per Recruit Screen GDD #21 §J | ui-programmer + ux-designer | 0.75d | Recruit Screen #21 APPROVED via S15-M3 | All 18 ACs from §H pass via integration tests at `tests/integration/recruit_screen/`. Drift fixes from cross-GDD sweep 2026-05-07 (RecruitOutcome enum return; HeroRoster.hero_recruited 1-arg + Recruitment.hero_recruited 3-arg dual subscriber) verified during impl. Pairs with `Recruitment.get_refreshes_today()` accessor extension per sweep §Self-documented gap recommendation (~5 LoC). |
| S16-M2 | **Hero Detail Modal implementation** (Roster / Hero Detail Screen GDD #22 §J) — 4 stories + 0.05d Guild Hall integration | ui-programmer | 0.75d (modal) + 0.05d (Guild Hall HeroCard tap wiring) | Roster GDD #22 APPROVED via S15-M3 | All 20 ACs from §H pass. Atomic Level-Up transaction (try_spend → set_hero_level) verified end-to-end. Dismissal-grace-period + reduce_motion + locale-aware labels covered. |
| S16-M3 | **Matchup Assignment Screen implementation** (GDD #23 §J) — 5 stories + 0.05d formation_assignment integration | ui-programmer + ux-designer | 1.0d (screen) + 0.05d (formation_assignment.gd integration) | Matchup #23 APPROVED via S15-M3 + S15-N1 FormationAssignment.set_target API ✓ | All 18 ACs from §H pass. Single-biome MVP layout (forest_reach only) per §C.8 + §I OQ-23-1 resolution. FloorButton lock-state visuals + EnemyDistributionList render tested. |
| S16-M4 | **Sprint 15 retrospective** (continuing Sprint 10/11/12/13/14 cadence) | producer + claude-code | 0.25d | Sprint 15 window closed | Captures pre-emption ratio (will likely break the 95% streak — Sprint 15 is the first sprint with substantial human-gated work that resists pre-emption). |

**Sprint 16 Must Have total (optimistic)**: ~3.0d. Substantial buffer remains in 7.2d available.

### Should Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S16-S1 | **Victory Moment Screen implementation** (GDD #25 §J) — 5 stories + 0.05d dungeon_run_view routing replacement | ui-programmer | 1.0d (screen) + 0.05d (dungeon_run_view route) | Victory Moment #25 APPROVED via S15-M3 + S15-S4 pre_dispatch_gold field ✓ |
| S16-S2 | **Onboarding flow implementation** (S15-S2 carry-forward if not landed) | gameplay-programmer + ux-designer | 1.0d | Onboarding #29 APPROVED via S15-M3 |
| S16-S3 | **AudioRouter debug-spy ADR** (S14-N1 → S15-S3 → here) — author when 2nd consumer (Settings overlay UI from S15-M2) lands | godot-gdscript-specialist | 0.25d | S15-M2 shipped with `_test_play_*_log` consumer adoption |
| S16-S4 | **Sprint 17 plan groundwork** (continuing pre-emptive Sprint-N+1 cadence) | producer + claude-code | 0.25d | none |

### Nice to Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S16-N1 | **Recruitment.get_refreshes_today() public accessor** (cross-GDD sweep §Self-documented gap fix) — pairs with S16-M1 | gameplay-programmer | 0.05d | S16-M1 in progress |
| S16-N2 | **Hero Leveling AC-15-02 calibration adjustment** (if S15-M4 playtest reveals leveling drag) — one-line orchestrator change moving XP grant out of `if awarded:` branch into Layer 2 gate | gameplay-programmer | 0.1d | S15-M4 playtest evidence |
| S16-N3 | **Cross-GDD consistency sweep iteration** (after S15-M3 batch review surfaces the "real" /design-review revisions) — re-run the sweep methodology against the post-review GDDs to catch any drift introduced by revisions | producer | 0.5d | S15-M3 4+ GDDs reviewed |

## Tasks — CONSERVATIVE CASE (Sprint 15 reviewed only 1-2 GDDs)

If Sprint 15 closes with only 1-2 GDDs reviewed (M3 batch was time-constrained), Sprint 16 absorbs more S15 carry-forward:

### Must Have (conservative)

| Story ID | Task | Estimate | Notes |
|---|---|---|---|
| S16-M1 | Settings overlay UI (carry-forward S15-M2 if not landed) | 2.0d | Highest-priority unimplemented item |
| S16-M2 | /design-review batch — 4+ GDDs (carry-forward S15-M3 partial) | 1.5d | Continue draining the queue |
| S16-M3 | Hero Leveling playtest (carry-forward S15-M4) | 0.5d | Manual; needs human |
| S16-M4 | Sprint 15 retrospective | 0.25d | Same as optimistic |

**Conservative total**: ~4.25d. Same scope, just shifted toward design-review continuation rather than screen implementation.

## Sprint 16 sequencing recommendation (optimistic case)

- **Day 1 morning**: S16-M4 Sprint 15 retro (0.25d) — retros at sprint start to honor the pattern.
- **Day 1 afternoon - Day 3**: S16-M1 Recruit Screen UI implementation. The drift fixes from the 2026-05-07 sweep are pre-applied (try_recruit RecruitOutcome enum; dual hero_recruited subscriber); implementation closely follows §J 5-story sequence.
- **Day 3-4**: S16-M2 Hero Detail Modal — pairs naturally with S16-M1 (both consume HeroRoster + Economy signals; share patterns).
- **Day 4-6**: S16-M3 Matchup Assignment Screen — uses S15-N1 FormationAssignment.set_target API.
- **Day 6-7**: S16-S1 Victory Moment Screen (if M3 lands cleanly + Victory Moment GDD APPROVED).
- **Day 7-8**: S16-S2 Onboarding flow OR S16-S3 AudioRouter debug-spy ADR (whichever has gating cleared).
- **Day 8-9**: S16-S4 Sprint 17 plan groundwork; cherry-pick remaining Should/Nice items.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Sprint 15 reviews surface design changes that invalidate Sprint 16 implementation work** | MEDIUM | MEDIUM | Apply cross-GDD sweep recommendations BEFORE implementation; if review introduces material changes, defer the affected screen to Sprint 17. |
| **Implementing 4+ screens in one sprint risks UX consistency drift** | MEDIUM | MEDIUM | Each screen GDD already references UIFramework + parchment theme + ADR-0008 — the consistency floor is locked at the design layer. Implementation drift would surface as visual review issues post-impl. |
| **Sprint 15 retrospective reveals 6-consecutive-sprint pre-emption is unsustainable** | LOW–MEDIUM | LOW | Sprint 16 retro should explicitly recalibrate planning rhetoric if the trend reverses (Sprint 15 should be the first sprint with <95% pre-emption due to human-gated Must Haves). |
| **Recruitment.get_refreshes_today() accessor needs to land before S16-M1** | LOW | LOW | S16-N1 captures it as a 5-LoC dependency; lands in parallel with S16-M1. |

## Dependencies on External Factors

- **Sprint 15 design-review velocity** — gates which screens can be implemented in S16 vs deferred to S17+.
- **Sprint 15 manual playtest evidence** — gates S16-N2 calibration adjustment decision.
- **User availability for visual UI verification** — S16's screen implementations need eventual human visual review (Steam Deck native + mobile-portrait-capable + parchment-theme visual correctness).

## Definition of Done for Sprint 16

- [ ] At least 2 screen UI implementations live in the build (Recruit Screen + Hero Detail Modal at minimum)
- [ ] Full unit + integration sweep ≥1550 tests, 0 failures, 0 errors (each new screen adds ~10-20 tests)
- [ ] Sprint 15 retrospective committed
- [ ] Sprint 17 plan groundwork authored
- [ ] Sprint 16 retrospective committed at `production/retrospectives/sprint-16-retrospective-<date>.md`

## Sprint 17+ candidates (post-Sprint-16)

- Remaining screen UIs from Sprint 16's deferred items
- HD-2D Pipeline #26 / VFX System #27 — Vertical Slice tier full first-pass GDDs (when ADR-0017 pivot trigger fires)
- Schema migration when first save-version bump occurs (currently V1.0)
- ADR-X04 Recruitment determinism extension if MVP playtest reveals issues
- Mobile platform port milestone (hard pivot trigger for ADR-0016 audio + ADR-0017 HD-2D)
- V1.0 progression block (Prestige #31 + Class Synergy #32 full first-pass GDDs)

## Notes

- Authored 2026-05-07 by post-Sprint-15-S15-N2 close-out work (the 6th consecutive pre-emptively-authored sprint plan in the project's history). Re-validate via `/sprint-plan` if anything material changes between now and Sprint 16 kickoff (2026-07-09).
- Sprint 16 is the first sprint where SCREEN UI IMPLEMENTATION dominates the autonomous surface. Prior sprints have been heavy on design + foundational systems; Sprint 16 transitions to the "build the player-facing UI" phase. Each screen has a clean GDD + drift fixes already applied (per the cross-GDD consistency sweep 2026-05-07); implementation should be relatively low-risk.
- **Continuing the Sprint 13/14/15 retro tracking**: pre-emption ratio for Sprint 16 will depend on whether Sprint 15's actual nominal-window work proceeds at expected pace. If Sprint 15 reviews + plays converge in 5-7 days of nominal work, Sprint 16 starts with substantially MORE autonomous surface than Sprint 15 (because screen UI implementation IS autonomously-doable for code + .tscn scaffolding); pre-emption ratio likely re-climbs to >50% in Sprint 16.
- **Strategic note on Sprint 16-17 cadence**: post-Sprint-16, the project will have shipped most of its MVP UI surface. Sprint 17+ work transitions toward (a) playtest-driven calibration tweaks, (b) remaining content authoring (additional biomes / classes / enemies), and (c) Vertical Slice tier polish (HD-2D + VFX, gated on ADR-0017 pivot triggers). The "build the MVP feature set" phase converges around Sprint 17; "polish + content + ship" begins Sprint 18+.
