# Story 009: ACTIVE_OFFLINE_REPLAY compute + D.4 loop-walk + foreground/offline parity

> **Epic**: dungeon-run-orchestrator
> **Status**: Complete (system shipped; see systems-index Implementation Status #13. Test evidence: `tests/{unit,integration}/dungeon_run_orchestrator/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/dungeon-run-orchestrator.md`
**Requirements**: TR-orchestrator-010, TR-orchestrator-011, TR-orchestrator-028

**Governing ADRs**: ADR-0014 (Offline Replay Batch Chunking) + ADR-0010 (Combat Resolver Snapshot)
**Decision Summary**: `compute_offline_run(tick_budget) -> OfflineRunResult` for the offline replay path. Emits `floor_cleared_first_time(floor_index, biome_id, losing_run)` in lockstep with foreground (same args, same conditions). Per **GDD §D.4 loop-walk algorithm**: walk `kill_schedule` in tick order, NOT dict-walk on `kills_by_archetype`. `partial_loop_kills` walked in tick order. Foreground/offline parity contract: identical gold totals, per-archetype counts, floor_cleared_first_time count/payload for same `(formation, floor, T)`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (parity invariant)

---

## Acceptance Criteria

- [ ] TR-010: `compute_offline_run(tick_budget)` returns `OfflineRunResult`; emits `floor_cleared_first_time` per first-clear in lockstep with foreground
- [ ] TR-011: D.4 loop-walk over `kill_schedule` in tick order; NOT dict-walk on `kills_by_archetype`
- [ ] TR-028: Foreground/offline parity: same `(formation, floor, T)` produces identical gold total, per-archetype kill counts, and `floor_cleared_first_time` count/payload

---

## Implementation Notes

```gdscript
class_name OfflineRunResult extends RefCounted

var total_gold: int = 0
var kills_by_archetype: Dictionary = {}
var floor_cleared_first_time_count: int = 0
var floor_was_valid: bool = true
# Use positional + property-setter pattern (NOT keyword args — invalid GDScript per Pass 5D)

func compute_offline_run(tick_budget: int) -> OfflineRunResult:
    var result: OfflineRunResult = OfflineRunResult.new()
    if run_snapshot == null:
        result.floor_was_valid = false
        return result
    var ticks_remaining: int = tick_budget
    # D.4 LOOP-WALK: iterate kill_schedule in tick order
    for kill_event in run_snapshot.kill_schedule:
        if kill_event.tick > run_snapshot.last_emitted_tick + ticks_remaining:
            break  # beyond budget
        # Read matchup from cache (zero resolver calls — TR-013)
        var advantaged: bool = run_snapshot.matchup_cache[kill_event.archetype]
        var gold: int = attribute_kill_gold(kill_event.tier, advantaged, run_snapshot.losing_run)
        result.total_gold += gold
        result.kills_by_archetype[kill_event.archetype] = result.kills_by_archetype.get(kill_event.archetype, 0) + 1
    _check_floor_clear()  # may emit floor_cleared_first_time (Story 007)
    return result
```

For parity: the same `_process_kill_events`-equivalent logic SHOULD route through Economy on offline path AS WELL — coordinate with ADR-0014 (offline replay must drive Economy.add_gold for accumulated gold delta to be reflected in the save).

---

## QA Test Cases

- **TR-010 emission**: compute_offline_run with formation+floor that triggers first-clear → emit count == 1
- **TR-011 tick order**: kill_schedule = [{tick: 5, archetype: "bruiser"}, {tick: 3, archetype: "caster"}, {tick: 8, archetype: "beast"}] → events processed in tick order [3, 5, 8]
- **TR-028 parity**: run same `(formation, floor, T=100)` through foreground (100 ticks of `_on_tick_fired`) AND offline (`compute_offline_run(100)`); compare total_gold, kills_by_archetype, first-clear count — ALL EQUAL

---

## Test Evidence

**Type**: Integration | **Required**: `tests/integration/dungeon_run_orchestrator/offline_replay_and_parity_test.gd`

---

## Dependencies

- Depends on: Story 004 (snapshot + cache), Story 005 (foreground tick path for parity baseline), Story 006 (kill attribution), Story 007 (first-clear gate).
- Unlocks: Story 011 (offline error path), Story 010 (save/load preserves replay state)
