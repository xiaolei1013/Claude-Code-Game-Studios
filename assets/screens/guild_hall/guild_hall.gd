## Guild Hall — first-launch landing screen (placeholder, with smoke nav).
##
## Sprint 8 S8-M4 hotfix: added a "Go to Dispatch" button so the manual smoke
## flow (Guild Hall → FormationAssignment → DungeonRunView → MainMenu) can be
## walked end-to-end without dev-console intervention. Sprint 9+ replaces this
## placeholder with the real Guild Hall content.
##
## Sprint 21+ Prestige V1.0 / Story 3 UI (Slice B): adds the
## "Hall of Retired Heroes" entry button, visibility-gated on
## `HeroRoster.get_prestige_count() > 0` per
## `design/gdd/prestige-system.md` §F.
extends Screen

@onready var _dispatch_nav_button: Button = $DispatchNavButton
@onready var _hall_nav_button: Button = $HallOfRetiredHeroesNavButton
@onready var _toast_label: Label = $ToastLabel
@onready var _gold_counter: Label = $GoldCounter
@onready var _recruit_nav_button: Button = $RecruitNavButton
@onready var _roster_list: VBoxContainer = $RosterPanel/RosterScroll/RosterList
@onready var _settings_gear_button: Button = $SettingsGearButton

const HeroDetailModalScene: PackedScene = preload(
	"res://assets/screens/hero_detail/hero_detail_modal.tscn"
)
const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")

# Prestige completion toast — fades over 4.0s matching the
# formation_assignment + Recruitment toast pattern (GDD #21 §G).
const TOAST_FADE_DURATION_SEC: float = 4.0
var _toast_tween: Tween = null


func on_enter() -> void:
	if _dispatch_nav_button == null:
		push_error("[GuildHall] _dispatch_nav_button is NULL — @onready did not resolve. Check .tscn node name 'DispatchNavButton'.")
		return
	if not _dispatch_nav_button.pressed.is_connected(_on_dispatch_nav_pressed):
		_dispatch_nav_button.pressed.connect(_on_dispatch_nav_pressed)

	if _recruit_nav_button != null:
		if not _recruit_nav_button.pressed.is_connected(_on_recruit_nav_pressed):
			_recruit_nav_button.pressed.connect(_on_recruit_nav_pressed)
	_refresh_gold_counter()
	if not Economy.gold_changed.is_connected(_on_gold_changed):
		Economy.gold_changed.connect(_on_gold_changed)

	_refresh_roster_panel()
	if not HeroRoster.hero_recruited.is_connected(_on_roster_changed):
		HeroRoster.hero_recruited.connect(_on_roster_changed)
	if not HeroRoster.hero_removed.is_connected(_on_roster_changed):
		HeroRoster.hero_removed.connect(_on_roster_changed)
	if not HeroRoster.hero_leveled.is_connected(_on_hero_leveled):
		HeroRoster.hero_leveled.connect(_on_hero_leveled)
	# Sprint 16 — biome progression gate. FloorUnlock emits biome_unlocked
	# when a gated biome's prereq floor first-clears (e.g. clearing
	# frostmire_f5 unlocks ember_wastes). Guild Hall surfaces a cozy toast.
	if FloorUnlock.has_signal("biome_unlocked") and not FloorUnlock.biome_unlocked.is_connected(_on_biome_unlocked):
		FloorUnlock.biome_unlocked.connect(_on_biome_unlocked)

	if _settings_gear_button != null:
		if not _settings_gear_button.pressed.is_connected(_on_settings_gear_pressed):
			_settings_gear_button.pressed.connect(_on_settings_gear_pressed)

	# Hall of Retired Heroes button: localized label + visibility gate +
	# subscribe to prestige_completed_signal so a freshly-prestiged hero
	# pops the button into view immediately on screen-resume.
	if _hall_nav_button != null:
		_hall_nav_button.text = tr("guild_hall_open_hall_button_label")
		if not _hall_nav_button.pressed.is_connected(_on_hall_nav_pressed):
			_hall_nav_button.pressed.connect(_on_hall_nav_pressed)
		if not HeroRoster.prestige_completed_signal.is_connected(_on_prestige_completed):
			HeroRoster.prestige_completed_signal.connect(_on_prestige_completed)
		_refresh_hall_button_visibility()


