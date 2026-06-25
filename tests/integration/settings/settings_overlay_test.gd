# Settings overlay wiring per GDD #30 §C.1-C.6 + AC-30-01..09.
#
# Test groups:
#   A  — overlay scene loads + wires its onready references without crash
#   B  — slider value writes through AudioRouter.set_*_volume_db (db curve)
#   C  — reduce_motion checkbox writes through SceneManager.set_reduce_motion
#   C2 — mute checkbox writes through AudioRouter.set_master_muted
#   E  — dB display labels render slider values ("0 dB" / "-INF")
#   F  — Reset button restores GDD §C.2-§C.5 defaults
#   G  — locale dropdown population + single-locale disabled state
#   D  — Guild Hall SettingsGearButton invokes SceneManager.push_overlay("settings")
#   H  — AC-30-09: Escape (ui_cancel) closes Settings when topmost
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
# Reset (and any locale change) now persists via LocaleLoader.persist_locale,
# which writes the SHARED user://settings.cfg. Redirect that write to a unique
# temp path so these overlay tests never touch the dev machine's real settings.
var _snapshot_locale_cfg_path: String = ""
var _temp_locale_cfg_path: String = ""
# The Reset/locale-select path also calls TranslationServer.set_locale; snapshot
# and restore the live locale so a future multi-locale build can't leak it across
# tests (today it is always "en", but the isolation must not depend on that).
var _snapshot_locale: String = ""
# Group H seeds SceneManager._active_overlays directly to exercise the Escape
# topmost-overlay guard against the live autoload (settings.gd couples to the
# SceneManager singleton, not an injectable instance). Snapshot/restore the
# overlay stack, FSM state, and current_screen so the seed never leaks across
# tests or suites (memory: feedback_test_isolation_live_autoload).
var _snapshot_active_overlays: Dictionary = {}
var _snapshot_sm_state: int = 0
var _snapshot_current_screen: Node = null


func before_test() -> void:
	_snapshot_master_db = AudioRouter.get_master_volume_db()
	_snapshot_music_db = AudioRouter.get_music_volume_db()
	_snapshot_sfx_db = AudioRouter.get_sfx_volume_db()
	_snapshot_reduce_motion = SceneManager.reduce_motion
	_snapshot_master_muted = AudioRouter.is_master_muted()
	_snapshot_locale_cfg_path = LocaleLoader._settings_cfg_path
	_temp_locale_cfg_path = "user://test_%d_settings_overlay_locale.cfg" % Time.get_ticks_msec()
	LocaleLoader._settings_cfg_path = _temp_locale_cfg_path
	_snapshot_locale = TranslationServer.get_locale()
	_snapshot_active_overlays = SceneManager._active_overlays
	_snapshot_sm_state = SceneManager.state
	_snapshot_current_screen = SceneManager.current_screen


func after_test() -> void:
	AudioRouter.set_master_volume_db(_snapshot_master_db)
	AudioRouter.set_music_volume_db(_snapshot_music_db)
	AudioRouter.set_sfx_volume_db(_snapshot_sfx_db)
	SceneManager.set_reduce_motion(_snapshot_reduce_motion)
	AudioRouter.set_master_muted(_snapshot_master_muted)
	LocaleLoader._settings_cfg_path = _snapshot_locale_cfg_path
	TranslationServer.set_locale(_snapshot_locale)
	SceneManager._active_overlays = _snapshot_active_overlays
	SceneManager.state = _snapshot_sm_state
	SceneManager.current_screen = _snapshot_current_screen
	if FileAccess.file_exists(_temp_locale_cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temp_locale_cfg_path))


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
	assert_object(overlay.get_node_or_null("Panel/VBox/ButtonRow/CloseButton")).is_not_null()
	assert_object(overlay.get_node_or_null("Panel/VBox/ButtonRow/ResetButton")).is_not_null()
	assert_object(overlay.get_node_or_null("Panel/VBox/LocaleRow/LocaleOption")).is_not_null()
	assert_object(overlay.get_node_or_null("Panel/VBox/MasterRow/MasterDbLabel")).is_not_null()


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
# Group E — dB display labels render slider values
# ===========================================================================

