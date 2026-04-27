extends Node

## BiomeDungeonDatabase — rank-6 Core autoload.
##
## NOTE: No [code]class_name[/code] — autoload scripts cannot declare
## [code]class_name[/code] when the autoload name matches the class, or Godot
## raises "Class X hides an autoload singleton". The autoload is globally
## accessible as [code]BiomeDungeonDatabase[/code]; tests use
## [code]preload("res://src/core/biome_dungeon_database/biome_dungeon_database.gd").new()[/code]
## for fresh instances.
##
## Thin typed-accessor wrapper over [DataRegistry]'s [code]biomes[/code] and
## [code]dungeons[/code] categories. Does NOT cache or shadow data — DataRegistry
## is the source of truth. Provides ergonomic helpers
## ([method get_biome_by_id], [method get_dungeon_by_id], [method get_floor_by_id],
## [method get_playable_biomes], [method get_all_biome_ids],
## [method get_floors_for_dungeon]) so consumers do not need to know the
## registry category strings or the nested Floor-within-Dungeon layout.
##
## NOTE on [code]get_floor_by_id[/code]: "floors" is NOT in
## [constant DataRegistry.ORDERED_CATEGORIES] — Floors are nested resources
## inside [Dungeon] resources per ADR-0011 §Resource layout. There are no
## standalone [code]floors/[/code] .tres files. Therefore [method get_floor_by_id]
## performs a cross-dungeon linear search. Callers that need Floor instances
## frequently should prefer [method get_floors_for_dungeon] and index the
## returned array themselves to avoid repeated scans.
##
## ADR-0011: Resource Schemas Core Databases (typed-accessor + nested-resource design).
## ADR-0006: DataRegistry boot scan + resolve contract.
## ADR-0003: Autoload rank 6; zero-arg [code]_init[/code] Amendment #3.

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
## the [code]biomes[/code] and [code]dungeons[/code] categories before this
## autoload's [code]_ready()[/code] fires (rank order per ADR-0003 guarantees
## rank-1 is READY by rank-6 boot).
func _ready() -> void:
	pass


# ---------------------------------------------------------------------------
# Public methods — category accessors
# ---------------------------------------------------------------------------

## Returns the [Biome] resource for [param id], or [code]null[/code] on miss.
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
##   var biome: Biome = BiomeDungeonDatabase.get_biome_by_id("forest_reach")
##   if biome == null:
##       return  # apply fallback here
##   [/codeblock]
func get_biome_by_id(id: String) -> Biome:
	return DataRegistry.resolve("biomes", id) as Biome


## Returns the [Dungeon] resource for [param id], or [code]null[/code] on miss.
##
## [code]null[/code] is the documented contract — callers MUST null-check the
## return value and apply their own fallback policy. This method does NOT emit
## [code]push_error[/code] on miss; [DataRegistry] emits [code]push_warning[/code]
## via its [enum DataRegistry.MissingIdBehavior.WARN] mode.
##
## Note: Dungeons are registered as top-level resources in the [code]"dungeons"[/code]
## category (ADR-0011). Their floors are accessible via [method get_floors_for_dungeon].
##
## Returns [code]null[/code] if DataRegistry has not reached READY state.
##
## Example:
##   [codeblock]
##   var dungeon: Dungeon = BiomeDungeonDatabase.get_dungeon_by_id("forest_reach_main")
##   if dungeon == null:
##       return  # apply fallback here
##   [/codeblock]
func get_dungeon_by_id(id: String) -> Dungeon:
	return DataRegistry.resolve("dungeons", id) as Dungeon


## Returns the [Floor] resource whose [member GameData.id] matches [param id],
## or [code]null[/code] if no such Floor exists across any loaded [Dungeon].
##
## NOTE: "floors" is NOT in [constant DataRegistry.ORDERED_CATEGORIES] —
## Floors are nested resources inside Dungeon resources per ADR-0011 §Resource
## layout. This method performs a cross-dungeon linear scan. For performance-
## sensitive callers that access the same Floor repeatedly, cache the result
## at the call site.
##
## Returns [code]null[/code] (no push_error) on miss or when DataRegistry is
## not READY.
##
## Example:
##   [codeblock]
##   var floor: Floor = BiomeDungeonDatabase.get_floor_by_id("forest_reach_main_floor_1")
##   if floor == null:
##       return  # floor not found or DataRegistry not ready
##   [/codeblock]
func get_floor_by_id(id: String) -> Floor:
	if DataRegistry.state != DataRegistry.State.READY:
		return null
	for r: Resource in DataRegistry.get_all_by_type("dungeons"):
		if not r is Dungeon:
			continue
		var dungeon: Dungeon = r as Dungeon
		for f: Floor in dungeon.floors:
			if f.id == id:
				return f
	return null


