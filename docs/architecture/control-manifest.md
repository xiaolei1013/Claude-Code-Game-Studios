# Control Manifest — Trizzle / Shadow Quest v1.0

Manifest Version: 2026-04-18-v2
Engine: Unity 6000.3.11f1
ADRs Covered: ADR-0001 through ADR-0008

---

## Section 1: REQUIRED (Must Do)

### Interfaces

- R-001: Implement `IDifficultyProvider` for every class that supplies difficulty multipliers. `CampaignDifficultyProvider` and `EndlessDifficultyProvider` are the two concrete implementations for v1.0. (Source: ADR-0001)
- R-002: Implement `IWaveProvider` for every class that supplies wave data to `SpawnManager`. `CampaignWaveProvider` and `EndlessWaveProvider` are the two concrete implementations. (Source: ADR-0002)
- R-003: Implement `IBossPhaseController` on `BossController`. This is the only interface external systems (`SpawnManager`, `DraftRunController`) depend on for boss state. (Source: ADR-0004)
- R-004: Implement `ICharacterClass` on both `MagePlayerController` and `ArcherPlayerController`. Shared skills must cast to `ICharacterClass` or `PlayerController`, never to `MagePlayerController`. (Source: ADR-0005)
- R-005: Implement `IComboRegistry` on `ComboRegistry`. `DraftRunController` calls this interface after each draft pick; it must not reference `ComboRegistry` directly. (Source: ADR-0003)

### Patterns

- R-006: All difficulty multiplier consumers (`SpawnManager`, `EnemyController`, drop behaviors, `EndlessWaveSpawner`) must read from `GameManager.Instance.ActiveDifficultyProvider` using `IDifficultyProvider`. Never access `DifficultyConfig` fields or difficulty enums directly in consumer code. (Source: ADR-0001)
- R-007: `SpawnManager` must call `ActiveWaveProvider.GetNextWave()` for wave composition, then apply `IDifficultyProvider` multipliers separately. These two interface calls must never be merged. (Source: ADR-0002)
- R-008: `BossController` must subscribe to `Health.OnDamaged` in `Awake()` and check thresholds per damage event — not in `Update()`. (Source: ADR-0004)
- R-009: Sort `BossController._phases` by `HealthThreshold` ascending at `Awake()`. Iterate all untriggered phases per damage event to handle multi-threshold skips correctly. (Source: ADR-0004)
- R-010: Boss phase transitions must use the stagger coroutine sequence: set invulnerable → `StateMachine.ResetState()` → swap `BehaviourTree` → apply `StatModifiers` → instantiate `TransitionVFX` → set `HasTriggered = true` → fire `OnPhaseTransition` → `WaitForSeconds(0.5f)` → lift invulnerable. (Source: ADR-0004)
- R-011: `ComboEffect.Activate(PlayerController)` must register event listeners and apply immediate attribute modifications. `ComboEffect.Deactivate()` must unsubscribe all listeners and reverse all attribute changes — leaving the asset clean for reuse next run. (Source: ADR-0003)
- R-012: Each `ComboEffect.Activate()` must call `Deactivate()` as its first step, as a guard against Editor play-mode state leaks. (Source: ADR-0003)
- R-013 (v2): Before calling `SpawnManager.SpawnNextWave()`, `EndlessSessionController.WaveLoop()` must call `_difficultyProvider.SetWave(_waveNumber)` and `_waveProvider.SetWave(_waveNumber)`. This ordering applies ONLY to the Endless path — campaign flow does not call `SetWave` on `CampaignWaveProvider` because `SetWave(int)` is not on the `IWaveProvider` interface; it is a method exposed by `EndlessWaveProvider` only. `CampaignWaveProvider` is initialized by `SetRoom(RoomConfig)` at room entry and auto-advances its internal wave index on each `GetNextWave()` call. (Source: ADR-0001, ADR-0007, ADR-0008)
- R-014: `DraftRunController.ShowDraft()` must filter candidates through `CanApplyUpgrade(player.CollectedSkills)` before building the draft pool. No class-specific `if` branches in `DraftRunController`. (Source: ADR-0005)
- R-029: `SpawnManager.SpawnNextWave()` must call `ExpandToSpawnQueue()` exactly once per wave to produce the internal `List<SpawnItemInfo>` queue, then `ApplyDifficulty()` exactly once on that queue before dispatching. The sequence `GetNextWave → Expand → ApplyDifficulty → Dispatch` is mandatory and must not be re-ordered. (Source: ADR-0008)

### Data Structures

