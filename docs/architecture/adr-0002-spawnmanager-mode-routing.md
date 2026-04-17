# ADR-0002: SpawnManager Mode Routing

## Status

Accepted

## Date

2026-04-07

## Last Verified

2026-04-07

## Decision Makers

Technical Director (Claude) + xiaolei

## Summary

SpawnManager is touched by four systems (E1 Room Content, E2 Difficulty, E3 Boss Phases,
N2 Endless Mode) and currently reads wave data directly from room-specific `SpawnItemInfo`
lists. With Endless Mode, it must also generate waves procedurally. This ADR defines an
`IWaveProvider` strategy interface that decouples SpawnManager from the source of wave
data, allowing `CampaignWaveProvider` and `EndlessWaveProvider` to be swapped at mode
entry — keeping SpawnManager unified while preventing it from becoming a god class.

---

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6000.3.11f1 (Unity 6.3 LTS) |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | HIGH — Unity 6 series post-dates LLM training cutoff (May 2025) |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md` |
| **Post-Cutoff APIs Used** | None — this decision uses MonoBehaviour, ScriptableObject, C# interfaces, and coroutines, all stable APIs with no known post-cutoff breaking changes |
| **Verification Required** | Confirm MonoBehaviour component lifecycle order (Awake/Start) when providers are set at scene load vs runtime; confirm ScriptableObject references survive scene transitions correctly in Unity 6000.3.11f1 |

> **Note**: Knowledge Risk is HIGH due to the Unity 6 version, but the specific APIs
> used (MonoBehaviour, ScriptableObject, C# interface, coroutines) have been stable
> since Unity 2020 LTS. The strategy pattern implemented here has no dependency on any
> post-cutoff Unity features. Re-validate if the project upgrades engine versions.

---

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: DifficultyConfig as Interface — `IDifficultyProvider` must be stable before `IWaveProvider` consumers can call it for stat scaling. ADR-0001 must reach Accepted before any E1 or N2 story is written to Ready. |
| **Enables** | ADR-006: RoomConfig Data Schema (CampaignWaveProvider defines the contract `RoomConfig` authors must write against); ADR-007: Endless Wave Generation (EndlessWaveProvider is the implementation site for N2 formulas) |
| **Blocks** | All E1 Room Content implementation stories; All N2 Endless Mode implementation stories; Any E3 story that requires SpawnManager to detect boss waves |
| **Ordering Note** | ADR-0001 and ADR-0002 may be drafted in parallel but ADR-0001 must be Accepted first. ADR-0002 may not be promoted to Accepted until ADR-0001 is Accepted. ADR-006 and ADR-007 cannot be drafted until this ADR is Accepted — they define the implementations of the interfaces established here. |

---

## Context

### Problem Statement

`SpawnManager` is the highest-risk shared hotspot in the codebase: four distinct systems
modify its behavior for v1.0.

- **E1 Room Content** requires SpawnManager to read wave lists, enemy types, and trap
  placement from `RoomConfig` ScriptableObjects authored per-room.
- **E2 Difficulty** requires SpawnManager to apply `IDifficultyProvider` multipliers
  (enemy count scaling, pacing) to whatever wave it is about to spawn.
- **E3 Boss Phases** requires SpawnManager to detect when a wave is a boss wave and
  spawn the correct `BossController` prefab (not a regular enemy).
- **N2 Endless Mode** requires SpawnManager to generate waves procedurally using
  wave-number-driven formulas rather than reading a static authored list.

Without a routing abstraction, SpawnManager must directly branch on the current mode
(`if (mode == Endless)`) to decide whether to read from `RoomConfig` or run formulas
inline. This couples SpawnManager to both content systems simultaneously, making it
impossible to test either path in isolation and guaranteeing merge conflicts whenever
E1 and N2 stories are worked on concurrently.

The architecture doc (Section 4, `Shared Code Hotspots`) flags SpawnManager as HIGH
risk precisely because of this four-system contention. Architecture Open Question A1
(Section 10) recommends a unified SpawnManager with strategy/mode routing over splitting
into two separate managers — avoiding duplication of wave-completion logic, the 3-second
breathing window, draft-trigger counting, and boss-detection.

### Constraints

- **No new architectural paradigms**: Architecture Principle P1 prohibits DOTS,
  Zenject, or reactive streams for v1.0. The routing solution must use MonoBehaviour +
  ScriptableObject + C# interface patterns consistent with the existing 46 managers.
- **Unified SpawnManager**: The wave-completion event, breathing window timer, draft
  trigger (every 5 waves in Endless), and boss detection must not be duplicated across
  two separate manager classes. Splitting would create two maintenance targets for the
  same shared logic.
- **Data-driven content**: Architecture Principle P2 requires all wave composition
  data (enemy types, counts, delays) to live in ScriptableObjects editable in the
  Inspector. Campaign wave data cannot be hardcoded in SpawnManager.
- **Separation of concerns**: Wave composition (what to spawn) must be separated from
  difficulty scaling (how to scale what was requested). These are two independent axes
  that can change independently — a new room archetype should not require touching the
  difficulty scaling code.
- **Solo developer timeline**: The solution must be simple enough that one developer
  can implement, test, and maintain all providers. Complexity ceiling is low.
- **Platform-agnostic**: Architecture Principle P4 prohibits platform-specific gameplay
  logic in the wave system. Mobile performance caps belong in a platform config, not in
  the wave provider or SpawnManager.

### Requirements

- SpawnManager must spawn both campaign room waves and Endless procedural waves without
  branching on mode internally.
- `CampaignWaveProvider` must wrap `RoomConfig` ScriptableObjects, exposing wave lists,
  trap placement, and boss assignment through a common interface.
- `EndlessWaveProvider` must generate wave data procedurally using the N2 formulas
  (enemyCount, eliteRatio, enemyTypeCount per wave number), without reading any
  `RoomConfig` asset.
- Both providers must support boss wave detection and boss config access — boss waves
  occur in both campaign rooms (Arena archetype) and Endless Mode (every 10 waves,
  cycling through 5 bosses, always 2-phase).
- Stat scaling via `IDifficultyProvider` (ADR-0001) must be applied AFTER the wave
  provider returns wave composition — difficulty scaling is a separate concern from
  wave generation.
- Mode must be set at entry: entering a campaign room sets `CampaignWaveProvider`,
  entering Endless sets `EndlessWaveProvider`.
- Adding a future content mode (e.g., a challenge room with hand-authored Endless-style
  waves) must require only a new `IWaveProvider` implementation — no changes to
  SpawnManager.

---

## Decision

Introduce `IWaveProvider` as a C# interface. SpawnManager depends exclusively on this
interface for all wave data. Two concrete implementations are provided:

1. **`CampaignWaveProvider`**: A MonoBehaviour that holds a reference to the current
   `RoomConfig` ScriptableObject. Returns waves from the SO's authored `SpawnItemInfo`
   lists. Detects boss waves by reading `RoomConfig.bossConfig` and the archetype tag.
   Returns trap layout from `RoomConfig.trapPlacements`.

2. **`EndlessWaveProvider`**: A MonoBehaviour that generates wave data at call time
   using the N2 formulas. Takes a wave number as input and computes enemy count, elite
   ratio, and enemy type selection. Returns boss wave every 10 waves, cycling through
   the 5 campaign bosses in order, always with 2-phase config. Returns no trap layout
   (Endless arena has no traps per N2 GDD).

Both providers implement `IWaveProvider`. SpawnManager calls `IDifficultyProvider`
(from ADR-0001) for stat scaling AFTER receiving wave data — wave composition and
difficulty scaling are separate concerns and separate interface calls.

A single `ActiveWaveProvider` reference (typed as `IWaveProvider`) lives on
**`SpawnManager`** itself. The provider is set at mode entry and is never null during
active gameplay. This follows the same pattern as `ActiveDifficultyProvider` on
`GameManager` established in ADR-0001.

### Architecture Diagram

```
Mode Entry
    │
    ├── Campaign room entry (MenuPrepareStagePanelPC)
    │       └── SpawnManager.SetWaveProvider(campaignProvider)
    │               campaignProvider.SetRoom(selectedRoomConfig)
    │
    └── Endless entry (EndlessWaveSpawner)
            └── SpawnManager.SetWaveProvider(endlessProvider)

                                ┌─────────────────────────────────┐
                                │          SpawnManager            │
                                │  (existing persistent manager)   │
                                │                                  │
                                │  IWaveProvider ActiveProvider    │◄── set at mode entry
                                │  IDifficultyProvider Difficulty  │◄── from GameManager (ADR-0001)
                                └──────────────┬──────────────────┘
                                               │
                      ┌────────────────────────┼─────────────────────────┐
                      │ implements              │ implements               │
          ┌───────────▼───────────┐ ┌──────────▼──────────────────────┐
          │  CampaignWaveProvider  │ │  EndlessWaveProvider            │
          │  : MonoBehaviour       │ │  : MonoBehaviour                │
          │                        │ │                                 │
          │  [SerializeField]      │ │  int _currentWave               │
          │  RoomConfig _config    │ │  BossConfig[] _bossCycle (x5)   │
          │                        │ │                                 │
          │  GetNextWave()         │ │  GetNextWave()                  │
          │    reads SpawnItemInfo │ │    computes from N2 formulas    │
          │    list from SO        │ │                                 │
          │                        │ │  IsBossWave()                  │
          │  IsBossWave()          │ │    wave % 10 == 0               │
          │    reads archetype tag │ │                                 │
          │    + bossConfig ref    │ │  GetBossConfig()               │
          │                        │ │    cycles through 5 bosses,    │
          │  GetBossConfig()       │ │    always 2-phase              │
          │    reads RoomConfig    │ │                                 │
          │    .bossConfig field   │ │  GetTrapLayout()               │
          │                        │ │    returns null (no traps)     │
          │  GetTrapLayout()       │ │                                 │
          │    reads RoomConfig    │ └────────────────────────────────┘
          │    .trapPlacements     │
          └────────────────────────┘
                      ▲                          ▲
                      │ set by                   │ set by
                      │ MenuPrepareStagePanelPC  │ EndlessWaveSpawner
                      │ on room entry            │ on Endless entry

