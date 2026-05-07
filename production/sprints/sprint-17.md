# Sprint 17 — 2026-07-19 to 2026-07-28 (9 working days, nominal)

> **Status: GROUNDWORK AUTHORED 2026-05-07** by post-Sprint-16-S16-S1 autonomous-execution session, continuing the pre-emptive Sprint-N+1 plan cadence (Sprint 14 plan during Sprint 13 close → Sprint 15 plan during Sprint 14 close → Sprint 16 plan during Sprint 15 mid-flight → this Sprint 17 plan during Sprint 16 mid-flight). 7th consecutive sprint plan authored before its nominal window. The planning artifact stack now reaches **14 weeks ahead of real-time** (Sprint 17 nominal window: 2026-07-19 → 2026-07-28; current real-time: 2026-05-07).

## Sprint Goal

**Polish the screen scaffolds with /design-review feedback + ship Onboarding flow + iterate visual layers.** Sprint 16 pre-emptively scaffolded 4 MVP UI screens (Recruit + Hero Detail + Matchup Assignment + Victory Moment) with contract layers + minimal `.tscn`s; Sprint 17 takes the `/design-review` feedback from Sprint 15-M3 + S16 review batches and polishes those scaffolds into shippable visual quality. In parallel, Sprint 17 ships the Onboarding flow (S16-S2 carry-forward) + the Sprint 16 retrospective + Sprint 18+ plan groundwork.

**Definition of Sprint 17 success**: (a) at least 2 of the 4 scaffolded screens (Recruit / Hero Detail / Matchup / Victory Moment) have visual polish APPROVED via design-review re-pass; (b) Onboarding flow implementation lands per GDD #29; (c) Sprint 16 retrospective committed; (d) cross-GDD sweep iteration #4 closes the 4 drift items surfaced during S16-M3 scaffold authoring (DataRegistry list_category, FloorUnlock single-arg is_unlocked, missing floor_unlocked signal, Dungeon shape flatten).

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

**Calibration warning**: 7 consecutive sprints at >95% pre-emption — Sprint 17 starts after Sprint 16's actual nominal-window work (which mostly involves human-driven `/design-review` feedback iteration). The autonomous surface in Sprint 17 is largely **visual polish iteration on shipped scaffolds + onboarding flow + retro/plan authoring**. Plan at 1.0× estimates with HIGH variance — visual polish work depends on review feedback quality + volume.

## Pre-flight checklist (Day 0)

- [ ] Sprint 16 retrospective committed (`production/retrospectives/sprint-16-retrospective-<date>.md`)
- [ ] At least 4 of the 13 drafted GDDs flipped from DRAFT to APPROVED or CONCERNS-only via S15-M3 batch reviews
- [ ] Cross-GDD sweep iteration #2 + #3 drift items consolidated into a single follow-up review document
- [ ] 4 scaffold screens have at least one /design-review pass each (Recruit / Hero Detail / Matchup / Victory Moment)
- [ ] All S15+S16 commits pushed to main
- [ ] `tests/` is green at Sprint 16 close (≥1573 tests / 0 failures expected)

## Tasks

### Must Have (Critical Path)

| Story ID | Task | Owners | Estimate (days) | Dep | Notes / AC |
|---|---|---|---|---|---|
| S17-M1 | **Recruit Screen visual polish iteration** — apply S15-M3 + S16 review feedback to `recruitment.tscn` + `.gd`. Specific known carve-outs: ClassPortrait sourcing decision (or placeholder lock per ADR-0016 precedent); SelectedSlotButton theme variation on affordable RecruitButtons; gold-counter pulse animation on recruit-spend. | ui-programmer + ux-designer | 0.75d | Recruit Screen #21 review APPROVED via S15-M3 |
| S17-M2 | **Hero Detail Modal visual polish iteration** | ui-programmer | 0.5d | Roster #22 review APPROVED via S15-M3 |
| S17-M3 | **Onboarding flow implementation** (S16-S2 → here) | gameplay-programmer + ux-designer | 1.0d | Onboarding #29 review APPROVED via S15-M3 |
| S17-M4 | **Sprint 16 retrospective** | producer + claude-code | 0.25d | Sprint 16 window closed |
| S17-M5 | **Cross-GDD sweep iteration #4** — consolidate the drift items from sweep iterations #2 (BASE_REFRESH_COST) + #3 (DataRegistry list_category, FloorUnlock single-arg, floor_unlocked signal, Dungeon shape) into GDD revisions. Format: post-`/design-review` propagation edits. | producer + game-designer | 0.5d | none |

