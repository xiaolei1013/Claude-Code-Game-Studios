# Regression (playtest 2026-06-03): on the Dispatch (formation_assignment) screen
# the player could not tap to assign heroes or select a floor.
#
# Root cause: WireframeKit greybox section_panels are overlaid at the SAME rect as
# the real interactive panels (Roster / Formation / FloorSelector), sitting behind
# them via z_index. But z_index does NOT affect input picking — Godot routes GUI
# input by TREE ORDER, and the greybox is a later sibling. The section_panel's inner
# MarginContainer + Body VBox default to MOUSE_FILTER_PASS, so they intercepted the
# taps meant for the real slot / roster / floor buttons (a PASS control consumes the
# event and bubbles to its parent — it does NOT forward to an earlier-sibling button).
#
# Contract: WireframeKit's decorative helpers must be fully input-transparent
# (MOUSE_FILTER_IGNORE) so greybox scaffolding never steals taps from real controls.
extends GdUnitTestSuite


## Returns names of any descendant Controls that are NOT MOUSE_FILTER_IGNORE.
func _non_ignore_controls(node: Node) -> Array:
	var offenders: Array = []
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			offenders.append("%s (mf=%d)" % [n.name, (n as Control).mouse_filter])
		for c: Node in n.get_children():
			stack.push_back(c)
	return offenders


## Returns names of any descendant nodes that are BaseButton (interactive).
func _base_buttons(node: Node) -> Array:
	var found: Array = []
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is BaseButton:
			found.append((n as Node).name)
		for c: Node in n.get_children():
			stack.push_back(c)
	return found


func test_section_panel_subtree_is_fully_input_transparent() -> void:
	# Build a section_panel the way the real screens do: a titled panel with a
	# caption added into its body.
	var panel: PanelContainer = WireframeKit.section_panel("Formation")
	auto_free(panel)
	WireframeKit.body_of(panel).add_child(
		WireframeKit.caption("tap a slot to select it", WireframeKit.MUTED, 11))

	var offenders: Array = _non_ignore_controls(panel)
	assert_array(offenders).is_empty().override_failure_message(
		"section_panel + its content must be fully MOUSE_FILTER_IGNORE so the greybox "
		+ "never intercepts taps meant for the real interactive panel it overlays. "
		+ "Non-IGNORE controls found: %s" % str(offenders)
	)


func test_eyebrow_caption_divider_are_input_transparent() -> void:
	var e: Label = WireframeKit.eyebrow("Title")
	auto_free(e)
	var c: Label = WireframeKit.caption("body text")
	auto_free(c)
	var d: HSeparator = WireframeKit.divider()
	auto_free(d)
	assert_int(e.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE).override_failure_message(
		"eyebrow() labels are decorative — must be IGNORE.")
	assert_int(c.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE).override_failure_message(
		"caption() labels are decorative — must be IGNORE.")
	assert_int(d.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE).override_failure_message(
		"divider() separators are decorative — must be IGNORE.")


func test_lantern_display_is_input_transparent() -> void:
	# S28-G2 (user-ratified 2026-06-23): the channel-light lantern carries no
	# economy mechanic, so the disc is ambient lit warmth — it must NOT present a
	# tap-target promising an interaction the game does not have. Shared by the
	# Guild Hall and Dungeon Run wireframes; a regression here would put a false
	# affordance back on two screens at once.
	var disc: Panel = WireframeKit.lantern_display()
	auto_free(disc)

	var offenders: Array = _non_ignore_controls(disc)
	assert_array(offenders).is_empty().override_failure_message(
		"lantern_display() is ambient lit warmth, NOT a click target — its whole "
		+ "subtree must be MOUSE_FILTER_IGNORE so there is no false tap-target. "
		+ "Non-IGNORE controls found: %s" % str(offenders)
	)


func test_lantern_block_is_input_transparent() -> void:
	# S28-G2 (user-ratified 2026-06-23): lantern_block() is the assembled bottom-
	# center widget the player actually sees — eyebrow caption + lit disc — shared
	# verbatim by the Guild Hall and Dungeon Run wireframes. The whole subtree must
	# be MOUSE_FILTER_IGNORE; if a later edit reintroduces a focusable/clickable node
	# here (e.g. swapping the disc back for a Button), it would put a false tap-target
	# back on two screens at once. This guards the shared factory at the level the
	# per-disc test cannot reach: the eyebrow + center_row wrapper around the disc.
	var block: VBoxContainer = WireframeKit.lantern_block()
	auto_free(block)

	var offenders: Array = _non_ignore_controls(block)
	assert_array(offenders).is_empty().override_failure_message(
		"lantern_block() is ambient lit warmth, NOT a click target — its whole "
		+ "subtree (WireLantern + eyebrow + center_row + LanternGlow) must be "
		+ "MOUSE_FILTER_IGNORE so there is no false tap-target. "
		+ "Non-IGNORE controls found: %s" % str(offenders)
	)


func test_lantern_block_has_no_interactive_button() -> void:
	# S28-G2 (user-ratified 2026-06-23): MOUSE_FILTER_IGNORE alone does not prove
	# the lantern is inert. A Button with focus_mode=NONE and mouse_filter=IGNORE
	# would still pass the input-transparency tests above, yet fire its `pressed`
	# signal if any caller connected one — reintroducing the false "idle-clicker"
	# affordance S28-G2 removed. The lantern subtree must therefore contain NO
	# BaseButton at all. Guards both the bare disc and the assembled block.
	var disc: Panel = WireframeKit.lantern_display()
	auto_free(disc)
	var block: VBoxContainer = WireframeKit.lantern_block()
	auto_free(block)

	var disc_buttons: Array = _base_buttons(disc)
	var block_buttons: Array = _base_buttons(block)
	assert_array(disc_buttons).is_empty().override_failure_message(
		"lantern_display() must contain no BaseButton — a clickable/connectable "
		+ "control would put the removed idle-clicker affordance back. Found: %s"
		% str(disc_buttons))
	assert_array(block_buttons).is_empty().override_failure_message(
		"lantern_block() must contain no BaseButton — a clickable/connectable "
		+ "control would put the removed idle-clicker affordance back on two "
		+ "screens at once. Found: %s" % str(block_buttons))
