# ADR-0003: ComboEffect ScriptableObject Architecture

## Status

Accepted

## Date

2026-04-07 (Proposed) / 2026-04-15 (Accepted) / 2026-04-16 (Amended — see end of file)

## Last Verified

2026-04-16

## Decision Makers

Technical Director (Claude) + xiaolei

## Summary

The Combo/Synergy Expansion (E4) requires 18 triggered combo effects with four distinct
trigger conditions (OnDraft, OnSkillUse, OnKill, Passive). This ADR defines `ComboEffect`
as an abstract ScriptableObject base class with `Activate(PlayerController)`,
`Deactivate()`, and `OnTrigger(TriggerContext)` methods. Each of the 18 combos is a
concrete `ComboEffect` subclass authored as a Unity ScriptableObject asset. Trigger
conditions are implemented via event subscription: `OnSkillUse` subscribes to skill
activation events, `OnKill` subscribes to `Health.OnDied`, and `Passive` applies stat
modifications immediately on `Activate`. `ComboRegistry.CheckCombos()` returns discovered
combos and activates their `ComboEffect` objects. All effects delegate to existing systems
— `DamageCalculator`, `AttributeModifier`, `SpawnManager` — and no new runtime systems
are required.

---

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6000.3.11f1 (Unity 6.3 LTS) |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | HIGH — Unity 6 series post-dates LLM training cutoff (May 2025) |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md` |
| **Post-Cutoff APIs Used** | None — this decision uses ScriptableObject, MonoBehaviour, C# abstract classes, and C# events. All are stable APIs present in Unity 2020 LTS and unchanged through Unity 6.3 LTS |
| **Verification Required** | Confirm `ScriptableObject` subclass instances assigned as `[SerializeField]` references in `ComboDefinition` survive play-mode enter/exit and scene transitions in Unity 6000.3.11f1; confirm that event subscription / unsubscription in `Activate` / `Deactivate` does not leak listeners across play sessions in the Editor |

> **Note**: Knowledge Risk is HIGH due to the Unity 6 engine version, but the specific
> APIs used (abstract ScriptableObject, C# events, SerializeField) have been stable
> since Unity 2019 LTS. Re-validate this ADR if the project upgrades engine versions.

---

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — `ComboEffect` is self-contained. It reads from existing D1/D3/D4 event APIs already shipped in the demo. No prior ADR must be Accepted before this can be implemented. |
| **Enables** | None — no subsequent ADR depends on the ComboEffect model being decided first. |
| **Blocks** | All E4 Combo/Synergy Expansion implementation stories (combo effect authoring, `ComboRegistry` wiring, combo discovery UI, save data extension, `ComboDatabase.asset` population). No E4 story can be written to Ready status until this ADR is Accepted. |
| **Ordering Note** | This ADR may be Accepted independently of ADR-0001 and ADR-0002. E4 is Layer 1 in the build order and has no dependency on the difficulty or spawn systems. Its only upstream dependency is E5 (Incomplete Skills), which is a code-audit prerequisite, not an ADR. |

---

## Context

### Problem Statement

E4 requires 18 combo effects, each with distinct trigger conditions and unique runtime
behaviors. The existing `ComboDatabase` holds 5 hardcoded Mage-only pairs with no runtime
effect — `ComboDefinition` currently stores combo metadata only (names, skill references)
but has no execution model. Three design forces must be reconciled:

1. **Trigger diversity**: Effects activate at four distinct moments — on draft, on any skill
   use, on enemy kill, and continuously while both skills are held. A single polling Update
   loop cannot serve all four without burning budget on 18 per-frame checks.

2. **Data-driven tuning**: Architecture Principle P2 (ScriptableObject as Single Source of
   Truth) requires all combo parameters (damage ratios, radii, durations, proc chances) to
   be Inspector-editable without recompilation. This points to ScriptableObject-based
   effect assets rather than MonoBehaviour components or plain C# classes.

3. **No new systems**: Architecture Principle P1 (Extend, Don't Replace) prohibits
   introducing new architectural paradigms for v1.0. All 18 effects must delegate to
   systems that already exist: `DamageCalculator` for bonus damage, `AttributeModifier`
   for stat changes, `SpawnManager` for spawning ground-patch objects, and
   `StateMachine.HasState()` for status-conditional logic.

The decision must be made now because E4 is Layer 1 in the build order and its
implementation stories cannot be authored until the execution model is settled.

### Current State

`ComboDefinition` (in `ComboDatabase.asset`) currently stores:
- `skillA`, `skillB` (BaseSkill references)
- `comboName` (string)
- No trigger condition, no runtime effect reference

`ComboRegistry.CheckCombos()` currently returns whether a pair is active but does not
activate any effect. The E4 GDD specifies extending `ComboDefinition` with
`triggerCondition` and `triggerEffect` fields.

### Constraints

- **No new architectural paradigms**: Architecture Principle P1 prohibits Zenject,
  reactive streams, or observable patterns for v1.0.
- **Performance budget**: Architecture doc Appendix B sets < 0.5 ms/frame total for all
  active combos. With up to 18 effects simultaneously active, per-frame polling per effect
  is prohibited. Effects must be event-driven or fully passive (zero per-frame cost).
- **Data-driven**: All per-combo tuning values must live in ScriptableObject assets editable
  in the Unity Inspector (Architecture Principle P2). Effect behaviors cannot be
  parameterized by hardcoded constants in code.
- **Testable in isolation**: Architecture Principle P3 (event-driven cross-system
  communication) and Coding Standards require each `ComboEffect` to be unit-testable
  without running a full game session. Effects must accept a `PlayerController` reference
  via `Activate()` rather than discovering it via `FindObjectOfType` or statics.
- **Solo developer timeline**: 18 concrete effect classes must be authorable quickly.
  The base class must provide a clear, minimal template that a single developer can
  follow without per-effect architecture decisions.

### Requirements

- All 18 combo effects must be authored as concrete `ComboEffect` ScriptableObject assets.
- `ComboEffect.Activate(PlayerController player)` must register any needed event listeners
  and apply any immediate stat modifications.
- `ComboEffect.Deactivate()` must unsubscribe all listeners and remove all stat
  modifications applied by this effect.
- `ComboEffect.OnTrigger(TriggerContext ctx)` must contain the effect's runtime behavior
  and may be a no-op for Passive effects.
- `ComboRegistry.CheckCombos()` must call `effect.Activate(player)` on discovery and
  `effect.Deactivate()` on run end.
- No effect may introduce per-frame Update polling — all runtime callbacks must be
  event-subscribed or purely passive attribute changes.
- All per-combo tuning values must be `[SerializeField]` fields on the concrete
  `ComboEffect` subclass, visible and editable in the Unity Inspector.
- Executioner's instant-kill must check `isBoss` on the target before executing —
  boss immunity is a hard requirement from GDD Edge Case 3.
- Elemental Storm's bonus must reset after 5 hits — the uncapped version was flagged as
  degenerate in architecture doc Section 9 (resolved bug B4).

---

## Decision

Introduce `ComboEffect` as an abstract `ScriptableObject` subclass. Each of the 18 combos
is a concrete C# class extending `ComboEffect`, with a corresponding `.asset` file
authored in the Unity Editor.

`ComboEffect` has three entry points:

- **`Activate(PlayerController player)`** — called by `ComboRegistry` when the combo pair
  is first detected. The concrete subclass stores the `player` reference, subscribes to
  the appropriate event(s) for its trigger condition, and applies any immediate
  `AttributeModifier` changes (Passive effects only).
- **`Deactivate()`** — called by `ComboRegistry` on run end. Unsubscribes all listeners,
  removes any `AttributeModifier` additions, and clears all runtime state so the asset can
  be reused next run without leaking state.
- **`OnTrigger(TriggerContext ctx)`** — called by the subscribed event handler(s). Contains
  the core runtime behavior. Passive effects leave this as a no-op; it is still present on
  the base class for uniformity.

`TriggerContext` is a plain C# struct (stack-allocated, zero heap cost) carrying the
caller's contextual data: the triggering skill, the target `Health` component, and the
damage amount. Concrete subclasses cast or ignore fields as appropriate.

### Trigger Condition Implementation by Condition Type

| Trigger | Subscription Site | Event |
|---------|------------------|-------|
| **OnDraft** | `Activate()` — fires `OnTrigger` immediately during activation | None (self-fires once) |
| **OnSkillUse** | `Activate()` → `player.OnSkillUsed += OnTrigger` | `PlayerController.OnSkillUsed` |
| **OnKill** | `Activate()` → `Health.OnDied += OnTrigger` (global listener via `HealthEventBus` or per-enemy subscription in `OnTrigger`) | `Health.OnDied` |
| **Passive** | `Activate()` → `player.AttributeModifier.Add(modifier)` — no event subscription | None (stat change is permanent until `Deactivate`) |

For `OnKill` combos, the subscription is to a project-wide `HealthEventBus` static event
(if one exists in the shipped codebase) or to `PlayerController.OnEnemyKilled` — whichever
event the existing D1/D2 systems expose. The concrete implementation must confirm the
actual event name during the implementation story's code review.

### Architecture

```
ScriptableObject (Unity base)
    └── ComboEffect (abstract SO)
            │  + Activate(PlayerController player)       [subscribe events]
            │  + Deactivate()                            [unsubscribe, clean up]
            │  + OnTrigger(TriggerContext ctx)           [runtime behavior]
            │
            ├── InfernoComboEffect.asset
            │     [SerializeField] float _burnDuration = 3.0f
            │     [SerializeField] float _burnTickInterval = 0.5f
            │     → On Fireball/BurnAttack use: SpawnManager.SpawnGroundPatch(pos, params)
            │
            ├── BlizzardComboEffect.asset
            │     [SerializeField] float _frostNovaRadius = 3.0f
            │     → On kill of frozen enemy: Physics2D.OverlapCircle → apply Slow
            │
            ├── VenomComboEffect.asset
            │     [SerializeField] float _tickIntervalMultiplier = 0.67f
            │     → Activate: AttributeModifier.Add(PoisonTickInterval, multiply, 0.67)
            │     → Deactivate: AttributeModifier.Remove(same modifier)
            │
            ├── ElementalStormComboEffect.asset
            │     [SerializeField] float _bonusMultiplier = 1.30f
            │     [SerializeField] int   _hitLimit = 5
            │     → On skill use against target with Burn+Freeze: track hit count, reset at 5
            │
            ├── ExecutionerComboEffect.asset
            │     [SerializeField] float _hpThreshold = 0.25f
            │     → On skill use against Slowed target: check HP%, check !isBoss, then Kill()
            │
            └── ... (13 more concrete assets following same pattern)

