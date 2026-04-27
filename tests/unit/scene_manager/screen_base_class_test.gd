# Tests for Story S5-M6: Screen base class + four lifecycle hooks + CI grep enforcement.
# Covers: TR-scene-manager-005 (all four hooks declared on base class),
#         TR-scene-manager-028 (transition_override_ms export),
#         ADR-0007 doc-comment warnings (PROCESS_MODE_PAUSABLE + TWEEN_PAUSE_BOUND),
#         7 placeholder screens refactored to extends Screen.
#
# The CI grep enforcement (tools/ci/check_screen_hooks.sh) is verified separately
# via the test fixture at tests/fixtures/bad_screen_missing_hook.gd.fixture and
# the .github/workflows/tests.yml integration. This test file does NOT invoke the
# bash script — it would require shell access from GdUnit4 which is not the
# idiomatic path. The CI workflow runs the script as a separate hard gate +
# a follow-on negative-path step (verifies the script catches missing hooks).
extends GdUnitTestSuite

const SCREEN_SCRIPT_PATH: String = "res://src/core/scene_manager/screen.gd"
const ScreenScript = preload("res://src/core/scene_manager/screen.gd")

const PLACEHOLDER_SCREEN_NAMES: Array[String] = [
	"main_menu",
	"guild_hall",
	"recruitment",
	"formation_assignment",
	"dungeon_run_view",
	"victory_moment",
	"return_to_app",
]


# ===========================================================================
# Group A: TR-scene-manager-005 — All four hooks declared on the base class
# ===========================================================================

# ---------------------------------------------------------------------------
# A-01: Screen class resolves via class_name registry; instantiation succeeds
# ---------------------------------------------------------------------------
func test_scene_manager_screen_class_resolves() -> void:
	# Act — instantiate via the registered class_name
	var scr: Node = ScreenScript.new()

	# Assert — non-null instance; correct script attached
	assert_object(scr).is_not_null()
	# Verify the script attached is screen.gd (not relying on class_name resolution
	# which is unreliable in the headless test runner before editor index is built).
	assert_bool(scr.get_script() == ScreenScript).is_true()

	# Cleanup
	scr.free()


# ---------------------------------------------------------------------------
# A-02: Screen extends Control (so theme cascade from MainRoot works per ADR-0008)
# ---------------------------------------------------------------------------
func test_scene_manager_screen_extends_control() -> void:
	# Arrange / Act
	var scr: Node = ScreenScript.new()

	# Assert — Screen is a Control subclass (load-bearing for theme cascade)
	assert_bool(scr is Control).is_true()

	# Cleanup
	scr.free()


# ---------------------------------------------------------------------------
# A-03: All four lifecycle hooks present on the base class
# ---------------------------------------------------------------------------
func test_scene_manager_screen_has_on_enter_method() -> void:
	var scr: Node = ScreenScript.new()
	assert_bool(scr.has_method("on_enter")).is_true()
	scr.free()


func test_scene_manager_screen_has_on_exit_method() -> void:
	var scr: Node = ScreenScript.new()
	assert_bool(scr.has_method("on_exit")).is_true()
	scr.free()


func test_scene_manager_screen_has_on_pause_method() -> void:
	var scr: Node = ScreenScript.new()
	assert_bool(scr.has_method("on_pause")).is_true()
	scr.free()


func test_scene_manager_screen_has_on_resume_method() -> void:
	var scr: Node = ScreenScript.new()
	assert_bool(scr.has_method("on_resume")).is_true()
	scr.free()


# ---------------------------------------------------------------------------
# A-04: All four hooks accept zero arguments (per ADR-0007 contract)
# ---------------------------------------------------------------------------
func test_scene_manager_screen_hooks_accept_zero_arguments() -> void:
	# Arrange
	var scr: Node = ScreenScript.new()

	# Act / Assert — call each hook with zero args; no error means signature is correct.
	# If a subclass were authored with `func on_enter(x: int)`, this would error at runtime.
	scr.on_enter()
	scr.on_exit()
	scr.on_pause()
	scr.on_resume()

	# Reaching this point with no error = all four hooks are zero-arg callable.
	assert_bool(true).is_true()

	# Cleanup
	scr.free()


# ===========================================================================
# Group B: TR-scene-manager-028 — transition_override_ms export
# ===========================================================================

# ---------------------------------------------------------------------------
# B-01: transition_override_ms property exists on the base class
# ---------------------------------------------------------------------------
func test_scene_manager_screen_has_transition_override_ms_property() -> void:
	# Arrange
	var scr: Node = ScreenScript.new()

	# Act — find the property in the property list
	var found: bool = false
	for prop: Dictionary in scr.get_property_list():
		if prop.get("name", "") == "transition_override_ms":
			found = true
			break

	# Assert
	assert_bool(found).is_true()

	# Cleanup
	scr.free()


# ---------------------------------------------------------------------------
# B-02: transition_override_ms default value is 0
# ---------------------------------------------------------------------------
func test_scene_manager_screen_transition_override_ms_default_is_zero() -> void:
	# Arrange
	var scr: Node = ScreenScript.new()

	# Assert
	assert_int(scr.transition_override_ms).is_equal(0)

	# Cleanup
	scr.free()


