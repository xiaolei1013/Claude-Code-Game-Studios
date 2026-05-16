# Sprint 23 S23-S3 — ClassPortraitFactory tests.
#
# Validates the programmatic-portrait contract that the Recruit Screen and
# Hero Detail modal consume:
#   - Texture has correct dimensions (96×96)
#   - Per-class colors are distinct (no two MVP classes get the same swatch)
#   - Empty/missing class_id degrades to a neutral grey rather than crashing
#   - Cache returns the same Texture2D instance on repeat calls (zero-alloc
#     in UI hot paths)
extends GdUnitTestSuite

const ClassPortraitFactoryScript = preload("res://src/ui/class_portrait_factory.gd")


func before_test() -> void:
	# Wipe the module-level cache so each test starts from a known state.
	ClassPortraitFactoryScript._clear_cache_for_tests()


func after_test() -> void:
	ClassPortraitFactoryScript._clear_cache_for_tests()


# ===========================================================================
# Group A — Texture dimensions
# ===========================================================================

func test_portrait_texture_is_96_by_96() -> void:
	# Arrange + Act
	var tex: Texture2D = ClassPortraitFactoryScript.get_portrait_texture("warrior")

	# Assert
	assert_object(tex).is_not_null()
	assert_int(tex.get_width()).is_equal(96)
	assert_int(tex.get_height()).is_equal(96)


# ===========================================================================
# Group B — Per-class color distinctness
# ===========================================================================

func test_warrior_and_mage_have_distinct_portrait_colors() -> void:
	# Arrange + Act
	var warrior_color: Color = ClassPortraitFactoryScript.get_portrait_color("warrior")
	var mage_color: Color = ClassPortraitFactoryScript.get_portrait_color("mage")

	# Assert — no two MVP classes should map to the same color swatch.
	assert_bool(warrior_color != mage_color).override_failure_message(
		"Warrior color %s and Mage color %s collide — adjust the hash → hue mapping."
		% [str(warrior_color), str(mage_color)]
	).is_true()


func test_warrior_and_rogue_have_distinct_portrait_colors() -> void:
	# Arrange + Act
	var warrior_color: Color = ClassPortraitFactoryScript.get_portrait_color("warrior")
	var rogue_color: Color = ClassPortraitFactoryScript.get_portrait_color("rogue")

	# Assert
	assert_bool(warrior_color != rogue_color).override_failure_message(
		"Warrior color %s and Rogue color %s collide — adjust the hash → hue mapping."
		% [str(warrior_color), str(rogue_color)]
	).is_true()


func test_mage_and_rogue_have_distinct_portrait_colors() -> void:
	# Arrange + Act
	var mage_color: Color = ClassPortraitFactoryScript.get_portrait_color("mage")
	var rogue_color: Color = ClassPortraitFactoryScript.get_portrait_color("rogue")

	# Assert
	assert_bool(mage_color != rogue_color).override_failure_message(
		"Mage color %s and Rogue color %s collide — adjust the hash → hue mapping."
		% [str(mage_color), str(rogue_color)]
	).is_true()


# ===========================================================================
# Group C — Defensive empty-id degrade
# ===========================================================================

func test_empty_class_id_returns_neutral_grey_color() -> void:
	# Arrange + Act
	var color: Color = ClassPortraitFactoryScript.get_portrait_color("")

	# Assert — a neutral grey (r==g==b) is the documented degrade.
	assert_float(color.r).is_equal_approx(color.g, 0.001)
	assert_float(color.g).is_equal_approx(color.b, 0.001)


func test_empty_class_id_still_returns_a_texture() -> void:
	# Arrange + Act — defensive: callers should never get null even on
	# a corrupt/missing class_id.
	var tex: Texture2D = ClassPortraitFactoryScript.get_portrait_texture("")

	# Assert
	assert_object(tex).is_not_null()
	assert_int(tex.get_width()).is_equal(96)


# ===========================================================================
# Group D — Cache returns identical instance on repeat calls
# ===========================================================================

func test_repeat_calls_return_same_texture_instance() -> void:
	# Arrange + Act
	var first: Texture2D = ClassPortraitFactoryScript.get_portrait_texture("warrior")
	var second: Texture2D = ClassPortraitFactoryScript.get_portrait_texture("warrior")

	# Assert — same instance (cache hit), not just equal value.
	assert_object(second).is_same(first)


