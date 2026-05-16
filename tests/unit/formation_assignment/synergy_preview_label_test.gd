# Sprint 23 S23-N2 + Sprint 24 S24-M2 — Dispatch synergy preview label tests.
#
# The preview label is always-visible above the slot row. Sprint 24 S24-M2
# refreshed the format per the V2 Tier Ladder (class-synergy-system.md §C.6):
#   - "Synergy: None" when slot composition doesn't match a known synergy
#   - "Synergy: <tier> (<display_name>)" when the composition matches one
#     e.g., "Synergy: Gold (Steel Wall)", "Synergy: Platinum (Triple Threat)"
#
# Distinct from the cozy SynergyBadge (covered by synergy_badge_test.gd) —
# the badge animates on detection edges; the preview label updates every
# slot edit.
#
# Acceptance criteria from class-synergy-system.md §H:
#   AC-CS-22 — synergy_id_to_tier("") → "none"
#   AC-CS-23 — synergy_id_to_tier(steel_wall|arcane_elite|triple_strike) → "gold"
#   AC-CS-24 — synergy_id_to_tier("triple_threat") → "platinum"
#   AC-CS-25 — synergy_id_to_tier("<unknown>") → "none" (defensive)
#   AC-CS-26 — Label renders "Synergy: {tier} ({display_name})" per V2 format
extends GdUnitTestSuite

const FormationAssignmentScene = preload(
	"res://assets/screens/formation_assignment/formation_assignment.tscn"
)
const FormationAssignmentScript = preload(
	"res://assets/screens/formation_assignment/formation_assignment.gd"
)
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


var _snapshot_roster: Dictionary = {}


func before_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_snapshot_roster = roster.get_save_data() if roster != null else {}


func after_test() -> void:
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and not _snapshot_roster.is_empty():
		roster.load_save_data(_snapshot_roster)


func _seed_three_warriors() -> Array[int]:
	# Erase existing heroes so the seeded warriors are unambiguously the
	# only members of the roster.
	var roster: Node = HeroRoster
	for h_v: Variant in roster.get_all_heroes():
		HeroRoster._heroes.erase(int(h_v.get("instance_id")))
	var ids: Array[int] = []
	for i: int in range(3):
		var inst: RefCounted = roster.call("add_hero", "warrior")
		if inst != null:
			ids.append(int(inst.get("instance_id")))
	# Assign each warrior to a formation slot 0..2.
	for slot: int in range(3):
		if slot < ids.size():
			HeroRoster.set_formation_slot(slot, ids[slot])
	return ids


# ===========================================================================
# Group A — Preview label exists + initial state
# ===========================================================================

func test_synergy_preview_label_exists_on_dispatch_screen() -> void:
	# Arrange + Act
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)

	# Assert — node is reachable at the canonical path.
	var label: Label = screen.get_node(
		"FormationPanel/FormationVBox/SynergyPreviewLabel"
	) as Label
	assert_object(label).is_not_null()


func test_synergy_preview_label_starts_at_none_when_no_synergy() -> void:
	# Arrange — clear the roster so no synergy is possible.
	for h_v: Variant in HeroRoster.get_all_heroes():
		HeroRoster._heroes.erase(int(h_v.get("instance_id")))
	for slot: int in range(3):
		HeroRoster.set_formation_slot(slot, 0)

	# Act — render the screen.
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	screen.on_enter()

	# Assert — preview label text contains "None".
	assert_bool(screen._synergy_preview_label.text.contains("None")).override_failure_message(
		"Expected preview label to contain 'None' on empty formation; got '%s'"
		% screen._synergy_preview_label.text
	).is_true()


# ===========================================================================
# Group B — Preview label updates on synergy detection
# ===========================================================================

func test_synergy_preview_label_shows_steel_wall_for_three_warriors() -> void:
	# Arrange — three warriors in slots 0/1/2 trigger Steel Wall synergy.
	_seed_three_warriors()

	# Act — render the screen (on_enter triggers _refresh_synergy_badge).
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	screen.on_enter()

	# Assert — preview label contains the Steel Wall display name (writer-
	# locked under class_synergy_badge_steel_wall in en.csv).
	var expected_display: String = tr("class_synergy_badge_steel_wall")
	assert_bool(screen._synergy_preview_label.text.contains(expected_display)).override_failure_message(
		"Expected preview label to contain '%s' for 3-warrior Steel Wall; got '%s'"
		% [expected_display, screen._synergy_preview_label.text]
	).is_true()


# ===========================================================================
# Group C — V2 Tier Ladder rendering (S24-M2, AC-CS-26)
# ===========================================================================

func test_synergy_preview_label_renders_gold_tier_for_three_warriors() -> void:
	# Arrange — three warriors → Steel Wall → Gold tier per §C.6.
	_seed_three_warriors()

	# Act
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	screen.on_enter()

	# Assert — label format "Synergy: Gold (Steel Wall)" must contain both
	# the tier name AND the V1 display name.
	var label_text: String = screen._synergy_preview_label.text
	var expected_tier: String = tr("synergy_tier_gold")
	var expected_display: String = tr("class_synergy_badge_steel_wall")
	assert_bool(label_text.contains(expected_tier)).override_failure_message(
		"Expected preview to contain tier '%s' for 3-warrior Steel Wall; got '%s'"
		% [expected_tier, label_text]
	).is_true()
	assert_bool(label_text.contains(expected_display)).override_failure_message(
		"Expected preview to also contain display name '%s'; got '%s'"
		% [expected_display, label_text]
	).is_true()


# ===========================================================================
# Group D — synergy_id_to_tier mapping (AC-CS-22..25)
# ===========================================================================

func test_synergy_id_to_tier_empty_returns_none() -> void:
	# AC-CS-22: empty synergy_id → "none"
	assert_str(FormationAssignmentScript._synergy_id_to_tier("")).is_equal("none")


func test_synergy_id_to_tier_steel_wall_returns_gold() -> void:
	# AC-CS-23: steel_wall → "gold"
	assert_str(FormationAssignmentScript._synergy_id_to_tier("steel_wall")).is_equal("gold")


func test_synergy_id_to_tier_arcane_elite_returns_gold() -> void:
	# AC-CS-23: arcane_elite → "gold"
	assert_str(FormationAssignmentScript._synergy_id_to_tier("arcane_elite")).is_equal("gold")


func test_synergy_id_to_tier_triple_strike_returns_gold() -> void:
	# AC-CS-23: triple_strike → "gold"
	assert_str(FormationAssignmentScript._synergy_id_to_tier("triple_strike")).is_equal("gold")


func test_synergy_id_to_tier_triple_threat_returns_platinum() -> void:
	# AC-CS-24: triple_threat → "platinum" (the 1+1+1 balanced "completeness" tier)
	assert_str(FormationAssignmentScript._synergy_id_to_tier("triple_threat")).is_equal("platinum")


func test_synergy_id_to_tier_unknown_returns_none_defensive() -> void:
	# AC-CS-25: unknown synergy_id → "none" (defensive degrade)
	assert_str(FormationAssignmentScript._synergy_id_to_tier("nonexistent_synergy")).is_equal("none")
	assert_str(FormationAssignmentScript._synergy_id_to_tier("some_v2_5_future_id")).is_equal("none")
