class_name ParchmentKit
extends RefCounted

## Parchment-themed UI helpers — the shipping-skin counterpart to [WireframeKit].
##
## Mirrors WireframeKit's factory signatures ([method section_panel],
## [method body_of], [method eyebrow], [method caption], [method divider],
## [method list_tile]) so a greybox screen graduates to the parchment theme by
## swapping the kit reference, NOT by rewriting its layout code. WireframeKit's
## docstring states it is "deliberately NOT the parchment theme", so the themed
## helpers live here rather than bolted onto it (Sprint 29 theme-first pass).
##
## Visuals come from [code]parchment_theme.tres[/code] theme variations
## (ParchmentPanel, LedgerRowPanel) and the DESIGN.md palette in
## [UIFramework] — never raw hex — so the global theme cascade (ADR-0008)
## stays the single source of truth.
##
## Input-transparency contract (regression playtest 2026-06-03): every
## decorative node these factories build is [code]MOUSE_FILTER_IGNORE[/code] on
## the WHOLE subtree. Section backdrops are overlaid at the same rect as real
## interactive panels (behind them via z_index), and Godot routes GUI input by
## TREE ORDER — not z_index — so a non-IGNORE node here would steal taps from the
## real controls it sits over. IGNORE on a parent does NOT propagate to children;
## each node is set individually.

# ---- Parchment palette (sourced from the canonical DESIGN.md constants) ------
## Active / interactive accent + ledger-row right-value — Guild Amber (#C8872A).
const ACCENT: Color = UIFramework.GUILD_AMBER
## Secondary annotation text — Slate Ink (#2C2838) at 70% (DESIGN.md caption spec).
const MUTED: Color = Color(0.17255, 0.15686, 0.21961, 0.70)
## Hairline divider / rule — Slate Ink at low alpha so it reads as a parchment rule.
const LINE_SOFT: Color = Color(0.17255, 0.15686, 0.21961, 0.28)


## A titled section panel: PanelContainer(ParchmentPanel) → VBox("Body").
## The eyebrow title + a hairline divider are added when [param title] is set.
## Retrieve the content container with [method body_of].
##
## No inner MarginContainer (unlike WireframeKit): the ParchmentPanel stylebox
## carries its own 18/14 content padding, so the body VBox is inset by the
## theme — adding a margin node would double-pad.
static func section_panel(title: String, min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	# ParchmentPanel theme variation (panel_parchment 9-patch, 18/14 padding).
	UIFramework.apply_parchment_panel(panel)
	if min_size != Vector2.ZERO:
		panel.custom_minimum_size = min_size
	panel.clip_contents = true
	# Decorative backdrop: never catch input. apply_parchment_panel leaves
	# mouse_filter at the PanelContainer default (STOP), and the DECORATIVE
	# pattern only sets PASS — neither is transparent. The whole subtree must be
	# IGNORE so this never steals taps from the real panel it overlays.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body)

	if title != "":
		body.add_child(eyebrow(title))
		body.add_child(divider())

	panel.set_meta("body", body)
	return panel


## Returns the content VBox of a [method section_panel]. Same "body" meta
## contract as [method WireframeKit.body_of], so callers are kit-agnostic.
static func body_of(panel: Node) -> VBoxContainer:
	if panel == null or not panel.has_meta("body"):
		return null
	return panel.get_meta("body") as VBoxContainer


## Small uppercase label — section eyebrows, HUD labels. Defaults to the muted
## ink register; pass [constant ACCENT] for active/interactive emphasis.
static func eyebrow(text: String, color: Color = MUTED) -> Label:
	var l: Label = Label.new()
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 11)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE  # decorative — never catch input
	return l


## Body caption / annotation line. Wraps. Muted Slate Ink by default
## (DESIGN.md §Component vocabulary: caption = Slate Ink @70%).
static func caption(text: String, color: Color = MUTED, size: int = 13) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE  # decorative — never catch input
	return l


## A hairline divider — a soft Slate-Ink rule on the parchment ground.
static func divider() -> HSeparator:
	var s: HSeparator = HSeparator.new()
	var sb: StyleBoxLine = StyleBoxLine.new()
	sb.color = LINE_SOFT
	sb.thickness = 1
	s.add_theme_stylebox_override("separator", sb)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE  # decorative — never catch input
	return s


## A ledger-row tile: title (left) + optional right value, with optional subtitle
## line. Used for run strips, map/biome rows, etc. Skinned with the LedgerRowPanel
## theme variation (ledger_row sub-panel register).
##
## Display-only: the whole subtree is MOUSE_FILTER_IGNORE so a row can never steal
## a tap (decorative-IGNORE contract). A future story that needs tappable rows
## will add a Button / set the filter deliberately rather than relax this.
static func list_tile(title: String, subtitle: String = "", right: String = "") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = &"LedgerRowPanel"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)

	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var t: Label = Label.new()
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", 14)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(t)
	if right != "":
		var r: Label = Label.new()
		r.text = right
		r.add_theme_color_override("font_color", ACCENT)
		r.add_theme_font_size_override("font_size", 13)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(r)

	if subtitle != "":
		v.add_child(caption(subtitle, MUTED, 11))

	return p
