# Sprint 25 S25-M3-rev — DungeonRunOrchestrator.get_dispatched_floor_index test.
#
# Verifies the new public accessor exposes the same value as the existing
# private _dispatched_floor_index field. Used by DungeonRunView to pass the
# floor context to BiomeBackground.set_biome_for_floor for per-floor visual
# modulation (boss-floor darkening).
extends GdUnitTestSuite


func test_get_dispatched_floor_index_returns_zero_when_no_run_active() -> void:
	# Arrange — read live autoload state
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	assert_object(orch).is_not_null()

	# Reset internal state to simulate no-run-active for the test
	orch.set("_dispatched_floor_index", 0)

	# Act
	var floor_idx: int = orch.call("get_dispatched_floor_index") as int

	# Assert — the documented sentinel value
	assert_int(floor_idx).is_equal(0)


func test_get_dispatched_floor_index_reflects_private_field_value() -> void:
	# Arrange
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	var prev_value: int = int(orch.get("_dispatched_floor_index"))

	# Act — set the private field to a known floor (5 = boss) and read via API
	orch.set("_dispatched_floor_index", 5)
	var floor_idx: int = orch.call("get_dispatched_floor_index") as int

	# Assert — accessor returns the same value
	assert_int(floor_idx).is_equal(5)

	# Cleanup — restore the original value
	orch.set("_dispatched_floor_index", prev_value)


func test_get_dispatched_floor_index_handles_each_mvp_floor_range() -> void:
	# Arrange
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	var prev_value: int = int(orch.get("_dispatched_floor_index"))

	# Act + Assert across MVP floor range
	for floor_n: int in range(1, 6):
		orch.set("_dispatched_floor_index", floor_n)
		var got: int = orch.call("get_dispatched_floor_index") as int
		assert_int(got).is_equal(floor_n).override_failure_message(
			"Expected get_dispatched_floor_index() to return %d after setting field; got %d"
			% [floor_n, got]
		)

	# Cleanup
	orch.set("_dispatched_floor_index", prev_value)
