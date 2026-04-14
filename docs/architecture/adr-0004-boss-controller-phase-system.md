# ADR-0004: BossController Phase System

## Status

Accepted

## Date

2026-04-07

## Accepted Date

2026-04-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6000.3.11f1 (Unity 6.3 LTS) |
| **Domain** | Gameplay |
| **Knowledge Risk** | HIGH — Unity 6 series post-dates LLM training cutoff (May 2025) |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md` |
| **Post-Cutoff APIs Used** | None — this decision uses MonoBehaviour subclassing, ScriptableObject, C# events, coroutines, and serialized structs. All are stable APIs present since Unity 2019 LTS with no known post-cutoff breaking changes. |
| **Verification Required** | Confirm that `[System.Serializable]` structs with `List<T>` serialize correctly in Inspector under Unity 6000.3.11f1 (ScriptableObject field behaviour is unchanged from 2022 LTS but should be verified in-editor before story sign-off). Confirm coroutine-based stagger timing is not affected by new frame scheduling behaviour introduced in Unity 6.0. |

> **Note**: Knowledge Risk is HIGH due to the Unity 6 version, but the specific
> patterns used (MonoBehaviour inheritance, event subscriptions, serialized structs,
> coroutines) have been stable across the entire Unity 5–6 lineage. The risk is in
> engine-level unknowns, not in any post-cutoff API dependency. Re-validate if the
> project upgrades engine versions.

---

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — BossController subclasses EnemyController (already shipped), subscribes to `Health.OnDamaged` (already shipped), and calls `StateMachine.ResetState()` (already shipped). No other ADR need be Accepted first. |
| **Enables** | ADR-006: RoomConfig Data Schema — rooms reference `BossController` prefabs; the prefab schema defined here is the contract `RoomConfig` authors write against. |
| **Blocks** | All E3 Boss Phase implementation stories; All E1 Room Content stories that reference a boss prefab; All N2 Endless Mode boss-wave stories. |
| **Ordering Note** | ADR-0004 may be drafted and Accepted independently of ADR-0001 and ADR-0002. However, stories that combine boss phases with difficulty scaling (E2) must wait for ADR-0001 to be Accepted. Stories that combine boss detection in SpawnManager with wave routing must wait for ADR-0002 to be Accepted. |

---

## Context

### Problem Statement

Bosses in Trizzle / Shadow Quest are currently regular enemies with no distinct
behavioral structure. The E3 GDD specifies 5 unique bosses, each with 2–3 phases,
HP-threshold transitions, per-phase BehaviourTree swaps, stagger states, stat
modifiers, and VFX cues. The existing `EnemyController` has no concept of phases,
thresholds, or stagger. A formal `BossController` is needed that layers phase
behavior on top of the existing enemy system without requiring rewrites of the
30 shipped enemy controllers.

The architecture doc (Section 4, Module Ownership Map) assigns this as the E3
module, touching `EnemyController` (subclass), `EnemyData` (add `isBoss` flag),
and `SpawnManager` (boss detection). Architecture Open Question A2 (Section 10)
concludes that subclassing is the correct pattern because the existing
`BuildTreeForThisEnemy()` override pattern (present in `DragonEnemyController`)
already establishes inheritance as the idiom for custom enemy AI. Composition
would require proxying 20+ EnemyController methods.

### Constraints

- **No new architectural paradigms** (Architecture Principle P1): Solution must use
  MonoBehaviour, ScriptableObject, coroutines, and C# events — the patterns already
  present in the 46 singleton managers and 30 enemy controllers.
- **Extend, don't replace** (Architecture Principle P1): The 30 existing enemy
  controllers must continue to work without modification. `BossController` is a new
  subclass, not a refactor of `EnemyController`.
- **Data-driven** (Architecture Principle P2): All phase thresholds, BehaviourTree
  references, stat modifiers, and VFX references must be configurable in the Inspector.
  No hardcoded phase values in C#.
- **Event-driven cross-system communication** (Architecture Principle P3): Phase
  checks hook into the existing `Health.OnDamaged` event, not into `Update()`.
  Boss state changes are broadcast as C# events on the `IBossPhaseController`
  interface for consumers (SpawnManager, DraftRunController) to subscribe to.
- **Platform parity** (Architecture Principle P4): No platform-specific gameplay
  logic inside `BossController`. If a mobile performance cap is needed (e.g., fewer
  simultaneous minions), it lives in a platform config, not in phase logic.
- **Boss is exempt from `enemyCountMultiplier`**: The E2 Difficulty GDD (edge
  case #3) and the E3 GDD both specify that bosses are never duplicated by the count
  multiplier. This check must use `EnemyData.isBoss`, not a string tag or name match.

### Requirements

- Must support 2-phase bosses (rooms 1–5) and 3-phase bosses (rooms 6–10)
- Must support multi-threshold skipping in a single damage event (one big hit that
  crosses two thresholds triggers both transitions in sequence)
- Must enter a 0.5s stagger state on each threshold crossing: invulnerable, clears
  all debuffs via `StateMachine.ResetState()`, swaps BehaviourTree, applies stat
  modifiers, then plays transition VFX
- Must expose `IBossPhaseController` interface (defined in architecture doc Section 6.2)
  so SpawnManager and DraftRunController can subscribe without depending on the
  concrete class
- Must replace tag/name-based boss detection with `EnemyData.isBoss` flag throughout
  the codebase (`SpawnManager`, `OneShotKillEffect`, `DraftRunController`)
- Must provide 4 new ability template MonoBehaviours: GroundSlam, Charge, ShieldPhase,
  RainOfFire — configurable per-phase via the Inspector
- Phases are one-way: healing a boss does not reverse a triggered phase
- Boss death during stagger must still process immediately — death takes priority

---

## Decision

`BossController` is a MonoBehaviour subclass of `EnemyController`. It adds a
`List<BossPhase>` field serialized in the Inspector, subscribes to `Health.OnDamaged`
on `Awake`, and checks thresholds on each damage event rather than in `Update`. Phases
are checked lowest-threshold-first so that a single massive hit that skips multiple
thresholds triggers all skipped phases in ascending threshold order.

On each threshold crossing, `BossController` starts a coroutine that: sets
invulnerability, fires the stagger animation, calls `StateMachine.ResetState()` to
clear all active debuffs, swaps the active BehaviourTree to the phase's tree reference
(matching the existing `DragonEnemyController` override pattern), applies the phase's
`statModifiers` array via `AttributeModifier`, instantiates the phase's `transitionVFX`
prefab, waits 0.5 seconds, then lifts invulnerability and resumes AI.

The `BossPhase` data type is a `[System.Serializable]` struct (not a ScriptableObject)
so it can be directly authored in the `BossController` prefab Inspector panel without
requiring separate asset files per phase. The 5 boss prefabs each carry their own
phase configuration.

`EnemyData` gains a `bool isBoss` flag. All existing tag/name-based boss detection
in `SpawnManager`, `OneShotKillEffect`, and `DraftRunController.OnRunComplete()` is
updated to use this flag instead.

### Architecture Diagram

```
Health.OnDamaged (event)
        │
        ▼
