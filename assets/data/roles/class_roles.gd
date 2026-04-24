class_name ClassRoles
extends RefCounted

## Canonical hero-class role constant set for Lantern Guild.
##
## All role string literals in the project MUST route through this module.
## Never hardcode role strings elsewhere — use these constants directly.
##
## All 6 roles are present from MVP through V1.0 (no phased subset needed).
##
## ADR-0011.

## A durable frontliner who draws enemy attention and protects allies.
const TANK: String = "tank"

## An aggressive melee damage dealer focused on raw physical output.
const STRIKER: String = "striker"

## A high-accuracy specialist (ranged or melee) that exploits enemy weaknesses.
const PRECISION: String = "precision"

## A utility provider who heals, buffs, or debuffs to strengthen the formation.
const SUPPORT: String = "support"

## A damage dealer who attacks safely from outside the front line.
const RANGED: String = "ranged"

## A formation leader who amplifies nearby allies through auras or commands.
const COMMANDER: String = "commander"

## Complete role set — all 6 hero-class roles, exhaustive for MVP and V1.0.
const ALL_SET: Array[String] = [TANK, STRIKER, PRECISION, SUPPORT, RANGED, COMMANDER]


## Returns [code]true[/code] if [param s] is any known class role.
## Comparison is case-sensitive — [code]"Tank"[/code] returns [code]false[/code].
static func is_valid(s: String) -> bool:
	return ALL_SET.has(s)
