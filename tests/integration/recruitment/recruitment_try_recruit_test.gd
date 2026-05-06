# Sprint 12 S12-M2 — Recruitment.try_recruit transaction integration tests.
#
# Closes recruitment-system.md §J Stories 2 + 4 (AC-RC-04/05/06/07/08/10/12).
# Story 3 (refund path AC-RC-09) is deferred to Sprint 13 — requires DI
# infrastructure for spy HeroRoster (the live add_hero contract violation
# cannot be triggered without injection).
#
# Test groups (live /root/Recruitment + /root/Economy + /root/HeroRoster +
# /root/DataRegistry — all 4 autoloads must be present + functional):
#   A — AC-RC-04 happy path: gold deducted, hero added, signal emitted.
#   B — AC-RC-05 INSUFFICIENT_GOLD: zero mutations, no signal.
#   C — AC-RC-06 ROSTER_FULL: zero mutations, no signal.
#   D — AC-RC-07 INVALID_POOL_INDEX: zero mutations, no signal.
#   E — AC-RC-08 UNRESOLVABLE_CLASS_ID: zero mutations, no signal.
#   F — AC-RC-10 mutation isolation: get_recruit_pool returns a copy.
#   G — AC-RC-12 pool_refreshed signal fires on refresh_pool() + counter
#       increments.
#
# Hygiene barrier: snapshot live Economy + HeroRoster + Recruitment state via
# get_save_data before each test; restore via load_save_data + remove_hero
# loop after. The S10-S4 reset-based pattern, scaled for cross-system
# fixtures.
extends GdUnitTestSuite

const RecruitmentScript = preload("res://src/core/recruitment/recruitment.gd")


# ---------------------------------------------------------------------------
# Hygiene barrier — snapshot/restore live state across the 4 autoloads
# ---------------------------------------------------------------------------

var _snapshot_economy: Dictionary = {}
var _snapshot_recruitment: Dictionary = {}
var _snapshot_roster_ids_pre: Array[int] = []


func _capture_snapshots() -> void:
	var economy: Node = get_tree().root.get_node_or_null("Economy")
	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_snapshot_economy = economy.get_save_data() if economy != null else {}
	_snapshot_recruitment = recruitment.get_save_data() if recruitment != null else {}
	_snapshot_roster_ids_pre = []
	if roster != null:
		var heroes: Array = roster.call("get_all_heroes")
		for h_v: Variant in heroes:
			var h: RefCounted = h_v as RefCounted
			if h != null:
				_snapshot_roster_ids_pre.append(int(h.get("instance_id")))


func _restore_snapshots() -> void:
	var economy: Node = get_tree().root.get_node_or_null("Economy")
	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	# Roster: remove any heroes added during the test (instance_ids absent
	# from the pre-snapshot). load_save_data won't rewind add_hero alone —
	# we explicitly remove the deltas.
	if roster != null:
		var current: Array = roster.call("get_all_heroes")
		for h_v: Variant in current:
			var h: RefCounted = h_v as RefCounted
			if h == null:
				continue
			var id: int = int(h.get("instance_id"))
			if id not in _snapshot_roster_ids_pre:
				roster.call("remove_hero", id)
	# Economy + Recruitment: load_save_data is the canonical restore.
	if economy != null:
		economy.load_save_data(_snapshot_economy)
	if recruitment != null:
		recruitment.load_save_data(_snapshot_recruitment)


func before_test() -> void:
	_capture_snapshots()


func after_test() -> void:
	_restore_snapshots()


# ---------------------------------------------------------------------------
# Signal-spy infrastructure
# ---------------------------------------------------------------------------

var _hero_recruited_calls: Array[Dictionary] = []
var _pool_refreshed_calls: Array[Array] = []


func _on_hero_recruited(hero_instance_id: int, class_id: String, cost_paid: int) -> void:
	_hero_recruited_calls.append({
		"hero_instance_id": hero_instance_id,
		"class_id": class_id,
		"cost_paid": cost_paid,
	})


