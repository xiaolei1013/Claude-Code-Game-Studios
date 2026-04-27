# Tests for Sprint 8 matchup-resolver Story 005 (S8-N2 carryover from S7-N2):
#   - TR-021 determinism: 1000-call same-input produces field-equal results
#   - TR-022 offline replay uses frozen matchup_cache lookup, never resolves
#   - TR-023 RunSnapshot.formation_snapshot contains class_id strings, NOT
#     HeroInstance references (source-grep canary)
#   - TR-024 zero-call invariant: 100-kill offline replay → 0 resolver calls
#   - TR-025 frozen floor_archetypes: snapshot's kill_schedule survives
#     post-dispatch mutation of the live Floor resource
#   - TR-029 empty-formation backstop guard
#
# Covers: TR-matchup-resolver-021/022/023/024/025/029.
#
# Implementation note: the actual resolver determinism + snapshot-build
# behaviors were implemented in Stories 002-003 (S7-M3) + Sprint 8 S8-S2
# (orchestrator snapshot deep-copy + matchup cache). This story is the
# verification layer: tests that confirm those behaviors hold under the
# offline-replay invariant contract.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const MatchupResultScript = preload("res://src/core/matchup_resolver/matchup_result.gd")
const CombatTickEventsScript = preload("res://src/core/combat/combat_tick_events.gd")
const KillEventScript = preload("res://src/core/combat/kill_event.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const MatchResultEq = preload("res://tests/fixtures/match_result_eq.gd")


# Counting spy MatchupResolver — minimal version reused from S8-N6 pattern.
class CountingMatchupResolverSpy extends RefCounted:
	const _Default := preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
	var _real: RefCounted = _Default.new()
	var resolve_formation_matchup_call_count: int = 0
	var resolve_floor_matchup_call_count: int = 0

	func resolve_formation_matchup(formation: Array, archetype: String) -> RefCounted:
		resolve_formation_matchup_call_count += 1
		return _real.resolve_formation_matchup(formation, archetype)

	func resolve_floor_matchup(formation: Array, archetypes: Array[String]) -> RefCounted:
		resolve_floor_matchup_call_count += 1
		return _real.resolve_floor_matchup(formation, archetypes)


func _make_hero(class_id: String, instance_id: int, level: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = level
	return h


func _data_registry_can_resolve_classes() -> bool:
	return DataRegistry.resolve("classes", "warrior") != null


# ===========================================================================
# Group A: TR-021 — determinism over 1000 iterations
# ===========================================================================

func test_resolve_formation_matchup_1000_calls_produce_field_equal_results() -> void:
	# Pure-function determinism: identical (formation, archetype) inputs
	# produce field-equal MatchupResult on every call. Uses S8-N3's
	# MatchResultEq helper for structural equality (RefCounted `==` is
	# reference-equality and would falsely report inequality here).
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped: DataRegistry cannot resolve classes")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero("warrior", 1),
		_make_hero("warrior", 2),
		_make_hero("mage", 3),
	]

	# Act — first call as canonical reference; 999 subsequent calls compared.
	var canonical: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
	for _i: int in range(999):
		var result: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
		assert_bool(MatchResultEq.match_result_equals(canonical, result)).is_true()


func test_resolve_floor_matchup_determinism_across_1000_calls() -> void:
	# Same determinism contract for the multi-archetype path.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero("warrior", 1),
		_make_hero("mage", 2),
		_make_hero("rogue", 3),
	]
	var floor_archetypes: Array[String] = ["bruiser", "caster", "armored"]

	# Act + Assert
	var canonical: MatchupResult = resolver.resolve_floor_matchup(formation, floor_archetypes)
	for _i: int in range(999):
		var result: MatchupResult = resolver.resolve_floor_matchup(formation, floor_archetypes)
		assert_bool(MatchResultEq.match_result_equals(canonical, result)).is_true()


# ===========================================================================
# Group B: TR-024 — zero-call invariant during offline replay
# ===========================================================================

func test_per_tick_replay_makes_zero_matchup_resolver_calls_after_dispatch() -> void:
	# After dispatch builds the matchup_cache, 100 simulated ticks must NOT
	# invoke the matchup resolver — the cache is consulted via direct lookup.
	# CountingMatchupResolverSpy proves this.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var orch: Node = OrchestratorScript.new()
	var spy: CountingMatchupResolverSpy = CountingMatchupResolverSpy.new()
	orch.set_combat_resolver(DefaultCombatResolverScript.new())
	orch.set_matchup_resolver(spy)
	add_child(orch)
	auto_free(orch)
	orch.dispatch([_make_hero("warrior", 1, 5)], 1, "forest_reach")
	var post_dispatch_count: int = spy.resolve_formation_matchup_call_count

	# Act — fire 100 ticks (or until run ends).
	for n: int in range(1, 101):
		if orch.state == DungeonRunStateScript.State.ACTIVE_FOREGROUND:
			orch._on_tick_fired(n)
		else:
			break

	# Assert — call count unchanged from post-dispatch baseline.
	assert_int(spy.resolve_formation_matchup_call_count).is_equal(post_dispatch_count)


# ===========================================================================
# Group C: TR-022 — replay uses snapshot.matchup_cache.get(archetype, false)
# ===========================================================================

func test_offline_replay_path_consumes_matchup_cache_via_dict_get() -> void:
	# Source-grep canary on default_combat_resolver.gd — the per-enemy
	# matchup-advantage lookup should use `matchup_cache.get(archetype, false)`
	# pattern (frozen lookup), NOT `matchup_resolver.resolve_*` (which would
	# trigger the spy).
	var path: String = "res://src/core/combat/default_combat_resolver.gd"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(f).is_not_null()
	if f == null:
		return
	var src: String = f.get_as_text()
	f.close()
	# Confirms the cache-lookup pattern is present.
	assert_bool(src.contains("matchup_cache.get(archetype")).is_true()


