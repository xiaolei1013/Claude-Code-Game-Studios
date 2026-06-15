# Sprint 19 S19-M3 — BiomeBackground node contract tests.
#
# Per `design/gdd/hd-2d-rendering-pipeline.md` (#26) §C.2 BiomeBackground node
# contract + §H Acceptance Criteria + ADR-0019 §Decision 3
# (programmatic-placeholder strategy). Locks the node's surface so future
# real-art swap-in (replace ColorRect with Sprite2D + texture) preserves
# the API: `set_biome(biome_id)`, `get_biome()`, `biome_changed` signal,
# z_index = -1, mouse_filter = MOUSE_FILTER_IGNORE, 7 palette presets,
# fallback to forest_reach on unknown.
#
# Test groups:
#   A — Scene + node contract (z_index, mouse_filter, anchors, script)
#   B — Palette mapping (7 contract palette keys produce distinct colors)
#   C — Fallback behavior (unknown / empty biome_id)
#   D — get_biome / biome_changed signal semantics
#   E — Guild Hall + DungeonRunView scene integration
#   F — Real-art swap-in (ADR-0019 §Decision 3): the BiomeArt TextureRect child
#       shows the committed per-biome PNG, hides for biomes with no shipped art,
#       and mirrors the boss-floor darken — without ever intercepting input.
extends GdUnitTestSuite

const BiomeBackgroundScene = preload("res://assets/screens/_shared/biome_background.tscn")
const BiomeBackgroundScript = preload("res://assets/screens/_shared/biome_background.gd")


func _make_instance() -> ColorRect:
	# Typed as ColorRect (BiomeBackground's base class) rather than the
	# class_name global because Godot 4.6's script registry can cold-load
	# globals after this script parses. Method calls dispatch dynamically.
	var inst: ColorRect = BiomeBackgroundScene.instantiate() as ColorRect
	add_child(inst)
	auto_free(inst)
	return inst


# ===========================================================================
# Group A — Scene + node contract
# ===========================================================================

func test_biome_background_scene_loads_as_packed_scene() -> void:
	# AC-26-09 / AC-26-10 precondition: the shared scene must load cleanly.
	assert_object(BiomeBackgroundScene).is_not_null()


func test_biome_background_instance_is_color_rect_subclass() -> void:
	# Real-art swap-in (Sprint 19+) may replace ColorRect with Sprite2D; for
	# now the placeholder ships as a ColorRect subclass. The script's class
	# inheritance is the contract surface.
	var bg: ColorRect = _make_instance()
	assert_bool(bg is ColorRect).is_true()


func test_biome_background_z_index_is_negative_one() -> void:
	# AC-26-09 + AC-26-10: BiomeBackground sits at z=-1 below all UI (z=0)
	# and below the WarmLanternOverlay (z=1). Per ADR-0019 §Decision 1
	# layer-order contract.
	var bg: ColorRect = _make_instance()
	assert_int(bg.z_index).override_failure_message(
		"BiomeBackground.z_index must be -1 (per ADR-0019 §Decision 1 layer-order "
		+ "contract). Got %d. UI sits at z=0; UI must render sharp above this."
		% bg.z_index
	).is_equal(-1)


func test_biome_background_mouse_filter_is_ignore() -> void:
	# AC-26-15: overlay ColorRects must NOT intercept input. mouse_filter
	# MOUSE_FILTER_IGNORE = 2.
	var bg: ColorRect = _make_instance()
	assert_int(bg.mouse_filter).override_failure_message(
		"BiomeBackground.mouse_filter must be MOUSE_FILTER_IGNORE (2) so it "
		+ "does not intercept taps on UI buttons. Got %d." % bg.mouse_filter
	).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_biome_background_anchors_full_rect() -> void:
	# GDD #26 §C.2 R2.1: BiomeBackground anchors at full-rect so window
	# resize is automatic via Godot's anchor system.
	var bg: ColorRect = _make_instance()
	assert_float(bg.anchor_right).is_equal(1.0)
	assert_float(bg.anchor_bottom).is_equal(1.0)
	assert_float(bg.anchor_left).is_equal(0.0)
	assert_float(bg.anchor_top).is_equal(0.0)


