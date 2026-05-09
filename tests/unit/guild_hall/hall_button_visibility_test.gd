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
