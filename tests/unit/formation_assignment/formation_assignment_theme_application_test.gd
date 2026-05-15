# Sprint 21 S21-M1 — Formation Assignment theme implementation contract tests.
#
# Per design/ux/formation-assignment.md + design/ux/interaction-patterns.md
# patterns #10 (Guild-Ledger-Entry), #12 (Slot Button), #13 (Two-Tap Flow).
#
# Test groups:
#   A — Theme has SlotButton + SlotButtonSelected variations
#   B — Slot buttons get SlotButton theme variation by default
#   C — Selected slot gets SlotButtonSelected variation; others stay SlotButton
#   D — Hero roster Buttons use LedgerRow theme variation (parity with Guild Hall)
extends GdUnitTestSuite

const FormationAssignmentScene := preload("res://assets/screens/formation_assignment/formation_assignment.tscn")
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


func after_test() -> void:
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()
	var empty: Array[int] = [0, 0, 0]
	HeroRoster._formation_slots = empty


# ===========================================================================
# Group A — Theme has SlotButton + SlotButtonSelected variations
# ===========================================================================

func test_parchment_theme_defines_slot_button_variation() -> void:
	# Pattern #12 default state: parchment ground + 2px Slate Ink border +
	# 6px corner radius (panel-like content holder).
	var theme: Theme = load(PARCHMENT_THEME_PATH) as Theme
	assert_object(theme).is_not_null()

	var base: StringName = theme.get_type_variation_base(&"SlotButton")
	assert_str(str(base)).override_failure_message(
		"SlotButton theme variation must extend &\"Button\" per "
		+ "interaction-patterns.md #12. Got: '%s'" % str(base)
	).is_equal("Button")


func test_parchment_theme_defines_slot_button_selected_variation() -> void:
	# Pattern #12 selected state: 4px Guild Amber border (weight + color
	# change — colorblind-safe per spec).
	var theme: Theme = load(PARCHMENT_THEME_PATH) as Theme
	var base: StringName = theme.get_type_variation_base(&"SlotButtonSelected")
	assert_str(str(base)).override_failure_message(
		"SlotButtonSelected theme variation must extend &\"Button\". Got: '%s'" % str(base)
	).is_equal("Button")


func test_slot_button_selected_has_thicker_border_than_default() -> void:
	# Colorblind-safe contract: selected state differs from default by BOTH
	# border weight AND color, not just color. This test asserts the weight
	# delta; the color delta is asserted by the styleboxes carrying different
	# bg/border colors (visible via theme.get_stylebox).
	var theme: Theme = load(PARCHMENT_THEME_PATH) as Theme
	var normal_box: StyleBoxFlat = theme.get_stylebox("normal", &"SlotButton") as StyleBoxFlat
	var selected_box: StyleBoxFlat = theme.get_stylebox("normal", &"SlotButtonSelected") as StyleBoxFlat
	assert_object(normal_box).is_not_null()
	assert_object(selected_box).is_not_null()

	assert_int(selected_box.border_width_left).override_failure_message(
		"SlotButtonSelected.border_width_left must be > SlotButton.border_width_left "
		+ "for colorblind-safe selection cue. Got SlotButton=%d, SlotButtonSelected=%d"
		% [normal_box.border_width_left, selected_box.border_width_left]
	).is_greater(normal_box.border_width_left)


# ===========================================================================
# Group B — Slot buttons get SlotButton theme variation by default
# ===========================================================================

func test_formation_assignment_slot_buttons_get_slot_button_variation() -> void:
	# After on_enter, each slot button must have theme_type_variation =
	# &"SlotButton" (default state when not selected). The active-slot
	# index defaults to 0, so slots 1 and 2 carry the default variation.
	#
	# Test-env note: _refresh_formation_panel queue_free's the .tscn-static
	# slot buttons (Slot0Button, Slot1Button, Slot2Button) and adds dynamic
	# replacements. queue_free is deferred to the next idle frame, so we
	# await one process_frame to let the static buttons clear before we
	# query the dynamic ones at index 0/1/2.
	var instance: Node = FormationAssignmentScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()
	await get_tree().process_frame

	var slots_hbox: HBoxContainer = instance.get_node("FormationPanel/SlotsHBox") as HBoxContainer
	assert_object(slots_hbox).is_not_null()
	# Slot 1 (index 1) is NOT the default active slot → carries SlotButton.
	var slot_btn_1: Button = slots_hbox.get_child(1) as Button
	assert_object(slot_btn_1).is_not_null()
	assert_str(str(slot_btn_1.theme_type_variation)).override_failure_message(
		"Non-selected slot Button must carry theme_type_variation = &\"SlotButton\" "
		+ "per interaction-patterns #12. Got: '%s'"
		% str(slot_btn_1.theme_type_variation)
	).is_equal("SlotButton")


# ===========================================================================
# Group C — Selected slot gets SlotButtonSelected variation
# ===========================================================================

func test_formation_assignment_selected_slot_gets_selected_variation() -> void:
	# The active-slot index defaults to 0; slot 0's Button must carry
	# theme_type_variation = &"SlotButtonSelected" after on_enter.
	# See test above for the queue_free / await rationale.
	var instance: Node = FormationAssignmentScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()
	await get_tree().process_frame

	var slots_hbox: HBoxContainer = instance.get_node("FormationPanel/SlotsHBox") as HBoxContainer
	var slot_btn_0: Button = slots_hbox.get_child(0) as Button
	assert_object(slot_btn_0).is_not_null()
	assert_str(str(slot_btn_0.theme_type_variation)).override_failure_message(
		"Selected slot (active_slot_index=0) Button must carry "
		+ "theme_type_variation = &\"SlotButtonSelected\". Got: '%s'"
		% str(slot_btn_0.theme_type_variation)
	).is_equal("SlotButtonSelected")


# ===========================================================================
# Group D — Hero roster Buttons use LedgerRow variation
# ===========================================================================

func test_formation_assignment_hero_buttons_use_ledger_row_variation() -> void:
	# Per UX-FA-04 + pattern #10 (Guild-Ledger-Entry): roster rows in
	# Formation Assignment must read the same way they do in Guild Hall —
	# as ledger-row entries inside the larger parchment panel.
	_inject_hero(901, "warrior", "TestHero901")

	var instance: Node = FormationAssignmentScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()
	await get_tree().process_frame

	var roster_list: VBoxContainer = instance.get_node("RosterPanel/RosterScroll/RosterList") as VBoxContainer
	assert_object(roster_list).is_not_null()
	var first_btn: Button = roster_list.get_child(0) as Button
	assert_object(first_btn).override_failure_message(
		"Expected a Button in the roster list after on_enter with at least "
		+ "one injected hero. Got: null — check _refresh_roster_panel."
	).is_not_null()
	assert_str(str(first_btn.theme_type_variation)).override_failure_message(
		"Hero roster Button must carry theme_type_variation = &\"LedgerRow\" "
		+ "per pattern #10 (parity with Guild Hall HeroCards). Got: '%s'"
		% str(first_btn.theme_type_variation)
	).is_equal("LedgerRow")
