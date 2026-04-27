# Story 001: MatchupResolver base class + MatchupResult value type

> **Epic**: matchup-resolver
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/class-vs-enemy-matchup-resolver.md`
**Requirements**: TR-matchup-resolver-001, 002, 005, 006, 007, 030 (partial)

**Governing ADR**: ADR-0009 (Matchup Resolver DI + Majority Threshold)
**Decision Summary**: `class_name MatchupResolver extends RefCounted` — instance class, NOT autoload, NOT static-only. Stateless: zero class-scope vars / signals / caches. Subclasses (Default + spies) provide the public methods. Companion `MatchupResult` value type holds `is_advantaged: bool` + `matched_archetypes: Array[String]`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `extends RefCounted` lifetime is automatic; never `.free()` resolver instances. Established pattern from S4-N3 `is_class_counter` test scaffolding.

**Control Manifest Rules (Feature Layer)**:
- Required: `class_name MatchupResolver extends RefCounted`. — TR-001
- Required: instance methods only — no `static func` on the public API. — TR-002
- Required: zero class-scope `var` declarations. — TR-005, TR-030
- Required: zero `signal` declarations on the resolver. — TR-005, TR-030
- Required: `MatchupResult` value type with exactly 2 public fields (`is_advantaged: bool`, `matched_archetypes: Array[String]`). — TR-006
- Forbidden: `matched_archetypes` containing HeroInstance refs or instance_id ints. — TR-007

---

## Acceptance Criteria

- [ ] TR-001: `MatchupResolver` declared with `class_name MatchupResolver extends RefCounted` in `src/core/matchup_resolver/matchup_resolver.gd`
- [ ] TR-002: methods are regular `func` (not `static func`); class is instantiable via `MatchupResolver.new()`
- [ ] TR-005 / TR-030: zero class-scope vars, zero signals (verified via source grep)
- [ ] TR-006: `MatchupResult` value type at `src/core/matchup_resolver/matchup_result.gd`; 2 public fields with named types; extends RefCounted
- [ ] TR-007: `matched_archetypes` typed as `Array[String]` — compile-time exclusion of HeroInstance / int payloads

---

## Implementation Notes

```gdscript
# src/core/matchup_resolver/matchup_resolver.gd
class_name MatchupResolver extends RefCounted
# Base class — no fields, no signals, no implementations.
# Concrete impls (DefaultMatchupResolver, test spies) override resolve_*.

# src/core/matchup_resolver/matchup_result.gd
class_name MatchupResult extends RefCounted
var is_advantaged: bool = false
var matched_archetypes: Array[String] = []
```

Subclasses provide `resolve_formation_matchup` and `resolve_floor_matchup` (Stories 002–003). The base class deliberately defines no method bodies — Godot 4 lacks `@abstract` on RefCounted, so the base is "interface by convention" enforced via code review + the structural CI check (Story 008).

---

## Out of Scope

- Story 002: `DefaultMatchupResolver` + `_is_class_counter` + `resolve_formation_matchup`
- Story 003: `resolve_floor_matchup` + error guards
- Story 008: structural CI lint + perf bench + MatchupResult equality test pattern

---

## QA Test Cases

- **AC TR-001**: instance constructor
  - Given: clean test env
  - When: `MatchupResolver.new()` called
  - Then: returns RefCounted instance; `is RefCounted` true; class_name resolves
- **AC TR-005 / TR-030**: structural shape
  - Given: `matchup_resolver.gd` source loaded
  - When: source grepped for `^var ` and `^signal `
  - Then: zero matches outside doc-comments
- **AC TR-006**: MatchupResult schema
  - Given: `MatchupResult.new()` instance
  - When: `is_advantaged` and `matched_archetypes` accessed
  - Then: types match `bool` and `Array[String]`; defaults are `false` and `[]`
- **AC TR-007**: typed Array[String] enforcement
  - Given: MatchupResult instance
  - When: `matched_archetypes.append(123)` (an int) attempted
  - Then: GDScript runtime raises type error (Array[String] guard)

---

## Test Evidence

**Story Type**: Logic
**Required**: `tests/unit/matchup_resolver/matchup_resolver_base_and_result_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (foundational class declarations)
- Unlocks: Stories 002-008 (all reference MatchupResolver + MatchupResult)
