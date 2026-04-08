# Story: EndlessSessionController

> **Epic**: endless-mode
> **Type**: Logic
> **Priority**: P0
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L

## Context

**GDD Requirement**: TR-endless-005 (draft every 5 waves), TR-endless-007 (3s breathing window), TR-endless-010 (no mid-run save), TR-endless-013 (EndlessSessionController coordinates wave loop)
**ADR Reference**: ADR-0007 -- Decision section (EndlessSessionController class, WaveLoop coroutine, StartRun entry point, OnPlayerDied termination, score persistence contract)
**Control Manifest Rules**: R-013 (SetWave on both providers before SpawnNextWave -- ORDER IS MANDATORY), F-014 (do not make DraftRunController aware of Endless wave numbers), G-001 (frame time budgets)

## Description

Implement `EndlessSessionController` as the single coordinator MonoBehaviour for an Endless Mode run. This class owns the wave counter, breathing window, draft trigger logic, boss detection delegation, and score accumulation. It does NOT own spawn logic (delegated to SpawnManager via IWaveProvider) or difficulty computation (delegated to EndlessDifficultyProvider via IDifficultyProvider).

**File to create:**

**`EndlessSessionController.cs`** -- MonoBehaviour placed in the Endless arena scene. Inspector references:
- `[SerializeField] private EndlessWaveProvider _waveProvider`
- `[SerializeField] private EndlessDifficultyProvider _difficultyProvider`

**Methods:**

1. **`StartRun(PlayerClassType classType)`** -- Entry point called from main menu Endless Mode button:
   - Store `_classType`, reset `_waveNumber = 0`, `_score = 0`
   - Call `GameManager.Instance.SetDifficultyProvider(_difficultyProvider)`
   - Call `SpawnManager.Instance.SetWaveProvider(_waveProvider)`
   - Start `WaveLoop()` coroutine

2. **`WaveLoop()` (private IEnumerator)** -- The core loop:
   ```
   while (true):
     _waveNumber++
     _difficultyProvider.SetWave(_waveNumber)  // MUST be before SpawnNextWave
     _waveProvider.SetWave(_waveNumber)          // MUST be before SpawnNextWave
     SpawnManager.Instance.SpawnNextWave()
     yield return WaitUntil(SpawnManager.Instance.IsWaveComplete)
     _score = _waveNumber
     UpdateScoreHUD(_score)
     yield return WaitForSeconds(3f)  // breathing window
     if (_waveNumber % 5 == 0):
       DraftRunController.Instance.ShowDraft()
       yield return WaitUntil(DraftRunController.Instance.IsDraftComplete)
   ```

3. **`OnPlayerDied()`** -- Subscribed to player death event:
   - `StopAllCoroutines()`
   - `LevelStats.SaveEndlessScore(_classType, _score)`
   - Show death screen with stats

**Key design decisions:**
- All run state is in-memory only -- no persistence path, no mid-run save (TR-endless-010)
- Draft timing is owned here, not by DraftRunController (F-014 -- layer rule enforcement)
- Boss wave detection is handled by `EndlessWaveProvider.IsBossWave()` inside SpawnManager -- this controller does not need to check boss waves
- Draft appears AFTER boss wave completes on wave 10, 20, etc. (GDD Edge Case 1: boss death counts as wave clear trigger for draft)
- Add 60s timeout safeguard on `WaitUntil(IsDraftComplete)` with error log and forced close (ADR-0007 Risk)

**Null guards in `Awake()`:**
- Verify `_waveProvider` is assigned
- Verify `_difficultyProvider` is assigned
- Log descriptive error and disable component if either is missing

## Acceptance Criteria

- [ ] `EndlessSessionController` MonoBehaviour exists with `StartRun(PlayerClassType)` entry point
- [ ] `WaveLoop()` coroutine increments wave counter and syncs both providers before calling `SpawnNextWave()`
- [ ] `_difficultyProvider.SetWave()` is called BEFORE `SpawnManager.SpawnNextWave()` every wave
- [ ] `_waveProvider.SetWave()` is called BEFORE `SpawnManager.SpawnNextWave()` every wave
- [ ] 3-second breathing window between waves (yield WaitForSeconds(3f))
- [ ] `DraftRunController.ShowDraft()` called when `_waveNumber % 5 == 0` after breathing window
- [ ] Draft at wave 10 occurs AFTER boss wave completes (edge case 1)
- [ ] `OnPlayerDied()` stops all coroutines, saves score, shows death screen
- [ ] Score persists only if `wavesCleared > existingHighScore` (via `LevelStats.SaveEndlessScore()`)
- [ ] `Awake()` null guards on `_waveProvider` and `_difficultyProvider` with descriptive errors
- [ ] 60s timeout on `WaitUntil(IsDraftComplete)` with error log fallback
- [ ] No mid-run save -- all run state is in memory only
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test + Integration Test
**Path**: `tests/unit/endless/`, `tests/integration/endless/`

- Unit test: `StartRun()` resets wave counter to 0 and score to 0
- Unit test: Wave counter increments correctly through sequential waves
- Unit test: `SetWave()` is called on both providers with matching wave number
- Integration test: Simulate 6-wave run -- verify draft screen triggers after wave 5 clears
- Integration test: Simulate 11-wave run -- verify boss spawns at wave 10, draft at wave 10 after boss
- Integration test: Verify score persistence -- die at wave 17, check `LevelStats` reads 17

## Dependencies

- **Blocked by**: 001-endless-difficulty-provider, 002-endless-wave-provider
- **Blocks**: 007-endless-draft-integration, 008-endless-mode-tests

## Engine Notes

Uses `MonoBehaviour`, `StartCoroutine`, `StopAllCoroutines`, `WaitForSeconds`, `WaitUntil` -- all stable Unity coroutine APIs. The coroutine-based wave loop is the same pattern used by existing campaign wave management. Per ADR-0007 Engine Compatibility: confirm coroutine timing behavior under Unity 6000.3.11f1 frame scheduler. The `DraftRunController.Instance` and `SpawnManager.Instance` singleton lookups follow the project's established 46-manager pattern.
