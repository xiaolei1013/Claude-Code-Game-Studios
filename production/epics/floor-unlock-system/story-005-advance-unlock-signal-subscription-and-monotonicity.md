# Story 005: advance_unlock + DungeonRunOrchestrator signal subscription + monotonicity invariant

> **Epic**: floor-unlock-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/floor-unlock-system.md`
**Requirements**: TR-floor-unlock-006, TR-floor-unlock-007, TR-floor-unlock-008, TR-floor-unlock-009, TR-floor-unlock-010

**Governing ADR**: ADR-0007 (Scene Transition + Persist Coupling) + ADR-0014 (Offline Replay Schema) + ADR-0003 Amendment #1 (signal subscription across rank pairs at _ready() is safe)
**Decision Summary**: At `_ready()`, FloorUnlock subscribes to `DungeonRunOrchestrator.floor_cleared_first_time(floor_index, biome_id, losing_run)` using DEFAULT flags (NOT CONNECT_DEFERRED — TR-006). The handler `_on_floor_cleared_first_time` advances `_unlock_state[biome_id]` via the max-form: `h_new = max(current, floor_index)`; writes ONLY when `h_new > current` (TR-010 — duplicate signal is a silent no-op). LOSING first-clear advances the lantern identically to WIN (TR-009 — `losing_run` is accepted but not read by this system; ADR-0002 handles gold idempotency separately). Monotonicity invariant R4: `_unlock_state[biome_id]` is strictly non-decreasing (TR-008 — no decrement code path exists outside Story 006's clamp-on-load).

**Engine**: Godot 4.6 | **Risk**: MEDIUM (cross-rank signal subscription — was the structural concern in ADR-0003 that Amendment #1 verified safe)

**Control Manifest Rules**:
- Required: signal subscription uses default `connect()` flags (not CONNECT_DEFERRED) — TR-006
- Required: handler accepts (floor_index: int, biome_id: String, losing_run: bool) signature — TR-007
- Required: `advance_unlock` uses max-form; write-only-when-greater (TR-010)
- Required: `losing_run` parameter accepted but NOT branched on (TR-009)
- Forbidden: any decrement-path on `_unlock_state[biome_id]` outside Story 006's clamp-on-load (TR-008)

---

## Acceptance Criteria

- [ ] TR-006: `_ready()` subscribes to `DungeonRunOrchestrator.floor_cleared_first_time` with default flags; idempotent (re-call doesn't double-connect)
- [ ] TR-007: handler signature is `_on_floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool)`
- [ ] TR-008: source-grep canary — no `_unlock_state[X] -= ...` or `_unlock_state[X] = N` where N could be lower; only `_unlock_state[X] = max(...)` patterns OR Story 006's clamp branches
- [ ] TR-009: handler treats losing_run=true and losing_run=false identically — same advance, same final state
- [ ] TR-010: duplicate signal (same floor_index for same biome_id) is silent no-op — `_unlock_state` unchanged

---

## Implementation Notes

```gdscript
func _ready() -> void:
	# ... existing seed + populate logic from Stories 001/004 ...
	if not DungeonRunOrchestrator.floor_cleared_first_time.is_connected(_on_floor_cleared_first_time):
		DungeonRunOrchestrator.floor_cleared_first_time.connect(_on_floor_cleared_first_time)

func _on_floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool) -> void:
	# losing_run accepted but NOT read — TR-009.
	advance_unlock(biome_id, floor_index)

func advance_unlock(biome_id: String, floor_index: int) -> void:
	# Story 004 guard chain: is_biome_available → BIOME_FLOOR_COUNT.has → range.
	if not is_biome_available(biome_id):
		_log_error("[FloorUnlock] advance_unlock: biome '%s' unavailable" % biome_id)
		return
	if not _biome_floor_count.has(biome_id):
		_log_error("[FloorUnlock] advance_unlock: biome '%s' has no floor count" % biome_id)
		return
	var n: int = int(_biome_floor_count[biome_id])
	if floor_index < 1 or floor_index > n:
		_log_error("[FloorUnlock] advance_unlock: floor %d out of [1,%d] for '%s'" % [floor_index, n, biome_id])
		return
	# TR-010 max-form: write ONLY if greater.
	var current: int = int(_unlock_state.get(biome_id, 0))
	var h_new: int = maxi(current, floor_index)
	if h_new > current:
		_unlock_state[biome_id] = h_new
```

---

## Out of Scope

- Save/Load persistence — Story 006
- Orchestrator's DISPATCHING gate query — Story 007
- Offline replay parity — Story 008

---

## QA Test Cases

- **AC TR-006 subscription**:
  - Given: orchestrator + FloorUnlock both autoloaded
  - When: inspect `DungeonRunOrchestrator.floor_cleared_first_time.is_connected(FloorUnlock._on_floor_cleared_first_time)`
  - Then: returns true

- **AC TR-007 handler signature**:
  - When: orchestrator emits `floor_cleared_first_time.emit(3, "forest_reach", false)`
  - Then: handler accepts the 3-arg payload without error

- **AC TR-009 losing-run parity**:
  - Given: fresh state `_unlock_state["forest_reach"] = 0`
  - When: handler invoked with (1, "forest_reach", true) — losing first-clear
  - Then: `_unlock_state["forest_reach"] == 1` (advances identically to WIN case)

- **AC TR-010 duplicate no-op**:
  - Given: `_unlock_state["forest_reach"] = 3`
  - When: handler invoked with (3, "forest_reach", false) — duplicate
  - Then: state still `{"forest_reach": 3}`; no error logged

- **AC TR-010 lower-than-current**:
  - Given: `_unlock_state["forest_reach"] = 3`
  - When: handler invoked with (1, "forest_reach", false) — out-of-order replay
  - Then: state still `{"forest_reach": 3}` — max-form preserves higher value

- **AC TR-008 monotonicity invariant**:
  - Given: source-grep on `_unlock_state\[.*\] = ` patterns in floor_unlock_system.gd
  - Then: only assignment patterns are `= maxi(...)` (Story 005), `= 0` (Story 001 fresh-save), or clamp-bounded (Story 006); no `-=` or `= N` where N could be lower than current

---

## Test Evidence

**Story Type**: Integration
**Required**: `tests/integration/floor_unlock/advance_unlock_and_signal_test.gd`

---

## Dependencies

- **Depends on**: Story 001-004 + DungeonRunOrchestrator Story 006 (S8-S3 — `floor_cleared_first_time` signal exists)
- **Unlocks**: Story 006 (save/load persistence relies on `_unlock_state` being mutable via advance_unlock first), Story 008 (offline replay reuses handler)
