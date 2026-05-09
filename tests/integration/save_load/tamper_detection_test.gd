# Sprint 11 Story 013 Phase 2 — tamper detection central recovery flow.
#
# Closes ACs 2-6, 9 (the central .bak fallback path) on top of Phase 1's
# peripheral surface (counter + acknowledge_tamper_modal_yes already covered
# by tests/unit/save_load/tamper_counter_and_constants_test.gd, 11/11 PASS).
#
# Test groups:
#   A — _meta round-trip (TR-save-load-018/019/025): persist + load preserves
#       slot_index, save_sequence_number (advanced by +1), tamper_suspicious_count,
#       and backup_restore_events.
#   B — FLAGS.bit0 round-trip (TR-save-load-026): acknowledge_tamper_modal_yes
#       sets pending; next persist writes FLAGS.bit0=1 in envelope header;
#       pending flag clears after save_completed; on next load the header
#       reports FLAGS.bit0=1 (read via _parse_header).
#   C — .bak rotation on persist (ADR-0004 §Atomic write Rule 7): first persist
#       creates .dat only; second persist creates .dat.bak whose bytes match
#       the prior .dat.
#   D — .bak fallback success path (TR-save-load-016): .dat HMAC-corrupted +
#       .bak HMAC-valid → load completes from .bak + bak_recovered_toast
#       emitted exactly once + backup_restore_events appended + tamper_detected_on_load
#       still emits exactly once.
#   E — .bak also-corrupt path (AC-SL-07): .dat corrupted + .bak corrupted →
#       CORRUPT terminal state + load_failed emitted + no consumer hydration.
#
# Tier 2 (DEFERRED to Phase 3 follow-up):
#   - Backup-restore escalation when within-window count >= threshold
#   - Both-Corrupt dedicated signal + acknowledge_corrupt_both_begin() bootstrap
#   - AC-SL-08 DataRegistry ERROR distinct path
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")

const FIXTURE_SAVE_PATH: String = "user://test_fixture_s13_p2_tamper.dat"


# ---------------------------------------------------------------------------
# Hygiene barrier
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
	# Warm TickSystem's wall-clock cache. SaveLoadSystem reads `now_ms()` for
	# the last_persist_ts update + the .bak recovery event timestamp; both
	# require a non-zero cache value. ADR-0005 forbids SaveLoadSystem from
	# calling Time.get_unix_time_from_system() directly, so the test fixture
	# does the cache-warming via TickSystem's owned helper.
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	if ts != null and ts.has_method("_read_wall_clock_unix_time"):
		ts._read_wall_clock_unix_time()


func _delete_fixture_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = FIXTURE_SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func before_test() -> void:
	_reset_save_load_state()
	_delete_fixture_files()
	_clear_spies()


func after_test() -> void:
	_disconnect_spies()
	_reset_save_load_state()
	_delete_fixture_files()
	# Restore canonical default save_file_path so other suites don't inherit
	# the fixture path (test ordering hygiene per S10-S4 lesson).
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl != null:
		sl.save_file_path = "user://save_slot_1.dat"


# ---------------------------------------------------------------------------
# Signal spies
# ---------------------------------------------------------------------------

var _save_completed_calls: Array[String] = []
var _load_completed_calls: Array[String] = []
var _load_failed_calls: Array[Dictionary] = []
var _tamper_calls: int = 0
var _bak_recovered_toast_calls: Array[int] = []
var _storage_advisory_calls: Array[int] = []
var _corrupt_both_modal_calls: int = 0
var _corrupt_both_ack_calls: int = 0
var _data_registry_error_modal_calls: int = 0
var _first_launch_calls: int = 0


func _on_save_completed(reason: String) -> void:
	_save_completed_calls.append(reason)


func _on_load_completed(reason: String) -> void:
	_load_completed_calls.append(reason)


func _on_load_failed(reason: String, error_code: int) -> void:
	_load_failed_calls.append({"reason": reason, "error_code": error_code})


func _on_tamper_detected_on_load() -> void:
	_tamper_calls += 1


func _on_bak_recovered_toast(event_count: int) -> void:
	_bak_recovered_toast_calls.append(event_count)


func _on_storage_advisory_modal_required(event_count: int) -> void:
	_storage_advisory_calls.append(event_count)


func _on_corrupt_both_modal_required() -> void:
	_corrupt_both_modal_calls += 1


func _on_corrupt_both_acknowledged() -> void:
	_corrupt_both_ack_calls += 1


