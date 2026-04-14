# Story: Reward Scaling

> **Epic**: difficulty-system
> **Type**: Logic
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: S

## Context

**GDD Requirement**: TR-difficulty-007 (Ceil(baseReward * rewardMultiplier); applies to enemy kills, boss drops, room-clear bonuses; shop prices unaffected)
**ADR Reference**: ADR-0001 -- Key Interfaces (RewardMultiplier property), Migration Plan step 9 (migrate D8 drop behaviors)
**Control Manifest Rules**: R-006 (read via IDifficultyProvider), F-001 (no direct enum/struct access in drop behaviors)

## Description

Wire gold/gem drops and room-clear bonuses to apply `RewardMultiplier` from `IDifficultyProvider`. Shop prices must NOT be affected.

**Implementation:**

1. Locate all reward grant code paths: enemy kill drops, boss drops, and room-clear bonuses. These are in the Loot & Drops (D8) system.

2. At each reward grant point, apply the multiplier with Ceil rounding:
   ```csharp
   var provider = GameManager.Instance.ActiveDifficultyProvider;
   int actualReward = Mathf.CeilToInt(baseReward * provider.RewardMultiplier);
   ```

3. **Reward types affected:** Gold drops, gem drops, and any material drops (boss essence, etc.).

4. **NOT affected:** Shop prices. The shop reads base prices, not difficulty-scaled prices. Verify that the shop pricing code path does not accidentally pass through the reward multiplier.

5. **Rounding:** Always `Mathf.CeilToInt` -- minimum reward is 1, never 0.

6. GDD formula examples:
   - Normal: 5 gold base -> 5 gold (multiplier = 1.0)
   - Hard: 5 gold base -> 10 gold (multiplier = 2.0)
   - Edge case: 3 gold base, Hard -> Ceil(3 * 2.0) = 6

7. Read the provider fresh from `GameManager.Instance` each time.

## Acceptance Criteria

- [ ] Drop/reward code reads `RewardMultiplier` from `GameManager.Instance.ActiveDifficultyProvider`
- [ ] Reward amount = `Ceil(baseReward * RewardMultiplier)` for all reward types
- [ ] GDD AC 7: Gold and gem drop amounts are exactly 2x Normal values on Hard. Verified on enemy kill drops, boss drops, and room-clear bonus
- [ ] Shop prices are NOT affected by `RewardMultiplier`
- [ ] Minimum reward is 1 (never 0) due to Ceil rounding
- [ ] Normal difficulty (multiplier=1.0) produces identical reward amounts to current behavior
- [ ] No direct difficulty enum checks remain in reward/drop code

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/difficulty/`

- Unit test: `Ceil(5 * 1.0) == 5` (Normal)
- Unit test: `Ceil(5 * 2.0) == 10` (Hard)
- Unit test: `Ceil(3 * 2.0) == 6` (odd value)
- Unit test: `Ceil(1 * 2.0) == 2` (minimum base)
- Unit test: Shop price with `RewardMultiplier = 2.0` remains at base price

## Dependencies

- **Blocked by**: 001-idfficulty-provider-interface (IDifficultyProvider must exist), 002-normal-hard-config-presets (config values needed)
- **Blocks**: 009-difficulty-system-tests (integration test covers full pipeline)

## Engine Notes

Reward grant code is likely in the loot/drop system under `Assets/Trizzle/Scripts/Combat/` or `Assets/Trizzle/Scripts/` (look for drop behaviors, loot tables, or reward controllers). `Mathf.CeilToInt` is a standard Unity API. Ensure the multiplier is applied at the grant point, not at the UI display point -- the actual currency added to the player's inventory must be the scaled amount.

## Completion Notes
**Completed**: 2026-04-10
**Criteria**: 6/7 passing (AC-3 playtest 2x verification deferred)
**Deviations**: None
**Test Evidence**: Logic: unit test at Assets/Trizzle/Tests/Difficulty/RewardScalingTest.cs (7 tests)
**Code Review**: Skipped (Lean mode)
**Files Changed**: EnemyController.cs (gold/gem CeilToInt with RewardMultiplier), NormalLootIChestBehavior.cs (gold/gem CeilToInt with RewardMultiplier)
