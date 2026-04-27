# Tests for Sprint 6 hero-roster Story 004: add_hero + remove_hero + 3 signals.
# Covers: TR-hero-roster-008 (add_hero contract — returns null on cap or
#                              unresolvable; increments _next_instance_id AFTER
#                              success; remove_hero is included for completeness),
#         TR-hero-roster-009 (3 signals — hero_recruited/hero_leveled/hero_removed),
#         TR-hero-roster-011 (monotonic _next_instance_id; failed add does not
#                              consume an id).
#
# Each test uses a fresh HeroRoster instance (NOT the autoload singleton) to
# guarantee isolation. The fresh instance still consults the live DataRegistry
# singleton — when DataRegistry is in ERROR state (FOLLOWUP-002 / S6-M12), tests
# that need a resolvable class skip with push_warning per the EconomyConfig
# precedent at tests/unit/economy/economy_config_schema_test.gd:286.
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const TEST_CLASS_ID := "warrior"
const UNKNOWN_CLASS_ID := "ghost_class_does_not_exist"


# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

# Build a fresh HeroRoster Node and add to scene tree so _ready() runs and the
# config resolves. Caller frees via auto_free().
func _make_fresh_roster() -> Node:
	var hr: Node = HeroRosterScript.new()
	add_child(hr)
	auto_free(hr)
	# _ready() ran on add_child; _config + _formation_slots are populated.
	return hr


# Detect if DataRegistry can resolve TEST_CLASS_ID. When false, success-path
# tests skip with push_warning (FOLLOWUP-002 / S6-M12 known issue).
func _data_registry_can_resolve_test_class() -> bool:
	return DataRegistry.resolve("classes", TEST_CLASS_ID) != null


# ===========================================================================
# Group A: add_hero success path (TR-008)
# ===========================================================================

func test_add_hero_returns_non_null_instance_for_valid_class() -> void:
	if not _data_registry_can_resolve_test_class():
		push_warning(
			"test_add_hero_returns_non_null_instance_for_valid_class: skipped — "
			+ "DataRegistry cannot resolve '%s' (FOLLOWUP-002). Deferred to smoke check."
			% TEST_CLASS_ID
		)
		return
	var hr: Node = _make_fresh_roster()
	var instance: RefCounted = hr.add_hero(TEST_CLASS_ID)
	assert_object(instance).is_not_null()


func test_add_hero_assigns_monotonic_instance_id_starting_at_1() -> void:
	if not _data_registry_can_resolve_test_class():
		push_warning("Skipped: DataRegistry not resolving TEST_CLASS_ID")
		return
	var hr: Node = _make_fresh_roster()
	var first: RefCounted = hr.add_hero(TEST_CLASS_ID)
	assert_int(first.instance_id).is_equal(1)
	var second: RefCounted = hr.add_hero(TEST_CLASS_ID)
	assert_int(second.instance_id).is_equal(2)


func test_add_hero_increments_next_instance_id_after_success() -> void:
	if not _data_registry_can_resolve_test_class():
		push_warning("Skipped: DataRegistry not resolving TEST_CLASS_ID")
		return
	var hr: Node = _make_fresh_roster()
	assert_int(hr._next_instance_id).is_equal(1)
	hr.add_hero(TEST_CLASS_ID)
	assert_int(hr._next_instance_id).is_equal(2)
	hr.add_hero(TEST_CLASS_ID)
	assert_int(hr._next_instance_id).is_equal(3)


func test_add_hero_inserts_into_heroes_dict_keyed_by_instance_id() -> void:
	if not _data_registry_can_resolve_test_class():
		push_warning("Skipped: DataRegistry not resolving TEST_CLASS_ID")
		return
	var hr: Node = _make_fresh_roster()
	var instance: RefCounted = hr.add_hero(TEST_CLASS_ID)
	assert_int(hr._heroes.size()).is_equal(1)
	assert_bool(hr._heroes.has(instance.instance_id)).is_true()
	assert_object(hr._heroes[instance.instance_id]).is_same(instance)


