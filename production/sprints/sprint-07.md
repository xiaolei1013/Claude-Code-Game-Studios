# Sprint 7 -- 2026-05-15 to 2026-05-29

## Sprint Goal

Complete boss abilities, launch Room Content (E1) to enable full campaign gameplay loop, close out remaining Archer + Combo stories.

## Capacity

- Total days: 10 (2-week sprint, solo developer)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days
- Sprint 6 velocity: 3 Must Have stories / 8.0 est. days, delivered in 1 session

## Tasks

### Must Have (Critical Path) -- 8.0 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E3-007 | Ability Template -- Rain of Fire | E3 Boss | 2.0 | E3-001 (done) | RainOfFireAbility MonoBehaviour. AoE circles, telegraph, damage, dodge window. Unit tests. |
| E3-008 | Boss Prefab Configuration | E3 Boss | 2.0 | E3-006 (done), E3-007 | 5 boss prefabs with phase configs, ability assignments, stat modifiers wired in Inspector. |
| E1-001 | RoomConfig ScriptableObject | E1 Room | 2.0 | E2 (done), E3 (mostly done) | RoomConfig SO with wave lists, trap placements, boss assignment, archetype tag. RoomArchetype enum. |
| E1-002 | Campaign Wave Provider | E1 Room | 2.0 | E1-001, ADR-0002 (done) | CampaignWaveProvider reads RoomConfig, applies IDifficultyProvider multipliers. SpawnManager integration. |

**Critical path**: E3-007 (2d) -> E3-008 (2d) serial. E1-001 (2d) -> E1-002 (2d) serial. Both chains run in parallel. Total: 4d per chain.

### Should Have (Start if Capacity Allows) -- 5.0 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E1-003 | Rooms 1-5 Configuration | E1 Room | 2.0 | E1-001, E1-002 | 5 RoomConfig assets for rooms 1-5 with Normal-difficulty wave data. |
| N1-008 | Archer VFX & Animation | N1 Archer | 1.0 | N1-001-006 (done) | Visual polish for Archer skills and character animations. |
| E4-009 | Combo System Tests | E4 Combo | 2.0 | E4-005, E4-007 (done) | Full integration suite across run boundaries. |

### Nice to Have (Sprint 8 candidates) -- 6.0 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E1-004 | Rooms 6-10 Configuration | E1 Room | 2.0 | E1-001, E1-002 | 5 RoomConfig assets for rooms 6-10 (3-phase bosses). |
| E3-009 | Boss Phase VFX | E3 Boss | 2.0 | E3-002 (done) | Transition VFX for phase changes. |
| E3-011 | Boss System Tests | E3 Boss | 2.0 | E3-007, E3-008 | Integration test suite for boss phases. |

## Carryover from Sprint 6

| Task | Reason | New Estimate |
|------|--------|-------------|
| E3-007 Rain of Fire | Sprint 6 Should Have, not started | 2.0 days (Must Have in Sprint 7) |
| E3-008 Boss Prefab Config | Sprint 6 Nice to Have, blocked by E3-007 | 2.0 days (Must Have in Sprint 7) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ADR-0006 (RoomConfig) may need acceptance | Medium | High | Review ADR-0006 status before E1-001. If still Proposed, accept it first. |
| Boss prefab authoring (E3-008) is Inspector-heavy | Low | Medium | Use Unity MCP for ScriptableObject creation where possible. |
| Room Content depends on boss system completion | Low | Low | E3-007 is parallel with E1-001; E3-008 can overlap with E1-002. |

## Dependencies on External Factors

- None -- all dependencies are internal stories already Complete or in this sprint.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-07.md`)
- [ ] All Logic stories have passing unit tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
