# Tests for Sprint 6 hero-roster Story 005: set_hero_level + set_formation_slot.
# Covers: TR-hero-roster-012 (instance_id/class_id/display_name immutable — no
#                              public setter exposed),
#         TR-hero-roster-013 (set_hero_level: clamp to [1, level_cap()];
#                              push_warning + return false on unknown id;
#                              emit hero_leveled on success),
#         TR-hero-roster-014 (set_formation_slot: validate slot index; validate
#                              hero_id; auto-clear prior slot on duplicate
#                              placement; hero_id=0 clears).
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


# Build a fresh HeroRoster Node and add to scene tree so _ready() runs.
func _make_fresh_roster() -> Node:
	var hr: Node = HeroRosterScript.new()
	add_child(hr)
	auto_free(hr)
	return hr


# Inject a synthetic HeroInstance directly into _heroes — bypasses DataRegistry.
func _inject_hero(hr: Node, id: int, level: int = 1) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = "warrior"
	fake.display_name = "Test Hero %d" % id
	fake.current_level = level
	hr._heroes[id] = fake
	return fake


# ===========================================================================
# Group A: set_hero_level — clamp range (TR-013)
# ===========================================================================

func test_set_hero_level_clamps_above_cap_to_level_cap() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 1, 5)
	var ok: bool = hr.set_hero_level(1, 99)
	assert_bool(ok).is_true()
	# level_cap() returns 15 by default (or fallback).
	assert_int(hero.current_level).is_equal(hr.level_cap())


func test_set_hero_level_clamps_below_one_to_one() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 1, 5)
	hr.set_hero_level(1, -3)
	assert_int(hero.current_level).is_equal(1)


func test_set_hero_level_zero_clamped_to_one() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 1, 5)
	hr.set_hero_level(1, 0)
	assert_int(hero.current_level).is_equal(1)


func test_set_hero_level_in_range_passes_through() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 1, 5)
	hr.set_hero_level(1, 10)
	assert_int(hero.current_level).is_equal(10)


func test_set_hero_level_at_cap_passes_through() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 1, 5)
	var cap: int = hr.level_cap()
	hr.set_hero_level(1, cap)
	assert_int(hero.current_level).is_equal(cap)


# ===========================================================================
# Group B: set_hero_level — unknown id (TR-013)
# ===========================================================================

func test_set_hero_level_returns_false_on_unknown_id() -> void:
	var hr: Node = _make_fresh_roster()
	var ok: bool = hr.set_hero_level(99999, 5)
	assert_bool(ok).is_false()


func test_set_hero_level_does_not_mutate_state_on_unknown_id() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 1, 5)
	hr.set_hero_level(99999, 10)
	# Existing hero is untouched.
	assert_int(hero.current_level).is_equal(5)


# ===========================================================================
# Group C: set_hero_level — hero_leveled signal (TR-013)
# ===========================================================================

var _spy_leveled_count: int = 0
var _spy_leveled_id: int = 0
var _spy_leveled_old: int = 0
var _spy_leveled_new: int = 0


func _on_hero_leveled(id: int, old_level: int, new_level: int) -> void:
	_spy_leveled_count += 1
	_spy_leveled_id = id
	_spy_leveled_old = old_level
	_spy_leveled_new = new_level


func test_set_hero_level_emits_hero_leveled_with_correct_payload() -> void:
	_spy_leveled_count = 0
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 7, 3)
	hr.hero_leveled.connect(_on_hero_leveled)
	hr.set_hero_level(7, 9)
	assert_int(_spy_leveled_count).is_equal(1)
	assert_int(_spy_leveled_id).is_equal(7)
	assert_int(_spy_leveled_old).is_equal(3)
	assert_int(_spy_leveled_new).is_equal(9)


func test_set_hero_level_emits_signal_with_clamped_new_level() -> void:
	_spy_leveled_count = 0
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, 5)
	hr.hero_leveled.connect(_on_hero_leveled)
	hr.set_hero_level(1, 99)
	# Payload's new_level is the POST-CLAMP value.
	assert_int(_spy_leveled_new).is_equal(hr.level_cap())


func test_set_hero_level_does_not_emit_signal_on_unknown_id() -> void:
	_spy_leveled_count = 0
	var hr: Node = _make_fresh_roster()
	hr.hero_leveled.connect(_on_hero_leveled)
	hr.set_hero_level(99999, 5)
	assert_int(_spy_leveled_count).is_equal(0)


# Documented contract (hero_roster.gd line ~348): even when the new level
# matches the current level (no-op clamp + no actual change), the signal
# STILL fires. Subscribers can compare old==new to detect a no-op level set.
# Guards the contract against a future early-return optimization.
func test_set_hero_level_emits_signal_even_when_level_unchanged() -> void:
	_spy_leveled_count = 0
	_spy_leveled_old = -1
	_spy_leveled_new = -1
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, 7)
	hr.hero_leveled.connect(_on_hero_leveled)
	# Set level to the SAME value the hero already has.
	hr.set_hero_level(1, 7)
	assert_int(_spy_leveled_count).is_equal(1)
	assert_int(_spy_leveled_old).is_equal(7)
	assert_int(_spy_leveled_new).is_equal(7)


