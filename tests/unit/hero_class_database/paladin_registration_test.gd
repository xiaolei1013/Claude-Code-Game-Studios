# Sprint 25 S25-M2-rev — Paladin class registration tests.
#
# Verifies the paladin .tres resource is discoverable by DataRegistry,
# resolvable via HeroClassDatabase, and has stat values consistent with
# the design intent (cozy-tank archetype: high HP, lower DMG, slower
# than warrior).
extends GdUnitTestSuite

const HeroClassScript = preload("res://src/core/hero_class_database/hero_class.gd")


# ===========================================================================
# Group A — Registry discovery
# ===========================================================================

func test_paladin_is_discoverable_via_data_registry() -> void:
	# Act
	var paladin: Variant = DataRegistry.resolve("classes", "paladin")

	# Assert — non-null + proper script type
	assert_object(paladin).is_not_null().override_failure_message(
		"DataRegistry.resolve('classes', 'paladin') returned null. Either paladin.tres "
		+ "is not in assets/data/classes/ or DataRegistry didn't scan it at boot."
	)


func test_paladin_appears_in_hero_class_database_all_ids() -> void:
	# Act
	var all_ids: Array[String] = HeroClassDatabase.get_all_ids()

	# Assert — paladin is in the list (alongside warrior/mage/rogue MVP set)
	assert_array(all_ids).contains(["paladin"]).override_failure_message(
		"Expected 'paladin' in HeroClassDatabase.get_all_ids(). Got: %s" % str(all_ids)
	)


# ===========================================================================
# Group B — Stat shape (cozy-tank archetype contract)
# ===========================================================================

func test_paladin_has_tier_2_classification() -> void:
	# Arrange + Act
	var paladin: HeroClass = HeroClassDatabase.get_by_id("paladin")

	# Assert — tier 2 (the "first non-MVP class" tier; warrior/mage/rogue are tier 1)
	assert_object(paladin).is_not_null()
	assert_int(paladin.tier).is_equal(2)


func test_paladin_role_is_defender_distinct_from_warrior_tank() -> void:
	# Arrange + Act
	var paladin: HeroClass = HeroClassDatabase.get_by_id("paladin")
	var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")

	# Assert — role is "defender" (distinct from warrior's "tank") so synergy
	# detection treats it as its own archetype slot, expanding the comp space.
	assert_object(paladin).is_not_null()
	assert_str(paladin.role).is_equal("defender")
	assert_str(warrior.role).is_equal("tank")
	# Sanity: roles are distinct so a paladin+warrior comp isn't a duplicate
	assert_bool(paladin.role == warrior.role).is_false()


func test_paladin_has_more_hp_than_warrior_at_level_1() -> void:
	# Arrange + Act
	var paladin: HeroClass = HeroClassDatabase.get_by_id("paladin")
	var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")

	# Assert — paladin is the cozy-tank: higher HP than warrior
	assert_object(paladin).is_not_null()
	assert_object(warrior).is_not_null()
	assert_int(paladin.base_hp).is_greater(warrior.base_hp)


func test_paladin_has_lower_attack_than_warrior_at_level_1() -> void:
	# Arrange + Act
	var paladin: HeroClass = HeroClassDatabase.get_by_id("paladin")
	var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")

	# Assert — paladin trades attack for survivability
	assert_int(paladin.base_attack).is_less(warrior.base_attack)


# ===========================================================================
# Group C — Counter archetype (interaction surface)
# ===========================================================================

func test_paladin_counters_caster_archetype() -> void:
	# Arrange + Act
	var paladin: HeroClass = HeroClassDatabase.get_by_id("paladin")

	# Assert — paladin counters "caster" (different from warrior's "bruiser"
	# counter). Expands the matchup interaction matrix.
	assert_object(paladin).is_not_null()
	assert_str(paladin.counter_archetype).is_equal("caster")


# ===========================================================================
# Group D — Display fields
# ===========================================================================

func test_paladin_has_non_empty_display_name() -> void:
	var paladin: HeroClass = HeroClassDatabase.get_by_id("paladin")
	assert_object(paladin).is_not_null()
	assert_int(paladin.display_name.length()).is_greater(0)
	assert_str(paladin.display_name).is_equal("Paladin")


func test_paladin_has_non_empty_flavor_text() -> void:
	var paladin: HeroClass = HeroClassDatabase.get_by_id("paladin")
	assert_object(paladin).is_not_null()
	assert_int(paladin.flavor_text.length()).is_greater(0)
