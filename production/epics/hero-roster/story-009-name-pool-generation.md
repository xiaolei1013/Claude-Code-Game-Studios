# Story 009: Name pool generation + DataRegistry name_pools category

> **Epic**: hero-roster
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/hero-roster.md`
**Requirements**: TR-hero-roster-022, TR-hero-roster-023

**Governing ADR(s)**: ADR-0012 (Hero Roster Mutation + Identity) + ADR-0011 (Resource Schemas Core Databases — DataRegistry category extension)
**ADR Decision Summary**: When `add_hero(class_id)` succeeds, `_generate_name(class_id)` selects uniformly at random from the unused name pool subset for that class. Pool >=20 names per class (MVP: warrior, mage, rogue). Pools loaded via `DataRegistry.resolve("name_pools", class_id)`. When the unused pool is exhausted (player owns 20+ heroes of the same class), fallback uses `'{base} the {Ordinal}'` pattern (e.g., "Theron the Second"). Pool tracking is per-class within the active session (no save persistence — recompute "used" set from current `_heroes` on each call).

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- **Required**: Pool selection uniform random over unused subset. — TR-022
- **Required**: Pool exhaustion fallback uses "{base} the {Ordinal}". — TR-022
- **Required**: Pool size >= 20 per class for MVP (warrior, mage, rogue). — TR-023
- **Required**: Pool resolution via `DataRegistry.resolve("name_pools", class_id)`. — TR-023

---

## Acceptance Criteria

- [ ] TR-hero-roster-022: `_generate_name(class_id)` uniform random over unused names; never returns a name already used by an existing hero of the same class
- [ ] TR-hero-roster-022: Pool exhaustion fallback returns "{base} the {Ordinal}" (e.g., "Theron the Second", "Theron the Third")
- [ ] TR-hero-roster-023: Each MVP class (warrior, mage, rogue) has >=20 names in its pool .tres
- [ ] TR-hero-roster-023: Pools loaded via `DataRegistry.resolve("name_pools", class_id)`; "name_pools" added to DataRegistry ORDERED_CATEGORIES

---

## Implementation Notes

Create `src/core/hero_roster/name_pool.gd`:
```gdscript
class_name NamePool extends Resource

@export var class_id: String = ""           # e.g., "warrior"
@export var names: Array[String] = []        # >=20 entries
```

Create `assets/data/name_pools/warrior_names.tres`, `mage_names.tres`, `rogue_names.tres` — each with at least 20 names. Author by hand (cozy fantasy aesthetic per Visual Identity Anchor).

Add `"name_pools"` to `data_registry.gd` ORDERED_CATEGORIES (mirrors the Sprint 2 EconomyConfig + Sprint 3 enemies/biomes/dungeons additions).

Implementation:
```gdscript
const ORDINALS: Array[String] = ["Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth"]

func _generate_name(class_id: String) -> String:
    var pool_resource: Resource = DataRegistry.resolve("name_pools", class_id)
    if pool_resource == null:
        push_warning("[HeroRoster] no name_pool for class_id '%s'; using fallback" % class_id)
        return "Hero %d" % _next_instance_id
    var all_names: Array[String] = pool_resource.names
    # Compute used-set: names already in use by heroes of THIS class
    var used: Dictionary = {}
    for id in _heroes:
        var inst: HeroInstance = _heroes[id]
        if inst.class_id == class_id:
            used[inst.display_name] = true
    var unused: Array[String] = []
    for name in all_names:
        if not used.has(name):
            unused.append(name)
    if unused.size() > 0:
        return unused[randi() % unused.size()]
    # Pool exhausted — use ordinal fallback on the first pool name
    var base: String = all_names[0]
    var ordinal_index: int = (used.size() - all_names.size())  # how many beyond pool
    var ordinal: String = ORDINALS[ordinal_index] if ordinal_index < ORDINALS.size() else "the Many"
    return "%s the %s" % [base, ordinal]
```

Story 004 currently uses placeholder `"Hero %d"` for `_generate_name`; this story replaces with the full implementation.

---

## Out of Scope

- Story 008: first-launch "Theron" seed — bypasses name pool entirely (hardcoded)
- Localization of name pools (post-MVP)
- Per-region name variants

---

## QA Test Cases

- **AC TR-022 uniform random**: 100 add_hero calls produce names from the pool with no duplicates until pool exhausted
  - Given: roster with 0 warriors; warrior pool has 20 names
  - When: `add_hero("warrior")` 20 times
  - Then: 20 distinct display_names; each is a member of the warrior pool
- **AC TR-022 ordinal fallback**: 21st warrior triggers ordinal
  - Given: 20 warriors named (pool exhausted)
  - When: `add_hero("warrior")`
  - Then: 21st hero's display_name matches `"%s the Second" % pool[0]` (e.g., "Theron the Second" if pool[0]=="Theron")
- **AC TR-022 ordinal sequence**: 22nd → "Third", 23rd → "Fourth"
- **AC TR-023 pool size**: each MVP class pool has >=20 names
  - Given: name pools loaded
  - When: each pool's `names` array measured
  - Then: warrior_names.size() >= 20; mage_names.size() >= 20; rogue_names.size() >= 20
- **AC TR-023 DataRegistry resolution**: pools resolve via "name_pools" category
  - Given: DataRegistry boot complete
  - When: `DataRegistry.resolve("name_pools", "warrior")` called
  - Then: returns non-null NamePool; `class_id == "warrior"`
- **AC unknown class fallback**: missing pool returns placeholder + push_warning
  - Given: class_id with no pool entry
  - When: `_generate_name("ghost_class")` called
  - Then: returns "Hero N" placeholder; push_warning emitted

---

## Test Evidence

**Story Type**: Integration (DataRegistry coupling)
**Required evidence**: `tests/integration/hero_roster/name_pool_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (HeroRoster skeleton), Story 004 (add_hero placeholder name path). DataRegistry from Sprint 1.
- **Unlocks**: end-to-end roster recruitment flow with proper name aesthetics
