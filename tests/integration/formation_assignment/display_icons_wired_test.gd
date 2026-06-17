# Wire the 6 deferred display icons authored in PR #226:
#   - 3 class-role icons (warrior/mage/rogue) onto the formation hero cards
#   - 3 matchup-state icons (advantage/neutral/disadvantage) onto the
#     floor-picker recommendation, reflecting the player's CURRENT lineup.
#
# Mirrors tests/integration/guild_hall/mvp_icons_wired_test.gd:
#   Group A/D — icon resolution by asset path (null-graceful for the 4 classes
#               without authored art per DESIGN.md "Required MVP icon set")
#   Group B/C — the icons are actually WIRED into the live screen, with crisp
#               pixel sampling (TEXTURE_FILTER_NEAREST) and decorative overlays
#               that never steal taps (MOUSE_FILTER_IGNORE). This is the
#               anti-scaffold guard — scaffolded-but-unwired is the project's
#               dominant defect class.
#   Group E — the matchup verdict reuses the SAME resolver combat uses
#             (DefaultMatchupResolver.resolve_floor_matchup -> effectiveness_label
#             ∈ {"Strong","Even","Weak"}), so the icon can never diverge from the
#             1.5×/0.7× throughput the player actually experiences.
#
# Live-autoload isolation: tests that mutate HeroRoster / FloorUnlock snapshot
# get_save_data() up-front and load_save_data() back in cleanup (per the
# test-isolation-via-live-autoload-mutation rule — no save-persistence leakage).
extends GdUnitTestSuite

const FormationAssignmentScene = preload(
	"res://assets/screens/formation_assignment/formation_assignment.tscn"
)

const ICON_DIR := "res://assets/art/ui/icons/"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Instantiate and enter the screen so all @onready refs are valid.
func _make_screen() -> Node:
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	screen.on_enter()
	return screen


## Build a typed Floor resource populated with the given enemy_list entries
## (a pure data bag for the matchup helpers — not added to DataRegistry).
func _make_floor(entries: Array[Dictionary]) -> Floor:
	var floor_res: Floor = Floor.new()
	floor_res.enemy_list = entries
	return floor_res


func _roster() -> Node:
	return get_tree().root.get_node_or_null("HeroRoster")


## Finds the roster-panel hero Button whose label is for the named hero.
## Card text format: "<display_name> (<class_id> Lv<n> · vs <archetype>)".
func _find_hero_button(screen: Node, display_name: String) -> Button:
	var list: Node = screen.get_node_or_null("RosterPanel/RosterScroll/RosterList")
	if list == null:
		return null
	for child: Node in list.get_children():
		var btn: Button = child as Button
		if btn != null and btn.text.begins_with(display_name + " ("):
			return btn
	return null


func _find_matchup_icon(screen: Node) -> TextureRect:
	for n: Node in screen.find_children("FloorMatchupIcon", "TextureRect", true, false):
		return n as TextureRect
	return null


## Seeds the live formation with one hero per slot for the given class_ids.
func _seed_formation(roster: Node, class_ids: Array) -> void:
	for i: int in range(roster.formation_size()):
		roster.set_formation_slot(i, 0)  # clear first (0 == empty slot)
	for i: int in range(class_ids.size()):
		var hero: RefCounted = roster.add_hero(class_ids[i])
		assert_object(hero).is_not_null().override_failure_message(
			"add_hero('%s') returned null — roster cap or unresolvable class" % class_ids[i]
		)
		roster.set_formation_slot(i, hero.instance_id)


func _clear_formation(roster: Node) -> void:
	for i: int in range(roster.formation_size()):
		roster.set_formation_slot(i, 0)


# ---------------------------------------------------------------------------
# Group A — class-icon resolution (deterministic; null-graceful for the 4
# classes without authored art).
# ---------------------------------------------------------------------------

func test_class_icon_for_warrior_resolves_warrior_asset() -> void:
	var screen: Node = _make_screen()
	var tex: Texture2D = screen.call("_class_icon_for", "warrior") as Texture2D
	assert_object(tex).is_not_null()
	assert_str(tex.resource_path).is_equal(ICON_DIR + "class_warrior.png")


func test_class_icon_for_mage_resolves_mage_asset() -> void:
	var screen: Node = _make_screen()
	var tex: Texture2D = screen.call("_class_icon_for", "mage") as Texture2D
	assert_object(tex).is_not_null()
	assert_str(tex.resource_path).is_equal(ICON_DIR + "class_mage.png")


