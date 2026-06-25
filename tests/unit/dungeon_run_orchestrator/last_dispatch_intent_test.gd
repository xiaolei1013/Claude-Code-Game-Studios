# Sprint 14 S14-N2 — tests for DungeonRunOrchestrator.last_dispatch_intent
# capture + get_last_dispatch_intent accessor.
#
# Re-dispatch shortcut on main_menu (5-sprint carry-forward from S10-N2)
# requires a session-only intent record so a Button can show/hide based on
# whether the player has dispatched yet this session and clicking re-fires
# DungeonRunOrchestrator.dispatch with the same arguments.
#
# Coverage:
#   - Initial state: empty Dictionary
#   - Successful dispatch: intent captured with formation + floor + biome
#   - Validation failure (empty formation): intent NOT updated
#   - Validation failure (floor locked): intent NOT updated
#   - Debounced dispatch: intent NOT updated
#   - get_last_dispatch_intent returns a deep copy (caller mutation does
#     not leak back into the cached intent)
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")

# Snapshot of the live /root/HeroRoster, captured before each test and restored
# after, so this suite neither suffers nor causes a cross-test roster leak.
var _roster_snapshot: Dictionary = {}


# These tests dispatch raw formation dicts whose instance_ids collide with the
# live /root/HeroRoster's starter heroes. A successful dispatch on an unlocked
# floor drives REAL combat; a defeat injures those shared heroes (GDD #34 /
# ADR-0021 — correct production behavior), which then trips the dispatch-time
# injured-hero gate on the next same-id dispatch, leaving last_dispatch_intent
# empty — so this suite can poison itself or other suites. Reset the live roster
# to empty per test (every dispatched id reads as a healthy unknown) and restore
# afterward so we leak nothing (memory: feedback_test_isolation_live_autoload).
func before_test() -> void:
	_roster_snapshot = HeroRosterFixture.snapshot_via_save_data()
	HeroRosterFixture.reset_hero_roster()


func after_test() -> void:
	HeroRosterFixture.restore_via_load_save_data(_roster_snapshot)


func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


# Mock FloorUnlock that lets every floor pass.
class PermissiveFloorUnlock extends RefCounted:
	func is_unlocked(_floor_index: int) -> bool:
		return true


# Mock FloorUnlock that locks specified floors.
class RestrictiveFloorUnlock extends RefCounted:
	var _locked_floors: Array[int] = []

	func is_unlocked(floor_index: int) -> bool:
		return not _locked_floors.has(floor_index)


# ===========================================================================
# Group A — initial state
# ===========================================================================

func test_orchestrator_last_dispatch_intent_initial_state_is_empty() -> void:
	var orch: Node = _make_orch()
	assert_dict(orch.last_dispatch_intent).is_empty()


func test_orchestrator_get_last_dispatch_intent_initial_returns_empty_dict() -> void:
	var orch: Node = _make_orch()
	var intent: Dictionary = orch.get_last_dispatch_intent()
	assert_dict(intent).is_empty()


# ===========================================================================
# Group B — successful dispatch captures intent
# ===========================================================================

func test_orchestrator_successful_dispatch_captures_intent() -> void:
	var orch: Node = _make_orch()
	orch._floor_unlock = PermissiveFloorUnlock.new()
	# A non-empty formation; the orchestrator does not validate hero ids
	# at dispatch time (only that formation is non-empty per TR-026).
	var formation: Array = [{"instance_id": 1, "class_id": "warrior"}]
	orch.dispatch(formation, 3, "ashen_glade")

	assert_dict(orch.last_dispatch_intent).is_not_empty()
	assert_int(int(orch.last_dispatch_intent.floor_index)).is_equal(3)
	assert_str(String(orch.last_dispatch_intent.biome_id)).is_equal("ashen_glade")
	# Formation deep-copied; size matches.
	assert_int((orch.last_dispatch_intent.formation as Array).size()).is_equal(1)


func test_orchestrator_get_last_dispatch_intent_after_success_returns_populated_dict() -> void:
	var orch: Node = _make_orch()
	orch._floor_unlock = PermissiveFloorUnlock.new()
	orch.dispatch([{"instance_id": 11, "class_id": "mage"}], 1, "cinder_keep")

	var intent: Dictionary = orch.get_last_dispatch_intent()
	assert_dict(intent).is_not_empty()
	assert_int(int(intent.floor_index)).is_equal(1)
	assert_str(String(intent.biome_id)).is_equal("cinder_keep")


# ===========================================================================
# Group C — validation failures do NOT update intent
# ===========================================================================

func test_orchestrator_empty_formation_dispatch_leaves_intent_empty() -> void:
	var orch: Node = _make_orch()
	orch._floor_unlock = PermissiveFloorUnlock.new()
	orch.dispatch([], 1, "ashen_glade")
	# Empty formation → validation_failed; intent NOT captured.
	assert_dict(orch.last_dispatch_intent).is_empty()


