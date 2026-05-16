# Sprint 23 S23-N2 — Dispatch synergy preview label tests.
#
# The preview label is always-visible above the slot row. It shows:
#   - "Synergy: None" when slot composition doesn't match a known synergy
#   - "Synergy: <display_name>" when the composition matches one
#
# Distinct from the cozy SynergyBadge (covered by synergy_badge_test.gd) —
# the badge animates on detection edges; the preview label updates every
# slot edit.
extends GdUnitTestSuite

const FormationAssignmentScene = preload(
	"res://assets/screens/formation_assignment/formation_assignment.tscn"
)
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")


var _snapshot_roster: Dictionary = {}


func before_test() -> void:
	# Sprint 24 S24-S3 — fixture handles snapshot+reset in one step.
	_snapshot_roster = HeroRosterFixture.snapshot_via_save_data()


func after_test() -> void:
	HeroRosterFixture.restore_via_load_save_data(_snapshot_roster)


func _seed_three_warriors() -> Array[int]:
	HeroRosterFixture.reset_hero_roster()
	return HeroRosterFixture.seed_warriors(3)


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
