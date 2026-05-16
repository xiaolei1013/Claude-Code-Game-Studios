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
