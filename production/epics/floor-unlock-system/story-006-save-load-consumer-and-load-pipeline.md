# Story 006: Save/Load consumer contract + per-value processing pipeline

> **Epic**: floor-unlock-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/floor-unlock-system.md`
**Requirements**: TR-floor-unlock-015, TR-floor-unlock-016, TR-floor-unlock-017, TR-floor-unlock-018, TR-floor-unlock-019, TR-floor-unlock-020, TR-floor-unlock-029

**Governing ADR**: ADR-0004 (Save Envelope) + ADR-0011 (Resource Schemas)
**Decision Summary**: FloorUnlock is item #3 in `SaveLoadSystem.CONSUMER_PATHS` (after Economy, after HeroRoster, before DungeonRunOrchestrator). Save dict shape: `{"highest_cleared": Dictionary[String, int]}` namespaced under key `"floor_unlock"` (TR-015). Load pipeline per-value processing order is FIXED (TR-016): (1) type guard → reject non-numeric (String/NIL/bool); (2) lossy-cast warn → if float and not int-equivalent, log warning; (3) `int()` cast → JSON returns numbers as float, must coerce before writing typed Dict[String,int] (TR-017); (4) under-range clamp → negative becomes 0 + warning (TR-029); (5) over-range clamp → value > BIOME_FLOOR_COUNT[b] becomes N + warning (TR-029); (6) write to `_unlock_state`. Missing `floor_unlock` key on load → fresh-save default (forward-compat, no error — TR-019). Stale biome_ids preserved (not deleted) with push_warning (TR-020).

**Engine**: Godot 4.6 | **Risk**: HIGH (5-step processing pipeline; JSON float-coercion is the load-bearing safety; clamp rules per ADR-0002 monotonicity)

**Control Manifest Rules**:
- Required: save dict shape exactly `{"highest_cleared": Dict[String,int]}`; no other keys (TR-015)
- Required: load pipeline order TR-016 strictly preserved
- Required: every `int()` cast site has a preceding type guard (TR-017 + TR-018)
- Required: clamp-rather-than-reject rule applied — TR-029
- Forbidden: `del _unlock_state[stale_biome_id]` — stale entries preserved per TR-020

---

## Acceptance Criteria

- [ ] TR-015: `get_save_data() -> {"highest_cleared": <dict>}`; `load_save_data(d)` reads `d["highest_cleared"]`
- [ ] TR-016: load pipeline executes 6 steps in order; each step's failure mode tested individually
- [ ] TR-017: float values from JSON round-trip (e.g., 5.0) are int()-cast before write
- [ ] TR-018: non-numeric value (String, bool, NIL) triggers `_warning_logger`; resets that biome's value to 0; key still present in `_unlock_state`
- [ ] TR-019: save dict missing the `"floor_unlock"` key → load_save_data falls back to fresh-save default; no error
- [ ] TR-020: stale biome_id (not in DataRegistry active list) preserved in `_unlock_state` after load round-trip with push_warning
- [ ] TR-029: under-range value (e.g., -3) clamps to 0 with warning; over-range (e.g., 99 with N=5) clamps to N with warning

---

## Implementation Notes

```gdscript
const _SAVE_NAMESPACE: String = "floor_unlock"

func get_save_data() -> Dictionary:
	return {"highest_cleared": _unlock_state.duplicate(true)}

func load_save_data(d: Dictionary) -> void:
	if not d.has(_SAVE_NAMESPACE):
		# TR-019 forward-compat — fresh save default already seeded by _ready.
		return
	var ns: Dictionary = d[_SAVE_NAMESPACE] as Dictionary
	if not ns.has("highest_cleared"):
		return
	var hc_in: Dictionary = ns["highest_cleared"] as Dictionary
	for biome_id_var: Variant in hc_in:
		var biome_id: String = str(biome_id_var)
		var raw: Variant = hc_in[biome_id_var]
		_apply_loaded_value(biome_id, raw)

