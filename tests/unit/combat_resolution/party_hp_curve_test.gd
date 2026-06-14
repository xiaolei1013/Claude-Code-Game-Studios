# Tests for the Defeat & Injury System Phase 4 (GDD #34 §D / ADR-0021) watchable-
# battle HP curve:
#   resolver.party_hp_remaining_at(snapshot, rel_tick) -> int
#
# This is the per-tick party-HP read that drives the dungeon-run-view HP bar. It
# reuses the SAME kill-schedule + per-enemy damage-rate math as compute_run_outcome
# (shared via _build_race_arrays), so the bar is TRUTHFUL — for a losing run the HP
# reaches 0 at exactly the resolver's defeat_tick, not a faked interpolation.
#
# Party HP RESETS each loop (GDD §E.3): the run loops loops_per_run times and the
# party HP pool refills at each loop boundary. The function therefore reports the
# CURRENT loop's remaining HP via rel_tick % ticks_per_loop.
#
# Worked example (identical to compute_run_outcome_test.gd so the numbers cross-
# check), dispatched_at = 100, raw_dps = 10.0, both enemies advantaged (factor 1.5),
# SPEED_BASE = 90 fallback, MATCHUP_PARTY_DISADVANTAGE = 1.0:
#   Enemy A: base_hp=30 → ttk=ceil(30/15)=2 → rel_death=2; dmg_rate=180*10/90=20
#   Enemy B: base_hp=45 → ttk=ceil(45/15)=3 → rel_death=5; dmg_rate=90*10/90=10
#   ticks_per_loop = T_clear = 5
#   party_damage_by(T) = 20*min(T,2) + 10*min(T,5)
#     T=0 → 0   T=1 → 30   T=2 → 60   T=3 → 70   T=4 → 80   T=5 → 90
#   So HP remaining (party_hp - damage), clamped at 0:
#     party_hp=100 (win): rel 0→100, 1→70, 2→40, 3→30, 4→20, 5→100(reset), 6→70
#     party_hp=50 (loss, defeat_tick rel 2): rel 0→50, 1→20, 2→0 (clamped)
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


# Two-enemy worked-example snapshot. party_hp + loops vary per case.
func _make_snapshot(party_hp: int, loops: int = 1) -> RefCounted:
	var snap: RefCounted = CombatRunSnapshotScript.new()
	snap.formation_dps_per_tick = RAW_DPS
	snap.formation_total_hp = party_hp
	snap.dispatched_at_tick = DISPATCHED_AT
	snap.loops_per_run = loops
	var cache: Dictionary = {&"goblin": true}  # advantaged → factor 1.5
	snap.matchup_cache = cache
	var enemies: Array = [
		_enemy(&"a", 30, 180, 10),  # dmg_rate = 180*10/90 = 20
		_enemy(&"b", 45, 90, 10),   # dmg_rate =  90*10/90 = 10
	]
	snap.enemy_list = enemies
	return snap


# ===========================================================================
# Group A — within-loop depletion (winning party, hp=100)
# ===========================================================================

func test_full_hp_at_dispatch_tick() -> void:
	# rel_tick 0 → no damage yet → full party HP.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.party_hp_remaining_at(_make_snapshot(100), 0)).is_equal(100)


func test_hp_after_one_tick_drops_by_first_damage() -> void:
	# rel 1: party_damage_by(1) = 30 → 100 - 30 = 70.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.party_hp_remaining_at(_make_snapshot(100), 1)).is_equal(70)


func test_hp_after_two_ticks() -> void:
	# rel 2: party_damage_by(2) = 60 → 100 - 60 = 40.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.party_hp_remaining_at(_make_snapshot(100), 2)).is_equal(40)


func test_hp_at_loop_min_is_lowest_before_clear() -> void:
	# rel 4 (= T_clear-1): party_damage_by(4) = 80 → 100 - 80 = 20. The minimum
	# HP the winning party reaches within a loop (matches the WIN verdict: max
	# pre-clear damage 80 < 100).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.party_hp_remaining_at(_make_snapshot(100), 4)).is_equal(20)


