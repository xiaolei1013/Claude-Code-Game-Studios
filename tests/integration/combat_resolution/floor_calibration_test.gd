# Phase 2 (GDD #34 §D.7 / ADR-0021) — empirical run-duration calibration.
#
# Drives the REAL DefaultCombatResolver against the REAL Forest Reach floor +
# enemy + class data to verify, per floor:
#   - the clear duration in seconds (T_clear / TICKS_PER_SECOND) lands in the
#     watchable window the player picked (~3–4 s, early floors snappier and the
#     boss longer) — no sub-second "instant combat" blur (the SPEED_BASE=10 bug)
#   - the two-sided HP race still produces real defeats for an underpowered
#     party while the intended-tier party wins (AC-34-02)
#
# Matchup spread: the resolver scales party kill-throughput by the per-enemy
# matchup factor (advantaged ×1.5 / disadvantaged ×0.67). The real game is a
# MIX, so the realistic clear time sits BETWEEN the all-advantaged (fastest)
# and all-disadvantaged (slowest) bounds this test measures. Calibration is
# anchored on those two bounds straddling the target window.
#
# SPEED_BASE is outcome-invariant (it sits in the denominator of BOTH the party
# DPS and the enemy→party damage rate), so it is tuned purely to move these
# durations; this test is the instrument that locked SPEED_BASE = 90.
#
# Env-robustness: when the env cannot resolve the live data
# (classes/enemies/dungeon), the suite skips cleanly via push_warning.
extends GdUnitTestSuite

const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

const DUNGEON_PATH := "res://assets/data/dungeons/forest_reach_dungeon_01.tres"
const TICKS_PER_SECOND := 20  # TickSystem.TICKS_PER_SECOND (game-time-and-tick.md)

const CALIBRATED_SPEED_BASE := 90  # locked Phase 2 value (combat_config.tres)

# Watchable-window guards. The anti-regression floor (no sub-second clears) and
# a generous ceiling that the boss floor is allowed to approach.
const MIN_WATCHABLE_S := 0.75   # SPEED_BASE=10 bug produced ~0.05–0.2 s clears
const MAX_WATCHABLE_S := 8.0    # all-advantaged clear must stay under this
# Mid-floor target band the realistic (ADV↔DIS) clear time must straddle.
const TARGET_LO_S := 3.0
const TARGET_HI_S := 4.0

# Intended-tier party level per floor (GDD §D.7 pacing table).
const INTENDED_LEVEL := {1: 2, 2: 4, 3: 6, 4: 11, 5: 13}
const BELOW_LEVEL := 1  # an L1 party is the "wrong tool for the job" baseline


func _classes_resolvable() -> bool:
	return (
		DataRegistry.resolve("classes", "warrior") != null
		and DataRegistry.resolve("classes", "mage") != null
		and DataRegistry.resolve("classes", "rogue") != null
	)


func _make_hero(class_id: String, level: int, instance_id: int) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = level
	return h


# Intended MVP formation: Warrior / Mage / Rogue at the given level.
func _make_formation(level: int) -> Array:
	return [
		_make_hero("warrior", level, 1),
		_make_hero("mage", level, 2),
		_make_hero("rogue", level, 3),
	]


# Replicates DungeonRunOrchestrator._materialize_enemy_list for one floor:
# expand {enemy_id, count} pairs into per-enemy stat dicts via DataRegistry.
func _materialize(floor_enemy_list: Array) -> Array:
	var out: Array = []
	for entry: Variant in floor_enemy_list:
		var d: Dictionary = entry as Dictionary
		var enemy_id: String = String(d.get("enemy_id", ""))
		var count: int = int(d.get("count", 0))
		var ed: Resource = DataRegistry.resolve("enemies", enemy_id)
		if ed == null or count <= 0:
			continue
		var template: Dictionary = {
			"id": StringName(enemy_id),
			"archetype": StringName(String(ed.get("archetype")) if "archetype" in ed else ""),
			"tier": int(ed.get("tier")) if "tier" in ed else 1,
			"is_boss": bool(ed.get("is_boss")) if "is_boss" in ed else false,
			"base_hp": int(ed.get("base_hp")) if "base_hp" in ed else 0,
			"base_attack": int(ed.get("base_attack")) if "base_attack" in ed else 0,
			"base_speed": int(ed.get("base_speed")) if "base_speed" in ed else 0,
		}
		for i: int in count:
			out.append(template.duplicate(true))
	return out


