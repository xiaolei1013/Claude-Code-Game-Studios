# Tests for Story S12-S2: ADR-0014 show_modal / hide_modal coordination.
#
# Covers:
#   show_modal: modal added to OverlayLayer; state → PAUSED; on_pause called;
#               _modal_pause_count unchanged; get_tree().paused unchanged (false).
#   hide_modal: modal queue_free'd; state → IDLE; on_resume called.
#   Edge cases: hide_modal with untracked modal → push_warning + no-op.
#               two show_modal calls without intervening hide → both hosted.
#               hide_modal does not transition to IDLE if push_overlay stack non-empty.
#
# Strategy: wired non-autoload SceneManager + temporary MainRoot. A fake screen
# node with spied on_pause / on_resume methods is installed as current_screen.
# Modal instances are plain Control nodes (auto_free'd after assertions via
# queue_free in cleanup — hide_modal does that for us in the happy path).
#
# ADR-0014 §Time-gated UX — TR-scene-manager-009
extends GdUnitTestSuite

const SceneManagerScript = preload("res://src/core/scene_manager/scene_manager.gd")
const MAIN_ROOT_SCENE_PATH: String = "res://src/core/scene_manager/MainRoot.tscn"


# ---------------------------------------------------------------------------
# Helper: wired SceneManager + MainRoot (canonical pattern)
# ---------------------------------------------------------------------------
func _make_wired_scene_manager() -> Array:
	var sm: Node = SceneManagerScript.new()
	# Isolate from real user://settings.cfg so reduce_motion doesn't bleed in
	# from prior dev-machine launches. _ready() runs at add_child().
	sm._settings_cfg_path = "user://test_offline_replay_modal_settings.cfg"
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
	if get_tree().paused:
		get_tree().paused = false
	if is_instance_valid(sm):
		sm.queue_free()
	if is_instance_valid(main_root):
		main_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Helper: a fake screen node exposing on_pause/on_resume call-count spies.
# Installed as sm.current_screen before exercising show_modal/hide_modal.
# ---------------------------------------------------------------------------
class FakeScreen extends Control:
	var pause_count: int = 0
	var resume_count: int = 0
	func on_pause() -> void:
		pause_count += 1
	func on_resume() -> void:
		resume_count += 1
	func on_enter() -> void:
		pass
	func on_exit() -> void:
		pass


# ===========================================================================
# Group A: show_modal happy path — ADR-0014
# ===========================================================================

# A-01: show_modal adds modal to OverlayLayer and transitions state to PAUSED
#
# Given: SceneManager IDLE; a FakeScreen installed as current_screen.
# When: show_modal(modal) called.
# Then: modal.get_parent() == OverlayLayer; state == PAUSED; on_pause called once;
#       _modal_pause_count == 0; get_tree().paused == false.
func test_show_modal_adds_to_overlay_layer_and_pauses_state() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var fake_screen: FakeScreen = auto_free(FakeScreen.new())
	sm.current_screen = fake_screen

	var modal: Control = Control.new()  # owned by test; hide_modal will queue_free it

	# Act
	sm.show_modal(modal)
	await get_tree().process_frame

	# Assert — state
	assert_int(sm.state).is_equal(SceneManagerScript.State.PAUSED)

	# Assert — modal is a child of OverlayLayer
	var main_root_node: Node = get_tree().root.get_node_or_null("MainRoot")
	assert_object(main_root_node).is_not_null()
	var overlay_layer: Node = main_root_node.get_node_or_null("OverlayLayer")
	assert_object(overlay_layer).is_not_null()
	assert_bool(modal.get_parent() == overlay_layer).is_true()

	# Assert — on_pause fired once on fake screen
	assert_int(fake_screen.pause_count).is_equal(1)

	# Assert — _modal_pause_count is UNCHANGED (0); tree NOT paused
	assert_int(sm._modal_pause_count).is_equal(0)
	assert_bool(get_tree().paused).is_false()

	# Cleanup — hide_modal frees the modal
	sm.hide_modal(modal)
	await _cleanup_wired(sm, main_root)


# A-02: hide_modal frees the modal and transitions state back to IDLE
#
# Given: show_modal was called; state == PAUSED.
# When: hide_modal(modal) called.
# Then: state == IDLE; on_resume called once; modal is freed (no longer in tree).
func test_hide_modal_frees_modal_and_returns_to_idle() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var fake_screen: FakeScreen = auto_free(FakeScreen.new())
	sm.current_screen = fake_screen

	var modal: Control = Control.new()

	sm.show_modal(modal)
	await get_tree().process_frame
	assert_int(sm.state).is_equal(SceneManagerScript.State.PAUSED)

	# Act
	sm.hide_modal(modal)
	await get_tree().process_frame

	# Assert — state is IDLE
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	# Assert — on_resume fired once
	assert_int(fake_screen.resume_count).is_equal(1)

	# Assert — modal was freed
	assert_bool(is_instance_valid(modal)).is_false()

	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group B: Edge cases — ADR-0014
# ===========================================================================

