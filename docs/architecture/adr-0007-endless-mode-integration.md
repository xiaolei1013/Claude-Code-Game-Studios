# ADR-0007: Endless Mode Integration

## Status

Proposed

## Date

2026-04-07

## Last Verified

2026-04-07

## Decision Makers

Technical Director (Claude) + xiaolei

## Summary

Endless Mode (N2) reuses the campaign's combat, draft, and boss systems but requires
its own wave generation, difficulty scaling, session management, and score persistence.
This ADR defines the four classes that integrate these concerns: `EndlessWaveProvider`
(procedural wave generation via N2 formulas), `EndlessDifficultyProvider` (wave-based
stat/heal/pacing scaling, already specified in ADR-0001), `EndlessSessionController`
(wave counter, draft timing every 5 waves, boss cycling every 10 waves, score tracking),
and score persistence via the existing `LevelStats` system with a synthetic `"Endless"`
level ID. No mid-run save. Single 30x30 unit arena, no traps, 6 spawn points.

---

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6000.3.11f1 (Unity 6.3 LTS) |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | HIGH — Unity 6 series post-dates LLM training cutoff (May 2025) |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md` |
| **Post-Cutoff APIs Used** | None — this decision uses MonoBehaviour, ScriptableObject, C# interfaces, coroutines, and `PlayerPrefs`/`LevelStats` patterns, all stable APIs with no known post-cutoff breaking changes |
| **Verification Required** | Confirm coroutine-based wave loop timing (3s breathing window) behaves as expected under Unity 6000.3.11f1 frame scheduler; confirm `LevelStats` write/read cycle survives scene transitions correctly in Unity 6.3 LTS |

> **Note**: Knowledge Risk is HIGH due to the Unity 6 version, but the specific APIs
> used (MonoBehaviour, ScriptableObject, coroutines, C# interface) have been stable
> since Unity 2020 LTS. Re-validate this ADR if the project upgrades engine versions.

---

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: DifficultyConfig as Interface — `IDifficultyProvider` and `EndlessDifficultyProvider` must be Accepted before N2 implementation stories can be written to Ready. ADR-0002: SpawnManager Mode Routing — `IWaveProvider` and `EndlessWaveProvider` slot (defined here) must be Accepted; `SpawnManager.SetWaveProvider()` API must exist before `EndlessSessionController` can set it at mode entry. |
| **Enables** | None at this time |
| **Blocks** | All N2 Endless Mode implementation stories |
| **Ordering Note** | ADR-0001 and ADR-0002 must both reach Accepted status before any N2 implementation story is written to Ready. This ADR may be drafted in parallel with ADR-0006 (RoomConfig Data Schema) but must not be promoted to Accepted until ADR-0002 is Accepted. |

---

## Context

### Problem Statement

Endless Mode must generate waves procedurally (no authored `RoomConfig`), apply a
wave-based difficulty curve, trigger skill drafts every 5 waves, cycle bosses every
10 waves, and persist per-class high scores — all while reusing the existing combat,
draft, and boss infrastructure. Without a dedicated session controller, this logic
would accumulate in `SpawnManager` (already flagged HIGH risk in architecture.md
Section 4) or scatter across `DraftRunController` and `GameManager`.

The architecture document (Section 5.4 and Open Question A4) already settled two
sub-decisions: use a unified SpawnManager with a strategy provider (ADR-0002), and
use `LevelStats` with a synthetic level ID for score persistence rather than a new
persistence path. This ADR defines the full integration structure those decisions
imply.

### Constraints

- **No new architectural paradigms**: Architecture Principle P1 prohibits DOTS,
  Zenject, or reactive streams for v1.0. All classes must follow MonoBehaviour +
  ScriptableObject patterns consistent with the existing 46 managers.
- **Extend, don't replace**: `DraftRunController`, `BossController`, `SpawnManager`,
  and `LevelStats` are existing shipped systems. Endless Mode must call into them
  via their existing or minimally-extended APIs — not fork them.
- **Data-driven tuning**: Architecture Principle P2 requires all scaling constants
  (rates, floors, boss cycle order) to live in ScriptableObject assets editable in
  the Inspector without recompilation.
- **No mid-run save**: Runs are intentionally non-saveable. Quitting a run is
  equivalent to death. This is a deliberate design decision (N2 GDD Edge Case 7),
  not a deferred feature.
- **Platform-agnostic gameplay logic**: Architecture Principle P4 prohibits
  platform-specific logic inside wave generation or the session controller. Any
  mobile enemy-count cap lives in a platform config, not in `EndlessWaveProvider`.
- **Solo developer timeline**: The integration must be comprehensible and maintainable
  by one developer. Complexity ceiling is low; prefer straightforward coroutine
  coordination over event mesh patterns.

### Requirements

- `EndlessWaveProvider` must implement `IWaveProvider` (ADR-0002) and generate wave
  composition using the three N2 formulas: `enemyCount`, `eliteRatio`, `enemyTypeCount`
  per wave number.
- `EndlessDifficultyProvider` must implement `IDifficultyProvider` (ADR-0001) and
  compute per-wave stat/heal/pacing/reward values from the N2 difficulty curve formulas
  (fully specified in ADR-0001 Key Interfaces).
- `EndlessSessionController` must manage: wave counter, 3s breathing window, draft
  trigger every 5 waves via `DraftRunController.ShowDraft()`, boss cycle detection
  every 10 waves, score display during run (HUD), and death-screen score presentation.
- Boss cycling must iterate through 5 campaign bosses in sequence (A→E), always
  requesting 2-phase config, and cycle back to Boss A at wave 60+.
- Score must persist using the existing `LevelStats` system with level IDs
  `"Endless_Mage"` and `"Endless_Archer"` for per-class high scores.
- The Endless arena is a single 30x30 unit scene with 6 spawn points and no traps.
  `EndlessWaveProvider.GetTrapLayout()` must always return null.
- All boss configs for the Endless cycle must be authored as ScriptableObject assets
  with `PhaseCount = 2`.

---

## Decision

Introduce three new classes and one ScriptableObject to integrate Endless Mode
without touching SpawnManager internals or forking DraftRunController:

1. **`EndlessWaveProvider : MonoBehaviour, IWaveProvider`** — Generates wave data
   at call time using the N2 formulas. Holds a serialised reference to
   `EndlessWaveConfig` SO (boss cycle array, enemy pool, elite tags). The current
   wave number is set by `EndlessSessionController` before each
   `SpawnManager.SpawnNextWave()` call. Boss cycling is resolved here via a
   deterministic index: `bossIndex = ((waveNumber / 10) - 1) % 5`.

2. **`EndlessDifficultyProvider : MonoBehaviour, IDifficultyProvider`** — Already
   fully specified in ADR-0001. Included here for integration completeness. Set on
   `GameManager.ActiveDifficultyProvider` at Endless entry. Wave number sync
   (`SetWave(waveNumber)`) is the responsibility of `EndlessSessionController`,
   called before each wave's spawn.

3. **`EndlessSessionController : MonoBehaviour`** — The single coordinator for an
   Endless run. Lives in the Endless arena scene. Owns the wave counter, the
   breathing window coroutine, draft trigger logic, boss detection, and score
   accumulation. Does NOT own spawn logic (delegated to SpawnManager via
   IWaveProvider) or difficulty computation (delegated to EndlessDifficultyProvider
   via IDifficultyProvider). Subscribes to `SpawnManager.OnWaveComplete` to advance
   state.

4. **`EndlessWaveConfig : ScriptableObject`** — Holds the boss cycle array
   (`BossConfig[5]`), the enemy prefab pool (ordered by introduction wave), and
   elite enemy tags. Editable in the Inspector without recompilation.

Score persistence reuses `LevelStats` (existing system, D11) with two synthetic
level IDs: `"Endless_Mage"` and `"Endless_Archer"`. Per-class high scores are
written on run end (death or quit). No new persistence classes are introduced.

### Architecture Diagram

```
Endless Entry (Main Menu → Endless Mode)
    │
    └── EndlessSessionController.StartRun(classType)
            │
            ├── GameManager.SetDifficultyProvider(endlessDifficultyProvider)
            ├── SpawnManager.SetWaveProvider(endlessWaveProvider)
            └── begin wave loop (coroutine)

                        ┌──────────────────────────────────────────────┐
                        │         EndlessSessionController              │
                        │  (MonoBehaviour — Endless arena scene)        │
                        │                                               │
                        │  int _waveNumber                              │
                        │  int _score (= _waveNumber on wave complete)  │
                        │  PlayerClassType _classType                   │
                        │                                               │
                        │  Subscribes: SpawnManager.OnWaveComplete      │
                        │  Calls: endlessDifficultyProvider.SetWave()   │
                        │  Calls: endlessWaveProvider.SetWave()         │
                        │  Calls: SpawnManager.SpawnNextWave()          │
                        │  Calls: DraftRunController.ShowDraft()        │
                        │  Calls: LevelStats.SaveEndlessScore()         │
                        └──────────────────┬───────────────────────────┘
                                           │ coordinates
                      ┌────────────────────┼─────────────────┐
                      │                    │                  │
          ┌───────────▼──────────┐ ┌───────▼──────────┐ ┌───▼────────────────┐
          │  EndlessWaveProvider  │ │ EndlessDifficulty │ │ DraftRunController │
          │  : IWaveProvider      │ │ Provider          │ │ (existing, D7)     │
          │                       │ │ : IDifficulty-    │ │                    │
          │  SetWave(n)           │ │   Provider        │ │ ShowDraft()        │
          │  GetNextWave()        │ │                   │ │ (every 5 waves)    │
          │  IsBossWave()         │ │ SetWave(n)        │ └────────────────────┘
          │  GetBossConfig()      │ │ StatMultiplierMin │
          │  GetTrapLayout()→null │ │ HealDropMultiplier│
          │                       │ │ PacingMultiplier  │
          │  [SerializeField]     │ │ RewardMultiplier  │
          │  EndlessWaveConfig SO │ │                   │
          └───────────────────────┘ │ [SerializeField]  │
                    ▲               │ EndlessDifficulty │
                    │ reads         │ Config SO         │
          ┌─────────┴─────────┐    └───────────────────┘
          │  EndlessWaveConfig │              ▲
          │  : ScriptableObject│              │ reads
          │  BossConfig[5]     │    ┌─────────┴──────────────┐
          │  EnemyPool[]       │    │  EndlessDifficultyConfig│
          │  EliteTags[]       │    │  : ScriptableObject     │
          └───────────────────-┘    │  StatScalingRate        │
                                    │  HealDropReductionRate  │
                                    │  HealDropFloor          │
                                    │  PacingReductionRate    │
                                    │  PacingFloor            │
                                    │  RewardMultiplier       │
                                    └─────────────────────────┘

