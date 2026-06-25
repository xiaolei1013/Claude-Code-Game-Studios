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
# S28-S1 display icons (authored PR #226). The matchup resolver is the SAME one
# DungeonRunOrchestrator uses to award the 1.5×/0.7× per-kill gold multiplier,
# so the floor-hint icon can never diverge from the throughput the player earns.
const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
# Role icons — only warrior/mage/rogue are authored (DESIGN.md "Required MVP
# icon set"); the other four classes degrade to no icon (see _class_icon_for).
const ICON_CLASS_WARRIOR: Texture2D = preload("res://assets/art/ui/icons/class_warrior.png")
const ICON_CLASS_MAGE: Texture2D = preload("res://assets/art/ui/icons/class_mage.png")
const ICON_CLASS_ROGUE: Texture2D = preload("res://assets/art/ui/icons/class_rogue.png")
# Matchup-state icons keyed off MatchupResult.effectiveness_label
# ("Strong" → advantage, "Even" → neutral, "Weak" → disadvantage).
const ICON_MATCHUP_ADVANTAGE: Texture2D = preload("res://assets/art/ui/icons/matchup_advantage.png")
const ICON_MATCHUP_NEUTRAL: Texture2D = preload("res://assets/art/ui/icons/matchup_neutral.png")
const ICON_MATCHUP_DISADVANTAGE: Texture2D = preload("res://assets/art/ui/icons/matchup_disadvantage.png")

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
# Sprint 22 S22-M3: BiomeBackground at z=-1 (cozy tavern preset by default).
@onready var _biome_background: ColorRect = $BiomeBackground
# Sprint 22 S22-M4: GoldCounter on the Dispatch screen so the player can
# see their balance while planning recruits + biome choice. Updates on
# Economy.gold_changed signal.
@onready var _gold_counter: Label = $GoldCounter
@onready var _slots_hbox: HBoxContainer = $FormationPanel/FormationVBox/SlotsHBox
# Sprint 23 S23-N2 — always-visible synergy preview label above the slot row.
# Distinct from SynergyBadge: this is the passive "what would this team get?"
# read; SynergyBadge stays as the cozy detection-moment glow.
@onready var _synergy_preview_label: Label = $FormationPanel/FormationVBox/SynergyPreviewLabel
@onready var _floor_button: Button = $FloorSelectorPanel/FloorVBox/FloorButton
@onready var _floor_context_label: Label = $FloorSelectorPanel/FloorVBox/FloorContextLabel
@onready var _dispatch_button: Button = $DispatchButton
@onready var _toast_label: Label = $ToastLabel
@onready var _synergy_badge: Label = $SynergyBadge
@onready var _back_button: Button = $BackButton
# S15-M2 — mid-run reassignment confirmation dialog (AC-FA-13).
@onready var _reassign_confirm_root: Control = $MidRunReassignConfirmation
@onready var _reassign_confirm_button: Button = $MidRunReassignConfirmation/ConfirmPanel/ConfirmContent/ConfirmButtonRow/ConfirmButton
@onready var _reassign_cancel_button: Button = $MidRunReassignConfirmation/ConfirmPanel/ConfirmContent/ConfirmButtonRow/CancelButton

# S22-M2 — Floor Picker overlay (folded from retired matchup_assignment screen).
# Hidden by default; shown when player taps FloorButton; closed on Cancel or
# Select. Cancel preserves prior target; Select commits via
# FormationAssignment.set_target then refreshes FloorContextLabel.
@onready var _floor_picker_root: Control = $FloorPickerOverlay
@onready var _floor_picker_biome_vbox: VBoxContainer = $FloorPickerOverlay/PickerPanel/PickerContent/PickerScroll/PickerBiomeVBox
@onready var _floor_picker_cancel_button: Button = $FloorPickerOverlay/PickerPanel/PickerContent/PickerHeader/PickerCancelButton
@onready var _floor_picker_select_button: Button = $FloorPickerOverlay/PickerPanel/PickerContent/PickerSelectButton

# Formation Presets (GDD #33, PR #2) — PresetsRow + the two confirm modals.
# Wire to the merged FormationAssignment public API only (save_preset /
# recall_preset / delete_preset / get_presets + config accessors); NEVER touch
# the private _presets/_next_preset_id (AC-FP-12 CI grep would fail).
@onready var _presets_panel: PanelContainer = $PresetsPanel
@onready var _preset_dropdown: OptionButton = $PresetsPanel/PresetsVBox/PresetsRow/PresetDropdown
@onready var _preset_recall_button: Button = $PresetsPanel/PresetsVBox/PresetsRow/PresetRecallButton
@onready var _preset_save_button: Button = $PresetsPanel/PresetsVBox/PresetsRow/PresetSaveButton
@onready var _preset_delete_button: Button = $PresetsPanel/PresetsVBox/PresetsRow/PresetDeleteButton
@onready var _preset_save_modal: Control = $PresetSaveModal
@onready var _preset_name_line_edit: LineEdit = $PresetSaveModal/SavePanel/SaveContent/PresetNameLineEdit
@onready var _preset_save_confirm_button: Button = $PresetSaveModal/SavePanel/SaveContent/SaveButtonRow/SaveConfirmButton
@onready var _preset_save_cancel_button: Button = $PresetSaveModal/SavePanel/SaveContent/SaveButtonRow/SaveCancelButton
@onready var _preset_delete_modal: Control = $PresetDeleteModal
@onready var _preset_delete_confirm_button: Button = $PresetDeleteModal/DeletePanel/DeleteContent/DeleteButtonRow/DeleteConfirmButton
@onready var _preset_delete_cancel_button: Button = $PresetDeleteModal/DeletePanel/DeleteContent/DeleteButtonRow/DeleteCancelButton

# Floor Picker cached state — built in _show_floor_picker from DataRegistry.
var _fp_biomes: Array[Resource] = []
var _fp_floors_by_biome: Dictionary = {}  # biome_id (String) → Array[Resource] sorted by floor_index

# Currently-selected target inside the Floor Picker. Distinct from
# FormationAssignment.get_target() — only commits to that on Select press.
var _fp_selected_biome_id: String = ""
var _fp_selected_floor_index: int = 0

# S28-S1 — per-floor matchup hint label. Created once in _show_floor_picker()
# as a sibling of PickerSelectButton inside PickerContent. Null until the
# picker has been opened for the first time. Visible = false when no
# recommendation is available for the selected floor.
var _floor_recommendation_label: Label = null

# S28-S1 — decorative 3-state matchup icon pinned to the right edge of
# FloorRecommendationLabel. Additive CHILD of the label (never reparents the
# label into a new container — that would break the FloorRecommendationLabel
# hard-path the tests/layout bind to per the screen-node-hard-path rule).
# MOUSE_FILTER_IGNORE so it can never steal a tap from the Select button
# beneath it. Null until the picker is opened for the first time.
var _floor_matchup_icon: TextureRect = null

# ---------------------------------------------------------------------------
# AC-FA-13 (S15-M2) — Mid-run reassignment confirm dialog gating
# ---------------------------------------------------------------------------

## Per formation-assignment-system.md §G.1: gates the confirm dialog when
## a hero-button tap arrives while DungeonRunOrchestrator.state is
## ACTIVE_FOREGROUND or OFFLINE_REPLAY. The dialog warns the player that
## confirming will end the current run (per ADR-0001 + §C.3 — the
## Orchestrator's _on_formation_reassigned handler ends + restarts the run
## on formation_reassignment_committed).
##
## Default true (cozy default — surface the consequence). false disables the
## dialog and commits immediately; reserved for QA / smoke-test contexts.
##
## GDD §G Tuning Knobs: lives in scene_manager_config.tres or a screen-
## config equivalent (future polish). For now, owned by the screen as a
## const — the contract is "the screen reads this and gates commit()",
## independent of where it's stored.
const MID_RUN_REASSIGN_WARNING_ENABLED: bool = true

## When a tap-during-active-run is deferred for confirmation, the screen
## stashes the hero_id + active_slot_index here. _on_reassign_confirm_pressed
## consumes them; _on_reassign_cancel_pressed clears them.
var _pending_reassign_hero_id: int = 0
var _pending_reassign_slot_index: int = -1

## GDD #33 (Formation Presets, PR #2): the dropdown's currently-selected preset
## id. 0 == the "(none)" placeholder. Drives Recall/Delete button visibility and
## is the preset Recall/Delete act upon.
var _selected_preset_id: int = 0

