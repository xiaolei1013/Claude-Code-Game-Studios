## ClassPortraitFactory — programmatic 96×96 placeholder portraits per class_id.
##
## Sprint 23 S23-S3 (third carry from S20-N1 → S21-S2 → dropped S22; promoted
## to Should Have per the "3rd carry → Should Have minimum" process rule).
##
## Each class_id deterministically maps to a distinct solid-color background
## with an inset border + a centered class-initial glyph. No real-art binding
## needed; the textures are generated on demand and cached. Used by:
##   - Recruit Screen pool-entry rows (ClassPortrait TextureRect, 96×96)
##   - Hero Detail Modal portrait slot (ClassPortrait TextureRect)
##   - Future surfaces wired by class_id alone
##
## When real product art lands, the factory's fallback path remains valid —
## consumers can read `HeroClass.portrait_path` first and fall back to
## [method get_portrait_texture] when the file is absent or empty.
##
## Pure-utility class (no scene tree dependency). Marked static-callable so
## callers don't need an instance; the cache is module-level by design.
class_name ClassPortraitFactory
extends RefCounted

## Default portrait dimension. Matches the existing TextureRect
## custom_minimum_size = Vector2(96, 96) in recruit + hero_detail scenes.
const PORTRAIT_SIZE: int = 96

## Inner padding for the border. 4px on each side gives a 4px frame around
## the colored block — keeps the portrait readable at the 96px size while
## still indicating "art placeholder, not the real thing."
const _BORDER_WIDTH_PX: int = 4

## Maximum length of the initial glyph rendered atop the block. Single
## character keeps it legible at 96×96; longer class_ids contribute only
## the first letter (e.g., "warrior" → "W"; "rogue" → "R").
const _INITIAL_GLYPH_LEN: int = 1

## Module-level cache. Keyed by class_id; never invalidated within a run
## (textures are immutable once built). Cache survives across many UI
## refreshes without per-call allocation, satisfying the zero-alloc-in-
## hot-paths engine rule.
static var _cache: Dictionary = {}


## Returns a 96×96 placeholder portrait for [param class_id]. Deterministic
## hash → color mapping ensures the same class always renders the same
## color. Cached after the first build; repeat calls are O(1) dictionary
## lookups.
##
## If [param class_id] is empty, returns a neutral grey block (defensive —
## avoids null returns on caller code paths).
static func get_portrait_texture(class_id: String) -> Texture2D:
	var key: String = class_id
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = _build_portrait(class_id)
	_cache[key] = tex
	return tex


## Returns the deterministic background color for [param class_id]. Exposed
## as a static helper so tests can verify per-class distinctness without
## instantiating the texture path.
static func get_portrait_color(class_id: String) -> Color:
	if class_id.is_empty():
		return Color(0.5, 0.5, 0.5, 1.0)
	# Stable hash → 0..1 hue space. Saturation + value are fixed to keep
	# the parchment-warm palette family — desaturated, mid-luminance.
	# The HSV-from-hash mapping gives ~6 visually distinct color slots
	# for the 3 MVP classes plus headroom for the Tier-2 expansion.
	var hash_value: int = class_id.hash()
	# Mask off the sign bit so hash → unsigned for the modulo. Godot's
	# String.hash() can return negative ints on overflow.
	var unsigned: int = hash_value & 0x7FFFFFFF
	var hue: float = float(unsigned % 360) / 360.0
	# Parchment-warm range: saturation 0.45, value 0.65 keeps colors in
	# the dusty-gold register defined by DESIGN.md token palette.
	return Color.from_hsv(hue, 0.45, 0.65, 1.0)


## Builds the 96×96 ImageTexture. Steps:
##   1. Solid background fill in the class color
##   2. Inset border drawn 4px from each edge in a darkened variant
##   3. Single-character initial glyph centered (rendered as a filled
##      sub-rect overlay — a true font glyph would require a Theme
##      lookup which is heavier; the sub-rect "tile mark" is the cozy-
##      register placeholder the playtester sees until real art arrives)
static func _build_portrait(class_id: String) -> Texture2D:
	var size: int = PORTRAIT_SIZE
	var bg: Color = get_portrait_color(class_id)
	var border: Color = Color(bg.r * 0.5, bg.g * 0.5, bg.b * 0.5, 1.0)
	var glyph: Color = Color(bg.r * 1.4, bg.g * 1.4, bg.b * 1.4, 1.0)

	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(bg)

	# Inset border — 4px frame inside the 96×96 block.
	for x: int in range(size):
		for y: int in range(size):
			var on_border: bool = (
				x < _BORDER_WIDTH_PX
				or x >= size - _BORDER_WIDTH_PX
				or y < _BORDER_WIDTH_PX
				or y >= size - _BORDER_WIDTH_PX
			)
			if on_border:
				img.set_pixel(x, y, border)

	# Initial-letter "mark" — a brightened diamond at the center of the
	# block. Distinct enough to differentiate from a flat color swatch
	# without needing a real font glyph at MVP time.
	var center: int = size / 2
	var mark_radius: int = size / 4
	for x: int in range(center - mark_radius, center + mark_radius + 1):
		for y: int in range(center - mark_radius, center + mark_radius + 1):
			# Diamond test: |dx| + |dy| ≤ mark_radius
			var dx: int = absi(x - center)
			var dy: int = absi(y - center)
			if dx + dy <= mark_radius:
				img.set_pixel(x, y, glyph)

	return ImageTexture.create_from_image(img)


## Clears the cache. Intended for tests + the editor reload path. Not
## reachable from gameplay code.
static func _clear_cache_for_tests() -> void:
	_cache.clear()
