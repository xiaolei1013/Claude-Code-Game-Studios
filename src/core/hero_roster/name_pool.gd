## NamePool — per-class hero-name pool resource (Sprint 8 S8-N9 / Story 009).
##
## Resolved by HeroRoster's [method _generate_name] via
## [code]DataRegistry.resolve("name_pools", class_id)[/code]. Each MVP class
## (warrior, mage, rogue) ships with a pool of >=20 cozy-fantasy names per
## TR-hero-roster-023.
##
## When the pool's unused subset is exhausted (player owns 20+ heroes of the
## same class), HeroRoster falls back to "{base} the {Ordinal}" naming
## (TR-022 — e.g., "Theron the Second"). The pool resource itself stays
## simple — pool-tracking state lives on HeroRoster (recomputed per call
## from `_heroes`, NOT persisted).
##
## ADR-0011: Resource Schemas Core Databases — `id` field per snake_case rule.
## ADR-0012: Hero Roster Mutation + Identity — pool-resolution path.
class_name NamePool extends GameData

## The class_id this pool serves. Must match a class_id from
## `assets/data/classes/*.tres` (e.g., "warrior", "mage", "rogue").
@export var class_id: String = ""

## Pool of display_name candidates. >=20 entries per MVP class per TR-023.
## Names should fit the cozy-fantasy / warm-light aesthetic of the Visual
## Identity Anchor (`design/gdd/game-concept.md`).
@export var names: Array[String] = []


## ADR-0011 per-resource validation. Returns Array[String] of error messages;
## empty Array means valid.
##
## Constraints:
##   1. `class_id` is non-empty snake_case (handled at the GameData level via id)
##   2. `names` has at least 1 entry (the pool can't be empty)
##   3. No duplicate names within the pool
##   4. No empty-string names
##
## TR-hero-roster-023 — ADR-0011
func _validate() -> Array[String]:
	var errors: Array[String] = []
	if class_id.is_empty():
		errors.append("class_id must be non-empty")
	if names.is_empty():
		errors.append("names array must have at least 1 entry")
	# Duplicate check.
	var seen: Dictionary = {}
	for n: String in names:
		if n.is_empty():
			errors.append("names array contains empty-string entry")
			continue
		if seen.has(n):
			errors.append("duplicate name in pool: '%s'" % n)
		seen[n] = true
	return errors
