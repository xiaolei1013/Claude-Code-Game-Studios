# Tests for Sprint 14 S14-M4 Story 2: HeroRoster.add_xp + xp_threshold per
# Hero Leveling GDD #15 §C.4 / §C.5 / §C.7. Covers ACs:
#   AC-15-03 — single level-up at threshold crossing
#   AC-15-04 — multi-level cascade emits per-level signals
#   AC-15-05 — LEVEL_CAP discards overflow
#   AC-15-07 — hydration suppression (no emit when _suppress_signals == true)
#   AC-15-08 — negative XP is push_error + no-op + return false
#   AC-15-09 — zero XP is silent no-op (returns true; no signal)
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


func _make_fresh_roster() -> Node:
	var hr: Node = HeroRosterScript.new()
	add_child(hr)
	auto_free(hr)
	return hr


func _inject_hero(hr: Node, id: int, level: int = 1, xp: int = 0) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = "warrior"
	fake.display_name = "Test Hero %d" % id
	fake.current_level = level
	fake.xp = xp
	hr._heroes[id] = fake
	return fake


# -- spy state for hero_leveled --------------------------------------------

var _spy_emits: Array = []  # Array of [id, old_level, new_level]


func _on_hero_leveled(id: int, old_level: int, new_level: int) -> void:
	_spy_emits.append([id, old_level, new_level])


func before_test() -> void:
	_spy_emits = []


# ===========================================================================
# Group A — xp_threshold pure formula (sanity-check the helper)
# ===========================================================================

func test_xp_threshold_at_level_1_is_base_plus_step() -> void:
	var hr: Node = _make_fresh_roster()
	# Defaults: base=100, step=50 → threshold(1) = 150.
	assert_int(hr.xp_threshold(1)).is_equal(150)


func test_xp_threshold_at_level_2_uses_linear_curve() -> void:
	var hr: Node = _make_fresh_roster()
	# threshold(2) = 100 + 50*2 = 200.
	assert_int(hr.xp_threshold(2)).is_equal(200)


func test_xp_threshold_at_level_14_caps_curve() -> void:
	var hr: Node = _make_fresh_roster()
	# threshold(14) = 100 + 50*14 = 800 (last threshold before LEVEL_CAP=15).
	assert_int(hr.xp_threshold(14)).is_equal(800)


# ===========================================================================
# Group B — AC-15-09 zero XP is silent no-op
# ===========================================================================

func test_add_xp_zero_returns_true_without_mutation() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 1, 3, 42)
	hr.hero_leveled.connect(_on_hero_leveled)
	var ok: bool = hr.add_xp(1, 0)
	assert_bool(ok).is_true()
	assert_int(hero.xp).is_equal(42)
	assert_int(hero.current_level).is_equal(3)
	assert_int(_spy_emits.size()).is_equal(0)


# ===========================================================================
# Group C — AC-15-08 negative XP push_errors and returns false
# ===========================================================================

func test_add_xp_negative_returns_false_without_mutation() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 1, 3, 42)
	hr.hero_leveled.connect(_on_hero_leveled)
	# push_error is logged; the test asserts behavior, not log capture.
	var ok: bool = hr.add_xp(1, -10)
	assert_bool(ok).is_false()
	assert_int(hero.xp).is_equal(42)
	assert_int(hero.current_level).is_equal(3)
	assert_int(_spy_emits.size()).is_equal(0)


# ===========================================================================
# Group D — unknown id returns false (parity with set_hero_level)
# ===========================================================================

func test_add_xp_unknown_id_returns_false() -> void:
	var hr: Node = _make_fresh_roster()
	hr.hero_leveled.connect(_on_hero_leveled)
	var ok: bool = hr.add_xp(99999, 100)
	assert_bool(ok).is_false()
	assert_int(_spy_emits.size()).is_equal(0)


# ===========================================================================
# Group E — AC-15-03 single level-up at threshold crossing
# ===========================================================================

# Hero current_level=1, xp=149 (one short of threshold 150). Grant 1 XP →
# current_level=2, xp=0; hero_leveled(id, 1, 2) emitted exactly once.
func test_add_xp_crosses_single_threshold_emits_one_signal() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 7, 1, 149)
	hr.hero_leveled.connect(_on_hero_leveled)
	var ok: bool = hr.add_xp(7, 1)
	assert_bool(ok).is_true()
	assert_int(hero.current_level).is_equal(2)
	assert_int(hero.xp).is_equal(0)
	assert_int(_spy_emits.size()).is_equal(1)
	assert_array(_spy_emits[0]).is_equal([7, 1, 2])


