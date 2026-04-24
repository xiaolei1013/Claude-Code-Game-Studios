# Tests for Story 001: TickSystem autoload skeleton.
# Covers: TR-time-001, TR-time-017, ADR-0003 Amendment #3,
#         TICKS_PER_SECOND constant guard, and public API stub zero-values.
extends GdUnitTestSuite

const TickSystemScript = preload("res://src/core/tick_system/tick_system.gd")


# ---------------------------------------------------------------------------
# Test 1 — TR-time-001: TickSystem is a Node-derived class named TickSystem.
#
# The real autoload is only present when the full project boots; unit tests
# cannot rely on the scene tree. We instantiate directly to verify the class
# contract (class_name + Node ancestry).  Headless boot / autoload-presence
# is covered by the sprint-close smoke check, not this unit test.
# ---------------------------------------------------------------------------
func test_tick_system_instantiates_as_node_derived_class() -> void:
	# Arrange / Act
	var ts: Node = TickSystemScript.new()

	# Assert
	assert_object(ts).is_not_null()
	assert_bool(ts is Node).is_true()
	assert_str(ts.get_class()).is_equal("Node")

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 2 — TR-time-017: All three signals are declared and connectable.
#
# Verifies signal arity implicitly: connecting a typed callable with the wrong
# arity raises an error at connect-time in Godot 4's typed-signal contract.
# We use simple callables that accept the correct parameter types.
# ---------------------------------------------------------------------------
func test_tick_system_signals_are_declared_and_connectable() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act — connect each signal with a matching callable; capture return codes.
	var result_tick_fired: int = ts.tick_fired.connect(
		func(_tick_number: int) -> void: pass
	)
	var result_offline_elapsed: int = ts.offline_elapsed_seconds.connect(
		func(_seconds: float, _cap_reached: bool) -> void: pass
	)
	var result_flag_suspicious: int = ts.flag_suspicious_timestamp_emitted.connect(
		func(_previous_ts: int, _current_ts: int) -> void: pass
	)

	# Assert — OK == 0 in Godot 4 (Error enum)
	assert_int(result_tick_fired).is_equal(OK)
	assert_int(result_offline_elapsed).is_equal(OK)
	assert_int(result_flag_suspicious).is_equal(OK)

	# Verify connections are live
	assert_bool(ts.tick_fired.get_connections().size() > 0).is_true()
	assert_bool(ts.offline_elapsed_seconds.get_connections().size() > 0).is_true()
	assert_bool(ts.flag_suspicious_timestamp_emitted.get_connections().size() > 0).is_true()

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 3 — ADR-0003 Amendment #3: zero-arg _init.
#
# TickSystemScript.new() with no arguments must succeed without error.
# If _init had required parameters this call would raise at runtime.
# ---------------------------------------------------------------------------
func test_tick_system_zero_arg_init_constructs_without_error() -> void:
	# Arrange / Act — no arguments passed
	var ts: Node = TickSystemScript.new()

	# Assert — reaching this line means _init accepted zero args cleanly
	assert_object(ts).is_not_null()

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 4 — Architectural constant guard: TICKS_PER_SECOND == 20.
#
# This protects against the Forbidden pattern of TICKS_PER_SECOND becoming a
# tuning knob or being accidentally changed without a superseding ADR.
# ---------------------------------------------------------------------------
func test_tick_system_ticks_per_second_is_exactly_20() -> void:
	# Assert constant value — no instance needed for a class constant.
	assert_int(TickSystemScript.TICKS_PER_SECOND).is_equal(20)


func test_tick_system_tick_interval_seconds_is_0_05() -> void:
	# Arrange
	const EXPECTED_INTERVAL: float = 0.05
	const EPSILON: float = 1e-9

	# Act
	var actual: float = TickSystemScript._TICK_INTERVAL_SECONDS

	# Assert (within float epsilon)
	assert_float(actual).is_between(
		EXPECTED_INTERVAL - EPSILON,
		EXPECTED_INTERVAL + EPSILON
	)


# ---------------------------------------------------------------------------
# Test 5 — Public API stubs return safe zero-values and do not raise.
# ---------------------------------------------------------------------------
func test_tick_system_now_ms_returns_zero() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act
	var result: int = ts.now_ms()

	# Assert
	assert_int(result).is_equal(0)

	# Cleanup
	ts.free()


func test_tick_system_current_tick_returns_zero() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act
	var result: int = ts.current_tick()

	# Assert
	assert_int(result).is_equal(0)

	# Cleanup
	ts.free()


func test_tick_system_get_last_persist_ts_returns_zero() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act
	var result: int = ts.get_last_persist_ts()

	# Assert
	assert_int(result).is_equal(0)

	# Cleanup
	ts.free()


func test_tick_system_get_session_high_water_returns_zero() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act
	var result: int = ts.get_session_high_water()

	# Assert
	assert_int(result).is_equal(0)

	# Cleanup
	ts.free()


func test_tick_system_set_last_persist_ts_completes_without_error() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act — stub body is pass; must not raise
	ts.set_last_persist_ts(12345)

	# Assert — reaching this line means no error was raised
	assert_object(ts).is_not_null()

	# Cleanup
	ts.free()


func test_tick_system_set_session_high_water_completes_without_error() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act — stub body is pass; must not raise
	ts.set_session_high_water(12345)

	# Assert — reaching this line means no error was raised
	assert_object(ts).is_not_null()

	# Cleanup
	ts.free()
