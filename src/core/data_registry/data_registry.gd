extends Node

## DataRegistry — rank-1 Foundation autoload.
##
## NOTE: No `class_name` — autoload scripts cannot declare `class_name`
## when the autoload name matches the class (Godot "hides an autoload
## singleton" error). The autoload is globally accessible as
## `DataRegistry`; tests that need a fresh instance use
## `preload("res://src/core/data_registry/data_registry.gd").new()`.
##
## Owns the content database for all `.tres` resource files under `assets/data/`.
## Drives the UNLOADED → LOADING → READY | ERROR | HOT_RELOAD state machine.
## Consumers gate hydration on [member state] == [enum State.READY] per ADR-0006.
##
## ADR-0006: DataRegistry boot scan strategy + state machine contract
## ADR-0003: Autoload Rank Table (rank 1; zero-arg _init invariant — Amendment #3)
## ADR-0011: Per-type validator specifications + load-time validation semantics
##
## TR-data-loading-027 (no patch-time live updates):
## The in-memory index is populated exactly once per cold boot via [method _boot_scan].
## New `.tres` files dropped into `assets/data/` at runtime are NOT automatically
## picked up — the next launch rebuilds the full index. Debug builds may opt in
## to a one-category re-enumeration via [method hot_reload]; production builds
## no-op the call (see [method hot_reload] for the runtime gate).

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Deterministic content category load order per ADR-0006.
##
## Adding a new category requires an explicit edit HERE plus a corresponding
## edit to [member min_content_count] — auto-discovery from directory presence
## is FORBIDDEN per ADR-0006.
##
## Order matters: [code]classes → enemies → biomes → dungeons → items → matchup → config[/code].
## Story 006 adds DAG cycle-detection on top of this fixed order.
##
## "config" was appended in Sprint 2 / S2-M2 to support [code]EconomyConfig[/code]
## loading from [code]assets/data/config/[/code]. It is loaded last because tuning
## resources have no cross-references to other categories — the order is a
## load-time invariant, not a dependency declaration.
const ORDERED_CATEGORIES: Array[String] = [
	"classes", "enemies", "biomes", "dungeons", "items", "matchup", "config", "name_pools",
	"sfx", "music",
]

# Snake_case id regex per ADR-0011 §Load-Time Validation Semantics.
# Accepts: lowercase letter start, followed by lowercase letters, digits, or underscores.
# Rejects: PascalCase, empty, leading digit, hyphens.
const _SNAKE_CASE_ID_PATTERN: String = "^[a-z][a-z0-9_]*$"

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## Boot and lifecycle state machine for the DataRegistry.
##
## Allowed transitions:
##   UNLOADED → LOADING  (entry in _ready)
##   LOADING  → READY    (_boot_scan succeeds)
##   LOADING  → ERROR    (_boot_scan fails — set via _transition_to_error)
##   READY    → HOT_RELOAD (hot_reload() — debug builds only; body in Story 007)
##   ERROR    is terminal; no exit transition
enum State {
	## Initial state before _ready() fires. No content is available.
	UNLOADED,
	## _ready() is actively scanning assets/data/. Consumers must not call resolve().
	LOADING,
	## All content loaded successfully. resolve() and get_all_by_type() are safe.
	READY,
	## Fatal load error encountered. Terminal: no transition out. Game cannot proceed.
	ERROR,
	## Debug-only re-scan in progress. Body filled by Story 007.
	HOT_RELOAD,
}

## Controls how a missing-id lookup is reported. See [method resolve].
##
## WARN (production default): push_warning with structured message; caller gets null.
## ASSERT (test builds): assert(false, ...) fires before returning null — surfacing
##   programmer errors early in CI without shipping crashing code to players.
##
## Set via [member missing_id_behavior] at the autoload level, or override per
## test fixture to exercise the ASSERT path.
enum MissingIdBehavior {
	## Emit push_warning and return null. Production default — never crashes.
	WARN,
	## Fire assert(false, ...) before returning null. Use in test builds / CI only.
	ASSERT,
}

## Canonical reason strings emitted by [signal registry_error].
##
## Tests and consumers MUST compare against these constants rather than raw
## string literals — prevents silent typo-drift between producer and listener.
const ERROR_INVALID_ID: String = "InvalidId"
const ERROR_DUPLICATE_ID: String = "DuplicateId"
const ERROR_MIN_CONTENT_COUNT: String = "MinContentCount"
const ERROR_INVALID_FIELD: String = "InvalidField"
## Story 006 — emitted by [signal registry_error] when [method _validate_dag]
## detects a circular reference in the dungeon ↔ biome graph. Details payload:
## [code]{"cycle": Array[String]}[/code] with the cycle path repeated tail-to-head
## (e.g. [code]["dungeon_a", "biome_b", "dungeon_a"][/code]).
## ADR-0006 §DAG validation, TR-data-loading-018.
const ERROR_CIRCULAR_REF: String = "CircularRef"

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted synchronously at the end of _ready() when _boot_scan() succeeds.
## Rank-2+ autoloads may connect to this in their own _ready() per ADR-0003
## Amendment #1 (rank-N may connect to rank-(N+1)+ signals at _ready() time).
signal registry_ready

## Emitted when a fatal load error prevents the registry from reaching READY.
## [param reason] is a non-empty human-readable error summary.
## [param details] carries structured diagnostic data (e.g. {"path": "...", "code": N}).
signal registry_error(reason: String, details: Dictionary)

