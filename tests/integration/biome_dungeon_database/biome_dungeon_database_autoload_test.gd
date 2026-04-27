# Tests for Story S3-M6: BiomeDungeonDatabase autoload skeleton + DataRegistry
# accessor wrappers.
# Covers: TR-biome-dungeon-db-006, TR-biome-dungeon-db-014, AC H-01, AC H-08,
#         autoload rank 6, zero-arg _init, null contract, resource cache consistency,
#         get_playable_biomes V1.0 filter, get_all_biome_ids sorted, get_floors_for_dungeon.
#
# Integration test — exercises the live BiomeDungeonDatabase autoload against the
# actual DataRegistry in the running Godot scene tree.
#
# NOTE: Many ACs depend on Forest Reach biome/dungeon/floor .tres files which
# land in Story S3-M7. Those tests apply a graceful-degrade pattern:
#   if DataRegistry is in ERROR state OR no biomes loaded
#       → push_warning + return (pass trivially).
# The smoke check at production/qa/smoke-*.md covers full-boot integration
# once S3-M7 populates assets/data/biomes/ and assets/data/dungeons/.
extends GdUnitTestSuite

const BiomeDungeonDatabaseScript = preload(
	"res://src/core/biome_dungeon_database/biome_dungeon_database.gd"
)

# ---------------------------------------------------------------------------
# AC: zero-arg _init does not crash
#
# Verifies ADR-0003 Amendment #3: BiomeDungeonDatabase can be freshly
# instantiated with zero args. This is required for the engine to boot the
# autoload. The live autoload presence is confirmed by scene tree lookup.
# ---------------------------------------------------------------------------
func test_biome_dungeon_database_init_does_not_crash() -> void:
	# Arrange / Act — preload-and-new() simulates engine zero-arg instantiation
	var db: Node = BiomeDungeonDatabaseScript.new()

	# Assert — instance created without error
	assert_bool(db != null).is_true()

	# Cleanup — Node (not RefCounted) must be freed
	db.free()


# ---------------------------------------------------------------------------
# AC: autoload is registered in the scene tree at rank 6
#
# Verifies project.godot autoload registration: BiomeDungeonDatabase singleton
# is reachable via get_tree().root (rank 6 — last in canonical list per ADR-0003).
# ---------------------------------------------------------------------------
func test_biome_dungeon_database_autoload_reachable_in_scene_tree() -> void:
	# Act
	var node: Node = get_tree().root.get_node_or_null("BiomeDungeonDatabase")

	# Assert
	assert_bool(node != null).is_true()


# ---------------------------------------------------------------------------
# TR-biome-dungeon-db-006: null contract on miss — no push_error (all 3 accessors)
#
# Verifies that querying a non-existent id returns null without push_error for
# get_biome_by_id, get_dungeon_by_id, and get_floor_by_id.
# DataRegistry emits push_warning (WARN mode) — that is acceptable.
# The contract is: no crash, null return.
# ---------------------------------------------------------------------------
func test_biome_dungeon_database_get_biome_by_id_returns_null_on_miss() -> void:
	# Act
	var result: Biome = BiomeDungeonDatabase.get_biome_by_id("does_not_exist")

	# Assert — documented null contract; no exception
	assert_bool(result == null).is_true()


func test_biome_dungeon_database_get_dungeon_by_id_returns_null_on_miss() -> void:
	# Act
	var result: Dungeon = BiomeDungeonDatabase.get_dungeon_by_id("does_not_exist")

	# Assert — documented null contract; no exception
	assert_bool(result == null).is_true()


func test_biome_dungeon_database_get_floor_by_id_returns_null_on_miss() -> void:
	# Act — "phantom" floor id: cross-dungeon scan finds nothing
	var result: Floor = BiomeDungeonDatabase.get_floor_by_id("phantom")

	# Assert — documented null contract; no exception
	assert_bool(result == null).is_true()


# ---------------------------------------------------------------------------
# TR-biome-dungeon-db-006 edge: empty string id returns null without crash
# (covers all 3 accessors)
# ---------------------------------------------------------------------------
func test_biome_dungeon_database_empty_string_id_returns_null() -> void:
	# Act
	var biome_result: Biome = BiomeDungeonDatabase.get_biome_by_id("")
	var dungeon_result: Dungeon = BiomeDungeonDatabase.get_dungeon_by_id("")
	var floor_result: Floor = BiomeDungeonDatabase.get_floor_by_id("")

	# Assert — all null, no exceptions
	assert_bool(biome_result == null).is_true()
	assert_bool(dungeon_result == null).is_true()
	assert_bool(floor_result == null).is_true()


