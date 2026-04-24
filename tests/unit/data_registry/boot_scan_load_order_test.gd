# Tests for Story 003: Boot scan load order and per-category enumeration.
# Covers: TR-data-loading-001, TR-data-loading-002, TR-data-loading-003,
#         TR-data-loading-007, TR-data-loading-008, TR-data-loading-022,
#         TR-data-loading-025, TR-data-loading-026.
#
# Fixture strategy (Option B — programmatic):
#   Fixture .tres files are created at runtime in before_test() via
#   TestContentType.new() + ResourceSaver.save(), then torn down in after_test().
#   This avoids committing binary-like .tres files to the repo and keeps every
#   test self-contained and deterministic.
#
# Load-order instrumentation (Test 2):
#   An inner class _OrderRecordingRegistry extends DataRegistryScript and overrides
#   _load_category() to capture the call sequence before delegating to super.
#   This asserts ORDERED_CATEGORIES walk order without modifying production code.
#
# TestContentType fixture class:
#   Defined in tests/fixtures/data_registry/test_content_type.gd.
#   It is a minimal concrete GameData subclass used only here.
extends GdUnitTestSuite

const DataRegistryScript = preload("res://src/core/data_registry/data_registry.gd")


# ---------------------------------------------------------------------------
# Inner class — load-order recorder (used by Test 2 only)
# ---------------------------------------------------------------------------

## Thin subclass that records which categories _load_category() is called with,
## then delegates to the real implementation.
##
## Used exclusively by test_boot_scan_load_order_matches_ordered_categories.
class _OrderRecordingRegistry extends DataRegistryScript:
	## Populated in declaration order as _load_category() is invoked.
	var recorded_order: Array[String] = []

	func _load_category(category: String) -> bool:
		recorded_order.append(category)
		return super._load_category(category)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Root of the programmatic fixture tree written/deleted per test.
## Under res:// so ResourceLoader.load() can resolve fixture .tres paths.
## In headless CI (godot --headless from project root), res:// is writable.
const FIXTURE_ROOT: String = "res://tests/fixtures/data_registry/boot_scan/"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates the fixture directory tree and saves the provided content map.
##
## [param fixture_map]: Dictionary of shape
##   { "category": [ { "id": "...", "display_name": "..." }, ... ] }
## All categories present as keys will have their directories created even if
## the value array is empty.
func _write_fixtures(fixture_map: Dictionary) -> void:
	for category: String in fixture_map:
		var dir_path: String = FIXTURE_ROOT + category
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(dir_path)
		)
		for entry: Dictionary in fixture_map[category]:
			var res: TestContentType = TestContentType.new()
			res.id = entry.get("id", "")
			res.display_name = entry.get("display_name", "")
			ResourceSaver.save(
				res,
				"%s/%s.tres" % [dir_path, res.id if res.id != "" else "unnamed"]
			)


## Recursively removes a directory and all its contents.
##
## Deletes all files first, then removes the (now-empty) directory.
## Handles one level of subdirectory depth — sufficient for the flat
## fixture structure used in this test suite.
func _remove_dir_recursive(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	var da: DirAccess = DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	var entry: String = da.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = da.get_next()
			continue
		var full: String = path + "/" + entry
		if da.current_is_dir():
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full))
		entry = da.get_next()
	da.list_dir_end()
	# Remove .import sidecar files Godot may generate for .tres fixtures
	# (they appear as siblings in the filesystem, not inside the dir).
	DirAccess.remove_absolute(abs_path)


## Tears down the entire FIXTURE_ROOT tree after each test.
func _cleanup_fixtures() -> void:
	_remove_dir_recursive(FIXTURE_ROOT.trim_suffix("/"))


## Creates a fresh DataRegistry pointing at FIXTURE_ROOT with
## [member DataRegistry.min_content_count] set to an empty Dictionary.
##
## Boot-scan enumeration/ordering tests were authored before Story 005 introduced
## minimum content thresholds. Setting an empty min_content_count disables the
## minimum-count enforcement so these tests remain focused on scan order and
## enumeration semantics rather than content volume.
##
## Caller is responsible for freeing the returned instance.
func _make_registry() -> DataRegistry:
	var dr: Node = DataRegistryScript.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}
	return dr


# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------

func after_test() -> void:
	_cleanup_fixtures()


