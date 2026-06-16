extends Node

## Economy — rank-3 Foundation autoload.
##
## NOTE: No `class_name` — autoload scripts cannot declare `class_name`
## when the autoload name matches the class, or Godot raises
## "Class X hides an autoload singleton". The autoload is globally
## accessible as `Economy`; tests that need a fresh instance use
## `preload("res://src/core/economy/economy.gd").new()`.
##
## Owns the gold economy for Lantern Guild: gold balance, lifetime gold
## earned, the monotonic floor-clear ledger, and the offline-replay batch.
## Skeleton: signal declarations and public API stubs only.
## Bodies are filled in by neighbouring stories (003, 004, 005, 006, 010, 012).
##
## ADR-0013: Economy Autoload — State, Public API, Cost Curves, Offline Batch
## ADR-0003: Autoload Rank Table (rank 3; zero-arg _init invariant — Amendment #3)
## ADR-0002: Floor-Clear Bonus Monotonic-Credit Ledger

# ---------------------------------------------------------------------------
# Inline class: OfflineResult
# ---------------------------------------------------------------------------
## Returned by [method compute_offline_batch] after an offline replay pass.
##
## Declared inline (RefCounted, NOT Object) per ADR-0013 NOTE #9 — prevents
## the memory leak that would result if the result were a plain Object held
## via a non-parent reference.
##
## Fields:
##   [member total_gold]: Net gold delta produced by the replay (sum of drip,
##     kill bonuses, and any floor-clear bonuses awarded during the batch).
##   [member floors_cleared]: Indices of floors that received their first-clear
##     bonus during this batch, in the order they were credited.
##   [member events_log]: High-level event entries for HUD display
##     (`{"type": "drip", "amount": int, "ticks": int}` for the drip arm;
##     extended in later stories with kill / floor-clear entries).
##
## ADR-0013 §NOTE #9 + GDD §C.6 OfflineResult contract.
class OfflineResult extends RefCounted:
	var total_gold: int = 0
	var floors_cleared: Array[int] = []
	var events_log: Array = []

# ---------------------------------------------------------------------------
# Constants (structural engineering ceilings — NOT tuning knobs)
# ---------------------------------------------------------------------------

## Hard cap on the gold balance in int64 arithmetic (1 trillion).
##
## This is an engineering ceiling, NOT a tuning knob. It MUST NOT be changed
## without a superseding ADR. All tuning knobs (BASE_DRIP, BASE_RECRUIT,
## FLOOR_CLEAR_BONUS, etc.) live in [EconomyConfig] (`assets/data/config/
## economy_config.tres`) per ADR-0013 §Forbidden Patterns.
##
## ADR-0013 §E.1 — only two constants are allowlisted in this file:
## GOLD_SANITY_CAP and OFFLINE_REPLAY_REASON.
const GOLD_SANITY_CAP: int = 1_000_000_000_000

## Reason string passed to [signal gold_changed] for the single aggregate
## emission after an offline replay batch completes.
##
## Signal consumers (HUD, Return-to-App screen) use this string to
## distinguish offline-batch updates from foreground drip/kill emissions.
## ADR-0013 — only two constants are allowlisted in this file.
const OFFLINE_REPLAY_REASON: String = "offline_replay"

## Save schema version for [method get_save_data] / [method load_save_data].
##
## Bumped when the persisted Economy state shape changes in a non-additive way.
## V1 (current) ships these keys: [code]gold_balance[/code], [code]lifetime_gold_earned[/code],
## [code]floor_clear_bonus_credited[/code]. Forward-compat: extra unknown keys
## are tolerated by [method load_save_data]. Backward-compat: a saved
## [code]schema_version != SAVE_SCHEMA_VERSION[/code] aborts the load via
## [code]push_error[/code] and the instance retains its current state.
##
## ADR-0004 §Consumer contract — ADR-0013 §save schema.
## Schema version 2 (Sprint 17): widens floor_clear_bonus_credited ledger from
## int-keyed (floor_index alone) to String-keyed ("<biome_id>_f<floor_index>")
## to support multi-biome progression. v1 saves are auto-migrated by prefixing
## int keys with "forest_reach_f" (Sprint 11-era saves predate multi-biome).
const SAVE_SCHEMA_VERSION: int = 2

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the gold balance changes in any faucet or drain path.
##
## [param new_balance]: Gold balance after the change (clamped to [constant GOLD_SANITY_CAP]).
## [param delta]: Signed delta applied to the balance (positive = gain, negative = spend).
## [param reason]: Human-readable string identifying the source ("add_gold",
##   "offline_replay", etc.). Consumers MUST NOT branch on reason for game-state
##   decisions — use it for display and telemetry only.
##
## SUPPRESSED during offline replay ([member _is_offline_replay] == true).
## One aggregate emission fires after [method compute_offline_batch] completes.
##
## ADR-0013 §Signals — GDD §F
signal gold_changed(new_balance: int, delta: int, reason: String)

## Emitted the FIRST time a floor is cleared within a save lifetime.
##
## [param floor_index]: The floor index (1..5) that was cleared for the first time.
## Emitted at most once per floor per save lifetime. Consumers (achievement
## system, Return-to-App screen) use this for first-clear UI celebrations.
##
## SUPPRESSED during offline replay ([member _is_offline_replay] == true).
##
## ADR-0013 §Signals — ADR-0002 monotonic-credit contract
## Sprint 17 schema v2 widening: payload now carries biome_id alongside
## floor_index. Pre-Sprint-17 consumers subscribing with arity 1 must be
## updated to accept the new (biome_id, floor_index) signature.
signal first_clear_awarded(biome_id: String, floor_index: int)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Current gold balance in int64. Clamped to [constant GOLD_SANITY_CAP] by
## [method add_gold]. Never goes negative — [method try_spend] guards this.
## Persisted via [method get_save_data] / [method load_save_data].
## ADR-0013 §Requirements — GDD §C.1
var _gold_balance: int = 0

## Cumulative gold earned across all faucets this save lifetime (unbounded int64).
## Does NOT decrease when gold is spent — it is a statistic, not the balance.
## Persisted via [method get_save_data] / [method load_save_data].
## ADR-0013 §Requirements — GDD §C
var _lifetime_gold_earned: int = 0

## Monotonic floor-clear bonus ledger. Keys are "<biome_id>_f<floor_index>"
## strings (e.g. "forest_reach_f1", "frostmire_f5"); values are the highest
## bonus_amount credited for that (biome, floor) pair.
##
## ADR-0002 credit-the-gap contract: only amounts EXCEEDING the stored value
## are credited. This prevents double-crediting when the same (biome, floor)
## pair is cleared multiple times with different bonus amounts.
##
## Sprint 17 schema v2 widening: previously [Dictionary][int, int] keyed by
## floor_index alone. That broke Sprint 16's multi-biome architecture —
## clearing F5 in Forest Reach blocked first-clear progression for F5 in
## every other biome (ember_wastes, frostmire, etc.), which silently
## suppressed FloorUnlockSystem advance via the orchestrator's `awarded`
## gate. The (biome_id, floor_index) namespacing fixes this.
##
## Typed [Dictionary][String, int] (Godot 4.4+ syntax — precedent-verified
## via ADR-0009 / ADR-0012 landed usage).
## Persisted via [method get_save_data] / [method load_save_data].
## ADR-0013 §Requirements — ADR-0002 (Sprint 17 amendment for multi-biome).
var _floor_clear_bonus_credited: Dictionary[String, int] = {}

