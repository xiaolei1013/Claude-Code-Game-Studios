extends Node

## TickSystem — rank-0 Foundation autoload.
##
## NOTE: No `class_name` — autoload scripts cannot declare `class_name`
## when the autoload name matches the class, or Godot raises
## "Class X hides an autoload singleton". The autoload is globally
## accessible as `TickSystem`; tests that need a fresh instance use
## `preload("res://src/core/tick_system/tick_system.gd").new()`.
##
## Owns the dual-clock contract (Wall Clock + Sim Clock) for Lantern Guild.
## Skeleton: signal declarations and public API stubs only.
## Bodies are filled in by neighbouring stories (002, 004, 008).
##
## ADR-0005: Time System Dual-Clock Contract
## ADR-0003: Autoload Rank Table (rank 0; zero-arg _init invariant)
##
## ---------------------------------------------------------------------------
## CI GREP INVARIANTS (Story 003 — TR-time-002, TR-time-006, TR-time-021)
## ---------------------------------------------------------------------------
## INV-1 (TR-time-002 / TR-time-021): Single call site for wall-clock reads.
##   grep -rn "Time.get_unix_time_from_system" src/
##   MUST return exactly ONE hit, inside _read_wall_clock_unix_time() in this
##   file.  Any match elsewhere in src/ is a BLOCKING regression per ADR-0005.
##
## INV-2 (TR-time-006): _process(delta) forbidden as economy input.
##   delta MUST only feed _tick_accumulator_seconds in this file.
##   It must never be multiplied into or passed to any economy / currency /
##   loot / run-outcome formula anywhere in src/.
##   grep for "delta *" or "delta +" outside TickSystem's accumulator line is
##   a BLOCKING regression.  Animation/interpolation uses in UI files are OK.
## ---------------------------------------------------------------------------
##
## ---------------------------------------------------------------------------
## ENGINE COMPATIBILITY NOTE (Story 004 — TR-time-015)
## ---------------------------------------------------------------------------
## NOTIFICATION_APPLICATION_PAUSED and NOTIFICATION_APPLICATION_RESUMED are
## used for mobile BG/FG handling.  The engine-reference docs for Godot 4.6
## in docs/engine-reference/godot/ do NOT explicitly confirm these constant
## names/values (they were absent from all module reference files at the time
## of Story 004 implementation).  The names used here match ADR-0005 and the
## Godot 4.x Object class as known at training-data cutoff.
## ACTION REQUIRED before MVP ship: run the engine-probe test in
## tests/probes/ (or add one) to confirm:
##   NOTIFICATION_APPLICATION_PAUSED == 2201
##   NOTIFICATION_APPLICATION_RESUMED == 2202
## on each target platform (Android, iOS).  Desktop constants
## NOTIFICATION_WM_WINDOW_FOCUS_OUT/IN and NOTIFICATION_WM_CLOSE_REQUEST
## are pre-cutoff stable and considered verified.
## ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## Platform application lifecycle state.
##
## FOREGROUND: The app is in the foreground and ticks are emitted normally.
## BACKGROUNDED: The app has been backgrounded (mobile: NOTIFICATION_APPLICATION_PAUSED;
##   desktop: NOTIFICATION_WM_WINDOW_FOCUS_OUT). Tick emission is frozen;
##   the accumulator residual is preserved for seamless resumption.
##
## TR-time-008, TR-time-015 — ADR-0005
enum AppState { FOREGROUND, BACKGROUNDED }

# ---------------------------------------------------------------------------
# Constants (architectural — NOT tuning knobs, NOT @export)
# ---------------------------------------------------------------------------

## Sim-clock frequency: 20 ticks per second (architectural constant per ADR-0005).
## Do NOT change without a superseding ADR — this value is wired into save
## schemas and offline-replay math across multiple systems.
const TICKS_PER_SECOND: int = 20

## Derived interval in seconds; stored to avoid repeated division in hot paths.
const _TICK_INTERVAL_SECONDS: float = 1.0 / TICKS_PER_SECOND

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted once per sim-clock tick (20 Hz). Carries the monotonic tick counter.
signal tick_fired(tick_number: int)

