# Sprint 12 S12-M4 (Stories 1-3) — OfflineProgressionEngine skeleton tests.
#
# Per design/gdd/offline-progression-engine.md §C.1: autoload skeleton +
# OfflineSummary class + signals + boot-time TickSystem subscription.
#
# Test groups:
#   A — public API surface lock (run_offline_replay + is_replay_in_flight
#       methods exist + OfflineSummary class accessible)
#   B — signal arity (offline_rewards_collected + cap_reached declarations)
#   C — OfflineSummary 7-field schema lock per GDD §C.1
#   D — Cap-clipping behavior (cap_reached fires only when elapsed > cap)
#   E — Single-replay-in-flight invariant (re-entrant calls push_warn + return)
#   F — Cold-launch / sub-second elapsed (no signal emission)
#   G — Autoload presence (post-S12-M4 registration)
#   H — TickSystem boot subscription (live wiring on /root/)
#
# DEFERRED to Sprint 12 S12-M5 (Stories 4-6 — chunked replay loop):
#   - Per-chunk Economy.compute_offline_batch + Orchestrator.compute_offline_batch
#     calls (current STUB skips these; summary is empty).
#   - Adaptive chunk-size adjustment per ADR-0014 §D.3.
#   - PROGRESS_MODAL_THRESHOLD_MS modal-show wiring.
#   - flush_offline_signals call ordering tests.
extends GdUnitTestSuite

const OPEScript = preload("res://src/core/offline_progression_engine/offline_progression_engine.gd")


func _make_engine() -> Node:
	var ope: Node = OPEScript.new()
	add_child(ope)
	auto_free(ope)
	return ope


# ===========================================================================
# Group A — public API surface lock
# ===========================================================================

func test_engine_has_run_offline_replay_method() -> void:
	var ope: Node = _make_engine()
	assert_bool(ope.has_method("run_offline_replay")).is_true()


func test_engine_has_is_replay_in_flight_method() -> void:
	var ope: Node = _make_engine()
	assert_bool(ope.has_method("is_replay_in_flight")).is_true()


func test_offline_summary_class_accessible_via_script() -> void:
	# OfflineSummary is an inner class declared on the engine script. Tests
	# instantiate via OPEScript.OfflineSummary.new() per the inner-class
	# access pattern.
	var summary = OPEScript.OfflineSummary.new()
	assert_object(summary).is_not_null()


# ===========================================================================
# Group B — signal arity + payload contract
# ===========================================================================

func test_engine_declares_offline_rewards_collected_signal() -> void:
	var ope: Node = _make_engine()
	assert_bool(ope.has_signal("offline_rewards_collected")).is_true()


func test_engine_declares_cap_reached_signal() -> void:
	var ope: Node = _make_engine()
	assert_bool(ope.has_signal("cap_reached")).is_true()


# ===========================================================================
# Group C — OfflineSummary 7-field schema lock per GDD §C.1
# ===========================================================================

func test_offline_summary_has_exactly_7_fields_per_adr_0014() -> void:
	# ADR-0014 forbidden pattern OFFLINE_SUMMARY_FIELD_SET_EXPANSION_WITHOUT_VERSION_BUMP:
	# adding a field requires a save-schema version bump. Lock the 7 fields
	# via direct property reads.
	var summary = OPEScript.OfflineSummary.new()
	assert_int(summary.gold_earned).is_equal(0)
	assert_int(summary.floors_cleared_in_window.size()).is_equal(0)
	assert_int(summary.seconds_credited).is_equal(0)
	assert_int(summary.seconds_clipped).is_equal(0)
	assert_int(summary.ticks_replayed).is_equal(0)
	assert_int(summary.chunks_consumed).is_equal(0)
	assert_int(summary.total_replay_wall_time_ms).is_equal(0)


# ===========================================================================
# Group D — Cap-clipping behavior
# ===========================================================================

var _cap_reached_calls: Array[int] = []
var _rewards_collected_calls: Array = []


func _on_cap_reached(seconds_clipped: int) -> void:
	_cap_reached_calls.append(seconds_clipped)


