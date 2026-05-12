# FormationAssignment.commit() contract tests covering AC-FA-04 through
# AC-FA-08 per formation-assignment-system.md §H. Uses live
# /root/FormationAssignment + /root/HeroRoster with snapshot/restore
# isolation (recruitment_try_recruit_test.gd precedent).
#
# Test groups:
#   A — AC-FA-04: browse(formation) does NOT mutate HeroRoster
#   B — AC-FA-05: commit(formation) writes set_formation_slot per slot in order
#   C — AC-FA-06: signal fires AFTER all slot writes complete
#   D — AC-FA-07: length validation rejects mismatched array, no write, no emit
#   E — AC-FA-08: abort on set_formation_slot returning false; no further writes; no signal
extends GdUnitTestSuite

const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


# ---------------------------------------------------------------------------
# Hygiene barrier — snapshot live HeroRoster state, restore after each test.
# ---------------------------------------------------------------------------

var _snapshot_roster: Dictionary = {}
var _seeded_ids: Array[int] = []


func _capture_snapshot() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_snapshot_roster = roster.get_save_data() if roster != null else {}


func _restore_snapshot() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and not _snapshot_roster.is_empty():
		roster.load_save_data(_snapshot_roster)


func before_test() -> void:
	_capture_snapshot()
	_seeded_ids = []


func after_test() -> void:
	_restore_snapshot()


# ---------------------------------------------------------------------------
# Seed helpers — populate roster with 3 heroes (instance_ids returned).
# ---------------------------------------------------------------------------

## Seeds the live roster with N heroes of given class_id. Returns their
## instance_ids in seeded order. Caller is responsible for ensuring the
## DataRegistry resolves the class_id (warrior/mage/rogue are MVP-canonical).
func _seed_heroes(roster: Node, class_id: String, count: int) -> Array[int]:
	var ids: Array[int] = []
	for i: int in range(count):
		var instance: RefCounted = roster.call("add_hero", class_id)
		if instance == null:
			# Skip if class_id unresolvable in this test env — caller asserts
			# downstream. (Mirrors the recruitment-test pattern.)
			continue
		var id: int = int(instance.get("instance_id"))
		ids.append(id)
		_seeded_ids.append(id)
	return ids


## Resolves a HeroInstance by instance_id from the live roster's
## get_all_heroes array. Returns null if id absent.
func _find_hero(roster: Node, instance_id: int) -> HeroInstance:
	var heroes: Array = roster.call("get_all_heroes")
	for h_v: Variant in heroes:
		var h: RefCounted = h_v as RefCounted
		if h != null and int(h.get("instance_id")) == instance_id:
			return h as HeroInstance
	return null


# ===========================================================================
# Group A — AC-FA-04: browse(formation) does NOT mutate HeroRoster
# ===========================================================================

func test_browse_does_not_mutate_hero_roster_formation_slots() -> void:
	# Arrange — seed 3 warriors, capture pre-browse formation snapshot.
	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(fa).is_not_null()
	assert_object(roster).is_not_null()

	var ids: Array[int] = _seed_heroes(roster, "warrior", 3)
	if ids.size() < 3:
		# Test env without warrior class registered — skip via early return
		# with an assertion that documents the skip rather than silently passing.
		assert_int(ids.size()).is_equal(3)
		return

	var pre_slots: Array = roster.call("get_save_data").get("formation_slots", []) as Array

	# Build a formation array (use the seeded heroes as the "displayed" state).
	var formation: Array[HeroInstance] = [
		_find_hero(roster, ids[0]),
		_find_hero(roster, ids[1]),
		_find_hero(roster, ids[2]),
	]

	# Act — browse with the formation.
	fa.call("browse", formation)

	# Assert — formation_slots unchanged (AC-FA-04).
	var post_slots: Array = roster.call("get_save_data").get("formation_slots", []) as Array
	assert_array(post_slots).is_equal(pre_slots)


# ===========================================================================
# Group B — AC-FA-05: commit(formation) writes set_formation_slot per slot in order
# ===========================================================================

func test_commit_writes_each_slot_in_order_with_correct_hero_ids() -> void:
	# Arrange — seed 3 heroes; commit a formation with them in slots 0/1/2.
	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(fa).is_not_null()
	assert_object(roster).is_not_null()

	var ids: Array[int] = _seed_heroes(roster, "warrior", 3)
	if ids.size() < 3:
		assert_int(ids.size()).is_equal(3)
		return

	# Start with empty formation slots.
	for i: int in range(3):
		roster.call("set_formation_slot", i, 0)

	var formation: Array[HeroInstance] = [
		_find_hero(roster, ids[0]),
		_find_hero(roster, ids[1]),
		_find_hero(roster, ids[2]),
	]

	# Act — commit the formation.
	fa.call("commit", formation)

	# Assert — formation_slots reflect the committed order (AC-FA-05).
	var post_slots: Array = roster.call("get_save_data").get("formation_slots", []) as Array
	assert_int(post_slots.size()).is_equal(3)
	assert_int(int(post_slots[0])).is_equal(ids[0])
	assert_int(int(post_slots[1])).is_equal(ids[1])
	assert_int(int(post_slots[2])).is_equal(ids[2])


func test_commit_with_null_slot_writes_zero_for_empty_slot() -> void:
	# AC-FA-05 corollary: null HeroInstance entries become slot 0 (empty).
	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")

	var ids: Array[int] = _seed_heroes(roster, "warrior", 2)
	if ids.size() < 2:
		assert_int(ids.size()).is_equal(2)
		return

	# Seed slot 2 with id 999 (fake) — must use a valid id to seed; use ids[0]
	# in slot 2 first, then call commit with null in slot 2 to verify clearing.
	# Actually simpler: just commit [hero_a, hero_b, null] from a clean state.
	for i: int in range(3):
		roster.call("set_formation_slot", i, 0)

	var formation: Array[HeroInstance] = [
		_find_hero(roster, ids[0]),
		_find_hero(roster, ids[1]),
		null,
	]
	fa.call("commit", formation)

	var post_slots: Array = roster.call("get_save_data").get("formation_slots", []) as Array
	assert_int(int(post_slots[0])).is_equal(ids[0])
	assert_int(int(post_slots[1])).is_equal(ids[1])
	assert_int(int(post_slots[2])).is_equal(0)


# ===========================================================================
# Group C — AC-FA-06: signal fires AFTER all slot writes complete
# ===========================================================================

# Lambda-capture spy that records HeroRoster.formation_slots state AT
# signal-fire time. AC-FA-06's invariant: by the time the subscriber's
# handler runs, all set_formation_slot writes have completed.
var _signal_payload_at_fire_time: Array[HeroInstance] = []
var _roster_slots_at_fire_time: Array = []
var _signal_fire_count: int = 0


func _on_committed_capture_state(new_formation: Array[HeroInstance]) -> void:
	# Capture the formation_slots state at fire time — this is the load-bearing
	# AC-FA-06 invariant assertion.
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_signal_payload_at_fire_time = new_formation.duplicate()
	_roster_slots_at_fire_time = roster.call("get_save_data").get("formation_slots", []) as Array
	_signal_fire_count += 1


func test_commit_signal_fires_after_all_writes_complete() -> void:
	# Arrange — seed 3 heroes, connect a spy that captures roster state at fire time.
	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")

	var ids: Array[int] = _seed_heroes(roster, "warrior", 3)
	if ids.size() < 3:
		assert_int(ids.size()).is_equal(3)
		return

	# Start with empty formation slots.
	for i: int in range(3):
		roster.call("set_formation_slot", i, 0)

	_signal_payload_at_fire_time = []
	_roster_slots_at_fire_time = []
	_signal_fire_count = 0
	fa.formation_reassignment_committed.connect(_on_committed_capture_state)

	var formation: Array[HeroInstance] = [
		_find_hero(roster, ids[0]),
		_find_hero(roster, ids[1]),
		_find_hero(roster, ids[2]),
	]

	# Act — commit; the spy captures roster state at fire time.
	fa.call("commit", formation)

	# Assert — signal fired exactly once with the post-mutation state visible.
	assert_int(_signal_fire_count).is_equal(1)
	assert_int(_signal_payload_at_fire_time.size()).is_equal(3)

	# AC-FA-06 invariant: at fire time, formation_slots already reflect the
	# new state (NOT a half-mutated state).
	assert_int(_roster_slots_at_fire_time.size()).is_equal(3)
	assert_int(int(_roster_slots_at_fire_time[0])).is_equal(ids[0])
	assert_int(int(_roster_slots_at_fire_time[1])).is_equal(ids[1])
	assert_int(int(_roster_slots_at_fire_time[2])).is_equal(ids[2])

	# Cleanup — disconnect spy to avoid cross-test leakage.
	if fa.formation_reassignment_committed.is_connected(_on_committed_capture_state):
		fa.formation_reassignment_committed.disconnect(_on_committed_capture_state)


# ===========================================================================
# Group D — AC-FA-07: length validation rejects mismatched array
# ===========================================================================

