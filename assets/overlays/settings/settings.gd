## Settings overlay — volume sliders + reduce_motion toggle + close.
##
## Per Settings GDD #30 §C.1 (minimum-viable subset: 3 volume rows + reduce_motion
## row + close; mute toggle, locale selector, dB display, Reset to Defaults
## deferred to polish iteration).
##
## Invoked from Guild Hall gear icon via SceneManager.push_overlay("settings", false)
## per AC-30-01. Wires:
##   - 3 volume sliders → AudioRouter.set_master_volume_db / set_music_volume_db
##     / set_sfx_volume_db using linear-to-dB curve from GDD §C.2
##   - reduce_motion checkbox → SceneManager.set_reduce_motion (S12-S2 wiring)
##   - close button → SceneManager.pop_overlay (auto-saves via AudioRouter +
##     SceneManager persistence pathways)
extends Control

const ParchmentKitScript = preload("res://src/ui/parchment_kit.gd")
const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")
const _MIN_DB: float = -80.0  # below this, treat as -INF (silent floor)

# Per GDD #30 §C.2 defaults (audio-system.md §C.7 baselines).
const _DEFAULT_MASTER_DB: float = 0.0
const _DEFAULT_MUSIC_DB: float = -8.0
const _DEFAULT_SFX_DB: float = -3.0
const _DEFAULT_REDUCE_MOTION: bool = false
const _DEFAULT_MUTE: bool = false
const _DEFAULT_LOCALE: String = "en"
# Per `production/live-ops/telemetry-events-v1.md` §C.1: opt-in default is OFF.
# Cozy register + privacy-first; no tracking until the player explicitly enables.
const _DEFAULT_TELEMETRY_OPT_IN: bool = false


@onready var _header_label: Label = $Panel/VBox/HeaderLabel
@onready var _master_label: Label = $Panel/VBox/MasterRow/MasterLabel
@onready var _music_label: Label = $Panel/VBox/MusicRow/MusicLabel
@onready var _sfx_label: Label = $Panel/VBox/SFXRow/SFXLabel
@onready var _mute_label: Label = $Panel/VBox/MuteRow/MuteLabel
@onready var _reduce_motion_label: Label = $Panel/VBox/ReduceMotionRow/ReduceMotionLabel
@onready var _locale_label: Label = $Panel/VBox/LocaleRow/LocaleLabel
@onready var _telemetry_label: Label = $Panel/VBox/TelemetryRow/TelemetryLabel
@onready var _dim_backdrop: ColorRect = $DimBackdrop
@onready var _master_slider: HSlider = $Panel/VBox/MasterRow/MasterSlider
@onready var _master_db_label: Label = $Panel/VBox/MasterRow/MasterDbLabel
@onready var _music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var _music_db_label: Label = $Panel/VBox/MusicRow/MusicDbLabel
@onready var _sfx_slider: HSlider = $Panel/VBox/SFXRow/SFXSlider
@onready var _sfx_db_label: Label = $Panel/VBox/SFXRow/SFXDbLabel
@onready var _mute_check: CheckButton = $Panel/VBox/MuteRow/MuteCheck
@onready var _reduce_motion_check: CheckButton = $Panel/VBox/ReduceMotionRow/ReduceMotionCheck
@onready var _locale_option: OptionButton = $Panel/VBox/LocaleRow/LocaleOption
@onready var _telemetry_check: CheckButton = $Panel/VBox/TelemetryRow/TelemetryCheck
@onready var _reset_button: Button = $Panel/VBox/ButtonRow/ResetButton
@onready var _close_button: Button = $Panel/VBox/ButtonRow/CloseButton
# Sprint 23 S23-S2 — Settings scaffold additions: version readout +
# Quit-to-Desktop button. Version string sources from
# ProjectSettings("application/config/version"); falls back to "unknown".
@onready var _version_label: Label = $Panel/VBox/VersionLabel
@onready var _quit_to_desktop_button: Button = $Panel/VBox/ButtonRow/QuitToDesktopButton


