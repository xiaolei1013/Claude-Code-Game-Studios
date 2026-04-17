# ADR-0006: Room Content Data Pipeline

## Status

Accepted

## Date

2026-04-07

## Decision Makers

Technical Director (Claude) + xiaolei

## Summary

Ten campaign rooms require a data-driven configuration system so room designers can
author Normal-mode wave lists, trap placements, boss assignments, and archetype tags
entirely in the Unity Inspector. Hard mode is derived at runtime by applying
`IDifficultyProvider` multipliers (ADR-0001) to the Normal baseline — no per-difficulty
authoring. `CampaignWaveProvider` (established in ADR-0002) wraps each `RoomConfig`
ScriptableObject and implements `IWaveProvider`, keeping `SpawnManager` unaware of the
underlying data schema.

---

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6000.3.11f1 (Unity 6.3 LTS) |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | HIGH — Unity 6 series post-dates LLM training cutoff (May 2025) |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md` |
| **Post-Cutoff APIs Used** | None — this decision uses `ScriptableObject`, `MonoBehaviour`, `[SerializeField]`, `List<T>`, and `[CreateAssetMenu]`, all stable APIs unchanged since Unity 2019 LTS |
| **Verification Required** | Confirm `[CreateAssetMenu]` workflow for nested SO types (e.g., `WaveDefinition` referenced inside `RoomConfig`) in Unity 6000.3.11f1 Inspector — verify sub-asset references survive asset database refresh |

> **Note**: Knowledge Risk is HIGH due to the Unity 6 version, but the specific APIs
> used (ScriptableObject, SerializeField, CreateAssetMenu, List<T>) have been stable
> since Unity 2019 LTS. This ADR has no dependency on any post-cutoff Unity features.
> Re-validate if the project upgrades engine versions.

---

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: DifficultyConfig as Interface — `IDifficultyProvider` must be stable before `CampaignWaveProvider` can apply Hard mode multipliers at runtime. ADR-0002: SpawnManager Mode Routing — `IWaveProvider` and `CampaignWaveProvider` contracts must be finalised before this ADR can specify `RoomConfig`'s surface area. Both must reach Accepted before any E1 implementation story is written to Ready. |
| **Enables** | None — this ADR is a leaf node in the dependency graph for v1.0. |
| **Blocks** | All E1 Room Content implementation stories; E3 boss assignment stories that reference a `RoomConfig` boss field; N2 Endless Mode stories that reuse room arena layouts. |
| **Ordering Note** | ADR-0001 and ADR-0002 must both reach Accepted before this ADR can be promoted to Accepted. This ADR may be drafted in parallel with those two but must not be implemented until both are Accepted. |

---

## Context

### Problem Statement

The E1 Room Content GDD defines 10 rooms, each with a unique wave list, trap layout,
boss assignment, and archetype tag. Currently no data schema exists for room
configuration — all spawn data is scattered across scene objects or hardcoded in
`SpawnManager`. With 10 rooms × 2 difficulties (Normal + Hard) × 2 character classes,
authoring 20 difficulty-specific configurations is impractical for a solo developer
and violates Architecture Principle P2 (ScriptableObject as single source of truth)
and P5 (data-driven difficulty, no if-difficulty-Hard branching in code).

The ADR-0002 `CampaignWaveProvider` already names `RoomConfig` as its data source and
declares fields like `RoomConfig.Waves`, `RoomConfig.BossConfig`, and
`RoomConfig.TrapPlacements` — but the schema of those types was deferred to this ADR.
This ADR is the contract `CampaignWaveProvider` implements against and room designers
author against. Until it is Accepted, no E1 implementation story can be written to
Ready.

### Constraints

- **No new architectural paradigms**: Architecture Principle P1 prohibits DOTS, Zenject,
  or reactive streams for v1.0. All data must live in ScriptableObjects authored in the
  Inspector.
- **Normal-only authoring**: Room designers author one `RoomConfig` per room (Normal
  baseline). Hard mode values are derived by `CampaignWaveProvider` applying
  `IDifficultyProvider` multipliers at runtime. No per-difficulty `RoomConfig` variants.
- **Stable `IWaveProvider` surface**: `RoomConfig` fields must map cleanly onto the
  `IWaveProvider` method signatures defined in ADR-0002 (`GetNextWave()`, `IsBossWave()`,
  `GetBossConfig()`, `GetTrapLayout()`). The schema cannot require changes to those
  method signatures.
- **Inspector-editable content**: All wave compositions, trap positions, boss references,
  and archetype tags must be configurable in the Unity Inspector without code changes.
  This supports balance iteration without recompilation (Architecture Principle P2).
- **Solo developer timeline**: The schema must be simple enough for one developer to
  author 10 rooms manually in the Inspector. Complexity ceiling is low — no procedural
  generation, no external data formats, no tooling requirement.
- **Performance**: 10 `RoomConfig` ScriptableObject assets are small (<10KB each). They
  are loaded at scene start and kept in memory for the session. No streaming required.

### Requirements

- Each of the 10 rooms must be representable as a single `RoomConfig` ScriptableObject
  containing all wave, trap, boss, and metadata needed to play the room on Normal.
- Hard mode values (enemy count, pacing, stats, healing, rewards) must be computable
  from the Normal baseline by `CampaignWaveProvider` reading `IDifficultyProvider`
  multipliers — no Hard-specific fields on `RoomConfig`.
- Wave composition must be per-wave, not per-room aggregate: each wave specifies which
  enemy types spawn, in what count, and with what inter-spawn delay.
- The boss assignment must be a direct prefab reference to the `BossController` prefab
  for that room, plus phase count, so `CampaignWaveProvider.IsBossWave()` and
  `GetBossConfig()` can serve it directly.
- Trap placement must store type, position, and rotation per trap instance, matching
  what `SpawnManager` needs to place traps at room entry (called once via
  `GetTrapLayout()`, not per wave).
- The archetype tag must be an enum (not a string) so gameplay systems can branch on it
  without string comparison.
- The schema must cover the 5 archetype values named in the E1 GDD: Swarm, Ambush,
  Gauntlet, Arena, Hybrid.

---

## Decision

Define a `RoomConfig` ScriptableObject with nested data types `WaveDefinition` and
`TrapPlacement`. `CampaignWaveProvider` wraps one `RoomConfig` instance per room entry
and implements `IWaveProvider`. Hard mode is applied at runtime by `CampaignWaveProvider`
reading `IDifficultyProvider` multipliers — `RoomConfig` stores Normal-only data.

### Schema

```csharp
/// <summary>
/// Identifies the combat rhythm and encounter structure of a room.
/// Matches the four primary archetypes and one hybrid type defined in E1 GDD.
/// Used by combo/synergy system (E4) to identify which combo builds the room rewards.
/// </summary>
public enum RoomArchetype
{
    Swarm,    // Many weak enemies, fast waves, AoE-rewarding
    Ambush,   // Few strong enemies, staggered flanking spawns
    Gauntlet, // Trap-heavy corridor into enemy waves
    Arena,    // Boss encounter with minion phases, open space
    Hybrid    // Mixed archetype (Rooms 5 and 10)
}