# ===========================================================================
# Group B — per-loop HP reset (GDD §E.3)
# ===========================================================================

func test_hp_resets_to_full_at_loop_boundary() -> void:
	# rel 5 == ticks_per_loop → 5 % 5 = 0 → loop just reset → full HP again.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.party_hp_remaining_at(_make_snapshot(100, 3), 5)).is_equal(100)


func test_second_loop_mirrors_first() -> void:
	# rel 6 → 6 % 5 = 1 → same as rel 1 of loop 1 → 70.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.party_hp_remaining_at(_make_snapshot(100, 3), 6)).is_equal(70)


# ===========================================================================
# Group C — losing party: HP hits 0 exactly at the resolver's defeat_tick
# ===========================================================================

func test_losing_party_hp_before_defeat_is_positive() -> void:
	# party_hp=50, rel 1: party_damage_by(1) = 30 → 50 - 30 = 20 (still alive).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.party_hp_remaining_at(_make_snapshot(50), 1)).is_equal(20)


func test_losing_party_hp_zero_at_defeat_tick() -> void:
	# party_hp=50: compute_run_outcome reports defeat_tick = 102 (rel 2). The HP
	# curve must read 0 at that same relative tick — truthful bar/verdict parity.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snap: RefCounted = _make_snapshot(50)
	var outcome: RefCounted = resolver.compute_run_outcome(snap)
	var defeat_rel: int = int(outcome.defeat_tick) - DISPATCHED_AT  # 2
	assert_int(resolver.party_hp_remaining_at(snap, defeat_rel)).is_equal(0)
	# And strictly positive the tick before.
	assert_int(resolver.party_hp_remaining_at(snap, defeat_rel - 1)).is_greater(0)


func test_hp_never_negative_past_defeat() -> void:
	# Past the wipe, HP stays clamped at 0 (never negative).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.party_hp_remaining_at(_make_snapshot(50), 3)).is_equal(0)


# ===========================================================================
# Group D — edge cases / defensive
# ===========================================================================

func test_null_snapshot_returns_zero() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.party_hp_remaining_at(null, 5)).is_equal(0)


func test_negative_rel_tick_returns_full_hp() -> void:
	# Defensive: a clock-rewind / pre-dispatch read shows full HP, never a wipe.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.party_hp_remaining_at(_make_snapshot(100), -3)).is_equal(100)


func test_empty_enemy_list_is_full_hp() -> void:
	# No enemies → no threat → full HP at any tick.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snap: RefCounted = CombatRunSnapshotScript.new()
	snap.formation_dps_per_tick = RAW_DPS
	snap.formation_total_hp = 77
	snap.dispatched_at_tick = DISPATCHED_AT
	snap.loops_per_run = 1
	assert_int(resolver.party_hp_remaining_at(snap, 4)).is_equal(77)


func test_party_hp_curve_is_deterministic() -> void:
	# Same inputs twice → identical reading (no RNG, no accumulation drift).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var a: int = resolver.party_hp_remaining_at(_make_snapshot(100), 3)
	var b: int = resolver.party_hp_remaining_at(_make_snapshot(100), 3)
	assert_int(a).is_equal(b)


func test_refactor_preserves_compute_run_outcome_win() -> void:
	# Guard: extracting _build_race_arrays must not change the verdict. party_hp=100
	# (worked example) is still a WIN with clear_tick 105 and defeat_tick -1.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(_make_snapshot(100))
	assert_bool(outcome.won).is_true()
	assert_int(outcome.clear_tick).is_equal(105)
	assert_int(outcome.defeat_tick).is_equal(-1)


func test_refactor_preserves_compute_run_outcome_defeat() -> void:
	# Guard: the defeat verdict + tick are unchanged by the shared-helper refactor.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var outcome: RefCounted = resolver.compute_run_outcome(_make_snapshot(50))
	assert_bool(outcome.won).is_false()
	assert_int(outcome.defeat_tick).is_equal(102)
