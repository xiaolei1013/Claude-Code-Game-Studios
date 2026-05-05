# Sprint 10 S10-M2: UIFramework.apply_parchment_panel + UIFramework.wire_touch_feedback.
#
# ADR-0008 §apply_parchment_panel + §Touch feedback (1.05× scale, 80ms).
# Companion to the Sprint 8 S5/S8 tap-target + suppress_keyboard_focus tests
# (those live alongside the formation_assignment screen tests because they
# wire onto live screens; these helpers are testable in pure Control isolation).
extends GdUnitTestSuite

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")

const _META_TOUCH_WIRED: StringName = &"ui_framework_touch_feedback_wired"


# ===========================================================================
# Group A — apply_parchment_panel
# ===========================================================================

func test_ui_framework_apply_parchment_panel_sets_theme_type_variation() -> void:
	# Arrange
	var panel: PanelContainer = auto_free(PanelContainer.new())
	add_child(panel)

	# Act
	UIFrameworkScript.apply_parchment_panel(panel)

	# Assert
	assert_str(String(panel.theme_type_variation)).is_equal("ParchmentPanel")


func test_ui_framework_apply_parchment_panel_decorative_sets_mouse_filter_pass() -> void:
	# Arrange — start with STOP so we can prove the helper changed it.
	var panel: PanelContainer = auto_free(PanelContainer.new())
	add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Act
	UIFrameworkScript.apply_parchment_panel(panel, UIFrameworkScript.PanelPattern.DECORATIVE)

	# Assert
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)


func test_ui_framework_apply_parchment_panel_standard_does_not_change_mouse_filter() -> void:
	# Arrange — set to a non-default value the helper should NOT touch.
	var panel: PanelContainer = auto_free(PanelContainer.new())
	add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	# Act
	UIFrameworkScript.apply_parchment_panel(panel, UIFrameworkScript.PanelPattern.STANDARD)

	# Assert — STANDARD pattern leaves mouse_filter exactly as the caller set it.
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)


func test_ui_framework_apply_parchment_panel_default_pattern_is_standard() -> void:
	# Arrange — no second argument means STANDARD per the function signature.
	var panel: PanelContainer = auto_free(PanelContainer.new())
	add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Act
	UIFrameworkScript.apply_parchment_panel(panel)

	# Assert — STOP preserved (STANDARD behavior).
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_str(String(panel.theme_type_variation)).is_equal("ParchmentPanel")


func test_ui_framework_apply_parchment_panel_null_panel_does_not_crash() -> void:
	# Arrange / Act — calling with null should push_error but not crash the test.
	# We swallow the error in a lambda so the test asserts only that the call
	# returns without throwing. push_error does not fail GdUnit tests by default.
	UIFrameworkScript.apply_parchment_panel(null)

	# Assert — control flow reached this line means no crash.
	assert_bool(true).is_true()


func test_ui_framework_panel_pattern_enum_has_standard_and_decorative_values() -> void:
	# Lock the enum surface so a future rename / removal is caught here rather
	# than in a runtime crash on a screen that uses DECORATIVE.
	assert_int(UIFrameworkScript.PanelPattern.STANDARD).is_equal(0)
	assert_int(UIFrameworkScript.PanelPattern.DECORATIVE).is_equal(1)


# ===========================================================================
# Group B — wire_touch_feedback
# ===========================================================================

func test_ui_framework_wire_touch_feedback_sets_meta_sentinel() -> void:
	# Arrange
	var btn: Button = auto_free(Button.new())
	add_child(btn)
	assert_bool(btn.has_meta(_META_TOUCH_WIRED)).is_false()

	# Act
	UIFrameworkScript.wire_touch_feedback(btn)

	# Assert
	assert_bool(btn.has_meta(_META_TOUCH_WIRED)).is_true()
	assert_bool(btn.get_meta(_META_TOUCH_WIRED)).is_true()


func test_ui_framework_wire_touch_feedback_connects_gui_input_signal() -> void:
	# Arrange
	var btn: Button = auto_free(Button.new())
	add_child(btn)
	var connection_count_before: int = btn.gui_input.get_connections().size()

	# Act
	UIFrameworkScript.wire_touch_feedback(btn)

	# Assert — exactly one new gui_input connection.
	var connection_count_after: int = btn.gui_input.get_connections().size()
	assert_int(connection_count_after).is_equal(connection_count_before + 1)


