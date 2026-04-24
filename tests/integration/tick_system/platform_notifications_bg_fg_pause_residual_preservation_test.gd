# Tests for Story S1-N2: Platform notifications, BG/FG lifecycle, UI-pause substate,
# and accumulator-residual preservation across pause transitions.
# Covers: AC-TICK-04, TR-time-008, TR-time-009, TR-time-010, TR-time-015, TR-time-034
extends GdUnitTestSuite

const TickSystemScript = preload("res://src/core/tick_system/tick_system.gd")


# ---------------------------------------------------------------------------
# Test 1 — AC-TICK-04: BG notification halts tick emission; persist timestamps written
#
# Verifies that NOTIFICATION_WM_WINDOW_FOCUS_OUT (desktop BG) transitions
# _app_state to BACKGROUNDED, stops all subsequent tick_fired emissions, and
# writes both _last_persist_unix (wall-clock snapshot) and _session_high_water
# (monotonic max) to non-zero values.
# ---------------------------------------------------------------------------
func test_tick_emission_halts_on_bg_notification_and_last_persist_is_set() -> void:
	# Arrange — capture emissions via lambda-connected signal
	var ts: Node = TickSystemScript.new()
	var captured: Array[int] = []
	ts.tick_fired.connect(func(n: int) -> void: captured.append(n))

	# Act — drive 10 FG frames to establish a baseline of 10 ticks
	for _i: int in range(10):
		ts._process(0.05)

	assert_int(captured.size()).is_equal(10)

	# Act — trigger desktop BG notification then attempt one more _process call
	ts._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	ts._process(0.05)

	# Assert — no new emission occurred during or after the BG trigger
	assert_int(captured.size()).is_equal(10)

	# Assert — app state transitioned to BACKGROUNDED
	assert_bool(ts._app_state == TickSystemScript.AppState.BACKGROUNDED).is_true()

	# Assert — wall-clock persist timestamp was written (non-zero = real clock read)
	assert_bool(ts._last_persist_unix > 0).is_true()

	# Assert — session high-water is at least as large as the persist timestamp
	assert_bool(ts._session_high_water >= ts._last_persist_unix).is_true()

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 2 — AC-TICK-04 residual: Sub-threshold accumulator residual survives
# a full BG→FG round-trip without corruption and resumes ticking correctly.
#
# Verifies TR-time-009 and TR-time-010: the accumulator is frozen (not reset)
# on BG entry and resumes advancing from the preserved value on FG return.
# ---------------------------------------------------------------------------
func test_accumulator_residual_preserved_across_pause_exactly() -> void:
	# Arrange — sub-threshold feed produces a residual of 0.03 s, no tick yet
	var ts: Node = TickSystemScript.new()
	var captured: Array[int] = []
	ts.tick_fired.connect(func(n: int) -> void: captured.append(n))

	ts._process(0.03)

	const EPSILON: float = 1e-9
	assert_int(captured.size()).is_equal(0)
	assert_float(ts._tick_accumulator_seconds).is_between(
		0.03 - EPSILON,
		0.03 + EPSILON
	)

	# Act — background the app (desktop path)
	ts._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)

	# Assert — accumulator residual is unchanged after entering BG
	assert_float(ts._tick_accumulator_seconds).is_between(
		0.03 - EPSILON,
		0.03 + EPSILON
	)

	# Act — simulate 10 "BG frames" by NOT calling _process (engine would pause it)

	# Act — resume to foreground
	ts._notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)

	# Assert — accumulator residual still preserved after FG return (TR-time-010)
	assert_float(ts._tick_accumulator_seconds).is_between(
		0.03 - EPSILON,
		0.03 + EPSILON
	)

	# Act — feed 0.02 s (residual 0.03 + 0.02 = 0.05 — exactly crosses threshold)
	ts._process(0.02)

	# Assert — exactly ONE tick fired since the test began
	assert_int(captured.size()).is_equal(1)

	# Assert — post-tick residual is 0.0 (0.05 − 0.05)
	assert_float(ts._tick_accumulator_seconds).is_between(
		0.0 - EPSILON,
		0.0 + EPSILON
	)

	# Act — feed 0.01 s more (sub-threshold); must not produce a new emission
	ts._process(0.01)

	# Assert — still exactly 1 total emission; residual == 0.01
	assert_int(captured.size()).is_equal(1)
	assert_float(ts._tick_accumulator_seconds).is_between(
		0.01 - EPSILON,
		0.01 + EPSILON
	)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 3 — AC-TICK-04 no-ticks-during-bg: 100 FG + BG window + 100 FG
