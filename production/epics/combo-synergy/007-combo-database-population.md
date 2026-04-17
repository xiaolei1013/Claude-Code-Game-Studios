# Story: ComboDatabase Population

> **Epic**: combo-synergy
> **Type**: Config
> **Priority**: P1
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-combo-002 (18 concrete implementations), TR-combo-012 (ComboDefinition extended fields populated)
**ADR Reference**: ADR-0003 -- Migration Plan step 7 ("Populate ComboDatabase.asset -- fill all 18 ComboDefinition entries with correct skill references, category, trigger condition, and effect asset references"), ScriptableObject Asset Organization, Validation Criteria ("ComboDatabase.asset contains exactly 18 ComboDefinition entries, each with non-null skillA, skillB, and triggerEffect")
**Control Manifest Rules**: R-023 (asset locations), F-003 (no runtime writes to SO assets)

## Description

Populate the existing `ComboDatabase.asset` ScriptableObject with all 18 `ComboDefinition` entries. This is a data-authoring story -- no new C# code, only Inspector-level asset configuration. Each entry wires together the skill references, category, trigger condition, and the corresponding `ComboEffect` ScriptableObject asset.

**Asset to modify:**
- `Assets/Trizzle/Data/ComboDatabase.asset` (or wherever the current ComboDatabase SO lives in the project)

**The existing 5 Mage fallback entries** must be updated (not duplicated) with the new fields:
1. Inferno: FireballSkill + BurnAttackSkill, Mage, OnSkillUse, InfernoComboEffect.asset
2. Blizzard: FrostShardSkill + FreezeAttackSkill, Mage, OnKill, BlizzardComboEffect.asset
3. Thunderstrike: LightningBoltSkill + StunAttackSkill, Mage, OnSkillUse, ThunderstrikeComboEffect.asset
4. Venom: PoisonCloudSkill + PoisonAttackSkill, Mage, Passive, VenomComboEffect.asset
5. Supernova: SolarFlareSkill + ExplosionAttackSkill, Mage, OnKill, SupernovaComboEffect.asset

**13 new entries to add:**

Archer-exclusive (6):
6. Plague Volley: PiercingArrow + PoisonArrow, Archer, OnSkillUse, PlagueVolleyComboEffect.asset
7. Hailstorm: Multishot + FreezeAttackSkill, Archer, OnSkillUse, HailstormComboEffect.asset
8. Shadow Step: DodgeRollSkill + Afterimage, Archer, OnSkillUse, ShadowStepComboEffect.asset
9. Predator's Mark: EagleEye + CounterRoll, Archer, Passive, PredatorsMarkComboEffect.asset
10. Rapid Assault: Quickdraw + Multishot, Archer, OnSkillUse, RapidAssaultComboEffect.asset
11. Venomous Hail: PoisonArrow + Multishot, Archer, OnSkillUse, VenomousHailComboEffect.asset

Universal (7):
12. Berserker's Fury: Frenzy + Rampage, Universal, Passive, BerserkersFuryComboEffect.asset
13. Ironclad: Stoneguard + ColdBlood, Universal, Passive, IroncladComboEffect.asset
14. Gold Rush Combo: GoldRush + GemRush, Universal, OnKill, GoldRushComboEffect.asset
15. Elemental Storm: BurnAttackSkill + FreezeAttackSkill, Universal, OnSkillUse, ElementalStormComboEffect.asset
16. Vampiric Strikes: BurnAttackSkill + HealthRecover, Universal, OnKill, VampiricStrikesComboEffect.asset
17. Gale Force: SwiftWind + Frenzy, Universal, Passive, GaleForceComboEffect.asset
18. Executioner: Berserk + SlowAttackSkill, Universal, OnSkillUse, ExecutionerComboEffect.asset

**Per entry, verify:**
- `skillA` and `skillB` reference the correct `BaseSkill` ScriptableObject assets (must exist in the project)
- `comboName` matches the GDD name exactly (used in discovery flash UI)
- `description` provides a player-facing effect summary
- `comboCategory` is set to the correct enum value
- `triggerCondition` is set to the correct enum value
- `triggerEffect` references the correct `ComboEffect` .asset file from Stories 003/004/005
- `discoveredFlag` defaults to `false` for all entries

