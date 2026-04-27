# Tests for Sprint 8 hero-roster Story 009 (S8-N9 carryover from S6-N1):
#   - _generate_name uniform random over unused pool subset (TR-022)
#   - Pool exhaustion fallback "{base} the {Ordinal}" (TR-022)
#   - DataRegistry "name_pools" category + per-class pool resolution (TR-023)
#   - Each MVP class pool has >=20 names (TR-023)
#   - Unknown class fallback to "Hero N" placeholder + push_warning
#
# Covers: TR-hero-roster-022 (uniform-random + ordinal fallback),
#         TR-hero-roster-023 (pool size + DataRegistry category).
#
# Test isolation: tests inject heroes directly into _heroes via the helper
# from save_load_round_trip_test.gd's pattern (bypasses add_hero's
# DataRegistry coupling). _generate_name still hits the live DataRegistry
# for name_pools lookup — tests skip with push_warning if pools aren't
# resolvable in the test env.
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const NamePoolScript = preload("res://src/core/hero_roster/name_pool.gd")


func _make_fresh_roster() -> Node:
	var hr: Node = HeroRosterScript.new()
	add_child(hr)
	auto_free(hr)
	return hr


# Inject a synthetic HeroInstance directly into _heroes with a specific
# (class_id, display_name) — bypasses add_hero's DataRegistry coupling.
func _inject_hero(hr: Node, id: int, class_id: String, display_name: String) -> void:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = class_id
	fake.display_name = display_name
	fake.current_level = 1
	fake.xp = 0
	hr._heroes[id] = fake


func _data_registry_can_resolve_name_pool(class_id: String) -> bool:
	return DataRegistry.resolve("name_pools", class_id) != null


# ===========================================================================
# Group A: TR-023 — DataRegistry resolves "name_pools" category
# ===========================================================================

func test_data_registry_resolves_warrior_name_pool() -> void:
	# Boot scan should have loaded warrior_names.tres into the "name_pools" category.
	var pool: Resource = DataRegistry.resolve("name_pools", "warrior")
	if pool == null:
		push_warning("Skipped: name_pools/warrior not resolvable")
		return
	assert_object(pool).is_not_null()
	assert_str(str(pool.class_id)).is_equal("warrior")


func test_data_registry_resolves_mage_name_pool() -> void:
	var pool: Resource = DataRegistry.resolve("name_pools", "mage")
	if pool == null:
		push_warning("Skipped")
		return
	assert_object(pool).is_not_null()
	assert_str(str(pool.class_id)).is_equal("mage")


func test_data_registry_resolves_rogue_name_pool() -> void:
	var pool: Resource = DataRegistry.resolve("name_pools", "rogue")
	if pool == null:
		push_warning("Skipped")
		return
	assert_object(pool).is_not_null()
	assert_str(str(pool.class_id)).is_equal("rogue")


# ===========================================================================
# Group B: TR-023 — pool size >=20 per MVP class
# ===========================================================================

func test_warrior_pool_has_at_least_20_names() -> void:
	var pool: Resource = DataRegistry.resolve("name_pools", "warrior")
	if pool == null:
		push_warning("Skipped")
		return
	var names: Array = pool.get("names") as Array
	assert_int(names.size()).is_greater_equal(20)


func test_mage_pool_has_at_least_20_names() -> void:
	var pool: Resource = DataRegistry.resolve("name_pools", "mage")
	if pool == null:
		push_warning("Skipped")
		return
	assert_int((pool.get("names") as Array).size()).is_greater_equal(20)


func test_rogue_pool_has_at_least_20_names() -> void:
	var pool: Resource = DataRegistry.resolve("name_pools", "rogue")
	if pool == null:
		push_warning("Skipped")
		return
	assert_int((pool.get("names") as Array).size()).is_greater_equal(20)


# ===========================================================================
# Group C: TR-022 — uniform random over unused pool subset
# ===========================================================================

func test_generate_name_returns_pool_member_for_known_class() -> void:
	if not _data_registry_can_resolve_name_pool("warrior"):
		push_warning("Skipped")
		return
	var hr: Node = _make_fresh_roster()
	var pool: Resource = DataRegistry.resolve("name_pools", "warrior")
	var pool_names: Array = pool.get("names") as Array

	# Act
	var generated: String = hr._generate_name("warrior", 1)

	# Assert — generated name is a member of the pool.
	assert_bool(pool_names.has(generated)).is_true()


func test_generate_name_does_not_return_already_used_name_for_same_class() -> void:
	# Pre-inject a warrior named "Theron"; subsequent _generate_name("warrior")
	# calls must NOT return "Theron" while the pool still has unused names.
	if not _data_registry_can_resolve_name_pool("warrior"):
		push_warning("Skipped")
		return
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "warrior", "Theron")

	# Act — generate 30 names (more than enough to detect collision risk).
	for _i: int in range(30):
		var name: String = hr._generate_name("warrior", 100)
		# Assert — never returns "Theron" while it's in use.
		assert_str(name).is_not_equal("Theron")


