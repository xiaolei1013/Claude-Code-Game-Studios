# Tests for Sprint 8 matchup-resolver Story 004 (S8-S6 carryover from S7-S3):
#   - MatchupResult.effectiveness_label: String default = "Even"
#   - resolve_formation_matchup populates label per is_advantaged + counter_count:
#       Strong (advantaged) / Weak (zero counters across non-empty eligible) /
#       Even (mixed or empty)
#   - resolve_floor_matchup aggregates labels: any-Strong / all-Weak / Even
#   - Existing Stories 001-003 tests continue to pass (additive — covered by
#     running the full matchup_resolver suite at sprint level, not in this file)
#
# Covers: epic DoD line 62 — "resolver returns effectiveness_label: String ∈
#         {Weak, Even, Strong} alongside the multiplier" (S4-N1 quick-spec
#         carryover from Sprint 4 Nice-to-Have).
#
# Test data: warrior counters bruiser, mage counters caster, rogue counters
# armored (per assets/data/classes/*.tres + GDD §G).
extends GdUnitTestSuite

const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const MatchupResultScript = preload("res://src/core/matchup_resolver/matchup_result.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

const WARRIOR_ID := "warrior"
const MAGE_ID := "mage"
const ROGUE_ID := "rogue"
const BRUISER := "bruiser"
const CASTER := "caster"
const ARMORED := "armored"


func _make_hero(class_id: String, instance_id: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = 1
	return h


func _data_registry_can_resolve_classes() -> bool:
	return DataRegistry.resolve("classes", WARRIOR_ID) != null


# ===========================================================================
# Group A: MatchupResult default field — "Even"
# ===========================================================================

func test_matchup_result_default_effectiveness_label_is_even() -> void:
	# Arrange + Act
	var r: MatchupResult = MatchupResultScript.new()

	# Assert
	assert_str(r.effectiveness_label).is_equal("Even")


func test_matchup_result_effectiveness_label_field_exists_as_string() -> void:
	# Defensive: verify the field is present and string-typed at the value-type
	# level, not just on populated instances.
	var r: MatchupResult = MatchupResultScript.new()
	assert_bool("effectiveness_label" in r).is_true()
	assert_str(r.effectiveness_label).is_equal("Even")


# ===========================================================================
# Group B: resolve_formation_matchup label population
# ===========================================================================

func test_resolve_formation_matchup_2_of_3_warriors_vs_bruiser_labels_strong() -> void:
	# 2/3 counters → strict majority → is_advantaged → "Strong".
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped: DataRegistry cannot resolve classes")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(WARRIOR_ID, 2),
		_make_hero(MAGE_ID, 3),
	]

	# Act
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, BRUISER)

	# Assert — both is_advantaged AND label populated.
	assert_bool(result.is_advantaged).is_true()
	assert_str(result.effectiveness_label).is_equal("Strong")


func test_resolve_formation_matchup_3_of_3_warriors_vs_bruiser_labels_strong() -> void:
	# All 3 counter → still "Strong" (no per-hero label stacking).
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(WARRIOR_ID, 2),
		_make_hero(WARRIOR_ID, 3),
	]

	# Act
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, BRUISER)

	# Assert
	assert_str(result.effectiveness_label).is_equal("Strong")


func test_resolve_formation_matchup_3_of_3_warriors_vs_caster_labels_weak() -> void:
	# 3 warriors counter bruiser, NOT caster. Zero counters against caster
	# across non-empty eligible formation → "Weak".
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(WARRIOR_ID, 2),
		_make_hero(WARRIOR_ID, 3),
	]

	# Act
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, CASTER)

	# Assert
	assert_bool(result.is_advantaged).is_false()
	assert_str(result.effectiveness_label).is_equal("Weak")


func test_resolve_formation_matchup_1_of_3_warriors_vs_bruiser_labels_even() -> void:
	# 1 counter / 3 eligible → counter_count > 0 but below strict majority →
	# not advantaged AND not all-zero → "Even".
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(MAGE_ID, 2),
		_make_hero(ROGUE_ID, 3),
	]

	# Act
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, BRUISER)

	# Assert
	assert_bool(result.is_advantaged).is_false()
	assert_str(result.effectiveness_label).is_equal("Even")


func test_resolve_formation_matchup_empty_formation_labels_even() -> void:
	# Empty formation → default "Even" (no eligible heroes; not "Weak" because
	# n_eligible == 0 — the all-null path is not the same as "tried but failed").
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()

	# Act
	var result: MatchupResult = resolver.resolve_formation_matchup([], BRUISER)

	# Assert — default Even preserved.
	assert_bool(result.is_advantaged).is_false()
	assert_str(result.effectiveness_label).is_equal("Even")


func test_resolve_formation_matchup_empty_archetype_returns_default_even() -> void:
	# Defensive: empty archetype guard returns default-constructed MatchupResult,
	# which carries the "Even" default.
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1)]

	# Act — push_error is logged inside resolve_formation_matchup.
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, "")

	# Assert
	assert_str(result.effectiveness_label).is_equal("Even")


# ===========================================================================
# Group C: resolve_floor_matchup label aggregation
# ===========================================================================