func test_add_hero_sets_class_id_on_instance() -> void:
	if not _data_registry_can_resolve_test_class():
		push_warning("Skipped: DataRegistry not resolving TEST_CLASS_ID")
		return
	var hr: Node = _make_fresh_roster()
	var instance: RefCounted = hr.add_hero(TEST_CLASS_ID)
	assert_str(instance.class_id).is_equal(TEST_CLASS_ID)


func test_add_hero_sets_default_level_one_and_xp_zero() -> void:
	if not _data_registry_can_resolve_test_class():
		push_warning("Skipped: DataRegistry not resolving TEST_CLASS_ID")
		return
	var hr: Node = _make_fresh_roster()
	var instance: RefCounted = hr.add_hero(TEST_CLASS_ID)
	assert_int(instance.current_level).is_equal(1)
	assert_int(instance.xp).is_equal(0)


func test_add_hero_assigns_display_name_from_warrior_name_pool() -> void:
	# Sprint 8 S8-N9 (Story 009) landed the name pool implementation —
	# add_hero now assigns a display_name from the per-class NamePool resource
	# instead of the legacy "Hero N" placeholder. Verify the new contract:
	# the assigned name is a member of the warrior pool.
	if not _data_registry_can_resolve_test_class():
		push_warning("Skipped: DataRegistry not resolving TEST_CLASS_ID")
		return
	var pool: Resource = DataRegistry.resolve("name_pools", TEST_CLASS_ID)
	if pool == null:
		push_warning("Skipped: name_pools/warrior not resolvable in test env")
		return
	var hr: Node = _make_fresh_roster()
	var instance: RefCounted = hr.add_hero(TEST_CLASS_ID)
	# Assigned display_name must be a member of the warrior pool (Sprint 8
	# S8-N9 contract; replaces the pre-S8-N9 "Hero N" placeholder assertion).
	var pool_names: Array = pool.get("names") as Array
	assert_bool(pool_names.has(instance.display_name)).is_true()


# ===========================================================================
# Group B: hero_recruited signal (TR-008, TR-009)
# ===========================================================================

# Simple counter-based spy. Lambdas capture by reference in GDScript.
var _spy_recruit_count: int = 0
var _spy_recruit_payload: RefCounted = null


func _on_hero_recruited(instance: RefCounted) -> void:
	_spy_recruit_count += 1
	_spy_recruit_payload = instance


func test_add_hero_emits_hero_recruited_exactly_once_on_success() -> void:
	if not _data_registry_can_resolve_test_class():
		push_warning("Skipped: DataRegistry not resolving TEST_CLASS_ID")
		return
	_spy_recruit_count = 0
	_spy_recruit_payload = null
	var hr: Node = _make_fresh_roster()
	hr.hero_recruited.connect(_on_hero_recruited)
	var instance: RefCounted = hr.add_hero(TEST_CLASS_ID)
	assert_int(_spy_recruit_count).is_equal(1)
	assert_object(_spy_recruit_payload).is_same(instance)


func test_add_hero_does_not_emit_hero_recruited_on_failure() -> void:
	_spy_recruit_count = 0
	var hr: Node = _make_fresh_roster()
	hr.hero_recruited.connect(_on_hero_recruited)
	hr.add_hero(UNKNOWN_CLASS_ID)
	assert_int(_spy_recruit_count).is_equal(0)


# Signal-ordering canary: `hero_recruited` MUST fire AFTER `_heroes` insertion,
# so subscribers reading `_heroes` from their handler see the new hero present.
# This is a load-bearing contract for HUD/Economy subscribers (ADR-0012).
var _spy_recruit_saw_in_dict: bool = false
var _spy_recruit_hr_ref: Node = null


func _on_hero_recruited_check_dict(instance: RefCounted) -> void:
	_spy_recruit_saw_in_dict = _spy_recruit_hr_ref._heroes.has(instance.instance_id)


