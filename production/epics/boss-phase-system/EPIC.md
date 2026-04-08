# Epic: Boss Phase System

> **Layer**: Core (Layer 1)
> **GDD**: design/gdd/boss-phase-system.md
> **Architecture Module**: E3 Boss Phases -- Gameplay Layer
> **Governing ADRs**: ADR-0004
> **Status**: Ready
> **Stories**: 11 stories created (see table below)

## Overview

The Boss Phase System adds multi-phase behavior to boss enemies, making them shift abilities at HP thresholds. Currently bosses are regular enemies with no distinct behavior. This system introduces `BossController : EnemyController` with a `List<BossPhase>` configurable in the Inspector, subscribing to `Health.OnDamaged` for event-driven phase checks. Five unique bosses (Stone Guardian, Dark Sorcerer, Necromancer, War Chief, Lich King) cover rooms 1-10 with 2-phase (rooms 1-5) and 3-phase (rooms 6-10) configurations. Phase transitions include a 0.5s stagger state (invulnerable, debuff clear, BehaviourTree swap, stat modifiers, VFX). The `EnemyData.isBoss` flag replaces all tag/name-based boss detection. Four new ability templates (GroundSlam, Charge, ShieldPhase, RainOfFire) are implemented as MonoBehaviours. Depends on E2 (Difficulty System) for boss stat scaling via `IDifficultyProvider`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: BossController Phase System | `BossController : EnemyController` subclass with `List<BossPhase>` in Inspector; phases checked per damage event not per frame; `EnemyData.IsBoss` replaces all tag/string boss checks. Stagger coroutine with invulnerability, debuff clear, tree swap, stat mods, VFX. | LOW -- uses MonoBehaviour subclassing, serialized structs, C# events, coroutines; all stable pre-cutoff APIs |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|-------------|
| TR-boss-001 | BossController : EnemyController subclass with List<BossPhase> configurable in Inspector | ADR-0004: Class hierarchy and data structure established |
| TR-boss-002 | Phase check hooks into Health.OnDamaged event (not Update); checks phases sorted by threshold ascending | ADR-0004: Subscription to Health.OnDamaged in Awake; ascending sort mandated |
| TR-boss-003 | Multi-threshold skip: single massive hit triggers all skipped phases in sequence, each with 0.5s stagger | ADR-0004: Iterate all untriggered phases per damage event |
| TR-boss-004 | Stagger state: 0.5s invulnerable, clears debuffs, swaps BehaviourTree, applies stat modifiers, plays VFX | ADR-0004: Stagger coroutine sequence fully specified |
| TR-boss-005 | Phases are one-way; healing a boss does not reverse triggered phases | ADR-0004: HasTriggered flag; phases never reverse |
| TR-boss-006 | EnemyData.isBoss flag replaces all tag/name-based boss detection | ADR-0004: Bool IsBoss on EnemyData mandated; string checks forbidden |
| TR-boss-007 | 4 new ability templates as MonoBehaviours: GroundSlam, Charge, ShieldPhase, RainOfFire | ADR-0004: Templates named, attachment model defined |
| TR-boss-008 | 5 unique bosses: Stone Guardian, Dark Sorcerer, Necromancer, War Chief, Lich King | Not covered by ADR -- content authoring stories |
| TR-boss-009 | Rooms 1-5: 2-phase bosses; Rooms 6-10: 3-phase bosses | ADR-0004: List<BossPhase> length is per-prefab |
| TR-boss-010 | Summoned minions persist after boss death; room does not clear until all enemies dead | Not covered by ADR -- implementation story |
| TR-boss-011 | Shield Phase blocks damage but NOT status effects; shield destroyed by hit counter | Not covered by ADR -- ability template implementation |
| TR-boss-012 | Fix DraftRunController.OnRunComplete() to detect actual boss kill via IBossPhaseController.OnBossDefeated | ADR-0004: IBossPhaseController interface with OnBossDefeated event |
| TR-boss-013 | Boss death during stagger must process immediately; death takes priority over phase transition | ADR-0004: Guard with isDead check; StopAllCoroutines on death |
| TR-boss-014 | IBossPhaseController interface: CurrentPhaseIndex, TotalPhases, IsInStagger, OnPhaseTransition, OnBossDefeated | ADR-0004: Interface specified verbatim from architecture.md Section 6.2 |

