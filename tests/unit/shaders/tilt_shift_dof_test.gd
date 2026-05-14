# Sprint 18 N1 — tilt-shift DoF shader contract test.
#
# Locks down the .gdshader's uniform surface so Vertical Slice tier
# tuning work (per ADR-0017 pivot triggers) and future per-biome tuning
# inherit a stable interface. Mirrors the warm_lantern_overlay_test.gd
# strategy from Sprint 15 N2 — string-grep contract check independent of
# Godot's Shader/ShaderMaterial introspection API.
#
# Per design/gdd/hd-2d-rendering-pipeline.md + game-concept.md Pillar 4
# Visual Identity Anchor. Composes with the warm-lantern overlay
# (tilt-shift runs first, lantern runs on top — verified by scene
# z_index in test 4).
extends GdUnitTestSuite

const SHADER_PATH: String = "res://assets/shaders/tilt_shift_dof.gdshader"


# ---------------------------------------------------------------------------
# Test 1 — shader loads as a Shader resource
# ---------------------------------------------------------------------------

func test_tilt_shift_dof_shader_resource_loads() -> void:
	var shader: Shader = load(SHADER_PATH) as Shader
	assert_object(shader).override_failure_message(
		"Failed to load shader at %s" % SHADER_PATH
	).is_not_null()


# ---------------------------------------------------------------------------
# Test 2 — exposes the 5 contract uniforms + the Godot 4.x screen-texture binding
# ---------------------------------------------------------------------------

# Per the shader source: focus_y, focus_height, blur_strength,
# falloff_softness, enabled (all float — `enabled` is float for cheap
# multiplication, not bool). Plus `screen_texture` with hint_screen_texture
# which is the Godot 4.x BackBufferCopy binding (the 3.x SCREEN_TEXTURE
# builtin was removed in 4.0).
#
# Strategy: read the shader source as text and grep for declarations.
# Pure-string contract check — independent of Godot's introspection API.
func test_tilt_shift_dof_shader_exposes_contract_uniforms() -> void:
	var file: FileAccess = FileAccess.open(SHADER_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var src: String = file.get_as_text()
	file.close()

	var expected_declarations: Array[String] = [
		"uniform float focus_y",
		"uniform float focus_height",
		"uniform float blur_strength",
		"uniform float falloff_softness",
		"uniform float enabled",
		"uniform sampler2D screen_texture",
		"hint_screen_texture",
	]

	var missing: Array[String] = []
	for decl: String in expected_declarations:
		if not src.contains(decl):
			missing.append(decl)

	assert_int(missing.size()).override_failure_message(
		"Missing contract declarations: %s. Vertical Slice tier tuning + "
		+ "per-biome shader-material instantiation depends on these names "
		+ "and the Godot 4.x hint_screen_texture binding. Restore them in "
		+ "assets/shaders/tilt_shift_dof.gdshader."
		% str(missing)
	).is_equal(0)


# ---------------------------------------------------------------------------
# Test 3 — Guild Hall scene loads with the tilt-shift material attached
# ---------------------------------------------------------------------------

# Catches the regression where the shader file is moved/renamed without
# updating the guild_hall.tscn ext_resource reference. Mirrors the
# warm-lantern test's scene-resolution check.
func test_guild_hall_scene_resolves_tilt_shift_shader() -> void:
	var packed: PackedScene = load("res://assets/screens/guild_hall/guild_hall.tscn") as PackedScene
	assert_object(packed).override_failure_message(
		"Guild Hall scene failed to load — may indicate broken ext_resource path "
		+ "to res://assets/shaders/tilt_shift_dof.gdshader"
	).is_not_null()

	var instance: Node = packed.instantiate()
	auto_free(instance)
	var overlay: ColorRect = instance.get_node_or_null("TiltShiftDof") as ColorRect
	assert_object(overlay).override_failure_message(
		"TiltShiftDof node missing from Guild Hall scene"
	).is_not_null()
	var mat: ShaderMaterial = overlay.material as ShaderMaterial
	assert_object(mat).override_failure_message(
		"TiltShiftDof ColorRect missing its ShaderMaterial"
	).is_not_null()
	assert_object(mat.shader).is_not_null()


# ---------------------------------------------------------------------------
# Test 4 — Guild Hall layer order: TiltShiftDof below WarmLanternOverlay
# ---------------------------------------------------------------------------

# The composition contract: tilt-shift runs first (samples raw content
# from BackBufferCopy), warm-lantern runs on top (composites amber wash
# over the already-blurred result). Reversing the order would tint the
# blur sample input rather than the final visual — wrong feel.
#
# Verified by z_index: TiltShiftDof must have lower z_index than
# WarmLanternOverlay so Godot's canvas-item sort renders it first.
func test_guild_hall_tilt_shift_renders_below_warm_lantern() -> void:
	var packed: PackedScene = load("res://assets/screens/guild_hall/guild_hall.tscn") as PackedScene
	var instance: Node = packed.instantiate()
	auto_free(instance)
	var tilt_shift: ColorRect = instance.get_node_or_null("TiltShiftDof") as ColorRect
	var warm_lantern: ColorRect = instance.get_node_or_null("WarmLanternOverlay") as ColorRect

	assert_object(tilt_shift).is_not_null()
	assert_object(warm_lantern).is_not_null()
	assert_int(tilt_shift.z_index).override_failure_message(
		"TiltShiftDof.z_index (%d) must be < WarmLanternOverlay.z_index (%d). "
		+ "Tilt-shift must sample raw content before the warm wash composites on top."
		% [tilt_shift.z_index, warm_lantern.z_index]
	).is_less(warm_lantern.z_index)


# ---------------------------------------------------------------------------
# Test 5 — DungeonRunView scene loads with the tilt-shift material attached
# ---------------------------------------------------------------------------

func test_dungeon_run_view_scene_resolves_tilt_shift_shader() -> void:
	var packed: PackedScene = load("res://assets/screens/dungeon_run_view/dungeon_run_view.tscn") as PackedScene
	assert_object(packed).override_failure_message(
		"DungeonRunView scene failed to load — may indicate broken ext_resource path "
		+ "to res://assets/shaders/tilt_shift_dof.gdshader"
	).is_not_null()

	var instance: Node = packed.instantiate()
	auto_free(instance)
	var overlay: ColorRect = instance.get_node_or_null("TiltShiftDof") as ColorRect
	assert_object(overlay).override_failure_message(
		"TiltShiftDof node missing from DungeonRunView scene"
	).is_not_null()
	var mat: ShaderMaterial = overlay.material as ShaderMaterial
	assert_object(mat).is_not_null()
	assert_object(mat.shader).is_not_null()
