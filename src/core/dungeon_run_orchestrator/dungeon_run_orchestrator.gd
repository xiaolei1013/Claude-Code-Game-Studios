extends Node

## DungeonRunOrchestrator — rank-12 Feature autoload for run lifecycle coordination.
##
## NOTE: No `class_name` — autoload scripts cannot declare `class_name` matching
## the autoload identifier (Sprint 1 lesson; Godot raises "Class X hides an
## autoload singleton"). The autoload is globally accessible as
## [code]DungeonRunOrchestrator[/code]; tests that need a fresh instance use
## [code]preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd").new()[/code].
##
## Owns:
## - [member state]: current FSM state (one of [enum DungeonRunState.State])
## - [member run_snapshot]: per-dispatch [RunSnapshot] (null when state == NO_RUN)
## - 3 injected dependencies: [member _combat_resolver], [member _matchup_resolver],
##   [member _error_logger] — wired via lazy-default-with-public-setters per ADR-0009
##
## Single purpose (per GDD §A): the **stateful host** that lets Combat Resolution
## remain stateless. Subscribes to TickSystem.tick_fired, calls Combat's pure-
## function entry points, and routes Combat's outputs to the rest of the game's
## signal consumers (Economy gold, Dungeon Run View kill-pops, etc.). This story
## implements the boot skeleton + DI surface ONLY; tick subscription + state
## transitions land in Stories 003-005.
##
## ADR-0014: Offline Replay Batch Chunking + RunSnapshot Schema (rank 14 in
##           ADR; this skeleton claims the next vacant slot per ADR-0003 §Editing
##           Protocol — actual rank determined at register time).
## ADR-0009: Matchup Resolver DI (lazy-default with public setters).
## ADR-0010: Combat Resolver Snapshot (pure-function consumer pattern).
## ADR-0003 Amendment #3: zero-arg `_init` invariant on autoloads.

# ---------------------------------------------------------------------------
# Preloaded resolver scripts — used for lazy-default instantiation in _ready().
# Production resolver implementations land in the matchup-resolver and
# combat-resolution epics (story bundles via S6-M10/M11 pre-flight). The stubs
# below are minimal RefCounted classes that satisfy the preload at parse time;
# consumers MUST inject real spies via the public setters until production
# resolvers ship.
# ---------------------------------------------------------------------------

const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")

## Preloaded State enum + 5×6 transition matrix from S6-M7. The orchestrator
## delegates state-transition validation to [code]DungeonRunState.validate_transition[/code]
## rather than reimplementing the matrix here.
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")


# ---------------------------------------------------------------------------
# State — owned exclusively by this autoload (ADR-0014 §B "FSM state is owned
# exclusively by the Orchestrator and persisted via Save/Load").
# ---------------------------------------------------------------------------

## Current FSM state — initial NO_RUN at boot. Only mutated by the transition
## handler (Story 003) and `load_save_data` hydration (later sprint).
var state: int = DungeonRunStateScript.State.NO_RUN

## Per-dispatch run state. Null when [member state] is NO_RUN. Allocated in
## DISPATCHING by [method _build_run_snapshot] (Sprint 7 S7-M13 data harness);
## freed when state returns to NO_RUN after RUN_ENDED clear.
var run_snapshot: RunSnapshot = null

## Combat-side immutable snapshot used by [method _on_tick_fired]'s call to
## [code]combat_resolver.emit_events_in_range(...)[/code]. Distinct from
## [member run_snapshot] (which is the FSM-state-ownership snapshot persisted
## by Save/Load) — this is a pre-projected CombatRunSnapshot suitable for
## passing directly to [CombatResolver]. Allocated at DISPATCHING, freed when
## state returns to NO_RUN. Typed as [Resource] not [CombatRunSnapshot] for
## the same Sprint 6 autoload-class-cache safety as [member _config] in
## HeroRoster (defensive against parse-order edge cases).
##
## Sprint 7 S7-M13 — ADR-0010
var _combat_snapshot: RefCounted = null


# ---------------------------------------------------------------------------
# Signals — TR-orchestrator-026, TR-orchestrator-027
# ---------------------------------------------------------------------------

## Emitted when a [method dispatch] call fails validation (empty formation,
## locked floor, etc.). [param reason] is a stable identifier suitable for
## driving UI error display ([code]"empty_formation"[/code], [code]"floor_locked"[/code]).
## [param payload] carries reason-specific context (e.g.,
## [code]{"floor_index": 99}[/code] for [code]"floor_locked"[/code]); empty
## dict when the reason is self-explanatory.
##
## TR-orchestrator-026, TR-orchestrator-027
signal validation_failed(reason: String, payload: Dictionary)

## Emitted by [method _set_state] after every state assignment where the new
## state differs from the prior state ([code]new_state != old_state[/code]).
##
## Consumers (e.g., DungeonRunView) subscribe to detect state transitions such
## as ACTIVE_FOREGROUND → RUN_ENDED without polling [member state] per tick.
## The signal fires AFTER [member state] is written to [param new_state], so
## listeners observe the current value via [member state].
##
## [param new_state]: the state that was just entered (matches [member state]
## at the time the signal fires).
## [param old_state]: the state that was just exited.
##
## Story 012 — AC-6 (preferred RUN_ENDED detection path over tick polling).
signal state_changed(new_state: int, old_state: int)

