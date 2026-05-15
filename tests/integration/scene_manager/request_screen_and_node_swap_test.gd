# Tests for Story S5-M5: request_screen sole external API + ScreenContainer node-swap
#                         + first-launch routing.
# Updated for Story S5-M7 (tween-based transitions): "await 2 process frames" pattern
# replaced with "await sm.transition_complete" throughout, since transitions are now
# tween-driven and complete asynchronously via _on_transition_finished rather than
# a deferred call_deferred swap. See story-005-tween-transitions-and-leak-guard.md.
#
# Covers: TR-scene-manager-003, TR-scene-manager-004, TR-scene-manager-010,
#         TR-scene-manager-011, TR-scene-manager-014, TR-scene-manager-022,
#         TR-scene-manager-038, TR-scene-manager-039.
# AC H-03 (same-screen no-op), AC H-06 (first-launch routing).
#
# Integration test — uses a mix of:
#   - Non-autoload SceneManager instances wired to temporary MainRoot nodes (Groups A, F, G)
#   - Static/structural checks that do not require a live scene tree (Groups B, C)
#   - Registry / structural assertions (Groups C, E, H)
#
# For non-autoload tests: instantiate SceneManagerScript.new(), manually provide
# a temporary MainRoot + ScreenContainer, set state = IDLE, then exercise the API.
# Always queue_free() and await process_frame in cleanup to prevent cross-test leaks.
#
# Signal spy pattern: use an Array[int] as a reference-type counter so lambdas can
# mutate it (GDScript lambdas capture by value; only reference types are mutable
# from inside a lambda). Pattern: var spy := [0]; lambda: spy[0] += 1.
#
# ADR-0007: request_screen sole external API + node-swap pattern
# ADR-0003 Amendment #1: signal subscription at _ready() is safe across ranks
extends GdUnitTestSuite

const SceneManagerScript = preload("res://src/core/scene_manager/scene_manager.gd")
const MAIN_ROOT_SCENE_PATH: String = "res://src/core/scene_manager/MainRoot.tscn"

# Known canonical screen IDs (TR-scene-manager-022)
# Sprint 22 S22-M2: matchup_assignment removed — folded into
# formation_assignment as the in-screen Floor Picker overlay.
const CANONICAL_SCREEN_IDS: Array[String] = [
	"main_menu",
	"guild_hall",
	"recruitment",
	"formation_assignment",
	"dungeon_run_view",
	"victory_moment",
	"return_to_app",
]

# Default timeout for awaiting transition_complete in wired tests (ms).
# Tween-based transitions take at most 300ms (fade_to_black); allow generous headroom.
const _TRANSITION_TIMEOUT_MS: int = 2000


# ---------------------------------------------------------------------------
# Helper: create a non-autoload SceneManager wired to a temporary MainRoot.
#
# Returns [sm_instance, main_root_instance].
# Caller is responsible for calling _cleanup_wired() after assertions.
# Sets sm.state = IDLE so it's ready for direct request_screen calls.
# ---------------------------------------------------------------------------
func _make_wired_scene_manager() -> Array:
	# Sprint 11 S10-S3 fix: order matters. add_child(sm) FIRST while MainRoot is
	# absent from /root, so sm._ready() → _on_registry_ready() hits the test-env
	# guard at scene_manager.gd:959 and skips the boot auto-route to guild_hall.
	# Adding MainRoot AFTER avoids the boot transition racing with the test's
	# explicit request_screen calls. Boot auto-route was the root cause of
	# `_execute_transition requires IDLE state` assertion failures.
	var sm: Node = SceneManagerScript.new()
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


# ---------------------------------------------------------------------------
# Helper: await a transition_complete signal with a timeout guard.
# Replaces the old "await process_frame x2" pattern.
# The extra process_frame after transition_complete handles any deferred work
# that was scheduled inside _on_transition_finished (e.g., _drain_queued_request).
# ---------------------------------------------------------------------------
func _await_transition(sm: Node) -> void:
	await sm.transition_complete
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Helper: clean up a wired scene manager pair.
# ---------------------------------------------------------------------------
func _cleanup_wired(sm: Node, main_root: Node) -> void:
	if is_instance_valid(sm):
		sm.queue_free()
	if is_instance_valid(main_root):
		main_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# ===========================================================================
