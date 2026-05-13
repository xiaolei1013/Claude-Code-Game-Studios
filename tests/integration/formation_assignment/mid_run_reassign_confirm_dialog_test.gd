# AC-FA-13 regression test for S15-M2.
#
# When the player taps a hero-button on the formation_assignment screen
# AND MID_RUN_REASSIGN_WARNING_ENABLED is true AND DungeonRunOrchestrator
# state is ACTIVE_FOREGROUND (2) or OFFLINE_REPLAY (3), the screen must
# defer the commit and show the confirmation dialog. On confirm, the
# commit fires; on cancel, no signal is emitted and HeroRoster is
# unchanged.
#
# When state is NO_RUN (0) or RUN_ENDED (4), the commit proceeds
# immediately without the dialog (matches the cozy default: don't surface
# a consequence dialog when there's no run to interrupt).
#
# Pairs with screen_routes_through_commit_test.gd (AC-FA-12) and the
# autoload commit() unit tests.
#
# S15-M2 — Sprint 15.
extends GdUnitTestSuite

const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const SCREEN_PATH: String = "res://assets/screens/formation_assignment/formation_assignment.tscn"


# ---------------------------------------------------------------------------
# Hygiene barrier — snapshot HeroRoster + DungeonRunOrchestrator state.
# ---------------------------------------------------------------------------

var _snapshot_roster: Dictionary = {}
var _snapshot_orch_state: int = 0


func before_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_snapshot_roster = roster.get_save_data() if roster != null else {}
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	_snapshot_orch_state = int(orch.get("state")) if orch != null else 0


func after_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and not _snapshot_roster.is_empty():
		roster.load_save_data(_snapshot_roster)
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	if orch != null:
		orch.set("state", _snapshot_orch_state)


# ---------------------------------------------------------------------------
# Signal spy — class-level to avoid lambda-capture marshalling issues.
# ---------------------------------------------------------------------------

var _spy_commit_count: int = 0


func _spy_on_committed(_formation: Variant) -> void:
	_spy_commit_count += 1


func _reset_spy() -> void:
	_spy_commit_count = 0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _seed_three_heroes() -> Array[int]:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	var ids: Array[int] = []
	for class_id: String in ["warrior", "mage", "rogue"]:
		var instance: RefCounted = roster.call("add_hero", class_id)
		if instance != null:
			ids.append(int(instance.get("instance_id")))
	return ids


func _make_screen() -> Control:
	var packed: PackedScene = load(SCREEN_PATH) as PackedScene
	var screen: Control = packed.instantiate() as Control
	add_child(screen)
	# One frame so @onready resolves.
	return screen


func _set_orch_state(state_value: int) -> void:
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	if orch != null:
		orch.set("state", state_value)


# ===========================================================================
# Group A — NO_RUN state: no dialog; commit fires immediately
# ===========================================================================

# A-01: when orchestrator state is NO_RUN (0), tapping a hero immediately
# fires the commit signal and the dialog stays hidden.
func test_no_run_state_commits_immediately_without_dialog() -> void:
	# Arrange.
	var ids: Array[int] = _seed_three_heroes()
	assert_int(ids.size()).is_greater_equal(3)

	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	_reset_spy()
	fa.formation_reassignment_committed.connect(_spy_on_committed)

	var screen: Control = _make_screen()
	await get_tree().process_frame
	_set_orch_state(DungeonRunStateScript.State.NO_RUN)

	# Act.
	screen.call("_on_hero_button_pressed", ids[0])
	await get_tree().process_frame

	# Assert — commit fired, dialog hidden.
	assert_int(_spy_commit_count).override_failure_message(
		"NO_RUN: commit should fire immediately; got %d emissions" % _spy_commit_count
	).is_equal(1)
	var dialog: Control = screen.get_node("MidRunReassignConfirmation") as Control
	assert_bool(dialog.visible).is_false()

	# Cleanup.
	if fa.formation_reassignment_committed.is_connected(_spy_on_committed):
		fa.formation_reassignment_committed.disconnect(_spy_on_committed)
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group B — ACTIVE_FOREGROUND state: dialog shows; commit deferred
# ===========================================================================

# B-01: when orchestrator state is ACTIVE_FOREGROUND (2), tapping a hero
# defers the commit — dialog becomes visible and no signal fires yet.
func test_active_foreground_state_defers_commit_and_shows_dialog() -> void:
	# Arrange.
	var ids: Array[int] = _seed_three_heroes()
	assert_int(ids.size()).is_greater_equal(3)

	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	_reset_spy()
	fa.formation_reassignment_committed.connect(_spy_on_committed)

	var screen: Control = _make_screen()
	await get_tree().process_frame
	_set_orch_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	# Act.
	screen.call("_on_hero_button_pressed", ids[0])
	await get_tree().process_frame

	# Assert — commit did NOT fire; dialog is visible.
	assert_int(_spy_commit_count).override_failure_message(
		"ACTIVE_FOREGROUND: commit should be deferred; got %d emissions" % _spy_commit_count
	).is_equal(0)
	var dialog: Control = screen.get_node("MidRunReassignConfirmation") as Control
	assert_bool(dialog.visible).override_failure_message(
		"ACTIVE_FOREGROUND: confirm dialog should be visible after tap"
	).is_true()

	# Cleanup.
	if fa.formation_reassignment_committed.is_connected(_spy_on_committed):
		fa.formation_reassignment_committed.disconnect(_spy_on_committed)
	screen.queue_free()
	await get_tree().process_frame


