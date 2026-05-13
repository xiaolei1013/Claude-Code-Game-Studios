# S15-S3 — Recruitment save/load round-trip integration test.
#
# AC-RC-13: get_save_data() / load_save_data() preserve the 3-field
# Recruitment payload (save_pool_seed, refresh_counter, current_pool)
# across the SaveLoadSystem JSON envelope round-trip.
#
# Unit-level round-trip is already covered in
# tests/unit/recruitment/recruitment_skeleton_test.gd:233 (dict-to-dict).
# This integration test adds the JSON-mangled-types path: JSON.parse_string
# returns numeric values as TYPE_FLOAT and Dictionary keys as String — the
# production code path through SaveLoadSystem's envelope. Recruitment's
# load_save_data must coerce these back to the typed shape (per project
# memory `project_json_int_round_trip_typeof_pattern`).
#
# Mirrors the pattern in tests/integration/economy/economy_save_load_round_trip_test.gd
# Test 13.
#
# S15-S3 — Sprint 15.
extends GdUnitTestSuite

const RecruitmentScript = preload("res://src/core/recruitment/recruitment.gd")


# ---------------------------------------------------------------------------
# Helper — fresh Recruitment instance (NOT the live autoload). Mirrors
# recruitment_skeleton_test._make_recruitment.
# ---------------------------------------------------------------------------

func _make_recruitment() -> Node:
	var r: Node = RecruitmentScript.new()
	add_child(r)
	auto_free(r)
	return r


# ===========================================================================
# Test 1 — JSON round-trip preserves seed/counter/pool through type coercion
# ===========================================================================

# Author state on instance A, serialize via JSON.stringify, parse back via
# JSON.parse_string, hand the JSON-mangled dict to instance B's load_save_data.
# Asserts that B's typed state matches A's — i.e., load_save_data coerced
# the JSON-mangled types correctly.
func test_load_save_data_after_json_round_trip_coerces_float_back_to_int() -> void:
	# Arrange — author state on instance A.
	var source: Node = _make_recruitment()
	var pool: Array[String] = ["warrior", "mage", "rogue"]
	source._save_pool_seed = 4242
	source._refresh_counter = 7
	source._current_pool = pool

	# Act — serialize through JSON to simulate the SaveLoadSystem envelope.
	var data: Dictionary = source.get_save_data()
	var json_str: String = JSON.stringify(data)
	var round_tripped: Variant = JSON.parse_string(json_str)
	assert_object(round_tripped).is_not_null()
	var rt_dict: Dictionary = round_tripped as Dictionary

	# Sanity — JSON coerced numeric values to TYPE_FLOAT (guards against
	# future Godot JSON behavior changes that would invalidate the
	# load_save_data coercion logic).
	assert_int(typeof(rt_dict["save_pool_seed"])).override_failure_message(
		"JSON.parse_string should coerce ints to TYPE_FLOAT — got type %d. "
		+ "If this assertion changes, the load_save_data int(...) cast may be unneeded."
		% typeof(rt_dict["save_pool_seed"])
	).is_equal(TYPE_FLOAT)

	# Act — hand the JSON-mangled dict to a fresh instance.
	var dest: Node = _make_recruitment()
	dest.load_save_data(rt_dict)

	# Assert — typed state restored exactly.
	assert_int(dest._save_pool_seed).is_equal(4242)
	assert_int(dest._refresh_counter).is_equal(7)
	assert_int(dest._current_pool.size()).is_equal(3)
	assert_str(dest._current_pool[0]).is_equal("warrior")
	assert_str(dest._current_pool[1]).is_equal("mage")
	assert_str(dest._current_pool[2]).is_equal("rogue")


# ===========================================================================
# Test 2 — Empty JSON envelope (first-launch path) seeds a fresh state
# ===========================================================================

# A fresh save file has no Recruitment namespace yet, so
# SaveLoadSystem hands an empty dict. load_save_data must initialize
# save_pool_seed via the first-launch path (randi) and regenerate the pool.
func test_empty_json_envelope_triggers_first_launch_init() -> void:
	# Arrange — JSON-encode + decode an empty dict.
	var empty_data: Dictionary = {}
	var json_str: String = JSON.stringify(empty_data)
	var rt: Variant = JSON.parse_string(json_str)
	assert_object(rt).is_not_null()

	# Act.
	var r: Node = _make_recruitment()
	r._save_pool_seed = 0  # ensure we observe the first-launch init effect
	r.load_save_data(rt as Dictionary)

	# Assert — first-launch path ran: seed is non-zero, counter is 0.
	assert_int(r._save_pool_seed).override_failure_message(
		"Empty envelope should trigger first-launch seed init (randi), got 0"
	).is_not_equal(0)
	assert_int(r._refresh_counter).is_equal(0)


# ===========================================================================
# Test 3 — JSON round-trip with non-Recruitment keys ignores them silently
# ===========================================================================

# Forward-compat invariant: a future Recruitment GDD might add fields. An
# OLD client loading a NEW save (with unknown keys) must ignore them
# silently — not crash, not warn. This test verifies the forward-compat
# contract through the JSON path.
func test_json_round_trip_with_unknown_keys_is_forward_compatible() -> void:
	# Arrange — author a known payload PLUS an unknown future-field key.
	var future_data: Dictionary = {
		"save_pool_seed": 100,
		"refresh_counter": 2,
		"current_pool": ["warrior", "mage"],
		"hypothetical_future_field": "ignore_me",
	}
	var json_str: String = JSON.stringify(future_data)
	var rt: Variant = JSON.parse_string(json_str)

	# Act.
	var r: Node = _make_recruitment()
	r.load_save_data(rt as Dictionary)

	# Assert — known fields loaded; unknown field caused no crash.
	assert_int(r._save_pool_seed).is_equal(100)
	assert_int(r._refresh_counter).is_equal(2)
	assert_int(r._current_pool.size()).is_equal(2)


# ===========================================================================
# Test 4 — JSON round-trip filters non-string pool entries (anti-tamper)
# ===========================================================================

# A tampered or upgraded save might inject non-string entries into the
# current_pool array. The per-element type-guard in load_save_data must
# survive the JSON-mangled path the same way it survives direct dict input.
func test_json_round_trip_filters_non_string_pool_entries() -> void:
	# Arrange — current_pool with mixed types. After JSON round-trip,
	# integer 42 becomes TYPE_FLOAT (which is still non-String).
	var tampered: Dictionary = {
		"save_pool_seed": 50,
		"refresh_counter": 0,
		"current_pool": ["warrior", 42, "mage"],
	}
	var json_str: String = JSON.stringify(tampered)
	var rt: Variant = JSON.parse_string(json_str)

	# Act.
	var r: Node = _make_recruitment()
	r.load_save_data(rt as Dictionary)

	# Assert — non-string entries filtered out; string entries survive.
	assert_int(r._current_pool.size()).override_failure_message(
		"Expected 2 surviving string entries, got %d" % r._current_pool.size()
	).is_equal(2)
	assert_str(r._current_pool[0]).is_equal("warrior")
	assert_str(r._current_pool[1]).is_equal("mage")
