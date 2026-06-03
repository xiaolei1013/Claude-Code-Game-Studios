# Story 010 — DungeonRunOrchestrator.compute_offline_batch (the feeder that
# makes the OfflineProgressionEngine kills/floors/XP branch run).
#
# These unit tests exercise the orchestrator's WIRING in isolation via a spy
# combat resolver whose compute_offline_batch returns a controlled CUMULATIVE
# kill count (proportional to the tick window). That lets us verify:
#   - the return is a plain Dictionary with the engine-required keys
#   - zero/invalid budget → empty result
#   - per-chunk kills are the cumulative DELTA (cum(cursor+chunk) - cum(cursor)),
#     so N chunks sum to the same total as one big chunk (over-counting guard)
#   - floor_cleared reflects the resolver's loops_completed
#   - run_snapshot is built when null (so flush → XP grant has a formation)
#   - _offline_pending_kills_by_tier accumulates for the batched XP grant
#
# The real combat math + foreground/offline parity live in the resolver's own
# suite; the END-TO-END kills/floors/XP path is covered by
# tests/integration/offline_progression_engine/end_to_end_offline_replay_test.gd.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const CombatBatchResultScript = preload("res://src/core/combat/combat_batch_result.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


# Spy resolver: returns 1 tier-1 kill per 100 ticks of the window, 1 loop per
# 300 ticks. The orchestrator re-anchors dispatched_at_tick per chunk and passes
# that chunk's budget, so the spy receives the CHUNK budget (not a cumulative) —
# a linear-in-budget kill stream that lets us assert per-chunk + total behavior.
class _SpyResolver extends RefCounted:
	func compute_offline_batch(_snapshot: Variant, tick_budget: int) -> RefCounted:
		var r: RefCounted = CombatBatchResultScript.new()
		r.kills_by_tier = {1: int(tick_budget / 100)}
		r.loops_completed = int(tick_budget / 300)
		r.first_clear_tick = -1
		return r


func _make_orchestrator() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	orch.set_combat_resolver(_SpyResolver.new())
	# Inject a known formation (one hero) + floor/biome so no autoloads are needed.
	var hero: RefCounted = HeroInstanceScript.new()
	hero.instance_id = 1
	hero.class_id = "warrior"
	hero.current_level = 1
	var formation: Array = [hero]
	orch.set_offline_replay_inputs(formation, 1, "")
	return orch


# ===========================================================================
# Return shape + defensive paths
# ===========================================================================

func test_compute_offline_batch_returns_dictionary_with_engine_keys() -> void:
	# The engine calls result.has("kills_by_tier") — a Dictionary-only method —
	# so the return MUST be a Dictionary, NOT the raw CombatBatchResult.
	var orch: Node = _make_orchestrator()
	var result: Variant = orch.compute_offline_batch(500)
	assert_bool(result is Dictionary).is_true()
	assert_bool((result as Dictionary).has("kills_by_tier")).is_true()
	assert_bool((result as Dictionary).has("floor_cleared")).is_true()
	assert_bool((result as Dictionary).has("floor_index")).is_true()


func test_compute_offline_batch_zero_budget_returns_empty() -> void:
	var orch: Node = _make_orchestrator()
	var result: Dictionary = orch.compute_offline_batch(0)
	assert_int((result["kills_by_tier"] as Dictionary).size()).is_equal(0)
	assert_bool(result["floor_cleared"]).is_false()
	assert_int(int(result["floor_index"])).is_equal(1)


func test_compute_offline_batch_negative_budget_returns_empty() -> void:
	var orch: Node = _make_orchestrator()
	var result: Dictionary = orch.compute_offline_batch(-50)
	assert_int((result["kills_by_tier"] as Dictionary).size()).is_equal(0)


# ===========================================================================
# Cumulative-delta correctness — the over-counting guard
# ===========================================================================

func test_each_chunk_returns_only_its_own_window_kills() -> void:
	# Each chunk must return ITS window's kills (spy: 200/100 = 2), not an
	# accumulation. If the feeder passed the cumulative budget (cursor+chunk=400)
	# to the resolver, the spy would return 4 — the over-counting regression.
	var orch: Node = _make_orchestrator()
	var c1: Dictionary = orch.compute_offline_batch(200)
	assert_int(int((c1["kills_by_tier"] as Dictionary).get(1, 0))).is_equal(2)
	var c2: Dictionary = orch.compute_offline_batch(200)
	assert_int(int((c2["kills_by_tier"] as Dictionary).get(1, 0))).override_failure_message(
		"chunk 2 must return its own window (2), not a cumulative (4) — over-counting"
	).is_equal(2)


func test_chunked_union_equals_single_call() -> void:
	# 3 chunks of 200 must accumulate the SAME total kills as 1 chunk of 600.
	# This is the parity invariant: the union of per-chunk windows == the whole.
	var orch_chunked: Node = _make_orchestrator()
	orch_chunked.compute_offline_batch(200)
	orch_chunked.compute_offline_batch(200)
	orch_chunked.compute_offline_batch(200)
	var chunked_total: int = int(orch_chunked._offline_pending_kills_by_tier.get(1, 0))

	var orch_single: Node = _make_orchestrator()
	orch_single.compute_offline_batch(600)
	var single_total: int = int(orch_single._offline_pending_kills_by_tier.get(1, 0))

	assert_int(chunked_total).override_failure_message(
		"chunked (3×200) total %d != single (600) total %d" % [chunked_total, single_total]
	).is_equal(single_total)
	assert_int(single_total).is_equal(6)  # cum(600) = 600/100 = 6


# ===========================================================================
# Accumulation + floor_cleared + run_snapshot building
# ===========================================================================

func test_accumulates_kills_into_offline_pending_for_xp() -> void:
	var orch: Node = _make_orchestrator()
	orch.compute_offline_batch(500)  # cum(500) = 5 tier-1 kills
	assert_int(int(orch._offline_pending_kills_by_tier.get(1, 0))).is_equal(5)


func test_floor_cleared_true_when_loops_completed_at_least_one() -> void:
	var orch: Node = _make_orchestrator()
	# cum(600): loops_completed = 600/300 = 2 → floor cleared.
	var result: Dictionary = orch.compute_offline_batch(600)
	assert_bool(result["floor_cleared"]).is_true()


func test_floor_not_cleared_when_window_too_short_for_a_loop() -> void:
	var orch: Node = _make_orchestrator()
	# cum(100): loops_completed = 100/300 = 0 → no clear.
	var result: Dictionary = orch.compute_offline_batch(100)
	assert_bool(result["floor_cleared"]).is_false()


func test_builds_run_snapshot_when_null_so_xp_can_grant() -> void:
	# _grant_xp_to_formation early-returns when run_snapshot == null; the feeder
	# must build it (offline resume has a null run_snapshot) with the formation's
	# instance_ids so the post-replay XP grant has a target.
	var orch: Node = _make_orchestrator()
	assert_object(orch.run_snapshot).is_null()
	orch.compute_offline_batch(500)
	assert_object(orch.run_snapshot).is_not_null()
	var ids: Variant = orch.run_snapshot.formation_snapshot.get("instance_ids", [])
	assert_bool(ids is Array).is_true()
	assert_bool((ids as Array).has(1)).is_true()


func test_flush_resets_offline_batch_state_for_next_resume() -> void:
	var orch: Node = _make_orchestrator()
	orch.compute_offline_batch(500)
	assert_object(orch._offline_combat_snapshot).is_not_null()
	orch.flush_offline_signals()
	assert_object(orch._offline_combat_snapshot).is_null()
	assert_int(orch._offline_replay_cursor).is_equal(0)
