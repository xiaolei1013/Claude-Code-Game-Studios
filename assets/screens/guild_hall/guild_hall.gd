## Guild Hall — first-launch landing screen (placeholder, with smoke nav).
##
## Sprint 8 S8-M4 hotfix: added a "Go to Dispatch" button so the manual smoke
## flow (Guild Hall → FormationAssignment → DungeonRunView → MainMenu) can be
## walked end-to-end without dev-console intervention. Sprint 9+ replaces this
## placeholder with the real Guild Hall content.
##
## Sprint 21+ Prestige V1.0 / Story 3 UI (Slice B): adds the
## "Hall of Retired Heroes" content as a Retired tab on the RosterPanel.
##
## Sprint 23 S23-M1: hall_of_retired_heroes retired as a standalone screen.
## Its title + multiplier + retired-hero card list now lives inside the
## Retired tab of this screen's RosterPanel TabContainer. Registry shrinks
## 7 → 6. Tab labels are localized at runtime in on_enter.
extends Screen

@onready var _dispatch_nav_button: Button = $DispatchNavButton
@onready var _toast_label: Label = $ToastLabel
@onready var _gold_counter: Label = $GoldCounter
@onready var _recruit_nav_button: Button = $RecruitNavButton
@onready var _roster_tabs: TabContainer = $RosterPanel/RosterTabs
@onready var _roster_list: VBoxContainer = $RosterPanel/RosterTabs/Active/RosterScroll/RosterList
@onready var _hall_title_label: Label = $RosterPanel/RosterTabs/Retired/HallTitleLabel
@onready var _multiplier_label: Label = $RosterPanel/RosterTabs/Retired/MultiplierLabel
@onready var _retired_card_list: VBoxContainer = $RosterPanel/RosterTabs/Retired/RetiredScroll/RetiredCardList
@onready var _settings_gear_button: Button = $SettingsGearButton
# Sprint 19 S19-M3 — HD-2D pipeline background layer (GDD #26 + ADR-0019).
# Set to the tavern preset on on_enter so the warm-amber backdrop renders
# under the UI + tilt-shift + warm-lantern composition.
# Typed as ColorRect (BiomeBackground's base class) because the `class_name
# BiomeBackground` global registration is not guaranteed at script-parse time
# in Godot 4.6 — the script registry can be cold-loaded after this file's
# parse. Method calls (set_biome) dispatch dynamically and resolve correctly.
@onready var _biome_background: ColorRect = $BiomeBackground

# Sprint 20 S20-M5 — Synergy badge per UX-GH-09 + interaction-patterns #11
# (Conditional Strip). Shows the active class synergy when the player's
# current formation has one; hidden otherwise. Reads from FormationAssignment
# .detect_active_synergy() on on_enter + on roster signal changes.
@onready var _synergy_badge: PanelContainer = $SynergyBadge
@onready var _synergy_label: Label = $SynergyBadge/SynergyLabel

const HeroDetailModalScene: PackedScene = preload(
	"res://assets/screens/hero_detail/hero_detail_modal.tscn"
)
const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")

# Prestige completion toast — fades over 4.0s matching the
# formation_assignment + Recruitment toast pattern (GDD #21 §G).
const TOAST_FADE_DURATION_SEC: float = 4.0
var _toast_tween: Tween = null

# ---------------------------------------------------------------------------
# Lantern Guild mock wireframe (feat/ui-wireframe-core-loop) — state.
# Greybox 3-column Hall built additively over the existing nodes. See the
# "mock wireframe" section at the bottom of this file.
# ---------------------------------------------------------------------------
const WireframeKitScript = preload("res://src/ui/wireframe_kit.gd")
const _WIRE_Z: int = 2          # draw above WarmLanternOverlay (z=1): greybox stays neutral
const _TOPBAR_H: float = 52.0
const _COL_GAP: float = 14.0
const _LEFT_W: float = 340.0
const _RIGHT_W: float = 360.0
const _CONTENT_TOP: float = 60.0
const _FOOTER_H: float = 56.0

var _wire_built: bool = false
var _runs_body: VBoxContainer = null
var _map_body: VBoxContainer = null
var _lantern_button: Button = null
var _float_layer: Control = null


