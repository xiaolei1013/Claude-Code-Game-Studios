# Tests for Sprint 7 combat-resolution Story 008:
#   - build_matchup_cache(formation, floor_archetypes, matchup_resolver)
#   - Per-archetype dedup (≤5 calls per MVP floor — TR-012)
#   - Stateless DI: matchup_resolver passed as method parameter
#   - Resolver source files have zero `signal ` declarations (TR-030)
#
# Covers: TR-combat-004 (DefaultCombatResolver subclass; spy DI),
#         TR-combat-012 (resolve_formation_matchup called once per distinct
#                        enemy_list archetype; ≤5 calls per MVP floor),
#         TR-combat-030 (Combat emits no signals; orchestrator owns emission).
extends GdUnitTestSuite

const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

const WARRIOR_ID := "warrior"
const MAGE_ID := "mage"


# Spy MatchupResolver — counts calls per (formation, archetype) tuple.
class SpyMatchupResolver extends MatchupResolver:
	var call_count: int = 0
	var calls_by_archetype: Dictionary = {}
	var canned_results: Dictionary = {}  # archetype: String → is_advantaged: bool

	func resolve_formation_matchup(formation: Array, archetype: String) -> MatchupResult:
		call_count += 1
		var key: StringName = StringName(archetype)
		calls_by_archetype[key] = int(calls_by_archetype.get(key, 0)) + 1
		var result: MatchupResult = MatchupResult.new()
		result.is_advantaged = bool(canned_results.get(archetype, false))
		if result.is_advantaged:
			result.matched_archetypes = [archetype]
		return result


