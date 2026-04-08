# ADR-0001: DifficultyConfig as Interface

## Status

Accepted

## Date

2026-04-07

## Last Verified

2026-04-07

## Decision Makers

Technical Director (Claude) + xiaolei

## Summary

Four systems (SpawnManager, EnemyController, drop behaviors, and Endless Mode) require difficulty multipliers but currently access them through direct enum checks or a single concrete struct, making it impossible to swap campaign scaling for Endless scaling at runtime. This ADR defines `IDifficultyProvider` as the sole interface all consumers read, with `CampaignDifficultyProvider` and `EndlessDifficultyProvider` as the two concrete implementations set at mode entry.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6000.3.11f1 (Unity 6.3 LTS) |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | HIGH — Unity 6 series post-dates LLM training cutoff (May 2025) |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md` |
| **Post-Cutoff APIs Used** | None — this decision uses MonoBehaviour, ScriptableObject, and C# interfaces, all stable APIs with no post-cutoff changes |
| **Verification Required** | Confirm ScriptableObject serialisation of concrete providers works correctly in Unity 6000.3.11f1; confirm MonoBehaviour lifecycle order when providers are set on Awake vs Start |

> **Note**: Knowledge Risk is HIGH due to Unity 6 version, but the specific APIs
> used (MonoBehaviour, ScriptableObject, C# interface) have been stable since
> Unity 2020 LTS. Re-validate this ADR if the project upgrades engine versions.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — this is a foundational decision |
| **Enables** | ADR-0002: SpawnManager Mode Routing (SpawnManager cannot safely route modes until a stable IDifficultyProvider exists to route to) |
| **Blocks** | All E2 story implementation (SpawnManager enemy-count scaling, EnemyController stat scaling, D8 drop behavior healing multiplier); All N2 story implementation (EndlessDifficultyProvider and wave scaling) |
| **Ordering Note** | Must reach Accepted status before any E2 or N2 implementation story is written to Ready status. ADR-0002 can be drafted in parallel but depends on this ADR's IDifficultyProvider interface being stable. |

---

## Context

### Problem Statement

Four systems need difficulty multipliers at runtime:

- `SpawnManager` needs `enemyCountMultiplier` and `pacingMultiplier` (E1/E2 stories)
- `EnemyController.InitAttributes()` needs `statMultiplierMin` and `statMultiplierMax` (D1/E2 stories)
- Drop behaviors need `healDropMultiplier` and `rewardMultiplier` (D8 story)
- Endless Mode needs a wave-based scaling curve that evolves per wave number (N2)

Without a shared abstraction, each system will independently branch on `if (mode == Endless)` or directly access a specific config struct. This creates four separate coupling points to the mode-selection logic — meaning any future difficulty tier (e.g. Nightmare mode, per-room modifiers) requires changes in four places.

The decision must be made now because E2 (Difficulty System) is Layer 0 in the build order; all Gameplay and Content layer stories are blocked until E2's interface is established.

### Current State

`DifficultyConfig` exists as a struct with flat float fields (verified from `design/gdd/difficulty-system.md`):

```csharp
// Current pattern (GDD describes this shape, not verified as shipped code)
DifficultyConfig
  statMultiplierMin: float
  statMultiplierMax: float
  enemyCountMultiplier: float
  healDropMultiplier: float
  pacingMultiplier: float
  rewardMultiplier: float
