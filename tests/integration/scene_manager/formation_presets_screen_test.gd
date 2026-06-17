# Integration tests for Formation Presets — the player-visible PresetsRow UI
# (GDD #33, design/gdd/formation-presets.md). PR #2: the screen layer wired on
# top of the merged FormationAssignment preset data layer (PR #1, #238).
#
# Covers acceptance criteria:
#   AC-FP-06: dropdown lists saved presets + "(none)" placeholder; recall/delete
#             buttons hidden while nothing is selected
#   AC-FP-07: save flow — name modal → save_preset → dropdown selects the new preset
#   AC-FP-08: empty/whitespace name is rejected (modal stays open, nothing saved)
#   AC-FP-04 / K.1 Option 1: recall performs an immediate commit() to the live
#             formation when no run is active
#   AC-FP-11: a recall mid-run is routed through the existing reassign-confirm
#             gate (deferred until the player confirms; cancel discards it)
#   AC-FP-05/§K.2: a recalled preset referencing a hero no longer in the guild
#             clears that slot and surfaces a count toast (no crash)
#   AC-FP-09: delete flow removes the preset and resets the dropdown to "(none)"
#
# Test isolation pattern: the screen drives the LIVE autoloads (FormationAssignment,
# HeroRoster, DungeonRunOrchestrator) via their global names, so this suite
# snapshots ALL THREE in before_test and restores them in after_test — preventing
# preset/roster/run-state leakage into other suites (see memory:
# test-isolation-via-live-autoload-mutation). This is deliberately separate from
# formation_assignment_screen_test.gd so the two suites stay independently runnable.
#
# White-box note: tests set/read the screen's `_`-prefixed members and call its
# handlers directly. GDScript has no enforced privacy; this is the established
# screen-test pattern (see formation_assignment_screen_test.gd) — it exercises the
# exact code paths the button .pressed signals fire, without synthesizing input.
#
# ADR-0007: Screen lifecycle contract (on_enter/on_exit signal hygiene)
# ADR-0008: UI Framework tap-target + focus suppression
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Path constants
# ---------------------------------------------------------------------------

const FORMATION_SCREEN_PATH: String = "res://assets/screens/formation_assignment/formation_assignment.tscn"

# ---------------------------------------------------------------------------
# Snapshots (restored in after_test for live-autoload isolation)
# ---------------------------------------------------------------------------

var _hero_roster_snapshot: Dictionary = {}
var _formation_assignment_snapshot: Dictionary = {}
var _orchestrator_state_snapshot: int = 0


# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------

func before_test() -> void:
	# Snapshot every live autoload this suite mutates.
	_hero_roster_snapshot = HeroRoster.get_save_data().duplicate(true)
	_formation_assignment_snapshot = FormationAssignment.get_save_data().duplicate(true)
	_orchestrator_state_snapshot = int(DungeonRunOrchestrator.state)

	# Clean slate: empty roster, empty preset store, no active run.
	HeroRoster.load_save_data({
		"heroes": [],
		"formation_slots": [0, 0, 0],
		"next_instance_id": 1,
	})
	FormationAssignment.load_save_data({})  # empty dict → presets=[], next_id=1
	DungeonRunOrchestrator.state = 0  # DungeonRunState.State.NO_RUN
	DungeonRunOrchestrator._last_dispatch_ms = 0
	DungeonRunOrchestrator.set_floor_unlock(null)


func after_test() -> void:
	HeroRoster.load_save_data(_hero_roster_snapshot)
	FormationAssignment.load_save_data(_formation_assignment_snapshot)
	DungeonRunOrchestrator.state = _orchestrator_state_snapshot
	DungeonRunOrchestrator._last_dispatch_ms = 0
	DungeonRunOrchestrator.set_floor_unlock(null)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Instantiate the formation screen, add it to the tree, run on_enter.
## Mirrors formation_assignment_screen_test.gd's navigate helper (the headless
## SceneManager routing quirk makes direct instantiation the reliable path).
func _navigate() -> Control:
	var packed: PackedScene = load(FORMATION_SCREEN_PATH) as PackedScene
	if packed == null:
		return null
	var screen: Control = packed.instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	if screen.has_method("on_enter"):
		screen.on_enter()
	await get_tree().process_frame
	return screen


## Tear down a screen: on_exit disconnects its live-autoload signals, then free.
func _teardown(screen: Control) -> void:
	if is_instance_valid(screen):
		if screen.has_method("on_exit"):
			screen.on_exit()
		screen.queue_free()
	await get_tree().process_frame


