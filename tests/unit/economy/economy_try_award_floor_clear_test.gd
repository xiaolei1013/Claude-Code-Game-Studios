# Tests for Story S3-M1: try_award_floor_clear monotonic-credit ledger (ADR-0002).
# Covers: AC H-03 (idempotent first credit + repeat), AC H-14 main (WIN/repeat-WIN/LOSING
#         sequence), Sub-AC 14-losing-first-then-win-reclaim, Sub-AC 14-win-then-losing-
#         no-reclaim, Sub-AC 14-boundary (out-of-range floor_index), Sub-AC 14-negative-
#         bonus, Sub-AC 14-zero-bonus, offline-replay signal suppression.
#
# Signal-emission counting: local Array[int] spies are connected to first_clear_awarded
# and gold_changed before each call under test. This matches the pattern established in
# economy_add_gold_test.gd and economy_try_spend_test.gd to avoid GdUnit4
# version-specific monitor_signals API differences.
#
# Ledger-key-absence assertions: use economy._floor_clear_bonus_credited.has(N) directly.
# Dictionary.get(key, default) does NOT insert — but we assert has() explicitly per the
# story QA requirement to prove no phantom key is ever written on error/no-op paths.
#
# push_error assertions: GDScript push_error writes to the error log but does not throw.
# For error-path tests we assert state-unchanged + zero signal emissions as the observable
# contract, and rely on the Godot output log for push_error confirmation during manual review.
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")

# ---------------------------------------------------------------------------
# AC H-03: idempotent first credit — first call returns true; second returns false
# ---------------------------------------------------------------------------

func test_economy_try_award_floor_clear_first_call_credits_gold_and_returns_true() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	var gold_emissions: Array[Array] = []
	var first_clear_emissions: Array[int] = []
	economy.gold_changed.connect(
		func(new_balance: int, delta: int, reason: String) -> void:
			gold_emissions.append([new_balance, delta, reason])
	)
	economy.first_clear_awarded.connect(
		func(floor_index: int) -> void: first_clear_emissions.append(floor_index)
	)

	# Act
	var result: bool = economy.try_award_floor_clear(3, 3000)

	# Assert — returns true; gold +3000; ledger {3: 3000}; exactly one emission of each signal
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(3000)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(3000)
	assert_bool(economy._floor_clear_bonus_credited.has(3)).is_true()
	assert_int(economy._floor_clear_bonus_credited.get(3, -1)).is_equal(3000)
	assert_int(gold_emissions.size()).is_equal(1)
	assert_int(gold_emissions[0][0]).is_equal(3000)   # new_balance
	assert_int(gold_emissions[0][1]).is_equal(3000)   # delta
	assert_str(gold_emissions[0][2]).is_equal("add_gold")
	assert_int(first_clear_emissions.size()).is_equal(1)
	assert_int(first_clear_emissions[0]).is_equal(3)

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_second_identical_call_returns_false_no_mutation() -> void:
	# Arrange — prime the ledger with a first credit
	var economy: Node = EconomyScript.new()
	economy.try_award_floor_clear(3, 3000)  # prime
	var gold_emit_count: Array[int] = [0]
	var first_clear_emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: gold_emit_count[0] += 1)
	economy.first_clear_awarded.connect(func(_f: int) -> void: first_clear_emit_count[0] += 1)

	# Act — second call with same args
	var result: bool = economy.try_award_floor_clear(3, 3000)

	# Assert — returns false; ledger unchanged; no add_gold; no signals
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(3000)  # unchanged from prime
	assert_int(economy.get_lifetime_gold_earned()).is_equal(3000)
	assert_int(economy._floor_clear_bonus_credited.get(3, -1)).is_equal(3000)  # unchanged
	assert_int(gold_emit_count[0]).is_equal(0)
	assert_int(first_clear_emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# AC H-14 main: WIN(3000) → repeat-WIN(3000) → LOSING(1500) triple sequence
# ---------------------------------------------------------------------------

func test_economy_try_award_floor_clear_win_repeat_losing_sequence_total_3000() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	var gold_emit_count: Array[int] = [0]
	var first_clear_emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: gold_emit_count[0] += 1)
	economy.first_clear_awarded.connect(func(_f: int) -> void: first_clear_emit_count[0] += 1)

	# Act — sequence: WIN(3000), repeat-WIN(3000), LOSING(1500)
	var result1: bool = economy.try_award_floor_clear(3, 3000)
	var result2: bool = economy.try_award_floor_clear(3, 3000)
	var result3: bool = economy.try_award_floor_clear(3, 1500)

	# Assert — first credits 3000 + emits; second = false; third = false (LOSING below WIN)
	assert_bool(result1).is_true()
	assert_bool(result2).is_false()
	assert_bool(result3).is_false()
	assert_int(economy.get_gold_balance()).is_equal(3000)  # total = 3000
	assert_int(economy.get_lifetime_gold_earned()).is_equal(3000)
	assert_int(economy._floor_clear_bonus_credited.get(3, -1)).is_equal(3000)  # ledger unchanged after 1st
	assert_int(gold_emit_count[0]).is_equal(1)   # only the first call triggered add_gold
	assert_int(first_clear_emit_count[0]).is_equal(1)  # signal fired exactly once

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# Sub-AC 14-losing-first-then-win-reclaim: the headline reclaim path
# ---------------------------------------------------------------------------

