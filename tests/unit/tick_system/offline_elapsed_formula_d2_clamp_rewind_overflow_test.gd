# Tests for Story 006 — Formula D.2 (offline elapsed + forward clamp + rewind
# tolerance + int64 overflow) and parts of Stories 005 + 007 that exercise the
# bootstrap_offline_replay entry point.
#
# Covers:
#   AC-TICK-02 (offline elapsed parameterized — drip math math)
#   AC-TICK-03 (cap enforcement at default 8h cap)
#   AC-TICK-06 (int64 forward-jump no overflow)
#   AC-TICK-07 / TR-time-030 (first-launch bootstrap seeds + emits zero)
#   AC-TICK-12 Part 2 (DST-backward flag — covered also in Story 007 file)
#   AC-TICK-13 / TR-time-016 (BG↔FG one-shot — bootstrap re-call is no-op)
#
# Test strategy:
#   bootstrap_offline_replay() reads the wall clock via _read_wall_clock_unix_time()
#   which calls Time.get_unix_time_from_system() — non-deterministic. To make
#   tests deterministic, we EITHER bypass bootstrap_offline_replay and call
#   _compute_offline_elapsed() directly with seeded _last_wall_ts, OR drive
#   bootstrap_offline_replay and accept the live wall clock for the first-launch
#   path (which only seeds + emits, doesn't compute deltas).
extends GdUnitTestSuite

const TickSystemScript = preload("res://src/core/tick_system/tick_system.gd")


# ---------------------------------------------------------------------------
# Helper — seed TickSystem state then invoke _compute_offline_elapsed directly.
# This bypasses bootstrap_offline_replay's wall-clock read so the test pins
# all 3 inputs (last_persist, session_high_water, t_current).
# ---------------------------------------------------------------------------
func _compute_with_seeded_state(
	last_persist: int, session_high_water: int, t_current: int
) -> Array:
	var ts: Node = TickSystemScript.new()
	var emissions: Array = []
	ts.offline_elapsed_seconds.connect(
		func(seconds: float, cap_reached: bool) -> void:
			emissions.append({"seconds": seconds, "cap_reached": cap_reached})
	)
	ts._last_persist_unix = last_persist
	ts._session_high_water = session_high_water
	ts._last_wall_ts = t_current  # bypass _read_wall_clock_unix_time
	ts._compute_offline_elapsed()
	ts.free()
	return emissions


# ---------------------------------------------------------------------------
# Test 1 — AC-TICK-02 parameterized: offline elapsed at 7 boundary points
# ---------------------------------------------------------------------------
func test_ac_tick_02_offline_elapsed_at_seven_boundary_points_match_clamp_formula() -> void:
	var t: int = 1_745_000_000
	var cap: int = 28_800  # default offline_cap_seconds
	var ticks_per_second: int = 20
	var deltas: Array[int] = [0, 1, 14_400, 28_800, 28_801, 86_400, 1_000_000]
	for d: int in deltas:
		# Arrange: anchor = T (last_persist == high_water == T); t_current = T+D
		var emissions: Array = _compute_with_seeded_state(t, t, t + d)

		# Assert
		assert_int(emissions.size()).is_equal(1)
		var entry: Dictionary = emissions[0]
		var expected_clamped: float = float(min(d, cap))
		var expected_cap_reached: bool = d > cap
		assert_float(entry["seconds"]).is_equal(expected_clamped)
		assert_bool(entry["cap_reached"]).is_equal(expected_cap_reached)
		# Tick budget per TR-time-026 multiply form: int(seconds * 20)
		var expected_budget: int = int(expected_clamped * float(ticks_per_second))
		# 28_800.0 * 20 = 576_000 exactly; 14_400.0 * 20 = 288_000 exactly.
		# These are well under 2^53 so no float-precision concerns.
		assert_int(int(entry["seconds"] * float(ticks_per_second))).is_equal(expected_budget)


