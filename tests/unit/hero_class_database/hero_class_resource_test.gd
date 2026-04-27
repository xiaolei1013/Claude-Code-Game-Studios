# Tests for Story S2-M5: HeroClass resource subclass + EnemyArchetypes constants.
# Covers: TR-hero-class-db-001, TR-hero-class-db-002, TR-hero-class-db-005,
#         TR-hero-class-db-006, ADR-0011 (Resource schema, archetype-tag centralization).
#
# All tests instantiate HeroClass directly (preload-and-new) for isolation.
# EnemyArchetypes tests operate on the canonical location:
#   assets/data/archetypes/enemy_archetypes.gd  (shipped in Sprint 1 — do NOT recreate)
#
# NOTE: HeroClass extends GameData extends Resource (RefCounted).
# Do NOT call .free() on these instances — Godot manages lifetime via refcounting.
extends GdUnitTestSuite

const HeroClassScript = preload("res://src/core/hero_class_database/hero_class.gd")
const HERO_CLASS_SOURCE_PATH: String = "res://src/core/hero_class_database/hero_class.gd"


# ---------------------------------------------------------------------------
# TR-hero-class-db-001: HeroClass default instantiation
# ---------------------------------------------------------------------------

func test_hero_class_new_succeeds_without_args() -> void:
	# Arrange / Act
	var hc: HeroClass = HeroClassScript.new()

	# Assert — must not be null and must be the correct type
	assert_object(hc).is_not_null()
	assert_bool(hc is HeroClass).is_true()
	assert_bool(hc is GameData).is_true()


# ---------------------------------------------------------------------------
# TR-hero-class-db-001/002: Inherited GameData fields are present and default
# ---------------------------------------------------------------------------

func test_hero_class_inherits_id_and_display_name_from_game_data() -> void:
	# Arrange
	var hc: HeroClass = HeroClassScript.new()

	# Act / Assert — inherited fields default to empty string (GameData contract)
	assert_str(hc.id).is_equal("")
	assert_str(hc.display_name).is_equal("")


# ---------------------------------------------------------------------------
# TR-hero-class-db-001/002: Schema property introspection — all 17 fields present
# ---------------------------------------------------------------------------

func test_hero_class_schema_has_all_seventeen_exported_properties() -> void:
	# Arrange
	var hc: HeroClass = HeroClassScript.new()

	# Act — enumerate @export properties.
	# PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE identifies user-defined
	# @export fields across the full inheritance chain.
	const EXPORT_FLAG: int = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	var export_names: Array[String] = []
	for prop: Dictionary in hc.get_property_list():
		if (prop["usage"] & EXPORT_FLAG) == EXPORT_FLAG:
			export_names.append(prop["name"])

	# Assert — 17 total: 2 inherited (id, display_name) + 15 new fields
	assert_int(export_names.size()).is_greater_equal(17)

	# Assert each of the 15 new schema fields is individually present
	var expected_new_fields: Array[String] = [
		"tier",
		"role",
		"counter_archetype",
		"base_attack",
		"base_hp",
		"base_speed",
		"attack_per_level",
		"hp_per_level",
		"speed_per_level",
		"tick_output_contribution_l1",
		"tick_output_per_level",
		"sprite_path",
		"portrait_path",
		"icon_path",
		"flavor_text",
	]
	for field_name: String in expected_new_fields:
		assert_bool(field_name in export_names).is_true()

	# Assert the 2 inherited fields are also enumerable
	assert_bool("id" in export_names).is_true()
	assert_bool("display_name" in export_names).is_true()


# ---------------------------------------------------------------------------
# TR-hero-class-db-001/002: Default values are valid (no uninitialized required fields)
# ---------------------------------------------------------------------------

