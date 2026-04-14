# QA Plan — Sprint 2

**Sprint**: 2 (2026-04-10 to 2026-04-24)
**Sprint Goal**: Deliver Archer character foundation + begin Boss Phase System
**QA Lead**: Claude (qa-lead agent)
**Generated**: 2026-04-10
**Scope**: 10 stories across 2 systems (N1 Archer Character, E3 Boss Phase System)
**Engine**: Unity 6000.3.11f1
**Sprint File**: production/sprints/sprint-02.md

---

## Story Classification

| Story | Name | Type | Test Evidence Required | Gate Level |
|-------|------|------|------------------------|------------|
| N1-001 | ArcherPlayerController & ICharacterClass | Logic | Unit tests — interface properties, enum extension, both controllers implement ICharacterClass | BLOCKING |
| N1-002 | DashSkill Cast Refactor | Logic | Unit tests — zero MagePlayerController refs in shared skills; Mage regression smoke test | BLOCKING |
| N1-003 | Arrow Shot Skill | Logic | Unit tests — damage formula, cooldown, projectile speed, auto-aim targeting | BLOCKING |
| N1-004 | Dodge Roll Skill | Logic | Unit tests — distance, i-frame timing, wall collision, status block | BLOCKING |
| N1-005 | Archer Base Stats | Config/Data | Smoke check — Inspector values match GDD table, Archer selectable in picker | ADVISORY |
| N1-007 | Draft Pool Filtering | Integration | Integration test — class-specific filtering for Mage vs Archer draft pools | BLOCKING |
| N1-009 | Archer Character Tests | Logic | Self-referential — this IS the test story | BLOCKING |
| E3-001 | BossController Subclass | Logic | Unit tests — phase sorting, health threshold triggers, event firing, multi-skip | BLOCKING |
| E3-002 | Stagger State & Phase Transition | Logic | Unit tests — R-010 sequence, invulnerability, debuff clear, tree swap, death during stagger | BLOCKING |
| E3-003 | EnemyData.IsBoss Verification | Logic | Grep verification — IsBoss used everywhere, no tag/name checks | BLOCKING |

---

## Test Cases per Story

### N1-001: ArcherPlayerController & ICharacterClass

**Story type**: Logic
**Test path**: `Assets/Trizzle/Tests/Character/Archer/`

#### Unit Tests

1. `test_ICharacterClass_interface_has_required_members`
   - Assert: ICharacterClass has ClassType property (PlayerClassType), GetClassSkills() method, ClassName property (string)

2. `test_ArcherPlayerController_implements_ICharacterClass`
   - Assert: ArcherPlayerController implements ICharacterClass; ClassType returns Archer

3. `test_MagePlayerController_implements_ICharacterClass`
   - Assert: MagePlayerController implements ICharacterClass; ClassType returns Mage; zero behavioral change

4. `test_PlayerClassType_enum_has_Archer_value`
   - Assert: PlayerClassType.Archer exists; PlayerClassType.Mage still exists and unchanged

5. `test_ArcherPlayerController_extends_PlayerController`
   - Assert: ArcherPlayerController is a subclass of PlayerController (not MagePlayerController — F-011)

---

### N1-002: DashSkill Cast Refactor

**Story type**: Logic
**Test path**: `Assets/Trizzle/Tests/Character/Skill/Support/DashSkillRefactorTest.cs`

#### Unit Tests

1. `test_DashSkill_no_MagePlayerController_references`
   - Grep: DashSkill.cs contains zero "MagePlayerController" strings

2. `test_SharedSkills_no_MagePlayerController_casts`
   - Grep: All shared skill files contain zero MagePlayerController references (extends E5-004 F-010 check)

3. `test_DashSkill_activates_with_PlayerController_type`
   - Assert: DashSkill.Activate() works with any PlayerController subclass, not just Mage

#### Manual Verification

- Mage completes Room 1 on Normal with no runtime exceptions (regression smoke test)

---

### N1-003: Arrow Shot Skill

**Story type**: Logic
**Test path**: `Assets/Trizzle/Tests/Character/Skill/Archer/ArrowShotSkillTest.cs`

#### Unit Tests

1. `test_ArrowShot_damage_formula`
   - Assert: damage = 0.6 * player.Attack (with mock player Attack=100, expected=60)

2. `test_ArrowShot_cooldown_is_configurable`
   - Assert: default cooldown is 0.5s; can be changed via SerializeField

3. `test_ArrowShot_projectile_speed`
   - Assert: projectile speed defaults to 18

4. `test_ArrowShot_no_concrete_controller_casts`
   - Grep: ArrowShotSkill.cs has zero MagePlayerController or ArcherPlayerController references

5. `test_ArrowShot_extends_UpgradableSkill`
   - Assert: ArrowShotSkill is subclass of UpgradableSkill

---

### N1-004: Dodge Roll Skill

**Story type**: Logic
**Test path**: `Assets/Trizzle/Tests/Character/Skill/Archer/DodgeRollSkillTest.cs`

#### Unit Tests

1. `test_DodgeRoll_distance_default`
   - Assert: roll distance defaults to 2.0 units

2. `test_DodgeRoll_cooldown_default`
   - Assert: cooldown defaults to 1.5s

