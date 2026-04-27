# Story 007: compute_offline_batch + foreground/offline parity

> **Epic**: combat-resolution
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/combat-resolution.md` §C.4
**Requirements**: TR-combat-002, 003, 015, 021, 022, 023
**Governing ADR**: ADR-0010 + ADR-0014 (offline batch chunking)
**Decision**: `compute_offline_batch(snapshot, tick_budget) -> CombatBatchResult` — pure function returning aggregate counts only (NOT per-event) for long runs (15k+ kills). **Parity invariant** (TR-022): the union of `emit_events_in_range` calls across the same total range produces a kill stream byte-equal to a single `compute_offline_batch` call. Both share the same private `_kill_schedule_for_loop` helper to guarantee parity (TR-003). Determinism (TR-021): repeated calls with identical args return field-equal CombatBatchResult; input formation is unmutated.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (parity is the load-bearing offline-replay invariant)

## Acceptance Criteria

- [ ] TR-002: `compute_offline_batch(snapshot, tick_budget) -> CombatBatchResult` — pure-function entry
- [ ] TR-003: foreground + offline share the same `_kill_schedule_for_loop` private helper (verified via single source of truth)
- [ ] TR-015: returned CombatBatchResult populates all 7 fields (kills_by_archetype, kills_by_tier, loops_completed, first_clear_tick, hp_bonus_factor, survived, final_tick)
- [ ] TR-021 determinism: 100 repeated calls with same args → field-equal results; source formation unmutated (verify via deep-copy hash)
- [ ] TR-022 parity: `emit_events_in_range(0, 1000)` union == `compute_offline_batch(snapshot, 1000)` aggregate (kills_by_archetype, kills_by_tier dicts byte-equal); 5 × 200-tick batches produce identical aggregate
- [ ] TR-023: 15k+ kill scenarios return aggregate CombatBatchResult only (no Array[KillEvent] retained); foreground retains per-event detail

## Implementation Notes
Foreground emit walks the schedule appending `KillEvent` records. Offline batch walks the SAME schedule but folds entries into `kills_by_archetype: Dictionary[StringName, int]` increments — same iteration order, same per-enemy timing, no per-event Array overhead.

```gdscript
func compute_offline_batch(snapshot, tick_budget) -> CombatBatchResult:
    var result := CombatBatchResult.new()
    # ... walk schedule via shared _kill_schedule_for_loop ...
    # Aggregate into dicts instead of appending Array
    return result
```

## QA Test Cases

- TR-022 parity: 1×1000-tick offline.kills_by_archetype == 5×200-tick offline.kills_by_archetype == 10×100-tick foreground (folded into archetype dict)
- TR-021 determinism: hash of CombatBatchResult.to_dict() identical across 100 calls
- TR-021 input safety: source formation Array's hash unchanged after `compute_offline_batch`
- TR-023 memory: 15k-kill scenario produces no Array[KillEvent] (verify via property absence on CombatBatchResult)

## Test Evidence
**Required**: `tests/integration/combat_resolution/foreground_offline_parity_test.gd`

## Dependencies
- Depends on: Stories 001-006 (resolver complete)
- Unlocks: Story 010 (perf bench builds on offline batch)
