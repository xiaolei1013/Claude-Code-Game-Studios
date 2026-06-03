class_name WireframeKit
extends RefCounted

## Greybox / wireframe UI helpers for the "Lantern Guild" mock-design pass
## (branch feat/ui-wireframe-core-loop).
##
## Builds neutral medium-grey structural widgets — deliberately NOT the
## parchment theme — so wireframe screens read as "layout & information
## architecture, not final skin". The later polish pass (which resolves the
## dark-mock-vs-light-parchment theme question) replaces these greybox widgets
## with themed panels.
##
## All factories return plain Control nodes; the caller positions them. Section
## panels expose their content container via [method body_of].
##
## Palette is medium grey so the default theme's dark Slate-Ink label text
## stays readable without per-label color overrides.

# ---- Neutral greybox palette ------------------------------------------------
const FILL: Color = Color(0.81, 0.80, 0.83)            # panel ground
const FILL_RAISED: Color = Color(0.87, 0.86, 0.89)     # raised / inner ground
const HEADER_FILL: Color = Color(0.72, 0.71, 0.75)     # top-bar / header strip
const PLACEHOLDER_FILL: Color = Color(0.75, 0.74, 0.78) # art-region placeholder
const LINE: Color = Color(0.36, 0.34, 0.42)            # wireframe outline (slate-grey)
const LINE_SOFT: Color = Color(0.36, 0.34, 0.42, 0.45)
const ACCENT: Color = Color(0.62, 0.49, 0.16)          # muted gold — interactive / CTA hint
const TEXT: Color = Color(0.17, 0.16, 0.22)            # Slate Ink (default body text)
const MUTED: Color = Color(0.32, 0.30, 0.39, 0.85)     # secondary annotation
const LANTERN_HOVER: Color = Color(0.91, 0.88, 0.78)
const LANTERN_PRESSED: Color = Color(0.86, 0.81, 0.66)

const PAD: int = 12


## Builds a flat greybox stylebox. [param pad] is the content margin on all
## four sides (0 when the panel hosts its own MarginContainer).
static func stylebox(fill: Color, border: Color, border_w: int = 1, radius: int = 3, pad: int = PAD) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


## A titled section panel: PanelContainer → MarginContainer → VBox("Body").
## The eyebrow title + a hairline divider are added when [param title] is set.
## Retrieve the content container with [method body_of].
static func section_panel(title: String, min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", stylebox(FILL, LINE, 1, 3, 0))
	if min_size != Vector2.ZERO:
		panel.custom_minimum_size = min_size
	panel.clip_contents = true
	# Decorative greybox: never catch input. These panels are routinely overlaid
	# at the SAME rect as real interactive panels (behind them via z_index). Since
	# Godot routes GUI input by tree order — NOT z_index — a non-IGNORE node here
	# would steal taps from the real slot/roster/floor controls it sits over.
	# (MarginContainer/VBoxContainer default to MOUSE_FILTER_PASS, which intercepts.)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PAD)
	margin.add_theme_constant_override("margin_right", PAD)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", PAD)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(body)

	if title != "":
		body.add_child(eyebrow(title))
		body.add_child(divider())

	panel.set_meta("body", body)
	return panel


## Returns the content VBox of a [method section_panel].
static func body_of(panel: Node) -> VBoxContainer:
	if panel == null or not panel.has_meta("body"):
		return null
	return panel.get_meta("body") as VBoxContainer


## Small uppercase label — section eyebrows, HUD labels.
static func eyebrow(text: String, color: Color = MUTED) -> Label:
	var l: Label = Label.new()
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 11)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE  # decorative — never catch input
	return l


## Body caption / annotation line. Wraps.
static func caption(text: String, color: Color = MUTED, size: int = 13) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE  # decorative — never catch input
	return l


## A hairline divider in the wireframe line color.
static func divider() -> HSeparator:
	var s: HSeparator = HSeparator.new()
	var sb: StyleBoxLine = StyleBoxLine.new()
	sb.color = LINE_SOFT
	sb.thickness = 1
	s.add_theme_stylebox_override("separator", sb)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE  # decorative — never catch input
	return s


## A labelled placeholder for an art region (diorama, portrait, icon). Renders
## as a distinct grey box with a centered "[ LABEL ]" annotation so wireframe
## reviewers can see where final art lands.
static func placeholder_box(label: String, min_size: Vector2) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", stylebox(PLACEHOLDER_FILL, LINE_SOFT, 1, 3, 0))
	var l: Label = Label.new()
	l.text = "[ %s ]" % label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", MUTED)
	l.add_theme_font_size_override("font_size", 12)
	p.add_child(l)
	return p


## A ledger-row tile: title (left) + optional right value, with optional
## subtitle line. Used for dungeon tiles, run strips, roster-ish rows in the
## wireframe. Returns a PanelContainer; not interactive by itself.
static func list_tile(title: String, subtitle: String = "", right: String = "") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", stylebox(FILL_RAISED, LINE_SOFT, 1, 2, 10))

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)

	var top: HBoxContainer = HBoxContainer.new()
	v.add_child(top)
	var t: Label = Label.new()
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", 14)
	top.add_child(t)
	if right != "":
		var r: Label = Label.new()
		r.text = right
		r.add_theme_color_override("font_color", ACCENT)
		r.add_theme_font_size_override("font_size", 13)
		top.add_child(r)

	if subtitle != "":
		v.add_child(caption(subtitle, MUTED, 11))

	return p


# ---- Lantern (idle-clicker click target) + floating numbers -----------------

## The circular "LIGHT" lantern button. Connects [param on_pressed] if valid.
## Idle-clicker hero element; shared by the Hall and Expedition wireframes.
static func lantern_button(on_pressed: Callable = Callable()) -> Button:
	var btn: Button = Button.new()
	btn.name = "LanternButton"
	btn.custom_minimum_size = Vector2(118, 118)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = "LIGHT"
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_stylebox_override("normal", stylebox(FILL_RAISED, ACCENT, 2, 60, 0))
	btn.add_theme_stylebox_override("hover", stylebox(LANTERN_HOVER, ACCENT, 2, 60, 0))
	btn.add_theme_stylebox_override("pressed", stylebox(LANTERN_PRESSED, ACCENT, 3, 60, 0))
	if on_pressed.is_valid():
		btn.pressed.connect(on_pressed)
	return btn


## Full-rect, input-transparent layer to host floating numbers. The caller adds
## it to the screen and presets it to full rect.
static func float_layer() -> Control:
	var layer: Control = Control.new()
	layer.name = "WireFloatLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 4
	return layer


## Spawns a floating "+N"-style label at [param pos] on [param layer]. When
## [param animate] is false (reduce-motion) it snap-holds then frees with no
## travel. Self-frees via its own tween.
static func spawn_float(layer: Control, text: String, pos: Vector2, animate: bool = true) -> void:
	if layer == null:
		return
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", ACCENT)
	layer.add_child(lbl)
	lbl.position = pos
	if not animate:
		var hold: Tween = lbl.create_tween()
		hold.tween_interval(0.5)
		hold.tween_callback(lbl.queue_free)
		return
	var tw: Tween = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 64.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(lbl.queue_free)
