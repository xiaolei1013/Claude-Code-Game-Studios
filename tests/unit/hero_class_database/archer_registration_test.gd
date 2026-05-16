# Archer class registration tests.
#
# Ranged-DPS archetype: tier-2, role="ranged", counters swarm.
# Stats: higher attack + speed than warrior, lower HP (glass cannon).
extends GdUnitTestSuite

const Helper = preload("res://tests/helpers/class_registration_test_helper.gd")


func test_archer_is_registered_in_data_registry_and_class_database() -> void:
	Helper.assert_class_registered(self, "archer")


func test_archer_has_tier_2_classification() -> void:
	Helper.assert_class_tier(self, "archer", 2)


func test_archer_role_is_ranged() -> void:
	# Distinct from mage's "striker" role — both deal damage but ranged
	# implies a positional read the matchup system can branch on later.
	Helper.assert_class_role(self, "archer", "ranged")


func test_archer_counters_swarm_archetype() -> void:
	# NEW counter not used by warrior/mage/rogue/paladin. Sets up V1.0
	# swarm-archetype biome introductions to have an existing counter.
	Helper.assert_class_counter_archetype(self, "archer", "swarm")


func test_archer_display_name_is_set() -> void:
	Helper.assert_class_display_name(self, "archer", "Archer")


func test_archer_has_flavor_text() -> void:
	Helper.assert_class_flavor_text_non_empty(self, "archer")


func test_archer_has_higher_attack_than_warrior() -> void:
	Helper.assert_class_stat_greater(self, "archer", "warrior", "base_attack")


func test_archer_has_higher_speed_than_warrior() -> void:
	Helper.assert_class_stat_greater(self, "archer", "warrior", "base_speed")


func test_archer_has_lower_hp_than_warrior() -> void:
	# Glass-cannon identity
	Helper.assert_class_stat_less(self, "archer", "warrior", "base_hp")
