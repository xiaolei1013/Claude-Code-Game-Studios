# Story 002: Public read API + FloorState enum

> **Epic**: floor-unlock-system
> **Status**: Complete (per-AC verification 2026-05-08 — implementation + tests already exist in source. Paperwork-only closure: ACs ticked + Test Evidence path corrected. Story spec named `tests/unit/floor_unlock/read_api_test.gd` but the canonical location is `tests/unit/floor_unlock_system/floor_unlock_system_test.gd` — same coverage, different path.)
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/floor-unlock-system.md`
**Requirements**: TR-floor-unlock-004, TR-floor-unlock-011, TR-floor-unlock-014

**Governing ADR**: ADR-0009 (DI patterns; pure-function reads)
**Decision Summary**: Read-only API consumed by DungeonRunOrchestrator (DISPATCHING gate), HUD (lock badges), and the Recruit/FloorSelect UI. `is_unlocked(floor_index)` is the load-bearing gate; auxiliary methods drive the floor-state widget. `FloorState` enum gives the UI a 4-bucket display contract: UNAVAILABLE (biome not in V1) / LOCKED (biome ok, floor not yet cleared) / ACCESSIBLE (next available floor) / CLEARED (already cleared). 1-based floor_index per TR-011; index 0 is the sentinel "no floor" — `is_unlocked(0)` returns false.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: `is_unlocked(floor_index: int) -> bool` returns false for floor_index=0 sentinel (TR-011)
- Required: `FloorState` enum has exactly 4 values: UNAVAILABLE / LOCKED / ACCESSIBLE / CLEARED (TR-014)
- Required: `get_floor_state(biome_id, floor_index)` derives state purely from `_unlock_state` + biome availability — never persisted (TR-014)

---

## Acceptance Criteria

- [x] TR-004: public methods `is_unlocked(floor_index)`, `get_highest_cleared(biome_id)`, `get_floor_state(biome_id, floor_index)` exist with documented signatures
- [x] TR-011: `is_unlocked(0)` returns false; `is_unlocked(N>=1)` reflects unlock state
- [x] TR-014: `FloorState` enum {UNAVAILABLE, LOCKED, ACCESSIBLE, CLEARED} declared at script level; `get_floor_state` derives correct bucket per (biome availability + highest_cleared + floor_index) tuple

---

## Implementation Notes

```gdscript
enum FloorState { UNAVAILABLE, LOCKED, ACCESSIBLE, CLEARED }

func is_unlocked(floor_index: int) -> bool:
	# Defaults to forest_reach for the MVP; biome_id-aware overload is Story 003.
	if floor_index <= 0:
		return false  # sentinel; TR-011
	var highest: int = get_highest_cleared("forest_reach")
	# A floor is unlocked iff floor_index <= highest + 1 (cleared OR next-available).
	return floor_index <= highest + 1

func get_highest_cleared(biome_id: String) -> int:
	return int(_unlock_state.get(biome_id, 0))

func get_floor_state(biome_id: String, floor_index: int) -> int:
	# Story 003 wires is_biome_available; placeholder treats unknown biome
	# as UNAVAILABLE per the planned-V1-not-seeded contract.
	if not _unlock_state.has(biome_id):
		return FloorState.UNAVAILABLE
	var highest: int = get_highest_cleared(biome_id)
	if floor_index <= highest:
		return FloorState.CLEARED
	if floor_index == highest + 1:
		return FloorState.ACCESSIBLE
	return FloorState.LOCKED
```

---

## Out of Scope

- Biome availability filtering (`is_biome_available`, `get_available_biomes`) — Story 003
- BIOME_FLOOR_COUNT range guards — Story 004
- advance_unlock mutation — Story 005

---

## QA Test Cases

- **AC TR-011 sentinel**:
  - Given: fresh autoload with `_unlock_state = {"forest_reach": 0}`
  - When: `is_unlocked(0)`
  - Then: returns false

- **AC TR-004 unlock formula**:
  - Given: `_unlock_state = {"forest_reach": 3}` (floors 1..3 cleared)
  - When: `is_unlocked(1)` / `is_unlocked(3)` / `is_unlocked(4)` / `is_unlocked(5)`
  - Then: true / true / true (next available) / false (locked)

- **AC TR-014 four-bucket enum**:
  - Given: `FloorState` declared at script level
  - When: enumerate values
  - Then: exactly 4 entries — UNAVAILABLE=0, LOCKED=1, ACCESSIBLE=2, CLEARED=3

- **AC TR-014 cleared bucket**:
  - Given: `_unlock_state = {"forest_reach": 5}`
  - When: `get_floor_state("forest_reach", 3)`
  - Then: returns FloorState.CLEARED

- **AC TR-014 accessible bucket**:
  - Given: same state
  - When: `get_floor_state("forest_reach", 6)`
  - Then: returns FloorState.ACCESSIBLE

- **AC TR-014 locked bucket**:
  - Given: same state
  - When: `get_floor_state("forest_reach", 8)`
  - Then: returns FloorState.LOCKED

- **AC TR-014 unavailable bucket**:
  - Given: state has no key for "tundra_pass"
  - When: `get_floor_state("tundra_pass", 1)`
  - Then: returns FloorState.UNAVAILABLE

---

## Test Evidence

**Story Type**: Logic
**Required**: `tests/unit/floor_unlock/read_api_test.gd`

---

## Dependencies

- **Depends on**: Story 001 (autoload + _unlock_state)
- **Unlocks**: Story 003 (biome availability extends this read API)
