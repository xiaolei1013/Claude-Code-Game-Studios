# Epic: Dungeon Run Orchestrator

> **Layer**: Feature
> **GDD**: `design/gdd/dungeon-run-orchestrator.md`
> **Architecture Module**: `DungeonRunOrchestrator` (autoload — rank 6+ governed by ADR-0003 Amendment table)
> **Control Manifest Version**: 2026-04-24
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories dungeon-run-orchestrator`

## Overview

The Dungeon Run Orchestrator is the **run lifecycle coordinator** — the
stateful host that lets Combat Resolution remain stateless. It owns all
per-dispatch state (`run_snapshot` — formation, floor, cached DPS, kill
schedule, loop counter, idempotency flags), subscribes to TickSystem's
`tick_fired(n)` signal in foreground mode, and calls Combat's pure-function
entry points (`emit_events_in_range` foreground, `compute_offline_batch`
offline) to drive the dungeon loop.

The Orchestrator does not author new mechanics; it routes existing ones.
Gold attribution to Economy, kill-pop signals to Dungeon Run View,
once-per-dispatch first-clear gates, boss fanfare triggers, the
`LOSING_RUN_LOOT_FACTOR` multiplier — all are routing decisions between
Combat's outputs and consumer signal handlers. It locks five contracts
that Combat Resolution explicitly deferred: AC-COMBAT-07b (LOSING gold
attribution end-to-end), AC-COMBAT-09b (once-per-dispatch first-clear),
E.5 (LOSING re-run after first-clear), I.Q7 (mid-run formation
reassignment), I.Q8 (boss-fanfare trigger placement).

Per ADR-0001, mid-run formation reassignment is **forbidden** — the
formation is locked at dispatch and any reassignment terminates the run.
Per ADR-0014, RunSnapshot is the persist payload and offline batches are
deterministic given snapshot + tick range. Per ADR-0007, scene transition
to `dungeon_run_view` fires `scene_boundary_persist(reason)` BEFORE the
transition, hard-stopping on `save_failed`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Mid-Run Formation Reassignment | Reassignment terminates the run; formation locked at dispatch | LOW |
| ADR-0002: Losing-First-Clear Reclaimable on Win | First-clear bonus credit gated on win, idempotent across LOSING re-runs; routes through `Economy.try_award_floor_clear` | LOW |
| ADR-0010: Combat Resolver Snapshot + Parity | Orchestrator IS the snapshot owner; calls Combat's pure functions | MEDIUM |
| ADR-0014: Offline Replay Batch Chunking + RunSnapshot Schema | RunSnapshot persist payload; orphan-hero recovery triggers `run_snapshot_discarded_orphan` + Economy refund | MEDIUM |
| ADR-0007: Scene Transition + Persist Coupling | `scene_boundary_persist(reason)` fires before `dungeon_run_view`; `save_failed` aborts transitions | MEDIUM |
| ADR-0009: Matchup Resolver DI | Orchestrator constructs/wires both resolvers via lazy-default + `set_*_resolver(spy)` test seams | LOW |
| ADR-0003 Amendment #3: Autoload `_init` Zero-Arg | Orchestrator IS an autoload; zero-arg `_init`; resolver dependencies wired in `_ready()` via lazy-default | LOW |

## GDD Requirements Coverage

| Metric | Count |
|---|---|
| Total TRs (`TR-orchestrator-*`) | per `tr-registry.yaml` |
| Coverage | high (5 governing ADRs cover the routing + lifecycle surface) |
| BLOCKING re-review items closed | 17/17 (Pass 5D AC Triangulation Sweep) |
| Writeable ACs | 13/13 post-Pass-5D |

## Engine Compatibility Notes (Godot 4.6)

- Lazy-default DI seam REQUIRED — autoload `_init` is called with zero args (Pass-INIT-PROBE-SYNC 2026-04-22 VERIFIED)
- `tick_fired(n)` foreground subscription at `_ready()` (rank ≥ 6 to TickSystem rank 0 — safe)
- `OfflineRunResult.new(...)` MUST use positional + property-setter pattern (NOT keyword args — invalid GDScript 4.6 per Pass 5D)
- DataRegistry.resolve via real DataRegistry + Forest Reach fixture (Godot ResourceLoader caching invariant)

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`
- All 13 writeable ACs from `design/gdd/dungeon-run-orchestrator.md` verified
- `tests/unit/dungeon_run_orchestrator/` covers state-machine transitions (NO_RUN/RUN_ACTIVE/RUN_ENDED) + once-per-dispatch first-clear idempotency + duplicate-tick rejection
- `tests/integration/dungeon_run_orchestrator/` exercises: dispatch → tick foreground → kills → first-clear → unlock cascade; LOSING re-run after WIN clear; orphan-hero RunSnapshot recovery
- Mid-run formation reassignment terminates run (ADR-0001 acceptance test)
- Scene-boundary persist fires BEFORE `dungeon_run_view` transition (integration with SaveLoadSystem Story 012)
- **Vertical Slice gate**: A human can dispatch a formation, watch ticks fire, see kill events stream, and observe first-clear unlock — without dev intervention

## Stories

Not yet created. Run `/create-stories dungeon-run-orchestrator` to author.
**This is the Vertical Slice's core gameplay loop.**

## Next Step

`/create-stories dungeon-run-orchestrator`. Pair with HeroRoster +
MatchupResolver + CombatResolution epics — these four together compose the
playable core loop that closes the Pre-Production → Production gate.
