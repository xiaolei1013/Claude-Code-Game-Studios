## DungeonRunState — 5-state FSM definition + complete 5×6 transition matrix
## for the [DungeonRunOrchestrator] (Story 002 will instantiate the autoload
## that consumes this).
##
## Story 001 keeps the State enum and transition logic in a standalone
## [code]class_name DungeonRunState[/code] file — Story 002 imports it via
## [code]const State := DungeonRunState.State[/code] in the orchestrator.
## Splitting state definitions from the autoload lets stories reference the
## enum + matrix without depending on the autoload being present in tests
## (the matrix is pure logic — no Node instance required).
##
## TR-orchestrator-001 (5-state FSM in canonical order)
## TR-orchestrator-002 (exhaustive 5×6 state-trigger matrix)
##
## ADR-0014: RunSnapshot Schema + chunked offline replay
class_name DungeonRunState

# ---------------------------------------------------------------------------
# State enum — TR-orchestrator-001 — order is contractual
# ---------------------------------------------------------------------------

## Run lifecycle states. Order matches GDD §B and is contractual — the integer
## values are persisted in save data. NEVER reorder; only append new states
## with new int values if the FSM grows.
enum State {
	NO_RUN = 0,                  # No formation dispatched
	DISPATCHING = 1,             # Validating formation + computing snapshot
	ACTIVE_FOREGROUND = 2,       # App visible; subscribed to tick_fired
	ACTIVE_OFFLINE_REPLAY = 3,   # One-shot compute_offline_batch in progress
	RUN_ENDED = 4,               # Snapshot retained for ReturnToApp display
}


# ---------------------------------------------------------------------------
# Triggers — TR-orchestrator-002 — exact 6-element set per GDD §B
# ---------------------------------------------------------------------------

## Player-pressed Dispatch button on Formation Assignment Screen.
const TRIGGER_DISPATCH_PRESSED: String = "dispatch_pressed"

## `formation_reassignment_committed` signal fired (player swap confirmed).
## NOT fired by browse-only opens (C.7 read/write split).
const TRIGGER_FORMATION_CHANGED: String = "formation_changed"

## App moves to background (mobile sleep, Steam Deck suspend, desktop minimize).
const TRIGGER_APP_SUSPENDED: String = "app_suspended"

## App returns to foreground. May complete a pending offline replay.
const TRIGGER_APP_RESUMED: String = "app_resumed"

## `compute_offline_batch` finished (Offline Engine signals completion).
const TRIGGER_OFFLINE_REPLAY_COMPLETE: String = "offline_replay_complete"

## Internal trigger fired when validation fails at DISPATCHING, the player
## explicitly recalls formation, or `replay_failed` error path triggers.
const TRIGGER_RUN_ENDED: String = "run_ended"


## All 6 valid triggers — used by [method validate_transition] to detect
## unknown trigger strings (push_error + return from-state unchanged).
const ALL_TRIGGERS: Array[String] = [
	TRIGGER_DISPATCH_PRESSED,
	TRIGGER_FORMATION_CHANGED,
	TRIGGER_APP_SUSPENDED,
	TRIGGER_APP_RESUMED,
	TRIGGER_OFFLINE_REPLAY_COMPLETE,
	TRIGGER_RUN_ENDED,
]


# ---------------------------------------------------------------------------
# State × trigger matrix — TR-orchestrator-002
# Every (state, trigger) pair is documented:
#   - Returns next State on a valid transition (including no-op self-loops).
#   - Logs push_error and returns the unchanged from-state on invalid cells
#     (per GDD §B "Invalid cell behavior" — Orchestrator stays operational).
#
# Source: design/gdd/dungeon-run-orchestrator.md §B "Complete state × trigger
# matrix" + Pass 4A complete-matrix codification.
# ---------------------------------------------------------------------------

## Returns the next [enum State] for the (from, trigger) cell or [param from]
## unchanged for invalid cells (push_error logged in standardized format).
##
## Static: callable without an Orchestrator instance — the matrix is pure
## logic and is unit-testable in isolation.
##
## TR-orchestrator-002
static func validate_transition(from: int, trigger: String) -> int:
	# Reject unknown triggers up-front — defends against typos in caller code.
	if not (trigger in ALL_TRIGGERS):
		push_error(
			"DungeonRunState: unknown trigger '%s' from state %s; ignoring"
			% [trigger, _state_name(from)]
		)
		return from

	match from:
		State.NO_RUN:
			return _from_no_run(trigger)
		State.DISPATCHING:
			return _from_dispatching(trigger)
		State.ACTIVE_FOREGROUND:
			return _from_active_foreground(trigger)
		State.ACTIVE_OFFLINE_REPLAY:
			return _from_active_offline_replay(trigger)
		State.RUN_ENDED:
			return _from_run_ended(trigger)
	# Unknown from-state — defensive. Should never happen given the enum.
	push_error(
		"DungeonRunState: unknown from-state %d (trigger '%s')" % [from, trigger]
	)
	return from


# Row 1: NO_RUN
static func _from_no_run(trigger: String) -> int:
	match trigger:
		TRIGGER_DISPATCH_PRESSED:
			return State.DISPATCHING                  # begin validation + snapshot
		TRIGGER_FORMATION_CHANGED:
			return _invalid(State.NO_RUN, trigger)    # no active run to modify
		TRIGGER_APP_SUSPENDED:
			return State.NO_RUN                        # no-op; nothing to persist
		TRIGGER_APP_RESUMED:
			return State.NO_RUN                        # no-op; no run was active
		TRIGGER_OFFLINE_REPLAY_COMPLETE:
			return _invalid(State.NO_RUN, trigger)    # no replay was running
		TRIGGER_RUN_ENDED:
			return _invalid(State.NO_RUN, trigger)    # no run to end
	return State.NO_RUN


