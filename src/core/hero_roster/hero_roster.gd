extends Node

## Preloaded HeroInstance script — used to construct new instances inside
## [method add_hero] without depending on the [code]class_name HeroInstance[/code]
## global registry being resolved at autoload parse time (same defensive
## pattern as the Resource-typed [member _config] field — Sprint 6 lesson).
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

## HeroRoster — rank-7 Feature autoload owning every recruited hero's instance state.
##
## NOTE: No `class_name` — autoload scripts cannot declare `class_name`
## when the autoload name matches the class, or Godot raises
## "Class X hides an autoload singleton" (Sprint 1 lesson). The autoload is
## globally accessible as `HeroRoster`; tests that need a fresh instance use
## `preload("res://src/core/hero_roster/hero_roster.gd").new()`.
##
## Owns:
## - `_heroes`: typed Dictionary keyed by instance_id (int) → HeroInstance
## - `_formation_slots`: Array[int] of size FORMATION_SIZE; 0 = empty slot
## - `_next_instance_id`: monotonic positive int; never reused after remove
## - `_orphaned_heroes`: session-only list of heroes with unresolvable class_ids
##   (populated by Story 007 boot validation; non-blocking notice to player)
##
## Mutation policy: ALL mutation flows through HeroRoster public methods
## (Story 004 add_hero/remove_hero, Story 005 set_hero_level/set_formation_slot).
## HeroInstance has no setter API. Three signals (`hero_recruited`,
## `hero_leveled`, `hero_removed`) are the only feedback channel — subscribers
## (HUD, Recruitment, Economy) react via signal connections, never poll _heroes.
##
## ADR-0012: Hero Roster Mutation + Identity (instance_id immutable; signal-driven)
## ADR-0003: Autoload Rank Table (rank 7; zero-arg _init invariant)
## ADR-0003 Amendment #1: signal SUBSCRIPTION across any rank pair at _ready() is safe
## ADR-0003 Amendment #3 Claim 4 [VERIFIED]: autoload _init MUST have zero required params
## ADR-0004: Save Envelope (HeroRoster is item #1 in CONSUMER_PATHS, after Economy at #0;
##   wired in Story 006)


# ---------------------------------------------------------------------------
# Config-loader fallback defaults (TR-hero-roster-030 exception path).
#
# These values are used ONLY if `assets/data/config/roster_config.tres` fails
# to resolve at boot OR fails `_validate()`. The runtime preference order is:
#     1. RosterConfig field values (loaded via DataRegistry — Story 003)
#     2. The fallbacks below (boot-safe degrade — push_error logged)
#
# TR-hero-roster-030 explicitly permits the config-loader path to reference
# default literals; production paths read via accessors `max_roster_size()`,
# `formation_size()`, `level_cap()` rather than touching these directly.
# ---------------------------------------------------------------------------

const _FALLBACK_MAX_ROSTER_SIZE: int = 30
const _FALLBACK_FORMATION_SIZE: int = 3
const _FALLBACK_LEVEL_CAP: int = 15

const _CONFIG_CATEGORY: String = "config"
const _CONFIG_ID: String = "roster_config"


# ---------------------------------------------------------------------------
# First-launch seed constants (Story 008 / S8-S5 — TR-hero-roster-020/021).
#
# Hardcoded — NOT drawn from the random name pool — so reinstalls are
# deterministic for QA reproducibility per TR-021. The seed name "Theron"
# is the canonical first-hero identity per the hero-roster GDD §First-Launch.
# ---------------------------------------------------------------------------

const SEED_HERO_CLASS_ID: String = "warrior"
const SEED_HERO_NAME: String = "Theron"
const SEED_HERO_INSTANCE_ID: int = 1
const SEED_FORMATION_SLOT: int = 0


# ---------------------------------------------------------------------------
# Private state — underscore-prefix encapsulation enforced at code review
# (TR-hero-roster-028). Public read access via getters in Stories 004/010;
# direct mutation FORBIDDEN per ADR-0012.
# ---------------------------------------------------------------------------

## Map of instance_id (int) → HeroInstance. Populated by add_hero (Story 004);
## drained by remove_hero (Story 004) and load_save_data validation (Story 007).
## Default empty Dictionary at boot — no auto-seeding here (first-launch seed
## is Story 008's separate code path called by SaveLoadSystem when no save exists).
##
## TR-hero-roster-005 — ADR-0012
var _heroes: Dictionary = {}

## Active formation slots. Size is set to [method formation_size] at boot
## (post-config-load) — initialised empty here and resized in [method _ready]
## once `roster_config.tres` resolves. Each element is a hero instance_id
## (int) or 0 (empty slot). Mutation via Story 005's set_formation_slot —
## never directly indexed-write from outside.
##
## Note: typed `Array[int]` works in Godot 4.6 and locks the element type.
##
## TR-hero-roster-007 — ADR-0012
var _formation_slots: Array[int] = []

## Monotonic positive int. Story 004's add_hero increments AFTER successful
## add; never decremented; never reused after remove. Cross-session stable
## via save round-trip (Story 006 persists this in the save dict).
##
## TR-hero-roster-011 — ADR-0012
var _next_instance_id: int = 1

