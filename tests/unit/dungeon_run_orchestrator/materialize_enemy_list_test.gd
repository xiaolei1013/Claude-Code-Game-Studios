# Regression test for Sprint 18 post-S18-M4 playtest fix: the orchestrator's
# _materialize_enemy_list helper expands Floor.enemy_list of {enemy_id, count}
# pairs (per ADR-0011) into the materialized {id, archetype, tier, is_boss,
# base_hp, base_attack} shape combat expects.
#
# Why this matters: the shape mismatch silently degenerated combat on every
# real floor since the Sprint 16 multi-biome content drop. Combat reads
# entry.get("base_hp", 0) — with the raw {enemy_id, count} shape, base_hp=0
# made every enemy die at tick 0 (instant-kill cascades). matchup_advantage
# never fired (archetype=""). hp_bonus_factor defensively returned 1.0
# (floor_total_enemy_attack=0). losing_run was structurally impossible.
#
# This test pins the materialization contract so the bug can't silently
# regress. Uses real registered enemies (hollow_brute, glowmoth) so the
# DataRegistry resolution path is exercised end-to-end.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")


func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


# ===========================================================================
# Group A — real {enemy_id, count} shape materializes via DataRegistry
# ===========================================================================

func test_materializes_real_enemy_id_count_pair_to_full_dict() -> void:
	# Floor data shape per ADR-0011: [{enemy_id, count}, ...].
	# Materialization should produce 3 copies of the full materialized dict
	# (one per count) with archetype/tier/base_hp/base_attack/is_boss populated
	# from the EnemyData resource.
	var orch: Node = _make_orch()
	var input: Array = [{"enemy_id": "hollow_brute", "count": 3}]

	var result: Array = orch._materialize_enemy_list(input)

	assert_int(result.size()).is_equal(3)
	for entry: Dictionary in result:
		# hollow_brute fields per assets/data/enemies/hollow_brute.tres
		assert_str(String(entry.get("id", ""))).is_equal("hollow_brute")
		assert_str(String(entry.get("archetype", ""))).is_equal("bruiser")
		assert_int(int(entry.get("tier", 0))).is_equal(1)
		assert_bool(bool(entry.get("is_boss", true))).is_false()
		assert_int(int(entry.get("base_hp", 0))).is_equal(52)
		assert_int(int(entry.get("base_attack", 0))).is_equal(8)


func test_materializes_multiple_enemy_types_preserves_order() -> void:
	# Floor.enemy_list ordering matters per ADR-0011 deterministic schedule;
	# materialization preserves the order (first-listed enemies materialize first).
	var orch: Node = _make_orch()
	var input: Array = [
		{"enemy_id": "hollow_brute", "count": 2},
		{"enemy_id": "glowmoth", "count": 1},
	]

	var result: Array = orch._materialize_enemy_list(input)

	assert_int(result.size()).is_equal(3)
	assert_str(String(result[0].get("id"))).is_equal("hollow_brute")
	assert_str(String(result[1].get("id"))).is_equal("hollow_brute")
	assert_str(String(result[2].get("id"))).is_equal("glowmoth")


# ===========================================================================
# Group B — synthetic shape (already materialized) passes through unchanged
# ===========================================================================

func test_synthetic_shape_passes_through_unchanged() -> void:
	# Pre-fix, _build_combat_snapshot used a synthetic [{id, archetype,
	# base_hp, base_attack, ...}] fallback when floor_data was null. That
	# shape is already materialized — passing it through the new helper must
	# not corrupt it (existing 308 orchestrator tests depend on this).
	var orch: Node = _make_orch()
	var synthetic: Array = [
		{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10, "base_attack": 1},
	]

	var result: Array = orch._materialize_enemy_list(synthetic)

	assert_int(result.size()).is_equal(1)
	assert_str(String(result[0].get("id"))).is_equal("e1")
	assert_str(String(result[0].get("archetype"))).is_equal("bruiser")
	assert_int(int(result[0].get("base_hp"))).is_equal(10)


