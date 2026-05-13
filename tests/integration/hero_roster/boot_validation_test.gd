# Tests for Sprint 8 hero-roster Story 007 (S8-S4 carryover from S7-S6):
#   - 4-step boot validation order: resolve class_ids → clear stale formation
#     slots → trim over-cap → repair _next_instance_id
#   - Orphaned heroes (unresolvable class_id) appended to _orphaned_heroes;
#     orphan_heroes_notice signal fires once after suppression is lifted
#   - Duplicate instance_id in save dict → last-write-wins via Dictionary
#     assignment; push_error logged; no crash
#   - Signal suppression spans the entire load + validate cycle
#
# Covers: TR-hero-roster-015 (boot validation runs 4 steps in exact order),
#         TR-hero-roster-016 (orphan tracking + non-blocking notice signal),
#         TR-hero-roster-025 (duplicate id last-write-wins).
#
# Each test uses a fresh HeroRoster instance for isolation. Tests inject
# synthetic HeroInstance objects directly into _heroes (or via load_save_data
# with a constructed save dict) to drive specific validation branches.
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

const WARRIOR_ID := "warrior"
const GHOST_CLASS := "ghost_class_does_not_exist"


func _make_fresh_roster() -> Node:
	var hr: Node = HeroRosterScript.new()
	add_child(hr)
	auto_free(hr)
	return hr


func _data_registry_can_resolve_warrior() -> bool:
	return DataRegistry.resolve("classes", WARRIOR_ID) != null


# Build a save-dict hero entry with the canonical 5-key shape (matches
# HeroInstance.to_dict from Sprint 6 Story 001).
func _make_hero_dict(id: int, class_id: String = WARRIOR_ID,
		display_name: String = "", level: int = 1, xp: int = 0) -> Dictionary:
	var hero_name: String = display_name if display_name != "" else ("Hero %d" % id)
	return {
		"instance_id": id,
		"class_id": class_id,
		"display_name": hero_name,
		"current_level": level,
		"xp": xp,
	}


# Signal spies for full-suppression test (Group F).
var _spy_recruited: int = 0
var _spy_leveled: int = 0
var _spy_removed: int = 0
var _spy_orphan_count: int = -1


func _on_hero_recruited(_inst: RefCounted) -> void:
	_spy_recruited += 1


func _on_hero_leveled(_id: int, _old: int, _new: int) -> void:
	_spy_leveled += 1


func _on_hero_removed(_id: int, _cls: String, _name: String) -> void:
	_spy_removed += 1


func _on_orphan_notice(count: int) -> void:
	_spy_orphan_count = count


# ===========================================================================
# Group A: TR-015 step 1 — orphan class_id heroes dropped to _orphaned_heroes
# ===========================================================================

