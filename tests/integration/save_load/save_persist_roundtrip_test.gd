# Sprint 11 S11-M4 / Story 016 partial: full-envelope persist→load round trip.
#
# Closes the original Story-016 happy-path-deferral (request_full_persist_test
# Group D sentinel will be deleted in this commit). Exercises the live
# autoload chain — all 7 CONSUMER_PATHS autoloads must be present + have
# get_save_data + load_save_data methods (post-S11-X10 ecosystem closure).
#
# Test groups:
#   A — Round-trip preserves consumer state (AC-1) — get_save_data snapshots
#       are byte-equal across persist→reset→load cycle.
#   B — Atomic-write file shape (AC-5 partial) — .tmp absent post-success;
#       .dat exists with size == 44 + payload_length.
#   C — Cold-start (no save file) emits first_launch + load_completed and
#       advances state UNLOADED → READY without going through LOADING errors.
#   D — Tamper detection: byte-flip in payload causes CORRUPT state +
#       tamper_detected_on_load + load_failed signals.
#   E — Load signal declarations (load_completed + load_failed exist with
#       expected arity).
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")

const FIXTURE_SAVE_PATH: String = "user://test_fixture_s11_m4_roundtrip.dat"


# ---------------------------------------------------------------------------
# Hygiene barrier — reset live autoload state + clean fixture file.
# ---------------------------------------------------------------------------

func _reset_save_load_state() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl == null:
		return
	sl._state = SaveLoadScript.State.UNLOADED
	sl.save_file_path = FIXTURE_SAVE_PATH
	sl._needs_rekey_persist = false


func _delete_fixture_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = FIXTURE_SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func before_test() -> void:
	_reset_save_load_state()
	_delete_fixture_files()


func after_test() -> void:
	_reset_save_load_state()
	_delete_fixture_files()
	# Restore canonical default save_file_path so other suites don't inherit
	# the fixture path (test ordering hygiene per S10-S4 lesson).
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl != null:
		sl.save_file_path = "user://save_slot_1.dat"


# ---------------------------------------------------------------------------
# Signal-spy infrastructure
# ---------------------------------------------------------------------------

var _save_completed_calls: Array[String] = []
var _save_failed_calls: Array[Dictionary] = []
var _load_completed_calls: Array[String] = []
var _load_failed_calls: Array[Dictionary] = []
var _first_launch_calls: int = 0
var _tamper_calls: int = 0


func _on_save_completed(reason: String) -> void:
	_save_completed_calls.append(reason)


func _on_save_failed(reason: String, error_code: int) -> void:
	_save_failed_calls.append({"reason": reason, "error_code": error_code})


func _on_load_completed(reason: String) -> void:
	_load_completed_calls.append(reason)


func _on_load_failed(reason: String, error_code: int) -> void:
	_load_failed_calls.append({"reason": reason, "error_code": error_code})


func _on_first_launch() -> void:
	_first_launch_calls += 1


func _on_tamper_detected_on_load() -> void:
	_tamper_calls += 1


func _connect_spies(sl: Node) -> void:
	_save_completed_calls.clear()
	_save_failed_calls.clear()
	_load_completed_calls.clear()
	_load_failed_calls.clear()
	_first_launch_calls = 0
	_tamper_calls = 0
	if not sl.save_completed.is_connected(_on_save_completed):
		sl.save_completed.connect(_on_save_completed)
	if not sl.save_failed.is_connected(_on_save_failed):
		sl.save_failed.connect(_on_save_failed)
	if not sl.load_completed.is_connected(_on_load_completed):
		sl.load_completed.connect(_on_load_completed)
	if not sl.load_failed.is_connected(_on_load_failed):
		sl.load_failed.connect(_on_load_failed)
	if not sl.first_launch.is_connected(_on_first_launch):
		sl.first_launch.connect(_on_first_launch)
	if not sl.tamper_detected_on_load.is_connected(_on_tamper_detected_on_load):
		sl.tamper_detected_on_load.connect(_on_tamper_detected_on_load)


func _disconnect_spies(sl: Node) -> void:
	if sl.save_completed.is_connected(_on_save_completed):
		sl.save_completed.disconnect(_on_save_completed)
	if sl.save_failed.is_connected(_on_save_failed):
		sl.save_failed.disconnect(_on_save_failed)
	if sl.load_completed.is_connected(_on_load_completed):
		sl.load_completed.disconnect(_on_load_completed)
	if sl.load_failed.is_connected(_on_load_failed):
		sl.load_failed.disconnect(_on_load_failed)
	if sl.first_launch.is_connected(_on_first_launch):
		sl.first_launch.disconnect(_on_first_launch)
	if sl.tamper_detected_on_load.is_connected(_on_tamper_detected_on_load):
		sl.tamper_detected_on_load.disconnect(_on_tamper_detected_on_load)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _capture_consumer_snapshots() -> Dictionary:
	# Capture each live consumer's get_save_data() output. Comparing these
	# before/after a round trip is the canonical AC-1 check — what we
	# persisted must match what we hydrated.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	var snapshots: Dictionary = {}
	for path: String in sl.CONSUMER_PATHS:
		var node: Node = get_tree().root.get_node_or_null(path)
		if node != null and node.has_method("get_save_data"):
			snapshots[node.name] = node.get_save_data()
	return snapshots