func on_exit() -> void:
	if _dispatch_nav_button != null and _dispatch_nav_button.pressed.is_connected(_on_dispatch_nav_pressed):
		_dispatch_nav_button.pressed.disconnect(_on_dispatch_nav_pressed)
	if _recruit_nav_button != null and _recruit_nav_button.pressed.is_connected(_on_recruit_nav_pressed):
		_recruit_nav_button.pressed.disconnect(_on_recruit_nav_pressed)
	if Economy.gold_changed.is_connected(_on_gold_changed):
		Economy.gold_changed.disconnect(_on_gold_changed)
	if HeroRoster.hero_recruited.is_connected(_on_roster_changed):
		HeroRoster.hero_recruited.disconnect(_on_roster_changed)
	if HeroRoster.hero_removed.is_connected(_on_roster_changed):
		HeroRoster.hero_removed.disconnect(_on_roster_changed)
	if HeroRoster.hero_leveled.is_connected(_on_hero_leveled):
		HeroRoster.hero_leveled.disconnect(_on_hero_leveled)
	if FloorUnlock.has_signal("biome_unlocked") and FloorUnlock.biome_unlocked.is_connected(_on_biome_unlocked):
		FloorUnlock.biome_unlocked.disconnect(_on_biome_unlocked)
	if _settings_gear_button != null and _settings_gear_button.pressed.is_connected(_on_settings_gear_pressed):
		_settings_gear_button.pressed.disconnect(_on_settings_gear_pressed)
	if _hall_nav_button != null and _hall_nav_button.pressed.is_connected(_on_hall_nav_pressed):
		_hall_nav_button.pressed.disconnect(_on_hall_nav_pressed)
	if HeroRoster.prestige_completed_signal.is_connected(_on_prestige_completed):
		HeroRoster.prestige_completed_signal.disconnect(_on_prestige_completed)
	# Kill any in-flight toast tween so its bound `_dismiss_toast`
	# callback can't fire on a being-freed node.
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null


func on_pause() -> void:
	pass


func on_resume() -> void:
	pass


# ---------------------------------------------------------------------------
# Hall of Retired Heroes button — visibility gate + nav
# ---------------------------------------------------------------------------

## Hides the Hall button until at least one prestige has been completed.
## Per `prestige-system.md` §F + cozy-register rule: don't tease the
## player with an empty Hall view. The button's visibility is content-
## addressable: it shows iff
## [code]HeroRoster.get_prestige_count() > 0[/code].
func _refresh_hall_button_visibility() -> void:
	if _hall_nav_button == null:
		return
	_hall_nav_button.visible = HeroRoster.get_prestige_count() > 0


func _on_prestige_completed(record: Dictionary, _new_count: int) -> void:
	_refresh_hall_button_visibility()
	# Cozy completion toast: "[hero name] joined the Hall of Retired
	# Heroes." Tween freezes if Guild Hall is paused under a modal at
	# emit time (Hero Detail Modal flow), then resumes on modal close —
	# the toast remains at modulate.a=1.0 during the modal cover and
	# starts fading out the moment the modal dismisses. Net effect:
	# player sees the toast appear as the modal closes. Acceptable
	# per the existing screen pause/tween contract.
	var display_name: String = String(record.get("display_name", ""))
	if display_name == "":
		return
	# Single %s, no literal %, so the % operator is safe here.
	var text: String = tr("prestige_complete_toast") % display_name
	_show_toast(text)


## Renders [param text] on the bottom-center toast label and fades it
## over [code]TOAST_FADE_DURATION_SEC[/code]. Mirrors the formation_assignment
## + Recruitment toast pattern (GDD #21 §G precedent). Kills any in-flight
## prior toast before starting the new one.
##
## Reduce-motion variant (S15-S2): when [code]SceneManager.reduce_motion[/code]
## is true, the fade tween is suppressed. The toast snap-shows and is hidden
## via a one-shot timer after the same total duration — no animation, no
## easing. Same on-screen residency, accessible behaviour.
##
## Generic — used by both prestige completion and hero level-up toasts.
## Renamed from _show_prestige_toast in S15-S2.
func _show_toast(text: String) -> void:
	if _toast_label == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_label.visible = true
	if SceneManager.reduce_motion:
		# Snap-hide via a one-shot timer (no fade).
		get_tree().create_timer(TOAST_FADE_DURATION_SEC).timeout.connect(_dismiss_toast, CONNECT_ONE_SHOT)
		return
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, TOAST_FADE_DURATION_SEC)
	_toast_tween.finished.connect(_dismiss_toast, CONNECT_ONE_SHOT)