func _on_data_registry_error_modal_required() -> void:
	_data_registry_error_modal_calls += 1


func _on_first_launch() -> void:
	_first_launch_calls += 1


func _clear_spies() -> void:
	_save_completed_calls.clear()
	_load_completed_calls.clear()
	_load_failed_calls.clear()
	_tamper_calls = 0
	_bak_recovered_toast_calls.clear()
	_storage_advisory_calls.clear()
	_corrupt_both_modal_calls = 0
	_corrupt_both_ack_calls = 0
	_data_registry_error_modal_calls = 0
	_first_launch_calls = 0


func _connect_spies(sl: Node) -> void:
	if not sl.save_completed.is_connected(_on_save_completed):
		sl.save_completed.connect(_on_save_completed)
	if not sl.load_completed.is_connected(_on_load_completed):
		sl.load_completed.connect(_on_load_completed)
	if not sl.load_failed.is_connected(_on_load_failed):
		sl.load_failed.connect(_on_load_failed)
	if not sl.tamper_detected_on_load.is_connected(_on_tamper_detected_on_load):
		sl.tamper_detected_on_load.connect(_on_tamper_detected_on_load)
	if not sl.bak_recovered_toast.is_connected(_on_bak_recovered_toast):
		sl.bak_recovered_toast.connect(_on_bak_recovered_toast)
	if not sl.storage_advisory_modal_required.is_connected(_on_storage_advisory_modal_required):
		sl.storage_advisory_modal_required.connect(_on_storage_advisory_modal_required)
	if not sl.corrupt_both_modal_required.is_connected(_on_corrupt_both_modal_required):
		sl.corrupt_both_modal_required.connect(_on_corrupt_both_modal_required)
	if not sl.corrupt_both_acknowledged.is_connected(_on_corrupt_both_acknowledged):
		sl.corrupt_both_acknowledged.connect(_on_corrupt_both_acknowledged)
	if not sl.data_registry_error_modal_required.is_connected(_on_data_registry_error_modal_required):
		sl.data_registry_error_modal_required.connect(_on_data_registry_error_modal_required)
	if not sl.first_launch.is_connected(_on_first_launch):
		sl.first_launch.connect(_on_first_launch)


func _disconnect_spies() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl == null:
		return
	if sl.save_completed.is_connected(_on_save_completed):
		sl.save_completed.disconnect(_on_save_completed)
	if sl.load_completed.is_connected(_on_load_completed):
		sl.load_completed.disconnect(_on_load_completed)
	if sl.load_failed.is_connected(_on_load_failed):
		sl.load_failed.disconnect(_on_load_failed)
	if sl.tamper_detected_on_load.is_connected(_on_tamper_detected_on_load):
		sl.tamper_detected_on_load.disconnect(_on_tamper_detected_on_load)
	if sl.bak_recovered_toast.is_connected(_on_bak_recovered_toast):
		sl.bak_recovered_toast.disconnect(_on_bak_recovered_toast)
	if sl.storage_advisory_modal_required.is_connected(_on_storage_advisory_modal_required):
		sl.storage_advisory_modal_required.disconnect(_on_storage_advisory_modal_required)
	if sl.corrupt_both_modal_required.is_connected(_on_corrupt_both_modal_required):
		sl.corrupt_both_modal_required.disconnect(_on_corrupt_both_modal_required)
	if sl.corrupt_both_acknowledged.is_connected(_on_corrupt_both_acknowledged):
		sl.corrupt_both_acknowledged.disconnect(_on_corrupt_both_acknowledged)
	if sl.data_registry_error_modal_required.is_connected(_on_data_registry_error_modal_required):
		sl.data_registry_error_modal_required.disconnect(_on_data_registry_error_modal_required)
	if sl.first_launch.is_connected(_on_first_launch):
		sl.first_launch.disconnect(_on_first_launch)


# ---------------------------------------------------------------------------
# File-corruption helpers
# ---------------------------------------------------------------------------

## Flips a single byte at [param offset] in the file at [param path].
## Used to make HMAC validation fail without touching MAGIC/VERSION fields
## (so the load pipeline reaches the HMAC step rather than short-circuiting
## at the magic gate).
func _corrupt_byte_at_offset(path: String, offset: int) -> void:
	assert_bool(FileAccess.file_exists(path)).is_true()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	assert_int(bytes.size()).is_greater(offset)
	bytes[offset] = (bytes[offset] ^ 0xFF) & 0xFF
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_object(f).is_not_null()
	f.store_buffer(bytes)
	f.close()


