# Tests for save-load-system Story 013 Phase 1 — tamper-counter wiring +
# escalation constants.
#
# Scope: this Phase 1 slice covers the in-memory peripheral surface:
#   - 4 new constants (BACKUP_ESCALATION_THRESHOLD, BACKUP_ESCALATION_WINDOW_SECONDS,
#     SETTINGS_MODIFIED_LABEL_ENABLED, MAX_TAMPER_SUSPICIOUS_COUNT)
#   - `_tamper_suspicious_count` session-scoped counter with saturation
#   - `_on_flag_suspicious_timestamp_emitted` handler wiring
#   - `acknowledge_tamper_modal_yes()` UI entry point
#   - `get_tamper_suspicious_count()` + `get_pending_flags_bit0_tamper()` accessors
#
# OUT OF SCOPE for Phase 1 (Story 013 stays Ready overall pending these):
#   - `.bak` fallback file I/O after `.dat` HMAC failure
#   - `_meta` namespace persistence wiring (Story 009's audit-cascade Status
#     was system-level only — `_meta` is not actually composed into the
#     persist `root_dict` yet; persistence wiring deferred to follow-up)
#   - Backup-restore escalation state machine using BACKUP_ESCALATION_THRESHOLD
#   - HMAC tamper modal + Both Corrupt modal UI signal payloads
#   - FLAGS.bit0 actually written into envelope header (currently only the
#     in-memory `_pending_flags_bit0_tamper` intent is set)
extends GdUnitTestSuite

const SaveLoadSystemScript = preload("res://src/core/save_load_system/save_load_system.gd")


# ---------------------------------------------------------------------------
# Constants — verify the new values exist and match ADR-0004 specifications
# ---------------------------------------------------------------------------

func test_save_load_system_backup_escalation_threshold_is_three() -> void:
	# Per ADR-0004 §`.bak` fallback escalation: 3 events trigger storage-advisory.
	assert_int(SaveLoadSystemScript.BACKUP_ESCALATION_THRESHOLD).is_equal(3)


func test_save_load_system_backup_escalation_window_is_seven_days_in_seconds() -> void:
	# 7 days × 86_400 seconds/day = 604_800.
	assert_int(SaveLoadSystemScript.BACKUP_ESCALATION_WINDOW_SECONDS).is_equal(604_800)


func test_save_load_system_settings_modified_label_disabled_in_mvp() -> void:
	# Per TR-save-load-026: MVP suppresses the UI surface; on-disk FLAGS.bit0
	# still persists silently for V1.0 consequence-feature.
	assert_bool(SaveLoadSystemScript.SETTINGS_MODIFIED_LABEL_ENABLED).is_false()


func test_save_load_system_max_tamper_suspicious_count_saturates_at_ten_thousand() -> void:
	# Per ADR-0004 §`_meta` field schema saturation rule.
	assert_int(SaveLoadSystemScript.MAX_TAMPER_SUSPICIOUS_COUNT).is_equal(10_000)


# ---------------------------------------------------------------------------
# In-memory counter — initial state + saturation semantics
# ---------------------------------------------------------------------------

func test_tamper_suspicious_count_starts_at_zero_on_fresh_instance() -> void:
	# Arrange
	var sls: Node = SaveLoadSystemScript.new()

	# Assert
	assert_int(sls.get_tamper_suspicious_count()).is_equal(0)
	assert_bool(sls.get_pending_flags_bit0_tamper()).is_false()

	# Cleanup
	sls.free()


func test_on_flag_suspicious_timestamp_emitted_increments_counter_by_one() -> void:
	# Arrange
	var sls: Node = SaveLoadSystemScript.new()

	# Act
	sls._on_flag_suspicious_timestamp_emitted(1_745_000_000, 1_744_996_400)

	# Assert
	assert_int(sls.get_tamper_suspicious_count()).is_equal(1)

	# Cleanup
	sls.free()


