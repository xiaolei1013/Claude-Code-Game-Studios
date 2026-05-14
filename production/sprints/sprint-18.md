# Sprint 18 — 2026-05-14 to 2026-05-27 (10 working days)

> **Status: Day-0 plan authored 2026-05-14**, same-day close of Sprint 17. Solo review
> mode. Continues the real-time cadence established Sprint 14→15→16→17.

## Sprint Goal

**Ship Class Synergy V1.0 — the first cross-class team bonus mechanic — and validate
it feels rewarding without trivializing the cozy register.** Sprint 17's playtest said
"it works great" without asking for more content, pointing toward variety. Class synergy
is the highest-scored Sprint 17 N-tier candidate: the GDD already exists, the multiplier
values are scoped (≤+25%), and the formation screen already has the slot structure the
preview signal needs.

**Definition of Sprint 18 success**: (a) GDD #32 reaches APPROVED via design-review;
(b) `detect_active_synergy()` is implemented, wired into the orchestrator's gold formula,
and has full unit + integration test coverage; (c) Formation Assignment screen shows live
synergy preview as heroes are assigned; (d) Sprint 18 playtest validates the synergy bonus
feels rewarding and not exploitable at the cozy register; (e) onboarding carry resolved.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days
- Available: **8.0 days**

**Calibration note**: Sprint 18's class synergy implementation is the first net-new
mechanic since the Sprint 9 pre-emptive wave. Design-review gate (M1) and ADR authoring
(S18-S1, embedded in M2) add ~0.5d of design overhead not present in pure-code sprints.
Total Must Have scope: 2.5d — well inside the 8.0d budget, leaving room for N-tier polish
if synergy ships cleanly.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance |
|----|------|-------|-----------|--------------|------------|
| S18-M1 | **Class Synergy GDD #32 design-review → APPROVED** — run `/design-review design/gdd/class-synergy-system.md`. GDD is first-pass DRAFT (authored Sprint 19 pre-emptive); implementation cannot begin until APPROVED verdict. | user + claude-code | 0.25d | none | GDD #32 status changes from DRAFT → APPROVED; no BLOCKING revisions remain |
| S18-M2 | **Class Synergy V1.0 backend** — `ClassSynergySystem` autoload with `detect_active_synergy(formation_class_ids: Array[String]) -> Dictionary` returning `{synergy_name: String, bonus_pct: float, tier: String}`. Wire into `DungeonRunOrchestrator._process_kill_events()` gold formula as a multiplier layer. New ADR-0018 documenting the multiplier insertion point in the combat formula. | godot-gdscript-specialist | 1.0d | M1 | `detect_active_synergy` returns correct tier + pct for mono/dual/triple; orchestrator applies bonus at resolution; unit tests cover all 3 tiers + no-synergy path; integration test confirms gold output scales correctly; ADR-0018 authored |
| S18-M3 | **Class Synergy live preview in Formation Assignment** — emit `formation_synergy_changed(bonus_pct: float)` signal from `FormationAssignment` on each `set_formation_slot()` call. Formation Assignment screen renders a "Synergy: +X%" label (empty string when no synergy). | godot-gdscript-specialist | 0.5d | M2 | Signal fires on every slot change with correct pct; screen renders label; reduce-motion path suppresses animation if any; regression tests |
| S18-M4 | **Sprint 18 playtest — class synergy validation** — dispatch a deliberate triple-class formation to verify the +25% bonus is perceptible in gold output; run a mixed formation to confirm no-synergy is silent; validate cozy register holds (bonus feels rewarding, not decisive). | xiaolei (human) | 0.5d | M3 | `production/playtests/playtest-10-class-synergy-validation-2026-05-??.md` committed with verdict on "rewarding but not trivializing" question |
| S18-M5 | **Sprint 18 retrospective** | producer + claude-code | 0.25d | M4 | `production/retrospectives/sprint-18-retrospective-2026-05-??.md` |