# advantaged=true → every archetype marked advantaged (×1.5, fastest clears);
# advantaged=false → empty cache (all disadvantaged ×0.67, slowest clears).
func _make_cache(enemy_list: Array, advantaged: bool) -> Dictionary:
	var cache: Dictionary = {}
	if not advantaged:
		return cache
	for e: Variant in enemy_list:
		cache[(e as Dictionary).get("archetype")] = true
	return cache


func _outcome_for(resolver: RefCounted, formation: Array, enemy_list: Array, advantaged: bool) -> RefCounted:
	var snap: RefCounted = CombatRunSnapshotScript.new()
	snap.formation_dps_per_tick = resolver.formation_dps_per_tick(formation)
	snap.formation_total_hp = resolver.formation_total_hp(formation)
	snap.dispatched_at_tick = 0
	snap.loops_per_run = 1
	snap.enemy_list = enemy_list
	snap.matchup_cache = _make_cache(enemy_list, advantaged)
	return resolver.compute_run_outcome(snap)


# Returns {fidx: {enemy_list, adv_dur, dis_dur, adv_won, dis_won, below_won}}.
func _collect() -> Dictionary:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var dungeon: Resource = load(DUNGEON_PATH)
	var results: Dictionary = {}
	for floor_data: Variant in (dungeon.get("floors") as Array):
		var fd: Resource = floor_data as Resource
		var fidx: int = int(fd.get("floor_index"))
		var enemy_list: Array = _materialize((fd.get("enemy_list") as Array).duplicate(true))
		var formation: Array = _make_formation(int(INTENDED_LEVEL.get(fidx, 1)))
		var adv: RefCounted = _outcome_for(resolver, formation, enemy_list, true)
		var dis: RefCounted = _outcome_for(resolver, formation, enemy_list, false)
		var below: RefCounted = _outcome_for(resolver, _make_formation(BELOW_LEVEL), enemy_list, false)
		results[fidx] = {
			"adv_dur": float(adv.clear_tick) / float(TICKS_PER_SECOND),
			"dis_dur": float(dis.clear_tick) / float(TICKS_PER_SECOND),
			"adv_won": adv.won,
			"dis_won": dis.won,
			"below_won": below.won,
		}
	return results


# ===========================================================================
# Diagnostic — prints the calibration table (always PASSES; payload is the log)
# ===========================================================================

func test_measure_floor_durations_and_verdicts() -> void:
	if not _classes_resolvable():
		push_warning("floor_calibration: classes not resolvable in this env — skipping")
		return
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	print("\n=== FLOOR CALIBRATION (SPEED_BASE=%d, %d ticks/s) ===" % [
		resolver._resolve_speed_base(), TICKS_PER_SECOND
	])
	var r: Dictionary = _collect()
	for fidx: int in [1, 2, 3, 4, 5]:
		var row: Dictionary = r[fidx]
		print("F%d | ADV %.2fs/%s | DIS %.2fs/%s | below-L1 %s" % [
			fidx,
			row["adv_dur"], ("WIN" if row["adv_won"] else "DEF"),
			row["dis_dur"], ("WIN" if row["dis_won"] else "DEF"),
			("WIN" if row["below_won"] else "DEF"),
		])
	assert_bool(true).is_true()


# ===========================================================================
# Calibration assertions
# ===========================================================================

func test_speed_base_is_the_calibrated_value() -> void:
	# The live combat_config.tres must resolve to the locked Phase 2 value.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver._resolve_speed_base()).is_equal(CALIBRATED_SPEED_BASE)


