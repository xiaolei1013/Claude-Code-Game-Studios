# Sprint 26 M1 — Dispatch floor picker honors FloorUnlock.get_available_biomes().
#
# Verifies the floor picker shows only biomes the player has unlocked,
# not every biome in DataRegistry. Per GDD #16 R7: FloorUnlockSystem is
# the authoritative source of "which biomes are currently playable" —
# UI consumers MUST call get_available_biomes() and not read Biome DB's
# status field directly.
extends GdUnitTestSuite

const FormationAssignmentScene = preload(
	"res://assets/screens/formation_assignment/formation_assignment.tscn"
)


var _snapshot_floor_unlock: Dictionary = {}


func before_test() -> void:
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	_snapshot_floor_unlock = fu.get_save_data() if fu != null else {}


func after_test() -> void:
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	if fu != null and not _snapshot_floor_unlock.is_empty():
		fu.load_save_data(_snapshot_floor_unlock)


func _open_picker_and_collect_biome_tabs() -> Array[String]:
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	screen.on_enter()
	screen.call("_show_floor_picker")

	var biome_ids: Array[String] = []
	# The biome tabs are children of PickerBiomeVBox (formation_assignment.tscn:
	# FloorPickerOverlay/PickerPanel/PickerContent/PickerScroll/PickerBiomeVBox, and
	# the `_floor_picker_biome_vbox` @onready). An earlier scene refactor renamed
	# this node FloorPickerBiomeVBox -> PickerBiomeVBox; this test searched the stale
	# name, found nothing, and silently returned [] — so the contains() assertions
	# failed whenever the suite actually reached this test. Search the real name.
	var vbox: Node = screen.find_children("PickerBiomeVBox", "", true, false).front() as Node
	if vbox == null:
		return biome_ids
	for child: Node in vbox.get_children():
		if child.name.begins_with("BiomeTab_"):
			biome_ids.append(child.name.substr(len("BiomeTab_")))
	return biome_ids


# ===========================================================================
# Group A — Fresh-save player sees only starter biomes
# ===========================================================================

func test_fresh_save_shows_only_starter_biomes_not_chained() -> void:
	# Arrange — reset to fresh-save state. FloorUnlock seeds the starter
	# biomes (those with Biome.unlock_after == ""); chained biomes
	# (ember_wastes, hollow_stair) stay out of _unlock_state until their
	# gate fires.
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	# Re-trigger fresh-save seeding by clearing state and calling the seeder.
	fu.set("_unlock_state", {})
	fu.call("_seed_fresh_save_default")

	# Act — open the floor picker
	var tab_biome_ids: Array[String] = _open_picker_and_collect_biome_tabs()

	# Assert — chained biomes (require unlock_after gate) MUST NOT appear
	assert_array(tab_biome_ids).not_contains(["ember_wastes"]).override_failure_message(
		"Chained biome 'ember_wastes' appeared as a Dispatch tab on a fresh save. "
		+ "It should only appear after clearing frostmire_f5. Tabs found: %s"
		% str(tab_biome_ids)
	)
	assert_array(tab_biome_ids).not_contains(["hollow_stair"]).override_failure_message(
		"Chained biome 'hollow_stair' appeared on fresh save. "
		+ "Tabs found: %s" % str(tab_biome_ids)
	)


func test_fresh_save_includes_forest_reach_starter_biome() -> void:
	# Arrange
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	fu.set("_unlock_state", {})
	fu.call("_seed_fresh_save_default")

	# Act
	var tab_biome_ids: Array[String] = _open_picker_and_collect_biome_tabs()

	# Assert — forest_reach is THE canonical starter biome
	assert_array(tab_biome_ids).contains(["forest_reach"]).override_failure_message(
		"Starter biome 'forest_reach' missing from Dispatch tabs. Tabs found: %s"
		% str(tab_biome_ids)
	)


# ===========================================================================
# Group B — Chained biome appears after gate fires
# ===========================================================================

func test_chained_biome_appears_after_gate_fires() -> void:
	# Arrange — seed FloorUnlock so ember_wastes IS unlocked (simulating
	# post-frostmire-F5-clear state).
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	var state: Dictionary = fu.get_save_data()
	# load_save_data with explicit ember_wastes entry — that's the "unlocked" signal
	# (chained biomes only enter _unlock_state after their gate fires).
	var hc: Dictionary = state.get("highest_cleared", {}) as Dictionary
	hc["ember_wastes"] = 0  # unlocked but not yet cleared
	state["highest_cleared"] = hc
	fu.load_save_data(state)

	# Act
	var tab_biome_ids: Array[String] = _open_picker_and_collect_biome_tabs()

	# Assert — ember_wastes now appears
	assert_array(tab_biome_ids).contains(["ember_wastes"]).override_failure_message(
		"ember_wastes did not appear in Dispatch tabs after its gate fired. "
		+ "Tabs found: %s" % str(tab_biome_ids)
	)
