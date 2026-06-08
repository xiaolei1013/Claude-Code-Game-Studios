# Tests for S28-G1: foreground per-tick gold drip via the count-based segment model.
#
# Design invariant under test (Pillar-1 foreground/offline parity):
#   Σ over N foreground _on_tick() credits == floori(rate × N) == the offline
#   closed-form (compute_offline_batch) for identical inputs — BIT-EXACTLY.
#
# Why count-based, not a float accumulator: the offline path credits drip as ONE
# multiplication then floor — floori(rate × N). A float accumulator (Σ += rate)
# diverges because N additions ≠ 1 multiplication in IEEE-754 (6.4×10 ≠ 6.4+6.4+…).
# So _on_tick tracks an exact integer tick count per constant-rate segment and
# recomputes floori(rate × segment_ticks) each tick — the same expression offline
# uses, so parity is exact. On floor/rate change the segment is banked
# (_fg_drip_segment_base += the segment's total) and the counter restarts.
#
# DI strategy:
#   - Economy.new() + _config injected directly (skips DataRegistry).
#   - The REAL _on_tick is driven via the test seam set_foreground_drip_inputs_for_test
#     (floor + strength), so the actual SUT accumulate path runs without live
#     DungeonRunOrchestrator / HeroRoster autoloads. The offline path uses its
#     existing set_offline_replay_inputs(fs, fi) seam.
#   - Parity tests compare _drive_fg_drip_ticks() (drives real _on_tick N times)
#     against compute_offline_batch(N) for identical inputs.
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")
const EconomyConfigScript = preload("res://src/core/economy/economy_config.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Builds a fresh Economy with an injected EconomyConfig. Bypasses DataRegistry.
func _make_economy(base_drip: Array[int], matchup_drip_bonus: float = 1.0) -> Node:
	var economy: Node = EconomyScript.new()
	var cfg: Resource = EconomyConfigScript.new()
	cfg.BASE_DRIP = base_drip
	cfg.MATCHUP_DRIP_BONUS = matchup_drip_bonus
	economy._config = cfg
	return economy


## Drives the REAL Economy._on_tick() N times via the test DI seam
## (set_foreground_drip_inputs_for_test), so the actual SUT accumulate-credit
## path — including the floor-init reset on the first tick — is exercised end to
## end, NOT a re-implementation. Returns total gold credited across N ticks.
func _drive_fg_drip_ticks(economy: Node, floor_index: int, formation_strength: float, n: int) -> int:
	economy.set_foreground_drip_inputs_for_test(floor_index, formation_strength)
	var balance_before: int = economy.get_gold_balance()
	for i: int in range(n):
		economy._on_tick(i + 1)
	return economy.get_gold_balance() - balance_before


# ---------------------------------------------------------------------------
# Test 1 — PARITY (load-bearing): foreground accumulator == offline closed-form
#
# For identical inputs (floor, formation_strength, N), the foreground
# accumulator loop and compute_offline_batch(N) must produce the SAME gold.
# Tested with three N values and a fractional rate (BASE_DRIP=4, FS=1.6 →
# rate=6.4, mirroring the GDD §D.1 worked example).
# ---------------------------------------------------------------------------
func test_parity_foreground_accumulator_equals_offline_closed_form_fractional_rate() -> void:
	# Arrange — floor 2, BASE_DRIP[1]=4, FS=1.6, matchup=1.0 → rate=6.4
	var base_drip: Array[int] = [2, 4, 7, 12, 8]
	var fs: float = 1.6
	var matchup: float = 1.0
	var floor_index: int = 2

	# N spans 1 tick → a large run; large N proves the fractional-carry drift
	# (floori(6.4×100000)=640000 vs naive 6×100000=600000) stays in lockstep
	# with the offline closed-form. Driven through the REAL _on_tick.
	for n: int in [1, 10, 100_000]:
		var offline_economy: Node = _make_economy(base_drip, matchup)
		offline_economy.set_offline_replay_inputs(fs, floor_index)
		var offline_result: Object = offline_economy.compute_offline_batch(n)
		var offline_gold: int = offline_result.total_gold

		var fg_economy: Node = _make_economy(base_drip, matchup)
		var fg_gold: int = _drive_fg_drip_ticks(fg_economy, floor_index, fs, n)

		# The parity assertion — this is the load-bearing test for Pillar 1.
		assert_int(fg_gold).is_equal(offline_gold)

		offline_economy.free()
		fg_economy.free()


# ---------------------------------------------------------------------------
# Test 2 — PARITY (additional rates): integer rate and another fractional rate
# ---------------------------------------------------------------------------
func test_parity_foreground_accumulator_equals_offline_closed_form_integer_rate() -> void:
	# floor 1, BASE_DRIP=2, FS=1.0 → rate=2.0 (integer — no fractional carry)
	var base_drip: Array[int] = [2, 4, 7, 12, 8]
	for n: int in [1, 100, 100_000]:
		var offline_economy: Node = _make_economy(base_drip, 1.0)
		offline_economy.set_offline_replay_inputs(1.0, 1)
		var offline_gold: int = offline_economy.compute_offline_batch(n).total_gold

		var fg_economy: Node = _make_economy(base_drip, 1.0)
		var fg_gold: int = _drive_fg_drip_ticks(fg_economy, 1, 1.0, n)

		assert_int(fg_gold).is_equal(offline_gold)

		offline_economy.free()
		fg_economy.free()


# ---------------------------------------------------------------------------
# Test 3 — Accumulator integer-delta carry
#
# rate = 6.4 (BASE_DRIP=4, FS=1.6). Verify credit schedule:
#   tick 1: accum=6.4 → whole=6 → delta=6 → total=6
#   tick 2: accum=12.8 → whole=12 → delta=6 → total=12  (NOT 13; 12.8 truncates)
#   tick 10: accum=64.0 → whole=64 → total=64           (NOT 60 = 6×10)
# ---------------------------------------------------------------------------
func test_accumulator_integer_delta_carry_with_rate_6_4() -> void:
	# Arrange — floor 2, FS=1.6, matchup=1.0 → rate 4*1.6*1.0 = 6.4.
	# Drive the REAL _on_tick via the DI seam (no hand-rolled loop).
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	economy.set_foreground_drip_inputs_for_test(2, 1.6)

	# Tick 1: accum 6.4 → whole 6 → credit 6
	economy._on_tick(1)
	assert_int(economy.get_gold_balance()).is_equal(6)

	# Tick 2: accum 12.8 → whole 12 → credit +6 → total 12 (NOT 13; 12.8 truncates)
	economy._on_tick(2)
	assert_int(economy.get_gold_balance()).is_equal(12)

	# Ticks 3..10
	for i: int in range(3, 11):
		economy._on_tick(i)
	# After 10 ticks: floori(6.4×10) = floori(64.0) = 64, NOT 60 (6×10 naive).
	assert_int(economy.get_gold_balance()).is_equal(64)
	assert_int(economy._fg_drip_credited).is_equal(64)

	economy.free()


# ---------------------------------------------------------------------------
# Test 4 — NO_RUN gating: _on_tick with no active run → zero drip
#
# Without a live orchestrator, get_node_or_null returns null → active_floor=0
# → _on_tick returns early without touching add_gold. We verify the accumulator
# state stays at 0 after calling _on_tick directly.
# ---------------------------------------------------------------------------
func test_no_run_gating_on_tick_with_no_orchestrator_produces_zero_drip() -> void:
	# Arrange — Economy without an active run (no orchestrator in unit test env)
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	var gold_before: int = economy.get_gold_balance()

	# Act — call _on_tick(1) directly; get_node_or_null("/root/DungeonRunOrchestrator")
	# returns null in a headless unit test → active_floor=0 → early return.
	economy._on_tick(1)
	economy._on_tick(2)
	economy._on_tick(3)

	# Assert — no gold credited; segment counter never advanced (early return).
	assert_int(economy.get_gold_balance()).is_equal(gold_before)
	assert_int(economy._fg_drip_segment_ticks).is_equal(0)
	assert_int(economy._fg_drip_credited).is_equal(0)

	economy.free()


# ---------------------------------------------------------------------------
# Test 5 — Empty formation (formation_strength == 0.0) → zero drip
#
# _drip_rate_per_tick returns 0.0 when formation_strength <= 0.0.
# We test this via the internal rate helper directly.
# ---------------------------------------------------------------------------
func test_empty_formation_zero_strength_produces_zero_drip_rate() -> void:
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)

	# _drip_rate_per_tick with formation_strength=0.0 → 0.0
	var rate: float = economy._drip_rate_per_tick(1, 0.0)
	assert_float(rate).is_equal(0.0)

	# Also verify 1.0 FS returns the expected rate for sanity.
	var rate_nominal: float = economy._drip_rate_per_tick(1, 1.0)
	assert_float(rate_nominal).is_equal(2.0)  # BASE_DRIP[0]=2, FS=1.0, matchup=1.0

	economy.free()


