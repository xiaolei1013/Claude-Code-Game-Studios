# Tests for Sprint 8 combat-resolution Story 007 (S8-S1 carryover from S7-S1):
#   - compute_offline_batch(snapshot, tick_budget) -> CombatBatchResult
#   - Foreground/offline parity: union of emit_events_in_range over a partitioned
#     range produces aggregate-equal kills_by_archetype + kills_by_tier dicts
#   - Determinism: 100 repeated calls return field-equal results
#   - Input safety: formation + enemy_list refs not mutated
#   - Memory profile: no Array[KillEvent] retained (CombatBatchResult lacks the
#     field; absence verified via property-presence check)
#
# Covers: TR-combat-002 (compute_offline_batch entry point),
#         TR-combat-003 (single source of truth — same _kill_schedule_for_loop
#                        helper as foreground emit),
#         TR-combat-015 (CombatBatchResult 7-field population),
#         TR-combat-021 (determinism + input safety),
#         TR-combat-022 (parity invariant: foreground union == offline aggregate),
#         TR-combat-023 (no per-event Array retained for long offline windows).
extends GdUnitTestSuite

const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")


# Build a snapshot with the same canonical 3-enemy list used in the foreground
# emit tests, so per-enemy ticks_to_kill arithmetic is shared and predictable.
# With raw_dps=1.0, factor_adv=1.5, hp_bonus=1.0, base_hp=10:
#   effective_dps = 1.5; ticks_to_kill = ceili(10/1.5) = 7
#   Per-loop kill_ticks (dispatched_at_tick=0): 7, 14, 21
#   ticks_per_loop = 21
func _make_snapshot(loops_per_run: int = 3, dispatched_at_tick: int = 0) -> CombatRunSnapshot:
	var s: CombatRunSnapshot = CombatRunSnapshotScript.new()
	s.formation_dps_per_tick = 1.0
	s.hp_bonus_factor = 1.0
	s.matchup_cache = {&"bruiser": true}
	s.enemy_list = [
		{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10},
		{"id": &"e2", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10},
		{"id": &"e3", "archetype": &"bruiser", "tier": 2, "is_boss": true, "base_hp": 10},
	]
	s.dispatched_at_tick = dispatched_at_tick
	s.loops_per_run = loops_per_run
	return s


# Aggregates kill counts from a sequence of emit_events_in_range CombatTickEvents
# into the same shape compute_offline_batch produces. Used to compare
# foreground-partition aggregates against a single offline-batch aggregate.
func _aggregate_kills(events_list: Array) -> Dictionary:
	var by_archetype: Dictionary = {}
	var by_tier: Dictionary = {}
	for events: Variant in events_list:
		for ke: KillEvent in events.kills:
			by_archetype[ke.archetype] = int(by_archetype.get(ke.archetype, 0)) + 1
			by_tier[ke.tier] = int(by_tier.get(ke.tier, 0)) + 1
	return {"by_archetype": by_archetype, "by_tier": by_tier}


# ===========================================================================
# Group A: TR-002 — entry point + null/edge-case safety
# ===========================================================================

func test_compute_offline_batch_null_snapshot_returns_default_result() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()

	# Act
	var result: CombatBatchResult = resolver.compute_offline_batch(null, 1000)

	# Assert — default-constructed result, no crash.
	assert_object(result).is_not_null()
	assert_int(result.kills_by_archetype.size()).is_equal(0)
	assert_int(result.kills_by_tier.size()).is_equal(0)
	assert_int(result.loops_completed).is_equal(0)
	assert_int(result.first_clear_tick).is_equal(-1)


func test_compute_offline_batch_zero_budget_returns_empty_result() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot()

	# Act
	var result: CombatBatchResult = resolver.compute_offline_batch(s, 0)

	# Assert — no kills aggregated; final_tick stays at dispatched_at_tick.
	assert_int(result.kills_by_archetype.size()).is_equal(0)
	assert_int(result.kills_by_tier.size()).is_equal(0)
	assert_int(result.final_tick).is_equal(s.dispatched_at_tick)


