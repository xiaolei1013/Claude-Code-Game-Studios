# Tests for Sprint 7 dungeon-run-orchestrator Story 005 (S7-M12):
#   - TickSystem.tick_fired subscription on ACTIVE_FOREGROUND entry
#   - Disconnection on ACTIVE_FOREGROUND exit
#   - _on_tick_fired calls combat_resolver.emit_events_in_range
#   - Duplicate-tick guard: n <= last_emitted_tick → no combat call
#   - Strict-rewind warning: n < last_emitted_tick → push_warning + no call
#
# Covers: TR-orchestrator-007 (subscribe/unsubscribe lifecycle),
#         TR-orchestrator-008 (per-tick combat call),
#         TR-orchestrator-009 (duplicate-tick guard + strict-rewind warning).
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")


# Spy CombatResolver — counts emit_events_in_range calls + remembers last args.
class SpyCombatResolver extends RefCounted:
	var call_count: int = 0
	var last_tick_lo: int = -1
	var last_tick_hi: int = -1

	func emit_events_in_range(_snapshot: Variant, tick_lo: int, tick_hi: int) -> Variant:
		call_count += 1
		last_tick_lo = tick_lo
		last_tick_hi = tick_hi
		return null


# Build a fresh orchestrator + spy combat resolver injected before _ready.
func _make_orch_with_spy() -> Array:
	var orch: Node = OrchestratorScript.new()
	var combat_spy: SpyCombatResolver = SpyCombatResolver.new()
	orch.set_combat_resolver(combat_spy)
	add_child(orch)
	auto_free(orch)
	return [orch, combat_spy]


# Build a minimal RunSnapshot suitable for tick handler tests.
func _make_snapshot(last_emitted: int = 0) -> RunSnapshot:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.floor_id = "forest_reach_dungeon_01_floor_1"
	snap.current_tick = last_emitted
	snap.last_emitted_tick = last_emitted
	return snap


# ===========================================================================
# Group A: TR-007 — subscription lifecycle
# ===========================================================================

func test_subscription_connects_on_enter_active_foreground() -> void:
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	# Initial state is NO_RUN — no subscription yet.
	assert_bool(TickSystem.tick_fired.is_connected(orch._on_tick_fired)).is_false()
	# Transition to ACTIVE_FOREGROUND via _set_state.
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	assert_bool(TickSystem.tick_fired.is_connected(orch._on_tick_fired)).is_true()


func test_subscription_disconnects_on_exit_active_foreground() -> void:
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	assert_bool(TickSystem.tick_fired.is_connected(orch._on_tick_fired)).is_true()
	# Exit to RUN_ENDED — disconnect fires.
	orch._set_state(DungeonRunStateScript.State.RUN_ENDED)
	assert_bool(TickSystem.tick_fired.is_connected(orch._on_tick_fired)).is_false()


func test_subscription_disconnects_on_exit_to_offline_replay() -> void:
	# AF → ACTIVE_OFFLINE_REPLAY also disconnects (offline engine takes over).
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	orch._set_state(DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY)
	assert_bool(TickSystem.tick_fired.is_connected(orch._on_tick_fired)).is_false()


func test_subscription_idempotent_on_repeated_enter() -> void:
	# Repeated _set_state(ACTIVE_FOREGROUND) doesn't double-connect.
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	# _set_state with same state is a no-op (early-return); no double-connect.
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	assert_bool(TickSystem.tick_fired.is_connected(orch._on_tick_fired)).is_true()
	# Verify by counting connections — single connection.
	var connections: Array = TickSystem.tick_fired.get_connections()
	var count: int = 0
	for c: Dictionary in connections:
		if c.get("callable").get_method() == "_on_tick_fired":
			count += 1
	assert_int(count).is_less_equal(1)


# ===========================================================================
# Group B: TR-008 — per-tick combat call
# ===========================================================================