func _ready() -> void:
	# Seed slider positions + toggle states from current autoload state.
	_master_slider.value = _db_to_linear(AudioRouter.get_master_volume_db())
	_music_slider.value = _db_to_linear(AudioRouter.get_music_volume_db())
	_sfx_slider.value = _db_to_linear(AudioRouter.get_sfx_volume_db())
	_mute_check.button_pressed = AudioRouter.is_master_muted()
	_reduce_motion_check.button_pressed = SceneManager.reduce_motion
	# Per telemetry-events-v1.md §C.1: read the persisted opt-in state. The
	# TelemetrySink autoload is the source of truth; the Settings checkbox is
	# just a UI mirror.
	_telemetry_check.button_pressed = TelemetrySink.is_opt_in()

	# Wire slider value_changed → AudioRouter setters.
	_master_slider.value_changed.connect(_on_master_slider_changed)
	_music_slider.value_changed.connect(_on_music_slider_changed)
	_sfx_slider.value_changed.connect(_on_sfx_slider_changed)

	# Wire toggles.
	_mute_check.toggled.connect(_on_mute_toggled)
	_reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
	_telemetry_check.toggled.connect(_on_telemetry_toggled)

	# Locale dropdown (GDD #30 §C.5): populate from TranslationServer; disable
	# if only one locale exists (MVP en-only state).
	_populate_locale_options()
	_locale_option.item_selected.connect(_on_locale_selected)

	# Reset to Defaults button (GDD #30 §C.6).
	_reset_button.pressed.connect(_on_reset_pressed)

	# Wire close button + tap-outside.
	_close_button.pressed.connect(_on_close_pressed)
	_dim_backdrop.gui_input.connect(_on_backdrop_input)

	# Sprint 23 S23-S2 — Quit-to-Desktop + version readout. Button label
	# routes through tr() for locale parity with other Settings rows.
	_quit_to_desktop_button.text = tr("settings_quit_to_desktop_button")
	_quit_to_desktop_button.pressed.connect(_on_quit_to_desktop_pressed)
	_refresh_version_label()

	# i18n: wire scene-baked label text through tr() so they update on locale change.
	_header_label.text = tr("settings_title")
	_master_label.text = tr("settings_volume_master_label")
	_music_label.text = tr("settings_volume_music_label")
	_sfx_label.text = tr("settings_volume_sfx_label")
	_mute_label.text = tr("settings_mute_label")
	_reduce_motion_label.text = tr("settings_reduce_motion_label")
	_locale_label.text = tr("settings_language_label")
	_telemetry_label.text = tr("settings_telemetry_label")
	_reset_button.text = tr("settings_reset_button")
	_close_button.text = tr("settings_close_button")

	# Seed dB display labels from current state.
	_refresh_db_label(_master_db_label, AudioRouter.get_master_volume_db())
	_refresh_db_label(_music_db_label, AudioRouter.get_music_volume_db())
	_refresh_db_label(_sfx_db_label, AudioRouter.get_sfx_volume_db())

	# Parchment skin (ADR-0008): graduate the modal panel to the ParchmentPanel
	# theme variation. The STANDARD pattern preserves mouse_filter=STOP so taps
	# inside the panel don't fall through to the dim backdrop (which closes it).
	UIFramework.apply_parchment_panel($Panel)

	# UI tap chime + 1.05x touch pulse on the action buttons (audio quick-win,
	# folded in per screen touched — audio-system.md AC-AS-14).
	UIFramework.wire_touch_feedback(_close_button)
	UIFramework.wire_touch_feedback(_reset_button)
	UIFramework.wire_touch_feedback(_quit_to_desktop_button)

	# Parchment section eyebrows (Audio / Accessibility / Data & locale).
	_build_wireframe()

	# Modal scale-in entrance — the panel settles into place (DESIGN.md §Motion:
	# `medium` 300ms modal-open duration, `enter` easing). reduce_motion snaps it
	# straight to 1.0 with no entrance motion. Fire-and-forget coroutine.
	_play_panel_scale_in()


# ---------------------------------------------------------------------------
# Slider handlers — linear position [0, 1] to dB
# ---------------------------------------------------------------------------

func _linear_to_db(linear: float) -> float:
	if linear <= 0.001:
		return _MIN_DB
	return 20.0 * log(linear) / log(10.0)


func _db_to_linear(db: float) -> float:
	if db <= _MIN_DB:
		return 0.0
	return clampf(pow(10.0, db / 20.0), 0.0, 1.0)


func _on_master_slider_changed(value: float) -> void:
	var db: float = _linear_to_db(value)
	AudioRouter.set_master_volume_db(db)
	_refresh_db_label(_master_db_label, db)


