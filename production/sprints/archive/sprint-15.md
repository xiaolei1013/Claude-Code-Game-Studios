# Sprint 15 — 2026-06-29 to 2026-07-08 (9 working days, nominal)

> **Status: GROUNDWORK AUTHORED 2026-05-07** by post-Sprint-14-retro autonomous-execution session. Re-validate via `/sprint-plan` if anything material changes between now and Sprint 15 kickoff. Sprint 14 retro accepts that sprint windows are doc artifacts and execution is continuous-autonomous-when-surface-available; Sprint 15 inherits that framing.

## Sprint Goal

**Process the 9-GDD design-review backlog and ship the Settings overlay UI.** Sprint 14 closed 3/5 Must Haves autonomously; the 2 deferred Must Haves (M2 Settings GDD review + M3 Settings overlay UI) are Sprint 15's primary work. The 9 first-pass GDDs drafted across the 2026-05-06/07 cumulative design-coverage push are pending `/design-review` — Sprint 15 batches the review feedback so downstream stories (S14-S3 Onboarding, S14-S4 Recruit Screen, S14-S5 Guild Hall full impl) become unblocked for Sprint 16+.

**Definition of Sprint 15 success**: (a) Settings GDD #30 review APPROVED or CONCERNS-only; (b) Settings overlay UI implemented and live in Guild Hall; (c) at least 4 of the 9 drafted GDDs review-converged (APPROVED / CONCERNS-only); (d) one Hero Leveling-focused playtest captured to validate AC-15-02 calibration before more content lands.

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

**Calibration warning** (continuing Sprint 12 + 13 + 14 retros): the autonomous Day-0 absorption pattern has been at 100% pre-emption for 5 consecutive sprints. Sprint 15 starts with a SMALLER autonomous surface than Sprint 14 because (a) the MVP design-coverage gap is exhausted (all "Not Started" MVP-tier UI screens drafted) and (b) the largest remaining items (S14-M2/M3) are gated on `/design-review`, an interactive skill that requires human-in-the-loop. **Plan at 1.0× estimates with HIGHER variance** — autonomously-doable items will be smaller; human-gated items dominate.

## Pre-flight checklist (Day 0)

- [ ] Settings GDD #30 has had at least one `/design-review` pass (the load-bearing gate for M3)
- [ ] All 14 Sprint 14 commits pushed to main
- [ ] Sprint 14 retrospective committed (`production/retrospectives/sprint-14-retrospective-2026-05-07.md` ✓)
- [ ] ADR-0016 + ADR-0017 statuses confirmed Accepted (✓ both flipped 2026-05-07)
- [ ] `tests/` is green at Sprint 14 close (1503 tests / 0 failures expected)

## Tasks

### Must Have (Critical Path)

| Story ID | Task | Owners | Estimate (days) | Dep | Notes / AC |
|---|---|---|---|---|---|
| S15-M1 | **Settings GDD #30 design-review pass** (S14-M2 carry-forward) — `/design-review settings-options-accessibility.md` runs interactively. Expected 5–10 BLOCKING items per first-pass-GDD precedent. Revisions resolve in-GDD or refile cross-GDD as Open Questions. | game-designer + qa-lead + user (interactive) | 0.5d (review) + 0.5d (revisions if needed) | none | Verdict: APPROVED or CONCERNS-only. |
| S15-M2 | **Settings overlay UI implementation** (S14-M3 carry-forward, now unblocked by S15-M1) — implement the 5 stories from Settings GDD §J: overlay scene authoring + volume slider wiring + toggle wiring + save/reset/auto-save flows + edge cases (replay-gating, corruption recovery, headless). | ui-programmer + accessibility-specialist | 2.0d | S15-M1 APPROVED | All 14 ACs from Settings GDD §H pass via integration tests at `tests/integration/settings_overlay/`. Volume slider mapping per §C.2 (linear-to-dB with 20·log10). Mute hard-overrides per §C.3. reduce_motion round-trips through `user://settings.cfg` per S12-S2 contract. Locale dropdown reads `TranslationServer.get_loaded_locales()`. |
| S15-M3 | **`/design-review` batch processing of 4+ drafted GDDs** — per Sprint 14 retro recommendation #3, batch reviews to amortize human attention cost. Priority order: (1) Settings #30 (gates M3 — already counted in S15-M1), (2) Hero Leveling #15 (gates nothing now — already implemented; review still informative), (3) Recruit Screen #21 (gates S14-S4), (4) Onboarding #29 (gates S14-S3). | game-designer + user (interactive) | 1.5d (~0.4d per GDD) | none | At least 4 of 9 GDDs converge to APPROVED or CONCERNS-only verdict. The remaining 5 carry to Sprint 16. |
| S15-M4 | **Hero Leveling-focused playtest (S14-S1 carry-forward + targeted scope)** — manual play session validating AC-15-02 calibration. Specifically: re-run Floor 3 multiple times after first-clear to verify the strict-AC interpretation (XP-per-floor-clear ties to floor_cleared_first_time signal — re-runs get kill-XP only) doesn't produce leveling drag. Capture findings in `production/playtests/playtest-05-hero-leveling-calibration-2026-XX-XX.md`. | qa-tester + producer + user (manual play) | 0.5d | none | Playtest report committed; findings inform OQ-15-1 calibration decision. |

