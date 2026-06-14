# GDD #34 Phase 3 (Defeat & Injury / ADR-0021 — AC-34-09): Formation Assignment
# screen marks injured heroes in BOTH the roster picker and the formation slots
# (fade + "Injured" badge), so the player sees a formation can't dispatch BEFORE
# tapping Dispatch (only Dispatch is gated, AC-34-04). Live-screen integration.
#
# Harness mirrors formation_assignment_screen_test.gd: seed heroes via
# load_save_data (bypasses DataRegistry), instantiate the .tscn + on_enter(),
# snapshot/restore the live HeroRoster autoload between tests.
extends GdUnitTestSuite

const FORMATION_SCREEN_PATH: String = "res://assets/screens/formation_assignment/formation_assignment.tscn"
const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")

const ROSTER_LIST_PATH: String = "RosterPanel/RosterScroll/RosterList"
const SLOTS_HBOX_PATH: String = "FormationPanel/FormationVBox/SlotsHBox"

# 30 minutes in the future, wall-clock ms — comfortably "still injured".
const _INJURY_HORIZON_MS: int = 1800 * 1000


var _hero_roster_save_snapshot: Dictionary = {}


func before_test() -> void:
	_hero_roster_save_snapshot = HeroRoster.get_save_data().duplicate(true)
	HeroRoster.load_save_data({
		"heroes": [],
		"formation_slots": [0, 0, 0],
		"next_instance_id": 1,
	})


func after_test() -> void:
	HeroRoster.load_save_data(_hero_roster_save_snapshot)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Seeds [param count] warriors. Any id in [param injured_ids] gets an
## injured_until 30 minutes in the future; the rest stay healthy (injured_until
## absent → defaults to 0). [param slots] optionally seeds formation_slots.
func _seed_heroes(count: int, injured_ids: Array, slots: Array) -> Array[int]:
	var future_ms: int = TickSystem.now_ms() + _INJURY_HORIZON_MS
	var heroes_arr: Array = []
	var ids: Array[int] = []
	for i: int in range(count):
		var iid: int = i + 1
		var hero_dict: Dictionary = {
			"instance_id": iid,
			"class_id": "warrior",
			"display_name": "Warrior_%d" % iid,
			"current_level": 1,
			"xp": 0,
		}
		if injured_ids.has(iid):
			hero_dict["injured_until"] = future_ms
		heroes_arr.append(hero_dict)
		ids.append(iid)
	HeroRoster.load_save_data({
		"heroes": heroes_arr,
		"formation_slots": slots if not slots.is_empty() else [0, 0, 0],
		"next_instance_id": count + 1,
	})
	return ids


func _navigate_to_formation_screen() -> Control:
	var packed: PackedScene = load(FORMATION_SCREEN_PATH) as PackedScene
	if packed == null:
		return null
	var screen: Control = packed.instantiate() as Control
	add_child(screen)
	auto_free(screen)
	await get_tree().process_frame
	if screen.has_method("on_enter"):
		screen.on_enter()
	return screen


func _count_injured_marks(container: Node) -> int:
	var count: int = 0
	for child: Node in container.get_children():
		if child.get_node_or_null(NodePath(UIFrameworkScript.INJURED_BADGE_NAME)) != null:
			count += 1
	return count


# ===========================================================================
# Group A — roster picker marks injured heroes
# ===========================================================================

func test_injured_hero_in_picker_has_injured_badge() -> void:
	# Arrange — 2 heroes, id 1 injured.
	_seed_heroes(2, [1], [])

	# Act
	var screen: Control = await _navigate_to_formation_screen()
	var roster_list: Node = screen.get_node(ROSTER_LIST_PATH)

	# Assert — exactly one injured mark in the picker.
	assert_int(_count_injured_marks(roster_list)).is_equal(1)


func test_healthy_picker_has_no_injured_badge() -> void:
	# Arrange — 2 healthy heroes.
	_seed_heroes(2, [], [])

	# Act
	var screen: Control = await _navigate_to_formation_screen()
	var roster_list: Node = screen.get_node(ROSTER_LIST_PATH)

	# Assert
	assert_int(_count_injured_marks(roster_list)).is_equal(0)


func test_injured_picker_button_is_dimmed() -> void:
	# Arrange
	_seed_heroes(1, [1], [])

	# Act
	var screen: Control = await _navigate_to_formation_screen()
	var roster_list: Node = screen.get_node(ROSTER_LIST_PATH)

	# Assert — the injured picker button is faded to the injured dim constant.
	var injured_btn: Control = null
	for child: Node in roster_list.get_children():
		if child.get_node_or_null(NodePath(UIFrameworkScript.INJURED_BADGE_NAME)) != null:
			injured_btn = child as Control
			break
	assert_object(injured_btn).is_not_null()
	assert_float(injured_btn.modulate.a).is_equal_approx(
		UIFrameworkScript.INJURED_DIM_ALPHA, 0.001
	)


# ===========================================================================
# Group B — formation slots mark injured occupants
# ===========================================================================

func test_injured_occupant_slot_has_injured_badge() -> void:
	# Arrange — 1 injured hero assigned to slot 0.
	_seed_heroes(1, [1], [1, 0, 0])

	# Act
	var screen: Control = await _navigate_to_formation_screen()
	var slots_hbox: Node = screen.get_node(SLOTS_HBOX_PATH)

	# Assert — exactly one slot carries the injured mark.
	assert_int(_count_injured_marks(slots_hbox)).is_equal(1)


func test_healthy_occupant_slot_has_no_injured_badge() -> void:
	# Arrange — 1 healthy hero assigned to slot 0.
	_seed_heroes(1, [], [1, 0, 0])

	# Act
	var screen: Control = await _navigate_to_formation_screen()
	var slots_hbox: Node = screen.get_node(SLOTS_HBOX_PATH)

	# Assert
	assert_int(_count_injured_marks(slots_hbox)).is_equal(0)


func test_empty_slot_has_no_injured_badge() -> void:
	# Arrange — injured hero exists in roster but is NOT slotted; all slots empty.
	_seed_heroes(1, [1], [0, 0, 0])

	# Act
	var screen: Control = await _navigate_to_formation_screen()
	var slots_hbox: Node = screen.get_node(SLOTS_HBOX_PATH)

	# Assert — no occupant → no slot mark (the picker still marks the hero,
	# but empty slots must never carry an injury badge).
	assert_int(_count_injured_marks(slots_hbox)).is_equal(0)


# ===========================================================================
# Group C — live signal re-marks the screen
# ===========================================================================

func test_heroes_injured_signal_marks_picker_live() -> void:
	# Arrange — render with a healthy roster, hero id 1 slotted.
	var ids: Array[int] = _seed_heroes(1, [], [1, 0, 0])
	var screen: Control = await _navigate_to_formation_screen()
	var roster_list: Node = screen.get_node(ROSTER_LIST_PATH)
	var slots_hbox: Node = screen.get_node(SLOTS_HBOX_PATH)
	assert_int(_count_injured_marks(roster_list)).is_equal(0)
	assert_int(_count_injured_marks(slots_hbox)).is_equal(0)

	# Act — injure the slotted hero while the screen is open.
	HeroRoster.injure_heroes([ids[0]], TickSystem.now_ms() + _INJURY_HORIZON_MS)

	# Assert — both the picker AND the slot re-mark live.
	assert_int(_count_injured_marks(roster_list)).is_equal(1)
	assert_int(_count_injured_marks(slots_hbox)).is_equal(1)