## Definition of Done

- All stories implemented, reviewed, closed via /story-done
- All acceptance criteria from GDD verified
- All Logic/Integration stories have passing tests
- All Visual/Feel/UI stories have evidence docs
- `BossController` subclass functional with phase transitions
- All 5 boss prefabs created with correct phase configurations
- All 4 ability templates implemented and configurable
- `EnemyData.isBoss` flag replaces all tag/name checks (grep verified)
- `IBossPhaseController` interface fully implemented
- DraftRunController.OnRunComplete() uses OnBossDefeated event
- Boss playable through Room 1 with phase transitions working
- ADR-0004 validation criteria all passing

## Stories

| # | Story | Type | Priority | Size | TRs | Dependencies | Status |
|---|-------|------|----------|------|-----|-------------|--------|
| 001 | [BossController Subclass & IBossPhaseController](001-boss-controller-subclass.md) | Logic | P0 | L | TR-boss-001, 002, 003, 014 | None (Layer 0 for E3) | Ready |
| 002 | [Stagger State & Phase Transition](002-stagger-state-phase-transition.md) | Logic | P0 | M | TR-boss-004, 005, 013 | 001 | Ready |
| 003 | [EnemyData.isBoss Flag](003-enemydata-isboss-flag.md) | Logic | P0 | S | TR-boss-006 | 001 | Ready |
| 004 | [Ability: Ground Slam](004-ability-ground-slam.md) | Logic | P1 | M | TR-boss-007 | 001 | Ready |
| 005 | [Ability: Charge](005-ability-charge.md) | Logic | P1 | M | TR-boss-007 | 001 | Ready |
| 006 | [Ability: Shield Phase](006-ability-shield-phase.md) | Logic | P1 | M | TR-boss-007, 011 | 001 | Ready |
| 007 | [Ability: Rain of Fire](007-ability-rain-of-fire.md) | Logic | P1 | M | TR-boss-007 | 001 | Ready |
| 008 | [5 Boss Prefab Configuration](008-boss-prefab-configuration.md) | Config | P1 | L | TR-boss-008, 009, 010 | 001-007 | Ready |
| 009 | [Boss Phase VFX](009-boss-phase-vfx.md) | Visual | P1 | M | TR-boss-004 | 001, 002 | Ready |
| 010 | [Boss Kill Tracking Fix](010-boss-kill-tracking-fix.md) | Logic | P0 | S | TR-boss-012 | 001, 003 | Ready |
| 011 | [Boss System Tests](011-boss-system-tests.md) | Logic | P0 | M | All TRs | 001-010 | Ready |

### Story Dependency Graph

```
001 BossController (L, P0) ─── foundation for all
├── 002 Stagger (M, P0)
├── 003 isBoss Flag (S, P0)
│   └── 010 Kill Tracking Fix (S, P0)
├── 004 Ground Slam (M, P1)
├── 005 Charge (M, P1)
├── 006 Shield Phase (M, P1)
├── 007 Rain of Fire (M, P1)
├── 008 Prefab Config (L, P1) ── depends on ALL of 001-007
└── 009 VFX (M, P1) ── depends on 001, 002
011 Tests (M, P0) ── depends on ALL of 001-010
```

### Critical Path

001 --> 002 --> 008 --> 011

### Sizing Summary

- P0 stories: 001 (L) + 002 (M) + 003 (S) + 010 (S) + 011 (M) = ~11 dev-days
- P1 stories: 004-007 (4xM) + 008 (L) + 009 (M) = ~15 dev-days
- Total estimated: ~26 dev-days (before 20% buffer)

### Parallelization Opportunities

After 001 completes, these can run in parallel:
- Track A: 002 (stagger) --> feeds into 008, 009
- Track B: 003 (isBoss) --> 010 (kill tracking fix)
- Track C: 004, 005, 006, 007 (ability templates, all independent of each other)

## Next Step

Run `/sprint-plan new` to schedule these stories into sprints, or `/story-readiness 001-boss-controller-subclass.md` to validate the first story before starting implementation.
