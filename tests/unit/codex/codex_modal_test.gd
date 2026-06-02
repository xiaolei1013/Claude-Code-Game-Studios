# Codex modal — code-only catalogue (Heroes / Monsters / Dungeons).
# Verifies the modal builds its tab structure + cards from DataRegistry, and
# exposes a Close button. The Codex is opened from the Guild Hall Codex tab via
# SceneManager.show_modal (caller-owned modal; no scene-manager registry entry).
extends GdUnitTestSuite

const CodexModalScript = preload("res://assets/screens/codex/codex_modal.gd")


func _make() -> Control:
	# CodexModalScript.new() is a plain Control; _ready() (→ _build) fires
	# synchronously on add_child since the test suite is inside the tree.
	var modal: Control = CodexModalScript.new()
	add_child(modal)
	auto_free(modal)
	return modal


func test_codex_builds_three_catalogue_tabs() -> void:
	var modal: Control = _make()
	var tabs: TabContainer = modal.find_child("CodexTabs", true, false) as TabContainer
	assert_object(tabs).is_not_null()
	assert_int(tabs.get_tab_count()).is_equal(3)


func test_codex_tab_titles_are_heroes_monsters_dungeons() -> void:
	var modal: Control = _make()
	var tabs: TabContainer = modal.find_child("CodexTabs", true, false) as TabContainer
	assert_object(tabs).is_not_null()
	var titles: Array[String] = []
	for i: int in range(tabs.get_tab_count()):
		titles.append(tabs.get_tab_title(i))
	assert_array(titles).contains(["Heroes", "Monsters", "Dungeons"])


func test_codex_has_close_button() -> void:
	var modal: Control = _make()
	var close: Button = modal.find_child("CloseButton", true, false) as Button
	assert_object(close).is_not_null()


func test_codex_heroes_tab_renders_cards_from_data() -> void:
	# Heroes tab = first TabContainer child (ScrollContainer "Heroes") →
	# GridContainer → one card per class in DataRegistry.
	var modal: Control = _make()
	var tabs: TabContainer = modal.find_child("CodexTabs", true, false) as TabContainer
	assert_object(tabs).is_not_null()
	var heroes_scroll: Node = tabs.get_child(0)
	var grid: Node = heroes_scroll.get_child(0)
	assert_int(grid.get_child_count()).is_greater(0)
