# Tests for the FOREGROUND defeat wiring of the Defeat & Injury System
# (GDD #34 §D / ADR-0021 — AC-34-04/05/08). Replaces the retired
# losing_run_wiring_test.gd (the half-loot losing-run state it covered is gone).
#
# Under test — the orchestrator's dispatch-time verdict plumbing:
#   - is_active_run_defeated(): true ONLY while a doomed run is in
#     ACTIVE_FOREGROUND (the Economy drip subscribes to this to forfeit gold).
#   - _on_tick_fired on a defeated run: SKIPS all kill/gold/XP processing (the
#     combat resolver is never called) but advances the tick clock, and fires
#     run_defeated exactly once when the clock reaches _run_defeat_tick.
#
# The verdict MATH (won / defeat_tick from the HP race) lives in
# compute_run_outcome_test.gd; this suite covers the orchestrator WIRING around
# the already-resolved verdict, driving _on_tick_fired directly with a spy
# resolver (no live TickSystem dependency).
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")


# Spy CombatResolver — counts emit_events_in_range calls so we can prove the
# defeat path skips combat processing entirely.
class _SpyCombatResolver extends RefCounted:
	var call_count: int = 0

	func emit_events_in_range(_snapshot: Variant, _tick_lo: int, _tick_hi: int) -> Variant:
		call_count += 1
		return null


func _make_orch_with_spy() -> Array:
	var orch: Node = OrchestratorScript.new()
	var spy: _SpyCombatResolver = _SpyCombatResolver.new()
	orch.set_combat_resolver(spy)
	add_child(orch)
	auto_free(orch)
	return [orch, spy]


func _make_snapshot() -> RunSnapshot:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.floor_id = "forest_reach_dungeon_01_floor_1"
	snap.current_tick = 0
	snap.last_emitted_tick = 0
	return snap


# ===========================================================================
# Group A: is_active_run_defeated() — the drip-gate predicate (AC-34-08)
# ===========================================================================

func test_is_active_run_defeated_true_for_doomed_run_in_active_foreground() -> void:
	var orch: Node = _make_orch_with_spy()[0]
	orch._run_won = false
	orch._run_defeat_tick = -1  # no auto-close: keep the run in ACTIVE_FOREGROUND
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	assert_bool(orch.is_active_run_defeated()).is_true()


func test_is_active_run_defeated_false_for_winning_run() -> void:
	var orch: Node = _make_orch_with_spy()[0]
	orch._run_won = true  # winning run
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	assert_bool(orch.is_active_run_defeated()).is_false()


func test_is_active_run_defeated_false_when_not_in_active_foreground() -> void:
	# A doomed verdict outside ACTIVE_FOREGROUND (e.g. NO_RUN before dispatch, or
	# RUN_ENDED after) must NOT report defeated — the drip only forfeits in-flight.
	var orch: Node = _make_orch_with_spy()[0]
	orch._run_won = false
	# State left at the NO_RUN default.
	assert_bool(orch.is_active_run_defeated()).is_false()


# ===========================================================================
# Group B: _on_tick_fired on a defeated run — zero loot + run_defeated (AC-34-04/05)
# ===========================================================================

func test_defeated_run_skips_all_combat_processing() -> void:
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	var spy: _SpyCombatResolver = pair[1]
	orch.run_snapshot = _make_snapshot()
	orch._run_won = false
	orch._run_defeat_tick = 5
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	# Drive ticks BEFORE the defeat tick — the clock advances but combat (and thus
	# all kill/gold/XP attribution) is never invoked.
	for n: int in [1, 2, 3, 4]:
		orch._on_tick_fired(n)
	assert_int(spy.call_count).override_failure_message(
		"a defeated run must never call the combat resolver — zero loot"
	).is_equal(0)
	assert_int(orch.run_snapshot.last_emitted_tick).is_equal(4)  # clock still advances


func test_defeated_run_emits_run_defeated_once_at_defeat_tick() -> void:
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	var spy: _SpyCombatResolver = pair[1]
	orch.run_snapshot = _make_snapshot()
	orch._run_won = false
	orch._run_defeat_tick = 5
	orch._dispatched_floor_index = 3
	orch._dispatched_biome_id = "forest_reach"
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	var emits: Array = []
	orch.run_defeated.connect(
		func(floor_index: int, biome_id: String) -> void:
			emits.append([floor_index, biome_id])
	)

	# Ticks before the defeat tick: no emission yet.
	for n: int in [1, 2, 3, 4]:
		orch._on_tick_fired(n)
	assert_int(emits.size()).is_equal(0)

	# Reaching the defeat tick fires run_defeated exactly once with dispatch context.
	orch._on_tick_fired(5)
	assert_int(emits.size()).is_equal(1)
	assert_int(int(emits[0][0])).is_equal(3)
	assert_str(String(emits[0][1])).is_equal("forest_reach")

	# Combat was never called across the whole doomed run.
	assert_int(spy.call_count).is_equal(0)


func test_defeat_closure_leaves_active_foreground_so_drip_gate_clears() -> void:
	# After run_defeated fires, the FSM transitions out of ACTIVE_FOREGROUND, so
	# is_active_run_defeated() flips back to false (the drip resumes for the NEXT
	# run, not this dead one).
	var orch: Node = _make_orch_with_spy()[0]
	orch.run_snapshot = _make_snapshot()
	orch._run_won = false
	orch._run_defeat_tick = 2
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	assert_bool(orch.is_active_run_defeated()).is_true()

	orch._on_tick_fired(2)  # reaches defeat tick → _end_run_defeated → RUN_ENDED

	assert_int(orch.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	assert_bool(orch.is_active_run_defeated()).is_false()


# ===========================================================================
# Group C: control — a WINNING run still processes combat
# ===========================================================================

func test_winning_run_calls_combat_resolver_normally() -> void:
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	var spy: _SpyCombatResolver = pair[1]
	orch.run_snapshot = _make_snapshot()
	orch._run_won = true  # WIN → normal processing
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	orch._on_tick_fired(5)
	assert_int(spy.call_count).override_failure_message(
		"a winning run must process combat normally (control for the defeat skip)"
	).is_equal(1)