func test_economy_try_award_floor_clear_losing_first_credits_halved_and_emits_signal() -> void:
	# Arrange — LOSING run calls first; bonus_amount = 1500 (halved)
	var economy: Node = EconomyScript.new()
	var first_clear_emissions: Array[int] = []
	economy.first_clear_awarded.connect(
		func(floor_index: int) -> void: first_clear_emissions.append(floor_index)
	)

	# Act — LOSING first clear
	var result: bool = economy.try_award_floor_clear(3, 1500)

	# Assert — true, gold +1500, ledger {3: 1500}, first_clear_awarded fires once
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(1500)
	assert_int(economy._floor_clear_bonus_credited.get(3, -1)).is_equal(1500)
	assert_int(first_clear_emissions.size()).is_equal(1)
	assert_int(first_clear_emissions[0]).is_equal(3)

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_win_after_losing_credits_delta_no_re_emit() -> void:
	# Arrange — LOSING first, then WIN follow-up
	var economy: Node = EconomyScript.new()
	economy.try_award_floor_clear(3, 1500)  # LOSING prime: gold=1500, ledger {3:1500}

	var gold_emissions: Array[Array] = []
	var first_clear_emit_count: Array[int] = [0]
	economy.gold_changed.connect(
		func(new_balance: int, delta: int, reason: String) -> void:
			gold_emissions.append([new_balance, delta, reason])
	)
	economy.first_clear_awarded.connect(func(_f: int) -> void: first_clear_emit_count[0] += 1)

	# Act — WIN follow-up: credits delta = 3000 - 1500 = 1500
	var result: bool = economy.try_award_floor_clear(3, 3000)

	# Assert — returns true; delta=1500 added; ledger advances to 3000; NO re-emit of first_clear_awarded
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(3000)  # 1500 + 1500 = 3000
	assert_int(economy.get_lifetime_gold_earned()).is_equal(3000)
	assert_int(economy._floor_clear_bonus_credited.get(3, -1)).is_equal(3000)
	assert_int(gold_emissions.size()).is_equal(1)
	assert_int(gold_emissions[0][0]).is_equal(3000)   # new_balance
	assert_int(gold_emissions[0][1]).is_equal(1500)   # delta = gap, not full bonus
	assert_str(gold_emissions[0][2]).is_equal("add_gold")
	assert_int(first_clear_emit_count[0]).is_equal(0)  # milestone already fired; no re-emit

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_reclaim_subsequent_calls_return_false() -> void:
	# Arrange — complete the LOSING → WIN reclaim; verify ceiling is honoured after
	var economy: Node = EconomyScript.new()
	economy.try_award_floor_clear(3, 1500)  # LOSING
	economy.try_award_floor_clear(3, 3000)  # WIN reclaim → total=3000

	var emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: emit_count[0] += 1)

	# Act — repeat at ceiling or below
	var r1: bool = economy.try_award_floor_clear(3, 3000)  # exact ceiling → false
	var r2: bool = economy.try_award_floor_clear(3, 1500)  # below ceiling → false

	# Assert — both false; gold unchanged from 3000; no further add_gold calls
	assert_bool(r1).is_false()
	assert_bool(r2).is_false()
	assert_int(economy.get_gold_balance()).is_equal(3000)
	assert_int(emit_count[0]).is_equal(0)

	# Assert — above-ceiling future bonus still credited
	var r3: bool = economy.try_award_floor_clear(3, 3001)
	assert_bool(r3).is_true()
	assert_int(economy.get_gold_balance()).is_equal(3001)  # 3000 + delta(1)
	assert_int(economy._floor_clear_bonus_credited.get(3, -1)).is_equal(3001)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# Sub-AC 14-win-then-losing-no-reclaim
# ---------------------------------------------------------------------------

