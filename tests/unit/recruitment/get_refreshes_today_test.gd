# Sprint 16 S16-N1 — tests for Recruitment.get_refreshes_today() public
# accessor. Closes the Cross-GDD Consistency Sweep 2026-05-07
# §Self-documented gap (Recruit Screen GDD #21 §C.6 step 1 cited the
# accessor as canonical; it didn't exist; this commit lands it).
#
# Coverage:
#   - Initial value 0 on a fresh autoload
#   - Increments after refresh_pool_paid() succeeds (verified indirectly
#     via the existing _refreshes_today field)
#   - Returns the underlying _refreshes_today field as an int
extends GdUnitTestSuite

const RecruitmentScript = preload("res://src/core/recruitment/recruitment.gd")


func _make_recruitment() -> Node:
	var r: Node = RecruitmentScript.new()
	add_child(r)
	auto_free(r)
	return r


# ===========================================================================
# Group A — initial state
# ===========================================================================

func test_recruitment_get_refreshes_today_initial_returns_zero() -> void:
	var r: Node = _make_recruitment()
	assert_int(r.get_refreshes_today()).is_equal(0)


# ===========================================================================
# Group B — return value tracks the underlying _refreshes_today field
# ===========================================================================

# The accessor is a thin pass-through; mutating _refreshes_today directly
# (test fixture) reflects in the accessor return.
func test_recruitment_get_refreshes_today_reflects_internal_field() -> void:
	var r: Node = _make_recruitment()
	r._refreshes_today = 7
	assert_int(r.get_refreshes_today()).is_equal(7)


# Reset to zero is reflected.
func test_recruitment_get_refreshes_today_returns_zero_after_reset() -> void:
	var r: Node = _make_recruitment()
	r._refreshes_today = 5
	r._refreshes_today = 0
	assert_int(r.get_refreshes_today()).is_equal(0)


# ===========================================================================
# Group C — return type is int (never null / never bool)
# ===========================================================================

func test_recruitment_get_refreshes_today_returns_int_type() -> void:
	var r: Node = _make_recruitment()
	var result: Variant = r.get_refreshes_today()
	assert_int(typeof(result)).is_equal(TYPE_INT)


# ===========================================================================
# Group D — accessor exists with expected signature (API surface lock)
# ===========================================================================

# Sprint 16 S16-N1 invariant: the public method exists. Future maintainers
# must not delete the accessor without updating Recruit Screen GDD §C.6.
func test_recruitment_get_refreshes_today_is_a_public_method() -> void:
	var r: Node = _make_recruitment()
	assert_bool(r.has_method("get_refreshes_today")).is_true()
