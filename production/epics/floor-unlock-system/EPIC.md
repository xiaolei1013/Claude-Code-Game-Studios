# Epic: Floor / Biome Unlock System

> **Layer**: Feature
> **GDD**: `design/gdd/floor-unlock-system.md`
> **Architecture Module**: `FloorUnlock` (autoload — rank governed by ADR-0003 Amendment table; item #3 in `CONSUMER_PATHS`)
> **Control Manifest Version**: 2026-04-26
> **Status**: Complete (all stories shipped — see systems-index Implementation Status; per-story Status fields flipped 2026-05-08)
> **Stories**: 9 stories authored — see table below

## Overview

The Floor/Biome Unlock System is the **persistent progression gate** that
answers *"which floors can the player dispatch a formation to right now?"*
It sits between the Biome/Dungeon Database (which defines *what content
exists*) and the Dungeon Run Orchestrator (which decides *whether a
specific dispatch is legal*). The system holds a single piece of durable
state: for each biome, the highest `floor_index` the player has ever
first-cleared — a **monotonic** integer that advances on any clear (WIN
or LOSING; no fail state per Pillar 1) and is **never rolled back**.

A fresh save starts with Forest Reach F1 unlocked and nothing else; every
other floor becomes available by clearing the one before it. The system
has a visible player-facing moment — the *"you just unlocked the next
floor"* beat that the game-concept doc flags as the MVP's core
breakthrough emotion — but the **rendering** of that moment is owned by
the Unlock/Victory Moment UI (Presentation epic). This GDD owns the
**state transition** and the **access gate**.

The floor-clear gold idempotency gate (`Economy.floor_clear_bonus_credited`,
per ADR-0002) is a **separate** layer that operates in parallel on the same
first-clear event — Economy decides whether to pay out gold; FloorUnlock
decides whether the floor is henceforth accessible. The two systems do not
read each other's state.

Implements Pillar 1 (Respect the Player's Time — permanent unlocks, no
regression) + Pillar 3 (gates the matchup-decision surface by controlling
which floors are available for dispatch).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007: Scene Transition + Persist Coupling | Unlock cascade fires `scene_boundary_persist(reason)` AFTER `victory_moment` (the player sees the unlock before persist commits) | MEDIUM |
| ADR-0014: Offline Replay Batch Chunking + RunSnapshot Schema | Floor unlocks during offline replay are batched with the run; no mid-batch unlock cascades | MEDIUM |
| ADR-0002: Losing-First-Clear Reclaimable on Win | Economy's gold idempotency gate parallels Floor Unlock's monotonic-integer gate; both systems independently track first-clear state without coupling | LOW |
| ADR-0003: Autoload Rank Table Canonical | FloorUnlock is item #3 in `SaveLoadSystem.CONSUMER_PATHS` (after Economy, after HeroRoster); zero-arg `_init` per Amendment #3 | LOW |
| ADR-0011: Resource Schemas Core Databases | FloorUnlock READS from `BiomeDungeonDatabase` (Core layer) but does not duplicate floor metadata — references `floor_index` integer only | LOW |

## GDD Requirements Coverage

| Metric | Count |
|---|---|
| Total TRs (`TR-floor-unlock-*`) | per `tr-registry.yaml` |
| Coverage | high (Pass-9 closed 6 BLOCKING + 9 CONCERN + 3 NICE; cross-pass surfacing rate dropping toward convergence) |
| Open gap | I.11 reopen — engine-idiom verification (third consecutive wrong claim caught by 3-specialist cross-model convergence). Carry forward to story authoring as a deliberate per-pass verification task. |

## Engine Compatibility Notes (Godot 4.6)

- Monotonic-integer state: simple `Dictionary[String, int]` keyed by `biome_id`; no complex containers
- `PROPERTY_HINT_*` claims rejected three times by reviewer — verify any inspector hints against `docs/engine-reference/godot/` before story implementation (I.11 lesson)
- Save/Load consumer contract: `get_save_data()` returns `{ "biome_floors_cleared": Dictionary[String, int] }`; `load_save_data(data)` validates + applies

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`
- All acceptance criteria from `design/gdd/floor-unlock-system.md` verified
- `tests/unit/floor_unlock/` covers monotonic-advance, never-rollback, fresh-save default (F1 only), per-biome independence
- `tests/integration/floor_unlock/` exercises: orchestrator first-clear → FloorUnlock advance → SaveLoadSystem persist → reload → state preserved; LOSING-then-WIN re-run sequence; offline-replay batch with mid-run unlock
- Pillar 1 invariant test: forced state-rollback attempt (e.g., reload older save) does not regress unlock state in current session

## Stories

| # | Story | Type | Status | TRs | ADR |
|---|-------|------|--------|-----|-----|
| 001 | Autoload skeleton + `_unlock_state` typed dict + fresh-save default | Logic | Ready | TR-001/002/003/005 | ADR-0003 + ADR-0011 |
| 002 | Public read API + FloorState enum | Logic | Ready | TR-004/011/014 | ADR-0009 |
| 003 | Biome availability + completeness + get_available_biomes | Logic | Ready | TR-023/024/020 | ADR-0011 |
| 004 | BIOME_FLOOR_COUNT + handler guards + DI loggers | Integration | Ready | TR-012/013/021 | ADR-0009 + ADR-0011 |
| 005 | advance_unlock + signal subscription + monotonicity | Integration | Ready | TR-006/007/008/009/010 | ADR-0007 + ADR-0014 + ADR-0003-A1 |
| 006 | Save/Load consumer + per-value processing pipeline | Integration | Ready | TR-015/016/017/018/019/020/029 | ADR-0004 + ADR-0011 |
| 007 | Orchestrator DISPATCHING gate wiring | Integration | Ready | TR-026 | ADR-0009 |
| 008 | Offline replay parity (foreground vs offline lockstep) | Integration | Ready | TR-030/025 | ADR-0014 + ADR-0007 |
| 009 | debug_unlock_all + UI fanfare losing/win equivalence | Logic + Integration | Ready | TR-022/027/028 | ADR-0002 |

**Story sequencing**: 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 (linear; each builds on the prior). Sprint 9 candidate scope: Stories 001-007 form a complete production-ready FloorUnlock; 008-009 are post-launch invariants that can land later if Sprint 9 capacity is constrained.

## Next Step

Run `/story-readiness production/epics/floor-unlock-system/story-001-autoload-skeleton-and-fresh-save-default.md` to validate the first story is implementation-ready, then `/dev-story` against it. The Unlock/Victory Moment UI (Presentation epic — not yet decomposed) renders the unlock beat; this epic owns only the state machine.
