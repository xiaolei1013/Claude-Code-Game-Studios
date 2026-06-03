## EnemySpriteFactory — loads an enemy's demo sprite from disk.
##
## The sprite lives at [code]assets/art/enemies/<enemy_id>/sprite.png[/code] —
## the path [member EnemyData.sprite_path] references, assembled by
## tools/demo-asset-setup.py from the Octopath enemy archive (see
## design/art/demo-asset-manifest.md). Unlike the hero idle sheets, enemy source
## art is a single still image, so this factory returns one [Texture2D] — no
## frame slicing or animation.
##
## DEMO-BUILD ONLY: when the sprite is absent (production art not delivered, or
## any non-demo build — demo assets are gitignored), [method get_sprite] returns
## null and callers keep whatever placeholder they already show. This mirrors the
## disk-first / null-fallback contract of [ClassPortraitFactory] / [ClassSpriteFactory].
##
## Pure-utility, static-callable, cached by enemy_id.
class_name EnemySpriteFactory
extends RefCounted

## Module-level cache: enemy_id → Texture2D (or null when no sheet on disk).
## A null cache entry is intentional — it records "checked, absent" so repeat
## codex opens don't re-hit the filesystem.
static var _cache: Dictionary = {}


## Returns the demo sprite [Texture2D] for [param enemy_id], or null when the
## class is empty or no sprite exists on disk. Cached after the first lookup.
static func get_sprite(enemy_id: String) -> Texture2D:
	if _cache.has(enemy_id):
		return _cache[enemy_id]
	var tex: Texture2D = null
	if not enemy_id.is_empty():
		var path: String = "res://assets/art/enemies/%s/sprite.png" % enemy_id
		if FileAccess.file_exists(path):
			tex = load(path) as Texture2D
	_cache[enemy_id] = tex
	return tex


## True when a demo sprite exists on disk for [param enemy_id]. Lets callers
## decide between a sprite thumbnail and a placeholder without forcing a load.
static func has_sprite(enemy_id: String) -> bool:
	return get_sprite(enemy_id) != null


## Clears the cache. Tests + editor reload only; not reachable from gameplay.
static func _clear_cache_for_tests() -> void:
	_cache.clear()