func test_class_icon_for_rogue_resolves_rogue_asset() -> void:
	var screen: Node = _make_screen()
	var tex: Texture2D = screen.call("_class_icon_for", "rogue") as Texture2D
	assert_object(tex).is_not_null()
	assert_str(tex.resource_path).is_equal(ICON_DIR + "class_rogue.png")


func test_class_icon_for_iconless_classes_returns_null() -> void:
	# cleric/archer/berserker/paladin have no authored icon (MVP scope). They
	# must degrade gracefully to NO icon — not crash, not a placeholder.
	var screen: Node = _make_screen()
	var iconless: Array[String] = ["cleric", "archer", "berserker", "paladin"]
	for class_id: String in iconless:
		assert_object(screen.call("_class_icon_for", class_id)).is_null() \
			.override_failure_message("class '%s' has no icon and must resolve null" % class_id)


func test_class_icon_for_unknown_id_returns_null() -> void:
	var screen: Node = _make_screen()
	assert_object(screen.call("_class_icon_for", "not_a_class")).is_null()


# ---------------------------------------------------------------------------
# Group B — class icons WIRED onto hero cards (anti-scaffold integration proof).
# ---------------------------------------------------------------------------

func test_hero_card_for_warrior_wires_class_icon_nearest() -> void:
	# Arrange — seed a warrior into the live roster (snapshot for isolation).
	var roster: Node = _roster()
	var snapshot: Dictionary = roster.get_save_data()
	var warrior: RefCounted = roster.add_hero("warrior")
	var warrior_name: String = String(warrior.display_name)

	# Act — enter the screen (rebuilds the roster panel from live state).
	var screen: Node = _make_screen()
	var btn: Button = _find_hero_button(screen, warrior_name)

	# Assert — icon wired to the warrior asset + crisp pixel sampling.
	assert_object(btn).is_not_null().override_failure_message(
		"warrior hero card '%s' must exist in the roster panel" % warrior_name
	)
	assert_object(btn.icon).is_not_null().override_failure_message(
		"warrior card must have a class icon wired (scaffolded-but-unwired guard)"
	)
	assert_str(btn.icon.resource_path).is_equal(ICON_DIR + "class_warrior.png")
	assert_int(btn.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)

	roster.load_save_data(snapshot)


func test_hero_card_for_iconless_class_has_no_icon() -> void:
	var roster: Node = _roster()
	var snapshot: Dictionary = roster.get_save_data()
	var cleric: RefCounted = roster.add_hero("cleric")
	var cleric_name: String = String(cleric.display_name)

	var screen: Node = _make_screen()
	var btn: Button = _find_hero_button(screen, cleric_name)

	assert_object(btn).is_not_null().override_failure_message(
		"cleric hero card '%s' must exist in the roster panel" % cleric_name
	)
	assert_object(btn.icon).is_null().override_failure_message(
		"cleric has no authored icon; the card must show NO icon (graceful degradation)"
	)

	roster.load_save_data(snapshot)


# ---------------------------------------------------------------------------
# Group C — matchup icon node exists with crisp, non-interactive properties.
# ---------------------------------------------------------------------------

