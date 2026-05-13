# Regression test for S14-M6: SceneManager.show_modal / hide_modal must call
# the modal's on_enter / on_exit lifecycle hooks automatically.
#
# Origin: PR #58 (v0.0.0.17) found that Hero Detail modal showed "Hero Name" /
# "Class" / "Level 1" placeholder labels instead of real hero data because
# SceneManager.show_modal() added the modal to the tree but did NOT call its
# on_enter hook (where _render_all runs). Pattern: lifecycle asymmetry vs
# request_screen, which DOES call on_enter automatically.
#
# This test locks in the patched contract: show_modal calls on_enter once
# AFTER add_child + tracking + state transition; hide_modal calls on_exit
# once BEFORE queue_free. Modals without these methods are unaffected.
#
# Strategy: wired non-autoload SceneManager + temporary MainRoot. The modal
# is a SpyScreen (recorded hook log) so we can assert exact call counts and
# ordering. Mirrors the pattern in tests/integration/scene_manager/
# offline_replay_modal_coordination_test.gd.
#
# S14-M6 — Sprint 14, Hero Detail lifecycle hardening.
extends GdUnitTestSuite

const SceneManagerScript = preload("res://src/core/scene_manager/scene_manager.gd")
const SpyScreenScript = preload("res://tests/fixtures/spy_screen.gd")
const MAIN_ROOT_SCENE_PATH: String = "res://src/core/scene_manager/MainRoot.tscn"


# ---------------------------------------------------------------------------
# Helper: wired SceneManager + MainRoot (canonical pattern).
# ---------------------------------------------------------------------------
func _make_wired_scene_manager() -> Array:
	var sm: Node = SceneManagerScript.new()
	sm._settings_cfg_path = "user://test_show_modal_lifecycle_settings.cfg"
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
# Helper: an underlying screen that records on_pause / on_resume so we can
# distinguish them from the modal's on_enter / on_exit in mixed logs.
# ---------------------------------------------------------------------------
class FakeUnderlyingScreen extends Control:
	var pause_count: int = 0
	var resume_count: int = 0
	func on_pause() -> void:
		pause_count += 1
	func on_resume() -> void:
		resume_count += 1


# ===========================================================================
# Group A: show_modal lifecycle — modal.on_enter is called exactly once
# ===========================================================================

# A-01: show_modal calls modal.on_enter() exactly once.
#
# Given: SceneManager IDLE; SpyScreen modal with empty hook_log.
# When: sm.show_modal(modal).
# Then: hook_log contains exactly one on_enter entry.
func test_show_modal_calls_modal_on_enter_exactly_once() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]
	var modal: SpyScreen = SpyScreenScript.new()

	# Act
	sm.show_modal(modal)
	await get_tree().process_frame

	# Assert — exactly one on_enter in the log
	var on_enter_count: int = 0
	for entry in modal.hook_log:
		if entry["hook"] == "on_enter":
			on_enter_count += 1
	assert_int(on_enter_count).is_equal(1)

	# Cleanup
	sm.hide_modal(modal)
	await _cleanup_wired(sm, main_root)


# A-02: show_modal calls modal.on_enter AFTER the modal is in the tree.
#
# Given: SpyScreen modal not yet added.
# When: sm.show_modal(modal).
# Then: at the moment on_enter fires, modal.is_inside_tree() must be true.
#       (Verified via a custom SpyScreen subclass that captures is_inside_tree
#       in its on_enter override.)
class TreeMembershipSpy extends "res://src/core/scene_manager/screen.gd":
	var was_in_tree_on_enter: bool = false
	func on_enter() -> void:
		was_in_tree_on_enter = is_inside_tree()


func test_show_modal_calls_on_enter_after_modal_is_in_tree() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]
	var modal: TreeMembershipSpy = TreeMembershipSpy.new()

	# Act
	sm.show_modal(modal)
	await get_tree().process_frame

	# Assert
	assert_bool(modal.was_in_tree_on_enter).is_true()

	# Cleanup
	sm.hide_modal(modal)
	await _cleanup_wired(sm, main_root)


# A-03: show_modal calls modal.on_enter AFTER state transitions to PAUSED.
#
# Hero Detail's on_enter may need to know SceneManager.state — assert state
# is PAUSED at the moment on_enter fires.
class StateAtEnterSpy extends "res://src/core/scene_manager/screen.gd":
	var state_at_enter: int = -1
	var sm_ref: Node = null
	func on_enter() -> void:
		if sm_ref != null:
			state_at_enter = sm_ref.state


func test_show_modal_calls_on_enter_after_state_is_paused() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]
	var modal: StateAtEnterSpy = StateAtEnterSpy.new()
	modal.sm_ref = sm

	# Act
	sm.show_modal(modal)
	await get_tree().process_frame

	# Assert — state was PAUSED when modal.on_enter ran
	assert_int(modal.state_at_enter).is_equal(SceneManagerScript.State.PAUSED)

	# Cleanup
	sm.hide_modal(modal)
	await _cleanup_wired(sm, main_root)


