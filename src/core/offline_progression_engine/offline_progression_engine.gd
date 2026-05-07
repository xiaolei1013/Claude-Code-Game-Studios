## OfflineProgressionEngine — Sprint 12 S12-M4 (Stories 1-3) implementation.
##
## Per design/gdd/offline-progression-engine.md §A: the boot-time orchestrator
## that drains the wall-clock delta accumulated while the player was away.
## Subscribes to [signal TickSystem.offline_elapsed_seconds], chunks the
## replay through Economy + DungeonRunOrchestrator's per-chunk APIs, yields
## to the main thread between chunks per ADR-0014's no-WorkerThreadPool
## mandate, and emits a single aggregate [signal offline_rewards_collected]
## at the end. The Return-to-App Screen is the lone subscriber.
##
## Sprint 12 S12-M4 scope (Stories 1-3): autoload skeleton + boot
## orchestration + OfflineSummary class. The actual chunked replay loop
## body is **stubbed** here — it currently produces an empty OfflineSummary
## without invoking Economy.compute_offline_batch / Orchestrator.compute_offline_batch.
## Sprint 12 S12-M5 (Stories 4-6) lands the real chunked loop + signal
## suppression + cap-handling per GDD §C.2 / §D.3 / §C.3 / §C.4.
##
## NOT in SaveLoadSystem.CONSUMER_PATHS per GDD §C.7 — engine has no
## persisted state of its own. Inputs come from other systems' save
## namespaces (TickSystem.offline_elapsed_seconds, RunSnapshot, etc.).
##
## class_name omitted to avoid the "Class hides an autoload singleton" parse
## error per the project_godot_autoload_class_name_collision memory note
## (matches FormationAssignment + AudioRouter + Recruitment pattern).
##
## Governing GDD: design/gdd/offline-progression-engine.md
## Governing ADRs: ADR-0014 (Offline Replay Batch Chunking + RunSnapshot
## Schema), ADR-0005 (TickSystem dual-clock contract), ADR-0013 (Economy
## compute_offline_batch + flush_offline_signals), ADR-0003 Amendment #8
## (rank 15 lockstep — Sprint 12 S12-M4).
extends Node


# ---------------------------------------------------------------------------
# Public types — OfflineSummary (passed to Return-to-App Screen)
# ---------------------------------------------------------------------------

## Aggregate result of an offline replay batch. Fields are additive over
## chunks; subscribers consume the whole struct, not per-chunk events.
##
## Per GDD §C.1: 7 fields locked. ADR-0014 forbidden pattern
## OFFLINE_SUMMARY_FIELD_SET_EXPANSION_WITHOUT_VERSION_BUMP — adding fields
## without a save-schema version bump is forbidden (the summary IS persisted
## briefly between replay-complete and Return-to-App-screen-acknowledge per
## OQ-OE-1; Sprint 13+ scope).
##
## V1.0 forward-compat field flagged in GDD §C.1 line 74:
##   var hero_levels_gained: Dictionary[int, int]  # hero_id → levels gained
class OfflineSummary extends RefCounted:
	## Sum of all credited gold (drip + kill + first-clear bonus).
	var gold_earned: int = 0
	## Floor indices first-cleared during the offline window (ADR-0002).
	var floors_cleared_in_window: Array[int] = []
	## min(elapsed, offline_cap_seconds); the actually-replayed window.
	var seconds_credited: int = 0
	## max(0, elapsed - offline_cap_seconds); 0 if under cap.
	var seconds_clipped: int = 0
	## Total sim-ticks consumed during replay.
	var ticks_replayed: int = 0
	## Total batch chunks consumed during replay (telemetry).
	var chunks_consumed: int = 0
	## Wall-clock duration of the replay loop (telemetry / AC-TICK-10).
	var total_replay_wall_time_ms: int = 0


# ---------------------------------------------------------------------------
# Tuning knobs (designer-overridable; ADR-0014 §adaptive time-budgeted chunking)
# ---------------------------------------------------------------------------

## Target wall-clock cost per chunk. Per ADR-0014: 12 ms is the headroom-
## bound for ANR-resilient mobile execution.
const OFFLINE_CHUNK_TARGET_WALL_MS: int = 12