## When a Recall is deferred for mid-run confirmation (§C.7 / AC-FP-11), the
## resolved positional formation (length == formation_size(), HeroInstance-or-null
## per slot) is stashed here. A NON-EMPTY array means a recall is pending — the
## reassign confirm/cancel handlers branch on this BEFORE the single-hero
## _pending_reassign_* path. The two pending states are never both set.
var _pending_recall_formation: Array[HeroInstance] = []

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

	# Sprint 22 S22-M3: render the cozy tavern BiomeBackground. The dispatch
	# screen is a guild-side activity (planning the run); player isn't in a
	# dungeon yet, so tavern reinforces "you are home, choosing where to go."
	if _biome_background != null:
		_biome_background.set_biome("guild_hall_tavern")

	# Sprint 22 S22-M4: GoldCounter — initial render + subscribe to
	# gold_changed for live updates (player may recruit or trigger refresh
	# from this screen and gold mutates accordingly).
	if _gold_counter != null:
		_refresh_gold_counter()
		if not Economy.gold_changed.is_connected(_on_gold_changed):
			Economy.gold_changed.connect(_on_gold_changed)

	# Apply any pending matchup target the player set via the in-screen
	# FloorPicker overlay (S22-M2 fold; previously the matchup_assignment
	# screen per S15-N1 contract). Empty target → keep the cold-launch
	# defaults.
	var target: Dictionary = FormationAssignment.get_target()
	if not target.is_empty():
		var t_biome: String = String(target.get("biome_id", ""))
		var t_floor: int = int(target.get("floor_index", 0))
		if t_biome != "" and t_floor >= 1:
			_selected_biome_id = t_biome
			_selected_floor = t_floor

	_refresh_floor_context_label()

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
	UIFrameworkScript.wire_touch_feedback(_back_button)

	# GDD #33 (Formation Presets, PR #2): parchment framing on the presets panel +
	# touch-feedback pulses on the seven static preset/modal buttons. Wired once in
	# _ready (these are .tscn-defined, not refresh-rebuilt); wire_touch_feedback is
	# idempotent via its meta sentinel. The name LineEdit deliberately gets no pulse.
	UIFrameworkScript.apply_parchment_panel($PresetsPanel)
	UIFrameworkScript.wire_touch_feedback(_preset_recall_button)
	UIFrameworkScript.wire_touch_feedback(_preset_save_button)
	UIFrameworkScript.wire_touch_feedback(_preset_delete_button)
	UIFrameworkScript.wire_touch_feedback(_preset_save_confirm_button)
	UIFrameworkScript.wire_touch_feedback(_preset_save_cancel_button)
	UIFrameworkScript.wire_touch_feedback(_preset_delete_confirm_button)
	UIFrameworkScript.wire_touch_feedback(_preset_delete_cancel_button)

	# i18n (PR2): wire scene-baked static strings that the .tscn scaffolds but
	# the .gd does not otherwise overwrite at runtime. All keys exist in en.csv
	# with byte-identical values so English output is unchanged.

	# BackButton ("← Guild Hall") — shared key reused across screens.
	_back_button.text = tr("back_to_guild_hall_button")

	# DispatchButton ("Dispatch") — static label, not runtime-overwritten.
	_dispatch_button.text = tr("dispatch_button")

	# PresetsPanel title label ("Saved Formations").
	var _presets_title_label: Label = $PresetsPanel/PresetsVBox/PresetsTitleLabel as Label
	if _presets_title_label != null:
		_presets_title_label.text = tr("formation_presets_panel_title")

	# PresetsRow buttons: Recall / Save / Delete.
	_preset_recall_button.text = tr("formation_presets_recall_button")
	_preset_save_button.text = tr("formation_presets_save_button")
	_preset_delete_button.text = tr("formation_presets_delete_button")

	# Mid-run confirm modal: body label, Confirm button ("End Run & Change"),
	# Cancel button.
	var _confirm_body: Label = $MidRunReassignConfirmation/ConfirmPanel/ConfirmContent/ConfirmBodyLabel as Label
	if _confirm_body != null:
		_confirm_body.text = tr("formation_assignment_mid_run_confirm_body")
	_reassign_confirm_button.text = tr("formation_assignment_end_run_confirm_button")
	_reassign_cancel_button.text = tr("formation_assignment_cancel_button")

	# Floor Picker header: Cancel button ("← Cancel") and title label
	# ("Choose Your Run"). PickerSelectButton text is runtime-set by
	# _select_floor_in_picker; do NOT wire it here.
	_floor_picker_cancel_button.text = tr("formation_assignment_picker_cancel_button")
	var _picker_title: Label = $FloorPickerOverlay/PickerPanel/PickerContent/PickerHeader/PickerTitleLabel as Label
	if _picker_title != null:
		_picker_title.text = tr("formation_assignment_picker_title")

	# Preset Save modal: title label ("Name this formation"), LineEdit
	# placeholder ("My formation"), Save confirm button, Cancel button.
	var _save_title: Label = $PresetSaveModal/SavePanel/SaveContent/SaveTitleLabel as Label
	if _save_title != null:
		_save_title.text = tr("formation_presets_save_modal_title")
	if _preset_name_line_edit != null:
		_preset_name_line_edit.placeholder_text = tr("formation_presets_name_placeholder")
	_preset_save_confirm_button.text = tr("formation_presets_save_button")
	_preset_save_cancel_button.text = tr("formation_assignment_cancel_button")

	# Preset Delete modal: body label, Delete confirm button, Cancel button.
	var _delete_body: Label = $PresetDeleteModal/DeletePanel/DeleteContent/DeleteBodyLabel as Label
	if _delete_body != null:
		_delete_body.text = tr("formation_presets_delete_confirm_body")
	_preset_delete_confirm_button.text = tr("formation_presets_delete_button")
	_preset_delete_cancel_button.text = tr("formation_assignment_cancel_button")


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
	# GDD #34 Phase 3 (Defeat & Injury / ADR-0021): re-render roster + formation
	# marks the moment a hero is injured or recovers, so the player sees the fade
	# + badge update live without leaving the screen (guard idempotent — the
	# signal is autoload-scoped and connecting twice would double-refresh).
	if not HeroRoster.heroes_injured.is_connected(_on_heroes_injured):
		HeroRoster.heroes_injured.connect(_on_heroes_injured)

	# Static UI button wiring — these nodes are .tscn-defined (not refresh-rebuilt)
	# so we connect them once here, mirroring on_exit. Dynamic hero/slot buttons
	# created in _refresh_*_panel are wired at creation time and freed on refresh.
	if not _dispatch_button.pressed.is_connected(_on_dispatch_pressed):
		_dispatch_button.pressed.connect(_on_dispatch_pressed)
	if not _floor_button.pressed.is_connected(_on_floor_button_pressed):
		_floor_button.pressed.connect(_on_floor_button_pressed)
	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	# S15-M2: confirm dialog button wiring (idempotent — buttons are static).
	if not _reassign_confirm_button.pressed.is_connected(_on_reassign_confirm_pressed):
		_reassign_confirm_button.pressed.connect(_on_reassign_confirm_pressed)
	if not _reassign_cancel_button.pressed.is_connected(_on_reassign_cancel_pressed):
		_reassign_cancel_button.pressed.connect(_on_reassign_cancel_pressed)
	# Toast tap-to-dismiss: ToastLabel uses gui_input rather than pressed
	# (Label has no pressed signal). MOUSE_FILTER_STOP enables input capture.
	_toast_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _toast_label.gui_input.is_connected(_on_toast_input):
		_toast_label.gui_input.connect(_on_toast_input)
	# S22-M2: Floor Picker overlay buttons (idempotent — buttons are static).
	if not _floor_picker_cancel_button.pressed.is_connected(_on_floor_picker_cancel_pressed):
		_floor_picker_cancel_button.pressed.connect(_on_floor_picker_cancel_pressed)
	if not _floor_picker_select_button.pressed.is_connected(_on_floor_picker_select_pressed):
		_floor_picker_select_button.pressed.connect(_on_floor_picker_select_pressed)
	if not FloorUnlock.floor_unlocked.is_connected(_on_floor_unlocked):
		FloorUnlock.floor_unlocked.connect(_on_floor_unlocked)
	# Newly-unlocked biomes must appear in the floor picker tab list during
	# the same session. The biome_unlocked signal fires when a chained biome's
	# Biome.unlock_after gate clears; the picker rebuilds via _show_floor_picker
	# if currently visible.
	if FloorUnlock.has_signal("biome_unlocked") and not FloorUnlock.biome_unlocked.is_connected(_on_biome_unlocked):
		FloorUnlock.biome_unlocked.connect(_on_biome_unlocked)

	# GDD #33 (Formation Presets, PR #2): subscribe to the preset lifecycle signals
	# + wire the PresetsRow / modal buttons + the dropdown selection. preset_saved
	# and preset_deleted emit SYNCHRONOUSLY from save_preset()/delete_preset(), so
	# the dropdown rebuilds during those calls (carrying the new/cleared selection).
	# There is no preset_recalled subscription — the recall handler owns the mid-run
	# gate flow and refreshes panels itself. All guards idempotent; mirrored in on_exit.
	if not FormationAssignment.preset_saved.is_connected(_on_preset_saved):
		FormationAssignment.preset_saved.connect(_on_preset_saved)
	if not FormationAssignment.preset_deleted.is_connected(_on_preset_deleted):
		FormationAssignment.preset_deleted.connect(_on_preset_deleted)
	if not _preset_dropdown.item_selected.is_connected(_on_preset_selected):
		_preset_dropdown.item_selected.connect(_on_preset_selected)
	if not _preset_recall_button.pressed.is_connected(_on_preset_recall_button_pressed):
		_preset_recall_button.pressed.connect(_on_preset_recall_button_pressed)
	if not _preset_save_button.pressed.is_connected(_on_preset_save_button_pressed):
		_preset_save_button.pressed.connect(_on_preset_save_button_pressed)
	if not _preset_delete_button.pressed.is_connected(_on_preset_delete_button_pressed):
		_preset_delete_button.pressed.connect(_on_preset_delete_button_pressed)
	if not _preset_save_confirm_button.pressed.is_connected(_on_preset_save_confirm_pressed):
		_preset_save_confirm_button.pressed.connect(_on_preset_save_confirm_pressed)
	if not _preset_save_cancel_button.pressed.is_connected(_on_preset_save_cancel_pressed):
		_preset_save_cancel_button.pressed.connect(_on_preset_save_cancel_pressed)
	if not _preset_delete_confirm_button.pressed.is_connected(_on_preset_delete_confirm_pressed):
		_preset_delete_confirm_button.pressed.connect(_on_preset_delete_confirm_pressed)
	if not _preset_delete_cancel_button.pressed.is_connected(_on_preset_delete_cancel_pressed):
		_preset_delete_cancel_button.pressed.connect(_on_preset_delete_cancel_pressed)

	# Initial render from current game state.
	_refresh_roster_panel()
	_refresh_formation_panel()
	_rebuild_preset_dropdown()

	# S15-M1 (AC-FA-12): fire the read-intent informational signal so any
	# subscribers (currently UI consumers only — DungeonRunOrchestrator
	# ignores per formation-assignment-system.md §C.7) know the player is
	# looking at their formation. Payload is the current formation snapshot.
	var current_formation: Array[HeroInstance] = []
	current_formation.resize(HeroRoster.formation_size())
	for i: int in range(HeroRoster.formation_size()):
		current_formation[i] = HeroRoster.get_hero_by_id(HeroRoster.get_formation_slot(i))
	FormationAssignment.browse(current_formation)

	# Single-focus-mode strategy: suppress keyboard/gamepad focus on all buttons
	# INCLUDING dynamically-created hero buttons from _refresh_roster_panel.
	UIFrameworkScript.suppress_keyboard_focus(self)

	# Lantern Guild mock wireframe (feat/ui-wireframe-core-loop): build the
	# greybox Dispatch layout once, then the real panels above it render live data.
	_build_wireframe_once()


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
	# GDD #34 Phase 3: mirror the heroes_injured subscription.
	if HeroRoster.heroes_injured.is_connected(_on_heroes_injured):
		HeroRoster.heroes_injured.disconnect(_on_heroes_injured)
	# S22-M4: GoldCounter live-update subscription cleanup.
	if Economy.gold_changed.is_connected(_on_gold_changed):
		Economy.gold_changed.disconnect(_on_gold_changed)

	# Mirror on_enter button wiring. Static buttons are also freed with the
	# screen, but explicit disconnect documents the lifecycle contract.
	if _dispatch_button != null and _dispatch_button.pressed.is_connected(_on_dispatch_pressed):
		_dispatch_button.pressed.disconnect(_on_dispatch_pressed)
	if _floor_button != null and _floor_button.pressed.is_connected(_on_floor_button_pressed):
		_floor_button.pressed.disconnect(_on_floor_button_pressed)
	if _back_button != null and _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.disconnect(_on_back_pressed)
	if _toast_label != null and _toast_label.gui_input.is_connected(_on_toast_input):
		_toast_label.gui_input.disconnect(_on_toast_input)
	# S15-M2: mirror confirm-dialog button wiring.
	if _reassign_confirm_button != null and _reassign_confirm_button.pressed.is_connected(_on_reassign_confirm_pressed):
		_reassign_confirm_button.pressed.disconnect(_on_reassign_confirm_pressed)
	if _reassign_cancel_button != null and _reassign_cancel_button.pressed.is_connected(_on_reassign_cancel_pressed):
		_reassign_cancel_button.pressed.disconnect(_on_reassign_cancel_pressed)
	# S22-M2: mirror Floor Picker button wiring + FloorUnlock subscription.
	if _floor_picker_cancel_button != null and _floor_picker_cancel_button.pressed.is_connected(_on_floor_picker_cancel_pressed):
		_floor_picker_cancel_button.pressed.disconnect(_on_floor_picker_cancel_pressed)
	if _floor_picker_select_button != null and _floor_picker_select_button.pressed.is_connected(_on_floor_picker_select_pressed):
		_floor_picker_select_button.pressed.disconnect(_on_floor_picker_select_pressed)
	if FloorUnlock.floor_unlocked.is_connected(_on_floor_unlocked):
		FloorUnlock.floor_unlocked.disconnect(_on_floor_unlocked)
	if FloorUnlock.has_signal("biome_unlocked") and FloorUnlock.biome_unlocked.is_connected(_on_biome_unlocked):
		FloorUnlock.biome_unlocked.disconnect(_on_biome_unlocked)

	# GDD #33 (Formation Presets, PR #2): mirror the preset signal/button wiring.
	if FormationAssignment.preset_saved.is_connected(_on_preset_saved):
		FormationAssignment.preset_saved.disconnect(_on_preset_saved)
	if FormationAssignment.preset_deleted.is_connected(_on_preset_deleted):
		FormationAssignment.preset_deleted.disconnect(_on_preset_deleted)
	if _preset_dropdown != null and _preset_dropdown.item_selected.is_connected(_on_preset_selected):
		_preset_dropdown.item_selected.disconnect(_on_preset_selected)
	if _preset_recall_button != null and _preset_recall_button.pressed.is_connected(_on_preset_recall_button_pressed):
		_preset_recall_button.pressed.disconnect(_on_preset_recall_button_pressed)
	if _preset_save_button != null and _preset_save_button.pressed.is_connected(_on_preset_save_button_pressed):
		_preset_save_button.pressed.disconnect(_on_preset_save_button_pressed)
	if _preset_delete_button != null and _preset_delete_button.pressed.is_connected(_on_preset_delete_button_pressed):
		_preset_delete_button.pressed.disconnect(_on_preset_delete_button_pressed)
	if _preset_save_confirm_button != null and _preset_save_confirm_button.pressed.is_connected(_on_preset_save_confirm_pressed):
		_preset_save_confirm_button.pressed.disconnect(_on_preset_save_confirm_pressed)
	if _preset_save_cancel_button != null and _preset_save_cancel_button.pressed.is_connected(_on_preset_save_cancel_pressed):
		_preset_save_cancel_button.pressed.disconnect(_on_preset_save_cancel_pressed)
	if _preset_delete_confirm_button != null and _preset_delete_confirm_button.pressed.is_connected(_on_preset_delete_confirm_pressed):
		_preset_delete_confirm_button.pressed.disconnect(_on_preset_delete_confirm_pressed)
	if _preset_delete_cancel_button != null and _preset_delete_cancel_button.pressed.is_connected(_on_preset_delete_cancel_pressed):
		_preset_delete_cancel_button.pressed.disconnect(_on_preset_delete_cancel_pressed)

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
	# Clear existing hero buttons. Sprint 24 S24-M3 uses
	# UIFramework.clear_children_immediate to avoid the deferred-queue_free
	# flake surfaced in Sprint 23 S23-M1.
	UIFrameworkScript.clear_children_immediate(_roster_list)

	var heroes: Array = HeroRoster.get_all_heroes(HeroRoster.SortMode.BY_CLASS)

	if heroes.is_empty():
		# Empty-state defensive label.
		var lbl: Label = Label.new()
		lbl.text = tr("recruit_a_hero_label")
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		_roster_list.add_child(lbl)
		return

	# Sprint 17 — build archetype lookup once per refresh. Each hero button
	# now appends "vs <archetype>" so the player can pick heroes against
	# the biome's recommendation (PR #84) without leaving the screen.
	# Continues the matchup awareness chain: biome shows what to bring,
	# Hero Detail confirms a hero's counter, this surface puts the counter
	# on every hero in the dispatch flow.
	var class_to_counter: Dictionary[String, String] = {}
	for class_id: String in HeroClassDatabase.get_all_ids():
		var cls: HeroClass = HeroClassDatabase.get_by_id(class_id)
		if cls == null:
			continue
		var counter: String = String(cls.counter_archetype)
		if counter != "":
			class_to_counter[class_id] = counter

	# GDD #34 Phase 3 — single wall-clock read per refresh for the injury marks below.
	var now_ms: int = TickSystem.now_ms()
	for hero: Variant in heroes:
		var btn: Button = Button.new()
		# Label format: "<display_name> (<class_id> Lv<level> · vs <archetype>)"
		# Falls back to the prior "<name> (<class> Lv<n>)" form when the
		# class has no counter_archetype (data drift defensive path).
		var counter: String = class_to_counter.get(String(hero.class_id), "")
		if counter != "":
			btn.text = UIFrameworkScript.format_localized(
					"formation_assignment_hero_slot_counter_format",
					[hero.display_name, hero.class_id, hero.current_level, counter]
				)
		else:
			btn.text = UIFrameworkScript.format_localized(
					"formation_assignment_hero_slot_format",
					[hero.display_name, hero.class_id, hero.current_level]
				)
		btn.custom_minimum_size = Vector2(120, 44)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		# Sprint 21 S21-M1: apply LedgerRow theme variation (pattern #10 —
		# Guild-Ledger-Entry). Same register as Guild Hall HeroCards so the
		# player reads roster lines consistently across screens.
		btn.theme_type_variation = &"LedgerRow"
		# S28-S1: role icon inline on the card. Button.icon is the idiomatic slot
		# (renders left of the text); the 24×24 art needs no expand_icon. NEAREST
		# keeps the pixel edges crisp. Iconless classes leave btn.icon null so the
		# card stays text-only (graceful degradation, not a placeholder glyph).
		var class_icon: Texture2D = _class_icon_for(String(hero.class_id))
		if class_icon != null:
			btn.icon = class_icon
			btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Bind the hero's instance_id so the closure captures the correct value.
		btn.pressed.connect(_on_hero_button_pressed.bind(hero.instance_id))
		_roster_list.add_child(btn)
		UIFrameworkScript.assert_tap_target_min(btn)
		UIFrameworkScript.wire_touch_feedback(btn)
		# GDD #34 Phase 3 (Defeat & Injury / ADR-0021 AC-34-09): fade + badge an
		# injured hero in the picker so the player sees who can't be dispatched
		# BEFORE assigning them. Assignment stays allowed (only Dispatch is gated,
		# AC-34-04); the mark is additive (badge child + dim), no reparent.
		var injured_until: int = int(hero.get("injured_until"))
		if injured_until > now_ms:
			UIFrameworkScript.mark_injured(btn, (injured_until - now_ms) / 1000)


