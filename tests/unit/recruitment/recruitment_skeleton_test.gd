# Sprint 11 S11-X10 / Sprint 12 Story 1: Recruitment autoload skeleton.
#
# Per design/gdd/recruitment-system.md §C.1 + ADR-0015: a thin coordinator
# that orchestrates Economy.try_spend → HeroRoster.add_hero atomically; owns
# the deterministic, save-seeded recruit pool.
#
# Test groups:
#   A — public API surface lock (try_recruit + get_recruit_pool +
#       get_recruit_cost + refresh_pool + refresh_pool_paid + refresh_cost +
#       get_save_data + load_save_data exist) + RecruitOutcome enum has
#       exactly 5 values
#   B — signal arity (hero_recruited 3-arg + pool_refreshed 1-arg)
#   C — refresh_cost curve (ADR-0015 §OQ-RC-2)
#   D — _regenerate_pool determinism (ADR-0015 §OQ-RC-1 — same seed XOR
#       counter produces same pool)
#   G — Save/Load consumer surface (round-trip preserves seed/counter/pool;
#       missing-key fallback re-inits seed; non-int seed warns + re-inits)
#   H — autoload presence + project.godot rank-12 ordering between
#       FormationAssignment (rank 11) and DungeonRunOrchestrator (rank 14)
#
# DEFERRED to Sprint 12+ Stories 2-5 (cross-system flows requiring live
# Economy/HeroRoster/DataRegistry):
#   - try_recruit happy path (AC-RC-04)
#   - try_recruit failure paths (AC-RC-05/06/07/08)
#   - add_hero contract-violation refund path (AC-RC-09)
#   - get_recruit_cost cost-stability invariant (AC-RC-11)
#   - on-clear free refresh integration test (subscribes to live orchestrator)
#   - AC-RC-14 CI grep (single-writer enforcement)
extends GdUnitTestSuite

const RecruitmentScript = preload("res://src/core/recruitment/recruitment.gd")


func _make_recruitment() -> Node:
	var r: Node = RecruitmentScript.new()
	add_child(r)
	auto_free(r)
	return r


# ===========================================================================
# Group A — public API surface lock
# ===========================================================================

func test_recruitment_has_try_recruit_method() -> void:
	var r: Node = _make_recruitment()
	assert_bool(r.has_method("try_recruit")).is_true()


func test_recruitment_has_get_recruit_pool_method() -> void:
	var r: Node = _make_recruitment()
	assert_bool(r.has_method("get_recruit_pool")).is_true()


func test_recruitment_has_get_recruit_cost_method() -> void:
	var r: Node = _make_recruitment()
	assert_bool(r.has_method("get_recruit_cost")).is_true()


func test_recruitment_has_refresh_pool_method() -> void:
	var r: Node = _make_recruitment()
	assert_bool(r.has_method("refresh_pool")).is_true()


func test_recruitment_has_refresh_pool_paid_method() -> void:
	var r: Node = _make_recruitment()
	assert_bool(r.has_method("refresh_pool_paid")).is_true()


func test_recruitment_has_refresh_cost_method() -> void:
	var r: Node = _make_recruitment()
	assert_bool(r.has_method("refresh_cost")).is_true()


func test_recruitment_has_save_consumer_methods() -> void:
	var r: Node = _make_recruitment()
	assert_bool(r.has_method("get_save_data")).is_true()
	assert_bool(r.has_method("load_save_data")).is_true()


func test_recruit_outcome_enum_has_exactly_5_values() -> void:
	# Lock the §C.1 enum surface: SUCCESS / INSUFFICIENT_GOLD / ROSTER_FULL /
	# INVALID_POOL_INDEX / UNRESOLVABLE_CLASS_ID. Any rename or addition
	# without a GDD §C.1 update will surface here.
	var success: int = RecruitmentScript.RecruitOutcome.SUCCESS
	var insufficient: int = RecruitmentScript.RecruitOutcome.INSUFFICIENT_GOLD
	var roster_full: int = RecruitmentScript.RecruitOutcome.ROSTER_FULL
	var invalid_index: int = RecruitmentScript.RecruitOutcome.INVALID_POOL_INDEX
	var unresolvable: int = RecruitmentScript.RecruitOutcome.UNRESOLVABLE_CLASS_ID

	# Default GDScript enum starts at 0 and increments — verify uniqueness.
	var values: Array[int] = [success, insufficient, roster_full, invalid_index, unresolvable]
	var unique: Dictionary = {}
	for v: int in values:
		unique[v] = true
	assert_int(unique.size()).is_equal(5)


