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

# Fallback XP threshold curve constants per Hero Leveling GDD #15 §C.3 defaults.
# Used when Economy.get_config() returns null (boot order / test fixture).
const _FALLBACK_XP_THRESHOLD_BASE: int = 100
const _FALLBACK_XP_THRESHOLD_STEP: int = 50

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

## Prestige V1.0 (Sprint 21 / Story 1) — global count of completed prestige
## actions. Monotonically non-decreasing per session; persisted in V2 save
## schema (Story 2 scope). Default 0 = no prestige yet.
##
## design/gdd/prestige-system.md §C.5 + AC-PR-08.
var _prestige_count: int = 0

## Prestige V1.0 — cached global multiplier derived from [member _prestige_count]
## via [method get_prestige_multiplier]. Cached value updated on every
## successful [method prestige_hero] call. Default 1.0 (no boost).
##
## design/gdd/prestige-system.md §C.5 + AC-PR-08.
var _prestige_multiplier: float = 1.0

## Prestige V1.0 — append-only record of retired heroes (Hall of Retired
## Heroes content). Each entry is a Dictionary with the schema documented
## in [signal prestige_completed_signal]. Persisted in V2 save schema.
##
## design/gdd/prestige-system.md §C.4 + §C.5 + AC-PR-07.
var _retired_hero_records: Array[Dictionary] = []

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

## Prestige System V1.0 (Sprint 21 / Story 1, 2026-05-09) — fired when
## [method prestige_hero] succeeds. Subscribers (Hall of Retired Heroes
## screen #19, AudioRouter) react to the player's voluntary retirement
## of a LEVEL_CAP hero.
##
## [param record]: the new RetiredHeroRecord Dictionary appended to
##   [member _retired_hero_records]. Schema per `prestige-system.md` §C.5:
##   {display_name, class_id, level_at_retirement, retirement_unix_ts,
##    prestige_index}.
## [param new_count]: the post-action [member _prestige_count] value
##   (always >= 1; first prestige = 1). Subscribers compute the new
##   multiplier via [method get_prestige_multiplier].
##
## design/gdd/prestige-system.md §C.2 + §F + AC-PR-09.
@warning_ignore("unused_signal")
signal prestige_completed_signal(record: Dictionary, new_count: int)


# ---------------------------------------------------------------------------
# Prestige V1.0 — Sprint 21 / Story 1 constants per `prestige-system.md` §G.
# ---------------------------------------------------------------------------

## Per-prestige multiplier gain. Applied to BOTH kill gold AND kill XP per
## the orchestrator's per-kill formula. Default 0.05 (5% per prestige).
## Per AC-PR-16 invariant: `PRESTIGE_GAIN_PER × PRESTIGE_MAX == PRESTIGE_MULTIPLIER_CAP - 1.0`.
const PRESTIGE_GAIN_PER: float = 0.05

## Hard ceiling on the global prestige multiplier. Default 2.0 (×2 baseline
## maximum at full prestige). Cozy-register hard floor: prestige is voluntary,
## not mandatory — capping at 2.0 prevents runaway compounding.
const PRESTIGE_MULTIPLIER_CAP: float = 2.0

## Hard cap on total prestige actions. Default 20 (with PRESTIGE_GAIN_PER=0.05
## yields exactly 1.0 + 20×0.05 = 2.0 = PRESTIGE_MULTIPLIER_CAP). Beyond this,
## [method is_prestige_eligible] returns false; the Hero Detail Modal hides
## the Prestige button.
const PRESTIGE_MAX: int = 20


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
	# Sprint 8 S8-M4 hotfix: wire first-launch seed for the AUTOLOAD instance only.
	# seed_first_launch_state() is the public Theron-seed function (S8-S5 closure)
	# that was defined but never invoked at boot. Call deferred so it runs at
	# end-of-frame, AFTER any same-frame load_save_data() calls populate
	# _heroes from a saved game. The seed_first_launch_state() guard refuses
	# to seed a non-empty roster, so this is idempotent and safe.
	#
	# Gate: only the autoload instance (resolvable as `/root/HeroRoster`) seeds.
	# Test fixtures that instantiate fresh HeroRoster nodes via add_child do NOT
	# match this guard, preserving the empty initial state required by unit tests.
	if get_tree() != null and get_tree().root != null:
		var autoload_node: Node = get_tree().root.get_node_or_null("HeroRoster")
		if autoload_node == self:
			call_deferred("seed_first_launch_state")


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


