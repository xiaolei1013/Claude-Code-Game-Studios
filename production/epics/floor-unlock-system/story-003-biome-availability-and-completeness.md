# Story 003: Biome availability + completeness + get_available_biomes

> **Epic**: floor-unlock-system
> **Status**: Complete (real implementation 2026-05-08 — implementation pre-existed; new focused test file `tests/unit/floor_unlock_system/biome_availability_and_completeness_test.gd` adds 16 functions covering all 6 ACs.)
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/floor-unlock-system.md`
**Requirements**: TR-floor-unlock-023, TR-floor-unlock-024, TR-floor-unlock-020 (partial — stale-biome filtering)

**Governing ADR**: ADR-0011 (Resource Schemas — DataRegistry as single source of truth for biome metadata)
**Decision Summary**: `is_biome_available(biome_id)` filters DataRegistry biomes by `status == "active"` — UI consumers MUST go through this, NOT read `Biome.status` directly (TR-023). `is_biome_completed(biome_id)` requires three guards: (1) BIOME_FLOOR_COUNT[biome_id] > 0; (2) highest_cleared == BIOME_FLOOR_COUNT[biome_id]; (3) is_biome_available — the third guard prevents V1.0 partial-ship false positives (TR-024). `get_available_biomes()` returns the filtered list for the FloorSelect screen.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: `is_biome_available(biome_id)` reads DataRegistry biome resource's `status` field; not cached (DataRegistry is the SoT)
- Required: `is_biome_completed(b)` triple-guard (count>0 AND highest==N AND is_biome_available) — TR-024
- Required: `get_available_biomes()` returns Array[String] of biome_ids with status=="active"
- Required: stale biome_id in `_unlock_state` (e.g., V1.0 biome demoted) is preserved on save round-trip but filtered via `is_biome_available()` returning false (TR-020)

---

## Acceptance Criteria

- [x] TR-023: `is_biome_available("forest_reach")` returns true (active in V1); fictional "ghost_biome" returns false
- [x] TR-023: `get_available_biomes()` returns Array[String]; ordering matches DataRegistry iteration order
- [x] TR-024: `is_biome_completed(b)` returns false when BIOME_FLOOR_COUNT[b] == 0 (defensive — prevents 0/0 false positive)
- [x] TR-024: `is_biome_completed(b)` returns false when biome is unavailable (status != "active")
- [x] TR-024: `is_biome_completed(b)` returns true ONLY when all three guards pass
- [x] TR-020: stale biome_id (in `_unlock_state` but not in DataRegistry active list) preserved in dict; filtered via is_biome_available

---

## Implementation Notes

```gdscript
func is_biome_available(biome_id: String) -> bool:
	var biome: Resource = DataRegistry.resolve("biomes", biome_id)
	if biome == null:
		return false
	return str(biome.get("status")) == "active"

func is_biome_completed(biome_id: String) -> bool:
	# Triple-guard per TR-024 — order matters; cheapest check first.
	var count: int = int(BIOME_FLOOR_COUNT.get(biome_id, 0))
	if count <= 0:
		return false  # V1.0 partial-ship: biome listed but no floors yet
	if get_highest_cleared(biome_id) != count:
		return false
	return is_biome_available(biome_id)

func get_available_biomes() -> Array[String]:
	var out: Array[String] = []
	for biome_id: String in DataRegistry.get_all_by_type("biomes"):
		if is_biome_available(biome_id):
			out.append(biome_id)
	return out
```

Update `get_floor_state` from Story 002 to use `is_biome_available` instead of the `_unlock_state.has(biome_id)` placeholder for the UNAVAILABLE branch.

---

## Out of Scope

- BIOME_FLOOR_COUNT population at boot — Story 004
- Stale-biome filtering on save load — Story 006

---

## QA Test Cases

- **AC TR-023 active filter**:
  - Given: DataRegistry with forest_reach (status="active") + tundra_pass (status="planned_v1")
  - When: `is_biome_available("forest_reach")` / `is_biome_available("tundra_pass")`
  - Then: true / false

- **AC TR-023 unknown biome**:
  - When: `is_biome_available("ghost_biome_does_not_exist")`
  - Then: false (DataRegistry.resolve returns null → guard returns false)

- **AC TR-024 partial-ship guard**:
  - Given: BIOME_FLOOR_COUNT["tundra_pass"] = 0 (no floors yet); `_unlock_state["tundra_pass"] = 0`
  - When: `is_biome_completed("tundra_pass")`
  - Then: false (count <= 0 fails first guard)

- **AC TR-024 unavailable guard**:
  - Given: BIOME_FLOOR_COUNT["beach"] = 5; `_unlock_state["beach"] = 5` (would otherwise look completed); but biome status="planned_v1"
  - When: `is_biome_completed("beach")`
  - Then: false (third guard fails)

- **AC TR-024 all guards pass**:
  - Given: BIOME_FLOOR_COUNT["forest_reach"] = 5; `_unlock_state["forest_reach"] = 5`; status="active"
  - When: `is_biome_completed("forest_reach")`
  - Then: true

- **AC TR-020 stale preservation**:
  - Given: `_unlock_state` contains "demoted_v0_biome" (left over from prior version); DataRegistry has no such biome
  - When: round-trip via get_save_data / load_save_data
  - Then: key still present in `_unlock_state`; `is_biome_available("demoted_v0_biome")` returns false

---

## Test Evidence

**Story Type**: Logic
**Required**: `tests/unit/floor_unlock/biome_availability_test.gd`

---

## Dependencies

- **Depends on**: Story 001 (autoload), Story 002 (read API), Sprint 4 BiomeDungeonDatabase + DataRegistry boot scan
- **Unlocks**: Story 005 (advance_unlock checks is_biome_available before write)