- R-015: Define `DifficultyConfig` as a `ScriptableObject` (not a struct). Create `DifficultyConfig_Normal.asset` and `DifficultyConfig_Hard.asset`. Create `EndlessDifficultyConfig.asset` for Endless tuning knobs. (Source: ADR-0001)
- R-016: Define `BossPhase` as a `[System.Serializable]` struct (not a ScriptableObject) with fields: `HealthThreshold`, `BehaviourTree`, `TransitionVFX`, `StatModifiers[]`, `HasTriggered`. (Source: ADR-0004)
- R-017: Define `RoomConfig` as a `ScriptableObject` with fields: `ThemeName`, `Archetype` (enum), `Waves` (list of `WaveDefinition`), `BossConfig`, `TrapPlacements`. One asset per room, 10 total in `Assets/Trizzle/Data/Rooms/`. (Source: ADR-0006)
- R-018: Define `RoomArchetype` as an enum with exactly these values: `Swarm`, `Ambush`, `Gauntlet`, `Arena`, `Hybrid`. (Source: ADR-0006)
- R-019: Define `ComboEffect` as an abstract `ScriptableObject` with three entry points: `Activate(PlayerController)`, `Deactivate()`, and `virtual OnTrigger(TriggerContext)`. Each of the 18 combos is a concrete subclass asset. (Source: ADR-0003)
- R-020: Define `TriggerContext` as a `readonly struct` (stack-allocated). Fields: `TriggeringSkill`, `TargetHealth`, `DamageAmount`, `TriggerPosition`. (Source: ADR-0003)
- R-021: Define `WaveData` as a plain struct (zero heap allocation). Fields: `BaseEnemyCount`, `EliteRatio`, `EnemyTypes`, `BaseSpawnDelay`. No logic in this struct. (Source: ADR-0002)
- R-022: Add `bool IsBoss` to `EnemyData` ScriptableObject. This is the sole mechanism for boss detection throughout the codebase. (Source: ADR-0004)

### Naming Conventions

- R-023: Archer-exclusive skill assets go in `Assets/Trizzle/Data/Skill/Archer/`. Combo effect assets go in `Assets/Trizzle/Data/Combos/Effects/[Mage|Archer|Universal]/`. (Source: ADR-0005, ADR-0003)
- R-024: Endless score level IDs are `"Endless_Mage"` and `"Endless_Archer"`. These strings are reserved in `LevelStats` and must not be used for campaign rooms. (Source: ADR-0007)
- R-025: Boss ability templates are named `GroundSlamAbility`, `ChargeAbility`, `ShieldPhaseAbility`, `RainOfFireAbility` and live in `Assets/Trizzle/Scripts/Combat/BossAbilities/`. (Source: ADR-0004)

### Event Subscription Patterns

- R-026: `OnSkillUse` combo effects subscribe to `PlayerController.OnSkillUsed` in `Activate()`. `OnKill` combo effects subscribe to the project-wide kill event (confirm exact name against `Health.cs` and `PlayerController.cs` during implementation). `Passive` effects call `AttributeModifier.Add()` in `Activate()` — no event subscription needed. (Source: ADR-0003)
- R-027: `SpawnManager` and `DraftRunController` subscribe to `IBossPhaseController.OnBossDefeated` and `IBossPhaseController.OnPhaseTransition` — never poll `CurrentPhaseIndex` per frame. (Source: ADR-0004)
- R-028: `ComboRegistry.CheckCombos()` fires `IComboRegistry.OnComboDiscovered` exactly once per newly discovered combo per run. The combo discovery UI subscribes to this event. (Source: ADR-0003)
- R-030: `SpawnManager.OnWaveComplete` must fire AFTER `IsWaveComplete` is set to `true`, in the same statement block, so any event handler that re-reads the property observes the new value. The event fires exactly once per wave; re-entry on an already-complete wave is a programmer error. (Source: ADR-0008)
- R-031: Wave-completion consumers should subscribe to `SpawnManager.OnWaveComplete` in `Awake()` (one-shot handler pattern). `EndlessSessionController.WaveLoop()` is grandfathered to use `WaitUntil(() => SpawnManager.IsWaveComplete)` because it is a coroutine; new consumers must use the event unless they have a coroutine-shaped reason to poll. (Source: ADR-0008)

---

## Section 2: FORBIDDEN (Must Not Do)

