# Sprint 3 -- 2026-04-14 to 2026-04-28

## Sprint Goal

Complete the Archer character (exclusive skills) and deliver all four Boss Phase abilities, unblocking boss prefab configuration and content authoring in Sprint 4.

## Capacity

- Total days: 10 (2-week sprint, solo developer)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days
- Owner: Xiaolei (all tasks)
- Sprint 2 velocity: 10 stories / 18.5 est. days completed (high throughput with AI-assisted dev)

## Tasks

### Must Have (Critical Path) -- 9 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| N1-006 | Archer Exclusive Skills (7) | N1 Archer | 4.0 | N1-001 (done) | 7 UpgradableSkill SOs created: PiercingArrow, Multishot, PoisonArrow, Afterimage, CounterRoll, Quickdraw, EagleEye. Each has compatibleUpgradeTypes referencing ArrowShotSkill or DodgeRollSkill. F-010 compliant, R-023 compliant. |
| E3-004 | Ability Template -- Ground Slam | E3 Boss | 2.0 | E3-001 (done) | GroundSlamAbility MonoBehaviour with telegraph, radial damage zone, 0.8s default telegraph. Unit tests pass. R-025 compliant. |
| E3-005 | Ability Template -- Charge | E3 Boss | 2.0 | E3-001 (done) | ChargeAbility MonoBehaviour with telegraph, line dash, wall collision. Unit tests pass. R-025 compliant. |
| E3-010 | Boss Kill Tracking Fix | E3 Boss | 1.0 | E3-001 (done) | DraftRunController subscribes to OnBossDefeated event, no hardcoded bossKilled=true. Unit tests verify correct tracking. R-027, F-007 compliant. |

**Must Have Total: 9 days (1 day over 8-day capacity -- acceptable with Sprint 2 velocity of 18.5d delivered)**

### Should Have (Start if Capacity Allows) -- 4 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E3-006 | Ability Template -- Shield Phase | E3 Boss | 2.0 | E3-001 (done) | ShieldPhaseAbility with hit counter, status effects pass through shield, phase-scaling formula. Unit tests pass. R-025 compliant. |
| E3-007 | Ability Template -- Rain of Fire | E3 Boss | 2.0 | E3-001 (done) | RainOfFireAbility with random AoE circles, telegraph, optional burn status. Reuses trap damage pattern. Unit tests pass. R-025 compliant. |

### Nice to Have (Defer to Sprint 4) -- 10 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| N1-008 | Archer VFX & Animation | N1 Archer | 3.0 | N1-003 (done), N1-004 (done) | Arrow projectile prefab, dodge roll VFX, Archer character visual placeholder. Production-quality visuals replacing programmer art. |
| E3-008 | Boss Prefab Configuration | E3 Boss | 3.0 | E3-004, E3-005, E3-006, E3-007 | 5 bosses x 2 variants = 10 prefabs. Phase data, ability templates, stat modifiers configured per GDD phase table. G-012 compliant. |
| E3-009 | Boss Phase VFX | E3 Boss | 2.0 | E3-002 (done) | Stagger animation, phase transition VFX (color-coded per phase), energy burst particles. Under 2ms render budget. |
| E3-011 | Boss System Tests | E3 Boss | 2.0 | E3-001 through E3-010 | Comprehensive unit + integration tests covering all Boss Phase System stories. Quality gate for E3 epic. |

## Carryover from Sprint 2

None -- all 10 stories completed. Sprint 2 QA: APPROVED (73 tests, 0 bugs).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| N1-006 scope too large (7 skills in one story) | MEDIUM | MEDIUM | Skills follow identical pattern (UpgradableSkill SO + compatibleUpgradeTypes). Batch implementation viable. Split into 2 stories if >4 days. |
| Boss ability templates need BehaviourTree integration not yet built | LOW | HIGH | Stories 004-007 are standalone MonoBehaviours. BT integration happens in E3-008 (prefab config). |
| E3-010 boss kill tracking may surface hidden DraftRunController coupling | MEDIUM | LOW | E3-010 is scoped to event subscription only. If coupling is wider, create follow-up story. |
| N1-006 activates N1-007 draft filtering and N1-009 deferred tests | LOW | LOW | Re-verify N1-007 and N1-009 deferred criteria after N1-006 ships. |

## Dependencies on External Factors

- ADR-0004 must be Accepted before E3-004 through E3-011 can proceed (currently Proposed -- verify before sprint start)
- ADR-0005 remains Accepted (confirmed Sprint 2)
- N1-006 completion activates N1-007 draft pool filtering (already structurally complete from Sprint 2)
- N1-006 completion unblocks N1-009 deferred exclusive skill tests

## Sprint Schedule (Recommended Execution Order)

```
Day 1-4:  N1-006 (Archer Exclusive Skills) -- largest story, start first
Day 5-6:  E3-004 (Ground Slam) -- first boss ability
Day 7-8:  E3-005 (Charge) -- second boss ability
Day 9:    E3-010 (Boss Kill Tracking Fix) -- bug fix, quick win
Day 10:   Buffer / E3-006 or E3-007 start (Should Have)
```

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and verified
- [ ] 7 Archer exclusive skill SOs created and tested
- [ ] Ground Slam and Charge abilities work in isolation
- [ ] Boss kill tracking uses event subscription, not hardcoded value
- [ ] All existing 73+ tests still pass (regression check)
- [ ] New stories have corresponding unit tests
- [ ] No S1 or S2 bugs in delivered features
- [ ] F-010 compliance maintained (no MagePlayerController casts in shared code)
- [ ] R-025 compliance (boss abilities in correct directory)
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

## Notes

- **N1-006 is the keystone**: It activates N1-007 draft filtering (already coded) and unblocks N1-009's deferred exclusive skill tests
- **ADR-0004 status**: Verify ADR-0004 is Accepted before starting E3-004. If still Proposed, run `/architecture-decision` first.
- **E3-008 blocked until all 4 abilities exist**: Boss prefab configuration needs all ability templates. If Should Have stories (E3-006, E3-007) are not completed this sprint, E3-008 moves to Sprint 5.
- **Scope check**: Run `/scope-check N1` and `/scope-check E3` before implementation begins.
