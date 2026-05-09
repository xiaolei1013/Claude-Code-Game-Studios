# Sprint 21 S21-S1 / Class Synergy V1.0 Story 2 — formula extension tests.
#
# Per design/gdd/class-synergy-system.md §C.3 + §D.2 + §D.3 + AC-CS-06..11.
# Extends attribute_kill_gold + adds attribute_kill_xp + the resolver helpers.
#
# Test groups:
#   A — Steel Wall conditional gold (AC-CS-06/07): bruiser → 1.25, other → 1.0
#   B — Triple Threat unconditional gold (AC-CS-08): all archetypes → 1.15
#   C — Arcane Elite gold pathway NOT affected (AC-CS-09): always 1.0
#   D — Arcane Elite XP pathway (AC-CS-10): all kills × 1.20
#   E — No synergy: baseline gold + XP unchanged (AC-CS-11)
#   F — Unknown synergy_id (AC-CS-18): forward-compat → 1.0
#   G — Cozy-register hard floor (AC-CS-16): all multipliers ≤ 1.5
#   H — Backwards-compat: 3-arg attribute_kill_gold still works
extends GdUnitTestSuite

const DungeonRunOrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")


func _make_orch() -> Node:
	var orch: Node = DungeonRunOrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


# ===========================================================================
# Group A — Steel Wall conditional gold (AC-CS-06 + AC-CS-07)
# ===========================================================================

func test_attribute_kill_gold_steel_wall_against_bruiser_applies_1_25() -> void:
	# AC-CS-06: synergy_id = "steel_wall", archetype = "bruiser"
	#   → ×1.25 multiplier on top of baseline.
	# Tier-1 advantaged winning: BASE_KILL[1]=5 × 1.5 × 1.0 × 1.25 = 9.375 → 9
	var orch: Node = _make_orch()

	var without_synergy: int = orch.attribute_kill_gold(1, true, false)
	var with_synergy: int = orch.attribute_kill_gold(1, true, false, "steel_wall", "bruiser")

	assert_int(without_synergy).is_equal(7)  # floori(5 * 1.5 * 1.0) = 7
	assert_int(with_synergy).is_equal(9)  # floori(5 * 1.5 * 1.0 * 1.25) = 9


func test_attribute_kill_gold_steel_wall_against_skirmisher_no_multiplier() -> void:
	# AC-CS-07: synergy_id = "steel_wall", archetype != "bruiser"
	#   → multiplier collapses to 1.0; gold equals the no-synergy baseline.
	var orch: Node = _make_orch()

	var without_synergy: int = orch.attribute_kill_gold(3, true, false)
	var with_synergy: int = orch.attribute_kill_gold(3, true, false, "steel_wall", "skirmisher")

	assert_int(with_synergy).is_equal(without_synergy)


func test_attribute_kill_gold_steel_wall_higher_tier_bigger_bonus() -> void:
	# Worked example from GDD §D.4: tier-3 bruiser kill, advantaged, winning.
	# floori(BASE_KILL[3] × 1.5 × 1.0 × 1.25) = floori(25 × 1.5 × 1.25) = floori(46.875) = 46
	# vs no-synergy: floori(25 × 1.5 × 1.0) = 37. Steel Wall = +9.
	var orch: Node = _make_orch()

	var without_synergy: int = orch.attribute_kill_gold(3, true, false)
	var with_synergy: int = orch.attribute_kill_gold(3, true, false, "steel_wall", "bruiser")

	assert_int(without_synergy).is_equal(37)
	assert_int(with_synergy).is_equal(46)


# ===========================================================================
# Group B — Triple Threat unconditional gold (AC-CS-08)
# ===========================================================================

func test_attribute_kill_gold_triple_threat_applies_unconditionally() -> void:
	# AC-CS-08: synergy_id = "triple_threat" → ×1.15 regardless of archetype.
	var orch: Node = _make_orch()

	# tier-3 advantaged winning kill against bruiser:
	# floori(25 * 1.5 * 1.0 * 1.15) = floori(43.125) = 43
	var bruiser_gold: int = orch.attribute_kill_gold(3, true, false, "triple_threat", "bruiser")
	var skirmisher_gold: int = orch.attribute_kill_gold(3, true, false, "triple_threat", "skirmisher")
	var caster_gold: int = orch.attribute_kill_gold(3, true, false, "triple_threat", "caster")

	# All three should be equal (Triple Threat is unconditional).
	assert_int(bruiser_gold).is_equal(43)
	assert_int(skirmisher_gold).is_equal(43)
	assert_int(caster_gold).is_equal(43)