## Returns the role icon for [param class_id], or null when the class has no
## authored art. Only warrior/mage/rogue ship icons in the MVP set (DESIGN.md
## "Required MVP icon set"); cleric/archer/berserker/paladin and any unknown id
## return null so the card renders text-only rather than a broken/placeholder
## glyph. Generating the remaining four class icons is a flagged follow-up.
func _class_icon_for(class_id: String) -> Texture2D:
	match class_id:
		"warrior":
			return ICON_CLASS_WARRIOR
		"mage":
			return ICON_CLASS_MAGE
		"rogue":
			return ICON_CLASS_ROGUE
		_:
			return null


## Rebuilds the formation slot buttons from the live HeroRoster state.
##
## Reads [code]HeroRoster.formation_size()[/code] (=3) and resolves each slot's
## occupant by building a lookup map from [code]get_all_heroes()[/code].
## Uses "Empty" label or hero display_name per slot.
##
## Called once in on_enter() and after any slot mutation.
func _refresh_formation_panel() -> void:
	# Clear existing slot buttons. Sprint 24 S24-M3 uses
	# UIFramework.clear_children_immediate.
	UIFrameworkScript.clear_children_immediate(_slots_hbox)

	# Build instance_id → hero lookup from the full hero list. Holds the hero
	# object (not just display_name) so GDD #34 Phase 3 can read injured_until
	# per occupied slot below.
	var hero_map: Dictionary = {}
	for hero: Variant in HeroRoster.get_all_heroes():
		hero_map[hero.instance_id] = hero

	# GDD #34 Phase 3 — single wall-clock read per refresh for the injury marks below.
	var now_ms: int = TickSystem.now_ms()
	var slot_count: int = HeroRoster.formation_size()
	for i: int in range(slot_count):
		var slot_id: int = _get_formation_slot_id(i)
		var btn: Button = Button.new()
		if slot_id == 0 or not hero_map.has(slot_id):
			btn.text = tr("slot_empty_label")
		else:
			btn.text = str(hero_map[slot_id].display_name)
		btn.custom_minimum_size = Vector2(180, 80)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		# Sprint 21 S21-M1: apply Slot Button theme variation (pattern #12).
		# Selected variant: 4px Guild Amber border (weight + color change —
		# colorblind-safe). Default: 2px Slate Ink + 6px corner radius
		# (panel-like content holder per pattern spec).
		if i == _active_slot_index:
			btn.theme_type_variation = &"SlotButtonSelected"
		else:
			btn.theme_type_variation = &"SlotButton"
		btn.pressed.connect(_on_slot_button_pressed.bind(i))
		_slots_hbox.add_child(btn)
		UIFrameworkScript.assert_tap_target_min(btn)
		UIFrameworkScript.wire_touch_feedback(btn)
		# GDD #34 Phase 3 (Defeat & Injury / ADR-0021 AC-34-09): fade + badge an
		# injured occupant so the player sees a formation can't dispatch BEFORE
		# tapping Dispatch (only Dispatch is gated, AC-34-04). Additive mark, no
		# reparent; the SelectedBadge below is an independent child.
		if slot_id != 0 and hero_map.has(slot_id):
			var occupant: Variant = hero_map[slot_id]
			var injured_until: int = int(occupant.get("injured_until"))
			if injured_until > now_ms:
				UIFrameworkScript.mark_injured(btn, (injured_until - now_ms) / 1000)
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
## S15-M1 refactor (AC-FA-12 single-write-point): routes the write through
## [code]FormationAssignment.commit()[/code] instead of calling
## [code]HeroRoster.set_formation_slot[/code] directly.
##
## S15-M2 mid-run gate (AC-FA-13): when
## [code]MID_RUN_REASSIGN_WARNING_ENABLED == true[/code] AND
## [code]DungeonRunOrchestrator.state[/code] is ACTIVE_FOREGROUND or
## OFFLINE_REPLAY, the commit is deferred — the screen shows
## [member _reassign_confirm_root] and stashes the pending tap. On confirm
## the commit proceeds; on cancel it's discarded.
##
## On commit, advances [member _active_slot_index] to fill successive slots
## with successive taps (progressive fill pattern). Refreshes both panels.
func _on_hero_button_pressed(hero_id: int) -> void:
	# AC-FA-13 gate: defer the commit if mid-run + warning enabled.
	if MID_RUN_REASSIGN_WARNING_ENABLED and _is_orchestrator_active():
		_pending_reassign_hero_id = hero_id
		_pending_reassign_slot_index = _active_slot_index
		_reassign_confirm_root.visible = true
		return
	_apply_hero_commit(hero_id, _active_slot_index)


