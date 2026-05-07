# Sprint 14 S14-M4 Story 3 — tests for the orchestrator's real XP grant
# helper (_grant_xp_to_formation) per Hero Leveling GDD #15 §C.1 / §C.2 /
# §C.6. Replaces the Sprint 10 S10-M4 stub grant tests (filename retained
# for git-history continuity). Helper-isolation tests; the kill-loop +
# floor-clear call-site integration is covered separately in
# kill_attribution_and_signals_test.gd.
#
# ACs covered:
#   AC-15-01 — XP grant per kill matches Formula D.1
#   AC-15-02 — XP grant per floor clear matches Formula D.2
#   AC-15-06 — XP grant respects formation determinism (snapshot at dispatch)
#   AC-15-14 — _grant_stub_levels_to_formation removed from orchestrator
#   defensive guards: null roster / empty formation / null run_snapshot
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")


# A minimal stand-in for HeroRoster. _grant_xp_to_formation only requires
# .add_xp(id, amount). Records every call for assertion.
class StubRoster extends Node:
	var add_xp_calls: Array[Dictionary] = []

	func add_xp(id: int, amount: int) -> bool:
		add_xp_calls.append({"id": id, "amount": amount})
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
# Group A — happy-path: per-hero XP grant equals xp_amount
# ===========================================================================

func test_orchestrator_xp_grant_calls_add_xp_per_formation_hero() -> void:
	# Arrange — 3 heroes dispatched.
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	_seed_run_snapshot_with_formation_ids(orch, [11, 12, 13])

	# Act — grant 17 XP to the formation.
	orch._grant_xp_to_formation(roster, 17)

	# Assert — exactly three add_xp calls, each with amount=17.
	assert_int(roster.add_xp_calls.size()).is_equal(3)
	var ids_seen: Array[int] = []
	for c: Dictionary in roster.add_xp_calls:
		assert_int(int(c.amount)).is_equal(17)
		ids_seen.append(int(c.id))
	assert_array(ids_seen).contains([11, 12, 13])


func test_orchestrator_xp_grant_skips_empty_slot_id_zero() -> void:
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	_seed_run_snapshot_with_formation_ids(orch, [11, 0, 12])

	orch._grant_xp_to_formation(roster, 5)

	# id 0 sentinel skipped.
	assert_int(roster.add_xp_calls.size()).is_equal(2)
	for c: Dictionary in roster.add_xp_calls:
		assert_int(int(c.id)).is_not_equal(0)


# ===========================================================================
# Group B — early-return guards (defensive)
# ===========================================================================

func test_orchestrator_xp_grant_zero_amount_is_noop() -> void:
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	_seed_run_snapshot_with_formation_ids(orch, [11, 12, 13])

	orch._grant_xp_to_formation(roster, 0)

	assert_int(roster.add_xp_calls.size()).is_equal(0)


func test_orchestrator_xp_grant_negative_amount_is_noop() -> void:
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	_seed_run_snapshot_with_formation_ids(orch, [11, 12, 13])

	orch._grant_xp_to_formation(roster, -50)

	assert_int(roster.add_xp_calls.size()).is_equal(0)


func test_orchestrator_xp_grant_no_run_snapshot_is_noop() -> void:
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	# Note: _make_orch leaves run_snapshot at its initial null value.

	orch._grant_xp_to_formation(roster, 100)

	assert_int(roster.add_xp_calls.size()).is_equal(0)


func test_orchestrator_xp_grant_empty_formation_is_noop() -> void:
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	_seed_run_snapshot_with_formation_ids(orch, [])

	orch._grant_xp_to_formation(roster, 100)

	assert_int(roster.add_xp_calls.size()).is_equal(0)


func test_orchestrator_xp_grant_null_roster_is_noop() -> void:
	var orch: Node = _make_orch()
	_seed_run_snapshot_with_formation_ids(orch, [11, 12])

	# Should not crash on null roster argument.
	orch._grant_xp_to_formation(null, 100)
	assert_bool(true).is_true()


func test_orchestrator_xp_grant_missing_formation_snapshot_key_is_noop() -> void:
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.formation_snapshot = {}  # no instance_ids key
	orch.run_snapshot = snap

	orch._grant_xp_to_formation(roster, 100)

	assert_int(roster.add_xp_calls.size()).is_equal(0)


