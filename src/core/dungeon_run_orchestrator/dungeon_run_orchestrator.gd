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

## Phase 1 defeat verdict (GDD #34 / ADR-0021). Computed ONCE at [method dispatch]
## from [member _combat_snapshot] via the resolver's [code]compute_run_outcome[/code]
## (the single source of truth shared with the offline batch — parity by
## construction). [member _run_won] is true when the floor clears before
## [code]formation_total_hp[/code] depletes; false = DEFEAT. [member _run_defeat_tick]
## is the absolute tick at which HP→0 (relative to dispatch; -1 when the run wins
## or the resolver is a spy without [code]compute_run_outcome[/code]).
##
## Spy resolvers default to WIN ([member _run_won] = true) so pre-pivot spy tests
## that never built a real snapshot keep their always-clear behavior.
var _run_won: bool = true
var _run_defeat_tick: int = -1


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

## Phase 1 defeat (GDD #34 / ADR-0021 — AC-34-05). Fires ONCE per dispatch when a
## run loses the two-sided HP race: the party's formation_total_hp depletes before
## the floor clears. Emitted from [method _on_tick_fired] when the tick clock
## reaches [member _run_defeat_tick], BEFORE the ACTIVE_FOREGROUND → RUN_ENDED
## transition (so subscribers see the run still active). Carries the same dispatch
## context as [signal floor_cleared_first_time] (the floor stays as the retry
## frontier). A DEFEATED run credits ZERO loot — no [signal enemy_killed] /
## [signal floor_cleared_first_time] fire on a defeat path.
##
## AudioRouter / Victory-Moment screen subscribe for the defeat cue + zero-loot
## summary. The injured-party recovery (Phase 3) keys off this signal.
@warning_ignore("unused_signal")
signal run_defeated(floor_index: int, biome_id: String)

## Class Synergy V1.0 first-pass (Sprint 21 S21-S2 / Story 3) — dispatch-time
## signal fired when a run begins with an active synergy. Emitted from
## [method dispatch] after the state transitions to ACTIVE_FOREGROUND.
## NOT fired when [code]run_snapshot.synergy_id == ""[/code] (no synergy
## active for the run).
##
## Per `class-synergy-system.md` §C.4 audio integration: AudioRouter
## subscribes and fires `sfx_class_synergy_dispatched` (warm sting) ONCE
## per dispatch. NOT throttled — the dispatch event is naturally rate-
## limited by the orchestrator's DISPATCH_DEBOUNCE_MS (250ms).
##
## [param synergy_id]: the run's active synergy id String. Always non-empty
##   when the signal fires (per the no-emit-on-empty contract). One of
##   "steel_wall", "arcane_elite", "triple_threat" in V1.0 first-pass.
##
## design/gdd/class-synergy-system.md §C.4 + AC-CS-14.
@warning_ignore("unused_signal")
signal class_synergy_dispatched_signal(synergy_id: String)


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
## Story 007 (TR-026) — widened from `RefCounted` to `Object` so the lazy-bind
## in `_ready()` can assign /root/FloorUnlock (which is a Node autoload, not
## RefCounted). The duck-typed `has_method("is_unlocked")` check at the call
## site already enforces the contract; the field type just needs to accept
## both Node + RefCounted impls.
var _floor_unlock: Object = null


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

# Phase 1 (GDD #34 / ADR-0021): LOSING_RUN_LOOT_FACTOR (half-loot on a losing run)
# is RETIRED. A run now either WINS (full loot) or is DEFEATED (zero loot, ends
# early — the per-kill loop never runs). There is no half-loot middle state.

# ---------------------------------------------------------------------------
# Class Synergy V1.0 first-pass — Sprint 21 S21-S1 (Story 2) constants.
#
# Per design/gdd/class-synergy-system.md §G Tuning Knobs. Cozy-register hard
# floor (OQ-32-6 + AC-CS-16): all synergy multipliers ≤ 1.5. Current first-pass
# uses ≤ 1.25 — well under the cap. Test: a static-analysis CI test asserts
# all four constants are ≤ 1.5 (cozy_register_cap_test.gd).
# ---------------------------------------------------------------------------

## Steel Wall (3 Warriors) gold multiplier vs `archetype = "bruiser"`.
## Conditional — applies only when the formation is 3 Warriors AND the kill
## archetype is bruiser. Per GDD §C.1 + §D.2 + AC-CS-06/07.
const STEEL_WALL_GOLD_MULT: float = 1.25
const BASTION_GOLD_MULT: float = 1.25
const VOLLEY_GOLD_MULT: float = 1.25
const FRENZY_GOLD_MULT: float = 1.25
const VIGIL_XP_MULT: float = 1.20

## Triple Strike (3 Rogues) gold multiplier vs `archetype = "armored"`.
## Conditional — applies only when the formation is 3 Rogues AND the kill
## archetype is armored. Structurally parallel to Steel Wall; added in the
## 2026-05-14 GDD re-review to close the 3-Rogue asymmetric-class-treatment
## gap. Per GDD §C.1 + §D.2 + AC-CS-22/23.
const TRIPLE_STRIKE_GOLD_MULT: float = 1.25

## Triple Threat (1W+1M+1R) gold multiplier — unconditional.
## Per GDD §C.1 + §D.2 + AC-CS-08.
const TRIPLE_THREAT_GOLD_MULT: float = 1.15

## Arcane Elite (3 Mages) XP multiplier — unconditional.
## Per GDD §C.1 + §D.3 + AC-CS-10.
const ARCANE_ELITE_XP_MULT: float = 1.20

## Base XP per tier-1 kill (V1.0 introduces; MVP ships with stub +1-per-clear
## per S10-M4). XP per kill = BASE_XP_PER_KILL × tier × synergy_multiplier.
## Per GDD §D.3.
const BASE_XP_PER_KILL: int = 10

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


## Returns the biome_id captured at dispatch() entry, or empty string if no
## run is currently dispatched. Sprint 19 S19-M3: DungeonRunView reads this
## in [code]on_enter[/code] to drive the BiomeBackground palette. The
## underlying [code]_dispatched_biome_id[/code] stays private (write-once at
## dispatch + reset on RUN_ENDED); this getter is the read-only public surface.
##
## Usage:
## [codeblock]
##   var biome: String = DungeonRunOrchestrator.get_dispatched_biome_id()
##   if not biome.is_empty():
##       biome_background.set_biome(biome)
## [/codeblock]
func get_dispatched_biome_id() -> String:
	return _dispatched_biome_id


## Returns the floor_index captured at dispatch() entry, or 0 if no run is
## active. Sprint 25 S25-M3-rev — exposes the dispatched floor for screens
## that need per-floor visual modulation (DungeonRunView passes this to
## BiomeBackground.set_biome_for_floor so the boss floor visually reads as
## distinct from regular floors).
##
## Usage:
## [codeblock]
##   var biome: String = DungeonRunOrchestrator.get_dispatched_biome_id()
##   var floor_idx: int = DungeonRunOrchestrator.get_dispatched_floor_index()
##   if not biome.is_empty():
##       biome_background.set_biome_for_floor(biome, floor_idx)
## [/codeblock]
func get_dispatched_floor_index() -> int:
	return _dispatched_floor_index


## Returns the 1-based floor index of the currently active run, or [code]0[/code]
## when no run is active (state == NO_RUN or RUN_ENDED).
##
## Semantic alias for [method get_dispatched_floor_index] introduced by S28-G1
## so Economy's foreground drip subscription ([code]Economy._on_tick[/code]) can
## resolve the active floor with a name that reads naturally at the call site
## ("active" vs "dispatched"). Both methods read the same underlying
## [member _dispatched_floor_index] field; neither mutates state.
##
## Returns [code]0[/code] when:
##   - State is NO_RUN (no dispatch has occurred this session).
##   - State is RUN_ENDED (run finished; [member _dispatched_floor_index] reset to 0
##     by [method _exit_active_foreground]).
##
## S28-G1 — Economy foreground drip (GDD §C.2.1 / §D.1).
func get_active_floor_index() -> int:
	return _dispatched_floor_index


# ---------------------------------------------------------------------------
# Offline replay infrastructure — Sprint 11 S11-X7 / OfflineProgressionEngine
# GDD §F + OQ-OE-6 lockstep. Mirrors the Economy shape from S11-X6 / ADR-0013
# Amendment #1. NOT persisted — transient per-replay-cycle state only.
# ---------------------------------------------------------------------------

## When [code]true[/code], [signal floor_cleared_first_time] emit sites
## accumulate into [member _offline_pending_first_clears] instead of emitting
## per-call. Cleared by [method flush_offline_signals] after the aggregate
## post-replay emission.
##
## Set externally by OfflineProgressionEngine (rank 15) at the start of the
## chunk loop. Foreground gameplay code MUST NOT touch this flag —
## compute_offline_batch (Sprint 12+ Story 010) is the only legitimate
## production caller of the offline-replay path.
##
## ADR-0014 §signal emission policy + per_chunk_domain_signal_emission_during_offline_replay
## forbidden pattern.
var _is_offline_replay: bool = false

## Floor-clear payloads pending aggregate emission after offline replay
## completes. Each entry is a Dictionary
## [code]{floor_index: int, biome_id: String, losing_run: bool}[/code]
## matching the [signal floor_cleared_first_time] payload arity.
##
## Insertion order is preserved on flush per OfflineProgressionEngine GDD
## §C.3 ("first_clear_awarded fires POST-replay for each first-cleared
## floor in the offline window" — equivalent semantic for floor_cleared_first_time).
var _offline_pending_first_clears: Array[Dictionary] = []

## Per-tier kill count accumulator for offline replay XP batching per Hero
## Leveling GDD #15 §E.9 / AC-15-11. Populated by
## [method compute_offline_batch] (Sprint 12+ Story 010 — currently
## scaffold-only since the orchestrator's compute_offline_batch is not yet
## implemented; the OfflineProgressionEngine's [code]has_method[/code] guard
## makes the call a no-op until it lands). [method flush_offline_signals]
## reads this accumulator + [member _offline_pending_first_clears] to compute
## a single batched XP-grant per dispatched-formation hero (§E.9: cascade
## fires post-replay rather than per-tick).
##
## Cleared on flush per the existing first_clears + flag-clear pattern.
##
## Hero Leveling GDD #15 §E.9 / AC-15-11
var _offline_pending_kills_by_tier: Dictionary = {}

