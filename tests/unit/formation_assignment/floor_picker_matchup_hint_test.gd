# Sprint 28 S28-S1 — Per-floor matchup hint on the floor picker.
#
# Tests the two helpers extracted from _render_floor_picker_biome_tabs():
#   _build_archetype_to_class_map() -> Dictionary[String, String]
#   _recommended_class_for_floor(floor_data, archetype_to_class) -> String
#
# All tests operate on a FormationAssignment screen instance so the helpers
# have access to EnemyDatabase and HeroClassDatabase autoloads. Autoload state
# is read-only here (no unlock-state mutations), so no save-data snapshot is
# required. Pattern mirrors floor_picker_available_biomes_filter_test.gd and
# floor_picker_lock_indicator_test.gd exactly.
extends GdUnitTestSuite

const FormationAssignmentScene = preload(
	"res://assets/screens/formation_assignment/formation_assignment.tscn"
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Instantiate and enter the screen so all @onready refs are valid.
## Returns the screen node (auto_free registered).
func _make_screen() -> Node:
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	screen.on_enter()
	return screen


## Build a typed Floor resource populated with the given enemy_list entries.
## Each entry: { "enemy_id": String, "count": int }.
## Returns a Floor resource (NOT added to DataRegistry — used as a pure data
## bag for the helper under test).
func _make_floor(entries: Array[Dictionary]) -> Floor:
	var floor_res: Floor = Floor.new()
	floor_res.enemy_list = entries
	return floor_res


# ---------------------------------------------------------------------------
# Group A — _build_archetype_to_class_map correctness
# ---------------------------------------------------------------------------

func test_build_archetype_to_class_map_returns_bruiser_counter() -> void:
	# Arrange
	var screen: Node = _make_screen()
	# Act
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	# Assert — "bruiser" must map to a class display name (not empty)
	assert_bool(map.has("bruiser")).is_true().override_failure_message(
		"Expected archetype map to contain 'bruiser'. Got keys: %s" % str(map.keys())
	)
	assert_str(String(map.get("bruiser", ""))).is_not_empty().override_failure_message(
		"Expected bruiser counter to be a non-empty class name"
	)


func test_build_archetype_to_class_map_first_wins_on_collision() -> void:
	# HeroClassDatabase.get_all_ids() returns alphabetically sorted IDs.
	# "berserker" (counter_archetype=bruiser) sorts before "warrior" (counter_archetype=bruiser).
	# First-wins means bruiser → "Berserker", not "Warrior".
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	# Both warrior and berserker counter bruiser; berserker is alphabetically first.
	assert_str(String(map.get("bruiser", ""))).is_equal("Berserker").override_failure_message(
		"Expected first-wins collision resolution: bruiser → Berserker (alpha before Warrior). "
		+ "Got: '%s'" % str(map.get("bruiser", ""))
	)


# ---------------------------------------------------------------------------
# Group B — _recommended_class_for_floor core logic
# ---------------------------------------------------------------------------

func test_recommended_class_for_floor_all_bruiser_enemies_returns_berserker() -> void:
	# Arrange — floor with bruiser enemies only.
	# hollow_brute.archetype = "bruiser" (verified in assets/data/enemies/).
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	var el: Array[Dictionary] = [{"enemy_id": "hollow_brute", "count": 5}]
	var floor_res: Floor = _make_floor(el)
	# Act
	var result: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	# Assert — bruiser → first alphabetical counter class = Berserker
	assert_str(result).is_equal("Berserker").override_failure_message(
		"Floor full of bruisers should recommend Berserker (first bruiser-counter). Got: '%s'" % result
	)


func test_recommended_class_for_floor_all_caster_enemies_returns_mage() -> void:
	# Arrange — marrow_witch.archetype = "caster".
	# "mage" sorts before "paladin" alphabetically; both counter caster.
	# First-wins → Mage.
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	var el: Array[Dictionary] = [{"enemy_id": "marrow_witch", "count": 3}]
	var floor_res: Floor = _make_floor(el)
	# Act
	var result: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	# Assert
	assert_str(result).is_equal("Mage").override_failure_message(
		"Floor full of casters should recommend Mage (first caster-counter). Got: '%s'" % result
	)


func test_recommended_class_for_floor_mixed_archetypes_dominant_wins() -> void:
	# Arrange — 3 bruiser + 1 caster. Dominant = bruiser → Berserker.
	# hollow_brute=bruiser, marrow_witch=caster.
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	var el: Array[Dictionary] = [
		{"enemy_id": "hollow_brute", "count": 3},
		{"enemy_id": "marrow_witch", "count": 1},
	]
	var floor_res: Floor = _make_floor(el)
	# Act
	var result: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	# Assert — bruiser (count 3) > caster (count 1)
	assert_str(result).is_equal("Berserker").override_failure_message(
		"Dominant archetype (bruiser, count=3) should win over minority (caster, count=1). "
		+ "Got: '%s'" % result
	)


func test_recommended_class_for_floor_tie_first_in_enemy_list_order_wins() -> void:
	# Arrange — 2 bruiser + 2 caster, tied on count.
	# enemy_list order: hollow_brute (bruiser) appears FIRST → bruiser wins tie.
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	var el: Array[Dictionary] = [
		{"enemy_id": "hollow_brute", "count": 2},
		{"enemy_id": "marrow_witch", "count": 2},
	]
	var floor_res: Floor = _make_floor(el)
	# Act — run multiple times to confirm the result is deterministic
	var result_a: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	var result_b: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	# Assert — first-seen archetype (bruiser, via hollow_brute first in list) wins
	assert_str(result_a).is_equal("Berserker").override_failure_message(
		"Tie should resolve to first-encountered archetype in enemy_list order (bruiser). "
		+ "Got: '%s'" % result_a
	)
	assert_str(result_a).is_equal(result_b).override_failure_message(
		"Result must be deterministic across repeated calls. "
		+ "First: '%s', Second: '%s'" % [result_a, result_b]
	)


func test_recommended_class_for_floor_unmatched_archetype_returns_empty() -> void:
	# Arrange — create a floor whose enemy archetype has no class counter.
	# We'll create a synthetic Floor with a fake enemy_id that resolves to
	# an archetype not in the map. Because EnemyDatabase.get_by_id() returns
	# null on miss, we test the null-guard path with a nonexistent enemy_id.
	# Additionally test via a real enemy with archetype="" (edge case per spec):
	# use a Floor with only an enemy_id not present in EnemyDatabase.
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	# "nonexistent_enemy" will return null from EnemyDatabase.get_by_id() → skipped
	var el: Array[Dictionary] = [{"enemy_id": "nonexistent_enemy", "count": 5}]
	var floor_res: Floor = _make_floor(el)
	# Act
	var result: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	# Assert — null return from get_by_id → no archetype tallied → returns ""
	assert_str(result).is_empty().override_failure_message(
		"Unresolvable enemy_id should produce empty recommendation, got: '%s'" % result
	)


func test_recommended_class_for_floor_empty_enemy_list_returns_empty() -> void:
	# Arrange — floor with no enemies at all (valid authoring placeholder per Floor schema).
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	var el: Array[Dictionary] = []
	var floor_res: Floor = _make_floor(el)
	# Act
	var result: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	# Assert
	assert_str(result).is_empty().override_failure_message(
		"Empty enemy_list should produce empty recommendation, got: '%s'" % result
	)


func test_recommended_class_for_floor_null_enemy_id_skipped_no_crash() -> void:
	# Arrange — mix of one valid enemy and one invalid enemy_id.
	# The null-guard must skip the bad entry and still tally the valid one.
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	# hollow_brute (bruiser, valid) + "bad_id" (null return, skipped)
	var el: Array[Dictionary] = [
		{"enemy_id": "bad_id_does_not_exist", "count": 1},
		{"enemy_id": "hollow_brute", "count": 2},
	]
	var floor_res: Floor = _make_floor(el)
	# Act — must not crash, and must return bruiser-counter based on hollow_brute
	var result: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	# Assert — valid enemy counted despite bad entry before it
	assert_str(result).is_equal("Berserker").override_failure_message(
		"Null get_by_id result should be skipped; valid enemies still tallied. "
		+ "Got: '%s'" % result
	)


func test_recommended_class_for_floor_null_enemy_id_value_skipped_no_crash() -> void:
	# Regression (adversarial Finding 1): a present-but-NULL enemy_id value must be
	# skipped, NOT fatally crash a bare String(null) cast and abort the selection
	# chain. .get("enemy_id", "") returns the default only on a MISSING key, not a
	# present-but-null one — so the type-guard is what protects this path.
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	var el: Array[Dictionary] = [
		{"enemy_id": null, "count": 9},
		{"enemy_id": "hollow_brute", "count": 2},
	]
	var floor_res: Floor = _make_floor(el)
	# Act — must not crash; the null entry is skipped, valid bruiser still tallied.
	var result: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	assert_str(result).is_equal("Berserker").override_failure_message(
		"Null enemy_id value must be skipped (not crash String()); valid enemies still win. "
		+ "Got: '%s'" % result
	)


func test_recommended_class_for_floor_non_string_enemy_id_skipped() -> void:
	# Regression (adversarial Finding 1): a non-string enemy_id (e.g. an int) must
	# be skipped via the typeof guard, not coerced/crashed.
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	var el: Array[Dictionary] = [{"enemy_id": 42, "count": 5}]
	var floor_res: Floor = _make_floor(el)
	var result: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	assert_str(result).is_empty().override_failure_message(
		"Non-string enemy_id must be skipped → no recommendation, no crash. Got: '%s'" % result
	)


func test_recommended_class_for_floor_non_numeric_count_treated_as_zero() -> void:
	# Regression (adversarial Finding 2): a null/non-numeric count must coerce to 0
	# without a runtime error or mis-tally. Here hollow_brute count=null (→0) and
	# marrow_witch count=2 → caster dominant → Mage.
	var screen: Node = _make_screen()
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	var el: Array[Dictionary] = [
		{"enemy_id": "hollow_brute", "count": null},
		{"enemy_id": "marrow_witch", "count": 2},
	]
	var floor_res: Floor = _make_floor(el)
	var result: String = String(screen.call("_recommended_class_for_floor", floor_res, map))
	assert_str(result).is_equal("Mage").override_failure_message(
		"Null count must coerce to 0 (not crash/mis-tally); caster (count 2) wins → Mage. "
		+ "Got: '%s'" % result
	)


# ---------------------------------------------------------------------------
# Group C — selection wiring (regression guard for the S28-S1 dead-wire bug:
# the FloorRecommendationLabel was created hidden but never populated on floor
# selection, so the feature was non-functional despite the helpers being correct
# and unit-tested. This test exercises the selection → helper → label chain.)
# ---------------------------------------------------------------------------

func test_select_floor_populates_recommendation_label_from_helper() -> void:
	# Arrange — fresh unlock state, then open the picker (builds tabs + the
	# FloorRecommendationLabel) and select forest_reach F1 (always unlocked,
	# enemy_list = hollow_brute×3 + glowmoth×1 → dominant bruiser → Berserker).
	var fu: Node = get_tree().root.get_node_or_null("FloorUnlock")
	var fu_snapshot: Dictionary = fu.get_save_data()
	fu.load_save_data({"highest_cleared": {"forest_reach": 0}})
	var screen: Node = _make_screen()
	screen.call("_show_floor_picker")

	# Act
	screen.call("_select_floor_in_picker", "forest_reach", 1)

	# Assert — the label exists and its state matches the helper's verdict for
	# that exact floor (proves the selection is wired to the recommendation
	# logic, not a hidden placeholder).
	var label: Label = null
	for n: Node in screen.find_children("FloorRecommendationLabel", "Label", true, false):
		label = n as Label
		break
	assert_object(label).is_not_null().override_failure_message(
		"FloorRecommendationLabel must exist after opening the picker."
	)
	var map: Dictionary = screen.call("_build_archetype_to_class_map") as Dictionary
	var floors: Array = (screen.get("_fp_floors_by_biome") as Dictionary).get("forest_reach", []) as Array
	var floor1: Floor = null
	for f: Resource in floors:
		if int(f.floor_index) == 1:
			floor1 = f as Floor
			break
	assert_object(floor1).is_not_null().override_failure_message(
		"forest_reach floor 1 should be present in the picker's floor cache."
	)
	var expected: String = String(screen.call("_recommended_class_for_floor", floor1, map))
	# forest_reach F1 has a matchable bruiser-dominant enemy_list, so the visible
	# branch is exercised — this is the branch the dead-wire bug broke.
	if expected == "":
		assert_bool(label.visible).is_false().override_failure_message(
			"Label should be hidden when the selected floor has no recommendation."
		)
	else:
		assert_bool(label.visible).is_true().override_failure_message(
			"Label must be VISIBLE when a recommendation exists — a hidden label here "
			+ "is the dead-wire regression (selection never populated the label)."
		)
		assert_str(label.text).contains(expected).override_failure_message(
			"Label text should contain the recommended class '%s'; got '%s'." % [expected, label.text]
		)

	# Cleanup — restore live FloorUnlock state (test isolation).
	fu.load_save_data(fu_snapshot)