┌─────────────────────────────────────────────────────────────────────────┐
│  SpawnManager wave loop (shared for both modes)                          │
│                                                                          │
│  1. waveData = ActiveProvider.GetNextWave()                              │
│  2. if (ActiveProvider.IsBossWave()) → SpawnBoss(GetBossConfig())        │
│     else → SpawnEnemies(waveData, Difficulty.EnemyCountMultiplier)       │
│  3. Apply Difficulty.PacingMultiplier to inter-wave delay                │
│  4. EnemyController.InitAttributes reads Difficulty.StatMultiplierMin/Max│
│  5. On all enemies dead → 3s breathing window → waveNumber++            │
│  6. If Endless and waveNumber % 5 == 0 → trigger draft screen           │
│  7. repeat                                                               │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  ScriptableObject Assets                                                 │
│  RoomConfig_Room01.asset … RoomConfig_Room10.asset  (campaign, x10)     │
│  EndlessBossConfig_A.asset … EndlessBossConfig_E.asset  (2-phase, x5)   │
│  EndlessDifficultyConfig.asset  (N2 tuning knobs, from ADR-0001)        │
└─────────────────────────────────────────────────────────────────────────┘
```

### Key Interfaces

```csharp
/// <summary>
/// Abstracts wave data sourcing from SpawnManager.
/// Campaign mode is served by CampaignWaveProvider (RoomConfig ScriptableObject).
/// Endless mode is served by EndlessWaveProvider (procedural formula-driven generation).
/// SpawnManager depends on this interface exclusively — never on a concrete provider.
/// </summary>
public interface IWaveProvider
{
    /// <summary>
    /// Returns the composition of the next wave to spawn.
    /// For campaign: reads the next SpawnItemInfo list from RoomConfig.
    /// For Endless: computes enemy count, elite ratio, and enemy types from wave formulas.
    /// SpawnManager applies IDifficultyProvider scaling to these values after calling this.
    /// </summary>
    WaveData GetNextWave();