func on_enter() -> void:
	if _dispatch_nav_button == null:
		push_error("[GuildHall] _dispatch_nav_button is NULL — @onready did not resolve. Check .tscn node name 'DispatchNavButton'.")
		return

	# Sprint 19 S19-M3 — Guild Hall renders the tavern preset (warm amber wood
	# baseline). Per GDD #26 §C.2 BiomeBackground node contract; ADR-0019
	# §Decision 3 programmatic-placeholder strategy.
	if _biome_background != null:
		_biome_background.set_biome("guild_hall_tavern")
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

	# Sprint 20 S20-M5 — refresh synergy badge per current formation.
	# Re-evaluates on each roster change since recruits / removals / level-ups
	# don't change the formation but the player may have returned from
	# Formation Assignment with a different lineup.
	_refresh_synergy_badge()
	# Sprint 16 — biome progression gate. FloorUnlock emits biome_unlocked
	# when a gated biome's prereq floor first-clears (e.g. clearing
	# frostmire_f5 unlocks ember_wastes). Guild Hall surfaces a cozy toast.
	if FloorUnlock.has_signal("biome_unlocked") and not FloorUnlock.biome_unlocked.is_connected(_on_biome_unlocked):
		FloorUnlock.biome_unlocked.connect(_on_biome_unlocked)

	if _settings_gear_button != null:
		if not _settings_gear_button.pressed.is_connected(_on_settings_gear_pressed):
			_settings_gear_button.pressed.connect(_on_settings_gear_pressed)

	# Sprint 23 S23-M1: Retired tab content (replacing the standalone
	# hall_of_retired_heroes screen). Localized tab titles + Hall title
	# label + initial multiplier + card list render. Subscribe to
	# prestige_completed_signal so a freshly-prestiged hero flows into
	# the Retired tab content without a tab switch.
	if _roster_tabs != null:
		_roster_tabs.set_tab_title(0, tr("guild_hall_roster_tab_active"))
		_roster_tabs.set_tab_title(1, tr("guild_hall_roster_tab_retired"))
	if _hall_title_label != null:
		_hall_title_label.text = tr("hall_of_retired_heroes_title")
	if not HeroRoster.prestige_completed_signal.is_connected(_on_prestige_completed):
		HeroRoster.prestige_completed_signal.connect(_on_prestige_completed)
	_refresh_retired_tab()

	# Lantern Guild mock wireframe (feat/ui-wireframe-core-loop): build the
	# greybox 3-column Hall once, then refresh its data-driven panels each
	# time the player lands here (e.g. returning from a run).
	_build_wireframe_once()
	_refresh_runs_panel()
	_refresh_map_panel()


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
# Retired tab — multiplier badge + retired-hero card list
# (Sprint 23 S23-M1 — content migrated from the retired hall_of_retired_heroes
# standalone screen; lives inside the RosterPanel TabContainer Retired tab.)
# ---------------------------------------------------------------------------

## Refreshes both the multiplier label and the retired card list. Called
## from on_enter and from _on_prestige_completed so the tab stays in sync
## with HeroRoster state without requiring the player to switch tabs.
## Per `prestige-system.md` §F + AC-PR-13.
func _refresh_retired_tab() -> void:
	_refresh_multiplier_label()
	_refresh_retired_card_list()


## Renders the global prestige multiplier as `×N.NN` (2 decimal places)
## per AC-PR-13. `×1.00` is the no-prestige baseline and DOES render
## (the tab is visible even with 0 records — empty-state path).
func _refresh_multiplier_label() -> void:
	if _multiplier_label == null:
		return
	var mult: float = HeroRoster.get_prestige_multiplier()
	_multiplier_label.text = "×%.2f" % mult


## Tears down the current Retired-tab card children and rebuilds from
## `HeroRoster.get_retired_hero_records()`. Each card is a Label whose
## text is `tr("hall_card_metadata_format")` formatted with
## `(display_name, class_id, level_at_retirement, prestige_index)`.
##
## Empty-state: a single placeholder card "No retired heroes yet." per
## locale key `hall_empty_state_placeholder`. Cozy degrade, no error.
func _refresh_retired_card_list() -> void:
	if _retired_card_list == null:
		return
	UIFrameworkScript.clear_children_immediate(_retired_card_list)

	var records: Array = HeroRoster.get_retired_hero_records()
	if records.is_empty():
		var placeholder: Label = Label.new()
		placeholder.text = tr("hall_empty_state_placeholder")
		_retired_card_list.add_child(placeholder)
		return

	for rec_variant: Variant in records:
		var rec: Dictionary = rec_variant
		var card: Label = Label.new()
		card.text = _format_retired_card_text(rec)
		_retired_card_list.add_child(card)


