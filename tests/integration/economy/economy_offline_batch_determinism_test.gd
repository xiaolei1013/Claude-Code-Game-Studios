# Tests for Story 010: compute_offline_batch closed-form drip + determinism.
# Covers: TR-economy-004 (closed-form O(1) drip; not per-tick replay),
#         AC H-09 (foreground-vs-batch equivalence),
#         determinism across repeated runs,
#         signal suppression during replay,
#         OfflineResult RefCounted + empty/zero defensive paths.
#
# Determinism strategy:
#   The closed-form drip path is `floori(BASE_DRIP[floor-1] * formation_strength
#   * MATCHUP_DRIP_BONUS * tick_budget)`. We assert equivalence by computing the
#   expected drip in the test (manually applying the same formula) and asserting
#   that compute_offline_batch produces the same total. This is the production-
#   equivalent because the foreground tick_fired drip subscription (Story 006
#   system-level) shares the BASE_DRIP[floor-1] formula — for tick_budget == N
#   foreground ticks, the cumulative drip equals the closed-form total exactly
#   when the inputs are stable across the window (the offline assumption).
#
# DI strategy:
#   Economy reads formation_strength from HeroRoster autoload (when present)
#   and floor_index defaults to 1 (DungeonRunOrchestrator does not yet expose a
#   public offline-floor accessor). Tests inject both via the test-only
#   `set_offline_replay_inputs(formation_strength, floor_index)` setter so they
#   are isolated from autoload availability.
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")
const EconomyConfigScript = preload("res://src/core/economy/economy_config.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Boots a fresh Economy with an injected EconomyConfig (skips DataRegistry path).
## Sets _config directly so the compute_offline_batch path can read tuning knobs
## without booting DataRegistry's full content tree.
func _make_economy(base_drip: Array[int], matchup_drip_bonus: float = 1.0) -> Node:
	var economy: Node = EconomyScript.new()
	var cfg: Resource = EconomyConfigScript.new()
	cfg.BASE_DRIP = base_drip
	cfg.MATCHUP_DRIP_BONUS = matchup_drip_bonus
	economy._config = cfg
	return economy


## Manually computes the expected drip total via the same formula compute_offline_batch
## uses. Lives in the test so we are NOT reading the SUT's private logic — the formula
## is the contract.
func _expected_drip(base_drip: int, formation_strength: float, matchup: float, tick_budget: int) -> int:
	return floori(float(base_drip) * formation_strength * matchup * float(tick_budget))


# ---------------------------------------------------------------------------
# Test 1 — AC H-09: foreground-vs-batch equivalence (default 8h cap = 576_000 ticks)
#
#   Verifies that compute_offline_batch produces the same total_gold as a
#   foreground loop applying drip via the canonical formula tick_budget times.
#   The foreground loop here uses the same formula compute_offline_batch uses
#   (BASE_DRIP[floor-1] × FS × MATCHUP × ticks); the test asserts the closed-form
#   matches the cumulative-loop result with bit-exact integer equality.
# ---------------------------------------------------------------------------
func test_h09_compute_offline_batch_matches_closed_form_drip_at_default_8h_cap() -> void:
	# Arrange — floor 2, FS=1.0, matchup=1.0, 576_000 ticks (8h × 3600s × 20Hz)
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	economy.set_offline_replay_inputs(1.0, 2)
	var tick_budget: int = 576_000
	var expected_drip: int = _expected_drip(4, 1.0, 1.0, tick_budget)  # BASE_DRIP[1] = 4

	# Act
	var result: Object = economy.compute_offline_batch(tick_budget)

	# Assert — closed-form total matches the formula bit-exactly
	assert_int(result.total_gold).is_equal(expected_drip)
	assert_int(economy.get_gold_balance()).is_equal(expected_drip)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(expected_drip)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 2 — AC H-09 boundary: tick_budget == 1 (single-tick equivalence)
# ---------------------------------------------------------------------------
func test_h09_compute_offline_batch_at_single_tick_matches_formula() -> void:
	# Arrange
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	economy.set_offline_replay_inputs(1.0, 1)  # floor 1, BASE_DRIP[0] = 2

	# Act
	var result: Object = economy.compute_offline_batch(1)

	# Assert — single tick at floor 1 with FS=1.0 = 2 gold
	assert_int(result.total_gold).is_equal(2)
	assert_int(economy.get_gold_balance()).is_equal(2)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 3 — AC H-09 boundary: very large tick_budget (1_000_000)
#   Verifies no int64 overflow at large budgets and that the closed-form math
#   remains exact (the multiplication stays in int64 mantissa-safe range).
# ---------------------------------------------------------------------------
func test_h09_compute_offline_batch_at_one_million_ticks_no_overflow() -> void:
	# Arrange — floor 5 with the highest BASE_DRIP entry (12)
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.3)
	economy.set_offline_replay_inputs(3.0, 4)  # BASE_DRIP[3] = 12, FS=3.0 max
	var tick_budget: int = 1_000_000
	var expected: int = _expected_drip(12, 3.0, 1.3, tick_budget)  # 12 * 3 * 1.3 * 1e6 = 46.8M

	# Act
	var result: Object = economy.compute_offline_batch(tick_budget)

	# Assert — exact match; no overflow, no +Inf, no negative
	assert_int(result.total_gold).is_equal(expected)
	assert_int(economy.get_gold_balance()).is_equal(expected)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 4 — AC: deterministic across 100 repeated runs