    /// <summary>
    /// Returns true if the current wave should be a boss wave.
    /// Campaign: true for the final wave in Arena-archetype rooms.
    /// Endless: true when waveNumber % 10 == 0.
    /// </summary>
    bool IsBossWave();

    /// <summary>
    /// Returns the boss configuration for a boss wave.
    /// Campaign: reads BossController prefab reference from RoomConfig.bossConfig.
    /// Endless: returns the cycling BossConfig (A→E→A) with PhaseCount always 2.
    /// Only valid to call when IsBossWave() returns true.
    /// </summary>
    BossConfig GetBossConfig();

    /// <summary>
    /// Returns the trap layout for this room/wave context.
    /// Campaign: reads TrapPlacementData from RoomConfig.trapPlacements.
    /// Endless: always returns null (Endless arena has no traps per N2 GDD).
    /// SpawnManager checks for null before placing traps.
    /// </summary>
    TrapLayout GetTrapLayout();
}

/// <summary>
/// Carries the output of IWaveProvider.GetNextWave().
/// SpawnManager reads this struct to determine what to spawn before applying
/// IDifficultyProvider scaling. This is a plain data container — no logic.
/// </summary>
public struct WaveData
{
    /// <summary>Base enemy count before IDifficultyProvider.EnemyCountMultiplier is applied.</summary>
    public int BaseEnemyCount;

