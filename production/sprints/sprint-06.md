# Sprint 6 -- 2026-05-01 to 2026-05-15

## Sprint Goal

Complete the combo system (all 18 effects + database wired), advance boss phases (2 ability templates), unblock Room Content (E1) for Sprint 7.

## Capacity

- Total days: 10 (2-week sprint, solo developer)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days
- Sprint 5 velocity: 4 Must Have stories / 6.5 est. days, delivered in 1 session

## Tasks

### Must Have (Critical Path) -- 8.0 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E4-005 | Universal Combo Effects (7) | E4 Combo | 4.0 | E4-001, E4-002 (done) | 7 concrete Universal ComboEffect SOs + unit tests. Executioner boss-immune (F-007). ElementalStorm 5-hit cap (G-009). |
| E3-006 | Ability Template -- Shield Phase | E3 Boss | 2.0 | E3-001 (done) | ShieldPhaseAbility MonoBehaviour. 4 base hits to break, scales by phase. Status effects pass through shield. Unit tests. |
| E4-007 | ComboDatabase Population | E4 Combo | 2.0 | E4-003, E4-004, E4-005 | All 18 ComboDefinition entries in ComboDatabase.asset with correct skill refs, categories, trigger conditions, and effect asset refs. |

**Critical path**: E4-005 (4d) → E4-007 (2d) = 6d serial. E3-006 (2d) runs parallel. Total: 6d + 2d buffer.

### Should Have (Start if Capacity Allows) -- 3.0 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E3-007 | Ability Template -- Rain of Fire | E3 Boss | 2.0 | E3-001 (done) | RainOfFireAbility MonoBehaviour. AoE damage zones, telegraph, dodge window. Unit tests. |
| PT-001 | New-player experience playtest | Quality | 1.0 | -- | 1 session with new player; 2-min comprehension check; report at production/playtests/. |

### Nice to Have (Defer to Sprint 7) -- 6.0 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E3-008 | Boss Prefab Configuration | E3 Boss | 2.0 | E3-006, E3-007 | Production boss prefabs with phase configs wired. |
| E4-009 | Combo System Tests | E4 Combo | 2.0 | E4-005, E4-007 | Full integration suite across run boundaries. |
| E3-009 | Boss Phase VFX | E3 Boss | 2.0 | E3-002 (done) | Transition VFX for phase changes. |

## Carryover from Sprint 5

| Task | Reason | New Estimate |
|------|--------|-------------|
| E4-005 Universal Combo Effects | Sprint 5 Should Have, not started | 4.0 days (Must Have in Sprint 6) |
| E3-006 Shield Phase | Sprint 5 Should Have, not started | 2.0 days (Must Have in Sprint 6) |
| PT-001 New-player playtest | Sprint 5 Should Have, not started | 1.0 day (Should Have in Sprint 6) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| E4-005 scope (7 effects, 2 critical) | Medium | High | Executioner + ElementalStorm are highest-risk. Implement those first. |
| E4-007 blocked if E4-005 slips | Medium | Medium | E4-007 is data wiring, can overlap with E4-005 tail if Mage+Archer effects exist. |
| Boss ability API mismatch (E3-006/007) | Low | Medium | E3-001 through E3-005 established the pattern. Shield/Rain follow same template. |

## Dependencies on External Factors

- None -- all dependencies are internal stories already Complete.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-06.md`)
- [ ] All Logic stories have passing unit tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
