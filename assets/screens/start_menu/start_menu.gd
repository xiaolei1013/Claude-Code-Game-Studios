## StartMenu — boot entry screen for Lantern Guild.
##
## Shown on every cold launch (SceneManager._on_registry_ready routes here
## instead of directly to guild_hall). Gives players a branded pause before
## the game begins, surfaces the version, and handles a clean Quit path.
##
## Layout: code-only (no .tscn node dependencies), so it is immune to the
## hard-path node-coupling fragility. All interactive children are referenced
## via local variables from _build().
##
## Navigation:
##   "Start Expedition" → request_screen("guild_hall")
##   "Quit"             → get_tree().quit()
##
## The screen has no on_exit signals to disconnect because it registers none.
## If a return path to the start menu is ever needed (e.g. from a future
## "Quit to Title" action), add it in SceneManager.request_screen("start_menu").
extends Screen

const WireframeKitScript = preload("res://src/ui/wireframe_kit.gd")
const ClassSpriteFactoryScript = preload("res://src/ui/class_sprite_factory.gd")
const ClassPortraitFactoryScript = preload("res://src/ui/class_portrait_factory.gd")

## Parchment-cream ground (DESIGN.md token — Parchment Cream #EDE0C4).
## Keeps the start menu in the light-register theme rather than committing
## to a dark variant before the skin decision is made (see active.md REMAINING).
const _GROUND: Color = Color(0.929, 0.878, 0.769)

## Hero classes cycled in the demo portrait row beneath the logo.
const _DEMO_CLASSES: PackedStringArray = [
	"warrior", "mage", "rogue", "cleric", "archer", "berserker", "paladin"
]

## Button min-width keeps tap targets ≥ 44 px per technical-preferences.md.
const _BTN_MIN_SIZE: Vector2 = Vector2(260, 48)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func on_enter() -> void:
	pass  # Nothing to connect or refresh on every entry for this screen.


func on_exit() -> void:
	pass  # Nothing to disconnect.


func on_pause() -> void:
	pass  # Start menu is never paused (no pause overlay reachable from boot).


func on_resume() -> void:
	pass  # No paused state to restore.


func _build() -> void:
	# Full-screen parchment backdrop.
	var bg: ColorRect = ColorRect.new()
	bg.color = _GROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centre column — logo + tagline + demo sprites + buttons.
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)

	var col: VBoxContainer = VBoxContainer.new()
	col.custom_minimum_size = Vector2(360, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	cc.add_child(col)

	# Lantern mark placeholder.
	var mark_row: HBoxContainer = HBoxContainer.new()
	mark_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mark_row.add_child(WireframeKitScript.placeholder_box("lantern", Vector2(80, 80)))
	col.add_child(mark_row)

	# Game title wordmark.
	var title_label: Label = Label.new()
	title_label.name = "Wordmark"
	title_label.text = "Lantern Guild"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.theme_type_variation = &"IdentityHeader"
	title_label.add_theme_font_size_override("font_size", 52)
	col.add_child(title_label)

	# Tagline.
	var tagline: Label = WireframeKitScript.caption(
		"The dungeon is dark. Send a light.", WireframeKitScript.MUTED, 16)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tagline)

	# Demo class sprite row — shows the 7 hero silhouettes when demo assets are
	# imported. Falls back to 48×48 coloured-block portraits when absent.
	col.add_child(_build_sprite_row())

	# Spacing.
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)

	# Primary CTA.
	var start_btn: Button = _nav_button("Start Expedition", _on_start_pressed)
	start_btn.name = "StartButton"
	col.add_child(start_btn)

	var quit_btn: Button = _nav_button("Quit", _on_quit_pressed)
	quit_btn.name = "QuitButton"
	col.add_child(quit_btn)

	# Build-meta footer.
	var footer: Label = WireframeKitScript.eyebrow(_footer_text())
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -34.0
	footer.offset_bottom = -12.0


## Builds a centred row of 48×48 demo portrait/sprite slots — one per class.
## When the demo sprite sheet is imported, ClassSpriteFactory.animate() turns
## the still portrait into a looping idle animation at the calm PORTRAIT tier
## (3 fps — half the in-scene rate; Story 014 / GDD #35 §D.7).
func _build_sprite_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "DemoSpriteRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)

	for class_id: String in _DEMO_CLASSES:
		var slot: TextureRect = TextureRect.new()
		slot.custom_minimum_size = Vector2(48, 48)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.texture = ClassPortraitFactoryScript.get_portrait_texture(class_id)
		row.add_child(slot)
		# Calm PORTRAIT tier: half the in-scene rate (Story 014 / GDD #35 §D.7).
		# reduce_motion (Story 015 / §C.8): the idle holds a static frame under the
		# accessibility flag — presence without motion.
		ClassSpriteFactoryScript.animate(
			slot, class_id, ClassSpriteFactoryScript.PORTRAIT_IDLE_FPS,
			_is_reduce_motion_enabled())

	return row


func _nav_button(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = _BTN_MIN_SIZE
	b.pressed.connect(cb)
	return b


func _footer_text() -> String:
	var v: String = String(ProjectSettings.get_setting("application/config/version", ""))
	return "v%s · Lantern Guild · Demo Build" % (v if v != "" else "0.0.0")


func _on_start_pressed() -> void:
	SceneManager.request_screen("guild_hall")


func _on_quit_pressed() -> void:
	get_tree().quit()


## Reads the live accessibility motion preference off the SceneManager autoload
## (Story 015 / §C.8). Returns false when the autoload or the flag is absent, so
## the start-menu sprite row degrades to animated-idle — the safe, non-breaking
## default. Read when the row is built; a row built under reduce_motion holds a
## static frame instead of looping.
func _is_reduce_motion_enabled() -> bool:
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm == null:
		return false
	if not ("reduce_motion" in sm):
		return false
	return bool(sm.get("reduce_motion"))
