# Sprint 25 S25-N2-rev — Floor picker lock-indicator UX polish tests.
#
# Per FloorUnlock GDD #16 §F: locked floors should communicate "blocked"
# via a lock affordance + tooltip explaining the unlock prerequisite,
# not just a grayed-out button. This test covers the visual contract:
#   - Unlocked floor → "F<N>" label, no tooltip
#   - Locked floor → "🔒 F<N>" label, tooltip names the prerequisite floor
extends GdUnitTestSuite

const FormationAssignmentScene = preload(
	"res://assets/screens/formation_assignment/formation_assignment.tscn"
)


var _snapshot_roster: Dictionary = {}
var _snapshot_floor_unlock: Dictionary = {}


func before_test() -> void:
	# Snapshot autoloads so tests don't leak state into each other.
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_snapshot_roster = roster.get_save_data() if roster != null else {}
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	_snapshot_floor_unlock = fu.get_save_data() if fu != null else {}


func after_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and not _snapshot_roster.is_empty():
		roster.load_save_data(_snapshot_roster)
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	if fu != null and not _snapshot_floor_unlock.is_empty():
		fu.load_save_data(_snapshot_floor_unlock)


func _open_floor_picker() -> Node:
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	screen.on_enter()
	# _show_floor_picker is the entry point that builds the per-biome tabs +
	# floor buttons via _render_floor_picker_biome_tabs.
	screen.call("_show_floor_picker")
	return screen


# ===========================================================================
# Group A — Unlocked floor button rendering
# ===========================================================================

func test_unlocked_floor_button_shows_plain_floor_label() -> void:
	# Arrange — fresh save state: F1 of forest_reach is unlocked per GDD #16 R2.
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	# Ensure a clean unlock state so F1 is the highest-cleared+1 frontier
	fu.load_save_data({"highest_cleared": {"forest_reach": 0}})

	# Act — open the floor picker to build the per-biome tabs
	var screen: Node = _open_floor_picker()

	# Assert — the F1 button (forest_reach) exists + has plain "F1" text
	var biome_tab: Node = screen.get_node_or_null(
		"FloorPickerOverlay/FloorPickerScroll/FloorPickerBiomeVBox/BiomeTab_forest_reach"
	)
	# Fall back to searching by name pattern if the overlay path varies
	if biome_tab == null:
		for child: Node in screen.find_children("BiomeTab_forest_reach", "", true, false):
			biome_tab = child
			break
	assert_object(biome_tab).is_not_null().override_failure_message(
		"Could not find BiomeTab_forest_reach in the floor picker overlay tree."
	)
	var f1_button: Button = null
	for btn: Node in biome_tab.find_children("FloorButton_1", "Button", true, false):
		f1_button = btn as Button
		break
	assert_object(f1_button).is_not_null()
	# Unlocked → plain text, no tooltip
	assert_str(f1_button.text).is_equal("F1")
	assert_str(f1_button.tooltip_text).is_equal("")
	assert_bool(f1_button.disabled).is_false()


# ===========================================================================
# Group B — Locked floor button rendering
# ===========================================================================

func test_locked_floor_button_shows_lock_emoji_and_tooltip() -> void:
	# Arrange — fresh unlock state so F2-F5 of forest_reach are locked.
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	fu.load_save_data({"highest_cleared": {"forest_reach": 0}})

	# Act
	var screen: Node = _open_floor_picker()

	# Assert — find F2 button (the first locked floor)
	var f2_button: Button = null
	for btn: Node in screen.find_children("FloorButton_2", "Button", true, false):
		# Restrict to the forest_reach biome tab (other biomes may have F2 too)
		var parent_chain: Node = btn.get_parent()
		while parent_chain != null:
			if parent_chain.name == "BiomeTab_forest_reach":
				f2_button = btn as Button
				break
			parent_chain = parent_chain.get_parent()
		if f2_button != null:
			break
	assert_object(f2_button).is_not_null().override_failure_message(
		"Could not find FloorButton_2 inside BiomeTab_forest_reach."
	)
	# Locked → lock emoji prefix + tooltip naming the prerequisite floor
	assert_bool(f2_button.text.begins_with("🔒")).is_true().override_failure_message(
		"Expected locked F2 button text to start with 🔒; got: '%s'" % f2_button.text
	)
	assert_bool(f2_button.text.contains("F2")).is_true()
	assert_int(f2_button.tooltip_text.length()).is_greater(0).override_failure_message(
		"Expected locked F2 button to have a non-empty tooltip; got empty string."
	)
	# Tooltip should reference floor 1 (the prerequisite) via the localized format.
	# Locale resolves to "Clear floor 1 first" or returns the key verbatim — either
	# way, "1" should appear in the resolved string.
	assert_bool(f2_button.tooltip_text.contains("1")).is_true()
	assert_bool(f2_button.disabled).is_true()


func test_locked_floor_5_tooltip_references_floor_4_prerequisite() -> void:
	# Arrange — F5 is locked when F4 hasn't been cleared yet.
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	fu.load_save_data({"highest_cleared": {"forest_reach": 0}})

	# Act
	var screen: Node = _open_floor_picker()

	# Assert — F5 of forest_reach
	var f5_button: Button = null
	for btn: Node in screen.find_children("FloorButton_5", "Button", true, false):
		var parent_chain: Node = btn.get_parent()
		while parent_chain != null:
			if parent_chain.name == "BiomeTab_forest_reach":
				f5_button = btn as Button
				break
			parent_chain = parent_chain.get_parent()
		if f5_button != null:
			break
	assert_object(f5_button).is_not_null()
	# Tooltip should reference floor 4 (the prerequisite for F5)
	assert_bool(f5_button.tooltip_text.contains("4")).is_true().override_failure_message(
		"Expected F5 tooltip to reference floor 4 as prerequisite; got: '%s'"
		% f5_button.tooltip_text
	)
