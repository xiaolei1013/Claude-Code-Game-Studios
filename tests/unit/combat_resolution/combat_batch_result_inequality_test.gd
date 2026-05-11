# Tests for US-029 (test-coverage-backfill):
#   - CombatBatchResult.equals — per-field inequality short-circuit branches
#     (loops_completed / first_clear_tick / survived / final_tick /
#     hp_bonus_factor outside is_equal_approx tolerance / kills_by_archetype /
#     kills_by_tier). The Group-D tests in value_types_and_equals_test.gd
#     cover happy (all fields equal -> true), null edge, and float-tolerance
#     INSIDE-tolerance edge; this suite closes the per-field inequality and
#     float OUTSIDE-tolerance branches, plus the dict_equals
#     same-size-different-keys branch (line 98-99 of combat_batch_result.gd).
#
# Covers: TR-combat-015 (CombatBatchResult equals per-field walk),
#         TR-combat-016 (Dictionary equality via key-by-key dict_equals —
#                       key-not-present-in-other branch),
#         TR-combat-017 (Float fields compared via is_equal_approx —
#                       outside-tolerance branch).
extends GdUnitTestSuite

const CombatBatchResultScript = preload("res://src/core/combat/combat_batch_result.gd")


# ---------------------------------------------------------------------------
# Per-field inequality short-circuit branches of equals()
# ---------------------------------------------------------------------------

func test_combat_batch_result_equals_returns_false_on_loops_completed_mismatch() -> void:
	var a: CombatBatchResult = CombatBatchResultScript.new()
	a.loops_completed = 3
	var b: CombatBatchResult = CombatBatchResultScript.new()
	b.loops_completed = 4
	assert_bool(a.equals(b)).is_false()


func test_combat_batch_result_equals_returns_false_on_first_clear_tick_mismatch() -> void:
	var a: CombatBatchResult = CombatBatchResultScript.new()
	a.first_clear_tick = 100
	var b: CombatBatchResult = CombatBatchResultScript.new()
	b.first_clear_tick = 101
	assert_bool(a.equals(b)).is_false()


func test_combat_batch_result_equals_returns_false_on_survived_mismatch() -> void:
	var a: CombatBatchResult = CombatBatchResultScript.new()
	a.survived = true
	var b: CombatBatchResult = CombatBatchResultScript.new()
	b.survived = false
	assert_bool(a.equals(b)).is_false()


func test_combat_batch_result_equals_returns_false_on_final_tick_mismatch() -> void:
	var a: CombatBatchResult = CombatBatchResultScript.new()
	a.final_tick = 500
	var b: CombatBatchResult = CombatBatchResultScript.new()
	b.final_tick = 501
	assert_bool(a.equals(b)).is_false()


func test_combat_batch_result_equals_returns_false_on_hp_bonus_factor_outside_tolerance() -> void:
	# TR-017 — float compared via is_equal_approx. The Group-D existing test
	# covers within-tolerance equality (returns true); this exercises the
	# false-return branch when the difference exceeds tolerance.
	var a: CombatBatchResult = CombatBatchResultScript.new()
	a.hp_bonus_factor = 0.5
	var b: CombatBatchResult = CombatBatchResultScript.new()
	b.hp_bonus_factor = 0.7  # 0.2 difference, well outside default tolerance
	assert_bool(a.equals(b)).is_false()


func test_combat_batch_result_equals_returns_false_on_kills_by_archetype_mismatch() -> void:
	var a: CombatBatchResult = CombatBatchResultScript.new()
	a.kills_by_archetype = {&"bruiser": 5}
	var b: CombatBatchResult = CombatBatchResultScript.new()
	b.kills_by_archetype = {&"bruiser": 6}
	assert_bool(a.equals(b)).is_false()


func test_combat_batch_result_equals_returns_false_on_kills_by_tier_mismatch() -> void:
	var a: CombatBatchResult = CombatBatchResultScript.new()
	a.kills_by_tier = {1: 4, 2: 3}
	var b: CombatBatchResult = CombatBatchResultScript.new()
	b.kills_by_tier = {1: 4, 2: 4}
	assert_bool(a.equals(b)).is_false()


# ---------------------------------------------------------------------------
# dict_equals — same-size-different-keys branch (line 98-99)
# ---------------------------------------------------------------------------
# Group-D existing tests cover happy (same content / different order),
# size-mismatch (line 95), and value-mismatch (line 100). The branch at
# line 98-99 (`if not b.has(k): return false`) requires same-size dicts
# with at-least-one key absent in the other.

func test_combat_batch_result_dict_equals_returns_false_when_key_not_present_in_other() -> void:
	var a: Dictionary = {&"bruiser": 5, &"caster": 2}
	var b: Dictionary = {&"bruiser": 5, &"skirmisher": 2}  # same size, "caster" missing
	assert_bool(CombatBatchResultScript.dict_equals(a, b)).is_false()
