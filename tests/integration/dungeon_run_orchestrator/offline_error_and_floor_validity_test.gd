# Tests for dungeon-run-orchestrator/story-011 — offline replay error path +
# `floor_was_valid` distinguisher per ADR-0014.
#
# Covers:
#   - TR-orchestrator-029: offline replay errors transition to RUN_ENDED via
#     `validation_failed("offline_replay_error", {partial_gold: N})`; partial
#     gold retained (no rollback).
#   - TR-orchestrator-031: `floor_was_valid` field on RunSnapshot defaults to
#     `true`; flipped to `false` only via the explicit `mark_floor_invalid_for_offline_replay`
#     hook for the authoring-bug case (distinguishes from the "lost badly"
#     case where kill_schedule is empty but archetypes are valid).
#
# Per ADR-0014 the orchestrator owns the state machine + signal surface; the
# OfflineProgressionEngine (rank 15) is the canonical caller of these hooks
# during offline replay. Tests drive the hooks directly to verify the
# orchestrator-side contract; OfflineProgressionEngine integration is covered
# elsewhere.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


func _make_orch_in_offline_replay(floor_id: String = "forest_reach_floor_1") -> Node:
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch.run_snapshot.floor_id = floor_id
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	# Walk the FSM through DISPATCHING → ACTIVE_FOREGROUND → ACTIVE_OFFLINE_REPLAY
	# the slow way is overkill — test setup uses direct state assignment.
	orch.state = DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY
	return orch


# ---------------------------------------------------------------------------
# TR-orchestrator-029 — offline replay error path
# ---------------------------------------------------------------------------

func test_tr029_report_offline_replay_error_emits_validation_failed_with_partial_gold() -> void:
	# Arrange — orchestrator in ACTIVE_OFFLINE_REPLAY with a captured
	# validation_failed spy.
	var orch: Node = _make_orch_in_offline_replay()
	var emissions: Array[Array] = []
	orch.validation_failed.connect(
		func(reason: String, payload: Dictionary) -> void:
			emissions.append([reason, payload])
	)

	# Act — caller (OfflineProgressionEngine) reports an error mid-replay
	# with 500 gold already credited to Economy before the error.
	orch.report_offline_replay_error(500)

	# Assert — exactly one validation_failed emission with the expected payload
	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0][0]).is_equal("offline_replay_error")
	var payload: Dictionary = emissions[0][1]
	assert_int(int(payload.get("partial_gold", -1))).is_equal(500)


func test_tr029_report_offline_replay_error_transitions_to_run_ended() -> void:
	# Arrange
	var orch: Node = _make_orch_in_offline_replay()
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY)

	# Act
	orch.report_offline_replay_error(0)

	# Assert
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)


func test_tr029_report_offline_replay_error_with_zero_partial_gold_still_reports() -> void:
	# Edge case: error fired before any gold credited (replay aborted in setup).
	# The signal still emits with partial_gold=0 so listeners can distinguish
	# "no gold lost" from "didn't run at all".
	var orch: Node = _make_orch_in_offline_replay()
	var emissions: Array[Array] = []
	orch.validation_failed.connect(
		func(reason: String, payload: Dictionary) -> void:
			emissions.append([reason, payload])
	)

	orch.report_offline_replay_error(0)

	assert_int(emissions.size()).is_equal(1)
	assert_int(int(emissions[0][1].get("partial_gold", -1))).is_equal(0)


func test_tr029_partial_gold_payload_carries_arbitrary_int_no_rollback_logic() -> void:
	# Per ADR-0014 the orchestrator does NOT rollback gold — the caller's
	# partial_gold value is forwarded verbatim into the signal payload. This
	# test confirms there's no defensive clamping / rollback logic on the
	# payload field.
	var orch: Node = _make_orch_in_offline_replay()
	var emissions: Array[Array] = []
	orch.validation_failed.connect(
		func(_reason: String, payload: Dictionary) -> void:
			emissions.append([payload.get("partial_gold", -1)])
	)

	orch.report_offline_replay_error(123_456_789)

	assert_int(emissions.size()).is_equal(1)
	assert_int(int(emissions[0][0])).is_equal(123_456_789)