    /// <summary>Fraction of enemies that should be elite type (0.0 – 1.0).</summary>
    public float EliteRatio;

    /// <summary>Enemy prefab references selected for this wave.</summary>
    public EnemyData[] EnemyTypes;

    /// <summary>
    /// For campaign: the SpawnItemInfo delays from RoomConfig, before pacing multiplier.
    /// For Endless: a uniform delay derived from wave number, before pacing multiplier.
    /// </summary>
    public float BaseSpawnDelay;
}

/// <summary>
/// Campaign wave provider. Reads wave composition from a RoomConfig ScriptableObject.
/// Set the active config via SetRoom() at campaign room entry. Thread-safe for read.
/// </summary>
public class CampaignWaveProvider : MonoBehaviour, IWaveProvider
{
    [SerializeField] private EnemyDatabase _enemyDatabase;

    private RoomConfig _config;
    private int _currentWaveIndex;

    /// <summary>Called by MenuPrepareStagePanelPC when the player confirms room entry.</summary>
    public void SetRoom(RoomConfig config)
    {
        _config = config;
        _currentWaveIndex = 0;
    }

    public WaveData GetNextWave()
    {
        // Reads _config.waves[_currentWaveIndex++] and converts SpawnItemInfo
        // list to WaveData. SpawnManager applies IDifficultyProvider scaling after.
        // Implementation: gameplay-programmer story E1-SP-001.
        throw new System.NotImplementedException();
    }

    public bool IsBossWave() =>
        _config != null && _currentWaveIndex >= _config.Waves.Count && _config.BossConfig != null;

    public BossConfig GetBossConfig() => _config?.BossConfig;

    public TrapLayout GetTrapLayout() => _config?.TrapPlacements;
}

/// <summary>
/// Endless wave provider. Generates wave data procedurally from N2 formulas.
/// Advance the wave number via SetWave() before each wave. Boss cycle is automatic.
/// </summary>
public class EndlessWaveProvider : MonoBehaviour, IWaveProvider
{
    [SerializeField] private EnemyDatabase _enemyDatabase;

    /// <summary>
    /// Five 2-phase boss configs cycling A→B→C→D→E→A.
    /// Each entry references the BossController prefab for that boss.
    /// Assigned in Inspector; must have exactly 5 entries.
    /// </summary>
    [SerializeField] private BossConfig[] _bossCycle;

    private int _currentWave = 1;

    /// <summary>Called by EndlessWaveSpawner before each wave begins.</summary>
    public void SetWave(int waveNumber) => _currentWave = waveNumber;

    public WaveData GetNextWave()
    {
        // enemyCount(wave)     = 4 + Floor(wave * 0.5)
        // eliteRatio(wave)     = Min(0.50, wave * 0.02)
        // enemyTypeCount(wave) = Min(5, 1 + Floor(wave / 5))
        // Implementation: gameplay-programmer story N2-SP-001.
        throw new System.NotImplementedException();
    }

    public bool IsBossWave() => _currentWave % 10 == 0;

    public BossConfig GetBossConfig()
    {
        // Cycle index: ((_currentWave / 10) - 1) % 5
        // PhaseCount on returned config is always 2 (Endless does not use 3-phase).
        throw new System.NotImplementedException();
    }

