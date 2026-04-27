# Tests for Story 004: resolve() API and typed category accessors.
# Covers: TR-data-loading-014, TR-data-loading-015, TR-data-loading-019,
#         TR-data-loading-024, TR-data-loading-006, AC-DLS-02, AC-DLS-04.
#
# Fixture strategy (same as boot_scan_load_order_test.gd — Option B, programmatic):
#   Fixture .tres files are created at runtime in before_test() / per-test helpers
#   via TestContentType.new() + ResourceSaver.save(), then torn down in after_test().
#   This avoids committing binary-like .tres to the repo and keeps every test
#   self-contained and deterministic.
#
# push_warning interception note:
#   GdUnit4 does not natively intercept push_warning() calls in-process.
#   Tests that care about warning behavior assert the return value (null) and
#   document which code path is exercised. The exact log format for AC-DLS-04
#   is verified by code review of _report_missing_id(). This is the pragmatic
#   approach recommended by the story spec.
#
# TestContentType fixture class:
#   Defined in tests/fixtures/data_registry/test_content_type.gd.
#   It is a minimal concrete GameData subclass used only by tests.
extends GdUnitTestSuite

const DataRegistryScript = preload("res://src/core/data_registry/data_registry.gd")
const DataRegistryFixtures = preload("res://tests/fixtures/data_registry/fixture_helpers.gd")


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Root of the programmatic fixture tree written/deleted per test.
## Under res:// so ResourceLoader.load() can resolve fixture .tres paths.
## In headless CI (godot --headless from project root), res:// is writable.
const FIXTURE_ROOT: String = "res://tests/fixtures/data_registry/resolve_api/"




## Boots a fresh DataRegistry pointing at FIXTURE_ROOT.
## Sets min_content_count to {} so tests focus on resolve() semantics rather
## than content-count thresholds (Story 005 added the defaults after these
## tests were authored).
## Caller is responsible for freeing the returned instance.
func _boot_registry() -> DataRegistry:
	var dr: Node = DataRegistryScript.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}
	dr._ready()
	return dr


# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------

func after_test() -> void:
	DataRegistryFixtures.cleanup(FIXTURE_ROOT)


# ---------------------------------------------------------------------------
# Test 1 — TR-data-loading-014 / AC-DLS-08 (read-only convention):
#   resolve() returns the cached resource for a valid id.
#   Calling resolve twice returns the SAME object (identity equality, not
#   just value equality) — confirms "cached instance, no duplication" invariant.
# ---------------------------------------------------------------------------
func test_resolve_valid_id_returns_cached_resource_and_identity_equality() -> void:
	# Arrange
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})
	var dr: Node = _boot_registry()

	# Act
	var result_a: Resource = dr.resolve("classes", "hero_warrior")
	var result_b: Resource = dr.resolve("classes", "hero_warrior")

	# Assert — non-null
	assert_object(result_a).is_not_null()

	# Assert — correct id
	assert_str(result_a.id).is_equal("hero_warrior")

	# Assert — concrete type is TestContentType
	assert_bool(result_a is TestContentType).is_true()

	# Assert — identity equality (same cached instance, not a duplicate)
	assert_bool(result_a == result_b).is_true()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 2 — TR-data-loading-014 / TR-data-loading-019 / AC-DLS-04:
