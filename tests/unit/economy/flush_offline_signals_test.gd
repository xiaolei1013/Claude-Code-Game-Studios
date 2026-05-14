# Sprint 11 S11-X6: Economy.flush_offline_signals + per-chunk accumulator tests.
#
# Covers ADR-0013 Amendment #1 + OfflineProgressionEngine GDD §F + OQ-OE-6:
#   - Per-call emit sites accumulate during offline replay (gold_changed +
#     first_clear_awarded both deferred until flush).
#   - flush_offline_signals emits ONE aggregate gold_changed (if non-zero
#     delta) + first_clear_awarded per accumulated floor in order.
#   - Flush clears _is_offline_replay flag + accumulators.
#   - Idempotent flush on empty accumulator.
#   - Non-replay (foreground) behavior unchanged — per-call emits as before.
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")


func _make_fresh_economy() -> Node:
	var e: Node = EconomyScript.new()
	add_child(e)
	auto_free(e)
	# Bypass _ready DataRegistry config-load by setting balance directly.
	e._gold_balance = 1000
	e._lifetime_gold_earned = 1000
	return e


# Spy state for both signals.
var _gold_changed_calls: Array[Dictionary] = []
var _first_clear_calls: Array[int] = []


func _on_gold_changed(new_balance: int, delta: int, reason: String) -> void:
	_gold_changed_calls.append({
		"balance": new_balance,
		"delta": delta,
		"reason": reason,
	})


func _on_first_clear_awarded(biome_id: String, floor_index: int) -> void:
	_first_clear_calls.append(floor_index)


func _connect_spy(e: Node) -> void:
	_gold_changed_calls.clear()
	_first_clear_calls.clear()
	if not e.gold_changed.is_connected(_on_gold_changed):
		e.gold_changed.connect(_on_gold_changed)
	if not e.first_clear_awarded.is_connected(_on_first_clear_awarded):
		e.first_clear_awarded.connect(_on_first_clear_awarded)


# ===========================================================================
# Group A — non-replay path is UNCHANGED
# ===========================================================================

func test_add_gold_emits_per_call_when_not_in_offline_replay() -> void:
	var e: Node = _make_fresh_economy()
	_connect_spy(e)
	e.add_gold(100)
	assert_int(_gold_changed_calls.size()).is_equal(1)
	assert_int(_gold_changed_calls[0].delta).is_equal(100)


func test_try_spend_emits_per_call_when_not_in_offline_replay() -> void:
	var e: Node = _make_fresh_economy()
	_connect_spy(e)
	var ok: bool = e.try_spend(50, "test_spend")
	assert_bool(ok).is_true()
	assert_int(_gold_changed_calls.size()).is_equal(1)
	assert_int(_gold_changed_calls[0].delta).is_equal(-50)


# ===========================================================================
# Group B — per-call accumulation during offline replay
# ===========================================================================

func test_add_gold_accumulates_during_offline_replay_no_per_call_signal() -> void:
	var e: Node = _make_fresh_economy()
	e._is_offline_replay = true
	_connect_spy(e)

	e.add_gold(100)
	e.add_gold(50)
	e.add_gold(25)

	# Per-call signals are suppressed; accumulator holds cumulative delta.
	assert_int(_gold_changed_calls.size()).is_equal(0)
	assert_int(e._offline_pending_delta).is_equal(175)


func test_try_spend_accumulates_negative_delta_during_offline_replay() -> void:
	var e: Node = _make_fresh_economy()
	e._is_offline_replay = true
	_connect_spy(e)

	e.try_spend(40, "replay_spend")
	e.try_spend(10, "replay_spend")

	assert_int(_gold_changed_calls.size()).is_equal(0)
	assert_int(e._offline_pending_delta).is_equal(-50)


func test_mixed_add_and_spend_accumulate_to_net_delta() -> void:
	var e: Node = _make_fresh_economy()
	e._is_offline_replay = true
	_connect_spy(e)

	e.add_gold(200)
	e.try_spend(75, "spend")
	e.add_gold(25)

	# Net: +200 - 75 + 25 = +150.
	assert_int(_gold_changed_calls.size()).is_equal(0)
	assert_int(e._offline_pending_delta).is_equal(150)


# ===========================================================================
# Group C — flush_offline_signals aggregate emission
# ===========================================================================

