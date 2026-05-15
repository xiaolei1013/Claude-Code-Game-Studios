# Sprint 20 S20-M5 — Guild Hall theme implementation contract tests.
#
# Per design/ux/guild-hall.md UX-GH-09 (synergy strip) + UX-GH-13 (no color-only
# information) + DESIGN.md typography/component-vocabulary commitments +
# design/ux/interaction-patterns.md patterns #10 (Guild-Ledger-Entry) and
# #11 (Conditional Strip).
#
# Test groups:
#   A — Theme has LedgerRow variation defined (interaction-patterns #10)
#   B — Guild Hall scene has SynergyBadge node (UX-GH-09)
#   C — SynergyBadge starts hidden (Conditional Strip — pattern #11)
#   D — SynergyBadge shows correct text when synergy active
#   E — HeroCard uses LedgerRow theme variation
extends GdUnitTestSuite

const GuildHallScene := preload("res://assets/screens/guild_hall/guild_hall.tscn")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

const PARCHMENT_THEME_PATH: String = "res://assets/ui/parchment_theme.tres"

var _injected_hero_ids: Array[int] = []


func _inject_hero(id: int, class_id: String, display_name: String, current_level: int = 1) -> void:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = class_id
	fake.display_name = display_name
	fake.current_level = current_level
	fake.xp = 0
	HeroRoster._heroes[id] = fake
	_injected_hero_ids.append(id)


func _set_formation(slot0_id: int, slot1_id: int, slot2_id: int) -> void:
	# Direct field write to bypass set_formation_slot validation; matches
	# the Sprint 18 synergy_badge_test.gd fixture pattern.
	var slots: Array[int] = [slot0_id, slot1_id, slot2_id]
	HeroRoster._formation_slots = slots


func after_test() -> void:
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()
	var empty: Array[int] = [0, 0, 0]
	HeroRoster._formation_slots = empty


# ===========================================================================
# Group A — Theme has LedgerRow variation (interaction-patterns #10)
# ===========================================================================

func test_parchment_theme_defines_ledger_row_variation() -> void:
	# LedgerRow is the Guild-Ledger-Entry pattern: parchment sub-panel
	# register for rows inside a larger parchment panel.
	var theme: Theme = load(PARCHMENT_THEME_PATH) as Theme
	assert_object(theme).is_not_null()

	# Theme.get_type_variation_base() returns the base_type registered for a
	# theme variation, or empty StringName when not defined. For LedgerRow
	# the base_type is Button per assets/ui/parchment_theme.tres.
	var base: StringName = theme.get_type_variation_base(&"LedgerRow")
	assert_str(str(base)).override_failure_message(
		"LedgerRow theme variation must extend &\"Button\" per "
		+ "interaction-patterns.md #10 + parchment_theme.tres. Got: '%s'"
		% str(base)
	).is_equal("Button")


func test_parchment_theme_ledger_row_has_normal_stylebox() -> void:
	# StyleBox for the normal state must exist (HeroCards inherit it via
	# theme_type_variation).
	var theme: Theme = load(PARCHMENT_THEME_PATH) as Theme
	var stylebox: StyleBox = theme.get_stylebox("normal", &"LedgerRow")
	assert_object(stylebox).override_failure_message(
		"LedgerRow theme variation must define a 'normal' StyleBox per "
		+ "parchment_theme.tres. Got null — check the LedgerRow/styles/normal "
		+ "line in the theme file."
	).is_not_null()


# ===========================================================================
# Group B — Guild Hall scene has SynergyBadge node (UX-GH-09)
# ===========================================================================

func test_guild_hall_scene_has_synergy_badge_node() -> void:
	# UX-GH-09: Conditional Strip pattern; SynergyBadge sits between the
	# RosterPanel and the NavBar buttons.
	var instance: Node = GuildHallScene.instantiate()
	auto_free(instance)
	var badge: PanelContainer = instance.get_node_or_null("SynergyBadge") as PanelContainer
	assert_object(badge).override_failure_message(
		"Guild Hall scene must contain a SynergyBadge child node "
		+ "(PanelContainer) per UX-GH-09. Check guild_hall.tscn."
	).is_not_null()


