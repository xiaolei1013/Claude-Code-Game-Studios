## offline_batch_chunking_test.gd — S12-M5 Batch Chunking Comprehensive Integration Tests
##
## Covers OfflineProgressionEngine's full chunked replay loop per ADR-0014 §C.2 + GDD §C.2.
## Tests the loop structure, signal suppression, adaptive chunking, cap handling, and
## accumulation across Economy + Orchestrator domains.
##
## Signal pattern: connect lambda to capture summary, then pump process_frame in a loop
## until the signal fires OR a frame-count deadline is reached. This mirrors the canonical
## pattern from run_pacing_minimum_duration_test.gd and modal_overlay_counter_test.gd.
## gdunit4's assert_signal/wait_until does NOT pump the scene tree, so the implementation's
## `await get_tree().process_frame` per chunk would never resolve inside wait_until — the
## frame-pump approach is required.
##
## Autoloads under test (live singletons — no _make_wired_engine() needed):
##   OfflineProgressionEngine  /root/OfflineProgressionEngine
##   Economy                   /root/Economy
##   DungeonRunOrchestrator    /root/DungeonRunOrchestrator
##   TickSystem                /root/TickSystem

extends GdUnitTestSuite

# Maximum frames to pump while waiting for offline_rewards_collected.
# At INITIAL_TICKS=5000 and adaptive sizing, 3600s (72000 ticks) ≈ 15 chunks max;
# larger replays (28800s) ≈ 116 chunks. 300 frames provides generous headroom.
const _MAX_PUMP_FRAMES: int = 300

# Short frame limit for asserting signals that must NOT fire.
const _NO_EMIT_FRAMES: int = 5


# ---------------------------------------------------------------------------
# Hygiene barrier — reset live autoload state before and after every test.
# Mirrors the save_persist_roundtrip_test pattern: reset on entry AND exit.
# ---------------------------------------------------------------------------

func _restore_initial_state() -> void:
	## Reset Economy + Orchestrator offline-replay flags to clean state.
	var economy: Node = get_node_or_null("/root/Economy")
	var orchestrator: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if economy != null:
		economy._is_offline_replay = false
		economy._offline_pending_delta = 0
		if economy.has_method("_offline_pending_first_clears") or "_offline_pending_first_clears" in economy:
			economy._offline_pending_first_clears.clear()
	if orchestrator != null:
		orchestrator._is_offline_replay = false
		if "_offline_pending_first_clears" in orchestrator:
			orchestrator._offline_pending_first_clears.clear()
	# Reset engine in-flight guard (defensive; normally cleared by run_offline_replay itself).
	OfflineProgressionEngine._replay_in_flight = false
	OfflineProgressionEngine._pending_elapsed_seconds = 0


func before_test() -> void:
	_restore_initial_state()


func after_test() -> void:
	_restore_initial_state()


# ---------------------------------------------------------------------------
# Helper — pump frames until captured_summary[0] is populated or deadline hit.
# Returns true if the signal fired before the deadline.
# ---------------------------------------------------------------------------

