# Tests for Sprint 6 hero-roster Story 006: get_save_data + load_save_data
# round-trip + signal suppression + SaveLoadSystem CONSUMER_PATHS registration.
#
# Covers: TR-hero-roster-010 (signals suppressed during load_save_data),
#         TR-hero-roster-019 (3-key save dict shape),
#         TR-hero-roster-029 (round-trip preserves heroes + _next_instance_id),
#         ADR-0004 (HeroRoster as item #1 in CONSUMER_PATHS after Economy).
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const SaveLoadSystemScript = preload("res://src/core/save_load_system/save_load_system.gd")


# Build a fresh HeroRoster Node and add to scene tree so _ready() runs.
func _make_fresh_roster() -> Node:
	var hr: Node = HeroRosterScript.new()
	add_child(hr)
	auto_free(hr)
	return hr


# Detect if DataRegistry can resolve a real class. Used to skip boot-validation
# tests that need DataRegistry-backed class lookup (FOLLOWUP-002 / S6-M12).
# Mirror of helper in tests/unit/hero_roster/add_hero_and_signals_test.gd.
func _data_registry_can_resolve_test_class() -> bool:
	return DataRegistry.resolve("classes", "warrior") != null


# Inject a synthetic HeroInstance directly into _heroes (bypasses DataRegistry).
func _inject_hero(hr: Node, id: int, class_id: String = "warrior",
		display_name: String = "", level: int = 1, xp: int = 0) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = class_id
	fake.display_name = display_name if display_name != "" else ("Hero %d" % id)
	fake.current_level = level
	fake.xp = xp
	hr._heroes[id] = fake
	return fake


# ===========================================================================
# Group A: get_save_data dict shape (TR-019)
# ===========================================================================

func test_get_save_data_returns_dict_with_exactly_six_keys() -> void:
	# V1 schema had 3 keys: heroes, formation_slots, next_instance_id.
	# V2 adds 3 more for Prestige V1.0 Story 2 (2026-05-09): prestige_count,
	# prestige_multiplier, retired_hero_records. Per
	# `prestige-system.md` §C.5.
	var hr: Node = _make_fresh_roster()
	var d: Dictionary = hr.get_save_data()
	assert_int(d.size()).is_equal(6)
	# V1 keys (regression guard)
	assert_bool(d.has("heroes")).is_true()
	assert_bool(d.has("formation_slots")).is_true()
	assert_bool(d.has("next_instance_id")).is_true()
	# V2 keys
	assert_bool(d.has("prestige_count")).is_true()
	assert_bool(d.has("prestige_multiplier")).is_true()
	assert_bool(d.has("retired_hero_records")).is_true()


func test_get_save_data_heroes_is_array() -> void:
	var hr: Node = _make_fresh_roster()
	var d: Dictionary = hr.get_save_data()
	assert_bool(d["heroes"] is Array).is_true()


func test_get_save_data_formation_slots_is_array_int() -> void:
	var hr: Node = _make_fresh_roster()
	var d: Dictionary = hr.get_save_data()
	assert_bool(d["formation_slots"] is Array).is_true()
	# Defaults to formation_size() (3) zeros from _ready.
	assert_int((d["formation_slots"] as Array).size()).is_equal(3)


func test_get_save_data_next_instance_id_is_int() -> void:
	var hr: Node = _make_fresh_roster()
	var d: Dictionary = hr.get_save_data()
	assert_int(d["next_instance_id"]).is_equal(1)  # default at boot


func test_get_save_data_heroes_entries_are_6key_to_dict() -> void:
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1, "warrior", "Theron", 7, 0)
	_inject_hero(hr, 2, "mage", "Eldra", 3, 0)
	var d: Dictionary = hr.get_save_data()
	var heroes: Array = d["heroes"] as Array
	assert_int(heroes.size()).is_equal(2)
	for entry in heroes:
		var dict: Dictionary = entry as Dictionary
		# 6 keys = 5 original + injured_until (GDD #34 Phase 3 save migration).
		assert_int(dict.size()).is_equal(6)
		assert_bool(dict.has("instance_id")).is_true()
		assert_bool(dict.has("class_id")).is_true()
		assert_bool(dict.has("display_name")).is_true()
		assert_bool(dict.has("current_level")).is_true()
		assert_bool(dict.has("xp")).is_true()
		assert_bool(dict.has("injured_until")).is_true()