func test_attribute_kill_gold_triple_threat_smaller_bonus_than_steel_wall() -> void:
	# Design intent (GDD §C.1 rationale): conditional Steel Wall (1.25)
	# rewards more than unconditional Triple Threat (1.15) when conditions
	# are met. This test pins that ordering.
	var orch: Node = _make_orch()

	var triple_threat_gold: int = orch.attribute_kill_gold(3, true, false, "triple_threat", "bruiser")
	var steel_wall_gold: int = orch.attribute_kill_gold(3, true, false, "steel_wall", "bruiser")

	assert_int(steel_wall_gold).is_greater(triple_threat_gold)


# ===========================================================================
# Group C — Arcane Elite gold pathway NOT affected (AC-CS-09)
# ===========================================================================

func test_attribute_kill_gold_arcane_elite_does_not_modify_gold() -> void:
	# AC-CS-09: Arcane Elite affects XP only; gold is baseline.
	var orch: Node = _make_orch()

	var baseline: int = orch.attribute_kill_gold(3, true, false)
	var with_arcane: int = orch.attribute_kill_gold(3, true, false, "arcane_elite", "caster")

	assert_int(with_arcane).is_equal(baseline)


# ===========================================================================
# Group D — Arcane Elite XP pathway (AC-CS-10)
# ===========================================================================

func test_attribute_kill_xp_arcane_elite_applies_1_20_multiplier() -> void:
	# AC-CS-10: synergy_id = "arcane_elite" → ×1.20 unconditional XP.
	# tier-2: floori(10 × 2 × 1.20) = floori(24) = 24
	var orch: Node = _make_orch()

	var without_synergy: int = orch.attribute_kill_xp(2)
	var with_synergy: int = orch.attribute_kill_xp(2, "arcane_elite")

	assert_int(without_synergy).is_equal(20)  # floori(10 * 2 * 1.0)
	assert_int(with_synergy).is_equal(24)  # floori(10 * 2 * 1.20)


func test_attribute_kill_xp_arcane_elite_scales_linearly_with_tier() -> void:
	# tier 1..5: 10, 20, 30, 40, 50 baseline
	# with arcane_elite: 12, 24, 36, 48, 60
	var orch: Node = _make_orch()

	for tier: int in range(1, 6):
		var baseline: int = orch.attribute_kill_xp(tier)
		var boosted: int = orch.attribute_kill_xp(tier, "arcane_elite")
		assert_int(baseline).is_equal(10 * tier)
		assert_int(boosted).is_equal(int(10.0 * tier * 1.20))


# ===========================================================================
# Group E — No synergy: baseline (AC-CS-11)
# ===========================================================================

func test_attribute_kill_gold_no_synergy_matches_baseline() -> void:
	# AC-CS-11: synergy_id = "" → multiplier = 1.0; output equals MVP baseline.
	var orch: Node = _make_orch()

	# Across all 4 ((advantaged, losing_run)) combinations and tiers 1..5.
	for tier: int in range(1, 6):
		for advantaged_v: int in [0, 1]:
			for losing_v: int in [0, 1]:
				var advantaged: bool = bool(advantaged_v)
				var losing_run: bool = bool(losing_v)
				var baseline: int = orch.attribute_kill_gold(tier, advantaged, losing_run)
				var no_synergy: int = orch.attribute_kill_gold(
					tier, advantaged, losing_run, "", ""
				)
				assert_int(no_synergy).is_equal(baseline)


func test_attribute_kill_xp_no_synergy_matches_baseline() -> void:
	# tier × BASE_XP_PER_KILL when synergy_id is "".
	var orch: Node = _make_orch()

	for tier: int in range(1, 6):
		var baseline: int = orch.attribute_kill_xp(tier)
		var no_synergy: int = orch.attribute_kill_xp(tier, "")
		assert_int(no_synergy).is_equal(baseline)
		assert_int(baseline).is_equal(10 * tier)