# ---------------------------------------------------------------------------
# Test 6 — Reset on run boundary / floor change
#
# Simulate: floor A for 3 ticks → then floor B for 3 ticks.
# The accumulator must reset on floor change; no cross-run fraction bleeds.
# ---------------------------------------------------------------------------
func test_accumulator_resets_on_floor_change_no_cross_floor_bleed() -> void:
	# Drive the REAL _on_tick across a floor change so the SUT's own
	# floor-change reset branch (active_floor != _fg_drip_active_floor) is what
	# clears the accumulator — not a hand-rolled reset in the test.
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)

	# --- Floor 2 (rate 4*1.6=6.4) — 3 ticks ---
	economy.set_foreground_drip_inputs_for_test(2, 1.6)
	for i: int in range(1, 4):
		economy._on_tick(i)
	# After 3 ticks: floori(6.4*3)=floori(19.2)=19. Segment: 3 ticks on floor 2.
	assert_int(economy.get_gold_balance()).is_equal(19)
	assert_int(economy._fg_drip_segment_ticks).is_equal(3)
	assert_int(economy._fg_drip_credited).is_equal(19)
	assert_int(economy._fg_drip_active_floor).is_equal(2)

	# --- Floor 4 (rate 12*1.0=12.0) — change the active floor. The REAL _on_tick
	# must detect the change, bank the segment (base=19) and start a fresh
	# segment counter — no cross-floor fractional bleed. ---
	economy.set_foreground_drip_inputs_for_test(4, 1.0)
	for i: int in range(4, 7):
		economy._on_tick(i)
	# Floor 4 segment: floori(12*3)=36. Cumulative run total: 19 + 36 = 55.
	assert_int(economy.get_gold_balance()).is_equal(55)
	assert_int(economy._fg_drip_credited).is_equal(55)        # cumulative across run
	assert_int(economy._fg_drip_segment_base).is_equal(19)    # floor 2's total, banked
	assert_int(economy._fg_drip_segment_ticks).is_equal(3)    # floor 4 segment fresh
	assert_int(economy._fg_drip_active_floor).is_equal(4)

	economy.free()