## Emitted after a successful hot-reload re-enumeration pass (debug builds only).
## [param content_type] names the content category that was refreshed.
## Forward-looking — emit path lands when the hot-reload pass ships.
@warning_ignore("unused_signal")
signal hot_reload_complete(content_type: String)

# ---------------------------------------------------------------------------
# Export variables (tuning knobs)
# ---------------------------------------------------------------------------

## Root path scanned during boot. Default is the production content directory.
##
## Override in test environments to point at fixture datasets without touching
## the production [code]assets/data/[/code] tree. In release builds the value
## should always equal the default — a project-settings assertion can enforce
## this (Story 008 performance budget phase).
##
## Example (test override):
##   [code]registry.data_root_path = "res://tests/fixtures/data_registry/boot_scan/"[/code]
@export var data_root_path: String = "res://assets/data"

## Categories deferred to lazy-load rather than eager boot scan. MVP value is
## empty — all categories are eager-loaded. Populated in V1.0 when late-loading
## of large item pools becomes a performance concern (Story 008 knob surface).
##
## Any category listed here is skipped by [method _boot_scan] and must be
## loaded on-demand by the consumer. Story 008 wires the lazy path; this field
## only declares the contract and holds the default.
@export var lazy_load_categories: PackedStringArray = PackedStringArray()

## Governs how a missing id is reported in [method resolve].
##
## [enum MissingIdBehavior.WARN] (default): push_warning; return null.
## [enum MissingIdBehavior.ASSERT]: assert(false, ...) in debug/test builds; return null.
##
## Test fixtures should set this to ASSERT to surface unresolved references as
## hard failures in CI. Never ship ASSERT to players.
##
## See also: [method _report_missing_id].
@export var missing_id_behavior: MissingIdBehavior = MissingIdBehavior.WARN

## Minimum required content count per category. If any category ends its
## load walk with fewer valid resources than its entry here, the registry
## transitions to ERROR state.
##
## Defaults per ADR-0006 §Key interfaces. [code]items[/code] is intentionally
## absent — zero items is a valid MVP state; downstream Orchestrator gates item
## access on its own zero-count check.
##
## [code]matchup[/code] was also lowered from 1 → 0 in Sprint 3 / S3-M8
## (TD-006 closure): per ADR-0009, the Matchup Resolver is a code-level
## DI pure-function module with no MVP-stage [code].tres[/code] content;
## the [code]matchup/[/code] directory exists for forward-compat (V1.0
## per-class matchup config tables) but is empty in MVP scope.
##
## Override in dev/test via:
##   [code]registry.min_content_count = {"classes": 1, "enemies": 1}[/code]
## Set to [code]{}[/code] to disable all minimum-count enforcement (e.g. when
## testing boot scan enumeration behavior without content requirements).
@export var min_content_count: Dictionary = {
	"classes": 3,
	"enemies": 5,
	"biomes": 1,
	"dungeons": 1,
	"config": 1,
	# matchup intentionally absent — see doc-comment above; code-level per ADR-0009
}

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## Current lifecycle state. Read-only to external callers.
## Internal writes go through direct assignment in internal methods only —
## never assign from outside this script.
var state: State = State.UNLOADED

# ---------------------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------------------

## Per-category loaded resources, keyed by [code]resource.id[/code].
## Structure: [code]{ "classes": { "hero_warrior": <Resource>, ... }, ... }[/code]
##
## Populated by [method _load_category] during [method _boot_scan].
## Consumed by [method resolve] and [method get_all_by_type].
## All six ordered categories are pre-seeded as empty Dictionaries before the
## load walk begins — [method get_all_by_type] can return [code]Array[Resource]()[/code]
## instead of null for categories that contain zero loaded resources (e.g.
## [code]items/[/code] during MVP).
var _categories: Dictionary = {}

## Parallel to [member _categories] — tracks the file path for each loaded id
## within a category. Used by [method _find_path_for_id] to produce accurate
## duplicate-id diagnostic log messages per AC-DLS-03.
##
## Structure: [code]{ "classes": { "hero_warrior": "res://assets/data/classes/warrior.tres", ... }, ... }[/code]
##
## Stored here rather than on the [Resource] itself so Save/Load hydration
## (which restores by id alone) does not need path state.
var _category_paths: Dictionary = {}

# Compiled once in _ready before _boot_scan; reused across all resource inserts.
# Lazily initialized to null so a fresh DataRegistry.new() before _ready() fires
# does not crash on regex calls (they guard with null check).
var _snake_case_id_regex: RegEx = null

## Per-category property snapshots used by [method verify_integrity] to detect
## consumer mutation of resources returned by [method resolve] / [method get_all_by_type].
##
## Structure: [code]{ "classes": { "hero_warrior": { "display_name": "Warrior", ... } } }[/code]
##
## Populated for every loaded resource at the end of [method _ready] (post-boot)
## and at the end of a successful [method hot_reload] (for the reloaded category).
## Only populated under [code]OS.is_debug_build()[/code] — release builds carry
## no snapshot state to keep memory + boot cost zero.
##
## The snapshot stores values for properties whose [code]usage[/code] flags include
## [constant PROPERTY_USAGE_STORAGE], excluding the engine-owned object meta
## fields (`script`, `resource_local_to_scene`, `resource_path`, `resource_name`,
## `resource_scene_unique_id`).
var _integrity_snapshots: Dictionary = {}

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

