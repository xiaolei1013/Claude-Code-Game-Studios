# Sprint 15 S15-N1 — tests for FormationAssignment.set_target /
# get_target accessor pair (Matchup Assignment Screen #23 OQ-23-4
# dependency).
#
# The Matchup Assignment Screen pushes the (biome_id, floor_index)
# selection back via FormationAssignment.set_target; the
# formation_assignment screen reads via get_target on its own
# on_enter to update the hard-coded biome+floor fields.
#
# Coverage:
#   - Initial state: empty Dictionary
#   - set_target with valid args populates the dict
#   - set_target rejects empty biome_id (push_warning + no-op)
#   - set_target rejects floor_index < 1 (push_warning + no-op)
#   - get_target returns a deep copy (caller mutation does not leak)
#   - Multiple set_target calls overwrite (last-write-wins)
#   - Field is NOT serialized in get_save_data (session-only)
extends GdUnitTestSuite

const FormationAssignmentScript = preload("res://src/core/formation_assignment/formation_assignment.gd")


func _make_fa() -> Node:
	var fa: Node = FormationAssignmentScript.new()
	add_child(fa)
	auto_free(fa)
	return fa


# ===========================================================================
# Group A — initial state empty
# ===========================================================================

func test_formation_assignment_matchup_target_initial_state_is_empty() -> void:
	var fa: Node = _make_fa()
	assert_dict(fa._matchup_target).is_empty()


func test_formation_assignment_get_target_initial_returns_empty_dict() -> void:
	var fa: Node = _make_fa()
	var target: Dictionary = fa.get_target()
	assert_dict(target).is_empty()


# ===========================================================================
# Group B — successful set_target captures
# ===========================================================================

func test_formation_assignment_set_target_captures_biome_and_floor() -> void:
	var fa: Node = _make_fa()
	fa.set_target("ashen_glade", 3)
	assert_dict(fa._matchup_target).is_not_empty()
	assert_str(String(fa._matchup_target.biome_id)).is_equal("ashen_glade")
	assert_int(int(fa._matchup_target.floor_index)).is_equal(3)


func test_formation_assignment_get_target_after_set_returns_populated_dict() -> void:
	var fa: Node = _make_fa()
	fa.set_target("forest_reach", 1)
	var target: Dictionary = fa.get_target()
	assert_dict(target).is_not_empty()
	assert_str(String(target.biome_id)).is_equal("forest_reach")
	assert_int(int(target.floor_index)).is_equal(1)


# ===========================================================================
# Group C — defensive rejection
# ===========================================================================

func test_formation_assignment_set_target_rejects_empty_biome_id() -> void:
	var fa: Node = _make_fa()
	# Establish a prior valid target.
	fa.set_target("forest_reach", 2)
	# Attempt with empty biome_id — push_warning + no-op.
	fa.set_target("", 5)
	# Prior target is preserved (no overwrite on rejection).
	assert_str(String(fa._matchup_target.biome_id)).is_equal("forest_reach")
	assert_int(int(fa._matchup_target.floor_index)).is_equal(2)


func test_formation_assignment_set_target_rejects_zero_floor_index() -> void:
	var fa: Node = _make_fa()
	fa.set_target("forest_reach", 2)
	fa.set_target("ashen_glade", 0)
	# Prior target preserved.
	assert_str(String(fa._matchup_target.biome_id)).is_equal("forest_reach")
	assert_int(int(fa._matchup_target.floor_index)).is_equal(2)


func test_formation_assignment_set_target_rejects_negative_floor_index() -> void:
	var fa: Node = _make_fa()
	fa.set_target("forest_reach", 2)
	fa.set_target("ashen_glade", -3)
	# Prior target preserved.
	assert_str(String(fa._matchup_target.biome_id)).is_equal("forest_reach")
	assert_int(int(fa._matchup_target.floor_index)).is_equal(2)


# ===========================================================================
# Group D — last-write-wins semantics
# ===========================================================================

func test_formation_assignment_set_target_overwrites_prior_target() -> void:
	var fa: Node = _make_fa()
	fa.set_target("forest_reach", 1)
	fa.set_target("ashen_glade", 4)
	# Latest write wins.
	assert_str(String(fa._matchup_target.biome_id)).is_equal("ashen_glade")
	assert_int(int(fa._matchup_target.floor_index)).is_equal(4)


# ===========================================================================
# Group E — get_target returns a deep copy
# ===========================================================================

func test_formation_assignment_get_target_returns_deep_copy() -> void:
	var fa: Node = _make_fa()
	fa.set_target("forest_reach", 2)

	var target: Dictionary = fa.get_target()
	# Mutate the returned copy.
	target.biome_id = "MUTATED"
	target.floor_index = 999

	# Cached target unchanged.
	assert_str(String(fa._matchup_target.biome_id)).is_equal("forest_reach")
	assert_int(int(fa._matchup_target.floor_index)).is_equal(2)


# ===========================================================================
# Group F — get_save_data does NOT include _matchup_target (session-only)
# ===========================================================================

# Per the GDD design floor: _matchup_target is session-only; cold-launch
# reads no target → formation_assignment falls back to hard-coded defaults.
func test_formation_assignment_get_save_data_does_not_persist_matchup_target() -> void:
	var fa: Node = _make_fa()
	fa.set_target("forest_reach", 5)
	var save_data: Dictionary = fa.get_save_data()
	# As of Formation Presets V1.0 the namespace carries the preset envelope
	# ("presets" + "next_preset_id"). The session-only _matchup_target must
	# still NOT leak into it — assert each target field is absent rather than
	# asserting the whole dict is empty.
	assert_bool(save_data.has("biome_id")).is_false()
	assert_bool(save_data.has("floor_index")).is_false()
	assert_bool(save_data.has("matchup_target")).is_false()
	assert_bool(save_data.has("target")).is_false()


# load_save_data is a no-op per existing MVP contract; verify that calling
# it does NOT clear the in-memory _matchup_target (the field's lifecycle
# is screen-driven, not save-driven).
func test_formation_assignment_load_save_data_does_not_clear_matchup_target() -> void:
	var fa: Node = _make_fa()
	fa.set_target("forest_reach", 5)
	fa.load_save_data({})
	# Target preserved.
	assert_str(String(fa._matchup_target.biome_id)).is_equal("forest_reach")
	assert_int(int(fa._matchup_target.floor_index)).is_equal(5)
