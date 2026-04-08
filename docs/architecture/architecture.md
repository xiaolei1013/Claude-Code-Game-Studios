# Master Architecture Document -- Trizzle / Shadow Quest v1.0

| Field | Value |
|-------|-------|
| **Status** | Draft -- Pending TD Approval |
| **Author** | Technical Director (Claude) + xiaolei |
| **Created** | 2026-04-07 |
| **Engine** | Unity 6000.3.11f1 (Unity 6.3 LTS) |
| **Rendering** | URP 17.3.0, Linear color space |
| **Codebase Size** | ~2,569 files, 46 singleton managers |
| **GDDs Covered** | E2 Difficulty, N1 Archer, E3 Boss Phases, E4 Combos, E1 Room Content, N2 Endless |
| **Existing Systems** | D1-D14 (14 shipped systems in demo) |

---

## 1. Engine Knowledge Gap Summary

**LLM cutoff**: May 2025. **Engine version**: Unity 6000.3.11f1 (Dec 2025).

The entire Unity 6 series post-dates the model's training data. Key gaps:

| Area | Risk | Mitigation |
|------|------|------------|
| Unity 6 rebrand (6000.x numbering) | HIGH | Always reference `docs/engine-reference/unity/VERSION.md` |
| DOTS / Entities 1.3+ | LOW | Project does not use DOTS; MonoBehaviour + ScriptableObject patterns are stable |
| URP 17.x changes | MEDIUM | Rendering pipeline may have new features/deprecations; verify shader compatibility |
| UI Toolkit (recommended over UGUI) | LOW | Project uses UGUI (101+ components shipped); migration not planned for v1.0 |
| New Input System as default | LOW | Project already uses `com.unity.inputsystem: 1.19.0` |
| C# 9 support | LOW | No breaking changes to existing C# patterns |

**Rule**: Any code suggestion involving Unity API must be verified against
`docs/engine-reference/unity/` before implementation. Do not trust LLM knowledge
of Unity APIs beyond 2022 LTS.

---

## 2. Technical Requirements Baseline

Extracted from 6 GDDs + game-concept + systems-index. These are the hard
technical constraints that architecture must satisfy.

### Performance Requirements

| Requirement | Source | Budget |
|-------------|--------|--------|
| Frame time (PC) | N2 Endless wave 30+ | < 16.6ms (60 FPS) |
| Frame time (Mobile) | N2 edge case #5 | < 33ms (30 FPS) |
| Max concurrent enemies (campaign) | E1 Room 10 Hard | ~13 enemies + 1 boss + summoned minions |
| Max concurrent enemies (Endless) | N2 wave 30 | 19+ enemies + boss at intervals |
| Projectile count (worst case) | N1 Multishot + Piercing | 3 arrows x 3 pierce = 9 simultaneous hits |
| Status effect ticks | D3 + E4 combos | 27 status types, multiple concurrent per enemy |

### Data Volume

| Content | Count | Storage |
|---------|-------|---------|
| Skills | 125+ (existing) + 9 new (2 base + 7 exclusive) | ScriptableObjects in `Data/Skill/` |
| Combos | 5 (existing placeholder) -> 18 (v1.0) | `ComboDatabase` ScriptableObject |
| Enemies | 30 controllers (existing) | Prefabs + `EnemyDatabase` |
| Rooms | 10 campaign + 1 Endless arena | `RoomConfig` ScriptableObjects |
| Bosses | 5 unique (new `BossController` prefabs) | Per-boss `BossPhase` configs |
| Traps | 14 types (existing) | Prefab library |
| Locales | 11 (existing) | Unity Localization package |

### Platform Requirements

| Platform | Input | Scenes | Notes |
|----------|-------|--------|-------|
| PC (Win/Mac/Linux) | Keyboard/Mouse + Gamepad | `Scenes/PC/` | Primary target, Steam |
| Mobile (Android/iOS) | Touch | `Scenes/Mobile/` | Separate scene hierarchy, separate UI |

---

## 3. System Layer Map