## First chunk size on every replay. Per ADR-0014 §C.2.
const OFFLINE_CHUNK_INITIAL_TICKS: int = 5000

## Floor for adaptive chunk-size adjustment. Per ADR-0014.
const OFFLINE_CHUNK_MIN_TICKS: int = 500

## Ceiling for adaptive chunk-size adjustment. Per ADR-0014.
const OFFLINE_CHUNK_MAX_TICKS: int = 50000

## Deadband ratio (±25%) per ADR-0014 — within deadband, no adjustment.
const OFFLINE_CHUNK_DEADBAND_RATIO: float = 0.25

## Adjust ratio (0.6) per ADR-0014 — dampens oscillation across 2-3 chunks.
const OFFLINE_CHUNK_ADJUST_RATIO: float = 0.6

## Show cozy modal if replay exceeds this duration. Per GDD §C.5.
const PROGRESS_MODAL_THRESHOLD_MS: int = 100


# ---------------------------------------------------------------------------
# Signals — per offline-progression-engine.md §C.1
# ---------------------------------------------------------------------------

## Aggregate replay-complete signal. Fired ONCE per launch, AFTER all chunks
## have completed AND domain-signal aggregates (gold_changed, first_clear_*)
## have been emitted via Economy.flush_offline_signals + DungeonRunOrchestrator
## .flush_offline_signals. Return-to-App Screen subscribes here and renders
## the summary as the player's first interaction.
##
## Order of operations per GDD §C.1:
##   1. for chunk in chunks: process; suppress per-chunk domain signals.
##   2. After all chunks: emit aggregate domain signals via flush_offline_signals.
##   3. Emit THIS signal LAST.
signal offline_rewards_collected(summary: OfflineSummary)

## Cap-reached signal. Fired BEFORE [signal offline_rewards_collected] when
## offline_elapsed_seconds exceeds offline_cap_seconds. Subscribers (Return-
## to-App Screen, telemetry) use this to render the cozy "your guild was
## busy for X hours" register per GDD §B fantasy 3.
##
## [param seconds_clipped]: max(0, elapsed - cap). Always > 0 when this
##   signal fires (strict comparison; cap == elapsed does not emit).
signal cap_reached(seconds_clipped: int)


## Fires whenever [member _replay_in_flight] changes value. Payload is the
## new state. Subscribers (Guild Hall settings gear gating per Guild Hall
## GDD #19 §C.5, Settings overlay open-gating per Settings GDD #30 §E.6)
## use this to enable/disable interactive surfaces that should be unavailable
## while a replay is in progress.
##
## Emit pairs are exactly-once-per-replay:
##   - emits [code]true[/code] right after [member _replay_in_flight] is set
##     to true at the start of [method run_offline_replay]
##   - emits [code]false[/code] right after [member _replay_in_flight] is set
##     back to false (BEFORE the [signal offline_rewards_collected] emit, so
##     listeners that re-enable UI on replay-complete see the false state
##     before any rewards-handling logic that depends on UI state).
##
## Re-entrant calls to [method run_offline_replay] (rejected by the in-flight
## guard) do NOT emit a [code]true[/code] — only the FIRST replay invocation
## triggers the state-change signal.
##
## Surfaced by Sprint 13 Guild Hall GDD #19 OQ-19-1.
signal replay_in_flight_changed(in_flight: bool)


# ---------------------------------------------------------------------------
# Private state (visibility-sensitive; tests assert via stable field names)
# ---------------------------------------------------------------------------

## Set to true at run_offline_replay() entry; cleared at offline_rewards_collected
## emit. STABLE-FOR-TEST-ACCESS — tests assert this transitions true→false in
## lockstep with the signal.
var _replay_in_flight: bool = false

## Snapshot of pending elapsed seconds (set by the TickSystem signal handler
## before the replay loop begins). Cleared post-replay. STABLE-FOR-TEST-ACCESS.
var _pending_elapsed_seconds: int = 0

## Cached summary from the most recent completed replay. Written BEFORE
## offline_rewards_collected is emitted so late subscribers (e.g., the
## Return-to-App Screen, which is instantiated AFTER the signal fires) can
## read the summary via [method last_summary] in their on_enter() without
## needing to have been connected at emit time.
##
## Pattern: screen connects in on_enter, reads _last_summary immediately (late-
## subscriber path), AND stays connected for re-render if the signal fires while
## the screen is already alive (live-subscriber path). Both paths call the same
## _render_summary helper.
var _last_summary: OfflineSummary = null

