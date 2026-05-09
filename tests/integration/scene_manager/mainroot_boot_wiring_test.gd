# Sprint 11+ tick-system Story 005b — MainRoot production-trigger boot wiring.
#
# Covers AC-1..3, AC-6 of `production/epics/tick-system/story-005b-...md`:
#   - MainRoot under /root invokes SaveLoadSystem.request_full_load("boot")
#     followed by TickSystem.bootstrap_offline_replay() in that order.
#   - MainRoot under a test-suite parent SKIPS the boot wiring.
#   - First-launch path: full signal sequence (first_launch → load_completed →
#     offline_elapsed_seconds(0.0, false)).
#
# AC-4 / AC-5 (missing-autoload diagnostic warnings) are NOT exercised here —
# they're defensive guards that production never reaches. AC-7 (returning-
# launch Formula D.2 path) is implicitly covered by the existing TickSystem
# offline-replay tests; this story's responsibility is wiring + ordering.
# AC-8 regression (existing mainroot_scene_composition_test.gd) is verified
# by running the full save_load + scene_manager suite.
#
# ADR-0005, ADR-0007.
extends GdUnitTestSuite

const MAIN_ROOT_SCENE_PATH: String = "res://src/core/scene_manager/MainRoot.tscn"
const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")

const FIXTURE_SAVE_PATH: String = "user://test_fixture_s5b_mainroot_boot.dat"


# ---------------------------------------------------------------------------
# Hygiene barrier — reset SaveLoadSystem + TickSystem cross-suite state.
# ---------------------------------------------------------------------------

func _reset_save_load_state() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl == null:
		return
	sl._state = SaveLoadScript.State.UNLOADED
	sl.save_file_path = FIXTURE_SAVE_PATH
	sl._needs_rekey_persist = false
	sl._tamper_suspicious_count = 0
	sl._pending_flags_bit0_tamper = false
	sl._meta_slot_index = 0
	sl._meta_save_sequence_number = 0
	var empty_events: Array[int] = []
	sl._meta_backup_restore_events = empty_events


func _reset_tick_system_state() -> void:
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	if ts == null:
		return
	ts._offline_replay_emitted = false
	ts._last_persist_unix = 0
	ts._session_high_water = 0
	ts._flag_suspicious_timestamp = false
	# Warm wall-clock cache so production code path (which reads now_ms) gets
	# a non-zero value. Mirrors the pattern from tamper_detection_test.gd.
	if ts.has_method("_read_wall_clock_unix_time"):
		ts._read_wall_clock_unix_time()


func _delete_fixture_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = FIXTURE_SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func before_test() -> void:
	_reset_save_load_state()
	_reset_tick_system_state()
	_delete_fixture_files()
	_clear_spies()


func after_test() -> void:
	# Free any MainRoot we attached to /root.
	var stray: Node = get_tree().root.get_node_or_null("MainRoot")
	if stray != null:
		get_tree().root.remove_child(stray)
		stray.queue_free()
		await get_tree().process_frame
	_disconnect_spies()
	_reset_save_load_state()
	_reset_tick_system_state()
	_delete_fixture_files()
	# Restore canonical default save_file_path so downstream suites don't
	# inherit the fixture path (test ordering hygiene per S10-S4 lesson).
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl != null:
		sl.save_file_path = "user://save_slot_1.dat"


# ---------------------------------------------------------------------------
# Signal spies — track emission order across SaveLoadSystem + TickSystem.
# ---------------------------------------------------------------------------

var _emission_log: Array[String] = []
var _load_completed_calls: Array[String] = []
var _first_launch_calls: int = 0
var _offline_elapsed_calls: Array[Dictionary] = []


func _on_load_completed(reason: String) -> void:
	_load_completed_calls.append(reason)
	_emission_log.append("load_completed:" + reason)


func _on_first_launch() -> void:
	_first_launch_calls += 1
	_emission_log.append("first_launch")


func _on_offline_elapsed_seconds(elapsed: float, cap_reached: bool) -> void:
	_offline_elapsed_calls.append({"elapsed": elapsed, "cap_reached": cap_reached})
	_emission_log.append("offline_elapsed_seconds:%.1f:%s" % [elapsed, str(cap_reached)])


func _clear_spies() -> void:
	_emission_log.clear()
	_load_completed_calls.clear()
	_first_launch_calls = 0
	_offline_elapsed_calls.clear()


func _connect_spies() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	if sl != null:
		if not sl.load_completed.is_connected(_on_load_completed):
			sl.load_completed.connect(_on_load_completed)
		if not sl.first_launch.is_connected(_on_first_launch):
			sl.first_launch.connect(_on_first_launch)
	if ts != null:
		if not ts.offline_elapsed_seconds.is_connected(_on_offline_elapsed_seconds):
			ts.offline_elapsed_seconds.connect(_on_offline_elapsed_seconds)


func _disconnect_spies() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	if sl != null:
		if sl.load_completed.is_connected(_on_load_completed):
			sl.load_completed.disconnect(_on_load_completed)
		if sl.first_launch.is_connected(_on_first_launch):
			sl.first_launch.disconnect(_on_first_launch)
	if ts != null:
		if ts.offline_elapsed_seconds.is_connected(_on_offline_elapsed_seconds):
			ts.offline_elapsed_seconds.disconnect(_on_offline_elapsed_seconds)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _instantiate_main_root() -> Control:
	var packed: PackedScene = load(MAIN_ROOT_SCENE_PATH) as PackedScene
	assert_object(packed).is_not_null()
	var inst: Control = packed.instantiate() as Control
	assert_object(inst).is_not_null()
	return inst