func test_injured_until_survives_save_load_round_trip() -> void:
	# GDD #34 Phase 3 save migration: a hero defeated (injured) before a save
	# loads back still injured, with the exact wall-clock recovery instant.
	var src_hr: Node = _make_fresh_roster()
	var injured: RefCounted = _inject_hero(src_hr, 1, "warrior", "Theron", 7, 0)
	injured.injured_until = 1_733_000_000_000
	_inject_hero(src_hr, 2, "mage", "Eldra", 3, 0)  # healthy control
	var snapshot: Dictionary = src_hr.get_save_data()

	var dst_hr: Node = _make_fresh_roster()
	dst_hr.load_save_data(snapshot)
	var h1: HeroInstance = dst_hr.get_hero_by_id(1)
	var h2: HeroInstance = dst_hr.get_hero_by_id(2)
	assert_object(h1).is_not_null()
	assert_int(h1.injured_until).is_equal(1_733_000_000_000)
	assert_object(h2).is_not_null()
	assert_int(h2.injured_until).is_equal(0)


func test_legacy_hero_without_injured_until_loads_healthy() -> void:
	# A pre-Phase-3 save omits injured_until entirely → the hero hydrates with
	# the 0 healthy sentinel (from_dict default), never injured. No crash.
	var hr: Node = _make_fresh_roster()
	hr.load_save_data({
		"heroes": [{
			"instance_id": 1,
			"class_id": "warrior",
			"display_name": "Theron",
			"current_level": 7,
			"xp": 0,
		}],
		"formation_slots": [0, 0, 0],
		"next_instance_id": 2,
	})
	var hero: HeroInstance = hr.get_hero_by_id(1)
	assert_object(hero).is_not_null()
	assert_int(hero.injured_until).is_equal(0)
	assert_bool(hr.is_hero_injured(1, 1_000_000_000_000)).is_false()


# ===========================================================================
# Group B: get_save_data immutability (deep copy semantics)
# ===========================================================================

func test_get_save_data_formation_slots_is_a_duplicate_not_reference() -> void:
	var hr: Node = _make_fresh_roster()
	hr._formation_slots[0] = 7
	var d: Dictionary = hr.get_save_data()
	var slots: Array = d["formation_slots"]
	# Mutating the returned array MUST NOT touch live state.
	slots[0] = 999
	assert_int(hr._formation_slots[0]).is_equal(7)


# ===========================================================================
# Group C: load_save_data — round-trip preserves heroes (TR-029)
# ===========================================================================

func test_load_save_data_restores_heroes_from_save_dict() -> void:
	var src_hr: Node = _make_fresh_roster()
	_inject_hero(src_hr, 1, "warrior", "Theron", 5, 0)
	_inject_hero(src_hr, 2, "mage", "Eldra", 3, 0)
	_inject_hero(src_hr, 3, "rogue", "Vex", 1, 0)
	src_hr._next_instance_id = 4
	src_hr._formation_slots[0] = 1
	src_hr._formation_slots[2] = 3
	var saved: Dictionary = src_hr.get_save_data()

	# Hydrate into a fresh roster.
	var dst_hr: Node = _make_fresh_roster()
	dst_hr.load_save_data(saved)

	assert_int(dst_hr._heroes.size()).is_equal(3)
	assert_bool(dst_hr._heroes.has(1)).is_true()
	assert_bool(dst_hr._heroes.has(2)).is_true()
	assert_bool(dst_hr._heroes.has(3)).is_true()


func test_load_save_data_preserves_per_hero_fields() -> void:
	var src_hr: Node = _make_fresh_roster()
	_inject_hero(src_hr, 7, "rogue", "Vex", 11, 42)
	var saved: Dictionary = src_hr.get_save_data()

	var dst_hr: Node = _make_fresh_roster()
	dst_hr.load_save_data(saved)

	var restored: RefCounted = dst_hr._heroes[7]
	assert_int(restored.instance_id).is_equal(7)
	assert_str(restored.class_id).is_equal("rogue")
	assert_str(restored.display_name).is_equal("Vex")
	assert_int(restored.current_level).is_equal(11)
	assert_int(restored.xp).is_equal(42)