## Transient flag: true only during the [method compute_offline_batch] call.
##
## When true, all [signal gold_changed] and [signal first_clear_awarded]
## emissions are suppressed inside [method add_gold] and
## [method try_award_floor_clear] to avoid blowing the 500 ms offline budget
## on signal dispatch (ADR-0013 §C.6 — 230 ms dispatch cost at 576k ticks).
## NOT persisted. Reset to false after compute_offline_batch completes (or on
## flush_offline_signals per ADR-0013 Amendment #1 / Sprint 11 S11-X6).
## ADR-0013 §Requirements — GDD §C.6
var _is_offline_replay: bool = false

## Foreground drip — current constant-rate "segment" state for the active run.
## A segment is a maximal span of ticks with an unchanged per-tick rate; it
## restarts on floor change or formation-strength change. Within a segment the
## credited total is recomputed each tick as
## [code]_fg_drip_segment_base + floori(rate * segment_ticks)[/code] — the SAME
## single-multiply-then-floor expression the offline closed-form uses (see
## [method compute_offline_batch]). This makes foreground/offline parity
## BIT-EXACT for a static run (identical inputs → identical gold). A naive float
## accumulator ([code]Σ += rate[/code]) would DRIFT because N additions ≠ 1
## multiplication in IEEE-754 (6.4×10 ≠ 6.4+6.4+…). None of these are persisted —
## they reset on run end; the offline batch re-derives the full total from scratch.
##
## 1-based floor of the current segment; [code]0[/code] when no run is active.
var _fg_drip_active_floor: int = 0

## Un-floored per-tick rate of the current segment (BASE_DRIP × strength × matchup).
var _fg_drip_rate: float = 0.0

## Ticks elapsed in the current segment — the exact integer counter that replaces
## a drifting float accumulator. The parity-safe heart of S28-G1.
var _fg_drip_segment_ticks: int = 0

## Cumulative drip gold credited up to the START of the current segment.
var _fg_drip_segment_base: int = 0

## Total drip gold credited in the current run (cumulative across segments).
## Reset to 0 on run end. NOT persisted.
var _fg_drip_credited: int = 0

## Test-only DI override for the foreground drip's active-floor resolution.
## [code]-1[/code] (default) → [method _on_tick] resolves the active floor via
## [code]DungeonRunOrchestrator.get_active_floor_index()[/code]. [code]>= 0[/code]
## → [method _on_tick] uses this value directly (lets headless unit tests drive
## the real [method _on_tick] active-drip path without a live orchestrator
## autoload; [code]0[/code] simulates NO_RUN). Mirrors the
## [member _offline_replay_formation_strength_override] seam. Test-only.
var _fg_drip_floor_override: int = -1

## Test-only DI override for the foreground drip's formation-strength resolution.
## [code]< 0[/code] (default) → [method _on_tick] resolves via
## [code]HeroRoster.get_formation_strength()[/code]. [code]>= 0.0[/code] → uses
## this value directly. Test-only.
var _fg_drip_strength_override: float = -1.0

## Test-only DI override for the foreground drip's DEFEAT resolution (GDD #34 /
## ADR-0021). [code]-1[/code] (default) → [method _on_tick] resolves defeat via
## [code]DungeonRunOrchestrator.is_active_run_defeated()[/code]. [code]0[/code] →
## force not-defeated; [code]1[/code] → force DEFEATED (drip forfeits). Lets a
## headless unit test drive the real defeat-forfeit branch without a live
## orchestrator autoload. Mirrors [member _fg_drip_floor_override]. Test-only.
var _fg_drip_defeated_override: int = -1

## Cumulative gold delta accumulated during the current offline replay window.
## Per ADR-0013 Amendment #1 (Sprint 11 S11-X6): when [member _is_offline_replay]
## is true, add_gold + try_spend + try_award_floor_clear's gold side-effects
## accumulate here instead of emitting [signal gold_changed] per-call. The
## aggregate is flushed by [method flush_offline_signals] which emits ONE
## [signal gold_changed] with the cumulative delta + reason
## [code]"offline_replay_aggregate"[/code].
##
## Cleared by [method flush_offline_signals] post-emit.
var _offline_pending_delta: int = 0

## (biome_id, floor_index) pairs pending [signal first_clear_awarded] aggregate
## emission per ADR-0013 Amendment #1. When [member _is_offline_replay] is true
## and a [method try_award_floor_clear] call matches the first-clear gate, the
## pair is appended here instead of emitting per-call. Flushed in insertion
## order by [method flush_offline_signals].
##
## Sprint 17 schema v2 widening: previously Array[int] (floor_index only).
## Now Array[Array] with [biome_id, floor_index] tuples to match the widened
## signal payload.
##
## Per OfflineProgressionEngine GDD §C.3 signal suppression policy:
## first_clear_awarded fires POST-replay for each first-cleared (biome, floor)
## pair in the offline window (not per-chunk).
var _offline_pending_first_clears: Array[Array] = []

## Resolved EconomyConfig instance from DataRegistry. Populated in _ready().
## Null if DataRegistry has not yet reached READY state (e.g. during boot
## errors). Consumers (Stories 003+) call get_config() rather than reading
## this field directly.
## ADR-0013 §Requirements — single source of truth for tuning knobs.
var _config: EconomyConfig = null

## Test-only DI override for the formation_strength input read by
## [method compute_offline_batch]. Set via [method set_offline_replay_inputs].
##
## Sentinel value [code]-1.0[/code] means "no override — fall through to
## [code]HeroRoster.get_formation_strength()[/code] (or default 1.0 if the
## autoload is absent in test envs)". Any non-negative float is used verbatim.
##
## Production callers MUST NOT set this — the OfflineProgressionEngine is the
## sole legitimate source of offline replay inputs and reads them from the
## RunSnapshot, not via this override.
var _offline_replay_formation_strength_override: float = -1.0

## Test-only DI override for the floor_index input read by
## [method compute_offline_batch]. Set via [method set_offline_replay_inputs].
##
## Sentinel value [code]0[/code] means "no override — fall through to floor 1
## as the safe default". Any value in [code][1, 5][/code] is used verbatim.
##
## Production callers MUST NOT set this — the future RunSnapshot integration
## will pass floor_index per the offline window's active floor.
var _offline_replay_floor_index_override: int = 0

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

## Zero-arg _init required by ADR-0003 Amendment #3.
## Godot autoload Nodes are instantiated with zero arguments by the engine;
## any required parameter on _init would silently fail instantiation.
## Do NOT read or subscribe to other autoloads here — use _ready() instead.
func _init() -> void:
	pass


## Establishes the tick subscription and resolves EconomyConfig at boot.
##
## Rank-3 safety (ADR-0003 Amendment #1): DataRegistry (rank 1) and
## TickSystem (rank 0) have completed their _ready() calls by the time
## Economy's _ready() fires, so signal subscriptions and DataRegistry.resolve()
## calls here are safe.
##
## Resolved at boot below; null-check on miss. Story 006 wires the
## TickSystem.tick_fired subscription and the drip math (still pending).
##
## ADR-0003 Amendment #1, ADR-0013 §Requirements
func _ready() -> void:
	_config = DataRegistry.resolve("config", "economy_config") as EconomyConfig
	if _config == null:
		push_error("Economy._ready: failed to resolve EconomyConfig from DataRegistry. " +
			"DataRegistry should already be in ERROR state if config is missing.")
	# First-launch gold seed wiring per Onboarding GDD #29 §C.1 + §D.1 +
	# AC-29-03. Cross-autoload subscription is safe at _ready() per ADR-0003
	# §Signal Subscription rule. On returning-launch, load_save_data runs
	# before first_launch fires, so the persisted balance is preserved.
	if has_node("/root/SaveLoadSystem"):
		var sl: Node = get_node("/root/SaveLoadSystem")
		if sl.has_signal("first_launch") and not sl.first_launch.is_connected(_on_first_launch):
			sl.first_launch.connect(_on_first_launch)
	# S28-G1: foreground per-tick drip subscription. TickSystem (rank 0) has
	# completed _ready() before Economy (rank 3) per ADR-0003 rank ordering, so
	# the subscription here is safe. Idempotent guard prevents double-connection
	# on hot-reload. _on_tick() guards _is_offline_replay so offline batch never
	# double-credits the drip path.
	if not TickSystem.tick_fired.is_connected(_on_tick):
		TickSystem.tick_fired.connect(_on_tick)