3. `test_DodgeRoll_iframe_duration`
   - Assert: i-frame duration defaults to 0.2s

4. `test_DodgeRoll_no_concrete_controller_casts`
   - Grep: DodgeRollSkill.cs has zero concrete controller references

#### Manual Verification

- Roll toward wall from 1 unit away: verify stops at wall, no clipping
- I-frames block damage during 0.2s window (hit by enemy attack during roll)

---

### N1-005: Archer Base Stats

**Story type**: Config/Data
**Evidence**: Smoke check

#### Spot Checks

- Inspector: GamePlayDatabase has Archer HP=75, MoveSpeed=3.6, Attack=80, AttackRange=10, Defense=3, CritChance=0.08
- CharacterDatabase: Archer entry exists with localized name/description
- Character picker: Archer is selectable alongside Mage

---

### N1-007: Draft Pool Filtering

**Story type**: Integration
**Test path**: `Assets/Trizzle/Tests/Character/DraftPoolFilteringTest.cs`

#### Integration Tests

1. `test_DraftPool_Mage_excludes_Archer_skills`
   - Assert: As Mage, Arrow/Dodge upgrades do NOT appear in draft pool

2. `test_DraftPool_Archer_excludes_Mage_skills`
   - Assert: As Archer, Fireball upgrades do NOT appear in draft pool

3. `test_DraftPool_shared_passives_appear_for_both`
   - Assert: Shared skills (Frenzy, BurnAttack, GoldRush) appear for both classes

4. `test_DraftRunController_no_class_specific_branches`
   - Grep: DraftRunController has zero `if (class == Archer)` or `if (class == Mage)` branches

---

### E3-001: BossController Subclass

**Story type**: Logic
**Test path**: `Assets/Trizzle/Tests/Combat/BossControllerTest.cs`

#### Unit Tests

1. `test_BossPhase_is_serializable_struct`
   - Assert: BossPhase is struct with [System.Serializable], has all 5 fields

2. `test_IBossPhaseController_has_required_members`
   - Assert: 2 properties + 1 bool + 2 events

3. `test_BossController_sorts_phases_ascending`
   - Assert: phases sorted by HealthThreshold ascending after init

4. `test_BossController_triggers_phase_on_threshold`
   - Assert: damage crossing a threshold fires OnPhaseTransition

5. `test_BossController_multi_threshold_skip`
   - Assert: single damage crossing 2 thresholds triggers both phases

6. `test_BossController_phase_check_uses_event_not_update`
   - Structural: no phase-check logic in Update()

---

### E3-002: Stagger State & Phase Transition

**Story type**: Logic
**Test path**: `Assets/Trizzle/Tests/Combat/BossStaggerTest.cs`

#### Unit Tests

1. `test_Stagger_boss_invulnerable_during_transition`
   - Assert: damage = 0 while IsInStagger == true

2. `test_Stagger_clears_debuffs`
   - Assert: StateMachine.ResetState() called during stagger

3. `test_Stagger_duration_is_0_5s`
   - Assert: stagger lasts exactly 0.5s, not affected by difficulty

4. `test_Stagger_healed_past_threshold_no_reversal`
   - Assert: HasTriggered remains true after healing above threshold

5. `test_Stagger_death_during_stagger_fires_defeated`
   - Assert: OnBossDefeated fires immediately if boss dies mid-stagger

---

### E3-003: EnemyData.IsBoss Verification

**Story type**: Logic (verification only)
**Evidence**: Grep output

#### Verification

1. Confirm `EnemyData.IsBoss` field exists (already added in E2-004)
2. Grep: OneShotKillEffect uses EnemyData.IsBoss, not tag/name checks
3. Grep: SpawnManager uses EnemyData.IsBoss (already confirmed in Sprint 1)
4. Grep: DraftRunController uses EnemyData.IsBoss for boss detection

---

### N1-009: Archer Character Tests

**Story type**: Logic (self-referential)
**Test path**: `Assets/Trizzle/Tests/Character/Archer/`

This IS the test story. Tests listed in N1-001 through N1-007 above are the implementation.

---

## Smoke Test Scope

1. Game launches to main menu without crash
2. New game starts successfully (both Mage and Archer if selectable)
3. Archer character moves, attacks (Arrow Shot), and dodges correctly
4. Mage character still works identically to Sprint 1 (regression)
5. Difficulty system still applies correctly (Normal vs Hard)
6. Save/load completes without data loss
7. No new frame rate drops or hitches

---

## Playtest Requirements

| Story | Playtest Goal | Min Sessions | Target Player |
|-------|--------------|--------------|---------------|
| N1-003 | Does Arrow Shot feel satisfying? Is auto-aim responsive? | 1 | Experienced |
| N1-004 | Does Dodge Roll feel responsive? Do i-frames feel fair? | 1 | Experienced |

---

## Definition of Done — This Sprint

- [ ] All acceptance criteria verified via automated test OR manual evidence
- [ ] Test files exist for all Logic and Integration stories
- [ ] Smoke check passes (`/smoke-check sprint`)
- [ ] No regressions (all 528+ existing tests still pass)
- [ ] F-010 compliance: zero MagePlayerController casts in shared skills
- [ ] Code reviewed and merged
- [ ] Story files updated to `Status: Complete`