# ---------------------------------------------------------------------------
# B-03: transition_override_ms is settable to a non-zero value
# ---------------------------------------------------------------------------
func test_scene_manager_screen_transition_override_ms_is_settable() -> void:
	# Arrange
	var scr: Node = ScreenScript.new()

	# Act
	scr.transition_override_ms = 250

	# Assert
	assert_int(scr.transition_override_ms).is_equal(250)

	# Cleanup
	scr.free()


# ---------------------------------------------------------------------------
# B-04: transition_override_ms property is typed as int (Godot TYPE_INT)
# ---------------------------------------------------------------------------
func test_scene_manager_screen_transition_override_ms_is_int_type() -> void:
	# Arrange
	var scr: Node = ScreenScript.new()

	# Act — find the property and verify its TYPE
	var prop_type: int = -1
	for prop: Dictionary in scr.get_property_list():
		if prop.get("name", "") == "transition_override_ms":
			prop_type = prop.get("type", -1)
			break

	# Assert — TYPE_INT == 2 in Godot 4.x
	assert_int(prop_type).is_equal(TYPE_INT)

	# Cleanup
	scr.free()


# ===========================================================================
# Group C: ADR-0007 doc-comment warnings present (Risks Note 1 + Note 4)
# ===========================================================================

# ---------------------------------------------------------------------------
# C-01: Doc warns about PROCESS_MODE_PAUSABLE inheritance (ADR-0007 Risks Note 4)
# ---------------------------------------------------------------------------
func test_scene_manager_screen_doc_warns_about_process_mode_pausable() -> void:
	# Arrange — read the file content
	var file: FileAccess = FileAccess.open(SCREEN_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()

	# Assert — the warning string is present (load-bearing for screen authors)
	assert_str(content).contains("PROCESS_MODE_PAUSABLE")


# ---------------------------------------------------------------------------
# C-02: Doc warns about TWEEN_PAUSE_BOUND default (ADR-0007 Risks Note 1)
# ---------------------------------------------------------------------------
func test_scene_manager_screen_doc_warns_about_tween_pause_bound() -> void:
	# Arrange
	var file: FileAccess = FileAccess.open(SCREEN_SCRIPT_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()

	# Assert
	assert_str(content).contains("TWEEN_PAUSE_BOUND")


# ===========================================================================
# Group D: 7 placeholder screens refactored from `extends Control` to `extends Screen`
# ===========================================================================

# ---------------------------------------------------------------------------
# D-01: All 7 placeholder screens declare `extends Screen` (refactor landed)
# ---------------------------------------------------------------------------
func test_scene_manager_seven_placeholder_screens_extend_screen() -> void:
	# Loop over the canonical 7 MVP screens
	for screen_name: String in PLACEHOLDER_SCREEN_NAMES:
		var path: String = "res://assets/screens/%s/%s.gd" % [screen_name, screen_name]

		# Arrange — read the script content
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_object(file).is_not_null()
		var content: String = file.get_as_text()
		file.close()

		# Assert — declares `extends Screen` (NOT `extends Control`) at line start
		assert_str(content).contains("extends Screen")
		# Negative assertion — bare `extends Control` should NOT remain (sanity check
		# for the refactor; comments mentioning Control are fine but the declaration
		# line should be `extends Screen`).
		assert_bool(content.contains("\nextends Control")).is_false()


# ---------------------------------------------------------------------------
# D-02: All 7 placeholder screens declare all four lifecycle hooks
# (mirrors the CI grep script's logic; runtime check provides redundant defense)
# ---------------------------------------------------------------------------
func test_scene_manager_seven_placeholder_screens_declare_all_hooks() -> void:
	var hooks: Array[String] = ["on_enter", "on_exit", "on_pause", "on_resume"]

	for screen_name: String in PLACEHOLDER_SCREEN_NAMES:
		var path: String = "res://assets/screens/%s/%s.gd" % [screen_name, screen_name]

		# Arrange
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_object(file).is_not_null()
		var content: String = file.get_as_text()
		file.close()

		# Assert — each hook present as a function declaration
		for hook: String in hooks:
			# Match `func hook_name(` (with possible whitespace) at line start
			var found: bool = content.contains("func %s(" % hook) or content.contains("func %s (" % hook)
			assert_bool(found).is_true()


# ===========================================================================
# Group E: Test fixture for the negative case (CI grep enforcement)
# ===========================================================================

# ---------------------------------------------------------------------------
# E-01: bad_screen_missing_hook.gd.fixture exists and is missing on_resume
# (verifies the fixture is set up correctly so the CI grep script has a
# meaningful negative test target. The actual CI grep run is in workflows/tests.yml.)
# ---------------------------------------------------------------------------
func test_scene_manager_bad_screen_fixture_omits_on_resume_hook() -> void:
	# Arrange
	var path: String = "res://tests/fixtures/bad_screen_missing_hook.gd.fixture"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()

	# Assert — the fixture extends Screen (it's a "Screen subclass" by declaration)
	assert_str(content).contains("extends Screen")
	# Has three of the four hooks
	assert_str(content).contains("func on_enter(")
	assert_str(content).contains("func on_exit(")
	assert_str(content).contains("func on_pause(")
	# But NOT on_resume — that's the missing-hook the CI grep should catch
	assert_bool(content.contains("func on_resume(")).is_false()
