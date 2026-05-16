## Pause Menu modal — Esc-triggered overlay with Resume / Settings /
## Quit-to-Guild-Hall actions. Sprint 23 S23-M2.
##
## Invoked from any player-facing screen via `SceneManager.push_overlay(
## "pause_menu", true)`. The Screen base class wires Esc → push_overlay
## globally so every screen gets the modal without per-screen plumbing.
##
## Stacks cleanly with other modals per ADR-0007 §push_overlay (counter-
## based pause). If a freestanding modal (e.g., MidRunReassign) is already
## active, the Esc handler in Screen.gd suppresses the pause-menu push so
## the modal slot doesn't double-stack — see Screen._unhandled_input.
##
## Actions:
##   - Resume → `SceneManager.pop_overlay("pause_menu")`
##   - Settings → `SceneManager.push_overlay("settings")` (chains)
##   - Quit-to-Guild-Hall → `pop_overlay("pause_menu")` + `request_screen(
##     "guild_hall")` (the screen swap auto-saves via the scene_boundary
##     contract when transitioning into Guild Hall from gameplay screens)
extends Control

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")


@onready var _title_label: Label = $Panel/VBox/TitleLabel
@onready var _resume_button: Button = $Panel/VBox/ResumeButton
@onready var _settings_button: Button = $Panel/VBox/SettingsButton
@onready var _quit_button: Button = $Panel/VBox/QuitToGuildHallButton


func _ready() -> void:
	# Localized button + title text via tr(). The keys are added in
	# `assets/locale/en.csv` as part of this story; missing keys degrade
	# to the verbatim key string per Godot tr() semantics.
	_title_label.text = tr("pause_menu_title")
	_resume_button.text = tr("pause_menu_resume_button")
	_settings_button.text = tr("pause_menu_settings_button")
	_quit_button.text = tr("pause_menu_quit_to_guild_hall_button")

	_resume_button.pressed.connect(_on_resume_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	# Touch-feedback pulse + UI tap chime per Art Bible §7 / ADR-0008.
	UIFrameworkScript.wire_touch_feedback(_resume_button)
	UIFrameworkScript.wire_touch_feedback(_settings_button)
	UIFrameworkScript.wire_touch_feedback(_quit_button)


## Handles Esc inside the pause modal itself — Esc dismisses (acts as Resume).
## The pause modal's own Esc handling is intentional: without it, the Screen
## base class's `_unhandled_input` would route Esc back to itself in a loop.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()


func _on_resume_pressed() -> void:
	_dismiss()


## Chains into the Settings overlay. The pause menu stays pushed beneath
## the Settings overlay (overlay stack), so closing Settings reveals the
## pause menu again — matching the conventional desktop-game pattern.
func _on_settings_pressed() -> void:
	SceneManager.push_overlay("settings", true)


## Pops the pause overlay and navigates back to Guild Hall. The
## `scene_boundary_persist` signal on transitions into safe screens is
## the auto-save trigger per SaveLoadSystem; no extra call needed here.
func _on_quit_pressed() -> void:
	_dismiss()
	SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)


func _dismiss() -> void:
	SceneManager.pop_overlay("pause_menu")