/// <summary>
/// Defines the composition of a single wave within a room.
/// Stores Normal-mode baseline values. Hard mode counts and delays are derived
/// at runtime by CampaignWaveProvider applying IDifficultyProvider multipliers.
/// </summary>
[System.Serializable]
public class WaveDefinition
{
    /// <summary>
    /// Enemy spawn entries for this wave. Each entry specifies an enemy type,
    /// base count, and inter-spawn delay before the next entry in this wave starts.
    /// </summary>
    public List<SpawnItemInfo> SpawnItems;

    /// <summary>
    /// When true, all enemies in this wave use elite stat scaling.
    /// CampaignWaveProvider passes this flag to SpawnManager for EnemyController
    /// attribute initialisation. Elite flag is independent of difficulty scaling.
    /// </summary>
    public bool IsEliteWave;
}

/// <summary>
/// Defines the position and orientation of a single trap instance in a room.
/// SpawnManager reads the full list once at room entry (via IWaveProvider.GetTrapLayout())
/// and places all traps before the first wave begins.
/// </summary>
[System.Serializable]
public class TrapPlacement
{
    /// <summary>
    /// Reference to the trap prefab. Must be one of the 14 trap types in the
    /// existing trap prefab library (D6). No new trap types are added by this ADR.
    /// </summary>
    public GameObject TrapPrefab;