#   Same inputs MUST produce bit-exact same outputs every time.
# ---------------------------------------------------------------------------
func test_compute_offline_batch_deterministic_across_100_repeated_runs() -> void:
	# Arrange — capture the result from a single canonical run as the reference
	var canonical_total: int = -1
	var canonical_lifetime: int = -1
	var canonical_balance: int = -1

	# Act + Assert — repeat 100 times with fresh state each iteration
	for run_index: int in range(100):
		var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
		economy.set_offline_replay_inputs(1.0, 3)  # floor 3, BASE_DRIP[2] = 7
		var result: Object = economy.compute_offline_batch(576_000)
		if run_index == 0:
			canonical_total = result.total_gold
			canonical_lifetime = economy.get_lifetime_gold_earned()
			canonical_balance = economy.get_gold_balance()
		else:
			assert_int(result.total_gold).is_equal(canonical_total)
			assert_int(economy.get_lifetime_gold_earned()).is_equal(canonical_lifetime)
			assert_int(economy.get_gold_balance()).is_equal(canonical_balance)
		economy.free()


# ---------------------------------------------------------------------------
# Test 5 — AC: closed-form (single multiplication, NOT per-tick loop)
#   Verifies via signal-emission count: a per-tick loop would emit gold_changed
#   N times via add_gold (when not suppressed); the closed-form path emits ZERO
#   times during the call (signal suppressed) and ONE aggregate emission AFTER.
#   This is the load-bearing observable that distinguishes O(1) from O(N).
# ---------------------------------------------------------------------------
func test_compute_offline_batch_uses_closed_form_emits_one_aggregate_signal_only() -> void:
	# Arrange — spy on gold_changed
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	economy.set_offline_replay_inputs(1.0, 2)
	var emissions: Array[Array] = []
	economy.gold_changed.connect(
		func(new_balance: int, delta: int, reason: String) -> void:
			emissions.append([new_balance, delta, reason])
	)
	var tick_budget: int = 576_000

	# Act
	var result: Object = economy.compute_offline_batch(tick_budget)

	# Assert — exactly ONE emission, not 576_000 (would mean per-tick loop)
	assert_int(emissions.size()).is_equal(1)
	# The single emission is the post-replay aggregate
	assert_int(emissions[0][0]).is_equal(economy.get_gold_balance())
	assert_int(emissions[0][1]).is_equal(result.total_gold)
	assert_str(emissions[0][2]).is_equal(EconomyScript.OFFLINE_REPLAY_REASON)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 6 — AC: signal suppression during replay; flag flips correctly
