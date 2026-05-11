# US-006 (test-coverage-backfill): targeted coverage for FloorUnlockSystem's
# debug/test API — `debug_set_highest_cleared` + `debug_reset`.
#
# Existing suites assert these methods EXIST (`has_method`) and consume
# `debug_set_highest_cleared` as integration-test setup, but neither has direct
# happy-path or edge-case behavioral coverage. Per EPIC FR-2/FR-3 every public
# function needs at least one happy + edge assertion against documented
# behavior — these tests close that gap.
#
# Production-build branch (the `if not OS.is_debug_build()` guard) is NOT
# directly testable because gdunit4 runs under a debug build by definition;
# we cover the in-debug-build behavior (the path that mutates state) and
# document the production-build branch as covered-by-construction.
extends GdUnitTestSuite

const FloorUnlockScript = preload("res://src/core/floor_unlock_system/floor_unlock_system.gd")


# ---------------------------------------------------------------------------
# Fixture helper — mirrors floor_unlock_system_test.gd::_make_floor_unlock_with_stubs
# (typed-dict literal-rejection workaround documented in MEMORY.md
# project_typed_collection_test_fixtures).
# ---------------------------------------------------------------------------

func _make_fu() -> Node:
	var fu: Node = FloorUnlockScript.new()
	auto_free(fu)
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	fu.BIOME_FLOOR_COUNT = bfc
	var us: Dictionary[String, int] = {"forest_reach": 0}
	fu._unlock_state = us
	return fu


# ===========================================================================
# debug_set_highest_cleared — in-debug-build happy + edge paths
# ===========================================================================

func test_debug_set_highest_cleared_writes_value_to_unlock_state() -> void:
	# Arrange — fresh stub, forest_reach starts at 0.
	var fu: Node = _make_fu()
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)

	# Act
	fu.debug_set_highest_cleared("forest_reach", 3)

	# Assert — direct write reflected via the public accessor.
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(3)


func test_debug_set_highest_cleared_overwrites_existing_value() -> void:
	# debug_* bypasses the monotone R4 invariant — it's a raw setter, so it
	# can DECREASE the counter (which the signal-handler path cannot).
	var fu: Node = _make_fu()
	fu._unlock_state["forest_reach"] = 4

	# Act — set lower than current.
	fu.debug_set_highest_cleared("forest_reach", 1)

	# Assert — written as-is, no monotone enforcement.
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(1)


func test_debug_set_highest_cleared_accepts_unknown_biome_and_creates_entry() -> void:
	# Edge: biome NOT in BIOME_FLOOR_COUNT. The debug setter does NOT validate
	# biome availability (unlike the signal handler), so a new entry is added
	# directly to _unlock_state. UI consumers still filter via is_biome_available.
	var fu: Node = _make_fu()
	assert_bool(fu._unlock_state.has("ghost_biome")).is_false()

	# Act
	fu.debug_set_highest_cleared("ghost_biome", 7)

	# Assert — entry created in _unlock_state but biome remains unavailable.
	assert_int(fu._unlock_state.get("ghost_biome", -1)).is_equal(7)
	assert_bool(fu.is_biome_available("ghost_biome")).is_false()
	# Stale-entry semantics still apply: get_highest_cleared returns the value
	# regardless of availability (consumers must filter).
	assert_int(fu.get_highest_cleared("ghost_biome")).is_equal(7)


func test_debug_set_highest_cleared_accepts_value_above_floor_count() -> void:
	# Edge: debug bypasses the over-range clamp that load_save_data applies.
	# Setting 999 on a 5-floor biome stores 999 directly (the debug helper
	# trusts the caller; this is what makes it useful for test-state setup).
	var fu: Node = _make_fu()

	fu.debug_set_highest_cleared("forest_reach", 999)

	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(999)


# ===========================================================================
# debug_reset — happy + edge paths
# ===========================================================================

func test_debug_reset_clears_existing_state_and_seeds_fresh_save_default() -> void:
	# Arrange — populated state across multiple biomes.
	var fu: Node = _make_fu()
	fu._unlock_state["forest_reach"] = 4
	fu._unlock_state["another_biome"] = 2
	assert_int(fu._unlock_state.size()).is_equal(2)

	# Act
	fu.debug_reset()

	# Assert — _unlock_state holds ONLY the fresh-save default {"forest_reach": 0}.
	assert_int(fu._unlock_state.size()).is_equal(1)
	assert_bool(fu._unlock_state.has("forest_reach")).is_true()
	assert_int(fu._unlock_state["forest_reach"]).is_equal(0)
	assert_bool(fu._unlock_state.has("another_biome")).is_false()


func test_debug_reset_on_already_empty_state_seeds_fresh_save_default() -> void:
	# Edge: _unlock_state was already cleared by some prior path. debug_reset
	# is idempotent — it always lands on the fresh-save default per R2.
	var fu: Node = _make_fu()
	fu._unlock_state.clear()
	assert_int(fu._unlock_state.size()).is_equal(0)

	# Act
	fu.debug_reset()

	# Assert — fresh-save default seeded.
	assert_int(fu._unlock_state.size()).is_equal(1)
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)


func test_debug_reset_drops_stale_biome_entries() -> void:
	# Edge: _unlock_state has stale entries (biomes removed from active set).
	# debug_reset must drop them — the seed-fresh-save-default path only
	# guarantees forest_reach exists at 0.
	var fu: Node = _make_fu()
	fu._unlock_state["removed_biome"] = 9
	fu._unlock_state["forest_reach"] = 3

	# Act
	fu.debug_reset()

	# Assert — stale entry gone; fresh default in place.
	assert_bool(fu._unlock_state.has("removed_biome")).is_false()
	assert_int(fu.get_highest_cleared("forest_reach")).is_equal(0)
