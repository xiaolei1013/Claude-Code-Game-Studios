# Tests for Sprint 7 matchup-resolver Story 002:
#   - DefaultMatchupResolver extends MatchupResolver
#   - resolve_formation_matchup with strict-majority threshold (TR-011)
#   - _is_class_counter case-sensitive string equality (TR-010 / TR-020)
#   - Empty formation guard, null class_data silent skip, dedup + sort
#
# Covers: TR-matchup-resolver-003 (DefaultMatchupResolver subclass),
#         TR-matchup-resolver-008/010-014/016/017/020 (resolve_formation_matchup
#         contract).
#
# Test data: warrior counters bruiser, mage counters caster, rogue counters
# armored (per assets/data/classes/*.tres + GDD §G).
extends GdUnitTestSuite

const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const MatchupResolverScript = preload("res://src/core/matchup_resolver/matchup_resolver.gd")
const MatchupResultScript = preload("res://src/core/matchup_resolver/matchup_result.gd")

const WARRIOR_ID := "warrior"
const MAGE_ID := "mage"
const ROGUE_ID := "rogue"


# Build a synthetic hero entry — the resolver only reads `class_id`, so a
# minimal Object-with-class_id duck-types correctly. Using HeroInstance from
# Sprint 6 for realism.
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


func _make_hero(class_id: String, instance_id: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	return h


# Confirm DataRegistry can resolve our test classes; if not, skip per the
# Sprint 6 FOLLOWUP-002 pattern (now resolved by S7-M1 but defensive in case
# the test env regresses).
func _data_registry_can_resolve(class_id: String) -> bool:
	return DataRegistry.resolve("classes", class_id) != null


# ===========================================================================
# Group A: TR-003 — DefaultMatchupResolver extends MatchupResolver
# ===========================================================================

func test_default_matchup_resolver_extends_matchup_resolver() -> void:
	var inst: RefCounted = DefaultMatchupResolverScript.new()
	var as_object: Object = inst
	assert_bool(as_object is MatchupResolver).is_true()
	assert_bool(as_object is RefCounted).is_true()


func test_default_matchup_resolver_can_be_instantiated_via_new() -> void:
	var inst: RefCounted = DefaultMatchupResolverScript.new()
	assert_object(inst).is_not_null()


# ===========================================================================
# Group B: strict-majority threshold (TR-011 / TR-012)
# ===========================================================================

func test_two_of_three_warriors_vs_bruiser_advantaged() -> void:
	# 2/3 counters → threshold (3/2 = 1) crossed → advantaged.
	if not _data_registry_can_resolve(WARRIOR_ID) or not _data_registry_can_resolve(MAGE_ID):
		push_warning("Skipped: DataRegistry classes not available")
		return
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(MAGE_ID, 3)]
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
	assert_bool(result.is_advantaged).is_true()
	assert_int(result.matched_archetypes.size()).is_equal(1)
	assert_str(result.matched_archetypes[0]).is_equal("bruiser")


func test_one_of_three_warriors_vs_bruiser_not_advantaged() -> void:
	# 1/3 counters → threshold not crossed → NOT advantaged.
	if not _data_registry_can_resolve(WARRIOR_ID) or not _data_registry_can_resolve(MAGE_ID) or not _data_registry_can_resolve(ROGUE_ID):
		push_warning("Skipped: DataRegistry classes not available")
		return
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1), _make_hero(MAGE_ID, 2), _make_hero(ROGUE_ID, 3)]
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
	assert_bool(result.is_advantaged).is_false()


func test_three_of_three_warriors_vs_bruiser_advantaged_no_stacking() -> void:
	# 3/3 counters → still single is_advantaged=true (no stacking beyond threshold).
	if not _data_registry_can_resolve(WARRIOR_ID):
		push_warning("Skipped: DataRegistry not resolving warrior")
		return
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(WARRIOR_ID, 3)]
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
	assert_bool(result.is_advantaged).is_true()
	# matched_archetypes deduplicated — only one entry even though 3 heroes matched.
	assert_int(result.matched_archetypes.size()).is_equal(1)


func test_zero_counters_not_advantaged() -> void:
	# 3 heroes, none counter the enemy → not advantaged.
	if not _data_registry_can_resolve(WARRIOR_ID):
		push_warning("Skipped: DataRegistry not resolving warrior")
		return
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(WARRIOR_ID, 3)]
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, "caster")
	assert_bool(result.is_advantaged).is_false()
	assert_int(result.matched_archetypes.size()).is_equal(0)


# ===========================================================================
# Group C: TR-016 — empty formation guard
# ===========================================================================

func test_empty_formation_returns_false_empty_archetypes() -> void:
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var result: MatchupResult = resolver.resolve_formation_matchup([], "bruiser")
	assert_bool(result.is_advantaged).is_false()
	assert_int(result.matched_archetypes.size()).is_equal(0)