func test_mixed_shapes_both_paths_work() -> void:
	# Defensive: an enemy_list with BOTH synthetic and real-shape entries
	# should materialize the real entries and pass through the synthetic.
	var orch: Node = _make_orch()
	var mixed: Array = [
		{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10, "base_attack": 1},
		{"enemy_id": "hollow_brute", "count": 1},
	]

	var result: Array = orch._materialize_enemy_list(mixed)

	assert_int(result.size()).is_equal(2)
	assert_str(String(result[0].get("id"))).is_equal("e1")
	assert_int(int(result[0].get("base_hp"))).is_equal(10)
	assert_str(String(result[1].get("id"))).is_equal("hollow_brute")
	assert_int(int(result[1].get("base_hp"))).is_equal(52)


# ===========================================================================
# Group C — defensive paths (skip + warn on bad input)
# ===========================================================================

func test_empty_input_returns_empty_array() -> void:
	var orch: Node = _make_orch()

	var result: Array = orch._materialize_enemy_list([])

	assert_int(result.size()).is_equal(0)


func test_entry_missing_both_id_and_enemy_id_is_skipped() -> void:
	var orch: Node = _make_orch()
	var input: Array = [
		{"count": 3, "some_other_field": "junk"},
		{"enemy_id": "hollow_brute", "count": 1},
	]

	var result: Array = orch._materialize_enemy_list(input)

	assert_int(result.size()).is_equal(1)
	assert_str(String(result[0].get("id"))).is_equal("hollow_brute")


func test_entry_with_non_positive_count_is_skipped() -> void:
	var orch: Node = _make_orch()
	var input: Array = [
		{"enemy_id": "hollow_brute", "count": 0},
		{"enemy_id": "hollow_brute", "count": -2},
		{"enemy_id": "hollow_brute", "count": 1},
	]

	var result: Array = orch._materialize_enemy_list(input)

	# Only the count=1 entry survives.
	assert_int(result.size()).is_equal(1)


func test_unresolvable_enemy_id_is_skipped() -> void:
	# enemy_id that DataRegistry can't resolve → skip with push_warning,
	# don't crash. Combat sees the trimmed list.
	var orch: Node = _make_orch()
	var input: Array = [
		{"enemy_id": "nonexistent_enemy_xyz", "count": 5},
		{"enemy_id": "hollow_brute", "count": 1},
	]

	var result: Array = orch._materialize_enemy_list(input)

	# Only the resolvable entry survives.
	assert_int(result.size()).is_equal(1)
	assert_str(String(result[0].get("id"))).is_equal("hollow_brute")


func test_non_dict_entries_are_skipped() -> void:
	# Junk entries (strings, ints, nulls) skip silently rather than crashing.
	var orch: Node = _make_orch()
	var input: Array = [
		"not a dict",
		42,
		null,
		{"enemy_id": "hollow_brute", "count": 1},
	]

	var result: Array = orch._materialize_enemy_list(input)

	# Only the well-formed entry survives.
	assert_int(result.size()).is_equal(1)
	assert_str(String(result[0].get("id"))).is_equal("hollow_brute")


# ===========================================================================
# Group D — materialized output is independent (no aliasing)
# ===========================================================================

func test_count_3_produces_independent_dict_copies() -> void:
	# Each materialized entry should be an independent copy. Mutating one
	# entry's fields must not affect the others (the template is duplicated
	# per copy, not shared by reference).
	var orch: Node = _make_orch()
	var input: Array = [{"enemy_id": "hollow_brute", "count": 3}]

	var result: Array = orch._materialize_enemy_list(input)
	# Mutate the first entry's base_hp to a sentinel value.
	(result[0] as Dictionary)["base_hp"] = 9999

	# The other two entries should retain the original 52.
	assert_int(int((result[1] as Dictionary).get("base_hp"))).is_equal(52)
	assert_int(int((result[2] as Dictionary).get("base_hp"))).is_equal(52)