```

The GDD states systems should "query it rather than checking the enum directly" but no interface exists yet — the struct is the only access pattern. Endless Mode's GDD (`design/gdd/endless-mode.md`) defines a separate `EndlessDifficultyConfig` with wave-based formulas that cannot fit in a flat struct.

### Constraints

- **No new architectural paradigms**: Architecture Principle P1 (Extend, Don't Replace) prohibits introducing Zenject, reactive streams, or DOTS for v1.0. The provider must follow existing MonoBehaviour + ScriptableObject patterns.
- **46 existing singleton managers**: The active provider must be accessible to multiple systems without requiring each to hold a direct inspector reference. It will live on an existing persistent manager.
- **Solo developer timeline**: The solution must be simple enough that one developer can implement, test, and maintain it. Complexity ceiling is low.
- **Data-driven tuning**: Architecture Principle P2 (ScriptableObject as Single Source of Truth) requires all multiplier values to be editable in the Inspector without recompilation.
- **Platform-agnostic**: Architecture Principle P4 prohibits platform-specific gameplay logic. The provider must not branch on platform.

### Requirements

- All four consumer systems (SpawnManager, EnemyController, drop behaviors, Endless spawner) must read difficulty values through a single interface — no direct struct or enum access in consumer code
- Campaign Normal and Hard presets must be editable as ScriptableObject assets in the Inspector
- Endless Mode must supply per-wave computed values through the same interface, with formulas from `design/gdd/endless-mode.md`
- `IsBossExemptFromCount` must always return `true` (boss enemy count scaling exception from E2 GDD edge case 3)
- The active provider must be swappable at mode entry (campaign room start or Endless start) with zero allocation
- Any future difficulty tier (Nightmare, custom modifiers) must be addable by creating a new provider class, with no changes to consumer code

---

## Decision

Introduce `IDifficultyProvider` as a C# interface. All four consumer systems depend on this interface exclusively. Two concrete implementations are provided:

1. **`CampaignDifficultyProvider`**: A MonoBehaviour wrapper that holds a serialised `DifficultyConfig` ScriptableObject reference. Returns the flat multiplier values. Assigned the Normal or Hard config asset depending on the player's room-select choice.

2. **`EndlessDifficultyProvider`**: A MonoBehaviour that computes per-wave values at call time using the formulas from `design/gdd/endless-mode.md`. The current wave number is set by the Endless wave spawner before each wave. Holds a serialised `EndlessDifficultyConfig` ScriptableObject for the tuning knobs (scaling rates, floors, caps).

A single `ActiveDifficultyProvider` reference (typed as `IDifficultyProvider`) lives on **`GameManager`** (one of the 46 existing persistent managers). All consumer systems resolve it via `GameManager.Instance.ActiveDifficultyProvider`. The provider is assigned at mode entry and is never null during active gameplay.

This follows the existing singleton manager pattern used by all 46 managers in the project. No new manager is introduced.

### Architecture

```
                    ┌──────────────────────────────┐
                    │         GameManager           │
                    │  (existing persistent manager)│
                    │                               │
                    │  IDifficultyProvider          │
                    │  ActiveDifficultyProvider     │◄── set at mode entry
                    └──────────────┬───────────────┘
                                   │ implements
               ┌───────────────────┼───────────────────┐
               │                                       │
   ┌───────────▼──────────────┐        ┌───────────────▼──────────────┐
   │  CampaignDifficultyProvider│        │  EndlessDifficultyProvider   │
   │  : MonoBehaviour          │        │  : MonoBehaviour             │
   │                           │        │                              │
   │  [SerializeField]         │        │  [SerializeField]            │
   │  DifficultyConfig         │        │  EndlessDifficultyConfig     │
   │  _config (SO ref)         │        │  _config (SO ref)            │
   │                           │        │                              │
   │  Returns flat floats      │        │  int _currentWave            │
   │  from _config fields      │        │  Computes values per wave    │
   └───────────────────────────┘        └──────────────────────────────┘
               ▲                                       ▲
               │ assigned by                          │ assigned by
               │ MenuPrepareStagePanelPC              │ EndlessWaveSpawner
               │ on room entry                        │ on Endless entry
               │
   ┌───────────┴──────────────────────────────────────────────┐
   │               Consumers (read only IDifficultyProvider)   │
   ├──────────────────────────────────────────────────────────┤
   │  SpawnManager          — enemyCountMultiplier, pacing    │
   │  EnemyController       — statMultiplierMin/Max           │
   │  Drop behaviors (D8)   — healDropMultiplier, reward      │
   │  EndlessWaveSpawner    — statMultiplier (via interface)  │
   └──────────────────────────────────────────────────────────┘

   ┌──────────────────────────────────────────────────────────┐
   │               ScriptableObject Assets                     │
   ├──────────────────────────────────────────────────────────┤
   │  DifficultyConfig_Normal.asset  (Normal preset)          │
   │  DifficultyConfig_Hard.asset    (Hard preset)            │
   │  EndlessDifficultyConfig.asset  (Endless tuning knobs)   │
   └──────────────────────────────────────────────────────────┘