# ---------------------------------------------------------------------------
# Prestige V1.0 — Sprint 21 / Story 1 public API.
#
# Per design/gdd/prestige-system.md §C.1 + §C.2 + §D.1 + §D.2 + AC-PR-01..11.
#
# The Hero Detail Modal queries [method is_prestige_eligible] to decide
# whether to show the "Prestige Hero" button. On player [Prestige Hero] tap
# (after the cozy confirmation modal), the UI layer calls [method prestige_hero]
# which synchronously: removes the hero from the active roster + appends a
# RetiredHeroRecord + increments the global count + recomputes the multiplier
# + emits the completion signal. Subscribers (Hall view, AudioRouter) react.
#
# The orchestrator's per-kill formula reads [method get_prestige_multiplier]
# to apply the prestige multiplier alongside matchup × loot × synergy
# (Sprint 22+ wiring; this story ships the in-memory surface only).
#
# V1→V2 save schema migration is Story 2 scope (CURRENT_SAVE_VERSION bump
# 1→2 + _migrate_v1_to_v2 body in SaveLoadSystem). This story's defaults
# (0 / 1.0 / []) match the V1→V2 migration's default-on-missing values.
# ---------------------------------------------------------------------------

## Returns [code]true[/code] if [param instance_id] is eligible for prestige.
##
## Eligibility checks (all must hold):
##   1. Hero exists at [param instance_id]
##   2. Hero is at [method level_cap]
##   3. Global [member _prestige_count] is below [constant PRESTIGE_MAX]
##   4. Global [member _prestige_multiplier] is below [constant PRESTIGE_MULTIPLIER_CAP]
##   5. **Roster size > 1** — last-hero protection per AC-PR-20. If the
##      to-be-prestiged hero is the only hero in the active roster,
##      [method remove_hero] would brick the game (first-launch seed
##      contract guarantees ≥ 1 hero). Story 3 logic guard: hide the
##      button at the source.
##   6. **Orchestrator state is NO_RUN** — active-run guard per
##      AC-PR-19 + GDD §E.2. Prestige cannot fire during ACTIVE_FOREGROUND
##      / ACTIVE_OFFLINE_REPLAY / DISPATCHING. The UI layer renders the
##      button as disabled (greyed out) with the
##      `prestige_disabled_active_run_tooltip` localized tooltip.
##      Defensive: if the DungeonRunOrchestrator autoload is absent
##      (test envs), the guard is skipped (eligibility passes on the
##      other 5 checks).
##
## Returns [code]false[/code] (no push_warning, no error) when any check
## fails. The Hero Detail Modal hides OR disables the Prestige button on
## false return per the specific failure mode.
##
## Per [code]prestige-system.md[/code] §C.1 + §D.2 + §E.1 + §E.2 +
## AC-PR-01..05 + AC-PR-19 + AC-PR-20.
func is_prestige_eligible(instance_id: int) -> bool:
	if not _heroes.has(instance_id):
		return false
	var hero: RefCounted = _heroes[instance_id]
	if hero == null or not ("current_level" in hero):
		return false
	if int(hero.current_level) != level_cap():
		return false
	if _prestige_count >= PRESTIGE_MAX:
		return false
	if _prestige_multiplier >= PRESTIGE_MULTIPLIER_CAP:
		return false
	# AC-PR-20 last-hero protection — removing the only hero would brick
	# the game per `hero-roster.md` first-launch seed contract.
	if _heroes.size() <= 1:
		return false
	# AC-PR-19 active-run guard — prestige is only legal from NO_RUN state.
	# Defensive null-check for test envs without the orchestrator autoload.
	# The orchestrator exposes its state via a public `state: int` field
	# (not a method) per dungeon_run_orchestrator.gd:56. Use Object.get
	# to read it without coupling to the import; null return means the
	# field doesn't exist (degenerate orchestrator) and we skip the guard.
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if orch != null and "state" in orch:
		# State enum: NO_RUN = 0 per dungeon_run_state.gd. Compare to int 0
		# to avoid coupling to the enum import. Any non-zero state
		# (DISPATCHING, ACTIVE_FOREGROUND, ACTIVE_OFFLINE_REPLAY, RUN_ENDED)
		# fails eligibility.
		if int(orch.get("state")) != 0:
			return false
	return true


