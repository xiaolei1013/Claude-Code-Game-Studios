# Tests for Story S4-S2: HeroClass.stat_at_level helper.
# Covers: TR-hero-class-db-009, TR-hero-class-db-010, ADR-0011.
# GDD §D.4 (L15 sanity table), §H-02 (formula), §H-03 (silent clamp at cap),
# §H-04 (invalid-level fallback).
#
# All tests load the shipped .tres files via DataRegistry.resolve to verify the
# helper against real authored content (not synthetic fixtures).
extends GdUnitTestSuite

const HeroClassScript = preload("res://src/core/hero_class_database/hero_class.gd")
const EconomyConfigScript = preload("res://src/core/economy/economy_config.gd")


func _make_warrior() -> HeroClass:
	var hc: HeroClass = HeroClassScript.new()
	hc.id = "warrior_test"
	hc.display_name = "Warrior Test"
	hc.tier = 1
	hc.role = "tank"
	hc.counter_archetype = "bruiser"
	hc.base_attack = 12
	hc.base_hp = 120
	hc.base_speed = 6
	hc.attack_per_level = 2
	hc.hp_per_level = 17
	hc.speed_per_level = 1
	return hc


func _make_mage() -> HeroClass:
	var hc: HeroClass = HeroClassScript.new()
	hc.id = "mage_test"
	hc.display_name = "Mage Test"
	hc.tier = 1
	hc.role = "striker"
	hc.counter_archetype = "caster"
	hc.base_attack = 20
	hc.base_hp = 70
	hc.base_speed = 10
	hc.attack_per_level = 3
	hc.hp_per_level = 10
	hc.speed_per_level = 1
	return hc


func _make_rogue() -> HeroClass:
	var hc: HeroClass = HeroClassScript.new()
	hc.id = "rogue_test"
	hc.display_name = "Rogue Test"
	hc.tier = 1
	hc.role = "precision"
	hc.counter_archetype = "armored"
	hc.base_attack = 14
	hc.base_hp = 55
	hc.base_speed = 16
	hc.attack_per_level = 2
	hc.hp_per_level = 8
	hc.speed_per_level = 2
	return hc


# ---------------------------------------------------------------------------
# AC H-02: L-cap sanity table — 9 (stat × class) sub-cases against GDD §D.4.
# Expected values are computed from base + per_level*(LEVEL_CAP - 1) so a
# future LEVEL_CAP bump keeps them honest.
# ---------------------------------------------------------------------------

func test_stat_at_level_warrior_lcap_attack_matches_formula() -> void:
	var w := _make_warrior()
	var expected: int = w.base_attack + w.attack_per_level * (HeroClassScript.LEVEL_CAP - 1)
	assert_int(w.stat_at_level(HeroClass.Stat.ATTACK, HeroClassScript.LEVEL_CAP)).is_equal(expected)


func test_stat_at_level_warrior_lcap_hp_matches_formula() -> void:
	var w := _make_warrior()
	var expected: int = w.base_hp + w.hp_per_level * (HeroClassScript.LEVEL_CAP - 1)
	assert_int(w.stat_at_level(HeroClass.Stat.HP, HeroClassScript.LEVEL_CAP)).is_equal(expected)


func test_stat_at_level_warrior_lcap_speed_matches_formula() -> void:
	var w := _make_warrior()
	var expected: int = w.base_speed + w.speed_per_level * (HeroClassScript.LEVEL_CAP - 1)
	assert_int(w.stat_at_level(HeroClass.Stat.SPEED, HeroClassScript.LEVEL_CAP)).is_equal(expected)


func test_stat_at_level_mage_lcap_attack_matches_formula() -> void:
	var m := _make_mage()
	var expected: int = m.base_attack + m.attack_per_level * (HeroClassScript.LEVEL_CAP - 1)
	assert_int(m.stat_at_level(HeroClass.Stat.ATTACK, HeroClassScript.LEVEL_CAP)).is_equal(expected)


func test_stat_at_level_mage_lcap_hp_matches_formula() -> void:
	var m := _make_mage()
	var expected: int = m.base_hp + m.hp_per_level * (HeroClassScript.LEVEL_CAP - 1)
	assert_int(m.stat_at_level(HeroClass.Stat.HP, HeroClassScript.LEVEL_CAP)).is_equal(expected)


