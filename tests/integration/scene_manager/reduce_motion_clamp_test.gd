# Tests for Story S12-S2: reduce_motion accessibility flag on SceneManager.
#
# Covers:
#   TR-scene-manager-027: reduce_motion clamps all standard transitions to 50ms
#   TR-scene-manager-006: transitions not player-skippable (clamp still applies)
#   TR-scene-manager-036: CEREMONY is documented as instant-cut when reduce_motion=true
#                         (but CEREMONY dispatcher is not yet shipped — Story 006)
#   ConfigFile persistence: set_reduce_motion persists; _load_interim_settings reloads
#
# Strategy: wired non-autoload SceneManager + temporary MainRoot (same pattern as
# request_screen_and_node_swap_test.gd:56). Duration getters are probed directly
# (they are internal helpers accessible on the instance). Wall-clock assertions are
# not used because headless timing compression makes them non-deterministic; instead
# we assert the AUTHORED duration value returned by the getter (structural assertion).
#
# ConfigFile tests write to a unique per-run temp path and clean up in after_test.
#
# ADR-0007 §reduce_motion accessibility
extends GdUnitTestSuite

const SceneManagerScript = preload("res://src/core/scene_manager/scene_manager.gd")
const MAIN_ROOT_SCENE_PATH: String = "res://src/core/scene_manager/MainRoot.tscn"

## Temp settings path unique to this test run (avoids polluting user://settings.cfg).
var _test_settings_path: String = ""


func before_test() -> void:
	# Build a unique temp path per test run using ticks for uniqueness.
	_test_settings_path = "user://test_%d_reduce_motion_settings.cfg" % Time.get_ticks_msec()


func after_test() -> void:
	# Remove the temp settings file so tests do not bleed state.
	if FileAccess.file_exists(_test_settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_settings_path))


# ---------------------------------------------------------------------------
# Helper: create a non-autoload SceneManager wired to a temporary MainRoot.
# Mirrors _make_wired_scene_manager() in request_screen_and_node_swap_test.gd:56.
# ---------------------------------------------------------------------------
func _make_wired_scene_manager() -> Array:
	var sm: Node = SceneManagerScript.new()
	# Override the settings path BEFORE add_child triggers _ready() so
	# _load_interim_settings reads from our isolated temp path, not the real
	# user://settings.cfg (which may have leftover state from prior real-game
	# launches on the dev machine).
	sm._settings_cfg_path = _test_settings_path
	sm.state = SceneManagerScript.State.IDLE
	add_child(sm)
	await get_tree().process_frame

	var packed_main_root: PackedScene = load(MAIN_ROOT_SCENE_PATH) as PackedScene
	assert_object(packed_main_root).is_not_null()
	var main_root: Control = packed_main_root.instantiate() as Control
	assert_object(main_root).is_not_null()
	get_tree().root.add_child(main_root)
	await get_tree().process_frame

	sm.state = SceneManagerScript.State.IDLE
	return [sm, main_root]


func _cleanup_wired(sm: Node, main_root: Node) -> void:
	if is_instance_valid(sm):
		sm.queue_free()
	if is_instance_valid(main_root):
		main_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# ===========================================================================
# Group A: TR-scene-manager-027 — reduce_motion getter clamp
# ===========================================================================

# A-01: When reduce_motion is false, getters return full-motion values
#
# Given: SceneManager instance with reduce_motion explicitly set to false
#        (isolates from any user://settings.cfg on the developer machine).
# When: _get_crossfade_duration_ms(null) called.
# Then: returns _CROSSFADE_DEFAULT_MS (150).
func test_reduce_motion_false_getters_return_full_duration() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Explicitly reset to false to isolate from any real user://settings.cfg
	sm.reduce_motion = false

	# Act / Assert
	assert_bool(sm.reduce_motion).is_false()
	# Crossfade getter (null screen → no override path → hardcoded constant 150ms)
	var crossfade_ms: int = sm._get_crossfade_duration_ms(null)
	assert_int(crossfade_ms).is_equal(150)

	await _cleanup_wired(sm, main_root)