func test_commit_with_undersize_formation_rejects_no_write_no_emit() -> void:
	# Arrange — seed 2 heroes; build a 2-element formation array (vs
	# formation_size() == 3 in MVP).
	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")

	var ids: Array[int] = _seed_heroes(roster, "warrior", 2)
	if ids.size() < 2:
		assert_int(ids.size()).is_equal(2)
		return

	# Snapshot pre-commit state.
	var pre_slots: Array = roster.call("get_save_data").get("formation_slots", []) as Array

	_signal_fire_count = 0
	fa.formation_reassignment_committed.connect(_on_committed_capture_state)

	# Build a 2-element array — size mismatch with formation_size() == 3.
	var bad_formation: Array[HeroInstance] = [
		_find_hero(roster, ids[0]),
		_find_hero(roster, ids[1]),
	]

	# Act — commit with the mismatched-size array. Per AC-FA-07, this should
	# push_error and return without writing or emitting.
	fa.call("commit", bad_formation)

	# Assert — no slot writes (formation_slots unchanged), no signal emit.
	var post_slots: Array = roster.call("get_save_data").get("formation_slots", []) as Array
	assert_array(post_slots).is_equal(pre_slots)
	assert_int(_signal_fire_count).is_equal(0)

	if fa.formation_reassignment_committed.is_connected(_on_committed_capture_state):
		fa.formation_reassignment_committed.disconnect(_on_committed_capture_state)


func test_commit_with_oversize_formation_rejects_no_write_no_emit() -> void:
	# AC-FA-07 corollary: 4-element array also rejected (size > formation_size()).
	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")

	var ids: Array[int] = _seed_heroes(roster, "warrior", 3)
	if ids.size() < 3:
		assert_int(ids.size()).is_equal(3)
		return

	var pre_slots: Array = roster.call("get_save_data").get("formation_slots", []) as Array

	_signal_fire_count = 0
	fa.formation_reassignment_committed.connect(_on_committed_capture_state)

	# 4-element array — size mismatch.
	var bad_formation: Array[HeroInstance] = [
		_find_hero(roster, ids[0]),
		_find_hero(roster, ids[1]),
		_find_hero(roster, ids[2]),
		null,
	]
	fa.call("commit", bad_formation)

	var post_slots: Array = roster.call("get_save_data").get("formation_slots", []) as Array
	assert_array(post_slots).is_equal(pre_slots)
	assert_int(_signal_fire_count).is_equal(0)

	if fa.formation_reassignment_committed.is_connected(_on_committed_capture_state):
		fa.formation_reassignment_committed.disconnect(_on_committed_capture_state)


# ===========================================================================
# Group E — AC-FA-08: abort on invalid hero_id mid-write
# ===========================================================================

func test_commit_aborts_when_set_formation_slot_rejects_invalid_hero_id() -> void:
	# Arrange — seed 2 heroes; build a formation with a SYNTHETIC HeroInstance
	# whose instance_id is NOT in HeroRoster._heroes (simulates "hero X not in
	# roster"). set_formation_slot returns false for unknown hero_id per
	# hero_roster.gd:819-824 — that triggers AC-FA-08 abort.
	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")

	var ids: Array[int] = _seed_heroes(roster, "warrior", 2)
	if ids.size() < 2:
		assert_int(ids.size()).is_equal(2)
		return

	# Synthetic hero with an instance_id NOT in the live roster. Use a value
	# guaranteed-not-to-collide with any seeded id (use ids[1] + 999999).
	var phantom_id: int = ids[1] + 999999
	var phantom: HeroInstance = HeroInstanceScript.new()
	phantom.instance_id = phantom_id
	phantom.class_id = "warrior"

	# Start with empty formation slots so the abort leaves an observable
	# partial-write state: slot 0 written (real hero), slot 1 reject,
	# slot 2 NOT attempted.
	for i: int in range(3):
		roster.call("set_formation_slot", i, 0)

	_signal_fire_count = 0
	fa.formation_reassignment_committed.connect(_on_committed_capture_state)

	# Build the formation: real hero, phantom (rejected), real hero. The
	# phantom in slot 1 triggers set_formation_slot → false, aborting before
	# slot 2 is attempted. push_error is logged.
	var formation: Array[HeroInstance] = [
		_find_hero(roster, ids[0]),
		phantom,
		_find_hero(roster, ids[1]),
	]

	# Act — commit; expect AC-FA-08 abort behavior.
	fa.call("commit", formation)

	# Assert — slot 0 written; slot 1 NOT written (still 0); slot 2 NOT attempted (still 0).
	var post_slots: Array = roster.call("get_save_data").get("formation_slots", []) as Array
	assert_int(post_slots.size()).is_equal(3)
	assert_int(int(post_slots[0])).is_equal(ids[0])
	assert_int(int(post_slots[1])).is_equal(0)
	assert_int(int(post_slots[2])).is_equal(0)

	# AC-FA-08 invariant: signal did NOT emit (no formation_reassignment_committed).
	assert_int(_signal_fire_count).is_equal(0)

	if fa.formation_reassignment_committed.is_connected(_on_committed_capture_state):
		fa.formation_reassignment_committed.disconnect(_on_committed_capture_state)