**Must Have total**: 2.5 days

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance |
|----|------|-------|-----------|--------------|------------|
| S18-S1 | **Onboarding carry — final disposition** (4-sprint carry: S15-N3 → S16-N4 → S17-N2 → S18-S1). No playtest session has produced a signal demanding onboarding polish. **Recommendation: retire** — append a retirement note to `design/gdd/onboarding-first-session.md` §J citing "no playtest demand after 4 sprints." | game-designer + claude-code | 0.25d | none | Retirement note in onboarding GDD §J; S18-S1 marked done. OR: if user actively decides to implement, scope to one concrete UX improvement and add as S18-S1 impl story instead. |
| S18-S2 | **ADR-amendment test-coverage audit pattern in PATTERNS.md §15** (Sprint 17 retro action #2) — when an ADR widens scope (e.g., single-biome → multi-biome), the associated test suite must be re-audited against the new scope before ship. Document: detection heuristic, example from PR #90 ADR-0002 amendment, test-contract template. | claude-code | 0.25d | none | §15 entry committed to `tests/PATTERNS.md`; follows §13 lifecycle-asymmetry and §14 PanelContainer-CI-guard precedent |

**Should Have total**: 0.5 days

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Notes |
|----|------|-------|-----------|--------------|-------|
| S18-N1 | **HD-2D tilt-shift DoF shader** (3-sprint carry: S16-N2 → S17-N4 → S18-N1) — second visible polish pass following warm-lantern. `assets/shaders/tilt_shift_dof.gdshader` + Guild Hall + Dungeon Run View applications. | godot-shader-specialist | 2.0d | M4 signal | Pull in only if M4 playtest confirms visual polish is the right next thing; defer if synergy playtest surfaces mechanic refinement work |

**Nice to Have total**: 2.0 days (only if M+S completes with playtest headroom)

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|--------------|
| S17-N2 Onboarding UX polish | 4-sprint carry with no playtest demand signal | → S18-S1 final disposition (retire) |
| S17-N4 HD-2D tilt-shift DoF shader | 3-sprint carry, visual polish pass | → S18-N1 (pull in if M4 playtest permits) |
| S17-N3 HeroLeveling AC-15-02 re-run | Sprint 17 retro action #4: carry chain closed — M6 playtest implicitly re-validated; no dedicated re-run needed | ❌ RETIRED — not carried |

**Net carryover**: 1 item to resolve (onboarding disposition, 0.25d), 1 N-tier item to attempt (DoF shader, 2.0d). HeroLeveling carry chain formally closed per retro action #4.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Class Synergy GDD #32 design-review surfaces BLOCKING revisions (per Sprint 13–14 "first-pass GDDs always have ≥5 BLOCKING" pattern) | MEDIUM | MEDIUM | Schedule M1 in day 1; absorb revision cost before M2 implementation begins; if >3 BLOCKINGs, scope to mono-class synergy only for Sprint 18 |
| Synergy bonus feels decisive (breaks cozy register at +25%) | LOW | HIGH | GDD OQ-32-6 hard-caps at +25%; M4 playtest explicitly asks the "rewarding but not trivializing" question; Sprint 19 can tune if needed |
| ADR-0018 insertion point conflicts with existing orchestrator bonus layers | MEDIUM | MEDIUM | Orchestrator has 3 existing multiplier layers (LOSING_RUN_LOOT_FACTOR, Economy gate, matchup bonus); synergy must compose cleanly; investigate day 1 of M2 before full implementation |
| `detect_active_synergy()` performance regression in offline batch | LOW | LOW | Called once per dispatch (not per-tick); 3-class MVP roster is O(1); no offline-batch concern at current scale. Register as ADR-0018 footnote for V1.5 if roster grows to 10+ classes |

## Dependencies on External Factors

- Human availability for S18-M1 design-review sign-off + S18-M4 playtest
- GDD #32 APPROVED verdict is a hard gate before M2 implementation begins

## Definition of Done for this Sprint

- [ ] GDD #32 APPROVED (no BLOCKING revisions remaining)
- [ ] `detect_active_synergy()` implemented + wired to orchestrator gold formula
- [ ] ADR-0018 authored (class synergy multiplier insertion point)
- [ ] Formation Assignment screen shows live synergy preview
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Sprint 18 playtest committed with verdict on cozy-register question
- [ ] Sprint 18 retrospective written
- [ ] Onboarding carry disposed (retired or implemented)
- [ ] ADR-amendment test-coverage pattern documented in PATTERNS.md §15
- [ ] No S1 or S2 bugs in delivered features
- [ ] Code reviewed and merged

## Sprint 19+ candidates

- FormationPresets V1.0 full sequence (5 stories per `design/gdd/formation-presets.md`)
- HD-2D tilt-shift DoF shader (if not pulled into S18-N1)
- Class synergy V1.5 (unlock cadence, additional synergy types) — post-M4 playtest signal
- Audio asset sourcing (ADR-0016 silent-MVP pivot triggers)
- Biome 7+ (if playtest signals content hunger — unlikely given "works great" verdict)

## Notes

- **Solo review mode** — no PR-SPRINT producer gate.
- **Day-0 plan** — authored 2026-05-14, same day as Sprint 17 close. Honors Sprint 14 retro action #1 ("plan Sprint N within Day 0").
- **Cadence inheritance**: Sprint 14→15→16→17→18 all Day-0 planned. Same-day-compressed-then-plan-next is the established rhythm.
- **Player-visible weight**: M3 (Formation Assignment live preview) + M4 (playtest) are both player-facing. Class synergy is a mechanic players will feel on their first triple-class dispatch — the "aha" moment when their team comp pays off.
- **ADR-0018 note**: this sprint authors the 18th ADR. Architecture is accumulating; `/architecture-review` before Sprint 20 would be healthy to check coverage gaps.

> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Per the solo + playtest-driven closure pattern established in Sprints 14–17, the M4 playtest is the load-bearing closure gate.