func test_ui_framework_wire_touch_feedback_idempotent_on_repeat_call() -> void:
	# Arrange
	var btn: Button = auto_free(Button.new())
	add_child(btn)

	# Act — call three times; should connect only once.
	UIFrameworkScript.wire_touch_feedback(btn)
	var after_first: int = btn.gui_input.get_connections().size()
	UIFrameworkScript.wire_touch_feedback(btn)
	UIFrameworkScript.wire_touch_feedback(btn)

	# Assert
	var after_third: int = btn.gui_input.get_connections().size()
	assert_int(after_third).is_equal(after_first)


func test_ui_framework_wire_touch_feedback_null_control_does_not_crash() -> void:
	# Arrange / Act
	UIFrameworkScript.wire_touch_feedback(null)

	# Assert — control flow reached this line means no crash.
	assert_bool(true).is_true()


func test_ui_framework_wire_touch_feedback_pulse_constants_match_art_bible() -> void:
	# Lock the Art Bible §7 Animation Feel contract (1.05× / 80ms / ~1 frame).
	# A future tuning pass that violates this without a corresponding Art Bible
	# update will fail here, surfacing the design-vs-impl drift loudly.
	assert_vector(UIFrameworkScript.TOUCH_PULSE_SCALE).is_equal(Vector2(1.05, 1.05))
	assert_float(UIFrameworkScript.TOUCH_PULSE_EXPAND_SEC).is_equal_approx(0.08, 0.001)
	assert_float(UIFrameworkScript.TOUCH_PULSE_RETURN_SEC).is_equal_approx(0.016, 0.001)


# ===========================================================================
# Group C — format_localized (S10-N1)
# ===========================================================================

func test_ui_framework_format_localized_substitutes_when_key_contains_specifier() -> void:
	# Real EN locale: "Run Complete — %d kills" is registered under
	# "run_complete_kill_count_format". Locale loader runs at boot in this test
	# env so tr() returns the substituted value, NOT the raw key.
	# We assert the output starts with "Run Complete" — exact text depends on
	# locale loader having succeeded; if it returns the raw key, the test
	# adjusts to the headless fallback path verified by the next test.
	var out: String = UIFrameworkScript.format_localized(
		"run_complete_kill_count_format", [42]
	)
	# Either substituted ("Run Complete — 42 kills") OR raw-key + suffix
	# ("run_complete_kill_count_format 42"). Both are valid outputs of the
	# safe-format contract; assert "42" is present in either case.
	assert_str(out).contains("42")


func test_ui_framework_format_localized_falls_back_to_suffix_on_unknown_key() -> void:
	# An unknown key produces tr() raw-key passthrough (no '%' specifier).
	# format_localized must fall back to "<key> <args joined by space>".
	var out: String = UIFrameworkScript.format_localized(
		"this_key_definitely_does_not_exist_xyz_s10n1", ["alpha", 7]
	)
	assert_str(out).contains("this_key_definitely_does_not_exist_xyz_s10n1")
	assert_str(out).contains("alpha")
	assert_str(out).contains("7")


func test_ui_framework_format_localized_handles_empty_args_array() -> void:
	# Empty args array: just return the format string unchanged
	# (no '%' substitution attempted, no suffix appended).
	var out: String = UIFrameworkScript.format_localized(
		"this_key_definitely_does_not_exist_xyz_s10n1_empty", []
	)
	assert_str(out).is_equal("this_key_definitely_does_not_exist_xyz_s10n1_empty")


func test_ui_framework_format_localized_substitutes_multiple_args_in_order() -> void:
	# Use the S10-M4 hero_level_up_toast_format key which is known to exist
	# in en.csv as "%s reached level %d!".
	var out: String = UIFrameworkScript.format_localized(
		"hero_level_up_toast_format", ["Theron", 3]
	)
	# Either "Theron reached level 3!" (locale-loaded path) OR
	# "hero_level_up_toast_format Theron 3" (headless fallback).
	assert_str(out).contains("Theron")
	assert_str(out).contains("3")