## Sprint 8 S8-S3 (Story 006 — TR-025): per-kill notification signal. Emitted
## once per kill event during [method _process_kill_events]. Payload is the
## kill's tier (drives Economy's BASE_KILL[tier] table), the enemy archetype
## (StringName cast to String for the signal), and whether the formation was
## advantaged against that archetype (read from the combat snapshot's
## matchup_cache). Subscribers (HUD ticker, audio cue) react per-kill.
##
## TR-orchestrator-025
signal enemy_killed(tier: int, archetype: String, advantaged: bool)

## Sprint 8 S8-S3 (Story 006 — TR-022): per-boss-kill fanfare signal. Fires
## on ANY kill event with [code]is_boss=true[/code] regardless of queue
## position (per TR-022 — Combat propagates the is_boss bit per-entry; the
## orchestrator emits regardless of where in the schedule the boss landed).
## [param enemy_id] is the StringName from the floor's enemy_list converted
## to String for the signal payload.
##
## TR-orchestrator-022
signal boss_killed(enemy_id: String)

## Sprint 8 S8-S3 (Story 006 — TR-022): once-per-dispatch first-clear fanfare.
## Fires when a kill event's tick covers the floor's first-clear marker
## (CombatTickEvents.first_clear_in_range == true) AND
## [member RunSnapshot.floor_clear_emitted] is still false. The orchestrator
## owns the once-per-dispatch idempotency gate (TR-018) — Combat reports the
## marker per-call but only the first crossing triggers this signal.
##
## TR-orchestrator-022
signal floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool)


# ---------------------------------------------------------------------------
# Injected dependencies — lazy-default-with-public-setters per ADR-0009.
# Tests inject spies BEFORE _ready() fires (e.g., from a test scene's _init);
# if no injection happens, _ready() instantiates the default for each null slot.
# ---------------------------------------------------------------------------

## CombatResolver dependency — pure-function provider for `emit_events_in_range`
## and `compute_offline_batch`. Default: [DefaultCombatResolver] (Sprint 6 stub).
var _combat_resolver: RefCounted = null

## MatchupResolver dependency — provides per-archetype matchup advantage
## lookups consumed at DISPATCHING for the snapshot's `matchup_cache`.
## Default: [DefaultMatchupResolver] (Sprint 6 stub).
var _matchup_resolver: RefCounted = null

## Error-logger dependency — Callable-via-RefCounted indirection that lets
## tests capture push_error / push_warning calls without intercepting the
## global handler. Default: null (in MVP we use Godot's push_error / push_warning
## directly; tests that want capture inject a recording spy here).
##
## TR-orchestrator-024 — ADR-0009
var _error_logger: RefCounted = null

## FloorUnlock dependency — provides [code]is_unlocked(floor_index: int) -> bool[/code].
## Production impl lands in the floor-unlock-system epic; until then, tests
## inject a spy via [method set_floor_unlock]. When [code]null[/code], the
## DISPATCHING floor-lock check is SKIPPED (fail-open) per the Sprint 6
## pre-production posture — production code paths in later sprints MUST inject
## a real FloorUnlock before the orchestrator dispatches.
##
## TR-orchestrator-027 — ADR-0009
var _floor_unlock: RefCounted = null


# ---------------------------------------------------------------------------
# Sprint 8 S8-S3 (Story 006) — kill-attribution constants + dispatch context
# ---------------------------------------------------------------------------

## Per-tier base gold table — Economy.add_gold pre-multiplier (TR-014). Tiers
## 1..5 cover MVP enemies; missing-tier lookups return 0 via Dictionary.get.
## Sourced from ADR-0013 §C kill-reward curve.
const BASE_KILL: Dictionary = {1: 5, 2: 10, 3: 25, 4: 50, 5: 100}

## Matchup multiplier when formation is advantaged against the enemy archetype
## (matchup_cache says true). Mirrors CombatConfig.MATCHUP_THROUGHPUT_FACTOR_ADV.
const MATCHUP_MULT_ADV: float = 1.5

## Matchup multiplier when formation is NOT advantaged. Mirrors CombatConfig's
## disadvantaged factor for kill-attribution purposes.
const MATCHUP_MULT_DIS: float = 0.7

## Loot factor applied to a kill's gold reward when the run is a "losing_run"
## (HP-bonus < 0.5; persisted explicitly in run_snapshot per ADR-0014 §B4).
## Half-loot per the GDD.
const LOSING_RUN_LOOT_FACTOR: float = 0.5

## Sprint 8 S8-N5 (Story 007) — per-floor first-clear gold bonus, 1-indexed
## table per TR-015. floor_index 0 is undefined sentinel — assert raises in
## debug if hit. Sourced from ADR-0013 §C floor-clear curve.
const FLOOR_CLEAR_BONUS: Dictionary = {1: 100, 2: 250, 3: 500, 4: 1000, 5: 2500}

## The dispatched floor_index for the active run, captured at dispatch() entry.
## Drives the floor_cleared_first_time signal payload. Reset to 0 on RUN_ENDED.
var _dispatched_floor_index: int = 0

## The dispatched biome_id for the active run, captured at dispatch() entry.
## Drives the floor_cleared_first_time signal payload. Reset to "" on RUN_ENDED.
var _dispatched_biome_id: String = ""


# ---------------------------------------------------------------------------
# Dispatch debounce + validation state — Story 003 (TR-026, TR-027, TR-032)
# ---------------------------------------------------------------------------