```

### Key Interfaces

```csharp
/// <summary>
/// Centralises difficulty multiplier access for all consumer systems.
/// Campaign mode is served by CampaignDifficultyProvider (flat ScriptableObject values).
/// Endless mode is served by EndlessDifficultyProvider (wave-based computed values).
/// All consumers depend on this interface only — never on a concrete implementation.
/// </summary>
public interface IDifficultyProvider
{
    /// <summary>Lower bound of the enemy stat scaling range.</summary>
    float StatMultiplierMin { get; }

    /// <summary>Upper bound of the enemy stat scaling range.</summary>
    float StatMultiplierMax { get; }

    /// <summary>
    /// Multiplier applied to base enemy count per wave.
    /// Normal: 1.0. Hard: 1.25. Endless: 1.0 (count is handled by wave formula).
    /// </summary>
    float EnemyCountMultiplier { get; }

    /// <summary>
    /// Multiplier applied to healing drop probability.
    /// Normal: 1.0. Hard: 0.5. Endless: decreases per wave.
    /// </summary>
    float HealDropMultiplier { get; }

    /// <summary>
    /// Multiplier applied to inter-wave delay. Values below 1.0 mean faster pacing.
    /// Normal: 1.0. Hard: 0.75. Endless: decreases per wave, floor 0.5.
    /// </summary>
    float PacingMultiplier { get; }

    /// <summary>
    /// Multiplier applied to gold, gem, and material drop amounts.
    /// Normal: 1.0. Hard: 2.0. Endless: 1.5 (flat).
    /// </summary>
    float RewardMultiplier { get; }

    /// <summary>
    /// Boss enemies are always exempt from enemy count scaling.
    /// Implementations must always return true.
    /// </summary>
    bool IsBossExemptFromCount { get; }
}

/// <summary>
/// Campaign difficulty provider. Reads flat multipliers from a DifficultyConfig
/// ScriptableObject assigned in the Inspector. One instance per preset (Normal, Hard).
/// GameManager.ActiveDifficultyProvider is set to the correct instance at room entry.
/// </summary>
public class CampaignDifficultyProvider : MonoBehaviour, IDifficultyProvider
{
    [SerializeField] private DifficultyConfig _config;

    public float StatMultiplierMin        => _config.StatMultiplierMin;
    public float StatMultiplierMax        => _config.StatMultiplierMax;
    public float EnemyCountMultiplier     => _config.EnemyCountMultiplier;
    public float HealDropMultiplier       => _config.HealDropMultiplier;
    public float PacingMultiplier         => _config.PacingMultiplier;
    public float RewardMultiplier         => _config.RewardMultiplier;
    public bool  IsBossExemptFromCount    => true;
}

/// <summary>
/// Difficulty config data asset for campaign presets.
/// Create one asset per difficulty tier (Normal, Hard, future Nightmare).
/// </summary>
[CreateAssetMenu(fileName = "DifficultyConfig", menuName = "Trizzle/DifficultyConfig")]
public class DifficultyConfig : ScriptableObject
{
    public float StatMultiplierMin;
    public float StatMultiplierMax;
    public float EnemyCountMultiplier;
    public float HealDropMultiplier;
    public float PacingMultiplier;
    public float RewardMultiplier;
}

/// <summary>
/// Endless mode difficulty provider. Computes values per wave using the scaling
/// formulas from design/gdd/endless-mode.md. _currentWave is set by EndlessWaveSpawner
/// before each wave begins. Tuning knob constants live in EndlessDifficultyConfig SO.
/// </summary>
public class EndlessDifficultyProvider : MonoBehaviour, IDifficultyProvider
{
    [SerializeField] private EndlessDifficultyConfig _config;

    private int _currentWave = 1;

    /// <summary>Called by EndlessWaveSpawner at the start of each wave.</summary>
    public void SetWave(int waveNumber) => _currentWave = waveNumber;

    // statMultiplier(wave) = 1.0 + (wave * statScalingRate)
    public float StatMultiplierMin     => 1.0f + (_currentWave * _config.StatScalingRate);
    public float StatMultiplierMax     => 1.0f + (_currentWave * _config.StatScalingRate);

    // Enemy count handled by wave formula in EndlessWaveSpawner; multiplier is neutral here
    public float EnemyCountMultiplier  => 1.0f;