func _apply_loaded_value(biome_id: String, raw: Variant) -> void:
	# TR-016 6-step pipeline:
	# 1. Type guard
	if not (raw is float or raw is int):
		_log_warning("[FloorUnlock] non-numeric value for '%s'; resetting to 0" % biome_id)
		_unlock_state[biome_id] = 0
		return
	# 2. Lossy-cast warn
	if raw is float and float(int(raw)) != float(raw):
		_log_warning("[FloorUnlock] lossy float→int for '%s': %f → %d" % [biome_id, raw, int(raw)])
	# 3. int() cast (TR-017)
	var v: int = int(raw)
	# 4. Under-range clamp
	if v < 0:
		_log_warning("[FloorUnlock] under-range for '%s': %d → 0" % [biome_id, v])
		v = 0
	# 5. Over-range clamp
	var n: int = int(_biome_floor_count.get(biome_id, 0))
	if n > 0 and v > n:
		_log_warning("[FloorUnlock] over-range for '%s': %d → %d" % [biome_id, v, n])
		v = n
	# 6. Write
	_unlock_state[biome_id] = v
	# TR-020 stale check: warn but preserve
	if not is_biome_available(biome_id):
		_log_warning("[FloorUnlock] stale biome '%s' preserved in state" % biome_id)
```

Register FloorUnlock as item #3 in `SaveLoadSystem.CONSUMER_PATHS` (after Economy, before DungeonRunOrchestrator).

---

## Out of Scope

- Heartbeat / dirty-marking — TR-025 (no action; relies on Save/Load Rule 5 cadence)

---

## QA Test Cases

- **AC TR-015 save shape**:
  - Given: `_unlock_state = {"forest_reach": 3}`
  - When: `get_save_data()`
  - Then: returns `{"highest_cleared": {"forest_reach": 3}}` exactly

- **AC TR-019 missing key fresh-default**:
  - Given: empty save dict `{}`
  - When: `load_save_data({})`
  - Then: `_unlock_state` retains fresh-save default (`{"forest_reach": 0}`); no error

- **AC TR-017 float coercion**:
  - Given: save dict has `"forest_reach": 3.0` (JSON-style float)
  - When: load_save_data
  - Then: `_unlock_state["forest_reach"] == 3` (int); no runtime type error

- **AC TR-018 non-numeric**:
  - Given: save dict has `"forest_reach": "corrupted"`
  - When: load_save_data
  - Then: `_warning_logger` invoked; `_unlock_state["forest_reach"] == 0`; key present

- **AC TR-029 under-range clamp**:
  - Given: save dict has `"forest_reach": -3`
  - When: load
  - Then: `_unlock_state["forest_reach"] == 0`; warning logged

- **AC TR-029 over-range clamp**:
  - Given: BIOME_FLOOR_COUNT["forest_reach"] = 5; save has `"forest_reach": 99`
  - When: load
  - Then: `_unlock_state["forest_reach"] == 5`; warning logged

- **AC TR-020 stale preservation**:
  - Given: save dict has `"demoted_biome": 4`; DataRegistry has no such biome
  - When: load
  - Then: `_unlock_state["demoted_biome"] == 4` preserved; warning logged

- **AC TR-016 ordering**:
  - Given: a save value that triggers multiple steps (e.g., float -3.7 with biome that has N=5)
  - When: load
  - Then: cast to int (-3) → under-range clamp (0); the lossy-cast warn fires before the under-range warn (verifies pipeline order)

---

## Test Evidence

**Story Type**: Integration
**Required**: `tests/integration/floor_unlock/save_load_round_trip_test.gd`

---

## Dependencies

- **Depends on**: Stories 001-005 + Sprint 4 SaveLoadSystem.CONSUMER_PATHS registration
- **Unlocks**: Story 008 (offline replay relies on load_save_data hydration)