## Formats a single retired-hero record into the writer-locked card
## metadata text via `hall_card_metadata_format`. Defensive: missing
## fields fall back to safe defaults. Format `%s · %s · Lv %d · Retired Day %d`.
func _format_retired_card_text(record: Dictionary) -> String:
	var display_name: String = String(record.get("display_name", "Unknown"))
	var class_id: String = String(record.get("class_id", "?")).capitalize()
	var level: int = int(record.get("level_at_retirement", 0))
	var day: int = int(record.get("prestige_index", 0))
	return tr("hall_card_metadata_format") % [display_name, class_id, level, day]


func _on_prestige_completed(record: Dictionary, _new_count: int) -> void:
	# Refresh the Retired tab so a fresh card is visible the next time
	# the player taps the Retired tab. Active tab is not altered.
	_refresh_retired_tab()
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
# Synergy badge (UX-GH-09 + interaction-patterns #11 Conditional Strip)
# ---------------------------------------------------------------------------

## Computes the active class synergy for the player's current formation and
## shows the SynergyBadge with localized "Display Name: Effect" text. When no
## synergy is active, hides the badge (visible=false). Called from on_enter
## and from roster signal handlers so the badge stays in sync with the live
## state.
##
## The badge is a Conditional Strip per interaction-patterns.md pattern #11:
## visible=false yields no layout impact (the badge's anchor preset places
## it absolutely-positioned in the screen, so hiding has no shifting effect
## on the roster panel or NavBar).
##
## Per design/ux/guild-hall.md UX-GH-09 + design/gdd/class-synergy-system.md
## §C.2. Builds the same formation_snapshot shape that the Formation Assignment
## screen builds (instance_ids + heroes Array[Dictionary] with class_id keys).
func _refresh_synergy_badge() -> void:
	if _synergy_badge == null or _synergy_label == null:
		return

	# Build hero_map from live roster (same pattern as Formation Assignment's
	# _build_formation_snapshot).
	var hero_map: Dictionary = {}
	for hero: Variant in HeroRoster.get_all_heroes():
		hero_map[hero.instance_id] = hero

	# Build formation snapshot in the shape detect_active_synergy expects.
	var heroes: Array[Dictionary] = []
	var slot_count: int = HeroRoster.formation_size()
	for i: int in range(slot_count):
		var sid: int = HeroRoster.get_formation_slot(i)
		var hero_dict: Dictionary = {"instance_id": sid}
		if sid != 0 and hero_map.has(sid):
			hero_dict["class_id"] = str(hero_map[sid].class_id)
		else:
			hero_dict["class_id"] = ""
		heroes.append(hero_dict)

	var synergy_id: String = FormationAssignment.detect_active_synergy(
		{"heroes": heroes}
	)

	if synergy_id == "":
		_synergy_badge.visible = false
		return

	# Render localized "Display Name: Effect" text. Locale keys for both
	# halves resolve via UIFramework helpers (display_name + effect_text)
	# so the locale-key convention lives in one place.
	var display_name: String = UIFrameworkScript.synergy_display_name(synergy_id)
	var effect_text: String = UIFrameworkScript.synergy_effect_text(synergy_id)
	_synergy_label.text = "%s: %s" % [display_name, effect_text]
	_synergy_badge.visible = true


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
	UIFrameworkScript.clear_children_immediate(_roster_list)
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
	# Sprint 20 S20-M5 — apply LedgerRow theme variation per
	# design/ux/interaction-patterns.md pattern #10. Parchment sub-panel
	# register: hairline Slate Ink border at 50% alpha + 2px corner radius
	# + 8px padding. Defined in assets/ui/parchment_theme.tres.
	card.theme_type_variation = &"LedgerRow"

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
	# Sprint 20 S20-M5 — recruit/remove may change formation composition
	# (e.g. removing a hero from a slot via prestige clears that slot).
	# Re-evaluate synergy so the badge stays in sync.
	_refresh_synergy_badge()


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


