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

# ---------------------------------------------------------------------------
# Parchment palette (DESIGN.md §Color — Art Bible §4, locked by ADR-0008)
# ---------------------------------------------------------------------------
# The canonical Color constants the DESIGN.md "Godot Theme implementation"
# translation guide refers to. Hex strings match DESIGN.md §Color exactly
# (Color() parses "#RRGGBB" as sRGB). Usage rules: Slate Ink replaces pure black
# everywhere (rule #1); no pure-saturated literals (rule #2). Themed widgets
# that build colors in code (e.g. ParchmentKit) reference these, never raw hex.

## Player-controlled territory / primary interactive state. #C8872A
const GUILD_AMBER: Color = Color("#C8872A")
## Reward + progression highlight — the game's highest-attention color. #F2B83B
const LANTERN_GOLD: Color = Color("#F2B83B")
## UI ground / panel backgrounds. #EDE0C4
const PARCHMENT_CREAM: Color = Color("#EDE0C4")
## Enemy territory / dungeon ambient / locked content. #5B4A72
const DUSK_PURPLE: Color = Color("#5B4A72")
## Forest biome / environmental nature accent. #7A8C5E
const MOSS_SAGE: Color = Color("#7A8C5E")
## Danger indicator / enemy power tier / warning register. #A84C2F
const EMBER_RUST: Color = Color("#A84C2F")
## Typography, sprite outlines, deep shadow — never pure black. #2C2838
const SLATE_INK: Color = Color("#2C2838")

## Gold-counter pulse rise duration (color → Guild Amber). Recruit GDD §C.3: 100 ms.
const GOLD_PULSE_RISE_SEC: float = 0.10
## Gold-counter pulse settle duration (Guild Amber → resting). Recruit GDD §C.3: 200 ms.
const GOLD_PULSE_FALL_SEC: float = 0.20
## Meta sentinel holding a gold counter's in-flight pulse Tween (kill-on-restart).
const _GOLD_PULSE_TWEEN_META: StringName = &"ui_framework_gold_pulse_tween"

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


# ---------------------------------------------------------------------------
# Gold-counter pulse
# ---------------------------------------------------------------------------

