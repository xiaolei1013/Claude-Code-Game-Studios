# Story: Skill Completion Tests

> **Epic**: incomplete-skills
> **Type**: Logic
> **Priority**: P0
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: N/A -- validation task for E5 skill completion work
**ADR Reference**: ADR-0005 (Accepted) -- R-004 (ICharacterClass), F-010 (no MagePlayerController casts in shared skills)
**Control Manifest Rules**: R-004, F-010

## Description

Create the verification and test suite that confirms all E5 completion work is correct. This story has two parts: automated unit tests for the code fixes in Story 002, and a systematic activation test for all 121 skill implementations.

**Part 1: Unit Tests for Fixed Skills (Category A fixes from Story 002)**

Write targeted unit tests for each skill that had placeholder logic replaced with real implementations. Test file location: `Assets/Trizzle/Tests/Character/Skill/` (in the `TrizzleUnitTests.asmdef` assembly), organized by skill category subdirectory matching the source structure.

**CurseBreakerSkill Tests** (`Tests/Character/Skill/Condition/CurseBreakerSkillTest.cs` -- may already exist, extend if so):
1. `test_CurseBreaker_HasDebuff_ReturnsTrueWhenTargetHasDebuff` -- verify `HasDebuff` returns true when StateMachine has the specified debuff state active
2. `test_CurseBreaker_HasDebuff_ReturnsFalseWhenNoDebuff` -- verify returns false when no matching debuff
3. `test_CurseBreaker_HasAnyDebuff_ReturnsTrueWhenAnyDebuffActive` -- verify `HasAnyDebuff` detects any active debuff
4. `test_CurseBreaker_HasAnyDebuff_ReturnsFalseWhenClean` -- verify returns false when no debuffs active

**BloodBondSkill Tests** (`Tests/Character/Skill/Condition/BloodBondSkillTest.cs` -- may already exist, extend if so):
5. `test_BloodBond_DamageCalculation_UsesRealDamageCalculator` -- verify damage is computed through DamageCalculator, not placeholder return
6. `test_BloodBond_Healing_AppliesCorrectAmount` -- verify heal amount matches expected percentage of damage dealt
7. `test_BloodBond_EnemyDetection_FindsValidTargets` -- verify enemy detection uses real system, not hardcoded true

**ArcaneReboundSkill Tests** (`Tests/Character/Skill/Support/ArcaneReboundSkillTest.cs` -- may already exist, extend if so):
8. `test_ArcaneRebound_Reflection_CalculatesReflectedDamage` -- verify reflected damage integrates with DamageCalculator
9. `test_ArcaneRebound_StateCategory_UsesCorrectState` -- verify SpellReflection state (or equivalent) is used correctly

**ExecutionFlowSkill Tests** (`Tests/Character/Skill/Support/ExecutionFlowSkillTest.cs` -- may already exist, extend if so):
10. `test_ExecutionFlow_SkillIntegration_AffectsCooldowns` -- verify skill system integration modifies cooldowns correctly

**FrostFocusSkill Tests** (`Tests/Character/Skill/Upgrade/FrostFocusSkillTest.cs` -- check if exists):
11. `test_FrostFocus_StatusEffectIntegration_DetectsFrozenState` -- verify frozen/slow state detection works through StateMachine
12. `test_FrostFocus_Activation_AppliesBonusOnFrozenTarget` -- verify damage bonus applies when target is in frozen state

**Part 2: Bulk Skill Activation Smoke Test**

Create a systematic test that verifies all 121 skill implementations can be activated without throwing exceptions. This is a regression safety net for the MagePlayerController refactoring (Story 002 Part 2).

**Test: `SkillActivationSmokeTest.cs`** in `Assets/Trizzle/Tests/Character/Skill/`:
13. `test_AllSkills_Activate_NoExceptions` -- for each skill ScriptableObject in `Assets/Trizzle/Data/Skill/`, call `Activate()` with a mock `ICharacter` and verify no exception is thrown
14. `test_AllSkills_Deactivate_NoExceptions` -- for each skill, call `Activate()` then `Deactivate()` and verify clean teardown
15. `test_SharedSkills_Activate_WithNonMageCharacter` -- activate shared skills with a mock character that is NOT MagePlayerController (simulating Archer) and verify no `InvalidCastException` (validates F-010 compliance)

**Test patterns:**
- Use Moq to create mock `ICharacter` / `PlayerController` instances
- Use `ScriptableObject.CreateInstance<T>()` for test skill instances (no disk I/O)
- Load skill SOs from `Assets/Trizzle/Data/Skill/` for bulk tests using `Resources.LoadAll` or `AssetDatabase.FindAssets` (EditMode)
- All tests must be deterministic and independent
- Extend existing test files where they exist (106 test files already present) rather than creating duplicates

## Acceptance Criteria

- [ ] All 15+ test cases listed above are implemented and passing
- [ ] CurseBreakerSkill debuff detection tests verify real StateMachine integration (not placeholder false returns)
- [ ] BloodBondSkill tests verify real DamageCalculator and Health system integration
- [ ] ArcaneReboundSkill tests verify real damage reflection calculation
- [ ] Bulk activation test covers all 121 skill ScriptableObject assets without exceptions
- [ ] Shared skill activation test with non-Mage character throws no InvalidCastException (F-010 validation)
- [ ] All 106 existing skill tests still pass (regression check)
- [ ] Tests use NUnit + Moq per project testing standards
- [ ] Tests are in `Assets/Trizzle/Tests/Character/Skill/` within the `TrizzleUnitTests.asmdef` assembly
- [ ] All tests are deterministic and independent (no execution order dependency)
- [ ] Tests run successfully via `Unity -batchmode -quit -projectPath . -runTests -testPlatform EditMode -testFilter "Skill"`
- [ ] Zero TODO/FIXME/placeholder matches remain in `Assets/Trizzle/Scripts/Character/Skill/` (final grep verification)

## Test Evidence

**Type**: Unit Test (self-referential -- this IS the test story)
**Path**: `Assets/Trizzle/Tests/Character/Skill/`

- CI output: all tests green
- Test report: `results.xml` from Unity Test Runner
- Grep output: zero matches for `TODO|FIXME|placeholder` in skill directory

## Dependencies

- **Blocked by**: 002-complete-skill-implementations (code fixes must exist to test), 003-create-missing-prefabs (prefab-dependent skills need prefabs wired for full activation testing)
- **Blocks**: None (this is the validation gate for the epic)

## Engine Notes

Tests use Unity Test Framework (NUnit) with Moq, per project testing standards in `CLAUDE.md`. The `TrizzleUnitTests.asmdef` assembly in `Assets/Trizzle/Tests/` is the test assembly. Use `[Test]` attribute for NUnit test methods. `ScriptableObject.CreateInstance<T>()` creates runtime instances without asset files -- suitable for EditMode tests. For bulk skill loading, use `AssetDatabase.FindAssets("t:BaseSkill")` in EditMode tests. Moq can create `Mock<ICharacter>()` and `Mock<PlayerController>()` for activation tests -- verify Moq can mock the specific types used (MonoBehaviours may need interface-based mocking).
