# ParchmentKit is the shipping-skin counterpart to WireframeKit (Sprint 29
# theme-first pass). It must honor the SAME input-transparency contract that
# wireframe_kit_input_transparency_test.gd guards — its section backdrops are
# overlaid at the same rect as real interactive panels (behind them via z_index),
# and Godot routes GUI input by TREE ORDER not z_index, so any non-IGNORE node
# would steal taps from the real controls (the 2026-06-03 "can't tap" bug class).
#
# It must ALSO apply the correct theme variations: a wrong variation string
# degrades silently to the default panel (no error), so a screen would look
# "themed" yet miss the intended ParchmentPanel/LedgerRowPanel register. These
# tests pin the variation names so that regression is caught.
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
	# Arrange / Act — build a section_panel the way the real screens do: a titled
	# panel with a caption added into its body.
	var panel: PanelContainer = ParchmentKit.section_panel("Expeditions")
	auto_free(panel)
	ParchmentKit.body_of(panel).add_child(
		ParchmentKit.caption("The lantern is lit.", ParchmentKit.MUTED, 11))

	# Assert
	var offenders: Array = _non_ignore_controls(panel)
	assert_array(offenders).is_empty().override_failure_message(
		"section_panel + its content must be fully MOUSE_FILTER_IGNORE so the "
		+ "parchment backdrop never intercepts taps meant for the real interactive "
		+ "panel it overlays. Non-IGNORE controls found: %s" % str(offenders)
	)


func test_section_panel_applies_parchment_panel_variation() -> void:
	# Arrange / Act
	var panel: PanelContainer = ParchmentKit.section_panel("The Map")
	auto_free(panel)

	# Assert — the panel must resolve the ParchmentPanel variation (panel_parchment
	# stylebox), not silently fall back to the default PanelContainer skin.
	assert_str(panel.theme_type_variation).is_equal("ParchmentPanel").override_failure_message(
		"section_panel must apply the ParchmentPanel theme variation; got '%s'. "
		% panel.theme_type_variation
		+ "A wrong/empty variation degrades to the default panel with no error."
	)


func test_body_of_returns_named_body_vbox() -> void:
	# Arrange / Act
	var panel: PanelContainer = ParchmentKit.section_panel("Event log")
	auto_free(panel)
	var body: VBoxContainer = ParchmentKit.body_of(panel)

	# Assert — the "body" meta contract callers rely on to append rows.
	assert_object(body).is_not_null().override_failure_message(
		"body_of(section_panel) must return the content VBox via the 'body' meta.")
	assert_str(body.name).is_equal("Body")


func test_body_of_returns_null_for_panel_without_body_meta() -> void:
	# Arrange — a bare panel that never went through section_panel().
	var bare: PanelContainer = PanelContainer.new()
	auto_free(bare)

	# Act / Assert — must not crash; returns null when the meta is absent.
	assert_object(ParchmentKit.body_of(bare)).is_null()


func test_eyebrow_caption_divider_are_input_transparent() -> void:
	# Arrange / Act
	var e: Label = ParchmentKit.eyebrow("Title")
	auto_free(e)
	var c: Label = ParchmentKit.caption("body text")
	auto_free(c)
	var d: HSeparator = ParchmentKit.divider()
	auto_free(d)

	# Assert
	assert_int(e.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE).override_failure_message(
		"eyebrow() labels are decorative — must be IGNORE.")
	assert_int(c.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE).override_failure_message(
		"caption() labels are decorative — must be IGNORE.")
	assert_int(d.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE).override_failure_message(
		"divider() separators are decorative — must be IGNORE.")


func test_eyebrow_uppercases_text() -> void:
	# Arrange / Act — eyebrows render as small-caps section labels.
	var e: Label = ParchmentKit.eyebrow("the map")
	auto_free(e)

	# Assert
	assert_str(e.text).is_equal("THE MAP")


func test_list_tile_applies_ledger_row_panel_variation() -> void:
	# Arrange / Act
	var tile: PanelContainer = ParchmentKit.list_tile("Mistwood Hollow", "Floor 3", "WATCH")
	auto_free(tile)

	# Assert — rows use the LedgerRowPanel sub-panel register, not the default panel.
	assert_str(tile.theme_type_variation).is_equal("LedgerRowPanel").override_failure_message(
		"list_tile must apply the LedgerRowPanel theme variation; got '%s'."
		% tile.theme_type_variation
	)