# B-02: confirm button on the dialog fires the deferred commit + hides dialog.
func test_confirm_button_runs_deferred_commit() -> void:
	# Arrange.
	var ids: Array[int] = _seed_three_heroes()
	assert_int(ids.size()).is_greater_equal(3)

	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	_reset_spy()
	fa.formation_reassignment_committed.connect(_spy_on_committed)

	var screen: Control = _make_screen()
	await get_tree().process_frame
	_set_orch_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	# Tap to defer.
	screen.call("_on_hero_button_pressed", ids[0])
	await get_tree().process_frame
	assert_int(_spy_commit_count).is_equal(0)  # confirms deferral

	# Drop state to NO_RUN before pressing Confirm. The dialog appeared
	# because the tap occurred during ACTIVE_FOREGROUND; pressing Confirm
	# fires _apply_hero_commit unconditionally regardless of current state.
	# Bypassing orchestrator restart cascade here keeps this test focused
	# on screen behavior — the orchestrator's restart-on-commit logic is
	# tested in tests/integration/dungeon_run_orchestrator/mid_run_reassignment_test.gd.
	_set_orch_state(DungeonRunStateScript.State.NO_RUN)

	# Act — press Confirm.
	screen.call("_on_reassign_confirm_pressed")
	await get_tree().process_frame

	# Assert — commit fired now; dialog hidden.
	assert_int(_spy_commit_count).override_failure_message(
		"Confirm: commit should fire on confirmation; got %d emissions" % _spy_commit_count
	).is_equal(1)
	var dialog: Control = screen.get_node("MidRunReassignConfirmation") as Control
	assert_bool(dialog.visible).is_false()

	# Assert — HeroRoster slot 0 mutated.
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_int(int(roster.call("get_formation_slot", 0))).is_equal(ids[0])

	# Cleanup.
	if fa.formation_reassignment_committed.is_connected(_spy_on_committed):
		fa.formation_reassignment_committed.disconnect(_spy_on_committed)
	screen.queue_free()
	await get_tree().process_frame


# B-03: cancel button on the dialog discards the pending tap — no signal,
# no HeroRoster mutation, dialog hides.
func test_cancel_button_discards_pending_tap() -> void:
	# Arrange.
	var ids: Array[int] = _seed_three_heroes()
	assert_int(ids.size()).is_greater_equal(3)

	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	_reset_spy()
	fa.formation_reassignment_committed.connect(_spy_on_committed)

	var screen: Control = _make_screen()
	await get_tree().process_frame
	_set_orch_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	# Capture slot 0 before to assert no mutation.
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	var slot_0_before: int = int(roster.call("get_formation_slot", 0))

	# Tap to defer.
	screen.call("_on_hero_button_pressed", ids[0])
	await get_tree().process_frame

	# Act — press Cancel.
	screen.call("_on_reassign_cancel_pressed")
	await get_tree().process_frame

	# Assert — no commit; dialog hidden; slot unchanged.
	assert_int(_spy_commit_count).override_failure_message(
		"Cancel: commit should not fire; got %d emissions" % _spy_commit_count
	).is_equal(0)
	var dialog: Control = screen.get_node("MidRunReassignConfirmation") as Control
	assert_bool(dialog.visible).is_false()
	var slot_0_after: int = int(roster.call("get_formation_slot", 0))
	assert_int(slot_0_after).override_failure_message(
		"Cancel: slot 0 must not mutate (before=%d, after=%d)"
		% [slot_0_before, slot_0_after]
	).is_equal(slot_0_before)

	# Cleanup.
	if fa.formation_reassignment_committed.is_connected(_spy_on_committed):
		fa.formation_reassignment_committed.disconnect(_spy_on_committed)
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group C — OFFLINE_REPLAY state also triggers the dialog
# ===========================================================================

# C-01: ACTIVE_OFFLINE_REPLAY (3) is also gated per §C.3 + §G.1.
func test_offline_replay_state_also_defers_commit() -> void:
	# Arrange.
	var ids: Array[int] = _seed_three_heroes()
	assert_int(ids.size()).is_greater_equal(3)

	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	_reset_spy()
	fa.formation_reassignment_committed.connect(_spy_on_committed)

	var screen: Control = _make_screen()
	await get_tree().process_frame
	_set_orch_state(DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY)

	# Act.
	screen.call("_on_hero_button_pressed", ids[0])
	await get_tree().process_frame

	# Assert — deferred.
	assert_int(_spy_commit_count).is_equal(0)
	var dialog: Control = screen.get_node("MidRunReassignConfirmation") as Control
	assert_bool(dialog.visible).is_true()

	# Cleanup.
	if fa.formation_reassignment_committed.is_connected(_spy_on_committed):
		fa.formation_reassignment_committed.disconnect(_spy_on_committed)
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group D — RUN_ENDED state does NOT trigger the dialog
# ===========================================================================

# D-01: RUN_ENDED (4) commits immediately — the run has already ended, no
# consequence to surface.
func test_run_ended_state_commits_immediately() -> void:
	# Arrange.
	var ids: Array[int] = _seed_three_heroes()
	assert_int(ids.size()).is_greater_equal(3)

	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	_reset_spy()
	fa.formation_reassignment_committed.connect(_spy_on_committed)

	var screen: Control = _make_screen()
	await get_tree().process_frame
	_set_orch_state(DungeonRunStateScript.State.RUN_ENDED)

	# Act.
	screen.call("_on_hero_button_pressed", ids[0])
	await get_tree().process_frame

	# Assert — immediate commit.
	assert_int(_spy_commit_count).is_equal(1)
	var dialog: Control = screen.get_node("MidRunReassignConfirmation") as Control
	assert_bool(dialog.visible).is_false()

	# Cleanup.
	if fa.formation_reassignment_committed.is_connected(_spy_on_committed):
		fa.formation_reassignment_committed.disconnect(_spy_on_committed)
	screen.queue_free()
	await get_tree().process_frame
