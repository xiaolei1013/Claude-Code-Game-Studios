# US-009 (test-coverage-backfill epic) — direct happy + edge coverage for the
# two HeroRoster public accessors that had zero direct test references in the
# existing suite:
#   * get_retired_hero_records() -> Array[Dictionary]
#   * get_prestige_count() -> int
#
# Both are pure read-only accessors used by UI gating (Hall of Retired Heroes
# button visibility) and analytics. The underlying fields _retired_hero_records
# and _prestige_count are extensively exercised by prestige_v1_test.gd via
# direct field assertions, but the public-getter accessors themselves had no
# call site under assertion. Per US-004 learnings, "the existing suite
# extensively exercised the field but never the getter — pure accessor public
# surface still needs at least one direct call site under assertion."
#
# Test groups:
#   A — get_retired_hero_records: empty initial + populated post-prestige +
#       deep-copy isolation (mutation does not contaminate persisted state)
#   B — get_prestige_count: zero default + monotone increment + identity
#       (read does not mutate)
#
# Per design/gdd/prestige-system.md §C.4 / §C.5 / §F.
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


func _make_roster() -> Node:
	# Mirrors prestige_v1_test.gd::_make_roster — needed because prestige_hero
	# captures retirement_unix_ts via TickSystem.now_ms() per ADR-0005, and the
	# TickSystem wall-clock cache must be warmed in test env.
	var roster: Node = HeroRosterScript.new()
	add_child(roster)
	auto_free(roster)
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


func _add_filler_hero(roster: Node) -> int:
	# AC-PR-20 last-hero protection requires >= 2 heroes for prestige_hero to
	# accept the action. Filler stays in roster throughout each test.
	return _add_hero_at_level(roster, "mage", 1, "Filler")


# ===========================================================================
# Group A — get_retired_hero_records()
# ===========================================================================

func test_get_retired_hero_records_initial_returns_empty_array() -> void:
	# Arrange: fresh roster, no prestige actions yet.
	var roster: Node = _make_roster()

	# Act
	var records: Array[Dictionary] = roster.get_retired_hero_records()

	# Assert: empty list per docstring "Empty list when no prestige action has
	# occurred yet." Type contract: Array[Dictionary].
	assert_int(records.size()).is_equal(0)


func test_get_retired_hero_records_after_prestige_returns_one_record() -> void:
	# Happy path: post-prestige, getter returns 1-element array with the
	# captured snapshot dictionary (display_name, class_id, level_at_retirement,
	# retirement_unix_ts, prestige_index).
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)
	roster.prestige_hero(id)

	var records: Array[Dictionary] = roster.get_retired_hero_records()

	assert_int(records.size()).is_equal(1)
	var rec: Dictionary = records[0]
	assert_str(rec.get("display_name", "")).is_equal("Theron")
	assert_str(rec.get("class_id", "")).is_equal("warrior")
	assert_int(rec.get("level_at_retirement", 0)).is_equal(roster.level_cap())
	assert_int(rec.get("prestige_index", 0)).is_equal(1)
	assert_int(rec.get("retirement_unix_ts", 0)).is_greater(0)


func test_get_retired_hero_records_returns_deep_copy_outer_array_isolated() -> void:
	# Edge: docstring promises "duplicate(true) -> deep copy". Mutations to the
	# returned outer Array (clear, append, erase) MUST NOT contaminate the
	# private _retired_hero_records field. Mirrors the matchup_target_test.gd
	# returns_deep_copy mutation-isolation invariant.
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)
	roster.prestige_hero(id)

	var copy_before: Array[Dictionary] = roster.get_retired_hero_records()
	copy_before.clear()  # consumer mutation
	copy_before.append({"injected": "garbage"})

	var copy_after: Array[Dictionary] = roster.get_retired_hero_records()
	assert_int(copy_after.size()).is_equal(1)
	assert_str(copy_after[0].get("display_name", "")).is_equal("Theron")
	# Confirm the consumer's injected entry never touched persisted state.
	assert_bool(copy_after[0].has("injected")).is_false()