# ---------------------------------------------------------------------------
# Test 1 — TR-data-loading-001 / TR-data-loading-007:
#   Boot scan enumerates all .tres under the six ordered category directories
#   and stores them in _categories keyed by resource.id.
#   All loads complete before _ready() returns (synchronous / eager).
# ---------------------------------------------------------------------------
func test_boot_scan_enumerates_tres_files_and_populates_categories() -> void:
	# Arrange — write minimal fixtures: 2 classes, 1 enemy, empty categories
	_write_fixtures({
		"classes": [
			{"id": "hero_warrior", "display_name": "Warrior"},
			{"id": "hero_mage", "display_name": "Mage"},
		],
		"enemies": [
			{"id": "orc", "display_name": "Orc"},
		],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})

	var ready_count: Array[int] = [0]
	var dr: Node = _make_registry()
	dr.registry_ready.connect(func() -> void: ready_count[0] += 1)

	# Act
	dr._ready()

	# Assert — state and signal
	assert_int(dr.state).is_equal(DataRegistryScript.State.READY)
	assert_int(ready_count[0]).is_equal(1)

	# Assert — classes category contains both fixtures keyed by id
	assert_bool(dr._categories.has("classes")).is_true()
	assert_int(dr._categories["classes"].size()).is_equal(2)
	assert_bool(dr._categories["classes"].has("hero_warrior")).is_true()
	assert_bool(dr._categories["classes"].has("hero_mage")).is_true()

	# Assert — enemies category contains the orc fixture
	assert_bool(dr._categories.has("enemies")).is_true()
	assert_int(dr._categories["enemies"].size()).is_equal(1)
	assert_bool(dr._categories["enemies"].has("orc")).is_true()

	# Assert — all six categories are present (even empty ones)
	for cat: String in DataRegistry.ORDERED_CATEGORIES:
		assert_bool(dr._categories.has(cat)).is_true()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 2 — TR-data-loading-008:
#   _load_category() is invoked in exactly ORDERED_CATEGORIES sequence.
# ---------------------------------------------------------------------------
func test_boot_scan_load_order_matches_ordered_categories() -> void:
	# Arrange — six empty category directories (no .tres content needed for
	# this test; we only assert invocation order, not loaded content).
	_write_fixtures({
		"classes": [],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})

	var dr: _OrderRecordingRegistry = _OrderRecordingRegistry.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}

	# Act
	dr._ready()

	# Assert — recorded order is exactly ORDERED_CATEGORIES
	assert_int(dr.recorded_order.size()).is_equal(6)
	assert_str(dr.recorded_order[0]).is_equal("classes")
	assert_str(dr.recorded_order[1]).is_equal("enemies")
	assert_str(dr.recorded_order[2]).is_equal("biomes")
	assert_str(dr.recorded_order[3]).is_equal("dungeons")
	assert_str(dr.recorded_order[4]).is_equal("items")
	assert_str(dr.recorded_order[5]).is_equal("matchup")

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 3 — TR-data-loading-003:
#   Only .tres files are loaded; .res and .gd siblings are silently skipped.
# ---------------------------------------------------------------------------
func test_boot_scan_skips_non_tres_files_in_category_directory() -> void:
	# Arrange — write one valid .tres fixture
	_write_fixtures({
		"classes": [{"id": "warrior", "display_name": "Warrior"}],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})

	# Write a stray .res file and a stray .gd file alongside the .tres
	# (These simulate .pck compression artifacts and accidental file drops.)
	var stray_res_path: String = FIXTURE_ROOT + "classes/warrior.res"
	var stray_gd_path: String = FIXTURE_ROOT + "classes/warrior.gd"
	var f_res: FileAccess = FileAccess.open(
		stray_res_path, FileAccess.WRITE
	)
	if f_res != null:
		f_res.store_string("not a real .res resource")
		f_res.close()
	var f_gd: FileAccess = FileAccess.open(
		stray_gd_path, FileAccess.WRITE
	)
	if f_gd != null:
		f_gd.store_string("# stray gd file")
		f_gd.close()

	var dr: Node = _make_registry()

	# Act
	dr._ready()

	# Assert — only the one .tres entry is loaded; stray files are absent
	assert_int(dr.state).is_equal(DataRegistryScript.State.READY)
	assert_int(dr._categories["classes"].size()).is_equal(1)
	assert_bool(dr._categories["classes"].has("warrior")).is_true()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 4 — TR-data-loading-002 (auto-discovery forbidden):