func test_master_slider_at_1_shows_0_db_label() -> void:
	var overlay: Control = _make_overlay_in_tree()
	var slider: HSlider = overlay.get_node("Panel/VBox/MasterRow/MasterSlider")
	var label: Label = overlay.get_node("Panel/VBox/MasterRow/MasterDbLabel")
	slider.value = 1.0
	# 0 dB displays as "0 dB"
	assert_str(label.text).is_equal("0 dB")


func test_master_slider_at_0_shows_inf_label() -> void:
	var overlay: Control = _make_overlay_in_tree()
	var slider: HSlider = overlay.get_node("Panel/VBox/MasterRow/MasterSlider")
	var label: Label = overlay.get_node("Panel/VBox/MasterRow/MasterDbLabel")
	slider.value = 0.0
	assert_str(label.text).is_equal("-INF")


# ===========================================================================
# Group F — Reset button restores GDD §C.2-§C.5 defaults
# ===========================================================================

func test_reset_button_restores_audio_defaults() -> void:
	AudioRouter.set_master_volume_db(-40.0)
	AudioRouter.set_music_volume_db(-40.0)
	AudioRouter.set_sfx_volume_db(-40.0)
	AudioRouter.set_master_muted(true)
	SceneManager.set_reduce_motion(true)

	var overlay: Control = _make_overlay_in_tree()
	var reset_btn: Button = overlay.get_node("Panel/VBox/ButtonRow/ResetButton")
	reset_btn.pressed.emit()

	# Defaults per GDD §C.2 / §C.3 / §C.4.
	assert_float(AudioRouter.get_master_volume_db()).is_equal_approx(0.0, 0.5)
	assert_float(AudioRouter.get_music_volume_db()).is_equal_approx(-8.0, 0.5)
	assert_float(AudioRouter.get_sfx_volume_db()).is_equal_approx(-3.0, 0.5)
	assert_bool(AudioRouter.is_master_muted()).is_false()
	assert_bool(SceneManager.reduce_motion).is_false()


# ===========================================================================
# Group G — Locale dropdown population + disabled state
# ===========================================================================

func test_locale_option_populated_with_loaded_locales() -> void:
	var overlay: Control = _make_overlay_in_tree()
	var opt: OptionButton = overlay.get_node("Panel/VBox/LocaleRow/LocaleOption")
	# At least one locale must always be present (en fallback).
	assert_int(opt.item_count).is_greater_equal(1)


func test_locale_option_disabled_when_only_one_locale() -> void:
	var overlay: Control = _make_overlay_in_tree()
	var opt: OptionButton = overlay.get_node("Panel/VBox/LocaleRow/LocaleOption")
	# MVP en-only state: dropdown disabled per GDD §C.5.
	if opt.item_count <= 1:
		assert_bool(opt.disabled).is_true()
	else:
		assert_bool(opt.disabled).is_false()


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


# ===========================================================================
# Group H — AC-30-09: Escape (ui_cancel) closes the Settings overlay
#
# settings.gd._unhandled_input mirrors pause_menu.gd: it consumes ui_cancel and
# closes ONLY when Settings is the topmost overlay, so a pause → Settings chain
# closes Settings first (revealing the pause menu beneath) instead of the pause
# handler firing underneath. These tests seed SceneManager._active_overlays
# directly (the overlay couples to the live autoload, not an injectable
# instance) and drive _unhandled_input synthetically; before_test/after_test
# snapshot and restore the overlay stack so the seed never leaks.
# ===========================================================================

func _ui_cancel_event() -> InputEventAction:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	return ev