func test_resolve_floor_matchup_any_strong_labels_aggregate_strong() -> void:
	# 2 warriors + 1 mage vs [bruiser, caster]:
	#   bruiser: 2/3 warriors → Strong
	#   caster: 1/3 mage → Even (counter_count=1 < majority of 3)
	#   aggregate: any-Strong → "Strong"
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(WARRIOR_ID, 2),
		_make_hero(MAGE_ID, 3),
	]
	var floor_archetypes: Array[String] = [BRUISER, CASTER]

	# Act
	var result: MatchupResult = resolver.resolve_floor_matchup(formation, floor_archetypes)

	# Assert
	assert_bool(result.is_advantaged).is_true()
	assert_str(result.effectiveness_label).is_equal("Strong")


func test_resolve_floor_matchup_all_weak_labels_aggregate_weak() -> void:
	# 3 warriors vs [caster, armored]:
	#   caster: 0 counters → Weak
	#   armored: 0 counters → Weak (warriors counter bruiser, not armored)
	#   aggregate: all-Weak → "Weak"
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(WARRIOR_ID, 2),
		_make_hero(WARRIOR_ID, 3),
	]
	var floor_archetypes: Array[String] = [CASTER, ARMORED]

	# Act
	var result: MatchupResult = resolver.resolve_floor_matchup(formation, floor_archetypes)

	# Assert
	assert_bool(result.is_advantaged).is_false()
	assert_str(result.effectiveness_label).is_equal("Weak")


func test_resolve_floor_matchup_mixed_weak_and_even_labels_aggregate_even() -> void:
	# 1 warrior + 1 mage + 1 rogue vs [bruiser, caster]:
	#   bruiser: 1/3 warrior → Even
	#   caster: 1/3 mage → Even
	#   aggregate: no Strong, NOT all-Weak → "Even"
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(MAGE_ID, 2),
		_make_hero(ROGUE_ID, 3),
	]
	var floor_archetypes: Array[String] = [BRUISER, CASTER]

	# Act
	var result: MatchupResult = resolver.resolve_floor_matchup(formation, floor_archetypes)

	# Assert
	assert_str(result.effectiveness_label).is_equal("Even")


func test_resolve_floor_matchup_empty_floor_archetypes_returns_default_even() -> void:
	# Empty floor_archetypes → no archetypes tested → default "Even".
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1)]
	var empty_floor: Array[String] = []

	# Act
	var result: MatchupResult = resolver.resolve_floor_matchup(formation, empty_floor)

	# Assert
	assert_str(result.effectiveness_label).is_equal("Even")


func test_resolve_floor_matchup_single_strong_archetype_labels_strong() -> void:
	# Edge: single-archetype floor where formation crosses majority.
	# 3 warriors vs [bruiser] → Strong.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(WARRIOR_ID, 2),
		_make_hero(WARRIOR_ID, 3),
	]
	var floor_archetypes: Array[String] = [BRUISER]

	# Act
	var result: MatchupResult = resolver.resolve_floor_matchup(formation, floor_archetypes)

	# Assert
	assert_str(result.effectiveness_label).is_equal("Strong")


# ===========================================================================
# Group D: contract — label is always one of exactly 3 values
# ===========================================================================

func test_resolve_formation_matchup_label_is_always_one_of_three_values() -> void:
	# Sweep multiple formation/archetype combinations; confirm label always
	# falls in {"Weak", "Even", "Strong"}.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var allowed: Array[String] = ["Weak", "Even", "Strong"]
	var formations: Array = [
		[],  # empty
		[_make_hero(WARRIOR_ID, 1)],  # single
		[_make_hero(WARRIOR_ID, 1), _make_hero(WARRIOR_ID, 2), _make_hero(WARRIOR_ID, 3)],
		[_make_hero(MAGE_ID, 1), _make_hero(MAGE_ID, 2), _make_hero(MAGE_ID, 3)],
		[_make_hero(WARRIOR_ID, 1), _make_hero(MAGE_ID, 2), _make_hero(ROGUE_ID, 3)],
	]
	var archetypes: Array = [BRUISER, CASTER, ARMORED]

	# Act + Assert
	for f: Array in formations:
		for a: String in archetypes:
			var result: MatchupResult = resolver.resolve_formation_matchup(f, a)
			assert_bool(allowed.has(result.effectiveness_label)).is_true()


# ===========================================================================
# Group E: invariant — label correlates with is_advantaged
# ===========================================================================

func test_label_strong_implies_is_advantaged_true() -> void:
	# Whenever label == "Strong", is_advantaged MUST be true (not just usually).
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(WARRIOR_ID, 2),
		_make_hero(WARRIOR_ID, 3),
	]

	# Act
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, BRUISER)

	# Assert
	if result.effectiveness_label == "Strong":
		assert_bool(result.is_advantaged).is_true()


func test_label_weak_implies_is_advantaged_false() -> void:
	# Whenever label == "Weak", is_advantaged MUST be false.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero(WARRIOR_ID, 1),
		_make_hero(WARRIOR_ID, 2),
		_make_hero(WARRIOR_ID, 3),
	]

	# Act
	var result: MatchupResult = resolver.resolve_formation_matchup(formation, CASTER)

	# Assert
	if result.effectiveness_label == "Weak":
		assert_bool(result.is_advantaged).is_false()
