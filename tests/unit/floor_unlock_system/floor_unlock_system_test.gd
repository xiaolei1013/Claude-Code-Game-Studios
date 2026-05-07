# Sprint 11 S11-X1: FloorUnlockSystem implementation tests.
#
# Covers the GDD R1-R10 + §C.2 + Save/Load consumer contract:
#   - Autoload presence + project.godot lockstep + rank 10 ordering.
#   - Public API surface (R1) — method existence + signatures.
#   - Fresh-save default (R2) — {"forest_reach": 0}.
#   - Signal-handler advance (R3 + R9) — idempotent, LOSING-identical (R5).
#   - FloorState derivation (§C.2) — 4 states + range guards.
#   - is_unlocked, is_biome_*, get_highest_cleared (R1).
#   - get_save_data / load_save_data round-trip + per-value processing
#     (type guard, clamp, lossy-cast warning) per GDD §E.
#
# Pattern: tests use isolated FloorUnlockSystem.new() instances (NOT the live
# autoload) where possible to avoid cross-suite state contamination. The
# live autoload is read in autoload-presence + ordering tests only.
#
# Hygiene-barrier pattern (S10-S4 lesson): live autoload tests use
# before_test/after_test reset.
extends GdUnitTestSuite

const FloorUnlockScript = preload("res://src/core/floor_unlock_system/floor_unlock_system.gd")


# ---------------------------------------------------------------------------
# Test fixtures — fresh instance with stub BIOME_FLOOR_COUNT
# ---------------------------------------------------------------------------

# Captured warning/error log for DI assertions.
var _captured_warnings: Array[String] = []
var _captured_errors: Array[String] = []


func _make_floor_unlock_with_stubs() -> Node:
	# Construct a fresh instance NOT added to the tree — _ready() does not
	# fire, so DataRegistry / signal-subscription paths are bypassed. Tests
	# manually populate BIOME_FLOOR_COUNT to mimic post-_ready state.
	var fu: Node = FloorUnlockScript.new()
	auto_free(fu)
	# Stub BIOME_FLOOR_COUNT for forest_reach (5 floors per MVP). The
	# production field is typed Dictionary[String, int]; assigning an
	# untyped {"forest_reach": 5} literal raises a runtime type error.
	# Use explicit typed local variable to satisfy the typed-dict contract.
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	fu.BIOME_FLOOR_COUNT = bfc
	# Seed fresh-save default per R2 — same typed-dict treatment.
	var us: Dictionary[String, int] = {"forest_reach": 0}
	fu._unlock_state = us
	# Wire DI-logger spies.
	_captured_warnings.clear()
	_captured_errors.clear()
	fu._warning_logger = func(msg: String) -> void: _captured_warnings.append(msg)
	fu._error_logger = func(msg: String) -> void: _captured_errors.append(msg)
	return fu


# ===========================================================================
# Group A — autoload presence + project.godot lockstep (R1 surface contract)
# ===========================================================================

func test_floor_unlock_autoload_resolves_at_root() -> void:
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	assert_object(fu).is_not_null()
	assert_bool(fu.get_script() == FloorUnlockScript).is_true()


func test_floor_unlock_registered_in_project_godot() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load("res://project.godot")
	assert_int(err).is_equal(OK)
	var path: String = cfg.get_value("autoload", "FloorUnlock", "")
	assert_str(path).is_equal("*res://src/core/floor_unlock_system/floor_unlock_system.gd")


func test_floor_unlock_appears_after_scene_manager_in_project_godot() -> void:
	# Per ADR-0003 + architecture.md rank table: rank 10 (FloorUnlockSystem)
	# is between rank 8 (SceneManager) and rank 14 (DungeonRunOrchestrator).
	var file: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	var content: String = file.get_as_text()
	file.close()
	var idx_sm: int = content.find("SceneManager=")
	var idx_fu: int = content.find("FloorUnlock=")
	var idx_orch: int = content.find("DungeonRunOrchestrator=")
	assert_int(idx_sm).is_greater(0)
	assert_int(idx_fu).is_greater(idx_sm)
	assert_int(idx_orch).is_greater(idx_fu)


