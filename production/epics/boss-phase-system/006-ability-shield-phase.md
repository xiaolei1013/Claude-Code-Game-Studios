# Story: Ability Template -- Shield Phase

> **Epic**: boss-phase-system
> **Type**: Logic
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-boss-007 (4 new ability templates as MonoBehaviours: GroundSlam, Charge, ShieldPhase, RainOfFire), TR-boss-011 (Shield Phase blocks damage but NOT status effects; shield destroyed by hit counter)
**ADR Reference**: ADR-0004 -- Decision section (ability templates as MonoBehaviour components on boss prefabs), Architecture Diagram (ShieldPhaseAbility: temporary invulnerability + hit counter)
**Control Manifest Rules**: R-025 (boss ability templates named ShieldPhaseAbility and placed in Assets/Trizzle/Scripts/Combat/BossAbilities/)

## Description

Implement the Shield Phase ability template -- temporary invulnerability with a hit counter that the player must break through. Used by Lich King (Boss E) as their signature defensive move.

**Files to create:**

1. **`ShieldPhaseAbility.cs`** -- MonoBehaviour in `Assets/Trizzle/Scripts/Combat/BossAbilities/`. Core behavior:
   - `[SerializeField] int _baseShieldHits = 4` -- base number of hits to break shield
   - `[SerializeField] int _hitsPerPhaseScaling = 2` -- additional hits per phase index (formula: `shieldHits = _baseShieldHits + (phaseIndex * _hitsPerPhaseScaling)`)
   - `[SerializeField] GameObject _shieldVFX` -- persistent shield visual while active
   - `[SerializeField] GameObject _crackVFX` -- visual per hit on shield
   - `[SerializeField] GameObject _shatterVFX` -- visual when shield breaks
   - `[SerializeField] bool _bossAttacksDuringShield = false` -- if false, boss stops attacking while shielded (minions still attack)

2. **Shield behavior:**
   - When activated: set boss damage invulnerability (but NOT status effect immunity), spawn `_shieldVFX` attached to boss
   - Each incoming damage hit: decrement hit counter by 1 (regardless of damage amount), play `_crackVFX`, apply zero damage to boss
   - **Critical: status effects still apply during shield** -- Freeze/Stun/Slow can affect the boss even while shield is active. Only HP damage is blocked.
   - When hit counter reaches 0: destroy `_shieldVFX`, play `_shatterVFX`, remove damage invulnerability, shield ability ends
   - Boss may or may not attack during shield (configurable via `_bossAttacksDuringShield`). Default: boss does NOT attack, but summoned minions do -- creating a "deal with the adds while the boss is shielded" moment.

3. **Archer vs Mage balance (from GDD edge case #6):**
   - Each arrow hit counts as 1 shield hit regardless of damage
   - Archer's faster fire rate breaks shields faster than Mage -- this is intentional and rewards rapid-fire builds
   - No special-casing needed: the hit counter naturally favors higher hit-rate characters

4. **Integration with BehaviourTree:**
   - Create a BT action node `BTAction_ShieldPhase` that activates the shield and returns Running until shield is broken
   - Shield can be activated as part of a phase's BehaviourTree sequence

**GDD context:**
- Lich King's signature move. "Summons minions while invulnerable, tests player's ability to multitask"
- Shield hit formula: `shieldHits = baseShieldHits + (phaseIndex * 2)`. Boss A phase 2: 4 hits. Boss E phase 3: 8 hits.
- The shield + status effects interaction is a deliberate design choice: Freeze the boss to buy time clearing minions

## Acceptance Criteria

- [ ] `ShieldPhaseAbility` MonoBehaviour exists in `Assets/Trizzle/Scripts/Combat/BossAbilities/`
- [ ] Shield blocks ALL incoming HP damage (damage = 0 while shield active)
- [ ] Shield does NOT block status effects -- Freeze, Stun, Slow still apply to boss during shield
- [ ] Each hit decrements hit counter by 1 regardless of damage amount
- [ ] Hit counter formula: `shieldHits = _baseShieldHits + (phaseIndex * _hitsPerPhaseScaling)`
- [ ] Shield breaks when hit counter reaches 0, with shatter VFX
- [ ] Each hit on shield plays crack VFX
- [ ] Shield VFX is visible while shield is active, destroyed when shield breaks
- [ ] `_bossAttacksDuringShield` flag controls whether boss AI continues during shield
- [ ] All tuning values are `[SerializeField]` (data-driven)
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/boss/`

- Unit test: Activate shield with 4 hits, deal damage 4 times, verify shield breaks on 4th hit
- Unit test: During shield, apply Freeze status effect, verify boss IS frozen (status effect applies)
- Unit test: During shield, deal damage, verify boss HP is unchanged (damage blocked)
- Unit test: Verify hit counter scales with phase index: phase 0 = 4 hits, phase 2 = 8 hits
- Unit test: Verify each hit decrements counter by 1 regardless of damage amount (100 damage hit = 1 hit count, same as 1 damage hit)

## Dependencies

- **Blocked by**: 001-boss-controller-subclass (ability template is a component on boss prefabs)
- **Blocks**: 008-boss-prefab-configuration (Lich King and others need ShieldPhase assigned)

## Engine Notes

MonoBehaviour component. Damage blocking uses the existing invulnerability system but must diverge from it for status effects -- standard invulnerability blocks everything, but shield must selectively block only HP damage. May need a new `isShielded` flag separate from `isInvulnerable`, or a modification to the damage/status application pipeline to distinguish shield from stagger invulnerability. This is the most architecturally novel ability template -- verify the approach in a spike if needed.

## Completion Notes

**Completed**: 2026-04-17
**Criteria**: 11/11 passing
**Deviations**:
- Health.cs modified: added `IsShielded` property + guard in `TakeDamage`. Anticipated by Engine Notes. `IsShielded` zeroes HP damage but still fires `OnHit` (so shield counts hits). Status effects unaffected because they use `StateMachine.SwitchState`, not `TakeDamage`.
**Test Evidence**: Logic: 9 unit tests at `Assets/Trizzle/Tests/Boss/ShieldPhaseAbilityTest.cs`
**Code Review**: Pending (run `/simplify` or `/review` before merge)
