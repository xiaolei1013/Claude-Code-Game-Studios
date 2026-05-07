# Sprint 14 S14-M4 Story 4 — tests for offline replay batch XP per Hero
# Leveling GDD #15 §E.9 / AC-15-11. Covers compute_offline_total_xp pure
# helper + flush_offline_signals integration with _grant_xp_to_formation.
#
# AC covered:
#   AC-15-11 — Offline replay XP batched correctly:
#     total per hero = sum(XP_PER_KILL[tier] * kills_by_tier[tier])
#                    + sum(xp_per_floor_clear(f) for f in first_clears)
#   §E.9 — Cascade fires post-replay (single add_xp call per hero, not per kill)
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")


func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


func _seed_run_snapshot_with_formation_ids(orch: Node, ids: Array[int]) -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.formation_snapshot = {"instance_ids": ids, "heroes": []}
	orch.run_snapshot = snap


# ===========================================================================
# Group A — compute_offline_total_xp pure formula
# ===========================================================================

func test_compute_offline_total_xp_with_empty_accumulators_returns_zero() -> void:
	var orch: Node = _make_orch()
	# No kills, no first_clears.
	assert_int(orch.compute_offline_total_xp()).is_equal(0)


func test_compute_offline_total_xp_kills_only() -> void:
	var orch: Node = _make_orch()
	# Defaults from §C.1: tier 1=5, tier 2=10, tier 3=20.
	# 30 tier-1 kills (150) + 10 tier-2 kills (100) + 5 tier-3 kills (100) = 350.
	orch._offline_pending_kills_by_tier = {1: 30, 2: 10, 3: 5}
	assert_int(orch.compute_offline_total_xp()).is_equal(350)


func test_compute_offline_total_xp_first_clears_only() -> void:
	var orch: Node = _make_orch()
	# Floor 1 = 50, Floor 3 = 100. Total = 150.
	# Typed-Array assignment requires a typed local — Array[Dictionary]
	# rejects untyped literal assignment per project memory pattern.
	var clears: Array[Dictionary] = [
		{"floor_index": 1, "biome_id": "ashen_glade", "losing_run": false},
		{"floor_index": 3, "biome_id": "ashen_glade", "losing_run": false},
	]
	orch._offline_pending_first_clears = clears
	assert_int(orch.compute_offline_total_xp()).is_equal(150)


func test_compute_offline_total_xp_kills_plus_first_clears() -> void:
	var orch: Node = _make_orch()
	# Kills: 20 tier-1 (100) + 5 tier-2 (50) = 150.
	# First clears: floor 1 (50) + floor 2 (75) = 125.
	# Total = 275.
	orch._offline_pending_kills_by_tier = {1: 20, 2: 5}
	var clears: Array[Dictionary] = [
		{"floor_index": 1, "biome_id": "ashen_glade", "losing_run": false},
		{"floor_index": 2, "biome_id": "ashen_glade", "losing_run": false},
	]
	orch._offline_pending_first_clears = clears
	assert_int(orch.compute_offline_total_xp()).is_equal(275)


func test_compute_offline_total_xp_high_tier_kills_dominates() -> void:
	var orch: Node = _make_orch()
	# 100 tier-5 kills @ 80 XP each = 8000 XP.
	orch._offline_pending_kills_by_tier = {5: 100}
	assert_int(orch.compute_offline_total_xp()).is_equal(8000)


func test_compute_offline_total_xp_zero_count_tier_excluded() -> void:
	var orch: Node = _make_orch()
	# Tier with 0 count contributes 0; defensive against accumulator drift.
	orch._offline_pending_kills_by_tier = {1: 0, 2: 5}
	# 0*5 + 5*10 = 50.
	assert_int(orch.compute_offline_total_xp()).is_equal(50)


# Pure-function guarantee: compute_offline_total_xp does NOT mutate the
# accumulator state. Re-call returns the same value; flush_offline_signals
# (which DOES mutate) is the only mutator.
func test_compute_offline_total_xp_does_not_mutate_accumulators() -> void:
	var orch: Node = _make_orch()
	orch._offline_pending_kills_by_tier = {1: 30, 2: 10}
	var clears: Array[Dictionary] = [
		{"floor_index": 2, "biome_id": "x", "losing_run": false},
	]
	orch._offline_pending_first_clears = clears
	var first: int = orch.compute_offline_total_xp()
	var second: int = orch.compute_offline_total_xp()
	assert_int(first).is_equal(second)
	assert_int(orch._offline_pending_kills_by_tier[1]).is_equal(30)
	assert_int(orch._offline_pending_first_clears.size()).is_equal(1)


# ===========================================================================
# Group B — flush_offline_signals clears the kills-by-tier accumulator
# ===========================================================================

func test_flush_offline_signals_clears_kills_by_tier_accumulator() -> void:
	var orch: Node = _make_orch()
	orch._offline_pending_kills_by_tier = {1: 30, 2: 10}
	orch._is_offline_replay = true

	orch.flush_offline_signals()

	assert_int(orch._offline_pending_kills_by_tier.size()).is_equal(0)
	assert_bool(orch._is_offline_replay).is_false()