Wave Loop (coroutine in EndlessSessionController):
  ┌─────────────────────────────────────────────────────────────────┐
  │  1. _waveNumber++                                                │
  │  2. endlessDifficultyProvider.SetWave(_waveNumber)               │
  │  3. endlessWaveProvider.SetWave(_waveNumber)                     │
  │  4. SpawnManager.SpawnNextWave()   ← uses IWaveProvider +        │
  │                                       IDifficultyProvider        │
  │  5. await SpawnManager.OnWaveComplete                            │
  │  6. _score = _waveNumber                                         │
  │  7. 3s breathing window (yield WaitForSeconds)                   │
  │  8. if (_waveNumber % 5 == 0): DraftRunController.ShowDraft()    │
  │     await DraftRunController.OnDraftComplete                     │
  │  9. repeat from step 1                                           │
  └─────────────────────────────────────────────────────────────────┘

On Player Death:
  EndlessSessionController.OnPlayerDied()
    → LevelStats.SaveEndlessScore(classType, _score)
    → ShowDeathScreen(wavesCleared, totalKills, combosDiscovered, classType)
```

### Key Interfaces

```csharp
/// <summary>
/// Generates wave composition for Endless Mode using the N2 formulas.
/// Implements IWaveProvider (ADR-0002) — SpawnManager calls this interface;
/// it has no knowledge of EndlessWaveProvider specifically.
/// SetWave() must be called by EndlessSessionController before each SpawnNextWave().
/// </summary>
public class EndlessWaveProvider : MonoBehaviour, IWaveProvider
{
    [SerializeField] private EndlessWaveConfig _config;