## Emitted on session resume after the platform was backgrounded or the game
## was closed. [param seconds] is the wall-clock delta; [param cap_reached]
## is true when the delta exceeded offline_cap_seconds.
@warning_ignore("unused_signal")
signal offline_elapsed_seconds(seconds: float, cap_reached: bool)

## Emitted when the wall-clock timestamp rewinds beyond rewind_tolerance_seconds,
## indicating a suspicious system-clock adjustment.
@warning_ignore("unused_signal")
signal flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)

# ---------------------------------------------------------------------------
# Export tuning knobs (designer-configurable defaults; override in .tscn or
# project autoload resource if the editor exposes them)
# ---------------------------------------------------------------------------

## Maximum offline time credited to the player, in seconds (default 8 hours).
@export var offline_cap_seconds: int = 28_800

## Tolerance for backward clock jumps before flagging as suspicious, in seconds.
@export var rewind_tolerance_seconds: int = 300

## Interval at which the session high-water timestamp is persisted, in seconds.
@export var heartbeat_interval_seconds: int = 60

# ---------------------------------------------------------------------------
# Private state (session-scoped; NOT persistent — TR-time-004)
# ---------------------------------------------------------------------------

## Fractional-second accumulator for the sim clock.
## Preserved across pause (never reset to 0 on unpause — TR-time-010 / ADR-0005).
## The _notification handler MUST NOT touch this value on BG entry.
var _tick_accumulator_seconds: float = 0.0

## Heartbeat-second accumulator (separate from the tick accumulator). Advances
## even when the UI is paused (TR-time-034); only gates on backgrounded state.
## When it reaches [member heartbeat_interval_seconds], a heartbeat persist is
## fired via [code]SaveLoadSystem.request_heartbeat_persist[/code] and the
## accumulator is decremented by the interval (preserving any sub-interval
## residual for the next firing).
##
## Sprint 11 S11-M2a — Story 011. Companion SaveLoadSystem.request_heartbeat_persist
## body is deferred to Story 011 SaveLoadSystem-side (S11-M2b) alongside Story 007
## (request_full_persist body); both share underlying envelope I/O machinery.
var _heartbeat_accumulator_seconds: float = 0.0

## Monotonic sim-clock tick counter. Starts at 0 on every cold launch.
## Incremented before each tick_fired emission — first emission carries tick 1.
## Never decreases while the app is alive (TR-time-007).
var _sim_tick_counter: int = 0

## Last wall-clock Unix timestamp (seconds) read by _read_wall_clock_unix_time().
## Starts at 0 — meaning "wall clock has not yet been read this session".
## now_ms() derives its value from this cache; it NEVER calls
## Time.get_unix_time_from_system() directly (single-call-site invariant,
## ADR-0005 / TR-time-021).
var _last_wall_ts: int = 0

## Current platform lifecycle state. FOREGROUND on cold launch.
## Changed by _on_backgrounded() and _on_foregrounded() via _notification().
## TR-time-008, TR-time-015 — ADR-0005
var _app_state: AppState = AppState.FOREGROUND

## UI-pause substate. When true, tick emission is suppressed while _app_state
## remains FOREGROUND (heartbeat accumulator continues in Story 008).
## Set via set_ui_paused(). TR-time-034 — ADR-0005
var _ui_paused: bool = false

## Last persisted wall-clock Unix timestamp (seconds), written on BG entry.
## SaveLoadSystem (Story 008) reads this via get_last_persist_ts() on heartbeat.
## ADR-0005: only SaveLoadSystem and _on_backgrounded() may write this value.
var _last_persist_unix: int = 0

## Session high-water wall-clock timestamp (seconds).
## Monotonically non-decreasing: updated to max(prev, now) on each BG entry.
## SaveLoadSystem (Story 008) reads this via get_session_high_water().
## ADR-0005: only SaveLoadSystem and _on_backgrounded() may write this value.
var _session_high_water: int = 0

