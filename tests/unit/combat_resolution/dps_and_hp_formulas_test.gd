# Tests for Sprint 7 combat-resolution Story 004:
#   - formation_dps_per_tick: sum(attack × speed) / SPEED_BASE; range [0.0, 2.31]
#   - formation_total_hp: sum(stat_at_level(HP, level)) helper — now the party
#     HP pool consumed by the two-sided HP race (compute_run_outcome)
#
# Phase 1 / GDD #34 §C.3: the hp_bonus_factor saturation curve and the
# survived() boundary method were removed — survival is no longer a DPS
# throttle; it is resolved by the HP race in compute_run_outcome (covered by
# compute_run_outcome_test.gd). The Group C/D tests for those methods are gone.
#
# Covers: TR-combat-006 (formation_dps_per_tick formula),
#         formation_total_hp helper (party-HP-pool building block).
extends GdUnitTestSuite

const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

const WARRIOR_ID := "warrior"
const MAGE_ID := "mage"
const ROGUE_ID := "rogue"


func _make_hero(class_id: String, level: int = 1, instance_id: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = level
	return h


func _data_registry_can_resolve(class_id: String) -> bool:
	return DataRegistry.resolve("classes", class_id) != null


# ===========================================================================
# Group A: TR-006 — formation_dps_per_tick formula
# ===========================================================================

func test_empty_formation_dps_is_zero() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_float(resolver.formation_dps_per_tick([])).is_equal_approx(0.0, 0.001)


func test_formation_dps_per_tick_uses_class_stats_at_level() -> void:
	# Single L1 warrior — DPS = (base_attack × base_speed) / SPEED_BASE
	if not _data_registry_can_resolve(WARRIOR_ID):
		push_warning("Skipped: DataRegistry not resolving warrior")
		return
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1, 1)]
	# Verify against actual class data (whatever the .tres values are, the
	# formula must produce attack*speed/SPEED_BASE).
	var class_data: Resource = DataRegistry.resolve("classes", WARRIOR_ID)
	var expected_attack: int = class_data.stat_at_level(HeroClass.Stat.ATTACK, 1)
	var expected_speed: int = class_data.stat_at_level(HeroClass.Stat.SPEED, 1)
	var expected: float = float(expected_attack * expected_speed) / 90.0  # SPEED_BASE=90
	var actual: float = resolver.formation_dps_per_tick(formation)
	assert_float(actual).is_equal_approx(expected, 0.001)


func test_formation_dps_per_tick_three_heroes_sums_correctly() -> void:
	if not _data_registry_can_resolve(WARRIOR_ID) or not _data_registry_can_resolve(MAGE_ID) or not _data_registry_can_resolve(ROGUE_ID):
		push_warning("Skipped")
		return
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1), _make_hero(MAGE_ID, 1), _make_hero(ROGUE_ID, 1)]
	var dps: float = resolver.formation_dps_per_tick(formation)
	# Output must be > 0 for any non-empty MVP formation (positive attack + speed).
	assert_float(dps).is_greater(0.0)
	# NOTE: TR-combat-006 claims output range [0.0, 2.31] but the actual class
	# .tres tuning produces DPS values an order of magnitude higher (~50 at L1
	# for a 3-hero MVP formation). This test asserts the formula is correct
	# (not zero, not negative, finite) and verifies parity against manual
	# stat-at-level computation. Bounded-range upper-bound is logged as a
	# balance-data inconsistency between TR-006 and assets/data/classes/*.tres
	# (tracked as TD-011 in tech-debt-register.md).
	#
	# Manual parity check: sum the per-hero attack*speed and divide by SPEED_BASE.
	var class_w: Resource = DataRegistry.resolve("classes", WARRIOR_ID)
	var class_m: Resource = DataRegistry.resolve("classes", MAGE_ID)
	var class_r: Resource = DataRegistry.resolve("classes", ROGUE_ID)
	var expected_sum: int = (
		class_w.stat_at_level(HeroClass.Stat.ATTACK, 1) * class_w.stat_at_level(HeroClass.Stat.SPEED, 1)
		+ class_m.stat_at_level(HeroClass.Stat.ATTACK, 1) * class_m.stat_at_level(HeroClass.Stat.SPEED, 1)
		+ class_r.stat_at_level(HeroClass.Stat.ATTACK, 1) * class_r.stat_at_level(HeroClass.Stat.SPEED, 1)
	)
	var expected_dps: float = float(expected_sum) / 90.0  # SPEED_BASE
	assert_float(dps).is_equal_approx(expected_dps, 0.001)


func test_formation_dps_with_unresolvable_class_id_skips_silently() -> void:
	if not _data_registry_can_resolve(WARRIOR_ID):
		push_warning("Skipped")
		return
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	# 1 valid warrior + 1 ghost hero. Ghost contributes 0 (silently skipped).
	var formation: Array = [_make_hero(WARRIOR_ID, 1, 1), _make_hero("ghost_class", 1, 2)]
	var formation_only_warrior: Array = [_make_hero(WARRIOR_ID, 1, 1)]
	# DPS with ghost == DPS of just-warrior (ghost contributes nothing).
	assert_float(resolver.formation_dps_per_tick(formation)).is_equal_approx(
		resolver.formation_dps_per_tick(formation_only_warrior), 0.001
	)


func test_formation_dps_higher_at_higher_level() -> void:
	# Verify level-up monotonicity (higher level → more DPS, since stat_at_level
	# is non-decreasing per GDD §C.1).
	if not _data_registry_can_resolve(WARRIOR_ID):
		push_warning("Skipped")
		return
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var dps_l1: float = resolver.formation_dps_per_tick([_make_hero(WARRIOR_ID, 1)])
	var dps_l15: float = resolver.formation_dps_per_tick([_make_hero(WARRIOR_ID, 15)])
	assert_float(dps_l15).is_greater(dps_l1)


# ===========================================================================
# Group B: formation_total_hp helper
# ===========================================================================

func test_empty_formation_total_hp_is_zero() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.formation_total_hp([])).is_equal(0)


func test_formation_total_hp_sums_class_data() -> void:
	if not _data_registry_can_resolve(WARRIOR_ID):
		push_warning("Skipped")
		return
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var formation: Array = [_make_hero(WARRIOR_ID, 1)]
	var class_data: Resource = DataRegistry.resolve("classes", WARRIOR_ID)
	var expected: int = class_data.stat_at_level(HeroClass.Stat.HP, 1)
	assert_int(resolver.formation_total_hp(formation)).is_equal(expected)


func test_formation_total_hp_returns_int_type() -> void:
	# TR-011 — integer arithmetic; no float leak.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var result: Variant = resolver.formation_total_hp([])
	assert_int(typeof(result)).is_equal(TYPE_INT)


# ===========================================================================
# Group C: TR-011 — formation_dps return type is float (not int)
# ===========================================================================

func test_formation_dps_per_tick_returns_float_type() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var result: Variant = resolver.formation_dps_per_tick([])
	assert_int(typeof(result)).is_equal(TYPE_FLOAT)