func test_flush_emits_one_aggregate_gold_changed_with_cumulative_delta() -> void:
	var e: Node = _make_fresh_economy()
	e._is_offline_replay = true
	_connect_spy(e)

	e.add_gold(300)
	e.add_gold(200)

	# Pre-flush: zero per-call signals.
	assert_int(_gold_changed_calls.size()).is_equal(0)

	e.flush_offline_signals()

	# Post-flush: exactly one aggregate emit.
	assert_int(_gold_changed_calls.size()).is_equal(1)
	assert_int(_gold_changed_calls[0].delta).is_equal(500)
	assert_str(_gold_changed_calls[0].reason).is_equal("offline_replay_aggregate")


func test_flush_clears_is_offline_replay_flag() -> void:
	var e: Node = _make_fresh_economy()
	e._is_offline_replay = true
	e.add_gold(100)
	assert_bool(e._is_offline_replay).is_true()

	e.flush_offline_signals()

	assert_bool(e._is_offline_replay).is_false()


func test_flush_clears_pending_delta_accumulator() -> void:
	var e: Node = _make_fresh_economy()
	e._is_offline_replay = true
	e.add_gold(50)
	assert_int(e._offline_pending_delta).is_equal(50)

	e.flush_offline_signals()

	assert_int(e._offline_pending_delta).is_equal(0)


func test_flush_with_zero_net_delta_does_not_emit_gold_changed() -> void:
	# add 100, spend 100 → net delta = 0 → no aggregate emit (no zero-delta noise).
	var e: Node = _make_fresh_economy()
	e._is_offline_replay = true
	_connect_spy(e)

	e.add_gold(100)
	e.try_spend(100, "balanced_spend")
	assert_int(e._offline_pending_delta).is_equal(0)

	e.flush_offline_signals()

	assert_int(_gold_changed_calls.size()).is_equal(0)


func test_flush_idempotent_on_empty_accumulator() -> void:
	# Calling flush with no pending accumulation is safe + clears the flag.
	var e: Node = _make_fresh_economy()
	e._is_offline_replay = true
	_connect_spy(e)

	e.flush_offline_signals()

	assert_int(_gold_changed_calls.size()).is_equal(0)
	assert_int(_first_clear_calls.size()).is_equal(0)
	assert_bool(e._is_offline_replay).is_false()


# ===========================================================================
# Group D — first_clear_awarded accumulation
# ===========================================================================

func test_try_award_floor_clear_accumulates_first_clear_during_offline_replay() -> void:
	# Bypass try_award_floor_clear's economy-config dependency by setting state
	# directly + simulating the path: append to accumulator + write to ledger.
	# Production path tested via integration; this test verifies the
	# accumulation contract ONLY.
	var e: Node = _make_fresh_economy()
	e._is_offline_replay = true
	_connect_spy(e)

	# Simulate try_award_floor_clear semantics: floor 1 + 2 first-cleared.
	# Direct accumulator manipulation matches what try_award_floor_clear does
	# when is_first AND _is_offline_replay are both true.
	# Sprint 17 schema v2: accumulator now stores [biome_id, floor_index] pairs.
	e._offline_pending_first_clears.append(["forest_reach", 1])
	e._offline_pending_first_clears.append(["forest_reach", 3])

	# Pre-flush: zero per-call signals.
	assert_int(_first_clear_calls.size()).is_equal(0)

	e.flush_offline_signals()

	# Post-flush: signals emit in insertion order.
	assert_int(_first_clear_calls.size()).is_equal(2)
	assert_int(_first_clear_calls[0]).is_equal(1)
	assert_int(_first_clear_calls[1]).is_equal(3)


func test_flush_emits_gold_and_first_clears_in_order() -> void:
	# Mixed scenario — accumulate gold delta + first-clears, flush, verify
	# both aggregates emit (order between the two signal types is
	# implementation-defined; this test only asserts both fired with
	# correct payloads).
	var e: Node = _make_fresh_economy()
	e._is_offline_replay = true
	_connect_spy(e)

	e.add_gold(500)
	e._offline_pending_first_clears.append(["forest_reach", 2])
	e._offline_pending_first_clears.append(["forest_reach", 4])

	e.flush_offline_signals()

	assert_int(_gold_changed_calls.size()).is_equal(1)
	assert_int(_gold_changed_calls[0].delta).is_equal(500)
	assert_int(_first_clear_calls.size()).is_equal(2)
	assert_int(_first_clear_calls[0]).is_equal(2)
	assert_int(_first_clear_calls[1]).is_equal(4)


# ===========================================================================
# Group E — public API surface lock
# ===========================================================================

func test_economy_flush_offline_signals_method_exists() -> void:
	var e: Node = _make_fresh_economy()
	assert_bool(e.has_method("flush_offline_signals")).is_true()
