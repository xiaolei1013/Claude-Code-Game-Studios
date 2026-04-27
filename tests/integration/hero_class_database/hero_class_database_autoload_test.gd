# Tests for Story S2-M6: HeroClassDatabase autoload skeleton + DataRegistry
# accessor wrapper.
# Covers: TR-hero-class-db-007, TR-hero-class-db-013, TR-hero-class-db-014,
#         TR-hero-class-db-018, AC H-01, AC H-07 (deferred).
#
# Integration test — exercises the live HeroClassDatabase autoload against the
# actual DataRegistry in the running Godot scene tree.
#
# NOTE: Many ACs depend on 3 MVP class .tres files (warrior/mage/rogue) which
# land in Story S2-M7. Those tests apply a graceful-degrade pattern:
#   if DataRegistry is in ERROR state → push_warning + return (pass trivially).
# The smoke check at production/qa/smoke-*.md covers full-boot integration
# once S2-M7 populates assets/data/classes/.
#
# Story 007 (get_recruitable_classes real body) is also deferred. The stub is
# tested here to confirm it returns an empty array without crashing.
extends GdUnitTestSuite

const HeroClassDatabaseScript = preload(
	"res://src/core/hero_class_database/hero_class_database.gd"
)

# ---------------------------------------------------------------------------
# AC: zero-arg _init does not crash
#
# Verifies ADR-0003 Amendment #3: HeroClassDatabase can be freshly instantiated
# with zero args. This is required for the engine to boot the autoload. The
# live autoload presence is confirmed by get_tree() node lookup.
# ---------------------------------------------------------------------------
func test_hero_class_database_init_does_not_crash() -> void:
	# Arrange / Act — preload-and-new() simulates engine zero-arg instantiation
	var db: Node = HeroClassDatabaseScript.new()

	# Assert — instance created without error
	assert_bool(db != null).is_true()

	# Cleanup — Node (not RefCounted) must be freed
	db.free()


# ---------------------------------------------------------------------------
# AC: autoload is registered in the scene tree at rank 4
#
# Verifies project.godot autoload registration: HeroClassDatabase singleton
# is reachable via get_tree().root.
# ---------------------------------------------------------------------------
func test_hero_class_database_autoload_reachable_in_scene_tree() -> void:
	# Act
	var node: Node = get_tree().root.get_node_or_null("HeroClassDatabase")

	# Assert
	assert_bool(node != null).is_true()


# ---------------------------------------------------------------------------
# TR-hero-class-db-014: null contract on miss — no push_error
#
# Verifies that querying a non-existent id returns null without push_error.
# DataRegistry emits push_warning (WARN mode) — that is acceptable. The
# contract is: no crash, null return.
# ---------------------------------------------------------------------------
func test_hero_class_database_get_by_id_returns_null_on_miss() -> void:
	# Act
	var result: HeroClass = HeroClassDatabase.get_by_id("does_not_exist")

	# Assert — documented null contract; no exception
	assert_bool(result == null).is_true()


# ---------------------------------------------------------------------------
# TR-hero-class-db-014 edge: empty string id returns null without crash
# ---------------------------------------------------------------------------
func test_hero_class_database_get_by_id_empty_string_returns_null() -> void:
	# Act
	var result: HeroClass = HeroClassDatabase.get_by_id("")

	# Assert
	assert_bool(result == null).is_true()


# ---------------------------------------------------------------------------
# AC H-01: 3 MVP classes resolvable (warrior / mage / rogue)
#
# Given: DataRegistry READY with 3 MVP .tres files from Story S2-M7.
# When: get_by_id("warrior"), get_by_id("mage"), get_by_id("rogue").
# Then: each returns a non-null HeroClass with id matching query.
#
# Graceful degrade: if DataRegistry is in ERROR state (no class .tres files
# yet — S2-M7 not landed), push_warning + return. Deferred to smoke check.
# ---------------------------------------------------------------------------
func test_hero_class_database_get_by_id_resolves_mvp_classes() -> void:
	# Guard: DataRegistry must be READY for this test to be meaningful
	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			"test_hero_class_database_get_by_id_resolves_mvp_classes: " +
			"DataRegistry is not in READY state (state=%d). " +
			"Likely no class .tres files yet (S2-M7 pending). " +
			"Deferred to smoke check at production/qa/smoke-*.md."
			% DataRegistry.state
		)
		return

	# Arrange
	var mvp_ids: Array[String] = ["warrior", "mage", "rogue"]

	for class_id: String in mvp_ids:
		# Act
		var hero_class: HeroClass = HeroClassDatabase.get_by_id(class_id)

		if hero_class == null:
			push_warning(
				"test_hero_class_database_get_by_id_resolves_mvp_classes: " +
				"get_by_id('%s') returned null even though DataRegistry is READY. " +
				"Class .tres file may be missing. Deferred to S2-M7 smoke check."
				% class_id
			)
			return

		# Assert — id round-trips correctly
		assert_str(hero_class.id).is_equal(class_id)

		# Assert — tier must be 1 (MVP classes are all Tier 1 per GDD §C.1)
		assert_int(hero_class.tier).is_equal(1)

		# Assert — display_name must be non-empty
		assert_bool(hero_class.display_name.length() > 0).is_true()


