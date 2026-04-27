class_name Biome
extends GameData

## Biome — read-only resource schema for a top-level dungeon biome in Lantern Guild.
##
## Stored as [code].tres[/code] files in [code]assets/data/biomes/[/code] and
## resolved at runtime via the [BiomeDungeonDatabase] autoload (Story 002).
## Story 003 authors the Forest Reach MVP biome [code].tres[/code].
##
## [b]Schema contract (ADR-0011 §Decision)[/b]: read-only at runtime — no
## mutation methods. A Biome owns its Dungeons, which own their Floors, forming
## a fully self-contained nested resource hierarchy.
##
## [member dungeons] is a typed [code]Array[Dungeon][/code]; Godot 4.6 supports
## typed arrays of Resource subclasses registered via [code]class_name[/code].
## File load order for class registration: floor.gd → dungeon.gd → biome.gd
## (each depends only on its direct child type). If inspector authoring of
## [code]Array[Dungeon][/code] elements fails in a future engine patch, fall
## back to [code]Array[Resource][/code] and cast at the call site.
##
## [b]Inherited fields[/b] (do NOT redeclare):
##   [member GameData.id] — stable snake_case identifier (e.g. [code]"biome_forest_reach"[/code])
##   [member GameData.display_name] — localizable display name shown in UI
##
## [b]Usage:[/b]
##   [codeblock]
##   var biome: Biome = BiomeDungeonDatabase.get_biome("biome_forest_reach")
##   var first_floor: Floor = biome.dungeons[0].floors[0]
##   [/codeblock]
##
## ADR-0011: Resource Schemas Core Databases.
## ADR-0006: DataRegistry boot-scan pattern.
## GDD §C: Biome schema field definitions.

# ---------------------------------------------------------------------------
# Section: Visual identity (GDD §C)
# ---------------------------------------------------------------------------

## Key that maps to the palette used for this biome's visual theme.
##
## Consumed by the shader/renderer system to apply the correct color palette.
## Story TBD (shader-specialist) implements the palette lookup.
## Default [code]""[/code] means unassigned (no palette override applied).
## GDD §C — primary_palette_key.
@export var primary_palette_key: String = ""

# ---------------------------------------------------------------------------
# Section: Gameplay identity (GDD §C)
# ---------------------------------------------------------------------------

## Informational list of dominant enemy archetype tags in this biome.
##
## Used by the matchup-resolver (pre-fight scout) to surface relevant class
## counter-picks to the player. Values should be members of
## [code]EnemyArchetypes.ALL_SET[/code] but this is not enforced at the schema
## level — Story 004 validates archetype membership. Default is empty (no hints).
## GDD §C — dominant_archetypes.
@export var dominant_archetypes: Array[String] = []

# ---------------------------------------------------------------------------
# Section: Dungeons (GDD §C)
# ---------------------------------------------------------------------------

## Ordered list of Dungeons in this Biome.
##
## Each element is a [Dungeon] resource, which in turn owns an ordered list
## of [Floor] resources. The dungeon runner resolves the active dungeon by
## index into this array. Story 004 validates non-empty constraint.
##
## Typed as [code]Array[Dungeon][/code] so the Inspector shows an "Add Dungeon"
## element button for designer authoring. If Godot's nested-resource array
## authoring regresses in a future engine patch, fall back to
## [code]Array[Resource][/code] and cast elements at call sites.
## GDD §C — dungeons.
@export var dungeons: Array[Dungeon] = []

# ---------------------------------------------------------------------------
# Section: Narrative (GDD §C)
# ---------------------------------------------------------------------------

## List of environmental storytelling cues for this biome.
##
## Shown in the biome-explore screen or level-select UI to give atmospheric
## context. Each string is a short cue (e.g. [code]"Roots split ancient stone."[/code]).
## May be localized at runtime via TranslationServer.
## Default is empty list (no cues authored yet).
## GDD §C — environmental_storytelling.
@export var environmental_storytelling: Array[String] = []

## Short lore / flavor text shown on the biome-select screen.
##
## Max recommended length: 200 characters (fits the panel without scroll).
## May be localized at runtime via TranslationServer.
## GDD §C — flavor_text.
@export_multiline var flavor_text: String = ""

# ---------------------------------------------------------------------------
# Section: Content lifecycle (GDD §C)
# ---------------------------------------------------------------------------

## Content lifecycle status of this biome (e.g. [code]"active"[/code], [code]"wip"[/code]).
##
## The [BiomeDungeonDatabase] autoload filters out non-active biomes at runtime
## (Story 002). Default [code]"active"[/code] — a newly authored biome is live
## unless explicitly marked otherwise.
## GDD §C — status.
@export var status: String = "active"