## Seed N "warrior" heroes via save data (instance_ids 1..N). Returns the ids.
func _seed_heroes(count: int) -> Array[int]:
	var heroes_arr: Array = []
	var ids: Array[int] = []
	for i: int in range(count):
		var iid: int = i + 1
		heroes_arr.append({
			"instance_id": iid,
			"class_id": "warrior",
			"display_name": "Warrior_%d" % iid,
			"current_level": 1,
			"xp": 0,
		})
		ids.append(iid)
	HeroRoster.load_save_data({
		"heroes": heroes_arr,
		"formation_slots": [0, 0, 0],
		"next_instance_id": count + 1,
	})
	return ids


# ===========================================================================
# AC-FP-06: dropdown lists presets + "(none)"; recall/delete hidden when unselected
# ===========================================================================

func test_formation_presets_dropdown_lists_presets_and_hides_action_buttons() -> void:
	# Arrange — two presets exist BEFORE the screen opens, so on_enter's rebuild
	# must pick them up. Empty roster is fine; save_preset stores ids verbatim.
	_seed_heroes(3)
	var slot_ids: Array[int] = [1, 2, 3]
	FormationAssignment.save_preset("Alpha", slot_ids)
	FormationAssignment.save_preset("Beta", slot_ids)

	# Act
	var screen: Control = await _navigate()
	assert_object(screen).is_not_null()

	# Assert — dropdown has "(none)" + 2 presets; placeholder id is 0; nothing
	# selected by default → recall/delete hidden.
	assert_int(screen._preset_dropdown.get_item_count()).is_equal(3)
	assert_int(screen._preset_dropdown.get_item_id(0)).is_equal(0)
	assert_int(screen._selected_preset_id).is_equal(0)
	assert_bool(screen._preset_recall_button.visible).is_false()
	assert_bool(screen._preset_delete_button.visible).is_false()

	await _teardown(screen)


# ===========================================================================
# AC-FP-07: save flow creates a preset from the current formation and selects it
# ===========================================================================

func test_formation_presets_save_flow_creates_and_selects_preset() -> void:
	# Arrange — 3 heroes in formation; the save modal snapshots the live slots.
	var ids: Array[int] = _seed_heroes(3)
	HeroRoster.set_formation_slot(0, ids[0])
	HeroRoster.set_formation_slot(1, ids[1])
	HeroRoster.set_formation_slot(2, ids[2])

	var screen: Control = await _navigate()
	assert_object(screen).is_not_null()

	# Act — open modal, type a name, confirm.
	screen._on_preset_save_button_pressed()
	assert_bool(screen._preset_save_modal.visible).is_true()
	screen._preset_name_line_edit.text = "Team A"
	screen._on_preset_save_confirm_pressed()
	await get_tree().process_frame

	# Assert — one preset stored, named, capturing the current formation.
	var presets: Array[Dictionary] = FormationAssignment.get_presets()
	assert_int(presets.size()).is_equal(1)
	assert_str(String(presets[0].get("name", ""))).is_equal("Team A")
	var stored: Array = presets[0].get("slot_hero_ids", [])
	assert_int(stored.size()).is_equal(3)
	assert_int(int(stored[0])).is_equal(ids[0])
	assert_int(int(stored[1])).is_equal(ids[1])
	assert_int(int(stored[2])).is_equal(ids[2])

	# Modal closed; dropdown auto-selected the new preset; actions now visible.
	assert_bool(screen._preset_save_modal.visible).is_false()
	assert_int(screen._selected_preset_id).is_equal(int(presets[0].get("id", 0)))
	assert_bool(screen._selected_preset_id != 0).is_true()
	assert_bool(screen._preset_recall_button.visible).is_true()
	assert_bool(screen._preset_delete_button.visible).is_true()

	await _teardown(screen)


# ===========================================================================
# AC-FP-08: empty/whitespace name is rejected — modal stays open, nothing saved
# ===========================================================================

func test_formation_presets_save_empty_name_keeps_modal_open_and_saves_nothing() -> void:
	# Arrange
	_seed_heroes(3)
	var screen: Control = await _navigate()
	assert_object(screen).is_not_null()

	# Act — open modal, enter whitespace only, confirm.
	screen._on_preset_save_button_pressed()
	screen._preset_name_line_edit.text = "   "
	screen._on_preset_save_confirm_pressed()
	await get_tree().process_frame

	# Assert — nothing saved; modal still open for correction.
	assert_int(FormationAssignment.get_presets().size()).is_equal(0)
	assert_bool(screen._preset_save_modal.visible).is_true()

	await _teardown(screen)


# ===========================================================================
# AC-FP-04 / K.1 Option 1: recall commits the formation when no run is active
# ===========================================================================

