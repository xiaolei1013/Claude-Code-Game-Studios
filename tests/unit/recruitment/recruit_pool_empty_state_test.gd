# Sprint 24 S24-S1 — Recruit Screen empty-state placeholder tests.
#
# When the recruit pool is fully empty (all 3 slots hidden because
# Recruitment.get_recruit_pool() returns []), the screen renders a
# placeholder Label so the panel doesn't look broken.
#
# Advisory polish per the Sprint 24 plan — playtest-14 graded the
# Recruit Screen as PASS without this gap, so the empty-state is a
# cozy-register defensive degrade for the mid-pool-empty state
# (e.g., just recruited the last entry before the next refresh).
extends GdUnitTestSuite

const RecruitmentScene = preload("res://assets/screens/recruitment/recruitment.tscn")


var _snapshot_recruitment: Dictionary = {}


func before_test() -> void:
	# Snapshot recruitment state (pool seed) so each test starts clean and
	# leaves the autoload in its original shape after.
	var rec_autoload: Node = get_tree().root.get_node_or_null("Recruitment")
	_snapshot_recruitment = rec_autoload.get_save_data() if rec_autoload != null else {}


func after_test() -> void:
	var rec_autoload: Node = get_tree().root.get_node_or_null("Recruitment")
	if rec_autoload != null and not _snapshot_recruitment.is_empty():
		rec_autoload.load_save_data(_snapshot_recruitment)


# ===========================================================================
# Group A — Empty-state placeholder rendering
# ===========================================================================

func test_recruit_screen_renders_no_placeholder_when_pool_has_entries() -> void:
	# Arrange — default recruitment seed produces ≥1 pool entry.
	var screen: Node = RecruitmentScene.instantiate()
	add_child(screen)
	auto_free(screen)

	# Act
	screen.on_enter()

	# Assert — no placeholder Label in the PoolVBox while pool is populated.
	# PoolVBox became an HBoxContainer in the 3-card-draft restyle; cast to the
	# generic Container base (the placeholder-child assertions are unchanged).
	var vbox: Control = screen.get_node_or_null("PoolPanel/PoolVBox") as Control
	assert_object(vbox).is_not_null()
	var placeholder: Label = vbox.get_node_or_null("EmptyPoolPlaceholder") as Label
	# Either: placeholder doesn't exist at all (lazy-create path), OR it
	# exists but is hidden (visible=false). Both pass the contract.
	var placeholder_visible: bool = placeholder != null and placeholder.visible
	assert_bool(placeholder_visible).is_false()


func test_recruit_screen_renders_placeholder_when_pool_is_empty() -> void:
	# Arrange — force empty pool by clearing the autoload's internal pool.
	# (Defensive scenario: just-recruited-last-entry, mid-refresh window.)
	var rec_autoload: Node = get_tree().root.get_node_or_null("Recruitment")
	assert_object(rec_autoload).is_not_null()
	# Pool state lives in the `_current_pool` (Array[String]) field per
	# recruitment.gd — get_recruit_pool() returns _current_pool.duplicate().
	# (Prior code targeted a non-existent `_pool` field, so the pool never
	# actually emptied and this test silently never exercised the empty path.)
	# Use a typed empty local — the typed field rejects untyped/Packed literals.
	var empty_pool: Array[String] = []
	rec_autoload.set("_current_pool", empty_pool)

	var screen: Node = RecruitmentScene.instantiate()
	add_child(screen)
	auto_free(screen)

	# Act
	screen.on_enter()

	# Assert — placeholder Label is present + visible + contains expected copy.
	# PoolVBox became an HBoxContainer in the 3-card-draft restyle; cast to the
	# generic Container base (the placeholder-child assertions are unchanged).
	var vbox: Control = screen.get_node_or_null("PoolPanel/PoolVBox") as Control
	assert_object(vbox).is_not_null()
	var placeholder: Label = vbox.get_node_or_null("EmptyPoolPlaceholder") as Label
	assert_object(placeholder).is_not_null().override_failure_message(
		"Expected EmptyPoolPlaceholder Label to be lazily created when pool is empty."
	)
	assert_bool(placeholder.visible).is_true()
	# Locale key resolves to either the writer-locked English text or the key
	# verbatim if en.csv isn't loaded — both forms contain "pool" / "refresh"
	# so we assert non-empty rather than exact match (per existing pattern in
	# retired_tab_render_test.gd::test_roster_tabs_titles_localized_on_enter).
	assert_int(placeholder.text.length()).is_greater(0)