    /// <summary>World-space position within the room's local coordinate frame.</summary>
    public Vector3 Position;

    /// <summary>World-space rotation for directional traps (spike floors, projectile launchers).</summary>
    public Quaternion Rotation;
}

/// <summary>
/// Configuration for a single campaign room. One asset per room (10 total).
/// Stores Normal-mode baseline data only. Hard mode values are derived at runtime.
/// Authored entirely in the Unity Inspector.
/// </summary>
[CreateAssetMenu(fileName = "RoomConfig_Room00", menuName = "Trizzle/Room Config")]
public class RoomConfig : ScriptableObject
{
    [Header("Room Identity")]

    /// <summary>
    /// Human-readable name matching the room assignment table in E1 GDD
    /// (e.g., "Crypt Entrance", "Sorcerer's Chamber").
    /// Used for debug logging and room select UI display.
    /// </summary>
    public string ThemeName;

    /// <summary>
    /// Combat archetype tag. Drives combo system (E4) room-type awareness and
    /// any future archetype-specific spawn point selection.
    /// </summary>
    public RoomArchetype Archetype;

    [Header("Wave Composition (Normal Baseline)")]

    /// <summary>
    /// Ordered list of waves for this room. Index 0 is wave 1.
    /// CampaignWaveProvider serves these in order via GetNextWave().
    /// Hard mode: CampaignWaveProvider applies IDifficultyProvider.EnemyCountMultiplier
    /// and PacingMultiplier to each wave's SpawnItems at runtime.
    /// </summary>
    public List<WaveDefinition> Waves;

    [Header("Boss Assignment")]

    /// <summary>
    /// Configuration for the boss encounter that follows the final wave.
    /// References the BossController prefab and phase count for this room.
    /// Rooms 1-5: 2-phase bosses. Rooms 6-10: 3-phase bosses.
    /// Set to null for rooms that have no boss (not used in v1.0 — all rooms have a boss).
    /// </summary>
    public BossConfig BossConfig;

    [Header("Trap Layout")]

    /// <summary>
    /// All trap instances to place at room entry, before wave 1 begins.
    /// SpawnManager calls IWaveProvider.GetTrapLayout() once and places all traps.
    /// Trap coverage must not exceed 15% of navigable floor area (E1 GDD constraint).
    /// </summary>
    public List<TrapPlacement> TrapPlacements;
}
```

### BossConfig (referenced above, defined by ADR-0003)

`BossConfig` is a ScriptableObject defined by the Boss Phase System (E3, ADR-0003).
`RoomConfig` holds a serialized reference to it. This ADR treats `BossConfig` as an
opaque reference — its schema is ADR-0003's concern. The only constraint this ADR
places on `BossConfig` is that it must be passable as-is to `IWaveProvider.GetBossConfig()`
return type, which ADR-0002 already defines as `BossConfig`.

### Hard Mode Derivation in CampaignWaveProvider

`RoomConfig` stores Normal-only data. `CampaignWaveProvider` applies difficulty scaling
at spawn time, not at authoring time. The derivation logic lives entirely in
`CampaignWaveProvider.GetNextWave()`:

```csharp
public WaveData GetNextWave()
{
    WaveDefinition waveDef = _config.Waves[_currentWaveIndex++];
    IDifficultyProvider diff = GameManager.Instance.ActiveDifficultyProvider;

    int scaledCount = 0;
    foreach (SpawnItemInfo item in waveDef.SpawnItems)
        scaledCount += Mathf.CeilToInt(item.SpawnCount * diff.EnemyCountMultiplier);

    return new WaveData
    {
        BaseEnemyCount  = scaledCount,
        EliteRatio      = waveDef.IsEliteWave ? 1.0f : ComputeEliteRatio(_config, _currentWaveIndex),
        EnemyTypes      = ExtractEnemyTypes(waveDef.SpawnItems),
        BaseSpawnDelay  = waveDef.SpawnItems.Count > 0
                          ? waveDef.SpawnItems[0].Delay * diff.PacingMultiplier
                          : 0f
    };
}
```

The `EnemyCountMultiplier` and `PacingMultiplier` are read from `IDifficultyProvider`
(ADR-0001). On Normal, both are 1.0 — output equals the authored baseline exactly.
On Hard, the multipliers apply automatically. No `if (difficulty == Hard)` branch exists
anywhere in this flow.

### Architecture Diagram

```
Inspector Authoring                  Runtime (Campaign room entry)
─────────────────────                ─────────────────────────────────

