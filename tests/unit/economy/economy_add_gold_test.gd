# Tests for Story S2-M3: add_gold real body + gold_changed signal + sanity-cap clamp.
# Covers: TR-economy-001 (sanity cap enforcement), TR-economy-002 (integer arithmetic),
#         ADR-0013 §add_gold semantics (positive-only, clamp, lifetime-unclamped,
#         signal-suppression during offline replay).
#
# Signal-emission counting: a local Array[int] spy is connected to gold_changed before
# each call under test. This avoids GdUnit4 version-specific monitor_signals API
# differences (same pattern as autoload_skeleton_and_state_machine_test.gd) and keeps
# every test fully self-contained.
#
# push_error assertions: GDScript push_error writes to the error log but does not
# throw; GdUnit4 has no direct push_error matcher. For zero/negative amount tests we
# assert state-unchanged + zero signal emissions as the observable contract, and rely
# on the Godot output log for push_error confirmation during manual review.
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")

# ---------------------------------------------------------------------------
# AC: positive add increases balance and lifetime — nominal case
# ---------------------------------------------------------------------------

func test_economy_add_gold_positive_amount_increases_balance_and_lifetime() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	var signal_emissions: Array[Array] = []
	economy.gold_changed.connect(
		func(new_balance: int, delta: int, reason: String) -> void:
			signal_emissions.append([new_balance, delta, reason])
	)

	# Act
	economy.add_gold(100)

	# Assert — balance and lifetime both equal 100
	assert_int(economy.get_gold_balance()).is_equal(100)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(100)

	# Assert — exactly one gold_changed emission with correct payload
	assert_int(signal_emissions.size()).is_equal(1)
	assert_int(signal_emissions[0][0]).is_equal(100)   # new_balance
	assert_int(signal_emissions[0][1]).is_equal(100)   # delta
	assert_str(signal_emissions[0][2]).is_equal("add_gold")  # reason

	# Cleanup
	economy.free()


func test_economy_add_gold_smallest_positive_amount_one() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	economy.add_gold(1)

	# Assert
	assert_int(economy.get_gold_balance()).is_equal(1)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(1)
	assert_int(emit_count[0]).is_equal(1)

	# Cleanup
	economy.free()


func test_economy_add_gold_large_amount_below_cap() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	economy.add_gold(1_000_000)

	# Assert
	assert_int(economy.get_gold_balance()).is_equal(1_000_000)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(1_000_000)
	assert_int(emit_count[0]).is_equal(1)

	# Cleanup
	economy.free()


func test_economy_add_gold_accumulates_on_repeated_calls() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	economy.add_gold(50)
	economy.add_gold(75)

	# Assert
	assert_int(economy.get_gold_balance()).is_equal(125)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(125)
	assert_int(emit_count[0]).is_equal(2)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# AC: sanity-cap clamp — balance saturates, lifetime is unclamped
# ---------------------------------------------------------------------------

func test_economy_add_gold_near_cap_clamps_balance_and_uses_actual_delta_in_signal() -> void:
	# Arrange — balance is 1 below cap; add 100 → balance saturates, delta=1
	var economy: Node = EconomyScript.new()
	economy._gold_balance = EconomyScript.GOLD_SANITY_CAP - 1
	var signal_emissions: Array[Array] = []
	economy.gold_changed.connect(
		func(new_balance: int, delta: int, reason: String) -> void:
			signal_emissions.append([new_balance, delta, reason])
	)

	# Act
	economy.add_gold(100)

	# Assert — balance saturates at cap
	assert_int(economy.get_gold_balance()).is_equal(EconomyScript.GOLD_SANITY_CAP)
	# Assert — lifetime takes the full requested amount (unclamped statistic)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(100)
	# Assert — exactly one signal emitted; delta = actual increment (1), not requested (100)
	assert_int(signal_emissions.size()).is_equal(1)
	assert_int(signal_emissions[0][0]).is_equal(EconomyScript.GOLD_SANITY_CAP)  # new_balance
	assert_int(signal_emissions[0][1]).is_equal(1)                               # actual delta
	assert_str(signal_emissions[0][2]).is_equal("add_gold")

	# Cleanup
	economy.free()