## Story 007 — session-scoped suspicious-timestamp flag (TR-time-018, TR-time-019).
##
## Set to [code]true[/code] exactly once per launch on the [b]first[/b] D.2
## rewind-branch detection (`elapsed_raw < -REWIND_TOLERANCE_SECONDS`). Once
## true, additional D.2 invocations that re-enter the rewind branch DO NOT
## re-emit [signal flag_suspicious_timestamp_emitted] — the once-per-launch
## invariant. Resets to [code]false[/code] only on cold-launch (process restart;
## the field is not persisted). NOT included in [member get_save_data].
##
## Distinct from [member _meta.tamper_suspicious_count] in SaveLoadSystem
## (which IS persisted) — this flag is purely session-scoped.
var _flag_suspicious_timestamp: bool = false

## Story 005 — process-scoped one-shot flag (TR-time-016) preventing multiple
## offline-replay emissions per launch.
##
## Set to [code]true[/code] on the first call to [method bootstrap_offline_replay].
## Subsequent calls (e.g. on BG↔FG cycles within the same process) are no-ops.
## Resets only on process restart — NOT on save/load, NOT on FG re-entry.
var _offline_replay_emitted: bool = false

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

## Zero-arg _init required by ADR-0003 Amendment #3:
## Godot autoload Nodes cannot receive constructor arguments.
func _init() -> void:
	pass

## Routes Godot platform lifecycle and window notifications to the appropriate
## internal handlers.
##
## Mobile BG/FG: [constant NOTIFICATION_APPLICATION_PAUSED] /
##   [constant NOTIFICATION_APPLICATION_RESUMED].
## Desktop BG/FG: [constant NOTIFICATION_WM_WINDOW_FOCUS_OUT] /
##   [constant NOTIFICATION_WM_WINDOW_FOCUS_IN].
## Graceful exit: [constant NOTIFICATION_WM_CLOSE_REQUEST] (Story 008 wires persist).
##
## TR-time-015 — ADR-0005 §"Platform-specific notification mapping"
##
## Engine compatibility note: NOTIFICATION_APPLICATION_PAUSED/RESUMED names and
## values should be verified via engine probe before MVP ship on mobile targets.
## See ENGINE COMPATIBILITY NOTE in the file header.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_on_backgrounded()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_on_foregrounded()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_on_graceful_exit()

## Advances the sim clock by [param delta] seconds using the integer-accumulator
## pattern from ADR-0005 §"Simulation Clock".
##
## Each time the accumulator crosses _TICK_INTERVAL_SECONDS (0.05 s), one tick
## is consumed, the counter is incremented, and tick_fired is emitted
## SYNCHRONOUSLY — never via call_deferred, never via Timer (ADR-0005).
##
## Pause-at-source: if the app is BACKGROUNDED or UI-paused, returns immediately
## WITHOUT touching _tick_accumulator_seconds. This preserves the fractional
## residual across the entire pause window (TR-time-009, TR-time-010, ADR-0005).
##
## Example:
##   tick_system._process(0.1)  # emits tick_fired(1) then tick_fired(2)
func _process(delta: float) -> void:
	# Background gate: in BG, neither tick nor heartbeat advances.
	if _app_state != AppState.FOREGROUND:
		return

	# Heartbeat advances even under UI pause (TR-time-034 + Story 011 S11-M2a).
	# Closes the prior TODO that called for splitting the UI-pause early-return.
	# Heartbeat continues so save persistence does not stall while a modal is open.
	_heartbeat_accumulator_seconds += delta
	if _heartbeat_accumulator_seconds >= float(heartbeat_interval_seconds):
		# Decrement (don't reset to 0) — preserves sub-interval residual so the
		# average firing rate matches heartbeat_interval_seconds exactly.
		_heartbeat_accumulator_seconds -= float(heartbeat_interval_seconds)
		_fire_heartbeat()

	# Tick emission suppressed by UI pause (TR-time-034 — original contract).
	if _ui_paused:
		return
	_tick_accumulator_seconds += delta
	while _tick_accumulator_seconds >= _TICK_INTERVAL_SECONDS:
		_tick_accumulator_seconds -= _TICK_INTERVAL_SECONDS
		_sim_tick_counter += 1
		tick_fired.emit(_sim_tick_counter)  # synchronous — NEVER call_deferred

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the current wall-clock time as a Unix timestamp in milliseconds.
##
## Derives its value from the cached [member _last_wall_ts] field, which is
## populated by [method _read_wall_clock_unix_time].  This method NEVER calls
## [code]Time.get_unix_time_from_system()[/code] directly — preserving the
## single-call-site invariant (ADR-0005 / TR-time-021).
##
## Returns 0 if [method _read_wall_clock_unix_time] has not yet been called
## this session (cold-start state).  Production callers will have triggered a
## wall-clock read before invoking now_ms() via the heartbeat or bootstrap
## paths added in later stories.
##
## Example:
##   tick_system._read_wall_clock_unix_time()
##   var ms: int = tick_system.now_ms()  # e.g. 1_714_000_000_000
func now_ms() -> int:
	return _last_wall_ts * 1000

