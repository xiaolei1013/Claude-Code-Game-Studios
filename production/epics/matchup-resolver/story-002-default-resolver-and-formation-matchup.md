# Story 002: DefaultMatchupResolver + _is_class_counter + resolve_formation_matchup

> **Epic**: matchup-resolver
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/class-vs-enemy-matchup-resolver.md`
**Requirements**: TR-matchup-resolver-003, 008, 010, 011, 012, 013, 014, 016, 017, 020

**Governing ADR**: ADR-0009 (Matchup Resolver DI + Majority Threshold)
**Decision Summary**: `DefaultMatchupResolver extends MatchupResolver` provides production impl. `resolve_formation_matchup(formation, enemy_archetype) -> MatchupResult` walks heroes, calls `_is_class_counter(class_data, archetype)` for each, applies majority-threshold aggregation (n > N/2 strict), returns deduplicated + alphabetical `matched_archetypes`.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: `_is_class_counter` is private (underscore prefix); uses string equality `class_data.counter_archetype == enemy_archetype`. — TR-010
- Required: aggregation rule `advantaged iff n > N/2` (integer division, strict majority). — TR-011
- Required: crossing threshold yields a single `1.5×` (no per-hero stacking). — TR-012
- Required: `matched_archetypes` deduplicated and sorted alphabetically. — TR-013
- Required: per-kill evaluation model — resolver called once per enemy death. — TR-014
- Required: empty formation returns `{false, []}` immediately (no iteration, no DataRegistry calls). — TR-016
- Required: null `class_data` from DataRegistry silently skipped, excluded from threshold N. — TR-017
- Required: case-sensitive string comparison; no `to_lower` normalization. — TR-020

---

## Acceptance Criteria

- [ ] TR-003: `DefaultMatchupResolver extends MatchupResolver` at `src/core/matchup_resolver/default_matchup_resolver.gd` (replaces Sprint 6 stub).
- [ ] TR-008 + TR-014: Public `resolve_formation_matchup(formation: Array, enemy_archetype: String) -> MatchupResult` returns advantage decision per single enemy archetype.
- [ ] TR-010 + TR-020: Private `_is_class_counter(class_data, enemy_archetype)` performs case-sensitive string equality.
- [ ] TR-011 + TR-012: Threshold logic — 2/3 counters → advantaged; 1/3 → not; 3/3 → still single `1.5×` boost (no stacking).
- [ ] TR-013: `matched_archetypes` deduplicated and sorted alphabetically before return.
- [ ] TR-016: Empty formation → `{is_advantaged: false, matched_archetypes: []}` with zero iteration.
- [ ] TR-017: Null `class_data` (DataRegistry miss) silently excluded from N — all-null formation behaves like empty.

---

## Implementation Notes

```gdscript
class_name DefaultMatchupResolver extends MatchupResolver

func resolve_formation_matchup(formation: Array, enemy_archetype: String) -> MatchupResult:
    var result := MatchupResult.new()
    if formation.is_empty():
        return result
    var n := 0      # eligible-hero count (excludes null class_data)
    var counter_count := 0
    var matched: Array[String] = []
    for hero in formation:
        var class_data: Resource = DataRegistry.resolve("classes", hero.class_id) if hero else null
        if class_data == null:
            continue  # TR-017: silently exclude
        n += 1
        if _is_class_counter(class_data, enemy_archetype):
            counter_count += 1
            matched.append(enemy_archetype)
    # TR-011 strict majority
    result.is_advantaged = counter_count > (n / 2)
    # TR-013 dedup + alphabetical
    matched.sort()
    var deduped: Array[String] = []
    for s in matched:
        if not deduped.has(s):
            deduped.append(s)
    result.matched_archetypes = deduped
    return result

func _is_class_counter(class_data: Resource, enemy_archetype: String) -> bool:
    return str(class_data.get("counter_archetype")) == enemy_archetype  # TR-020 case-sensitive
```

---

## Out of Scope

- Story 003: `resolve_floor_matchup` + edge-case error guards
- Story 005: determinism / offline-replay invariants
- Story 008: structural lint + perf bench

---

## QA Test Cases

- **AC TR-008 / TR-011**: 2/3 warriors vs bruiser → advantaged
- **AC TR-011**: 1/3 warriors vs bruiser → NOT advantaged
- **AC TR-012**: 3/3 warriors vs bruiser → advantaged (single `1.5×`, no stacking)
- **AC TR-013**: matched_archetypes deduplicated + alphabetical
- **AC TR-016**: empty formation → `{false, []}` with zero DataRegistry calls (verify via spy)
- **AC TR-017**: 3 heroes with bad class_ids → behaves as empty formation
- **AC TR-020**: case mismatch (`"Bruiser"` vs `"bruiser"`) → NOT a counter

---

## Test Evidence

**Story Type**: Logic
**Required**: `tests/unit/matchup_resolver/default_resolver_formation_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (MatchupResolver base + MatchupResult value type)
- Unlocks: Story 003 (resolve_floor_matchup builds on resolve_formation_matchup)
