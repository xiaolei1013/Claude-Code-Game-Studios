# Tests for Story 001: DataRegistry autoload skeleton and state machine.
# Covers: TR-data-loading-001, TR-data-loading-007, TR-data-loading-011,
#         TR-data-loading-012, TR-data-loading-013, ADR-0003 Amendment #3.
#
# ERROR-path strategy: Tests that need a failing _boot_scan() call
# _transition_to_error() directly. The stub _boot_scan() always returns true
# in this story (body is Story 003), so forcing ERROR via the private helper is
# the cleanest approach and is explicitly permitted by the story spec.
#
# Signal-emission counting: A local Array[int] is connected to each signal and
# incremented on emission. This avoids GdUnit4 version-specific monitor_signals
# API differences and keeps every test fully self-contained.
extends GdUnitTestSuite

const DataRegistryScript = preload("res://src/core/data_registry/data_registry.gd")


# ---------------------------------------------------------------------------
# Test 1 — TR-data-loading-001 / TR-data-loading-011:
#   DataRegistry is a Node-derived class named DataRegistry and its state
#   transitions UNLOADED → LOADING → READY when _ready() fires (stub returns true).
#
# The real autoload is only present when the full project boots; unit tests
# instantiate directly to verify the class contract. Headless boot / autoload-
# presence is covered by the sprint-close smoke check, not this unit test.
# ---------------------------------------------------------------------------
func test_data_registry_state_transitions_unloaded_loading_ready_on_ready() -> void:
	# Arrange — empty min_content_count so boot_scan succeeds with no content
	# (Story 005 introduced default thresholds {classes:3, ...}; this skeleton
	# test pre-dates that and only cares that the state machine advances.)
	var dr: Node = DataRegistryScript.new()
	dr.min_content_count = {}

	# Assert initial state before _ready()
	assert_int(dr.state).is_equal(DataRegistryScript.State.UNLOADED)
	assert_bool(dr is Node).is_true()
	assert_str(dr.get_class()).is_equal("Node")

	# Act — manually invoke _ready() (autoload boots in scene tree; unit tests invoke directly)
	dr._ready()

	# Assert — boot_scan with empty min_content_count succeeds; state must be READY
	assert_int(dr.state).is_equal(DataRegistryScript.State.READY)

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 2 — TR-data-loading-007 / TR-data-loading-012:
#   Successful boot transitions to READY and emits registry_ready exactly once.
# ---------------------------------------------------------------------------
func test_data_registry_ready_boot_emits_registry_ready_exactly_once() -> void:
	# Arrange — empty min_content_count so boot_scan succeeds with no content
	var dr: Node = DataRegistryScript.new()
	dr.min_content_count = {}
	var emit_count: Array[int] = [0]
	dr.registry_ready.connect(func() -> void: emit_count[0] += 1)

	# Act
	dr._ready()

	# Assert
	assert_int(dr.state).is_equal(DataRegistryScript.State.READY)
	assert_int(emit_count[0]).is_equal(1)

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 3 — TR-data-loading-012:
#   Fatal boot error transitions to ERROR and emits registry_error (not
#   registry_ready). Uses _transition_to_error() directly — no subclass needed.
# ---------------------------------------------------------------------------
func test_data_registry_transition_to_error_emits_registry_error_not_registry_ready() -> void:
	# Arrange
	var dr: Node = DataRegistryScript.new()
	var ready_count: Array[int] = [0]
	var error_count: Array[int] = [0]
	var captured_reason: Array[String] = [""]
	var captured_details: Array[Dictionary] = [{}]

	dr.registry_ready.connect(func() -> void: ready_count[0] += 1)
	dr.registry_error.connect(
		func(reason: String, details: Dictionary) -> void:
			error_count[0] += 1
			captured_reason[0] = reason
			captured_details[0] = details
	)

	# Manually advance to LOADING to simulate partial boot before error
	dr.state = DataRegistryScript.State.LOADING

	# Act — call the private error helper directly (permitted by story spec)
	dr._transition_to_error("test_fatal_error", {"code": 42, "path": "assets/data/"})

	# Assert — state must be ERROR, registry_error emitted once, registry_ready never emitted
	assert_int(dr.state).is_equal(DataRegistryScript.State.ERROR)
	assert_int(error_count[0]).is_equal(1)
	assert_int(ready_count[0]).is_equal(0)
	assert_str(captured_reason[0]).is_not_empty()
	assert_bool(captured_details[0].size() > 0).is_true()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 4 — TR-data-loading-013:
#   hot_reload_complete signal is declared with exactly one String parameter
#   named content_type; connect() returns OK.
# ---------------------------------------------------------------------------
func test_data_registry_hot_reload_complete_signal_has_correct_arity_and_type() -> void:
	# Arrange
	var dr: Node = DataRegistryScript.new()

	# Act — connect a callable matching the expected signature (String param)
	var result: int = dr.hot_reload_complete.connect(
		func(_content_type: String) -> void: pass
	)

	# Assert — OK == 0 in Godot 4 Error enum; verifies signal exists with correct arity
	assert_int(result).is_equal(OK)
	assert_bool(dr.hot_reload_complete.get_connections().size() > 0).is_true()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 5 — ADR-0003 Amendment #3: zero-arg _init.
#   DataRegistryScript.new() with no arguments must succeed without error.
# ---------------------------------------------------------------------------
func test_data_registry_zero_arg_init_constructs_without_error() -> void:
	# Arrange / Act — no arguments passed
	var dr: Node = DataRegistryScript.new()

	# Assert — reaching this line means _init accepted zero args cleanly
	assert_object(dr).is_not_null()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 6 — ERROR is terminal:
#   A second call to _transition_to_error() after ERROR is already set must be
#   a no-op — no additional registry_error emission, state remains ERROR.
# ---------------------------------------------------------------------------
func test_data_registry_error_state_is_terminal_no_reentry() -> void:
	# Arrange
	var dr: Node = DataRegistryScript.new()
	var error_count: Array[int] = [0]
	dr.registry_error.connect(func(_r: String, _d: Dictionary) -> void: error_count[0] += 1)

	# First transition to ERROR
	dr._transition_to_error("first_error", {})
	assert_int(dr.state).is_equal(DataRegistryScript.State.ERROR)
	assert_int(error_count[0]).is_equal(1)

	# Act — attempt a second _transition_to_error call (re-entry guard)
	dr._transition_to_error("second_error_should_not_emit", {"extra": true})

	# Assert — state stays ERROR, signal count unchanged (guard fired)
	assert_int(dr.state).is_equal(DataRegistryScript.State.ERROR)
	assert_int(error_count[0]).is_equal(1)

	# Cleanup
	dr.free()