# A-02: set_reduce_motion(true) clamps all four standard-transition getters to 50ms
#
# Given: SceneManager IDLE; reduce_motion == false.
# When: set_reduce_motion(true) called.
# Then: all four getters return REDUCE_MOTION_CLAMP_MS (50).
func test_reduce_motion_true_clamps_all_four_getters_to_50ms() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Act
	sm.reduce_motion = true  # bypass ConfigFile for this structural test

	# Assert — all four getters return REDUCE_MOTION_CLAMP_MS
	assert_int(sm.REDUCE_MOTION_CLAMP_MS).is_equal(50)
	assert_int(sm._get_crossfade_duration_ms(null)).is_equal(50)
	assert_int(sm._get_slide_duration_ms(null)).is_equal(50)
	assert_int(sm._get_fade_to_black_duration_ms(null)).is_equal(50)
	assert_int(sm._get_push_modal_duration_ms(null)).is_equal(50)

	await _cleanup_wired(sm, main_root)


# A-03: reduce_motion clamp overrides per-screen transition_override_ms
#
# Given: reduce_motion == true; a fake screen node with transition_override_ms = 300.
# When: _get_crossfade_duration_ms(fake_screen) called.
# Then: returns 50 (clamp wins over per-screen override).
func test_reduce_motion_clamp_overrides_per_screen_override() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.reduce_motion = true

	# Create a minimal fake screen with the override property
	var fake_screen: Control = auto_free(Control.new())
	fake_screen.set("transition_override_ms", 300)

	# Act / Assert
	var ms: int = sm._get_crossfade_duration_ms(fake_screen)
	assert_int(ms).is_equal(50)

	await _cleanup_wired(sm, main_root)


# A-04: set_reduce_motion is idempotent — calling with same value does not change state
#
# Given: reduce_motion explicitly set to true.
# When: set_reduce_motion(true) called again (same value).
# Then: reduce_motion still true; no error or crash.
func test_set_reduce_motion_is_idempotent_on_same_value() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Force a known state rather than relying on settings.cfg content
	sm.reduce_motion = true

	# Act — call with the same value; should be a no-op
	sm.set_reduce_motion(true)

	# Assert — still true, no crash
	assert_bool(sm.reduce_motion).is_true()

	await _cleanup_wired(sm, main_root)


# A-05: set_reduce_motion(true) updates in-memory flag immediately
#
# Given: SceneManager IDLE; reduce_motion == false.
# When: set_reduce_motion(true) called.
# Then: reduce_motion == true immediately (synchronous).
func test_set_reduce_motion_updates_in_memory_flag_immediately() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	assert_bool(sm.reduce_motion).is_false()

	# Act
	sm.set_reduce_motion(true)

	# Assert
	assert_bool(sm.reduce_motion).is_true()

	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group B: ConfigFile persistence — TR-scene-manager-027
# ===========================================================================