## Session-only list of HeroInstance objects whose class_id failed to resolve
## via DataRegistry.resolve("classes", class_id) at load time. Populated by
## Story 007 boot validation; SaveLoadSystem fires a single non-blocking
## notice signal when this list is non-empty post-load. Never persisted.
##
## TR-hero-roster-016 — ADR-0012
var _orphaned_heroes: Array = []

## Resolved RosterConfig instance (loaded in [method _ready] from
## `res://assets/data/config/roster_config.tres` via [DataRegistry]).
## When [code]null[/code] (config missing or invalid), the [method max_roster_size],
## [method formation_size], and [method level_cap] accessors fall back to the
## `_FALLBACK_*` constants and push_error has been logged at boot.
##
## NOTE: typed as [Resource] (not [code]RosterConfig[/code]) as a defensive
## guard against a stale `.godot/global_script_class_cache.cfg` on a fresh
## checkout: when [code]roster_config.gd[/code] is added to the project but
## the editor has not yet rebuilt the cache, an autoload that references the
## class_name at parse time fails to boot. Economy uses a directly-typed
## [code]EconomyConfig[/code] field (and works) because its config script
## predates this autoload's first registration. Duck-typed access via
## [code]"field_name" in _config[/code] and [code]_config.get("field_name")[/code]
## in the accessors below sidesteps the cache dependency entirely.
## A future cleanup could replace this with [code]const RosterConfigScript = preload(...)[/code]
## at the top of this file to get compile-time type safety on the field.
##
## TR-hero-roster-006, TR-hero-roster-030 — ADR-0011, ADR-0012
var _config: Resource = null

## When [code]true[/code], the three mutation signals
## ([signal hero_recruited], [signal hero_leveled], [signal hero_removed])
## are NOT emitted. Set to [code]true[/code] for the duration of
## [method load_save_data] (and the Story 007 boot validation pass that
## follows it) so bulk hydration does not trigger HUD updates / sound effects
## mid-load. Always paired with a corresponding [code]false[/code] write at
## the end of the protected section.
##
## CONVENTION: All future emit sites in HeroRoster MUST guard with
## [code]if not _suppress_signals[/code] before emitting. Add the guard
## alongside the emit when introducing any new mutation signal — the
## suppression contract is enforced site-by-site, not by a wrapper helper.
##
## TR-hero-roster-010 — ADR-0004, ADR-0012
var _suppress_signals: bool = false


# ---------------------------------------------------------------------------
# Signals — the only feedback channel for roster mutations. Subscribers
# (HUD, Recruitment, Economy) connect at their own _ready() and react via
# signal handlers; no polling of _heroes from outside HeroRoster is permitted.
#
# TR-hero-roster-009 — ADR-0012
# ---------------------------------------------------------------------------

## Emitted by add_hero (Story 004) when a new hero is successfully recruited.
## [param instance] is the freshly-created HeroInstance with all fields set.
## NOTE: typed as RefCounted (not HeroInstance) at the signal-declaration level
## because the HeroInstance class_name registry may not be fully resolved when
## the autoload script parses at boot. Subscribers can cast to HeroInstance at
## handler time. Same pattern as Sprint 5 SceneManager signal declarations.
signal hero_recruited(instance: RefCounted)

## Emitted by set_hero_level (Story 005) when a hero's level changes via
## any code path (recruit, gold-spend level-up, save-load hydration when
## signals are NOT suppressed). [param old_level] is the level before the
## mutation; [param new_level] is the post-clamp result.
signal hero_leveled(instance_id: int, old_level: int, new_level: int)

## Emitted by remove_hero (Story 004) just before the HeroInstance is dropped
## from _heroes. [param class_id] and [param display_name] are captured pre-drop
## so subscribers (e.g., HUD's "X retired" notification) can show context after
## the instance reference is gone.
signal hero_removed(instance_id: int, class_id: String, display_name: String)

## Sprint 8 S8-S4 (Story 007 — TR-016): non-blocking notice fired ONCE after
## boot validation when [member _orphaned_heroes] is non-empty. Subscribers
## (HUD) display "N heroes from a previous version are no longer playable."
## Emitted post-suppression (after [code]_suppress_signals[/code] returns to
## false) so the load path itself remains signal-quiet.
signal orphan_heroes_notice(count: int)


# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

## Zero-arg _init required by ADR-0003 Amendment #3:
## Godot autoload Nodes cannot receive constructor arguments at runtime.
## Claim 4 [VERIFIED] — autoload.md (2026-04-22).
func _init() -> void:
	pass


## Resolves [member _config] from DataRegistry and sizes [member _formation_slots]
## from the loaded value. On miss or `_validate()` failure, logs push_error and
## continues with the `_FALLBACK_*` constants — the autoload still boots.
##
## Rank-7 safety (ADR-0003 Amendment #1): DataRegistry (rank 5) has completed
## its _ready() boot scan by the time this fires, so `resolve()` is safe.
##
## Story 006 will additionally connect SaveLoadSystem signals here.
##
## ADR-0003 Amendment #1, ADR-0011, ADR-0012, ADR-0013
func _ready() -> void:
	_load_config()
	_resize_formation_slots()


## Loads roster_config.tres via DataRegistry and validates it. On any failure,
## leaves [member _config] as null so accessors fall back to defaults.
##
## Duck-typed: checks for the three required fields rather than referencing
## the [code]RosterConfig[/code] class_name (parse-order safety).
##
## TR-hero-roster-006, TR-hero-roster-030
func _load_config() -> void:
	var resolved: Resource = DataRegistry.resolve(_CONFIG_CATEGORY, _CONFIG_ID)
	_apply_resolved_config(resolved)