ComboDefinition (extended)
    ├── skillA: BaseSkill
    ├── skillB: BaseSkill
    ├── comboName: string
    ├── description: string
    ├── comboCategory: ComboCategory     (Mage / Archer / Universal)
    ├── triggerCondition: TriggerCondition (OnDraft / OnSkillUse / OnKill / Passive)
    ├── triggerEffect: ComboEffect        ← NEW: SO asset reference
    └── discoveredFlag: bool              ← NEW: persisted to save data

ComboRegistry
    + CheckCombos(IReadOnlyList<BaseSkill> collectedSkills)
    + ActiveCombos: IReadOnlyList<ComboDefinition>
    + OnComboDiscovered: event Action<ComboDefinition>
    − ActivateCombo(ComboDefinition combo, PlayerController player)
    − DeactivateAllCombos()   ← called on run end

TriggerContext (struct)
    + TriggeringSkill: BaseSkill
    + TargetHealth: Health
    + DamageAmount: float
    + TriggerPosition: Vector3
```

### Key Interfaces

```csharp
/// <summary>
/// Abstract base for all combo trigger effects. Subclass once per combo — each
/// subclass is a ScriptableObject asset in Data/Combos/Effects/.
///
/// Lifecycle: ComboRegistry calls Activate() on discovery, Deactivate() on run end.
/// Concrete subclasses subscribe to events in Activate() and unsubscribe in Deactivate().
/// All [SerializeField] tuning values are editable in the Unity Inspector.
/// </summary>
public abstract class ComboEffect : ScriptableObject
{
    /// <summary>
    /// Called when the combo pair is detected. Subscribe to events, apply immediate
    /// attribute modifiers, store the player reference. Called at most once per run.
    /// </summary>
    public abstract void Activate(PlayerController player);

