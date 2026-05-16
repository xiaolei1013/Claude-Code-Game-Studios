# Cleric class registration tests.
#
# Support archetype: tier-2, role="support", counters armored.
# Stats: balanced; the load-bearing distinction is high
# tick_output_contribution_l1 (sustained DPS via the tick economy
# rather than spike damage). Shared armored-counter with rogue enables
# double-armored-counter comps for whispering_crags/hollow_stair/frostmire.
extends GdUnitTestSuite

const Helper = preload("res://tests/helpers/class_registration_test_helper.gd")


func test_cleric_is_registered_in_data_registry_and_class_database() -> void:
	Helper.assert_class_registered(self, "cleric")


func test_cleric_has_tier_2_classification() -> void:
	Helper.assert_class_tier(self, "cleric", 2)


func test_cleric_role_is_support() -> void:
	# NEW role distinct from all 6 prior classes. Tick-economy DPS rather
	# than direct combat — sustained over a run instead of spike per hit.
	Helper.assert_class_role(self, "cleric", "support")


func test_cleric_counters_armored_archetype() -> void:
	# Shared with rogue — enables double-armored-counter comps for biomes
	# with heavy armored presence (whispering_crags, hollow_stair, frostmire,
	# forest_reach, ember_wastes per Biome DB dominant_archetypes).
	Helper.assert_class_counter_archetype(self, "cleric", "armored")


func test_cleric_display_name_is_set() -> void:
	Helper.assert_class_display_name(self, "cleric", "Cleric")


func test_cleric_has_flavor_text() -> void:
	Helper.assert_class_flavor_text_non_empty(self, "cleric")


func test_cleric_has_higher_tick_output_than_warrior() -> void:
	# Support identity: outsized contribution to the tick economy. Warrior
	# tick_output_contribution_l1 = 2; cleric's must be higher so the
	# "support" play pattern (sustained DPS) is mechanically distinct.
	Helper.assert_class_stat_greater(
		self, "cleric", "warrior", "tick_output_contribution_l1"
	)


func test_cleric_has_higher_tick_output_per_level_than_warrior() -> void:
	# Scales harder per level than non-support classes — the late-game
	# read of "this hero became a workhorse" comes from this stat.
	Helper.assert_class_stat_greater(
		self, "cleric", "warrior", "tick_output_per_level"
	)
