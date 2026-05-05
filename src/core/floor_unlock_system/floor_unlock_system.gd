## FloorUnlockSystem — owns the per-biome unlock high-water counter + floor-state
## derivation per design/gdd/floor-unlock-system.md.
##
## Sprint 11 S11-X1 (2026-05-05): runtime-MVP implementation per the GDD's
## R1-R10 rules + §C.2 FloorState derivation. Closes one of the three missing
## consumer autoloads in CONSUMER_PATHS (Economy + HeroRoster + DungeonRunOrchestrator
## already exist; FloorUnlock is the third — FormationAssignment + Recruitment
## remain as Sprint 12+ work).
##
## Autoload name is `FloorUnlock` (per project.godot [autoload] section + GDD
## §C.3 D2 lockstep). Script `class_name` is `FloorUnlockSystem` — the two are
## orthogonal per ADR-0003 + GDD §C.3 Pass-8 edit. Bare-name references in
## other code (e.g., `FloorUnlock.is_unlocked(...)`) resolve to the autoload
## node at /root/FloorUnlock, NOT to the class_name.
##
## ProjectSettings designer-UI integration is DEFERRED per Pass-PROBE-EXECUTED
## (2026-04-21 GDD Open Question I.11) — `add_property_info` only reaches the
## running game process, not the editor process; @tool-script or EditorPlugin
## is required for a real editor-surfaced knob. The runtime fallback
## (`get_setting(key, default)`) works correctly and is what this implementation
## uses. V1.0 multi-biome work owns the proper @tool integration.
##
## Governing GDD: design/gdd/floor-unlock-system.md (Pass-9 + Pass-PROBE-EXECUTED)
## ADRs: ADR-0001 (mid-run reassignment), ADR-0002 (LOSING first-clear),
##       ADR-0003 Amendment #6 (rank 10), ADR-0004 (Save/Load consumer)
class_name FloorUnlockSystem extends Node


# ---------------------------------------------------------------------------
# Public enum (R1 §C.2 — used by get_floor_state + UI consumers)
# ---------------------------------------------------------------------------

## Per-floor state derived from biome availability + highest_cleared counter.
## State is NOT persisted per-floor — only the counter is — but UI + dispatch
## consumers use this enum at call sites for clarity.
enum FloorState { UNAVAILABLE, LOCKED, ACCESSIBLE, CLEARED }


# ---------------------------------------------------------------------------
# Internal state (R1 §C.1)
# ---------------------------------------------------------------------------

## Per-biome high-water unlock counter. Monotone non-decreasing per biome_id
## (R4). Fresh-save default seeds {"forest_reach": 0} per R2 — absent biomes
## signal "unavailable" via get_available_biomes filter (R7).
##
## STABLE-FOR-TEST-ACCESS: this private field name is asserted directly by
## Sub-AC 08-non-numeric / 08-null / 08-bool. Do not rename without updating
## those assertions (or adding a has_biome_state public accessor in lockstep).
var _unlock_state: Dictionary[String, int] = {}

## Test-injection DI for clamp/load warnings per GDD R1-DI-pattern. Production
## defaults to push_warning; tests override with a capturing closure.
var _warning_logger: Callable = func(msg: String) -> void: push_warning(msg)

## Test-injection DI for invalid-signal errors per GDD Pass-7 edit (BLOCKING-5).
## Mirrors the orchestrator's _error_logger pattern.
var _error_logger: Callable = func(msg: String) -> void: push_error(msg)

## Debug/QA flag (G.2). Not @export — toggling is via test fixture or in-editor
## inspector. When true (and OS.is_debug_build()), get_floor_state returns
## CLEARED for every in-range floor.
var debug_unlock_all: bool = false

## Designer-tunable active biome for MVP. Read from ProjectSettings at boot
## with a default of "forest_reach" per the §C.1 R1 ProjectSettings stanza.
## See file header note about ProjectSettings designer-UI deferral.
var active_biome_mvp: String = "forest_reach"

