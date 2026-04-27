# Story 004: formation_dps + hp_bonus_factor + survived/losing_run

> **Epic**: combat-resolution
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/combat-resolution.md` §D.2 + §D.3
**Requirements**: TR-combat-006, 008, 009
**Governing ADR**: ADR-0010
**Decision**: `formation_dps_per_tick = sum(hero.attack * hero.speed) / SPEED_BASE`; output range `[0.0, 2.31]`. `hp_bonus_factor = mini(formation_total_hp / floor_total_enemy_attack, 1.0)`; continuous `[0.0, 1.0]`. `survived := (hp_bonus_factor >= 0.5)` (inclusive boundary); `losing_run = !survived` — explicit bool, NOT re-derived on save/load (per ADR-0014 §B4).

**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] TR-006: `formation_dps_per_tick(formation: Array, snapshot) -> float` — sum(attack×speed) / SPEED_BASE
- [ ] TR-006 range: with MVP heroes (attack ≤ 11, speed ≤ 7, FORMATION_SIZE=3), output ≤ 2.31
- [ ] TR-008: `hp_bonus_factor(formation_total_hp: int, floor_total_enemy_attack: int) -> float` — `mini(hp/atk, 1.0)`; clamps to 1.0 ceiling
- [ ] TR-008 range: continuous `[0.0, 1.0]`; never > 1.0
- [ ] TR-009 boundary: `hp_bonus_factor == 0.5` → `survived == true` (inclusive); `hp_bonus_factor == 0.4999` → `survived == false`
- [ ] TR-009: `losing_run = not survived`; persisted as explicit bool in `RunSnapshot` per ADR-0014 §B4

## QA Test Cases

- DPS calc: 3 heroes (5×4 + 6×3 + 4×7) / 10 = 6.6 → matches expected
- hp_bonus_factor of 0.5 → survived true (boundary inclusive)
- hp_bonus_factor of 0.4999... → survived false
- hp_bonus_factor clamps to 1.0 when hp >> atk (e.g., 1000 / 100 → 1.0 not 10.0)
- Empty formation → DPS == 0.0

## Test Evidence
**Required**: `tests/unit/combat_resolution/dps_and_hp_formulas_test.gd`

## Dependencies
- Depends on: Stories 001-003 (base + cooldown + config)
- Unlocks: Story 005 (kill schedule consumes effective_dps)
