# Tests for Story S5-M8: Modal overlay API + counter-based _modal_pause_count.
# Covers: TR-scene-manager-007 (overlay pushes onto OverlayLayer; on_pause/on_resume fires)
#         + counter invariants (never negative; pop without push warns + no-ops)
#         + lifecycle hook ordering on modal cycle (uses SpyScreen fixture).
#
# Pattern: instantiate non-autoload SceneManager + a temporary MainRoot. Set state=IDLE
# directly to bypass the full transition machinery for unit-test isolation. For tests
# that need a live current_screen (lifecycle hook tests), inject a SpyScreen via direct
# field assignment (sm.current_screen = SpyScreen.new()). This is documented as
# legitimate test access — the underscore-private fields are convention only in GDScript.
#
# AC H-08 (BLOCKING) integration with TickSystem is covered separately in
# tests/integration/scene_manager/modal_pause_tick_coupling_test.gd.
extends GdUnitTestSuite

const SceneManagerScript = preload("res://src/core/scene_manager/scene_manager.gd")
const SpyScreenScript = preload("res://tests/fixtures/spy_screen.gd")
const MAIN_ROOT_SCENE_PATH: String = "res://src/core/scene_manager/MainRoot.tscn"


# ---------------------------------------------------------------------------
# Helper: wire a fresh non-autoload SceneManager to a temporary MainRoot.
# Returns [sm, main_root]. Caller must call _cleanup_wired().
# State is set to IDLE so push_overlay/pop_overlay take the real path.
# ---------------------------------------------------------------------------
func _make_wired_sm() -> Array:
	# Sprint 11 S10-S3 fix: order matters. add_child(sm) FIRST, while MainRoot is
	# absent from /root, so sm._ready() → _on_registry_ready() hits the test-env
	# guard at scene_manager.gd:959 and skips the boot auto-route to guild_hall.
	# Adding MainRoot AFTER avoids the boot transition racing with the test's
	# explicit request_screen calls. The boot auto-route was the root cause of
	# `_execute_transition requires IDLE state` assertion failures: drain queue
	# would re-enter _execute_transition while state was still TRANSITIONING.
	var sm: Node = SceneManagerScript.new()
	sm.state = SceneManagerScript.State.IDLE
	add_child(sm)
	await get_tree().process_frame

	var packed: PackedScene = load(MAIN_ROOT_SCENE_PATH) as PackedScene
	var main_root: Control = packed.instantiate() as Control
	get_tree().root.add_child(main_root)
	await get_tree().process_frame

	# State should be IDLE post-_ready due to test-env guard early-return at
	# scene_manager.gd:959. Set defensively in case the guard moves.
	sm.state = SceneManagerScript.State.IDLE

	return [sm, main_root]


func _cleanup_wired(sm: Node, main_root: Node) -> void:
	# Defensive: ensure tree is unpaused even if a test leaves it paused (would
	# corrupt subsequent tests). Reset directly — this is teardown, not a violation.
	if get_tree().paused:
		get_tree().paused = false
	if is_instance_valid(sm):
		sm.queue_free()
	if is_instance_valid(main_root):
		main_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# ===========================================================================
# Group A: TR-scene-manager-007 — Overlay placement + state transitions
# ===========================================================================

# A-01: push_overlay adds to OverlayLayer, NOT ScreenContainer
func test_scene_manager_push_overlay_adds_to_overlay_layer() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Navigate to guild_hall first so we have a current_screen for on_pause to fire on.
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete

	var overlay_layer: CanvasLayer = main_root.get_node_or_null("OverlayLayer")
	var screen_container: Node = main_root.get_node_or_null("ScreenContainer")
	assert_object(overlay_layer).is_not_null()
	assert_object(screen_container).is_not_null()

	# Pre-condition: ScreenContainer has 1 child (guild_hall), OverlayLayer is empty.
	var screen_count_before: int = screen_container.get_child_count()
	assert_int(overlay_layer.get_child_count()).is_equal(0)

	# Act
	sm.push_overlay("settings", true)

	# Assert
	assert_int(overlay_layer.get_child_count()).is_equal(1)
	assert_int(screen_container.get_child_count()).is_equal(screen_count_before)

	await _cleanup_wired(sm, main_root)


# A-02: push_overlay does NOT change current_screen / current_screen_id
func test_scene_manager_push_overlay_does_not_change_current_screen() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete

	var screen_before: Control = sm.current_screen
	var screen_id_before: String = sm.current_screen_id

	sm.push_overlay("settings", true)

	assert_object(sm.current_screen).is_same(screen_before)
	assert_str(sm.current_screen_id).is_equal(screen_id_before)

	await _cleanup_wired(sm, main_root)


# A-03: push_overlay sets state == PAUSED
func test_scene_manager_push_overlay_sets_state_to_paused() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	sm.push_overlay("settings", true)
	assert_int(sm.state).is_equal(SceneManagerScript.State.PAUSED)

	await _cleanup_wired(sm, main_root)


