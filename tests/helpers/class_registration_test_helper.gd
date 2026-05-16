## HeroClass registration test helpers.
##
## Sprint 26 N1 — consolidates the boilerplate that grew across paladin
## (PR #152), archer (PR #154), and berserker (PR #159) registration tests.
## Each test file was 9-11 assertions of the same shape: registry discovery,
## tier check, role distinction, stat-vs-warrior comparisons, counter
## archetype, display-field non-empty. The /simplify+/review pass flagged
## this as Rule-of-Three pending; with the third tier-2 class shipped,
## factoring pays.
##
## ## Usage pattern (canonical)
##
## ```gdscript
## extends GdUnitTestSuite
##
## const Helper = preload("res://tests/helpers/class_registration_test_helper.gd")
##
## func test_paladin_registered_with_expected_shape() -> void:
##     Helper.assert_class_registered(self, "paladin")
##     Helper.assert_class_tier(self, "paladin", 2)
##     Helper.assert_class_role(self, "paladin", "defender")
##     Helper.assert_class_counter_archetype(self, "paladin", "caster")
##     Helper.assert_class_display_name(self, "paladin", "Paladin")
##     Helper.assert_class_flavor_text_non_empty(self, "paladin")
##     # Cross-class stat comparisons:
##     Helper.assert_class_stat_greater(self, "paladin", "warrior", "base_hp")
##     Helper.assert_class_stat_less(self, "paladin", "warrior", "base_attack")
## ```
##
## ## What's NOT in here
##
## Per-class flavor-specific tests stay in the per-class file (e.g., a class
## with a unique synergy interaction or a special stat-cap behavior). The
## helper covers the homogeneous "is this class wired into the registry
## correctly" surface — about 80% of each existing test file.
##
## Pure-utility class. Static methods only. The first parameter is always
## the calling GdUnitTestSuite instance so the helper can invoke
## `suite.assert_*` directly (GdUnit4 assertion functions are instance
## methods on the suite).
class_name ClassRegistrationTestHelper
extends RefCounted


# ---------------------------------------------------------------------------
# Registry discovery
# ---------------------------------------------------------------------------

## Asserts the class is resolvable via DataRegistry AND appears in
## HeroClassDatabase.get_all_ids(). Failure indicates either the .tres
## file isn't in assets/data/classes/ OR DataRegistry didn't scan it
## at boot.
static func assert_class_registered(suite: GdUnitTestSuite, class_id: String) -> void:
	var cls: Variant = DataRegistry.resolve("classes", class_id)
	suite.assert_object(cls).is_not_null().override_failure_message(
		"DataRegistry.resolve('classes', '%s') returned null. Either %s.tres "
		% [class_id, class_id]
		+ "is not in assets/data/classes/ or DataRegistry didn't scan it at boot."
	)
	var all_ids: Array[String] = HeroClassDatabase.get_all_ids()
	suite.assert_array(all_ids).contains([class_id]).override_failure_message(
		"Expected '%s' in HeroClassDatabase.get_all_ids(). Got: %s"
		% [class_id, str(all_ids)]
	)


# ---------------------------------------------------------------------------
# Tier
# ---------------------------------------------------------------------------

## Asserts the class has [param expected_tier] in its tier field. MVP
## tier-1 classes: warrior, mage, rogue. Tier-2+: paladin, archer,
## berserker, future additions.
static func assert_class_tier(
	suite: GdUnitTestSuite,
	class_id: String,
	expected_tier: int
) -> void:
	var cls: HeroClass = HeroClassDatabase.get_by_id(class_id)
	suite.assert_object(cls).is_not_null()
	suite.assert_int(cls.tier).is_equal(expected_tier)


# ---------------------------------------------------------------------------
# Role + counter archetype
# ---------------------------------------------------------------------------

