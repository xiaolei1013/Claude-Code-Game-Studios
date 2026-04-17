# Story: EndlessDifficultyProvider

> **Epic**: endless-mode
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-endless-001 (EndlessDifficultyConfig SO with wave-based scaling formulas), TR-endless-011 (SpawnManager reads EndlessDifficultyConfig in Endless mode, NOT campaign DifficultyConfig)
**ADR Reference**: ADR-0001 -- Decision section (EndlessDifficultyProvider class, EndlessDifficultyConfig SO, all formula implementations); Implementation Guidelines 5-6 (wave number sync, no caching in consumers)
**Control Manifest Rules**: R-001 (implement IDifficultyProvider for EndlessDifficultyProvider), R-006 (all consumers read from GameManager.Instance.ActiveDifficultyProvider), R-013 (SetWave before SpawnNextWave), R-015 (EndlessDifficultyConfig.asset), F-001 (no direct DifficultyConfig/enum access), F-003 (no runtime writes to SO assets), G-003 (< 1 microsecond computation), G-006 (pacing floor 0.5), G-007 (heal drop floor 0.1)

## Description

Implement `EndlessDifficultyProvider` as a MonoBehaviour implementing `IDifficultyProvider`, providing wave-based difficulty scaling for Endless Mode. This provider computes per-wave values from the N2 difficulty curve formulas at call time rather than reading flat values from a config.

**Files to create:**

1. **`EndlessDifficultyConfig.cs`** -- ScriptableObject class holding all Endless tuning knobs. Fields: `StatScalingRate` (default 0.04), `HealDropReductionRate` (default 0.03), `HealDropFloor` (default 0.1), `PacingReductionRate` (default 0.015), `PacingFloor` (default 0.5), `RewardMultiplier` (default 1.5). Use `[CreateAssetMenu(fileName = "EndlessDifficultyConfig", menuName = "Trizzle/EndlessDifficultyConfig")]`. All fields with `[Tooltip]` attributes describing safe ranges from GDD Tuning Knobs section.

2. **`EndlessDifficultyProvider.cs`** -- MonoBehaviour implementing `IDifficultyProvider`. Holds a `[SerializeField] private EndlessDifficultyConfig _config` reference. Exposes `public void SetWave(int waveNumber)` for wave number sync. Property implementations:
   - `StatMultiplierMin` and `StatMultiplierMax`: `1.0f + (_currentWave * _config.StatScalingRate)` (both identical -- Endless has no random range)
   - `EnemyCountMultiplier`: always `1.0f` (enemy count handled by EndlessWaveProvider formulas)
   - `HealDropMultiplier`: `Mathf.Max(_config.HealDropFloor, 1.0f - (_currentWave * _config.HealDropReductionRate))`
   - `PacingMultiplier`: `Mathf.Max(_config.PacingFloor, 1.0f - (_currentWave * _config.PacingReductionRate))`
   - `RewardMultiplier`: `_config.RewardMultiplier` (flat, not scaling)
   - `IsBossExemptFromCount`: always `true`

3. **`EndlessDifficultyConfig.asset`** -- ScriptableObject asset in `Assets/Trizzle/Data/Endless/` with default values matching GDD Tuning Knobs.

**Key constraints:**
- `SetWave()` must be called by `EndlessSessionController` BEFORE each `SpawnManager.SpawnNextWave()` call (R-013)
- All formula shapes are linear (per GDD design intent: "Stat scaling is linear so builds have time to come online")
- Tuning knobs (rates, floors) live in the SO; formula shapes live in code and change only via ADR

## Acceptance Criteria

- [ ] `EndlessDifficultyConfig` ScriptableObject class exists with all 6 tuning knob fields and `[Tooltip]` attributes
- [ ] `EndlessDifficultyProvider` MonoBehaviour implements `IDifficultyProvider` with all 7 properties
- [ ] `SetWave(int waveNumber)` method exists and correctly updates the internal wave counter
- [ ] Wave 1: `StatMultiplierMin == 1.04`, `HealDropMultiplier == 0.97`, `PacingMultiplier == 0.985`
- [ ] Wave 10: `StatMultiplierMin == 1.4`, `HealDropMultiplier == 0.7`, `PacingMultiplier == 0.85`
- [ ] Wave 25: `StatMultiplierMin == 2.0`, `HealDropMultiplier == 0.25`, `PacingMultiplier == 0.625`
- [ ] Wave 33: `PacingMultiplier == 0.5` (floor clamped)
- [ ] Wave 30: `HealDropMultiplier == 0.1` (floor clamped)
- [ ] `EnemyCountMultiplier` always returns `1.0`
- [ ] `RewardMultiplier` always returns `1.5` regardless of wave
- [ ] `IsBossExemptFromCount` always returns `true`
- [ ] `EndlessDifficultyConfig.asset` exists with default values matching N2 GDD Tuning Knobs
- [ ] Null check with descriptive error in `Awake()` if `_config` is not assigned
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/endless/`

- Unit test: `EndlessDifficultyProvider` with wave=1 returns `StatMultiplierMin == 1.04`, `HealDropMultiplier == 0.97`, `PacingMultiplier == 0.985`
- Unit test: `EndlessDifficultyProvider` with wave=10 returns `StatMultiplierMin == 1.4`, `HealDropMultiplier == 0.7`, `PacingMultiplier == 0.85`
- Unit test: `EndlessDifficultyProvider` with wave=33 returns `PacingMultiplier == 0.5` (floor clamp verified)
- Unit test: `EndlessDifficultyProvider` with wave=30 returns `HealDropMultiplier == 0.1` (floor clamp verified)
- Unit test: `EnemyCountMultiplier` always returns `1.0` regardless of wave
- Unit test: `RewardMultiplier` always returns `1.5` regardless of wave
- Unit test: `IsBossExemptFromCount` returns `true`

## Dependencies

- **Blocked by**: E2-001 (IDifficultyProvider interface must exist first)
- **Blocks**: 003-endless-session-controller, 008-endless-mode-tests

## Engine Notes

Uses `MonoBehaviour`, `ScriptableObject`, `CreateAssetMenu`, `Mathf.Max`, and C# interface -- all stable Unity APIs with no post-cutoff changes (confirmed in ADR-0001 Engine Compatibility section). Knowledge Risk is HIGH for Unity 6 but LOW for these specific APIs.