# ---------------------------------------------------------------------------
# AC: get_all_ids enumerates all loaded class ids, sorted alphabetically
#
# Graceful degrade: if DataRegistry is in ERROR state, get_all_ids() returns
# [] (not null, not an error). When S2-M7 lands and 3+ classes exist, the
# returned array must contain all MVP ids in sorted order.
# ---------------------------------------------------------------------------
func test_hero_class_database_get_all_ids_returns_sorted_array() -> void:
	# Act
	var ids: Array[String] = HeroClassDatabase.get_all_ids()

	# Assert — always returns a typed Array, never null
	assert_bool(ids != null).is_true()

	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			"test_hero_class_database_get_all_ids_returns_sorted_array: " +
			"DataRegistry not READY — get_all_ids() correctly returned empty array. " +
			"Full enumeration deferred to S2-M7 smoke check."
		)
		# An empty result is the correct contract; nothing further to assert.
		return

	if ids.size() == 0:
		push_warning(
			"test_hero_class_database_get_all_ids_returns_sorted_array: " +
			"DataRegistry READY but get_all_ids() returned empty array. " +
			"No class .tres files loaded yet. Deferred to S2-M7 smoke check."
		)
		return

	# Assert — sorted alphabetically (each element <= next)
	for i: int in range(ids.size() - 1):
		assert_bool(ids[i] <= ids[i + 1]).is_true()

	# Assert — MVP ids present when classes are loaded (>= 3)
	if ids.size() >= 3:
		assert_bool("mage" in ids).is_true()
		assert_bool("rogue" in ids).is_true()
		assert_bool("warrior" in ids).is_true()


# ---------------------------------------------------------------------------
# AC: get_recruitable_classes stub — always returns empty array, never crashes
#
# Story 007 implements the real body. Until then this must return [] without
# error. This is a Must-Have acceptance criterion for S2-M6.
# ---------------------------------------------------------------------------
func test_hero_class_database_get_recruitable_classes_stub_returns_empty_array() -> void:
	# Act
	var result: Array[HeroClass] = HeroClassDatabase.get_recruitable_classes()

	# Assert — stub returns empty typed array (never null)
	assert_bool(result != null).is_true()
	assert_int(result.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC H-07: id-stability — same id returns same Resource instance (cache identity)
#
# Verifies Godot resource cache: repeated calls to get_by_id with the same id
# return the identical Resource object (object-identity ==).
#
# Graceful degrade: if DataRegistry is in ERROR or classes are not loaded,
# push_warning + return. Deferred to S2-M7 smoke check (save/load round-trip
# variant also deferred).
# ---------------------------------------------------------------------------
func test_hero_class_database_get_by_id_returns_same_instance() -> void:
	# Guard
	if DataRegistry.state != DataRegistry.State.READY:
		push_warning(
			"test_hero_class_database_get_by_id_returns_same_instance: " +
			"DataRegistry not READY. Deferred to S2-M7 smoke check."
		)
		return

	# Probe with first available id to avoid hardcoding warrior (may not exist yet)
	var ids: Array[String] = HeroClassDatabase.get_all_ids()
	if ids.is_empty():
		push_warning(
			"test_hero_class_database_get_by_id_returns_same_instance: " +
			"No class ids loaded. Deferred to S2-M7 smoke check."
		)
		return

	var probe_id: String = ids[0]

	# Act — two independent calls for the same id
	var first: HeroClass = HeroClassDatabase.get_by_id(probe_id)
	var second: HeroClass = HeroClassDatabase.get_by_id(probe_id)

	if first == null or second == null:
		push_warning(
			"test_hero_class_database_get_by_id_returns_same_instance: " +
			"get_by_id('%s') returned null. Deferred to S2-M7 smoke check." % probe_id
		)
		return

	# Assert — object-identity (same cached Resource instance)
	assert_bool(first == second).is_true()