    private int _currentWave = 1;

    /// <summary>Called by EndlessSessionController before each wave spawn.</summary>
    public void SetWave(int waveNumber) => _currentWave = waveNumber;

    /// <summary>
    /// Computes wave composition from N2 formulas.
    /// enemyCount(wave)     = 4 + Floor(wave * 0.5)
    /// eliteRatio(wave)     = Min(0.50, wave * 0.02)
    /// enemyTypeCount(wave) = Min(5, 1 + Floor(wave / 5))
    /// </summary>
    public WaveData GetNextWave()
    {
        int   enemyCount     = 4 + Mathf.FloorToInt(_currentWave * 0.5f);
        float eliteRatio     = Mathf.Min(0.50f, _currentWave * 0.02f);
        int   enemyTypeCount = Mathf.Min(5, 1 + Mathf.FloorToInt(_currentWave / 5f));

        return new WaveData(
            enemyCount:     enemyCount,
            eliteRatio:     eliteRatio,
            enemyTypeCount: enemyTypeCount,
            enemyPool:      _config.EnemyPool,
            eliteTags:      _config.EliteTags
        );
    }

    /// <summary>Boss wave every 10 waves: wave % 10 == 0 and wave > 0.</summary>
    public bool IsBossWave() => _currentWave > 0 && _currentWave % 10 == 0;