## Debounce window: a second [method dispatch] call within this many milliseconds
## of a successful first call is silently ignored (push_warning logged). Prevents
## accidental double-dispatch from a UI button held down or a signal storm.
##
## TR-orchestrator-032
const DISPATCH_DEBOUNCE_MS: int = 250

## Wall-clock millisecond stamp of the most recent successful [method dispatch]
## entry. Compared against [code]Time.get_ticks_msec()[/code] on each call.
var _last_dispatch_ms: int = 0


# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

## Zero-arg _init required by ADR-0003 Amendment #3:
## Godot autoload Nodes are instantiated with zero arguments by the engine;
## any required parameter on _init would silently fail instantiation.
##
## Do NOT read or subscribe to other autoloads here — use _ready() instead.
##
## ADR-0003 Amendment #3 Claim 4 [VERIFIED] — autoload.md (2026-04-22).
func _init() -> void:
	pass


## Lazy-default resolver instantiation (TR-024). For each of the 3 DI slots,
## if no spy has been injected via the corresponding setter, instantiate the
## default. Tests inject BEFORE add_child() / scene-tree-attach so this _ready()
## sees the injected spy and skips the default construction.
##
## Rank-safety (ADR-0003 Amendment #1): by the time this _ready() fires, all
## lower-rank autoloads (TickSystem, DataRegistry, SaveLoadSystem, Economy,
## HeroRoster, etc.) have completed their _ready(); resolver `new()` calls
## that need DataRegistry are safe.
##
## TR-orchestrator-023, TR-orchestrator-024 — ADR-0009, ADR-0014
func _ready() -> void:
	if _matchup_resolver == null:
		_matchup_resolver = DefaultMatchupResolverScript.new()
	if _combat_resolver == null:
		_combat_resolver = DefaultCombatResolverScript.new()
	# error_logger remains null in MVP; push_error / push_warning are the default.
	# Story 003+ may inject a recording_logger Callable here per GDD §J.4.


# ---------------------------------------------------------------------------
# DI setters — TR-orchestrator-024
#
# CONVENTION: callers MUST invoke these BEFORE add_child() (or before the
# autoload's _ready fires in production). Calls AFTER _ready() are allowed
# but replace the lazy-default; this is intentional for tests that swap
# resolvers between phases.
# ---------------------------------------------------------------------------

## Injects a CombatResolver spy or alternate implementation. Called by tests
## before [code]add_child(orchestrator)[/code] to replace the lazy default.
##
## TR-orchestrator-024 — ADR-0009, ADR-0010
func set_combat_resolver(r: RefCounted) -> void:
	_combat_resolver = r


## Injects a MatchupResolver spy or alternate implementation.
##
## TR-orchestrator-024 — ADR-0009
func set_matchup_resolver(r: RefCounted) -> void:
	_matchup_resolver = r


## Injects a recording-logger spy. Tests that want to verify the orchestrator
## emitted a specific push_error message connect a logger that records the
## payload (see GDD §J.4 recording_logger Callable).
##
## TR-orchestrator-024 — ADR-0009
func set_error_logger(l: RefCounted) -> void:
	_error_logger = l


## Injects the FloorUnlock dependency for floor-lock validation. Spy or real
## FloorUnlock autoload, both must implement [code]is_unlocked(floor_index: int) -> bool[/code].
##
## TR-orchestrator-027
func set_floor_unlock(fu: RefCounted) -> void:
	_floor_unlock = fu


# ---------------------------------------------------------------------------
# Public dispatch API — Story 003 (TR-026, TR-027, TR-032)
# ---------------------------------------------------------------------------