- F-001: Do not access `DifficultyConfig` fields or check difficulty enums in `SpawnManager`, `EnemyController`, or drop behaviors. All reads go through `IDifficultyProvider`. — Direct struct/enum access scatters mode-branching across four systems. (Source: ADR-0001)
- F-002: Do not use static utility classes or static singletons for game state (e.g., a static `DifficultyManager`). — Untestable, not injectable, adds an effective 47th singleton. (Source: ADR-0001)
- F-003: Do not write runtime values into ScriptableObject assets. SOs are read-only data authored in the Inspector. — Writing `waveNumber` to an SO dirties it in memory and creates state management bugs across play sessions. (Source: ADR-0001, ADR-0002)
- F-004: Do not add an Endless mode branch inside `SpawnManager` (`if (mode == Endless)`). SpawnManager must have zero mode-awareness — it calls `IWaveProvider` regardless of mode. — Produces a god class; violates Open/Closed Principle. (Source: ADR-0002)
- F-005: Do not split `SpawnManager` into `CampaignSpawnManager` and `EndlessSpawnManager`. — Duplicates wave-completion logic, breathing window, draft-trigger counting, and boss detection. (Source: ADR-0002)
- F-006: Do not store wave data in a mutable shared `WaveSequence` ScriptableObject written at runtime. — Same as F-003: SO dirtying, test isolation failure. (Source: ADR-0002)
- F-007: Do not use tag or name string comparisons for boss detection in `SpawnManager`, `OneShotKillEffect`, or `DraftRunController.OnRunComplete()`. Use `EnemyData.IsBoss`. — String comparisons are rename-fragile and not IDE-searchable by reference. (Source: ADR-0004)
- F-008: Do not compose boss phases via a `BossPhaseComponent` attached to an existing `EnemyController`. `BossController` must subclass `EnemyController`. — Composition requires exposing 20+ internal EnemyController methods and creates two boss patterns; contradicts the established `DragonEnemyController` inheritance convention. (Source: ADR-0004)
- F-009: Do not define `BossPhase` data as separate `ScriptableObject` assets (one per phase). Use `[System.Serializable]` struct in the prefab Inspector. — No reuse benefit for v1.0; adds asset management overhead. (Source: ADR-0004)
- F-010: Do not cast to `MagePlayerController` in any shared skill code (`DashSkill` or any new shared skill). Cast to `PlayerController` or `ICharacterClass` instead. — Causes `InvalidCastException` at runtime for Archer players. (Source: ADR-0005)
- F-011: Do not use the adapter pattern (Archer as subclass of `MagePlayerController`). Archer is a direct subclass of `PlayerController`. — Semantically wrong; causes `is MagePlayerController` checks to match Archer incorrectly; violates Liskov Substitution. (Source: ADR-0005)
- F-012: Do not poll combo trigger conditions in a per-frame `Update()` loop. All combo triggers are event-subscribed or fully passive (attribute modifier). — 18 per-frame checks violates the < 0.5 ms/frame combo budget; polling grows linearly with combo count. (Source: ADR-0003)
- F-013: Do not implement `ComboEffect` as a `MonoBehaviour` added via `AddComponent` at runtime. — Heap allocation on combo discovery; per-effect `Update()` required; cannot be authored as flat Inspector assets in `ComboDatabase`. (Source: ADR-0003)
- F-014: Do not make `DraftRunController` aware of Endless wave numbers or manage Endless draft timing internally. — Inverts dependency direction: a Content layer detail (N2 wave count) would reach into a Meta layer system (D7 draft). `EndlessSessionController` calls `DraftRunController.ShowDraft()`. (Source: ADR-0007)
- F-015: Do not author per-difficulty `RoomConfig` variants (separate Normal and Hard assets per room). Hard mode is derived at runtime from the Normal baseline via `IDifficultyProvider` multipliers. — Doubles the authoring burden; creates a sync maintenance problem. (Source: ADR-0006)
- F-016: Do not store room data in JSON/CSV external files or inline scene MonoBehaviours. Room data lives in `RoomConfig` ScriptableObjects. — JSON requires a custom parser and loses type safety and prefab references. Scene MonoBehaviours cannot be referenced cross-scene. (Source: ADR-0006)
- F-017: Do not introduce new architectural paradigms (DOTS, Zenject, reactive streams) for v1.0. All systems use MonoBehaviour + ScriptableObject + C# interface patterns. — Migration cost exceeds benefit for a solo developer shipping in 12-18 months. (Source: architecture.md P1)
- F-018: Do not add platform-specific gameplay logic inside wave generation, `BossController`, or `ComboEffect`. Platform divergence lives in `Scenes/PC/`, `Scenes/Mobile/`, and platform config assets only. (Source: architecture.md P4)

---

## Section 3: GUARDRAILS (Boundaries)

### Performance Budgets

