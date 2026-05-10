## FormationAssignment — Presentation-layer screen for squad picker + Dispatch.
##
## Lets the player assign up to FORMATION_SIZE (3) heroes from their roster to
## the active formation slots, review the floor target, and press Dispatch to
## begin a dungeon run.
##
## Acceptance Criteria (7 ACs from Story 011):
##   AC-1: Roster picker — assign heroes to slots via HeroRoster.set_formation_slot()
##   AC-2: Floor selector — hard-coded forest_reach floor 1 for Sprint 8 VS
##   AC-3: Dispatch — calls DungeonRunOrchestrator.dispatch(formation, floor, biome)
##   AC-4: Validation surfacing — toasts for "empty_formation" / "floor_locked"
##   AC-5: Lifecycle hygiene — on_enter connects, on_exit disconnects ALL signals
##   AC-6: Theme + tap-target compliance — no Color() literals; UIFramework checks
##   AC-7: Routed via SceneManager.request_screen("formation_assignment", CROSS_FADE)
##
## Governing ADRs: ADR-0007 (Screen base class lifecycle), ADR-0008 (UI Framework)
## Story: Story 011 (Sprint 8 S8-M1 DispatchScreen UI)
extends Screen

# ---------------------------------------------------------------------------
# Preload
# ---------------------------------------------------------------------------

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")

# ---------------------------------------------------------------------------
# Private screen state
# ---------------------------------------------------------------------------

## Which formation slot will receive the next hero tap.
## Advances automatically after each successful set_formation_slot call.
var _active_slot_index: int = 0

## Selected biome for dispatch (hard-coded Sprint 8 VS: single target).
## Held as a screen-state field so future multi-biome picker can replace
## the single FloorButton without restructuring the dispatch path.
var _selected_biome_id: String = "forest_reach"

## Selected floor index for dispatch (hard-coded Sprint 8 VS: floor 1).
var _selected_floor: int = 1

## Active toast tween (may be null). Killed on new toast to avoid overlap.
var _toast_tween: Tween = null

# Class Synergy V1.0 Story 4 — UI badge live-preview wiring.
# Per `class-synergy-system.md` §C.4 + §G + AC-CS-17.

## Glow tween duration when a synergy activates (default path; full-motion).
## Per GDD §G `class_synergy_badge_glow_duration_seconds = 0.4` (range 0.1-1.0).
## Reduce-motion path skips the tween entirely (AC-CS-17): badge appears at
## modulate.a = 1.0 instantly with theme variation `class_synergy_badge_active_reduced_motion`.
const SYNERGY_BADGE_GLOW_DURATION_SEC: float = 0.4

## Theme variations per GDD §C.4 visual: animated default, reduce-motion alt.
const SYNERGY_BADGE_VARIATION_ACTIVE: StringName = &"class_synergy_badge_active"
const SYNERGY_BADGE_VARIATION_REDUCED_MOTION: StringName = &"class_synergy_badge_active_reduced_motion"

## Currently-displayed synergy id. Tracks state across refreshes so the glow
## tween + audio cue only re-fire when the synergy ACTUALLY changes (slot
## edits within the same composition multiset don't re-trigger). The audio
## subscriber's 2.0s throttle is a backstop, not the primary de-dup.
var _current_synergy_id: String = ""

## Active synergy badge glow tween (may be null). Killed on re-trigger or
## on_exit to avoid modulating a freed Label.
var _synergy_badge_tween: Tween = null

# ---------------------------------------------------------------------------
# @onready node references (wired to .tscn node names)
# ---------------------------------------------------------------------------

@onready var _header_label: Label = $HeaderLabel
@onready var _roster_list: VBoxContainer = $RosterPanel/RosterScroll/RosterList
@onready var _slots_hbox: HBoxContainer = $FormationPanel/SlotsHBox
@onready var _floor_button: Button = $FloorSelectorPanel/FloorVBox/FloorButton
@onready var _floor_context_label: Label = $FloorSelectorPanel/FloorVBox/FloorContextLabel
@onready var _dispatch_button: Button = $DispatchButton
@onready var _toast_label: Label = $ToastLabel
@onready var _synergy_badge: Label = $SynergyBadge

