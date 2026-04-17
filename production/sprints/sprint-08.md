# Sprint 8 -- 2026-05-29 to 2026-06-12

## Sprint Goal

Launch Endless Mode (N2) as the second major content system, complete remaining Room Content, close out all minor epic tails.

## Capacity

- Total days: 10 (2-week sprint, solo developer)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days
- Sprint 7 velocity: 7 stories / ~13 est. days, delivered in 1 session

## Tasks

### Must Have (Critical Path) -- 8.0 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| N2-001 | Endless Difficulty Provider | N2 Endless | 1.0 | ADR-0001 (done) | EndlessDifficultyProvider implements IDifficultyProvider with wave-based scaling formulas. |
| N2-002 | Endless Wave Provider | N2 Endless | 1.5 | ADR-0002 (done), N2-001 | EndlessWaveProvider implements IWaveProvider with procedural wave generation. |
| N2-003 | Endless Session Controller | N2 Endless | 2.0 | N2-001, N2-002 | EndlessSessionController coordinates wave loop, draft timing, boss cycling, score tracking. |
| N2-004 | Boss Wave Cycling | N2 Endless | 1.0 | N2-003, E3 Boss (done) | Boss every 10 waves, cycle A-E (2-phase only), restart at wave 60+. |
| N2-005 | Endless Arena Setup | N2 Endless | 0.5 | N2-003 | Single 30x30 arena, Arena archetype, no traps, 6 spawn points. |
| N2-007 | Endless Draft Integration | N2 Endless | 1.0 | N2-003 | Skill draft every 5 waves via DraftRunController.ShowDraft(); class filtering applies. |
| N2-006 | Score and Leaderboard | N2 Endless | 1.0 | N2-003 | Score = waves cleared; per-class leaderboard persisted via LevelStats. |

**Critical path**: N2-001 (1d) -> N2-002 (1.5d) -> N2-003 (2d) -> N2-004/005/006/007 (parallel, 1d each). Total: ~5.5d serial + 1d parallel = ~6.5d.

### Should Have (Start if Capacity Allows) -- 5.0 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| N2-008 | Endless Mode Tests | N2 Endless | 2.0 | N2-001 through N2-007 | Integration test suite for Endless Mode. |
| E1-004 | Rooms 6-10 Configuration | E1 Room | 2.0 | E1-001, E1-002 (done) | 5 RoomConfig assets for rooms 6-10 (3-phase bosses). |
| N1-010 | Poison State Stack Extension | N1 Archer | 1.0 | N1-001 (done) | Poison state stacking behavior for Archer skills. |

### Nice to Have (Sprint 9 candidates) -- 6.0 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E3-009 | Boss Phase VFX | E3 Boss | 2.0 | E3-002 (done) | Transition VFX for phase changes. |
| E3-011 | Boss System Tests | E3 Boss | 2.0 | E3-007, E3-008 (done) | Integration test suite for boss phases. |
| E1-005 | Room Layout & Spawn Points | E1 Room | 1.0 | E1-001 (done) | Spawn point placement per room. |
| E1-006 | Room Content Tests | E1 Room | 1.0 | E1-002 (done) | Integration tests for room content pipeline. |

## Carryover from Sprint 7

None -- all 7 Sprint 7 stories completed.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ADR-0007 (Endless Mode) may need acceptance | Medium | High | Check ADR-0007 status before N2-001. Promote if still Proposed. |
| EndlessSessionController is the most complex new system | Medium | Medium | Implement N2-001 and N2-002 first to validate the provider pattern before the controller. |
| 7 Must Have stories is ambitious | Low | Medium | N2-004/005/006/007 are small (0.5-1d each) and independent. Serial chain is only 4.5d. |

## Dependencies on External Factors

- None -- all dependencies are internal stories already Complete.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-08.md`)
- [ ] All Logic stories have passing unit tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
