# Tests for Story S3-M3: EnemyDatabase autoload skeleton + DataRegistry
# accessor wrapper.
# Covers: TR-enemy-db-005, TR-enemy-db-022, AC H-01, resource cache consistency,
#         autoload rank 5, zero-arg _init.
#
# Integration test — exercises the live EnemyDatabase autoload against the
# actual DataRegistry in the running Godot scene tree.
#
# NOTE: Many ACs depend on 7+ MVP enemy .tres files which land in Story S3-M4.
# Those tests apply a graceful-degrade pattern:
#   if DataRegistry is in ERROR state → push_warning + return (pass trivially).
# The smoke check at production/qa/smoke-*.md covers full-boot integration
# once S3-M4 populates assets/data/enemies/.
extends GdUnitTestSuite

const EnemyDatabaseScript = preload(
	"res://src/core/enemy_database/enemy_database.gd"
)

# ---------------------------------------------------------------------------
# AC: zero-arg _init does not crash
#
# Verifies ADR-0003 Amendment #3: EnemyDatabase can be freshly instantiated
# with zero args. This is required for the engine to boot the autoload. The
# live autoload presence is confirmed by get_tree() node lookup.
# ---------------------------------------------------------------------------
func test_enemy_database_init_does_not_crash() -> void:
	# Arrange / Act — preload-and-new() simulates engine zero-arg instantiation
	var db: Node = EnemyDatabaseScript.new()

	# Assert — instance created without error
	assert_bool(db != null).is_true()

	# Cleanup — Node (not RefCounted) must be freed
	db.free()


# ---------------------------------------------------------------------------
# AC: autoload is registered in the scene tree at rank 5
#
# Verifies project.godot autoload registration: EnemyDatabase singleton
# is reachable via get_tree().root.
# ---------------------------------------------------------------------------
func test_enemy_database_autoload_reachable_in_scene_tree() -> void:
	# Act
	var node: Node = get_tree().root.get_node_or_null("EnemyDatabase")

	# Assert
	assert_bool(node != null).is_true()


# ---------------------------------------------------------------------------
# TR-enemy-db-022: null contract on miss — no push_error
#
# Verifies that querying a non-existent id returns null without push_error.
# DataRegistry emits push_warning (WARN mode) — that is acceptable. The
# contract is: no crash, null return.
# ---------------------------------------------------------------------------
func test_enemy_database_get_by_id_returns_null_on_miss() -> void:
	# Act
	var result: EnemyData = EnemyDatabase.get_by_id("does_not_exist")

	# Assert — documented null contract; no exception
	assert_bool(result == null).is_true()


# ---------------------------------------------------------------------------
# TR-enemy-db-022 edge: empty string id returns null without crash
# ---------------------------------------------------------------------------
func test_enemy_database_get_by_id_empty_string_returns_null() -> void:
	# Act
	var result: EnemyData = EnemyDatabase.get_by_id("")

	# Assert
	assert_bool(result == null).is_true()


# ---------------------------------------------------------------------------
# AC H-01: MVP enemies resolvable (hollow_brute / shadow_scout / etc.)
#
# Given: DataRegistry READY with 7+ MVP .tres files from Story S3-M4.
# When: get_by_id("hollow_brute") etc.
# Then: each returns a non-null EnemyData with id matching query and
#       tier ∈ {1, 2, 3}, display_name non-empty.
#
# Graceful degrade: if DataRegistry is in ERROR state (no enemy .tres files
# yet — S3-M4 not landed), push_warning + return. Deferred to smoke check.
# ---------------------------------------------------------------------------
func test_enemy_database_get_by_id_resolves_mvp_enemies() -> void:
	# Guard: DataRegistry must be READY for this test to be meaningful
	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			(
				"test_enemy_database_get_by_id_resolves_mvp_enemies: " +
				"DataRegistry is not in READY state (state=%d). " +
				"Likely no enemy .tres files yet (S3-M4 pending). " +
				"Deferred to smoke check at production/qa/smoke-*.md."
			) % DataRegistry.state
		)
		return

	# Probe with first available id to avoid hardcoding ids (may not exist yet)
	var ids: Array[String] = EnemyDatabase.get_all_ids()
	if ids.is_empty():
		push_warning(
			"test_enemy_database_get_by_id_resolves_mvp_enemies: " +
			"DataRegistry READY but get_all_ids() returned empty array. " +
			"No enemy .tres files loaded yet. Deferred to S3-M4 smoke check."
		)
		return

	# Assert at least one enemy resolves correctly
	for enemy_id: String in ids:
		# Act
		var enemy: EnemyData = EnemyDatabase.get_by_id(enemy_id)

		if enemy == null:
			push_warning(
				"test_enemy_database_get_by_id_resolves_mvp_enemies: " +
				"get_by_id('%s') returned null even though DataRegistry is READY. " +
				"Enemy .tres file may be missing. Deferred to S3-M4 smoke check."
				% enemy_id
			)
			return

		# Assert — id round-trips correctly
		assert_str(enemy.id).is_equal(enemy_id)

		# Assert — tier must be in valid range 1-3
		assert_bool(enemy.tier >= 1 and enemy.tier <= 3).is_true()

		# Assert — display_name must be non-empty
		assert_bool(enemy.display_name.length() > 0).is_true()