# ---------------------------------------------------------------------------
# Built-in lifecycle (_ready — tap-target enforcement)
# ---------------------------------------------------------------------------

## Verifies tap-target compliance for all Buttons in debug builds.
## Runs once when the scene is added to the tree, before on_enter().
func _ready() -> void:
	# Apply localized instructional header text once. S9-M1 polish: replaced
	# the generic "Formation" title with an action-oriented prompt so a fresh-eyes
	# player immediately understands the screen purpose without external explanation.
	# Key: formation_assignment_instructional_header → "Send your guild to:"
	_header_label.text = tr("formation_assignment_instructional_header")

	# Floor context label: surface the current target floor name so the player
	# can see where they are dispatching without pressing the floor button.
	# Key: floor_label_forest_reach_1 → "Forest Reach — Floor 1"
	_floor_context_label.text = tr("floor_label_forest_reach_1")

	# Walk all Button descendants and assert the 44×44 tap-target floor.
	# This is defense-in-depth: .tscn already sets custom_minimum_size on each
	# button; this call catches regressions during layout iteration.
	for btn: Variant in find_children("*", "Button", true, false):
		UIFrameworkScript.assert_tap_target_min(btn as Control)

	# S10-M2: apply ParchmentPanel theme variation to the three section panels
	# so they pick up the warmer document framing from parchment_theme.tres
	# (border, padding, warm vignette shadow). STANDARD pattern keeps the
	# default mouse_filter — these panels are interactive containers that
	# should still consume taps that miss their child controls.
	UIFrameworkScript.apply_parchment_panel($RosterPanel)
	UIFrameworkScript.apply_parchment_panel($FormationPanel)
	UIFrameworkScript.apply_parchment_panel($FloorSelectorPanel)

	# S10-M2: touch-feedback pulse on the static .tscn-defined buttons.
	# Wired in _ready (one-time) so re-entry into on_enter doesn't re-wire;
	# UIFramework's meta sentinel makes wire_touch_feedback idempotent anyway.
	UIFrameworkScript.wire_touch_feedback(_dispatch_button)
	UIFrameworkScript.wire_touch_feedback(_floor_button)


# ---------------------------------------------------------------------------
# Screen lifecycle hooks (ADR-0007 — all four MUST be declared)
# ---------------------------------------------------------------------------

## Called by SceneManager after this screen becomes current_screen.
## Connects signals, wires button presses, performs initial render, suppresses focus.
func on_enter() -> void:
	# Cross-system signal connections (mirrored exactly in on_exit).
	HeroRoster.hero_recruited.connect(_on_hero_list_changed)
	HeroRoster.hero_removed.connect(_on_hero_removed)
	DungeonRunOrchestrator.validation_failed.connect(_on_validation_failed)
	# Sprint 8 S8-M4 hotfix: navigate to DungeonRunView when orchestrator
	# successfully advances to ACTIVE_FOREGROUND (post-dispatch). Story 011
	# only invoked dispatch; Story 012 assumed DungeonRunView was already
	# current. The screen-transition wiring on dispatch success was missing.
	DungeonRunOrchestrator.state_changed.connect(_on_orchestrator_state_changed)

	# Static UI button wiring — these nodes are .tscn-defined (not refresh-rebuilt)
	# so we connect them once here, mirroring on_exit. Dynamic hero/slot buttons
	# created in _refresh_*_panel are wired at creation time and freed on refresh.
	if not _dispatch_button.pressed.is_connected(_on_dispatch_pressed):
		_dispatch_button.pressed.connect(_on_dispatch_pressed)
	if not _floor_button.pressed.is_connected(_on_floor_button_pressed):
		_floor_button.pressed.connect(_on_floor_button_pressed)
	# Toast tap-to-dismiss: ToastLabel uses gui_input rather than pressed
	# (Label has no pressed signal). MOUSE_FILTER_STOP enables input capture.
	_toast_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _toast_label.gui_input.is_connected(_on_toast_input):
		_toast_label.gui_input.connect(_on_toast_input)

	# Initial render from current game state.
	_refresh_roster_panel()
	_refresh_formation_panel()

	# Single-focus-mode strategy: suppress keyboard/gamepad focus on all buttons
	# INCLUDING dynamically-created hero buttons from _refresh_roster_panel.
	UIFrameworkScript.suppress_keyboard_focus(self)