# Sprint 24 S24-M3: _clear_container_immediate hoisted to
# UIFramework.clear_children_immediate. Call sites updated to use the
# UIFramework helper directly. Local wrapper removed.


# ===========================================================================
# Lantern Guild mock wireframe — greybox 3-column Hall
# (feat/ui-wireframe-core-loop)
#
# Recreates "The Hall" layout from the Lantern Guild Prototype mock
# (Roster · Expeditions+Lantern · Map, with a top bar + event feed) at
# greybox/wireframe fidelity. Built ADDITIVELY: every node the @onready vars
# and tests reference keeps its original path; existing nodes are repositioned
# via anchors and new neutral-grey wireframe siblings are added at z=2 (above
# the WarmLanternOverlay) so the greybox reads as neutral structure.
#
# Real data is wired where cheap (gold, roster, biomes, run state). The lantern
# is the idle-clicker click target; we have NO channel-light economy mechanic
# yet, so its click only spawns wireframe feedback (see the caption under it).
# ===========================================================================

## Sets a Control's four anchors then four offsets in one call.
func _place(node: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, orr: float, ob: float) -> void:
	if node == null:
		return
	node.anchor_left = al
	node.anchor_top = at
	node.anchor_right = ar
	node.anchor_bottom = ab
	node.offset_left = ol
	node.offset_top = ot
	node.offset_right = orr
	node.offset_bottom = ob


func _center_col_left() -> float:
	return _COL_GAP + _LEFT_W + _COL_GAP


func _center_col_right() -> float:
	return -(_COL_GAP + _RIGHT_W + _COL_GAP)


func _build_wireframe_once() -> void:
	if _wire_built:
		return
	_wire_built = true
	_reposition_existing_nodes()
	_build_top_bar()
	_build_runs_panel()
	_build_activity_feed()
	_build_lantern()
	_build_map_panel()
	_build_float_layer()


