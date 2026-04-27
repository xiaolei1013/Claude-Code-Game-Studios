class_name HeroClass
extends GameData

## HeroClass — read-only resource schema for hero classes (Lantern Guild MVP).
##
## Stored as [code].tres[/code] files in [code]assets/data/classes/[/code] and
## resolved at runtime via [code]DataRegistry.resolve("classes", id)[/code].
## Story 003 (S2-M7) authors the 3 MVP class .tres files (warrior/mage/rogue).
##
## All archetype values MUST route through [EnemyArchetypes] constants — never
## use raw archetype string literals in this file (ADR-0011 §Forbidden).
##
## [b]Inherited fields[/b] (do NOT redeclare):
##   [member GameData.id] — stable snake_case identifier (e.g. [code]"class_warrior"[/code])
##   [member GameData.display_name] — localizable display name shown in UI
##
## [b]Usage:[/b]
##   [codeblock]
##   var hc: HeroClass = DataRegistry.resolve("classes", "class_warrior") as HeroClass
##   [/codeblock]
##
## ADR-0011: Resource Schemas Core Databases.
## ADR-0006: DataRegistry boot-scan pattern.

# ---------------------------------------------------------------------------
# Section: Constants & Enums
# ---------------------------------------------------------------------------

## Maximum hero level. Mirrors [member EconomyConfig.LEVEL_CAP] but is declared
## here to avoid Core-layer coupling to Economy from the schema resource itself.
## Keep this value in lockstep with EconomyConfig at edit time. GDD §G LEVEL_CAP.
##
## CI guardrail: `tests/unit/hero_class_database/stat_at_level_test.gd` asserts
## this equals the live `economy_config.tres` value so silent drift fails fast.
const LEVEL_CAP: int = 15

## Hero stat selector for [method stat_at_level]. Keeps the formula API
## type-safe and removes the unknown-stat fallback path.
enum Stat { ATTACK, HP, SPEED }

# ---------------------------------------------------------------------------
# Section: Progression tier (GDD §C.1)
# ---------------------------------------------------------------------------

## Rarity / progression tier of this class (1 = Tier 1, 2 = Tier 2).
##
## Controls recruit cost curve via [member EconomyConfig.BASE_RECRUIT][tier]
## and level cost curve via [member EconomyConfig.BASE_LEVEL][tier].
## MVP ships Tier 1 (warrior, mage, rogue) and one Tier 2 class.
## Safe range: 1 – 2.
## GDD §C.1 — tier field.
@export_range(1, 2) var tier: int = 1

# ---------------------------------------------------------------------------
# Section: Role (GDD §C.1)
# ---------------------------------------------------------------------------

## Combat role string for this class (e.g. [code]"tank"[/code], [code]"striker"[/code]).
##
## Must be a value from [ClassRoles.ALL_SET]; validated at DataRegistry load time
## (Story 008). Roles determine formation placement rules and tooltip display.
## Use [ClassRoles] constants — never hardcode role strings in downstream code.
## GDD §C.1 — role field.
@export var role: String = ""

# ---------------------------------------------------------------------------
# Section: Matchup (GDD §C.1 — class-vs-biome counter system)
# ---------------------------------------------------------------------------

## The enemy archetype this class counters (e.g. [code]EnemyArchetypes.BRUISER[/code]).
##
## When this class is on the active formation and the dungeon enemy matches this
## archetype, the matchup bonus applies ([member EconomyConfig.MATCHUP_GOLD_MULTIPLIER]
## and [member EconomyConfig.MATCHUP_DRIP_BONUS]).
## MUST be an empty string (no counter) or a value from [EnemyArchetypes.ALL_SET].
## Default [code]""[/code] means this class has no assigned counter archetype.
## GDD §C.1 — counter_archetype field.
@export var counter_archetype: String = ""

# ---------------------------------------------------------------------------
# Section: Base stats at Level 1 (GDD §C.2)
# ---------------------------------------------------------------------------

## Base attack damage at Level 1.
##
## Contributes to tick output formula: Story 004 (stat_at_level).
## All stat values must be >= 0.
## Safe range: 0 – 999.
## GDD §C.2 — base_attack.
@export_range(0, 999) var base_attack: int = 0

## Base hit points at Level 1.
##
## Determines formation survival against enemy archetypes in dungeon runs.
## Safe range: 0 – 9999.
## GDD §C.2 — base_hp.
@export_range(0, 9999) var base_hp: int = 0

## Base speed at Level 1.
##
## Determines action order within a dungeon tick. Higher speed acts earlier.
## Safe range: 0 – 999.
## GDD §C.2 — base_speed.
@export_range(0, 999) var base_speed: int = 0

# ---------------------------------------------------------------------------
# Section: Per-level stat growth (GDD §C.2)
# ---------------------------------------------------------------------------

## Attack added per hero level above Level 1.
##
## Stat formula: [code]base_attack + attack_per_level * (level - 1)[/code].
## Implemented by Story 004 (stat_at_level helper).
## Safe range: 0 – 100.
## GDD §C.2 — attack_per_level.
@export_range(0, 100) var attack_per_level: int = 0

## HP added per hero level above Level 1.
##
## Stat formula: [code]base_hp + hp_per_level * (level - 1)[/code].
## Implemented by Story 004.
## Safe range: 0 – 1000.
## GDD §C.2 — hp_per_level.
@export_range(0, 1000) var hp_per_level: int = 0