```
+============================================================================+
|                          PRESENTATION LAYER                                 |
|  D13 Audio | D14 UI (101+ components, PC/Mobile split) | VFX | HUD        |
|  Combo Discovery Flash (E4) | Boss Phase Transition VFX (E3)              |
+============================================================================+
        |                    |                    |
        v                    v                    v
+============================================================================+
|                           GAMEPLAY LAYER                                    |
|  D1 Core Combat    | D2 Health/Death  | D3 Status Effects (27 states)      |
|  D4 Skill System   | D5 Enemy AI      | D6 Traps (14 types)               |
|  ............................................................              |
|  N1 Archer (NEW)   | E3 Boss Phases (NEW) | E4 Combos (EXPAND)            |
|  E2 Difficulty (EXPAND)                                                    |
+============================================================================+
        |                    |                    |
        v                    v                    v
+============================================================================+
|                            CONTENT LAYER                                    |
|  E1 Room Content (10 rooms, 4 archetypes) (NEW)                           |
|  N2 Endless Mode (wave scaling, arena) (NEW)                               |
+============================================================================+
        |                    |                    |
        v                    v                    v
+============================================================================+
|                             META LAYER                                      |
|  D7 Roguelite Draft | D8 Loot | D9 Shop | D10 Currency                    |
|  N3 Achievements (P2, deferred)                                            |
+============================================================================+
        |                    |                    |
        v                    v                    v
+============================================================================+
|                        INFRASTRUCTURE LAYER                                 |
|  D11 Save/Load (CloudServiceManager) | D12 Localization (11 locales)      |
|  46 Singleton Managers | Object Pooling | ScriptableObject Data Layer      |
|  Platform/ (PC/Mobile split) | Steamworks.NET | Firebase Analytics         |
+============================================================================+
```

### Layer Rules

1. **Downward dependency only.** Presentation reads from Gameplay; Gameplay reads
   from Infrastructure. No upward calls.
2. **Event-based upward communication.** Lower layers emit events (e.g.,
   `Health.OnDamaged`); upper layers subscribe. No polling.
3. **Cross-layer data via ScriptableObject.** Shared configuration flows through
   ScriptableObject assets, not through manager references.

---

## 4. Module Ownership Map

| Module | Owner | New Files | Touches Existing |
|--------|-------|-----------|-----------------|
| **E2 Difficulty** | Gameplay | `DifficultyConfig.cs`, `DifficultyConfig.asset` (x2) | `EnemyController.InitAttributes()`, `SpawnManager`, drop behaviors, `MenuPrepareStagePanelPC` |
| **N1 Archer** | Gameplay | `ArcherPlayerController.cs`, `ArrowShotSkill.cs`, `DodgeRollSkill.cs`, 7 skill SOs, arrow prefab, dodge VFX | `PlayerController` (base class), `GamePlayDatabase` (new fields), `CharacterDatabase`, `DraftRunController` (class filter), `DashSkill` (refactor cast) |
| **E3 Boss Phases** | Gameplay | `BossController.cs`, `BossPhase.cs`, 4 ability templates (GroundSlam, Charge, ShieldPhase, RainOfFire), stagger VFX | `EnemyController` (subclass), `EnemyData` (add `isBoss`), `SpawnManager` (boss detection), `DraftRunController.OnRunComplete()` (fix hardcode), `OneShotKillEffect` (use `isBoss`) |
| **E4 Combos** | Gameplay | `ComboEffect.cs` (base), 18 ComboEffect SOs, combo discovery UI | `ComboDefinition` (extend), `ComboRegistry.CheckCombos()` (activate effects), `ComboDatabase.asset` (populate), save data (discoveredFlag) |
| **E1 Room Content** | Content | 10 `RoomConfig` SOs, spawn point layouts | `SpawnManager` (read RoomConfig), existing trap prefabs (placement) |
| **N2 Endless** | Content | `EndlessDifficultyConfig.cs`, Endless wave spawner, Endless arena scene, score HUD, death screen | `SpawnManager` (mode routing), `DraftRunController` (draft timing), `LevelStats` (Endless level ID), main menu (Endless entry) |