func test_compute_offline_batch_negative_budget_returns_empty_result() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot()

	# Act
	var result: CombatBatchResult = resolver.compute_offline_batch(s, -100)

	# Assert
	assert_int(result.kills_by_archetype.size()).is_equal(0)


func test_compute_offline_batch_empty_enemy_list_returns_empty_result() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = CombatRunSnapshotScript.new()
	s.formation_dps_per_tick = 1.0
	s.hp_bonus_factor = 1.0
	s.enemy_list = []
	s.matchup_cache = {}
	s.loops_per_run = 1

	# Act
	var result: CombatBatchResult = resolver.compute_offline_batch(s, 100)

	# Assert
	assert_int(result.kills_by_archetype.size()).is_equal(0)


# ===========================================================================
# Group B: TR-015 — 7-field CombatBatchResult population
# ===========================================================================

func test_compute_offline_batch_full_run_populates_all_seven_fields() -> void:
	# Arrange — 3 loops × 3 enemies, schedule ends at tick 63.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(3)

	# Act — budget covers full schedule (63 ticks).
	var result: CombatBatchResult = resolver.compute_offline_batch(s, 63)

	# Assert all 7 fields populated correctly.
	# kills_by_archetype: 9 bruiser kills (3 enemies × 3 loops).
	assert_int(int(result.kills_by_archetype[&"bruiser"])).is_equal(9)
	# kills_by_tier: 6 tier-1 + 3 tier-2 (e3 is tier 2 in canonical fixture).
	assert_int(int(result.kills_by_tier[1])).is_equal(6)
	assert_int(int(result.kills_by_tier[2])).is_equal(3)
	# loops_completed = 3 (all loops finished in range).
	assert_int(result.loops_completed).is_equal(3)
	# first_clear_tick = 63 (3rd loop's last enemy = first floor-clear).
	assert_int(result.first_clear_tick).is_equal(63)
	# hp_bonus_factor copied verbatim.
	assert_float(result.hp_bonus_factor).is_equal(1.0)
	# survived = (1.0 >= 0.5) = true.
	assert_bool(result.survived).is_true()
	# final_tick: schedule exhausted exactly at budget → last event tick = 63.
	assert_int(result.final_tick).is_equal(63)


func test_compute_offline_batch_budget_truncates_mid_loop() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(3)

	# Act — budget cuts off after first loop (kill at 21) but before second loop's
	# first kill (28). Range (0, 25] → 3 kills, loops_completed=1, no clear.
	var result: CombatBatchResult = resolver.compute_offline_batch(s, 25)

	# Assert
	assert_int(int(result.kills_by_archetype[&"bruiser"])).is_equal(3)
	assert_int(int(result.kills_by_tier.get(1, 0))).is_equal(2)
	assert_int(int(result.kills_by_tier.get(2, 0))).is_equal(1)
	assert_int(result.loops_completed).is_equal(1)
	# first_clear_tick = -1 (no full-floor clear within budget).
	assert_int(result.first_clear_tick).is_equal(-1)
	# final_tick = budget cap (25), since budget was the limit not the schedule.
	assert_int(result.final_tick).is_equal(25)


func test_compute_offline_batch_first_clear_only_set_at_loops_per_run_completion() -> void:
	# Arrange — 2 loops total. Budget covers loop 1 fully and loop 2 fully.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(2)

	# Act
	var result: CombatBatchResult = resolver.compute_offline_batch(s, 42)

	# Assert — first_clear_tick = 42 (loop 2's last enemy = the loops_per_run-th
	# loop's final enemy = the floor clear).
	assert_int(result.first_clear_tick).is_equal(42)
	# Loop 1 ending at 21 should NOT have set first_clear_tick (it's not the
	# loops_per_run-th loop).
	assert_int(result.loops_completed).is_equal(2)


func test_compute_offline_batch_hp_bonus_below_threshold_marks_losing_run() -> void:
	# Arrange — hp_bonus = 0.4 < 0.5 → survived = false.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot()
	s.hp_bonus_factor = 0.4

	# Act
	var result: CombatBatchResult = resolver.compute_offline_batch(s, 1000)

	# Assert — survived field reflects threshold (TR-009 inclusive boundary).
	assert_float(result.hp_bonus_factor).is_equal_approx(0.4, 0.001)
	assert_bool(result.survived).is_false()