func test_orchestrator_floor_locked_dispatch_leaves_intent_empty() -> void:
	var orch: Node = _make_orch()
	var floor_unlock: RestrictiveFloorUnlock = RestrictiveFloorUnlock.new()
	floor_unlock._locked_floors = [3]
	orch._floor_unlock = floor_unlock
	orch.dispatch([{"instance_id": 1, "class_id": "warrior"}], 3, "ashen_glade")
	# Floor locked → validation_failed; intent NOT captured.
	assert_dict(orch.last_dispatch_intent).is_empty()


# A failed dispatch after a previous success leaves the SUCCESS intent
# in place — the cache is "last SUCCESSFUL", not "last attempt".
func test_orchestrator_failed_dispatch_after_success_preserves_prior_intent() -> void:
	var orch: Node = _make_orch()
	orch._floor_unlock = PermissiveFloorUnlock.new()
	# Successful dispatch captures intent.
	orch.dispatch([{"instance_id": 1, "class_id": "warrior"}], 2, "ashen_glade")
	assert_dict(orch.last_dispatch_intent).is_not_empty()
	# Force the orchestrator back to NO_RUN so dispatch can be called again.
	orch._set_state(DungeonRunStateScript.validate_transition(
		orch.state, DungeonRunStateScript.TRIGGER_RUN_ENDED
	))
	# Empty formation: validation fails — intent should NOT be overwritten.
	orch.dispatch([], 5, "cinder_keep")
	# Original intent (floor 2, ashen_glade) is preserved.
	assert_int(int(orch.last_dispatch_intent.floor_index)).is_equal(2)
	assert_str(String(orch.last_dispatch_intent.biome_id)).is_equal("ashen_glade")


# ===========================================================================
# Group D — debounce does NOT update intent
# ===========================================================================

# A debounced dispatch (within DISPATCH_DEBOUNCE_MS of the prior) is silently
# dropped at the orchestrator's debounce gate — intent should NOT update.
func test_orchestrator_debounced_dispatch_does_not_overwrite_intent() -> void:
	var orch: Node = _make_orch()
	orch._floor_unlock = PermissiveFloorUnlock.new()
	# First dispatch succeeds.
	orch.dispatch([{"instance_id": 1, "class_id": "warrior"}], 1, "ashen_glade")
	assert_int(int(orch.last_dispatch_intent.floor_index)).is_equal(1)
	# Immediate second dispatch (within debounce window) is dropped.
	orch.dispatch([{"instance_id": 2, "class_id": "mage"}], 5, "cinder_keep")
	# Intent still reflects the FIRST dispatch (debounce dropped the second).
	assert_int(int(orch.last_dispatch_intent.floor_index)).is_equal(1)
	assert_str(String(orch.last_dispatch_intent.biome_id)).is_equal("ashen_glade")


# ===========================================================================
# Group E — get_last_dispatch_intent returns a deep copy
# ===========================================================================

# Caller mutation of the returned Dictionary must NOT leak back into the
# orchestrator's cached intent. This guards against a subtle aliasing bug
# where main_menu (or any other caller) could accidentally mutate the
# session-state by writing into the returned reference.
func test_orchestrator_get_last_dispatch_intent_returns_deep_copy() -> void:
	var orch: Node = _make_orch()
	orch._floor_unlock = PermissiveFloorUnlock.new()
	orch.dispatch([{"instance_id": 1, "class_id": "warrior"}], 2, "ashen_glade")

	var intent: Dictionary = orch.get_last_dispatch_intent()
	# Mutate the returned copy's top-level keys.
	intent.floor_index = 999
	intent.biome_id = "MUTATED"
	# Mutate the nested formation array.
	(intent.formation as Array).append({"instance_id": 99, "class_id": "rogue"})

	# The orchestrator's cached intent is unchanged.
	assert_int(int(orch.last_dispatch_intent.floor_index)).is_equal(2)
	assert_str(String(orch.last_dispatch_intent.biome_id)).is_equal("ashen_glade")
	assert_int((orch.last_dispatch_intent.formation as Array).size()).is_equal(1)


# ===========================================================================
# Group F — multiple successful dispatches update intent each time
# ===========================================================================

func test_orchestrator_second_successful_dispatch_overwrites_intent() -> void:
	var orch: Node = _make_orch()
	orch._floor_unlock = PermissiveFloorUnlock.new()
	# First dispatch.
	orch.dispatch([{"instance_id": 1, "class_id": "warrior"}], 1, "ashen_glade")
	assert_int(int(orch.last_dispatch_intent.floor_index)).is_equal(1)
	# Force back to NO_RUN.
	orch._set_state(DungeonRunStateScript.validate_transition(
		orch.state, DungeonRunStateScript.TRIGGER_RUN_ENDED
	))
	# Wait past debounce.
	OS.delay_msec(OrchestratorScript.DISPATCH_DEBOUNCE_MS + 10)
	# Second dispatch.
	orch.dispatch([{"instance_id": 2, "class_id": "mage"}], 4, "cinder_keep")
	# Intent now reflects the SECOND dispatch.
	assert_int(int(orch.last_dispatch_intent.floor_index)).is_equal(4)
	assert_str(String(orch.last_dispatch_intent.biome_id)).is_equal("cinder_keep")