## Validates [param resolved] against the RosterConfig schema and applies it
## to [member _config] on success. Returns [code]true[/code] on accept,
## [code]false[/code] on any of the four defensive branches:
##   1. [param resolved] is null → push_error + reject (DataRegistry miss path)
##   2. Duck-type schema field check fails → push_error + reject (wrong type
##      registered under the config/roster_config key)
##   3. Per-resource [code]_validate()[/code] returns non-empty errors →
##      push_error + reject (ADR-0011)
##   4. Resource has no [code]_validate[/code] method → ACCEPT (defensive
##      tolerance — non-Resource configs that pre-date ADR-0011 still load)
##
## Extracted from [method _load_config] specifically so unit tests can drive
## each branch directly with a constructed mock Resource — without going
## through the live DataRegistry singleton (whose state is hard to control
## from a fresh test instance per TD-009 resolution path).
##
## TR-hero-roster-006, TR-hero-roster-030 — TD-009 closure (S8-S8)
func _apply_resolved_config(resolved: Resource) -> bool:
	if resolved == null:
		push_error(
			("[HeroRoster] failed to resolve RosterConfig from DataRegistry "
			+ "(category='%s', id='%s'). Falling back to safe defaults "
			+ "(max_roster_size=%d, formation_size=%d, level_cap=%d).")
			% [_CONFIG_CATEGORY, _CONFIG_ID,
				_FALLBACK_MAX_ROSTER_SIZE, _FALLBACK_FORMATION_SIZE, _FALLBACK_LEVEL_CAP]
		)
		return false
	# Duck-type schema check — avoids referencing class_name RosterConfig at parse time.
	if not ("max_roster_size" in resolved and "formation_size" in resolved and "level_cap" in resolved):
		push_error(
			("[HeroRoster] resolved resource at '%s/%s' is missing RosterConfig "
			+ "schema fields. Falling back to safe defaults.")
			% [_CONFIG_CATEGORY, _CONFIG_ID]
		)
		return false
	# Per-resource _validate() per ADR-0011 — duck-typed call.
	if resolved.has_method("_validate"):
		var errors: Array = resolved.call("_validate")
		if not errors.is_empty():
			push_error(
				("[HeroRoster] RosterConfig validation failed: %s. "
				+ "Falling back to safe defaults.")
				% ", ".join(errors)
			)
			return false
	_config = resolved
	return true


## Sizes [member _formation_slots] to [method formation_size] entries (all 0).
## Called once in [method _ready] after [member _config] is resolved (or after
## fallback defaults are accepted). [code]Array[int].resize()[/code] zero-fills
## new entries automatically — no explicit loop needed.
func _resize_formation_slots() -> void:
	_formation_slots.clear()
	_formation_slots.resize(formation_size())


# ---------------------------------------------------------------------------
# Public config accessors — read tuning knobs from the loaded RosterConfig
# (or `_FALLBACK_*` constants on config miss). Production paths call these
# rather than touching the constants directly.
#
# TR-hero-roster-006, TR-hero-roster-030 — ADR-0012
# ---------------------------------------------------------------------------

## Maximum number of heroes the player may keep recruited at once.
## From `roster_config.tres` (default 30), with [code]_FALLBACK_MAX_ROSTER_SIZE[/code]
## fallback when config failed to load.
func max_roster_size() -> int:
	if _config != null and "max_roster_size" in _config:
		return _config.get("max_roster_size") as int
	return _FALLBACK_MAX_ROSTER_SIZE


## Number of slots in the active formation.
## From `roster_config.tres` (default 3), with [code]_FALLBACK_FORMATION_SIZE[/code]
## fallback when config failed to load.
func formation_size() -> int:
	if _config != null and "formation_size" in _config:
		return _config.get("formation_size") as int
	return _FALLBACK_FORMATION_SIZE


## Maximum hero level reachable in MVP.
## From `roster_config.tres` (default 15), with [code]_FALLBACK_LEVEL_CAP[/code]
## fallback when config failed to load.
func level_cap() -> int:
	if _config != null and "level_cap" in _config:
		return _config.get("level_cap") as int
	return _FALLBACK_LEVEL_CAP


# ---------------------------------------------------------------------------
# Public mutation API — Story 004 (TR-008, TR-009)
#
# All roster mutations flow through these methods (ADR-0012). Signals are the
# only mutation-feedback channel. Subscribers react via signal connections
# — direct polling of [member _heroes] from outside HeroRoster is forbidden.
# ---------------------------------------------------------------------------