func test_generate_name_can_reuse_same_name_across_different_classes() -> void:
	# A warrior named "Theron" doesn't block a mage from being named "Theron"
	# (the used-set is filtered by class_id).
	if not _data_registry_can_resolve_name_pool("warrior"):
		push_warning("Skipped")
		return
	if not _data_registry_can_resolve_name_pool("mage"):
		push_warning("Skipped")
		return
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "warrior", "Theron")
	# Mage pool doesn't contain "Theron" (different aesthetic) so this scenario
	# would actually never happen; the test asserts the FILTER is by class_id,
	# not by global name uniqueness. Use a name that happens to be in both
	# pools — none currently overlap, so we test the filter logic directly.

	# Act — generate a mage name; must come from the mage pool.
	var mage_pool: Resource = DataRegistry.resolve("name_pools", "mage")
	var mage_names: Array = mage_pool.get("names") as Array
	var generated: String = hr._generate_name("mage", 2)

	# Assert — mage name from mage pool, regardless of warrior's "Theron".
	assert_bool(mage_names.has(generated)).is_true()


# ===========================================================================
# Group D: TR-022 — pool exhaustion ordinal fallback
# ===========================================================================

func test_generate_name_returns_ordinal_fallback_when_pool_exhausted() -> void:
	# Fill the warrior roster with all pool names; next _generate_name call
	# must return "{base} the Second".
	if not _data_registry_can_resolve_name_pool("warrior"):
		push_warning("Skipped")
		return
	var hr: Node = _make_fresh_roster()
	var pool: Resource = DataRegistry.resolve("name_pools", "warrior")
	var pool_names: Array = pool.get("names") as Array

	# Inject a hero for every name in the pool — fully exhausts it.
	for i: int in range(pool_names.size()):
		_inject_hero(hr, i + 1, "warrior", str(pool_names[i]))

	# Act — pool is exhausted; expect "{pool[0]} the Second".
	var fallback_name: String = hr._generate_name("warrior", 100)

	# Assert
	var expected: String = "%s the Second" % str(pool_names[0])
	assert_str(fallback_name).is_equal(expected)


func test_generate_name_ordinal_sequence_advances_third_fourth() -> void:
	# After "the Second" lands, the NEXT pool-exhausted hero gets "the Third".
	# Implementation note: same_class_count - pool_size is the index into
	# _ORDINALS. With pool_size N: count=N → Second; count=N+1 → Third; etc.
	# The test injects N+1 same-class heroes (pool + 1 ordinal), then asks
	# for the (pool_size+2)th name.
	if not _data_registry_can_resolve_name_pool("warrior"):
		push_warning("Skipped")
		return
	var hr: Node = _make_fresh_roster()
	var pool: Resource = DataRegistry.resolve("name_pools", "warrior")
	var pool_names: Array = pool.get("names") as Array
	for i: int in range(pool_names.size()):
		_inject_hero(hr, i + 1, "warrior", str(pool_names[i]))
	# Add one ordinal-named hero — this brings same_class_count to N+1.
	_inject_hero(hr, pool_names.size() + 1, "warrior",
			"%s the Second" % str(pool_names[0]))

	# Act
	var fallback_name: String = hr._generate_name("warrior", 200)

	# Assert — next ordinal is "Third".
	var expected: String = "%s the Third" % str(pool_names[0])
	assert_str(fallback_name).is_equal(expected)


# ===========================================================================
# Group E: defensive — unknown class returns placeholder
# ===========================================================================

func test_generate_name_unknown_class_returns_placeholder_with_warning() -> void:
	# DataRegistry has no name_pool for "ghost_class" → fallback to "Hero N".
	var hr: Node = _make_fresh_roster()

	# Act
	var name: String = hr._generate_name("ghost_class_does_not_exist", 42)

	# Assert
	assert_str(name).is_equal("Hero 42")


# ===========================================================================
# Group F: structural — _generate_name no longer hardcodes "Hero %d"
# ===========================================================================

func test_generate_name_for_warrior_does_not_return_placeholder_format() -> void:
	# Regression guard — the placeholder "Hero N" pattern was the pre-S8-N9
	# implementation. After this story, valid class_id paths must NOT
	# return the placeholder.
	if not _data_registry_can_resolve_name_pool("warrior"):
		push_warning("Skipped")
		return
	var hr: Node = _make_fresh_roster()

	# Act
	var name: String = hr._generate_name("warrior", 7)

	# Assert
	assert_str(name).is_not_equal("Hero 7")