    /// <summary>
    /// Called on run end. Must unsubscribe all event listeners registered in Activate()
    /// and remove any AttributeModifier additions. Must leave the asset in a clean state
    /// for reuse in the next run (ScriptableObjects persist between play sessions).
    /// </summary>
    public abstract void Deactivate();

    /// <summary>
    /// Called by the event handler registered in Activate(). Contains the core runtime
    /// behavior. No-op for Passive effects. Must not be called before Activate().
    /// </summary>
    public virtual void OnTrigger(TriggerContext ctx) { }
}

/// <summary>
/// Context data passed to OnTrigger. Stack-allocated; zero heap cost per trigger.
/// Concrete effects cast or ignore fields as needed.
/// </summary>
public readonly struct TriggerContext
{
    /// <summary>The skill that fired the trigger event, or null for OnKill triggers.</summary>
    public readonly BaseSkill TriggeringSkill;

    /// <summary>The Health component of the affected enemy, or null if not applicable.</summary>
    public readonly Health TargetHealth;

    /// <summary>The damage amount that caused the trigger, or 0 if not a damage event.</summary>
    public readonly float DamageAmount;

    /// <summary>World position of the trigger event (for spawning ground effects).</summary>
    public readonly Vector3 TriggerPosition;

    public TriggerContext(BaseSkill skill, Health target, float damage, Vector3 position)
    {
        TriggeringSkill = skill;
        TargetHealth    = target;
        DamageAmount    = damage;
        TriggerPosition = position;
    }
}

/// <summary>
/// Implemented by ComboRegistry. Called by DraftRunController after each draft pick.
/// </summary>
public interface IComboRegistry
{
    /// <summary>
    /// Scans collectedSkills for new combo pairs. For each newly discovered pair,
    /// fires OnComboDiscovered and calls effect.Activate(player).
    /// </summary>
    void CheckCombos(IReadOnlyList<BaseSkill> collectedSkills);

    /// <summary>All combos currently active this run.</summary>
    IReadOnlyList<ComboDefinition> ActiveCombos { get; }

    /// <summary>Fires when a new combo pair is detected for the first time this run.</summary>
    event System.Action<ComboDefinition> OnComboDiscovered;
}
```

### ScriptableObject Asset Organization

```
Assets/
  Data/
    Combos/
      ComboDatabase.asset               ← extended with 18 ComboDefinition entries
      Effects/
        Mage/
          InfernoComboEffect.asset
          BlizzardComboEffect.asset
          ThunderstrikeComboEffect.asset
          VenomComboEffect.asset
          SupernovaComboEffect.asset
        Archer/
          PlagueVolleyComboEffect.asset
          HailstormComboEffect.asset
          ShadowStepComboEffect.asset
          PredatorsMarkComboEffect.asset
          RapidAssaultComboEffect.asset
          VenomousHailComboEffect.asset
        Universal/
          BerserkersFuryComboEffect.asset
          IroncladComboEffect.asset
          GoldRushComboEffect.asset
          ElementalStormComboEffect.asset
          VampiricStrikesComboEffect.asset
          GaleForceComboEffect.asset
          ExecutionerComboEffect.asset