## Persist twice so a `.bak` exists, then optionally corrupt one or both files.
## Returns the SaveLoadSystem node for caller convenience.
func _persist_twice_then_unload(sl: Node) -> void:
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seed_first")
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seed_second")
	sl._state = SaveLoadScript.State.UNLOADED


# ===========================================================================
# Group A — _meta round-trip
# ===========================================================================

func test_meta_round_trip_preserves_tamper_count_and_advances_sequence_number() -> void:
	# Arrange — seed in-memory _meta state.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	sl._tamper_suspicious_count = 7
	sl._meta_slot_index = 0
	sl._meta_save_sequence_number = 41
	sl._state = SaveLoadScript.State.READY

	# Act — persist (sequence advances 41 → 42), reset in-memory, then load.
	sl.request_full_persist("meta_roundtrip_persist")
	assert_int(sl._meta_save_sequence_number).is_equal(42)
	sl._tamper_suspicious_count = 0
	sl._meta_save_sequence_number = 0
	var empty_events: Array[int] = []
	sl._meta_backup_restore_events = empty_events
	sl._state = SaveLoadScript.State.UNLOADED
	sl.request_full_load("meta_roundtrip_load")

	# Assert — _meta restored from disk; tamper_count + sequence_number recovered.
	assert_int(sl._tamper_suspicious_count).is_equal(7)
	assert_int(sl._meta_save_sequence_number).is_equal(42)
	assert_int(sl._meta_slot_index).is_equal(0)
	assert_int(_load_failed_calls.size()).is_equal(0)


func test_meta_save_sequence_number_advances_by_one_per_persist() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	sl._meta_save_sequence_number = 0
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seq_1")
	assert_int(sl._meta_save_sequence_number).is_equal(1)
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seq_2")
	assert_int(sl._meta_save_sequence_number).is_equal(2)
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seq_3")
	assert_int(sl._meta_save_sequence_number).is_equal(3)


func test_meta_backup_restore_events_round_trip_preserves_timestamps() -> void:
	# Arrange — seed events in-memory.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	# Use timestamps within the escalation window so they survive prune.
	# Window is 7 days = 604_800 s. Anchor on a recent fixed-ish value.
	var now_unix: int = int(Time.get_unix_time_from_system())
	var seed_events: Array[int] = [now_unix - 100, now_unix - 50, now_unix - 10]
	sl._meta_backup_restore_events = seed_events.duplicate()
	sl._state = SaveLoadScript.State.READY

	# Act — persist + reset + load.
	sl.request_full_persist("events_roundtrip")
	var empty_events: Array[int] = []
	sl._meta_backup_restore_events = empty_events
	sl._state = SaveLoadScript.State.UNLOADED
	sl.request_full_load("events_roundtrip_load")

	# Assert — all 3 events restored.
	assert_int(sl._meta_backup_restore_events.size()).is_equal(3)
	for ts: int in seed_events:
		assert_bool(sl._meta_backup_restore_events.has(ts)).is_true()


# ===========================================================================
# Group B — FLAGS.bit0 round-trip
# ===========================================================================

func test_acknowledge_tamper_modal_yes_persists_flags_bit0_set_in_envelope_header() -> void:
	# Arrange — set pending tamper intent; persist; verify header FLAGS bit.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	sl._state = SaveLoadScript.State.READY
	sl.acknowledge_tamper_modal_yes()
	assert_bool(sl.get_pending_flags_bit0_tamper()).is_true()

	# Act — persist; the helper writes FLAGS=1 in the envelope header.
	sl.request_full_persist("flags_bit0_persist")

	# Assert — pending flag cleared post-persist (per AC).
	assert_bool(sl.get_pending_flags_bit0_tamper()).is_false()

	# Assert — on-disk envelope header has FLAGS bit0 = 1.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH)
	var parsed: Dictionary = sl._parse_header(bytes)
	assert_int(int(parsed.flags) & 0x1).is_equal(1)


func test_persist_without_pending_flags_writes_envelope_with_flags_bit0_zero() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	# Pending flag explicitly false (default; reset_save_load_state confirms).
	assert_bool(sl.get_pending_flags_bit0_tamper()).is_false()
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("flags_clean_persist")

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH)
	var parsed: Dictionary = sl._parse_header(bytes)
	assert_int(int(parsed.flags) & 0x1).is_equal(0)


# ===========================================================================
# Group C — .bak rotation on persist
# ===========================================================================