## Computes the un-floored per-tick drip rate for a given floor and formation
## strength. Shared by both the foreground accumulator path ([method _on_tick])
## and the offline closed-form path ([method compute_offline_batch]) so both
## paths use EXACTLY the same rate function — parity is guaranteed by
## construction.
##
## Returns 0.0 when:
## - [param floor_index] is out of [code][1, 5][/code].
## - [member _config] is null.
## - [member _config.BASE_DRIP] is shorter than [param floor_index] entries.
## - [param formation_strength] is 0.0 (empty formation guard).
##
## Formula: [code]float(BASE_DRIP[floor_index-1]) * formation_strength * MATCHUP_DRIP_BONUS[/code]
##
## [param floor_index]: Active 1-based floor index.
## [param formation_strength]: From [code]HeroRoster.get_formation_strength()[/code].
##   Range [1.0, 3.0] per ADR-0012; 0.0 signals empty formation → zero drip.
##
## S28-G1 — GDD §D.1 + §C.2.1 accumulator note (2026-06-08).
func _drip_rate_per_tick(floor_index: int, formation_strength: float) -> float:
	if _config == null:
		return 0.0
	if floor_index < 1 or floor_index > _config.BASE_DRIP.size():
		return 0.0
	if formation_strength <= 0.0:
		return 0.0
	return float(_config.BASE_DRIP[floor_index - 1]) * formation_strength * _config.MATCHUP_DRIP_BONUS


## Per-tick handler for the foreground drip path.
##
## Called via [signal TickSystem.tick_fired] (subscribed in [method _ready]).
## Uses a count-based segment model: within a constant-rate segment the running
## credited total is [code]_fg_drip_segment_base + floori(rate * segment_ticks)[/code]
## — the SAME single-multiply-then-floor expression [method compute_offline_batch]
## uses — so Σ over N ticks == floori(rate × N) == the offline closed-form,
## BIT-EXACTLY. (A float accumulator would drift: N additions ≠ 1 multiplication
## in IEEE-754.)
##
## Guards / transitions:
## - [member _is_offline_replay] true → return (offline batch owns that path).
## - No active run (floor == 0) → reset all segment state; return.
## - Floor change OR rate change → bank the segment, start a new one.
## - HeroRoster absent or empty formation (strength 0.0) → rate 0 → no credit.
##
## [param _n]: monotonic tick counter from TickSystem (the rate is per-tick, so we
##   always advance the segment by exactly one tick).
##
## S28-G1 — GDD §C.2.1 + §D.1 (state table row: ACTIVE | tick_fired → _on_tick()).
func _on_tick(_n: int) -> void:
	# Offline batch owns the drip path during replay — never double-credit.
	if _is_offline_replay:
		return

	# Resolve the active floor. Test seam first (lets unit tests drive this path
	# without a live orchestrator); otherwise via DungeonRunOrchestrator, guarded
	# by is_inside_tree() so an orphan Economy in a unit test stays at floor 0.
	var active_floor: int = 0
	if _fg_drip_floor_override >= 0:
		active_floor = _fg_drip_floor_override
	elif is_inside_tree():
		var orchestrator: Node = get_node_or_null("/root/DungeonRunOrchestrator")
		if orchestrator != null and orchestrator.has_method("get_active_floor_index"):
			active_floor = int(orchestrator.get_active_floor_index())

	# No active run → reset all segment state so nothing bleeds into the next run.
	if active_floor == 0:
		_fg_drip_active_floor = 0
		_fg_drip_rate = 0.0
		_fg_drip_segment_ticks = 0
		_fg_drip_segment_base = 0
		_fg_drip_credited = 0
		return

	# Phase 1 (GDD #34 / ADR-0021) defeat-forfeit gate (AC-34-08): a DEFEATED run
	# earns ZERO drip for its entire duration. The WIN/DEFEAT verdict is resolved
	# once at dispatch, so is_active_run_defeated() is true from tick 1 of a doomed
	# run → the whole run forfeits the drip, mirroring the offline batch's
	# zero-credit window. Reset the segment state (same as NO_RUN) so no partial
	# credit bleeds, then return without crediting.
	var run_is_defeated: bool = false
	if _fg_drip_defeated_override >= 0:
		run_is_defeated = _fg_drip_defeated_override == 1
	elif is_inside_tree():
		var def_orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
		if def_orch != null and def_orch.has_method("is_active_run_defeated"):
			run_is_defeated = bool(def_orch.is_active_run_defeated())
	if run_is_defeated:
		_fg_drip_active_floor = 0
		_fg_drip_rate = 0.0
		_fg_drip_segment_ticks = 0
		_fg_drip_segment_base = 0
		_fg_drip_credited = 0
		return

	# Resolve formation strength. Test seam first; otherwise via HeroRoster
	# (is_inside_tree guarded). Absent roster / empty formation → 0.0 → no drip.
	var formation_strength: float = 0.0
	if _fg_drip_strength_override >= 0.0:
		formation_strength = _fg_drip_strength_override
	elif is_inside_tree():
		var roster: Node = get_node_or_null("/root/HeroRoster")
		if roster != null and roster.has_method("get_formation_strength"):
			formation_strength = float(roster.get_formation_strength())

	var rate: float = _drip_rate_per_tick(active_floor, formation_strength)

	# New segment on floor change OR rate change: bank credited-so-far as the new
	# segment base and restart the tick counter. Within a segment the rate is
	# constant, so floori(rate * segment_ticks) matches the offline closed-form
	# bit-for-bit (same single multiplication, not an accumulated sum).
	if active_floor != _fg_drip_active_floor or not is_equal_approx(rate, _fg_drip_rate):
		_fg_drip_segment_base = _fg_drip_credited
		_fg_drip_segment_ticks = 0
		_fg_drip_active_floor = active_floor
		_fg_drip_rate = rate

	_fg_drip_segment_ticks += 1
	var target: int = _fg_drip_segment_base + floori(rate * float(_fg_drip_segment_ticks))
	var delta: int = target - _fg_drip_credited
	if delta > 0:
		add_gold(delta)
		_fg_drip_credited = target


## Test-only seam: inject the foreground drip inputs so [method _on_tick] can be
## driven from a headless unit test without live DungeonRunOrchestrator /
## HeroRoster autoloads. Pass [param floor_index] [code]<= 0[/code] to simulate
## NO_RUN, or a 1-based floor to simulate an active run; [param formation_strength]
## [code]0.0[/code] simulates an empty formation. Mirrors the offline
## [method set_offline_replay_inputs] test seam (ADR-0013 test-DI precedent).
func set_foreground_drip_inputs_for_test(floor_index: int, formation_strength: float) -> void:
	_fg_drip_floor_override = floor_index
	_fg_drip_strength_override = formation_strength