func _on_music_slider_changed(value: float) -> void:
	var db: float = _linear_to_db(value)
	AudioRouter.set_music_volume_db(db)
	_refresh_db_label(_music_db_label, db)


func _on_sfx_slider_changed(value: float) -> void:
	var db: float = _linear_to_db(value)
	AudioRouter.set_sfx_volume_db(db)
	_refresh_db_label(_sfx_db_label, db)


## Renders dB value as integer dB ("-6 dB") or "-INF" at the silent floor.
func _refresh_db_label(label: Label, db: float) -> void:
	if db <= _MIN_DB:
		label.text = tr("settings_volume_silent_label")
	else:
		label.text = UIFrameworkScript.format_localized("settings_volume_db_format", [roundi(db)])


# ---------------------------------------------------------------------------
# Toggle handlers
# ---------------------------------------------------------------------------

func _on_mute_toggled(value: bool) -> void:
	AudioRouter.set_master_muted(value)


func _on_reduce_motion_toggled(value: bool) -> void:
	SceneManager.set_reduce_motion(value)


## Per telemetry-events-v1.md §C.1: toggle takes effect immediately. The
## TelemetrySink autoload owns the buffer-drop / flush behavior on
## ON→OFF / OFF→ON transitions; the screen just notifies it.
func _on_telemetry_toggled(value: bool) -> void:
	TelemetrySink.set_opt_in(value)


# ---------------------------------------------------------------------------
# Close handlers
# ---------------------------------------------------------------------------

func _on_close_pressed() -> void:
	SceneManager.pop_overlay("settings")


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		SceneManager.pop_overlay("settings")


# ---------------------------------------------------------------------------
# Locale dropdown (GDD #30 §C.5)
# ---------------------------------------------------------------------------

## Populates the OptionButton with TranslationServer's loaded locales.
## Per GDD §C.5: dropdown is disabled (single-locale grayed) if only one
## locale exists. MVP ships en-only — locale resources arrive in V1.0 i18n.
func _populate_locale_options() -> void:
	_locale_option.clear()
	var locales: PackedStringArray = TranslationServer.get_loaded_locales()
	# Defensive: ensure "en" is always present as the fallback option even
	# when TranslationServer reports no loaded locales (headless test env).
	if locales.is_empty():
		locales = PackedStringArray(["en"])
	var current: String = TranslationServer.get_locale()
	var selected_index: int = 0
	for i: int in range(locales.size()):
		_locale_option.add_item(locales[i], i)
		if locales[i] == current:
			selected_index = i
	_locale_option.select(selected_index)
	# Grayed when only one locale exists (no choice to make).
	_locale_option.disabled = (_locale_option.item_count <= 1)


func _on_locale_selected(index: int) -> void:
	var locale_id: String = _locale_option.get_item_text(index)
	TranslationServer.set_locale(locale_id)


# ---------------------------------------------------------------------------
# Reset to Defaults (GDD #30 §C.6)
# ---------------------------------------------------------------------------

## Resets all controls to GDD §C.2-§C.5 defaults. Slider value sets trigger
## the existing slider_value_changed signal handlers, which propagate the
## defaults to AudioRouter immediately (auto-save model). This deviates from
## GDD §C.6's "must click Save to persist" — the MVP overlay has no Save
## button distinct from Close; every change persists immediately via the
## AudioRouter consumer surface. Acceptable for MVP per the simpler UX.
func _on_reset_pressed() -> void:
	_master_slider.value = _db_to_linear(_DEFAULT_MASTER_DB)
	_music_slider.value = _db_to_linear(_DEFAULT_MUSIC_DB)
	_sfx_slider.value = _db_to_linear(_DEFAULT_SFX_DB)
	_mute_check.button_pressed = _DEFAULT_MUTE
	# CheckButton.button_pressed assignment does NOT emit toggled on its own
	# in Godot 4; emit explicitly so AudioRouter receives the change.
	_mute_check.toggled.emit(_DEFAULT_MUTE)
	_reduce_motion_check.button_pressed = _DEFAULT_REDUCE_MOTION
	_reduce_motion_check.toggled.emit(_DEFAULT_REDUCE_MOTION)
	# Telemetry: reset to opt-out default per telemetry-events-v1.md §C.1
	# (privacy-first; resetting Settings should not silently leave tracking on).
	_telemetry_check.button_pressed = _DEFAULT_TELEMETRY_OPT_IN
	_telemetry_check.toggled.emit(_DEFAULT_TELEMETRY_OPT_IN)
	# Locale: select the default option. select() doesn't emit item_selected,
	# so emit explicitly.
	for i: int in range(_locale_option.item_count):
		if _locale_option.get_item_text(i) == _DEFAULT_LOCALE:
			_locale_option.select(i)
			_locale_option.item_selected.emit(i)
			break


