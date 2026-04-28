# Unit tests for the state_changed signal added to DungeonRunOrchestrator in
# Story 012 (Sprint 8 S8-M2). The signal fires from _set_state() after EVERY
# state mutation where new_state != old_state.
#
# Covers:
#   test_state_changed_signal_fires_on_state_transition
#   test_state_changed_signal_payload_contains_new_and_old_states
#   test_state_changed_signal_does_not_fire_for_same_state_set
#
# All tests use a fresh (non-autoload) OrchestratorScript.new() instance wired
# as a child of the suite so the signal bus is isolated from the live autoload.
# DungeonRunState integer constants are read from the preloaded script so this
# test has no coupling to string-based state names.
#
# ADR-0007: Screen lifecycle (state_changed is the preferred RUN_ENDED detection
#           path per AC-6 over per-tick polling)
# Story 012: DungeonRunView — live tick + kill_count display + RUN_ENDED overlay
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")

# ---------------------------------------------------------------------------
# Spy state
# ---------------------------------------------------------------------------

## Accumulates all (new_state, old_state) payloads emitted during the test.
var _spy_state_changed_calls: Array = []  # Array of {new_state: int, old_state: int}


func _on_state_changed(new_state: int, old_state: int) -> void:
	_spy_state_changed_calls.append({"new_state": new_state, "old_state": old_state})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a fresh orchestrator child with the spy connected to state_changed.
## The instance is auto_free()'d so it is freed after each test.
func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


func before_test() -> void:
	_spy_state_changed_calls.clear()


# ---------------------------------------------------------------------------
# test_state_changed_signal_fires_on_state_transition
# ---------------------------------------------------------------------------

## Verifies that state_changed is emitted at least once when _set_state
## transitions from NO_RUN to DISPATCHING (a valid, non-self-transition).
##
## Uses a fresh orchestrator so the starting state is deterministically NO_RUN.
func test_state_changed_signal_fires_on_state_transition() -> void:
	# Arrange
	var orch: Node = _make_orch()
	orch.state_changed.connect(_on_state_changed)

	# Pre-assert: spy is empty before the transition.
	assert_int(_spy_state_changed_calls.size()).is_equal(0)

	# Act — call _set_state directly (bypasses dispatch validation, tests the
	# choke-point in isolation per Story 012 §Implementation Notes).
	orch._set_state(DungeonRunStateScript.State.DISPATCHING)

	# Assert — signal fired at least once.
	assert_int(_spy_state_changed_calls.size()).is_greater_equal(1)


# ---------------------------------------------------------------------------
# test_state_changed_signal_payload_contains_new_and_old_states
# ---------------------------------------------------------------------------

## Verifies that the emitted (new_state, old_state) payload is correct for a
## NO_RUN → DISPATCHING transition.
func test_state_changed_signal_payload_contains_new_and_old_states() -> void:
	# Arrange
	var orch: Node = _make_orch()
	# Confirm the starting state matches the expected old_state.
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	orch.state_changed.connect(_on_state_changed)

	# Act
	orch._set_state(DungeonRunStateScript.State.DISPATCHING)

	# Assert — exactly one emission with correct payload.
	assert_int(_spy_state_changed_calls.size()).is_equal(1)
	var payload: Dictionary = _spy_state_changed_calls[0] as Dictionary
	assert_int(int(payload["new_state"])).is_equal(DungeonRunStateScript.State.DISPATCHING)
	assert_int(int(payload["old_state"])).is_equal(DungeonRunStateScript.State.NO_RUN)


## Verifies that the DISPATCHING → RUN_ENDED transition also carries the
## correct (new_state, old_state) pair — multi-step path through the FSM.
func test_state_changed_signal_payload_dispatching_to_run_ended() -> void:
	# Arrange
	var orch: Node = _make_orch()
	# Force the orchestrator into DISPATCHING by direct field write (bypasses
	# _set_state so _spy is clean for the DISPATCHING → RUN_ENDED step only).
	orch.state = DungeonRunStateScript.State.DISPATCHING
	orch.state_changed.connect(_on_state_changed)

	# Act
	orch._set_state(DungeonRunStateScript.State.RUN_ENDED)

	# Assert
	assert_int(_spy_state_changed_calls.size()).is_equal(1)
	var payload: Dictionary = _spy_state_changed_calls[0] as Dictionary
	assert_int(int(payload["new_state"])).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	assert_int(int(payload["old_state"])).is_equal(DungeonRunStateScript.State.DISPATCHING)


# ---------------------------------------------------------------------------
# test_state_changed_signal_does_not_fire_for_same_state_set
# ---------------------------------------------------------------------------

## Verifies that calling _set_state with the same value as the current state
## (a self-transition) does NOT emit state_changed.
##
## The orchestrator's _set_state already has an early-return guard
## (if new_state == state: return) which prevents any emission. This test
## verifies that guard is in place and working.
func test_state_changed_signal_does_not_fire_for_same_state_set() -> void:
	# Arrange — fresh orchestrator starts at NO_RUN.
	var orch: Node = _make_orch()
	assert_int(orch.state).is_equal(DungeonRunStateScript.State.NO_RUN)
	orch.state_changed.connect(_on_state_changed)

	# Act — call _set_state with the SAME state (NO_RUN → NO_RUN self-transition).
	orch._set_state(DungeonRunStateScript.State.NO_RUN)

	# Assert — no emission.
	assert_int(_spy_state_changed_calls.size()).is_equal(0)


# ---------------------------------------------------------------------------
# Bonus: ACTIVE_FOREGROUND → RUN_ENDED path (the critical path for Story 012)
# ---------------------------------------------------------------------------

## Verifies the ACTIVE_FOREGROUND → RUN_ENDED transition emits state_changed
## with the correct payload — this is the primary consumer path for
## DungeonRunView's run-end overlay (Story 012 AC-3 / AC-6).
func test_state_changed_signal_active_foreground_to_run_ended() -> void:
	# Arrange — set state to ACTIVE_FOREGROUND via direct field write.
	var orch: Node = _make_orch()
	# Wire a minimal run_snapshot so _exit_active_foreground doesn't crash
	# on the TickSystem disconnect (TickSystem is live in the test environment).
	orch.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	orch.state_changed.connect(_on_state_changed)

	# Act
	orch._set_state(DungeonRunStateScript.State.RUN_ENDED)

	# Assert
	assert_int(_spy_state_changed_calls.size()).is_equal(1)
	var payload: Dictionary = _spy_state_changed_calls[0] as Dictionary
	assert_int(int(payload["new_state"])).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	assert_int(int(payload["old_state"])).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
