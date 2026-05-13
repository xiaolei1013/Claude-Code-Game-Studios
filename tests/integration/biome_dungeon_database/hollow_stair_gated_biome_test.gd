# Sprint 16 — Hollow Stair biome 6 + second link in the progression chain.
#
# The Hollow Stair is the SECOND gated biome (Biome.unlock_after =
# "ember_wastes_f5"). Chains the progression: Frostmire boss → Ember
# Wastes unlocks → Ember Wastes boss → Hollow Stair unlocks.
#
# Tests mirror ember_wastes_gated_biome_test.gd structure.
extends GdUnitTestSuite

const FloorUnlockScript = preload("res://src/core/floor_unlock_system/floor_unlock_system.gd")


# ---------------------------------------------------------------------------
# Spy state
# ---------------------------------------------------------------------------

var _spy_unlocked_count: int = 0
var _spy_last_unlocked_biome: String = ""


func _spy_on_biome_unlocked(biome_id: String) -> void:
	_spy_unlocked_count += 1
	_spy_last_unlocked_biome = biome_id


func _reset_spy() -> void:
	_spy_unlocked_count = 0
	_spy_last_unlocked_biome = ""


# ---------------------------------------------------------------------------
# Test 1 — biome loads + unlock_after reads as expected
# ---------------------------------------------------------------------------

func test_hollow_stair_biome_loads_and_gates_behind_ember_wastes_boss() -> void:
	var biome: Variant = DataRegistry.resolve("biomes", "hollow_stair")
	assert_object(biome).is_not_null()
	assert_str(String(biome.get("id"))).is_equal("hollow_stair")
	assert_str(String(biome.get("display_name"))).is_equal("The Hollow Stair")
	assert_str(String(biome.get("unlock_after"))).override_failure_message(
		"Hollow Stair should be gated behind clearing ember_wastes_f5"
	).is_equal("ember_wastes_f5")


# ---------------------------------------------------------------------------
# Test 2 — dungeon resolves with 5 floors (F5 boss)
# ---------------------------------------------------------------------------

func test_hollow_stair_dungeon_resolves_with_five_floors() -> void:
	var biome: Variant = DataRegistry.resolve("biomes", "hollow_stair")
	var dungeon: Resource = (biome.get("dungeons") as Array)[0] as Resource
	var floors: Array = dungeon.get("floors") as Array
	assert_int(floors.size()).is_equal(5)
	assert_bool(bool((floors[4] as Resource).get("is_boss_floor"))).is_true()


# ---------------------------------------------------------------------------
# Test 3 — all 5 new enemies load with hollow_stair biome tag
# ---------------------------------------------------------------------------

func test_hollow_stair_enemies_loaded_with_correct_biome_tag() -> void:
	var expected_enemy_ids: Array[String] = [
		"lamplit_chorister",
		"iron_silent",
		"stairmaw_hound",
		"cradle_judge",
		"the_last_step",
	]
	var missing: Array[String] = []
	var wrong_biome: Array[String] = []
	for enemy_id: String in expected_enemy_ids:
		var enemy: Variant = DataRegistry.resolve("enemies", enemy_id)
		if enemy == null:
			missing.append(enemy_id)
			continue
		var biome_tag: String = String(enemy.get("biome"))
		if biome_tag != "hollow_stair":
			wrong_biome.append("%s (biome=%s)" % [enemy_id, biome_tag])
	assert_int(missing.size()).is_equal(0)
	assert_int(wrong_biome.size()).is_equal(0)


# ---------------------------------------------------------------------------
# Test 4 — Fresh-save EXCLUDES hollow_stair (gated)
# ---------------------------------------------------------------------------

func test_fresh_save_excludes_gated_hollow_stair() -> void:
	var fu: Node = FloorUnlockScript.new()
	add_child(fu)
	auto_free(fu)
	await get_tree().process_frame
	var available: Array[String] = fu.get_available_biomes()
	assert_bool(available.has("hollow_stair")).override_failure_message(
		"Hollow Stair should be hidden from get_available_biomes pre-unlock"
	).is_false()


# ---------------------------------------------------------------------------
# Test 5 — clearing ember_wastes_f5 unlocks Hollow Stair
# ---------------------------------------------------------------------------

func test_clearing_ember_wastes_boss_unlocks_hollow_stair() -> void:
	var fu: Node = FloorUnlockScript.new()
	add_child(fu)
	auto_free(fu)
	await get_tree().process_frame

	# Step 1: clear frostmire_f5 to unlock ember_wastes (so subsequent
	# ember_wastes signal will pass the is_biome_available check).
	fu._on_floor_cleared_first_time(5, "frostmire", false)
	await get_tree().process_frame

	# Step 2: spy + clear ember_wastes_f5 to unlock hollow_stair.
	_reset_spy()
	fu.biome_unlocked.connect(_spy_on_biome_unlocked)
	fu._on_floor_cleared_first_time(5, "ember_wastes", false)
	await get_tree().process_frame

	# Assert — biome_unlocked fired for hollow_stair specifically.
	assert_int(_spy_unlocked_count).is_equal(1)
	assert_str(_spy_last_unlocked_biome).is_equal("hollow_stair")

	# Assert — hollow_stair now in available list.
	assert_bool(fu.get_available_biomes().has("hollow_stair")).is_true()
	# F1 unlocked, F2 still locked.
	assert_bool(fu.is_unlocked_in_biome("hollow_stair", 1)).is_true()
	assert_bool(fu.is_unlocked_in_biome("hollow_stair", 2)).is_false()

	fu.biome_unlocked.disconnect(_spy_on_biome_unlocked)


# ---------------------------------------------------------------------------
# Test 6 — full progression chain: Frostmire → Ember Wastes → Hollow Stair
# ---------------------------------------------------------------------------

# Validates the chain end-to-end: starting from fresh save (4 starter
# biomes), clearing each gate floor in order should unlock both gated
# biomes in sequence.
func test_full_chain_unlocks_both_gated_biomes_in_order() -> void:
	var fu: Node = FloorUnlockScript.new()
	add_child(fu)
	auto_free(fu)
	await get_tree().process_frame

	_reset_spy()
	fu.biome_unlocked.connect(_spy_on_biome_unlocked)

	# Cold launch: 4 starters available.
	var starters: Array[String] = fu.get_available_biomes()
	assert_int(starters.size()).override_failure_message(
		"Cold launch should have exactly 4 starter biomes (got %d: %s)"
		% [starters.size(), str(starters)]
	).is_equal(4)

	# Clear Frostmire boss → unlocks Ember Wastes.
	fu._on_floor_cleared_first_time(5, "frostmire", false)
	await get_tree().process_frame
	assert_int(_spy_unlocked_count).is_equal(1)
	assert_str(_spy_last_unlocked_biome).is_equal("ember_wastes")
	assert_int(fu.get_available_biomes().size()).is_equal(5)

	# Clear Ember Wastes boss → unlocks Hollow Stair.
	fu._on_floor_cleared_first_time(5, "ember_wastes", false)
	await get_tree().process_frame
	assert_int(_spy_unlocked_count).is_equal(2)
	assert_str(_spy_last_unlocked_biome).is_equal("hollow_stair")
	assert_int(fu.get_available_biomes().size()).is_equal(6)

	fu.biome_unlocked.disconnect(_spy_on_biome_unlocked)
