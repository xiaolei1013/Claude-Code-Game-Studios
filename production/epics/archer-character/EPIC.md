# Epic: Archer Character

> **Layer**: Core (Layer 1)
> **GDD**: design/gdd/archer-character.md
> **Architecture Module**: N1 Archer -- Gameplay Layer
> **Governing ADRs**: ADR-0005
> **Status**: Stories Created
> **Stories**: 9 stories (2 P0, 7 P1)

## Overview

The Archer is the second playable character, offering a faster, squishier alternative to the Mage. It extends `PlayerController` via `ArcherPlayerController` with `PlayerClassType.Archer`, using the same skill collection, draft, and combo systems. Two unique base skills -- Arrow Shot (fast single-target projectile) and Dodge Roll (short-range sidestep with i-frames) -- define the class identity. Architecturally, this system introduces the `ICharacterClass` interface so shared skills cast to `PlayerController` or `ICharacterClass` instead of `MagePlayerController`, eliminating a class of runtime cast exceptions. The DashSkill cast refactor is a blocking prerequisite. Seven archer-exclusive skills, `GamePlayDatabase` stat extensions, and `CharacterDatabase` entry round out the module. Depends on E5 (Incomplete Skills) for shared skill pool readiness.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Archer Class Extension Strategy | Archer is a `PlayerController` subclass alongside Mage; `ICharacterClass` eliminates `MagePlayerController` casts in shared skills; class filtering is data-driven via `CanApplyUpgrade()`. DashSkill cast refactored as prerequisite. | LOW -- uses MonoBehaviour inheritance and C# interfaces; all stable pre-cutoff APIs |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|-------------|
| TR-archer-001 | Add Archer to PlayerClassType enum; create ArcherPlayerController : PlayerController | ADR-0005: Class hierarchy defined (Decision items 1-2) |
| TR-archer-002 | ArrowShotSkill : UpgradableSkill with 0.5s cooldown, 0.6x Attack damage, speed 18 projectile, auto-aim | ADR-0005: Skill hierarchy defined (Decision item 5) |
| TR-archer-003 | DodgeRollSkill : UpgradableSkill with 2.0 unit distance, 0.2s i-frames, wall-blocking | ADR-0005: Skill hierarchy defined (Decision item 5) |
| TR-archer-004 | I-frames block ALL damage sources and status effect application during the 0.2s window | Not covered by ADR -- implementation story |
| TR-archer-005 | Archer base stats in GamePlayDatabase ScriptableObject: HP 75, Attack 80, etc. | ADR-0005: Six SerializeField properties specified (Decision item 7) |
| TR-archer-006 | Shared skill pool filtered by CanApplyUpgrade() compatibleUpgradeTypes | ADR-0005: Data-driven class filtering via CanApplyUpgrade() (Decision item 9) |
| TR-archer-007 | 7 new archer-exclusive skills: PiercingArrow, Multishot, PoisonArrow, Afterimage, CounterRoll, Quickdraw, EagleEye | ADR-0005: Asset names, paths, and compatibleUpgradeTypes defined (Decision item 6) |
| TR-archer-008 | Refactor DashSkill to cast to PlayerController or ICharacterClass instead of MagePlayerController | ADR-0005: Refactor scope and prerequisite sequencing defined (Decision item 4) |
| TR-archer-009 | DraftRunController filters draft options by class compatibility using CanApplyUpgrade() | ADR-0005: CanApplyUpgrade() filter approach defined (Decision item 9) |
| TR-archer-010 | Afterimage decoy: 1 HP, 2s duration, draws enemy aggro, destroyed by any hit | Not covered by ADR -- implementation story |
| TR-archer-011 | CharacterDatabase extended with Archer entry; localization for all 11 locales | ADR-0005: CharacterDatabase extension defined (Decision item 8) |
| TR-archer-012 | No MagePlayerController casts in shared code; all must use PlayerController or ICharacterClass | ADR-0005: ICharacterClass interface eliminates cast sites; grep verification required |

## Stories

| # | Story | Type | Priority | Size | TR Coverage | Status |
|---|-------|------|----------|------|-------------|--------|
| 001 | [ArcherPlayerController & ICharacterClass](001-archer-controller-icharacterclass.md) | Logic | P0 | M | TR-archer-001, TR-archer-002 | Ready |
| 002 | [DashSkill Cast Refactor](002-dashskill-refactor.md) | Logic | P0 | M | TR-archer-003 | Ready |
| 003 | [Arrow Shot Skill](003-arrow-shot-skill.md) | Logic | P1 | M | TR-archer-004 | Ready |
| 004 | [Dodge Roll Skill](004-dodge-roll-skill.md) | Logic | P1 | M | TR-archer-005 | Ready |
| 005 | [Archer Base Stats](005-archer-base-stats.md) | Config | P1 | S | TR-archer-006 | Ready |
| 006 | [Archer Exclusive Skills (7)](006-archer-exclusive-skills.md) | Logic | P1 | XL | TR-archer-007 | Ready |
| 007 | [Draft Pool Filtering](007-draft-pool-filtering.md) | Integration | P1 | M | TR-archer-008 | Ready |
| 008 | [Archer VFX & Animation](008-archer-vfx-animation.md) | Visual | P1 | L | TR-archer-009 | Ready |
| 009 | [Archer Character Tests](009-archer-character-tests.md) | Logic | P0 | M | TR-archer-001 -- TR-archer-012 (validation) | Ready |

## Dependency Graph

```
002 DashSkill Refactor (BLOCKING -- must complete first)
 |
 v
001 Controller & ICharacterClass
 |
 +---> 003 Arrow Shot Skill ---+
 |                              |
 +---> 004 Dodge Roll Skill ---+--> 006 Exclusive Skills (7)
 |                              |        |
 +---> 005 Base Stats          |        +--> 007 Draft Pool Filtering
 |                              |
 +---> 008 VFX & Animation <---+
 |
 +---> 009 Tests (blocked by ALL above)
```

**Critical Path**: 002 -> 001 -> 003/004 (parallel) -> 006 -> 007 -> 009

## Total Effort Estimate

| Size | Count | Est. Days Each | Total |
|------|-------|----------------|-------|
| S | 1 | 1-2 | 1-2 |
| M | 6 | 2-3 | 12-18 |
| L | 1 | 3-5 | 3-5 |
| XL | 1 | 5-8 | 5-8 |
| **Total** | **9** | | **21-33 days** |

## Definition of Done

- All stories implemented, reviewed, closed via /story-done
- All acceptance criteria from GDD verified
- All Logic/Integration stories have passing tests
- All Visual/Feel/UI stories have evidence docs
- `ICharacterClass` interface implemented on both Mage and Archer controllers
- DashSkill cast refactored -- no `MagePlayerController` casts in shared code (grep verified)
- Arrow Shot and Dodge Roll functional with correct stats
- All 7 exclusive skills implemented with ScriptableObject assets
- Draft pool correctly filters by class compatibility
- Archer playable through Room 1 on Normal without crashes
- ADR-0005 validation criteria all passing
