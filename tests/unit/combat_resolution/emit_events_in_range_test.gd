# Tests for Sprint 7 combat-resolution Story 006:
#   - emit_events_in_range(snapshot, tick_lo, tick_hi) -> CombatTickEvents
#   - Half-open range (tick_lo, tick_hi] semantics
#   - Multi-loop schedule iteration (snapshot.loops_per_run)
#   - loop_completed_ticks tracking (last enemy of each loop)
#   - first_clear_in_range detection at loops_per_run-th loop completion
#   - Clock-rewind safety: descending range → push_warning + empty events
#
# Covers: TR-combat-002 (emit_events_in_range entry point),
#         TR-combat-014 (CombatTickEvents 3-field schema populated),
#         TR-combat-022 (foreground+offline parity foundation — half-open
#                        range produces non-overlapping consecutive call partition),
#         TR-combat-026 (clock-rewind: time-anchored schedule recovers via range),
#         TR-combat-029 (synchronous; no tick_fired subscription — verified
#                        by source-grep in S7-S2 / S7-N1 stories).
extends GdUnitTestSuite

const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")


func _make_snapshot(formation_dps: float, _hp_bonus: float, enemy_list: Array,
		matchup_cache: Dictionary, dispatched_at_tick: int = 0,
		loops_per_run: int = 1) -> CombatRunSnapshot:
	# Phase 1 (GDD #34): hp_bonus_factor field is RETIRED — the param is kept
	# (ignored) so the positional call sites in this suite stay unchanged.
	var s: CombatRunSnapshot = CombatRunSnapshotScript.new()
	s.formation_dps_per_tick = formation_dps
	s.enemy_list = enemy_list
	s.matchup_cache = matchup_cache
	s.dispatched_at_tick = dispatched_at_tick
	s.loops_per_run = loops_per_run
	return s


func _make_three_enemy_list() -> Array:
	# Three enemies, all advantaged-bruiser. With factor_adv=1.5, raw_dps=1.0,
	# hp_bonus=1.0, base_hp=10 → ticks_to_kill = ceili(10/1.5) = 7.
	# Cumulative kill_ticks (for one loop, dispatched_at_tick=0): 7, 14, 21.
	return [
		{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10},
		{"id": &"e2", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10},
		{"id": &"e3", "archetype": &"bruiser", "tier": 2, "is_boss": true, "base_hp": 10},
	]


# ===========================================================================
# Group A: TR-002 — entry point + null-safety
# ===========================================================================

func test_emit_events_in_range_null_snapshot_returns_empty_events() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var result: CombatTickEvents = resolver.emit_events_in_range(null, 0, 100)
	assert_int(result.kills.size()).is_equal(0)
	assert_int(result.loop_completed_ticks.size()).is_equal(0)
	assert_bool(result.first_clear_in_range).is_false()


func test_emit_events_in_range_empty_enemy_list_returns_empty_events() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, [], {}, 0, 1)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 100)
	assert_int(result.kills.size()).is_equal(0)


func test_emit_events_in_range_zero_loops_per_run_returns_empty_events() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 0)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 100)
	assert_int(result.kills.size()).is_equal(0)


# ===========================================================================
# Group B: half-open range (tick_lo, tick_hi]
# ===========================================================================

func test_emit_events_in_range_includes_kill_at_exactly_tick_hi() -> void:
	# Kill at tick=7 (first enemy). Range (0, 7] should include it.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 1)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 7)
	assert_int(result.kills.size()).is_equal(1)
	assert_int(result.kills[0].kill_tick).is_equal(7)


func test_emit_events_in_range_excludes_kill_at_exactly_tick_lo() -> void:
	# Kill at tick=7. Range (7, 14] should exclude it (already emitted in prior call).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 1)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 7, 14)
	# Range (7, 14] includes kills at 8..14. Only enemy 2 (tick=14) qualifies.
	assert_int(result.kills.size()).is_equal(1)
	assert_int(result.kills[0].kill_tick).is_equal(14)


func test_emit_events_in_range_full_loop_includes_all_kills() -> void:
	# Range (0, 21] covers the full single-loop schedule.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 1)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 21)
	assert_int(result.kills.size()).is_equal(3)
	assert_int(result.kills[0].kill_tick).is_equal(7)
	assert_int(result.kills[1].kill_tick).is_equal(14)
	assert_int(result.kills[2].kill_tick).is_equal(21)


# ===========================================================================
# Group C: TR-022 — non-overlapping consecutive calls produce a partition
# ===========================================================================

func test_emit_events_consecutive_calls_produce_full_kill_stream_without_overlap() -> void:
	# Half-open semantics: (0,10] then (10,20] then (20,30] should partition
	# the kills produced by (0, 30] with NO overlaps (TR-022 parity foundation).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 1)
	var full: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 30)
	var part1: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 10)
	var part2: CombatTickEvents = resolver.emit_events_in_range(snapshot, 10, 20)
	var part3: CombatTickEvents = resolver.emit_events_in_range(snapshot, 20, 30)
	# Sum of partition kill counts == full call kill count (no overlap, no missing).
	var partitioned_count: int = part1.kills.size() + part2.kills.size() + part3.kills.size()
	assert_int(partitioned_count).is_equal(full.kills.size())


