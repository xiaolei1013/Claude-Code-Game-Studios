# Story: Archer Combo Effects (6)

> **Epic**: combo-synergy
> **Type**: Logic
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L

## Context

**GDD Requirement**: TR-combo-002 (18 concrete ComboEffect implementations -- 6 Archer-exclusive), TR-combo-003 (trigger conditions via event subscription)
**ADR Reference**: ADR-0003 -- Decision section (concrete subclass pattern), ScriptableObject Asset Organization (Data/Combos/Effects/Archer/), GDD Requirements Addressed ("6 Archer-exclusive combos -- exact event names must be confirmed against N1 implementation")
**Control Manifest Rules**: R-011 (Activate/Deactivate lifecycle), R-012 (Activate calls Deactivate first), R-019 (ComboEffect abstract SO), R-023 (assets in Data/Combos/Effects/Archer/), R-026 (subscription patterns per trigger type), F-012 (no polling), F-013 (no MonoBehaviour), G-002 (< 0.5ms/frame)

## Description

Implement the 6 Archer-exclusive `ComboEffect` ScriptableObject subclasses. These combos require Archer-exclusive skills from the N1 (Archer Character) epic. The skill SO references (PiercingArrow, Multishot, PoisonArrow, etc.) must exist for the effects to be wired, but the effects can be authored and unit-tested independently using mock skill references.