# ---------------------------------------------------------------------------
# TR-orchestrator-031 — `floor_was_valid` distinguisher
# ---------------------------------------------------------------------------

func test_tr031_run_snapshot_floor_was_valid_defaults_to_true() -> void:
	# Default-constructed RunSnapshot has floor_was_valid == true.
	# This is the "lost badly" default: a fresh run with valid floor archetypes
	# starts as valid; only the explicit invalid-marking path flips it.
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_bool(snap.floor_was_valid).is_true()


func test_tr031_mark_floor_invalid_for_offline_replay_flips_field_to_false() -> void:
	# Arrange — orchestrator with an active snapshot
	var orch: Node = _make_orch_in_offline_replay("authoring_bug_floor_id")
	assert_bool(orch.run_snapshot.floor_was_valid).is_true()

	# Act
	orch.mark_floor_invalid_for_offline_replay()

	# Assert
	assert_bool(orch.run_snapshot.floor_was_valid).is_false()


func test_tr031_mark_floor_invalid_with_null_run_snapshot_is_silent_no_op() -> void:
	# Defensive: if called when run_snapshot is null (NO_RUN, or test setup
	# without a snapshot), the method is a silent no-op rather than crashing.
	var orch: Node = _make_orch()
	orch.run_snapshot = null
	orch.state = DungeonRunStateScript.State.NO_RUN

	# Act — does NOT crash
	orch.mark_floor_invalid_for_offline_replay()

	# Assert — state unchanged, run_snapshot still null
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_object(orch.run_snapshot).is_null()


# ---------------------------------------------------------------------------
# TR-orchestrator-031 round-trip: floor_was_valid persists through to_dict / from_dict
# ---------------------------------------------------------------------------

func test_tr031_floor_was_valid_round_trips_through_to_dict_from_dict() -> void:
	# Arrange — flip floor_was_valid to false, serialize, deserialize, verify.
	var snap_a: RunSnapshot = RunSnapshotScript.new()
	snap_a.floor_was_valid = false
	snap_a.floor_id = "test_floor"

	# Act
	var data: Dictionary = snap_a.to_dict()
	var snap_b: RunSnapshot = RunSnapshotScript.new()
	snap_b.from_dict(data)

	# Assert
	assert_bool(snap_b.floor_was_valid).is_false()
	# And the equals() helper accounts for the field too
	assert_bool(snap_a.equals(snap_b)).is_true()


func test_tr031_floor_was_valid_default_true_when_absent_from_save_data() -> void:
	# Forward-compat: a save authored before the field landed (no
	# floor_was_valid key in the dict) should hydrate as `true` — the safe
	# default that doesn't spuriously claim an authoring bug.
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.from_dict({"floor_id": "legacy_save"})  # no floor_was_valid key

	assert_bool(snap.floor_was_valid).is_true()


# ---------------------------------------------------------------------------
# Combined error + invalid-floor scenario
#   The "authoring bug" path: empty kill_schedule + invalid archetypes →
#   mark_floor_invalid_for_offline_replay() flips the flag, then
#   report_offline_replay_error() signals the run-ended cascade.
# ---------------------------------------------------------------------------

func test_combined_authoring_bug_path_marks_invalid_then_reports_error() -> void:
	# Arrange
	var orch: Node = _make_orch_in_offline_replay("authoring_bug_floor")
	orch.run_snapshot.kill_schedule = []  # empty → triggers authoring-bug branch in the engine
	var emissions: Array[Array] = []
	orch.validation_failed.connect(
		func(reason: String, payload: Dictionary) -> void:
			emissions.append([reason, payload])
	)

	# Act — engine detects empty kill_schedule + invalid archetypes
	orch.mark_floor_invalid_for_offline_replay()
	orch.report_offline_replay_error(0)

	# Assert — both effects landed
	assert_bool(orch.run_snapshot.floor_was_valid).is_false()
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	assert_int(emissions.size()).is_equal(1)
	assert_str(emissions[0][0]).is_equal("offline_replay_error")