## Test-only seam: force the foreground drip's DEFEAT verdict so [method _on_tick]'s
## defeat-forfeit gate (GDD #34 / ADR-0021 / AC-34-08) can be driven from a headless
## unit test without a live DungeonRunOrchestrator. Pass [code]true[/code] to force a
## DEFEATED run (drip forfeits), [code]false[/code] to force a normal (won) run.
## Mirrors [method set_foreground_drip_inputs_for_test].
func set_foreground_drip_defeated_for_test(is_defeated: bool) -> void:
	_fg_drip_defeated_override = 1 if is_defeated else 0


## Seeds [member _gold_balance] to [member EconomyConfig.STARTING_GOLD] on
## first-launch. Wired by [method _ready] subscribing to
## [signal SaveLoadSystem.first_launch]. Per Onboarding GDD #29 §C.1 + §D.1 +
## AC-29-03. Lifetime gold stays at 0 — the starting gift is not "earned".
func _on_first_launch() -> void:
	if _config == null:
		push_error(
			"Economy._on_first_launch: _config is null — cannot seed STARTING_GOLD. "
			+ "DataRegistry should already be in ERROR state."
		)
		return
	_gold_balance = _config.STARTING_GOLD
	# Guard required by tests/unit/offline_progression_engine/offline_forbidden_patterns_ci_grep_test.gd —
	# semantically unreachable since first_launch and offline replay are
	# mutually exclusive, but the CI grep enforces uniform emit guarding.
	if not _is_offline_replay:
		gold_changed.emit(_gold_balance, _config.STARTING_GOLD, "first_launch_seed")

# ---------------------------------------------------------------------------
# Public API — write methods
# ---------------------------------------------------------------------------

## Adds [param amount] gold to the balance and updates lifetime earned.
##
## Positive-only: [param amount] must be > 0; if not, calls [method push_error]
## and returns early without mutating state or emitting a signal.
##
## Sanity-cap-clamped: if [code]_gold_balance + amount > GOLD_SANITY_CAP[/code],
## [member _gold_balance] is set to [constant GOLD_SANITY_CAP]. The [param delta]
## carried by [signal gold_changed] reflects the actual increment applied to the
## balance, not the requested amount.
##
## Lifetime-unclamped: [member _lifetime_gold_earned] always increases by the full
## requested [param amount], regardless of clamp. It is an unbounded faucet statistic.
##
## Signal-suppressed during offline replay: when [member _is_offline_replay] is
## [code]true[/code], state mutations occur silently. One aggregate [signal gold_changed]
## fires after [method compute_offline_batch] completes (Story 010).
##
## Example:
##   Economy.add_gold(500)  # adds 500 to the gold balance
##
## ADR-0013 §Requirements — GDD §C.2, §D.1, §D.2
func add_gold(amount: int) -> void:
	if amount <= 0:
		push_error("Economy.add_gold: amount=%d must be positive" % amount)
		return
	var actual_delta: int = amount
	var projected: int = _gold_balance + amount
	if projected > GOLD_SANITY_CAP:
		actual_delta = GOLD_SANITY_CAP - _gold_balance
		_gold_balance = GOLD_SANITY_CAP
	else:
		_gold_balance = projected
	_lifetime_gold_earned += amount  # statistic — unclamped; takes the requested amount even if balance clamped
	# ADR-0013 Amendment #1: during offline replay, accumulate the delta
	# instead of emitting per-call. flush_offline_signals emits the aggregate
	# post-replay.
	if _is_offline_replay:
		_offline_pending_delta += actual_delta
	else:
		gold_changed.emit(_gold_balance, actual_delta, "add_gold")


## Attempts to deduct [param amount] gold from the balance atomically.
##
## Atomic: either the full deduction succeeds (returns [code]true[/code]) or
## nothing changes (returns [code]false[/code]). No partial mutations.
## Atomicity is guaranteed by GDScript's single-threaded main loop (ADR-0013 §E.6).
##
## Semantics:
## - [b]Negative amount[/b]: calls [method push_error] and returns [code]false[/code];
##   balance and signal are both unchanged.
## - [b]Zero amount[/b]: defined no-op — returns [code]true[/code] immediately;
##   no state mutation, no [signal gold_changed] emission (AC H-12).
## - [b]Insufficient balance[/b]: returns [code]false[/code]; no state mutation,
##   no signal (AC H-05).
## - [b]Sufficient balance[/b]: deducts [param amount] from [member _gold_balance],
##   emits [signal gold_changed]([code]_gold_balance, -amount, reason[/code]) UNLESS
##   [member _is_offline_replay] is [code]true[/code], and returns [code]true[/code]
##   (AC H-06).
##
## Signal-suppressed during offline replay: when [member _is_offline_replay] is
## [code]true[/code], the state mutation occurs silently. One aggregate
## [signal gold_changed] fires after [method compute_offline_batch] completes (Story 010).
##
## Note: [method try_spend] does NOT update [member _lifetime_gold_earned].
## That statistic tracks income only, not spending (ADR-0013 §State).
##
## [param amount]: Gold to spend. Must be >= 0.
## [param reason]: Telemetry label identifying the spend site (e.g. "recruit",
##   "level_up"). Propagated verbatim into [signal gold_changed]'s third argument.
##
## Example:
##   if Economy.try_spend(150, "recruit"):
##       HeroRoster.add_hero("warrior")
##
## ADR-0013 §Requirements — GDD §C.3, §H-05, §H-06, §H-12, §E.6
func try_spend(amount: int, reason: String) -> bool:
	if amount < 0:
		push_error("Economy.try_spend: amount=%d must be non-negative" % amount)
		return false
	if amount == 0:
		return true  # no-op true; no signal, no mutation (AC H-12)
	if _gold_balance < amount:
		return false  # insufficient — no signal, no mutation (AC H-05)
	_gold_balance -= amount
	# ADR-0013 Amendment #1: accumulate negative delta during offline replay.
	if _is_offline_replay:
		_offline_pending_delta += -amount
	else:
		gold_changed.emit(_gold_balance, -amount, reason)
	return true


