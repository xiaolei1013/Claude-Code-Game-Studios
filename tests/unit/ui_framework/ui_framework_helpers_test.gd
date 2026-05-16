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


# ===========================================================================
# Group D — AC-AS-14 / AC-AS-15: UI tap chime via wire_touch_feedback
# ===========================================================================
# Tests the audio-system.md hook that fires sfx_ui_tap on the same gui_input
# event that drives the visual touch pulse. Reads back the AudioRouter's
# debug-build _test_play_sfx_log spy populated by play_sfx.

func _ar() -> Node:
	return get_tree().root.get_node_or_null("AudioRouter")


func _clear_play_log() -> void:
	var ar: Node = _ar()
	if ar != null and "_test_play_sfx_log" in ar:
		ar._test_play_sfx_log.clear()


func _count_ui_tap_plays() -> int:
	var ar: Node = _ar()
	if ar == null or "_test_play_sfx_log" not in ar:
		return 0
	var count: int = 0
	for entry: Dictionary in ar._test_play_sfx_log:
		if entry.get("sfx_id") == &"sfx_ui_tap":
			count += 1
	return count


func test_ui_framework_wire_touch_feedback_fires_ui_tap_chime_on_mouse_press() -> void:
	# AC-AS-14: a wired Control receiving a mouse-button-down event produces
	# exactly one sfx_ui_tap play.
	# Arrange
	_clear_play_log()
	var btn: Button = auto_free(Button.new())
	add_child(btn)
	UIFrameworkScript.wire_touch_feedback(btn)

	# Act — synthesize a mouse-button-down event via the gui_input signal.
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	btn.gui_input.emit(press)

	# Assert
	assert_int(_count_ui_tap_plays()).is_equal(1)


func test_ui_framework_wire_touch_feedback_fires_ui_tap_chime_on_touch_press() -> void:
	# AC-AS-14 (touch parity): a screen-touch-down event also produces one chime.
	# Arrange
	_clear_play_log()
	var btn: Button = auto_free(Button.new())
	add_child(btn)
	UIFrameworkScript.wire_touch_feedback(btn)

	# Act
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	btn.gui_input.emit(touch)

	# Assert
	assert_int(_count_ui_tap_plays()).is_equal(1)


func test_ui_framework_wire_touch_feedback_does_not_fire_chime_on_release() -> void:
	# AC-AS-15: the chime is wired to gui_input (press) only — release does
	# NOT produce a chime. A complete tap (press + release) yields exactly one
	# chime, not two.
	# Arrange
	_clear_play_log()
	var btn: Button = auto_free(Button.new())
	add_child(btn)
	UIFrameworkScript.wire_touch_feedback(btn)

	# Act — fire a release event (pressed = false).
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	btn.gui_input.emit(release)

	# Assert — no chime on release.
	assert_int(_count_ui_tap_plays()).is_equal(0)


func test_ui_framework_wire_touch_feedback_full_tap_produces_exactly_one_chime() -> void:
	# AC-AS-15: combined press + release produces 1 chime, not 2.
	# Arrange
	_clear_play_log()
	var btn: Button = auto_free(Button.new())
	add_child(btn)
	UIFrameworkScript.wire_touch_feedback(btn)

	# Act — full tap = press then release.
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	btn.gui_input.emit(press)

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	btn.gui_input.emit(release)

	# Assert
	assert_int(_count_ui_tap_plays()).is_equal(1)


# ===========================================================================
# Group E — Sprint 24 S24-M3: clear_children_immediate
# ===========================================================================

func test_clear_children_immediate_detaches_all_children_synchronously() -> void:
	# Arrange — container with 5 child labels.
	var container: VBoxContainer = auto_free(VBoxContainer.new())
	add_child(container)
	for i: int in range(5):
		var lbl: Label = Label.new()
		lbl.text = "child %d" % i
		container.add_child(lbl)
	assert_int(container.get_child_count()).is_equal(5)

	# Act
	UIFrameworkScript.clear_children_immediate(container)

	# Assert — synchronous: get_child_count is 0 immediately, no idle-frame wait needed.
	assert_int(container.get_child_count()).is_equal(0)


func test_clear_children_immediate_handles_null_container_defensively() -> void:
	# Arrange + Act — no-op, must not crash on null.
	UIFrameworkScript.clear_children_immediate(null)
	# Assert — reaching here = pass (no exception).


func test_clear_children_immediate_handles_empty_container() -> void:
	# Arrange — empty container.
	var container: VBoxContainer = auto_free(VBoxContainer.new())
	add_child(container)

	# Act
	UIFrameworkScript.clear_children_immediate(container)

	# Assert
	assert_int(container.get_child_count()).is_equal(0)