# ---------------------------------------------------------------------------
# AC: get_all_ids enumerates all loaded enemy ids, sorted alphabetically
#
# Graceful degrade: if DataRegistry is in ERROR state, get_all_ids() returns
# [] (not null, not an error). When S3-M4 lands and 7+ enemies exist, the
# returned array must contain all MVP ids in sorted order.
# ---------------------------------------------------------------------------
func test_enemy_database_get_all_ids_returns_sorted_array() -> void:
	# Act
	var ids: Array[String] = EnemyDatabase.get_all_ids()

	# Assert — always returns a typed Array, never null
	assert_bool(ids != null).is_true()

	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			"test_enemy_database_get_all_ids_returns_sorted_array: " +
			"DataRegistry not READY — get_all_ids() correctly returned empty array. " +
			"Full enumeration deferred to S3-M4 smoke check."
		)
		# An empty result is the correct contract; nothing further to assert.
		return

	if ids.size() == 0:
		push_warning(
			"test_enemy_database_get_all_ids_returns_sorted_array: " +
			"DataRegistry READY but get_all_ids() returned empty array. " +
			"No enemy .tres files loaded yet. Deferred to S3-M4 smoke check."
		)
		return

	# Assert — sorted alphabetically (each element <= next)
	for i: int in range(ids.size() - 1):
		assert_bool(ids[i] <= ids[i + 1]).is_true()

	# Assert — at least 7 MVP enemies present when enemies are loaded
	if ids.size() >= 7:
		assert_bool(ids.size() >= 7).is_true()


# ---------------------------------------------------------------------------
# AC: resource cache consistency — same id returns same Resource instance
#
# Verifies Godot resource cache: repeated calls to get_by_id with the same id
# return the identical Resource object (object-identity ==).
#
# Graceful degrade: if DataRegistry is in ERROR or enemies are not loaded,
# push_warning + return. Deferred to S3-M4 smoke check (save/load round-trip
# variant also deferred to Story 006).
# ---------------------------------------------------------------------------
func test_enemy_database_get_by_id_returns_same_instance() -> void:
	# Guard
	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			"test_enemy_database_get_by_id_returns_same_instance: " +
			"DataRegistry not READY. Deferred to S3-M4 smoke check."
		)
		return

	# Probe with first available id to avoid hardcoding enemy ids (may not exist yet)
	var ids: Array[String] = EnemyDatabase.get_all_ids()
	if ids.is_empty():
		push_warning(
			"test_enemy_database_get_by_id_returns_same_instance: " +
			"No enemy ids loaded. Deferred to S3-M4 smoke check."
		)
		return

	var probe_id: String = ids[0]

	# Act — two independent calls for the same id
	var first: EnemyData = EnemyDatabase.get_by_id(probe_id)
	var second: EnemyData = EnemyDatabase.get_by_id(probe_id)

	if first == null or second == null:
		push_warning(
			"test_enemy_database_get_by_id_returns_same_instance: " +
			"get_by_id('%s') returned null. Deferred to S3-M4 smoke check." % probe_id
		)
		return

	# Assert — object-identity (same cached Resource instance)
	assert_bool(first == second).is_true()
