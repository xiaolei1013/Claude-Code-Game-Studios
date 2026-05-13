# Sprint 16 M1 — Whispering Crags biome 2 content + multi-biome seeding tests.
#
# Verifies:
#   1. The new whispering_crags.tres biome loads via DataRegistry
#   2. The new whispering_crags_dungeon_01.tres dungeon resolves with 5 floors
#   3. The 5 new enemies (crag_wraith, stoneback_grub, windborne_hunter,
#      spire_warden, echo_serpent) load with the correct biome tag
#   4. FloorUnlock's fresh-save default seeds BOTH biomes (forest_reach
#      + whispering_crags), not just forest_reach
#   5. The Matchup Assignment screen's biome iterator includes both biomes
#      (verified indirectly via FloorUnlock.get_available_biomes)
extends GdUnitTestSuite

const FloorUnlockScript = preload("res://src/core/floor_unlock_system/floor_unlock_system.gd")


# ---------------------------------------------------------------------------
# Test 1 — biome resource loads
# ---------------------------------------------------------------------------

func test_whispering_crags_biome_loads_via_data_registry() -> void:
	var biome: Variant = DataRegistry.resolve("biomes", "whispering_crags")
	assert_object(biome).override_failure_message(
		"DataRegistry could not resolve biome 'whispering_crags'. "
		+ "Check assets/data/biomes/whispering_crags.tres exists + has id field set."
	).is_not_null()
	assert_str(String(biome.get("id"))).is_equal("whispering_crags")
	assert_str(String(biome.get("display_name"))).is_equal("Whispering Crags")
	assert_str(String(biome.get("status"))).is_equal("active")


# ---------------------------------------------------------------------------
# Test 2 — dungeon resource resolves with 5 floors
# ---------------------------------------------------------------------------

func test_whispering_crags_dungeon_resolves_with_five_floors() -> void:
	var biome: Variant = DataRegistry.resolve("biomes", "whispering_crags")
	assert_object(biome).is_not_null()
	var dungeons: Array = biome.get("dungeons") as Array
	assert_int(dungeons.size()).override_failure_message(
		"Biome should have exactly 1 dungeon (MVP single-dungeon-per-biome)"
	).is_equal(1)
	var dungeon: Resource = dungeons[0] as Resource
	assert_object(dungeon).is_not_null()
	var floors: Array = dungeon.get("floors") as Array
	assert_int(floors.size()).override_failure_message(
		"Whispering Crags should have 5 floors (matching Forest Reach floor count)"
	).is_equal(5)
	# Floor 5 is the boss.
	var f5: Resource = floors[4] as Resource
	assert_bool(bool(f5.get("is_boss_floor"))).is_true()


# ---------------------------------------------------------------------------
# Test 3 — all 5 new enemies load with whispering_crags biome tag
# ---------------------------------------------------------------------------

func test_whispering_crags_enemies_loaded_with_correct_biome_tag() -> void:
	var expected_enemy_ids: Array[String] = [
		"crag_wraith",
		"stoneback_grub",
		"windborne_hunter",
		"spire_warden",
		"echo_serpent",
	]
	var missing: Array[String] = []
	var wrong_biome: Array[String] = []
	for enemy_id: String in expected_enemy_ids:
		var enemy: Variant = DataRegistry.resolve("enemies", enemy_id)
		if enemy == null:
			missing.append(enemy_id)
			continue
		var biome_tag: String = String(enemy.get("biome"))
		if biome_tag != "whispering_crags":
			wrong_biome.append("%s (biome=%s)" % [enemy_id, biome_tag])
	assert_int(missing.size()).override_failure_message(
		"Missing enemies: %s" % str(missing)
	).is_equal(0)
	assert_int(wrong_biome.size()).override_failure_message(
		"Enemies with wrong biome tag: %s" % str(wrong_biome)
	).is_equal(0)


# ---------------------------------------------------------------------------
# Test 4 — FloorUnlock fresh-save default seeds both biomes
# ---------------------------------------------------------------------------

# Sprint 16 M1: _seed_fresh_save_default was updated to iterate
# BIOME_FLOOR_COUNT instead of hard-coding {forest_reach: 0}. Verify both
# biomes are seeded at 0 on a fresh save.
func test_fresh_save_seeds_both_forest_reach_and_whispering_crags() -> void:
	var fu: Node = FloorUnlockScript.new()
	add_child(fu)
	auto_free(fu)
	await get_tree().process_frame  # let _ready populate BIOME_FLOOR_COUNT

	# At this point _ready ran which calls _seed_fresh_save_default — but the
	# instance is fresh so _unlock_state should be the seeded default.
	# Note: we don't hydrate from save here; the seeded state is post-_ready.
	var unlock_state: Dictionary = fu.get_save_data()
	# The save schema wraps state under a top-level key per FloorUnlock's
	# get_save_data contract — see existing test fixtures for the exact key.
	# Pull the inner state and check both biomes.
	assert_int(fu.get_highest_cleared("forest_reach")).override_failure_message(
		"forest_reach should be seeded at 0"
	).is_equal(0)
	assert_int(fu.get_highest_cleared("whispering_crags")).override_failure_message(
		"whispering_crags should be seeded at 0 (multi-biome fresh-save default)"
	).is_equal(0)


# ---------------------------------------------------------------------------
# Test 5 — get_available_biomes returns BOTH biomes
# ---------------------------------------------------------------------------

func test_get_available_biomes_lists_both_biomes() -> void:
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	assert_object(fu).is_not_null()
	var biomes: Array[String] = fu.get_available_biomes()
	assert_bool(biomes.has("forest_reach")).override_failure_message(
		"Available biomes should include forest_reach"
	).is_true()
	assert_bool(biomes.has("whispering_crags")).override_failure_message(
		"Available biomes should include whispering_crags (new in Sprint 16 M1)"
	).is_true()


# ---------------------------------------------------------------------------
# Test 6 — Whispering Crags F1 is unlocked on a fresh save
# ---------------------------------------------------------------------------

# Player-visible: from cold launch, the player can dispatch a run to either
# Forest Reach F1 OR Whispering Crags F1.
func test_whispering_crags_floor_1_is_unlocked_on_fresh_save() -> void:
	var fu: Node = FloorUnlockScript.new()
	add_child(fu)
	auto_free(fu)
	await get_tree().process_frame
	assert_bool(fu.is_unlocked_in_biome("whispering_crags", 1)).override_failure_message(
		"Whispering Crags Floor 1 should be unlocked on fresh save"
	).is_true()
	# Floor 2 locked until F1 is cleared.
	assert_bool(fu.is_unlocked_in_biome("whispering_crags", 2)).override_failure_message(
		"Whispering Crags Floor 2 should be LOCKED on fresh save (requires F1 clear)"
	).is_false()
