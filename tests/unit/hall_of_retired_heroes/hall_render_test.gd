# Sprint 21+ Prestige V1.0 / Story 3 UI (Slice B) — Hall of Retired Heroes
# render tests.
#
# Per `design/gdd/prestige-system.md` §F + AC-PR-13 (multiplier rendered
# to 2 decimal places: `×1.05` exactly).
#
# Test groups:
#   A — Multiplier label format (AC-PR-13)
#   B — Card list rebuild from records
#   C — Empty-state path
#   D — Live re-render on prestige_completed_signal
extends GdUnitTestSuite

const HallScene = preload("res://assets/screens/hall_of_retired_heroes/hall_of_retired_heroes.tscn")


func _make_hall() -> Node:
	var hall: Node = HallScene.instantiate()
	add_child(hall)
	auto_free(hall)
	return hall


func _seed_records(records: Array[Dictionary]) -> void:
	# Inject directly into HeroRoster._retired_hero_records. Test isolation
	# pattern matches the synthetic-state injection in the modal contract
	# tests. after_test cleanup restores the original list.
	HeroRoster._retired_hero_records.clear()
	for rec: Dictionary in records:
		HeroRoster._retired_hero_records.append(rec)


func before_test() -> void:
	HeroRoster._prestige_count = 0
	HeroRoster._prestige_multiplier = 1.0
	HeroRoster._retired_hero_records.clear()


func after_test() -> void:
	HeroRoster._prestige_count = 0
	HeroRoster._prestige_multiplier = 1.0
	HeroRoster._retired_hero_records.clear()


# ===========================================================================
# Group A — Multiplier label format (AC-PR-13)
# ===========================================================================

func test_hall_multiplier_renders_baseline_1_00_when_no_prestige() -> void:
	# Defensive empty-state: navigating the hall with 0 prestige still
	# renders the multiplier badge cleanly.
	var hall: Node = _make_hall()
	hall.on_enter()
	assert_str(hall._multiplier_label.text).is_equal("×1.00")


func test_hall_multiplier_renders_1_05_after_one_prestige() -> void:
	# AC-PR-13: multiplier rendered to 2 decimal places. 1 prestige =
	# 1.05 multiplier per PRESTIGE_GAIN_PER. Asserts the exact string
	# "×1.05" — not just "contains '1.05'".
	HeroRoster._prestige_count = 1
	HeroRoster._prestige_multiplier = 1.05
	var hall: Node = _make_hall()
	hall.on_enter()
	assert_str(hall._multiplier_label.text).is_equal("×1.05")


func test_hall_multiplier_renders_1_50_after_ten_prestiges() -> void:
	# Mid-curve: 10 prestiges = 1.50 multiplier. Verify trailing zero
	# in the decimal preserved (×1.50, not ×1.5).
	HeroRoster._prestige_count = 10
	HeroRoster._prestige_multiplier = 1.50
	var hall: Node = _make_hall()
	hall.on_enter()
	assert_str(hall._multiplier_label.text).is_equal("×1.50")


func test_hall_multiplier_renders_2_00_at_max() -> void:
	# Max curve: 20 prestiges = 2.00 cap.
	HeroRoster._prestige_count = 20
	HeroRoster._prestige_multiplier = 2.0
	var hall: Node = _make_hall()
	hall.on_enter()
	assert_str(hall._multiplier_label.text).is_equal("×2.00")


# ===========================================================================
# Group B — Card list rebuild from records
# ===========================================================================

func test_hall_renders_one_card_per_record() -> void:
	var records: Array[Dictionary] = [
		{"display_name": "Theron", "class_id": "warrior", "level_at_retirement": 15, "retirement_unix_ts": 1700000000, "prestige_index": 1},
		{"display_name": "Mira", "class_id": "mage", "level_at_retirement": 15, "retirement_unix_ts": 1700100000, "prestige_index": 2},
	]
	_seed_records(records)
	HeroRoster._prestige_count = 2

	var hall: Node = _make_hall()
	hall.on_enter()

	# CardList has 2 children (one per record).
	assert_int(hall._card_list.get_child_count()).is_equal(2)


func test_hall_card_text_includes_writer_locked_separators() -> void:
	# AC-PR-17 surface: card metadata format renders via tr() with the
	# `%s · %s · Lv %d · Retired Day %d` writer-locked layout. Verify
	# the · separators + the "Lv " + "Retired Day " prefixes are present.
	var records: Array[Dictionary] = [
		{"display_name": "Theron", "class_id": "warrior", "level_at_retirement": 15, "retirement_unix_ts": 1700000000, "prestige_index": 1},
	]
	_seed_records(records)
	HeroRoster._prestige_count = 1

	var hall: Node = _make_hall()
	hall.on_enter()

	assert_int(hall._card_list.get_child_count()).is_equal(1)
	var card_label: Label = hall._card_list.get_child(0)
	# All four fields present in the rendered text.
	assert_str(card_label.text).contains("Theron")
	assert_str(card_label.text).contains("Warrior")  # capitalized class_id
	assert_str(card_label.text).contains("Lv 15")
	assert_str(card_label.text).contains("Retired Day 1")
	# Writer-locked separator.
	assert_str(card_label.text).contains("·")


# ===========================================================================
# Group C — Empty-state path
# ===========================================================================

func test_hall_renders_empty_state_placeholder_when_no_records() -> void:
	# Defensive path: if the player navigates here with 0 records (Guild
	# Hall button SHOULD have been hidden in this case, but a save-load
	# corruption or test could surface it), render gracefully.
	var hall: Node = _make_hall()
	hall.on_enter()

	# Exactly 1 placeholder card.
	assert_int(hall._card_list.get_child_count()).is_equal(1)
	# Multiplier renders the baseline.
	assert_str(hall._multiplier_label.text).is_equal("×1.00")


# ===========================================================================
# Group D — Live re-render on prestige_completed_signal
# ===========================================================================

func test_hall_rebuilds_card_list_on_prestige_completed_signal() -> void:
	# Signal subscriber path: a prestige fires while the Hall is on-screen.
	# The card list rebuilds from the autoload's now-larger record list;
	# the multiplier label updates.
	var hall: Node = _make_hall()
	hall.on_enter()
	assert_int(hall._card_list.get_child_count()).is_equal(1)  # placeholder
	assert_str(hall._multiplier_label.text).is_equal("×1.00")

	# Simulate autoload state mutation + signal emit.
	var new_record: Dictionary = {
		"display_name": "Theron",
		"class_id": "warrior",
		"level_at_retirement": 15,
		"retirement_unix_ts": 1700000000,
		"prestige_index": 1,
	}
	HeroRoster._retired_hero_records.append(new_record)
	HeroRoster._prestige_count = 1
	HeroRoster._prestige_multiplier = 1.05
	HeroRoster.prestige_completed_signal.emit(new_record, 1)

	# Hall auto-rebuilt: card list now has 1 real card; multiplier
	# updated.
	assert_int(hall._card_list.get_child_count()).is_equal(1)
	var card_label: Label = hall._card_list.get_child(0)
	assert_str(card_label.text).contains("Theron")
	assert_str(hall._multiplier_label.text).is_equal("×1.05")
