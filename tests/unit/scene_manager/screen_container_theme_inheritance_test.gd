# Sprint 21 fix — Theme inheritance through ScreenContainer regression guard.
#
# Root cause (discovered 2026-05-15 playtest): MainRoot.tscn declared
# ScreenContainer as `type="Node"`. Godot 4.6 theme inheritance only walks
# through Control ancestors; non-Control ancestors break the cascade.
# Result: every screen ever rendered via SceneManager used Godot's default
# Button theme (white text on dark grey), NOT parchment_theme.tres — making
# all design system work (Sprint 10 through Sprint 21) invisible to players.
#
# Fix: ScreenContainer changed to `type="Control"` (with full-rect anchors +
# mouse_filter = IGNORE so input passes through to its screen children).
#
# This test guards against accidental regression to a non-Control type.
extends GdUnitTestSuite

const MainRootScene := preload("res://src/core/scene_manager/MainRoot.tscn")
const GuildHallScene := preload("res://assets/screens/guild_hall/guild_hall.tscn")

# Parchment theme reference values (must match assets/ui/parchment_theme.tres).
const SLATE_INK: Color = Color(0.1725, 0.1569, 0.2196, 1)
const PARCHMENT_CREAM: Color = Color(0.9294, 0.8784, 0.7686, 1)


func test_screen_container_is_a_control_node() -> void:
	# ScreenContainer must extend Control so MainRoot's theme cascades to
	# screen descendants via the Control tree walk. If this test fails, the
	# MainRoot.tscn type was reverted from Control back to Node (or some
	# other non-Control type) — restore it and Godot theme inheritance
	# will work again.
	var main_root: Control = MainRootScene.instantiate() as Control
	auto_free(main_root)
	var screen_container: Node = main_root.get_node("ScreenContainer")
	assert_object(screen_container).override_failure_message(
		"MainRoot.ScreenContainer must exist. Check src/core/scene_manager/MainRoot.tscn."
	).is_not_null()
	assert_bool(screen_container is Control).override_failure_message(
		"ScreenContainer must extend Control (NOT plain Node) so the parchment "
		+ "theme cascades to screen children. Godot 4.6 theme inheritance only "
		+ "walks Control ancestors. Got class: %s" % screen_container.get_class()
	).is_true()


func test_screen_under_screen_container_inherits_parchment_theme() -> void:
	# End-to-end: instantiate MainRoot, add Guild Hall under ScreenContainer
	# (mirroring SceneManager's _execute_transition behavior), and verify
	# a Button inside Guild Hall sees parchment theme colors.
	var main_root: Control = MainRootScene.instantiate() as Control
	add_child(main_root)
	auto_free(main_root)
	await get_tree().process_frame

	var screen_container: Node = main_root.get_node("ScreenContainer")
	var gh: Control = GuildHallScene.instantiate() as Control
	screen_container.add_child(gh)
	await get_tree().process_frame

	# Pick a known Button from Guild Hall.
	var btn: Button = gh.get_node_or_null("DispatchNavButton") as Button
	assert_object(btn).override_failure_message(
		"Expected DispatchNavButton in Guild Hall scene root."
	).is_not_null()

	var font_color: Color = btn.get_theme_color("font_color", "Button")
	assert_float(font_color.r).override_failure_message(
		"Button font_color.r must match Slate Ink (0.1725) — got %f. Parchment "
		+ "theme NOT inheriting through ScreenContainer; check MainRoot.tscn."
		% font_color.r
	).is_equal_approx(SLATE_INK.r, 0.01)
	assert_float(font_color.g).is_equal_approx(SLATE_INK.g, 0.01)
	assert_float(font_color.b).is_equal_approx(SLATE_INK.b, 0.01)


func test_screen_under_screen_container_inherits_panel_container_parchment_bg() -> void:
	# Panel containers inside screens (e.g., Guild Hall's RosterPanel) should
	# inherit the parchment theme's PanelContainer/styles/panel = panel_default
	# StyleBox, which has bg_color = Parchment Cream.
	var main_root: Control = MainRootScene.instantiate() as Control
	add_child(main_root)
	auto_free(main_root)
	await get_tree().process_frame

	var screen_container: Node = main_root.get_node("ScreenContainer")
	var gh: Control = GuildHallScene.instantiate() as Control
	screen_container.add_child(gh)
	await get_tree().process_frame

	var roster_panel: PanelContainer = gh.get_node_or_null("RosterPanel") as PanelContainer
	assert_object(roster_panel).override_failure_message(
		"Expected RosterPanel in Guild Hall scene root."
	).is_not_null()

	var stylebox: StyleBox = roster_panel.get_theme_stylebox("panel", "PanelContainer")
	assert_object(stylebox).is_not_null()
	assert_bool(stylebox is StyleBoxFlat).is_true()
	var bg: Color = (stylebox as StyleBoxFlat).bg_color
	assert_float(bg.r).override_failure_message(
		"RosterPanel.bg_color.r must match Parchment Cream (0.9294) — got %f. "
		+ "Parchment theme NOT cascading to PanelContainer descendants of screens."
		% bg.r
	).is_equal_approx(PARCHMENT_CREAM.r, 0.01)