# Group A: TR-scene-manager-003 / TR-scene-manager-004 — Node-swap correctness
# ===========================================================================

# ---------------------------------------------------------------------------
# A-01: Requesting a new screen from IDLE swaps ScreenContainer contents
#
# Given: SceneManager in IDLE; no current screen (fresh wired instance).
# When: request_screen("guild_hall", CROSS_FADE) called; test awaits transition_complete.
# Then: ScreenContainer.get_child_count() == 1; current_screen_id == "guild_hall";
#       transition_complete emitted; state returns to IDLE.
# ---------------------------------------------------------------------------
func test_request_screen_swaps_to_new_screen() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var screen_container: Node = main_root.get_node_or_null("ScreenContainer")
	assert_object(screen_container).is_not_null()

	# Signal spy: Array[int] so lambda can mutate it by reference
	var transition_count: Array[int] = [0]
	sm.transition_complete.connect(func(_sid: String, _tt: int) -> void:
		transition_count[0] += 1
	)

	# Act
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	# Await transition_complete signal (tween-based — not 2-frame deferred).
	await _await_transition(sm)

	# Assert — ScreenContainer has exactly one child
	assert_int(screen_container.get_child_count()).is_equal(1)
	# current_screen is non-null and current_screen_id is "guild_hall"
	assert_object(sm.current_screen).is_not_null()
	assert_str(sm.current_screen_id).is_equal("guild_hall")
	# transition_complete fired once
	assert_int(transition_count[0]).is_equal(1)
	# State returned to IDLE
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ---------------------------------------------------------------------------
# A-02: Node-swap from screen A to screen B — old screen freed, new screen enters
#
# Given: SceneManager in IDLE; current screen is guild_hall.
# When: request_screen("recruitment") called.
# Then: ScreenContainer.get_child_count() == 1; current_screen_id == "recruitment";
#       screen_changed emitted with correct new_id and old_id.
# ---------------------------------------------------------------------------
func test_request_screen_replaces_existing_screen() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var screen_container: Node = main_root.get_node_or_null("ScreenContainer")
	assert_object(screen_container).is_not_null()

	# Navigate to guild_hall first
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await _await_transition(sm)
	assert_str(sm.current_screen_id).is_equal("guild_hall")

	# Signal spy using Array[String] for mutable capture
	var changed_args: Array[String] = ["", ""]  # [new_id, old_id]
	sm.screen_changed.connect(func(new_id: String, old_id: String) -> void:
		changed_args[0] = new_id
		changed_args[1] = old_id
	)

	# Act — navigate to recruitment
	sm.request_screen("recruitment", SceneManagerScript.TransitionType.CROSS_FADE)
	await _await_transition(sm)

	# Assert
	assert_int(screen_container.get_child_count()).is_equal(1)
	assert_str(sm.current_screen_id).is_equal("recruitment")
	assert_str(changed_args[0]).is_equal("recruitment")
	assert_str(changed_args[1]).is_equal("guild_hall")
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ---------------------------------------------------------------------------
# A-03: on_exit is called before on_enter during a swap
#
# Given: SceneManager in IDLE; current screen is guild_hall (which has on_exit).
# When: request_screen("recruitment") called.
# Then: old screen is freed (was queue_free'd before tween start);
#       new screen is active after transition_complete.
#       Lifecycle order contract: on_exit fires synchronously before tween start;
#       on_enter fires during the tween callback at peak opacity.
# ---------------------------------------------------------------------------
func test_node_swap_old_screen_is_freed_after_swap() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Navigate to guild_hall first
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await _await_transition(sm)
	assert_str(sm.current_screen_id).is_equal("guild_hall")

	var old_screen_before_swap: Control = sm.current_screen
	assert_object(old_screen_before_swap).is_not_null()

	# Verify old screen has on_exit (Story 004 base class enforced)
	assert_bool(old_screen_before_swap.has_method("on_exit")).is_true()

	# Act — queue_free of old screen is called synchronously in _execute_transition
	# BEFORE the tween starts. await transition_complete to let tween complete.
	sm.request_screen("recruitment", SceneManagerScript.TransitionType.CROSS_FADE)
	await _await_transition(sm)

	# Assert — current screen is now recruitment, old screen is freed (no longer valid)
	assert_str(sm.current_screen_id).is_equal("recruitment")
	assert_bool(is_instance_valid(old_screen_before_swap)).is_false()

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ---------------------------------------------------------------------------
# A-04: New screen exposes on_enter lifecycle hook (duck-typed)
# ---------------------------------------------------------------------------
func test_new_screen_has_on_enter_method() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Act
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await _await_transition(sm)

	# Assert — current_screen exposes the lifecycle hooks
	assert_object(sm.current_screen).is_not_null()
	assert_bool(sm.current_screen.has_method("on_enter")).is_true()
	assert_bool(sm.current_screen.has_method("on_exit")).is_true()
	assert_bool(sm.current_screen.has_method("on_pause")).is_true()
	assert_bool(sm.current_screen.has_method("on_resume")).is_true()

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group B: TR-scene-manager-010 — Sole external API (CI grep enforcement)
# ===========================================================================

