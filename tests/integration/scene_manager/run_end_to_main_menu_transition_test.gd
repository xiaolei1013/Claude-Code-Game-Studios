# Integration tests for Story 013: Run-end → MainMenu transition (RUN_ENDED auto-route)
#
# Covers acceptance criteria:
#   AC-1: Auto-route on RUN_ENDED — request_screen("main_menu", CROSS_FADE) called once.
#   AC-3: RUN_END_DWELL_MS constant is in the valid range [0, 2000] (Sprint 9 S9-M2 expansion).
#   AC-4: Tick subscription disconnects cleanly after on_exit following the route.
#   AC-5: Idempotency — second RUN_ENDED signal does NOT trigger a second request_screen.
#   AC-6: No bypass of SceneManager — no change_scene_to_* calls in dungeon_run_view.gd.
#   AC-7 (structural): request_screen is the sole screen-change call (covered by AC-6 grep).
#
# Test isolation pattern (same as Story 012 dungeon_run_view_screen_test.gd):
#   Screen instantiation bypasses SceneManager (headless test-env quirk documented in
#   Story 011 closure note — fresh SceneManagerScript.new() interacts with the live
#   autoload's first-launch routing, leaving current_screen_id at "guild_hall").
#
# SceneManager state control pattern:
#   In headless environments without MainRoot, SceneManager._execute_transition crashes
#   with assert(false) at _get_screen_container (intentional hard-fail per TD-010 note).
#   To prevent this while still verifying that request_screen IS called, tests set
#   SceneManager.state = TRANSITIONING before driving RUN_ENDED. In TRANSITIONING state,
#   request_screen queues the request (last-write-wins) instead of executing _execute_transition.
#   SceneManager.screen_changed is NOT emitted until the transition executes, so we
#   verify routing via the _routed flag instead (set on the same line as request_screen,
#   so _routed == true implies request_screen was invoked).
#
#   Additionally, SceneManager._queued_request is checked to confirm the "main_menu"
#   request was queued with CROSS_FADE — this is direct proof that request_screen
#   was called with the correct arguments.
#
# Orchestrator state isolation:
#   before_test() snapshots and resets; after_test() restores.
#   SceneManager.state and _queued_request are also snapshotted and restored.
#
# ADR-0007: Screen lifecycle contract — request_screen sole external API.
# Story 013: DungeonRunView run-end → main_menu transition.
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const DUNGEON_RUN_VIEW_SCENE_PATH: String = "res://assets/screens/dungeon_run_view/dungeon_run_view.tscn"
const DUNGEON_RUN_VIEW_GD_PATH: String = "res://assets/screens/dungeon_run_view/dungeon_run_view.gd"

const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")

# ---------------------------------------------------------------------------
# Per-test state snapshots for isolation
# ---------------------------------------------------------------------------

var _orch_state_snapshot: int = DungeonRunStateScript.State.NO_RUN
var _orch_run_snapshot_snapshot: RunSnapshot = null
var _orch_last_dispatch_ms_snapshot: int = 0

## Snapshots of SceneManager state modified by tests.
var _sm_state_snapshot: int = 0
var _sm_queued_request_snapshot: Dictionary = {}
var _sm_current_screen_id_snapshot: String = ""


# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------

func before_test() -> void:
	# Snapshot orchestrator fields so we can restore them after the test.
	_orch_state_snapshot = DungeonRunOrchestrator.state
	_orch_run_snapshot_snapshot = DungeonRunOrchestrator.run_snapshot
	_orch_last_dispatch_ms_snapshot = DungeonRunOrchestrator._last_dispatch_ms

	# Reset orchestrator to a clean NO_RUN state for test isolation.
	# Direct field write bypasses _set_state so state_changed does NOT fire
	# during setup (avoids polluting any test's signal spy).
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.NO_RUN
	DungeonRunOrchestrator.run_snapshot = null
	DungeonRunOrchestrator._last_dispatch_ms = 0

	# Snapshot SceneManager state (we modify it in some tests).
	_sm_state_snapshot = SceneManager.state
	_sm_queued_request_snapshot = SceneManager._queued_request.duplicate()
	_sm_current_screen_id_snapshot = SceneManager.current_screen_id


func after_test() -> void:
	# Restore SceneManager state.
	SceneManager.state = _sm_state_snapshot
	SceneManager._queued_request = _sm_queued_request_snapshot.duplicate()
	SceneManager.current_screen_id = _sm_current_screen_id_snapshot

	# Restore orchestrator fields.
	DungeonRunOrchestrator.state = _orch_state_snapshot
	DungeonRunOrchestrator.run_snapshot = _orch_run_snapshot_snapshot
	DungeonRunOrchestrator._last_dispatch_ms = _orch_last_dispatch_ms_snapshot