## Returns the current monotonic sim-clock tick counter (TR-time-007).
## Returns 0 before any _process call; increments by 1 each tick thereafter.
func current_tick() -> int:
	return _sim_tick_counter

## Returns the last persisted Unix timestamp (seconds).
##
## Written by [method _on_backgrounded] on BG entry with the current wall-clock
## time.  SaveLoadSystem (Story 008) reads this on each heartbeat to persist
## state to disk.  Only [method _on_backgrounded] and SaveLoadSystem (via
## [method set_last_persist_ts]) may write this value — ADR-0005.
##
## Returns 0 until the first BG event or until SaveLoadSystem writes via
## [method set_last_persist_ts] (cold-start state).
##
## Example:
##   var ts_seconds: int = tick_system.get_last_persist_ts()
func get_last_persist_ts() -> int:
	return _last_persist_unix

## Returns the session high-water wall-clock timestamp (seconds).
##
## Monotonically non-decreasing: updated to [code]max(prev, now)[/code] on each
## BG entry.  SaveLoadSystem (Story 008) reads this on heartbeat.
## Only [method _on_backgrounded] and SaveLoadSystem (via
## [method set_session_high_water]) may write this value — ADR-0005.
##
## Returns 0 on cold start (before first BG event or SaveLoadSystem write).
##
## Example:
##   var hwm: int = tick_system.get_session_high_water()
func get_session_high_water() -> int:
	return _session_high_water

## Records the last persisted Unix timestamp (seconds).
##
## CALLER RESTRICTION: only SaveLoadSystem may call this method — ADR-0005.
## Story 008 wires SaveLoadSystem to call this on heartbeat after persisting
## to disk so TickSystem always holds the most-recently-confirmed save time.
##
## Example:
##   tick_system.set_last_persist_ts(Time.get_unix_time_from_system() as int)
func set_last_persist_ts(ts: int) -> void:
	_last_persist_unix = ts

## Records the session high-water wall-clock timestamp (seconds).
##
## CALLER RESTRICTION: only SaveLoadSystem may call this method — ADR-0005.
## Story 008 wires SaveLoadSystem to call this after a successful persist.
## Callers are responsible for passing a max-preserving value if desired;
## TickSystem applies no max() logic here — that logic lives in _on_backgrounded.
##
## Example:
##   tick_system.set_session_high_water(max(prev_hwm, current_ts))
func set_session_high_water(ts: int) -> void:
	_session_high_water = ts