# ---------------------------------------------------------------------------
# B-01: No external change_scene_to_* calls in src/ (excluding scene_manager/)
# ---------------------------------------------------------------------------
func test_no_external_change_scene_to_calls() -> void:
	# Walk src/ excluding src/core/scene_manager/, grep for forbidden API calls.
	var forbidden_patterns: Array[String] = [
		"change_scene_to_packed",
		"change_scene_to_file",
	]
	var violations: Array[String] = _grep_src_excluding_scene_manager(forbidden_patterns)

	# Assert — zero hits
	assert_int(violations.size()).is_equal(0)
	if violations.size() > 0:
		push_error("[TR-010] Forbidden direct scene change calls found: %s" % str(violations))


# ---------------------------------------------------------------------------
# B-02: No external ScreenContainer.add_child / remove_child calls in src/
# ---------------------------------------------------------------------------
func test_no_external_screen_container_modifications() -> void:
	# Walk src/ excluding src/core/scene_manager/, grep for ScreenContainer mutation.
	var forbidden_patterns: Array[String] = [
		"ScreenContainer.add_child",
		"ScreenContainer.remove_child",
	]
	var violations: Array[String] = _grep_src_excluding_scene_manager(forbidden_patterns)

	# Assert — zero hits
	assert_int(violations.size()).is_equal(0)
	if violations.size() > 0:
		push_error("[TR-010] Forbidden ScreenContainer mutations found: %s" % str(violations))


# ---------------------------------------------------------------------------
# Helper: recursively walk src/ and collect lines matching any of the given
# string patterns. Returns a list of "filepath:line_number:line_content" strings.
# Excludes src/core/scene_manager/ from the walk (it is the owner of these APIs).
# Tests/ is not in src/ so it is automatically excluded.
# ---------------------------------------------------------------------------
func _grep_src_excluding_scene_manager(patterns: Array[String]) -> Array[String]:
	var violations: Array[String] = []
	var src_dir: String = "res://src"
	var excluded_prefix: String = "res://src/core/scene_manager"
	_walk_and_grep(src_dir, excluded_prefix, patterns, violations)
	return violations


func _walk_and_grep(
		dir_path: String,
		excluded_prefix: String,
		patterns: Array[String],
		out_violations: Array[String]) -> void:
	if dir_path.begins_with(excluded_prefix):
		return

	var da: DirAccess = DirAccess.open(dir_path)
	if da == null:
		return

	da.list_dir_begin()
	var entry: String = da.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = da.get_next()
			continue

		var full_path: String = dir_path.path_join(entry)
		if da.current_is_dir():
			_walk_and_grep(full_path, excluded_prefix, patterns, out_violations)
		elif entry.ends_with(".gd"):
			_grep_file(full_path, patterns, out_violations)
		entry = da.get_next()
	da.list_dir_end()


func _grep_file(
		file_path: String,
		patterns: Array[String],
		out_violations: Array[String]) -> void:
	var fa: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if fa == null:
		return

	var line_num: int = 0
	while not fa.eof_reached():
		var line: String = fa.get_line()
		line_num += 1
		for pattern: String in patterns:
			if line.contains(pattern):
				out_violations.append("%s:%d: %s" % [file_path, line_num, line.strip_edges()])
	fa.close()


# ===========================================================================
# Group C: TR-scene-manager-011 — TransitionType enum completeness
# ===========================================================================

