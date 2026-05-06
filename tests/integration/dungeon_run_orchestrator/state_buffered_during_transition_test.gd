## state_buffered_during_transition_test.gd — Story 013 / TR-orchestrator-014
##
## Verifies the orchestrator-level buffered-replay pattern that closes the
## "screen detects already-advanced state on enter" race documented in
## Sprint 8 S8-M4 + Sprint 9 S9-M2.
##
## Behavior under test:
##   - When SceneManager.state == TRANSITIONING, DungeonRunOrchestrator._set_state
##     buffers the state_changed emit instead of firing it.
##   - Buffered emit is replayed when SceneManager.transition_complete fires
##     (CONNECT_ONE_SHOT).
##   - When SceneManager.state != TRANSITIONING, _set_state emits synchronously
##     (no buffering).
##   - Multiple state changes during one TRANSITIONING window are coalesced —
##     only the LATEST new_state is replayed, but the ORIGINAL old_state
##     (pre-transition) is preserved.
##
## Sprint origin: Sprint 13 S13-S1 (carry-forward from Sprint 10 S10-S1).
## Story: production/epics/dungeon-run-orchestrator/story-013-orchestrator-state-during-scene-transition.md
extends GdUnitTestSuite

const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")


# ---------------------------------------------------------------------------
# Hygiene barrier — reset orchestrator + SceneManager state on entry/exit.
# ---------------------------------------------------------------------------

func _restore_state() -> void:
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.NO_RUN
	DungeonRunOrchestrator._buffered_state_change.clear()
	# Disconnect any pending replay handler (defensive — CONNECT_ONE_SHOT
	# usually auto-disconnects but a test may have set up a buffered emit
	# without firing the replay).
	if SceneManager.transition_complete.is_connected(
		DungeonRunOrchestrator._replay_buffered_state_change
	):
		SceneManager.transition_complete.disconnect(
			DungeonRunOrchestrator._replay_buffered_state_change
		)
	SceneManager.state = SceneManager.State.IDLE


func before_test() -> void:
	_restore_state()


func after_test() -> void:
	_restore_state()


# ===========================================================================
# Group A: TR-014-001 — buffer-and-replay during TRANSITIONING
# ===========================================================================

func test_state_changed_buffered_when_scene_manager_is_transitioning() -> void:
	## TR-014-001: When SM.state == TRANSITIONING at the moment _set_state
	## fires, the state_changed signal is buffered and NOT emitted.
	# Arrange
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	SceneManager.state = SceneManager.State.TRANSITIONING

	var emit_count: Array[int] = [0]
	DungeonRunOrchestrator.state_changed.connect(
		func(_n, _o): emit_count[0] += 1
	)

	# Act — _set_state during TRANSITIONING.
	DungeonRunOrchestrator._set_state(DungeonRunStateScript.State.RUN_ENDED)

	# Assert — buffer populated, no emit fired.
	assert_bool(DungeonRunOrchestrator._buffered_state_change.is_empty()).is_false()
	assert_int(emit_count[0]).is_equal(0)
	assert_int(
		int(DungeonRunOrchestrator._buffered_state_change.get("new_state", -1))
	).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	assert_int(
		int(DungeonRunOrchestrator._buffered_state_change.get("old_state", -1))
	).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	# Cleanup — after_test() resets the orchestrator + clears state.
	# The emit_count lambda has no stable handle to disconnect by; rely
	# on before_test/after_test hygiene barrier to clear cross-test state.


func test_buffered_state_change_replays_on_transition_complete() -> void:
	## TR-014-001: The buffered emit fires when SceneManager.transition_complete
	## fires (the canonical post-transition replay trigger).
	# Arrange
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	SceneManager.state = SceneManager.State.TRANSITIONING

	var captured: Array = [null]  # captures (new_state, old_state)
	DungeonRunOrchestrator.state_changed.connect(
		func(n, o): captured[0] = {"new": n, "old": o},
		CONNECT_ONE_SHOT
	)

	# Act — buffer the emit, then trigger the replay.
	DungeonRunOrchestrator._set_state(DungeonRunStateScript.State.RUN_ENDED)
	# Verify pre-replay: no emit yet.
	assert_object(captured[0]).is_null()

	# Trigger the replay via the canonical signal pathway.
	SceneManager.transition_complete.emit(
		"dungeon_run_view", SceneManager.TransitionType.FADE_TO_BLACK
	)
	await get_tree().process_frame

	# Assert — buffered emit replayed; buffer cleared.
	assert_object(captured[0]).is_not_null()
	assert_int(int(captured[0].new)).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	assert_int(int(captured[0].old)).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	assert_bool(DungeonRunOrchestrator._buffered_state_change.is_empty()).is_true()


# ===========================================================================
# Group B: TR-014-002 — synchronous emit when SM is IDLE
# ===========================================================================