func test_load_save_data_preserves_formation_slots() -> void:
	var src_hr: Node = _make_fresh_roster()
	_inject_hero(src_hr, 1)
	_inject_hero(src_hr, 2)
	src_hr._formation_slots[0] = 1
	src_hr._formation_slots[1] = 0
	src_hr._formation_slots[2] = 2
	var saved: Dictionary = src_hr.get_save_data()

	var dst_hr: Node = _make_fresh_roster()
	dst_hr.load_save_data(saved)

	assert_int(dst_hr._formation_slots[0]).is_equal(1)
	assert_int(dst_hr._formation_slots[1]).is_equal(0)
	assert_int(dst_hr._formation_slots[2]).is_equal(2)


func test_post_load_add_hero_consumes_restored_next_instance_id() -> void:
	# Production-safety end-to-end: TR-011 requires that after a save/load
	# cycle, the NEXT add_hero call consumes the restored _next_instance_id
	# value (NOT a re-issued lower id, NOT _heroes.size()+1). A regression
	# where _next_instance_id is restored but add_hero ignores it would
	# silently violate id uniqueness in production.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: DataRegistry not resolving 'warrior' (FOLLOWUP-002)")
		return
	var src_hr: Node = _make_fresh_roster()
	for i: int in range(1, 11):
		_inject_hero(src_hr, i)
	src_hr._heroes.erase(5)
	src_hr._next_instance_id = 11
	var saved: Dictionary = src_hr.get_save_data()

	var dst_hr: Node = _make_fresh_roster()
	dst_hr.load_save_data(saved)

	# Now call add_hero — it MUST issue id=11 (the restored monotonic counter).
	var new_hero: RefCounted = dst_hr.add_hero("warrior")
	assert_object(new_hero).is_not_null()
	assert_int(new_hero.instance_id).is_equal(11)
	# After success, _next_instance_id ticks to 12.
	assert_int(dst_hr._next_instance_id).is_equal(12)


func test_load_save_data_preserves_next_instance_id_across_remove_add() -> void:
	# Simulate: add 10 heroes (ids 1..10), remove id=5, save, load — expect
	# 9 heroes (ids 1,2,3,4,6,7,8,9,10), _next_instance_id == 11 (TR-011 monotonic).
	var src_hr: Node = _make_fresh_roster()
	for i: int in range(1, 11):
		_inject_hero(src_hr, i)
	src_hr._heroes.erase(5)
	src_hr._next_instance_id = 11  # what add_hero would have left after 10 successful adds
	var saved: Dictionary = src_hr.get_save_data()

	var dst_hr: Node = _make_fresh_roster()
	dst_hr.load_save_data(saved)

	assert_int(dst_hr._heroes.size()).is_equal(9)
	assert_bool(dst_hr._heroes.has(5)).is_false()
	# id=5 must NOT be reused — _next_instance_id stays at 11.
	assert_int(dst_hr._next_instance_id).is_equal(11)


# ===========================================================================
# Group D: load_save_data clears prior state before hydration
# ===========================================================================

func test_load_save_data_clears_prior_heroes_before_hydrating() -> void:
	var hr: Node = _make_fresh_roster()
	# Pre-populate with state that should be wiped.
	_inject_hero(hr, 99, "warrior", "Stale", 15, 0)
	hr._next_instance_id = 99
	hr._formation_slots[0] = 99

	# Hydrate from a different snapshot.
	var snapshot: Dictionary = {
		"heroes": [{
			"instance_id": 1,
			"class_id": "mage",
			"display_name": "Eldra",
			"current_level": 1,
			"xp": 0,
		}],
		"formation_slots": [1, 0, 0],
		"next_instance_id": 2,
	}
	hr.load_save_data(snapshot)

	# Stale id=99 must be gone; only id=1 from snapshot remains.
	assert_bool(hr._heroes.has(99)).is_false()
	assert_int(hr._heroes.size()).is_equal(1)
	assert_int(hr._next_instance_id).is_equal(2)
	assert_int(hr._formation_slots[0]).is_equal(1)