## Offline-replay combat-batch state (Story 010 landing — the feeder that makes
## the OfflineProgressionEngine kills/floors/XP branch actually run). Transient
## per-replay-cycle; reset by [method flush_offline_signals].
##
## [method compute_offline_batch] is called once per OfflineProgressionEngine
## chunk. The combat resolver counts kills in the window
## [code](dispatched_at_tick, dispatched_at_tick + tick_budget][/code], where
## [code]dispatched_at_tick[/code] is BOTH the schedule anchor and the window-low
## bound. We re-anchor it to a running cursor each chunk and pass the chunk's
## budget, so each chunk processes exactly its own [code](cursor, cursor + chunk][/code]
## window in O(chunk) work (the resolver returns as soon as a scheduled kill
## exceeds the window edge — no cumulative re-walk, so long replays don't blow up
## the per-chunk wall-time / chunk count). The kill schedule is periodic
## (period = ticks_per_loop), so contiguous equal windows tile to the correct
## total; chunk-size adaptation introduces only sub-loop boundary rounding,
## negligible for an offline kill estimate.
var _offline_combat_snapshot: RefCounted = null
var _offline_replay_cursor: int = 0

## Phase 1 (GDD #34 / ADR-0021): the offline replay's WIN/DEFEAT verdict, computed
## ONCE on the first chunk via the resolver's `compute_run_outcome` — the SAME
## source of truth the foreground dispatch uses, so offline + foreground agree by
## construction (AC-34-03). DEFEAT means the dispatched formation loses the
## two-sided HP race on this floor; offline progress is then forfeited entirely
## (zero kills, zero floor-clear bonus, zero drip — the party is stuck dying on a
## floor it cannot clear). Defaults true so spy resolvers without
## `compute_run_outcome` preserve the pre-pivot always-clear behavior.
var _offline_run_won: bool = true

## Test-injection seam mirroring [code]Economy.set_offline_replay_inputs[/code].
## Production leaves these empty/zero and the live HeroRoster formation +
## dispatched floor/biome are resolved instead.
var _offline_replay_formation_override: Array = []
var _offline_replay_floor_index_override: int = 0
var _offline_replay_biome_id_override: String = ""

## Loop budget for the offline snapshot. The formation grinds the dispatched
## floor for the whole offline window (kills scale with time, consistent with
## the linear-in-time Economy gold drip), so we give the resolver a large loop
## budget. The resolver returns as soon as a scheduled kill exceeds the window
## edge, so unused loops cost nothing — this is just an upper bound well past
## any offline cap.
const _OFFLINE_LOOPS_CAP: int = 1_000_000


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

## Story 013 — buffered state_changed emit for the SceneManager-TRANSITIONING
## window.
##
## Empty Dictionary when no buffered emit is pending. When _set_state fires
## while SceneManager.state == TRANSITIONING, the (new_state, old_state) pair
## is captured here instead of emitted directly. SceneManager.transition_complete
## triggers a one-shot replay via [method _replay_buffered_state_change].
##
## Coalesce semantic: if multiple state changes occur during one TRANSITIONING
## window, only the most recent (terminal) state is replayed. The "old_state"
## stored is the state at the time of the FIRST buffered transition (so the
## emit reflects the cross-transition transition, not the most recent
## intermediate hop).
##
## Intentionally a Dictionary rather than typed fields so the empty-vs-
## populated check is a single is_empty() call.
##
## TR-orchestrator-014-001 / TR-orchestrator-014-004 — Story 013.
var _buffered_state_change: Dictionary = {}

## Last successful dispatch intent — captured in [method dispatch] right
## before the state transition to ACTIVE_FOREGROUND (i.e. all validations
## passed). Empty Dictionary [code]{}[/code] when no successful dispatch
## has occurred this session. Schema (when populated):
##
##   - [code]formation[/code]: Array (deep copy of [method dispatch]'s
##     [param formation] argument).
##   - [code]floor_index[/code]: int (1-5).
##   - [code]biome_id[/code]: String.
##
## NOT persisted in the save namespace — session-only. After game close →
## reopen the field resets to {}; the player must make a deliberate dispatch
## via the formation_assignment screen first. This is intentional cozy-UX
## scope: the re-dispatch shortcut surfaces only AFTER deliberate dispatch
## in this session (avoids first-launch confusion with an unfamiliar
## bypass button).
##
## Read by main_menu.gd to toggle the RedispatchButton visibility via
## [method get_last_dispatch_intent].
##
## Sprint 14 S14-N2 (5-sprint carry-forward from S10-N2)
var last_dispatch_intent: Dictionary = {}


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

	# floor-unlock-system/story-007 (TR-026) — lazy-bind /root/FloorUnlock as
	# the FloorUnlock dependency when no spy was pre-injected via
	# set_floor_unlock(). Production: the autoload at /root/FloorUnlock binds
	# automatically. Tests: pre-inject a spy via set_floor_unlock() BEFORE
	# add_child() to override; the lazy-bind here sees `_floor_unlock != null`
	# and skips. Removes the previous test-env null-fail-open path from
	# production runs (was: dispatch() skipped floor-lock check when
	# _floor_unlock was null; now: production always has a bound dependency).
	if _floor_unlock == null:
		var fu: Node = (
			get_node_or_null("/root/FloorUnlock") if get_tree() != null else null
		)
		if fu != null and fu.has_method("is_unlocked"):
			_floor_unlock = fu

	# Story 008 — subscribe to FormationAssignment.formation_reassignment_committed
	# so mid-run formation reassignment cascades: ACTIVE_FOREGROUND → RUN_ENDED →
	# DISPATCHING (new formation). Per ADR-0001 the formation is locked at dispatch;
	# attempting reassignment during a run terminates the current run and
	# immediately re-dispatches with the new lineup. `formation_browse_opened` is
	# intentionally NOT subscribed (TR-021: read-only signal, no state change).
	_subscribe_to_formation_reassignment()


## Story 008 — subscribes to [signal FormationAssignment.formation_reassignment_committed]
## via the autoload at [code]/root/FormationAssignment[/code].
##
## Idempotent: if the connection already exists (e.g., the autoload was
## resolved + subscribed in an earlier _ready that re-fired during scene
## reload), a duplicate connection is skipped via [method Signal.is_connected].
##
## Test envs without the autoload (FormationAssignment not registered) silently
## skip the subscription. The cascade behavior in those envs requires direct
## handler invocation via [method _on_formation_reassignment_committed].
##
## TR-orchestrator-020, ADR-0001.
func _subscribe_to_formation_reassignment() -> void:
	var fa: Node = (
		get_node_or_null("/root/FormationAssignment") if get_tree() != null else null
	)
	if fa == null or not fa.has_signal("formation_reassignment_committed"):
		return
	if not fa.formation_reassignment_committed.is_connected(_on_formation_reassignment_committed):
		fa.formation_reassignment_committed.connect(_on_formation_reassignment_committed)


## Story 011 (TR-orchestrator-029) — UI / OfflineProgressionEngine entry point
## for offline-replay errors per ADR-0014.
##
## When an error occurs during offline replay (e.g., resolver returned malformed
## data, RNG seed mismatch detected, internal invariant violation), the caller
## (typically OfflineProgressionEngine) invokes this method to:
##   1. Emit [signal validation_failed] with reason `"offline_replay_error"`
##      and a payload carrying [param partial_gold] — the gold credited to
##      Economy BEFORE the error occurred. Per ADR-0014: NO ROLLBACK. The
##      partial gold is intentionally retained because it was already added
##      via [code]Economy.add_gold[/code] during the replay loop.
##   2. Transition to [enum DungeonRunState.State.RUN_ENDED]. Allowed from
##      ACTIVE_OFFLINE_REPLAY (the canonical error-from-replay edge) AND
##      from any other state defensively (a caller invoking this method
##      from an unusual state still gets the visible run-ended outcome).
##
## Idempotent: calling twice is safe — the signal emits twice (caller is
## responsible for not double-reporting), but the state transition is a
## no-op self-transition the second time per [method _set_state]'s guard.
##
## Example (OfflineProgressionEngine error-handling):
##   [codeblock]
##   if not _try_replay(result, tick_budget):
##       DungeonRunOrchestrator.report_offline_replay_error(result.total_gold)
##   [/codeblock]
##
## TR-orchestrator-029, ADR-0014.
func report_offline_replay_error(partial_gold: int) -> void:
	validation_failed.emit("offline_replay_error", {"partial_gold": partial_gold})
	_set_state(DungeonRunStateScript.State.RUN_ENDED)


## Story 011 (TR-orchestrator-031) — flips [member RunSnapshot.floor_was_valid]
## to `false` for the active run + logs the authoring-bug diagnostic per
## ADR-0014.
##
## Called by OfflineProgressionEngine (or other offline-replay infrastructure)
## when an empty `kill_schedule` is detected AND the source Floor's archetype
## list is verified missing/invalid — distinguishing the "lost badly" case
## (kill_schedule empty + valid archetypes) from the "floor authoring bug"
## case (kill_schedule empty + missing archetype data).
##
## Side-effects:
##   - [member run_snapshot.floor_was_valid] = `false` (the field defaults to
##     `true` on snapshot construction; this flips it).
##   - [code]push_error[/code] with the floor_id for surfacing the authoring
##     bug at QA / playtest time. Per ADR-0014, this is a fail-loud surface
##     so the bug is caught before ship rather than silently degrading the
##     player's offline run.
##
## Defensive: if [member run_snapshot] is null (NO_RUN state, or test setup
## without a snapshot), this is a silent no-op. The caller is responsible
## for only invoking this when there's an active run to mark.
##
## TR-orchestrator-031, ADR-0014.
func mark_floor_invalid_for_offline_replay() -> void:
	if run_snapshot == null:
		return
	run_snapshot.floor_was_valid = false
	push_error(
		"[Orchestrator] floor '%s' produced empty kill_schedule with no valid archetypes — likely authoring bug"
		% run_snapshot.floor_id
	)