# ---------------------------------------------------------------------------
# C-01: TransitionType enum has exactly 7 values
# ---------------------------------------------------------------------------
func test_transition_type_enum_has_seven_values() -> void:
	assert_int(SceneManagerScript.TransitionType.size()).is_equal(7)
	assert_int(SceneManagerScript.TransitionType.keys().size()).is_equal(7)


# ---------------------------------------------------------------------------
# C-02: TransitionType enum canonical order
# ---------------------------------------------------------------------------
func test_transition_type_canonical_order() -> void:
	assert_int(SceneManagerScript.TransitionType.CROSS_FADE).is_equal(0)
	assert_int(SceneManagerScript.TransitionType.SLIDE_UP).is_equal(1)
	assert_int(SceneManagerScript.TransitionType.SLIDE_LEFT).is_equal(2)
	assert_int(SceneManagerScript.TransitionType.SLIDE_DOWN).is_equal(3)
	assert_int(SceneManagerScript.TransitionType.FADE_TO_BLACK).is_equal(4)
	assert_int(SceneManagerScript.TransitionType.PUSH_MODAL).is_equal(5)
	assert_int(SceneManagerScript.TransitionType.CEREMONY).is_equal(6)


# ===========================================================================
# Group D: TR-scene-manager-014 / AC H-03 — Same-screen no-op
# ===========================================================================

# ---------------------------------------------------------------------------
# D-01: Same-screen request is a silent no-op — no signals fire, state stays IDLE
# ---------------------------------------------------------------------------
func test_same_screen_request_is_silent_noop() -> void:
	# Arrange — fresh instance, manually set IDLE + current_screen_id
	var sm: Node = SceneManagerScript.new()
	sm.state = SceneManagerScript.State.IDLE
	sm.current_screen_id = "guild_hall"

	# Signal spies using Array[int] (mutable by reference in lambda)
	var screen_changed_count: Array[int] = [0]
	var transition_complete_count: Array[int] = [0]
	sm.screen_changed.connect(func(_n: String, _o: String) -> void:
		screen_changed_count[0] += 1
	)
	sm.transition_complete.connect(func(_s: String, _t: int) -> void:
		transition_complete_count[0] += 1
	)

	# Act
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)

	# Assert — no signals fired, state unchanged
	assert_int(screen_changed_count[0]).is_equal(0)
	assert_int(transition_complete_count[0]).is_equal(0)
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)
	assert_str(sm.current_screen_id).is_equal("guild_hall")

	# Cleanup
	sm.free()


# ---------------------------------------------------------------------------
# D-02: Same-screen no-op with a different transition type — still no-op
# ---------------------------------------------------------------------------
func test_same_screen_with_different_transition_still_noop() -> void:
	# Arrange — same screen regardless of transition parameter
	var sm: Node = SceneManagerScript.new()
	sm.state = SceneManagerScript.State.IDLE
	sm.current_screen_id = "guild_hall"

	var signal_fire_count: Array[int] = [0]
	sm.screen_changed.connect(func(_n: String, _o: String) -> void:
		signal_fire_count[0] += 1
	)
	sm.transition_complete.connect(func(_s: String, _t: int) -> void:
		signal_fire_count[0] += 1
	)

	# Act — different transition type, same screen
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.FADE_TO_BLACK)

	# Assert — no signals, state unchanged
	assert_int(signal_fire_count[0]).is_equal(0)
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	# Cleanup
	sm.free()


