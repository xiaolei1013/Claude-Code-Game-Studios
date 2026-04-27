# Story 003: resolve_floor_matchup + edge-case error guards

> **Epic**: matchup-resolver
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/class-vs-enemy-matchup-resolver.md`
**Requirements**: TR-matchup-resolver-009, 015, 018, 019

**Governing ADR**: ADR-0009
**Decision Summary**: `resolve_floor_matchup(formation, floor_archetypes) -> MatchupResult` aggregates over a list of archetypes (caller dedupes upstream). Empty/null `enemy_archetype` calls `push_error` containing `"empty or null enemy_archetype"`. Unknown / V1.0 / garbage archetype returns `{false, []}` silently. Formation MUST be a frozen dispatch snapshot, never a live HeroRoster read.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: `resolve_floor_matchup` aggregates per-archetype results into a single `MatchupResult` (caller dedupes input). — TR-009
- Required: formation parameter is the frozen dispatch snapshot — verified by no `HeroRoster.get_formation_heroes()` call inside the resolver. — TR-015
- Required: empty/null enemy_archetype → `push_error("empty or null enemy_archetype")` + `{false, []}`. — TR-018
- Required: unknown archetype → `{false, []}` silently (no push_warning, no error). — TR-019

---

## Acceptance Criteria

- [ ] TR-009: `resolve_floor_matchup(formation: Array, floor_archetypes: Array[String]) -> MatchupResult`.
- [ ] TR-015: resolver source contains zero references to `HeroRoster` (formation is frozen, passed in).
- [ ] TR-018: empty string or null `enemy_archetype` → push_error logged with substring `"empty or null enemy_archetype"`; result `{false, []}`.
- [ ] TR-019: garbage archetype (e.g., `"v1_dragonkin"`) → silent `{false, []}` with NO push_error / push_warning.

---

## Implementation Notes

```gdscript
func resolve_floor_matchup(formation: Array, floor_archetypes: Array[String]) -> MatchupResult:
    var aggregate := MatchupResult.new()
    var matched: Array[String] = []
    for archetype in floor_archetypes:
        var per := resolve_formation_matchup(formation, archetype)
        if per.is_advantaged:
            aggregate.is_advantaged = true
        for s in per.matched_archetypes:
            if not matched.has(s):
                matched.append(s)
    matched.sort()
    aggregate.matched_archetypes = matched
    return aggregate

# Override resolve_formation_matchup to add the empty/null guard:
func resolve_formation_matchup(formation: Array, enemy_archetype: String) -> MatchupResult:
    if enemy_archetype == null or enemy_archetype.is_empty():
        push_error("MatchupResolver: empty or null enemy_archetype")
        return MatchupResult.new()
    return super.resolve_formation_matchup(formation, enemy_archetype)  # Story 002 body
```

The `null` check is defensive — String type in GDScript can't truly hold null, but the concatenated guard `== null or .is_empty()` survives Variant-typed arguments.

---

## Out of Scope

- Story 005: determinism + offline-replay snapshot integrity
- Story 008: perf bench, structural lint, MatchupResult equality test pattern

---

## QA Test Cases

- **AC TR-009**: floor with `[bruiser, caster, armored]` + 2 warriors + 1 mage → returns `is_advantaged = true` if either bruiser or caster majority is met
- **AC TR-018 empty**: `resolve_formation_matchup(formation, "")` → push_error logged; returns `{false, []}`
- **AC TR-019 unknown**: `resolve_formation_matchup(formation, "v1_dragonkin")` → silent `{false, []}` (no error/warning)
- **AC TR-015 source-grep**: `matchup_resolver.gd` and `default_matchup_resolver.gd` contain zero references to `HeroRoster`

---

## Test Evidence

**Story Type**: Logic
**Required**: `tests/unit/matchup_resolver/floor_matchup_and_guards_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (resolve_formation_matchup)
- Unlocks: Story 005 (determinism), Story 007 (Economy/Combat consumer wiring)