## Returns true when DungeonRunOrchestrator.state warrants the confirm
## dialog. Per formation-assignment-system.md §C.3 + §G.1: any state in
## which a run is in flight should surface the consequence. That includes
## DISPATCHING (1), ACTIVE_FOREGROUND (2), and ACTIVE_OFFLINE_REPLAY (3).
## NO_RUN (0) and RUN_ENDED (4) commit immediately — no in-flight run to
## interrupt.
func _is_orchestrator_active() -> bool:
	# Resolve at call time via get_node_or_null so test envs without the
	# orchestrator wired don't crash on the global lookup.
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if orch == null:
		return false
	var s: int = int(orch.get("state"))
	# Hard-coded enum values to avoid script-load coupling. Per
	# dungeon_run_state.gd: NO_RUN=0, RUN_ENDED=4. Active = anything else.
	return s != 0 and s != 4


## Builds the positional Array[HeroInstance], applies the tap, routes through
## FormationAssignment.commit(), and advances the active slot. Called either
## directly (no-confirmation path) or from _on_reassign_confirm_pressed.
func _apply_hero_commit(hero_id: int, slot_index: int) -> void:
	var formation_size: int = HeroRoster.formation_size()
	var new_formation: Array[HeroInstance] = []
	new_formation.resize(formation_size)
	for i: int in range(formation_size):
		var existing_id: int = HeroRoster.get_formation_slot(i)
		new_formation[i] = HeroRoster.get_hero_by_id(existing_id)
	new_formation[slot_index] = HeroRoster.get_hero_by_id(hero_id)
	FormationAssignment.commit(new_formation)
	_active_slot_index = (slot_index + 1) % formation_size
	_refresh_roster_panel()
	_refresh_formation_panel()
	UIFrameworkScript.suppress_keyboard_focus(self)


## Confirm button on the mid-run reassignment dialog. Two pending paths share
## this dialog (never both set at once):
##   1. Preset recall (GDD #33 / AC-FP-11): a NON-EMPTY _pending_recall_formation
##      is applied via _apply_recall_commit and takes priority.
##   2. Single-hero tap (S15-M2): consumes _pending_reassign_* and commits.
## Either commit triggers run-end + restart per ADR-0001. Hides the dialog.
func _on_reassign_confirm_pressed() -> void:
	_reassign_confirm_root.visible = false
	if not _pending_recall_formation.is_empty():
		var formation: Array[HeroInstance] = _pending_recall_formation
		_pending_recall_formation = []
		_apply_recall_commit(formation)
		return
	var hero_id: int = _pending_reassign_hero_id
	var slot_index: int = _pending_reassign_slot_index
	_pending_reassign_hero_id = 0
	_pending_reassign_slot_index = -1
	if hero_id != 0 and slot_index >= 0:
		_apply_hero_commit(hero_id, slot_index)


## Cancel button on the mid-run reassignment dialog. Discards BOTH pending
## paths (single-hero tap and preset recall); no signal emit; the run continues
## unaffected.
func _on_reassign_cancel_pressed() -> void:
	_pending_reassign_hero_id = 0
	_pending_reassign_slot_index = -1
	_pending_recall_formation = []
	_reassign_confirm_root.visible = false


# ---------------------------------------------------------------------------
# Formation Presets (GDD #33, PR #2) — dropdown, Save/Recall/Delete + modals
# ---------------------------------------------------------------------------

## Rebuilds the preset dropdown from FormationAssignment.get_presets(). Item 0
## is always the "(none)" placeholder (preset id 0); each saved preset is added
## with its real id as the OptionButton item id. [param keep_selected_id] re-selects
## that preset if it still exists (used after a save to land on the new preset);
## 0 resets to "(none)" (used after a delete). OptionButton.select() does NOT emit
## item_selected, so this never re-enters _on_preset_selected.
func _rebuild_preset_dropdown(keep_selected_id: int = 0) -> void:
	if _preset_dropdown == null:
		return
	_preset_dropdown.clear()
	_preset_dropdown.add_item(tr("formation_presets_none_option"), 0)
	var presets: Array[Dictionary] = FormationAssignment.get_presets()
	var select_index: int = 0
	for preset: Dictionary in presets:
		var pid: int = int(preset.get("id", 0))
		_preset_dropdown.add_item(String(preset.get("name", "")), pid)
		if pid == keep_selected_id and keep_selected_id != 0:
			select_index = _preset_dropdown.get_item_count() - 1
	_preset_dropdown.select(select_index)
	_selected_preset_id = _preset_dropdown.get_item_id(select_index)
	_update_preset_button_visibility()


## Recall + Delete only make sense once a real preset (id != 0) is selected.
func _update_preset_button_visibility() -> void:
	var has_selection: bool = _selected_preset_id != 0
	if _preset_recall_button != null:
		_preset_recall_button.visible = has_selection
	if _preset_delete_button != null:
		_preset_delete_button.visible = has_selection


## Player picked a dropdown row. Tracks the selection + toggles button visibility.
func _on_preset_selected(index: int) -> void:
	if _preset_dropdown == null:
		return
	_selected_preset_id = _preset_dropdown.get_item_id(index)
	_update_preset_button_visibility()


## preset_saved fires synchronously from save_preset(); land the dropdown on the
## new preset.
func _on_preset_saved(preset_id: int, _preset_name: String) -> void:
	_rebuild_preset_dropdown(preset_id)


## preset_deleted fires synchronously from delete_preset(); reset to "(none)".
func _on_preset_deleted(_preset_id: int) -> void:
	_rebuild_preset_dropdown(0)


## Save button: cap-guard first (a friendly toast beats a silent no-op), then
## open the name modal.
func _on_preset_save_button_pressed() -> void:
	if FormationAssignment.get_presets().size() >= FormationAssignment.max_presets():
		_show_toast(tr("formation_presets_at_cap_toast"))
		return
	_show_preset_save_modal()


func _show_preset_save_modal() -> void:
	if _preset_save_modal == null:
		return
	if _preset_name_line_edit != null:
		_preset_name_line_edit.text = ""
	_preset_save_modal.visible = true
	# LineEdit keeps FOCUS_ALL (suppress_keyboard_focus only neutralizes
	# BaseButtons), so grab_focus raises the virtual keyboard on touch/Steam Deck.
	if _preset_name_line_edit != null:
		_preset_name_line_edit.grab_focus()


func _hide_preset_save_modal() -> void:
	if _preset_save_modal != null:
		_preset_save_modal.visible = false


func _on_preset_save_cancel_pressed() -> void:
	_hide_preset_save_modal()


## Snapshots the CURRENT formation slot ids and saves them under the typed name.
## Empty name → toast + keep the modal open. The autoload truncates names over
## preset_name_max_length(); we surface that with a "shortened" toast. Dropdown
## refresh happens via the preset_saved signal (fires inside save_preset()).
func _on_preset_save_confirm_pressed() -> void:
	var raw_name: String = ""
	if _preset_name_line_edit != null:
		raw_name = _preset_name_line_edit.text
	var trimmed: String = raw_name.strip_edges()
	if trimmed.is_empty():
		_show_toast(tr("formation_presets_name_empty_toast"))
		return
	var was_truncated: bool = trimmed.length() > FormationAssignment.preset_name_max_length()
	var slot_ids: Array[int] = []
	var fsize: int = HeroRoster.formation_size()
	slot_ids.resize(fsize)
	for i: int in range(fsize):
		slot_ids[i] = HeroRoster.get_formation_slot(i)
	var new_id: int = FormationAssignment.save_preset(trimmed, slot_ids)
	_hide_preset_save_modal()
	if new_id == 0:
		_show_toast(tr("formation_presets_at_cap_toast"))
		return
	if was_truncated:
		_show_toast(tr("formation_presets_truncated_toast"))
	else:
		_show_toast(tr("formation_presets_saved_toast"))


## Recall (K.1 Option 1): resolve the preset to a positional formation, surface
## any missing heroes as ONE composed (capped) toast, then commit immediately —
## routing through the mid-run gate when a run is active (AC-FP-11).
func _on_preset_recall_button_pressed() -> void:
	if _selected_preset_id == 0:
		return
	var resolved: Array = FormationAssignment.recall_preset(_selected_preset_id)
	if resolved.is_empty():
		# Preset vanished (e.g. deleted in another flow). Recover gracefully.
		_show_toast(tr("formation_presets_recall_unknown_toast"))
		_rebuild_preset_dropdown(0)
		return
	var fsize: int = HeroRoster.formation_size()
	var formation: Array[HeroInstance] = []
	formation.resize(fsize)
	var stored_ids: Array = _stored_slot_ids_for(_selected_preset_id)
	var missing_count: int = 0
	for i: int in range(fsize):
		var hero: HeroInstance = resolved[i] as HeroInstance if i < resolved.size() else null
		formation[i] = hero
		# A slot stored a real hero id (!= 0) but it no longer resolves → that
		# hero left the guild. Empty slots (stored id 0) are NOT "missing".
		var stored_id: int = int(stored_ids[i]) if i < stored_ids.size() else 0
		if stored_id != 0 and hero == null:
			missing_count += 1
	if missing_count > 0:
		var shown: int = mini(missing_count, FormationAssignment.recall_missing_hero_toast_cap())
		# Guard the %d substitution: if the locale string is unresolved — tr()
		# returns the bare key, which has no placeholder — then `key % shown` is
		# a FATAL format error in GDScript ("not all arguments converted").
		# Only substitute when the placeholder is actually present, so a missing
		# or late-loading LocaleLoader can never crash the recall path.
		var template: String = tr("formation_presets_missing_toast")
		var message: String = template
		if template.find("%d") != -1:
			message = template % shown
		_show_toast(message)
	# Mid-run gate: a recall commits, so defer behind the confirm dialog when a
	# run is in flight (mirrors the single-hero tap path).
	if MID_RUN_REASSIGN_WARNING_ENABLED and _is_orchestrator_active():
		_pending_recall_formation = formation
		_reassign_confirm_root.visible = true
		return
	_apply_recall_commit(formation)