**Sprint 15 Must Have total**: 0.5d M1 + 2.0d M2 + 1.5d M3 + 0.5d M4 = 4.5d. Fits within 7.2d available.

### Should Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S15-S1 | **Recruit Screen UI implementation** (S14-S4 carry-forward) — implement per Recruit Screen GDD #21 §J 5-story sequence. Pre-scoped at ~0.75d. | ui-programmer + ux-designer | 0.75d | Recruit Screen #21 APPROVED via S15-M3 |
| S15-S2 | **Onboarding flow implementation** (S14-S3 carry-forward) — STARTING_GOLD constant ✓ already shipped; integration test simulating cold-launch + manual smoke checklist + first-recruit prompt + first-dispatch tutorial ribbon | gameplay-programmer + ux-designer | 1.0d | Onboarding GDD #29 APPROVED via S15-M3 |
| S15-S3 | **AudioRouter `_test_play_*_log` debug-spy ADR** (S14-N1 carry-forward) — re-evaluate when S15-M2 Settings overlay UI lands; 2nd consumer threshold likely met at that point | godot-gdscript-specialist | 0.25d | S15-M2 in progress |
| S15-S4 | **DungeonRunOrchestrator pre_dispatch_gold snapshot field** (Victory Moment GDD #25 OQ-25-1 dependency) — ~5 LoC orchestrator extension capturing pre-dispatch gold balance in run_snapshot for the Victory Moment screen's gold-delta render. Pairs with S16+ Victory Moment implementation. | gameplay-programmer | 0.15d | none |

### Nice to Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S15-N1 | **FormationAssignment.set_target API extension** (Matchup Assignment GDD #23 OQ-23-4 dependency) — adds set_target(biome_id, floor_index) + get_target accessor pair on FormationAssignment autoload. Pairs with S16+ Matchup Assignment Screen implementation. | gameplay-programmer | 0.2d | none |
| S15-N2 | **Cross-GDD consistency sweep** — read all 9 drafted GDDs + flag cross-reference drift (e.g., signal signature mismatches, dependency arrow mismatches between §F and the upstream/downstream GDDs). Output: a single review document. | producer | 0.5d | none |

## Sprint 15 sequencing recommendation

- **Day 1 morning**: S15-M1 `/design-review` on Settings GDD #30 (interactive). User-driven; if BLOCKING surface < 5 items, revisions resolve same-day.
- **Day 1 afternoon - Day 3**: S15-M2 Settings overlay UI implementation. Follow the 5-story sequence in Settings GDD §J.
- **Day 3-4**: S15-M3 `/design-review` batch — 4+ GDDs. Priority order per S15-M3 notes.
- **Day 4-5**: S15-S1 Recruit Screen UI (after Recruit Screen #21 review converges).
- **Day 5-6**: S15-S2 Onboarding implementation.
- **Day 6-7**: S15-M4 Hero Leveling playtest + S15-S3 (AudioRouter debug-spy ADR if 2nd consumer landed) + S15-S4 (pre_dispatch_gold orchestrator extension).
- **Day 7-9**: cherry-pick remaining Should/Nice items; absorb any S15-M1 revision overrun.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **S15-M1 design-review surfaces > 10 BLOCKING items on Settings GDD** | MEDIUM | MEDIUM | Time-box revision at 1.0d. If > 1.0d converges, defer M2 to Sprint 16; keep the sprint goal achievable on the other 3 Must Haves. |
| **The 9-GDD review backlog overwhelms human attention budget** | MEDIUM | MEDIUM | Batch reviews per S15-M3; cap at 4 GDDs in Sprint 15; carry remaining 5 to Sprint 16. |
| **Hero Leveling playtest reveals a calibration miss** | LOW–MEDIUM | LOW | Calibration fix is a one-line orchestrator change (move XP grant out of `if awarded:` branch into Layer 2 gate per Sprint 13 retro note). Ship the fix in Sprint 16 if discovered. |
| **The autonomous well shallows mid-sprint** | HIGH | LOW | Per Sprint 14 retro, this is the expected state going forward. If the autonomous session has nothing actionable, surface the gap to the user explicitly rather than manufacturing work. |
| **/design-review skill availability + project lead time** | MEDIUM | HIGH | S15-M1 is the primary gate; S15-M3 multiplies the gate. Without /design-review running, Sprint 15's Must Haves are blocked at >50%. Mitigation: schedule a focused review session early in the sprint window. |

## Dependencies on External Factors

- **`/design-review` skill availability** — gates S15-M1 + S15-M3 (interactive, human-driven; no autonomous workaround).
- **User availability for review batching** — gates S15-M3 (the 1.5d budget assumes user can attend reviews in concentrated sessions; if user's attention is fragmented, the budget may not hold).
- **User availability for manual playtest** — gates S15-M4.

## Definition of Done for Sprint 15

- [ ] S15-M1 Settings GDD #30 design-review verdict committed (APPROVED or CONCERNS-only)
- [ ] S15-M2 Settings overlay UI live in Guild Hall via gear icon; manual smoke confirms volume/mute/reduce_motion round-trip
- [ ] S15-M3 4+ GDDs converged to APPROVED/CONCERNS-only verdict
- [ ] S15-M4 Hero Leveling playtest report committed
- [ ] Full unit + integration sweep ≥1500 tests, 0 failures, 0 errors (no regressions from M2 implementation)
- [ ] Sprint 15 retrospective committed at `production/retrospectives/sprint-15-retrospective-<date>.md`

## Sprint 16+ candidates (post-Sprint-15)

- HD-2D shader pass / Vertical Slice tier (when ADR-0017 pivot trigger fires; needs Steam Deck access OR dev-machine baseline acceptance)
- Recruit Screen UI implementation (S15-S1 if not landed)
- Onboarding flow implementation (S15-S2 if not landed)
- Guild Hall Screen full implementation (gated on Guild Hall #19 + Settings #30 reviews; ~3.0d)
- Matchup Assignment Screen UI implementation (~1.0d; gated on #23 review)
- Roster / Hero Detail Modal implementation (~0.75d; gated on #22 review; pairs with Guild Hall full impl)
- Victory Moment Screen UI implementation (~1.0d; gated on #25 review + S15-S4 pre_dispatch_gold field)
- Vertical Slice tier #26 HD-2D Pipeline + #27 VFX System full first-pass GDDs (V1.0+ stubs ship in Sprint 15 per the Sprint 14 retro recommendation)

## Notes

- Authored 2026-05-07 by post-Sprint-14-retro work. Re-validate via `/sprint-plan` if anything material changes between now and Sprint 15 kickoff (2026-06-29).
- Sprint 15 is the first sprint where the autonomous well is genuinely shallow. Expect the Day-0 absorption cadence to degrade naturally — most Must Haves require human-in-the-loop work (interactive `/design-review`, manual playtest). The autonomous session can usefully tackle Should/Nice items + small API extensions (S15-S4, S15-N1) but cannot autonomously close M1 / M3 / M4.
- Pre-emption ratio for Sprint 15 will likely be substantially lower than Sprint 14's 100% — the human-gated Must Haves resist pre-emption by design.
- After Sprint 15, the project's MVP polish bar should be substantially closer to ship: Settings overlay live, design-review feedback processed for the largest GDDs, Hero Leveling calibration validated, audio sourcing locked (ADR-0016), HD-2D deferral locked (ADR-0017). Remaining Sprint 16+ work is screen UI implementation for the screens whose GDDs reviewed cleanly.
- **Continuing the Sprint 13/14 retro recommendation**: track the pre-emption ratio in active.md when Sprint 15 closes; flag if 6 consecutive sprints exceed 80%.
