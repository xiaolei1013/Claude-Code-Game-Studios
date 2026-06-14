# Tests for GDD #34 Phase 3 (Defeat & Injury System / ADR-0021): the HeroRoster
# injury API — injure_heroes() mutator + is_hero_injured() / get_injured_hero_ids()
# query helpers + the heroes_injured signal + _suppress_signals hydration gating.
#
# injured_until is a WALL-CLOCK Unix-ms instant (0 == healthy); a hero is injured
# while now_ms < injured_until. Recovery is wall-clock so it elapses while
# backgrounded/offline (AC-34-05). The until_ms passed to injure_heroes() is an
# ABSOLUTE instant, not a duration.
#
# Covers (GDD #34 §C.3 / §D):
#   - injure_heroes sets injured_until on every found hero; skips unknown ids
#   - idempotent absolute overwrite (re-injure resets the timer)
#   - heroes_injured emits once with the marked-ids payload + until_ms
#   - no emit when every id is unknown; no emit (but full mutation) under
#     _suppress_signals (save-load hydration parity with add_xp AC-15-07)
#   - is_hero_injured boundary: true while pending, false at/after instant,
#     false for healthy / unknown / 0-sentinel
#   - get_injured_hero_ids returns currently-injured ids (iteration order),
#     empty once recovered or on an empty roster
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


func _make_fresh_roster() -> Node:
	var hr: Node = HeroRosterScript.new()
	add_child(hr)
	auto_free(hr)
	return hr


# Inject a synthetic HeroInstance straight into _heroes — bypasses DataRegistry
# so these tests stay pure unit tests (no class-resolution dependency).
func _inject_hero(hr: Node, id: int, injured_until: int = 0) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = "warrior"
	fake.display_name = "Test Hero %d" % id
	fake.current_level = 1
	fake.injured_until = injured_until
	hr._heroes[id] = fake
	return fake


# -- spy state for heroes_injured ------------------------------------------
# gdunit4 does NOT auto-clear class-level spy fields between tests — reset in
# before_test (project memory: gdunit4_spy_state_not_auto_cleared).

var _spy_injured: Array = []  # Array of [ids: Array, until_ms: int]


func _on_heroes_injured(ids: Array, until_ms: int) -> void:
	_spy_injured.append([ids, until_ms])


func before_test() -> void:
	_spy_injured = []


# ===========================================================================
# Group A — injure_heroes mutates injured_until
# ===========================================================================

func test_injure_heroes_sets_injured_until_on_each_found_hero() -> void:
	var hr: Node = _make_fresh_roster()
	var h1: RefCounted = _inject_hero(hr, 1)
	var h2: RefCounted = _inject_hero(hr, 2)
	hr.injure_heroes([1, 2], 5_000)
	assert_int(h1.injured_until).is_equal(5_000)
	assert_int(h2.injured_until).is_equal(5_000)


func test_injure_heroes_skips_unknown_ids_without_crashing() -> void:
	var hr: Node = _make_fresh_roster()
	var h1: RefCounted = _inject_hero(hr, 1)
	# id 99 is not in the roster — skipped; hero 1 still marked.
	hr.injure_heroes([1, 99], 5_000)
	assert_int(h1.injured_until).is_equal(5_000)


func test_injure_heroes_overwrites_prior_injury_with_absolute_instant() -> void:
	# Re-injuring replaces (not adds to) the recovery instant — callers pass a
	# freshly-computed ABSOLUTE instant, so a later defeat resets the timer.
	var hr: Node = _make_fresh_roster()
	var h1: RefCounted = _inject_hero(hr, 1, 5_000)
	hr.injure_heroes([1], 9_000)
	assert_int(h1.injured_until).is_equal(9_000)


# ===========================================================================
# Group B — heroes_injured signal + _suppress_signals gating
# ===========================================================================

func test_injure_heroes_emits_signal_once_with_marked_ids() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	_inject_hero(hr, 2)
	hr.heroes_injured.connect(_on_heroes_injured)
	hr.injure_heroes([1, 2], 5_000)
	assert_int(_spy_injured.size()).is_equal(1)
	# Payload[0] == marked ids (insertion order 1, 2); payload[1] == until_ms.
	assert_array(_spy_injured[0][0]).is_equal([1, 2])
	assert_int(_spy_injured[0][1]).is_equal(5_000)


func test_injure_heroes_signal_carries_only_found_ids() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	hr.heroes_injured.connect(_on_heroes_injured)
	hr.injure_heroes([1, 99], 5_000)
	assert_int(_spy_injured.size()).is_equal(1)
	assert_array(_spy_injured[0][0]).is_equal([1])


func test_injure_heroes_no_emit_when_all_ids_unknown() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	hr.heroes_injured.connect(_on_heroes_injured)
	hr.injure_heroes([99, 100], 5_000)
	assert_int(_spy_injured.size()).is_equal(0)


func test_injure_heroes_suppresses_signal_during_hydration() -> void:
	# AC-15-07 parity: under _suppress_signals the state mutates fully but no
	# signal fires (save-load hydration must not re-trigger UI/audio).
	var hr: Node = _make_fresh_roster()
	var h1: RefCounted = _inject_hero(hr, 1)
	hr.heroes_injured.connect(_on_heroes_injured)
	hr._suppress_signals = true
	hr.injure_heroes([1], 5_000)
	hr._suppress_signals = false
	assert_int(h1.injured_until).is_equal(5_000)   # mutated…
	assert_int(_spy_injured.size()).is_equal(0)     # …but silent


# ===========================================================================
# Group C — is_hero_injured boundary
# ===========================================================================

func test_is_hero_injured_true_while_recovery_pending() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, 5_000)
	assert_bool(hr.is_hero_injured(1, 4_999)).is_true()


func test_is_hero_injured_false_at_and_after_recovery_instant() -> void:
	# is_injured uses strict >, so now == injured_until reads as recovered.
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, 5_000)
	assert_bool(hr.is_hero_injured(1, 5_000)).is_false()
	assert_bool(hr.is_hero_injured(1, 5_001)).is_false()


func test_is_hero_injured_false_for_healthy_sentinel() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, 0)
	assert_bool(hr.is_hero_injured(1, 1_000_000)).is_false()


func test_is_hero_injured_false_for_unknown_and_zero_id() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, 5_000)
	assert_bool(hr.is_hero_injured(99, 0)).is_false()  # unknown id
	assert_bool(hr.is_hero_injured(0, 0)).is_false()   # empty-slot sentinel


# ===========================================================================
# Group D — get_injured_hero_ids
# ===========================================================================

func test_get_injured_hero_ids_returns_currently_injured_in_iteration_order() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, 5_000)  # injured
	_inject_hero(hr, 2, 0)      # healthy
	_inject_hero(hr, 3, 5_000)  # injured
	# Godot Dictionary preserves insertion order → [1, 3].
	assert_array(hr.get_injured_hero_ids(4_000)).is_equal([1, 3])


func test_get_injured_hero_ids_empty_when_all_recovered() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, 5_000)
	_inject_hero(hr, 2, 5_000)
	# now == injured_until → all recovered (strict >).
	assert_array(hr.get_injured_hero_ids(5_000)).is_empty()


func test_get_injured_hero_ids_empty_on_empty_roster() -> void:
	var hr: Node = _make_fresh_roster()
	assert_array(hr.get_injured_hero_ids(1_000)).is_empty()
