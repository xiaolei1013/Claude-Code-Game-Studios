# Manual Verification: E4-001 Extend ComboDefinition

**Story**: `production/epics/combo-synergy/001-extend-combo-definition.md`
**Date**: PENDING
**Type**: Logic — Manual asset-compat verification (AC-8)
**Verifier**: PENDING

## Why this exists

Acceptance criterion AC-8 — "Existing `ComboDatabase.asset` loads without errors (null/default values for new fields are acceptable)" — cannot be verified by the NUnit suite at `Assets/Trizzle/Tests/Combo/ComboDefinitionSchemaTest.cs`. The test assembly runs in a non-Editor context and does not invoke Unity's asset-deserialization pipeline against `ComboDatabase.asset`. This checklist captures the equivalent manual verification.

## Checklist

- [ ] Unity project opens in `6000.3.11f1` with no new console errors or warnings (Clear console first, then open the project).
- [ ] Compile passes with zero warnings after the E4-001 changes land (`Console → Clear → Recompile`).
- [ ] Locate `Assets/Trizzle/Data/ComboDatabase.asset` (or wherever the project stores it — search for `t:ComboDatabase` in the Project window if path is different).
- [ ] Select the `ComboDatabase.asset`. The Inspector shows the `Combos` list with its 5 pre-existing Mage entries intact.
- [ ] Expand a pre-existing `ComboDefinition` entry in the Inspector. Confirm the 4 new fields appear with default values:
  - [ ] `Combo Category` = `Mage` (enum zero — acceptable default)
  - [ ] `Trigger Condition` = `OnDraft` (enum zero — acceptable default)
  - [ ] `Trigger Effect` = `None (Combo Effect)` (null reference — acceptable default)
  - [ ] `Discovered Flag` = unchecked (false — acceptable default)
- [ ] Existing fields on each ComboDefinition (`skillA`, `skillB`, `comboName`, `description`) are still populated with their original values — **no data loss**.
- [ ] Edit one new field (e.g., change `Combo Category` from Mage to Archer on a test entry), save, close, and re-open the asset — confirm the change persists (round-trip serialization works).
- [ ] Revert the test edit (set the field back to Mage), save — no dirty state remains after save.
- [ ] Run the Test Runner → `Trizzle.Tests.Combo.ComboDefinitionSchemaTest` → all 7 tests pass (6 original + the new `SetDiscovered_IsIdempotent` from suggestion #1).

## Expected outcome

All 9 checkboxes ticked ✓ + zero console errors ⇒ AC-8 verified.
Any checkbox failing ⇒ block `/story-done` and investigate (most likely cause: Unity asset upgrade issue on the `ComboEffect` abstract type reference — would require `[SerializeReference]` fallback, not expected for SO refs).

## Notes

The Inspector auto-labels new fields from their private-field names (e.g., `comboCategory` → "Combo Category"). No `[Tooltip]` or `[Header]` attributes were added in this story to match the pre-existing `ComboDefinition` field style.
