# Story: Boss Wave Cycling

> **Epic**: endless-mode
> **Type**: Logic
> **Priority**: P1
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-endless-006 (boss wave every 10 waves: cycle A-E, 2-phase only in Endless, cycle restarts at wave 60+)
**ADR Reference**: ADR-0007 -- Decision section (EndlessWaveProvider.GetBossConfig with deterministic index, EndlessWaveConfig.BossCycle[5], each SO has PhaseCount=2); ADR-0004 (BossController prefabs with BossPhase data)
**Control Manifest Rules**: G-012 (BossController phases: 2 for Endless), G-013 (BossCycle array must contain exactly 5 entries)

## Description

Author the 5 Endless-specific boss configuration assets and validate the full boss cycling system through wave 60+. While `EndlessWaveProvider.GetBossConfig()` is implemented in Story 002, this story covers the data authoring, scene wiring, and extended cycling validation that ensures bosses actually work end-to-end.

**Work items:**

1. **Author 5 `EndlessBossConfig` ScriptableObject assets** in `Assets/Trizzle/Data/Endless/`:
   - `EndlessBossConfig_A.asset` -- Stone Guardian (melee), PhaseCount=2
   - `EndlessBossConfig_B.asset` -- Dark Sorcerer (ranged), PhaseCount=2
   - `EndlessBossConfig_C.asset` -- Necromancer (summoner), PhaseCount=2
   - `EndlessBossConfig_D.asset` -- War Chief (tank), PhaseCount=2
   - `EndlessBossConfig_E.asset` -- Lich King (all-rounder), PhaseCount=2

   Each asset must reference the corresponding `BossController` prefab and have exactly 2 phases configured (not 3 as in campaign rooms 6-10). Phase thresholds and ability templates follow existing E3 boss prefab conventions.

2. **Wire `EndlessWaveConfig.asset`** -- Assign all 5 boss configs to the `BossCycle` array in order (index 0=A, 1=B, 2=C, 3=D, 4=E). Verify array length validation in `EndlessWaveProvider.Awake()`.

3. **Validate boss stat scaling at wave 60+** -- When the cycle restarts (Boss A returns at wave 60), `EndlessDifficultyProvider` stat scaling applies automatically:
   - Wave 10 Boss A: `statMultiplier = 1.4x`
   - Wave 60 Boss A: `statMultiplier = 3.4x`
   No special boss-cycling logic needed -- the difficulty provider handles scaling.

4. **Boss-only wave spawning** -- On boss waves, `EndlessWaveProvider.IsBossWave()` returns true. SpawnManager must spawn only the boss (no regular enemies alongside). Verify this interaction via integration test.

**Key constraints:**
- Endless bosses are always 2-phase (GDD: "difficulty comes from stat scaling, not phase complexity")
- Boss waves spawn the boss ONLY -- no wave enemies (GDD Detailed Design: "Boss waves spawn the boss only, no wave enemies")
- Enhanced stats at wave 60+ come from the difficulty curve, not from boss-specific scaling

## Acceptance Criteria

- [ ] 5 `EndlessBossConfig` SO assets exist with correct boss identity and PhaseCount=2
- [ ] `EndlessWaveConfig.asset` has all 5 boss configs wired in `BossCycle` array (A=0, B=1, C=2, D=3, E=4)
- [ ] Boss A spawns at wave 10, Boss B at wave 20, Boss C at wave 30, Boss D at wave 40, Boss E at wave 50
- [ ] Boss A spawns again at wave 60 (cycle restart confirmed)
- [ ] Boss waves spawn only the boss -- no regular enemies alongside
- [ ] Wave 60 Boss A has higher stats than wave 10 Boss A (verified via `EndlessDifficultyProvider` stat multiplier: 3.4x vs 1.4x)
- [ ] Each boss asset references a valid `BossController` prefab
- [ ] `EndlessWaveProvider.Awake()` validates BossCycle.Length == 5

## Test Evidence

**Type**: Unit Test + Integration Test
**Path**: `tests/unit/endless/`, `tests/integration/endless/`

- Unit test: `GetBossConfig()` cycle correctness -- waves 10,20,30,40,50 return indices 0,1,2,3,4; wave 60 returns index 0
- Unit test: `GetBossConfig()` extended cycling -- waves 70,80,90,100,110 return indices 1,2,3,4,0
- Integration test: Start Endless run, reach wave 10, verify boss spawns with correct identity and 2-phase config
- Integration test: Verify no regular enemies spawn on a boss wave

## Dependencies

- **Blocked by**: 002-endless-wave-provider (GetBossConfig method must exist), E3 boss assets (BossController prefabs must exist for reference)
- **Blocks**: 008-endless-mode-tests

## Engine Notes

Boss configuration uses the same `BossConfig` ScriptableObject schema from ADR-0004. The `BossController` prefab and `BossPhase` struct are defined in the E3 Boss Phase System epic -- this story depends on those assets existing but does not modify them. `PhaseCount = 2` is enforced by authoring (not runtime code) and validated by G-012 guardrail.