func _make_hero(class_id: String, instance_id: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = 1
	return h


# ===========================================================================
# Group A: TR-012 — per-archetype dedup
# ===========================================================================

func test_build_matchup_cache_calls_resolver_once_per_distinct_archetype() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var spy: SpyMatchupResolver = SpyMatchupResolver.new()
	# Floor with 5 distinct archetypes (the MVP cap per TR-012).
	var floor_archetypes: Array = ["bruiser", "caster", "armored", "swarm", "ranged"]
	var formation: Array = [_make_hero(WARRIOR_ID, 1)]
	var cache: Dictionary = resolver.build_matchup_cache(formation, floor_archetypes, spy)
	# 5 distinct archetypes → exactly 5 resolver calls.
	assert_int(spy.call_count).is_equal(5)
	# Cache has 5 entries.
	assert_int(cache.size()).is_equal(5)


func test_build_matchup_cache_dedupes_duplicate_archetype_entries() -> void:
	# Floor with duplicates → dedup before calling resolver.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var spy: SpyMatchupResolver = SpyMatchupResolver.new()
	var floor_archetypes: Array = ["bruiser", "bruiser", "caster", "bruiser"]
	var formation: Array = [_make_hero(WARRIOR_ID, 1)]
	resolver.build_matchup_cache(formation, floor_archetypes, spy)
	# Only 2 distinct → 2 calls, NOT 4.
	assert_int(spy.call_count).is_equal(2)
	# Per-archetype call count: bruiser called once, caster called once.
	assert_int(int(spy.calls_by_archetype.get(&"bruiser", 0))).is_equal(1)
	assert_int(int(spy.calls_by_archetype.get(&"caster", 0))).is_equal(1)


func test_build_matchup_cache_empty_floor_archetypes_zero_calls() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var spy: SpyMatchupResolver = SpyMatchupResolver.new()
	resolver.build_matchup_cache([_make_hero(WARRIOR_ID, 1)], [], spy)
	assert_int(spy.call_count).is_equal(0)


func test_build_matchup_cache_skips_empty_archetype_strings() -> void:
	# Defensive: empty archetype entries are silently dropped (don't reach resolver).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var spy: SpyMatchupResolver = SpyMatchupResolver.new()
	var floor_archetypes: Array = ["", "bruiser", ""]
	resolver.build_matchup_cache([_make_hero(WARRIOR_ID, 1)], floor_archetypes, spy)
	# Only "bruiser" reaches resolver.
	assert_int(spy.call_count).is_equal(1)


# ===========================================================================
# Group B: cache contents — archetype → is_advantaged mapping
# ===========================================================================

func test_build_matchup_cache_returns_advantaged_true_for_matching_archetype() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var spy: SpyMatchupResolver = SpyMatchupResolver.new()
	spy.canned_results = {"bruiser": true, "caster": false}
	var formation: Array = [_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(MAGE_ID, 3)]
	var cache: Dictionary = resolver.build_matchup_cache(formation, ["bruiser", "caster"], spy)
	assert_bool(bool(cache.get(&"bruiser", false))).is_true()
	assert_bool(bool(cache.get(&"caster", false))).is_false()


func test_build_matchup_cache_returns_string_name_keys() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var spy: SpyMatchupResolver = SpyMatchupResolver.new()
	var cache: Dictionary = resolver.build_matchup_cache(
		[_make_hero(WARRIOR_ID, 1)], ["bruiser"], spy
	)
	# Cache key should be StringName, not String — for snapshot.matchup_cache
	# typed-Dictionary[StringName, bool] consistency.
	assert_bool(cache.has(&"bruiser")).is_true()


# ===========================================================================
# Group C: null / malformed resolver safety
# ===========================================================================

func test_build_matchup_cache_null_resolver_returns_empty_cache() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var cache: Dictionary = resolver.build_matchup_cache(
		[_make_hero(WARRIOR_ID, 1)], ["bruiser"], null
	)
	assert_int(cache.size()).is_equal(0)


func test_build_matchup_cache_resolver_lacking_method_returns_empty_cache() -> void:
	# Inject a bare RefCounted that doesn't implement resolve_formation_matchup.
	# Should push_error + return empty.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var bad_spy: RefCounted = RefCounted.new()
	var cache: Dictionary = resolver.build_matchup_cache(
		[_make_hero(WARRIOR_ID, 1)], ["bruiser"], bad_spy
	)
	assert_int(cache.size()).is_equal(0)


# ===========================================================================
# Group D: integration with DefaultMatchupResolver (production resolver)
# ===========================================================================

func test_build_matchup_cache_integrates_with_default_matchup_resolver() -> void:
	# Production wiring: DefaultMatchupResolver injected, real DataRegistry
	# class lookups. 2 warriors + 1 mage vs bruiser → 2/3 majority → advantaged.
	if DataRegistry.resolve("classes", WARRIOR_ID) == null:
		push_warning("Skipped: DataRegistry not resolving warrior")
		return
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var matchup: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(MAGE_ID, 3)]
	var cache: Dictionary = resolver.build_matchup_cache(formation, ["bruiser", "caster"], matchup)
	assert_bool(bool(cache.get(&"bruiser", false))).is_true()
	# 1 mage out of 3 → caster NOT majority advantaged.
	assert_bool(bool(cache.get(&"caster", false))).is_false()


# ===========================================================================
# Group E: TR-030 — Combat resolver source has zero signal declarations
# ===========================================================================

func test_combat_resolver_source_has_zero_signal_declarations() -> void:
	# TR-030: Combat emits no signals; Orchestrator owns all signal emission.
	var sources: Array[String] = [
		"res://src/core/combat/combat_resolver.gd",
		"res://src/core/combat/default_combat_resolver.gd",
	]
	for path: String in sources:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_object(file).override_failure_message("missing: %s" % path).is_not_null()
		var content: String = file.get_as_text()
		file.close()
		var lines: PackedStringArray = content.split("\n")
		for line: String in lines:
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("#") or trimmed.begins_with("##"):
				continue
			assert_bool(trimmed.begins_with("signal ")).override_failure_message(
				"%s contains signal declaration: '%s'" % [path, trimmed]
			).is_false()
