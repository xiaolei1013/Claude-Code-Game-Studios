extends Control
## Codex — read-only catalogue modal (Heroes / Monsters / Dungeons).
##
## Lantern Guild mock wireframe (feat/ui-codex-modal). Built ENTIRELY in code
## (no .tscn) to avoid the import-order fragility that structural .tscn edits
## hit. Opened from the Guild Hall "Codex" top-bar tab via
## SceneManager.show_modal(self); closes via SceneManager.hide_modal(self) or a
## tap on the dim backdrop. Greybox: real data from DataRegistry, neutral
## WireframeKit styling.

const WireframeKitScript = preload("res://src/ui/wireframe_kit.gd")

# Backdrop dim. A named const (not an inline literal); mirrors the modal
# DimBackdrop colour used in settings.tscn / pause_menu.tscn.
const _DIM: Color = Color(0, 0, 0, 0.7)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# Dim backdrop — tap outside the sheet to close.
	var dim: ColorRect = ColorRect.new()
	dim.color = _DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# The Codex sheet.
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "CodexSheet"
	panel.add_theme_stylebox_override("panel",
		WireframeKitScript.stylebox(WireframeKitScript.FILL, WireframeKitScript.LINE, 1, 6, 0))
	add_child(panel)
	# Centred 900x600 sheet (explicit offsets — PRESET_CENTER mis-places a
	# min-sized panel, leaving it right-shifted).
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -450.0
	panel.offset_top = -300.0
	panel.offset_right = 450.0
	panel.offset_bottom = 300.0

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Header — eyebrow + title + close.
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(WireframeKitScript.eyebrow("· The guild keeps a record ·", WireframeKitScript.ACCENT))
	var title: Label = Label.new()
	title.text = "The Codex"
	title.theme_type_variation = &"IdentityHeader"
	titles.add_child(title)
	var close_btn: Button = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(100, 44)
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	vbox.add_child(WireframeKitScript.divider())

	# Tabs — each catalogue built from real DataRegistry content.
	var tabs: TabContainer = TabContainer.new()
	tabs.name = "CodexTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tabs)
	tabs.add_child(_make_catalogue_tab("Heroes", "classes"))
	tabs.add_child(_make_catalogue_tab("Monsters", "enemies"))
	tabs.add_child(_make_catalogue_tab("Dungeons", "biomes"))


## One catalogue tab: a scrollable grid of cards built from
## DataRegistry.get_all_by_type(content_type). The child node's name becomes
## the TabContainer tab title.
func _make_catalogue_tab(title: String, content_type: String) -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var entries: Array = []
	if DataRegistry != null:
		entries = DataRegistry.get_all_by_type(content_type)
	if entries.is_empty():
		grid.add_child(WireframeKitScript.caption("Nothing recorded yet.", WireframeKitScript.MUTED))
		return scroll
	for res: Variant in entries:
		grid.add_child(_make_card(res))
	return scroll


## A catalogue card: name + a meta line + flavour, sized for the grid.
func _make_card(res: Variant) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(270, 92)
	card.add_theme_stylebox_override("panel",
		WireframeKitScript.stylebox(WireframeKitScript.FILL_RAISED, WireframeKitScript.LINE_SOFT, 1, 4, 10))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)

	var nm: Label = Label.new()
	nm.text = _display_name(res)
	nm.add_theme_font_size_override("font_size", 15)
	v.add_child(nm)

	var meta: String = _meta_line(res)
	if meta != "":
		v.add_child(WireframeKitScript.eyebrow(meta))

	var flavor: String = _field_str(res, "flavor_text")
	if flavor != "":
		v.add_child(WireframeKitScript.caption(flavor, WireframeKitScript.MUTED, 11))
	return card


func _display_name(res: Variant) -> String:
	var dn: String = _field_str(res, "display_name")
	if dn != "":
		return dn
	var id: String = _field_str(res, "id")
	return id.capitalize() if id != "" else "—"


## Short "Tier N · <archetype/counter> [· BOSS]" meta line, defensively built
## from whichever fields the resource exposes.
func _meta_line(res: Variant) -> String:
	var parts: Array[String] = []
	if res != null and "tier" in res:
		parts.append("Tier %d" % int(res.get("tier")))
	if res != null and "archetype" in res and String(res.get("archetype")) != "":
		parts.append(String(res.get("archetype")))
	elif res != null and "counter_archetype" in res and String(res.get("counter_archetype")) != "":
		parts.append("vs " + String(res.get("counter_archetype")))
	if res != null and "is_boss" in res and bool(res.get("is_boss")):
		parts.append("BOSS")
	var out: String = ""
	for p: String in parts:
		out += (" · " if out != "" else "") + p
	return out


func _field_str(res: Variant, field: String) -> String:
	if res != null and field in res:
		return String(res.get(field))
	return ""


func _on_close_pressed() -> void:
	if SceneManager != null:
		SceneManager.hide_modal(self)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close_pressed()