## Recruits a new hero of the given [param class_id] and returns the created
## [HeroInstance], or [code]null[/code] when the recruit cannot proceed.
##
## Failure modes (each logs [method push_warning] and returns null without
## mutating state — atomic):
##   1. Roster is at cap: [code]_heroes.size() >= max_roster_size()[/code]
##   2. [param class_id] does not resolve via [code]DataRegistry.resolve("classes", class_id)[/code]
##
## Success path:
##   1. Construct [HeroInstance] with id [member _next_instance_id]
##   2. Set [code]class_id[/code], placeholder [code]display_name[/code]
##      (Story 009 will replace with name-pool generation), level=1, xp=0
##   3. Insert into [member _heroes] keyed by [member instance_id]
##   4. Increment [member _next_instance_id] AFTER success (TR-011: failed
##      adds must NOT consume an id)
##   5. Emit [signal hero_recruited] with the new instance exactly once
##
## TR-hero-roster-008, TR-hero-roster-009, TR-hero-roster-011 — ADR-0012
func add_hero(class_id: String) -> RefCounted:
	if _heroes.size() >= max_roster_size():
		push_warning(
			"[HeroRoster] add_hero: roster at cap (%d); cannot recruit '%s'"
			% [max_roster_size(), class_id]
		)
		return null
	var class_data: Resource = DataRegistry.resolve("classes", class_id)
	if class_data == null:
		push_warning(
			"[HeroRoster] add_hero: unresolvable class_id '%s' — DataRegistry returned null"
			% class_id
		)
		return null
	var instance: RefCounted = HeroInstanceScript.new()
	instance.instance_id = _next_instance_id
	instance.class_id = class_id
	instance.display_name = _generate_name(class_id, _next_instance_id)
	instance.current_level = 1
	instance.xp = 0
	_heroes[_next_instance_id] = instance
	_next_instance_id += 1  # AFTER success — TR-011
	if not _suppress_signals:
		hero_recruited.emit(instance)
	return instance


## Removes the hero with [param id] from the roster and clears any formation
## slot that referenced it. Returns [code]true[/code] on success, [code]false[/code]
## when [param id] is unknown (push_warning logged; no mutation).
##
## On success, emits [signal hero_removed] with [code](id, class_id, display_name)[/code]
## captured BEFORE the instance is dropped — subscribers can show context after
## the reference is gone.
##
## NOTE: [member _next_instance_id] is NOT decremented (TR-011: ids are
## monotonic; removed ids are never reused).
##
## TR-hero-roster-008, TR-hero-roster-009 — ADR-0012
func remove_hero(id: int) -> bool:
	if not _heroes.has(id):
		push_warning("[HeroRoster] remove_hero: unknown id %d" % id)
		return false
	var instance: RefCounted = _heroes[id]
	# Capture pre-drop for the signal payload.
	var class_id: String = instance.class_id
	var display_name: String = instance.display_name
	_heroes.erase(id)
	# Clear any formation slot that referenced this id.
	for i: int in range(_formation_slots.size()):
		if _formation_slots[i] == id:
			_formation_slots[i] = 0
	if not _suppress_signals:
		hero_removed.emit(id, class_id, display_name)
	return true


## Updates a hero's [code]current_level[/code] to [param new_level], clamping
## to [code][1, level_cap()][/code]. Returns [code]true[/code] on success or
## [code]false[/code] when [param id] is unknown.
##
## Semantics:
##   - Out-of-range [param new_level] is silently clamped (with push_warning).
##   - Unknown id returns false; push_warning logged; no signal emitted.
##   - On success, emits [signal hero_leveled] with [code](id, old_level, new_level)[/code]
##     where [code]new_level[/code] is the post-clamp value.
##   - Clamp-equal-no-op: even when no clamping is needed, the signal still
##     fires (subscribers can compare old==new to detect a no-op level set).
##
## TR-hero-roster-013 — ADR-0012
func set_hero_level(id: int, new_level: int) -> bool:
	if not _heroes.has(id):
		push_warning("[HeroRoster] set_hero_level: unknown id %d" % id)
		return false
	var instance: RefCounted = _heroes[id]
	var cap: int = level_cap()
	var clamped: int = clampi(new_level, 1, cap)
	if clamped != new_level:
		push_warning(
			"[HeroRoster] set_hero_level: %d clamped to %d (level_cap=%d)"
			% [new_level, clamped, cap]
		)
	var old_level: int = instance.current_level
	instance.current_level = clamped
	if not _suppress_signals:
		hero_leveled.emit(id, old_level, clamped)
	return true


## Places [param hero_id] into formation slot [param slot_index]. Returns
## [code]true[/code] on success or [code]false[/code] when the slot is
## out-of-range or [param hero_id] does not exist in the roster.
##
## Semantics:
##   - [param slot_index] must be in [code][0, formation_size())[/code].
##   - [param hero_id] of [code]0[/code] clears the slot.
##   - [param hero_id] != 0 must exist in [member _heroes].
##   - Auto-clear: if [param hero_id] already occupies a different slot,
##     that prior slot is set to 0 BEFORE the new placement — heroes cannot
##     be in two slots simultaneously (TR-014).
##   - No signal is emitted by this method (formation changes are observed
##     by polling [member _formation_slots] via Story 010 accessors).
##
## TR-hero-roster-014 — ADR-0012
func set_formation_slot(slot_index: int, hero_id: int) -> bool:
	if slot_index < 0 or slot_index >= _formation_slots.size():
		push_warning(
			"[HeroRoster] set_formation_slot: slot_index %d out of range [0, %d)"
			% [slot_index, _formation_slots.size()]
		)
		return false
	if hero_id != 0 and not _heroes.has(hero_id):
		push_warning(
			"[HeroRoster] set_formation_slot: unknown hero_id %d"
			% hero_id
		)
		return false
	# Auto-clear: same hero_id cannot occupy two slots — clear any prior slot.
	# (Loop sweeps ALL slots, so it also heals any pathological synthetic state
	# where the same id ended up in multiple slots simultaneously — that state
	# is unreachable via the public API but the loop is robust against it.)
	if hero_id != 0:
		for i: int in range(_formation_slots.size()):
			if _formation_slots[i] == hero_id and i != slot_index:
				_formation_slots[i] = 0
	_formation_slots[slot_index] = hero_id
	return true


