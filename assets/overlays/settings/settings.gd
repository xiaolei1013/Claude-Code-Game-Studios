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

const _MIN_DB: float = -80.0  # below this, treat as -INF (silent floor)

# Per GDD #30 §C.2 defaults (audio-system.md §C.7 baselines).
const _DEFAULT_MASTER_DB: float = 0.0
const _DEFAULT_MUSIC_DB: float = -8.0
const _DEFAULT_SFX_DB: float = -3.0
const _DEFAULT_REDUCE_MOTION: bool = false
const _DEFAULT_MUTE: bool = false
const _DEFAULT_LOCALE: String = "en"


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
@onready var _reset_button: Button = $Panel/VBox/ButtonRow/ResetButton
@onready var _close_button: Button = $Panel/VBox/ButtonRow/CloseButton


func _ready() -> void:
	# Seed slider positions + toggle states from current autoload state.
	_master_slider.value = _db_to_linear(AudioRouter.get_master_volume_db())
	_music_slider.value = _db_to_linear(AudioRouter.get_music_volume_db())
	_sfx_slider.value = _db_to_linear(AudioRouter.get_sfx_volume_db())
	_mute_check.button_pressed = AudioRouter.is_master_muted()
	_reduce_motion_check.button_pressed = SceneManager.reduce_motion

	# Wire slider value_changed → AudioRouter setters.
	_master_slider.value_changed.connect(_on_master_slider_changed)
	_music_slider.value_changed.connect(_on_music_slider_changed)
	_sfx_slider.value_changed.connect(_on_sfx_slider_changed)

	# Wire toggles.
	_mute_check.toggled.connect(_on_mute_toggled)
	_reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)

	# Locale dropdown (GDD #30 §C.5): populate from TranslationServer; disable
	# if only one locale exists (MVP en-only state).
	_populate_locale_options()
	_locale_option.item_selected.connect(_on_locale_selected)

	# Reset to Defaults button (GDD #30 §C.6).
	_reset_button.pressed.connect(_on_reset_pressed)

	# Wire close button + tap-outside.
	_close_button.pressed.connect(_on_close_pressed)
	_dim_backdrop.gui_input.connect(_on_backdrop_input)

	# Seed dB display labels from current state.
	_refresh_db_label(_master_db_label, AudioRouter.get_master_volume_db())
	_refresh_db_label(_music_db_label, AudioRouter.get_music_volume_db())
	_refresh_db_label(_sfx_db_label, AudioRouter.get_sfx_volume_db())


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
		label.text = "-INF"
	else:
		label.text = "%d dB" % roundi(db)


# ---------------------------------------------------------------------------
# Toggle handlers
# ---------------------------------------------------------------------------

func _on_mute_toggled(value: bool) -> void:
	AudioRouter.set_master_muted(value)


func _on_reduce_motion_toggled(value: bool) -> void:
	SceneManager.set_reduce_motion(value)


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
	# Locale: select the default option. select() doesn't emit item_selected,
	# so emit explicitly.
	for i: int in range(_locale_option.item_count):
		if _locale_option.get_item_text(i) == _DEFAULT_LOCALE:
			_locale_option.select(i)
			_locale_option.item_selected.emit(i)
			break