## Story 008 — handles the mid-run formation reassignment cascade per ADR-0001.
##
## Sequence (ACTIVE_FOREGROUND only — other states are silent no-ops):
##   1. Capture the dispatched floor_index + biome_id BEFORE state transition
##      (the `dispatch()` call below will repopulate these).
##   2. Transition ACTIVE_FOREGROUND → RUN_ENDED via the validated state-machine
##      path. The transition matrix already permits this edge with the
##      `run_ended` trigger (matrix row 3).
##   3. Clear the dispatch debounce stamp so the cascade re-dispatch is NOT
##      rejected as a rapid-fire double-dispatch. The cascade is internally
##      triggered by player intent (formation commit), not a UI signal storm,
##      so the debounce protection doesn't apply here.
##   4. Call [method dispatch] with the new formation + the captured floor /
##      biome ids. This advances RUN_ENDED → DISPATCHING and Story 004's
##      snapshot-build path takes over from there.
##
## Non-ACTIVE_FOREGROUND states (NO_RUN, DISPATCHING, RUN_ENDED, ACTIVE_OFFLINE_REPLAY)
## are silent no-ops — the player can re-arrange the formation freely outside
## a live run; only mid-run reassignment cascades.
##
## [param new_formation]: the new formation array from FormationAssignment's
##   commit. Forwarded verbatim to [method dispatch] which validates it
##   (empty-formation rejection still applies — passing an empty Array here
##   would dispatch then fail validation at dispatch's own guard).
##
## TR-orchestrator-020, TR-orchestrator-021 — ADR-0001.
func _on_formation_reassignment_committed(new_formation: Array) -> void:
	if state != DungeonRunStateScript.State.ACTIVE_FOREGROUND:
		return
	# Capture pre-cascade dispatch context. After _set_state(RUN_ENDED) +
	# dispatch(), these fields will be overwritten — so snapshot first.
	var captured_floor_index: int = _dispatched_floor_index
	var captured_biome_id: String = _dispatched_biome_id
	# Cascade step 1: ACTIVE_FOREGROUND → RUN_ENDED via the validated transition.
	_set_state(DungeonRunStateScript.State.RUN_ENDED)
	# Bypass dispatch debounce — the cascade is internally-triggered, not a
	# UI signal storm. Without this clear, a cascade firing within
	# DISPATCH_DEBOUNCE_MS of the original dispatch would be silently rejected.
	_last_dispatch_ms = 0
	# Cascade step 2: RUN_ENDED → DISPATCHING (with new formation).
	dispatch(new_formation, captured_floor_index, captured_biome_id)


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
func set_floor_unlock(fu: Object) -> void:
	# TR-026: param widened from `RefCounted` to `Object` to accept both Node
	# (production /root/FloorUnlock autoload) and RefCounted (test spies).
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

	# Validation 3: injured-hero gate (GDD #34 Phase 3 / ADR-0021 — AC-34-04).
	# A formation containing any hero still recovering from a defeat injury
	# cannot be dispatched until recovery elapses (wall-clock, so it heals while
	# offline). Checked AFTER the floor-lock so a locked floor still reports
	# `floor_locked`. Fail-open when HeroRoster is absent (lean test envs),
	# mirroring the floor-lock null guard. injured_ids carries the offenders so
	# the UI can highlight them.
	var roster_for_injury: Node = (
		get_node_or_null("/root/HeroRoster") if get_tree() != null else null
	)
	if roster_for_injury != null:
		var injury_now_ms: int = TickSystem.now_ms()
		var injured_ids: Array[int] = []
		for hero: Variant in formation:
			if hero == null or not ("instance_id" in hero):
				continue
			var hid: int = int(hero.get("instance_id"))
			if roster_for_injury.is_hero_injured(hid, injury_now_ms):
				injured_ids.append(hid)
		if not injured_ids.is_empty():
			validation_failed.emit("hero_injured", {"injured_ids": injured_ids})
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
	# Phase 1 (GDD #34 / ADR-0021): compute the run verdict ONCE here from the
	# combat snapshot via the resolver's `compute_run_outcome` — the SINGLE source
	# of truth also used by the offline batch, so foreground + offline agree by
	# construction (AC-34-03). WIN = floor clears before formation_total_hp
	# depletes; DEFEAT = HP→0 first, at `defeat_tick`. Spy resolvers without the
	# method default to WIN (preserving the pre-pivot always-clear behavior those
	# tests assert).
	_run_won = true
	_run_defeat_tick = -1
	if _combat_resolver != null and _combat_resolver.has_method("compute_run_outcome"):
		var outcome: RefCounted = _combat_resolver.call("compute_run_outcome", _combat_snapshot)
		if outcome != null:
			_run_won = bool(outcome.won)
			_run_defeat_tick = int(outcome.defeat_tick)
	# losing_run is RETIRED as a gameplay state (GDD #34): a run now WINS or is
	# DEFEATED, with no half-loot middle. The legacy field stays pinned false for
	# save-compat + the 3-arg floor_cleared_first_time signal contract.
	run_snapshot.losing_run = false
	# Sprint 8 S8-S3 (Story 006): capture dispatch context so the
	# floor_cleared_first_time signal can carry biome_id + floor_index when
	# the floor-clear marker fires later in the run.
	_dispatched_floor_index = floor_index
	_dispatched_biome_id = biome_id
	# Sprint 14 S14-N2: capture the dispatch intent for the main_menu
	# re-dispatch shortcut. Captured AFTER all validations pass + BEFORE
	# the state transition to ACTIVE_FOREGROUND so re-dispatch reads from
	# a known-good intent. Deep-copy `formation` so subsequent caller-side
	# mutations don't propagate into the cached intent.
	last_dispatch_intent = {
		"formation": formation.duplicate(true),
		"floor_index": floor_index,
		"biome_id": biome_id,
	}
	# Sprint 15 S15-S4: capture pre-dispatch gold for the Victory Moment
	# screen's post-run gold-delta render per Victory Moment GDD #25 §D.2 +
	# OQ-25-1 dependency. Reads /root/Economy.get_gold_balance() with
	# null-guard for test environments without Economy autoload registered.
	# Captured AFTER all validations pass + BEFORE the state transition so
	# the value reflects the player's pre-run balance unchanged.
	var economy_for_gold: Node = (
		get_node_or_null("/root/Economy") if get_tree() != null else null
	)
	if economy_for_gold != null and economy_for_gold.has_method("get_gold_balance"):
		run_snapshot.pre_dispatch_gold = int(economy_for_gold.get_gold_balance())
	_set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	# Class Synergy V1.0 (Sprint 21 S21-S2 / Story 3) — emit dispatch-time
	# synergy signal AFTER state transition so subscribers see the run
	# already in ACTIVE_FOREGROUND. Only emits when a synergy is active
	# (run_snapshot.synergy_id != ""). AudioRouter subscribes for the
	# warm-sting cue per `class-synergy-system.md` §C.4 + AC-CS-14.
	if run_snapshot != null and run_snapshot.synergy_id != "":
		class_synergy_dispatched_signal.emit(run_snapshot.synergy_id)


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
	# observe the fully-settled new state (Story 012 AC-6). Routed through
	# _emit_state_changed_or_buffer per Story 013 TR-014-001: when SceneManager
	# is mid-transition, the emit is buffered and replayed post-transition so
	# late-mounting screens (whose on_enter has not yet wired the
	# state_changed listener) still get the emission.
	_emit_state_changed_or_buffer(new_state, old_state)


## Story 013 — emit `state_changed` synchronously when SceneManager is IDLE,
## OR buffer the emit when SceneManager is mid-transition. The deferred emit
## is replayed by [method _replay_buffered_state_change] when the SceneManager
## fires `transition_complete`.
##
## Coalesce: if multiple state changes occur during one TRANSITIONING window,
## only the latest is held in [member _buffered_state_change] (the previous
## buffered entry is overwritten). The "old_state" stored is the original
## pre-transition state, NOT the most recent intermediate state — this makes
## the post-transition emit reflect the cross-transition transition. Listeners
## that observe intermediate states should subscribe BEFORE the transition
## starts (the standard ADR-0007 lifecycle).
##
## TR-orchestrator-014-001 / TR-orchestrator-014-002 / TR-orchestrator-014-004.
func _emit_state_changed_or_buffer(new_state: int, old_state: int) -> void:
	var sm: Node = get_node_or_null("/root/SceneManager")
	# Defensive: if SceneManager is absent (early-boot or test envs), emit
	# synchronously. The IDLE-time case is the canonical fast path.
	if sm == null or not ("state" in sm) or sm.state != sm.State.TRANSITIONING:
		state_changed.emit(new_state, old_state)
		return

	# Buffer the emit. Coalesce: if a buffered entry already exists, preserve
	# the original old_state but overwrite the new_state with the latest.
	# This makes the post-transition emit reflect "where we ended up" with
	# "where we came from" being the pre-transition state.
	var preserved_old_state: int = old_state
	if not _buffered_state_change.is_empty():
		preserved_old_state = int(_buffered_state_change.get("old_state", old_state))
	_buffered_state_change = {
		"new_state": new_state,
		"old_state": preserved_old_state,
	}

	# Connect a one-shot replay handler if not already connected. CONNECT_ONE_SHOT
	# auto-disconnects after firing; if multiple state changes accumulate during
	# the same transition window, the existing connection covers them all.
	if sm.has_signal("transition_complete"):
		var sig: Signal = sm.get("transition_complete")
		if not sig.is_connected(_replay_buffered_state_change):
			sig.connect(_replay_buffered_state_change, CONNECT_ONE_SHOT)


