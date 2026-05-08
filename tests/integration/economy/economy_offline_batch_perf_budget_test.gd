# Tests for Story 011 — compute_offline_batch perf budget < 500 ms (8h cap).
# Covers: AC H-10 (576_000-tick budget), per-tick avg < 0.87 μs, determinism
# preserved via Story 010 contract.
#
# Scope note: Story 010 implements the closed-form drip arm (single
# multiplication, O(1) in tick_budget). The kill-event and floor-clear arms
# are RunSnapshot-driven and are NOT wired in MVP scope (deferred to the
# OfflineProgressionEngine Feature epic). The H-10 perf budget is therefore
# trivially met by the closed-form scope — this test asserts that empirically
# and writes p50/p95/p99 numbers to the evidence doc per H-10 §Verification.
#
# When kill-event / floor-clear arms land, this test should be re-run; if
# any single 576_000-tick iteration exceeds 500 ms, adaptive chunking
# (await get_tree().process_frame, ADR-0014 §Decision) becomes a real
# requirement and Story 011's deferred ACs (2-4, 6) need follow-up work.
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")
const EconomyConfigScript = preload("res://src/core/economy/economy_config.gd")


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Per H-10: total wall-clock for the 576_000-tick budget MUST stay under
## 500 ms on minimum-spec hardware. We assert max-of-N < 500 ms (not just
## the average) per the AC.
const PERF_BUDGET_MS: int = 500

## 100 iterations per H-10 §Verification — yields p50/p95/p99 numbers.
const ITERATION_COUNT: int = 100

## 8h cap × 20 Hz = 576_000 ticks (default offline_cap_seconds × TICKS_PER_SECOND).
const FULL_BUDGET_TICKS: int = 576_000

## Per-tick average ceiling per H-10: 500 ms / 576_000 ticks ≈ 0.87 μs.
## Stored as nanoseconds for integer comparison without float precision loss.
const PER_TICK_AVG_NS_CEILING: int = 870


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Boots a fresh Economy with an injected EconomyConfig. Mirrors the helper
## in `economy_offline_batch_determinism_test.gd` so this perf test is
## isolated from DataRegistry boot.
func _make_economy() -> Node:
	var economy: Node = EconomyScript.new()
	var cfg: Resource = EconomyConfigScript.new()
	var base_drip: Array[int] = [2, 4, 7, 12, 8]
	cfg.BASE_DRIP = base_drip
	cfg.MATCHUP_DRIP_BONUS = 1.0
	economy._config = cfg
	economy.set_offline_replay_inputs(1.0, 2)  # floor 2, BASE_DRIP[1] = 4
	return economy


## Runs compute_offline_batch ITERATION_COUNT times and returns the per-iteration
## wall-clock samples (sorted ascending) for percentile reporting.
##
## Each iteration boots a fresh Economy to avoid state accumulation
## skewing later iterations (gold balance approaching GOLD_SANITY_CAP would
## change the clamp behavior of add_gold).
func _collect_samples_ms() -> Array[int]:
	var samples: Array[int] = []
	for i: int in ITERATION_COUNT:
		var economy: Node = _make_economy()
		var start_us: int = Time.get_ticks_usec()
		var _result: Object = economy.compute_offline_batch(FULL_BUDGET_TICKS)
		var elapsed_us: int = Time.get_ticks_usec() - start_us
		# Convert µs → ms with ceiling so a 500.5µs run reports 1ms (not 0).
		samples.append(int(ceil(float(elapsed_us) / 1000.0)))
		economy.free()
	samples.sort()
	return samples


## Computes a percentile from a sorted ascending samples array using the
## nearest-rank method (sufficient for p50/p95/p99 reporting at N=100).
func _percentile(sorted_samples: Array[int], pct: float) -> int:
	if sorted_samples.is_empty():
		return 0
	var rank: int = clampi(int(ceil(pct * float(sorted_samples.size()))) - 1, 0, sorted_samples.size() - 1)
	return sorted_samples[rank]


