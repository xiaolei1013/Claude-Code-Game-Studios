# Tests for Sprint 6 dungeon-run-orchestrator Story 001:
#   - RunSnapshot RefCounted + 9-field schema + to_dict/from_dict/equals
#   - 5-state FSM definition + complete 5×6 transition matrix.
#
# Covers: TR-orchestrator-001 (5-state FSM in canonical order),
#         TR-orchestrator-002 (every (state, trigger) cell defined),
#         TR-orchestrator-003 (RunSnapshot RefCounted + round-trip serialization),
#         TR-orchestrator-005 (named fields with correct types).
extends GdUnitTestSuite

const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")


# ===========================================================================
# Group A: TR-orchestrator-001 — 5-state FSM
# ===========================================================================

func test_state_enum_has_exactly_five_values() -> void:
	# DungeonRunState.State.size() returns 5 (one per state).
	assert_int(DungeonRunStateScript.State.size()).is_equal(5)


func test_state_enum_canonical_order_no_run_to_run_ended() -> void:
	# Order is contractual — int values are persisted in save data.
	# NEVER reorder; only append.
	assert_int(DungeonRunStateScript.State.NO_RUN).is_equal(0)
	assert_int(DungeonRunStateScript.State.DISPATCHING).is_equal(1)
	assert_int(DungeonRunStateScript.State.ACTIVE_FOREGROUND).is_equal(2)
	assert_int(DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY).is_equal(3)
	assert_int(DungeonRunStateScript.State.RUN_ENDED).is_equal(4)


# ===========================================================================
# Group B: TR-orchestrator-002 — six trigger constants exist
# ===========================================================================

func test_six_canonical_triggers_defined() -> void:
	assert_int(DungeonRunStateScript.ALL_TRIGGERS.size()).is_equal(6)
	assert_bool(DungeonRunStateScript.ALL_TRIGGERS.has("dispatch_pressed")).is_true()
	assert_bool(DungeonRunStateScript.ALL_TRIGGERS.has("formation_changed")).is_true()
	assert_bool(DungeonRunStateScript.ALL_TRIGGERS.has("app_suspended")).is_true()
	assert_bool(DungeonRunStateScript.ALL_TRIGGERS.has("app_resumed")).is_true()
	assert_bool(DungeonRunStateScript.ALL_TRIGGERS.has("offline_replay_complete")).is_true()
	assert_bool(DungeonRunStateScript.ALL_TRIGGERS.has("run_ended")).is_true()


# ===========================================================================
# Group C: TR-orchestrator-002 — every (state, trigger) cell returns a State
# ===========================================================================

# This test validates the EXHAUSTIVENESS contract — for every of the 30 cells,
# `validate_transition` returns a valid State int (one of the 5 enum values),
# never -1 / null / a sentinel for "undefined".
func test_every_state_trigger_cell_returns_a_valid_state() -> void:
	var states: Array[int] = [
		DungeonRunStateScript.State.NO_RUN,
		DungeonRunStateScript.State.DISPATCHING,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND,
		DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY,
		DungeonRunStateScript.State.RUN_ENDED,
	]
	var valid_states: Array[int] = states  # alias for readability
	for from_state: int in states:
		for trigger: String in DungeonRunStateScript.ALL_TRIGGERS:
			var next: int = DungeonRunStateScript.validate_transition(from_state, trigger)
			assert_bool(valid_states.has(next)).override_failure_message(
				"Cell (%d, '%s') returned %d which is not a valid State"
				% [from_state, trigger, next]
			).is_true()


# Row 1: NO_RUN cells
func test_no_run_dispatch_pressed_transitions_to_dispatching() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.NO_RUN, "dispatch_pressed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.DISPATCHING)


func test_no_run_formation_changed_is_invalid_stays_no_run() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.NO_RUN, "formation_changed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.NO_RUN)


func test_no_run_app_suspended_is_noop() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.NO_RUN, "app_suspended"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.NO_RUN)


func test_no_run_app_resumed_is_noop() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.NO_RUN, "app_resumed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.NO_RUN)


func test_no_run_offline_replay_complete_is_invalid() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.NO_RUN, "offline_replay_complete"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.NO_RUN)


func test_no_run_run_ended_is_invalid() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.NO_RUN, "run_ended"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.NO_RUN)


# Row 2: DISPATCHING — only run_ended exits validly
func test_dispatching_run_ended_transitions_to_run_ended() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.DISPATCHING, "run_ended"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.RUN_ENDED)


func test_dispatching_dispatch_pressed_is_invalid() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.DISPATCHING, "dispatch_pressed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.DISPATCHING)


func test_dispatching_formation_changed_is_invalid() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.DISPATCHING, "formation_changed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.DISPATCHING)


func test_dispatching_app_suspended_is_invalid() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.DISPATCHING, "app_suspended"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.DISPATCHING)


# Row 3: ACTIVE_FOREGROUND — the steady state
func test_active_foreground_app_suspended_to_offline_replay() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_FOREGROUND, "app_suspended"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY)


