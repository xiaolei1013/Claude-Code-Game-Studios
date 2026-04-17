# Story: Universal Combo Effects (7)

> **Epic**: combo-synergy
> **Type**: Logic
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L

## Context

**GDD Requirement**: TR-combo-002 (18 concrete ComboEffect implementations -- 7 Universal), TR-combo-003 (trigger conditions via event subscription), TR-combo-008 (Executioner boss-immune), TR-combo-009 (Elemental Storm 5-hit cap)
**ADR Reference**: ADR-0003 -- Decision section (ElementalStormComboEffect per-target hit counter, ExecutionerComboEffect isBoss check), Validation Criteria (Executioner boss immunity test, Elemental Storm 5-hit reset test), Risks (ElementalStorm per-target Dictionary, Executioner EnemyData.isBoss check)
**Control Manifest Rules**: R-011 (lifecycle), R-012 (Activate guard), R-019 (abstract SO), R-022 (EnemyData.IsBoss for boss detection), R-026 (subscription patterns), F-007 (no tag/string boss detection), F-012 (no polling), G-002 (< 0.5ms/frame), G-009 (Elemental Storm 5-hit cap must not be removed)

## Description

Implement the 7 Universal `ComboEffect` ScriptableObject subclasses. Universal combos use shared skills available to both Mage and Archer. Two effects have critical edge cases with dedicated ADR coverage: Executioner (boss immunity) and Elemental Storm (5-hit cap).

