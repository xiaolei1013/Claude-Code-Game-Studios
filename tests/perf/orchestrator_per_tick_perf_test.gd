# Tests for dungeon-run-orchestrator/story-012 — per-tick performance budget.
# Covers TR-orchestrator-019 (`_on_tick_fired` p95 ≤ 2ms on dev hardware).
#
# Methodology:
#   - Fully-armed orchestrator in ACTIVE_FOREGROUND with run_snapshot +
#     combat_snapshot wired.
#   - Inject a fast no-op CombatResolver stub so the benchmark measures the
#     orchestrator's tick-handling overhead (cache lookups, signal dispatch,
#     state updates) WITHOUT also benchmarking the combat resolver itself.
#     The resolver is benchmarked separately by combat-resolution/story-010.
#   - Three benchmark configurations:
#       1. Steady-state: zero-kill ticks (the most common per-tick case)
#       2. Loaded: 5-kill ticks (heavy-kill burst — TR-019 edge case)
#       3. Mixed: alternating zero-kill / 5-kill ticks (realistic shape)
#   - 10_000 iterations per configuration; per-call timing via
#     `Time.get_ticks_usec()`; p50/p95/p99/max via nearest-rank percentile.
#   - Assertion: p95 ≤ 2_000 µs (2 ms) per TR-019.
#
# Mobile min-spec verification: this benchmark runs on dev hardware (Apple
# Silicon in CI). Mobile min-spec verification is captured manually in
# `production/qa/evidence/orchestrator-tick-perf-2026-05-08.md` per the
# story's Test Evidence requirement.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")
const CombatResolverScript = preload("res://src/core/combat/combat_resolver.gd")
const CombatTickEventsScript = preload("res://src/core/combat/combat_tick_events.gd")
const KillEventScript = preload("res://src/core/combat/kill_event.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")


# ---------------------------------------------------------------------------
# Constants — perf budget per TR-019
# ---------------------------------------------------------------------------

## p95 latency budget per TR-019 (2 ms on dev hardware).
const PERF_BUDGET_P95_US: int = 2_000

## Iteration count for percentile stability. The story's QA case specifies
## 10_000 calls. We sort and pick rank-based percentiles (no interpolation).
const ITERATION_COUNT: int = 10_000


# ---------------------------------------------------------------------------
# Stub combat resolver — controllable kill output per tick
# ---------------------------------------------------------------------------

## Fixed-output CombatResolver stub: returns the same CombatTickEvents object
## from every emit_events_in_range call. Returning a pre-allocated events
## object (rather than constructing per-call) keeps the resolver's overhead
## near-zero so the benchmark isolates orchestrator-side cost.
class _StubResolver extends CombatResolver:
	var fixed_events: CombatTickEvents = null

	func emit_events_in_range(_snapshot: CombatRunSnapshot, _tick_lo: int, _tick_hi: int) -> CombatTickEvents:
		return fixed_events


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _build_kill_events(kill_count: int) -> CombatTickEvents:
	var ev: CombatTickEvents = CombatTickEventsScript.new()
	# Typed Array[KillEvent] required by CombatTickEvents.kills field — generic
	# Array literal fails the runtime type check (project memory pattern
	# `project_typed_collection_test_fixtures`).
	var kills: Array[KillEvent] = []
	for i: int in range(kill_count):
		var ke: KillEvent = KillEventScript.new()
		ke.archetype = "bruiser"
		ke.tier = 1
		ke.is_boss = false
		kills.append(ke)
	ev.kills = kills
	ev.first_clear_in_range = false
	return ev


func _make_armed_orch(events_per_tick: CombatTickEvents) -> Node:
	var orch: Node = OrchestratorScript.new()
	# Inject the stub resolver via the public DI seam BEFORE add_child — orch's
	# _ready() lazy-defaults the resolver if no DI happened, so we must set it
	# before the autoload entry into the scene tree.
	var stub: _StubResolver = _StubResolver.new()
	stub.fixed_events = events_per_tick
	orch.set_combat_resolver(stub)
	add_child(orch)
	auto_free(orch)

	# Build run_snapshot + combat_snapshot. matchup_cache stays empty for the
	# perf benchmark — Story 010 covers the cache-populated case; here we
	# isolate the steady-state hot path.
	orch.run_snapshot = RunSnapshotScript.new()
	orch.run_snapshot.losing_run = false
	orch.run_snapshot.last_emitted_tick = 0
	orch.run_snapshot.current_tick = 0
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	orch._dispatched_floor_index = 1
	orch._dispatched_biome_id = "forest_reach"
	orch.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	return orch


## Runs ITERATION_COUNT consecutive _on_tick_fired calls and returns sorted
## per-call wall-clock samples (microseconds).
func _collect_samples_us(orch: Node) -> Array[int]:
	var samples: Array[int] = []
	# Pre-allocate slot for typed-int pushes.
	samples.resize(ITERATION_COUNT)
	for i: int in range(ITERATION_COUNT):
		# Tick numbers MUST be strictly increasing — orchestrator's TR-009
		# guard rejects duplicates and rewinds.
		var tick_n: int = i + 1
		var t0: int = Time.get_ticks_usec()
		orch._on_tick_fired(tick_n)
		var t1: int = Time.get_ticks_usec()
		samples[i] = t1 - t0
	samples.sort()
	return samples