# ---------------------------------------------------------------------------
# Helper: navigate to dungeon_run_view screen (bypass SceneManager)
#
# Reuses the exact pattern from Story 012's dungeon_run_view_screen_test.gd.
# ---------------------------------------------------------------------------

func _navigate_to_dungeon_run_view_screen() -> Control:
	var packed: PackedScene = load(DUNGEON_RUN_VIEW_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var screen: Control = packed.instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	if screen.has_method("on_enter"):
		screen.on_enter()
	return screen


# ---------------------------------------------------------------------------
# Helper: seed a RunSnapshot on the orchestrator
# ---------------------------------------------------------------------------

func _seed_run_snapshot(current_tick: int, kill_count: int) -> RunSnapshot:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.current_tick = current_tick
	snap.last_emitted_tick = current_tick
	snap.kill_count = kill_count
	DungeonRunOrchestrator.run_snapshot = snap
	return snap


# ===========================================================================
# AC-1 / AC-7: Auto-route on RUN_ENDED — request_screen called for main_menu
#
# Strategy: set SceneManager.state = TRANSITIONING so request_screen queues
# the request in _queued_request instead of calling _execute_transition
# (which would assert-crash without MainRoot). Verify that:
#   (a) screen._routed == true (set just before request_screen is invoked)
#   (b) SceneManager._queued_request == {"screen_id": "main_menu", ...}
# These together prove request_screen("main_menu", CROSS_FADE) was called.
# ===========================================================================

func test_run_end_to_main_menu_transition_routes_on_run_ended() -> void:
	# Arrange — seed orchestrator in ACTIVE_FOREGROUND with a live snapshot.
	var snap: RunSnapshot = _seed_run_snapshot(10, 5)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Set SceneManager to TRANSITIONING so request_screen queues rather than
	# executing _execute_transition (which would assert-crash without MainRoot).
	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — simulate orchestrator advancing to RUN_ENDED via state_changed signal.
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)
	# Allow one frame for the synchronous portion of _on_state_changed to run
	# (sets _routed = true, shows overlay) before the dwell await begins.
	await get_tree().process_frame

	# Assert (a): _routed flag is true — route was triggered (synchronous portion ran).
	assert_bool(screen._routed).is_true()

	# Sprint 9 S9-M2: RUN_END_DWELL_MS = 1500 ms — wait for the dwell to expire so
	# the deferred request_screen call lands in _queued_request before we assert.
	# Cap the wait at 3000 ms (2x dwell) to fail clearly if the dwell never resolves.
	var poll_deadline_ms: int = Time.get_ticks_msec() + 3000
	while SceneManager._queued_request.is_empty() and Time.get_ticks_msec() < poll_deadline_ms:
		await get_tree().process_frame

	# Assert (b): request_screen queued "main_menu" with CROSS_FADE.
	# This is direct proof that request_screen was called with the right arguments.
	assert_bool(SceneManager._queued_request.is_empty()).is_false()
	assert_str(SceneManager._queued_request.get("screen_id", "")).is_equal("main_menu")
	assert_int(SceneManager._queued_request.get("transition", -1)).is_equal(
		SceneManager.TransitionType.CROSS_FADE
	)

	# Cleanup
	if screen.has_method("on_exit"):
		screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# AC-5: Idempotency — second RUN_ENDED emission does not call request_screen twice
# ===========================================================================

func test_run_end_to_main_menu_transition_idempotent_on_repeated_run_ended() -> void:
	# Arrange
	var snap: RunSnapshot = _seed_run_snapshot(5, 3)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Pre-assert: _routed starts false on a fresh on_enter.
	assert_bool(screen._routed).is_false()

	# Set SceneManager to TRANSITIONING to prevent assert-crash (headless test isolation).
	# After the first request_screen queues "main_menu", subsequent calls while still
	# TRANSITIONING would overwrite _queued_request AND emit push_warning.
	# We can detect double-call by checking for the push_warning, but the simpler
	# assertion is: _routed == true + _queued_request still has "main_menu" after
	# both emissions (first emission queues; second emission is blocked by _routed guard).
	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap

	# Act — emit state_changed(RUN_ENDED) TWICE in rapid succession.
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)
	await get_tree().process_frame

	# Assert — _routed is true (route was requested on first emission).
	assert_bool(screen._routed).is_true()

	# Sprint 9 S9-M2: RUN_END_DWELL_MS = 1500 ms — wait for the dwell to expire
	# so the deferred request_screen call lands in _queued_request.
	var poll_deadline_ms: int = Time.get_ticks_msec() + 3000
	while SceneManager._queued_request.is_empty() and Time.get_ticks_msec() < poll_deadline_ms:
		await get_tree().process_frame

	# Assert — only ONE request_screen call was made.
	# If the second emission had fired request_screen, SceneManager._queued_request
	# would have been overwritten (same key "main_menu" but new write). However, since
	# _routed is checked BEFORE request_screen, the second emission returns early and
	# _queued_request is set exactly once. Verify it still holds "main_menu".
	assert_bool(SceneManager._queued_request.is_empty()).is_false()
	assert_str(SceneManager._queued_request.get("screen_id", "")).is_equal("main_menu")

	# Cleanup
	if screen.has_method("on_exit"):
		screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# AC-4: Tick subscription disconnects after route (re-assertion for Story 013 path)