BossController.OnDamageReceived(float damage)
        │
        ├── currentHPPercent = CurrentHealth / MaxHealth
        │
        ├── Sort _phases by healthThreshold ascending (done once at Awake)
        │
        └── foreach BossPhase p in _phases (ascending threshold order):
                │
                ├── if p.hasTriggered → skip
                ├── if currentHPPercent > p.healthThreshold → skip
                └── StartCoroutine(TransitionToPhase(p))
                        │
                        ├── isInvulnerable = true
                        ├── stateMachine.ResetState()     ← clears debuffs
                        ├── SwapBehaviourTree(p.behaviourTree)
                        ├── ApplyStatModifiers(p.statModifiers)
                        ├── Instantiate(p.transitionVFX)
                        ├── p.hasTriggered = true
                        ├── OnPhaseTransition?.Invoke(currentPhaseIndex)
                        ├── yield return WaitForSeconds(0.5f)
                        └── isInvulnerable = false


EnemyData
        └── bool isBoss          ← replaces all tag/name checks

BossController : EnemyController
        ├── [SerializeField] List<BossPhase> _phases
        ├── Implements IBossPhaseController
        └── Overrides BuildTreeForThisEnemy() → returns _phases[currentPhaseIndex].behaviourTree


IBossPhaseController (interface — architecture doc Section 6.2)
        ├── int CurrentPhaseIndex { get; }
        ├── int TotalPhases { get; }
        ├── bool IsInStagger { get; }
        ├── event Action<int> OnPhaseTransition
        └── event Action OnBossDefeated