## Called by SceneManager BEFORE queue_free. Disconnects all signals.
func on_exit() -> void:
	# Mirror on_enter cross-system connections exactly.
	if HeroRoster.hero_recruited.is_connected(_on_hero_list_changed):
		HeroRoster.hero_recruited.disconnect(_on_hero_list_changed)
	if HeroRoster.hero_removed.is_connected(_on_hero_removed):
		HeroRoster.hero_removed.disconnect(_on_hero_removed)
	if DungeonRunOrchestrator.validation_failed.is_connected(_on_validation_failed):
		DungeonRunOrchestrator.validation_failed.disconnect(_on_validation_failed)
	if DungeonRunOrchestrator.state_changed.is_connected(_on_orchestrator_state_changed):
		DungeonRunOrchestrator.state_changed.disconnect(_on_orchestrator_state_changed)

	# Mirror on_enter button wiring. Static buttons are also freed with the
	# screen, but explicit disconnect documents the lifecycle contract.
	if _dispatch_button != null and _dispatch_button.pressed.is_connected(_on_dispatch_pressed):
		_dispatch_button.pressed.disconnect(_on_dispatch_pressed)
	if _floor_button != null and _floor_button.pressed.is_connected(_on_floor_button_pressed):
		_floor_button.pressed.disconnect(_on_floor_button_pressed)
	if _toast_label != null and _toast_label.gui_input.is_connected(_on_toast_input):
		_toast_label.gui_input.disconnect(_on_toast_input)

	# Kill any in-flight toast tween to avoid modulating a freed node.
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null

	# Kill any in-flight synergy badge glow tween — same reason.
	if _synergy_badge_tween != null and _synergy_badge_tween.is_valid():
		_synergy_badge_tween.kill()
	_synergy_badge_tween = null


## Called by SceneManager when a modal overlay opens on top of this screen.
## No per-screen animations to suspend for Sprint 8 VS.
func on_pause() -> void:
	pass


## Called by SceneManager when the modal overlay closes.
func on_resume() -> void:
	pass


# ---------------------------------------------------------------------------
# Panel refresh helpers
# ---------------------------------------------------------------------------

## Rebuilds the roster picker panel from the live HeroRoster state.
##
## Reads [code]HeroRoster.get_all_heroes(SortMode.BY_CLASS)[/code] for stable
## Sprint 8 ordering. Creates one Button per hero. Clears prior children first
## to avoid duplicates.
##
## Empty-state copy: if roster is empty, shows "Recruit a hero to begin."
## (Sprint 4 first-launch seeds Theron, so this is a defensive edge case.)
##
## Called once in on_enter() and again on hero_recruited / hero_removed.
func _refresh_roster_panel() -> void:
	# Clear existing hero buttons.
	for child: Node in _roster_list.get_children():
		child.queue_free()

	var heroes: Array = HeroRoster.get_all_heroes(HeroRoster.SortMode.BY_CLASS)

	if heroes.is_empty():
		# Empty-state defensive label.
		var lbl: Label = Label.new()
		lbl.text = tr("recruit_a_hero_label")
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		_roster_list.add_child(lbl)
		return

	for hero: Variant in heroes:
		var btn: Button = Button.new()
		# Label format: "<display_name> (<class_id> Lv<level>)"
		btn.text = "%s (%s Lv%d)" % [hero.display_name, hero.class_id, hero.current_level]
		btn.custom_minimum_size = Vector2(120, 44)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		# Bind the hero's instance_id so the closure captures the correct value.
		btn.pressed.connect(_on_hero_button_pressed.bind(hero.instance_id))
		_roster_list.add_child(btn)
		UIFrameworkScript.assert_tap_target_min(btn)
		UIFrameworkScript.wire_touch_feedback(btn)