func _pump_until_summary(captured_summary: Array, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		await get_tree().process_frame
		if captured_summary[0] != null:
			return true
	return false


# === Group A: Cold Launch + Zero Elapsed ===

func test_run_offline_replay_zero_elapsed_returns_silently() -> void:
	## AC-OE-01: elapsed=0 → no emit, no summary.
	# Arrange
	var rewards_spy: Array[int] = [0]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(_s: OfflineProgressionEngine.OfflineSummary) -> void: rewards_spy[0] += 1,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(0)

	# Assert — pump a few frames; signal must NOT fire
	for _i: int in range(_NO_EMIT_FRAMES):
		await get_tree().process_frame
	assert_int(rewards_spy[0]).is_equal(0)
	# Disconnect unused one-shot to avoid leaking into next test
	if OfflineProgressionEngine.offline_rewards_collected.is_connected(
		func(_s: OfflineProgressionEngine.OfflineSummary) -> void: rewards_spy[0] += 1
	):
		pass  # CONNECT_ONE_SHOT auto-disconnects; no manual cleanup needed


func test_run_offline_replay_negative_elapsed_returns_silently() -> void:
	## GDD §E.1: negative elapsed is treated as cold-start (no replay).
	# Arrange
	var rewards_spy: Array[int] = [0]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(_s: OfflineProgressionEngine.OfflineSummary) -> void: rewards_spy[0] += 1,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(-5)

	# Assert — pump a few frames; signal must NOT fire
	for _i: int in range(_NO_EMIT_FRAMES):
		await get_tree().process_frame
	assert_int(rewards_spy[0]).is_equal(0)


# === Group B: Single-Chunk Replay (Small Elapsed) ===

func test_run_offline_replay_small_elapsed_single_chunk() -> void:
	## Elapsed < INITIAL_TICKS (5000 ticks = 250 s): one chunk processes the entire batch.
	# Arrange — elapsed_ticks = 1000 ticks = 50 seconds
	var elapsed_seconds: int = 50  # 1000 ticks at 20 Hz — within OFFLINE_CHUNK_INITIAL_TICKS
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(elapsed_seconds)

	# Assert — pump frames until summary arrives
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_object(summary).is_not_null()
	assert_int(summary.chunks_consumed).is_equal(1)
	assert_int(summary.ticks_replayed).is_equal(elapsed_seconds * 20)


func test_run_offline_replay_short_window_surfaces_credited_gold() -> void:
	## A short replay still credits offline drip, and the summary must SURFACE the
	## gold the economy actually credited. Regression guard for the bug where
	## summary.gold_earned was left at 0 (the per-chunk economy result was discarded
	## behind a stale "returns null" comment) while add_gold quietly grew the
	## balance — so the Return-to-App screen reported "0 gold earned" falsely.
	# Arrange — 10 s = 200 ticks
	var economy: Node = get_tree().root.get_node_or_null("Economy")
	assert_object(economy).is_not_null()
	var lifetime_before: int = int(economy.get_lifetime_gold_earned())
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(10)

	# Assert
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_object(summary).is_not_null()
	# The summary's gold_earned must EQUAL the gold the economy actually credited
	# during the replay (its lifetime delta) — not a stale 0. Under the prior bug
	# this was 0 while `credited` was the real (non-zero) drip, so this fails RED.
	var credited: int = int(economy.get_lifetime_gold_earned()) - lifetime_before
	assert_int(summary.gold_earned).is_equal(credited)
	# (Kills/floors are now wired via DungeonRunOrchestrator.compute_offline_batch
	# and covered by end_to_end_offline_replay_test.gd — whether this short window
	# clears a floor depends on the live formation, so no floors assertion here.)


# === Group C: Multi-Chunk Loop (Large Elapsed) ===

func test_run_offline_replay_large_elapsed_multiple_chunks() -> void:
	## Elapsed > INITIAL_TICKS (5000 ticks): loop processes multiple chunks.
	## Use 600 s = 12000 ticks to guarantee multiple chunks (12000 / 5000 > 1).
	# Arrange — 600 s = 12000 ticks; at 5000 ticks/chunk → at least 2 chunks
	var elapsed_seconds: int = 600
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(elapsed_seconds)

	# Assert — pump frames until all chunks complete
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_object(summary).is_not_null()
	assert_int(summary.chunks_consumed).is_greater(1)
	assert_int(summary.ticks_replayed).is_equal(elapsed_seconds * 20)


func test_run_offline_replay_chunk_count_boundary_at_initial_size() -> void:
	## Exactly OFFLINE_CHUNK_INITIAL_TICKS (5000 ticks = 250 s): one chunk completes exactly.
	# Arrange — 250 s = 5000 ticks = exactly OFFLINE_CHUNK_INITIAL_TICKS
	var elapsed_seconds: int = 250
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(elapsed_seconds)

	# Assert
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_int(summary.chunks_consumed).is_equal(1)
	assert_int(summary.ticks_replayed).is_equal(5000)


# === Group D: Adaptive Chunk-Size Adjustment ===
# NOTE: Wall-time adaptive tests are skipped in headless mode — chunk execution is
# sub-millisecond, so chunk_wall_ms is always 0 ms (below deadband low 9 ms),
# which means adaptive adjustment always fires. These tests verify the loop
# completes without error, not the specific adjusted chunk size.

func test_adaptive_chunk_adjustment_loop_completes_without_error() -> void:
	## Adaptive chunk adjustment runs every chunk iteration without crashing.
	## Wall-time assertions are skipped (headless chunks are sub-ms; wall_ms = 0).
	# Arrange
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act — 50 s = 1000 ticks; fits in 1 chunk (< INITIAL_TICKS 5000)
	OfflineProgressionEngine.run_offline_replay(50)

	# Assert — completed successfully (chunk-size adaptation doesn't error)
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_int(summary.chunks_consumed).is_greater_equal(1)


func test_adaptive_chunk_adjustment_multi_chunk_completes_without_error() -> void:
	## Multi-chunk replay with adaptive sizing completes without error.
	## Verifies clamping to [MIN_TICKS, MAX_TICKS] doesn't break the loop.
	# Arrange — 1000 s = 20000 ticks; enough for multi-chunk with adaptive sizing
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(1000)

	# Assert — replay completed; ticks_replayed <= elapsed * 20 (cap may have been applied)
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_int(summary.ticks_replayed).is_less_equal(1000 * 20)
	assert_int(summary.chunks_consumed).is_greater(0)


# === Group E: Signal Suppression ===

func test_signal_suppression_economy_flag_cleared_post_replay() -> void:
	## During replay, Economy._is_offline_replay = true suppresses per-chunk gold_changed.
	## After replay completes, the flag must be cleared to false.
	# Arrange
	var economy: Node = get_node_or_null("/root/Economy")
	assert_object(economy).is_not_null()

	# Pre-replay: flag should be false.
	assert_bool(economy._is_offline_replay).is_false()

	# Act
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)
	OfflineProgressionEngine.run_offline_replay(50)
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()

	# Assert — post-replay flag cleared
	assert_bool(economy._is_offline_replay).is_false()