func _on_pool_refreshed(new_pool: Array[String]) -> void:
	_pool_refreshed_calls.append(new_pool.duplicate())


func _connect_spies(recruitment: Node) -> void:
	_hero_recruited_calls.clear()
	_pool_refreshed_calls.clear()
	if not recruitment.hero_recruited.is_connected(_on_hero_recruited):
		recruitment.hero_recruited.connect(_on_hero_recruited)
	if not recruitment.pool_refreshed.is_connected(_on_pool_refreshed):
		recruitment.pool_refreshed.connect(_on_pool_refreshed)


func _disconnect_spies(recruitment: Node) -> void:
	if recruitment.hero_recruited.is_connected(_on_hero_recruited):
		recruitment.hero_recruited.disconnect(_on_hero_recruited)
	if recruitment.pool_refreshed.is_connected(_on_pool_refreshed):
		recruitment.pool_refreshed.disconnect(_on_pool_refreshed)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _set_pool(recruitment: Node, class_ids: Array[String]) -> void:
	# Typed-array assignment per the project_typed_collection_test_fixtures
	# memory note. _current_pool is Array[String]; untyped literal rejected.
	recruitment._current_pool = class_ids


func _set_gold(amount: int) -> void:
	var economy: Node = get_tree().root.get_node_or_null("Economy")
	economy._gold_balance = amount


func _get_gold() -> int:
	var economy: Node = get_tree().root.get_node_or_null("Economy")
	return economy.get_gold_balance()


func _roster_size() -> int:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	return (roster.call("get_all_heroes") as Array).size()


# ===========================================================================
# Group A — AC-RC-04 happy path
# ===========================================================================

func test_try_recruit_warrior_zero_copies_succeeds_and_deducts_150() -> void:
	# tier 1 warrior, copies 0 → cost=150 (per economy_recruit_cost_test).
	# Ensure the ROSTER_FULL guard does not trip — wipe roster down to size 0
	# for this test by removing all current heroes then setting gold.
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	var current_heroes: Array = roster.call("get_all_heroes")
	for h_v: Variant in current_heroes:
		var h: RefCounted = h_v as RefCounted
		if h != null:
			roster.call("remove_hero", int(h.get("instance_id")))
	assert_int(_roster_size()).is_equal(0)

	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_connect_spies(recruitment)
	_set_pool(recruitment, ["warrior"] as Array[String])
	_set_gold(1000)

	var outcome: int = recruitment.try_recruit(0)

	assert_int(outcome).is_equal(RecruitmentScript.RecruitOutcome.SUCCESS)
	assert_int(_get_gold()).is_equal(850)  # 1000 - 150
	assert_int(_roster_size()).is_equal(1)
	assert_int(_hero_recruited_calls.size()).is_equal(1)
	assert_str(_hero_recruited_calls[0].class_id).is_equal("warrior")
	assert_int(_hero_recruited_calls[0].cost_paid).is_equal(150)

	_disconnect_spies(recruitment)


func test_try_recruit_subsequent_warrior_costs_270_per_geometric_curve() -> void:
	# AC-RC-11 cost-stability adjacent: after recruiting a warrior, the next
	# warrior cost reflects copies_owned=1 → floori(150 × 1.8) = 270.
	# Wipe roster first.
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	for h_v: Variant in roster.call("get_all_heroes"):
		var h: RefCounted = h_v as RefCounted
		if h != null:
			roster.call("remove_hero", int(h.get("instance_id")))

	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_connect_spies(recruitment)
	_set_pool(recruitment, ["warrior", "warrior"] as Array[String])
	_set_gold(1000)

	# First recruit: cost 150
	var outcome1: int = recruitment.try_recruit(0)
	assert_int(outcome1).is_equal(RecruitmentScript.RecruitOutcome.SUCCESS)
	assert_int(_get_gold()).is_equal(850)

	# get_recruit_cost on the second slot now reflects copies_owned=1.
	var second_cost: int = recruitment.get_recruit_cost(1)
	assert_int(second_cost).is_equal(270)

	# Second recruit: cost 270, deducted from 850 → 580.
	var outcome2: int = recruitment.try_recruit(1)
	assert_int(outcome2).is_equal(RecruitmentScript.RecruitOutcome.SUCCESS)
	assert_int(_get_gold()).is_equal(580)
	assert_int(_hero_recruited_calls.size()).is_equal(2)
	assert_int(_hero_recruited_calls[1].cost_paid).is_equal(270)

	_disconnect_spies(recruitment)