## Initiates a new dungeon run dispatch. Validates inputs and either advances
## the FSM to DISPATCHING (success path; Story 004 takes over from there to
## build the snapshot + matchup cache) or transitions to RUN_ENDED with a
## [signal validation_failed] emission carrying the rejection reason.
##
## Validation order (early-out on first failure):
##   1. Debounce: second call within [constant DISPATCH_DEBOUNCE_MS] milliseconds
##      is a silent no-op (push_warning logged, no state change, no signal).
##      Stamp updated only on debounce-passing entries — failed validations
##      still consume the debounce window so a UI signal storm is rate-limited.
##   2. State transition: NO_RUN / RUN_ENDED + dispatch_pressed → DISPATCHING.
##      From DISPATCHING / ACTIVE_FOREGROUND / ACTIVE_OFFLINE_REPLAY, the
##      transition matrix rejects the dispatch via push_error and stays put;
##      the dispatch method returns without further work.
##   3. Empty formation: emit `validation_failed("empty_formation", {})` and
##      transition DISPATCHING → RUN_ENDED.
##   4. Floor locked: if [member _floor_unlock] is non-null AND
##      [code]is_unlocked(floor_index)[/code] returns false, emit
##      `validation_failed("floor_locked", {"floor_index": floor_index})` and
##      transition DISPATCHING → RUN_ENDED.
##   5. Success: state stays at DISPATCHING. Story 004 wires the snapshot
##      build + matchup cache + transition to ACTIVE_FOREGROUND.
##
## When [member _floor_unlock] is null (typical pre-production state in
## Sprint 6 before the floor-unlock-system epic ships), the lock check is
## SKIPPED. push_warning is NOT logged — the null-skip is the documented
## fail-open default for the pre-production sprint window.
##
## TR-orchestrator-026, TR-orchestrator-027, TR-orchestrator-032
func dispatch(formation: Array, floor_index: int, biome_id: String) -> void:
	# Reference biome_id to silence unused-arg warning until Story 004 wires
	# the snapshot build that consumes it.
	var _unused_biome: String = biome_id

	# Debounce check — happens BEFORE state transition so a debounced call
	# leaves state untouched (NO_RUN stays NO_RUN, etc.).
	var now_ms: int = Time.get_ticks_msec()
	if _last_dispatch_ms > 0 and now_ms - _last_dispatch_ms < DISPATCH_DEBOUNCE_MS:
		push_warning(
			"[Orchestrator] dispatch debounce hit — call within %d ms of last dispatch ignored"
			% DISPATCH_DEBOUNCE_MS
		)
		return
	_last_dispatch_ms = now_ms

	# State transition: NO_RUN / RUN_ENDED → DISPATCHING via the matrix.
	# Invalid from-states (DISPATCHING / ACTIVE_FOREGROUND / ACTIVE_OFFLINE_REPLAY)
	# get rejected with push_error inside validate_transition and we stay put.
	var next_state: int = DungeonRunStateScript.validate_transition(
		state, DungeonRunStateScript.TRIGGER_DISPATCH_PRESSED
	)
	if next_state == state:
		# Matrix rejected the trigger — push_error already logged.
		return
	_set_state(next_state)  # → DISPATCHING

	# Validation 1: empty formation rejected with named reason.
	if formation.is_empty():
		validation_failed.emit("empty_formation", {})
		_set_state(DungeonRunStateScript.validate_transition(
			state, DungeonRunStateScript.TRIGGER_RUN_ENDED
		))
		return

	# Validation 2: floor lock check (skipped when _floor_unlock is null —
	# pre-production fail-open per doc-comment).
	if _floor_unlock != null and _floor_unlock.has_method("is_unlocked"):
		var unlocked: bool = bool(_floor_unlock.call("is_unlocked", floor_index))
		if not unlocked:
			validation_failed.emit("floor_locked", {"floor_index": floor_index})
			_set_state(DungeonRunStateScript.validate_transition(
				state, DungeonRunStateScript.TRIGGER_RUN_ENDED
			))
			return

	# Validation passed. Build the orchestrator + combat snapshots, transition
	# to ACTIVE_FOREGROUND (which fires the tick subscription via _set_state).
	#
	# Sprint 7 S7-M13 VS harness data path: this is the load-bearing wire
	# from validation success into the live combat loop. Story 004 of the
	# orchestrator epic (S7-S4 — Should Have) will refine the snapshot
	# construction with deeper hero-state copying + DataRegistry floor lookup
	# polish; S7-M13's MVP build is sufficient to drive end-to-end tick combat.
	# Sprint 8 S8-S2 (Story 004): build CombatRunSnapshot first so RunSnapshot
	# can mirror its matchup_cache + enemy_list into orchestrator-persistent
	# fields (TR-012 cache completeness; TR-013 once-only build). The matchup
	# cache is computed exactly ONCE here — subsequent ticks read from the
	# stored cache, never re-resolve.
	_combat_snapshot = _build_combat_snapshot(formation, floor_index, biome_id)
	run_snapshot = _build_run_snapshot(formation, floor_index, biome_id, _combat_snapshot)
	# Sprint 8 S8-S3 (Story 006): capture dispatch context so the
	# floor_cleared_first_time signal can carry biome_id + floor_index when
	# the floor-clear marker fires later in the run.
	_dispatched_floor_index = floor_index
	_dispatched_biome_id = biome_id
	_set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


# ---------------------------------------------------------------------------
# State transition hooks — Sprint 7 Story M12 (TR-orchestrator-007/008/009)
#
# All state mutations flow through [method _set_state] so enter/exit hooks
# can fire at canonical state-boundary moments. ACTIVE_FOREGROUND is the
# only state with hooks today (subscribes to TickSystem.tick_fired on entry,
# unsubscribes on exit) — adding hooks for other states is straightforward.
# ---------------------------------------------------------------------------

## Sets [member state] to [param new_state], firing exit hooks for the prior
## state and entry hooks for the new state. Use this in place of direct
## [code]state = ...[/code] writes so subscriptions and side-effects stay
## paired.
##
## TR-orchestrator-007 — ADR-0010
func _set_state(new_state: int) -> void:
	if new_state == state:
		return  # No-op self-transition.
	# Capture prior state BEFORE mutation so the signal payload is accurate.
	var old_state: int = state
	# Fire exit hooks for the OUTGOING state.
	if state == DungeonRunStateScript.State.ACTIVE_FOREGROUND:
		_exit_active_foreground()
	state = new_state
	# Fire entry hooks for the INCOMING state.
	if state == DungeonRunStateScript.State.ACTIVE_FOREGROUND:
		_enter_active_foreground()
	# Emit state_changed AFTER state is written and hooks are run so listeners
	# observe the fully-settled new state (Story 012 AC-6).
	state_changed.emit(new_state, old_state)


## Connects the [signal TickSystem.tick_fired] subscription. Called by
## [method _set_state] when transitioning INTO ACTIVE_FOREGROUND. Idempotent
## via [method Signal.is_connected] check.
##
## TR-orchestrator-007
func _enter_active_foreground() -> void:
	if not TickSystem.tick_fired.is_connected(_on_tick_fired):
		TickSystem.tick_fired.connect(_on_tick_fired)


