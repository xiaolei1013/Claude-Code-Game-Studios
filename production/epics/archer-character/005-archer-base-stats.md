# Story: Archer Base Stats

> **Epic**: archer-character
> **Type**: Config
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: S

## Context

**GDD Requirement**: TR-archer-006 (Shared skill pool filtered by CanApplyUpgrade() compatibleUpgradeTypes; Mage-only skills excluded from Archer draft pool and vice versa)
**ADR Reference**: ADR-0005 -- Decision items 7-8 (GamePlayDatabase extended with 6 Archer stat fields; CharacterDatabase extended with Archer entry and 11-locale localization)
**Control Manifest Rules**: F-003 (no runtime writes to SO assets -- stats are authored in Inspector), F-017 (MonoBehaviour + SO + interface only)

## Description

Add Archer-specific stat fields to `GamePlayDatabase` and create the Archer entry in `CharacterDatabase`. This is a data-only story -- no behavioral code changes. The stats become functional when `ArcherPlayerController.InitAttributes()` reads them (story 001).

**Files to modify:**

1. **`GamePlayDatabase.cs`** -- Add 6 new `[SerializeField]` fields with public read-only properties, per ADR-0005 Decision item 7:

   ```csharp
   [Header("Archer Base Stats")]
   [SerializeField] private float _archerBaseHealth         = 75f;
   [SerializeField] private float _archerBaseMoveSpeed      = 3.6f;
   [SerializeField] private float _archerBaseAttack         = 80f;
   [SerializeField] private float _archerBaseAttackRange    = 10f;
   [SerializeField] private float _archerBaseDefense        = 3f;
   [SerializeField] private float _archerBaseCritChance     = 0.08f;
   ```

   All defaults are Inspector-editable. Existing Mage fields are NOT modified.

2. **`GamePlayDatabase.asset`** -- Set the Archer stat defaults in the ScriptableObject asset (Inspector values matching the code defaults above).

**Files to create/modify:**

3. **`CharacterDatabase.asset`** -- Add an Archer `CharacterData` entry alongside the existing Mage entry. The entry references:
   - `ArcherPlayerController` prefab (created in story 001)
   - Localized name/description strings for all 11 locales: EN, ZH-S, ZH-T, FR, DE, IT, JA, KO, PT-BR, PT-PT, RU
   - Character artwork placeholder (to be replaced by 008-archer-vfx-animation)

**Stat rationale from GDD:**

| Attribute | Mage | Archer | Delta | Rationale |
|-----------|------|--------|-------|-----------|
| Health | 100 | 75 | -25% | Squishier -- dodge roll compensates |
| Attack | 100 | 80 | -20% | Lower per-hit, higher fire rate = ~20% more DPS |
| AttackRange | 8 | 10 | +25% | Longer range rewards kiting |
| MoveSpeed | 3.0 | 3.6 | +20% | Faster base movement |
| Defense | 5 | 3 | -40% | Glass cannon -- mistakes hurt more |
| CriticalChance | 0.05 | 0.08 | +60% | Rapid hits + higher crit = rewarding crit builds |

**Localization requirement:**
- 11 locales per GDD and ADR-0005 Decision item 8
- Localization keys follow the existing pattern established for the Mage entry
- At minimum: character name ("Archer" / equivalent) and character description (1-2 sentences describing the class fantasy)

## Acceptance Criteria

- [ ] `GamePlayDatabase.cs` has 6 new `[SerializeField]` float fields for Archer stats with public getters
- [ ] Default values match GDD: HP=75, MoveSpeed=3.6, Attack=80, AttackRange=10, Defense=3, CritChance=0.08
- [ ] All Archer stat fields are editable in Unity Inspector without code changes
- [ ] Existing Mage stat fields are unmodified
- [ ] `CharacterDatabase.asset` contains an Archer entry with localized name/description for all 11 locales
- [ ] Archer entry references `ArcherPlayerController` prefab
- [ ] GDD Acceptance Criterion 1: "CharacterDatabase shows Archer alongside Mage. Archer has name, description, and visual in all 11 locales."
- [ ] GDD Acceptance Criterion 5: "Archer has lower HP (-25%), higher move speed (+20%), higher crit (+60%), lower defense (-40%) compared to Mage. Verify via Inspector on GamePlayDatabase."

## Test Evidence

**Type**: Smoke Check
**Path**: `production/qa/evidence/`

- Inspector verification: Open `GamePlayDatabase.asset` in Unity Inspector, confirm all 6 Archer stat fields are visible and editable with correct defaults
- Inspector verification: Open `CharacterDatabase.asset`, confirm Archer entry appears alongside Mage with all 11 locale strings populated
- Smoke check: Modify `_archerBaseHealth` to 50 in Inspector, confirm no compilation errors (value is read at runtime, not build time)

## Dependencies

- **Blocked by**: 001-archer-controller-icharacterclass (ArcherPlayerController prefab must exist to be referenced by CharacterDatabase)
- **Blocks**: 009-archer-character-tests (integration test needs Archer stats configured)

## Engine Notes

Uses `ScriptableObject` `[SerializeField]` fields and Unity Inspector serialization -- all stable APIs. CharacterDatabase likely uses Unity's built-in localization system or a custom LocalizedString pattern. Follow the existing Mage entry's localization approach exactly. Verify that adding new fields to an existing SO does not corrupt the `.asset` file (standard Unity behavior: new fields get default values, existing fields preserved).