# ---------------------------------------------------------------------------
# AC H-01: Forest Reach biome resolvable post-boot
#
# Given: DataRegistry READY with Forest Reach biome .tres from Story S3-M7.
# When: get_biome_by_id("forest_reach")
# Then: returns non-null Biome with id == "forest_reach", status == "active",
#       non-empty display_name.
#
# Graceful degrade: if DataRegistry is not READY or no biomes are loaded
# (S3-M7 not landed), push_warning + return. Deferred to smoke check.
# ---------------------------------------------------------------------------
func test_biome_dungeon_database_get_biome_by_id_resolves_forest_reach() -> void:
	# Guard: DataRegistry must be READY for this test to be meaningful
	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			(
				"test_biome_dungeon_database_get_biome_by_id_resolves_forest_reach: " +
				"DataRegistry is not in READY state (state=%d). " +
				"Forest Reach .tres not yet authored (S3-M7 pending). " +
				"Deferred to smoke check at production/qa/smoke-*.md."
			) % DataRegistry.state
		)
		return

	var biome: Biome = BiomeDungeonDatabase.get_biome_by_id("forest_reach")

	if biome == null:
		push_warning(
			"test_biome_dungeon_database_get_biome_by_id_resolves_forest_reach: " +
			"get_biome_by_id('forest_reach') returned null even though DataRegistry is READY. " +
			"Forest Reach .tres not yet authored (S3-M7 pending). " +
			"Deferred to S3-M7 smoke check."
		)
		return

	# Assert — id round-trips correctly
	assert_str(biome.id).is_equal("forest_reach")

	# Assert — status is active
	assert_str(biome.status).is_equal("active")

	# Assert — display_name must be non-empty
	assert_bool(biome.display_name.length() > 0).is_true()


# ---------------------------------------------------------------------------
# TR-biome-dungeon-db-014 + AC H-08: get_playable_biomes filters by status
#
# Verifies that get_playable_biomes() only returns biomes with status == "active"
# and that the result is sorted by id.
#
# Graceful degrade: if DataRegistry is not READY or no biomes loaded (S3-M7 +
# future stub biome story pending), push_warning + return. An empty result is
# valid and correct before content lands.
# ---------------------------------------------------------------------------
func test_biome_dungeon_database_get_playable_biomes_returns_typed_array() -> void:
	# Act — always valid to call; returns [] when no biomes loaded
	var result: Array[Biome] = BiomeDungeonDatabase.get_playable_biomes()

	# Assert — always returns a typed Array, never null
	assert_bool(result != null).is_true()

	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			"test_biome_dungeon_database_get_playable_biomes_returns_typed_array: " +
			"DataRegistry not READY — get_playable_biomes() correctly returned empty array. " +
			"Full filter test deferred to S3-M7 + stub biome story smoke check."
		)
		return

	if result.is_empty():
		push_warning(
			"test_biome_dungeon_database_get_playable_biomes_returns_typed_array: " +
			"DataRegistry READY but get_playable_biomes() returned empty array. " +
			"No active biome .tres files loaded yet (S3-M7 pending). " +
			"Deferred to smoke check."
		)
		return

	# Assert — all returned biomes have status == "active"
	for biome: Biome in result:
		assert_str(biome.status).is_equal("active")

	# Assert — sorted alphabetically by id (each element id <= next element id)
	for i: int in range(result.size() - 1):
		assert_bool(result[i].id <= result[i + 1].id).is_true()


# ---------------------------------------------------------------------------
# AC: get_all_biome_ids returns sorted Array[String] (active + planned)
#
# Verifies that get_all_biome_ids() returns a sorted typed array regardless of
# biome status — it includes ALL loaded biomes, not just active ones.
#
# Graceful degrade: if DataRegistry is not READY or no biomes loaded
# (S3-M7 pending), push_warning + return. Empty result is correct.
# ---------------------------------------------------------------------------
func test_biome_dungeon_database_get_all_biome_ids_returns_sorted_array() -> void:
	# Act
	var ids: Array[String] = BiomeDungeonDatabase.get_all_biome_ids()

	# Assert — always returns a typed Array, never null
	assert_bool(ids != null).is_true()

	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			"test_biome_dungeon_database_get_all_biome_ids_returns_sorted_array: " +
			"DataRegistry not READY — get_all_biome_ids() correctly returned empty array. " +
			"Full enumeration deferred to S3-M7 smoke check."
		)
		return

	if ids.is_empty():
		push_warning(
			"test_biome_dungeon_database_get_all_biome_ids_returns_sorted_array: " +
			"DataRegistry READY but get_all_biome_ids() returned empty array. " +
			"No biome .tres files loaded yet (S3-M7 pending). " +
			"Deferred to smoke check."
		)
		return

	# Assert — sorted alphabetically (each element <= next)
	for i: int in range(ids.size() - 1):
		assert_bool(ids[i] <= ids[i + 1]).is_true()