# ===========================================================================
# Group F — Sprint 24 S24-M3: synergy_display_name
# ===========================================================================

func test_synergy_display_name_returns_localized_for_known_synergy() -> void:
	# Arrange + Act — known synergy_id routes through tr() with the
	# class_synergy_badge_<id> key set.
	var result: String = UIFrameworkScript.synergy_display_name("steel_wall")

	# Assert — non-empty (tr returns the en.csv value or the key verbatim).
	assert_bool(result.length() > 0).is_true()


func test_synergy_display_name_returns_empty_for_empty_synergy_id() -> void:
	# Arrange + Act — defensive: empty input returns empty string.
	var result: String = UIFrameworkScript.synergy_display_name("")

	# Assert
	assert_str(result).is_equal("")


# ===========================================================================
# Group G — Sprint 24 S24-M3: synergy_id_to_tier (hoisted from S24-M2)
# ===========================================================================
# AC-CS-22..25 — see class-synergy-system.md §H acceptance criteria.

func test_synergy_id_to_tier_empty_returns_none() -> void:
	# AC-CS-22
	assert_str(UIFrameworkScript.synergy_id_to_tier("")).is_equal("none")


func test_synergy_id_to_tier_steel_wall_returns_gold() -> void:
	# AC-CS-23
	assert_str(UIFrameworkScript.synergy_id_to_tier("steel_wall")).is_equal("gold")


func test_synergy_id_to_tier_arcane_elite_returns_gold() -> void:
	# AC-CS-23
	assert_str(UIFrameworkScript.synergy_id_to_tier("arcane_elite")).is_equal("gold")


func test_synergy_id_to_tier_triple_strike_returns_gold() -> void:
	# AC-CS-23
	assert_str(UIFrameworkScript.synergy_id_to_tier("triple_strike")).is_equal("gold")


func test_synergy_id_to_tier_triple_threat_returns_platinum() -> void:
	# AC-CS-24
	assert_str(UIFrameworkScript.synergy_id_to_tier("triple_threat")).is_equal("platinum")


func test_synergy_id_to_tier_unknown_returns_none_defensive() -> void:
	# AC-CS-25
	assert_str(UIFrameworkScript.synergy_id_to_tier("nonexistent_synergy")).is_equal("none")
	assert_str(UIFrameworkScript.synergy_id_to_tier("future_v25_id")).is_equal("none")


# ===========================================================================
# Group H — tier-2 mono-class synergies tier mapping
#
# Each tier-2 class's 3-of-a-kind synergy maps to Gold tier — same as the
# V1 mono-class set. Hoisted from tier2_synergy_multipliers_test.gd where
# they were originally collocated with the orchestrator multiplier tests.
# ===========================================================================

func test_synergy_id_to_tier_bastion_returns_gold() -> void:
	assert_str(UIFrameworkScript.synergy_id_to_tier("bastion")).is_equal("gold")


func test_synergy_id_to_tier_volley_returns_gold() -> void:
	assert_str(UIFrameworkScript.synergy_id_to_tier("volley")).is_equal("gold")


func test_synergy_id_to_tier_frenzy_returns_gold() -> void:
	assert_str(UIFrameworkScript.synergy_id_to_tier("frenzy")).is_equal("gold")


func test_synergy_id_to_tier_vigil_returns_gold() -> void:
	assert_str(UIFrameworkScript.synergy_id_to_tier("vigil")).is_equal("gold")


# ===========================================================================
# Group I — synergy_effect_text helper
#
# Effect text lookup for the writer-locked class_synergy_effect_<id>
# locale keys. Centralizes the locale-key convention so guild_hall.gd +
# formation_assignment.gd badge/preview-label call sites don't each
# build the key string inline.
# ===========================================================================

func test_synergy_effect_text_returns_steel_wall_writer_locked_string() -> void:
	# Validates V1 path. Resolves to "+25% gold vs bruisers" via en.csv
	# OR to the key verbatim if en.csv isn't loaded — both are non-empty.
	var result: String = UIFrameworkScript.synergy_effect_text("steel_wall")
	assert_int(result.length()).is_greater(0)


func test_synergy_effect_text_returns_empty_for_empty_synergy_id() -> void:
	# No synergy → no effect to render. Empty input → empty output (defensive
	# parallel to synergy_display_name's empty-id branch).
	assert_str(UIFrameworkScript.synergy_effect_text("")).is_equal("")