## Rebuilds the formation slot buttons from the live HeroRoster state.
##
## Reads [code]HeroRoster.formation_size()[/code] (=3) and resolves each slot's
## occupant by building a lookup map from [code]get_all_heroes()[/code].
## Uses "Empty" label or hero display_name per slot.
##
## Called once in on_enter() and after any slot mutation.
func _refresh_formation_panel() -> void:
	# Clear existing slot buttons.
	for child: Node in _slots_hbox.get_children():
		child.queue_free()

	# Build instance_id → display_name lookup from the full hero list.
	var hero_map: Dictionary = {}
	for hero: Variant in HeroRoster.get_all_heroes():
		hero_map[hero.instance_id] = hero.display_name

	var slot_count: int = HeroRoster.formation_size()
	for i: int in range(slot_count):
		var slot_id: int = _get_formation_slot_id(i)
		var btn: Button = Button.new()
		if slot_id == 0 or not hero_map.has(slot_id):
			btn.text = tr("slot_empty_label")
		else:
			btn.text = str(hero_map[slot_id])
		btn.custom_minimum_size = Vector2(180, 80)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_slot_button_pressed.bind(i))
		_slots_hbox.add_child(btn)
		UIFrameworkScript.assert_tap_target_min(btn)
		UIFrameworkScript.wire_touch_feedback(btn)
		# S9-M1 active-slot affordance: add a "Selected" badge Label as a child
		# of the active slot button. MOUSE_FILTER_IGNORE per ADR-0008 §mouse_filter
		# defaults ("decorative TextureRects IGNORE") — taps pass straight through
		# to the parent Button without any intercept risk (canonical choice over PASS
		# for purely-decorative overlays per ADR-0008 §mouse_filter defaults).
		# theme_type_variation = "SelectedSlotButton" allows parchment_theme.tres
		# (S9-S3) to target this variation cleanly without touching every slot.
		if i == _active_slot_index:
			var badge: Label = Label.new()
			badge.name = "SelectedBadge"
			badge.text = tr("slot_selected_badge")
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.theme_type_variation = &"SelectedSlotButton"
			btn.add_child(badge)

	# Class Synergy V1.0 Story 4 — refresh the live-preview badge after every
	# slot mutation. Pure read; safe to call on every refresh per AC-CS-20
	# perf budget (detect_active_synergy is O(1)).
	_refresh_synergy_badge()


## Thin adapter for [code]HeroRoster.get_formation_slot(slot_index)[/code].
## Kept as a private helper so future refactors can substitute the read source
## without touching every callsite in the screen.
func _get_formation_slot_id(slot_index: int) -> int:
	return HeroRoster.get_formation_slot(slot_index)


# ---------------------------------------------------------------------------
# User interaction handlers
# ---------------------------------------------------------------------------

## Handles tapping a formation slot button.
##
## Sets [member _active_slot_index] to [param slot_index] so the next hero-
## button tap writes to this slot. Per Note A in the Story 011 spec: for
## Sprint 8 VS, tapping an occupied slot simply selects it as the write target
## (does NOT auto-clear). Clearing happens implicitly when set_formation_slot
## moves a hero between slots per TR-hero-roster-014 auto-clear behavior.
func _on_slot_button_pressed(slot_index: int) -> void:
	_active_slot_index = slot_index
	# S9-M1: refresh so the "Selected" badge migrates to the newly-active slot.
	# Without this re-render, the active-state visual indicator never moves and
	# the player gets no feedback on slot tap (root cause of S8-M5 confusion).
	_refresh_formation_panel()
	UIFrameworkScript.suppress_keyboard_focus(self)
	# No explicit clear — let auto-clear in set_formation_slot handle multi-slot.