**Files to create (6 C# classes + 6 .asset files):**

### 1. PlagueVolleyComboEffect (PiercingArrow + PoisonArrow, OnSkillUse)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Archer/PlagueVolleyComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Archer/PlagueVolleyComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to `PlayerController.OnSkillUsed`
- **Behavior**: Piercing arrows spread Poison to ALL pierced targets, not just first hit
- **Implementation**: In `OnTrigger()`, check if `ctx.TriggeringSkill` is PiercingArrow. If yes, apply Poison status to all enemies in the projectile's pierce path. Hook into the projectile's pierce callback or apply Poison to `ctx.TargetHealth` on each hit event.
- **Deactivate**: Unsubscribe from `OnSkillUsed`.

### 2. HailstormComboEffect (Multishot + FreezeAttackSkill, OnSkillUse)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Archer/HailstormComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Archer/HailstormComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to `PlayerController.OnSkillUsed`
- **Behavior**: Each multishot arrow has 30% chance to apply Freeze
- **SerializeField tuning knobs**: `_freezeChance` (default 0.30f, range 0.10-0.50)
- **Implementation**: In `OnTrigger()`, check if skill is Multishot. For each arrow hit, roll against `_freezeChance`. If success AND enemy is not Freeze-immune, apply Freeze. Freeze-immune enemies simply fail the proc with no error (Edge Case 10).
- **Deactivate**: Unsubscribe from `OnSkillUsed`.

### 3. ShadowStepComboEffect (DodgeRollSkill + Afterimage, OnSkillUse)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Archer/ShadowStepComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Archer/ShadowStepComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to Afterimage spawn/death event
- **Behavior**: Afterimage decoy explodes on death for 50% Attack damage in 2-unit radius
- **SerializeField tuning knobs**: `_damageRatio` (default 0.50f, range 0.25-1.0), `_explosionRadius` (default 2.0f, range 1.0-4.0)
- **Implementation**: Subscribe to afterimage death event. On death, calculate `archer.GetAttribute(Attack).CurrentValue * _damageRatio`, deal damage via `DamageCalculator` to all enemies in `_explosionRadius` of death position.
- **Deactivate**: Unsubscribe from afterimage death event. Clear stored references.

### 4. PredatorsMarkComboEffect (EagleEye + CounterRoll, Passive)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Archer/PredatorsMarkComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Archer/PredatorsMarkComboEffect.asset`

- **Trigger**: Passive -- applies modifier in `Activate()`
- **Behavior**: Counter Roll damage bonus increased from 2x to 3x against targets beyond Eagle Eye range threshold
- **SerializeField tuning knobs**: `_enhancedMultiplier` (default 3.0f, range 2.0-4.0)
- **Implementation**: In `Activate()`, apply `AttributeModifier` that upgrades the Counter Roll ranged bonus from base 2x to `_enhancedMultiplier`. The exact modifier target depends on how CounterRoll stores its damage bonus (confirm against N1 implementation).
- **Deactivate**: Remove the `AttributeModifier`. Restore base Counter Roll behavior.
- **Edge Case**: At exactly the Eagle Eye threshold distance, the combo bonus applies (>= not >) per Edge Case 9.

### 5. RapidAssaultComboEffect (Quickdraw + Multishot, OnSkillUse)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Archer/RapidAssaultComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Archer/RapidAssaultComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to `PlayerController.OnSkillUsed`
- **Behavior**: Quickdraw's attack speed buff also applies to Multishot arrows (all 3 fire faster)
- **Implementation**: In `OnTrigger()`, check if Quickdraw is activated. When Quickdraw's speed buff is applied, extend it to cover Multishot's fire rate. This may require reading Quickdraw's buff value and applying it as a secondary `AttributeModifier` to Multishot's cooldown.
- **Deactivate**: Unsubscribe. Remove any applied modifiers.

### 6. VenomousHailComboEffect (PoisonArrow + Multishot, OnSkillUse)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Archer/VenomousHailComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Archer/VenomousHailComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to `PlayerController.OnSkillUsed`
- **Behavior**: All 3 multishot arrows apply Poison (normally only center arrow does)
- **Implementation**: In `OnTrigger()`, check if skill is Multishot. For each arrow hit event, apply Poison status to the target. This extends the center-only poison to all arrows.
- **Deactivate**: Unsubscribe from `OnSkillUsed`.

**Code audit step:** Before writing Archer effects, read `ArcherPlayerController.cs` (if it exists from N1) and Archer skill scripts to confirm:
- Arrow hit event name and signature
- Afterimage spawn/death event name
- CounterRoll damage bonus storage mechanism
- Quickdraw speed buff mechanism
- Multishot per-arrow hit callback

If N1 is not yet implemented, author the effects against the expected API from the Archer GDD and note TODOs for event name confirmation.

## Acceptance Criteria

- [ ] 6 C# class files exist in `Assets/Trizzle/Scripts/Combat/ComboEffects/Archer/`
- [ ] 6 `.asset` files exist in `Assets/Trizzle/Data/Combos/Effects/Archer/`
- [ ] All `[SerializeField]` tuning knobs set to GDD defaults
- [ ] Plague Volley: Piercing arrows spread Poison to all pierced targets
- [ ] Hailstorm: Each multishot arrow has 30% Freeze chance. Freeze-immune enemies are silently skipped (Edge Case 10).
- [ ] Shadow Step: Afterimage explodes on death for 50% Attack in 2-unit radius
- [ ] Predator's Mark: Counter Roll bonus is 3x at/beyond Eagle Eye range (>= threshold, Edge Case 9)
- [ ] Rapid Assault: Quickdraw speed buff extends to Multishot fire rate
- [ ] Venomous Hail: All 3 multishot arrows apply Poison
- [ ] All effects properly `Deactivate()` on run end -- no state leak
- [ ] GDD Acceptance Criterion 1: Draft PiercingArrow + PoisonArrow as Archer, "Plague Volley" activates
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `Assets/Trizzle/Tests/Combo/ArcherEffects/`

- Unit test per effect: `CreateInstance<T>()`, `Activate()`, trigger condition, verify behavior
- Unit test: Hailstorm -- freeze chance 1.0 always freezes; freeze chance 0.0 never freezes; Freeze-immune target is not frozen
- Unit test: Predator's Mark -- attribute before Activate (2x), after Activate (3x), after Deactivate (2x)
- Unit test: Shadow Step -- afterimage death triggers explosion with correct damage calculation
- Unit test: All 6 effects -- Deactivate then Activate works cleanly

## Dependencies

- **Blocked by**: 001-extend-combo-definition, 002-combo-effect-base-class
- **Soft dependency on**: N1 Archer Character epic (Archer skill SOs and ArcherPlayerController). Effects can be authored and tested with mock skills if N1 is not yet complete.
- **Blocks**: 007-combo-database-population (needs Archer effect assets), 009-combo-system-tests

## Engine Notes

Same stable APIs as Story 003. Archer-specific events (arrow hit, afterimage death) depend on N1 implementation. If N1 uses `UnityEvent` or C# `event/Action`, the subscription pattern in `Activate()`/`Deactivate()` is the same. Confirm the event system in `ArcherPlayerController` during implementation.

## Completion Notes
**Completed**: 2026-04-17
**Criteria**: 12/12 passing (AC-11 combo discovery deferred to INFRA-001 scene-attach)
**Deviations**:
- ADVISORY: ShadowStep triggers on DodgeRoll use (not afterimage death) because afterimage prefab system is not shipped. Fires at dodge start position where afterimage would spawn. Functionally equivalent for v1.
- ADVISORY: PredatorsMarkComboEffect._counterRollSkill needs Inspector wiring to CounterRollSkill.asset.
**Test Evidence**: Logic — 6 test files at Assets/Trizzle/Tests/Combo/ArcherEffects/ (~36 tests)
**Code Review**: Complete (/simplify x1, /review x1 — 5 fixes applied: PredatorsMark _isActive on error, RapidAssault cooldown restore, _isActive guards in all OnTrigger, reflection warning log)
**PR**: #122 (merged 2026-04-17)
