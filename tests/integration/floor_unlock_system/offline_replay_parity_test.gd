# Tests for floor-unlock-system/story-008 — offline replay parity per ADR-0014.
#
# Covers:
#   - TR-030: foreground vs offline-replay paths produce IDENTICAL `_unlock_state`
#     for the same logical kill/clear sequence. Both paths route through the
#     same handler `_on_floor_cleared_first_time` — there's no offline-specific
#     branch in FloorUnlock. Parity is enforced by signal-emission lockstep.
#   - TR-025: `advance_unlock` does NOT call any save-dirty-mark method.
#     Persistence relies on Save/Load Rule 5's heartbeat cadence (60s).
#     Verified by source-grep canary.
#
# This is primarily a regression/contract test — the emission lockstep itself
# is the orchestrator's responsibility (out of scope here per the story spec).
# What FloorUnlock owns: the same handler must produce identical state when
# fed the same logical signal sequence, regardless of who emits it.
extends GdUnitTestSuite

const FloorUnlockScript = preload("res://src/core/floor_unlock_system/floor_unlock_system.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_fu() -> Node:
	var fu: Node = FloorUnlockScript.new()
	auto_free(fu)
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	fu.BIOME_FLOOR_COUNT = bfc
	var us: Dictionary[String, int] = {"forest_reach": 0}
	fu._unlock_state = us
	return fu


# ---------------------------------------------------------------------------
# TR-030 parity: foreground vs offline produce identical _unlock_state
#
# The test drives the SAME handler function with two "paths" — Path A
# represents the foreground tick-driven sequence (orchestrator emits +
# FloorUnlock subscriber consumes); Path B represents the offline-batch
# replay (orchestrator's offline replay emits the SAME signal). Since both
# paths route through `_on_floor_cleared_first_time`, identical inputs MUST
# produce identical outputs. The handler's purity is the enforcement — no
# offline-branch exists in FloorUnlock.
# ---------------------------------------------------------------------------

func test_tr030_foreground_and_offline_paths_produce_identical_unlock_state() -> void:
	# Arrange — two FloorUnlock instances, identical starting state
	var fu_foreground: Node = _make_fu()
	var fu_offline: Node = _make_fu()

	# Act — Path A (foreground): handler invoked 3 times for floors 1, 2, 3
	fu_foreground._on_floor_cleared_first_time(1, "forest_reach", false)
	fu_foreground._on_floor_cleared_first_time(2, "forest_reach", false)
	fu_foreground._on_floor_cleared_first_time(3, "forest_reach", false)

	# Path B (offline replay): handler invoked with same logical sequence —
	# in the offline-batch path the orchestrator emits the same signal but
	# in batched form (could be all in one tick). FloorUnlock doesn't care.
	fu_offline._on_floor_cleared_first_time(1, "forest_reach", false)
	fu_offline._on_floor_cleared_first_time(2, "forest_reach", false)
	fu_offline._on_floor_cleared_first_time(3, "forest_reach", false)

	# Assert — identical end state
	assert_int(fu_foreground.get_highest_cleared("forest_reach")).is_equal(3)
	assert_int(fu_offline.get_highest_cleared("forest_reach")).is_equal(3)


func test_tr030_parity_holds_for_losing_run_advances() -> void:
	# Per Story 005 TR-009 (losing_run identical advance), the LOSING-flag
	# variant also produces identical state. Parity holds across the
	# losing_run boolean.
	var fu_win: Node = _make_fu()
	var fu_lose: Node = _make_fu()

	fu_win._on_floor_cleared_first_time(2, "forest_reach", false)
	fu_lose._on_floor_cleared_first_time(2, "forest_reach", true)

	assert_int(fu_win.get_highest_cleared("forest_reach")).is_equal(2)
	assert_int(fu_lose.get_highest_cleared("forest_reach")).is_equal(2)


func test_tr030_parity_handles_idempotent_replay_in_offline_path() -> void:
	# Per Story 005 TR-010 (duplicate signal silent no-op), the offline path's
	# batch may emit duplicate signals if the orchestrator's batch state
	# straddles a floor-clear boundary. Idempotency invariant holds.
	var fu: Node = _make_fu()

	# Simulate a batch that fires the same first-clear 3 times (e.g., orchestrator
	# replayed 3 ticks within the floor-clear window).
	fu._on_floor_cleared_first_time(3, "forest_reach", false)
	fu._on_floor_cleared_first_time(3, "forest_reach", false)
	fu._on_floor_cleared_first_time(3, "forest_reach", false)

	# Final state is 3, not 9 or 0 or any other artifact.
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(3)


# ---------------------------------------------------------------------------
# TR-030 emission lockstep: signal connection is the SAME across paths
# ---------------------------------------------------------------------------

func test_tr030_handler_signature_identical_for_foreground_and_offline_paths() -> void:
	# The handler signature contract: `(floor_index: int, biome_id: String, losing_run: bool)`.
	# Both foreground and offline emissions must use this signature; if the
	# orchestrator's offline-replay path emitted a different shape (e.g.,
	# extra arguments), the connection would error. This is a structural test.
	var fu: Node = _make_fu()

	# Verify the handler accepts the canonical 3-arg shape (no error on call).
	fu._on_floor_cleared_first_time(1, "forest_reach", false)
	fu._on_floor_cleared_first_time(2, "forest_reach", true)

	# Final state reflects both calls.
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(2)


# ---------------------------------------------------------------------------
# TR-025: no save-dirty-mark calls in advance_unlock path
#
# Source-grep canary: scan `src/core/floor_unlock_system/floor_unlock_system.gd`
# for any save-dirty-mark patterns. Per ADR-0014 + Save/Load Rule 5, FloorUnlock
# does NOT mark the save dirty after advance — heartbeat (60s cadence) captures
# the state. Offline replay re-applies the change deterministically next session,
# so transient save-state divergence is acceptable.
# ---------------------------------------------------------------------------

func test_tr025_floor_unlock_source_does_not_call_save_dirty_mark() -> void:
	# Read the source file via FileAccess (test env can read res:// paths)
	var source_path: String = "res://src/core/floor_unlock_system/floor_unlock_system.gd"
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	assert_object(file).is_not_null()
	var contents: String = file.get_as_text()
	file.close()

	# Grep canary: must NOT contain any save-dirty-mark patterns.
	# These are the canonical save-dirty surfaces per Save/Load contract.
	var forbidden_patterns: Array[String] = [
		"mark_dirty",
		"save_now",
		"force_save",
		"request_save",
		"request_full_persist",
		"request_heartbeat_persist",
	]
	var hits: Array[String] = []
	for pat: String in forbidden_patterns:
		if contents.contains(pat):
			hits.append(pat)

	# Assert — zero hits (FloorUnlock relies on heartbeat for persistence)
	assert_int(hits.size()).override_failure_message(
		"FloorUnlock source contains forbidden save-dirty pattern(s): %s. " % str(hits)
		+ "Per TR-025 / ADR-0014 / Save/Load Rule 5, FloorUnlock MUST NOT "
		+ "trigger explicit persists — heartbeat captures the advanced state."
	).is_equal(0)


# ---------------------------------------------------------------------------
# TR-030 parity: monotonic non-decreasing across path swaps
#
# Edge case: if a foreground run clears floor 3, then an offline replay
# (same session resume) re-emits the floor-3 clear, the second emission
# must be a no-op. Tests the realistic scenario where a save loaded after
# a foreground run replays the just-finished run as offline.
# ---------------------------------------------------------------------------

func test_tr030_offline_replay_after_foreground_does_not_decrement_or_re_advance() -> void:
	# Arrange — fresh FloorUnlock
	var fu: Node = _make_fu()

	# Foreground path advances to 3
	fu._on_floor_cleared_first_time(1, "forest_reach", false)
	fu._on_floor_cleared_first_time(2, "forest_reach", false)
	fu._on_floor_cleared_first_time(3, "forest_reach", false)
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(3)

	# Offline replay re-emits the same sequence (e.g., save loaded mid-session;
	# orchestrator's batch replay covers ticks already-replayed in foreground).
	fu._on_floor_cleared_first_time(1, "forest_reach", false)
	fu._on_floor_cleared_first_time(2, "forest_reach", false)
	fu._on_floor_cleared_first_time(3, "forest_reach", false)

	# Assert — state still 3, no decrement or spurious advance
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(3)
