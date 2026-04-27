# Tests for Story S3-M5: Biome / Dungeon / Floor resource subclasses.
# Covers: TR-biome-dungeon-db-001, TR-biome-dungeon-db-002, TR-biome-dungeon-db-003,
#         TR-biome-dungeon-db-004, TR-biome-dungeon-db-005.
#         ADR-0011 (Resource schema, nested resource composition).
#
# All tests instantiate resources directly (preload-and-new) for isolation.
# Biome/Dungeon/Floor each extend GameData extends Resource (RefCounted).
# Do NOT call .free() on these instances — Godot manages lifetime via refcounting.
extends GdUnitTestSuite

const BiomeScript = preload("res://src/core/biome_dungeon_database/biome.gd")
const DungeonScript = preload("res://src/core/biome_dungeon_database/dungeon.gd")
const FloorScript = preload("res://src/core/biome_dungeon_database/floor.gd")

# Utility: enumerate @export property names on a resource instance.
# PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE identifies user-defined
# @export fields across the full inheritance chain.
const EXPORT_FLAG: int = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE

func _get_export_names(resource: Resource) -> Array[String]:
	var names: Array[String] = []
	for prop: Dictionary in resource.get_property_list():
		if (prop["usage"] & EXPORT_FLAG) == EXPORT_FLAG:
			names.append(prop["name"])
	return names


# ---------------------------------------------------------------------------
# TR-biome-dungeon-db-001: Default instantiation — all three types
# ---------------------------------------------------------------------------

func test_biome_new_succeeds_without_args() -> void:
	# Arrange / Act
	var b: Biome = BiomeScript.new()

	# Assert — correct type and GameData lineage
	assert_object(b).is_not_null()
	assert_bool(b is Biome).is_true()
	assert_bool(b is GameData).is_true()


func test_dungeon_new_succeeds_without_args() -> void:
	# Arrange / Act
	var d: Dungeon = DungeonScript.new()

	# Assert — correct type and GameData lineage
	assert_object(d).is_not_null()
	assert_bool(d is Dungeon).is_true()
	assert_bool(d is GameData).is_true()


func test_floor_new_succeeds_without_args() -> void:
	# Arrange / Act
	var f: Floor = FloorScript.new()

	# Assert — correct type and GameData lineage
	assert_object(f).is_not_null()
	assert_bool(f is Floor).is_true()
	assert_bool(f is GameData).is_true()


# ---------------------------------------------------------------------------
# TR-biome-dungeon-db-002: Biome schema shape — 6 net-new + 2 inherited = 8 total
# ---------------------------------------------------------------------------

func test_biome_schema_has_all_eight_exported_properties() -> void:
	# Arrange
	var b: Biome = BiomeScript.new()

	# Act
	var export_names: Array[String] = _get_export_names(b)

	# Assert total count (2 inherited + 6 net-new)
	assert_int(export_names.size()).is_greater_equal(8)

	# Assert each of the 6 net-new fields is present
	var expected_new: Array[String] = [
		"primary_palette_key",
		"dominant_archetypes",
		"dungeons",
		"environmental_storytelling",
		"flavor_text",
		"status",
	]
	for field_name: String in expected_new:
		assert_bool(field_name in export_names).is_true()

	# Assert inherited fields also enumerable
	assert_bool("id" in export_names).is_true()
	assert_bool("display_name" in export_names).is_true()


# ---------------------------------------------------------------------------
# TR-biome-dungeon-db-003: Dungeon schema shape — 2 net-new + 2 inherited = 4 total
# ---------------------------------------------------------------------------

func test_dungeon_schema_has_all_four_exported_properties() -> void:
	# Arrange
	var d: Dungeon = DungeonScript.new()

	# Act
	var export_names: Array[String] = _get_export_names(d)

	# Assert total count (2 inherited + 2 net-new)
	assert_int(export_names.size()).is_greater_equal(4)

	# Assert each of the 2 net-new fields is present
	var expected_new: Array[String] = [
		"biome_id",
		"floors",
	]
	for field_name: String in expected_new:
		assert_bool(field_name in export_names).is_true()

	# Assert inherited fields also enumerable
	assert_bool("id" in export_names).is_true()
	assert_bool("display_name" in export_names).is_true()


# ---------------------------------------------------------------------------
# TR-biome-dungeon-db-004: Floor schema shape — 5 net-new + 2 inherited = 7 total
# ---------------------------------------------------------------------------

