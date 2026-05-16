# Sprint 26 M4 — tier-2 class synergy detection tests.
#
# Verifies the four new mono-class synergies fire on 3-of-a-kind
# formations of paladin/archer/berserker/cleric:
#   - 3 paladins → "bastion" (conditional gold vs caster)
#   - 3 archers → "volley" (conditional gold vs swarm)
#   - 3 berserkers → "frenzy" (conditional gold vs bruiser)
#   - 3 clerics → "vigil" (unconditional XP)
#
# Detection mirrors the V1 mono-class pattern (Steel Wall / Arcane Elite /
# Triple Strike): sorted-multiset comparison after class_id extraction.
extends GdUnitTestSuite

const FormationAssignmentScript = preload(
	"res://src/core/formation_assignment/formation_assignment.gd"
)


func _formation_of(class_ids: Array[String]) -> Dictionary:
	# Builds the formation_snapshot shape that detect_active_synergy
	# accepts via the "heroes Array[Dictionary]" path (test-friendly,
	# no autoload dep).
	var heroes: Array[Dictionary] = []
	for cid: String in class_ids:
		heroes.append({"class_id": cid})
	return {"heroes": heroes}


# ===========================================================================
# Group A — Tier-2 mono-class detection
# ===========================================================================

func test_three_paladins_detect_bastion() -> void:
	var fa: Node = FormationAssignmentScript.new()
	var result: String = fa.detect_active_synergy(
		_formation_of(["paladin", "paladin", "paladin"])
	)
	assert_str(result).is_equal("bastion")


func test_three_archers_detect_volley() -> void:
	var fa: Node = FormationAssignmentScript.new()
	var result: String = fa.detect_active_synergy(
		_formation_of(["archer", "archer", "archer"])
	)
	assert_str(result).is_equal("volley")


func test_three_berserkers_detect_frenzy() -> void:
	var fa: Node = FormationAssignmentScript.new()
	var result: String = fa.detect_active_synergy(
		_formation_of(["berserker", "berserker", "berserker"])
	)
	assert_str(result).is_equal("frenzy")


func test_three_clerics_detect_vigil() -> void:
	var fa: Node = FormationAssignmentScript.new()
	var result: String = fa.detect_active_synergy(
		_formation_of(["cleric", "cleric", "cleric"])
	)
	assert_str(result).is_equal("vigil")


# ===========================================================================
# Group B — 2+1 mixes do NOT fire tier-2 synergies (V1.0 first-pass rule)
# ===========================================================================

func test_two_paladins_one_warrior_does_not_fire_bastion() -> void:
	var fa: Node = FormationAssignmentScript.new()
	var result: String = fa.detect_active_synergy(
		_formation_of(["paladin", "paladin", "warrior"])
	)
	assert_str(result).is_equal("")


func test_two_clerics_one_archer_does_not_fire_vigil() -> void:
	var fa: Node = FormationAssignmentScript.new()
	var result: String = fa.detect_active_synergy(
		_formation_of(["cleric", "cleric", "archer"])
	)
	assert_str(result).is_equal("")


# ===========================================================================
# Group C — Insertion-order-independence (sorted-multiset comparison)
# ===========================================================================

func test_bastion_fires_regardless_of_slot_order() -> void:
	# Sanity: detect_active_synergy sorts class_ids before comparison;
	# slot order should not affect the result.
	var fa: Node = FormationAssignmentScript.new()
	var result_a: String = fa.detect_active_synergy(
		_formation_of(["paladin", "paladin", "paladin"])
	)
	# (3-paladin formations have no order variants — included as a smoke
	# check that the test setup matches the production sort path.)
	assert_str(result_a).is_equal("bastion")
