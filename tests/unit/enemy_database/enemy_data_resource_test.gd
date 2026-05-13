# Tests for Story S3-M2: EnemyData resource subclass + EnemyArchetypes consumer.
# Covers: TR-enemy-db-001, TR-enemy-db-002, TR-enemy-db-004, TR-enemy-db-007.
#         ADR-0011 (Resource schema, archetype-tag centralization).
#
# All tests instantiate EnemyData directly (preload-and-new) for isolation.
# EnemyData extends GameData extends Resource (RefCounted).
# Do NOT call .free() on these instances — Godot manages lifetime via refcounting.
extends GdUnitTestSuite

const EnemyDataScript = preload("res://src/core/enemy_database/enemy_data.gd")
const ENEMY_DATA_SOURCE_PATH: String = "res://src/core/enemy_database/enemy_data.gd"


# ---------------------------------------------------------------------------
# TR-enemy-db-001: EnemyData default instantiation
# ---------------------------------------------------------------------------

func test_enemy_data_new_succeeds_without_args() -> void:
	# Arrange / Act
	var ed: EnemyData = EnemyDataScript.new()

	# Assert — must not be null and must be the correct type
	assert_object(ed).is_not_null()
	assert_bool(ed is EnemyData).is_true()
	assert_bool(ed is GameData).is_true()


# ---------------------------------------------------------------------------
# TR-enemy-db-001/002: Inherited GameData fields are present and default empty
# ---------------------------------------------------------------------------

func test_enemy_data_inherits_id_and_display_name_from_game_data() -> void:
	# Arrange
	var ed: EnemyData = EnemyDataScript.new()

	# Act / Assert — inherited fields default to empty string (GameData contract)
	assert_str(ed.id).is_equal("")
	assert_str(ed.display_name).is_equal("")


# ---------------------------------------------------------------------------
# TR-enemy-db-001/002: Schema property introspection — all 12 fields present
# ---------------------------------------------------------------------------

func test_enemy_data_schema_has_all_twelve_exported_properties() -> void:
	# Arrange
	var ed: EnemyData = EnemyDataScript.new()

	# Act — enumerate @export properties.
	# PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE identifies user-defined
	# @export fields across the full inheritance chain.
	const EXPORT_FLAG: int = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	var export_names: Array[String] = []
	for prop: Dictionary in ed.get_property_list():
		if (prop["usage"] & EXPORT_FLAG) == EXPORT_FLAG:
			export_names.append(prop["name"])

	# Assert — 12 total: 2 inherited (id, display_name) + 10 net-new fields
	assert_int(export_names.size()).is_greater_equal(12)

	# Assert each of the 10 net-new schema fields is individually present
	var expected_new_fields: Array[String] = [
		"tier",
		"archetype",
		"biome",
		"base_hp",
		"base_attack",
		"base_speed",
		"sprite_path",
		"death_anim_key",
		"flavor_text",
		"is_boss",
	]
	for field_name: String in expected_new_fields:
		assert_bool(field_name in export_names).is_true()

	# Assert the 2 inherited fields are also enumerable
	assert_bool("id" in export_names).is_true()
	assert_bool("display_name" in export_names).is_true()


# ---------------------------------------------------------------------------
# TR-enemy-db-001/002: Default values — integer fields
# ---------------------------------------------------------------------------

func test_enemy_data_default_int_fields_are_correct() -> void:
	# Arrange
	var ed: EnemyData = EnemyDataScript.new()

	# Act / Assert — tier defaults to 1; all stat fields default to 0
	assert_int(ed.tier).is_equal(1)
	assert_int(ed.base_hp).is_equal(0)
	assert_int(ed.base_attack).is_equal(0)
	assert_int(ed.base_speed).is_equal(0)


# ---------------------------------------------------------------------------
# TR-enemy-db-001/002: Default values — string fields
# ---------------------------------------------------------------------------