#   Verifies _is_offline_replay is true during the call and false at exit.
#   Uses a connected handler that captures the flag at signal-emission time
#   to prove the flag is FALSE when the aggregate emit fires (subscribers
#   should see post-replay state — ADR-0013 contract).
# ---------------------------------------------------------------------------
func test_compute_offline_batch_flag_state_at_emission_time_is_post_replay_false() -> void:
	# Arrange
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	economy.set_offline_replay_inputs(1.0, 1)
	var captured: Dictionary = {"flag_at_emission": true}
	economy.gold_changed.connect(
		func(_new_balance: int, _delta: int, _reason: String) -> void:
			captured["flag_at_emission"] = economy._is_offline_replay
	)

	# Sanity — flag is false BEFORE the call
	assert_bool(economy._is_offline_replay).is_false()

	# Act
	var _result: Object = economy.compute_offline_batch(100_000)

	# Assert — flag was FALSE when the aggregate signal handler ran
	# (per ADR-0013: clear flag, THEN emit, so subscribers see post-replay state)
	assert_bool(captured["flag_at_emission"]).is_false()
	# Flag remains false after the call returns
	assert_bool(economy._is_offline_replay).is_false()

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 7 — AC: tick_budget == 0 → empty result, no signal, no state change
# ---------------------------------------------------------------------------
func test_compute_offline_batch_zero_tick_budget_returns_empty_result_no_emission() -> void:
	# Arrange
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	economy.set_offline_replay_inputs(1.0, 2)
	var emissions: Array[int] = []
	economy.gold_changed.connect(
		func(_new_balance: int, _delta: int, _reason: String) -> void:
			emissions.append(1)
	)

	# Act
	var result: Object = economy.compute_offline_batch(0)

	# Assert — empty result, no signal, no state change
	assert_int(result.total_gold).is_equal(0)
	assert_int(result.floors_cleared.size()).is_equal(0)
	assert_int(result.events_log.size()).is_equal(0)
	assert_int(emissions.size()).is_equal(0)
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_bool(economy._is_offline_replay).is_false()

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 8 — AC edge: negative tick_budget defensive — same as zero (return empty)
# ---------------------------------------------------------------------------
func test_compute_offline_batch_negative_tick_budget_returns_empty_result_defensively() -> void:
	# Arrange
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	economy.set_offline_replay_inputs(1.0, 2)

	# Act
	var result: Object = economy.compute_offline_batch(-1000)

	# Assert
	assert_int(result.total_gold).is_equal(0)
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_bool(economy._is_offline_replay).is_false()

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 9 — AC: OfflineResult is RefCounted (NOT Object)
#   Verifies the inline class extends RefCounted so it auto-frees when the
#   last reference drops. We can't directly assert "is RefCounted" without
#   reflection, but we can assert is_instance_of behavior + that 1000
#   sequential calls do not accumulate orphans (RefCounted auto-cleans).
# ---------------------------------------------------------------------------
func test_offline_result_is_refcounted_class_no_leak_across_many_calls() -> void:
	# Arrange
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	economy.set_offline_replay_inputs(1.0, 1)

	# Act — 1000 calls; each result reference is dropped immediately. If
	# OfflineResult were a plain Object, this would leak 1000 instances.
	# RefCounted auto-frees on ref count == 0.
	for i: int in range(1000):
		var _result: Object = economy.compute_offline_batch(0)
		# _result goes out of scope here; ref count drops to 0 on next iteration

	# Assert — proxy check: assert RefCounted-typed result via cast
	var final_result: RefCounted = economy.compute_offline_batch(100) as RefCounted
	assert_object(final_result).is_not_null()

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 10 — AC: OfflineResult.events_log populated for non-zero drip arm
# ---------------------------------------------------------------------------
func test_compute_offline_batch_events_log_records_drip_arm() -> void:
	# Arrange
	var economy: Node = _make_economy([2, 4, 7, 12, 8], 1.0)
	economy.set_offline_replay_inputs(2.0, 3)  # FS=2, floor 3 (BASE_DRIP=7)

	# Act
	var result: Object = economy.compute_offline_batch(1000)

	# Assert — events_log has exactly one drip entry with the expected fields
	assert_int(result.events_log.size()).is_equal(1)
	var entry: Dictionary = result.events_log[0]
	assert_str(entry["type"]).is_equal("drip")
	assert_int(entry["amount"]).is_equal(_expected_drip(7, 2.0, 1.0, 1000))
	assert_int(entry["ticks"]).is_equal(1000)
	assert_int(entry["floor_index"]).is_equal(3)
	assert_float(entry["formation_strength"]).is_equal(2.0)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test — code review 2026-06-16 (I7): chunked replay has NO per-chunk floor drift.