# ===========================================================================
# Group B — Palette mapping (AC-26-12)
# ===========================================================================

# The 7 contract palette keys per GDD #26 §G.3. The Sprint 19 RGB values are
# placeholders pending Art Bible §4 canonical RGB authoring; the test pins
# that each key produces a DISTINCT color (preventing accidental key collision)
# rather than the exact RGB tuple (which is allowed to be tuned).

func test_biome_background_renders_forest_reach_palette() -> void:
	var bg: ColorRect = _make_instance()
	bg.set_biome("forest_reach")
	assert_str(bg.get_biome()).is_equal("forest_reach")


func test_biome_background_renders_whispering_crags_palette() -> void:
	var bg: ColorRect = _make_instance()
	bg.set_biome("whispering_crags")
	assert_str(bg.get_biome()).is_equal("whispering_crags")


func test_biome_background_renders_sunken_ruins_palette() -> void:
	var bg: ColorRect = _make_instance()
	bg.set_biome("sunken_ruins")
	assert_str(bg.get_biome()).is_equal("sunken_ruins")


func test_biome_background_renders_hollow_stair_palette() -> void:
	var bg: ColorRect = _make_instance()
	bg.set_biome("hollow_stair")
	assert_str(bg.get_biome()).is_equal("hollow_stair")


func test_biome_background_renders_ember_wastes_palette() -> void:
	var bg: ColorRect = _make_instance()
	bg.set_biome("ember_wastes")
	assert_str(bg.get_biome()).is_equal("ember_wastes")


func test_biome_background_renders_frostmire_palette() -> void:
	var bg: ColorRect = _make_instance()
	bg.set_biome("frostmire")
	assert_str(bg.get_biome()).is_equal("frostmire")


func test_biome_background_renders_guild_hall_tavern_palette() -> void:
	var bg: ColorRect = _make_instance()
	bg.set_biome("guild_hall_tavern")
	assert_str(bg.get_biome()).is_equal("guild_hall_tavern")


func test_biome_background_seven_palette_keys_produce_distinct_colors() -> void:
	# Pins that the 7 contract keys produce 7 distinct colors. Future tuning
	# of individual RGB values is allowed; future merging of two keys to
	# the same color is the regression this test catches.
	var bg: ColorRect = _make_instance()
	var palette_keys: Array[String] = [
		"forest_reach", "whispering_crags", "sunken_ruins",
		"hollow_stair", "ember_wastes", "frostmire", "guild_hall_tavern",
	]
	var seen_colors: Dictionary[String, Color] = {}
	for key: String in palette_keys:
		bg.set_biome(key)
		seen_colors[key] = bg.color

	# Every pair of keys must produce different colors.
	for a: String in palette_keys:
		for b: String in palette_keys:
			if a == b:
				continue
			assert_bool(seen_colors[a] == seen_colors[b]).override_failure_message(
				"Palette keys '%s' and '%s' produced the same color %s — collision "
				+ "would make biomes visually indistinguishable. Tune PALETTE in "
				+ "biome_background.gd." % [a, b, str(seen_colors[a])]
			).is_false()


# ===========================================================================
# Group C — Fallback behavior (AC-26-12)
# ===========================================================================

func test_set_biome_with_unknown_id_falls_back_to_forest_reach() -> void:
	# AC-26-12: unknown biome_id falls back to forest_reach, NOT a crash or
	# blank screen. push_warning emitted (not asserted here — Godot warning
	# capture is brittle; the fallback behavior is the testable surface).
	var bg: ColorRect = _make_instance()
	bg.set_biome("nonexistent_biome_id_xyz")
	assert_str(bg.get_biome()).is_equal("forest_reach")


func test_set_biome_with_empty_string_falls_back_to_forest_reach() -> void:
	# Empty string is the "no run dispatched" case from DungeonRunOrchestrator.
	# get_dispatched_biome_id() returns "" when idle; DRV passes it straight
	# through and BiomeBackground falls back to forest_reach as the default.
	var bg: ColorRect = _make_instance()
	bg.set_biome("")
	assert_str(bg.get_biome()).is_equal("forest_reach")