## Zero-arg _init required by ADR-0003 Amendment #3.
## Godot autoload Nodes are instantiated with zero arguments by the engine;
## any required parameter on _init would silently fail instantiation (Claim 4
## [VERIFIED] in docs/engine-reference/godot/modules/autoload.md).
## Do NOT read or subscribe to other autoloads here — use _ready() instead.
func _init() -> void:
	pass


## Drives the UNLOADED → LOADING → READY | ERROR transition at boot.
##
## Sequence:
##   1. Set state = LOADING (synchronous, before any consumer _ready() runs
##      if rank order is correct — DataRegistry is rank 1 per ADR-0006).
##   2. Compile the snake_case id regex (ADR-0011) — once here, reused by all
##      [method _load_category] calls during the scan.
##   3. Delegate to _boot_scan() (body in Story 003; validators wired in Story 005).
##   4. On success: set state = READY, emit registry_ready.
##   5. On failure: _boot_scan() is responsible for calling
##      _transition_to_error(reason, details), which sets ERROR and emits
##      registry_error. Do NOT emit registry_ready after a failure.
func _ready() -> void:
	state = State.LOADING
	_snake_case_id_regex = RegEx.new()
	var compile_err: Error = _snake_case_id_regex.compile(_SNAKE_CASE_ID_PATTERN)
	assert(compile_err == OK, "DataRegistry: snake_case id regex failed to compile")
	if _boot_scan():
		state = State.READY
		# Snapshot all loaded resources for the read-only integrity check
		# (debug-only, ADR-0006 §Read-only contract; TR-data-loading-028).
		# Performed BEFORE registry_ready emits so the first consumer that resolves
		# a resource and stashes a reference cannot beat the snapshot.
		if OS.is_debug_build():
			for category: String in ORDERED_CATEGORIES:
				_snapshot_category_for_integrity_check(category)
		registry_ready.emit()
	# On failure, _boot_scan() calls _transition_to_error() — no action needed here.

# ---------------------------------------------------------------------------
# Public methods
# ---------------------------------------------------------------------------

# NOTE: Typed per-category accessors (get_all_classes, get_class_by_id,
# get_all_enemies, get_enemy_by_id, ...) are deferred to the per-DB consumer
# stories (HeroClassDatabase, EnemyDatabase, BiomeDungeonDatabase, ...) which
# wrap this registry.  Sprint 1 only ships the category-agnostic resolve() /
# get_all_by_type().  — Story S1-S2 decision.

## Resolves a content resource by its canonical id.
##
## Returns the cached [Resource] if the [param content_type] + [param id] pair
## exists in the loaded registry; returns [code]null[/code] on miss.
##
## ADR-0006: Silent substitution is forbidden. On miss the behavior depends on
## [member missing_id_behavior]:
##   [enum MissingIdBehavior.WARN]   — push_warning with a structured message; return null.
##   [enum MissingIdBehavior.ASSERT] — assert(false) with the id/content_type in the
##                                     message; return null if the assert is compiled
##                                     out in production.
##
## CALLER RESPONSIBILITY: callers (notably Save/Load) must apply their own
## fallback policy on null return.  This function does NOT substitute defaults.
##
## Returns [code]null[/code] if called before registry_ready has fired
## ([member state] != [enum State.READY]).
##
## The returned resource is the live cached instance — identity-equal across
## all calls for the same id.  Do NOT call [method Resource.duplicate] inside
## this function (ADR-0006 read-only contract; consumers that need mutable
## copies must duplicate themselves).
##
## Example:
##   [codeblock]
##   var hero_class: Resource = DataRegistry.resolve("classes", "hero_warrior")
##   if hero_class == null:
##       # apply fallback policy here
##       return
##   [/codeblock]
func resolve(content_type: String, id: String) -> Resource:
	if state != State.READY:
		_warn_not_ready("resolve", "content_type=%s id=%s" % [content_type, id])
		return null
	var category: Dictionary = _categories.get(content_type, {})
	if not category.has(id):
		_report_missing_id(content_type, id)
		return null
	return category[id]


## Returns an [Array][Resource] of all loaded resources of the given [param content_type].
##
## If [member state] != [enum State.READY], returns an empty array and logs a
## warning (ADR-0006 "Before registry_ready" semantics).
## If [param content_type] is unknown (not in [constant ORDERED_CATEGORIES] or not
## yet loaded), returns an empty array.
##
## Returned instances are the same cached objects returned by [method resolve] —
## identity-equal, NOT duplicates.  Consumers MUST NOT mutate [code]@export[/code]
## fields (ADR-0006 read-only contract).  Use [method Resource.duplicate] for
## mutable copies.
##
## Allocates a new Array on every call. Callers reading repeatedly (e.g. UI
## refresh, offline replay) MUST cache the returned array — do NOT call inside
## [code]_process[/code], resolve loops, or per-tick handlers.
##
## Example:
##   [codeblock]
##   var all_classes: Array[Resource] = DataRegistry.get_all_by_type("classes")
##   for cls in all_classes:
##       print(cls.id)
##   [/codeblock]
func get_all_by_type(content_type: String) -> Array[Resource]:
	if state != State.READY:
		_warn_not_ready("get_all_by_type", "content_type=%s" % content_type)
		return []
	var category: Dictionary = _categories.get(content_type, {})
	var out: Array[Resource] = []
	for id: String in category:
		out.append(category[id])
	return out


