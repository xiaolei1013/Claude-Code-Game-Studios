# Story: RoomConfig ScriptableObject

> **Epic**: room-content
> **Type**: Logic
> **Priority**: P0
> **Status**: Complete
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: M

## Context

**GDD Requirement**: TR-room-001 (10 RoomConfig SOs with wave lists, trap placements, boss assignment, archetype tag), TR-room-002 (RoomArchetype enum with Swarm, Ambush, Gauntlet, Arena, Hybrid), TR-room-010 (WaveDefinition stores List\<SpawnItemInfo\> with enemy type, count, delay)
**ADR Reference**: ADR-0006 -- Decision section (RoomConfig schema, WaveDefinition, TrapPlacement, RoomArchetype enum), Migration Plan steps 1-4
**Control Manifest Rules**: R-017 (RoomConfig SO with ThemeName, Archetype enum, Waves list, BossConfig, TrapPlacements), R-018 (RoomArchetype enum with exactly Swarm, Ambush, Gauntlet, Arena, Hybrid), F-015 (no per-difficulty RoomConfig variants), F-016 (no JSON/CSV or scene MonoBehaviours for room data), F-003 (no runtime writes to SO assets)

## Description

Create the data schema that defines a single campaign room. This is the foundational data type for the entire E1 Room Content epic -- all other stories depend on this schema being stable. The types defined here are consumed by `CampaignWaveProvider` (story 002) and authored by room configuration stories (003, 004).

**Files to create:**

1. **`RoomArchetype.cs`** -- Enum with exactly 5 values: `Swarm`, `Ambush`, `Gauntlet`, `Arena`, `Hybrid`. XML doc comments on the enum and each value describing the combat rhythm (from GDD archetype table). Place in `Assets/Trizzle/Scripts/Rooms/`.

2. **`WaveDefinition.cs`** -- `[System.Serializable]` class with two fields: `public List<SpawnItemInfo> SpawnItems` (enemy spawn entries per wave) and `public bool IsEliteWave` (elite stat scaling flag). XML doc comments on each field. Place in `Assets/Trizzle/Scripts/Rooms/`.

3. **`TrapPlacement.cs`** -- `[System.Serializable]` class with three fields: `public GameObject TrapPrefab` (reference to one of 14 existing trap prefabs from D6), `public Vector3 Position` (world-space within room's local frame), `public Quaternion Rotation` (for directional traps). XML doc comments on each field. Place in `Assets/Trizzle/Scripts/Rooms/`.

4. **`RoomConfig.cs`** -- ScriptableObject with `[CreateAssetMenu(fileName = "RoomConfig_Room00", menuName = "Trizzle/Room Config")]`. Fields:
   - `[Header("Room Identity")]` section: `public string ThemeName`, `public RoomArchetype Archetype`
   - `[Header("Wave Composition (Normal Baseline)")]` section: `public List<WaveDefinition> Waves`
   - `[Header("Boss Assignment")]` section: `public BossConfig BossConfig`
   - `[Header("Trap Layout")]` section: `public List<TrapPlacement> TrapPlacements`
   - Full XML doc comments on each field referencing the ADR-0006 documentation
   - Place in `Assets/Trizzle/Scripts/Rooms/`

**Key constraints from ADR-0006:**
- `RoomConfig` stores Normal-only data; Hard mode is derived at runtime by `CampaignWaveProvider`
- `WaveDefinition` and `TrapPlacement` are `[Serializable]` classes, not ScriptableObjects (cannot be shared across RoomConfigs)
- `BossConfig` is an opaque reference defined by ADR-0003 (E3 Boss Phase System); treat as external type
- `SpawnItemInfo` is an existing type in the codebase (from SpawnManager); `WaveDefinition.SpawnItems` references it directly

## Acceptance Criteria

- [ ] `RoomArchetype` enum exists with exactly 5 values: Swarm, Ambush, Gauntlet, Arena, Hybrid
- [ ] `WaveDefinition` class is `[System.Serializable]` with `SpawnItems` (List\<SpawnItemInfo\>) and `IsEliteWave` (bool) fields
- [ ] `TrapPlacement` class is `[System.Serializable]` with `TrapPrefab` (GameObject), `Position` (Vector3), and `Rotation` (Quaternion) fields
- [ ] `RoomConfig` is a ScriptableObject with `[CreateAssetMenu]` attribute generating menu item "Trizzle/Room Config"
- [ ] `RoomConfig` has all 5 fields: ThemeName, Archetype, Waves, BossConfig, TrapPlacements
- [ ] All fields have XML doc comments referencing their purpose and constraints
- [ ] No difficulty-specific fields exist on `RoomConfig` (Normal-only data)
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1
- [ ] Creating a `RoomConfig` asset via the Unity Create Asset menu works and all fields are editable in Inspector
- [ ] Nested `WaveDefinition` list renders correctly in Inspector (expandable wave list with SpawnItems sub-list per wave)

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/rooms/`

- Unit test: Create a `RoomConfig` instance programmatically, populate all fields, verify all values read back correctly
- Unit test: Verify `RoomArchetype` enum has exactly 5 values and they match expected names
- Unit test: Create a `WaveDefinition` with 3 `SpawnItemInfo` entries, verify `SpawnItems.Count == 3`
- Unit test: Create a `TrapPlacement`, verify Position and Rotation fields serialize correctly

## Dependencies

- **Blocked by**: ADR-0001 (must be Accepted), ADR-0002 (must be Accepted), ADR-0006 (must be Accepted) -- all three ADRs must be Accepted before implementation begins
- **Blocks**: 002-campaign-wave-provider, 003-rooms-1-5-configuration, 004-rooms-6-10-configuration, 005-room-layout-spawn-points, 006-room-content-tests

## Engine Notes

Uses `ScriptableObject`, `[CreateAssetMenu]`, `[System.Serializable]`, `[SerializeField]`, `List<T>`, `Vector3`, `Quaternion`, and `[Header]` -- all stable Unity APIs unchanged since Unity 2019 LTS (confirmed in ADR-0006 Engine Compatibility section). Verify that nested `[Serializable]` class lists (`List<WaveDefinition>` containing `List<SpawnItemInfo>`) render correctly in the Unity 6000.3.11f1 Inspector. Also verify `[CreateAssetMenu]` workflow for the nested SO reference (`BossConfig`) survives asset database refresh.

## Completion Notes

**Completed**: 2026-04-18
**Criteria**: 10/10 passing
**Deviations**:
- Created BossConfig.cs (story said "treat as external type" but no BossConfig existed). Minimal class with BossPrefab reference only.
- ADR-0002 and ADR-0006 promoted from Proposed to Accepted as prerequisites.
**Test Evidence**: Logic: 8 unit tests at `Assets/Trizzle/Tests/Rooms/RoomConfigTest.cs`
**Code Review**: Pending (run `/simplify` or `/review` before merge)