func _on_rewards_collected(summary) -> void:
	_rewards_collected_calls.append(summary)


func _connect_spies(ope: Node) -> void:
	_cap_reached_calls.clear()
	_rewards_collected_calls.clear()
	if not ope.cap_reached.is_connected(_on_cap_reached):
		ope.cap_reached.connect(_on_cap_reached)
	if not ope.offline_rewards_collected.is_connected(_on_rewards_collected):
		ope.offline_rewards_collected.connect(_on_rewards_collected)


func _disconnect_spies(ope: Node) -> void:
	if ope.cap_reached.is_connected(_on_cap_reached):
		ope.cap_reached.disconnect(_on_cap_reached)
	if ope.offline_rewards_collected.is_connected(_on_rewards_collected):
		ope.offline_rewards_collected.disconnect(_on_rewards_collected)


func test_run_offline_replay_under_cap_does_not_emit_cap_reached() -> void:
	# Non-live unit instance — _read_cap_seconds() falls back to GDD default
	# 28800 (8h) when TickSystem isn't visible to this instance via /root/.
	# elapsed=3600 (1h) is well under cap.
	# S12-M5: run_offline_replay now awaits process_frame per chunk; pump frames.
	var ope: Node = _make_engine()
	_connect_spies(ope)

	ope.run_offline_replay(3600)
	# Pump enough frames for the chunked loop to complete (3600s = 72000 ticks;
	# at INITIAL_TICKS 5000: ~15 chunks → 15 process_frame yields needed; 60 is safe headroom).
	for _i: int in range(60):
		await get_tree().process_frame
		if _rewards_collected_calls.size() > 0:
			break

	assert_int(_cap_reached_calls.size()).is_equal(0)
	assert_int(_rewards_collected_calls.size()).is_equal(1)
	# Summary fields per GDD §D.2: capped == elapsed; clipped == 0.
	var summary = _rewards_collected_calls[0]
	assert_int(summary.seconds_credited).is_equal(3600)
	assert_int(summary.seconds_clipped).is_equal(0)

	_disconnect_spies(ope)


func test_run_offline_replay_at_exactly_cap_does_not_emit_cap_reached() -> void:
	# GDD §E.3: elapsed == cap → strict > 0 check on clipped means no emit.
	# Live TickSystem is at /root; its offline_cap_seconds = 28800 default.
	# S12-M5: run_offline_replay now awaits process_frame per chunk; pump frames.
	var ope: Node = _make_engine()
	_connect_spies(ope)

	ope.run_offline_replay(28800)
	# 28800s = 576000 ticks; at INITIAL_TICKS 5000: ~116 chunks. Use 200-frame limit.
	for _i: int in range(200):
		await get_tree().process_frame
		if _rewards_collected_calls.size() > 0:
			break

	assert_int(_cap_reached_calls.size()).is_equal(0)
	assert_int(_rewards_collected_calls.size()).is_equal(1)
	var summary = _rewards_collected_calls[0]
	assert_int(summary.seconds_credited).is_equal(28800)
	assert_int(summary.seconds_clipped).is_equal(0)

	_disconnect_spies(ope)


func test_run_offline_replay_above_cap_emits_cap_reached_with_clipped_delta() -> void:
	# GDD §E.4: elapsed = 86400 (24h); cap = 28800 (8h); clipped = 57600.
	# S12-M5: run_offline_replay now awaits process_frame per chunk; pump frames.
	var ope: Node = _make_engine()
	_connect_spies(ope)

	ope.run_offline_replay(86400)
	# cap = 28800s = 576000 ticks; ~116 chunks. Use 200-frame limit.
	for _i: int in range(200):
		await get_tree().process_frame
		if _rewards_collected_calls.size() > 0:
			break

	assert_int(_cap_reached_calls.size()).is_equal(1)
	assert_int(_cap_reached_calls[0]).is_equal(57600)
	assert_int(_rewards_collected_calls.size()).is_equal(1)
	var summary = _rewards_collected_calls[0]
	assert_int(summary.seconds_credited).is_equal(28800)
	assert_int(summary.seconds_clipped).is_equal(57600)

	_disconnect_spies(ope)


