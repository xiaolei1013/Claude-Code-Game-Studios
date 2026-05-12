# Sprint 19 — 2026-08-09 to 2026-08-18 (9 working days, nominal)

> **Status: GROUNDWORK AUTHORED 2026-05-07** by S18-S5 autonomous-execution session, continuing the 8-sprint pre-emptive Sprint-N+1 plan cadence (Sprint 14 plan during Sprint 13 close → Sprint 15 plan during Sprint 14 close → Sprint 16 plan during Sprint 15 mid-flight → Sprint 17 plan during Sprint 16 mid-flight → Sprint 18 plan during Sprint 17 autonomous close-out → this Sprint 19 plan during Sprint 18 autonomous close-out). 9th consecutive sprint plan authored before its nominal window. The planning artifact stack now reaches **16 weeks ahead of real-time** (Sprint 19 nominal window: 2026-08-09 → 2026-08-18; current real-time: 2026-05-07).

> **Calibration note**: at 16 weeks ahead, the cadence is now more disciplinary than timely. Pre-emption serves as a forcing function for "did we identify enough autonomous-doable items in this autonomous session?" rather than as a planning artifact that will be acted on in real-time. Re-validate via `/sprint-plan` before Sprint 19 kickoff (2026-08-09); the actual Sprint 18 outcomes will substantially reshape Sprint 19's contents.

## Sprint Goal

**Convert Sprint 18 playtest findings into shipped MVP polish + close the V1.0 design block + open the release-candidate prep track.** Sprint 18 surfaced P0/P1/P2 calibration findings via S18-M3 playtest report; Sprint 19 closes the P0 blockers + ships P1 calibration tweaks + advances at least one V1.0 GDD to APPROVED. In parallel, Sprint 19 opens the release-candidate hardening track: cert-config sanity check, build-pipeline shake-out, store-listing copy first-pass.

