# Sprint 17 S17-S5 — tests for UIFramework.format_short_number.
#
# Closes the cross-GDD gap surfaced during Sprint 16 scaffold authoring
# (Recruit Screen #21 + Hero Detail #22 + Victory Moment #25 reference
# UIFramework.format_short_number; the helper didn't exist until this
# commit — pre-emptively shipped to unblock Sprint 17 visual-polish
# iteration M1+M2+S1+S2).
extends GdUnitTestSuite

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")


# ===========================================================================
# Group A — sub-K threshold renders as raw integer
# ===========================================================================

func test_format_short_number_zero() -> void:
	assert_str(UIFrameworkScript.format_short_number(0)).is_equal("0")


func test_format_short_number_small_int() -> void:
	assert_str(UIFrameworkScript.format_short_number(7)).is_equal("7")


func test_format_short_number_at_999() -> void:
	# 999 < DISPLAY_K_THRESHOLD (1000) → raw number, no suffix.
	assert_str(UIFrameworkScript.format_short_number(999)).is_equal("999")


# ===========================================================================
# Group B — K threshold (1K-999K)
# ===========================================================================

func test_format_short_number_at_1000_displays_1k() -> void:
	# 1000 == K threshold → "1.0K".
	assert_str(UIFrameworkScript.format_short_number(1_000)).is_equal("1.0K")


func test_format_short_number_1234_displays_1_2k() -> void:
	# 1234 → "1.2K" (one decimal place).
	assert_str(UIFrameworkScript.format_short_number(1_234)).is_equal("1.2K")


func test_format_short_number_999500_displays_999_5k() -> void:
	# Just below M threshold.
	assert_str(UIFrameworkScript.format_short_number(999_500)).is_equal("999.5K")


# ===========================================================================
# Group C — M threshold (1M-999M)
# ===========================================================================

func test_format_short_number_at_1_million_displays_1m() -> void:
	assert_str(UIFrameworkScript.format_short_number(1_000_000)).is_equal("1.0M")


func test_format_short_number_4_5_million_displays_4_5m() -> void:
	assert_str(UIFrameworkScript.format_short_number(4_500_000)).is_equal("4.5M")


# ===========================================================================
# Group D — B threshold (1B-999B)
# ===========================================================================

func test_format_short_number_at_1_billion_displays_1b() -> void:
	assert_str(UIFrameworkScript.format_short_number(1_000_000_000)).is_equal("1.0B")


func test_format_short_number_7_2_billion_displays_7_2b() -> void:
	assert_str(UIFrameworkScript.format_short_number(7_200_000_000)).is_equal("7.2B")


# ===========================================================================
# Group E — T threshold (1T+)
# ===========================================================================

func test_format_short_number_at_1_trillion_displays_1t() -> void:
	assert_str(UIFrameworkScript.format_short_number(1_000_000_000_000)).is_equal("1.0T")


# ===========================================================================
# Group F — negative defensive (gold is always positive in MVP, but the
# helper handles negatives with a minus prefix for completeness)
# ===========================================================================

func test_format_short_number_negative_value_prefixed_with_minus() -> void:
	assert_str(UIFrameworkScript.format_short_number(-1500)).is_equal("-1.5K")


func test_format_short_number_negative_below_k_threshold() -> void:
	assert_str(UIFrameworkScript.format_short_number(-42)).is_equal("-42")
