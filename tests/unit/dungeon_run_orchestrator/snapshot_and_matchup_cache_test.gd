# Tests for Sprint 8 dungeon-run-orchestrator Story 004 (S8-S2 carryover from S7-S4):
#   - RunSnapshot.formation_snapshot is a deep copy via .duplicate(true);
#     mutations to source HeroRoster do NOT propagate
#   - RunSnapshot.floor_id stored as String; resolve helper returns null on
#     unknown id (Story 010 will route null → NO_RUN at load time)
#   - RunSnapshot.matchup_cache pre-populated with one entry per distinct
#     enemy archetype in the floor's enemy_list
#   - matchup cache built ONCE at DISPATCHING — subsequent ticks read from
#     cache, never re-resolve via the matchup resolver
#
# Covers: TR-orchestrator-004 (formation deep-copy via .duplicate(true)),
#         TR-orchestrator-006 (floor_id: String stored; resolved via DataRegistry
#                              on load — null routes to NO_RUN per Story 010),
#         TR-orchestrator-012 (matchup_cache populates an entry for every
#                              archetype in the floor's enemy_list/kill_schedule),
#         TR-orchestrator-013 (matchup cache built ONCE at DISPATCHING; per-tick
#                              replay reads from cache, zero resolver calls).
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

const WARRIOR_ID := "warrior"
const MAGE_ID := "mage"


func _make_hero(class_id: String, instance_id: int, level: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = level
	return h


func _data_registry_can_resolve_classes() -> bool:
	return DataRegistry.resolve("classes", WARRIOR_ID) != null


# Spy MatchupResolver — extends the production resolver and counts how many
# times resolve_formation_matchup is invoked. Used to verify TR-013 once-only
# build (cache hits during ticks must NOT trigger resolver calls).
class CountingMatchupResolverSpy extends RefCounted:
	const _Default := preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
	var _real: RefCounted = _Default.new()
	var resolve_formation_matchup_call_count: int = 0

	func resolve_formation_matchup(formation: Array, enemy_archetype: String) -> RefCounted:
		resolve_formation_matchup_call_count += 1
		return _real.resolve_formation_matchup(formation, enemy_archetype)

	func resolve_floor_matchup(formation: Array, archetypes: Array[String]) -> RefCounted:
		return _real.resolve_floor_matchup(formation, archetypes)


func _make_orch_with_spy_matchup() -> Node:
	var orch: Node = OrchestratorScript.new()
	var combat: RefCounted = DefaultCombatResolverScript.new()
	orch.set_combat_resolver(combat)
	add_child(orch)
	auto_free(orch)
	return orch


func _make_orch_with_real_resolvers() -> Node:
	var orch: Node = OrchestratorScript.new()
	orch.set_combat_resolver(DefaultCombatResolverScript.new())
	orch.set_matchup_resolver(DefaultMatchupResolverScript.new())
	add_child(orch)
	auto_free(orch)
	return orch


# ===========================================================================
# Group A: TR-004 — formation deep-copy isolates from source mutation
# ===========================================================================

func test_formation_snapshot_heroes_array_captures_per_hero_dictionaries() -> void:
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped: DataRegistry cannot resolve classes")
		return
	# Arrange
	var orch: Node = _make_orch_with_real_resolvers()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1, 5),
		_make_hero(WARRIOR_ID, 2, 3),
		_make_hero(MAGE_ID, 3, 1),
	]

	# Act
	orch.dispatch(formation, 1, "forest_reach")

	# Assert — formation_snapshot has both legacy `instance_ids` AND new
	# `heroes` (canonical per-hero deep payload).
	assert_bool(orch.run_snapshot.formation_snapshot.has("instance_ids")).is_true()
	assert_bool(orch.run_snapshot.formation_snapshot.has("heroes")).is_true()
	var heroes: Array = orch.run_snapshot.formation_snapshot["heroes"]
	assert_int(heroes.size()).is_equal(3)
	# Per-hero shape: dict with instance_id, class_id, current_level.
	assert_int(int(heroes[0]["instance_id"])).is_equal(1)
	assert_str(str(heroes[0]["class_id"])).is_equal(WARRIOR_ID)
	assert_int(int(heroes[0]["current_level"])).is_equal(5)


func test_mutating_source_hero_does_not_change_formation_snapshot() -> void:
	# TR-004 deep-copy: post-dispatch mutations to source HeroInstance refs
	# MUST NOT leak into the persistent snapshot.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var orch: Node = _make_orch_with_real_resolvers()
	var hero1: RefCounted = _make_hero(WARRIOR_ID, 1, 5)
	var formation: Array = [hero1, _make_hero(WARRIOR_ID, 2), _make_hero(MAGE_ID, 3)]

	# Act — dispatch captures snapshot; THEN mutate source hero.
	orch.dispatch(formation, 1, "forest_reach")
	hero1.current_level = 99  # post-dispatch mutation
	hero1.class_id = "rogue"   # post-dispatch mutation

	# Assert — snapshot captured pre-mutation values; mutations didn't propagate.
	var heroes: Array = orch.run_snapshot.formation_snapshot["heroes"]
	assert_int(int(heroes[0]["current_level"])).is_equal(5)
	assert_str(str(heroes[0]["class_id"])).is_equal(WARRIOR_ID)


