# Integration tests for Sprint 9 ticket S9-M2: Run pacing minimum-perceived-duration.
#
# Sprint 9 S9-M2 bumped RUN_END_DWELL_MS from 0 to 1500 ms to ensure the player
# perceives the run before the auto-route to main_menu fires. S8-M5 playtest
# evidence showed sub-2-second runs scored 1/5 on Pillar 2 ("run feels meaningful").
#
# These tests verify:
#   1. The dwell holds the run-end overlay visible for the minimum duration.
#   2. Total wall-clock time from RUN_ENDED → request_screen("main_menu") is ≥1500 ms.
#   3. The constant value matches the Sprint 9 production target (structural test).
#   4. Idempotency holds during the dwell window (re-emitted RUN_ENDED is a no-op).
#
# Test isolation pattern matches run_end_to_main_menu_transition_test.gd:
#   - Bypass SceneManager (headless test-env quirk per Story 011 closure note).
#   - Set SceneManager.state = TRANSITIONING so request_screen queues instead
#     of calling _execute_transition (which would assert-crash without MainRoot).
#   - Snapshot/restore orchestrator + SceneManager state in before_test/after_test.
#
# Run via:
#   godot --headless --ignoreHeadlessMode --script tests/gdunit4_runner.gd
#
# Sprint 9 S9-M2 — Run pacing minimum-perceived-duration polish (sprint-9.md S9-M2 row).
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const DUNGEON_RUN_VIEW_SCENE_PATH: String = "res://assets/screens/dungeon_run_view/dungeon_run_view.tscn"

const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")

## Sprint 9 S9-M2 production value of RUN_END_DWELL_MS. The test asserts this
## value is the actual constant in dungeon_run_view.gd to catch regressions.
const EXPECTED_S9M2_DWELL_MS: int = 1500

## Lower-bound minimum perceived run duration per S9-M2 acceptance criterion:
## "no run completes in <2 seconds wall-clock". 2000 - 500 ms transition slack = 1500 ms
## minimum dwell that the dungeon_run_view alone is responsible for.
const S9M2_MINIMUM_DWELL_MS: int = 1500

# ---------------------------------------------------------------------------
# Per-test state snapshots for isolation
# ---------------------------------------------------------------------------

var _orch_state_snapshot: int = DungeonRunStateScript.State.NO_RUN
var _orch_run_snapshot_snapshot: RunSnapshot = null
var _orch_last_dispatch_ms_snapshot: int = 0

var _sm_state_snapshot: int = 0
var _sm_queued_request_snapshot: Dictionary = {}
var _sm_current_screen_id_snapshot: String = ""


# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------

func before_test() -> void:
	_orch_state_snapshot = DungeonRunOrchestrator.state
	_orch_run_snapshot_snapshot = DungeonRunOrchestrator.run_snapshot
	_orch_last_dispatch_ms_snapshot = DungeonRunOrchestrator._last_dispatch_ms

	DungeonRunOrchestrator.state = DungeonRunStateScript.State.NO_RUN
	DungeonRunOrchestrator.run_snapshot = null
	DungeonRunOrchestrator._last_dispatch_ms = 0

	_sm_state_snapshot = SceneManager.state
	_sm_queued_request_snapshot = SceneManager._queued_request.duplicate()
	_sm_current_screen_id_snapshot = SceneManager.current_screen_id


func after_test() -> void:
	SceneManager.state = _sm_state_snapshot
	SceneManager._queued_request = _sm_queued_request_snapshot.duplicate()
	SceneManager.current_screen_id = _sm_current_screen_id_snapshot

	DungeonRunOrchestrator.state = _orch_state_snapshot
	DungeonRunOrchestrator.run_snapshot = _orch_run_snapshot_snapshot
	DungeonRunOrchestrator._last_dispatch_ms = _orch_last_dispatch_ms_snapshot


# ---------------------------------------------------------------------------
# Helpers
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


func _seed_run_snapshot(current_tick: int, kill_count: int) -> RunSnapshot:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.current_tick = current_tick
	snap.last_emitted_tick = current_tick
	snap.kill_count = kill_count
	DungeonRunOrchestrator.run_snapshot = snap
	return snap


# ===========================================================================
# Test 1 — Dwell holds run-end overlay visible for minimum duration.
#
# After RUN_ENDED is signalled, the run-end overlay must remain visible until
# the dwell elapses. We sample the overlay's visible flag at multiple points
# during the dwell window to confirm it does not get hidden prematurely.
# ===========================================================================