## Disconnects the [signal TickSystem.tick_fired] subscription. Called by
## [method _set_state] when transitioning OUT OF ACTIVE_FOREGROUND
## (regardless of next state). Prevents leaked connections — every connect
## has a matching disconnect.
##
## Sprint 8 S8-S3 follow-up (code-review): also resets the dispatch-context
## fields used by the [signal floor_cleared_first_time] payload — without
## this reset, a second dispatch's floor_cleared signal would carry stale
## context if the second dispatch reused the same orchestrator instance
## without going through full re-initialization.
##
## TR-orchestrator-007
func _exit_active_foreground() -> void:
	if TickSystem.tick_fired.is_connected(_on_tick_fired):
		TickSystem.tick_fired.disconnect(_on_tick_fired)
	# Sprint 8 S8-S3 dispatch-context reset. Doc-comments on _dispatched_*
	# fields promised this; the reset is wired here.
	_dispatched_floor_index = 0
	_dispatched_biome_id = ""


## Per-tick handler called by [signal TickSystem.tick_fired]. Calls Combat's
## [code]emit_events_in_range(snapshot, last_emitted, n)[/code] for the new
## tick range. Routes returned events via [method _process_kill_events]
## (Story 006 of orchestrator epic — out of scope for S7-M12).
##
## Defensive guards:
##   - Not in ACTIVE_FOREGROUND → return (signal-storm safety).
##   - [member run_snapshot] is null → return (snapshot not yet built; Story 004).
##   - [param n] <= [member RunSnapshot.last_emitted_tick] → duplicate-tick
##     guard. push_warning ONLY on strict rewind ([param n] < last); equal
##     ticks are a no-op without warning (idle systems may re-emit the
##     current tick during phase-resume).
##
## After a successful Combat call, advances both
## [member RunSnapshot.current_tick] and [member RunSnapshot.last_emitted_tick]
## to [param n].
##
## TR-orchestrator-008, TR-orchestrator-009 — ADR-0010
func _on_tick_fired(n: int) -> void:
	if state != DungeonRunStateScript.State.ACTIVE_FOREGROUND:
		return  # Defensive: only the steady state should drive combat.
	if run_snapshot == null:
		return  # Snapshot not yet built (Story 004 of orchestrator epic).
	if n <= run_snapshot.last_emitted_tick:
		if n < run_snapshot.last_emitted_tick:
			push_warning(
				"[Orchestrator] strict rewind detected: current=%d < last=%d"
				% [n, run_snapshot.last_emitted_tick]
			)
		return  # Duplicate-tick guard (TR-009).
	# Combat call. Sprint 7 S7-M13 data harness: pass the pre-built
	# [member _combat_snapshot] (CombatRunSnapshot) — distinct from
	# [member run_snapshot] (the FSM-ownership snapshot). When _combat_snapshot
	# is null (e.g., test injecting only a spy resolver without going through
	# dispatch), fall back to passing run_snapshot directly so spy tests still
	# work.
	var combat_input: Variant = _combat_snapshot if _combat_snapshot != null else run_snapshot
	var events: Variant = _combat_resolver.emit_events_in_range(
		combat_input, run_snapshot.last_emitted_tick, n
	)
	run_snapshot.current_tick = n
	run_snapshot.last_emitted_tick = n
	_process_kill_events(events)


