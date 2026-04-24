# Tests for Story S1-N1: Per-type validators, duplicate-id detection, and
# min_content_count enforcement.
#
# Covers: TR-016 (AC-DLS-03), TR-017 (AC-DLS-05), TR-023, TR-005, ADR-0011 hook contract.
#
# Fixture strategy (Option B — programmatic):
#   Fixture .tres files are created at runtime via TestContentType.new() +
#   ResourceSaver.save(), then torn down in after_test(). This avoids committing
#   binary .tres files to the repo and keeps every test self-contained and
#   deterministic.
#
# Malformed file note (Test 2 / TR-017):
#   ResourceLoader.load() returns null for a file whose content is not a valid
#   Godot resource. The implementation pushes a warning and continues (does NOT
#   emit registry_error for the malformed file itself). registry_error is only
#   emitted if the subsequent _validate_min_content_count() fails. This test
#   verifies the skip-and-continue behaviour by using min_content_count = {"classes":1}
#   so one valid file is enough to stay READY.
#
# TestContentType fixture class:
#   Defined in tests/fixtures/data_registry/test_content_type.gd.
#   Minimal concrete GameData subclass used exclusively by tests.
extends GdUnitTestSuite

const DataRegistryScript = preload("res://src/core/data_registry/data_registry.gd")
const DataRegistryFixtures = preload("res://tests/fixtures/data_registry/fixture_helpers.gd")


# ---------------------------------------------------------------------------
# Inner class — per-type field validator stub (Test 5 only)
# ---------------------------------------------------------------------------

## Thin DataRegistry subclass that injects a field-validation error for the
## "classes" category, exercising the _validate_resource_fields() hook contract
## defined in ADR-0011 §Load-Time Validation Semantics.
##
## Used exclusively by test_per_type_field_validator_hook_routes_errors_to_transition_to_error.
class _FieldValidatorRegistry extends DataRegistryScript:
	## Override: return a non-empty error reason for "classes" to trigger
	## the InvalidField transition. All other categories pass through.
	func _validate_resource_fields(category: String, _resource: Resource) -> String:
		if category == "classes":
			return "test_injected_error"
		return ""


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Root of the programmatic fixture tree written/deleted per test.
## Under res:// so ResourceLoader.load() can resolve fixture .tres paths.
## In headless CI (godot --headless from project root), res:// is writable.
## Isolated from other test suites' fixture trees by the "validators/" suffix.
const FIXTURE_ROOT: String = "res://tests/fixtures/data_registry/validators/"




## Creates a fresh DataRegistry pointing at FIXTURE_ROOT with
## [member DataRegistry.min_content_count] set to an empty Dictionary.
##
## Used by tests that need to isolate a single validation concern (e.g. id
## format) without triggering unrelated MinContentCount failures.
## Caller is responsible for calling _ready() and freeing the returned instance.
func _make_registry() -> DataRegistry:
	var dr: Node = DataRegistryScript.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}
	return dr


# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------

func after_test() -> void:
	DataRegistryFixtures.cleanup(FIXTURE_ROOT)


# ---------------------------------------------------------------------------
# Test 1 — TR-016 / AC-DLS-03:
#   Two .tres files with the same id within a category transition the registry
#   to ERROR state. The first loaded file is retained in _categories; the
#   second triggers DuplicateId with paths pointing to both files.
# ---------------------------------------------------------------------------
func test_duplicate_id_within_category_transitions_to_error() -> void:
	# Arrange — two files with identical id="hero_warrior" in classes/
	var dir_path: String = FIXTURE_ROOT + "classes"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var res_a: TestContentType = TestContentType.new()
	res_a.id = "hero_warrior"
	res_a.display_name = "Warrior A"
	ResourceSaver.save(res_a, dir_path + "/warrior_a.tres")

	var res_b: TestContentType = TestContentType.new()
	res_b.id = "hero_warrior"
	res_b.display_name = "Warrior B"
	ResourceSaver.save(res_b, dir_path + "/warrior_b.tres")

	var reg: Node = DataRegistryScript.new()
	reg.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	reg.min_content_count = {"classes": 1}

	var captured_errors: Array = []
	reg.registry_error.connect(
		func(reason: String, details: Dictionary) -> void:
			captured_errors.append({"reason": reason, "details": details})
	)

	# Act
	reg._ready()

	# Assert — terminal ERROR state
	assert_int(reg.state).is_equal(DataRegistryScript.State.ERROR)

	# Assert — exactly one registry_error emitted
	assert_int(captured_errors.size()).is_equal(1)
	var err: Dictionary = captured_errors[0]
	assert_str(err["reason"]).is_equal("DuplicateId")
	assert_str(err["details"]["id"]).is_equal("hero_warrior")
	assert_str(err["details"]["content_type"]).is_equal("classes")
	assert_int(err["details"]["paths"].size()).is_equal(2)

	# Assert — first file was retained before the ERROR was triggered
	assert_bool(reg._categories["classes"].has("hero_warrior")).is_true()

	# Cleanup
	reg.free()