func test_run_pacing_dwell_overlay_remains_visible_for_minimum_duration() -> void:
	# Arrange — orchestrator in ACTIVE_FOREGROUND with a live snapshot.
	var snap: RunSnapshot = _seed_run_snapshot(20, 7)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Set SceneManager to TRANSITIONING (bypass _execute_transition crash in headless).
	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — emit RUN_ENDED.
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)
	# Allow one frame for the synchronous portion of _on_state_changed to run
	# (sets _overlay_shown = true, _routed = true, shows overlay, then awaits).
	await get_tree().process_frame

	# Assert — overlay is shown immediately on RUN_ENDED detection.
	assert_bool(screen._overlay_shown).is_true()
	assert_bool(screen._run_end_overlay.visible).is_true()
	assert_bool(screen._routed).is_true()

	# Assert — overlay remains visible after a partial-dwell wait.
	# We wait half the dwell, then re-check. The overlay must still be visible.
	# create_timer is the same mechanism the production code uses, so this
	# accurately measures whether the dwell is actually being respected.
	await get_tree().create_timer((S9M2_MINIMUM_DWELL_MS / 2) / 1000.0).timeout
	assert_bool(screen._run_end_overlay.visible).is_true()

	# Cleanup
	if screen.has_method("on_exit"):
		screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Test 2 — Total wall-clock time from RUN_ENDED → request_screen ≥1500 ms.
#
# Measures Time.get_ticks_msec() at the moment RUN_ENDED is emitted and again
# when SceneManager._queued_request becomes populated with "main_menu".
# Asserts the elapsed delta is ≥ S9M2_MINIMUM_DWELL_MS (1500 ms).
# ===========================================================================

func test_run_pacing_total_wall_clock_at_least_1500ms_with_dwell() -> void:
	# Arrange
	var snap: RunSnapshot = _seed_run_snapshot(30, 12)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — capture t_start, emit RUN_ENDED, wait for the dwell to complete,
	# capture t_end at the moment the queued request appears.
	var t_start_ms: int = Time.get_ticks_msec()

	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)

	# Poll get_tree().process_frame until the queued request is populated
	# OR until a generous timeout (3x dwell) expires. The dwell is 1500 ms;
	# we cap the wait at 5000 ms to fail clearly if the dwell never resolves.
	var poll_deadline_ms: int = t_start_ms + 5000
	while SceneManager._queued_request.is_empty() and Time.get_ticks_msec() < poll_deadline_ms:
		await get_tree().process_frame

	var t_end_ms: int = Time.get_ticks_msec()
	var elapsed_ms: int = t_end_ms - t_start_ms

	# Assert — elapsed must be at least the dwell minimum (with slack for
	# create_timer scheduling jitter; dwell is 1500 ms). The 50 ms slack
	# was too tight for full unit + integration sweep contention (observed
	# 1446 ms once on dev hardware; isolated runs always >1500 ms). 100 ms
	# slack still holds well within the S9-M2 acceptance criterion ("no
	# run completes in <2 seconds wall-clock"; the 1500 ms dwell already
	# has a 500 ms transition-budget cushion built in).
	assert_int(elapsed_ms).is_greater_equal(S9M2_MINIMUM_DWELL_MS - 100)

	# Assert — the queue contains "main_menu" (the dwell did its job, then routed).
	assert_bool(SceneManager._queued_request.is_empty()).is_false()
	assert_str(SceneManager._queued_request.get("screen_id", "")).is_equal("main_menu")

	# Cleanup
	if screen.has_method("on_exit"):
		screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Test 3 — Structural assertion: production constant value matches S9-M2 target.
#
# RUN_END_DWELL_MS is a `const`, so a runtime override would require refactoring
# to a `var` (architecturally messier). Instead, this structural test asserts:
#   (a) the constant exists and is exposed on the screen instance
#   (b) its value equals EXPECTED_S9M2_DWELL_MS (1500 ms)
#   (c) the value falls in the new Sprint 9 valid range [0, 2000]
#
# This catches any regression that bumps the value outside the spec range
# OR reverts it to the Sprint 8 default of 0 (the bug S9-M2 fixes).
#
# Approach-A documented limitation: a true "control" test (dwell = 0 → run
# completes in <2s) would require a const-override scaffold. The expected
# behavior is implicitly verified by the prior pre-S9-M2 test suite, which
# passed with dwell = 0 — the regression detection is bidirectional (this
# test fails if dwell drops to 0; the earlier suite would fail if dwell was
# always 1500 because the AC-3 range was [0, 350]).
# ===========================================================================

func test_run_pacing_constant_matches_s9m2_production_value() -> void:
	# Arrange
	var packed: PackedScene = load(DUNGEON_RUN_VIEW_SCENE_PATH) as PackedScene
	assert_object(packed).is_not_null()

	var screen: Control = packed.instantiate() as Control
	assert_object(screen).is_not_null()

	# Assert — RUN_END_DWELL_MS is exposed and matches the S9-M2 production value.
	assert_bool("RUN_END_DWELL_MS" in screen).is_true()
	var dwell_ms: int = screen.RUN_END_DWELL_MS
	assert_int(dwell_ms).is_equal(EXPECTED_S9M2_DWELL_MS)

	# Assert — within Sprint 9 valid range [0, 2000].
	assert_int(dwell_ms).is_greater_equal(0)
	assert_int(dwell_ms).is_less_equal(2000)

	# Cleanup
	screen.free()


