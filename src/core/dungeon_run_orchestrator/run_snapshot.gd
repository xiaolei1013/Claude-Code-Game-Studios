## RunSnapshot — per-dispatch state owned by DungeonRunOrchestrator.
##
## Standalone [code]class_name RunSnapshot extends RefCounted[/code] per
## ADR-0014 §2 (each value type lives in a single file matching snake-case of
## the class name; matches MatchupResult / CombatBatchResult / OfflineResult
## file layouts). Automatic lifecycle via RefCounted prevents the manual-`free()`
## leak risk of [code]extends Object[/code].
##
## Owned exclusively by [DungeonRunOrchestrator]; mutated only by it. Persisted
## via [SaveLoadSystem] consumer contract per ADR-0004 with [method to_dict] /
## [method from_dict] (Story 002 wires the orchestrator's get/load_save_data).
##
## Field ownership model:
##   - Frozen-at-dispatch fields ([code]formation_snapshot[/code], [code]floor_id[/code],
##     [code]matchup_cache[/code]) — populated in DISPATCHING, read-only for the
##     remainder of the run.
##   - Tick-advancing fields ([code]current_tick[/code], [code]last_emitted_tick[/code])
##     — written by the Orchestrator on every [signal TickSystem.tick_fired].
##   - Idempotency fields ([code]losing_run[/code], [code]floor_clear_emitted[/code])
##     — written exactly once per dispatch by the Orchestrator's once-emit guards.
##
## ADR-0014: Offline Replay Batch Chunking + RunSnapshot Schema
## ADR-0010: Combat Resolver Snapshot
## ADR-0004: Save Envelope (consumer contract via Orchestrator)
class_name RunSnapshot extends RefCounted

# ---------------------------------------------------------------------------
# Frozen-at-dispatch fields (TR-orchestrator-005)
# ---------------------------------------------------------------------------

## Deep-copied formation state captured at DISPATCHING — never mutated mid-run.
## Story 004 wires the deep-copy from HeroRoster.get_formation_heroes().
var formation_snapshot: Dictionary = {}

## Floor reference serialized by id (resolved via DataRegistry on hydrate).
## Empty string means "no floor selected" (NO_RUN sentinel).
var floor_id: String = ""

## Per-archetype matchup advantage lookup, built once at DISPATCHING via
## MatchupResolver.is_advantaged(). Never recomputed mid-dispatch (ADR-0009).
var matchup_cache: Dictionary = {}

## Ordered tick events scheduled at DISPATCHING. Entries are dicts with
## per-event payload (tick, archetype, kill_count, etc.). Walked sequentially
## as `current_tick` advances; never reordered or rewritten mid-run.
var kill_schedule: Array = []


# ---------------------------------------------------------------------------
# Tick-advancing fields
# ---------------------------------------------------------------------------

## Absolute TickSystem run-tick at the current frame. Strictly monotonic;
## advanced by Orchestrator's tick_fired handler. Initialized to 0 at dispatch.
var current_tick: int = 0

## High-water mark of the most recently emitted tick. The Orchestrator's
## emit-events range is [code](last_emitted_tick, current_tick][/code]
## (half-open). Used to dedupe duplicate-tick signals (ADR-0010).
var last_emitted_tick: int = 0

## Number of times the formation has rotated through the floor's enemies.
## Advanced by Combat Resolver on loop completion. Never decremented.
var loop_counter: int = 0

## Running total of enemies killed since DISPATCHING. Advanced by the
## orchestrator's [code]_process_kill_events[/code] handler each tick.
## Sprint 7 S7-M13 added this field as part of the VS harness data path.
var kill_count: int = 0

## Player gold balance captured at dispatch validation time (just before
## state transition to ACTIVE_FOREGROUND). Captured by [code]Orchestrator.dispatch[/code]
## via [code]Economy.get_gold_balance()[/code] read; never updated post-
## capture. The Victory Moment screen (#25) reads this to compute the
## post-run gold delta = [code]post_run_balance - pre_dispatch_gold[/code]
## per Victory Moment GDD §D.2. NOT serialized in to_dict — session-only
## context for the foreground victory celebration; offline replay uses
## the OfflineProgressionEngine's flushed aggregate gold delta instead
## (Return-to-App Screen #20 path).
##
## Sprint 15 S15-S4 (Victory Moment GDD #25 OQ-25-1 dependency).
var pre_dispatch_gold: int = 0


# ---------------------------------------------------------------------------
# Idempotency / per-dispatch flags (TR-orchestrator-005)
# ---------------------------------------------------------------------------

## Set EXPLICITLY by the Orchestrator at DISPATCHING when the formation lacks
## a tier-1 majority matchup advantage (per Combat GDD E.5). NOT re-derived
## from `hp_bonus_factor < 0.5` on load — the float-boundary flip at exactly
## 0.5 made the derived form non-deterministic across save/load (Save/Load
## Rule 14 + ADR-0014 §B4 resolution).
var losing_run: bool = false

