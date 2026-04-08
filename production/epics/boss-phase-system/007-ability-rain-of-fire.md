# Story: Ability Template -- Rain of Fire

> **Epic**: boss-phase-system
> **Type**: Logic
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-boss-007 (4 new ability templates as MonoBehaviours: GroundSlam, Charge, ShieldPhase, RainOfFire)
**ADR Reference**: ADR-0004 -- Decision section (ability templates as MonoBehaviour components on boss prefabs), Architecture Diagram (RainOfFireAbility: spawns AoE hazard zones, reuses trap damage pattern)
**Control Manifest Rules**: R-025 (boss ability templates named RainOfFireAbility and placed in Assets/Trizzle/Scripts/Combat/BossAbilities/)

## Description

Implement the Rain of Fire ability template -- random AoE denial circles that telegraph then explode. Used by Dark Sorcerer (Boss B) as their signature move. Reuses the trap system's damage pattern.

**Files to create:**

1. **`RainOfFireAbility.cs`** -- MonoBehaviour in `Assets/Trizzle/Scripts/Combat/BossAbilities/`. Core behavior:
   - `[SerializeField] int _circleCount = 4` -- number of AoE circles per cast (safe range: 2-8 per GDD Tuning Knobs)
   - `[SerializeField] float _telegraphDuration = 1.0f` -- time before circles explode (safe range: 0.5-2.0s)
   - `[SerializeField] float _circleRadius = 2f` -- radius of each AoE circle
   - `[SerializeField] float _damageMultiplier = 1.2f` -- damage per explosion as multiplier of boss Attack stat
   - `[SerializeField] float _spawnAreaRadius = 10f` -- radius around boss within which circles can spawn
   - `[SerializeField] GameObject _telegraphCircleVFX` -- red circle on ground during telegraph
   - `[SerializeField] GameObject _explosionVFX` -- explosion effect when circle detonates
   - `[SerializeField] bool _applyBurnStatus = true` -- whether explosions apply Burn status effect

2. **Execution sequence:**
   - Called by BehaviourTree action node when boss AI selects Rain of Fire
   - Generate `_circleCount` random positions within `_spawnAreaRadius` of boss
   - Placement constraint: at least one safe zone must exist between circles (verify no position overlap that covers 100% of the area)
   - Instantiate `_telegraphCircleVFX` at each position (red circles on ground)
   - After `_telegraphDuration`: all circles explode simultaneously
   - Destroy telegraph VFX, instantiate `_explosionVFX` at each position
   - Apply damage to player if inside any circle radius at detonation time
   - Damage = `boss.Attack * _damageMultiplier` per circle (player in multiple circles takes multiple hits)
   - Optionally apply Burn status effect if `_applyBurnStatus` is true

3. **Trap system reuse:**
   - The AoE circles function similarly to the existing trap damage zones from D6 Trap System
   - Reuse the trap damage pattern where possible (area trigger, telegraph, then damage)
   - If trap system provides a reusable `AreaDamageZone` component, use it. Otherwise, implement a similar pattern.

4. **Integration with BehaviourTree:**
   - Create a BT action node `BTAction_RainOfFire` that calls `RainOfFireAbility.Execute()`
   - Action node returns Running during telegraph, Success after explosions

**GDD context:**
- Dark Sorcerer's signature move. "AoE denial forces constant repositioning"
- Red circles on ground are the telegraph -- player has 1.0s to move to a safe zone
- Must always leave at least one safe zone (GDD Tuning Knobs: Rain of Fire circle count 3-5 with "must leave at least 1 safe zone")

## Acceptance Criteria

- [ ] `RainOfFireAbility` MonoBehaviour exists in `Assets/Trizzle/Scripts/Combat/BossAbilities/`
- [ ] Spawns `_circleCount` random AoE circles within `_spawnAreaRadius` of boss
- [ ] 1.0s default telegraph with visible red circles on ground before explosion
- [ ] After telegraph: circles explode, dealing damage to player if inside radius
- [ ] Damage uses `DamageCalculator` pipeline (respects Defense, etc.)
- [ ] Player in multiple overlapping circles takes damage from each (stacking)
- [ ] At least one safe zone always exists between circles (placement validation)
- [ ] Burn status effect optionally applied on hit (`_applyBurnStatus` flag)
- [ ] All tuning values are `[SerializeField]` (data-driven)
- [ ] BehaviourTree action node `BTAction_RainOfFire` integrates with NodeCanvas BT system
- [ ] VFX references are null-safe
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/boss/`

- Unit test: Execute Rain of Fire, player inside a circle at detonation, verify damage applied
- Unit test: Execute Rain of Fire, player outside all circles at detonation, verify 0 damage
- Unit test: Verify telegraph duration matches `_telegraphDuration` (no early detonation)
- Unit test: Verify circle positions are within `_spawnAreaRadius` of boss
- Unit test: Verify at least one safe zone exists (no 100% area coverage with default settings)

## Dependencies

- **Blocked by**: 001-boss-controller-subclass (ability template is a component on boss prefabs)
- **Soft dependency**: D6 Trap System (reuse trap damage pattern if available; implement standalone if not)
- **Blocks**: 008-boss-prefab-configuration (Dark Sorcerer and others need Rain of Fire assigned)

## Engine Notes

MonoBehaviour component with coroutine-based execution. Uses existing `DamageCalculator` and status effect application (`Burn`). AoE detection via Physics overlap (sphere/circle cast). Performance: ADR-0004 Performance Implications notes Rain of Fire + transition VFX combined must be < 2ms render. Keep particle count reasonable for mobile target.