# ===========================================================================
# Group B — R1 public API method existence
# ===========================================================================

func test_public_api_methods_exist() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	# R1 query API
	assert_bool(fu.has_method("is_unlocked")).is_true()
	assert_bool(fu.has_method("is_biome_available")).is_true()
	assert_bool(fu.has_method("is_biome_completed")).is_true()
	assert_bool(fu.has_method("get_available_biomes")).is_true()
	assert_bool(fu.has_method("get_highest_cleared")).is_true()
	assert_bool(fu.has_method("get_floor_state")).is_true()
	# R1 Save/Load consumer surface
	assert_bool(fu.has_method("get_save_data")).is_true()
	assert_bool(fu.has_method("load_save_data")).is_true()
	# R1 debug/test API
	assert_bool(fu.has_method("debug_set_highest_cleared")).is_true()
	assert_bool(fu.has_method("debug_reset")).is_true()


# ===========================================================================
# Group C — R2 fresh-save default state
# ===========================================================================

func test_fresh_save_default_is_forest_reach_zero() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	# Stubbed _unlock_state per fixture matches R2 default.
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)


func test_fresh_save_does_not_seed_planned_v1_biomes() -> void:
	# R2: only forest_reach is seeded; planned_v1 biomes signal "unavailable"
	# via absence from get_available_biomes (which reads BIOME_FLOOR_COUNT).
	var fu: Node = _make_floor_unlock_with_stubs()
	assert_int(fu.get_highest_cleared("sunken_ruins")).is_equal(0)  # default
	assert_bool(fu.is_biome_available("sunken_ruins")).is_false()


# ===========================================================================
# Group D — §C.2 FloorState derivation (4 states + range guards)
# ===========================================================================

func test_get_floor_state_unavailable_for_unknown_biome() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	assert_int(fu.get_floor_state("planned_v1_biome", 1)).is_equal(FloorUnlockScript.FloorState.UNAVAILABLE)


func test_get_floor_state_locked_for_floor_index_zero() -> void:
	# R10 sentinel: floor_index < 1 returns LOCKED (not UNAVAILABLE — biome
	# IS available; the floor itself is invalid).
	var fu: Node = _make_floor_unlock_with_stubs()
	assert_int(fu.get_floor_state("forest_reach", 0)).is_equal(FloorUnlockScript.FloorState.LOCKED)


func test_get_floor_state_locked_for_floor_index_above_count() -> void:
	# Out-of-biome-range: floor_index > BIOME_FLOOR_COUNT[biome]. LOCKED, not
	# UNAVAILABLE.
	var fu: Node = _make_floor_unlock_with_stubs()
	assert_int(fu.get_floor_state("forest_reach", 6)).is_equal(FloorUnlockScript.FloorState.LOCKED)


func test_get_floor_state_accessible_for_first_floor_on_fresh_save() -> void:
	# Fresh save: highest=0, F1 == highest+1 == ACCESSIBLE.
	var fu: Node = _make_floor_unlock_with_stubs()
	assert_int(fu.get_floor_state("forest_reach", 1)).is_equal(FloorUnlockScript.FloorState.ACCESSIBLE)


func test_get_floor_state_locked_for_floors_beyond_accessible() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	# F2..F5 are all LOCKED on fresh save (only F1 accessible).
	for f: int in [2, 3, 4, 5]:
		assert_int(fu.get_floor_state("forest_reach", f)).is_equal(FloorUnlockScript.FloorState.LOCKED)


func test_get_floor_state_cleared_for_floors_at_or_below_highest() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	fu._unlock_state["forest_reach"] = 3
	# F1, F2, F3 = CLEARED; F4 = ACCESSIBLE; F5 = LOCKED.
	assert_int(fu.get_floor_state("forest_reach", 1)).is_equal(FloorUnlockScript.FloorState.CLEARED)
	assert_int(fu.get_floor_state("forest_reach", 2)).is_equal(FloorUnlockScript.FloorState.CLEARED)
	assert_int(fu.get_floor_state("forest_reach", 3)).is_equal(FloorUnlockScript.FloorState.CLEARED)
	assert_int(fu.get_floor_state("forest_reach", 4)).is_equal(FloorUnlockScript.FloorState.ACCESSIBLE)
	assert_int(fu.get_floor_state("forest_reach", 5)).is_equal(FloorUnlockScript.FloorState.LOCKED)