## Generates a placeholder display name for a freshly-recruited hero.
##
## Story 004 stub: returns [code]"Hero %d" % instance_id[/code]. Story 009
## replaces this with name-pool generation backed by a DataRegistry
## "name_pools" category keyed by class_id (parameter renamed back to
## [code]class_id[/code] then).
##
## Sprint 8 S8-N9 (Story 009 — TR-022 / TR-023): name pool generation.
##
## Resolves the per-class NamePool via DataRegistry, computes the unused-name
## subset by walking [member _heroes] for entries with the same class_id, and
## returns a uniformly-random unused name. When the pool is exhausted (player
## owns ≥pool-size heroes of the same class), falls back to "{base} the
## {Ordinal}" pattern using the first pool name as the base (e.g.,
## "Theron the Second" → "Theron the Third" → ...).
##
## Defensive: when DataRegistry can't resolve a NamePool for [param class_id]
## (test env without name_pools, or unknown class), returns a "Hero N"
## placeholder with push_warning. Production code paths require all MVP
## class_ids to have a registered pool.
##
## TR-hero-roster-022 / TR-hero-roster-023 — ADR-0011 + ADR-0012
const _ORDINALS: Array[String] = [
	"Second", "Third", "Fourth", "Fifth", "Sixth",
	"Seventh", "Eighth", "Ninth", "Tenth",
]

func _generate_name(class_id: String, instance_id: int) -> String:
	var pool: Resource = DataRegistry.resolve("name_pools", class_id)
	if pool == null or not ("names" in pool):
		push_warning(
			("[HeroRoster] _generate_name: no NamePool for class_id '%s' in DataRegistry; "
			+ "falling back to 'Hero %d' placeholder")
			% [class_id, instance_id]
		)
		return "Hero %d" % instance_id
	var all_names: Array = pool.get("names") as Array
	if all_names.is_empty():
		push_warning(
			"[HeroRoster] _generate_name: NamePool for '%s' has empty names array"
			% class_id
		)
		return "Hero %d" % instance_id
	# Compute the used-name set: existing heroes of THIS class that aren't
	# already ordinal-fallback-named (those don't count against pool exhaustion).
	var used: Dictionary = {}
	for id: int in _heroes:
		var inst: RefCounted = _heroes[id]
		if "class_id" in inst and str(inst.class_id) == class_id:
			used[str(inst.display_name)] = true
	var unused: Array[String] = []
	for n: Variant in all_names:
		var name_str: String = str(n)
		if not used.has(name_str):
			unused.append(name_str)
	# Pool not yet exhausted — uniform random from unused subset.
	if not unused.is_empty():
		return unused[randi() % unused.size()]
	# Pool exhausted — ordinal fallback on the first pool name (TR-022).
	# `ordinal_index` = how many heroes beyond the pool size we are. The first
	# overflow gets "Second" (index 0); the next "Third" (index 1); etc. Past
	# the ordinal table, we fall back to "the Many" rather than crash.
	var base: String = str(all_names[0])
	var pool_size: int = all_names.size()
	var same_class_count: int = used.size()
	var ordinal_index: int = same_class_count - pool_size
	var ordinal: String = "the Many"
	if ordinal_index >= 0 and ordinal_index < _ORDINALS.size():
		ordinal = _ORDINALS[ordinal_index]
	return "%s the %s" % [base, ordinal]


# ---------------------------------------------------------------------------
# Public accessors — Story 010 / S8-N4 (TR-017 / TR-018 / TR-024 / TR-026 / TR-027).
#
# Reads consumed by Combat (formation strength scaling), MatchupResolver
# (formation hero list), and UI (sortable hero roster). All methods are
# pure-function reads against [member _heroes] / [member _formation_slots] —
# zero mutation side effects, no signals fired.
# ---------------------------------------------------------------------------

## Sort mode enum for [method get_all_heroes]. BY_CLASS is the default; UI
## screens may override per their context (Recruitment shows BY_CLASS for
## taxonomy clarity; Roster overview shows BY_LEVEL_DESC for progression
## visibility; debug tools use BY_INSTANCE_ID for stable iteration).
enum SortMode { BY_CLASS, BY_LEVEL_DESC, BY_INSTANCE_ID }