func _dismiss_toast() -> void:
	if _toast_label != null:
		_toast_label.visible = false
		_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null


func _on_hall_nav_pressed() -> void:
	SceneManager.request_screen("hall_of_retired_heroes", SceneManager.TransitionType.CROSS_FADE)


func _on_dispatch_nav_pressed() -> void:
	SceneManager.request_screen("formation_assignment", SceneManager.TransitionType.CROSS_FADE)


## Navigates to the recruitment screen.
func _on_recruit_nav_pressed() -> void:
	SceneManager.request_screen("recruitment", SceneManager.TransitionType.CROSS_FADE)


## Refreshes the gold counter label against the live Economy balance.
func _refresh_gold_counter() -> void:
	if _gold_counter == null:
		return
	_set_gold_text(Economy.get_gold_balance())


## Updates the gold counter label, guarding against redundant assignments
## (Label.text setter marks the node dirty even on identical-value writes).
func _set_gold_text(balance: int) -> void:
	var formatted: String = "Gold: %d" % balance
	if _gold_counter.text != formatted:
		_gold_counter.text = formatted


func _on_gold_changed(new_balance: int, _delta: int, _reason: String) -> void:
	if _gold_counter != null:
		_set_gold_text(new_balance)


# ---------------------------------------------------------------------------
# Roster panel (Guild Hall GDD #19 §C.4 + Hero Detail GDD #22 §C.2 wire-up)
# ---------------------------------------------------------------------------

## Rebuilds the HeroCard list from HeroRoster.get_all_heroes(). Sorted by
## current_level desc, then class_id ascending, per GDD #19 §C.4. Each card
## is a Button (for tap handling) with child Labels showing name/class/level
## + a slim ProgressBar for XP toward next level. Tap fires
## _on_hero_card_pressed(instance_id) which opens the Hero Detail modal.
func _refresh_roster_panel() -> void:
	if _roster_list == null:
		return
	for child in _roster_list.get_children():
		child.queue_free()
	var heroes: Array = HeroRoster.get_all_heroes()
	heroes.sort_custom(func(a: Variant, b: Variant) -> bool:
		var la: int = int(a.get("current_level"))
		var lb: int = int(b.get("current_level"))
		if la != lb:
			return la > lb
		return String(a.get("class_id")) < String(b.get("class_id"))
	)
	for hero_v: Variant in heroes:
		var hero: RefCounted = hero_v as RefCounted
		if hero == null:
			continue
		_roster_list.add_child(_build_hero_card(hero))


## Constructs a single HeroCard widget per GDD #19 §C.4. Layout:
##   Button (no text; captures tap)
##   └── VBoxContainer (mouse_filter = IGNORE so taps pass to Button)
##       ├── Label "{display_name} · {class_id} · Lv {current_level}"
##       └── ProgressBar (slim, no percent text) showing xp / xp_threshold
##
## At level cap (level_cap()), the bar shows full. Below cap, the bar shows
## fraction of XP toward next level via HeroRoster.xp_threshold(level).
func _build_hero_card(hero: RefCounted) -> Button:
	var card: Button = Button.new()
	card.text = ""
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 56)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var summary_label: Label = Label.new()
	# Sprint 17 — append "· vs <archetype>" so the matchup signal is
	# visible on the Guild Hall roster without needing a modal tap.
	# Defensive: class with no counter_archetype falls back to the prior
	# 3-segment format. Continues the matchup awareness chain
	# (PR #84, #85, #86) into the player's home screen.
	var class_id_str: String = String(hero.get("class_id"))
	var class_data: Resource = DataRegistry.resolve("classes", class_id_str)
	var counter: String = ""
	if class_data != null and "counter_archetype" in class_data:
		counter = String(class_data.counter_archetype)
	if counter != "":
		summary_label.text = "%s · %s · Lv %d · vs %s" % [
			String(hero.get("display_name")),
			class_id_str,
			int(hero.get("current_level")),
			counter,
		]
	else:
		summary_label.text = "%s · %s · Lv %d" % [
			String(hero.get("display_name")),
			class_id_str,
			int(hero.get("current_level")),
		]
	summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(summary_label)

	var xp_bar: ProgressBar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 6)
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var current_level: int = int(hero.get("current_level"))
	var cap: int = HeroRoster.level_cap()
	if current_level >= cap:
		xp_bar.max_value = 1.0
		xp_bar.value = 1.0
	else:
		var threshold: int = HeroRoster.xp_threshold(current_level)
		xp_bar.max_value = maxi(threshold, 1)
		xp_bar.value = clampi(int(hero.get("xp")), 0, threshold)
	vbox.add_child(xp_bar)

	var instance_id: int = int(hero.get("instance_id"))
	card.pressed.connect(_on_hero_card_pressed.bind(instance_id))
	# Touch-feedback pulse + UI tap chime per Art Bible §7 / ADR-0008 §wire_touch_feedback.
	UIFrameworkScript.wire_touch_feedback(card)
	return card


