# Story: Endless Mode Tests

> **Epic**: endless-mode
> **Type**: Logic
> **Priority**: P0
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: All TR-endless-001 through TR-endless-014 (validation of the complete Endless Mode system)
**ADR Reference**: ADR-0001 Validation Criteria (EndlessDifficultyProvider unit tests), ADR-0007 Validation Criteria (EndlessWaveProvider unit tests, integration test coverage)
**Control Manifest Rules**: G-001 (frame time budgets), G-003 (< 1 microsecond EndlessDifficultyProvider computation), G-005 (IWaveProvider.GetNextWave negligible cost), G-008 (elite ratio cap 50%)

## Description

Create the comprehensive test suite for Endless Mode, covering unit tests for all scaling formulas and an integration test that validates a full 20-wave run. This story ensures all N2 technical requirements are verifiable and regression-testable.

**Test files to create:**

### Unit Tests (`tests/unit/endless/`)

1. **`endless_difficulty_scaling_test.cs`** -- EndlessDifficultyProvider formula verification:
   - `test_statMultiplier_wave1_returns_1_04`
   - `test_statMultiplier_wave10_returns_1_4`
   - `test_statMultiplier_wave25_returns_2_0`
   - `test_statMultiplier_wave50_returns_3_0`
   - `test_healDropMultiplier_wave10_returns_0_7`
   - `test_healDropMultiplier_wave30_clamps_to_floor_0_1`
   - `test_pacingMultiplier_wave20_returns_0_7`
   - `test_pacingMultiplier_wave33_clamps_to_floor_0_5`
   - `test_enemyCountMultiplier_always_returns_1_0`
   - `test_rewardMultiplier_always_returns_1_5`
   - `test_isBossExemptFromCount_always_returns_true`

2. **`endless_wave_composition_test.cs`** -- EndlessWaveProvider formula verification:
   - `test_enemyCount_wave1_returns_4`
   - `test_enemyCount_wave10_returns_9`
   - `test_enemyCount_wave20_returns_14`
   - `test_enemyCount_wave30_returns_19`
   - `test_eliteRatio_wave1_returns_0_02`
   - `test_eliteRatio_wave25_returns_0_50_cap`
   - `test_eliteRatio_wave50_still_capped_at_0_50`
   - `test_enemyTypeCount_wave1_returns_1`
   - `test_enemyTypeCount_wave5_returns_2`
   - `test_enemyTypeCount_wave20_returns_5_cap`
   - `test_isBossWave_true_for_multiples_of_10`
   - `test_isBossWave_false_for_non_multiples`
   - `test_getBossConfig_wave10_returns_boss_A`
   - `test_getBossConfig_wave50_returns_boss_E`
   - `test_getBossConfig_wave60_returns_boss_A_cycle_restart`
   - `test_getTrapLayout_always_returns_null`

3. **`endless_session_controller_test.cs`** -- Session lifecycle verification:
   - `test_startRun_resets_wave_and_score_to_zero`
   - `test_startRun_sets_difficulty_provider_on_gameManager`
   - `test_startRun_sets_wave_provider_on_spawnManager`
   - `test_setWave_called_before_spawnNextWave` (ordering assertion)

### Integration Test (`tests/integration/endless/`)

4. **`endless_20_wave_run_test.cs`** -- Full integration test simulating a 20-wave run:
   - Verify enemy counts match formula at waves 1, 5, 10, 15, 20
   - Verify draft screen triggers at waves 5, 10, 15, 20
   - Verify boss spawns at wave 10, wave 20
   - Verify boss identity: wave 10 = Boss A, wave 20 = Boss B
   - Verify stat scaling increases measurably between wave 1 and wave 20
   - Verify heal drop multiplier decreases over time
   - Verify score equals waves cleared on simulated death
   - Verify score persists correctly via LevelStats

**Test design constraints:**
- All tests must be deterministic (no random seeds, no time-dependent assertions)
- Unit tests must not require a running SpawnManager or DraftRunController -- use dependency injection and mocks
- Integration test may use simulated wave completion (mock SpawnManager.IsWaveComplete)
- Test fixtures use factory functions, not inline magic numbers (except boundary value tests)

## Acceptance Criteria

- [ ] All 11 `EndlessDifficultyProvider` formula unit tests exist and pass
- [ ] All 16 `EndlessWaveProvider` formula unit tests exist and pass
- [ ] All 4 `EndlessSessionController` lifecycle unit tests exist and pass
- [ ] Integration test: 20-wave run simulation passes with all checkpoints verified
- [ ] Tests are deterministic -- produce the same result on every run
- [ ] Tests do not depend on execution order
- [ ] Unit tests use mock/stub providers, not live singletons
- [ ] Test file naming follows convention: `[system]_[feature]_test.cs`
- [ ] Test function naming follows convention: `test_[scenario]_[expected]`
- [ ] All tests compile and pass in Unity 6000.3.11f1 test runner

## Test Evidence

**Type**: Automated (this IS the test story)
**Path**: `tests/unit/endless/`, `tests/integration/endless/`

This story IS the test evidence for the entire Endless Mode epic. The tests produced here serve as the blocking gate evidence for Stories 001-003 (Logic type, P0) and advisory evidence for Stories 004-007.

## Dependencies

- **Blocked by**: 001-endless-difficulty-provider, 002-endless-wave-provider, 003-endless-session-controller (systems must exist to test)
- **Blocks**: None (terminal story, but required for epic Definition of Done)

## Engine Notes

Unity test runner with `[Test]` and `[UnityTest]` attributes. Unit tests use `[Test]` (synchronous). Integration test uses `[UnityTest]` (coroutine-based) for the 20-wave simulation that needs frame-by-frame execution. Per CI/CD rules in Coding Standards: `game-ci/unity-test-runner@v4` for GitHub Actions. Tests must not be skipped or disabled to make CI pass.
