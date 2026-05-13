# Sprint 16 — Ember Wastes biome 5 + first biome progression gate test.
#
# Ember Wastes is the first GATED biome (Biome.unlock_after = "frostmire_f5").
# Tests:
#   1. ember_wastes.tres loads via DataRegistry
#   2. unlock_after field reads as "frostmire_f5"
#   3. 5-floor dungeon resolves; F5 is boss
#   4. 5 new enemies load with correct biome tag
#   5. Fresh-save EXCLUDES ember_wastes from _unlock_state (gated)
#   6. get_available_biomes does NOT include ember_wastes pre-unlock
#   7. Firing floor_cleared_first_time(5, "frostmire", false) seeds
#      ember_wastes + emits biome_unlocked exactly once
#   8. Firing the gate-clear signal AGAIN does NOT re-emit biome_unlocked
extends GdUnitTestSuite

const FloorUnlockScript = preload("res://src/core/floor_unlock_system/floor_unlock_system.gd")


# ---------------------------------------------------------------------------
# Spy state (class-level to avoid lambda-capture marshalling issues)
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
# Test 1 — biome loads
# ---------------------------------------------------------------------------

func test_ember_wastes_biome_loads_via_data_registry() -> void:
	var biome: Variant = DataRegistry.resolve("biomes", "ember_wastes")
	assert_object(biome).is_not_null()
	assert_str(String(biome.get("id"))).is_equal("ember_wastes")
	assert_str(String(biome.get("display_name"))).is_equal("Ember Wastes")


# ---------------------------------------------------------------------------
# Test 2 — unlock_after gate field reads as expected
# ---------------------------------------------------------------------------

func test_ember_wastes_has_unlock_after_frostmire_boss() -> void:
	var biome: Variant = DataRegistry.resolve("biomes", "ember_wastes")
	assert_object(biome).is_not_null()
	assert_str(String(biome.get("unlock_after"))).override_failure_message(
		"Ember Wastes should be gated behind clearing frostmire_f5 (the bog boss)"
	).is_equal("frostmire_f5")


# ---------------------------------------------------------------------------
# Test 3 — dungeon resolves with 5 floors (F5 boss)
# ---------------------------------------------------------------------------

func test_ember_wastes_dungeon_resolves_with_five_floors() -> void:
	var biome: Variant = DataRegistry.resolve("biomes", "ember_wastes")
	assert_object(biome).is_not_null()
	var dungeon: Resource = (biome.get("dungeons") as Array)[0] as Resource
	var floors: Array = dungeon.get("floors") as Array
	assert_int(floors.size()).is_equal(5)
	assert_bool(bool((floors[4] as Resource).get("is_boss_floor"))).is_true()


# ---------------------------------------------------------------------------
# Test 4 — all 5 new enemies load with ember_wastes biome tag
# ---------------------------------------------------------------------------

func test_ember_wastes_enemies_loaded_with_correct_biome_tag() -> void:
	var expected_enemy_ids: Array[String] = [
		"ash_djinn",
		"glasswind_walker",
		"cinder_jackal",
		"obsidian_titan",
		"the_kiln_below",
	]
	var missing: Array[String] = []
	var wrong_biome: Array[String] = []
	for enemy_id: String in expected_enemy_ids:
		var enemy: Variant = DataRegistry.resolve("enemies", enemy_id)
		if enemy == null:
			missing.append(enemy_id)
			continue
		var biome_tag: String = String(enemy.get("biome"))
		if biome_tag != "ember_wastes":
			wrong_biome.append("%s (biome=%s)" % [enemy_id, biome_tag])
	assert_int(missing.size()).is_equal(0)
	assert_int(wrong_biome.size()).is_equal(0)


# ---------------------------------------------------------------------------
# Test 5 — Fresh-save EXCLUDES ember_wastes (it's gated)
# ---------------------------------------------------------------------------

func test_fresh_save_excludes_gated_ember_wastes() -> void:
	var fu: Node = FloorUnlockScript.new()
	add_child(fu)
	auto_free(fu)
	await get_tree().process_frame
	# Starter biomes are seeded.
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)
	assert_int(fu.get_highest_cleared("frostmire")).is_equal(0)
	# Gated biome is NOT seeded. get_highest_cleared returns 0 by default
	# for missing keys, but the _unlock_state dict should not have the key.
	# Check via get_available_biomes (which DOES filter gated biomes).
	var available: Array[String] = fu.get_available_biomes()
	assert_bool(available.has("ember_wastes")).override_failure_message(
		"Ember Wastes should be hidden from get_available_biomes pre-unlock"
	).is_false()


# ---------------------------------------------------------------------------
# Test 6 — firing the gate-clear signal seeds ember_wastes + emits signal
# ---------------------------------------------------------------------------

func test_clearing_frostmire_boss_unlocks_ember_wastes() -> void:
	var fu: Node = FloorUnlockScript.new()
	add_child(fu)
	auto_free(fu)
	await get_tree().process_frame
	_reset_spy()
	fu.biome_unlocked.connect(_spy_on_biome_unlocked)

	# Pre-condition: ember_wastes NOT in available list.
	assert_bool(fu.get_available_biomes().has("ember_wastes")).is_false()

	# Act — simulate clearing frostmire_f5 for the first time.
	# (Direct method call rather than dispatching through Orchestrator —
	# the signal handler is the unit under test.)
	fu._on_floor_cleared_first_time(5, "frostmire", false)
	await get_tree().process_frame

	# Assert — biome_unlocked fired once with the gated biome id.
	assert_int(_spy_unlocked_count).is_equal(1)
	assert_str(_spy_last_unlocked_biome).is_equal("ember_wastes")

	# Assert — ember_wastes now in available list.
	assert_bool(fu.get_available_biomes().has("ember_wastes")).override_failure_message(
		"Ember Wastes should be available after the gate fires"
	).is_true()

	# Assert — ember_wastes F1 unlocked, F2+ locked (fresh-state seed).
	assert_bool(fu.is_unlocked_in_biome("ember_wastes", 1)).is_true()
	assert_bool(fu.is_unlocked_in_biome("ember_wastes", 2)).is_false()

	fu.biome_unlocked.disconnect(_spy_on_biome_unlocked)


# ---------------------------------------------------------------------------
# Test 7 — idempotent: re-clearing the gate floor does NOT re-emit
# ---------------------------------------------------------------------------

func test_re_clearing_gate_floor_does_not_re_emit_biome_unlocked() -> void:
	var fu: Node = FloorUnlockScript.new()
	add_child(fu)
	auto_free(fu)
	await get_tree().process_frame

	# First clear — should fire signal once.
	_reset_spy()
	fu.biome_unlocked.connect(_spy_on_biome_unlocked)
	fu._on_floor_cleared_first_time(5, "frostmire", false)
	await get_tree().process_frame
	assert_int(_spy_unlocked_count).is_equal(1)

	# Second clear — should NOT re-emit.
	fu._on_floor_cleared_first_time(5, "frostmire", false)
	await get_tree().process_frame
	assert_int(_spy_unlocked_count).override_failure_message(
		"biome_unlocked must be idempotent — re-clearing the gate floor should not re-emit"
	).is_equal(1)

	fu.biome_unlocked.disconnect(_spy_on_biome_unlocked)