**Sprint 17 Must Have total**: ~3.0d. Substantial buffer remains in 7.2d available.

### Should Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S17-S1 | **Matchup Assignment Screen visual polish iteration** — BiomeTab full layout + FloorDetailPanel rendering + matchup hint locale strings | ui-programmer + ux-designer | 0.75d | Matchup #23 review APPROVED |
| S17-S2 | **Victory Moment Screen visual polish iteration** — DimBackdrop fade-in + ContinuationPromptLabel pulse + staggered reveal + dungeon_run_view route replacement (one-line change) | ui-programmer | 0.5d | Victory Moment #25 review APPROVED |
| S17-S3 | **Settings overlay UI implementation** (S15-M2 carry-forward if not landed) | ui-programmer + accessibility-specialist | 2.0d | Settings #30 review APPROVED |
| S17-S4 | **AudioRouter `_test_play_*_log` debug-spy ADR** (S14-N1 → S15-S3 → S16-S3 → here) — author when 2nd consumer (Settings overlay UI) lands | godot-gdscript-specialist | 0.25d | S17-S3 (or earlier) shipped with `_test_play_*_log` consumer adoption |
| S17-S5 | **UIFramework.format_short_number formatter** — closes the cross-GDD gap surfaced during S16-M2 + S16-M1 (GDDs #21 + #22 + #25 reference the helper but it doesn't exist). ~0.15d implementation + 4-5 tests. | godot-gdscript-specialist | 0.2d | none |
| S17-S6 | **Sprint 18 plan groundwork** | producer + claude-code | 0.25d | none |

### Nice to Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S17-N1 | **Hero Leveling AC-15-02 calibration adjustment** (if S15-M4 playtest revealed leveling drag) — one-line orchestrator change | gameplay-programmer | 0.1d | S15-M4 playtest evidence |
| S17-N2 | **FloorUnlock `floor_unlocked` signal** (closes S16-M3 sweep iteration #3 — Matchup Assignment GDD §C.2 + §E.3 + AC-23-15 reference the signal which doesn't exist) | gameplay-programmer | 0.25d | none |
| S17-N3 | **FloorUnlock `is_unlocked(biome_id, floor_index)` 2-arg overload** (V1.0+ multi-biome prep + closes S16-M3 sweep #3 drift) | gameplay-programmer | 0.3d | none |

## Sprint 17 sequencing recommendation

- **Day 1 morning**: S17-M4 Sprint 16 retro (0.25d)
- **Day 1 afternoon**: S17-M5 cross-GDD sweep iteration #4 (0.5d) — fix all drift items in GDDs first so visual polish work uses consistent specs
- **Day 1-2**: S17-S5 UIFramework.format_short_number (0.2d) — small dependency that unblocks gold-formatting polish across screens
- **Day 2-3**: S17-M1 Recruit Screen + S17-M2 Hero Detail Modal visual polish (1.25d combined)
- **Day 3-4**: S17-S1 Matchup Assignment + S17-S2 Victory Moment visual polish (1.25d)
- **Day 4-5**: S17-M3 Onboarding flow implementation (1.0d)
- **Day 5-7**: S17-S3 Settings overlay UI if carry-forward (2.0d) OR cherry-pick remaining S/N items
- **Day 7-9**: S17-S6 Sprint 18 plan + S17-S4 debug-spy ADR + S17-N items

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Sprint 15+16 reviews slip past Sprint 17 window** | MEDIUM | HIGH | Sprint 17 conservative case absorbs more S15-M2 carry-forward; visual polish work shifts to Sprint 18+. |
| **Visual polish reveals layout-architecture flaws requiring scaffold rewrite** | LOW | MEDIUM | Per cross-GDD sweep validation, contract layers are sound; layout drift is non-architectural. |
| **Cross-GDD sweep iteration #4 surfaces additional drift not yet captured** | LOW–MEDIUM | LOW | Each iteration converges (#1 = signal arities + ADR refs; #2 = numeric defaults; #3 = API signatures + missing signals). #4 may surface remaining edge cases; budget 0.5d covers this. |
| **The autonomous well shallows further** | HIGH (continuing trend) | LOW | Sprint 17 is heavily human-gated (review feedback iteration) — that's the expected state. Pre-emptive scaffolds in Sprints 14-16 already absorbed the autonomously-doable portion. |

## Dependencies on External Factors

- **`/design-review` feedback velocity** — gates S17-M1 + S17-M2 + S17-M3 + S17-S1 + S17-S2 + S17-S3 implementation work.
- **User availability for visual review** — Sprint 17's primary gating constraint.

## Definition of Done for Sprint 17

- [ ] At least 2 of {Recruit, Hero Detail, Matchup, Victory Moment} screens visually polished + APPROVED
- [ ] Onboarding flow implementation lands per GDD #29
- [ ] Cross-GDD sweep iteration #4 commits drift fixes back to GDDs
- [ ] Sprint 16 retrospective committed
- [ ] Sprint 18 plan groundwork authored (continuing the cadence)
- [ ] Full unit + integration sweep ≥1600 tests, 0 failures, 0 errors (visual polish + Onboarding adds tests)
- [ ] Sprint 17 retrospective committed at `production/retrospectives/sprint-17-retrospective-<date>.md`

## Sprint 18+ candidates (post-Sprint-17)

- Remaining screen visual polish (whichever 2-of-4 didn't land in Sprint 17)
- HD-2D Pipeline / VFX Vertical Slice tier work (when ADR-0017 pivot trigger fires; needs Steam Deck access OR dev-machine baseline acceptance)
- Settings overlay UI carry-forward if S17-S3 deferred
- V1.0 progression block design (#31 Prestige + #32 Class Synergy full first-pass GDDs)
- Mobile platform port milestone (hard pivot trigger for ADR-0016 audio + ADR-0017 HD-2D)
- Schema migration when first save-version bump occurs (currently V1.0)
- ADR-X04 Recruitment determinism extension if MVP playtest reveals issues
- Manual QA sweep of the full MVP gameplay loop (recruit → assign → matchup-select → dispatch → run → victory_moment → guild_hall) once visual polish converges

## Notes

- Authored 2026-05-07 by post-Sprint-16-S16-S1 close-out work. Re-validate via `/sprint-plan` if anything material changes between now and Sprint 17 kickoff (2026-07-19).
- Sprint 17 transitions the project from "build the MVP feature set" to **"polish + iterate"** phase. Most contract-layer code is shipped; visual polish + review feedback iteration drives the remaining MVP work.
- **Continuing the Sprint 13/14/15/16 retro tracking**: pre-emption ratio for Sprint 17 will likely be SUBSTANTIALLY LOWER than Sprint 14's 100% — visual polish + review iteration are inherently human-gated. This may finally break the >95% streak. Sprint 17 retro should explicitly track this transition.
- After Sprint 17, the project should have a substantially shippable MVP: 4 polished screens + Settings overlay + Onboarding flow + drift-resolved GDDs + retro cadence sustained. Sprint 18+ work transitions toward (a) playtest-driven calibration, (b) remaining Vertical Slice tier polish (HD-2D + VFX), (c) post-MVP content authoring, (d) mobile port preparation.
- **Strategic note**: Sprint 17 is the first sprint where the project's autonomous-vs-human balance shifts toward human. Prior sprints leveraged autonomous Day-0 absorption; Sprint 17 absorbs less because the review-feedback loop is the dominant work. This is a healthy maturation of the cadence — autonomous work front-loaded the foundation, human-driven review polishes the surface.