## Per-biome floor count cache. Populated in _ready() from DataRegistry after
## active-biome validation. SCREAMING_SNAKE_CASE matches GDD convention as
## "derived-but-immutable after boot" — treated as a const-like lookup by
## consumers. Unit tests that construct FloorUnlockSystem.new() may set this
## directly before invoking other methods.
var BIOME_FLOOR_COUNT: Dictionary[String, int] = {}


# ---------------------------------------------------------------------------
# Built-in lifecycle
# ---------------------------------------------------------------------------

func _init() -> void:
	# Zero-arg per ADR-0003 Amendment #3.
	pass


## Initializes active_biome_mvp from ProjectSettings, validates against
## DataRegistry, populates BIOME_FLOOR_COUNT, seeds fresh-save default state,
## subscribes to Orchestrator.floor_cleared_first_time per R3.
##
## Per ADR-0003 §Signal SUBSCRIPTION rule: rank 10 → rank 14 forward
## subscription is safe at _ready() time (rank-N → rank-(N+1)+ signal connect
## at _ready is VERIFIED).
func _ready() -> void:
	# ProjectSettings runtime fallback. Pass-PROBE-EXECUTED documented that
	# the editor-UI registration path is broken without @tool — but the
	# runtime get_setting fallback works correctly and is what we use.
	# Designer can set the value by hand-editing project.godot or via the
	# Settings dialog ONCE the @tool integration lands (V1.0+).
	var setting_key: String = "floor_unlock/active_biome_mvp"
	active_biome_mvp = ProjectSettings.get_setting(setting_key, "forest_reach")

	# Validate active_biome_mvp against Biome DB. Soft-brick guard per R1
	# Pass-7/Pass-8 edits. Fall back to "forest_reach" if it exists; else
	# first active biome; else hard-error and leave BIOME_FLOOR_COUNT empty.
	#
	# Note: GDD's example code referenced DataRegistry.get_all_ids("biomes")
	# but the actual DataRegistry public API is `get_all_by_type(content_type)`
	# which returns `Array[Resource]` directly. The biomes have an `id`
	# property we read off the Resource — equivalent semantics, different
	# call shape.
	var valid_active_biomes: Array[String] = []
	var valid_active_biome_resources: Array[Resource] = []
	if has_node("/root/DataRegistry"):
		var dr: Node = get_node("/root/DataRegistry")
		if dr.has_method("get_all_by_type"):
			var all_biomes: Array = dr.call("get_all_by_type", "biomes")
			for biome_v: Variant in all_biomes:
				var biome: Resource = biome_v as Resource
				if biome != null and "status" in biome and biome.get("status") == "active" and "id" in biome:
					valid_active_biomes.append(String(biome.get("id")))
					valid_active_biome_resources.append(biome)
	if not valid_active_biomes.has(active_biome_mvp):
		_error_logger.call(
			"FloorUnlockSystem: active_biome_mvp='%s' is not an active biome"
			% active_biome_mvp
		)
		if valid_active_biomes.has("forest_reach"):
			active_biome_mvp = "forest_reach"
		elif not valid_active_biomes.is_empty():
			active_biome_mvp = String(valid_active_biomes[0])
			_error_logger.call(
				"FloorUnlockSystem: 'forest_reach' not in active biomes; falling back to '%s'"
				% active_biome_mvp
			)
		else:
			_error_logger.call(
				"FloorUnlockSystem: no active biomes in DataRegistry; system is soft-bricked"
			)
			# Leave BIOME_FLOOR_COUNT empty; queries return LOCKED/UNAVAILABLE.
			_seed_fresh_save_default()
			_subscribe_to_orchestrator()
			return

	# Populate BIOME_FLOOR_COUNT from the already-resolved active biome
	# resources (avoids a second DataRegistry round-trip).
	for biome: Resource in valid_active_biome_resources:
		if not ("dungeons" in biome) or not ("id" in biome):
			continue
		var dungeons: Array = biome.get("dungeons") as Array
		if dungeons.is_empty():
			continue
		# MVP: single dungeon per biome (V1.0 multi-dungeon → I.13).
		var dungeon: Resource = dungeons[0] as Resource
		if dungeon == null or not ("floors" in dungeon):
			continue
		var floors: Array = dungeon.get("floors") as Array
		BIOME_FLOOR_COUNT[String(biome.get("id"))] = floors.size()

	_seed_fresh_save_default()
	_subscribe_to_orchestrator()


