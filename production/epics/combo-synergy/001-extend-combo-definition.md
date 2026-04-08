# Story: Extend ComboDefinition

> **Epic**: combo-synergy
> **Type**: Logic
> **Priority**: P0
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-combo-012 (ComboDefinition extended with comboCategory, triggerCondition, triggerEffect SO reference, discoveredFlag)
**ADR Reference**: ADR-0003 -- Decision section (ComboDefinition extended schema), Migration Plan step 3
**Control Manifest Rules**: R-019 (ComboEffect as abstract SO with three entry points), R-020 (TriggerContext as readonly struct), F-003 (no runtime writes to SO assets), F-012 (no per-frame polling), F-013 (no MonoBehaviour ComboEffect)

## Description

Extend the existing `ComboDefinition` class in `ComboDatabase.cs` with four new fields required by the combo-effect system. The current `ComboDefinition` stores only `skillA`, `skillB`, `comboName`, and `description`. The E4 architecture requires category filtering, trigger routing, effect asset references, and discovery tracking.

**Files to modify:**

1. **`Assets/Trizzle/Scripts/Data/ComboDatabase.cs`** -- Extend the existing `ComboDefinition` serializable class:
   - Add `[SerializeField] private ComboCategory comboCategory` with public getter. `ComboCategory` is a new enum: `Mage`, `Archer`, `Universal`.
   - Add `[SerializeField] private TriggerCondition triggerCondition` with public getter. `TriggerCondition` is a new enum: `OnDraft`, `OnSkillUse`, `OnKill`, `Passive`.
   - Add `[SerializeField] private ComboEffect triggerEffect` with public getter. This is a ScriptableObject reference to the concrete `ComboEffect` asset for this combo.
   - Add `[SerializeField] private bool discoveredFlag` with public getter and a `SetDiscovered()` method. Note: `discoveredFlag` on the SO is the Editor-time default; actual persistence is handled by save data (Story 008). The SO field exists for Inspector visibility only.
   - Add XML doc comments on all new fields describing their purpose and valid values.

2. **Create `Assets/Trizzle/Scripts/Data/ComboCategory.cs`** -- Enum file:
   ```
   public enum ComboCategory { Mage, Archer, Universal }
   ```

3. **Create `Assets/Trizzle/Scripts/Data/TriggerCondition.cs`** -- Enum file:
   ```
   public enum TriggerCondition { OnDraft, OnSkillUse, OnKill, Passive }
   ```

**Key constraints from ADR-0003:**
- `triggerEffect` will be null for the existing 5 Mage fallback entries until Story 007 populates ComboDatabase.asset. `ComboRegistry.CheckCombos()` already null-checks skill references; ensure null-check also covers `triggerEffect` before calling `Activate()`.
- The four new fields are additive -- existing serialized data in `ComboDatabase.asset` will default to enum-zero and null reference, which is safe.
- Do NOT modify the existing `CheckCombos()` or `GetComboName()` signatures in `ComboDatabase` -- those are extended in Story 004 (via ComboRegistry refactor).

## Acceptance Criteria

- [ ] `ComboCategory` enum exists with values `Mage`, `Archer`, `Universal`
- [ ] `TriggerCondition` enum exists with values `OnDraft`, `OnSkillUse`, `OnKill`, `Passive`
- [ ] `ComboDefinition` has `comboCategory` field of type `ComboCategory` with public getter
- [ ] `ComboDefinition` has `triggerCondition` field of type `TriggerCondition` with public getter
- [ ] `ComboDefinition` has `triggerEffect` field of type `ComboEffect` with public getter
- [ ] `ComboDefinition` has `discoveredFlag` field of type `bool` with public getter and `SetDiscovered()` method
- [ ] All new fields have `[SerializeField]` and XML doc comments
- [ ] Existing `ComboDatabase.asset` loads without errors (null/default values for new fields are acceptable)
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `Assets/Trizzle/Tests/Combo/`

- Unit test: Instantiate a `ComboDefinition` (via reflection or test helper), verify all 8 properties (4 existing + 4 new) are accessible and return expected defaults
- Unit test: `ComboCategory` enum has exactly 3 values
- Unit test: `TriggerCondition` enum has exactly 4 values

## Dependencies

- **Blocked by**: None -- this extends existing shipped code with additive fields
- **Blocks**: 002-combo-effect-base-class (needs `TriggerCondition` enum), 003-mage-combo-effects, 004-archer-combo-effects, 005-universal-combo-effects, 007-combo-database-population, 008-discovery-persistence, 009-combo-system-tests

## Engine Notes

Uses `[SerializeField]`, `[Serializable]`, and C# enums -- all stable Unity APIs with no post-cutoff changes. Adding serialized fields to an existing `[Serializable]` class is safe in Unity; existing asset data is preserved and new fields initialize to default values (enum 0, null reference, false).
