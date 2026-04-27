# Story 010: Formation strength + accessors + AC H-14 perf

> **Epic**: hero-roster
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic (with Performance for AC H-14)
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/hero-roster.md`
**Requirements**: TR-hero-roster-017, TR-hero-roster-018, TR-hero-roster-024, TR-hero-roster-026, TR-hero-roster-027

**Governing ADR(s)**: ADR-0012 (Hero Roster Mutation + Identity)
**ADR Decision Summary**: `get_formation_strength() = clamp(1.0 + (avg_formation_level - 1) * 0.2, 1.0, 3.0)`. `avg_formation_level = float(sum(current_level)) / size(formation)` skipping empty slots; empty formation returns 1.0 via guard. `get_all_heroes()` default sort: BY_CLASS (registry order) then BY_LEVEL_DESC tiebreaker. `get_formation_heroes()` skips empty slots; returns ordered by slot index; consumed by Combat / Orchestrator / MatchupResolver. AC H-14 perf: `get_formation_strength` p99 < 50µs on min-spec (Steam Deck 1280×800).

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- **Required**: get_formation_strength formula = clamp(1.0 + (avg_formation_level - 1) * 0.2, 1.0, 3.0). — TR-017
- **Required**: empty formation guards return 1.0. — TR-017
- **Performance Guardrail**: get_formation_strength p99 < 50µs on min-spec. — TR-024 (AC H-14)

---

## Acceptance Criteria

- [ ] TR-hero-roster-017: `get_formation_strength() -> float` = clamp(1.0 + (avg_level - 1) * 0.2, 1.0, 3.0)
- [ ] TR-hero-roster-017: empty formation (all slots 0) returns exactly 1.0 via guard (no division by zero)
- [ ] TR-hero-roster-018: `avg_formation_level = sum(current_level) / non_empty_slot_count`; skips empty slots (id=0)
- [ ] TR-hero-roster-024: AC H-14 — get_formation_strength p99 < 50µs over 1000 calls on dev hardware
- [ ] TR-hero-roster-026: `get_all_heroes()` default sort BY_CLASS (DataRegistry order) then BY_LEVEL_DESC tiebreaker
- [ ] TR-hero-roster-027: `get_formation_heroes() -> Array[HeroInstance]` skips empty slots; ordered by slot index

---

## Implementation Notes

```gdscript
func get_formation_strength() -> float:
    var sum_levels: int = 0
    var non_empty_count: int = 0
    for slot_id in _formation_slots:
        if slot_id == 0:
            continue
        if not _heroes.has(slot_id):
            continue  # defensive (Story 007 should have cleared but guard anyway)
        sum_levels += (_heroes[slot_id] as HeroInstance).current_level
        non_empty_count += 1
    if non_empty_count == 0:
        return 1.0
    var avg: float = float(sum_levels) / float(non_empty_count)
    return clampf(1.0 + (avg - 1.0) * 0.2, 1.0, 3.0)

func get_formation_heroes() -> Array[HeroInstance]:
    var out: Array[HeroInstance] = []
    for slot_id in _formation_slots:
        if slot_id == 0:
            continue
        if not _heroes.has(slot_id):
            continue
        out.append(_heroes[slot_id])
    return out

enum SortMode { BY_CLASS, BY_LEVEL_DESC, BY_INSTANCE_ID }

func get_all_heroes(sort_mode: SortMode = SortMode.BY_CLASS) -> Array[HeroInstance]:
    var out: Array[HeroInstance] = []
    for id in _heroes:
        out.append(_heroes[id])
    match sort_mode:
        SortMode.BY_CLASS:
            out.sort_custom(func(a: HeroInstance, b: HeroInstance) -> bool:
                if a.class_id != b.class_id:
                    return a.class_id < b.class_id  # alphabetic; refine to DataRegistry order if needed
                return a.current_level > b.current_level  # desc tiebreaker
            )
        SortMode.BY_LEVEL_DESC:
            out.sort_custom(func(a: HeroInstance, b: HeroInstance) -> bool:
                return a.current_level > b.current_level
            )
        SortMode.BY_INSTANCE_ID:
            out.sort_custom(func(a: HeroInstance, b: HeroInstance) -> bool:
                return a.instance_id < b.instance_id
            )
    return out
