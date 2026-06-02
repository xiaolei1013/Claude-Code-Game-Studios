extends Control
## Title / start screen — Lantern Guild mock (feat/ui-title-screen).
##
## Code-only (no .tscn → no import-order fragility). Reached from the Pause
## menu's "Return to Title" and shown via SceneManager.show_modal with an
## OPAQUE backdrop so it fully covers gameplay. The boot route still goes to
## Guild Hall — the onboarding GDD #29 / AC-29-01 first-launch contract is
## intentionally preserved (the mock's boot-to-Title was a design deviation we
## deferred). Greybox styling via WireframeKit.

const WireframeKitScript = preload("res://src/ui/wireframe_kit.gd")
# Opaque title ground — Parchment Cream (DESIGN.md), kept readable with the
# light theme rather than committing to the mock's dark register (deferred).
const _GROUND: Color = Color(0.929, 0.878, 0.769)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# Opaque backdrop — blocks tap-through to the game beneath.
	var bg: ColorRect = ColorRect.new()
	bg.color = _GROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centred content stack.
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var center: VBoxContainer = VBoxContainer.new()
	center.custom_minimum_size = Vector2(300, 0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 14)
	cc.add_child(center)

	# Logo mark placeholder.
	var mark_wrap: HBoxContainer = HBoxContainer.new()
	mark_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	mark_wrap.add_child(WireframeKitScript.placeholder_box("lantern mark", Vector2(96, 96)))
	center.add_child(mark_wrap)

	# Wordmark.
	var wordmark: Label = Label.new()
	wordmark.name = "Wordmark"
	wordmark.text = "Lantern Guild"
	wordmark.theme_type_variation = &"IdentityHeader"
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wordmark.add_theme_font_size_override("font_size", 48)
	center.add_child(wordmark)

	# Tagline.
	var tagline: Label = WireframeKitScript.caption(
		"The dungeon is dark. Send a light.", WireframeKitScript.MUTED, 16)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(tagline)

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	center.add_child(gap)

	# Menu.
	center.add_child(_menu_button("Continue the Watch", _on_continue_pressed))
	center.add_child(_menu_button("Settings", _on_settings_pressed))
	center.add_child(_menu_button("Quit to Desktop", _on_quit_pressed))

	# Footer build-meta.
	var footer: Label = WireframeKitScript.eyebrow(_footer_text())
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -38.0
	footer.offset_bottom = -16.0


func _menu_button(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(280, 48)
	b.pressed.connect(cb)
	return b


func _footer_text() -> String:
	var v: String = String(ProjectSettings.get_setting("application/config/version", ""))
	if v == "":
		v = "prototype"
	return "Build %s · HD-2D · Lantern Guild" % v


## Continue → dismiss the Title and resume the paused game beneath it (Title is
## opened from the Pause overlay; closing both returns to gameplay).
func _on_continue_pressed() -> void:
	if SceneManager == null:
		return
	SceneManager.hide_modal(self)
	if SceneManager.topmost_overlay_id() == "pause_menu":
		SceneManager.pop_overlay("pause_menu")


func _on_settings_pressed() -> void:
	if SceneManager != null:
		SceneManager.push_overlay("settings", true)


func _on_quit_pressed() -> void:
	get_tree().quit()
