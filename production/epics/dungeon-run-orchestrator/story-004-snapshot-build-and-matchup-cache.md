# Story 004: Formation snapshot deep-copy + floor serialize-by-id + matchup cache build

> **Epic**: dungeon-run-orchestrator
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-004, TR-orchestrator-006, TR-orchestrator-012, TR-orchestrator-013

**Governing ADRs**: ADR-0010 (Combat Resolver Snapshot) + ADR-0014 (RunSnapshot Schema)
**Decision Summary**: At DISPATCHING transition: (1) deep-copy formation via `.duplicate(true)` into `RunSnapshot.formation_snapshot` — never re-read mid-dispatch from HeroRoster; (2) store `floor_id` (string) only — resolve via DataRegistry on load; null floor → NO_RUN reset; (3) pre-populate `matchup_cache` with an entry for every archetype in the floor's kill_schedule — guarantees zero KeyError during replay; (4) matchup_cache built ONCE at DISPATCHING; per-kill replay reads cache; zero resolver calls during offline replay.

**Engine**: Godot 4.6 | **Risk**: MEDIUM

**Control Manifest Rules**:
- Required: formation deep-copy via `.duplicate(true)`. — TR-004
- Required: floor serialized by id only. — TR-006
- Required: matchup cache pre-populated for every archetype. — TR-012
- Required: matchup cache built ONCE at DISPATCHING. — TR-013

---

## Acceptance Criteria

- [ ] TR-004: `RunSnapshot.formation_snapshot` is a deep copy via `.duplicate(true)`; mutations to source HeroRoster do NOT propagate
- [ ] TR-006: `floor_id: String` stored (NOT a Floor reference); resolved via `DataRegistry.resolve("floors", floor_id)` on load; null → NO_RUN
- [ ] TR-012: `_build_matchup_cache(formation, floor)` pre-populates entry for every archetype in `kill_schedule`; no KeyError possible during offline replay
- [ ] TR-013: `_build_matchup_cache` runs ONCE at DISPATCHING; subsequent ticks read from cache (zero resolver calls during replay)

---

## Implementation Notes

```gdscript
func _build_run_snapshot(formation: Array, floor: Floor, biome_id: String) -> RunSnapshot:
    var snap: RunSnapshot = RunSnapshot.new()
    snap.formation_snapshot = formation.duplicate(true) as Dictionary
    snap.floor_id = floor.id  # serialize-by-id
    snap.kill_schedule = floor.kill_schedule.duplicate()
    snap.matchup_cache = _build_matchup_cache(formation, floor)
    snap.losing_run = false  # default; updated on kill events
    snap.floor_clear_emitted = false
    return snap

func _build_matchup_cache(formation: Array, floor: Floor) -> Dictionary:
    var cache: Dictionary = {}
    var archetypes_in_floor: Dictionary = {}
    for kill in floor.kill_schedule:
        archetypes_in_floor[kill.archetype] = true
    for archetype in archetypes_in_floor:
        cache[archetype] = _matchup_resolver.resolve_floor_matchup(formation, archetype)
    return cache
```

On load (`load_save_data`): if `DataRegistry.resolve("floors", snap.floor_id) == null`, transition to NO_RUN + log push_warning. This handles content removed between save and load (e.g., V1.0 floor demoted, save still references it).

---

## QA Test Cases

- **TR-004 deep copy**: build snapshot from formation; mutate source HeroRoster.formation; assert snapshot.formation_snapshot unchanged
- **TR-006 floor by id**: snapshot.floor_id is String not Floor; on load with unknown id → state goes NO_RUN
- **TR-012 cache completeness**: floor with kill_schedule [bruiser, caster, beast] → matchup_cache.size() == 3; all 3 archetypes present
- **TR-013 once-only**: spy resolver counts `resolve_floor_matchup` calls; build snapshot then run 100 ticks worth of replay; assert call count == 3 (one per archetype, NOT 100)

---

## Test Evidence

**Type**: Logic | **Required**: `tests/unit/dungeon_run_orchestrator/snapshot_and_matchup_cache_test.gd`

---

## Dependencies

- Depends on: Story 001 (RunSnapshot), Story 002 (resolvers). Floor resource from biome-dungeon-database epic.
- Unlocks: Story 005 (tick handler reads cache); Story 011 (offline replay reads cache); Story 010 (save/load round-trip preserves cache)