func test_add_xp_below_threshold_accumulates_without_level_up() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 7, 1, 100)
	hr.hero_leveled.connect(_on_hero_leveled)
	var ok: bool = hr.add_xp(7, 49)  # 100 + 49 = 149, threshold(1)=150 → no level-up
	assert_bool(ok).is_true()
	assert_int(hero.current_level).is_equal(1)
	assert_int(hero.xp).is_equal(149)
	assert_int(_spy_emits.size()).is_equal(0)


# ===========================================================================
# Group F — AC-15-04 multi-level cascade emits per-level signals
# ===========================================================================

# Hero current_level=1, xp=0. Grant 1000 XP. Cumulative thresholds across
# levels 1..4 (to reach level 5): 150 + 200 + 250 + 300 = 900. Carry 100 XP
# into level 5. Expect 4 hero_leveled emits: (1→2), (2→3), (3→4), (4→5).
func test_add_xp_multi_level_cascade_emits_per_level_signals() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 11, 1, 0)
	hr.hero_leveled.connect(_on_hero_leveled)
	var ok: bool = hr.add_xp(11, 1000)
	assert_bool(ok).is_true()
	assert_int(hero.current_level).is_equal(5)
	assert_int(hero.xp).is_equal(100)
	assert_int(_spy_emits.size()).is_equal(4)
	assert_array(_spy_emits[0]).is_equal([11, 1, 2])
	assert_array(_spy_emits[1]).is_equal([11, 2, 3])
	assert_array(_spy_emits[2]).is_equal([11, 3, 4])
	assert_array(_spy_emits[3]).is_equal([11, 4, 5])


# ===========================================================================
# Group G — AC-15-05 / §E.6 LEVEL_CAP overflow is discarded
# ===========================================================================

# Hero current_level=14, xp=799. Grant 5000. Hero reaches LEVEL_CAP=15;
# instance.xp == 0 post-grant. One hero_leveled(14, 15) emit (no level-16).
func test_add_xp_at_cap_threshold_discards_overflow() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 21, 14, 799)
	hr.hero_leveled.connect(_on_hero_leveled)
	var ok: bool = hr.add_xp(21, 5000)
	assert_bool(ok).is_true()
	assert_int(hero.current_level).is_equal(hr.level_cap())
	assert_int(hero.xp).is_equal(0)
	assert_int(_spy_emits.size()).is_equal(1)
	assert_array(_spy_emits[0]).is_equal([21, 14, 15])


# §E.6 worked example: Hero level=14, xp=700. Grant 1500. Cascade level 14→15
# uses 800 of the 1500; remaining 700 discarded. Final xp=0.
func test_add_xp_cascade_into_cap_discards_remainder() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 22, 14, 700)
	hr.hero_leveled.connect(_on_hero_leveled)
	hr.add_xp(22, 1500)
	assert_int(hero.current_level).is_equal(hr.level_cap())
	assert_int(hero.xp).is_equal(0)
	assert_int(_spy_emits.size()).is_equal(1)


# Already at LEVEL_CAP — add_xp is a silent no-op (returns true; no mutation).
func test_add_xp_when_already_capped_is_silent_no_op() -> void:
	var hr: Node = _make_fresh_roster()
	var cap: int = hr.level_cap()
	var hero: RefCounted = _inject_hero(hr, 23, cap, 0)
	hr.hero_leveled.connect(_on_hero_leveled)
	var ok: bool = hr.add_xp(23, 9999)
	assert_bool(ok).is_true()
	assert_int(hero.current_level).is_equal(cap)
	assert_int(hero.xp).is_equal(0)
	assert_int(_spy_emits.size()).is_equal(0)


# ===========================================================================
# Group H — AC-15-07 hydration suppression
# ===========================================================================

# With _suppress_signals == true, add_xp mutates state but does NOT emit
# hero_leveled. Audio chime / toast subscribers stay silent during hydration.
func test_add_xp_suppresses_signal_during_hydration() -> void:
	var hr: Node = _make_fresh_roster()
	var hero: RefCounted = _inject_hero(hr, 31, 1, 0)
	hr.hero_leveled.connect(_on_hero_leveled)
	hr._suppress_signals = true
	var ok: bool = hr.add_xp(31, 1000)
	hr._suppress_signals = false
	assert_bool(ok).is_true()
	# State mutates fully even with suppression on.
	assert_int(hero.current_level).is_equal(5)
	assert_int(hero.xp).is_equal(100)
	# But no signal emitted.
	assert_int(_spy_emits.size()).is_equal(0)
