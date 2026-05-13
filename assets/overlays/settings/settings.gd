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


@onready var _dim_backdrop: ColorRect = $DimBackdrop
@onready var _master_slider: HSlider = $Panel/VBox/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $Panel/VBox/SFXRow/SFXSlider
@onready var _mute_check: CheckButton = $Panel/VBox/MuteRow/MuteCheck
@onready var _reduce_motion_check: CheckButton = $Panel/VBox/ReduceMotionRow/ReduceMotionCheck
@onready var _close_button: Button = $Panel/VBox/CloseButton


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

	# Wire close button + tap-outside.
	_close_button.pressed.connect(_on_close_pressed)
	_dim_backdrop.gui_input.connect(_on_backdrop_input)


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
	AudioRouter.set_master_volume_db(_linear_to_db(value))


func _on_music_slider_changed(value: float) -> void:
	AudioRouter.set_music_volume_db(_linear_to_db(value))


func _on_sfx_slider_changed(value: float) -> void:
	AudioRouter.set_sfx_volume_db(_linear_to_db(value))


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