# ---------------------------------------------------------------------------
# Test 2 — TR-017 / AC-DLS-05:
#   A .tres file whose content is not a valid Godot resource causes
#   ResourceLoader.load() to return null. The implementation pushes a warning
#   and skips the file (does NOT emit registry_error for this file alone).
#   State stays READY when the remaining count meets min_content_count.
#
#   "Malformed .tres → push_warning + skip + continue; state stays READY
#    when remaining count ≥ min_content_count."
# ---------------------------------------------------------------------------
func test_malformed_tres_file_is_skipped_state_remains_ready() -> void:
	# Arrange — one valid .tres + one garbage file that ResourceLoader returns null for
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
	})

	# Write a file with arbitrary non-resource text — ResourceLoader.load returns null
	var corrupt_path: String = FIXTURE_ROOT + "classes/corrupt.tres"
	var f: FileAccess = FileAccess.open(corrupt_path, FileAccess.WRITE)
	assert_object(f).is_not_null()
	f.store_string("this is not a valid godot resource")
	f.close()

	var reg: Node = DataRegistryScript.new()
	reg.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	reg.min_content_count = {"classes": 1}

	var captured_errors: Array = []
	reg.registry_error.connect(
		func(reason: String, details: Dictionary) -> void:
			captured_errors.append({"reason": reason, "details": details})
	)

	# Act
	reg._ready()

	# Assert — READY, not ERROR (malformed file was skipped, not fatal)
	assert_int(reg.state).is_equal(DataRegistryScript.State.READY)

	# Assert — no registry_error was emitted for the malformed file
	assert_int(captured_errors.size()).is_equal(0)

	# Assert — exactly 1 entry in classes (the valid one); corrupt file skipped
	assert_int(reg._categories["classes"].size()).is_equal(1)
	assert_bool(reg._categories["classes"].has("hero_warrior")).is_true()

	# Cleanup
	reg.free()


# ---------------------------------------------------------------------------
# Test 3 — TR-023:
#   Loaded count below min_content_count for a category transitions to ERROR.
#   Default min_content_count requires 3 classes; only 2 are provided.
# ---------------------------------------------------------------------------
func test_below_min_content_count_transitions_to_error() -> void:
	# Arrange — 2 valid classes; default min_content_count requires 3
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [
			{"id": "hero_warrior", "display_name": "Warrior"},
			{"id": "hero_mage", "display_name": "Mage"},
		],
	})

	var reg: Node = DataRegistryScript.new()
	reg.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	# Use the production default: {"classes": 3, "enemies": 5, "biomes": 1, "dungeons": 1, "matchup": 1}
	# Do NOT override min_content_count — the default 3 for classes is what we're testing.

	var captured_errors: Array = []
	reg.registry_error.connect(
		func(reason: String, details: Dictionary) -> void:
			captured_errors.append({"reason": reason, "details": details})
	)

	# Act
	reg._ready()

	# Assert — ERROR state
	assert_int(reg.state).is_equal(DataRegistryScript.State.ERROR)

	# Assert — exactly one MinContentCount error emitted
	assert_int(captured_errors.size()).is_equal(1)
	var err: Dictionary = captured_errors[0]
	assert_str(err["reason"]).is_equal("MinContentCount")
	assert_str(err["details"]["content_type"]).is_equal("classes")
	assert_int(err["details"]["loaded"]).is_equal(2)
	assert_int(err["details"]["required"]).is_equal(3)

	# Cleanup
	reg.free()


# ---------------------------------------------------------------------------
# Test 4a — TR-005:
#   A PascalCase id (e.g. "HeroWarrior") is not snake_case.
#   The registry transitions to ERROR with reason "InvalidId" and
#   details.reason == "not_snake_case".
# ---------------------------------------------------------------------------
func test_id_pascal_case_transitions_to_error() -> void:
	# Arrange — single file with PascalCase id; min_content_count lenient
	var dir_path: String = FIXTURE_ROOT + "classes"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var res: TestContentType = TestContentType.new()
	res.id = "HeroWarrior"
	res.display_name = "Warrior"
	ResourceSaver.save(res, dir_path + "/HeroWarrior.tres")

	var reg: Node = _make_registry()

	var captured_errors: Array = []
	reg.registry_error.connect(
		func(reason: String, details: Dictionary) -> void:
			captured_errors.append({"reason": reason, "details": details})
	)

	# Act
	reg._ready()

	# Assert — ERROR state
	assert_int(reg.state).is_equal(DataRegistryScript.State.ERROR)

	# Assert — InvalidId / not_snake_case
	assert_int(captured_errors.size()).is_equal(1)
	var err: Dictionary = captured_errors[0]
	assert_str(err["reason"]).is_equal("InvalidId")
	assert_str(err["details"]["reason"]).is_equal("not_snake_case")

	# Cleanup
	reg.free()


