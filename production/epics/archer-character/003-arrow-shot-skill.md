# Story: Arrow Shot Skill

> **Epic**: archer-character
> **Type**: Logic
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-archer-004 (I-frames block ALL damage sources and status effect application during the 0.2s window)
**ADR Reference**: ADR-0005 -- Decision item 5 (ArrowShotSkill as UpgradableSkill subclass, parallel to FireballSkill)
**Control Manifest Rules**: F-010 (ArrowShotSkill casts to PlayerController, never MagePlayerController), F-017 (MonoBehaviour + SO + interface only)

## Description

Create the Archer's primary attack skill -- a fast, single-target projectile with auto-aim. Arrow Shot defines the Archer's combat rhythm: rapid-fire, lower per-hit damage, constant pressure.

**Files to create:**

1. **`ArrowShotSkill.cs`** -- `ArrowShotSkill : UpgradableSkill` in `Assets/Trizzle/Scripts/Skill/Archer/`. Implements the following per GDD Detailed Design:
   - **Targeting**: Auto-aim at nearest enemy (same targeting logic as FireballSkill)
   - **Cooldown**: 0.5s (configurable via `[SerializeField] private float _cooldown = 0.5f`)
   - **Damage**: `0.6 * playerAttack` (configurable via `[SerializeField] private float _damageMultiplier = 0.6f`)
   - **Projectile speed**: 18 (configurable via `[SerializeField] private float _projectileSpeed = 18f`)
   - **Type**: Active skill, assigned as `defaultActiveHitSkill` on ArcherPlayerController

2. **Arrow Projectile Prefab** -- `Assets/Trizzle/Prefabs/Projectiles/ArrowProjectile.prefab`. Uses the existing projectile system (same pattern as Fireball projectile). Moves in a straight line at speed 18, single-target hit, destroys on contact. Placeholder visuals acceptable -- 008-archer-vfx will replace.

**Implementation notes from GDD:**
- ArrowShotSkill casts only to `PlayerController` (base class), never to `MagePlayerController` or `ArcherPlayerController` -- the skill is class-agnostic by construction
- Uses `DamageCalculator` for damage computation (upstream dependency on D1 Core Combat)
- Uses `SpellWeaponHandler` for projectile instantiation (same system as Fireball)
- Receives upgrades via the existing `UpgradableSkill.ApplyUpgrade()` framework -- no new upgrade logic needed in this story

**DPS comparison (for balance verification):**
```
Mage DPS  = 100 Attack * 1.0 / 1.0s = 100 DPS
Archer DPS = 80 Attack * 0.6 / 0.5s = 96 DPS (~4% less raw, compensated by higher crit)
```

## Acceptance Criteria

- [ ] `ArrowShotSkill : UpgradableSkill` exists at `Assets/Trizzle/Scripts/Skill/Archer/ArrowShotSkill.cs`
- [ ] Arrow fires at nearest enemy with auto-aim (same targeting as FireballSkill)
- [ ] Cooldown is 0.5s (configurable in Inspector)
- [ ] Damage is `0.6 * player.Attack` (configurable `_damageMultiplier` in Inspector)
- [ ] Projectile speed is 18 (configurable in Inspector)
- [ ] Arrow projectile destroys on contact with enemy
- [ ] ArrowShotSkill casts to `PlayerController` only -- grep confirms no `MagePlayerController` or `ArcherPlayerController` references
- [ ] Skill integrates with `UpgradableSkill.ApplyUpgrade()` framework (upgrades can be applied)
- [ ] GDD Acceptance Criterion 2: "Pressing attack fires an arrow projectile at the nearest enemy. Arrow travels at speed 18, deals 0.6x Attack damage. Cooldown is 0.5s."

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/archer/`

- Unit test: ArrowShotSkill cooldown is 0.5s default
- Unit test: ArrowShotSkill damage = Attack * 0.6 (with mock PlayerController Attack=100, expected damage=60)
- Unit test: ArrowShotSkill projectile speed is 18 default
- Unit test: ArrowShotSkill.CanApplyUpgrade() returns true for compatible arrow upgrades, false for incompatible (Fireball upgrades)

## Dependencies

- **Blocked by**: 001-archer-controller-icharacterclass (ArcherPlayerController must exist), 002-dashskill-refactor (prerequisite for all Archer integration)
- **Blocks**: 006-archer-exclusive-skills (arrow upgrade skills depend on ArrowShotSkill existing), 009-archer-character-tests

## Engine Notes

Uses `UpgradableSkill` base class, `DamageCalculator`, and projectile instantiation -- all existing patterns from the Mage implementation. No new engine APIs needed. Follow FireballSkill implementation as the reference pattern.
