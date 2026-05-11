# Tests for US-034 (test-coverage-backfill):
#   - DungeonRunState.validate_transition — fills the per-cell expected-return
#     coverage gaps for cells where run_snapshot_and_fsm_test.gd asserts only
#     "returns a valid State" (via the Group C exhaustiveness loop) but lacks
#     a specific expected-State assertion.
#
# Background: the exhaustiveness loop at run_snapshot_and_fsm_test.gd:55-70
# catches any cell that returns an invalid State int, but it does NOT catch
# a cell that returns a DIFFERENT but valid State (e.g., DISPATCHING
# silently mutating to return RUN_ENDED instead of staying DISPATCHING).
# 7 of 30 (state, trigger) cells lacked a specific expected-return test
# prior to this suite, plus the unknown from-state defensive guard.
#
# Coverage map vs. dungeon_run_state.gd (line numbers in source):
#   Row 2 DISPATCHING (line 135):
#     * app_resumed -> DISPATCHING (invalid, line 144)              — UNTESTED
#     * offline_replay_complete -> DISPATCHING (invalid, line 146)  — UNTESTED
#   Row 3 ACTIVE_FOREGROUND (line 153):
#     * offline_replay_complete -> ACTIVE_FOREGROUND (invalid, line 168) — UNTESTED
#   Row 4 ACTIVE_OFFLINE_REPLAY (line 175):
#     * app_suspended -> ACTIVE_OFFLINE_REPLAY (no-op, line 184)    — UNTESTED
#     * app_resumed -> ACTIVE_OFFLINE_REPLAY (no-op, line 192)      — UNTESTED
#   Row 5 RUN_ENDED (line 203):
#     * app_resumed -> RUN_ENDED (no-op, line 212)                  — UNTESTED
#     * offline_replay_complete -> RUN_ENDED (invalid, line 214)    — UNTESTED
#   Defensive guard (line 109-113):
#     * unknown from-state int -> returns from unchanged            — UNTESTED
#
# Covers: TR-orchestrator-002 (exhaustive 5x6 state-trigger matrix per-cell
#         expected-return contract, not just "valid State returned").
extends GdUnitTestSuite

const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")


# ---------------------------------------------------------------------------
# Row 2: DISPATCHING — invalid-cell self-loops (synchronous <1-frame state)
# ---------------------------------------------------------------------------

func test_dispatching_app_resumed_is_invalid_stays_dispatching() -> void:
	# dungeon_run_state.gd:144 — synchronous state; "resume" is nonsense from
	# DISPATCHING. push_error logged; from-state returned unchanged.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.DISPATCHING, "app_resumed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.DISPATCHING)


func test_dispatching_offline_replay_complete_is_invalid_stays_dispatching() -> void:
	# dungeon_run_state.gd:146 — no replay was running. push_error logged;
	# from-state returned unchanged.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.DISPATCHING, "offline_replay_complete"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.DISPATCHING)


# ---------------------------------------------------------------------------
# Row 3: ACTIVE_FOREGROUND — final invalid cell
# ---------------------------------------------------------------------------

func test_active_foreground_offline_replay_complete_is_invalid() -> void:
	# dungeon_run_state.gd:168 — no replay was running while in foreground.
	# push_error logged; from-state returned unchanged.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_FOREGROUND, "offline_replay_complete"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.ACTIVE_FOREGROUND)


# ---------------------------------------------------------------------------
# Row 4: ACTIVE_OFFLINE_REPLAY — self-loop no-op cells
# ---------------------------------------------------------------------------

func test_active_offline_replay_app_suspended_is_noop() -> void:
	# dungeon_run_state.gd:184 — already offline; suspending again is a no-op.
	# Returns ACTIVE_OFFLINE_REPLAY unchanged, NOT an invalid push_error path.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY, "app_suspended"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY)


func test_active_offline_replay_app_resumed_is_noop_when_replay_pending() -> void:
	# dungeon_run_state.gd:185-192 — pure-FSM transition for app_resumed during
	# an in-flight replay is a no-op stay; the multi-step "replay-complete-then
	# -resume" transition is the orchestrator's sequencing concern (see source
	# comment lines 186-191). Returns ACTIVE_OFFLINE_REPLAY unchanged.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY, "app_resumed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.ACTIVE_OFFLINE_REPLAY)


# ---------------------------------------------------------------------------
# Row 5: RUN_ENDED — final 2 cells (one no-op, one invalid)
# ---------------------------------------------------------------------------

func test_run_ended_app_resumed_is_noop() -> void:
	# dungeon_run_state.gd:212 — no active run to resume into; snapshot frozen.
	# Returns RUN_ENDED unchanged.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.RUN_ENDED, "app_resumed"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.RUN_ENDED)


func test_run_ended_offline_replay_complete_is_invalid() -> void:
	# dungeon_run_state.gd:214 — no replay was running once the run has ended.
	# push_error logged; from-state returned unchanged.
	var n: int = DungeonRunStateScript.validate_transition(
		DungeonRunStateScript.State.RUN_ENDED, "offline_replay_complete"
	)
	assert_int(n).is_equal(DungeonRunStateScript.State.RUN_ENDED)


# ---------------------------------------------------------------------------
# Defensive guard: unknown from-state int
# ---------------------------------------------------------------------------

func test_validate_transition_unknown_from_state_returns_from_unchanged() -> void:
	# dungeon_run_state.gd:109-113 — defensive branch for from-state values
	# outside the State enum. push_error logged; from-state returned unchanged.
	# In practice unreachable given the enum, but the contract is documented
	# and worth pinning so a future refactor of the match block can't silently
	# regress the defensive return shape.
	var bogus_from: int = -1
	var n: int = DungeonRunStateScript.validate_transition(
		bogus_from, "dispatch_pressed"
	)
	assert_int(n).is_equal(bogus_from)