## Story 013 — replays a buffered state_changed emit when SceneManager fires
## `transition_complete`. Connected via CONNECT_ONE_SHOT so it auto-disconnects
## after firing. If [member _buffered_state_change] is empty (no buffered emit
## pending), the replay is a no-op — defensive in case the transition finishes
## without a state-change buffer ever being populated.
##
## TR-orchestrator-014-001 / TR-orchestrator-014-004.
func _replay_buffered_state_change(_screen_id: String, _transition_type: int) -> void:
	if _buffered_state_change.is_empty():
		return
	var buffered: Dictionary = _buffered_state_change.duplicate()
	_buffered_state_change.clear()
	state_changed.emit(
		int(buffered["new_state"]),
		int(buffered["old_state"]),
	)


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
	# Phase 1 defeat path (GDD #34 / ADR-0021 — AC-34-04): a DEFEATED run credits
	# ZERO loot. Advance the tick clock but SKIP all kill/gold/XP processing; when
	# the clock reaches the defeat tick, end the run via [signal run_defeated].
	# (Enemies that "died" before the party fell grant nothing — defeat is
	# all-or-nothing per the GDD.)
	if not _run_won:
		run_snapshot.current_tick = n
		run_snapshot.last_emitted_tick = n
		if _run_defeat_tick >= 0 and n >= _run_defeat_tick:
			_end_run_defeated()
		return
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
	# Resolve HeroRoster autoload once for per-kill XP grants per Hero Leveling
	# GDD #15 §C.1 (Sprint 14 S14-M4 Story 3). Engine-code-rule: no per-kill
	# tree query — hoist outside the loop. _grant_xp_to_formation null-guards
	# the roster argument so test envs without HeroRoster are safe.
	var roster_for_xp: Node = (
		get_node_or_null("/root/HeroRoster") if get_tree() != null else null
	)
	# Engine-code-rule extension (Sprint 14 S14-M4 Story 3 follow-up): pre-cache
	# xp_per_kill(tier) for every tier seen in this kills_array so the per-kill
	# loop avoids the Economy.get_config tree query that lives inside
	# xp_per_kill. For a 60-kill combat tick that would be 60 tree queries
	# inside the hot path; pre-caching reduces it to ≤5 queries (one per
	# unique tier, MVP tiers 1-5). Cache is a local Dictionary[int, int]
	# keyed by tier, populated lazily on first per-tier sighting.
	var xp_by_tier_cache: Dictionary = {}

	# Class Synergy V1.0 (Sprint 21 Story 4 — per-kill wiring) — hoist the
	# active synergy id + XP multiplier OUT of the per-kill loop. The
	# multiplier is constant for the run (synergy_id is frozen-at-dispatch
	# per AC-CS-13). Computing it once amortizes the resolver over all
	# kills in the batch; the gold multiplier varies per archetype so it
	# stays inside the loop via attribute_kill_gold's archetype param.
	#
	# `class-synergy-system.md` §C.3 — synergy multipliers compose
	# multiplicatively with the existing 3-factor (matchup × loot × base)
	# kill output formula. The 4-factor product is:
	#   gold = floori(BASE_KILL[tier] × matchup × loot × synergy)
	#   xp   = floori(xp_per_kill(tier) × synergy_xp_multiplier)
	var synergy_id: String = ""
	if run_snapshot != null:
		synergy_id = run_snapshot.synergy_id
	var synergy_xp_multiplier: float = _resolve_synergy_xp_multiplier(synergy_id)

	# Prestige V1.0 (Sprint 21+ Story 2) — hoist the global prestige
	# multiplier outside the per-kill loop. The multiplier is global +
	# constant for the run (it only changes via HeroRoster.prestige_hero
	# which is only callable from NO_RUN state per `prestige-system.md`
	# §E.2). Reading once amortizes the autoload lookup over all kills.
	#
	# Defensive: null-guard for test envs without HeroRoster registered.
	# Default 1.0 means "no prestige boost" — the per-kill formula still
	# works, just at baseline output.
	#
	# Per `prestige-system.md` §C.3 + AC-PR-21 (5-factor stacking).
	var prestige_multiplier: float = 1.0
	var roster_for_prestige: Node = roster_for_xp  # Reuse the already-resolved autoload.
	if roster_for_prestige != null and roster_for_prestige.has_method("get_prestige_multiplier"):
		prestige_multiplier = float(roster_for_prestige.call("get_prestige_multiplier"))

	for ke: Variant in kills_array:
		# KillEvent fields — duck-typed reads against the value-type contract:
		# enemy_id (StringName), archetype (StringName), tier (int), is_boss (bool).
		var tier: int = int(ke.tier) if "tier" in ke else 1
		var archetype_sn: StringName = (ke.archetype as StringName) if "archetype" in ke else &""
		var advantaged: bool = bool(matchup_cache.get(archetype_sn, false))
		# Gold attribution → Economy. Production Economy.add_gold takes a
		# single int; the "kill" attribution stays implicit at the call site
		# (Economy's gold_changed signal carries a generic "add_gold" reason).
		# Class Synergy V1.0 — pass synergy_id + archetype to attribute_kill_gold
		# so Steel Wall (3W vs bruiser) and Triple Threat (1+1+1 unconditional)
		# multiply the gold output. `class-synergy-system.md` §C.3 + §D.2.
		# Prestige V1.0 (Story 2) — apply the prestige multiplier on top of
		# the synergy-adjusted output. Per AC-PR-21 5-factor product:
		#   floori(BASE_KILL[tier] × matchup × loot × synergy × prestige).
		var archetype_str: String = String(archetype_sn)
		var gold_pre_prestige: int = attribute_kill_gold(tier, advantaged, losing_run, synergy_id, archetype_str)
		var gold: int = floori(float(gold_pre_prestige) * prestige_multiplier)
		if economy_can_add_gold and gold > 0:
			economy.add_gold(gold)
		# Per-kill signals.
		enemy_killed.emit(tier, archetype_str, advantaged)
		if "is_boss" in ke and bool(ke.is_boss):
			var enemy_id_str: String = String(ke.enemy_id) if "enemy_id" in ke else ""
			boss_killed.emit(enemy_id_str)
		# Hero Leveling GDD #15 §C.1 / AC-15-01: per-kill XP grant to every
		# dispatched-formation hero. Foreground-only (this loop only runs in
		# ACTIVE_FOREGROUND state per _on_tick_fired guard); offline replay
		# uses the Story 4 batch path via flush_offline_signals.
		# Per-tier XP cache (engine-code-rule: hoist Economy tree query out
		# of the per-kill loop; resolve at most once per unique tier).
		var xp_amount: int = int(xp_by_tier_cache.get(tier, -1))
		if xp_amount < 0:
			xp_amount = xp_per_kill(tier)
			xp_by_tier_cache[tier] = xp_amount
		# Class Synergy V1.0 — apply Arcane Elite's ×1.20 XP multiplier
		# (or 1.0 for any other synergy_id, including ""). Per
		# `class-synergy-system.md` §C.3. The multiplier is loop-invariant
		# (hoisted above) so this is a single float multiplication per kill.
		# Prestige V1.0 (Story 2) — also apply the prestige multiplier on
		# the XP path. Both Arcane Elite and prestige stack multiplicatively
		# per AC-PR-21 5-factor product.
		var xp_with_synergy_prestige: int = floori(
			float(xp_amount) * synergy_xp_multiplier * prestige_multiplier
		)
		_grant_xp_to_formation(roster_for_xp, xp_with_synergy_prestige)

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
			# Phase 1 (GDD #34): no half-loot. The floor-clear block only runs on
			# a WINNING run (a defeated run returns early in _on_tick_fired before
			# any kill processing), so the full bonus always applies.
			# Layer 3: Economy monotonic-credit gate.
			var awarded: bool = false
			if economy_can_add_gold and bonus > 0 and economy.has_method("try_award_floor_clear"):
				# Sprint 17 schema v2: Economy.try_award_floor_clear takes
				# biome_id as the first param so the monotonic-credit ledger
				# is namespaced per biome. Pre-Sprint-17 (single-biome MVP)
				# this call was (floor_idx, bonus) — the int-keyed ledger
				# collided across biomes (e.g. clearing Forest Reach F5
				# blocked Frostmire F5's first-clear progression). The
				# biome-aware signature fixes the multi-biome chain.
				awarded = bool(economy.try_award_floor_clear(_dispatched_biome_id, floor_idx, bonus))
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
				# Hero Leveling GDD #15 §C.2 / AC-15-02: per-floor-clear XP
				# grant to every dispatched-formation hero. Tied to the
				# floor_cleared_first_time signal (lifetime monotonic) per
				# AC-15-02 — re-runs of an already-cleared floor get kill-XP
				# only. Sprint 14 S14-M4 Story 3 replaces the Sprint 10 S10-M4
				# stub +1-per-clear grant per AC-15-14.
				_grant_xp_to_formation(roster_for_xp, xp_per_floor_clear(floor_idx))
				# Sprint 11 S11-X7 / ADR-0014 §signal emission policy: during
				# offline replay (set externally by OfflineProgressionEngine
				# rank 15), accumulate the floor-clear payload for post-replay
				# aggregate emission instead of firing the player-facing
				# fanfare per-chunk. Foreground path emits as before.
				if _is_offline_replay:
					_offline_pending_first_clears.append({
						"floor_index": floor_idx,
						"biome_id": _dispatched_biome_id,
						"losing_run": losing_run,
					})
				else:
					floor_cleared_first_time.emit(floor_idx, _dispatched_biome_id, losing_run)
		# Floor cleared — transition ACTIVE_FOREGROUND → RUN_ENDED.
		var next_state: int = DungeonRunStateScript.validate_transition(
			state, DungeonRunStateScript.TRIGGER_RUN_ENDED
		)
		_set_state(next_state)


## Phase 1 defeat closure (GDD #34 / ADR-0021 — AC-34-04/05). Ends a DEFEATED
## run: emits [signal run_defeated] with the dispatch context BEFORE the FSM
## transition (so subscribers observe the run still in ACTIVE_FOREGROUND), then
## transitions ACTIVE_FOREGROUND → RUN_ENDED via the same matrix trigger the
## win path uses. Credits NOTHING — the caller ([method _on_tick_fired]) has
## already skipped all kill/gold/XP processing for the defeat path.
func _end_run_defeated() -> void:
	# GDD #34 Phase 3 / ADR-0021 (AC-34-04): apply injuries BEFORE notifying
	# subscribers, so any run_defeated listener (UI, audio) observes a roster
	# that already reflects the injured party.
	_apply_defeat_injuries()
	run_defeated.emit(_dispatched_floor_index, _dispatched_biome_id)
	var next_state: int = DungeonRunStateScript.validate_transition(
		state, DungeonRunStateScript.TRIGGER_RUN_ENDED
	)
	_set_state(next_state)


## Injures every hero in the dispatched formation when a foreground run is
## DEFEATED (GDD #34 Phase 3 / ADR-0021 — AC-34-04/05). Each hero's
## [code]injured_until[/code] is set to a WALL-CLOCK recovery instant
## ([code]TickSystem.now_ms() + HeroRoster.injury_recovery_seconds() * 1000[/code]).
## Wall-clock — NOT sim-ticks — so recovery keeps elapsing while the game is
## backgrounded or fully offline (AC-34-05).
##
## The ids come from the frozen-at-dispatch [member run_snapshot].formation_snapshot
## so a mid-run roster edit or re-dispatch cannot change who is penalised. Unknown
## ids are tolerated by [method HeroRoster.injure_heroes] (it skips + warns).
##
## Safe no-op when [member run_snapshot] is null, the HeroRoster autoload is
## absent (lean test envs), or the snapshot carries no formation ids.
func _apply_defeat_injuries() -> void:
	if run_snapshot == null:
		return
	var roster: Node = (
		get_node_or_null("/root/HeroRoster") if get_tree() != null else null
	)
	if roster == null:
		return
	var fs: Dictionary = run_snapshot.formation_snapshot
	var ids_v: Variant = fs.get("instance_ids", [])
	var ids: Array = ids_v as Array if ids_v is Array else []
	if ids.is_empty():
		return
	var recovery_seconds: int = int(roster.injury_recovery_seconds())
	var until_ms: int = TickSystem.now_ms() + recovery_seconds * 1000
	roster.injure_heroes(ids, until_ms)