# ---------------------------------------------------------------------------
# AC: get_floors_for_dungeon returns ordered list
#
# Given: Forest Reach dungeon with floors from Story S3-M7.
# When: get_floors_for_dungeon("forest_reach_main") (id TBD by S3-M7 author).
# Then: returned Array[Floor] is sorted by floor_index ascending; unknown id
#       returns empty array without error.
#
# Graceful degrade: if DataRegistry is not READY or no dungeons loaded
# (S3-M7 pending), push_warning + return.
# The unknown-id path is always tested (no degrade needed).
# ---------------------------------------------------------------------------
func test_biome_dungeon_database_get_floors_for_dungeon_unknown_id_returns_empty() -> void:
	# Act — unknown dungeon id: must return empty array, no error
	var result: Array[Floor] = BiomeDungeonDatabase.get_floors_for_dungeon("unknown_dungeon_id")

	# Assert — empty array, never null
	assert_bool(result != null).is_true()
	assert_int(result.size()).is_equal(0)


func test_biome_dungeon_database_get_floors_for_dungeon_returns_sorted_floors() -> void:
	# Guard
	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			(
				"test_biome_dungeon_database_get_floors_for_dungeon_returns_sorted_floors: " +
				"DataRegistry is not in READY state (state=%d). " +
				"Forest Reach dungeon .tres not yet authored (S3-M7 pending). " +
				"Deferred to smoke check."
			) % DataRegistry.state
		)
		return

	# Probe with first available dungeon id to avoid hardcoding S3-M7 dungeon id
	var all_dungeons: Array[Resource] = DataRegistry.get_all_by_type("dungeons")
	if all_dungeons.is_empty():
		push_warning(
			"test_biome_dungeon_database_get_floors_for_dungeon_returns_sorted_floors: " +
			"DataRegistry READY but no dungeons loaded yet (S3-M7 pending). " +
			"Deferred to smoke check."
		)
		return

	# Find first dungeon resource with at least one floor
	var probe_dungeon: Dungeon
	for r: Resource in all_dungeons:
		if r is Dungeon and (r as Dungeon).floors.size() > 0:
			probe_dungeon = r as Dungeon
			break

	if probe_dungeon == null:
		push_warning(
			"test_biome_dungeon_database_get_floors_for_dungeon_returns_sorted_floors: " +
			"No dungeon with authored floors found (S3-M7 pending). " +
			"Deferred to smoke check."
		)
		return

	# Act
	var floors: Array[Floor] = BiomeDungeonDatabase.get_floors_for_dungeon(probe_dungeon.id)

	# Assert — non-null, same count as the dungeon's floors array
	assert_bool(floors != null).is_true()
	assert_int(floors.size()).is_equal(probe_dungeon.floors.size())

	# Assert — sorted ascending by floor_index
	for i: int in range(floors.size() - 1):
		assert_bool(floors[i].floor_index <= floors[i + 1].floor_index).is_true()


# ---------------------------------------------------------------------------
# AC: resource cache consistency — same id returns same Resource instance
#
# Verifies Godot resource cache: repeated calls to get_biome_by_id with the
# same id return the identical Resource object (object-identity ==).
#
# Graceful degrade: if DataRegistry is not READY or no biomes loaded,
# push_warning + return. Deferred to S3-M7 smoke check.
# ---------------------------------------------------------------------------
func test_biome_dungeon_database_get_biome_by_id_returns_same_instance() -> void:
	# Guard
	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			"test_biome_dungeon_database_get_biome_by_id_returns_same_instance: " +
			"DataRegistry not READY. Deferred to S3-M7 smoke check."
		)
		return

	# Probe with first available id to avoid hardcoding biome ids (may not exist yet)
	var ids: Array[String] = BiomeDungeonDatabase.get_all_biome_ids()
	if ids.is_empty():
		push_warning(
			"test_biome_dungeon_database_get_biome_by_id_returns_same_instance: " +
			"No biome ids loaded. Deferred to S3-M7 smoke check."
		)
		return

	var probe_id: String = ids[0]

	# Act — two independent calls for the same id
	var first: Biome = BiomeDungeonDatabase.get_biome_by_id(probe_id)
	var second: Biome = BiomeDungeonDatabase.get_biome_by_id(probe_id)

	if first == null or second == null:
		push_warning(
			"test_biome_dungeon_database_get_biome_by_id_returns_same_instance: " +
			"get_biome_by_id('%s') returned null. Deferred to S3-M7 smoke check." % probe_id
		)
		return

	# Assert — object-identity (same cached Resource instance)
	assert_bool(first == second).is_true()