func test_load_save_data_drops_heroes_with_unresolvable_class_id() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped: DataRegistry cannot resolve warrior")
		return
	# Arrange — save dict with 1 valid + 2 orphans.
	var hr: Node = _make_fresh_roster()
	var save_dict: Dictionary = {
		"heroes": [
			_make_hero_dict(1, WARRIOR_ID),
			_make_hero_dict(2, GHOST_CLASS),
			_make_hero_dict(3, "phantom"),
		],
		"formation_slots": [0, 0, 0],
		"next_instance_id": 4,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — only the valid warrior remains.
	assert_int(hr._heroes.size()).is_equal(1)
	assert_bool(hr._heroes.has(1)).is_true()
	assert_bool(hr._heroes.has(2)).is_false()
	assert_bool(hr._heroes.has(3)).is_false()


func test_orphaned_heroes_list_contains_unresolvable_instances() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()
	var save_dict: Dictionary = {
		"heroes": [
			_make_hero_dict(1, WARRIOR_ID),
			_make_hero_dict(2, GHOST_CLASS),
			_make_hero_dict(3, "phantom"),
		],
		"formation_slots": [],
		"next_instance_id": 4,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — both unresolvable heroes captured in orphans.
	assert_int(hr._orphaned_heroes.size()).is_equal(2)


func test_orphan_heroes_notice_fires_once_with_correct_count() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	_spy_orphan_count = -1  # sentinel: signal didn't fire
	var hr: Node = _make_fresh_roster()
	hr.orphan_heroes_notice.connect(_on_orphan_notice)
	var save_dict: Dictionary = {
		"heroes": [
			_make_hero_dict(1, WARRIOR_ID),
			_make_hero_dict(2, GHOST_CLASS),
			_make_hero_dict(3, "phantom"),
		],
		"formation_slots": [],
		"next_instance_id": 4,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — signal fired with count == 2.
	assert_int(_spy_orphan_count).is_equal(2)


func test_orphan_heroes_notice_does_not_fire_when_no_orphans() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	_spy_orphan_count = -1
	var hr: Node = _make_fresh_roster()
	hr.orphan_heroes_notice.connect(_on_orphan_notice)
	var save_dict: Dictionary = {
		"heroes": [_make_hero_dict(1, WARRIOR_ID), _make_hero_dict(2, WARRIOR_ID)],
		"formation_slots": [],
		"next_instance_id": 3,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — signal never fired (sentinel still -1).
	assert_int(_spy_orphan_count).is_equal(-1)


func test_orphaned_heroes_list_cleared_on_re_load() -> void:
	# Re-load with fresh data → orphan list reset; previous orphans don't accumulate.
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()
	# First load with orphans.
	hr.load_save_data({
		"heroes": [_make_hero_dict(1, GHOST_CLASS)],
		"formation_slots": [],
		"next_instance_id": 2,
	})
	assert_int(hr._orphaned_heroes.size()).is_equal(1)

	# Act — second load with no orphans.
	hr.load_save_data({
		"heroes": [_make_hero_dict(1, WARRIOR_ID)],
		"formation_slots": [],
		"next_instance_id": 2,
	})

	# Assert
	assert_int(hr._orphaned_heroes.size()).is_equal(0)


# ===========================================================================
# Group B: TR-015 step 2 — stale formation slots cleared
# ===========================================================================

func test_load_save_data_clears_formation_slots_referencing_orphan_ids() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange — slot 0 references hero id 2 (which is an orphan).
	var hr: Node = _make_fresh_roster()
	var save_dict: Dictionary = {
		"heroes": [
			_make_hero_dict(1, WARRIOR_ID),
			_make_hero_dict(2, GHOST_CLASS),
		],
		"formation_slots": [2, 1, 0],  # slot 0 → orphan id 2
		"next_instance_id": 3,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — slot 0 cleared (orphan), slot 1 retains valid id 1.
	assert_int(hr._formation_slots[0]).is_equal(0)
	assert_int(hr._formation_slots[1]).is_equal(1)


func test_load_save_data_preserves_formation_slots_referencing_valid_ids() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange — all slots reference valid heroes.
	var hr: Node = _make_fresh_roster()
	var save_dict: Dictionary = {
		"heroes": [
			_make_hero_dict(1, WARRIOR_ID),
			_make_hero_dict(2, WARRIOR_ID),
			_make_hero_dict(3, WARRIOR_ID),
		],
		"formation_slots": [1, 2, 3],
		"next_instance_id": 4,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert
	assert_int(hr._formation_slots[0]).is_equal(1)
	assert_int(hr._formation_slots[1]).is_equal(2)
	assert_int(hr._formation_slots[2]).is_equal(3)


# ===========================================================================
# Group C: TR-015 step 3 — over-cap roster trimmed (preserve lowest ids)
# ===========================================================================

func test_load_save_data_trims_over_cap_roster_preserving_lowest_ids() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange — 35 valid warrior heroes; cap is 30 (default).
	var hr: Node = _make_fresh_roster()
	var heroes_arr: Array = []
	for i: int in range(1, 36):
		heroes_arr.append(_make_hero_dict(i, WARRIOR_ID))
	var save_dict: Dictionary = {
		"heroes": heroes_arr,
		"formation_slots": [],
		"next_instance_id": 36,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — exactly 30 retained; ids 1..30 present; 31..35 dropped.
	assert_int(hr._heroes.size()).is_equal(30)
	assert_bool(hr._heroes.has(1)).is_true()
	assert_bool(hr._heroes.has(30)).is_true()
	assert_bool(hr._heroes.has(31)).is_false()
	assert_bool(hr._heroes.has(35)).is_false()


# ===========================================================================
# Group D: TR-015 step 4 — _next_instance_id repair (always > max(ids))
# ===========================================================================

func test_load_save_data_repairs_next_instance_id_when_artificially_low() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange — heroes at ids [5, 10, 20]; next_instance_id artificially = 2.
	var hr: Node = _make_fresh_roster()
	var save_dict: Dictionary = {
		"heroes": [
			_make_hero_dict(5, WARRIOR_ID),
			_make_hero_dict(10, WARRIOR_ID),
			_make_hero_dict(20, WARRIOR_ID),
		],
		"formation_slots": [],
		"next_instance_id": 2,  # artificially low — must be repaired to 21
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert
	assert_int(hr._next_instance_id).is_equal(21)


func test_load_save_data_preserves_next_instance_id_when_already_above_max() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange — heroes at [1, 2, 3]; next_instance_id = 100 (e.g., heroes 4..99
	# were removed during the session; monotonic preserves the gap per TR-011).
	var hr: Node = _make_fresh_roster()
	var save_dict: Dictionary = {
		"heroes": [
			_make_hero_dict(1, WARRIOR_ID),
			_make_hero_dict(2, WARRIOR_ID),
			_make_hero_dict(3, WARRIOR_ID),
		],
		"formation_slots": [],
		"next_instance_id": 100,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — preserved at 100 (max(_next_instance_id, max_id+1) = max(100, 4) = 100).
	assert_int(hr._next_instance_id).is_equal(100)


func test_load_save_data_next_instance_id_after_trim_stays_at_save_value() -> void:
	# Edge: trim drops ids 31..35; _next_instance_id was 36 in save → stays 36
	# even though max(remaining_ids) = 30.
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()
	var heroes_arr: Array = []
	for i: int in range(1, 36):
		heroes_arr.append(_make_hero_dict(i, WARRIOR_ID))
	var save_dict: Dictionary = {
		"heroes": heroes_arr,
		"formation_slots": [],
		"next_instance_id": 36,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — preserved at 36 (max(36, max_remaining(30) + 1) = max(36, 31) = 36).
	assert_int(hr._next_instance_id).is_equal(36)


# ===========================================================================
# Group E: TR-015 — full 4-step pipeline (combined orphan + slot + trim + repair)
# ===========================================================================

func test_full_validation_pipeline_drops_orphan_clears_slot_and_repairs_id() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange — single orphan hero referenced by formation slot; _next_instance_id
	# already higher than max id.
	var hr: Node = _make_fresh_roster()
	var save_dict: Dictionary = {
		"heroes": [
			_make_hero_dict(1, GHOST_CLASS, "Orphan"),
		],
		"formation_slots": [1, 0, 0],
		"next_instance_id": 2,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — Step 1 dropped the orphan, Step 2 cleared slot 0, no trim
	# needed (Step 3), _next_instance_id stays 2 since size==0 (Step 4 keeps
	# the saved value when no heroes remain).
	assert_int(hr._heroes.size()).is_equal(0)
	assert_int(hr._orphaned_heroes.size()).is_equal(1)
	assert_int(hr._formation_slots[0]).is_equal(0)
	assert_int(hr._next_instance_id).is_equal(2)


# ===========================================================================
# Group F: TR-025 — duplicate instance_id last-write-wins
# ===========================================================================

func test_duplicate_instance_id_in_save_last_write_wins() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange — two heroes with id=5; second has display_name "Second".
	var hr: Node = _make_fresh_roster()
	var save_dict: Dictionary = {
		"heroes": [
			_make_hero_dict(5, WARRIOR_ID, "First"),
			_make_hero_dict(5, WARRIOR_ID, "Second"),
		],
		"formation_slots": [],
		"next_instance_id": 6,
	}

	# Act — push_error logged for the duplicate; no crash.
	hr.load_save_data(save_dict)

	# Assert — the LAST write wins.
	assert_int(hr._heroes.size()).is_equal(1)
	assert_str(hr._heroes[5].display_name).is_equal("Second")


# ===========================================================================
# Group G: signal suppression — zero emissions during load + validate cycle
# ===========================================================================

func test_signal_spies_receive_zero_emissions_during_load_with_orphans_and_trim() -> void:
	# All 3 mutation signals (hero_recruited / hero_leveled / hero_removed)
	# must remain SILENT during the entire load + validate pass — even when
	# heroes are dropped during validation. Suppression flag is enforced for
	# the whole cycle.
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	_spy_recruited = 0
	_spy_leveled = 0
	_spy_removed = 0
	var hr: Node = _make_fresh_roster()
	hr.hero_recruited.connect(_on_hero_recruited)
	hr.hero_leveled.connect(_on_hero_leveled)
	hr.hero_removed.connect(_on_hero_removed)
	var save_dict: Dictionary = {
		"heroes": [
			_make_hero_dict(1, WARRIOR_ID),
			_make_hero_dict(2, GHOST_CLASS),  # orphan → drop
			_make_hero_dict(3, WARRIOR_ID),
			_make_hero_dict(4, WARRIOR_ID),
			_make_hero_dict(5, WARRIOR_ID),
		],
		"formation_slots": [2, 0, 0],  # references the orphan → cleared
		"next_instance_id": 6,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — zero signal emissions across the full load + validate cycle.
	assert_int(_spy_recruited).is_equal(0)
	assert_int(_spy_leveled).is_equal(0)
	assert_int(_spy_removed).is_equal(0)


func test_orphan_heroes_notice_fires_after_suppress_signals_lifted() -> void:
	# TR-016: orphan_heroes_notice is the EXCEPTION — it fires AFTER the load
	# completes (post-suppression-lift). Verify it reaches the spy.
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	_spy_orphan_count = -1
	var hr: Node = _make_fresh_roster()
	hr.orphan_heroes_notice.connect(_on_orphan_notice)
	var save_dict: Dictionary = {
		"heroes": [_make_hero_dict(1, GHOST_CLASS)],
		"formation_slots": [],
		"next_instance_id": 2,
	}

	# Act
	hr.load_save_data(save_dict)

	# Assert — _suppress_signals is now false (load completed); notice fired.
	assert_bool(hr._suppress_signals).is_false()
	assert_int(_spy_orphan_count).is_equal(1)