# ---------------------------------------------------------------------------
# Public methods — helpers
# ---------------------------------------------------------------------------

## Returns all [Biome] resources with [code]status == "active"[/code], sorted
## by [member GameData.id].
##
## V1.0 stub biomes ([code]status == "planned_v1"[/code] or any non-active
## value) are excluded from the result. Use [method get_biome_by_id] if you
## need to resolve a stub biome directly.
##
## Conforms to TR-biome-dungeon-db-014 + AC H-08 (V1.0 filter).
##
## Returns an empty array if no biomes are loaded or DataRegistry is not READY.
## Allocates a new Array on every call — callers should cache if called
## repeatedly (e.g. UI refresh).
##
## Example:
##   [codeblock]
##   var playable: Array[Biome] = BiomeDungeonDatabase.get_playable_biomes()
##   for biome: Biome in playable:
##       populate_biome_card(biome)
##   [/codeblock]
func get_playable_biomes() -> Array[Biome]:
	var result: Array[Biome] = []
	for r: Resource in DataRegistry.get_all_by_type("biomes"):
		if r is Biome and (r as Biome).status == "active":
			result.append(r as Biome)
	result.sort_custom(func(a: Biome, b: Biome) -> bool: return a.id < b.id)
	return result


## Returns a sorted [Array][String] of all loaded biome ids (active + planned).
##
## Reads from [DataRegistry.get_all_by_type]([code]"biomes"[/code]) — does NOT
## cache. Includes ALL biomes regardless of [member Biome.status]; use
## [method get_playable_biomes] if you only want active biomes.
##
## Returns an empty array if no biomes are loaded (DataRegistry in ERROR or
## LOADING state, or zero [code].tres[/code] files in [code]assets/data/biomes/[/code]).
##
## Ids are sorted alphabetically for stable enumeration order.
##
## Example:
##   [codeblock]
##   var ids: Array[String] = BiomeDungeonDatabase.get_all_biome_ids()
##   # e.g. ["forest_reach", "volcanic_depths", ...] after content lands
##   [/codeblock]
func get_all_biome_ids() -> Array[String]:
	var ids: Array[String] = []
	for r: Resource in DataRegistry.get_all_by_type("biomes"):
		if r is Biome:
			ids.append((r as Biome).id)
	ids.sort()
	return ids


## Returns the [Floor] resources for [param dungeon_id], sorted ascending by
## [member Floor.floor_index].
##
## Resolves the [Dungeon] via [method get_dungeon_by_id], then returns a
## sorted duplicate of its [member Dungeon.floors] array. The returned array
## is a shallow duplicate — elements are the same cached [Floor] instances;
## do NOT mutate them (ADR-0006 read-only contract).
##
## Returns an empty array (no push_error) if:
##   - [param dungeon_id] does not resolve to a known Dungeon.
##   - DataRegistry is not in READY state.
##   - The resolved Dungeon has no floors authored yet.
##
## Example:
##   [codeblock]
##   var floors: Array[Floor] = BiomeDungeonDatabase.get_floors_for_dungeon("forest_reach_main")
##   for floor: Floor in floors:
##       queue_floor_encounter(floor)
##   [/codeblock]
func get_floors_for_dungeon(dungeon_id: String) -> Array[Floor]:
	var dungeon: Dungeon = get_dungeon_by_id(dungeon_id)
	if dungeon == null:
		return []
	var floors: Array[Floor] = dungeon.floors.duplicate()
	floors.sort_custom(func(a: Floor, b: Floor) -> bool: return a.floor_index < b.floor_index)
	return floors