# Empty-accumulator flush stays a no-op (idempotent + safe to call from
# OfflineProgressionEngine even when nothing happened).
func test_flush_offline_signals_with_empty_accumulators_is_safe_noop() -> void:
	var orch: Node = _make_orch()
	orch._is_offline_replay = true

	orch.flush_offline_signals()

	# Flag clears; accumulators remain empty.
	assert_bool(orch._is_offline_replay).is_false()
	assert_int(orch._offline_pending_kills_by_tier.size()).is_equal(0)
	assert_int(orch._offline_pending_first_clears.size()).is_equal(0)


# ===========================================================================
# Group C — flush_offline_signals invokes _grant_xp_to_formation
# ===========================================================================

# Helper: instrument _grant_xp_to_formation by replacing the orchestrator's
# method with a recording variant. We use a subclass that overrides the
# method to capture the call without touching live HeroRoster.
class RecordingOrchestrator extends OrchestratorScript:
	var grant_calls: Array[Dictionary] = []

	func _grant_xp_to_formation(roster: Node, xp_amount: int) -> void:
		grant_calls.append({"xp_amount": xp_amount})


func _make_recording_orch() -> RecordingOrchestrator:
	var orch: RecordingOrchestrator = RecordingOrchestrator.new()
	add_child(orch)
	auto_free(orch)
	return orch


func test_flush_offline_signals_calls_grant_xp_with_total_xp() -> void:
	var orch: RecordingOrchestrator = _make_recording_orch()
	_seed_run_snapshot_with_formation_ids(orch, [11, 12, 13])
	# Kills: 30 tier-1 (150) + 10 tier-2 (100) = 250.
	# First clears: floor 1 (50). Total = 300.
	orch._offline_pending_kills_by_tier = {1: 30, 2: 10}
	var clears: Array[Dictionary] = [
		{"floor_index": 1, "biome_id": "ashen_glade", "losing_run": false},
	]
	orch._offline_pending_first_clears = clears
	orch._is_offline_replay = true

	orch.flush_offline_signals()

	# Single batched call with the summed XP.
	assert_int(orch.grant_calls.size()).is_equal(1)
	assert_int(int(orch.grant_calls[0].xp_amount)).is_equal(300)


# §E.9: cascade fires post-replay — the helper is called ONCE per flush,
# not per accumulated kill or first-clear. Validates the "single call per
# hero" guarantee at the orchestrator level.
func test_flush_offline_signals_calls_grant_xp_exactly_once_for_high_kill_count() -> void:
	var orch: RecordingOrchestrator = _make_recording_orch()
	_seed_run_snapshot_with_formation_ids(orch, [11])
	# 1000 tier-3 kills accumulated. Per-call grant would be 1000; the
	# batch path produces ONE call with amount 20000 (=1000*20).
	orch._offline_pending_kills_by_tier = {3: 1000}
	orch._is_offline_replay = true

	orch.flush_offline_signals()

	assert_int(orch.grant_calls.size()).is_equal(1)
	assert_int(int(orch.grant_calls[0].xp_amount)).is_equal(20000)


func test_flush_offline_signals_with_zero_total_skips_grant() -> void:
	var orch: RecordingOrchestrator = _make_recording_orch()
	_seed_run_snapshot_with_formation_ids(orch, [11])
	# No kills, no first clears → total = 0 → grant skipped.
	orch._is_offline_replay = true

	orch.flush_offline_signals()

	assert_int(orch.grant_calls.size()).is_equal(0)


# ===========================================================================
# Group D — sequencing: floor_cleared_first_time emits BEFORE XP grant
# ===========================================================================

# Subscribe to floor_cleared_first_time and record the timing relative to
# the grant_calls array. Deterministic ordering: signal subscribers fire
# during the floor-clear emit loop, then the XP grant runs.
class SequencingOrchestrator extends OrchestratorScript:
	var event_log: Array[String] = []

	func _grant_xp_to_formation(_roster: Node, _xp_amount: int) -> void:
		event_log.append("grant_xp")


func _make_sequencing_orch() -> SequencingOrchestrator:
	var orch: SequencingOrchestrator = SequencingOrchestrator.new()
	add_child(orch)
	auto_free(orch)
	return orch


func _on_floor_cleared_first_time_log(_floor: int, _biome: String, _lose: bool) -> void:
	_floor_clear_log_target.event_log.append("floor_cleared")


var _floor_clear_log_target: SequencingOrchestrator = null


func test_flush_offline_signals_emits_floor_clear_before_xp_grant() -> void:
	var orch: SequencingOrchestrator = _make_sequencing_orch()
	_floor_clear_log_target = orch
	orch.floor_cleared_first_time.connect(_on_floor_cleared_first_time_log)
	_seed_run_snapshot_with_formation_ids(orch, [11, 12])
	orch._offline_pending_kills_by_tier = {1: 5}
	var clears: Array[Dictionary] = [
		{"floor_index": 1, "biome_id": "x", "losing_run": false},
	]
	orch._offline_pending_first_clears = clears
	orch._is_offline_replay = true

	orch.flush_offline_signals()

	# floor_cleared signal fires first (cozy fanfare), then XP grant fires
	# (level-up chime + toast).
	assert_array(orch.event_log).is_equal(["floor_cleared", "grant_xp"])
