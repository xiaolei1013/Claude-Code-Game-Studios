# Tests for Story 007 — suspicious-timestamp flag, signal emission, and
# once-per-launch invariant.
#
# Covers:
#   AC-TICK-05 (rewind flag + signal + log on first detection)
#   AC-TICK-05b (in-session rewind via high-water max-preservation)
#   TR-time-018 (signal fires once per launch on false→true transition)
#   TR-time-019 (session-scoped flag resets to false on cold launch)
#   TR-time-036 (log format literal prefix)
#
# The flag-emission semantic is the load-bearing observable that distinguishes
# this story from Story 006: Story 006 implements the rewind branch's BRANCH
# (offline_elapsed_seconds = 0); Story 007 implements the SIGNAL + LOG +
# ONCE-PER-LAUNCH GUARD inside that branch.
extends GdUnitTestSuite

const TickSystemScript = preload("res://src/core/tick_system/tick_system.gd")


# ---------------------------------------------------------------------------
# Helper — build TickSystem instance with seeded state and capturing spies.
# ---------------------------------------------------------------------------
func _make_ts_with_spies(
	last_persist: int, session_high_water: int, t_current: int
) -> Dictionary:
	var ts: Node = TickSystemScript.new()
	ts._last_persist_unix = last_persist
	ts._session_high_water = session_high_water
	ts._last_wall_ts = t_current
	var flag_emissions: Array = []
	var elapsed_emissions: Array = []
	ts.flag_suspicious_timestamp_emitted.connect(
		func(prev_ts: int, curr_ts: int) -> void:
			flag_emissions.append([prev_ts, curr_ts])
	)
	ts.offline_elapsed_seconds.connect(
		func(seconds: float, cap_reached: bool) -> void:
			elapsed_emissions.append({"seconds": seconds, "cap_reached": cap_reached})
	)
	return {
		"ts": ts,
		"flag_emissions": flag_emissions,
		"elapsed_emissions": elapsed_emissions,
	}


# ---------------------------------------------------------------------------
# Test 1 — AC-TICK-05: first rewind detection sets flag + emits signal once
#   + emits offline_elapsed_seconds(0.0, false).
# ---------------------------------------------------------------------------
func test_ac_tick_05_first_rewind_detection_sets_flag_emits_signal_once() -> void:
	# Arrange — clock rewound by 1h, well past 300s tolerance
	var t: int = 1_745_000_000
	var bundle: Dictionary = _make_ts_with_spies(t, t, t - 3600)

	# Act
	(bundle["ts"] as Node)._compute_offline_elapsed()

	# Assert — flag set, signal emitted exactly once with (anchor, t_current)
	assert_bool((bundle["ts"] as Node)._flag_suspicious_timestamp).is_true()
	assert_int((bundle["flag_emissions"] as Array).size()).is_equal(1)
	var args: Array = (bundle["flag_emissions"] as Array)[0]
	assert_int(args[0]).is_equal(t)
	assert_int(args[1]).is_equal(t - 3600)
	# Rewind branch emits zero-elapsed
	assert_int((bundle["elapsed_emissions"] as Array).size()).is_equal(1)
	var elapsed: Dictionary = (bundle["elapsed_emissions"] as Array)[0]
	assert_float(elapsed["seconds"]).is_equal(0.0)
	assert_bool(elapsed["cap_reached"]).is_false()

	(bundle["ts"] as Node).free()


# ---------------------------------------------------------------------------
# Test 2 — TR-time-018 once-per-launch: subsequent rewind-branch hits do NOT
#   re-emit flag_suspicious_timestamp_emitted.
# ---------------------------------------------------------------------------
func test_tr_time_018_three_sequential_rewind_calls_emit_signal_only_once() -> void:
	# Arrange
	var t: int = 1_745_000_000
	var bundle: Dictionary = _make_ts_with_spies(t, t, t - 3600)

	# Act — three sequential calls, all into the rewind branch
	(bundle["ts"] as Node)._compute_offline_elapsed()
	(bundle["ts"] as Node)._compute_offline_elapsed()
	(bundle["ts"] as Node)._compute_offline_elapsed()

	# Assert — flag_suspicious_timestamp_emitted fires EXACTLY once
	assert_int((bundle["flag_emissions"] as Array).size()).is_equal(1)
	# Flag stays true across all three calls
	assert_bool((bundle["ts"] as Node)._flag_suspicious_timestamp).is_true()
	# offline_elapsed_seconds DOES emit on every call (each call is a fresh
	# computation; the suppression is on the flag signal, not on offline_elapsed)
	assert_int((bundle["elapsed_emissions"] as Array).size()).is_equal(3)

	(bundle["ts"] as Node).free()


# ---------------------------------------------------------------------------
# Test 3 — TR-time-018 the once-per-launch guard ALSO applies when t_current
#   is restored to a non-rewind value between calls. The flag stays true and
#   never re-emits even if a later call would re-enter the rewind branch.
# ---------------------------------------------------------------------------
func test_tr_time_018_flag_stays_true_after_restoration_no_second_emit() -> void:
	# Arrange
	var t: int = 1_745_000_000
	var bundle: Dictionary = _make_ts_with_spies(t, t, t - 3600)

	# Act 1 — rewind detected
	(bundle["ts"] as Node)._compute_offline_elapsed()
	# Act 2 — clock restored to forward (within cap)
	(bundle["ts"] as Node)._last_wall_ts = t + 60
	(bundle["ts"] as Node)._compute_offline_elapsed()
	# Act 3 — clock rewound again
	(bundle["ts"] as Node)._last_wall_ts = t - 7200
	(bundle["ts"] as Node)._compute_offline_elapsed()

	# Assert — signal emitted only once (at the FIRST detection)
	assert_int((bundle["flag_emissions"] as Array).size()).is_equal(1)
	assert_bool((bundle["ts"] as Node)._flag_suspicious_timestamp).is_true()

	(bundle["ts"] as Node).free()


