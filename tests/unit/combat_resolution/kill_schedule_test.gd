# Tests for Sprint 7 combat-resolution Story 005:
#   - effective_dps(raw_dps, throughput_factor) -> float  (Phase 1 / GDD #34
#     §C.3: the hp_bonus survival-throttle term was removed; party survival is
#     now resolved by the two-sided HP race in compute_run_outcome, not folded
#     into the kill rate)
#   - ticks_to_kill(base_hp, effective_dps) -> int (ceili + maxi(1, ...) floor)
#   - _kill_schedule_for_loop(snapshot) -> Array[Dictionary] — cumulative
#     per-enemy kill_tick walk, preserving enemy_list order, applying
#     per-archetype matchup factor from snapshot.matchup_cache, propagating
#     is_boss per-event regardless of position.
#
# Covers: TR-combat-007 (effective_dps multiplication chain),
#         TR-combat-010 (ticks_to_kill = ceili(base_hp / effective_dps)),
#         TR-combat-011 (integer arithmetic, no float intermediates leak),
#         TR-combat-025 (ceili guarantees kill_tick >= dispatched_at_tick + 1),
#         TR-combat-028 (is_boss propagates regardless of queue position).
extends GdUnitTestSuite

const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")


func _make_snapshot(formation_dps: float, _hp_bonus: float, enemy_list: Array,
		matchup_cache: Dictionary, dispatched_at_tick: int = 0) -> CombatRunSnapshot:
	# Phase 1 (GDD #34): hp_bonus_factor field is RETIRED — the param is kept
	# (ignored) so the 10 positional call sites in this suite stay unchanged.
	var s: CombatRunSnapshot = CombatRunSnapshotScript.new()
	s.formation_dps_per_tick = formation_dps
	s.enemy_list = enemy_list
	s.matchup_cache = matchup_cache
	s.dispatched_at_tick = dispatched_at_tick
	return s


# ===========================================================================
# Group A: TR-007 — effective_dps multiplication chain (raw_dps × matchup factor)
# ===========================================================================

func test_effective_dps_neutral_factor() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	# 1.0 raw * 1.0 factor = 1.0
	assert_float(resolver.effective_dps(1.0, 1.0)).is_equal_approx(1.0, 0.001)


func test_effective_dps_advantaged_factor() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	# 1.0 raw * 1.5 factor = 1.5 (matchup advantage)
	assert_float(resolver.effective_dps(1.0, 1.5)).is_equal_approx(1.5, 0.001)


func test_effective_dps_disadvantaged_factor() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	# 1.0 raw * 0.67 factor ≈ 0.67 (matchup disadvantage)
	assert_float(resolver.effective_dps(1.0, 0.67)).is_equal_approx(0.67, 0.001)


func test_effective_dps_returns_float_type() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var result: Variant = resolver.effective_dps(1.0, 1.5)
	assert_int(typeof(result)).is_equal(TYPE_FLOAT)


# ===========================================================================
# Group B: TR-010 / TR-025 — ticks_to_kill formula + tick-1 floor
# ===========================================================================

func test_ticks_to_kill_basic_division() -> void:
	# 10 hp / 2.5 dps = 4.0 → ceili = 4.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.ticks_to_kill(10, 2.5)).is_equal(4)


func test_ticks_to_kill_ceili_rounds_up() -> void:
	# 10 / 3 = 3.333... → ceili = 4.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.ticks_to_kill(10, 3.0)).is_equal(4)


func test_ticks_to_kill_at_exact_one_tick() -> void:
	# 10 hp / 10 dps = 1.0 → ceili = 1 (one tick to kill).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.ticks_to_kill(10, 10.0)).is_equal(1)


func test_ticks_to_kill_high_dps_floors_at_one() -> void:
	# 10 hp / 100 dps = 0.1 → ceili = 1 (TR-025 floor; never tick 0).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.ticks_to_kill(10, 100.0)).is_equal(1)


func test_ticks_to_kill_zero_dps_returns_sentinel() -> void:
	# Defensive: zero-DPS formation produces a large-finite sentinel (10000).
	# Callers should reject this earlier; we don't return infinity so downstream
	# tick math doesn't blow up.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.ticks_to_kill(10, 0.0)).is_equal(10000)