## Computes the formation strength multiplier from the average level of
## non-empty formation slots. Used by Combat as the "formation power"
## scalar; downstream of [method get_formation_heroes].
##
## Formula (TR-017): [code]clamp(1.0 + (avg_level - 1) * 0.2, 1.0, 3.0)[/code]
## where [code]avg_level = sum(current_level) / non_empty_count[/code] and
## empty slots (id=0) are skipped. Empty formation guard returns 1.0
## (no division by zero; the floor of the clamp range).
##
## Output range: [1.0, 3.0]. At level 1 (min) → 1.0; at level 11 → 3.0;
## at level 12+ → still 3.0 (upper clamp). Player-facing UI may display
## the value as a percentage (1.0 = 100% / 3.0 = 300%).
##
## Performance budget (AC H-14 / TR-024): p99 < 50µs over 1000 calls on
## min-spec (Steam Deck 1280×800). MVP path is a tight integer accumulate
## + one float division — easily within budget; perf test in
## [code]tests/unit/hero_roster/formation_strength_and_accessors_test.gd[/code]
## verifies the budget on dev hardware.
##
## Defensive: skips formation slots whose id doesn't resolve in
## [member _heroes] (Story 007 boot validation should have cleared these,
## but this method guards anyway for runtime robustness).
##
## TR-hero-roster-017, TR-hero-roster-018, TR-hero-roster-024 — ADR-0012
func get_formation_strength() -> float:
	var sum_levels: int = 0
	var non_empty_count: int = 0
	for slot_id: int in _formation_slots:
		if slot_id == 0:
			continue
		if not _heroes.has(slot_id):
			continue  # defensive — Story 007 boot validation should clear orphans
		sum_levels += int((_heroes[slot_id] as RefCounted).current_level)
		non_empty_count += 1
	if non_empty_count == 0:
		return 1.0
	var avg: float = float(sum_levels) / float(non_empty_count)
	return clampf(1.0 + (avg - 1.0) * 0.2, 1.0, 3.0)


## Returns the heroes currently assigned to formation slots, ordered by
## slot index. Empty slots (id=0) and orphan-id slots (id not in _heroes)
## are silently skipped — the returned Array contains only valid
## HeroInstance refs.
##
## Result Array length: 0 to FORMATION_SIZE (≤3 in MVP). Consumed by
## Combat (per-tick formation iteration) and MatchupResolver (formation
## input to resolve_formation_matchup) — both treat the empty case as
## "no advantage" defensively.
##
## Output is a fresh Array on each call — caller may mutate without
## affecting [member _formation_slots] state.
##
## TR-hero-roster-027 — ADR-0012
func get_formation_heroes() -> Array:
	var out: Array = []
	for slot_id: int in _formation_slots:
		if slot_id == 0:
			continue
		if not _heroes.has(slot_id):
			continue
		out.append(_heroes[slot_id])
	return out


## Returns all heroes in the roster, sorted per [param sort_mode].
## Default sort is [code]BY_CLASS[/code] (alphabetic class_id ordering with
## level-desc tiebreaker) — matches the Recruitment / Roster UI's taxonomy-
## first display pattern.
##
## Sort modes (TR-026):
##   - [code]BY_CLASS[/code]: alphabetic by class_id ascending; ties broken
##     by current_level descending (highest-level same-class hero first).
##     MVP simplification: alphabetic instead of DataRegistry registration
##     order — flagged in story note as acceptable for V1.0.
##   - [code]BY_LEVEL_DESC[/code]: current_level descending (highest first);
##     no secondary sort (stable per Godot's sort_custom).
##   - [code]BY_INSTANCE_ID[/code]: instance_id ascending — stable iteration
##     for debug tools.
##
## Output is a fresh Array on each call — caller may mutate freely.
##
## TR-hero-roster-026 — ADR-0012
func get_all_heroes(sort_mode: int = SortMode.BY_CLASS) -> Array:
	var out: Array = []
	for id: int in _heroes:
		out.append(_heroes[id])
	match sort_mode:
		SortMode.BY_CLASS:
			out.sort_custom(_sort_by_class_then_level_desc)
		SortMode.BY_LEVEL_DESC:
			out.sort_custom(_sort_by_level_desc)
		SortMode.BY_INSTANCE_ID:
			out.sort_custom(_sort_by_instance_id)
	return out


# Sort comparators — extracted as named methods rather than inline lambdas
# so static typing analysis is happy and stack traces are readable.

func _sort_by_class_then_level_desc(a: RefCounted, b: RefCounted) -> bool:
	if a.class_id != b.class_id:
		return a.class_id < b.class_id  # alphabetic ascending
	return a.current_level > b.current_level  # level descending tiebreaker


func _sort_by_level_desc(a: RefCounted, b: RefCounted) -> bool:
	return a.current_level > b.current_level


func _sort_by_instance_id(a: RefCounted, b: RefCounted) -> bool:
	return a.instance_id < b.instance_id


# ---------------------------------------------------------------------------
# First-launch seed — Story 008 / S8-S5 (TR-020 + TR-021).
#
# Invoked by SaveLoadSystem on the first-launch path (no save file exists).
# Bypasses [method add_hero] because add_hero would assign a name from the
# name pool; the seed name "Theron" is hardcoded and constant per TR-021.
#
# Direct field assignment is the canonical seed path per ADR-0012 §First-launch.
# ---------------------------------------------------------------------------