## Awards a floor-clear bonus using the monotonic-credit-gap contract.
##
## Returns [code]true[/code] if any new gold was credited; [code]false[/code]
## if [param bonus_amount] is at or below the previously credited amount for
## this floor (no double-credit, per ADR-0002).
##
## Credit-the-gap semantic: only the DELTA above [member _floor_clear_bonus_credited]
## is added via [method add_gold]. This supports the LOSING-then-WIN reclaim path:
## a LOSING run credits the halved bonus first; a subsequent WIN credits only the
## remaining gap. The first-clear milestone ([signal first_clear_awarded]) fires only
## on the initial credit for each floor (when [code]already == 0[/code]) and is NOT
## re-emitted on reclaim deltas — the milestone already fired on the first credit.
##
## At-or-below-ceiling paths (zero-bonus, repeat-WIN, LOSING-after-WIN) return
## [code]false[/code] silently with no state mutation.
##
## [param floor_index]: Floor index (1..5). Out-of-range values call [method push_error]
##   and return [code]false[/code] without mutating the ledger.
## [param bonus_amount]: Total bonus to credit for this floor. Must be >= 0.
##   Negative values call [method push_error] and return [code]false[/code].
##   The DELTA above the stored ceiling is added via [method add_gold].
##
## Signal suppression: [signal first_clear_awarded] is suppressed when
##   [member _is_offline_replay] is [code]true[/code]. [method add_gold] already
##   self-suppresses [signal gold_changed] during offline replay.
##
## Sprint 17 schema v2: signature widened to take [param biome_id] as the
## first param to support multi-biome progression. Pre-v2 callers (single-biome
## tests, MVP code paths) must pass [code]"forest_reach"[/code] explicitly.
##
## [param biome_id]: Biome identifier (e.g. [code]"forest_reach"[/code],
##   [code]"frostmire"[/code]). Empty string is rejected with [method push_error].
##
## Example:
##   Economy.try_award_floor_clear("forest_reach", 2, 1200)  # credits Forest Reach F2 first-clear
##   Economy.try_award_floor_clear("frostmire", 5, 2500)     # credits Frostmire F5 first-clear
##
## ADR-0013 §Requirements — ADR-0002 monotonic-credit contract (Sprint 17 amendment
## for multi-biome ledger) — GDD §C.4, §D.5
func try_award_floor_clear(biome_id: String, floor_index: int, bonus_amount: int) -> bool:
	if biome_id.is_empty():
		push_error("Economy.try_award_floor_clear: biome_id is empty — refusing to credit")
		return false
	if floor_index < 1 or floor_index > 5:
		push_error("Economy.try_award_floor_clear: floor_index=%d out of range [1,5]" % floor_index)
		return false
	if bonus_amount < 0:
		push_error("Economy.try_award_floor_clear: bonus_amount=%d is negative (authoring bug)" % bonus_amount)
		return false
	var key: String = "%s_f%d" % [biome_id, floor_index]
	var already: int = _floor_clear_bonus_credited.get(key, 0)
	if bonus_amount <= already:
		return false  # at-or-below ceiling; covers zero-bonus, repeat-WIN, LOSING-after-WIN
	var delta: int = bonus_amount - already
	var is_first: bool = already == 0  # captured before add_gold mutates any state
	add_gold(delta)  # routes through the canonical mutation site; updates lifetime
	_floor_clear_bonus_credited[key] = bonus_amount
	# ADR-0013 Amendment #1: during offline replay, accumulate first-clear
	# (biome_id, floor_index) pairs for post-replay aggregate emission
	# (preserves OfflineProgressionEngine GDD §C.3 contract: first_clear_awarded
	# fires POST-replay for each first-cleared (biome, floor) pair in the
	# offline window).
	if is_first:
		if _is_offline_replay:
			_offline_pending_first_clears.append([biome_id, floor_index])
		else:
			first_clear_awarded.emit(biome_id, floor_index)
	return true


## Computes the full offline gold batch for [param tick_budget] ticks via the
## closed-form drip path (single multiplication — NOT a per-tick loop).
##
## Determinism contract (AC H-09): for identical starting state, this call
## produces a [member OfflineResult.total_gold] equal to what
## [code]tick_budget[/code] foreground tick_fired emissions would have produced
## via the canonical drip path. Bit-exact across repeated runs.
##
## Sequence:
##   1. Defensive guard: [param tick_budget] [code]<= 0[/code] returns an empty
##      [OfflineResult] with zero state changes and no signal emissions.
##   2. [member _is_offline_replay] flips to [code]true[/code], suppressing
##      [signal gold_changed] / [signal first_clear_awarded] emissions inside
##      [method add_gold] and [method try_award_floor_clear] for the duration.
##   3. Closed-form drip: [code]drip_total = floori(BASE_DRIP[floor-1] * formation_strength
##      * MATCHUP_DRIP_BONUS * tick_budget)[/code] — a single multiplication, NOT a loop.
##   4. [method add_gold] is called once with the cumulative drip_total.
##   5. RunSnapshot kill events + floor clears (future integration via
##      OfflineProgressionEngine) are NOT yet wired — empty arrays for MVP.
##   6. [member _is_offline_replay] flips to [code]false[/code] BEFORE the
##      aggregate signal emit (so subscribers see the post-replay flag state).
##   7. Exactly ONE [signal gold_changed] with reason [constant OFFLINE_REPLAY_REASON]
##      fires AFTER replay completes (skipped when total_delta == 0).
##
## RNG seed contract (per ADR-0013 §Decision): seeded RNG for any future
## event-cadence estimation uses [code]t_last_persist XOR offline_tick_budget[/code].
## MVP closed-form drip path does NOT consume any random numbers — the seed
## contract is established here for forward-compat; Story 011's chunking +
## kill-event integration will exercise it.
##
## Inputs (formation_strength + floor_index) are resolved via
## [method _resolve_offline_replay_formation_strength] and
## [method _resolve_offline_replay_floor_index]. Tests inject via
## [method set_offline_replay_inputs]; production reads from [HeroRoster] +
## the future RunSnapshot integration.
##
## [param tick_budget]: Number of offline ticks to replay. Capped upstream
##   by [code]TickSystem.offline_cap_seconds × TICKS_PER_SECOND[/code]
##   (default 28_800 × 20 = 576_000 ticks at 8h cap). Values [code]<= 0[/code]
##   return an empty result.
##
## Returns an [OfflineResult] (RefCounted; auto-frees when last reference drops).
##
## Example:
##   var result: Economy.OfflineResult = Economy.compute_offline_batch(576_000)
##   print("offline gold: %d" % result.total_gold)
##
## ADR-0013 §Decision §C.6 — ADR-0014 (chunking out of scope here)
func compute_offline_batch(tick_budget: int) -> OfflineResult:
	var result: OfflineResult = OfflineResult.new()
	if tick_budget <= 0:
		return result
	if _config == null:
		push_error("Economy.compute_offline_batch: _config is null — cannot compute drip. " +
			"DataRegistry boot likely failed; this method requires resolved EconomyConfig.")
		return result
	# CODE REVIEW 2026-06-16 (C2): be caller-aware about the offline-replay
	# suppression window. The OfflineProgressionEngine drives this method ONCE PER
	# CHUNK inside an externally-managed window — it sets _is_offline_replay = true
	# around the whole loop and emits a SINGLE aggregate via flush_offline_signals
	# afterward. When driven that way we must NOT (a) clear the flag here (clearing
	# it mid-loop unsuppresses add_gold on later chunks AND lets a foreground
	# _on_tick double-credit during the engine's inter-chunk `await process_frame`),
	# nor (b) emit a per-chunk gold_changed (which double-announces the offline gold
	# the aggregate already covers). Only self-manage the flag + emit when called
	# STANDALONE (was_replay == false) — e.g. a direct unit test.
	var was_replay: bool = _is_offline_replay
	if not was_replay:
		_is_offline_replay = true
	var balance_before: int = _gold_balance
	# Closed-form drip: single multiplication via the shared _drip_rate_per_tick helper.
	# S28-G1: refactored from an inline formula to use _drip_rate_per_tick so the
	# foreground and offline paths share EXACTLY one rate function — parity is
	# guaranteed by construction. Algebraically identical to the old inline form:
	#   float(BASE_DRIP[floor-1]) * formation_strength * MATCHUP_DRIP_BONUS * tick_budget
	var formation_strength: float = _resolve_offline_replay_formation_strength()
	var floor_index: int = _resolve_offline_replay_floor_index()
	var drip_total: int = floori(_drip_rate_per_tick(floor_index, formation_strength) * float(tick_budget))
	if drip_total > 0:
		add_gold(drip_total)
	# RunSnapshot kill events + floor clears — not yet integrated with the
	# OfflineProgressionEngine RunSnapshot schema; out of scope for this
	# determinism story (Story 011 + Feature epic land that wiring).
	# Build the event log entry for the drip arm — feeds the Return-to-App HUD.
	if drip_total > 0:
		result.events_log.append({
			"type": "drip",
			"amount": drip_total,
			"ticks": tick_budget,
			"floor_index": floor_index,
			"formation_strength": formation_strength,
		})
	result.total_gold = _gold_balance - balance_before
	# Future stories populate floors_cleared from try_award_floor_clear during
	# the batch (the call site appends to result.floors_cleared); empty for MVP.
	if not was_replay:
		# Standalone call (no engine-managed window): close the flag and announce
		# this batch's net delta as the single aggregate, exactly as before.
		# Emit AFTER the flag clears (re-entrant subscribers see post-replay state);
		# skip a zero-delta no-op so consumers don't get a phantom update.
		_is_offline_replay = false
		if result.total_gold != 0:
			gold_changed.emit(_gold_balance, result.total_gold, OFFLINE_REPLAY_REASON)
	# When was_replay (engine-driven): leave _is_offline_replay set and the drip
	# accumulated in _offline_pending_delta. The engine clears the flag after the
	# loop and flush_offline_signals emits the ONE aggregate gold_changed.
	return result