## Phase 1 drip gate (GDD #34 / ADR-0021 — AC-34-08). True when the in-flight
## foreground run is doomed to DEFEAT (the verdict computed at dispatch was a
## loss). The Economy's per-tick drip subscribes to this so a defeated run earns
## ZERO passive gold while it plays out. Returns false once the run ends (state
## leaves ACTIVE_FOREGROUND) or for any winning run.
func is_active_run_defeated() -> bool:
	return (not _run_won) and state == DungeonRunStateScript.State.ACTIVE_FOREGROUND


## Sprint 8 S8-S3 (Story 006 — TR-014): per-kill gold attribution formula.
##
## Formula: [code]floori(BASE_KILL[tier] * matchup_mult * synergy_mult)[/code]
##
##   - [code]BASE_KILL[tier][/code]: base gold lookup, 0 for unmapped tiers
##   - [code]matchup_mult[/code]: [constant MATCHUP_MULT_ADV] (1.5) when
##     advantaged, [constant MATCHUP_MULT_DIS] (0.7) otherwise
##   - [code]synergy_mult[/code]: per-(synergy_id, archetype) multiplier
##
## Phase 1 (GDD #34 / ADR-0021): the legacy [code]loot_factor[/code] (half-loot
## on a losing run) is RETIRED. A run now WINS (full loot) or is DEFEATED (this
## method never runs — the per-kill loop is skipped on defeat). [param losing_run]
## is RETAINED in the signature for call-site compatibility but is IGNORED; it is
## always false in production now (a defeated run credits nothing). A later
## hygiene pass may drop the param once its ~40 call sites are migrated.
##
## Output range for MVP tiers (1..5): floori(5*0.7)=3 lower bound,
## floori(100*1.5)=150 upper bound. Returns the arithmetic result without
## clamping (callers can cap if needed).
##
## TR-orchestrator-014 — ADR-0013 §C
##
## Sprint 21 S21-S1 (Class Synergy V1.0 Story 2): extended with optional
## [param synergy_id] + [param archetype] for the multiplicative synergy/prestige
## formula. Per `class-synergy-system.md` §C.3 + §D.2 + AC-CS-06..09.
func attribute_kill_gold(tier: int, advantaged: bool, losing_run: bool, synergy_id: String = "", archetype: String = "") -> int:
	# Phase 1 (GDD #34): losing_run is ignored — retained for call-site compat.
	var _unused_losing_run: bool = losing_run
	var base: int = int(BASE_KILL.get(tier, 0))
	var matchup_mult: float = MATCHUP_MULT_ADV if advantaged else MATCHUP_MULT_DIS
	var synergy_mult: float = _resolve_synergy_gold_multiplier(synergy_id, archetype)
	return floori(float(base) * matchup_mult * synergy_mult)


## Sprint 21 S21-S1 (Class Synergy V1.0 Story 2): per-kill XP attribution
## formula. New surface introduced by the V1.0 Class Synergy block; MVP
## ships with stub +1-per-clear XP grant per S10-M4 + the orchestrator's
## existing `_grant_stub_levels_to_formation` path. The V1.0 implementation
## epic wires this method into the per-kill schedule alongside
## [method attribute_kill_gold] when Story 4 lands the screen + UX
## integration.
##
## Formula: [code]floori(BASE_XP_PER_KILL * tier * synergy_mult)[/code]
##
##   - [constant BASE_XP_PER_KILL] (10): tier-1 base XP.
##   - [param tier]: enemy tier (1..5). Output scales linearly with tier
##     so tier-3 kills are 3× the XP of tier-1 kills.
##   - [param synergy_id]: active formation synergy id; resolved via
##     [method _resolve_synergy_xp_multiplier].
##
## Output range for MVP tiers (1..5) with default synergy (none):
##   floori(10 * 1 * 1.0) = 10 (tier-1 baseline)
##   floori(10 * 5 * 1.0) = 50 (tier-5 baseline)
## With Arcane Elite synergy active (×1.20):
##   floori(10 * 5 * 1.20) = 60 (tier-5 boosted)
##
## Per `class-synergy-system.md` §C.3 + §D.3 + AC-CS-10/11.
func attribute_kill_xp(tier: int, synergy_id: String = "") -> int:
	var synergy_mult: float = _resolve_synergy_xp_multiplier(synergy_id)
	return floori(float(BASE_XP_PER_KILL) * float(tier) * synergy_mult)


## Resolves the gold multiplier for a given (synergy_id, archetype) pair.
## Returns 1.0 (no multiplier) for: empty synergy_id, archetype-conditional
## synergies whose archetype doesn't match, or unknown synergy_ids
## (V1.5+ forward-compat per AC-CS-18).
##
## Per `class-synergy-system.md` §D.2.
func _resolve_synergy_gold_multiplier(synergy_id: String, archetype: String) -> float:
	match synergy_id:
		"":
			return 1.0
		"steel_wall":
			# Conditional: only applies vs bruiser archetype kills.
			return STEEL_WALL_GOLD_MULT if archetype == "bruiser" else 1.0
		"triple_strike":
			# Conditional: only applies vs armored archetype kills
			# (parallel to steel_wall; Rogue counters Armored per
			# assets/data/classes/rogue.tres counter_archetype).
			# Added in the 2026-05-14 GDD re-review to close the
			# 3-Rogue asymmetric-class-treatment gap.
			return TRIPLE_STRIKE_GOLD_MULT if archetype == "armored" else 1.0
		"triple_threat":
			# Unconditional: applies to all kill archetypes.
			return TRIPLE_THREAT_GOLD_MULT
		"arcane_elite":
			# Arcane Elite affects XP only (per GDD §C.1 effect type column).
			return 1.0
		"bastion":
			# 3 Paladins: conditional gold vs caster (paladin counter_archetype).
			# Same teaches-matchup pattern as Steel Wall, defender shape.
			return BASTION_GOLD_MULT if archetype == "caster" else 1.0
		"volley":
			# 3 Archers: conditional gold vs swarm. Archer is the MVP roster's
			# only swarm-counter class; Volley is the load-bearing teach for
			# swarm-archetype enemy introductions.
			return VOLLEY_GOLD_MULT if archetype == "swarm" else 1.0
		"frenzy":
			# 3 Berserkers: conditional gold vs bruiser. Mirrors Steel Wall —
			# gives the brawler path the same discovery moment Warriors get.
			return FRENZY_GOLD_MULT if archetype == "bruiser" else 1.0
		"vigil":
			# Vigil affects XP, not gold (support→investment theme, mirrors
			# Arcane Elite for the support class shape).
			return 1.0
		_:
			# AC-CS-18 forward-compat: unknown synergy_id (e.g., V1.5
			# "veteran_squad") falls back to no multiplier. Graceful
			# degradation, no crash.
			return 1.0


## Resolves the XP multiplier for a given synergy_id. Returns 1.0 (no
## multiplier) for: empty synergy_id, gold-only synergies, or unknown
## synergy_ids (V1.5+ forward-compat per AC-CS-18).
##
## Per `class-synergy-system.md` §D.3.
func _resolve_synergy_xp_multiplier(synergy_id: String) -> float:
	match synergy_id:
		"":
			return 1.0
		"arcane_elite":
			# Unconditional XP boost.
			return ARCANE_ELITE_XP_MULT
		"vigil":
			# 3 Clerics: unconditional XP boost (support→investment theme,
			# mirrors Arcane Elite's caster-investment shape).
			return VIGIL_XP_MULT
		"steel_wall", "triple_strike", "triple_threat", "bastion", "volley", "frenzy":
			# Gold-only synergies (XP path is baseline). Tier-2 conditionals
			# Bastion / Volley / Frenzy are tier-2 conditional-gold synergies.
			return 1.0
		_:
			# AC-CS-18 forward-compat fallback.
			return 1.0


## Drains per-chunk-suppressed offline-replay signals into aggregate
## emissions, then clears [member _is_offline_replay].
##
## Sprint 11 S11-X7 / OfflineProgressionEngine GDD §F (Story 0a). Symmetric
## to [code]Economy.flush_offline_signals[/code] (S11-X6 / ADR-0013 Amendment #1)
## but for the orchestrator-side [signal floor_cleared_first_time].
##
## Per OfflineProgressionEngine GDD §C.3 signal-suppression policy:
##   - [signal floor_cleared_first_time] fires ONCE per accumulated floor in
##     the order they were appended (matches insertion order of the foreground
##     replay sequence).
##   - [member _is_offline_replay] is cleared to [code]false[/code] AFTER
##     the aggregate emissions (subscribers re-entering during the emission
##     see the post-replay flag state).
##
## Idempotent: calling on an empty / already-flushed accumulator is a no-op
## (no signals fire, flag clears safely).
##
## Sprint 12+ OfflineProgressionEngine implementation owns the call site;
## this method is the API surface the engine binds against.
##
## OfflineProgressionEngine GDD §F (Story 0a), §C.2 batch-loop integration.
##
## Sprint 14 S14-M4 Story 4 / Hero Leveling GDD #15 §E.9 / AC-15-11:
## additionally batches XP grants — sums [code]xp_per_kill[/code] across
## [member _offline_pending_kills_by_tier] plus [code]xp_per_floor_clear[/code]
## across [member _offline_pending_first_clears], then dispatches a single
## [code]roster.add_xp(id, total)[/code] per dispatched-formation hero. The
## cascade (multi-level-up loop) runs at HeroRoster.add_xp time per §C.4 —
## one call per hero, not per kill. Sequencing: floor_cleared_first_time
## emits BEFORE the XP grant so the player-facing first-clear fanfare
## precedes the level-up chimes (subscriber order is deterministic).
func flush_offline_signals() -> void:
	var total_xp: int = compute_offline_total_xp()

	# Aggregate floor_cleared_first_time emits in insertion order.
	for entry: Dictionary in _offline_pending_first_clears:
		floor_cleared_first_time.emit(
			int(entry.floor_index),
			String(entry.biome_id),
			bool(entry.losing_run)
		)

	# Hero Leveling GDD #15 AC-15-11: single batched add_xp per formation
	# hero. _grant_xp_to_formation null-guards the roster argument (test
	# envs without /root/HeroRoster are safe).
	if total_xp > 0:
		var roster: Node = (
			get_node_or_null("/root/HeroRoster") if get_tree() != null else null
		)
		_grant_xp_to_formation(roster, total_xp)

	# Clear accumulators + replay flag.
	_offline_pending_first_clears.clear()
	_offline_pending_kills_by_tier.clear()
	_is_offline_replay = false
	# Reset the per-replay-cycle combat-batch state so the next offline resume
	# rebuilds a fresh snapshot + cursor (see compute_offline_batch).
	_offline_combat_snapshot = null
	_offline_replay_cursor = 0
	_offline_run_won = true


