## Screen — Base class for every managed screen in the SceneManager system.
##
## Declared under SceneManager module ownership (src/core/scene_manager/) rather than
## assets/screens/_base/ because this is Foundation-layer infrastructure consumed by
## all Presentation-layer screens.
##
## Every screen MUST extend this class and MUST declare all four lifecycle hooks:
## on_enter(), on_exit(), on_pause(), on_resume(). Empty-body declarations are
## acceptable; silently omitting any hook is FORBIDDEN (enforced by
## tools/ci/check_screen_hooks.sh and the unit test suite).
##
## --- PROCESS MODE WARNING (ADR-0007 Risks Note 4) ---
## Children of a Screen subclass inherit PROCESS_MODE_PAUSABLE from ScreenContainer.
## Child nodes that need to keep running during a modal overlay (e.g., a looping idle
## particle, a persistent counter animation) MUST explicitly set PROCESS_MODE_ALWAYS
## on that specific child. The Screen base class itself does NOT set process_mode —
## it inherits whatever ScreenContainer specifies at runtime.
##
## --- TWEEN WARNING (ADR-0007 Risks Note 1) ---
## Tweens created inside a Screen child inherit Tween.TWEEN_PAUSE_BOUND from
## ScreenContainer (PROCESS_MODE_PAUSABLE), so they will FREEZE during modal pause
## automatically — which is usually correct. To keep a tween running during modal
## pause, either create it from a node with process_mode = Node.PROCESS_MODE_ALWAYS,
## or call tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) explicitly.
##
## Governing ADR: ADR-0007 (§Screen base class lifecycle contract)
## Requirements: TR-scene-manager-005, TR-scene-manager-028
class_name Screen extends Control

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Optional per-screen override for enter-transition duration (milliseconds).
## 0 = use SceneManager default (from EconomyConfig or SceneManager constants).
## Matches GDD §G Tuning Knobs "Per-screen duration overrides" (TR-scene-manager-028).
## Negative values are clamped to 0 with a push_warning by Story 005's
## transition dispatcher — this story only declares the export surface.
@export var transition_override_ms: int = 0

# ---------------------------------------------------------------------------
# Lifecycle hooks
# ---------------------------------------------------------------------------

## Called by SceneManager AFTER this screen becomes current_screen (post-transition).
## Connect signals here; initialize UI from the game data model.
## Do NOT assume any state was preserved from a prior visit — treat each call as
## a fresh initialization.
func on_enter() -> void:
	pass


## Called by SceneManager BEFORE queue_free is called on this screen.
## Disconnect any signals connected in on_enter; flush deferred or in-flight work.
## After this returns, SceneManager will free the node — do not store references
## to this screen that would outlive the call.
func on_exit() -> void:
	pass


## Called by SceneManager when a modal overlay opens on top of this screen.
## The screen is NOT freed; visual continuity is preserved beneath the overlay.
## Pause any animations, timers, or tooltip cycles that would be confusing or
## distracting while the overlay is active.
##
## TWEEN NOTE (ADR-0007 Risks Note 1): Tweens created inside Screen children
## inherit Tween.TWEEN_PAUSE_BOUND from ScreenContainer (PROCESS_MODE_PAUSABLE),
## so they freeze automatically during modal pause. To keep a specific tween
## running, call tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) on it, or
## create it from a node whose process_mode is Node.PROCESS_MODE_ALWAYS.
func on_pause() -> void:
	pass


## Called by SceneManager when the modal overlay closes and this screen becomes
## interactive again. Restore animations, timers, and tooltip cycles that were
## paused in on_pause().
func on_resume() -> void:
	pass


# ---------------------------------------------------------------------------
# Global Esc → Pause Menu (Sprint 23 S23-M2)
# ---------------------------------------------------------------------------

## Routes the `ui_cancel` action (default Esc) into the Pause Menu overlay.
## This applies to every Screen subclass — no per-screen wiring required.
##
## Guard conditions:
## - SceneManager state must be IDLE (no Esc handling mid-transition)
## - No freestanding modal (e.g., HeroDetail, MidRunReassignConfirmation)
##   already active — those modals own the Esc semantics for their context
## - Pause Menu must not already be in the overlay stack — avoids
##   re-pushing on a held key
##
## The Pause Menu's own `_unhandled_input` handles Esc-to-dismiss; calling
## get_viewport().set_input_as_handled() inside the modal stops the event
## from bubbling back here.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if SceneManager == null or SceneManager.state != SceneManager.State.IDLE:
		return
	# Freestanding modals (Hero Detail, MidRunReassign, …) own Esc themselves.
	if SceneManager.active_freestanding_modal_count() > 0:
		return
	# Don't re-push if pause_menu (or any overlay) is already active.
	if SceneManager.active_overlay_count() > 0:
		return
	get_viewport().set_input_as_handled()
	SceneManager.push_overlay("pause_menu", true)