# ---------------------------------------------------------------------------
# Test 7 — Offline-replay guard: _is_offline_replay=true → _on_tick is no-op
# ---------------------------------------------------------------------------
func test_offline_replay_guard_on_tick_is_noop_when_replay_active() -> void:
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)

	# Active-run inputs ARE set (floor 1, full strength), but a replay is in
	# progress → _on_tick must short-circuit and never credit foreground drip.
	economy.set_foreground_drip_inputs_for_test(1, 1.0)
	economy._is_offline_replay = true
	var gold_before: int = economy.get_gold_balance()

	economy._on_tick(1)
	economy._on_tick(2)

	# No gold credited; the segment counter never advanced (early return).
	assert_int(economy.get_gold_balance()).is_equal(gold_before)
	assert_int(economy._fg_drip_segment_ticks).is_equal(0)

	# Cleanup.
	economy._is_offline_replay = false
	economy.free()


# ---------------------------------------------------------------------------
# Test 8 — _drip_rate_per_tick: out-of-range floor_index returns 0.0
# ---------------------------------------------------------------------------
func test_drip_rate_per_tick_out_of_range_floor_returns_zero() -> void:
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)

	assert_float(economy._drip_rate_per_tick(0, 1.0)).is_equal(0.0)  # floor 0 invalid
	assert_float(economy._drip_rate_per_tick(6, 1.0)).is_equal(0.0)  # floor 6 > size 5
	assert_float(economy._drip_rate_per_tick(-1, 1.0)).is_equal(0.0)  # negative

	economy.free()


