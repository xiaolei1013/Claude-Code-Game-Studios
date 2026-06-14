# GDD #34 Phase 3 (Defeat & Injury / ADR-0021 — AC-34-09): UIFramework injury
# mark helpers. Pure-Control isolation tests for format_recovery_countdown,
# mark_injured, and clear_injured — no live screen, no autoload dependency.
#
# Companion to ui_framework_helpers_test.gd; same UIFrameworkScript preload +
# auto_free(Control) pattern so the injury surface is locked the same way the
# parchment/touch-feedback surface is.
extends GdUnitTestSuite

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")


# ===========================================================================
# Group A — format_recovery_countdown (pure function)
# ===========================================================================

func test_format_recovery_countdown_zero_returns_empty() -> void:
	# 0 seconds remaining → "" (caller renders the bare "Injured" label).
	assert_str(UIFrameworkScript.format_recovery_countdown(0)).is_equal("")


func test_format_recovery_countdown_negative_returns_empty() -> void:
	# Negative (clock already past recovery) → "" defensively.
	assert_str(UIFrameworkScript.format_recovery_countdown(-42)).is_equal("")


func test_format_recovery_countdown_seconds_only_renders_s_suffix() -> void:
	# Under a minute → "<n>s".
	assert_str(UIFrameworkScript.format_recovery_countdown(45)).is_equal("45s")


func test_format_recovery_countdown_minutes_drops_seconds() -> void:
	# 90s = 1m 30s → coarsens to "1m" (minutes bucket drops the seconds).
	assert_str(UIFrameworkScript.format_recovery_countdown(90)).is_equal("1m")


func test_format_recovery_countdown_default_recovery_reads_30m() -> void:
	# The default injury_recovery_seconds (1800) must read "30m", not "1800s".
	assert_str(UIFrameworkScript.format_recovery_countdown(1800)).is_equal("30m")


func test_format_recovery_countdown_hours_renders_h_and_m() -> void:
	# 3725s = 1h 2m 5s → "1h 2m" (hours bucket drops the seconds).
	assert_str(UIFrameworkScript.format_recovery_countdown(3725)).is_equal("1h 2m")


# ===========================================================================
# Group B — mark_injured
# ===========================================================================

func test_mark_injured_dims_card_to_injured_alpha() -> void:
	# Arrange
	var card: Button = auto_free(Button.new())
	add_child(card)

	# Act
	UIFrameworkScript.mark_injured(card, 1800)

	# Assert — modulate alpha dropped to the injured constant.
	assert_float(card.modulate.a).is_equal_approx(UIFrameworkScript.INJURED_DIM_ALPHA, 0.001)


func test_mark_injured_attaches_named_badge_child() -> void:
	# Arrange
	var card: Button = auto_free(Button.new())
	add_child(card)

	# Act
	UIFrameworkScript.mark_injured(card, 1800)

	# Assert — additive badge child exists under the canonical name.
	var badge: Node = card.get_node_or_null(NodePath(UIFrameworkScript.INJURED_BADGE_NAME))
	assert_object(badge).is_not_null()
	assert_bool(badge is Label).is_true()