## Fires a heartbeat persist request via [code]SaveLoadSystem.request_heartbeat_persist[/code].
##
## Called by [method _process] when the heartbeat accumulator reaches
## [member heartbeat_interval_seconds]. Resolves the SaveLoadSystem autoload
## defensively (test envs may not register it; cold-launch ordering is rank-2
## so it's normally present by the time _process runs).
##
## Reads the wall clock once before packaging the time_fields payload, per the
## ADR-0005 single-call-site invariant for [method _read_wall_clock_unix_time].
##
## Payload schema per Save/Load GDD §Heartbeat contract:
##   - [code]last_ts_ms[/code]: current wall clock as milliseconds since epoch
##   - [code]session_high_water[/code]: monotonically non-decreasing high-water
##     mark used by the rewind-detection path
##
## Sprint 11 S11-M2a — Story 011 (TickSystem-side). The companion
## [code]SaveLoadSystem.request_heartbeat_persist[/code] body is deferred to
## Story 011 SaveLoadSystem-side (S11-M2b) alongside Story 007. In the
## meantime, the call returns immediately (stub body=pass); heartbeat firing
## is exercised structurally without persisting to disk.
func _fire_heartbeat() -> void:
	# Refresh wall clock cache before packaging the payload — single-call-site
	# invariant per ADR-0005.
	_read_wall_clock_unix_time()
	var save_system: Node = (
		get_node_or_null("/root/SaveLoadSystem") if get_tree() != null else null
	)
	if save_system == null:
		# Test-env path: SaveLoadSystem autoload absent. The accumulator still
		# advances + decrements correctly; persistence is a no-op until the
		# autoload is wired (Story 011 SaveLoadSystem-side / S11-M2b).
		return
	if not save_system.has_method("request_heartbeat_persist"):
		push_warning(
			"[TickSystem] /root/SaveLoadSystem has no request_heartbeat_persist " +
			"method; heartbeat fire skipped. Sprint 11 S11-M2b implements the body."
		)
		return
	save_system.request_heartbeat_persist({
		"last_ts_ms": now_ms(),
		"session_high_water": get_session_high_water(),
	})


## Suppresses tick emission while keeping [member _app_state] as FOREGROUND.
##
## When [param paused] is [code]true[/code], [method _process] returns before
## advancing the accumulator, halting tick emission without changing lifecycle
## state.  When [param paused] is [code]false[/code], tick emission resumes
## from the preserved accumulator residual (TR-time-010).
##
## RESOLVED (Sprint 11 S11-M2a, 2026-05-05): the heartbeat accumulator now
## advances independently of UI pause; only tick emission is suppressed when
## [member _ui_paused] is true. See [method _process] for the restructured
## flow and [member _heartbeat_accumulator_seconds] for the heartbeat-side state.
##
## TR-time-034 — ADR-0005
##
## Example:
##   tick_system.set_ui_paused(true)   # open settings screen
##   tick_system.set_ui_paused(false)  # close settings screen
func set_ui_paused(paused: bool) -> void:
	_ui_paused = paused

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

## Transitions to BACKGROUNDED state; freezes tick emission; writes persist timestamps.
##
## Idempotent: if already BACKGROUNDED, returns immediately without side effects.
## Called by [method _notification] on both mobile
## ([constant NOTIFICATION_APPLICATION_PAUSED]) and desktop
## ([constant NOTIFICATION_WM_WINDOW_FOCUS_OUT]) triggers — ADR-0005.
##
## State changes performed:
## - [member _app_state] → BACKGROUNDED (causes [method _process] early-return)
## - [member _last_persist_unix] ← current wall-clock time (seconds)
## - [member _session_high_water] ← max(prev, now) — monotonically non-decreasing
##
## IMPORTANT: [member _tick_accumulator_seconds] is NOT touched here.
## Preserving the residual is the core of TR-time-010 / ADR-0005 Consequence Row 4.
## SaveLoadSystem (Story 008) will consume _last_persist_unix on the next heartbeat.
##
## TR-time-008, TR-time-009, TR-time-010, AC-TICK-04 — ADR-0005
func _on_backgrounded() -> void:
	# Idempotent: already backgrounded — no-op prevents double-persist.
	if _app_state == AppState.BACKGROUNDED:
		return
	_app_state = AppState.BACKGROUNDED
	# Write persist timestamps using the single-call-site wall-clock routing (S1-S1).
	# NOTE: SaveLoadSystem integration (Story 008) will read these on heartbeat.
	var now: int = _read_wall_clock_unix_time()
	_last_persist_unix = now
	_session_high_water = max(_session_high_water, now)

