## BiomeBackground — palette-keyed full-rect ColorRect at z_index=-1.
##
## The z=-1 background layer for the HD-2D pipeline per GDD #26 §C.1 +
## ADR-0019 §Decision 1 (layer-order contract). The tilt-shift BackBufferCopy
## captures BiomeBackground's pixels at this z_index and the tilt-shift
## shader blurs them; UI content (z=0) renders sharp above the blurred
## output; WarmLanternOverlay (z=1) composites the amber wash on top.
##
## Sprint 19 M3 ships 7 palette presets keyed to the biome database's
## [code]primary_palette_key[/code] field (per GDD #22 §C.1 Biome resource
## schema):
## [codeblock]
##   forest_reach        → moss_sage_guild_amber
##   whispering_crags    → grey_teal_mist
##   sunken_ruins        → ochre_dusk_purple
##   hollow_stair        → grey_bone_charcoal
##   ember_wastes        → ember_rust_charcoal
##   frostmire           → ice_blue_slate
##   guild_hall_tavern   → tavern_warm_amber  (non-biome, Guild Hall use)
## [/codeblock]
##
## Per ADR-0019 §Decision 3, Sprint 19 ships programmatic ColorRect
## placeholders. Real product art swaps in zero-code by replacing the
## ColorRect with a Sprite2D + Texture, preserving the script's surface
## (set_biome / get_biome / biome_changed signal).
##
## Per GDD #26 §C.2: full-rect anchors, mouse_filter=IGNORE, z_index=-1.
## Per GDD #26 §E: fallback to forest_reach on unknown / empty biome_id
## with push_warning. No crash on missing data.
class_name BiomeBackground extends ColorRect


## Emitted when the biome changes. Carries the previous and new biome_id
## strings so listeners can react to the transition (e.g. crossfade
## animation in a future polish pass).
signal biome_changed(old_biome_id: String, new_biome_id: String)


## Per-biome palette colors. Tuned for the cozy register (muted, low
## saturation) so the tilt-shift + warm-lantern composition on top reads
## as intimate diorama, not as a bright cartoon. RGB values are placeholder
## defaults pending Art Bible §4 color-system canonical RGB authoring;
## these are tuned by eye in Sprint 19 M5 playtest.
const PALETTE: Dictionary[String, Color] = {
	# Forest Reach — moss green + sage + warm amber undertone.
	"forest_reach": Color(0.36, 0.42, 0.28),
	# Whispering Crags — cool grey with teal-mist tint.
	"whispering_crags": Color(0.38, 0.46, 0.50),
	# Sunken Ruins — ochre with dusk purple undertone; "lost place" feel.
	"sunken_ruins": Color(0.42, 0.32, 0.42),
	# Hollow Stair — bone white tipping toward grey-charcoal; deepest biome.
	"hollow_stair": Color(0.28, 0.28, 0.32),
	# Ember Wastes — rust red + charcoal; volcanic register.
	"ember_wastes": Color(0.48, 0.26, 0.20),
	# Frostmire — ice blue + slate; cold-fog register.
	"frostmire": Color(0.42, 0.52, 0.62),
	# Guild Hall tavern — warm amber wood; cozy register baseline.
	"guild_hall_tavern": Color(0.32, 0.24, 0.18),
}

## Fallback biome key used when set_biome() receives an unknown or empty
## biome_id. Forest Reach is the onboarding biome and the safest "default
## biome" register per the cozy onboarding fantasy.
const FALLBACK_BIOME_ID: String = "forest_reach"

## Directory holding per-biome background art (ADR-0019 §Decision 3 real-art
## swap-in). A PNG named "<biome_id>.png" here is composited above the palette
## ColorRect when present; biomes with no shipped art (e.g. guild_hall_tavern)
## fall back to the flat palette color. This is the zero-`.tscn`-change swap
## path the §Decision 3 note anticipated.
const ART_DIR: String = "res://assets/art/backgrounds/"

## Floor index that triggers boss-floor visual modulation. MVP biomes all
## have exactly 5 floors (per Biome DB); this constant captures the
## "biome's terminal floor" assumption explicitly. When a V1.0 biome ships
## with a different floor count, replace this with a per-biome lookup via
## FloorUnlock.BIOME_FLOOR_COUNT.
const BOSS_FLOOR_INDEX_MVP: int = 5

## Multiplier applied to the biome palette on the boss floor. 0.65 picks
## the "dusk → night" transition that the parchment-warm palette tolerates
## without losing the cozy-game register. Tested by eye on warrior + mage
## + rogue compositions in forest_reach F5.
const BOSS_FLOOR_DARKEN_FACTOR: float = 0.65


## Current biome_id this background represents. Empty string at boot;
## populated via [method set_biome].
var _current_biome_id: String = ""

## Floor context for the current render — 0 means "no floor context"
## (Guild Hall tavern, Return-to-App). Tracked alongside _current_biome_id
## so the same-state short-circuit covers both axes: a re-render at the
## same biome+floor is a no-op, while a floor transition within the same
## biome (e.g., F4 → F5 boss) is correctly detected and re-rendered.
var _current_floor_index: int = 0

