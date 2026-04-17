# Story: CampaignWaveProvider

> **Epic**: room-content
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-room-003 (Hard mode derived from Normal baseline via IDifficultyProvider multipliers), TR-room-011 (boss spawns after final wave cleared, no dead time), TR-room-008 (room replay deterministic), TR-room-010 (wave composition per-wave with SpawnItemInfo)
**ADR Reference**: ADR-0002 -- Decision section (CampaignWaveProvider implements IWaveProvider, wraps RoomConfig), ADR-0006 -- Hard Mode Derivation section (GetNextWave applies EnemyCountMultiplier and PacingMultiplier)
**Control Manifest Rules**: R-002 (implement IWaveProvider for all wave data suppliers), R-007 (SpawnManager calls GetNextWave then applies IDifficultyProvider separately), R-006 (all difficulty reads through IDifficultyProvider), F-004 (no mode branch in SpawnManager), F-015 (no per-difficulty RoomConfig variants), G-005 (GetNextWave < 2ns campaign)

## Description

Implement `CampaignWaveProvider` as the bridge between `RoomConfig` ScriptableObjects and `SpawnManager`'s `IWaveProvider` interface. This MonoBehaviour wraps one `RoomConfig` per room entry and serves wave data with Hard mode scaling applied at runtime -- the key mechanism that makes "author once, play on both difficulties" work.

**Files to create:**

1. **`CampaignWaveProvider.cs`** -- MonoBehaviour implementing `IWaveProvider`. Place in `Assets/Trizzle/Scripts/Rooms/`.

   **State:**
   - `private RoomConfig _config` -- the currently loaded room's config (set via `SetRoom()`)
   - `private int _currentWaveIndex` -- tracks which wave to serve next (reset on `SetRoom()`)

   **IWaveProvider methods:**
   - `GetNextWave()` -- Reads `_config.Waves[_currentWaveIndex]`, applies `IDifficultyProvider.EnemyCountMultiplier` to each `SpawnItemInfo.SpawnCount` via `Mathf.CeilToInt()`, applies `IDifficultyProvider.PacingMultiplier` to spawn delays. Returns a `WaveData` struct (stack-allocated per R-021). Increments `_currentWaveIndex`.
   - `IsBossWave()` -- Returns `true` when `_currentWaveIndex >= _config.Waves.Count && _config.BossConfig != null`. This is how the boss triggers after the final wave with no dead time (TR-room-011).
   - `GetBossConfig()` -- Returns `_config.BossConfig` directly. The BossConfig reference is opaque (ADR-0003 schema).
   - `GetTrapLayout()` -- Returns `_config.TrapPlacements` wrapped as a `TrapLayout`. Called once at room entry before wave 1.

   **Public API:**
   - `SetRoom(RoomConfig config)` -- Sets `_config` and resets `_currentWaveIndex = 0`. Called by `MenuPrepareStagePanelPC` on campaign room entry.

   **Null safety:**
   - `GetNextWave()` null-checks each `SpawnItemInfo.EnemyPrefab` and logs `Debug.LogError` with room name and wave index if null (ADR-0006 Risk mitigation)
   - `IsBossWave()` returns `false` if `BossConfig == null` (safe fallback)

**Key constraints:**
- On Normal difficulty, `EnemyCountMultiplier == 1.0` and `PacingMultiplier == 1.0`, so output equals authored baseline exactly -- no drift
- On Hard, `EnemyCountMultiplier == 1.25` and `PacingMultiplier == 0.75` are applied automatically
- No `if (difficulty == Hard)` branch anywhere in this code
- `WaveData` is a struct, not a class -- zero heap allocation per wave (R-021)
- Deterministic: same RoomConfig asset produces identical output every replay (TR-room-008)

## Acceptance Criteria

- [ ] `CampaignWaveProvider` exists as a MonoBehaviour implementing `IWaveProvider`
- [ ] `SetRoom(RoomConfig)` assigns the config and resets wave index to 0
- [ ] `GetNextWave()` reads from `_config.Waves` and applies `IDifficultyProvider.EnemyCountMultiplier` via `Mathf.CeilToInt()`
- [ ] `GetNextWave()` applies `IDifficultyProvider.PacingMultiplier` to spawn delays
- [ ] `GetNextWave()` returns a `WaveData` struct (not class) with BaseEnemyCount, EliteRatio, EnemyTypes, BaseSpawnDelay
- [ ] `IsBossWave()` returns `true` only after all waves exhausted and `BossConfig != null`
- [ ] `GetBossConfig()` returns the `RoomConfig.BossConfig` reference
- [ ] `GetTrapLayout()` returns the `RoomConfig.TrapPlacements` list wrapped as `TrapLayout`
- [ ] Null `EnemyPrefab` in SpawnItemInfo logs `Debug.LogError` with room name and wave index
- [ ] With Normal `IDifficultyProvider` (multipliers = 1.0), output count equals authored baseline exactly
- [ ] With Hard `IDifficultyProvider` (EnemyCountMultiplier = 1.25), wave of 4 enemies returns count of 5 (`Ceil(4 * 1.25)`)
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/rooms/`

- Unit test: Construct `CampaignWaveProvider` with a test `RoomConfig` (3 waves, 4 enemies per wave). Inject mock `IDifficultyProvider` with `EnemyCountMultiplier = 1.0`. Verify `GetNextWave()` returns `BaseEnemyCount == 4` for each wave (ADR-0006 Validation Criteria).
- Unit test: Same setup with `EnemyCountMultiplier = 1.25`. Verify `GetNextWave()` returns `BaseEnemyCount == 5` (`Ceil(4 * 1.25)`) (ADR-0006 Validation Criteria).
- Unit test: After calling `GetNextWave()` for all waves, verify `IsBossWave()` returns `true` when `BossConfig` is non-null.
- Unit test: Verify `IsBossWave()` returns `false` when `BossConfig` is null (safe fallback).
- Unit test: Verify `GetTrapLayout()` returns the correct trap count matching `RoomConfig.TrapPlacements.Count` (ADR-0006 Validation Criteria).
- Unit test: Verify `SetRoom()` resets `_currentWaveIndex` to 0 (replay determinism).
- Unit test: Apply `PacingMultiplier = 0.75` and verify BaseSpawnDelay is scaled correctly.

## Dependencies

- **Blocked by**: 001-roomconfig-scriptableobject (RoomConfig, WaveDefinition, TrapPlacement types must exist), ADR-0001 (IDifficultyProvider interface), ADR-0002 (IWaveProvider interface and WaveData struct)
- **Blocks**: 003-rooms-1-5-configuration (CampaignWaveProvider must be functional before room configs can be integration tested), 006-room-content-tests

## Engine Notes

Uses `MonoBehaviour`, `Mathf.CeilToInt()`, `ScriptableObject` references, and C# interface implementation -- all stable Unity APIs. `WaveData` is a plain C# struct (no Unity serialisation needed) for stack allocation. Verify that `GameManager.Instance.ActiveDifficultyProvider` is accessible from a MonoBehaviour at runtime in Unity 6000.3.11f1. No post-cutoff API dependencies.

## Completion Notes

**Completed**: 2026-04-18
**Criteria**: 12/12 passing
**Deviations**:
- Created IWaveProvider.cs, WaveData.cs, TrapLayout.cs (types defined in ADR-0002 but not previously implemented). Required for CampaignWaveProvider to compile.
**Test Evidence**: Logic: 8 unit tests at `Assets/Trizzle/Tests/Rooms/CampaignWaveProviderTest.cs`
**Code Review**: Pending (run `/simplify` or `/review` before merge)