func test_ticks_to_kill_negative_dps_returns_sentinel() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.ticks_to_kill(10, -1.0)).is_equal(10000)


func test_ticks_to_kill_zero_hp_returns_one() -> void:
	# Edge: 0 HP enemy still takes 1 tick to register.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.ticks_to_kill(0, 1.0)).is_equal(1)


func test_ticks_to_kill_returns_int_type() -> void:
	# TR-011: integer arithmetic; output is int.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var result: Variant = resolver.ticks_to_kill(10, 2.5)
	assert_int(typeof(result)).is_equal(TYPE_INT)


# ===========================================================================
# Group C: _kill_schedule_for_loop — cumulative walk
# ===========================================================================

func test_kill_schedule_empty_enemy_list_returns_empty_array() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, [], {})
	var schedule: Array[Dictionary] = resolver._kill_schedule_for_loop(snapshot)
	assert_int(schedule.size()).is_equal(0)


func test_kill_schedule_three_enemies_cumulative_ticks() -> void:
	# raw_dps=1.0 * factor_dis=0.67 * hp_bonus=1.0 = effective_dps ≈ 0.67
	# Each enemy hp=10 → ticks_to_kill = ceili(10/0.67) = 15
	# Cumulative ticks: 15, 30, 45
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var enemy_list: Array = [
		{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10},
		{"id": &"e2", "archetype": &"caster", "tier": 1, "is_boss": false, "base_hp": 10},
		{"id": &"e3", "archetype": &"armored", "tier": 2, "is_boss": false, "base_hp": 10},
	]
	# matchup_cache empty → all archetypes default to false → DIS factor (0.67)
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, enemy_list, {})
	var schedule: Array[Dictionary] = resolver._kill_schedule_for_loop(snapshot)
	assert_int(schedule.size()).is_equal(3)
	# 10 / (1.0 * 0.67 * 1.0) = 14.925 → ceili = 15.
	assert_int(schedule[0]["kill_tick"]).is_equal(15)
	assert_int(schedule[1]["kill_tick"]).is_equal(30)
	assert_int(schedule[2]["kill_tick"]).is_equal(45)


func test_kill_schedule_advantaged_archetype_uses_higher_factor() -> void:
	# matchup_cache: bruiser=true (advantaged → factor_adv=1.5),
	# others=false (factor_dis=0.67). Bruiser dies faster.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var enemy_list: Array = [
		{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10},
		{"id": &"e2", "archetype": &"caster", "tier": 1, "is_boss": false, "base_hp": 10},
	]
	var matchup: Dictionary = {&"bruiser": true, &"caster": false}
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, enemy_list, matchup)
	var schedule: Array[Dictionary] = resolver._kill_schedule_for_loop(snapshot)
	# Bruiser: 10 / (1.0 * 1.5 * 1.0) = 6.67 → ceili = 7
	# Caster: 10 / (1.0 * 0.67 * 1.0) = 14.925 → ceili = 15
	# Cumulative: 7, 22
	assert_int(schedule[0]["kill_tick"]).is_equal(7)
	assert_int(schedule[1]["kill_tick"]).is_equal(22)


func test_kill_schedule_anchors_on_dispatched_at_tick() -> void:
	# TR-026: schedule is time-anchored on snapshot.dispatched_at_tick.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var enemy_list: Array = [
		{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10},
	]
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, enemy_list, {&"bruiser": true}, 100)
	var schedule: Array[Dictionary] = resolver._kill_schedule_for_loop(snapshot)
	# dispatched_at_tick=100, ticks_to_kill=7 → kill_tick=107.
	assert_int(schedule[0]["kill_tick"]).is_equal(107)


# ===========================================================================
# Group D: TR-025 — ceili guarantees kill_tick >= dispatched_at_tick + 1
# ===========================================================================