# ---------------------------------------------------------------------------
# Test 4b — TR-005:
#   An empty id ("") is rejected with reason "InvalidId" /
#   details.reason == "empty_id".
# ---------------------------------------------------------------------------
func test_id_empty_transitions_to_error() -> void:
	# Arrange — single file with empty id
	var dir_path: String = FIXTURE_ROOT + "classes"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var res: TestContentType = TestContentType.new()
	res.id = ""
	res.display_name = "Unnamed"
	ResourceSaver.save(res, dir_path + "/unnamed.tres")

	var reg: Node = _make_registry()

	var captured_errors: Array = []
	reg.registry_error.connect(
		func(reason: String, details: Dictionary) -> void:
			captured_errors.append({"reason": reason, "details": details})
	)

	# Act
	reg._ready()

	# Assert — ERROR state
	assert_int(reg.state).is_equal(DataRegistryScript.State.ERROR)

	# Assert — InvalidId / empty_id
	assert_int(captured_errors.size()).is_equal(1)
	var err: Dictionary = captured_errors[0]
	assert_str(err["reason"]).is_equal("InvalidId")
	assert_str(err["details"]["reason"]).is_equal("empty_id")

	# Cleanup
	reg.free()


# ---------------------------------------------------------------------------
# Test 4c — TR-005:
#   An id with a leading digit ("1_warrior") is not valid snake_case.
#   _SNAKE_CASE_ID_PATTERN requires [a-z] as the first character.
# ---------------------------------------------------------------------------
func test_id_leading_digit_transitions_to_error() -> void:
	# Arrange — single file with leading-digit id
	var dir_path: String = FIXTURE_ROOT + "classes"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var res: TestContentType = TestContentType.new()
	res.id = "1_warrior"
	res.display_name = "Warrior"
	ResourceSaver.save(res, dir_path + "/1_warrior.tres")

	var reg: Node = _make_registry()

	var captured_errors: Array = []
	reg.registry_error.connect(
		func(reason: String, details: Dictionary) -> void:
			captured_errors.append({"reason": reason, "details": details})
	)

	# Act
	reg._ready()

	# Assert — ERROR state
	assert_int(reg.state).is_equal(DataRegistryScript.State.ERROR)

	# Assert — InvalidId / not_snake_case
	assert_int(captured_errors.size()).is_equal(1)
	var err: Dictionary = captured_errors[0]
	assert_str(err["reason"]).is_equal("InvalidId")
	assert_str(err["details"]["reason"]).is_equal("not_snake_case")

	# Cleanup
	reg.free()


# ---------------------------------------------------------------------------
# Test 4d — TR-005:
#   An id containing hyphens ("hero-warrior") is not valid snake_case.
#   _SNAKE_CASE_ID_PATTERN only allows lowercase letters, digits, and underscores.
# ---------------------------------------------------------------------------
func test_id_with_hyphens_transitions_to_error() -> void:
	# Arrange — single file with hyphenated id
	var dir_path: String = FIXTURE_ROOT + "classes"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var res: TestContentType = TestContentType.new()
	res.id = "hero-warrior"
	res.display_name = "Warrior"
	ResourceSaver.save(res, dir_path + "/hero-warrior.tres")

	var reg: Node = _make_registry()

	var captured_errors: Array = []
	reg.registry_error.connect(
		func(reason: String, details: Dictionary) -> void:
			captured_errors.append({"reason": reason, "details": details})
	)

	# Act
	reg._ready()

	# Assert — ERROR state
	assert_int(reg.state).is_equal(DataRegistryScript.State.ERROR)

	# Assert — InvalidId / not_snake_case
	assert_int(captured_errors.size()).is_equal(1)
	var err: Dictionary = captured_errors[0]
	assert_str(err["reason"]).is_equal("InvalidId")
	assert_str(err["details"]["reason"]).is_equal("not_snake_case")

	# Cleanup
	reg.free()


# ---------------------------------------------------------------------------
# Test 5 — ADR-0011 hook contract:
#   _validate_resource_fields() is called per-resource after id validation.
#   A non-empty return value routes through _transition_to_error with
#   reason == "InvalidField" and details.reason set to the returned string.
# ---------------------------------------------------------------------------
func test_per_type_field_validator_hook_routes_errors_to_transition_to_error() -> void:
	# Arrange — one valid class; _FieldValidatorRegistry always rejects "classes"
	DataRegistryFixtures.write(FIXTURE_ROOT, {
		"classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
	})

	var reg: _FieldValidatorRegistry = _FieldValidatorRegistry.new()
	reg.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	reg.min_content_count = {"classes": 1}

	var captured_errors: Array = []
	reg.registry_error.connect(
		func(reason: String, details: Dictionary) -> void:
			captured_errors.append({"reason": reason, "details": details})
	)

	# Act
	reg._ready()

	# Assert — ERROR state (hook returned a non-empty error reason)
	assert_int(reg.state).is_equal(DataRegistryScript.State.ERROR)

	# Assert — exactly one registry_error emitted with InvalidField semantics
	assert_int(captured_errors.size()).is_equal(1)
	var err: Dictionary = captured_errors[0]
	assert_str(err["reason"]).is_equal("InvalidField")
	assert_str(err["details"]["reason"]).is_equal("test_injected_error")
	assert_str(err["details"]["content_type"]).is_equal("classes")

	# Cleanup
	reg.free()