func test_formation_presets_recall_commits_formation_when_no_active_run() -> void:
	# Arrange — heroes 1,2,3; save a preset of [1,2,3]; leave the live formation
	# empty so a successful recall is observable as [1,2,3].
	var ids: Array[int] = _seed_heroes(3)
	var slot_ids: Array[int] = [ids[0], ids[1], ids[2]]
	var pid: int = FormationAssignment.save_preset("Lineup", slot_ids)

	var screen: Control = await _navigate()
	assert_object(screen).is_not_null()
	screen._selected_preset_id = pid

	# Pre-assert — formation is empty before recall.
	assert_int(HeroRoster.get_formation_slot(0)).is_equal(0)

	# Act — recall (orchestrator state is NO_RUN → no gate).
	screen._on_preset_recall_button_pressed()
	await get_tree().process_frame

	# Assert — formation committed to the preset; no confirm dialog shown.
	assert_int(HeroRoster.get_formation_slot(0)).is_equal(ids[0])
	assert_int(HeroRoster.get_formation_slot(1)).is_equal(ids[1])
	assert_int(HeroRoster.get_formation_slot(2)).is_equal(ids[2])
	assert_bool(screen._reassign_confirm_root.visible).is_false()

	await _teardown(screen)


# ===========================================================================
# AC-FP-11: a recall mid-run defers behind the reassign-confirm gate (it does
# NOT commit immediately), then commits when the player confirms.
#
# Split into two focused tests on purpose. Confirming a recall while a run is
# ACTIVE re-enters the existing reassign flow: commit() emits
# formation_reassignment_committed, the orchestrator ends+restarts the run
# (ADR-0001), and the screen navigates to dungeon_run_view via SceneManager —
# which asserts on a live /root/MainRoot. That restart→navigation cascade is
# pre-existing reassign behavior (covered by the dispatch + orchestrator
# suites); wiring a live MainRoot here is out of scope for the UI gate. So the
# deferral and the confirm-applies-it logic are exercised independently.
# ===========================================================================

func test_formation_presets_recall_during_active_run_defers_behind_confirm_gate() -> void:
	# Arrange — heroes + preset; live formation empty; an ACTIVE run in flight.
	var ids: Array[int] = _seed_heroes(3)
	var slot_ids: Array[int] = [ids[0], ids[1], ids[2]]
	var pid: int = FormationAssignment.save_preset("Lineup", slot_ids)

	var screen: Control = await _navigate()
	assert_object(screen).is_not_null()
	screen._selected_preset_id = pid
	DungeonRunOrchestrator.state = 2  # DungeonRunState.State.ACTIVE_FOREGROUND

	# Act — recall while a run is active.
	screen._on_preset_recall_button_pressed()
	await get_tree().process_frame

	# Assert — gate is open, recall is pending, NOTHING committed yet.
	assert_bool(screen._reassign_confirm_root.visible).is_true()
	assert_bool(screen._pending_recall_formation.is_empty()).is_false()
	assert_int(HeroRoster.get_formation_slot(0)).is_equal(0)
	assert_int(HeroRoster.get_formation_slot(1)).is_equal(0)
	assert_int(HeroRoster.get_formation_slot(2)).is_equal(0)

	await _teardown(screen)


func test_formation_presets_recall_confirm_applies_deferred_formation() -> void:
	# Arrange — defer a recall via the REAL mid-run path (ACTIVE → gate opens,
	# pending set, nothing committed yet).
	var ids: Array[int] = _seed_heroes(3)
	var slot_ids: Array[int] = [ids[0], ids[1], ids[2]]
	var pid: int = FormationAssignment.save_preset("Lineup", slot_ids)

	var screen: Control = await _navigate()
	assert_object(screen).is_not_null()
	screen._selected_preset_id = pid
	DungeonRunOrchestrator.state = 2  # DungeonRunState.State.ACTIVE_FOREGROUND
	screen._on_preset_recall_button_pressed()
	await get_tree().process_frame
	assert_bool(screen._reassign_confirm_root.visible).is_true()
	assert_bool(screen._pending_recall_formation.is_empty()).is_false()

	# The run ends before the player taps Confirm (NO_RUN). Direct assignment to
	# the orchestrator's plain `state` var emits no signal, so the screen does
	# not navigate — and commit() at NO_RUN no-ops the orchestrator restart
	# (proven safe by the no-active-run recall test above). This isolates the
	# confirm-applies-the-deferred-recall logic from the navigation cascade.
	DungeonRunOrchestrator.state = 0  # DungeonRunState.State.NO_RUN

	# Act — player confirms.
	screen._on_reassign_confirm_pressed()
	await get_tree().process_frame

	# Assert — formation committed; gate closed; pending state cleared.
	assert_int(HeroRoster.get_formation_slot(0)).is_equal(ids[0])
	assert_int(HeroRoster.get_formation_slot(1)).is_equal(ids[1])
	assert_int(HeroRoster.get_formation_slot(2)).is_equal(ids[2])
	assert_bool(screen._reassign_confirm_root.visible).is_false()
	assert_bool(screen._pending_recall_formation.is_empty()).is_true()

	await _teardown(screen)