## Reads the stored slot_hero_ids for a preset (for missing-hero detection).
## Returns [] if the preset is gone. JSON round-trips ints as floats, so callers
## int()-cast each element.
func _stored_slot_ids_for(preset_id: int) -> Array:
	var result: Array = []
	for preset: Dictionary in FormationAssignment.get_presets():
		if int(preset.get("id", 0)) == preset_id:
			var raw: Variant = preset.get("slot_hero_ids", [])
			if raw is Array:
				result = raw
			break
	return result


## Applies a recalled formation through the single commit write-point, then
## refreshes. Mirrors _apply_hero_commit's post-commit refresh; resets the active
## slot to 0 since recall replaces the whole lineup.
func _apply_recall_commit(formation: Array[HeroInstance]) -> void:
	FormationAssignment.commit(formation)
	_active_slot_index = 0
	_refresh_roster_panel()
	_refresh_formation_panel()
	UIFrameworkScript.suppress_keyboard_focus(self)


func _on_preset_delete_button_pressed() -> void:
	if _selected_preset_id == 0:
		return
	_show_preset_delete_modal()


func _show_preset_delete_modal() -> void:
	if _preset_delete_modal == null:
		return
	_preset_delete_modal.visible = true
	_grab_delete_default_focus()


## Default focus on the delete-confirm modal is Cancel (the safe choice) per
## FormationAssignment.delete_confirmation_default_focus(). suppress_keyboard_focus
## neutralized this button, so re-enable focus_mode before grabbing.
func _grab_delete_default_focus() -> void:
	var which: String = FormationAssignment.delete_confirmation_default_focus()
	var target: Button = _preset_delete_cancel_button
	if which == "confirm":
		target = _preset_delete_confirm_button
	if target != null:
		target.focus_mode = Control.FOCUS_ALL
		target.grab_focus()


func _hide_preset_delete_modal() -> void:
	if _preset_delete_modal != null:
		_preset_delete_modal.visible = false


## Confirm delete: delete_preset emits preset_deleted synchronously → the
## dropdown rebuilds to "(none)". Then a confirmation toast.
func _on_preset_delete_confirm_pressed() -> void:
	var pid: int = _selected_preset_id
	_hide_preset_delete_modal()
	if pid != 0:
		FormationAssignment.delete_preset(pid)
		_show_toast(tr("formation_presets_deleted_toast"))


func _on_preset_delete_cancel_pressed() -> void:
	_hide_preset_delete_modal()


## Shows the Floor Picker overlay (S22-M2 fold of the retired
## matchup_assignment screen). Reads the current target from
## FormationAssignment.get_target() as the initial selection.
## Player taps Cancel (no change) or Select (commits via set_target).
func _on_floor_button_pressed() -> void:
	_show_floor_picker()


## Refreshes the FloorContextLabel + FloorButton text from
## [member _selected_biome_id] + [member _selected_floor]. Extracted as a
## helper so the Floor Picker (S22-M2) can call it after Select commits.
func _refresh_floor_context_label() -> void:
	_floor_context_label.text = _compose_target_label(_selected_biome_id, _selected_floor)
	_floor_button.text = _floor_context_label.text


## Sprint 22 S22-M4: refreshes the GoldCounter from Economy.get_gold_balance().
## Uses the cozy-display short-number format (1.2K / 4.5M) per UIFramework.
func _refresh_gold_counter() -> void:
	if _gold_counter == null:
		return
	_gold_counter.text = UIFrameworkScript.format_localized(
		"formation_assignment_gold_counter_format",
		[UIFrameworkScript.format_short_number(Economy.get_gold_balance())]
	)


## Sprint 22 S22-M4: gold_changed signal handler — re-renders GoldCounter.
func _on_gold_changed(_new_balance: int, _delta: int, _reason: String) -> void:
	_refresh_gold_counter()


# ---------------------------------------------------------------------------
# Floor Picker overlay — Sprint 22 S22-M2 (fold of matchup_assignment)
#
# Per the retired Matchup Assignment Screen GDD #23 §C.1-§C.6, ported here
# as private methods on formation_assignment to collapse two screens into
# one Dispatch flow. All ACs UX-MA-01..18 are now satisfied inside this
# overlay rather than a separate screen.
# ---------------------------------------------------------------------------

func _show_floor_picker() -> void:
	# Step 1: resolve biomes via FloorUnlock.get_available_biomes() — the
	# authoritative source per GDD #16 R7. UI consumers MUST NOT read
	# DataRegistry.get_all_by_type("biomes") directly, because that returns
	# every biome regardless of unlock state — including chained biomes that
	# the player has not yet unlocked. Honoring R7 keeps the tab list aligned
	# with the player's actual progression: 4 starter biomes on a fresh save;
	# chained biomes (ember_wastes, hollow_stair) appear only after their
	# Biome.unlock_after gate fires.
	var available_biome_ids: Array[String] = FloorUnlock.get_available_biomes()
	_fp_biomes = []
	for biome_id: String in available_biome_ids:
		var biome: Resource = DataRegistry.resolve("biomes", biome_id) as Resource
		if biome != null:
			_fp_biomes.append(biome)
	_fp_biomes.sort_custom(func(a: Resource, b: Resource) -> bool:
		return String(a.id) < String(b.id)
	)
	_fp_floors_by_biome = {}
	var all_dungeons: Array[Resource] = DataRegistry.get_all_by_type("dungeons")
	for biome: Resource in _fp_biomes:
		var biome_id: String = String(biome.id)
		_fp_floors_by_biome[biome_id] = []
		for dungeon: Resource in all_dungeons:
			if String(dungeon.biome_id) == biome_id:
				var dungeon_floors: Array = dungeon.floors as Array
				for floor_data: Resource in dungeon_floors:
					_fp_floors_by_biome[biome_id].append(floor_data)
		(_fp_floors_by_biome[biome_id] as Array).sort_custom(func(a: Resource, b: Resource) -> bool:
			return int(a.floor_index) < int(b.floor_index)
		)

	# S28-S1: create FloorRecommendationLabel once (idempotent). The label is a
	# sibling of PickerSelectButton inside PickerContent so it renders above the
	# Select button. Visible = false until a floor with a valid recommendation is
	# selected. Created in code (not .tscn) to avoid reparenting any existing node.
	if _floor_recommendation_label == null:
		var picker_content: Control = _floor_picker_select_button.get_parent() as Control
		if picker_content != null:
			var rec_label: Label = Label.new()
			rec_label.name = "FloorRecommendationLabel"
			rec_label.visible = false
			# Insert before PickerSelectButton so it renders above it.
			var select_idx: int = _floor_picker_select_button.get_index()
			picker_content.add_child(rec_label)
			picker_content.move_child(rec_label, select_idx)
			_floor_recommendation_label = rec_label
			# S28-S1: additive matchup icon pinned to the label's right edge. It is
			# a CHILD of the label (not a reparent of the label into a new HBox —
			# that would break the FloorRecommendationLabel hard-path). Decorative:
			# MOUSE_FILTER_IGNORE so a tap falls through to the Select button. As a
			# child of the label it also inherits the label's visibility, so it can
			# never linger when the recommendation is hidden.
			var matchup_icon: TextureRect = TextureRect.new()
			matchup_icon.name = "FloorMatchupIcon"
			matchup_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			matchup_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			matchup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			matchup_icon.custom_minimum_size = Vector2(16, 16)
			matchup_icon.visible = false
			# Right-edge, vertically centred 16×16 box (label is not a container,
			# so position via explicit anchored offsets rather than layout).
			matchup_icon.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			matchup_icon.offset_left = -20.0
			matchup_icon.offset_right = -4.0
			matchup_icon.offset_top = -8.0
			matchup_icon.offset_bottom = 8.0
			rec_label.add_child(matchup_icon)
			_floor_matchup_icon = matchup_icon

	# Step 2: render biome tabs.
	_render_floor_picker_biome_tabs()

	# Step 3: apply initial selection from current FormationAssignment target.
	var target: Dictionary = FormationAssignment.get_target()
	var initial_biome: String = String(target.get("biome_id", ""))
	var initial_floor: int = int(target.get("floor_index", 0))
	if initial_biome == "" or initial_floor <= 0:
		# Fallback: first biome, floor 1 (always unlocked per FloorUnlock §C).
		if _fp_biomes.size() > 0:
			initial_biome = String(_fp_biomes[0].id)
			initial_floor = 1
	if initial_biome != "" and initial_floor > 0:
		_select_floor_in_picker(initial_biome, initial_floor)
	else:
		_floor_picker_select_button.disabled = true
		_floor_picker_select_button.text = tr("formation_assignment_no_biomes")
		# No floor selected → hide any stale recommendation from a prior open.
		if _floor_recommendation_label != null:
			_floor_recommendation_label.visible = false

	# Step 4: show the overlay.
	_floor_picker_root.visible = true


func _hide_floor_picker() -> void:
	_floor_picker_root.visible = false


## Builds an archetype → class display_name map from HeroClassDatabase.
##
## Iterates [method HeroClassDatabase.get_all_ids] (alphabetically sorted) and
## maps each [code]counter_archetype[/code] to the corresponding class
## [code]display_name[/code]. First-class-encountered wins on collision (because
## get_all_ids is alphabetically sorted, this is deterministic and stable).
## Classes with an empty [code]counter_archetype[/code] are skipped.
##
## Consumed by both the biome hint ([method _render_floor_picker_biome_tabs])
## and the per-floor recommendation label ([method _update_floor_recommendation_label]).
## The map is a cheap pure projection of HeroClassDatabase (≈7 O(1) lookups), so
## each consumer rebuilds it on demand rather than sharing cached state — this
## keeps the helper correct across the picker's multiple render entry points
## (initial open + live floor-unlock re-render) with no invalidation surface.
##
## Returns a typed [Dictionary][String, String]: archetype → display_name.
## Example: [code]{"bruiser": "Berserker", "caster": "Mage", ...}[/code]
func _build_archetype_to_class_map() -> Dictionary[String, String]:
	var map: Dictionary[String, String] = {}
	for class_id: String in HeroClassDatabase.get_all_ids():
		var cls: HeroClass = HeroClassDatabase.get_by_id(class_id)
		if cls == null:
			continue
		var counter: String = String(cls.counter_archetype)
		if counter != "" and not map.has(counter):
			map[counter] = String(cls.display_name)
	return map