## Pulses [param label]'s font color toward Guild Amber and back — the "gold
## changed" feedback shared by the Guild Hall, Recruit, and Dungeon Run gold
## counters (the three counters VFX GDD #27 §F enumerates), so the timing and
## color stay in lockstep across screens.
##
## A COLOR pulse, deliberately not a scale pulse: the gold counter is a centered
## Label, and a scale tween would reflow neighbouring layout / fight the touch
## pulse's transform. Recruit GDD §C.3 specifies the motion — font color shifts
## to Guild Amber over ~100 ms, then settles back over ~200 ms (≤300 ms total).
##
## WHICH gold_changed reasons pulse (recruit / level_up / floor_clear / kill —
## never the idle drip) is the caller's decision; this helper only renders.
##
## Reduce-motion (ADR-0007): when [param reduce_motion] is true the pulse is
## suppressed entirely. The caller has already snapped the counter text, so the
## value change is still conveyed — just without animation.
##
## Self-contained tween lifecycle: a meta sentinel holds the in-flight Tween so a
## rapid burst of triggers (e.g. a quick double-tap recruit) kills-and-restarts
## rather than stacking overlapping color tweens. The font_color override is
## removed on completion so the label falls back to its themed resting color.
##
## This is the low-level primitive — it pulses unconditionally. Screens reacting
## to [signal Economy.gold_changed] should call [method pulse_gold_on_reason] so
## the "which gold changes pulse" policy stays centralized.
##
## ADR-0008 §Touch feedback (sibling pulse effect) + VFX GDD #27.
static func pulse_gold_counter(label: Label, reduce_motion: bool = false) -> void:
	if label == null:
		push_error("[UIFramework] pulse_gold_counter called with null label.")
		return
	# Kill any in-flight pulse so a burst of gold_changed signals restarts
	# cleanly instead of stacking overlapping color tweens on the same label.
	if label.has_meta(_GOLD_PULSE_TWEEN_META):
		var prior: Tween = label.get_meta(_GOLD_PULSE_TWEEN_META) as Tween
		if prior != null and prior.is_valid():
			prior.kill()
		label.remove_meta(_GOLD_PULSE_TWEEN_META)
	# Drop any leftover font_color override so the captured resting color is the
	# label's themed color, never a mid-pulse tint. Our gold counters derive
	# their resting color from the IdentityHeader theme variation (Lantern Gold),
	# not a local override — see guild_hall.tscn $GoldCounter — so clearing the
	# override here both restores the true base and keeps rapid bursts drift-free.
	if label.has_theme_color_override("font_color"):
		label.remove_theme_color_override("font_color")
	# Reduce-motion (ADR-0007): no animation; the caller has already snapped text.
	if reduce_motion:
		return
	var base: Color = label.get_theme_color("font_color")
	var tw: Tween = label.create_tween()
	tw.tween_method(
		_apply_label_font_color.bind(label), base, GUILD_AMBER, GOLD_PULSE_RISE_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(
		_apply_label_font_color.bind(label), GUILD_AMBER, base, GOLD_PULSE_FALL_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(_clear_gold_pulse.bind(label), CONNECT_ONE_SHOT)
	label.set_meta(_GOLD_PULSE_TWEEN_META, tw)


## Internal — tween_method target for [method pulse_gold_counter]. Applies the
## interpolated [param c] as a font_color override. [code]Callable.bind(label)[/code]
## appends the label AFTER the interpolated value, so the signature is
## [code](c, label)[/code], not [code](label, c)[/code].
static func _apply_label_font_color(c: Color, label: Label) -> void:
	if label != null:
		label.add_theme_color_override("font_color", c)


## Internal — gold-pulse completion: drop the override (fall back to the themed
## resting color) and clear the in-flight-tween sentinel.
static func _clear_gold_pulse(label: Label) -> void:
	if label == null:
		return
	label.remove_theme_color_override("font_color")
	if label.has_meta(_GOLD_PULSE_TWEEN_META):
		label.remove_meta(_GOLD_PULSE_TWEEN_META)


## True when an [signal Economy.gold_changed] [param reason] denotes a discrete,
## player-initiated transaction worth a gold-counter pulse.
##
## Matches ONLY the spend reasons Economy actually emits (verified against
## economy.gd, recruitment.gd, hero_detail_modal.gd — 2026-06-23):
##   - [code]"level_up"[/code]            — hero level-up spend (hero_detail_modal.gd)
##   - [code]"recruit_<class_id>"[/code]  — hero recruit spend; class-suffixed, so
##                                          matched by the [code]"recruit_"[/code] prefix
##   - [code]"recruit_pool_refresh"[/code] — paid pool refresh (also "recruit_"-prefixed)
##
## Deliberately EXCLUDES the earn + system reasons — they are NOT discrete player
## actions and pulsing on them would strobe or mislead:
##   - [code]"add_gold"[/code]          — the foreground idle drip credits this EVERY
##                                        tick (economy.gd [code]_on_tick[/code]) AND
##                                        once per kill (dungeon_run_orchestrator), so
##                                        pulsing would throb continuously through a run.
##   - [code]"first_launch_seed"[/code] — one-time boot grant; a boot pulse is noise.
##   - [code]"offline_replay"[/code] / [code]"offline_replay_aggregate"[/code] — the
##                                        offline-return lump has its own return beat.
##
## NOTE: this supersedes VFX GDD #27 §F's literal {recruit, level_up, floor_clear,
## kill} list — floor_clear/kill earns are emitted as the generic "add_gold" reason
## and cannot be isolated here without an Economy-level reason change.
static func is_gold_pulse_reason(reason: String) -> bool:
	return reason == "level_up" or reason.begins_with("recruit_")


## Pure trigger policy for dungeon_run_view's reward FLOATS — the rising "+N gold"
## / "Lv N" numbers (S30-S1, GDD #27 OQ-27-1 reward beats). Lives here beside
## [method is_gold_pulse_reason] so the policy is one testable predicate, decoupled
## from the screen scene (see tests/unit/ui_framework/should_float_reward_test.gd).
##
## Floats ONLY two discrete, human-frequency reward beats:
##   - [code]"gold_kill"[/code] — a kill that actually credited gold; a zero-gold
##                                kill (e.g. an unknown tier → base 0) floats nothing,
##                                so [param amount] must be > 0.
##   - [code]"level_up"[/code]  — a hero reaching a new level; ALWAYS floats (a
##                                discrete beat — [param amount] is ignored).
## Every other event — the per-tick [code]"add_gold"[/code] drip, and any per-hit /
## damage event (NONE exists to subscribe to: the resolver aggregates DPS and emits
## no per-hit signal, ADR-0025 §C.5, so floating one would be a fiction) — returns
## false. Mirrors how [method is_gold_pulse_reason] excludes the continuous drip.
static func should_float_reward(event_type: String, amount: int = 0) -> bool:
	match event_type:
		"gold_kill":
			return amount > 0
		"level_up":
			return true
		_:
			return false


## Reason-gated gold pulse: pulses [param label] via [method pulse_gold_counter]
## only when [param reason] passes [method is_gold_pulse_reason]. Every screen
## bound to [signal Economy.gold_changed] (Guild Hall, Recruitment, Hero Detail,
## Expedition) calls this from its handler, so the trigger policy lives in one
## place rather than being re-derived — and drifting — per screen.
static func pulse_gold_on_reason(label: Label, reason: String, reduce_motion: bool = false) -> void:
	if is_gold_pulse_reason(reason):
		pulse_gold_counter(label, reduce_motion)


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
	# Round to the one-decimal display value FIRST, then promote to the next
	# suffix when rounding lands on 1000.0 — e.g. 999_999 rounds to "1000.0K",
	# which must render as "1.0M", not "1000.0K" (same guard at the M/B/T edges).
	# Using the snapped value for BOTH the branch test and the display keeps them
	# consistent (no double-rounding skew between the %.1f format and the test).
	var q_k: float = snappedf(float(value) / 1_000.0, 0.1)
	if value < m_threshold and q_k < 1000.0:
		return "%.1fK" % q_k
	var q_m: float = snappedf(float(value) / 1_000_000.0, 0.1)
	if value < b_threshold and q_m < 1000.0:
		return "%.1fM" % q_m
	var q_b: float = snappedf(float(value) / 1_000_000_000.0, 0.1)
	if value < t_threshold and q_b < 1000.0:
		return "%.1fB" % q_b
	return "%.1fT" % snappedf(float(value) / 1_000_000_000_000.0, 0.1)


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


# ---------------------------------------------------------------------------
# Sprint 24 S24-M3 — Hygiene helpers (container refresh + synergy display)
# ---------------------------------------------------------------------------

## Detaches every child of [param container] from the tree IMMEDIATELY,
## then queue_frees it. queue_free alone is deferred to the next idle
## frame, which lets a rebuild within the same frame stack stale children
## on top of fresh ones (e.g., add_hero → hero_recruited → refresh handler
## before queue_free has run). Sprint 23 S23-M1 surfaced this as a latent
## flake in Guild Hall's roster panel; Sprint 24 S24-M3 hoists the pattern
## here so every screen-refresh call site uses the same idiom.
##
## Defensive: silently no-ops on a null container.
static func clear_children_immediate(container: Node) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Returns the localized display name for a V1 synergy_id, e.g.
## `"Steel Wall"` for `"steel_wall"`. Routes through `tr()` with the
## writer-locked `class_synergy_badge_<id>` key set defined in
## `assets/locale/en.csv`.
##
## Defensive: empty `synergy_id` returns an empty string (caller is
## expected to short-circuit before calling). Unknown synergy_id returns
## the verbatim key — non-empty and readable, matching the existing
## `tr()` fallback semantics.
##
## Sprint 24 S24-M3 — consolidates 3 pre-existing call sites of the
## `tr("class_synergy_badge_" + synergy_id)` idiom across `guild_hall.gd`
## (synergy badge), `formation_assignment.gd` (badge), and
## `formation_assignment.gd` (preview label).
static func synergy_display_name(synergy_id: String) -> String:
	if synergy_id.is_empty():
		return ""
	# Static method context — uses TranslationServer.translate, not tr()
	# (tr() requires a Node context). Matches the pattern established by
	# `format_localized` above.
	return TranslationServer.translate("class_synergy_badge_" + synergy_id)


## Maps V1 `synergy_id` to V2 tier key per `class-synergy-system.md` §C.6.
## Pure function — safe to call every UI refresh. O(1) string switch.
##
## Returns the lowercase tier key (used as suffix for `synergy_tier_<key>`
## locale lookups): `"none"` | `"bronze"` | `"silver"` | `"gold"` | `"platinum"`.
##
## Defensive: unknown `synergy_id` degrades to `"none"`.
##
## Sprint 24 S24-M3 — hoisted from `formation_assignment.gd::_synergy_id_to_tier`
## (added in S24-M2) so future tier-aware UI surfaces (Guild Hall synergy
## summary, toast variants, badge color treatment) can reuse the mapping
## without duplicating the switch logic.
##
## AC-CS-22..25 — see `class-synergy-system.md` §H.
static func synergy_id_to_tier(synergy_id: String) -> String:
	match synergy_id:
		"":               return "none"
		"steel_wall":     return "gold"
		"arcane_elite":   return "gold"
		"triple_strike":  return "gold"
		"triple_threat":  return "platinum"
		# Tier-2 mono-class synergies (3-of-a-kind for each tier-2 class).
		# Same Gold tier as the V1 mono-class set. Vigil is XP-only (mirrors
		# Arcane Elite); the other three are conditional gold.
		"bastion":        return "gold"
		"volley":         return "gold"
		"frenzy":         return "gold"
		"vigil":          return "gold"
		_:                return "none"


## Resolves the writer-locked effect text for [param synergy_id]. Returns
## the localized string from the `class_synergy_effect_<id>` locale key
## (e.g., "+25% gold vs bruisers"), or an empty string when no synergy is
## active.
##
## Rule-of-Three hoist: this lookup is performed at 3 call sites
## (formation_assignment screen's synergy badge + synergy preview label,
## plus Guild Hall's synergy summary if/when it lands). Centralizing here
## keeps the locale-key convention in one place and parallels the existing
## [method synergy_display_name] helper next door.
##
## Defensive: empty [param synergy_id] returns empty string (no effect to
## render).
static func synergy_effect_text(synergy_id: String) -> String:
	if synergy_id == "":
		return ""
	return TranslationServer.translate("class_synergy_effect_" + synergy_id)


# ---------------------------------------------------------------------------
# Injury marks (GDD #34 Phase 3 / ADR-0021 — AC-34-09)
# ---------------------------------------------------------------------------

## Node name of the additive injury badge Label attached to a hero card / slot.
## Stable so screen tests can locate it via [code]get_node_or_null[/code] and so
## [method mark_injured] can update an existing badge in place rather than
## stacking duplicates across panel refreshes.
const INJURED_BADGE_NAME: StringName = &"InjuredBadge"

## Modulate alpha applied to an injured hero card / slot. A 50% fade reads as
## "unavailable" WITHOUT relying on hue (colorblind-safe per ui-code rules —
## the literal "Injured" badge text is the primary, non-color signal). Mirrors
## the existing toast [code]modulate.a[/code] fade idiom rather than introducing
## a palette Color literal (DESIGN.md / ADR-0008 §no-Color-literals).
const INJURED_DIM_ALPHA: float = 0.5

## Theme type variation the injury badge resolves against, so a future
## parchment_theme.tres pass can style it (warm "field-dressing" tag look)
## without touching call sites. Falls back to default Label styling until then.
const INJURED_BADGE_VARIATION: StringName = &"InjuredBadge"


## Formats a wall-clock recovery remainder (in whole seconds) as a compact
## human countdown for the injury badge. Coarsens to the largest meaningful
## unit so a 30-minute recovery reads "30m" rather than "1800s":
##   [code]3725[/code] → [code]"1h 2m"[/code]
##   [code]1800[/code] → [code]"30m"[/code]
##   [code]90[/code]   → [code]"1m"[/code]
##   [code]45[/code]   → [code]"45s"[/code]
##   [code]0[/code] / negative → [code]""[/code] (caller renders the bare
##   "Injured" label; recovery is effectively complete).
##
## Pure function (no Node / autoload / locale dependency) → directly unit-testable.
static func format_recovery_countdown(remaining_seconds: int) -> String:
	if remaining_seconds <= 0:
		return ""
	var hours: int = remaining_seconds / 3600
	var minutes: int = (remaining_seconds % 3600) / 60
	var seconds: int = remaining_seconds % 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	if minutes > 0:
		return "%dm" % minutes
	return "%ds" % seconds


## Marks [param card] (a hero card Button or formation slot Button) as injured:
## dims it to [constant INJURED_DIM_ALPHA] and attaches (or updates) an additive,
## non-interactive [constant INJURED_BADGE_NAME] Label showing "Injured · <countdown>".
##
## ADDITIVE contract (project memory: screen-node hard-path coupling — never
## reparent): the badge is a NEW child of [param card]; nothing in the existing
## card subtree moves. The badge is [code]MOUSE_FILTER_IGNORE[/code] so taps pass
## straight through to the parent Button (an injured hero is still tappable for
## inspection / slot assignment — only DISPATCH is gated, per AC-34-04). Anchored
## top-right so it doesn't obscure the hero name/level text drawn top-left.
##
## Idempotent: re-marking an already-marked card updates the badge text in place
## instead of stacking a second Label (safe to call every panel refresh).
##
## ADR-0008 §mouse_filter defaults (decorative overlays IGNORE).
static func mark_injured(card: Control, remaining_seconds: int) -> void:
	if card == null:
		push_error("[UIFramework] mark_injured called with null card.")
		return
	card.modulate.a = INJURED_DIM_ALPHA
	var badge: Label = card.get_node_or_null(NodePath(INJURED_BADGE_NAME)) as Label
	if badge == null:
		badge = Label.new()
		badge.name = INJURED_BADGE_NAME
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.theme_type_variation = INJURED_BADGE_VARIATION
		# Top-right corner — keeps the name/level (drawn top-left) legible.
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		card.add_child(badge)
	var countdown: String = format_recovery_countdown(remaining_seconds)
	if countdown.is_empty():
		badge.text = format_localized("injured_badge_label", [])
	else:
		badge.text = format_localized("injured_badge_format", [countdown])


## Reverses [method mark_injured]: restores full opacity and removes the injury
## badge if present. A no-op on a card that was never marked. Provided for
## symmetry / live recovery without a full panel rebuild; the screens currently
## rebuild cards each refresh, so a recovered hero simply renders unmarked.
static func clear_injured(card: Control) -> void:
	if card == null:
		return
	card.modulate.a = 1.0
	var badge: Node = card.get_node_or_null(NodePath(INJURED_BADGE_NAME))
	if badge != null:
		card.remove_child(badge)
		badge.queue_free()
