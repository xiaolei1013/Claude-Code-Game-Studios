# Tests for S28-N1: VfxKit one-shot particle-burst helper (GDD #27 VFX System).
#
# VfxKit is a pure static helper — no autoload, no scene tree required for the
# config asserts (CPUParticles2D is added to an orphan parent; we assert its
# configuration, not its rendered output, which is feel-verified by playtest).
extends GdUnitTestSuite

const VfxKitScript = preload("res://src/ui/vfx_kit.gd")


func _texture() -> Texture2D:
	return PlaceholderTexture2D.new()


func test_spawn_burst_returns_configured_one_shot_particles() -> void:
	var parent: Node2D = Node2D.new()
	var tex: Texture2D = _texture()

	var burst: CPUParticles2D = VfxKitScript.spawn_burst(
		parent, Vector2(10.0, 20.0), tex, VfxKitScript.LANTERN_GOLD, 12, 0.5, false)

	assert_object(burst).is_not_null()
	assert_bool(burst.get_parent() == parent).is_true()
	assert_bool(burst.one_shot).is_true()
	assert_bool(burst.emitting).is_true()
	assert_int(burst.amount).is_equal(12)
	assert_float(burst.lifetime).is_equal(0.5)
	assert_object(burst.texture).is_same(tex)
	assert_bool(burst.color == VfxKitScript.LANTERN_GOLD).is_true()
	assert_bool(burst.position == Vector2(10.0, 20.0)).is_true()

	parent.free()


func test_spawn_burst_reduce_motion_emits_nothing() -> void:
	# GDD #27 OQ-27-3: reduce_motion = true → snap-replace (no particles).
	var parent: Node2D = Node2D.new()

	var burst: CPUParticles2D = VfxKitScript.spawn_burst(
		parent, Vector2.ZERO, _texture(), VfxKitScript.LANTERN_GOLD, 10, 0.6, true)

	assert_object(burst).is_null()
	assert_int(parent.get_child_count()).is_equal(0)

	parent.free()


func test_spawn_burst_null_parent_returns_null() -> void:
	var burst: CPUParticles2D = VfxKitScript.spawn_burst(
		null, Vector2.ZERO, _texture(), VfxKitScript.LANTERN_GOLD)
	assert_object(burst).is_null()


func test_spawn_burst_null_texture_returns_null_no_child() -> void:
	var parent: Node2D = Node2D.new()
	var burst: CPUParticles2D = VfxKitScript.spawn_burst(
		parent, Vector2.ZERO, null, VfxKitScript.LANTERN_GOLD)
	assert_object(burst).is_null()
	assert_int(parent.get_child_count()).is_equal(0)
	parent.free()


func test_spawn_burst_nonpositive_amount_returns_null() -> void:
	var parent: Node2D = Node2D.new()
	var burst: CPUParticles2D = VfxKitScript.spawn_burst(
		parent, Vector2.ZERO, _texture(), VfxKitScript.LANTERN_GOLD, 0, 0.6)
	assert_object(burst).is_null()
	parent.free()


func test_spawn_burst_nonpositive_lifetime_returns_null() -> void:
	var parent: Node2D = Node2D.new()
	var burst: CPUParticles2D = VfxKitScript.spawn_burst(
		parent, Vector2.ZERO, _texture(), VfxKitScript.LANTERN_GOLD, 10, 0.0)
	assert_object(burst).is_null()
	parent.free()


func test_palette_constants_match_design_tokens() -> void:
	# Guards against drift from DESIGN.md §Color (Art Bible §4 locked palette).
	assert_bool(VfxKitScript.LANTERN_GOLD == Color(0.949, 0.722, 0.231, 1.0)).is_true()
	assert_bool(VfxKitScript.GUILD_AMBER == Color(0.784, 0.529, 0.165, 1.0)).is_true()
	assert_bool(VfxKitScript.MOSS_SAGE == Color(0.478, 0.549, 0.369, 1.0)).is_true()
