# Sprint 22 S22-M4 — every non-modal screen has an IdentityHeader-marked Label.
#
# Pre-S22-M4 state: only 5 of 8 screens had a Label using the IdentityHeader
# theme variation (Lantern Gold + IM Fell English + Slate Ink outline at
# 32px). Screens without a clear visual "you are here" title (Guild Hall,
# Dungeon Run View, Return-to-App) rendered with no anchor cue for the
# player — a clarity gap surfaced by the 2026-05-15 playtest screenshots.
#
# Post-S22-M4: every player-facing screen has at least one Label with
# theme_type_variation = "IdentityHeader" as a top-level identifier.
extends GdUnitTestSuite

# Screens that MUST have at least one IdentityHeader-marked Label.
# Modals (hero_detail_modal) are exempt — they use the DimBackdrop pattern
# and rely on the underlying screen's IdentityHeader.
const SCREENS_REQUIRING_IDENTITY_HEADER: Array[String] = [
	"res://assets/screens/guild_hall/guild_hall.tscn",
	"res://assets/screens/recruitment/recruitment.tscn",
	"res://assets/screens/formation_assignment/formation_assignment.tscn",
	"res://assets/screens/dungeon_run_view/dungeon_run_view.tscn",
	"res://assets/screens/victory_moment/victory_moment.tscn",
	"res://assets/screens/return_to_app/return_to_app.tscn",
]


## Recursively walk the scene tree and return true if any Label child has
## theme_type_variation == &"IdentityHeader".
func _has_identity_header_label(node: Node) -> bool:
	if node is Label and node.theme_type_variation == &"IdentityHeader":
		return true
	for child: Node in node.get_children():
		if _has_identity_header_label(child):
			return true
	return false


func test_every_player_facing_screen_has_identity_header_label() -> void:
	for path: String in SCREENS_REQUIRING_IDENTITY_HEADER:
		var packed: PackedScene = load(path) as PackedScene
		assert_object(packed).override_failure_message(
			"Failed to load screen scene at '%s' — check path." % path
		).is_not_null()

		var instance: Node = packed.instantiate()
		auto_free(instance)
		assert_bool(_has_identity_header_label(instance)).override_failure_message(
			"Screen '%s' is missing an IdentityHeader-marked Label. Sprint 22 "
			+ "S22-M4 requires every player-facing screen to have at least one "
			+ "Label with theme_type_variation = &\"IdentityHeader\" so the "
			+ "player always knows what screen they're on." % path
		).is_true()