    /// <summary>
    /// Cycles through the 5 campaign bosses (A→E→A) with PhaseCount always 2.
    /// bossIndex = ((waveNumber / 10) - 1) % 5
    /// Wave 10→Boss A, Wave 20→Boss B, ..., Wave 60→Boss A (with scaled stats).
    /// </summary>
    public BossConfig GetBossConfig()
    {
        int bossIndex = ((_currentWave / 10) - 1) % 5;
        return _config.BossCycle[bossIndex];  // each SO has PhaseCount = 2
    }

    /// <summary>Endless arena has no traps per N2 GDD. Always returns null.</summary>
    public TrapPlacementData GetTrapLayout() => null;
}

/// <summary>
/// Tuning knob asset for Endless wave composition.
/// Boss cycle array, enemy pool, and elite tags are all Inspector-editable.
/// </summary>
[CreateAssetMenu(fileName = "EndlessWaveConfig", menuName = "Trizzle/EndlessWaveConfig")]
public class EndlessWaveConfig : ScriptableObject
{
    [Tooltip("5 boss configs in cycle order (A=0, B=1, C=2, D=3, E=4). Each must have PhaseCount = 2.")]
    public BossConfig[] BossCycle = new BossConfig[5];

    [Tooltip("Enemy prefab pool ordered by introduction wave. Index 0 = weakest (wave 1), last = strongest.")]
    public EnemyData[] EnemyPool;

    [Tooltip("Tags that identify elite enemy variants for eliteRatio selection.")]
    public string[] EliteTags;
}

/// <summary>
/// Coordinates an Endless Mode run: wave counter, draft timing, boss cycling,
/// score tracking, and run termination. Lives in the Endless arena scene.
/// Delegates spawn to SpawnManager (via IWaveProvider) and difficulty to
/// EndlessDifficultyProvider (via IDifficultyProvider) — does not own either concern.
/// </summary>
public class EndlessSessionController : MonoBehaviour
{
    [SerializeField] private EndlessWaveProvider      _waveProvider;
    [SerializeField] private EndlessDifficultyProvider _difficultyProvider;

    private int             _waveNumber;
    private int             _score;
    private PlayerClassType _classType;

    /// <summary>
    /// Entry point called from the main menu Endless Mode button.
    /// Sets providers on GameManager and SpawnManager, then begins the wave loop.
    /// </summary>
    public void StartRun(PlayerClassType classType)
    {
        _classType  = classType;
        _waveNumber = 0;
        _score      = 0;

        GameManager.Instance.SetDifficultyProvider(_difficultyProvider);
        SpawnManager.Instance.SetWaveProvider(_waveProvider);

        StartCoroutine(WaveLoop());
    }

