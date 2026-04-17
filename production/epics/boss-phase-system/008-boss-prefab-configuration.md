# Story: 5 Boss Prefab Configuration

> **Epic**: boss-phase-system
> **Type**: Config
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L

## Context

**GDD Requirement**: TR-boss-008 (5 unique bosses: Stone Guardian, Dark Sorcerer, Necromancer, War Chief, Lich King), TR-boss-009 (Rooms 1-5: 2-phase bosses; Rooms 6-10: 3-phase bosses), TR-boss-010 (summoned minions persist after boss death; room does not clear until all enemies dead)
**ADR Reference**: ADR-0004 -- Decision section (5 boss prefabs each carry their own BossPhase configuration), Migration Plan step 6 (create 5 boss prefabs, configure phases per GDD phase table)
**Control Manifest Rules**: G-012 (validate _phases list length in Awake: 2 phases for rooms 1-5, 3 phases for rooms 6-10)

## Description

Create and configure 5 boss prefabs with phase data, ability templates, stat modifiers, and per-phase BehaviourTrees. This is the content authoring story that wires together all the systems built in stories 001-007.

**Prefabs to create/configure:**

Each boss needs TWO prefab variants: a 2-phase version (rooms 1-5) and a 3-phase version (rooms 6-10). Total: 10 prefab variants across 5 bosses.

| Boss | Name | Archetype | 2-Phase (Rooms 1-5) | 3-Phase (Rooms 6-10) |
|------|------|-----------|---------------------|----------------------|
| A | Stone Guardian | Melee Bruiser | P1: Melee Combo. P2: + Charge, Enrage Aura | P3: + Summon Minions |
| B | Dark Sorcerer | Ranged Caster | P1: Projectile Burst. P2: + Ground Slam | P3: + Rain of Fire |
| C | Necromancer | Summoner | P1: Projectile Burst, Summon Minions. P2: + Shield Phase | P3: + Enrage Aura |
| D | War Chief | Hybrid Tank | P1: Melee Combo, Ground Slam. P2: + Charge, Enrage Aura | P3: + Summon Minions, Rain of Fire |
| E | Lich King | All-rounder | P1: Ranged + melee mix. P2: + Summon + Shield | P3: + Enrage + Rain of Fire |

**Per-prefab configuration:**

1. **BossController component** with `List<BossPhase>`:
   - Phase thresholds: 2-phase = [0.50], 3-phase = [0.60, 0.30]
   - Per-phase BehaviourTree references (must be authored or copied from existing enemy trees + extended)
   - Per-phase stat modifiers (e.g., Enrage: +30% attack speed, +20% move speed via AttributeModifier)
   - Per-phase TransitionVFX reference (from Story 009, or placeholder)

2. **Ability template components** attached to each prefab:
   - Stone Guardian: MeleeWeaponHandler (existing), ChargeAbility, EnrageAura (existing AttributeModifier)
   - Dark Sorcerer: ProjectileBurst (existing), GroundSlamAbility, RainOfFireAbility
   - Necromancer: ProjectileBurst, SummonMinions (existing SpawnManager call), ShieldPhaseAbility, EnrageAura
   - War Chief: MeleeWeaponHandler, GroundSlamAbility, ChargeAbility, EnrageAura, SummonMinions, RainOfFireAbility
   - Lich King: Mixed existing + ShieldPhaseAbility, SummonMinions, EnrageAura, RainOfFireAbility

3. **EnemyData assets** for each boss:
   - Set `IsBoss = true` on all 5 boss EnemyData ScriptableObjects
   - Configure base stats per boss archetype (placeholder values, balance tuning later)

4. **BehaviourTree authoring** per phase:
   - Each phase needs a BT that uses the correct ability templates
   - Phase 1 trees are simpler (1-2 abilities). Phase 2/3 add complexity.
   - Trees should be authored in NodeCanvas and saved as BT assets

5. **Summon Minions persistence** (TR-boss-010):
   - Verify that when boss dies, summoned minions remain alive
   - Room-clear logic in SpawnManager must check all enemies (boss + minions) are dead before completing the room
   - This may require a SpawnManager change to track boss-summoned entities separately

## Acceptance Criteria

- [ ] 5 boss prefabs exist with BossController component and configured `List<BossPhase>`
- [ ] 2-phase variants: Stone Guardian, Dark Sorcerer, Necromancer, War Chief, Lich King (rooms 1-5)
- [ ] 3-phase variants: same 5 bosses with additional Phase 3 (rooms 6-10)
- [ ] Phase thresholds: 2-phase = [0.50], 3-phase = [0.60, 0.30]
- [ ] Each phase has a distinct BehaviourTree with the correct ability templates per GDD table
- [ ] Stat modifiers correctly applied per phase (Enrage: +30% attack speed, +20% move speed)
- [ ] All 5 boss EnemyData assets have `IsBoss = true`
- [ ] Ability template MonoBehaviours correctly attached to each prefab
- [ ] Summoned minions persist after boss death; room does not clear until all enemies dead
- [ ] All 5 bosses load in-editor without errors
- [ ] Phase transitions trigger correctly at configured HP thresholds

## Test Evidence

**Type**: Config (Smoke Check)
**Path**: `production/qa/evidence/`

- Smoke check: Load each of the 10 boss prefab variants in-editor, verify no missing references
- Smoke check: Play each boss through all phases, verify transitions trigger at correct HP thresholds
- Smoke check: Verify summoned minions persist after boss death
- Smoke check: Verify room does not clear until all enemies (boss + minions) are dead
- Document: Screenshot of each boss prefab's Inspector showing BossController configuration

## Dependencies

- **Blocked by**: 001-boss-controller-subclass, 002-stagger-state-phase-transition, 003-enemydata-isboss-flag, 004-ability-ground-slam, 005-ability-charge, 006-ability-shield-phase, 007-ability-rain-of-fire (all systems must be implemented before prefabs can be configured)
- **Blocks**: 011-boss-system-tests (integration tests need configured prefabs)
- **Soft dependency on**: 009-boss-phase-vfx (VFX can be added to prefabs later; use placeholders initially)

## Engine Notes

Prefab authoring in Unity Inspector. NodeCanvas BehaviourTree assets must be created per phase. ScriptableObject EnemyData assets edited in Inspector. No code changes -- this is pure content/configuration work. Verify serialized struct list persistence when saving prefabs in Unity 6000.3.11f1 (ADR-0004 Verification Required).

## Completion Notes

**Completed**: 2026-04-18
**Criteria**: 1/11 passing, 10 deferred to Unity Editor session
**Deviations**:
- All prefab/BT/EnemyData authoring deferred. Full configuration spec written at production/qa/evidence/e3-008-boss-prefab-configuration.md with exact values for all 10 variants, 15 BT assets, and 5 EnemyData entries.
- User accepted override to mark Complete despite deferred criteria.
**Test Evidence**: Config/Data: evidence doc at `production/qa/evidence/e3-008-boss-prefab-configuration.md`
**Code Review**: N/A (Config/Data story, no code)
