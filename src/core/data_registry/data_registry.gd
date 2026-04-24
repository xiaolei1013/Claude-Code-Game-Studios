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

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Deterministic content category load order per ADR-0006.
##
## Adding a new category requires an explicit edit HERE plus a corresponding
## edit to [member min_content_count] — auto-discovery from directory presence
## is FORBIDDEN per ADR-0006.
##
## Order matters: [code]classes → enemies → biomes → dungeons → items → matchup[/code].
## Story 006 adds DAG cycle-detection on top of this fixed order.
const ORDERED_CATEGORIES: Array[String] = [
	"classes", "enemies", "biomes", "dungeons", "items", "matchup",
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
## Override in dev/test via:
##   [code]registry.min_content_count = {"classes": 1, "enemies": 1}[/code]
## Set to [code]{}[/code] to disable all minimum-count enforcement (e.g. when
## testing boot scan enumeration behavior without content requirements).
@export var min_content_count: Dictionary = {
	"classes": 3,
	"enemies": 5,
	"biomes": 1,
	"dungeons": 1,
	"matchup": 1,
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
##   - OS.is_debug_build() must be true (stripped from release exports)
##   - state must be READY (guards against re-entrant or premature calls)
##
## The full re-enumeration body and hot_reload_complete emission are pending —
## this stub exists to lock the precondition contract and signal declaration.
##
## Example:
##   DataRegistry.hot_reload("heroes")  # refreshes hero .tres files in-editor
func hot_reload(_content_type: String) -> void:
	if not OS.is_debug_build():
		return
	if state != State.READY:
		return

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
	# DAG validation (Story 006) is not wired here — that story adds its gates.
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