```

For BY_CLASS DataRegistry-order tiebreaker: read DataRegistry's class registration order from the resolved category (or accept alphabetic as a documented MVP simplification — flag if so).

Performance test: pre-populate roster with 30 heroes, fill formation, run `get_formation_strength` 1000 times measuring `Time.get_ticks_usec()` deltas. Compute p99. Assert < 50µs (or document the actual measurement on dev hardware with a note that Steam Deck min-spec verification requires hardware playtest).

---

## Out of Scope

- Combat system consumption of get_formation_strength (Combat epic)
- MatchupResolver consumption of get_formation_heroes (Matchup epic)
- BY_LEVEL_DESC / BY_INSTANCE_ID secondary sort modes (covered as test paths but UI Recruit Screen consumption is Presentation-layer)

---

## QA Test Cases

- **AC TR-017 / TR-018 formula**: 3 heroes at levels [5, 10, 15] → strength = clamp(1.0 + (10-1)*0.2, 1.0, 3.0) = 2.8
  - Given: formation = [hero_l5, hero_l10, hero_l15]
  - When: get_formation_strength()
  - Then: returns 2.8 (within float epsilon)
- **AC TR-017 empty formation**: returns 1.0
  - Given: formation = [0, 0, 0]
  - When: get_formation_strength()
  - Then: returns exactly 1.0
- **AC TR-017 partial formation**: 1 hero at level 15 → avg=15, strength = clamp(1+14*0.2, 1, 3) = 3.0 (capped)
  - Given: formation = [hero_l15, 0, 0]
  - When: get_formation_strength()
  - Then: returns 3.0
- **AC TR-017 clamp lower**: avg below 1 (impossible per LEVEL_CAP=15 floor=1, but defensive)
  - Given: formation = [hero_l1, 0, 0]
  - When: get_formation_strength()
  - Then: returns 1.0 (lower clamp triggers)
- **AC TR-024 perf p99 < 50µs**: 1000-call benchmark
  - Given: full 30-hero roster; formation filled; SETTING current_level varies
  - When: 1000 calls of get_formation_strength measured via Time.get_ticks_usec
  - Then: p99 < 50; mean < 25µs; standard deviation reasonable
- **AC TR-026 BY_CLASS sort**: 3 heroes (warrior l5, mage l10, warrior l15)
  - Given: above heroes added
  - When: get_all_heroes(BY_CLASS)
  - Then: order is [mage_l10, warrior_l15, warrior_l5] OR [warrior_l15, warrior_l5, mage_l10] depending on DataRegistry order; warriors appear adjacent; warrior_l15 before warrior_l5 (level desc tiebreaker)
- **AC TR-027 get_formation_heroes**: skips empty slots; orders by slot index
  - Given: formation = [hero_b, 0, hero_c] (slot 1 empty)
  - When: get_formation_heroes()
  - Then: returns [hero_b, hero_c] (size 2; in slot order; empty slot omitted)

---

## Test Evidence

**Story Type**: Logic (with Performance test for AC H-14)
**Required evidence**:
- Unit: `tests/unit/hero_roster/formation_strength_and_accessors_test.gd` (formula + sort tests)
- Performance: `tests/performance/hero_roster/formation_strength_perf_test.gd` (1000-call p99) — OR include perf assertion in unit test

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (HeroInstance), Story 002 (HeroRoster + state), Story 005 (set_formation_slot to populate test data)
- **Unlocks**: Combat system consumption (Combat epic); MatchupResolver consumption (Matchup epic); Recruit Screen sort UI (Presentation epic)