# ===========================================================================
# Group E: load_save_data signal suppression (TR-010)
# ===========================================================================

var _spy_recruit_count: int = 0
var _spy_leveled_count: int = 0
var _spy_remove_count: int = 0


func _on_hero_recruited(_instance: RefCounted) -> void:
	_spy_recruit_count += 1


func _on_hero_leveled(_id: int, _old: int, _new: int) -> void:
	_spy_leveled_count += 1


func _on_hero_removed(_id: int, _class_id: String, _display_name: String) -> void:
	_spy_remove_count += 1


func test_load_save_data_suppresses_all_three_signals_during_hydration() -> void:
	_spy_recruit_count = 0
	_spy_leveled_count = 0
	_spy_remove_count = 0

	var hr: Node = _make_fresh_roster()
	hr.hero_recruited.connect(_on_hero_recruited)
	hr.hero_leveled.connect(_on_hero_leveled)
	hr.hero_removed.connect(_on_hero_removed)

	# Build a snapshot with 5 heroes — bulk hydration must be silent.
	var heroes_arr: Array = []
	for i: int in range(1, 6):
		heroes_arr.append({
			"instance_id": i,
			"class_id": "warrior",
			"display_name": "Hero %d" % i,
			"current_level": 1,
			"xp": 0,
		})
	hr.load_save_data({
		"heroes": heroes_arr,
		"formation_slots": [0, 0, 0],
		"next_instance_id": 6,
	})

	# State was hydrated…
	assert_int(hr._heroes.size()).is_equal(5)
	# …but no signals fired.
	assert_int(_spy_recruit_count).is_equal(0)
	assert_int(_spy_leveled_count).is_equal(0)
	assert_int(_spy_remove_count).is_equal(0)


func test_signals_resume_firing_after_load_save_data_returns() -> void:
	# Strengthened: actually emit a signal post-load and verify the spy
	# receives it. Guards against a guard-stickiness regression where the
	# emit guard logic accidentally references stale state instead of the
	# live `_suppress_signals` flag.
	_spy_recruit_count = 0
	var hr: Node = _make_fresh_roster()
	hr.load_save_data({
		"heroes": [],
		"formation_slots": [0, 0, 0],
		"next_instance_id": 1,
	})
	assert_bool(hr._suppress_signals).is_false()
	hr.hero_recruited.connect(_on_hero_recruited)
	# Direct emit — bypasses add_hero's DataRegistry dependency. The guard
	# inside hero_roster.gd checks `_suppress_signals` for ALL emit sites,
	# not just the add_hero one; calling .emit() directly here verifies the
	# subscriber receives the event when the flag is false.
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = 1
	hr.hero_recruited.emit(fake)
	assert_int(_spy_recruit_count).is_equal(1)


# ===========================================================================
# Group F: SaveLoadSystem CONSUMER_PATHS registration
# ===========================================================================

func test_save_load_system_consumer_paths_includes_hero_roster() -> void:
	# Read the live constant from the SaveLoadSystem script.
	var consumers: PackedStringArray = SaveLoadSystemScript.CONSUMER_PATHS
	assert_bool(consumers.has("/root/HeroRoster")).is_true()


func test_hero_roster_is_consumer_index_one_after_economy() -> void:
	var consumers: PackedStringArray = SaveLoadSystemScript.CONSUMER_PATHS
	assert_int(consumers.size()).is_greater_equal(2)
	assert_str(consumers[0]).is_equal("/root/Economy")
	assert_str(consumers[1]).is_equal("/root/HeroRoster")


# ===========================================================================
# Group G: defensive defaults on missing keys
# ===========================================================================