# ===========================================================================
# Group E — is_unlocked (R1 + R10 + dispatch predicate)
# ===========================================================================

func test_is_unlocked_returns_true_for_accessible_floor() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	assert_bool(fu.is_unlocked(1)).is_true()  # F1 accessible


func test_is_unlocked_returns_false_for_locked_floor() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	assert_bool(fu.is_unlocked(2)).is_false()  # F2 locked on fresh save


func test_is_unlocked_returns_false_for_floor_index_zero() -> void:
	# R10 sentinel.
	var fu: Node = _make_floor_unlock_with_stubs()
	assert_bool(fu.is_unlocked(0)).is_false()


func test_is_unlocked_returns_true_for_cleared_floor() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	fu._unlock_state["forest_reach"] = 2
	# F1 + F2 CLEARED → both is_unlocked.
	assert_bool(fu.is_unlocked(1)).is_true()
	assert_bool(fu.is_unlocked(2)).is_true()


# ===========================================================================
# Group F — Signal handler (R3 + R5 + R9 idempotent advance)
# ===========================================================================

func test_signal_handler_advances_unlock_on_first_clear() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	fu._on_floor_cleared_first_time(1, "forest_reach", false)
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(1)


func test_signal_handler_idempotent_on_duplicate_signal() -> void:
	# R9: max() form handles duplicates as silent no-ops.
	var fu: Node = _make_floor_unlock_with_stubs()
	fu._on_floor_cleared_first_time(1, "forest_reach", false)
	fu._on_floor_cleared_first_time(1, "forest_reach", false)
	fu._on_floor_cleared_first_time(1, "forest_reach", false)
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(1)


func test_signal_handler_does_not_decrement_on_lower_floor_replay() -> void:
	# R4: monotone non-decreasing within a session.
	var fu: Node = _make_floor_unlock_with_stubs()
	fu._on_floor_cleared_first_time(3, "forest_reach", false)  # advance to 3
	fu._on_floor_cleared_first_time(1, "forest_reach", false)  # replay F1
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(3)  # unchanged


func test_signal_handler_losing_run_advances_identically_to_win() -> void:
	# R5: LOSING first-clear advances unlock identically. losing_run param is
	# accepted but not read by this system.
	var fu_win: Node = _make_floor_unlock_with_stubs()
	fu_win._on_floor_cleared_first_time(1, "forest_reach", false)
	var fu_lose: Node = _make_floor_unlock_with_stubs()
	fu_lose._on_floor_cleared_first_time(1, "forest_reach", true)
	# Both produce identical state.
	assert_int(fu_win.get_highest_cleared("forest_reach")).is_equal(1)
	assert_int(fu_lose.get_highest_cleared("forest_reach")).is_equal(1)


func test_signal_handler_rejects_unavailable_biome_with_error_log() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	fu._on_floor_cleared_first_time(1, "planned_v1_biome", false)
	# State unchanged; error logged via DI.
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)
	assert_int(_captured_errors.size()).is_equal(1)
	assert_str(_captured_errors[0]).contains("unavailable biome_id")


func test_signal_handler_rejects_invalid_floor_index_with_error_log() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	# Floor 0 is sentinel; floor 6 is out of range (BIOME_FLOOR_COUNT[forest_reach]=5).
	fu._on_floor_cleared_first_time(0, "forest_reach", false)
	assert_int(_captured_errors.size()).is_equal(1)
	assert_str(_captured_errors[0]).contains("invalid floor_index=0")
	_captured_errors.clear()
	fu._on_floor_cleared_first_time(6, "forest_reach", false)
	assert_int(_captured_errors.size()).is_equal(1)
	assert_str(_captured_errors[0]).contains("invalid floor_index=6")


# ===========================================================================
# Group F2 — floor_unlocked signal (R11 — UI live-update on frontier advance)
# ===========================================================================

