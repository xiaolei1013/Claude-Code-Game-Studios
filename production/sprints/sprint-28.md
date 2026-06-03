# Sprint 28 — 2026-06-03 to 2026-06-16

> Solo review mode. Fifteenth consecutive same-day-compressed sprint (S14 → S28).

## Sprint Goal

Drain the compounded playtest backlog (3 sessions over the cap-1 guardrail), lock the visual theme direction, and ship per-floor matchup hints contingent on playtest verdict.

## Pre-Plan Disposition

| Item | Status | Action |
|------|--------|--------|
| Playtest 16/17/18 | 3 sessions PENDING (over cap-1 guardrail) | S28-M1 — must land before any new content |
| Sprint 25/26/27 retros | DRAFT (verdicts pending) | Close once S28-M1 grades land |
| Theme skin | USER-GATED (dark-mock vs light-parchment) | S28-M3 |
| Prestige model | GDD #31 EXISTS (460-line FIRST-PASS DRAFT; model locked: per-hero retire → global multiplier; pending `/design-review`). User-gated = ratify vs pivot to mock's pure-global | S28-S2 (after M1) |
| VERSION | Stale at 0.0.0.74 (PRs #170–#195 untracked) | S28-M2 |
| S28 retro candidates already shipped | DONE — POOL_SIZE=4 (`recruitment.gd:74`); hero milestone toasts (PR #195) | No action needed |

## Capacity

- Total days: 14
- Buffer (20%): 2.8 days reserved for unplanned work
- Available: ~11 days

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S28-M1 | Run unified playtest 16/17/18 session (human-executed) | Human (tester) | 0.5 | None | All 3 playtest docs graded; verdict documented; S25/S26/S27 retros marked COMPLETE |
| S28-M2 | VERSION + CHANGELOG catch-up (PRs #170–#195) | chore | 0.5 | None | VERSION reflects actual PR count; CHANGELOG updated; project.godot aligned |
| S28-M3 | Theme skin ADR-0020: dark-mock vs light-parchment | User decision + doc | 0.5 | None | ADR-0020 written; visual direction locked for the real-theme pass |

### Should Have _(gated on S28-M1 PASS verdict)_

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S28-S1 | Per-floor matchup hint on floor picker | gameplay-programmer | 1.5 | S28-M1 PASS | Floor picker shows "Recommended: [Class]" per floor from enemy_list archetypes; **reuses** the existing archetype→class map in `formation_assignment.gd` (~L683, currently biome-level) rather than reimplementing; locale-keyed; unit tests green |
| S28-S2 | Prestige GDD #31 `/design-review` → APPROVED (or pivot) | systems-designer | 0.5 | S28-M1 PASS | Existing `design/gdd/prestige-system.md` (FIRST-PASS DRAFT) run through `/design-review`; its locked per-hero-retire → global-multiplier model is ratified OR a pivot to the mock's pure-global model is recorded; no implementation |

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S28-N1 | VFX: aura/bubble/batwing placeholder → real particle textures | technical-artist | 1.0 | None | 3 VFX effects use non-placeholder textures; visible in combat runs |
| S28-N2 | Offline-unlock surfacing at return-to-app | gameplay-programmer | 1.0 | None | Return-to-app screen shows unlock notice when offline run cleared a new floor |

## Risks

| Risk | Probability | Impact |
|------|------------|--------|
| Playtest reveals specific gap → S1/S2 deferred to address gap | MEDIUM | HIGH |
| Theme ADR opens visual rework > 1 day | LOW | MEDIUM |
| Per-floor hint requires enemy archetype API not currently exposed | LOW | MEDIUM |
| VERSION catch-up conflicts with project.godot versioning — follow the PR #169 pattern | LOW | LOW |

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] Playtest backlog drained to 0 (all 3 sessions graded)
- [ ] Sprint 25/26/27 retros marked CLOSED
- [ ] Theme direction locked in ADR-0020
- [ ] VERSION aligned to actual PR count
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] **Content PRs (S1/S2/N1/N2) only landed after S28-M1 verdict = PASS**

## Sprint 28 Process Rules (carried + updated from S27)

1. Per-task PR with `base=main`. No stacked PRs.
2. Grep-first GDD-existence check before any "author GDD X" story.
3. Player-visible surface check at mid-sprint.
4. Parse-check before merging test-helper changes.
5. Bundle Day-0 plan into first content PR.
6. **NEW**: No new content PRs until S28-M1 playtest verdict lands.
7. Playtest backlog cap = 1 sprint — this sprint drains to zero.

## Notes

Channel-light economy (lantern click) has no design yet — deferred. Remaining wireframe screens (Recruit restyle, Hero Detail full, Settings/Pause, Prestige modal) are deferred post-theme-decision (S28-M3).

**QA Plan**: `production/qa/qa-plan-sprint-28.md` — generate before S28-S1 implementation begins.