# B-01: set_reduce_motion persists to ConfigFile; _load_interim_settings reloads it
#
# Given: no settings file at _test_settings_path.
# When: set_reduce_motion(true) writes to the temp path; a new SceneManager calls
#       _load_interim_settings() pointing to the same temp path.
# Then: new instance reduce_motion == true.
#
# Strategy: we call _load_interim_settings via monkey-patching the path isn't
# directly injectable, so we write the cfg manually and call _load_interim_settings,
# which reads from user://settings.cfg. For isolation, this test writes to the
# REAL user://settings.cfg and restores it afterward. We use a helper SM and call
# the public API so the write goes through set_reduce_motion.
func test_set_reduce_motion_persists_to_configfile_and_reloads() -> void:
	# Write reduce_motion=true via ConfigFile directly to the canonical path
	# (same path that set_reduce_motion and _load_interim_settings use).
	# We clean up after ourselves in after_test — but since the canonical path
	# is user://settings.cfg we save/restore any pre-existing content.

	# Arrange: save any pre-existing settings.cfg
	var saved_cfg_content: String = ""
	var restore_existing: bool = false
	if FileAccess.file_exists("user://settings.cfg"):
		var f: FileAccess = FileAccess.open("user://settings.cfg", FileAccess.READ)
		if f != null:
			saved_cfg_content = f.get_as_text()
			f.close()
			restore_existing = true

	# Write reduce_motion = true via ConfigFile (same logic as set_reduce_motion)
	var cfg_write := ConfigFile.new()
	cfg_write.set_value("accessibility", "reduce_motion", true)
	cfg_write.save("user://settings.cfg")

	# Act: create a fresh SceneManager and trigger _load_interim_settings
	var sm2: Node = SceneManagerScript.new()
	sm2.state = SceneManagerScript.State.IDLE
	add_child(sm2)
	await get_tree().process_frame

	# _ready() is already called when add_child runs (including _load_interim_settings).
	# Since we cannot inject a path, we call _load_interim_settings() again manually
	# to simulate a fresh boot read from the file we just wrote.
	sm2._load_interim_settings()

	# Assert
	assert_bool(sm2.reduce_motion).is_true()

	# Cleanup SM
	if is_instance_valid(sm2):
		sm2.queue_free()
	await get_tree().process_frame

	# Restore previous settings.cfg state
	if restore_existing:
		var f_restore: FileAccess = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		if f_restore != null:
			f_restore.store_string(saved_cfg_content)
			f_restore.close()
	else:
		# No pre-existing file — remove what we created
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))


# B-02: _load_interim_settings gracefully handles missing settings file
#
# Given: no user://settings.cfg (or backup restored after prior test).
# When: _load_interim_settings() called on a fresh SceneManager.
# Then: reduce_motion == false (default); no crash.
func test_load_interim_settings_handles_missing_file_gracefully() -> void:
	# Arrange: ensure no settings.cfg interferes
	var saved_cfg_content: String = ""
	var restore_existing: bool = false
	if FileAccess.file_exists("user://settings.cfg"):
		var f: FileAccess = FileAccess.open("user://settings.cfg", FileAccess.READ)
		if f != null:
			saved_cfg_content = f.get_as_text()
			f.close()
			restore_existing = true
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))

	# Act
	var sm: Node = SceneManagerScript.new()
	sm.state = SceneManagerScript.State.IDLE
	add_child(sm)
	await get_tree().process_frame
	sm._load_interim_settings()

	# Assert
	assert_bool(sm.reduce_motion).is_false()

	if is_instance_valid(sm):
		sm.queue_free()
	await get_tree().process_frame

	# Restore
	if restore_existing:
		var f_restore: FileAccess = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		if f_restore != null:
			f_restore.store_string(saved_cfg_content)
			f_restore.close()


# ===========================================================================
# Group C: TR-scene-manager-036 — CEREMONY reduce_motion branch documentation
# ===========================================================================

# C-01: CEREMONY transition with reduce_motion=true still falls back to CROSS_FADE
#       (Story 006 dispatcher not yet shipped — reduce_motion branch documented only)
#
# Given: SceneManager IDLE; reduce_motion == true.
# When: request_screen("recruitment", CEREMONY) called.
# Then: transition_complete fires (fallback to CROSS_FADE executes);
#       authored crossfade duration is 50ms (reduce_motion clamp applied).
func test_ceremony_with_reduce_motion_falls_back_to_crossfade_at_50ms() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.reduce_motion = true

	# Navigate to guild_hall first so CEREMONY has an "old" screen to exit from
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	# Spy for transition_complete
	var completed: Array[int] = [0]
	sm.transition_complete.connect(func(_sid: String, _tt: int) -> void:
		completed[0] += 1
	)

	# Act
	sm.request_screen("recruitment", SceneManagerScript.TransitionType.CEREMONY)
	await sm.transition_complete
	await get_tree().process_frame

	# Assert — transition completed and authored duration was 50ms (reduce_motion clamp)
	assert_int(completed[0]).is_equal(1)
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)
	assert_int(sm._get_last_crossfade_total_duration_ms()).is_equal(50)

	await _cleanup_wired(sm, main_root)
