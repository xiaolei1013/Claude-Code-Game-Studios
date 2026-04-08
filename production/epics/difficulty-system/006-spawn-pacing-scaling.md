# Story: Spawn Pacing Scaling

> **Epic**: difficulty-system
> **Type**: Logic
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: S

## Context

**GDD Requirement**: TR-difficulty-006 (actualDelay = baseDelay * pacingMultiplier; affects inter-wave delay only)
**ADR Reference**: ADR-0001 -- Key Interfaces (PacingMultiplier property), Migration Plan step 8 (migrate SpawnManager)
**Control Manifest Rules**: R-006 (read via IDifficultyProvider), F-001 (no direct enum/struct access)

## Description

Wire `SpawnManager` wave delays to apply `PacingMultiplier` from `IDifficultyProvider`. This affects the delay between waves (inter-wave delay), NOT the within-wave spawn timing.

**Implementation:**

1. In `SpawnManager`, when reading the `Delay` value from each wave's `SpawnItemInfo`, apply the pacing multiplier:
   ```csharp
   var provider = GameManager.Instance.ActiveDifficultyProvider;
   float actualDelay = baseDelay * provider.PacingMultiplier;
   ```

2. **Scope:** Only inter-wave delays are affected. Within-wave spawn timing (the gap between individual enemy spawns within the same wave) is NOT modified by the pacing multiplier.

3. GDD formula examples:
   - Normal: 4.0s base delay -> 4.0s actual (multiplier = 1.0)
   - Hard: 4.0s base delay -> 3.0s actual (multiplier = 0.75)

4. Read the provider fresh from `GameManager.Instance` each time -- do not cache at Awake.

5. **Interaction warning from GDD Tuning Knobs:** `enemyCountMultiplier` and `pacingMultiplier` compound -- more enemies arriving faster can spike CPU load. This is a tuning concern, not an implementation concern. The code should apply the multiplier faithfully; the values in the SO assets control the tuning.

## Acceptance Criteria

- [ ] `SpawnManager` reads `PacingMultiplier` from `GameManager.Instance.ActiveDifficultyProvider`
- [ ] Inter-wave delay = `baseDelay * PacingMultiplier`
- [ ] GDD AC 6: Time between wave 1 and wave 2 start on Hard is ~75% of Normal delay (tolerance +/-0.2s)
- [ ] Within-wave spawn timing is NOT affected by the pacing multiplier
- [ ] Normal difficulty (multiplier=1.0) produces identical wave timing to current behavior
- [ ] No direct difficulty enum checks remain in SpawnManager pacing logic

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/difficulty/`

- Unit test: With `PacingMultiplier = 1.0` and baseDelay 4.0, actualDelay = 4.0
- Unit test: With `PacingMultiplier = 0.75` and baseDelay 4.0, actualDelay = 3.0
- Unit test: With `PacingMultiplier = 0.75` and baseDelay 2.0, actualDelay = 1.5

## Dependencies

- **Blocked by**: 001-idfficulty-provider-interface (IDifficultyProvider must exist), 002-normal-hard-config-presets (config values needed)
- **Blocks**: 009-difficulty-system-tests (integration test covers full pipeline)

## Engine Notes

`SpawnManager` is in `Assets/Trizzle/Scripts/Manager/`. Read the current implementation to find where wave `Delay` values from `SpawnItemInfo` are consumed -- this is likely in a coroutine that waits between waves. The multiplier should be applied to the `WaitForSeconds` duration or equivalent delay mechanism.
