# Tests for Story S4-N3: HeroClass.is_class_counter helper.
# Covers: TR-hero-class-db-011, ADR-0011 §H-05, §H-06.
# Pure string equality, case-sensitive, null-safe; no membership check.
extends GdUnitTestSuite

const HeroClassScript = preload("res://src/core/hero_class_database/hero_class.gd")


func _make_class(counter: String) -> HeroClass:
	var hc: HeroClass = HeroClassScript.new()
	hc.id = "test_class"
	hc.display_name = "Test"
	hc.tier = 1
	hc.role = "tank"
	hc.counter_archetype = counter
	return hc


# ---------------------------------------------------------------------------
# AC H-06: main path — match returns true, mismatch returns false
# ---------------------------------------------------------------------------

func test_is_class_counter_warrior_vs_bruiser_returns_true() -> void:
	var w := _make_class("bruiser")
	assert_bool(HeroClassScript.is_class_counter(w, "bruiser")).is_true()


func test_is_class_counter_warrior_vs_caster_returns_false() -> void:
	var w := _make_class("bruiser")
	assert_bool(HeroClassScript.is_class_counter(w, "caster")).is_false()


func test_is_class_counter_mage_vs_caster_returns_true() -> void:
	var m := _make_class("caster")
	assert_bool(HeroClassScript.is_class_counter(m, "caster")).is_true()


func test_is_class_counter_rogue_vs_armored_returns_true() -> void:
	var r := _make_class("armored")
	assert_bool(HeroClassScript.is_class_counter(r, "armored")).is_true()


# ---------------------------------------------------------------------------
# AC H-06: empty string and unknown tag — both return false without error
# ---------------------------------------------------------------------------

func test_is_class_counter_empty_string_returns_false() -> void:
	var w := _make_class("bruiser")
	assert_bool(HeroClassScript.is_class_counter(w, "")).is_false()


func test_is_class_counter_unknown_archetype_returns_false() -> void:
	var w := _make_class("bruiser")
	assert_bool(HeroClassScript.is_class_counter(w, "purple_dragon")).is_false()


func test_is_class_counter_long_unknown_string_returns_false() -> void:
	var w := _make_class("bruiser")
	var long_str := "x".repeat(1000)
	assert_bool(HeroClassScript.is_class_counter(w, long_str)).is_false()


func test_is_class_counter_class_with_empty_counter_against_empty_returns_true() -> void:
	# Edge case: a class with counter_archetype="" matches an empty query string
	# (pure string equality semantics, no special-casing).
	var c := _make_class("")
	assert_bool(HeroClassScript.is_class_counter(c, "")).is_true()


# ---------------------------------------------------------------------------
# AC: case sensitivity — uppercase mismatches return false
# ---------------------------------------------------------------------------

func test_is_class_counter_uppercase_input_returns_false() -> void:
	var w := _make_class("bruiser")
	assert_bool(HeroClassScript.is_class_counter(w, "BRUISER")).is_false()


func test_is_class_counter_capitalized_input_returns_false() -> void:
	var w := _make_class("bruiser")
	assert_bool(HeroClassScript.is_class_counter(w, "Bruiser")).is_false()


func test_is_class_counter_whitespace_padded_input_returns_false() -> void:
	# Whitespace is treated as real characters — no trim.
	var w := _make_class("bruiser")
	assert_bool(HeroClassScript.is_class_counter(w, " bruiser ")).is_false()


# ---------------------------------------------------------------------------
# AC: null class_data — push_error + return false (no crash)
# ---------------------------------------------------------------------------

func test_is_class_counter_null_class_data_returns_false() -> void:
	# H-06 null-safe: push_error fires, returns false, does not crash.
	assert_bool(HeroClassScript.is_class_counter(null, "bruiser")).is_false()


func test_is_class_counter_null_class_with_empty_archetype_returns_false() -> void:
	assert_bool(HeroClassScript.is_class_counter(null, "")).is_false()


# ---------------------------------------------------------------------------
# Resource (.tres) integration — verify shipped classes match GDD §C.1
# ---------------------------------------------------------------------------

func test_warrior_tres_counters_bruiser() -> void:
	var w: HeroClass = load("res://assets/data/classes/warrior.tres") as HeroClass
	assert_object(w).is_not_null()
	assert_bool(HeroClassScript.is_class_counter(w, "bruiser")).is_true()
	assert_bool(HeroClassScript.is_class_counter(w, "caster")).is_false()
	assert_bool(HeroClassScript.is_class_counter(w, "armored")).is_false()


func test_mage_tres_counters_caster() -> void:
	var m: HeroClass = load("res://assets/data/classes/mage.tres") as HeroClass
	assert_object(m).is_not_null()
	assert_bool(HeroClassScript.is_class_counter(m, "caster")).is_true()
	assert_bool(HeroClassScript.is_class_counter(m, "bruiser")).is_false()


func test_rogue_tres_counters_armored() -> void:
	var r: HeroClass = load("res://assets/data/classes/rogue.tres") as HeroClass
	assert_object(r).is_not_null()
	assert_bool(HeroClassScript.is_class_counter(r, "armored")).is_true()
	assert_bool(HeroClassScript.is_class_counter(r, "bruiser")).is_false()


