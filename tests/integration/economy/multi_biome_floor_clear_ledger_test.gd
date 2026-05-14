# Regression test: Sprint 17 progression-chain playtest bug — boss floor doesn't progress.
#
# Root cause (pre-fix): Economy._floor_clear_bonus_credited was Dictionary[int, int]
# keyed by floor_index alone. Designed for MVP single-biome (Forest Reach). Sprint 16
# added 5 more biomes (Whispering Crags, Sunken Ruins, Frostmire, Ember Wastes,
# Hollow Stair) — each with F1-F5. The int-keyed ledger collides: clearing any
# biome's F_N sets credited[N]; subsequent F_N clears in OTHER biomes see bonus
# <= already and return false, blocking floor_cleared_first_time emit at
# dungeon_run_orchestrator.gd:1097, which blocks FloorUnlockSystem advance,
# which blocks the biome-progression gate (ember_wastes unlock_after frostmire_f5,
# hollow_stair unlock_after ember_wastes_f5).
#
# Player-visible: after clearing Forest Reach end-to-end, no other biome's
# floors can advance past F1. Reported via S17-M6 playtest 2026-05-14.
#
# Fix: widen Economy ledger to Dictionary[String, int] keyed by "<biome_id>_f<idx>".
# Signature change: try_award_floor_clear(biome_id, floor_index, bonus_amount).
# Signal payload: first_clear_awarded(biome_id, floor_index).
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")


# ---------------------------------------------------------------------------
# Group A — the bug: same floor_index in different biomes both first-credit
# ---------------------------------------------------------------------------