# ---------------------------------------------------------------------------
# Test 4 — TR-time-019: session-scoped flag resets to false on cold launch.
#   New TickSystem instance starts with flag = false even if a prior instance
#   in the same process had it set to true.
# ---------------------------------------------------------------------------
func test_tr_time_019_fresh_instance_starts_with_flag_false_session_scoped() -> void:
	# Arrange — set flag in instance A, then create instance B
	var ts_a: Node = TickSystemScript.new()
	ts_a._flag_suspicious_timestamp = true
	ts_a.free()

	# Act — fresh instance B
	var ts_b: Node = TickSystemScript.new()

	# Assert — B's flag is false (NOT inherited from A or any global state)
	assert_bool(ts_b._flag_suspicious_timestamp).is_false()
	assert_bool(ts_b._offline_replay_emitted).is_false()

	ts_b.free()


# ---------------------------------------------------------------------------
# Test 5 — AC-TICK-05b: in-session rewind via session_high_water max-preservation.
#   Heartbeat after 1h sets both timestamps to T+3600; attacker rewinds clock;
#   next heartbeat overwrites _last_persist_unix=T+1800 BUT high_water
#   stays at T+3600 (max-preserved). Cold-launch at T+1800 reads anchor=T+3600;
#   elapsed_raw = -1800 < -300 → rewind branch.
# ---------------------------------------------------------------------------
func test_ac_tick_05b_in_session_rewind_via_high_water_triggers_rewind_branch() -> void:
	# Arrange
	var t: int = 1_745_000_000
	# After heartbeat write: _last_persist_unix = T+1800 (rewound), _high_water = T+3600 (max)
	# t_current at relaunch: T+1800
	var bundle: Dictionary = _make_ts_with_spies(t + 1800, t + 3600, t + 1800)

	# Act
	(bundle["ts"] as Node)._compute_offline_elapsed()

	# Assert — rewind branch fired with anchor = max(T+1800, T+3600) = T+3600
	assert_bool((bundle["ts"] as Node)._flag_suspicious_timestamp).is_true()
	assert_int((bundle["flag_emissions"] as Array).size()).is_equal(1)
	var args: Array = (bundle["flag_emissions"] as Array)[0]
	assert_int(args[0]).is_equal(t + 3600)  # anchor (high_water)
	assert_int(args[1]).is_equal(t + 1800)  # t_current
	# Zero elapsed
	assert_float(((bundle["elapsed_emissions"] as Array)[0] as Dictionary)["seconds"]).is_equal(0.0)

	(bundle["ts"] as Node).free()


# ---------------------------------------------------------------------------
# Test 6 — boundary: NTP-style small backward correction (within tolerance)
#   does NOT flag suspicious. -100s with default 300s tolerance → accept branch
#   clamps to 0; flag stays false.
# ---------------------------------------------------------------------------
func test_small_ntp_correction_within_tolerance_does_not_flag() -> void:
	# Arrange
	var t: int = 1_745_000_000
	var bundle: Dictionary = _make_ts_with_spies(t, t, t - 100)

	# Act
	(bundle["ts"] as Node)._compute_offline_elapsed()

	# Assert — accept branch (within tolerance), zero elapsed, flag stays false
	assert_bool((bundle["ts"] as Node)._flag_suspicious_timestamp).is_false()
	assert_int((bundle["flag_emissions"] as Array).size()).is_equal(0)
	# offline_elapsed clamps to 0 (clamp(elapsed_raw=-100, 0, cap) = 0)
	assert_float(((bundle["elapsed_emissions"] as Array)[0] as Dictionary)["seconds"]).is_equal(0.0)
	assert_bool(((bundle["elapsed_emissions"] as Array)[0] as Dictionary)["cap_reached"]).is_false()

	(bundle["ts"] as Node).free()


# ---------------------------------------------------------------------------
# Test 7 — TR-time-036 log format documented (push_warning interception is
#   not natively supported in this project's gdunit4 — see tests/PATTERNS.md
#   §1). The literal prefix `"[TickSystem] Clock rewind detected: delta="`
#   is enforced by code review of _compute_offline_elapsed; this test asserts
#   the BEHAVIORAL contract (signal + flag) which is the testable surface.
# ---------------------------------------------------------------------------
func test_tr_time_036_log_emission_path_runs_alongside_signal_advisory() -> void:
	# Arrange
	var t: int = 1_745_000_000
	var bundle: Dictionary = _make_ts_with_spies(t, t, t - 3600)

	# Act
	(bundle["ts"] as Node)._compute_offline_elapsed()

	# Assert — signal emission proves the rewind branch executed; the
	# push_warning() call on the same code path is verified by code review
	# of `_compute_offline_elapsed` line `push_warning("[TickSystem] Clock
	# rewind detected: delta=%d" % elapsed_raw)`.
	assert_int((bundle["flag_emissions"] as Array).size()).is_equal(1)

	(bundle["ts"] as Node).free()
