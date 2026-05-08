# Tests for floor-unlock-system/story-003 — biome availability + completeness
# accessor methods.
#
# Covers:
#   - TR-023 is_biome_available: true for active biome, false for unknown
#   - TR-023 get_available_biomes: Array[String] of active biome ids
#   - TR-024 is_biome_completed: AND of three guards (available + count > 0
#     + highest_cleared == count)
#   - TR-020 stale biome_id preserved in _unlock_state but filtered via
#     is_biome_available
#
# Test isolation pattern matches the canonical floor_unlock_system_test.gd:
# fresh instance NOT added to tree (no _ready fires); manually populate
# BIOME_FLOOR_COUNT + _unlock_state to mimic post-_ready state.
#
# Story spec named `tests/unit/floor_unlock/biome_availability_test.gd` but
# the canonical project location is `tests/unit/floor_unlock_system/`. This
# file lands in the canonical location alongside the existing
# `floor_unlock_system_test.gd`.
extends GdUnitTestSuite

const FloorUnlockScript = preload("res://src/core/floor_unlock_system/floor_unlock_system.gd")


# ---------------------------------------------------------------------------
# Helpers — shared with the canonical test file's _make_floor_unlock_with_stubs
# ---------------------------------------------------------------------------

## Builds a FloorUnlockSystem instance with stub BIOME_FLOOR_COUNT +
## _unlock_state. NOT added to the tree, so _ready() does NOT fire — bypasses
## the DataRegistry boot path so the test focuses on the accessor semantics.
func _make_fu(
	bfc_in: Dictionary[String, int] = {"forest_reach": 5},
	us_in: Dictionary[String, int] = {"forest_reach": 0}
) -> Node:
	var fu: Node = FloorUnlockScript.new()
	auto_free(fu)
	fu.BIOME_FLOOR_COUNT = bfc_in
	fu._unlock_state = us_in
	return fu


# ---------------------------------------------------------------------------
# TR-023: is_biome_available
# ---------------------------------------------------------------------------

func test_tr023_is_biome_available_returns_true_for_active_biome() -> void:
	# Arrange — forest_reach is the active V1 biome
	var fu: Node = _make_fu()

	# Act + Assert
	assert_bool(fu.is_biome_available("forest_reach")).is_true()


func test_tr023_is_biome_available_returns_false_for_fictional_biome() -> void:
	# Arrange
	var fu: Node = _make_fu()

	# Act + Assert — fictional biome NOT in BIOME_FLOOR_COUNT
	assert_bool(fu.is_biome_available("ghost_biome")).is_false()


func test_tr023_is_biome_available_returns_false_for_empty_string() -> void:
	# Sub-AC AC-FU-08: empty-string biome_id returns false defensively.
	var fu: Node = _make_fu()
	assert_bool(fu.is_biome_available("")).is_false()


func test_tr023_is_biome_available_returns_false_for_planned_v1_biome() -> void:
	# Per spec: V1 stub biomes (status != "active") are NOT in BIOME_FLOOR_COUNT
	# (which is populated only from active biomes during _ready()).
	var fu: Node = _make_fu()
	# The stub population only includes forest_reach; planned V1 biomes are absent.
	assert_bool(fu.is_biome_available("planned_v1_biome")).is_false()


# ---------------------------------------------------------------------------
# TR-023: get_available_biomes returns Array[String]
# ---------------------------------------------------------------------------

func test_tr023_get_available_biomes_returns_typed_string_array() -> void:
	# Arrange — single active biome
	var fu: Node = _make_fu()

	# Act
	var result: Array[String] = fu.get_available_biomes()

	# Assert — exactly one entry, "forest_reach"
	assert_int(result.size()).is_equal(1)
	assert_str(result[0]).is_equal("forest_reach")


func test_tr023_get_available_biomes_with_multiple_active_biomes_returns_all() -> void:
	# Arrange — simulate post-V1 state with 2 active biomes
	var bfc: Dictionary[String, int] = {"forest_reach": 5, "crystal_caves": 5}
	var us: Dictionary[String, int] = {"forest_reach": 0, "crystal_caves": 0}
	var fu: Node = _make_fu(bfc, us)

	# Act
	var result: Array[String] = fu.get_available_biomes()

	# Assert — both biomes present (order may differ; check membership)
	assert_int(result.size()).is_equal(2)
	assert_bool(result.has("forest_reach")).is_true()
	assert_bool(result.has("crystal_caves")).is_true()


func test_tr023_get_available_biomes_with_no_active_biomes_returns_empty() -> void:
	# Edge case: no active biomes (BIOME_FLOOR_COUNT is empty). Should return
	# empty array, not crash.
	var bfc: Dictionary[String, int] = {}
	var us: Dictionary[String, int] = {}
	var fu: Node = _make_fu(bfc, us)

	# Act
	var result: Array[String] = fu.get_available_biomes()

	# Assert
	assert_int(result.size()).is_equal(0)