# A-04: pop_overlay restores state to IDLE
func test_scene_manager_pop_overlay_restores_state_to_idle() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete

	sm.push_overlay("settings", true)
	assert_int(sm.state).is_equal(SceneManagerScript.State.PAUSED)

	sm.pop_overlay("settings")
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	await _cleanup_wired(sm, main_root)


# A-05b: duplicate push (same overlay_id while still active) is a release-safe no-op
# (push_error + early return; counter NOT incremented twice; tree state unchanged)
# Story line 132 + GAP-1 from /code-review (was assert in original impl; now release-safe).
func test_scene_manager_duplicate_push_overlay_does_not_double_increment() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# First push — succeeds normally
	sm.push_overlay("settings", true)
	assert_int(sm._modal_pause_count).is_equal(1)
	assert_int(sm._active_overlays.size()).is_equal(1)
	var first_overlay: Control = sm._active_overlays["settings"]
	assert_object(first_overlay).is_not_null()

	# Second push with the SAME overlay_id while first is still active.
	# Implementation must reject (push_error + return) — NOT silently overwrite.
	sm.push_overlay("settings", true)

	# Counter MUST NOT have double-incremented
	assert_int(sm._modal_pause_count).is_equal(1)
	# _active_overlays still has exactly one entry — the original instance
	assert_int(sm._active_overlays.size()).is_equal(1)
	assert_object(sm._active_overlays["settings"]).is_same(first_overlay)
	# Tree state still paused (counter is 1, not 0 or 2)
	assert_bool(get_tree().paused).is_true()

	# Cleanup: pop and unpause
	sm.pop_overlay("settings")
	await _cleanup_wired(sm, main_root)


# A-05: pop_overlay on unknown id warns + no-ops (does not crash, does not change state)
func test_scene_manager_pop_overlay_unknown_id_warns_and_noops() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await sm.transition_complete

	# No overlays active; calling pop on a ghost id should be a silent no-op.
	sm.pop_overlay("ghost_overlay")

	# State unchanged
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)
	assert_int(sm._modal_pause_count).is_equal(0)
	assert_bool(get_tree().paused).is_false()

	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group B: counter invariant (_modal_pause_count never negative)
# ===========================================================================

# B-01: counter starts at 0
func test_scene_manager_modal_pause_count_starts_zero() -> void:
	var sm: Node = SceneManagerScript.new()
	assert_int(sm._modal_pause_count).is_equal(0)
	sm.free()


# B-02: push + pop cycle returns counter to 0; tree unpaused
func test_scene_manager_push_pop_cycle_returns_count_to_zero() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.push_overlay("settings", true)
	assert_int(sm._modal_pause_count).is_equal(1)
	assert_bool(get_tree().paused).is_true()

	sm.pop_overlay("settings")
	assert_int(sm._modal_pause_count).is_equal(0)
	assert_bool(get_tree().paused).is_false()

	await _cleanup_wired(sm, main_root)


# B-03: nested overlays increment the counter
func test_scene_manager_nested_overlays_increment_counter() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.push_overlay("settings", true)
	sm.push_overlay("confirm_save", true)

	assert_int(sm._modal_pause_count).is_equal(2)
	assert_bool(get_tree().paused).is_true()

	# Cleanup: pop both before teardown.
	sm.pop_overlay("confirm_save")
	sm.pop_overlay("settings")
	await _cleanup_wired(sm, main_root)


# B-04: pop in reverse order decrements counter step-by-step
func test_scene_manager_pop_in_reverse_decrements_counter() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.push_overlay("settings", true)
	sm.push_overlay("confirm_save", true)
	assert_int(sm._modal_pause_count).is_equal(2)

	sm.pop_overlay("confirm_save")
	assert_int(sm._modal_pause_count).is_equal(1)
	assert_bool(get_tree().paused).is_true()  # Still paused — settings still active

	sm.pop_overlay("settings")
	assert_int(sm._modal_pause_count).is_equal(0)
	assert_bool(get_tree().paused).is_false()

	await _cleanup_wired(sm, main_root)


# B-05: stray pops do not drive counter negative (clamped via maxi)
func test_scene_manager_stray_pop_does_not_go_negative() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Call pop_overlay 5 times on ghost ids — counter must stay at 0
	for i in range(5):
		sm.pop_overlay("ghost_%d" % i)
	assert_int(sm._modal_pause_count).is_equal(0)
	assert_bool(get_tree().paused).is_false()

	await _cleanup_wired(sm, main_root)


# B-06: non-pausing overlay (pause_on_open=false) does NOT increment counter
func test_scene_manager_non_pausing_push_does_not_increment_counter() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.push_overlay("hero_detail", false)

	# State is PAUSED (visual-modal contract), but counter and tree are unaffected.
	assert_int(sm._modal_pause_count).is_equal(0)
	assert_bool(get_tree().paused).is_false()

	sm.pop_overlay("hero_detail")
	assert_int(sm._modal_pause_count).is_equal(0)

	await _cleanup_wired(sm, main_root)