func test_active_foreground_formation_changed_to_dispatching() -> void:
	# Mid-run reassignment ends current run AND begins new dispatch in one step.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_FOREGROUND, "formation_changed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.DISPATCHING)


func test_active_foreground_run_ended_to_run_ended() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_FOREGROUND, "run_ended"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.RUN_ENDED)


func test_active_foreground_app_resumed_is_noop() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_FOREGROUND, "app_resumed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


func test_active_foreground_dispatch_pressed_is_invalid() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_FOREGROUND, "dispatch_pressed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


# Row 4: ACTIVE_OFFLINE_REPLAY
func test_active_offline_replay_complete_to_active_foreground() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY, "offline_replay_complete"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


func test_active_offline_replay_formation_changed_to_run_ended() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY, "formation_changed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.RUN_ENDED)


func test_active_offline_replay_run_ended_to_run_ended() -> void:
	# `replay_failed` error path.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY, "run_ended"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.RUN_ENDED)


func test_active_offline_replay_dispatch_pressed_is_invalid() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY, "dispatch_pressed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY)


# Row 5: RUN_ENDED
func test_run_ended_dispatch_pressed_to_dispatching() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.RUN_ENDED, "dispatch_pressed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.DISPATCHING)


func test_run_ended_run_ended_to_no_run() -> void:
	# Player explicitly clears the run.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.RUN_ENDED, "run_ended"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.NO_RUN)


func test_run_ended_formation_changed_is_invalid() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.RUN_ENDED, "formation_changed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.RUN_ENDED)


func test_run_ended_app_suspended_is_noop() -> void:
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.RUN_ENDED, "app_suspended"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.RUN_ENDED)


# Unknown trigger defensive guard
func test_validate_transition_rejects_unknown_trigger() -> void:
	# Unknown trigger: push_error logged; from-state returned unchanged.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.NO_RUN, "garbage_trigger_typo"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.NO_RUN)


# ===========================================================================
# Group D: TR-orchestrator-003 — RunSnapshot RefCounted + identity
# ===========================================================================

func test_run_snapshot_extends_refcounted_not_resource() -> void:
	# RefCounted lifecycle (auto-free) per ADR-0014; NOT a Resource (.tres).
	var snap: RunSnapshot = RunSnapshotScript.new()
	var as_object: Object = snap
	assert_bool(as_object is RefCounted).is_true()
	assert_bool(as_object is Resource).is_false()


# ===========================================================================
# Group E: TR-orchestrator-005 — 9-field schema with correct types + defaults
# ===========================================================================

func test_run_snapshot_default_formation_snapshot_is_empty_dict() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_bool(snap.formation_snapshot is Dictionary).is_true()
	assert_int(snap.formation_snapshot.size()).is_equal(0)


func test_run_snapshot_default_floor_id_is_empty_string() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_str(snap.floor_id).is_equal("")


func test_run_snapshot_default_current_tick_is_zero() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_int(snap.current_tick).is_equal(0)


func test_run_snapshot_default_last_emitted_tick_is_zero() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_int(snap.last_emitted_tick).is_equal(0)


func test_run_snapshot_default_losing_run_is_false() -> void:
	# losing_run is an EXPLICIT bool, NOT re-derived (TR-005 + ADR-0014 §B4).
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_bool(snap.losing_run).is_false()


func test_run_snapshot_default_floor_clear_emitted_is_false() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_bool(snap.floor_clear_emitted).is_false()


func test_run_snapshot_default_matchup_cache_is_empty_dict() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_bool(snap.matchup_cache is Dictionary).is_true()
	assert_int(snap.matchup_cache.size()).is_equal(0)


func test_run_snapshot_default_kill_schedule_is_empty_array() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_bool(snap.kill_schedule is Array).is_true()
	assert_int(snap.kill_schedule.size()).is_equal(0)


func test_run_snapshot_default_loop_counter_is_zero() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_int(snap.loop_counter).is_equal(0)


# ===========================================================================
# Group F: TR-orchestrator-003 — to_dict shape + values
# ===========================================================================

func test_to_dict_returns_ten_key_dict() -> void:
	# Sprint 7 S7-M13 added `kill_count` field as the 10th — tracking running
	# kills since DISPATCHING. Persisted via to_dict for save/load round-trip.
	var snap: RunSnapshot = RunSnapshotScript.new()
	var d: Dictionary = snap.to_dict()
	assert_int(d.size()).is_equal(10)
	for key: String in [
		"formation_snapshot", "floor_id", "current_tick", "last_emitted_tick",
		"losing_run", "floor_clear_emitted", "matchup_cache", "kill_schedule",
		"loop_counter", "kill_count",
	]:
		assert_bool(d.has(key)).override_failure_message(
			"to_dict missing key '%s'" % key
		).is_true()


