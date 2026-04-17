# Evidence: E3-008 Boss Prefab Configuration

**Date**: 2026-04-18
**Story**: production/epics/boss-phase-system/008-boss-prefab-configuration.md
**Type**: Config/Data (Inspector authoring)

---

## Configuration Specification

### 5 Boss Prefabs — 2 Variants Each (10 total)

All prefabs go in `Assets/Trizzle/Prefabs/Enemies/Bosses/`.

#### Boss A: Stone Guardian (Melee Bruiser)

| Field | 2-Phase (Rooms 1-5) | 3-Phase (Rooms 6-10) |
|-------|---------------------|----------------------|
| Prefab name | `Boss_StoneGuardian_2P.prefab` | `Boss_StoneGuardian_3P.prefab` |
| Phase thresholds | [0.50] | [0.60, 0.30] |
| P1 BT | MeleeCombo | MeleeCombo |
| P2 BT | MeleeCombo + ChargeAbility + EnrageAura | MeleeCombo + ChargeAbility + EnrageAura |
| P3 BT | — | + SummonMinions |
| P2 stat mods | +30% attack speed, +20% move speed | +30% attack speed, +20% move speed |
| P3 stat mods | — | +50% attack, +30% move speed |
| Abilities | MeleeWeaponHandler, ChargeAbility | MeleeWeaponHandler, ChargeAbility |

#### Boss B: Dark Sorcerer (Ranged Caster)

| Field | 2-Phase | 3-Phase |
|-------|---------|---------|
| Prefab name | `Boss_DarkSorcerer_2P.prefab` | `Boss_DarkSorcerer_3P.prefab` |
| Phase thresholds | [0.50] | [0.60, 0.30] |
| P1 BT | ProjectileBurst | ProjectileBurst |
| P2 BT | + GroundSlamAbility | + GroundSlamAbility |
| P3 BT | — | + RainOfFireAbility |
| Abilities | SpellWeaponHandler, GroundSlamAbility | + RainOfFireAbility |

#### Boss C: Necromancer (Summoner)

| Field | 2-Phase | 3-Phase |
|-------|---------|---------|
| Prefab name | `Boss_Necromancer_2P.prefab` | `Boss_Necromancer_3P.prefab` |
| Phase thresholds | [0.50] | [0.60, 0.30] |
| P1 BT | ProjectileBurst + SummonMinions | ProjectileBurst + SummonMinions |
| P2 BT | + ShieldPhaseAbility | + ShieldPhaseAbility |
| P3 BT | — | + EnrageAura |
| Abilities | SpellWeaponHandler, ShieldPhaseAbility | SpellWeaponHandler, ShieldPhaseAbility |

#### Boss D: War Chief (Hybrid Tank)

| Field | 2-Phase | 3-Phase |
|-------|---------|---------|
| Prefab name | `Boss_WarChief_2P.prefab` | `Boss_WarChief_3P.prefab` |
| Phase thresholds | [0.50] | [0.60, 0.30] |
| P1 BT | MeleeCombo + GroundSlamAbility | MeleeCombo + GroundSlamAbility |
| P2 BT | + ChargeAbility + EnrageAura | + ChargeAbility + EnrageAura |
| P3 BT | — | + SummonMinions + RainOfFireAbility |
| Abilities | MeleeWeaponHandler, GroundSlamAbility, ChargeAbility | + RainOfFireAbility |

#### Boss E: Lich King (All-rounder)

| Field | 2-Phase | 3-Phase |
|-------|---------|---------|
| Prefab name | `Boss_LichKing_2P.prefab` | `Boss_LichKing_3P.prefab` |
| Phase thresholds | [0.50] | [0.60, 0.30] |
| P1 BT | Mixed ranged + melee | Mixed ranged + melee |
| P2 BT | + SummonMinions + ShieldPhaseAbility | + SummonMinions + ShieldPhaseAbility |
| P3 BT | — | + EnrageAura + RainOfFireAbility |
| Abilities | MeleeWeaponHandler, SpellWeaponHandler, ShieldPhaseAbility | + RainOfFireAbility |

---

### EnemyData Configuration

Add 5 entries to `EnemyDatabase.asset` with `IsBoss = true`:

| Boss | ClassType (add to enum) | Base HP | Base Attack | Base Defense | Base MoveSpeed | IsBoss |
|------|------------------------|---------|-------------|-------------|----------------|--------|
| Stone Guardian | StoneGuardian | 500 | 25 | 15 | 3.0 | true |
| Dark Sorcerer | DarkSorcerer | 350 | 35 | 8 | 3.5 | true |
| Necromancer | Necromancer | 300 | 20 | 10 | 3.0 | true |
| War Chief | WarChief | 600 | 30 | 20 | 2.5 | true |
| Lich King | LichKing | 450 | 40 | 12 | 3.0 | true |

*Stats are placeholder values for initial balance. Tuning will occur during playtesting.*

---

### BehaviourTree Assets Needed

Create in `Assets/Trizzle/Items/NodeCanvas/Boss/`:

| BT Asset | Used By | Abilities |
|----------|---------|-----------|
| `StoneGuardian_P1.asset` | SG Phase 1 | MeleeCombo only |
| `StoneGuardian_P2.asset` | SG Phase 2 | MeleeCombo + Charge + Enrage |
| `StoneGuardian_P3.asset` | SG Phase 3 (3P only) | + SummonMinions |
| `DarkSorcerer_P1.asset` | DS Phase 1 | ProjectileBurst |
| `DarkSorcerer_P2.asset` | DS Phase 2 | + GroundSlam |
| `DarkSorcerer_P3.asset` | DS Phase 3 (3P only) | + RainOfFire |
| `Necromancer_P1.asset` | NC Phase 1 | ProjectileBurst + Summon |
| `Necromancer_P2.asset` | NC Phase 2 | + Shield |
| `Necromancer_P3.asset` | NC Phase 3 (3P only) | + Enrage |
| `WarChief_P1.asset` | WC Phase 1 | Melee + GroundSlam |
| `WarChief_P2.asset` | WC Phase 2 | + Charge + Enrage |
| `WarChief_P3.asset` | WC Phase 3 (3P only) | + Summon + RainOfFire |
| `LichKing_P1.asset` | LK Phase 1 | Mixed |
| `LichKing_P2.asset` | LK Phase 2 | + Summon + Shield |
| `LichKing_P3.asset` | LK Phase 3 (3P only) | + Enrage + RainOfFire |

---

## Smoke Check Checklist

- [ ] 10 boss prefab variants exist in `Prefabs/Enemies/Bosses/`
- [ ] Each has BossController component with configured `List<BossPhase>`
- [ ] 2-phase variants have threshold [0.50]; 3-phase have [0.60, 0.30]
- [ ] Each phase has a non-null BehaviourTree reference
- [ ] All 5 boss EnemyData entries have `IsBoss = true`
- [ ] Ability templates correctly attached per boss table above
- [ ] In Play mode: boss transitions at correct HP thresholds
- [ ] In Play mode: summoned minions persist after boss death
- [ ] In Play mode: room does not clear until boss + minions dead
- [ ] All 10 prefabs load without errors or missing references

---

## Status

**BLOCKED ON UNITY EDITOR**: This story requires extensive Unity Editor work that cannot be completed programmatically:
1. Boss prefab creation (requires 3D model setup, component wiring)
2. NodeCanvas BehaviourTree authoring (15 BT assets, visual editor)
3. EnemyDatabase entry addition (5 new ClassType enum values + entries)
4. Phase configuration in Inspector

The specification above is complete. Implementation requires a Unity Editor session.