- G-001: Frame time (PC): < 16.6 ms (60 FPS). Frame time (Mobile): < 33 ms (30 FPS). These are hard targets for all gameplay states including Endless wave 30+. (Source: architecture.md)
- G-002: Total combo system CPU cost: < 0.5 ms/frame across all active combos simultaneously. Passive effects cost 0 per frame; event-triggered effects cost only on event delivery. (Source: ADR-0003, architecture.md Appendix B)
- G-003: `EndlessDifficultyProvider` property computation (per wave start): < 1 microsecond. Runs once per wave, not per frame. (Source: ADR-0001)
- G-004: Boss phase check overhead: O(n) where n ≤ 3 phases, triggered per damage event not per frame. (Source: ADR-0004)
- G-005: `IWaveProvider.GetNextWave()` call (per wave start): Campaign ≈ 1–2 ns; Endless ≈ 1 ns. Interface dispatch overhead ≈ 2–3 ns. All negligible — spawn events are infrequent, never in `Update()`. (Source: ADR-0002)

### Safe Ranges for Tuning Knobs

- G-006: Endless pacing multiplier floor: 0.5 (minimum). Configured in `EndlessDifficultyConfig.PacingFloor`. Do not set below 0.5 — spawn loop becomes unplayable. (Source: ADR-0001)
- G-007: Endless heal drop multiplier floor: 0.1 (minimum). Configured in `EndlessDifficultyConfig.HealDropFloor`. (Source: ADR-0001)
- G-008: Endless elite ratio cap: 50% (`eliteRatio = Min(0.50, wave * 0.02)`). Do not remove this cap — runs become unwinnable. (Source: ADR-0007)
- G-009: Elemental Storm bonus hit limit: 5 hits per trigger (B4 resolved). `ElementalStormComboEffect._hitLimit` must not be removed — uncapped version was confirmed degenerate. (Source: ADR-0003, architecture.md Section 9)
- G-010: Trap coverage per room: ≤ 15% of navigable floor area. Enforced at authoring time (manual QA check). At least one safe path must always exist. (Source: ADR-0006)
- G-011: Max concurrent enemies (campaign): ~13 enemies + 1 boss + minions. Max concurrent enemies (Endless wave 30): 19+ enemies. Object pooling is required; do not instantiate/destroy enemies at runtime. (Source: architecture.md)
- G-012: `BossController._phases` list length: 2 phases for rooms 1–5 and Endless, 3 phases for rooms 6–10. Validate in `Awake()`. (Source: ADR-0004)
- G-013: `EndlessWaveConfig.BossCycle` array must contain exactly 5 entries. Validate in `EndlessWaveProvider.Awake()` — log error and block run start if misconfigured. (Source: ADR-0007)

### Platform Constraints

- G-014: PC and Mobile share all Gameplay, Content, Meta, and Infrastructure code. Platform divergence is limited to `Scenes/PC/`, `Scenes/Mobile/`, `UI/PC/`, and `Manager/PC/`. (Source: architecture.md P4)
- G-015: Mobile enemy count cap (if needed at wave 30+) lives in a platform config asset, not in `EndlessWaveProvider` or `EndlessSessionController`. (Source: ADR-0007)

---

## Section 4: LAYER RULES

### Foundation Layer (E2 Difficulty, E5 Incomplete Skills)

**Owns:** `IDifficultyProvider`, `CampaignDifficultyProvider`, `EndlessDifficultyProvider`, `DifficultyConfig` ScriptableObject assets, `EndlessDifficultyConfig` SO.

**Must not touch:** Scene objects, SpawnManager, player state, UI. This layer is pure data contract and computation.

**Depends on:** Nothing. This is Layer 0 — no other ADR must be Accepted before this.

**Everything else depends on it:** ADR-0002 (`IWaveProvider`) cannot be Accepted; E2, N2 stories cannot be written to Ready; until `IDifficultyProvider` is stable.

### Core Layer (N1 Archer, E3 Boss Phases, E4 Combos)

**Owns:** `ArcherPlayerController`, `ICharacterClass`, `ArrowShotSkill`, `DodgeRollSkill`, 7 Archer-exclusive skill SOs; `BossController`, `BossPhase` struct, `IBossPhaseController`, 4 ability template MonoBehaviours; `ComboEffect` abstract SO, 18 concrete `ComboEffect` assets, `ComboRegistry`, `IComboRegistry`, `TriggerContext`.

**Depends on:** Foundation layer (`IDifficultyProvider` for boss stat scaling). `PlayerController` base class. Existing shipped systems: `Health.OnDamaged`, `DamageCalculator`, `AttributeModifier`, `SpawnManager` (via interface), `StateMachine`.