### Shared Code Hotspots (High Change Risk)

| File/Class | Systems Touching It | Risk |
|-----------|-------------------|------|
| `SpawnManager` | E1, E2, E3, N2 | HIGH -- 4 systems modify spawn behavior |
| `PlayerController` | N1, E4, D4 | MEDIUM -- Archer subclass + combo registration |
| `DraftRunController` | N1, E4, N2 | MEDIUM -- class filtering, combo checks, draft timing |
| `EnemyController` | E3, E2 | MEDIUM -- boss subclass + difficulty scaling |
| `Health.cs` | N1, E3, D1 | LOW -- i-frame suppression, phase check hook |

---

## 5. Data Flow Scenarios

### 5.1 Difficulty-Scaled Enemy Spawn (E2 + E1 + D5)

```
RoomConfig.asset ──> SpawnManager.StartWave()
                         │
                         ├── Read DifficultyConfig (Normal or Hard)
                         ├── Multiply spawnCount by enemyCountMultiplier
                         ├── Multiply delay by pacingMultiplier
                         │
                         └──> EnemyController.InitAttributes()
                                  │
                                  ├── Read base stats from EnemyData
                                  ├── ApplyRandomVariation(statMultiplierMin, statMultiplierMax)
                                  └── Enemy ready with scaled stats
```

### 5.2 Boss Phase Transition (E3 + D1 + D3)

```
Player deals damage ──> Health.TakeDamage()
                            │
                            ├── Health.OnDamaged event fires
                            └──> BossController.OnDamageReceived()
                                     │
                                     ├── Check currentHP% vs BossPhase thresholds
                                     ├── If threshold crossed:
                                     │   ├── Enter stagger (0.5s invulnerable)
                                     │   ├── StateMachine.ResetState() (clear debuffs)
                                     │   ├── Swap BehaviourTree to new phase
                                     │   ├── Apply stat modifiers
                                     │   └── Play transition VFX
                                     └── Resume with new AI pattern
```

### 5.3 Skill Draft + Combo Detection (D7 + N1 + E4)

```
Room cleared ──> DraftRunController.ShowDraft()
                     │
                     ├── Filter skill pool by PlayerClassType
                     │   (Archer: exclude Fireball upgrades; Mage: exclude Arrow upgrades)
                     ├── CanApplyUpgrade() check per candidate
                     ├── Present 3 options to player
                     │
Player picks ──> PlayerController.CollectSkill(chosenSkill)
                     │
                     └──> ComboRegistry.CheckCombos(collectedSkills)
                              │
                              ├── For each ComboDefinition in ComboDatabase:
                              │   ├── If both skillA and skillB in collected:
                              │   │   ├── ComboEffect.Activate(playerController)
                              │   │   ├── Flash combo name (gold, Cinzel, 2s)
                              │   │   └── Set discoveredFlag in save data
                              │   └── Else: skip
                              └── Return
```

### 5.4 Endless Mode Wave Loop (N2 + E3 + E2)

```
Endless start ──> SpawnManager.SetMode(Endless)
                      │
                      ├── Load EndlessDifficultyConfig (NOT campaign DifficultyConfig)
                      │
Wave N ──> SpawnManager.SpawnEndlessWave(waveNumber)
               │
               ├── Calculate: enemyCount = 4 + Floor(wave * 0.5)
               ├── Calculate: statMultiplier = 1.0 + (wave * 0.04)
               ├── If wave % 10 == 0: spawn BossController (2-phase, cycling A-E)
               ├── If wave % 5 == 0: trigger DraftRunController.ShowDraft()
               │
               └── On all enemies dead: waveNumber++, 3s breathing window
```

### 5.5 Archer Dodge Roll + Counter Roll + Quickdraw (N1 + D1)