func test_mark_injured_badge_is_mouse_filter_ignore() -> void:
	# AC-34-04/09: the badge must not steal taps — injured heroes stay tappable
	# (project memory: z_index does NOT affect input picking; only IGNORE does).
	# Arrange
	var card: Button = auto_free(Button.new())
	add_child(card)

	# Act
	UIFrameworkScript.mark_injured(card, 1800)

	# Assert
	var badge: Label = card.get_node_or_null(NodePath(UIFrameworkScript.INJURED_BADGE_NAME)) as Label
	assert_int(badge.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_mark_injured_badge_text_includes_countdown() -> void:
	# Arrange
	var card: Button = auto_free(Button.new())
	add_child(card)

	# Act
	UIFrameworkScript.mark_injured(card, 1800)

	# Assert — badge text carries the "30m" countdown (substituted or suffixed
	# depending on locale-load state; both contain "30m").
	var badge: Label = card.get_node_or_null(NodePath(UIFrameworkScript.INJURED_BADGE_NAME)) as Label
	assert_str(badge.text).contains("30m")


func test_mark_injured_zero_remaining_renders_bare_label_text() -> void:
	# remaining <= 0 → no countdown; badge falls back to the bare "injured" label
	# key. Text is non-empty (the localized "Injured" or the raw key).
	# Arrange
	var card: Button = auto_free(Button.new())
	add_child(card)

	# Act
	UIFrameworkScript.mark_injured(card, 0)

	# Assert
	var badge: Label = card.get_node_or_null(NodePath(UIFrameworkScript.INJURED_BADGE_NAME)) as Label
	assert_int(badge.text.length()).is_greater(0)


func test_mark_injured_idempotent_does_not_stack_badges() -> void:
	# Calling every panel refresh must update in place, not add a second badge.
	# Arrange
	var card: Button = auto_free(Button.new())
	add_child(card)

	# Act — mark three times.
	UIFrameworkScript.mark_injured(card, 1800)
	UIFrameworkScript.mark_injured(card, 600)
	UIFrameworkScript.mark_injured(card, 60)

	# Assert — exactly one badge child named INJURED_BADGE_NAME.
	var matches: int = 0
	for child: Node in card.get_children():
		if child.name == UIFrameworkScript.INJURED_BADGE_NAME:
			matches += 1
	assert_int(matches).is_equal(1)


func test_mark_injured_updates_badge_text_on_remark() -> void:
	# Idempotent re-mark must refresh the countdown text, not leave the stale one.
	# Arrange
	var card: Button = auto_free(Button.new())
	add_child(card)

	# Act — mark with 30m then re-mark with 45s.
	UIFrameworkScript.mark_injured(card, 1800)
	UIFrameworkScript.mark_injured(card, 45)

	# Assert — text now reflects the second call.
	var badge: Label = card.get_node_or_null(NodePath(UIFrameworkScript.INJURED_BADGE_NAME)) as Label
	assert_str(badge.text).contains("45s")
	assert_str(badge.text).not_contains("30m")


func test_mark_injured_null_card_does_not_crash() -> void:
	# Defensive: null card push_errors but must not throw.
	UIFrameworkScript.mark_injured(null, 1800)
	assert_bool(true).is_true()


# ===========================================================================
# Group C — clear_injured
# ===========================================================================

func test_clear_injured_restores_full_opacity() -> void:
	# Arrange — mark then clear.
	var card: Button = auto_free(Button.new())
	add_child(card)
	UIFrameworkScript.mark_injured(card, 1800)

	# Act
	UIFrameworkScript.clear_injured(card)

	# Assert
	assert_float(card.modulate.a).is_equal_approx(1.0, 0.001)


func test_clear_injured_removes_badge_child() -> void:
	# Arrange
	var card: Button = auto_free(Button.new())
	add_child(card)
	UIFrameworkScript.mark_injured(card, 1800)

	# Act
	UIFrameworkScript.clear_injured(card)

	# Assert — badge gone.
	var badge: Node = card.get_node_or_null(NodePath(UIFrameworkScript.INJURED_BADGE_NAME))
	assert_object(badge).is_null()


func test_clear_injured_on_unmarked_card_is_noop() -> void:
	# Never-marked card: clear must be a safe no-op (no badge to remove, alpha
	# already 1.0).
	# Arrange
	var card: Button = auto_free(Button.new())
	add_child(card)

	# Act
	UIFrameworkScript.clear_injured(card)

	# Assert
	assert_float(card.modulate.a).is_equal_approx(1.0, 0.001)
	assert_int(card.get_child_count()).is_equal(0)


func test_clear_injured_null_card_does_not_crash() -> void:
	UIFrameworkScript.clear_injured(null)
	assert_bool(true).is_true()