## Processes [param events] returned by [code]combat_resolver.emit_events_in_range[/code].
##
## Sprint 7 S7-M13 minimal kill-event processing:
##   - Increments [member RunSnapshot.kill_count] by [param events.kills.size()].
##   - On [code]events.first_clear_in_range == true[/code], transitions FSM
##     to RUN_ENDED via [code]validate_transition[/code] with the
##     [code]run_ended[/code] trigger (matrix row 3: ACTIVE_FOREGROUND →
##     RUN_ENDED on run_ended trigger).
##
## Story 006 of orchestrator epic (S7-S5 — Should Have) will extend this
## handler with kill-attribution signals + boss-fanfare emission + Economy
## gold-bonus routing. The S7-M13 MVP only needs to advance kill_count
## and detect floor-clear so the data harness completes the
## DISPATCHING → ACTIVE_FOREGROUND → RUN_ENDED cycle.
##
## Defensive: tolerates spy resolvers that return null (no events to process).
##
## Sprint 8 S8-S3 (Story 006) closure: per-kill processing now also routes
## gold to Economy via [method attribute_kill_gold] and emits the 3 new
## owned signals — [signal enemy_killed] (per kill), [signal boss_killed]
## (when [code]is_boss[/code]), and [signal floor_cleared_first_time] (once
## per dispatch via the [member RunSnapshot.floor_clear_emitted] gate).
##
## TR-orchestrator-008 / 014 / 018 / 022 — ADR-0010 + ADR-0013
func _process_kill_events(events: Variant) -> void:
	if events == null:
		return  # Spy resolvers may return null; no events to process.
	if not ("kills" in events) or not ("first_clear_in_range" in events):
		return  # Defensive duck-type check — incomplete CombatTickEvents.

	var kills_array: Array = events.get("kills") as Array
	if run_snapshot != null:
		run_snapshot.kill_count += kills_array.size()

	# Per-kill processing: gold attribution + per-kill signals. Hoist all
	# loop-invariant lookups (matchup_cache, losing_run flag, Economy autoload)
	# out of the for-loop body — engine-code rule: ZERO tree queries in
	# hot paths. The Economy node lookup in particular was a get_node_or_null
	# call inside the per-kill loop in the initial S8-S3 implementation; the
	# code-review caught it.
	var matchup_cache: Dictionary = {}
	if _combat_snapshot != null and "matchup_cache" in _combat_snapshot:
		matchup_cache = _combat_snapshot.get("matchup_cache") as Dictionary
	var losing_run: bool = false
	if run_snapshot != null:
		losing_run = run_snapshot.losing_run
	# Resolve Economy autoload once, outside the loop. Test envs may not have
	# it registered — null-guard the per-kill call below.
	var economy: Node = get_node_or_null("/root/Economy") if get_tree() != null else null
	var economy_can_add_gold: bool = economy != null and economy.has_method("add_gold")

	for ke: Variant in kills_array:
		# KillEvent fields — duck-typed reads against the value-type contract:
		# enemy_id (StringName), archetype (StringName), tier (int), is_boss (bool).
		var tier: int = int(ke.tier) if "tier" in ke else 1
		var archetype_sn: StringName = (ke.archetype as StringName) if "archetype" in ke else &""
		var advantaged: bool = bool(matchup_cache.get(archetype_sn, false))
		# Gold attribution → Economy. Production Economy.add_gold takes a
		# single int; the "kill" attribution stays implicit at the call site
		# (Economy's gold_changed signal carries a generic "add_gold" reason).
		var gold: int = attribute_kill_gold(tier, advantaged, losing_run)
		if economy_can_add_gold and gold > 0:
			economy.add_gold(gold)
		# Per-kill signals.
		var archetype_str: String = String(archetype_sn)
		enemy_killed.emit(tier, archetype_str, advantaged)
		if "is_boss" in ke and bool(ke.is_boss):
			var enemy_id_str: String = String(ke.enemy_id) if "enemy_id" in ke else ""
			boss_killed.emit(enemy_id_str)

	if bool(events.get("first_clear_in_range")):
		# Sprint 8 S8-N5 (Story 007) — 3-layer idempotency:
		#   Layer 1: Combat reports first_clear_in_range marker per-call (stateless)
		#   Layer 2: run_snapshot.floor_clear_emitted gates per-dispatch re-entry
		#   Layer 3: Economy.try_award_floor_clear's monotonic ledger gates
		#           per-lifetime double-credit
		# The floor_cleared_first_time signal fires only when ALL THREE gates
		# pass — i.e. genuine first-ever clear of this floor in the player's
		# lifetime. Within-dispatch re-entries return at Layer 2; cross-dispatch
		# repeat clears at the same floor return at Layer 3.
		if run_snapshot != null and not run_snapshot.floor_clear_emitted:
			# Layer 2 gate passed — compute bonus + LOSING factor + route Economy.
			var floor_idx: int = _dispatched_floor_index
			var bonus: int = int(FLOOR_CLEAR_BONUS.get(floor_idx, 0))
			# Defensive: assert range matches Economy.try_award_floor_clear contract.
			# Empirical floor 0 / floor 6+ would fail Economy's range guard, so
			# we mirror that here for early-return cleanliness.
			assert(floor_idx >= 1 and floor_idx <= 5,
					"floor_index out of range [1,5]: %d" % floor_idx)
			if losing_run:
				bonus = floori(float(bonus) * LOSING_RUN_LOOT_FACTOR)
			# Layer 3: Economy monotonic-credit gate.
			var awarded: bool = false
			if economy_can_add_gold and bonus > 0 and economy.has_method("try_award_floor_clear"):
				awarded = bool(economy.try_award_floor_clear(floor_idx, bonus))
			# Layer 2 flag set regardless of awarded — prevents within-dispatch
			# re-entry from re-calling Economy (whose monotonic gate would block
			# anyway, but skipping the call is cheaper).
			run_snapshot.floor_clear_emitted = true
			# Signal fires only on genuine first-ever-clear (Economy gated).
			# Subsequent dispatches that re-clear the same floor see awarded=false
			# and DO NOT fire the player-facing fanfare — a critical UX rule per
			# ADR-0002 (losing-first-clear reclaimable on win) so the fanfare
			# stays a meaningful "first time you've EVER done this" moment.
			if awarded:
				floor_cleared_first_time.emit(floor_idx, _dispatched_biome_id, losing_run)
		# Floor cleared — transition ACTIVE_FOREGROUND → RUN_ENDED.
		var next_state: int = DungeonRunStateScript.validate_transition(
			state, DungeonRunStateScript.TRIGGER_RUN_ENDED
		)
		_set_state(next_state)


## Sprint 8 S8-S3 (Story 006 — TR-014): per-kill gold attribution formula.
##
## Formula: [code]floori(BASE_KILL[tier] * matchup_mult * loot_factor)[/code]
##
##   - [code]BASE_KILL[tier][/code]: base gold lookup, 0 for unmapped tiers
##   - [code]matchup_mult[/code]: [constant MATCHUP_MULT_ADV] (1.5) when
##     advantaged, [constant MATCHUP_MULT_DIS] (0.7) otherwise
##   - [code]loot_factor[/code]: [constant LOSING_RUN_LOOT_FACTOR] (0.5) when
##     [param losing_run], 1.0 otherwise
##
## Output range for MVP tiers (1..5): floori(5*0.7*0.5)=1 lower bound,
## floori(100*1.5*1.0)=150 upper bound. The story spec calls for [5, 120]
## but the empirical bounds depend on MVP tier mix; this method returns the
## arithmetic result without clamping (callers can cap if needed).
##
## TR-orchestrator-014 — ADR-0013 §C
func attribute_kill_gold(tier: int, advantaged: bool, losing_run: bool) -> int:
	var base: int = int(BASE_KILL.get(tier, 0))
	var matchup_mult: float = MATCHUP_MULT_ADV if advantaged else MATCHUP_MULT_DIS
	var loot_factor: float = LOSING_RUN_LOOT_FACTOR if losing_run else 1.0
	return floori(float(base) * matchup_mult * loot_factor)


