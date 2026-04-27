# Story 008: Offline replay parity — floor_cleared_first_time emission lockstep

> **Epic**: floor-unlock-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/floor-unlock-system.md`
**Requirements**: TR-floor-unlock-030, TR-floor-unlock-025

**Governing ADR**: ADR-0014 (Offline Replay Batch Chunking + RunSnapshot Schema) + ADR-0007 (Persist Coupling)
**Decision Summary**: Per ADR-0014, offline replay batches floor-clear events with the run; **no mid-batch unlock cascades** — but the `floor_cleared_first_time` signal MUST fire in lockstep with the foreground path (TR-030 / I.15 fix). If the offline path fails to emit, FloorUnlock silently fails to advance — a Pillar 1 violation that the player only discovers next session when their cleared floor is "still locked." This story verifies the offline-replay path emits `floor_cleared_first_time` for every first-clear that lands during the offline window. The signal subscription from Story 005 then advances `_unlock_state` identically. No save dirty-marking (TR-025 — heartbeat captures advanced state per Save/Load Rule 5; offline replay re-applies the change deterministically).

**Engine**: Godot 4.6 | **Risk**: HIGH (Pillar 1 invariant — silent failures here are user-facing trust breaks)

**Control Manifest Rules**:
- Required: offline replay path emits `floor_cleared_first_time` for every first-clear (TR-030)
- Required: foreground vs offline produce identical `_unlock_state` after the same logical event sequence (replay-parity invariant)
- Required: no dirty-marking call at advance_unlock — heartbeat handles persistence (TR-025)

---

## Acceptance Criteria

- [ ] TR-030: offline batch path (DungeonRunOrchestrator.compute_offline_batch consumer) emits `floor_cleared_first_time` for first-clears in the batch
- [ ] TR-030 parity: a foreground run that clears floor 3 produces `_unlock_state["forest_reach"] == 3`; an offline replay covering the same logical run produces the same final state
- [ ] TR-025: `advance_unlock` does NOT call any save-dirty-mark method; relies on heartbeat (60s cadence per Save/Load Rule 5)

---

## Implementation Notes

This story is primarily a TEST + documentation story — the actual emission lockstep was contracted by the orchestrator's offline replay path (out of scope for FloorUnlock). What FloorUnlock owns:

1. The handler `_on_floor_cleared_first_time` is the SAME function for foreground + offline paths (no offline-specific branch).
2. A regression test that drives both paths against the same input and asserts identical `_unlock_state` outcome.

```gdscript
# Test pattern:
func test_foreground_and_offline_replay_produce_identical_unlock_state() -> void:
    # Path A: foreground — orchestrator dispatch + tick-driven first-clear
    var orch_a: Node = ... ; orch_a.dispatch([...], 1, "forest_reach")
    # Drive ticks until RUN_ENDED; FloorUnlock advances via signal subscription.
    var foreground_state: int = FloorUnlock.get_highest_cleared("forest_reach")
    # Reset state; Path B: simulate offline replay emitting the same signal
    FloorUnlock._unlock_state["forest_reach"] = 0
    DungeonRunOrchestrator.floor_cleared_first_time.emit(1, "forest_reach", false)
    var offline_state: int = FloorUnlock.get_highest_cleared("forest_reach")
    assert_int(offline_state).is_equal(foreground_state)
```

The TR-025 no-dirty-mark check is a source-grep canary on `floor_unlock_system.gd` for any `SaveLoadSystem.mark_dirty()` or similar call — must return zero.

---

## Out of Scope

- Orchestrator's offline replay path implementation — dungeon-run-orchestrator/story-009-offline-replay-and-parity.md
- Save/Load heartbeat cadence — Save/Load epic

---

## QA Test Cases

- **AC TR-030 emission lockstep**:
  - Given: orchestrator's offline-replay batch produces a kill stream including a first-clear at floor 2
  - When: replay completes
  - Then: `floor_cleared_first_time(2, "forest_reach", losing_run)` emitted at least once during replay

- **AC TR-030 parity**:
  - Given: identical input (formation + floor + biome + tick budget)
  - When: foreground tick-driven dispatch vs offline batch replay
  - Then: `_unlock_state["forest_reach"]` identical between the two paths

- **AC TR-025 no dirty-mark**:
  - Given: source-grep on `src/core/floor_unlock_system/floor_unlock_system.gd`
  - When: scan for `mark_dirty\|save_now\|force_save\|request_save` patterns
  - Then: zero hits (relies on heartbeat per Save/Load Rule 5)

- **AC TR-030 mid-batch unlock NOT cascaded**:
  - Given: offline replay batch covering 100 ticks where 3 floors first-clear in sequence
  - When: replay completes
  - Then: 3 separate `floor_cleared_first_time` emissions; `_unlock_state["forest_reach"] == 3` (final state, not 1 → 2 → 3 cascade)

---

## Test Evidence

**Story Type**: Integration
**Required**: `tests/integration/floor_unlock/offline_replay_parity_test.gd`

---

## Dependencies

- **Depends on**: Stories 001-007 + DungeonRunOrchestrator Story 009 (offline replay) — currently a stub; this story may need to mock the offline path until that ships
- **Unlocks**: Pre-launch QA Pillar 1 invariant verification
