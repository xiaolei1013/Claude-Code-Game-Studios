# GDD #34 Phase 5 (Defeat & Injury / ADR-0021 — §E.4 all-injured surface):
# Guild Hall shows a cozy "your guild is recovering" banner when EVERY roster
# hero is still recovering from a defeat (no healthy hero left to form a party).
# Hidden whenever at least one hero is dispatchable, on an empty roster, or once
# the soonest hero recovers. Live-screen integration; pairs with the pure-helper
# unit tests in tests/unit/hero_roster/injury_api_test.gd (Groups E + F).
#
# Harness mirrors roster_injury_mark_test.gd: snapshot/restore live HeroRoster
# via get_save_data/load_save_data, instantiate the real .tscn + on_enter().
extends GdUnitTestSuite

const GuildHallScene: PackedScene = preload(
	"res://assets/screens/guild_hall/guild_hall.tscn"
)

const BANNER_PATH: String = "AllInjuredBanner"
const BANNER_LABEL_PATH: String = "AllInjuredBanner/AllInjuredLabel"

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


## Removes the default starting roster so each test controls its own state.
func _clear_roster() -> void:
	for h_v: Variant in HeroRoster.get_all_heroes():
		HeroRoster._heroes.erase(int(h_v.get("instance_id")))


func _seed_hero(class_id: String) -> int:
	var instance: RefCounted = HeroRoster.call("add_hero", class_id)
	if instance == null:
		return 0
	return int(instance.get("instance_id"))


# ===========================================================================
# Group A — all heroes injured → banner shows
# ===========================================================================

func test_all_injured_shows_banner() -> void:
	# Arrange — a single-hero roster, that hero injured 30 min out → every hero
	# is recovering → the E.4 soft-block state.
	_clear_roster()
	var id: int = _seed_hero("warrior")
	HeroRoster.injure_heroes([id], TickSystem.now_ms() + _INJURY_HORIZON_MS)

	# Act
	var screen: Node = _make_guild_hall_in_tree()
	var banner: Control = screen.get_node(BANNER_PATH) as Control

	# Assert
	assert_bool(banner.visible).is_true()


func test_all_injured_banner_text_mentions_recovering() -> void:
	# Arrange
	_clear_roster()
	var a: int = _seed_hero("warrior")
	var b: int = _seed_hero("mage")
	HeroRoster.injure_heroes([a, b], TickSystem.now_ms() + _INJURY_HORIZON_MS)

	# Act
	var screen: Node = _make_guild_hall_in_tree()
	var label: Label = screen.get_node(BANNER_LABEL_PATH) as Label

	# Assert — the stable copy prefix is present (the live "ready in <time>"
	# suffix is wall-clock dependent and intentionally not asserted exactly).
	assert_str(label.text.to_lower()).contains("recovering")


func test_all_injured_banner_label_ignores_taps() -> void:
	# The banner is informational, never a tap target — Dispatch soft-blocks
	# itself when no party can be formed. Panel + label are MOUSE_FILTER_IGNORE
	# so they cannot steal taps from controls beneath (z_index ≠ input picking).
	_clear_roster()
	var id: int = _seed_hero("warrior")
	HeroRoster.injure_heroes([id], TickSystem.now_ms() + _INJURY_HORIZON_MS)

	var screen: Node = _make_guild_hall_in_tree()
	var banner: Control = screen.get_node(BANNER_PATH) as Control
	var label: Control = screen.get_node(BANNER_LABEL_PATH) as Control

	assert_int(banner.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(label.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


# ===========================================================================
# Group B — at least one dispatchable hero (or none) → banner hidden
# ===========================================================================

func test_one_healthy_hero_hides_banner() -> void:
	# A single healthy hero means the player can still dispatch → not all-injured.
	_clear_roster()
	var injured: int = _seed_hero("warrior")
	_seed_hero("mage")  # healthy — leaves a dispatchable hero
	HeroRoster.injure_heroes([injured], TickSystem.now_ms() + _INJURY_HORIZON_MS)

	var screen: Node = _make_guild_hall_in_tree()
	var banner: Control = screen.get_node(BANNER_PATH) as Control

	assert_bool(banner.visible).is_false()


func test_no_injuries_hides_banner() -> void:
	# A fully healthy roster is never the recovering state.
	_clear_roster()
	_seed_hero("warrior")
	_seed_hero("mage")

	var screen: Node = _make_guild_hall_in_tree()
	var banner: Control = screen.get_node(BANNER_PATH) as Control

	assert_bool(banner.visible).is_false()


func test_empty_roster_hides_banner() -> void:
	# A fresh player with no heroes is NOT "recovering" — nothing to wait for.
	_clear_roster()

	var screen: Node = _make_guild_hall_in_tree()
	var banner: Control = screen.get_node(BANNER_PATH) as Control

	assert_bool(banner.visible).is_false()


func test_past_injury_hides_banner() -> void:
	# Recovery is strict (injured_until > now); an injured_until in the PAST
	# means the hero has recovered → dispatchable → banner hidden.
	_clear_roster()
	var id: int = _seed_hero("warrior")
	HeroRoster.injure_heroes([id], TickSystem.now_ms() - 1000)

	var screen: Node = _make_guild_hall_in_tree()
	var banner: Control = screen.get_node(BANNER_PATH) as Control

	assert_bool(banner.visible).is_false()


# ===========================================================================
# Group C — live signal: injuring the last healthy hero shows the banner
# ===========================================================================

func test_injuring_last_healthy_hero_shows_banner_live() -> void:
	# Arrange — render with a single healthy hero; banner hidden.
	_clear_roster()
	var id: int = _seed_hero("warrior")
	var screen: Node = _make_guild_hall_in_tree()
	var banner: Control = screen.get_node(BANNER_PATH) as Control
	assert_bool(banner.visible).is_false()

	# Act — injure the last healthy hero while the screen is open; the
	# heroes_injured subscription must re-evaluate and show the banner.
	HeroRoster.injure_heroes([id], TickSystem.now_ms() + _INJURY_HORIZON_MS)

	# Assert
	assert_bool(banner.visible).is_true()