## Transitions back to FOREGROUND state; resumes tick emission from preserved residual.
##
## Idempotent: if already FOREGROUND, returns immediately without side effects.
## Called by [method _notification] on both mobile
## ([constant NOTIFICATION_APPLICATION_RESUMED]) and desktop
## ([constant NOTIFICATION_WM_WINDOW_FOCUS_IN]) triggers — ADR-0005.
##
## IMPORTANT: Does NOT emit [signal offline_elapsed_seconds] — that signal is
## cold-launch-only and is handled by Story 005.  The accumulator residual is
## unchanged; [method _process] resumes advancing it on the next frame naturally.
##
## TR-time-008, TR-time-010, AC-TICK-04 — ADR-0005
func _on_foregrounded() -> void:
	# Idempotent: already in foreground — no-op.
	if _app_state == AppState.FOREGROUND:
		return
	_app_state = AppState.FOREGROUND
	# Do NOT recompute offline elapsed — that is cold-launch-only (Story 005).
	# Do NOT reset _tick_accumulator_seconds — preserving the residual is TR-time-010.

## Story 005 / 006 / 007 — unified entry point for offline-replay bootstrap.
##
## Called once per process by an external orchestrator (production: MainRoot
## boot sequence, after SaveLoadSystem.request_full_load completes; tests:
## directly). Process-scoped one-shot via [member _offline_replay_emitted] —
## subsequent calls within the same process are no-ops (TR-time-016).
##
## Branches:
##   - First-launch (no save loaded; [member _last_persist_unix] == 0 AND
##     [member _session_high_water] == 0): seed both timestamps to current
##     wall clock; emit [signal offline_elapsed_seconds]([code]0.0, false[/code])
##     for OfflineProgressionEngine's zero-tick-budget path. Per AC-TICK-07 +
##     TR-time-030.
##   - Returning-launch (one or both timestamps non-zero from SaveLoadSystem
##     hydration): runs Formula D.2 via [method _compute_offline_elapsed].
##
## Per AC-TICK-13 + TR-time-016: BG↔FG cycles within the same process MUST NOT
## re-fire the offline_elapsed_seconds signal. Only [method _on_backgrounded]
## continues to update persist timestamps; this method's one-shot flag prevents
## the replay path from re-running.
##
## ADR-0005 §"Cold-launch offline-replay path".
func bootstrap_offline_replay() -> void:
	if _offline_replay_emitted:
		return  # process-scoped one-shot — TR-time-016
	_offline_replay_emitted = true
	# Refresh wall-clock cache before any branch — single call site invariant
	# (ADR-0005 / TR-time-021).
	_read_wall_clock_unix_time()
	if _last_persist_unix == 0 and _session_high_water == 0:
		# First-launch path (AC-TICK-07 / TR-time-030): seed timestamps to
		# t_current so the next BG entry's max-preserving write doesn't see a
		# zero session_high_water and produce a phantom forward jump.
		_last_persist_unix = _last_wall_ts
		_session_high_water = _last_wall_ts
		offline_elapsed_seconds.emit(0.0, false)
		return
	# Returning-launch path (Stories 006 + 007): Formula D.2.
	_compute_offline_elapsed()