func test_economy_add_gold_at_cap_delta_is_zero_signal_still_fires() -> void:
	# Arrange — balance is already at cap; add 1 → delta=0, signal still fires
	# (per story spec: "signal still fires because delta has no zero-floor")
	var economy: Node = EconomyScript.new()
	economy._gold_balance = EconomyScript.GOLD_SANITY_CAP
	var signal_emissions: Array[Array] = []
	economy.gold_changed.connect(
		func(new_balance: int, delta: int, reason: String) -> void:
			signal_emissions.append([new_balance, delta, reason])
	)

	# Act
	economy.add_gold(1)

	# Assert — balance stays at cap
	assert_int(economy.get_gold_balance()).is_equal(EconomyScript.GOLD_SANITY_CAP)
	# Assert — lifetime still increments by requested amount (unclamped)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(1)
	# Assert — one signal with delta=0
	assert_int(signal_emissions.size()).is_equal(1)
	assert_int(signal_emissions[0][0]).is_equal(EconomyScript.GOLD_SANITY_CAP)
	assert_int(signal_emissions[0][1]).is_equal(0)   # actual_delta = cap - cap = 0
	assert_str(signal_emissions[0][2]).is_equal("add_gold")

	# Cleanup
	economy.free()


func test_economy_add_gold_from_zero_amount_exceeding_cap_clamps_to_cap() -> void:
	# Arrange — from zero, add 2 * GOLD_SANITY_CAP → balance=cap, delta=cap, lifetime=full requested
	var economy: Node = EconomyScript.new()
	var signal_emissions: Array[Array] = []
	economy.gold_changed.connect(
		func(new_balance: int, delta: int, reason: String) -> void:
			signal_emissions.append([new_balance, delta, reason])
	)

	# Act
	economy.add_gold(2 * EconomyScript.GOLD_SANITY_CAP)

	# Assert
	assert_int(economy.get_gold_balance()).is_equal(EconomyScript.GOLD_SANITY_CAP)
	# lifetime = requested (2 * cap), unclamped
	assert_int(economy.get_lifetime_gold_earned()).is_equal(2 * EconomyScript.GOLD_SANITY_CAP)
	# signal delta = actual increment = cap (started from 0)
	assert_int(signal_emissions.size()).is_equal(1)
	assert_int(signal_emissions[0][0]).is_equal(EconomyScript.GOLD_SANITY_CAP)
	assert_int(signal_emissions[0][1]).is_equal(EconomyScript.GOLD_SANITY_CAP)
	assert_str(signal_emissions[0][2]).is_equal("add_gold")

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# AC: zero/negative amount → push_error, no mutation, no signal
# ---------------------------------------------------------------------------

func test_economy_add_gold_zero_amount_does_not_mutate_state_or_emit_signal() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 100
	# Note: _lifetime_gold_earned starts at 0; we leave it at 0 for a clean baseline
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act — push_error fires but does not throw; state must be unchanged
	economy.add_gold(0)

	# Assert — no state mutation
	assert_int(economy.get_gold_balance()).is_equal(100)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(0)
	# Assert — no signal emitted
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_add_gold_negative_amount_does_not_mutate_state_or_emit_signal() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 100
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act — push_error fires; state must be unchanged
	economy.add_gold(-50)

	# Assert
	assert_int(economy.get_gold_balance()).is_equal(100)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(0)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_add_gold_very_negative_amount_does_not_crash() -> void:
	# Arrange — INT64_MIN edge case: should push_error and return, not crash
	var economy: Node = EconomyScript.new()
	economy._gold_balance = 100
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act — -9223372036854775808 (INT64_MIN)
	economy.add_gold(-9223372036854775808)

	# Assert — no crash, no mutation, no signal
	assert_int(economy.get_gold_balance()).is_equal(100)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(0)
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# AC: offline-replay signal suppression
# ---------------------------------------------------------------------------

func test_economy_add_gold_during_offline_replay_mutates_state_silently() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	economy._is_offline_replay = true
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act
	economy.add_gold(100)

	# Assert — state mutates normally
	assert_int(economy.get_gold_balance()).is_equal(100)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(100)
	# Assert — zero signal emissions during offline replay
	assert_int(emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_add_gold_offline_replay_no_signal_latch_after_flag_cleared() -> void:
	# Arrange — set replay mode, add gold, clear flag, then add more gold
	var economy: Node = EconomyScript.new()
	economy._is_offline_replay = true
	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act — silent add during replay
	economy.add_gold(100)

	# Assert — no signal yet
	assert_int(emit_count[0]).is_equal(0)

	# Act — clear flag; subsequent add MUST emit normally
	economy._is_offline_replay = false
	economy.add_gold(50)

	# Assert — exactly one signal from the post-replay call
	assert_int(economy.get_gold_balance()).is_equal(150)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(150)
	assert_int(emit_count[0]).is_equal(1)

	# Cleanup
	economy.free()