func test_stat_at_level_mage_lcap_speed_matches_formula() -> void:
	var m := _make_mage()
	var expected: int = m.base_speed + m.speed_per_level * (HeroClassScript.LEVEL_CAP - 1)
	assert_int(m.stat_at_level(HeroClass.Stat.SPEED, HeroClassScript.LEVEL_CAP)).is_equal(expected)


func test_stat_at_level_rogue_lcap_attack_matches_formula() -> void:
	var r := _make_rogue()
	var expected: int = r.base_attack + r.attack_per_level * (HeroClassScript.LEVEL_CAP - 1)
	assert_int(r.stat_at_level(HeroClass.Stat.ATTACK, HeroClassScript.LEVEL_CAP)).is_equal(expected)


func test_stat_at_level_rogue_lcap_hp_matches_formula() -> void:
	var r := _make_rogue()
	var expected: int = r.base_hp + r.hp_per_level * (HeroClassScript.LEVEL_CAP - 1)
	assert_int(r.stat_at_level(HeroClass.Stat.HP, HeroClassScript.LEVEL_CAP)).is_equal(expected)


func test_stat_at_level_rogue_lcap_speed_matches_formula() -> void:
	var r := _make_rogue()
	var expected: int = r.base_speed + r.speed_per_level * (HeroClassScript.LEVEL_CAP - 1)
	assert_int(r.stat_at_level(HeroClass.Stat.SPEED, HeroClassScript.LEVEL_CAP)).is_equal(expected)


# ---------------------------------------------------------------------------
# AC formula: L1 returns base, L8 mid-range, integer arithmetic
# ---------------------------------------------------------------------------

func test_stat_at_level_l1_returns_base_attack() -> void:
	var w := _make_warrior()
	assert_int(w.stat_at_level(HeroClass.Stat.ATTACK, 1)).is_equal(12)


func test_stat_at_level_l1_returns_base_hp() -> void:
	var w := _make_warrior()
	assert_int(w.stat_at_level(HeroClass.Stat.HP, 1)).is_equal(120)


func test_stat_at_level_l1_returns_base_speed() -> void:
	var w := _make_warrior()
	assert_int(w.stat_at_level(HeroClass.Stat.SPEED, 1)).is_equal(6)


func test_stat_at_level_l8_warrior_attack_returns_26() -> void:
	# 12 + 2 * (8 - 1) = 26
	var w := _make_warrior()
	assert_int(w.stat_at_level(HeroClass.Stat.ATTACK, 8)).is_equal(26)


func test_stat_at_level_l8_warrior_hp_returns_239() -> void:
	# 120 + 17 * (8 - 1) = 120 + 119 = 239
	var w := _make_warrior()
	assert_int(w.stat_at_level(HeroClass.Stat.HP, 8)).is_equal(239)


# ---------------------------------------------------------------------------
# AC H-03: silent clamp at LEVEL_CAP — no error, no warning
# ---------------------------------------------------------------------------

func test_stat_at_level_above_cap_silent_clamps_to_lcap() -> void:
	var w := _make_warrior()
	var v_at_cap: int = w.stat_at_level(HeroClass.Stat.ATTACK, HeroClassScript.LEVEL_CAP)
	var v_above_cap_1: int = w.stat_at_level(HeroClass.Stat.ATTACK, HeroClassScript.LEVEL_CAP + 1)
	var v_above_cap_far: int = w.stat_at_level(HeroClass.Stat.ATTACK, HeroClassScript.LEVEL_CAP + 100)
	assert_int(v_above_cap_1).is_equal(v_at_cap)
	assert_int(v_above_cap_far).is_equal(v_at_cap)


func test_stat_at_level_at_cap_boundary_off_by_one_guard() -> void:
	# Off-by-one guard: LEVEL_CAP itself must not double-clamp to LEVEL_CAP-1.
	# expected = base + per_level * (LEVEL_CAP - 1)
	var w := _make_warrior()
	var expected: int = w.base_attack + w.attack_per_level * (HeroClassScript.LEVEL_CAP - 1)
	assert_int(w.stat_at_level(HeroClass.Stat.ATTACK, HeroClassScript.LEVEL_CAP)).is_equal(expected)


# ---------------------------------------------------------------------------
# AC H-04: invalid-level fallback — push_error + L1 stats returned
# ---------------------------------------------------------------------------

