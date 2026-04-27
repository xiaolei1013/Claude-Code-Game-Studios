# Story 001: CombatResolver base + 4 value types + equals() pattern

> **Epic**: combat-resolution
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/combat-resolution.md`
**Requirements**: TR-combat-001, 013, 014, 015, 016, 017, 028
**Governing ADR**: ADR-0010 (Combat Resolver Snapshot + Parity)
**Decision**: `class_name CombatResolver extends RefCounted` — stateless instance; zero vars / signals / caches / RNG. Companion value types (each `extends RefCounted`): `KillEvent` (5 fields + equals), `CombatTickEvents` (3 fields + equals), `CombatBatchResult` (7 fields + equals), `CombatRunSnapshot` (snapshot for replay). All implement `equals()` for field-by-field comparison.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `extends RefCounted` lifetime automatic. Typed Dictionary (`Dictionary[StringName, int]`) requires Godot 4.4+ — already on 4.6.

## Acceptance Criteria

- [ ] TR-001: `class_name CombatResolver extends RefCounted` at `src/gameplay/combat/combat_resolver.gd`; zero class-scope vars/signals
- [ ] TR-013: `KillEvent` with `enemy_id: StringName, archetype: StringName, tier: int, is_boss: bool, kill_tick: int` + `equals()` deep-equality
- [ ] TR-014: `CombatTickEvents` with `kills: Array[KillEvent], loop_completed_ticks: Array[int], first_clear_in_range: bool` + `equals()`
- [ ] TR-015: `CombatBatchResult` with `kills_by_archetype: Dictionary[StringName, int], kills_by_tier: Dictionary[int, int], loops_completed: int, first_clear_tick: int, hp_bonus_factor: float, survived: bool, final_tick: int` + `equals()`
- [ ] TR-016: Dictionary equality via key-by-key `dict_equals` walk (NOT `==` hash-based)
- [ ] TR-017: float fields compared via `is_equal_approx`; typed dicts engine-checked at assignment
- [ ] TR-028: `is_boss` flag propagates per-event regardless of queue position

## Implementation Notes
Each value type lives in its own file (`kill_event.gd`, `combat_tick_events.gd`, `combat_batch_result.gd`) following project convention. `CombatResolver` base has no method bodies (Default impl in Story 003).

## QA Test Cases
- `KillEvent.new()` defaults; `equals()` returns true for field-equal, false otherwise
- Reference-different but field-equal CombatBatchResult → `equals()` true; `==` false
- Float field equality test uses `is_equal_approx` not `==`

## Test Evidence
**Required**: `tests/unit/combat_resolution/value_types_and_equals_test.gd`

## Dependencies
- Depends on: None (foundational class declarations)
- Unlocks: All combat stories