## Moves the pre-existing .tscn nodes into the mock's 3-column layout. Their
## node paths are unchanged — only anchors/offsets/z. Text + theme variation
## are left alone (identity-header + smoke-flow tests assert on those).
func _reposition_existing_nodes() -> void:
	# top bar: screen title as the left lockup; gold + gear on the right (z=3
	# so they draw above the WireTopBar strip).
	var title: Label = get_node_or_null("ScreenTitleLabel") as Label
	if title != null:
		_place(title, 0, 0, 0, 0, 16.0, 8.0, 360.0, 46.0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.z_index = 3
	if _gold_counter != null:
		_place(_gold_counter, 1, 0, 1, 0, -300.0, 8.0, -64.0, 46.0)
		_gold_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_gold_counter.z_index = 3
	if _settings_gear_button != null:
		_place(_settings_gear_button, 1, 0, 1, 0, -56.0, 9.0, -14.0, 45.0)
		_settings_gear_button.z_index = 3

	# left column: roster panel + recruit footer button. Clear the .tscn's
	# 480px min-size + GROW_BOTH (centered layout) so the panel pins to the
	# left column instead of overflowing off-screen.
	var roster_panel: Control = get_node_or_null("RosterPanel") as Control
	if roster_panel != null:
		roster_panel.custom_minimum_size = Vector2.ZERO
		roster_panel.grow_horizontal = Control.GROW_DIRECTION_END
		roster_panel.grow_vertical = Control.GROW_DIRECTION_END
		_place(roster_panel, 0, 0, 0, 1,
			_COL_GAP, _CONTENT_TOP, _COL_GAP + _LEFT_W, -(_FOOTER_H + _COL_GAP))
		roster_panel.z_index = _WIRE_Z
	if _recruit_nav_button != null:
		_place(_recruit_nav_button, 0, 1, 0, 1,
			_COL_GAP, -(_FOOTER_H + _COL_GAP), _COL_GAP + _LEFT_W, -_COL_GAP)
		_recruit_nav_button.z_index = _WIRE_Z

	# right column: dispatch ("Send Party") footer button. The Map panel built
	# in _build_map_panel fills the column above it.
	if _dispatch_nav_button != null:
		_place(_dispatch_nav_button, 1, 1, 1, 1,
			-(_RIGHT_W + _COL_GAP), -(_FOOTER_H + _COL_GAP), -_COL_GAP, -_COL_GAP)
		_dispatch_nav_button.z_index = _WIRE_Z

	# synergy badge: park it centered just above the lantern. Still hidden by
	# default; on_enter's _refresh_synergy_badge shows it when a synergy is
	# active (visibility is NOT touched here).
	if _synergy_badge != null:
		_place(_synergy_badge, 0.5, 1, 0.5, 1, -220.0, -250.0, 220.0, -214.0)
		_synergy_badge.z_index = _WIRE_Z


## Decorative top-bar strip with the mock's nav tabs + currency-tray
## placeholders. The brand lockup + real gold/gear sit on top of it (z=3).
func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "WireTopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = _WIRE_Z
	bar.add_theme_stylebox_override("panel", WireframeKitScript.stylebox(
		WireframeKitScript.HEADER_FILL, WireframeKitScript.LINE, 1, 0, 0))
	add_child(bar)
	_place(bar, 0, 0, 1, 0, 0.0, 0.0, 0.0, _TOPBAR_H)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var lead: Control = Control.new()
	lead.custom_minimum_size = Vector2(360, 0)
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lead)

	for tab_text: String in ["The Hall", "Codex", "Lantern Shards · 0"]:
		var is_active: bool = tab_text == "The Hall"
		var tab: Label = WireframeKitScript.eyebrow(tab_text,
			WireframeKitScript.ACCENT if is_active else WireframeKitScript.MUTED)
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_theme_font_size_override("font_size", 12)
		row.add_child(tab)

	var grow: Control = Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grow)

	for chip_text: String in ["Gems —", "Keys —"]:
		var chip: Label = WireframeKitScript.eyebrow(chip_text)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)

	var tail: Control = Control.new()       # reserve room for the real gold + gear
	tail.custom_minimum_size = Vector2(300, 0)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tail)


## Center-column top panel: "Expeditions in progress". Our orchestrator is a
## single-run engine, so this honestly shows 0 or 1 run.
func _build_runs_panel() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Expeditions in progress")
	panel.name = "WireRunsPanel"
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 0, 0, 1, 0,
		_center_col_left(), _CONTENT_TOP, _center_col_right(), _CONTENT_TOP + 196.0)
	var dyn: VBoxContainer = VBoxContainer.new()
	dyn.name = "Dyn"
	dyn.add_theme_constant_override("separation", 6)
	WireframeKitScript.body_of(panel).add_child(dyn)
	_runs_body = dyn


func _refresh_runs_panel() -> void:
	if _runs_body == null:
		return
	for c: Node in _runs_body.get_children():
		c.queue_free()
	var snap: Variant = DungeonRunOrchestrator.run_snapshot if DungeonRunOrchestrator != null else null
	if snap == null:
		_runs_body.add_child(WireframeKitScript.caption(
			"The lantern is lit. No one has answered yet.", WireframeKitScript.MUTED))
		return
	var biome_id: String = DungeonRunOrchestrator.get_dispatched_biome_id()
	var floor_i: int = DungeonRunOrchestrator.get_dispatched_floor_index()
	var biome_label: String = biome_id.capitalize()
	if BiomeDungeonDatabase != null:
		biome_label = _biome_display(BiomeDungeonDatabase.get_biome_by_id(biome_id), biome_id)
	_runs_body.add_child(WireframeKitScript.list_tile(
		biome_label, "Floor %d · in progress" % floor_i, "WATCH"))


## Center-column middle panel: the event/activity feed (static flavour lines —
## the live combat log is wired on the Expedition screen).
func _build_activity_feed() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Event log")
	panel.name = "WireActivityFeed"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 0, 0, 1, 1,
		_center_col_left(), _CONTENT_TOP + 208.0, _center_col_right(), -216.0)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)
	for line: String in [
		"The lantern needs trimming.",
		"A draft. Somewhere a door closes.",
		"The party rests four breaths.",
		"A loose stone settles in the wall.",
	]:
		var l: Label = WireframeKitScript.caption("· " + line, WireframeKitScript.MUTED, 12)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(l)


