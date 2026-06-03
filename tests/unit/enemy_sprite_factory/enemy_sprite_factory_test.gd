# EnemySpriteFactory tests — the demo enemy-sprite loader consumed by the
# Codex Monsters tab.
#
# Enemy demo sprites are gitignored (absent in CI), so these tests verify the
# CI-stable contract: empty / missing ids return null and callers can branch on
# has_sprite() without forcing a load. The disk-hit path (returns a real
# Texture2D) is covered manually + by the codex screenshot, not in CI.
extends GdUnitTestSuite

const EnemySpriteFactoryScript = preload("res://src/ui/enemy_sprite_factory.gd")


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