## Triggers a debug-only re-enumeration of assets/data/ for the given
## [param content_type]. No-ops in release builds and when state != READY.
##
## Preconditions enforced:
##   - [code]OS.is_debug_build()[/code] must be true (stripped from release exports
##     by the runtime gate, NOT a compile-time strip).
##   - [member state] must be [enum State.READY] (guards against re-entrant or
##     premature calls; non-READY callers receive a [code]push_warning[/code] and
##     no state change).
##
## On success the call walks [method _load_category] for the target [param content_type]
## only — no other category is touched. Cached resources for OTHER categories
## remain identity-equal across the call (Godot's [code]ResourceLoader[/code] cache
## is also unchanged for un-touched files). The integrity snapshot for the
## reloaded category is refreshed.
##
## State transitions: [enum State.READY] → [enum State.HOT_RELOAD] → [enum State.READY]
## (success) or [enum State.ERROR] (validator failure during reload — terminal).
##
## On failure (e.g. [code]_load_category[/code] reports a duplicate id, missing
## min count, etc.), [method _transition_to_error] has already moved state to
## [enum State.ERROR] and the [signal hot_reload_complete] signal is NOT emitted.
##
## Log format on success:
##   [code][DataRegistry] HOT RELOAD: classes — N resources re-registered in Mms[/code]
##
## Example:
##   [codeblock]
##   DataRegistry.hot_reload("classes")  # refreshes classes/*.tres in-editor
##   [/codeblock]
func hot_reload(content_type: String) -> void:
	if not OS.is_debug_build():
		return
	if state != State.READY:
		push_warning(
			"[DataRegistry] hot_reload requested while state=%s; ignoring"
			% _state_name(state)
		)
		return
	state = State.HOT_RELOAD
	var start_ms: int = Time.get_ticks_msec()
	# Wipe both the resource cache and the path-tracking dict for the target
	# category so _load_category re-walks the directory from a clean slate.
	# Other categories remain untouched — caller-held references to their
	# resources stay identity-equal across this call.
	_categories[content_type] = {}
	_category_paths[content_type] = {}
	if not _load_category(content_type):
		# _load_category already called _transition_to_error(); state is now ERROR
		# (terminal per ADR-0006). Do NOT emit hot_reload_complete in this branch.
		return
	state = State.READY
	# Refresh the integrity snapshot for the reloaded category — debug-only.
	# Other categories' snapshots are untouched and remain valid baselines.
	_snapshot_category_for_integrity_check(content_type)
	var loaded_count: int = _categories[content_type].size()
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	print(
		"[DataRegistry] HOT RELOAD: %s — %d resources re-registered in %dms"
		% [content_type, loaded_count, elapsed_ms]
	)
	hot_reload_complete.emit(content_type)


## Compares each loaded resource's storage-flagged property values against the
## baseline captured at boot (or after the most recent successful [method hot_reload]).
##
## Use in test builds to assert the read-only contract from ADR-0006: consumers
## that mutate a resource returned by [method resolve] or [method get_all_by_type]
## corrupt every cached holder of that same id (Godot's resource cache returns
## the same object). This helper surfaces such mutations as structured records.
##
## Returns an [Array][Dictionary] of mismatches; each element has shape:
##   [code]{ "content_type": String, "id": String, "property": String, "expected": Variant, "actual": Variant }[/code]
##
## Returns an empty array when:
##   - No mutation has occurred since the snapshot was taken, OR
##   - [code]OS.is_debug_build() == false[/code] (release builds carry no snapshot), OR
##   - No snapshot has been taken yet (e.g. called before [method _ready] completes).
##
## NOTE: Only properties with [constant PROPERTY_USAGE_STORAGE] are tracked, and
## the engine-owned object meta fields (`script`, `resource_local_to_scene`,
## `resource_path`, `resource_name`, `resource_scene_unique_id`) are excluded —
## the contract concerns authored content fields, not engine plumbing.
##
## Example (test):
##   [codeblock]
##   var dr: Node = _boot_registry()
##   var hero: Resource = dr.resolve("classes", "hero_warrior")
##   hero.display_name = "MUTATED"
##   var mismatches: Array[Dictionary] = dr.verify_integrity()
##   assert(mismatches.size() == 1 and mismatches[0]["property"] == "display_name")
##   [/codeblock]
func verify_integrity() -> Array[Dictionary]:
	var mismatches: Array[Dictionary] = []
	if not OS.is_debug_build():
		return mismatches
	if _integrity_snapshots.is_empty():
		return mismatches
	for content_type: String in _integrity_snapshots:
		var category_snapshot: Dictionary = _integrity_snapshots[content_type]
		var category: Dictionary = _categories.get(content_type, {})
		for id: String in category_snapshot:
			if not category.has(id):
				# Resource was removed since snapshot — surface as a mismatch with
				# property=null so callers can distinguish removal from mutation.
				mismatches.append({
					"content_type": content_type,
					"id": id,
					"property": "<removed>",
					"expected": "<present>",
					"actual": null,
				})
				continue
			var resource: Resource = category[id]
			var snapshot: Dictionary = category_snapshot[id]
			for prop_name: String in snapshot:
				var expected: Variant = snapshot[prop_name]
				var actual: Variant = resource.get(prop_name)
				if not _values_equal(expected, actual):
					mismatches.append({
						"content_type": content_type,
						"id": id,
						"property": prop_name,
						"expected": expected,
						"actual": actual,
					})
	return mismatches

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

