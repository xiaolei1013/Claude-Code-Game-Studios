# Skill Code Audit Report

**Date**: 2026-04-08
**Audited by**: /dev-story E5-001
**Total skill files scanned**: 125
**Skill directory**: `Assets/Trizzle/Scripts/Character/Skill/`

---

## Summary

| Category | Files | Occurrences | Feeds Into |
|----------|-------|-------------|------------|
| A: Code TODOs | 10 | 23 | Story 002 |
| B: Missing Prefabs | 3 | 4 prefabs | Story 003 |
| C: MagePlayerController Casts | 30 | 30 files | Story 002 |

---

## Category A: Code TODOs / Placeholders

Skills with TODO, FIXME, HACK, placeholder, or incomplete logic.

| # | File | Lines | Issue | Severity | Size |
|---|------|-------|-------|----------|------|
| A1 | `Support/ArcaneReboundSkill.cs` | 19 | TODO: StateCategory.SpellReflection not implemented | Advisory | XS |
| A2 | `Support/ArcaneReboundSkill.cs` | 73 | TODO: Damage system reflection integration | Advisory | S |
| A3 | `Support/ExecutionFlowSkill.cs` | 46 | TODO: Skill system integration comment (code is now implemented) | Advisory | XS |
| A4 | `Upgrade/FrostFocusSkill.cs` | 65 | TODO: Status effect system integration comment (code is now implemented) | Advisory | XS |
| A5 | `Upgrade/FrostFocusSkill.cs` | 90 | TODO: VFX/SFX for frost focus activation | Advisory | S |
| A6 | `Defense/IceWallSkill.cs` | 67 | EDITOR TODO: iceWallPrefab needs BoxCollider setup | Blocking | S |
| A7 | `Defense/IceWallSkill.cs` | 77 | TODO: Targeting/input system integration | Advisory | M |
| A8 | `Defense/IcePondSkill.cs` | 88 | EDITOR TODO: icePondPrefab needs SphereCollider setup | Blocking | S |
| A9 | `Defense/IcePondSkill.cs` | 97-98 | TODO: Targeting/input system integration (placeholder implementation) | Advisory | M |
| A10 | `Defense/LightningShieldSkill.cs` | 127 | Placeholder: area-of-effect lightning abilities | Advisory | M |
| A11 | `Defense/LightningShieldSkill.cs` | 140 | Placeholder: chain lightning implementation | Advisory | M |
| A12 | `Defense/FrostArmorSkill.cs` | 109 | Placeholder: area-of-effect frost abilities | Advisory | S |
| A13 | `Condition/GuardianCallSkill.cs` | 184 | Placeholder: collision system integration | Advisory | S |
| A14 | `Condition/CurseBreakerSkill.cs` | 92-93 | Placeholder: debuff type detection (returns false) | Blocking | S |
| A15 | `Condition/CurseBreakerSkill.cs` | 101-102 | Placeholder: any debuff detection (returns false) | Blocking | S |
| A16 | `Condition/CurseBreakerSkill.cs` | 110 | Placeholder: returns false | Blocking | XS |
| A17 | `Condition/BloodBondSkill.cs` | 106 | Placeholder: enemy validation (returns true always) | Blocking | S |
| A18 | `Condition/BloodBondSkill.cs` | 145-151 | Placeholder: damage calculation (returns full damage) | Blocking | S |
| A19 | `Condition/BloodBondSkill.cs` | 165 | Placeholder: healing implementation | Blocking | S |
| A20 | `Condition/BloodBondSkill.cs` | 174 | Placeholder: VFX system integration | Advisory | S |

**Note**: A3, A4 had their TODO code resolved in the simplify PR (ExecutionFlowSkill now has real cooldown logic, FrostFocusSkill now checks StateMachine). The TODO comments remain as stale markers.

### Blocking vs Advisory

- **Blocking** (8 items): A6, A8, A14, A15, A16, A17, A18, A19 -- code returns placeholder values (false, full damage) that affect gameplay correctness
- **Advisory** (12 items): A1, A2, A3, A4, A5, A7, A9, A10, A11, A12, A13, A20 -- comments about future integration or missing VFX, game still functions

---

## Category B: Missing Prefabs

Skills that reference prefabs not found in `Assets/Trizzle/Prefabs/Skills/`.

