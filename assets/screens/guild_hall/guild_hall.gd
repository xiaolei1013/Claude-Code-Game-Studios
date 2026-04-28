## Guild Hall — first-launch landing screen (placeholder, with smoke nav).
##
## Sprint 8 S8-M4 hotfix: added a "Go to Dispatch" button so the manual smoke
## flow (Guild Hall → FormationAssignment → DungeonRunView → MainMenu) can be
## walked end-to-end without dev-console intervention. Sprint 9+ replaces this
## placeholder with the real Guild Hall content.
extends Screen

@onready var _dispatch_nav_button: Button = $DispatchNavButton


func on_enter() -> void:
	if _dispatch_nav_button == null:
		push_error("[GuildHall] _dispatch_nav_button is NULL — @onready did not resolve. Check .tscn node name 'DispatchNavButton'.")
		return
	if not _dispatch_nav_button.pressed.is_connected(_on_dispatch_nav_pressed):
		_dispatch_nav_button.pressed.connect(_on_dispatch_nav_pressed)


func on_exit() -> void:
	if _dispatch_nav_button != null and _dispatch_nav_button.pressed.is_connected(_on_dispatch_nav_pressed):
		_dispatch_nav_button.pressed.disconnect(_on_dispatch_nav_pressed)


func on_pause() -> void:
	pass


func on_resume() -> void:
	pass


func _on_dispatch_nav_pressed() -> void:
	SceneManager.request_screen("formation_assignment", SceneManager.TransitionType.CROSS_FADE)
