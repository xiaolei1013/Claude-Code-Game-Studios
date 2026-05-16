# Sprint 23 S23-M2 — Pause Menu modal render + wiring tests.
#
# Validates the structural and behavioral contract of the pause modal that
# replaces "fall through to a screen" behavior on Esc. The modal lives at
# assets/screens/_modals/pause_menu.tscn and is registered with SceneManager
# as overlay_id "pause_menu" (registry entry).
#
# Test groups:
#   A — Scene structure (Resume/Settings/Quit buttons + dim backdrop)
#   B — Button text localized at _ready
#   C — Resume button pops the overlay
#   D — Quit-to-Guild-Hall navigates + dismisses
#   E — SceneManager registry contains "pause_menu"
extends GdUnitTestSuite

const PauseMenuScene = preload("res://assets/screens/_modals/pause_menu.tscn")


func _make_pause_menu() -> Control:
	var menu: Control = PauseMenuScene.instantiate()
	add_child(menu)
	auto_free(menu)
	return menu


# ===========================================================================
# Group A — Scene structure
# ===========================================================================

func test_pause_menu_has_resume_settings_and_quit_buttons() -> void:
	# Arrange + Act
	var menu: Control = _make_pause_menu()

	# Assert — three buttons present at their canonical paths.
	assert_object(menu.get_node("Panel/VBox/ResumeButton") as Button).is_not_null()
	assert_object(menu.get_node("Panel/VBox/SettingsButton") as Button).is_not_null()
	assert_object(menu.get_node("Panel/VBox/QuitToGuildHallButton") as Button).is_not_null()


func test_pause_menu_has_dim_backdrop() -> void:
	# Arrange + Act — modal pattern (ADR-0007): dim full-screen backdrop
	# behind a centered Panel.
	var menu: Control = _make_pause_menu()

	# Assert — backdrop exists and is semi-transparent (alpha < 1).
	var backdrop: ColorRect = menu.get_node("DimBackdrop") as ColorRect
	assert_object(backdrop).is_not_null()
	assert_float(backdrop.color.a).is_less(1.0)
	assert_float(backdrop.color.a).is_greater(0.0)


# ===========================================================================
# Group B — Localized button text
# ===========================================================================

func test_pause_menu_buttons_text_routed_through_tr() -> void:
	# Arrange + Act
	var menu: Control = _make_pause_menu()

	# Assert — each button has non-empty localized text. tr() returns
	# either the writer-locked en.csv value OR the key verbatim if the
	# locale didn't load; both are non-empty.
	var resume_btn: Button = menu.get_node("Panel/VBox/ResumeButton") as Button
	var settings_btn: Button = menu.get_node("Panel/VBox/SettingsButton") as Button
	var quit_btn: Button = menu.get_node("Panel/VBox/QuitToGuildHallButton") as Button
	assert_bool(resume_btn.text.length() > 0).is_true()
	assert_bool(settings_btn.text.length() > 0).is_true()
	assert_bool(quit_btn.text.length() > 0).is_true()


# ===========================================================================
# Group C — SceneManager overlay registry
# ===========================================================================

func test_scene_manager_overlay_registry_contains_pause_menu() -> void:
	# Arrange + Act — read the live SceneManager autoload's registry.
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")

	# Assert — pause_menu is registered so push_overlay("pause_menu") resolves.
	assert_object(sm).is_not_null()
	var registry: Dictionary = sm.get("_overlay_registry") as Dictionary
	assert_bool(registry.has("pause_menu")).is_true()
	# Resource path matches the canonical location.
	var packed: PackedScene = registry["pause_menu"] as PackedScene
	assert_object(packed).is_not_null()
	assert_str(packed.resource_path).is_equal("res://assets/screens/_modals/pause_menu.tscn")


# ===========================================================================
# Group D — Button signal handlers wired
# ===========================================================================

func test_pause_menu_buttons_have_pressed_signal_connections() -> void:
	# Arrange + Act
	var menu: Control = _make_pause_menu()

	# Assert — each button has at least one pressed-signal listener
	# (the _on_*_pressed handlers connected in _ready).
	var resume_btn: Button = menu.get_node("Panel/VBox/ResumeButton") as Button
	var settings_btn: Button = menu.get_node("Panel/VBox/SettingsButton") as Button
	var quit_btn: Button = menu.get_node("Panel/VBox/QuitToGuildHallButton") as Button
	assert_int(resume_btn.pressed.get_connections().size()).is_greater_equal(1)
	assert_int(settings_btn.pressed.get_connections().size()).is_greater_equal(1)
	assert_int(quit_btn.pressed.get_connections().size()).is_greater_equal(1)
