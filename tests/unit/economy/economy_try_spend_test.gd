# Tests for Story S2-M4: try_spend atomic — insufficient/sufficient/zero/negative/
# offline-replay/reason-propagation paths.
# Covers: AC H-05 (insufficient), AC H-06 (sufficient), AC H-12 (zero no-op),
#         AC H-12 (negative defensive), offline-replay signal suppression,
#         reason-string verbatim propagation.
#         ADR-0013 §try_spend semantics — GDD §C.3, §H-05, §H-06, §H-12
#
# Signal-emission counting: a local Array[int] spy is connected to gold_changed
# before each call under test. This avoids GdUnit4 version-specific
# monitor_signals API differences (same pattern as economy_add_gold_test.gd)
# and keeps every test fully self-contained.
#
# push_error assertions: GDScript push_error writes to the error log but does
# not throw; GdUnit4 has no direct push_error matcher. For negative-amount
# tests we assert state-unchanged + zero signal emissions as the observable
# contract, and rely on the Godot output log for push_error confirmation during
# manual review.
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")

# ---------------------------------------------------------------------------
# AC H-05: insufficient balance — returns false, no mutation, no signal
# ---------------------------------------------------------------------------

func test_economy_try_spend_insufficient_balance_returns_false() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 100
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	var result: bool = economy.try_spend(150, "test")

	# Assert
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(100)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_try_spend_at_boundary_one_over_balance_returns_false() -> void:
	# Arrange — balance=100, spend 101 → at-boundary insufficient
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 100
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	var result: bool = economy.try_spend(101, "test")

	# Assert
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(100)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# AC H-06: sufficient balance — returns true, deducts, emits signal
# ---------------------------------------------------------------------------

func test_economy_try_spend_sufficient_balance_returns_true_and_deducts() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 500
	var signal_emissions: Array[Array] = []
	economy.gold_changed.connect(
		func(new_balance: int, delta: int, reason: String) -> void:
			signal_emissions.append([new_balance, delta, reason])
	)

	# Act
	var result: bool = economy.try_spend(200, "recruit")

	# Assert
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(300)
	assert_int(signal_emissions.size()).is_equal(1)
	assert_int(signal_emissions[0][0]).is_equal(300)    # new_balance
	assert_int(signal_emissions[0][1]).is_equal(-200)   # delta (negative = spend)
	assert_str(signal_emissions[0][2]).is_equal("recruit")  # reason

	# Cleanup
	economy.free()


func test_economy_try_spend_exact_balance_returns_true_balance_zero_signal_fires() -> void:
	# Arrange — spend exactly the balance → true, balance=0, signal fires
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 300
	var signal_emissions: Array[Array] = []
	economy.gold_changed.connect(
		func(new_balance: int, delta: int, reason: String) -> void:
			signal_emissions.append([new_balance, delta, reason])
	)

	# Act
	var result: bool = economy.try_spend(300, "level_up")

	# Assert
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_int(signal_emissions.size()).is_equal(1)
	assert_int(signal_emissions[0][0]).is_equal(0)
	assert_int(signal_emissions[0][1]).is_equal(-300)
	assert_str(signal_emissions[0][2]).is_equal("level_up")

	# Cleanup
	economy.free()


func test_economy_try_spend_one_over_exact_balance_returns_false() -> void:
	# Arrange — balance+1 → false (boundary check)
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 300
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	var result: bool = economy.try_spend(301, "recruit")

	# Assert
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(300)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# AC H-12: zero amount — no-op true, no mutation, no signal
# ---------------------------------------------------------------------------

func test_economy_try_spend_zero_amount_at_zero_balance_returns_true_no_signal() -> void:
	# Arrange — B=0
	var economy: Node = EconomyScript.new()
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	var result: bool = economy.try_spend(0, "anything")

	# Assert
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_try_spend_zero_amount_at_sanity_cap_returns_true_no_signal() -> void:
	# Arrange — B=GOLD_SANITY_CAP (no signal even at cap)
	var economy: Node = EconomyScript.new()
	economy._gold_balance = EconomyScript.GOLD_SANITY_CAP
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	var result: bool = economy.try_spend(0, "anything")

	# Assert
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(EconomyScript.GOLD_SANITY_CAP)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# AC H-12: negative amount — push_error + false, no mutation, no signal
# ---------------------------------------------------------------------------

func test_economy_try_spend_negative_amount_returns_false_no_mutation_no_signal() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 100
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act — push_error fires but does not throw; state must be unchanged
	var result: bool = economy.try_spend(-50, "test")

	# Assert
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(100)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_try_spend_smallest_negative_minus_one_returns_false() -> void:
	# Arrange — smallest negative: -1
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 100
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	var result: bool = economy.try_spend(-1, "test")

	# Assert
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(100)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_try_spend_int64_min_does_not_crash() -> void:
	# Arrange — INT64_MIN edge case: should push_error and return, not crash
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 100
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act — -9223372036854775808 (INT64_MIN)
	var result: bool = economy.try_spend(-9223372036854775808, "test")

	# Assert — no crash, no mutation, no signal
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(100)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# AC: offline-replay signal suppression
# ---------------------------------------------------------------------------

func test_economy_try_spend_during_offline_replay_mutates_silently() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	economy._is_offline_replay = true
	economy._gold_balance = 500
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	var result: bool = economy.try_spend(200, "test")

	# Assert — returns true, balance mutated, zero emissions
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(300)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_try_spend_offline_replay_flag_flip_then_emits_normally() -> void:
	# Arrange — set replay mode, spend silently, clear flag, then spend with signal
	var economy: Node = EconomyScript.new()
	economy._is_offline_replay = true
	economy._gold_balance = 500
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act — silent spend during replay
	var result_replay: bool = economy.try_spend(200, "test")

	# Assert — no signal yet
	assert_bool(result_replay).is_true()
	assert_int(economy.get_gold_balance()).is_equal(300)
	assert_int(emit_count[0]).is_equal(0)

	# Act — clear flag; subsequent spend MUST emit normally
	economy._is_offline_replay = false
	var result_normal: bool = economy.try_spend(100, "recruit")

	# Assert — exactly one signal from the post-replay call
	assert_bool(result_normal).is_true()
	assert_int(economy.get_gold_balance()).is_equal(200)
	assert_int(emit_count[0]).is_equal(1)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# AC: reason-string propagation — verbatim into signal's third arg
# ---------------------------------------------------------------------------

func test_economy_try_spend_reason_string_propagated_verbatim_into_signal() -> void:
	# Arrange — verify several distinct reason strings are propagated unchanged
	var reason_strings: Array[String] = ["recruit", "level_up", "test_reason"]
	for reason in reason_strings:
		var economy: Node = EconomyScript.new()
		economy._gold_balance = 500
		var signal_emissions: Array[Array] = []
		economy.gold_changed.connect(
			func(new_balance: int, delta: int, captured_reason: String) -> void:
				signal_emissions.append([new_balance, delta, captured_reason])
		)

		# Act
		var result: bool = economy.try_spend(100, reason)

		# Assert — result true; reason propagated verbatim
		assert_bool(result).is_true()
		assert_int(signal_emissions.size()).is_equal(1)
		assert_str(signal_emissions[0][2]).is_equal(reason)

		# Cleanup
		economy.free()