func test_floor_schema_has_all_seven_exported_properties() -> void:
	# Arrange
	var f: Floor = FloorScript.new()

	# Act
	var export_names: Array[String] = _get_export_names(f)

	# Assert total count (2 inherited + 5 net-new)
	assert_int(export_names.size()).is_greater_equal(7)

	# Assert each of the 5 net-new fields is present
	var expected_new: Array[String] = [
		"floor_index",
		"enemy_list",
		"expected_clear_time_seconds",
		"is_boss_floor",
		"flavor_text",
	]
	for field_name: String in expected_new:
		assert_bool(field_name in export_names).is_true()

	# Assert inherited fields also enumerable
	assert_bool("id" in export_names).is_true()
	assert_bool("display_name" in export_names).is_true()


# ---------------------------------------------------------------------------
# TR-biome-dungeon-db-005: Floor.enemy_list entry shape — deterministic dict keys
# ---------------------------------------------------------------------------

func test_floor_enemy_list_entry_has_exactly_enemy_id_and_count_keys() -> void:
	# Arrange
	var f: Floor = FloorScript.new()
	f.enemy_list = [
		{"enemy_id": "hollow_brute", "count": 3},
		{"enemy_id": "bog_caster", "count": 2},
	]

	# Act
	var first_entry: Dictionary = f.enemy_list[0]
	var second_entry: Dictionary = f.enemy_list[1]

	# Assert each entry has exactly the 2 expected keys
	assert_int(first_entry.size()).is_equal(2)
	assert_bool(first_entry.has("enemy_id")).is_true()
	assert_bool(first_entry.has("count")).is_true()

	# Assert value types match contract: enemy_id is String, count is int
	assert_str(first_entry["enemy_id"]).is_equal("hollow_brute")
	assert_int(first_entry["count"]).is_equal(3)

	# Assert second entry is independent
	assert_str(second_entry["enemy_id"]).is_equal("bog_caster")
	assert_int(second_entry["count"]).is_equal(2)

	assert_int(second_entry.size()).is_equal(2)


func test_floor_enemy_list_empty_is_valid_at_schema_level() -> void:
	# Arrange / Act — empty list is a valid authoring state (Story 004 validates non-empty)
	var f: Floor = FloorScript.new()

	# Assert default is empty array — no nil, no crash
	assert_object(f.enemy_list).is_not_null()
	assert_int(f.enemy_list.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC: Nested resource composition — Biome → Dungeon → Floor round-trip
# ---------------------------------------------------------------------------

func test_biome_dungeon_floor_nested_access_returns_correct_instance() -> void:
	# Arrange — build a minimal nested hierarchy in memory
	var inner_floor: Floor = FloorScript.new()
	inner_floor.floor_index = 0

	var inner_dungeon: Dungeon = DungeonScript.new()
	inner_dungeon.floors = [inner_floor]

	var biome: Biome = BiomeScript.new()
	biome.dungeons = [inner_dungeon]

	# Act — traverse the full chain
	var retrieved_floor: Floor = biome.dungeons[0].floors[0]

	# Assert — same instance returned (resource identity preserved)
	assert_object(retrieved_floor).is_not_null()
	assert_bool(retrieved_floor is Floor).is_true()
	assert_bool(retrieved_floor == inner_floor).is_true()
	assert_int(retrieved_floor.floor_index).is_equal(0)


func test_biome_dungeon_floor_empty_arrays_handled_gracefully() -> void:
	# Arrange — all arrays empty (deepest valid authoring state)
	var biome: Biome = BiomeScript.new()

	# Act / Assert — array access on empty containers does not panic
	assert_int(biome.dungeons.size()).is_equal(0)

	var dungeon: Dungeon = DungeonScript.new()
	assert_int(dungeon.floors.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC: Defaults — is_boss_floor and status
# ---------------------------------------------------------------------------

func test_floor_is_boss_floor_defaults_false() -> void:
	# Arrange / Act
	var f: Floor = FloorScript.new()

	# Assert — must default false per ADR-0011 + acceptance criteria
	assert_bool(f.is_boss_floor).is_false()


func test_biome_status_defaults_active() -> void:
	# Arrange / Act
	var b: Biome = BiomeScript.new()

	# Assert — must default "active" per ADR-0011 + acceptance criteria
	assert_str(b.status).is_equal("active")


# ---------------------------------------------------------------------------
# AC: Inherited id and display_name default to empty string
# ---------------------------------------------------------------------------

func test_all_three_types_inherit_id_and_display_name_defaulting_empty() -> void:
	# Arrange
	var b: Biome = BiomeScript.new()
	var d: Dungeon = DungeonScript.new()
	var f: Floor = FloorScript.new()

	# Assert — GameData contract: both inherited fields default to ""
	assert_str(b.id).is_equal("")
	assert_str(b.display_name).is_equal("")

	assert_str(d.id).is_equal("")
	assert_str(d.display_name).is_equal("")

	assert_str(f.id).is_equal("")
	assert_str(f.display_name).is_equal("")