## Test-only DI seam for [method compute_offline_batch] inputs.
##
## Production callers MUST NOT use this method — the OfflineProgressionEngine
## is the sole legitimate source of offline replay inputs and reads them from
## the RunSnapshot. This setter exists so Story 010 determinism tests can
## inject fixed values without booting the full HeroRoster + RunSnapshot stack.
##
## Pass [code]formation_strength = -1.0[/code] to clear the override (return
## to autoload-read fallback). Pass [code]floor_index = 0[/code] to clear that
## override.
##
## [param formation_strength]: Override value in [code][1.0, 3.0][/code] per
##   ADR-0012, or [code]-1.0[/code] to clear.
## [param floor_index]: Override value in [code][1, 5][/code], or [code]0[/code]
##   to clear.
##
## Example (test):
##   economy.set_offline_replay_inputs(1.0, 2)
##   var result: Economy.OfflineResult = economy.compute_offline_batch(576_000)
##
## ADR-0013 §Requirements — DI seam pattern matches [method set_economy_config].
func set_offline_replay_inputs(formation_strength: float, floor_index: int) -> void:
	_offline_replay_formation_strength_override = formation_strength
	_offline_replay_floor_index_override = floor_index


## Resolves the formation_strength input for [method compute_offline_batch].
##
## Order of precedence:
##   1. Test override via [method set_offline_replay_inputs] (>= 0.0).
##   2. [code]HeroRoster.get_formation_strength()[/code] when the autoload is
##      present (production path).
##   3. Safe default of [code]1.0[/code] when no source is available
##      (test envs without autoloads).
func _resolve_offline_replay_formation_strength() -> float:
	if _offline_replay_formation_strength_override >= 0.0:
		return _offline_replay_formation_strength_override
	var roster: Node = (
		get_node_or_null("/root/HeroRoster") if get_tree() != null else null
	)
	if roster != null and roster.has_method("get_formation_strength"):
		return roster.get_formation_strength()
	return 1.0


## Resolves the floor_index input for [method compute_offline_batch].
##
## Order of precedence:
##   1. Test override via [method set_offline_replay_inputs] (in [code][1, 5][/code]).
##   2. Safe default of [code]1[/code] (the floor where every save begins).
##
## DungeonRunOrchestrator does not yet expose a public "current floor for
## offline replay" accessor; the future RunSnapshot integration will pass
## the active floor explicitly. Until then, the safe default holds and the
## test override is the production-equivalent surface.
func _resolve_offline_replay_floor_index() -> int:
	if _offline_replay_floor_index_override >= 1 and _offline_replay_floor_index_override <= 5:
		return _offline_replay_floor_index_override
	return 1


## Drains per-chunk-suppressed offline-replay signals into single aggregate
## emissions, then clears [member _is_offline_replay].
##
## Sprint 11 S11-X6 / ADR-0013 Amendment #1. Called by OfflineProgressionEngine
## after the chunk-iteration loop completes per OfflineProgressionEngine GDD
## §C.2 (rank 15 boot-time orchestrator). Per the GDD §C.3 signal-suppression
## policy:
##   - [signal gold_changed] fires ONCE with the cumulative delta (reason
##     [code]"offline_replay_aggregate"[/code]) — only if the cumulative
##     delta is non-zero (no zero-delta noise emit).
##   - [signal first_clear_awarded] fires ONCE per accumulated floor index
##     in the order they were appended.
##   - [member _is_offline_replay] is cleared to [code]false[/code] AFTER
##     the aggregate emissions (so any subscribers that re-enter Economy
##     during the emission see the post-replay flag state).
##
## Idempotent: calling on an empty / already-flushed accumulator is a no-op
## (no signals fire, flag clears safely).
##
## Sprint 12+ OfflineProgressionEngine implementation owns the call site;
## this method is the API surface the engine binds against.
##
## ADR-0013 Amendment #1, OfflineProgressionEngine GDD §F (Story 0a).
func flush_offline_signals() -> void:
	# Aggregate gold_changed emit (only if non-zero — zero-delta is silent).
	if _offline_pending_delta != 0:
		gold_changed.emit(_gold_balance, _offline_pending_delta, "offline_replay_aggregate")
	# Aggregate first_clear_awarded emits in insertion order. Sprint 17 schema
	# v2: each entry is [biome_id: String, floor_index: int].
	for pair: Array in _offline_pending_first_clears:
		first_clear_awarded.emit(String(pair[0]), int(pair[1]))
	# Clear accumulators + replay flag.
	_offline_pending_delta = 0
	_offline_pending_first_clears.clear()
	_is_offline_replay = false


## Returns the economy state for serialisation by SaveLoadSystem.
##
## Keys (fixed insertion order per ADR-0004):
##   "schema_version" → [constant SAVE_SCHEMA_VERSION]
##   "gold_balance" → [member _gold_balance]
##   "lifetime_gold_earned" → [member _lifetime_gold_earned]
##   "floor_clear_bonus_credited" → [member _floor_clear_bonus_credited] (deep-copied)
##
## [member _is_offline_replay] and the offline accumulator fields are NOT
## included — they are transient and re-derived on demand.
##
## The [code]floor_clear_bonus_credited[/code] dictionary is deep-copied via
## [code]Dictionary.duplicate(true)[/code] so callers cannot accidentally
## mutate Economy's internal ledger by modifying the returned value (and
## conversely, post-save Economy mutations don't bleed into the persisted dict).
##
## Example:
##   var data: Dictionary = Economy.get_save_data()
##   # data == {"schema_version": 1, "gold_balance": 500,
##   #          "lifetime_gold_earned": 1200, "floor_clear_bonus_credited": {1: 500}}
##
## ADR-0013 §Requirements — ADR-0004 consumer contract
func get_save_data() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"gold_balance": _gold_balance,
		"lifetime_gold_earned": _lifetime_gold_earned,
		"floor_clear_bonus_credited": _floor_clear_bonus_credited.duplicate(true),
	}


