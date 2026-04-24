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
signal offline_elapsed_seconds(seconds: float, cap_reached: bool)

## Emitted when the wall-clock timestamp rewinds beyond REWIND_TOLERANCE_SECONDS,
## indicating a suspicious system-clock adjustment.
signal flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)

# ---------------------------------------------------------------------------
# Export tuning knobs (designer-configurable defaults; override in .tscn or
# project autoload resource if the editor exposes them)
# ---------------------------------------------------------------------------

## Maximum offline time credited to the player, in seconds (default 8 hours).
@export var offline_cap_seconds: int = 28_800

## Tolerance for backward clock jumps before flagging as suspicious, in seconds.
@export var REWIND_TOLERANCE_SECONDS: int = 300

## Interval at which the session high-water timestamp is persisted, in seconds.
@export var heartbeat_interval_seconds: int = 60

# ---------------------------------------------------------------------------
# Private state (session-scoped; NOT persistent — TR-time-004)
# ---------------------------------------------------------------------------

## Fractional-second accumulator for the sim clock.
## Preserved across pause (never reset to 0 on unpause — TR-time-010 / ADR-0005).
## The _notification handler MUST NOT touch this value on BG entry.
var _tick_accumulator_seconds: float = 0.0

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
	# TODO (Story 008): heartbeat accumulator must still advance under UI pause
	# (TR-time-034). Currently we early-return on both BG and UI-paused because
	# there is no heartbeat code to gate. When heartbeat lands, restructure
	# this so only the tick-emission branch is suppressed under UI pause.
	if _app_state != AppState.FOREGROUND or _ui_paused:
		return
	_tick_accumulator_seconds += delta
	while _tick_accumulator_seconds >= _TICK_INTERVAL_SECONDS:
		_tick_accumulator_seconds -= _TICK_INTERVAL_SECONDS
		var _previous_counter: int = _sim_tick_counter
		_sim_tick_counter += 1
		assert(_sim_tick_counter > _previous_counter, \
			"TickSystem: _sim_tick_counter decreased — monotonic invariant violated")
		tick_fired.emit(_sim_tick_counter)  # synchronous — NEVER call_deferred

# ---------------------------------------------------------------------------
# Public API
## Story 002 fills in accumulator + tick emission (done above).
## Story 004 adds set_ui_paused (done below).
## Story 008 wires SaveLoadSystem to call set_last_persist_ts /
## set_session_high_water on heartbeat.
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

## Suppresses tick emission while keeping [member _app_state] as FOREGROUND.
##
## When [param paused] is [code]true[/code], [method _process] returns before
## advancing the accumulator, halting tick emission without changing lifecycle
## state.  When [param paused] is [code]false[/code], tick emission resumes
## from the preserved accumulator residual (TR-time-010).
##
## NOTE (Story 008): Once the heartbeat accumulator lands, [method _process]
## must be restructured so the heartbeat still advances under UI pause while
## only the tick-emission branch is suppressed.  See the TODO comment in
## [method _process].
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
