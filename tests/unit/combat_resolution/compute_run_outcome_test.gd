# Tests for the Defeat & Injury System (GDD #34 §D / ADR-0021) verdict:
#   resolver.compute_run_outcome(snapshot) -> CombatRunOutcome{won, clear_tick, defeat_tick}
#
# The two-sided HP race: the party kills enemies sequentially (focus-fire) while
# still-alive enemies draw down the shared party HP pool. WIN = floor cleared
# before party_hp reaches 0; DEFEAT = party_hp reaches 0 strictly first.
#
# All expected values are hand-computed against the resolver's documented model
# with the project defaults that hold in the test env:
#   SPEED_BASE = 10, MATCHUP_PARTY_DISADVANTAGE = 1.0,
#   MATCHUP_THROUGHPUT_FACTOR_ADV = 1.5 (enemies marked advantaged in the cache).
#
# Worked example used by most cases (dispatched_at = 100, raw_dps = 10.0,
# both enemies advantaged → effective_dps = 10.0 * 1.5 = 15.0):
#   Enemy A: base_hp=30 → ttk=ceil(30/15)=2 → rel_death=2; dmg_rate=20*10/10=20
#   Enemy B: base_hp=45 → ttk=ceil(45/15)=3 → rel_death=5; dmg_rate=10*10/10=10
#   T_clear = 5 (abs clear_tick = 105)
#   party_damage_by(T) = 20*min(T,2) + 10*min(T,5)
#     T=1 → 30   T=2 → 60   T=3 → 70   T=4 → 80   T=5 → 90
extends GdUnitTestSuite

const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")

const DISPATCHED_AT := 100
const RAW_DPS := 10.0  # effective_dps = 10 * 1.5 (advantaged) = 15.0


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


# Two-enemy worked-example snapshot. party_hp varies per case.
func _make_snapshot(party_hp: int) -> RefCounted:
	var snap: RefCounted = CombatRunSnapshotScript.new()
	snap.formation_dps_per_tick = RAW_DPS
	snap.formation_total_hp = party_hp
	snap.dispatched_at_tick = DISPATCHED_AT
	snap.loops_per_run = 1
	var cache: Dictionary = {&"goblin": true}  # advantaged → factor 1.5
	snap.matchup_cache = cache
	var enemies: Array = [
		_enemy(&"a", 30, 20, 10),
		_enemy(&"b", 45, 10, 10),
	]
	snap.enemy_list = enemies
	return snap


# ===========================================================================
# WIN cases
# ===========================================================================

func test_party_survives_the_race_is_a_win() -> void:
	# party_hp=100; max pre-clear damage = party_damage_by(4) = 80 < 100 → WIN.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(_make_snapshot(100))
	assert_bool(outcome.won).is_true()
	assert_int(outcome.defeat_tick).is_equal(-1)


func test_win_clear_tick_is_anchored_at_dispatch() -> void:
	# T_clear = 5 → absolute clear_tick = dispatched_at(100) + 5 = 105.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(_make_snapshot(100))
	assert_int(outcome.clear_tick).is_equal(105)


func test_tie_at_clear_tick_resolves_to_win() -> void:
	# party_hp=90; damage reaches 90 exactly at T_clear(=5), but the verdict is
	# evaluated at T_clear-1=4 (damage 80 < 90). GDD §E.2 tie rule → WIN.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(_make_snapshot(90))
	assert_bool(outcome.won).is_true()
	assert_int(outcome.defeat_tick).is_equal(-1)


func test_empty_enemy_list_is_trivial_win() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snap: RefCounted = CombatRunSnapshotScript.new()
	snap.formation_dps_per_tick = RAW_DPS
	snap.formation_total_hp = 1  # 1 HP, but no enemies → no threat
	snap.dispatched_at_tick = DISPATCHED_AT
	snap.loops_per_run = 1
	var outcome: RefCounted = resolver.compute_run_outcome(snap)
	assert_bool(outcome.won).is_true()
	assert_int(outcome.defeat_tick).is_equal(-1)
	assert_int(outcome.clear_tick).is_equal(DISPATCHED_AT)


func test_instant_clear_is_win_even_against_a_lethal_enemy() -> void:
	# Single enemy dies in 1 tick (T_clear=1) → no tick of damage can land,
	# so even a 1-HP party vs a 999-attack enemy WINS.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snap: RefCounted = CombatRunSnapshotScript.new()
	snap.formation_dps_per_tick = RAW_DPS  # effective 15.0
	snap.formation_total_hp = 1
	snap.dispatched_at_tick = DISPATCHED_AT
	snap.loops_per_run = 1
	snap.matchup_cache = {&"goblin": true}
	snap.enemy_list = [_enemy(&"glass", 5, 999, 10)]  # ttk = ceil(5/15) = 1
	var outcome: RefCounted = resolver.compute_run_outcome(snap)
	assert_bool(outcome.won).is_true()
	assert_int(outcome.clear_tick).is_equal(DISPATCHED_AT + 1)


# ===========================================================================
# DEFEAT cases
# ===========================================================================

func test_party_wipes_before_clear_is_a_defeat() -> void:
	# party_hp=50; party_damage_by(4)=80 >= 50 → DEFEAT.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(_make_snapshot(50))
	assert_bool(outcome.won).is_false()


func test_defeat_tick_is_the_first_tick_party_hp_crosses_zero() -> void:
	# party_hp=50: T=1→30 (<50), T=2→60 (>=50). First crossing at rel tick 2
	# → absolute defeat_tick = 100 + 2 = 102.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(_make_snapshot(50))
	assert_int(outcome.defeat_tick).is_equal(102)


func test_defeat_clear_tick_still_reports_the_unreached_clear() -> void:
	# clear_tick is informational on a defeat — the clear the party didn't reach.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(_make_snapshot(50))
	assert_int(outcome.clear_tick).is_equal(105)


func test_defeat_at_exactly_party_hp_counts_as_defeat() -> void:
	# party_hp=80: party_damage_by(4)=80 >= 80 (inclusive) → DEFEAT.
	# First crossing: T=3→70 (<80), T=4→80 (>=80) → defeat_tick = 100 + 4 = 104.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(_make_snapshot(80))
	assert_bool(outcome.won).is_false()
	assert_int(outcome.defeat_tick).is_equal(104)


func test_zero_party_hp_is_defeat_on_first_damaging_tick() -> void:
	# Degenerate / unplumbed formation (formation_total_hp default 0) → DEFEAT.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(_make_snapshot(0))
	assert_bool(outcome.won).is_false()
	assert_int(outcome.defeat_tick).is_equal(101)  # first tick (T=1) damage 30 >= 0


# ===========================================================================
# Determinism / parity
# ===========================================================================

func test_compute_run_outcome_is_deterministic() -> void:
	# Same snapshot twice → field-equal outcome (parity-by-construction premise).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var a: RefCounted = resolver.compute_run_outcome(_make_snapshot(50))
	var b: RefCounted = resolver.compute_run_outcome(_make_snapshot(50))
	assert_bool(a.equals(b)).is_true()


func test_null_snapshot_returns_default_win() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(null)
	assert_bool(outcome.won).is_true()
	assert_int(outcome.defeat_tick).is_equal(-1)