## Seeds {"forest_reach": 0} per R2 fresh-save default. Idempotent — only
## seeds when the dict is empty, so load_save_data hydrating the dict before
## _ready ran (test envs) is preserved.
func _seed_fresh_save_default() -> void:
	if _unlock_state.is_empty():
		_unlock_state["forest_reach"] = 0


## Subscribes to DungeonRunOrchestrator.floor_cleared_first_time per R3.
## Defensive lookup tolerates test envs where the orchestrator autoload is
## absent; CONNECT_DEFERRED is FORBIDDEN per Pass-8 BLOCKING-4 (AC-FU-14
## requires synchronous handler execution).
func _subscribe_to_orchestrator() -> void:
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if orch == null:
		return
	if not orch.has_signal("floor_cleared_first_time"):
		return
	if not orch.floor_cleared_first_time.is_connected(_on_floor_cleared_first_time):
		orch.floor_cleared_first_time.connect(_on_floor_cleared_first_time)


# ---------------------------------------------------------------------------
# Public API — query (R1)
# ---------------------------------------------------------------------------

## Per R1 + R10: 1-based floor_index. Returns false for floor_index < 1
## (R10 sentinel) and for any state other than ACCESSIBLE / CLEARED.
##
## Per AC-FU-13: this is the orchestrator-facing dispatch predicate.
func is_unlocked(floor_index: int) -> bool:
	var state: FloorState = get_floor_state(_active_biome_id(), floor_index)
	return state == FloorState.ACCESSIBLE or state == FloorState.CLEARED


## Per R7: returns true iff biome_id is in get_available_biomes() — i.e., the
## biome's status is "active" in DataRegistry.
func is_biome_available(biome_id: String) -> bool:
	# Per AC-FU-08 sub-AC: empty-string and unknown biome_id return false.
	if biome_id.is_empty():
		return false
	# Fast path: BIOME_FLOOR_COUNT is populated from DataRegistry's active
	# biomes only, so presence is sufficient.
	return BIOME_FLOOR_COUNT.has(biome_id)


## Per R6: derived predicate, NOT a persisted field.
## highest_cleared == BIOME_FLOOR_COUNT[biome_id] means the biome is fully
## cleared.
func is_biome_completed(biome_id: String) -> bool:
	if not is_biome_available(biome_id):
		return false
	var highest: int = _unlock_state.get(biome_id, 0)
	return highest == BIOME_FLOOR_COUNT.get(biome_id, 0) and highest > 0


## Per R7: returns the list of biome IDs whose Biome DB status is "active".
## UI consumers (Formation Assignment, Matchup Assignment, Guild Hall) call
## this and do NOT read Biome DB's status field directly.
func get_available_biomes() -> Array[String]:
	var result: Array[String] = []
	for biome_id_v: Variant in BIOME_FLOOR_COUNT.keys():
		result.append(String(biome_id_v))
	return result


## Per R1: returns the high-water unlock counter for biome_id. 0 means "no
## floors ever cleared in this biome; F1 is accessible." Returns 0 for
## unknown biome_id (caller sees the same default as fresh-save).
func get_highest_cleared(biome_id: String) -> int:
	return _unlock_state.get(biome_id, 0)