# ===========================================================================
# Group C — AC-15-01 xp_per_kill formula matches Hero Leveling §C.1 / §D.1
# ===========================================================================

func test_orchestrator_xp_per_kill_returns_default_per_tier_values() -> void:
	# Defaults from Hero Leveling §C.1: {1: 5, 2: 10, 3: 20, 4: 40, 5: 80}.
	# Live Economy autoload provides EconomyConfig with these values; the
	# fallback constants match.
	var orch: Node = _make_orch()
	assert_int(orch.xp_per_kill(1)).is_equal(5)
	assert_int(orch.xp_per_kill(2)).is_equal(10)
	assert_int(orch.xp_per_kill(3)).is_equal(20)
	assert_int(orch.xp_per_kill(4)).is_equal(40)
	assert_int(orch.xp_per_kill(5)).is_equal(80)


# AC-15-10 — unknown tier defaults to tier-1 XP (5 by default) + push_warning.
func test_orchestrator_xp_per_kill_unknown_tier_defaults_to_tier_1() -> void:
	var orch: Node = _make_orch()
	# Tier 99 is config-drift territory — fallback to tier 1 = 5.
	assert_int(orch.xp_per_kill(99)).is_equal(5)


# ===========================================================================
# Group D — AC-15-02 xp_per_floor_clear formula matches §C.2 / §D.2
# ===========================================================================

func test_orchestrator_xp_per_floor_clear_returns_linear_curve() -> void:
	# Defaults from §C.2: BASE=50, STEP=25.
	# Floor 1 = 50, Floor 2 = 75, Floor 3 = 100, Floor 4 = 125, Floor 5 = 150.
	var orch: Node = _make_orch()
	assert_int(orch.xp_per_floor_clear(1)).is_equal(50)
	assert_int(orch.xp_per_floor_clear(2)).is_equal(75)
	assert_int(orch.xp_per_floor_clear(3)).is_equal(100)
	assert_int(orch.xp_per_floor_clear(4)).is_equal(125)
	assert_int(orch.xp_per_floor_clear(5)).is_equal(150)


func test_orchestrator_xp_per_floor_clear_zero_or_negative_is_zero() -> void:
	var orch: Node = _make_orch()
	# Negative / zero floor index returns 0 (silent no-op upstream).
	assert_int(orch.xp_per_floor_clear(0)).is_equal(0)
	assert_int(orch.xp_per_floor_clear(-1)).is_equal(0)


# ===========================================================================
# Group E — AC-15-06 formation determinism (snapshot at dispatch, not live)
# ===========================================================================

# The helper reads run_snapshot.formation_snapshot.instance_ids — the FROZEN
# dispatch-time formation. If a hero is swapped out post-dispatch but the
# snapshot is unchanged, XP still flows to the snapshot's ids (the swapped-in
# hero earns from their own subsequent kills via a refreshed snapshot —
# tested at the dispatch integration layer).
func test_orchestrator_xp_grant_uses_snapshot_formation_not_live_roster() -> void:
	var orch: Node = _make_orch()
	var roster: StubRoster = _make_stub_roster()
	# Snapshot says formation = [11, 12, 13]. Roster is queried only via
	# add_xp; the helper does NOT call get_all_heroes or set_formation_slot.
	_seed_run_snapshot_with_formation_ids(orch, [11, 12, 13])

	orch._grant_xp_to_formation(roster, 25)

	# Calls go to ids 11, 12, 13 (the snapshot ids), regardless of any
	# theoretical live-roster mutation.
	assert_int(roster.add_xp_calls.size()).is_equal(3)
	var ids_seen: Array[int] = []
	for c: Dictionary in roster.add_xp_calls:
		ids_seen.append(int(c.id))
	ids_seen.sort()
	assert_array(ids_seen).is_equal([11, 12, 13])


# ===========================================================================
# Group F — AC-15-14 stub helper removed
# ===========================================================================

# The helper renamed from _grant_stub_levels_to_formation → _grant_xp_to_formation
# per AC-15-14. This test asserts the stub method no longer exists on the
# orchestrator; future maintainers attempting to call the old name fail loudly.
func test_orchestrator_grant_stub_levels_to_formation_no_longer_exists() -> void:
	var orch: Node = _make_orch()
	assert_bool(orch.has_method("_grant_stub_levels_to_formation")).is_false()
	assert_bool(orch.has_method("_grant_xp_to_formation")).is_true()