# ===========================================================================
# Group C: TR-022 parity — foreground partition aggregate == offline aggregate
# ===========================================================================

func test_offline_batch_matches_single_foreground_call_aggregate() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(3)

	# Act — single foreground call covering full range vs offline batch.
	var foreground: CombatTickEvents = resolver.emit_events_in_range(s, 0, 63)
	var offline: CombatBatchResult = resolver.compute_offline_batch(s, 63)
	var aggregated: Dictionary = _aggregate_kills([foreground])

	# Assert — both paths produce byte-equal aggregate dicts.
	assert_bool(CombatBatchResult.dict_equals(
		aggregated["by_archetype"], offline.kills_by_archetype
	)).is_true()
	assert_bool(CombatBatchResult.dict_equals(
		aggregated["by_tier"], offline.kills_by_tier
	)).is_true()


func test_offline_batch_matches_partitioned_foreground_call_aggregate_5x200() -> void:
	# Arrange — 5-loop schedule (last kill at tick 105, ticks_per_loop=21).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(5)

	# Act — partition (0, 1000] into 5 × 200 tick chunks via foreground; compare
	# aggregate to single offline batch.
	var foreground_events: Array = []
	for k: int in range(5):
		var lo: int = k * 200
		var hi: int = (k + 1) * 200
		foreground_events.append(resolver.emit_events_in_range(s, lo, hi))
	var offline: CombatBatchResult = resolver.compute_offline_batch(s, 1000)
	var aggregated: Dictionary = _aggregate_kills(foreground_events)

	# Assert
	assert_bool(CombatBatchResult.dict_equals(
		aggregated["by_archetype"], offline.kills_by_archetype
	)).is_true()
	assert_bool(CombatBatchResult.dict_equals(
		aggregated["by_tier"], offline.kills_by_tier
	)).is_true()


func test_offline_batch_matches_partitioned_foreground_call_aggregate_10x100() -> void:
	# Arrange — same 5-loop schedule, finer partition.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(5)

	# Act — partition (0, 1000] into 10 × 100 tick chunks.
	var foreground_events: Array = []
	for k: int in range(10):
		foreground_events.append(resolver.emit_events_in_range(s, k * 100, (k + 1) * 100))
	var offline: CombatBatchResult = resolver.compute_offline_batch(s, 1000)
	var aggregated: Dictionary = _aggregate_kills(foreground_events)

	# Assert — finer partition still aggregates byte-equal.
	assert_bool(CombatBatchResult.dict_equals(
		aggregated["by_archetype"], offline.kills_by_archetype
	)).is_true()
	assert_bool(CombatBatchResult.dict_equals(
		aggregated["by_tier"], offline.kills_by_tier
	)).is_true()


# ===========================================================================
# Group D: TR-021 determinism + input safety
# ===========================================================================

func test_compute_offline_batch_100_calls_produce_field_equal_results() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(3)

	# Act — first call as the canonical reference.
	var canonical: CombatBatchResult = resolver.compute_offline_batch(s, 63)

	# Assert — 100 subsequent calls must field-equal the canonical.
	for i: int in range(100):
		var r: CombatBatchResult = resolver.compute_offline_batch(s, 63)
		assert_bool(r.equals(canonical)).is_true()


func test_compute_offline_batch_does_not_mutate_input_snapshot_enemy_list() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(3)
	# Snapshot enemy_list as a baseline for shape comparison.
	var baseline_size: int = s.enemy_list.size()
	var baseline_first_id: StringName = s.enemy_list[0]["id"] as StringName
	var baseline_last_hp: int = int(s.enemy_list[-1]["base_hp"])

	# Act
	var _result: CombatBatchResult = resolver.compute_offline_batch(s, 63)

	# Assert — enemy_list shape + content unchanged.
	assert_int(s.enemy_list.size()).is_equal(baseline_size)
	assert_str(str(s.enemy_list[0]["id"])).is_equal(str(baseline_first_id))
	assert_int(int(s.enemy_list[-1]["base_hp"])).is_equal(baseline_last_hp)