## Seeds the roster with the canonical first hero (Theron, Warrior, level 1)
## and places them in formation slot 0. Emits [signal hero_recruited] exactly
## once with the new instance.
##
## Refuses (push_warning, no mutation) when the roster is non-empty —
## first-launch seed is a single-shot operation; SaveLoadSystem invokes it
## only when no save file exists.
##
## Refuses (push_error, no mutation) when DataRegistry cannot resolve the
## "warrior" class — boot ordering bug or missing class .tres. Caller (typically
## SaveLoadSystem first-launch detection) is expected to surface this to the
## player as a "data missing" error.
##
## Signal emission is NOT gated on [member _suppress_signals] per the story
## spec (TR-020): the player's first hero deserves a HUD reaction even in
## scripted-test contexts that suppress signals elsewhere. Tests that need to
## verify post-seed state without the signal can still inspect [member _heroes]
## directly.
##
## TR-hero-roster-020 / TR-hero-roster-021 — ADR-0012
func seed_first_launch_state() -> void:
	if _heroes.size() > 0:
		push_warning(
			("[HeroRoster] seed_first_launch_state: refusing to seed non-empty roster "
			+ "(size=%d). First-launch seed is a single-shot operation.")
			% _heroes.size()
		)
		return
	var class_data: Resource = DataRegistry.resolve("classes", SEED_HERO_CLASS_ID)
	if class_data == null:
		push_error(
			("[HeroRoster] seed_first_launch_state: '%s' class not registered in DataRegistry. "
			+ "Cannot seed first-launch hero. Verify assets/data/classes/warrior.tres exists "
			+ "and DataRegistry boot scan ran.")
			% SEED_HERO_CLASS_ID
		)
		return
	var instance: RefCounted = HeroInstanceScript.new()
	instance.instance_id = SEED_HERO_INSTANCE_ID
	instance.class_id = SEED_HERO_CLASS_ID
	instance.display_name = SEED_HERO_NAME
	instance.current_level = 1
	instance.xp = 0
	_heroes[SEED_HERO_INSTANCE_ID] = instance
	_next_instance_id = SEED_HERO_INSTANCE_ID + 1
	# Place in formation slot 0. Direct write — set_formation_slot would also
	# work but adds a re-validation step that is unnecessary at seed time
	# (we just authored the instance so we know it's valid).
	if _formation_slots.size() > SEED_FORMATION_SLOT:
		_formation_slots[SEED_FORMATION_SLOT] = SEED_HERO_INSTANCE_ID
	# IMPORTANT: signal emission is NOT suppressed per TR-020 (see doc above).
	hero_recruited.emit(instance)


# ---------------------------------------------------------------------------
# Save/Load consumer API — Story 006 (TR-010, TR-019, TR-029)
#
# HeroRoster is item #1 in [code]SaveLoadSystem.CONSUMER_PATHS[/code] (after
# Economy at #0). Element-layer canonical naming per ADR-0004:
# [code]get_save_data() -> Dictionary[/code] and
# [code]load_save_data(d: Dictionary) -> void[/code].
#
# Save dict shape (TR-019):
#   {
#     "heroes":           Array of 5-key dicts (HeroInstance.to_dict)
#     "formation_slots":  Array[int] copy of _formation_slots
#     "next_instance_id": int — preserves monotonic id across remove/add (TR-011)
#   }
# ---------------------------------------------------------------------------

## Serializes the full roster state into the save envelope's plain Dictionary.
##
## Returns a fresh Dictionary with exactly 3 top-level keys:
##   - [code]heroes[/code]: Array of dicts produced by [method HeroInstance.to_dict]
##   - [code]formation_slots[/code]: Array[int] copy of [member _formation_slots]
##     (DUPLICATED — caller may mutate without touching live state)
##   - [code]next_instance_id[/code]: int copy of [member _next_instance_id]
##
## Order of `heroes` is iteration-order of [member _heroes] (Godot Dictionaries
## preserve insertion order). [method load_save_data] does not depend on order
## — heroes are re-keyed by their stored [code]instance_id[/code].
##
## TR-hero-roster-019 — ADR-0004, ADR-0012
func get_save_data() -> Dictionary:
	var heroes_arr: Array = []
	for id: int in _heroes:
		var instance: RefCounted = _heroes[id]
		heroes_arr.append(instance.to_dict())
	return {
		"heroes": heroes_arr,
		"formation_slots": _formation_slots.duplicate(),
		"next_instance_id": _next_instance_id,
	}