func test_get_retired_hero_records_returns_deep_copy_inner_dict_isolated() -> void:
	# Edge: docstring promises EACH record dictionary is also duplicated, so a
	# UI mutation (e.g., a renderer adding a transient "selected" key to a
	# record) does not contaminate persisted state. This is the "deep copy"
	# part of duplicate(true) — without it, the inner dicts would be shared
	# references between the returned array and the source array.
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)
	roster.prestige_hero(id)

	var copy_before: Array[Dictionary] = roster.get_retired_hero_records()
	copy_before[0]["selected"] = true  # simulated UI consumer mutation
	copy_before[0]["display_name"] = "MUTATED"

	var copy_after: Array[Dictionary] = roster.get_retired_hero_records()
	assert_bool(copy_after[0].has("selected")).is_false()
	assert_str(copy_after[0].get("display_name", "")).is_equal("Theron")


func test_get_retired_hero_records_after_multiple_prestiges_returns_all() -> void:
	# Happy: sequential prestige actions append in order. Confirms the getter
	# enumerates the full list (not just the most recent record), preserving
	# prestige_index ordering 1..N.
	var roster: Node = _make_roster()
	_add_filler_hero(roster)
	var hero_ids: Array[int] = []
	for i: int in range(3):
		hero_ids.append(_add_hero_at_level(
			roster, "warrior", roster.level_cap(), "Hero%d" % i
		))
	for hero_id: int in hero_ids:
		roster.prestige_hero(hero_id)

	var records: Array[Dictionary] = roster.get_retired_hero_records()

	assert_int(records.size()).is_equal(3)
	for i: int in range(3):
		assert_int(records[i].get("prestige_index", 0)).is_equal(i + 1)
		assert_str(records[i].get("display_name", "")).is_equal("Hero%d" % i)


# ===========================================================================
# Group B — get_prestige_count()
# ===========================================================================

func test_get_prestige_count_initial_returns_zero() -> void:
	# Arrange: fresh roster, no prestige actions yet.
	var roster: Node = _make_roster()

	# Act
	var count: int = roster.get_prestige_count()

	# Assert: pure read of _prestige_count field default = 0.
	assert_int(count).is_equal(0)


func test_get_prestige_count_after_one_prestige_returns_one() -> void:
	# Happy: single prestige_hero action increments _prestige_count to 1; the
	# getter must reflect that.
	var roster: Node = _make_roster()
	var id: int = _add_hero_at_level(roster, "warrior", roster.level_cap(), "Theron")
	_add_filler_hero(roster)
	roster.prestige_hero(id)

	assert_int(roster.get_prestige_count()).is_equal(1)


func test_get_prestige_count_monotone_across_three_prestiges() -> void:
	# Happy: sequential prestige actions advance the count monotonically
	# 0 -> 1 -> 2 -> 3. Confirms the getter is a live read of the underlying
	# field, not a stale snapshot.
	var roster: Node = _make_roster()
	_add_filler_hero(roster)
	var hero_ids: Array[int] = []
	for i: int in range(3):
		hero_ids.append(_add_hero_at_level(
			roster, "warrior", roster.level_cap(), "Hero%d" % i
		))

	assert_int(roster.get_prestige_count()).is_equal(0)
	roster.prestige_hero(hero_ids[0])
	assert_int(roster.get_prestige_count()).is_equal(1)
	roster.prestige_hero(hero_ids[1])
	assert_int(roster.get_prestige_count()).is_equal(2)
	roster.prestige_hero(hero_ids[2])
	assert_int(roster.get_prestige_count()).is_equal(3)


func test_get_prestige_count_does_not_mutate_state() -> void:
	# Edge: pure-accessor invariant. Repeated reads must not advance the
	# count (no off-by-one or auto-increment). Mirrors the
	# economy_get_config pure-accessor invariant from US-004.
	var roster: Node = _make_roster()
	roster._prestige_count = 7  # direct field write to seed a known state

	for _i: int in range(10):
		roster.get_prestige_count()

	assert_int(roster._prestige_count).is_equal(7)
	assert_int(roster.get_prestige_count()).is_equal(7)


func test_get_prestige_count_reflects_direct_field_writes() -> void:
	# Edge: live-read invariant. Tests that the getter is not a cached
	# snapshot — direct writes to _prestige_count (used by load_save_data
	# and by the save schema migration path) are immediately visible to the
	# getter without re-querying. Mirrors the pattern of asserting
	# accessor parity with field state across the prestige_v1 suite.
	var roster: Node = _make_roster()
	assert_int(roster.get_prestige_count()).is_equal(0)
	roster._prestige_count = 20  # PRESTIGE_MAX
	assert_int(roster.get_prestige_count()).is_equal(20)
	roster._prestige_count = 0  # reset (e.g., post-load fresh save)
	assert_int(roster.get_prestige_count()).is_equal(0)