## Asserts the class has the expected role identifier. Roles must be
## distinct strings to keep synergy detection treating each archetype
## as its own slot (a "warrior + warrior + warrior" comp triggers
## Steel Wall; a "paladin + warrior + paladin" comp should not collapse
## to the same synergy by mistake).
static func assert_class_role(
	suite: GdUnitTestSuite,
	class_id: String,
	expected_role: String
) -> void:
	var cls: HeroClass = HeroClassDatabase.get_by_id(class_id)
	suite.assert_object(cls).is_not_null()
	suite.assert_str(cls.role).is_equal(expected_role)


## Asserts the class's counter_archetype identifier. Determines matchup
## interactions: a class with counter_archetype="bruiser" gets a damage
## bonus against bruiser-archetype enemies in matchup-aware combat.
static func assert_class_counter_archetype(
	suite: GdUnitTestSuite,
	class_id: String,
	expected_archetype: String
) -> void:
	var cls: HeroClass = HeroClassDatabase.get_by_id(class_id)
	suite.assert_object(cls).is_not_null()
	suite.assert_str(cls.counter_archetype).is_equal(expected_archetype)


# ---------------------------------------------------------------------------
# Display fields (non-empty + expected value)
# ---------------------------------------------------------------------------

## Asserts the display_name field exactly matches [param expected_name].
## Non-empty subsumed by the equality check (empty string == "Paladin"
## fails immediately).
static func assert_class_display_name(
	suite: GdUnitTestSuite,
	class_id: String,
	expected_name: String
) -> void:
	var cls: HeroClass = HeroClassDatabase.get_by_id(class_id)
	suite.assert_object(cls).is_not_null()
	suite.assert_str(cls.display_name).is_equal(expected_name)


## Asserts the flavor_text field is non-empty. Doesn't enforce specific
## copy — flavor text is writer-locked elsewhere and may be revised
## without breaking this assertion.
static func assert_class_flavor_text_non_empty(
	suite: GdUnitTestSuite,
	class_id: String
) -> void:
	var cls: HeroClass = HeroClassDatabase.get_by_id(class_id)
	suite.assert_object(cls).is_not_null()
	suite.assert_int(cls.flavor_text.length()).is_greater(0)


# ---------------------------------------------------------------------------
# Cross-class stat comparisons
# ---------------------------------------------------------------------------

## Asserts class_a's [param stat_name] is greater than class_b's same
## stat. Used to anchor tier-2 class identity vs an MVP class (e.g.,
## "paladin has more HP than warrior" or "archer is faster than warrior").
##
## [param stat_name] must be a HeroClass property: base_attack, base_hp,
## base_speed, attack_per_level, hp_per_level, speed_per_level,
## tick_output_contribution_l1, tick_output_per_level, or tier.
static func assert_class_stat_greater(
	suite: GdUnitTestSuite,
	class_a: String,
	class_b: String,
	stat_name: String
) -> void:
	var a: HeroClass = HeroClassDatabase.get_by_id(class_a)
	var b: HeroClass = HeroClassDatabase.get_by_id(class_b)
	suite.assert_object(a).is_not_null()
	suite.assert_object(b).is_not_null()
	var stat_a: int = int(a.get(stat_name))
	var stat_b: int = int(b.get(stat_name))
	suite.assert_int(stat_a).is_greater(stat_b).override_failure_message(
		"Expected %s.%s (%d) > %s.%s (%d)"
		% [class_a, stat_name, stat_a, class_b, stat_name, stat_b]
	)


## Mirrors [method assert_class_stat_greater] but with `<` semantics.
static func assert_class_stat_less(
	suite: GdUnitTestSuite,
	class_a: String,
	class_b: String,
	stat_name: String
) -> void:
	var a: HeroClass = HeroClassDatabase.get_by_id(class_a)
	var b: HeroClass = HeroClassDatabase.get_by_id(class_b)
	suite.assert_object(a).is_not_null()
	suite.assert_object(b).is_not_null()
	var stat_a: int = int(a.get(stat_name))
	var stat_b: int = int(b.get(stat_name))
	suite.assert_int(stat_a).is_less(stat_b).override_failure_message(
		"Expected %s.%s (%d) < %s.%s (%d)"
		% [class_a, stat_name, stat_a, class_b, stat_name, stat_b]
	)