# ===========================================================================
# Group B — AC-RC-05 INSUFFICIENT_GOLD
# ===========================================================================

func test_try_recruit_with_insufficient_gold_returns_outcome_and_no_mutations() -> void:
	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_connect_spies(recruitment)
	_set_pool(recruitment, ["warrior"] as Array[String])
	_set_gold(50)  # < 150 cost

	var roster_before: int = _roster_size()
	var outcome: int = recruitment.try_recruit(0)

	assert_int(outcome).is_equal(RecruitmentScript.RecruitOutcome.INSUFFICIENT_GOLD)
	assert_int(_get_gold()).is_equal(50)  # unchanged
	assert_int(_roster_size()).is_equal(roster_before)  # unchanged
	assert_int(_hero_recruited_calls.size()).is_equal(0)

	_disconnect_spies(recruitment)


# ===========================================================================
# Group C — AC-RC-06 ROSTER_FULL
# ===========================================================================

func test_try_recruit_at_roster_cap_returns_roster_full_and_no_mutations() -> void:
	# Fill the roster to max_roster_size first.
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	var max_size: int = int(roster.call("max_roster_size"))
	# Wipe + refill to exactly max_size with warriors.
	for h_v: Variant in roster.call("get_all_heroes"):
		var h: RefCounted = h_v as RefCounted
		if h != null:
			roster.call("remove_hero", int(h.get("instance_id")))
	for _i: int in range(max_size):
		roster.call("add_hero", "warrior")
	assert_int(_roster_size()).is_equal(max_size)

	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_connect_spies(recruitment)
	_set_pool(recruitment, ["warrior"] as Array[String])
	_set_gold(1000000)  # plenty of gold

	var gold_before: int = _get_gold()
	var outcome: int = recruitment.try_recruit(0)

	assert_int(outcome).is_equal(RecruitmentScript.RecruitOutcome.ROSTER_FULL)
	assert_int(_get_gold()).is_equal(gold_before)  # unchanged
	assert_int(_roster_size()).is_equal(max_size)  # unchanged
	assert_int(_hero_recruited_calls.size()).is_equal(0)

	_disconnect_spies(recruitment)


# ===========================================================================
# Group D — AC-RC-07 INVALID_POOL_INDEX
# ===========================================================================

func test_try_recruit_with_negative_pool_index_returns_invalid_index() -> void:
	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_connect_spies(recruitment)
	_set_pool(recruitment, ["warrior"] as Array[String])
	_set_gold(1000)

	var gold_before: int = _get_gold()
	var roster_before: int = _roster_size()

	var outcome: int = recruitment.try_recruit(-1)

	assert_int(outcome).is_equal(RecruitmentScript.RecruitOutcome.INVALID_POOL_INDEX)
	assert_int(_get_gold()).is_equal(gold_before)
	assert_int(_roster_size()).is_equal(roster_before)
	assert_int(_hero_recruited_calls.size()).is_equal(0)

	_disconnect_spies(recruitment)