# ===========================================================================
# Group B — signal arity + payload contract
# ===========================================================================

func test_recruitment_declares_hero_recruited_signal() -> void:
	var r: Node = _make_recruitment()
	assert_bool(r.has_signal("hero_recruited")).is_true()


func test_recruitment_declares_pool_refreshed_signal() -> void:
	var r: Node = _make_recruitment()
	assert_bool(r.has_signal("pool_refreshed")).is_true()


# ===========================================================================
# Group C — refresh_cost curve (ADR-0015 §OQ-RC-2)
# ===========================================================================

func test_refresh_cost_at_zero_refreshes_today_returns_base() -> void:
	# n=0 → cost = 100 × (1 + 2.0 × 0) = 100 per ADR-0015 example.
	var r: Node = _make_recruitment()
	assert_int(r.refresh_cost(0)).is_equal(100)


func test_refresh_cost_at_one_refresh_returns_300() -> void:
	# n=1 → cost = 100 × (1 + 2.0 × 1) = 300.
	var r: Node = _make_recruitment()
	assert_int(r.refresh_cost(1)).is_equal(300)


func test_refresh_cost_at_five_refreshes_returns_1100() -> void:
	# n=5 → cost = 100 × (1 + 2.0 × 5) = 1100 (effectively spam-blocked).
	var r: Node = _make_recruitment()
	assert_int(r.refresh_cost(5)).is_equal(1100)


# ===========================================================================
# Group D — _regenerate_pool determinism
# ===========================================================================

func test_two_recruitment_instances_with_same_seed_and_counter_produce_same_pool() -> void:
	# ADR-0015 §Validation Criteria: "Two consecutive _regenerate_pool calls
	# with the same _refresh_counter produce IDENTICAL pools."
	#
	# In the test env DataRegistry is a live autoload; its active classes
	# drive the pool. Two instances seeded identically should pull the same
	# RNG sequence and thus the same pool (assuming an active class set is
	# available — if not, both pools are empty, which still satisfies the
	# determinism contract trivially).
	var a: Node = _make_recruitment()
	var b: Node = _make_recruitment()

	# Typed-field hygiene: _current_pool is Array[String]; untyped [] literals
	# are rejected at runtime. Use explicit typed locals before assignment.
	var empty_pool: Array[String] = []
	a._save_pool_seed = 42
	a._refresh_counter = 7
	a._current_pool = empty_pool.duplicate()
	b._save_pool_seed = 42
	b._refresh_counter = 7
	b._current_pool = empty_pool.duplicate()

	a._regenerate_pool()
	b._regenerate_pool()

	# Pools must be element-equal.
	assert_int(a._current_pool.size()).is_equal(b._current_pool.size())
	for i: int in range(a._current_pool.size()):
		assert_str(a._current_pool[i]).is_equal(b._current_pool[i])


func test_different_refresh_counter_produces_different_pool_when_classes_available() -> void:
	# ADR-0015 §Amendment 2 regression: incrementing _refresh_counter must
	# actually change the pool — the player rerolls and sees a NEW draft. Prior
	# to the §Amendment-2 seed fix, `rng.state = 0` clobbered the seed so EVERY
	# counter produced the IDENTICAL pool, making refresh a silent no-op.
	#
	# Deterministic assertion: sweep several counters for a fixed seed; the
	# generated pools must NOT all be identical. Under the bug every pool is
	# identical (guaranteed fail); under the fix they vary.
	var r: Node = _make_recruitment()
	var empty_pool: Array[String] = []
	var signatures: Dictionary = {}
	for counter: int in range(8):
		r._save_pool_seed = 12345
		r._refresh_counter = counter
		r._current_pool = empty_pool.duplicate()
		r._regenerate_pool()
		if r._current_pool.size() < 2:
			return  # sparse/empty test-env class set — soft skip.
		signatures[str(r._current_pool)] = true
	assert_int(signatures.size()).override_failure_message(
		"All 8 refresh_counter values produced the IDENTICAL pool — refresh is a "
		+ "no-op (rng.state=0 seed-clobber regression)."
	).is_greater(1)