    /// <summary>Endless arena has no traps. Always returns null.</summary>
    public TrapLayout GetTrapLayout() => null;
}
```

### Implementation Guidelines

1. **SpawnManager extension**: Add `public IWaveProvider ActiveWaveProvider { get; private set; }`
   and `public void SetWaveProvider(IWaveProvider provider)` to `SpawnManager`. Initialize to
   `CampaignWaveProvider` in `Awake()` as a safe default.
2. **Assignment sites**: `MenuPrepareStagePanelPC` calls `SpawnManager.Instance.SetWaveProvider(campaignProvider)`
   then `campaignProvider.SetRoom(selectedRoomConfig)` on room entry confirmation.
   `EndlessWaveSpawner.StartEndless()` calls `SpawnManager.Instance.SetWaveProvider(endlessProvider)`.
3. **Difficulty scaling is always separate**: SpawnManager must call `ActiveWaveProvider.GetNextWave()`
   first to get base `WaveData`, then apply `GameManager.Instance.ActiveDifficultyProvider`
   multipliers to counts and delays. These two interface calls must never merge into one.
4. **Boss wave path**: SpawnManager checks `ActiveWaveProvider.IsBossWave()` before spawning.
   If true, it calls `GetBossConfig()` and spawns the `BossController` prefab with
   `IsBossExemptFromCount = true` from `IDifficultyProvider`. Normal enemy spawning is skipped.
5. **Trap placement**: SpawnManager calls `GetTrapLayout()` once per room entry (not per wave).
   A null result means no traps — SpawnManager skips trap placement silently.
6. **Wave breathing window**: The 3-second breathing window between waves lives in SpawnManager,
   not in any provider. Both providers are passive data sources; pacing is SpawnManager's concern
   (modulated by `IDifficultyProvider.PacingMultiplier`).
7. **Draft trigger in Endless**: SpawnManager is responsible for detecting `waveNumber % 5 == 0`
   in Endless mode and firing the draft event. `EndlessWaveProvider` does not hold wave-number
   state for this purpose — SpawnManager tracks the count itself.
8. **Null guard**: `ActiveWaveProvider` must never be null during active gameplay. Default to
   `CampaignWaveProvider` in `SpawnManager.Awake()`. Add `Debug.Assert` at each call site in
   development builds.
9. **No caching of provider in consumers**: Other systems (e.g., `DraftRunController`) that need
   to know the current mode should read `SpawnManager.Instance.ActiveWaveProvider` fresh — not
   cache it at Awake.

---

## Alternatives Considered

### Alternative 1: Unified SpawnManager with inline mode branching

- **Description**: SpawnManager retains a `SpawnMode` enum (Campaign / Endless) and branches
  internally: `if (mode == Endless) { /* formula */ } else { /* read RoomConfig */ }`. Both code
  paths live directly in SpawnManager.
- **Pros**: No new abstractions. Familiar to any Unity developer reading the file. Zero interface
  dispatch overhead.
- **Cons**: SpawnManager becomes a god class owning both content-layer responsibilities (what waves
  look like in campaign vs Endless) and infrastructure responsibilities (how spawning works). Adding
  a third content mode requires modifying SpawnManager directly. E1 and N2 stories both touch the
  same file, guaranteeing merge conflicts. Testing campaign spawning requires setting up Endless
  state correctly to avoid the branch, and vice versa.
- **Rejection Reason**: Directly produces the god-class outcome the architecture doc warns against
  in Section 4. Violates Architecture Principle P3 (event-driven, decoupled systems) and the
  Open/Closed Principle — the class must be modified every time a new content mode is added.

### Alternative 2: Split into CampaignSpawnManager + EndlessSpawnManager

- **Description**: Two separate MonoBehaviour managers, each responsible for their mode's full
  spawn loop. A routing manager or GameManager activates one or the other at mode entry.
- **Pros**: Each manager is smaller and focused. No branching within either class.
- **Cons**: Wave-completion logic (breathing window, boss detection, draft trigger timing, wave
  counter) must be duplicated or extracted into a third base class. Architecture Open Question A1
  explicitly recommends against this: "Splitting duplicates wave-completion logic." Any bug in the
  shared wave loop must be fixed in two places. Two managers = two objects to configure in scenes,
  two sets of Inspector references to maintain.
- **Rejection Reason**: The shared wave loop logic (3s window, boss detection, draft counting) is
  non-trivial. Duplication is a higher maintenance cost than the abstraction introduced by the
  strategy pattern. Architecture Open Question A1 documents this analysis and recommends unified
  with strategy routing.

### Alternative 3: SpawnManager reads a unified WaveSequence ScriptableObject for both modes

- **Description**: Define a `WaveSequence` ScriptableObject that both campaign and Endless write
  into at mode entry. Campaign pre-populates it from `RoomConfig`. Endless populates it procedurally
  before each wave. SpawnManager only reads `WaveSequence` — it never knows the source.
- **Pros**: SpawnManager has a single read target. No interface dispatch. Data visible in Inspector.
- **Cons**: `WaveSequence` becomes a runtime-mutable ScriptableObject — violating Architecture
  Principle P2 (ScriptableObjects are immutable data assets). Endless would write to the SO before
  each wave, dirtying it in memory and creating state management risks (two systems writing to the
  same asset). Pre-populating a campaign WaveSequence from RoomConfig adds a redundant copy step
  that the strategy pattern avoids. This is the same ScriptableObject-as-runtime-state anti-pattern
  rejected in ADR-0001 Alternative 3.
- **Rejection Reason**: Violates Architecture Principle P2. Writing runtime state into a
  ScriptableObject creates asset-dirtying bugs, test-isolation problems, and contradicts the
  established pattern that SOs are read-only data (write once in the Inspector, read many times
  in code).

---

## Consequences

### Positive

- SpawnManager has no knowledge of whether it is in Campaign or Endless mode — it calls
  `IWaveProvider` regardless, eliminating the mode-branching god-class risk.
- Adding a future content mode (challenge rooms, time-trial, boss rush) requires only a new
  `IWaveProvider` implementation — SpawnManager is closed for modification.
- E1 and N2 implementation stories work on separate files (`CampaignWaveProvider.cs` and
  `EndlessWaveProvider.cs`) with no merge conflict surface on SpawnManager itself.
- Both providers are independently testable via mock injection — QA can inject a
  `TestWaveProvider` with known wave data without running a full scene.
- The separation of `IWaveProvider` (what to spawn) and `IDifficultyProvider` (how to scale it)
  makes both axes tunable independently. A designer can change wave composition without touching
  difficulty math, and vice versa.
- Trap placement flows through the same `GetTrapLayout()` call regardless of mode, giving
  SpawnManager a single trap setup code path.

### Negative

- Two new MonoBehaviour types (`CampaignWaveProvider` and `EndlessWaveProvider`) must be placed
  in the scene(s) and wired with Inspector references, adding two components to the hierarchy.
- `WaveData` struct introduces a new data transfer type between the provider and SpawnManager.
  Programmers unfamiliar with the ADR may be tempted to add business logic to this struct (resist:
  it must remain a plain data container).
- `SpawnManager` must be refactored to call `ActiveWaveProvider.GetNextWave()` instead of reading
  `SpawnItemInfo` lists directly. This is a non-trivial change to an existing shipped class.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `ActiveWaveProvider` is null when SpawnManager is called (scene loaded without mode entry) | LOW | HIGH — NullReferenceException at wave start | Default to `CampaignWaveProvider` in `SpawnManager.Awake()`. Add `Debug.Assert(ActiveWaveProvider != null)` in development builds at each call site. |
| `EndlessWaveProvider.SetWave()` called after `SpawnManager.StartWave()` — wave number one tick behind | LOW | MEDIUM — wave 1 enemies receive wave 0 stats from provider | Document ordering requirement in `EndlessWaveSpawner` with an explicit code comment. Add a unit test asserting SetWave precedes GetNextWave. |
| `CampaignWaveProvider.SetRoom()` not called before SpawnManager enters the wave loop (stale room config from previous session) | LOW | MEDIUM — wrong enemies spawned, or NullReference on SpawnItemInfo access | Add a null/staleness check in `CampaignWaveProvider.GetNextWave()`. Defensive: throw a descriptive exception if `_config` is null rather than silently returning empty wave data. |
| `EndlessWaveProvider._bossCycle` array has fewer than 5 entries (authoring error in Inspector) | LOW | MEDIUM — ArrayIndexOutOfRange on boss waves | Validate array length in `EndlessWaveProvider.Awake()` with a descriptive error. Add an Editor validation attribute. |
| SpawnManager keeps wave-completion logic tightly coupled to `IWaveProvider` internal state | MEDIUM | MEDIUM — if a provider needs to track state across GetNextWave() calls, the interface contract becomes fragile | Providers are stateful MonoBehaviours, which is acceptable. SpawnManager must never assume what state a provider is in between calls — it calls the interface and trusts the result. |

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/room-content.md` (E1) | Wave composition rules: each wave is a list of `SpawnItemInfo` entries with enemy type, count, and delay. Room Content is data-driven via `RoomConfig` ScriptableObjects. | `CampaignWaveProvider` wraps `RoomConfig` and exposes its `SpawnItemInfo` lists through `GetNextWave()`. SpawnManager never reads `RoomConfig` directly — only through the interface. |
| `design/gdd/room-content.md` (E1) | Boss assignment per room: each room references a `BossController` prefab with configured phases (2-phase rooms 1-5, 3-phase rooms 6-10). | `CampaignWaveProvider.GetBossConfig()` returns the `BossConfig` from `RoomConfig`. Phase count is authored per-room in the SO. SpawnManager reads it through `IWaveProvider.GetBossConfig()`. |
| `design/gdd/room-content.md` (E1) | Trap placement: 14 trap types placed per-room via data, no more than 15% floor coverage. At least one safe path always exists. | `CampaignWaveProvider.GetTrapLayout()` returns `TrapPlacementData` from `RoomConfig`. SpawnManager applies it once at room entry. Campaign trap design is fully in the SO — no trap data in code. |
| `design/gdd/endless-mode.md` (N2) | Wave composition formulas: `enemyCount(wave) = 4 + Floor(wave * 0.5)`, `eliteRatio(wave) = Min(0.50, wave * 0.02)`, `enemyTypeCount(wave) = Min(5, 1 + Floor(wave/5))`. | `EndlessWaveProvider.GetNextWave()` computes all three values from `_currentWave` using the exact N2 formulas. `WaveData` carries the results to SpawnManager. |
| `design/gdd/endless-mode.md` (N2) | Boss wave cycling: boss spawns every 10 waves, cycling A→E, always 2-phase in Endless (difficulty from stat scaling, not phase complexity). | `EndlessWaveProvider.IsBossWave()` returns `wave % 10 == 0`. `GetBossConfig()` returns the cycling boss with `PhaseCount = 2`. The 2-phase Endless constraint is encoded in the provider, not in SpawnManager or `BossController`. |
| `design/gdd/endless-mode.md` (N2) | "Config routing: SpawnManager reads `EndlessDifficultyConfig` in Endless mode, NOT campaign `DifficultyConfig`. Mode is set at Endless entry." | `EndlessWaveProvider` is set as `ActiveWaveProvider` at Endless entry. SpawnManager calls `IDifficultyProvider` (which is `EndlessDifficultyProvider` at this point, per ADR-0001) separately from wave data — the routing is achieved by combining this ADR's wave provider swap with ADR-0001's difficulty provider swap. SpawnManager never sees the mode directly. |
| `design/gdd/endless-mode.md` (N2) | No traps in Endless arena. Pure open space. | `EndlessWaveProvider.GetTrapLayout()` always returns null. SpawnManager skips trap placement on null. No additional SpawnManager logic needed for this rule. |
| `design/gdd/difficulty-system.md` (E2) | "Systems query [DifficultyConfig] rather than checking the enum directly." Hard mode applies on top of base wave composition — room designs are Normal-only; Hard is derived. | Wave composition (what to spawn) is separated from difficulty scaling (how to scale it). SpawnManager calls `GetNextWave()` for base counts, then applies `IDifficultyProvider.EnemyCountMultiplier` and `PacingMultiplier`. Room designers author only Normal configs; Hard scaling is automatic. |
| `design/gdd/difficulty-system.md` (E2) | Edge Case 3: Boss enemies are exempt from enemy count scaling. | `IWaveProvider.IsBossWave()` triggers the boss path in SpawnManager. SpawnManager reads `IDifficultyProvider.IsBossExemptFromCount` (always true per ADR-0001) and skips count scaling for boss spawns. The exemption is enforced structurally, not by a magic if-check in SpawnManager. |