## Restores economy state from a SaveLoadSystem envelope.
##
## Validates [code]schema_version[/code] first (must equal [constant SAVE_SCHEMA_VERSION]
## or the load aborts via [code]push_error[/code] with the instance state
## unchanged). On schema match, hydrates the three persisted state fields with
## safe defaults for missing keys.
##
## Signal-quiet during restore: [signal gold_changed] / [signal first_clear_awarded]
## are NOT emitted by this method. The hydration assigns to [member _gold_balance]
## directly (NOT via [method add_gold]), so the signal-suppression contract holds
## without any flag-flipping. The pseudocode in the story file's Implementation
## Notes proposes reusing [member _is_offline_replay] as a defensive guard; we
## omit it here because no signal-emitting path is reachable from the field
## assignments below — the simpler implementation is the safer one.
##
## JSON round-trip type-safety (per project memory `project_json_int_round_trip_typeof_pattern`):
##   - Numeric values may arrive as either [code]TYPE_INT[/code] or [code]TYPE_FLOAT[/code]
##     (JSON.parse_string yields TYPE_FLOAT). All numeric reads pass through
##     [code]int(...)[/code] for safety.
##   - Dictionary keys may arrive as [code]String[/code] when round-tripped
##     through JSON. The [code]floor_clear_bonus_credited[/code] dict is rebuilt
##     key-by-key with explicit [code]int(key)[/code] coercion so a typed
##     [code]Dictionary[int, int][/code] target is honored.
##
## Forward-compat: extra unknown keys in [param data] are tolerated and ignored.
## Backward-compat: missing optional keys default to safe values
## ([code]gold_balance = 0[/code], [code]lifetime_gold_earned = 0[/code],
## [code]floor_clear_bonus_credited = {}[/code]).
##
## [param data]: Dictionary as returned by [method get_save_data] (possibly
##   round-tripped through SaveLoadSystem's JSON envelope).
##
## Example:
##   Economy.load_save_data({"schema_version": 1, "gold_balance": 500,
##       "lifetime_gold_earned": 1200, "floor_clear_bonus_credited": {1: 500}})
##
## ADR-0013 §Requirements — ADR-0004 consumer contract
func load_save_data(data: Dictionary) -> void:
	if not data.has("schema_version"):
		push_error("Economy.load_save_data: missing schema_version key — load aborted, state unchanged")
		return
	var raw_version: Variant = data["schema_version"]
	# Defensive: a malicious / corrupt save could deliver a non-numeric
	# schema_version. Reject anything that isn't TYPE_INT or TYPE_FLOAT.
	if typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT:
		push_error(
			"Economy.load_save_data: schema_version has unexpected type=%d — load aborted"
			% typeof(raw_version)
		)
		return
	var version: int = int(raw_version)
	# Sprint 17: accept v1 (legacy, int-keyed ledger) and v2 (current,
	# String-keyed ledger). v1 → v2 migration prefixes int keys with
	# "forest_reach_f" since Sprint 11-era saves predate multi-biome
	# content and any cleared floors were implicitly Forest Reach.
	if version != 1 and version != SAVE_SCHEMA_VERSION:
		push_error(
			"Economy.load_save_data: unsupported schema_version=%d (expected 1 or %d) — load aborted, state unchanged"
			% [version, SAVE_SCHEMA_VERSION]
		)
		return

	# Schema OK — hydrate. Field assignments are direct (NOT via add_gold);
	# no signal-emitting path is reachable, so the signal-quiet contract holds
	# without any explicit flag-flipping.
	_gold_balance = int(data.get("gold_balance", 0))
	_lifetime_gold_earned = int(data.get("lifetime_gold_earned", 0))
	# Clamp restored balance defensively to GOLD_SANITY_CAP. A save authored
	# by a tampered build could exceed the cap; clamping keeps the in-memory
	# invariant consistent with add_gold's runtime ceiling.
	if _gold_balance > GOLD_SANITY_CAP:
		push_warning(
			"Economy.load_save_data: gold_balance=%d exceeds GOLD_SANITY_CAP=%d — clamping"
			% [_gold_balance, GOLD_SANITY_CAP]
		)
		_gold_balance = GOLD_SANITY_CAP
	if _gold_balance < 0:
		push_warning(
			"Economy.load_save_data: gold_balance=%d is negative — clamping to 0"
			% _gold_balance
		)
		_gold_balance = 0
	# Rebuild the floor-clear ledger. Sprint 17 schema v2 uses String keys
	# of the form "<biome_id>_f<floor_index>" (e.g. "forest_reach_f1").
	# v1 saves have int keys (floor_index alone, implicitly Forest Reach);
	# we migrate by prefixing with "forest_reach_f". The migration is
	# best-effort defensive: numeric-looking string keys on v2 also get
	# treated as legacy ints so a hand-edited save doesn't lose state.
	var ledger_in: Variant = data.get("floor_clear_bonus_credited", {})
	var ledger_out: Dictionary[String, int] = {}
	if typeof(ledger_in) == TYPE_DICTIONARY:
		for key: Variant in (ledger_in as Dictionary):
			var raw_value: Variant = (ledger_in as Dictionary)[key]
			var typed_value: int = int(raw_value)
			var typed_key: String = ""
			if typeof(key) == TYPE_INT:
				# Legacy v1 int key → migrate to "forest_reach_f<idx>".
				typed_key = "forest_reach_f%d" % int(key)
			elif typeof(key) == TYPE_FLOAT:
				typed_key = "forest_reach_f%d" % int(key)
			elif typeof(key) == TYPE_STRING:
				var s: String = String(key)
				# Defensive: a JSON round-trip can convert int keys to numeric-
				# looking strings ("1", "2", ...). If the entire string is digits,
				# treat as a legacy v1 entry; otherwise pass through as a v2 key.
				if s.is_valid_int():
					typed_key = "forest_reach_f%d" % s.to_int()
				else:
					typed_key = s
			else:
				push_warning(
					"Economy.load_save_data: floor_clear_bonus_credited has unexpected key type=%d — skipping entry"
					% typeof(key)
				)
				continue
			ledger_out[typed_key] = typed_value
	else:
		push_warning(
			"Economy.load_save_data: floor_clear_bonus_credited has unexpected type=%d — defaulting to empty"
			% typeof(ledger_in)
		)
	_floor_clear_bonus_credited = ledger_out

# ---------------------------------------------------------------------------
# Public API — read methods (display surfaces)
# ---------------------------------------------------------------------------

## Returns the current gold balance.
##
## Read-only accessor for display surfaces (HUD, recruit button grey-out).
## Always call this rather than reading [member _gold_balance] directly from
## outside this script.
##
## Example:
##   label.text = str(Economy.get_gold_balance())
##
## ADR-0013 §Requirements — GDD §C.1
func get_gold_balance() -> int:
	return _gold_balance


## Returns the cumulative lifetime gold earned (unbounded statistic).
##
## Useful for analytics and "total gold earned" achievement tracking.
## Never decreases — it is not the current balance.
##
## Example:
##   var lifetime: int = Economy.get_lifetime_gold_earned()
##
## ADR-0013 §Requirements
func get_lifetime_gold_earned() -> int:
	return _lifetime_gold_earned


## Returns [code]true[/code] if the first-clear bonus for [param floor_index]
## has already been credited this save lifetime.
##
## Reads the [member _floor_clear_bonus_credited] ledger: a floor is considered
## first-cleared when its stored value is > 0 (ADR-0002 monotonic invariant).
## Presentation layer uses this to decide whether to show the "first clear!"
## celebration overlay on the floor card.
##
## Sprint 17 schema v2: signature widened to take [param biome_id] for
## multi-biome support.
##
## [param biome_id]: Biome identifier (e.g. [code]"forest_reach"[/code]).
## [param floor_index]: Floor index to check (1..5).
##
## Example:
##   if Economy.is_first_clear_awarded("forest_reach", 3):
##       show_first_clear_badge(3)
##
## ADR-0013 §Requirements — ADR-0002 (Sprint 17 amendment for multi-biome).
func is_first_clear_awarded(biome_id: String, floor_index: int) -> bool:
	var key: String = "%s_f%d" % [biome_id, floor_index]
	return _floor_clear_bonus_credited.get(key, 0) > 0


