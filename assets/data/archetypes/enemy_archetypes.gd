class_name EnemyArchetypes
extends RefCounted

## Canonical enemy-archetype constant set for Lantern Guild.
##
## All archetype string literals in the project MUST route through this module.
## Never hardcode archetype strings elsewhere — use these constants directly.
##
## MVP ships the 3 MVP archetypes (see [constant MVP_SET]).
## V1.0 adds the remaining 3 (see [constant ALL_SET]).
##
## ADR-0011.

## A tough, close-range enemy that absorbs damage and threatens the front line.
const BRUISER: String = "bruiser"

## A long-range magic user that deals high burst damage.
const CASTER: String = "caster"

## A heavily protected enemy with high physical and magical resistance.
const ARMORED: String = "armored"

## A fast, mobile enemy that exploits unprotected flanks. (V1.0)
const BEAST: String = "beast"

## A mechanical or golem-type enemy immune to morale effects. (V1.0)
const CONSTRUCT: String = "construct"

## A spectral or ethereal enemy that bypasses physical armour. (V1.0)
const INCORPOREAL: String = "incorporeal"

## MVP archetype subset — the three archetypes present from Sprint 1 through
## MVP ship. Validators and content authors must treat this set as current scope.
const MVP_SET: Array[String] = [BRUISER, CASTER, ARMORED]

## Complete archetype set — MVP_SET plus the three V1.0 archetypes.
## Validators that run against all shipped content should use ALL_SET.
const ALL_SET: Array[String] = [BRUISER, CASTER, ARMORED, BEAST, CONSTRUCT, INCORPOREAL]


## Returns [code]true[/code] if [param s] is any known archetype (MVP or V1.0).
## Comparison is case-sensitive — [code]"Bruiser"[/code] returns [code]false[/code].
static func is_valid(s: String) -> bool:
	return ALL_SET.has(s)


## Returns [code]true[/code] if [param s] is in the MVP archetype subset.
## Comparison is case-sensitive — [code]"Bruiser"[/code] returns [code]false[/code].
static func is_mvp(s: String) -> bool:
	return MVP_SET.has(s)
