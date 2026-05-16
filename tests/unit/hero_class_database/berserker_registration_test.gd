# Berserker class registration tests.
#
# Brawler archetype: tier-2, role="brawler", counters bruiser.
# Stats: higher attack + speed than warrior, lower HP. Shared bruiser-
# counter with warrior + paladin enables triple-bruiser-counter comps.
extends GdUnitTestSuite

const Helper = preload("res://tests/helpers/class_registration_test_helper.gd")


func test_berserker_is_registered_in_data_registry_and_class_database() -> void:
	Helper.assert_class_registered(self, "berserker")


func test_berserker_has_tier_2_classification() -> void:
	Helper.assert_class_tier(self, "berserker", 2)


func test_berserker_role_is_brawler() -> void:
	# Distinct from warrior's "tank" — both counter bruisers but with
	# different play patterns (warrior absorbs, berserker damages).
	Helper.assert_class_role(self, "berserker", "brawler")


func test_berserker_counters_bruiser_archetype() -> void:
	# Shared with warrior — intentional. Enables triple-bruiser-counter
	# formation (warrior + paladin + berserker) for forest_reach,
	# ember_wastes, sunken_ruins (all bruiser-dominant per Biome DB).
	Helper.assert_class_counter_archetype(self, "berserker", "bruiser")


func test_berserker_display_name_is_set() -> void:
	Helper.assert_class_display_name(self, "berserker", "Berserker")


func test_berserker_has_flavor_text() -> void:
	Helper.assert_class_flavor_text_non_empty(self, "berserker")


func test_berserker_has_higher_attack_than_warrior() -> void:
	Helper.assert_class_stat_greater(self, "berserker", "warrior", "base_attack")


func test_berserker_has_higher_speed_than_warrior() -> void:
	Helper.assert_class_stat_greater(self, "berserker", "warrior", "base_speed")


func test_berserker_has_lower_hp_than_warrior() -> void:
	Helper.assert_class_stat_less(self, "berserker", "warrior", "base_hp")