# B-01: hide_modal with untracked modal → push_warning + no-op (state unchanged)
#
# Given: SceneManager IDLE; no modal shown.
# When: hide_modal called with an untracked Control.
# Then: state remains IDLE; no crash.
func test_hide_modal_untracked_modal_is_no_op() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	var stray_modal: Control = auto_free(Control.new())

	# Act — should push_warning but not crash or change state
	sm.hide_modal(stray_modal)
	await get_tree().process_frame

	# Assert — state unchanged
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	await _cleanup_wired(sm, main_root)


# B-02: two show_modal calls stack both modals as OverlayLayer children
#
# Given: SceneManager IDLE.
# When: show_modal(modal_a) then show_modal(modal_b) called.
# Then: both modals are children of OverlayLayer; state == PAUSED.
func test_two_show_modals_both_hosted_on_overlay_layer() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var modal_a: Control = Control.new()
	var modal_b: Control = Control.new()

	# Act
	sm.show_modal(modal_a)
	sm.show_modal(modal_b)
	await get_tree().process_frame

	# Assert — state PAUSED
	assert_int(sm.state).is_equal(SceneManagerScript.State.PAUSED)

	var main_root_node: Node = get_tree().root.get_node_or_null("MainRoot")
	var overlay_layer: Node = main_root_node.get_node_or_null("OverlayLayer")
	assert_object(overlay_layer).is_not_null()
	assert_bool(modal_a.get_parent() == overlay_layer).is_true()
	assert_bool(modal_b.get_parent() == overlay_layer).is_true()

	# Cleanup — hide both
	sm.hide_modal(modal_a)
	sm.hide_modal(modal_b)
	await get_tree().process_frame

	await _cleanup_wired(sm, main_root)


# B-03: hide_modal does not return to IDLE while push_overlay stack is non-empty
#
# Given: push_overlay("settings") is active; then show_modal(modal) called.
# When: hide_modal(modal) called (removes freestanding modal).
# Then: state remains PAUSED (push_overlay overlay still open).
func test_hide_modal_stays_paused_when_push_overlay_stack_nonempty() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Push a registry overlay (pause_on_open = false so get_tree().paused stays false)
	sm.push_overlay("settings", false)
	assert_int(sm.state).is_equal(SceneManagerScript.State.PAUSED)

	var modal: Control = Control.new()
	sm.show_modal(modal)
	await get_tree().process_frame
	assert_int(sm.state).is_equal(SceneManagerScript.State.PAUSED)

	# Act — hide the freestanding modal
	sm.hide_modal(modal)
	await get_tree().process_frame

	# Assert — state remains PAUSED (settings overlay still open)
	assert_int(sm.state).is_equal(SceneManagerScript.State.PAUSED)

	# Cleanup
	sm.pop_overlay("settings")
	await get_tree().process_frame
	await _cleanup_wired(sm, main_root)


# B-04: show_modal with no current_screen does not crash
#
# Given: SceneManager IDLE; current_screen == null.
# When: show_modal(modal) called.
# Then: state == PAUSED; no crash (on_pause guard protects null current_screen).
func test_show_modal_with_no_current_screen_does_not_crash() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Ensure no current_screen
	sm.current_screen = null
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	var modal: Control = Control.new()

	# Act — should not crash even with null current_screen
	sm.show_modal(modal)
	await get_tree().process_frame

	# Assert
	assert_int(sm.state).is_equal(SceneManagerScript.State.PAUSED)

	# Cleanup
	sm.hide_modal(modal)
	await get_tree().process_frame
	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group C: ADR-0014 tree-pause invariant — offline replay must keep ticking
# ===========================================================================

# C-01: show_modal does NOT set get_tree().paused (offline replay must tick)
#
# Given: SceneManager IDLE; get_tree().paused == false.
# When: show_modal(modal) called.
# Then: get_tree().paused STILL false; _modal_pause_count == 0.
func test_show_modal_does_not_pause_tree() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	assert_bool(get_tree().paused).is_false()
	assert_int(sm._modal_pause_count).is_equal(0)

	var modal: Control = Control.new()

	# Act
	sm.show_modal(modal)
	await get_tree().process_frame

	# Assert — tree NOT paused; counter NOT incremented
	assert_bool(get_tree().paused).is_false()
	assert_int(sm._modal_pause_count).is_equal(0)

	# Cleanup
	sm.hide_modal(modal)
	await get_tree().process_frame
	await _cleanup_wired(sm, main_root)


# C-02: hide_modal does NOT call _apply_pause_state; _modal_pause_count stays 0
#
# Given: show_modal was called; _modal_pause_count == 0.
# When: hide_modal called.
# Then: _modal_pause_count still 0; get_tree().paused still false.
func test_hide_modal_does_not_increment_or_decrement_pause_count() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var modal: Control = Control.new()
	sm.show_modal(modal)
	await get_tree().process_frame

	assert_int(sm._modal_pause_count).is_equal(0)
	assert_bool(get_tree().paused).is_false()

	# Act
	sm.hide_modal(modal)
	await get_tree().process_frame

	# Assert
	assert_int(sm._modal_pause_count).is_equal(0)
	assert_bool(get_tree().paused).is_false()

	await _cleanup_wired(sm, main_root)
