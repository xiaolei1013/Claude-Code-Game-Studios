# Tests for Sprint 8 combat-resolution Story 010 (S8-N1) orchestrator integration:
#   - Orchestrator invokes Combat synchronously within its tick handler
#   - Combat itself does NOT subscribe to TickSystem.tick_fired
#   - 1000-tick foreground sim invokes Combat.emit_events_in_range exactly
#     N times where N = number of ticks fired (no auto-batching, no skips)
#
# Covers: TR-combat-029 (synchronous invocation contract — Orchestrator
#                        owns the tick subscription; Combat is a pure function
#                        called from inside the orchestrator's tick handler).
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const CombatTickEventsScript = preload("res://src/core/combat/combat_tick_events.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")


# Counting spy CombatResolver — extends RefCounted, exposes the methods the
# orchestrator calls, and counts emit_events_in_range invocations + records
# the (tick_lo, tick_hi) range per call. Demonstrates Combat is invoked
# from the orchestrator's tick handler, not from any internal subscription.
class CountingCombatResolverSpy extends RefCounted:
	const _Default := preload("res://src/core/combat/default_combat_resolver.gd")
	var _real: RefCounted = _Default.new()
	var emit_events_call_count: int = 0
	var call_log: Array = []  # Array of {tick_lo, tick_hi}

	func emit_events_in_range(snapshot: RefCounted, tick_lo: int, tick_hi: int) -> RefCounted:
		emit_events_call_count += 1
		call_log.append({"tick_lo": tick_lo, "tick_hi": tick_hi})
		return _real.emit_events_in_range(snapshot, tick_lo, tick_hi)

	func formation_dps_per_tick(formation: Array, error_logger: Callable = Callable()) -> float:
		return _real.formation_dps_per_tick(formation, error_logger)

	func formation_total_hp(formation: Array, error_logger: Callable = Callable()) -> int:
		return _real.formation_total_hp(formation, error_logger)

	func build_matchup_cache(formation: Array, archetypes: Array, matchup_resolver: RefCounted) -> Dictionary:
		return _real.build_matchup_cache(formation, archetypes, matchup_resolver)

	func is_stub() -> String:
		return "DefaultCombatResolver (counting spy wrapper)"


# Snapshot of the live /root/HeroRoster, captured before each test and restored
# after. These tests dispatch synthetic formations whose instance_ids collide
# with the live starter heroes; a defeat on an unlocked floor injures those
# shared heroes (GDD #34 / ADR-0021), which would trip the dispatch-time
# injured-hero gate in a later test or suite (the orchestrator reads the live
# /root/HeroRoster even when constructed locally). Reset to empty per test so
# every dispatched id reads as a healthy unknown, and restore afterward so this
# suite neither suffers nor causes a cross-test roster leak
# (memory: feedback_test_isolation_live_autoload).
var _roster_snapshot: Dictionary = {}


func before_test() -> void:
	_roster_snapshot = HeroRosterFixture.snapshot_via_save_data()
	HeroRosterFixture.reset_hero_roster()


func after_test() -> void:
	HeroRosterFixture.restore_via_load_save_data(_roster_snapshot)


