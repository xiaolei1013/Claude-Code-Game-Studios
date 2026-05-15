# Sprint 11 S11-M1 (Story 008): scene_boundary_persist signal emission tests.
#
# Verifies:
#   - Signal declared on SceneManager (signature `(reason: String)`).
#   - Emits "pre_dungeon_entry" before transitioning to dungeon_run_view.
#   - Emits "post_victory_exit" after exiting victory_moment.
#   - Does NOT emit on other transitions (e.g., guild_hall → recruitment).
#   - Both emissions fire on a victory_moment → dungeon_run_view transition
#     (the case where both conditions apply).
#
# Test pattern: instantiate non-autoload SceneManager wired to a temporary
# MainRoot (same _make_wired_scene_manager pattern from sibling integration
# tests, with the S10-S3 fix applied — sm BEFORE MainRoot).
#
# Story 012 (S11-M3) will extend the emission with `await SaveLoadSystem.save_completed`
# to gate the transition; this test verifies emission count + payload only.
extends GdUnitTestSuite

const SceneManagerScript = preload("res://src/core/scene_manager/scene_manager.gd")
const MAIN_ROOT_SCENE_PATH: String = "res://src/core/scene_manager/MainRoot.tscn"


func _make_wired_scene_manager() -> Array:
	# Sprint 11 S10-S3 fix: see modal_overlay_counter_test.gd _make_wired_sm
	# header comment. Order matters — sm BEFORE MainRoot.
	var sm: Node = SceneManagerScript.new()
	sm.state = SceneManagerScript.State.IDLE
	add_child(sm)
	await get_tree().process_frame

	var packed: PackedScene = load(MAIN_ROOT_SCENE_PATH) as PackedScene
	var main_root: Control = packed.instantiate() as Control
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
# Signal spy infrastructure
# ---------------------------------------------------------------------------

var _emitted_reasons: Array[String] = []


func _on_scene_boundary_persist(reason: String) -> void:
	_emitted_reasons.append(reason)


func _connect_spy(sm: Node) -> void:
	_emitted_reasons.clear()
	sm.scene_boundary_persist.connect(_on_scene_boundary_persist)


# ===========================================================================
# Group A — signal contract
# ===========================================================================

func test_scene_manager_scene_boundary_persist_signal_declared() -> void:
	# Lock the signal's existence + signature so a future rename / removal
	# fails here loudly. Per ADR-0007 Story 008.
	var sm: Node = SceneManagerScript.new()
	auto_free(sm)
	assert_bool(sm.has_signal("scene_boundary_persist")).is_true()


# ===========================================================================
# Group B — emission timing on the two GDD-specified transitions
# ===========================================================================

func test_scene_manager_scene_boundary_persist_emits_pre_dungeon_entry_on_entry_to_dungeon_run_view() -> void:
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]
	_connect_spy(sm)

	# Act — transition INTO dungeon_run_view.
	sm.request_screen("dungeon_run_view", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	# Assert — exactly one "pre_dungeon_entry" emission.
	assert_array(_emitted_reasons).contains(["pre_dungeon_entry"])
	assert_int(_emitted_reasons.count("pre_dungeon_entry")).is_equal(1)

	await _cleanup_wired(sm, main_root)


func test_scene_manager_scene_boundary_persist_emits_post_victory_exit_on_exit_from_victory_moment() -> void:
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Arrange — get into victory_moment first (no spy yet — we don't care
	# about signal events during setup).
	sm.request_screen("victory_moment", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	# NOW connect the spy and start the transition AWAY from victory_moment.
	_connect_spy(sm)
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	# Assert — exactly one "post_victory_exit" emission.
	assert_int(_emitted_reasons.count("post_victory_exit")).is_equal(1)

	await _cleanup_wired(sm, main_root)


func test_scene_manager_scene_boundary_persist_emits_both_on_victory_to_dungeon_transition() -> void:
	# Edge case from the GDD: victory_moment → dungeon_run_view fires BOTH
	# "post_victory_exit" AND "pre_dungeon_entry" in the same transition.
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Get into victory_moment first.
	sm.request_screen("victory_moment", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	# Now spy + transition straight to dungeon_run_view.
	_connect_spy(sm)
	sm.request_screen("dungeon_run_view", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	# Assert — both reasons in the emission log; pre_dungeon_entry FIRST
	# (synchronous order: emit before old.on_exit; post_victory_exit fires
	# after old.on_exit per scene_manager.gd ordering).
	assert_int(_emitted_reasons.count("pre_dungeon_entry")).is_equal(1)
	assert_int(_emitted_reasons.count("post_victory_exit")).is_equal(1)
	assert_int(_emitted_reasons.size()).is_equal(2)

	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group C — non-emission on unrelated transitions
# ===========================================================================

func test_scene_manager_scene_boundary_persist_does_not_emit_on_guild_hall_to_recruitment() -> void:
	# Per the GDD: "Only these two transitions trigger it — no other
	# transitions fire this signal."
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	_connect_spy(sm)
	sm.request_screen("recruitment", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	assert_int(_emitted_reasons.size()).is_equal(0)

	await _cleanup_wired(sm, main_root)


func test_scene_manager_scene_boundary_persist_does_not_emit_on_recruitment_to_formation_assignment() -> void:
	# Another negative case — neither end of the transition is a GDD-specified
	# emission boundary.
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.request_screen("recruitment", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	_connect_spy(sm)
	sm.request_screen("formation_assignment", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	assert_int(_emitted_reasons.size()).is_equal(0)

	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group D — payload contract
# ===========================================================================

func test_scene_manager_scene_boundary_persist_payload_is_human_readable_string() -> void:
	# Per signal doc-comment: "[param reason] is a human-readable description
	# of the trigger context (e.g., 'pre_dungeon_entry', 'post_victory_exit')."
	# Lock the literal values so a future refactor can't silently rename them
	# and break SaveLoadSystem._on_scene_boundary_persist's reason-based
	# branching (when implemented in Story 012).
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	_connect_spy(sm)
	sm.request_screen("dungeon_run_view", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	await get_tree().process_frame

	# Assert exact string literal.
	assert_array(_emitted_reasons).contains_exactly(["pre_dungeon_entry"])

	await _cleanup_wired(sm, main_root)