    private IEnumerator WaveLoop()
    {
        while (true)
        {
            _waveNumber++;

            // Sync wave number to both providers before any spawn or scaling call.
            _difficultyProvider.SetWave(_waveNumber);
            _waveProvider.SetWave(_waveNumber);

            SpawnManager.Instance.SpawnNextWave();
            yield return new WaitUntil(() => SpawnManager.Instance.IsWaveComplete);

            _score = _waveNumber;
            UpdateScoreHUD(_score);

            yield return new WaitForSeconds(3f);  // breathing window

            if (_waveNumber % 5 == 0)
            {
                DraftRunController.Instance.ShowDraft();
                yield return new WaitUntil(() => DraftRunController.Instance.IsDraftComplete);
            }
        }
    }

    /// <summary>
    /// Subscribed to the player death event. Terminates the wave loop,
    /// persists the high score, and shows the death screen.
    /// </summary>
    public void OnPlayerDied()
    {
        StopAllCoroutines();
        LevelStats.SaveEndlessScore(_classType, _score);
        ShowDeathScreen();
    }

    private void UpdateScoreHUD(int waves) { /* updates top-right HUD wave counter */ }
    private void ShowDeathScreen()         { /* triggers death screen with _score, kills, combos, class */ }
}
```

### Score Persistence Contract

Per-class high scores use the existing `LevelStats` system (D11) with two synthetic
level IDs:

| Class | Level ID |
|-------|----------|
| Mage | `"Endless_Mage"` |
| Archer | `"Endless_Archer"` |

`LevelStats.SaveEndlessScore(classType, wavesCleared)` writes the score only if
`wavesCleared > existingHighScore` (same pattern as campaign room best-time saving).
No new save field, no new persistence class, no new save schema.

---

## Alternatives Considered

### Alternative 1: Extend SpawnManager to own Endless session logic

- **Description**: SpawnManager grows an Endless mode branch: it holds the wave
  counter, triggers drafts at wave % 5, and cycles bosses at wave % 10. All session
  state lives in the existing manager.
- **Pros**: One fewer class. No new MonoBehaviour in the Endless scene.
- **Cons**: SpawnManager is already the highest-risk hotspot (touched by E1, E2, E3,
  N2 per architecture.md Section 4). Adding session ownership violates Single
  Responsibility. Wave-completion logic, draft trigger logic, and boss cycling would
  all need to be disentangled if any one changes. Untestable in isolation — testing
  draft trigger timing requires a running SpawnManager.
- **Rejection Reason**: Contradicts the architecture document's explicit goal of
  keeping SpawnManager unified but not a god class. ADR-0002 already establishes the
  IWaveProvider boundary precisely to prevent SpawnManager from accumulating N2 logic.

### Alternative 2: Extend DraftRunController to own Endless draft timing

- **Description**: DraftRunController tracks a wave counter and triggers itself every
  5 waves in Endless mode, removing the need for `EndlessSessionController` to call it.
- **Pros**: Draft timing is co-located with draft logic.
- **Cons**: DraftRunController is a campaign system (D7). Making it aware of Endless
  wave numbers inverts the dependency direction — a Content Layer detail (N2 wave
  count) would reach into a Meta Layer system (D7 draft). Architecture Principle:
  downward dependency only (architecture.md Section 3, Layer Rules Rule 1).
- **Rejection Reason**: Violates layer rules. `EndlessSessionController` owns the
  Endless run state; it calls `DraftRunController.ShowDraft()` as a collaborator, not
  the reverse. This keeps DraftRunController Endless-agnostic.

### Alternative 3: Separate EndlessScoreManager for score persistence

- **Description**: Introduce a new `EndlessScoreManager` singleton that owns high
  score storage, separate from `LevelStats`.
- **Pros**: Isolated concern. No coupling to campaign persistence logic.
- **Cons**: Adds a 47th manager to an already-large manager set. `LevelStats` already
  handles per-run completion data; a synthetic level ID costs nothing and avoids
  parallel save paths that would need synchronization. Architecture Open Question A4
  (architecture.md Section 10) explicitly recommended this approach.
- **Rejection Reason**: Unnecessary new persistence path. `LevelStats` with synthetic
  IDs is the low-complexity solution endorsed by the architecture document.

---

## Consequences

### Positive

- `EndlessSessionController` owns exactly one concern: coordinating a run. SpawnManager,
  DraftRunController, and LevelStats remain unchanged for Endless — they are called, not
  modified.
- `EndlessWaveProvider` is fully testable in isolation: given a wave number, it returns
  deterministic `WaveData`. No SpawnManager instance required for unit tests.
- `EndlessDifficultyProvider` (specified in ADR-0001) is already testable in isolation
  for the same reason.
- Score persistence requires no new save schema — the first Endless run works on an
  existing save file without migration.
- All N2 tuning knobs (scaling rates, boss cycle order, enemy pool, floors) are
  Inspector-editable via `EndlessWaveConfig` and `EndlessDifficultyConfig` SOs.
- Future extensions (Endless modifiers, wave modifiers, trap introduction at wave 15)
  can be added to `EndlessWaveProvider` or `EndlessSessionController` without touching
  SpawnManager.

### Negative

- `EndlessSessionController` introduces a new MonoBehaviour that must be wired in the
  Endless arena scene. Missed inspector references (wave provider, difficulty provider)
  will cause null errors at run start — requires a null guard in `StartRun()`.
- The wave loop coroutine in `EndlessSessionController` coordinates three async
  concerns (spawn completion, breathing window, draft completion). If any one does not
  resolve (e.g., `DraftRunController.IsDraftComplete` never flips), the coroutine
  hangs. Each `WaitUntil` needs a timeout safeguard.
- Using `SpawnManager.IsWaveComplete` as a polling flag (rather than an event) is
  slightly less clean than a `C# event` subscription. If SpawnManager adds an
  `OnWaveComplete` event in its ADR-0002 implementation, `EndlessSessionController`
  should be updated to subscribe to that event instead.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `EndlessDifficultyProvider.SetWave()` called after `SpawnManager.SpawnNextWave()` — stats one wave behind | LOW | MEDIUM — wave 1 enemies receive wave 0 stats | Enforce ordering in `WaveLoop()` coroutine: SetWave() is always called before SpawnNextWave(). Add a development-build assertion in EndlessWaveProvider. |
