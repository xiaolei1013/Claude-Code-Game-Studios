# Title screen — code-only start screen (Lantern Guild mock).
# Reached from the Pause menu's "Return to Title" via SceneManager.show_modal.
# Boot still routes to Guild Hall (onboarding GDD #29 / AC-29-01 preserved).
extends GdUnitTestSuite

const TitleScreenScript = preload("res://assets/screens/title/title_screen.gd")


func _make() -> Control:
	var title: Control = TitleScreenScript.new()
	add_child(title)
	auto_free(title)
	return title


func test_title_renders_lantern_guild_wordmark() -> void:
	var title: Control = _make()
	var wordmark: Label = title.find_child("Wordmark", true, false) as Label
	assert_object(wordmark).is_not_null()
	assert_str(wordmark.text).is_equal("Lantern Guild")


func test_title_has_at_least_three_menu_buttons() -> void:
	var title: Control = _make()
	var buttons: Array[Node] = title.find_children("*", "Button", true, false)
	assert_int(buttons.size()).is_greater_equal(3)


func test_title_offers_continue_settings_and_quit() -> void:
	var title: Control = _make()
	var labels: Array[String] = []
	for b: Node in title.find_children("*", "Button", true, false):
		labels.append((b as Button).text)
	assert_array(labels).contains(["Continue the Watch", "Settings", "Quit to Desktop"])