# Row 2: DISPATCHING (synchronous <1-frame state — most cells reject)
static func _from_dispatching(trigger: String) -> int:
	match trigger:
		TRIGGER_DISPATCH_PRESSED:
			return _invalid(State.DISPATCHING, trigger)  # debounce should catch this
		TRIGGER_FORMATION_CHANGED:
			return _invalid(State.DISPATCHING, trigger)  # formation already frozen
		TRIGGER_APP_SUSPENDED:
			return _invalid(State.DISPATCHING, trigger)  # must complete or abort first
		TRIGGER_APP_RESUMED:
			return _invalid(State.DISPATCHING, trigger)  # synchronous state; resume is nonsense
		TRIGGER_OFFLINE_REPLAY_COMPLETE:
			return _invalid(State.DISPATCHING, trigger)  # no replay was running
		TRIGGER_RUN_ENDED:
			return State.RUN_ENDED                       # validation failure path
	return State.DISPATCHING


# Row 3: ACTIVE_FOREGROUND (the steady state)
static func _from_active_foreground(trigger: String) -> int:
	match trigger:
		TRIGGER_DISPATCH_PRESSED:
			return _invalid(State.ACTIVE_FOREGROUND, trigger)  # must end run first
		TRIGGER_FORMATION_CHANGED:
			# Mid-run reassignment: ends current run, begins new dispatch.
			# Single-step transition lands on DISPATCHING; the orchestrator's
			# transition handler is responsible for emitting `run_ended` events
			# atomically with the state change (see Story 003 entry/exit hooks).
			return State.DISPATCHING
		TRIGGER_APP_SUSPENDED:
			return State.ACTIVE_OFFLINE_REPLAY            # persist + Offline Engine takes over
		TRIGGER_APP_RESUMED:
			return State.ACTIVE_FOREGROUND                # no-op; already foreground
		TRIGGER_OFFLINE_REPLAY_COMPLETE:
			return _invalid(State.ACTIVE_FOREGROUND, trigger)  # no replay was running
		TRIGGER_RUN_ENDED:
			return State.RUN_ENDED                        # explicit recall or error
	return State.ACTIVE_FOREGROUND


# Row 4: ACTIVE_OFFLINE_REPLAY
static func _from_active_offline_replay(trigger: String) -> int:
	match trigger:
		TRIGGER_DISPATCH_PRESSED:
			return _invalid(State.ACTIVE_OFFLINE_REPLAY, trigger)  # cannot dispatch during replay
		TRIGGER_FORMATION_CHANGED:
			# Reassignment policy: replay result discarded; new dispatch begins
			# after RUN_ENDED → DISPATCHING on next player action.
			return State.RUN_ENDED
		TRIGGER_APP_SUSPENDED:
			return State.ACTIVE_OFFLINE_REPLAY            # no-op; already offline
		TRIGGER_APP_RESUMED:
			# If replay still computing → stay; if computing complete →
			# orchestrator transitions to FOREGROUND on the
			# `offline_replay_complete` trigger, not here. The pure-FSM
			# transition for app_resumed is the no-op stay; the multi-step
			# transition (replay-complete-then-resume) is the orchestrator's
			# responsibility to sequence.
			return State.ACTIVE_OFFLINE_REPLAY
		TRIGGER_OFFLINE_REPLAY_COMPLETE:
			# Default success path: replay complete + app foregrounded →
			# resume foreground play. Recall path uses `run_ended` separately.
			return State.ACTIVE_FOREGROUND
		TRIGGER_RUN_ENDED:
			return State.RUN_ENDED                        # `replay_failed` error path
	return State.ACTIVE_OFFLINE_REPLAY


# Row 5: RUN_ENDED
static func _from_run_ended(trigger: String) -> int:
	match trigger:
		TRIGGER_DISPATCH_PRESSED:
			return State.DISPATCHING                      # player begins new dispatch
		TRIGGER_FORMATION_CHANGED:
			return _invalid(State.RUN_ENDED, trigger)    # run already over
		TRIGGER_APP_SUSPENDED:
			return State.RUN_ENDED                        # no-op; snapshot frozen
		TRIGGER_APP_RESUMED:
			return State.RUN_ENDED                        # no-op; no active run
		TRIGGER_OFFLINE_REPLAY_COMPLETE:
			return _invalid(State.RUN_ENDED, trigger)    # no replay was running
		TRIGGER_RUN_ENDED:
			return State.NO_RUN                           # player explicitly clears
	return State.RUN_ENDED


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Standardized push_error for invalid cells. Returns [param from] unchanged
## per GDD §B "Invalid cell behavior" — Orchestrator stays operational.
static func _invalid(from: int, trigger: String) -> int:
	push_error(
		"Orchestrator: invalid trigger %s in state %s; ignoring"
		% [trigger, _state_name(from)]
	)
	return from


## Returns the State enum's string name for diagnostic messages. Used by
## [method validate_transition] error formatting; static so it's testable
## in isolation.
static func _state_name(state: int) -> String:
	match state:
		State.NO_RUN:
			return "NO_RUN"
		State.DISPATCHING:
			return "DISPATCHING"
		State.ACTIVE_FOREGROUND:
			return "ACTIVE_FOREGROUND"
		State.ACTIVE_OFFLINE_REPLAY:
			return "ACTIVE_OFFLINE_REPLAY"
		State.RUN_ENDED:
			return "RUN_ENDED"
	return "UNKNOWN(%d)" % state