func test_stat_at_level_zero_returns_l1_fallback() -> void:
	var w := _make_warrior()
	# H-04: push_error fires; returns L1 stats as safe fallback
	assert_int(w.stat_at_level(HeroClass.Stat.ATTACK, 0)).is_equal(12)


func test_stat_at_level_negative_returns_l1_fallback() -> void:
	var w := _make_warrior()
	assert_int(w.stat_at_level(HeroClass.Stat.ATTACK, -5)).is_equal(12)


func test_stat_at_level_int_min_does_not_crash_and_returns_l1() -> void:
	var w := _make_warrior()
	# Well-defined min int in GDScript
	assert_int(w.stat_at_level(HeroClass.Stat.ATTACK, -9223372036854775807)).is_equal(12)


# ---------------------------------------------------------------------------
# Resource (.tres) integration — verify shipped data hits the GDD §D.4 sanity
# table at LEVEL_CAP using the formula (so a cap bump cascades, not breaks).
# ---------------------------------------------------------------------------

func test_warrior_tres_lcap_matches_formula() -> void:
	var w: HeroClass = load("res://assets/data/classes/warrior.tres") as HeroClass
	assert_object(w).is_not_null()
	var growth: int = HeroClassScript.LEVEL_CAP - 1
	assert_int(w.stat_at_level(HeroClass.Stat.ATTACK, HeroClassScript.LEVEL_CAP)).is_equal(w.base_attack + w.attack_per_level * growth)
	assert_int(w.stat_at_level(HeroClass.Stat.HP, HeroClassScript.LEVEL_CAP)).is_equal(w.base_hp + w.hp_per_level * growth)
	assert_int(w.stat_at_level(HeroClass.Stat.SPEED, HeroClassScript.LEVEL_CAP)).is_equal(w.base_speed + w.speed_per_level * growth)


func test_mage_tres_lcap_matches_formula() -> void:
	var m: HeroClass = load("res://assets/data/classes/mage.tres") as HeroClass
	assert_object(m).is_not_null()
	var growth: int = HeroClassScript.LEVEL_CAP - 1
	assert_int(m.stat_at_level(HeroClass.Stat.ATTACK, HeroClassScript.LEVEL_CAP)).is_equal(m.base_attack + m.attack_per_level * growth)
	assert_int(m.stat_at_level(HeroClass.Stat.HP, HeroClassScript.LEVEL_CAP)).is_equal(m.base_hp + m.hp_per_level * growth)
	assert_int(m.stat_at_level(HeroClass.Stat.SPEED, HeroClassScript.LEVEL_CAP)).is_equal(m.base_speed + m.speed_per_level * growth)


func test_rogue_tres_lcap_matches_formula() -> void:
	var r: HeroClass = load("res://assets/data/classes/rogue.tres") as HeroClass
	assert_object(r).is_not_null()
	var growth: int = HeroClassScript.LEVEL_CAP - 1
	assert_int(r.stat_at_level(HeroClass.Stat.ATTACK, HeroClassScript.LEVEL_CAP)).is_equal(r.base_attack + r.attack_per_level * growth)
	assert_int(r.stat_at_level(HeroClass.Stat.HP, HeroClassScript.LEVEL_CAP)).is_equal(r.base_hp + r.hp_per_level * growth)
	assert_int(r.stat_at_level(HeroClass.Stat.SPEED, HeroClassScript.LEVEL_CAP)).is_equal(r.base_speed + r.speed_per_level * growth)


# ---------------------------------------------------------------------------
# CI guardrail: HeroClass.LEVEL_CAP must equal EconomyConfig.LEVEL_CAP.
# Catches silent drift between the schema-side const and the designer-tunable
# `.tres` field. If a designer bumps economy_config.tres, this fails fast.
# ---------------------------------------------------------------------------

func test_hero_class_level_cap_is_15() -> void:
	assert_int(HeroClassScript.LEVEL_CAP).is_equal(15)


func test_hero_class_level_cap_matches_economy_config_default() -> void:
	var ec: EconomyConfig = EconomyConfigScript.new()
	assert_int(HeroClassScript.LEVEL_CAP).is_equal(ec.LEVEL_CAP)


func test_hero_class_level_cap_matches_shipped_economy_config_tres() -> void:
	var ec: EconomyConfig = load("res://assets/data/config/economy_config.tres") as EconomyConfig
	assert_object(ec).is_not_null()
	assert_int(HeroClassScript.LEVEL_CAP).is_equal(ec.LEVEL_CAP)