## Handles tapping a hero button in the roster panel.
##
## Calls [code]HeroRoster.set_formation_slot(_active_slot_index, hero_id)[/code].
## On success, advances [member _active_slot_index] to fill successive slots with
## successive taps (progressive fill pattern). Refreshes both panels.
func _on_hero_button_pressed(hero_id: int) -> void:
	var success: bool = HeroRoster.set_formation_slot(_active_slot_index, hero_id)
	if success:
		# Advance active slot cyclically so successive taps fill progressively.
		var slot_count: int = HeroRoster.formation_size()
		_active_slot_index = (_active_slot_index + 1) % slot_count
	_refresh_roster_panel()
	_refresh_formation_panel()
	# Re-suppress focus on any newly-created buttons.
	UIFrameworkScript.suppress_keyboard_focus(self)


## Handles tapping the Floor button. Sprint 8 VS no-op — the floor target is
## hard-coded to forest_reach floor 1 (see [member _selected_biome_id] /
## [member _selected_floor]). Wired so the button tap-feedback fires on input
## per Pillar 1 ("the game responds to me"); future Sprint 9+ work replaces
## this with a multi-floor picker.
func _on_floor_button_pressed() -> void:
	# Defensive: if Sprint 9+ adds a floor picker, route to it here.
	pass


## Handles input on the toast label for tap-to-dismiss.
##
## ToastLabel uses [code]gui_input[/code] (Label has no [code]pressed[/code]
## signal). Any [InputEventMouseButton] with [code]pressed = true[/code] dismisses.
func _on_toast_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_toast()


## Handles pressing the Dispatch button.
##
## Reads the current formation via [code]HeroRoster.get_formation_heroes()[/code]
## and delegates entirely to [code]DungeonRunOrchestrator.dispatch()[/code].
## Does NOT branch on success/failure — the orchestrator owns state advance
## and emits [signal validation_failed] on error, which this screen handles
## via [method _on_validation_failed]. UI MUST NOT loop-fire (no debounce on
## the UI side; orchestrator owns DISPATCH_DEBOUNCE_MS).
func _on_dispatch_pressed() -> void:
	var formation: Array = HeroRoster.get_formation_heroes()
	DungeonRunOrchestrator.dispatch(formation, _selected_floor, _selected_biome_id)


## Handles [signal DungeonRunOrchestrator.validation_failed].
##
## Maps stable reason strings to localized toast messages. Any unrecognized
## reason emits [code]push_warning[/code] and falls back to a generic error
## toast so the player is never left without feedback.
func _on_validation_failed(reason: String, _payload: Dictionary) -> void:
	match reason:
		"empty_formation":
			_show_toast(tr("dispatch_error_empty_formation"))
		"floor_locked":
			_show_toast(tr("dispatch_error_floor_locked"))
		_:
			push_warning(
				"[FormationAssignment] unhandled validation_failed reason: %s" % reason
			)
			_show_toast(tr("dispatch_error_generic"))


## Handles [signal DungeonRunOrchestrator.state_changed].
##
## Sprint 8 S8-M4 hotfix: navigates to DungeonRunView when orchestrator
## successfully transitions into ACTIVE_FOREGROUND (post-dispatch). This is the
## screen-side completion of the Dispatch button flow — Story 011 invokes
## dispatch, the orchestrator validates, and on success this handler fires the
## scene transition. Validation failures fire [signal validation_failed] instead
## (handled by [method _on_validation_failed]); the screen stays put on failure.
##
## Per ADR-0007 §D.1, dungeon_run_view enter uses FADE_TO_BLACK (300 ms),
## which also emits scene_boundary_persist for the boundary save (TR-scene-manager-015).
func _on_orchestrator_state_changed(new_state: int, _old_state: int) -> void:
	if new_state == DungeonRunStateScript.State.ACTIVE_FOREGROUND:
		SceneManager.request_screen("dungeon_run_view", SceneManager.TransitionType.FADE_TO_BLACK)


