# Story 007: Boot validation order + orphan handling + last-write-wins

> **Epic**: hero-roster
> **Status**: Complete (system shipped; see systems-index Implementation Status #9. Test evidence: `tests/{unit,integration}/hero_roster/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/hero-roster.md`
**Requirements**: TR-hero-roster-015, TR-hero-roster-016, TR-hero-roster-025

**Governing ADR(s)**: ADR-0012 (Hero Roster Mutation + Identity)
**ADR Decision Summary**: After `load_save_data()` populates `_heroes`, boot validation runs in this exact order: (1) resolve class_ids — drop heroes whose class_id is unknown to DataRegistry; (2) clear stale formation slots — slots referencing removed/orphaned heroes set to 0; (3) trim over-cap — if size > MAX_ROSTER_SIZE, preserve the lowest instance_ids and drop the rest; (4) repair _next_instance_id — `_next_instance_id = max(_next_instance_id, max(_heroes.keys()) + 1)`. Orphaned heroes (dropped in step 1) appended to session-scoped `_orphaned_heroes` list. SaveLoadSystem surfaces a single non-blocking notice via signal. Duplicate instance_id in save = last-written-wins (Dictionary semantics); push_error logged but no crash.

**Engine**: Godot 4.6 | **Risk**: LOW (deterministic ordering)

**Control Manifest Rules**:
- **Required**: Boot validation order: resolve class_ids → clear stale formation slots → trim over-cap (preserve lowest ids) → repair _next_instance_id. — TR-015
- **Required**: Orphans appended to _orphaned_heroes; non-blocking notice. — TR-016
- **Required**: Duplicate id = last-write-wins; push_error logged. — TR-025

---

## Acceptance Criteria

- [ ] TR-hero-roster-015: Boot validation runs the 4 steps in exact order after load_save_data
- [ ] TR-hero-roster-016: Orphaned heroes (unresolvable class_id) appended to session-only `_orphaned_heroes` list; SaveLoadSystem fires single notice signal
- [ ] TR-hero-roster-025: Duplicate instance_id in save dict → last-written-wins (Dictionary `_heroes[id] = instance` semantics); push_error logged; no crash
- [ ] Signals remain SUPPRESSED across the entire boot validation pass (Story 006 sets flag; this story consumes it)

---

## Implementation Notes

Add `_validate_after_load()` method called at the end of `load_save_data` BEFORE `_suppress_signals = false`:

```gdscript
func _validate_after_load() -> void:
    # Step 1: resolve class_ids; drop unresolvable
    _orphaned_heroes.clear()
    var to_remove: Array[int] = []
    for id in _heroes:
        var instance: HeroInstance = _heroes[id]
        if DataRegistry.resolve("classes", instance.class_id) == null:
            push_warning("[HeroRoster] orphan hero id=%d class_id='%s' unresolvable" % [id, instance.class_id])
            _orphaned_heroes.append(instance)
            to_remove.append(id)
    for id in to_remove:
        _heroes.erase(id)
    # Step 2: clear stale formation slots
    for i in range(_formation_slots.size()):
        if _formation_slots[i] != 0 and not _heroes.has(_formation_slots[i]):
            push_warning("[HeroRoster] formation slot %d cleared (orphan id=%d)" % [i, _formation_slots[i]])
            _formation_slots[i] = 0
    # Step 3: trim over-cap (preserve lowest ids)
    if _heroes.size() > MAX_ROSTER_SIZE:
        var sorted_ids: Array = _heroes.keys()
        sorted_ids.sort()
        for id_to_drop in sorted_ids.slice(MAX_ROSTER_SIZE):
            push_warning("[HeroRoster] trimming over-cap id=%d" % id_to_drop)
            _heroes.erase(id_to_drop)
    # Step 4: repair _next_instance_id
    if _heroes.size() > 0:
        var max_id: int = _heroes.keys().max()
        _next_instance_id = max(_next_instance_id, max_id + 1)
    # else: _next_instance_id stays at whatever load_save_data set
```

For TR-025 last-write-wins: when iterating `heroes_arr` in `load_save_data`, the assignment `_heroes[instance.instance_id] = instance` naturally overwrites duplicates (Dictionary semantics). Add a duplicate detection counter:
```gdscript
var seen_ids: Dictionary = {}
for hero_dict in heroes_arr:
    var instance: HeroInstance = HeroInstance.new()
    instance.from_dict(hero_dict)
    if seen_ids.has(instance.instance_id):
        push_error("[HeroRoster] duplicate instance_id %d in save (last-write-wins)" % instance.instance_id)
    seen_ids[instance.instance_id] = true
    _heroes[instance.instance_id] = instance
```

Add a single notice signal on SaveLoadSystem (or HeroRoster) — `orphan_heroes_notice(count: int)` — emitted once after validation if `_orphaned_heroes.size() > 0`. Subscribers (HUD) display non-blocking message: "N heroes from a previous version are no longer playable." Coordinated with Save/Load notice contract.

---

## Out of Scope

- Story 008: first-launch seeding (separate path; doesn't go through load_save_data)
- Re-recovery of orphan heroes (V1.0)

---

## QA Test Cases

- **AC TR-015 step order**: validation runs in exact 4-step order
  - Given: save dict with one hero having unresolvable class_id, formation slot referencing that hero, and _next_instance_id=2
  - When: load_save_data → _validate_after_load
  - Then: hero dropped (step 1) → formation slot cleared (step 2) → no trim needed (step 3, only 1 hero) → _next_instance_id stays 2 (step 4); _orphaned_heroes has 1 entry
- **AC TR-016 orphan tracking**: unresolvable class_ids tracked
  - Given: save with 3 heroes; 1 has class_id "warrior" (resolvable), 2 have class_id "ghost_class" (unresolvable)
  - When: load_save_data
  - Then: _heroes.size() == 1; _orphaned_heroes.size() == 2; orphan_heroes_notice signal fired exactly once with count=2
- **AC TR-015 trim**: over-cap roster trimmed preserving lowest ids
  - Given: save with 35 heroes (ids 1..35); MAX_ROSTER_SIZE=30
  - When: load_save_data
  - Then: _heroes has ids 1..30; ids 31..35 dropped; _next_instance_id stays 36 (preserved monotonic)
- **AC TR-015 next_instance_id repair**: _next_instance_id always > max(ids)
  - Given: save with hero ids [5, 10, 20]; next_instance_id=2 (artificially low)
  - When: load_save_data → _validate_after_load
  - Then: _next_instance_id == 21 (max(20)+1)
- **AC TR-025 duplicate id**: last-write-wins; push_error logged
  - Given: save dict.heroes contains two entries with instance_id=5 (different display_names "First" and "Second")
  - When: load_save_data
  - Then: _heroes[5].display_name == "Second" (last write); push_error logged with "duplicate instance_id 5"; no crash
- **AC signal suppression across boot**: zero signal emissions during full load + validate cycle
  - Given: signal spies for all 3 signals
  - When: load_save_data with 5 heroes (all resolvable) → validation runs
  - Then: spy_recruited.size() == 0; spy_leveled.size() == 0; spy_removed.size() == 0 (even though heroes were added to _heroes during load)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/hero_roster/boot_validation_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (HeroRoster + state), Story 006 (load_save_data populates _heroes; sets _suppress_signals). Requires DataRegistry from Sprint 1.
- **Unlocks**: Story 008 (first-launch seed needs validated invariants); end-of-feature integration testing