## Offline-replay combat feeder — landed Story 010. Called once per
## OfflineProgressionEngine chunk while [member _is_offline_replay] is true.
## Returns a plain [Dictionary] (NOT the CombatBatchResult — the engine calls
## [code]result.has(...)[/code], which is Dictionary-only):
##   [code]{kills_by_tier: Dictionary, floor_cleared: bool, floor_index: int,
##    floor_clear_bonus_gold: int, won: bool}[/code]
##
## Phase 1 (GDD #34 / ADR-0021): [code]won[/code] is the WIN/DEFEAT verdict of the
## two-sided HP race, resolved ONCE on the first chunk via the resolver's shared
## [code]compute_run_outcome[/code] (foreground/offline parity, AC-34-03). On DEFEAT
## ([code]won == false[/code]) the batch credits nothing — zero kills, zero
## floor-clear bonus — and the OfflineProgressionEngine reads [code]won[/code] to
## ALSO skip the Economy drip batch, so a doomed offline run earns zero gold
## (AC-34-08), mirroring the foreground drip forfeit.
##
## Mirrors the Economy offline-input resolution (formation + floor): the offline
## batch represents the player's live formation grinding the dispatched (or
## default floor-1) floor for the elapsed window. Routes through
## [code]_combat_resolver.compute_offline_batch[/code] (shared kill-schedule
## source of truth → foreground/offline parity), accumulates per-tier kills into
## [member _offline_pending_kills_by_tier] so [method flush_offline_signals]
## grants the batched kill-XP, and builds [member run_snapshot] if absent so the
## XP grant has a formation to target.
##
## Scope: GOLD (Economy branch) + KILLS + KILL-XP + floors-cleared DISPLAY.
## Offline floor-clear UNLOCK + floor-clear XP (first_clear emission gated on the
## already-cleared check + Economy floor-award coupling) are a deliberate
## follow-up — not wired here.
func compute_offline_batch(tick_budget: int) -> Dictionary:
	var floor_index: int = _resolve_offline_replay_floor_index()
	# Degenerate-path return: `won: true` so a missing/spy resolver does NOT forfeit
	# the Economy drip (no combat verdict known → no defeat → drip runs as before).
	var empty: Dictionary = {
		"kills_by_tier": {}, "floor_cleared": false, "floor_index": floor_index, "won": true,
	}
	if tick_budget <= 0:
		return empty
	if _combat_resolver == null or not _combat_resolver.has_method("compute_offline_batch"):
		return empty

	# Lazy-init the offline snapshot ONCE per replay cycle (first chunk).
	if _offline_combat_snapshot == null:
		var formation: Array = _resolve_offline_replay_formation()
		var biome_id: String = _resolve_offline_replay_biome_id()
		_offline_combat_snapshot = _build_combat_snapshot(formation, floor_index, biome_id)
		if _offline_combat_snapshot != null:
			_offline_combat_snapshot.loops_per_run = _OFFLINE_LOOPS_CAP
		_offline_replay_cursor = 0
		# Phase 1 (GDD #34 / ADR-0021): resolve the WIN/DEFEAT verdict ONCE, here on
		# the first chunk, via the SAME `compute_run_outcome` the foreground dispatch
		# uses (AC-34-03 parity). A single-loop verdict is sufficient: the formation
		# either clears this floor (and grinds it for the whole window) or is defeated
		# on it (and is defeated on every retry → zero offline progress). Spy resolvers
		# without the method leave `_offline_run_won` true (pre-pivot always-clear).
		_offline_run_won = true
		if (
			_offline_combat_snapshot != null
			and _combat_resolver.has_method("compute_run_outcome")
		):
			var outcome: RefCounted = _combat_resolver.call(
				"compute_run_outcome", _offline_combat_snapshot
			)
			if outcome != null:
				_offline_run_won = bool(outcome.won)
		# Offline resume: run_snapshot is null (it's transient, never persisted).
		# Build it so flush_offline_signals → _grant_xp_to_formation has a
		# formation_snapshot to grant against. Guard: never clobber a genuinely
		# active run.
		if run_snapshot == null:
			run_snapshot = _build_run_snapshot(formation, floor_index, biome_id, _offline_combat_snapshot)
	if _offline_combat_snapshot == null:
		return empty

	# Phase 1 (GDD #34 / ADR-0021) defeat-forfeit gate (AC-34-08): a DEFEATED
	# offline run earns NOTHING for the whole window — no kills, no floor-clear
	# bonus, no kill-XP. Runs on EVERY chunk (the verdict was cached on the first
	# chunk above), so a multi-chunk window stays zero throughout. The `won: false`
	# return tells OfflineProgressionEngine to ALSO skip the Economy drip batch, so
	# foreground (drip gates on is_active_run_defeated) and offline forfeit alike.
	if not _offline_run_won:
		return {
			"kills_by_tier": {},
			"floor_cleared": false,
			"floor_index": floor_index,
			"floor_clear_bonus_gold": 0,
			"won": false,
		}

	# Per-chunk window: re-anchor the schedule at the running cursor and count
	# this chunk's budget — O(chunk), no cumulative re-walk.
	_offline_combat_snapshot.dispatched_at_tick = _offline_replay_cursor
	var batch: RefCounted = _combat_resolver.compute_offline_batch(_offline_combat_snapshot, tick_budget)
	_offline_replay_cursor += tick_budget
	if batch == null:
		return empty

	var chunk_kills: Dictionary = batch.kills_by_tier
	# Accumulate this chunk's kills into the pending tier dict for batched XP.
	for tier_v: Variant in chunk_kills:
		_offline_pending_kills_by_tier[tier_v] = (
			int(_offline_pending_kills_by_tier.get(tier_v, 0)) + int(chunk_kills[tier_v])
		)

	# Offline floor-clear UNLOCK + bonus + floor-clear XP. Mirrors the foreground
	# _process_kill_events first-clear path's 3-layer idempotency:
	#   Layer 2 — run_snapshot.floor_clear_emitted: fire at most once per replay.
	#   Layer 3 — Economy.try_award_floor_clear's monotonic ledger: returns false
	#             if the floor was ALREADY cleared (foreground or a prior resume),
	#             so a re-ground floor never re-unlocks or double-credits.
	# When awarded, we append to _offline_pending_first_clears so
	# flush_offline_signals emits floor_cleared_first_time (→ FloorUnlock advances
	# the unlock frontier) AND compute_offline_total_xp adds the per-floor-clear
	# XP. The bonus gold (credited to the balance by try_award_floor_clear via the
	# offline-accumulating add_gold) is surfaced on the summary so the
	# Return-to-App screen's gold matches the balance.
	var floor_clear_bonus_gold: int = 0
	if int(batch.loops_completed) >= 1 and run_snapshot != null and not run_snapshot.floor_clear_emitted:
		var biome_id: String = _resolve_offline_replay_biome_id()
		if not biome_id.is_empty():
			var bonus: int = int(FLOOR_CLEAR_BONUS.get(floor_index, 0))
			var economy: Node = get_node_or_null("/root/Economy")
			var awarded: bool = false
			if economy != null and bonus > 0 and economy.has_method("try_award_floor_clear"):
				awarded = bool(economy.try_award_floor_clear(biome_id, floor_index, bonus))
			# Layer 2 set regardless of awarded — a re-grind never re-attempts.
			run_snapshot.floor_clear_emitted = true
			if awarded:
				_offline_pending_first_clears.append({
					"floor_index": floor_index,
					"biome_id": biome_id,
					"losing_run": false,
				})
				floor_clear_bonus_gold = bonus

	return {
		"kills_by_tier": chunk_kills,
		# loops_completed >= 1 in this chunk's window means the floor was cleared
		# at least once. The engine dedups by floor_index, so reporting it on any
		# chunk yields a single floors_cleared entry.
		"floor_cleared": int(batch.loops_completed) >= 1,
		"floor_index": floor_index,
		# Floor-clear bonus credited this chunk (0 unless a genuine first-clear) —
		# surfaced onto summary.gold_earned by the engine.
		"floor_clear_bonus_gold": floor_clear_bonus_gold,
		# Phase 1 (GDD #34): WIN verdict — the engine runs the Economy drip batch.
		"won": true,
	}


## Test-injection seam for offline-replay inputs — mirrors
## [code]Economy.set_offline_replay_inputs[/code]. Production callers MUST NOT
## use this; the OfflineProgressionEngine is the sole legitimate driver and the
## live HeroRoster formation + dispatched floor/biome are resolved instead.
func set_offline_replay_inputs(formation: Array, floor_index: int, biome_id: String) -> void:
	_offline_replay_formation_override = formation
	_offline_replay_floor_index_override = floor_index
	_offline_replay_biome_id_override = biome_id


## Resolves the formation for the offline replay snapshot. Precedence:
## test override → live [code]HeroRoster.get_formation_heroes()[/code] → empty.
func _resolve_offline_replay_formation() -> Array:
	if not _offline_replay_formation_override.is_empty():
		return _offline_replay_formation_override
	var roster: Node = get_node_or_null("/root/HeroRoster") if get_tree() != null else null
	if roster != null and roster.has_method("get_formation_heroes"):
		return roster.get_formation_heroes()
	return []


## Resolves the floor index for the offline replay. Precedence: test override
## (>= 1) → dispatched floor (if a run was dispatched this session) → default 1
## (the floor where every save begins). Mirrors Economy's default-1 policy.
func _resolve_offline_replay_floor_index() -> int:
	if _offline_replay_floor_index_override >= 1:
		return _offline_replay_floor_index_override
	var fi: int = get_dispatched_floor_index()
	return fi if fi >= 1 else 1


## Resolves the biome for the offline replay. Precedence: test override →
## dispatched biome → empty (which drives _build_combat_snapshot's synthetic
## floor fallback).
func _resolve_offline_replay_biome_id() -> String:
	if not _offline_replay_biome_id_override.is_empty():
		return _offline_replay_biome_id_override
	return get_dispatched_biome_id()