## Speed added per hero level above Level 1.
##
## Stat formula: [code]base_speed + speed_per_level * (level - 1)[/code].
## Implemented by Story 004.
## Safe range: 0 – 50.
## GDD §C.2 — speed_per_level.
@export_range(0, 50) var speed_per_level: int = 0

# ---------------------------------------------------------------------------
# Section: Tick output contribution (GDD §C.3 — idle income)
# ---------------------------------------------------------------------------

## Gold-equivalent tick output this class contributes at Level 1.
##
## Used in [code]hero_tick_output(level)[/code] formula (Story 005):
##   [code]tick_output_contribution_l1 + tick_output_per_level * (level - 1)[/code]
## This value is added to the formation's total tick output during dungeon runs.
## Safe range: 0 – 9999.
## GDD §C.3 — tick_output_contribution_l1.
@export_range(0, 9999) var tick_output_contribution_l1: int = 0

## Additional tick output this class contributes per hero level above Level 1.
##
## Idle income growth rate. See [member tick_output_contribution_l1] for formula.
## Safe range: 0 – 999.
## GDD §C.3 — tick_output_per_level.
@export_range(0, 999) var tick_output_per_level: int = 0

# ---------------------------------------------------------------------------
# Section: Asset paths (GDD §C.4 — visual identity)
# ---------------------------------------------------------------------------

## Res-path to the in-dungeon sprite texture for this class.
##
## Example: [code]"res://assets/art/heroes/warrior_sprite.png"[/code].
## Loaded at runtime by the HeroRenderer node (Story TBD).
## Leave empty if not yet authored; renderer will use a placeholder.
## GDD §C.4 — sprite_path.
@export_file("*.png") var sprite_path: String = ""

## Res-path to the portrait texture for roster and recruit UI.
##
## Example: [code]"res://assets/art/heroes/warrior_portrait.png"[/code].
## Loaded by HeroPortraitCard (Story TBD).
## Leave empty if not yet authored; UI will show a placeholder silhouette.
## GDD §C.4 — portrait_path.
@export_file("*.png") var portrait_path: String = ""

## Res-path to the small icon texture for HUD and formation slots.
##
## Example: [code]"res://assets/art/heroes/warrior_icon.png"[/code].
## 44×44 px minimum for mobile tap-target parity (Technical Preferences).
## Leave empty if not yet authored; HUD will use a fallback icon.
## GDD §C.4 — icon_path.
@export_file("*.png") var icon_path: String = ""

# ---------------------------------------------------------------------------
# Section: Flavor text (GDD §C.5 — narrative)
# ---------------------------------------------------------------------------

## Short lore / flavor text shown on the class detail screen.
##
## Max recommended length: 200 characters (fits the detail panel without scroll).
## May be localized at runtime via TranslationServer.
## GDD §C.5 — flavor_text.
@export_multiline var flavor_text: String = ""

# ---------------------------------------------------------------------------
# Section: Stat helper (GDD §H-02 / §H-03 / §H-04 — ADR-0011)
# ---------------------------------------------------------------------------

## Returns the value of [param stat] at hero [param level] for this class.
##
## Formula (integer arithmetic only, ADR-0011):
##   [code]base_<stat> + <stat>_per_level * (clamp(level, 1, LEVEL_CAP) - 1)[/code]
##
## Behavior:
##   • [param stat] is the typed [enum Stat] selector — exhaustive at compile
##     time, no unknown-stat fallback path.
##   • [param level] above [constant LEVEL_CAP] is silently clamped (GDD §H-03).
##   • [param level] below 1 fires [method @GlobalScope.push_error] and returns
##     L1 stats as a safe fallback (GDD §H-04).
##
## [b]Usage:[/b]
##   [codeblock]
##   var hp_at_l8: int = warrior.stat_at_level(HeroClass.Stat.HP, 8)
##   [/codeblock]
func stat_at_level(stat: Stat, level: int) -> int:
	var clamped_level: int = level
	if level < 1:
		push_error("HeroClass.stat_at_level: level=%d invalid; clamping to 1" % level)
		clamped_level = 1
	elif level > LEVEL_CAP:
		clamped_level = LEVEL_CAP
	var growth: int = clamped_level - 1
	match stat:
		Stat.ATTACK:
			return base_attack + attack_per_level * growth
		Stat.HP:
			return base_hp + hp_per_level * growth
		Stat.SPEED:
			return base_speed + speed_per_level * growth
	return 0  # Unreachable — Stat enum is exhaustive.


## Returns [code]true[/code] iff [param class_data]'s [member counter_archetype]
## exactly equals [param enemy_archetype]. Case-sensitive pure string equality.
##
## Behavior (ADR-0011 §H-05/§H-06):
##   • Null [param class_data] fires [method @GlobalScope.push_error] and returns
##     [code]false[/code].
##   • Empty string and unknown archetype both return [code]false[/code] (no
##     membership check; pure equality only).
##   • Used per-tick by the matchup-resolver — kept tight (single comparison).
##
## [b]Usage:[/b]
##   [codeblock]
##   if HeroClass.is_class_counter(warrior, EnemyArchetypes.BRUISER):
##       # apply matchup bonus
##   [/codeblock]
static func is_class_counter(class_data: HeroClass, enemy_archetype: String) -> bool:
	if class_data == null:
		push_error("HeroClass.is_class_counter: class_data is null")
		return false
	return class_data.counter_archetype == enemy_archetype
