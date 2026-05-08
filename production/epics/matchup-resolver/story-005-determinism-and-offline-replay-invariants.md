# Story 005: Determinism + offline-replay invariants

> **Epic**: matchup-resolver
> **Status**: Complete (system shipped; see systems-index Implementation Status #10. Test evidence: `tests/{unit,integration}/matchup_resolver/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/class-vs-enemy-matchup-resolver.md` + `design/gdd/dungeon-run-orchestrator.md` §F (offline parity)
**Requirements**: TR-matchup-resolver-021, 022, 023, 024, 025, 029

**Governing ADR**: ADR-0009 + ADR-0014 (RunSnapshot Schema)
**Decision Summary**: Pure-function determinism — identical inputs always yield field-equal `MatchupResult` (Pillar 1 offline replay). Offline Engine calls `resolve_floor_matchup` exactly once at dispatch; replay uses `snapshot.matched_archetypes.has(archetype)` lookup. Snapshot stores `MatchupResult` + `class_ids` Array — NOT live HeroInstance refs (per ADR-0012). Frozen `floor_archetypes` at dispatch — never re-derived from live `Floor.enemy_list`. **During offline replay, `DataRegistry.resolve` AND `MatchupResolver.*` call counts MUST be exactly 0.**

**Engine**: Godot 4.6 | **Risk**: LOW (pure-function invariant)

**Control Manifest Rules**:
- Required: `resolve_*` methods are deterministic — same inputs produce field-equal output. — TR-021
- Required: snapshot stores frozen `class_ids` + `MatchupResult` — never live HeroInstance refs. — TR-023, ADR-0012
- Required: snapshot freezes `floor_archetypes` at dispatch. — TR-025
- Required: zero DataRegistry / MatchupResolver calls during offline replay. — TR-024
- Required: empty-formation guard is a backstop (Formation Assignment precondition prevents reaching here). — TR-029
- Forbidden: re-deriving `floor_archetypes` from `Floor.enemy_list` at replay time.

---

## Acceptance Criteria

- [ ] TR-021: 1000-iteration determinism test — same `(formation, archetype)` produces field-equal MatchupResult on every call.
- [ ] TR-022: Offline replay code path uses `snapshot.matched_archetypes.has(archetype)` for the per-kill matchup lookup (no resolver call).
- [ ] TR-023: `RunSnapshot.formation_snapshot` (or sibling field) stores `Array[String]` of class_ids — verified via source grep that no `HeroInstance` reference is in the snapshot dict.
- [ ] TR-024: A test that runs 100 simulated kills during offline replay records zero `DataRegistry.resolve` AND zero `MatchupResolver.resolve_*` calls (via spy injection counts).
- [ ] TR-025: A test loads a saved snapshot, swaps `Floor.enemy_list` (mutates the live resource), runs replay, asserts the replay used the FROZEN floor_archetypes (not the live mutated list).
- [ ] TR-029: Orchestrator dispatch with empty formation is a backstop — Formation Assignment screen prevents the case earlier; this test confirms the guard returns cleanly.

---

## Implementation Notes

Most of this story is TEST + INFRASTRUCTURE work — the resolver behavior was implemented in Stories 002-003. This story adds:

1. A determinism harness: invoke `resolve_formation_matchup(formation, "bruiser")` 1000 times, assert all results are field-equal (use Story 008's MatchupResult equality helper).

2. An Orchestrator integration test that:
   - Builds a `RunSnapshot` containing `class_ids: Array[String] + matched_archetypes: Array[String]`
   - Simulates 100 kills via the offline-replay path
   - Asserts spy resolver / spy DataRegistry both record 0 calls

3. A snapshot integrity test that mutates a Floor resource between dispatch and replay, asserting replay uses frozen archetypes.

```gdscript
# tests/integration/matchup_resolver/offline_replay_zero_resolve_calls_test.gd
func test_offline_replay_makes_zero_resolver_calls() -> void:
    var spy := SpyMatchupResolver.new()
    DungeonRunOrchestrator.set_matchup_resolver(spy)
    # ... build snapshot, run replay, assert spy.call_count == 0
```

---

## Out of Scope

- The actual resolve_formation_matchup implementation (Story 002).
- The orchestrator's snapshot build logic (out-of-epic; lives in `dungeon-run-orchestrator/story-004`).

---

## QA Test Cases

- **TR-021 determinism**: 1000 calls of same input → 1000 field-equal MatchupResult instances
- **TR-024 zero-call invariant**: 100-kill offline replay → spy resolver call_count == 0; spy DataRegistry call_count == 0
- **TR-025 frozen floor_archetypes**: dispatch with floor archetypes [bruiser, caster] → mutate floor.enemy_list to [armored] → replay → snapshot still uses [bruiser, caster]
- **TR-023 no HeroInstance refs**: source grep `_run_snapshot` for `HeroInstance` → zero hits

---

## Test Evidence

**Story Type**: Integration
**Required**: `tests/integration/matchup_resolver/offline_replay_invariants_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001-004 (resolver + label complete); orchestrator Story 004 (snapshot build)
- Unlocks: combat-resolution Story 005+ (offline replay consumes these invariants)