```
Player presses dodge ──> DodgeRollSkill.Activate()
                             │
                             ├── Set isDodging = true, start 0.2s i-frame timer
                             ├── Move 2.0 units in movement direction
                             ├── During i-frames: Health.TakeDamage() returns early
                             │
                             ├── If attack blocked during i-frames (Counter Roll held):
                             │   └── Apply 2x damage buff for 3s
                             │
                             └── On roll end (Quickdraw held):
                                 └── Apply 0.5x cooldown multiplier for 2s
                                     (both buffs stack: 2x damage + 2x fire rate)
```

---

## 6. API Boundaries

New interfaces required for v1.0 systems. These define the contracts between
modules; implementations live in the owning module.

### 6.1 IDifficultyProvider

```csharp
/// Centralizes difficulty multiplier access. Replaces direct enum checks.
/// Campaign mode returns DifficultyConfig; Endless returns EndlessDifficultyConfig.
public interface IDifficultyProvider
{
    float StatMultiplierMin { get; }
    float StatMultiplierMax { get; }
    float EnemyCountMultiplier { get; }
    float HealDropMultiplier { get; }
    float PacingMultiplier { get; }
    float RewardMultiplier { get; }
    bool IsBossExemptFromCount { get; }  // always true
}
```

### 6.2 IBossPhaseController

```csharp
/// Implemented by BossController. Read by SpawnManager and DraftRunController.
public interface IBossPhaseController
{
    int CurrentPhaseIndex { get; }
    int TotalPhases { get; }
    bool IsInStagger { get; }
    event System.Action<int> OnPhaseTransition;  // emits new phase index
    event System.Action OnBossDefeated;
}
```

### 6.3 IComboRegistry

```csharp
/// Implemented by ComboRegistry. Called by DraftRunController after each draft.
public interface IComboRegistry
{
    void CheckCombos(IReadOnlyList<BaseSkill> collectedSkills);
    IReadOnlyList<ComboDefinition> ActiveCombos { get; }
    event System.Action<ComboDefinition> OnComboDiscovered;
}
```

### 6.4 ICharacterClass (Refactor Target)

```csharp
/// Replaces direct casts to MagePlayerController. Both Mage and Archer implement.
public interface ICharacterClass
{
    PlayerClassType ClassType { get; }
    BaseSkill DefaultActiveHitSkill { get; }
    BaseSkill DefaultActiveRunSkill { get; }
    void InitAttributes(GamePlayDatabase db);
}
```

### Refactor Note: DashSkill Cast

The existing `DashSkill` casts to `MagePlayerController`. This must be refactored
to use `PlayerController` or `ICharacterClass` before Archer integration.
**Impact assessment required** -- mobile code may depend on the cast. Evaluate
`Assets/Trizzle/Scripts/Character/Skills/DashSkill.cs` and all references.

---

## 7. ADR Audit

### Existing ADRs

None. The `docs/architecture/` directory contains only `tr-registry.yaml`. All
46 singleton managers and existing systems were built without formal ADRs.

### Required ADRs (Grouped by Layer)

#### Infrastructure Layer

| ADR | Why | Priority |
|-----|-----|----------|
| **ADR-001: DifficultyConfig as Interface** | SpawnManager, EnemyController, drop behaviors, and Endless mode all need difficulty multipliers. Centralize via `IDifficultyProvider` to avoid 4+ direct references to difficulty enums. | P0 |
| **ADR-002: SpawnManager Mode Routing** | SpawnManager is touched by E1, E2, E3, and N2. Define how it selects between campaign RoomConfig and Endless wave generation without becoming a god class. | P0 |

#### Gameplay Layer

| ADR | Why | Priority |
|-----|-----|----------|
| **ADR-003: BossController Subclass vs Composition** | E3 proposes `BossController : EnemyController`. Evaluate whether subclassing or a composable `BossPhase` component on existing EnemyController is more maintainable given 30 existing enemy controllers. | P1 |
| **ADR-004: PlayerClassType Refactor** | N1 introduces Archer. Existing code casts to `MagePlayerController` in shared skills. Define the refactoring strategy: interface extraction, base class methods, or adapter pattern. | P1 |
| **ADR-005: ComboEffect Execution Model** | E4 defines 18 combo effects with 4 trigger conditions. Define whether effects register as event listeners, poll per-frame, or use a hybrid. Performance budget: < 0.5ms total per frame for all active combos. | P1 |

