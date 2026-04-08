# Story: Ability Template -- Ground Slam

> **Epic**: boss-phase-system
> **Type**: Logic
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-boss-007 (4 new ability templates as MonoBehaviours: GroundSlam, Charge, ShieldPhase, RainOfFire)
**ADR Reference**: ADR-0004 -- Decision section (ability templates as MonoBehaviour components on boss prefabs), Architecture Diagram (GroundSlamAbility: radial damage zone, 0.8s telegraph)
**Control Manifest Rules**: R-025 (boss ability templates named GroundSlamAbility and placed in Assets/Trizzle/Scripts/Combat/BossAbilities/)

## Description

Implement the Ground Slam ability template -- a telegraphed AoE attack used by War Chief (Boss D) and available to other bosses via the template system.

**Files to create:**

1. **`GroundSlamAbility.cs`** -- MonoBehaviour in `Assets/Trizzle/Scripts/Combat/BossAbilities/`. Core behavior:
   - `[SerializeField] float _telegraphDuration = 0.8f` -- windup time before damage (safe range: 0.5-1.5s per GDD Tuning Knobs)
   - `[SerializeField] float _damageRadius = 5f` -- radius of damage zone (safe range: 3-8 units)
   - `[SerializeField] float _damageMultiplier = 1.5f` -- damage as multiplier of boss Attack stat
   - `[SerializeField] GameObject _telegraphVFX` -- visual indicator during windup (ground circle)
   - `[SerializeField] GameObject _impactVFX` -- explosion effect on slam

2. **Execution sequence:**
   - Called by BehaviourTree action node when boss AI selects Ground Slam
   - Instantiate `_telegraphVFX` at boss position showing the AoE radius (red circle on ground)
   - Boss plays windup animation (0.8s default)
   - After telegraph duration: destroy telegraph VFX, instantiate `_impactVFX`
   - Apply damage to all enemies within `_damageRadius` of boss position using `DamageCalculator`
   - Damage = `boss.Attack * _damageMultiplier`
   - Players inside radius take damage; players outside are safe

3. **Integration with BehaviourTree:**
   - Create a BT action node `BTAction_GroundSlam` that calls `GroundSlamAbility.Execute()`
   - Action node returns Running during telegraph, Success after damage dealt

**GDD context:**
- War Chief's signature move. "Room-wide shockwave, must dodge or take massive damage"
- Ground Slam telegraph (0.8s) is readable -- player can see the windup and dodge
- Status effect potential: may apply Slow to hit targets (configurable, not required for v1.0)

## Acceptance Criteria

- [ ] `GroundSlamAbility` MonoBehaviour exists in `Assets/Trizzle/Scripts/Combat/BossAbilities/`
- [ ] Telegraph duration, damage radius, damage multiplier are all `[SerializeField]` (data-driven, not hardcoded)
- [ ] 0.8s default telegraph with visible ground indicator before damage
- [ ] Radial damage zone applies damage to all players within radius after telegraph
- [ ] Damage uses `DamageCalculator` (not raw HP subtraction)
- [ ] Players outside radius take zero damage
- [ ] BehaviourTree action node `BTAction_GroundSlam` integrates with NodeCanvas BT system
- [ ] VFX references are null-safe (ability works without VFX assigned, just no visuals)
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/boss/`

- Unit test: Execute Ground Slam with player inside radius, verify damage applied = `Attack * _damageMultiplier`
- Unit test: Execute Ground Slam with player outside radius, verify 0 damage
- Unit test: Verify telegraph duration matches `_telegraphDuration` (no early/late damage)
- Unit test: Verify damage uses `DamageCalculator` pipeline (respects Defense, etc.)

## Dependencies

- **Blocked by**: 001-boss-controller-subclass (ability template is a component on boss prefabs; BossController must exist)
- **Blocks**: 008-boss-prefab-configuration (War Chief and others need Ground Slam assigned)

## Engine Notes

MonoBehaviour component with coroutine-based execution. Uses existing `DamageCalculator` for damage application and existing projectile/VFX instantiation patterns. BehaviourTree integration via NodeCanvas (existing BT framework in project). No post-cutoff API concerns.
