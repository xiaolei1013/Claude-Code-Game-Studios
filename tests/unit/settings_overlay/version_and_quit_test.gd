# Sprint 23 S23-S2 — Settings overlay version-label + Quit-to-Desktop tests.
#
# Validates the S23-S2 scaffold additions on the existing settings overlay:
# - Version label is populated from ProjectSettings("application/config/version")
# - Quit-to-Desktop button exists with a pressed-signal listener
#
# The pre-existing volume sliders + reduce_motion toggle + locale + telemetry
# rows are covered by their own dedicated test suites.
extends GdUnitTestSuite

const SettingsScene = preload("res://assets/overlays/settings/settings.tscn")


func _make_settings() -> Control:
	var overlay: Control = SettingsScene.instantiate()
	add_child(overlay)
	auto_free(overlay)
	return overlay


# ===========================================================================
# Group A — Version label
# ===========================================================================

func test_version_label_node_exists() -> void:
	# Arrange + Act
	var overlay: Control = _make_settings()

	# Assert — VersionLabel exists at the canonical path.
	var version_label: Label = overlay.get_node("Panel/VBox/VersionLabel") as Label
	assert_object(version_label).is_not_null()


func test_version_label_renders_project_version_at_ready() -> void:
	# Arrange — read what ProjectSettings reports for reference.
	var expected_version: String = String(
		ProjectSettings.get_setting("application/config/version", "")
	).strip_edges()

	# Act
	var overlay: Control = _make_settings()
	var version_label: Label = overlay.get_node("Panel/VBox/VersionLabel") as Label

	# Assert — label text contains the project version (or "unknown" fallback
	# if the project hasn't declared a version setting).
	var label_text: String = version_label.text
	assert_bool(label_text.length() > 0).is_true()
	if expected_version.is_empty():
		assert_bool(label_text.contains("unknown")).is_true()
	else:
		assert_bool(label_text.contains(expected_version)).override_failure_message(
			"VersionLabel should display the project version '%s'; got '%s'"
			% [expected_version, label_text]
		).is_true()


# ===========================================================================
# Group B — Quit-to-Desktop button
# ===========================================================================

func test_quit_to_desktop_button_exists() -> void:
	# Arrange + Act
	var overlay: Control = _make_settings()

	# Assert — button exists at the canonical path.
	var quit_btn: Button = overlay.get_node("Panel/VBox/ButtonRow/QuitToDesktopButton") as Button
	assert_object(quit_btn).is_not_null()


func test_quit_to_desktop_button_has_pressed_connection() -> void:
	# Arrange + Act
	var overlay: Control = _make_settings()

	# Assert — at least one listener wired by _ready (_on_quit_to_desktop_pressed).
	var quit_btn: Button = overlay.get_node("Panel/VBox/ButtonRow/QuitToDesktopButton") as Button
	assert_int(quit_btn.pressed.get_connections().size()).is_greater_equal(1)