```

---

## Alternatives Considered

### Alternative 1: ComboEffect as MonoBehaviour component on PlayerController

- **Description**: Each combo effect is a `MonoBehaviour` that gets `AddComponent`'d to
  `PlayerController` on combo discovery and `Destroy`'d on run end. Trigger conditions
  are implemented as `Update()` loops or coroutines within each component.
- **Pros**: Familiar Unity pattern. `Update()` available without special wiring.
  `GetComponent` chain available for sibling systems.
- **Cons**: `AddComponent`/`Destroy` allocates heap memory, triggering GC at combo
  discovery and run end — unacceptable at runtime for a PC/mobile title. MonoBehaviours
  cannot be authored as Inspector assets in `ComboDatabase.asset` without additional
  prefab indirection. Per-effect `Update()` polling violates the < 0.5 ms/frame budget
  when 18 effects are active simultaneously. Tuning values would require prefabs, not
  flat ScriptableObject assets, increasing content authoring friction for a solo developer.
- **Rejection Reason**: GC allocation at combo discovery, per-frame polling cost, and
  MonoBehaviour prefab authoring overhead all violate this project's constraints
  (Architecture Principles P1, P2; performance budget from architecture doc Appendix B).

### Alternative 2: Strategy objects as plain C# classes (not ScriptableObjects)

- **Description**: `ComboEffect` is an abstract C# class (not ScriptableObject).
  Concrete subclasses are instantiated at startup or combo discovery. Tuning values are
  either hardcoded or loaded from a separate JSON/CSV data file.
- **Pros**: No Unity ScriptableObject overhead. Pure C# is easier to unit test with
  standard NUnit (no MonoBehaviour harness needed).
- **Cons**: Tuning values cannot be edited in the Unity Inspector without recompilation or
  a separate data pipeline — violates Architecture Principle P2. Designer/developer workflow
  is broken: changing `_burnDuration` from 3.0s to 4.5s requires a code change, rebuild,
  and re-enter play mode instead of a single Inspector field change. Cross-referencing in
  `ComboDatabase.asset` via `[SerializeField]` is only available for `UnityEngine.Object`
  subclasses. Each of the 18 effects would need a manual `new` factory somewhere,
  introducing coupling that ScriptableObject avoids.
- **Rejection Reason**: Violates Architecture Principle P2 (ScriptableObject as Single
  Source of Truth). The entire project uses ScriptableObject assets for data-driven
  content; introducing a parallel non-SO effect system would be an inconsistent pattern
  and create friction for the solo developer workflow.

### Alternative 3: Per-frame polling in a ComboManager Update loop

- **Description**: A single `ComboManager.Update()` iterates all 18 active `ComboDefinition`
  entries each frame, checking trigger conditions using polling (e.g., `if (player.lastSkillUsed != null)`,
  `if (player.lastKilledEnemy != null)`).
- **Pros**: Simple control flow — all trigger logic in one place. Easy to step through in
  a debugger. No event subscription bookkeeping.
- **Cons**: 18 per-frame condition checks, even with early-exit optimizations, adds
  unnecessary overhead during frames when no trigger condition is met. `lastSkillUsed` and
  `lastKilledEnemy` state requires a polling-compatible API on `PlayerController` that
  doesn't exist and would couple `PlayerController` to the combo system. Open Question A3
  in the architecture doc (Section 10) explicitly recommends event subscription to avoid
  this pattern. The architecture principle P3 (event-driven cross-system communication)
  prohibits polling across module boundaries.
- **Rejection Reason**: Violates Architecture Principle P3. Polling is explicitly rejected
  in architecture doc Section 10 (Open Question A3 resolution). Even at 18 checks × 60
  fps, the per-frame overhead is small in absolute terms, but the design is directionally
  wrong: polling grows linearly with combo count and creates accidental coupling between
  `PlayerController` state exposure and combo trigger logic.

---

## Consequences

### Positive

- **Zero per-frame overhead for idle effects.** Passive effects apply their `AttributeModifier`
  once in `Activate()` and incur no runtime cost thereafter. `OnSkillUse` and `OnKill`
  effects only execute on event delivery, not every frame. For a run with 6 active combos,
  frame budget consumed by the combo system during idle frames is exactly 0 CPU cycles.
- **Data-driven tuning per-effect.** Every tuning knob (damage ratio, radius, duration,
  proc chance, hit limit) is a `[SerializeField]` on the concrete ScriptableObject subclass.
  Balance iteration requires only Inspector edits — no recompilation.
- **Clear authoring contract.** Each new combo requires: one new C# class (~20–35 lines),
  one `.asset` file, and one `ComboDefinition` entry in `ComboDatabase.asset`. The pattern
  is identical across all 18 effects; a solo developer can implement all 18 in a single
  focused session.
- **Clean run boundary.** `Deactivate()` guarantees all subscriptions are removed and all
  stat modifications are reversed before run end. No combo state leaks between runs.
- **Mockable in tests.** `IComboRegistry` is injectable. Concrete `ComboEffect` subclasses
  can be instantiated in NUnit tests via `ScriptableObject.CreateInstance<T>()` without
  running a full scene.
- **Consistent with existing codebase.** ScriptableObject-per-data-asset is the same
  pattern used for `DifficultyConfig`, `EnemyData`, `RoomConfig`, and all skill assets.
  No new paradigms required.

### Negative

- **ScriptableObjects accumulate state between Editor play sessions if `Deactivate()` is
  not called.** If the game crashes mid-run in the Editor, subscribed event delegates may
  remain on the asset until the next `Activate()` call overwrites them, causing doubled
  effects. Mitigation: each concrete subclass clears its `_player` reference and event
  subscriptions at the top of `Activate()` before re-registering.
- **`OnTrigger(TriggerContext)` is virtual, not abstract.** Passive effects have no
  meaningful implementation, but all subclasses still carry the method signature. This is
  a minor interface-segregation impurity accepted for API uniformity.
- **18 `.asset` files in the project.** This is a modest content volume but requires
  organized folder structure (`Data/Combos/Effects/Mage|Archer|Universal/`) to remain
  navigable. The asset organization plan above addresses this.
- **`OnKill` subscription mechanism depends on an event that must be confirmed against the
  shipped codebase.** The architecture doc references `Health.OnDied`; the exact event
  name and signature must be verified during implementation. The implementation story
  should include a code-audit step for this.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| ScriptableObject state leak in Editor if `Deactivate()` is not called on scene stop | MEDIUM | LOW — effects double-fire in Editor testing only, not in builds | Each `Activate()` implementation calls `Deactivate()` first as a guard. Add an `OnDisable()` override on `ComboEffect` that calls `Deactivate()` for Editor hygiene. |
| `OnKill` event name mismatch (Health.OnDied vs PlayerController.OnEnemyKilled) | MEDIUM | LOW — requires one-line fix during implementation | Implementation story must include: "Read `Health.cs` and `PlayerController.cs` to confirm exact OnKill event name and signature before writing `OnKill` combos." |
| ElementalStorm hit-count state shared across multiple targets if not tracked per-target | LOW | MEDIUM — counter resets mid-fight, earlier than intended | `ElementalStormComboEffect` tracks hit count in a `Dictionary<Health, int>` keyed by target instance. Reset each entry when it reaches `_hitLimit`. Clear the dictionary in `Deactivate()`. |
| Executioner instant-kill bypasses boss invulnerability window if `isBoss` check is on wrong component | LOW | HIGH — boss killed during stagger window | Executioner checks `EnemyData.isBoss` (the data field established for OneShotKill in architecture doc Section 4), not a runtime state flag. This is immune to stagger timing. |
| ComboEffect allocates per-trigger via closures or LINQ | LOW | MEDIUM — GC pressure in hot paths | `OnTrigger` implementations use pre-allocated fields (no lambdas, no LINQ). Event subscription uses named methods (not anonymous lambdas) to support clean unsubscription. |

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `combo-synergy-expansion.md` (E4) | "Create `ComboEffect` base ScriptableObject with `Activate(PlayerController)` and `Deactivate()`" | Defines the abstract `ComboEffect : ScriptableObject` base class with exactly these method signatures plus `OnTrigger(TriggerContext)`. |
| `combo-synergy-expansion.md` (E4) | "Create 18 `ComboEffect` implementations (many reuse existing damage/status patterns)" | Each of the 18 combos maps to one concrete `ComboEffect` subclass asset. Effects reuse `DamageCalculator`, `AttributeModifier`, `SpawnManager` per the no-new-systems constraint. |
| `combo-synergy-expansion.md` (E4) | Trigger Conditions table — OnDraft / OnSkillUse / OnKill / Passive | Each condition maps to a concrete subscription pattern in the Decision section above. No polling. |
| `combo-synergy-expansion.md` (E4) | "Combos reset on run end" (Edge Case 5) | `ComboRegistry.DeactivateAllCombos()` calls `effect.Deactivate()` on each active effect. The `discoveredFlag` is in `ComboDefinition` save data, not in `ComboEffect`, so it is not cleared. |
| `combo-synergy-expansion.md` (E4) | "Elemental Storm — 30% bonus, resets after 5 hits" (resolved bug B4 from architecture doc Section 9) | `ElementalStormComboEffect` tracks a per-target hit counter and resets to 0 at `_hitLimit = 5`. The 5-hit cap is a `[SerializeField]` tuning knob. |
| `combo-synergy-expansion.md` (E4) | "Executioner — boss-immune" (Edge Case 3) | `ExecutionerComboEffect.OnTrigger()` checks `EnemyData.isBoss` before executing instant kill. |
| `combo-synergy-expansion.md` (E4) | "All combo definitions, bonuses, and hint rules live in `ComboDatabase` ScriptableObject and can be tuned in the Inspector without code changes" | All tuning values are `[SerializeField]` on concrete `ComboEffect` assets. `ComboDatabase.asset` holds 18 `ComboDefinition` entries each referencing a `ComboEffect` asset. |
| `combo-synergy-expansion.md` (E4) | "Extend `ComboRegistry.CheckCombos()` to activate effects on detection" | `IComboRegistry` interface (Section 6.3 of architecture.md) is extended with `ActivateCombo(ComboDefinition, PlayerController)`. `CheckCombos()` now calls `Activate()` on detected effects. |
| `archer-character.md` (N1) | 6 Archer-exclusive combos referenced | 6 concrete `ComboEffect` subclasses in `Data/Combos/Effects/Archer/` cover all archer combos. They depend on `ArcherPlayerController` events (Arrow Shot, Dodge Roll) — the exact event names must be confirmed against N1 implementation. |

---

## Performance Implications

| Metric | Scenario | Expected Cost | Budget |
|--------|----------|---------------|--------|
| CPU — combo effect per-frame (idle, no trigger) | 18 active passive effects | 0 cycles (no Update loop) | < 0.5 ms/frame total |
| CPU — combo effect per-frame (passive AttributeModifier) | 4 passive effects active | ~4 attribute reads/frame (existing system) | Negligible — within existing attribute budget |
| CPU — OnSkillUse trigger dispatch | Player fires a skill | 1 event dispatch × N OnSkillUse subscribers (max 6 combos) | < 0.01 ms |
| CPU — OnKill trigger dispatch | Enemy dies | 1 event dispatch × N OnKill subscribers (max 4 combos) | < 0.01 ms |
| CPU — `CheckCombos()` on draft | Player drafts a skill | Iterate ≤ 18 `ComboDefinition` entries, O(18 × 2) skill comparisons | < 0.1 ms — runs once per draft, not per frame |
| Memory — 18 `ComboEffect` ScriptableObject assets | Scene loaded | ~18 × ~200 bytes = ~3.6 KB | Negligible |
| Memory — `ElementalStormComboEffect` per-target dictionary | Up to 19 concurrent enemies | 19 `Dictionary<Health, int>` entries | < 1 KB |
| Heap allocation — `TriggerContext` struct | Per trigger event | 0 bytes (stack-allocated struct) | 0 GC cost |

Total estimated combo system cost during active gameplay: < 0.05 ms/frame. Well within the
< 0.5 ms/frame budget.

---

## Migration Plan

`ComboEffect` is an additive change — no existing shipped code is removed or broken.

1. **Create `ComboEffect.cs`** — abstract ScriptableObject base class with the three
   method signatures. New file, no existing code touched. Verify it compiles.
2. **Create `TriggerContext.cs`** — readonly struct. New file. Verify it compiles.
3. **Extend `ComboDefinition`** — add `comboCategory`, `triggerCondition`, `triggerEffect`,
   `discoveredFlag` fields. Existing `ComboDatabase.asset` entries have null `triggerEffect`
   references — this is safe; `CheckCombos()` must null-check before calling `Activate()`.
4. **Create 18 concrete `ComboEffect` subclasses** — one class file per effect. Create
   corresponding `.asset` files in `Data/Combos/Effects/[Mage|Archer|Universal]/`.
5. **Extend `ComboRegistry.CheckCombos()`** — add `ActivateCombo()` and `DeactivateAllCombos()`
   methods. Wire `DeactivateAllCombos()` to the run-end event (already exists in
   `DraftRunController`).
6. **Update `IComboRegistry`** — expose `ActiveCombos` and `OnComboDiscovered` per
   Section 6.3 of `architecture.md`. Verify callers compile.
7. **Populate `ComboDatabase.asset`** — fill all 18 `ComboDefinition` entries with
   correct skill references, category, trigger condition, and effect asset references.
8. **Add combo discovery UI** — flash logic subscribes to `IComboRegistry.OnComboDiscovered`
   in `DraftRunController` or a dedicated `ComboDiscoveryUI` component.
9. **Extend save data** — serialize `discoveredFlag` per `ComboDefinition` index. Hook
   `IComboRegistry.OnComboDiscovered` to set the flag and mark save data dirty.

**Rollback plan**: `ComboEffect` and `TriggerContext` are new files. `ComboDefinition`
additions are additive fields with null defaults. If the approach needs revision,
the four new fields on `ComboDefinition` can be removed and the `.asset` file is
backward-compatible (Unity ignores unknown serialized fields on ScriptableObjects).

---

## Validation Criteria

- [ ] All 18 `ComboEffect` subclass assets exist in `Data/Combos/Effects/`. Each has
      non-null `[SerializeField]` values for all tuning knobs.
- [ ] `ComboDatabase.asset` contains exactly 18 `ComboDefinition` entries, each with
      non-null `skillA`, `skillB`, and `triggerEffect` references (Acceptance Criterion 9).
- [ ] `ComboEffect.Deactivate()` is idempotent — calling it on an already-deactivated
      effect does not throw. Unit test: `CreateInstance<InfernoComboEffect>()`, call
      `Deactivate()` without `Activate()` — no exception.
- [ ] `ComboEffect` state does not leak between runs. Unit test: `Activate(player)`,
      `Deactivate()`, `Activate(player)` — event fires exactly once per trigger, not twice.
- [ ] No `ComboEffect` allocates heap memory in `OnTrigger()`. Profile: enable GC alloc
      tracing, trigger each effect type — 0 bytes allocated during `OnTrigger`.
- [ ] Passive effects (`Venom`, `Ironclad`, `Berserker's Fury`, `Gale Force`,
      `Predator's Mark`) apply their `AttributeModifier` in `Activate()` and reverse it
      in `Deactivate()`. Unit test: read attribute value before `Activate()`, after
      `Activate()`, and after `Deactivate()` — before and after-deactivate values match.
