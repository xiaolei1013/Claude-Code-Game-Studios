# Tests for Sprint 6 hero-roster Story 002: HeroRoster autoload skeleton + state fields + encapsulation.
# Covers: TR-hero-roster-005 (extends Node + _heroes Dictionary keyed by instance_id),
#         TR-hero-roster-007 (_formation_slots: Array[int] size 3),
#         TR-hero-roster-011 (_next_instance_id starts at 1, monotonic positive int),
#         TR-hero-roster-028 (zero-arg _init; underscore-private fields),
#         TR-hero-roster-009 (3 signals declared with exact arity).
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")


# ===========================================================================
# Group A: TR-005 — autoload reachable + _heroes Dictionary
# ===========================================================================

func test_hero_roster_autoload_node_resolves() -> void:
	var hr: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(hr).is_not_null()
	assert_bool(hr is Node).is_true()


func test_hero_roster_heroes_field_is_dictionary() -> void:
	var hr: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(hr).is_not_null()
	# Reset to empty-roster state (Sprint 8 S8-M4 hotfix wired call_deferred
	# seed in autoload _ready, so the live autoload may have Theron seeded by
	# the time tests run. Reset for skeleton-shape verification per ADR-0003).
	hr.load_save_data({"heroes": [], "formation_slots": [0, 0, 0], "next_instance_id": 1})
	# Dictionary type, empty after reset
	assert_bool(hr._heroes is Dictionary).is_true()
	assert_int((hr._heroes as Dictionary).size()).is_equal(0)


# ===========================================================================
# Group B: TR-007 — formation slots Array[int] size 3, all 0 at boot
# ===========================================================================

func test_hero_roster_formation_slots_is_array_of_int_size_three() -> void:
	var hr: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(hr).is_not_null()
	# Reset to empty-roster state (see test_hero_roster_heroes_field_is_dictionary).
	hr.load_save_data({"heroes": [], "formation_slots": [0, 0, 0], "next_instance_id": 1})
	var slots: Array = hr._formation_slots
	assert_int(slots.size()).is_equal(3)
	# All slots are 0 (empty) after reset
	for slot in slots:
		assert_int(slot).is_equal(0)


# ===========================================================================
# Group C: TR-011 — _next_instance_id starts at 1, monotonic positive int
# ===========================================================================

func test_hero_roster_next_instance_id_starts_at_one() -> void:
	var hr: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(hr).is_not_null()
	# Reset to empty-roster state (see test_hero_roster_heroes_field_is_dictionary).
	hr.load_save_data({"heroes": [], "formation_slots": [0, 0, 0], "next_instance_id": 1})
	# Value 1 — monotonic positive; first add_hero (Story 004) will assign id=1
	# then increment to 2 AFTER success.
	assert_int(hr._next_instance_id).is_equal(1)


# ===========================================================================
# Group D: TR-028 — zero-arg _init + underscore-private fields
# ===========================================================================

# D-01: _init has zero required parameters (per ADR-0003 Amendment #3).
# A non-autoload instance can be constructed with no args; if _init had any
# required parameters, this would error with "Method expected N arguments".
func test_hero_roster_init_has_zero_required_args() -> void:
	var hr: Node = HeroRosterScript.new()
	assert_object(hr).is_not_null()
	hr.free()


# D-02: state fields are underscore-prefixed (encapsulation enforced at code review).
# Direct attribute access works in GDScript regardless of underscore — this test
# verifies the FIELD NAMES match the convention. Future automated lint can grep
# for non-underscore field declarations to enforce.
func test_hero_roster_private_fields_use_underscore_prefix() -> void:
	var hr: Node = HeroRosterScript.new()
	# Reading via reflection: get_property_list() returns Dictionary entries.
	# Verify the five private state fields are present with underscore names.
	# (_config added in Story 003 — RosterConfig resolved at boot.)
	var expected: Array[String] = [
		"_heroes", "_formation_slots", "_next_instance_id", "_orphaned_heroes", "_config",
	]
	var prop_names: Array[String] = []
	for prop: Dictionary in hr.get_property_list():
		var n: String = prop.get("name", "")
		if n.begins_with("_") and n in expected:
			prop_names.append(n)
	assert_int(prop_names.size()).is_equal(expected.size())
	for class_name_check: String in expected:
		assert_bool(prop_names.has(class_name_check)).is_true()
	hr.free()


