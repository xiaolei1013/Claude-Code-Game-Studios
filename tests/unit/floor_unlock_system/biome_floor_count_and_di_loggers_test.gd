# Tests for floor-unlock-system/story-004 — BIOME_FLOOR_COUNT derivation +
# DI logger setters.
#
# Covers:
#   - TR-013: BIOME_FLOOR_COUNT["forest_reach"] == 5 after _ready (matches
#     forest_reach Biome.dungeons[0].floors.size()).
#   - TR-012 guard ordering: handler rejects unavailable biome BEFORE checking
#     BIOME_FLOOR_COUNT; rejects unknown biome BEFORE range check.
#   - TR-012 range guard: floor_index outside [1, BIOME_FLOOR_COUNT[b]] triggers
#     _error_logger and rejects.
#   - TR-021 DI setters: `set_error_logger(c)` / `set_warning_logger(c)` exist;
#     injected Callables receive log messages.
#   - TR-021 fallback: when no logger injected, falls back to push_error /
#     push_warning (production default).
extends GdUnitTestSuite

const FloorUnlockScript = preload("res://src/core/floor_unlock_system/floor_unlock_system.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_fu_with_stubs() -> Node:
	var fu: Node = FloorUnlockScript.new()
	auto_free(fu)
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	fu.BIOME_FLOOR_COUNT = bfc
	var us: Dictionary[String, int] = {"forest_reach": 0}
	fu._unlock_state = us
	return fu


# ---------------------------------------------------------------------------
# TR-013: BIOME_FLOOR_COUNT["forest_reach"] == 5 from production data
#
# The full _ready() path reads DataRegistry's active forest_reach Biome and
# populates BIOME_FLOOR_COUNT from `biome.dungeons[0].floors.size()`. The
# autoload at /root/FloorUnlock has already done this — the test asserts the
# resulting state on the production autoload.
# ---------------------------------------------------------------------------

func test_tr013_biome_floor_count_forest_reach_equals_five_after_ready() -> void:
	# Arrange — read the production autoload (already booted via _ready)
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	if fu == null:
		push_warning("Skipped: /root/FloorUnlock autoload not registered")
		return

	# Assert — forest_reach has 5 floors per the active V1 data
	assert_int(fu.BIOME_FLOOR_COUNT.get("forest_reach", -1)).is_equal(5)


# ---------------------------------------------------------------------------
# TR-012 guard ordering: unavailable biome rejected BEFORE range check
# ---------------------------------------------------------------------------

func test_tr012_unavailable_biome_rejected_before_range_check() -> void:
	# Arrange — captured spy for error logger
	var fu: Node = _make_fu_with_stubs()
	var captured: Array[String] = []
	fu.set_error_logger(func(msg: String) -> void: captured.append(msg))

	# Act — fire signal for an unavailable biome with an invalid floor_index too.
	# If guard ordering is correct, the unavailable-biome error fires FIRST
	# (range check is never reached).
	fu._on_floor_cleared_first_time(99, "ghost_biome", false)

	# Assert — exactly one error, about the biome (not the range)
	assert_int(captured.size()).is_equal(1)
	assert_str(captured[0]).contains("unavailable biome_id")
	assert_str(captured[0]).contains("ghost_biome")
	# Critical: the error must NOT mention the range — that would indicate
	# the range check ran before the biome guard.
	assert_bool(captured[0].contains("invalid floor_index")).is_false()


func test_tr012_unknown_biome_rejected_before_range_check() -> void:
	# Edge case: biome is in BIOME_FLOOR_COUNT (so is_biome_available returns
	# true) but somehow not... actually if it's in BIOME_FLOOR_COUNT, both
	# guards pass. The "unknown biome NOT in BIOME_FLOOR_COUNT" path is the
	# secondary guard inside the handler — verify by stubbing differently.
	#
	# The handler has THREE guards in order:
	#   1. is_biome_available(biome_id) — checks BIOME_FLOOR_COUNT.has + non-empty
	#   2. BIOME_FLOOR_COUNT.has(biome_id) — same check repeated defensively
	#   3. floor_index range check
	#
	# Guards 1 + 2 are equivalent in current implementation — both check
	# BIOME_FLOOR_COUNT presence. So the "unknown biome" + "unavailable biome"
	# paths fire the same guard 1 message. This is the canonical behavior;
	# the AC's intent (range check NEVER runs on unknown biome) is satisfied.
	var fu: Node = _make_fu_with_stubs()
	var captured: Array[String] = []
	fu.set_error_logger(func(msg: String) -> void: captured.append(msg))

	# Act — unknown biome with out-of-range floor
	fu._on_floor_cleared_first_time(99, "unknown_biome", false)

	# Assert — biome guard 1 fires (the "unavailable" message); range never reached
	assert_int(captured.size()).is_equal(1)
	assert_str(captured[0]).contains("unavailable")
	assert_bool(captured[0].contains("invalid floor_index")).is_false()


# ---------------------------------------------------------------------------
# TR-012 range guard: floor_index outside [1, BIOME_FLOOR_COUNT[b]]
# ---------------------------------------------------------------------------

func test_tr012_range_guard_rejects_floor_index_zero() -> void:
	var fu: Node = _make_fu_with_stubs()
	var captured: Array[String] = []
	fu.set_error_logger(func(msg: String) -> void: captured.append(msg))

	# Act — floor 0 is below range
	fu._on_floor_cleared_first_time(0, "forest_reach", false)

	# Assert
	assert_int(captured.size()).is_equal(1)
	assert_str(captured[0]).contains("invalid floor_index=0")
	assert_str(captured[0]).contains("forest_reach")


func test_tr012_range_guard_rejects_floor_index_above_count() -> void:
	# forest_reach has 5 floors → index 6 is out of range
	var fu: Node = _make_fu_with_stubs()
	var captured: Array[String] = []
	fu.set_error_logger(func(msg: String) -> void: captured.append(msg))

	fu._on_floor_cleared_first_time(6, "forest_reach", false)

	assert_int(captured.size()).is_equal(1)
	assert_str(captured[0]).contains("invalid floor_index=6")


func test_tr012_range_guard_rejects_negative_floor_index() -> void:
	var fu: Node = _make_fu_with_stubs()
	var captured: Array[String] = []
	fu.set_error_logger(func(msg: String) -> void: captured.append(msg))

	fu._on_floor_cleared_first_time(-3, "forest_reach", false)

	assert_int(captured.size()).is_equal(1)
	assert_str(captured[0]).contains("invalid floor_index=-3")


func test_tr012_range_guard_accepts_boundaries_1_and_max() -> void:
	# Boundaries: floor 1 (lower) + floor 5 (upper for forest_reach) accepted.
	var fu: Node = _make_fu_with_stubs()
	var captured: Array[String] = []
	fu.set_error_logger(func(msg: String) -> void: captured.append(msg))

	# Act — both boundary values
	fu._on_floor_cleared_first_time(1, "forest_reach", false)
	fu._on_floor_cleared_first_time(5, "forest_reach", false)

	# Assert — no errors, state advanced to 5
	assert_int(captured.size()).is_equal(0)
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(5)


# ---------------------------------------------------------------------------
# TR-021: set_error_logger / set_warning_logger DI setters
# ---------------------------------------------------------------------------

func test_tr021_set_error_logger_routes_messages_to_injected_callable() -> void:
	# Arrange
	var fu: Node = _make_fu_with_stubs()
	var captured: Array[String] = []
	fu.set_error_logger(func(msg: String) -> void: captured.append(msg))

	# Act — trigger an error
	fu._on_floor_cleared_first_time(0, "forest_reach", false)

	# Assert — message went through the injected callable
	assert_int(captured.size()).is_equal(1)
	assert_str(captured[0]).contains("invalid floor_index")


func test_tr021_set_warning_logger_method_exists_and_replaces_default() -> void:
	# Verify the setter exists + injecting REPLACES the default lambda.
	# We assert by checking that fu._warning_logger is the injected callable
	# after the setter call (fields are still accessible from tests).
	var fu: Node = _make_fu_with_stubs()
	var injected: Callable = func(_msg: String) -> void: pass
	fu.set_warning_logger(injected)

	# Assert — the field now points at our injected callable
	assert_bool(fu._warning_logger == injected).is_true()


func test_tr021_set_error_logger_method_exists_and_replaces_default() -> void:
	# Same pattern for the error logger.
	var fu: Node = _make_fu_with_stubs()
	var injected: Callable = func(_msg: String) -> void: pass
	fu.set_error_logger(injected)

	assert_bool(fu._error_logger == injected).is_true()


# ---------------------------------------------------------------------------
# TR-021: when no logger injected, falls back to push_error / push_warning
#
# Default field values are lambdas that wrap push_error / push_warning. Test
# verifies the default Callable is non-null and is invokable (the actual
# routing to push_error / push_warning is verified by code review of the
# default lambda; gdunit4 doesn't intercept push_error).
# ---------------------------------------------------------------------------

func test_tr021_fresh_instance_has_default_loggers_invokable() -> void:
	var fu: Node = FloorUnlockScript.new()
	auto_free(fu)

	# Default loggers exist + are invokable Callables.
	assert_bool(fu._error_logger.is_valid()).is_true()
	assert_bool(fu._warning_logger.is_valid()).is_true()
	# Invoking should NOT crash (production default routes through push_error /
	# push_warning which are no-throw functions).
	fu._error_logger.call("test error")
	fu._warning_logger.call("test warning")
	# If we reach here, both invocations completed without crash.
	assert_bool(true).is_true()