# produces exactly 200 total tick_fired emissions and none during the BG window.
#
# This test validates the "no zero-tick burst" invariant: the BG period is
# modelled by the engine not calling _process; when we return to FG and resume
# normal _process calls the count increases linearly from where it left off.
# ---------------------------------------------------------------------------
func test_no_ticks_emitted_during_bg_window() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	var captured: Array[int] = []
	ts.tick_fired.connect(func(n: int) -> void: captured.append(n))

	# Act — 100 FG frames; expect 100 ticks
	for _i: int in range(100):
		ts._process(0.05)

	assert_int(captured.size()).is_equal(100)

	# Act — enter background (desktop path)
	ts._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)

	# Assert — BG transition does not itself emit anything; count unchanged
	assert_int(captured.size()).is_equal(100)

	# Act — BG window: no _process calls are made (engine pauses node processing)

	# Act — return to foreground
	ts._notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)

	# Assert — FG return does not itself emit anything; count still 100
	assert_int(captured.size()).is_equal(100)

	# Act — 100 more FG frames
	for _i: int in range(100):
		ts._process(0.05)

	# Assert — total ticks == 200 (second batch adds exactly 100 more)
	assert_int(captured.size()).is_equal(200)

	# Assert — tick numbers are contiguous across the BG boundary (no gap or repeat)
	assert_int(captured[99]).is_equal(100)
	assert_int(captured[100]).is_equal(101)
	assert_int(captured[199]).is_equal(200)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 4 — TR-time-015: Mobile NOTIFICATION_APPLICATION_PAUSED code path
# behaves identically to the desktop FOCUS_OUT path, and calling it twice
# is idempotent (second call must not overwrite _last_persist_unix).
#
# The idempotent assert proves _on_backgrounded() returns early on a
# repeated call without reading the wall clock a second time, so
# _last_persist_unix does not change between the first and second call.
# ---------------------------------------------------------------------------
func test_mobile_notification_pauses_emission() -> void:
	# Arrange — warm up the tick engine first
	var ts: Node = TickSystemScript.new()
	var captured: Array[int] = []
	ts.tick_fired.connect(func(n: int) -> void: captured.append(n))

	for _i: int in range(5):
		ts._process(0.05)

	assert_int(captured.size()).is_equal(5)

	# Act — trigger mobile BG notification
	ts._notification(NOTIFICATION_APPLICATION_PAUSED)

	# Act — attempt a _process call after the mobile pause; must emit nothing
	ts._process(0.05)

	# Assert — no emission after mobile BG notification
	assert_int(captured.size()).is_equal(5)

	# Assert — app state is BACKGROUNDED
	assert_bool(ts._app_state == TickSystemScript.AppState.BACKGROUNDED).is_true()

	# Assert — persist timestamp was written by the first PAUSED notification
	var persist_ts_after_first_pause: int = ts._last_persist_unix
	assert_bool(persist_ts_after_first_pause > 0).is_true()

	# Act — call NOTIFICATION_APPLICATION_PAUSED a second time (idempotent edge case)
	ts._notification(NOTIFICATION_APPLICATION_PAUSED)

	# Assert — still BACKGROUNDED, no state change, no error
	assert_bool(ts._app_state == TickSystemScript.AppState.BACKGROUNDED).is_true()

	# Assert — _last_persist_unix was NOT overwritten on the second call
	# (idempotent: _on_backgrounded returned early without reading the wall clock again)
	assert_int(ts._last_persist_unix).is_equal(persist_ts_after_first_pause)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 5 — TR-time-034: UI pause suppresses tick emission while keeping
# _app_state as FOREGROUND (not BACKGROUNDED), and the accumulator residual
# accumulated during the UI-paused period is zero (early-return before
# accumulator advancement).
#
# On unpause the tick stream resumes from the preserved accumulator residual
# and produces the correct number of new ticks.
# ---------------------------------------------------------------------------
func test_ui_paused_suppresses_ticks_without_entering_background() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	var captured: Array[int] = []
	ts.tick_fired.connect(func(n: int) -> void: captured.append(n))

	# Act — UI pause active; drive 10 _process calls
	ts.set_ui_paused(true)
	for _i: int in range(10):
		ts._process(0.05)

	# Assert — zero emissions while UI-paused
	assert_int(captured.size()).is_equal(0)

	# Assert — app_state remains FOREGROUND (UI pause is NOT a lifecycle BG event)
	assert_bool(ts._app_state == TickSystemScript.AppState.FOREGROUND).is_true()

	# Assert — accumulator residual is zero because _process returns before
	# advancing the accumulator on every UI-paused frame (TR-time-010)
	const EPSILON: float = 1e-9
	assert_float(ts._tick_accumulator_seconds).is_between(0.0 - EPSILON, 0.0 + EPSILON)

	# Act — resume tick emission
	ts.set_ui_paused(false)
	for _i: int in range(10):
		ts._process(0.05)

	# Assert — exactly 10 new emissions after unpause (clean accumulator = 1 tick/call)
	assert_int(captured.size()).is_equal(10)

	# Assert — tick numbers are sequential from 1..10 (no pre-pause ticks exist)
	assert_int(captured[0]).is_equal(1)
	assert_int(captured[9]).is_equal(10)

	# Cleanup
	ts.free()
