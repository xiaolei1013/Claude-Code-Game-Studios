## Main Menu — post-run landing screen (placeholder, with smoke nav).
##
## Sprint 8 S8-M4 hotfix: added a "Go to Dispatch" button so a player who lands
## on main_menu after a RUN_ENDED auto-route (Story 013) can start another run
## without restarting the build. Sprint 9+ replaces this placeholder with the
## real MainMenu content (settings, credits, quit, etc.).
extends Screen

@onready var _dispatch_nav_button: Button = $DispatchNavButton


func on_enter() -> void:
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
