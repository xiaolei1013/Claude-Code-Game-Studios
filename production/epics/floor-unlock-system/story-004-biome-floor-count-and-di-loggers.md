# Story 004: BIOME_FLOOR_COUNT lookup + handler guards + DI loggers

> **Epic**: floor-unlock-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/floor-unlock-system.md`
**Requirements**: TR-floor-unlock-012, TR-floor-unlock-013, TR-floor-unlock-021

**Governing ADR**: ADR-0009 (DI Callable patterns) + ADR-0011 (DataRegistry SoT)
**Decision Summary**: `BIOME_FLOOR_COUNT: Dictionary[String, int]` is populated ONCE at `_ready()` from DataRegistry by reading `Biome.dungeons[0].floors.size()` for each biome (TR-013). Handler-side range guards check in this order: (1) `is_biome_available(biome_id)` → reject unavailable; (2) `BIOME_FLOOR_COUNT.has(biome_id)` → reject unknown; (3) `floor_index in [1, N]` → reject out-of-range. Errors route through injected `_error_logger: Callable` (TR-021); production wires it to `push_error`; tests inject capturing closures.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (DataRegistry boot-order coupling — was the root cause of TD-010 in Sprint 7)

**Control Manifest Rules**:
- Required: `BIOME_FLOOR_COUNT` populated in `_ready()` from DataRegistry; never re-read mid-session
- Required: handler guard order = is_biome_available → BIOME_FLOOR_COUNT.has → floor_index in [1,N] (TR-012)
- Required: `_error_logger: Callable` and `_warning_logger: Callable` are injected via setters (TR-021); defaults to push_error / push_warning when not set

---

## Acceptance Criteria

- [ ] TR-013: `BIOME_FLOOR_COUNT["forest_reach"] == 5` after `_ready()` (matches forest_reach Biome.dungeons[0].floors.size())
- [ ] TR-012 guard ordering: handler rejects unavailable biome BEFORE checking BIOME_FLOOR_COUNT; rejects unknown biome BEFORE range check
- [ ] TR-012 range guard: floor_index outside `[1, BIOME_FLOOR_COUNT[b]]` triggers `_error_logger.call(...)` and rejects
- [ ] TR-021: `set_error_logger(c)` / `set_warning_logger(c)` setters exist; injected Callables receive log messages instead of push_error/push_warning
- [ ] TR-021: when no logger injected, falls back to push_error / push_warning (production default)

---

## Implementation Notes

```gdscript
const BIOME_FLOOR_COUNT: Dictionary[String, int] = {}
# Wait — const Dictionary can't be mutated after declaration. Switch to var:

var _biome_floor_count: Dictionary[String, int] = {}
var _error_logger: Callable = Callable()
var _warning_logger: Callable = Callable()

func _ready() -> void:
	_seed_fresh_save_default()  # from Story 001
	_populate_biome_floor_count()

func _populate_biome_floor_count() -> void:
	for biome_id: String in DataRegistry.get_all_by_type("biomes"):
		var biome: Resource = DataRegistry.resolve("biomes", biome_id)
		if biome == null:
			continue
		var dungeons: Array = biome.get("dungeons") as Array
		if dungeons.is_empty():
			continue
		var floors: Array = (dungeons[0] as Resource).get("floors") as Array
		_biome_floor_count[biome_id] = floors.size()

func set_error_logger(c: Callable) -> void:
	_error_logger = c

func set_warning_logger(c: Callable) -> void:
	_warning_logger = c

func _log_error(msg: String) -> void:
	if _error_logger.is_valid():
		_error_logger.call(msg)
	else:
		push_error(msg)

func _log_warning(msg: String) -> void:
	if _warning_logger.is_valid():
		_warning_logger.call(msg)
	else:
		push_warning(msg)
```

The handler guard chain is consumed by Story 005's advance_unlock and Story 002's read API.

---

## Out of Scope

- Signal subscription to floor_cleared_first_time — Story 005
- Save/Load consumer contract — Story 006

---

## QA Test Cases

- **AC TR-013 boot population**:
  - Given: DataRegistry has forest_reach with 5 floors in dungeons[0]
  - When: FloorUnlock _ready completes
  - Then: `_biome_floor_count["forest_reach"] == 5`

- **AC TR-013 multi-biome**:
  - Given: DataRegistry has forest_reach (5 floors) + tundra_pass (3 floors planned_v1)
  - Then: both keys present in `_biome_floor_count` regardless of status

- **AC TR-012 guard order — unknown biome**:
  - Given: handler invoked with biome_id="ghost"
  - When: handler runs
  - Then: rejects at first guard (is_biome_available); does NOT reach _biome_floor_count check; logger receives "biome_unavailable" reason

- **AC TR-012 guard order — out of range**:
  - Given: handler invoked with biome="forest_reach", floor_index=99
  - When: handler runs
  - Then: passes biome guards; rejects at range guard; `_error_logger` invoked with message containing "out of range"

- **AC TR-021 injected logger**:
  - Given: spy Callable injected via `set_error_logger`
  - When: handler triggers an error path
  - Then: spy receives the message; `push_error` is NOT called

- **AC TR-021 default fallback**:
  - Given: no logger injected (Callable() default)
  - When: handler triggers an error path
  - Then: falls back to push_error (verified by absence of crash; log content check via output capture optional)

---

## Test Evidence

**Story Type**: Integration
**Required**: `tests/integration/floor_unlock/biome_floor_count_and_loggers_test.gd`

---

## Dependencies

- **Depends on**: Story 001-003 + Sprint 4 BiomeDungeonDatabase
- **Unlocks**: Story 005 (advance_unlock uses guards), Story 006 (load_save_data uses range clamps)
