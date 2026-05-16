# Sprint 23 S23-M1 — Guild Hall Retired-tab render + prestige toast tests.
#
# This file replaces:
#   - tests/unit/hall_of_retired_heroes/hall_render_test.gd (deleted with the
#     standalone screen)
#   - tests/unit/guild_hall/hall_button_visibility_test.gd (visibility gate
#     removed; Retired tab is always present on RosterPanel)
#
# Per `design/gdd/prestige-system.md` §F + AC-PR-13. The Retired tab is the
# new home of the multiplier badge + retired-hero card list — its content
# matches the prior standalone hall_of_retired_heroes screen.
#
# Test groups:
#   A — Tab structure (TabContainer has 2 tabs; titles localized)
#   B — Multiplier label format (AC-PR-13; ports from hall_render_test Group A)
#   C — Card list rebuild from records (ports from hall_render_test Group B)
#   D — Empty-state path (ports from hall_render_test Group C)
#   E — Live re-render on prestige_completed_signal (ports from hall_render_test Group D)
#   F — Prestige completion toast (ports from hall_button_visibility_test Group C)
extends GdUnitTestSuite

const GuildHallScene = preload("res://assets/screens/guild_hall/guild_hall.tscn")
const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")


var _snapshot_roster: Dictionary = {}


func _make_guild_hall() -> Node:
	var screen: Node = GuildHallScene.instantiate()
	add_child(screen)
	auto_free(screen)
	return screen


func _seed_records(records: Array[Dictionary]) -> void:
	HeroRoster._retired_hero_records.clear()
	for rec: Dictionary in records:
		HeroRoster._retired_hero_records.append(rec)


func before_test() -> void:
	# Sprint 24 S24-S3 — snapshot+reset via fixture (replaces inline boilerplate).
	_snapshot_roster = HeroRosterFixture.snapshot_via_save_data()
	HeroRosterFixture.reset_hero_roster()


func after_test() -> void:
	HeroRosterFixture.restore_via_load_save_data(_snapshot_roster)


# ===========================================================================
# Group A — Tab structure
# ===========================================================================

func test_roster_tabs_has_two_tabs_active_and_retired() -> void:
	# Arrange + Act
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	# Assert — TabContainer has exactly two tab pages.
	assert_int(screen._roster_tabs.get_tab_count()).is_equal(2)


func test_roster_tabs_titles_localized_on_enter() -> void:
	# Arrange + Act
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	# Assert — tab titles routed through tr(). Returns the writer-locked
	# value when en.csv is loaded; the key verbatim otherwise — both NON-empty.
	assert_bool(screen._roster_tabs.get_tab_title(0).length() > 0).is_true()
	assert_bool(screen._roster_tabs.get_tab_title(1).length() > 0).is_true()


# ===========================================================================
# Group B — Multiplier label format (AC-PR-13)
# ===========================================================================

func test_retired_tab_multiplier_renders_baseline_1_00_when_no_prestige() -> void:
	# Defensive empty-state: the Retired tab still renders cleanly with 0
	# prestiges. Multiplier shows the baseline ×1.00.
	var screen: Node = _make_guild_hall()
	screen.on_enter()
	assert_str(screen._multiplier_label.text).is_equal("×1.00")


func test_retired_tab_multiplier_renders_1_05_after_one_prestige() -> void:
	# Arrange — AC-PR-13: 1 prestige = ×1.05 (PRESTIGE_GAIN_PER).
	HeroRoster._prestige_count = 1
	HeroRoster._prestige_multiplier = 1.05

	# Act
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	# Assert — exact string match (×1.05, not "contains 1.05").
	assert_str(screen._multiplier_label.text).is_equal("×1.05")


func test_retired_tab_multiplier_renders_1_50_after_ten_prestiges() -> void:
	# Arrange — mid-curve: 10 prestiges → ×1.50.
	HeroRoster._prestige_count = 10
	HeroRoster._prestige_multiplier = 1.50

	# Act
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	# Assert — trailing zero preserved (×1.50, not ×1.5).
	assert_str(screen._multiplier_label.text).is_equal("×1.50")


func test_retired_tab_multiplier_renders_2_00_at_max() -> void:
	# Arrange — max curve: 20 prestiges → ×2.00 cap.
	HeroRoster._prestige_count = 20
	HeroRoster._prestige_multiplier = 2.0

	# Act
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	# Assert
	assert_str(screen._multiplier_label.text).is_equal("×2.00")


# ===========================================================================
# Group C — Card list rebuild from records
# ===========================================================================

func test_retired_tab_renders_one_card_per_record() -> void:
	# Arrange
	var records: Array[Dictionary] = [
		{"display_name": "Theron", "class_id": "warrior", "level_at_retirement": 15, "retirement_unix_ts": 1700000000, "prestige_index": 1},
		{"display_name": "Mira", "class_id": "mage", "level_at_retirement": 15, "retirement_unix_ts": 1700100000, "prestige_index": 2},
	]
	_seed_records(records)
	HeroRoster._prestige_count = 2

	# Act
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	# Assert — RetiredCardList has 2 children (one per record).
	assert_int(screen._retired_card_list.get_child_count()).is_equal(2)


