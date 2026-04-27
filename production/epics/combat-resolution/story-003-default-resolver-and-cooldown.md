# Story 003: DefaultCombatResolver + action_cooldown_ticks formula

> **Epic**: combat-resolution
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/combat-resolution.md` §D.1
**Requirements**: TR-combat-004, 005, 011, 032
**Governing ADR**: ADR-0010
**Decision**: `DefaultCombatResolver extends CombatResolver` provides production impl. `action_cooldown_ticks(speed) -> int` pre-guards `speed <= 0` returning 1, otherwise `maxi(1, floori(SPEED_BASE / speed))`. Result bounded `[1, SPEED_BASE]` (when speed > SPEED_BASE, formula clamps to 1). All integer arithmetic via `floori()` / `maxi()` / `mini()` — no float intermediates.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `floori()` / `maxi()` / `mini()` are 4.6 integer-returning variants — confirmed in `docs/engine-reference/godot/`.

## Acceptance Criteria

- [ ] TR-004: `class_name DefaultCombatResolver extends CombatResolver` (replaces Sprint 6 stub `default_combat_resolver.gd`)
- [ ] TR-005: `action_cooldown_ticks(speed: int) -> int` — `speed<=0 → 1`; otherwise `maxi(1, floori(SPEED_BASE/speed))`
- [ ] TR-011: zero float intermediates; uses `floori()` / `maxi()` / `mini()` exclusively
- [ ] TR-032: result bounded `[1, SPEED_BASE]`; `speed=99` (above SPEED_BASE) clamps to 1; `speed=0` returns 1; `speed=SPEED_BASE` returns 1; `speed=1` returns SPEED_BASE

## QA Test Cases

- `action_cooldown_ticks(0) == 1`; `action_cooldown_ticks(-5) == 1`
- `action_cooldown_ticks(1) == SPEED_BASE` (e.g., 10)
- `action_cooldown_ticks(SPEED_BASE) == 1`
- `action_cooldown_ticks(99) == 1` (clamped)
- `action_cooldown_ticks(2) == floori(10/2) == 5`
- Returned value type is `int` (not float)

## Test Evidence
**Required**: `tests/unit/combat_resolution/cooldown_formula_test.gd`

## Dependencies
- Depends on: Story 001 (CombatResolver base), Story 002 (combat_config.tres)
- Unlocks: Stories 004, 005, 006 (consume cooldown)
