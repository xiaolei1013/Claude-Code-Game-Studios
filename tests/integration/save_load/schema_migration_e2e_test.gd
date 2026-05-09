# Story 010 follow-up (S18-N4): end-to-end forged-envelope migration test.
#
# The unit-level Group A/B tests in tests/unit/save_load/schema_migration_test.gd
# cover the migration chain stub + state machine in isolation. This integration
# test forges a save envelope with VERSION=0 (a hypothetical pre-MVP build)
# whose HMAC validates against the current-build integrity tag, then drops it
# at the SaveLoadSystem fixture path and exercises the full request_full_load
# pipeline. Verifies that:
#   - VERSION < CURRENT_SAVE_VERSION triggers the LOADING → MIGRATION transition
#     mid-pipeline (after MAGIC + HMAC + JSON validation pass).
#   - _run_migration_chain returns null for any unauthored version step
#     (MVP placeholder behavior; only same-version no-op exists).
#   - MIGRATION → CORRUPT transition fires when the chain returns null.
#   - load_failed signal emits with the migration-failure error message;
#     tamper_detected_on_load does NOT emit (HMAC was valid — this isn't
#     a tamper scenario).
#
# Forging strategy: use the live autoload's private envelope-construction
# primitives (_derive_mask_seed, _generate_mask, _apply_xor_mask,
# _compose_header, _derive_integrity_tags, _integrity_wrap) so the resulting
# envelope passes every validation gate up to the version check. The forged
# envelope's payload is an empty Dict — consumer hydration is bypassed
# because the migration branch returns null before reaching step 7.
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")

const FIXTURE_SAVE_PATH: String = "user://test_fixture_s18_n4_migration.dat"
const FORGED_VERSION: int = 0  # any value < CURRENT_SAVE_VERSION (1) triggers migration


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
	# Reset spy state — gdunit4 does NOT auto-clear class-level fields
	# between tests, so accumulated spy calls from a previous test bleed
	# into the next assertion otherwise. Pattern lifted from
	# save_persist_roundtrip_test.gd's mid-test clear()s, hoisted into
	# before_test for this suite.
	_load_failed_calls.clear()
	_load_completed_calls.clear()
	_tamper_calls = 0


func after_test() -> void:
	_reset_save_load_state()
	_delete_fixture_files()
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl != null:
		sl.save_file_path = "user://save_slot_1.dat"


# ---------------------------------------------------------------------------
# Signal-spy infrastructure — narrower than save_persist_roundtrip_test's;
# only the load-side signals are relevant for the migration scenario.
# ---------------------------------------------------------------------------

var _load_failed_calls: Array[Dictionary] = []
var _load_completed_calls: Array[String] = []
var _tamper_calls: int = 0


func _on_load_failed(reason: String, error_code: int) -> void:
	_load_failed_calls.append({"reason": reason, "error_code": error_code})


func _on_load_completed(reason: String) -> void:
	_load_completed_calls.append(reason)


func _on_tamper_detected_on_load() -> void:
	_tamper_calls += 1


func _connect_spies(sl: Node) -> void:
	if not sl.load_failed.is_connected(_on_load_failed):
		sl.load_failed.connect(_on_load_failed)
	if not sl.load_completed.is_connected(_on_load_completed):
		sl.load_completed.connect(_on_load_completed)
	if not sl.tamper_detected_on_load.is_connected(_on_tamper_detected_on_load):
		sl.tamper_detected_on_load.connect(_on_tamper_detected_on_load)


func _disconnect_spies(sl: Node) -> void:
	if sl.load_failed.is_connected(_on_load_failed):
		sl.load_failed.disconnect(_on_load_failed)
	if sl.load_completed.is_connected(_on_load_completed):
		sl.load_completed.disconnect(_on_load_completed)
	if sl.tamper_detected_on_load.is_connected(_on_tamper_detected_on_load):
		sl.tamper_detected_on_load.disconnect(_on_tamper_detected_on_load)


# ---------------------------------------------------------------------------
# Envelope forgery — uses the live autoload's private primitives so the
# forged envelope passes every gate (MAGIC + payload-length + HMAC + JSON)
# up to the version check.
# ---------------------------------------------------------------------------

# Builds a VERSION=FORGED_VERSION envelope with a valid HMAC over (header +
# masked_payload). Payload is an empty Dict ({}) — consumer hydration is
# bypassed because the migration branch returns null before reaching that
# step. Returns the raw envelope bytes ready for FileAccess.store_buffer.
func _forge_envelope_with_version(sl: Node, version: int) -> PackedByteArray:
	# 1. Plaintext payload — empty top-level Dict.
	var json_string: String = JSON.stringify({})
	var plaintext: PackedByteArray = json_string.to_utf8_buffer()

	# 2. XOR mask using the FORGED version (the loader uses the file's
	#    version field to derive the mask seed at line 669).
	var mask_seed: PackedByteArray = sl._derive_mask_seed(version)
	var mask: PackedByteArray = sl._generate_mask(mask_seed, plaintext.size())
	var masked_payload: PackedByteArray = sl._apply_xor_mask(plaintext, mask)

	# 3. Compose header with FORGED version. _compose_envelope hardcodes
	#    CURRENT_SAVE_VERSION so we cannot reuse it; build the header
	#    directly via the version-parameterized _compose_header.
	var header: PackedByteArray = sl._compose_header(version, 0, masked_payload.size())

	# 4. Assemble: header + masked_payload + zero-padded HMAC placeholder.
	var hmac_placeholder := PackedByteArray()
	hmac_placeholder.resize(32)  # _HMAC_SIZE
	var envelope := PackedByteArray()
	envelope.append_array(header)
	envelope.append_array(masked_payload)
	envelope.append_array(hmac_placeholder)

	# 5. Compute HMAC over (header + masked_payload) using current-build tag.
	#    The loader checks against the current-build tag first (matches_current)
	#    so signing under tags[0] is sufficient.
	var tags: Array[PackedByteArray] = sl._derive_integrity_tags()
	var hmac_input: PackedByteArray = envelope.slice(0, envelope.size() - 32)
	var hmac: PackedByteArray = sl._integrity_wrap(tags[0], hmac_input)

	# 6. Overwrite the zero placeholder with the real HMAC.
	for i: int in 32:
		envelope.encode_u8(envelope.size() - 32 + i, hmac.decode_u8(i))

	return envelope