func test_enemy_data_default_string_fields_are_empty() -> void:
	# Arrange
	var ed: EnemyData = EnemyDataScript.new()

	# Act / Assert — all string fields default to empty string
	assert_str(ed.archetype).is_equal("")
	assert_str(ed.biome).is_equal("")
	assert_str(ed.sprite_path).is_equal("")
	assert_str(ed.death_anim_key).is_equal("")
	assert_str(ed.flavor_text).is_equal("")


# ---------------------------------------------------------------------------
# TR-enemy-db-001/002: Default value — is_boss defaults false
# ---------------------------------------------------------------------------

func test_enemy_data_is_boss_defaults_false() -> void:
	# Arrange
	var ed: EnemyData = EnemyDataScript.new()

	# Act / Assert — is_boss must default to false (ADR-0011)
	assert_bool(ed.is_boss).is_false()


# ---------------------------------------------------------------------------
# TR-enemy-db-004: No leveling fields in MVP schema
# ---------------------------------------------------------------------------

func test_enemy_data_schema_has_no_leveling_fields() -> void:
	# Arrange
	var ed: EnemyData = EnemyDataScript.new()

	# Act — enumerate all property names (not just exports)
	var all_names: Array[String] = []
	for prop: Dictionary in ed.get_property_list():
		all_names.append(prop["name"])

	# Assert — no level / current_level fields (enemies are static, not leveling)
	assert_bool("level" in all_names).is_false()
	assert_bool("current_level" in all_names).is_false()


# ---------------------------------------------------------------------------
# TR-enemy-db-004: No loot_override or resistance fields in MVP schema
# ---------------------------------------------------------------------------

func test_enemy_data_schema_has_no_loot_override_or_resistance_fields() -> void:
	# Arrange
	var ed: EnemyData = EnemyDataScript.new()

	# Act — enumerate all property names
	var all_names: Array[String] = []
	for prop: Dictionary in ed.get_property_list():
		all_names.append(prop["name"])

	# Assert — no loot override or resistance fields (TR-enemy-db-004 + TR-enemy-db-023)
	assert_bool("loot_override" in all_names).is_false()

	# Check that no property name starts with "resistance_"
	var has_resistance_field: bool = false
	for enemy_name: String in all_names:
		if enemy_name.begins_with("resistance_"):
			has_resistance_field = true
			break
	assert_bool(has_resistance_field).is_false()


# ---------------------------------------------------------------------------
# TR-enemy-db-007: No magic archetype strings in enemy_data.gd source
# ---------------------------------------------------------------------------

func test_enemy_data_source_contains_no_hardcoded_archetype_string_literals() -> void:
	# Arrange — read enemy_data.gd source as text
	var file: FileAccess = FileAccess.open(ENEMY_DATA_SOURCE_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var source: String = file.get_as_text()
	file.close()

	# Act / Assert — none of the 6 archetype literal strings appear quoted in source.
	# The default for archetype is "" (empty string) — no archetype value literal.
	# This ensures ADR-0011 §Forbidden: no magic strings in enemy_data.gd.
	assert_str(source).not_contains("\"bruiser\"")
	assert_str(source).not_contains("\"caster\"")
	assert_str(source).not_contains("\"armored\"")
	assert_str(source).not_contains("\"beast\"")
	assert_str(source).not_contains("\"construct\"")
	assert_str(source).not_contains("\"incorporeal\"")


# ---------------------------------------------------------------------------
# TR-enemy-db-007: Default archetype value is empty string, not a literal
# ---------------------------------------------------------------------------

func test_enemy_data_default_archetype_is_empty_not_a_literal_archetype() -> void:
	# Arrange
	var ed: EnemyData = EnemyDataScript.new()

	# Act / Assert — default must be "" not any archetype constant value
	assert_str(ed.archetype).is_equal("")
	assert_bool(EnemyArchetypes.is_valid(ed.archetype)).is_false()
