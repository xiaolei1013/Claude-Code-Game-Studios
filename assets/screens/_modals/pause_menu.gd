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
const WireframeKitScript = preload("res://src/ui/wireframe_kit.gd")
const TitleScreenScript = preload("res://assets/screens/title/title_screen.gd")


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

	# Lantern Guild mock wireframe: "the guild waits" framing (greybox).
	_build_wireframe()


## Handles Esc inside the pause modal itself — Esc dismisses (acts as Resume).
## The pause modal's own Esc handling is intentional: without it, the Screen
## base class's `_unhandled_input` would route Esc back to itself in a loop.
##
## Guard: only dismiss when this modal is the TOPMOST overlay. When the
## player chains pause → Settings, Settings is topmost; the pause-menu
## Esc handler must NOT fire underneath and pop pause while Settings
## stays orphaned on a resumed game. The topmost-overlay check defers
## Esc to whatever overlay sits above us.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if SceneManager.topmost_overlay_id() != "pause_menu":
		return
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


# ===========================================================================
# Lantern Guild mock wireframe — greybox "the guild waits" framing for Pause
# Additive: eyebrow above the title + a tagline below it (no .tscn edits).
# ===========================================================================

func _build_wireframe() -> void:
	var vbox: Node = get_node_or_null("Panel/VBox")
	if vbox == null or _title_label == null:
		return
	var eyebrow: Label = WireframeKitScript.eyebrow("· The guild waits ·", WireframeKitScript.ACCENT)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(eyebrow)
	vbox.move_child(eyebrow, 0)
	var tagline: Label = WireframeKitScript.caption("The hour-glass turns regardless.", WireframeKitScript.MUTED, 13)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tagline)
	vbox.move_child(tagline, _title_label.get_index() + 1)

	# "Return to Title" entry (mock pause flow) — opens the code-only Title
	# screen as a modal. Boot still routes to Guild Hall (onboarding intact).
	var to_title: Button = Button.new()
	to_title.name = "ReturnToTitleButton"
	to_title.text = "Return to Title"
	to_title.focus_mode = Control.FOCUS_NONE
	to_title.custom_minimum_size = Vector2(0, 52)
	to_title.pressed.connect(_on_return_to_title_pressed)
	UIFrameworkScript.wire_touch_feedback(to_title)
	vbox.add_child(to_title)


func _on_return_to_title_pressed() -> void:
	SceneManager.show_modal(TitleScreenScript.new())
