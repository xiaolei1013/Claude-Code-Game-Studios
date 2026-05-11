# Tests for US-035 (test-coverage-backfill):
#   - RunSnapshot.equals — per-field inequality short-circuit branches not
#     covered by Group-F/G in run_snapshot_and_fsm_test.gd. Existing tests
#     cover happy (round-trip -> equals returns true), null edge, and
#     floor_id mismatch; this suite closes the remaining 11 per-field
#     short-circuit branches of the 12-field `and`-chain at lines 226-239:
#       * formation_snapshot mismatch          (line 227)
#       * current_tick mismatch                (line 229)
#       * last_emitted_tick mismatch           (line 230)
#       * losing_run mismatch                  (line 231)
#       * floor_clear_emitted mismatch         (line 232)
#       * matchup_cache mismatch               (line 233)
#       * kill_schedule mismatch               (line 234)
#       * loop_counter mismatch                (line 235)
#       * kill_count mismatch                  (line 236)
#       * floor_was_valid mismatch             (line 237)
#       * synergy_id mismatch                  (line 238)
#
# Fifth member of the equals()-inequality cohort (US-029 combat_batch_result,
# US-031 combat_run_snapshot, US-032 combat_tick_events, US-033 kill_event,
# US-035 run_snapshot). One test per untested branch — each constructs two
# RunSnapshot instances differing on EXACTLY ONE field (other 11 fields
# identical defaults) and asserts equals() returns false. Uses
# RunSnapshotScript const preload — no autoload dependencies, no
# DataRegistry, no before_test cleanup needed.
#
# Covers: TR-orchestrator-003 (RunSnapshot equals per-field walk).
extends GdUnitTestSuite

const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")


# ---------------------------------------------------------------------------
# Per-field inequality short-circuit branches of equals()
# ---------------------------------------------------------------------------

func test_equals_returns_false_on_formation_snapshot_mismatch() -> void:
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.formation_snapshot = {"slots": [1, 2, 3]}
	b.formation_snapshot = {"slots": [4, 5, 6]}
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_on_current_tick_mismatch() -> void:
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.current_tick = 100
	b.current_tick = 101
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_on_last_emitted_tick_mismatch() -> void:
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.last_emitted_tick = 50
	b.last_emitted_tick = 51
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_on_losing_run_mismatch() -> void:
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.losing_run = true
	b.losing_run = false
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_on_floor_clear_emitted_mismatch() -> void:
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.floor_clear_emitted = true
	b.floor_clear_emitted = false
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_on_matchup_cache_mismatch() -> void:
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.matchup_cache = {"warrior": true, "mage": false}
	b.matchup_cache = {"warrior": false, "mage": false}
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_on_kill_schedule_mismatch() -> void:
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.kill_schedule = [{"tick": 10, "archetype": "bruiser"}]
	b.kill_schedule = [{"tick": 11, "archetype": "bruiser"}]
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_on_loop_counter_mismatch() -> void:
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.loop_counter = 3
	b.loop_counter = 4
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_on_kill_count_mismatch() -> void:
	# Sprint 7 S7-M13 field. Untested at the inequality short-circuit until now.
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.kill_count = 7
	b.kill_count = 8
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_on_floor_was_valid_mismatch() -> void:
	# Story 011 (TR-orchestrator-031, ADR-0014). Default is true; flipping
	# to false on one side exercises the 11th `and`-chain short-circuit.
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.floor_was_valid = true
	b.floor_was_valid = false
	assert_bool(a.equals(b)).is_false()


func test_equals_returns_false_on_synergy_id_mismatch() -> void:
	# Sprint 21 S21-M1 (Class Synergy V1.0). Default is ""; populating one
	# side exercises the 12th `and`-chain short-circuit.
	var a: RunSnapshot = RunSnapshotScript.new()
	var b: RunSnapshot = RunSnapshotScript.new()
	a.synergy_id = "steel_wall"
	b.synergy_id = "arcane_elite"
	assert_bool(a.equals(b)).is_false()