- [ ] Executioner does NOT instant-kill a boss target at < 25% HP with Slow active.
      Unit test: mock `EnemyData.isBoss = true`, trigger `ExecutionerComboEffect.OnTrigger()`,
      confirm target HP unchanged (Acceptance Criterion 7).
- [ ] Elemental Storm resets hit count at 5. Unit test: call `OnTrigger()` 6 times
      on a target with both Burn and Freeze — bonus applies on hits 1–5, not hit 6.
- [ ] Frost Nova fires only when killed enemy had Frozen status at death. Unit test with
      Frozen enemy → nova spawns. Unit test with non-Frozen enemy → no nova
      (Acceptance Criterion 8).
- [ ] `ComboRegistry.CheckCombos()` correctly identifies all 18 combo pairs. Unit test:
      inject each pair of skills and verify the matching `ComboDefinition` is activated
      (Acceptance Criteria 1–4).
- [ ] `IComboRegistry.OnComboDiscovered` fires exactly once per newly discovered combo per
      run — not on subsequent drafts that confirm an already-active combo.

---

## Related Decisions

- `docs/architecture/architecture.md` — Section 6.3 (`IComboRegistry` API boundary),
  Section 8 (Architecture Principles P1–P5), Section 9 (resolved bug B4: Elemental Storm
  uncapped), Section 10 Open Question A3 (event subscription vs. polling resolution)