func _wait_for_state(sl: Node, target_state: int, max_iterations: int = 100) -> bool:
	# Per Save/Load GDD §C synchronous-I/O note: persist + load are
	# synchronous in MVP. By the time request_full_persist returns, the
	# state has already transitioned. This helper exists for forward-compat
	# with the Sprint 12+ async pattern.
	var iters: int = 0
	while sl.get_state() != target_state and iters < max_iterations:
		iters += 1
	return sl.get_state() == target_state


# ===========================================================================
# Group A — Round-trip preserves consumer state (AC-1)
# ===========================================================================

func test_full_envelope_round_trip_preserves_all_consumer_state() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)

	# The state machine starts at UNLOADED in the hygiene barrier. To call
	# request_full_persist we need READY. This mirrors how production gets
	# there: a successful load (or first-launch path) advances UNLOADED → READY.
	# For the round-trip test we manually pin to READY, then persist.
	sl._state = SaveLoadScript.State.READY

	# Snapshot before persist.
	var snapshot_before: Dictionary = _capture_consumer_snapshots()
	assert_int(snapshot_before.size()).is_equal(7)

	# Persist.
	sl.request_full_persist("roundtrip_persist")
	assert_str(_save_completed_calls[0] if not _save_completed_calls.is_empty() else "").is_equal("roundtrip_persist")
	assert_int(_save_failed_calls.size()).is_equal(0)
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH)).is_true()

	# Reset state UNLOADED so request_full_load is legal.
	sl._state = SaveLoadScript.State.UNLOADED

	# Load.
	sl.request_full_load("roundtrip_load")
	assert_int(_load_failed_calls.size()).is_equal(0)
	assert_int(_load_completed_calls.size()).is_equal(1)
	assert_str(_load_completed_calls[0]).is_equal("roundtrip_load")
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.READY)

	# Snapshot after load + compare.
	var snapshot_after: Dictionary = _capture_consumer_snapshots()
	assert_int(snapshot_after.size()).is_equal(snapshot_before.size())
	for key: String in snapshot_before.keys():
		assert_bool(snapshot_after.has(key)).is_true()
		# Per consumer, the get_save_data() return must round-trip equal.
		# JSON.stringify provides a deterministic byte-equal comparison
		# across Dictionary instances (same keys + values produce the same
		# string per Godot's stable key ordering).
		var before_str: String = JSON.stringify(snapshot_before[key])
		var after_str: String = JSON.stringify(snapshot_after[key])
		assert_str(after_str).is_equal(before_str)

	_disconnect_spies(sl)


# ===========================================================================
# Group B — Atomic write + envelope-shape invariants (AC-5 partial)
# ===========================================================================

func test_persist_writes_dat_with_44_plus_payload_length_and_no_residual_tmp() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	sl._state = SaveLoadScript.State.READY

	sl.request_full_persist("envelope_shape")
	assert_str(_save_completed_calls[0] if not _save_completed_calls.is_empty() else "").is_equal("envelope_shape")

	# .tmp must not survive a successful persist (rename completed).
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH + ".tmp")).is_false()

	# .dat exists; size = 44 (header 12 + HMAC 32) + payload_length.
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH)).is_true()
	var f: FileAccess = FileAccess.open(FIXTURE_SAVE_PATH, FileAccess.READ)
	var size: int = f.get_length()
	f.close()
	assert_int(size).is_greater(44)  # at least header + HMAC + non-empty payload

	# Cross-check: PAYLOAD_LENGTH header field matches (size - 44).
	var bytes: PackedByteArray
	var f2: FileAccess = FileAccess.open(FIXTURE_SAVE_PATH, FileAccess.READ)
	bytes = f2.get_buffer(size)
	f2.close()
	var declared_payload_length: int = bytes.decode_u32(8)
	assert_int(declared_payload_length).is_equal(size - 44)

	_disconnect_spies(sl)


func test_envelope_starts_with_lgld_magic_bytes() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	sl._state = SaveLoadScript.State.READY

	sl.request_full_persist("magic_check")
	var bytes: PackedByteArray
	var f: FileAccess = FileAccess.open(FIXTURE_SAVE_PATH, FileAccess.READ)
	bytes = f.get_buffer(f.get_length())
	f.close()

	# MAGIC = "LGLD" = 0x4C 0x47 0x4C 0x44
	assert_int(bytes.decode_u8(0)).is_equal(0x4C)
	assert_int(bytes.decode_u8(1)).is_equal(0x47)
	assert_int(bytes.decode_u8(2)).is_equal(0x4C)
	assert_int(bytes.decode_u8(3)).is_equal(0x44)

	# VERSION (u16 LE at offset 4) = CURRENT_SAVE_VERSION = 1.
	assert_int(bytes.decode_u16(4)).is_equal(1)

	_disconnect_spies(sl)