## Story 006 — Formula D.2 implementation: offline elapsed + forward clamp +
## rewind tolerance + int64 overflow safety.
##
## Sequence (per ADR-0005 §"Formula D.2" + GDD §D.2):
##   1. anchor = max(_last_persist_unix, _session_high_water) — TR-time-023.
##   2. elapsed_raw = t_current − anchor — int64 subtraction, mantissa-safe
##      since GDScript int IS int64 and Unix ts < 2^53.
##   3. Rewind branch FIRST — elapsed_raw < -REWIND_TOLERANCE_SECONDS:
##        - elapsed_offline_seconds = 0.0; cap_reached = false; budget = 0.
##        - Story 007: set [member _flag_suspicious_timestamp] = true on the
##          first false→true transition; emit
##          [signal flag_suspicious_timestamp_emitted](anchor, t_current); log
##          the literal-prefix warning. Subsequent rewind-branch hits with the
##          flag already true do NOT re-emit (TR-time-018 once-per-launch).
##   4. Accept branch — elapsed_raw >= -REWIND_TOLERANCE_SECONDS:
##        - clamped = clamp(elapsed_raw, 0, offline_cap_seconds) — TR-time-025.
##        - cap_reached = elapsed_raw > offline_cap_seconds.
##        - elapsed_offline_seconds = float(clamped).
##        - offline_tick_budget computed via the multiply form (TR-time-026):
##          [code]int(elapsed_offline_seconds × TICKS_PER_SECOND)[/code], NOT
##          divide form (0.05 is not exactly representable in IEEE-754).
##   5. Emit [signal offline_elapsed_seconds] with the computed values.
##
## Int64 overflow safety (TR-time-035 / AC-TICK-06): elapsed_raw is computed
## via direct int subtraction in GDScript int64 space — no float widening. For
## D = INT64_MAX − T, elapsed_raw remains positive int64; the subsequent clamp
## to offline_cap_seconds keeps the float multiplication well under 2^53.
##
## Idempotency: this method is called by [method bootstrap_offline_replay]
## under the one-shot guard. Direct calls in tests bypass that guard but the
## flag transition still respects the once-per-launch invariant on its own.
##
## TR-time-022..027 / TR-time-035 / AC-TICK-02 / AC-TICK-03 / AC-TICK-05 /
## AC-TICK-06 / AC-TICK-12 / AC-TICK-13 — ADR-0005.
func _compute_offline_elapsed() -> void:
	var anchor: int = max(_last_persist_unix, _session_high_water)
	var t_current: int = _last_wall_ts  # populated by _read_wall_clock_unix_time
	# int64 subtraction — GDScript int is int64; mantissa-safe at Unix ts scale.
	var elapsed_raw: int = t_current - anchor

	# Rewind branch FIRST (per ADR-0005 §D.2 ordering).
	if elapsed_raw < -rewind_tolerance_seconds:
		# Story 007 — once-per-launch flag transition + signal + log.
		if not _flag_suspicious_timestamp:
			_flag_suspicious_timestamp = true
			# Log format MUST match TR-time-036 literal prefix exactly.
			push_warning(
				"[TickSystem] Clock rewind detected: delta=%d" % elapsed_raw
			)
			flag_suspicious_timestamp_emitted.emit(anchor, t_current)
		# Per ADR-0005: rewind branch yields zero offline credit, no cap reached.
		offline_elapsed_seconds.emit(0.0, false)
		return

	# Accept branch — clamp to [0, offline_cap_seconds].
	var clamped: int = clampi(elapsed_raw, 0, offline_cap_seconds)
	var cap_reached: bool = elapsed_raw > offline_cap_seconds
	var elapsed_offline: float = float(clamped)
	# Multiply form (TR-time-026) — NOT divide form.
	# offline_tick_budget is implicit in the receiver; emitting both here.
	offline_elapsed_seconds.emit(elapsed_offline, cap_reached)


## Stub for the graceful-exit path triggered by [constant NOTIFICATION_WM_CLOSE_REQUEST].
##
## Story 008 wires the full-state persist here (SaveLoadSystem.request_graceful_exit_persist).
## Until then this is intentionally empty — we do not want to call SaveLoadSystem prematurely.
##
## ADR-0005 §"Platform-specific notification mapping"
func _on_graceful_exit() -> void:
	# Stub — Story 008 wires the full-state persist here.
	pass

## SINGLE PROJECT-WIDE CALL SITE for [code]Time.get_unix_time_from_system()[/code].
##
## All internal code paths that need the current wall-clock time MUST go
## through this function.  Direct calls to Time.get_unix_time_from_system()
## anywhere else in src/ are a BLOCKING regression per ADR-0005 (see CI grep
## invariant INV-1 at the top of this file).
##
## Design notes:
## - Returns [code]int(Time.get_unix_time_from_system())[/code].  We use
##   [code]int()[/code] NOT [code]floori()[/code] because in GDScript 4.x
##   [code]floori()[/code] returns a float despite its name (ADR-0005 Decision
##   §"Two clocks").
## - Caches the result in [member _last_wall_ts] so that [method now_ms] and
##   any future debug mock (Story 010) can derive millisecond time without an
##   additional OS call.
## - Story 010 will splice a debug-mock hook here; this routing function is the
##   seam that makes that splice zero-touch for all other call sites.
##
## Example:
##   var unix_seconds: int = _read_wall_clock_unix_time()  # e.g. 1_714_000_000
func _read_wall_clock_unix_time() -> int:
	_last_wall_ts = int(Time.get_unix_time_from_system())
	return _last_wall_ts
