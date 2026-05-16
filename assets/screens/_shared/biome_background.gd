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


## Current biome_id this background represents. Empty string at boot;
## populated via [method set_biome].
var _current_biome_id: String = ""


## Updates the visible palette to match [param biome_id]. Emits
## [signal biome_changed] when the resolved biome_id differs from the
## current state.
##
## Failure handling: an unknown or empty biome_id falls back to
## FALLBACK_BIOME_ID + emits a [code]push_warning[/code]. Combat dispatch
## should never silently render the wrong biome, but it also must not
## crash on a typo or a future biome that hasn't shipped its palette yet.
##
## Per GDD #26 §E (Edge Cases) + AC-26-11 + AC-26-12.
func set_biome(biome_id: String) -> void:
	var resolved_id: String = biome_id
	if biome_id.is_empty() or not PALETTE.has(biome_id):
		if not biome_id.is_empty():
			push_warning(
				"BiomeBackground.set_biome: unknown biome_id '%s'; falling back to '%s'"
				% [biome_id, FALLBACK_BIOME_ID]
			)
		resolved_id = FALLBACK_BIOME_ID

	if resolved_id == _current_biome_id:
		return

	var old_id: String = _current_biome_id
	_current_biome_id = resolved_id
	color = PALETTE[resolved_id]
	biome_changed.emit(old_id, resolved_id)


## Returns the current biome_id, or empty string if [method set_biome]
## has not been called yet.
func get_biome() -> String:
	return _current_biome_id


## Multiplier applied to the biome palette on the FINAL (boss) floor — F5
## of a standard biome. Darkens the background so the boss fight visually
## reads as a culmination, distinct from the daylight register of F1–F4.
## Sprint 25 S25-M3-rev — per-floor visual differentiation; smallest
## meaningful variant: only the boss floor diverges. Per-floor gradient
## across F1–F4 deferred to a follow-up pass once playtest validates the
## boss-floor moment.
##
## 0.65 picks the "dusk → night" transition that the parchment-warm
## palette tolerates without losing the cozy-game register. Tested by
## eye on warrior + mage + rogue compositions in forest_reach F5.
const BOSS_FLOOR_DARKEN_FACTOR: float = 0.65


## Updates the visible palette to match [param biome_id], with optional
## per-floor modulation. Sprint 25 S25-M3-rev — when [param floor_index]
## indicates a boss floor (currently floor 5 in MVP), the resolved palette
## is darkened by [constant BOSS_FLOOR_DARKEN_FACTOR] so the player
## visually reads the boss fight as distinct from regular floors.
##
## [param floor_index] of 0 means "no floor context" (e.g., Guild Hall
## tavern, Return-to-App screen) — no modulation applied, identical to
## [method set_biome].
##
## Compatibility: [method set_biome] is preserved as the no-floor-context
## entry point. Callers that have a floor context (DungeonRunView,
## Victory Moment) can opt into per-floor modulation via this method
## without breaking screens that don't track floors.
func set_biome_for_floor(biome_id: String, floor_index: int) -> void:
	# Resolve biome_id with the same fallback policy as set_biome (DRY-violation
	# avoidance — inlined here to keep the per-floor modulation in one place;
	# extracting a shared helper would complicate signal-emit semantics).
	var resolved_id: String = biome_id
	if biome_id.is_empty() or not PALETTE.has(biome_id):
		if not biome_id.is_empty():
			push_warning(
				"BiomeBackground.set_biome_for_floor: unknown biome_id '%s'; falling back to '%s'"
				% [biome_id, FALLBACK_BIOME_ID]
			)
		resolved_id = FALLBACK_BIOME_ID

	# Per-floor modulation: only the boss floor (5) currently diverges.
	# Pre-MVP playtest can lift this to a per-floor gradient if the boss-only
	# variant reads as too binary.
	var base_color: Color = PALETTE[resolved_id]
	var floor_modulated_color: Color = base_color
	if floor_index == 5:
		floor_modulated_color = Color(
			base_color.r * BOSS_FLOOR_DARKEN_FACTOR,
			base_color.g * BOSS_FLOOR_DARKEN_FACTOR,
			base_color.b * BOSS_FLOOR_DARKEN_FACTOR,
			base_color.a
		)

	# Always update color even on same biome_id — the floor may have changed
	# without the biome changing (e.g., F4 → F5 in the same run). Set
	# _current_biome_id BEFORE the signal emit so subscribers see consistent state.
	var old_id: String = _current_biome_id
	_current_biome_id = resolved_id
	color = floor_modulated_color
	if old_id != resolved_id:
		biome_changed.emit(old_id, resolved_id)