## Signal relay: hero list changed on recruitment.
## Thin adapter from typed signal to the shared refresh.
func _on_hero_list_changed(_instance: RefCounted) -> void:
	_refresh_roster_panel()
	_refresh_formation_panel()
	UIFrameworkScript.suppress_keyboard_focus(self)


## Signal relay: hero removed from roster.
func _on_hero_removed(_instance_id: int, _class_id: String, _display_name: String) -> void:
	_refresh_roster_panel()
	_refresh_formation_panel()
	UIFrameworkScript.suppress_keyboard_focus(self)


# ---------------------------------------------------------------------------
# Toast helpers
# ---------------------------------------------------------------------------

## Shows a toast notification with [param text] for up to 4 seconds.
##
## Makes [member _toast_label] visible, animates its [code]modulate.a[/code]
## from 1.0 → 0.0 over 4 seconds, then hides the label on tween_finished.
##
## Kills any existing in-flight toast tween before starting a new one to
## prevent two toasts animating simultaneously on the same label.
##
## Note: [member _toast_tween] is created on this screen node which inherits
## [code]PROCESS_MODE_PAUSABLE[/code] from ScreenContainer (ADR-0007 Risks Note 1).
## If the Settings overlay opens mid-toast, the tween freezes — acceptable for
## Sprint 8 VS. To keep it running during modal pause, create the tween from a
## PROCESS_MODE_ALWAYS ancestor instead.
func _show_toast(text: String) -> void:
	if _toast_label == null:
		push_warning("[FormationAssignment] _show_toast: _toast_label is null")
		return

	# Kill any prior toast tween.
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null

	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_label.visible = true

	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 4.0)
	_toast_tween.finished.connect(_dismiss_toast, CONNECT_ONE_SHOT)


## Hides the toast label immediately (called by tween_finished or tap-to-dismiss).
func _dismiss_toast() -> void:
	if _toast_label != null:
		_toast_label.visible = false
		_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null


# ---------------------------------------------------------------------------
# Class Synergy V1.0 Story 4 — UI badge live-preview wiring
# Per `class-synergy-system.md` §C.4 visual + §C.2 detection-timing
# + AC-CS-17 reduce-motion variant + AC-CS-15 localized strings.
# ---------------------------------------------------------------------------

