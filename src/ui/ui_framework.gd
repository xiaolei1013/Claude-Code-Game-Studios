## UIFramework — non-autoload static helper module (class_name UIFramework).
##
## NOT registered in the ADR-0003 rank table. Accessed via
## UIFramework.method_name() static calls. No Node, no _ready(), no signals
## from the framework itself.
##
## Public API (ADR-0008 §Module structure):
##   - assert_tap_target_min(control)         — debug-only 44×44 tap-target check
##   - suppress_keyboard_focus(root)          — single-focus-mode walk
##   - apply_parchment_panel(panel, pattern)  — ParchmentPanel theme variation binder
##   - wire_touch_feedback(control)           — 1.05× scale pulse, 80 ms, 1-frame return
##
## Governing ADR: ADR-0008 (§Module structure, §Tap-target enforcement,
##                            §Single-focus-mode strategy, §Touch feedback)
## History: Sprint 8 Story 011 (assert_tap_target_min + suppress_keyboard_focus);
##          Sprint 10 S10-M2 (apply_parchment_panel + wire_touch_feedback —
##          unblocked once parchment_theme.tres content was authored in S10-M1).
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

## Touch-feedback pulse magnitude. Per Art Bible §7 Animation Feel:
## "scale pulse of approximately 1.05× for 80ms, followed by return to 1.0×".
const TOUCH_PULSE_SCALE: Vector2 = Vector2(1.05, 1.05)

## Touch-feedback pulse expand duration in seconds (80 ms).
const TOUCH_PULSE_EXPAND_SEC: float = 0.08

## Touch-feedback pulse return duration in seconds (~1 frame at 60 fps).
const TOUCH_PULSE_RETURN_SEC: float = 0.016

## Meta-key sentinel that marks a Control as already wired for touch feedback.
## Prevents double-connection if [code]wire_touch_feedback[/code] is called more
## than once on the same Control (e.g., across re-entry into a screen's
## [code]on_enter()[/code]). Lambdas connected to a signal have no stable
## identity for [code]is_connected[/code] checks, so a meta sentinel is the
## simplest idempotency guard.
const _TOUCH_FEEDBACK_META: StringName = &"ui_framework_touch_feedback_wired"

## ParchmentPanel application pattern.
## - [code]STANDARD[/code]: panel intercepts taps (mouse_filter unchanged from
##   the panel's own setting; defaults to STOP for PanelContainer).
## - [code]DECORATIVE[/code]: purely-visual panel that should not intercept
##   taps; mouse_filter is forced to PASS so child controls receive input.
##
## ADR-0008 §apply_parchment_panel.
enum PanelPattern { STANDARD, DECORATIVE }


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


# ---------------------------------------------------------------------------
# Parchment-panel binder
# ---------------------------------------------------------------------------

## Applies the [code]ParchmentPanel[/code] theme variation to [param panel] and
## sets the [code]mouse_filter[/code] policy according to [param pattern].
##
## Use this in a screen's [code]_ready()[/code] for any [code]PanelContainer[/code]
## (or [code]Panel[/code], or any [code]Control[/code] subclass that resolves
## a [code]theme_type_variation[/code]) that should render with the warm-document
## styling defined in [code]parchment_theme.tres[/code].
##
## Pass [code]PanelPattern.DECORATIVE[/code] for purely-visual panels (parchment
## backgrounds, ink ornament wrappers) so they do not intercept taps from
## interactive children. Pass [code]PanelPattern.STANDARD[/code] (the default)
## for panels that legitimately consume tap events at their own level.
##
## Idempotent: setting the same [code]theme_type_variation[/code] twice is a
## no-op cost; setting [code]mouse_filter[/code] twice is also free.
##
## Example:
##   [codeblock]
##   func _ready() -> void:
##       UIFramework.apply_parchment_panel($RosterPanel)
##       UIFramework.apply_parchment_panel($BackgroundOrnament,
##           UIFramework.PanelPattern.DECORATIVE)
##   [/codeblock]
##
## ADR-0008 §apply_parchment_panel + §mouse_filter default policy.
static func apply_parchment_panel(panel: Control, pattern: PanelPattern = PanelPattern.STANDARD) -> void:
	if panel == null:
		push_error("[UIFramework] apply_parchment_panel called with null panel.")
		return
	panel.theme_type_variation = &"ParchmentPanel"
	if pattern == PanelPattern.DECORATIVE:
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
	# else STANDARD: leave mouse_filter at the panel's existing value (theme
	# defaults to STOP for PanelContainer; instances may override per-screen).


# ---------------------------------------------------------------------------
# Touch-feedback pulse
# ---------------------------------------------------------------------------