## Hydrates the roster from a save envelope's plain Dictionary.
##
## Resets [member _heroes], [member _formation_slots], and [member _next_instance_id]
## to a clean slate, then walks the [code]heroes[/code] array reconstructing
## [HeroInstance] objects via [method HeroInstance.from_dict].
##
## Signal suppression (TR-010): [member _suppress_signals] is set to
## [code]true[/code] for the entire bulk-hydration path so subscribers
## (HUD/Recruitment/Economy) do NOT receive [signal hero_recruited],
## [signal hero_leveled], or [signal hero_removed] mid-load. The flag is
## restored to [code]false[/code] before this method returns. Story 007
## extends the protected section to cover boot validation that may run
## immediately after.
##
## Defensive defaults — missing keys produce safe empty state:
##   - [code]heroes[/code] missing → empty roster
##   - [code]formation_slots[/code] missing → cleared to formation_size() zeros
##   - [code]next_instance_id[/code] missing → 1 (cold-start default)
##
## TR-hero-roster-010, TR-hero-roster-019, TR-hero-roster-029 — ADR-0004
func load_save_data(d: Dictionary) -> void:
	_suppress_signals = true
	_heroes.clear()
	# Reset formation slots to the configured size, all empty.
	_resize_formation_slots()
	_next_instance_id = 1

	# Hydrate heroes — each entry is a 5-key dict per HeroInstance.to_dict().
	# TR-025: duplicate instance_id in save → last-write-wins via Dictionary
	# assignment semantics; push_error logged so the upstream save corruption
	# is visible. No crash; no skip — the second write overwrites the first.
	var heroes_arr: Array = d.get("heroes", []) as Array
	var seen_ids: Dictionary = {}
	for hero_dict: Dictionary in heroes_arr:
		var instance: RefCounted = HeroInstanceScript.new()
		instance.from_dict(hero_dict)
		if seen_ids.has(instance.instance_id):
			push_error(
				"[HeroRoster] load_save_data: duplicate instance_id %d in save (last-write-wins)"
				% instance.instance_id
			)
		seen_ids[instance.instance_id] = true
		_heroes[instance.instance_id] = instance

	# Hydrate formation slots — clamp size to formation_size() to defend against
	# saves authored before a config change shrunk the formation.
	var slots_in: Array = d.get("formation_slots", []) as Array
	var slot_count: int = formation_size()
	if slots_in.size() > slot_count:
		push_warning(
			("[HeroRoster] load_save_data: saved formation_slots count (%d) "
			+ "exceeds current formation_size (%d); trailing slots truncated. "
			+ "Heroes assigned to truncated slots remain in the roster but lose "
			+ "their formation placement.")
			% [slots_in.size(), slot_count]
		)
	for i: int in range(slot_count):
		if i < slots_in.size():
			# Coerce to int defensively (JSON round-trip may produce floats).
			_formation_slots[i] = int(slots_in[i])
		else:
			_formation_slots[i] = 0

	# Restore the monotonic id counter — TR-011: removed ids never reused.
	_next_instance_id = int(d.get("next_instance_id", 1))

	# Sprint 8 S8-S4 (Story 007): boot validation — runs while signals still
	# suppressed so any drops/clears don't leak hero_removed emissions.
	_validate_after_load()

	_suppress_signals = false

	# TR-016: non-blocking orphan notice fires AFTER suppression is lifted —
	# subscribers want to react to the notice with normal signal handling.
	if _orphaned_heroes.size() > 0:
		orphan_heroes_notice.emit(_orphaned_heroes.size())


## Sprint 8 S8-S4 (Story 007 — TR-015 / TR-016): runs the 4-step boot
## validation pass after [method load_save_data] hydrates [member _heroes].
## Order matters — each step depends on the prior step's output:
##
##   1. Resolve class_ids: drop heroes whose [code]class_id[/code] DataRegistry
##      cannot resolve. Append the dropped instances to [member _orphaned_heroes]
##      (session-only — never persisted). The orphan list is CLEARED at the
##      start of this method so a re-load doesn't accumulate stale entries.
##   2. Clear stale formation slots: any slot referencing a hero id that no
##      longer exists in [member _heroes] is set to 0 (empty slot sentinel).
##   3. Trim over-cap: if [member _heroes] exceeds [method max_roster_size],
##      drop the highest-id heroes (preserve lowest ids). Per ADR-0012, lowest
##      ids are the oldest heroes — the player's longest-tenured roster.
##   4. Repair [member _next_instance_id]: ensures monotonic id allocation
##      survives the trim — set to [code]max(_next_instance_id, max(ids) + 1)[/code].
##
## Called from [method load_save_data] BEFORE [member _suppress_signals]
## returns to false — boot validation must remain signal-quiet (TR-010).
##
## TR-hero-roster-015 / TR-hero-roster-016 — ADR-0012
func _validate_after_load() -> void:
	# Step 1: resolve class_ids; drop unresolvable heroes into orphans.
	_orphaned_heroes.clear()
	var to_remove: Array[int] = []
	for id: int in _heroes:
		var instance: RefCounted = _heroes[id]
		if DataRegistry.resolve("classes", instance.class_id) == null:
			push_warning(
				("[HeroRoster] _validate_after_load: orphan hero id=%d class_id='%s' "
				+ "unresolvable — appending to _orphaned_heroes; dropping from roster.")
				% [id, instance.class_id]
			)
			_orphaned_heroes.append(instance)
			to_remove.append(id)
	for id: int in to_remove:
		_heroes.erase(id)

	# Step 2: clear stale formation slots referencing dropped/orphan ids.
	for i: int in range(_formation_slots.size()):
		var slot_id: int = _formation_slots[i]
		if slot_id != 0 and not _heroes.has(slot_id):
			push_warning(
				"[HeroRoster] _validate_after_load: clearing formation slot %d (orphan id=%d)"
				% [i, slot_id]
			)
			_formation_slots[i] = 0

	# Step 3: trim over-cap (preserve lowest ids).
	var cap: int = max_roster_size()
	if _heroes.size() > cap:
		var sorted_ids: Array = _heroes.keys()
		sorted_ids.sort()
		# Keep the first `cap` (lowest) ids; drop the rest.
		for i: int in range(cap, sorted_ids.size()):
			var id_to_drop: int = sorted_ids[i]
			push_warning(
				"[HeroRoster] _validate_after_load: trimming over-cap id=%d (cap=%d)"
				% [id_to_drop, cap]
			)
			_heroes.erase(id_to_drop)

	# Step 4: repair _next_instance_id to be strictly greater than any present id.
	# Preserves TR-011 monotonic invariant even after trim/orphan drops.
	if _heroes.size() > 0:
		var ids: Array = _heroes.keys()
		var max_id: int = ids.max()
		_next_instance_id = max(_next_instance_id, max_id + 1)
	# else: leave _next_instance_id at whatever load_save_data set (or 1).
