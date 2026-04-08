# Story: Mage Combo Effects (5)

> **Epic**: combo-synergy
> **Type**: Logic
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L

## Context

**GDD Requirement**: TR-combo-002 (18 concrete ComboEffect implementations -- 5 Mage-exclusive), TR-combo-003 (trigger conditions via event subscription)
**ADR Reference**: ADR-0003 -- Decision section (concrete subclass authoring pattern, InfernoComboEffect, BlizzardComboEffect, VenomComboEffect examples), ScriptableObject Asset Organization (Data/Combos/Effects/Mage/)
**Control Manifest Rules**: R-011 (Activate registers listeners, Deactivate reverses), R-012 (Activate calls Deactivate first), R-019 (ComboEffect as abstract SO), R-023 (combo effect assets in Data/Combos/Effects/Mage/), R-026 (OnSkillUse subscribes to PlayerController.OnSkillUsed, OnKill to Health.OnDied/OnEnemyKilled, Passive applies AttributeModifier), F-012 (no polling), F-013 (no MonoBehaviour), G-002 (< 0.5ms/frame combo budget)

## Description

Implement the 5 Mage-exclusive `ComboEffect` ScriptableObject subclasses. Each is a concrete C# class extending `ComboEffect` with a corresponding `.asset` file. These upgrade the existing 5 Mage fallback combos (currently name-only, no gameplay effect) into functional triggered effects.

