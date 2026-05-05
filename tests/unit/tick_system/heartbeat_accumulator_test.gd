# Sprint 11 S11-M2a (Story 011 — TickSystem side): heartbeat accumulator tests.
#
# Verifies:
#   - Heartbeat accumulator advances per _process delta.
#   - Heartbeat fires when accumulator reaches heartbeat_interval_seconds.
#   - Decrement (not reset) preserves sub-interval residual for exact average rate.
#   - Heartbeat advances even when UI is paused (TR-time-034 — closes the prior
#     TODO at scene_manager.gd line 196 about UI-pause heartbeat semantics).
#   - Heartbeat does NOT advance when app is backgrounded.
#   - Heartbeat call into SaveLoadSystem.request_heartbeat_persist is no-op-safe
#     when the autoload is absent (test env).
#
# Companion SaveLoadSystem.request_heartbeat_persist body lands in S11-M2b
# alongside Story 007. This suite tests TickSystem behavior in isolation.
extends GdUnitTestSuite

const TickSystemScript = preload("res://src/core/tick_system/tick_system.gd")


# ---------------------------------------------------------------------------
# Group A — accumulator advancement
# ---------------------------------------------------------------------------

func test_tick_system_heartbeat_accumulator_starts_at_zero() -> void:
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	assert_float(ts._heartbeat_accumulator_seconds).is_equal_approx(0.0, 1e-9)


func test_tick_system_heartbeat_accumulator_advances_per_process_delta() -> void:
	var ts: Node = TickSystemScript.new()
	auto_free(ts)

	# Act — advance by 5 seconds total in 100 process calls of 0.05s each.
	# heartbeat_interval is default 60s; should NOT fire yet.
	for _i: int in range(100):
		ts._process(0.05)

	# Assert — accumulator has advanced by ~5.0s; no firing yet.
	assert_float(ts._heartbeat_accumulator_seconds).is_equal_approx(5.0, 1e-6)


# ---------------------------------------------------------------------------
# Group B — firing semantics
# ---------------------------------------------------------------------------

func test_tick_system_heartbeat_fires_when_accumulator_reaches_interval() -> void:
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	# Use a 1-second interval to keep the test fast.
	ts.heartbeat_interval_seconds = 1

	# Act — advance exactly 1 second. Heartbeat should fire once.
	# (We can't directly observe the SaveLoadSystem call without a real
	# autoload; instead verify the accumulator was decremented from >=1.0 to
	# the residual, which only happens inside the firing branch.)
	for _i: int in range(20):  # 20 * 0.05s = 1.0s
		ts._process(0.05)

	# Assert — accumulator should be ~0.0 (decremented by 1.0s after firing).
	# If firing didn't happen, accumulator would still be ~1.0s.
	assert_float(ts._heartbeat_accumulator_seconds).is_between(-1e-6, 1e-6)


func test_tick_system_heartbeat_decrement_preserves_subinterval_residual() -> void:
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	ts.heartbeat_interval_seconds = 1

	# Act — advance 1.3 seconds total; heartbeat should fire once and leave
	# 0.3s residual on the accumulator (decrement, not reset).
	for _i: int in range(26):  # 26 * 0.05s = 1.3s
		ts._process(0.05)

	# Assert — residual ~0.3s.
	assert_float(ts._heartbeat_accumulator_seconds).is_equal_approx(0.3, 1e-5)


func test_tick_system_heartbeat_does_not_fire_below_interval() -> void:
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	ts.heartbeat_interval_seconds = 1

	# Act — advance only 0.95 seconds total; heartbeat should NOT fire.
	for _i: int in range(19):  # 19 * 0.05s = 0.95s
		ts._process(0.05)

	# Assert — accumulator at 0.95s (no firing decrement applied).
	assert_float(ts._heartbeat_accumulator_seconds).is_equal_approx(0.95, 1e-5)


# ---------------------------------------------------------------------------
# Group C — UI pause + background gating
# ---------------------------------------------------------------------------

