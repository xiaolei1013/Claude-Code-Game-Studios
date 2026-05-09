## Guild Hall — first-launch landing screen (placeholder, with smoke nav).
##
## Sprint 8 S8-M4 hotfix: added a "Go to Dispatch" button so the manual smoke
## flow (Guild Hall → FormationAssignment → DungeonRunView → MainMenu) can be
## walked end-to-end without dev-console intervention. Sprint 9+ replaces this
## placeholder with the real Guild Hall content.
##
## Sprint 21+ Prestige V1.0 / Story 3 UI (Slice B): adds the
## "Hall of Retired Heroes" entry button, visibility-gated on
## `HeroRoster.get_prestige_count() > 0` per
## `design/gdd/prestige-system.md` §F.
extends Screen

@onready var _dispatch_nav_button: Button = $DispatchNavButton
@onready var _hall_nav_button: Button = $HallOfRetiredHeroesNavButton
@onready var _toast_label: Label = $ToastLabel

# Prestige completion toast — fades over 4.0s matching the
# formation_assignment + Recruitment toast pattern (GDD #21 §G).
const TOAST_FADE_DURATION_SEC: float = 4.0
var _toast_tween: Tween = null


func on_enter() -> void:
	if _dispatch_nav_button == null:
		push_error("[GuildHall] _dispatch_nav_button is NULL — @onready did not resolve. Check .tscn node name 'DispatchNavButton'.")
		return
	if not _dispatch_nav_button.pressed.is_connected(_on_dispatch_nav_pressed):
		_dispatch_nav_button.pressed.connect(_on_dispatch_nav_pressed)

	# Hall of Retired Heroes button: localized label + visibility gate +
	# subscribe to prestige_completed_signal so a freshly-prestiged hero
	# pops the button into view immediately on screen-resume.
	if _hall_nav_button != null:
		_hall_nav_button.text = tr("guild_hall_open_hall_button_label")
		if not _hall_nav_button.pressed.is_connected(_on_hall_nav_pressed):
			_hall_nav_button.pressed.connect(_on_hall_nav_pressed)
		if not HeroRoster.prestige_completed_signal.is_connected(_on_prestige_completed):
			HeroRoster.prestige_completed_signal.connect(_on_prestige_completed)
		_refresh_hall_button_visibility()


func on_exit() -> void:
	if _dispatch_nav_button != null and _dispatch_nav_button.pressed.is_connected(_on_dispatch_nav_pressed):
		_dispatch_nav_button.pressed.disconnect(_on_dispatch_nav_pressed)
	if _hall_nav_button != null and _hall_nav_button.pressed.is_connected(_on_hall_nav_pressed):
		_hall_nav_button.pressed.disconnect(_on_hall_nav_pressed)
	if HeroRoster.prestige_completed_signal.is_connected(_on_prestige_completed):
		HeroRoster.prestige_completed_signal.disconnect(_on_prestige_completed)
	# Kill any in-flight toast tween so its bound `_dismiss_toast`
	# callback can't fire on a being-freed node.
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null


func on_pause() -> void:
	pass


func on_resume() -> void:
	pass


# ---------------------------------------------------------------------------
# Hall of Retired Heroes button — visibility gate + nav
# ---------------------------------------------------------------------------

## Hides the Hall button until at least one prestige has been completed.
## Per `prestige-system.md` §F + cozy-register rule: don't tease the
## player with an empty Hall view. The button's visibility is content-
## addressable: it shows iff
## [code]HeroRoster.get_prestige_count() > 0[/code].
func _refresh_hall_button_visibility() -> void:
	if _hall_nav_button == null:
		return
	_hall_nav_button.visible = HeroRoster.get_prestige_count() > 0


func _on_prestige_completed(record: Dictionary, _new_count: int) -> void:
	_refresh_hall_button_visibility()
	# Cozy completion toast: "[hero name] joined the Hall of Retired
	# Heroes." Tween freezes if Guild Hall is paused under a modal at
	# emit time (Hero Detail Modal flow), then resumes on modal close —
	# the toast remains at modulate.a=1.0 during the modal cover and
	# starts fading out the moment the modal dismisses. Net effect:
	# player sees the toast appear as the modal closes. Acceptable
	# per the existing screen pause/tween contract.
	var display_name: String = String(record.get("display_name", ""))
	if display_name == "":
		return
	# Single %s, no literal %, so the % operator is safe here.
	var text: String = tr("prestige_complete_toast") % display_name
	_show_prestige_toast(text)


## Renders [param text] on the bottom-center toast label and fades it
## over [code]TOAST_FADE_DURATION_SEC[/code]. Mirrors the formation_assignment
## + Recruitment toast pattern (GDD #21 §G precedent). Kills any in-flight
## prior toast before starting the new one.
func _show_prestige_toast(text: String) -> void:
	if _toast_label == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_label.visible = true
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, TOAST_FADE_DURATION_SEC)
	_toast_tween.finished.connect(_dismiss_toast, CONNECT_ONE_SHOT)


func _dismiss_toast() -> void:
	if _toast_label != null:
		_toast_label.visible = false
		_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null


func _on_hall_nav_pressed() -> void:
	SceneManager.request_screen("hall_of_retired_heroes", SceneManager.TransitionType.CROSS_FADE)


func _on_dispatch_nav_pressed() -> void:
	SceneManager.request_screen("formation_assignment", SceneManager.TransitionType.CROSS_FADE)