# ===========================================================================
# Group D: TR-014 — KillEvent fields populated correctly
# ===========================================================================

func test_emit_events_in_range_kill_event_fields_match_enemy_list() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 1)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 21)
	# Third enemy (e3) is the boss with tier=2.
	var third: KillEvent = result.kills[2]
	assert_str(str(third.enemy_id)).is_equal("e3")
	assert_str(str(third.archetype)).is_equal("bruiser")
	assert_int(third.tier).is_equal(2)
	assert_bool(third.is_boss).is_true()


# ===========================================================================
# Group E: loop_completed_ticks + first_clear_in_range
# ===========================================================================

func test_emit_events_in_range_loop_completion_recorded() -> void:
	# Single loop, 3 enemies. Last enemy (kill_tick=21) is the loop completion.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 1)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 21)
	assert_int(result.loop_completed_ticks.size()).is_equal(1)
	assert_int(result.loop_completed_ticks[0]).is_equal(21)


func test_emit_events_in_range_first_clear_true_at_final_loop() -> void:
	# loops_per_run=1; the single loop is the floor clear → first_clear_in_range true.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 1)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 21)
	assert_bool(result.first_clear_in_range).is_true()


func test_emit_events_in_range_first_clear_false_when_clear_outside_window() -> void:
	# loops_per_run=2. Loop 1 ends at tick 21; loop 2 ends at tick 42 (the clear).
	# Range (0, 21] sees loop 1 complete but NOT the floor clear.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 2)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 21)
	assert_int(result.loop_completed_ticks.size()).is_equal(1)
	assert_int(result.loop_completed_ticks[0]).is_equal(21)
	assert_bool(result.first_clear_in_range).is_false()


func test_emit_events_in_range_first_clear_true_when_floor_clear_in_window() -> void:
	# loops_per_run=2. Range (21, 42] covers loop 2 completion = floor clear.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 2)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 21, 42)
	assert_int(result.loop_completed_ticks.size()).is_equal(1)
	assert_int(result.loop_completed_ticks[0]).is_equal(42)
	assert_bool(result.first_clear_in_range).is_true()


# ===========================================================================
# Group F: multi-loop iteration
# ===========================================================================

func test_emit_events_in_range_multi_loop_kill_count() -> void:
	# loops_per_run=3, 3 enemies per loop → 9 total kills.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 3)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 100)  # full run
	assert_int(result.kills.size()).is_equal(9)


func test_emit_events_in_range_multi_loop_kill_ticks_advance() -> void:
	# 3 loops × ticks_per_loop=21 → loop kills at:
	#  L1: 7, 14, 21
	#  L2: 28, 35, 42
	#  L3: 49, 56, 63
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 3)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 100)
	assert_int(result.kills[0].kill_tick).is_equal(7)
	assert_int(result.kills[3].kill_tick).is_equal(28)
	assert_int(result.kills[6].kill_tick).is_equal(49)
	# Last loop complete = floor clear = tick 63.
	assert_int(result.loop_completed_ticks.size()).is_equal(3)
	assert_int(result.loop_completed_ticks[2]).is_equal(63)
	assert_bool(result.first_clear_in_range).is_true()


# ===========================================================================
# Group G: TR-026 — clock-rewind / descending range safety
# ===========================================================================

func test_emit_events_in_range_descending_range_returns_empty_with_warning() -> void:
	# tick_hi <= tick_lo → push_warning + empty events.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 1)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 100, 50)
	assert_int(result.kills.size()).is_equal(0)
	assert_int(result.loop_completed_ticks.size()).is_equal(0)
	assert_bool(result.first_clear_in_range).is_false()


func test_emit_events_in_range_zero_length_range_returns_empty() -> void:
	# tick_lo == tick_hi → empty (nothing in (n, n]).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 1)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 10, 10)
	assert_int(result.kills.size()).is_equal(0)


# ===========================================================================
# Group H: TR-026 — time-anchored schedule (clock-rewind re-emission)
# ===========================================================================

func test_emit_events_in_range_re_emission_after_rewind_covers_same_kills() -> void:
	# TR-026: schedule is time-anchored — calling with tick_lo=0 again after
	# already calling with (0, 21] re-produces the same kill stream
	# (deterministic, idempotent for non-overlapping windows).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 0, 1)
	var first: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 21)
	var second: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 21)
	# Both calls must produce field-equal CombatTickEvents (TR-021 determinism).
	assert_bool(first.equals(second)).is_true()


# ===========================================================================
# Group I: dispatched_at_tick anchoring (TR-026)
# ===========================================================================

func test_emit_events_in_range_anchors_on_dispatched_at_tick() -> void:
	# dispatched_at_tick=100 → kills at 107, 114, 121 (not 7, 14, 21).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var snapshot: CombatRunSnapshot = _make_snapshot(1.0, 1.0, _make_three_enemy_list(), {&"bruiser": true}, 100, 1)
	var result: CombatTickEvents = resolver.emit_events_in_range(snapshot, 0, 200)
	assert_int(result.kills.size()).is_equal(3)
	assert_int(result.kills[0].kill_tick).is_equal(107)
	assert_int(result.kills[1].kill_tick).is_equal(114)
	assert_int(result.kills[2].kill_tick).is_equal(121)