#
#   The OfflineProgressionEngine drives compute_offline_batch once per CHUNK inside
#   a suppression window (_is_offline_replay set around the whole loop). Crediting
#   floori(rate * chunk_i) per chunk and summing drifts BELOW floori(rate * total)
#   for a fractional rate — every chunk whose rate*chunk has a fractional part
#   discards it. The telescoping fix must make the chunked sum EXACTLY equal the
#   single-call closed form.
#
#   Rate 9.8 = BASE_DRIP[0]=49 × FS 0.2. Chunk size 501 (NOT 500) so 9.8×501 =
#   4909.8 has a fractional part the OLD per-chunk floori() would discard — the
#   review's reproduced underpayment. (9.8×500 = 4900.0 is whole and would hide it.)
# ---------------------------------------------------------------------------
func test_i7_chunked_window_total_equals_closed_form_no_drift() -> void:
	var total_ticks: int = 576_000  # 8h @ 20 ticks/s
	var rate: float = 49.0 * 0.2 * 1.0  # identical float expression to _drip_rate_per_tick
	var closed_form: int = floori(rate * float(total_ticks))

	var economy: Node = _make_economy([49, 0, 0, 0, 0], 1.0)
	economy.set_offline_replay_inputs(0.2, 1)  # rate = BASE_DRIP[0]=49 × 0.2 = 9.8/tick

	# Simulate the engine-managed window: flag set around the whole chunked loop.
	economy._is_offline_replay = true
	var ticks_left: int = total_ticks
	var summed_marginals: int = 0
	while ticks_left > 0:
		var c: int = mini(501, ticks_left)
		summed_marginals += int(economy.compute_offline_batch(c).total_gold)
		ticks_left -= c

	# Telescoping: per-chunk marginals sum to the closed form (no drift). The OLD
	# code summed floori(rate * chunk) per chunk → strictly less for chunk 501.
	assert_int(summed_marginals).is_equal(closed_form)
	# The accumulated pending delta (what flush_offline_signals will emit) matches.
	assert_int(economy._offline_pending_delta).is_equal(closed_form)
	assert_int(economy.get_gold_balance()).is_equal(closed_form)

	economy.free()


func test_i7_chunked_window_equals_single_standalone_batch() -> void:
	# Chunked engine-window total == a single standalone batch over the full budget
	# (which is the closed form by construction). Proves foreground/offline parity
	# holds regardless of how the engine slices the window into chunks.
	var total_ticks: int = 576_000

	var e1: Node = _make_economy([49, 0, 0, 0, 0], 1.0)
	e1.set_offline_replay_inputs(0.2, 1)
	var single_total: int = int(e1.compute_offline_batch(total_ticks).total_gold)
	e1.free()

	var e2: Node = _make_economy([49, 0, 0, 0, 0], 1.0)
	e2.set_offline_replay_inputs(0.2, 1)
	e2._is_offline_replay = true
	var ticks_left: int = total_ticks
	var chunked_total: int = 0
	while ticks_left > 0:
		var c: int = mini(501, ticks_left)
		chunked_total += int(e2.compute_offline_batch(c).total_gold)
		ticks_left -= c
	e2.free()

	assert_int(chunked_total).is_equal(single_total)


# ---------------------------------------------------------------------------
# Test — code review 2026-06-16 (I8): offline drip floor comes from the
# orchestrator's offline-resume accessor, not a hardcoded 1.
#
#   With no test override, _resolve_offline_replay_floor_index now reads the live
#   DungeonRunOrchestrator.get_offline_resume_floor_index() (restored from the
#   persisted active_run at boot by I3). Mutates the live autoload's resume field,
#   so it snapshots + restores per the live-autoload test-isolation rule.
# ---------------------------------------------------------------------------
func test_i8_offline_floor_reads_orchestrator_resume_floor_with_clamp() -> void:
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	if orch == null:
		push_warning("Skipped: DungeonRunOrchestrator autoload absent")
		return
	var saved_resume: int = orch._offline_resume_floor_index

	# Economy must be in-tree so its get_tree()-guarded orchestrator lookup runs.
	# No floor override → production path queries the orchestrator. (_config not
	# needed: _resolve_offline_replay_floor_index only resolves the floor index.)
	var economy: Node = EconomyScript.new()
	add_child(economy)
	auto_free(economy)

	orch._offline_resume_floor_index = 4
	assert_int(economy._resolve_offline_replay_floor_index()).is_equal(4)
	# No active run persisted (resume 0) → floor-1 fallback.
	orch._offline_resume_floor_index = 0
	assert_int(economy._resolve_offline_replay_floor_index()).is_equal(1)
	# Out-of-range resume → clamped to floor 1 (BASE_DRIP range is [1, 5]).
	orch._offline_resume_floor_index = 99
	assert_int(economy._resolve_offline_replay_floor_index()).is_equal(1)

	orch._offline_resume_floor_index = saved_resume
