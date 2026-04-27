class_name EnemyData
extends GameData

## EnemyData — read-only resource schema for enemies in Lantern Guild.
##
## Stored as [code].tres[/code] files in [code]assets/data/enemies/[/code] and
## resolved at runtime via the EnemyDatabase autoload (Story 002).
## Story 003 authors the 7+ MVP enemy .tres files.
##
## Schema is static/read-only at runtime: no leveling, no per-enemy loot
## overrides, no resistance fields in MVP (ADR-0011 §Decision, TR-enemy-db-004).
##
## All archetype values MUST route through [EnemyArchetypes] constants — never
## use raw archetype string literals in this file (ADR-0011 §Forbidden).
##
## [b]Inherited fields[/b] (do NOT redeclare):
##   [member GameData.id] — stable snake_case identifier (e.g. [code]"enemy_goblin_bruiser"[/code])
##   [member GameData.display_name] — localizable display name shown in UI
##
## [b]Usage:[/b]
##   [codeblock]
##   var ed: EnemyData = EnemyDatabase.get_enemy("enemy_goblin_bruiser")
##   [/codeblock]
##
## ADR-0011: Resource Schemas Core Databases.
## ADR-0006: DataRegistry boot-scan pattern.
## GDD §C: Enemy schema field definitions.

# ---------------------------------------------------------------------------
# Section: Progression tier (GDD §C)
# ---------------------------------------------------------------------------

## Progression tier of this enemy (1 = common, 2 = elite, 3 = boss-tier).
##
## Controls encounter difficulty scaling and reward multipliers.
## MVP ships Tier 1 (standard dungeon enemies) and Tier 2 (elites).
## Safe range: 1 – 3.
## GDD §C — tier field.
@export_range(1, 3) var tier: int = 1

# ---------------------------------------------------------------------------
# Section: Archetype (GDD §C, ADR-0011 §H-02)
# ---------------------------------------------------------------------------

## Enemy archetype tag for this enemy (e.g. [code]EnemyArchetypes.BRUISER[/code]).
##
## MUST be an empty string or a value from [EnemyArchetypes.ALL_SET].
## Validated at load time by Story 004 (_validate method).
## Default [code]""[/code] means unassigned (authoring placeholder only).
## Use [EnemyArchetypes] constants — never hardcode archetype strings.
## GDD §C — archetype field. ADR-0011 §H-02.
@export var archetype: String = ""

# ---------------------------------------------------------------------------
# Section: Biome (GDD §C)
# ---------------------------------------------------------------------------

## The dungeon biome this enemy is associated with.
##
## Controls which dungeons can spawn this enemy and which biome matchup
## bonuses apply. Must match a Biome [code]id[/code] from the Biome database
## (Story TBD). Default [code]""[/code] means unassigned.
## GDD §C — biome field.
@export var biome: String = ""

# ---------------------------------------------------------------------------
# Section: Base stats (GDD §C)
# ---------------------------------------------------------------------------

## Base hit points of this enemy.
##
## Enemies do not level; this is their fixed HP for all dungeon encounters.
## Safe range: 0 – 99999.
## GDD §C — base_hp.
@export_range(0, 99999) var base_hp: int = 0

## Base attack damage of this enemy.
##
## Enemies do not level; this is their fixed attack for all encounters.
## Safe range: 0 – 9999.
## GDD §C — base_attack.
@export_range(0, 9999) var base_attack: int = 0

## Base speed of this enemy.
##
## Determines action order within a dungeon tick. Higher speed acts earlier.
## Enemies do not level; this is their fixed speed.
## Safe range: 0 – 999.
## GDD §C — base_speed.
@export_range(0, 999) var base_speed: int = 0

# ---------------------------------------------------------------------------
# Section: Asset paths (GDD §C)
# ---------------------------------------------------------------------------

## Res-path to the in-dungeon sprite texture for this enemy.
##
## Example: [code]"res://assets/art/enemies/goblin_bruiser_sprite.png"[/code].
## Loaded at runtime by the EnemyRenderer node (Story TBD).
## Leave empty if not yet authored; renderer will use a placeholder.
## GDD §C — sprite_path.
@export_file("*.png") var sprite_path: String = ""

## Key name of the death animation in this enemy's AnimationPlayer.
##
## Example: [code]"death"[/code] or [code]"death_explode"[/code].
## Used by the EnemyRenderer to trigger the correct death sequence.
## Leave empty if no custom death animation is authored.
## GDD §C — death_anim_key.
@export var death_anim_key: String = ""

# ---------------------------------------------------------------------------
# Section: Flavor text (GDD §C)
# ---------------------------------------------------------------------------

## Short lore / flavor text shown on the enemy detail screen or bestiary.
##
## Max recommended length: 200 characters (fits the detail panel without scroll).
## May be localized at runtime via TranslationServer.
## GDD §C — flavor_text.
@export_multiline var flavor_text: String = ""

# ---------------------------------------------------------------------------
# Section: Boss flag (GDD §C)
# ---------------------------------------------------------------------------

## Whether this enemy is a boss encounter.
##
## Boss enemies trigger special UI, music, and reward sequences.
## Exactly one enemy per dungeon set should have [code]is_boss = true[/code]
## (enforced by content authoring guidelines; set-level invariant not checked here).
## Defaults [code]false[/code] — most enemies are standard encounters.
## GDD §C — is_boss.
@export var is_boss: bool = false