func test_on_tick_fired_calls_combat_resolver() -> void:
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	var combat_spy: SpyCombatResolver = pair[1]
	orch.run_snapshot = _make_snapshot(0)
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	orch._on_tick_fired(5)
	assert_int(combat_spy.call_count).is_equal(1)
	assert_int(combat_spy.last_tick_lo).is_equal(0)
	assert_int(combat_spy.last_tick_hi).is_equal(5)


func test_on_tick_fired_advances_last_emitted_tick() -> void:
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	orch.run_snapshot = _make_snapshot(0)
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	orch._on_tick_fired(5)
	assert_int(orch.run_snapshot.last_emitted_tick).is_equal(5)
	assert_int(orch.run_snapshot.current_tick).is_equal(5)


func test_five_consecutive_ticks_produce_five_combat_calls() -> void:
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	var combat_spy: SpyCombatResolver = pair[1]
	orch.run_snapshot = _make_snapshot(0)
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	for n: int in [1, 2, 3, 4, 5]:
		orch._on_tick_fired(n)
	assert_int(combat_spy.call_count).is_equal(5)
	assert_int(orch.run_snapshot.last_emitted_tick).is_equal(5)


# ===========================================================================
# Group C: TR-009 — duplicate-tick guard
# ===========================================================================

func test_duplicate_tick_is_no_op() -> void:
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	var combat_spy: SpyCombatResolver = pair[1]
	orch.run_snapshot = _make_snapshot(0)
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	orch._on_tick_fired(5)  # first call: 1 combat call
	orch._on_tick_fired(5)  # duplicate: should NOT trigger another call
	assert_int(combat_spy.call_count).is_equal(1)


func test_strict_rewind_is_no_op() -> void:
	# n < last_emitted → guard fires; combat NOT called; push_warning emitted.
	# We don't intercept the warning in unit tests, but we verify the guard
	# behavior (no combat call).
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	var combat_spy: SpyCombatResolver = pair[1]
	orch.run_snapshot = _make_snapshot(5)  # last_emitted = 5
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	orch._on_tick_fired(3)  # rewind
	assert_int(combat_spy.call_count).is_equal(0)


# ===========================================================================
# Group D: defensive guards — not in ACTIVE_FOREGROUND, null run_snapshot
# ===========================================================================

func test_on_tick_fired_no_op_when_state_not_active_foreground() -> void:
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	var combat_spy: SpyCombatResolver = pair[1]
	# State is NO_RUN by default.
	orch.run_snapshot = _make_snapshot(0)
	orch._on_tick_fired(5)
	assert_int(combat_spy.call_count).is_equal(0)


func test_on_tick_fired_no_op_when_run_snapshot_null() -> void:
	# Even in ACTIVE_FOREGROUND, null run_snapshot is a defensive no-op
	# (Story 004 of orchestrator epic is responsible for snapshot construction;
	# S7-M12 handler must tolerate the not-yet-built case).
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	var combat_spy: SpyCombatResolver = pair[1]
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	# run_snapshot stays null.
	orch._on_tick_fired(5)
	assert_int(combat_spy.call_count).is_equal(0)


# ===========================================================================
# Group E: state-transition hook coverage — _set_state replaces direct writes
# ===========================================================================

func test_set_state_self_transition_is_no_op() -> void:
	# Repeated _set_state(NO_RUN) shouldn't fire any hooks (no subscription change).
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	orch._set_state(DungeonRunStateScript.State.NO_RUN)  # already NO_RUN
	# State unchanged.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_bool(TickSystem.tick_fired.is_connected(orch._on_tick_fired)).is_false()


func test_set_state_dispatching_does_not_subscribe() -> void:
	# DISPATCHING is NOT ACTIVE_FOREGROUND; no tick subscription.
	var pair: Array = _make_orch_with_spy()
	var orch: Node = pair[0]
	orch._set_state(DungeonRunStateScript.State.DISPATCHING)
	assert_bool(TickSystem.tick_fired.is_connected(orch._on_tick_fired)).is_false()
