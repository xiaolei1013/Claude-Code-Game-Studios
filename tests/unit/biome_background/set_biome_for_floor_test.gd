# BiomeBackground per-floor modulation tests.
#
# Covers the boss-floor darkening contract: floor matching
# BOSS_FLOOR_INDEX_MVP of any biome renders at BOSS_FLOOR_DARKEN_FACTOR
# RGB intensity (alpha preserved) so the player visually reads the boss
# fight as distinct from regular floors.
extends GdUnitTestSuite

const BiomeBackgroundScene = preload("res://assets/screens/_shared/biome_background.tscn")
const BiomeBackgroundScript = preload("res://assets/screens/_shared/biome_background.gd")


func _make_bg() -> ColorRect:
	var bg: ColorRect = BiomeBackgroundScene.instantiate()
	add_child(bg)
	auto_free(bg)
	return bg


# ===========================================================================
# Group A — Regular floors render at baseline brightness
# ===========================================================================

func test_floor_1_uses_baseline_palette_unchanged() -> void:
	var bg: ColorRect = _make_bg()
	var expected: Color = BiomeBackgroundScript.PALETTE["forest_reach"]

	bg.set_biome("forest_reach", 1)

	assert_float(bg.color.r).is_equal_approx(expected.r, 0.001)
	assert_float(bg.color.g).is_equal_approx(expected.g, 0.001)
	assert_float(bg.color.b).is_equal_approx(expected.b, 0.001)


func test_floor_4_uses_baseline_palette_unchanged() -> void:
	# Last regular floor; should still be baseline.
	var bg: ColorRect = _make_bg()
	var expected: Color = BiomeBackgroundScript.PALETTE["frostmire"]

	bg.set_biome("frostmire", 4)

	assert_float(bg.color.r).is_equal_approx(expected.r, 0.001)
	assert_float(bg.color.g).is_equal_approx(expected.g, 0.001)
	assert_float(bg.color.b).is_equal_approx(expected.b, 0.001)


# ===========================================================================
# Group B — Boss floor renders darkened
# ===========================================================================

func test_boss_floor_darkens_palette_by_factor() -> void:
	var bg: ColorRect = _make_bg()
	var base: Color = BiomeBackgroundScript.PALETTE["forest_reach"]
	var factor: float = BiomeBackgroundScript.BOSS_FLOOR_DARKEN_FACTOR

	bg.set_biome("forest_reach", BiomeBackgroundScript.BOSS_FLOOR_INDEX_MVP)

	assert_float(bg.color.r).is_equal_approx(base.r * factor, 0.001)
	assert_float(bg.color.g).is_equal_approx(base.g * factor, 0.001)
	assert_float(bg.color.b).is_equal_approx(base.b * factor, 0.001)
	# Alpha preserved (Color * float scales all channels; constant restores alpha).
	assert_float(bg.color.a).is_equal_approx(base.a, 0.001)


func test_boss_floor_darkens_any_biome_consistently() -> void:
	# Per-biome consistency, not hardcoded to one palette entry.
	var bg: ColorRect = _make_bg()
	var biome_ids: Array[String] = ["forest_reach", "frostmire", "sunken_ruins"]
	var factor: float = BiomeBackgroundScript.BOSS_FLOOR_DARKEN_FACTOR
	var boss_floor: int = BiomeBackgroundScript.BOSS_FLOOR_INDEX_MVP

	for biome_id: String in biome_ids:
		bg.set_biome(biome_id, boss_floor)
		var base: Color = BiomeBackgroundScript.PALETTE[biome_id]

		assert_float(bg.color.r).is_equal_approx(base.r * factor, 0.001).override_failure_message(
			"Biome '%s' boss-floor red channel mismatch: expected %.3f got %.3f"
			% [biome_id, base.r * factor, bg.color.r]
		)
		assert_float(bg.color.g).is_equal_approx(base.g * factor, 0.001)
		assert_float(bg.color.b).is_equal_approx(base.b * factor, 0.001)


# ===========================================================================
# Group C — Boundary: floor 0 (no floor context) renders baseline
# ===========================================================================

func test_floor_0_treats_as_no_floor_context_baseline_palette() -> void:
	# floor_index 0 is the no-run-active sentinel — render baseline, NOT darkened.
	var bg: ColorRect = _make_bg()
	var expected: Color = BiomeBackgroundScript.PALETTE["forest_reach"]

	bg.set_biome("forest_reach", 0)

	assert_float(bg.color.r).is_equal_approx(expected.r, 0.001)
	assert_float(bg.color.g).is_equal_approx(expected.g, 0.001)
	assert_float(bg.color.b).is_equal_approx(expected.b, 0.001)


# ===========================================================================
# Group D — Fallback to forest_reach on unknown biome
# ===========================================================================

func test_unknown_biome_falls_back_to_forest_reach_with_floor_modulation() -> void:
	var bg: ColorRect = _make_bg()
	var base: Color = BiomeBackgroundScript.PALETTE["forest_reach"]
	var factor: float = BiomeBackgroundScript.BOSS_FLOOR_DARKEN_FACTOR

	# Unknown biome + boss floor → falls back to forest_reach + darkens
	bg.set_biome("nonexistent_biome", BiomeBackgroundScript.BOSS_FLOOR_INDEX_MVP)

	assert_str(bg.get_biome()).is_equal("forest_reach")
	assert_float(bg.color.r).is_equal_approx(base.r * factor, 0.001)


# ===========================================================================
# Group E — Default floor_index parameter preserves pre-S25 behavior
# ===========================================================================

func test_set_biome_without_floor_index_uses_baseline_palette() -> void:
	# Pre-S25 callers passing only biome_id should see no behavior change.
	var bg: ColorRect = _make_bg()
	var expected: Color = BiomeBackgroundScript.PALETTE["sunken_ruins"]

	bg.set_biome("sunken_ruins")

	assert_float(bg.color.r).is_equal_approx(expected.r, 0.001)
	assert_float(bg.color.g).is_equal_approx(expected.g, 0.001)
	assert_float(bg.color.b).is_equal_approx(expected.b, 0.001)


# ===========================================================================
# Group F — Same-state short-circuit (covers biome AND floor axes)
# ===========================================================================

func test_floor_transition_within_same_biome_updates_color() -> void:
	# F4 → F5 same biome must re-render (darken kicks in at F5).
	var bg: ColorRect = _make_bg()
	bg.set_biome("forest_reach", 4)
	var f4_color: Color = bg.color

	bg.set_biome("forest_reach", 5)
	var f5_color: Color = bg.color

	# Boss floor should be visibly darker than F4 baseline.
	assert_bool(f5_color.r < f4_color.r).is_true().override_failure_message(
		"Expected F5 red %.3f < F4 red %.3f after floor transition." % [f5_color.r, f4_color.r]
	)


func test_repeated_call_with_same_biome_and_floor_is_no_op() -> void:
	# Defensive: same biome + same floor → no color mutation, no signal storm.
	var bg: ColorRect = _make_bg()
	bg.set_biome("forest_reach", 5)
	var first_color: Color = bg.color

	# Second call with identical args
	bg.set_biome("forest_reach", 5)

	# Color unchanged (binary identity check would over-specify — float compare is enough)
	assert_float(bg.color.r).is_equal_approx(first_color.r, 0.0001)