func test_signal_suppression_orchestrator_flag_cleared_post_replay() -> void:
	## During replay, Orchestrator._is_offline_replay = true suppresses per-chunk events.
	## After replay completes, the flag must be cleared to false.
	# Arrange
	var orchestrator: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	assert_object(orchestrator).is_not_null()
	assert_bool(orchestrator._is_offline_replay).is_false()

	# Act
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)
	OfflineProgressionEngine.run_offline_replay(50)
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()

	# Assert
	assert_bool(orchestrator._is_offline_replay).is_false()


func test_flush_offline_signals_method_exists_on_economy() -> void:
	## Economy.flush_offline_signals exists (AC per ADR-0013).
	## Post-replay flag state confirms flush was called (flush clears the flag per impl).
	# Arrange
	var economy: Node = get_node_or_null("/root/Economy")
	assert_object(economy).is_not_null()
	assert_bool(economy.has_method("flush_offline_signals")).is_true()

	# Act
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)
	OfflineProgressionEngine.run_offline_replay(50)
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()

	# Assert — flag cleared confirms flush was called
	assert_bool(economy._is_offline_replay).is_false()


# === Group F: Cap Clipping ===

func test_cap_clipping_elapsed_exceeds_cap() -> void:
	## Elapsed > cap → emit cap_reached, replay only capped portion.
	# Arrange — set cap to 1 hour via TickSystem.offline_cap_seconds DI
	var tick_system: Node = get_node_or_null("/root/TickSystem")
	var original_cap: int = 28800
	if tick_system != null and "offline_cap_seconds" in tick_system:
		original_cap = int(tick_system.get("offline_cap_seconds"))
		tick_system.offline_cap_seconds = 3600  # 1 hour cap

	var elapsed_seconds: int = 7200  # 2 hours → exceeds 1-hour cap
	var cap_spy: Array[int] = [0]
	var cap_clipped_spy: Array[int] = [0]
	OfflineProgressionEngine.cap_reached.connect(
		func(seconds_clipped: int) -> void:
			cap_spy[0] += 1
			cap_clipped_spy[0] = seconds_clipped,
		CONNECT_ONE_SHOT
	)
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(elapsed_seconds)

	# Assert — pump frames until the full replay completes
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()

	# cap_reached fired once with clipped = 7200 - 3600 = 3600
	assert_int(cap_spy[0]).is_equal(1)
	assert_int(cap_clipped_spy[0]).is_equal(3600)

	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_int(summary.seconds_credited).is_equal(3600)
	assert_int(summary.seconds_clipped).is_equal(3600)

	# Restore original cap
	if tick_system != null and "offline_cap_seconds" in tick_system:
		tick_system.offline_cap_seconds = original_cap


func test_cap_clipping_elapsed_under_cap() -> void:
	## Elapsed < cap → no cap_reached, full replay (seconds_clipped = 0).
	# Arrange — ensure cap is large enough (default 28800)
	var tick_system: Node = get_node_or_null("/root/TickSystem")
	var original_cap: int = 28800
	if tick_system != null and "offline_cap_seconds" in tick_system:
		original_cap = int(tick_system.get("offline_cap_seconds"))
		tick_system.offline_cap_seconds = 28800  # 8 hours default

	var elapsed_seconds: int = 1800  # 30 minutes — well under cap
	var cap_spy: Array[int] = [0]
	OfflineProgressionEngine.cap_reached.connect(
		func(_clipped: int) -> void: cap_spy[0] += 1,
		CONNECT_ONE_SHOT
	)
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(elapsed_seconds)

	# Assert — pump frames; cap_reached must NOT fire; offline_rewards_collected must fire
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	assert_int(cap_spy[0]).is_equal(0)

	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_int(summary.seconds_credited).is_equal(1800)
	assert_int(summary.seconds_clipped).is_equal(0)

	# Restore
	if tick_system != null and "offline_cap_seconds" in tick_system:
		tick_system.offline_cap_seconds = original_cap


