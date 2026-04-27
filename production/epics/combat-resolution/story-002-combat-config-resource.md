# Story 002: combat_config.tres tuning constants

> **Epic**: combat-resolution
> **Status**: Complete
> **Layer**: Feature
> **Type**: Config/Data
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/combat-resolution.md` §G
**Requirements**: TR-combat-031
**Governing ADR**: ADR-0010 + ADR-0013 (single-source-of-truth tuning)
**Decision**: All combat tuning values live in `assets/data/combat_config.tres` — `SPEED_BASE`, `MATCHUP_THROUGHPUT_FACTOR_ADV`, `MATCHUP_THROUGHPUT_FACTOR_DIS`, `LOSING_RUN_LOOT_FACTOR`. No hardcoded values in resolver code (Story 003+ reads from `_config`).

**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] TR-031: `assets/data/combat_config.tres` exists; loaded via DataRegistry `config` category
- [ ] `class_name CombatConfig extends GameData` resource at `src/gameplay/combat/combat_config.gd` with `@export` fields: `SPEED_BASE: int`, `MATCHUP_THROUGHPUT_FACTOR_ADV: float`, `MATCHUP_THROUGHPUT_FACTOR_DIS: float`, `LOSING_RUN_LOOT_FACTOR: float`
- [ ] `_validate() -> Array[String]` per ADR-0011 returns empty Array on default values; non-empty on out-of-range
- [ ] Defaults match GDD §G: `SPEED_BASE=10`, `MATCHUP_THROUGHPUT_FACTOR_ADV=1.5`, `MATCHUP_THROUGHPUT_FACTOR_DIS=0.67`, `LOSING_RUN_LOOT_FACTOR=0.5`
- [ ] No hardcoded copies of these values in `combat_resolver.gd` or subclasses (verified via source grep, similar to TR-030 in matchup-resolver Story 008)

## Implementation Notes
Mirror EconomyConfig (Sprint 2) and RosterConfig (S6-M3) precedents. `_validate()` enforces `SPEED_BASE >= 1`, `1.0 <= MATCHUP_THROUGHPUT_FACTOR_ADV <= 3.0`, `0.1 <= MATCHUP_THROUGHPUT_FACTOR_DIS < 1.0`, `0.0 <= LOSING_RUN_LOOT_FACTOR <= 1.0`.

## Test Evidence
**Required**: `tests/unit/combat_resolution/combat_config_test.gd` + smoke check confirming `.tres` loads cleanly.

## Dependencies
- Depends on: ADR-0011 + ADR-0013 (precedent established by EconomyConfig + RosterConfig)
- Unlocks: Stories 003-010 (all formulas read from `_config`)
