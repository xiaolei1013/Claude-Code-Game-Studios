# Sprint 25 S25-S2-rev — Archer class registration tests.
#
# Verifies the archer .tres resource is discoverable by DataRegistry,
# resolvable via HeroClassDatabase, and has stat values consistent with
# the design intent (ranged DPS archetype: high DMG, low HP, high speed).
extends GdUnitTestSuite


# ===========================================================================
# Group A — Registry discovery
# ===========================================================================

func test_archer_is_discoverable_via_data_registry() -> void:
	var archer: Variant = DataRegistry.resolve("classes", "archer")
	assert_object(archer).is_not_null().override_failure_message(
		"DataRegistry.resolve('classes', 'archer') returned null. Either archer.tres "
		+ "is not in assets/data/classes/ or DataRegistry didn't scan it at boot."
	)


func test_archer_appears_in_hero_class_database_all_ids() -> void:
	var all_ids: Array[String] = HeroClassDatabase.get_all_ids()
	assert_array(all_ids).contains(["archer"]).override_failure_message(
		"Expected 'archer' in HeroClassDatabase.get_all_ids(). Got: %s" % str(all_ids)
	)


# ===========================================================================
# Group B — Stat shape (ranged DPS archetype contract)
# ===========================================================================

func test_archer_has_tier_2_classification() -> void:
	var archer: HeroClass = HeroClassDatabase.get_by_id("archer")
	assert_object(archer).is_not_null()
	assert_int(archer.tier).is_equal(2)


func test_archer_role_is_ranged_distinct_from_mage_striker() -> void:
	var archer: HeroClass = HeroClassDatabase.get_by_id("archer")
	var mage: HeroClass = HeroClassDatabase.get_by_id("mage")
	assert_object(archer).is_not_null()
	assert_str(archer.role).is_equal("ranged")
	# Sanity: mage's role is distinct (mage is striker; archer is ranged)
	assert_bool(archer.role == mage.role).is_false()


func test_archer_has_higher_attack_than_warrior_at_level_1() -> void:
	# Archer is the high-DPS option; should exceed warrior's attack
	var archer: HeroClass = HeroClassDatabase.get_by_id("archer")
	var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")
	assert_int(archer.base_attack).is_greater(warrior.base_attack)


func test_archer_has_higher_speed_than_warrior_at_level_1() -> void:
	# Ranged + scout shape: faster than the warrior frontline
	var archer: HeroClass = HeroClassDatabase.get_by_id("archer")
	var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")
	assert_int(archer.base_speed).is_greater(warrior.base_speed)


func test_archer_has_lower_hp_than_warrior_at_level_1() -> void:
	# Glass cannon: high DMG / low HP
	var archer: HeroClass = HeroClassDatabase.get_by_id("archer")
	var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")
	assert_int(archer.base_hp).is_less(warrior.base_hp)


# ===========================================================================
# Group C — Counter archetype (interaction surface)
# ===========================================================================

func test_archer_counters_swarm_archetype() -> void:
	# Archer counters "swarm" — distinct from warrior (bruiser), mage (caster),
	# rogue (armored), paladin (caster). Expands the matchup matrix.
	var archer: HeroClass = HeroClassDatabase.get_by_id("archer")
	assert_object(archer).is_not_null()
	assert_str(archer.counter_archetype).is_equal("swarm")


# ===========================================================================
# Group D — Display fields
# ===========================================================================

func test_archer_has_non_empty_display_name() -> void:
	var archer: HeroClass = HeroClassDatabase.get_by_id("archer")
	assert_object(archer).is_not_null()
	assert_int(archer.display_name.length()).is_greater(0)
	assert_str(archer.display_name).is_equal("Archer")


func test_archer_has_non_empty_flavor_text() -> void:
	var archer: HeroClass = HeroClassDatabase.get_by_id("archer")
	assert_object(archer).is_not_null()
	assert_int(archer.flavor_text.length()).is_greater(0)