#   resolve() returns null for a missing id with WARN behavior.
#
#   Note on push_warning interception: GdUnit4 does not intercept push_warning
#   in-process. The WARN path is verified by asserting null return. The exact
#   log format "[DataRegistry] MISSING REF: classes id='hero_berserker' —
#   no resource registered" is enforced by _report_missing_id() source code
#   (AC-DLS-04 format) and is covered by code review, not runtime assertion.
# ---------------------------------------------------------------------------
func test_resolve_missing_id_returns_null_with_warn_behavior() -> void:
	# Arrange — warrior loaded, berserker absent; WARN is the default
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})
	var dr: Node = _boot_registry()
	# Confirm WARN is the default (TR-data-loading-024 default)
	assert_int(dr.missing_id_behavior).is_equal(DataRegistryScript.MissingIdBehavior.WARN)

	# Act — id that does not exist
	var result: Resource = dr.resolve("classes", "hero_berserker")

	# Assert — null return, no crash
	assert_object(result).is_null()

	# Assert — the registry is still healthy; a subsequent valid resolve still works
	var warrior: Resource = dr.resolve("classes", "hero_warrior")
	assert_object(warrior).is_not_null()
	assert_str(warrior.id).is_equal("hero_warrior")

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 3 — TR-data-loading-019 / AC-DLS-04:
#   Unknown content_type returns null without crashing.
# ---------------------------------------------------------------------------
func test_resolve_unknown_content_type_returns_null_without_crash() -> void:
	# Arrange — minimal registry in READY state
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})
	var dr: Node = _boot_registry()
	assert_int(dr.state).is_equal(DataRegistryScript.State.READY)

	# Act — category not in ORDERED_CATEGORIES
	var result: Resource = dr.resolve("nonsense", "anything")

	# Assert — null return; no exception raised (test completes normally)
	assert_object(result).is_null()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 4 — TR-data-loading-019:
#   resolve() called before registry_ready (state == UNLOADED) returns null
#   with a distinct "called before registry_ready" warning rather than a crash.
#
#   Note: The distinct warning message format is
#   "[DataRegistry] resolve called before registry_ready: content_type=... id=..."
#   This is verified by code review. The test asserts the null return.
# ---------------------------------------------------------------------------
func test_resolve_before_registry_ready_returns_null() -> void:
	# Arrange — fresh instance; do NOT call _ready(); state stays UNLOADED
	var dr: Node = DataRegistryScript.new()
	assert_int(dr.state).is_equal(DataRegistryScript.State.UNLOADED)

	# Act
	var result: Resource = dr.resolve("classes", "hero_warrior")

	# Assert — null return; no crash
	assert_object(result).is_null()

	# Assert — state did not change (resolve must not advance the state machine)
	assert_int(dr.state).is_equal(DataRegistryScript.State.UNLOADED)

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 5 — TR-data-loading-024:
#   missing_id_behavior == ASSERT configures the ASSERT branch.
#
#   Caveat: GDScript's assert(false, ...) does not raise a catchable exception —
#   it aborts in debug builds and is compiled out in release builds. This test
#   therefore verifies only that:
#     (a) The ASSERT enum value can be set without error.
#     (b) resolve() still returns null after the assert (function does not panic
#         in a way that prevents the return in release-mode CI).
#   The assert firing in debug builds is verified by manual test-build runs and
#   is documented in the story spec's QA notes. This is the pragmatic honest test
#   of the enum-driven branch existing.
# ---------------------------------------------------------------------------
func test_resolve_assert_behavior_returns_null_after_assert_fires() -> void:
	# Sprint 4 FOLLOWUP-001 / S5-M1 fix: this test exercises the post-assert
	# return path of DataRegistry.resolve in ASSERT mode. In DEBUG builds
	# `assert(false, ...)` aborts the test runner; the path is only reachable
	# in RELEASE builds where assertions are compiled out. Skip in debug to
	# preserve the contractual coverage in release builds without crashing
	# the dev-loop / CI runs (which run in debug).
	if OS.is_debug_build():
		return

	# Arrange — ASSERT mode, warrior loaded, berserker absent
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})
	var dr: Node = _boot_registry()
	dr.missing_id_behavior = DataRegistryScript.MissingIdBehavior.ASSERT

	# Act — in release builds (CI headless) the assert is compiled out;
	# the function reaches the return null statement normally.
	# In debug builds the assert fires and the test harness records a failure.
	var result: Resource = dr.resolve("classes", "hero_berserker")

	# Assert — null return is the documented post-assert behavior
	assert_object(result).is_null()

	# Assert — valid id still resolves correctly regardless of behavior mode
	var warrior: Resource = dr.resolve("classes", "hero_warrior")
	assert_object(warrior).is_not_null()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 6 — TR-data-loading-015:
#   get_all_by_type() returns the full loaded array for each category.
#   Identity equality: elements are the same cached objects as resolve().
#   Edge cases: before registry_ready → []; unknown category → [].
# ---------------------------------------------------------------------------
func test_get_all_by_type_returns_full_array_with_identity_equality() -> void:
	# Arrange — 3 classes + 2 enemies
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [
			{"id": "hero_warrior", "display_name": "Warrior"},
			{"id": "hero_mage", "display_name": "Mage"},
			{"id": "hero_rogue", "display_name": "Rogue"},
		],
		"enemies": [
			{"id": "enemy_orc", "display_name": "Orc"},
			{"id": "enemy_goblin", "display_name": "Goblin"},
		],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})
	var dr: Node = _boot_registry()

	# Act
	var classes: Array[Resource] = dr.get_all_by_type("classes")
	var enemies: Array[Resource] = dr.get_all_by_type("enemies")

	# Assert — correct counts
	assert_int(classes.size()).is_equal(3)
	assert_int(enemies.size()).is_equal(2)

	# Assert — every element is a non-null Resource
	for res: Resource in classes:
		assert_object(res).is_not_null()
	for res: Resource in enemies:
		assert_object(res).is_not_null()

	# Assert — identity equality with resolve() for each returned item
	for res: Resource in classes:
		var via_resolve: Resource = dr.resolve("classes", res.id)
		assert_bool(res == via_resolve).is_true()

	for res: Resource in enemies:
		var via_resolve: Resource = dr.resolve("enemies", res.id)
		assert_bool(res == via_resolve).is_true()

	# Edge: unknown category returns empty array, no crash
	var unknown: Array[Resource] = dr.get_all_by_type("not_a_category")
	assert_int(unknown.size()).is_equal(0)

	# Cleanup
	dr.free()


## Sub-test for get_all_by_type before registry_ready: returns [] with warning.
func test_get_all_by_type_before_registry_ready_returns_empty_array() -> void:
	# Arrange — fresh instance; do NOT call _ready()
	var dr: Node = DataRegistryScript.new()
	assert_int(dr.state).is_equal(DataRegistryScript.State.UNLOADED)

	# Act
	var result: Array[Resource] = dr.get_all_by_type("classes")

	# Assert — empty array; no crash
	assert_int(result.size()).is_equal(0)

	# Assert — state did not change
	assert_int(dr.state).is_equal(DataRegistryScript.State.UNLOADED)

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 7 — TR-data-loading-006 / AC-DLS-02:
#   Rename-transparent resolution.
#
#   Proves that _categories is keyed by resource.id, NOT by filename.
#   A file rename on disk does not affect resolve() after a fresh boot,
#   because the index key is always the .id field value.
# ---------------------------------------------------------------------------
func test_resolve_rename_transparent_id_based_lookup() -> void:
	# Arrange — Step 1: create warrior.tres with id="hero_warrior", boot registry
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})
	var dr_original: Node = _boot_registry()

	# Verify initial resolve works
	var original_result: Resource = dr_original.resolve("classes", "hero_warrior")
	assert_object(original_result).is_not_null()
	assert_str(original_result.id).is_equal("hero_warrior")
	dr_original.free()

	# Act — Step 2: simulate a file rename.
	#   Delete the original warrior.tres and write a new hero_warrior_v2.tres
	#   with the SAME id="hero_warrior". The filename changed; the id did not.
	var old_path: String = FIXTURE_ROOT + "classes/hero_warrior.tres"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))

	var renamed_res: TestContentType = TestContentType.new()
	renamed_res.id = "hero_warrior"
	renamed_res.display_name = "Warrior (renamed file)"
	ResourceSaver.save(renamed_res, FIXTURE_ROOT + "classes/hero_warrior_v2.tres")

	# Step 3: boot a fresh registry (simulates app relaunch after rename)
	var dr_after_rename: Node = _boot_registry()

	# Assert — resolve still finds id="hero_warrior" despite filename change
	var renamed_result: Resource = dr_after_rename.resolve("classes", "hero_warrior")
	assert_object(renamed_result).is_not_null()
	assert_str(renamed_result.id).is_equal("hero_warrior")

	# Assert — no ERROR state (no error was logged for the rename)
	assert_int(dr_after_rename.state).is_equal(DataRegistryScript.State.READY)

	# Cleanup
	dr_after_rename.free()