    // healDropMultiplier(wave) = Max(healDropFloor, 1.0 - (wave * healDropReductionRate))
    public float HealDropMultiplier    =>
        Mathf.Max(_config.HealDropFloor, 1.0f - (_currentWave * _config.HealDropReductionRate));

    // spawnPacing(wave) = Max(pacingFloor, 1.0 - (wave * pacingReductionRate))
    public float PacingMultiplier      =>
        Mathf.Max(_config.PacingFloor, 1.0f - (_currentWave * _config.PacingReductionRate));

    public float RewardMultiplier      => _config.RewardMultiplier;
    public bool  IsBossExemptFromCount => true;
}

/// <summary>
/// Tuning knob asset for Endless Mode difficulty scaling.
/// All rate constants and floors are Inspector-editable without recompilation.
/// </summary>
[CreateAssetMenu(fileName = "EndlessDifficultyConfig", menuName = "Trizzle/EndlessDifficultyConfig")]
public class EndlessDifficultyConfig : ScriptableObject
{
    [Tooltip("Per-wave additive rate for stat scaling. Default: 0.04")]
    public float StatScalingRate       = 0.04f;

    [Tooltip("Per-wave reduction rate for heal drop chance. Default: 0.03")]
    public float HealDropReductionRate = 0.03f;

    [Tooltip("Minimum floor for heal drop multiplier. Default: 0.1")]
    public float HealDropFloor         = 0.1f;

    [Tooltip("Per-wave reduction rate for spawn pacing. Default: 0.015")]
    public float PacingReductionRate   = 0.015f;

    [Tooltip("Minimum floor for pacing multiplier (fastest possible pacing). Default: 0.5")]
    public float PacingFloor           = 0.5f;