func test_no_floor_clears_instantly() -> void:
	# Anti-regression for the SPEED_BASE=10 "instant combat" playtest bug: even
	# the fastest (all-advantaged) clear of every floor must be watchable.
	if not _classes_resolvable():
		push_warning("floor_calibration: classes not resolvable — skipping")
		return
	var r: Dictionary = _collect()
	for fidx: int in [1, 2, 3, 4, 5]:
		assert_float(r[fidx]["adv_dur"]).override_failure_message(
			"F%d cleared in %.3fs (< %.2fs) — instant-combat regression"
			% [fidx, r[fidx]["adv_dur"], MIN_WATCHABLE_S]
		).is_greater(MIN_WATCHABLE_S)


func test_all_floors_within_watchable_ceiling() -> void:
	# The designed (advantaged) clear of every floor stays under the ceiling.
	if not _classes_resolvable():
		push_warning("floor_calibration: classes not resolvable — skipping")
		return
	var r: Dictionary = _collect()
	for fidx: int in [1, 2, 3, 4, 5]:
		assert_float(r[fidx]["adv_dur"]).override_failure_message(
			"F%d advantaged clear %.2fs exceeds %.1fs ceiling"
			% [fidx, r[fidx]["adv_dur"], MAX_WATCHABLE_S]
		).is_less(MAX_WATCHABLE_S)


func test_mid_floors_realistic_band_straddles_target_window() -> void:
	# The realistic clear time sits between the advantaged (fast) and
	# disadvantaged (slow) bounds. For the representative mid floors (F3, F4),
	# that band must straddle the player's ~3–4 s target: fastest ≤ 4 s AND
	# slowest ≥ 3 s, i.e. 3–4 s is reachable under a realistic matchup mix.
	if not _classes_resolvable():
		push_warning("floor_calibration: classes not resolvable — skipping")
		return
	var r: Dictionary = _collect()
	for fidx: int in [3, 4]:
		assert_float(r[fidx]["adv_dur"]).override_failure_message(
			"F%d fastest clear %.2fs > %.1fs — mid floor too slow even advantaged"
			% [fidx, r[fidx]["adv_dur"], TARGET_HI_S]
		).is_less_equal(TARGET_HI_S)
		assert_float(r[fidx]["dis_dur"]).override_failure_message(
			"F%d slowest clear %.2fs < %.1fs — mid floor too fast even disadvantaged"
			% [fidx, r[fidx]["dis_dur"], TARGET_LO_S]
		).is_greater_equal(TARGET_LO_S)


func test_boss_floor_runs_longer_than_first_floor() -> void:
	# The boss (F5) is the climax — its clear must take longer than F1's.
	if not _classes_resolvable():
		push_warning("floor_calibration: classes not resolvable — skipping")
		return
	var r: Dictionary = _collect()
	assert_float(r[5]["adv_dur"]).is_greater(r[1]["adv_dur"])


# ===========================================================================
# Verdict assertions (AC-34-02: real wins for intended, real defeats for weak)
# ===========================================================================

func test_intended_party_wins_every_floor_under_good_matchup() -> void:
	if not _classes_resolvable():
		push_warning("floor_calibration: classes not resolvable — skipping")
		return
	var r: Dictionary = _collect()
	for fidx: int in [1, 2, 3, 4, 5]:
		assert_bool(r[fidx]["adv_won"]).override_failure_message(
			"F%d: intended-tier party LOST under advantaged matchup" % fidx
		).is_true()


func test_underpowered_party_is_defeated_on_real_floors() -> void:
	# An L1 party (wrong tier) must be DEFEATED on the real floors (F2–F5).
	# F1 is the tutorial floor and is intentionally beatable by anyone.
	if not _classes_resolvable():
		push_warning("floor_calibration: classes not resolvable — skipping")
		return
	var r: Dictionary = _collect()
	for fidx: int in [2, 3, 4, 5]:
		assert_bool(r[fidx]["below_won"]).override_failure_message(
			"F%d: an L1 party WON — defeat system not biting for underpowered parties"
			% fidx
		).is_false()