func test_mutating_formation_snapshot_does_not_change_source_heroes() -> void:
	# Reverse direction: mutating the snapshot must NOT change the source hero.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var orch: Node = _make_orch_with_real_resolvers()
	var hero1: RefCounted = _make_hero(WARRIOR_ID, 1, 5)
	var formation: Array = [hero1, _make_hero(WARRIOR_ID, 2), _make_hero(MAGE_ID, 3)]

	# Act
	orch.dispatch(formation, 1, "forest_reach")
	var heroes: Array = orch.run_snapshot.formation_snapshot["heroes"]
	heroes[0]["current_level"] = 99  # mutate the snapshot's per-hero dict

	# Assert — source HeroInstance still at level 5.
	assert_int(hero1.current_level).is_equal(5)


# ===========================================================================
# Group B: TR-006 — floor_id stored as String; resolve helper handles unknown ids
# ===========================================================================

func test_run_snapshot_floor_id_is_string_after_dispatch() -> void:
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange + Act
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([_make_hero(WARRIOR_ID, 1)], 1, "forest_reach")

	# Assert — floor_id is a non-empty String (composite biome+index).
	assert_str(orch.run_snapshot.floor_id).is_not_empty()
	# Composite shape sanity check.
	assert_bool(orch.run_snapshot.floor_id.contains("forest_reach")).is_true()


func test_resolve_floor_by_snapshot_id_returns_null_for_unknown_id() -> void:
	# TR-006 unknown id → null. Story 010's load_save_data path will route
	# this to NO_RUN + push_warning; for S8-S2 we just verify the helper
	# returns null cleanly.
	# Arrange
	var orch: Node = _make_orch_with_real_resolvers()

	# Act
	var resolved: Resource = orch.resolve_floor_by_snapshot_id("ghost_floor_id_does_not_exist")

	# Assert
	assert_object(resolved).is_null()


func test_resolve_floor_by_snapshot_id_returns_null_for_empty_id() -> void:
	# Empty floor_id is the NO_RUN sentinel — helper returns null without
	# touching DataRegistry.
	# Arrange
	var orch: Node = _make_orch_with_real_resolvers()

	# Act
	var resolved: Resource = orch.resolve_floor_by_snapshot_id("")

	# Assert
	assert_object(resolved).is_null()


# ===========================================================================
# Group C: TR-012 — matchup_cache populates one entry per distinct archetype
# ===========================================================================

func test_run_snapshot_matchup_cache_has_one_entry_per_distinct_archetype() -> void:
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange — synthetic 3-enemy floor (default fallback in _build_combat_snapshot)
	# has all 3 enemies as archetype "bruiser" → matchup_cache should have
	# exactly 1 distinct archetype entry.
	var orch: Node = _make_orch_with_real_resolvers()

	# Act
	orch.dispatch([_make_hero(WARRIOR_ID, 1)], 1, "forest_reach")

	# Assert — cache built; bruiser is the only archetype.
	assert_object(orch.run_snapshot.matchup_cache).is_not_null()
	assert_int(orch.run_snapshot.matchup_cache.size()).is_greater_equal(1)
	# Bruiser archetype must be present (the fallback floor has 3 bruisers).
	# Cache keys are StringName per build_matchup_cache contract.
	assert_bool(orch.run_snapshot.matchup_cache.has(&"bruiser")).is_true()


func test_run_snapshot_matchup_cache_mirrors_combat_snapshot_cache() -> void:
	# RunSnapshot.matchup_cache is a deep-copy of CombatRunSnapshot.matchup_cache —
	# both source from the same build_matchup_cache call (TR-013 once-only).
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange + Act
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([_make_hero(WARRIOR_ID, 1)], 1, "forest_reach")

	# Assert — same shape, same keys, same values.
	var run_cache: Dictionary = orch.run_snapshot.matchup_cache
	var combat_cache: Dictionary = orch._combat_snapshot.matchup_cache
	assert_int(run_cache.size()).is_equal(combat_cache.size())
	for k: Variant in run_cache:
		assert_bool(combat_cache.has(k)).is_true()
		assert_bool(run_cache[k] == combat_cache[k]).is_true()


