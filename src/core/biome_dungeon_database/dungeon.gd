class_name Dungeon
extends GameData

## Dungeon — read-only resource schema for a dungeon within a Biome.
##
## Stored as [code].tres[/code] files nested inside [Biome] resources.
## The [BiomeDungeonDatabase] autoload (Story 002) resolves the full
## Biome → Dungeon → Floor hierarchy at runtime.
##
## [b]Schema contract (ADR-0011 §Decision)[/b]: read-only at runtime — no
## mutation methods. [member floors] is a typed [code]Array[Floor][/code];
## Godot 4.6 supports typed arrays of Resource subclasses defined in other
## scripts as long as the class is registered before this resource is loaded.
## File load order: floor.gd must be parsed before dungeon.gd (handled by
## Godot's class-registry scan, which alphabetically-ish resolves dependencies
## through [code]class_name[/code] registration). If inspector authoring of
## [code]Array[Floor][/code] elements fails in a future engine version, fall
## back to [code]Array[Resource][/code] and cast at the call site.
##
## [b]Inherited fields[/b] (do NOT redeclare):
##   [member GameData.id] — stable snake_case identifier
##   [member GameData.display_name] — localizable display name shown in UI
##
## [b]Usage:[/b]
##   [codeblock]
##   var dungeon: Dungeon = biome.dungeons[0]
##   var first_floor: Floor = dungeon.floors[0]
##   [/codeblock]
##
## ADR-0011: Resource Schemas Core Databases.
## ADR-0006: DataRegistry boot-scan pattern.
## GDD §C: Dungeon schema field definitions.

# ---------------------------------------------------------------------------
# Section: Back-reference (GDD §C)
# ---------------------------------------------------------------------------

## The [code]id[/code] of the parent [Biome] that owns this Dungeon.
##
## Used as a back-reference for tooling and cross-system queries. Must match
## a [Biome].id in the Biome database; cross-resolution validated in Story 004.
## Default [code]""[/code] means unassigned (authoring placeholder only).
## GDD §C — biome_id.
@export var biome_id: String = ""

# ---------------------------------------------------------------------------
# Section: Floors (GDD §C)
# ---------------------------------------------------------------------------

## Ordered list of floors in this Dungeon.
##
## Each element is a [Floor] resource. Elements should be ordered by
## [member Floor.floor_index] in ascending order; the dungeon runner
## iterates them in array order. Story 004 validates floor_index uniqueness
## and non-empty constraint.
##
## Typed as [code]Array[Floor][/code] so the Inspector shows an "Add Floor"
## element button for designer authoring. If Godot's nested-resource array
## authoring regresses in a future engine patch, fall back to
## [code]Array[Resource][/code] and cast elements at call sites.
## GDD §C — floors.
@export var floors: Array[Floor] = []
