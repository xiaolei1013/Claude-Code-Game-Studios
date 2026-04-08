# Sprint 1 -- 2026-04-08 to 2026-04-22

## Sprint Goal

Establish the IDifficultyProvider foundation and audit the incomplete skill codebase, unblocking all downstream epics (N1 Archer, E3 Boss Phases, E4 Combo/Synergy, E1 Room Content, N2 Endless Mode).

## Capacity

- Total days: 10 (2-week sprint, solo developer)
- Buffer (20%): 2 days reserved for unplanned work and bug fixes
- Available: 8 days
- Owner: Xiaolei (all tasks)

## Tasks

### Must Have (Critical Path) -- 6.5 days

These stories form the P0 critical path. Both Layer 0 epics must land to unblock Layer 1.

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E2-001 | IDifficultyProvider Interface & Campaign Provider | E2 Difficulty | 2.5 | None (Layer 0 root) | IDifficultyProvider interface (7 properties), DifficultyConfig SO, CampaignDifficultyProvider MonoBehaviour, GameManager.ActiveDifficultyProvider property -- all compile with zero warnings |
| E2-002 | Normal & Hard Config Presets | E2 Difficulty | 1.0 | E2-001 | DifficultyConfig_Normal.asset and DifficultyConfig_Hard.asset created with GDD values, Normal wired as default on CampaignDifficultyProvider |
| E2-003 | Enemy Stat Scaling Integration | E2 Difficulty | 2.0 | E2-001, E2-002 | EnemyController.InitAttributes() reads from IDifficultyProvider, no direct enum checks remain, Normal behavior identical to demo |
| E5-001 | Skill Code Audit | E5 Incomplete Skills | 1.0 | None (Layer 0 root) | Audit report at production/epics/incomplete-skills/audit-report.md with Category A (TODOs), B (missing prefabs), C (MagePlayerController casts) -- totals match or exceed 10 TODO files, 30 cast files, 3 missing prefabs |

**Must Have Total: 6.5 days (within 8-day capacity)**

### Should Have (Start if Capacity Allows) -- 5.5 days total

These stories begin after Must Have items complete. Expected to carry over into Sprint 2.

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E5-002 | Complete Skill Implementations | E5 Incomplete Skills | 3.0 | E5-001 | All TODO/placeholder logic resolved, shared skills cast to PlayerController/ICharacterClass, all 121 skills compile |
| E2-004 | Enemy Count Scaling | E2 Difficulty | 2.5 | E2-001, E2-002 | SpawnManager reads EnemyCountMultiplier from IDifficultyProvider, boss exempt via EnemyData.IsBoss, Ceil rounding verified |

### Nice to Have (Defer to Sprint 2) -- 10.5 days total

| ID | Task | Epic | Est. Days | Dependencies | Acceptance Criteria |
|----|------|------|-----------|-------------|---------------------|
| E2-005 | Healing Drop Rate Scaling | E2 Difficulty | 1.0 | E2-001, E2-002 | Drop behavior reads HealDropMultiplier, non-healing drops unaffected |
| E2-006 | Spawn Pacing Scaling | E2 Difficulty | 1.0 | E2-001, E2-002 | SpawnManager inter-wave delay = baseDelay * PacingMultiplier |
| E2-007 | Reward Scaling | E2 Difficulty | 1.0 | E2-001, E2-002 | Reward amount = Ceil(baseReward * RewardMultiplier), shop prices unaffected |
| E2-008 | Hard Mode Unlock Gating | E2 Difficulty | 2.5 | E2-001, E2-002 | UI shows lock/unlock state from LevelStats, SetDifficultyProvider called on room entry |
| E2-009 | Difficulty System Tests | E2 Difficulty | 2.0 | E2-001, E2-002, E2-003, E2-004, E2-005, E2-006, E2-007 | All 14+ unit and integration tests passing, ADR-0001 validation criteria verified |
| E5-003 | Create Missing Skill Prefabs | E5 Incomplete Skills | 2.0 | E5-001 | IceWall, IcePond, Icicle prefabs created with correct colliders, pool-compatible |
| E5-004 | Skill Completion Tests | E5 Incomplete Skills | 2.0 | E5-002, E5-003 | 15+ tests passing, bulk activation smoke test, zero TODO/FIXME in skill directory |