## Returns the resolved [EconomyConfig] instance or [code]null[/code] if
## DataRegistry failed to load it. Stories 003+ use this to read tuning knobs;
## consumers must null-check (DataRegistry should have already errored if
## the config is missing, but defensive checks remain valuable).
##
## Example:
##   var cfg: EconomyConfig = Economy.get_config()
##   if cfg != null:
##       var drip: int = cfg.BASE_DRIP[floor_index - 1]
##
## ADR-0013 §Requirements
func get_config() -> EconomyConfig:
	return _config

# ---------------------------------------------------------------------------
# Cost curve queries (pure functions — no state mutation)
# ---------------------------------------------------------------------------

## Returns the gold cost to recruit one more copy of [param class_id] given
## that [param copies_owned] copies are already owned.
##
## Formula: [code]floori(BASE_RECRUIT[tier] × RECRUIT_RATIO^copies_owned)[/code]
## where tier is read from the [HeroClass] resource resolved via
## [code]DataRegistry.resolve("classes", class_id)[/code].
##
## Returns [code]-1[/code] (sentinel) on:
## - [param copies_owned] < 0 (authoring bug — push_error + return -1)
## - [member _config] null (boot failed OR test fixture did not seed)
## - DataRegistry.resolve returns null (orphan class_id — content patch
##   removed it OR save corruption)
## - tier not in BASE_RECRUIT keys (unknown tier — push_error + return -1)
##
## Pure function — no state mutation. Per ADR-0013 §recruit_cost: called on
## UI render + button-tap (user-driven cadence, not a hot path). Performance
## budget: <50 µs per call (DataRegistry.resolve + pow + floor).
##
## [param class_id]: Snake-case class identifier (e.g. "warrior").
## [param copies_owned]: Copies already in the roster, from
##   [code]HeroRoster.get_copies_owned(class_id)[/code]. Must be >= 0.
##
## Example:
##   var cost: int = Economy.recruit_cost("warrior", 2)
##   # tier 1 warrior, 2 copies owned: floori(150 × 1.8^2) = floori(486.0) = 486
##
## Sprint 12 S12-M1 — closes the Story 007 stub.
## ADR-0013 §Requirements + §recruit_cost semantics; GDD §D.3.
func recruit_cost(class_id: String, copies_owned: int) -> int:
	# Step 1: copies_owned non-negative guard. Negative values would invert
	# the geometric escalation (RECRUIT_RATIO^|−n| < 1.0) and produce a
	# fractional cost smaller than BASE_RECRUIT — soft authoring bug.
	if copies_owned < 0:
		push_error(
			"Economy.recruit_cost: copies_owned=%d negative (authoring bug) — class_id='%s'"
			% [copies_owned, class_id]
		)
		return -1

	# Step 2: config presence guard. _config is populated in _ready() from
	# DataRegistry; absence means a test fixture instantiated Economy.new()
	# without seeding _config, OR DataRegistry boot failed (production would
	# already have crashed via the _ready() push_error path).
	if _config == null:
		push_error(
			"Economy.recruit_cost: _config null — DataRegistry.resolve('config', 'economy_config') failed at boot OR test fixture did not seed _config (class_id='%s')"
			% class_id
		)
		return -1

	# Step 3: class_id resolution. Orphan class_ids return null per Save/Load
	# corruption-resilience contract; production push_error + sentinel.
	var class_data: Resource = DataRegistry.resolve("classes", class_id) as Resource
	if class_data == null:
		push_error(
			"Economy.recruit_cost: DataRegistry.resolve('classes', '%s') returned null — orphan class_id"
			% class_id
		)
		return -1

	# Step 4: tier lookup. BASE_RECRUIT is Dictionary[int, int] keyed by
	# HeroClass.tier (currently {1: 150, 2: 8000} per economy_config.tres).
	var tier: int = int(class_data.get("tier"))
	if not _config.BASE_RECRUIT.has(tier):
		push_error(
			"Economy.recruit_cost: tier %d not in BASE_RECRUIT keys %s (class_id='%s')"
			% [tier, _config.BASE_RECRUIT.keys(), class_id]
		)
		return -1

	# Step 5: geometric escalation. floori per the canonical curve convention
	# (matches level_cost shape + Recruitment.refresh_cost).
	var base: int = int(_config.BASE_RECRUIT[tier])
	var ratio: float = _config.RECRUIT_RATIO
	return int(floor(float(base) * pow(ratio, float(copies_owned))))


## Returns the gold cost to level a [param class_tier] hero from
## [param current_level] to [param current_level] + 1.
##
## Formula: [code]floori(BASE_LEVEL[class_tier] × LEVEL_RATIO^(current_level - 1))[/code]
## where BASE_LEVEL + LEVEL_RATIO + LEVEL_CAP come from [member _config]
## (EconomyConfig.tres).
##
## Returns [code]-1[/code] (sentinel) on:
## - [param current_level] >= LEVEL_CAP (past cap — no further leveling)
## - [param current_level] < 1 (authoring bug — heroes start at level 1)
## - [member _config] null (boot failed OR test fixture without seed)
## - [param class_tier] not in BASE_LEVEL keys (unknown tier)
##
## Pure function — no state mutation. Per ADR-0013 §level_cost: called on
## UI render + button-tap (user-driven cadence, not a hot path).
##
## [param class_tier]: Hero class tier (1..2). Maps to BASE_LEVEL key.
## [param current_level]: Hero's current level (1..LEVEL_CAP). Returns -1
##   if at or past cap (caller checks for -1 to disable Level-Up button).
##
## Example:
##   var cost: int = Economy.level_cost(1, 5)
##   # tier 1 hero at level 5 → floori(40 × 1.6^4) = floori(262.144) = 262
##
## Sprint 12 S12-N5 — closes the Story 008 stub (sibling to S12-M1
## recruit_cost). ADR-0013 §Requirements + §D.4 + AC H-08; GDD §D.4.
func level_cost(class_tier: int, current_level: int) -> int:
	# Step 1: config presence guard.
	if _config == null:
		push_error(
			"Economy.level_cost: _config null — DataRegistry.resolve('config', 'economy_config') failed at boot OR test fixture did not seed _config (class_tier=%d, current_level=%d)"
			% [class_tier, current_level]
		)
		return -1

	# Step 2: current_level lower-bound guard. Heroes start at level 1 per
	# HeroRoster.add_hero contract. Negative or zero values are an
	# authoring bug.
	if current_level < 1:
		push_error(
			"Economy.level_cost: current_level=%d < 1 (heroes start at level 1) — class_tier=%d"
			% [current_level, class_tier]
		)
		return -1

	# Step 3: cap guard. At-or-past-cap returns -1 sentinel; caller (Level-
	# Up UI) interprets this as "Level-Up button disabled."
	if current_level >= _config.LEVEL_CAP:
		return -1

	# Step 4: tier lookup. BASE_LEVEL is Dictionary[int, int] keyed by
	# class.tier (currently {1: 40, 2: 600} per economy_config.tres).
	if not _config.BASE_LEVEL.has(class_tier):
		push_error(
			"Economy.level_cost: class_tier %d not in BASE_LEVEL keys %s (current_level=%d)"
			% [class_tier, _config.BASE_LEVEL.keys(), current_level]
		)
		return -1

	# Step 5: geometric escalation per ADR-0013 §D.4 + GDD §D.4. floori
	# matches the canonical curve convention (recruit_cost + refresh_cost).
	# Note: exponent is (current_level - 1) so level 1 → ratio^0 = 1 → cost
	# == BASE_LEVEL (the FIRST level-up costs the base value).
	var base: int = int(_config.BASE_LEVEL[class_tier])
	var ratio: float = _config.LEVEL_RATIO
	return int(floor(float(base) * pow(ratio, float(current_level - 1))))