Ability Templates (MonoBehaviour components on boss prefabs)
        ├── GroundSlamAbility    ← radial damage zone, 0.8s telegraph
        ├── ChargeAbility        ← momentum dash, 0.5s telegraph + line indicator
        ├── ShieldPhaseAbility   ← temporary invulnerability + hit counter
        └── RainOfFireAbility    ← spawns AoE hazard zones (reuses trap damage pattern)
```

### Key Interfaces

The `IBossPhaseController` interface (defined in `architecture.md` Section 6.2) is the
only public contract external systems depend on:

```csharp
/// <summary>
/// Implemented by BossController. Read by SpawnManager (boss detection) and
/// DraftRunController (boss-killed tracking). Subscribe to events rather than
/// polling properties where possible.
/// </summary>
public interface IBossPhaseController
{
    /// <summary>Zero-based index of the currently active phase.</summary>
    int CurrentPhaseIndex { get; }

    /// <summary>Total number of configured phases for this boss.</summary>
    int TotalPhases { get; }

    /// <summary>True during the 0.5s stagger window; boss is invulnerable.</summary>
    bool IsInStagger { get; }

    /// <summary>Fires with the new phase index each time a threshold is crossed.</summary>
    event System.Action<int> OnPhaseTransition;

    /// <summary>Fires when boss HP reaches 0. SpawnManager and DraftRunController subscribe.</summary>
    event System.Action OnBossDefeated;
}
```

The `BossPhase` struct (serialized in Inspector, not a ScriptableObject):

```csharp
[System.Serializable]
public struct BossPhase
{
    /// <summary>HP percentage (0.0–1.0) at which this phase triggers.</summary>
    [Range(0f, 1f)]
    public float HealthThreshold;

    /// <summary>Root BehaviourTree node to activate when this phase begins.</summary>
    public BTNode BehaviourTree;

    /// <summary>VFX prefab instantiated at the boss's position during stagger.</summary>
    public GameObject TransitionVFX;

    /// <summary>
    /// Stat multipliers applied additively on top of base stats when this phase begins.
    /// Uses the existing AttributeModifier system. Empty array = no stat change.
    /// </summary>
    public AttributeModifier[] StatModifiers;

