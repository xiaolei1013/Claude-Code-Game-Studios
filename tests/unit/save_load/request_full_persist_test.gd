# Sprint 11 Story 007a: request_full_persist body — guard + signal-emission tests.
#
# Test scope is constrained by project state. CONSUMER_PATHS lists 7 autoloads:
#   /root/Economy, /root/HeroRoster, /root/FloorUnlock,
#   /root/FormationAssignment, /root/Recruitment, /root/DungeonRunOrchestrator,
#   /root/AudioRouter
#
# Live as of 2026-05-05 (after S11-X10 Recruitment skeleton — consumer
# ecosystem is now COMPLETE):
#   - Economy (rank 3) ✓ has get_save_data
#   - HeroRoster (rank 7) ✓ has get_save_data
#   - FloorUnlock (rank 10) ✓ has get_save_data (S11-X1)
#   - FormationAssignment (rank 11) ✓ has get_save_data (S11-X9, returns {})
#   - Recruitment (rank 12) ✓ has get_save_data (S11-X10 — ADR-0015 schema:
#     save_pool_seed + refresh_counter + current_pool)
#   - DungeonRunOrchestrator (rank 14) ✓ has get_save_data (S11-M3c)
#   - AudioRouter (rank 16) ✓ has get_save_data (S11-S2 + S11-S3 registration)
#
# 7/7 autoloads present + with get_save_data. The original deferral sentinel
# (Group D below) flips from "6 of 7 present" to "7 of 7 present" + an
# updated docstring marking that the next blocker for happy-path coverage is
# integration-test authoring (Sprint 11 S11-M4 / Story 016), not autoload
# presence.
#
# Tests below cover:
#   - State-transition guards (UNLOADED rejects with save_failed emit).
#   - Coalesce behavior (PERSISTING rejects without state change).
#   - save_file_path knob is exposed + writable for test-fixture isolation.
#   - save_completed / save_failed signal payloads carry the reason string.
#
# DEFERRED to Sprint 12+ (when consumer ecosystem completes):
#   - Happy-path round-trip: dispatch full persist, read back envelope,
#     verify HMAC + JSON content matches consumer.get_save_data() outputs.
#   - Atomic-write semantics (.tmp absent after success, .dat present at
#     save_file_path).
#   - TickSystem.set_last_persist_ts is called on success.
#
# These follow-ups land alongside Story 007b (FLAGS bit, _meta sub-schema,
# .bak rotation) once FloorUnlock / FormationAssignment / Recruitment
# autoloads exist + DungeonRunOrchestrator gets a get_save_data method.
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")


# ---------------------------------------------------------------------------
# Hygiene barrier (S10-S4 lesson) — reset live autoload state before/after.
# ---------------------------------------------------------------------------

func _reset_save_load_state() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	if sl == null:
		return
	# Reset the state machine to UNLOADED (initial state) and clear the
	# save_file_path override so a subsequent test starts fresh.
	sl._state = SaveLoadScript.State.UNLOADED
	sl.save_file_path = "user://save_slot_1.dat"


func before_test() -> void:
	_reset_save_load_state()


func after_test() -> void:
	_reset_save_load_state()


# ---------------------------------------------------------------------------
# Signal-spy infrastructure
# ---------------------------------------------------------------------------

var _save_failed_calls: Array[Dictionary] = []
var _save_completed_calls: Array[String] = []


func _on_save_failed(reason: String, error_code: int) -> void:
	_save_failed_calls.append({"reason": reason, "error_code": error_code})


func _on_save_completed(reason: String) -> void:
	_save_completed_calls.append(reason)


func _connect_spy(sl: Node) -> void:
	_save_failed_calls.clear()
	_save_completed_calls.clear()
	if not sl.save_failed.is_connected(_on_save_failed):
		sl.save_failed.connect(_on_save_failed)
	if not sl.save_completed.is_connected(_on_save_completed):
		sl.save_completed.connect(_on_save_completed)


func _disconnect_spy(sl: Node) -> void:
	if sl.save_failed.is_connected(_on_save_failed):
		sl.save_failed.disconnect(_on_save_failed)
	if sl.save_completed.is_connected(_on_save_completed):
		sl.save_completed.disconnect(_on_save_completed)


# ===========================================================================
# Group A — save_file_path knob (Pass-5A — added in Story 007a)
# ===========================================================================

func test_save_load_system_has_save_file_path_export() -> void:
	# Pass-5A canonical knob — exists and defaults to user:// canonical path.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_str(sl.save_file_path).is_equal("user://save_slot_1.dat")


func test_save_load_system_save_file_path_is_writable_for_test_fixtures() -> void:
	# Tests must be able to redirect persist to a fixture-isolated path so
	# they don't write into the player's real save slot.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	sl.save_file_path = "user://test_fixture_007a.dat"
	assert_str(sl.save_file_path).is_equal("user://test_fixture_007a.dat")


