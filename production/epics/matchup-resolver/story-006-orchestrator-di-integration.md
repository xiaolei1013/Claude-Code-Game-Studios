# Story 006: Orchestrator DI integration + spy-subclass test pattern

> **Epic**: matchup-resolver
> **Status**: Complete (system shipped; see systems-index Implementation Status #10. Test evidence: `tests/{unit,integration}/matchup_resolver/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/class-vs-enemy-matchup-resolver.md`
**Requirements**: TR-matchup-resolver-004, 026, 032

**Governing ADR**: ADR-0009 + ADR-0003 Amendment #3
**Decision Summary**: DungeonRunOrchestrator uses lazy-default-with-public-setters per ADR-0003 Amendment #3. The setter `set_matchup_resolver(spy)` runs BEFORE `_ready()` for tests; lazy-default `DefaultMatchupResolver.new()` inside `_ready()` for production. Test spies use the spy-subclass pattern: `class TestSpyResolver extends MatchupResolver` overrides `resolve_*` methods. Orchestrator emits `enemy_killed(tier: int, is_matchup_advantaged: bool)` to Economy after each kill — the resolver itself exposes no signals.

**Engine**: Godot 4.6 | **Risk**: LOW (already partially wired in S6-M8)

**Control Manifest Rules**:
- Required: `set_matchup_resolver(r)` accepts any RefCounted subclass of MatchupResolver. — TR-004
- Required: lazy-default in `_ready()` — when no spy injected, `_matchup_resolver = DefaultMatchupResolver.new()`. — TR-004
- Required: `enemy_killed(tier, is_matchup_advantaged)` signal owned by Orchestrator (NOT by resolver). — TR-026
- Required: spy-subclass test pattern documented + applied to ≥1 test. — TR-032

---

## Acceptance Criteria

- [ ] TR-004: orchestrator's `_matchup_resolver` is `DefaultMatchupResolver` after _ready when no spy injected (replaces Sprint 6 stub once Story 002 ships the production class).
- [ ] TR-004: spy injected via `set_matchup_resolver(spy)` BEFORE add_child / _ready survives intact (no overwrite by lazy-default).
- [ ] TR-026: orchestrator declares `signal enemy_killed(tier: int, is_matchup_advantaged: bool)`; emitted from kill-processing loop (Story 003+ in dungeon-run-orchestrator epic).
- [ ] TR-026: `MatchupResolver` source grep — zero `signal ` declarations in resolver files (resolver is signal-free).
- [ ] TR-032: spy-subclass test pattern — `class TestSpyResolver extends MatchupResolver` overrides `resolve_formation_matchup` to return canned values; tests use this to assert orchestrator calls the resolver with expected args.

---

## Implementation Notes

The orchestrator scaffolding is already in place from S6-M8:
- `_matchup_resolver: RefCounted = null` field
- `set_matchup_resolver(r)` setter
- `_ready()` lazy-default `DefaultMatchupResolverScript.new()`

This story:
1. Replaces the Sprint 6 stub `default_matchup_resolver.gd` with the production impl from Story 002.
2. Adds the `enemy_killed` signal to the orchestrator (declared on Orchestrator, not on the resolver).
3. Documents and uses the spy-subclass pattern in at least one test.

```gdscript
# tests/integration/matchup_resolver/spy_subclass_pattern_test.gd
class TestSpyResolver extends MatchupResolver:
    var call_count := 0
    var canned_result: MatchupResult = null
    func resolve_formation_matchup(formation: Array, archetype: String) -> MatchupResult:
        call_count += 1
        return canned_result if canned_result else MatchupResult.new()
```

---

## Out of Scope

- The orchestrator's actual kill-processing loop (lives in `dungeon-run-orchestrator/story-006-kill-attribution-and-signals.md`).
- Economy's consumption of the `enemy_killed` signal (lives in economy epic).

---

## QA Test Cases

- **TR-004 lazy-default**: build orchestrator with no injection → `_matchup_resolver is DefaultMatchupResolver`
- **TR-004 spy survives**: `set_matchup_resolver(spy)` then `add_child(orch)` → `_matchup_resolver === spy`
- **TR-026 signal arity**: orchestrator declares `enemy_killed(tier: int, is_matchup_advantaged: bool)` — verified via `get_signal_list`
- **TR-026 resolver signal-free**: `MatchupResolver` + `DefaultMatchupResolver` source grep → zero `signal ` declarations
- **TR-032 spy-subclass works**: spy returns canned MatchupResult; orchestrator dispatch invokes it; spy.call_count > 0

---

## Test Evidence

**Story Type**: Integration
**Required**: `tests/integration/matchup_resolver/orchestrator_di_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001-002 (resolver + production impl); dungeon-run-orchestrator Stories 002-003 (DI scaffolding + dispatch — Complete in S6)
- Unlocks: Story 007 (Economy consumer wiring); dungeon-run-orchestrator Story 006 (kill attribution)