# ===========================================================================
# Group E — Single-replay-in-flight invariant (ADR-0014)
# ===========================================================================

func test_re_entrant_run_offline_replay_is_dropped_with_warning() -> void:
	# Force _replay_in_flight true to simulate a mid-flight call.
	var ope: Node = _make_engine()
	_connect_spies(ope)
	ope._replay_in_flight = true

	ope.run_offline_replay(3600)

	# Re-entrant call was dropped — no signals emitted.
	assert_int(_cap_reached_calls.size()).is_equal(0)
	assert_int(_rewards_collected_calls.size()).is_equal(0)
	# In-flight flag NOT touched by the re-entrant attempt.
	assert_bool(ope._replay_in_flight).is_true()

	_disconnect_spies(ope)


func test_is_replay_in_flight_reflects_internal_state() -> void:
	var ope: Node = _make_engine()
	# Default false at construction.
	assert_bool(ope.is_replay_in_flight()).is_false()
	ope._replay_in_flight = true
	assert_bool(ope.is_replay_in_flight()).is_true()


# ===========================================================================
# Group F — Cold-launch / sub-second elapsed (no signal emission)
# ===========================================================================

func test_run_offline_replay_with_zero_elapsed_emits_nothing() -> void:
	# GDD §E.1 cold-launch: elapsed=0; no signals fire.
	var ope: Node = _make_engine()
	_connect_spies(ope)

	ope.run_offline_replay(0)

	assert_int(_cap_reached_calls.size()).is_equal(0)
	assert_int(_rewards_collected_calls.size()).is_equal(0)
	assert_bool(ope.is_replay_in_flight()).is_false()

	_disconnect_spies(ope)


func test_run_offline_replay_with_negative_elapsed_emits_nothing() -> void:
	# Defensive: negative elapsed (degenerate clock) treated as zero.
	var ope: Node = _make_engine()
	_connect_spies(ope)

	ope.run_offline_replay(-100)

	assert_int(_cap_reached_calls.size()).is_equal(0)
	assert_int(_rewards_collected_calls.size()).is_equal(0)

	_disconnect_spies(ope)


# ===========================================================================
# Group G — Autoload presence (post-S12-M4 registration)
# ===========================================================================

func test_engine_is_live_autoload_at_canonical_path() -> void:
	# Locks the project.godot autoload registration at rank 15 (per ADR-0003
	# Amendment #8). Sits between DungeonRunOrchestrator (rank 14) and
	# AudioRouter (rank 16).
	var ope: Node = get_tree().root.get_node_or_null("OfflineProgressionEngine")
	assert_object(ope).is_not_null()
	assert_bool(ope.has_method("run_offline_replay")).is_true()
	assert_bool(ope.has_signal("offline_rewards_collected")).is_true()
	assert_bool(ope.has_signal("cap_reached")).is_true()


func test_engine_not_in_consumer_paths_per_gdd_c7() -> void:
	# Per GDD §C.7: NOT in CONSUMER_PATHS. The engine has no persisted state
	# of its own. This test locks that contract — adding /root/OfflineProgressionEngine
	# to CONSUMER_PATHS is forbidden without a GDD §C.7 update.
	var SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")
	for path: String in SaveLoadScript.CONSUMER_PATHS:
		assert_str(path).is_not_equal("/root/OfflineProgressionEngine")


# ===========================================================================
# Group H — TickSystem boot subscription (live wiring)
# ===========================================================================

func test_engine_subscribed_to_tick_system_offline_elapsed_signal() -> void:
	# Locks the GDD §F.signal-source-dependencies wiring: rank 15 → rank 0
	# subscribe at _ready(). Per ADR-0003 Amendment #1 forward-subscription
	# rule, this is safe.
	var tick_system: Node = get_tree().root.get_node_or_null("TickSystem")
	var ope: Node = get_tree().root.get_node_or_null("OfflineProgressionEngine")
	assert_object(tick_system).is_not_null()
	assert_object(ope).is_not_null()
	assert_bool(tick_system.offline_elapsed_seconds.is_connected(ope._on_offline_elapsed_seconds)).is_true()