func test_add_hero_emits_signal_after_heroes_dict_mutation() -> void:
	if not _data_registry_can_resolve_test_class():
		push_warning("Skipped: DataRegistry not resolving TEST_CLASS_ID")
		return
	_spy_recruit_saw_in_dict = false
	var hr: Node = _make_fresh_roster()
	_spy_recruit_hr_ref = hr
	hr.hero_recruited.connect(_on_hero_recruited_check_dict)
	hr.add_hero(TEST_CLASS_ID)
	assert_bool(_spy_recruit_saw_in_dict).is_true()


# ===========================================================================
# Group C: add_hero unresolvable-class failure path (TR-008)
# ===========================================================================

func test_add_hero_returns_null_on_unresolvable_class_id() -> void:
	var hr: Node = _make_fresh_roster()
	var instance: RefCounted = hr.add_hero(UNKNOWN_CLASS_ID)
	assert_object(instance).is_null()


func test_add_hero_does_not_increment_next_instance_id_on_unresolvable() -> void:
	var hr: Node = _make_fresh_roster()
	assert_int(hr._next_instance_id).is_equal(1)
	hr.add_hero(UNKNOWN_CLASS_ID)
	# TR-011: failed add must NOT consume an id.
	assert_int(hr._next_instance_id).is_equal(1)


func test_add_hero_does_not_insert_into_heroes_on_unresolvable() -> void:
	var hr: Node = _make_fresh_roster()
	hr.add_hero(UNKNOWN_CLASS_ID)
	assert_int(hr._heroes.size()).is_equal(0)


func test_add_hero_returns_null_on_empty_string_class_id() -> void:
	# DataRegistry.resolve("classes", "") returns null; unresolvable branch fires.
	# Defends against caller bugs (formatting errors, deserialization gaps) that
	# could pass an empty class_id where a real one was expected.
	var hr: Node = _make_fresh_roster()
	var result: RefCounted = hr.add_hero("")
	assert_object(result).is_null()
	assert_int(hr._heroes.size()).is_equal(0)
	assert_int(hr._next_instance_id).is_equal(1)


# ===========================================================================
# Group D: cap-path failure (TR-008)
# Manually populate _heroes to MAX_ROSTER_SIZE — bypasses DataRegistry
# dependency so this test runs even when DataRegistry is in ERROR state.
# ===========================================================================

func test_add_hero_returns_null_when_roster_at_cap() -> void:
	var hr: Node = _make_fresh_roster()
	# Populate _heroes to cap with synthetic instances (does not require DataRegistry).
	var cap: int = hr.max_roster_size()
	for i: int in range(1, cap + 1):
		var fake: RefCounted = HeroInstanceScript.new()
		fake.instance_id = i
		fake.class_id = "synthetic"
		hr._heroes[i] = fake
	assert_int(hr._heroes.size()).is_equal(cap)
	# Now attempt add_hero with any class_id — cap check fires before DataRegistry.
	var result: RefCounted = hr.add_hero(TEST_CLASS_ID)
	assert_object(result).is_null()


func test_add_hero_does_not_change_state_when_at_cap() -> void:
	var hr: Node = _make_fresh_roster()
	var cap: int = hr.max_roster_size()
	for i: int in range(1, cap + 1):
		var fake: RefCounted = HeroInstanceScript.new()
		fake.instance_id = i
		hr._heroes[i] = fake
	var pre_size: int = hr._heroes.size()
	var pre_next: int = hr._next_instance_id
	hr.add_hero(TEST_CLASS_ID)
	assert_int(hr._heroes.size()).is_equal(pre_size)
	assert_int(hr._next_instance_id).is_equal(pre_next)


# ===========================================================================
# Group E: remove_hero (TR-008, TR-009)
# ===========================================================================

# Per-test signal spy state for hero_removed.
var _spy_remove_count: int = 0
var _spy_remove_id: int = 0
var _spy_remove_class_id: String = ""
var _spy_remove_display_name: String = ""


