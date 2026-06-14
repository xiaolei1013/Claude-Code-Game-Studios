class_name RosterConfig
extends GameData

## RosterConfig — single source of truth for HeroRoster tuning knobs.
##
## All Roster balance constants live here as [code]@export[/code] fields,
## loaded at startup from [code]assets/data/config/roster_config.tres[/code]
## via [DataRegistry]. No Roster balance value is hardcoded in
## [code]hero_roster.gd[/code] outside the config-loader fallback path.
##
## Usage:
##   [code]var cfg: RosterConfig = DataRegistry.resolve("config", "roster_config") as RosterConfig[/code]
##
## Call [method _validate] after any programmatic mutation to verify schema
## constraints. The method returns an empty array on a valid instance.
##
## ADR-0011: Resource schema + per-resource [method _validate] pattern.
## ADR-0012: HeroRoster — config-driven knobs.
## ADR-0006: DataRegistry boot-scan loads this file from assets/data/config/.
##
## NOTE: [member id] and [member display_name] are inherited from [GameData].
## Do NOT redeclare them here.

# ---------------------------------------------------------------------------
# Tuning knobs (TR-hero-roster-006 / GDD §G)
# ---------------------------------------------------------------------------

## Maximum number of recruited heroes the player may keep at once.
##
## Default 30 per GDD §G. Constraint: [member max_roster_size] must be
## strictly greater than or equal to [member formation_size] — a roster
## smaller than the active formation is structurally impossible.
@export_range(1, 200) var max_roster_size: int = 30

## Number of slots in the active formation.
##
## Default 3 per GDD §G. Each slot may hold a recruited hero's instance_id
## (positive int) or 0 (empty slot). Constraint: must be >= 1 and <=
## [member max_roster_size].
@export_range(1, 10) var formation_size: int = 3

## Maximum hero level reachable in MVP.
##
## Default 15 per GDD §G. Mutation API in HeroRoster Story 005 clamps level
## requests to [code][1, level_cap][/code]. Must be >= 1.
@export_range(1, 50) var level_cap: int = 15

## Defeat-injury recovery duration, in WALL-CLOCK seconds (GDD #34 Phase 3 /
## ADR-0021). When a party is defeated, each dispatched hero's
## [code]injured_until[/code] is set to [code]now_ms + injury_recovery_seconds * 1000[/code].
## Default 1800 (30 min) per GDD #34 §G. Constraint: must be >= 0; the 0 value
## is a valid designer dial meaning "injuries heal instantly" (no downtime).
##
## Seconds — NOT ticks — to match the project's [code]offline_cap_seconds[/code]
## convention and because recovery is wall-clock (elapses while backgrounded /
## offline per AC-34-05). This is the deliberate deviation from GDD #34's literal
## "INJURY_RECOVERY_TICKS" naming; see ADR-0021 / the GDD §D/§G amendment.
@export_range(0, 86_400) var injury_recovery_seconds: int = 1800


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Validates all schema constraints for this RosterConfig instance.
##
## Returns an empty [Array][String] if the instance is valid; returns a
## non-empty list of human-readable violation strings if any constraint fails.
##
## Enforced constraints:
##   1. [member max_roster_size] >= [member formation_size]
##      — TR-hero-roster-006: the active formation must fit in the roster
##   2. [member formation_size] >= 1
##   3. [member max_roster_size] >= 1
##   4. [member level_cap] >= 1
##   5. [member injury_recovery_seconds] >= 0 (GDD #34 Phase 3; 0 == instant heal)
##
## ADR-0011 §Decision — per-resource _validate() pattern.
func _validate() -> Array[String]:
	var errors: Array[String] = []

	if max_roster_size < formation_size:
		errors.append(
			"max_roster_size (%d) must be >= formation_size (%d)"
			% [max_roster_size, formation_size]
		)

	if formation_size < 1:
		errors.append("formation_size must be >= 1; got %d" % formation_size)

	if max_roster_size < 1:
		errors.append("max_roster_size must be >= 1; got %d" % max_roster_size)

	if level_cap < 1:
		errors.append("level_cap must be >= 1; got %d" % level_cap)

	if injury_recovery_seconds < 0:
		errors.append(
			"injury_recovery_seconds must be >= 0; got %d" % injury_recovery_seconds
		)

	return errors