## Returns the total XP a single dispatched-formation hero would gain from
## the current offline replay accumulators. Pure function — does NOT mutate
## state, does NOT call add_xp, does NOT emit signals.
##
## Formula per Hero Leveling GDD #15 AC-15-11:
##   [code]total = sum(xp_per_kill(tier) * count for tier, count in kills_by_tier)
##                + sum(xp_per_floor_clear(f) for f in floors_cleared_in_window)[/code]
##
## Reads [member _offline_pending_kills_by_tier] +
## [member _offline_pending_first_clears]. When both are empty, returns 0.
##
## Used by [method flush_offline_signals] to batch the XP grant; exposed
## publicly so OfflineProgressionEngine summary-rendering paths (Return-to-App
## Screen) can preview the per-hero XP gain pre-flush if needed.
##
## Hero Leveling GDD #15 §E.9 / AC-15-11
func compute_offline_total_xp() -> int:
	var total: int = 0
	for tier_v: Variant in _offline_pending_kills_by_tier.keys():
		var tier: int = int(tier_v)
		var count: int = int(_offline_pending_kills_by_tier[tier_v])
		if count > 0:
			total += xp_per_kill(tier) * count
	for entry: Dictionary in _offline_pending_first_clears:
		var floor_idx: int = int(entry.get("floor_index", 0))
		total += xp_per_floor_clear(floor_idx)
	return total


## Sprint 14 S14-M4 — real XP grant per Hero Leveling GDD #15.
##
## Grants [param xp_amount] XP to every dispatched-formation hero. Reads
## [code]run_snapshot.formation_snapshot.instance_ids[/code] (the dispatch-time
## formation, NOT the live HeroRoster formation per §C.6 formation-membership
## determinism) and calls [code]roster.add_xp(id, xp_amount)[/code] per hero.
## [code]HeroRoster.add_xp[/code] handles the multi-level cascade + LEVEL_CAP
## overflow + hydration suppression per Hero Leveling GDD §C.4 / §C.5 / §C.7.
##
## Caller is responsible for gating this:
##   - Per-kill XP: kill loop in [method _process_kill_events] calls per kill
##     event (after [signal enemy_killed] emit) — foreground-only; offline
##     replay batches via Story 4 path.
##   - Per-floor-clear XP: floor-clear branch calls inside the
##     [code]if awarded:[/code] (Layer 3 / lifetime monotonic) sub-branch so
##     XP-per-floor-clear ties to the [signal floor_cleared_first_time] signal
##     per AC-15-02. Re-runs of an already-cleared floor get kill-XP only.
##
## Defensive guards (silent early-return):
##   - [param xp_amount] <= 0 → no-op (matches add_xp's zero/negative semantics).
##   - [member run_snapshot] null → no-op (NO_RUN state).
##   - [code]formation_snapshot.instance_ids[/code] missing or empty → no-op.
##   - [param roster] null → no-op (test-env path: get_node_or_null returned
##     null before this call).
##   - [param roster] missing [code]add_xp[/code] method → no-op (forward-compat
##     against future roster API drift).
##
## Replaces Sprint 10 S10-M4 stub [code]_grant_stub_levels_to_formation[/code]
## per Hero Leveling GDD #15 §J Story 3 + AC-15-14.
##
## Hero Leveling GDD #15 §C.1 / §C.2 / §C.6 — TR-15-01 / TR-15-02 / TR-15-06
func _grant_xp_to_formation(roster: Node, xp_amount: int) -> void:
	if xp_amount <= 0:
		return
	if run_snapshot == null:
		return
	var fs: Dictionary = run_snapshot.formation_snapshot
	var ids_v: Variant = fs.get("instance_ids", [])
	if not (ids_v is Array):
		return
	var ids: Array = ids_v as Array
	if ids.is_empty():
		return
	if roster == null:
		return
	if not roster.has_method("add_xp"):
		return
	for hero_id_v: Variant in ids:
		var hero_id: int = int(hero_id_v)
		# instance_id 0 represents an empty slot — skip.
		if hero_id == 0:
			continue
		# add_xp itself handles unknown-id (push_warning + return false) per
		# the §C.6 spec — a hero removed from the roster between dispatch and
		# clear silently no-ops at the roster layer.
		roster.add_xp(hero_id, xp_amount)


## Returns the XP grant per kill for [param tier] per Hero Leveling GDD
## #15 §C.1 / Formula D.1: [code]xp_per_kill(tier) = XP_PER_KILL[tier][/code].
##
## Reads [code]Economy.get_config().XP_PER_KILL[/code] (Dictionary[int, int]).
## Fallback constants (when config null OR tier missing from dict) are the
## §C.1 defaults: {1: 5, 2: 10, 3: 20, 4: 40, 5: 80}.
##
## Per AC-15-10 + §E.7, an unknown [param tier] (config drift — content patch
## removed a tier OR a save references an out-of-range tier) defaults to
## tier-1 XP and logs push_warning. Defensive fallback prevents content-drift
## crashes; the invariant is "kill always grants SOME XP, never zero".
##
## Hero Leveling GDD #15 §C.1 / §D.1 — TR-15-01 / AC-15-10
func xp_per_kill(tier: int) -> int:
	const _FALLBACK_XP_PER_KILL: Dictionary = {1: 5, 2: 10, 3: 20, 4: 40, 5: 80}
	var economy: Node = get_node_or_null("/root/Economy") if get_tree() != null else null
	if economy != null and economy.has_method("get_config"):
		var cfg: Resource = economy.get_config()
		if cfg != null and "XP_PER_KILL" in cfg:
			var dict_val: Variant = cfg.get("XP_PER_KILL")
			if dict_val is Dictionary:
				var d: Dictionary = dict_val as Dictionary
				if d.has(tier):
					return int(d[tier])
				if d.has(1):
					push_warning(
						"[Orchestrator] xp_per_kill: unknown tier %d; defaulting to tier 1"
						% tier
					)
					return int(d[1])
	if _FALLBACK_XP_PER_KILL.has(tier):
		return int(_FALLBACK_XP_PER_KILL[tier])
	push_warning(
		"[Orchestrator] xp_per_kill: unknown tier %d; defaulting to tier 1 (fallback)"
		% tier
	)
	return int(_FALLBACK_XP_PER_KILL[1])


## Returns the XP grant per floor clear for [param floor_index] per Hero
## Leveling GDD #15 §C.2 / Formula D.2:
##   [code]xp_per_floor_clear(f) = XP_PER_FLOOR_CLEAR_BASE + (f - 1) * XP_PER_FLOOR_CLEAR_STEP[/code]
##
## Reads [code]Economy.get_config().XP_PER_FLOOR_CLEAR_BASE[/code] +
## [code]XP_PER_FLOOR_CLEAR_STEP[/code]. Fallback constants are §C.2 defaults
## (50, 25): Floor 1 = 50, Floor 2 = 75, Floor 3 = 100, Floor 4 = 125,
## Floor 5 = 150.
##
## [param floor_index] is expected in [1, 5] (validated by the caller's
## existing floor-range guard at the kill-loop emit site); negative inputs
## return 0 (silent no-op upstream of [method _grant_xp_to_formation]).
##
## Hero Leveling GDD #15 §C.2 / §D.2 — TR-15-02
func xp_per_floor_clear(floor_index: int) -> int:
	if floor_index < 1:
		return 0
	var base: int = 50
	var step: int = 25
	var economy: Node = get_node_or_null("/root/Economy") if get_tree() != null else null
	if economy != null and economy.has_method("get_config"):
		var cfg: Resource = economy.get_config()
		if cfg != null:
			if "XP_PER_FLOOR_CLEAR_BASE" in cfg:
				base = int(cfg.get("XP_PER_FLOOR_CLEAR_BASE"))
			if "XP_PER_FLOOR_CLEAR_STEP" in cfg:
				step = int(cfg.get("XP_PER_FLOOR_CLEAR_STEP"))
	return base + (floor_index - 1) * step


## Returns a deep copy of [member last_dispatch_intent] — the formation +
## floor + biome triplet captured at the most recent successful dispatch.
##
## Returns an empty Dictionary [code]{}[/code] when no successful dispatch
## has occurred this session. Callers should treat that as "no shortcut
## available" (e.g. main_menu's RedispatchButton hides itself).
##
## Returns a deep copy so callers can mutate the result without
## contaminating the cached intent.
##
## Sprint 14 S14-N2 — accessor for the main_menu re-dispatch shortcut.
func get_last_dispatch_intent() -> Dictionary:
	return last_dispatch_intent.duplicate(true)


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

	# Class Synergy V1.0 first-pass — Sprint 21 S21-M1 (Story 1).
	# Detect the active synergy at DISPATCHING time and freeze it on the
	# RunSnapshot. Per ADR-0001 mid-run reassignment policy, the synergy is
	# IMMUTABLE for the run's duration (mid-run formation edits do NOT
	# recompute the synergy — verified by AC-CS-13).
	#
	# Defensive: if FormationAssignment autoload is unavailable (test env
	# without it), fall through to "" (no synergy). Production rank table
	# guarantees presence (rank 11).
	#
	# design/gdd/class-synergy-system.md §C.2 dispatch-time confirmation +
	# AC-CS-13 mid-run reassignment immutability.
	snap.synergy_id = _detect_synergy_for_dispatch(snap.formation_snapshot)
	return snap


