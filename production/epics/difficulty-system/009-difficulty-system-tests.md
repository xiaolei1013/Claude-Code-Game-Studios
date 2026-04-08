# Story: Difficulty System Tests

> **Epic**: difficulty-system
> **Type**: Logic
> **Priority**: P0
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-difficulty-001 (SO with 6 multipliers), TR-difficulty-002 (IDifficultyProvider interface), TR-difficulty-004 (enemy count Ceil rounding), TR-difficulty-005 (heal drop multiplier), TR-difficulty-006 (pacing multiplier), TR-difficulty-007 (reward Ceil rounding), TR-difficulty-008 (boss exempt from count)
**ADR Reference**: ADR-0001 -- Validation Criteria (all 9 criteria)
**Control Manifest Rules**: R-001 (IDifficultyProvider implemented), R-006 (all consumers read via interface), R-015 (DifficultyConfig as SO)

## Description

Create the comprehensive test suite for the Difficulty System. This covers unit tests for the provider implementations and scaling formulas, plus an integration test for the full difficulty pipeline.

**Test file location:** `Assets/Trizzle/Tests/` (in the `TrizzleUnitTests.asmdef` assembly). Create a `Difficulty/` subfolder for organization.

**Unit Tests for CampaignDifficultyProvider:**

1. `test_CampaignProvider_Normal_ReturnsCorrectValues` -- Instantiate with Normal config, verify all 7 properties match Normal preset (1.0, 1.2, 1.0, 1.0, 1.0, 1.0, true)
2. `test_CampaignProvider_Hard_ReturnsCorrectValues` -- Instantiate with Hard config, verify all 7 properties match Hard preset (1.2, 1.5, 1.25, 0.5, 0.75, 2.0, true)
3. `test_CampaignProvider_IsBossExemptFromCount_AlwaysTrue` -- Verify `IsBossExemptFromCount` returns `true` for both Normal and Hard configs

**Unit Tests for Scaling Formulas:**

4. `test_EnemyCountScaling_CeilRounding` -- Verify `Ceil(1 * 1.25) == 2`, `Ceil(3 * 1.25) == 4`, `Ceil(4 * 1.25) == 5`, `Ceil(7 * 1.25) == 9`
5. `test_EnemyCountScaling_NormalMultiplier_PreservesBase` -- Verify `Ceil(N * 1.0) == N` for various N
6. `test_EnemyCountScaling_BossExempt` -- Verify boss enemy count is always 1 regardless of multiplier
7. `test_HealDropMultiplier_ReducesChance` -- Verify `0.10 * 0.5 == 0.05`, `0.01 * 0.5 == 0.005`
8. `test_HealDropMultiplier_Normal_PreservesChance` -- Verify `0.10 * 1.0 == 0.10`
9. `test_PacingMultiplier_ReducesDelay` -- Verify `4.0 * 0.75 == 3.0`, `2.0 * 0.75 == 1.5`
10. `test_PacingMultiplier_Normal_PreservesDelay` -- Verify `4.0 * 1.0 == 4.0`
11. `test_RewardScaling_CeilRounding` -- Verify `Ceil(5 * 2.0) == 10`, `Ceil(3 * 2.0) == 6`, `Ceil(1 * 2.0) == 2`
12. `test_RewardScaling_MinimumIsOne` -- Verify reward is never 0 (Ceil guarantees minimum 1 for any positive base)

**Integration Test for Full Pipeline (ADR-0001 Validation Criteria):**

13. `test_Integration_SwitchProvider_ConsumersReadCorrectValues` -- Set `GameManager.ActiveDifficultyProvider` to Normal, verify SpawnManager reads Normal values. Switch to Hard, verify SpawnManager reads Hard values. Switch back to Normal, verify values revert.
14. `test_Integration_ProviderNeverNull` -- Verify `GameManager.ActiveDifficultyProvider` is not null after `Awake()` and after `SetDifficultyProvider()` calls

**Test patterns:**
- Use Moq to create mock `IDifficultyProvider` implementations for isolated formula tests
- Use `ScriptableObject.CreateInstance<DifficultyConfig>()` for test config assets (no disk I/O)
- All tests must be deterministic -- no random seeds, no time-dependent assertions
- Tests must be independent -- each sets up and tears down its own state

## Acceptance Criteria

- [ ] All 14+ test cases listed above are implemented and passing
- [ ] ADR-0001 Validation Criterion: `CampaignDifficultyProvider` with Hard config returns `EnemyCountMultiplier == 1.25`, `HealDropMultiplier == 0.5`, `RewardMultiplier == 2.0`
- [ ] ADR-0001 Validation Criterion: `IsBossExemptFromCount` returns `true` from CampaignDifficultyProvider
- [ ] ADR-0001 Validation Criterion: `GameManager.ActiveDifficultyProvider` is never null during any gameplay state
- [ ] ADR-0001 Validation Criterion: Integration test -- switch provider and verify consumers read correct values
- [ ] Tests use NUnit + Moq per project testing standards
- [ ] Tests are in `Assets/Trizzle/Tests/Difficulty/` within the `TrizzleUnitTests.asmdef` assembly
- [ ] All tests are deterministic and independent (no execution order dependency)
- [ ] Tests run successfully via `Unity -batchmode -quit -projectPath . -runTests -testPlatform EditMode -testFilter "Difficulty"`

## Test Evidence

**Type**: Unit Test (self-referential -- this IS the test story)
**Path**: `Assets/Trizzle/Tests/Difficulty/`

- CI output: All tests green
- Test report: `results.xml` from Unity Test Runner

## Dependencies

- **Blocked by**: 001-idfficulty-provider-interface (interface and provider must exist to test), 003-enemy-stat-scaling, 004-enemy-count-scaling, 005-healing-drop-rate, 006-spawn-pacing-scaling, 007-reward-scaling (integration tests require consumer wiring)
- **Blocks**: None (tests are a validation gate, not a build dependency)

## Engine Notes

Tests use Unity Test Framework (NUnit) with Moq, per project testing standards in `CLAUDE.md`. The `TrizzleUnitTests.asmdef` assembly in `Assets/Trizzle/Tests/` is the test assembly. Use `[Test]` attribute for NUnit test methods. `ScriptableObject.CreateInstance<T>()` creates runtime instances without asset files -- suitable for EditMode tests. For integration tests that need `GameManager`, use test scaffolding that instantiates a minimal `GameManager` with the provider.
