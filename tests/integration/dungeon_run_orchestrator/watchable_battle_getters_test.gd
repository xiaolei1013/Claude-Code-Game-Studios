# Integration tests for the Defeat & Injury System Phase 4 (GDD #34 §I) watchable-
# battle orchestrator getters that drive the dungeon-run-view HP bar + enemy
# lineup:
#   current_party_hp() -> int   — live party HP at run_snapshot.current_tick
#   max_party_hp()     -> int   — formation HP pool (refills each loop, §E.3)
#   enemies_remaining()-> int   — enemy_total() - kill_count, clamped >= 0
#   enemy_total()      -> int   — enemy_list.size() * loops_per_run
#
# These are thin reads over the live _combat_snapshot + run_snapshot, delegating
# the HP curve to resolver.party_hp_remaining_at (the SAME two-sided-race math as
# the WIN/DEFEAT verdict, so the bar is truthful). The orchestrator wires a REAL
# DefaultCombatResolver in _ready when none is injected, so the numbers below
# cross-check the worked example in party_hp_curve_test.gd / compute_run_outcome_test.gd:
#   dispatched_at=100; enemies a(hp30,atk180,spd10)->dmg 20, b(hp45,atk90,spd10)->dmg 10,
#   both advantaged (factor 1.5), SPEED_BASE=90 fallback, MATCHUP disadvantage=1.0:
#     party_damage_by(T) = 20*min(T,2) + 10*min(T,5); ticks_per_loop=5
#     party_hp=100: rel 0->100, 1->70, 2->40, 4->20, 5->100(reset)
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")

const DISPATCHED_AT := 100


func _enemy(id: StringName, base_hp: int, base_attack: int, base_speed: int) -> Dictionary:
	return {
		"id": id,
		"archetype": &"goblin",
		"tier": 1,
		"is_boss": false,
		"base_hp": base_hp,
		"base_attack": base_attack,
		"base_speed": base_speed,
	}


# Worked-example combat snapshot (mirrors party_hp_curve_test.gd).
func _combat_snapshot(party_hp: int, loops: int = 1) -> RefCounted:
	var snap: RefCounted = CombatRunSnapshotScript.new()
	snap.formation_dps_per_tick = 10.0
	snap.formation_total_hp = party_hp
	snap.dispatched_at_tick = DISPATCHED_AT
	snap.loops_per_run = loops
	var cache: Dictionary = {&"goblin": true}  # advantaged -> factor 1.5
	snap.matchup_cache = cache
	var enemies: Array = [
		_enemy(&"a", 30, 180, 10),  # dmg_rate = 20
		_enemy(&"b", 45, 90, 10),   # dmg_rate = 10
	]
	snap.enemy_list = enemies
	return snap


# Fresh orchestrator with a REAL resolver (wired by _ready), the worked-example
# combat snapshot installed, and a run_snapshot at the given current tick + kills.
func _make_orch(party_hp: int, current_tick: int, kill_count: int = 0, loops: int = 1) -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	orch._combat_snapshot = _combat_snapshot(party_hp, loops)
	var rs: RunSnapshot = RunSnapshotScript.new()
	rs.current_tick = current_tick
	rs.last_emitted_tick = current_tick
	rs.kill_count = kill_count
	orch.run_snapshot = rs
	return orch


# ===========================================================================
# Group A — max_party_hp + current_party_hp track the resolver curve
# ===========================================================================

func test_max_party_hp_is_formation_total_hp() -> void:
	var orch: Node = _make_orch(100, DISPATCHED_AT)
	assert_int(orch.max_party_hp()).is_equal(100)


func test_current_party_hp_full_at_dispatch_tick() -> void:
	# current_tick == dispatched_at -> rel 0 -> no damage -> full HP.
	var orch: Node = _make_orch(100, DISPATCHED_AT)
	assert_int(orch.current_party_hp()).is_equal(100)


func test_current_party_hp_after_two_ticks() -> void:
	# current_tick = 102 -> rel 2 -> party_damage_by(2)=60 -> 100-60 = 40.
	var orch: Node = _make_orch(100, DISPATCHED_AT + 2)
	assert_int(orch.current_party_hp()).is_equal(40)


func test_current_party_hp_at_loop_minimum() -> void:
	# current_tick = 104 -> rel 4 (= T_clear-1) -> 100-80 = 20 (winning min).
	var orch: Node = _make_orch(100, DISPATCHED_AT + 4)
	assert_int(orch.current_party_hp()).is_equal(20)


func test_current_party_hp_resets_at_loop_boundary() -> void:
	# loops=3, current_tick = 105 -> rel 5 -> 5 % 5 = 0 -> full HP again (§E.3).
	var orch: Node = _make_orch(100, DISPATCHED_AT + 5, 0, 3)
	assert_int(orch.current_party_hp()).is_equal(100)


func test_current_party_hp_zero_at_defeat_for_losing_run() -> void:
	# Losing party (hp=50): defeat at rel 2 -> HP curve reads 0 there.
	var orch: Node = _make_orch(50, DISPATCHED_AT + 2)
	assert_int(orch.current_party_hp()).is_equal(0)


# ===========================================================================
# Group B — enemy_total + enemies_remaining
# ===========================================================================

func test_enemy_total_is_lineup_times_loops() -> void:
	var orch: Node = _make_orch(100, DISPATCHED_AT, 0, 3)
	assert_int(orch.enemy_total()).is_equal(6)  # 2 enemies * 3 loops


func test_enemy_total_single_loop() -> void:
	var orch: Node = _make_orch(100, DISPATCHED_AT)
	assert_int(orch.enemy_total()).is_equal(2)


func test_enemies_remaining_subtracts_kills() -> void:
	# 6 total, 1 killed -> 5 remaining.
	var orch: Node = _make_orch(100, DISPATCHED_AT, 1, 3)
	assert_int(orch.enemies_remaining()).is_equal(5)


func test_enemies_remaining_full_lineup_before_any_kill() -> void:
	var orch: Node = _make_orch(100, DISPATCHED_AT, 0, 3)
	assert_int(orch.enemies_remaining()).is_equal(6)


func test_enemies_remaining_clamps_at_zero_past_total() -> void:
	# Defensive: kill_count exceeding total never reads negative.
	var orch: Node = _make_orch(100, DISPATCHED_AT, 99, 1)
	assert_int(orch.enemies_remaining()).is_equal(0)


# ===========================================================================
# Group C — defensive: no combat snapshot / null run_snapshot
# ===========================================================================

func test_no_combat_snapshot_reads_zero_hp_and_enemies() -> void:
	# NO_RUN before first dispatch: snapshot null -> 0/0 bar (view hides it).
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	assert_int(orch.max_party_hp()).is_equal(0)
	assert_int(orch.current_party_hp()).is_equal(0)
	assert_int(orch.enemy_total()).is_equal(0)
	assert_int(orch.enemies_remaining()).is_equal(0)


func test_null_run_snapshot_reads_full_hp() -> void:
	# Combat snapshot present but run_snapshot null (mid-dispatch transient):
	# rel_tick defaults to 0 -> full HP, full lineup (no kills counted yet).
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	orch._combat_snapshot = _combat_snapshot(100, 2)
	orch.run_snapshot = null
	assert_int(orch.current_party_hp()).is_equal(100)
	assert_int(orch.max_party_hp()).is_equal(100)
	assert_int(orch.enemy_total()).is_equal(4)
	assert_int(orch.enemies_remaining()).is_equal(4)