func test_floor_matchup_icon_node_is_crisp_and_non_interactive() -> void:
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	var fu_snapshot: Dictionary = fu.get_save_data()
	fu.load_save_data({"highest_cleared": {"forest_reach": 0}})
	var screen: Node = _make_screen()
	screen.call("_show_floor_picker")

	var icon: TextureRect = _find_matchup_icon(screen)
	assert_object(icon).is_not_null().override_failure_message(
		"FloorMatchupIcon must be created when the floor picker opens"
	)
	assert_int(icon.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_int(icon.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE) \
		.override_failure_message("decorative icon must never steal taps (z_index ≠ input picking)")
	assert_int(icon.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)

	fu.load_save_data(fu_snapshot)


# ---------------------------------------------------------------------------
# Group D — matchup effectiveness label → icon mapping (Strong/Even/Weak).
# ---------------------------------------------------------------------------

func test_matchup_icon_for_label_maps_three_states() -> void:
	var screen: Node = _make_screen()
	var strong: Texture2D = screen.call("_matchup_icon_for_label", "Strong") as Texture2D
	var even: Texture2D = screen.call("_matchup_icon_for_label", "Even") as Texture2D
	var weak: Texture2D = screen.call("_matchup_icon_for_label", "Weak") as Texture2D
	assert_object(strong).is_not_null()
	assert_object(even).is_not_null()
	assert_object(weak).is_not_null()
	assert_str(strong.resource_path).is_equal(ICON_DIR + "matchup_advantage.png")
	assert_str(even.resource_path).is_equal(ICON_DIR + "matchup_neutral.png")
	assert_str(weak.resource_path).is_equal(ICON_DIR + "matchup_disadvantage.png")


func test_matchup_icon_for_unknown_label_returns_null() -> void:
	var screen: Node = _make_screen()
	assert_object(screen.call("_matchup_icon_for_label", "")).is_null()
	assert_object(screen.call("_matchup_icon_for_label", "Bogus")).is_null()


# ---------------------------------------------------------------------------
# Group E — formation matchup verdict reuses the combat resolver. The label
# drives the icon, so this proves the icon reflects real 1.5×/0.7× throughput.
# forest_reach fixtures: hollow_brute is a bruiser; warrior counters bruiser.
# ---------------------------------------------------------------------------

func test_formation_matchup_label_strong_when_majority_counters() -> void:
	# 2 of 3 warriors counter bruiser → strict majority (≥2) → Strong.
	var roster: Node = _roster()
	var snapshot: Dictionary = roster.get_save_data()
	var screen: Node = _make_screen()
	_seed_formation(roster, ["warrior", "warrior", "mage"])
	var bruiser_floor: Floor = _make_floor([{"enemy_id": "hollow_brute", "count": 3}])

	var label: String = String(screen.call("_formation_matchup_label_for_floor", bruiser_floor))

	assert_str(label).is_equal("Strong")
	roster.load_save_data(snapshot)


func test_formation_matchup_label_weak_when_no_counter() -> void:
	# No mage counters bruiser → zero counters → Weak (all kills at 0.7×).
	var roster: Node = _roster()
	var snapshot: Dictionary = roster.get_save_data()
	var screen: Node = _make_screen()
	_seed_formation(roster, ["mage", "mage", "mage"])
	var bruiser_floor: Floor = _make_floor([{"enemy_id": "hollow_brute", "count": 3}])

	var label: String = String(screen.call("_formation_matchup_label_for_floor", bruiser_floor))

	assert_str(label).is_equal("Weak")
	roster.load_save_data(snapshot)


func test_formation_matchup_label_even_when_below_majority() -> void:
	# 1 of 3 counters bruiser → some coverage but below the ≥2 majority → Even.
	var roster: Node = _roster()
	var snapshot: Dictionary = roster.get_save_data()
	var screen: Node = _make_screen()
	_seed_formation(roster, ["warrior", "mage", "mage"])
	var bruiser_floor: Floor = _make_floor([{"enemy_id": "hollow_brute", "count": 3}])

	var label: String = String(screen.call("_formation_matchup_label_for_floor", bruiser_floor))

	assert_str(label).is_equal("Even")
	roster.load_save_data(snapshot)


func test_formation_matchup_label_empty_when_no_formation() -> void:
	# Empty formation → no verdict to show → "" (caller hides the icon).
	var roster: Node = _roster()
	var snapshot: Dictionary = roster.get_save_data()
	var screen: Node = _make_screen()
	_clear_formation(roster)
	var bruiser_floor: Floor = _make_floor([{"enemy_id": "hollow_brute", "count": 3}])

	var label: String = String(screen.call("_formation_matchup_label_for_floor", bruiser_floor))

	assert_str(label).is_equal("")
	roster.load_save_data(snapshot)


func test_formation_matchup_label_empty_when_floor_has_no_archetypes() -> void:
	# A floor with no resolvable enemies has no matchup → "" (icon hidden).
	var roster: Node = _roster()
	var snapshot: Dictionary = roster.get_save_data()
	var screen: Node = _make_screen()
	_seed_formation(roster, ["warrior", "warrior", "warrior"])
	var empty_floor: Floor = _make_floor([] as Array[Dictionary])

	var label: String = String(screen.call("_formation_matchup_label_for_floor", empty_floor))

	assert_str(label).is_equal("")
	roster.load_save_data(snapshot)
