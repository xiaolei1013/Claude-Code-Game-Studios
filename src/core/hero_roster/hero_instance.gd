## HeroInstance — lightweight player-state record for a recruited hero.
##
## This is a RefCounted data class, NOT a Godot Resource (per ADR-0012). Hero
## instances are owned by the HeroRoster autoload, mutable only via HeroRoster
## methods, and persisted via to_dict/from_dict. There is no .tres file per
## hero — the player's roster is a typed Dictionary keyed by instance_id.
##
## Class templates live in HeroClassDatabase (Core layer) as immutable HeroClass
## resources. HeroInstance.class_id is the string reference resolved through
## DataRegistry.resolve("classes", class_id) at read time.
##
## ADR-0011: Resource Schemas Core Databases (class_id reference, not Resource)
## ADR-0012: Hero Roster Mutation + Identity (instance_id immutable; mutation
##           via HeroRoster only; no setter methods on HeroInstance itself)
class_name HeroInstance extends RefCounted

# ---------------------------------------------------------------------------
# Fields — exactly five, per TR-hero-roster-002
# ---------------------------------------------------------------------------

## Monotonic positive int identity for this hero. Assigned by HeroRoster.add_hero
## and never reused after remove_hero. Cross-session stable for save/load.
## Default 0 means "uninitialized" — a HeroInstance with instance_id == 0 has
## not been registered in any roster.
var instance_id: int = 0

## Class template reference. Resolves to a HeroClass via
## DataRegistry.resolve("classes", class_id). Immutable after add_hero.
var class_id: String = ""

## Player-facing name. For seed Hero Theron (TR-021) this is hardcoded;
## for all others it's drawn from name_pools (Story 009). Immutable after add_hero.
var display_name: String = ""

## Current level [1, LEVEL_CAP=15]. Mutable via HeroRoster.set_hero_level only.
var current_level: int = 1

## Reserved field for V1.0 progression. Always 0 in MVP and never displayed.
## Persisted in to_dict for forward compatibility with V1.0 save migrations.
var xp: int = 0


# ---------------------------------------------------------------------------
# Serialization — exactly the 5 fields, per TR-hero-roster-003
# ---------------------------------------------------------------------------

## Returns a 5-key Dictionary representation of this instance.
## Used by HeroRoster.get_save_data() to persist the roster element.
##
## TR-hero-roster-003: dict shape is exactly the 5 named fields. No other
## per-hero data is persisted.
func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"class_id": class_id,
		"display_name": display_name,
		"current_level": current_level,
		"xp": xp,
	}


## Hydrates this instance from a 5-key Dictionary (the inverse of to_dict).
## Defensive defaults preserve invariants if the source dict is incomplete:
## - instance_id default 0 (uninitialized)
## - class_id default "" (will fail DataRegistry.resolve, surfacing as orphan)
## - display_name default ""
## - current_level default 1 (matches add_hero default)
## - xp default 0
##
## TR-hero-roster-003: callers pass exactly the 5-key dict produced by to_dict.
func from_dict(d: Dictionary) -> void:
	instance_id = int(d.get("instance_id", 0))
	class_id = str(d.get("class_id", ""))
	display_name = str(d.get("display_name", ""))
	current_level = int(d.get("current_level", 1))
	xp = int(d.get("xp", 0))
