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
# Fields — exactly six, per TR-hero-roster-002 + GDD #34 Phase 3 (injured_until)
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

## Absolute WALL-CLOCK Unix-ms timestamp at which this hero's defeat injury
## heals (GDD #34 Phase 3 / ADR-0021). 0 is the "healthy" sentinel — a hero
## with injured_until == 0 has no active injury. Mutated only via
## HeroRoster.injure_heroes(). Wall-clock (NOT TickSystem sim-ticks) so that
## recovery elapses during background/offline time per AC-34-05 — the sim
## clock is paused while backgrounded and never fast-forwarded for offline.
##
## Deliberate deviation from GDD #34's literal "INJURY_RECOVERY_TICKS" naming;
## see ADR-0021 / the GDD §D amendment for the wall-clock rationale.
var injured_until: int = 0


## Returns true iff this hero has an active, not-yet-elapsed defeat injury.
##
## [param now_ms] is the current WALL-CLOCK time in Unix ms (callers pass
## [code]TickSystem.now_ms()[/code]). A hero is injured while
## [code]now_ms < injured_until[/code]; at the recovery instant
## ([code]now_ms == injured_until[/code]) and after, the hero has recovered.
## The 0 sentinel reads as healthy for any positive clock.
##
## [codeblock]
## # Gate dispatch on injury (GDD #34 §C.4):
## if hero.is_injured(TickSystem.now_ms()):
##     return  # reject — hero still recovering
## [/codeblock]
func is_injured(now_ms: int) -> bool:
	return injured_until > now_ms


# ---------------------------------------------------------------------------
# Serialization — exactly the 6 fields, per TR-hero-roster-003 + GDD #34 Phase 3
# ---------------------------------------------------------------------------

## Returns a 6-key Dictionary representation of this instance.
## Used by HeroRoster.get_save_data() to persist the roster element.
##
## TR-hero-roster-003: dict shape is exactly the 6 named fields (the 5 original
## plus injured_until per GDD #34 Phase 3). No other per-hero data is persisted.
func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"class_id": class_id,
		"display_name": display_name,
		"current_level": current_level,
		"xp": xp,
		"injured_until": injured_until,
	}


## Hydrates this instance from a Dictionary (the inverse of to_dict).
## Defensive defaults preserve invariants if the source dict is incomplete:
## - instance_id default 0 (uninitialized)
## - class_id default "" (will fail DataRegistry.resolve, surfacing as orphan)
## - display_name default ""
## - current_level default 1 (matches add_hero default)
## - xp default 0
## - injured_until default 0 (healthy) — legacy pre-Phase-3 saves omit the key,
##   so they load un-injured (GDD #34 save migration, AC-34-06). The int()
##   coercion also normalizes the TYPE_FLOAT a JSON save/load round-trip yields.
##
## TR-hero-roster-003: callers pass the 6-key dict produced by to_dict; a 5-key
## legacy dict is tolerated (injured_until defaults to 0).
func from_dict(d: Dictionary) -> void:
	instance_id = int(d.get("instance_id", 0))
	class_id = str(d.get("class_id", ""))
	display_name = str(d.get("display_name", ""))
	current_level = int(d.get("current_level", 1))
	xp = int(d.get("xp", 0))
	injured_until = int(d.get("injured_until", 0))