func test_compute_offline_batch_does_not_mutate_input_matchup_cache() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(3)
	var baseline_keys: int = s.matchup_cache.size()
	var baseline_advantaged: bool = bool(s.matchup_cache.get(&"bruiser", false))

	# Act
	var _result: CombatBatchResult = resolver.compute_offline_batch(s, 63)

	# Assert
	assert_int(s.matchup_cache.size()).is_equal(baseline_keys)
	assert_bool(bool(s.matchup_cache.get(&"bruiser", false))).is_equal(baseline_advantaged)


# ===========================================================================
# Group E: TR-023 memory profile — no per-event Array retained
# ===========================================================================

func test_combat_batch_result_has_no_kill_events_array_field() -> void:
	# Arrange — TR-023 requires that CombatBatchResult does NOT carry a per-event
	# Array (which would defeat the purpose of the offline-aggregate path for
	# 15k+ kill scenarios). Verify by property-presence: instantiate a result
	# and confirm there is no `kills` (Array) field — only the aggregate dicts.
	var result: CombatBatchResult = CombatBatchResult.new()

	# Act + Assert — `kills_by_archetype` exists; `kills` (raw Array) MUST NOT.
	assert_bool("kills_by_archetype" in result).is_true()
	assert_bool("kills_by_tier" in result).is_true()
	# This is the property whose absence is the canary — if a future refactor
	# accidentally adds a `kills: Array[KillEvent]` field, this test fails.
	assert_bool("kills" in result).is_false()


func test_compute_offline_batch_15k_kill_scenario_completes_without_array_growth() -> void:
	# Arrange — large loops_per_run scenario (5000 loops × 3 enemies = 15000 kills).
	# Schedule end tick = 5000 × 21 = 105_000.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(5000)

	# Act — full-budget offline batch over 15k-kill scenario.
	var result: CombatBatchResult = resolver.compute_offline_batch(s, 105_000)

	# Assert — kills_by_archetype aggregates 15k entries into ONE int per archetype.
	# CombatBatchResult should have exactly 1 archetype key (bruiser → 15000)
	# and 2 tier keys (1 → 10000, 2 → 5000), NOT a 15k-entry Array.
	assert_int(result.kills_by_archetype.size()).is_equal(1)
	assert_int(int(result.kills_by_archetype[&"bruiser"])).is_equal(15000)
	assert_int(result.kills_by_tier.size()).is_equal(2)
	assert_int(int(result.kills_by_tier[1])).is_equal(10000)
	assert_int(int(result.kills_by_tier[2])).is_equal(5000)
	assert_int(result.loops_completed).is_equal(5000)
	assert_int(result.first_clear_tick).is_equal(105_000)


# ===========================================================================
# Group F: TR-003 single source of truth — both paths share kill schedule
# ===========================================================================

func test_offline_aggregate_first_clear_matches_foreground_first_clear_tick() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(3)

	# Act — find foreground first_clear via emit_events_in_range covering the
	# specific last-enemy-of-loops_per_run tick.
	var fg: CombatTickEvents = resolver.emit_events_in_range(s, 62, 63)
	var offline: CombatBatchResult = resolver.compute_offline_batch(s, 63)

	# Assert — both paths agree the floor cleared at tick 63 (loop 3 last enemy).
	assert_bool(fg.first_clear_in_range).is_true()
	assert_int(offline.first_clear_tick).is_equal(63)


# ===========================================================================
# Group G: defensive — final_tick behaviour
# ===========================================================================

func test_compute_offline_batch_final_tick_equals_budget_cap_when_budget_limits() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(3)

	# Act — budget < schedule end (63); cap is the limit.
	var result: CombatBatchResult = resolver.compute_offline_batch(s, 30)

	# Assert
	assert_int(result.final_tick).is_equal(30)


func test_compute_offline_batch_final_tick_equals_schedule_end_when_schedule_exhausts() -> void:
	# Arrange
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var s: CombatRunSnapshot = _make_snapshot(3)

	# Act — budget > schedule end. Schedule exhausts at tick 63; final_tick = 63.
	var result: CombatBatchResult = resolver.compute_offline_batch(s, 1000)

	# Assert — schedule was the limit, not the budget.
	assert_int(result.final_tick).is_equal(63)