# ---------------------------------------------------------------------------
# Test 1 — AC H-10: 576_000-tick budget completes in < 500 ms across 100 runs
#   max-of-N < 500 ms (NOT just the average — H-10 explicit AC text).
# ---------------------------------------------------------------------------
func test_h10_576k_tick_budget_max_of_100_runs_under_500ms() -> void:
	# Arrange + Act
	var samples: Array[int] = _collect_samples_ms()

	# Assert — max wall-clock under PERF_BUDGET_MS
	var max_ms: int = samples[samples.size() - 1]
	assert_int(max_ms).is_less(PERF_BUDGET_MS)

	# Per-tick average ceiling: total_us / total_ticks < 0.87 µs
	# Use the median (samples[ITERATION_COUNT/2]) to avoid one-off jitter
	# inflating the per-tick ceiling spuriously.
	var p50_ms: int = _percentile(samples, 0.50)
	var p50_per_tick_ns: int = (p50_ms * 1_000_000) / FULL_BUDGET_TICKS
	assert_int(p50_per_tick_ns).is_less(PER_TICK_AVG_NS_CEILING)

	# Print percentile summary for the evidence doc / CI log capture.
	# (gdunit4 captures stdout; the evidence doc reader greps these lines.)
	print(
		"[Story 011 perf] N=%d FULL_BUDGET_TICKS=%d  p50=%dms  p95=%dms  p99=%dms  max=%dms  budget=%dms"
		% [
			ITERATION_COUNT, FULL_BUDGET_TICKS,
			_percentile(samples, 0.50),
			_percentile(samples, 0.95),
			_percentile(samples, 0.99),
			max_ms, PERF_BUDGET_MS,
		]
	)


# ---------------------------------------------------------------------------
# Test 2 — perf trend: smaller tick_budgets scale roughly proportionally.
#   Story 011 §Edge cases: "smaller tick_budgets (1000, 10_000, 100_000) also
#   profiled for trend confirmation". For closed-form O(1) drip, all three
#   should report under the budget by a wide margin.
# ---------------------------------------------------------------------------
func test_h10_smaller_tick_budgets_complete_well_under_budget() -> void:
	# Arrange — three smaller budgets
	var budgets: Array[int] = [1_000, 10_000, 100_000]
	for budget: int in budgets:
		# Act — single iteration (these are sanity smoke checks, not p99 runs)
		var economy: Node = _make_economy()
		var start_us: int = Time.get_ticks_usec()
		var _result: Object = economy.compute_offline_batch(budget)
		var elapsed_us: int = Time.get_ticks_usec() - start_us

		# Assert — closed-form O(1) means smaller budgets are equally fast
		var elapsed_ms: int = int(ceil(float(elapsed_us) / 1000.0))
		assert_int(elapsed_ms).is_less(PERF_BUDGET_MS)
		# Cleanup
		economy.free()


# ---------------------------------------------------------------------------
# Test 3 — Determinism contract preserved (cross-reference Story 010 AC H-09).
#   Story 011 §AC 5 requires that chunking does not break determinism. Since
#   MVP scope is unchunked closed-form, this test asserts that two runs with
#   identical inputs produce bit-exact identical OfflineResult fields — the
#   same property Story 010 already covers, re-asserted here for the
#   Story 011 evidence file's audit trail.
# ---------------------------------------------------------------------------
func test_h10_determinism_two_runs_with_identical_inputs_are_bit_exact() -> void:
	# Arrange — two fresh instances with identical inputs
	var economy_a: Node = _make_economy()
	var economy_b: Node = _make_economy()

	# Act
	var result_a: Object = economy_a.compute_offline_batch(FULL_BUDGET_TICKS)
	var result_b: Object = economy_b.compute_offline_batch(FULL_BUDGET_TICKS)

	# Assert — identical OfflineResult.total_gold + identical post-replay state
	assert_int(result_a.total_gold).is_equal(result_b.total_gold)
	assert_int(economy_a.get_gold_balance()).is_equal(economy_b.get_gold_balance())
	assert_int(economy_a.get_lifetime_gold_earned()).is_equal(economy_b.get_lifetime_gold_earned())
	assert_int(result_a.events_log.size()).is_equal(result_b.events_log.size())

	# Cleanup
	economy_a.free()
	economy_b.free()