## Returns the recommended class display_name for the given floor's enemy composition.
##
## Algorithm:
##   1. Tally total enemy counts per archetype by iterating [Floor.enemy_list]
##      in order. Entries whose [code]enemy_id[/code] cannot be resolved by
##      [EnemyDatabase.get_by_id] (returns null) or have an empty
##      [code]archetype[/code] are skipped.
##   2. The archetype with the highest total count is dominant. Tie-break:
##      first-encountered archetype in [Floor.enemy_list] order wins
##      (deterministic per the list's authoring order).
##   3. Returns [code]archetype_to_class.get(dominant_archetype, "")[/code] —
##      the counter class display_name, or [code]""[/code] if no archetype was
##      tallied or the dominant archetype has no class counter mapped.
##
## [param floor_data] — the [Floor] resource to analyse.
## [param archetype_to_class] — pre-built map from [method _build_archetype_to_class_map].
## Returns [code]""[/code] on empty list, all-null enemy ids, or unmapped archetype.
func _recommended_class_for_floor(
		floor_data: Floor,
		archetype_to_class: Dictionary[String, String]) -> String:
	# Tally enemy counts per archetype. GDScript Dictionaries preserve insertion
	# order (Godot 4.4+; the project relies on this per ADR-0012 / ADR-0013), so
	# iterating `tally` yields archetypes in first-encountered order — exactly the
	# tie-break we want, with no separate ordering array to maintain.
	var tally: Dictionary[String, int] = {}
	for entry: Dictionary in floor_data.enemy_list:
		# Defensive reads: the Floor schema documents enemy_id:String + count:int,
		# but nothing validates .tres entries at load (the Story-004 validator was
		# never wired), so a present-but-null/non-string enemy_id would make a bare
		# String() cast abort the whole selection chain. Type-check before trusting.
		var raw_id: Variant = entry.get("enemy_id")
		if typeof(raw_id) != TYPE_STRING or String(raw_id) == "":
			continue
		var enemy_data: EnemyData = EnemyDatabase.get_by_id(String(raw_id))
		if enemy_data == null:
			continue
		var arch: String = String(enemy_data.archetype)
		if arch == "":
			continue
		var raw_count: Variant = entry.get("count")
		var count: int = int(raw_count) if (typeof(raw_count) == TYPE_INT or typeof(raw_count) == TYPE_FLOAT) else 0
		tally[arch] = tally.get(arch, 0) + count
	if tally.is_empty():
		return ""
	# Dominant archetype: highest total count; tie → first-encountered wins
	# (tally insertion order == enemy_list first-seen order).
	var dominant: String = ""
	var dominant_count: int = -1
	for arch: String in tally:
		if tally[arch] > dominant_count:
			dominant_count = tally[arch]
			dominant = arch
	return archetype_to_class.get(dominant, "")


func _render_floor_picker_biome_tabs() -> void:
	# Clear existing biome tabs (idempotent re-entry). Sprint 24 S24-M3
	# uses UIFramework.clear_children_immediate.
	UIFrameworkScript.clear_children_immediate(_floor_picker_biome_vbox)

	# Build archetype → recommended-class map for the matchup-hint labels
	# (biome hint + per-floor hint both consume this map).
	var archetype_to_class: Dictionary[String, String] = _build_archetype_to_class_map()

	# Per-biome tabs.
	for biome: Resource in _fp_biomes:
		var biome_id: String = String(biome.id)
		var biome_tab: VBoxContainer = VBoxContainer.new()
		biome_tab.name = "BiomeTab_%s" % biome_id
		_floor_picker_biome_vbox.add_child(biome_tab)
		# Biome name label.
		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.text = String(biome.display_name) if "display_name" in biome and String(biome.display_name) != "" else biome_id.capitalize()
		biome_tab.add_child(name_label)
		# Matchup hint — prescriptive class recommendation.
		var archetypes: Array[String] = []
		if "dominant_archetypes" in biome:
			var raw: Array = biome.get("dominant_archetypes") as Array
			for a: Variant in raw:
				if a is String and String(a) != "":
					archetypes.append(String(a))
		if not archetypes.is_empty():
			var recommended: Array[String] = []
			var seen: Dictionary = {}
			for a: String in archetypes:
				if archetype_to_class.has(a):
					var class_name_for_a: String = archetype_to_class[a]
					if not seen.has(class_name_for_a):
						recommended.append(class_name_for_a)
						seen[class_name_for_a] = true
			var hint_label: Label = Label.new()
			hint_label.name = "MatchupHintLabel"
			if recommended.is_empty():
				hint_label.text = UIFrameworkScript.format_localized(
						"formation_assignment_common_archetypes_format",
						[", ".join(archetypes)]
					)
			else:
				hint_label.text = tr("matchup_floor_recommended_format") % ", ".join(recommended)
			biome_tab.add_child(hint_label)
		# Floor buttons row.
		var floor_row: HBoxContainer = HBoxContainer.new()
		floor_row.name = "FloorRow"
		biome_tab.add_child(floor_row)
		var floors: Array = _fp_floors_by_biome.get(biome_id, [])
		for floor_data: Resource in floors:
			var floor_index: int = int(floor_data.floor_index)
			var floor_button: Button = Button.new()
			floor_button.name = "FloorButton_%d" % floor_index
			var is_unlocked: bool = FloorUnlock.is_unlocked_in_biome(biome_id, floor_index)
			# Emoji-as-icon avoids a separate icon node + asset for the locked
			# affordance. The tooltip names the predecessor floor (floor_index - 1)
			# because MVP has no skip-ahead unlocks; chained-biome floor-1 is gated
			# by Biome.unlock_after, not by this tooltip's predecessor reference.
			if is_unlocked:
				floor_button.text = UIFrameworkScript.format_localized(
						"formation_assignment_floor_button_format", [floor_index]
					)
				floor_button.tooltip_text = ""
			else:
				floor_button.text = UIFrameworkScript.format_localized(
						"formation_assignment_floor_button_locked_format", [floor_index]
					)
				floor_button.tooltip_text = tr("matchup_floor_locked_tooltip_format") % (floor_index - 1)
			floor_button.custom_minimum_size = Vector2(60, 60)
			floor_button.focus_mode = Control.FOCUS_NONE
			floor_button.mouse_filter = Control.MOUSE_FILTER_STOP
			floor_button.disabled = not is_unlocked
			floor_button.pressed.connect(
				_on_floor_picker_floor_pressed.bind(biome_id, floor_index)
			)
			UIFrameworkScript.wire_touch_feedback(floor_button)
			floor_row.add_child(floor_button)


func _select_floor_in_picker(biome_id: String, floor_index: int) -> void:
	_fp_selected_biome_id = biome_id
	_fp_selected_floor_index = floor_index
	if FloorUnlock.is_unlocked_in_biome(biome_id, floor_index):
		_floor_picker_select_button.disabled = false
		_floor_picker_select_button.text = UIFrameworkScript.format_localized("matchup_select_format", [floor_index, biome_id.capitalize()])
	else:
		_floor_picker_select_button.disabled = true
		_floor_picker_select_button.text = tr("formation_assignment_select_locked")
	# S28-S1: surface the per-floor matchup recommendation for the selected floor.
	_update_floor_recommendation_label(biome_id, floor_index)


## Updates the FloorRecommendationLabel for the currently selected floor.
##
## Resolves the [Floor] resource for (biome_id, floor_index) from the picker's
## [member _fp_floors_by_biome] cache, derives the recommended class via
## [method _recommended_class_for_floor], and shows "Recommended: <class>". When
## the floor has no resolvable recommendation (empty/unmapped enemy_list), the
## label is hidden so no empty "Recommended: " stub is ever shown.
func _update_floor_recommendation_label(biome_id: String, floor_index: int) -> void:
	if _floor_recommendation_label == null:
		return
	var floor_data: Floor = null
	for f: Resource in (_fp_floors_by_biome.get(biome_id, []) as Array):
		# Cast + null-guard BEFORE reading floor_index: the cache is sourced from
		# a typed Array[Floor] today, but dungeon.gd documents a fallback to
		# Array[Resource], so a stray non-Floor element must not abort here.
		var candidate: Floor = f as Floor
		if candidate != null and candidate.floor_index == floor_index:
			floor_data = candidate
			break
	if floor_data == null:
		_floor_recommendation_label.visible = false
		_set_matchup_icon_visible(false)
		return
	var archetype_to_class: Dictionary[String, String] = _build_archetype_to_class_map()
	var recommended: String = _recommended_class_for_floor(floor_data, archetype_to_class)
	if recommended == "":
		_floor_recommendation_label.visible = false
		_set_matchup_icon_visible(false)
	else:
		_floor_recommendation_label.text = tr("matchup_floor_recommended_format") % recommended
		_floor_recommendation_label.visible = true
		# S28-S1: the 3-state icon reports how the player's CURRENT lineup fares
		# on THIS floor (Strong/Even/Weak from the combat resolver), distinct from
		# the prescriptive "Recommended: <class>" text. Hidden when there is no
		# formation yet or the floor has no resolvable archetypes.
		_update_floor_matchup_icon(floor_data)


## Returns the distinct enemy archetypes present on a floor, in first-seen order.
##
## Mirrors the enemy_list extraction in [method _recommended_class_for_floor]
## (same defensive typed reads — present-but-null enemy_id would otherwise abort
## a bare String() cast), but yields the FULL archetype set rather than only the
## dominant one: the resolver scores the lineup against every archetype present,
## not just the most common.
func _floor_archetypes(floor_data: Floor) -> Array[String]:
	var archetypes: Array[String] = []
	var seen: Dictionary[String, bool] = {}
	for entry: Dictionary in floor_data.enemy_list:
		var raw_id: Variant = entry.get("enemy_id")
		if typeof(raw_id) != TYPE_STRING or String(raw_id) == "":
			continue
		var enemy_data: EnemyData = EnemyDatabase.get_by_id(String(raw_id))
		if enemy_data == null:
			continue
		var arch: String = String(enemy_data.archetype)
		if arch == "" or seen.has(arch):
			continue
		seen[arch] = true
		archetypes.append(arch)
	return archetypes


## Returns the live formation's matchup verdict against [param floor_data] as a
## [MatchupResult] effectiveness_label ∈ {"Strong","Even","Weak"}, or "" when
## there is nothing to score (empty formation, or a floor with no resolvable
## archetypes). "" is distinct from "Even": it means "no verdict to show" and
## the caller hides the icon entirely rather than displaying a neutral state.
##
## Reuses [DefaultMatchupResolver.resolve_floor_matchup] — the exact resolver
## [DungeonRunOrchestrator] uses to award the 1.5×/0.7× per-kill gold multiplier
## — so the hint reflects the throughput the player will actually experience.
func _formation_matchup_label_for_floor(floor_data: Floor) -> String:
	var formation: Array = HeroRoster.get_formation_heroes()
	if formation.is_empty():
		return ""
	var archetypes: Array[String] = _floor_archetypes(floor_data)
	if archetypes.is_empty():
		return ""
	var resolver := DefaultMatchupResolverScript.new()
	var result: MatchupResult = resolver.resolve_floor_matchup(formation, archetypes)
	return String(result.effectiveness_label)