    /// <summary>Set true when this phase has triggered. Phases never reverse.</summary>
    [HideInInspector]
    public bool HasTriggered;
}
```

`EnemyData` addition:

```csharp
// In EnemyData ScriptableObject — replaces all tag/name-based boss checks
[Tooltip("Set true for boss enemies. Exempts from OneShotKill, count multiplier, and enables IBossPhaseController detection.")]
public bool IsBoss;
```

---

## Alternatives Considered

### Alternative 1: Composition — BossPhaseComponent on EnemyController

- **Description**: Add a `BossPhaseComponent : MonoBehaviour` that can be attached
  to any existing `EnemyController`-based prefab. The component listens to `Health.OnDamaged`
  and calls methods back on the host `EnemyController` to drive transitions.
- **Pros**: No inheritance hierarchy; any existing enemy could theoretically become
  a boss. Follows Unity's component-composition idiom more closely.
- **Cons**: Requires a public mutation API on `EnemyController` to allow the component
  to swap BehaviourTrees and apply stat modifiers. This exposes 20+ internal methods
  as public, widening the API surface unnecessarily. The existing `DragonEnemyController`
  already establishes `BuildTreeForThisEnemy()` override as the idiom for custom AI.
  Switching to composition would create two boss patterns in the codebase
  (Dragon = inheritance, others = component), increasing maintenance burden.
  Architecture Open Question A2 explicitly rejected this approach for this reason.
- **Rejection Reason**: Two boss patterns; requires publicizing EnemyController
  internals; contradicts established DragonEnemyController convention.

### Alternative 2: BossController as separate MonoBehaviour (no EnemyController inheritance)

- **Description**: Write `BossController` as a standalone MonoBehaviour that does
  not extend `EnemyController`. Duplicate (or re-reference) health, stats, AI, and
  combat handling.
- **Pros**: Clean slate — no risk of breaking changes to EnemyController base.
- **Cons**: Massive code duplication. EnemyController ships 30 subclasses and
  encapsulates damage reception, status effects, attribute systems, and AI dispatch.
  A standalone boss would need to reimplement or re-reference all of this, creating
  a parallel maintenance track. Violates Architecture Principle P1 (Extend, Don't
  Replace).
- **Rejection Reason**: Violates P1; introduces a second maintenance track for enemy
  combat logic; doubles the blast radius of any future EnemyController bugfix.

### Alternative 3: Per-phase ScriptableObject assets instead of serialized struct

- **Description**: Define `BossPhaseData : ScriptableObject` instead of a
  `[System.Serializable]` struct. Each phase would be a separate `.asset` file
  referenced by the boss prefab.
- **Pros**: Phase configs become reusable assets (two bosses could share a phase
  config). Editor tooling for ScriptableObjects is slightly richer.
- **Cons**: Creates 10–15 additional `.asset` files for 5 bosses' phases. Adds
  indirection — designer must open 3 separate assets to understand one boss. Since
  no two bosses share a phase configuration, reusability provides no practical benefit
  for v1.0. Per-prefab serialized structs are simpler to author and review.
- **Rejection Reason**: No reuse benefit for v1.0; adds asset management overhead;
  struct in Inspector is sufficient and simpler.

---

## Consequences

### Positive

- Boss phase behavior is fully data-driven: all thresholds, trees, VFX, and stat
  modifiers are configurable in the Inspector without touching C#.
- Existing 30 enemy controllers are untouched; subclassing isolates all boss-specific
  code in `BossController`.
- `IBossPhaseController` decouples SpawnManager and DraftRunController from the
  concrete implementation, making both testable in isolation with a mock.
- Replacing tag/name-based boss detection with `EnemyData.isBoss` eliminates a class
  of string-comparison bugs and makes the flag searchable by reference across the IDE.
- The established `DragonEnemyController` inheritance pattern is extended rather than
  contradicted — one boss pattern in the codebase.
- Multi-threshold skipping is handled correctly by design (sorted ascending, iterate
  all untriggered phases per damage event), removing a class of edge-case bugs.

### Negative

- `EnemyController` gains an implicit coupling to `BossController` through the
  `BuildTreeForThisEnemy()` virtual override. Any future change to that method's
  signature requires updating `BossController`.
- The 0.5s stagger coroutine and phase-transition logic live in `BossController`.
  If a future non-boss enemy needs stagger behavior, this logic is not easily shared
  without further refactoring.
- `EnemyData.isBoss` is a new flag on a shared ScriptableObject type. Existing
  `EnemyData` assets must be opened and saved in-editor to expose the new field
  (they default to `false`, which is correct, but a bulk-save pass may be needed).

### Risks

- **DragonEnemyController migration debt (W6)**: The architecture doc flags that
  `DragonEnemyController` uses an ad-hoc boss pattern. This ADR establishes the
  canonical pattern but does not mandate migration. If Dragon is not migrated,
  two boss patterns coexist. Mitigation: create a follow-up tech-debt entry; migrate
  Dragon in the same sprint as E3 if scope allows.
- **Stagger coroutine + boss death race condition**: If the boss's HP reaches 0
  during a stagger coroutine, both the death path and the stagger path are active
  simultaneously. Mitigation: guard all stagger coroutine steps with an `if (!isDead)`
  check; the death path calls `StopAllCoroutines()` as part of existing
  `EnemyController.Die()` behavior.
- **Serialized struct data loss on prefab revert**: `BossPhase.HasTriggered` is a
  runtime-mutated field on a serialized struct. If a prefab is reverted at runtime
  in a development build, triggered state could reset. Mitigation: this is a dev-time
  issue only; document in the implementation story.
- **Unity 6000.3.11f1 serialization behavior**: Nested serializable structs inside
  a `List<T>` have been stable since Unity 2019, but should be verified in-editor
  given the post-cutoff engine version.

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `boss-phase-system.md` (E3) | `BossController : EnemyController` subclass with `List<BossPhase>` configured in Inspector | Establishes exactly this class hierarchy and data structure as the accepted pattern |
| `boss-phase-system.md` (E3) | Phase check hooks into `Health.OnDamaged` (not Update — event-driven) | Subscription to `Health.OnDamaged` in `Awake` is the mandated implementation site |
| `boss-phase-system.md` (E3) | Phases checked lowest-threshold-first for multi-threshold skip handling | Mandates ascending sort of `_phases` list at `Awake`; iterate all untriggered phases per damage event |
| `boss-phase-system.md` (E3) | 0.5s stagger state: invulnerable, clears debuffs via `StateMachine.ResetState()` | Stagger coroutine with `WaitForSeconds(0.5f)` and `ResetState()` call is the mandated sequence |
| `boss-phase-system.md` (E3) | BehaviourTree swap matching existing DragonEnemyController pattern | `BuildTreeForThisEnemy()` override returning `_phases[currentPhaseIndex].behaviourTree` is the mandated API |
| `boss-phase-system.md` (E3) | `EnemyData.isBoss` flag replaces tag-based boss detection | `bool IsBoss` field on `EnemyData` is mandated; tag/name checks are a forbidden pattern post-ADR |
| `boss-phase-system.md` (E3) | 4 new ability templates: GroundSlam, Charge, ShieldPhase, RainOfFire | Each template is a MonoBehaviour component; this ADR establishes their existence and attachment model |
| `room-content.md` (E1) | Each room references a `BossController` prefab with configured phases | The `BossPhase` struct schema is the data contract `RoomConfig` boss-assignment fields write against |
| `room-content.md` (E1) | Rooms 1–5: 2-phase bosses; Rooms 6–10: 3-phase bosses | `List<BossPhase>` length is per-prefab, supporting any count ≥ 2 |
| `endless-mode.md` (N2) | Boss waves use `BossController` prefabs with 2-phase configs only | `IBossPhaseController` is the interface Endless SpawnManager reads; phase count is prefab-configured, not code-gated |
| `endless-mode.md` (N2) | Boss stat scaling follows endless curve, not campaign `DifficultyConfig` | `BossController` applies stat modifiers through `AttributeModifier` (per-phase) + the `IDifficultyProvider` supplied by the current wave provider at spawn time |

---

## Performance Implications

- **CPU**: Phase check runs once per damage event (not per frame). `foreach` over 2–3
  phases is O(n) where n ≤ 3 — negligible. Stagger coroutine is a one-shot yield;
  no per-frame overhead during normal combat. Well within the 16.6ms frame budget.
- **Memory**: `List<BossPhase>` per boss prefab: 2–3 struct instances (~64 bytes each
  at current field count). 5 boss prefabs in memory = ~960 bytes total phase data.
  No measurable impact.
- **Load Time**: 5 boss prefabs with serialized phase data. No additional `.asset`
  files beyond the prefabs themselves. Negligible load impact.
- **Rendering**: `transitionVFX` instantiation during phase transitions is a one-shot
  instantiate per transition. Budget this in the VFX particle budget per the
  architecture doc Appendix B: Rain of Fire + transition VFX combined < 2ms render.
- **Network**: Not applicable — single-player only.

---

## Migration Plan

1. **Add `IsBoss` to `EnemyData`**: Add `public bool IsBoss;` with tooltip. All
   existing `EnemyData` assets default to `false` — no bulk migration needed. Open
   boss enemy data assets and set `IsBoss = true`.

2. **Create `BossController.cs` and `BossPhase.cs`**: New files in
   `Assets/Trizzle/Scripts/Combat/` (or alongside existing enemy controllers).
   Implement `IBossPhaseController` interface from architecture doc Section 6.2.

3. **Create 4 ability template MonoBehaviours**: `GroundSlamAbility.cs`,
   `ChargeAbility.cs`, `ShieldPhaseAbility.cs`, `RainOfFireAbility.cs` in
   `Assets/Trizzle/Scripts/Combat/BossAbilities/`.

4. **Replace tag/name checks**: Update `SpawnManager` (boss detection),
   `OneShotKillEffect` (boss exemption), and `DraftRunController.OnRunComplete()`
   (boss-killed flag) to read `EnemyData.IsBoss` instead of tag or name strings.

5. **DragonEnemyController (optional, same sprint)**: If in scope, migrate Dragon to
   use `BossController` as its base class and configure its existing behavior as a
   `BossPhase` list. Otherwise, log in tech-debt register.

6. **Create 5 boss prefabs**: Author one `BossController` prefab per boss (A–E),
   configure phases, assign ability template components per the E3 GDD phase table.

---

## Validation Criteria

This decision is validated when all E3 Acceptance Criteria pass in a playtest:

1. `BossController` exists and extends `EnemyController`; boss prefabs use it with
   a `List<BossPhase>` visible and editable in the Inspector.
2. Damage to 50% HP triggers Phase 2 stagger, tree swap, and stat modifier.
3. One hit crossing two thresholds triggers both transitions in sequence (1.0s total
   stagger).
4. During stagger, boss takes 0 damage.
5. Stagger clears the Frozen status effect via `StateMachine.ResetState()`.
6. Summoned minions persist after boss death; room does not clear until all dead.
7. Shield Phase blocks damage but not status effects; shield hit counter functions.
8. Room 1 Hard spawns 1 boss (not 2); boss stats scale via difficulty.
9. `DraftRunController.OnRunComplete()` receives correct `bossKilled` value via
   `IBossPhaseController.OnBossDefeated` event (not hardcoded `true`).
10. `EnemyData.IsBoss = true` blocks `OneShotKillEffect`; no string tag checks remain.
11. All 5 bosses load, transition phases, and die correctly across rooms 1–10.

---

## Related Decisions

- `docs/architecture/adr-0001-difficulty-config-interface.md` — Boss stat scaling
  consumes `IDifficultyProvider`; boss is exempt from `IsBossExemptFromCount = true`
  flag on that interface.
- `docs/architecture/adr-0002-spawnmanager-mode-routing.md` — Boss wave detection
  in SpawnManager (checking `EnemyData.IsBoss` to route to boss-wave path) is
  implemented within the `IWaveProvider` strategy established by that ADR.
- `design/gdd/boss-phase-system.md` — Primary GDD this ADR implements.
- `design/gdd/room-content.md` — Boss-per-room assignments; `BossPhase` struct is
  the schema rooms reference.
- `design/gdd/endless-mode.md` — Boss wave cycling every 10 waves; always 2-phase
  in Endless; stat scaling via `EndlessDifficultyConfig`, not campaign difficulty.
- `docs/architecture/architecture.md` Section 6.2 — `IBossPhaseController` interface
  definition that this ADR mandates as the external contract.
