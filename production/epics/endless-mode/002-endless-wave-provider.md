# Story: EndlessWaveProvider

> **Epic**: endless-mode
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-endless-002 (enemyCount formula), TR-endless-003 (eliteRatio formula), TR-endless-004 (enemyTypeCount formula), TR-endless-006 (boss wave every 10 waves, cycle A-E, 2-phase), TR-endless-008 (30x30 arena, no traps)
**ADR Reference**: ADR-0002 -- Decision section (IWaveProvider interface, EndlessWaveProvider implementation); ADR-0007 -- Decision section (EndlessWaveProvider class, EndlessWaveConfig SO, GetNextWave/IsBossWave/GetBossConfig/GetTrapLayout methods)
**Control Manifest Rules**: R-002 (implement IWaveProvider for EndlessWaveProvider), R-007 (SpawnManager calls GetNextWave then applies IDifficultyProvider separately), F-004 (no Endless mode branch inside SpawnManager), F-006 (no mutable shared WaveSequence SO), G-008 (elite ratio cap 50%), G-013 (BossCycle array must contain exactly 5 entries)

## Description

Implement `EndlessWaveProvider` as a MonoBehaviour implementing `IWaveProvider`, providing procedural wave generation for Endless Mode using the N2 wave composition formulas. This is the wave data source -- SpawnManager calls this interface without knowing it is in Endless mode.

**Files to create:**

1. **`EndlessWaveConfig.cs`** -- ScriptableObject class. Fields:
   - `BossConfig[] BossCycle` (array of 5, in cycle order A-E, each with PhaseCount=2)
   - `EnemyData[] EnemyPool` (ordered by introduction wave, index 0 = weakest)
   - `string[] EliteTags` (tags identifying elite enemy variants)
   Use `[CreateAssetMenu(fileName = "EndlessWaveConfig", menuName = "Trizzle/EndlessWaveConfig")]`. Add `[Tooltip]` attributes.

2. **`EndlessWaveProvider.cs`** -- MonoBehaviour implementing `IWaveProvider`. Holds `[SerializeField] private EndlessWaveConfig _config`. Exposes `public void SetWave(int waveNumber)` for wave number sync from `EndlessSessionController`. Method implementations:
   - `GetNextWave()`:
     - `enemyCount = 4 + Mathf.FloorToInt(_currentWave * 0.5f)`
     - `eliteRatio = Mathf.Min(0.50f, _currentWave * 0.02f)`
     - `enemyTypeCount = Mathf.Min(5, 1 + Mathf.FloorToInt(_currentWave / 5f))`
     - Returns `WaveData` struct populated from `_config.EnemyPool` sliced by `enemyTypeCount`
   - `IsBossWave()`: returns `_currentWave > 0 && _currentWave % 10 == 0`
   - `GetBossConfig()`: deterministic cycling via `bossIndex = ((_currentWave / 10) - 1) % 5`, returns `_config.BossCycle[bossIndex]`
   - `GetTrapLayout()`: always returns `null` (Endless arena has no traps per GDD)

3. **`EndlessWaveConfig.asset`** -- ScriptableObject asset in `Assets/Trizzle/Data/Endless/`. Will need to be wired with BossConfig references once E3 boss assets exist.

**Key constraints:**
- `SetWave()` must be called by `EndlessSessionController` BEFORE `SpawnManager.SpawnNextWave()` (R-013)
- Boss cycling restarts at wave 60+: `((60/10)-1) % 5 = 4` (Boss E at wave 50), `((60/10)-1) % 5 = 0` (Boss A at wave 60)
- `Awake()` must validate `BossCycle.Length == 5` and log error + prevent run start if misconfigured (G-013)
- Enhanced boss stats at wave 60+ are automatic via `EndlessDifficultyProvider` stat scaling -- no special boss logic needed here

## Acceptance Criteria

- [ ] `EndlessWaveConfig` ScriptableObject exists with `BossCycle[5]`, `EnemyPool[]`, and `EliteTags[]`
- [ ] `EndlessWaveProvider` MonoBehaviour implements `IWaveProvider` with all 4 methods
- [ ] `SetWave(int waveNumber)` method exists and updates the internal wave counter
- [ ] `GetNextWave()` at wave 1: 4 enemies, 2% elite ratio, 1 enemy type
- [ ] `GetNextWave()` at wave 10: 9 enemies, 20% elite ratio, 3 enemy types
- [ ] `GetNextWave()` at wave 20: 14 enemies, 40% elite ratio, 5 enemy types (type cap)
- [ ] `GetNextWave()` at wave 30: 19 enemies, 50% elite ratio (cap), 5 enemy types
- [ ] `IsBossWave()` returns `true` for wave 10, 20, 30, 40, 50, 60
- [ ] `IsBossWave()` returns `false` for wave 1, 5, 11, 25
- [ ] `GetBossConfig()` at wave 10 returns BossCycle[0] (Boss A, Stone Guardian)
- [ ] `GetBossConfig()` at wave 50 returns BossCycle[4] (Boss E, Lich King)
- [ ] `GetBossConfig()` at wave 60 returns BossCycle[0] (cycle restart, Boss A)
- [ ] `GetTrapLayout()` always returns `null`
- [ ] `Awake()` validates `BossCycle.Length == 5` and logs error if misconfigured
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/endless/`

- Unit test: `GetNextWave()` at waves 1, 10, 20, 30 returns correct enemyCount, eliteRatio, enemyTypeCount
- Unit test: `IsBossWave()` returns true for waves 10, 20, 30, 60; false for 1, 5, 11, 25
- Unit test: `GetBossConfig()` returns correct boss index: wave 10 -> [0], wave 50 -> [4], wave 60 -> [0] (cycle restart)
- Unit test: `GetTrapLayout()` always returns null
- Unit test: Enemy count formula boundary -- wave 1 = 4, wave 2 = 5, large wave (100) = 54

## Dependencies

- **Blocked by**: E2-001 (IDifficultyProvider must exist -- ADR-0002 depends on ADR-0001 being Accepted)
- **Blocks**: 003-endless-session-controller, 004-boss-wave-cycling, 008-endless-mode-tests

## Engine Notes

Uses `MonoBehaviour`, `ScriptableObject`, `CreateAssetMenu`, `Mathf.FloorToInt`, `Mathf.Min`, and C# interface -- all stable Unity APIs with no post-cutoff changes. The `WaveData` struct is stack-allocated (R-021) for zero heap allocation per wave. `EndlessWaveConfig` SO holds prefab references that survive scene transitions via standard SO persistence.