func test_list_tile_subtree_is_input_transparent() -> void:
	# Arrange / Act — a fully-populated tile (title + subtitle + right value).
	var tile: PanelContainer = ParchmentKit.list_tile("Mistwood Hollow", "Floor 3", "WATCH")
	auto_free(tile)

	# Assert — display-only rows must never steal a tap.
	var offenders: Array = _non_ignore_controls(tile)
	assert_array(offenders).is_empty().override_failure_message(
		"list_tile is a display-only row — its whole subtree must be "
		+ "MOUSE_FILTER_IGNORE. Non-IGNORE controls found: %s" % str(offenders)
	)


func test_placeholder_box_applies_ledger_row_panel_variation() -> void:
	# Arrange / Act
	var box: PanelContainer = ParchmentKit.placeholder_box("loot", Vector2(150, 92))
	auto_free(box)

	# Assert — placeholder slots use the LedgerRowPanel sub-panel register so they
	# read as intentional parchment slots, not the default panel or a grey void.
	assert_str(box.theme_type_variation).is_equal("LedgerRowPanel").override_failure_message(
		"placeholder_box must apply the LedgerRowPanel theme variation; got '%s'. "
		% box.theme_type_variation
		+ "A wrong/empty variation degrades to the default panel with no error."
	)
	# Honors the requested min size (the art-region footprint).
	assert_vector(box.custom_minimum_size).is_equal(Vector2(150, 92))


func test_placeholder_box_subtree_is_input_transparent() -> void:
	# Arrange / Act — a labelled placeholder (panel + centered caption).
	var box: PanelContainer = ParchmentKit.placeholder_box("portrait", Vector2(68, 68))
	auto_free(box)

	# Assert — placeholders are decorative art-region stand-ins overlaid on the
	# ceremony; the whole subtree must be IGNORE so none ever steals a tap.
	var offenders: Array = _non_ignore_controls(box)
	assert_array(offenders).is_empty().override_failure_message(
		"placeholder_box is decorative — its whole subtree must be "
		+ "MOUSE_FILTER_IGNORE. Non-IGNORE controls found: %s" % str(offenders)
	)


func test_placeholder_box_renders_label_when_set_and_omits_when_empty() -> void:
	# Arrange / Act — labelled vs bare slot.
	var labelled: PanelContainer = ParchmentKit.placeholder_box("party", Vector2(140, 64))
	auto_free(labelled)
	var bare: PanelContainer = ParchmentKit.placeholder_box("", Vector2(140, 64))
	auto_free(bare)

	# Assert — a non-empty label renders one centered Label child; an empty label
	# yields a bare slot (no child), per the signature contract.
	assert_int(labelled.get_child_count()).is_equal(1)
	var l: Label = labelled.get_child(0) as Label
	assert_object(l).is_not_null()
	assert_str(l.text).is_equal("party")
	assert_int(bare.get_child_count()).is_equal(0)


func test_palette_constants_match_design_tokens() -> void:
	# Guards the single-source-of-truth wiring: ParchmentKit.ACCENT must be the
	# canonical Guild Amber from UIFramework, not a drifted local copy.
	assert_object(ParchmentKit.ACCENT).is_equal(UIFramework.GUILD_AMBER).override_failure_message(
		"ParchmentKit.ACCENT must reference UIFramework.GUILD_AMBER (DESIGN.md palette).")
	# MUTED is Slate Ink at reduced alpha — same RGB as the canonical ink.
	assert_float(ParchmentKit.MUTED.r).is_equal_approx(UIFramework.SLATE_INK.r, 0.01)
	assert_float(ParchmentKit.MUTED.g).is_equal_approx(UIFramework.SLATE_INK.g, 0.01)
	assert_float(ParchmentKit.MUTED.b).is_equal_approx(UIFramework.SLATE_INK.b, 0.01)
	assert_float(ParchmentKit.MUTED.a).is_less(1.0)
