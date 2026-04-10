# Smoke Check: E2-002 Normal & Hard Config Presets

**Story**: 002-normal-hard-config-presets.md
**Date**: 2026-04-08
**Type**: Config/Data — Manual Verification

## Checklist

- [ ] Open `Assets/Trizzle/Data/Difficulty/DifficultyConfig_Normal.asset` in Inspector
  - [ ] StatMultiplierMin = 1.0
  - [ ] StatMultiplierMax = 1.2
  - [ ] EnemyCountMultiplier = 1.0
  - [ ] HealDropMultiplier = 1.0
  - [ ] PacingMultiplier = 1.0
  - [ ] RewardMultiplier = 1.0
- [ ] Open `Assets/Trizzle/Data/Difficulty/DifficultyConfig_Hard.asset` in Inspector
  - [ ] StatMultiplierMin = 1.2
  - [ ] StatMultiplierMax = 1.5
  - [ ] EnemyCountMultiplier = 1.25
  - [ ] HealDropMultiplier = 0.5
  - [ ] PacingMultiplier = 0.75
  - [ ] RewardMultiplier = 2.0
- [ ] Both assets are editable in Inspector without code changes
- [ ] Change a value, enter Play Mode, confirm CampaignDifficultyProvider reads the new value, revert
- [ ] Normal asset is assigned as `_config` on CampaignDifficultyProvider in the GlobalEntry scene

## Notes

The wiring of Normal asset to CampaignDifficultyProvider in the scene must be done
manually in Unity Editor (drag DifficultyConfig_Normal.asset onto the _config field).
This cannot be done via code/YAML editing of the scene file without risk of corruption.