func test_first_persist_creates_dat_and_no_bak() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("first_persist")

	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH)).is_true()
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH + ".bak")).is_false()


func test_second_persist_creates_bak_with_prior_dat_bytes() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	# First persist.
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seed_first")
	var dat_after_first: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH)

	# Second persist — should rotate prior .dat into .bak before overwriting.
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seed_second")

	# Assert — .bak now exists and equals the bytes from the first .dat.
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH + ".bak")).is_true()
	var bak_bytes: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH + ".bak")
	assert_int(bak_bytes.size()).is_equal(dat_after_first.size())
	assert_bool(bak_bytes == dat_after_first).is_true()

	# Assert — .dat was overwritten by the second persist (sequence_number advanced
	# so the bytes differ from the first .dat).
	var dat_after_second: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH)
	assert_bool(dat_after_second == dat_after_first).is_false()


# ===========================================================================
# Group D — .bak fallback success path
# ===========================================================================

func test_dat_hmac_fail_with_valid_bak_recovers_via_fallback_path() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	# Seed two persists so .bak exists with valid HMAC.
	_persist_twice_then_unload(sl)
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH + ".bak")).is_true()

	# Corrupt the .dat in its HMAC region (last 32 bytes of envelope) so the
	# load pipeline reaches the .bak fallback after .dat HMAC fails.
	var dat_size: int = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH).size()
	_corrupt_byte_at_offset(FIXTURE_SAVE_PATH, dat_size - 5)

	# Reset spy state immediately before load (the call_deferred re-persist
	# emitted earlier during _persist_twice_then_unload would otherwise leak
	# into our assertions).
	_clear_spies()

	# Act — load. .dat HMAC fails → .bak fallback fires.
	sl.request_full_load("bak_fallback_load")

	# Assert — recovery completed without going CORRUPT.
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.READY)
	assert_int(_load_completed_calls.size()).is_equal(1)
	assert_int(_load_failed_calls.size()).is_equal(0)
	# tamper_detected_on_load fires exactly once (the .dat HMAC fail).
	assert_int(_tamper_calls).is_equal(1)
	# bak_recovered_toast fires exactly once with the within-window count.
	assert_int(_bak_recovered_toast_calls.size()).is_equal(1)
	# After this single .bak recovery, the within-window event count is 1.
	assert_int(_bak_recovered_toast_calls[0]).is_equal(1)
	# A new event timestamp was appended to the in-memory _meta.
	assert_int(sl._meta_backup_restore_events.size()).is_greater_equal(1)


# ===========================================================================
# Group E — .bak also-corrupt path
# ===========================================================================

func test_both_dat_and_bak_corrupt_transitions_to_corrupt_terminal_state() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	# Seed two persists so both .dat and .bak exist.
	_persist_twice_then_unload(sl)
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH + ".bak")).is_true()

	# Corrupt both files in their HMAC regions.
	var dat_size: int = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH).size()
	var bak_size: int = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH + ".bak").size()
	_corrupt_byte_at_offset(FIXTURE_SAVE_PATH, dat_size - 5)
	_corrupt_byte_at_offset(FIXTURE_SAVE_PATH + ".bak", bak_size - 5)

	_clear_spies()

	# Act — load. Both HMAC checks fail → CORRUPT terminal state.
	sl.request_full_load("both_corrupt_load")

	# Assert — CORRUPT state + load_failed emitted + no bak_recovered_toast.
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.CORRUPT)
	assert_int(_load_failed_calls.size()).is_equal(1)
	assert_int(_load_completed_calls.size()).is_equal(0)
	# tamper_detected_on_load still emits (the .dat HMAC fail is still suspicious).
	assert_int(_tamper_calls).is_equal(1)
	# No recovery toast — .bak also failed.
	assert_int(_bak_recovered_toast_calls.size()).is_equal(0)


func test_dat_hmac_fail_with_no_bak_at_all_transitions_to_corrupt() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	# Seed only a single persist — no .bak yet.
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("single_persist")
	sl._state = SaveLoadScript.State.UNLOADED
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH + ".bak")).is_false()

	var dat_size: int = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH).size()
	_corrupt_byte_at_offset(FIXTURE_SAVE_PATH, dat_size - 5)

	_clear_spies()

	# Act — load. .dat HMAC fails, .bak missing → CORRUPT.
	sl.request_full_load("no_bak_load")

	# Assert — CORRUPT terminal state; missing .bak treated identically to
	# .bak HMAC fail per ADR-0004 §`.bak` fallback.
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.CORRUPT)
	assert_int(_load_failed_calls.size()).is_equal(1)
	assert_int(_tamper_calls).is_equal(1)
	assert_int(_bak_recovered_toast_calls.size()).is_equal(0)