**Must not touch:** UI layer, save/load internals, localization keys (extend, don't modify existing).

**Cross-layer communication:** `BossController` broadcasts `IBossPhaseController.OnPhaseTransition` and `OnBossDefeated` events. `ComboRegistry` fires `IComboRegistry.OnComboDiscovered`. Upper layers subscribe to these — never call down into Presentation or Meta.

### Content Layer (E1 Room Content, N2 Endless Mode)

**Owns:** 10 `RoomConfig` ScriptableObject assets, `WaveDefinition`, `TrapPlacement`, `RoomArchetype` enum; `EndlessSessionController`, `EndlessWaveProvider`, `EndlessWaveConfig` SO, `EndlessWaveConfig.asset`.

**Depends on:** All Core and Foundation layer interfaces (`IDifficultyProvider`, `IWaveProvider`, `IBossPhaseController`). Calls `DraftRunController.ShowDraft()` (Meta layer) via its existing API — Content drives Meta, not the reverse.

**Must not touch:** `SpawnManager` internals (reads only through `IWaveProvider`). `DifficultyConfig` assets directly. Any `RoomConfig` during Endless; `EndlessWaveProvider` generates data procedurally.

**Layer rule enforcement:** `EndlessSessionController` calls `DraftRunController.ShowDraft()` as a collaborator. `DraftRunController` must remain unaware of Endless wave numbers.

### Presentation Layer (D13 Audio, D14 UI, VFX, HUD)

**Owns:** All UI components (101+ existing, PC/Mobile split), combo discovery flash, boss phase transition VFX, Endless score HUD, death screen.

**Reads from:** Gameplay layer events only. `IComboRegistry.OnComboDiscovered` → flash UI. `IBossPhaseController.OnPhaseTransition` → phase VFX. `EndlessSessionController` score → HUD update.

**Must not own:** Game state. Presentation reads and displays; it never writes back to Gameplay or Content layer state.

**Platform split boundary:** The PC/Mobile UI split exists entirely in this layer. `Scenes/PC/` and `Scenes/Mobile/` diverge here. All Gameplay code below is shared.

---

## Section 5: ADR Quick Reference

| ADR | Status | Key Interface / Class | One-Line Summary |
|-----|--------|----------------------|-----------------|
| ADR-0001 | Proposed | `IDifficultyProvider` | All difficulty multiplier access goes through one interface; two providers (campaign flat SO, Endless per-wave computed) swap at mode entry via `GameManager.ActiveDifficultyProvider`. |
| ADR-0002 | Proposed | `IWaveProvider` | SpawnManager has zero mode-awareness; `CampaignWaveProvider` (reads `RoomConfig`) and `EndlessWaveProvider` (procedural formulas) swap at mode entry; difficulty scaling is always a separate call. |
| ADR-0003 | Proposed | `ComboEffect` (abstract SO), `IComboRegistry` | 18 combo effects are concrete `ScriptableObject` subclasses; triggers are event-subscribed (not polled); `Activate`/`Deactivate` lifecycle guarantees clean run boundaries; < 0.5 ms/frame budget. |
| ADR-0004 | Proposed | `IBossPhaseController` | `BossController : EnemyController` subclass with `List<BossPhase>` in Inspector; phases checked per damage event not per frame; `EnemyData.IsBoss` replaces all tag/string boss checks. |
| ADR-0005 | Accepted | `ICharacterClass` | Archer is a `PlayerController` subclass alongside Mage; `ICharacterClass` eliminates `MagePlayerController` casts in shared skills; class filtering is data-driven via `CanApplyUpgrade()`. |
| ADR-0006 | Proposed | `RoomConfig` (SO) | 10 `RoomConfig` ScriptableObjects store Normal-only wave/trap/boss data; Hard mode is derived at runtime by `CampaignWaveProvider` applying `IDifficultyProvider` multipliers — no per-difficulty authoring. |
| ADR-0007 | Proposed | `EndlessSessionController`, `EndlessWaveProvider` | Endless run is coordinated by `EndlessSessionController`; waves are procedural via `EndlessWaveProvider`; score persists to `LevelStats` with synthetic IDs `"Endless_Mage"` / `"Endless_Archer"`; no mid-run save. |
| ADR-0008 | Accepted | `SpawnManager` public API, `WaveData` (union) | Locks SpawnManager public surface (`SetWaveProvider`/`SpawnNextWave`/`IsWaveComplete`/`OnWaveComplete`); `WaveData` becomes an authored/procedural tagged union so campaign `SpawnItemInfo` lists and Endless recipes flow through one `GetNextWave()`; `IsWaveComplete` = dispatch exhausted ∧ zero live hostiles; event + polling both supported; `SetWave(int)` is Endless-only. |