# ===========================================================================
# Group E: TR-009 — 3 signals declared with exact arity
# ===========================================================================

# E-01: hero_recruited signal exists with 1 arg (instance: HeroInstance)
func test_hero_roster_hero_recruited_signal_exists() -> void:
	var hr: Node = HeroRosterScript.new()
	var sigs: Array = hr.get_signal_list()
	var found: bool = false
	for sig: Dictionary in sigs:
		if sig.get("name", "") == "hero_recruited":
			found = true
			# Verify 1 argument: instance
			var args: Array = sig.get("args", [])
			assert_int(args.size()).is_equal(1)
	assert_bool(found).is_true()
	hr.free()


# E-02: hero_leveled signal exists with 3 args (instance_id, old_level, new_level)
func test_hero_roster_hero_leveled_signal_exists() -> void:
	var hr: Node = HeroRosterScript.new()
	var sigs: Array = hr.get_signal_list()
	var found: bool = false
	for sig: Dictionary in sigs:
		if sig.get("name", "") == "hero_leveled":
			found = true
			var args: Array = sig.get("args", [])
			assert_int(args.size()).is_equal(3)
	assert_bool(found).is_true()
	hr.free()


# E-03: hero_removed signal exists with 3 args (instance_id, class_id, display_name)
func test_hero_roster_hero_removed_signal_exists() -> void:
	var hr: Node = HeroRosterScript.new()
	var sigs: Array = hr.get_signal_list()
	var found: bool = false
	for sig: Dictionary in sigs:
		if sig.get("name", "") == "hero_removed":
			found = true
			var args: Array = sig.get("args", [])
			assert_int(args.size()).is_equal(3)
	assert_bool(found).is_true()
	hr.free()


# ===========================================================================
# Group E2: TR-hero-roster-006 — config accessors return GDD §G defaults
# Story 003 migrated MAX_ROSTER_SIZE/FORMATION_SIZE/LEVEL_CAP to roster_config.tres;
# the accessors now read from the loaded config (with `_FALLBACK_*` const fallback).
# Asserting against the live autoload (which has _ready()'d its config load).
# ===========================================================================

func test_hero_roster_accessors_return_gdd_defaults() -> void:
	var hr: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(hr).is_not_null()
	assert_int(hr.max_roster_size()).is_equal(30)
	assert_int(hr.formation_size()).is_equal(3)
	assert_int(hr.level_cap()).is_equal(15)


# ===========================================================================
# Group F: project.godot autoload registration
# ===========================================================================

# F-01: HeroRoster registered in project.godot [autoload] section after BiomeDungeonDatabase
func test_hero_roster_registered_in_project_godot() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var load_err: int = cfg.load("res://project.godot")
	assert_int(load_err).is_equal(OK)

	var autoload_path: String = cfg.get_value("autoload", "HeroRoster", "")
	# Path is "*res://..." — leading * marks it as a script-level autoload
	assert_str(autoload_path).is_equal("*res://src/core/hero_roster/hero_roster.gd")


# F-02: HeroRoster autoload appears AFTER BiomeDungeonDatabase + BEFORE SceneManager
# (rank 7 per architecture.md, between rank 6 and rank 8).
func test_hero_roster_appears_in_correct_rank_order() -> void:
	var file: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()

	var idx_biome: int = content.find("BiomeDungeonDatabase=")
	var idx_hero: int = content.find("HeroRoster=")
	var idx_scene: int = content.find("SceneManager=")
	assert_int(idx_biome).is_greater(0)
	assert_int(idx_hero).is_greater(idx_biome)
	assert_int(idx_scene).is_greater(idx_hero)