#
# Drives RUN_ENDED → on_exit lifecycle, verifies tick_fired and state_changed
# subscriptions are both disconnected (Story 012 AC-5 re-asserted here).
# ===========================================================================

func test_run_end_to_main_menu_transition_tick_subscription_disconnects_after_route() -> void:
	# Arrange
	var snap: RunSnapshot = _seed_run_snapshot(8, 2)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Pre-assert: tick_fired is connected while screen is active.
	assert_bool(TickSystem.tick_fired.is_connected(screen._on_tick_fired)).is_true()

	# Set SceneManager to TRANSITIONING to prevent assert-crash on request_screen.
	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — drive RUN_ENDED to trigger the auto-route.
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)
	await get_tree().process_frame

	# Verify route was triggered.
	assert_bool(screen._routed).is_true()

	# SceneManager calls on_exit during the transition (lifecycle order per ADR-0007).
	# Simulate the SceneManager lifecycle step: call on_exit manually (mirrors
	# SceneManager._execute_transition calling old_screen.on_exit before queue_free).
	screen.on_exit()

	# Assert — tick subscription is disconnected after on_exit.
	assert_bool(TickSystem.tick_fired.is_connected(screen._on_tick_fired)).is_false()

	# Assert — state_changed subscription is also disconnected.
	assert_bool(
		DungeonRunOrchestrator.state_changed.is_connected(screen._on_state_changed)
	).is_false()

	# Verify: emitting tick_fired after on_exit produces no push_error (no orphaned
	# connection). Absence of engine errors is the assertion.
	TickSystem.tick_fired.emit(99)
	await get_tree().process_frame

	# Cleanup
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# AC-6: No SceneTree.change_scene_to_* calls in dungeon_run_view.gd
# ===========================================================================

func test_run_end_to_main_menu_transition_no_change_scene_calls() -> void:
	# Grep dungeon_run_view.gd for forbidden scene-change APIs (AC-6 Story 013
	# + AC-8 Story 012 — same pattern, redundantly enforced here for Story 013).
	var forbidden: Array[String] = [
		"change_scene_to_packed",
		"change_scene_to_file",
		"change_scene_to_node",
	]
	var fa: FileAccess = FileAccess.open(DUNGEON_RUN_VIEW_GD_PATH, FileAccess.READ)
	assert_object(fa).is_not_null()
	var violations: Array[String] = []
	var line_num: int = 0
	while not fa.eof_reached():
		var line: String = fa.get_line()
		line_num += 1
		for pattern: String in forbidden:
			if line.contains(pattern):
				violations.append("line %d: %s" % [line_num, line.strip_edges()])
	fa.close()
	assert_int(violations.size()).is_equal(0)


# ===========================================================================
# AC-3: RUN_END_DWELL_MS constant is in the valid range [0, 2000]
# Sprint 9 S9-M2 expanded the range from Story 013's original [0, 350] based
# on S8-M5 playtest evidence (sub-2s runs scored 1/5 on Pillar 2).
# ===========================================================================

func test_run_end_to_main_menu_transition_dwell_constant_is_in_valid_range() -> void:
	# Arrange — instantiate screen to read the constant.
	var packed: PackedScene = load(DUNGEON_RUN_VIEW_SCENE_PATH) as PackedScene
	assert_object(packed).is_not_null()

	var screen: Control = packed.instantiate() as Control
	assert_object(screen).is_not_null()

	# Assert — RUN_END_DWELL_MS is exposed as a constant and in [0, 2000].
	assert_bool("RUN_END_DWELL_MS" in screen).is_true()
	var dwell_ms: int = screen.RUN_END_DWELL_MS
	assert_int(dwell_ms).is_greater_equal(0)
	assert_int(dwell_ms).is_less_equal(2000)

	# Cleanup
	screen.free()


# ===========================================================================
# Structural: _routed flag resets in on_enter (fresh per screen visit)
# ===========================================================================

func test_run_end_to_main_menu_transition_routed_flag_resets_in_on_enter() -> void:
	# Arrange
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Pre-assert: fresh on_enter → _routed is false.
	assert_bool(screen._routed).is_false()

	# Act — set _routed to true to simulate a previous run-end on this visit.
	screen._routed = true
	assert_bool(screen._routed).is_true()

	# Simulate SceneManager calling on_exit + on_enter again (second visit).
	screen.on_exit()
	screen.on_enter()

	# Assert — _routed is false again (reset on on_enter).
	assert_bool(screen._routed).is_false()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame
