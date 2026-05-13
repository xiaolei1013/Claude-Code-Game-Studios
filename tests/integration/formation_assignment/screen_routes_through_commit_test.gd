# AC-FA-12 single-write-point regression test for S15-M1.
#
# The formation_assignment screen previously called HeroRoster.set_formation_slot
# directly on each hero-button tap, bypassing the FormationAssignment autoload
# (and therefore the formation_reassignment_committed signal). This weakened
# the single-write-point contract: any subscriber relying on the signal to know
# "the formation just changed" never got the notification when the change came
# from the screen.
#
# This test locks in the S15-M1 refactor:
#   - CI grep: formation_assignment.gd contains NO direct
#     `HeroRoster.set_formation_slot(` call.
#   - Behavioral: invoking the screen's _on_hero_button_pressed handler with a
#     valid hero_id causes FormationAssignment.formation_reassignment_committed
#     to fire exactly once with the correct positional payload.
#
# Pairs with tests/integration/formation_assignment/browse_no_orchestrator_consumption_test.gd
# (AC-FA-09) and tests/unit/formation_assignment/formation_assignment_commit_test.gd
# (AC-FA-04 through AC-FA-08).
#
# S15-M1 — Sprint 15.
extends GdUnitTestSuite

const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const SCREEN_PATH: String = "res://assets/screens/formation_assignment/formation_assignment.tscn"
const SCREEN_SOURCE_PATH: String = "res://assets/screens/formation_assignment/formation_assignment.gd"


# ---------------------------------------------------------------------------
# Hygiene barrier — snapshot live HeroRoster state, restore after each test.
# Mirror formation_assignment_commit_test.gd pattern.
# ---------------------------------------------------------------------------

var _snapshot_roster: Dictionary = {}


func _capture_snapshot() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_snapshot_roster = roster.get_save_data() if roster != null else {}


func _restore_snapshot() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and not _snapshot_roster.is_empty():
		roster.load_save_data(_snapshot_roster)


func before_test() -> void:
	_capture_snapshot()


func after_test() -> void:
	_restore_snapshot()


# ---------------------------------------------------------------------------
# Helper — seed 3 heroes into the roster, return their instance_ids.
# ---------------------------------------------------------------------------

func _seed_three_heroes() -> Array[int]:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(roster).is_not_null()
	var ids: Array[int] = []
	for class_id: String in ["warrior", "mage", "rogue"]:
		var instance: RefCounted = roster.call("add_hero", class_id)
		if instance == null:
			# Class id may not resolve in some test environments; skip but
			# downstream assertions will surface insufficient seed count.
			continue
		ids.append(int(instance.get("instance_id")))
	return ids


# ===========================================================================
# Group A — CI grep: screen has no direct HeroRoster.set_formation_slot call
# ===========================================================================

# A-01: formation_assignment.gd source contains no `HeroRoster.set_formation_slot`
# code-level reference (comments/docstrings allowed for context).
func test_screen_source_has_no_direct_set_formation_slot_call() -> void:
	# Arrange — read the screen source file.
	var file: FileAccess = FileAccess.open(SCREEN_SOURCE_PATH, FileAccess.READ)
	assert_object(file).override_failure_message(
		"Could not open screen source at %s" % SCREEN_SOURCE_PATH
	).is_not_null()
	var src: String = file.get_as_text()
	file.close()

	# Strip comments line-by-line so commentary references are allowed.
	# (Same approach as browse_no_orchestrator_consumption_test.gd.)
	var stripped: PackedStringArray = PackedStringArray()
	for raw_line: String in src.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("#"):
			continue
		stripped.append(line)
	var code_only: String = "\n".join(stripped)

	# AC-FA-12 invariant: zero code-level direct calls. The screen MUST route
	# through FormationAssignment.commit() (which internally calls
	# set_formation_slot per slot). If this fails, the single-write-point
	# contract is violated.
	assert_bool(code_only.contains("HeroRoster.set_formation_slot(")).override_failure_message(
		"AC-FA-12 violation: formation_assignment.gd contains a direct "
		+ "`HeroRoster.set_formation_slot(` call. The screen MUST route writes "
		+ "through FormationAssignment.commit() per formation-assignment-system.md §C.5."
	).is_false()


# ===========================================================================
# Group B — Behavioral: hero-button tap fires the commit signal + writes
# ===========================================================================

# Stateful spy variables (class-level to avoid lambda-capture marshalling issues
# with typed Array signal payloads).
var _spy_emit_count: int = 0
var _spy_last_payload_size: int = -1
var _spy_last_slot_0_id: int = -1