RoomConfig_Room01.asset              MenuPrepareStagePanelPC
  ThemeName: "Crypt Entrance"    ──► campaignProvider.SetRoom(roomConfig)
  Archetype: Swarm                   SpawnManager.SetWaveProvider(campaignProvider)
  Waves: [                           GameManager.SetDifficultyProvider(diffProvider)
    WaveDefinition {                              │
      SpawnItems: [...]                           │
      IsEliteWave: false              ┌───────────▼─────────────────────────┐
    },                                │       CampaignWaveProvider           │
    ...                               │  : MonoBehaviour, IWaveProvider      │
  ]                                   │                                      │
  BossConfig: → BossConfig_A2p.asset  │  RoomConfig _config                 │
  TrapPlacements: [                   │  int _currentWaveIndex               │
    TrapPlacement {                   │                                      │
      TrapPrefab: → FireGrate.prefab  │  GetNextWave()                      │
      Position: (3, 0, 4)            │    reads Waves[_currentWaveIndex]   │
      Rotation: identity             │    applies IDifficultyProvider       │
    },                               │    multipliers to count + delay      │
    ...                              │                                      │
  ]                                  │  IsBossWave()                       │
                                     │    _currentWaveIndex >= Waves.Count  │
RoomConfig_Room02.asset              │    && BossConfig != null             │
  ...                                │                                      │
                                     │  GetBossConfig()                    │
(10 assets total)                    │    returns _config.BossConfig        │
                                     │                                      │
                                     │  GetTrapLayout()                    │
                                     │    returns _config.TrapPlacements    │
                                     └──────────────┬───────────────────────┘
                                                    │ IWaveProvider
                                                    ▼
                                             SpawnManager
                                     (reads only IWaveProvider,
                                      never touches RoomConfig directly)
```

### Asset Naming Convention

```
Assets/Trizzle/Data/Rooms/
  RoomConfig_Room01.asset    // Crypt Entrance    — Swarm
  RoomConfig_Room02.asset    // Sorcerer's Chamber — Ambush
  RoomConfig_Room03.asset    // Necromancer's Corridor — Gauntlet
  RoomConfig_Room04.asset    // War Hall          — Arena
  RoomConfig_Room05.asset    // Lich's Antechamber — Hybrid
  RoomConfig_Room06.asset    // Deep Crypt        — Swarm (remix)
  RoomConfig_Room07.asset    // Dark Sanctum      — Ambush (remix)
  RoomConfig_Room08.asset    // Catacombs         — Gauntlet (remix)
  RoomConfig_Room09.asset    // Throne Room       — Arena (remix)
  RoomConfig_Room10.asset    // Lich's Domain     — Hybrid (all archetypes)
```

### Key Interfaces

`RoomConfig` is a data container — it has no public methods. The interface contract
it fulfils is `IWaveProvider`, implemented by `CampaignWaveProvider` (ADR-0002).
The types below are the data-level contracts that `CampaignWaveProvider` consumes.

```csharp
// Existing type from SpawnManager — reproduced here for completeness.
// RoomConfig.WaveDefinition.SpawnItems is a List<SpawnItemInfo>.
[System.Serializable]
public class SpawnItemInfo
{
    public EnemyData EnemyPrefab;   // reference to the enemy's data/prefab
    public int SpawnCount;          // Normal-mode base count (pre-multiplier)
    public float Delay;             // seconds before this entry's enemies spawn
}