# ---------------------------------------------------------------------------
# Snapshot construction — Sprint 7 S7-M13 (VS harness data path)
#
# Story 004 of orchestrator epic (S7-S4 — Should Have) will refine these with
# proper deep-copying of HeroInstance fields + biome resolution; the S7-M13
# MVP build populates enough fields for the end-to-end data path to work.
# ---------------------------------------------------------------------------

## Builds the FSM-ownership [RunSnapshot] at DISPATCHING. Sprint 8 S8-S2
## (Story 004) implementation per ADR-0014:
##
##   - **TR-004 deep copy**: each hero in [param formation] is captured as a
##     per-hero Dictionary inside [code]formation_snapshot.heroes[/code]; the
##     entire payload is then [code]duplicate(true)[/code]'d. Mutations to the
##     source HeroRoster after dispatch do NOT propagate into the snapshot.
##   - **TR-006 floor by id**: [code]floor_id: String[/code] stored (composite
##     of biome_id + floor_index for the MVP harness). Save/load round-trip
##     resolves via DataRegistry on hydrate; null → NO_RUN handling lives on
##     Story 010's load_save_data path (not S8-S2 scope).
##   - **TR-012 cache completeness**: [code]matchup_cache[/code] mirrored
##     from the [param combat_snap]'s pre-built cache — guarantees one entry
##     per archetype in the floor's enemy_list. Zero KeyError possible during
##     replay because the cache is keyed on the same archetype names that
##     drive [code]_kill_schedule_for_loop[/code].
##   - **TR-013 once-only**: this method is called exactly once per dispatch.
##     The cache is consumed verbatim from [param combat_snap] (which itself
##     called [code]build_matchup_cache[/code] with deduplication, ≤5 calls
##     per MVP floor per TR-012). No resolver calls happen here.
##
## [param combat_snap] is the already-built [CombatRunSnapshot] — sequenced
## first in [method dispatch] so its matchup_cache + enemy_list are available
## for mirroring into the orchestrator-side persistent snapshot.
func _build_run_snapshot(formation: Array, floor_index: int, biome_id: String,
		combat_snap: RefCounted = null) -> RunSnapshot:
	var snap: RunSnapshot = RunSnapshot.new()

	# TR-004: deep-copy per-hero state. Capture all duck-typed fields the
	# orchestrator + its consumers (Economy, save/load, UI) read post-dispatch.
	# `instance_ids` is preserved for legacy callers that hydrated against the
	# pre-S8-S2 schema; `heroes` is the new canonical per-hero deep payload.
	#
	# NOTE: `Object.get(name)` takes ONE argument (no default-arg overload like
	# Dictionary.get). Use `"field" in hero` gating for optional fields rather
	# than `hero.get("field", default)`.
	var ids: Array = []
	var heroes: Array = []
	for hero: Variant in formation:
		if hero == null or not ("instance_id" in hero):
			continue
		ids.append(int(hero.get("instance_id")))
		var hero_dict: Dictionary = {
			"instance_id": int(hero.get("instance_id")),
		}
		if "class_id" in hero:
			hero_dict["class_id"] = str(hero.get("class_id"))
		else:
			hero_dict["class_id"] = ""
		if "current_level" in hero:
			hero_dict["current_level"] = int(hero.get("current_level"))
		else:
			hero_dict["current_level"] = 1
		# Optional fields — copy when present (display_name, xp).
		if "display_name" in hero:
			hero_dict["display_name"] = str(hero.get("display_name"))
		if "xp" in hero:
			hero_dict["xp"] = int(hero.get("xp"))
		heroes.append(hero_dict)
	# `.duplicate(true)` is a no-op on a freshly-built dict-of-primitives, but
	# explicit per TR-004's "deep copy via .duplicate(true)" requirement —
	# documents the intent and protects against future per-hero nested fields.
	snap.formation_snapshot = ({"instance_ids": ids, "heroes": heroes} as Dictionary).duplicate(true)

	# TR-006: floor_id as String. Composite of biome_id + floor_index for the
	# MVP harness; Story 010 will refine to a canonical Floor.id from
	# DataRegistry. Empty string sentinel reserved for NO_RUN.
	snap.floor_id = "%s_floor_%d" % [biome_id, floor_index]

	# TR-012 + TR-013: mirror matchup_cache + enemy archetype list from the
	# already-built CombatRunSnapshot. Cache is built ONCE upstream; this is
	# verbatim duplication, NOT recomputation.
	if combat_snap != null:
		if "matchup_cache" in combat_snap:
			snap.matchup_cache = (combat_snap.get("matchup_cache") as Dictionary).duplicate(true)
		if "enemy_list" in combat_snap:
			# kill_schedule mirrors enemy_list shape — the orchestrator's
			# persistent walk reference. Keys remain identical to combat-side
			# entries so save/load round-trip is loss-less.
			snap.kill_schedule = (combat_snap.get("enemy_list") as Array).duplicate(true)

	snap.current_tick = 0
	snap.last_emitted_tick = 0
	snap.loop_counter = 0
	snap.kill_count = 0
	return snap