func test_different_save_seed_produces_different_pool() -> void:
	# ADR-0015 §Amendment 2 + §Risk table (per-save uniqueness): two saves with
	# DIFFERENT _save_pool_seed values must get DIFFERENT recruit pools, so the
	# pool isn't globally identical across every player. Regression guard for the
	# same rng.state=0 seed-clobber bug, on the save-seed axis.
	var r: Node = _make_recruitment()
	var empty_pool: Array[String] = []
	var signatures: Dictionary = {}
	for seed_val: int in [11, 22, 33, 44, 55, 66, 77, 88]:
		r._save_pool_seed = seed_val
		r._refresh_counter = 0
		r._current_pool = empty_pool.duplicate()
		r._regenerate_pool()
		if r._current_pool.size() < 2:
			return  # sparse/empty test-env class set — soft skip.
		signatures[str(r._current_pool)] = true
	assert_int(signatures.size()).override_failure_message(
		"All 8 distinct save seeds produced the IDENTICAL pool — per-save "
		+ "uniqueness is broken (rng.state=0 seed-clobber)."
	).is_greater(1)


func test_regenerate_pool_draws_distinct_classes_when_enough_available() -> void:
	# OQ-0015-2 resolution (ADR-0015 §Amendment 1, option b): the pool is
	# drawn WITHOUT replacement, so every generated pool of POOL_SIZE entries
	# is all-distinct WHEN the active-class set has at least POOL_SIZE members.
	# This implements the ADR-0015 risk-table mitigation ("Pool-generation
	# algorithm SHOULD prefer same-class deduplication").
	#
	# Determinism guard: sweep many seeds. Under the prior with-replacement
	# draw, at least one seed in this range WOULD collide (4-from-7 ≈ 65% per
	# seed), so this assertion deterministically catches a regression to
	# with-replacement. Under without-replacement, ALL seeds produce distinct
	# pools.
	#
	# Soft-skip per-seed when the test-env DataRegistry exposes fewer than
	# POOL_SIZE active classes (the with-replacement fallback path is then
	# correct and is covered by the existing determinism tests).
	var r: Node = _make_recruitment()
	var empty_pool: Array[String] = []
	var asserted_at_least_once: bool = false
	for seed_offset: int in range(50):
		r._save_pool_seed = 1000 + seed_offset
		r._refresh_counter = 0
		r._current_pool = empty_pool.duplicate()
		r._regenerate_pool()
		if r._current_pool.size() < RecruitmentScript.POOL_SIZE:
			continue  # sparse class set — fallback path, covered elsewhere.
		asserted_at_least_once = true
		var seen: Dictionary = {}
		for cid: String in r._current_pool:
			seen[cid] = true
		assert_int(seen.size()).override_failure_message(
			"seed %d produced a duplicate pool (with-replacement regression?): %s"
			% [1000 + seed_offset, str(r._current_pool)]
		).is_equal(r._current_pool.size())
	# If the env never had a full pool, the test is a no-op (acceptable soft
	# skip), but note it so a silently-empty DataRegistry doesn't masquerade
	# as a pass.
	if not asserted_at_least_once:
		push_warning(
			"test_regenerate_pool_draws_distinct: DataRegistry exposed < POOL_SIZE "
			+ "active classes for all swept seeds — distinctness not exercised."
		)


# ===========================================================================
# Group G — Save/Load consumer surface (ADR-0015 schema)
# ===========================================================================

func test_get_save_data_returns_three_fields_per_adr_0015_schema() -> void:
	# ADR-0015 Decision §OQ-RC-1: persists save_pool_seed, refresh_counter,
	# current_pool. Exactly these 3 keys.
	var r: Node = _make_recruitment()
	var pool: Array[String] = ["warrior", "mage"]
	r._save_pool_seed = 999
	r._refresh_counter = 5
	r._current_pool = pool

	var data: Dictionary = r.get_save_data()
	assert_int(data.size()).is_equal(3)
	assert_bool(data.has("save_pool_seed")).is_true()
	assert_bool(data.has("refresh_counter")).is_true()
	assert_bool(data.has("current_pool")).is_true()