## Test-injection DI for warning logs per FloorUnlock S11-X1's pattern.
var _warning_logger: Callable = func(msg: String) -> void: push_warning(msg)

## Test-injection DI for error logs per FloorUnlock S11-X1's pattern.
var _error_logger: Callable = func(msg: String) -> void: push_error(msg)


# ---------------------------------------------------------------------------
# Built-in lifecycle
# ---------------------------------------------------------------------------

func _init() -> void:
	# Zero-arg per ADR-0003 Amendment #3.
	pass


## Subscribes to TickSystem.offline_elapsed_seconds per GDD §F.signal-source-
## dependencies. Per ADR-0003 §Signal SUBSCRIPTION rule: rank 15 → rank 0
## subscription is safe at _ready() time (signal objects exist on Node
## instantiation, before any _ready() fires; [VERIFIED]).
func _ready() -> void:
	var tick_system: Node = get_node_or_null("/root/TickSystem")
	if tick_system != null and tick_system.has_signal("offline_elapsed_seconds"):
		if not tick_system.offline_elapsed_seconds.is_connected(_on_offline_elapsed_seconds):
			tick_system.offline_elapsed_seconds.connect(_on_offline_elapsed_seconds)
	else:
		# Defensive — test envs may boot without TickSystem. GDD §E.9
		# documents this as a packaging-bug surface, not a runtime concern.
		_warning_logger.call(
			"OfflineProgressionEngine._ready: /root/TickSystem absent or no offline_elapsed_seconds signal — boot subscription skipped"
		)


# ---------------------------------------------------------------------------
# Public API — minimal surface; engine is mostly signal-driven.
# ---------------------------------------------------------------------------

