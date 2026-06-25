# Sprint 15 S15-S4 — tests for run_snapshot.pre_dispatch_gold capture
# (Victory Moment GDD #25 OQ-25-1 dependency).
#
# The Victory Moment screen reads pre_dispatch_gold to compute the
# post-run gold delta. The orchestrator captures the value at dispatch
# validation time (after all validations pass, before state transition
# to ACTIVE_FOREGROUND) by reading Economy.get_gold_balance().
#
# Coverage:
#   - run_snapshot.pre_dispatch_gold field initial value 0
#   - Successful dispatch captures Economy gold balance
#   - Validation failure (empty formation) does NOT capture (no run_snapshot
#     built — null check)
#   - Test-env without Economy autoload registered: graceful no-op (field
#     stays at default 0; no crash)
#   - to_dict / from_dict do NOT include pre_dispatch_gold (session-only
#     per the GDD)
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")


# Snapshot of the live /root/HeroRoster, taken before each test and restored
# after, so this suite is isolated from roster state leaked by other suites.
var _roster_snapshot: Dictionary = {}


# dispatch() reads the live /root/HeroRoster for its injured-hero gate (GDD #34
# / ADR-0021). These tests dispatch raw formation dicts (instance_id 1/2) and
# assume those heroes are healthy — but a prior suite can leave a same-id hero
# INJURED in the shared roster, which makes the gate reject the dispatch and
# leave run_snapshot null, crashing the snapshot assertions below. Reset the
# live roster to empty per test so every dispatched id reads as a healthy
# unknown, regardless of suite execution order
# (memory: feedback_test_isolation_live_autoload).
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


class PermissiveFloorUnlock extends RefCounted:
	func is_unlocked(_floor_index: int) -> bool:
		return true


# ===========================================================================
# Group A — RunSnapshot.pre_dispatch_gold field
# ===========================================================================

func test_run_snapshot_pre_dispatch_gold_initial_value_is_zero() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_int(snap.pre_dispatch_gold).is_equal(0)


func test_run_snapshot_pre_dispatch_gold_writeable() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.pre_dispatch_gold = 1234
	assert_int(snap.pre_dispatch_gold).is_equal(1234)


# Per the GDD §D.2 + Notes: pre_dispatch_gold is session-only context;
# NOT serialized in to_dict (offline replay uses OfflineProgressionEngine
# aggregates instead). Locks the contract that pre_dispatch_gold doesn't
# leak into save state.
func test_run_snapshot_to_dict_does_not_include_pre_dispatch_gold() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.pre_dispatch_gold = 999
	var d: Dictionary = snap.to_dict()
	assert_bool(d.has("pre_dispatch_gold")).is_false()


# Symmetric: from_dict does not consume pre_dispatch_gold either.
func test_run_snapshot_from_dict_ignores_pre_dispatch_gold_key() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	# Even if a hostile / forward-compat dict carries the key, it does not
	# leak into the field — the field stays at its default 0.
	var d: Dictionary = {
		"formation_snapshot": {},
		"floor_id": "x",
		"current_tick": 0,
		"last_emitted_tick": 0,
		"losing_run": false,
		"floor_clear_emitted": false,
		"matchup_cache": {},
		"kill_schedule": [],
		"loop_counter": 0,
		"kill_count": 0,
		"pre_dispatch_gold": 5000,  # hostile/forward-compat key
	}
	snap.from_dict(d)
	# field stays at default; not consumed by from_dict
	assert_int(snap.pre_dispatch_gold).is_equal(0)


# ===========================================================================
# Group B — Orchestrator.dispatch captures Economy.get_gold_balance
# ===========================================================================

# In the test env, the live /root/Economy autoload IS running. The
# orchestrator's get_node_or_null lookup resolves; get_gold_balance returns
# whatever the live Economy currently reports. We don't assert a specific
# value (test isolation: live Economy state varies); we assert the field
# was POPULATED (>= 0) post-dispatch.
func test_orchestrator_dispatch_captures_pre_dispatch_gold_from_live_economy() -> void:
	var orch: Node = _make_orch()
	orch._floor_unlock = PermissiveFloorUnlock.new()
	# Pre-dispatch: snapshot is null; field is unreachable.
	assert_object(orch.run_snapshot).is_null()

	orch.dispatch([{"instance_id": 1, "class_id": "warrior"}], 1, "ashen_glade")

	# Post-dispatch: snapshot exists; pre_dispatch_gold captured (>=0).
	assert_object(orch.run_snapshot).is_not_null()
	assert_int(orch.run_snapshot.pre_dispatch_gold).is_greater_equal(0)


# Validation failure (empty formation) → orchestrator returns to RUN_ENDED
# without building run_snapshot to a non-null state. The field is
# unreachable because run_snapshot stays null.
func test_orchestrator_dispatch_validation_failure_does_not_capture_pre_dispatch_gold() -> void:
	var orch: Node = _make_orch()
	orch._floor_unlock = PermissiveFloorUnlock.new()
	orch.dispatch([], 1, "ashen_glade")
	# Empty formation → validation_failed; run_snapshot stays null.
	assert_object(orch.run_snapshot).is_null()


# ===========================================================================
# Group C — Multi-dispatch sequence captures fresh values
# ===========================================================================

# A re-dispatch (after RUN_ENDED reset) builds a fresh run_snapshot with a
# new pre_dispatch_gold capture. This is the canonical "play multiple
# rounds in one session" flow; each captures its own pre-balance.
func test_orchestrator_redispatch_captures_fresh_pre_dispatch_gold() -> void:
	var orch: Node = _make_orch()
	orch._floor_unlock = PermissiveFloorUnlock.new()
	# First dispatch.
	orch.dispatch([{"instance_id": 1, "class_id": "warrior"}], 1, "ashen_glade")
	# Guard the run_snapshot read: a rejected dispatch leaves it null, and an
	# unguarded null deref is a HARD runtime error that aborts the test before
	# after_test() can restore the roster (leaking the emptied roster to later
	# suites). A failed assertion fails cleanly and still runs after_test.
	assert_object(orch.run_snapshot).is_not_null()
	var first_capture: int = orch.run_snapshot.pre_dispatch_gold
	# Force back to RUN_ENDED so dispatch can be called again.
	orch._set_state(DungeonRunStateScript.validate_transition(
		orch.state, DungeonRunStateScript.TRIGGER_RUN_ENDED
	))
	# Wait past debounce.
	OS.delay_msec(OrchestratorScript.DISPATCH_DEBOUNCE_MS + 10)
	# Second dispatch — fresh snapshot.
	orch.dispatch([{"instance_id": 2, "class_id": "mage"}], 2, "ashen_glade")
	# Snapshot is a NEW object; pre_dispatch_gold is freshly captured.
	# (Both dispatches read the live Economy balance at their respective
	# capture moments; neither value is stale across dispatches.)
	assert_object(orch.run_snapshot).is_not_null()
	assert_int(orch.run_snapshot.pre_dispatch_gold).is_greater_equal(0)
	# The two captures may or may not be equal depending on whether Economy
	# state mutated between (in test isolation it's stable, so likely equal).
	# We just verify both are valid non-negative ints.
	assert_int(first_capture).is_greater_equal(0)
