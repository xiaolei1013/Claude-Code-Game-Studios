# US-016 (test-coverage-backfill): persist-timestamp accessor round-trip coverage.
#
# Closes the public-API audit gap on TickSystem's persist-timestamp accessors.
# Pre-existing coverage:
#   - tick_system_autoload_skeleton_test.gd asserts zero-on-construction for
#     get_last_persist_ts / get_session_high_water and "no-error" smoke for the
#     setters — that is edge-case + structural coverage only.
#   - platform_notifications_bg_fg_pause_residual_preservation_test.gd asserts
#     the post-_on_backgrounded snapshot via the PRIVATE field (`_last_persist_unix`),
#     not via the public getter — it does not validate that the public getter
#     returns the snapshot value.
#
# Gap closed by this suite (per EPIC.md FR-2 / FR-3 + tests/PATTERNS.md):
#   - Setter→getter round-trip happy paths for both accessors.
#   - Independence: writes to one accessor do not bleed into the other.
#   - Boundary: setting to 0 (re-zeroing after a non-zero write) returns 0.
#   - No-max-applied invariant: set_session_high_water DOES NOT apply max();
#     a later smaller write overwrites a larger value (the doc comment makes
#     this caller-responsibility explicit — the test pins the invariant so a
#     well-meaning refactor that adds max() inside the setter would fail loudly).
#   - Repeated writes: last-writer-wins on both accessors (no accumulator drift).
#
# ADR-0005 §"Two clocks" — caller restrictions are documented, not enforced.
# Tests instantiate via `TickSystemScript.new()` and call the methods directly.
extends GdUnitTestSuite

const TickSystemScript = preload("res://src/core/tick_system/tick_system.gd")


# ---------------------------------------------------------------------------
# Group A — set_last_persist_ts ↔ get_last_persist_ts round-trip
# ---------------------------------------------------------------------------

func test_set_last_persist_ts_then_get_returns_same_value() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	const STAMP: int = 1_714_000_000  # plausible Unix seconds value

	# Act
	ts.set_last_persist_ts(STAMP)
	var result: int = ts.get_last_persist_ts()

	# Assert
	assert_int(result).is_equal(STAMP)


func test_set_last_persist_ts_overwrites_previous_value_no_accumulation() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	auto_free(ts)

	# Act — last-writer-wins; the value is replaced, not accumulated.
	ts.set_last_persist_ts(1_000_000_000)
	ts.set_last_persist_ts(2_000_000_000)
	var result: int = ts.get_last_persist_ts()

	# Assert
	assert_int(result).is_equal(2_000_000_000)


func test_set_last_persist_ts_to_zero_after_nonzero_returns_zero() -> void:
	# Arrange — boundary: re-zeroing the persist timestamp must round-trip cleanly.
	var ts: Node = TickSystemScript.new()
	auto_free(ts)

	# Act
	ts.set_last_persist_ts(1_714_000_000)
	ts.set_last_persist_ts(0)
	var result: int = ts.get_last_persist_ts()

	# Assert
	assert_int(result).is_equal(0)


# ---------------------------------------------------------------------------
# Group B — set_session_high_water ↔ get_session_high_water round-trip
# ---------------------------------------------------------------------------

func test_set_session_high_water_then_get_returns_same_value() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	auto_free(ts)
	const STAMP: int = 1_714_000_000

	# Act
	ts.set_session_high_water(STAMP)
	var result: int = ts.get_session_high_water()

	# Assert
	assert_int(result).is_equal(STAMP)


func test_set_session_high_water_does_not_apply_max_smaller_overwrites_larger() -> void:
	# Arrange — pin the documented invariant: set_session_high_water DOES NOT
	# apply max(); the max-preserving logic lives in _on_backgrounded(). A future
	# refactor that adds max() inside the setter must fail this test loudly so
	# that the corresponding doc comment in tick_system.gd L327-329 is updated
	# in the same patch.
	var ts: Node = TickSystemScript.new()
	auto_free(ts)

	# Act
	ts.set_session_high_water(2_000_000_000)
	ts.set_session_high_water(1_000_000_000)  # smaller; overwrites
	var result: int = ts.get_session_high_water()

	# Assert
	assert_int(result).is_equal(1_000_000_000)


func test_set_session_high_water_to_zero_after_nonzero_returns_zero() -> void:
	# Arrange — boundary: caller may re-zero the high water (e.g., test fixture
	# reset). Round-trip must be clean.
	var ts: Node = TickSystemScript.new()
	auto_free(ts)

	# Act
	ts.set_session_high_water(1_714_000_000)
	ts.set_session_high_water(0)
	var result: int = ts.get_session_high_water()

	# Assert
	assert_int(result).is_equal(0)


# ---------------------------------------------------------------------------
# Group C — independence: the two accessors do not share storage
# ---------------------------------------------------------------------------

func test_set_last_persist_ts_does_not_affect_session_high_water() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	auto_free(ts)

	# Act
	ts.set_last_persist_ts(1_714_000_000)

	# Assert — session_high_water still cold-start zero
	assert_int(ts.get_session_high_water()).is_equal(0)
	assert_int(ts.get_last_persist_ts()).is_equal(1_714_000_000)


func test_set_session_high_water_does_not_affect_last_persist_ts() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	auto_free(ts)

	# Act
	ts.set_session_high_water(1_714_000_000)

	# Assert — last_persist_ts still cold-start zero
	assert_int(ts.get_last_persist_ts()).is_equal(0)
	assert_int(ts.get_session_high_water()).is_equal(1_714_000_000)
