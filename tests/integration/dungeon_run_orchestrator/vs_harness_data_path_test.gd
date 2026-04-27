# Tests for Sprint 7 S7-M13: VS harness data path (autonomous-completable
# portion). Drives the full orchestrator pipeline end-to-end:
#   1. Fresh orchestrator + real DefaultCombatResolver + DefaultMatchupResolver
#   2. dispatch(formation, floor_index, biome_id) — validation passes,
#      snapshots built, ACTIVE_FOREGROUND entered
#   3. Simulated ticks fire — combat called per tick, kill_count advances
#   4. first_clear_in_range triggers RUN_ENDED transition
#
# UI-facing portions of S7-M13 (DispatchScreen UI, manual smoke session,
# playtest sessions) are inherently human-driven and tracked separately as
# Sprint 7 manual QA evidence (S7-M15/M16/M17). This test demonstrates the
# DATA HARNESS works — the kernel can drive a dispatch from start to finish
# without crashes, with real (non-spy) resolvers.
#
# Covers: VS harness data path AC: "one full [dispatch → tick-driven kills →
#         run end] cycle runs end-to-end without crashes" — the autonomous
#         portion that doesn't require a UI or human playtester.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

const WARRIOR_ID := "warrior"
const MAGE_ID := "mage"
const ROGUE_ID := "rogue"


func _make_hero(class_id: String, instance_id: int, level: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = level
	return h


# Build a fresh orchestrator wired with REAL DefaultCombatResolver +
# DefaultMatchupResolver (not spies). Floor unlock injection optional — when
# null, the orchestrator's null-fail-open path lets dispatch proceed.
func _make_orch_with_real_resolvers() -> Node:
	var orch: Node = OrchestratorScript.new()
	var combat: RefCounted = DefaultCombatResolverScript.new()
	var matchup: RefCounted = DefaultMatchupResolverScript.new()
	orch.set_combat_resolver(combat)
	orch.set_matchup_resolver(matchup)
	add_child(orch)
	auto_free(orch)
	return orch


func _data_registry_can_resolve_classes() -> bool:
	return DataRegistry.resolve("classes", WARRIOR_ID) != null


# ===========================================================================
# Group A: dispatch → ACTIVE_FOREGROUND transition
# ===========================================================================

func test_successful_dispatch_advances_to_active_foreground() -> void:
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped: DataRegistry not resolving classes")
		return
	var orch: Node = _make_orch_with_real_resolvers()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(MAGE_ID, 3),
	]
	orch.dispatch(formation, 1, "forest_reach")
	# After successful dispatch, state is ACTIVE_FOREGROUND (not DISPATCHING).
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


func test_successful_dispatch_builds_orchestrator_run_snapshot() -> void:
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([_make_hero(WARRIOR_ID, 1)], 1, "forest_reach")
	assert_object(orch.run_snapshot).is_not_null()
	assert_int(orch.run_snapshot.current_tick).is_equal(0)
	assert_int(orch.run_snapshot.last_emitted_tick).is_equal(0)
	assert_int(orch.run_snapshot.kill_count).is_equal(0)


func test_successful_dispatch_builds_combat_snapshot() -> void:
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([_make_hero(WARRIOR_ID, 1)], 1, "forest_reach")
	assert_object(orch._combat_snapshot).is_not_null()
	# CombatRunSnapshot fields populated.
	assert_float(orch._combat_snapshot.formation_dps_per_tick).is_greater(0.0)
	assert_int(orch._combat_snapshot.enemy_list.size()).is_greater(0)
	assert_int(orch._combat_snapshot.loops_per_run).is_greater(0)


# ===========================================================================
# Group B: tick subscription + combat call end-to-end
# ===========================================================================

func test_dispatch_subscribes_to_tick_system() -> void:
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([_make_hero(WARRIOR_ID, 1)], 1, "forest_reach")
	# Tick subscription is connected via _set_state(ACTIVE_FOREGROUND) hook.
	assert_bool(TickSystem.tick_fired.is_connected(orch._on_tick_fired)).is_true()