func test_economy_try_award_floor_clear_win_then_losing_losing_returns_false() -> void:
	# Arrange — WIN first
	var economy: Node = EconomyScript.new()
	economy.try_award_floor_clear(3, 3000)  # WIN prime

	var gold_emit_count: Array[int] = [0]
	var first_clear_emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: gold_emit_count[0] += 1)
	economy.first_clear_awarded.connect(func(_f: int) -> void: first_clear_emit_count[0] += 1)

	# Act — LOSING follow-up: 1500 < 3000 ceiling
	var result: bool = economy.try_award_floor_clear(3, 1500)

	# Assert — false; zero credit; zero signal; ledger still at 3000
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(3000)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(3000)
	assert_int(economy._floor_clear_bonus_credited.get(3, -1)).is_equal(3000)
	assert_int(gold_emit_count[0]).is_equal(0)
	assert_int(first_clear_emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_win_then_zero_bonus_returns_false() -> void:
	# Arrange — WIN prime, then zero-bonus call (degenerate LOSING edge case)
	var economy: Node = EconomyScript.new()
	economy.try_award_floor_clear(3, 3000)  # WIN prime

	# Act
	var result: bool = economy.try_award_floor_clear(3, 0)

	# Assert — false; zero-bonus at-or-below-ceiling path
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(3000)
	assert_int(economy._floor_clear_bonus_credited.get(3, -1)).is_equal(3000)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# Sub-AC 14-boundary: out-of-range floor_index — push_error, false, no ledger mutation
# ---------------------------------------------------------------------------

func test_economy_try_award_floor_clear_floor_index_zero_returns_false_no_ledger_mutation() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	var gold_emit_count: Array[int] = [0]
	var first_clear_emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: gold_emit_count[0] += 1)
	economy.first_clear_awarded.connect(func(_f: int) -> void: first_clear_emit_count[0] += 1)

	# Act — floor_index=0 is below range [1,5]; push_error fires (not caught in test)
	var result: bool = economy.try_award_floor_clear(0, 500)

	# Assert — returns false; no state mutation; ledger has NO key for 0 (no phantom insert)
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_bool(economy._floor_clear_bonus_credited.has(0)).is_false()
	assert_int(gold_emit_count[0]).is_equal(0)
	assert_int(first_clear_emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_floor_index_six_returns_false_no_ledger_mutation() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — floor_index=6 is above range [1,5]
	var result: bool = economy.try_award_floor_clear(6, 500)

	# Assert — false; no key 6 in ledger
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_bool(economy._floor_clear_bonus_credited.has(6)).is_false()

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_floor_index_negative_returns_false_no_ledger_mutation() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — negative floor_index
	var result: bool = economy.try_award_floor_clear(-1, 500)

	# Assert — false; no negative key inserted
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_bool(economy._floor_clear_bonus_credited.has(-1)).is_false()

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# Sub-AC 14-negative-bonus: bonus_amount < 0 — push_error, false, no mutation
# ---------------------------------------------------------------------------

func test_economy_try_award_floor_clear_negative_bonus_returns_false_no_mutation() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	var gold_emit_count: Array[int] = [0]
	var first_clear_emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: gold_emit_count[0] += 1)
	economy.first_clear_awarded.connect(func(_f: int) -> void: first_clear_emit_count[0] += 1)

	# Act — bonus_amount = -100; push_error fires
	var result: bool = economy.try_award_floor_clear(1, -100)

	# Assert — false; ledger key 1 absent; floor remains uncredited
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_bool(economy._floor_clear_bonus_credited.has(1)).is_false()
	assert_int(gold_emit_count[0]).is_equal(0)
	assert_int(first_clear_emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_negative_one_bonus_returns_false() -> void:
	# Arrange — smallest negative: -1
	var economy: Node = EconomyScript.new()

	# Act
	var result: bool = economy.try_award_floor_clear(2, -1)

	# Assert
	assert_bool(result).is_false()
	assert_bool(economy._floor_clear_bonus_credited.has(2)).is_false()

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_int64_min_bonus_does_not_crash() -> void:
	# Arrange — INT64_MIN edge case: must push_error and return, not crash
	var economy: Node = EconomyScript.new()

	# Act — -9223372036854775808 (INT64_MIN)
	var result: bool = economy.try_award_floor_clear(1, -9223372036854775808)

	# Assert — no crash, no mutation
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_bool(economy._floor_clear_bonus_credited.has(1)).is_false()

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_after_negative_bonus_valid_call_still_credits() -> void:
	# Arrange — negative-bonus error must not permanently block the floor
	var economy: Node = EconomyScript.new()
	economy.try_award_floor_clear(1, -100)  # rejected; floor 1 stays uncredited

	var first_clear_emissions: Array[int] = []
	economy.first_clear_awarded.connect(
		func(floor_index: int) -> void: first_clear_emissions.append(floor_index)
	)

	# Act — subsequent valid call must credit normally
	var result: bool = economy.try_award_floor_clear(1, 500)

	# Assert — true; gold=500; signal fired
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(500)
	assert_int(economy._floor_clear_bonus_credited.get(1, -1)).is_equal(500)
	assert_int(first_clear_emissions.size()).is_equal(1)
	assert_int(first_clear_emissions[0]).is_equal(1)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# Sub-AC 14-zero-bonus: bonus_amount = 0 on uncredited floor — false, no insert
# ---------------------------------------------------------------------------

func test_economy_try_award_floor_clear_zero_bonus_on_uncredited_floor_returns_false() -> void:
	# Arrange — fresh ledger; floor 1 uncredited
	var economy: Node = EconomyScript.new()
	var gold_emit_count: Array[int] = [0]
	var first_clear_emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: gold_emit_count[0] += 1)
	economy.first_clear_awarded.connect(func(_f: int) -> void: first_clear_emit_count[0] += 1)

	# Act — zero-bonus: bonus_amount(0) <= already(0) → at-or-below-ceiling path
	var result: bool = economy.try_award_floor_clear(1, 0)

	# Assert — false; NO key 1 inserted into ledger (critical: not {1: 0})
	assert_bool(result).is_false()
	assert_bool(economy._floor_clear_bonus_credited.has(1)).is_false()
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_int(gold_emit_count[0]).is_equal(0)
	assert_int(first_clear_emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_valid_call_after_zero_bonus_credits_normally() -> void:
	# Arrange — zero-bonus rejected; floor must remain creditable
	var economy: Node = EconomyScript.new()
	economy.try_award_floor_clear(1, 0)  # rejected; no insert
	assert_bool(economy._floor_clear_bonus_credited.has(1)).is_false()  # verify no phantom key

	var first_clear_emissions: Array[int] = []
	economy.first_clear_awarded.connect(
		func(floor_index: int) -> void: first_clear_emissions.append(floor_index)
	)

	# Act — valid WIN call after the rejected zero-bonus
	var result: bool = economy.try_award_floor_clear(1, 500)

	# Assert — true; gold=500; first_clear_awarded fires (floor was truly uncredited)
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(500)
	assert_int(economy._floor_clear_bonus_credited.get(1, -1)).is_equal(500)
	assert_int(first_clear_emissions.size()).is_equal(1)
	assert_int(first_clear_emissions[0]).is_equal(1)

	# Cleanup
	economy.free()

# ---------------------------------------------------------------------------
# AC: offline-replay — add_gold runs; first_clear_awarded suppressed
# ---------------------------------------------------------------------------

func test_economy_try_award_floor_clear_offline_replay_suppresses_first_clear_signal() -> void:
	# Arrange — replay mode active
	var economy: Node = EconomyScript.new()
	economy._is_offline_replay = true

	var gold_emit_count: Array[int] = [0]
	var first_clear_emit_count: Array[int] = [0]
	economy.gold_changed.connect(func(_b: int, _d: int, _r: String) -> void: gold_emit_count[0] += 1)
	economy.first_clear_awarded.connect(func(_f: int) -> void: first_clear_emit_count[0] += 1)

	# Act — first credit during offline replay
	var result: bool = economy.try_award_floor_clear(3, 3000)

	# Assert — returns true; gold credited (add_gold runs); ledger advances; NO signal emissions
	# (add_gold self-suppresses gold_changed; try_award_floor_clear gates first_clear_awarded)
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(3000)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(3000)
	assert_int(economy._floor_clear_bonus_credited.get(3, -1)).is_equal(3000)
	assert_int(gold_emit_count[0]).is_equal(0)         # suppressed by add_gold's own guard
	assert_int(first_clear_emit_count[0]).is_equal(0)  # suppressed by offline-replay gate

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_offline_replay_flag_cleared_emits_normally() -> void:
	# Arrange — replay mode; credit floor 3; then clear flag and credit floor 4
	var economy: Node = EconomyScript.new()
	economy._is_offline_replay = true
	economy.try_award_floor_clear(3, 3000)  # silent credit during replay

	var first_clear_emissions: Array[int] = []
	economy.first_clear_awarded.connect(
		func(floor_index: int) -> void: first_clear_emissions.append(floor_index)
	)

	# Act — clear replay flag; credit a different floor; signal must fire normally
	economy._is_offline_replay = false
	var result: bool = economy.try_award_floor_clear(4, 2500)

	# Assert — true; first_clear_awarded fires with floor_index=4 (not 3 — already credited silently)
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(5500)  # 3000 + 2500
	assert_int(first_clear_emissions.size()).is_equal(1)
	assert_int(first_clear_emissions[0]).is_equal(4)

	# Cleanup
	economy.free()
