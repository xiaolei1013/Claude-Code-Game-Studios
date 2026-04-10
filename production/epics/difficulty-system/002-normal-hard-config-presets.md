# Story: Normal & Hard Config Presets

> **Epic**: difficulty-system
> **Type**: Config
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: S

## Context

**GDD Requirement**: TR-difficulty-001 (DifficultyConfig SO with all 6 multipliers editable in Inspector)
**ADR Reference**: ADR-0001 -- Migration Plan steps 2-3 (create SO assets with GDD values)
**Control Manifest Rules**: R-015 (create DifficultyConfig_Normal.asset and DifficultyConfig_Hard.asset), F-003 (SOs are read-only data, no runtime writes)

## Description

Create the two `DifficultyConfig` ScriptableObject assets for the campaign difficulty presets. These are the data files that `CampaignDifficultyProvider` reads from. All values come directly from the GDD Detailed Design table and Tuning Knobs section.

**Assets to create in `Assets/Trizzle/Data/` (or a `Difficulty/` subfolder):**

1. **`DifficultyConfig_Normal.asset`** -- `DifficultyConfig` ScriptableObject with values:
   - `StatMultiplierMin`: 1.0
   - `StatMultiplierMax`: 1.2
   - `EnemyCountMultiplier`: 1.0
   - `HealDropMultiplier`: 1.0
   - `PacingMultiplier`: 1.0
   - `RewardMultiplier`: 1.0

2. **`DifficultyConfig_Hard.asset`** -- `DifficultyConfig` ScriptableObject with values:
   - `StatMultiplierMin`: 1.2
   - `StatMultiplierMax`: 1.5
   - `EnemyCountMultiplier`: 1.25
   - `HealDropMultiplier`: 0.5
   - `PacingMultiplier`: 0.75
   - `RewardMultiplier`: 2.0

**Wire the Normal asset** as the default `_config` reference on `CampaignDifficultyProvider` in the scene. The Hard asset is swapped in by `MenuPrepareStagePanelPC` when the player selects Hard difficulty (wiring covered in Story 008).

## Acceptance Criteria

- [ ] `DifficultyConfig_Normal.asset` exists with all 6 values matching GDD Normal column exactly
- [ ] `DifficultyConfig_Hard.asset` exists with all 6 values matching GDD Hard column exactly
- [ ] Both assets are Inspector-editable without code changes (GDD Acceptance Criterion 9)
- [ ] Changing a value in the asset and entering Play Mode applies it immediately
- [ ] Normal asset is wired as the default on `CampaignDifficultyProvider` in the GameManager scene

## Test Evidence

**Type**: Smoke Check
**Path**: `production/qa/evidence/`

- Manual verification: Open each asset in Inspector, confirm all 6 values match the GDD table
- Manual verification: Change one value, enter Play Mode, confirm it takes effect, revert

## Dependencies

- **Blocked by**: 001-idfficulty-provider-interface (DifficultyConfig SO class must exist first)
- **Blocks**: 003-enemy-stat-scaling, 004-enemy-count-scaling, 005-healing-drop-rate, 006-spawn-pacing, 007-reward-scaling (all consumers need config data to test against)

## Engine Notes

ScriptableObject asset creation is standard Unity workflow. Use `Assets > Create > Trizzle > DifficultyConfig` menu (provided by the `CreateAssetMenu` attribute in Story 001). Verify serialised float values persist correctly after Unity domain reload.

## Completion Notes
**Completed**: 2026-04-08
**Criteria**: 5/5 passing
**Deviations**: None
**Test Evidence**: Config/Data — smoke check at production/qa/evidence/e2-002-normal-hard-config-presets.md
**Code Review**: Skipped (Lean mode, Config/Data story)