# ===========================================================================
# Group D: TR-023 — RunSnapshot stores class_ids/dicts, NOT HeroInstance refs
# ===========================================================================

const _ORCHESTRATOR_SOURCE: String = "res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd"


func _read_source(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var content: String = f.get_as_text()
	f.close()
	return content


func test_orchestrator_snapshot_build_does_not_store_hero_instance_refs() -> void:
	# Inspect _build_run_snapshot — formation_snapshot stores class_ids +
	# per-hero dicts (deep-copied per S8-S2 / TR-004), NOT HeroInstance refs.
	# Source-grep checks the snapshot Dictionary construction does NOT
	# directly assign a HeroInstance instance to the dict.
	var src: String = _read_source(_ORCHESTRATOR_SOURCE)
	# The build path constructs hero_dict with primitive fields (instance_id,
	# class_id, current_level, etc.) — NOT a `hero_dict["instance"] = hero`
	# assignment of the HeroInstance ref.
	assert_bool(src.contains("\"instance\": hero")).is_false()
	# Defensive: also check that formation_snapshot.heroes Array gets
	# Dictionaries appended, not raw HeroInstance refs.
	assert_bool(src.contains("heroes.append(hero)")).is_false()


func test_run_snapshot_formation_snapshot_field_typed_as_dictionary() -> void:
	# Schema check: formation_snapshot field type in run_snapshot.gd is
	# Dictionary, not Array[HeroInstance] or anything that could carry refs.
	var src: String = _read_source("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
	# The field declaration line — check it's typed Dictionary.
	assert_bool(src.contains("var formation_snapshot: Dictionary")).is_true()


# ===========================================================================
# Group E: TR-025 — frozen floor_archetypes (post-dispatch mutation safety)
# ===========================================================================

func test_snapshot_kill_schedule_survives_post_dispatch_combat_snapshot_mutation() -> void:
	# Post-dispatch mutation of the LIVE CombatRunSnapshot.enemy_list must
	# NOT propagate into the orchestrator's RunSnapshot.kill_schedule. S8-S2
	# wired `.duplicate(true)` on the mirror — this test pins that contract.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	var orch: Node = OrchestratorScript.new()
	orch.set_combat_resolver(DefaultCombatResolverScript.new())
	orch.set_matchup_resolver(DefaultMatchupResolverScript.new())
	add_child(orch)
	auto_free(orch)
	orch.dispatch([_make_hero("warrior", 1)], 1, "forest_reach")
	var pre_size: int = orch.run_snapshot.kill_schedule.size()

	# Act — mutate the LIVE _combat_snapshot.enemy_list (clear it).
	orch._combat_snapshot.enemy_list.clear()

	# Assert — RunSnapshot's kill_schedule was deep-copied; mutation didn't propagate.
	assert_int(orch.run_snapshot.kill_schedule.size()).is_equal(pre_size)


func test_snapshot_matchup_cache_survives_post_dispatch_mutation() -> void:
	# Same contract for matchup_cache — post-dispatch mutation of
	# CombatRunSnapshot.matchup_cache must NOT propagate to RunSnapshot.matchup_cache
	# (verified by S8-S2; this test re-pins the contract from the offline-replay
	# invariant POV).
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	var orch: Node = OrchestratorScript.new()
	orch.set_combat_resolver(DefaultCombatResolverScript.new())
	orch.set_matchup_resolver(DefaultMatchupResolverScript.new())
	add_child(orch)
	auto_free(orch)
	orch.dispatch([_make_hero("warrior", 1)], 1, "forest_reach")
	var pre_keys: int = orch.run_snapshot.matchup_cache.size()

	# Act — mutate the LIVE _combat_snapshot.matchup_cache.
	orch._combat_snapshot.matchup_cache.clear()

	# Assert — orchestrator-side cache survived.
	assert_int(orch.run_snapshot.matchup_cache.size()).is_equal(pre_keys)


# ===========================================================================
# Group F: TR-029 — empty-formation backstop guard
# ===========================================================================

func test_resolve_formation_matchup_empty_formation_returns_default_result() -> void:
	# TR-029: empty-formation guard is a backstop. Formation Assignment
	# screen prevents the case earlier, but the resolver MUST handle it
	# cleanly without crash, returning a default-constructed MatchupResult.
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()

	# Act
	var result: MatchupResult = resolver.resolve_formation_matchup([], "bruiser")

	# Assert — default values: not advantaged, empty matched_archetypes.
	assert_bool(result.is_advantaged).is_false()
	assert_int(result.matched_archetypes.size()).is_equal(0)


func test_orchestrator_dispatch_with_empty_formation_does_not_crash() -> void:
	# TR-029: orchestrator's dispatch() with empty formation triggers
	# validation_failed("empty_formation", {}) and transitions to RUN_ENDED
	# WITHOUT calling the matchup resolver.
	var orch: Node = OrchestratorScript.new()
	var spy: CountingMatchupResolverSpy = CountingMatchupResolverSpy.new()
	orch.set_combat_resolver(DefaultCombatResolverScript.new())
	orch.set_matchup_resolver(spy)
	add_child(orch)
	auto_free(orch)

	# Act
	orch.dispatch([], 1, "forest_reach")

	# Assert — resolver not invoked; state is RUN_ENDED.
	assert_int(spy.resolve_formation_matchup_call_count).is_equal(0)
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)
