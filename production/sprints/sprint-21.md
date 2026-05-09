# Sprint 21 — 2026-08-29 to 2026-09-07 (9 working days, nominal)

> **Status: GROUNDWORK AUTHORED 2026-05-09** by S20-S2 autonomous-execution session, continuing the 10-sprint pre-emptive Sprint-N+1 plan cadence (Sprint 14 plan during Sprint 13 close → Sprint 15 plan during Sprint 14 close → ... → Sprint 20 plan during Sprint 19 autonomous close-out → this Sprint 21 plan during Sprint 20 autonomous close-out). 11th consecutive sprint plan authored before its nominal window. The planning artifact stack now reaches **18 weeks ahead of real-time** (Sprint 21 nominal window: 2026-08-29 → 2026-09-07; current real-time: 2026-05-09).

> **Calibration warning — recommended upper bound reached**: Sprint 20's plan (S20-S2 task description) explicitly flagged Sprint 21 as the **recommended upper bound** for pre-emptive sprint plan authoring. Beyond Sprint 21, the planning artifact will be entirely rewritten before its window opens — so writing it ahead of time produces zero usable output. Sprint 22+ planning is deferred to real-time `/sprint-plan` invocation when Sprint 21's actual window opens (or when real-time outcomes from Sprints 19/20 indicate scope changes). This is the LAST pre-emptive sprint plan in the cadence.

## Sprint Goal