func _spy_on_committed(formation: Variant) -> void:
	_spy_emit_count += 1
	if formation is Array:
		_spy_last_payload_size = (formation as Array).size()
		if _spy_last_payload_size > 0:
			var slot_0: Variant = (formation as Array)[0]
			if slot_0 != null:
				_spy_last_slot_0_id = int(slot_0.get("instance_id"))


func _reset_spy() -> void:
	_spy_emit_count = 0
	_spy_last_payload_size = -1
	_spy_last_slot_0_id = -1


# B-01: invoking _on_hero_button_pressed with a valid hero_id causes
# FormationAssignment.formation_reassignment_committed to fire exactly once
# with the tapped hero at slot 0.
#
# Pattern: instantiate the screen and call _on_hero_button_pressed directly.
# We do NOT call on_enter (avoids cross-autoload signal wiring + cleanup).
# The handler is independent of on_enter wiring — it reads HeroRoster + calls
# FormationAssignment.commit().
func test_hero_button_tap_fires_commit_signal_once() -> void:
	# Arrange — seed + reset spy + connect.
	var ids: Array[int] = _seed_three_heroes()
	assert_int(ids.size()).override_failure_message(
		"Test seed failed: expected 3 heroes, got %d" % ids.size()
	).is_greater_equal(3)

	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	assert_object(fa).is_not_null()
	_reset_spy()
	fa.formation_reassignment_committed.connect(_spy_on_committed)

	# Arrange — instantiate the screen.
	var packed: PackedScene = load(SCREEN_PATH) as PackedScene
	var screen: Control = packed.instantiate() as Control
	add_child(screen)
	await get_tree().process_frame

	# Act.
	screen.call("_on_hero_button_pressed", ids[0])
	await get_tree().process_frame

	# Assert — signal fired exactly once with correct payload.
	assert_int(_spy_emit_count).override_failure_message(
		"AC-FA-12: hero-button tap should fire formation_reassignment_committed "
		+ "exactly once; observed %d emissions." % _spy_emit_count
	).is_equal(1)
	assert_int(_spy_last_payload_size).is_equal(3)
	assert_int(_spy_last_slot_0_id).override_failure_message(
		"Slot 0 of committed payload should be hero id %d; got %d"
		% [ids[0], _spy_last_slot_0_id]
	).is_equal(ids[0])

	# Cleanup.
	if fa.formation_reassignment_committed.is_connected(_spy_on_committed):
		fa.formation_reassignment_committed.disconnect(_spy_on_committed)
	screen.queue_free()
	await get_tree().process_frame


# B-02: regression — refactor preserves the end-state mutation. HeroRoster
# slot 0 should hold the tapped hero post-commit (the prior contract).
func test_hero_button_tap_writes_to_hero_roster_through_commit() -> void:
	# Arrange.
	var ids: Array[int] = _seed_three_heroes()
	assert_int(ids.size()).is_greater_equal(3)

	var packed: PackedScene = load(SCREEN_PATH) as PackedScene
	var screen: Control = packed.instantiate() as Control
	add_child(screen)
	await get_tree().process_frame

	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")

	# Act.
	screen.call("_on_hero_button_pressed", ids[0])
	await get_tree().process_frame

	# Assert — slot 0 holds the tapped hero (post-commit write).
	var slot_0_id: int = int(roster.call("get_formation_slot", 0))
	assert_int(slot_0_id).override_failure_message(
		"Slot 0 should hold hero id %d post-commit; got %d" % [ids[0], slot_0_id]
	).is_equal(ids[0])

	# Cleanup.
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group C — HeroRoster.get_hero_by_id accessor (new in S15-M1)
# ===========================================================================

# C-01: get_hero_by_id returns the HeroInstance for a valid id.
func test_get_hero_by_id_returns_instance_for_valid_id() -> void:
	# Arrange.
	var ids: Array[int] = _seed_three_heroes()
	assert_int(ids.size()).is_greater_equal(1)
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")

	# Act.
	var hero: Variant = roster.call("get_hero_by_id", ids[0])

	# Assert.
	assert_object(hero).is_not_null()
	assert_int(int(hero.get("instance_id"))).is_equal(ids[0])


# C-02: get_hero_by_id returns null for the 0 sentinel (empty slot).
func test_get_hero_by_id_returns_null_for_zero_sentinel() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	var hero: Variant = roster.call("get_hero_by_id", 0)
	assert_object(hero).is_null()


# C-03: get_hero_by_id returns null for an unknown id (never-allocated).
func test_get_hero_by_id_returns_null_for_unknown_id() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	# 999999 is far above any seeded id; verified empty.
	var hero: Variant = roster.call("get_hero_by_id", 999999)
	assert_object(hero).is_null()
