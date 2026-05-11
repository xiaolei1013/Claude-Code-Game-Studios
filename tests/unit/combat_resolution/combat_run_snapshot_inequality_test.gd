# Tests for US-031 (test-coverage-backfill):
#   - CombatRunSnapshot.equals — per-field inequality short-circuit branches
#     not covered by Group-E in value_types_and_equals_test.gd. Group-E
#     covers happy (all fields equal -> true), null edge,
#     dispatched_at_tick mismatch, and matchup_cache mismatch; this suite
#     closes the remaining 5 short-circuit branches:
#       * loops_per_run mismatch (line 77-78)
#       * formation_dps_per_tick OUTSIDE is_equal_approx tolerance (line 79-80)
#       * hp_bonus_factor OUTSIDE is_equal_approx tolerance (line 81-82)
#       * enemy_list size mismatch (line 84-85)
#       * enemy_list per-element dict_equals mismatch (line 86-90)
#
# Mirrors US-029 combat_batch_result_inequality_test.gd shape: one test per
# field, each constructing two instances differing on EXACTLY ONE field and
# asserting equals() returns false.
#
# Covers: TR-combat-013 (CombatRunSnapshot equals per-field walk),
#         TR-combat-016 (Dictionary equality via key-by-key dict_equals —
#                       per-element walk on enemy_list),
#         TR-combat-017 (Float fields compared via is_equal_approx —
#                       outside-tolerance branch for both float fields).
extends GdUnitTestSuite

const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")


# ---------------------------------------------------------------------------
# Per-field inequality short-circuit branches of equals()
# ---------------------------------------------------------------------------

func test_combat_run_snapshot_equals_returns_false_on_loops_per_run_mismatch() -> void:
	var a: CombatRunSnapshot = CombatRunSnapshotScript.new()
	a.loops_per_run = 5
	var b: CombatRunSnapshot = CombatRunSnapshotScript.new()
	b.loops_per_run = 6
	assert_bool(a.equals(b)).is_false()


func test_combat_run_snapshot_equals_returns_false_on_formation_dps_per_tick_outside_tolerance() -> void:
	# TR-017 — float compared via is_equal_approx. The Group-E happy test
	# covers within-tolerance equality (returns true); this exercises the
	# false-return branch when the difference exceeds tolerance.
	var a: CombatRunSnapshot = CombatRunSnapshotScript.new()
	a.formation_dps_per_tick = 1.5
	var b: CombatRunSnapshot = CombatRunSnapshotScript.new()
	b.formation_dps_per_tick = 1.7  # 0.2 difference, well outside default tolerance
	assert_bool(a.equals(b)).is_false()


func test_combat_run_snapshot_equals_returns_false_on_hp_bonus_factor_outside_tolerance() -> void:
	# TR-017 — float compared via is_equal_approx.
	var a: CombatRunSnapshot = CombatRunSnapshotScript.new()
	a.hp_bonus_factor = 0.5
	var b: CombatRunSnapshot = CombatRunSnapshotScript.new()
	b.hp_bonus_factor = 0.8  # 0.3 difference, well outside default tolerance
	assert_bool(a.equals(b)).is_false()


func test_combat_run_snapshot_equals_returns_false_on_enemy_list_size_mismatch() -> void:
	# Line 84-85: `if enemy_list.size() != other.enemy_list.size(): return false`
	var a: CombatRunSnapshot = CombatRunSnapshotScript.new()
	a.enemy_list = [{"id": &"e1", "tier": 1}]
	var b: CombatRunSnapshot = CombatRunSnapshotScript.new()
	b.enemy_list = [{"id": &"e1", "tier": 1}, {"id": &"e2", "tier": 2}]
	assert_bool(a.equals(b)).is_false()


func test_combat_run_snapshot_equals_returns_false_on_enemy_list_element_mismatch() -> void:
	# Line 86-90: per-element dict_equals walk. Same-size arrays where
	# at least one element-dict differs from the parallel element.
	var a: CombatRunSnapshot = CombatRunSnapshotScript.new()
	a.enemy_list = [{"id": &"e1", "tier": 1}]
	var b: CombatRunSnapshot = CombatRunSnapshotScript.new()
	b.enemy_list = [{"id": &"e1", "tier": 2}]  # same size, tier differs
	assert_bool(a.equals(b)).is_false()