## Manual trigger for the replay loop. Production callers do NOT use this —
## the loop is auto-triggered by [method _on_offline_elapsed_seconds]. This
## method exists for QA / debug / test-fixture paths that need to drive a
## replay without going through TickSystem's bg/fg cycle.
##
## Idempotent: calling twice while a replay is in flight push_warns the
## second call and returns immediately (no parallel replays — ADR-0014
## single-replay-in-flight invariant).
##
## [param elapsed_seconds]: the wall-clock delta to replay. Capped to
##   offline_cap_seconds before chunking.
##
## Sprint 12 S12-M4 scope: this body is a STUB that emits cap_reached (if
## clipped) + offline_rewards_collected with an empty summary. Sprint 12
## S12-M5 lands the real chunked loop body per GDD §C.2 pseudocode.
func run_offline_replay(elapsed_seconds: int) -> void:
	if _replay_in_flight:
		_warning_logger.call(
			"OfflineProgressionEngine.run_offline_replay: replay already in flight (elapsed=%d ignored) — single-replay-in-flight invariant per ADR-0014"
			% elapsed_seconds
		)
		return

	if elapsed_seconds <= 0:
		# Cold launch / sub-second elapsed: GDD §E.1 documents no replay.
		# Emit nothing; return silently.
		return

	_replay_in_flight = true
	_pending_elapsed_seconds = elapsed_seconds
	# Notify state-change subscribers (Guild Hall + Settings overlay gating)
	# per Guild Hall GDD #19 OQ-19-1.
	replay_in_flight_changed.emit(true)

	# Cap clipping per GDD §D.2.
	var cap_seconds: int = _read_cap_seconds()
	var capped: int = mini(elapsed_seconds, cap_seconds)
	var clipped: int = maxi(0, elapsed_seconds - cap_seconds)
	if clipped > 0:
		cap_reached.emit(clipped)

	# Sprint 12 S12-M5: full chunked replay loop per GDD §C.2 + ADR-0014 §C.2.
	# Convert capped seconds to ticks (TickSystem.TICKS_PER_SECOND = 20 per game-time-and-tick.md).
	var ticks_per_second: int = 20
	var total_ticks: int = capped * ticks_per_second
	var remaining_ticks: int = total_ticks
	var current_chunk_size: int = OFFLINE_CHUNK_INITIAL_TICKS

	# Initialize summary accumulator.
	var summary: OfflineSummary = OfflineSummary.new()
	summary.seconds_credited = capped
	summary.seconds_clipped = clipped

	# Suppress per-chunk domain signals per ADR-0014 §C.3 + ADR-0013.
	var economy: Node = get_node_or_null("/root/Economy")
	var orchestrator: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if economy != null:
		economy._is_offline_replay = true
	if orchestrator != null:
		orchestrator._is_offline_replay = true

	# Batch chunking loop per GDD §C.2 pseudocode + ADR-0014 §C.2.
	var replay_start_ms: int = Time.get_ticks_msec()
	while remaining_ticks > 0:
		var chunk_ticks: int = mini(current_chunk_size, remaining_ticks)
		var chunk_start_ms: int = Time.get_ticks_msec()

		# Domain calls: Orchestrator first (combat kills), then Economy (drip accrual).
		# Per ADR-0014: order is load-bearing for accumulation semantics.
		# Note: combat_result/economy_result locals removed (were assigned but
		# never read — the if-branches consume `result` directly via has()/has_method()
		# checks). If a future iteration needs to thread the per-chunk result into
		# a cross-system summary, reintroduce the locals at that time.
		if orchestrator != null and orchestrator.has_method("compute_offline_batch"):
			var result = orchestrator.compute_offline_batch(chunk_ticks)
			if result != null:
				# Accumulate kills by tier (population is lazy; defaults to 0).
				if result.has("kills_by_tier") and result.kills_by_tier is Dictionary:
					for tier: int in result.kills_by_tier.keys():
						if not summary.has_meta("_kills_by_tier"):
							summary.set_meta("_kills_by_tier", {})
						var tier_dict: Dictionary = summary.get_meta("_kills_by_tier")
						tier_dict[tier] = tier_dict.get(tier, 0) + result.kills_by_tier[tier]
				# Track first_clear_tick to populate floors_cleared_in_window post-replay.
				if result.has("first_clear_tick") and result.first_clear_tick >= 0:
					if not summary.has_meta("_floors_cleared_ticks"):
						summary.set_meta("_floors_cleared_ticks", [])
					var cleared_list: Array = summary.get_meta("_floors_cleared_ticks")
					if result.first_clear_tick not in cleared_list:
						cleared_list.append(result.first_clear_tick)

		if economy != null and economy.has_method("compute_offline_batch"):
			var _result = economy.compute_offline_batch(chunk_ticks)
			# Stub for Story 010 — economy.compute_offline_batch returns null;
			# when implemented, the result will populate gold drip accumulators
			# on `summary` here (mirroring the orchestrator branch above).

		summary.ticks_replayed += chunk_ticks
		summary.chunks_consumed += 1
		remaining_ticks -= chunk_ticks

		# Measure wall time for this chunk (measuring yield is non-blocking per async pattern).
		var chunk_wall_ms: int = Time.get_ticks_msec() - chunk_start_ms

		# Yield to main thread per ADR-0014: yield IS the budget mechanism (no WorkerThreadPool).
		await get_tree().process_frame

		# Adaptive chunk-size adjustment per ADR-0014 §D.3 + GDD §D.3.
		var deadband_low: float = OFFLINE_CHUNK_TARGET_WALL_MS * (1.0 - OFFLINE_CHUNK_DEADBAND_RATIO)
		var deadband_high: float = OFFLINE_CHUNK_TARGET_WALL_MS * (1.0 + OFFLINE_CHUNK_DEADBAND_RATIO)
		if chunk_wall_ms < deadband_low or chunk_wall_ms > deadband_high:
			# Outside deadband: adjust chunk size toward target.
			var ratio: float = float(OFFLINE_CHUNK_TARGET_WALL_MS) / float(maxi(chunk_wall_ms, 1))
			var adjusted: int = int(current_chunk_size * lerpf(1.0, ratio, OFFLINE_CHUNK_ADJUST_RATIO))
			current_chunk_size = clampi(adjusted, OFFLINE_CHUNK_MIN_TICKS, OFFLINE_CHUNK_MAX_TICKS)

	summary.total_replay_wall_time_ms = Time.get_ticks_msec() - replay_start_ms

	# Clear suppression flags BEFORE flush (defensive re-init; flush also clears).
	if economy != null:
		economy._is_offline_replay = false
	if orchestrator != null:
		orchestrator._is_offline_replay = false

	# Emit aggregate domain signals per ADR-0014 §C.3 post-replay order.
	# Order: Economy aggregates, then Orchestrator aggregates, then this engine's signal.
	if economy != null and economy.has_method("flush_offline_signals"):
		economy.flush_offline_signals()
	if orchestrator != null and orchestrator.has_method("flush_offline_signals"):
		orchestrator.flush_offline_signals()

	# Cache summary BEFORE emitting so late subscribers (Return-to-App Screen)
	# can read it via last_summary() in on_enter() even if the signal already
	# fired before the screen was instantiated. See _last_summary doc comment.
	_last_summary = summary

	# Clear in-flight state BEFORE emitting (per GDD §E.6: a listener
	# exception must not leave _replay_in_flight stuck true).
	_replay_in_flight = false
	_pending_elapsed_seconds = 0
	# Notify state-change subscribers BEFORE the rewards emit so listeners
	# that re-enable UI on replay-complete (Guild Hall settings gear,
	# Settings overlay open-gating) see the false state before any
	# rewards-handling logic fires per Guild Hall GDD #19 OQ-19-1.
	replay_in_flight_changed.emit(false)

	offline_rewards_collected.emit(summary)

	# Route to Return-to-App Screen if real seconds were credited (Story 9 autoload
	# hook — closes the loop: replay complete → summary cached → screen routed →
	# on_enter reads cached summary). Guard with has_node + has_method for test-env
	# safety. The MainRoot guard is load-bearing: SceneManager.request_screen
	# transitively asserts on /root/MainRoot existing (per scene_manager.gd:1212).
	# Test envs that drive run_offline_replay without authoring a MainRoot would
	# crash here without this guard.
	if summary.seconds_credited > 0:
		var scene_manager: Node = get_node_or_null("/root/SceneManager")
		var main_root: Node = get_node_or_null("/root/MainRoot")
		if scene_manager != null and main_root != null and scene_manager.has_method("request_screen"):
			scene_manager.request_screen(
				"return_to_app", SceneManager.TransitionType.SLIDE_DOWN
			)


