# S15-S2 — Guild Hall level-up toast regression test.
#
# When HeroRoster fires hero_leveled while Guild Hall is the current screen,
# the screen's _on_hero_leveled handler should:
#   1. Refresh the roster panel (so the XP bar repaints).
#   2. Show a localized toast on the bottom ToastLabel with format
#      "[display_name] reached level [N]!".
#
# Under reduce_motion, the toast snap-shows + snap-hides (no fade tween).
#
# Test groups:
#   A — Toast renders correct text on hero_leveled
#   B — Empty display_name path no-ops the toast (no crash)
#   C — reduce_motion suppresses the fade tween
#
# Closes S14-N2 carryover.
extends GdUnitTestSuite

const GuildHallScene: PackedScene = preload(
	"res://assets/screens/guild_hall/guild_hall.tscn"
)


# ---------------------------------------------------------------------------
# Hygiene barrier — snapshot live HeroRoster + reduce_motion state.
# ---------------------------------------------------------------------------

var _snapshot_roster: Dictionary = {}
var _snapshot_reduce_motion: bool = false


func before_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_snapshot_roster = roster.get_save_data() if roster != null else {}
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")
	_snapshot_reduce_motion = bool(sm.get("reduce_motion")) if sm != null else false


func after_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and not _snapshot_roster.is_empty():
		roster.load_save_data(_snapshot_roster)
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")
	if sm != null:
		sm.set("reduce_motion", _snapshot_reduce_motion)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_screen() -> Node:
	var screen: Node = GuildHallScene.instantiate()
	add_child(screen)
	auto_free(screen)
	if screen.has_method("on_enter"):
		screen.on_enter()
	return screen


func _seed_hero(class_id: String, level: int) -> int:
	var roster: Node = HeroRoster
	var instance: RefCounted = roster.call("add_hero", class_id)
	if instance == null:
		return 0
	var id: int = int(instance.get("instance_id"))
	if level > 1:
		instance.set("current_level", level)
	return id


# ===========================================================================
# Group A — toast renders correct text on hero_leveled
# ===========================================================================

# A-01: hero_leveled with a known hero → ToastLabel visible with formatted text.
func test_hero_leveled_shows_toast_with_formatted_text() -> void:
	# Arrange — seed a hero + spawn screen.
	var hero_id: int = _seed_hero("warrior", 1)
	assert_int(hero_id).is_greater(0)
	var screen: Node = _make_screen()
	await get_tree().process_frame
	var toast: Label = screen.get_node("ToastLabel") as Label

	# Read display_name for the expected text.
	var hero: HeroInstance = HeroRoster.get_hero_by_id(hero_id)
	assert_object(hero).is_not_null()
	var expected_text: String = tr("hero_level_up_toast_format") % [hero.display_name, 2]

	# Act — invoke the handler directly (signal is just an event bus).
	screen.call("_on_hero_leveled", hero_id, 1, 2)
	await get_tree().process_frame

	# Assert — ToastLabel is visible with the right text.
	assert_bool(toast.visible).override_failure_message(
		"hero_leveled should make ToastLabel visible"
	).is_true()
	assert_str(toast.text).is_equal(expected_text)


# A-02: a second hero_leveled cancels the prior toast tween and replaces text.
func test_second_hero_leveled_replaces_first_toast() -> void:
	var first_id: int = _seed_hero("warrior", 1)
	var second_id: int = _seed_hero("mage", 1)
	assert_int(first_id).is_greater(0)
	assert_int(second_id).is_greater(0)
	var screen: Node = _make_screen()
	await get_tree().process_frame
	var toast: Label = screen.get_node("ToastLabel") as Label

	screen.call("_on_hero_leveled", first_id, 1, 2)
	await get_tree().process_frame
	# Second toast.
	screen.call("_on_hero_leveled", second_id, 1, 2)
	await get_tree().process_frame

	var second_hero: HeroInstance = HeroRoster.get_hero_by_id(second_id)
	var expected: String = tr("hero_level_up_toast_format") % [second_hero.display_name, 2]
	assert_str(toast.text).override_failure_message(
		"Second toast should replace the first; got %s" % toast.text
	).is_equal(expected)
	assert_bool(toast.visible).is_true()


# ===========================================================================
# Group B — defensive: unknown hero id / empty display_name no-op the toast
# ===========================================================================

# B-01: hero_leveled fired for an unknown id (hero was removed mid-signal)
# does not crash and does not surface a toast with garbage text.
func test_hero_leveled_with_unknown_id_does_not_crash_or_toast() -> void:
	var screen: Node = _make_screen()
	await get_tree().process_frame
	var toast: Label = screen.get_node("ToastLabel") as Label
	var toast_visible_before: bool = toast.visible

	# Act — id 999999 is unknown.
	screen.call("_on_hero_leveled", 999999, 1, 2)
	await get_tree().process_frame

	# Assert — visibility unchanged from baseline (no toast surfaced).
	assert_bool(toast.visible).is_equal(toast_visible_before)


# ===========================================================================
# Group C — reduce_motion suppresses the fade tween
# ===========================================================================

# C-01: under reduce_motion, the toast is shown but no fade tween is created.
# Validates the accessibility branch.
func test_reduce_motion_suppresses_fade_tween() -> void:
	# Arrange.
	var hero_id: int = _seed_hero("warrior", 1)
	assert_int(hero_id).is_greater(0)
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")
	sm.set("reduce_motion", true)
	var screen: Node = _make_screen()
	await get_tree().process_frame
	var toast: Label = screen.get_node("ToastLabel") as Label

	# Act.
	screen.call("_on_hero_leveled", hero_id, 1, 2)
	await get_tree().process_frame

	# Assert — toast visible; _toast_tween remains null (no fade authored).
	assert_bool(toast.visible).is_true()
	var tween: Variant = screen.get("_toast_tween")
	assert_object(tween).override_failure_message(
		"reduce_motion path should NOT create a fade tween"
	).is_null()