# ===========================================================================
# AC-FP-11 (cancel branch): cancelling a mid-run recall discards it
# ===========================================================================

func test_formation_presets_recall_during_active_run_cancel_discards_pending() -> void:
	# Arrange
	var ids: Array[int] = _seed_heroes(3)
	var slot_ids: Array[int] = [ids[0], ids[1], ids[2]]
	var pid: int = FormationAssignment.save_preset("Lineup", slot_ids)

	var screen: Control = await _navigate()
	assert_object(screen).is_not_null()
	screen._selected_preset_id = pid
	DungeonRunOrchestrator.state = 2  # ACTIVE_FOREGROUND

	# Act — recall opens the gate, then cancel.
	screen._on_preset_recall_button_pressed()
	await get_tree().process_frame
	assert_bool(screen._reassign_confirm_root.visible).is_true()
	screen._on_reassign_cancel_pressed()
	await get_tree().process_frame

	# Assert — nothing committed; gate closed; pending state cleared.
	assert_int(HeroRoster.get_formation_slot(0)).is_equal(0)
	assert_int(HeroRoster.get_formation_slot(1)).is_equal(0)
	assert_int(HeroRoster.get_formation_slot(2)).is_equal(0)
	assert_bool(screen._reassign_confirm_root.visible).is_false()
	assert_bool(screen._pending_recall_formation.is_empty()).is_true()

	await _teardown(screen)


# ===========================================================================
# AC-FP-05 / §K.2: recalling a preset with a departed hero clears that slot and
# surfaces a toast (must not crash even if the locale string is unresolved)
# ===========================================================================

func test_formation_presets_recall_missing_hero_clears_slot_and_shows_toast() -> void:
	# Arrange — save a preset of [1,2,3], then re-seed the roster WITHOUT hero 2,
	# so recall resolves slot 1 to null (a departed hero).
	var ids: Array[int] = _seed_heroes(3)
	var slot_ids: Array[int] = [ids[0], ids[1], ids[2]]
	var pid: int = FormationAssignment.save_preset("Lineup", slot_ids)

	var heroes_without_2: Array = [
		{"instance_id": 1, "class_id": "warrior", "display_name": "Warrior_1", "current_level": 1, "xp": 0},
		{"instance_id": 3, "class_id": "warrior", "display_name": "Warrior_3", "current_level": 1, "xp": 0},
	]
	HeroRoster.load_save_data({
		"heroes": heroes_without_2,
		"formation_slots": [0, 0, 0],
		"next_instance_id": 4,
	})

	var screen: Control = await _navigate()
	assert_object(screen).is_not_null()
	screen._selected_preset_id = pid

	var toast_label: Label = screen.get_node_or_null("ToastLabel") as Label
	assert_object(toast_label).is_not_null()

	# Act — recall (no active run).
	screen._on_preset_recall_button_pressed()
	await get_tree().process_frame

	# Assert — present heroes land in their slots; the missing hero's slot is
	# cleared; a (non-empty) toast is surfaced. The %d guard means this path
	# never crashes whether or not LocaleLoader resolved the string.
	assert_int(HeroRoster.get_formation_slot(0)).is_equal(1)
	assert_int(HeroRoster.get_formation_slot(1)).is_equal(0)  # departed hero → empty
	assert_int(HeroRoster.get_formation_slot(2)).is_equal(3)
	assert_bool(toast_label.visible).is_true()
	assert_str(toast_label.text).is_not_empty()

	await _teardown(screen)


# ===========================================================================
# AC-FP-09: delete flow removes the preset and resets the dropdown to "(none)"
# ===========================================================================

func test_formation_presets_delete_flow_removes_preset_and_resets_dropdown() -> void:
	# Arrange — one preset, selected.
	_seed_heroes(3)
	var slot_ids: Array[int] = [1, 2, 3]
	var pid: int = FormationAssignment.save_preset("Doomed", slot_ids)

	var screen: Control = await _navigate()
	assert_object(screen).is_not_null()
	screen._selected_preset_id = pid
	assert_int(FormationAssignment.get_presets().size()).is_equal(1)

	# Act — open the confirm modal, confirm deletion.
	screen._on_preset_delete_button_pressed()
	assert_bool(screen._preset_delete_modal.visible).is_true()
	screen._on_preset_delete_confirm_pressed()
	await get_tree().process_frame

	# Assert — preset gone; modal closed; dropdown reset to "(none)"; actions hidden.
	assert_int(FormationAssignment.get_presets().size()).is_equal(0)
	assert_bool(screen._preset_delete_modal.visible).is_false()
	assert_int(screen._selected_preset_id).is_equal(0)
	assert_bool(screen._preset_recall_button.visible).is_false()
	assert_bool(screen._preset_delete_button.visible).is_false()

	await _teardown(screen)
