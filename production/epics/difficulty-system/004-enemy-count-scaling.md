# Story: Enemy Count Scaling

> **Epic**: difficulty-system
> **Type**: Logic
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-difficulty-004 (Ceil(baseCount * enemyCountMultiplier); extra enemies round-robin across spawn points), TR-difficulty-008 (boss enemies exempt from count scaling)
**ADR Reference**: ADR-0001 -- Key Interfaces (EnemyCountMultiplier, IsBossExemptFromCount), Implementation Guideline 3 (consumer migration)
**Control Manifest Rules**: R-006 (read via IDifficultyProvider), R-022 (EnemyData.IsBoss for boss detection), F-001 (no direct enum checks), F-007 (no tag/name string comparisons for boss detection)

## Description

Wire `SpawnManager` to apply `EnemyCountMultiplier` from `IDifficultyProvider` when spawning wave enemies. Boss enemies must be exempt from count scaling.

**Implementation:**

1. In `SpawnManager`, when processing each `SpawnItemInfo` in a wave, apply the enemy count multiplier:
   ```csharp
   var provider = GameManager.Instance.ActiveDifficultyProvider;
   int scaledCount = Mathf.CeilToInt(baseSpawnCount * provider.EnemyCountMultiplier);
   ```

2. **Boss exemption:** Before applying the multiplier, check `EnemyData.IsBoss` (per R-022 and F-007). If the enemy is a boss, use `baseSpawnCount` unchanged (always 1). Check `provider.IsBossExemptFromCount` as the gating flag -- it always returns `true`, but reading it from the interface makes the rule explicit and discoverable.

3. **Spawn point overflow:** When `scaledCount > baseSpawnCount`, extra enemies spawn at existing spawn points via round-robin across available `EnemySpawnPoint` transforms. No new spawn points need to be created.

4. **Rounding:** Always use `Mathf.CeilToInt` -- never round down. GDD examples:
   - baseCount=1, multiplier=1.25 -> Ceil(1.25) = 2 (solo enemy becomes a pair)
   - baseCount=3, multiplier=1.25 -> Ceil(3.75) = 4
   - baseCount=7, multiplier=1.25 -> Ceil(8.75) = 9

5. Read the provider fresh from `GameManager.Instance` each time -- do not cache at Awake.

## Acceptance Criteria

- [ ] `SpawnManager` reads `EnemyCountMultiplier` from `GameManager.Instance.ActiveDifficultyProvider`
- [ ] Wave spawn count = `Ceil(baseCount * EnemyCountMultiplier)` for non-boss enemies
- [ ] Boss enemies (detected via `EnemyData.IsBoss`, NOT tag/string comparison) are exempt from count scaling
- [ ] GDD AC 4: A wave with `spawnCount = 4` spawns 5 enemies on Hard. Verified with at least 3 different wave sizes (1, 4, 7)
- [ ] GDD AC 8: Boss wave spawns exactly 1 boss on both Normal and Hard
- [ ] Extra enemies beyond available spawn points use round-robin spawn point assignment
- [ ] Normal difficulty (multiplier=1.0) produces identical spawn counts to current behavior
- [ ] No direct difficulty enum checks remain in SpawnManager spawn count logic

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/difficulty/`

- Unit test: `Ceil(1 * 1.25) == 2`
- Unit test: `Ceil(4 * 1.25) == 5`
- Unit test: `Ceil(7 * 1.25) == 9`
- Unit test: Boss enemy with multiplier=1.25 still spawns exactly 1
- Unit test: Normal multiplier=1.0 preserves base count for all test cases

## Dependencies

- **Blocked by**: 001-idfficulty-provider-interface (IDifficultyProvider must exist), 002-normal-hard-config-presets (config values needed)
- **Blocks**: 009-difficulty-system-tests (integration test covers full pipeline)

## Engine Notes

`SpawnManager` is an existing singleton manager in `Assets/Trizzle/Scripts/Manager/`. Read the current implementation to identify where `SpawnItemInfo.SpawnCount` is consumed and where the spawn loop iterates over spawn points. `EnemyData` is a ScriptableObject -- confirm `IsBoss` field exists (it may need to be added per R-022 / ADR-0004; if not yet present, this story should add it or coordinate with the Boss Phase System epic).

## Completion Notes
**Completed**: 2026-04-08
**Criteria**: 8/8 passing
**Deviations**: LevelDifficulty param still in SpawnEnemies/GenerateEnmeyWave signatures (unused for count logic, separate refactor). EnemyData.IsBoss defaults false for all existing entries (must flag bosses in Inspector).
**Test Evidence**: Logic — Assets/Trizzle/Tests/Difficulty/EnemyCountScalingTest.cs (9 tests)
**Code Review**: Skipped (Lean mode)