# ===========================================================================
# Group E — Border pixel-accuracy (Sprint 24 S24-N1 fill_rect refactor)
#
# These tests are the regression net for the strip-fill optimization in
# `_build_portrait`. The optimization replaces a nested set_pixel loop with
# 4 `fill_rect` calls (top, bottom, left, right). If a future refactor
# breaks the strip math, the border pixels would render with the wrong
# color or wrong location — these tests catch that.
#
# Logic-level test (not visual-fidelity): we verify the border pixel sample
# at each canonical location matches the darkened-border color, and the
# inside-the-border sample matches the bg color.
# ===========================================================================

func _make_image_for_class(class_id: String) -> Image:
	# Pull the texture, then extract its backing Image for pixel-level inspection.
	var tex: Texture2D = ClassPortraitFactoryScript.get_portrait_texture(class_id)
	var img: Image = tex.get_image()
	# get_image() returns a fresh copy — safe to read without mutating cache.
	return img


func _expected_border_color(class_id: String) -> Color:
	# Mirrors the `border = bg * 0.5` derivation in `_build_portrait`. Kept
	# inline rather than exposing a helper because the formula is part of
	# the visual contract, not a reusable derivation.
	var bg: Color = ClassPortraitFactoryScript.get_portrait_color(class_id)
	return Color(bg.r * 0.5, bg.g * 0.5, bg.b * 0.5, 1.0)


func test_border_top_left_corner_pixel_is_border_color() -> void:
	# Arrange
	var img: Image = _make_image_for_class("warrior")
	var expected: Color = _expected_border_color("warrior")

	# Act — pixel (0, 0) is in the top-left corner of the top strip.
	var actual: Color = img.get_pixel(0, 0)

	# Assert
	assert_float(actual.r).is_equal_approx(expected.r, 0.005)
	assert_float(actual.g).is_equal_approx(expected.g, 0.005)
	assert_float(actual.b).is_equal_approx(expected.b, 0.005)


func test_border_bottom_right_corner_pixel_is_border_color() -> void:
	# Arrange
	var img: Image = _make_image_for_class("warrior")
	var expected: Color = _expected_border_color("warrior")

	# Act — pixel (95, 95) is the bottom-right corner; covered by the bottom strip.
	var actual: Color = img.get_pixel(95, 95)

	# Assert
	assert_float(actual.r).is_equal_approx(expected.r, 0.005)
	assert_float(actual.g).is_equal_approx(expected.g, 0.005)
	assert_float(actual.b).is_equal_approx(expected.b, 0.005)


func test_border_left_edge_inner_pixel_is_border_color() -> void:
	# Arrange — Y=48 is mid-height; X=0 is the leftmost column of the left strip.
	var img: Image = _make_image_for_class("warrior")
	var expected: Color = _expected_border_color("warrior")

	# Act
	var actual: Color = img.get_pixel(0, 48)

	# Assert — should be border-color, not bg-color (verifies left strip wrote here).
	assert_float(actual.r).is_equal_approx(expected.r, 0.005)
	assert_float(actual.g).is_equal_approx(expected.g, 0.005)
	assert_float(actual.b).is_equal_approx(expected.b, 0.005)


func test_pixel_just_inside_border_is_background_color_not_border() -> void:
	# Arrange — (4, 4) is the first pixel JUST inside the 4px frame. Should
	# be bg color, NOT border color. Catches off-by-one strip-width bugs.
	var img: Image = _make_image_for_class("warrior")
	var bg: Color = ClassPortraitFactoryScript.get_portrait_color("warrior")
	var border: Color = _expected_border_color("warrior")

	# Act
	var actual: Color = img.get_pixel(4, 4)

	# Assert — matches bg, NOT border.
	assert_float(actual.r).is_equal_approx(bg.r, 0.005).override_failure_message(
		"Pixel at (4,4) should be bg %s but got %s — likely an off-by-one in the border strip width."
		% [str(bg), str(actual)]
	)
	# Sanity: must NOT match the border color either.
	var matches_border: bool = (
		absf(actual.r - border.r) < 0.005
		and absf(actual.g - border.g) < 0.005
		and absf(actual.b - border.b) < 0.005
	)
	assert_bool(matches_border).is_false()
