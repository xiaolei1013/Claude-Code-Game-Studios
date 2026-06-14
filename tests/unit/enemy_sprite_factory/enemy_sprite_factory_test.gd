# EnemySpriteFactory tests — the enemy-sprite loader consumed by the Codex
# Monsters tab and the in-dungeon enemy display.
#
# Two contracts under test:
#   - Negative path (empty / missing ids return null; callers branch on
#     has_sprite() without forcing a load).
#   - Real-art path (Sprint 28 AI enemy sprites): a committed enemy id loads a
#     real Texture2D at native resolution. This is the regression net against a
#     reverted ResourceLoader.exists guard, a path typo, or the sprite files
#     slipping back out of version control.
extends GdUnitTestSuite

const EnemySpriteFactoryScript = preload("res://src/ui/enemy_sprite_factory.gd")

# An enemy id with committed real art (Sprint 28) at
# assets/art/enemies/<id>/sprite.png. The factory must load this, not return null.
const _REAL_ART_ENEMY_ID: String = "abyss_eel"


func before_test() -> void:
	EnemySpriteFactoryScript._clear_cache_for_tests()


func after_test() -> void:
	EnemySpriteFactoryScript._clear_cache_for_tests()


func test_get_sprite_empty_id_returns_null() -> void:
	assert_object(EnemySpriteFactoryScript.get_sprite("")).is_null()


func test_get_sprite_missing_enemy_returns_null() -> void:
	# No sprite on disk for a bogus id → null (production / non-demo path).
	assert_object(EnemySpriteFactoryScript.get_sprite("not_a_real_enemy_xyz")).is_null()


func test_has_sprite_false_for_missing_enemy() -> void:
	assert_bool(EnemySpriteFactoryScript.has_sprite("not_a_real_enemy_xyz")).is_false()


func test_has_sprite_false_for_empty_id() -> void:
	assert_bool(EnemySpriteFactoryScript.has_sprite("")).is_false()


func test_repeat_lookup_is_cached_and_stable() -> void:
	# Second lookup returns the same (null) cache entry — no re-hit, no divergence.
	var first: Texture2D = EnemySpriteFactoryScript.get_sprite("not_a_real_enemy_xyz")
	var second: Texture2D = EnemySpriteFactoryScript.get_sprite("not_a_real_enemy_xyz")
	assert_object(first).is_same(second)


# ===========================================================================
# Real-art binding (Sprint 28 — AI enemy sprites)
# ===========================================================================

func test_real_art_enemy_loads_native_resolution_sprite() -> void:
	# Arrange + Act — "abyss_eel" has committed real art at
	# assets/art/enemies/abyss_eel/sprite.png, authored by the asset pipeline at
	# the manifest-pinned 256×256 (images.enemy_sprites[].size in full.json).
	var tex: Texture2D = EnemySpriteFactoryScript.get_sprite(_REAL_ART_ENEMY_ID)

	# Assert — real art loads at its pinned size; the factory must NOT have fallen
	# back to null. A null/absent here means the sprite is missing/unimported or
	# the ResourceLoader.exists guard regressed (e.g. reverted to FileAccess, which
	# fails in exported builds); a wrong size means the import settings drifted.
	assert_object(tex).is_not_null()
	assert_int(tex.get_width()).is_equal(256)
	assert_int(tex.get_height()).is_equal(256)


func test_has_sprite_true_for_real_art_enemy() -> void:
	# has_sprite() delegates to get_sprite(); a committed enemy must report true.
	assert_bool(EnemySpriteFactoryScript.has_sprite(_REAL_ART_ENEMY_ID)).is_true()