# ===========================================================================
# Group F — Phase 2B escalation switch
# ===========================================================================

func test_bak_recovery_at_threshold_emits_storage_advisory_instead_of_toast() -> void:
	# Arrange — seed 2 prior in-window events BEFORE the persists so they
	# end up in both .dat and .bak. After the .bak fallback hydrates [t1, t2]
	# and appends ts_now, count = 3 = BACKUP_ESCALATION_THRESHOLD → escalation.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)

	var ts_now: int = int(Time.get_unix_time_from_system())
	var seed_events: Array[int] = [ts_now - 200, ts_now - 100]
	sl._meta_backup_restore_events = seed_events.duplicate()

	# Persist twice so .dat AND .bak both contain the 2 seeded events.
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seed_first_with_events")
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seed_second_with_events")
	sl._state = SaveLoadScript.State.UNLOADED

	# Corrupt .dat so the load falls back to .bak (which has [t1, t2]).
	var dat_size: int = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH).size()
	_corrupt_byte_at_offset(FIXTURE_SAVE_PATH, dat_size - 5)

	_clear_spies()

	# Act — load. .dat HMAC fails, .bak hydrates [t1, t2], append ts_now → 3.
	sl.request_full_load("escalation_load")

	# Assert — storage advisory fires INSTEAD of the cozy toast.
	assert_int(_storage_advisory_calls.size()).is_equal(1)
	assert_int(_storage_advisory_calls[0]).is_equal(3)
	assert_int(_bak_recovered_toast_calls.size()).is_equal(0)
	# Recovery still completes successfully.
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.READY)
	assert_int(_load_completed_calls.size()).is_equal(1)


func test_bak_recovery_below_threshold_emits_toast_only() -> void:
	# Sanity check: count=2 (one prior + this recovery) stays under the
	# threshold of 3, so cozy toast fires and storage advisory does not.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)

	var ts_now: int = int(Time.get_unix_time_from_system())
	var seed_events: Array[int] = [ts_now - 100]
	sl._meta_backup_restore_events = seed_events.duplicate()

	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seed_first_below")
	sl._state = SaveLoadScript.State.READY
	sl.request_full_persist("seed_second_below")
	sl._state = SaveLoadScript.State.UNLOADED

	var dat_size: int = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH).size()
	_corrupt_byte_at_offset(FIXTURE_SAVE_PATH, dat_size - 5)

	_clear_spies()
	sl.request_full_load("below_threshold_load")

	assert_int(_bak_recovered_toast_calls.size()).is_equal(1)
	assert_int(_bak_recovered_toast_calls[0]).is_equal(2)
	assert_int(_storage_advisory_calls.size()).is_equal(0)


# ===========================================================================
# Group G — Phase 2B Both-Corrupt modal + acknowledge
# ===========================================================================

func test_corrupt_both_emits_corrupt_both_modal_required_signal() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	_persist_twice_then_unload(sl)

	var dat_size: int = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH).size()
	var bak_size: int = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH + ".bak").size()
	_corrupt_byte_at_offset(FIXTURE_SAVE_PATH, dat_size - 5)
	_corrupt_byte_at_offset(FIXTURE_SAVE_PATH + ".bak", bak_size - 5)

	_clear_spies()
	sl.request_full_load("corrupt_both_signal_test")

	# corrupt_both_modal_required emits exactly once.
	assert_int(_corrupt_both_modal_calls).is_equal(1)
	# Both load_failed and tamper_detected_on_load also fire (existing contract).
	assert_int(_load_failed_calls.size()).is_equal(1)
	assert_int(_tamper_calls).is_equal(1)
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.CORRUPT)


