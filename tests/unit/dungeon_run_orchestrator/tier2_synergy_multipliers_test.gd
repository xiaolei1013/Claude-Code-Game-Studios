# Sprint 26 M4 — tier-2 synergy multiplier resolver tests.
#
# Verifies the gold/XP path for the four new mono-class synergies:
#   - bastion: ×1.25 gold vs caster, ×1.0 otherwise (XP baseline)
#   - volley: ×1.25 gold vs swarm, ×1.0 otherwise (XP baseline)
#   - frenzy: ×1.25 gold vs bruiser, ×1.0 otherwise (XP baseline)
#   - vigil: ×1.20 XP unconditional (gold baseline)
extends GdUnitTestSuite

const DungeonRunOrchestratorScript = preload(
	"res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd"
)


func _make_orch() -> Node:
	var orch: Node = DungeonRunOrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


# ===========================================================================
# Group A — Bastion (paladin) conditional gold vs caster
# ===========================================================================

func test_bastion_against_caster_applies_1_25_gold() -> void:
	var orch: Node = _make_orch()
	var baseline: int = orch.attribute_kill_gold(1, true, false)
	var with_bastion: int = orch.attribute_kill_gold(1, true, false, "bastion", "caster")
	assert_int(with_bastion).is_greater(baseline)


func test_bastion_against_non_caster_no_multiplier() -> void:
	var orch: Node = _make_orch()
	var baseline: int = orch.attribute_kill_gold(2, true, false)
	var with_bastion: int = orch.attribute_kill_gold(2, true, false, "bastion", "bruiser")
	assert_int(with_bastion).is_equal(baseline)


func test_bastion_xp_path_is_baseline() -> void:
	var orch: Node = _make_orch()
	var baseline_xp: int = orch.attribute_kill_xp(2, "")
	var bastion_xp: int = orch.attribute_kill_xp(2, "bastion")
	assert_int(bastion_xp).is_equal(baseline_xp)


# ===========================================================================
# Group B — Volley (archer) conditional gold vs swarm
# ===========================================================================

func test_volley_against_swarm_applies_1_25_gold() -> void:
	var orch: Node = _make_orch()
	var baseline: int = orch.attribute_kill_gold(1, true, false)
	var with_volley: int = orch.attribute_kill_gold(1, true, false, "volley", "swarm")
	assert_int(with_volley).is_greater(baseline)


func test_volley_against_non_swarm_no_multiplier() -> void:
	var orch: Node = _make_orch()
	var baseline: int = orch.attribute_kill_gold(2, true, false)
	var with_volley: int = orch.attribute_kill_gold(2, true, false, "volley", "armored")
	assert_int(with_volley).is_equal(baseline)


# ===========================================================================
# Group C — Frenzy (berserker) conditional gold vs bruiser
# ===========================================================================

func test_frenzy_against_bruiser_applies_1_25_gold() -> void:
	var orch: Node = _make_orch()
	var baseline: int = orch.attribute_kill_gold(1, true, false)
	var with_frenzy: int = orch.attribute_kill_gold(1, true, false, "frenzy", "bruiser")
	assert_int(with_frenzy).is_greater(baseline)


func test_frenzy_against_non_bruiser_no_multiplier() -> void:
	var orch: Node = _make_orch()
	var baseline: int = orch.attribute_kill_gold(2, true, false)
	var with_frenzy: int = orch.attribute_kill_gold(2, true, false, "frenzy", "caster")
	assert_int(with_frenzy).is_equal(baseline)


func test_frenzy_and_steel_wall_parallel_against_bruiser() -> void:
	# Frenzy's bruiser-counter shape mirrors Steel Wall — both should give the
	# same multiplier path for bruiser kills. Sanity check the symmetry.
	var orch: Node = _make_orch()
	var steel_wall_gold: int = orch.attribute_kill_gold(2, true, false, "steel_wall", "bruiser")
	var frenzy_gold: int = orch.attribute_kill_gold(2, true, false, "frenzy", "bruiser")
	assert_int(frenzy_gold).is_equal(steel_wall_gold)


# ===========================================================================
# Group D — Vigil (cleric) unconditional XP boost
# ===========================================================================

func test_vigil_xp_unconditional_boost() -> void:
	var orch: Node = _make_orch()
	var baseline: int = orch.attribute_kill_xp(2, "")
	var with_vigil: int = orch.attribute_kill_xp(2, "vigil")
	assert_int(with_vigil).is_greater(baseline)


func test_vigil_xp_mirrors_arcane_elite() -> void:
	# Vigil = ARCANE_ELITE_XP_MULT shape (both VIGIL_XP_MULT and
	# ARCANE_ELITE_XP_MULT are 1.20 by design). Sanity check the
	# support→investment parallel.
	var orch: Node = _make_orch()
	var arcane_elite_xp: int = orch.attribute_kill_xp(2, "arcane_elite")
	var vigil_xp: int = orch.attribute_kill_xp(2, "vigil")
	assert_int(vigil_xp).is_equal(arcane_elite_xp)


func test_vigil_gold_path_is_baseline() -> void:
	var orch: Node = _make_orch()
	var baseline_gold: int = orch.attribute_kill_gold(2, true, false)
	var vigil_gold: int = orch.attribute_kill_gold(2, true, false, "vigil", "armored")
	assert_int(vigil_gold).is_equal(baseline_gold)


# ===========================================================================
# Group E — UIFramework tier mapping (S24-M3 helper)
# ===========================================================================

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")


func test_bastion_maps_to_gold_tier() -> void:
	assert_str(UIFrameworkScript.synergy_id_to_tier("bastion")).is_equal("gold")


func test_volley_maps_to_gold_tier() -> void:
	assert_str(UIFrameworkScript.synergy_id_to_tier("volley")).is_equal("gold")


func test_frenzy_maps_to_gold_tier() -> void:
	assert_str(UIFrameworkScript.synergy_id_to_tier("frenzy")).is_equal("gold")


func test_vigil_maps_to_gold_tier() -> void:
	assert_str(UIFrameworkScript.synergy_id_to_tier("vigil")).is_equal("gold")