# ---------------------------------------------------------------------------
# D-03: Same-screen no-op — current_screen (node ref) not freed
# ---------------------------------------------------------------------------
func test_same_screen_request_does_not_free_current_screen() -> void:
	# Arrange — create a minimal Control to act as current screen
	var dummy_screen: Control = Control.new()
	add_child(dummy_screen)
	await get_tree().process_frame

	var sm: Node = SceneManagerScript.new()
	sm.state = SceneManagerScript.State.IDLE
	sm.current_screen_id = "guild_hall"
	sm.current_screen = dummy_screen

	# Act
	sm.request_screen("guild_hall")

	# Assert — dummy_screen is still valid (queue_free was NOT called)
	assert_bool(is_instance_valid(dummy_screen)).is_true()

	# Cleanup
	sm.free()
	dummy_screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group E: TR-scene-manager-022 — MVP screens preloaded (count adjusted
# 2026-05-15 from 9 → 8 with Sprint 22 S22-M2 matchup_assignment fold)
# ===========================================================================

# ---------------------------------------------------------------------------
# E-01: _screen_registry has exactly 8 entries
# Sprint 22 S22-M2: matchup_assignment folded into formation_assignment as
# the in-screen Floor Picker overlay; registry shrunk 9 → 8.
# (Pre-S22-M2 count was 9 — Sprint 21+ Prestige V1.0 / Story 3 UI Slice B
# added hall_of_retired_heroes, growing 8 → 9; this fold takes it back to 8.)
# ---------------------------------------------------------------------------
func test_screen_registry_has_eight_entries() -> void:
	var sm: Node = SceneManagerScript.new()
	assert_int(sm._screen_registry.size()).is_equal(8)
	sm.free()


# ---------------------------------------------------------------------------
# E-02: _screen_registry contains exactly the 7 canonical IDs
# ---------------------------------------------------------------------------
func test_screen_registry_contains_canonical_ids() -> void:
	var sm: Node = SceneManagerScript.new()
	var registry: Dictionary = sm._screen_registry

	for id: String in CANONICAL_SCREEN_IDS:
		assert_bool(registry.has(id)).is_true()

	sm.free()


# ---------------------------------------------------------------------------
# E-03: All 7 registered PackedScenes are non-null and instantiable
# ---------------------------------------------------------------------------
func test_all_registered_packedscenes_load_and_instantiate() -> void:
	var sm: Node = SceneManagerScript.new()
	var registry: Dictionary = sm._screen_registry

	for id: String in registry.keys():
		var packed: PackedScene = registry[id] as PackedScene
		assert_object(packed).is_not_null()

		var inst: Control = packed.instantiate() as Control
		assert_object(inst).is_not_null()
		# Clean up the instantiated node (never added to tree)
		inst.free()

	sm.free()


# ---------------------------------------------------------------------------
# E-04: Screen registry resource paths match canonical layout
#        (load-bearing path commitment — renaming a .tscn must fail this test)
# ---------------------------------------------------------------------------
func test_screen_registry_resource_paths_match_canonical_layout() -> void:
	var sm: Node = SceneManagerScript.new()
	var registry: Dictionary = sm._screen_registry

	var expected_paths: Dictionary = {
		"main_menu": "res://assets/screens/main_menu/main_menu.tscn",
		"guild_hall": "res://assets/screens/guild_hall/guild_hall.tscn",
		"recruitment": "res://assets/screens/recruitment/recruitment.tscn",
		"formation_assignment": "res://assets/screens/formation_assignment/formation_assignment.tscn",
		"dungeon_run_view": "res://assets/screens/dungeon_run_view/dungeon_run_view.tscn",
		"victory_moment": "res://assets/screens/victory_moment/victory_moment.tscn",
		"return_to_app": "res://assets/screens/return_to_app/return_to_app.tscn",
		"hall_of_retired_heroes": "res://assets/screens/hall_of_retired_heroes/hall_of_retired_heroes.tscn",
	}

	for id: String in expected_paths.keys():
		var packed: PackedScene = registry.get(id) as PackedScene
		assert_object(packed).is_not_null()
		assert_str(packed.resource_path).is_equal(expected_paths[id])

	sm.free()


# ===========================================================================
# Group F: TR-scene-manager-038 / AC H-06 — First-launch routes to guild_hall
# ===========================================================================

# ---------------------------------------------------------------------------
# F-01: First-launch routes to guild_hall — empty queue, no prior request
#
# Given: fresh SceneManager (UNINITIALIZED); empty _queued_request.
# When: _on_registry_ready() is called (simulates DataRegistry.registry_ready firing).
# Then: state advances to TRANSITIONING (within handler) then IDLE (after tween finishes);
#       current_screen_id == "guild_hall".
# ---------------------------------------------------------------------------
func test_first_launch_routes_to_guild_hall() -> void:
	# Arrange — wired instance so ScreenContainer is resolvable
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Reset to UNINITIALIZED to simulate first-launch
	sm.state = SceneManagerScript.State.UNINITIALIZED
	sm.current_screen_id = ""
	sm.current_screen = null
	sm._queued_request = {}

	# Act — simulate registry_ready signal
	sm._on_registry_ready()

	# After handler: state is TRANSITIONING (tween in progress)
	assert_int(sm.state).is_equal(SceneManagerScript.State.TRANSITIONING)

	# Wait for tween to complete
	await _await_transition(sm)

	# Assert
	assert_str(sm.current_screen_id).is_equal("guild_hall")
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ---------------------------------------------------------------------------
# F-02: Queued request takes precedence over default guild_hall route
#
# Given: SceneManager in UNINITIALIZED; _queued_request populated with "recruitment".
# When: _on_registry_ready() called.
# Then: current_screen_id == "recruitment", NOT "guild_hall".
# ---------------------------------------------------------------------------
func test_queued_request_takes_precedence_over_default_guild_hall() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Reset to UNINITIALIZED with a queued request
	sm.state = SceneManagerScript.State.UNINITIALIZED
	sm.current_screen_id = ""
	sm.current_screen = null
	sm._queued_request = {
		"screen_id": "recruitment",
		"transition": SceneManagerScript.TransitionType.CROSS_FADE
	}

	# Act
	sm._on_registry_ready()
	await _await_transition(sm)

	# Assert — queued request wins; guild_hall never shown
	assert_str(sm.current_screen_id).is_equal("recruitment")
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ---------------------------------------------------------------------------
# F-03: request_screen while UNINITIALIZED populates _queued_request
#        and drains it after _on_registry_ready (AC H-06)
# ---------------------------------------------------------------------------
func test_request_before_registry_ready_is_queued_and_drains_on_ready() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Force UNINITIALIZED
	sm.state = SceneManagerScript.State.UNINITIALIZED
	sm.current_screen_id = ""
	sm.current_screen = null
	sm._queued_request = {}

	# Act — call request_screen while UNINITIALIZED
	sm.request_screen("victory_moment", SceneManagerScript.TransitionType.CEREMONY)

	# Assert — queued, not executed yet
	assert_bool(sm._queued_request.is_empty()).is_false()
	assert_str(sm._queued_request.get("screen_id", "")).is_equal("victory_moment")
	assert_str(sm.current_screen_id).is_equal("")

	# Now simulate registry_ready
	sm._on_registry_ready()
	await _await_transition(sm)

	# Assert — queued request was drained and executed
	assert_str(sm.current_screen_id).is_equal("victory_moment")
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)
	assert_bool(sm._queued_request.is_empty()).is_true()

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ---------------------------------------------------------------------------
# F-04: TRANSITIONING-queue drain — request screen B while screen A's tween is
# in flight; after A's tween completes, B must auto-execute via
# _drain_queued_request_if_any() called from _on_transition_finished.
# Per QA review G-1: this is the most operationally dangerous untested path.
# Covers _on_transition_finished → _drain_queued_request_if_any → _execute_transition.
# ---------------------------------------------------------------------------
func test_scene_manager_transitioning_queue_drains_after_swap_completes() -> void:
	# Arrange — wire SceneManager + MainRoot, get to IDLE on screen A.
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Establish screen A as the current screen (guild_hall).
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await _await_transition(sm)
	assert_str(sm.current_screen_id).is_equal("guild_hall")
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	# Act — fire request for screen B (recruitment); state goes TRANSITIONING.
	sm.request_screen("recruitment", SceneManagerScript.TransitionType.CROSS_FADE)
	# Mid-transition (BEFORE the tween finishes), queue screen C.
	# This exercises the TRANSITIONING-queue branch of request_screen.
	sm.request_screen("victory_moment", SceneManagerScript.TransitionType.FADE_TO_BLACK)

	# Pre-assert — state is TRANSITIONING; C is queued; B's tween not yet complete.
	assert_int(sm.state).is_equal(SceneManagerScript.State.TRANSITIONING)
	assert_str(sm._queued_request.get("screen_id", "")).is_equal("victory_moment")
	assert_int(sm._queued_request.get("transition", -1)).is_equal(SceneManagerScript.TransitionType.FADE_TO_BLACK)

	# Wait for B's tween to complete + C's tween to complete.
	# _drain_queued_request_if_any runs inside _on_transition_finished after B finishes,
	# immediately starting C's transition. We need two transition_complete emissions.
	await sm.transition_complete  # B's tween done
	await get_tree().process_frame  # let drain + C's tween start
	await sm.transition_complete  # C's tween done
	await get_tree().process_frame  # settle

	# Assert — C (victory_moment) is now the active screen; queue is empty; state IDLE.
	assert_str(sm.current_screen_id).is_equal("victory_moment")
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)
	assert_bool(sm._queued_request.is_empty()).is_true()

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group G: TR-scene-manager-039 — Resume with offline gains accepts the API call
# ===========================================================================