func test_try_recruit_with_pool_index_at_size_returns_invalid_index() -> void:
	# Index == size is out of [0, size); both negative and at-size hit the
	# same INVALID_POOL_INDEX guard.
	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_connect_spies(recruitment)
	_set_pool(recruitment, ["warrior", "mage"] as Array[String])
	_set_gold(1000)

	var outcome: int = recruitment.try_recruit(2)

	assert_int(outcome).is_equal(RecruitmentScript.RecruitOutcome.INVALID_POOL_INDEX)
	assert_int(_hero_recruited_calls.size()).is_equal(0)

	_disconnect_spies(recruitment)


# ===========================================================================
# Group E — AC-RC-08 UNRESOLVABLE_CLASS_ID
# ===========================================================================

func test_try_recruit_with_orphan_class_id_returns_unresolvable() -> void:
	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_connect_spies(recruitment)
	_set_pool(recruitment, ["not_a_real_class_xyz"] as Array[String])
	_set_gold(1000)

	var gold_before: int = _get_gold()
	var roster_before: int = _roster_size()

	var outcome: int = recruitment.try_recruit(0)

	assert_int(outcome).is_equal(RecruitmentScript.RecruitOutcome.UNRESOLVABLE_CLASS_ID)
	assert_int(_get_gold()).is_equal(gold_before)
	assert_int(_roster_size()).is_equal(roster_before)
	assert_int(_hero_recruited_calls.size()).is_equal(0)

	_disconnect_spies(recruitment)


# ===========================================================================
# Group F — AC-RC-10 mutation isolation
# ===========================================================================

func test_get_recruit_pool_returns_copy_not_internal_array() -> void:
	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_set_pool(recruitment, ["warrior", "mage", "rogue"] as Array[String])

	var pool_returned: Array[String] = recruitment.get_recruit_pool()
	assert_int(pool_returned.size()).is_equal(3)

	# Mutate the returned array.
	pool_returned.clear()

	# Internal state untouched.
	var pool_after: Array[String] = recruitment.get_recruit_pool()
	assert_int(pool_after.size()).is_equal(3)
	assert_str(pool_after[0]).is_equal("warrior")


# ===========================================================================
# Group G — AC-RC-12 pool_refreshed signal + counter increment
# ===========================================================================

func test_refresh_pool_emits_pool_refreshed_signal_with_new_pool() -> void:
	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_connect_spies(recruitment)
	_set_pool(recruitment, ["warrior"] as Array[String])

	var counter_before: int = recruitment._refresh_counter

	recruitment.refresh_pool()

	# Signal emitted exactly once with the new pool snapshot.
	assert_int(_pool_refreshed_calls.size()).is_equal(1)
	# Counter incremented (so RNG seed XOR differs from prior).
	assert_int(recruitment._refresh_counter).is_equal(counter_before + 1)
	# Pool is non-empty (active classes available in DataRegistry).
	assert_int((_pool_refreshed_calls[0] as Array).size()).is_greater(0)

	_disconnect_spies(recruitment)


func test_refresh_pool_paid_with_insufficient_gold_returns_false_no_refresh() -> void:
	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_connect_spies(recruitment)
	_set_pool(recruitment, ["warrior"] as Array[String])
	_set_gold(50)  # < 100 BASE_REFRESH_COST

	var counter_before: int = recruitment._refresh_counter
	var refreshes_today_before: int = recruitment._refreshes_today

	var ok: bool = recruitment.refresh_pool_paid()

	assert_bool(ok).is_false()
	assert_int(recruitment._refresh_counter).is_equal(counter_before)  # unchanged
	assert_int(recruitment._refreshes_today).is_equal(refreshes_today_before)  # unchanged
	assert_int(_pool_refreshed_calls.size()).is_equal(0)
	assert_int(_get_gold()).is_equal(50)  # unchanged

	_disconnect_spies(recruitment)


