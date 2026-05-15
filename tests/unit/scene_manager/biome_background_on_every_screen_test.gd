# Sprint 22 S22-M3 — every non-modal screen has a BiomeBackground child.
#
# Pre-S22-M3 state: only guild_hall + dungeon_run_view instanced
# BiomeBackground. Pure-black backgrounds on Recruit / Dispatch (formation
# assignment) / Victory Moment / Return-to-App were the dominant
# demo-quality signal in the 2026-05-15 playtest screenshots.
#
# Post-S22-M3: every screen the player can land on has BiomeBackground at
# z=-1 (per ADR-0019 §Decision 1 layer-order contract). Defaults to the
# cozy tavern preset for guild-side activities; victory_moment uses the
# cleared biome's preset for thematic continuity with the run.
#
# Modals (hero_detail_modal) intentionally do NOT carry BiomeBackground —
# they DIM the underlying screen via DimBackdrop, so the caller's biome
# shows through (dimmed) and a modal-owned background would either be
# invisible behind the dim or violate the modal-over-screen layer pattern.
#
# This test asserts the structural invariant: every screen path the player
# can land on instances BiomeBackground.
extends GdUnitTestSuite

# Screens that MUST have BiomeBackground as a direct child after S22-M3.
const SCREENS_REQUIRING_BIOME_BG: Array[String] = [
	"res://assets/screens/guild_hall/guild_hall.tscn",
	"res://assets/screens/dungeon_run_view/dungeon_run_view.tscn",
	"res://assets/screens/recruitment/recruitment.tscn",
	"res://assets/screens/formation_assignment/formation_assignment.tscn",
	"res://assets/screens/victory_moment/victory_moment.tscn",
	"res://assets/screens/return_to_app/return_to_app.tscn",
]


func test_every_player_facing_screen_has_biome_background_child() -> void:
	for path: String in SCREENS_REQUIRING_BIOME_BG:
		var packed: PackedScene = load(path) as PackedScene
		assert_object(packed).override_failure_message(
			"Failed to load screen scene at '%s' — check path." % path
		).is_not_null()

		var instance: Node = packed.instantiate()
		auto_free(instance)
		var biome_bg: Node = instance.get_node_or_null("BiomeBackground")
		assert_object(biome_bg).override_failure_message(
			"Screen '%s' is missing a direct BiomeBackground child. Sprint 22 "
			+ "S22-M3 requires every player-facing screen to instance the "
			+ "BiomeBackground at z=-1 per ADR-0019 §Decision 1 layer-order "
			+ "contract — no more pure-black backgrounds." % path
		).is_not_null()


func test_biome_background_is_color_rect_subclass() -> void:
	# BiomeBackground extends ColorRect; this guards against a refactor that
	# accidentally swaps the base type and breaks the z=-1 layer contract.
	for path: String in SCREENS_REQUIRING_BIOME_BG:
		var packed: PackedScene = load(path) as PackedScene
		var instance: Node = packed.instantiate()
		auto_free(instance)
		var biome_bg: Node = instance.get_node_or_null("BiomeBackground")
		if biome_bg == null:
			continue  # covered by the test above
		assert_bool(biome_bg is ColorRect).override_failure_message(
			"Screen '%s' BiomeBackground child is not a ColorRect subclass. "
			+ "Got class: %s" % [path, biome_bg.get_class()]
		).is_true()