## Defensive helper: resolves a Floor resource by [member RunSnapshot.floor_id]
## via DataRegistry. Returns null when the id can't be resolved (content was
## removed between save and load). Callers in load_save_data (Story 010 — not
## yet wired) will route a null return to NO_RUN + push_warning per TR-006.
##
## Sprint 8 S8-S2 — TR-006 hook. Currently called from tests; Story 010 will
## consume from the load_save_data path.
func resolve_floor_by_snapshot_id(floor_id: String) -> Resource:
	if floor_id.is_empty():
		return null
	return DataRegistry.resolve("floors", floor_id)


## Builds the combat-side [CombatRunSnapshot] at DISPATCHING. Uses the
## injected [member _combat_resolver] (when it's a [DefaultCombatResolver])
## to compute formation_dps_per_tick + hp_bonus_factor; falls back to
## sentinel values when the injected resolver lacks those methods (spy
## injection paths).
##
## [param formation], [param floor_index], [param biome_id] arrive unchanged
## from [method dispatch]'s caller — the orchestrator owns the floor lookup
## via DataRegistry.
##
## Returns a fresh [CombatRunSnapshot] suitable for passing to
## [code]combat_resolver.emit_events_in_range[/code].
func _build_combat_snapshot(formation: Array, floor_index: int, biome_id: String) -> RefCounted:
	var snap: CombatRunSnapshot = CombatRunSnapshot.new()
	snap.dispatched_at_tick = 0
	# Compute formation_dps_per_tick via the injected resolver IF it has the
	# method (DefaultCombatResolver does; spy resolvers may not). On miss,
	# default to a non-zero sentinel so combat doesn't div-by-zero.
	if _combat_resolver != null and _combat_resolver.has_method("formation_dps_per_tick"):
		snap.formation_dps_per_tick = float(_combat_resolver.call("formation_dps_per_tick", formation))
	else:
		snap.formation_dps_per_tick = 1.0
	# hp_bonus_factor — placeholder 1.0 until Story 004 wires real floor data.
	snap.hp_bonus_factor = 1.0
	# enemy_list — fetched from Floor data via DataRegistry. Floor lookup is
	# composite-keyed: biome_id + floor_index. The biome-dungeon-database
	# epic Story 003 (Forest Reach MVP content) provides the data; for the
	# S7-M13 MVP harness, default to a 3-enemy synthetic list when the lookup
	# fails so the data path completes.
	var floor_data: Resource = _resolve_floor(biome_id, floor_index)
	if floor_data != null and "enemy_list" in floor_data:
		snap.enemy_list = (floor_data.get("enemy_list") as Array).duplicate(true)
	else:
		# Synthetic 3-enemy default: gives integration tests a deterministic
		# floor to drive ticks against.
		snap.enemy_list = [
			{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10, "base_attack": 1},
			{"id": &"e2", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10, "base_attack": 1},
			{"id": &"e3", "archetype": &"bruiser", "tier": 2, "is_boss": true, "base_hp": 15, "base_attack": 2},
		]
	# Build matchup_cache by inspecting enemy archetypes + invoking the
	# injected matchup resolver. Empty when matchup_resolver is null/spy
	# without the needed method.
	var archetypes: Array[String] = []
	for entry: Variant in snap.enemy_list:
		var arch: String = str((entry as Dictionary).get("archetype", ""))
		if not arch.is_empty():
			archetypes.append(arch)
	if _combat_resolver != null and _combat_resolver.has_method("build_matchup_cache"):
		snap.matchup_cache = _combat_resolver.call(
			"build_matchup_cache", formation, archetypes, _matchup_resolver
		) as Dictionary
	else:
		snap.matchup_cache = {}
	# loops_per_run: 1 for MVP (single rotation through enemy_list = floor clear).
	# Story 004 will compute this from floor difficulty + formation throughput.
	snap.loops_per_run = 1
	return snap


## Looks up Floor resource by [param biome_id] + [param floor_index]. Returns
## null if the lookup fails (biome-dungeon-database not populated in test env).
##
## Sprint 7 S7-M13 MVP — uses DataRegistry for "biomes" / "dungeons" lookup;
## the actual Floor resolution is composite (biome → dungeon → floor). For
## the harness MVP, attempts a direct lookup via "floors" category if
## available; falls back to null.
func _resolve_floor(biome_id: String, floor_index: int) -> Resource:
	# Try direct floors category first (some test envs / future content shape).
	var direct_id: String = "%s_floor_%d" % [biome_id, floor_index]
	var floor_data: Resource = DataRegistry.resolve("floors", direct_id)
	if floor_data != null:
		return floor_data
	# Fall back: navigate biome → dungeon → floor.
	var biome: Resource = DataRegistry.resolve("biomes", biome_id)
	if biome == null or not ("dungeon_ids" in biome):
		return null
	var dungeon_ids: Array = biome.get("dungeon_ids") as Array
	if dungeon_ids.is_empty():
		return null
	var dungeon: Resource = DataRegistry.resolve("dungeons", str(dungeon_ids[0]))
	if dungeon == null or not ("floors" in dungeon):
		return null
	var floors: Array = dungeon.get("floors") as Array
	if floor_index < 1 or floor_index > floors.size():
		return null
	return floors[floor_index - 1] as Resource
