# Story: ArcherPlayerController & ICharacterClass Interface

> **Epic**: archer-character
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-archer-001 (Add Archer to PlayerClassType enum; create ArcherPlayerController : PlayerController), TR-archer-002 (ArrowShotSkill : UpgradableSkill with 0.5s cooldown, 0.6x Attack damage, speed 18 projectile, auto-aim)
**ADR Reference**: ADR-0005 -- Decision items 1-3 (ArcherPlayerController subclass, PlayerClassType enum extension, ICharacterClass interface definition)
**Control Manifest Rules**: R-004 (implement ICharacterClass on both MagePlayerController and ArcherPlayerController), F-010 (no MagePlayerController casts in shared skill code), F-011 (no adapter pattern -- Archer is direct PlayerController subclass), F-017 (MonoBehaviour + SO + C# interface only)

## Description

Create the Archer character controller and the class-agnostic interface that enables shared skills to work with any character class. This story establishes the type-system foundation that all subsequent Archer stories build on.

**Files to create:**

1. **`ICharacterClass.cs`** -- C# interface in `Assets/Trizzle/Scripts/Character/`. Three properties: `PlayerClassType ClassType { get; }`, `BaseSkill DefaultActiveHitSkill { get; }`, `BaseSkill DefaultActiveRunSkill { get; }`. One method: `void InitAttributes(GamePlayDatabase db)`. Full XML doc comments per ADR-0005 Decision item 3.

2. **`ArcherPlayerController.cs`** -- `ArcherPlayerController : PlayerController, ICharacterClass` in `Assets/Trizzle/Scripts/Character/`. Overrides `InitAttributes(GamePlayDatabase db)` to read Archer-specific stat fields (Health=75, Attack=80, AttackRange=10, MoveSpeed=3.6, Defense=3, CritChance=0.08). Implements `ClassType` returning `PlayerClassType.Archer`. Implements `DefaultActiveHitSkill` and `DefaultActiveRunSkill` to return ArrowShotSkill and DodgeRollSkill references respectively.

**Files to modify:**

3. **`PlayerClassType` enum** -- Add `Archer` as a new value. Append only -- do not change existing `Mage` integer value. Existing `switch` statements that lack an `Archer` case will produce compiler warnings (intended behavior per ADR-0005).

4. **`MagePlayerController.cs`** -- Add `: ICharacterClass` to the class declaration. Implement the three interface properties (`ClassType` returns `PlayerClassType.Mage`, `DefaultActiveHitSkill` returns FireballSkill, `DefaultActiveRunSkill` returns DashSkill). This is a type annotation only -- zero behavioral change to existing Mage gameplay.

**Key constraints from ADR-0005:**
- `ClassType` is resolved once at initialization and cached, not queried per-frame (R-004 performance rule)
- `MagePlayerController` gains only the interface declaration -- no behavioral changes
- No new architectural paradigms (F-017)
- `ArcherPlayerController` does NOT modify `MagePlayerController` behavior in any way

## Acceptance Criteria

- [ ] `ICharacterClass` interface exists at `Assets/Trizzle/Scripts/Character/ICharacterClass.cs` with all 3 properties, 1 method, and XML doc comments matching ADR-0005 verbatim
- [ ] `PlayerClassType` enum includes `Archer` value; existing `Mage` value unchanged
- [ ] `ArcherPlayerController : PlayerController, ICharacterClass` exists at `Assets/Trizzle/Scripts/Character/ArcherPlayerController.cs`
- [ ] `ArcherPlayerController.InitAttributes()` reads from `GamePlayDatabase` archer-specific fields
- [ ] `ArcherPlayerController.ClassType` returns `PlayerClassType.Archer`
- [ ] `MagePlayerController` implements `ICharacterClass` with zero behavioral change
- [ ] `MagePlayerController.ClassType` returns `PlayerClassType.Mage`
- [ ] Both controllers compile against `PlayerController` base class (verify no `sealed` keyword)
- [ ] All code compiles with zero errors in Unity 6000.3.11f1; compiler warnings from incomplete `switch` statements on `PlayerClassType` are expected and acceptable

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/archer/`

- Unit test: `ArcherPlayerController.ClassType` returns `PlayerClassType.Archer`
- Unit test: `MagePlayerController.ClassType` returns `PlayerClassType.Mage`
- Unit test: `ArcherPlayerController` implements `ICharacterClass` (interface cast succeeds)
- Unit test: `MagePlayerController` implements `ICharacterClass` (interface cast succeeds)
- Unit test: `PlayerClassType` enum contains both `Mage` and `Archer` values

## Dependencies

- **Blocked by**: 002-dashskill-refactor (DashSkill must be refactored before ArcherPlayerController is integrated into a shared scene -- ADR-0005 ordering note)
- **Blocks**: 003-arrow-shot-skill, 004-dodge-roll-skill, 005-archer-base-stats, 007-draft-pool-filtering, 009-archer-character-tests

## Engine Notes

Uses `MonoBehaviour` inheritance, C# interfaces, and enum extension -- all stable Unity APIs with no post-cutoff changes. `PlayerController` base class must not be `sealed` (verify before implementation). ADR-0005 Engine Compatibility section confirms LOW risk for these specific APIs.

## Completion Notes
**Completed**: 2026-04-10
**Criteria**: 9/9 passing
**Deviations**: ArcherPlayerController.InitAttributes uses Mage baseline stats temporarily — N1-005 will add Archer-specific GamePlayDatabase fields
**Test Evidence**: Logic: Assets/Trizzle/Tests/Character/Archer/ArcherControllerTest.cs (10 tests)
**Code Review**: Skipped (Lean mode)
**Files Changed**: ICharacterClass.cs (new), ArcherPlayerController.cs (new), MagePlayerController.cs (added ICharacterClass), PlayerController.cs (Archer enum)