# ---------------------------------------------------------------------------
# Test 2 — AC-TICK-03: cap enforcement at 10× cap
# ---------------------------------------------------------------------------
func test_ac_tick_03_cap_enforcement_at_ten_times_cap_clamps_to_cap_exact() -> void:
	# Arrange — 10× the 8h cap (288_000s)
	var t: int = 1_745_000_000
	var emissions: Array = _compute_with_seeded_state(t, t, t + 288_000)

	# Assert — clamped to 28_800.0 exact
	assert_int(emissions.size()).is_equal(1)
	assert_float(emissions[0]["seconds"]).is_equal(28_800.0)
	assert_bool(emissions[0]["cap_reached"]).is_true()
	# Budget = 28_800 × 20 = 576_000 exactly
	assert_int(int(emissions[0]["seconds"] * 20.0)).is_equal(576_000)


# ---------------------------------------------------------------------------
# Test 3 — AC-TICK-06: int64 forward-jump no overflow
#   D = 2^53 (well past the cap; guards the multiply against float widening)
# ---------------------------------------------------------------------------
func test_ac_tick_06_int64_forward_jump_clamps_without_overflow_or_inf() -> void:
	var t: int = 1_000_000
	var huge_t_current: int = (1 << 53) - 1  # mantissa-safe ceiling for float
	var emissions: Array = _compute_with_seeded_state(t, t, huge_t_current)

	# Assert — clamped to cap, no Inf, no negative
	assert_int(emissions.size()).is_equal(1)
	assert_float(emissions[0]["seconds"]).is_equal(28_800.0)
	assert_bool(emissions[0]["cap_reached"]).is_true()


# ---------------------------------------------------------------------------
# Test 4 — AC-TICK-12 Part 2 (DST-backward): clock rewind by 3600s flags suspicious
#   AND emits offline_elapsed_seconds(0.0, false). Detailed flag-emission
#   semantics live in suspicious_timestamp_flag_signal_emission_test.gd.
# ---------------------------------------------------------------------------
func test_ac_tick_12_dst_backward_3600s_flags_suspicious_and_emits_zero_elapsed() -> void:
	var t: int = 1_745_000_000
	var ts: Node = TickSystemScript.new()
	var elapsed_emissions: Array = []
	var flag_emissions: Array = []
	ts.offline_elapsed_seconds.connect(
		func(seconds: float, cap_reached: bool) -> void:
			elapsed_emissions.append({"seconds": seconds, "cap_reached": cap_reached})
	)
	ts.flag_suspicious_timestamp_emitted.connect(
		func(prev_ts: int, curr_ts: int) -> void:
			flag_emissions.append([prev_ts, curr_ts])
	)
	ts._last_persist_unix = t
	ts._session_high_water = t
	ts._last_wall_ts = t - 3600
	ts._compute_offline_elapsed()

	# Assert
	assert_int(elapsed_emissions.size()).is_equal(1)
	assert_float(elapsed_emissions[0]["seconds"]).is_equal(0.0)
	assert_bool(elapsed_emissions[0]["cap_reached"]).is_false()
	assert_int(flag_emissions.size()).is_equal(1)
	assert_bool(ts._flag_suspicious_timestamp).is_true()

	ts.free()


# ---------------------------------------------------------------------------
# Test 5 — boundary: rewind exactly at -REWIND_TOLERANCE_SECONDS is NOT flagged
#   (per AC-TICK-05 implicit contract; -300 = -300, NOT < -300).
# ---------------------------------------------------------------------------
func test_rewind_at_exactly_minus_tolerance_does_not_flag_or_branch_to_rewind() -> void:
	var t: int = 1_745_000_000
	var ts: Node = TickSystemScript.new()
	var flag_count: Array[int] = []
	ts.flag_suspicious_timestamp_emitted.connect(
		func(_a: int, _b: int) -> void:
			flag_count.append(1)
	)
	ts._last_persist_unix = t
	ts._session_high_water = t
	ts._last_wall_ts = t - 300  # exactly at tolerance, NOT past
	ts._compute_offline_elapsed()

	# Assert — not flagged; clamped to 0 via accept branch
	assert_int(flag_count.size()).is_equal(0)
	assert_bool(ts._flag_suspicious_timestamp).is_false()

	ts.free()