**Files to create (5 C# classes + 5 .asset files):**

### 1. InfernoComboEffect (Fireball + BurnAttackSkill, OnSkillUse)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/InfernoComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Mage/InfernoComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to `PlayerController.OnSkillUsed` in `Activate()`
- **Behavior**: When Fireball or BurnAttack is used, spawn a burning ground patch at the target position
- **SerializeField tuning knobs**: `_burnDuration` (default 3.0f, range 1.0-6.0), `_burnTickInterval` (default 0.5f)
- **Implementation**: In `OnTrigger()`, check if `ctx.TriggeringSkill` is FireballSkill or BurnAttackSkill. If yes, call `SpawnManager` to spawn a ground-patch object at `ctx.TriggerPosition` with the configured duration and tick parameters.
- **Deactivate**: Unsubscribe from `OnSkillUsed`. Active ground patches despawn naturally on their timer.

### 2. BlizzardComboEffect (FrostShardSkill + FreezeAttackSkill, OnKill)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/BlizzardComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Mage/BlizzardComboEffect.asset`

- **Trigger**: OnKill -- subscribe to kill event in `Activate()`
- **Behavior**: When a frozen enemy dies, spawn a frost nova at death position (3-unit radius, applies Slow)
- **SerializeField tuning knobs**: `_frostNovaRadius` (default 3.0f, range 1.5-5.0)
- **Implementation**: In `OnTrigger()`, check if killed enemy had Frozen status at time of death via `StateMachine.HasState()`. If yes, `Physics2D.OverlapCircle()` at death position, apply Slow to all enemies in radius. If not frozen at death, no nova (Edge Case 8).
- **Deactivate**: Unsubscribe from kill event.

### 3. ThunderstrikeComboEffect (LightningBoltSkill + StunAttackSkill, OnSkillUse)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/ThunderstrikeComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Mage/ThunderstrikeComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to `PlayerController.OnSkillUsed`
- **Behavior**: Stunned enemies take 2x damage from Lightning attacks
- **SerializeField tuning knobs**: `_damageMultiplier` (default 2.0f, range 1.5-3.0)
- **Implementation**: In `OnTrigger()`, check if `ctx.TriggeringSkill` is LightningBoltSkill AND `ctx.TargetHealth` has Stun status. If yes, apply bonus damage via `DamageCalculator`.
- **Deactivate**: Unsubscribe from `OnSkillUsed`.

### 4. VenomComboEffect (PoisonCloudSkill + PoisonAttackSkill, Passive)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/VenomComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Mage/VenomComboEffect.asset`

- **Trigger**: Passive -- applies modifier in `Activate()`, no event subscription
- **Behavior**: Poison tick interval reduced from 1.0s to 0.67s (50% faster stacking)
- **SerializeField tuning knobs**: `_tickIntervalMultiplier` (default 0.67f, range 0.5-0.9)
- **Implementation**: In `Activate()`, call `AttributeModifier.Add()` for poison tick interval with multiply operation. Store the modifier reference for removal.
- **Deactivate**: Call `AttributeModifier.Remove()` with the stored modifier reference. Clear reference.

### 5. SupernovaComboEffect (SolarFlareSkill + ExplosionAttackSkill, OnKill)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/SupernovaComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Mage/SupernovaComboEffect.asset`

- **Trigger**: OnKill -- subscribe to kill event
- **Behavior**: 25% chance on kill to trigger secondary explosion (50% original damage, 4-unit radius)
- **SerializeField tuning knobs**: `_procChance` (default 0.25f, range 0.10-0.50), `_damageRatio` (default 0.50f, range 0.25-1.0), `_explosionRadius` (default 4.0f, range 2.0-6.0)
- **Implementation**: In `OnTrigger()`, roll against `_procChance`. If proc, spawn explosion at `ctx.TriggerPosition` with `ctx.DamageAmount * _damageRatio` damage in `_explosionRadius`. Use deterministic seed or pre-seeded RNG for testability.
- **Deactivate**: Unsubscribe from kill event.

**Code audit step (per ADR-0003 Consequences):** Before writing OnKill combos (Blizzard, Supernova), read `Health.cs` and `PlayerController.cs` to confirm the exact kill event name and signature. The ADR references `Health.OnDied` but the exact name must be verified against the shipped codebase.

**All concrete subclasses must:**
- Call `Deactivate()` as the first line of `Activate()` (R-012)
- Use named methods for event subscription, not anonymous lambdas (zero GC in OnTrigger)
- Not use LINQ or closures in `OnTrigger()` (ADR-0003 Risks)
- Leave the asset in a clean state after `Deactivate()` for reuse next run

## Acceptance Criteria

- [ ] 5 C# class files exist in `Assets/Trizzle/Scripts/Combat/ComboEffects/Mage/`
- [ ] 5 `.asset` files exist in `Assets/Trizzle/Data/Combos/Effects/Mage/`
- [ ] All `[SerializeField]` tuning knobs are set to GDD default values in the .asset files
- [ ] Inferno: Fireball use spawns burning ground patch (3s duration, 0.5s tick interval)
- [ ] Blizzard: Frozen enemy kill spawns frost nova (3-unit radius, applies Slow). Non-frozen kill does NOT spawn nova (Edge Case 8).
- [ ] Thunderstrike: Lightning attack on stunned enemy deals 2x damage
- [ ] Venom: Poison tick interval is 0.67s while combo is active (was 1.0s)
- [ ] Supernova: 25% kill proc triggers secondary explosion (50% damage, 4-unit radius)
- [ ] All effects properly `Deactivate()` on run end -- no state leak between runs
- [ ] GDD Acceptance Criterion 2: Fireball + BurnAttack combo produces burning ground patch that ticks for 3s
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `Assets/Trizzle/Tests/Combo/MageEffects/`

- Unit test per effect: `CreateInstance<T>()`, `Activate()`, trigger condition, verify behavior
- Unit test: Venom -- read attribute before Activate, after Activate (reduced), after Deactivate (restored)
- Unit test: Blizzard -- frozen target kill triggers nova; non-frozen target kill does not
- Unit test: Supernova -- proc chance of 1.0 always triggers; proc chance of 0.0 never triggers
- Unit test: All 5 effects -- `Deactivate()` then `Activate()` works cleanly (no double-subscribe)

## Dependencies

- **Blocked by**: 001-extend-combo-definition (needs ComboCategory, TriggerCondition enums), 002-combo-effect-base-class (needs ComboEffect abstract class, TriggerContext)
- **Blocks**: 007-combo-database-population (needs Mage effect assets to wire into ComboDefinition entries), 009-combo-system-tests

## Engine Notes

Uses `ScriptableObject` subclassing, `[SerializeField]`, `Physics2D.OverlapCircle`, `AttributeModifier` -- all stable Unity APIs. `Physics2D.OverlapCircle` uses the 2D physics engine for area detection in the frost nova; confirm that the project uses 2D physics (not 3D) for enemy collision. If 3D, substitute `Physics.OverlapSphere`. SpawnManager.SpawnGroundPatch (Inferno) coordinates with E1/N2 stories per ADR-0003 Related Decisions.