func test_multi_biome_same_floor_index_both_credit_first_clear() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()
	var first_clear_emissions: Array[Array] = []
	economy.first_clear_awarded.connect(
		func(biome_id: String, floor_index: int) -> void:
			first_clear_emissions.append([biome_id, floor_index])
	)

	# Act — clear Forest Reach F5 (boss), then clear Frostmire F5 (different biome,
	# same floor_index). Pre-fix: second call silently fails. Post-fix: both succeed.
	var forest_result: bool = economy.try_award_floor_clear("forest_reach", 5, 2500)
	var frostmire_result: bool = economy.try_award_floor_clear("frostmire", 5, 2500)

	# Assert — BOTH calls credit + emit first_clear_awarded
	assert_bool(forest_result).is_true()
	assert_bool(frostmire_result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(5000)  # 2500 + 2500
	assert_int(first_clear_emissions.size()).is_equal(2)
	assert_array(first_clear_emissions[0]).is_equal(["forest_reach", 5])
	assert_array(first_clear_emissions[1]).is_equal(["frostmire", 5])

	# Cleanup
	economy.free()


func test_multi_biome_same_floor_index_ledger_keys_namespace_per_biome() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — credit F5 in three different biomes
	economy.try_award_floor_clear("forest_reach", 5, 2500)
	economy.try_award_floor_clear("frostmire", 5, 2500)
	economy.try_award_floor_clear("ember_wastes", 5, 2500)

	# Assert — three separate ledger entries, namespaced by biome
	assert_bool(economy._floor_clear_bonus_credited.has("forest_reach_f5")).is_true()
	assert_bool(economy._floor_clear_bonus_credited.has("frostmire_f5")).is_true()
	assert_bool(economy._floor_clear_bonus_credited.has("ember_wastes_f5")).is_true()
	assert_int(economy._floor_clear_bonus_credited["forest_reach_f5"]).is_equal(2500)
	assert_int(economy._floor_clear_bonus_credited["frostmire_f5"]).is_equal(2500)
	assert_int(economy._floor_clear_bonus_credited["ember_wastes_f5"]).is_equal(2500)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Group B — within a single biome, monotonic credit still holds (ADR-0002)
# ---------------------------------------------------------------------------

func test_single_biome_repeat_clear_still_returns_false() -> void:
	# Arrange — Forest Reach F3 first-clear primes ledger.
	var economy: Node = EconomyScript.new()
	economy.try_award_floor_clear("forest_reach", 3, 3000)
	var first_clear_emit_count: Array[int] = [0]
	economy.first_clear_awarded.connect(
		func(_b: String, _f: int) -> void: first_clear_emit_count[0] += 1
	)

	# Act — second identical call in same biome
	var result: bool = economy.try_award_floor_clear("forest_reach", 3, 3000)

	# Assert — false, no re-credit, no signal
	assert_bool(result).is_false()
	assert_int(economy.get_gold_balance()).is_equal(3000)
	assert_int(first_clear_emit_count[0]).is_equal(0)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Group C — LOSING-then-WIN reclaim path still works PER BIOME
# ---------------------------------------------------------------------------

func test_losing_then_win_reclaim_in_one_biome_does_not_affect_other_biome() -> void:
	# Arrange — Frostmire F3 LOSING (half bonus, 1500), then WIN reclaim (delta 1500 = 3000 total).
	var economy: Node = EconomyScript.new()
	economy.try_award_floor_clear("frostmire", 3, 1500)  # LOSING prime
	economy.try_award_floor_clear("frostmire", 3, 3000)  # WIN reclaim
	var first_clear_emit_count: Array[int] = [0]
	economy.first_clear_awarded.connect(
		func(_b: String, _f: int) -> void: first_clear_emit_count[0] += 1
	)

	# Act — Ember Wastes F3 should still be a fresh first-clear (different biome)
	var result: bool = economy.try_award_floor_clear("ember_wastes", 3, 3000)

	# Assert — Ember Wastes F3 credits + emits its own first_clear
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(6000)  # 1500 + 1500 + 3000
	assert_int(first_clear_emit_count[0]).is_equal(1)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Group D — save/load round-trip preserves biome-keyed ledger
# ---------------------------------------------------------------------------

func test_save_load_round_trip_preserves_multi_biome_ledger() -> void:
	# Arrange — credit several biomes
	var economy_a: Node = EconomyScript.new()
	economy_a.try_award_floor_clear("forest_reach", 1, 100)
	economy_a.try_award_floor_clear("forest_reach", 5, 2500)
	economy_a.try_award_floor_clear("frostmire", 1, 100)
	economy_a.try_award_floor_clear("frostmire", 5, 2500)

	# Act — save then restore into a fresh instance
	var payload: Dictionary = economy_a.get_save_data()
	var economy_b: Node = EconomyScript.new()
	economy_b.load_save_data(payload)

	# Assert — all four ledger entries survive
	assert_bool(economy_b._floor_clear_bonus_credited.has("forest_reach_f1")).is_true()
	assert_bool(economy_b._floor_clear_bonus_credited.has("forest_reach_f5")).is_true()
	assert_bool(economy_b._floor_clear_bonus_credited.has("frostmire_f1")).is_true()
	assert_bool(economy_b._floor_clear_bonus_credited.has("frostmire_f5")).is_true()
	# And a re-credit attempt on any one returns false (the gate still works post-load)
	var repeat: bool = economy_b.try_award_floor_clear("forest_reach", 5, 2500)
	assert_bool(repeat).is_false()

	# Cleanup
	economy_a.free()
	economy_b.free()


# ---------------------------------------------------------------------------
# Group E — legacy schema_version=1 save migration
# ---------------------------------------------------------------------------

func test_legacy_v1_save_migrates_int_keyed_ledger_to_forest_reach_prefix() -> void:
	# Arrange — synthesize a legacy Sprint 11-era save payload (schema v1, int-keyed
	# ledger; entries assumed to be Forest Reach since v1 predates multi-biome).
	var legacy_payload: Dictionary = {
		"schema_version": 1,
		"gold_balance": 3850,
		"lifetime_gold_earned": 3850,
		"floor_clear_bonus_credited": {1: 100, 2: 250, 3: 500, 4: 1000, 5: 2000},
	}
	var economy: Node = EconomyScript.new()

	# Act — load the legacy payload
	economy.load_save_data(legacy_payload)

	# Assert — int keys migrated to "forest_reach_f<idx>" string keys
	assert_bool(economy._floor_clear_bonus_credited.has("forest_reach_f1")).is_true()
	assert_bool(economy._floor_clear_bonus_credited.has("forest_reach_f5")).is_true()
	assert_int(economy._floor_clear_bonus_credited["forest_reach_f1"]).is_equal(100)
	assert_int(economy._floor_clear_bonus_credited["forest_reach_f5"]).is_equal(2000)
	# And Frostmire F5 is now a fresh first-clear opportunity (not blocked by the
	# legacy F5 credit, which was implicitly Forest Reach)
	var frostmire_result: bool = economy.try_award_floor_clear("frostmire", 5, 2500)
	assert_bool(frostmire_result).is_true()

	# Cleanup
	economy.free()
