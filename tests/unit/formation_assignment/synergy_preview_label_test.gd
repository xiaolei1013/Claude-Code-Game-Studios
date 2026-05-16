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


# Note (Sprint 24 S24-M3): tier-mapper tests (AC-CS-22..25) moved to
# tests/unit/ui_framework/ui_framework_helpers_test.gd Groups F+G, where
# the synergy_id_to_tier helper now lives.


# ===========================================================================
# Group D — Effect text rendering (Sprint 27 M1)
#
# The preview label now answers BOTH "what synergy is active?" AND "what
# does it do?" in one line. Effect text comes from class_synergy_effect_<id>
# locale keys (already shipped in en.csv since V1; surfaced in UI here).
# ===========================================================================

func test_synergy_preview_label_renders_steel_wall_effect_text() -> void:
	# Arrange — 3 warriors → Steel Wall
	_seed_three_warriors()

	# Act
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	screen.on_enter()

	# Assert — label contains the effect text (writer-locked: "+25% gold vs bruisers")
	var label_text: String = screen._synergy_preview_label.text
	var expected_effect: String = tr("class_synergy_effect_steel_wall")
	assert_bool(label_text.contains(expected_effect)).override_failure_message(
		"Expected preview to contain effect text '%s' for Steel Wall; got '%s'"
		% [expected_effect, label_text]
	).is_true()


func test_synergy_preview_label_includes_em_dash_separator_for_effect() -> void:
	# Arrange — 3 warriors → Steel Wall fires
	_seed_three_warriors()

	# Act
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	screen.on_enter()

	# Assert — separator "—" appears between display name and effect
	# Format: "Synergy: Gold (Steel Wall) — +25% gold vs bruisers"
	assert_bool(screen._synergy_preview_label.text.contains("—")).override_failure_message(
		"Expected preview to contain em-dash separator '—' between display name and effect; "
		+ "got '%s'" % screen._synergy_preview_label.text
	).is_true()


func test_synergy_preview_label_no_effect_text_when_no_synergy() -> void:
	# Arrange — clear the roster so no synergy is possible
	for h_v: Variant in HeroRoster.get_all_heroes():
		HeroRoster._heroes.erase(int(h_v.get("instance_id")))
	for slot: int in range(3):
		HeroRoster.set_formation_slot(slot, 0)

	# Act
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	screen.on_enter()

	# Assert — "Synergy: None" format does NOT include effect text
	# (None state uses synergy_preview_none_format, no effect column).
	# The em-dash separator should NOT appear in the no-synergy state.
	assert_bool(screen._synergy_preview_label.text.contains("—")).override_failure_message(
		"Did not expect em-dash in no-synergy preview text; got '%s'"
		% screen._synergy_preview_label.text
	).is_false()
