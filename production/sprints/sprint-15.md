# Sprint 15 — 2026-05-14 to 2026-05-27 (10 working days)

> **Status: Day-0 plan authored 2026-05-14** within hours of Sprint 14 retro merge (PR #61), honoring Sprint 14 retro action item #1. Real-time cadence continues per Sprints 13 + 14 precedent.

## Sprint Goal

**Harden the existing Guild Hall + Dispatch surface and ship visible Hero Detail interactivity.** Sprint 14 wired the screens; Sprint 15 finishes their contracts (FormationAssignment write-path refactor, Hero Detail actions) and pays down Sprint 14's carryover action items. No new major systems — closing existing surface area.

**Definition of Sprint 15 success**: (a) FormationAssignment screen writes route through the FormationAssignment autoload (AC-FA-12); (b) Hero Detail modal has working level-up confirm + dismiss-hero actions; (c) HeroLeveling AC-15-02 calibration validated via focused playtest; (d) `tests/PATTERNS.md` updated with the lifecycle-asymmetry pattern from PR #58 → #59.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days
- Available: **8.0 days**

**Calibration note**: Sprint 14 hit ~6.0d realized cost in 5 calendar days. Sprint 15 is 2× the window with similar story density → realistic to plan ~6.0d Must+Should, leave 2.0d for unplanned + Nice-to-Have absorption.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance |
|----|------|-------|-----------|--------------|------------|
| S15-M1 | **FormationAssignment Story 5** — refactor `formation_assignment.gd` screen to route writes through `FormationAssignment.commit()` instead of direct `HeroRoster.set_formation_slot` calls (per AC-FA-12). The screen currently bypasses the autoload, weakening the single-write-point contract. | gameplay-programmer + godot-gdscript-specialist | 1.0d | none | `formation_assignment.gd` line 349's direct `HeroRoster.set_formation_slot` call replaced with `FormationAssignment.commit()` flow; existing integration tests still pass; new test asserts `formation_reassignment_committed` fires exactly once per confirm |
| S15-M2 | **FormationAssignment Stories 6+7** — confirmation dialog screen-side wiring (AC-FA-13) + CI grep guard for AC-FA-12 forbidden-pattern (`HeroRoster.set_formation_slot` in screen code) added to ADR-0003 forbidden-patterns registry | gameplay-programmer + qa-tester | 0.5d | S15-M1 | Confirmation dialog blocks mid-run reassignment per `MID_RUN_REASSIGN_WARNING_ENABLED`; CI script fails build on direct screen→HeroRoster bypass |
| S15-M3 | **Hero Detail interactive actions** (closes S14-N1) — level-up confirm button (visible only when `hero.level < cap` AND XP ≥ threshold; tap → try_spend → set_hero_level + 1) + dismiss-hero stub (modal pattern for destructive actions; opens confirmation toast, no actual hero deletion in V1 — just emits a `hero_dismissed_requested` signal for future wiring) per `design/gdd/roster-hero-detail-screen.md` §C.6 | gameplay-programmer + ux-designer | 1.0d | M6 from Sprint 14 (DONE) | Level-up button visible per tri-state visibility rule; tap → atomic try_spend; `hero_leveled` fires; XP bar updates live. Dismiss button opens confirmation overlay; tapping confirm emits stub signal + closes modal. |
| S15-M4 | **HeroLeveling AC-15-02 calibration playtest** (Sprint 14 retro action item #2 + Sprint 13 retro carry) — human-gated manual play session. Re-run Floor 3 multiple times after first-clear to validate that "XP-per-floor-clear ties to floor_cleared_first_time" doesn't produce leveling drag for re-grind play. Capture report at `production/playtests/playtest-08-hero-leveling-calibration-2026-05-??.md` | xiaolei (human) | 0.5d | none | Playtest report committed; verdict + recommendation on OQ-15-1 calibration |

**Must Have total**: 3.0 days

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance |
|----|------|-------|-----------|--------------|------------|
| S15-S1 | **`tests/PATTERNS.md` — lifecycle asymmetry entry** (Sprint 14 retro action #3) — distill the PR #58 → PR #59 lesson: when a SceneManager API pair has asymmetric lifecycle (e.g., `request_screen` auto-calls `on_enter` but `show_modal` did not), the asymmetric half WILL be the next bug. Document the contract + reference the regression test. | godot-gdscript-specialist | 0.25d | none | Section added to PATTERNS.md with code reference + test reference |
| S15-S2 | **Level-up toast polish** (closes S14-N2) — bottom-of-screen toast on `hero_leveled` signal in Guild Hall. Reuses the `prestige_complete_toast` pattern. Reduce-motion variant disables fade. | ui-programmer | 0.5d | M3 (level-up trigger) | Toast appears on `hero_leveled`, lingers 3.0s, fades over 0.6s; `reduce_motion` uses snap-show / snap-hide |
| S15-S3 | **Recruitment Stories 6+8** — Save/Load consumer surface (AC-RC-13) — recruitment pool state survives quit/reopen + CI grep for AC-RC-14 forbidden-pattern | gameplay-programmer + qa-tester | 0.5d | none | Round-trip test in `tests/integration/recruitment/save_round_trip_test.gd`; CI guard added to ADR-0003 |
| S15-S4 | **Sprint 15 retrospective** | producer + claude-code | 0.25d | M1–M4 close | `production/retrospectives/sprint-15-retrospective-2026-05-??.md` |

**Should Have total**: 1.5 days

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Notes |
|----|------|-------|-----------|--------------|-------|
| S15-N1 | **Steam Deck verification rehearsal** — manual; 1280×800 native @ 60fps stable; touchscreen + trackpad input parity check | xiaolei (human + Steam Deck hardware) | 0.5d | hardware access | Defer if Steam Deck unavailable |
| S15-N2 | **HD-2D shader — warm-lantern overlay** (single visible polish pass per Visual Identity Anchor) — soft warm-tint vignette on Guild Hall + Dungeon Run View. Tilt-shift DoF deferred to Sprint 16+ pending shader-specialist review | godot-shader-specialist | 2.0d | none | Visible on first-launch screenshot; performance budget held |
| S15-N3 | **First-run onboarding flow UX polish** (closes S14-N3) — UX pass on the first-screen experience per Onboarding GDD #29 | ux-designer + ui-programmer | 1.0d | none | Subjective sign-off; no automated tests |

**Nice to Have total**: 3.5 days (only pulled in if Must+Should completes early)

## Carryover from Previous Sprint

**None.** Sprint 14 drained the entire S12 → S13 → S14 carry chain. Sprint 15 starts with a clean slate.

The 3 deferred Sprint 14 nice-to-haves (S14-N1 / N2 / N3) re-enter Sprint 15 as **M3 / S2 / N3** respectively — repromoted because Sprint 14's full closure freed up the budget.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| S15-M1 FormationAssignment refactor touches Orchestrator coupling | MEDIUM | MEDIUM | Existing integration tests already cover the contract; if any breaks, the refactor is wrong |
| S15-M3 dismiss-hero scope creep — player asks "where do they go?" | LOW | LOW | V1 stub emits a signal only; future Sprint can wire Hall of Retired Heroes route if desired |
| S15-M4 playtest deferred (Sprint 13 retro action #4 already carried once) | MEDIUM | LOW | If still unclosed at Sprint 15 end, surface explicitly in retro; do NOT silently carry again |
| Day-0 plan slip (action item #1 from Sprint 14 retro) | LOW | LOW | This plan IS the Day-0 deliverable. Sprint 14 retro merged this morning; Sprint 15 plan landing today honors the action item |

## Dependencies on External Factors

- Human availability for S15-M4 playtest
- Optional: Steam Deck hardware for S15-N1

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (M1–M4)
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-15.md`)
- [ ] All Logic/Integration stories have passing tests
- [ ] No S1 or S2 bugs in delivered features
- [ ] Sprint 15 retrospective written (S15-S4)
- [ ] Code reviewed and merged

## Sprint 16+ candidates

- Multi-biome unlock + biome 2 design pass (Forest Reach is the only biome)
- Telemetry events V1.0 implementation (per archived S20-N3 taxonomy)
- HD-2D tilt-shift DoF (if S15-N2 warm-lantern proves the shader pipeline)
- Audio asset sourcing follow-through (silent-MVP pivot? gated on playtest signal)
- Hero Detail dismiss-hero V2 — wire to Hall of Retired Heroes or "fired" gallery
- FormationAssignment named-presets V1.0 (true preset system, not just current refactor)
- Recruitment Stories 5+7 (cost-stability + RecruitScreen wire-up; depends on existing scope review)

## Notes

- **Solo review mode** — no PR-SPRINT producer gate per `production/review-mode.txt`.
- **Day-0 plan** — authored 2026-05-14 within hours of Sprint 14 retro merge (PR #61). Honors Sprint 14 retro action item #1.
- **Real-time cadence continues** — Sprint 13 + 14 demonstrated this works; Sprint 15 inherits the same pattern.
- **No new ADRs anticipated** — Sprint 15 is execution-focused. If FormationAssignment refactor surfaces a binding contract decision, ADR-0019 (next slot) is reserved.

> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Per the playtest-driven closure rule and solo review mode, the QA plan is skipped — the M4 playtest is the load-bearing closure gate for this sprint.