# B-07: mixed pause modes — non-pausing + pausing overlays interact correctly
func test_scene_manager_mixed_pause_modes() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Push non-pausing first
	sm.push_overlay("hero_detail", false)
	assert_int(sm._modal_pause_count).is_equal(0)
	assert_bool(get_tree().paused).is_false()

	# Push pausing — counter goes to 1
	sm.push_overlay("settings", true)
	assert_int(sm._modal_pause_count).is_equal(1)
	assert_bool(get_tree().paused).is_true()

	# Pop non-pausing first — counter unchanged
	sm.pop_overlay("hero_detail")
	assert_int(sm._modal_pause_count).is_equal(1)
	assert_bool(get_tree().paused).is_true()

	# Pop pausing — counter to 0; tree unpaused
	sm.pop_overlay("settings")
	assert_int(sm._modal_pause_count).is_equal(0)
	assert_bool(get_tree().paused).is_false()

	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group C: get_tree().paused coupling (sets follow counter)
# ===========================================================================

# C-01: get_tree().paused is true while count > 0
func test_scene_manager_paused_tree_when_count_positive() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	assert_bool(get_tree().paused).is_false()

	sm.push_overlay("settings", true)
	assert_bool(get_tree().paused).is_true()

	sm.pop_overlay("settings")
	await _cleanup_wired(sm, main_root)


# C-02: get_tree().paused returns to false after counter hits 0
func test_scene_manager_unpaused_tree_when_count_zero() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	sm.push_overlay("settings", true)
	sm.pop_overlay("settings")

	assert_bool(get_tree().paused).is_false()
	assert_int(sm._modal_pause_count).is_equal(0)

	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group D: lifecycle hook ordering on modal cycle (uses SpyScreen fixture)
# ===========================================================================

# D-01: on_pause fires on push_overlay
func test_scene_manager_on_pause_called_on_push_overlay() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Inject a SpyScreen as current_screen directly. This bypasses the transition
	# machinery — fine because we're testing the modal API contract, not transitions.
	var screen_spy: Node = SpyScreenScript.new()
	sm.current_screen = screen_spy
	sm.current_screen_id = "spy_screen"

	# Pre-condition: spy hook log is empty
	assert_int(screen_spy.hook_log.size()).is_equal(0)

	# Act
	sm.push_overlay("settings", true)

	# Assert: on_pause was called exactly once
	assert_int(screen_spy.hook_log.size()).is_equal(1)
	assert_str(screen_spy.hook_log[0]["hook"]).is_equal("on_pause")

	# Cleanup
	sm.pop_overlay("settings")
	screen_spy.free()
	await _cleanup_wired(sm, main_root)


# D-02: on_resume fires on the LAST pop_overlay
func test_scene_manager_on_resume_called_on_last_pop_overlay() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var screen_spy: Node = SpyScreenScript.new()
	sm.current_screen = screen_spy
	sm.current_screen_id = "spy_screen"

	sm.push_overlay("settings", true)
	sm.pop_overlay("settings")

	# After full cycle: hook_log = [on_pause, on_resume] in order
	assert_int(screen_spy.hook_log.size()).is_equal(2)
	assert_str(screen_spy.hook_log[0]["hook"]).is_equal("on_pause")
	assert_str(screen_spy.hook_log[1]["hook"]).is_equal("on_resume")

	screen_spy.free()
	await _cleanup_wired(sm, main_root)


# D-03: on_resume only fires after ALL overlays close (nested case)
func test_scene_manager_on_resume_only_after_all_overlays_pop() -> void:
	var result: Array = await _make_wired_sm()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var screen_spy: Node = SpyScreenScript.new()
	sm.current_screen = screen_spy
	sm.current_screen_id = "spy_screen"

	# Push two overlays
	sm.push_overlay("settings", true)
	sm.push_overlay("confirm_save", true)

	# Pop the inner one first — on_resume must NOT have fired yet.
	sm.pop_overlay("confirm_save")
	# Hook log so far: only on_pause (fired once at first push)
	# Note: on_pause fires on EACH push (per the implementation calling on_pause unconditionally
	# when current_screen exists). Verify the actual contract.
	# Filter the hook log for on_resume entries — should be 0 at this point.
	var resume_count_after_inner_pop: int = 0
	for entry: Dictionary in screen_spy.hook_log:
		if entry["hook"] == "on_resume":
			resume_count_after_inner_pop += 1
	assert_int(resume_count_after_inner_pop).is_equal(0)

	# Pop the outer one — on_resume must now fire (state returns to IDLE).
	sm.pop_overlay("settings")
	var resume_count_after_outer_pop: int = 0
	for entry: Dictionary in screen_spy.hook_log:
		if entry["hook"] == "on_resume":
			resume_count_after_outer_pop += 1
	assert_int(resume_count_after_outer_pop).is_equal(1)

	screen_spy.free()
	await _cleanup_wired(sm, main_root)