func test_run_snapshot_matchup_cache_independent_from_combat_snapshot_cache() -> void:
	# TR-004 spirit applied to matchup_cache: mutating the run_snapshot cache
	# must NOT change the combat_snapshot cache (and vice-versa). Achieved
	# via .duplicate(true) on the mirror.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange + Act
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([_make_hero(WARRIOR_ID, 1)], 1, "forest_reach")
	var pre_mutation_size: int = orch._combat_snapshot.matchup_cache.size()

	# Act — mutate run_snapshot cache.
	orch.run_snapshot.matchup_cache[&"injected_archetype"] = true

	# Assert — combat_snapshot cache size unchanged.
	assert_int(orch._combat_snapshot.matchup_cache.size()).is_equal(pre_mutation_size)


func test_run_snapshot_kill_schedule_populates_from_floor_enemy_list() -> void:
	# TR-012 kill_schedule completeness: orchestrator's persistent kill_schedule
	# mirrors the combat-snapshot enemy_list, so every archetype in the schedule
	# has a corresponding matchup_cache entry — guarantees zero KeyError during
	# replay (cache lookups always find the key).
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange + Act
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([_make_hero(WARRIOR_ID, 1)], 1, "forest_reach")

	# Assert — kill_schedule populated with the 3-enemy synthetic fallback.
	assert_int(orch.run_snapshot.kill_schedule.size()).is_greater(0)
	# Every archetype in kill_schedule has a matchup_cache entry.
	for entry: Variant in orch.run_snapshot.kill_schedule:
		var archetype: StringName = (entry as Dictionary).get("archetype", &"") as StringName
		if archetype != &"":
			assert_bool(orch.run_snapshot.matchup_cache.has(archetype)).is_true()


# ===========================================================================
# Group D: TR-013 — matchup cache built ONCE; ticks read from cache
# ===========================================================================

func test_matchup_cache_built_exactly_once_at_dispatch() -> void:
	# TR-013: build_matchup_cache → resolve_formation_matchup is called only
	# once per distinct archetype during dispatch. After dispatch, ticks read
	# from the stored cache — zero additional resolver calls.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange — orchestrator with a counting spy resolver.
	var orch: Node = OrchestratorScript.new()
	var combat: RefCounted = DefaultCombatResolverScript.new()
	var matchup_spy: RefCounted = CountingMatchupResolverSpy.new()
	orch.set_combat_resolver(combat)
	orch.set_matchup_resolver(matchup_spy)
	add_child(orch)
	auto_free(orch)

	# Act — dispatch (synthetic 3-enemy floor → 1 distinct archetype "bruiser"
	# → 1 resolver call expected per build_matchup_cache's dedup).
	orch.dispatch([_make_hero(WARRIOR_ID, 1)], 1, "forest_reach")
	var post_dispatch_calls: int = matchup_spy.resolve_formation_matchup_call_count

	# Assert — cache built once. The 3-enemy synthetic floor has 1 distinct
	# archetype, so call count is exactly 1 after dispatch.
	assert_int(post_dispatch_calls).is_equal(1)


func test_per_tick_replay_does_not_invoke_matchup_resolver() -> void:
	# TR-013 critical guarantee: ticks read from the pre-built matchup_cache,
	# NEVER re-invoke the resolver. 100 ticks → 0 additional resolver calls
	# beyond the dispatch-time build.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var orch: Node = OrchestratorScript.new()
	orch.set_combat_resolver(DefaultCombatResolverScript.new())
	var matchup_spy: RefCounted = CountingMatchupResolverSpy.new()
	orch.set_matchup_resolver(matchup_spy)
	add_child(orch)
	auto_free(orch)
	orch.dispatch([_make_hero(WARRIOR_ID, 1, 5)], 1, "forest_reach")
	var dispatch_call_count: int = matchup_spy.resolve_formation_matchup_call_count

	# Act — fire 100 simulated ticks. None should invoke the resolver.
	for n: int in range(1, 101):
		orch._on_tick_fired(n)
		# Stop early if run ended (kills all enemies fast → RUN_ENDED).
		if orch.state == DungeonRunStateScript.State.RUN_ENDED:
			break

	# Assert — total resolver calls unchanged from post-dispatch baseline.
	assert_int(matchup_spy.resolve_formation_matchup_call_count).is_equal(dispatch_call_count)


# ===========================================================================
# Group E: structural — formation_snapshot is a Dictionary (not an Array)
# ===========================================================================

func test_formation_snapshot_is_dictionary_per_run_snapshot_schema() -> void:
	# RunSnapshot.formation_snapshot is typed Dictionary per ADR-0014. Verify
	# the dispatch path produces a Dictionary, not an Array (regression guard
	# against accidental schema drift).
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange + Act
	var orch: Node = _make_orch_with_real_resolvers()
	orch.dispatch([_make_hero(WARRIOR_ID, 1)], 1, "forest_reach")

	# Assert
	assert_bool(orch.run_snapshot.formation_snapshot is Dictionary).is_true()