## Maps a [MatchupResult] effectiveness_label to its 3-state icon, or null for an
## unrecognised/empty label (caller hides the icon). "Weak" → disadvantage is
## truthful, not invented: a Weak floor means the lineup counters nothing on it,
## so every kill lands at the 0.7× penalty.
func _matchup_icon_for_label(label: String) -> Texture2D:
	match label:
		"Strong":
			return ICON_MATCHUP_ADVANTAGE
		"Even":
			return ICON_MATCHUP_NEUTRAL
		"Weak":
			return ICON_MATCHUP_DISADVANTAGE
		_:
			return null


## Sets the matchup icon for [param floor_data] against the live formation, or
## hides it when there is no verdict (no formation / no resolvable archetypes).
func _update_floor_matchup_icon(floor_data: Floor) -> void:
	if _floor_matchup_icon == null:
		return
	var icon: Texture2D = _matchup_icon_for_label(_formation_matchup_label_for_floor(floor_data))
	if icon == null:
		_floor_matchup_icon.visible = false
	else:
		_floor_matchup_icon.texture = icon
		_floor_matchup_icon.visible = true


## Null-safe visibility toggle for the matchup icon (it may not exist yet if the
## picker has never been opened).
func _set_matchup_icon_visible(is_visible: bool) -> void:
	if _floor_matchup_icon != null:
		_floor_matchup_icon.visible = is_visible


func _on_floor_picker_floor_pressed(biome_id: String, floor_index: int) -> void:
	if not FloorUnlock.is_unlocked_in_biome(biome_id, floor_index):
		push_warning(
			"[FloorPicker] toast: %s"
			% (tr("matchup_floor_locked_format") % (floor_index - 1))
		)
		return
	_select_floor_in_picker(biome_id, floor_index)


func _on_floor_picker_select_pressed() -> void:
	if _fp_selected_biome_id == "" or _fp_selected_floor_index <= 0:
		push_warning("[FloorPicker] select press with no valid selection — defensive")
		return
	# Commit selection: push to FormationAssignment.set_target so it survives
	# screen re-entry, then update local state so the FloorContextLabel +
	# FloorButton reflect the new target, then close the overlay.
	FormationAssignment.set_target(_fp_selected_biome_id, _fp_selected_floor_index)
	_selected_biome_id = _fp_selected_biome_id
	_selected_floor = _fp_selected_floor_index
	_refresh_floor_context_label()
	_hide_floor_picker()


func _on_floor_picker_cancel_pressed() -> void:
	# Cancel without committing — preserve prior target.
	_hide_floor_picker()


## Mid-screen unlock advance (rare; primarily during offline-replay flush).
## Re-renders the picker if it's currently visible.
func _on_floor_unlocked(_biome_id: String, _floor_index: int) -> void:
	if _floor_picker_root != null and _floor_picker_root.visible:
		_render_floor_picker_biome_tabs()
		if _fp_selected_biome_id != "" and _fp_selected_floor_index > 0:
			_select_floor_in_picker(_fp_selected_biome_id, _fp_selected_floor_index)


## Biome chain gate fired — a previously-locked biome is now unlocked.
## If the floor picker is visible, fully rebuild it so the new biome
## appears as a tab. Distinct from _on_floor_unlocked (which only
## re-renders the existing tabs for floor frontier changes).
func _on_biome_unlocked(_biome_id: String) -> void:
	if _floor_picker_root != null and _floor_picker_root.visible:
		_show_floor_picker()


## Navigates back to Guild Hall.
func _on_back_pressed() -> void:
	SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)


## Composes "<Biome display_name> — Floor <N>" from biome_id + floor_index,
## with defensive fallbacks:
##   - cold-launch default (forest_reach floor 1) → uses the localized canonical key
##   - biome resolved → "<display_name> — Floor <N>"
##   - biome unresolvable → "<biome_id> — Floor <N>" raw fallback
func _compose_target_label(biome_id: String, floor_index: int) -> String:
	if biome_id == "forest_reach" and floor_index == 1:
		return tr("floor_label_forest_reach_1")
	var biome: Resource = DataRegistry.resolve("biomes", biome_id)
	var biome_display: String = biome_id
	if biome != null and "display_name" in biome:
		var d: String = String(biome.get("display_name"))
		if d != "":
			biome_display = d
	return "%s — Floor %d" % [biome_display, floor_index]


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
		"run_already_active":
			# Player re-entered the formation screen mid-run and pressed Dispatch.
			# The orchestrator's FSM rejects a second dispatch while a run is in
			# flight; surface that as a toast instead of a silent dead control.
			_show_toast(tr("dispatch_error_run_already_active"))
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


## Signal relay: one or more heroes were injured (GDD #34 Phase 3 / ADR-0021).
## Rebuilds both panels so the injury fade + badge appear (or clear on recovery)
## live. Payload is ignored — a full refresh re-reads injured_until per hero.
func _on_heroes_injured(_instance_ids: Array, _injured_until_ms: int) -> void:
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

	# Sprint 23 S23-N2 — passive preview label (always visible). Updates
	# every refresh, independent of the cozy detection-moment de-dup below.
	# Players see "Synergy: None" until the slot composition matches a known
	# synergy, at which point the label flips to the synergy's display name.
	_refresh_synergy_preview_label(synergy_id)

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

	# Show path: render localized "Display Name: Effect" text. AC-CS-15.
	var display_name: String = UIFrameworkScript.synergy_display_name(synergy_id)
	var effect_text: String = UIFrameworkScript.synergy_effect_text(synergy_id)
	_synergy_badge.text = UIFrameworkScript.format_localized(
			"formation_assignment_synergy_badge_format", [display_name, effect_text]
		)

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


## Sprint 23 S23-N2 + Sprint 24 S24-M2 — passive synergy preview label.
##
## Updates the always-visible "Synergy: X" label above the slot row to
## reflect [param synergy_id] per the V2 Tier Ladder spec in
## `class-synergy-system.md` §C.6:
##   - empty string → "Synergy: None" (no detection yet)
##   - non-empty    → "Synergy: <tier> (<display_name>)"
##                    e.g., "Synergy: Gold (Steel Wall)",
##                          "Synergy: Platinum (Triple Threat)"
##
## Distinct from `_refresh_synergy_badge` which animates the cozy "you-
## found-something" glow on detection-edge transitions only. This label
## updates on EVERY slot edit so players see the live preview as they
## experiment with composition before pressing Dispatch.
##
## V2 Tier (S24-M1 GDD §C.6 + AC-CS-22..26): the tier reflects composition
## VERSATILITY, not raw multiplier strength. 3-mono-class → Gold;
## 1+1+1 balanced → Platinum (the "completeness" tier).
func _refresh_synergy_preview_label(synergy_id: String) -> void:
	if _synergy_preview_label == null:
		return
	var tier_key: String = UIFrameworkScript.synergy_id_to_tier(synergy_id)
	var tier_name: String = tr("synergy_tier_" + tier_key)
	if synergy_id == "":
		# No detection: single-substitution "Synergy: None" format.
		_synergy_preview_label.text = tr("synergy_preview_none_format") % tier_name
		return
	# Tiered + effect: "Synergy: Gold (Steel Wall) — +25% gold vs bruisers".
	# Answers both "what synergy is active?" AND "what does it do?".
	var display_name: String = UIFrameworkScript.synergy_display_name(synergy_id)
	var effect_text: String = UIFrameworkScript.synergy_effect_text(synergy_id)
	_synergy_preview_label.text = (
		tr("synergy_preview_tiered_format_with_effect")
		% [tier_name, display_name, effect_text]
	)


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


# ===========================================================================
# Lantern Guild mock wireframe — greybox Dispatch screen
# (feat/ui-wireframe-core-loop)
#
# Recreates the "Dispatch" layout from the Lantern Guild Prototype mock
# (Roster left column, Formation + Floor right column, Dispatch CTA footer)
# at greybox/wireframe fidelity. Built ADDITIVELY: every @onready node path
# and every node referenced by tests remains unchanged. Existing nodes are
# repositioned via anchor/offset; new neutral-grey wireframe siblings are
# added at z=2 (above BiomeBackground/WarmLanternOverlay) so the greybox
# reads as neutral structure without disturbing the interactive behaviour.
#
# PickerPanel receives a single stylebox override for visual coherence;
# NO node names, paths, or types inside FloorPickerOverlay are changed.
#
# NO Color() literals in this file — all colors route through WireframeKit
# palette constants (a sibling screen's test greps for Color( literals).
# ===========================================================================

const WireframeKitScript = preload("res://src/ui/wireframe_kit.gd")

const _WIRE_Z: int = 2          # draw above BiomeBackground (z=-1) and WarmLanternOverlay (z=1)
const _TOPBAR_H: float = 52.0   # height of the decorative top-bar strip
const _COL_GAP: float = 12.0    # gap between viewport edge and panels
const _ROW_GAP: float = 10.0    # vertical gap between stacked panels
const _LEFT_W: float = 340.0    # roster column width
const _CONTENT_TOP: float = 58.0  # y-offset below top bar where panels start
const _FORMATION_H: float = 180.0 # height of the formation panel
const _FLOOR_H: float = 80.0    # height of the floor-selector panel
const _FOOTER_H: float = 60.0   # height of the dispatch CTA footer strip
# GDD #33 (Formation Presets, PR #2): the PresetsPanel stacks below the floor
# selector in the right column. _PRESETS_TOP == 338 (58+180+10+80+10).
const _PRESETS_TOP: float = _CONTENT_TOP + _FORMATION_H + _ROW_GAP + _FLOOR_H + _ROW_GAP
const _PRESETS_H: float = 120.0 # height of the presets panel (title + row + breathing room)

var _wire_built: bool = false
var _wire_float_layer: Control = null