func test_retired_tab_card_text_includes_writer_locked_separators() -> void:
	# Arrange — AC-PR-17 surface: card metadata format renders via tr()
	# with the `%s · %s · Lv %d · Retired Day %d` writer-locked layout.
	var records: Array[Dictionary] = [
		{"display_name": "Theron", "class_id": "warrior", "level_at_retirement": 15, "retirement_unix_ts": 1700000000, "prestige_index": 1},
	]
	_seed_records(records)
	HeroRoster._prestige_count = 1

	# Act
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	# Assert — all four fields + writer-locked separator present.
	assert_int(screen._retired_card_list.get_child_count()).is_equal(1)
	var card_label: Label = screen._retired_card_list.get_child(0)
	assert_str(card_label.text).contains("Theron")
	assert_str(card_label.text).contains("Warrior")
	assert_str(card_label.text).contains("Lv 15")
	assert_str(card_label.text).contains("Retired Day 1")
	assert_str(card_label.text).contains("·")


# ===========================================================================
# Group D — Empty-state path
# ===========================================================================

func test_retired_tab_renders_empty_state_placeholder_when_no_records() -> void:
	# Arrange + Act — defensive: navigating with 0 records renders gracefully.
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	# Assert — exactly 1 placeholder card + baseline multiplier.
	assert_int(screen._retired_card_list.get_child_count()).is_equal(1)
	assert_str(screen._multiplier_label.text).is_equal("×1.00")


# ===========================================================================
# Group E — Live re-render on prestige_completed_signal
# ===========================================================================

func test_retired_tab_rebuilds_on_prestige_completed_signal() -> void:
	# Arrange
	var screen: Node = _make_guild_hall()
	screen.on_enter()
	assert_int(screen._retired_card_list.get_child_count()).is_equal(1)  # placeholder
	assert_str(screen._multiplier_label.text).is_equal("×1.00")

	# Act — simulate prestige firing while the player is on Guild Hall.
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

	# Assert — Retired tab auto-rebuilt: card list has 1 real card,
	# multiplier updated.
	assert_int(screen._retired_card_list.get_child_count()).is_equal(1)
	var card_label: Label = screen._retired_card_list.get_child(0)
	assert_str(card_label.text).contains("Theron")
	assert_str(screen._multiplier_label.text).is_equal("×1.05")


# ===========================================================================
# Group F — Prestige completion toast
# ===========================================================================

func test_prestige_completion_toast_shows_with_hero_name_on_signal() -> void:
	# Arrange
	var screen: Node = _make_guild_hall()
	screen.on_enter()
	assert_bool(screen._toast_label.visible).is_false()

	# Act — fake prestige record emit.
	var fake_record: Dictionary = {
		"display_name": "Theron",
		"class_id": "warrior",
		"level_at_retirement": 15,
		"retirement_unix_ts": 1700000000,
		"prestige_index": 1,
	}
	HeroRoster._prestige_count = 1
	HeroRoster._prestige_multiplier = 1.05
	HeroRoster.prestige_completed_signal.emit(fake_record, 1)

	# Assert — toast visible, full opacity, hero name in rendered text,
	# tween created.
	assert_bool(screen._toast_label.visible).is_true()
	assert_float(screen._toast_label.modulate.a).is_equal(1.0)
	assert_str(screen._toast_label.text).contains("Theron")
	assert_object(screen._toast_tween).is_not_null()


func test_prestige_completion_toast_no_op_when_record_missing_display_name() -> void:
	# Arrange + Act — corrupted record (no display_name) should NOT render
	# a malformed "%s joined..." toast. Skip cleanly.
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	var malformed: Dictionary = {
		"class_id": "warrior",
		"level_at_retirement": 15,
		"prestige_index": 1,
	}
	HeroRoster.prestige_completed_signal.emit(malformed, 1)

	# Assert — toast remains hidden, no tween created.
	assert_bool(screen._toast_label.visible).is_false()
	assert_object(screen._toast_tween).is_null()


func test_prestige_toast_kills_prior_tween_on_double_emit() -> void:
	# Arrange
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	var rec1: Dictionary = {"display_name": "Theron", "class_id": "warrior", "level_at_retirement": 15, "retirement_unix_ts": 1700000000, "prestige_index": 1}
	var rec2: Dictionary = {"display_name": "Mira", "class_id": "mage", "level_at_retirement": 15, "retirement_unix_ts": 1700100000, "prestige_index": 2}

	# Act 1 — first prestige fires
	HeroRoster.prestige_completed_signal.emit(rec1, 1)
	var first_tween: Tween = screen._toast_tween
	assert_object(first_tween).is_not_null()

	# Act 2 — rapid second prestige
	HeroRoster.prestige_completed_signal.emit(rec2, 2)

	# Assert — new tween instance + Mira in rendered text.
	assert_object(screen._toast_tween).is_not_same(first_tween)
	assert_str(screen._toast_label.text).contains("Mira")