- `docs/architecture/adr-0001-difficulty-config-interface.md` — establishes the
  ScriptableObject-as-provider pattern used here; no dependency, but same structural approach
- `docs/architecture/adr-0002-spawnmanager-mode-routing.md` — `SpawnManager` is called
  by `InfernoComboEffect` to spawn burning ground patches; the `IWaveProvider` pattern
  does not affect this, but `SpawnManager` is a shared hotspot and E4 stories must
  coordinate with E1/N2 stories when touching `SpawnManager`
- `design/gdd/combo-synergy-expansion.md` — E4 GDD, primary source for all 18 combos,
  trigger conditions, detection flow, tuning knobs, and acceptance criteria
- `design/gdd/archer-character.md` — N1 GDD, source for 6 Archer-exclusive combos and
  the Archer skill references required by those effects

---

## Amendment 2026-04-16 — Implementation Reality Corrections

Applied during E4-003 (Mage Combo Effects) implementation after a mandatory code audit
of the shipped codebase revealed four mismatches between this ADR's original Decision
section and the actual API surface. No Decision is reversed — only clarified/corrected.

### 1. `PlayerController.OnSkillUsed` — event is new, added in E4-003

This ADR assumed an existing skill-activation event. None was shipped. The demo invokes
skills via direct `skill.Activate(character)` calls inside
`PlayerController.OnSkillActivation(int skillIndex)` with no event broadcast.