**Files to create (7 C# classes + 7 .asset files):**

### 1. BerserkersFuryComboEffect (Frenzy + Rampage, Passive)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Universal/BerserkersFuryComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Universal/BerserkersFuryComboEffect.asset`

- **Trigger**: Passive -- applies modifier in `Activate()`
- **Behavior**: Kill streaks of 5+ grant +10% move speed for 3s (stacks with existing buffs)
- **SerializeField tuning knobs**: `_killStreakThreshold` (default 5), `_moveSpeedBonus` (default 0.10f), `_buffDuration` (default 3.0f)
- **Implementation**: Subscribe to kill event. Track consecutive kills. When threshold reached, apply temporary `AttributeModifier` for move speed. Reset streak counter on taking damage or timer expiry. Buff stacks additively with existing move speed bonuses.
- **Deactivate**: Unsubscribe from kill event. Remove any active move speed modifier. Reset streak counter.

### 2. IroncladComboEffect (Stoneguard + ColdBlood, Passive)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Universal/IroncladComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Universal/IroncladComboEffect.asset`

- **Trigger**: Passive -- monitors HP threshold
- **Behavior**: When below 30% HP, defense doubled instead of normal Stoneguard bonus
- **SerializeField tuning knobs**: `_hpThreshold` (default 0.30f, range 0.15-0.50), `_defenseMultiplier` (default 2.0f, range 1.5-3.0)
- **Implementation**: Subscribe to `Health.OnDamaged` and `Health.OnHealed` events. When HP crosses below threshold, apply `AttributeModifier` for defense. When HP crosses above threshold, remove modifier. Store modifier reference for clean removal.
- **Deactivate**: Remove defense modifier if active. Unsubscribe from health events.

### 3. GoldRushComboEffect (GoldRush + GemRush, OnKill)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Universal/GoldRushComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Universal/GoldRushComboEffect.asset`

- **Trigger**: OnKill -- subscribe to kill event
- **Behavior**: Kills have 10% chance to drop a bonus currency bundle (3x normal drop)
- **SerializeField tuning knobs**: `_dropChance` (default 0.10f, range 0.05-0.25), `_dropMultiplier` (default 3.0f, range 2.0-5.0)
- **Implementation**: In `OnTrigger()`, roll against `_dropChance`. If success, spawn bonus currency drop at death position with value = normal drop * `_dropMultiplier`.
- **Deactivate**: Unsubscribe from kill event.

### 4. ElementalStormComboEffect (BurnAttackSkill + FreezeAttackSkill, OnSkillUse) -- CRITICAL
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Universal/ElementalStormComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Universal/ElementalStormComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to `PlayerController.OnSkillUsed`
- **Behavior**: Enemies with both Burn AND Freeze active take 30% bonus damage from the next 5 hits, then bonus resets (requires both statuses reapplied)
- **SerializeField tuning knobs**: `_bonusMultiplier` (default 1.30f, range 1.10-1.50), `_hitLimit` (default 5, GUARDRAIL G-009: must not be removed)
- **CRITICAL Implementation** (resolved bug B4 from architecture doc Section 9):
  - Maintain `Dictionary<Health, int> _hitCounts` keyed by target instance (per ADR-0003 Risks)
  - In `OnTrigger()`: check `target.HasStatus(Burn) AND target.HasStatus(Freeze)`
  - If both present, look up target in `_hitCounts`. If count < `_hitLimit`, apply bonus damage and increment. If count >= `_hitLimit`, do NOT apply bonus (reset requires both statuses to be reapplied -- remove entry from dictionary when either status drops off)
  - Clear `_hitCounts` in `Deactivate()`
- **Memory**: Up to 19 concurrent enemies = 19 Dictionary entries < 1 KB (ADR-0003 Performance)
- **The uncapped version was confirmed degenerate** -- the 5-hit cap is mandatory, not optional (G-009)

### 5. VampiricStrikesComboEffect (BurnAttackSkill + HealthRecover, OnKill)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Universal/VampiricStrikesComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Universal/VampiricStrikesComboEffect.asset`

- **Trigger**: OnKill -- subscribe to kill event
- **Behavior**: Burn-killed enemies heal player for 5% of their max HP
- **SerializeField tuning knobs**: `_healPercent` (default 0.05f, range 0.02-0.10)
- **Implementation**: In `OnTrigger()`, check if killed enemy had Burn status at death. If yes, heal player for `killedEnemy.MaxHealth * _healPercent`.
- **Deactivate**: Unsubscribe from kill event.

### 6. GaleForceComboEffect (SwiftWind + Frenzy, Passive)
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Universal/GaleForceComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Universal/GaleForceComboEffect.asset`

- **Trigger**: Passive -- applies modifier in `Activate()`
- **Behavior**: Move speed bonus from SwiftWind also increases attack speed by half the amount
- **SerializeField tuning knobs**: `_attackSpeedRatio` (default 0.50f, range 0.25-0.75)
- **Implementation**: In `Activate()`, read the current SwiftWind move speed bonus, calculate attack speed bonus = move speed bonus * `_attackSpeedRatio`, apply as `AttributeModifier` to attack speed.
- **Deactivate**: Remove the attack speed `AttributeModifier`.

### 7. ExecutionerComboEffect (Berserk + SlowAttackSkill, OnSkillUse) -- CRITICAL
**File**: `Assets/Trizzle/Scripts/Combat/ComboEffects/Universal/ExecutionerComboEffect.cs`
**Asset**: `Assets/Trizzle/Data/Combos/Effects/Universal/ExecutionerComboEffect.asset`

- **Trigger**: OnSkillUse -- subscribe to `PlayerController.OnSkillUsed`
- **Behavior**: Slowed enemies below 25% HP are instantly killed. **MUST be boss-immune.**
- **SerializeField tuning knobs**: `_hpThreshold` (default 0.25f, range 0.10-0.40)
- **CRITICAL Implementation** (TR-combo-008, ADR-0003 Validation Criteria):
  - In `OnTrigger()`:
    1. Check `ctx.TargetHealth != null`
    2. Check `ctx.TargetHealth.CurrentHP / ctx.TargetHealth.MaxHP <= _hpThreshold`
    3. Check target has Slow status via `StateMachine.HasState(Slow)`
    4. Check `!target.EnemyData.IsBoss` (R-022, F-007 -- use EnemyData.IsBoss, NOT tags or strings)
    5. If ALL conditions met: `ctx.TargetHealth.Kill()` -- instant kill
    6. If target is boss: do nothing, let normal damage proceed
  - The `isBoss` check uses `EnemyData.IsBoss` per ADR-0004 (R-022), not tag comparisons (F-007)
- **Deactivate**: Unsubscribe from `OnSkillUsed`.

## Acceptance Criteria

- [ ] 7 C# class files exist in `Assets/Trizzle/Scripts/Combat/ComboEffects/Universal/`
- [ ] 7 `.asset` files exist in `Assets/Trizzle/Data/Combos/Effects/Universal/`
- [ ] All `[SerializeField]` tuning knobs set to GDD defaults
- [ ] Berserker's Fury: 5+ kill streak grants +10% move speed for 3s
- [ ] Ironclad: Below 30% HP, defense is doubled
- [ ] Gold Rush: 10% kill chance drops 3x currency bundle
- [ ] Elemental Storm: 30% bonus on Burn+Freeze targets, resets after exactly 5 hits (G-009). Hit 6 does NOT get bonus.
- [ ] Vampiric Strikes: Burn-killed enemies heal player for 5% of enemy max HP
- [ ] Gale Force: SwiftWind move speed bonus grants half as attack speed
- [ ] Executioner: Slowed enemies below 25% HP instant-killed. Boss enemies are NOT instant-killed (TR-combo-008).
- [ ] GDD Acceptance Criterion 7: Slow a boss, get below 25% HP, boss is NOT killed
- [ ] GDD Acceptance Criterion 3: 4 skills forming 2 combos, both effects active simultaneously
- [ ] All effects properly `Deactivate()` on run end
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `Assets/Trizzle/Tests/Combo/UniversalEffects/`

- Unit test: Executioner -- mock `EnemyData.IsBoss = true`, Slow status active, HP at 20%. Call `OnTrigger()`. Verify target HP unchanged (boss immunity). (ADR-0003 Validation Criteria)
- Unit test: Executioner -- mock `EnemyData.IsBoss = false`, Slow active, HP at 20%. Verify instant kill.
- Unit test: Executioner -- non-Slowed enemy below 25% HP. Verify no kill (Slow required).
- Unit test: Executioner -- Slowed enemy at 26% HP. Verify no kill (above threshold).
- Unit test: Elemental Storm -- call `OnTrigger()` 6 times on target with Burn+Freeze. Verify bonus on hits 1-5, NO bonus on hit 6. (ADR-0003 Validation Criteria)
- Unit test: Elemental Storm -- after 5 hits, remove Burn status, reapply Burn+Freeze, verify counter resets and bonus applies again.
- Unit test: Ironclad -- HP above 30%: no defense modifier. HP drops below 30%: defense doubled. HP healed above 30%: modifier removed.
- Unit test: All 7 effects -- Deactivate then Activate works cleanly.

## Dependencies

- **Blocked by**: 001-extend-combo-definition, 002-combo-effect-base-class
- **Depends on**: ADR-0004 for `EnemyData.IsBoss` (Executioner). If E3 Boss Phase System stories are not yet implemented, mock `IsBoss` in tests.
- **Blocks**: 007-combo-database-population, 009-combo-system-tests

## Engine Notes

Same stable APIs as Stories 003/004. `Dictionary<Health, int>` in ElementalStorm is heap-allocated once in `Activate()` and reused -- no per-trigger allocation. `Health.Kill()` method must be confirmed against the shipped codebase (the exact method that bypasses normal damage calculation for instant kill). `EnemyData.IsBoss` field availability depends on E3 (Boss Phase System) or may already exist -- confirm during implementation.

## Completion Notes

**Completed**: 2026-04-17
**Criteria**: 12/14 passing (2 deferred: .asset file authoring → E4-007, simultaneous combo test → E4-007)
**Deviations**:
- GaleForce uses PinpointAttackMultiplier as attack speed proxy (no dedicated AttackSpeed attribute exists). Follow-up: add AttackSpeed to AttributeType enum.
- Executioner uses `health.TakeDamage(health.CurrentHealth)` for instant kill (no Health.Kill() method exists). Functionally equivalent.
- OnKill effects (BerserkersFury, GoldRush, VampiricStrikes) only subscribe to enemies alive at Activate time. Known MVP gap shared with Mage/Archer effects.
- Ironclad re-evaluates HP threshold on next OnHit event after healing (no Health.OnHealed event exists).
**Test Evidence**: Logic: 7 test files at `Assets/Trizzle/Tests/Combo/UniversalEffects/` (~45 tests, 8 behavioral)
**Code Review**: Complete — /simplify (3-agent) + /review (adversarial + testing specialist). 7 issues found and fixed.
**PR**: https://github.com/xiaolei1013/Trizzle/pull/124 (merged)