# ---------------------------------------------------------------------------
# Test 9 — _drip_rate_per_tick: null config returns 0.0
# ---------------------------------------------------------------------------
func test_drip_rate_per_tick_null_config_returns_zero() -> void:
	var economy: Node = EconomyScript.new()
	# _config is null (no injection)
	assert_float(economy._drip_rate_per_tick(1, 1.0)).is_equal(0.0)
	economy.free()


# ---------------------------------------------------------------------------
# Test 10 — add_gold signature unchanged: no reason param
#
# Verifies that add_gold still accepts exactly (amount: int) without a reason
# param. This guards against the forbidden-pattern of adding a reason param
# (noted in the task brief as a caller-audit risk).
# ---------------------------------------------------------------------------
func test_add_gold_signature_unchanged_single_param_no_reason() -> void:
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	# If the signature changed to require reason, this call would error.
	economy.add_gold(100)
	assert_int(economy.get_gold_balance()).is_equal(100)
	economy.free()


# ---------------------------------------------------------------------------
# Test 11 — PARITY: large N (8h offline cap) with non-integer rate
#
# rate = 7 * 1.5 * 1.0 = 10.5 (floor 3, FS=1.5, matchup=1.0).
# Over 576_000 ticks: offline = floori(10.5 * 576_000) = 6_048_000.
# Foreground accumulator must match exactly.
# ---------------------------------------------------------------------------
func test_parity_large_n_8h_cap_non_integer_rate() -> void:
	var base_drip: Array[int] = [2, 4, 7, 12, 8]
	var fs: float = 1.5
	var matchup: float = 1.0
	var n: int = 576_000
	var floor_index: int = 3  # BASE_DRIP[2]=7 → rate=7*1.5*1.0=10.5

	var offline_economy: Node = _make_economy(base_drip, matchup)
	offline_economy.set_offline_replay_inputs(fs, floor_index)
	var offline_gold: int = offline_economy.compute_offline_batch(n).total_gold

	var fg_economy: Node = _make_economy(base_drip, matchup)
	var fg_gold: int = _drive_fg_drip_ticks(fg_economy, floor_index, fs, n)

	assert_int(fg_gold).is_equal(offline_gold)

	offline_economy.free()
	fg_economy.free()


# ---------------------------------------------------------------------------
# Test 12 — PARITY: matchup_drip_bonus != 1.0
#
# rate = 4 * 1.0 * 1.2 = 4.8 (floor 2, FS=1.0, matchup=1.2).
# Fractional carry: ticks 1-4 = 4,9,14,19 (floor 4.8). tick 5 = floori(24.0)=24.
# ---------------------------------------------------------------------------
func test_parity_matchup_drip_bonus_applied_correctly() -> void:
	var base_drip: Array[int] = [2, 4, 7, 12, 8]
	var fs: float = 1.0
	var matchup: float = 1.2
	var floor_index: int = 2  # BASE_DRIP[1]=4 → rate=4*1.0*1.2=4.8

	# (Test 11 already drives the full 576k 8h-cap parity; here a 10k large-N
	# is enough to prove the matchup-bonus fractional carry stays in lockstep.)
	for n: int in [1, 5, 100, 10_000]:
		var offline_economy: Node = _make_economy(base_drip, matchup)
		offline_economy.set_offline_replay_inputs(fs, floor_index)
		var offline_gold: int = offline_economy.compute_offline_batch(n).total_gold

		var fg_economy: Node = _make_economy(base_drip, matchup)
		var fg_gold: int = _drive_fg_drip_ticks(fg_economy, floor_index, fs, n)

		assert_int(fg_gold).is_equal(offline_gold)

		offline_economy.free()
		fg_economy.free()
