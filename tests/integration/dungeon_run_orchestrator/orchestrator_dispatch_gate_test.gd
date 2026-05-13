# Tests for floor-unlock-system/story-007 — orchestrator dispatch gate wiring.
#
# Covers:
#   - TR-026 lazy-bind: orchestrator `_ready()` auto-binds `_floor_unlock` to
#     /root/FloorUnlock when no fu_spy was pre-injected; pre-injected fu_spy survives.
#   - TR-026 locked rejection: dispatch with floor where `is_unlocked` returns
#     false triggers `validation_failed("floor_locked", {...})` and state →
#     RUN_ENDED.
#   - TR-026 unlocked passes: dispatch with valid floor proceeds normally
#     (snapshot built, ACTIVE_FOREGROUND entered).
#   - TR-026 fail-open removed: with production FloorUnlock bound,
#     `is_unlocked(0)` returns false (sentinel); previous test-env null-fail-open
#     path no longer reached in production.
#
# This story is cross-system: source-side wiring lives in `dungeon_run_orchestrator.gd`
# (the dispatch gate validation 2 + lazy-bind in _ready), but the AC scope is
# floor-unlock's contract. Tests live in integration/dungeon_run_orchestrator/.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const FloorUnlockScript = preload("res://src/core/floor_unlock_system/floor_unlock_system.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")


# ---------------------------------------------------------------------------
# Spy FloorUnlock — controllable is_unlocked return value
# ---------------------------------------------------------------------------

class _SpyFloorUnlock extends RefCounted:
	var unlocked_value: bool = true
	var call_count: int = 0
	var last_floor_index: int = -1

	func is_unlocked(floor_index: int) -> bool:
		call_count += 1
		last_floor_index = floor_index
		return unlocked_value


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


func _make_orch_with_spy(fu_spy: _SpyFloorUnlock) -> Node:
	var orch: Node = OrchestratorScript.new()
	# DI must happen BEFORE add_child so the lazy-bind in _ready sees the
	# pre-injected fu_spy and skips auto-binding.
	orch.set_floor_unlock(fu_spy)
	add_child(orch)
	auto_free(orch)
	return orch


# ---------------------------------------------------------------------------
# TR-026 lazy-bind: _ready auto-binds /root/FloorUnlock when no fu_spy injected
# ---------------------------------------------------------------------------

func test_tr026_ready_auto_binds_floor_unlock_when_no_spy_injected() -> void:
	# Arrange + Act — fresh orchestrator with no DI; _ready fires on add_child
	var orch: Node = _make_orch()

	# Assert — _floor_unlock now points at /root/FloorUnlock (or null in
	# test envs without the autoload, in which case the test-env path is
	# the documented fallback).
	var fu_autoload: Node = get_tree().root.get_node_or_null("FloorUnlock")
	if fu_autoload == null:
		push_warning("Skipped: /root/FloorUnlock autoload not registered in test env")
		return
	assert_object(orch._floor_unlock).is_equal(fu_autoload)


func test_tr026_pre_injected_spy_survives_ready_lazy_bind() -> void:
	# Arrange — inject a fu_spy via set_floor_unlock BEFORE add_child
	var fu_spy: _SpyFloorUnlock = _SpyFloorUnlock.new()

	# Act
	var orch: Node = _make_orch_with_spy(fu_spy)

	# Assert — orchestrator's _floor_unlock is the fu_spy, NOT the autoload
	assert_object(orch._floor_unlock).is_equal(fu_spy)
	# Confirm not the autoload
	var fu_autoload: Node = get_tree().root.get_node_or_null("FloorUnlock")
	if fu_autoload != null:
		assert_bool(orch._floor_unlock == fu_autoload).is_false()


# ---------------------------------------------------------------------------
# TR-026 locked rejection: dispatch with locked floor → validation_failed
# ---------------------------------------------------------------------------

func test_tr026_dispatch_with_locked_floor_emits_floor_locked_validation_failed() -> void:
	# Arrange — fu_spy returns false for is_unlocked
	var fu_spy: _SpyFloorUnlock = _SpyFloorUnlock.new()
	fu_spy.unlocked_value = false
	var orch: Node = _make_orch_with_spy(fu_spy)
	var emissions: Array[Array] = []
	orch.validation_failed.connect(
		func(reason: String, payload: Dictionary) -> void:
			emissions.append([reason, payload])
	)
	# Build a non-empty formation for the dispatch to pass empty-formation guard
	var formation: Array = ["dummy_hero_a"]

	# Act
	orch.dispatch(formation, 3, "forest_reach")

	# Assert — validation_failed("floor_locked", {floor_index: 3})
	# (filter to only floor_locked emissions — empty_formation could also
	# fire if the dispatch state machine hits multiple guards)
	var floor_locked_emissions: Array = []
	for e: Array in emissions:
		if e[0] == "floor_locked":
			floor_locked_emissions.append(e)
	assert_int(floor_locked_emissions.size()).is_equal(1)
	assert_int(int(floor_locked_emissions[0][1].get("floor_index", -1))).is_equal(3)
	# State settled at RUN_ENDED (locked dispatch terminates the would-be run)
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	# Spy was actually called with the right floor
	assert_int(fu_spy.call_count).is_greater(0)
	assert_int(fu_spy.last_floor_index).is_equal(3)


# ---------------------------------------------------------------------------
# TR-026 unlocked passes: dispatch with unlocked floor advances normally
# ---------------------------------------------------------------------------

func test_tr026_dispatch_with_unlocked_floor_advances_to_active_foreground() -> void:
	# Arrange — fu_spy returns true
	var fu_spy: _SpyFloorUnlock = _SpyFloorUnlock.new()
	fu_spy.unlocked_value = true
	var orch: Node = _make_orch_with_spy(fu_spy)
	var formation: Array = ["dummy_hero_a"]

	# Act
	orch.dispatch(formation, 1, "forest_reach")

	# Assert — state is ACTIVE_FOREGROUND (dispatch validation passed; live run)
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	# Spy was called
	assert_int(fu_spy.call_count).is_greater(0)


# ---------------------------------------------------------------------------
# TR-026 fail-open removed: production FloorUnlock rejects floor_index 0
#
# The previous test-env null-fail-open path is gone now that _ready
# auto-binds. With the production autoload (or any FloorUnlock), is_unlocked(0)
# returns false (sentinel), so dispatch with floor 0 is rejected.
# ---------------------------------------------------------------------------

func test_tr026_dispatch_with_floor_zero_sentinel_rejected_by_floor_unlock() -> void:
	# Arrange — production autoload binding
	var orch: Node = _make_orch()
	var fu_autoload: Node = get_tree().root.get_node_or_null("FloorUnlock")
	if fu_autoload == null:
		push_warning("Skipped: /root/FloorUnlock autoload not registered")
		return
	# Sanity: orchestrator bound the autoload
	assert_object(orch._floor_unlock).is_equal(fu_autoload)

	var emissions: Array[Array] = []
	orch.validation_failed.connect(
		func(reason: String, payload: Dictionary) -> void:
			emissions.append([reason, payload])
	)
	var formation: Array = ["dummy_hero_a"]

	# Act — floor 0 is the sentinel; production FloorUnlock returns false
	orch.dispatch(formation, 0, "forest_reach")

	# Assert — validation_failed fires with floor_locked (the lock-check path)
	var floor_locked_emissions: Array = []
	for e: Array in emissions:
		if e[0] == "floor_locked":
			floor_locked_emissions.append(e)
	assert_int(floor_locked_emissions.size()).is_equal(1)
	assert_int(int(floor_locked_emissions[0][1].get("floor_index", -1))).is_equal(0)
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)
