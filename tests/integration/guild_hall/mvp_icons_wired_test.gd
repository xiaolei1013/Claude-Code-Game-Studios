# DESIGN.md "Iconography" / ADR-0024 — the MVP UI icon set must be WIRED, not
# merely authored on disk. This project's dominant defect class is "scaffolded
# but never wired" (the asset exists, no player can ever see it), so this guards
# the three Guild Hall chrome icons shipped in PR-C against a silent revert of
# the .icon / TextureRect wiring:
#   - SettingsGearButton.icon  (Slate Ink cog, replaces the "⚙" text glyph)
#   - DispatchNavButton.icon   (Guild Amber dispatch arrow)
#   - GoldCoinIcon TextureRect (Lantern Gold coin, left of the gold counter)
# Pairs with the deterministic authoring tool tools/asset-pipeline/compose_icons.py
# and the headful render evidence ui_icons_guild_hall_wired_20260616.png.
#
# Harness mirrors all_injured_banner_test.gd: instantiate the real .tscn +
# on_enter() (the coin sibling is created by _build_wireframe_once(), which
# on_enter() invokes), then assert against the live nodes by hard path.
extends GdUnitTestSuite

const GuildHallScene: PackedScene = preload(
	"res://assets/screens/guild_hall/guild_hall.tscn"
)

const ICON_DIR: String = "res://assets/art/ui/icons/"


func _make_guild_hall_in_tree() -> Node:
	var screen: Node = GuildHallScene.instantiate()
	add_child(screen)
	auto_free(screen)
	if screen.has_method("on_enter"):
		screen.on_enter()
	return screen


# ===========================================================================
# Group A — the three chrome icons are wired to their real call sites
# ===========================================================================

func test_settings_gear_button_wired_to_gear_icon() -> void:
	# Arrange / Act
	var screen: Node = _make_guild_hall_in_tree()
	var gear: Button = screen.get_node("SettingsGearButton") as Button

	# Assert — the Slate Ink cog icon replaced the "⚙" text glyph.
	assert_object(gear.icon).is_not_null()
	assert_str(gear.icon.resource_path).is_equal(ICON_DIR + "settings_gear.png")
	assert_str(gear.text).is_empty()


func test_dispatch_nav_button_wired_to_arrow_icon() -> void:
	# Arrange / Act
	var screen: Node = _make_guild_hall_in_tree()
	var dispatch: Button = screen.get_node("DispatchNavButton") as Button

	# Assert — the Guild Amber dispatch arrow is the button's leading icon.
	assert_object(dispatch.icon).is_not_null()
	assert_str(dispatch.icon.resource_path).is_equal(ICON_DIR + "dispatch_arrow.png")


func test_gold_counter_wired_to_coin_icon_sibling() -> void:
	# Arrange / Act
	var screen: Node = _make_guild_hall_in_tree()
	var coin: TextureRect = screen.get_node_or_null("GoldCoinIcon") as TextureRect

	# Assert — the coin TextureRect exists and carries the Lantern Gold coin.
	assert_object(coin).is_not_null()
	assert_object(coin.texture).is_not_null()
	assert_str(coin.texture.resource_path).is_equal(ICON_DIR + "coin.png")


# ===========================================================================
# Group B — crispness + input hygiene (hard-won project lessons)
# ===========================================================================

func test_wired_icons_use_nearest_filter_for_crisp_pixels() -> void:
	# Pixel-art icons under the project's stretch scaling must use NEAREST or they
	# blur into mush at non-integer scales (DESIGN.md "never anti-aliased").
	var screen: Node = _make_guild_hall_in_tree()
	var gear: Button = screen.get_node("SettingsGearButton") as Button
	var dispatch: Button = screen.get_node("DispatchNavButton") as Button
	var coin: TextureRect = screen.get_node("GoldCoinIcon") as TextureRect

	assert_int(gear.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_int(dispatch.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_int(coin.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_coin_icon_ignores_taps() -> void:
	# Decorative — z_index does NOT affect Godot input picking, so a coin drawn
	# "above" the chrome must be MOUSE_FILTER_IGNORE or it would steal taps from
	# controls beneath it (project lesson: zindex_does_not_affect_input_picking).
	var screen: Node = _make_guild_hall_in_tree()
	var coin: TextureRect = screen.get_node("GoldCoinIcon") as TextureRect

	assert_int(coin.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
