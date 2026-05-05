# Sprint 11 S11-X5: HeroRoster.get_copies_owned read-API addition tests.
#
# Per Recruitment GDD §F + OQ-RC-4: the Recruitment system needs a
# get_copies_owned method to compute copies_owned for Economy.recruit_cost.
# This is the additive Sprint 12+ Story 0b lockstep edit on hero-roster.md
# + ADR-0012 Amendment #1 (additive read-API extension; no existing
# surface changes).
#
# Pattern: bypass DataRegistry by injecting synthetic HeroInstance entries
# directly into _heroes. Same _make_fresh_roster + _inject_hero helpers as
# formation_strength_and_accessors_test.gd.
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


func _make_fresh_roster() -> Node:
	var hr: Node = HeroRosterScript.new()
	add_child(hr)
	auto_free(hr)
	return hr


func _inject_hero(hr: Node, id: int, class_id: String = "warrior",
		level: int = 1) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = class_id
	fake.display_name = "Hero %d" % id
	fake.current_level = level
	fake.xp = 0
	hr._heroes[id] = fake
	return fake


# ===========================================================================
# Group A — empty roster + unknown class_id semantics
# ===========================================================================

func test_get_copies_owned_empty_roster_returns_zero() -> void:
	var hr: Node = _make_fresh_roster()
	assert_int(hr.get_copies_owned("warrior")).is_equal(0)


func test_get_copies_owned_unknown_class_id_returns_zero() -> void:
	# Per the GDD doc-comment: 0 for unknown class_id is the correct semantic
	# for recruit-cost lookup even when class_id refers to a future / unreleased
	# class.
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "warrior")
	_inject_hero(hr, 2, "warrior")
	assert_int(hr.get_copies_owned("future_class")).is_equal(0)


func test_get_copies_owned_empty_string_returns_zero() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "warrior")
	assert_int(hr.get_copies_owned("")).is_equal(0)


# ===========================================================================
# Group B — single-class counts
# ===========================================================================

func test_get_copies_owned_one_hero_one_match() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "warrior")
	assert_int(hr.get_copies_owned("warrior")).is_equal(1)


func test_get_copies_owned_three_warriors_returns_three() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "warrior")
	_inject_hero(hr, 2, "warrior")
	_inject_hero(hr, 3, "warrior")
	assert_int(hr.get_copies_owned("warrior")).is_equal(3)


# ===========================================================================
# Group C — multi-class roster
# ===========================================================================

func test_get_copies_owned_mixed_classes_independent_counts() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "warrior")
	_inject_hero(hr, 2, "warrior")
	_inject_hero(hr, 3, "mage")
	_inject_hero(hr, 4, "rogue")
	_inject_hero(hr, 5, "rogue")
	_inject_hero(hr, 6, "rogue")
	assert_int(hr.get_copies_owned("warrior")).is_equal(2)
	assert_int(hr.get_copies_owned("mage")).is_equal(1)
	assert_int(hr.get_copies_owned("rogue")).is_equal(3)
	assert_int(hr.get_copies_owned("cleric")).is_equal(0)  # absent class


func test_get_copies_owned_total_matches_roster_size_across_all_classes() -> void:
	# Invariant: sum(get_copies_owned(c) for c in distinct_classes) == roster_size.
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "warrior")
	_inject_hero(hr, 2, "warrior")
	_inject_hero(hr, 3, "mage")
	_inject_hero(hr, 4, "rogue")
	var total: int = (
		hr.get_copies_owned("warrior")
		+ hr.get_copies_owned("mage")
		+ hr.get_copies_owned("rogue")
	)
	assert_int(total).is_equal(hr._heroes.size())


# ===========================================================================
# Group D — case-sensitivity + edge cases
# ===========================================================================

func test_get_copies_owned_is_case_sensitive() -> void:
	# class_id is a stable identifier per ADR-0011 — case mismatches are
	# different IDs, not the same class.
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "Warrior")  # capitalized
	_inject_hero(hr, 2, "warrior")  # lowercase
	assert_int(hr.get_copies_owned("warrior")).is_equal(1)
	assert_int(hr.get_copies_owned("Warrior")).is_equal(1)
	assert_int(hr.get_copies_owned("WARRIOR")).is_equal(0)


func test_get_copies_owned_does_not_mutate_state() -> void:
	# Read-only method; calling it does not change _heroes or any counters.
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "warrior")
	_inject_hero(hr, 2, "warrior")
	var roster_size_before: int = hr._heroes.size()
	hr.get_copies_owned("warrior")
	hr.get_copies_owned("mage")
	hr.get_copies_owned("warrior")
	assert_int(hr._heroes.size()).is_equal(roster_size_before)


# ===========================================================================
# Group E — public API surface lock
# ===========================================================================

func test_hero_roster_get_copies_owned_method_exists() -> void:
	# Lock the method-presence contract — Recruitment GDD §F dependency.
	# A future refactor that removes this method without updating Recruitment
	# fails here loudly.
	var hr: Node = _make_fresh_roster()
	assert_bool(hr.has_method("get_copies_owned")).is_true()