## Re-evaluates the active synergy from the current formation composition,
## updates the badge label + visibility, and (only when synergy CHANGES)
## fires the audio chime signal + glow tween.
##
## Called from [method _refresh_formation_panel] after every slot mutation.
## Pure read against [code]HeroRoster.get_formation_slot[/code]; the
## detection function is O(1).
##
## State de-dup via [member _current_synergy_id]: rapid slot toggles within
## the same composition multiset (e.g., swapping two warriors between slots
## while a 3-warrior synergy is active) do NOT re-trigger the glow tween or
## audio chime. The audio subscriber's 2.0s throttle is a backstop against
## edge cases, not the primary de-dup.
func _refresh_synergy_badge() -> void:
	if _synergy_badge == null:
		return

	var snapshot: Dictionary = _build_formation_snapshot()
	var synergy_id: String = FormationAssignment.detect_active_synergy(snapshot)

	# State de-dup: only re-render + re-fire signal when synergy CHANGES.
	if synergy_id == _current_synergy_id:
		return
	_current_synergy_id = synergy_id

	# Hide path: synergy went away (composition no longer matches a synergy).
	if synergy_id == "":
		_kill_synergy_badge_tween()
		_synergy_badge.visible = false
		_synergy_badge.modulate.a = 1.0
		return

	# Show path: render localized "Display Name: Effect" text.
	# Both keys exist in en.csv per Sprint 21 S21-S2 (AC-CS-15).
	var display_name: String = tr("class_synergy_badge_" + synergy_id)
	var effect_text: String = tr("class_synergy_effect_" + synergy_id)
	_synergy_badge.text = "%s: %s" % [display_name, effect_text]

	# Theme variation per AC-CS-17: animated default vs reduce-motion variant.
	# Both variants render at modulate.a = 1.0 once visible; the difference
	# is whether we tween the alpha from 0 → 1 (full motion) or jump to 1
	# instantly (reduce motion).
	_kill_synergy_badge_tween()
	if _is_reduce_motion_enabled():
		_synergy_badge.theme_type_variation = SYNERGY_BADGE_VARIATION_REDUCED_MOTION
		_synergy_badge.modulate.a = 1.0
		_synergy_badge.visible = true
	else:
		_synergy_badge.theme_type_variation = SYNERGY_BADGE_VARIATION_ACTIVE
		_synergy_badge.modulate.a = 0.0
		_synergy_badge.visible = true
		_synergy_badge_tween = create_tween()
		_synergy_badge_tween.tween_property(
			_synergy_badge, "modulate:a", 1.0, SYNERGY_BADGE_GLOW_DURATION_SEC
		)

	# Notify the audio path. notify_synergy_detected is a no-op for "" so
	# the empty-synergy path above never reaches this line.
	FormationAssignment.notify_synergy_detected(synergy_id)


## Builds the formation snapshot Dictionary for
## [method FormationAssignment.detect_active_synergy] using the live
## HeroRoster slot map.
##
## Provides BOTH [code]instance_ids[/code] AND [code]heroes[/code] keys
## matching the production pattern in
## [code]DungeonRunOrchestrator.snapshot_formation_for_run[/code]. The
## detection function checks the heroes path first; the instance_ids
## path is the documented fallback (currently calls a non-existent
## [code]HeroRoster.get_hero[/code] — providing heroes avoids that
## dead-code path entirely).
##
## Slots with id 0 (empty) yield a hero dict with empty class_id; the
## resolver returns "" when any slot's class_id is empty per AC-CS-05.
func _build_formation_snapshot() -> Dictionary:
	var instance_ids: Array[int] = []
	var heroes: Array[Dictionary] = []

	# Build instance_id → HeroInstance lookup from the live roster (same
	# pattern as _refresh_formation_panel uses for display_name lookup).
	var hero_map: Dictionary = {}
	for hero: Variant in HeroRoster.get_all_heroes():
		hero_map[hero.instance_id] = hero

	var slot_count: int = HeroRoster.formation_size()
	for i: int in range(slot_count):
		var sid: int = HeroRoster.get_formation_slot(i)
		instance_ids.append(sid)
		var hero_dict: Dictionary = {"instance_id": sid}
		if sid != 0 and hero_map.has(sid):
			hero_dict["class_id"] = str(hero_map[sid].class_id)
		else:
			hero_dict["class_id"] = ""
		heroes.append(hero_dict)

	return {"instance_ids": instance_ids, "heroes": heroes}


## Reads [code]SceneManager.reduce_motion[/code] defensively. Test envs
## without the SceneManager autoload registered get the false default
## (full-motion). Mirrors the canonical pattern in
## [code]hero_detail_modal.gd::_is_reduce_motion_enabled[/code].
func _is_reduce_motion_enabled() -> bool:
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm == null:
		return false
	if not ("reduce_motion" in sm):
		return false
	return bool(sm.get("reduce_motion"))


## Kills any in-flight synergy badge glow tween. Idempotent.
func _kill_synergy_badge_tween() -> void:
	if _synergy_badge_tween != null and _synergy_badge_tween.is_valid():
		_synergy_badge_tween.kill()
	_synergy_badge_tween = null