## Boot scan entry point. Enumerates all [code].tres[/code] files under
## [member data_root_path] in [constant ORDERED_CATEGORIES] order and loads
## them synchronously into [member _categories].
##
## Sequence:
##   1. Pre-seed [member _categories] with empty Dictionaries for all six
##      categories so [method get_all_by_type] can return an empty
##      [code]Array[Resource][/code] rather than null.
##   2. Walk [constant ORDERED_CATEGORIES] in order, calling [method _load_category]
##      for each. Returns false immediately if any category fails to load (the
##      helper has already called [method _transition_to_error]).
##   3. DAG cross-ref validation (Story 006) and min_content_count checks
##      (Story 005) are NOT wired here — those stories add their gates after
##      this loop.
##
## Returns [code]true[/code] on success, [code]false[/code] if a fatal error
## occurred (caller must not emit [signal registry_ready]).
##
## Example (internal, called by _ready()):
##   [code]if _boot_scan(): state = State.READY[/code]
func _boot_scan() -> bool:
	# Pre-seed every ordered category so consumers never receive null from
	# get_all_by_type() for a category that simply has no content yet.
	# Also pre-seed the parallel path-tracking dict used by duplicate-id logs.
	for category: String in ORDERED_CATEGORIES:
		_categories[category] = {}
		_category_paths[category] = {}

	for category: String in ORDERED_CATEGORIES:
		if not _load_category(category):
			return false  # _load_category already called _transition_to_error
	# Story 006 — post-load DAG validation (TR-008 / TR-018 / AC-DLS-06).
	# Detects circular references in the dungeon ↔ biome graph after all
	# categories have loaded. On cycle detection: _validate_dag calls
	# _transition_to_error("CircularRef", {"cycle": [...]}) and returns false;
	# we propagate up so _ready() doesn't fire registry_ready.
	if not _validate_dag():
		return false
	return true


# Forward-compat (TR-data-loading-026): Godot's ResourceLoader silently ignores
# unknown fields and defaults missing fields when loading .tres files. No per-file
# version stamp is needed. This behavior is a property of Godot's resource loader,
# not explicit code here.

## Loads all [code].tres[/code] files from a single content category directory.
##
## [param category] must be one of the values in [constant ORDERED_CATEGORIES].
## The directory scanned is [code]{data_root_path}/{category}[/code].
##
## Validation pipeline applied to each file (ADR-0011 §Load-Time Validation Semantics):
##   1. Null return from [code]ResourceLoader.load[/code] → MALFORMED FILE warning; skip and continue.
##   2. Empty [code]id[/code] field → [code]InvalidId[/code] error; fail-fast.
##   3. Non-snake_case [code]id[/code] → [code]InvalidId[/code] error; fail-fast.
##   4. Duplicate [code]id[/code] within category → [code]DuplicateId[/code] error; first retained, fail-fast.
##   5. Per-type field validator hook ([method _validate_resource_fields]) — Sprint 1 no-op.
##
## After all files are walked, [method _validate_min_content_count] runs to enforce
## minimum required counts per [member min_content_count].
##
## Missing directory: treated as an empty category; [method _validate_min_content_count]
## still runs and may transition to ERROR if the minimum is above zero.
##
## Non-[code].tres[/code] files (e.g. [code].res[/code], [code].import[/code],
## [code].gd[/code]) are silently skipped. [code].res[/code] only ships as a
## [code].pck[/code] compression artifact per ADR-0006; it is not an authored
## format and must not be loaded here.
##
## Returns [code]true[/code] on success (including empty directory that meets
## min_content_count), [code]false[/code] on any fatal error.
##
## Example (internal, called by _boot_scan()):
##   [code]if not _load_category("classes"): return false[/code]
func _load_category(category: String) -> bool:
	var dir_path: String = "%s/%s" % [data_root_path, category]
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		# Missing directory is not itself fatal — min_content_count decides.
		push_warning("[DataRegistry] Category directory missing or unreadable: %s" % dir_path)
		return _validate_min_content_count(category)

	var file_names: PackedStringArray = DirAccess.get_files_at(dir_path)
	for file_name: String in file_names:
		# Skip non-.tres files.
		# .res only ships as a .pck artifact per ADR-0006; .tres is the only
		# authored content format.
		if not file_name.ends_with(".tres"):
			continue

		var full_path: String = "%s/%s" % [dir_path, file_name]

		# --- Step 1: null-skip (TR-017 / AC-DLS-05) ---
		var loaded: Resource = ResourceLoader.load(full_path)
		if loaded == null:
			push_warning(
				"[DataRegistry] MALFORMED FILE: %s — skipped. Reason: ResourceLoader returned null"
				% full_path
			)
			continue

		# --- Step 2 & 3: id non-empty + snake_case check (TR-005) ---
		var resource_id: String = _extract_resource_id(loaded)
		if resource_id.is_empty():
			_transition_to_error(ERROR_INVALID_ID, {
				"reason": "empty_id",
				"content_type": category,
				"path": full_path,
			})
			return false
		if _snake_case_id_regex.search(resource_id) == null:
			_transition_to_error(ERROR_INVALID_ID, {
				"reason": "not_snake_case",
				"content_type": category,
				"path": full_path,
				"id": resource_id,
			})
			return false

		# --- Step 4: duplicate-id detection (TR-016 / AC-DLS-03) — first retained ---
		if _categories[category].has(resource_id):
			var path_a: String = _find_path_for_id(category, resource_id)
			push_warning(
				"[DataRegistry] DUPLICATE ID: '%s' in %s — %s vs %s. Second file skipped."
				% [resource_id, category, path_a, full_path]
			)
			_transition_to_error(ERROR_DUPLICATE_ID, {
				"id": resource_id,
				"content_type": category,
				"paths": [path_a, full_path],
			})
			return false

		# --- Step 5: per-type field validator hook (ADR-0011 §Load-Time Validation) ---
		# Sprint 1 ships this as a no-op. Concrete validators slot in here via
		# subclass override of _validate_resource_fields() — see that method.
		var field_error: String = _validate_resource_fields(category, loaded)
		if not field_error.is_empty():
			_transition_to_error(ERROR_INVALID_FIELD, {
				"content_type": category,
				"path": full_path,
				"id": resource_id,
				"reason": field_error,
			})
			return false

		# --- Insert: record resource + path ---
		_categories[category][resource_id] = loaded
		_category_paths[category][resource_id] = full_path

	return _validate_min_content_count(category)


