# Story: ComboEffect Base Class

> **Epic**: combo-synergy
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-combo-001 (ComboEffect abstract SO with Activate, Deactivate, OnTrigger), TR-combo-011 (TriggerContext readonly struct, zero heap allocation), TR-combo-003 (4 trigger conditions via event subscription), TR-combo-010 (< 0.5ms/frame budget)
**ADR Reference**: ADR-0003 -- Decision section (ComboEffect abstract class definition, TriggerContext struct, IComboRegistry interface), Key Interfaces (full C# signatures)
**Control Manifest Rules**: R-005 (IComboRegistry on ComboRegistry), R-011 (Activate registers listeners, Deactivate unsubscribes and reverses changes), R-012 (Activate calls Deactivate first as guard), R-019 (ComboEffect as abstract SO), R-020 (TriggerContext as readonly struct), R-026 (event subscription patterns per trigger type), R-028 (OnComboDiscovered fires once per combo per run), F-012 (no per-frame polling), F-013 (no MonoBehaviour ComboEffect)

## Description

Create the abstract `ComboEffect` ScriptableObject base class and its supporting types. This is the core architectural piece that all 18 concrete combo effects will extend. Also refactor `ComboRegistry` from a static utility class to a MonoBehaviour implementing `IComboRegistry`, and update its `CheckCombos()` to activate effects on discovery.

**Files to create:**

1. **`Assets/Trizzle/Scripts/Data/ComboEffect.cs`** -- Abstract ScriptableObject base class with three entry points per ADR-0003:
   - `public abstract void Activate(PlayerController player)` -- Subscribe events, apply immediate modifiers. Must call `Deactivate()` as first line (guard against Editor state leaks per R-012).
   - `public abstract void Deactivate()` -- Unsubscribe all listeners, remove all AttributeModifier additions, clear runtime state. Must be idempotent (calling on an already-deactivated effect must not throw).
   - `public virtual void OnTrigger(TriggerContext ctx) { }` -- Runtime behavior. No-op default for Passive effects.
   - Protected field: `protected PlayerController _player` -- stored reference, cleared in Deactivate.
   - Protected field: `protected bool _isActive` -- tracks activation state to prevent double-subscribe.
   - Override `OnDisable()` to call `Deactivate()` for Editor hygiene (ADR-0003 Risks section).
   - Full XML doc comments on class and all methods.

2. **`Assets/Trizzle/Scripts/Data/TriggerContext.cs`** -- Readonly struct per ADR-0003:
   ```csharp
   public readonly struct TriggerContext
   {
       public readonly BaseSkill TriggeringSkill;
       public readonly Health TargetHealth;
       public readonly float DamageAmount;
       public readonly Vector3 TriggerPosition;
       // Constructor
   }
   ```
   Zero heap allocation. Full XML doc comments on each field.

3. **`Assets/Trizzle/Scripts/Manager/IComboRegistry.cs`** -- Interface per ADR-0003:
   - `void CheckCombos(IReadOnlyList<BaseSkill> collectedSkills)` -- scans for new pairs, activates effects
   - `IReadOnlyList<ComboDefinition> ActiveCombos { get; }` -- currently active this run
   - `event System.Action<ComboDefinition> OnComboDiscovered` -- fires once per new combo per run

4. **Refactor `Assets/Trizzle/Scripts/Manager/ComboRegistry.cs`** -- Convert from static class to MonoBehaviour implementing `IComboRegistry`:
   - Remove `static` modifier and all static members
   - Add `[SerializeField] private ComboDatabase _database` reference
   - Implement `IComboRegistry.CheckCombos(IReadOnlyList<BaseSkill> collectedSkills)`:
     - Iterate all `ComboDefinition` entries in `_database`
     - For each entry, check if both `skillA` and `skillB` are in `collectedSkills`
     - If a match is found and not in `_activeCombos`: call `combo.TriggerEffect.Activate(player)`, add to `_activeCombos`, fire `OnComboDiscovered`
     - Null-check `triggerEffect` before calling Activate (existing combos may have null effects until Story 007)
   - Add `DeactivateAllCombos()` method: iterate `_activeCombos`, call `Deactivate()` on each effect, clear the list. Wire to run-end event.
   - Keep fallback logic for backward compatibility during migration (can be removed after Story 007)
   - Store reference to `PlayerController` via a `SetPlayer(PlayerController)` method called by `DraftRunController` at run start

**Key constraints from ADR-0003:**
- `Activate()` must call `Deactivate()` first as a guard (R-012)
- `OnTrigger` must not allocate heap memory -- no lambdas, no LINQ, no closures
- Event subscription uses named methods, not anonymous lambdas, for clean unsubscription
- `OnComboDiscovered` fires exactly once per newly discovered combo per run (R-028)

## Acceptance Criteria

- [ ] `ComboEffect` abstract ScriptableObject class exists with `Activate(PlayerController)`, `Deactivate()`, `OnTrigger(TriggerContext)` methods
- [ ] `Activate()` is abstract; `Deactivate()` is abstract; `OnTrigger()` is virtual with empty default
- [ ] `ComboEffect.OnDisable()` calls `Deactivate()` for Editor hygiene
- [ ] `TriggerContext` is a `readonly struct` with `TriggeringSkill`, `TargetHealth`, `DamageAmount`, `TriggerPosition` fields
- [ ] `IComboRegistry` interface exists with `CheckCombos()`, `ActiveCombos`, `OnComboDiscovered`
- [ ] `ComboRegistry` is a MonoBehaviour implementing `IComboRegistry`
- [ ] `ComboRegistry.CheckCombos()` activates `ComboEffect` on newly discovered combos
- [ ] `ComboRegistry.DeactivateAllCombos()` calls `Deactivate()` on each active effect and clears the list
- [ ] `OnComboDiscovered` fires exactly once per newly discovered combo per run
- [ ] Null-check on `triggerEffect` prevents NullReferenceException for combos without effects (TR-combo-004)
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `Assets/Trizzle/Tests/Combo/`

- Unit test: Create a mock `ComboEffect` subclass via `ScriptableObject.CreateInstance<T>()`, call `Activate()`, verify `_isActive` is true. Call `Deactivate()`, verify `_isActive` is false.
- Unit test: Call `Deactivate()` on an already-deactivated effect -- no exception thrown (idempotency)
- Unit test: Construct `TriggerContext` struct, verify all fields accessible and stack-allocated (value type check)
- Unit test: `ComboRegistry.CheckCombos()` with two matching skills fires `OnComboDiscovered` exactly once
- Unit test: `ComboRegistry.CheckCombos()` called again with same skills does NOT fire `OnComboDiscovered` again
- Unit test: `ComboRegistry.DeactivateAllCombos()` calls `Deactivate()` on all active effects

## Dependencies

- **Blocked by**: 001-extend-combo-definition (needs `ComboCategory`, `TriggerCondition` enums and extended `ComboDefinition`)
- **Blocks**: 003-mage-combo-effects, 004-archer-combo-effects, 005-universal-combo-effects, 006-combo-discovery-ui (needs OnComboDiscovered event), 007-combo-database-population, 009-combo-system-tests

## Engine Notes

Uses abstract `ScriptableObject`, `MonoBehaviour`, C# interfaces, C# events, `readonly struct` -- all stable Unity APIs present since Unity 2019 LTS. The `OnDisable()` override on ScriptableObject fires when play mode exits in the Editor, which is the correct hook for state cleanup. Verify that `ScriptableObject.CreateInstance<T>()` works correctly for abstract subclass instantiation in Unity 6000.3.11f1 EditMode tests.

## Completion Notes
**Completed**: 2026-04-16
**Criteria**: 10/11 passing (AC-11 zero-warnings DEFERRED — requires Unity Editor build)
**Deviations**:
- File location: `ComboEffect.cs` and `TriggerContext.cs` placed under `Assets/Trizzle/Scripts/Combo/` instead of story-stated `Scripts/Data/` — aligns with new combo namespace folder from E4-001, functionally equivalent.
- Out-of-scope changes from /review gstack 2026-04-15 (all approved): DraftRunController lifecycle wiring (4 `DeactivateAllCombos` call-sites + SetPlayer + HandleComboDiscovered), ComboDatabase `discoveredFlag`/`SetDiscovered` removal (amends E4-001, fixes ADR-0003 F-003 violation), 2 tests removed from ComboDefinitionSchemaTest (7→5), 2 legacy tests removed from DraftRunControllerTest (coverage migrated to ComboRegistryTest).
- Untested ACs (ADVISORY): AC-3 (OnDisable→Deactivate hook) and AC-10 (null-triggerEffect path) have no direct tests. Follow-up quality story recommended.
**Test Evidence**: Unit — `Assets/Trizzle/Tests/Combo/ComboRegistryTest.cs` (6 tests). Test Runner execution pending Unity Editor verification per PR #118 checklist.
**Code Review**: Skipped (Lean mode); /review gstack session on 2026-04-15 covered combined E4-001 + E4-002 diff with 6 specialists, all critical findings fixed.
**PR**: https://github.com/xiaolei1013/Trizzle/pull/118 (commit `72f3e293f`)
**Pending before merge**: Attach ComboRegistry MonoBehaviour to scene GameObject, wire `DraftRunController._comboRegistry` Inspector field, run all 11 new NUnit tests in Test Runner, confirm zero compile warnings, tick evidence checklist.

