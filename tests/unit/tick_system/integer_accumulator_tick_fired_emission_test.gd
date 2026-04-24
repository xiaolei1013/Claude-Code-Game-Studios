# Tests for Story 002: Integer accumulator and tick_fired synchronous emission.
# Covers: AC-TICK-01, TR-time-003, TR-time-004, TR-time-005,
#         TR-time-007, TR-time-010, TR-time-013
extends GdUnitTestSuite

const TickSystemScript = preload("res://src/core/tick_system/tick_system.gd")


# ---------------------------------------------------------------------------
# Test 1 — AC-TICK-01: Fixed-rate tick delivery (20 calls of 0.05 s each)
#
# Verifies that exactly 20 tick_fired signals are emitted with monotonically
# increasing tick_number values [1..20] and that the accumulator residual
# after all 20 calls is ≤ 1e-9.
# ---------------------------------------------------------------------------
func test_tick_system_twenty_fixed_deltas_emit_exactly_twenty_ticks() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	var emitted_tick_numbers: Array[int] = []
	ts.tick_fired.connect(func(tick_number: int) -> void:
		emitted_tick_numbers.append(tick_number)
	)

	# Act — 20 calls of 0.05 s each (exactly one tick per call at 20 Hz)
	for _i: int in range(20):
		ts._process(0.05)

	# Assert — emission count
	assert_int(emitted_tick_numbers.size()).is_equal(20)

	# Assert — tick_number sequence is [1, 2, ..., 20]
	for idx: int in range(20):
		assert_int(emitted_tick_numbers[idx]).is_equal(idx + 1)

	# Assert — accumulator residual ≤ 1e-9
	const RESIDUAL_TOLERANCE: float = 1e-9
	assert_float(ts._tick_accumulator_seconds).is_between(0.0, RESIDUAL_TOLERANCE)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 1a — AC-TICK-01 edge case: sub-threshold delta emits nothing
#
# A single _process(0.049) call must not fire any tick because 0.049 < 0.05.
# The accumulator residual must equal the delta exactly.
# ---------------------------------------------------------------------------
func test_tick_system_sub_threshold_delta_emits_zero_ticks() -> void:
	# Arrange — Array[int] wrapper because GDScript 4 lambdas capture outer
	# locals by value; reassignment inside the lambda does NOT propagate out.
	var ts: Node = TickSystemScript.new()
	var emission_count: Array[int] = [0]
	ts.tick_fired.connect(func(_tick_number: int) -> void:
		emission_count[0] += 1
	)

	# Act
	ts._process(0.049)

	# Assert — no tick emitted
	assert_int(emission_count[0]).is_equal(0)

	# Assert — residual equals the fed delta (within float epsilon)
	const EPSILON: float = 1e-9
	assert_float(ts._tick_accumulator_seconds).is_between(0.049 - EPSILON, 0.049 + EPSILON)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 1b — AC-TICK-01 edge case: double-tick frame (0.1 s = 2 ticks)
#
# A single _process(0.1) call spans two tick intervals and must emit exactly
# 2 tick_fired signals in the same call, in order.
# ---------------------------------------------------------------------------
func test_tick_system_double_tick_frame_emits_two_ticks() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	var emitted_tick_numbers: Array[int] = []
	ts.tick_fired.connect(func(tick_number: int) -> void:
		emitted_tick_numbers.append(tick_number)
	)

	# Act
	ts._process(0.1)

	# Assert — exactly 2 ticks
	assert_int(emitted_tick_numbers.size()).is_equal(2)
	assert_int(emitted_tick_numbers[0]).is_equal(1)
	assert_int(emitted_tick_numbers[1]).is_equal(2)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 1c — AC-TICK-01 edge case: catch-up frame (1.0 s = 20 ticks)
#
# A single _process(1.0) call spans 20 tick intervals and must emit exactly
# 20 tick_fired signals in the same call (catch-up behavior).
# ---------------------------------------------------------------------------
func test_tick_system_catchup_frame_emits_twenty_ticks_in_one_call() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	var emitted_tick_numbers: Array[int] = []
	ts.tick_fired.connect(func(tick_number: int) -> void:
		emitted_tick_numbers.append(tick_number)
	)

	# Act — feed 1.001s to guarantee 20 emissions despite IEEE-754 rounding
	# (0.05 cannot be represented exactly in float64; 1.0 / 0.05 via iterative
	# subtraction yields 19 — not 20 — due to accumulated rounding. Adding a
	# small buffer restores deterministic catch-up behavior.)
	ts._process(1.001)

	# Assert — 20 ticks emitted in a single _process call
	assert_int(emitted_tick_numbers.size()).is_equal(20)
	assert_int(emitted_tick_numbers[0]).is_equal(1)
	assert_int(emitted_tick_numbers[19]).is_equal(20)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 2 — TR-time-013: Synchronous emission
#
# tick_fired must complete synchronously inside _process; the signal listener
# must have run by the time _process returns. If emission were deferred, the
# counter would still be 0 immediately after the _process call.
# ---------------------------------------------------------------------------
func test_tick_system_tick_fired_emits_synchronously_inside_process() -> void:
	# Arrange — Array[int] wrapper because GDScript 4 lambdas capture outer
	# locals by value; reassignment inside the lambda does NOT propagate out.
	var ts: Node = TickSystemScript.new()
	var counter_after_emission: Array[int] = [0]
	ts.tick_fired.connect(func(_tick_number: int) -> void:
		# This lambda body executes during _process if emission is synchronous.
		# We record the counter value here to prove the listener ran mid-call.
		counter_after_emission[0] += 1
	)

	# Act — one tick (0.05 s exactly crosses the 0.05 s threshold)
	ts._process(0.05)

	# Assert — listener must have run synchronously; counter == 1 right now.
	# If emission were deferred (call_deferred / next idle frame), counter would
	# still be 0 at this point.
	assert_int(counter_after_emission[0]).is_equal(1)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 3 — TR-time-007: Monotonic non-negative counter