#### Content Layer

| ADR | Why | Priority |
|-----|-----|----------|
| **ADR-006: RoomConfig Data Schema** | E1 defines 10 rooms as ScriptableObjects. Define the schema: wave lists, trap placement format, boss assignment, archetype tagging. This is the contract Room Content authors write against. | P1 |
| **ADR-007: Endless Wave Generation** | N2 needs a wave generator separate from campaign's static RoomConfigs. Define whether Endless uses a procedural generator, a parameterized template, or a sequence of pre-authored wave configs with scaling. | P1 |

---

## 8. Architecture Principles

### P1: Extend, Don't Replace

The codebase has 46 singleton managers and 2,569 files that ship a working demo
on Steam. New systems (Archer, Bosses, Combos, Endless) must integrate with
existing patterns -- MonoBehaviour, ScriptableObject, singleton managers, object
pooling, coroutines. Do not introduce new architectural paradigms (DOTS, Zenject,
reactive streams) for v1.0. The cost of migration exceeds the benefit for a solo
developer shipping in 12-18 months.

### P2: ScriptableObject as Single Source of Truth

All tuning values, combo definitions, room configs, difficulty multipliers, and
boss phase data live in ScriptableObjects editable in the Unity Inspector. No
hardcoded gameplay values in code. This enables balance iteration without
recompilation and keeps designers (even if that designer is also the programmer)
working in the Inspector, not in C# files.

### P3: Event-Driven Cross-System Communication

Systems communicate via events, not direct method calls across module boundaries.
`Health.OnDamaged` triggers boss phase checks. `DraftRunController.OnSkillDrafted`
triggers combo detection. `BossController.OnBossDefeated` triggers draft-run
completion. This keeps modules decoupled and testable in isolation.

### P4: Platform Split at the Presentation Layer Only

PC and Mobile share all Gameplay, Content, Meta, and Infrastructure code.
Platform divergence exists only in `Scenes/PC/`, `Scenes/Mobile/`, `UI/PC/`,
and `Manager/PC/`. New systems (E2, N1, E3, E4, E1, N2) must not introduce
platform-specific gameplay logic. If Endless Mode needs a mobile performance cap
on enemy count, that cap lives in a platform config, not in the wave generator.

### P5: Data-Driven Difficulty

No system should branch on `if (difficulty == Hard)`. All difficulty-dependent
behavior reads from `IDifficultyProvider` multipliers. This ensures Endless mode,
future difficulty tiers (Nightmare), and per-room modifiers work without code
changes -- only new `DifficultyConfig` asset instances.

---

## 9. Cross-GDD Integration Issues

Sourced from `gdd-cross-review-2026-04-07.md`. These are architecture-relevant
warnings that require technical resolution.

| ID | Issue | Impact | Recommended Resolution |
|----|-------|--------|----------------------|
| W1 | N1/E4 dependency direction inverted in docs | Confusion during implementation | Fix in next GDD pass; E4 depends on N1 skills, not the reverse |
| W6 | E3 references `DragonEnemyController` | Migration debt -- two boss patterns | ADR-003 must decide: migrate Dragon to BossController or keep separate |
| W7 | E4 Mage combo skills not validated against E5 | Combos may reference incomplete skills | Audit E5 completion list against all 5 Mage combo skill references before E4 implementation |
| W8 | N1 Archer DPS formula ignores Defense scaling | Balance math incomplete at high difficulty | Add Defense-adjusted DPS to N1 formulas during implementation |
| W11/W14 | Archer attention budget hits 6 on Hard | Cognitive overload risk | Playtest gate at milestone; may need to reduce simultaneous active buffs visually |
| W12 | Hard 2x rewards with no gem sink | Economy inflation risk | Define gem sink before E2 implementation or cap Hard reward multiplier |
| B4 (resolved) | Elemental Storm was uncapped | Degenerate combo in E4 | Fixed: 5-hit limit per trigger. Verify in ComboEffect implementation. |