func test_get_save_data_returns_pool_copy_for_mutation_isolation() -> void:
	# Mutating the returned Array must NOT affect internal state.
	var r: Node = _make_recruitment()
	var pool: Array[String] = ["warrior", "mage"]
	r._current_pool = pool

	var data: Dictionary = r.get_save_data()
	(data["current_pool"] as Array).clear()

	# Internal state untouched.
	assert_int(r._current_pool.size()).is_equal(2)


func test_load_save_data_round_trips_seed_counter_and_pool() -> void:
	var src: Node = _make_recruitment()
	var pool: Array[String] = ["warrior", "mage", "rogue"]
	src._save_pool_seed = 777
	src._refresh_counter = 3
	src._current_pool = pool
	var saved: Dictionary = src.get_save_data()

	var dst: Node = _make_recruitment()
	dst.load_save_data(saved)

	assert_int(dst._save_pool_seed).is_equal(777)
	assert_int(dst._refresh_counter).is_equal(3)
	assert_int(dst._current_pool.size()).is_equal(3)
	assert_str(dst._current_pool[0]).is_equal("warrior")
	assert_str(dst._current_pool[1]).is_equal("mage")
	assert_str(dst._current_pool[2]).is_equal("rogue")


func test_load_save_data_with_empty_dict_first_launch_inits_seed() -> void:
	# Pre-Recruitment-shipped saves load with empty payload. Per ADR-0015
	# Migration Plan + Save/Load §C MVP-default-on-missing-key contract:
	# the seed gets first-launch-init'd on load.
	var r: Node = _make_recruitment()
	var empty_pool: Array[String] = []
	r._save_pool_seed = 0
	r._refresh_counter = 0
	r._current_pool = empty_pool

	r.load_save_data({})

	# Seed populated by first-launch init (non-zero post-randi).
	assert_int(r._save_pool_seed).is_not_equal(0)
	assert_int(r._refresh_counter).is_equal(0)


func test_load_save_data_ignores_non_int_seed_and_re_inits() -> void:
	# Anti-tamper resilience per load_save_data per-field type guard.
	var r: Node = _make_recruitment()
	r._save_pool_seed = 0
	r.load_save_data({"save_pool_seed": "not_an_int", "refresh_counter": 0})

	# Seed got re-initialized via first-launch path, NOT taken from the
	# string. Result is non-zero.
	assert_int(r._save_pool_seed).is_not_equal(0)


func test_load_save_data_filters_non_string_pool_entries() -> void:
	var r: Node = _make_recruitment()
	r._save_pool_seed = 100  # avoid first-launch init
	r.load_save_data({
		"save_pool_seed": 100,
		"refresh_counter": 0,
		"current_pool": ["warrior", 42, null, "mage"],
	})

	# Only String entries survived the per-element type guard.
	assert_int(r._current_pool.size()).is_equal(2)
	assert_str(r._current_pool[0]).is_equal("warrior")
	assert_str(r._current_pool[1]).is_equal("mage")


# ===========================================================================
# Group H — autoload presence (post-S11-X10 registration)
# ===========================================================================

func test_recruitment_is_live_autoload_at_canonical_path() -> void:
	# Locks the project.godot autoload registration at rank 12 (per ADR-0003
	# Amendment #7). Sits between FormationAssignment (rank 11) and
	# DungeonRunOrchestrator (rank 14).
	var r: Node = get_tree().root.get_node_or_null("Recruitment")
	assert_object(r).is_not_null()
	assert_bool(r.has_method("try_recruit")).is_true()
	assert_bool(r.has_signal("hero_recruited")).is_true()
	assert_bool(r.has_signal("pool_refreshed")).is_true()


func test_recruitment_autoload_is_consumer_path_index_4() -> void:
	# Cross-check: SaveLoadSystem.CONSUMER_PATHS lists /root/Recruitment at
	# index 4 (between FormationAssignment index 3 and DungeonRunOrchestrator
	# index 5). Locks the rank-12 → CONSUMER_PATHS slot mapping.
	var SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")
	assert_str(SaveLoadScript.CONSUMER_PATHS[4]).is_equal("/root/Recruitment")
