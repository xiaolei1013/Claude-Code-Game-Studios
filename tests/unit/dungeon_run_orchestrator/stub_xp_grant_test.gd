# Sprint 10 S10-M4: tests for the orchestrator's stub XP grant
# (_grant_stub_levels_to_formation).
#
# Scope: pure-function behavior of the grant helper using a stub roster Node
# that implements get_all_heroes + set_hero_level. The Layer 2 idempotency
# gate (run_snapshot.floor_clear_emitted) is part of the call site (not the
# helper) and is covered by the existing kill_attribution_and_signals_test.gd
# floor_cleared_first_time tests; here we test the helper in isolation.
#
# Stub formula in scope (Sprint 10): flat +1 level per surviving formation
# hero, capped at HeroRoster.level_cap. Sprint 11 replaces with proper XP curve.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")


# ---------------------------------------------------------------------------
# Test helpers — stub roster that records set_hero_level calls.
# ---------------------------------------------------------------------------

# A minimal stand-in for HeroRoster. The orchestrator's _grant_stub_levels_to_formation
# only requires .get_all_heroes() and .set_hero_level(id, new_level). The
# get_all_heroes return values use Dictionary entries (orchestrator reads them
# via "field" in hero + hero.get("field"), which works identically for Object
# and Dictionary with single-arg get).
class StubRoster extends Node:
	var _seeded_heroes: Array[Dictionary] = []
	var set_hero_level_calls: Array[Dictionary] = []

	func seed_hero(instance_id: int, current_level: int, display_name: String = "") -> void:
		_seeded_heroes.append({
			"instance_id": instance_id,
			"current_level": current_level,
			"display_name": display_name,
		})

	func get_all_heroes() -> Array:
		# Return a copy so callers cannot mutate our internal state.
		return _seeded_heroes.duplicate(true)

	func set_hero_level(id: int, new_level: int) -> bool:
		set_hero_level_calls.append({"id": id, "new_level": new_level})
		return true


func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


func _make_stub_roster() -> StubRoster:
	var sr: StubRoster = StubRoster.new()
	add_child(sr)
	auto_free(sr)
	return sr


func _seed_run_snapshot_with_formation_ids(orch: Node, ids: Array[int]) -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.formation_snapshot = {"instance_ids": ids, "heroes": []}
	orch.run_snapshot = snap


# ===========================================================================
# Group A — happy-path grant
# ===========================================================================

func test_orchestrator_stub_grant_increments_each_formation_hero_by_one_level() -> void:
	# Arrange — 3 heroes at varying starting levels; all dispatched.
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	roster.seed_hero(11, 1, "Theron")
	roster.seed_hero(12, 4, "Mira")
	roster.seed_hero(13, 9, "Kaeden")
	_seed_run_snapshot_with_formation_ids(orch, [11, 12, 13])

	# Act
	orch._grant_stub_levels_to_formation(roster)

	# Assert — each formation hero got exactly one set_hero_level call with
	# current_level + 1.
	assert_int(roster.set_hero_level_calls.size()).is_equal(3)
	# Lookup-by-id assertion to tolerate iteration order changes.
	var calls_by_id: Dictionary = {}
	for c: Dictionary in roster.set_hero_level_calls:
		calls_by_id[int(c.id)] = int(c.new_level)
	assert_int(int(calls_by_id[11])).is_equal(2)
	assert_int(int(calls_by_id[12])).is_equal(5)
	assert_int(int(calls_by_id[13])).is_equal(10)


func test_orchestrator_stub_grant_skips_empty_slot_id_zero() -> void:
	# Arrange — two real heroes plus an "empty slot" sentinel id 0.
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	roster.seed_hero(11, 1)
	roster.seed_hero(12, 2)
	_seed_run_snapshot_with_formation_ids(orch, [11, 0, 12])

	# Act
	orch._grant_stub_levels_to_formation(roster)

	# Assert — exactly two grants; id 0 ignored.
	assert_int(roster.set_hero_level_calls.size()).is_equal(2)
	for c: Dictionary in roster.set_hero_level_calls:
		assert_int(int(c.id)).is_not_equal(0)


func test_orchestrator_stub_grant_skips_unknown_id_not_in_roster() -> void:
	# Arrange — formation references id 99 that was removed before clear.
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	roster.seed_hero(11, 3)
	_seed_run_snapshot_with_formation_ids(orch, [11, 99])

	# Act
	orch._grant_stub_levels_to_formation(roster)

	# Assert — only the known hero gets a grant; unknown id silently skipped.
	assert_int(roster.set_hero_level_calls.size()).is_equal(1)
	assert_int(int(roster.set_hero_level_calls[0].id)).is_equal(11)
	assert_int(int(roster.set_hero_level_calls[0].new_level)).is_equal(4)


# ===========================================================================
# Group B — early-return guards (defensive)
# ===========================================================================

func test_orchestrator_stub_grant_no_run_snapshot_is_noop() -> void:
	# Arrange — orchestrator has no run_snapshot set yet (NO_RUN state).
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	roster.seed_hero(11, 1)
	# Note: _make_orch leaves run_snapshot at its initial null value.

	# Act
	orch._grant_stub_levels_to_formation(roster)

	# Assert — no calls; helper early-returned on null run_snapshot.
	assert_int(roster.set_hero_level_calls.size()).is_equal(0)


func test_orchestrator_stub_grant_empty_formation_is_noop() -> void:
	# Arrange — run_snapshot exists but formation_snapshot.instance_ids is empty.
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	roster.seed_hero(11, 1)
	_seed_run_snapshot_with_formation_ids(orch, [])

	# Act
	orch._grant_stub_levels_to_formation(roster)

	# Assert — no calls; helper early-returned on empty ids.
	assert_int(roster.set_hero_level_calls.size()).is_equal(0)


func test_orchestrator_stub_grant_null_roster_is_noop() -> void:
	# Arrange — formation has heroes but roster autoload is missing
	# (test-env path: get_node_or_null returns null in some contexts).
	var orch: Node = _make_orch()
	_seed_run_snapshot_with_formation_ids(orch, [11, 12])

	# Act / Assert — no crash on null roster argument.
	orch._grant_stub_levels_to_formation(null)
	assert_bool(true).is_true()


func test_orchestrator_stub_grant_missing_formation_snapshot_key_is_noop() -> void:
	# Arrange — run_snapshot.formation_snapshot present but lacks instance_ids
	# key (defensive against schema drift).
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	roster.seed_hero(11, 1)
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.formation_snapshot = {}  # no instance_ids key
	orch.run_snapshot = snap

	# Act
	orch._grant_stub_levels_to_formation(roster)

	# Assert — no calls.
	assert_int(roster.set_hero_level_calls.size()).is_equal(0)