## Carryover from Previous Sprint

N/A -- this is the first sprint.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ADR-0001 still Proposed (not Accepted) | HIGH | HIGH -- E2-001 implementation is technically blocked by an unaccepted ADR | Accept ADR-0001 before starting E2-001. The ADR has been reviewed and is architecturally sound. Sprint Day 1 action item. |
| EnemyController existing code shape differs from assumptions | MEDIUM | MEDIUM -- may increase E2-003 estimate if stat multiplier sourcing is more complex than expected | E5-001 audit runs in parallel and reveals codebase shape. Budget 0.5d from buffer if needed. |
| MagePlayerController cast count higher than 30 | LOW | LOW -- E5-002 estimate already accounts for 30 files; additional files would push it further into Sprint 2 | E5-001 audit will give exact count. Any overage defers naturally since E5-002 is Should Have. |
| Unity 6 API surprises in MonoBehaviour/SO lifecycle | LOW | MEDIUM -- ScriptableObject serialization or Awake ordering may differ in Unity 6000.3.11f1 | ADR-0001 Engine Compatibility rates this as LOW risk. Verify in first build after E2-001. |
| E5-002 scope expansion after audit reveals more issues | MEDIUM | LOW -- E5-002 is already Should Have and expected to carry over | Audit report (E5-001) will give exact scope. Adjust Sprint 2 planning accordingly. |

## Dependencies on External Factors

- **ADR-0001 must be Accepted before E2-001 implementation begins.** Currently status: Proposed. Action: Accept ADR-0001 on Sprint Day 1 (2026-04-08).
- No external library dependencies.
- No platform-specific dependencies (all work is core C# + ScriptableObject).

## Sprint Schedule (Recommended Execution Order)

```
Day 1:  Accept ADR-0001 | Start E2-001 (interface + provider) | Start E5-001 (audit, parallel)
Day 2:  E2-001 continues | E5-001 completes
Day 3:  E2-001 completes
Day 4:  E2-002 (config presets, 1 day)
Day 5:  E2-003 (stat scaling integration, start)
Day 6:  E2-003 completes
Day 7:  E5-002 (skill implementations, start -- Should Have)
Day 8:  E5-002 continues / E2-004 start if E5-002 blocked
Day 9:  Buffer
Day 10: Buffer
```

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and verified
- [ ] All Must Have tasks pass their acceptance criteria
- [ ] IDifficultyProvider interface is stable and implemented
- [ ] CampaignDifficultyProvider reads from DifficultyConfig ScriptableObjects
- [ ] GameManager.ActiveDifficultyProvider is wired and never null
- [ ] EnemyController.InitAttributes() reads from IDifficultyProvider (no enum checks)
- [ ] Normal difficulty behavior is identical to current demo build (regression check)
- [ ] E5 audit report exists with complete categorized inventory
- [ ] ADR-0001 status updated to Accepted
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1
- [ ] Design documents updated for any deviations from GDD
- [ ] No S1 or S2 bugs in delivered features

## Notes

- **Scope check:** This sprint includes only stories from the original E2 and E5 epics. No scope additions. Run `/scope-check E2` and `/scope-check E5` before Sprint 2 planning to verify no creep.
- **PR-SPRINT skipped -- Lean mode.** Producer feasibility was validated during sprint planning (6.5d Must Have fits within 8d capacity with 1.5d margin).
- **E5-002 partial completion expected.** The L-sized story (3 days) is Should Have and will likely carry over. This is intentional -- the audit (E5-001) must complete first to scope E5-002 accurately.
- **E2-009 (Tests) deferred.** The comprehensive test story requires all consumer stories (003-007) to be complete. It will anchor Sprint 2 after the remaining difficulty axes ship.

> **No QA Plan**: This sprint was started without a QA plan. Run `/qa-plan sprint`
> before the last story is implemented. The Production to Polish gate requires a QA
> sign-off report, which requires a QA plan.