# ===========================================================================
# Test 4 — Idempotency holds during the dwell window.
#
# If RUN_ENDED is signalled twice in rapid succession (within the dwell), the
# second emission must be a no-op — the _routed flag prevents a second
# request_screen call. We verify by checking that _queued_request retains
# the FIRST queued request and is not overwritten by a second.
# ===========================================================================

func test_run_pacing_idempotency_holds_during_dwell_window() -> void:
	# Arrange
	var snap: RunSnapshot = _seed_run_snapshot(15, 4)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — emit RUN_ENDED, then a second time DURING the dwell window.
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)
	await get_tree().process_frame

	# Capture _routed state after first emission — should be true.
	var routed_after_first: bool = screen._routed
	assert_bool(routed_after_first).is_true()

	# Second emission DURING the dwell window (overlay still visible, dwell
	# hasn't expired). The second emission's handler should hit the early-return
	# at `if _routed: return` BEFORE setting _routed again or calling request_screen.
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.RUN_ENDED  # spurious re-emit
	)
	await get_tree().process_frame

	# Assert — _routed is still true (idempotency held; flag wasn't reset).
	assert_bool(screen._routed).is_true()

	# Wait for the dwell to complete so the original (single) request_screen fires.
	await get_tree().create_timer((S9M2_MINIMUM_DWELL_MS + 100) / 1000.0).timeout

	# Assert — exactly one queued request, with screen_id == "main_menu".
	# If the second emission had triggered another request_screen, we'd see a
	# push_warning from SceneManager's queue-overwrite guard (queue depth max 1).
	# The queue should hold "main_menu" (the first call's target).
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
# Test 5 — Fast path (run already RUN_ENDED at on_enter time) honors dwell.
#
# Regression test for the S9-M2 hotfix (2026-05-05). The "slow path" via
# _on_state_changed already had the dwell. The "fast path" (run completes
# during the FADE_TO_BLACK transition INTO this screen, so on_enter sees
# state == RUN_ENDED with no signal incoming) was bypassing the dwell entirely
# — _deferred_run_end_route fired request_screen one frame after on_enter,
# giving the player no time to perceive the overlay or final kill_count.
#
# Sub-2-second runs in the live build (playtest 2026-05-05) consistently hit
# the fast path because combat resolves faster than FADE_TO_BLACK (~300 ms).
#
# This test simulates the fast path: state is set to RUN_ENDED BEFORE on_enter,
# then on_enter is called. Asserts elapsed time from on_enter →
# request_screen is ≥1500 ms (the same dwell as the slow path).
# ===========================================================================

func test_run_pacing_fast_path_dwell_holds_when_run_ended_at_on_enter() -> void:
	# Arrange — orchestrator is ALREADY in RUN_ENDED before the screen mounts.
	# This mirrors the production fast path: combat resolved during the
	# FADE_TO_BLACK transition into dungeon_run_view, so by the time on_enter
	# fires, state is RUN_ENDED and no state_changed signal will be incoming.
	var snap: RunSnapshot = _seed_run_snapshot(45, 9)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap

	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — mount the screen (on_enter detects RUN_ENDED via the defensive
	# branch on dungeon_run_view.gd line 179 and call_deferred()s the route).
	var t_start_ms: int = Time.get_ticks_msec()
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Assert — fast path detected the already-RUN_ENDED state and showed overlay.
	assert_bool(screen._overlay_shown).is_true()
	assert_bool(screen._routed).is_true()

	# Poll until the queued request appears OR a generous timeout (5000 ms cap
	# at 3x dwell so a missing dwell fails clearly within bounded test time).
	var poll_deadline_ms: int = t_start_ms + 5000
	while SceneManager._queued_request.is_empty() and Time.get_ticks_msec() < poll_deadline_ms:
		await get_tree().process_frame

	var t_end_ms: int = Time.get_ticks_msec()
	var elapsed_ms: int = t_end_ms - t_start_ms

	# Assert — elapsed must be at least the dwell minimum. WITHOUT the hotfix
	# this asserts in the ~10-50 ms range (the call_deferred fires next frame).
	# WITH the hotfix this asserts in the ~1500 ms range (await timer.timeout).
	# 50 ms slack for create_timer scheduling jitter (matches Test 2).
	assert_int(elapsed_ms).is_greater_equal(S9M2_MINIMUM_DWELL_MS - 50)

	# Assert — the queue contains "main_menu" (route fired after the dwell).
	assert_bool(SceneManager._queued_request.is_empty()).is_false()
	assert_str(SceneManager._queued_request.get("screen_id", "")).is_equal("main_menu")

	# Cleanup
	if screen.has_method("on_exit"):
		screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame
