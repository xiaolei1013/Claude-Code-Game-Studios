# Story: Combo System Tests

> **Epic**: combo-synergy
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-combo-001 through TR-combo-012 (all combo requirements), all 10 GDD Acceptance Criteria
**ADR Reference**: ADR-0003 -- Validation Criteria (12 criteria covering all critical behaviors)
**Control Manifest Rules**: R-005 (IComboRegistry), R-011 (Activate/Deactivate lifecycle), R-012 (Activate guard), R-019 (ComboEffect SO), R-020 (TriggerContext struct), R-022 (EnemyData.IsBoss), R-028 (OnComboDiscovered fires once), F-007 (no tag/string boss detection), F-012 (no polling), G-002 (< 0.5ms/frame), G-009 (Elemental Storm 5-hit cap)

## Description

Create the comprehensive test suite for the Combo/Synergy system. This covers unit tests for combo detection, effect activation/deactivation lifecycle, stacking behavior, and the two critical edge cases (Executioner boss immunity, Elemental Storm 5-hit cap). This story validates ADR-0003 Validation Criteria and GDD Acceptance Criteria.

**Test file location:** `Assets/Trizzle/Tests/Combo/` within the `TrizzleUnitTests.asmdef` assembly.

### Unit Tests: ComboRegistry Detection

1. `test_CheckCombos_SinglePair_DetectsCombo` -- Draft SkillA + SkillB of a known combo. Verify `CheckCombos()` returns the combo. (GDD AC 1)
2. `test_CheckCombos_ReversedOrder_DetectsCombo` -- Draft SkillB first, then SkillA. Verify same combo detected (order-independent).
3. `test_CheckCombos_IncompleteSkills_NoCombo` -- Draft only SkillA of a pair. Verify no combo detected.
4. `test_CheckCombos_MultiplePairs_DetectsAll` -- Draft 4 skills forming 2 combos. Verify both combos detected. (GDD AC 3)
5. `test_CheckCombos_AlreadyActive_NoDuplicate` -- Call `CheckCombos()` again with same skills. Verify no duplicate detection.
6. `test_CheckCombos_NullSkillReference_Skipped` -- Combo with null `skillA` or `skillB` is silently skipped with no exception. (GDD AC 10)
7. `test_CheckCombos_NullTriggerEffect_Skipped` -- Combo with null `triggerEffect` is detected but `Activate()` is not called. No NullReferenceException.

### Unit Tests: ComboEffect Lifecycle

8. `test_Activate_SetsIsActive` -- `Activate()` sets `_isActive = true`.
9. `test_Activate_CallsDeactivateFirst` -- `Activate()` calls `Deactivate()` before subscribing (R-012 guard).
10. `test_Deactivate_Idempotent` -- `Deactivate()` on an already-deactivated effect does not throw. (ADR-0003 VC)
11. `test_Deactivate_ClearsPlayerReference` -- After `Deactivate()`, `_player` is null.
12. `test_ActivateDeactivateActivate_NoDoubleSubscription` -- `Activate()`, `Deactivate()`, `Activate()` again. Verify event fires exactly once per trigger. (ADR-0003 VC: state leak test)

### Unit Tests: Combo Stacking

13. `test_TwoCombosActive_BothEffectsFire` -- Activate 2 combos. Trigger both. Verify both effects execute. (GDD AC 3)
14. `test_DeactivateAll_AllEffectsClean` -- Activate 3 combos. Call `DeactivateAllCombos()`. Verify all `_isActive == false`. (GDD AC 5)

### Unit Tests: Executioner Boss Immunity (CRITICAL)

15. `test_Executioner_BossImmune_NoKill` -- Mock `EnemyData.IsBoss = true`, Slow active, HP at 20% (below threshold). Call `OnTrigger()`. Verify target HP is unchanged. (GDD AC 7, TR-combo-008, ADR-0003 VC)
16. `test_Executioner_NonBoss_SlowedBelowThreshold_Kill` -- Mock `IsBoss = false`, Slow active, HP at 20%. Verify instant kill.
17. `test_Executioner_NonBoss_NotSlowed_NoKill` -- `IsBoss = false`, no Slow, HP at 20%. Verify no kill (Slow required).
18. `test_Executioner_NonBoss_SlowedAboveThreshold_NoKill` -- `IsBoss = false`, Slow active, HP at 26%. Verify no kill (above threshold).
19. `test_Executioner_NonBoss_SlowedAtExactThreshold_Kill` -- `IsBoss = false`, Slow active, HP at exactly 25%. Verify kill (threshold is <=, not <).

### Unit Tests: Elemental Storm 5-Hit Cap (CRITICAL)

20. `test_ElementalStorm_BurnAndFreeze_BonusApplied` -- Target has both Burn and Freeze. First hit gets 30% bonus.
21. `test_ElementalStorm_OnlyBurn_NoBonusApplied` -- Target has Burn but not Freeze. No bonus.
22. `test_ElementalStorm_OnlyFreeze_NoBonusApplied` -- Target has Freeze but not Burn. No bonus.
23. `test_ElementalStorm_FiveHits_AllGetBonus` -- 5 consecutive hits on Burn+Freeze target. All get bonus. (ADR-0003 VC)
24. `test_ElementalStorm_SixthHit_NoBonus` -- 6th hit on same target does NOT get bonus. Counter has expired. (ADR-0003 VC, G-009)
25. `test_ElementalStorm_StatusDropped_CounterResets` -- After 3 hits, Burn drops off. Reapply Burn+Freeze. Verify counter resets to 0 and bonus applies again.
26. `test_ElementalStorm_MultipleTargets_IndependentCounters` -- Two targets, each with Burn+Freeze. Hit counts are tracked independently per target.

### Unit Tests: TriggerContext

27. `test_TriggerContext_IsValueType` -- `typeof(TriggerContext).IsValueType == true`. Confirms struct, not class. (TR-combo-011)
28. `test_TriggerContext_ConstructorSetsAllFields` -- Create `TriggerContext` with all args. Verify each field.

### Integration Tests

29. `test_Integration_DraftTriggersComboPipeline` -- Simulate full flow: draft SkillA, draft SkillB, verify `CheckCombos()` fires, `OnComboDiscovered` fires, `ComboEffect.Activate()` is called.
30. `test_Integration_RunEnd_DeactivatesAll` -- Activate 2 combos. Trigger run-end event. Verify both effects deactivated and `ActiveCombos` is empty.

### Test patterns:
- Use `ScriptableObject.CreateInstance<T>()` for test ComboEffect instances (no disk I/O)
- Use Moq for `PlayerController`, `Health`, `EnemyData`, `StateMachine` mocks
- Create a test-only `TestComboEffect : ComboEffect` subclass that tracks method calls
- All tests deterministic -- no random seeds (for Supernova/GoldRush proc tests, set proc chance to 0.0 and 1.0)
- Tests are independent -- each sets up and tears down its own state

## Acceptance Criteria

- [ ] All 30 test cases listed above are implemented and passing
- [ ] ADR-0003 Validation Criteria: All 12 validation criteria have corresponding test coverage
- [ ] GDD Acceptance Criteria: Tests cover AC 1 (detection), AC 3 (stacking), AC 5 (run reset), AC 7 (boss immunity), AC 9 (18 entries), AC 10 (null safety)
- [ ] Executioner boss immunity is verified by test (BLOCKING -- this is a hard GDD requirement)
- [ ] Elemental Storm 5-hit cap is verified by test (BLOCKING -- G-009 guardrail)
- [ ] Tests use NUnit + Moq per project testing standards
- [ ] Tests are in `Assets/Trizzle/Tests/Combo/` within the `TrizzleUnitTests.asmdef` assembly
- [ ] All tests are deterministic and independent (no execution order dependency)
- [ ] Tests run successfully via `Unity -batchmode -quit -projectPath . -runTests -testPlatform EditMode -testFilter "Combo"`

## Test Evidence

**Type**: Unit Test (self-referential -- this IS the test story)
**Path**: `Assets/Trizzle/Tests/Combo/`

- CI output: All tests green
- Test report: `results.xml` from Unity Test Runner

## Dependencies

- **Blocked by**: 001-extend-combo-definition (enums), 002-combo-effect-base-class (abstract class, IComboRegistry, TriggerContext), 003-mage-combo-effects (for Mage effect-specific tests), 004-archer-combo-effects, 005-universal-combo-effects (for Executioner and Elemental Storm tests), 007-combo-database-population (for integration test with populated database)
- **Blocks**: None -- tests are a validation gate, not a build dependency

## Engine Notes

Tests use Unity Test Framework (NUnit) with Moq, per project testing standards in `CLAUDE.md`. `ScriptableObject.CreateInstance<T>()` creates runtime instances without asset files -- suitable for EditMode tests. For integration tests that need `ComboRegistry` and `PlayerController`, use test scaffolding that instantiates minimal required components. Mock `StateMachine.HasState()` for status-conditional tests (Executioner Slow check, Elemental Storm Burn/Freeze check). Mock `EnemyData.IsBoss` for boss immunity tests.

## Completion Notes

**Completed**: 2026-04-18
**Criteria**: 30/30 test cases covered across existing + new ComboSystemIntegrationTest.cs
**Deviations**: None. Tests distributed across 22 existing files + 1 new integration file.
**Test Evidence**: Logic: `Assets/Trizzle/Tests/Combo/ComboSystemIntegrationTest.cs` (10 new tests) + 150+ existing tests across Mage/Archer/Universal effect files
**Code Review**: Pending