# ===========================================================================
# Group D: TR-017 — null class_data silently excluded
# ===========================================================================

func test_three_unresolvable_class_ids_behaves_as_empty_formation() -> void:
	# All 3 heroes have unresolvable class_ids → all skipped → behaves as empty.
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero("ghost_class_a", 1),
		_make_hero("ghost_class_b", 2),
		_make_hero("ghost_class_c", 3),
	]
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
	assert_bool(result.is_advantaged).is_false()
	assert_int(result.matched_archetypes.size()).is_equal(0)


func test_one_resolvable_warrior_among_two_unresolvable_advantaged() -> void:
	# 1 of 1 eligible (the 2 ghosts are excluded from N) → counter_count > (1/2)=0
	# → 1 > 0 → advantaged. This is the TR-017 N-shrinking semantics.
	if not _data_registry_can_resolve(WARRIOR_ID):
		push_warning("Skipped: DataRegistry not resolving warrior")
		return
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero("ghost_a", 1),
		_make_hero(WARRIOR_ID, 2),
		_make_hero("ghost_b", 3),
	]
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
	assert_bool(result.is_advantaged).is_true()


# ===========================================================================
# Group E: TR-018 — empty enemy_archetype guard
# ===========================================================================

func test_empty_string_enemy_archetype_returns_false() -> void:
	# Per TR-018: empty enemy_archetype calls push_error and returns {false, []}.
	# We don't assert on push_error here (godot doesn't expose intercept easily);
	# we assert the contract — false + empty result + no crash.
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1)]
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, "")
	assert_bool(result.is_advantaged).is_false()
	assert_int(result.matched_archetypes.size()).is_equal(0)


# ===========================================================================
# Group F: TR-020 — case-sensitive string comparison
# ===========================================================================

func test_uppercase_enemy_archetype_does_not_match() -> void:
	# `"Bruiser"` (capital B) does NOT match warrior's `"bruiser"` (lowercase).
	if not _data_registry_can_resolve(WARRIOR_ID):
		push_warning("Skipped: DataRegistry not resolving warrior")
		return
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(WARRIOR_ID, 3)]
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, "Bruiser")
	assert_bool(result.is_advantaged).is_false()


# ===========================================================================
# Group G: TR-013 — matched_archetypes deduplicated + sorted
# ===========================================================================

func test_matched_archetypes_single_enemy_dedup() -> void:
	# Single-enemy resolution always produces 0 or 1 matched archetypes.
	# Dedup is observable when N counters > 1 — only 1 entry, not N.
	if not _data_registry_can_resolve(WARRIOR_ID):
		push_warning("Skipped")
		return
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(WARRIOR_ID, 3)]
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
	assert_int(result.matched_archetypes.size()).is_equal(1)


# ===========================================================================
# Group H: TR-021 — determinism (same inputs → field-equal outputs)
# ===========================================================================

func test_repeated_calls_with_same_inputs_produce_field_equal_results() -> void:
	if not _data_registry_can_resolve(WARRIOR_ID) or not _data_registry_can_resolve(MAGE_ID):
		push_warning("Skipped")
		return
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(MAGE_ID, 3)]
	var r1: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
	var r2: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
	assert_bool(r1.is_advantaged).is_equal(r2.is_advantaged)
	assert_int(r1.matched_archetypes.size()).is_equal(r2.matched_archetypes.size())
	if r1.matched_archetypes.size() > 0:
		assert_str(r1.matched_archetypes[0]).is_equal(r2.matched_archetypes[0])


# ===========================================================================
# Group I: TR-005 — formation parameter unmutated by resolution
# ===========================================================================

func test_formation_array_unmutated_after_resolve() -> void:
	# The resolver MUST NOT mutate the input formation array. Verify size and
	# per-element class_id equality post-resolve.
	if not _data_registry_can_resolve(WARRIOR_ID):
		push_warning("Skipped")
		return
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var h1: RefCounted = _make_hero(WARRIOR_ID, 1)
	var h2: RefCounted = _make_hero(WARRIOR_ID, 2)
	var h3: RefCounted = _make_hero(MAGE_ID, 3)
	var formation: Array = [h1, h2, h3]
	resolver.resolve_formation_matchup(formation, "bruiser")
	assert_int(formation.size()).is_equal(3)
	assert_object(formation[0]).is_same(h1)
	assert_object(formation[1]).is_same(h2)
	assert_object(formation[2]).is_same(h3)
	assert_str(h1.class_id).is_equal(WARRIOR_ID)


# ===========================================================================
# Group J: is_stub() preserved for orchestrator autoload tests
# ===========================================================================

func test_is_stub_marker_contains_default_matchup_resolver_substring() -> void:
	# orchestrator's autoload_skeleton_and_di_test depends on this substring.
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	assert_str(resolver.is_stub()).contains("DefaultMatchupResolver")
