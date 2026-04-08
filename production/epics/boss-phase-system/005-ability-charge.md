# Story: Ability Template -- Charge

> **Epic**: boss-phase-system
> **Type**: Logic
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-boss-007 (4 new ability templates as MonoBehaviours: GroundSlam, Charge, ShieldPhase, RainOfFire)
**ADR Reference**: ADR-0004 -- Decision section (ability templates as MonoBehaviour components on boss prefabs), Architecture Diagram (ChargeAbility: momentum dash, 0.5s telegraph + line indicator)
**Control Manifest Rules**: R-025 (boss ability templates named ChargeAbility and placed in Assets/Trizzle/Scripts/Combat/BossAbilities/)

## Description

Implement the Charge ability template -- a telegraphed dash toward the player used by Stone Guardian (Boss A) and available to other bosses via the template system.

**Files to create:**

1. **`ChargeAbility.cs`** -- MonoBehaviour in `Assets/Trizzle/Scripts/Combat/BossAbilities/`. Core behavior:
   - `[SerializeField] float _telegraphDuration = 0.5f` -- windup time before dash (safe range: 0.3-1.0s per GDD Tuning Knobs)
   - `[SerializeField] float _chargeDistance = 8f` -- maximum dash distance (safe range: 5-12 units)
   - `[SerializeField] float _chargeSpeed = 20f` -- dash movement speed
   - `[SerializeField] float _damageMultiplier = 2.0f` -- damage on contact as multiplier of boss Attack stat
   - `[SerializeField] GameObject _telegraphVFX` -- line indicator showing charge path
   - `[SerializeField] GameObject _impactVFX` -- effect on contact with player or wall

2. **Execution sequence:**
   - Called by BehaviourTree action node when boss AI selects Charge
   - Boss faces the player's current position, locks direction
   - Instantiate `_telegraphVFX` as a line indicator from boss to charge endpoint (boss position + facing direction * `_chargeDistance`)
   - Boss plays windup animation (0.5s default)
   - After telegraph: destroy telegraph VFX, boss dashes in the locked direction at `_chargeSpeed`
   - Dash terminates on: reaching `_chargeDistance`, hitting a wall, or hitting the player
   - On player contact: apply damage = `boss.Attack * _damageMultiplier` via `DamageCalculator`, instantiate `_impactVFX`
   - On wall contact: boss staggers briefly (recovery animation, no additional damage), instantiate `_impactVFX`
   - Must not clip through walls -- use physics raycast or collision detection along charge path

3. **Integration with BehaviourTree:**
   - Create a BT action node `BTAction_Charge` that calls `ChargeAbility.Execute()`
   - Action node returns Running during telegraph and dash, Success after charge completes

**GDD context:**
- Stone Guardian's signature move. "Telegraphed dash across the room, leaves rubble"
- Charge telegraph (0.5s) + line indicator gives player time to dodge sideways
- Charge direction is locked at telegraph start -- player can dodge after seeing the indicator
- Room-dependent: `_chargeDistance` must not exceed room bounds. Wall collision handles this naturally.

## Acceptance Criteria

- [ ] `ChargeAbility` MonoBehaviour exists in `Assets/Trizzle/Scripts/Combat/BossAbilities/`
- [ ] Telegraph duration, charge distance, charge speed, damage multiplier are all `[SerializeField]`
- [ ] 0.5s default telegraph with visible line indicator showing charge path
- [ ] Boss dashes in locked direction (direction fixed at telegraph start, not tracking player)
- [ ] Dash stops on wall collision (no clipping through walls)
- [ ] Player contact during dash applies damage via `DamageCalculator`
- [ ] Player who dodges sideways avoids the charge entirely
- [ ] BehaviourTree action node `BTAction_Charge` integrates with NodeCanvas BT system
- [ ] VFX references are null-safe
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/boss/`

- Unit test: Execute Charge with player in charge path, verify damage applied
- Unit test: Execute Charge with player outside charge path, verify 0 damage
- Unit test: Verify charge direction is locked at telegraph start (move player during telegraph, boss still charges original direction)
- Unit test: Verify charge stops at wall (does not teleport through colliders)
- Unit test: Verify charge distance does not exceed `_chargeDistance`

## Dependencies

- **Blocked by**: 001-boss-controller-subclass (ability template is a component on boss prefabs)
- **Blocks**: 008-boss-prefab-configuration (Stone Guardian and others need Charge assigned)

## Engine Notes

MonoBehaviour with physics-based movement (Rigidbody or CharacterController dash). Wall collision detection via raycast or collider. Uses existing `DamageCalculator` and VFX instantiation patterns. BehaviourTree integration via NodeCanvas. No post-cutoff API concerns.