**Resolution:** E4-003 introduces `public event Action<BaseSkill, Vector3> OnSkillUsed`
on `PlayerController`. The event fires inside the existing 0.2s animation-delay coroutine
immediately after `skillInstance.Activate(this)` succeeds — the `Vector3` payload is the
player's cast-commit position (captured before the coroutine) so combo effects can spawn
ground patches at the correct location.

R-026 is hereby updated: `OnSkillUse` combos subscribe to
`PlayerController.OnSkillUsed(BaseSkill, Vector3)` in `Activate()`.

### 2. Kill event — `Health.OnDead`, parameterless

This ADR referenced `Health.OnDied`. The actual event is `Health.OnDead` of type `Action`
(no parameters). There is **no global kill bus**; each enemy's `Health` component exposes
its own event, fired at `Health.cs:159` when `currentHealth <= 0`.

**Consequence for OnKill combos:** the handler cannot receive the killing skill, damage
amount, or target reference from the event. The combo must subscribe per-enemy (enemy-spawn
hook) OR track the last-damage context separately. For E4-003 scope, the simpler pattern
wins: combos subscribe to `Health.OnDead` on each enemy at spawn time (via an existing
enemy-spawned hook if available, else at `Activate()` scanning current enemies + subscribing
to new ones via `SpawnManager` — confirm during impl). `TriggerContext.TargetHealth` is
populated from the sending `Health`, `DamageAmount` is 0, `TriggerPosition` is the
`Health.transform.position`.

