# Sprint 18 — 2026-07-29 to 2026-08-07 (9 working days, nominal)

> **Status: GROUNDWORK AUTHORED 2026-05-07** by S17-S6 autonomous-execution session, continuing the 7-sprint pre-emptive Sprint-N+1 plan cadence (Sprint 14 plan during Sprint 13 close → Sprint 15 plan during Sprint 14 close → Sprint 16 plan during Sprint 15 mid-flight → Sprint 17 plan during Sprint 16 mid-flight → this Sprint 18 plan during Sprint 17 autonomous-scope close-out). 8th consecutive sprint plan authored before its nominal window. The planning artifact stack now reaches **15 weeks ahead of real-time** (Sprint 18 nominal window: 2026-07-29 → 2026-08-07; current real-time: 2026-05-07).

## Sprint Goal

**Close the screen-polish backlog + ship the playtest-driven calibration loop + advance V1.0 design groundwork.** Sprint 17 polished 2 of 4 MVP screens (whichever the `/design-review` feedback velocity surfaced first); Sprint 18 finishes the remaining 2 screen polish passes + lands Settings overlay UI if it carried forward + opens the playtest-driven calibration loop with the first formal MVP playtest report. In parallel, Sprint 18 advances V1.0 design groundwork (Prestige #31 + Class Synergy #32 first-pass GDDs) and authors the Sprint 17 retrospective + Sprint 19 plan groundwork.

**Definition of Sprint 18 success**: (a) all 4 MVP screens (Recruit / Hero Detail / Matchup / Victory Moment) APPROVED via `/design-review` re-pass; (b) Settings overlay UI shipped per GDD #30 (S15-M2 → S17-S3 carry-forward closes here); (c) first formal MVP playtest report committed with calibration findings classified by severity; (d) Prestige #31 OR Class Synergy #32 first-pass GDD APPROVED; (e) Sprint 17 retrospective committed; (f) Sprint 19 plan groundwork authored.

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

**Calibration warning**: Sprint 18 marks the project's transition from "build" to "polish + iterate + V1.0-prep". Autonomous surface area is now structurally bounded — visual polish, playtest analysis, and V1.0 design all need human-in-the-loop review. The pre-emption ratio for Sprint 18 will track between 30–60% (down from Sprints 13–17's >95% streak) because the gated work *is* the work. This is the expected and healthy state for a project at this maturity stage.

## Pre-flight checklist (Day 0)

