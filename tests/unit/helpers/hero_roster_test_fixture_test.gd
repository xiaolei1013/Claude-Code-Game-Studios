## Sprint 24 S24-S3 — HeroRoster test fixture helper tests.
##
## Tests the helpers themselves (round-trip, idempotency, defensive degrade).
## The actual *uses* of the helper across the test suite are exercised by
## the refactored test files in tests/unit/{guild_hall,formation_assignment}/.
extends GdUnitTestSuite

const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")


# Each test snapshots + restores the autoload state via the fixture itself
# (testing the fixture's snapshot/restore contract by using it directly).
var _outer_snapshot: Dictionary = {}


func before_test() -> void:
	# Snapshot the autoload state at test entry so we can restore it cleanly
	# in after_test regardless of how the test mutates it.
	_outer_snapshot = HeroRosterFixture.snapshot_via_save_data()


func after_test() -> void:
	HeroRosterFixture.restore_via_load_save_data(_outer_snapshot)


# ===========================================================================
# Group A — snapshot_via_save_data + restore_via_load_save_data round-trip
# ===========================================================================

func test_snapshot_returns_non_empty_dict_when_hero_roster_present() -> void:
	# Act
	var snap: Dictionary = HeroRosterFixture.snapshot_via_save_data()

	# Assert — non-empty (HeroRoster autoload is wired in project.godot).
	assert_bool(snap.is_empty()).is_false()
	# The snapshot should have at least the canonical keys.
	assert_bool(snap.has("heroes")).is_true()


func test_snapshot_is_deep_copy_not_reference() -> void:
	# Arrange — seed something to mutate
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var snap_a: Dictionary = HeroRosterFixture.snapshot_via_save_data()

	# Act — mutate the live state AFTER snapshotting
	HeroRosterFixture.seed_warriors(1)
	var snap_b: Dictionary = HeroRosterFixture.snapshot_via_save_data()

	# Assert — snap_a should be unchanged (deep-copy, not reference)
	var heroes_a: Array = snap_a["heroes"] as Array
	var heroes_b: Array = snap_b["heroes"] as Array
	assert_int(heroes_a.size()).is_equal(2)
	assert_int(heroes_b.size()).is_equal(3)


func test_restore_round_trip_preserves_hero_count() -> void:
	# Arrange — capture a clean state with 2 warriors
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var snap: Dictionary = HeroRosterFixture.snapshot_via_save_data()

	# Act — mutate then restore
	HeroRosterFixture.reset_hero_roster()
	assert_int(HeroRoster.get_all_heroes().size()).is_equal(0)
	HeroRosterFixture.restore_via_load_save_data(snap)

	# Assert — restored to 2 warriors
	assert_int(HeroRoster.get_all_heroes().size()).is_equal(2)


# ===========================================================================
# Group B — reset_hero_roster brings autoload to clean state
# ===========================================================================

func test_reset_clears_all_heroes() -> void:
	# Arrange
	HeroRosterFixture.seed_warriors(3)
	assert_int(HeroRoster.get_all_heroes().size()).is_greater_equal(3)

	# Act
	HeroRosterFixture.reset_hero_roster()

	# Assert
	assert_int(HeroRoster.get_all_heroes().size()).is_equal(0)


func test_reset_clears_prestige_state() -> void:
	# Arrange — set non-default prestige values
	HeroRoster._prestige_count = 5
	HeroRoster._prestige_multiplier = 1.25

	# Act
	HeroRosterFixture.reset_hero_roster()

	# Assert — reset to defaults
	assert_int(HeroRoster._prestige_count).is_equal(0)
	assert_float(HeroRoster._prestige_multiplier).is_equal_approx(1.0, 0.001)
	assert_int(HeroRoster._retired_hero_records.size()).is_equal(0)


func test_reset_clears_formation_slots() -> void:
	# Arrange — seed + put hero in slot 0
	HeroRosterFixture.seed_warriors(1)

	# Act
	HeroRosterFixture.reset_hero_roster()

	# Assert — all slots empty
	for slot: int in range(3):
		assert_int(HeroRoster.get_formation_slot(slot)).is_equal(0)


# ===========================================================================
# Group C — seed_warriors + seed_heroes
# ===========================================================================

func test_seed_warriors_returns_instance_ids_in_order() -> void:
	# Arrange
	HeroRosterFixture.reset_hero_roster()

	# Act
	var ids: Array[int] = HeroRosterFixture.seed_warriors(3)

	# Assert — 3 ids, all warriors, slots 0/1/2 set
	assert_int(ids.size()).is_equal(3)
	for id: int in ids:
		var hero: RefCounted = HeroRoster._heroes.get(id) as RefCounted
		assert_object(hero).is_not_null()
		assert_str(String(hero.get("class_id"))).is_equal("warrior")
	for slot: int in range(3):
		assert_int(HeroRoster.get_formation_slot(slot)).is_equal(ids[slot])


func test_seed_heroes_with_mixed_classes_returns_correct_ids() -> void:
	# Arrange
	HeroRosterFixture.reset_hero_roster()

	# Act — Triple Threat composition (1 warrior + 1 mage + 1 rogue)
	var ids: Array[int] = HeroRosterFixture.seed_heroes(["warrior", "mage", "rogue"])

	# Assert
	assert_int(ids.size()).is_equal(3)
	var expected_classes: Array[String] = ["warrior", "mage", "rogue"]
	for i: int in range(3):
		var hero: RefCounted = HeroRoster._heroes.get(ids[i]) as RefCounted
		assert_str(String(hero.get("class_id"))).is_equal(expected_classes[i])