## Synchronous prestige action. Removes the hero, appends a RetiredHeroRecord,
## advances the global count + multiplier, emits [signal prestige_completed_signal].
##
## Returns [code]true[/code] on success, [code]false[/code] when the hero is
## not eligible (per [method is_prestige_eligible]). On false return, no
## state changes — idempotent reject.
##
## Side effects on success (in order):
##   1. Capture the hero's display_name + class_id + current_level for the
##      RetiredHeroRecord (must read pre-removal — the hero instance is
##      gone after step 2).
##   2. [method remove_hero] — drops the hero from active roster.
##      Auto-clears formation slots; emits [signal hero_removed].
##   3. Increment [member _prestige_count].
##   4. Recompute [member _prestige_multiplier] = clampf(1.0 + count × GAIN_PER, 1.0, CAP).
##   5. Append the RetiredHeroRecord to [member _retired_hero_records].
##      Schema: {display_name, class_id, level_at_retirement,
##               retirement_unix_ts, prestige_index}.
##   6. Emit [signal prestige_completed_signal] with the new record + count.
##
## SaveLoadSystem persist trigger: Story 2 scope. This story ships the in-
## memory mutation; the cross-system persist call lives in the V1→V2
## migration epic.
##
## Per [code]prestige-system.md[/code] §C.2 + §D.1 + AC-PR-06..09.
func prestige_hero(instance_id: int) -> bool:
	if not is_prestige_eligible(instance_id):
		return false
	# Capture pre-removal state for the RetiredHeroRecord.
	var hero: RefCounted = _heroes[instance_id]
	var display_name: String = String(hero.display_name) if "display_name" in hero else ""
	var class_id: String = String(hero.class_id) if "class_id" in hero else ""
	var level_at_retirement: int = int(hero.current_level) if "current_level" in hero else 0
	# Step 2: remove hero from active roster.
	if not remove_hero(instance_id):
		# Defensive: remove_hero returned false somehow (shouldn't happen
		# since is_prestige_eligible verified existence). Abort cleanly.
		return false
	# Step 3-4: advance prestige count + multiplier.
	_prestige_count += 1
	_prestige_multiplier = clampf(
		1.0 + float(_prestige_count) * PRESTIGE_GAIN_PER,
		1.0,
		PRESTIGE_MULTIPLIER_CAP
	)
	# Step 5: append RetiredHeroRecord. Per ADR-0005 single-call-site
	# invariant, the wall-clock read MUST route through TickSystem's
	# cached value — direct Time.get_unix_time_from_system() is forbidden
	# in src/ outside tick_system.gd. If TickSystem cache is cold (returns
	# 0), the timestamp falls back to 0 — UI degrades gracefully (Hall
	# card renders "Day 0" or hides the date until first heartbeat).
	var retirement_ts: int = 0
	var tick_system_for_ts: Node = get_node_or_null("/root/TickSystem")
	if tick_system_for_ts != null and tick_system_for_ts.has_method("now_ms"):
		var ms_val: int = int(tick_system_for_ts.now_ms())
		if ms_val > 0:
			@warning_ignore("integer_division")
			retirement_ts = ms_val / 1000
	var record: Dictionary = {
		"display_name": display_name,
		"class_id": class_id,
		"level_at_retirement": level_at_retirement,
		"retirement_unix_ts": retirement_ts,
		"prestige_index": _prestige_count,
	}
	_retired_hero_records.append(record)
	# Step 6: emit completion signal.
	if not _suppress_signals:
		prestige_completed_signal.emit(record, _prestige_count)
	# Step 7: synchronous persist trigger per AC-PR-10. The save state must
	# survive a crash immediately after prestige — the player's retirement
	# action is a major irreversible decision; losing it to a crash would
	# violate the cozy register's "your guild is safe" contract. Defensive:
	# null-guard for test envs without SaveLoadSystem registered.
	#
	# Per `prestige-system.md` §C.2 step 6.
	var save_load: Node = get_node_or_null("/root/SaveLoadSystem")
	if save_load != null and save_load.has_method("request_full_persist"):
		save_load.call("request_full_persist", "prestige_completed")
	return true