---

## 10. Open Questions

### Architecture-Level (Require ADR or TD Decision)

| # | Question | Blocking | Recommendation |
|---|----------|----------|----------------|
| A1 | Should `SpawnManager` be split into `CampaignSpawnManager` + `EndlessSpawnManager`, or remain unified with mode routing? | ADR-002 | Unified with strategy pattern. Splitting duplicates wave-completion logic. |
| A2 | Should `BossController` be a subclass of `EnemyController` or a composable component? | ADR-003 | Subclass. The GDD's `BuildTreeForThisEnemy()` override pattern requires inheritance. Composition would need a wrapper that proxies 20+ EnemyController methods. |
| A3 | How does `ComboEffect` register its triggers without introducing per-frame polling for 18 effects? | ADR-005 | Event subscription model. Each ComboEffect subscribes to the specific event its triggerCondition requires (OnDamaged, OnDied, OnSkillUsed). Passive effects use AttributeModifier, not polling. |
| A4 | Should Endless high scores use `LevelStats` with a synthetic level ID, or a separate persistence system? | N2 | Use `LevelStats` with ID `"Endless_Mage"` / `"Endless_Archer"`. Avoid new persistence paths. |

### Design-Level (Require Game Designer Decision, Not TD)

| # | Question | Source GDD |
|---|----------|-----------|
| D1 | Archer unlock: available from start or gated behind Room N clear? | N1 |
| D2 | Boss health bar UI: distinct named bar or standard enemy bar? | E3 |
| D3 | Endless Mode unlock: available from start or gated? | N2 |
| D4 | Room visual themes: unique per room or shared tileset with lighting? | E1 |
| D5 | Room progression: linear unlock or hub selection? | E1 |
| D6 | Boss loot: guaranteed drops or standard loot table? | E3 |
| D7 | Endless leaderboard: local only or Steam leaderboards? | N2 |

---

## Appendix A: Dependency Graph (Build Order)

```
Layer 0 (Foundation) -- No dependencies, build first
  ├── E2: Difficulty System (DifficultyConfig, IDifficultyProvider)
  └── E5: Incomplete Skills (code audit, prefab fixes)

Layer 1 (Core) -- Depends on Layer 0
  ├── N1: Archer Character (depends on E5)
  ├── E3: Boss Phase System (depends on E2)
  └── E4: Combo/Synergy Expansion (depends on E5)

Layer 2 (Content) -- Depends on Layer 1
  └── E1: Room Content (depends on N1, E3, E4, E2)

Layer 3 (Mode) -- Depends on Layer 2
  └── N2: Endless Mode (depends on E1, E2, E3)

Layer 4 (Meta) -- Depends on all gameplay, build last
  └── N3: Achievements (depends on N1, N2, E1) [P2, deferred]
```

**Critical path**: E5 -> N1 -> E1 -> N2.
**Bottleneck**: E5 (Incomplete Skills) blocks both Archer and Combos.

## Appendix B: Performance Risk Register

| Risk | System | Trigger Condition | Budget | Mitigation |
|------|--------|-------------------|--------|------------|
| Enemy count spike | N2 Endless | Wave 30+: 19+ enemies | < 16.6ms PC | Object pooling (existing); cap visible enemies on mobile |
| Combo effect overhead | E4 | 18 active combos, OnSkillUse triggers | < 0.5ms/frame | Event subscription, not polling; profile after 10+ combos active |
| Boss ability VFX | E3 | Rain of Fire: 3-5 AoE circles + particles | < 2ms render | Particle budget per ability; LOD on mobile |
| Multishot + Piercing | N1 | 9 simultaneous projectile hits | < 1ms physics | Projectile pooling; batch damage calculation |
| Status effect ticks | D3 + E4 | 16+ enemies with Poison + Burn + Slow | < 1ms/frame | Tick batching; don't tick per-enemy per-frame |