#   A directory not in ORDERED_CATEGORIES is NOT enumerated even if it exists
#   under data_root_path.
# ---------------------------------------------------------------------------
func test_boot_scan_does_not_enumerate_unknown_category_directories() -> void:
	# Arrange — write the six canonical categories plus an extra "bonus_category"
	_write_fixtures({
		"classes": [{"id": "warrior", "display_name": "Warrior"}],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})

	# Create the adversarial bonus_category directory with a .tres inside
	var bonus_dir: String = FIXTURE_ROOT + "bonus_category"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(bonus_dir)
	)
	var bonus_res: TestContentType = TestContentType.new()
	bonus_res.id = "bonus_entry"
	ResourceSaver.save(bonus_res, bonus_dir + "/bonus_entry.tres")

	var dr: Node = DataRegistryScript.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}
	# Act
	dr._ready()

	# Assert — _categories contains only the six ORDERED_CATEGORIES keys;
	# "bonus_category" is absent (auto-discovery is forbidden per ADR-0006).
	assert_int(dr._categories.keys().size()).is_equal(6)
	assert_bool(dr._categories.has("bonus_category")).is_false()
	for cat: String in DataRegistry.ORDERED_CATEGORIES:
		assert_bool(dr._categories.has(cat)).is_true()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 5 — TR-data-loading-022:
#   data_root_path override redirects the boot scan away from the default
#   res://assets/data path.
# ---------------------------------------------------------------------------
func test_boot_scan_data_root_path_override_redirects_scan() -> void:
	# Arrange — fixture at non-default path (FIXTURE_ROOT, not res://assets/data)
	_write_fixtures({
		"classes": [{"id": "paladin", "display_name": "Paladin"}],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})

	var dr: Node = DataRegistryScript.new()
	# Override to fixture path — scan must NOT read from res://assets/data
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}
	# Act
	dr._ready()

	# Assert — scan read from fixture path; paladin entry found
	assert_int(dr.state).is_equal(DataRegistryScript.State.READY)
	assert_bool(dr._categories["classes"].has("paladin")).is_true()

	# Assert — default path was NOT used (no production data leaked in)
	# This is guaranteed by the override; we verify the fixture result is
	# what we authored, not what production assets/data/classes/ might contain.
	assert_int(dr._categories["classes"].size()).is_equal(1)

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 6 — TR-data-loading-025 / TR-data-loading-026:
#   lazy_load_categories defaults to empty PackedStringArray on a fresh instance.
#   A .tres fixture with an extra meta value loads without crashing (TR-026 is
#   a property of Godot's ResourceLoader, verified implicitly by Test 1 success).
# ---------------------------------------------------------------------------
func test_boot_scan_lazy_load_categories_defaults_empty_and_extra_fields_ignored() -> void:
	# Arrange — TR-025: inspect a fresh instance without calling _ready()
	var dr: Node = DataRegistryScript.new()

	# Assert — lazy_load_categories default is empty PackedStringArray
	assert_int(dr.lazy_load_categories.size()).is_equal(0)

	# TR-026: author a fixture with a set_meta value (simulates an unknown field
	# from a future content schema version). Godot silently ignores it on load.
	_write_fixtures({
		"classes": [{"id": "wizard", "display_name": "Wizard"}],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],
		"matchup": [],
	})
	# Add meta to the saved .tres to simulate a forward-compat unknown field.
	# We do this by loading, setting meta, and re-saving.
	var wizard_path: String = FIXTURE_ROOT + "classes/wizard.tres"
	var loaded_wizard: Resource = ResourceLoader.load(wizard_path)
	if loaded_wizard != null:
		loaded_wizard.set_meta("future_field_v2", "some_future_value")
		ResourceSaver.save(loaded_wizard, wizard_path)

	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}
	# Act
	dr._ready()

	# Assert — boot scan succeeds despite the meta (unknown field) in the .tres
	# TR-026 NOTE: Godot's ResourceLoader silently ignores unknown resource metadata.
	# No behavioral assertion is needed beyond confirming the load succeeded.
	assert_int(dr.state).is_equal(DataRegistryScript.State.READY)
	assert_bool(dr._categories["classes"].has("wizard")).is_true()

	# Cleanup
	dr.free()


# ---------------------------------------------------------------------------
# Test 7 — Empty category directory does NOT abort the boot scan.
# ---------------------------------------------------------------------------
func test_boot_scan_empty_category_directory_does_not_abort_scan() -> void:
	# Arrange — valid .tres in classes, deliberately empty items/ directory
	_write_fixtures({
		"classes": [{"id": "ranger", "display_name": "Ranger"}],
		"enemies": [],
		"biomes": [],
		"dungeons": [],
		"items": [],  # empty — no .tres files written
		"matchup": [],
	})

	var dr: Node = DataRegistryScript.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}
	# Act
	dr._ready()

	# Assert — scan completed successfully; state is READY
	assert_int(dr.state).is_equal(DataRegistryScript.State.READY)

	# Assert — items/ is present as an empty Dictionary, not null
	assert_bool(dr._categories.has("items")).is_true()
	assert_int(dr._categories["items"].size()).is_equal(0)

	# Assert — classes loaded correctly despite items being empty
	assert_bool(dr._categories["classes"].has("ranger")).is_true()

	# Cleanup
	dr.free()