# Array-spy pattern per project_gdunit4_signal_api.md: lambdas capture by value,
# so the spy must be a reference type (Array) to be mutated from inside the
# capture closure. Each test wires a fresh spy to the freshly-instantiated
# FloorUnlockSystem so emissions across tests don't bleed.

func test_floor_unlocked_signal_emits_on_frontier_advance() -> void:
	# Arrange — fresh save (highest_cleared=0); F1 ACCESSIBLE, F2 LOCKED.
	var fu: Node = _make_floor_unlock_with_stubs()
	var captured: Array = []
	fu.floor_unlocked.connect(
		func(biome_id: String, floor_index: int) -> void:
			captured.append({"biome_id": biome_id, "floor_index": floor_index})
	)

	# Act — clear F1; frontier advances 0 → 1 ⇒ F2 transitions LOCKED → ACCESSIBLE.
	fu._on_floor_cleared_first_time(1, "forest_reach", false)

	# Assert — exactly one emission for F2.
	assert_int(captured.size()).is_equal(1)
	assert_str(captured[0]["biome_id"]).is_equal("forest_reach")
	assert_int(captured[0]["floor_index"]).is_equal(2)


func test_floor_unlocked_signal_does_not_emit_on_idempotent_replay() -> void:
	# R9 idempotent path: re-clear of an already-cleared floor must NOT
	# re-fire floor_unlocked (the frontier did not move).
	var fu: Node = _make_floor_unlock_with_stubs()
	fu._unlock_state["forest_reach"] = 2  # F1 + F2 already cleared
	var captured: Array = []
	fu.floor_unlocked.connect(
		func(_b: String, _f: int) -> void: captured.append(true)
	)

	# Act — replay F1 (already cleared; no advance).
	fu._on_floor_cleared_first_time(1, "forest_reach", false)
	# Act — replay F2 (still no advance).
	fu._on_floor_cleared_first_time(2, "forest_reach", false)

	# Assert — zero emissions; frontier never moved.
	assert_int(captured.size()).is_equal(0)


func test_floor_unlocked_signal_does_not_emit_on_final_floor_clear() -> void:
	# Final-floor clear (F5 in MVP) advances highest_cleared to count; no
	# further floor exists to unlock — the signal must not fire.
	var fu: Node = _make_floor_unlock_with_stubs()
	fu._unlock_state["forest_reach"] = 4  # frontier at F5 (ACCESSIBLE)
	var captured: Array = []
	fu.floor_unlocked.connect(
		func(_b: String, _f: int) -> void: captured.append(true)
	)

	# Act — clear F5; frontier advances 4 → 5; biome is now CLEARED.
	fu._on_floor_cleared_first_time(5, "forest_reach", false)

	# Assert — zero emissions (no F6 to unlock).
	assert_int(captured.size()).is_equal(0)
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(5)


func test_floor_unlocked_signal_emits_on_losing_first_clear() -> void:
	# R5 + R11 interaction: LOSING run advances unlock identically to WIN, so
	# floor_unlocked fires identically too — Pillar 1 fanfare equality.
	var fu: Node = _make_floor_unlock_with_stubs()
	var captured: Array = []
	fu.floor_unlocked.connect(
		func(b: String, f: int) -> void:
			captured.append({"biome_id": b, "floor_index": f})
	)

	# Act — LOSING first-clear of F1.
	fu._on_floor_cleared_first_time(1, "forest_reach", true)

	# Assert — emission identical to WIN path.
	assert_int(captured.size()).is_equal(1)
	assert_int(captured[0]["floor_index"]).is_equal(2)


func test_floor_unlocked_signal_does_not_emit_on_invalid_floor_or_biome() -> void:
	# Validation rejection paths (out-of-range index, unavailable biome) must
	# not emit floor_unlocked — the early-return guards run before any state
	# mutation.
	var fu: Node = _make_floor_unlock_with_stubs()
	var captured: Array = []
	fu.floor_unlocked.connect(
		func(_b: String, _f: int) -> void: captured.append(true)
	)

	# Act — invalid: index 0 (sentinel), index 6 (out-of-range), unavailable biome.
	fu._on_floor_cleared_first_time(0, "forest_reach", false)
	fu._on_floor_cleared_first_time(6, "forest_reach", false)
	fu._on_floor_cleared_first_time(1, "planned_v1_biome", false)

	# Assert — no emissions; rejected at error-log path.
	assert_int(captured.size()).is_equal(0)


