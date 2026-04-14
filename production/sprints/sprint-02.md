# Sprint 2 -- 2026-04-10 to 2026-04-24

## Sprint Goal

Deliver the Archer character foundation (playable Archer with core skills) and begin the Boss Phase System, unblocking Layer 2 content epics.

## Capacity

- Total days: 10 (2-week sprint, solo developer)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days
- Owner: Xiaolei (all tasks)
- Sprint 1 velocity: 13 stories / 10 days (high throughput with AI-assisted dev)

## Tasks

### Must Have (Critical Path) -- 7 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| N1-001 | ArcherPlayerController & ICharacterClass | N1 Archer | 2.0 | E5 (done) | ArcherPlayerController : PlayerController, ICharacterClass on both Mage+Archer, PlayerClassType.Archer enum value, no shared skill breaks |
| N1-002 | DashSkill Cast Refactor | N1 Archer | 2.0 | N1-001 | DashSkill casts to PlayerController/ICharacterClass (not MagePlayerController), works for both classes, F-010 compliant |
| N1-003 | Arrow Shot Skill | N1 Archer | 2.0 | N1-001 | ArrowShotSkill with 0.5s cooldown, 0.6x damage, speed 18 projectile, auto-aim targeting |
| N1-005 | Archer Base Stats | N1 Archer | 1.0 | N1-001 | CharacterData SO for Archer with GDD stat values, selectable in character picker |

**Must Have Total: 7 days (within 8-day capacity with 1d margin)**

### Should Have (Start if Capacity Allows) -- 5 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| N1-004 | Dodge Roll Skill | N1 Archer | 2.0 | N1-001 | Archer-exclusive dodge with i-frames, replaces Dash when Archer selected |
| E3-001 | BossController Subclass | E3 Boss | 3.0 | E2 (done) | BossController : EnemyController, IBossPhaseController interface, BossPhase struct, health threshold phase transitions |

### Nice to Have (Defer to Sprint 3) -- 6.5 days

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E3-003 | EnemyData.IsBoss Flag Verification | E3 Boss | 0.5 | None | Verify existing IsBoss field from E2-004 satisfies E3 requirements |
| N1-007 | Draft Pool Filtering | N1 Archer | 2.0 | N1-001 | DraftRunController filters skill candidates by ICharacterClass, no class-specific if branches |
| E3-002 | Stagger State & Phase Transition | E3 Boss | 2.0 | E3-001 | Stagger coroutine: invulnerable -> reset -> swap tree -> apply mods -> VFX -> lift |
| N1-009 | Archer Character Tests | N1 Archer | 2.0 | N1-001, N1-002, N1-003 | 15+ tests covering controller, skills, class interface |

## Carryover from Sprint 1

None -- all 13 stories completed.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ICharacterClass interface breaks existing Mage skills | MEDIUM | HIGH | N1-002 explicitly refactors DashSkill first; E5-004 smoke test validates all 121 skills |
| PlayerClassType enum extension causes switch/case misses | LOW | MEDIUM | Grep all switch(PlayerClassType) before merging N1-001 |
| Arrow projectile physics differs from spell projectiles | LOW | LOW | Reference existing Projectile.cs patterns; FX_ShardIce_Shooting_01 as template |
| BossController scope too large for single story | MEDIUM | LOW | E3-001 is Should Have; can split if needed |

## Dependencies on External Factors

- ADR-0005 must remain Accepted (currently Accepted)
- No external library dependencies
- Arrow Shot may need a projectile prefab (Unity Editor work, like E5-003)

## Sprint Schedule (Recommended Execution Order)

```
Day 1-2:  N1-001 (ArcherController + ICharacterClass) -- critical path root
Day 3-4:  N1-002 (DashSkill refactor) -- unblocks shared skills for Archer
Day 5-6:  N1-003 (Arrow Shot Skill) -- core Archer attack
Day 7:    N1-005 (Archer Base Stats) -- config data
Day 8:    N1-004 (Dodge Roll) or E3-001 start -- Should Have
Day 9-10: Buffer / E3-001 continues
```

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and verified
- [ ] ArcherPlayerController compiles and can be assigned in scene
- [ ] Archer is selectable in character picker with correct stats
- [ ] DashSkill works for both Mage and Archer without cast errors
- [ ] Arrow Shot fires, hits enemies, deals correct damage
- [ ] All existing 528+ tests still pass (regression check)
- [ ] No S1 or S2 bugs in delivered features
- [ ] F-010 compliance maintained (no MagePlayerController casts in shared code)
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

## Notes

- **Critical path**: N1-001 is the root -- everything else depends on ICharacterClass existing
- **E3-003 may already be done**: EnemyData.IsBoss was added in Sprint 1 (E2-004). Verify and close quickly.
- **Scope check**: Run `/scope-check N1` and `/scope-check E3` before Sprint 3 planning

> **No QA Plan**: Run `/qa-plan sprint` before the last story is implemented.
> The Production to Polish gate requires a QA sign-off report, which requires a QA plan.