func test_refresh_pool_paid_with_sufficient_gold_charges_and_refreshes() -> void:
	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	_connect_spies(recruitment)
	_set_pool(recruitment, ["warrior"] as Array[String])
	_set_gold(1000)
	recruitment._refreshes_today = 0  # ensure cost is base 100

	var counter_before: int = recruitment._refresh_counter
	var ok: bool = recruitment.refresh_pool_paid()

	assert_bool(ok).is_true()
	assert_int(_get_gold()).is_equal(900)  # 1000 - 100 BASE_REFRESH_COST
	assert_int(recruitment._refresh_counter).is_equal(counter_before + 1)
	assert_int(recruitment._refreshes_today).is_equal(1)
	assert_int(_pool_refreshed_calls.size()).is_equal(1)

	_disconnect_spies(recruitment)


# ===========================================================================
# AC-RC-11 cost-stability invariant — Sprint 13 S13-S3 closure.
#
# Locks the literal invariant: for each entry i in the pool,
#   get_recruit_cost(i) == Economy.recruit_cost(pool[i],
#                          HeroRoster.get_copies_owned(pool[i]))
# This ensures the cost shown to the player matches the cost charged at
# try_recruit time. The adjacent test
# `test_try_recruit_subsequent_warrior_costs_270_per_geometric_curve`
# covers the post-recruit increment; this test covers the pre-recruit
# parity for arbitrary pool contents.
# ===========================================================================

func test_get_recruit_cost_matches_economy_recruit_cost_contract_for_all_pool_entries() -> void:
	# Wipe roster so copies_owned starts at 0 for all classes.
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	for h_v: Variant in roster.call("get_all_heroes"):
		var h: RefCounted = h_v as RefCounted
		if h != null:
			roster.call("remove_hero", int(h.get("instance_id")))

	var recruitment: Node = get_tree().root.get_node_or_null("Recruitment")
	var economy: Node = get_tree().root.get_node_or_null("Economy")
	assert_object(recruitment).is_not_null()
	assert_object(economy).is_not_null()

	# Seed a 3-entry pool with mixed classes (relies on warrior + mage being
	# in DataRegistry; if mage is unresolvable, the orphan path returns -1
	# from get_recruit_cost AND from Economy.recruit_cost, so the invariant
	# still holds at -1).
	_set_pool(recruitment, ["warrior", "warrior", "mage"] as Array[String])

	# Assert the literal invariant for every pool entry.
	for i: int in range(recruitment.get_recruit_pool().size()):
		var class_id: String = recruitment.get_recruit_pool()[i]
		var copies_owned: int = int(roster.call("get_copies_owned", class_id))
		var displayed_cost: int = recruitment.get_recruit_cost(i)
		var canonical_cost: int = int(economy.call("recruit_cost", class_id, copies_owned))
		assert_int(displayed_cost).override_failure_message(
			"AC-RC-11 invariant broken at pool index %d (class_id=%s, copies_owned=%d): "
			% [i, class_id, copies_owned]
			+ "get_recruit_cost=%d, Economy.recruit_cost=%d"
			% [displayed_cost, canonical_cost]
		).is_equal(canonical_cost)

	# Recruit one warrior so copies_owned for "warrior" advances; assert the
	# invariant STILL holds for the remaining warrior pool entry (index 1)
	# AND for the mage entry (which should be unaffected by warrior copies).
	_set_gold(1000)
	var outcome: int = recruitment.try_recruit(0)
	assert_int(outcome).is_equal(RecruitmentScript.RecruitOutcome.SUCCESS)

	for i: int in range(recruitment.get_recruit_pool().size()):
		var class_id: String = recruitment.get_recruit_pool()[i]
		var copies_owned: int = int(roster.call("get_copies_owned", class_id))
		var displayed_cost: int = recruitment.get_recruit_cost(i)
		var canonical_cost: int = int(economy.call("recruit_cost", class_id, copies_owned))
		assert_int(displayed_cost).override_failure_message(
			"AC-RC-11 invariant broken AFTER recruit at pool index %d (class_id=%s, copies_owned=%d): "
			% [i, class_id, copies_owned]
			+ "get_recruit_cost=%d, Economy.recruit_cost=%d"
			% [displayed_cost, canonical_cost]
		).is_equal(canonical_cost)