## HeroRoster signal handlers — re-render the panel on roster changes.
## Both hero_recruited (1-arg) and hero_removed (3-arg) route here; the args
## are ignored — we rebuild from current roster state.
func _on_roster_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_refresh_roster_panel()


## hero_leveled handler — refresh the roster (XP bar repaint) AND fire a
## cozy toast announcing the level-up. S15-S2 (closes S14-N2).
##
## The toast reuses _show_toast which mirrors the prestige toast tween path:
## fades over TOAST_FADE_DURATION_SEC. Under reduce_motion, the fade is
## suppressed and the toast snap-hides via a Timer after the same duration
## (no animation, no easing).
##
## Signal arity is (id, old_level, new_level) per HeroRoster.gd:790.
func _on_hero_leveled(id: int, _old_level: int, new_level: int) -> void:
	_refresh_roster_panel()
	# Resolve display name for the toast. If the hero isn't resolvable
	# (race: removed between level-up and the signal handler), skip the
	# toast — the roster refresh has already happened.
	var hero: HeroInstance = HeroRoster.get_hero_by_id(id)
	if hero == null:
		return
	var display_name: String = String(hero.display_name)
	if display_name == "":
		return
	# Localized format: "%s reached level %d!" per assets/locale/en.csv.
	var text: String = tr("hero_level_up_toast_format") % [display_name, new_level]
	_show_toast(text)


## Sprint 16 — biome progression gate handler. Fires when a gated biome's
## prereq floor first-clears (FloorUnlock.biome_unlocked). Surfaces a cozy
## toast: "Unlocked: <display_name>". Reuses the existing _show_toast path
## (with reduce_motion accessibility branch from S15-S2).
func _on_biome_unlocked(biome_id: String) -> void:
	# Resolve the biome's display_name via DataRegistry. Defensive: skip the
	# toast if the registry can't resolve (data drift between save and load).
	var biome: Variant = DataRegistry.resolve("biomes", biome_id)
	if biome == null:
		return
	var display_name: String = String(biome.get("display_name"))
	if display_name == "":
		return
	_show_toast("Unlocked: %s" % display_name)


## HeroCard tap handler. Per GDD #22 AC-22-01: instantiate Hero Detail modal
## scene, call set_target_hero(instance_id), then SceneManager.show_modal(modal).
##
## Gated on SceneManager.state — if a modal is already active (PAUSED state),
## ignore the tap per GDD #22 §"Rapid HeroCard taps" resolution.
func _on_hero_card_pressed(instance_id: int) -> void:
	if SceneManager.state == SceneManager.State.PAUSED:
		return
	var modal: Control = HeroDetailModalScene.instantiate() as Control
	if modal == null:
		push_error("[GuildHall] Failed to instantiate hero_detail_modal scene")
		return
	if modal.has_method("set_target_hero"):
		modal.set_target_hero(instance_id)
	# S14-M6: SceneManager.show_modal auto-calls modal.on_enter() after add_child,
	# matching the request_screen lifecycle contract. Hero Detail's on_enter is
	# where _render_all populates labels with real hero data.
	SceneManager.show_modal(modal)


## Opens the Settings overlay per GDD #30 AC-30-01. Gated on
## OfflineProgressionEngine.is_replay_in_flight (GDD #30 §E.6) so the player
## cannot open Settings mid-replay (would conflict with the replay modal slot).
func _on_settings_gear_pressed() -> void:
	if OfflineProgressionEngine.is_replay_in_flight():
		return
	SceneManager.push_overlay("settings", false)