func _on_hero_removed(id: int, class_id: String, display_name: String) -> void:
	_spy_remove_count += 1
	_spy_remove_id = id
	_spy_remove_class_id = class_id
	_spy_remove_display_name = display_name


func test_remove_hero_returns_false_on_unknown_id() -> void:
	var hr: Node = _make_fresh_roster()
	var ok: bool = hr.remove_hero(999)
	assert_bool(ok).is_false()


func test_remove_hero_returns_true_on_known_id() -> void:
	var hr: Node = _make_fresh_roster()
	# Inject a synthetic hero — does not require DataRegistry.
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = 7
	fake.class_id = "warrior"
	fake.display_name = "Test Hero"
	hr._heroes[7] = fake
	var ok: bool = hr.remove_hero(7)
	assert_bool(ok).is_true()


func test_remove_hero_drops_from_heroes_dict() -> void:
	var hr: Node = _make_fresh_roster()
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = 7
	hr._heroes[7] = fake
	hr.remove_hero(7)
	assert_bool(hr._heroes.has(7)).is_false()
	assert_int(hr._heroes.size()).is_equal(0)


func test_remove_hero_clears_formation_slot_referencing_id() -> void:
	var hr: Node = _make_fresh_roster()
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = 5
	hr._heroes[5] = fake
	# Manually place the hero in formation slot 0 (Story 005 will own this API).
	hr._formation_slots[0] = 5
	hr.remove_hero(5)
	assert_int(hr._formation_slots[0]).is_equal(0)


func test_remove_hero_emits_hero_removed_with_pre_drop_payload() -> void:
	_spy_remove_count = 0
	var hr: Node = _make_fresh_roster()
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = 12
	fake.class_id = "rogue"
	fake.display_name = "Test Rogue"
	hr._heroes[12] = fake
	hr.hero_removed.connect(_on_hero_removed)
	hr.remove_hero(12)
	assert_int(_spy_remove_count).is_equal(1)
	assert_int(_spy_remove_id).is_equal(12)
	assert_str(_spy_remove_class_id).is_equal("rogue")
	assert_str(_spy_remove_display_name).is_equal("Test Rogue")


func test_remove_hero_does_not_decrement_next_instance_id() -> void:
	# TR-011: ids are monotonic; removed ids are never reused.
	var hr: Node = _make_fresh_roster()
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = 3
	hr._heroes[3] = fake
	hr._next_instance_id = 4
	hr.remove_hero(3)
	assert_int(hr._next_instance_id).is_equal(4)


func test_remove_hero_does_not_emit_signal_on_unknown_id() -> void:
	_spy_remove_count = 0
	var hr: Node = _make_fresh_roster()
	hr.hero_removed.connect(_on_hero_removed)
	hr.remove_hero(999)
	assert_int(_spy_remove_count).is_equal(0)


# Signal-ordering canary: `hero_removed` MUST fire AFTER `_heroes.erase`,
# so subscribers reading `_heroes` from their handler see the hero already gone.
# Load-bearing contract for HUD "X retired" notifications (ADR-0012).
var _spy_remove_saw_in_dict: bool = true
var _spy_remove_hr_ref: Node = null


func _on_hero_removed_check_dict(id: int, _class_id: String, _display_name: String) -> void:
	_spy_remove_saw_in_dict = _spy_remove_hr_ref._heroes.has(id)


func test_remove_hero_emits_signal_after_heroes_dict_erase() -> void:
	_spy_remove_saw_in_dict = true
	var hr: Node = _make_fresh_roster()
	_spy_remove_hr_ref = hr
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = 42
	fake.class_id = "warrior"
	fake.display_name = "Test"
	hr._heroes[42] = fake
	hr.hero_removed.connect(_on_hero_removed_check_dict)
	hr.remove_hero(42)
	# At signal-emit time, _heroes.has(42) MUST be false.
	assert_bool(_spy_remove_saw_in_dict).is_false()
