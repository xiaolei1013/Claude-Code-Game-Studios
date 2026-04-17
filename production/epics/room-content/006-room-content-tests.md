# Story: Room Content Integration Tests

> **Epic**: room-content
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-room-001 (all 10 rooms load with no null references), TR-room-003 (Hard mode scales automatically), TR-room-008 (room replay deterministic), TR-room-011 (boss spawns after final wave)
**ADR Reference**: ADR-0006 -- Validation Criteria (all 9 test cases), ADR-0002 -- IWaveProvider contract tests
**Control Manifest Rules**: R-002 (IWaveProvider implemented), R-007 (GetNextWave then IDifficultyProvider separately), R-017 (RoomConfig fields), G-010 (trap coverage <= 15%), G-012 (2-phase rooms 1-5, 3-phase rooms 6-10)

## Description

Create the integration test suite that validates the entire Room Content pipeline: RoomConfig loading, CampaignWaveProvider correctness, Hard mode derivation, boss spawn timing, and deterministic replay. These tests are the BLOCKING gate for the E1 epic -- the Definition of Done requires "All Logic/Integration stories have passing tests."

**Test files to create in `tests/integration/rooms/`:**

1. **`room_config_loading_test.cs`** -- Asset integrity tests
   - Load each of the 10 `RoomConfig` assets from `Assets/Trizzle/Data/Rooms/`
   - Verify no null references: all `SpawnItemInfo.EnemyPrefab` entries are non-null, all `TrapPlacement.TrapPrefab` entries are non-null, `BossConfig` is non-null (GDD AC 1)
   - Verify wave count per room matches GDD table within tolerance
   - Verify archetype tag matches GDD room assignment table (GDD AC 2)
   - Verify boss assignment: Room 1 = Boss A, Room 2 = Boss B, ... Room 5 = Boss E; Rooms 6-10 repeat (GDD AC 3)
   - Verify rooms 1-5 have 2-phase bosses, rooms 6-10 have 3-phase bosses (G-012)

2. **`campaign_wave_provider_integration_test.cs`** -- Wave delivery tests
   - For each room: set `CampaignWaveProvider.SetRoom(roomConfig)`, call `GetNextWave()` for each wave, verify returned `WaveData.BaseEnemyCount` matches expected count
   - Verify `IsBossWave()` returns `false` during wave iteration, then `true` after final wave (TR-room-011)
   - Verify `GetBossConfig()` returns the correct BossConfig for each room
   - Verify `GetTrapLayout()` returns the correct trap count matching `RoomConfig.TrapPlacements.Count`

3. **`hard_mode_scaling_test.cs`** -- Difficulty derivation tests
   - Inject mock `IDifficultyProvider` with Hard multipliers: `EnemyCountMultiplier = 1.25`, `PacingMultiplier = 0.75`
   - For Room 1: verify `GetNextWave()` returns `BaseEnemyCount == Ceil(normalCount * 1.25)` (ADR-0006 Validation Criteria)
   - Verify spawn delay is scaled by `PacingMultiplier` (25% faster)
   - Inject Normal provider (`multipliers = 1.0`): verify output equals authored baseline exactly (no drift)
   - Verify no per-difficulty `RoomConfig` assets exist in the data folder (F-015 enforcement)

4. **`room_replay_determinism_test.cs`** -- Deterministic replay tests
   - Load Room 3, call `SetRoom()`, iterate all waves, record output sequence
   - Call `SetRoom()` again with the same RoomConfig, iterate all waves, record second sequence
   - Verify both sequences are identical: same enemy types, same counts, same delays (GDD AC 10, TR-room-008)
   - Repeat for Room 10 (most complex room) as a stress case

5. **`room_progression_validation_test.cs`** -- Progression curve tests
   - Verify enemy count escalates: Room 1 < Room 5 < Room 10 (GDD AC 9)
   - Verify elite ratio escalates: Room 1 (~13%) < Room 5 (~25%) < Room 10 (40%)
   - Verify wave count escalates: Room 1 (4) <= Room 5 (5) <= Room 10 (6)
   - Verify enemy type variety increases across rooms

**Test naming convention:** `test_[scenario]_[expected]` per coding standards.

**Key constraints:**
- All tests must be deterministic: no random seeds, no time-dependent assertions
- Tests must set up and tear down their own state; no test-order dependency
- Use dependency injection for `IDifficultyProvider` (no singleton access in tests)
- Mock `IDifficultyProvider` returns configurable multiplier values
- Tests load `RoomConfig` assets from the asset database (integration test, not pure unit)

## Acceptance Criteria

- [ ] All 10 rooms pass null-reference validation (no missing enemy, trap, or boss references)
- [ ] CampaignWaveProvider delivers correct wave data for all 10 rooms
- [ ] IsBossWave() transitions correctly from false to true after final wave for all rooms
- [ ] Hard mode scaling produces correct counts: Ceil(baseCount * 1.25) for each room's waves
- [ ] Normal mode (multiplier = 1.0) produces output identical to authored baseline
- [ ] Room replay is deterministic: two sequential playthroughs produce identical wave sequences
- [ ] Enemy count, elite ratio, and wave count escalate across rooms 1-10
- [ ] No per-difficulty RoomConfig variants exist (F-015 enforcement test)
- [ ] All tests pass on CI without manual intervention
- [ ] Test coverage: every `IWaveProvider` method on `CampaignWaveProvider` is called at least once per room
- [ ] Tests are named per convention: `test_[scenario]_[expected]`

## Test Evidence

**Type**: Integration Test (self-validating)
**Path**: `tests/integration/rooms/`

This story IS the test evidence for the E1 epic. All tests must pass as the BLOCKING gate for E1 completion.

## Dependencies

- **Blocked by**: 001-roomconfig-scriptableobject (types must exist), 002-campaign-wave-provider (CampaignWaveProvider must be implemented), 003-rooms-1-5-configuration (room assets 1-5 must be authored), 004-rooms-6-10-configuration (room assets 6-10 must be authored), 005-room-layout-spawn-points (trap positions must be finalized)
- **Blocks**: None -- this is the final validation story for the E1 epic

## Engine Notes

Integration tests in Unity require loading ScriptableObject assets from the asset database. Use `AssetDatabase.LoadAssetAtPath<RoomConfig>()` in edit-mode tests or `Resources.Load<RoomConfig>()` in play-mode tests -- verify which approach works with Unity 6000.3.11f1's test runner. For mock `IDifficultyProvider`, create a simple test class implementing the interface with configurable return values (no mocking framework needed). All Unity test APIs (NUnit, `[Test]`, `[UnityTest]`) are stable pre-cutoff.
