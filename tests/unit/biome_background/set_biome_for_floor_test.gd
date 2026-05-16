# Sprint 25 S25-M3-rev — BiomeBackground per-floor modulation tests.
#
# Covers the boss-floor darkening contract: floor 5 of any biome renders
# with a darkened palette (BOSS_FLOOR_DARKEN_FACTOR = 0.65) so the player
# visually reads the boss fight as distinct from regular floors.
extends GdUnitTestSuite

const BiomeBackgroundScene = preload("res://assets/screens/_shared/biome_background.tscn")
const BiomeBackgroundScript = preload("res://assets/screens/_shared/biome_background.gd")


func _make_bg() -> ColorRect:
	var bg: ColorRect = BiomeBackgroundScene.instantiate()
	add_child(bg)
	auto_free(bg)
	return bg


# ===========================================================================
# Group A — Regular floors (F1–F4) render at baseline brightness
# ===========================================================================

func test_floor_1_uses_baseline_palette_unchanged() -> void:
	# Arrange
	var bg: ColorRect = _make_bg()
	var expected: Color = BiomeBackgroundScript.PALETTE["forest_reach"]

	# Act
	bg.set_biome_for_floor("forest_reach", 1)

	# Assert — color matches the unmodulated palette entry
	assert_float(bg.color.r).is_equal_approx(expected.r, 0.001)
	assert_float(bg.color.g).is_equal_approx(expected.g, 0.001)
	assert_float(bg.color.b).is_equal_approx(expected.b, 0.001)


func test_floor_4_uses_baseline_palette_unchanged() -> void:
	# Arrange — F4 is the last regular floor; should still be baseline.
	var bg: ColorRect = _make_bg()
	var expected: Color = BiomeBackgroundScript.PALETTE["frostmire"]

	# Act
	bg.set_biome_for_floor("frostmire", 4)

	# Assert
	assert_float(bg.color.r).is_equal_approx(expected.r, 0.001)
	assert_float(bg.color.g).is_equal_approx(expected.g, 0.001)
	assert_float(bg.color.b).is_equal_approx(expected.b, 0.001)


# ===========================================================================
# Group B — Boss floor (F5) renders darkened
# ===========================================================================

func test_floor_5_darkens_palette_by_factor() -> void:
	# Arrange
	var bg: ColorRect = _make_bg()
	var base: Color = BiomeBackgroundScript.PALETTE["forest_reach"]
	var factor: float = BiomeBackgroundScript.BOSS_FLOOR_DARKEN_FACTOR

	# Act
	bg.set_biome_for_floor("forest_reach", 5)

	# Assert — each channel multiplied by BOSS_FLOOR_DARKEN_FACTOR
	assert_float(bg.color.r).is_equal_approx(base.r * factor, 0.001)
	assert_float(bg.color.g).is_equal_approx(base.g * factor, 0.001)
	assert_float(bg.color.b).is_equal_approx(base.b * factor, 0.001)


func test_floor_5_darkens_any_biome_consistently() -> void:
	# Arrange — verify modulation is per-biome consistent, not hardcoded to
	# one palette entry.
	var bg: ColorRect = _make_bg()
	var biome_ids: Array[String] = ["forest_reach", "frostmire", "sunken_ruins"]
	var factor: float = BiomeBackgroundScript.BOSS_FLOOR_DARKEN_FACTOR

	for biome_id: String in biome_ids:
		# Act
		bg.set_biome_for_floor(biome_id, 5)
		var base: Color = BiomeBackgroundScript.PALETTE[biome_id]

		# Assert
		assert_float(bg.color.r).is_equal_approx(base.r * factor, 0.001).override_failure_message(
			"Biome '%s' F5 red channel mismatch: expected %.3f got %.3f"
			% [biome_id, base.r * factor, bg.color.r]
		)
		assert_float(bg.color.g).is_equal_approx(base.g * factor, 0.001)
		assert_float(bg.color.b).is_equal_approx(base.b * factor, 0.001)


# ===========================================================================
# Group C — Boundary: floor 0 (no floor context) renders baseline
# ===========================================================================

func test_floor_0_treats_as_no_floor_context_baseline_palette() -> void:
	# Arrange — floor_index 0 is the "no run active" sentinel (Guild Hall,
	# Return-to-App). Should render baseline, NOT darkened.
	var bg: ColorRect = _make_bg()
	var expected: Color = BiomeBackgroundScript.PALETTE["forest_reach"]

	# Act
	bg.set_biome_for_floor("forest_reach", 0)

	# Assert
	assert_float(bg.color.r).is_equal_approx(expected.r, 0.001)
	assert_float(bg.color.g).is_equal_approx(expected.g, 0.001)
	assert_float(bg.color.b).is_equal_approx(expected.b, 0.001)


# ===========================================================================
# Group D — Fallback to forest_reach on unknown biome (preserves set_biome contract)
# ===========================================================================

func test_unknown_biome_falls_back_to_forest_reach_with_floor_modulation() -> void:
	# Arrange
	var bg: ColorRect = _make_bg()
	var base: Color = BiomeBackgroundScript.PALETTE["forest_reach"]
	var factor: float = BiomeBackgroundScript.BOSS_FLOOR_DARKEN_FACTOR

	# Act — unknown biome + F5 → falls back to forest_reach + darkens
	bg.set_biome_for_floor("nonexistent_biome", 5)

	# Assert
	assert_str(bg.get_biome()).is_equal("forest_reach")
	assert_float(bg.color.r).is_equal_approx(base.r * factor, 0.001)


# ===========================================================================
# Group E — Backward compat: set_biome still works (no per-floor modulation)
# ===========================================================================

func test_legacy_set_biome_still_renders_baseline_palette() -> void:
	# Arrange
	var bg: ColorRect = _make_bg()
	var expected: Color = BiomeBackgroundScript.PALETTE["sunken_ruins"]

	# Act — pre-Sprint-25 API path
	bg.set_biome("sunken_ruins")

	# Assert — set_biome unchanged; no floor modulation in this path
	assert_float(bg.color.r).is_equal_approx(expected.r, 0.001)
	assert_float(bg.color.g).is_equal_approx(expected.g, 0.001)
	assert_float(bg.color.b).is_equal_approx(expected.b, 0.001)