| `WaveLoop()` coroutine hangs if `IsDraftComplete` never returns true (draft UI crash) | LOW | HIGH — run becomes unresponsive | Add a `WaitUntil` timeout of 60s with an error log and forced draft-close fallback. |
| `BossCycle` array shorter than 5 elements — `IndexOutOfRangeException` at wave 10 | LOW | HIGH — crash on first boss wave | Validate `BossCycle.Length == 5` in `EndlessWaveProvider.Awake()`. Log error and prevent run start if misconfigured. |
| Combo discovery `discoveredFlag` set in Endless persists to campaign (N2 GDD Edge Case 3) — may surprise players who expect campaign discovery to be separate | MEDIUM | LOW — design intent per N2 GDD, but may generate player confusion | Document in release notes and in-game tooltip: "Combos discovered in Endless count for your collection." |
| `"Endless_Mage"` / `"Endless_Archer"` level IDs collide with a future campaign level named "Endless" | LOW | LOW — save data conflict, not a crash | Reserve these IDs in `LevelDatabase` as Endless-only. Document the convention. |

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `endless-mode.md` | Wave scaling formulas: `enemyCount(wave) = 4 + Floor(wave * 0.5)`, `eliteRatio(wave) = Min(0.50, wave * 0.02)`, `enemyTypeCount(wave) = Min(5, 1 + Floor(wave/5))` | All three formulas are implemented in `EndlessWaveProvider.GetNextWave()`. Constants are not hardcoded — scaling factors derive from the GDD formulas directly with no tuning knob needed (they are the design, not a tuning value). |
| `endless-mode.md` | Boss cycling: Wave 10 → Boss A (Stone Guardian), Wave 20 → Boss B, ..., Wave 60+ → cycle back to Boss A with enhanced stats. Always 2-phase in Endless. | `EndlessWaveProvider.GetBossConfig()` uses deterministic index `((wave/10)-1) % 5`. Each `BossConfig` SO in the cycle has `PhaseCount = 2`. Enhanced stats at wave 60+ are automatic via `EndlessDifficultyProvider` stat scaling — no special boss cycling logic needed. |
| `endless-mode.md` | Draft every 5 waves, using same `DraftRunController` and skill pool as campaign. Class filtering applies. | `EndlessSessionController.WaveLoop()` calls `DraftRunController.ShowDraft()` when `_waveNumber % 5 == 0`. DraftRunController is called unchanged — it already applies class filtering. |
| `endless-mode.md` | "Config routing: SpawnManager reads `EndlessDifficultyConfig` in Endless mode, NOT campaign DifficultyConfig." | `EndlessSessionController.StartRun()` calls `GameManager.SetDifficultyProvider(endlessDifficultyProvider)` at Endless entry, setting the IDifficultyProvider contract established in ADR-0001. SpawnManager reads IDifficultyProvider — it never reads DifficultyConfig directly. |
| `endless-mode.md` | Arena: single 30x30 unit arena, Arena archetype, no traps, 6 spawn points. | `EndlessWaveProvider.GetTrapLayout()` always returns null. Arena layout is a scene-level decision; the Endless arena scene is a single room with 6 `EnemySpawnPoint` transforms and no trap prefabs. |
| `endless-mode.md` | Score persistence: per-class leaderboard using existing `LevelStats` system with special "Endless" level ID. | `LevelStats.SaveEndlessScore()` uses IDs `"Endless_Mage"` and `"Endless_Archer"`. No new persistence class or schema. |
| `endless-mode.md` | No mid-run save (intentional — runs are 10-15 min, saves would allow save-scumming). | `EndlessSessionController` holds all run state in memory only. Quitting triggers `OnPlayerDied()` which persists only the high score — not the run state. |
| `endless-mode.md` | 3s breathing window between waves. | `WaveLoop()` coroutine yields `WaitForSeconds(3f)` after each `OnWaveComplete`. |
| `difficulty-system.md` | "Endless Mode has its own `EndlessDifficultyConfig` with wave-based scaling, independent of campaign DifficultyConfig." | `EndlessDifficultyProvider` (specified in ADR-0001, referenced here) reads `EndlessDifficultyConfig` SO exclusively. Campaign providers remain untouched. |