# ===========================================================================
# Group F — Unknown synergy_id (AC-CS-18 forward-compat)
# ===========================================================================

func test_attribute_kill_gold_unknown_synergy_id_falls_back_to_baseline() -> void:
	# AC-CS-18: a hypothetical V1.5 synergy_id ("veteran_squad", "elite_vanguard")
	# loaded by V1.0 build returns 1.0 (no multiplier). Forward-compat:
	# graceful degradation, no crash.
	var orch: Node = _make_orch()

	var baseline: int = orch.attribute_kill_gold(3, true, false)
	var v15_unknown: int = orch.attribute_kill_gold(3, true, false, "veteran_squad", "bruiser")
	var another_v15: int = orch.attribute_kill_gold(3, true, false, "synchronized_strike", "")

	assert_int(v15_unknown).is_equal(baseline)
	assert_int(another_v15).is_equal(baseline)


func test_attribute_kill_xp_unknown_synergy_id_falls_back_to_baseline() -> void:
	var orch: Node = _make_orch()

	var baseline: int = orch.attribute_kill_xp(3)
	var v15_unknown: int = orch.attribute_kill_xp(3, "veteran_squad")
	var another: int = orch.attribute_kill_xp(3, "synchronized_strike")

	assert_int(v15_unknown).is_equal(baseline)
	assert_int(another).is_equal(baseline)


# ===========================================================================
# Group G — Cozy-register hard floor: AC-CS-16
# ===========================================================================

func test_synergy_multipliers_respect_cozy_register_cap() -> void:
	# AC-CS-16: all V1.0 synergy multipliers MUST be ≤ 1.5 (cozy-register
	# hard floor per GDD §G + OQ-32-6). Static-analysis-style invariant:
	# read the constants directly and assert.
	#
	# This test is the canonical AC-CS-16 enforcement. If a future tuning
	# pass violates the cap (e.g., raises STEEL_WALL_GOLD_MULT to 1.6),
	# this test fails immediately and the cap is restored OR the GDD's
	# cozy-register floor is explicitly raised (which would be a non-
	# shippable design change per Pillar 2).
	const HARD_FLOOR: float = 1.5
	assert_float(DungeonRunOrchestratorScript.STEEL_WALL_GOLD_MULT).is_less_equal(HARD_FLOOR)
	assert_float(DungeonRunOrchestratorScript.TRIPLE_THREAT_GOLD_MULT).is_less_equal(HARD_FLOOR)
	assert_float(DungeonRunOrchestratorScript.ARCANE_ELITE_XP_MULT).is_less_equal(HARD_FLOOR)
	# All multipliers are ALSO ≥ 1.0 (no negative-bonus synergies).
	assert_float(DungeonRunOrchestratorScript.STEEL_WALL_GOLD_MULT).is_greater_equal(1.0)
	assert_float(DungeonRunOrchestratorScript.TRIPLE_THREAT_GOLD_MULT).is_greater_equal(1.0)
	assert_float(DungeonRunOrchestratorScript.ARCANE_ELITE_XP_MULT).is_greater_equal(1.0)


# ===========================================================================
# Group H — Backwards-compat: 3-arg calls
# ===========================================================================

func test_attribute_kill_gold_3arg_signature_still_works() -> void:
	# Pre-S21-S1 callers invoking attribute_kill_gold(tier, advantaged, losing_run)
	# must continue to work unchanged. The new synergy_id + archetype
	# parameters default to "" / "" which produces the original 3-factor
	# result.
	var orch: Node = _make_orch()

	# 3-arg signature
	var three_arg: int = orch.attribute_kill_gold(2, true, false)
	# 5-arg signature with empty defaults
	var five_arg_empty: int = orch.attribute_kill_gold(2, true, false, "", "")

	assert_int(three_arg).is_equal(five_arg_empty)
	# Concrete value: floori(BASE_KILL[2] * 1.5 * 1.0) = floori(10 * 1.5) = 15
	assert_int(three_arg).is_equal(15)


func test_attribute_kill_xp_1arg_signature_works() -> void:
	# attribute_kill_xp is new in S21-S1; verify the 1-arg form (no synergy)
	# works as expected.
	var orch: Node = _make_orch()
	var one_arg: int = orch.attribute_kill_xp(3)
	assert_int(one_arg).is_equal(30)
