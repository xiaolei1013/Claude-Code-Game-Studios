# Story 006: emit_events_in_range (foreground entry point)

> **Epic**: combat-resolution
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/combat-resolution.md` §C.3
**Requirements**: TR-combat-002, 014, 026, 029
**Governing ADR**: ADR-0010
**Decision**: `emit_events_in_range(snapshot, tick_lo, tick_hi) -> CombatTickEvents` — pure function. Walks the kill schedule, emits `KillEvent` per enemy whose `kill_tick ∈ (tick_lo, tick_hi]` (half-open). Tracks `loop_completed_ticks` (when all enemies in a loop are dead → loop completes; counter increments). Sets `first_clear_in_range = true` if a floor-clear lands inside this window. Closed-form schedule is **time-anchored** — clock-rewind / frame-drop recovers via the range arg (TR-026).

**Engine**: Godot 4.6 | **Risk**: MEDIUM (load-bearing for foreground tick cadence)

## Acceptance Criteria

- [ ] TR-002 + TR-029: `emit_events_in_range(snapshot, tick_lo, tick_hi) -> CombatTickEvents` — synchronous, pure-function; Combat does NOT subscribe to `tick_fired` (Orchestrator invokes within `_on_tick`)
- [ ] TR-014: returns CombatTickEvents with `kills`, `loop_completed_ticks`, `first_clear_in_range`
- [ ] TR-026 clock-rewind: calling with `(tick_lo=100, tick_hi=200)` then `(tick_lo=80, tick_hi=200)` produces same kills + warns "rewind detected" (subset of full-range result)
- [ ] Half-open range: kill at exactly `tick_hi` IS included; kill at exactly `tick_lo` is NOT included (already emitted in prior call)

## QA Test Cases

- `emit_events_in_range(snap, 0, 10)` returns kills with `1 <= kill_tick <= 10`
- `emit_events_in_range(snap, 10, 20)` returns kills with `11 <= kill_tick <= 20` (no overlap with prior call)
- Loop completion: schedule of 3 enemies with kill_ticks [3, 5, 8] in range (0, 10] → `loop_completed_ticks == [8]`
- first_clear: 5-loop floor → first_clear_in_range true only on the loop that completes the floor
- Clock-rewind: calling with descending range produces a push_warning + safe re-emission

## Test Evidence
**Required**: `tests/unit/combat_resolution/emit_events_in_range_test.gd`

## Dependencies
- Depends on: Stories 001-005 (snapshot, schedule, formulas)
- Unlocks: Story 007 (offline batch parity test compares to this)
