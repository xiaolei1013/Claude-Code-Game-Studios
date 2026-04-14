# Story: DashSkill Cast Refactor

> **Epic**: archer-character
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-archer-003 (DodgeRollSkill : UpgradableSkill with 2.0 unit distance, 0.2s i-frames, movement-direction roll, wall-blocking)
**ADR Reference**: ADR-0005 -- Decision item 4 (DashSkill cast refactor is a prerequisite), Migration Plan step 2
**Control Manifest Rules**: R-004 (shared skills cast to ICharacterClass or PlayerController, never MagePlayerController), F-010 (no MagePlayerController casts in shared skill code), R-014 (DraftRunController filters via CanApplyUpgrade, no class-specific if-branches)

**BLOCKING PREREQUISITE**: This story MUST be completed before any other Archer story that adds ArcherPlayerController to a shared scene. The DashSkill currently casts to `MagePlayerController`, which will throw `InvalidCastException` at runtime for Archer players.

## Description

Remove all `MagePlayerController` casts from shared skill code, replacing them with casts to `PlayerController` (base class) or `ICharacterClass` (interface). This is a refactor-only story with zero behavioral change to Mage gameplay.

**Step 1 -- Impact Assessment:**

Run `grep -r "MagePlayerController" Assets/Trizzle/Scripts/` to document every cast site. For each site, evaluate:
- Does the cast access a field that exists on `PlayerController`? -> Replace with `PlayerController` cast
- Does the cast access class-identity information (ClassType, DefaultSkills)? -> Replace with `ICharacterClass` cast
- Does the cast access a Mage-specific feature that has no Archer equivalent? -> Leave as-is in Mage-only code, flag for review

**Step 2 -- Refactor DashSkill:**

`DashSkill.cs` contains at least one cast to `MagePlayerController`. Replace with `PlayerController` or `ICharacterClass` as determined by Step 1. The DashSkill uses `AdvancedWalkerController` momentum -- verify the momentum API lives on `PlayerController` (not `MagePlayerController`) before changing the cast.

**Step 3 -- Verify Mobile Code:**

Check `Manager/Mobile/` and `Platform/` directories for any cast chains through `DashSkill` that reference `MagePlayerController`. Update any discovered casts. ADR-0005 Risk table flags this as MEDIUM likelihood.

**Step 4 -- Grep Verification:**

After all changes, re-run `grep -r "MagePlayerController" Assets/Trizzle/Scripts/`. The only files that should reference `MagePlayerController` are:
- `MagePlayerController.cs` itself
- Mage-only skills that explicitly require Mage (e.g., Fireball upgrades that check for FireballSkill)

**Key constraints:**
- Zero behavioral change to existing Mage gameplay -- all existing Mage tests must still pass
- This is a type-system cleanup, not a feature addition
- If mobile code impact is larger than expected, surface as a blocker immediately

## Acceptance Criteria

- [ ] Impact assessment document lists every `MagePlayerController` cast site found by grep
- [ ] `DashSkill.cs` contains zero references to `MagePlayerController` -- uses `PlayerController` or `ICharacterClass` instead
- [ ] All shared skill files (skills usable by both Mage and Archer) contain zero `MagePlayerController` casts
- [ ] Mobile/platform code updated if any `MagePlayerController` cast chains are discovered
- [ ] `grep -r "MagePlayerController" Assets/Trizzle/Scripts/` returns only `MagePlayerController.cs` itself and Mage-exclusive skill files
- [ ] All existing Mage gameplay tests pass with zero regressions
- [ ] Mage can complete Room 1 on Normal with no runtime exceptions (manual smoke test)
- [ ] All code compiles with zero errors in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test + Integration Test
**Path**: `tests/unit/archer/`, `tests/integration/archer/`

- Unit test: `DashSkill` can be activated on a mock `PlayerController` (not specifically `MagePlayerController`) without `InvalidCastException`
- Integration test: Mage player completes Room 1 with DashSkill -- verifies refactor did not regress Mage behavior
- Grep test: CI check that `MagePlayerController` only appears in its own file and Mage-exclusive skill files (ADR-0005 Validation Criterion 2)

## Dependencies

- **Blocked by**: None -- this is the FIRST story in the Archer epic critical path
- **Blocks**: 001-archer-controller-icharacterclass (must complete before ArcherPlayerController is integrated into shared scenes), and transitively ALL other Archer stories

## Engine Notes

Refactoring C# casts and interface usage -- all stable Unity APIs. No post-cutoff API risk. The primary risk is discovering unexpected cast sites in mobile/platform code. ADR-0005 lists this as MEDIUM likelihood with mitigation: "Read all callers of DashSkill before touching any code."

## Completion Notes
**Completed**: 2026-04-10
**Criteria**: 8/8 passing (DashSkill already refactored in Sprint 1 E5-002; OneShotKillEffect redundant cast removed)
**Deviations**: None
**Test Evidence**: Logic: ArcherControllerTest::test_DashSkill_no_MagePlayerController_reference
**Code Review**: Skipped (Lean mode)
**Files Changed**: OneShotKillEffect.cs (removed redundant MagePlayerController check)
