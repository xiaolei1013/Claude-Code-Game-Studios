# US-007 — FormationAssignment.commit() behavioral coverage.
#
# Per `design/gdd/formation-assignment-system.md` §C.1 line 65 + §D commit
# ordering invariant: commit() validates the new_formation length, writes
# every slot via HeroRoster.set_formation_slot(), and emits
# `formation_reassignment_committed` AFTER all writes complete.
#
# Coverage gap closed by US-007: prior tests only asserted commit's existence
# (`has_method` check in formation_assignment_skeleton_test.gd Group A) and a
# static-grep enforcement that commit() is the single production caller of
# HeroRoster.set_formation_slot (recruitment_single_writer_ci_grep_test.gd).
# No behavioral test exercised the write-then-emit ordering or the
# length-validation reject branch.
#
# Test groups:
#   A — happy path: 3-hero formation writes all slots + emits signal AFTER
#   B — length-mismatch reject: short/long formation → push_error + no emit
#   C — empty-slot semantics: null entries clear slots (hero_id = 0) + emit
#   D — signal-after-mutation invariant: subscriber sees post-mutation state
#
# Test isolation pattern: live /root/HeroRoster autoload is mutated. Mirrors
# `tests/unit/hero_detail/prestige_button_visibility_test.gd:30` injection +
# after_test cleanup. _formation_slots are captured pre-test and restored on
# teardown so subsequent tests in the suite see a clean roster state.
extends GdUnitTestSuite