# ---------------------------------------------------------------------------
# Test 6 — TR-time-023: anchor is max(_last_persist_unix, _session_high_water)
#   AC-TICK-05b in spirit: high_water > last_persist due to mid-session rewind.
# ---------------------------------------------------------------------------
func test_anchor_uses_max_of_last_persist_and_session_high_water() -> void:
	var t: int = 1_745_000_000
	# Setup: heartbeat persist after 1h sets both to T+3600; attacker rewinds
	# clock during session so next persist writes _last_persist_unix=T+1800
	# but _session_high_water was max-preserved at T+3600. Cold-launch at
	# T+1800 reads anchor = max(T+1800, T+3600) = T+3600; elapsed_raw = -1800.
	var emissions: Array = _compute_with_seeded_state(t + 1800, t + 3600, t + 1800)

	# Assert — rewind branch fires (elapsed_raw == -1800 < -300 tolerance)
	assert_int(emissions.size()).is_equal(1)
	assert_float(emissions[0]["seconds"]).is_equal(0.0)


# ---------------------------------------------------------------------------
# Test 7 — Story 005 / TR-time-030 / AC-TICK-07: first-launch bootstrap seeds
#   timestamps and emits offline_elapsed_seconds(0.0, false).
#   Because bootstrap_offline_replay calls _read_wall_clock_unix_time() which
#   hits the OS clock, this test asserts post-conditions (timestamps == cached
#   wall ts) rather than absolute values.
# ---------------------------------------------------------------------------
func test_bootstrap_first_launch_seeds_timestamps_and_emits_zero() -> void:
	# Arrange — fresh instance, both timestamps zero (no save loaded)
	var ts: Node = TickSystemScript.new()
	var emissions: Array = []
	ts.offline_elapsed_seconds.connect(
		func(seconds: float, cap_reached: bool) -> void:
			emissions.append({"seconds": seconds, "cap_reached": cap_reached})
	)

	# Act
	ts.bootstrap_offline_replay()

	# Assert — emit happened with zeros; timestamps seeded equal to wall_ts
	assert_int(emissions.size()).is_equal(1)
	assert_float(emissions[0]["seconds"]).is_equal(0.0)
	assert_bool(emissions[0]["cap_reached"]).is_false()
	assert_int(ts._last_persist_unix).is_equal(ts._last_wall_ts)
	assert_int(ts._session_high_water).is_equal(ts._last_wall_ts)
	assert_bool(ts._offline_replay_emitted).is_true()

	ts.free()


# ---------------------------------------------------------------------------
# Test 8 — Story 005 / TR-time-016 / AC-TICK-13: bootstrap_offline_replay
#   is a process-scoped one-shot — second call is a no-op.
# ---------------------------------------------------------------------------
func test_bootstrap_second_call_is_noop_one_shot_per_process() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	var emissions: Array = []
	ts.offline_elapsed_seconds.connect(
		func(seconds: float, cap_reached: bool) -> void:
			emissions.append({"seconds": seconds, "cap_reached": cap_reached})
	)

	# Act — first call fires; second is no-op
	ts.bootstrap_offline_replay()
	ts.bootstrap_offline_replay()
	ts.bootstrap_offline_replay()

	# Assert — exactly one emission across three calls
	assert_int(emissions.size()).is_equal(1)

	ts.free()


# ---------------------------------------------------------------------------
# Test 9 — Story 005 returning-launch: bootstrap with non-zero timestamps
#   routes through _compute_offline_elapsed (Formula D.2). Wall-clock read is
#   live, so we just assert that exactly one emission fires (the math content
#   is covered by the seeded tests above).
# ---------------------------------------------------------------------------
func test_bootstrap_returning_launch_routes_through_formula_d2() -> void:
	# Arrange — simulate hydrated state from SaveLoadSystem
	var ts: Node = TickSystemScript.new()
	var t: int = int(Time.get_unix_time_from_system())
	# Persist 60s ago — within cap, accept branch
	ts._last_persist_unix = t - 60
	ts._session_high_water = t - 60
	var emissions: Array = []
	ts.offline_elapsed_seconds.connect(
		func(seconds: float, _cap_reached: bool) -> void:
			emissions.append(seconds)
	)

	# Act
	ts.bootstrap_offline_replay()

	# Assert — exactly one emit; seconds in [55, 65] tolerating wall-clock jitter
	assert_int(emissions.size()).is_equal(1)
	assert_float(emissions[0]).is_greater_equal(55.0)
	assert_float(emissions[0]).is_less_equal(65.0)

	ts.free()
