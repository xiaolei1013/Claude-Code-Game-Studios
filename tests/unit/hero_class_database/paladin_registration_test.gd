# Paladin class registration tests.
#
# Cozy-tank archetype: tier-2, role="defender", counters caster.
# Stats: more HP than warrior, lower attack, slower speed.
extends GdUnitTestSuite

const Helper = preload("res://tests/helpers/class_registration_test_helper.gd")


func test_paladin_is_registered_in_data_registry_and_class_database() -> void:
	Helper.assert_class_registered(self, "paladin")


func test_paladin_has_tier_2_classification() -> void:
	Helper.assert_class_tier(self, "paladin", 2)


func test_paladin_role_is_defender() -> void:
	# Distinct from warrior's "tank" role — synergy detection treats it as
	# its own archetype slot.
	Helper.assert_class_role(self, "paladin", "defender")


func test_paladin_counters_caster_archetype() -> void:
	# Same counter as mage but with a defensive shape — expands the comp space
	# for caster-heavy biomes (whispering_crags, hollow_stair).
	Helper.assert_class_counter_archetype(self, "paladin", "caster")


func test_paladin_display_name_is_set() -> void:
	Helper.assert_class_display_name(self, "paladin", "Paladin")


func test_paladin_has_flavor_text() -> void:
	Helper.assert_class_flavor_text_non_empty(self, "paladin")


func test_paladin_has_more_hp_than_warrior() -> void:
	# Cozy-tank identity: trades attack for survivability.
	Helper.assert_class_stat_greater(self, "paladin", "warrior", "base_hp")


func test_paladin_has_lower_attack_than_warrior() -> void:
	Helper.assert_class_stat_less(self, "paladin", "warrior", "base_attack")