## Returns the current global prestige multiplier — the value that the
## per-kill gold + XP formulas multiply by. Default 1.0 when no prestige
## has occurred. Pure function of [member _prestige_count].
##
## Per [code]prestige-system.md[/code] §D.1 + AC-PR-08.
func get_prestige_multiplier() -> float:
	return clampf(
		1.0 + float(_prestige_count) * PRESTIGE_GAIN_PER,
		1.0,
		PRESTIGE_MULTIPLIER_CAP
	)


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


## Returns the XP required to advance a hero from [param current_level] to
## [code]current_level + 1[/code]. Pure linear curve per Hero Leveling GDD
## #15 §C.3 / §D.3:
##   [code]xp_threshold(L) = XP_THRESHOLD_BASE + XP_THRESHOLD_STEP * L[/code]
##
## Constants resolve through [code]Economy.get_config()[/code]; if the config
## is null (boot ordering edge case) the fallback constants
## [code]_FALLBACK_XP_THRESHOLD_BASE[/code] / [code]_FALLBACK_XP_THRESHOLD_STEP[/code]
## are used (defaults 100 / 50, matching GDD).
##
## Out-of-range [param current_level] is not validated here — callers
## ([method add_xp]) only invoke this with [code]current_level in [1, level_cap()-1][/code].
##
## Hero Leveling GDD #15 §C.3 — TR-15-03
func xp_threshold(current_level: int) -> int:
	var base: int = _FALLBACK_XP_THRESHOLD_BASE
	var step: int = _FALLBACK_XP_THRESHOLD_STEP
	var cfg: Resource = Economy.get_config() if Economy != null else null
	if cfg != null:
		if "XP_THRESHOLD_BASE" in cfg:
			base = int(cfg.get("XP_THRESHOLD_BASE"))
		if "XP_THRESHOLD_STEP" in cfg:
			step = int(cfg.get("XP_THRESHOLD_STEP"))
	return base + step * current_level


## Grants [param amount] XP to the hero with [param id], cascading through
## any level-ups the gain crosses. Returns [code]true[/code] on success or
## [code]false[/code] when [param id] is unknown OR [param amount] is negative.
##
## Semantics (Hero Leveling GDD #15 §C.4):
##   - [param amount] == 0: silent no-op; returns [code]true[/code]; no signal.
##   - [param amount] < 0: push_error + return [code]false[/code]; no mutation.
##   - Unknown [param id]: push_warning + return [code]false[/code]; no mutation.
##   - Already at [method level_cap]: silent no-op; returns [code]true[/code]
##     (overflow discarded per cozy register §C.5; no negative feedback).
##   - Cascade: while [code]instance.xp >= xp_threshold(current_level)[/code]
##     and [code]current_level < level_cap()[/code], deduct threshold,
##     increment level, emit [signal hero_leveled] once per crossed level.
##   - On reaching the cap mid-cascade, [code]instance.xp = 0[/code]
##     (overflow discarded per §C.5 + §E.6).
##   - Signal suppression: when [member _suppress_signals] is true (post-load
##     hydration per ADR-0004 + §C.7), state mutates but [signal hero_leveled]
##     is NOT emitted. Audio chime / toast subscribers stay silent.
##
## Hero Leveling GDD #15 §C.4 / §C.5 / §C.7 — TR-15-04
func add_xp(id: int, amount: int) -> bool:
	if not _heroes.has(id):
		push_warning("[HeroRoster] add_xp: unknown id %d" % id)
		return false
	if amount < 0:
		push_error(
			"[HeroRoster] add_xp: negative amount %d (id=%d)" % [amount, id]
		)
		return false
	if amount == 0:
		return true
	var instance: RefCounted = _heroes[id]
	var cap: int = level_cap()
	# Already capped — overflow discarded silently per §C.5.
	if instance.current_level >= cap:
		return true
	instance.xp += amount
	while instance.current_level < cap:
		var threshold: int = xp_threshold(instance.current_level)
		if instance.xp < threshold:
			break
		instance.xp -= threshold
		var old_level: int = instance.current_level
		instance.current_level += 1
		if not _suppress_signals:
			hero_leveled.emit(id, old_level, instance.current_level)
	# Cap reached mid-cascade — discard XP overflow per §C.5 / §E.6.
	if instance.current_level >= cap:
		instance.xp = 0
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


