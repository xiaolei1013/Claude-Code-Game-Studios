# Story: Complete Skill Implementations

> **Epic**: incomplete-skills
> **Type**: Logic
> **Priority**: P0
> **Status**: In Progress
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L

## Context

**GDD Requirement**: N/A -- code completion task derived from systems-index.md ("15+ skills need TODO resolution")
**ADR Reference**: ADR-0005 (Accepted) -- R-004 (ICharacterClass on both MagePlayerController and ArcherPlayerController; shared skills cast to ICharacterClass or PlayerController), F-010 (no MagePlayerController casts in shared skills), F-011 (Archer is not a MagePlayerController subclass)
**Control Manifest Rules**: R-004, F-010, F-011, F-017 (no new architectural paradigms)

## Description

Resolve all code-level TODOs, placeholders, and MagePlayerController cast violations identified by the Story 001 audit. This is the largest E5 story because it covers two distinct categories of fixes across many files.

**Part 1: Resolve TODO/Placeholder Logic (Category A from audit)**

Fix the code TODOs in the 10 files identified by the audit. Known issues and expected fixes:

| File | Issue | Expected Fix |
|------|-------|-------------|
| `Support/ArcaneReboundSkill.cs` | TODO: SpellReflection StateCategory, damage reflection integration | Wire into existing `StateMachine` states; integrate with `DamageCalculator` for reflected damage |
| `Support/ExecutionFlowSkill.cs` | TODO: Skill system integration | Wire into `BaseSkill` cooldown/activation flow via existing `ICharacter` interface |
| `Upgrade/FrostFocusSkill.cs` | TODO: Status effect system integration, VFX/SFX | Wire into existing `StateMachine/` frozen/slow states; add VFX prefab reference field |
| `Defense/LightningShieldSkill.cs` | 2 placeholders: AoE lightning, chain lightning | Implement using existing projectile/AoE patterns from other Defense skills (e.g., FireShieldSkill) |
| `Defense/FrostArmorSkill.cs` | 1 placeholder: AoE frost | Implement using existing AoE frost patterns |
| `Defense/IceWallSkill.cs` | TODO: targeting/input system integration | Wire into existing targeting system (similar to other Defense skills) |
| `Defense/IcePondSkill.cs` | TODO: targeting/input system integration | Wire into existing targeting system |
| `Condition/GuardianCallSkill.cs` | Placeholder: collision system | Wire into existing Unity collision/trigger system |
| `Condition/CurseBreakerSkill.cs` | 5 placeholders: debuff detection returns false | Wire `HasDebuff` and `HasAnyDebuff` into existing `StateMachine` state queries |
| `Condition/BloodBondSkill.cs` | 5 placeholders: enemy detection, damage calc, healing, VFX | Wire into existing `Health`, `DamageCalculator`, and enemy detection systems |

**Key constraint:** All fixes must use existing patterns (MonoBehaviour + ScriptableObject + C# interface). No new architectural paradigms (F-017). Integrate with existing systems (`StateMachine/`, `DamageCalculator`, `Health`, `ICharacter`) rather than creating new abstractions.

**Part 2: Refactor MagePlayerController Casts (Category C from audit)**

Refactor the shared skills (from the 30 files identified) to cast to `PlayerController` or `ICharacterClass` instead of `MagePlayerController`. This is required by R-004 and F-010 to support the Archer character (N1).

**Approach:** For each of the 30 files:
1. Determine if the skill is Mage-exclusive or shared (audit report Category C provides this)
2. For shared skills: replace `MagePlayerController` casts with `PlayerController` or `ICharacterClass`
3. For Mage-exclusive skills: leave as-is (Mage-exclusive skills may legitimately reference `MagePlayerController`)
4. Verify all accessed members are available on the base type -- if a member is only on `MagePlayerController`, it must be promoted to `PlayerController` or accessed through `ICharacterClass`

**Known files with MagePlayerController casts (30 total):**
- Offense: ArcaneBarrageSkill, BlizzardSkill, CrystalSpikeSkill, EarthQuakeSkill, FireballSkill, FrostShardSkill, HeavenfallMeteorSkill, IceQuakeSkill, IceShardPushSkill, LightningBoltSkill, LightningOrbSkill, MeteorShowerSkill, MeteorStrikeSkill, PoisonCloudSkill, RockPushSkill, RockQuakeSkill, ShadowVortexSkill, ShockwaveSkill, SolarFlareSkill, StormHeraldSkill, StormPulseSkill, SuperNovaSkill, SwordSlashSkill, WindArrowSkill
- Defense: RotateShieldSkill, RotateSwordSkill
- Support: CriticalAttackSkill, DashSkill, GravitonSurgeSkill, LethalPrecisionSkill

**The audit report (Story 001) will refine this list** by identifying which are shared vs. Mage-exclusive.

## Acceptance Criteria

- [ ] All TODO/FIXME/placeholder comments in Category A files are resolved with working implementations
- [ ] No skill file in `Assets/Trizzle/Scripts/Character/Skill/` contains unresolved TODO, FIXME, or placeholder patterns (verified by re-running grep)
- [ ] All shared skills cast to `PlayerController` or `ICharacterClass`, not `MagePlayerController` (F-010)
- [ ] All resolved skills compile without errors in Unity 6000.3.11f1
- [ ] All resolved skills use existing patterns (MonoBehaviour, ScriptableObject, C# interface) -- no new frameworks (F-017)
- [ ] `CurseBreakerSkill.HasDebuff()` and `HasAnyDebuff()` return correct results based on `StateMachine` state (not hardcoded false)
- [ ] `BloodBondSkill` damage and healing calculations use `DamageCalculator` and `Health` systems (not placeholder return values)
- [ ] `ArcaneReboundSkill` spell reflection integrates with `DamageCalculator` for reflected damage
- [ ] `ExecutionFlowSkill` integrates with `BaseSkill` cooldown/activation system
- [ ] `FrostFocusSkill` integrates with `StateMachine` frozen/slow states
- [ ] Existing unit tests for modified skills still pass (106 existing test files)

## Test Evidence

**Type**: Unit Test + Integration Test
**Path**: `Assets/Trizzle/Tests/Character/Skill/`

- Re-run all 106 existing skill tests -- all must pass after modifications
- New unit tests for fixed placeholder logic (CurseBreakerSkill debuff detection, BloodBondSkill damage/heal, ArcaneReboundSkill reflection)
- Grep verification: zero matches for TODO/FIXME/placeholder in skill directory

## Dependencies

- **Blocked by**: 001-skill-code-audit (need the categorized work list and shared-vs-exclusive classification)
- **Blocks**: 004-skill-completion-tests (tests validate the fixes made here)

## Engine Notes

Uses `MonoBehaviour`, `ScriptableObject`, `ICharacter`, `PlayerController`, `StateMachine`, `DamageCalculator`, `Health` -- all existing project APIs. The `ICharacterClass` interface is defined in ADR-0005 (Accepted) and may need to be created if not yet implemented -- check `Assets/Trizzle/Scripts/Character/` for its existence before starting. `PlayerController` base class is the safe cast target until `ICharacterClass` is available.
