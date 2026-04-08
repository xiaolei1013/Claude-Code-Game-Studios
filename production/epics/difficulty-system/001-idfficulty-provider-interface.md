# Story: IDifficultyProvider Interface & Campaign Provider

> **Epic**: difficulty-system
> **Type**: Logic
> **Priority**: P0
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-difficulty-001 (DifficultyConfig SO with 6 multipliers), TR-difficulty-002 (systems query IDifficultyProvider, not enum)
**ADR Reference**: ADR-0001 -- Decision section (interface definition, CampaignDifficultyProvider, DifficultyConfig SO), Implementation Guidelines 1-6
**Control Manifest Rules**: R-001 (implement IDifficultyProvider), R-006 (all consumers read from GameManager.Instance.ActiveDifficultyProvider), R-015 (DifficultyConfig as SO, not struct), F-001 (no direct DifficultyConfig/enum access in consumers), F-002 (no static utility classes for game state), F-003 (no runtime writes to SO assets)

## Description

Create the foundational difficulty abstraction layer that all consumer systems will depend on. This is the Layer 0 interface -- no other E2 or N2 story can proceed until this is stable.

**Files to create:**

1. **`IDifficultyProvider.cs`** -- C# interface with 7 read-only properties: `StatMultiplierMin`, `StatMultiplierMax`, `EnemyCountMultiplier`, `HealDropMultiplier`, `PacingMultiplier`, `RewardMultiplier`, `IsBossExemptFromCount`. Full XML doc comments on each property. Place in `Assets/Trizzle/Scripts/` (core systems area).

2. **`DifficultyConfig.cs`** -- ScriptableObject class (promoted from struct per ADR-0001). Fields: `StatMultiplierMin`, `StatMultiplierMax`, `EnemyCountMultiplier`, `HealDropMultiplier`, `PacingMultiplier`, `RewardMultiplier`. Use `[CreateAssetMenu(fileName = "DifficultyConfig", menuName = "Trizzle/DifficultyConfig")]`. All fields are public floats with `[Tooltip]` attributes describing safe ranges from GDD Tuning Knobs section.

3. **`CampaignDifficultyProvider.cs`** -- MonoBehaviour implementing `IDifficultyProvider`. Holds a `[SerializeField] private DifficultyConfig _config` reference. Each property delegates directly to the SO field (e.g., `public float StatMultiplierMin => _config.StatMultiplierMin`). `IsBossExemptFromCount` always returns `true`. Add a null check with descriptive error in `Awake()` if `_config` is not assigned.

4. **Extend `GameManager`** -- Add `public IDifficultyProvider ActiveDifficultyProvider { get; private set; }` property and `public void SetDifficultyProvider(IDifficultyProvider provider)` method. In `Awake()`, initialize `ActiveDifficultyProvider` to the `CampaignDifficultyProvider` component (Normal preset) as a safe default. Add `Debug.Assert(ActiveDifficultyProvider != null)` after initialization.

**Key constraints from ADR-0001:**
- Consumers must NOT cache the provider reference at Awake -- they read fresh from GameManager each use
- `ActiveDifficultyProvider` must never be null during active gameplay
- No new architectural paradigms (no Zenject, no DOTS) -- pure MonoBehaviour + SO + interface

## Acceptance Criteria

- [ ] `IDifficultyProvider` interface exists with all 7 properties and XML doc comments
- [ ] `DifficultyConfig` is a ScriptableObject (not a struct) with all 6 float fields
- [ ] `CampaignDifficultyProvider` MonoBehaviour implements `IDifficultyProvider` and reads from a `DifficultyConfig` SO reference
- [ ] `CampaignDifficultyProvider.IsBossExemptFromCount` always returns `true`
- [ ] `CampaignDifficultyProvider.Awake()` logs a descriptive error if `_config` is null
- [ ] `GameManager.ActiveDifficultyProvider` property exists and is initialized to the Normal campaign provider in `Awake()`
- [ ] `GameManager.SetDifficultyProvider()` method exists and updates the active provider
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1
- [ ] GDD Acceptance Criterion 9: "All 6 multiplier values are editable in a ScriptableObject without code changes"

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/difficulty/`

- Unit test: Instantiate `CampaignDifficultyProvider` with a test `DifficultyConfig` SO, verify all 7 properties return expected values
- Unit test: `IsBossExemptFromCount` returns `true`
- Unit test: `CampaignDifficultyProvider` with Hard config returns `EnemyCountMultiplier == 1.25`, `HealDropMultiplier == 0.5`, `RewardMultiplier == 2.0` (from ADR-0001 Validation Criteria)

## Dependencies

- **Blocked by**: None -- this is Layer 0, the foundational story
- **Blocks**: 002-normal-hard-config-presets, 003-enemy-stat-scaling, 004-enemy-count-scaling, 005-healing-drop-rate, 006-spawn-pacing, 007-reward-scaling, 008-hard-mode-unlock-gating, 009-difficulty-system-tests

## Engine Notes

Uses `MonoBehaviour`, `ScriptableObject`, `CreateAssetMenu`, and C# interface -- all stable Unity APIs with no post-cutoff changes (confirmed in ADR-0001 Engine Compatibility section). Knowledge Risk is HIGH for Unity 6 but LOW for these specific APIs. Verify ScriptableObject serialisation works correctly in Unity 6000.3.11f1 and confirm MonoBehaviour lifecycle order when providers are set on Awake vs Start.