# ---------------------------------------------------------------------------
# TR-024: is_biome_completed three-guard AND
# ---------------------------------------------------------------------------

func test_tr024_is_biome_completed_false_when_biome_unavailable() -> void:
	# Guard 1: biome must be available (in BIOME_FLOOR_COUNT).
	var fu: Node = _make_fu()
	assert_bool(fu.is_biome_completed("ghost_biome")).is_false()


func test_tr024_is_biome_completed_false_when_floor_count_zero_defensive() -> void:
	# Guard 2: BIOME_FLOOR_COUNT[biome] > 0 — defensive against a 0-floor biome
	# that would otherwise produce false-positive 0/0 == "completed".
	var bfc: Dictionary[String, int] = {"empty_biome": 0}
	var us: Dictionary[String, int] = {"empty_biome": 0}
	var fu: Node = _make_fu(bfc, us)

	# is_biome_available returns true (BIOME_FLOOR_COUNT.has it), but
	# is_biome_completed must return false because count is 0.
	assert_bool(fu.is_biome_available("empty_biome")).is_true()
	assert_bool(fu.is_biome_completed("empty_biome")).is_false()


func test_tr024_is_biome_completed_false_when_highest_below_count() -> void:
	# Guard 3: highest_cleared must equal BIOME_FLOOR_COUNT[biome].
	# 3 of 5 cleared → not completed.
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	var us: Dictionary[String, int] = {"forest_reach": 3}
	var fu: Node = _make_fu(bfc, us)

	assert_bool(fu.is_biome_completed("forest_reach")).is_false()


func test_tr024_is_biome_completed_true_when_all_guards_pass() -> void:
	# All 5 floors cleared in the 5-floor biome → completed.
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	var us: Dictionary[String, int] = {"forest_reach": 5}
	var fu: Node = _make_fu(bfc, us)

	assert_bool(fu.is_biome_completed("forest_reach")).is_true()


func test_tr024_is_biome_completed_false_when_highest_zero_on_completable_biome() -> void:
	# Boundary: highest=0 on a 5-floor biome → not completed (no progress).
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	var us: Dictionary[String, int] = {"forest_reach": 0}
	var fu: Node = _make_fu(bfc, us)

	assert_bool(fu.is_biome_completed("forest_reach")).is_false()


# ---------------------------------------------------------------------------
# TR-020: stale biome_id preserved in _unlock_state but filtered via
# is_biome_available
# ---------------------------------------------------------------------------

func test_tr020_stale_biome_id_preserved_in_unlock_state_dict() -> void:
	# Arrange — _unlock_state has a stale "removed_biome" entry that's NOT in
	# BIOME_FLOOR_COUNT (e.g., authored before the biome was removed from the
	# active set in DataRegistry).
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	var us: Dictionary[String, int] = {"forest_reach": 2, "removed_biome": 3}
	var fu: Node = _make_fu(bfc, us)

	# Assert — the stale entry is STILL in _unlock_state (not auto-purged)
	assert_bool(fu._unlock_state.has("removed_biome")).is_true()
	assert_int(fu._unlock_state["removed_biome"]).is_equal(3)


func test_tr020_stale_biome_id_filtered_via_is_biome_available() -> void:
	# The is_biome_available filter is the load-bearing surface that hides
	# stale entries from the UI (per the spec: stale entries are dormant).
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	var us: Dictionary[String, int] = {"forest_reach": 2, "removed_biome": 3}
	var fu: Node = _make_fu(bfc, us)

	# Assert — is_biome_available correctly filters
	assert_bool(fu.is_biome_available("forest_reach")).is_true()
	assert_bool(fu.is_biome_available("removed_biome")).is_false()


func test_tr020_stale_biome_excluded_from_get_available_biomes() -> void:
	# Round-trip: get_available_biomes reads from BIOME_FLOOR_COUNT, NOT from
	# _unlock_state, so the stale entry is naturally excluded.
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	var us: Dictionary[String, int] = {"forest_reach": 2, "removed_biome": 3}
	var fu: Node = _make_fu(bfc, us)

	var result: Array[String] = fu.get_available_biomes()
	assert_int(result.size()).is_equal(1)
	assert_bool(result.has("forest_reach")).is_true()
	assert_bool(result.has("removed_biome")).is_false()


func test_tr020_stale_biome_is_biome_completed_returns_false() -> void:
	# Even if the stale entry has highest_cleared > 0, is_biome_completed
	# returns false because is_biome_available filters it out.
	var bfc: Dictionary[String, int] = {"forest_reach": 5}
	var us: Dictionary[String, int] = {"forest_reach": 2, "removed_biome": 3}
	var fu: Node = _make_fu(bfc, us)

	assert_bool(fu.is_biome_completed("removed_biome")).is_false()