## Per-dispatch idempotency gate for the once-only `floor_cleared_first_time`
## emission (AC-COMBAT-09b). Set true by the Orchestrator after the first
## valid first-clear emission per dispatch; reset only by `dispatch_pressed`
## starting a new dispatch.
var floor_clear_emitted: bool = false

## Story 011 (TR-orchestrator-031) — distinguishes ADR-0014's two failure modes
## when offline replay produces an empty `kill_schedule`:
##   - `true` (default): floor archetypes are valid; the empty kill_schedule
##     means the formation lost without producing any kills ("lost badly").
##   - `false`: floor authoring bug — the source Floor resource has missing
##     or invalid archetype data, so Combat had no enemies to schedule.
##     Set explicitly via [method DungeonRunOrchestrator.mark_floor_invalid_for_offline_replay]
##     (which also `push_error`s the authoring-bug diagnostic).
##
## Default is `true` because the typical case at dispatch time is a valid
## floor — only the explicit invalid-marking path flips this to `false`.
##
## Serialized in [method to_dict] / [method from_dict] so the Return-to-App
## Screen can render the distinction correctly across the persist boundary
## (a floor authoring bug detected during offline replay is still a bug
## after relaunch).
##
## TR-orchestrator-031, ADR-0014.
var floor_was_valid: bool = true


# ---------------------------------------------------------------------------
# Serialization (TR-orchestrator-003) — round-trip via to_dict / from_dict
# ---------------------------------------------------------------------------

## Returns a 9-key Dictionary representation of this snapshot for
## [SaveLoadSystem] persistence. Collection fields are duplicated so the
## returned dict can be mutated without touching live state.
##
## TR-orchestrator-003
func to_dict() -> Dictionary:
	return {
		"formation_snapshot": formation_snapshot.duplicate(true),
		"floor_id": floor_id,
		"current_tick": current_tick,
		"last_emitted_tick": last_emitted_tick,
		"losing_run": losing_run,
		"floor_clear_emitted": floor_clear_emitted,
		"matchup_cache": matchup_cache.duplicate(true),
		"kill_schedule": kill_schedule.duplicate(true),
		"loop_counter": loop_counter,
		"kill_count": kill_count,
		"floor_was_valid": floor_was_valid,
	}


## Hydrates this snapshot from a Dictionary produced by [method to_dict].
## Defensive defaults preserve invariants if the source dict is partial:
##   - missing collection keys produce empty containers
##   - missing scalars produce 0 / false / ""
##   - JSON round-trip floats coerced to ints via [code]int()[/code]
##
## NOTE: this method overwrites all fields. Callers that need to discard a
## hydrate failure (e.g., orphan-hero recovery per ADR-0014 §2.3) should
## construct a fresh RunSnapshot rather than reuse one in flight.
##
## TR-orchestrator-003
func from_dict(d: Dictionary) -> void:
	# Collections — duplicate the inputs so external mutations don't leak in.
	var fs_in: Variant = d.get("formation_snapshot", {})
	formation_snapshot = (fs_in as Dictionary).duplicate(true) if fs_in is Dictionary else {}

	var mc_in: Variant = d.get("matchup_cache", {})
	matchup_cache = (mc_in as Dictionary).duplicate(true) if mc_in is Dictionary else {}

	var ks_in: Variant = d.get("kill_schedule", [])
	kill_schedule = (ks_in as Array).duplicate(true) if ks_in is Array else []

	# Scalars — defensive int() coercion (JSON returns floats for whole numbers).
	floor_id = str(d.get("floor_id", ""))
	current_tick = int(d.get("current_tick", 0))
	last_emitted_tick = int(d.get("last_emitted_tick", 0))
	loop_counter = int(d.get("loop_counter", 0))
	kill_count = int(d.get("kill_count", 0))

	# Bools — explicit, never re-derived (ADR-0014 §B4).
	losing_run = bool(d.get("losing_run", false))
	floor_clear_emitted = bool(d.get("floor_clear_emitted", false))
	# Story 011 — default `true` if absent so legacy saves (pre-field) hydrate
	# as "valid floor" rather than spuriously claiming an authoring bug.
	floor_was_valid = bool(d.get("floor_was_valid", true))


## Returns true if [param other] has equal values for all 9 fields.
## Used for save round-trip parity tests; does NOT compare object identity.
##
## Collections compared via Dictionary `==` / Array `==` (deep equality).
##
## TR-orchestrator-003
func equals(other: RunSnapshot) -> bool:
	if other == null:
		return false
	return (
		formation_snapshot == other.formation_snapshot
		and floor_id == other.floor_id
		and current_tick == other.current_tick
		and last_emitted_tick == other.last_emitted_tick
		and losing_run == other.losing_run
		and floor_clear_emitted == other.floor_clear_emitted
		and matchup_cache == other.matchup_cache
		and kill_schedule == other.kill_schedule
		and loop_counter == other.loop_counter
		and kill_count == other.kill_count
		and floor_was_valid == other.floor_was_valid
	)
