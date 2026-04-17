# Story: Extend ComboDefinition

> **Epic**: combo-synergy
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
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

## Completion Notes

**Completed**: 2026-04-15
**Branch**: `feature/e4-001-extend-combo-definition` (in Trizzle Unity project repo at `/Users/xiaolei/work/Trizzle/`)
**Verdict**: COMPLETE WITH NOTES

### 2026-04-15 Amendment — `discoveredFlag` + `SetDiscovered()` removed

During E4-002 adversarial review (gstack `/review` on 2026-04-15), Codex + Claude adversarial both flagged that AC-6's `discoveredFlag` + `SetDiscovered()` directly contradict ADR-0003 forbidden pattern F-003 (no runtime writes to SO assets). In the Unity Editor, `SetDiscovered()` would persist the flag across Play sessions, pre-marking every combo as discovered on the second Play press -- silently breaking the combo discovery loop.

**Resolution**: removed both `discoveredFlag` field and `SetDiscovered()` method from `ComboDefinition`. Per-save discovery persistence is owned by save data (E4-008), keyed by combo name. AC-6's requirement for these members was mis-specified; the registry entry `discovered_combos` (save-data-system owner) remains valid.

**AC-6 status**: superseded -- `ComboDefinition` has a `discoveredFlag` field → should have been "Discovery persistence is tracked by save data, not on the SO".

**Criteria**: 7/9 auto-verified, 2/9 deferred to manual Unity Editor verification (AC-8 asset load, AC-9 zero warnings). Deferred checks tracked in `production/qa/evidence/e4-001-extend-combo-definition.md`.

**Files changed**:
- `Assets/Trizzle/Scripts/Data/ComboDatabase.cs` (modified) -- extended `ComboDefinition` with 4 fields + `SetDiscovered()`
- `Assets/Trizzle/Scripts/Data/ComboCategory.cs` (new) -- enum `{ Mage, Archer, Universal }`
- `Assets/Trizzle/Scripts/Data/TriggerCondition.cs` (new) -- enum `{ OnDraft, OnSkillUse, OnKill, Passive }`
- `Assets/Trizzle/Scripts/Combo/ComboEffect.cs` (new, scope extension) -- empty abstract SO stub; full lifecycle deferred to Story E4-002 per ADR-0003
- `Assets/Trizzle/Tests/Combo/ComboDefinitionSchemaTest.cs` (new) -- 7 NUnit tests covering enum shape, ComboDefinition defaults, and SetDiscovered semantics (incl. idempotence)

**Deviations**:
- Scope extension: `ComboEffect.cs` stub created outside story's stated file list. Architecturally required by ADR-0003 for `triggerEffect` field type reference to compile. E4-002 owns the full lifecycle contract (Activate/Deactivate/OnTrigger). Not logged as tech debt -- documented in the stub's `<remarks>` block.

**Test Evidence**: `Assets/Trizzle/Tests/Combo/ComboDefinitionSchemaTest.cs` (7 tests); manual checklist at `production/qa/evidence/e4-001-extend-combo-definition.md` (AC-8 / AC-9 PENDING user walkthrough before branch merge)

**Code Review**: Manual `/code-review` run — APPROVED WITH SUGGESTIONS; both suggestions (idempotence test + manual verification doc) applied before sign-off. `/simplify` pass also applied: `[Serializable]` removed from enums, rotting "E4-007" history trimmed from docs + tests, failure messages added to `Enum.IsDefined` asserts. Director-gate phases (QL-TEST-COVERAGE, LP-CODE-REVIEW) skipped per `lean` review mode.

**Follow-up required before branch merge**:
1. Open Unity Editor → Test Runner → verify all 7 tests pass
2. Walk through the 9-item checklist in `production/qa/evidence/e4-001-extend-combo-definition.md`, tick each box, fill in date + verifier
3. Confirm `ComboDatabase.asset` opens with zero console errors (AC-8), zero compile warnings (AC-9)