## Per §C.2 — single source of truth for floor state. is_unlocked + UI call
## sites both go through this method.
func get_floor_state(biome_id: String, floor_index: int) -> FloorState:
	if not is_biome_available(biome_id):
		return FloorState.UNAVAILABLE
	# Pass-4 edit: explicit floor-index range guards. R10 sentinel + post-
	# content-downgrade safety (`floor_index > N` for a biome whose floor
	# count shrank).
	if floor_index < 1:
		return FloorState.LOCKED
	var floor_count: int = BIOME_FLOOR_COUNT.get(biome_id, 0)
	if floor_index > floor_count:
		return FloorState.LOCKED
	# Pass-6 edit: debug_unlock_all override — placed AFTER range guards so
	# out-of-range queries still report LOCKED, BEFORE the highest/CLEARED
	# branches so all valid in-range floors report CLEARED uniformly.
	if debug_unlock_all and OS.is_debug_build():
		return FloorState.CLEARED
	var highest: int = _unlock_state.get(biome_id, 0)
	if floor_index <= highest:
		return FloorState.CLEARED
	if floor_index == highest + 1:
		return FloorState.ACCESSIBLE
	return FloorState.LOCKED


# ---------------------------------------------------------------------------
# Save/Load consumer surface (R1 + Save/Load GDD Rule 10)
# ---------------------------------------------------------------------------

## Per Save/Load Rule 10 + GDD §C.1 R1 — payload shape:
##   {"highest_cleared": {biome_id: int}}
##
## Missing key on load → fresh-save default per R2.
func get_save_data() -> Dictionary:
	# Duplicate the inner dict so external mutations on the returned payload
	# don't leak into _unlock_state.
	return {"highest_cleared": _unlock_state.duplicate()}


## Per R1-typing + GDD §E "load_save_data per-value processing order":
## type guard → lossy-cast warning → cast → under-range clamp → over-range
## clamp → write. Defensive defaults preserve invariants if the source dict
## is partial.
func load_save_data(d: Dictionary) -> void:
	# Missing top-level key → fresh-save default (R2). Note: per the GDD,
	# Save/Load strips the "floor_unlock" namespace wrapper before calling
	# this method; `d` is the unwrapped interior dict.
	var hc_in: Variant = d.get("highest_cleared", null)
	if not (hc_in is Dictionary):
		# Schema absent or non-Dictionary — clear in-memory state + reseed
		# fresh-save default. Per GDD §C.1 R1: "Missing key on load →
		# fresh-save default (R2)" — the loaded state replaces in-memory
		# state, so a missing key means the saved state had no unlock
		# progress and we reflect that by resetting.
		_unlock_state.clear()
		_seed_fresh_save_default()
		return

	var hc: Dictionary = hc_in as Dictionary
	# Reset and reload. R2 still applies if the loaded dict is empty.
	_unlock_state.clear()

	for key_v: Variant in hc.keys():
		var biome_id: String = str(key_v)
		var raw_value: Variant = hc[key_v]

		# Step 1: type guard. Per Pass-4 edit: non-numeric values (e.g., "foo",
		# null, true/false) silently zero via int(...) coercion if not guarded.
		# Pass-8 edit: explicit warn before cast — load-bearing for tampered-
		# save defense.
		if typeof(raw_value) not in [TYPE_INT, TYPE_FLOAT]:
			_warning_logger.call(
				"FloorUnlockSystem.load_save_data: non-numeric value for biome_id='%s' (type=%d); writing 0"
				% [biome_id, typeof(raw_value)]
			)
			_unlock_state[biome_id] = 0
			continue

		# Step 2: lossy-cast warning. JSON numeric values come back as float;
		# whole-number floats cast cleanly, fractional floats lose precision.
		var float_value: float = float(raw_value)
		if float_value != floor(float_value):
			_warning_logger.call(
				"FloorUnlockSystem.load_save_data: lossy float→int cast for biome_id='%s' (value=%f → %d)"
				% [biome_id, float_value, int(float_value)]
			)

		# Step 3: cast.
		var cast_value: int = int(raw_value)

		# Step 4: under-range clamp. Negative values clamp to 0 with warning
		# (R4 exception 2).
		if cast_value < 0:
			_warning_logger.call(
				"FloorUnlockSystem.load_save_data: under-range biome_id='%s' (value=%d clamped to 0)"
				% [biome_id, cast_value]
			)
			cast_value = 0

		# Step 5: over-range clamp. If a content patch shrunk the biome's
		# floor count, clamp to the new max (R4 exception 1).
		var floor_count: int = BIOME_FLOOR_COUNT.get(biome_id, 0)
		if cast_value > floor_count and floor_count > 0:
			_warning_logger.call(
				"FloorUnlockSystem.load_save_data: over-range biome_id='%s' (value=%d clamped to %d, content shrank?)"
				% [biome_id, cast_value, floor_count]
			)
			cast_value = floor_count

		# Step 6: write. Per Pass-8 stability note — Sub-AC 08-* asserts
		# _unlock_state.has(biome_id) post-write; do not skip the write even
		# when the value lands at 0.
		_unlock_state[biome_id] = cast_value

	# R2 default: if the loaded payload had no entry for forest_reach (or
	# whatever the active biome is), seed it. This protects against partial
	# saves that drop the active biome.
	_seed_fresh_save_default()


