# Tests for GDD #34 Phase 3 (Defeat & Injury System / ADR-0021 — AC-34-04): the
# orchestrator DISPATCH gate that rejects a formation containing an injured hero.
#
# Contract (Validation 3 in dispatch(), after the floor-lock check):
#   - Any dispatched hero still recovering (is_hero_injured == true at now) →
#     validation_failed("hero_injured", {injured_ids: [...]}) + state RUN_ENDED.
#   - A fully-healthy formation dispatches normally (→ ACTIVE_FOREGROUND).
#   - Mixed formation reports ONLY the injured ids in the payload.
#   - The gate runs AFTER floor-lock, so a locked floor still reports floor_locked.
#
# These mutate the LIVE /root/HeroRoster, so they snapshot+restore it via
# HeroRosterTestFixture (memory: feedback_test_isolation_live_autoload).
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")


# Spy FloorUnlock that always reports unlocked, so dispatch reaches Validation 3.
class _SpyFloorUnlock extends RefCounted:
	func is_unlocked(_floor_index: int) -> bool:
		return true


var _roster_snapshot: Dictionary = {}


func before_test() -> void:
	_roster_snapshot = HeroRosterFixture.snapshot_via_save_data()
	HeroRosterFixture.reset_hero_roster()


func after_test() -> void:
	HeroRosterFixture.restore_via_load_save_data(_roster_snapshot)


func _roster() -> Node:
	return get_tree().root.get_node_or_null("HeroRoster")


# Inject a HeroInstance into the live roster's _heroes and return it. The same
# object doubles as a duck-typed formation member (it carries instance_id).
func _inject_hero(roster: Node, id: int, injured_until: int = 0) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = "warrior"
	fake.display_name = "Test Hero %d" % id
	fake.current_level = 1
	fake.injured_until = injured_until
	roster._heroes[id] = fake
	return fake


# Orchestrator with an always-unlocked floor spy so floor-lock never blocks.
func _make_orch_unlocked() -> Node:
	var orch: Node = OrchestratorScript.new()
	orch.set_floor_unlock(_SpyFloorUnlock.new())  # DI before add_child
	add_child(orch)
	auto_free(orch)
	return orch


func _collect_validation_failures(orch: Node) -> Array:
	var emissions: Array = []
	orch.validation_failed.connect(
		func(reason: String, payload: Dictionary) -> void:
			emissions.append([reason, payload])
	)
	return emissions


# ===========================================================================
# Group A: injured formation is rejected (AC-34-04)
# ===========================================================================

func test_dispatch_with_injured_hero_emits_hero_injured_validation_failed() -> void:
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var future_ms: int = TickSystem.now_ms() + 3_600_000  # injured for ~1h
	var injured: RefCounted = _inject_hero(roster, 1, future_ms)

	var orch: Node = _make_orch_unlocked()
	var emissions: Array = _collect_validation_failures(orch)

	orch.dispatch([injured], 3, "forest_reach")

	var hero_injured: Array = []
	for e: Array in emissions:
		if e[0] == "hero_injured":
			hero_injured.append(e)
	assert_int(hero_injured.size()).is_equal(1)
	var payload: Dictionary = hero_injured[0][1]
	assert_array(payload.get("injured_ids", [])).is_equal([1])
	# Rejected dispatch terminates the would-be run.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)


func test_dispatch_blocked_run_does_not_reach_active_foreground() -> void:
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var injured: RefCounted = _inject_hero(roster, 1, TickSystem.now_ms() + 3_600_000)

	var orch: Node = _make_orch_unlocked()
	orch.dispatch([injured], 3, "forest_reach")

	assert_int(orch.state).is_not_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


# ===========================================================================
# Group B: healthy formation dispatches normally (control)
# ===========================================================================

func test_dispatch_with_healthy_formation_advances_to_active_foreground() -> void:
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var healthy: RefCounted = _inject_hero(roster, 1, 0)  # never injured

	var orch: Node = _make_orch_unlocked()
	var emissions: Array = _collect_validation_failures(orch)

	orch.dispatch([healthy], 1, "forest_reach")

	# No hero_injured emission; the run goes live.
	for e: Array in emissions:
		assert_str(String(e[0])).is_not_equal("hero_injured")
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


func test_dispatch_with_already_recovered_hero_is_allowed() -> void:
	# A hero whose injured_until has elapsed (now >= injured_until) is healthy.
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	# injured_until in the PAST → is_hero_injured(now) is false.
	var recovered: RefCounted = _inject_hero(roster, 1, TickSystem.now_ms() - 1000)

	var orch: Node = _make_orch_unlocked()
	orch.dispatch([recovered], 1, "forest_reach")

	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


# ===========================================================================
# Group C: mixed formation reports only the injured ids
# ===========================================================================

func test_dispatch_mixed_formation_reports_only_injured_ids() -> void:
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var future_ms: int = TickSystem.now_ms() + 3_600_000
	var h1: RefCounted = _inject_hero(roster, 1, 0)          # healthy
	var h2: RefCounted = _inject_hero(roster, 2, future_ms)  # injured
	var h3: RefCounted = _inject_hero(roster, 3, 0)          # healthy

	var orch: Node = _make_orch_unlocked()
	var emissions: Array = _collect_validation_failures(orch)

	orch.dispatch([h1, h2, h3], 3, "forest_reach")

	var hero_injured: Array = []
	for e: Array in emissions:
		if e[0] == "hero_injured":
			hero_injured.append(e)
	assert_int(hero_injured.size()).is_equal(1)
	assert_array(hero_injured[0][1].get("injured_ids", [])).is_equal([2])
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)


# ===========================================================================
# Group D: floor-lock still takes priority over the injury gate
# ===========================================================================

func test_locked_floor_reports_floor_locked_not_hero_injured() -> void:
	# Even with an injured hero in the formation, a LOCKED floor is reported
	# first (the injury gate sits after the floor-lock check).
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var injured: RefCounted = _inject_hero(roster, 1, TickSystem.now_ms() + 3_600_000)

	# Locked floor spy.
	var orch: Node = OrchestratorScript.new()
	orch.set_floor_unlock(_LockedFloorSpy.new())
	add_child(orch)
	auto_free(orch)
	var emissions: Array = _collect_validation_failures(orch)

	orch.dispatch([injured], 3, "forest_reach")

	var reasons: Array = []
	for e: Array in emissions:
		reasons.append(String(e[0]))
	assert_bool(reasons.has("floor_locked")).is_true()
	assert_bool(reasons.has("hero_injured")).is_false()
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)


class _LockedFloorSpy extends RefCounted:
	func is_unlocked(_floor_index: int) -> bool:
		return false
