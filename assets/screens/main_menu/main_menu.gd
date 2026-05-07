## Main Menu — post-run landing screen (placeholder, with smoke nav).
##
## Sprint 8 S8-M4 hotfix: added a "Go to Dispatch" button so a player who lands
## on main_menu after a RUN_ENDED auto-route (Story 013) can start another run
## without restarting the build. Sprint 9+ replaces this placeholder with the
## real MainMenu content (settings, credits, quit, etc.).
##
## Sprint 10 S10-M2: wires UIFramework touch feedback onto the dispatch button
## (Art Bible §7 Animation Feel — 1.05× scale pulse for tap responsiveness).
##
## Sprint 14 S14-N2 (5-sprint carry-forward from S10-N2): wires the Redispatch
## shortcut button. Visible only when DungeonRunOrchestrator.last_dispatch_intent
## is non-empty (i.e. the player has dispatched at least once this session).
## Press re-dispatches with the cached formation/floor/biome and routes to
## dungeon_run_view via the orchestrator's state_changed → ACTIVE_FOREGROUND
## transition (same path formation_assignment uses).
extends Screen

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")

@onready var _dispatch_nav_button: Button = $DispatchNavButton
@onready var _redispatch_button: Button = $RedispatchButton


func _ready() -> void:
	# Touch feedback is wired in _ready (one-time, .tscn-defined Buttons) so it
	# survives screen re-entry without double-connection. UIFramework's meta
	# sentinel makes wire_touch_feedback idempotent regardless of call site.
	UIFrameworkScript.wire_touch_feedback(_dispatch_nav_button)
	UIFrameworkScript.wire_touch_feedback(_redispatch_button)


func on_enter() -> void:
	if not _dispatch_nav_button.pressed.is_connected(_on_dispatch_nav_pressed):
		_dispatch_nav_button.pressed.connect(_on_dispatch_nav_pressed)
	if not _redispatch_button.pressed.is_connected(_on_redispatch_pressed):
		_redispatch_button.pressed.connect(_on_redispatch_pressed)
	# Subscribe to orchestrator state_changed to navigate into dungeon_run_view
	# when re-dispatch succeeds (mirrors formation_assignment.gd:373 pattern).
	if not DungeonRunOrchestrator.state_changed.is_connected(_on_orchestrator_state_changed):
		DungeonRunOrchestrator.state_changed.connect(_on_orchestrator_state_changed)
	_refresh_redispatch_visibility()


func on_exit() -> void:
	if _dispatch_nav_button != null and _dispatch_nav_button.pressed.is_connected(_on_dispatch_nav_pressed):
		_dispatch_nav_button.pressed.disconnect(_on_dispatch_nav_pressed)
	if _redispatch_button != null and _redispatch_button.pressed.is_connected(_on_redispatch_pressed):
		_redispatch_button.pressed.disconnect(_on_redispatch_pressed)
	if DungeonRunOrchestrator.state_changed.is_connected(_on_orchestrator_state_changed):
		DungeonRunOrchestrator.state_changed.disconnect(_on_orchestrator_state_changed)


func on_pause() -> void:
	pass


func on_resume() -> void:
	pass


## Toggles RedispatchButton visibility based on whether the orchestrator has
## a cached last_dispatch_intent. Called from on_enter and after a re-dispatch
## (which cycles back through main_menu only on RUN_ENDED routing).
func _refresh_redispatch_visibility() -> void:
	if _redispatch_button == null:
		return
	var intent: Dictionary = DungeonRunOrchestrator.get_last_dispatch_intent()
	_redispatch_button.visible = not intent.is_empty()


func _on_dispatch_nav_pressed() -> void:
	SceneManager.request_screen("formation_assignment", SceneManager.TransitionType.CROSS_FADE)


## Sprint 14 S14-N2: re-dispatch using the orchestrator's cached intent.
## Mirrors formation_assignment.gd:_on_dispatch_pressed (calls
## DungeonRunOrchestrator.dispatch with the same arg shape) — the orchestrator
## owns state advance + scene navigation via state_changed → ACTIVE_FOREGROUND.
func _on_redispatch_pressed() -> void:
	var intent: Dictionary = DungeonRunOrchestrator.get_last_dispatch_intent()
	if intent.is_empty():
		# Defensive — visibility check should prevent this path, but guard
		# against race conditions (e.g. orchestrator state cleared between
		# refresh + press).
		_refresh_redispatch_visibility()
		return
	var formation: Array = intent.get("formation", []) as Array
	var floor_index: int = int(intent.get("floor_index", 0))
	var biome_id: String = String(intent.get("biome_id", ""))
	DungeonRunOrchestrator.dispatch(formation, floor_index, biome_id)


## Sprint 14 S14-N2: navigate to dungeon_run_view when orchestrator transitions
## to ACTIVE_FOREGROUND (post-redispatch). Mirrors formation_assignment.gd:373
## with a CROSS_FADE transition (matching the main_menu → formation_assignment
## fade tone) instead of FADE_TO_BLACK (which formation_assignment uses for the
## more cinematic "entering the dungeon" beat).
func _on_orchestrator_state_changed(new_state: int, _old_state: int) -> void:
	if new_state == DungeonRunStateScript.State.ACTIVE_FOREGROUND:
		SceneManager.request_screen("dungeon_run_view", SceneManager.TransitionType.CROSS_FADE)