## Wires a 1.05× scale pulse (80 ms expand, 1-frame return) onto [param control]
## that fires every time the Control receives a mouse-button-down or screen-touch-
## down [code]gui_input[/code] event.
##
## Per Art Bible §7 Animation Feel: "every tap produces an immediate visual
## response within one frame (16ms). The response is a scale pulse of
## approximately 1.05× for 80ms, followed by return to 1.0×. This must be felt
## on mobile before it is seen — the scale is small, but it is instant."
##
## Idempotent: a meta sentinel ([code]_TOUCH_FEEDBACK_META[/code]) prevents
## double-wiring if this is called repeatedly on the same Control (e.g., across
## screen re-entry into [code]on_enter()[/code]). When the Control is freed,
## the bound Callable is automatically released by Godot.
##
## Per ADR-0008 §wire_touch_feedback: the pulse is opt-in per interactive
## Control rather than encoded in the theme, both because Theme cannot tween
## animations and because performance-dense screens (DungeonRunView) may opt
## out per-element to keep tween count bounded.
##
## Example:
##   [codeblock]
##   func on_enter() -> void:
##       UIFramework.wire_touch_feedback(%DispatchButton)
##   [/codeblock]
##
## ADR-0008 §Touch feedback (1.05× scale, 80ms) — owned by individual screens.
static func wire_touch_feedback(control: Control) -> void:
	if control == null:
		push_error("[UIFramework] wire_touch_feedback called with null control.")
		return
	if control.has_meta(_TOUCH_FEEDBACK_META):
		return
	control.set_meta(_TOUCH_FEEDBACK_META, true)
	control.gui_input.connect(_on_touch_feedback_input.bind(control))


## Internal — handles a [code]gui_input[/code] event and dispatches a touch
## pulse on mouse-button-down or screen-touch-down. Bound to the wired Control
## via [code]Callable.bind(control)[/code] in [method wire_touch_feedback].
##
## Audio: each press also fires [code]sfx_ui_tap[/code] via AudioRouter per
## audio-system.md AC-AS-14 / AC-AS-15. Wiring on [code]gui_input[/code]
## (press) rather than Button.pressed (release) ensures exactly one chime
## per tap, not two.
static func _on_touch_feedback_input(event: InputEvent, control: Control) -> void:
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_play_touch_pulse(control)
			_fire_ui_tap_chime()
	elif event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			_play_touch_pulse(control)
			_fire_ui_tap_chime()


## Internal — fires [code]sfx_ui_tap[/code] via the AudioRouter autoload.
## Defensive: silently no-ops if AudioRouter is absent (test fixtures that
## don't load the autoload, headless runs without audio device, etc.).
##
## Looking up the autoload via [code]Engine.get_main_loop()[/code] rather
## than [code]get_node()[/code] because this static method has no Node
## context to anchor a relative lookup.
static func _fire_ui_tap_chime() -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var router: Node = loop.root.get_node_or_null("AudioRouter")
	if router == null or not router.has_method("play_sfx"):
		return
	router.play_sfx(&"sfx_ui_tap")


## Safe-format wrapper around [code]tr()[/code] localization keys with format
## specifiers.
##
## In headless / test environments, [code]tr(key)[/code] returns the raw key
## string when the locale isn't loaded — and the raw key contains no
## [code]%[/code] specifier, so applying [code]raw_key % args[/code] raises
## "not all arguments converted during string formatting". This helper checks
## for a [code]%[/code] in the format string and only substitutes when one is
## present; otherwise it returns the format with the args appended as a
## space-separated suffix so the final text is still human-readable.
##
## Hoisted from screen-level duplicate implementations in S10-N1 (Sprint 10
## tr() safe-format pattern). Callers were
## [code]dungeon_run_view._show_run_end_overlay[/code] and
## [code]dungeon_run_view._on_hero_leveled[/code]; both can now call
## [code]UIFramework.format_localized(key, args)[/code] uniformly.
##
## Example:
##   [codeblock]
##   var text: String = UIFramework.format_localized(
##       "hero_level_up_toast_format", [hero_name, new_level])
##   # Loaded EN: "Theron reached level 2!"
##   # Headless test env: "hero_level_up_toast_format Theron 2"
##   [/codeblock]
##
## ADR-0008 §Localization-ready.
##
## Note on the underlying lookup: Object's [code]tr()[/code] method is an
## instance method (not static), so this static helper uses
## [code]TranslationServer.translate(StringName)[/code] — the singleton API
## that [code]tr()[/code] wraps. Result is identical for the main locale path;
## context-specific translations (the second [code]tr()[/code] argument) are
## not supported here. Add an overload if a caller needs it.
static func format_localized(key: String, args: Array) -> String:
	var fmt: String = String(TranslationServer.translate(StringName(key)))
	if "%" in fmt:
		return fmt % args
	# No format specifier — append args as a space-separated suffix.
	if args.is_empty():
		return fmt
	var parts: PackedStringArray = PackedStringArray()
	for arg: Variant in args:
		parts.append(str(arg))
	return fmt + " " + " ".join(parts)