- [ ] Sprint 17 retrospective committed (`production/retrospectives/sprint-17-retrospective-<date>.md`)
- [ ] Sprint 17 sweep #4 drift fixes propagated (matchup-screen drift fixes shipped 2026-05-07; verify no further GDDs surfaced drift during S17 review batches)
- [ ] At least 2 of 4 scaffolded screens APPROVED via S17 design-review batches
- [ ] All S15+S16+S17 commits pushed to main
- [ ] `tests/` is green at Sprint 17 close (≥1620 tests / 0 failures expected — Sprint 17's autonomous adds: +6 floor_unlocked + +3 is_unlocked_in_biome + +13 format_short_number = 22 minimum; Onboarding implementation adds a further ~10–15)

## Tasks

### Must Have (Critical Path)

| Story ID | Task | Owners | Estimate (days) | Dep | Notes / AC |
|---|---|---|---|---|---|
| S18-M1 | **Remaining 2 screens visual polish iteration** — whichever 2 of 4 (Recruit / Hero Detail / Matchup / Victory Moment) did not land in Sprint 17. Apply S17-batch `/design-review` feedback to scaffolds. | ui-programmer + ux-designer | 1.5d | S17-M1/M2/S1/S2 partial completion |
| S18-M2 | **Settings overlay UI shipping** (S15-M2 → S17-S3 → here) — author and ship Settings overlay per GDD #30 if not landed in Sprint 17. Volume sliders + mute toggle + reduce_motion + colorblind palette + locale selector + accessibility text-scale. | ui-programmer + accessibility-specialist | 2.0d | Settings #30 review APPROVED via S15-M3 |
| S18-M3 | **First formal MVP playtest report** — execute end-to-end MVP gameplay loop on dev hardware, document findings via `/playtest-report` skill. Classify findings: P0 (blocks MVP ship), P1 (calibration tweak), P2 (V1.0 polish), P3 (defer). Anchor playtest scope: recruit → formation_assignment → matchup → dispatch → run (5 floors) → victory_moment → guild_hall → roster/hero-detail. | producer + qa-lead + game-designer | 1.0d | All 4 MVP screens at minimum scaffold-functional state |
| S18-M4 | **Sprint 17 retrospective** — pattern-match against the Sprint 13–17 cadence; track the predicted pre-emption-ratio inflection (Sprint 17 was forecast as the first <95% pre-emption sprint; document actual ratio + lessons for the 8-sprint cadence). | producer + claude-code | 0.25d | Sprint 17 nominal window closed |
| S18-M5 | **Prestige #31 OR Class Synergy #32 first-pass GDD APPROVED** — pick whichever has lower-blocking-content-dependency at sprint kickoff. Each is a V1.0-tier system but the design pass is autonomous-doable; APPROVED verdict via `/design-review` is the user-gated portion. | game-designer + systems-designer | 1.5d | systems-index "Vertical Slice tier" entry exists |

**Sprint 18 Must Have total**: ~6.25d. Tight against 7.2d available — likely defer one of M1/M2 to Sprint 19 if the playtest report surfaces P0 work.

### Should Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S18-S1 | **Onboarding flow polish** — if S17-M3 landed minimum-functional, Sprint 18 polishes per the post-implementation `/design-review` feedback. | ui-programmer + ux-designer | 0.5d | S17-M3 shipped |
| S18-S2 | **Hero Leveling AC-15-02 calibration adjustment** — if Sprint 18 playtest (S18-M3) reveals leveling drag, ship the orchestrator one-line change per S17-N1 deferred. | gameplay-programmer | 0.1d | S18-M3 playtest evidence |
| S18-S3 | **AudioRouter `_test_play_*_log` debug-spy ADR** — if Sprint 17 didn't ship S17-S4 (ADR was conditional on 2nd consumer adoption — Settings overlay UI counts), author the ADR now. | godot-gdscript-specialist | 0.25d | S17-S3 OR S18-M2 shipped |
| S18-S4 | **Cross-GDD sweep iteration #5** — if any new drift surfaces during Sprint 17 review batches, consolidate into GDD revisions. Convergence model: each iteration shrinks (#1=arities+ADRs; #2=numeric defaults; #3=API signatures+missing signals; #4=matchup-screen drift). #5 likely smaller. | producer + game-designer | 0.25d | Drift surfaces during S17 review |
| S18-S5 | **Sprint 19 plan groundwork** — continue the cadence; 9th consecutive pre-emptively-authored sprint plan. | producer + claude-code | 0.25d | none |
| S18-S6 | **Locale CSV expansion** — Sprint 17 added 16 keys for the 4 new screen GDDs; Sprint 18 likely adds Settings overlay + Onboarding strings (~12-20 new keys depending on scope). | localization-lead + claude-code | 0.25d | S18-M2 (Settings) + S17-M3 (Onboarding) shipped |

### Nice to Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S18-N1 | **HD-2D shader pass pivot trigger evaluation** — if dev-machine baseline acceptance lands (per ADR-0017 PROPOSED → ACCEPTED transition), kick off the HD-2D shader work. Otherwise extend the silent-MVP defensible default. | technical-artist + godot-shader-specialist | 1.0d | ADR-0017 status update |
| S18-N2 | **Audio sourcing pivot trigger evaluation** — if any of ADR-0016's 4 pivot triggers fired during Sprint 17 (post-launch playtest signal · ≥$200 budget approval · mobile port milestone · sprint-capacity AI-generation pathway), advance audio sourcing per the relevant pathway. Otherwise hold silent-MVP. | audio-director + claude-code | 0.5d | ADR-0016 status update |
| S18-N3 | **Manual QA sweep of full MVP loop** — formalize the S18-M3 playtest scope into a reusable QA test plan + smoke-check checklist. | qa-tester + qa-lead | 0.5d | S18-M3 playtest report committed |
| S18-N4 | **Save-format version bump rehearsal** — when V1.0 ships, the first save-format migration must be tested end-to-end. Author the migration test scaffold preemptively (no actual migration yet). | gameplay-programmer | 0.5d | none (anticipatory work) |
| S18-N5 | **systems-index "Implemented" tracker pass** — verify each Implemented entry's GDD has its AC-table linked to test-evidence files. Closes a long-tail traceability gap. | producer + qa-lead | 0.25d | none |

## Sprint 18 sequencing recommendation

- **Day 1 morning**: S18-M4 Sprint 17 retro (0.25d)
- **Day 1 afternoon**: S18-S4 sweep #5 if any (0.25d) — fix any drift surfaced during S17 review batches first
- **Day 1-2**: S18-M3 playtest report (1.0d) — surface P0 issues before polish work starts so polish covers the right things
- **Day 2-4**: S18-M1 remaining 2 screens visual polish (1.5d) — scope informed by playtest findings
- **Day 4-6**: S18-M2 Settings overlay UI (2.0d) — concurrent with M1 partly
- **Day 6-8**: S18-M5 Prestige OR Class Synergy GDD (1.5d) — APPROVED verdict via /design-review
- **Day 8-9**: S18-S5 Sprint 19 plan + S18-S1 Onboarding polish + N items as buffer

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Playtest reveals P0 issues requiring scope re-plan** | MEDIUM–HIGH | HIGH | First formal playtest is a known unknown — budget 0.5d post-S18-M3 to triage findings. P0 items absorb buffer; P1+ defer to Sprint 19. |
| **Settings overlay UI scope creep** | MEDIUM | MEDIUM | GDD #30 spec is locked; if review-pass reveals layout flaws, defer polish to Sprint 19 (Settings overlay in 1-week post-launch hotfix is acceptable). |
| **Sprint 18 absorbs all S17 carry-forward AND breaks new ground** | HIGH | MEDIUM | Sprint 17's autonomous-shallowing was explicit; Sprint 18 capacity is realistic about how much human-gated work fits in 7.2d. Defer aggressively. |
| **V1.0 GDD design surfaces V1.0-blocking dependencies** | LOW–MEDIUM | LOW | Both Prestige #31 and Class Synergy #32 are stub-tier in systems-index; first-pass authoring may surface schema migrations. Track in Open Questions; do not block MVP ship on V1.0 work. |
| **The autonomous well runs dry mid-sprint** | HIGH | LOW | Per Sprint 17 forecast: this is structural, not a failure. Use the freed time for review-feedback iteration, S18-N items, or documentation polish. |

## Dependencies on External Factors

- **`/design-review` feedback velocity** — gates S18-M1 + S18-M5 implementation work.
- **User availability for visual review + playtest** — Sprint 18's primary gating constraint (continued from Sprint 17).
- **Hardware access for HD-2D evaluation** — gates S18-N1 (ADR-0017 pivot trigger).
- **Budget/sourcing decisions for audio** — gates S18-N2 (ADR-0016 pivot trigger).

## Definition of Done for Sprint 18

- [ ] All 4 MVP screens (Recruit / Hero Detail / Matchup / Victory Moment) visually polished + APPROVED
- [ ] Settings overlay UI shipped per GDD #30 (S15-M2 → S17-S3 → S18-M2 carry-forward closes)
- [ ] First formal MVP playtest report committed with severity-classified findings
- [ ] At least 1 of {Prestige #31, Class Synergy #32} first-pass GDD APPROVED
- [ ] Sprint 17 retrospective committed
- [ ] Sprint 19 plan groundwork authored (continuing the cadence)
- [ ] Cross-GDD sweep iteration #5 committed (if drift surfaced)
- [ ] Full unit + integration sweep ≥1635 tests, 0 failures, 0 errors (Sprint 17's +22 baseline + Sprint 18's Settings + Onboarding tests)
- [ ] Sprint 18 retrospective committed at `production/retrospectives/sprint-18-retrospective-<date>.md`

## Sprint 19+ candidates (post-Sprint-18)

- Whichever V1.0 stub GDD didn't land in S18-M5 (Prestige OR Class Synergy)
- HD-2D Pipeline / VFX Vertical Slice tier implementation if S18-N1 pivot triggered
- Mobile platform port milestone (hard pivot trigger for ADR-0016 audio + ADR-0017 HD-2D)
- Save-format version bump rehearsal full implementation if S18-N4 scaffold lands
- ADR-X04 Recruitment determinism extension if S18-M3 playtest revealed RNG fairness issues
- Post-MVP content authoring (additional biome content, additional class content)
- Steam page assets + store listing copy preparation
- Beta release candidate build pipeline shake-out
- Localization expansion (Sprint 18 likely closes core English; Sprint 19+ could open second-locale work)

## Notes

- Authored 2026-05-07 by S17-S6 autonomous-execution session — 8th consecutive pre-emptively-authored sprint plan. Re-validate via `/sprint-plan` if anything material changes between now and Sprint 18 kickoff (2026-07-29).
- Sprint 18 is the project's first **playtest-anchored sprint**. The playtest report (S18-M3) is the critical-path artifact — it informs everything else (which screens get polished where, which calibration tweaks are P0 vs deferred, whether V1.0 GDDs need scope adjustments).
- **Pre-emption ratio forecast**: Sprint 18 forecast is 35–55% — well below Sprints 13–17's >95% but matching the structural reality of a project transitioning to "iteration anchored on user-gated work." This is the healthy steady state.
- After Sprint 18, the project should have a **playtest-validated, fully-polished MVP** with the first V1.0 design block in motion. Sprint 19+ work transitions toward (a) MVP release-candidate hardening, (b) V1.0 implementation if MVP launch is on schedule, (c) post-MVP content authoring depending on playtest signal.
