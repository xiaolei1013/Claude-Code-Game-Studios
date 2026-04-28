## UIFramework — Sprint 8 minimum stub per ADR-0008.
##
## Non-autoload static helper module (class_name UIFramework). NOT registered in
## the ADR-0003 rank table. Accessed via UIFramework.method_name() static calls.
## No Node, no _ready(), no signals from the framework itself.
##
## Sprint 8 VS scope: implements the two helpers required by Story 011
## (FormationAssignment screen). Full surface documented in ADR-0008 §Module
## structure; remaining helpers are deferred to the UIFramework authoring epic.
##
## ## TODO (ADR-0008 Required Patterns — post Story 011):
## - `apply_parchment_panel(panel, pattern)` — theme_type_variation binder for
##   ParchmentPanel / DECORATIVE panels. Blocked on parchment_theme.tres content
##   authoring (empty Theme placeholder for Sprint 8 VS).
## - `wire_touch_feedback(control)` — 1.05× scale pulse, 80 ms, 1-frame return.
##   Blocked on Art Bible §7 Animation Feel integration pass (post Sprint 8).
##
## Governing ADR: ADR-0008 (§Module structure, §Tap-target enforcement,
##                            §Single-focus-mode strategy)
## Story: Story 011 — Formation Assignment Screen
class_name UIFramework

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Minimum interactive tap-target size in logical pixels (both axes).
##
## Set by Art Bible §7 UX Constraints for mobile-port readiness. Every Button /
## interactive Control must meet this floor. Enforcement is debug-only to avoid
## production runtime cost (Pillar 1 performance budget).
##
## ADR-0008 §Tap-target enforcement
const MIN_TAP_TARGET_LOGICAL_PX: int = 44


# ---------------------------------------------------------------------------
# Tap-target enforcement
# ---------------------------------------------------------------------------

## Asserts that [param control] meets the 44×44 logical-pixel tap-target floor.
##
## Debug-build only — returns immediately in production builds via
## [code]OS.is_debug_build()[/code] early-out (zero cost in production).
##
## Logs [code]push_error[/code] (NOT assert(false)) so designers iterating layouts
## see a loud warning in the editor output without crashing the editor session.
##
## Example:
##   [codeblock]
##   func _ready() -> void:
##       UIFramework.assert_tap_target_min(%DispatchButton)
##   [/codeblock]
##
## ADR-0008 §assert_tap_target_min
static func assert_tap_target_min(control: Control) -> void:
	if not OS.is_debug_build():
		return
	var size: Vector2 = control.get_combined_minimum_size()
	if size.x < MIN_TAP_TARGET_LOGICAL_PX or size.y < MIN_TAP_TARGET_LOGICAL_PX:
		push_error(
			"[UIFramework] Tap target below %d px floor: %s (size=%s). "
			% [MIN_TAP_TARGET_LOGICAL_PX, control.name, size]
			+ "Set custom_minimum_size to at least Vector2(%d, %d)."
			% [MIN_TAP_TARGET_LOGICAL_PX, MIN_TAP_TARGET_LOGICAL_PX]
		)


# ---------------------------------------------------------------------------
# Focus suppression
# ---------------------------------------------------------------------------

## Walks [param root] and all Control descendants, setting [code]focus_mode =
## FOCUS_NONE[/code] on every Button / TextureButton / BaseButton found.
## Also sets FOCUS_NONE on [param root] itself if it is a BaseButton subclass.
##
## This is the single-focus-mode strategy per ADR-0008: the project does NOT
## implement keyboard/gamepad navigation in MVP (technical-preferences.md
## "Gamepad Support: None"). Suppressing focus_mode prevents the 4.6 dual-focus
## system from rendering a keyboard/gamepad focus ring on interactive controls.
##
## Note: [code]focus_mode[/code] is NOT a Theme-settable property in Godot 4.6.
## It must be set per Control instance — either in the .tscn Inspector or at
## runtime via this helper. Calling it in [code]on_enter()[/code] is the
## recommended runtime path because it covers dynamically-created Button
## instances (e.g., roster hero buttons created in _refresh_roster_panel).
##
## Keyboard shortcuts (e.g., Esc for Settings) still function via
## [code]_unhandled_input[/code] action mapping — they do NOT require
## [code]focus_mode = FOCUS_ALL[/code].
##
## Example:
##   [codeblock]
##   func on_enter() -> void:
##       UIFramework.suppress_keyboard_focus(self)
##   [/codeblock]
##
## ADR-0008 §Single-focus-mode strategy
static func suppress_keyboard_focus(root: Control) -> void:
	# Suppress focus on root itself if it is an interactive control type.
	if root is BaseButton:
		(root as Control).focus_mode = Control.FOCUS_NONE
	# Walk all Control descendants (recursive = true, owned_by_scene = false so
	# dynamically-instantiated children are included).
	var children: Array = root.find_children("*", "Control", true, false)
	for child: Variant in children:
		var ctrl: Control = child as Control
		if ctrl == null:
			continue
		if ctrl is BaseButton:
			ctrl.focus_mode = Control.FOCUS_NONE
