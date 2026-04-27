extends Node

## HeroClassDatabase — rank-4 Core autoload.
##
## NOTE: No [code]class_name[/code] — autoload scripts cannot declare
## [code]class_name[/code] when the autoload name matches the class, or Godot
## raises "Class X hides an autoload singleton". The autoload is globally
## accessible as [code]HeroClassDatabase[/code]; tests use
## [code]preload("res://src/core/hero_class_database/hero_class_database.gd").new()[/code]
## for fresh instances.
##
## Thin typed-accessor wrapper over [DataRegistry]'s [code]classes[/code]
## category. Does NOT cache or shadow data — DataRegistry is the source of
## truth. Provides ergonomic helpers ([method get_by_id],
## [method get_recruitable_classes], [method get_all_ids]) so consumers do not
## need to know the registry category string.
##
## ADR-0011: Resource Schemas Core Databases (typed-accessor pattern).
## ADR-0006: DataRegistry boot scan + resolve contract.
## ADR-0003: Autoload rank 4; zero-arg [code]_init[/code] Amendment #3.

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

## Zero-arg [code]_init[/code] required by ADR-0003 Amendment #3.
##
## Godot autoload Nodes are instantiated with zero arguments by the engine;
## any required parameter on [code]_init[/code] would silently fail
## instantiation. Do NOT read or subscribe to other autoloads here — use
## [code]_ready()[/code] instead.
func _init() -> void:
	pass


## No boot work needed: DataRegistry (rank 1) has already scanned and loaded
## the [code]classes[/code] category before this autoload's [code]_ready()[/code]
## fires (rank order per ADR-0003 guarantees rank-1 is READY by rank-4 boot).
func _ready() -> void:
	pass

# ---------------------------------------------------------------------------
# Public methods
# ---------------------------------------------------------------------------

## Returns the [HeroClass] resource for [param id], or [code]null[/code] on miss.
##
## [code]null[/code] is the documented contract — callers MUST null-check the
## return value and apply their own fallback policy. This method does NOT emit
## [code]push_error[/code] on miss; [DataRegistry] emits [code]push_warning[/code]
## via its [enum DataRegistry.MissingIdBehavior.WARN] mode.
##
## Returns [code]null[/code] if DataRegistry has not reached READY state.
##
## Example:
##   [codeblock]
##   var warrior: HeroClass = HeroClassDatabase.get_by_id("warrior")
##   if warrior == null:
##       return  # apply fallback here
##   [/codeblock]
func get_by_id(id: String) -> HeroClass:
	return DataRegistry.resolve("classes", id) as HeroClass


## Returns all [HeroClass] resources whose [code]is_recruitable[/code] field is
## [code]true[/code] — STUB for this story.
##
## The real body is implemented in hero-class-database epic Story 007
## (S2-N1 / Nice-to-Have, not in Sprint 2 Must Have). This stub returns an
## empty typed array so all callers compile and run without error today.
##
## Example:
##   [codeblock]
##   var pool: Array[HeroClass] = HeroClassDatabase.get_recruitable_classes()
##   # pool is always [] until Story 007 lands
##   [/codeblock]
func get_recruitable_classes() -> Array[HeroClass]:
	return [] as Array[HeroClass]


## Returns a sorted [Array][String] of all loaded class ids.
##
## Reads from [DataRegistry.get_all_by_type]([code]"classes"[/code]) — does NOT
## cache. Callers that read this repeatedly (e.g. UI refresh loops) MUST cache
## the returned array; do NOT call inside [code]_process[/code] or per-tick
## handlers (ADR-0006 alloc note on [method DataRegistry.get_all_by_type]).
##
## Returns an empty array if no classes are loaded (DataRegistry in ERROR or
## LOADING state, or zero [code].tres[/code] files in [code]assets/data/classes/[/code]).
##
## Ids are sorted alphabetically for stable enumeration order.
##
## Example:
##   [codeblock]
##   var ids: Array[String] = HeroClassDatabase.get_all_ids()
##   # e.g. ["mage", "rogue", "warrior"] after S2-M7 lands
##   [/codeblock]
func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for r: Resource in DataRegistry.get_all_by_type("classes"):
		if r is HeroClass:
			ids.append((r as HeroClass).id)
	ids.sort()
	return ids