## Returns the hero instance_id occupying formation slot [param slot_index],
## or [code]0[/code] if the slot is empty or [param slot_index] is out of range.
##
## Documented as public API in design/gdd/hero-roster.md §C (Rule 10) for the
## Formation Assignment Screen (#23). Out-of-range slot_index returns 0 rather
## than raising — matches set_formation_slot's defensive validation contract.
##
## TR-hero-roster (formation slot read-accessor — companion to set_formation_slot)
##
## Example:
##   [codeblock]
##   var slot0_hero: int = HeroRoster.get_formation_slot(0)
##   if slot0_hero != 0:
##       var hero: HeroInstance = HeroRoster.get_hero(slot0_hero)
##   [/codeblock]
func get_formation_slot(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= _formation_slots.size():
		return 0
	return _formation_slots[slot_index]


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
## Returns the count of heroes in the roster whose [code]class_id[/code] matches
## [param class_id]. Used by Recruitment to compute [code]copies_owned[/code]
## for [code]Economy.recruit_cost(class_id, copies_owned)[/code] per ADR-0013
## cost-curve contract.
##
## Returns 0 for an unknown class_id (the value is "no copies of this class
## are in the roster", which is the correct semantic for recruit-cost lookup
## even when class_id refers to a future / unreleased class).
##
## O(n) over the roster size (n ≤ MAX_ROSTER_SIZE = 30 per default config).
##
## Sprint 11 S11-X5 — added per Recruitment GDD §F + OQ-RC-4 (Sprint 12+
## Story 0b lockstep). ADR-0012 Amendment #1 documents this addition as
## an additive read-API extension (no existing API surface changes).
func get_copies_owned(class_id: String) -> int:
	var n: int = 0
	for id: int in _heroes:
		var hero: RefCounted = _heroes[id]
		if hero != null and "class_id" in hero and String(hero.get("class_id")) == class_id:
			n += 1
	return n


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
	# Prestige V1.0 (Story 2 / Sprint 21+) — V2 schema additions per
	# `prestige-system.md` §C.5. Three new fields persist alongside the
	# existing 3-key V1 schema. V1 saves load via _migrate_v1_to_v2 which
	# defaults these to 0 / 1.0 / [].
	return {
		"heroes": heroes_arr,
		"formation_slots": _formation_slots.duplicate(),
		"next_instance_id": _next_instance_id,
		"prestige_count": _prestige_count,
		"prestige_multiplier": _prestige_multiplier,
		"retired_hero_records": _retired_hero_records.duplicate(true),
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

	# Prestige V1.0 (Story 2) — hydrate V2 schema additions. Defaults
	# match the V1→V2 migration body in SaveLoadSystem so legacy V1 saves
	# (no prestige fields) hydrate as "no prestige yet". Per
	# `prestige-system.md` §C.5 + AC-PR-12 + AC-PR-14.
	#
	# Defensive int() coercion on the count (JSON returns floats for whole
	# numbers per project memory). Multiplier is float-native. Records is
	# duplicated to defeat external mutation of the source dict.
	_prestige_count = int(d.get("prestige_count", 0))
	_prestige_multiplier = float(d.get("prestige_multiplier", 1.0))
	var records_in: Variant = d.get("retired_hero_records", [])
	var records_typed: Array[Dictionary] = []
	if records_in is Array:
		for r: Variant in (records_in as Array):
			if r is Dictionary:
				records_typed.append((r as Dictionary).duplicate(true))
	_retired_hero_records = records_typed

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
