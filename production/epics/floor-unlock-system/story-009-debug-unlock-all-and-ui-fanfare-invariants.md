# Story 009: debug_unlock_all + UI fanfare losing/win equivalence invariant

> **Epic**: floor-unlock-system
> **Status**: Complete (system shipped; see systems-index Implementation Status #16. Test evidence: `tests/unit/floor_unlock_system/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Feature
> **Type**: Logic + Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/floor-unlock-system.md`
**Requirements**: TR-floor-unlock-022, TR-floor-unlock-027, TR-floor-unlock-028

**Governing ADR**: ADR-0002 (Losing-First-Clear Reclaimable on Win)
**Decision Summary**: `debug_unlock_all` is a developer-only flag guarded by `OS.is_debug_build()` (TR-022). When true, FloorUnlock's `get_floor_state` returns `CLEARED` for all in-range floors regardless of `_unlock_state`. The flag is placed AFTER range guards and BEFORE the highest-cleared comparison branches. Production builds strip the entire branch via `OS.is_debug_build()` returning false. The UI fanfare invariant (TR-027 / TR-028): when the player first-clears a floor, the Unlock/Victory Moment UI fires the SAME fanfare regardless of WIN vs LOSING run — no per-floor `losing_unlock` flag is recorded; UI consumers MUST NOT branch on how the floor reached ACCESSIBLE state. This is the cozy-register lock per Pillar 1 ("respect the player's time").

**Engine**: Godot 4.6 | **Risk**: LOW (debug flag is non-shipping; UI invariant is a contract on UI consumers, verified by source-grep)

**Control Manifest Rules**:
- Required: `debug_unlock_all` guarded by `OS.is_debug_build()` (TR-022); placed AFTER range guards
- Required: `losing_unlock` field DOES NOT EXIST in `_unlock_state` schema (TR-028)
- Required: UI consumer source-grep for `losing_unlock` returns zero hits (TR-028 enforcement test)

---

## Acceptance Criteria

- [ ] TR-022: `debug_unlock_all = true` makes `get_floor_state(b, n)` return CLEARED for all `n in [1, BIOME_FLOOR_COUNT[b]]`; out-of-range floors still rejected
- [ ] TR-022: in non-debug builds (mocked via `OS.is_debug_build()` shim), `debug_unlock_all = true` is a no-op
- [ ] TR-027: `_unlock_state` schema does NOT contain a per-floor `losing_unlock` field (only `Dictionary[String, int]` highest-cleared); source-grep verifies
- [ ] TR-028: UI consumer source-grep — no UI screen file branches on "did this floor unlock via losing or winning?"

---

## Implementation Notes

```gdscript
var debug_unlock_all: bool = false

func get_floor_state(biome_id: String, floor_index: int) -> int:
	# 1. Biome availability guard
	if not is_biome_available(biome_id):
		return FloorState.UNAVAILABLE
	# 2. Range guards
	var n: int = int(_biome_floor_count.get(biome_id, 0))
	if n <= 0 or floor_index < 1 or floor_index > n:
		return FloorState.UNAVAILABLE  # treat out-of-range as unavailable
	# 3. Debug flag (TR-022) — placed AFTER range guards
	if debug_unlock_all and OS.is_debug_build():
		return FloorState.CLEARED
	# 4. Highest-cleared comparison
	var highest: int = get_highest_cleared(biome_id)
	if floor_index <= highest:
		return FloorState.CLEARED
	if floor_index == highest + 1:
		return FloorState.ACCESSIBLE
	return FloorState.LOCKED
```

UI invariant test pattern (source-grep):

```gdscript
func test_ui_consumers_do_not_branch_on_losing_unlock() -> void:
	# Glob assets/screens/**/*.gd + assets/overlays/**/*.gd
	# Scan for the forbidden pattern "losing_unlock" (substring match, comments OK)
	# Assert zero non-comment matches.
```

---

## Out of Scope

- Unlock/Victory Moment UI screen implementation — Presentation epic (#25)
- HUD lock badge — Presentation epic (#19)

---

## QA Test Cases

- **AC TR-022 debug build active**:
  - Given: `OS.is_debug_build()` returns true; `_unlock_state["forest_reach"] = 0`; `debug_unlock_all = true`
  - When: `get_floor_state("forest_reach", 5)`
  - Then: returns FloorState.CLEARED (debug flag overrode highest-cleared)

- **AC TR-022 debug build off**:
  - Given: same state but `debug_unlock_all = false`
  - When: `get_floor_state("forest_reach", 5)`
  - Then: returns FloorState.LOCKED (highest=0, target=5 > 1)

- **AC TR-022 range still respected**:
  - Given: `debug_unlock_all = true`; floor_index = 99 (out of range)
  - When: `get_floor_state(..., 99)`
  - Then: returns UNAVAILABLE (range guard fires before debug flag)

- **AC TR-022 production build no-op**:
  - Given: `debug_unlock_all = true` but `OS.is_debug_build()` mocked to false
  - When: `get_floor_state("forest_reach", 5)`
  - Then: returns LOCKED (debug flag stripped in production builds)

- **AC TR-027 schema canary**:
  - Given: source-grep on floor_unlock_system.gd for "losing_unlock" pattern
  - Then: zero hits (field does not exist)

- **AC TR-028 UI consumer canary**:
  - Given: glob `assets/screens/**/*.gd` + `assets/overlays/**/*.gd` + Sprint 8 DispatchScreen UI files
  - When: scan for "losing_unlock" or "is_losing_unlock" patterns
  - Then: zero hits in non-comment lines

---

## Test Evidence

**Story Type**: Logic + Integration (debug flag is logic; UI canary is integration)
**Required**: `tests/unit/floor_unlock/debug_flag_and_ui_invariants_test.gd`

---

## Dependencies

- **Depends on**: Stories 001-006 (full read API + state machine)
- **Unlocks**: Sprint 9+ Unlock/Victory Moment UI implementation
