# CI guard: SaveLoadSystem consumer contract.
#
# Every entry in SaveLoadSystem.CONSUMER_PATHS must:
#   1. Resolve to a live Node at the given autoload path.
#   2. Expose a `get_save_data()` method returning a Dictionary.
#   3. Expose a `load_save_data(d: Dictionary)` method.
#   4. Round-trip: feeding get_save_data() output back into load_save_data()
#      must not crash and must not produce push_errors.
#
# Why this exists: each consumer has its own round-trip test (and they all
# pass at sprint-15 close), but there is no single test asserting the global
# contract for the canonical CONSUMER_PATHS list. If a future PR adds an
# entry to CONSUMER_PATHS but forgets to implement the two methods,
# SaveLoadSystem would crash on the first persist attempt — at runtime, in
# production. This test catches it at CI time.
#
# Mirrors the audit done at Sprint 15 close: 8 consumers, all contract-
# compliant. The codebase is clean; this test locks the invariant.
extends GdUnitTestSuite

const SaveLoadSystemScript = preload("res://src/core/save_load_system/save_load_system.gd")


# ---------------------------------------------------------------------------
# Test 1 — Every consumer path resolves AND exposes both methods
# ---------------------------------------------------------------------------

func test_every_consumer_path_resolves_and_exposes_both_save_methods() -> void:
	var paths: PackedStringArray = SaveLoadSystemScript.CONSUMER_PATHS
	assert_int(paths.size()).override_failure_message(
		"CONSUMER_PATHS is empty — test infrastructure broken or list moved"
	).is_greater_equal(1)

	var violations: Array[String] = []
	for path: String in paths:
		var node: Node = get_tree().root.get_node_or_null(path)
		if node == null:
			violations.append("%s does not resolve to a live Node" % path)
			continue
		if not node.has_method("get_save_data"):
			violations.append("%s missing get_save_data() method" % path)
		if not node.has_method("load_save_data"):
			violations.append("%s missing load_save_data(d) method" % path)

	if not violations.is_empty():
		for v: String in violations:
			push_error(v)
	assert_int(violations.size()).override_failure_message(
		"%d CONSUMER_PATHS contract violation(s); see push_errors. Fix by either "
		+ "implementing the missing method or removing the path from CONSUMER_PATHS."
		% violations.size()
	).is_equal(0)


# ---------------------------------------------------------------------------
# Test 2 — get_save_data must return a Dictionary (not null, not Variant)
# ---------------------------------------------------------------------------

func test_every_consumer_get_save_data_returns_dictionary() -> void:
	var paths: PackedStringArray = SaveLoadSystemScript.CONSUMER_PATHS
	var violations: Array[String] = []
	for path: String in paths:
		var node: Node = get_tree().root.get_node_or_null(path)
		if node == null or not node.has_method("get_save_data"):
			# Test 1 catches these; skip here.
			continue
		var result: Variant = node.call("get_save_data")
		if not (result is Dictionary):
			violations.append(
				"%s.get_save_data() returned type %d (expected Dictionary / TYPE_DICTIONARY=27)"
				% [path, typeof(result)]
			)

	if not violations.is_empty():
		for v: String in violations:
			push_error(v)
	assert_int(violations.size()).override_failure_message(
		"%d consumer(s) returned non-Dictionary from get_save_data; see push_errors"
		% violations.size()
	).is_equal(0)


# ---------------------------------------------------------------------------
# Test 3 — Round-trip self-feed: get_save_data → load_save_data must not crash
# ---------------------------------------------------------------------------

# Snapshot each consumer's state before the round-trip, restore after.
# Catches the regression where load_save_data mishandles its own output
# (e.g., a typed-array assignment regression per project memory
# `project_typed_collection_test_fixtures`).
func test_every_consumer_self_feed_round_trip_does_not_crash() -> void:
	var paths: PackedStringArray = SaveLoadSystemScript.CONSUMER_PATHS
	var violations: Array[String] = []
	for path: String in paths:
		var node: Node = get_tree().root.get_node_or_null(path)
		if node == null or not node.has_method("get_save_data") or not node.has_method("load_save_data"):
			continue
		# Snapshot.
		var snapshot: Dictionary = node.call("get_save_data") as Dictionary
		# Self-feed.
		# If this crashes via push_error, the test infrastructure catches it
		# as a test failure (gdunit converts push_error to test fail by default).
		node.call("load_save_data", snapshot)
		# Re-snapshot — should still produce a Dictionary.
		var after: Variant = node.call("get_save_data")
		if not (after is Dictionary):
			violations.append(
				"%s: post-self-feed get_save_data returned non-Dictionary (type=%d)"
				% [path, typeof(after)]
			)

	if not violations.is_empty():
		for v: String in violations:
			push_error(v)
	assert_int(violations.size()).is_equal(0)