func test_guild_hall_synergy_badge_has_label_child() -> void:
	var instance: Node = GuildHallScene.instantiate()
	auto_free(instance)
	var label: Label = instance.get_node_or_null("SynergyBadge/SynergyLabel") as Label
	assert_object(label).override_failure_message(
		"SynergyBadge must contain a SynergyLabel child for the synergy "
		+ "display text (UX-GH-09 + interaction-patterns #11)."
	).is_not_null()


# ===========================================================================
# Group C — Conditional Strip behavior — starts hidden (pattern #11)
# ===========================================================================

func test_guild_hall_synergy_badge_hidden_by_default() -> void:
	# Conditional Strip pattern #11: zero layout impact when no synergy
	# active. Visible=false is the canonical "hidden" state.
	var instance: Node = GuildHallScene.instantiate()
	auto_free(instance)
	var badge: PanelContainer = instance.get_node_or_null("SynergyBadge") as PanelContainer
	assert_bool(badge.visible).override_failure_message(
		"SynergyBadge must be visible=false by default per Conditional "
		+ "Strip pattern (interaction-patterns.md #11) — scene-time state "
		+ "before on_enter computes the active synergy."
	).is_false()


# ===========================================================================
# Group D — SynergyBadge shows correct text when 3-warrior synergy active
# ===========================================================================

func test_guild_hall_synergy_badge_visible_when_three_warriors_form_steel_wall() -> void:
	# 3-warrior formation → Steel Wall synergy → badge visible with
	# localized "Display Name: Effect" text per UX-GH-09.
	_inject_hero(801, "warrior", "TestHero801")
	_inject_hero(802, "warrior", "TestHero802")
	_inject_hero(803, "warrior", "TestHero803")
	_set_formation(801, 802, 803)

	var instance: Node = GuildHallScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()

	var badge: PanelContainer = instance.get_node("SynergyBadge") as PanelContainer
	var label: Label = instance.get_node("SynergyBadge/SynergyLabel") as Label

	assert_bool(badge.visible).override_failure_message(
		"SynergyBadge should be visible when formation has an active synergy "
		+ "(3 warriors → steel_wall). Got visible=false."
	).is_true()
	# Locale en.csv: class_synergy_badge_steel_wall = "Steel Wall"
	#                class_synergy_effect_steel_wall = "+25% gold vs bruisers"
	assert_str(label.text).contains("Steel Wall")
	assert_str(label.text).contains("bruisers")


func test_guild_hall_synergy_badge_hidden_when_no_synergy() -> void:
	# Mixed-class formation (no synergy) → badge stays hidden.
	_inject_hero(811, "warrior", "TestHero811")
	_inject_hero(812, "mage", "TestHero812")
	_set_formation(811, 812, 0)  # only 2 heroes, last slot empty

	var instance: Node = GuildHallScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()

	var badge: PanelContainer = instance.get_node("SynergyBadge") as PanelContainer
	assert_bool(badge.visible).is_false()


# ===========================================================================
# Group E — HeroCard uses LedgerRow theme variation
# ===========================================================================

func test_guild_hall_hero_card_uses_ledger_row_theme_variation() -> void:
	# Per UX-GH-04 + interaction-patterns #10: HeroCard rows in the roster
	# panel apply the LedgerRow theme variation so they read as ledger entries
	# inside the larger parchment panel.
	_inject_hero(821, "warrior", "TestHero821")

	var instance: Node = GuildHallScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()

	var roster_list: VBoxContainer = instance.get_node("RosterPanel/RosterScroll/RosterList") as VBoxContainer
	var first_card: Button = roster_list.get_child(0) as Button
	assert_object(first_card).override_failure_message(
		"Expected at least one HeroCard Button child in RosterList after "
		+ "on_enter. Got null — check _build_hero_card + _refresh_roster_panel."
	).is_not_null()
	assert_str(str(first_card.theme_type_variation)).override_failure_message(
		"HeroCard Button must have theme_type_variation = &\"LedgerRow\" per "
		+ "interaction-patterns #10. Got: '%s'"
		% str(first_card.theme_type_variation)
	).is_equal("LedgerRow")