# ===========================================================================
# Group D — get_biome / biome_changed signal semantics
# ===========================================================================

func test_get_biome_returns_empty_string_before_first_set() -> void:
	# Before set_biome() has been called, get_biome() returns empty. The
	# scene's color is whatever the .tscn default is — that's not the
	# script's responsibility to pin.
	var bg: ColorRect = _make_instance()
	assert_str(bg.get_biome()).is_equal("")


func test_biome_changed_signal_emits_on_biome_change() -> void:
	# AC-26-11 + GDD #26 §C.2: biome_changed signal fires when the resolved
	# biome_id actually changes. The test uses an inline lambda receiver to
	# capture the emission rather than gdunit4's signal API.
	var bg: ColorRect = _make_instance()
	var emissions: Array[Dictionary] = []
	bg.biome_changed.connect(
		func(old_id: String, new_id: String) -> void:
			emissions.append({"old": old_id, "new": new_id})
	)

	bg.set_biome("forest_reach")
	bg.set_biome("sunken_ruins")

	assert_int(emissions.size()).is_equal(2)
	assert_str(emissions[0]["old"]).is_equal("")
	assert_str(emissions[0]["new"]).is_equal("forest_reach")
	assert_str(emissions[1]["old"]).is_equal("forest_reach")
	assert_str(emissions[1]["new"]).is_equal("sunken_ruins")


func test_biome_changed_signal_does_not_emit_when_set_to_same_biome() -> void:
	# Idempotency: setting the same biome_id twice in a row emits once,
	# not twice. Avoids spurious crossfade re-triggers in any listener.
	#
	# Uses an Array wrapper because GDScript lambdas capture primitives by
	# value (so `var emit_count: int` + `emit_count += 1` inside the lambda
	# modifies a copy, not the outer variable). Array is captured by
	# reference; appending tracks each emission.
	var bg: ColorRect = _make_instance()
	var emissions: Array[bool] = []
	bg.biome_changed.connect(
		func(_old_id: String, _new_id: String) -> void:
			emissions.append(true)
	)

	bg.set_biome("ember_wastes")
	bg.set_biome("ember_wastes")
	bg.set_biome("ember_wastes")

	assert_int(emissions.size()).is_equal(1)


# ===========================================================================
# Group E — Scene integration (AC-26-09, AC-26-10)
# ===========================================================================

func test_guild_hall_scene_has_biome_background_at_z_minus_one() -> void:
	# AC-26-10: Guild Hall instance has a BiomeBackground child at z=-1.
	var packed: PackedScene = load("res://assets/screens/guild_hall/guild_hall.tscn") as PackedScene
	assert_object(packed).is_not_null()
	var instance: Node = packed.instantiate()
	auto_free(instance)
	var bg: ColorRect = instance.get_node_or_null("BiomeBackground") as ColorRect
	assert_object(bg).override_failure_message(
		"GuildHall scene must contain a BiomeBackground child node (per "
		+ "GDD #26 §C.1 layer-order contract; AC-26-10)"
	).is_not_null()
	assert_int(bg.z_index).is_equal(-1)


func test_dungeon_run_view_scene_has_biome_background_at_z_minus_one() -> void:
	# AC-26-09: DungeonRunView instance has a BiomeBackground child at z=-1.
	var packed: PackedScene = load("res://assets/screens/dungeon_run_view/dungeon_run_view.tscn") as PackedScene
	assert_object(packed).is_not_null()
	var instance: Node = packed.instantiate()
	auto_free(instance)
	var bg: ColorRect = instance.get_node_or_null("BiomeBackground") as ColorRect
	assert_object(bg).override_failure_message(
		"DungeonRunView scene must contain a BiomeBackground child node (per "
		+ "GDD #26 §C.1 layer-order contract; AC-26-09)"
	).is_not_null()
	assert_int(bg.z_index).is_equal(-1)