func test_to_dict_values_match_fields() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.floor_id = "forest_reach_dungeon_01_floor_3"
	snap.current_tick = 42
	snap.last_emitted_tick = 41
	snap.losing_run = true
	snap.floor_clear_emitted = true
	snap.loop_counter = 5
	snap.matchup_cache = {"warrior": true, "mage": false}
	snap.kill_schedule = [{"tick": 10, "kills": 3}]

	var d: Dictionary = snap.to_dict()
	assert_str(d["floor_id"]).is_equal("forest_reach_dungeon_01_floor_3")
	assert_int(d["current_tick"]).is_equal(42)
	assert_int(d["last_emitted_tick"]).is_equal(41)
	assert_bool(d["losing_run"]).is_true()
	assert_bool(d["floor_clear_emitted"]).is_true()
	assert_int(d["loop_counter"]).is_equal(5)
	assert_int((d["matchup_cache"] as Dictionary).size()).is_equal(2)
	assert_int((d["kill_schedule"] as Array).size()).is_equal(1)


func test_to_dict_collections_are_deep_duplicates() -> void:
	# Mutating returned dict's collections must NOT touch live state.
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.matchup_cache = {"warrior": true}
	snap.kill_schedule = [{"tick": 10}]

	var d: Dictionary = snap.to_dict()
	(d["matchup_cache"] as Dictionary)["warrior"] = false
	(d["kill_schedule"] as Array)[0] = {"tick": 999}

	assert_bool(snap.matchup_cache["warrior"]).is_true()
	assert_int((snap.kill_schedule[0] as Dictionary)["tick"]).is_equal(10)


# ===========================================================================
# Group G: TR-orchestrator-003 — from_dict round-trip + defensive defaults
# ===========================================================================

func test_round_trip_to_dict_then_from_dict_preserves_all_fields() -> void:
	var src: RunSnapshot = RunSnapshotScript.new()
	src.formation_snapshot = {"slots": [1, 2, 3]}
	src.floor_id = "forest_reach_dungeon_01_floor_2"
	src.current_tick = 100
	src.last_emitted_tick = 99
	src.losing_run = true
	src.floor_clear_emitted = true
	src.matchup_cache = {"warrior": true, "rogue": false}
	src.kill_schedule = [{"tick": 50, "archetype": "bruiser"}]
	src.loop_counter = 3

	var dst: RunSnapshot = RunSnapshotScript.new()
	dst.from_dict(src.to_dict())

	assert_bool(dst.equals(src)).is_true()


func test_equals_returns_false_for_mismatched_floor_id() -> void:
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.floor_id = "floor_1"
	b.floor_id = "floor_2"
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_against_null() -> void:
	var a: RunSnapshot = RunSnapshotScript.new()
	assert_bool(a.equals(null)).is_false()


func test_from_dict_uses_defaults_on_missing_keys() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.from_dict({})  # totally empty
	assert_int(snap.formation_snapshot.size()).is_equal(0)
	assert_str(snap.floor_id).is_equal("")
	assert_int(snap.current_tick).is_equal(0)
	assert_int(snap.last_emitted_tick).is_equal(0)
	assert_bool(snap.losing_run).is_false()
	assert_bool(snap.floor_clear_emitted).is_false()
	assert_int(snap.matchup_cache.size()).is_equal(0)
	assert_int(snap.kill_schedule.size()).is_equal(0)
	assert_int(snap.loop_counter).is_equal(0)


func test_from_dict_coerces_float_tick_values_to_int() -> void:
	# JSON round-trip turns whole-number ints into floats. Verify int() coercion.
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.from_dict({
		"current_tick": 100.0,
		"last_emitted_tick": 99.0,
		"loop_counter": 3.0,
	})
	assert_int(snap.current_tick).is_equal(100)
	assert_int(snap.last_emitted_tick).is_equal(99)
	assert_int(snap.loop_counter).is_equal(3)


func test_from_dict_does_not_alias_input_collections() -> void:
	# from_dict must duplicate input collections so external mutation of the
	# source dict does not leak into the snapshot's live state.
	var input_dict: Dictionary = {
		"matchup_cache": {"warrior": true},
		"kill_schedule": [{"tick": 10}],
	}
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.from_dict(input_dict)

	# Mutate the input AFTER from_dict — snapshot should not change.
	(input_dict["matchup_cache"] as Dictionary)["warrior"] = false
	(input_dict["kill_schedule"] as Array).append({"tick": 999})

	assert_bool(snap.matchup_cache["warrior"]).is_true()
	assert_int(snap.kill_schedule.size()).is_equal(1)


# ===========================================================================
# Group H: losing_run is explicit, NOT re-derived (TR-005 + ADR-0014 §B4)
# ===========================================================================

func test_losing_run_is_persisted_explicitly_not_derived() -> void:
	# Edge case: losing_run = true even when no other field would suggest it.
	# Verifies the contract that losing_run is its own bit, not a function of
	# kill counts / hp_bonus_factor / etc.
	var src: RunSnapshot = RunSnapshotScript.new()
	src.losing_run = true
	# All other fields default — losing_run should still round-trip.
	var dst: RunSnapshot = RunSnapshotScript.new()
	dst.from_dict(src.to_dict())
	assert_bool(dst.losing_run).is_true()
