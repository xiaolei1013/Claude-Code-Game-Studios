# Story 001: Autoload skeleton + _unlock_state typed dict + fresh-save default

> **Epic**: floor-unlock-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/floor-unlock-system.md`
**Requirements**: TR-floor-unlock-001, TR-floor-unlock-002, TR-floor-unlock-003, TR-floor-unlock-005

**Governing ADR**: ADR-0003 (Autoload Rank Table) + ADR-0011 (Resource Schemas)
**Decision Summary**: `FloorUnlockSystem` is a `class_name extends Node` autoload registered as `FloorUnlock` (the autoload name is orthogonal to the class_name per ADR-0003 Amendment Sprint-1 lesson). Owns one piece of state: `_unlock_state: Dictionary[String, int]` keyed by biome_id, value = highest cleared floor_index. Fresh-save default seeds **only** `forest_reach: 0` — planned-V1 biomes are NOT seeded so their absence acts as the "unavailable" sentinel. Autoload boot order is fixed at item #4 (after DataRegistry, SaveLoadSystem, Economy; before DungeonRunOrchestrator).

**Engine**: Godot 4.6 | **Risk**: LOW (zero state mutation; pure scaffolding)

**Control Manifest Rules**:
- Required: `class_name FloorUnlockSystem extends Node`; autoload registered as `FloorUnlock` (TR-001)
- Required: `_unlock_state: Dictionary[String, int]` typed (TR-002)
- Required: zero-arg `_init()` per ADR-0003 Amendment #3
- Required: fresh-save default = `{"forest_reach": 0}` ONLY (TR-005)

---

## Acceptance Criteria

- [ ] TR-001: `FloorUnlockSystem extends Node` with `class_name`; autoload at `/root/FloorUnlock`
- [ ] TR-002: `_unlock_state` is typed `Dictionary[String, int]`; not plain `Dictionary`
- [ ] TR-003: autoload boot order matches the rank table — registered AFTER DataRegistry/SaveLoadSystem/Economy, BEFORE DungeonRunOrchestrator
- [ ] TR-005: fresh-save default state contains exactly one key (`forest_reach: 0`); no planned-V1 biomes seeded

---

## Implementation Notes

```gdscript
# src/core/floor_unlock_system/floor_unlock_system.gd
class_name FloorUnlockSystem extends Node

const _FRESH_SAVE_DEFAULT_BIOME: String = "forest_reach"

var _unlock_state: Dictionary[String, int] = {}

func _init() -> void:
	# Zero-arg per ADR-0003 Amendment #3.
	pass

func _ready() -> void:
	# Seed fresh-save default. Save/Load consumer (Story 006) overrides via load_save_data.
	if _unlock_state.is_empty():
		_unlock_state[_FRESH_SAVE_DEFAULT_BIOME] = 0
```

Add to `project.godot` autoloads section AFTER `Economy` and BEFORE `DungeonRunOrchestrator`. The autoload name is `FloorUnlock` — accessed globally as `FloorUnlock.is_unlocked(...)` etc.

---

## Out of Scope

- Public read API (`is_unlocked`, `is_biome_available`, etc.) — Story 002
- BIOME_FLOOR_COUNT lookup — Story 004
- advance_unlock signal subscription — Story 005
- Save/Load consumer contract — Story 006

---

## QA Test Cases

- **AC TR-001 autoload exists**:
  - Given: project starts with autoload `FloorUnlock` registered
  - When: test reads `get_node_or_null("/root/FloorUnlock")`
  - Then: returns non-null Node with `class_name == "FloorUnlockSystem"`

- **AC TR-002 typed state**:
  - Given: fresh autoload after `_ready()`
  - When: inspect `_unlock_state`
  - Then: type is `Dictionary[String, int]` (assignment of plain `{}` literal must fail per static-typing pitfall pattern)

- **AC TR-003 boot order**:
  - Given: project.godot autoloads section
  - When: parse autoload order
  - Then: `DataRegistry` index < `SaveLoadSystem` index < `Economy` index < `FloorUnlock` index < `DungeonRunOrchestrator` index

- **AC TR-005 fresh-save default**:
  - Given: fresh autoload (no save data loaded)
  - When: inspect `_unlock_state`
  - Then: `_unlock_state.size() == 1`; `_unlock_state["forest_reach"] == 0`; no other keys

---

## Test Evidence

**Story Type**: Logic
**Required**: `tests/unit/floor_unlock/autoload_skeleton_test.gd`

---

## Dependencies

- **Depends on**: Sprint 1 DataRegistry + SaveLoadSystem autoloads
- **Unlocks**: All subsequent floor-unlock-system stories
