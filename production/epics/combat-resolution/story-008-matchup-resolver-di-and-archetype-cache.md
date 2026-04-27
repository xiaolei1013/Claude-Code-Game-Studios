# Story 008: MatchupResolver DI + per-archetype call optimization

> **Epic**: combat-resolution
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/combat-resolution.md` §D.5
**Requirements**: TR-combat-004, 012, 030
**Governing ADR**: ADR-0010 + ADR-0009 (Matchup Resolver DI)
**Decision**: Combat consumes `MatchupResolver` as a constructor-injected dependency. To minimize resolver calls, Combat invokes `MatchupResolver.resolve_formation_matchup(formation, archetype)` **once per distinct enemy_list entry** (≤5 per MVP floor) and caches the result in the snapshot's `matchup_cache: Dictionary[StringName, bool]`. The matchup `bool` flips Economy's `1.0 → 1.5 (MATCHUP_GOLD_MULTIPLIER)` and Combat's `MATCHUP_THROUGHPUT_FACTOR_ADV/DIS`. Combat emits no signals (TR-030) — Orchestrator owns all kill-event signal routing.

**Engine**: Godot 4.6 | **Risk**: LOW

## Acceptance Criteria

- [ ] TR-004: `DefaultCombatResolver` accepts `MatchupResolver` via DI setter (replaces Sprint 6 stub `set_matchup_resolver` test seam — already wired in S6-M8)
- [ ] TR-012: `resolve_formation_matchup` called exactly once per distinct archetype in `floor.enemy_list` (≤5 calls per MVP floor); subsequent uses hit `matchup_cache`
- [ ] TR-030: `combat_resolver.gd` and `default_combat_resolver.gd` source — zero `signal ` declarations
- [ ] Spy-subclass test: spy MatchupResolver counts `resolve_formation_matchup` calls; for a floor with 3 distinct archetypes, count == 3

## QA Test Cases

- 5-distinct-archetype floor → spy resolver call_count == 5
- 5-enemy floor with all-same archetype → spy call_count == 1
- Empty floor → call_count == 0
- Cached hit returns same `is_advantaged` bool as the original resolve
- Source grep both files for `signal ` → 0 hits

## Test Evidence
**Required**: `tests/integration/combat_resolution/matchup_di_and_cache_test.gd`

## Dependencies
- Depends on: Stories 001-007 (resolver pipeline complete); matchup-resolver Story 002+ (production resolver; or use spy)
- Unlocks: Sprint 7+ Vertical Slice gold flow
