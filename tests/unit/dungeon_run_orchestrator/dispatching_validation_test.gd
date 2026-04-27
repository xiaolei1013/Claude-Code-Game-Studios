# Tests for Sprint 6 dungeon-run-orchestrator Story 003: DISPATCHING validation.
# Covers: TR-orchestrator-026 (empty formation rejected with named reason),
#         TR-orchestrator-027 (floor lock via injected FloorUnlock spy),
#         TR-orchestrator-032 (250ms debounce on dispatch).
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")


# Build a fresh orchestrator and add to scene tree so _ready runs.
func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


# Mock FloorUnlock — a RefCounted with an `is_unlocked(floor_index)` method
# whose return value is parameterised per-test via `_unlocked_set`.
class MockFloorUnlock extends RefCounted:
	var _unlocked_set: Dictionary = {}  # floor_index → bool

	func is_unlocked(floor_index: int) -> bool:
		return bool(_unlocked_set.get(floor_index, true))


# Signal spy state.
var _spy_validation_count: int = 0
var _spy_validation_reason: String = ""
var _spy_validation_payload: Dictionary = {}


func _on_validation_failed(reason: String, payload: Dictionary) -> void:
	_spy_validation_count += 1
	_spy_validation_reason = reason
	_spy_validation_payload = payload


# ===========================================================================
# Group A: TR-032 — DISPATCH_DEBOUNCE_MS constant exists at expected value
# ===========================================================================

func test_dispatch_debounce_constant_is_250_ms() -> void:
	assert_int(OrchestratorScript.DISPATCH_DEBOUNCE_MS).is_equal(250)


# ===========================================================================
# Group B: TR-026 — empty formation → RUN_ENDED + validation_failed
# ===========================================================================

func test_empty_formation_emits_validation_failed_with_empty_formation_reason() -> void:
	_spy_validation_count = 0
	var orch: Node = _make_orch()
	orch.validation_failed.connect(_on_validation_failed)
	orch.dispatch([], 1, "forest_reach")
	assert_int(_spy_validation_count).is_equal(1)
	assert_str(_spy_validation_reason).is_equal("empty_formation")


func test_empty_formation_transitions_state_to_run_ended() -> void:
	var orch: Node = _make_orch()
	orch.dispatch([], 1, "forest_reach")
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)


func test_empty_formation_payload_is_empty_dict() -> void:
	_spy_validation_count = 0
	_spy_validation_payload = {"sentinel": true}  # pre-load to detect overwrite
	var orch: Node = _make_orch()
	orch.validation_failed.connect(_on_validation_failed)
	orch.dispatch([], 1, "forest_reach")
	assert_int(_spy_validation_payload.size()).is_equal(0)


# ===========================================================================
# Group C: TR-027 — floor locked → RUN_ENDED + validation_failed("floor_locked")
# ===========================================================================

func test_locked_floor_emits_validation_failed_with_floor_locked_reason() -> void:
	_spy_validation_count = 0
	var orch: Node = _make_orch()
	var fu: MockFloorUnlock = MockFloorUnlock.new()
	fu._unlocked_set[99] = false
	orch.set_floor_unlock(fu)
	orch.validation_failed.connect(_on_validation_failed)
	orch.dispatch([{"id": 1}], 99, "forest_reach")
	assert_int(_spy_validation_count).is_equal(1)
	assert_str(_spy_validation_reason).is_equal("floor_locked")


func test_locked_floor_payload_includes_floor_index() -> void:
	_spy_validation_count = 0
	var orch: Node = _make_orch()
	var fu: MockFloorUnlock = MockFloorUnlock.new()
	fu._unlocked_set[42] = false
	orch.set_floor_unlock(fu)
	orch.validation_failed.connect(_on_validation_failed)
	orch.dispatch([{"id": 1}], 42, "forest_reach")
	assert_bool(_spy_validation_payload.has("floor_index")).is_true()
	assert_int(_spy_validation_payload["floor_index"]).is_equal(42)


func test_locked_floor_transitions_state_to_run_ended() -> void:
	var orch: Node = _make_orch()
	var fu: MockFloorUnlock = MockFloorUnlock.new()
	fu._unlocked_set[5] = false
	orch.set_floor_unlock(fu)
	orch.dispatch([{"id": 1}], 5, "forest_reach")
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)


# ===========================================================================
# Group D: TR-027 — unlocked floor passes validation; state stays at DISPATCHING
# ===========================================================================

func test_unlocked_floor_with_non_empty_formation_advances_to_active_foreground() -> void:
	# Sprint 7 S7-M13: dispatch now wires straight through to ACTIVE_FOREGROUND
	# (snapshot built + tick subscription connected) on successful validation.
	# Story 003's earlier "stops at DISPATCHING" comment is superseded.
	_spy_validation_count = 0
	var orch: Node = _make_orch()
	var fu: MockFloorUnlock = MockFloorUnlock.new()
	fu._unlocked_set[1] = true
	orch.set_floor_unlock(fu)
	orch.validation_failed.connect(_on_validation_failed)
	orch.dispatch([{"id": 1}], 1, "forest_reach")
	# No validation_failed emission.
	assert_int(_spy_validation_count).is_equal(0)
	# State advanced through DISPATCHING to ACTIVE_FOREGROUND.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