func _escape_key_event() -> InputEventKey:
	# The real, physical Escape key event (what the OS delivers), as opposed to the
	# pre-resolved InputEventAction. Both keycode and physical_keycode are set so
	# event_is_action() matches regardless of how ui_cancel is bound.
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	return ev


func test_escape_closes_settings_when_topmost() -> void:
	# Arrange — register Settings as the sole (topmost) overlay on the live
	# autoload. pause_on_open=false so pop touches no pause counter; null
	# current_screen so pop's on_resume path is a guarded no-op (determinism).
	var tracked: Control = Control.new()
	tracked.set_meta("scene_manager_pause_on_open", false)
	SceneManager._active_overlays = {"settings": tracked}
	SceneManager.current_screen = null
	var overlay: Control = _make_overlay_in_tree()
	assert_str(SceneManager.topmost_overlay_id()).is_equal("settings")

	# Act — Esc arrives as unhandled input.
	overlay._unhandled_input(_ui_cancel_event())

	# Assert — Settings popped itself and consumed the event.
	assert_bool(SceneManager._active_overlays.has("settings")).is_false()
	assert_bool(overlay.get_viewport().is_input_handled()).is_true()


func test_escape_ignored_when_settings_not_topmost() -> void:
	# Arrange — a DIFFERENT overlay sits on top of Settings (e.g. another modal
	# pushed after it). Settings must DEFER: not consume Esc, not pop anything —
	# the chain-safety guard that keeps the topmost overlay owning Esc.
	var settings_stub: Control = Control.new()
	settings_stub.set_meta("scene_manager_pause_on_open", false)
	auto_free(settings_stub)
	var other: Control = Control.new()
	other.set_meta("scene_manager_pause_on_open", false)
	auto_free(other)
	SceneManager._active_overlays = {"settings": settings_stub, "other_modal": other}
	var overlay: Control = _make_overlay_in_tree()
	assert_str(SceneManager.topmost_overlay_id()).is_not_equal("settings")

	# Act
	overlay._unhandled_input(_ui_cancel_event())

	# Assert — the topmost overlay is untouched (Settings did not pop it).
	assert_bool(SceneManager._active_overlays.has("other_modal")).is_true()


func test_non_cancel_input_ignored_when_settings_topmost() -> void:
	# Arrange — Settings topmost, but a non-cancel action arrives.
	var tracked: Control = Control.new()
	tracked.set_meta("scene_manager_pause_on_open", false)
	auto_free(tracked)
	SceneManager._active_overlays = {"settings": tracked}
	var overlay: Control = _make_overlay_in_tree()

	# Act — ui_accept is not ui_cancel; the handler must ignore it.
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	overlay._unhandled_input(ev)

	# Assert — Settings is still open (Esc-close path not triggered).
	assert_bool(SceneManager._active_overlays.has("settings")).is_true()


func test_escape_key_event_maps_to_cancel_and_closes_settings() -> void:
	# Production Esc arrives as a physical InputEventKey, not an InputEventAction.
	# The action-based tests above would keep passing even if Escape were unmapped
	# from ui_cancel in project.godot; this test guards that binding end to end —
	# event_is_action() goes false the moment the keymap regresses.
	assert_bool(InputMap.event_is_action(_escape_key_event(), "ui_cancel")).is_true()

	# Arrange — Settings is the sole (topmost) overlay; pop frees `tracked`.
	var tracked: Control = Control.new()
	tracked.set_meta("scene_manager_pause_on_open", false)
	SceneManager._active_overlays = {"settings": tracked}
	SceneManager.current_screen = null
	var overlay: Control = _make_overlay_in_tree()
	assert_str(SceneManager.topmost_overlay_id()).is_equal("settings")

	# Act — the real Escape key arrives as unhandled input.
	overlay._unhandled_input(_escape_key_event())

	# Assert — Settings popped itself and consumed the event.
	assert_bool(SceneManager._active_overlays.has("settings")).is_false()
	assert_bool(overlay.get_viewport().is_input_handled()).is_true()
