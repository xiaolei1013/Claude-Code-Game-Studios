# Sprint 21+ Prestige V1.0 / Story 3 UI (Slice B) — Guild Hall
# "Hall of Retired Heroes" button visibility-gating tests.
#
# Per `design/gdd/prestige-system.md` §F + cozy-register rule (don't
# tease the player with an empty Hall surface):
#   - 0 prestiges → button hidden
#   - ≥1 prestige → button shown
#   - Live update on prestige_completed_signal (button pops in)
extends GdUnitTestSuite

const GuildHallScene = preload("res://assets/screens/guild_hall/guild_hall.tscn")


func _make_guild_hall() -> Node:
	var screen: Node = GuildHallScene.instantiate()
	add_child(screen)
	auto_free(screen)
	return screen


func before_test() -> void:
	HeroRoster._prestige_count = 0
	HeroRoster._prestige_multiplier = 1.0
	HeroRoster._retired_hero_records.clear()


func after_test() -> void:
	HeroRoster._prestige_count = 0
	HeroRoster._prestige_multiplier = 1.0
	HeroRoster._retired_hero_records.clear()


# ===========================================================================
# Group A — Visibility gate
# ===========================================================================

func test_hall_button_hidden_when_no_prestige() -> void:
	# 0 prestiges → button hidden. Cozy-register: don't tease the player
	# with an empty Hall surface.
	var screen: Node = _make_guild_hall()
	screen.on_enter()
	assert_bool(screen._hall_nav_button.visible).is_false()


func test_hall_button_visible_when_one_prestige_completed() -> void:
	# Direct mutation + on_enter render. The button must surface
	# immediately on a save-load with prestige_count > 0.
	HeroRoster._prestige_count = 1
	HeroRoster._prestige_multiplier = 1.05

	var screen: Node = _make_guild_hall()
	screen.on_enter()

	assert_bool(screen._hall_nav_button.visible).is_true()


func test_hall_button_label_uses_localized_string() -> void:
	# AC-PR-17 surface: button label routes through tr().
	HeroRoster._prestige_count = 1
	var screen: Node = _make_guild_hall()
	screen.on_enter()
	# Verify the localized value (tr returns "Hall of Retired Heroes"
	# per en.csv, or the key verbatim if translation didn't load —
	# both are NON-empty).
	assert_bool(screen._hall_nav_button.text.length() > 0).is_true()


# ===========================================================================
# Group B — Live update on prestige_completed_signal
# ===========================================================================

func test_hall_button_pops_in_on_prestige_completed_signal() -> void:
	# Subscriber path: a prestige fires while Guild Hall is foregrounded
	# (e.g., the Hero Detail Modal closed back to Guild Hall after a
	# successful prestige). The button must transition hidden → visible
	# without requiring a screen refresh.
	var screen: Node = _make_guild_hall()
	screen.on_enter()
	assert_bool(screen._hall_nav_button.visible).is_false()

	HeroRoster._prestige_count = 1
	HeroRoster._prestige_multiplier = 1.05
	var fake_record: Dictionary = {
		"display_name": "Theron",
		"class_id": "warrior",
		"level_at_retirement": 15,
		"retirement_unix_ts": 1700000000,
		"prestige_index": 1,
	}
	HeroRoster.prestige_completed_signal.emit(fake_record, 1)

	assert_bool(screen._hall_nav_button.visible).is_true()


# ===========================================================================
# Group C — Prestige completion toast
# ===========================================================================

func test_prestige_completion_toast_shows_with_hero_name_on_signal() -> void:
	# Subscriber path: prestige fires → toast renders with the hero's
	# display_name interpolated into the writer-locked
	# `prestige_complete_toast` value. The tween starts at modulate.a=1.0
	# and fades over TOAST_FADE_DURATION_SEC.
	var screen: Node = _make_guild_hall()
	screen.on_enter()
	# Toast hidden pre-signal.
	assert_bool(screen._toast_label.visible).is_false()

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

	# Toast visible, opacity full, hero name in the rendered text.
	assert_bool(screen._toast_label.visible).is_true()
	assert_float(screen._toast_label.modulate.a).is_equal(1.0)
	assert_str(screen._toast_label.text).contains("Theron")
	# Tween created.
	assert_object(screen._toast_tween).is_not_null()


func test_prestige_completion_toast_no_op_when_record_missing_display_name() -> void:
	# Defensive: a corrupted record without display_name should NOT
	# render a malformed "%s joined..." toast. Skip cleanly.
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	var malformed: Dictionary = {
		"class_id": "warrior",
		"level_at_retirement": 15,
		"prestige_index": 1,
	}
	HeroRoster.prestige_completed_signal.emit(malformed, 1)

	assert_bool(screen._toast_label.visible).is_false()
	assert_object(screen._toast_tween).is_null()


func test_prestige_toast_kills_prior_tween_on_double_emit() -> void:
	# Two rapid prestiges (theoretical — flow is one at a time): the
	# second toast MUST kill the first tween before starting a new one.
	# Mirrors the formation_assignment toast pattern.
	var screen: Node = _make_guild_hall()
	screen.on_enter()

	var rec1: Dictionary = {"display_name": "Theron", "class_id": "warrior", "level_at_retirement": 15, "retirement_unix_ts": 1700000000, "prestige_index": 1}
	var rec2: Dictionary = {"display_name": "Mira", "class_id": "mage", "level_at_retirement": 15, "retirement_unix_ts": 1700100000, "prestige_index": 2}

	HeroRoster.prestige_completed_signal.emit(rec1, 1)
	var first_tween: Tween = screen._toast_tween
	assert_object(first_tween).is_not_null()

	HeroRoster.prestige_completed_signal.emit(rec2, 2)
	# New tween created (different reference); text updated to Mira.
	assert_object(screen._toast_tween).is_not_same(first_tween)
	assert_str(screen._toast_label.text).contains("Mira")