func test_on_flag_suspicious_timestamp_emitted_does_NOT_set_pending_flags_bit0() -> void:
	# The TickSystem-driven path is for "passive" detection of clock rewind —
	# the player has not yet acknowledged anything. Only modal-Yes flips the
	# FLAGS.bit0 pending flag.
	# Arrange
	var sls: Node = SaveLoadSystemScript.new()

	# Act
	sls._on_flag_suspicious_timestamp_emitted(1_745_000_000, 1_744_996_400)

	# Assert
	assert_bool(sls.get_pending_flags_bit0_tamper()).is_false()

	# Cleanup
	sls.free()


func test_acknowledge_tamper_modal_yes_increments_counter_AND_sets_pending_flags_bit0() -> void:
	# Arrange
	var sls: Node = SaveLoadSystemScript.new()

	# Act — the player taps "Yes" on the cozy HMAC tamper modal
	sls.acknowledge_tamper_modal_yes()

	# Assert — both side-effects happened synchronously
	assert_int(sls.get_tamper_suspicious_count()).is_equal(1)
	assert_bool(sls.get_pending_flags_bit0_tamper()).is_true()

	# Cleanup
	sls.free()


func test_acknowledge_tamper_modal_yes_increments_idempotently_on_repeated_taps() -> void:
	# Per the design comment in `acknowledge_tamper_modal_yes`: stuck-double-tap
	# is acceptable; the counter increments per-call rather than dedupe. The
	# saturation cap prevents abuse.
	# Arrange
	var sls: Node = SaveLoadSystemScript.new()

	# Act — three taps
	sls.acknowledge_tamper_modal_yes()
	sls.acknowledge_tamper_modal_yes()
	sls.acknowledge_tamper_modal_yes()

	# Assert
	assert_int(sls.get_tamper_suspicious_count()).is_equal(3)
	# pending_flags stays true after first tap; subsequent taps are still safe
	assert_bool(sls.get_pending_flags_bit0_tamper()).is_true()

	# Cleanup
	sls.free()


func test_tamper_counter_saturates_at_max_with_post_cap_increments_silent_no_op() -> void:
	# Per ADR-0004: post-cap increments are silent no-ops so a malicious actor
	# cannot run the counter up arbitrarily.
	# Arrange — pre-load the counter to one below the cap
	var sls: Node = SaveLoadSystemScript.new()
	sls._tamper_suspicious_count = SaveLoadSystemScript.MAX_TAMPER_SUSPICIOUS_COUNT - 1

	# Act 1 — single tick brings it to the cap
	sls._on_flag_suspicious_timestamp_emitted(0, 0)
	assert_int(sls.get_tamper_suspicious_count()).is_equal(SaveLoadSystemScript.MAX_TAMPER_SUSPICIOUS_COUNT)

	# Act 2 — three more increments past the cap should NOT change the value
	sls._on_flag_suspicious_timestamp_emitted(0, 0)
	sls.acknowledge_tamper_modal_yes()
	sls._on_flag_suspicious_timestamp_emitted(0, 0)

	# Assert — still at the cap, no overflow, no decrement
	assert_int(sls.get_tamper_suspicious_count()).is_equal(SaveLoadSystemScript.MAX_TAMPER_SUSPICIOUS_COUNT)

	# Cleanup
	sls.free()


# ---------------------------------------------------------------------------
# Mixed paths — both entry points feed the same counter
# ---------------------------------------------------------------------------

func test_tamper_counter_aggregates_across_both_entry_points() -> void:
	# Arrange
	var sls: Node = SaveLoadSystemScript.new()

	# Act — interleave the two entry points
	sls._on_flag_suspicious_timestamp_emitted(0, 0)  # +1 (passive detection)
	sls.acknowledge_tamper_modal_yes()               # +1 (player ack)
	sls._on_flag_suspicious_timestamp_emitted(0, 0)  # +1 (passive again)

	# Assert
	assert_int(sls.get_tamper_suspicious_count()).is_equal(3)
	assert_bool(sls.get_pending_flags_bit0_tamper()).is_true()  # set by the modal-Yes call

	# Cleanup
	sls.free()