# Signal-ordering canary: `hero_leveled` MUST fire AFTER the mutation, so
# subscribers reading `instance.current_level` from inside their handler see
# the NEW value, not the old. Load-bearing for HUD/Recruitment consumers
# (ADR-0012). Guards a future refactor that swaps emit+mutate order.
var _spy_leveled_observed_level: int = 0
var _spy_leveled_hr_ref: Node = null


func _on_hero_leveled_observe_state(id: int, _old: int, _new: int) -> void:
	var inst: RefCounted = _spy_leveled_hr_ref._heroes[id]
	_spy_leveled_observed_level = inst.current_level


func test_set_hero_level_emits_signal_after_state_mutation() -> void:
	_spy_leveled_observed_level = 0
	var hr: Node = _make_fresh_roster()
	_spy_leveled_hr_ref = hr
	_inject_hero(hr, 1, 5)
	hr.hero_leveled.connect(_on_hero_leveled_observe_state)
	hr.set_hero_level(1, 9)
	# At signal-emit time, current_level MUST be the new value.
	assert_int(_spy_leveled_observed_level).is_equal(9)


# ===========================================================================
# Group D: set_formation_slot — happy path + zero clears (TR-014)
# ===========================================================================

func test_set_formation_slot_places_hero_at_slot() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	var ok: bool = hr.set_formation_slot(0, 1)
	assert_bool(ok).is_true()
	assert_int(hr._formation_slots[0]).is_equal(1)


func test_set_formation_slot_zero_clears_slot() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	hr._formation_slots[0] = 1
	var ok: bool = hr.set_formation_slot(0, 0)
	assert_bool(ok).is_true()
	assert_int(hr._formation_slots[0]).is_equal(0)


# ===========================================================================
# Group E: set_formation_slot — auto-clear duplicate placement (TR-014)
# ===========================================================================

func test_set_formation_slot_auto_clears_prior_slot_for_same_hero() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	# Pre-place hero 1 in slot 0.
	hr._formation_slots[0] = 1
	# Move hero 1 to slot 2.
	var ok: bool = hr.set_formation_slot(2, 1)
	assert_bool(ok).is_true()
	# Slot 0 is auto-cleared; slot 2 has the hero.
	assert_int(hr._formation_slots[0]).is_equal(0)
	assert_int(hr._formation_slots[2]).is_equal(1)


func test_set_formation_slot_no_auto_clear_when_slot_unchanged() -> void:
	# Edge: re-placing the same hero in the SAME slot is a no-op (no clear).
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	hr._formation_slots[0] = 1
	hr.set_formation_slot(0, 1)
	assert_int(hr._formation_slots[0]).is_equal(1)


# ===========================================================================
# Group F: set_formation_slot — invalid index / unknown hero_id (TR-014)
# ===========================================================================

func test_set_formation_slot_returns_false_on_negative_index() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	var ok: bool = hr.set_formation_slot(-1, 1)
	assert_bool(ok).is_false()


func test_set_formation_slot_returns_false_on_index_beyond_size() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	var ok: bool = hr.set_formation_slot(99, 1)
	assert_bool(ok).is_false()


func test_set_formation_slot_returns_false_on_unknown_hero_id() -> void:
	var hr: Node = _make_fresh_roster()
	# No hero injected.
	var ok: bool = hr.set_formation_slot(0, 99999)
	assert_bool(ok).is_false()


func test_set_formation_slot_does_not_mutate_state_on_invalid_index() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	hr._formation_slots[0] = 1
	hr.set_formation_slot(99, 1)
	# Existing slot[0] unchanged.
	assert_int(hr._formation_slots[0]).is_equal(1)


func test_set_formation_slot_does_not_mutate_state_on_unknown_hero_id() -> void:
	var hr: Node = _make_fresh_roster()
	hr.set_formation_slot(0, 99999)
	# Slot remains empty.
	assert_int(hr._formation_slots[0]).is_equal(0)


# ===========================================================================
# Group G: TR-012 — instance_id/class_id/display_name immutability
# Source-grep canary: HeroRoster exposes no public setters for those fields.
# ===========================================================================

func test_hero_roster_exposes_no_setter_for_immutable_fields() -> void:
	var file: FileAccess = FileAccess.open("res://src/core/hero_roster/hero_roster.gd", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	# No public setter API for instance_id / class_id / display_name on HeroRoster.
	assert_bool(content.contains("func set_instance_id(")).is_false()
	assert_bool(content.contains("func set_class_id(")).is_false()
	assert_bool(content.contains("func set_display_name(")).is_false()


func test_hero_instance_has_no_setter_methods() -> void:
	# Cross-check: HeroInstance itself also exposes no setter methods (S6-M1
	# already verified this; included here as a cross-story belt-and-suspenders).
	var file: FileAccess = FileAccess.open("res://src/core/hero_roster/hero_instance.gd", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	assert_bool(content.contains("func set_")).is_false()