func _write_envelope_to_fixture(envelope: PackedByteArray) -> void:
	var f_w: FileAccess = FileAccess.open(FIXTURE_SAVE_PATH, FileAccess.WRITE)
	f_w.store_buffer(envelope)
	f_w.close()


# ===========================================================================
# Group A — VERSION < CURRENT_SAVE_VERSION enters MIGRATION → CORRUPT
# ===========================================================================

# The end-to-end happy path for the failure scenario: forged V0 envelope
# passes MAGIC + HMAC + JSON parse, enters MIGRATION on the version check,
# chain returns null (no v0→v1 migration authored), transitions to CORRUPT,
# emits load_failed without firing tamper signal.
func test_forged_v0_envelope_triggers_migration_then_corrupt_on_null_chain() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_object(sl).is_not_null()
	_connect_spies(sl)

	# Forge + drop the V0 envelope at the fixture path.
	var envelope: PackedByteArray = _forge_envelope_with_version(sl, FORGED_VERSION)
	_write_envelope_to_fixture(envelope)
	assert_bool(FileAccess.file_exists(FIXTURE_SAVE_PATH)).is_true()

	# Trigger the load pipeline.
	sl.request_full_load("forged_v0_migration_test")

	# Terminal state: CORRUPT (MIGRATION chain returned null → fall through).
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.CORRUPT)
	# load_failed emitted exactly once with the test's reason.
	assert_int(_load_failed_calls.size()).is_equal(1)
	assert_str(_load_failed_calls[0].reason).is_equal("forged_v0_migration_test")
	assert_int(_load_failed_calls[0].error_code).is_equal(ERR_FILE_CORRUPT)
	# load_completed must NOT emit (the load did not succeed).
	assert_int(_load_completed_calls.size()).is_equal(0)
	# Tamper signal must NOT emit — HMAC was valid; this is a schema-version
	# failure, not a tamper. Per ADR-0004 the tamper signal is reserved for
	# HMAC-only failures.
	assert_int(_tamper_calls).is_equal(0)

	_disconnect_spies(sl)


# Sanity: forged V99 (future-version) envelope rejects EARLY at the version
# check, before HMAC/JSON parse even runs. The version > CURRENT path
# emits load_failed with detail='version_future' and does NOT enter MIGRATION.
#
# Test renamed from `_v2_` → `_v99_future_` after Sprint 21+ Prestige V1.0
# Story 2 bumped CURRENT_SAVE_VERSION 1→2: V2 is no longer "future". Use
# V99 as a clearly-future value that no foreseeable migration will ever
# reach.
func test_forged_v99_envelope_rejects_early_with_version_future() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)

	# Forge a V99 envelope (any value > CURRENT_SAVE_VERSION = 2).
	var envelope: PackedByteArray = _forge_envelope_with_version(sl, 99)
	_write_envelope_to_fixture(envelope)

	sl.request_full_load("forged_v99_future_test")

	# Terminal state: CORRUPT (early reject at the version check).
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.CORRUPT)
	assert_int(_load_failed_calls.size()).is_equal(1)
	assert_int(_load_completed_calls.size()).is_equal(0)
	# Tamper does NOT fire — version-future is not a tamper.
	assert_int(_tamper_calls).is_equal(0)

	_disconnect_spies(sl)


# Sprint 21+ Prestige V1.0 Story 2 (2026-05-09): CURRENT_SAVE_VERSION
# bumped 1→2. A forged V1 envelope is now PRIOR-version; loading it
# triggers the V1→V2 migration chain via _migrate_v1_to_v2 (default
# prestige fields). The post-migration payload hydrates consumers
# successfully; LOADING → MIGRATION → READY.
func test_forged_v1_envelope_runs_v1_to_v2_migration_proceeds_to_ready() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	_connect_spies(sl)

	var envelope: PackedByteArray = _forge_envelope_with_version(sl, 1)
	_write_envelope_to_fixture(envelope)

	sl.request_full_load("forged_v1_runs_migration_test")

	# Migration chain runs (V1 → V2 with default prestige fields).
	# Consumer hydration uses the migrated payload + defaults from
	# missing fields per Rule 11; load completes successfully.
	assert_int(sl.get_state()).is_equal(SaveLoadScript.State.READY)
	assert_int(_load_completed_calls.size()).is_equal(1)
	assert_str(_load_completed_calls[0]).is_equal("forged_v1_runs_migration_test")
	assert_int(_load_failed_calls.size()).is_equal(0)
	assert_int(_tamper_calls).is_equal(0)

	_disconnect_spies(sl)