| # | Skill File | Missing Prefab | Field Name | Impact | Size |
|---|-----------|----------------|------------|--------|------|
| B1 | `Defense/IceWallSkill.cs` | IceWall prefab | `iceWallPrefab` | Wall doesn't spawn (null-guarded) | M |
| B2 | `Defense/IcePondSkill.cs` | IcePond prefab | `icePondPrefab` | Pond doesn't spawn (null-guarded) | M |
| B3 | `Defense/IcePondSkill.cs` | Icicle projectile | `iciclePrefab` | Icicle doesn't spawn (null-guarded) | S |
| B4 | `Condition/GuardianCallSkill.cs` | Minion prefab | `minionPrefab` (referenced in code) | Guardian minion doesn't spawn | M |

**Note**: All missing prefab references are null-guarded, so no runtime crash. The skills simply have no visual effect when activated.

---

## Category C: MagePlayerController Casts (F-010 Violations)

30 skill files cast to `MagePlayerController` instead of `PlayerController` or `ICharacterClass`.

### Shared Skills (must refactor for Archer — 5 files)

These are used by both Mage and Archer characters. The cast will throw `InvalidCastException` for Archer players.

| # | File | Cast Count | Usage |
|---|------|-----------|-------|
| C1 | `Support/DashSkill.cs` | 2 | `character is MagePlayerController` — gets animator, triggers dash |
| C2 | `Support/CriticalAttackSkill.cs` | 5 | Casts for critical hit logic |
| C3 | `Support/LethalPrecisionSkill.cs` | 5 | Casts for lethal precision mode |
| C4 | `Support/GravitonSurgeSkill.cs` | refs | Casts for graviton effect |
| C5 | `Defense/RotateShieldSkill.cs` | refs | Casts for shield instantiation |

### Mage-Exclusive Skills (25 files — lower priority)

These are Offense skills that only the Mage class uses. The cast is technically an F-010 violation but does not cause runtime errors since Archer won't equip these.

| # | File | Category |
|---|------|----------|
| C6 | `Offense/ArcaneBarrageSkill.cs` | Mage-exclusive |
| C7 | `Offense/BlizzardSkill.cs` | Mage-exclusive |
| C8 | `Offense/CrystalSpikeSkill.cs` | Mage-exclusive |
| C9 | `Offense/EarthQuakeSkill.cs` | Mage-exclusive |
| C10 | `Offense/FireballSkill.cs` | Mage-exclusive |
| C11 | `Offense/FrostShardSkill.cs` | Mage-exclusive |
| C12 | `Offense/HeavenfallMeteorSkill.cs` | Mage-exclusive |
| C13 | `Offense/IceQuakeSkill.cs` | Mage-exclusive |
| C14 | `Offense/IceShardPushSkill.cs` | Mage-exclusive |
| C15 | `Offense/LightningBoltSkill.cs` | Mage-exclusive |
| C16 | `Offense/LightningOrbSkill.cs` | Mage-exclusive |
| C17 | `Offense/MeteorShowerSkill.cs` | Mage-exclusive |
| C18 | `Offense/MeteorStrikeSkill.cs` | Mage-exclusive |
| C19 | `Offense/PoisonCloudSkill.cs` | Mage-exclusive |
| C20 | `Offense/RockPushSkill.cs` | Mage-exclusive |
| C21 | `Offense/RockQuakeSkill.cs` | Mage-exclusive |
| C22 | `Offense/ShadowVortexSkill.cs` | Mage-exclusive |
| C23 | `Offense/ShockwaveSkill.cs` | Mage-exclusive |
| C24 | `Offense/SolarFlareSkill.cs` | Mage-exclusive |
| C25 | `Offense/StormHeraldSkill.cs` | Mage-exclusive |
| C26 | `Offense/StormPulseSkill.cs` | Mage-exclusive |
| C27 | `Offense/SuperNovaSkill.cs` | Mage-exclusive |
| C28 | `Offense/SwordSlashSkill.cs` | Mage-exclusive |
| C29 | `Offense/WindArrowSkill.cs` | Mage-exclusive |
| C30 | `Defense/RotateSwordSkill.cs` | Mage-exclusive |

### Refactoring Priority

1. **P0 — Shared skills (C1-C5)**: Must refactor to `PlayerController`/`ICharacterClass` before Archer (N1) can ship. 5 files, estimated 2 days.
2. **P2 — Mage-exclusive (C6-C30)**: Refactor for code hygiene. 25 files, estimated 3 days. Not blocking Archer since these skills are class-filtered.

---

## Totals Verification

| Metric | Expected (from story) | Actual | Status |
|--------|-----------------------|--------|--------|
| TODO files | >= 10 | 10 | PASS |
| TODO occurrences | (not specified) | 23 | -- |
| MagePlayerController files | >= 30 | 30 | PASS |
| Missing-prefab skills | >= 3 | 3 (4 prefabs) | PASS |
| Total skill files scanned | 121 (story estimate) | 125 | PASS (exceeded) |
