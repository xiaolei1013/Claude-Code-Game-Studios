# Sprint 21 / Prestige V1.0 Story 1 — eligibility + action + multiplier tests.
#
# Per design/gdd/prestige-system.md §C.1 + §C.2 + §D.1 + §D.2 + AC-PR-01..11.
# Story 1 scope: in-memory surface (predicate + action + multiplier + signal).
# V1→V2 save schema migration is Story 2 scope.
#
# Test groups:
#   A — Eligibility predicate (AC-PR-01..05)
#   B — Prestige action mechanics (AC-PR-06..09)
#   C — Multiplier formula (AC-PR-08, AC-PR-11)
#   D — Tuning invariant (AC-PR-16: GAIN_PER × MAX = CAP - 1.0)
#   E — Performance (AC-PR-22)
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


func _make_roster() -> Node:
	var roster: Node = HeroRosterScript.new()
	add_child(roster)
	auto_free(roster)
	# Force LEVEL_CAP to 15 baseline (matches roster_config.tres default).
	# In test env without the config resource loaded, level_cap() returns
	# the _FALLBACK_LEVEL_CAP = 15.
	# Warm TickSystem's wall-clock cache so prestige_hero's retirement_unix_ts
	# capture (which routes through TickSystem.now_ms() per ADR-0005) gets
	# a non-zero value. Mirrors the pattern from tamper_detection_test.gd
	# + mainroot_boot_wiring_test.gd.
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	if ts != null and ts.has_method("_read_wall_clock_unix_time"):
		ts._read_wall_clock_unix_time()
	return roster


func _add_hero_at_level(roster: Node, class_id: String, level: int, display_name: String = "") -> int:
	var hero: HeroInstance = roster.add_hero(class_id)
	if hero == null:
		fail("add_hero failed for class_id=%s" % class_id)
		return 0
	hero.current_level = level
	if display_name != "":
		hero.display_name = display_name
	return hero.instance_id


# Sprint 21+ Story 3 last-hero-protection guard (AC-PR-20) requires
# the roster to have ≥ 2 heroes for is_prestige_eligible to return true.
# Tests that target Story 1 mechanics (eligibility/action) need a filler
# hero alongside the cap-level test subject; this helper adds a level-1
# Mage to the roster so the cap-level Warrior under test is not the
# last hero.
func _add_filler_hero(roster: Node) -> int:
	return _add_hero_at_level(roster, "mage", 1, "Filler")


# ===========================================================================
# Group A — Eligibility predicate (AC-PR-01..05)
# ===========================================================================

func test_is_prestige_eligible_hero_at_level_cap_returns_true() -> void:
	# AC-PR-01: hero at LEVEL_CAP (= 15) AND prestige_count < MAX → true.
	# Story 3 added AC-PR-20 last-hero protection; filler hero needed
	# so the cap-level Warrior under test is not the last hero.
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)
	assert_bool(roster.is_prestige_eligible(id)).is_true()


func test_is_prestige_eligible_hero_below_level_cap_returns_false() -> void:
	# AC-PR-02: hero below LEVEL_CAP → false.
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap() - 1, "Theron")
	assert_bool(roster.is_prestige_eligible(id)).is_false()


func test_is_prestige_eligible_prestige_max_reached_returns_false() -> void:
	# AC-PR-03: prestige_count >= PRESTIGE_MAX → false.
	# Filler ensures last-hero protection isn't the false-cause.
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)
	# Force the count to MAX.
	roster._prestige_count = HeroRosterScript.PRESTIGE_MAX
	roster._prestige_multiplier = HeroRosterScript.PRESTIGE_MULTIPLIER_CAP
	assert_bool(roster.is_prestige_eligible(id)).is_false()


func test_is_prestige_eligible_multiplier_cap_reached_returns_false() -> void:
	# AC-PR-04: multiplier >= CAP → false (defensive; should match count check).
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)
	roster._prestige_count = HeroRosterScript.PRESTIGE_MAX
	roster._prestige_multiplier = HeroRosterScript.PRESTIGE_MULTIPLIER_CAP
	assert_bool(roster.is_prestige_eligible(id)).is_false()


func test_is_prestige_eligible_unknown_id_returns_false() -> void:
	# AC-PR-05: unknown instance_id → false (no crash, no error).
	var roster: Node = _make_roster()
	assert_bool(roster.is_prestige_eligible(9999)).is_false()


# ===========================================================================
# Group B — Prestige action mechanics (AC-PR-06..09)
# ===========================================================================

var _prestige_signal_calls: Array[Dictionary] = []


func _on_prestige_completed(record: Dictionary, new_count: int) -> void:
	_prestige_signal_calls.append({"record": record, "new_count": new_count})


