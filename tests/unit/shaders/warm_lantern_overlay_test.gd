# Sprint 15 N2 preview — warm-lantern overlay shader contract test.
#
# Locks down the .gdshader's uniform surface so Vertical Slice tier
# tuning work (per ADR-0017 pivot triggers) inherits a stable interface.
#
# Per design/gdd/hd-2d-rendering-pipeline.md OQ-26-1 + OQ-26-2: shader
# ships with @export-style uniforms that the designer can tune via the
# ShaderMaterial inspector without touching .gdshader source. This test
# locks the 4 uniform names + their default ranges so a tuning iteration
# can't silently rename / remove them.
extends GdUnitTestSuite

const SHADER_PATH: String = "res://assets/shaders/warm_lantern_overlay.gdshader"


# ---------------------------------------------------------------------------
# Test 1 — shader loads as a Shader resource
# ---------------------------------------------------------------------------

func test_warm_lantern_shader_resource_loads() -> void:
	var shader: Shader = load(SHADER_PATH) as Shader
	assert_object(shader).override_failure_message(
		"Failed to load shader at %s" % SHADER_PATH
	).is_not_null()


# ---------------------------------------------------------------------------
# Test 2 — exposes the 4 contract uniforms
# ---------------------------------------------------------------------------

# Per the shader source: warm_color (vec4), vignette_radius (float),
# vignette_softness (float), intensity (float). The Vertical Slice tier
# tuning workflow depends on these names being stable.
#
# Strategy: read the shader source as text and grep for `uniform <type> <name>`
# declarations. Pure-string contract check — independent of Godot's
# Shader/ShaderMaterial introspection API which varies across 4.x versions.
func test_warm_lantern_shader_exposes_four_contract_uniforms() -> void:
	var file: FileAccess = FileAccess.open(SHADER_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var src: String = file.get_as_text()
	file.close()

	var expected_declarations: Array[String] = [
		"uniform vec4 warm_color",
		"uniform float vignette_radius",
		"uniform float vignette_softness",
		"uniform float intensity",
	]

	var missing: Array[String] = []
	for decl: String in expected_declarations:
		if not src.contains(decl):
			missing.append(decl)

	assert_int(missing.size()).override_failure_message(
		"Missing contract uniform declarations: %s. The Vertical Slice tier "
		+ "designer-tuning workflow depends on these names. Restore them in "
		+ "assets/shaders/warm_lantern_overlay.gdshader."
		% str(missing)
	).is_equal(0)


# ---------------------------------------------------------------------------
# Test 3 — Guild Hall scene loads with the shader material attached
# ---------------------------------------------------------------------------

# Catches the regression where the shader file is moved/renamed without
# updating the guild_hall.tscn ext_resource reference.
func test_guild_hall_scene_resolves_shader_resource() -> void:
	var packed: PackedScene = load("res://assets/screens/guild_hall/guild_hall.tscn") as PackedScene
	assert_object(packed).override_failure_message(
		"Guild Hall scene failed to load — may indicate broken ext_resource path "
		+ "to res://assets/shaders/warm_lantern_overlay.gdshader"
	).is_not_null()

	var instance: Node = packed.instantiate()
	auto_free(instance)
	var overlay: ColorRect = instance.get_node_or_null("WarmLanternOverlay") as ColorRect
	assert_object(overlay).override_failure_message(
		"WarmLanternOverlay node missing from Guild Hall scene"
	).is_not_null()
	var mat: ShaderMaterial = overlay.material as ShaderMaterial
	assert_object(mat).override_failure_message(
		"WarmLanternOverlay ColorRect missing its ShaderMaterial"
	).is_not_null()
	assert_object(mat.shader).is_not_null()
