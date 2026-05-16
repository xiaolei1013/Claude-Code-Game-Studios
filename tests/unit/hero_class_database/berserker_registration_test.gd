# Sprint 26 M2 — Berserker class registration tests.
#
# Verifies the berserker .tres resource is discoverable by DataRegistry,
# resolvable via HeroClassDatabase, and has stat values consistent with
# the design intent (brawler archetype: high DMG, moderate HP, high speed,
# counters bruiser).
extends GdUnitTestSuite


# ===========================================================================
# Group A — Registry discovery
# ===========================================================================

func test_berserker_is_discoverable_via_data_registry() -> void:
	var berserker: Variant = DataRegistry.resolve("classes", "berserker")
	assert_object(berserker).is_not_null().override_failure_message(
		"DataRegistry.resolve('classes', 'berserker') returned null. Either berserker.tres "
		+ "is not in assets/data/classes/ or DataRegistry didn't scan it at boot."
	)


func test_berserker_appears_in_hero_class_database_all_ids() -> void:
	var all_ids: Array[String] = HeroClassDatabase.get_all_ids()
	assert_array(all_ids).contains(["berserker"]).override_failure_message(
		"Expected 'berserker' in HeroClassDatabase.get_all_ids(). Got: %s" % str(all_ids)
	)


# ===========================================================================
# Group B — Stat shape (brawler archetype contract)
# ===========================================================================

func test_berserker_has_tier_2_classification() -> void:
	var berserker: HeroClass = HeroClassDatabase.get_by_id("berserker")
	assert_object(berserker).is_not_null()
	assert_int(berserker.tier).is_equal(2)


func test_berserker_role_is_brawler_distinct_from_warrior_tank() -> void:
	# Brawler is the rage-driven counterpart to warrior's defensive tank.
	# Both counter bruisers but with different play patterns (warrior absorbs,
	# berserker damages).
	var berserker: HeroClass = HeroClassDatabase.get_by_id("berserker")
	var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")
	assert_object(berserker).is_not_null()
	assert_str(berserker.role).is_equal("brawler")
	assert_bool(berserker.role == warrior.role).is_false()


func test_berserker_has_higher_attack_than_warrior_at_level_1() -> void:
	# DPS-first brawler — higher attack than the defensive tank
	var berserker: HeroClass = HeroClassDatabase.get_by_id("berserker")
	var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")
	assert_int(berserker.base_attack).is_greater(warrior.base_attack)


func test_berserker_has_lower_hp_than_warrior_at_level_1() -> void:
	# Trades tankiness for damage output
	var berserker: HeroClass = HeroClassDatabase.get_by_id("berserker")
	var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")
	assert_int(berserker.base_hp).is_less(warrior.base_hp)


func test_berserker_has_higher_speed_than_warrior_at_level_1() -> void:
	var berserker: HeroClass = HeroClassDatabase.get_by_id("berserker")
	var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")
	assert_int(berserker.base_speed).is_greater(warrior.base_speed)


# ===========================================================================
# Group C — Counter archetype (shared bruiser-counter with warrior)
# ===========================================================================

func test_berserker_counters_bruiser_archetype() -> void:
	# Berserker shares warrior's bruiser-counter role; this is INTENTIONAL —
	# enables triple-bruiser-counter comps (warrior + paladin + berserker)
	# for biomes with heavy bruiser presence (forest_reach, sunken_ruins).
	var berserker: HeroClass = HeroClassDatabase.get_by_id("berserker")
	assert_object(berserker).is_not_null()
	assert_str(berserker.counter_archetype).is_equal("bruiser")


# ===========================================================================
# Group D — Display fields
# ===========================================================================

func test_berserker_has_non_empty_display_name() -> void:
	var berserker: HeroClass = HeroClassDatabase.get_by_id("berserker")
	assert_object(berserker).is_not_null()
	assert_int(berserker.display_name.length()).is_greater(0)
	assert_str(berserker.display_name).is_equal("Berserker")


func test_berserker_has_non_empty_flavor_text() -> void:
	var berserker: HeroClass = HeroClassDatabase.get_by_id("berserker")
	assert_object(berserker).is_not_null()
	assert_int(berserker.flavor_text.length()).is_greater(0)