---

## Performance Implications

| Metric | Expected Impact | Budget |
|--------|----------------|--------|
| CPU — `EndlessWaveProvider.GetNextWave()` per wave | 4 integer/float operations + array slice. ~0.001ms. Negligible — runs once per wave, not per frame. | No budget needed |
| CPU — `EndlessSessionController` coroutine overhead | One coroutine running per wave cycle, awaiting `WaitUntil` (polls `IsWaveComplete` once per frame). Standard Unity coroutine cost: ~0.001ms/frame. | Within existing coroutine budget |
| Memory — `EndlessWaveConfig` ScriptableObject | Single SO with BossConfig[5] + EnemyData[] references. <2KB. | Negligible |
| Enemy count at wave 30 | `enemyCount(30) = 4 + Floor(15) = 19` enemies simultaneously. Architecture.md performance risk register: <16.6ms PC, <33ms mobile. | Existing object pooling handles this; mobile performance cap (if needed) is a platform config, not in this ADR. |
| Draft screen frequency | Every 5 waves. DraftRunController is not hot-path code. | No concern |

---

## Migration Plan

This ADR introduces all-new code. No existing system is modified, only called.

1. **Create `EndlessWaveConfig` ScriptableObject** — new file. Create
   `EndlessWaveConfig.asset` in `Assets/Trizzle/Data/Endless/`. Author
   `EndlessBossConfig_A.asset` through `EndlessBossConfig_E.asset` with `PhaseCount = 2`
   (requires E3 BossConfig schema from ADR-0003 to be complete first).
2. **Create `EndlessWaveProvider` MonoBehaviour** — new file. Add to GameManager's
   GameObject or a dedicated `EndlessManager` child in the Endless arena scene.
   Wire `_config` reference to `EndlessWaveConfig.asset`. Verify `GetNextWave()` unit
   tests pass for waves 1, 10, 20, 30.