func test_acknowledge_corrupt_both_begin_runs_first_launch_bootstrap() -> void:
	# Arrange — drive into CORRUPT via both-corrupt path.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	_persist_twice_then_unload(sl)
	var dat_size: int = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH).size()
	var bak_size: int = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH + ".bak").size()
	_corrupt_byte_at_offset(FIXTURE_SAVE_PATH, dat_size - 5)
	_corrupt_byte_at_offset(FIXTURE_SAVE_PATH + ".bak", bak_size - 5)
	sl.request_full_load("ack_setup_load")
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.CORRUPT)

	_clear_spies()

	# Act — UI taps [Begin].
	sl.acknowledge_corrupt_both_begin()

	# Assert — corrupt_both_acknowledged + first_launch + load_completed fire.
	assert_int(_corrupt_both_ack_calls).is_equal(1)
	assert_int(_first_launch_calls).is_equal(1)
	assert_int(_load_completed_calls.size()).is_equal(1)
	assert_str(_load_completed_calls[0]).is_equal("corrupt_both_begin_bootstrap")
	# State advanced to READY so consumers can apply tutorial defaults.
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.READY)


func test_acknowledge_corrupt_both_begin_resets_meta_to_first_launch_defaults() -> void:
	# Arrange — drive into CORRUPT with non-default _meta state.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	# Seed pre-corrupt state with non-zero _meta values.
	sl._tamper_suspicious_count = 5
	sl._meta_save_sequence_number = 99
	sl._pending_flags_bit0_tamper = true
	var seed_events: Array[int] = [123, 456]
	sl._meta_backup_restore_events = seed_events.duplicate()
	# Force CORRUPT directly (skip the load setup; we're testing reset only).
	sl._state = SaveLoadScript.State.CORRUPT

	_clear_spies()
	sl.acknowledge_corrupt_both_begin()

	# Assert — _meta fields reset to first-launch defaults.
	assert_int(sl._tamper_suspicious_count).is_equal(0)
	assert_int(sl._meta_save_sequence_number).is_equal(0)
	assert_bool(sl._pending_flags_bit0_tamper).is_false()
	assert_int(sl._meta_backup_restore_events.size()).is_equal(0)


func test_acknowledge_corrupt_both_begin_ignored_when_state_not_corrupt() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	# State is UNLOADED (default reset). Calling acknowledge from here is a
	# contract violation — should push_warning + no-op, not crash.
	sl._state = SaveLoadScript.State.UNLOADED

	_clear_spies()
	sl.acknowledge_corrupt_both_begin()

	# No signals fired; state unchanged.
	assert_int(_corrupt_both_ack_calls).is_equal(0)
	assert_int(_first_launch_calls).is_equal(0)
	assert_int(_load_completed_calls.size()).is_equal(0)
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.UNLOADED)


# ===========================================================================
# Group H — Phase 2B AC-SL-08 DataRegistry ERROR distinct path
# ===========================================================================

func test_data_registry_error_at_load_emits_modal_required_and_aborts() -> void:
	# Arrange — drive DataRegistry into ERROR state, then request_full_load.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	var dr: Node = get_tree().root.get_node_or_null("DataRegistry")
	assert_object(dr).is_not_null()
	# Save original state to restore in cleanup.
	var dr_original_state: int = dr.state
	dr.state = dr.State.ERROR

	# Seed a save file so the test confirms NO FS writes happen
	# (file should be byte-identical pre-/post-call).
	# We can't run the persist path with DataRegistry in ERROR (consumers
	# won't have valid data), so we manually write a placeholder file and
	# capture its bytes.
	var placeholder: PackedByteArray = PackedByteArray([0x00, 0x01, 0x02, 0x03, 0x04])
	var f: FileAccess = FileAccess.open(FIXTURE_SAVE_PATH, FileAccess.WRITE)
	f.store_buffer(placeholder)
	f.close()
	var pre_bytes: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH)

	_connect_spies(sl)
	_clear_spies()
	sl._state = SaveLoadScript.State.UNLOADED

	# Act — request_full_load. Should short-circuit at the DataRegistry check.
	sl.request_full_load("data_registry_error_load")

	# Assert — distinct modal signal fires; no tamper signal; load_failed fires.
	assert_int(_data_registry_error_modal_calls).is_equal(1)
	assert_int(_tamper_calls).is_equal(0)
	assert_int(_load_failed_calls.size()).is_equal(1)
	assert_int(_load_completed_calls.size()).is_equal(0)
	# State went CORRUPT (terminal load failure path).
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.CORRUPT)
	# Save file untouched (byte-identical to pre-call).
	var post_bytes: PackedByteArray = FileAccess.get_file_as_bytes(FIXTURE_SAVE_PATH)
	assert_int(post_bytes.size()).is_equal(pre_bytes.size())
	assert_bool(post_bytes == pre_bytes).is_true()
	# No .bak written.
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH + ".bak")).is_false()

	# Cleanup — restore DataRegistry state for downstream tests.
	dr.state = dr_original_state
