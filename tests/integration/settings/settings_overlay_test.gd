# Settings overlay wiring per GDD #30 §C.1-C.4 + AC-30-01..05.
#
# Test groups:
#   A — overlay scene loads + wires its onready references without crash
#   B — slider value writes through AudioRouter.set_*_volume_db (db curve)
#   C — reduce_motion checkbox writes through SceneManager.set_reduce_motion
#   D — Guild Hall SettingsGearButton invokes SceneManager.push_overlay("settings")
extends GdUnitTestSuite

const SettingsOverlayScene: PackedScene = preload(
	"res://assets/overlays/settings/settings.tscn"
)
const GuildHallScene: PackedScene = preload(
	"res://assets/screens/guild_hall/guild_hall.tscn"
)


# ---------------------------------------------------------------------------
# Hygiene barrier — snapshot/restore AudioRouter volume + reduce_motion state.
# ---------------------------------------------------------------------------

var _snapshot_master_db: float = 0.0
var _snapshot_music_db: float = 0.0
var _snapshot_sfx_db: float = 0.0
var _snapshot_reduce_motion: bool = false
var _snapshot_master_muted: bool = false


func before_test() -> void:
	_snapshot_master_db = AudioRouter.get_master_volume_db()
	_snapshot_music_db = AudioRouter.get_music_volume_db()
	_snapshot_sfx_db = AudioRouter.get_sfx_volume_db()
	_snapshot_reduce_motion = SceneManager.reduce_motion
	_snapshot_master_muted = AudioRouter.is_master_muted()


func after_test() -> void:
	AudioRouter.set_master_volume_db(_snapshot_master_db)
	AudioRouter.set_music_volume_db(_snapshot_music_db)
	AudioRouter.set_sfx_volume_db(_snapshot_sfx_db)
	SceneManager.set_reduce_motion(_snapshot_reduce_motion)
	AudioRouter.set_master_muted(_snapshot_master_muted)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_overlay_in_tree() -> Control:
	var overlay: Control = SettingsOverlayScene.instantiate() as Control
	add_child(overlay)
	auto_free(overlay)
	return overlay


# ===========================================================================
# Group A — overlay scene loads + @onready references resolve
# ===========================================================================

func test_settings_overlay_scene_loads_without_crash() -> void:
	var overlay: Control = _make_overlay_in_tree()
	assert_object(overlay).is_not_null()
	# All @onready node paths must resolve.
	assert_object(overlay.get_node_or_null("DimBackdrop")).is_not_null()
	assert_object(overlay.get_node_or_null("Panel/VBox/MasterRow/MasterSlider")).is_not_null()
	assert_object(overlay.get_node_or_null("Panel/VBox/MusicRow/MusicSlider")).is_not_null()
	assert_object(overlay.get_node_or_null("Panel/VBox/SFXRow/SFXSlider")).is_not_null()
	assert_object(overlay.get_node_or_null("Panel/VBox/ReduceMotionRow/ReduceMotionCheck")).is_not_null()
	assert_object(overlay.get_node_or_null("Panel/VBox/CloseButton")).is_not_null()


func test_sliders_initialize_from_current_audiorouter_state() -> void:
	AudioRouter.set_master_volume_db(0.0)
	var overlay: Control = _make_overlay_in_tree()
	var master_slider: HSlider = overlay.get_node("Panel/VBox/MasterRow/MasterSlider")
	# 0 dB → linear 1.0
	assert_float(master_slider.value).is_equal_approx(1.0, 0.01)


# ===========================================================================
# Group B — slider value writes through AudioRouter via linear-to-dB curve
# ===========================================================================

func test_master_slider_at_1_writes_0db_to_audiorouter() -> void:
	var overlay: Control = _make_overlay_in_tree()
	var slider: HSlider = overlay.get_node("Panel/VBox/MasterRow/MasterSlider")
	slider.value = 1.0
	# Slider emits value_changed; handler writes 0 dB.
	assert_float(AudioRouter.get_master_volume_db()).is_equal_approx(0.0, 0.5)


func test_master_slider_at_0_writes_silent_floor_to_audiorouter() -> void:
	var overlay: Control = _make_overlay_in_tree()
	var slider: HSlider = overlay.get_node("Panel/VBox/MasterRow/MasterSlider")
	slider.value = 0.0
	# Slider at 0 → silent floor (-80 dB or below).
	assert_float(AudioRouter.get_master_volume_db()).is_less_equal(-79.0)


func test_music_slider_writes_to_music_bus_not_master() -> void:
	var overlay: Control = _make_overlay_in_tree()
	var master_before: float = AudioRouter.get_master_volume_db()
	var music_slider: HSlider = overlay.get_node("Panel/VBox/MusicRow/MusicSlider")
	music_slider.value = 0.5
	# Music bus changed; master unchanged.
	var music_after: float = AudioRouter.get_music_volume_db()
	assert_float(music_after).is_not_equal(master_before)
	assert_float(AudioRouter.get_master_volume_db()).is_equal(master_before)


# ===========================================================================
# Group C — reduce_motion checkbox writes through SceneManager
# ===========================================================================

func test_reduce_motion_check_toggled_writes_to_scene_manager() -> void:
	SceneManager.set_reduce_motion(false)
	var overlay: Control = _make_overlay_in_tree()
	var check: CheckButton = overlay.get_node("Panel/VBox/ReduceMotionRow/ReduceMotionCheck")
	check.button_pressed = true
	# Direct property set should emit toggled signal.
	check.toggled.emit(true)
	assert_bool(SceneManager.reduce_motion).is_true()


func test_reduce_motion_check_initializes_from_scene_manager() -> void:
	SceneManager.set_reduce_motion(true)
	var overlay: Control = _make_overlay_in_tree()
	var check: CheckButton = overlay.get_node("Panel/VBox/ReduceMotionRow/ReduceMotionCheck")
	assert_bool(check.button_pressed).is_true()


# ===========================================================================
# Group C2 — Mute checkbox writes through AudioRouter
# ===========================================================================

func test_mute_check_toggled_writes_to_audio_router() -> void:
	AudioRouter.set_master_muted(false)
	var overlay: Control = _make_overlay_in_tree()
	var check: CheckButton = overlay.get_node("Panel/VBox/MuteRow/MuteCheck")
	check.button_pressed = true
	check.toggled.emit(true)
	assert_bool(AudioRouter.is_master_muted()).is_true()


func test_mute_check_initializes_from_audio_router() -> void:
	AudioRouter.set_master_muted(true)
	var overlay: Control = _make_overlay_in_tree()
	var check: CheckButton = overlay.get_node("Panel/VBox/MuteRow/MuteCheck")
	assert_bool(check.button_pressed).is_true()


# ===========================================================================
# Group D — Guild Hall SettingsGearButton wires to push_overlay
# ===========================================================================

func test_guild_hall_has_settings_gear_button() -> void:
	var screen: Node = GuildHallScene.instantiate()
	add_child(screen)
	auto_free(screen)
	var gear: Node = screen.get_node_or_null("SettingsGearButton")
	assert_object(gear).is_not_null()


func test_settings_gear_button_pressed_handler_is_wired() -> void:
	var screen: Node = GuildHallScene.instantiate()
	add_child(screen)
	auto_free(screen)
	if screen.has_method("on_enter"):
		screen.on_enter()
	var gear: Button = screen.get_node("SettingsGearButton") as Button
	# At least one connection should exist (the _on_settings_gear_pressed bind).
	var conns: Array = gear.pressed.get_connections()
	assert_int(conns.size()).is_greater_equal(1)