---

## Performance Implications

| Metric | Expected | Budget |
|--------|----------|--------|
| CPU — `IWaveProvider.GetNextWave()` call (per wave start) | Campaign: one SO field read, ~1-2ns. Endless: 3 arithmetic operations, ~1ns. | Negligible — called once per wave, not per frame. |
| CPU — `IWaveProvider.IsBossWave()` call | Campaign: one comparison. Endless: one modulo + comparison, ~1ns. | Negligible. |
| CPU — Interface dispatch overhead (virtual dispatch) | ~2-3ns per call on modern hardware. Called 2-4 times per wave event, not per frame. | Negligible — spawn events are infrequent. |
| Memory — two MonoBehaviour components | ~200 bytes each. | Negligible. |
| Memory — `WaveData` struct allocation per wave | Stack-allocated struct, zero heap allocation. | Negligible. Zero GC pressure. |
| Load time | Two MonoBehaviour types instantiated at scene load, 5 boss `BossConfig` SOs loaded for `EndlessWaveProvider`. | Negligible — SOs are small assets. |

No performance concerns. All provider calls occur at wave transition events (once every 15-60 seconds of gameplay), never inside `Update()` loops. The `WaveData` struct is deliberately chosen over a class to avoid per-wave heap allocation and GC pressure, which matters at wave 30+ in Endless when frame budget is tightest.