# ---------------------------------------------------------------------------
# Signal handler (R3 + R9)
# ---------------------------------------------------------------------------

## Per R9: idempotent advance via max(current, floor_index). Three early-
## return validations (Pass-9 edits): biome availability, BIOME_FLOOR_COUNT
## presence, floor_index range — each routed through _error_logger for DI
## consistency.
##
## losing_run is accepted but NOT read here per R5 — Pillar 1 commitment:
## "the guild was present there — and presence, in Lantern Guild, is what
## counts." Other subscribers may branch on losing_run; this system does not.
func _on_floor_cleared_first_time(floor_index: int, biome_id: String, _losing_run: bool) -> void:
	if not is_biome_available(biome_id):
		_error_logger.call(
			"FloorUnlockSystem: unavailable biome_id='%s' attempted advance"
			% biome_id
		)
		return
	if not BIOME_FLOOR_COUNT.has(biome_id):
		_error_logger.call(
			"FloorUnlockSystem: biome_id='%s' not in BIOME_FLOOR_COUNT (DataRegistry miss?)"
			% biome_id
		)
		return
	if floor_index < 1 or floor_index > BIOME_FLOOR_COUNT[biome_id]:
		_error_logger.call(
			"FloorUnlockSystem: invalid floor_index=%d for biome=%s (valid range 1..%d)"
			% [floor_index, biome_id, BIOME_FLOOR_COUNT[biome_id]]
		)
		return
	# R9 canonical advance: max() form. Idempotent on duplicate signals.
	var current: int = _unlock_state.get(biome_id, 0)
	var h_new: int = max(current, floor_index)
	if h_new > current:
		_unlock_state[biome_id] = h_new
	# else: silent idempotent no-op


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Returns the active biome ID for is_unlocked queries. MVP: returns
## active_biome_mvp. V1.0: replaced with biome-context injection per GDD
## R1 V1.0 evolution note.
func _active_biome_id() -> String:
	return active_biome_mvp


# ---------------------------------------------------------------------------
# Debug/test API (R1 — guarded by OS.is_debug_build())
# ---------------------------------------------------------------------------

## Test/debug hook to bypass the signal-driven advance and directly set the
## counter. Production callers MUST NOT use this — only the signal handler
## may write _unlock_state in a normally-progressing session.
func debug_set_highest_cleared(biome_id: String, floor_index: int) -> void:
	if not OS.is_debug_build():
		_warning_logger.call(
			"FloorUnlockSystem.debug_set_highest_cleared: blocked in production build"
		)
		return
	_unlock_state[biome_id] = floor_index


## Test/debug hook to reset _unlock_state to fresh-save default.
func debug_reset() -> void:
	if not OS.is_debug_build():
		_warning_logger.call("FloorUnlockSystem.debug_reset: blocked in production build")
		return
	_unlock_state.clear()
	_seed_fresh_save_default()
