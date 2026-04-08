# Story: BossController Subclass & IBossPhaseController Interface

> **Epic**: boss-phase-system
> **Type**: Logic
> **Priority**: P0
> **Status**: Ready
> **Manifest Version**: 2026-04-08-v1
> **Estimated Effort**: L

## Context

**GDD Requirement**: TR-boss-001 (BossController : EnemyController subclass with List<BossPhase> configurable in Inspector), TR-boss-002 (phase check hooks into Health.OnDamaged event, checks phases sorted by threshold ascending), TR-boss-003 (multi-threshold skip: single massive hit triggers all skipped phases in sequence, each with 0.5s stagger), TR-boss-014 (IBossPhaseController interface: CurrentPhaseIndex, TotalPhases, IsInStagger, OnPhaseTransition, OnBossDefeated)
**ADR Reference**: ADR-0004 -- Decision section (class hierarchy, BossPhase struct, IBossPhaseController interface definition, ascending threshold sort, iterate all untriggered phases per damage event)
**Control Manifest Rules**: R-003 (implement IBossPhaseController on BossController), R-008 (subscribe to Health.OnDamaged in Awake, not Update), R-009 (sort _phases by HealthThreshold ascending at Awake; iterate all untriggered per damage event), R-016 (BossPhase as [System.Serializable] struct), G-004 (phase check O(n) where n <= 3, per damage event not per frame), G-012 (validate _phases list length in Awake), F-008 (do not compose via BossPhaseComponent), F-009 (do not define BossPhase as separate ScriptableObject assets)

## Description

Create the core BossController class and its supporting data structures. This is the foundational story for the entire E3 epic -- all other boss stories depend on this.

**Files to create:**

1. **`IBossPhaseController.cs`** -- C# interface matching the architecture doc Section 6.2 definition verbatim. Properties: `int CurrentPhaseIndex`, `int TotalPhases`, `bool IsInStagger`. Events: `event Action<int> OnPhaseTransition`, `event Action OnBossDefeated`. Full XML doc comments on each member. Place in `Assets/Trizzle/Scripts/Combat/`.

2. **`BossPhase.cs`** -- `[System.Serializable]` struct with fields: `[Range(0f, 1f)] float HealthThreshold`, `BTNode BehaviourTree`, `GameObject TransitionVFX`, `AttributeModifier[] StatModifiers`, `[HideInInspector] bool HasTriggered`. Place alongside BossController.

3. **`BossController.cs`** -- `BossController : EnemyController` MonoBehaviour implementing `IBossPhaseController`. Core behavior:
   - `[SerializeField] List<BossPhase> _phases` configurable in Inspector
   - In `Awake()`: sort `_phases` by `HealthThreshold` ascending, subscribe to `Health.OnDamaged` event, validate phase count (log error if < 2)
   - `OnDamageReceived()` handler: compute `currentHPPercent = CurrentHealth / MaxHealth`, iterate all phases ascending, for each untriggered phase where `currentHPPercent <= phase.HealthThreshold`: start coroutine `TransitionToPhase(phase)` (see Story 002 for coroutine implementation -- stub it here as a placeholder that sets `HasTriggered = true` and fires `OnPhaseTransition`)
   - Override `BuildTreeForThisEnemy()` to return `_phases[_currentPhaseIndex].BehaviourTree`
   - Implement all `IBossPhaseController` properties and events
   - Fire `OnBossDefeated` event when boss HP reaches 0 (hook into existing death path)
   - Guard phase iteration with `isDead` check per ADR-0004 Risks section

**Key constraints from ADR-0004:**
- Phases must be sorted ascending by threshold at Awake, not at each damage event
- Multi-threshold skip is handled by iterating ALL untriggered phases per damage event (not breaking after the first match)
- `HasTriggered` is one-way -- never reset to false
- `OnBossDefeated` must fire BEFORE `StopAllCoroutines()` in the death path so subscribers receive the event

## Acceptance Criteria

- [ ] `IBossPhaseController` interface exists with all 5 members (2 properties + 1 bool + 2 events) and XML doc comments matching ADR-0004 Key Interfaces section
- [ ] `BossPhase` is a `[System.Serializable]` struct (not ScriptableObject) with all 5 fields
- [ ] `BossController : EnemyController` exists and implements `IBossPhaseController`
- [ ] `_phases` is a `[SerializeField] List<BossPhase>` editable in Inspector
- [ ] Phases are sorted by `HealthThreshold` ascending in `Awake()`
- [ ] Phase check subscribes to `Health.OnDamaged` event in `Awake()` -- no `Update()` polling
- [ ] Single damage event crossing 2 thresholds triggers both phases in sequence (multi-threshold skip)
- [ ] `BuildTreeForThisEnemy()` override returns current phase's BehaviourTree
- [ ] `OnBossDefeated` event fires on boss death
- [ ] `OnPhaseTransition` event fires with new phase index on each threshold crossing
- [ ] Phase count validated in `Awake()` -- logs error if < 2
- [ ] All code compiles with zero warnings in Unity 6000.3.11f1

## Test Evidence

**Type**: Unit Test
**Path**: `tests/unit/boss/`

- Unit test: Create BossController with 3 phases at 0.60, 0.30, unsorted in list. After Awake, verify internal order is 0.30, 0.60 (ascending)
- Unit test: Simulate damage to 50% HP on a 2-phase boss (threshold 0.50). Verify `OnPhaseTransition` fires with index 1. Verify `CurrentPhaseIndex == 1`
- Unit test: Simulate one-hit from 100% to 20% HP on a 3-phase boss (thresholds 0.60, 0.30). Verify `OnPhaseTransition` fires twice (indices 1, then 2). Verify `CurrentPhaseIndex == 2`
- Unit test: `HasTriggered` prevents re-triggering: damage boss past 50%, heal back above 50%, damage past 50% again. Verify `OnPhaseTransition` fires only once total
- Unit test: Boss death fires `OnBossDefeated` exactly once

## Dependencies

- **Blocked by**: None within E3. Depends on existing `EnemyController`, `Health.OnDamaged`, `BTNode`, `AttributeModifier` (all shipped systems)
- **Blocks**: 002-stagger-state-phase-transition, 003-enemydata-isboss-flag, 004-ability-ground-slam, 005-ability-charge, 006-ability-shield-phase, 007-ability-rain-of-fire, 008-boss-prefab-configuration, 009-boss-phase-vfx, 010-boss-kill-tracking-fix, 011-boss-system-tests

## Engine Notes

Uses `MonoBehaviour` subclassing, `[System.Serializable]` struct with `List<T>`, C# events, and `Health.OnDamaged` subscription -- all stable Unity APIs confirmed in ADR-0004 Engine Compatibility section. Verify that `[System.Serializable]` structs with `List<T>` serialize correctly in Inspector under Unity 6000.3.11f1 (ADR-0004 Verification Required). Confirm coroutine lifecycle is unaffected by Unity 6 frame scheduling changes.