## Resolves the active synergy id for a freshly-built formation_snapshot.
## Defers to [FormationAssignment.detect_active_synergy] when the autoload
## is present; returns [code]""[/code] (no synergy) otherwise.
##
## Test-env safety: the autoload may be absent in unit-test fixtures that
## boot DungeonRunOrchestrator standalone. Production guarantees presence
## via the ADR-0003 rank table (FormationAssignment is rank 11).
##
## Sprint 21 S21-M1 / Story 1 — `class-synergy-system.md` §C.2 + §F.
func _detect_synergy_for_dispatch(formation_snapshot: Dictionary) -> String:
	var fa: Node = get_node_or_null("/root/FormationAssignment")
	if fa == null or not fa.has_method("detect_active_synergy"):
		return ""
	var result_v: Variant = fa.call("detect_active_synergy", formation_snapshot)
	if result_v is String:
		return result_v as String
	return ""


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
## to compute formation_dps_per_tick + formation_total_hp; falls back to
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
	# Phase 1 (GDD #34 / ADR-0021): formation_total_hp is the party's HP pool for
	# the two-sided HP race — the resolver's compute_run_outcome depletes it by
	# enemy DPS each tick and declares DEFEAT if it hits 0 before the floor clears.
	# Computed via the injected resolver when available (DefaultCombatResolver has
	# formation_total_hp); spy resolvers lacking it default to a large sentinel so
	# any verdict resolves to WIN (preserving pre-pivot always-clear behavior).
	# Replaces the retired hp_bonus_factor DPS-throttle (removed in Phase 1 L1).
	if _combat_resolver != null and _combat_resolver.has_method("formation_total_hp"):
		snap.formation_total_hp = int(_combat_resolver.call("formation_total_hp", formation))
	else:
		snap.formation_total_hp = 1_000_000
	# enemy_list — fetched from Floor data via DataRegistry. Floor lookup is
	# composite-keyed: biome_id + floor_index. The biome-dungeon-database
	# epic Story 003 (Forest Reach MVP content) provides the data; for the
	# S7-M13 MVP harness, default to a 3-enemy synthetic list when the lookup
	# fails so the data path completes.
	var floor_data: Resource = _resolve_floor(biome_id, floor_index)
	if floor_data != null and "enemy_list" in floor_data:
		# Sprint 18 post-S18-M4 playtest fix: real Floor.enemy_list stores
		# {enemy_id, count} pairs per ADR-0011 §Decision; combat expects
		# the materialized shape {id, archetype, tier, is_boss, base_hp,
		# base_attack, base_speed}. Pre-fix this shape mismatch silently
		# degenerated combat on every real floor (base_hp=0 → instant-kill
		# cascades, archetype="" → matchup advantage never fired).
		# Materialize via DataRegistry; pass synthetic shape through unchanged
		# so existing tests stay green.
		snap.enemy_list = _materialize_enemy_list(
			(floor_data.get("enemy_list") as Array).duplicate(true)
		)
	else:
		# Synthetic 3-enemy default: gives integration tests a deterministic
		# floor to drive ticks against. base_speed is low (Phase 1: enemy→party
		# DPS = base_attack×base_speed/SPEED_BASE) so the synthetic floor's threat
		# stays well under any real formation HP → resolves to WIN by default.
		snap.enemy_list = [
			{"id": &"e1", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10, "base_attack": 1, "base_speed": 1},
			{"id": &"e2", "archetype": &"bruiser", "tier": 1, "is_boss": false, "base_hp": 10, "base_attack": 1, "base_speed": 1},
			{"id": &"e3", "archetype": &"bruiser", "tier": 2, "is_boss": true, "base_hp": 15, "base_attack": 2, "base_speed": 1},
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


## Sprint 18 post-S18-M4 playtest fix: expands a Floor.enemy_list of
## [code]{enemy_id: String, count: int}[/code] pairs (per ADR-0011 §Decision)
## into the materialized shape combat expects:
## [code]{id, archetype, tier, is_boss, base_hp, base_attack}[/code], with
## [param count] copies emitted per pair (preserves enemy_list ordering).
##
## Per-entry shape detection: entries that already have an [code]"id"[/code]
## key (the synthetic test-fallback shape from [method _build_combat_snapshot])
## pass through unchanged so existing tests stay green. Entries with an
## [code]"enemy_id"[/code] key get materialized via DataRegistry.
##
## Failure handling: missing [code]enemy_id[/code], unresolvable EnemyData,
## or non-positive [code]count[/code] emit a [code]push_warning[/code] and
## skip the entry. Combat sees the trimmed list (still better than the
## pre-fix silently-degenerate path where every entry produced [code]base_hp=0[/code]
## instant kills).
##
## Returns a fresh Array (no aliasing with caller).
##
## Per `design/gdd/biome-dungeon-database.md` §C.4 + ADR-0011 + DataRegistry
## §enemies category. Sprint 18 ship: this was the missing wiring that
## silently degenerated combat on every real floor since Sprint 16 shipped
## multi-biome content. Player-facing symptom: instant-kill cascades on
## every dispatch with no LOSING-run possibility, no matchup advantage,
## no real synergy effect.
##
## Phase 1 (GDD #34 / ADR-0021): also materializes [code]base_speed[/code] so
## compute_run_outcome can compute the enemy→party DPS rate for the two-sided
## HP race. (Replaces the retired hp_bonus_factor throttle path.)
func _materialize_enemy_list(floor_enemy_list: Array) -> Array:
	var materialized: Array = []
	for entry: Variant in floor_enemy_list:
		if not (entry is Dictionary):
			continue
		var entry_dict: Dictionary = entry as Dictionary
		# Pass-through: synthetic shape already has the materialized fields.
		# Detect by presence of "id" key (synthetic uses "id"; real Floor data
		# uses "enemy_id"). Mutually exclusive in well-formed inputs.
		if entry_dict.has("id"):
			materialized.append(entry_dict.duplicate(true))
			continue
		var enemy_id: String = String(entry_dict.get("enemy_id", ""))
		if enemy_id.is_empty():
			push_warning(
				"DungeonRunOrchestrator._materialize_enemy_list: entry missing both 'id' and 'enemy_id'; skipping"
			)
			continue
		var count: int = int(entry_dict.get("count", 0))
		if count <= 0:
			push_warning(
				"DungeonRunOrchestrator._materialize_enemy_list: entry '%s' has non-positive count=%d; skipping"
				% [enemy_id, count]
			)
			continue
		var enemy_data: Resource = DataRegistry.resolve("enemies", enemy_id)
		if enemy_data == null:
			push_warning(
				"DungeonRunOrchestrator._materialize_enemy_list: DataRegistry could not resolve enemy_id='%s'; skipping %d copies"
				% [enemy_id, count]
			)
			continue
		var template: Dictionary = {
			"id": StringName(enemy_id),
			"enemy_id": StringName(enemy_id),
			"archetype": StringName(String(enemy_data.get("archetype")) if "archetype" in enemy_data else ""),
			"tier": int(enemy_data.get("tier")) if "tier" in enemy_data else 1,
			"is_boss": bool(enemy_data.get("is_boss")) if "is_boss" in enemy_data else false,
			"base_hp": int(enemy_data.get("base_hp")) if "base_hp" in enemy_data else 0,
			"base_attack": int(enemy_data.get("base_attack")) if "base_attack" in enemy_data else 0,
			# Phase 1 (GDD #34 / ADR-0021): base_speed feeds the enemy→party DPS
			# rate (base_attack×base_speed/SPEED_BASE) in compute_run_outcome.
			"base_speed": int(enemy_data.get("base_speed")) if "base_speed" in enemy_data else 0,
		}
		for i: int in count:
			materialized.append(template.duplicate(true))
	return materialized


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


# ---------------------------------------------------------------------------
# Save/Load consumer surface — per design/gdd/dungeon-run-orchestrator.md
# §F save-load row + ADR-0004 + ADR-0014. Namespace key "DungeonRunOrchestrator"
# (the autoload's node name) is composed by SaveLoadSystem from CONSUMER_PATHS.
# ---------------------------------------------------------------------------

## Returns this autoload's persisted save state per the Save/Load consumer
## contract. Schema per the GDD §F Save/Load row:
##   - Empty dict [code]{}[/code] when no run is active (state == NO_RUN).
##   - [code]{"active_run": <RunSnapshot.to_dict()>}[/code] when a run is in
##     flight (state in {DISPATCHING, ACTIVE_FOREGROUND, OFFLINE_REPLAY,
##     RUN_ENDED}).
##
## Active-run save is the offline-progression persistence path: the player
## closed the app mid-run and OfflineProgressionEngine (rank 15, currently
## unimplemented) replays the offline-elapsed ticks on next launch via
## [method load_save_data] + [method compute_offline_run].
##
## ADR-0014 §RunSnapshot save-persisted schema, TR-orchestrator-003
func get_save_data() -> Dictionary:
	if state == DungeonRunStateScript.State.NO_RUN or run_snapshot == null:
		return {}
	return {"active_run": run_snapshot.to_dict()}


## Hydrates this autoload from a save dict produced by [method get_save_data].
##
## **Sprint 11 minimal scope** (S11-M3c, 2026-05-05): the active-run resume
## path requires OfflineProgressionEngine (rank 15) to replay the offline-
## elapsed delta before this autoload can return to a meaningful in-flight
## state. OfflineProgressionEngine is unimplemented (Sprint 12+ scope). In
## the meantime, this method satisfies the Save/Load consumer contract
## (method exists + safe to call) but discards any persisted active_run with
## a [code]push_warning[/code]. The state machine stays at NO_RUN per the
## fresh-instance default.
##
## **Sprint 12+ extension**: resume path lands alongside
## OfflineProgressionEngine. The replacement implementation:
##   1. Validate the snapshot's [code]floor_id[/code] resolves via DataRegistry.
##   2. Validate every [code]formation_snapshot.instance_ids[/code] entry
##      exists in HeroRoster (orphan-hero recovery per ADR-0014 §2.3).
##   3. On any validation failure: emit
##      [code]run_snapshot_discarded_orphan[/code] (signal to be declared in
##      Sprint 12+ alongside Economy refund logic) + leave NO_RUN.
##   4. On success: rehydrate run_snapshot via from_dict, set state =
##      OFFLINE_REPLAY, hand off to OfflineProgressionEngine.
##
## ADR-0014 §RunSnapshot persistence; design/gdd/dungeon-run-orchestrator.md §F
func load_save_data(d: Dictionary) -> void:
	if d.is_empty():
		# Saved state was NO_RUN — defaults preserved (state=NO_RUN, run_snapshot=null).
		return
	if d.has("active_run"):
		# Sprint 11 minimal scope: discard with warning. Sprint 12+ adds
		# OfflineProgressionEngine + signal-based orphan recovery.
		push_warning(
			"[DungeonRunOrchestrator] load_save_data: 'active_run' present in " +
			"save dict but resume path is deferred to Sprint 12+ " +
			"(OfflineProgressionEngine rank 15 unimplemented). Saved run " +
			"discarded; orchestrator stays at NO_RUN. Sprint 12+ adds the " +
			"actual replay + orphan-hero recovery per ADR-0014."
		)
		# Defaults preserved (state=NO_RUN, run_snapshot=null).
		return
	# Unknown schema variant — defensive log + preserve defaults.
	push_warning(
		"[DungeonRunOrchestrator] load_save_data: unknown save dict schema " +
		"(keys=%s); preserving defaults." % str(d.keys())
	)