# ===========================================================================
# Group A — Test-fixture parent SKIPS boot wiring (AC-3)
# ===========================================================================

func test_mainroot_under_test_parent_skips_boot_wiring() -> void:
	# Arrange — connect spies + verify clean baseline.
	_connect_spies()
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	assert_bool(ts._offline_replay_emitted).is_false()

	# Act — add MainRoot under THIS test suite (parent != /root). _ready fires.
	var inst: Control = _instantiate_main_root()
	add_child(inst)
	await get_tree().process_frame

	# Assert — boot wiring did NOT fire. No load_completed, no first_launch,
	# no offline_elapsed_seconds. TickSystem one-shot flag stays false.
	assert_int(_load_completed_calls.size()).is_equal(0)
	assert_int(_first_launch_calls).is_equal(0)
	assert_int(_offline_elapsed_calls.size()).is_equal(0)
	assert_bool(ts._offline_replay_emitted).is_false()

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group B — Production parent INVOKES boot wiring (AC-1, AC-2, AC-6)
# ===========================================================================

func test_mainroot_under_root_invokes_request_full_load_then_bootstrap_offline_replay() -> void:
	# Arrange — clean state; no save file (first-launch path).
	_connect_spies()
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	assert_bool(ts._offline_replay_emitted).is_false()
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH)).is_false()

	# Act — add MainRoot directly under /root (production main-scene mimic).
	var inst: Control = _instantiate_main_root()
	get_tree().root.add_child(inst)
	await get_tree().process_frame

	# Assert — both calls fired:
	# 1. SaveLoadSystem.request_full_load("boot") emitted load_completed.
	assert_int(_load_completed_calls.size()).is_equal(1)
	assert_str(_load_completed_calls[0]).is_equal("boot")
	# 2. TickSystem.bootstrap_offline_replay ran.
	assert_bool(ts._offline_replay_emitted).is_true()


func test_mainroot_under_root_first_launch_emits_full_signal_sequence() -> void:
	# Arrange — clean state, no save file.
	_connect_spies()
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH)).is_false()

	# Act — boot wiring fires.
	var inst: Control = _instantiate_main_root()
	get_tree().root.add_child(inst)
	await get_tree().process_frame

	# Assert — exact signal sequence: first_launch → load_completed("boot") →
	# offline_elapsed_seconds(0.0, false). The full-emission log preserves
	# the order of all three signals across both autoloads.
	assert_int(_first_launch_calls).is_equal(1)
	assert_int(_load_completed_calls.size()).is_equal(1)
	assert_int(_offline_elapsed_calls.size()).is_equal(1)
	assert_float(_offline_elapsed_calls[0]["elapsed"]).is_equal(0.0)
	assert_bool(_offline_elapsed_calls[0]["cap_reached"]).is_false()
	# Order check: emission_log preserves insertion order; first_launch comes
	# before load_completed (both inside SaveLoadSystem.request_full_load),
	# and offline_elapsed_seconds comes after (TickSystem.bootstrap_offline_replay).
	assert_str(_emission_log[0]).is_equal("first_launch")
	assert_str(_emission_log[1]).is_equal("load_completed:boot")
	assert_str(_emission_log[2]).is_equal("offline_elapsed_seconds:0.0:false")


func test_mainroot_under_root_call_order_load_before_bootstrap_offline_replay() -> void:
	# Sanity-check ordering invariant explicitly: bootstrap_offline_replay
	# MUST NOT fire before load_completed, since the replay's anchor reads
	# fields that consumer hydration populates.
	_connect_spies()

	var inst: Control = _instantiate_main_root()
	get_tree().root.add_child(inst)
	await get_tree().process_frame

	# Find indexes of the two markers in emission_log.
	var load_idx: int = -1
	var offline_idx: int = -1
	for i: int in _emission_log.size():
		var entry: String = _emission_log[i]
		if entry.begins_with("load_completed"):
			load_idx = i
		elif entry.begins_with("offline_elapsed_seconds"):
			offline_idx = i

	assert_int(load_idx).is_greater_equal(0)
	assert_int(offline_idx).is_greater_equal(0)
	# offline_elapsed_seconds index MUST be greater than load_completed index.
	assert_int(offline_idx).is_greater(load_idx)


# ===========================================================================
# Group C — Idempotency (one-shot flags survive _ready re-entry)
# ===========================================================================

func test_mainroot_under_root_double_ready_is_safe_idempotent() -> void:
	# Defensive: verify that calling _bootstrap_save_load_and_offline_replay
	# twice on the same MainRoot instance (e.g., simulating a hypothetical
	# scene-tree re-entry) does NOT re-fire either autoload's one-shot logic.
	_connect_spies()

	var inst: Control = _instantiate_main_root()
	get_tree().root.add_child(inst)
	await get_tree().process_frame

	# First boot recorded.
	var first_load_count: int = _load_completed_calls.size()
	var first_offline_count: int = _offline_elapsed_calls.size()
	assert_int(first_load_count).is_equal(1)
	assert_int(first_offline_count).is_equal(1)

	# Act — manual re-invoke. SaveLoadSystem.request_full_load rejects
	# non-UNLOADED state with a push_warning + load_failed; TickSystem
	# bootstrap_offline_replay short-circuits via _offline_replay_emitted.
	# Net effect: load_completed does NOT fire a second time.
	inst.call("_bootstrap_save_load_and_offline_replay")

	# Assert — counts unchanged.
	assert_int(_load_completed_calls.size()).is_equal(first_load_count)
	assert_int(_offline_elapsed_calls.size()).is_equal(first_offline_count)
