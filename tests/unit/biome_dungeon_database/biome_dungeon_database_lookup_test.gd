# BiomeDungeonDatabase.get_dungeon_by_id and get_floor_by_id happy-path
# coverage tests (US-028 backfill).
#
# The integration test file (tests/integration/biome_dungeon_database/
# biome_dungeon_database_autoload_test.gd) covers the documented null-on-miss
# edge contract for both functions and provides a happy-path for
# get_biome_by_id (resolves_forest_reach). It does NOT directly assert the
# non-null happy-path return for get_dungeon_by_id or get_floor_by_id —
# get_dungeon_by_id is only exercised transitively through
# get_floors_for_dungeon, and get_floor_by_id has no direct happy-path
# assertion at all. This file fills both gaps.
#
# Pattern: use the live BiomeDungeonDatabase autoload (per AudioRouter
# stop_music_test.gd precedent — autoloads are reachable from unit tests via
# get_tree().root). Probe DataRegistry for a real Dungeon / Floor id to
# avoid hardcoding S3-M7 content ids that may evolve. Graceful-degrade when
# DataRegistry is not READY or no content is loaded (matches the integration
# test's deferral contract — empty result is valid before content lands).
#
# Test groups:
#   A — Happy path: get_dungeon_by_id with a known id returns the Dungeon
#   B — Happy path: get_floor_by_id with a known id returns the Floor
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Accessor — fetch the live autoload from the scene tree (matches the
# stop_music_test.gd / audio_router pattern).
# ---------------------------------------------------------------------------
func _get_db() -> Node:
	return get_tree().root.get_node_or_null("BiomeDungeonDatabase")


# ===========================================================================
# Group A — get_dungeon_by_id happy path
# ===========================================================================

func test_get_dungeon_by_id_with_known_probe_id_returns_matching_dungeon() -> void:
	# Arrange — autoload must be reachable
	var db: Node = _get_db()
	assert_object(db).is_not_null()

	# Guard — DataRegistry must be READY for any dungeon to resolve
	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			(
				"test_get_dungeon_by_id_with_known_probe_id_returns_matching_dungeon: " +
				"DataRegistry is not READY (state=%d). Deferred to smoke check."
			) % DataRegistry.state
		)
		return

	# Probe — discover a real dungeon id from DataRegistry rather than
	# hardcoding "forest_reach_dungeon_01" so the test survives content rename.
	var all_dungeons: Array[Resource] = DataRegistry.get_all_by_type("dungeons")
	if all_dungeons.is_empty():
		push_warning(
			"test_get_dungeon_by_id_with_known_probe_id_returns_matching_dungeon: " +
			"DataRegistry READY but no dungeons loaded. Deferred to smoke check."
		)
		return

	var probe: Dungeon = null
	for r: Resource in all_dungeons:
		if r is Dungeon:
			probe = r as Dungeon
			break
	if probe == null:
		push_warning(
			"test_get_dungeon_by_id_with_known_probe_id_returns_matching_dungeon: " +
			"DataRegistry has 'dungeons' entries but none cast to Dungeon. " +
			"Deferred to smoke check."
		)
		return

	# Act
	var result: Dungeon = db.get_dungeon_by_id(probe.id)

	# Assert — non-null happy-path return, id round-trips, Dungeon lineage holds
	assert_object(result).is_not_null()
	assert_str(result.id).is_equal(probe.id)
	assert_bool(result is Dungeon).is_true()


# ===========================================================================
# Group B — get_floor_by_id happy path
# ===========================================================================

func test_get_floor_by_id_with_known_probe_id_returns_matching_floor() -> void:
	# Arrange
	var db: Node = _get_db()
	assert_object(db).is_not_null()

	# Guard
	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			(
				"test_get_floor_by_id_with_known_probe_id_returns_matching_floor: " +
				"DataRegistry is not READY (state=%d). Deferred to smoke check."
			) % DataRegistry.state
		)
		return

	# Probe — Floors are nested inside Dungeon.floors per ADR-0011, so the
	# discovery walks Dungeon resources to find the first authored Floor id.
	var all_dungeons: Array[Resource] = DataRegistry.get_all_by_type("dungeons")
	if all_dungeons.is_empty():
		push_warning(
			"test_get_floor_by_id_with_known_probe_id_returns_matching_floor: " +
			"No dungeons loaded — no Floors to probe. Deferred to smoke check."
		)
		return

	var probe_floor: Floor = null
	for r: Resource in all_dungeons:
		if not r is Dungeon:
			continue
		var d: Dungeon = r as Dungeon
		if d.floors.size() > 0:
			probe_floor = d.floors[0]
			break
	if probe_floor == null:
		push_warning(
			"test_get_floor_by_id_with_known_probe_id_returns_matching_floor: " +
			"No dungeon with authored floors found. Deferred to smoke check."
		)
		return

	# Act
	var result: Floor = db.get_floor_by_id(probe_floor.id)

	# Assert — non-null happy-path return, id round-trips, Floor lineage holds
	assert_object(result).is_not_null()
	assert_str(result.id).is_equal(probe_floor.id)
	assert_bool(result is Floor).is_true()
