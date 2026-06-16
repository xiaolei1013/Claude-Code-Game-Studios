# Sprint 11 S11-M3c: DungeonRunOrchestrator Save/Load consumer surface.
#
# Verifies the get_save_data + load_save_data pair per:
#   - design/gdd/dungeon-run-orchestrator.md §F Save/Load row (canonical
#     schema: {} when NO_RUN; {"active_run": <RunSnapshot.to_dict()>} when
#     a run is in flight).
#   - ADR-0014 §RunSnapshot save-persisted schema.
#   - Save/Load GDD §C consumer contract (Pass-5+ canonical
#     get_save_data / load_save_data pair).
#
# Sprint 11 minimal-scope load_save_data: the active-run resume path is
# deferred to Sprint 12+ (OfflineProgressionEngine rank 15 unimplemented).
# Tests below verify the discard-with-warning behavior; the resume-path
# tests will land alongside the Sprint 12+ OfflineProgressionEngine work.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")


func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


# ===========================================================================
# Group A — get_save_data (NO_RUN path)
# ===========================================================================

func test_get_save_data_returns_empty_dict_when_state_is_no_run() -> void:
	# Initial orchestrator state is NO_RUN with run_snapshot == null.
	# Per GDD §F: "Returns ... {} if NO_RUN".
	var orch: Node = _make_orch()
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_object(orch.run_snapshot).is_null()

	var data: Dictionary = orch.get_save_data()
	assert_int(data.size()).is_equal(0)


func test_get_save_data_returns_empty_dict_when_run_snapshot_is_null_even_in_other_states() -> void:
	# Defensive: even if state advanced past NO_RUN somehow, a null run_snapshot
	# means there's no run state to persist. The condition is OR (NO_RUN OR
	# run_snapshot == null) per the implementation.
	var orch: Node = _make_orch()
	# Force a non-NO_RUN state with null run_snapshot — degenerate case but
	# must not crash and must return empty dict.
	orch.state = DungeonRunStateScript.State.DISPATCHING
	orch.run_snapshot = null

	var data: Dictionary = orch.get_save_data()
	assert_int(data.size()).is_equal(0)


# ===========================================================================
# Group B — get_save_data (active-run path)
# ===========================================================================

func test_get_save_data_returns_active_run_payload_when_run_in_flight() -> void:
	# When state is non-NO_RUN AND run_snapshot is non-null, the dict has
	# exactly one key "active_run" carrying RunSnapshot.to_dict() output.
	var orch: Node = _make_orch()

	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.floor_id = "forest_reach:1"
	snap.current_tick = 42
	snap.kill_count = 3
	snap.losing_run = false
	orch.run_snapshot = snap
	orch.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	var data: Dictionary = orch.get_save_data()
	assert_int(data.size()).is_equal(1)
	assert_bool(data.has("active_run")).is_true()
	assert_bool(data["active_run"] is Dictionary).is_true()


func test_get_save_data_active_run_payload_round_trips_via_run_snapshot_to_dict() -> void:
	# Lock the schema: the active_run sub-dict must equal RunSnapshot.to_dict().
	# This is the canonical GDD §F contract — future tests + Sprint 12+
	# resume-path implementation depend on this equality.
	var orch: Node = _make_orch()

	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.floor_id = "forest_reach:2"
	snap.current_tick = 100
	snap.last_emitted_tick = 95
	snap.loop_counter = 1
	snap.kill_count = 7
	snap.losing_run = true
	snap.floor_clear_emitted = false
	orch.run_snapshot = snap
	orch.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	var data: Dictionary = orch.get_save_data()
	var expected_subdict: Dictionary = snap.to_dict()
	# Compare key sets first (clearer failure mode than dict equality if a key
	# is dropped or added).
	var actual_subdict: Dictionary = data["active_run"]
	assert_int(actual_subdict.size()).is_equal(expected_subdict.size())
	for key: String in expected_subdict.keys():
		assert_bool(actual_subdict.has(key)).is_true()
	# Spot-check critical fields.
	assert_str(str(actual_subdict["floor_id"])).is_equal("forest_reach:2")
	assert_int(int(actual_subdict["current_tick"])).is_equal(100)
	assert_int(int(actual_subdict["kill_count"])).is_equal(7)
	assert_bool(bool(actual_subdict["losing_run"])).is_true()


# ===========================================================================
# Group C — load_save_data (Sprint 11 minimal-scope behavior)
# ===========================================================================