func test_null_floor_unlock_skips_lock_check_and_advances_to_active_foreground() -> void:
	# Pre-production fail-open: when _floor_unlock is null, the lock check
	# is SKIPPED — dispatch with a non-empty formation now reaches
	# ACTIVE_FOREGROUND (Sprint 7 S7-M13 wires DISPATCHING → ACTIVE_FOREGROUND
	# automatically via snapshot construction).
	var orch: Node = _make_orch()
	# Deliberately do not call set_floor_unlock — _floor_unlock stays null.
	orch.dispatch([{"id": 1}], 99, "forest_reach")
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


# ===========================================================================
# Group E: TR-032 — debounce within 250ms is silent no-op
# ===========================================================================

func test_second_dispatch_within_250ms_is_silent_no_op() -> void:
	_spy_validation_count = 0
	var orch: Node = _make_orch()
	var fu: MockFloorUnlock = MockFloorUnlock.new()
	fu._unlocked_set[1] = true
	orch.set_floor_unlock(fu)
	orch.validation_failed.connect(_on_validation_failed)
	# First dispatch — empty formation triggers validation_failed AND consumes
	# the debounce window. State: RUN_ENDED.
	orch.dispatch([], 1, "forest_reach")
	assert_int(_spy_validation_count).is_equal(1)
	# Second dispatch IMMEDIATELY (same frame) — within 250ms — is debounced.
	# No new validation_failed; state unchanged.
	orch.dispatch([], 1, "forest_reach")
	assert_int(_spy_validation_count).is_equal(1)


func test_second_dispatch_within_debounce_does_not_change_state() -> void:
	var orch: Node = _make_orch()
	# First dispatch — successful entry into ACTIVE_FOREGROUND (Sprint 7
	# S7-M13 wires snapshot build + state advance automatically).
	orch.dispatch([{"id": 1}], 1, "forest_reach")
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	var pre_state: int = orch.state
	# Second dispatch immediately — debounce fires; state unchanged.
	# (Note: the matrix would also reject dispatch_pressed from
	# ACTIVE_FOREGROUND — debounce kicks in first; either way state stays.)
	orch.dispatch([{"id": 2}], 2, "forest_reach")
	assert_int(orch.state).is_equal(pre_state)


# ===========================================================================
# Group F: state-transition guard — dispatch from invalid from-state is rejected
# ===========================================================================

func test_dispatch_from_dispatching_state_is_rejected_by_matrix() -> void:
	# Manually force state to DISPATCHING (bypass the public API for test setup).
	# DungeonRunState matrix rejects dispatch_pressed from DISPATCHING.
	var orch: Node = _make_orch()
	orch.state = DungeonRunStateScript.State.DISPATCHING
	# The dispatch call should push_error inside validate_transition and exit.
	orch.dispatch([{"id": 1}], 1, "forest_reach")
	# State stays at DISPATCHING — matrix rejected the trigger.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.DISPATCHING)


func test_dispatch_from_active_foreground_is_rejected_by_matrix() -> void:
	var orch: Node = _make_orch()
	orch.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	orch.dispatch([{"id": 1}], 1, "forest_reach")
	# Per matrix row 3: dispatch_pressed in ACTIVE_FOREGROUND is invalid → stay.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


# ===========================================================================
# Group G: validation_failed signal arity + types
# ===========================================================================

func test_validation_failed_signal_exists_with_two_args() -> void:
	var orch: Node = _make_orch()
	var sigs: Array = orch.get_signal_list()
	var found: bool = false
	for sig: Dictionary in sigs:
		if sig.get("name", "") == "validation_failed":
			found = true
			var args: Array = sig.get("args", [])
			assert_int(args.size()).is_equal(2)
	assert_bool(found).is_true()


# ===========================================================================
# Group H: re-dispatch from RUN_ENDED is allowed (matrix row 5)
# ===========================================================================

func test_dispatch_from_run_ended_after_debounce_window_passes_advances_to_active_foreground() -> void:
	# Setup: first dispatch lands in RUN_ENDED (empty formation).
	var orch: Node = _make_orch()
	orch.dispatch([], 1, "forest_reach")
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	# Bypass debounce by resetting the stamp manually (simulates >250ms wait).
	orch._last_dispatch_ms = 0
	# Second dispatch with valid inputs — matrix row 5 allows dispatch_pressed.
	# Sprint 7 S7-M13 wires DISPATCHING → ACTIVE_FOREGROUND automatically on
	# successful validation (no longer stops at DISPATCHING).
	var fu: MockFloorUnlock = MockFloorUnlock.new()
	fu._unlocked_set[1] = true
	orch.set_floor_unlock(fu)
	orch.dispatch([{"id": 1}], 1, "forest_reach")
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