func test_kill_schedule_first_kill_tick_always_above_dispatched_at_tick() -> void:
	# Sweep increasing DPS; first enemy's kill_tick must always be > dispatched_at_tick.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	for raw_dps_int: int in range(1, 100):
		var raw_dps: float = float(raw_dps_int) / 10.0  # 0.1, 0.2, ..., 9.9
		var enemy_list: Array = [
			{"id": &"e1", "archetype": &"x", "tier": 1, "is_boss": false, "base_hp": 5},
		]
		var snapshot: CombatRunSnapshot = _make_snapshot(raw_dps, 1.0, enemy_list, {}, 0)
		var schedule: Array[Dictionary] = resolver._kill_schedule_for_loop(snapshot)
		assert_int(schedule[0]["kill_tick"]).override_failure_message(
			"raw_dps=%f produced kill_tick=%d (must be > 0)" % [raw_dps, schedule[0]["kill_tick"]]
		).is_greater_equal(1)


# ===========================================================================
# Group E: TR-028 — is_boss propagates regardless of position
# ===========================================================================

func test_kill_schedule_is_boss_flag_preserved_per_entry() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var enemy_list: Array = [
		{"id": &"e1", "archetype": &"x", "tier": 1, "is_boss": false, "base_hp": 5},
		{"id": &"e2", "archetype": &"x", "tier": 2, "is_boss": true, "base_hp": 5},   # boss in MIDDLE
		{"id": &"e3", "archetype": &"x", "tier": 1, "is_boss": false, "base_hp": 5},
	]
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, enemy_list, {})
	var schedule: Array[Dictionary] = resolver._kill_schedule_for_loop(snapshot)
	assert_bool(schedule[0]["is_boss"]).is_false()
	assert_bool(schedule[1]["is_boss"]).is_true()  # boss flag survived mid-queue position
	assert_bool(schedule[2]["is_boss"]).is_false()


func test_kill_schedule_preserves_enemy_list_ordering() -> void:
	# Verify the schedule never reorders entries — IDs match enemy_list 1:1.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var enemy_list: Array = [
		{"id": &"first", "archetype": &"a", "tier": 1, "is_boss": false, "base_hp": 5},
		{"id": &"second", "archetype": &"b", "tier": 1, "is_boss": false, "base_hp": 5},
		{"id": &"third", "archetype": &"c", "tier": 1, "is_boss": false, "base_hp": 5},
	]
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, enemy_list, {})
	var schedule: Array[Dictionary] = resolver._kill_schedule_for_loop(snapshot)
	assert_str(str(schedule[0]["enemy_id"])).is_equal("first")
	assert_str(str(schedule[1]["enemy_id"])).is_equal("second")
	assert_str(str(schedule[2]["enemy_id"])).is_equal("third")


# ===========================================================================
# Group F: schedule entry shape — required keys present
# ===========================================================================

func test_kill_schedule_entry_has_required_keys() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var enemy_list: Array = [
		{"id": &"e1", "archetype": &"x", "tier": 1, "is_boss": false, "base_hp": 5},
	]
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, enemy_list, {})
	var schedule: Array[Dictionary] = resolver._kill_schedule_for_loop(snapshot)
	var entry: Dictionary = schedule[0]
	for key: String in ["kill_tick", "enemy_id", "archetype", "tier", "is_boss"]:
		assert_bool(entry.has(key)).override_failure_message(
			"schedule entry missing key '%s'" % key
		).is_true()


# ===========================================================================
# Group G: defensive — null snapshot / zero-dps formation
# ===========================================================================

func test_kill_schedule_zero_formation_dps_uses_sentinel_ttk() -> void:
	# Zero-DPS formation → ticks_to_kill returns 10000 sentinel per enemy.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var enemy_list: Array = [
		{"id": &"e1", "archetype": &"x", "tier": 1, "is_boss": false, "base_hp": 10},
	]
	var snapshot: CombatRunSnapshot = _make_snapshot(0.0, 1.0, enemy_list, {})
	var schedule: Array[Dictionary] = resolver._kill_schedule_for_loop(snapshot)
	# 0 raw_dps × any factor × any bonus = 0; ticks_to_kill returns sentinel 10000.
	assert_int(schedule[0]["kill_tick"]).is_equal(10000)


func test_kill_schedule_null_snapshot_returns_empty_array() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var schedule: Array[Dictionary] = resolver._kill_schedule_for_loop(null)
	assert_int(schedule.size()).is_equal(0)