# === Group G: Wall-Time Tracking ===

func test_total_replay_wall_time_ms_populated() -> void:
	## summary.total_replay_wall_time_ms is measured (>= 0 after replay).
	# Arrange
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(100)

	# Assert
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_int(summary.total_replay_wall_time_ms).is_greater_equal(0)


func test_wall_time_non_negative_for_large_elapsed() -> void:
	## Larger elapsed has a non-negative wall-time (field is populated).
	## NOTE: Does NOT assert strict > than small elapsed — headless chunks are
	## sub-ms; two replays may both measure 0 ms. The >= 0 contract is sufficient.
	# Arrange
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act — large elapsed
	OfflineProgressionEngine.run_offline_replay(500)
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]

	# Assert — field is populated and non-negative
	assert_int(summary.total_replay_wall_time_ms).is_greater_equal(0)


# === Group H: Accumulation ===

func test_ticks_replayed_accumulates_across_chunks() -> void:
	## summary.ticks_replayed = sum of all chunk ticks = elapsed_seconds * 20.
	# Arrange — 300 s = 6000 ticks → 2 chunks at 5000 initial (6000 > 5000)
	var elapsed_seconds: int = 300
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(elapsed_seconds)

	# Assert
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_int(summary.ticks_replayed).is_equal(6000)


func test_chunks_consumed_counts_chunk_iterations() -> void:
	## summary.chunks_consumed increments for each chunk processed.
	## 600 s = 12000 ticks → at least 2 chunks at INITIAL_TICKS (5000).
	# Arrange
	var elapsed_seconds: int = 600
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(elapsed_seconds)

	# Assert
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()
	var summary: OfflineProgressionEngine.OfflineSummary = captured_summary[0]
	assert_int(summary.chunks_consumed).is_greater(1)


# === Group I: Replay-In-Flight Guard ===

func test_replay_in_flight_guard_reentrant_call_rejected() -> void:
	## Calling run_offline_replay while one is in flight returns early with push_warn.
	## No offline_rewards_collected signal must fire for the rejected call.
	# Arrange — manually set in-flight flag to simulate mid-replay state
	OfflineProgressionEngine._replay_in_flight = true

	var rewards_spy: Array[int] = [0]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(_s: OfflineProgressionEngine.OfflineSummary) -> void: rewards_spy[0] += 1,
		CONNECT_ONE_SHOT
	)

	# Act — should be rejected
	OfflineProgressionEngine.run_offline_replay(100)

	# Assert — rejected call emits nothing after a few frames
	for _i: int in range(_NO_EMIT_FRAMES):
		await get_tree().process_frame
	assert_int(rewards_spy[0]).is_equal(0)

	# Cleanup — reset flag (after_test also resets, this is belt-and-suspenders)
	OfflineProgressionEngine._replay_in_flight = false


func test_replay_in_flight_flag_transitions_false_post_emit() -> void:
	## After offline_rewards_collected emits, _replay_in_flight = false.
	# Arrange — flag starts false
	assert_bool(OfflineProgressionEngine._replay_in_flight).is_false()

	var captured_flag_during_emit: Array[bool] = [true]  # starts true to prove it was set
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void:
			# Capture flag value AT emit time; per GDD §E.6 it must already be false
			captured_flag_during_emit[0] = OfflineProgressionEngine._replay_in_flight
			captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(50)
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()

	# Assert — flag was false at emit time (cleared BEFORE emit per line 297 impl)
	assert_bool(captured_flag_during_emit[0]).is_false()
	# And still false after
	assert_bool(OfflineProgressionEngine._replay_in_flight).is_false()


func test_exception_during_replay_flag_is_false_at_emission() -> void:
	## Contract: _replay_in_flight is set to false BEFORE offline_rewards_collected emits.
	## Per GDD §E.6: a listener exception must not leave _replay_in_flight stuck true.
	## Validates: impl clears flag first, then emits.
	# Arrange
	var flag_at_emission: Array[bool] = [true]  # sentinel: starts true
	var captured_summary: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void:
			flag_at_emission[0] = OfflineProgressionEngine._replay_in_flight
			# Simulate listener error via push_error (non-throwing in GDScript)
			push_error("test_exception_during_replay: intentional test error")
			captured_summary[0] = s,
		CONNECT_ONE_SHOT
	)

	# Act
	OfflineProgressionEngine.run_offline_replay(50)
	var fired: bool = await _pump_until_summary(captured_summary, _MAX_PUMP_FRAMES)
	assert_bool(fired).is_true()

	# Assert — flag was false at the moment the listener was invoked
	assert_bool(flag_at_emission[0]).is_false()
	assert_bool(OfflineProgressionEngine._replay_in_flight).is_false()
