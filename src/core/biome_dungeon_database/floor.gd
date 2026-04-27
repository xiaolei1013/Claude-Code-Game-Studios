class_name Floor
extends GameData

## Floor — read-only resource schema for a single dungeon floor in Lantern Guild.
##
## Stored as [code].tres[/code] files nested inside [Dungeon] resources, which
## are in turn nested inside [Biome] resources. The [BiomeDungeonDatabase]
## autoload (Story 002) resolves Biome/Dungeon/Floor at runtime.
##
## [b]Schema contract (ADR-0011 §Decision)[/b]: read-only at runtime — no
## mutation methods. [code]enemy_list[/code] is a deterministic
## [code]Array[Dictionary][/code] where each entry has exactly two keys:
## [code]{ "enemy_id": String, "count": int }[/code]. No RNG, no probabilistic
## spawn weights. Validation of enemy_id cross-references lands in Story 004.
##
## [b]Inherited fields[/b] (do NOT redeclare):
##   [member GameData.id] — stable snake_case identifier
##   [member GameData.display_name] — localizable display name shown in UI
##
## [b]Usage:[/b]
##   [codeblock]
##   var floor: Floor = biome.dungeons[0].floors[0]
##   [/codeblock]
##
## ADR-0011: Resource Schemas Core Databases.
## ADR-0006: DataRegistry boot-scan pattern.
## GDD §C: Floor schema field definitions.

# ---------------------------------------------------------------------------
# Section: Floor index (GDD §C)
# ---------------------------------------------------------------------------

## Ordinal position of this floor within its parent Dungeon (0-based).
##
## Used by the dungeon runner to sequence floors in ascending order.
## Uniqueness per Dungeon is enforced by Story 004 validator; the schema
## itself permits duplicate indices (authoring error, not a runtime crash).
## Safe range: 0 – 9999.
## GDD §C — floor_index.
@export var floor_index: int = 0

# ---------------------------------------------------------------------------
# Section: Enemy list (GDD §C, ADR-0011)
# ---------------------------------------------------------------------------

## Deterministic list of enemy spawns on this floor.
##
## Each entry is a [Dictionary] with exactly two keys:
##   [code]"enemy_id"[/code] ([String]) — must match an [EnemyData].id in the
##       enemy database; cross-resolution validated in Story 004.
##   [code]"count"[/code] ([int]) — number of that enemy to spawn (>= 1).
##
## No RNG fields, no probability weights — spawn list is fully deterministic
## per ADR-0011 §Decision. An empty list is valid at the schema level; Story 004
## rejects empty enemy_list on non-boss floors as a content error.
## GDD §C — enemy_list.
@export var enemy_list: Array[Dictionary] = []

# ---------------------------------------------------------------------------
# Section: Timing (GDD §C)
# ---------------------------------------------------------------------------

## Expected time in seconds for a fully-equipped formation to clear this floor.
##
## Used by the dungeon runner to calculate offline progression rewards.
## Must be > 0 for any playable floor; Story 004 validates this constraint.
## Safe range: 0 – 86400 (0 is a valid authoring placeholder only).
## GDD §C — expected_clear_time_seconds.
@export var expected_clear_time_seconds: int = 0

# ---------------------------------------------------------------------------
# Section: Boss floor flag (GDD §C)
# ---------------------------------------------------------------------------

## Whether this floor is a boss encounter.
##
## Boss floors trigger special UI, music, and reward sequences.
## Exactly one floor per Dungeon should have [code]is_boss_floor = true[/code]
## (authoring guideline; not enforced at schema level — Story 004 validates).
## Defaults [code]false[/code] — most floors are standard encounters.
## GDD §C — is_boss_floor.
@export var is_boss_floor: bool = false

# ---------------------------------------------------------------------------
# Section: Flavor text (GDD §C)
# ---------------------------------------------------------------------------

## Short lore / flavor text shown on the floor transition screen.
##
## Max recommended length: 200 characters (fits the panel without scroll).
## May be localized at runtime via TranslationServer.
## Leave empty if no floor-specific flavor is authored.
## GDD §C — flavor_text.
@export_multiline var flavor_text: String = ""