## Center-bottom: the lantern click target. Idle-clicker hero element.
func _build_lantern() -> void:
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.name = "WireLantern"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 8)
	wrap.z_index = _WIRE_Z
	add_child(wrap)
	_place(wrap, 0.5, 1, 0.5, 1, -150.0, -224.0, 150.0, -20.0)

	var cap_top: Label = WireframeKitScript.eyebrow(
		"Channel · click the lantern", WireframeKitScript.ACCENT)
	cap_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(cap_top)

	var center_row: HBoxContainer = HBoxContainer.new()
	center_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(center_row)

	var btn: Button = WireframeKitScript.lantern_button(_on_lantern_pressed)
	center_row.add_child(btn)
	_lantern_button = btn

	var note: Label = WireframeKitScript.caption(
		"Wireframe — click feedback only; channel-light economy TBD",
		WireframeKitScript.MUTED, 10)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(note)


func _on_lantern_pressed() -> void:
	_spawn_lantern_float()


## Spawns a floating "+ light" number near the lantern (the idle-clicker
## feedback). Respects reduce_motion: no travel/fade, snap-hide via a timer.
func _spawn_lantern_float() -> void:
	if _float_layer == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var animate: bool = not (SceneManager != null and SceneManager.reduce_motion)
	WireframeKitScript.spawn_float(
		_float_layer, "+ light",
		Vector2(vp.x * 0.5 - 28.0 + randf_range(-26.0, 26.0), vp.y - 210.0),
		animate)


## Resolves a biome's player-facing name defensively (biomes may carry a
## `display_name`, a localized `display_name_key`, or neither). Mirrors the
## fallback chain in formation_assignment.gd + victory_moment.gd.
func _biome_display(biome: Variant, fallback_id: String) -> String:
	if biome != null and "display_name" in biome:
		var dn: String = String(biome.display_name)
		if dn != "":
			return dn
	if biome != null and "display_name_key" in biome:
		var key: String = String(biome.display_name_key)
		if key != "":
			var localized: String = tr(key)
			if localized != "" and localized != key:
				return localized
	return fallback_id.capitalize()


## Right column: "The Map" — list of playable biomes (real data) with their
## clear progress. Floor/party selection happens in Dispatch (Send Party CTA).
func _build_map_panel() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("The Map")
	panel.name = "WireMapPanel"
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 1, 0, 1, 1,
		-(_RIGHT_W + _COL_GAP), _CONTENT_TOP, -_COL_GAP, -(_FOOTER_H + _COL_GAP))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	WireframeKitScript.body_of(panel).add_child(scroll)
	var dyn: VBoxContainer = VBoxContainer.new()
	dyn.name = "Dyn"
	dyn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dyn.add_theme_constant_override("separation", 6)
	scroll.add_child(dyn)
	_map_body = dyn


func _refresh_map_panel() -> void:
	if _map_body == null:
		return
	for c: Node in _map_body.get_children():
		c.queue_free()
	var biomes: Array = []
	if BiomeDungeonDatabase != null:
		biomes = BiomeDungeonDatabase.get_playable_biomes()
	if biomes.is_empty():
		_map_body.add_child(WireframeKitScript.caption(
			"No dungeons available yet.", WireframeKitScript.MUTED))
	else:
		var shown: int = 0
		for b: Variant in biomes:
			if b == null:
				continue
			var bid: String = String(b.id)
			var bname: String = _biome_display(b, bid)
			var sub: String = "Sealed"
			if FloorUnlock != null and FloorUnlock.is_biome_available(bid):
				sub = "Cleared to floor %d" % FloorUnlock.get_highest_cleared(bid)
			_map_body.add_child(WireframeKitScript.list_tile(bname, sub, ""))
			shown += 1
			if shown >= 6:
				break
	_map_body.add_child(WireframeKitScript.caption(
		"Choose a party and floor in Dispatch ->", WireframeKitScript.MUTED, 11))


## Full-rect input-transparent layer for the lantern's floating numbers.
func _build_float_layer() -> void:
	var layer: Control = WireframeKitScript.float_layer()
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_float_layer = layer
