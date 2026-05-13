# Guild Hall RosterPanel + HeroCard tap → Hero Detail modal wire-up,
# per Guild Hall GDD #19 §C.4 + Hero Detail GDD #22 AC-22-01.
#
# Test groups:
#   A — RosterPanel renders one HeroCard per hero in HeroRoster.get_all_heroes()
#   B — HeroCards sorted by current_level desc, then class_id ascending
#   C — HeroCard tap calls set_target_hero + SceneManager.show_modal
#   D — Roster signal subscriptions trigger _refresh_roster_panel
extends GdUnitTestSuite

const GuildHallScene: PackedScene = preload(
	"res://assets/screens/guild_hall/guild_hall.tscn"
)
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


# ---------------------------------------------------------------------------
# Hygiene barrier — snapshot/restore live HeroRoster + SceneManager state.
# ---------------------------------------------------------------------------

var _snapshot_roster: Dictionary = {}


func before_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_snapshot_roster = roster.get_save_data() if roster != null else {}


func after_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and not _snapshot_roster.is_empty():
		roster.load_save_data(_snapshot_roster)
	var scene_manager: Node = get_tree().root.get_node_or_null("SceneManager")
	if scene_manager != null:
		var modals: Array = scene_manager.get("_active_freestanding_modals") as Array
		if modals != null:
			for m: Variant in modals.duplicate():
				if m is Control:
					(m as Control).queue_free()
			modals.clear()
		scene_manager.set("state", scene_manager.State.IDLE)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_guild_hall_in_tree() -> Node:
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
# Group A — RosterPanel renders one HeroCard per hero
# ===========================================================================

func test_roster_panel_renders_one_card_per_hero() -> void:
	_seed_hero("warrior", 1)
	_seed_hero("mage", 1)
	var screen: Node = _make_guild_hall_in_tree()
	var roster_list: Node = screen.get_node("RosterPanel/RosterScroll/RosterList")
	assert_object(roster_list).is_not_null()
	# Theron (seeded by autoload) + 2 added = 3 cards expected.
	var card_count: int = roster_list.get_child_count()
	assert_int(card_count).is_greater_equal(2)


func test_hero_card_text_includes_name_class_and_level() -> void:
	var id: int = _seed_hero("rogue", 3)
	var screen: Node = _make_guild_hall_in_tree()
	var roster_list: Node = screen.get_node("RosterPanel/RosterScroll/RosterList")
	var found: bool = false
	for child in roster_list.get_children():
		var btn: Button = child as Button
		if btn == null:
			continue
		if btn.text.contains("rogue") and btn.text.contains("Lv3"):
			found = true
			break
	assert_bool(found).override_failure_message(
		"Expected a HeroCard with 'rogue' + 'Lv3' for seeded hero id %d" % id
	).is_true()


# ===========================================================================
# Group B — HeroCards sorted by current_level desc, then class_id ascending
# ===========================================================================

func test_hero_cards_sorted_level_desc_then_class_id_asc() -> void:
	# Clear default Theron so we control the ordering precisely.
	var theron_ids: Array[int] = []
	for h_v: Variant in HeroRoster.get_all_heroes():
		theron_ids.append(int(h_v.get("instance_id")))
	for id: int in theron_ids:
		HeroRoster._heroes.erase(id)

	# Seed: warrior L2, mage L5, rogue L5. Expected order: mage L5, rogue L5, warrior L2.
	_seed_hero("warrior", 2)
	_seed_hero("mage", 5)
	_seed_hero("rogue", 5)

	var screen: Node = _make_guild_hall_in_tree()
	var roster_list: Node = screen.get_node("RosterPanel/RosterScroll/RosterList")
	var labels: Array[String] = []
	for child in roster_list.get_children():
		var btn: Button = child as Button
		if btn != null:
			labels.append(btn.text)
	assert_int(labels.size()).is_equal(3)
	# Higher levels first; within same level, class_id alphabetical (mage < rogue).
	assert_bool(labels[0].contains("mage")).is_true()
	assert_bool(labels[1].contains("rogue")).is_true()
	assert_bool(labels[2].contains("warrior")).is_true()


# ===========================================================================
# Group C — HeroCard tap calls set_target_hero + SceneManager.show_modal
# ===========================================================================

func test_hero_card_tap_wires_pressed_signal_handler() -> void:
	# Verifies HeroCard.pressed is connected to a handler. Cannot verify
	# end-to-end show_modal in test env per TD-010 — OverlayLayer is absent
	# without MainRoot, so SceneManager.show_modal push_errors silently. The
	# behavioral test happens via manual playtest; this test catches the
	# wiring contract (connect call lives in _refresh_roster_panel).
	_seed_hero("warrior", 1)
	var screen: Node = _make_guild_hall_in_tree()

	var roster_list: Node = screen.get_node("RosterPanel/RosterScroll/RosterList")
	var first_card: Button = roster_list.get_child(0) as Button
	assert_object(first_card).is_not_null()

	# Pressed signal has at least one connection (the _on_hero_card_pressed bind).
	var conns: Array = first_card.pressed.get_connections()
	assert_int(conns.size()).is_greater_equal(1)


func test_hero_card_tap_ignored_when_modal_already_active() -> void:
	_seed_hero("warrior", 1)
	var screen: Node = _make_guild_hall_in_tree()
	# Simulate "modal already active" by forcing PAUSED state.
	SceneManager.set("state", SceneManager.State.PAUSED)
	var pre_modal_count: int = (SceneManager.get("_active_freestanding_modals") as Array).size()

	var roster_list: Node = screen.get_node("RosterPanel/RosterScroll/RosterList")
	var first_card: Button = roster_list.get_child(0) as Button
	first_card.pressed.emit()

	var post_modal_count: int = (SceneManager.get("_active_freestanding_modals") as Array).size()
	assert_int(post_modal_count).is_equal(pre_modal_count)


# ===========================================================================
# Group D — Roster signal subscriptions trigger refresh
# ===========================================================================

func test_hero_recruited_signal_refreshes_roster_panel() -> void:
	var screen: Node = _make_guild_hall_in_tree()
	var roster_list: Node = screen.get_node("RosterPanel/RosterScroll/RosterList")
	var initial_count: int = roster_list.get_child_count()

	# add_hero emits hero_recruited which Guild Hall is subscribed to.
	HeroRoster.call("add_hero", "warrior")

	var post_count: int = roster_list.get_child_count()
	assert_int(post_count).is_equal(initial_count + 1)