**Definition of Sprint 19 success**: (a) every P0 finding from S18-M3 playtest report is closed (shipped fix OR documented defensible-default ADR); (b) ≥80% of P1 calibration tweaks shipped; (c) at least one of {Prestige #31, Class Synergy #32} first-pass GDD APPROVED (whichever didn't land in Sprint 18); (d) Sprint 18 retrospective committed; (e) Sprint 20 plan groundwork authored; (f) initial RC build pipeline produces a Steam-Deck-target build artifact.

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

**Calibration warning**: Sprint 19 is the first **post-MVP-feature-complete** sprint. The "autonomous well IS dry" pattern that started in Sprint 17 + held in Sprint 18 will continue here — Sprint 19's autonomous surface is largely retro authoring + plan groundwork + tooling hardening. Pre-emption ratio forecast: 20–40%.

## Pre-flight checklist (Day 0)

- [ ] Sprint 18 retrospective committed (`production/retrospectives/sprint-18-retrospective-<date>.md`)
- [ ] S18-M3 playtest report committed with P0/P1/P2/P3 findings classified
- [ ] All S18 commits pushed to main
- [ ] `tests/` is green at Sprint 18 close (≥1660 tests / 0 failures expected — Sprint 18 baseline 1633 + Settings + Onboarding + V1.0 GDD test surface)
- [ ] Settings overlay UI + Onboarding flow shipped (S17-M3 + S18-M2 carry-forward closes)

## Tasks

### Must Have (Critical Path)

| Story ID | Task | Owners | Estimate (days) | Dep | Notes / AC |
|---|---|---|---|---|---|
| S19-M1 | **Close all S18-M3 playtest P0 findings** — each P0 either ships a code fix OR commits a defensible-default ADR (ADR-0016 silent-MVP precedent) explaining why the issue is intentional. Scope is unknowable today; budget here is the ceiling. | game-designer + gameplay-programmer + producer | 2.0d | S18-M3 playtest report committed |
| S19-M2 | **Ship ≥80% of S18-M3 P1 calibration tweaks** — typically one-line constant changes in EconomyConfig / hero leveling curve / floor unlock pacing / matchup hint prose. Each tweak references the playtest finding ID + has a regression test if it touches a formula. | gameplay-programmer + economy-designer | 1.5d | S18-M3 playtest report committed |
| S19-M3 | **Remaining V1.0 GDD APPROVED** — whichever of {Prestige #31, Class Synergy #32} didn't land in Sprint 18. First-pass authoring is autonomous-doable; APPROVED verdict via `/design-review` is human-gated. | game-designer + systems-designer | 1.5d | Sprint 18 close |
| S19-M4 | **Sprint 18 retrospective** — track 9-sprint-running pre-emption ratio + the post-MVP-feature-complete inflection. Document the Sprint 13–17 (>95%) → Sprint 18 (forecast 35–55%) transition empirically. | producer + claude-code | 0.25d | Sprint 18 nominal window closed |
| S19-M5 | **Initial RC build pipeline produces Steam-Deck-target artifact** — no codesigning / store assets yet, just a working `tools/build/` invocation that produces a runnable Steam-Deck-target export from main. Validates the build chain end-to-end before cert work begins. | devops-engineer + release-manager | 1.5d | none |

**Sprint 19 Must Have total**: ~6.75d. Tight against 7.2d available — assume some Sprint 18 carry-forward absorbs the slack.

### Should Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S19-S1 | **Steam page copy first-pass** — Steam store listing draft (long description, short description, system requirements, screenshot captions). Final copy owned by writer; first-pass uses GDD content as source. | writer + community-manager | 0.5d | none |
| S19-S2 | **Cross-GDD sweep iteration #5** — if any new drift surfaces during Sprint 18 review batches (Settings + Onboarding implementation often surfaces drift between GDD #29/#30 and consumer interfaces). Convergence model: each iteration shrinks. | producer + game-designer | 0.25d | drift surfaces during S18 review |
| S19-S3 | **Sprint 20 plan groundwork** — 10th consecutive pre-emptively-authored sprint plan. Scope candidates: cert prep, store submission rehearsal, post-launch live-ops scaffolding. | producer + claude-code | 0.25d | none |
| S19-S4 | **Locale CSV expansion** — finalize the English-source corpus before locale freeze; identify any V1.0 strings that should be English-only (technical UI like "F1/F2/F3") vs. translatable narrative. | localization-lead + writer | 0.5d | Settings + Onboarding shipped |
| S19-S5 | **Manual QA test plan formalization** — convert S18-M3's playtest scope into a reusable QA test plan + smoke-check checklist (S18-N3 → here if not landed). Establishes the pre-RC QA cadence. | qa-tester + qa-lead | 0.5d | S18-M3 playtest report committed |
| S19-S6 | **Performance budget verification on Steam Deck** — ADR-0017's silent-MVP defensibility was conditional on dev-machine baseline holding; first Steam-Deck profile pass surfaces real numbers. May trigger ADR-0017 pivot. | performance-analyst + technical-artist | 1.0d | S19-M5 RC build artifact exists |

### Nice to Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S19-N1 | **HD-2D shader pass implementation** — if S19-S6 surfaces enough headroom on Steam Deck OR ADR-0017's pivot trigger fires, kick off the deferred shader work. Otherwise extend silent-MVP defensible default. | technical-artist + godot-shader-specialist | 2.0d | S19-S6 evidence + ADR-0017 status |
| S19-N2 | **Audio sourcing pivot trigger evaluation** — same shape as S18-N2 if not closed. Mobile port milestone is the most likely trigger; remains gated on user/budget input. | audio-director + claude-code | 0.5d | ADR-0016 pivot trigger fires |
| S19-N3 | **Save-format V2 schema bump rehearsal** — when the first V1.0 design lands a save-shape change (Prestige's prestige_count counter, Class Synergy's synergy_unlocks dict), Story 010's chain gains its first real branch. Author the migration body + regression test. | gameplay-programmer | 1.0d | V1.0 GDD with save-shape change APPROVED |
| S19-N4 | **systems-index Implementation Status maintenance** — flip whichever systems' Status flipped from "scaffolded" to "implemented" during Sprint 18 (#19 Guild Hall, #29 Onboarding, #30 Settings most likely). | producer + claude-code | 0.25d | S18 implementation closes |
| S19-N5 | **Project README + CONTRIBUTING.md polish** — first-time-contributor onboarding text. Gated on the project being open to outside contributors (post-MVP launch question). | writer + technical-director | 0.5d | post-launch decision |

## Sprint 19 sequencing recommendation

- **Day 1 morning**: S19-M4 Sprint 18 retro (0.25d)
- **Day 1 afternoon — Day 3**: S19-M1 P0 closure (2.0d) — bounded by playtest findings; if none surface as P0, this is "verified clean" rather than fix work
- **Day 3-4**: S19-M2 P1 calibration tweaks (1.5d)
- **Day 4-6**: S19-M3 V1.0 GDD APPROVED (1.5d)
- **Day 6-7**: S19-M5 RC build pipeline (1.5d)
- **Day 7-9**: S19-S items (Steam page + sweep #5 + Sprint 20 plan + locale CSV + QA test plan + Steam Deck perf), buffer-permitting

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **S18-M3 playtest reveals architectural P0** | LOW–MEDIUM | HIGH | Architectural P0s require a re-design pass + ADR — likely re-scope Sprint 19 + 20 entirely. Mitigation: design-review rigor in Sprints 13–17 should prevent surprise architectural failures; if one surfaces it's a project-level event, not a sprint-level one. |
| **Steam Deck profile reveals ADR-0017 invalidation** | MEDIUM | MEDIUM–HIGH | If silent-MVP defaults break on real hardware, the HD-2D pass becomes unblocked and S19-N1 promotes to S19-M-tier. Realistic possibility once real hardware enters the loop. |
| **Build pipeline shake-out reveals platform-specific bugs** | MEDIUM | MEDIUM | First export to Steam Deck target is high-leverage for surfacing platform-specific path / save-location / input issues. Budget S19-M5 generously (1.5d) precisely because surprises are likely. |
| **The autonomous well shallows below 20%** | HIGH (continuing trend) | LOW | Sprint 19 is structurally a polish + RC sprint; most work is human-gated by design. Continue using the freed time for documentation polish + S/N-tier items + Sprint 20 plan. |

## Dependencies on External Factors

- **S18-M3 playtest report findings** — every Must-Have except M4 is gated on knowing what playtest surfaced.
- **Steam Deck hardware access** — gates S19-M5 + S19-S6 + S19-N1.
- **`/design-review` feedback velocity** — gates S19-M3 V1.0 GDD APPROVED.

## Definition of Done for Sprint 19

- [ ] All S18-M3 playtest P0 findings closed (shipped fix OR defensible-default ADR)
- [ ] ≥80% of S18-M3 P1 calibration tweaks shipped with regression tests
- [ ] At least one of {Prestige #31, Class Synergy #32} first-pass GDD APPROVED
- [ ] Sprint 18 retrospective committed
- [ ] Sprint 20 plan groundwork authored
- [ ] Initial RC build pipeline produces Steam-Deck-target artifact
- [ ] Cross-GDD sweep iteration #5 committed (if drift surfaced)
- [ ] Full unit + integration sweep ≥1660 tests, 0 failures, 0 errors (Sprint 18 baseline + Settings + Onboarding + S19 calibration regression tests)
- [ ] Sprint 19 retrospective committed at `production/retrospectives/sprint-19-retrospective-<date>.md`

## Sprint 20+ candidates (post-Sprint-19)

- Whichever V1.0 stub GDD didn't land in S19-M3 (Prestige OR Class Synergy)
- Cert-prep + store submission rehearsal (Steam) — gated on RC build pipeline working in Sprint 19
- ADR-0017 HD-2D pivot trigger evaluation if S19-S6 surfaces invalidation
- ADR-0016 audio sourcing pivot if mobile port milestone enters scope
- Post-launch live-ops scaffolding (telemetry events, A/B test framework, patch-notes pipeline)
- Beta release candidate + closed-beta playtester onboarding flow
- Save-format V2 migration if S19-N3 didn't ship in Sprint 19
- Steam Deck verification badge submission flow

## Notes

- Authored 2026-05-07 by S18-S5 autonomous-execution session — 9th consecutive pre-emptively-authored sprint plan. Re-validate via `/sprint-plan` if anything material changes between now and Sprint 19 kickoff (2026-08-09); the actual Sprint 18 outcomes will substantially reshape Sprint 19's contents (especially M1/M2 which are entirely playtest-driven).
- Sprint 19 is the project's first **post-MVP-feature-complete** sprint. The pivot from "build features" to "polish + harden + cert" is the headline narrative for the retro.
- **Pre-emption ratio forecast**: Sprint 19 forecast 20–40% — continuing the downward shift from Sprints 18's 35–55%. This is the steady-state for a project at MVP-feature-complete maturity.
- After Sprint 19, the project should have a **Steam-Deck-target RC build artifact** + **playtest-validated MVP** + **at least one V1.0 design block APPROVED** + **store listing copy in draft**. Sprint 20+ work transitions toward (a) cert prep, (b) post-launch live-ops scaffolding, (c) V1.0 implementation if MVP launch is on schedule.