# A-04: show_modal with a modal that lacks on_enter does not error.
#
# Plain Control (no Screen base, no on_enter method) must still be hosted.
# Duck-typing via has_method must not assume the method exists.
func test_show_modal_with_plain_control_does_not_error() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]
	var modal: Control = Control.new()  # no on_enter method

	# Act
	sm.show_modal(modal)
	await get_tree().process_frame

	# Assert — state still transitioned; modal still hosted
	assert_int(sm.state).is_equal(SceneManagerScript.State.PAUSED)
	assert_bool(modal.is_inside_tree()).is_true()

	# Cleanup
	sm.hide_modal(modal)
	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group B: hide_modal lifecycle — modal.on_exit is called exactly once
# ===========================================================================

# B-01: hide_modal calls modal.on_exit() exactly once before queue_free.
#
# Given: show_modal called; SpyScreen hook_log contains one on_enter.
# When: hide_modal(modal).
# Then: hook_log contains exactly one on_exit entry, and it comes AFTER
#       the on_enter entry (ordering: on_enter → on_exit).
func test_hide_modal_calls_modal_on_exit_exactly_once() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]
	var modal: SpyScreen = SpyScreenScript.new()

	sm.show_modal(modal)
	await get_tree().process_frame

	# Act
	sm.hide_modal(modal)

	# Assert — exactly one on_exit; appears after on_enter in the log
	var on_exit_count: int = 0
	var on_enter_index: int = -1
	var on_exit_index: int = -1
	for i in modal.hook_log.size():
		var entry: Dictionary = modal.hook_log[i]
		if entry["hook"] == "on_enter" and on_enter_index == -1:
			on_enter_index = i
		if entry["hook"] == "on_exit":
			on_exit_count += 1
			on_exit_index = i
	assert_int(on_exit_count).is_equal(1)
	assert_int(on_enter_index).is_greater_equal(0)
	assert_int(on_exit_index).is_greater(on_enter_index)

	# Cleanup
	await _cleanup_wired(sm, main_root)


# B-02: hide_modal calls on_exit BEFORE the modal is queue_freed.
#
# Critical for signal handler cleanup — at the moment on_exit fires, the
# modal must still be in the tree (else signal disconnect would fail).
class TreeMembershipExitSpy extends "res://src/core/scene_manager/screen.gd":
	var was_in_tree_on_exit: bool = false
	func on_exit() -> void:
		was_in_tree_on_exit = is_inside_tree()


func test_hide_modal_calls_on_exit_while_modal_still_in_tree() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]
	var modal: TreeMembershipExitSpy = TreeMembershipExitSpy.new()

	sm.show_modal(modal)
	await get_tree().process_frame

	# Act
	sm.hide_modal(modal)

	# Assert — modal was still in the tree when on_exit ran
	assert_bool(modal.was_in_tree_on_exit).is_true()

	# Cleanup
	await _cleanup_wired(sm, main_root)


# B-03: hide_modal with a modal that lacks on_exit does not error.
#
# Plain Control (no Screen base, no on_exit method) must still be hidden +
# freed cleanly. Duck-typing must guard the call.
func test_hide_modal_with_plain_control_does_not_error() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]
	var modal: Control = Control.new()  # no on_exit method

	sm.show_modal(modal)
	await get_tree().process_frame

	# Act
	sm.hide_modal(modal)

	# Assert — state returned to IDLE
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group C: full ordering — production lifecycle sequence
# ===========================================================================

# C-01: complete show → hide cycle produces on_enter → on_exit on the modal
# while the underlying screen records on_pause → on_resume in interleaved
# order.
#
# Expected order:
#   1. modal.on_enter (show_modal)
#   2. modal.on_exit  (hide_modal, before queue_free)
# Underlying screen records on_pause once (show_modal) and on_resume once
# (hide_modal), but those are tested elsewhere — this test focuses on the
# modal hooks specifically.
func test_full_show_hide_cycle_modal_hooks_ordered_enter_then_exit() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var underlying: FakeUnderlyingScreen = auto_free(FakeUnderlyingScreen.new())
	sm.current_screen = underlying

	var modal: SpyScreen = SpyScreenScript.new()

	# Act — full cycle
	sm.show_modal(modal)
	await get_tree().process_frame
	sm.hide_modal(modal)

	# Assert — modal hook order is on_enter then on_exit
	var hooks: Array = []
	for entry in modal.hook_log:
		hooks.append(entry["hook"])
	assert_array(hooks).contains_exactly(["on_enter", "on_exit"])

	# Assert — underlying screen pause/resume cycled (sanity check that the
	# existing show_modal / hide_modal contract is not regressed)
	assert_int(underlying.pause_count).is_equal(1)
	assert_int(underlying.resume_count).is_equal(1)

	# Cleanup
	await _cleanup_wired(sm, main_root)