3. **Verify `EndlessDifficultyProvider`** — already specified in ADR-0001. Confirm it
   is implemented and passing its ADR-0001 validation criteria before proceeding.
4. **Create `EndlessSessionController` MonoBehaviour** — new file. Place in Endless
   arena scene. Wire `_waveProvider` and `_difficultyProvider` inspector references.
   Add `StartRun()` call from main menu Endless button. Add null guards in `Awake()`.
5. **Extend `LevelStats`** — add `SaveEndlessScore(PlayerClassType, int)` method if
   not already present. Verify write/read cycle with IDs `"Endless_Mage"` and
   `"Endless_Archer"`.
6. **Create Endless arena scene** — 30x30 unit room using Arena archetype, 6
   `EnemySpawnPoint` transforms, no trap prefabs. Reuses Arena lighting. Add
   `EndlessSessionController` to scene.
7. **Wire main menu** — add Endless Mode button to `MainMenuPanel`. On click:
   show class selector (Mage / Archer if unlocked), then call
   `EndlessSessionController.StartRun(selectedClass)`.
8. **Integration test**: Complete a simulated 15-wave run. Verify: enemy counts match
   formula, draft appears at waves 5/10/15, boss appears at wave 10, score persists
   after death.

**Rollback plan**: All N2 code is additive. If `EndlessSessionController` must be
reverted, removing it from the Endless arena scene and unregistering the main menu
button restores the pre-N2 state with zero impact on campaign code.

---

## Validation Criteria

- [ ] `EndlessWaveProvider.GetNextWave()` unit test: wave 1 → 4 enemies, 2% elite ratio,
  1 type. Wave 10 → 9 enemies, 20% elite ratio, 3 types. Wave 20 → 14 enemies, 40%
  elite ratio, 5 types (cap). Wave 30 → 19 enemies, 50% elite ratio (cap), 5 types.
- [ ] `EndlessWaveProvider.IsBossWave()` unit test: returns true for wave 10, 20, 30, 60;
  returns false for wave 1, 5, 11, 25.
- [ ] `EndlessWaveProvider.GetBossConfig()` unit test: wave 10 → BossCycle[0] (Boss A);
  wave 50 → BossCycle[4] (Boss E); wave 60 → BossCycle[0] (cycle restart, Boss A).
- [ ] `EndlessWaveProvider.GetTrapLayout()` always returns null.
- [ ] All 5 `EndlessBossConfig` assets have `PhaseCount == 2`.
- [ ] Integration test: start Endless run as Mage, survive to wave 6. Verify draft appears
  after wave 5 clears. Verify draft uses Mage skill pool.
- [ ] Integration test: survive to wave 11. Verify boss spawns at wave 10, no regular
  enemies spawn on boss wave.
- [ ] `EndlessDifficultyProvider` validation criteria from ADR-0001 all pass (wave 10 stat,
  heal drop, pacing values match formula).
- [ ] Score saves correctly: die at wave 17 as Mage. Reload. `"Endless_Mage"` high score
  reads 17. Start Archer run, die at wave 8. `"Endless_Archer"` = 8, `"Endless_Mage"` = 17
  (unchanged).
- [ ] N2 Acceptance Criteria 1-10 from `design/gdd/endless-mode.md` all pass.

---

## Related Decisions

- ADR-0001: DifficultyConfig as Interface — defines `IDifficultyProvider` and
  `EndlessDifficultyProvider` (the difficulty half of this integration)
- ADR-0002: SpawnManager Mode Routing — defines `IWaveProvider` and
  `EndlessWaveProvider` slot (the wave generation half of this integration)
- ADR-0003: BossController Subclass vs Composition — `BossConfig` ScriptableObject
  schema used by `EndlessWaveConfig.BossCycle` must be compatible with E3's decision
- `design/gdd/endless-mode.md` — N2 GDD, primary source for all wave formulas, arena
  layout, draft timing, boss cycle, and score persistence requirements
- `design/gdd/difficulty-system.md` — E2 GDD, documents the `EndlessDifficultyConfig`
  independence requirement
- `docs/architecture/architecture.md` — Section 5.4 (Endless wave loop data flow),
  Section 7 (ADR-007 requirement), Section 10 Open Question A4 (LevelStats decision)