// TrapLayout is the return type of IWaveProvider.GetTrapLayout() (defined in ADR-0002).
// CampaignWaveProvider wraps RoomConfig.TrapPlacements as a TrapLayout.
// The TrapLayout wrapper type is defined by ADR-0002; its internal structure must
// be compatible with the List<TrapPlacement> stored on RoomConfig.
public class TrapLayout
{
    public List<TrapPlacement> Placements;
}
```

---

## Alternatives Considered

### Alternative 1: Per-Difficulty RoomConfig Variants (Normal + Hard Assets)

- **Description**: Author two `RoomConfig` assets per room — one for Normal, one for
  Hard — with Hard values pre-baked in the asset (higher spawn counts, shorter delays).
- **Pros**: Hard mode data is fully explicit and independently tunable; no runtime math.
  Designers can set exact Hard enemy counts without relying on multiplier rounding.
- **Cons**: 20 assets to author and maintain instead of 10. When a room changes, both
  variants must be updated in sync. Violates Architecture Principle P5
  (no if-difficulty branching — the implicit branch lives in which asset is selected).
  Multiplier rounding edge cases (wave of 1 → 2 on Hard) cannot be tested in isolation.
  Endless Mode's `IDifficultyProvider` pattern becomes inconsistent with campaign.
- **Rejection Reason**: Doubles the authoring burden for a solo developer, creates a
  sync maintenance problem, and breaks the `IDifficultyProvider` abstraction that
  ADR-0001 establishes as the project-wide pattern for difficulty scaling.

### Alternative 2: JSON/CSV External Data Files

- **Description**: Store room configurations in external JSON or CSV files rather than
  ScriptableObjects. Parse at runtime or import as TextAssets.
- **Pros**: Editable in any text editor; diff-friendly in version control.
- **Cons**: Requires a custom parser or third-party library; no Inspector editing;
  type safety is lost (string-keyed fields, no prefab references); prefab references
  cannot be serialised in JSON without a custom resolution system. Violates
  Architecture Principle P1 (no new architectural paradigms) and P2 (ScriptableObject
  as single source of truth). The existing 2,569-file codebase uses no external data
  format for gameplay configuration.
- **Rejection Reason**: Introduces a new data pipeline dependency with no benefit over
  ScriptableObjects. The Inspector authoring workflow is already established for all
  other data in the project (skills, enemy data, combo definitions).

### Alternative 3: Inline Wave Data on Room Scene GameObjects

- **Description**: Store wave lists as serialised arrays on a `RoomManager` MonoBehaviour
  placed in each room's scene, rather than as standalone ScriptableObjects.
- **Pros**: Wave data co-located with the room scene; no separate asset management.
- **Cons**: Wave data is locked inside a scene, making it impossible to reference from
  other scenes (e.g., Endless Mode reusing wave compositions). Data is not reusable
  across rooms that share enemy compositions. Testing requires loading a full scene.
  Violates Architecture Principle P2 (ScriptableObject as single source of truth for
  gameplay config). `CampaignWaveProvider` (ADR-0002) already specifies it holds a
  `RoomConfig` ScriptableObject reference, not a scene MonoBehaviour reference.
- **Rejection Reason**: Incompatible with the `IWaveProvider` contract established in
  ADR-0002. Scenes are not referenceable cross-scene; ScriptableObjects are.

---

## Consequences

### Positive

- Room designers author once (Normal baseline) and get Hard mode automatically — no
  redundant authoring, no sync risk between difficulty variants.
- `SpawnManager` never touches `RoomConfig` directly — it reads only through
  `IWaveProvider`. Adding a room, changing a wave count, or reassigning a boss prefab
  requires no code changes, only Inspector edits.
- `RoomConfig` is fully Inspector-editable — all tuning knobs from the E1 GDD (wave
  counts, trap coverage, elite ratios) are directly accessible without recompilation.
- The `RoomArchetype` enum is available to the combo system (E4) for encounter-type
  awareness and to any future system that needs to differentiate room types at runtime.
- 10 small ScriptableObject assets (<10KB each) are trivial to load and hold in memory;
  no streaming or loading-screen impact.
- The schema is testable in isolation: unit tests can construct a `RoomConfig` with
  known wave counts, inject a mock `IDifficultyProvider`, and verify
  `CampaignWaveProvider.GetNextWave()` output without running a full scene.

### Negative

- `WaveDefinition` and `TrapPlacement` are `[Serializable]` classes, not ScriptableObjects.
  They cannot be shared across `RoomConfig` assets — if two rooms use identical wave
  compositions, the data must be authored twice. For 10 rooms this is acceptable;
  for 50+ rooms a shared-wave-template pattern would be preferable.
- `TrapPlacement` stores world-space positions, which are sensitive to room layout
  changes. If a room's geometry is updated, all `TrapPlacement` positions in that
  room's `RoomConfig` must be re-authored manually.
- `BossConfig` is an opaque reference — this ADR cannot validate its schema. If ADR-0003
  changes `BossConfig`'s structure, `RoomConfig.BossConfig` references must be
  re-assigned in the Inspector.

### Risks

- **Risk: `WaveDefinition.SpawnItems` list authored with wrong enemy prefab references.**
  Mitigation: `CampaignWaveProvider.GetNextWave()` null-checks each `SpawnItemInfo.EnemyPrefab`
  and logs a `Debug.LogError` with the room name and wave index if any are null. A
  validation utility (editor tool, P2 priority) can scan all 10 assets on demand.
- **Risk: Trap coverage exceeds 15% of navigable floor area (E1 GDD constraint).**
  Mitigation: This ADR does not enforce the 15% limit at runtime — it is a design
  authoring constraint. QA Acceptance Criterion 6 in the E1 GDD requires a manual
  measurement pass. An optional editor-time warning can be added later.
- **Risk: `BossConfig` reference on `RoomConfig` is null at room entry.**
  Mitigation: `CampaignWaveProvider.IsBossWave()` returns false if `BossConfig == null`,
  preventing a null-reference crash. `SpawnManager` logs a warning. This is a safe
  fallback for development, not a silent failure.
- **Risk: Hard mode rounding produces unexpected counts on small waves.**
  Mitigation: `CampaignWaveProvider` uses `Mathf.CeilToInt()` for count scaling,
  matching the formula in E2 GDD (Acceptance Criterion 4). Edge Case 1 in the E2 GDD
  explicitly accepts: wave of 1 enemy on Hard → `Ceil(1 × 1.25) = 2`.

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `room-content.md` | "Each room is a self-contained combat arena... defined as a `RoomConfig` ScriptableObject containing wave lists, trap placements, boss assignment, and archetype tag." | `RoomConfig` ScriptableObject schema defined with all four fields: `Waves`, `TrapPlacements`, `BossConfig`, `Archetype`. |
| `room-content.md` | "Room designers author Normal configurations; Hard mode values are derived automatically via `DifficultyConfig` multipliers." | `RoomConfig` stores Normal-only data. `CampaignWaveProvider.GetNextWave()` applies `IDifficultyProvider.EnemyCountMultiplier` and `PacingMultiplier` at runtime. No Hard-mode fields on the asset. |
| `room-content.md` | "4 room archetypes — Swarm, Ambush, Gauntlet, and Arena" + Room 5/10 hybrid. | `RoomArchetype` enum defines Swarm, Ambush, Gauntlet, Arena, Hybrid — all five values from the E1 GDD room assignment table. |
| `room-content.md` | "Wave composition rules — each wave is a list of SpawnItemInfo entries with enemy type, count, and delay." | `WaveDefinition.SpawnItems` is `List<SpawnItemInfo>` directly matching this description. |
| `room-content.md` | "Hard mode — enemy count x1.25, spawn pacing x0.75 (applied automatically)." | `CampaignWaveProvider.GetNextWave()` applies `IDifficultyProvider.EnemyCountMultiplier` (1.25 on Hard) and `PacingMultiplier` (0.75 on Hard) to each wave's authored baseline. |
| `room-content.md` | Acceptance Criterion 4 — "Hard mode scales automatically — no room-specific Hard authoring needed." | Satisfied structurally: `RoomConfig` has no difficulty-split fields. Hard scaling is entirely in `CampaignWaveProvider`. |
| `room-content.md` | Acceptance Criterion 7 — "Room replay is deterministic — same enemy types, same spawn points, same traps." | `RoomConfig` is a static asset with no randomised fields. Replaying a room loads the same asset — identical output every time. |
| `difficulty-system.md` | "All five axes apply simultaneously — Hard is not just 'pick one modifier'." | `CampaignWaveProvider` applies both count and pacing multipliers from `IDifficultyProvider` in a single `GetNextWave()` call. Stat scaling is handled downstream by `EnemyController.InitAttributes()` reading `IDifficultyProvider.StatMultiplierMin/Max`. |
| `difficulty-system.md` | Acceptance Criterion 9 — "DifficultyConfig is data-driven — all multiplier values are editable in a ScriptableObject." | `RoomConfig` contains no hardcoded difficulty values. All multipliers come from `IDifficultyProvider` (ADR-0001), which wraps `DifficultyConfig` ScriptableObjects. |
| `boss-phase-system.md` | "Each room's boss encounter references a `BossController` prefab with configured phases." | `RoomConfig.BossConfig` is a direct prefab reference to the `BossController` asset for that room. `CampaignWaveProvider.GetBossConfig()` returns it via `IWaveProvider`. |
| `boss-phase-system.md` | "Rooms 1-5: 2-phase bosses. Rooms 6-10: 3-phase bosses." | Phase count is a property of `BossConfig` (ADR-0003 schema). `RoomConfig.BossConfig` reference points to the correct 2-phase or 3-phase asset per room. Authoring is per-asset in the Inspector. |

---

## Performance Implications

- **CPU**: `CampaignWaveProvider.GetNextWave()` is called once per wave start (not per
  frame). Two float multiplications per `SpawnItemInfo` entry for count and pacing
  scaling. For the largest wave in the game (Room 10, ~10 enemies), this is < 1
  microsecond. Negligible.
- **Memory**: 10 `RoomConfig` ScriptableObject assets × < 10KB each = < 100KB total.
  Assets are loaded at scene start and held for the session. No dynamic allocation in
  `GetNextWave()` — `WaveData` is a struct returned by value.
- **Load Time**: 10 small ScriptableObjects load synchronously at scene start. No
  measurable impact on load time.
- **Network**: Not applicable. Room configs are local assets; no network data path.

---

## Migration Plan

This ADR introduces new types alongside the existing codebase. No existing system is
broken by this ADR.

1. **Create `RoomArchetype` enum** — new file `Assets/Trizzle/Scripts/Rooms/RoomArchetype.cs`.
   Verify it compiles.
2. **Create `WaveDefinition` class** — new file `Assets/Trizzle/Scripts/Rooms/WaveDefinition.cs`.
   Confirm `[Serializable]` attribute is present; confirm `SpawnItemInfo` is the correct
   existing type (or add a using directive).
3. **Create `TrapPlacement` class** — new file `Assets/Trizzle/Scripts/Rooms/TrapPlacement.cs`.
   Confirm `[Serializable]` attribute and `Vector3`/`Quaternion` fields compile.
4. **Create `RoomConfig` ScriptableObject** — new file
   `Assets/Trizzle/Scripts/Rooms/RoomConfig.cs`. Confirm `[CreateAssetMenu]` generates
   the menu item "Trizzle/Room Config" in the Unity Project window.
5. **Create 10 `RoomConfig` assets** — one per room via the Create Asset menu. Name per
   the asset naming convention above. Leave all fields empty initially.
6. **Author wave data** — For each room, populate `Waves` list per E1 GDD room assignment
   table. One `WaveDefinition` per wave; populate `SpawnItems` per archetype wave
   composition rules.
7. **Assign boss references** — Set `BossConfig` on each asset to the appropriate
   `BossController` prefab reference. Requires ADR-0003 assets to exist.
8. **Author trap placements** — Set `TrapPlacements` per room using the trap placement
   rules in the E1 GDD. Verify coverage < 15% of floor area per room (manual check).
9. **Wire `CampaignWaveProvider`** — In `CampaignWaveProvider.SetRoom()`, assign
   `_config = roomConfig`. Confirm `GetNextWave()` reads `_config.Waves[_currentWaveIndex]`
   and applies `IDifficultyProvider` multipliers. This is the E1-SP-001 story.
10. **Run E1 acceptance criteria tests** — Per E1 GDD Acceptance Criteria 1-10.

---

## Validation Criteria

- [ ] All 10 `RoomConfig` assets exist in `Assets/Trizzle/Data/Rooms/` and have no null
      fields at project save time (no missing enemy prefab, trap prefab, or boss config
      references visible in the Inspector).
- [ ] `CampaignWaveProvider.GetNextWave()` unit test: inject a `RoomConfig` with a wave
      of `SpawnCount = 4`, inject a mock `IDifficultyProvider` returning
      `EnemyCountMultiplier = 1.25`, verify `WaveData.BaseEnemyCount == 5`
      (`Ceil(4 × 1.25)`).
- [ ] `CampaignWaveProvider.GetNextWave()` unit test: inject a Normal `IDifficultyProvider`
      (`EnemyCountMultiplier = 1.0`), verify output count equals the authored baseline
      exactly (no drift on Normal).
- [ ] `CampaignWaveProvider.IsBossWave()` returns `false` during waves 1 through N,
      returns `true` after all waves are exhausted and `BossConfig != null`.
- [ ] `CampaignWaveProvider.GetTrapLayout()` returns the correct `TrapPlacement` count
      matching the authored `RoomConfig.TrapPlacements` list.
- [ ] E1 GDD Acceptance Criterion 1: all 10 rooms load from their `RoomConfig` asset
      with no null references on enemies, traps, or bosses.
- [ ] E1 GDD Acceptance Criterion 4: Play Room 1 Normal then Room 1 Hard. Verify: more
      enemies, faster waves. No per-difficulty `RoomConfig` asset was created.
- [ ] E1 GDD Acceptance Criterion 10: Clear Room 3, replay Room 3. Verify: same enemy
      types, same spawn points, same traps (deterministic — no randomisation in
      `RoomConfig` or `CampaignWaveProvider`).
- [ ] `RoomArchetype` enum covers all five values used in the E1 GDD room assignment
      table: Swarm, Ambush, Gauntlet, Arena, Hybrid.

---

## Related Decisions

- ADR-0001: DifficultyConfig as Interface — defines `IDifficultyProvider`; consumed
  by `CampaignWaveProvider` to derive Hard mode values from Normal baseline.
- ADR-0002: SpawnManager Mode Routing — defines `IWaveProvider` and
  `CampaignWaveProvider`; this ADR specifies the `RoomConfig` schema that
  `CampaignWaveProvider` wraps.
- ADR-0003: BossController Subclass vs Composition — defines `BossConfig`; this ADR
  holds a reference to it on `RoomConfig.BossConfig`.
- `design/gdd/room-content.md` — E1 GDD, primary source for room assignments, wave
  composition rules, archetype definitions, and acceptance criteria.
- `design/gdd/difficulty-system.md` — E2 GDD, source for Hard mode multiplier values
  and the Normal-only authoring constraint.
- `design/gdd/boss-phase-system.md` — E3 GDD, source for boss assignment per room and
  2-phase vs 3-phase split.
- `docs/architecture/architecture.md` — Section 4 (module ownership for E1), Section 5.1
  (data flow: RoomConfig → SpawnManager → EnemyController), Section 8 (Architecture
  Principles P2 and P5).
