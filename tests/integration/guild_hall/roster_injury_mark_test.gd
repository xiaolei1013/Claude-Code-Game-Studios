# GDD #34 Phase 3 (Defeat & Injury / ADR-0021 — AC-34-09): Guild Hall RosterPanel
# marks an injured hero's card (fade + "Injured" badge) and clears the mark when
# the hero recovers. Live-screen integration; pairs with the pure-helper unit
# tests in tests/unit/ui_framework/ui_framework_injury_test.gd.
#
# Harness mirrors roster_panel_test.gd: snapshot/restore live HeroRoster via
# get_save_data/load_save_data, instantiate the real .tscn + on_enter().
extends GdUnitTestSuite

const GuildHallScene: PackedScene = preload(
	"res://assets/screens/guild_hall/guild_hall.tscn"
)
const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")

const ROSTER_LIST_PATH: String = "RosterPanel/RosterTabs/Active/RosterScroll/RosterList"

# 30 minutes in the future, in wall-clock ms — comfortably "still injured".
const _INJURY_HORIZON_MS: int = 1800 * 1000


var _snapshot_roster: Dictionary = {}


func before_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_snapshot_roster = roster.get_save_data() if roster != null else {}


func after_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and not _snapshot_roster.is_empty():
		roster.load_save_data(_snapshot_roster)


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
	var instance: RefCounted = HeroRoster.call("add_hero", class_id)
	if instance == null:
		return 0
	var id: int = int(instance.get("instance_id"))
	if level > 1:
		instance.set("current_level", level)
	return id


## Returns the first card under the roster list that carries an InjuredBadge.
func _find_injured_card(roster_list: Node) -> Control:
	for child: Node in roster_list.get_children():
		var badge: Node = child.get_node_or_null(NodePath(UIFrameworkScript.INJURED_BADGE_NAME))
		if badge != null:
			return child as Control
	return null


func _count_injured_cards(roster_list: Node) -> int:
	var count: int = 0
	for child: Node in roster_list.get_children():
		if child.get_node_or_null(NodePath(UIFrameworkScript.INJURED_BADGE_NAME)) != null:
			count += 1
	return count


# ===========================================================================
# Group A — injured hero renders a marked card
# ===========================================================================

func test_injured_hero_card_has_injured_badge() -> void:
	# Arrange — seed a hero and injure it 30 minutes into the future.
	var id: int = _seed_hero("warrior", 1)
	HeroRoster.injure_heroes([id], TickSystem.now_ms() + _INJURY_HORIZON_MS)

	# Act — render the screen.
	var screen: Node = _make_guild_hall_in_tree()
	var roster_list: Node = screen.get_node(ROSTER_LIST_PATH)

	# Assert — at least one card carries the additive InjuredBadge child.
	var injured_card: Control = _find_injured_card(roster_list)
	assert_object(injured_card).override_failure_message(
		"Expected an InjuredBadge on the injured hero's card (id %d)" % id
	).is_not_null()


func test_injured_hero_card_is_dimmed() -> void:
	# Arrange
	var id: int = _seed_hero("warrior", 1)
	HeroRoster.injure_heroes([id], TickSystem.now_ms() + _INJURY_HORIZON_MS)

	# Act
	var screen: Node = _make_guild_hall_in_tree()
	var roster_list: Node = screen.get_node(ROSTER_LIST_PATH)

	# Assert — the marked card's modulate alpha is the injured dim constant.
	var injured_card: Control = _find_injured_card(roster_list)
	assert_object(injured_card).is_not_null()
	assert_float(injured_card.modulate.a).is_equal_approx(
		UIFrameworkScript.INJURED_DIM_ALPHA, 0.001
	)


func test_injured_badge_does_not_steal_taps() -> void:
	# AC-34-04: only Dispatch is gated — the injured hero card stays tappable.
	# The badge must be MOUSE_FILTER_IGNORE so taps reach the card Button.
	# Arrange
	var id: int = _seed_hero("warrior", 1)
	HeroRoster.injure_heroes([id], TickSystem.now_ms() + _INJURY_HORIZON_MS)

	# Act
	var screen: Node = _make_guild_hall_in_tree()
	var roster_list: Node = screen.get_node(ROSTER_LIST_PATH)

	# Assert
	var injured_card: Control = _find_injured_card(roster_list)
	assert_object(injured_card).is_not_null()
	var badge: Control = injured_card.get_node(
		NodePath(UIFrameworkScript.INJURED_BADGE_NAME)
	) as Control
	assert_int(badge.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


# ===========================================================================
# Group B — healthy heroes are NOT marked
# ===========================================================================

func test_healthy_hero_card_has_no_injured_badge() -> void:
	# Clear default heroes so the only card is the healthy seed.
	for h_v: Variant in HeroRoster.get_all_heroes():
		HeroRoster._heroes.erase(int(h_v.get("instance_id")))
	_seed_hero("warrior", 1)

	# Act
	var screen: Node = _make_guild_hall_in_tree()
	var roster_list: Node = screen.get_node(ROSTER_LIST_PATH)

	# Assert — no injured marks on a roster with no injured heroes.
	assert_int(_count_injured_cards(roster_list)).is_equal(0)


func test_past_injured_until_is_treated_as_healthy() -> void:
	# Recovery is strict (injured_until > now). An injured_until in the PAST
	# means the hero has recovered → no mark.
	# Arrange
	for h_v: Variant in HeroRoster.get_all_heroes():
		HeroRoster._heroes.erase(int(h_v.get("instance_id")))
	var id: int = _seed_hero("warrior", 1)
	# Injure to a moment already elapsed (1 second ago).
	HeroRoster.injure_heroes([id], TickSystem.now_ms() - 1000)

	# Act
	var screen: Node = _make_guild_hall_in_tree()
	var roster_list: Node = screen.get_node(ROSTER_LIST_PATH)

	# Assert
	assert_int(_count_injured_cards(roster_list)).is_equal(0)


# ===========================================================================
# Group C — live signal: injuring a hero while the screen is open re-marks it
# ===========================================================================

func test_heroes_injured_signal_marks_card_live() -> void:
	# Arrange — render with a healthy roster first.
	for h_v: Variant in HeroRoster.get_all_heroes():
		HeroRoster._heroes.erase(int(h_v.get("instance_id")))
	var id: int = _seed_hero("warrior", 1)
	var screen: Node = _make_guild_hall_in_tree()
	var roster_list: Node = screen.get_node(ROSTER_LIST_PATH)
	assert_int(_count_injured_cards(roster_list)).is_equal(0)

	# Act — injure while the screen is open; the heroes_injured subscription
	# must trigger a refresh that re-marks the card.
	HeroRoster.injure_heroes([id], TickSystem.now_ms() + _INJURY_HORIZON_MS)

	# Assert
	assert_int(_count_injured_cards(roster_list)).is_equal(1)