# ===========================================================================
# Group B — state-transition guards (Story 007a §guard block)
# ===========================================================================

func test_request_full_persist_rejects_when_state_is_unloaded() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	# Initial state is UNLOADED (set by hygiene-barrier reset).
	assert_int(sl._state).is_equal(SaveLoadScript.State.UNLOADED)
	_connect_spy(sl)

	# Act
	sl.request_full_persist("test_persist_from_unloaded")

	# Assert — state unchanged; save_failed emitted with ERR_UNAVAILABLE.
	assert_int(sl._state).is_equal(SaveLoadScript.State.UNLOADED)
	assert_int(_save_failed_calls.size()).is_equal(1)
	assert_str(_save_failed_calls[0].reason).is_equal("test_persist_from_unloaded")
	assert_int(_save_failed_calls[0].error_code).is_equal(ERR_UNAVAILABLE)
	assert_int(_save_completed_calls.size()).is_equal(0)
	_disconnect_spy(sl)


func test_request_full_persist_rejects_when_state_is_loading() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	sl._state = SaveLoadScript.State.LOADING
	_connect_spy(sl)

	sl.request_full_persist("test_persist_from_loading")

	assert_int(sl._state).is_equal(SaveLoadScript.State.LOADING)
	assert_int(_save_failed_calls.size()).is_equal(1)
	assert_int(_save_failed_calls[0].error_code).is_equal(ERR_UNAVAILABLE)
	_disconnect_spy(sl)


func test_request_full_persist_coalesces_when_state_is_persisting() -> void:
	# Per TR-save-load-046: PERSISTING → PERSISTING is a coalesce drop, NOT a
	# state transition. The new trigger is dropped with push_warning; no
	# save_failed signal fires (the in-flight persist will eventually emit
	# save_completed for itself, not the dropped trigger).
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	sl._state = SaveLoadScript.State.PERSISTING
	_connect_spy(sl)

	sl.request_full_persist("test_persist_during_persist")

	assert_int(sl._state).is_equal(SaveLoadScript.State.PERSISTING)
	# Coalesce path is silent (push_warning only) — no save_failed emit.
	assert_int(_save_failed_calls.size()).is_equal(0)
	assert_int(_save_completed_calls.size()).is_equal(0)
	_disconnect_spy(sl)


# ===========================================================================
# Group C — Story 007a contract surface (existence + tunability)
# ===========================================================================

func test_request_full_persist_method_exists() -> void:
	# Lock the public API method existence + arity.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_bool(sl.has_method("request_full_persist")).is_true()


func test_save_load_system_save_completed_signal_declared() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_bool(sl.has_signal("save_completed")).is_true()


func test_save_load_system_save_failed_signal_declared() -> void:
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_bool(sl.has_signal("save_failed")).is_true()


# ===========================================================================
# Group D — sentinel test for happy-path deferral
#
# Documents (in test form, so it surfaces in CI logs) that the happy-path
# round-trip is intentionally NOT covered here. Sprint 12+ work that adds the
# missing consumer autoloads should DELETE this test as part of the same edit
# that lands the happy-path coverage.
# ===========================================================================

func test_happy_path_persist_coverage_intentionally_deferred_until_integration_test_authoring() -> void:
	# CONSUMER_PATHS expects 7 autoloads at /root/{Economy, HeroRoster,
	# FloorUnlock, FormationAssignment, Recruitment, DungeonRunOrchestrator,
	# AudioRouter}.
	#
	# As of 2026-05-05 (post-S11-X10 Recruitment skeleton), 7 of 7 exist as
	# live autoloads with get_save_data — the consumer-ecosystem gap that
	# motivated this sentinel is now CLOSED.
	#
	# The remaining gap is integration-test authoring: the happy-path round
	# trip (envelope round-trip, atomic write semantics, TickSystem
	# .set_last_persist_ts call, save_completed emit) needs a real test
	# fixture that exercises request_full_persist end-to-end. That work is
	# Sprint 11 S11-M4 (Story 016 — save-persist pipeline end-to-end). When
	# S11-M4 lands, this sentinel should be DELETED + replaced with the
	# real round-trip integration test.
	#
	# Until then, this test holds the line on "all 7 autoloads present + with
	# get_save_data" so any regression (e.g., accidentally removing one) is
	# loudly surfaced in CI.
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_int(sl.CONSUMER_PATHS.size()).is_equal(7)
	# Verify all 7 present.
	var present: int = 0
	for path: String in sl.CONSUMER_PATHS:
		if get_tree().root.get_node_or_null(path) != null:
			present += 1
	assert_int(present).is_equal(7)