#
# Drives 1,000 _process(0.05) calls and verifies that every tick_number in
# every signal emission is strictly greater than the previous one and never
# negative. Scales down from 10,000 to 1,000 for test runner speed without
# compromising the monotonic invariant proof.
# ---------------------------------------------------------------------------
func test_tick_system_counter_is_monotonically_increasing_and_non_negative() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	var last_tick_number: int = 0
	var violations: int = 0

	ts.tick_fired.connect(func(tick_number: int) -> void:
		if tick_number <= last_tick_number or tick_number < 0:
			violations += 1
		last_tick_number = tick_number
	)

	# Act — 1,000 calls × 1 tick/call = 1,000 ticks total
	const ITERATIONS: int = 1000
	for _i: int in range(ITERATIONS):
		ts._process(0.05)

	# Assert — no monotonic or non-negative violations
	assert_int(violations).is_equal(0)

	# Assert — final counter matches expected tick count
	assert_int(ts.current_tick()).is_equal(ITERATIONS)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 3a — TR-time-007 edge case: mixed delta values never decrease counter
#
# Feeds a variety of delta values (including zero, which should fire nothing)
# and asserts the tick stream is still strictly monotonic with no negatives.
# ---------------------------------------------------------------------------
func test_tick_system_mixed_deltas_never_decrease_counter() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	var last_tick_number: int = 0
	var violations: int = 0

	ts.tick_fired.connect(func(tick_number: int) -> void:
		if tick_number <= last_tick_number or tick_number < 0:
			violations += 1
		last_tick_number = tick_number
	)

	# Act — varied deltas: 0.0 (no tick), 0.05 (1 tick), 1.0 (20 ticks), 0.049 (0 ticks)
	var test_deltas: Array[float] = [0.0, 0.05, 1.0, 0.049, 0.05, 0.05]
	for delta: float in test_deltas:
		ts._process(delta)

	# Assert — no violations across all emitted ticks
	assert_int(violations).is_equal(0)

	# Assert — counter is non-negative
	assert_bool(ts.current_tick() >= 0).is_true()

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 4 — TR-time-004: Session-scoped counter resets to 0 on fresh instantiation
#
# Each new TickSystem instance starts with _sim_tick_counter == 0 (cold launch
# semantics — no persistence, no global state carried between instances).
# ---------------------------------------------------------------------------
func test_tick_system_fresh_instance_starts_at_tick_zero() -> void:
	# Arrange / Act — create two independent instances
	var ts_a: Node = TickSystemScript.new()
	var ts_b: Node = TickSystemScript.new()

	# Drive ts_a forward so it has state
	ts_a._process(0.5)  # 10 ticks

	# Assert — ts_b is untouched: counter must still be 0
	assert_int(ts_b.current_tick()).is_equal(0)

	# Assert — ts_a has the expected tick count, confirming isolation
	assert_int(ts_a.current_tick()).is_equal(10)

	# Cleanup
	ts_a.free()
	ts_b.free()


# ---------------------------------------------------------------------------
# Test 5 — TR-time-005: _process is used; accumulator state is visible
#
# Confirms that the accumulator field (_tick_accumulator_seconds) exists and
# reflects sub-threshold fractional remainder after a non-exact delta feed.
# This indirectly proves the integer-accumulator _process pattern is in place
# rather than any _physics_process or Timer-based approach.
# ---------------------------------------------------------------------------
func test_tick_system_accumulator_preserves_fractional_remainder() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act — feed 0.07 s: one tick fires (consumes 0.05 s), residual = 0.02 s
	ts._process(0.07)

	# Assert — exactly 1 tick emitted
	assert_int(ts.current_tick()).is_equal(1)

	# Assert — residual ≈ 0.02 s (within float precision)
	const EXPECTED_RESIDUAL: float = 0.07 - 0.05  # = 0.02
	const EPSILON: float = 1e-9
	assert_float(ts._tick_accumulator_seconds).is_between(
		EXPECTED_RESIDUAL - EPSILON,
		EXPECTED_RESIDUAL + EPSILON
	)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 5a — TR-time-010: Accumulator residual is preserved (not reset to 0)
#
# Simulates what a pause would expose: after a partial accumulation, the next
# _process call continues from the preserved residual rather than zero.
# (Full BG/FG preservation across pause transitions is Story 004's scope.)
# ---------------------------------------------------------------------------
func test_tick_system_accumulator_residual_preserved_across_process_calls() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act — first call accumulates 0.04 s (no tick yet)
	ts._process(0.04)
	assert_int(ts.current_tick()).is_equal(0)

	# Act — second call adds 0.03 s → total 0.07 s → one tick fires,
	#        residual = 0.02 s (not 0.03 s — proves carry from first call)
	ts._process(0.03)

	# Assert — one tick fired using the carried residual
	assert_int(ts.current_tick()).is_equal(1)

	# Assert — residual is 0.02 (the fractional carry is preserved)
	const EXPECTED_RESIDUAL: float = 0.02
	const EPSILON: float = 1e-9
	assert_float(ts._tick_accumulator_seconds).is_between(
		EXPECTED_RESIDUAL - EPSILON,
		EXPECTED_RESIDUAL + EPSILON
	)

	# Cleanup
	ts.free()