func test_state_changed_emits_synchronously_when_scene_manager_is_idle() -> void:
	## TR-014-002: When SM.state == IDLE at the moment _set_state fires,
	## state_changed emits synchronously (no buffering).
	# Arrange
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.NO_RUN
	SceneManager.state = SceneManager.State.IDLE

	var captured: Array = [null]
	DungeonRunOrchestrator.state_changed.connect(
		func(n, o): captured[0] = {"new": n, "old": o},
		CONNECT_ONE_SHOT
	)

	# Act — _set_state with SM IDLE.
	DungeonRunOrchestrator._set_state(DungeonRunStateScript.State.DISPATCHING)

	# Assert — emit fired synchronously, buffer empty.
	assert_object(captured[0]).is_not_null()
	assert_int(int(captured[0].new)).is_equal(DungeonRunStateScript.State.DISPATCHING)
	assert_int(int(captured[0].old)).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_bool(DungeonRunOrchestrator._buffered_state_change.is_empty()).is_true()


# ===========================================================================
# Group C: TR-014-004 — coalesce semantic (multiple changes, one replay)
# ===========================================================================

func test_multiple_state_changes_during_transition_coalesce_to_terminal_state() -> void:
	## TR-014-004: If multiple orchestrator state transitions occur during
	## one TRANSITIONING window, the buffered replay emits only the most
	## recent (terminal) new_state, but the OLD_STATE preserved is the
	## pre-transition state — making the post-transition emit reflect the
	## cross-transition transition.
	# Arrange
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.NO_RUN
	SceneManager.state = SceneManager.State.TRANSITIONING

	var captured: Array = [null]
	var emit_count: Array[int] = [0]
	DungeonRunOrchestrator.state_changed.connect(
		func(n, o):
			captured[0] = {"new": n, "old": o}
			emit_count[0] += 1,
		CONNECT_ONE_SHOT
	)

	# Act — three state changes during one TRANSITIONING window.
	# IDLE -> DISPATCHING -> ACTIVE_FOREGROUND -> RUN_ENDED.
	DungeonRunOrchestrator._set_state(DungeonRunStateScript.State.DISPATCHING)
	DungeonRunOrchestrator._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)
	DungeonRunOrchestrator._set_state(DungeonRunStateScript.State.RUN_ENDED)

	# Verify pre-replay: buffer holds the terminal new_state with the
	# original IDLE old_state.
	assert_int(
		int(DungeonRunOrchestrator._buffered_state_change.get("new_state", -1))
	).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	assert_int(
		int(DungeonRunOrchestrator._buffered_state_change.get("old_state", -1))
	).is_equal(DungeonRunStateScript.State.NO_RUN)
	assert_int(emit_count[0]).is_equal(0)

	# Trigger the replay.
	SceneManager.transition_complete.emit(
		"dungeon_run_view", SceneManager.TransitionType.FADE_TO_BLACK
	)
	await get_tree().process_frame

	# Assert — exactly ONE emit, with the terminal new_state and original
	# old_state. Intermediate states (DISPATCHING, ACTIVE_FOREGROUND) are
	# coalesced.
	assert_int(emit_count[0]).is_equal(1)
	assert_int(int(captured[0].new)).is_equal(DungeonRunStateScript.State.RUN_ENDED)
	assert_int(int(captured[0].old)).is_equal(DungeonRunStateScript.State.NO_RUN)


# ===========================================================================
# Group D: defensive paths
# ===========================================================================

func test_replay_buffered_state_change_is_noop_when_buffer_empty() -> void:
	## Defensive: calling _replay_buffered_state_change with an empty buffer
	## is a no-op. Documented in the helper's surface comment.
	# Arrange — empty buffer (cleared in before_test).
	assert_bool(DungeonRunOrchestrator._buffered_state_change.is_empty()).is_true()

	var emit_count: Array[int] = [0]
	DungeonRunOrchestrator.state_changed.connect(
		func(_n, _o): emit_count[0] += 1
	)

	# Act
	DungeonRunOrchestrator._replay_buffered_state_change(
		"any_screen", SceneManager.TransitionType.CROSS_FADE
	)

	# Assert — no emit fired.
	assert_int(emit_count[0]).is_equal(0)


func test_set_state_no_op_self_transition_does_not_buffer() -> void:
	## When _set_state is called with the same state as the current state,
	## the early-return at the top of _set_state prevents any side effect —
	## including buffering. This is the canonical no-op self-transition path.
	# Arrange
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	SceneManager.state = SceneManager.State.TRANSITIONING

	# Act — set the SAME state.
	DungeonRunOrchestrator._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	# Assert — buffer empty (no-op).
	assert_bool(DungeonRunOrchestrator._buffered_state_change.is_empty()).is_true()