func test_hero_class_default_int_fields_are_zero() -> void:
	# Arrange
	var hc: HeroClass = HeroClassScript.new()

	# Act / Assert — all integer stat fields default to 0
	assert_int(hc.tier).is_equal(1)
	assert_int(hc.base_attack).is_equal(0)
	assert_int(hc.base_hp).is_equal(0)
	assert_int(hc.base_speed).is_equal(0)
	assert_int(hc.attack_per_level).is_equal(0)
	assert_int(hc.hp_per_level).is_equal(0)
	assert_int(hc.speed_per_level).is_equal(0)
	assert_int(hc.tick_output_contribution_l1).is_equal(0)
	assert_int(hc.tick_output_per_level).is_equal(0)


func test_hero_class_default_string_fields_are_empty() -> void:
	# Arrange
	var hc: HeroClass = HeroClassScript.new()

	# Act / Assert — all string fields default to empty string
	assert_str(hc.role).is_equal("")
	assert_str(hc.counter_archetype).is_equal("")
	assert_str(hc.sprite_path).is_equal("")
	assert_str(hc.portrait_path).is_equal("")
	assert_str(hc.icon_path).is_equal("")
	assert_str(hc.flavor_text).is_equal("")


# ---------------------------------------------------------------------------
# TR-hero-class-db-005: EnemyArchetypes constants (canonical Sprint 1 location)
# ---------------------------------------------------------------------------

func test_enemy_archetypes_constants_are_lowercase_strings() -> void:
	# Arrange / Act — static access to canonical constant holder
	# Assert each of the 6 archetype constants has the correct lowercase value
	assert_str(EnemyArchetypes.BRUISER).is_equal("bruiser")
	assert_str(EnemyArchetypes.CASTER).is_equal("caster")
	assert_str(EnemyArchetypes.ARMORED).is_equal("armored")
	assert_str(EnemyArchetypes.BEAST).is_equal("beast")
	assert_str(EnemyArchetypes.CONSTRUCT).is_equal("construct")
	assert_str(EnemyArchetypes.INCORPOREAL).is_equal("incorporeal")


func test_enemy_archetypes_all_set_contains_all_six_archetypes() -> void:
	# Arrange / Act — ALL_SET is the canonical full set (Sprint 1 name; story used "ALL")
	assert_int(EnemyArchetypes.ALL_SET.size()).is_equal(6)

	# Assert all 6 constants are members of ALL_SET
	assert_bool(EnemyArchetypes.ALL_SET.has(EnemyArchetypes.BRUISER)).is_true()
	assert_bool(EnemyArchetypes.ALL_SET.has(EnemyArchetypes.CASTER)).is_true()
	assert_bool(EnemyArchetypes.ALL_SET.has(EnemyArchetypes.ARMORED)).is_true()
	assert_bool(EnemyArchetypes.ALL_SET.has(EnemyArchetypes.BEAST)).is_true()
	assert_bool(EnemyArchetypes.ALL_SET.has(EnemyArchetypes.CONSTRUCT)).is_true()
	assert_bool(EnemyArchetypes.ALL_SET.has(EnemyArchetypes.INCORPOREAL)).is_true()


# ---------------------------------------------------------------------------
# TR-hero-class-db-006: No magic archetype strings in hero_class.gd source
# ---------------------------------------------------------------------------

func test_hero_class_source_contains_no_hardcoded_archetype_string_literals() -> void:
	# Arrange — read hero_class.gd source as text
	var file: FileAccess = FileAccess.open(HERO_CLASS_SOURCE_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var source: String = file.get_as_text()
	file.close()

	# Act / Assert — none of the 6 archetype literal strings appear quoted in source.
	# The default for counter_archetype is "" (empty string) — no archetype value literal.
	# This ensures ADR-0011 §Forbidden: no magic strings in hero_class.gd.
	assert_str(source).not_contains("\"bruiser\"")
	assert_str(source).not_contains("\"caster\"")
	assert_str(source).not_contains("\"armored\"")
	assert_str(source).not_contains("\"beast\"")
	assert_str(source).not_contains("\"construct\"")
	assert_str(source).not_contains("\"incorporeal\"")
