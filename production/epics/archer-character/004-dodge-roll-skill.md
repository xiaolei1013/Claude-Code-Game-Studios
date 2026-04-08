# Story: Dodge Roll Skill

> **Epic**: archer-character
> **Type**: Logic
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-archer-005 (Archer base stats in GamePlayDatabase: HP 75, Attack 80, AttackRange 10, MoveSpeed 3.6, Defense 3, CritChance 0.08)
**ADR Reference**: ADR-0005 -- Decision item 5 (DodgeRollSkill as UpgradableSkill subclass, parallel to DashSkill)
**Control Manifest Rules**: F-010 (DodgeRollSkill casts to PlayerController, never MagePlayerController), F-017 (MonoBehaviour + SO + interface only)

## Description

Create the Archer's movement/evasion skill -- a short directional roll with invincibility frames. Dodge Roll defines the Archer's survival pattern: reactive evasion, not teleportation. Shorter distance than Blink but with i-frames as compensation.

**Files to create:**

1. **`DodgeRollSkill.cs`** -- `DodgeRollSkill : UpgradableSkill` in `Assets/Trizzle/Scripts/Skill/Archer/`. Implements the following per GDD Detailed Design:

   **Movement:**
   - Direction: Movement input direction (not facing direction -- differs from Blink)
   - Distance: 2.0 units (configurable via `[SerializeField] private float _dodgeDistance = 2.0f`)
   - Cooldown: 1.5s (configurable via `[SerializeField] private float _cooldown = 1.5f`)
   - Uses `AdvancedWalkerController` momentum (same pattern as DashSkill post-refactor)
   - Does NOT pass through walls (raycast check for ground and obstacles)

   **I-Frames:**
   - Duration: 0.2s from activation (configurable via `[SerializeField] private float _iFrameDuration = 0.2f`)
   - During i-frames, `Health.TakeDamage()` is suppressed (return early if `isDodging && Time.time < iFrameEnd`)
   - I-frames block ALL damage sources: enemy attacks, projectiles, AND trap damage (GDD Edge Case 3)
   - I-frames block status effect application during the window (GDD Edge Case 4)
   - I-frames last their full duration even if roll distance is shortened by wall collision (GDD Edge Case 1)

   **Wall Collision:**
   - Roll stops at wall contact point -- no clipping through (GDD Edge Case 1)
   - Momentum zeroed on wall contact
   - Raycast check for ground at destination -- if no ground, roll stops at last valid ground position (GDD Edge Case 2)

   **Type**: Active skill, assigned as `defaultActiveRunSkill` on ArcherPlayerController

**Key formulas from GDD:**
```
rollDuration = dodgeDistance / rollSpeed
iFrameStart = 0.0s (immediate on activation)
iFrameEnd = 0.2s
iFrameRatio = 0.2 / rollDuration
```

**Implementation notes:**
- DodgeRollSkill casts only to `PlayerController`, never to concrete subclasses
- I-frame check must integrate with `Health.TakeDamage()` -- either via a flag on Health component or via a callback pattern
- The i-frame implementation must be clean enough for 005-counter-roll (Counter Roll upgrade checks "did i-frames block an attack")

## Acceptance Criteria

- [ ] `DodgeRollSkill : UpgradableSkill` exists at `Assets/Trizzle/Scripts/Skill/Archer/DodgeRollSkill.cs`
- [ ] Roll moves 2.0 units in movement input direction (not facing direction)
- [ ] Cooldown is 1.5s (configurable in Inspector)
- [ ] I-frames last 0.2s from activation (configurable in Inspector)
- [ ] I-frames block ALL incoming damage during the window (enemy attacks, projectiles, traps)
- [ ] I-frames block status effect application during the window
- [ ] Roll stops at walls -- no clipping through obstacles
- [ ] I-frames persist full 0.2s even if wall shortens roll distance
- [ ] Momentum zeroed on wall contact
- [ ] Roll stops at last valid ground position if destination has no ground
- [ ] DodgeRollSkill casts to `PlayerController` only -- grep confirms no concrete controller references
- [ ] GDD Acceptance Criterion 3: "Pressing dodge rolls 2.0 units in movement direction. During the first 0.2s, all incoming damage is blocked."
- [ ] GDD Acceptance Criterion 4: "Roll stops at walls (no clipping through). Verify by rolling toward a wall from 1 unit away."

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/archer/`

- Unit test: DodgeRollSkill distance is 2.0 default
- Unit test: DodgeRollSkill cooldown is 1.5s default
- Unit test: DodgeRollSkill i-frame duration is 0.2s default
- Unit test: During i-frames, `TakeDamage()` is suppressed (damage = 0 during 0.2s window)
- Unit test: After i-frames expire, `TakeDamage()` applies normally
- Unit test: I-frames block status effect application (mock status effect not applied during window)
- Unit test: Wall collision stops roll and zeroes momentum

## Dependencies

- **Blocked by**: 001-archer-controller-icharacterclass (ArcherPlayerController must exist), 002-dashskill-refactor (prerequisite for all Archer integration)
- **Blocks**: 006-archer-exclusive-skills (dodge upgrade skills depend on DodgeRollSkill existing), 009-archer-character-tests

## Engine Notes

Uses `UpgradableSkill` base class and `AdvancedWalkerController` momentum -- same pattern as the post-refactor DashSkill. Wall collision uses Unity Physics raycasts (stable API). The i-frame implementation integrates with `Health.TakeDamage()` -- verify the Health component's API allows external suppression (flag or callback) before implementation.
