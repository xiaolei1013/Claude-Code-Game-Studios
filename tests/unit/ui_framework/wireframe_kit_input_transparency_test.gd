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