## Returns true if a replay is currently in flight. The Return-to-App Screen
## + the cozy progress modal use this to gate their own state machines.
## Foreground transitions (e.g., player tapping a button mid-replay) are
## blocked by SceneManager via this flag.
func is_replay_in_flight() -> bool:
	return _replay_in_flight


## Returns the most recently completed [OfflineSummary], or null if no replay
## has ever completed in this session.
##
## Intended for the **late-subscriber pattern**: the Return-to-App Screen may
## be instantiated AFTER [signal offline_rewards_collected] has already emitted
## (e.g., when SceneManager finishes a SLIDE_DOWN transition into the screen
## after the replay completes). The screen calls this getter in [method on_enter]
## to render the cached summary immediately, without needing to have been
## connected at emit time.
##
## Null handling: callers MUST check for null. Return null = no replay has run
## this session (cold launch, or screen shown via debug navigation).
func last_summary() -> OfflineSummary:
	return _last_summary


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Boot-time signal handler per GDD §F.signal-source-dependencies. Routes
## the TickSystem-emitted elapsed delta into [method run_offline_replay].
##
## [param seconds]: wall-clock delta in seconds (float). Truncated to int
##   before passing to run_offline_replay.
## [param _cap_reached]: true if TickSystem internally clipped to cap_seconds.
##   This engine ALSO performs cap clipping to be defensive (GDD §D.2);
##   double-clipping is idempotent (mini of already-capped is the cap).
func _on_offline_elapsed_seconds(seconds: float, _cap_reached: bool) -> void:
	run_offline_replay(int(seconds))


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Reads offline_cap_seconds from TickSystem per GDD §C.4 + §F. Falls back
## to the GDD default (28800 = 8h) if TickSystem is absent (test envs).
func _read_cap_seconds() -> int:
	var tick_system: Node = get_node_or_null("/root/TickSystem")
	if tick_system != null and "offline_cap_seconds" in tick_system:
		return int(tick_system.get("offline_cap_seconds"))
	# GDD-documented default. Tests that need a different cap inject via
	# the live tick_system.offline_cap_seconds field.
	return 28800