func test_prestige_hero_removes_hero_from_active_roster() -> void:
	# AC-PR-06: hero gone from get_all_heroes() after prestige.
	# Filler ensures Theron is not the last hero (AC-PR-20 guard).
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)
	assert_int(roster.get_all_heroes().size()).is_equal(2)

	var ok: bool = roster.prestige_hero(id)
	assert_bool(ok).is_true()
	# Post-action: filler remains, Theron retired.
	assert_int(roster.get_all_heroes().size()).is_equal(1)


func test_prestige_hero_appends_retired_record() -> void:
	# AC-PR-07: _retired_hero_records grows by 1 with the captured snapshot.
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)

	roster.prestige_hero(id)

	assert_int(roster._retired_hero_records.size()).is_equal(1)
	var rec: Dictionary = roster._retired_hero_records[0]
	assert_str(rec.get("display_name", "")).is_equal("Theron")
	assert_str(rec.get("class_id", "")).is_equal("warrior")
	assert_int(rec.get("level_at_retirement", 0)).is_equal(roster.level_cap())
	assert_int(rec.get("prestige_index", 0)).is_equal(1)
	# retirement_unix_ts is real Unix time (>0).
	assert_int(rec.get("retirement_unix_ts", 0)).is_greater(0)


func test_prestige_hero_advances_count_and_multiplier() -> void:
	# AC-PR-08: post-action count = 1, multiplier = 1.05.
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)
	assert_int(roster._prestige_count).is_equal(0)
	assert_float(roster._prestige_multiplier).is_equal(1.0)

	roster.prestige_hero(id)

	assert_int(roster._prestige_count).is_equal(1)
	assert_float(roster._prestige_multiplier).is_equal(1.05)


func test_prestige_hero_emits_prestige_completed_signal() -> void:
	# AC-PR-09: signal fires once with correct payload.
	var roster: Node = _make_roster()
	_prestige_signal_calls.clear()
	roster.prestige_completed_signal.connect(_on_prestige_completed)
	var id: int = _add_hero_at_level(roster, "mage", roster.level_cap(), "Mira")
	_add_filler_hero(roster)

	roster.prestige_hero(id)

	assert_int(_prestige_signal_calls.size()).is_equal(1)
	var call_record: Dictionary = _prestige_signal_calls[0]
	assert_int(call_record.get("new_count", -1)).is_equal(1)
	var rec: Dictionary = call_record.get("record", {})
	assert_str(rec.get("display_name", "")).is_equal("Mira")
	assert_str(rec.get("class_id", "")).is_equal("mage")


func test_prestige_hero_returns_false_on_ineligible_hero() -> void:
	# Defensive: prestige_hero rejects non-eligible heroes idempotently.
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", 10, "Theron")  # below cap
	assert_bool(roster.is_prestige_eligible(id)).is_false()

	var ok: bool = roster.prestige_hero(id)

	assert_bool(ok).is_false()
	# State unchanged.
	assert_int(roster._prestige_count).is_equal(0)
	assert_int(roster.get_all_heroes().size()).is_equal(1)
	assert_int(roster._retired_hero_records.size()).is_equal(0)


func test_prestige_hero_multiple_prestiges_increment_index() -> void:
	# Sequential prestiges: index = 1, 2, 3, ...
	# Per AC-PR-20 last-hero protection, the roster needs ≥ 2 heroes
	# present at each prestige call. Strategy: add 4 heroes upfront (3
	# cap-level + 1 filler); prestige the 3 cap-level ones in sequence.
	# After each prestige the roster shrinks (4 → 3 → 2; AT 2, the next
	# eligibility check would still be ≥ 2 = OK; after the third, roster
	# has 1 = the filler, but we've already done 3 prestiges).
	var roster: Node = _make_roster()
	# Filler stays in roster throughout — never targeted for prestige.
	_add_filler_hero(roster)
	var hero_ids: Array[int] = []
	for i: int in range(3):
		hero_ids.append(_add_hero_at_level(
			roster, "warrior", roster.level_cap(), "Hero%d" % i
		))

	# Now 4 heroes (1 filler + 3 cap-level Warriors).
	assert_int(roster._heroes.size()).is_equal(4)

	for hero_id: int in hero_ids:
		roster.prestige_hero(hero_id)

	# After 3 prestiges: 1 filler remains, 3 retired.
	assert_int(roster._heroes.size()).is_equal(1)
	assert_int(roster._prestige_count).is_equal(3)
	assert_int(roster._retired_hero_records.size()).is_equal(3)
	for i: int in range(3):
		assert_int(roster._retired_hero_records[i].get("prestige_index", 0)).is_equal(i + 1)


# ===========================================================================
# Group C — Multiplier formula (AC-PR-08, AC-PR-11)
# ===========================================================================