# ---------------------------------------------------------------------------
# G-01: request_screen("return_to_app", SLIDE_DOWN) works from IDLE
#
# Given: SceneManager in IDLE on guild_hall.
# When: request_screen("return_to_app", SLIDE_DOWN) called.
# Then: transition executes; current_screen_id == "return_to_app".
# ---------------------------------------------------------------------------
func test_request_screen_return_to_app_with_slide_down() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Navigate to guild_hall first
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	await _await_transition(sm)
	assert_str(sm.current_screen_id).is_equal("guild_hall")

	var transition_count: Array[int] = [0]
	sm.transition_complete.connect(func(_s: String, _t: int) -> void:
		transition_count[0] += 1
	)

	# Act — post-boot offline-gains route (ADR-0014 / Story 009 wires the caller)
	sm.request_screen("return_to_app", SceneManagerScript.TransitionType.SLIDE_DOWN)
	await _await_transition(sm)

	# Assert
	assert_str(sm.current_screen_id).is_equal("return_to_app")
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)
	assert_int(transition_count[0]).is_equal(1)

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ---------------------------------------------------------------------------
# G-02: transition_complete signal carries correct screen_id and transition_type
# ---------------------------------------------------------------------------
func test_transition_complete_signal_carries_correct_args() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	# Use Array captures for mutable signal spy state
	var received_args: Array = ["", -1]  # [screen_id, transition_type]
	sm.transition_complete.connect(func(sid: String, tt: int) -> void:
		received_args[0] = sid
		received_args[1] = tt
	)

	# Act
	sm.request_screen("dungeon_run_view", SceneManagerScript.TransitionType.FADE_TO_BLACK)
	await _await_transition(sm)

	# Assert
	assert_str(received_args[0] as String).is_equal("dungeon_run_view")
	assert_int(received_args[1] as int).is_equal(SceneManagerScript.TransitionType.FADE_TO_BLACK)

	# Cleanup
	await _cleanup_wired(sm, main_root)


