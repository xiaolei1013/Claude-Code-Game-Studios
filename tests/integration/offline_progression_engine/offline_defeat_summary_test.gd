## Tests for GDD #34 Phase 5 (Defeat & Injury System / ADR-0021) — the ENGINE-side
## wiring in OfflineProgressionEngine.run_offline_replay that:
##   (L2a) records the offline window's START instant on the orchestrator BEFORE the
##         chunk loop, so a DEFEATED offline run anchors its injury-recovery clock
##         there (Model B, §E.3/§E.5) rather than at resume. window_start uses the
##         TRUE UNCAPPED elapsed (the absence length), not the reward-capped value.
##   (L2b) stamps the floor the formation was driven back at onto the summary via the
##         "_defeated_at_floor" META key (NOT a field — ADR-0014 forbids OfflineSummary
##         field expansion; meta is the sanctioned escape hatch, like _kills_by_tier),
##         so the Return-to-App screen can render the "driven back at Floor X" notice
##         (L3 / AC-34-10). A WINNING window stamps nothing.
##
## Test pattern: live autoloads at /root/{OfflineProgressionEngine, Economy,
## DungeonRunOrchestrator, TickSystem, HeroRoster}, driven exactly like
## end_to_end_offline_replay_test.gd (seed a real formation hero, inject offline
## inputs, pump frames until offline_rewards_collected fires). A DEFEAT is forced by
## injecting a defeat spy resolver into the live orchestrator (compute_run_outcome →
## won=false), mirroring offline_defeat_injury_test.gd. The live HeroRoster is
## snapshot+restored (memory: feedback_test_isolation_live_autoload) because a forced
## offline defeat injures the dispatched formation.
extends GdUnitTestSuite

const CombatBatchResultScript = preload("res://src/core/combat/combat_batch_result.gd")
const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")

const _PIPELINE_TIMEOUT_FRAMES: int = 600  # ~10s at 60fps process_frame cadence

# A fixed, large, production-realistic wall-clock (Unix seconds ≈ 2033). Seeded into
# TickSystem so now_ms() is deterministic for the window-start arithmetic; see
# offline_defeat_injury_test.gd for the rationale (the bare clock would be 0).
const _FIXED_NOW_S: int = 2_000_000_000


# Spy resolver: returns kills proportional to the window (mirrors the L1 harness).
class _SpyResolver extends RefCounted:
	func compute_offline_batch(_snapshot: Variant, tick_budget: int) -> RefCounted:
		var r: RefCounted = CombatBatchResultScript.new()
		r.kills_by_tier = {1: int(tick_budget / 100)}
		r.loops_completed = int(tick_budget / 300)
		r.first_clear_tick = -1
		return r


# Minimal verdict stand-in: the offline verdict path reads only `.won`.
class _DefeatOutcome extends RefCounted:
	var won: bool = false
	var clear_tick: int = -1
	var defeat_tick: int = 5


# Spy resolver reporting DEFEAT (compute_run_outcome → won=false).
class _DefeatSpyResolver extends _SpyResolver:
	func compute_run_outcome(_snapshot: Variant) -> RefCounted:
		return _DefeatOutcome.new()


var _roster_snapshot: Dictionary = {}
var _wall_ts_snapshot: int = 0
var _orig_resolver: RefCounted = null


func _restore_initial_state() -> void:
	var economy: Node = get_node_or_null("/root/Economy")
	var orchestrator: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if economy != null:
		economy._is_offline_replay = false
		economy._offline_pending_delta = 0
		if "_offline_pending_first_clears" in economy:
			economy._offline_pending_first_clears.clear()
	if orchestrator != null:
		orchestrator._is_offline_replay = false
		if "_offline_pending_first_clears" in orchestrator:
			orchestrator._offline_pending_first_clears.clear()
		orchestrator.set_offline_replay_inputs([], 0, "")
		orchestrator.run_snapshot = null
	OfflineProgressionEngine._replay_in_flight = false
	OfflineProgressionEngine._pending_elapsed_seconds = 0
	OfflineProgressionEngine._last_summary = null


func before_test() -> void:
	_restore_initial_state()
	_roster_snapshot = HeroRosterFixture.snapshot_via_save_data()
	HeroRosterFixture.reset_hero_roster()
	_wall_ts_snapshot = TickSystem._last_wall_ts
	# Preserve the live orchestrator resolver so a defeat-spy injection is reversible.
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	_orig_resolver = orch._combat_resolver if orch != null else null


func after_test() -> void:
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if orch != null:
		orch.set_combat_resolver(_orig_resolver)
	HeroRosterFixture.restore_via_load_save_data(_roster_snapshot)
	TickSystem._last_wall_ts = _wall_ts_snapshot
	_restore_initial_state()


