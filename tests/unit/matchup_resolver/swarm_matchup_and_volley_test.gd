# Proves the swarm-enemy fix is live end-to-end: thornling_swarm carries
# archetype "swarm", a 3-Archer formation is matchup-advantaged against it, and
# the Volley synergy pays its +25% gold on a swarm kill (vs no bonus otherwise).
# Before thornling_swarm existed, all three were unreachable.
extends GdUnitTestSuite

const MatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


func test_thornling_swarm_resolves_with_swarm_archetype() -> void:
	var e: Resource = DataRegistry.resolve("enemies", "thornling_swarm") as Resource
	assert_object(e).override_failure_message(
		"thornling_swarm did not resolve from DataRegistry — .tres missing or unimported?"
	).is_not_null()
	assert_str(String(e.get("archetype"))).is_equal("swarm")
	assert_str(String(e.get("biome"))).is_equal("forest_reach")


func test_three_archers_are_matchup_advantaged_versus_swarm() -> void:
	var resolver: RefCounted = MatchupResolverScript.new()
	var formation: Array = []
	for i: int in range(3):
		var h: RefCounted = HeroInstanceScript.new()
		h.instance_id = i + 1
		h.class_id = "archer"
		formation.append(h)
	var result: Variant = resolver.resolve_formation_matchup(formation, "swarm")
	assert_bool(result.is_advantaged).override_failure_message(
		"3 Archers (counter_archetype='swarm') must be advantaged vs a swarm enemy"
	).is_true()


func test_volley_pays_bonus_gold_on_a_swarm_kill() -> void:
	# attribute_kill_gold is a pure compute; use the live orchestrator so BASE_KILL
	# is populated. Volley (+25% vs swarm) must out-earn the same kill on a
	# non-swarm archetype, where the Volley arm resolves to 1.0.
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	assert_object(orch).is_not_null()
	var gold_swarm: int = int(orch.attribute_kill_gold(1, false, false, "volley", "swarm"))
	var gold_other: int = int(orch.attribute_kill_gold(1, false, false, "volley", "caster"))
	assert_int(gold_swarm).override_failure_message(
		"Volley must pay MORE gold on a swarm kill (%d) than a non-swarm kill (%d)"
		% [gold_swarm, gold_other]
	).is_greater(gold_other)