# ---------------------------------------------------------------------------
# Sprint 23 S23-S2 — Version readout + Quit-to-Desktop
# ---------------------------------------------------------------------------

## Reads the application version from ProjectSettings("application/config/version")
## and renders it on the version label. Defensive: missing setting renders
## "Version unknown" rather than crashing.
func _refresh_version_label() -> void:
	if _version_label == null:
		return
	var version_value: Variant = ProjectSettings.get_setting("application/config/version", "")
	var version_text: String = String(version_value).strip_edges()
	if version_text.is_empty():
		version_text = "unknown"
	# tr() with %s substitution; the locale key fallback returns the key
	# verbatim and still renders cleanly.
	_version_label.text = tr("settings_version_label_format") % version_text


## Quits the game application. SceneTree.quit() is the canonical Godot 4.6
## exit path; the OS shell receives normal exit code 0. SaveLoadSystem's
## standard shutdown autosave fires through its own _notification(
## NOTIFICATION_WM_CLOSE_REQUEST) handler — no explicit save call needed
## here.
func _on_quit_to_desktop_pressed() -> void:
	# Pop the settings overlay first so the pause state unwinds cleanly
	# before the tree exits. Without this, the modal pause counter would
	# stay incremented through the exit handler — harmless in practice
	# but produces a noisy warning in debug builds.
	SceneManager.pop_overlay("settings")
	get_tree().quit()


# ===========================================================================
# Parchment section eyebrows for Settings
# Additive (no .tscn edits): inserts the "inner workings" eyebrow + per-section
# eyebrows (Audio / Accessibility / Data & locale) into Panel/VBox. Colors route
# through ParchmentKit (no Color() literals); ParchmentKit.eyebrow renders the
# parchment small-caps register (uppercased).
# ===========================================================================

func _build_wireframe() -> void:
	var vbox: Node = get_node_or_null("Panel/VBox")
	if vbox == null:
		return
	_insert_section(vbox, get_node_or_null("Panel/VBox/HeaderLabel"), tr("settings_eyebrow_header"), ParchmentKitScript.ACCENT)
	_insert_section(vbox, get_node_or_null("Panel/VBox/MasterRow"), tr("settings_section_audio"), ParchmentKitScript.MUTED)
	_insert_section(vbox, get_node_or_null("Panel/VBox/ReduceMotionRow"), tr("settings_section_accessibility"), ParchmentKitScript.MUTED)
	_insert_section(vbox, get_node_or_null("Panel/VBox/LocaleRow"), tr("settings_section_data_locale"), ParchmentKitScript.MUTED)


## Inserts a parchment eyebrow label immediately before [param before] in [param vbox].
func _insert_section(vbox: Node, before: Node, text: String, color: Color) -> void:
	if vbox == null or before == null:
		return
	var eyebrow: Label = ParchmentKitScript.eyebrow(text, color)
	vbox.add_child(eyebrow)
	vbox.move_child(eyebrow, before.get_index())


# ===========================================================================
# Modal scale-in entrance
# ===========================================================================

## Grows the panel from 0.94 to 1.0 about its centre so it settles into place
## (DESIGN.md §Motion: `medium` 300ms modal-open duration, `enter` easing =
## EASE_OUT/TRANS_QUAD — "panels appearing"). Under reduce_motion (ADR-0007 /
## DESIGN.md §Reduce motion) the panel stays at 1.0 with no entrance motion.
## Fire-and-forget coroutine: _ready starts it without awaiting, so the
## synchronous wiring above is unaffected and tests that don't pump frames
## never observe a non-1.0 scale.
func _play_panel_scale_in() -> void:
	var panel: Control = get_node_or_null("Panel")
	if panel == null:
		return
	if SceneManager.reduce_motion:
		return
	# Defer one frame so the panel's laid-out size is valid before we pivot+scale.
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.94, 0.94)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3)