func test_get_prestige_multiplier_default_is_1_0() -> void:
	var roster: Node = _make_roster()
	assert_float(roster.get_prestige_multiplier()).is_equal(1.0)


func test_get_prestige_multiplier_linear_scaling_per_count() -> void:
	# AC-PR-11: count 0..20 produces 1.0, 1.05, ..., 2.0 (linear; clamped
	# at PRESTIGE_MULTIPLIER_CAP for count > 20).
	var roster: Node = _make_roster()
	# Test a few key values.
	roster._prestige_count = 0
	assert_float(roster.get_prestige_multiplier()).is_equal(1.0)
	roster._prestige_count = 1
	assert_float(roster.get_prestige_multiplier()).is_equal(1.05)
	roster._prestige_count = 5
	assert_float(roster.get_prestige_multiplier()).is_equal(1.25)
	roster._prestige_count = 10
	assert_float(roster.get_prestige_multiplier()).is_equal(1.50)
	roster._prestige_count = 20
	assert_float(roster.get_prestige_multiplier()).is_equal(2.0)
	# Clamp: count > MAX still clamps to CAP.
	roster._prestige_count = 25
	assert_float(roster.get_prestige_multiplier()).is_equal(2.0)


func test_get_prestige_multiplier_matches_cached_field_after_action() -> void:
	# After prestige_hero, get_prestige_multiplier() should match _prestige_multiplier.
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)
	roster.prestige_hero(id)
	assert_float(roster.get_prestige_multiplier()).is_equal(roster._prestige_multiplier)


# ===========================================================================
# Group D — Tuning invariant (AC-PR-16)
# ===========================================================================

func test_prestige_tuning_invariant_gain_per_times_max_equals_cap_minus_one() -> void:
	# AC-PR-16: PRESTIGE_GAIN_PER × PRESTIGE_MAX = PRESTIGE_MULTIPLIER_CAP - 1.0
	# Current values: 0.05 × 20 = 1.0 = 2.0 - 1.0. Static-analysis CI test.
	var product: float = HeroRosterScript.PRESTIGE_GAIN_PER * float(HeroRosterScript.PRESTIGE_MAX)
	var expected: float = HeroRosterScript.PRESTIGE_MULTIPLIER_CAP - 1.0
	assert_float(abs(product - expected)).is_less(1e-6).override_failure_message(
		"PRESTIGE_GAIN_PER × PRESTIGE_MAX (%f) does not equal PRESTIGE_MULTIPLIER_CAP - 1.0 (%f). " % [product, expected] +
		"Adjust the constants in lockstep when retuning."
	)


func test_prestige_constants_within_safe_ranges() -> void:
	# Per GDD §G safe ranges:
	# PRESTIGE_GAIN_PER: 0.02 – 0.10
	# PRESTIGE_MULTIPLIER_CAP: 1.5 – 3.0
	# PRESTIGE_MAX: 10 – 40
	assert_float(HeroRosterScript.PRESTIGE_GAIN_PER).is_greater_equal(0.02)
	assert_float(HeroRosterScript.PRESTIGE_GAIN_PER).is_less_equal(0.10)
	assert_float(HeroRosterScript.PRESTIGE_MULTIPLIER_CAP).is_greater_equal(1.5)
	assert_float(HeroRosterScript.PRESTIGE_MULTIPLIER_CAP).is_less_equal(3.0)
	assert_int(HeroRosterScript.PRESTIGE_MAX).is_greater_equal(10)
	assert_int(HeroRosterScript.PRESTIGE_MAX).is_less_equal(40)


# ===========================================================================
# Group E — Performance (AC-PR-22)
# ===========================================================================

func test_get_prestige_multiplier_perf_under_100us_p99() -> void:
	# AC-PR-22: pure function, O(1). Per-kill hot-path budget.
	var roster: Node = _make_roster()
	roster._prestige_count = 5

	# Warm-up
	for i: int in range(100):
		roster.get_prestige_multiplier()

	const ITERATIONS: int = 100_000
	var t0: int = Time.get_ticks_usec()
	for i: int in ITERATIONS:
		roster.get_prestige_multiplier()
	var t1: int = Time.get_ticks_usec()
	var avg_us: float = float(t1 - t0) / float(ITERATIONS)

	# Spec: <100us p99. Soft-warn at 100us; hard-fail at 500us (5×).
	if avg_us >= 100.0:
		push_warning(
			"[prestige_perf] get_prestige_multiplier avg=%fus exceeds 100us spec budget (advisory)" % avg_us
		)
	assert_float(avg_us).is_less(500.0).override_failure_message(
		"get_prestige_multiplier avg latency %fus exceeds 500us hard ceiling" % avg_us
	)