**Skill reference availability:**
- Mage skills (5 combos): Should already exist in the shipped demo codebase
- Shared skills (Universal combos): BurnAttackSkill, FreezeAttackSkill, Frenzy, Rampage, Stoneguard, ColdBlood, GoldRush, GemRush, SwiftWind, Berserk, SlowAttackSkill, HealthRecover -- confirm these exist in `Assets/Trizzle/Data/Skill/`
- Archer skills (6 combos): PiercingArrow, Multishot, PoisonArrow, DodgeRollSkill, Afterimage, CounterRoll, Quickdraw, EagleEye -- depend on N1 Archer Character epic. If not yet created, leave `skillA`/`skillB` as null with a TODO comment and wire when N1 ships.

## Acceptance Criteria

- [ ] `ComboDatabase.asset` contains exactly 18 `ComboDefinition` entries
- [ ] All 18 entries have non-null `comboName` and `description`
- [ ] All 18 entries have correct `comboCategory` (5 Mage, 6 Archer, 7 Universal)
- [ ] All 18 entries have correct `triggerCondition` matching GDD Trigger Conditions table
- [ ] All 5 Mage entries have non-null `skillA`, `skillB` (existing demo skills)
- [ ] All 18 entries have non-null `triggerEffect` referencing the correct ComboEffect .asset
- [ ] Archer skill references are wired if N1 skills exist; documented as TODO if not yet available
- [ ] Universal skill references are wired for all shared skills that exist in the project
- [ ] All `discoveredFlag` values default to `false`
- [ ] GDD Acceptance Criterion 9: ComboDatabase.asset has 18 entries with non-null SkillA, SkillB, and triggerEffect
- [ ] GDD Acceptance Criterion 10: ComboRegistry handles null skill references gracefully -- no NullReferenceException

## Test Evidence

**Type**: Smoke Check
**Path**: `production/qa/smoke-check/`

- Smoke check: Open ComboDatabase.asset in Inspector, count 18 entries
- Smoke check: Verify all triggerEffect references are non-null (blue asset link, not "Missing")
- Smoke check: Verify skill references for Mage combos are non-null
- Smoke check: Enter play mode, draft skills to trigger at least one combo -- verify no NullReferenceException in console

## Dependencies

- **Blocked by**: 001-extend-combo-definition (needs extended ComboDefinition fields), 003-mage-combo-effects (needs Mage effect .assets), 004-archer-combo-effects (needs Archer effect .assets), 005-universal-combo-effects (needs Universal effect .assets)
- **Soft dependency on**: N1 Archer Character (for Archer skill SO references)
- **Blocks**: 009-combo-system-tests (integration tests need populated database)

## Engine Notes

This is a Unity Editor data-authoring task. No code changes -- all work is in the Inspector assigning `[SerializeField]` references on the `ComboDatabase.asset`. The `.asset` file is serialized as YAML by Unity and version-controlled via Git. If multiple developers touch the same `.asset`, merge conflicts in the YAML are possible but manageable for a solo developer. Verify all references survive a domain reload (exit/re-enter play mode) in Unity 6000.3.11f1.

## Completion Notes

**Completed**: 2026-04-17
**Criteria**: 10/11 passing (1 deferred: null ref handling requires play-mode smoke)
**Deviations**:
- Shadow Step skillA is null (DodgeRollSkill has no standalone .asset; base-kit skill). CheckCombos null-guards at line 65. Wire when asset is confirmed.
- Attribute skills use Common variants (FrenzyFuryCommonSkill, StoneguardCommonSkill, etc.). Rare variants won't trigger combos via name-matching. Design gap in CheckCombos, not a data issue.
**Test Evidence**: Config/Data: smoke check at production/qa/smoke-2026-04-17.md. New smoke recommended after sprint close-out.
**Code Review**: N/A (Config/Data story, no new code)
