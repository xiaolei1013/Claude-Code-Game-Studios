# Sprint 16 — Frostmire biome 4 content + 4-biome fresh-save seeding tests.
#
# Mirrors whispering_crags_load_test + sunken_ruins_load_test patterns.
# The biome-add pattern is mature: data files only, zero code changes.
extends GdUnitTestSuite

const FloorUnlockScript = preload("res://src/core/floor_unlock_system/floor_unlock_system.gd")


# ---------------------------------------------------------------------------
# Test 1 — biome resource loads
# ---------------------------------------------------------------------------

func test_frostmire_biome_loads_via_data_registry() -> void:
	var biome: Variant = DataRegistry.resolve("biomes", "frostmire")
	assert_object(biome).is_not_null()
	assert_str(String(biome.get("id"))).is_equal("frostmire")
	assert_str(String(biome.get("display_name"))).is_equal("Frostmire")
	assert_str(String(biome.get("status"))).is_equal("active")


# ---------------------------------------------------------------------------
# Test 2 — dungeon resource resolves with 5 floors
# ---------------------------------------------------------------------------

func test_frostmire_dungeon_resolves_with_five_floors() -> void:
	var biome: Variant = DataRegistry.resolve("biomes", "frostmire")
	assert_object(biome).is_not_null()
	var dungeons: Array = biome.get("dungeons") as Array
	assert_int(dungeons.size()).is_equal(1)
	var dungeon: Resource = dungeons[0] as Resource
	var floors: Array = dungeon.get("floors") as Array
	assert_int(floors.size()).is_equal(5)
	var f5: Resource = floors[4] as Resource
	assert_bool(bool(f5.get("is_boss_floor"))).is_true()


# ---------------------------------------------------------------------------
# Test 3 — all 5 new enemies load with frostmire biome tag
# ---------------------------------------------------------------------------

func test_frostmire_enemies_loaded_with_correct_biome_tag() -> void:
	var expected_enemy_ids: Array[String] = [
		"marrow_witch",
		"icebound_pilgrim",
		"frost_revenant",
		"mire_colossus",
		"the_hollow_winter",
	]
	var missing: Array[String] = []
	var wrong_biome: Array[String] = []
	for enemy_id: String in expected_enemy_ids:
		var enemy: Variant = DataRegistry.resolve("enemies", enemy_id)
		if enemy == null:
			missing.append(enemy_id)
			continue
		var biome_tag: String = String(enemy.get("biome"))
		if biome_tag != "frostmire":
			wrong_biome.append("%s (biome=%s)" % [enemy_id, biome_tag])
	assert_int(missing.size()).override_failure_message(
		"Missing enemies: %s" % str(missing)
	).is_equal(0)
	assert_int(wrong_biome.size()).override_failure_message(
		"Enemies with wrong biome tag: %s" % str(wrong_biome)
	).is_equal(0)


# ---------------------------------------------------------------------------
# Test 4 — FloorUnlock fresh-save default seeds all 4 biomes
# ---------------------------------------------------------------------------

func test_fresh_save_seeds_all_four_biomes() -> void:
	var fu: Node = FloorUnlockScript.new()
	add_child(fu)
	auto_free(fu)
	await get_tree().process_frame
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)
	assert_int(fu.get_highest_cleared("whispering_crags")).is_equal(0)
	assert_int(fu.get_highest_cleared("sunken_ruins")).is_equal(0)
	assert_int(fu.get_highest_cleared("frostmire")).is_equal(0)


# ---------------------------------------------------------------------------
# Test 5 — get_available_biomes returns all four
# ---------------------------------------------------------------------------

func test_get_available_biomes_lists_all_four() -> void:
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	assert_object(fu).is_not_null()
	var biomes: Array[String] = fu.get_available_biomes()
	assert_bool(biomes.has("forest_reach")).is_true()
	assert_bool(biomes.has("whispering_crags")).is_true()
	assert_bool(biomes.has("sunken_ruins")).is_true()
	assert_bool(biomes.has("frostmire")).override_failure_message(
		"Available biomes should include frostmire (new in this PR)"
	).is_true()


# ---------------------------------------------------------------------------
# Test 6 — Frostmire F1 is unlocked on a fresh save
# ---------------------------------------------------------------------------

func test_frostmire_floor_1_is_unlocked_on_fresh_save() -> void:
	var fu: Node = FloorUnlockScript.new()
	add_child(fu)
	auto_free(fu)
	await get_tree().process_frame
	assert_bool(fu.is_unlocked_in_biome("frostmire", 1)).is_true()
	assert_bool(fu.is_unlocked_in_biome("frostmire", 2)).is_false()