### 3. Status-check API — `StateMachine.HasDebuffState(StateCategory)`

This ADR used `StateMachine.HasState()` in prose. The actual API is
`StateMachine.HasDebuffState(StateCategory category)` at `StateMachine.cs:69`. Valid
enum values: `Frozen`, `Stun`, `Burn`, `Poison`, `MoveSpeedDown` (not `Slowed`).

**Resolution:** Thunderstrike reads `ctx.TargetHealth.GetStateMachine().HasDebuffState(StateCategory.Stun)`.
Blizzard (on enemy death) reads `enemyHealth.GetStateMachine().HasDebuffState(StateCategory.Frozen)`.
Executioner uses `StateCategory.MoveSpeedDown` (the in-code name for "Slowed").

### 4. Physics is 3D, not 2D

This ADR's diagram showed `Physics2D.OverlapCircle`. The project uses 3D physics across
the board — confirmed via three cite sites: `ChargeAbility.cs`, `GroundSlamAbility.cs`,
`BloodBondSkill.cs`, plus `Utils.cs`.

**Resolution:** Blizzard and Supernova use `Physics.OverlapSphere` (or the non-allocating
`Physics.OverlapSphereNonAlloc` with a cached buffer — preferred for OnKill combos that
may fire on multi-kill frames).

### 5. `SpawnManager.SpawnGroundPatch` — does not exist; use prefab pattern

This ADR referenced `SpawnManager.SpawnGroundPatch(pos, params)` for Inferno. No such
method exists. The shipped pattern for persistent area effects is: `[SerializeField]`
prefab reference on the skill/effect, `Instantiate(prefab, position, Quaternion.identity)`,
`<Area>.Initialize(this)` for runtime data, `Destroy(obj, duration)` for auto-cleanup.
Reference implementation: `IcePondSkill.CreateIcePond` at
`IcePondSkill.cs:84-96`.

**Resolution:** Inferno holds `[SerializeField] GameObject _burnPatchPrefab`. On trigger,
instantiates the prefab at `ctx.TriggerPosition`, calls `BurnPatchArea.Initialize(duration, tickInterval)`,
schedules `Destroy` for `_burnDuration` seconds. A new `BurnPatchArea` MonoBehaviour is
authored in E4-003 (mirroring `IcePondArea`). The `.prefab` is authored in the Unity Editor
post-merge (same deferral pattern as N1-006 archer-skill prefabs).

### 6. Venom redesign — duration-multiplier instead of tick-interval

This ADR's Venom spec ("poison tick 1.0s → 0.67s") assumed a shipped poison DoT damage
tick. The code audit found the DoT damage loop is NOT implemented: `PoisonState` ticks
only for duration expiry, `DamageCalculator.CalculateDotDamage` exists but has zero
callers, and neither `PoisonAttackSkill` nor `PoisonState` exposes a tick-interval field.
Only `BurnState` and `NumbState` ship tick intervals (hardcoded private constants).

**Resolution (V1):** Venom's effect changes from "tick 50% faster" to "duration 50%
longer". `VenomComboEffect` holds `[SerializeField] PoisonAttackSkill _poisonSkill` +
`[SerializeField] float _durationMultiplier = 1.5f`. On `Activate()`, stores the current
`totalDurationInMs` via reflection (private field), writes back `original * multiplier`.
On `Deactivate()`, writes the stored original back.

**F-003 compliance (runtime SO mutation):** Venom is technically mutating a ScriptableObject
at runtime, same forbidden pattern that retracted `ComboDatabase.discoveredFlag` in E4-001.
Tolerated here because (a) `Deactivate()` guarantees restore, (b) `ComboEffect.OnDisable`
always calls `Deactivate` so Editor play-mode exit restores even on crash-outside-StartDraftRun,
(c) the mutation is bounded in scope to a single field on a single known asset. This is a
pragmatic exception, not a general relaxation of F-003. GDD (`combo-synergy-expansion.md`)
is amended to reflect the new effect text.

**Future work:** If/when the poison DoT damage loop is built as a proper system, Venom
should migrate to modify that system's tick interval instead of mutating the SO field.
Tracked as: `Follow-up — rebuild Venom on poison DoT tick system (depends on poison-DoT
damage story)`.

### Governing Rule Updates

These amendments update (not replace) the following control-manifest rules:

- **R-026** (updated): `OnSkillUse` subscribes to `PlayerController.OnSkillUsed(BaseSkill, Vector3)`. `OnKill` subscribes to `Health.OnDead` (parameterless) per-enemy. `Passive` applies `AttributeModifier.Add()` OR (narrow exception) modifies a specific SO field with guaranteed symmetric restore.

### Amendment Validation Criteria

- [x] Code audit via `/dev-story` subagent found 4 mismatches; all documented and resolved
- [x] `PlayerController.OnSkillUsed` event added in same branch as E4-003 (not a separate story — too small to warrant split)
- [ ] E4-003 implementation passes audit against this amendment (validated at `/story-done`)
- [ ] No new F-003 violations introduced beyond the documented Venom exception
- [ ] GDD `combo-synergy-expansion.md` reflects Venom duration-not-tick change