func test_simulated_tick_advances_run_snapshot_state() -> void:
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	var orch: Node = _make_orch_with_real_resolvers()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(MAGE_ID, 3),
	]
	orch.dispatch(formation, 1, "forest_reach")
	# Simulate a tick at tick 5 — combat fires, snapshot advances.
	orch._on_tick_fired(5)
	assert_int(orch.run_snapshot.last_emitted_tick).is_equal(5)
	assert_int(orch.run_snapshot.current_tick).is_equal(5)


# ===========================================================================
# Group C: full data path — dispatch → ticks → first_clear → RUN_ENDED
# ===========================================================================

func test_full_dispatch_to_run_ended_cycle() -> void:
	# End-to-end harness drive: dispatch a 3-hero formation, fire enough
	# simulated ticks to clear the floor (synthetic 3-enemy default OR real
	# Forest Reach floor 1), verify the run transitions to RUN_ENDED with
	# kill_count > 0.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped: DataRegistry not resolving classes")
		return
	var orch: Node = _make_orch_with_real_resolvers()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1, 5),
		_make_hero(WARRIOR_ID, 2, 5),
		_make_hero(WARRIOR_ID, 3, 5),
	]
	orch.dispatch(formation, 1, "forest_reach")
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	# Drive enough ticks to clear the floor. With 3 L5 warriors vs bruiser,
	# DPS is high; floor with 3 enemies clears within a small tick budget.
	# Sweep up to 1000 ticks to be defensive.
	var max_ticks: int = 1000
	for n: int in range(1, max_ticks + 1):
		orch._on_tick_fired(n)
		if orch.state == DungeonRunStateScript.State.RUN_ENDED:
			break

	# Verify the run actually ended (not stuck in ACTIVE_FOREGROUND forever).
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	# Kills accumulated.
	assert_int(orch.run_snapshot.kill_count).is_greater(0)
	# Tick subscription disconnected on AF exit.
	assert_bool(TickSystem.tick_fired.is_connected(orch._on_tick_fired)).is_false()


# ===========================================================================
# Group D: defensive edge — failed dispatch doesn't reach ACTIVE_FOREGROUND
# ===========================================================================

func test_empty_formation_dispatch_does_not_reach_active_foreground() -> void:
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([], 1, "forest_reach")
	# Empty formation → validation_failed → RUN_ENDED, NOT ACTIVE_FOREGROUND.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	# No snapshot built on validation failure (snapshot construction happens
	# AFTER validation passes).
	assert_object(orch.run_snapshot).is_null()
	assert_object(orch._combat_snapshot).is_null()


# ===========================================================================
# Group E: kill_count progression
# ===========================================================================

func test_kill_count_advances_per_tick_with_real_combat() -> void:
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([
		_make_hero(WARRIOR_ID, 1, 5),
		_make_hero(WARRIOR_ID, 2, 5),
		_make_hero(WARRIOR_ID, 3, 5),
	], 1, "forest_reach")
	# Drive ticks with reasonable budget; verify kill_count advances.
	for n: int in range(1, 200):
		orch._on_tick_fired(n)
		if orch.state == DungeonRunStateScript.State.RUN_ENDED:
			break
	# Synthetic floor has 3 enemies; expect kill_count = 3 by run end.
	# (Real Forest Reach floor 1 may have a different count; the test just
	# verifies kill_count > 0 — at least one kill happened during the run.)
	assert_int(orch.run_snapshot.kill_count).is_greater(0)


# ===========================================================================
# Group F: snapshot persistence — RunSnapshot.kill_count round-trips
# ===========================================================================

func test_run_snapshot_kill_count_persists_via_to_dict() -> void:
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([_make_hero(WARRIOR_ID, 1, 5)], 1, "forest_reach")
	# Drive a few ticks.
	for n: int in [1, 2, 3, 5, 10, 20, 50]:
		orch._on_tick_fired(n)
	# Snapshot's kill_count should round-trip through to_dict.
	var saved: Dictionary = orch.run_snapshot.to_dict()
	assert_bool(saved.has("kill_count")).is_true()
	assert_int(int(saved["kill_count"])).is_equal(orch.run_snapshot.kill_count)