func test_orchestrator_exposes_public_dispatched_biome_id_getter() -> void:
	# Sprint 19 S19-M3 adds DungeonRunOrchestrator.get_dispatched_biome_id()
	# as the read-only public surface for DRV's BiomeBackground wiring.
	# Returns "" when no run is dispatched.
	assert_bool(DungeonRunOrchestrator.has_method("get_dispatched_biome_id")).override_failure_message(
		"DungeonRunOrchestrator.get_dispatched_biome_id() is the documented "
		+ "public surface for the BiomeBackground wiring in DungeonRunView.on_enter. "
		+ "GDD #26 §F lists it as a dependency."
	).is_true()
	# Idle state — no run dispatched yet in test env. Returns empty string.
	var biome_id: String = DungeonRunOrchestrator.get_dispatched_biome_id()
	assert_str(biome_id).is_equal("")


# ===========================================================================
# Group F — Real-art swap-in (ADR-0019 §Decision 3)
# ===========================================================================

# forest_reach ships a committed background PNG, anchoring the "has art" branch.
# As of Sprint 28 all 7 palette biomes ship committed art (guild_hall_tavern was
# the last holdout), so no real biome reaches the "no art" branch via set_biome
# anymore — an unknown id resolves to FALLBACK_BIOME_ID = forest_reach, which HAS
# art. The graceful-degradation branch of _update_art_layer is still load-bearing
# (a future biome added to PALETTE before its art ships, or a build with a
# stripped PNG, must fall back to the palette ColorRect rather than error), so it
# is pinned directly with a synthetic biome id that deliberately has no PNG.
const ART_BIOME_WITH_ART: String = "forest_reach"
const ART_BIOME_WITHOUT_ART: String = "__synthetic_biome_without_art__"
const ART_LAYER_NODE_NAME: String = "BiomeArt"
const BOSS_FLOOR_INDEX: int = 5  # mirrors BiomeBackground.BOSS_FLOOR_INDEX_MVP


func test_biome_with_committed_art_shows_visible_texture_layer() -> void:
	# set_biome() must add a "BiomeArt" TextureRect child, load the committed
	# PNG, and make it visible above the palette ColorRect.
	var bg: ColorRect = _make_instance()
	# Precondition: the committed asset must be importable. A failure here means
	# the PNG / .import sidecar wasn't committed — not a swap-in logic bug.
	assert_bool(
		ResourceLoader.exists("res://assets/art/backgrounds/%s.png" % ART_BIOME_WITH_ART)
	).override_failure_message(
		"Committed background art for '%s' is missing or un-imported. Group F "
		% ART_BIOME_WITH_ART
		+ "requires assets/art/backgrounds/%s.png + its .import sidecar committed "
		% ART_BIOME_WITH_ART
		+ "(CI regenerates .godot/imported/ from the sidecar)."
	).is_true()

	bg.set_biome(ART_BIOME_WITH_ART)

	var art: TextureRect = bg.get_node_or_null(ART_LAYER_NODE_NAME) as TextureRect
	assert_object(art).override_failure_message(
		"set_biome('%s') must create a '%s' TextureRect child for the real art."
		% [ART_BIOME_WITH_ART, ART_LAYER_NODE_NAME]
	).is_not_null()
	assert_bool(art.visible).is_true()
	assert_object(art.texture).is_not_null()


func test_guild_hall_tavern_shows_committed_art_layer() -> void:
	# Sprint 28: guild_hall_tavern now ships a committed interior backdrop
	# (assets/art/backgrounds/guild_hall_tavern.png), so the Guild Hall and the
	# Return-to-App screen (both use the tavern preset) show the warm tavern art
	# above the palette ColorRect instead of the flat amber-wood fallback.
	# Precondition: the PNG + .import sidecar must be committed (CI rebuilds
	# .godot/imported/ from the sidecar).
	assert_bool(
		ResourceLoader.exists("res://assets/art/backgrounds/guild_hall_tavern.png")
	).override_failure_message(
		"guild_hall_tavern background art is missing or un-imported — commit the "
		+ "PNG + its .import sidecar."
	).is_true()

	var bg: ColorRect = _make_instance()
	bg.set_biome("guild_hall_tavern")

	var art: TextureRect = bg.get_node_or_null(ART_LAYER_NODE_NAME) as TextureRect
	assert_object(art).override_failure_message(
		"set_biome('guild_hall_tavern') must create the '%s' art layer now that "
		% ART_LAYER_NODE_NAME
		+ "the tavern ships committed art."
	).is_not_null()
	assert_bool(art.visible).is_true()
	assert_object(art.texture).is_not_null()