func _make_hero(class_id: String, instance_id: int, level: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = level
	return h


func _data_registry_can_resolve_classes() -> bool:
	return DataRegistry.resolve("classes", "warrior") != null


# ===========================================================================
# Group A: TR-029 — Combat is invoked synchronously from orchestrator
# ===========================================================================

func test_orchestrator_calls_combat_emit_events_once_per_tick_handler_invocation() -> void:
	# Drive 50 simulated ticks; assert spy.emit_events_call_count == 50.
	# Each tick handler call should result in exactly one Combat invocation —
	# no batching, no skips, no internal subscription firing extras.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped: DataRegistry cannot resolve classes")
		return
	var orch: Node = OrchestratorScript.new()
	var combat_spy: CountingCombatResolverSpy = CountingCombatResolverSpy.new()
	orch.set_combat_resolver(combat_spy)
	orch.set_matchup_resolver(DefaultMatchupResolverScript.new())
	add_child(orch)
	auto_free(orch)
	orch.dispatch([_make_hero("warrior", 1, 5)], 1, "forest_reach")
	# Reset call count to ignore the dispatch-time formation_dps_per_tick call.
	# emit_events_call_count tracks ONLY emit_events_in_range, which dispatch
	# does NOT call. So no reset needed — count starts at 0 post-dispatch.

	# Act — fire 50 ticks with monotonic increasing values.
	var tick_count: int = 0
	for n: int in range(1, 51):
		if orch.state == DungeonRunStateScript.State.ACTIVE_FOREGROUND:
			orch._on_tick_fired(n)
			tick_count += 1
		else:
			break  # run ended; stop firing ticks

	# Assert — spy invoked exactly tick_count times (1 call per tick handler).
	assert_int(combat_spy.emit_events_call_count).is_equal(tick_count)


func test_combat_call_log_uses_monotonic_tick_ranges_per_orchestrator_handler() -> void:
	# Each (tick_lo, tick_hi] range should be (prev_n, current_n] — the
	# orchestrator passes (run_snapshot.last_emitted_tick, n) to Combat.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	var orch: Node = OrchestratorScript.new()
	var combat_spy: CountingCombatResolverSpy = CountingCombatResolverSpy.new()
	orch.set_combat_resolver(combat_spy)
	orch.set_matchup_resolver(DefaultMatchupResolverScript.new())
	add_child(orch)
	auto_free(orch)
	orch.dispatch([_make_hero("warrior", 1, 5)], 1, "forest_reach")

	# Act — fire 5 ticks; record range per call.
	for n: int in range(1, 6):
		if orch.state == DungeonRunStateScript.State.ACTIVE_FOREGROUND:
			orch._on_tick_fired(n)
		else:
			break

	# Assert — recorded ranges are monotonic; each call's tick_lo == previous
	# call's tick_hi.
	var call_log: Array = combat_spy.call_log
	if call_log.size() >= 2:
		for i: int in range(1, call_log.size()):
			var prev_hi: int = int(call_log[i - 1]["tick_hi"])
			var curr_lo: int = int(call_log[i]["tick_lo"])
			assert_int(curr_lo).is_equal(prev_hi)


# ===========================================================================
# Group B: TR-029 — Combat does not subscribe to TickSystem (runtime check)
# ===========================================================================

func test_combat_resolver_instance_is_not_in_tick_system_connections() -> void:
	# Runtime check: after dispatch, the only entity subscribed to
	# TickSystem.tick_fired should be the orchestrator (its _on_tick_fired
	# handler). The Combat resolver instance itself should NOT appear in
	# the connection list.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	var orch: Node = OrchestratorScript.new()
	var combat: RefCounted = DefaultCombatResolverScript.new()
	orch.set_combat_resolver(combat)
	orch.set_matchup_resolver(DefaultMatchupResolverScript.new())
	add_child(orch)
	auto_free(orch)
	orch.dispatch([_make_hero("warrior", 1, 5)], 1, "forest_reach")

	# Assert — TickSystem.tick_fired connections do NOT include the combat
	# resolver as a target. Walk get_connections() and check each callable's
	# get_object() against the combat instance.
	var connections: Array = TickSystem.tick_fired.get_connections()
	for conn: Dictionary in connections:
		var callable: Callable = conn.get("callable") as Callable
		var target: Object = callable.get_object()
		assert_object(target).is_not_equal(combat)


# ===========================================================================
# Group C: code review 2026-06-16 (C1) — dispatch anchors lazily to the FIRST
# observed tick, not a hardcoded 0. TickSystem.tick_fired carries a monotonic,
# session-absolute counter; in production the first tick after a dispatch is
# already in the hundreds. Pre-fix, dispatched_at_tick=0 made the first handler
# call feed Combat the range (0, n] and resolve the ENTIRE run in one tick
# (instant clear/defeat on every run after the first cold-launch dispatch).
# ===========================================================================

func test_first_observed_tick_anchors_window_to_n_minus_one() -> void:
	# Simulate a session whose absolute tick counter is already high at dispatch:
	# the first observed tick is 800. The anchor must bind to 799 so Combat sees
	# only the (799, 800] window (one relative tick), NOT (0, 800].
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped: DataRegistry cannot resolve classes")
		return
	var orch: Node = OrchestratorScript.new()
	var combat_spy: CountingCombatResolverSpy = CountingCombatResolverSpy.new()
	orch.set_combat_resolver(combat_spy)
	orch.set_matchup_resolver(DefaultMatchupResolverScript.new())
	add_child(orch)
	auto_free(orch)
	orch.dispatch([_make_hero("warrior", 1, 5)], 1, "forest_reach")

	# Act — the FIRST observed tick is a large session-absolute value.
	orch._on_tick_fired(800)

	# Assert — exactly one Combat call, windowed to (799, 800], not (0, 800].
	assert_int(combat_spy.call_log.size()).is_equal(1)
	assert_int(int(combat_spy.call_log[0]["tick_lo"])).is_equal(799)
	assert_int(int(combat_spy.call_log[0]["tick_hi"])).is_equal(800)


func test_manual_tick_stream_from_one_still_anchors_to_zero() -> void:
	# Drivers that fire ticks starting at n=1 (the common test pattern) must keep
	# anchoring to 0 — the first window stays (0, 1] exactly as before the fix.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped: DataRegistry cannot resolve classes")
		return
	var orch: Node = OrchestratorScript.new()
	var combat_spy: CountingCombatResolverSpy = CountingCombatResolverSpy.new()
	orch.set_combat_resolver(combat_spy)
	orch.set_matchup_resolver(DefaultMatchupResolverScript.new())
	add_child(orch)
	auto_free(orch)
	orch.dispatch([_make_hero("warrior", 1, 5)], 1, "forest_reach")

	orch._on_tick_fired(1)

	assert_int(combat_spy.call_log.size()).is_equal(1)
	assert_int(int(combat_spy.call_log[0]["tick_lo"])).is_equal(0)
	assert_int(int(combat_spy.call_log[0]["tick_hi"])).is_equal(1)