## Formats a numeric value as a compact display string using K / M / B / T
## thresholds per [EconomyConfig] (DISPLAY_K_THRESHOLD = 1000,
## DISPLAY_M_THRESHOLD = 1_000_000, DISPLAY_B_THRESHOLD = 1_000_000_000,
## DISPLAY_T_THRESHOLD = 1_000_000_000_000). Defaults to those values when
## Economy is unavailable (test envs).
##
## Examples:
##   [code]format_short_number(450)[/code] → [code]"450"[/code]
##   [code]format_short_number(1234)[/code] → [code]"1.2K"[/code]
##   [code]format_short_number(4_500_000)[/code] → [code]"4.5M"[/code]
##   [code]format_short_number(7_200_000_000)[/code] → [code]"7.2B"[/code]
##
## Below DISPLAY_K_THRESHOLD: rendered as the integer with no suffix.
## At/above each threshold: divided by the threshold's 10^N base, formatted
## with one decimal place, and appended with the K/M/B/T suffix.
##
## Used by Recruit Screen (#21), Roster / Hero Detail Modal (#22), Victory
## Moment Screen (#25), and any UI surface that displays gold or large
## numeric values.
##
## Sprint 17 S17-S5 — closes the cross-GDD gap surfaced during Sprint 16
## scaffold authoring (the helper was referenced in 3 GDDs but didn't
## exist; landing it pre-emptively unblocks the visual-polish iteration
## scheduled for Sprint 17 M1+M2+S1+S2).
static func format_short_number(value: int) -> String:
	# Negative numbers are not expected (gold is always positive in MVP);
	# format the absolute value with a minus prefix as defensive output.
	if value < 0:
		return "-" + format_short_number(-value)

	# Resolve thresholds from Economy if available; fall back to defaults.
	var k_threshold: int = 1_000
	var m_threshold: int = 1_000_000
	var b_threshold: int = 1_000_000_000
	var t_threshold: int = 1_000_000_000_000
	# Use Engine.get_singleton or autoload-name lookup pattern that
	# safely returns null if Economy is missing (test envs).
	var economy: Object = null
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var root: Window = (main_loop as SceneTree).root
		if root != null:
			economy = root.get_node_or_null("/root/Economy")
	if economy != null and economy.has_method("get_config"):
		var cfg: Resource = economy.call("get_config")
		if cfg != null:
			if "DISPLAY_K_THRESHOLD" in cfg:
				k_threshold = int(cfg.get("DISPLAY_K_THRESHOLD"))
			if "DISPLAY_M_THRESHOLD" in cfg:
				m_threshold = int(cfg.get("DISPLAY_M_THRESHOLD"))
			if "DISPLAY_B_THRESHOLD" in cfg:
				b_threshold = int(cfg.get("DISPLAY_B_THRESHOLD"))
			if "DISPLAY_T_THRESHOLD" in cfg:
				t_threshold = int(cfg.get("DISPLAY_T_THRESHOLD"))

	if value < k_threshold:
		return "%d" % value
	if value < m_threshold:
		return "%.1fK" % (float(value) / 1_000.0)
	if value < b_threshold:
		return "%.1fM" % (float(value) / 1_000_000.0)
	if value < t_threshold:
		return "%.1fB" % (float(value) / 1_000_000_000.0)
	return "%.1fT" % (float(value) / 1_000_000_000_000.0)


## Internal — plays the 1.05× scale pulse via Tween. Centers
## [code]pivot_offset[/code] on the Control's current size so the pulse reads
## as a centered "warm bump" rather than a top-left zoom. Safe to call on a
## just-freed or out-of-tree Control (no-ops if the Control is invalid).
static func _play_touch_pulse(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if not control.is_inside_tree():
		return
	control.pivot_offset = control.size * 0.5
	var tween: Tween = control.create_tween()
	tween.tween_property(control, "scale", TOUCH_PULSE_SCALE, TOUCH_PULSE_EXPAND_SEC)
	tween.tween_property(control, "scale", Vector2.ONE, TOUCH_PULSE_RETURN_SEC)