func test_load_save_data_with_empty_dict_is_noop() -> void:
	# Empty dict means saved state was NO_RUN. Defaults preserved.
	var orch: Node = _make_orch()
	# Pre-condition: NO_RUN defaults.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_object(orch.run_snapshot).is_null()

	orch.load_save_data({})

	# Post-condition: unchanged.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_object(orch.run_snapshot).is_null()


func test_load_save_data_with_active_run_discards_to_no_run_with_warning() -> void:
	# Sprint 11 minimal-scope: load_save_data with an active_run payload
	# discards the snapshot and leaves NO_RUN, warning out via push_warning.
	# Sprint 12+ OfflineProgressionEngine work replaces this with a real
	# resume path.
	var orch: Node = _make_orch()
	var saved: Dictionary = {
		"active_run": {
			"floor_id": "forest_reach:1",
			"current_tick": 42,
			"kill_count": 3,
		},
	}

	orch.load_save_data(saved)

	# State unchanged from defaults — Sprint 11 conservative behavior.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_object(orch.run_snapshot).is_null()


func test_load_save_data_with_unknown_schema_preserves_defaults() -> void:
	# Defensive: unrecognized schema variants should preserve defaults + warn,
	# not crash. This guards against schema drift between save versions.
	var orch: Node = _make_orch()
	orch.load_save_data({"some_future_key": "future_value"})

	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_object(orch.run_snapshot).is_null()


# ===========================================================================
# Group D — round-trip property (NO_RUN ↔ NO_RUN)
# ===========================================================================

func test_no_run_save_load_round_trip_preserves_no_run_state() -> void:
	# Save → load when starting from NO_RUN should always end at NO_RUN.
	# This is the only fully-supported round-trip in Sprint 11; the active-
	# run round-trip lands with OfflineProgressionEngine in Sprint 12+.
	var orch: Node = _make_orch()
	var saved: Dictionary = orch.get_save_data()
	# Confirm we got the NO_RUN representation.
	assert_int(saved.size()).is_equal(0)

	# Now load it back into a fresh orchestrator.
	var orch2: Node = _make_orch()
	orch2.load_save_data(saved)

	assert_int(orch2.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_object(orch2.run_snapshot).is_null()


# ===========================================================================
# Group E — Save/Load consumer contract surface
# ===========================================================================

func test_orchestrator_get_save_data_method_exists() -> void:
	var orch: Node = _make_orch()
	assert_bool(orch.has_method("get_save_data")).is_true()


func test_orchestrator_load_save_data_method_exists() -> void:
	var orch: Node = _make_orch()
	assert_bool(orch.has_method("load_save_data")).is_true()


# ===========================================================================
# Group F — code review 2026-06-16 (I3): offline-resume floor recovery
# ===========================================================================

func test_load_save_data_active_run_recovers_offline_resume_floor_and_biome() -> void:
	# I3: a persisted active_run restores the floor the player was on into the
	# DECOUPLED offline-resume fields (parsed from the composite floor_id), so offline
	# rewards compute at that floor instead of floor 1. The foreground FSM is NOT
	# resumed — _dispatched_floor_index / get_active_floor_index stay 0 so the at-home
	# foreground drip is unaffected.
	var orch: Node = _make_orch()
	orch.load_save_data({"active_run": {"floor_id": "forest_reach_floor_3", "current_tick": 80}})
	assert_int(orch._offline_resume_floor_index).is_equal(3)
	assert_str(orch._offline_resume_biome_id).is_equal("forest_reach")
	assert_int(orch.get_offline_resume_floor_index()).is_equal(3)
	# Foreground untouched.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_int(orch.get_active_floor_index()).is_equal(0)
	assert_int(orch._dispatched_floor_index).is_equal(0)


func test_load_save_data_resume_floor_parses_biome_with_underscores() -> void:
	# The composite split must handle biome ids that themselves contain underscores
	# (split on the LAST "_floor_").
	var orch: Node = _make_orch()
	orch.load_save_data({"active_run": {"floor_id": "ember_wastes_floor_5"}})
	assert_int(orch._offline_resume_floor_index).is_equal(5)
	assert_str(orch._offline_resume_biome_id).is_equal("ember_wastes")


func test_load_save_data_unparseable_floor_id_leaves_resume_unset() -> void:
	# A floor_id not in "<biome>_floor_<index>" shape → no resume; offline falls back
	# to floor 1, orchestrator stays NO_RUN (matches the prior discard contract).
	var orch: Node = _make_orch()
	orch.load_save_data({"active_run": {"floor_id": "forest_reach:1"}})
	assert_int(orch._offline_resume_floor_index).is_equal(0)
	assert_str(orch._offline_resume_biome_id).is_equal("")
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_object(orch.run_snapshot).is_null()