func _percentile(sorted_samples: Array[int], pct: float) -> int:
	if sorted_samples.is_empty():
		return 0
	var rank: int = clampi(int(ceil(pct * float(sorted_samples.size()))) - 1, 0, sorted_samples.size() - 1)
	return sorted_samples[rank]


# ---------------------------------------------------------------------------
# Test 1 — TR-019: steady-state (0-kill ticks) p95 ≤ 2ms across 10_000 calls
# ---------------------------------------------------------------------------
func test_tr019_steady_state_zero_kill_ticks_p95_under_2ms() -> void:
	# Arrange — stub returns 0-kill events
	var orch: Node = _make_armed_orch(_build_kill_events(0))

	# Act
	var samples: Array[int] = _collect_samples_us(orch)

	# Assert
	var p95_us: int = _percentile(samples, 0.95)
	var max_us: int = samples[samples.size() - 1]
	assert_int(p95_us).is_less_equal(PERF_BUDGET_P95_US)

	# Print percentile summary for the evidence doc / CI log capture.
	print(
		"[Story 012 perf] steady-state 0-kill  N=%d  p50=%dµs  p95=%dµs  p99=%dµs  max=%dµs  budget=%dµs"
		% [
			ITERATION_COUNT,
			_percentile(samples, 0.50), p95_us, _percentile(samples, 0.99), max_us,
			PERF_BUDGET_P95_US,
		]
	)


# ---------------------------------------------------------------------------
# Test 2 — TR-019 edge case: 5-kill ticks p95 ≤ 2ms
#   The story's edge-case AC: "high-kill ticks (5+ kills in single tick) —
#   assert still under p95 bound".
# ---------------------------------------------------------------------------
func test_tr019_high_kill_burst_5_kills_per_tick_p95_under_2ms() -> void:
	# Arrange
	var orch: Node = _make_armed_orch(_build_kill_events(5))

	# Act
	var samples: Array[int] = _collect_samples_us(orch)

	# Assert
	var p95_us: int = _percentile(samples, 0.95)
	var max_us: int = samples[samples.size() - 1]
	assert_int(p95_us).is_less_equal(PERF_BUDGET_P95_US)

	print(
		"[Story 012 perf] burst 5-kill         N=%d  p50=%dµs  p95=%dµs  p99=%dµs  max=%dµs  budget=%dµs"
		% [
			ITERATION_COUNT,
			_percentile(samples, 0.50), p95_us, _percentile(samples, 0.99), max_us,
			PERF_BUDGET_P95_US,
		]
	)


# ---------------------------------------------------------------------------
# Test 3 — Mixed shape: alternating 0-kill / 5-kill (realistic per-run pattern)
# ---------------------------------------------------------------------------
func test_tr019_mixed_alternating_kill_ticks_p95_under_2ms() -> void:
	# Arrange — two alternating events; we re-point the stub mid-loop.
	var orch: Node = _make_armed_orch(_build_kill_events(0))
	var resolver_stub: _StubResolver = orch._combat_resolver
	var zero_kill: CombatTickEvents = _build_kill_events(0)
	var five_kill: CombatTickEvents = _build_kill_events(5)

	# Act — run loop manually so we can flip the stub's fixed_events between calls
	var samples: Array[int] = []
	samples.resize(ITERATION_COUNT)
	for i: int in range(ITERATION_COUNT):
		resolver_stub.fixed_events = (zero_kill if i % 2 == 0 else five_kill)
		var tick_n: int = i + 1
		var t0: int = Time.get_ticks_usec()
		orch._on_tick_fired(tick_n)
		var t1: int = Time.get_ticks_usec()
		samples[i] = t1 - t0
	samples.sort()

	# Assert
	var p95_us: int = _percentile(samples, 0.95)
	var max_us: int = samples[samples.size() - 1]
	assert_int(p95_us).is_less_equal(PERF_BUDGET_P95_US)

	print(
		"[Story 012 perf] mixed alternating    N=%d  p50=%dµs  p95=%dµs  p99=%dµs  max=%dµs  budget=%dµs"
		% [
			ITERATION_COUNT,
			_percentile(samples, 0.50), p95_us, _percentile(samples, 0.99), max_us,
			PERF_BUDGET_P95_US,
		]
	)


# ---------------------------------------------------------------------------
# Test 4 — mean ≤ 1ms (story QA secondary AC)
#   The story's QA Test Cases line says: "p95 ≤ 2ms; mean ≤ 1ms; max
#   documented (no hard cap on max — variance acceptable)". We assert the
#   mean against the mean ceiling here for the steady-state case.
# ---------------------------------------------------------------------------
func test_tr019_steady_state_mean_under_1ms() -> void:
	# Arrange
	var orch: Node = _make_armed_orch(_build_kill_events(0))

	# Act
	var samples: Array[int] = _collect_samples_us(orch)
	var sum_us: int = 0
	for s: int in samples:
		sum_us += s
	@warning_ignore("integer_division")
	var mean_us: int = sum_us / samples.size()

	# Assert — mean ≤ 1000 µs (1 ms)
	assert_int(mean_us).is_less_equal(1_000)
	print("[Story 012 perf] steady-state mean=%dµs (budget 1000µs)" % mean_us)