func test_biome_art_layer_never_intercepts_input() -> void:
	# AC-26-15 parity: the real-art layer keeps mouse_filter=IGNORE + full-rect
	# anchors so it composites edge-to-edge without stealing taps from the UI
	# above it (z_index does NOT gate Godot input picking — taps route by tree
	# order, so a non-IGNORE backdrop child would swallow button presses).
	var bg: ColorRect = _make_instance()
	bg.set_biome(ART_BIOME_WITH_ART)
	var art: TextureRect = bg.get_node_or_null(ART_LAYER_NODE_NAME) as TextureRect
	assert_object(art).is_not_null()
	assert_int(art.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_float(art.anchor_right).is_equal(1.0)
	assert_float(art.anchor_bottom).is_equal(1.0)


func test_biome_without_committed_art_hides_layer_and_falls_back_to_palette() -> void:
	# A biome whose PNG is absent / un-imported must hide the BiomeArt layer and
	# clear its texture so the flat palette ColorRect shows through (graceful
	# degradation, not an error). All real biomes now ship art, so this branch is
	# driven directly through _update_art_layer with a synthetic id that has no
	# committed PNG — set_biome can no longer reach it (unknown ids resolve to
	# FALLBACK_BIOME_ID, which has art).
	var bg: ColorRect = _make_instance()
	# Invariant: the synthetic id must genuinely have no committed art, else the
	# assertions below would be vacuous.
	assert_bool(
		ResourceLoader.exists("res://assets/art/backgrounds/%s.png" % ART_BIOME_WITHOUT_ART)
	).override_failure_message(
		"Test invariant broken: '%s' must have NO committed background PNG."
		% ART_BIOME_WITHOUT_ART
	).is_false()

	bg._update_art_layer(ART_BIOME_WITHOUT_ART, 0)

	var art: TextureRect = bg.get_node_or_null(ART_LAYER_NODE_NAME) as TextureRect
	# _update_art_layer lazily creates the layer (via _ensure_art_layer), then
	# hides it + nulls the texture when no PNG exists.
	assert_object(art).override_failure_message(
		"_update_art_layer must lazily create the '%s' layer even when hiding it."
		% ART_LAYER_NODE_NAME
	).is_not_null()
	assert_bool(art.visible).override_failure_message(
		"'%s' has no committed art; BiomeArt must be hidden so the palette "
		% ART_BIOME_WITHOUT_ART
		+ "ColorRect shows through."
	).is_false()
	assert_object(art.texture).is_null()


func test_biome_art_layer_darkens_on_boss_floor() -> void:
	# Parity with the palette boss-floor modulation: a real-art boss floor
	# (floor_index == BOSS_FLOOR_INDEX_MVP) darkens the texture via modulate so
	# it reads as the same "dusk → night" transition the palette applies.
	var bg: ColorRect = _make_instance()
	bg.set_biome(ART_BIOME_WITH_ART, BOSS_FLOOR_INDEX)
	var art: TextureRect = bg.get_node_or_null(ART_LAYER_NODE_NAME) as TextureRect
	assert_object(art).is_not_null()
	assert_bool(art.visible).is_true()
	assert_float(art.modulate.r).override_failure_message(
		"Boss-floor (floor %d) real art must be darkened (modulate.r < 1.0) to "
		% BOSS_FLOOR_INDEX
		+ "match the palette boss modulation. Got %s." % str(art.modulate.r)
	).is_less(1.0)


func test_biome_art_layer_full_brightness_on_regular_floor() -> void:
	# Regular floors render the art at full brightness — modulate stays white
	# so the daytime palette reads cozy, not dim.
	var bg: ColorRect = _make_instance()
	bg.set_biome(ART_BIOME_WITH_ART, 1)
	var art: TextureRect = bg.get_node_or_null(ART_LAYER_NODE_NAME) as TextureRect
	assert_object(art).is_not_null()
	assert_bool(art.visible).is_true()
	assert_float(art.modulate.r).is_equal(1.0)