---

## Migration Plan

This ADR introduces new types alongside the existing SpawnManager. It does not require rewriting SpawnManager in a single pass.

1. **Define `IWaveProvider` interface and `WaveData` struct** — new files, no existing code touched. Verify they compile.
2. **Create `CampaignWaveProvider` MonoBehaviour** — new file. Implement `GetNextWave()` to read existing `SpawnItemInfo` data format from `RoomConfig`. Wire to SpawnManager in scene.
3. **Create `EndlessWaveProvider` MonoBehaviour** — new file. Implement N2 formulas. Wire 5 boss `BossConfig` SO references in Inspector.
4. **Extend `SpawnManager`** — add `ActiveWaveProvider` property and `SetWaveProvider()`. Add null guard in `Awake()`. Change wave loop to call `ActiveWaveProvider.GetNextWave()` instead of reading lists directly. Verify existing campaign tests still pass.
5. **Wire `MenuPrepareStagePanelPC`** — add `SpawnManager.Instance.SetWaveProvider(campaignProvider)` and `campaignProvider.SetRoom(config)` on room entry confirmation.
6. **Wire `EndlessWaveSpawner`** (N2 story) — at Endless start, call `SpawnManager.Instance.SetWaveProvider(endlessProvider)`. Before each wave, call `endlessProvider.SetWave(waveNumber)`.
7. **Remove direct `SpawnItemInfo` reads from SpawnManager** — only after step 4 is stable and all campaign room tests pass.