## Extracts the [code]id[/code] field from a loaded [Resource].
##
## All content resources are expected to extend [GameData], which declares
## [code]id: String[/code]. For safety — test fixtures or mis-authored resources
## that do not extend [GameData] — this method falls back to an empty string
## rather than crashing. The [code]InvalidId[/code] validator in
## [method _load_category] catches the empty-id case downstream.
##
## [param res]: The loaded resource to inspect.
## Returns the [code]id[/code] string, or [code]""[/code] if not present.
func _extract_resource_id(res: Resource) -> String:
	if "id" in res:
		return res.id
	return ""


## Validates that a loaded category meets the minimum content count threshold.
##
## Called at the end of [method _load_category] after all files in the directory
## have been walked. If the loaded count is below [member min_content_count]
## for this [param category], transitions to ERROR via [method _transition_to_error]
## and returns [code]false[/code].
##
## Categories absent from [member min_content_count] (e.g. [code]items[/code] in
## the MVP default) default to a required count of 0, so they never trigger ERROR
## from this check alone.
##
## [param category]: The category name (one of [constant ORDERED_CATEGORIES]).
## Returns [code]true[/code] if the count meets the requirement; [code]false[/code]
## if the ERROR transition was triggered.
##
## Example (internal, called by _load_category()):
##   [code]return _validate_min_content_count("classes")[/code]
func _validate_min_content_count(category: String) -> bool:
	var loaded_count: int = _categories[category].size()
	var required: int = int(min_content_count.get(category, 0))
	if loaded_count < required:
		_transition_to_error(ERROR_MIN_CONTENT_COUNT, {
			"content_type": category,
			"loaded": loaded_count,
			"required": required,
		})
		return false
	return true


## Emits a structured "called before READY" warning for public accessors.
##
## Callers (resolve, get_all_by_type) pass the method name and a caller-specific
## context suffix. Extracted to avoid drift between the two accessors' messages.
func _warn_not_ready(method_name: String, context: String) -> void:
	push_warning("[DataRegistry] %s called before registry_ready: %s" % [method_name, context])


## Best-effort lookup of the file path for an already-loaded resource id.
##
## Used by [method _load_category] to include the first file's path in the
## duplicate-id diagnostic log (AC-DLS-03 exact format). Returns [code]""[/code]
## if the path is not found in [member _category_paths] — callers must treat
## the empty string as a safe advisory value rather than a hard error.
##
## [param category]: The category to search within.
## [param resource_id]: The id whose path to retrieve.
## Returns the stored file path string, or [code]""[/code] if unavailable.
func _find_path_for_id(category: String, resource_id: String) -> String:
	if _category_paths.has(category) and _category_paths[category].has(resource_id):
		return _category_paths[category][resource_id]
	return ""


## Per-type field validator hook — override in a concrete [DataRegistry] subclass
## (or splice via a callable table) when [HeroClass] / [EnemyData] / [Biome] /
## [Dungeon] / [Floor] concrete subclasses land under Core DB epics.
##
## Sprint 1 ships this as a no-op that always returns [code]""[/code].
## [method _load_category] calls this after id validation and before insertion.
## A non-empty return value causes [method _load_category] to call
## [method _transition_to_error] with [code]reason = "InvalidField"[/code] and
## the returned string in [code]details.reason[/code].
##
## Expected future overrides per ADR-0011 §Load-Time Validation Semantics:
##   - [code]classes[/code]: validate [code]role[/code] in [code]ClassRoles.ALL_SET[/code],
##     [code]counter_archetype[/code] in [code]EnemyArchetypes.ALL_SET[/code].
##   - [code]enemies[/code]: validate [code]archetype[/code] in [code]EnemyArchetypes.ALL_SET[/code].
##   - [code]biomes[/code]: validate [code]status[/code] in [code]{"active", "planned_v1"}[/code].
##
## [param category]: The content category being validated.
## [param resource]: The loaded resource instance to validate.
## Returns [code]""[/code] on pass; a non-empty error reason string on fail.
func _validate_resource_fields(_category: String, _resource: Resource) -> String:
	return ""


## Reports a missing-id lookup according to [member missing_id_behavior].
##
## Exact log format per AC-DLS-04:
##   [code][DataRegistry] MISSING REF: <content_type> id='<id>' — no resource registered[/code]
##
## [enum MissingIdBehavior.WARN]   — push_warning with the above message.
## [enum MissingIdBehavior.ASSERT] — assert(false, ...) fires in debug/test builds.
##   In production (assert compiled out), execution falls through and the caller
##   receives null from [method resolve] on the next statement.
##
## [param content_type]: The category that was queried.
## [param id]: The id that was not found.
func _report_missing_id(content_type: String, id: String) -> void:
	var msg: String = (
		"[DataRegistry] MISSING REF: %s id='%s' — no resource registered"
		% [content_type, id]
	)
	match missing_id_behavior:
		MissingIdBehavior.WARN:
			push_warning(msg)
		MissingIdBehavior.ASSERT:
			assert(false, msg)