func test_load_save_data_coerces_float_formation_slot_values_to_int() -> void:
	# Production-safety: Godot's JSON.parse_string returns floats for numeric
	# values without decimals. A real save file loaded from disk will hit the
	# `int(slots_in[i])` cast in load_save_data. Verify the coercion produces
	# correct ints (no precision loss, no crashes).
	var hr: Node = _make_fresh_roster()
	_inject_hero(hr, 1)
	_inject_hero(hr, 2)
	hr.load_save_data({
		"heroes": [
			{"instance_id": 1, "class_id": "warrior", "display_name": "A",
				"current_level": 1, "xp": 0},
			{"instance_id": 2, "class_id": "mage", "display_name": "B",
				"current_level": 1, "xp": 0},
		],
		"formation_slots": [1.0, 0.0, 2.0],  # floats — JSON-style payload
		"next_instance_id": 3,
	})
	assert_int(hr._formation_slots[0]).is_equal(1)
	assert_int(hr._formation_slots[1]).is_equal(0)
	assert_int(hr._formation_slots[2]).is_equal(2)


func test_load_save_data_truncates_oversize_formation_slots_with_warning() -> void:
	# Production-safety: a save authored with formation_size=4 loaded under
	# current formation_size=3 must drop the trailing slot, not crash.
	# The slot-4 hero remains in _heroes (only the formation assignment is lost).
	#
	# Sprint 8 S8-S4: this test now populates `heroes` so the slot ids 1/2/3
	# resolve to real instances during boot validation. Without this the
	# Story 007 TR-015 step 2 would correctly clear the slots as orphan
	# references; the original 2026-04-26 test predated boot validation and
	# implicitly relied on the (then-absent) post-load slot-vs-heroes check.
	if not _data_registry_can_resolve_test_class():
		push_warning("Skipped: DataRegistry cannot resolve test class")
		return
	var hr: Node = _make_fresh_roster()
	hr.load_save_data({
		"heroes": [
			{"instance_id": 1, "class_id": "warrior", "display_name": "A",
				"current_level": 1, "xp": 0},
			{"instance_id": 2, "class_id": "warrior", "display_name": "B",
				"current_level": 1, "xp": 0},
			{"instance_id": 3, "class_id": "warrior", "display_name": "C",
				"current_level": 1, "xp": 0},
		],
		"formation_slots": [1, 2, 3, 4],  # 4 entries; current size is 3
		"next_instance_id": 5,
	})
	assert_int(hr._formation_slots.size()).is_equal(3)
	assert_int(hr._formation_slots[0]).is_equal(1)
	assert_int(hr._formation_slots[1]).is_equal(2)
	assert_int(hr._formation_slots[2]).is_equal(3)


func test_load_save_data_pads_undersize_formation_slots_with_zero() -> void:
	# Edge case: a save with fewer slots than current formation_size pads
	# missing slots with 0 (empty), not garbage / out-of-bounds.
	#
	# Sprint 8 S8-S4: post-load boot validation clears orphan slot ids
	# (slots referencing hero ids that don't exist in `heroes`). The
	# padding-with-zero contract is independent of the orphan-clear
	# pass; this test populates `heroes` with id=1 so slot[0]=1 resolves
	# and isn't cleared by orphan-clear, leaving the padding behavior
	# (slots[1]/[2] stay 0) as the assertion target. Without this
	# population, slot[0] would also clear to 0, masking whether the
	# padding zeroes came from the pad-pass or the orphan-clear pass.
	if not _data_registry_can_resolve_test_class():
		push_warning("Skipped: DataRegistry cannot resolve test class")
		return
	var hr: Node = _make_fresh_roster()
	hr.load_save_data({
		"heroes": [
			{"instance_id": 1, "class_id": "warrior", "display_name": "A",
				"current_level": 1, "xp": 0},
		],
		"formation_slots": [1],  # only 1 entry; current size is 3
		"next_instance_id": 2,
	})
	assert_int(hr._formation_slots.size()).is_equal(3)
	assert_int(hr._formation_slots[0]).is_equal(1)
	assert_int(hr._formation_slots[1]).is_equal(0)
	assert_int(hr._formation_slots[2]).is_equal(0)


func test_load_save_data_uses_safe_defaults_on_empty_dict() -> void:
	var hr: Node = _make_fresh_roster()
	hr.load_save_data({})
	assert_int(hr._heroes.size()).is_equal(0)
	assert_int(hr._formation_slots.size()).is_equal(3)
	for slot: int in hr._formation_slots:
		assert_int(slot).is_equal(0)
	assert_int(hr._next_instance_id).is_equal(1)
