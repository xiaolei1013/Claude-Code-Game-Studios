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

	# --- FRAGDUMP2 (temporary) ---
	var _vb: Array = screen.find_children("FloorPickerBiomeVBox", "", true, false)
	var _fpb: Variant = screen.get("_fp_biomes")
	var _fpbn: int = (_fpb as Array).size() if _fpb is Array else -99
	var _dr2: Node = get_tree().root.get_node_or_null("DataRegistry")
	var _res: Variant = _dr2.call("resolve", "biomes", "forest_reach") if _dr2 != null else null
	var _vbchildren: int = -1
	if _vb.size() > 0:
		_vbchildren = (_vb.front() as Node).get_child_count()
	push_warning("[FRAGDUMP2] vbox_found=%d vbox_children=%d | _fp_biomes_size=%d | resolve(forest_reach)=%s" % [
		_vb.size(), _vbchildren, _fpbn, str(_res)])
	# --- end ---

	var biome_ids: Array[String] = []
	var vbox: Node = screen.find_children("FloorPickerBiomeVBox", "", true, false).front() as Node
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

	# --- FRAGILITY INSTRUMENTATION (temporary) ---
	var _dr: Node = get_tree().root.get_node_or_null("DataRegistry")
	var _dbg: Array[String] = []
	if _dr != null:
		for _b: Variant in _dr.call("get_all_by_type", "biomes"):
			var _bid: String = String(_b.get("id")) if ("id" in _b) else "?"
			var _dn: int = -1
			if ("dungeons" in _b) and (_b.get("dungeons") is Array):
				_dn = (_b.get("dungeons") as Array).size()
			var _st: String = String(_b.get("status")) if ("status" in _b) else "?"
			_dbg.append("%s(d=%d,st=%s)" % [_bid, _dn, _st])
	push_warning("[FRAGDUMP] tabs=%s | DR_biomes=%s | BFC=%s | avail=%s | active_mvp=%s" % [
		str(tab_biome_ids), str(_dbg),
		str(fu.get("BIOME_FLOOR_COUNT")),
		str(fu.call("get_available_biomes")),
		str(fu.get("active_biome_mvp"))])
	# --- end instrumentation ---

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
