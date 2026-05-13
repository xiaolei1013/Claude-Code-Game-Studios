# Sprint 16 — 2026-05-28 to 2026-06-10 (10 working days)

> **Status: Day-0 plan authored 2026-05-14** during the Sprint 15 close-out push. Honors Sprint 14 retro action item #1 (plan Sprint 16 within Day 0 of its window) — Sprint 16 nominal start follows Sprint 15 end (2026-05-27). Solo review mode.

## Sprint Goal

**Convert the Sprint 15 design preview + carryover into shipped Vertical Slice tier features, gated by playtest validation of HeroLeveling.** Sprint 15 ended with two carries: the HeroLeveling AC-15-02 playtest (M4) and the Sprint 15 retro (S4). Sprint 16 absorbs both, then converts the warm-lantern shader preview (PR #73) into a tuned production asset and authors the FormationAssignment named-presets GDD as the design-first input to a future implementation sprint.

**Definition of Sprint 16 success**: (a) HeroLeveling AC-15-02 playtest report committed; (b) Sprint 15 retro written; (c) FormationAssignment named-presets GDD authored to APPROVED or CONCERNS-only; (d) warm-lantern shader either confirmed in production or formally reverted per ADR-0017; (e) at least one Sprint 15+ candidate from the backlog converted from "candidate" to "shipped".

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days
- Available: **8.0 days**

**Calibration note**: Sprint 15 hit ~17 PRs (#58–#73 + #65–#67 bundled work) in 5 calendar days — well above the 9-PR Sprint 14 baseline. Productive but the curve is flattening (last 4 PRs were hygiene + preview). Sprint 16 should aim for 6-8 PRs of substantive work, not raw PR count. The remaining backlog is dominated by design-first items (named-presets GDD, biome 2) which compound differently than pure code.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance |
|----|------|-------|-----------|--------------|------------|
| S16-M1 | **HeroLeveling AC-15-02 calibration playtest** (carryover from S15-M4 + S13-M3) — human-gated. Re-run Floor 3 multiple times after first-clear to validate "XP-per-floor-clear ties to floor_cleared_first_time" doesn't produce leveling drag for re-grind play. | xiaolei (human) | 0.5d | none | `production/playtests/playtest-08-hero-leveling-calibration-2026-05-??.md` committed; verdict on OQ-15-1 |
| S16-M2 | **Sprint 15 retrospective** (carryover from S15-S4) — capture the productivity-curve-flattening insight + the ADR-0017 deviation pattern (shipping previews against deferral decisions). | producer + claude-code | 0.25d | M1 | `production/retrospectives/sprint-15-retrospective-2026-05-??.md` |
| S16-M3 | **FormationAssignment named-presets V1.0 GDD** — author per the standard 8-section + I+J template. Defines the save namespace expansion, UI affordances (preset name field, save/load/delete buttons), MVP scope vs V1.0+ deferrals, and the formation_assignment screen integration story. Unblocks future implementation in Sprint 17+. | game-designer + claude-code | 0.75d | none | `design/gdd/formation-presets.md` exists with 8+I+J sections; cross-referenced from `formation-assignment-system.md` §C.6 |
| S16-M4 | **ADR-0017 reconciliation on warm-lantern preview** (post-PR #73) — either: (a) amend ADR-0017 to reflect that warm-lantern shipped early as a tuned production asset, OR (b) revert PR #73's Guild Hall application keeping the shader+tests as deferred infrastructure. Decision belongs to the user; this story tracks the closure. | claude-code + user | 0.25d | PR #73 merged | ADR-0017 amendment OR revert PR committed |

**Must Have total**: 1.75 days

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance |
|----|------|-------|-----------|--------------|------------|
| S16-S1 | **Recruitment Stories 5+7 audit closure** — audit found these were already implemented in Sprint 11-12 work but never formally closed against `recruitment-system.md` §J. Walk the AC list, mark each "shipped or N/A", commit the trace. | qa-tester + claude-code | 0.5d | none | §J each story marked DONE or N/A with PR reference |
| S16-S2 | **Multi-biome biome 2 design pass — GDD authoring** — second biome content (name, theme, enemy roster, narrative). MVP only ships Forest Reach; biome 2 is the first Vertical Slice tier content addition. | game-designer + world-builder + claude-code | 1.5d | none | `design/gdd/biome-dungeon-database.md` §H updated with biome 2 entries; `assets/data/biome/` resource added (DRAFT — implementation Sprint 17+) |
| S16-S3 | **Sprint 16 retrospective** | producer + claude-code | 0.25d | M1-M4 | `production/retrospectives/sprint-16-retrospective-2026-06-??.md` |

**Should Have total**: 2.25 days

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Notes |
|----|------|-------|-----------|--------------|-------|
| S16-N1 | **Hero Detail dismiss-hero V2 design call** — formally decide whether destructive actions live in Hero Detail or get their own screen surface. Pre-req for actual implementation in Sprint 17+. | game-designer + user | 0.25d | none | Decision committed (in-line ADR amendment or fresh ADR-0019) |
| S16-N2 | **HD-2D tilt-shift DoF shader** — second visible polish pass following the warm-lantern preview pattern. Implements the OQ-26-1 deferred half of the HD-2D pipeline. | godot-shader-specialist | 2.0d | M4 ADR-0017 reconciliation | `assets/shaders/tilt_shift_dof.gdshader` + Guild Hall + Dungeon Run View applications |
| S16-N3 | **Steam Deck verification rehearsal** (carryover from S15-N1) | xiaolei (human + Steam Deck hardware) | 0.5d | hardware | `production/playtests/playtest-09-steam-deck-rehearsal-2026-??.md` |
| S16-N4 | **First-run onboarding flow UX polish** (carryover from S15-N3) | ux-designer + ui-programmer | 1.0d | playtest signal | Subjective sign-off |
| S16-N5 | **Audio asset sourcing follow-through** — re-evaluate ADR-0016 silent-MVP pivot triggers after Sprint 15 playtest signal. If pivot warranted, kick off sourcing; otherwise re-affirm silent-MVP. | audio-director + user | 0.5d | M1 playtest signal | Decision committed in ADR-0016 amendment |

**Nice to Have total**: 4.25 days (only pulled in if Must+Should completes early)

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|--------------|
| S15-M4 HeroLeveling playtest | Human-gated; never opened a build session in the Sprint 15 window | → S16-M1 (0.5d) |
| S15-S4 Sprint 15 retro | Blocked on M4 | → S16-M2 (0.25d) |
| S15-N1 Steam Deck rehearsal | Hardware-gated; deferred from N tier | → S16-N3 (0.5d) |
| S15-N3 onboarding UX polish | No playtest signal demanding it | → S16-N4 (1.0d) |

**Net carryover**: ~2.25 days of nominally-Sprint-15 work absorbs into Sprint 16. Acceptable per the cadence pattern (Sprint 14 also absorbed 1.5d of S13 carry).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| HeroLeveling playtest deferred a 3rd time (Sprint 13 → 14 → 15 → 16 carry chain) | MEDIUM | LOW (test still informative whenever it runs) | Sprint 16 retro flags it explicitly per Sprint 14 retro pattern; do not silently carry again to Sprint 17 |
| ADR-0017 reconciliation surfaces ADR process gap (when does an autonomous PR's deviation warrant formal ADR amendment?) | MEDIUM | LOW | Either path (amend OR revert) closes cleanly; doesn't block other work |
| named-presets GDD design pass surfaces 5+ BLOCKING revisions (per the "first-pass GDDs always have ≥5 BLOCKING" pattern from Sprint 13-14 history) | HIGH | MEDIUM | Schedule M3 in the first half of the sprint; absorbs the revision cost |
| biome 2 content GDD scope creep (worldbuilding rabbit hole) | MEDIUM | MEDIUM | Hard-cap S16-S2 at 1.5d; defer art-direction-specific work to the implementation sprint |

## Dependencies on External Factors

- Human availability for S16-M1 playtest + S16-M4 ADR decision
- Optional: Steam Deck hardware for S16-N3
- Designer review cycles for S16-M3 (named-presets) + S16-S2 (biome 2)

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (M1–M4)
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-16.md`) OR explicit skip note
- [ ] All Logic/Integration stories have passing tests
- [ ] No S1 or S2 bugs in delivered features
- [ ] Sprint 16 retrospective written (S16-S3)
- [ ] Code reviewed and merged

## Sprint 17+ candidates

- FormationAssignment named-presets V1.0 implementation (5-story sequence per S16-M3's GDD)
- Biome 2 implementation (after S16-S2 design pass)
- HD-2D tilt-shift DoF (if S16-N2 ships in Sprint 16, this becomes "polish + tune"; otherwise it's "ship")
- Hero Detail dismiss-hero V2 implementation (after S16-N1 design call)
- Telemetry V1.0 dashboarding work (server-side; deferred until cert + privacy policy land)
- Audio asset sourcing implementation (if S16-N5 decision triggers pivot)
- More content: biomes 3, 4, 5 (post biome-2 proof point)

## Notes

- **Solo review mode** — no PR-SPRINT producer gate.
- **Day-0 plan** — authored 2026-05-14 even though Sprint 16's nominal window starts 2026-05-28. Honors Sprint 14 retro action #1 + the "plan Sprint N within Day 0 of its branch existence" pattern.
- **Cadence inheritance**: Sprint 13 → 14 → 15 all followed real-time-with-zero-or-minor-carryover. Sprint 16 inherits this. Pre-emption ratio: 0%.
- **ADR-0017 deviation**: PR #73's warm-lantern shader ships AGAINST the ADR's Vertical Slice deferral. S16-M4 closes that — either amend the ADR or revert the application.

> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Per the solo + playtest-driven closure pattern established in Sprints 14-15, the M1 playtest is the load-bearing closure gate.
