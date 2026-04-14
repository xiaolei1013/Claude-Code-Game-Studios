# Story: EnemyData.isBoss Flag

> **Epic**: boss-phase-system
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: S

## Context

**GDD Requirement**: TR-boss-006 (EnemyData.isBoss flag replaces all tag/name-based boss detection in SpawnManager, OneShotKillEffect, DraftRunController)
**ADR Reference**: ADR-0004 -- Decision section (EnemyData addition: `bool IsBoss` with tooltip), Migration Plan step 1 (add IsBoss to EnemyData, set true on boss assets)
**Control Manifest Rules**: R-022 (add bool IsBoss to EnemyData SO; sole mechanism for boss detection), F-007 (do not use tag or name string comparisons for boss detection)

## Description

Add the `isBoss` boolean flag to `EnemyData` ScriptableObject and replace all existing tag/name-based boss detection throughout the codebase. This is a small but critical change that eliminates rename-fragile string comparisons.

**Implementation details:**

1. **Add `IsBoss` to `EnemyData.cs`**:
   ```csharp
   [Tooltip("Set true for boss enemies. Exempts from OneShotKill, count multiplier, and enables IBossPhaseController detection.")]
   public bool IsBoss;
   ```
   All existing EnemyData assets default to `false` (correct for non-boss enemies). Boss EnemyData assets must be opened in Inspector and set to `true`.

2. **Replace boss detection in `OneShotKillEffect`**:
   - Find the current boss check (likely a tag comparison like `CompareTag("Boss")` or name string check)
   - Replace with: `if (enemyData.IsBoss) return;` (or equivalent guard to block instant kill on bosses)

3. **Replace boss detection in `SpawnManager`**:
   - Find any tag/name-based boss detection used for boss wave routing or count exemption
   - Replace with `EnemyData.IsBoss` check

4. **Replace boss detection in `DraftRunController.OnRunComplete()`**:
   - This is partly covered by Story 010 (boss kill tracking fix), but any remaining string-based boss detection in this file must also be migrated here

5. **Grep verification**: After all replacements, `grep -r` the codebase for the old tag/name patterns to confirm zero remaining instances. Document the grep command and output as part of the PR evidence.

**Key constraints:**
- Existing non-boss EnemyData assets do NOT need a bulk migration -- `bool` defaults to `false`
- Boss EnemyData assets (5 total for v1.0) must be manually set to `true` in the Inspector
- This change is backward-compatible -- no existing behavior changes for non-boss enemies

## Acceptance Criteria

- [ ] `EnemyData` ScriptableObject has `public bool IsBoss` field with descriptive tooltip
- [ ] `OneShotKillEffect` uses `EnemyData.IsBoss` to block instant kill on bosses -- no tag/name checks
- [ ] `SpawnManager` uses `EnemyData.IsBoss` for boss detection -- no tag/name checks
- [ ] `DraftRunController` uses `EnemyData.IsBoss` for boss detection -- no tag/name checks
- [ ] `grep -rn` for old tag/name boss patterns returns zero matches in gameplay code
- [ ] All existing non-boss enemies continue to function identically (regression check)
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/boss/`

- Unit test: Create EnemyData with `IsBoss = true`, pass to OneShotKillEffect, verify instant kill is blocked
- Unit test: Create EnemyData with `IsBoss = false`, pass to OneShotKillEffect, verify instant kill is NOT blocked
- Unit test: Verify default `IsBoss` value is `false` on a fresh EnemyData instance
- Manual verification: grep output showing zero tag/name boss detection patterns remaining

## Dependencies

- **Blocked by**: 001-boss-controller-subclass (BossController existence confirms the pattern; but this story can technically proceed in parallel since it only modifies EnemyData and consumer code)
- **Blocks**: 008-boss-prefab-configuration (prefab EnemyData assets need IsBoss set), 010-boss-kill-tracking-fix (uses IsBoss for detection), 011-boss-system-tests

## Engine Notes

Adding a public field to an existing ScriptableObject is safe in Unity -- existing assets get the default value (`false`) on next load. No asset migration needed. The tooltip attribute is purely editor-side.

## Completion Notes
**Completed**: 2026-04-13
**Criteria**: 7/7 passing (EnemyData.IsBoss field pre-existed from E2-004; OneShotKillEffect migrated; SpawnManager already clean from E2-004; DraftRunController receives bossKilled as parameter — no internal detection to replace; grep verified zero tag/name patterns remain)
**Deviations**: DraftRunController.OnRunComplete(bool bossKilled) does not do boss detection itself — it receives the flag from SceneManagerPC. The hardcoded `true` in SceneManagerPC is a separate concern addressed by E3-010 (boss kill tracking fix). AC #4 is satisfied because there is no tag/name boss detection in DraftRunController.
**Test Evidence**: Logic — Assets/Trizzle/Tests/Combat/IsBossFlagTest.cs (6 tests)
**Code Review**: Skipped (Lean mode)
**Files Changed**: EnemyController.cs (added IsBoss property + SetBossFlag method), SpawnManager.cs (calls SetBossFlag at spawn), OneShotKillEffect.cs (replaced CompareTag/name check with EnemyController.IsBoss)