## Transitions to the terminal ERROR state and emits [signal registry_error].
##
## Guards against re-entry: if state is already ERROR, this is a no-op
## (ERROR is terminal — no transition out per ADR-0006).
##
## Called by [method _load_category] failure paths (Story 005) and will be
## called by DAG validation failure paths (Story 006). May also be called
## directly in tests to exercise the ERROR path without subclassing.
##
## [param reason]: A non-empty error category string. Story 005 values:
##   [code]"InvalidId"[/code], [code]"DuplicateId"[/code],
##   [code]"MinContentCount"[/code], [code]"InvalidField"[/code].
## [param details]: Structured diagnostic data (path, id, counts, etc.).
func _transition_to_error(reason: String, details: Dictionary) -> void:
	if state == State.ERROR:
		return
	state = State.ERROR
	registry_error.emit(reason, details)


## Set of property names skipped by [method _snapshot_category_for_integrity_check].
##
## These are engine-owned [Resource] / [Object] fields that are NOT authored
## content; tracking them would produce false positives whenever Godot writes
## an internal id (e.g. resource_path on save) or re-anchors a sub-resource.
## ADR-0006's read-only contract concerns @export-style content fields only.
const _SNAPSHOT_SKIP_PROPS: Array[String] = [
	"script",
	"resource_local_to_scene",
	"resource_path",
	"resource_name",
	"resource_scene_unique_id",
]


## Captures a property snapshot for every resource currently loaded under
## [param content_type] and stores it in [member _integrity_snapshots].
##
## Snapshots only properties whose [code]usage[/code] flags include
## [constant PROPERTY_USAGE_STORAGE], skipping the engine-owned meta fields
## listed in [constant _SNAPSHOT_SKIP_PROPS].
##
## No-ops in release builds — the read-only contract enforcement is debug-only
## per ADR-0006 (defensive [code].duplicate()[/code] per-read would burn budget
## and defeat the cache).
##
## [param content_type]: One of [constant ORDERED_CATEGORIES]. Categories absent
##   from [member _categories] are silently skipped.
func _snapshot_category_for_integrity_check(content_type: String) -> void:
	if not OS.is_debug_build():
		return
	if not _categories.has(content_type):
		return
	var category: Dictionary = _categories[content_type]
	var category_snapshot: Dictionary = {}
	for id: String in category:
		var resource: Resource = category[id]
		if resource == null:
			continue
		var resource_snapshot: Dictionary = {}
		for prop_info: Dictionary in resource.get_property_list():
			var usage: int = int(prop_info.get("usage", 0))
			if usage & PROPERTY_USAGE_STORAGE == 0:
				continue
			var prop_name: String = String(prop_info.get("name", ""))
			if prop_name.is_empty():
				continue
			if _SNAPSHOT_SKIP_PROPS.has(prop_name):
				continue
			resource_snapshot[prop_name] = resource.get(prop_name)
		category_snapshot[id] = resource_snapshot
	_integrity_snapshots[content_type] = category_snapshot


## Maps a [enum State] enum value to its readable name for log messages.
##
## Kept private to avoid exposing a stringly-typed surface; callers that need
## state introspection should compare against the [enum State] constants directly.
func _state_name(value: int) -> String:
	match value:
		State.UNLOADED:
			return "UNLOADED"
		State.LOADING:
			return "LOADING"
		State.READY:
			return "READY"
		State.ERROR:
			return "ERROR"
		State.HOT_RELOAD:
			return "HOT_RELOAD"
		_:
			return "UNKNOWN(%d)" % value


## Variant-aware equality for snapshot comparison.
##
## [code]==[/code] on Object/Resource compares object identity, which would
## report false-mismatch when the snapshot stored a primitive value but the
## resource still holds the same primitive. For primitives, container types
## (Array, Dictionary, PackedArrays), and Strings, [code]==[/code] is value-based
## and works correctly. For Resource references, identity equality is the
## semantically-correct comparison (mutating a Resource property to point at a
## different Resource IS a mismatch the test should catch).
func _values_equal(a: Variant, b: Variant) -> bool:
	return a == b


# ---------------------------------------------------------------------------
# Story 006 — DAG validation
# ---------------------------------------------------------------------------