## Sets a Control's four anchors then four offsets in one call.
## Private helper shared by all wireframe build methods.
func _place_fa(node: Control, al: float, at: float, ar: float, ab: float,
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


## Entry point — called once from on_enter(); guarded by _wire_built flag.
func _build_wireframe_once() -> void:
	if _wire_built:
		return
	_wire_built = true
	_reposition_existing_nodes_fa()
	_build_top_bar_fa()
	_build_roster_section()
	_build_formation_section()
	_build_floor_section()
	_build_presets_section()
	_build_dispatch_footer()
	_style_picker_panel()
	_build_float_layer_fa()


## Repositions the pre-existing .tscn nodes into the wireframe 2-column layout.
## Node paths are UNCHANGED — only anchors, offsets, and z-index are modified.
## Text, theme_type_variation, and signals are preserved.
func _reposition_existing_nodes_fa() -> void:
	# Back button: top-left corner above the top bar. custom_minimum_size gives
	# the rendered button a >=44px mobile-parity tap target. (UIFramework's
	# on-enter check reads .size before layout settles, so it still logs the
	# button's intrinsic 104x31 .tscn size — a warning present on main too,
	# unaffected by this wireframe; not chased here per the no-hygiene-creep steer.)
	if _back_button != null:
		_back_button.custom_minimum_size = Vector2(88.0, 44.0)
		_place_fa(_back_button, 0, 0, 0, 0,
			_COL_GAP, 4.0, _COL_GAP + 140.0, 48.0)
		_back_button.z_index = 3

	# HeaderLabel: centered in the top bar strip.
	var header: Label = get_node_or_null("HeaderLabel") as Label
	if header != null:
		_place_fa(header, 0.5, 0, 0.5, 0,
			-200.0, 10.0, 200.0, 48.0)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.z_index = 3

	# GoldCounter: top-right corner above the top bar.
	if _gold_counter != null:
		_place_fa(_gold_counter, 1, 0, 1, 0,
			-220.0, 8.0, -_COL_GAP, 46.0)
		_gold_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_gold_counter.z_index = 3

	# RosterPanel: left column, from content-top to the footer.
	var roster_panel: PanelContainer = get_node_or_null("RosterPanel") as PanelContainer
	if roster_panel != null:
		roster_panel.custom_minimum_size = Vector2.ZERO
		roster_panel.grow_horizontal = Control.GROW_DIRECTION_END
		roster_panel.grow_vertical = Control.GROW_DIRECTION_END
		_place_fa(roster_panel, 0, 0, 0, 1,
			_COL_GAP, _CONTENT_TOP,
			_COL_GAP + _LEFT_W, -(_FOOTER_H + _ROW_GAP + _COL_GAP))
		roster_panel.z_index = _WIRE_Z

	# FormationPanel: right column, top portion.
	var formation_panel: PanelContainer = get_node_or_null("FormationPanel") as PanelContainer
	if formation_panel != null:
		formation_panel.grow_horizontal = Control.GROW_DIRECTION_END
		formation_panel.grow_vertical = Control.GROW_DIRECTION_END
		_place_fa(formation_panel, 0, 0, 1, 0,
			_COL_GAP + _LEFT_W + _ROW_GAP, _CONTENT_TOP,
			-_COL_GAP, _CONTENT_TOP + _FORMATION_H)
		formation_panel.z_index = _WIRE_Z

	# FloorSelectorPanel: right column, below formation.
	var floor_panel: PanelContainer = get_node_or_null("FloorSelectorPanel") as PanelContainer
	if floor_panel != null:
		floor_panel.grow_horizontal = Control.GROW_DIRECTION_END
		floor_panel.grow_vertical = Control.GROW_DIRECTION_END
		_place_fa(floor_panel, 0, 0, 1, 0,
			_COL_GAP + _LEFT_W + _ROW_GAP,
			_CONTENT_TOP + _FORMATION_H + _ROW_GAP,
			-_COL_GAP,
			_CONTENT_TOP + _FORMATION_H + _ROW_GAP + _FLOOR_H)
		floor_panel.z_index = _WIRE_Z

	# DispatchButton: full-width footer, bottom of screen.
	if _dispatch_button != null:
		_place_fa(_dispatch_button, 0, 1, 1, 1,
			_COL_GAP, -(_FOOTER_H + _COL_GAP),
			-_COL_GAP, -_COL_GAP)
		_dispatch_button.z_index = _WIRE_Z

	# SynergyBadge: park it centered below the formation panel; visibility
	# controlled by the existing _refresh_synergy_badge logic (not touched here).
	if _synergy_badge != null:
		_place_fa(_synergy_badge, 0.5, 0, 0.5, 0,
			-240.0, _CONTENT_TOP + _FORMATION_H - 32.0,
			240.0, _CONTENT_TOP + _FORMATION_H)
		_synergy_badge.z_index = _WIRE_Z

	# ToastLabel: centered just above the footer dispatch button.
	if _toast_label != null:
		_place_fa(_toast_label, 0, 1, 1, 1,
			_COL_GAP, -(_FOOTER_H + _COL_GAP + 40.0),
			-_COL_GAP, -(_FOOTER_H + _COL_GAP + 2.0))
		_toast_label.z_index = _WIRE_Z + 1

	# MidRunReassignConfirmation: keep as full-rect overlay (unchanged semantics),
	# raise its z so it sits above the wireframe.
	var confirm_root: Control = get_node_or_null("MidRunReassignConfirmation") as Control
	if confirm_root != null:
		confirm_root.z_index = 6

	# FloorPickerOverlay: raise z so the modal sits above all wireframe panels.
	# Node names and paths inside this subtree are NOT touched.
	if _floor_picker_root != null:
		_floor_picker_root.z_index = 7

	# PresetsPanel: right column, below the floor selector (GDD #33, PR #2).
	# Same anchor pattern (0,0,1,0) + absolute top/bottom offsets as the formation
	# and floor panels above it.
	if _presets_panel != null:
		_presets_panel.grow_horizontal = Control.GROW_DIRECTION_END
		_presets_panel.grow_vertical = Control.GROW_DIRECTION_END
		_place_fa(_presets_panel, 0, 0, 1, 0,
			_COL_GAP + _LEFT_W + _ROW_GAP, _PRESETS_TOP,
			-_COL_GAP, _PRESETS_TOP + _PRESETS_H)
		_presets_panel.z_index = _WIRE_Z

	# Preset Save / Delete modals: full-rect overlays raised above the floor
	# picker (z=7). Tree order (declared last in the .tscn) gives their STOP
	# backdrops input priority; z just controls draw order.
	if _preset_save_modal != null:
		_preset_save_modal.z_index = 8
	if _preset_delete_modal != null:
		_preset_delete_modal.z_index = 8


## Decorative top-bar strip. The real HeaderLabel, BackButton, and GoldCounter
## are repositioned above it (z=3) so real text reads over the strip.
func _build_top_bar_fa() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "WireTopBarDispatch"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = _WIRE_Z
	bar.add_theme_stylebox_override("panel", WireframeKitScript.stylebox(
		WireframeKitScript.HEADER_FILL, WireframeKitScript.LINE, 1, 0, 0))
	add_child(bar)
	_place_fa(bar, 0, 0, 1, 0, 0.0, 0.0, 0.0, _TOPBAR_H)


## Left column: Roster section label. The real RosterPanel is repositioned
## to fill this column; this method adds a section_panel eyebrow wrapper
## BEHIND the real panel (z=1 vs RosterPanel z=2) to give the column a
## titled wireframe frame.
func _build_roster_section() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Roster")
	panel.name = "WireRosterSection"
	panel.z_index = 1   # behind the real RosterPanel (z=2)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_place_fa(panel, 0, 0, 0, 1,
		_COL_GAP, _CONTENT_TOP,
		_COL_GAP + _LEFT_W, -(_FOOTER_H + _ROW_GAP + _COL_GAP))
	# Annotation inside the section body
	var body: VBoxContainer = WireframeKitScript.body_of(panel)
	body.add_child(WireframeKitScript.caption(
		"Tap a hero to place them in the active slot.",
		WireframeKitScript.MUTED, 11))


## Right column, top: Formation section label. The real FormationPanel is
## repositioned to fill this zone; this method adds a section_panel wrapper
## behind it (z=1) for the titled wireframe frame.
func _build_formation_section() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Formation")
	panel.name = "WireFormationSection"
	panel.z_index = 1   # behind the real FormationPanel (z=2)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_place_fa(panel, 0, 0, 1, 0,
		_COL_GAP + _LEFT_W + _ROW_GAP, _CONTENT_TOP,
		-_COL_GAP, _CONTENT_TOP + _FORMATION_H)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)
	body.add_child(WireframeKitScript.caption(
		"3 slots · tap a slot to select it, then tap a hero.",
		WireframeKitScript.MUTED, 11))


## Right column, below formation: Floor-selector section label. The real
## FloorSelectorPanel is repositioned here; this wrapper sits at z=1.
func _build_floor_section() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Destination")
	panel.name = "WireFloorSection"
	panel.z_index = 1   # behind the real FloorSelectorPanel (z=2)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_place_fa(panel, 0, 0, 1, 0,
		_COL_GAP + _LEFT_W + _ROW_GAP,
		_CONTENT_TOP + _FORMATION_H + _ROW_GAP,
		-_COL_GAP,
		_CONTENT_TOP + _FORMATION_H + _ROW_GAP + _FLOOR_H)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)
	body.add_child(WireframeKitScript.caption(
		"Tap to choose biome + floor.", WireframeKitScript.MUTED, 11))


## Right column, below the floor selector: Presets section label (GDD #33).
## The real PresetsPanel is repositioned over this; this greybox wrapper sits at
## z=1 with MOUSE_FILTER_IGNORE so it never steals taps from the real controls
## (per the z_index-does-not-affect-input-picking lesson).
func _build_presets_section() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Formations")
	panel.name = "WirePresetsSection"
	panel.z_index = 1   # behind the real PresetsPanel (z=2)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_place_fa(panel, 0, 0, 1, 0,
		_COL_GAP + _LEFT_W + _ROW_GAP, _PRESETS_TOP,
		-_COL_GAP, _PRESETS_TOP + _PRESETS_H)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)
	body.add_child(WireframeKitScript.caption(
		"Save, recall, or delete a saved lineup.", WireframeKitScript.MUTED, 11))


## Full-width footer accent strip behind the real DispatchButton.
## The real button stays interactive at z=2; this strip sits at z=1.
func _build_dispatch_footer() -> void:
	var strip: PanelContainer = PanelContainer.new()
	strip.name = "WireDispatchFooter"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.z_index = 1   # behind the real DispatchButton (z=2)
	strip.add_theme_stylebox_override("panel", WireframeKitScript.stylebox(
		WireframeKitScript.FILL_RAISED, WireframeKitScript.ACCENT, 2, 4, 0))
	add_child(strip)
	_place_fa(strip, 0, 1, 1, 1,
		_COL_GAP, -(_FOOTER_H + _COL_GAP),
		-_COL_GAP, -_COL_GAP)

	# Eyebrow annotation above the dispatch button area.
	var label: Label = WireframeKitScript.eyebrow(
		"Dispatch party", WireframeKitScript.ACCENT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 1
	add_child(label)
	_place_fa(label, 0, 1, 1, 1,
		_COL_GAP, -(_FOOTER_H + _COL_GAP + 18.0),
		-_COL_GAP, -(_FOOTER_H + _COL_GAP + 2.0))


## Applies a greybox stylebox to PickerPanel for visual coherence with the
## other wireframe panels. ONLY touches the stylebox override — NO node names,
## paths, types, or children inside FloorPickerOverlay are changed.
func _style_picker_panel() -> void:
	var picker_panel: PanelContainer = get_node_or_null(
		"FloorPickerOverlay/PickerPanel") as PanelContainer
	if picker_panel == null:
		return
	picker_panel.add_theme_stylebox_override("panel",
		WireframeKitScript.stylebox(WireframeKitScript.FILL, WireframeKitScript.LINE, 1, 4, 0))


## Full-rect, input-transparent float layer for any future floating-number
## feedback on this screen.
func _build_float_layer_fa() -> void:
	var layer: Control = WireframeKitScript.float_layer()
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wire_float_layer = layer