func _pump_until_summary(captured_summary: Array, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		await get_tree().process_frame
		if captured_summary[0] != null:
			return true
	return false


# ===========================================================================
# Group A: defeated offline window stamps the "_defeated_at_floor" meta
# ===========================================================================

func test_offline_defeat_stamps_defeated_at_floor_meta() -> void:
	# A forced offline DEFEAT must stamp the floor the formation was driven back at
	# onto the summary meta, so the Return-to-App screen (L3) can surface the notice.
	var roster: Node = get_node_or_null("/root/HeroRoster")
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	assert_object(roster).is_not_null()
	assert_object(orch).is_not_null()

	var inst: RefCounted = roster.add_hero("warrior")
	if inst == null:
		push_warning("Skipped: HeroRoster.add_hero('warrior') returned null (DataRegistry).")
		return

	# Force DEFEAT on floor 2 (a non-default floor so the stamped value proves
	# fidelity, not a hardcoded 1).
	orch.set_combat_resolver(_DefeatSpyResolver.new())
	orch.run_snapshot = null
	orch.set_offline_replay_inputs([inst], 2, "forest_reach")

	var captured: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured[0] = s,
		CONNECT_ONE_SHOT
	)

	OfflineProgressionEngine.run_offline_replay(600)
	var fired: bool = await _pump_until_summary(captured, _PIPELINE_TIMEOUT_FRAMES)
	assert_bool(fired).is_true()

	var summary: OfflineProgressionEngine.OfflineSummary = captured[0]
	assert_object(summary).is_not_null()
	assert_bool(summary.has_meta("_defeated_at_floor")).override_failure_message(
		"a defeated offline window must stamp the _defeated_at_floor summary meta (AC-34-10)"
	).is_true()
	var defeated_floor: Variant = summary.get_meta("_defeated_at_floor", 0)
	assert_int(defeated_floor).override_failure_message(
		"the stamped floor must be the floor the formation was driven back at (2)"
	).is_equal(2)


func test_offline_win_sets_no_defeated_at_floor_meta() -> void:
	# Control: a WINNING offline window (live default resolver clears floor 1) must
	# NOT stamp the defeat meta — the screen then keeps its defeat notice hidden.
	var roster: Node = get_node_or_null("/root/HeroRoster")
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	assert_object(roster).is_not_null()
	assert_object(orch).is_not_null()

	var inst: RefCounted = roster.add_hero("warrior")
	if inst == null:
		push_warning("Skipped: HeroRoster.add_hero('warrior') returned null (DataRegistry).")
		return

	# No resolver injection → the live DefaultCombatResolver wins floor 1.
	orch.run_snapshot = null
	orch.set_offline_replay_inputs([inst], 1, "forest_reach")

	var captured: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured[0] = s,
		CONNECT_ONE_SHOT
	)

	OfflineProgressionEngine.run_offline_replay(600)
	var fired: bool = await _pump_until_summary(captured, _PIPELINE_TIMEOUT_FRAMES)
	assert_bool(fired).is_true()

	var summary: OfflineProgressionEngine.OfflineSummary = captured[0]
	assert_object(summary).is_not_null()
	assert_bool(summary.has_meta("_defeated_at_floor")).override_failure_message(
		"a winning offline window must NOT stamp the _defeated_at_floor meta"
	).is_false()


# ===========================================================================
# Group B: the engine records the window START on the orchestrator
# ===========================================================================

func test_engine_sets_window_start_to_now_minus_elapsed() -> void:
	# The engine must record window_start = now_ms() - elapsed*1000 on the
	# orchestrator BEFORE the chunk loop, so the offline-defeat injury (L1) anchors
	# recovery at the window start. now_ms() is read synchronously before the first
	# await, so the seeded clock holds for the arithmetic.
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	assert_object(orch).is_not_null()

	TickSystem._last_wall_ts = _FIXED_NOW_S
	var now_ms: int = TickSystem.now_ms()
	var elapsed_seconds: int = 600

	var captured: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured[0] = s,
		CONNECT_ONE_SHOT
	)

	OfflineProgressionEngine.run_offline_replay(elapsed_seconds)
	var fired: bool = await _pump_until_summary(captured, _PIPELINE_TIMEOUT_FRAMES)
	assert_bool(fired).is_true()

	assert_int(orch._offline_window_start_ms).override_failure_message(
		"engine must set orchestrator window_start = now_ms() - elapsed*1000"
	).is_equal(now_ms - elapsed_seconds * 1000)


func test_engine_window_start_uses_uncapped_elapsed() -> void:
	# The window start anchors at the TRUE absence length, NOT the reward-capped
	# value: recovery elapses in real wall-clock time regardless of the offline cap.
	# With a 1h cap and a 2h absence, window_start must subtract the full 2h.
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	var tick_system: Node = get_node_or_null("/root/TickSystem")
	assert_object(orch).is_not_null()
	assert_object(tick_system).is_not_null()

	var original_cap: int = int(tick_system.get("offline_cap_seconds"))
	tick_system.offline_cap_seconds = 3600  # 1h cap
	TickSystem._last_wall_ts = _FIXED_NOW_S
	var now_ms: int = TickSystem.now_ms()
	var elapsed_seconds: int = 7200  # 2h absence — exceeds the cap

	var captured: Array = [null]
	OfflineProgressionEngine.offline_rewards_collected.connect(
		func(s: OfflineProgressionEngine.OfflineSummary) -> void: captured[0] = s,
		CONNECT_ONE_SHOT
	)

	OfflineProgressionEngine.run_offline_replay(elapsed_seconds)
	var fired: bool = await _pump_until_summary(captured, _PIPELINE_TIMEOUT_FRAMES)
	assert_bool(fired).is_true()

	# Uncapped: subtracts 7200s, NOT the capped 3600s.
	assert_int(orch._offline_window_start_ms).override_failure_message(
		"window_start must use the uncapped absence length (7200s), not the cap (3600s)"
	).is_equal(now_ms - elapsed_seconds * 1000)

	tick_system.offline_cap_seconds = original_cap