**Open the V1.0 Class Synergy implementation track + close the cert-prep prerequisites + ship the first beta release candidate.** Sprint 20 closed the V1.0 design block (both Prestige #31 + Class Synergy #32 first-pass GDDs) and shipped the cert-prep checklist + 3-platform build parity. Sprint 21 starts the V1.0 implementation work proper, beginning with Class Synergy (the simpler of the two — no save-format bump). In parallel, Sprint 21 produces the first closed-beta build artifact and onboards the first wave of external playtesters.

**Definition of Sprint 21 success**: (a) Class Synergy V1.0 implementation Story 1 (`FormationAssignment.detect_active_synergy` + `RunSnapshot.synergy_id`) shipped; (b) closed-beta build v0.1 artifact uploaded to Steam Direct backend; (c) first 3-5 external playtesters onboarded per S20-N2 onboarding doc; (d) Sprint 20 retrospective committed; (e) `tests/` suite ≥1763 + Class Synergy Story 1's new tests (estimate +15-20).

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work + first-real-implementation-of-V1.0-block discovery friction
- Available: **7.2 days**

**Calibration warning**: Sprint 21 is the **first V1.0 implementation sprint**. The "autonomous well IS dry" pattern that started in Sprint 17 + held through Sprint 20 will continue here — Sprint 21's autonomous surface is implementation work that requires the GDDs to be APPROVED first. If `/design-review` on PRs #20 (Class Synergy) and #23 (Prestige) hasn't completed by Sprint 21 kickoff, S21-M1 slips to Sprint 22 and the sprint pivots to other Should-Haves. Pre-emption ratio forecast: 25–45%.

## Pre-flight checklist (Day 0)

- [ ] Sprint 20 retrospective committed (`production/retrospectives/sprint-20-retrospective-<date>.md`)
- [ ] PR #20 (Class Synergy first-pass GDD) **APPROVED via `/design-review`** — gates S21-M1
- [ ] PR #23 (Prestige first-pass GDD) APPROVED — does NOT gate S21-M1 (Class Synergy is Sprint 21 implementation; Prestige is Sprint 22+)
- [ ] PR #24 (cross-GDD F.3 amendments) merged
- [ ] All Sprint 20 commits pushed to main
- [ ] `tests/` is green at Sprint 20 close (≥1763 expected; no test-surface change forecast for Sprint 20 since it was design + cert-prep + retro)
- [ ] Sprint 20 S20-M4 platform parity verified (Linux + Windows + macOS artifacts produced; or documented platform-X failure note)
- [ ] Closed-beta playtester recruitment per S20-N2 onboarding doc — 3-5 external testers identified

## Tasks

### Must Have (Critical Path — V1.0 Class Synergy implementation kickoff)

| Story ID | Task | Owners | Estimate (days) | Dep | Notes / AC |
|---|---|---|---|---|---|
| S21-M1 | **Class Synergy implementation Story 1** — `FormationAssignment.detect_active_synergy(snapshot) -> String` + `RunSnapshot.synergy_id: String` field + AC-CS-01..05 detection accuracy + AC-CS-12/18 save round-trip + V1.0+ forward-compat. Per `class-synergy-system.md` §C.1 + §D.1. | gameplay-programmer + godot-gdscript-specialist | 1.5d | PR #20 APPROVED |
| S21-M2 | **Closed-beta build v0.1 artifact + Steam Direct upload** — produce a `tools/build/build.sh linux` + `windows` + `macos` artifact set; smoke-check via Steam Deck (if hardware available); upload to Steam Direct backend with closed-beta visibility (NOT public-store-page); generate beta-key batch (3-5 keys for first wave). | release-manager + devops-engineer | 1.0d | Sprint 20 S20-M4 platform parity done |
| S21-M3 | **Sprint 20 retrospective** — track 11-sprint-running pre-emption ratio + the post-MVP-feature-complete + V1.0-design-block-closed double-inflection. Document what % of Sprint 20 was actually autonomous-doable (forecast: 60-80%) and what % was reactive to the V1.0 design pass + cert-prep specifics. Capture lessons for Sprint 22+ planning cadence shift to real-time. | producer + claude-code | 0.25d | Sprint 20 nominal window closed |
| S21-M4 | **First closed-beta playtester onboarding** — invite 3-5 external testers per S20-N2 onboarding doc; distribute beta keys; provide Discord/Forms feedback channel; set 7-day initial-playtest window expectation. Document outreach + first-week response rate as Sprint 21 close-out evidence. | community-manager + producer | 0.5d | S21-M2 build + keys ready |

**Sprint 21 Must Have total**: ~3.25d. Within 7.2d available with ~3.95d for Should-Have absorption.

### Should Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S21-S1 | **Class Synergy implementation Story 2** — `attribute_kill_gold` + new `attribute_kill_xp` formula extension with `synergy_multiplier` factor per `class-synergy-system.md` §C.3 + §D.2/D.3. Adds AC-CS-06..11 ACs. | gameplay-programmer | 1.5d | S21-M1 done |
| S21-S2 | **Class Synergy implementation Story 3** — Audio integration (2 new cues + suppression per `class-synergy-system.md` §C.4) + AC-CS-14 + AC-CS-15 localization keys (6 new in `assets/locale/en.csv`). | gameplay-programmer + audio-director | 0.75d | S21-S1 done |
| S21-S3 | **Sprint 22+ planning kickoff (REAL-TIME, not pre-emptive)** — instead of authoring `production/sprints/sprint-22.md` ahead of time per the prior cadence, this Sprint 21 task closes the pre-emptive cadence and authors a `production/sprints/PRE-EMPTIVE-CADENCE-RETIRED.md` doc explaining: (a) why the cadence retired at Sprint 21; (b) the real-time `/sprint-plan` workflow that replaces it; (c) lessons learned from 11 consecutive pre-emptive plans (Sprint 13 → Sprint 21). | producer + claude-code | 0.5d | none |
| S21-S4 | **First-wave playtest findings triage** — within Sprint 21's 9-day window, the closed beta will produce some feedback. Triage into P0/P1/P2/P3 buckets per `production/sprints/sprint-19.md` S19-M1 conventions. Items become Sprint 22 Must Haves OR Sprint 23+ backlog. | qa-lead + producer | 0.5d | S21-M4 done + 7-day playtest window opened |
| S21-S5 | **Cross-GDD audit pass — Prestige #31 cross-GDD amendments** — IF PR #24 (combined Class Synergy + Prestige F.3 amendments) didn't already cover this, finalize the Prestige-specific cross-GDD references. Single batch pass; one commit. | game-designer | 0.25d | PR #24 status checked |

### Nice to Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S21-N1 | **Class Synergy implementation Story 4** — UI badge wiring on formation_assignment screen + reduce-motion variant per AC-CS-17. UX iteration may be required (S20-S1 Steam page copy iteration #2 pattern). | ui-programmer + ux-designer | 1.0d | S21-S1 + S21-S2 done |
| S21-N2 | **Steam Deck Verified badge first submission attempt** — if S20-N6 rehearsal indicated readiness, submit the closed-beta artifact for the Steam Deck Verified initial review. May surface 2-3 small fixes (controller mapping, default text size) — capture as Sprint 22+ work. | release-manager | 0.5d | S21-M2 build done + S20-N6 rehearsal complete |
| S21-N3 | **Telemetry events V1 implementation kickoff** — per S20-N3 taxonomy doc, implement the first 3-5 most-load-bearing events (run-dispatched, run-completed, prestige-completed, recruit-purchased, first-launch). Cozy-register-respecting; opt-in default; minimal PII. | analytics-engineer + gameplay-programmer | 1.0d | S20-N3 taxonomy doc committed |
| S21-N4 | **systems-index Implementation Status maintenance** — flip Class Synergy #32 from "FIRST-PASS DRAFT (pending /design-review)" to "FIRST-PASS DRAFT APPROVED" or "FIRST-PASS DRAFT IMPLEMENTED" depending on Sprint 21 progress. Same for Prestige #31. | producer + claude-code | 0.25d | PR #20 + #23 review verdicts landed |
| S21-N5 | **Closed-beta v0.1 hotfix release** — first beta will likely surface a Day-0 P0 issue (typical first-real-build pattern). Reserve buffer for 1-2 build cycles to push hotfixes if needed. | gameplay-programmer + release-manager | 0.75d | S21-S4 P0 surfaced |

## Sprint 21 sequencing recommendation

- **Day 1 morning**: S21-M3 Sprint 20 retro (0.25d)
- **Day 1 afternoon — Day 3**: S21-M1 Class Synergy Story 1 (1.5d) — autoload-side + RunSnapshot field + tests
- **Day 3 afternoon — Day 4**: S21-M2 closed-beta build + Steam Direct upload (1.0d)
- **Day 4 afternoon**: S21-M4 first playtester onboarding (0.5d)
- **Day 5-6**: S21-S1 Class Synergy Story 2 (formula extension; 1.5d)
- **Day 6-7**: S21-S2 Class Synergy Story 3 (audio + localization; 0.75d)
- **Day 7 afternoon**: S21-S3 pre-emptive cadence retirement doc (0.5d) + S21-S4 first-wave triage (0.5d, if feedback has arrived)
- **Day 8-9**: Nice-to-Have absorption (S21-N1 UI badge / S21-N3 telemetry / buffer)

**Anti-pattern to avoid**: don't try to ship all 4 Class Synergy implementation stories in Sprint 21. Stories 1 + 2 + 3 are realistic; Story 4 (UI) likely slips to Sprint 22 if the closed beta surfaces P0/P1 priorities. Story 5 (cross-GDD F.3 amendments) was already executed by PR #24 — DO NOT re-execute.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **PR #20 review verdict is REVISED** — Class Synergy first-pass needs revision before APPROVED. S21-M1 slips. | MEDIUM | MEDIUM | If REVISED, Sprint 21 absorbs the revision pass into S21-M3 retro time + pivots Day 1-3 to Should-Have items. S21-M1 slips to Sprint 22. |
| **Closed-beta build v0.1 has a Day-0 P0** | MEDIUM–HIGH | LOW | First builds typically have 1-2 small bugs. S21-N5 reserves 0.75d hotfix capacity. If P0 doesn't materialize, S21-N5 reverts to other Nice-to-Have items. |
| **Steam Direct backend / cert process surfaces unknowns** — first upload of an actual beta artifact to Steam Direct may surface paperwork gaps (age rating, DRM choice, etc.). | MEDIUM | MEDIUM | S20-M2 cert-prep checklist is the pre-flight; if it surfaced gaps Sprint 21 absorbs them as S21-M2 sub-items. Time-box at 1.5d total; if exceeded, beta upload slips a sprint. |
| **External playtester recruitment yields <3 testers** | MEDIUM | LOW | Project lead can act as solo "fresh-eyes" tester per Sprint 9 S9-M4 precedent. The playtest signal is qualitative anyway; 3-5 testers is a target, not a contractual minimum. |
| **The autonomous well shallows below 25%** | HIGH (continuing trend) | LOW | Sprint 21 is structurally a half-implementation, half-process-shift sprint. Most work is human-gated by review verdicts + playtest data. The pre-emptive cadence retirement doc (S21-S3) is the meta-deliverable that frees future sprints from autonomous-output expectations. |
| **Sprint 19 + Sprint 20 outcomes substantially reshape Sprint 21** | HIGH | LOW (acknowledged) | This sprint plan is authored 18 weeks ahead. Sprint 19 + Sprint 20's actual outcomes — playtest findings, GDD review verdicts, hardware availability — will reshape Must Haves. Treat this plan as scaffolding; re-validate via `/sprint-plan` at Sprint 21 kickoff. **This is the LAST pre-emptive sprint plan**; Sprint 22+ uses real-time `/sprint-plan` exclusively. |

## Dependencies on External Factors

- **PR #20 + #23 review verdicts**: Sprint 21 M1 (Class Synergy implementation) is gated on PR #20 APPROVED. If REVISED, M1 absorbs the revision iteration.
- **Steam Direct account ready**: gates S21-M2 upload. Steamworks SDK + age-rating filings + DRM-choice declaration must be filled out per S20-M2 checklist.
- **Steam Deck hardware**: gates S21-M2 smoke-check verification + S21-N2 Verified badge submission. Without hardware, both ship as scaffold-only.
- **External playtesters**: gates S21-M4 + S21-S4. Recruitment is human-coordinated.
- **Closed-beta feedback channel**: Discord vs Forms vs custom — designer's call per S20-N2 onboarding doc.
- **`/design-review` feedback velocity**: gates PR #20, #23 verdicts.

## Definition of Done for Sprint 21

- [ ] Class Synergy implementation Story 1 shipped + tests passing (≥15 new tests covering AC-CS-01..05 + AC-CS-12 + AC-CS-18)
- [ ] Sprint 20 retrospective committed
- [ ] **Pre-emptive cadence retirement doc committed** at `production/sprints/PRE-EMPTIVE-CADENCE-RETIRED.md` (replaces Sprint 22 plan groundwork)
- [ ] Closed-beta build v0.1 artifact uploaded to Steam Direct backend
- [ ] 3-5 external playtesters onboarded with beta keys
- [ ] First-wave playtest findings triaged into P0/P1/P2/P3 buckets
- [ ] Full unit + integration sweep ≥1763 baseline + Class Synergy Story 1 net-new tests; 0 failures
- [ ] PR #20 + #23 review verdicts landed (APPROVED or REVISED-then-APPROVED)
- [ ] Sprint 21 retrospective committed at `production/retrospectives/sprint-21-retrospective-<date>.md`

## Sprint 22+ candidates (post-Sprint-21; AUTHORED REAL-TIME, NOT PRE-EMPTIVELY)

Sprint 22+ planning shifts to **real-time `/sprint-plan` invocation** per the cadence retirement decision. Sprint 22 candidates listed here as scaffolding only:

- Class Synergy implementation Story 2 (formula extension) if not done in Sprint 21
- Class Synergy implementation Story 3-4 (audio + UI) carry-forward
- Prestige #31 implementation epic kickoff (Story 1 — `HeroRoster.is_prestige_eligible` + `prestige_hero` + V1→V2 migration)
- Sprint 22+ playtest findings P0 closure (whatever surfaces from S21-S4)
- Steam Deck Verified badge submission (post-S21-N2 first-attempt iteration)
- Telemetry events V1 implementation continuation (post-S21-N3)
- Cert submission rehearsal #2 (if Sprint 21 surfaced gaps)
- Beta v0.2 release (post-S21-N5 hotfix learnings)
- Locale CSV non-English-locale Pass 1 (gated on EN locale freeze)
- Save-format V2 migration implementation (per Prestige Story spec)

## Notes

- Authored 2026-05-09 by S20-S2 autonomous-execution session — **11th and FINAL consecutive pre-emptively-authored sprint plan**. Sprint 22+ uses real-time `/sprint-plan` invocation exclusively.
- Sprint 21 is the project's **first V1.0 implementation sprint**. Closes the pivot from "build features" → "polish + harden + cert + V1.0 GDDs" → "V1.0 implementation + closed-beta + cert submission". Sprint 21+ work transitions toward live-service prep.
- **Pre-emption ratio forecast**: Sprint 21 forecast 25–45% — slight uptick from Sprint 20's 15–35% because Class Synergy implementation IS autonomous-doable once the GDD is APPROVED. The closed-beta + playtester onboarding work is decidedly NOT autonomous.
- **The cadence retirement (S21-S3) is the headline meta-deliverable**: an explicit doc explaining why Sprint 22+ uses real-time planning and what lessons the 11-plan pre-emptive cadence taught. The doc names: (a) the diminishing-returns curve (planning artifact stack at 18 weeks ahead → 0% chance of being acted on as-written); (b) the autonomous-well-shallowing pattern that drove the cadence (high autonomous output during Sprint 11-16 era → progressively lower output at Sprint 17-20 → minimal at Sprint 21+); (c) the inflection at MVP-feature-complete (Sprint 16) and V1.0-design-block-closed (Sprint 20) that closed the autonomous opportunity space.
- After Sprint 21, the project should have **Class Synergy V1.0 partially implemented + closed-beta v0.1 in playtester hands + first feedback triaged + pre-emptive planning cadence formally retired**. Sprint 22+ work is driven by real playtest data and real-time creative-direction calls, not autonomous output.
- **This plan WILL be substantially rewritten before its nominal window opens** (2026-08-29). The actual Sprint 19 + Sprint 20 outcomes — playtest findings, GDD review verdicts, hardware availability, beta tester response — will reshape every Must Have item. This plan exists for two reasons: (1) closing the cadence cleanly with a documented final entry; (2) providing scaffolding scope for Sprint 21 kickoff so the real-time `/sprint-plan` invocation has a starting point to refine rather than a blank page. Per S21-S3 retirement doc, future sprints skip even this scaffolding step.