func test_tick_system_heartbeat_advances_under_ui_pause() -> void:
	# TR-time-034 + Story 011: heartbeat must continue advancing under UI pause
	# (only tick emission is suppressed). This is the critical contract that
	# closes the prior TODO at tick_system.gd line 196 (pre-S11-M2a).
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	ts.set_ui_paused(true)

	# Act — advance 3 seconds while UI-paused.
	for _i: int in range(60):  # 60 * 0.05s = 3.0s
		ts._process(0.05)

	# Assert — heartbeat accumulator advanced (matches non-paused behavior).
	assert_float(ts._heartbeat_accumulator_seconds).is_equal_approx(3.0, 1e-5)
	# Assert — tick accumulator did NOT advance (UI pause suppresses tick path).
	assert_float(ts._tick_accumulator_seconds).is_equal_approx(0.0, 1e-9)
	# Assert — no tick emissions (current_tick still 0).
	assert_int(ts.current_tick()).is_equal(0)


func test_tick_system_heartbeat_does_not_advance_when_backgrounded() -> void:
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	# Force BG state via the internal field (matches existing test patterns
	# that bypass the platform notification).
	ts._app_state = TickSystemScript.AppState.BACKGROUNDED

	# Act — advance 5 seconds while BG.
	for _i: int in range(100):  # 100 * 0.05s = 5.0s
		ts._process(0.05)

	# Assert — accumulator did NOT advance (BG short-circuit).
	assert_float(ts._heartbeat_accumulator_seconds).is_equal_approx(0.0, 1e-9)


func test_tick_system_heartbeat_resumes_advancement_after_foreground() -> void:
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	ts._app_state = TickSystemScript.AppState.BACKGROUNDED

	# 2 seconds in BG — no advancement.
	for _i: int in range(40):
		ts._process(0.05)
	assert_float(ts._heartbeat_accumulator_seconds).is_equal_approx(0.0, 1e-9)

	# Foreground; 1 second of process — accumulator advances.
	ts._app_state = TickSystemScript.AppState.FOREGROUND
	for _i: int in range(20):
		ts._process(0.05)
	assert_float(ts._heartbeat_accumulator_seconds).is_equal_approx(1.0, 1e-5)


# ---------------------------------------------------------------------------
# Group D — _fire_heartbeat resilience
# ---------------------------------------------------------------------------

func test_tick_system_fire_heartbeat_does_not_crash_when_save_load_system_absent() -> void:
	# Test-env path: SaveLoadSystem autoload may not be at /root in pure unit
	# tests. _fire_heartbeat must early-return cleanly without crashing.
	# The TickSystem instance under test is fresh-instance (not the live
	# autoload) so it has no /root parent at all.
	var ts: Node = TickSystemScript.new()
	auto_free(ts)

	# Act — directly call _fire_heartbeat.
	ts._fire_heartbeat()

	# Assert — no crash; control flow reaches here.
	assert_bool(true).is_true()


func test_tick_system_heartbeat_does_not_advance_tick_counter() -> void:
	# Heartbeat firing must not interact with the tick counter.
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	ts.heartbeat_interval_seconds = 1

	# Run the heartbeat firing path multiple times.
	for _i: int in range(60):  # 3.0s — heartbeat fires 3 times
		ts._process(0.05)

	# Assert — tick counter advanced normally (60 calls of 0.05s = 3.0s total
	# = 60 ticks at 20 Hz). Heartbeat firing does not interfere.
	assert_int(ts.current_tick()).is_equal(60)


# ---------------------------------------------------------------------------
# Group E — interval tunability
# ---------------------------------------------------------------------------

func test_tick_system_heartbeat_interval_default_is_sixty_seconds() -> void:
	# Save/Load GDD §Tuning Knobs row: heartbeat_interval_seconds default 60.
	# Lock the default so a future tuning pass that violates this surfaces here.
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	assert_int(ts.heartbeat_interval_seconds).is_equal(60)


func test_tick_system_heartbeat_interval_is_configurable() -> void:
	# Save/Load GDD §Tuning Knobs row: range 15..300. Lock the @export
	# field's writeability without claiming the validator (no validator yet).
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	ts.heartbeat_interval_seconds = 30
	assert_int(ts.heartbeat_interval_seconds).is_equal(30)
	ts.heartbeat_interval_seconds = 120
	assert_int(ts.heartbeat_interval_seconds).is_equal(120)