    [Tooltip("Flat reward multiplier for Endless mode. Default: 1.5")]
    public float RewardMultiplier      = 1.5f;
}
```

### Implementation Guidelines

1. **GameManager extension**: Add `public IDifficultyProvider ActiveDifficultyProvider { get; private set; }` and `public void SetDifficultyProvider(IDifficultyProvider provider)` to `GameManager`. Do not make the setter public-facing beyond the two assignment sites.
2. **Assignment sites**: `MenuPrepareStagePanelPC` calls `GameManager.Instance.SetDifficultyProvider(campaignProvider)` when the player confirms room + difficulty selection. `EndlessWaveSpawner.StartEndless()` calls `GameManager.Instance.SetDifficultyProvider(endlessProvider)` at Endless entry.
3. **Consumer migration**: Replace any `if (difficulty == Hard)` branch or direct struct field access in `SpawnManager`, `EnemyController`, and drop behaviors with `GameManager.Instance.ActiveDifficultyProvider.[Property]`.
4. **Null guard**: `ActiveDifficultyProvider` must never be null during active gameplay. Initialize it to the Normal campaign provider in `GameManager.Awake()` as a safe default.
5. **No caching in consumers**: Consumers must read the provider reference fresh from GameManager on each use — not cache the reference at Awake — so that mode switches take effect immediately.
6. **Endless wave number sync**: `EndlessWaveSpawner` must call `endlessProvider.SetWave(waveNumber)` before calling `SpawnManager.SpawnEndlessWave()`. Order matters.
7. **DifficultyConfig as ScriptableObject (not struct)**: The GDD describes `DifficultyConfig` as a struct. This ADR promotes it to a ScriptableObject to satisfy Architecture Principle P2. The field names and values are identical — only the type declaration changes.

---

## Alternatives Considered

### Alternative 1: Direct struct access (current pattern)

- **Description**: Each consumer directly holds a `DifficultyConfig` reference (Normal or Hard struct) set by injection at room start. Endless Mode defines a parallel `EndlessDifficultyConfig` struct, and `SpawnManager` branches on `if (mode == Endless)` to choose which struct to read.
- **Pros**: Zero abstraction overhead. Familiar to any Unity developer. No new types introduced.
- **Cons**: Requires every consumer to be aware of the Endless/campaign distinction. Adding a third tier (Nightmare) requires changes in every consumer. Endless values are computed at call site, scattering the wave formulas across multiple files. Testing requires instantiating two separate struct types.
- **Estimated Effort**: Lower initial effort, higher long-term maintenance cost
- **Rejection Reason**: Violates Architecture Principle P5 (data-driven difficulty) and Architecture Principle P2. With four consumer systems, mode-branching logic would be duplicated in four places. This was the specific problem the GDD's interface requirement was written to solve.

### Alternative 2: Static utility class

- **Description**: A static `DifficultyManager` class exposes `GetStatMultiplier()`, `GetEnemyCountMultiplier()`, etc. as static methods. Internally it holds the active config and knows the current mode.
- **Pros**: Simple call sites — no reference resolution needed. No MonoBehaviour lifecycle concerns.
- **Cons**: Static state is a forbidden pattern for game state per Coding Standards ("All dependencies injected, no static singletons for game state"). Untestable without reflection hacks. Cannot be swapped per test scenario. Adds a 47th effective singleton to a project that is already managing 46.
- **Estimated Effort**: Comparable to chosen approach
- **Rejection Reason**: Violates the Coding Standards explicit prohibition on static singletons for game state. Testability would be blocked — the qa-lead cannot inject a mock provider without reflection. This is also the pattern the architecture document (section 8, P5) explicitly rejects with "No system should branch on `if (difficulty == Hard)`."

### Alternative 3: ScriptableObject with mode field

- **Description**: A single `UnifiedDifficultyConfig` ScriptableObject has a `mode` field (`Campaign` or `Endless`) and all multiplier fields including wave-curve constants. Consumer code reads the mode field and executes the appropriate formula inline.
- **Pros**: Single asset type. Easy to inspect in the Unity Editor.
- **Cons**: Consumer code must re-implement the Endless scaling formulas everywhere. The wave number must be injected into the ScriptableObject at runtime (breaking the ScriptableObject-as-read-only-data convention). Switching modes still requires consumers to branch on the mode field — the same coupling problem as Alternative 1.
- **Estimated Effort**: Lower initial effort
- **Rejection Reason**: ScriptableObjects are intended as immutable data assets (Architecture Principle P2). Writing a runtime value (`waveNumber`) into a ScriptableObject violates this convention and creates state management risks (the asset is shared; writing to it in play mode would dirty it). The Open/Closed Principle violation is also significant: any new difficulty tier would require modifying the single asset schema.

---

## Consequences

### Positive

- All four consumer systems are decoupled from the Campaign/Endless mode distinction — they call the same interface regardless of which mode is active
- Adding a future difficulty tier (Nightmare, custom modifiers, per-room difficulty) requires only: (1) a new class implementing `IDifficultyProvider` and (2) a new ScriptableObject asset — zero changes to consumer code
- Endless scaling formulas are co-located in `EndlessDifficultyProvider`, not scattered across SpawnManager, EnemyController, and drop behaviors
- Campaign presets are fully Inspector-editable as ScriptableObject assets (satisfies Architecture Principle P2)
- The interface is mockable for unit tests — QA can inject a `TestDifficultyProvider` with known values without running in a full game session

### Negative

- Consumer code must resolve `GameManager.Instance.ActiveDifficultyProvider` on each use rather than reading a local field — one additional indirection per call
- Two new MonoBehaviour types (`CampaignDifficultyProvider` and `EndlessDifficultyProvider`) must be placed in the scene. They will need to live on GameManager's GameObject or a dedicated child — adds two components to the hierarchy
- `DifficultyConfig` is promoted from struct to ScriptableObject. Any existing code that declares a local `DifficultyConfig config = new DifficultyConfig()` will need to be updated to use asset references instead

### Neutral

- `IsBossExemptFromCount` is always `true` across both implementations. This field exists on the interface to make the boss-exemption rule explicit and discoverable for implementers reading the interface, rather than buried in SpawnManager as a hardcoded check

### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `ActiveDifficultyProvider` is null when a consumer accesses it (e.g., scene loaded without going through room-select) | LOW | HIGH — NullReferenceException in SpawnManager or EnemyController | Initialize to `CampaignDifficultyProvider` (Normal) in `GameManager.Awake()` as safe default. Add `Debug.Assert(ActiveDifficultyProvider != null)` at the top of each consumer method in development builds. |
| `EndlessDifficultyProvider.SetWave()` called after `SpawnManager.SpawnEndlessWave()` — wave number one tick behind | LOW | MEDIUM — wave 1 enemies receive wave 0 stats | Document the ordering requirement in `EndlessWaveSpawner` with a code comment. Add a unit test asserting wave number is set before spawn. |
| Endless stat formula diverges from GDD over time (tuning changes applied to SO asset but formula in code not updated) | MEDIUM | LOW — balance drift, not a crash | Tuning knobs in `EndlessDifficultyConfig` SO control rates and floors. Formula shape (linear scaling) is in code and should only change via a new ADR. Separate the "what formula" (ADR) from "what constants" (SO asset). |
| `CampaignDifficultyProvider` MonoBehaviour not assigned in scene during mobile branch | LOW | MEDIUM — wrong or null config | Add a null check with a descriptive error in `CampaignDifficultyProvider.Awake()`. Include in integration test setup. |

---

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Addresses It |
|---|---|---|---|
| `design/gdd/difficulty-system.md` | E2 Difficulty | "A `DifficultyConfig` struct holds all five multipliers for the current difficulty. Systems query it rather than checking the enum directly." | Elevates the struct to a full `IDifficultyProvider` interface with two concrete implementations. The "query rather than check enum" requirement is enforced structurally — consumers have no access to the enum. |
| `design/gdd/difficulty-system.md` | E2 Difficulty | Tuning Knobs section — "All values live in a `DifficultyConfig` ScriptableObject, editable in the Unity Inspector without code changes." | `CampaignDifficultyProvider` holds a `DifficultyConfig` ScriptableObject reference. Normal and Hard presets are separate assets editable in the Inspector. |
| `design/gdd/difficulty-system.md` | E2 Difficulty | Acceptance Criterion 9 — "All 6 multiplier values are editable in a ScriptableObject without code changes." | Satisfied by `DifficultyConfig` SO for campaign. Satisfied by `EndlessDifficultyConfig` SO tuning knobs for Endless (rates and floors, not the formula itself). |
| `design/gdd/difficulty-system.md` | E2 Difficulty | Edge Case 3 — "Boss enemies are exempt from enemy count scaling." | `IsBossExemptFromCount` is a first-class interface member, always `true`. SpawnManager reads it instead of hardcoding the boss check. |
| `design/gdd/endless-mode.md` | N2 Endless | "Config routing: `SpawnManager` reads `EndlessDifficultyConfig` in Endless mode, NOT campaign `DifficultyConfig`. Mode is set at Endless entry and checked by SpawnManager before applying any multiplier." | `GameManager.ActiveDifficultyProvider` is set to `EndlessDifficultyProvider` at Endless entry. SpawnManager reads `IDifficultyProvider` — it never knows which concrete type is active, satisfying the isolation requirement. |
| `design/gdd/endless-mode.md` | N2 Endless | Endless Difficulty Curve formulas — stat, heal drop, pacing, reward multipliers with per-wave computation | All four formulas are implemented in `EndlessDifficultyProvider` property bodies. Tuning constants (scaling rates, floors) are in `EndlessDifficultyConfig` SO, matching the GDD Tuning Knobs section. |

---

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|----------------|--------|
| CPU — IDifficultyProvider property access (per spawn event) | Direct struct field read: ~0ns | Interface dispatch + GameManager.Instance lookup: ~1-2ns | Negligible — spawn events are infrequent (not per-frame per-enemy) |
| CPU — EndlessDifficultyProvider formula computation (per wave) | N/A | 3 float multiplications + 2 Max() calls: <1 microsecond | Negligible — runs once per wave start, not per frame |
| Memory — two MonoBehaviour components | N/A | ~200 bytes per component | Negligible |
| Load time | N/A | Two ScriptableObject assets loaded at startup | Negligible — SO assets are <1KB each |

No performance concerns. Difficulty multipliers are read at spawn time and wave start — not in per-frame Update loops. The `GameManager.Instance` singleton lookup is the same pattern used by all 46 existing managers in the codebase; its cost is already accepted.

---

## Migration Plan

This ADR introduces new types alongside the existing codebase. It does not require a big-bang rewrite.

1. **Create `IDifficultyProvider` interface** — new file, no existing code touched. Verify interface compiles.
2. **Create `DifficultyConfig` ScriptableObject** — rename/promote from struct. Create `DifficultyConfig_Normal.asset` and `DifficultyConfig_Hard.asset` with values from E2 GDD. If a struct `DifficultyConfig` exists in code, update its declaration to extend `ScriptableObject`.
3. **Create `CampaignDifficultyProvider` MonoBehaviour** — new file. Assign to GameManager's GameObject in scene. Wire `_config` reference to Normal asset (default). Verify it compiles and Inspector shows fields.
4. **Create `EndlessDifficultyConfig` ScriptableObject** — new file. Create `EndlessDifficultyConfig.asset` with default values matching N2 GDD Tuning Knobs.
5. **Create `EndlessDifficultyProvider` MonoBehaviour** — new file. Assign to GameManager's GameObject. Wire `_config` reference to `EndlessDifficultyConfig.asset`.
6. **Extend `GameManager`** — add `ActiveDifficultyProvider` property and `SetDifficultyProvider()`. Initialize to `CampaignDifficultyProvider` (Normal) in Awake. Verify existing tests still pass.
7. **Migrate `EnemyController.InitAttributes()`** — replace direct struct/enum access with `GameManager.Instance.ActiveDifficultyProvider.StatMultiplierMin/Max`. Run existing combat tests.
8. **Migrate `SpawnManager`** — replace direct difficulty checks with `IDifficultyProvider` properties. Run spawn tests.
9. **Migrate D8 drop behaviors** — replace direct healing/reward checks with `IDifficultyProvider` properties.
10. **Wire `MenuPrepareStagePanelPC`** — on room entry confirmation, call `GameManager.Instance.SetDifficultyProvider()` with the correct campaign provider (Normal or Hard).
11. **Wire `EndlessWaveSpawner`** (N2 story) — at Endless start, call `GameManager.Instance.SetDifficultyProvider(endlessProvider)`. Before each wave, call `endlessProvider.SetWave(waveNumber)`.

**Rollback plan**: If this approach proves problematic, the interface can be removed and consumers can revert to direct struct access. The `DifficultyConfig` SO fields are identical to the original struct fields, so the data migration is reversible. No save data is affected.

---

## Validation Criteria

- [ ] All four consumer systems (SpawnManager, EnemyController, drop behaviors, EndlessWaveSpawner) reference `IDifficultyProvider` exclusively — no direct `DifficultyConfig` struct or difficulty enum access in consumer code
- [ ] `DifficultyConfig_Normal.asset` and `DifficultyConfig_Hard.asset` exist in the project and are Inspector-editable; changing a value and entering Play Mode applies it immediately (E2 Acceptance Criterion 9)
- [ ] `EndlessDifficultyConfig.asset` exists and its tuning knobs match the default values from N2 GDD Tuning Knobs section
- [ ] Unit test: `EndlessDifficultyProvider` with wave=10 returns `StatMultiplierMin == 1.4`, `HealDropMultiplier == 0.7`, `PacingMultiplier == 0.85`
- [ ] Unit test: `EndlessDifficultyProvider` with wave=33 returns `PacingMultiplier == 0.5` (floor clamped)
- [ ] Unit test: `CampaignDifficultyProvider` with Hard config returns `EnemyCountMultiplier == 1.25`, `HealDropMultiplier == 0.5`, `RewardMultiplier == 2.0`
- [ ] Integration test: Switch `GameManager.ActiveDifficultyProvider` from campaign (Normal) to `EndlessDifficultyProvider` and back; verify SpawnManager reads the correct values after each switch
- [ ] `IsBossExemptFromCount` returns `true` from both provider implementations
- [ ] `GameManager.ActiveDifficultyProvider` is never null during any gameplay state (assert in development build)

---

## Related

- ADR-0002: SpawnManager Mode Routing — depends on this ADR; defines how SpawnManager uses the active provider to route between campaign RoomConfig and Endless wave generation
- `design/gdd/difficulty-system.md` — E2 GDD, primary source for campaign multiplier values and requirements
- `design/gdd/endless-mode.md` — N2 GDD, source for Endless difficulty curve formulas and tuning knobs
- `docs/architecture/architecture.md` — Section 6.1 (IDifficultyProvider API boundary), Section 7 (ADR audit), Section 8 (Architecture Principles P2, P5)
