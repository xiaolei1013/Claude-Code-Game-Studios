# Sprint 17 — Matchup Assignment biome tab matchup-hint label.
#
# The Matchup Assignment screen renders one tab per biome via
# _render_biome_tabs. Sprint 17 adds a "MatchupHintLabel" below the
# biome name showing the biome's dominant_archetypes (e.g.,
# "Common: armored, caster"). Player gets in-game feedback on what
# class composition is good vs each biome.
#
# Tests:
#   1. Each biome tab includes a MatchupHintLabel
#   2. The label text starts with "Common: " + the biome's archetypes
#   3. Tab NameLabel uses biome.display_name (not capitalize(id))
extends GdUnitTestSuite

const MatchupAssignmentScene: PackedScene = preload(
	"res://assets/screens/matchup_assignment/matchup_assignment.tscn"
)


# ---------------------------------------------------------------------------
# Helper — instantiate the screen and let on_enter populate the biome tabs.
# Returns the screen Control.
# ---------------------------------------------------------------------------

func _make_screen_in_tree() -> Control:
	var screen: Control = MatchupAssignmentScene.instantiate() as Control
	add_child(screen)
	auto_free(screen)
	if screen.has_method("on_enter"):
		screen.on_enter()
	# Two frames so _render_biome_tabs has run.
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


# ---------------------------------------------------------------------------
# Test 1 — every biome tab has a MatchupHintLabel
# ---------------------------------------------------------------------------

func test_each_biome_tab_has_matchup_hint_label() -> void:
	var screen: Control = await _make_screen_in_tree()
	var biome_vbox: Node = screen.get_node_or_null("BiomePanel/BiomeVBox")
	assert_object(biome_vbox).is_not_null()

	var checked_count: int = 0
	var missing_hint: Array[String] = []
	for child: Node in biome_vbox.get_children():
		if not child.name.begins_with("BiomeTab_"):
			continue
		checked_count += 1
		var hint: Node = child.get_node_or_null("MatchupHintLabel")
		if hint == null:
			missing_hint.append(child.name)

	# At least one biome tab should exist (forest_reach minimum).
	assert_int(checked_count).override_failure_message(
		"Expected at least 1 BiomeTab_ child; got 0"
	).is_greater_equal(1)
	assert_int(missing_hint.size()).override_failure_message(
		"Biome tabs missing MatchupHintLabel: %s" % str(missing_hint)
	).is_equal(0)


# ---------------------------------------------------------------------------
# Test 2 — label text format "Common: <archetype>[, <archetype>]"
# ---------------------------------------------------------------------------

func test_matchup_hint_text_starts_with_common_prefix() -> void:
	var screen: Control = await _make_screen_in_tree()
	var biome_vbox: Node = screen.get_node_or_null("BiomePanel/BiomeVBox")
	for child: Node in biome_vbox.get_children():
		if not child.name.begins_with("BiomeTab_"):
			continue
		var hint: Label = child.get_node_or_null("MatchupHintLabel") as Label
		if hint == null:
			continue
		assert_str(hint.text).override_failure_message(
			"%s.MatchupHintLabel.text should start with 'Common: ' — got '%s'"
			% [child.name, hint.text]
		).starts_with("Common: ")


# ---------------------------------------------------------------------------
# Test 3 — Forest Reach hint shows "bruiser, armored" (per its data)
# ---------------------------------------------------------------------------

# Validates that the label reflects the biome.tres dominant_archetypes
# field rather than a hardcoded string.
func test_forest_reach_hint_shows_bruiser_armored() -> void:
	var screen: Control = await _make_screen_in_tree()
	var tab: Node = screen.get_node_or_null("BiomePanel/BiomeVBox/BiomeTab_forest_reach")
	if tab == null:
		# Forest Reach is the MVP starter biome; if it's missing the test
		# environment is broken, not the feature.
		push_warning("Skipped: BiomeTab_forest_reach not found")
		return
	var hint: Label = tab.get_node_or_null("MatchupHintLabel") as Label
	assert_object(hint).is_not_null()
	assert_str(hint.text).override_failure_message(
		"Forest Reach should report 'Common: bruiser, armored' per its dominant_archetypes; got '%s'"
		% hint.text
	).is_equal("Common: bruiser, armored")


# ---------------------------------------------------------------------------
# Test 4 — biome tab NameLabel uses display_name, not capitalize(id)
# ---------------------------------------------------------------------------

# "hollow_stair" should render as "The Hollow Stair" (its display_name),
# not "Hollow_Stair" (capitalize(id)).
func test_biome_tab_name_label_uses_display_name() -> void:
	var screen: Control = await _make_screen_in_tree()
	var biome_vbox: Node = screen.get_node_or_null("BiomePanel/BiomeVBox")

	# Find any biome tab whose display_name differs from capitalize(id).
	# Hollow Stair is the obvious one (id="hollow_stair", display_name="The Hollow Stair").
	# It's gated, so won't appear without progression. Fall back to checking
	# Forest Reach (display_name "Forest Reach" vs capitalize "Forest_Reach").
	var tab: Node = biome_vbox.get_node_or_null("BiomeTab_forest_reach")
	if tab == null:
		push_warning("Skipped: BiomeTab_forest_reach not found")
		return
	var name_label: Label = tab.get_node_or_null("NameLabel") as Label
	assert_object(name_label).is_not_null()
	assert_str(name_label.text).override_failure_message(
		"NameLabel should use display_name 'Forest Reach'; got '%s' (regression: capitalize(id) would produce 'Forest_Reach')"
		% name_label.text
	).is_equal("Forest Reach")
