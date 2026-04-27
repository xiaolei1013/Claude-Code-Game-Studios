# Story 005: _kill_schedule_for_loop + effective_dps + ticks_to_kill

> **Epic**: combat-resolution
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/combat-resolution.md` §D.4
**Requirements**: TR-combat-007, 010, 011, 025
**Governing ADR**: ADR-0010
**Decision**: `effective_dps = raw_dps * matchup_throughput_factor * hp_bonus_factor` applied per-enemy. `_kill_schedule_for_loop` walks the floor's enemy list, computes `ticks_to_kill = ceili(base_hp / effective_dps)` for each, and returns an ordered list of `(kill_tick, enemy_id, archetype, tier, is_boss)` tuples. `ceili()` guarantees `kill_tick >= 1` always — no tick-0 instant-kill events.

**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] TR-007: `effective_dps(raw_dps, matchup_throughput_factor, hp_bonus_factor)` returns the product
- [ ] TR-010: `_kill_schedule_for_loop(formation, floor, matchup_cache, hp_bonus_factor)` — per-enemy `ceili(base_hp / effective_dps)` integer arithmetic
- [ ] TR-011: returned schedule is `Array[Dictionary]` with int kill_tick fields; zero float intermediates leak into output
- [ ] TR-025: `ceili()` ensures every `kill_tick >= 1`; no events at tick 0 (instant kill rejected by formula floor)

## QA Test Cases

- effective_dps(1.0, 1.5, 1.0) == 1.5; (1.0, 0.67, 0.5) ≈ 0.335
- ticks_to_kill: enemy hp=10, effective_dps=2.5 → ceili(4.0) = 4
- ticks_to_kill: enemy hp=10, effective_dps=10 → ceili(1.0) = 1 (boundary; hits 1, not 0)
- ticks_to_kill: enemy hp=10, effective_dps=11 → ceili(0.909) = 1 (floor of 1, not 0)
- Schedule preserves enemy_list ordering (no reordering)
- Schedule entries' `is_boss` matches source enemy data (TR-028 propagation)

## Test Evidence
**Required**: `tests/unit/combat_resolution/kill_schedule_test.gd`

## Dependencies
- Depends on: Stories 001-004 (value types + cooldown + dps)
- Unlocks: Story 006 (emit_events_in_range walks the schedule)
