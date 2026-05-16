# ClassRegistrationTestHelper self-tests.
#
# Smoke checks that each helper assertion fires correctly against the
# canonical MVP warrior class. If the warrior data shape ever drifts,
# these tests catch it before the dependent class tests (paladin, archer,
# berserker) fail with confusing helper-internal errors.
extends GdUnitTestSuite

const Helper = preload("res://tests/helpers/class_registration_test_helper.gd")


func test_helper_recognizes_warrior_as_registered() -> void:
	Helper.assert_class_registered(self, "warrior")


func test_helper_recognizes_warrior_tier_1() -> void:
	Helper.assert_class_tier(self, "warrior", 1)


func test_helper_recognizes_warrior_tank_role() -> void:
	Helper.assert_class_role(self, "warrior", "tank")


func test_helper_recognizes_warrior_bruiser_counter() -> void:
	Helper.assert_class_counter_archetype(self, "warrior", "bruiser")


func test_helper_recognizes_warrior_display_name() -> void:
	Helper.assert_class_display_name(self, "warrior", "Warrior")


func test_helper_recognizes_warrior_has_flavor_text() -> void:
	Helper.assert_class_flavor_text_non_empty(self, "warrior")


func test_helper_stat_greater_warrior_hp_above_mage_hp() -> void:
	# Warrior is tankier than mage — sanity check the comparison helper
	Helper.assert_class_stat_greater(self, "warrior", "mage", "base_hp")


func test_helper_stat_less_warrior_attack_below_mage_attack() -> void:
	# Mage hits harder than warrior — sanity check the inverse comparison
	Helper.assert_class_stat_less(self, "warrior", "mage", "base_attack")


func test_valid_stat_names_includes_all_documented_int_fields() -> void:
	# Canary: if a HeroClass int field is added without updating
	# VALID_STAT_NAMES, the helper silently fails to validate the new
	# stat. This test fails first with a clear message in that scenario.
	var expected: Array[String] = [
		"base_attack",
		"base_hp",
		"base_speed",
		"attack_per_level",
		"hp_per_level",
		"speed_per_level",
		"tick_output_contribution_l1",
		"tick_output_per_level",
		"tier",
	]
	for stat: String in expected:
		assert_bool(Helper.VALID_STAT_NAMES.has(stat)).is_true().override_failure_message(
			"VALID_STAT_NAMES missing '%s'. Update the helper when adding HeroClass int fields."
			% stat
		)