## Story 006 (TR-008 / TR-018 / AC-DLS-06) — post-load DAG validation.
##
## BFS/DFS-traverses the in-memory dungeon ↔ biome graph after all categories
## have loaded. Edges:
##   - [code]Dungeon.biome_id (String)[/code] → Biome (id-string ref).
##   - [code]Biome.dungeons (Array[Dungeon])[/code] → Dungeon[] (embedded refs).
##
## On cycle detection: transitions to ERROR via [method _transition_to_error]
## with reason [constant ERROR_CIRCULAR_REF] and details payload
## [code]{"cycle": Array[String]}[/code] where the cycle path is repeated
## tail-to-head (e.g. [code]["dungeon_a", "biome_b", "dungeon_a"][/code]).
## Also pushes the canonical [code][DataRegistry] CIRCULAR REF: a → b → a[/code]
## log line for QA / playtest visibility.
##
## Acyclic graphs are silent passes. Returns [code]true[/code] on no-cycle,
## [code]false[/code] when a cycle was detected (caller must NOT emit
## [signal registry_ready] in that branch).
##
## Defensive: an empty `dungeons` or `biomes` category short-circuits to
## [code]true[/code] (no graph to traverse).
##
## Cross-type invariants (boss-uniqueness, archetype-distribution, etc. per
## ADR-0011) are out of scope for this method's TR-008/018 closure — those
## land alongside their respective per-type validators in the Implementation
## Notes section of the story file. This method covers the DAG cycle detection
## piece only.
##
## ADR-0006 §DAG validation, TR-data-loading-008, TR-data-loading-018, AC-DLS-06.
func _validate_dag() -> bool:
	var dungeons: Dictionary = _categories.get("dungeons", {})
	var biomes: Dictionary = _categories.get("biomes", {})
	if dungeons.is_empty() and biomes.is_empty():
		return true  # No graph to walk.

	# Iterate every dungeon as a potential cycle entry point. Reusing visited
	# state across roots is unsafe — a cycle entered from a different root
	# might be missed if the closing node was marked "fully done" earlier.
	# The per-root walk is bounded by the graph size so total cost stays O(N).
	for dungeon_id: String in dungeons:
		var path: Array = []
		var on_path: Dictionary = {}
		if _walk_for_cycle(dungeon_id, "dungeons", path, on_path):
			# _walk_for_cycle already populated the cycle path.
			var typed_path: Array[String] = []
			for v: Variant in path:
				typed_path.append(str(v))
			_transition_to_error(ERROR_CIRCULAR_REF, {"cycle": typed_path})
			push_error(
				"[DataRegistry] CIRCULAR REF: %s" % " → ".join(typed_path)
			)
			return false
	return true


## Story 006 — recursive DFS helper for [method _validate_dag].
##
## Walks edges from [param node_id] of [param node_type] (one of
## [code]"dungeons"[/code] or [code]"biomes"[/code]). Maintains [param path]
## as the current visit chain and [param on_path] as the on-stack set. When
## an on-stack node is re-entered, the cycle is detected: [param path] is
## extended with the closing-node id and the function returns [code]true[/code].
##
## On a non-cycle return, the node is popped from both [param path] and
## [param on_path] so subsequent root walks see a clean state.
##
## [param node_id]: id of the current node.
## [param node_type]: one of [code]"dungeons"[/code] or [code]"biomes"[/code].
## [param path]: in-out; the current visit chain. Caller passes [code][][/code]
##   on first call.
## [param on_path]: in-out; set of [code]node_type:node_id[/code] keys
##   currently on the visit stack. Caller passes [code]{}[/code] on first call.
##
## Returns [code]true[/code] when a cycle was detected (path is populated
## with the offending sequence repeated tail-to-head); [code]false[/code]
## on a clean walk.
func _walk_for_cycle(
	node_id: String, node_type: String, path: Array, on_path: Dictionary
) -> bool:
	var key: String = "%s:%s" % [node_type, node_id]
	if on_path.has(key):
		# Cycle detected. Append the closing id so the path reads
		# "a → b → a" tail-to-head per AC-DLS-06.
		path.append(node_id)
		return true
	on_path[key] = true
	path.append(node_id)

	var category: Dictionary = _categories.get(node_type, {})
	var resource: Resource = category.get(node_id, null)
	if resource == null:
		# Unresolvable — treat as leaf for DAG purposes (no edges to walk).
		# UnresolvableCrossRef detection lives in the cross-type validator
		# story (out of scope here per the story spec).
		on_path.erase(key)
		path.pop_back()
		return false

	# Walk edges based on node type. Only the dungeon ↔ biome edges are checked
	# for MVP; other cross-refs (Floor.enemy_list[].enemy_id → EnemyData)
	# are non-cycling by construction (enemies have no back-refs to floors).
	if node_type == "dungeons":
		# Edge: Dungeon.biome_id (String) → Biome
		if "biome_id" in resource:
			var biome_id: String = str(resource.get("biome_id"))
			if not biome_id.is_empty():
				if _walk_for_cycle(biome_id, "biomes", path, on_path):
					return true
	elif node_type == "biomes":
		# Edge: Biome.dungeons (Array[Dungeon]) → Dungeon[] (embedded refs).
		#
		# IMPORTANT: skip the CANONICAL parent-child embedding (a biome embedding
		# a dungeon whose biome_id points BACK to this same biome). That's the
		# standard authoring pattern in `assets/data/`, not a cycle. The
		# cycle-check follows ONLY non-canonical embeddings — i.e. a biome that
		# embeds a dungeon belonging to a DIFFERENT biome (which would be a
		# malformed authoring pattern indicating a real cross-link cycle).
		if "dungeons" in resource:
			var dungeons_in: Variant = resource.get("dungeons")
			if dungeons_in is Array:
				for d: Variant in (dungeons_in as Array):
					if d == null:
						continue
					if not (d is Resource) or not ("id" in d):
						continue
					var d_id: String = str(d.get("id"))
					if d_id.is_empty():
						continue
					# Canonical parent-child skip: a biome embedding a dungeon
					# that points BACK at this biome via biome_id is the
					# standard pattern; the cycle is structural, not logical.
					if "biome_id" in d:
						var d_biome_id: String = str(d.get("biome_id"))
						if d_biome_id == node_id:
							continue
					if _walk_for_cycle(d_id, "dungeons", path, on_path):
						return true

	on_path.erase(key)
	path.pop_back()
	return false