const FormationAssignmentScript = preload("res://src/core/formation_assignment/formation_assignment.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


# Spy state — cleared in before_test per
# `feedback_gdunit4_spy_state_not_auto_cleared` (class-level Array spy fields
# persist across tests).
var _committed_calls: Array[Array] = []
var _injected_hero_ids: Array[int] = []
var _saved_formation_slots: Array[int] = []


func _make_fa() -> Node:
	var fa: Node = FormationAssignmentScript.new()
	add_child(fa)
	auto_free(fa)
	return fa


func _inject_hero(id: int, class_id: String) -> HeroInstance:
	var h: HeroInstance = HeroInstanceScript.new()
	h.instance_id = id
	h.class_id = class_id
	HeroRoster._heroes[id] = h
	_injected_hero_ids.append(id)
	return h


func _on_committed(new_formation: Array[HeroInstance]) -> void:
	_committed_calls.append(new_formation)


func before_test() -> void:
	_committed_calls.clear()
	_injected_hero_ids.clear()
	# Snapshot live formation slots so we can restore in teardown.
	_saved_formation_slots.clear()
	for slot: int in HeroRoster._formation_slots:
		_saved_formation_slots.append(slot)


func after_test() -> void:
	# Restore formation slot contents (commit() may have rewritten them).
	for i: int in range(HeroRoster._formation_slots.size()):
		if i < _saved_formation_slots.size():
			HeroRoster._formation_slots[i] = _saved_formation_slots[i]
		else:
			HeroRoster._formation_slots[i] = 0
	# Erase injected synthetic heroes.
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()


# ===========================================================================
# Group A — happy path: 3-hero formation writes all slots + emits signal
# ===========================================================================

func test_commit_with_three_heroes_writes_all_formation_slots() -> void:
	# Arrange — 3 synthetic heroes injected into the live roster.
	var h1: HeroInstance = _inject_hero(9001, "warrior")
	var h2: HeroInstance = _inject_hero(9002, "mage")
	var h3: HeroInstance = _inject_hero(9003, "rogue")
	var formation: Array[HeroInstance] = [h1, h2, h3]
	var fa: Node = _make_fa()

	# Act
	fa.commit(formation)

	# Assert — slots reflect the committed instance_ids in order.
	assert_int(HeroRoster._formation_slots.size()).is_equal(3)
	assert_int(HeroRoster._formation_slots[0]).is_equal(9001)
	assert_int(HeroRoster._formation_slots[1]).is_equal(9002)
	assert_int(HeroRoster._formation_slots[2]).is_equal(9003)


func test_commit_with_three_heroes_emits_reassignment_committed_signal() -> void:
	# Arrange
	var h1: HeroInstance = _inject_hero(9011, "warrior")
	var h2: HeroInstance = _inject_hero(9012, "mage")
	var h3: HeroInstance = _inject_hero(9013, "rogue")
	var formation: Array[HeroInstance] = [h1, h2, h3]
	var fa: Node = _make_fa()
	fa.formation_reassignment_committed.connect(_on_committed)

	# Act
	fa.commit(formation)

	# Assert — exactly one emit, payload matches input formation length.
	assert_int(_committed_calls.size()).is_equal(1)
	assert_int(_committed_calls[0].size()).is_equal(3)


# ===========================================================================
# Group B — length-mismatch reject branch: no write, no emit
# ===========================================================================

func test_commit_with_short_formation_does_not_emit_signal() -> void:
	# Arrange — 2-element formation; HeroRoster.formation_size() == 3 in MVP.
	var h1: HeroInstance = _inject_hero(9021, "warrior")
	var h2: HeroInstance = _inject_hero(9022, "mage")
	var short_formation: Array[HeroInstance] = [h1, h2]
	var fa: Node = _make_fa()
	fa.formation_reassignment_committed.connect(_on_committed)

	# Act — commit pushes an error and bails out of the write+emit path.
	fa.commit(short_formation)

	# Assert — no emit on length mismatch.
	assert_int(_committed_calls.size()).is_equal(0)


func test_commit_with_short_formation_does_not_mutate_formation_slots() -> void:
	# Arrange — capture pre-state (post-snapshot in before_test, may be empty).
	var pre_slots: Array[int] = []
	for slot: int in HeroRoster._formation_slots:
		pre_slots.append(slot)
	var h1: HeroInstance = _inject_hero(9031, "warrior")
	var fa: Node = _make_fa()
	var short_formation: Array[HeroInstance] = [h1]

	# Act
	fa.commit(short_formation)

	# Assert — slot contents unchanged (length-validation gate runs BEFORE
	# the per-slot write loop per §D ordering invariant).
	assert_int(HeroRoster._formation_slots.size()).is_equal(pre_slots.size())
	for i: int in range(pre_slots.size()):
		assert_int(HeroRoster._formation_slots[i]).is_equal(pre_slots[i])


func test_commit_with_oversized_formation_does_not_emit_signal() -> void:
	# Arrange — 4-element formation; size > formation_size() == 3.
	var h1: HeroInstance = _inject_hero(9041, "warrior")
	var h2: HeroInstance = _inject_hero(9042, "mage")
	var h3: HeroInstance = _inject_hero(9043, "rogue")
	var h4: HeroInstance = _inject_hero(9044, "warrior")
	var oversized: Array[HeroInstance] = [h1, h2, h3, h4]
	var fa: Node = _make_fa()
	fa.formation_reassignment_committed.connect(_on_committed)

	# Act
	fa.commit(oversized)

	# Assert — no emit on oversized formation.
	assert_int(_committed_calls.size()).is_equal(0)


# ===========================================================================
# Group C — empty-slot semantics: null entries clear slots (hero_id = 0)
# ===========================================================================

func test_commit_with_all_null_formation_clears_all_slots() -> void:
	# Arrange — pre-seed the formation with real heroes so the clear is
	# observable as a state change rather than a no-op.
	var h1: HeroInstance = _inject_hero(9051, "warrior")
	var h2: HeroInstance = _inject_hero(9052, "mage")
	var h3: HeroInstance = _inject_hero(9053, "rogue")
	HeroRoster._formation_slots[0] = 9051
	HeroRoster._formation_slots[1] = 9052
	HeroRoster._formation_slots[2] = 9053
	var empty_formation: Array[HeroInstance] = [null, null, null]
	var fa: Node = _make_fa()

	# Act
	fa.commit(empty_formation)

	# Assert — all 3 slots cleared (hero_id = 0 sentinel per
	# HeroRoster._formation_slots convention).
	assert_int(HeroRoster._formation_slots[0]).is_equal(0)
	assert_int(HeroRoster._formation_slots[1]).is_equal(0)
	assert_int(HeroRoster._formation_slots[2]).is_equal(0)


func test_commit_with_partial_null_formation_writes_real_and_clears_null() -> void:
	# Arrange — mixed formation: real, null, real.
	var h1: HeroInstance = _inject_hero(9061, "warrior")
	var h3: HeroInstance = _inject_hero(9063, "rogue")
	var formation: Array[HeroInstance] = [h1, null, h3]
	var fa: Node = _make_fa()

	# Act
	fa.commit(formation)

	# Assert — slot 0/2 hold the real heroes, slot 1 is the empty sentinel.
	assert_int(HeroRoster._formation_slots[0]).is_equal(9061)
	assert_int(HeroRoster._formation_slots[1]).is_equal(0)
	assert_int(HeroRoster._formation_slots[2]).is_equal(9063)


func test_commit_with_all_null_formation_still_emits_signal() -> void:
	# Arrange
	var fa: Node = _make_fa()
	fa.formation_reassignment_committed.connect(_on_committed)
	var empty_formation: Array[HeroInstance] = [null, null, null]

	# Act
	fa.commit(empty_formation)

	# Assert — empty-slot commit is a valid commit (length matches);
	# signal fires regardless of slot contents.
	assert_int(_committed_calls.size()).is_equal(1)


# ===========================================================================
# Group D — signal-after-mutation invariant (§D)
# ===========================================================================

# Spy that captures HeroRoster._formation_slots AT signal-emit time. The
# subscriber must observe the post-mutation state per the §D ordering
# invariant ("subscribers see HeroRoster in its post-mutation state when
# their handlers fire"). Using a class-level Array per memory
# `feedback_gdunit4_spy_state_not_auto_cleared`.
var _slots_at_emit_time: Array[int] = []


func _on_committed_capture_slots(_new_formation: Array[HeroInstance]) -> void:
	_slots_at_emit_time.clear()
	for slot: int in HeroRoster._formation_slots:
		_slots_at_emit_time.append(slot)


func test_commit_emits_signal_after_writes_complete() -> void:
	# Arrange — ensure pre-state is empty so the post-state delta is clear.
	var h1: HeroInstance = _inject_hero(9071, "warrior")
	var h2: HeroInstance = _inject_hero(9072, "mage")
	var h3: HeroInstance = _inject_hero(9073, "rogue")
	HeroRoster._formation_slots[0] = 0
	HeroRoster._formation_slots[1] = 0
	HeroRoster._formation_slots[2] = 0
	_slots_at_emit_time.clear()
	var formation: Array[HeroInstance] = [h1, h2, h3]
	var fa: Node = _make_fa()
	fa.formation_reassignment_committed.connect(_on_committed_capture_slots)

	# Act
	fa.commit(formation)

	# Assert — at signal-emit time, all three slot writes were already
	# visible to the subscriber (write-then-emit ordering).
	assert_int(_slots_at_emit_time.size()).is_equal(3)
	assert_int(_slots_at_emit_time[0]).is_equal(9071)
	assert_int(_slots_at_emit_time[1]).is_equal(9072)
	assert_int(_slots_at_emit_time[2]).is_equal(9073)