**Rollback plan**: If the provider abstraction proves problematic, `IWaveProvider` can be removed and SpawnManager can revert to reading `SpawnItemInfo` lists directly (step 7 reverted). The `WaveData` struct is a pass-through type — removing it requires only changing the `GetNextWave()` call sites. No save data is affected.

---

## Validation Criteria

- [ ] `SpawnManager` contains zero references to `RoomConfig` directly — all room data accessed via `IWaveProvider`
- [ ] `SpawnManager` contains zero references to any Endless wave formula — all Endless data accessed via `IWaveProvider`
- [ ] `SpawnManager` contains zero mode branches (`if (mode == Endless)` or equivalent) for wave composition
- [ ] Unit test: `CampaignWaveProvider` with a 3-wave `RoomConfig` returns `WaveData` matching the authored `SpawnItemInfo` on the first 3 calls, then `IsBossWave() == true` on the 4th call
- [ ] Unit test: `EndlessWaveProvider` at wave 1 returns `BaseEnemyCount == 4`, `EliteRatio == 0.02`
- [ ] Unit test: `EndlessWaveProvider` at wave 10 returns `BaseEnemyCount == 9`, `IsBossWave() == true`, `GetBossConfig().PhaseCount == 2`
- [ ] Unit test: `EndlessWaveProvider` at wave 20 returns `IsBossWave() == true`, boss is Boss B (index 1)
- [ ] Unit test: `EndlessWaveProvider` at wave 60 returns boss at index 0 (cycle wraps)
- [ ] Unit test: `EndlessWaveProvider.GetTrapLayout()` always returns null regardless of wave number
- [ ] Integration test: Switch `SpawnManager.ActiveWaveProvider` from `CampaignWaveProvider` to `EndlessWaveProvider` and back; verify SpawnManager reads correct wave composition after each switch, and that `IDifficultyProvider` scaling is applied independently after each provider call
- [ ] Campaign Room 1 wave loop completes (4 waves + boss) using `CampaignWaveProvider` with no regressions vs. demo build behavior
- [ ] `ActiveWaveProvider` is never null during any active gameplay state

---

## Related Decisions

- **ADR-0001: DifficultyConfig as Interface** — prerequisite; defines `IDifficultyProvider` that SpawnManager calls for stat scaling AFTER calling `IWaveProvider`. These two interfaces are complementary and intentionally separate.
- **ADR-006: RoomConfig Data Schema** — enabled by this ADR; defines the full `RoomConfig` ScriptableObject schema that `CampaignWaveProvider` reads.
- **ADR-007: Endless Wave Generation** — enabled by this ADR; defines the full implementation of `EndlessWaveProvider` including enemy type selection logic and boss config authoring.
- `design/gdd/room-content.md` — E1 GDD; primary source for campaign wave composition rules, room archetype definitions, and trap placement requirements
- `design/gdd/endless-mode.md` — N2 GDD; source for Endless wave generation formulas, boss cycling rules, draft timing, and arena layout constraints
- `design/gdd/difficulty-system.md` — E2 GDD; source for the 5-axis scaling that SpawnManager applies on top of `IWaveProvider` output
- `docs/architecture/architecture.md` — Section 4 (SpawnManager as shared hotspot), Section 5.1 (difficulty-scaled spawn flow), Section 5.4 (Endless wave loop), Section 10 Open Question A1 (unified vs split SpawnManager)