func test_floor_unlocked_signal_does_not_emit_during_load_save_data() -> void:
	# Hydration must be silent (R3 + R11): load_save_data writes _unlock_state
	# directly, bypassing the signal handler — no UI live-update fanfare on
	# session restore.
	var fu: Node = _make_floor_unlock_with_stubs()
	var captured: Array = []
	fu.floor_unlocked.connect(
		func(_b: String, _f: int) -> void: captured.append(true)
	)

	# Act — load a save with F3 already cleared.
	fu.load_save_data({"highest_cleared": {"forest_reach": 3}})

	# Assert — state hydrated, no signal emission.
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(3)
	assert_int(captured.size()).is_equal(0)


# ===========================================================================
# Group G — get_save_data / load_save_data (Save/Load Rule 10 contract)
# ===========================================================================

func test_get_save_data_returns_canonical_schema() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	fu._unlock_state["forest_reach"] = 3
	var data: Dictionary = fu.get_save_data()
	assert_bool(data.has("highest_cleared")).is_true()
	var hc: Dictionary = data["highest_cleared"]
	assert_int(int(hc["forest_reach"])).is_equal(3)


func test_get_save_data_returned_dict_is_independent_of_internal_state() -> void:
	# Mutating the returned payload must not leak into _unlock_state.
	var fu: Node = _make_floor_unlock_with_stubs()
	var data: Dictionary = fu.get_save_data()
	data["highest_cleared"]["forest_reach"] = 99
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)  # unchanged


func test_load_save_data_round_trips_canonical_payload() -> void:
	var fu: Node = _make_floor_unlock_with_stubs()
	var saved: Dictionary = {"highest_cleared": {"forest_reach": 3}}
	fu.load_save_data(saved)
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(3)


func test_load_save_data_missing_top_level_key_falls_back_to_default() -> void:
	# GDD §C.1 R1: "Missing key on load → fresh-save default (R2)."
	var fu: Node = _make_floor_unlock_with_stubs()
	fu._unlock_state["forest_reach"] = 5  # pre-existing state
	fu.load_save_data({})
	# Cleared + reseeded to default (0).
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)


func test_load_save_data_clamps_under_range_negative_to_zero() -> void:
	# R4 exception 2 + GDD §E step 4: negative value clamps to 0 with warning.
	var fu: Node = _make_floor_unlock_with_stubs()
	fu.load_save_data({"highest_cleared": {"forest_reach": -3}})
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)
	assert_int(_captured_warnings.size()).is_greater_equal(1)


func test_load_save_data_clamps_over_range_to_floor_count() -> void:
	# R4 exception 1 + GDD §E step 5: over-range clamps to BIOME_FLOOR_COUNT.
	var fu: Node = _make_floor_unlock_with_stubs()
	fu.load_save_data({"highest_cleared": {"forest_reach": 999}})
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(5)  # MVP cap
	assert_int(_captured_warnings.size()).is_greater_equal(1)


func test_load_save_data_warns_on_non_numeric_value_and_writes_zero() -> void:
	# Pass-4 edit + Sub-AC 08-non-numeric: non-numeric values must be type-
	# guarded BEFORE the int() cast (else int("foo") == 0 silently).
	var fu: Node = _make_floor_unlock_with_stubs()
	fu.load_save_data({"highest_cleared": {"forest_reach": "tampered"}})
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)
	assert_int(_captured_warnings.size()).is_greater_equal(1)


func test_load_save_data_warns_on_lossy_float_cast() -> void:
	# GDD §E step 2: lossy float→int cast emits warning.
	var fu: Node = _make_floor_unlock_with_stubs()
	fu.load_save_data({"highest_cleared": {"forest_reach": 2.7}})
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(2)  # int truncation
	# Look for the lossy-cast warning specifically (not the under/over-range ones).
	var found_lossy: bool = false
	for msg: String in _captured_warnings:
		if "lossy" in msg.to_lower():
			found_lossy = true
			break
	assert_bool(found_lossy).is_true()