## Real-art layer (ADR-0019 §Decision 3 swap-in). A full-rect child
## [TextureRect] that displays the biome's background PNG above the palette
## ColorRect when one exists at [constant ART_DIR]. Created lazily on the first
## [method set_biome]. Hidden (palette shows through) for biomes with no
## shipped art. mouse_filter=IGNORE so it never intercepts taps on the UI above.
var _art_layer: TextureRect = null


## Updates the visible palette to match [param biome_id], with optional
## per-floor modulation. When [param floor_index] equals
## [constant BOSS_FLOOR_INDEX_MVP], the resolved palette is darkened by
## [constant BOSS_FLOOR_DARKEN_FACTOR] so the boss fight visually reads
## as distinct from regular floors.
##
## [param floor_index] of 0 means "no floor context" (e.g., Guild Hall
## tavern, Return-to-App screen) — no modulation applied. This is the
## documented default for callers that don't track floor state.
##
## Failure handling: an unknown or empty biome_id falls back to
## FALLBACK_BIOME_ID + emits a [code]push_warning[/code]. Combat dispatch
## should never silently render the wrong biome, but it also must not
## crash on a typo or a future biome that hasn't shipped its palette yet.
##
## Per GDD #26 §E (Edge Cases) + AC-26-11 + AC-26-12.
func set_biome(biome_id: String, floor_index: int = 0) -> void:
	var resolved_id: String = biome_id
	if biome_id.is_empty() or not PALETTE.has(biome_id):
		if not biome_id.is_empty():
			push_warning(
				"BiomeBackground.set_biome: unknown biome_id '%s'; falling back to '%s'"
				% [biome_id, FALLBACK_BIOME_ID]
			)
		resolved_id = FALLBACK_BIOME_ID

	# Short-circuit on same biome AND same floor — covers both the re-render
	# path AND the floor-transition path within the same biome.
	if resolved_id == _current_biome_id and floor_index == _current_floor_index:
		return

	var base_color: Color = PALETTE[resolved_id]
	var modulated_color: Color = base_color
	if floor_index == BOSS_FLOOR_INDEX_MVP:
		modulated_color = base_color * BOSS_FLOOR_DARKEN_FACTOR
		modulated_color.a = base_color.a

	var old_id: String = _current_biome_id
	_current_biome_id = resolved_id
	_current_floor_index = floor_index
	# The palette ColorRect is still set on every change — it is both the
	# documented contract surface (biome_background_test.gd Group B asserts
	# `color`) and the fallback shown when a biome has no shipped art.
	color = modulated_color
	_update_art_layer(resolved_id, floor_index)
	if old_id != resolved_id:
		biome_changed.emit(old_id, resolved_id)


## Returns the current biome_id, or empty string if [method set_biome]
## has not been called yet.
func get_biome() -> String:
	return _current_biome_id


## Lazily creates the full-rect real-art [TextureRect] child (see
## [member _art_layer]) and returns it. Idempotent — returns the existing
## layer on subsequent calls. The layer fills the BiomeBackground rect, never
## intercepts input, and starts hidden until a biome with art is set.
func _ensure_art_layer() -> TextureRect:
	if _art_layer != null and is_instance_valid(_art_layer):
		return _art_layer
	var layer: TextureRect = TextureRect.new()
	layer.name = "BiomeArt"
	# COVER so a 16:9 background fills the rect at any aspect (crops overflow)
	# rather than letter-boxing — the cozy diorama should bleed to the edges.
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.visible = false
	# Added as a child of the z=-1 ColorRect, so it composites at the same
	# layer the tilt-shift BackBufferCopy captures (ADR-0019 §Decision 1) —
	# the real art receives the HD-2D blur exactly like the placeholder did.
	add_child(layer)
	_art_layer = layer
	return layer


## Shows the biome's background PNG above the palette ColorRect when one exists
## at [constant ART_DIR], darkened on the boss floor to match the palette
## modulation; hides the layer (palette shows through) when the biome ships no
## art. Uses [method ResourceLoader.exists] so an un-imported / missing texture
## degrades to the palette fallback instead of erroring.
func _update_art_layer(resolved_id: String, floor_index: int) -> void:
	var layer: TextureRect = _ensure_art_layer()
	var art_path: String = ART_DIR + resolved_id + ".png"
	if not ResourceLoader.exists(art_path):
		layer.visible = false
		layer.texture = null
		return
	var tex: Texture2D = load(art_path) as Texture2D
	if tex == null:
		layer.visible = false
		layer.texture = null
		return
	layer.texture = tex
	layer.visible = true
	# Mirror the boss-floor darken the palette applies, so a real-art boss
	# floor reads as the same "dusk → night" transition (AC for parity).
	var darken: float = BOSS_FLOOR_DARKEN_FACTOR if floor_index == BOSS_FLOOR_INDEX_MVP else 1.0
	layer.modulate = Color(darken, darken, darken, 1.0)