# ===========================================================================
# Group H: Additional structural / config checks
# ===========================================================================

# ---------------------------------------------------------------------------
# H-01: scene_manager_config.tres file exists at canonical path (TR-037)
# ---------------------------------------------------------------------------
func test_scene_manager_config_tres_exists() -> void:
	assert_bool(FileAccess.file_exists("res://assets/data/config/scene_manager_config.tres")).is_true()


# ---------------------------------------------------------------------------
# H-02: scene_manager_config.tres loads without error
# ---------------------------------------------------------------------------
func test_scene_manager_config_tres_loads() -> void:
	var cfg: Resource = load("res://assets/data/config/scene_manager_config.tres")
	assert_object(cfg).is_not_null()


# ---------------------------------------------------------------------------
# H-03: screen_changed signal carries correct new_id / old_id on first transition
# ---------------------------------------------------------------------------
func test_screen_changed_signal_on_first_transition() -> void:
	# Arrange
	var result: Array = await _make_wired_scene_manager()
	var sm: Node = result[0]
	var main_root: Node = result[1]

	var changed_args: Array[String] = ["_unset_", "_unset_"]  # [new_id, old_id]
	sm.screen_changed.connect(func(new_id: String, old_id: String) -> void:
		changed_args[0] = new_id
		changed_args[1] = old_id
	)

	# Act — first ever transition; old_id should be ""
	sm.request_screen("main_menu", SceneManagerScript.TransitionType.CROSS_FADE)
	await _await_transition(sm)

	# Assert
	assert_str(changed_args[0]).is_equal("main_menu")
	assert_str(changed_args[1]).is_equal("")

	# Cleanup
	await _cleanup_wired(sm, main_root)
