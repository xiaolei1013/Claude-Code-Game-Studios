# Regression test for the mid-run Dispatch dead-control bug.
#
# Bug: re-entering the formation_assignment screen during an active run and
# pressing Dispatch was a SILENT no-op. The orchestrator's FSM rejected the
# second dispatch_pressed trigger with only a push_error — no signal, so the
# screen had nothing to react to and the player got zero feedback.
#
# Fix (two halves, tested in two suites):
#   1. DungeonRunOrchestrator.dispatch() now emits
#      validation_failed("run_already_active", {"state": <busy>}) on the reject
#      path. Covered by tests/unit/dungeon_run_orchestrator/
#      dispatching_validation_test.gd (Group F2).
#   2. This screen's _on_validation_failed() routes that reason to a visible
#      toast (distinct from the generic-fallback arm). Covered HERE.
#
# These tests drive _on_validation_failed directly (white-box) — the orchestrator
# wiring is exercised by the unit suite, so there's no need to stand up a live
# run here. We assert against tr(key) computed the same way the screen computes
# it, so the test pins the routing (correct key → toast) regardless of whether
# the compiled .translation files are present in the headless runner (per the
# "tr() returns the bare key when locale unresolved" project gotcha — never
# assert on the *resolved* translated string).
extends GdUnitTestSuite

const SCREEN_PATH: String = "res://assets/screens/formation_assignment/formation_assignment.tscn"
const LOCALE_CSV_PATH: String = "res://assets/locale/en.csv"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_screen() -> Control:
	var packed: PackedScene = load(SCREEN_PATH) as PackedScene
	var screen: Control = packed.instantiate() as Control
	add_child(screen)
	# @onready ($ToastLabel → _toast_label) resolves on add_child; the CALLER
	# must still await one process frame before asserting on the screen so
	# _ready() and any deferred setup settle.
	return screen


func _teardown_screen(screen: Control) -> void:
	# Kill the 4s fade tween _show_toast started so it doesn't outlive the node
	# (avoids a dangling SceneTreeTween on free).
	if screen != null:
		screen.call("_dismiss_toast")
		screen.queue_free()


# ===========================================================================
# Group A — run_already_active reason surfaces a visible toast
# ===========================================================================

# A-01: dispatching the "run_already_active" reason makes the toast label
# visible and shows the localized run-already-active message — the player is
# no longer left with a silent dead control.
func test_run_already_active_reason_shows_visible_toast() -> void:
	# Arrange.
	var screen: Control = _make_screen()
	await get_tree().process_frame
	var toast: Label = screen.get_node("ToastLabel") as Label

	# Act.
	screen.call("_on_validation_failed", "run_already_active", {})
	await get_tree().process_frame

	# Assert — toast is shown with the run-already-active copy.
	assert_bool(toast.visible).override_failure_message(
		"run_already_active: toast label must become visible (no silent dead control)"
	).is_true()
	assert_str(toast.text).is_equal(tr("dispatch_error_run_already_active"))

	# Cleanup.
	_teardown_screen(screen)
	await get_tree().process_frame


# A-02: the run_already_active toast is NOT the generic fallback — proves the
# dedicated match arm fired rather than the `_:` default (which would also emit
# a push_warning). Holds whether or not .translation files are loaded: the two
# keys differ as bare strings and as resolved strings.
func test_run_already_active_toast_differs_from_generic_fallback() -> void:
	# Arrange.
	var screen: Control = _make_screen()
	await get_tree().process_frame
	var toast: Label = screen.get_node("ToastLabel") as Label

	# Act.
	screen.call("_on_validation_failed", "run_already_active", {})
	await get_tree().process_frame

	# Assert — distinct from the generic-fallback message.
	assert_str(toast.text).override_failure_message(
		"run_already_active must route to its own toast, not the generic `_:` fallback"
	).is_not_equal(tr("dispatch_error_generic"))

	# Cleanup.
	_teardown_screen(screen)
	await get_tree().process_frame


# ===========================================================================
# Group B — locale data guard (locale-load-independent)
# ===========================================================================

# B-01: the dispatch_error_run_already_active row exists in en.csv, so the
# toast shows localized copy rather than the raw key. Reads the committed CSV
# directly (deterministic, no dependency on regenerated .translation files),
# mirroring the locale_columns_test.gd CSV-read pattern. Guards the data edit
# against an accidental revert.
func test_dispatch_error_run_already_active_key_present_in_locale_csv() -> void:
	var file: FileAccess = FileAccess.open(LOCALE_CSV_PATH, FileAccess.READ)
	assert_object(file).override_failure_message(
		"en.csv must be readable at %s" % LOCALE_CSV_PATH
	).is_not_null()

	var found: bool = false
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.begins_with("dispatch_error_run_already_active,"):
			found = true
			break
	file.close()

	assert_bool(found).override_failure_message(
		"en.csv must contain a 'dispatch_error_run_already_active' row so the "
		+ "mid-run dispatch toast shows localized text, not the bare key"
	).is_true()