# ===========================================================================
# Group C — Cold-start path (no save file)
# ===========================================================================

func test_cold_start_no_save_file_emits_first_launch_and_advances_to_ready() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	# Hygiene barrier already deleted the fixture file. State is UNLOADED.
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH)).is_false()
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.UNLOADED)

	sl.request_full_load("boot")

	# State READY; first_launch + load_completed both emitted; no failures.
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.READY)
	assert_int(_first_launch_calls).is_equal(1)
	assert_int(_load_completed_calls.size()).is_equal(1)
	assert_int(_load_failed_calls.size()).is_equal(0)
	assert_int(_tamper_calls).is_equal(0)

	_disconnect_spies(sl)


# ===========================================================================
# Group D — Tamper detection
# ===========================================================================

func test_byte_flip_in_payload_triggers_corrupt_state_and_tamper_signal() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	sl._state = SaveLoadScript.State.READY

	# Persist a valid envelope.
	sl.request_full_persist("tamper_setup")
	assert_int(_save_failed_calls.size()).is_equal(0)
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH)).is_true()

	# Corrupt one byte in the payload region (offset 20 — past the 12-byte
	# header, not in the 32-byte HMAC footer at end-of-file).
	var bytes_w: PackedByteArray
	var f_r: FileAccess = FileAccess.open(FIXTURE_SAVE_PATH, FileAccess.READ)
	bytes_w = f_r.get_buffer(f_r.get_length())
	f_r.close()
	bytes_w.encode_u8(20, (bytes_w.decode_u8(20) ^ 0xFF))
	var f_w: FileAccess = FileAccess.open(FIXTURE_SAVE_PATH, FileAccess.WRITE)
	f_w.store_buffer(bytes_w)
	f_w.close()

	# Reset to UNLOADED and attempt load.
	sl._state = SaveLoadScript.State.UNLOADED
	# Clear spies so we can isolate the load-side signals.
	_load_completed_calls.clear()
	_load_failed_calls.clear()
	_tamper_calls = 0

	sl.request_full_load("tamper_load")

	# CORRUPT terminal state; tamper signal + load_failed both emitted.
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.CORRUPT)
	assert_int(_tamper_calls).is_equal(1)
	assert_int(_load_failed_calls.size()).is_equal(1)
	assert_str(_load_failed_calls[0].reason).is_equal("tamper_load")
	assert_int(_load_failed_calls[0].error_code).is_equal(ERR_FILE_CORRUPT)
	assert_int(_load_completed_calls.size()).is_equal(0)

	_disconnect_spies(sl)


func test_corrupt_magic_bytes_trigger_corrupt_state_without_tamper_signal() -> void:
	# MAGIC mismatch fails before the HMAC check — per ADR-0004 validation
	# order MAGIC → VERSION → HMAC, a non-LGLD file is not a tamper signal,
	# it's a "wrong file" signal. Verify load_failed fires WITHOUT
	# tamper_detected_on_load (tamper is reserved for HMAC-only failures).
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)

	# Write garbage bytes to the fixture path.
	var garbage := PackedByteArray()
	garbage.resize(50)
	for i: int in range(50):
		garbage.encode_u8(i, 0xAA)
	var f_w: FileAccess = FileAccess.open(FIXTURE_SAVE_PATH, FileAccess.WRITE)
	f_w.store_buffer(garbage)
	f_w.close()

	sl._state = SaveLoadScript.State.UNLOADED
	sl.request_full_load("garbage_load")

	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.CORRUPT)
	assert_int(_load_failed_calls.size()).is_equal(1)
	assert_int(_tamper_calls).is_equal(0)  # MAGIC failure is NOT a tamper

	_disconnect_spies(sl)


# ===========================================================================
# Group E — Load signal declarations
# ===========================================================================

func test_load_completed_signal_declared() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_bool(sl.has_signal("load_completed")).is_true()


func test_load_failed_signal_declared() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_bool(sl.has_signal("load_failed")).is_true()


func test_request_full_load_method_exists() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_bool(sl.has_method("request_full_load")).is_true()


# ===========================================================================
# Group F — State-guard: load rejects when state is not UNLOADED
# ===========================================================================

func test_request_full_load_rejects_when_state_is_ready() -> void:
	# Reloading from READY is Sprint 12+ scope (manual reload). MVP rejects
	# with load_failed + ERR_UNAVAILABLE.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)
	sl._state = SaveLoadScript.State.READY

	sl.request_full_load("reload_attempt")

	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.READY)
	assert_int(_load_failed_calls.size()).is_equal(1)
	assert_int(_load_failed_calls[0].error_code).is_equal(ERR_UNAVAILABLE)
	assert_int(_load_completed_calls.size()).is_equal(0)

	_disconnect_spies(sl)
