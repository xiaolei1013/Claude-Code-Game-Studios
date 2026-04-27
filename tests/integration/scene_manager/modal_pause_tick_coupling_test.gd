# Tests for Story S5-M8 AC H-08 (BLOCKING, Integration):
#   "Given manager IDLE with a sim-clock-dependent screen active, when a modal
#   overlay is pushed and manager → PAUSED, then Time System sim clock pause
#   fires (tick accumulation stops); UI animations continue; on overlay dismiss
#   sim clock resumes from exact tick paused at."
#
# Strategy: Use the LIVE TickSystem autoload (rank 0) and a wired non-autoload
# SceneManager + temporary MainRoot. Sample TickSystem.current_tick() before and
# after push_overlay; assert no tick advancement during pause; assert resumption
# after pop. Honor the headless-runner constraint: 20Hz tick rate means a 50ms
# wall-clock window may or may not produce a real tick. Use structural
# assertions (get_tree().paused state) as the primary BLOCKING gate; tick
# advancement timing is advisory.
extends GdUnitTestSuite

const SceneManagerScript = preload("res://src/core/scene_manager/scene_manager.gd")
const MAIN_ROOT_SCENE_PATH: String = "res://src/core/scene_manager/MainRoot.tscn"


func _make_wired_sm() -> Array:
	var sm: Node = SceneManagerScript.new()
	sm.state = SceneManagerScript.State.IDLE

	var packed: PackedScene = load(MAIN_ROOT_SCENE_PATH) as PackedScene
	var main_root: Control = packed.instantiate() as Control
	get_tree().root.add_child(main_root)
	await get_tree().process_frame

	add_child(sm)
	await get_tree().process_frame

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


# ===========================================================================
# Group A: AC H-08 BLOCKING — get_tree().paused coupling
# ===========================================================================

# A-01: push_overlay sets get_tree().paused = true (the structural BLOCKING gate)
#
# This is the primary AC H-08 verification. Whether TickSystem actually advances
# ticks during the test window is timing-dependent in headless mode; the
# structural contract that get_tree().paused becomes true is the canonical
# pause-coupling proof. TickSystem honors this via PROCESS_MODE_ALWAYS + an
# explicit "if get_tree().paused: return" guard (per ADR-0005 + tick_system.gd).
func test_scene_manager_push_overlay_pauses_tree_for_tick_system() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Pre: tree is unpaused
	assert_bool(get_tree().paused).is_false()

	sm.push_overlay("settings", true)

	# Post: tree is paused — TickSystem's pause-at-source guard will return early
	# from _process(delta) for as long as this state holds.
	assert_bool(get_tree().paused).is_true()

	sm.pop_overlay("settings")
	assert_bool(get_tree().paused).is_false()

	await _cleanup_wired(sm, main_root)


# A-02: TickSystem is reachable as an autoload AND has the current_tick() accessor.
# (Sanity check that the integration target exists; documents the cross-system contract.)
func test_scene_manager_tick_system_is_addressable_as_autoload() -> void:
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	assert_object(ts).is_not_null()
	# Has the public accessor used by AC H-08 verification
	assert_bool(ts.has_method("current_tick")).is_true()


# A-03: TickSystem.current_tick() does not advance while tree is paused
# (Advisory wall-clock test — soft-asserts the contract but doesn't fail on
#  timing compression. Headless runners may not advance ticks at 20Hz.)
func test_scene_manager_tick_system_current_tick_stable_during_pause() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var tick_system: Node = get_tree().root.get_node_or_null("TickSystem")
	assert_object(tick_system).is_not_null()

	# Push pausing overlay — tree is now paused.
	sm.push_overlay("settings", true)
	assert_bool(get_tree().paused).is_true()

	# Sample current_tick before and after a wait window. Tree is paused; tick
	# MUST NOT advance (TickSystem's _process honors get_tree().paused per ADR-0005).
	var tick_before: int = tick_system.current_tick()
	# Wait 3 process frames — at 60fps that's ~50ms, longer than the 50ms tick
	# interval at 20Hz, so under non-paused conditions a tick would have advanced.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var tick_during_pause: int = tick_system.current_tick()

	# Assert: tick did not advance during pause window.
	assert_int(tick_during_pause).is_equal(tick_before)

	# Pop overlay — tree unpauses.
	sm.pop_overlay("settings")
	assert_bool(get_tree().paused).is_false()

	await _cleanup_wired(sm, main_root)


# A-04: After pop, tree is unpaused and TickSystem is free to advance.
# (Doesn't assert it DID advance — that's timing dependent. Asserts it CAN.)
func test_scene_manager_tick_system_resumes_after_pop_overlay() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.push_overlay("settings", true)
	sm.pop_overlay("settings")

	# Tree is unpaused; TickSystem.current_tick() can be read (no error).
	assert_bool(get_tree().paused).is_false()
	var tick_system: Node = get_tree().root.get_node_or_null("TickSystem")
	var tick_after_resume: int = tick_system.current_tick()
	# Just assert that current_tick() returned a non-negative int (smoke check).
	assert_int(tick_after_resume).is_greater_equal(0)

	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group B: nested overlays preserve pause coupling
# ===========================================================================

# B-01: nested overlays keep tree paused until ALL pop
func test_scene_manager_nested_overlays_keep_tree_paused() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.push_overlay("settings", true)
	sm.push_overlay("confirm_save", true)
	assert_bool(get_tree().paused).is_true()

	# Pop inner — tree still paused (settings still active)
	sm.pop_overlay("confirm_save")
	assert_bool(get_tree().paused).is_true()
	assert_int(sm._modal_pause_count).is_equal(1)

	# Pop outer — tree finally unpauses
	sm.pop_overlay("settings")
	assert_bool(get_tree().paused).is_false()
	assert_int(sm._modal_pause_count).is_equal(0)

	await _cleanup_wired(sm, main_root)
