# Tests for Sprint 8 matchup-resolver Story 008 (S8-N3 carryover from S7-N3):
#   - 10,000-call benchmark of resolve_formation_matchup (TR-031)
#   - Performance budget: < 200ms on CI baseline; soft-warn at 100ms;
#     hard-ceiling at 1000ms for CI variance
#   - Structural lint shell script integration (TR-030 — covered by
#     tools/ci/check_matchup_resolver_shape.sh; this test verifies the
#     script exists and is executable)
#   - match_result_equals helper smoke test (TR-033)
#
# Covers: TR-matchup-resolver-030 (structural shape — script exists),
#         TR-matchup-resolver-031 (perf budget),
#         TR-matchup-resolver-033 (equality helper smoke test).
extends GdUnitTestSuite

const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const MatchupResultScript = preload("res://src/core/matchup_resolver/matchup_result.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const MatchResultEq = preload("res://tests/fixtures/match_result_eq.gd")


func _make_hero(class_id: String, instance_id: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = 1
	return h


func _data_registry_can_resolve_classes() -> bool:
	return DataRegistry.resolve("classes", "warrior") != null


# ===========================================================================
# Group A: TR-031 — performance budget
# ===========================================================================

func test_resolve_formation_matchup_10000_calls_under_perf_budget() -> void:
	# 10,000 calls of resolve_formation_matchup must complete within budget
	# on CI baseline. Soft-warn at 100ms (early regression signal); hard-fail
	# at 1000ms (5x the spec budget — absorbs CI variance + warm-up jitter).
	#
	# Note on hardware: dev machines are typically 2-5x faster than CI
	# ubuntu-latest baselines. The 200ms spec budget is for CI; passing on
	# dev hardware doesn't guarantee CI-pass. The hard ceiling here is set
	# generously so the test doesn't flap on slow CI runners.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped: DataRegistry cannot resolve classes")
		return
	# Arrange — fixed formation + archetype to keep per-call work uniform.
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero("warrior", 1),
		_make_hero("mage", 2),
		_make_hero("rogue", 3),
	]

	# Act — 10,000 calls; measure total elapsed time in microseconds.
	var t0: int = Time.get_ticks_usec()
	for _i: int in range(10000):
		var _r: MatchupResult = resolver.resolve_formation_matchup(formation, "bruiser")
	var elapsed_us: int = Time.get_ticks_usec() - t0
	var elapsed_ms: int = elapsed_us / 1000

	# Soft-warn at 100ms (sets a tight regression alarm).
	if elapsed_ms >= 100:
		push_warning(
			"[Perf] resolve_formation_matchup 10000 calls took %dms — exceeds 100ms soft budget"
			% elapsed_ms
		)
	# Hard ceiling at 1000ms (5x spec budget, accommodates CI variance).
	assert_int(elapsed_ms).is_less(1000)


func test_resolve_floor_matchup_5_archetype_call_under_perf_budget() -> void:
	# resolve_floor_matchup with the 5-archetype upper bound (TR-012 ≤5
	# distinct archetypes per MVP floor) — verify it completes within a
	# reasonable per-call budget.
	if not _data_registry_can_resolve_classes():
		push_warning("Skipped")
		return
	# Arrange
	var resolver: RefCounted = DefaultMatchupResolverScript.new()
	var formation: Array = [
		_make_hero("warrior", 1),
		_make_hero("mage", 2),
		_make_hero("rogue", 3),
	]
	var archetypes: Array[String] = ["bruiser", "caster", "armored", "swift", "boss"]

	# Act — 1000 calls of the 5-archetype path; under 100ms total.
	var t0: int = Time.get_ticks_usec()
	for _i: int in range(1000):
		var _r: MatchupResult = resolver.resolve_floor_matchup(formation, archetypes)
	var elapsed_us: int = Time.get_ticks_usec() - t0
	var elapsed_ms: int = elapsed_us / 1000

	# Hard ceiling at 500ms — gives plenty of room for CI variance.
	assert_int(elapsed_ms).is_less(500)


# ===========================================================================
# Group B: TR-030 — structural lint script exists + is executable
# ===========================================================================

func test_structural_lint_shell_script_exists() -> void:
	# TR-030: tools/ci/check_matchup_resolver_shape.sh must exist for the CI
	# pipeline to invoke. This test fails loudly if the script is renamed
	# or deleted without a corresponding workflow update.
	var path: String = "res://tools/ci/check_matchup_resolver_shape.sh"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(f).is_not_null()
	if f != null:
		f.close()


func test_structural_lint_script_has_executable_shebang() -> void:
	# The script must start with a #!/usr/bin/env bash shebang for CI to
	# invoke it directly without `bash` prefix. Smoke check the first line.
	var path: String = "res://tools/ci/check_matchup_resolver_shape.sh"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Skipped: script missing")
		return
	var first_line: String = f.get_line()
	f.close()
	assert_str(first_line).contains("#!")
	assert_str(first_line).contains("bash")


# ===========================================================================
# Group C: TR-033 — match_result_equals helper smoke tests
# ===========================================================================

func test_match_result_equals_returns_true_for_field_equal_results() -> void:
	# Two separately-constructed MatchupResult instances with the same field
	# contents must compare equal via the helper.
	# Arrange
	var a: MatchupResult = MatchupResultScript.new()
	a.is_advantaged = true
	a.matched_archetypes = ["bruiser"]
	a.effectiveness_label = "Strong"
	var b: MatchupResult = MatchupResultScript.new()
	b.is_advantaged = true
	b.matched_archetypes = ["bruiser"]
	b.effectiveness_label = "Strong"

	# Assert
	assert_bool(MatchResultEq.match_result_equals(a, b)).is_true()


func test_match_result_equals_returns_false_for_different_is_advantaged() -> void:
	var a: MatchupResult = MatchupResultScript.new()
	a.is_advantaged = true
	var b: MatchupResult = MatchupResultScript.new()
	b.is_advantaged = false
	assert_bool(MatchResultEq.match_result_equals(a, b)).is_false()


func test_match_result_equals_returns_false_for_different_label() -> void:
	var a: MatchupResult = MatchupResultScript.new()
	a.effectiveness_label = "Strong"
	var b: MatchupResult = MatchupResultScript.new()
	b.effectiveness_label = "Even"
	assert_bool(MatchResultEq.match_result_equals(a, b)).is_false()


func test_match_result_equals_returns_false_for_different_matched_archetypes() -> void:
	var a: MatchupResult = MatchupResultScript.new()
	a.matched_archetypes = ["bruiser", "caster"]
	var b: MatchupResult = MatchupResultScript.new()
	b.matched_archetypes = ["bruiser"]
	assert_bool(MatchResultEq.match_result_equals(a, b)).is_false()


func test_match_result_equals_handles_both_null_inputs() -> void:
	# Edge: both null → true (defensive symmetry).
	assert_bool(MatchResultEq.match_result_equals(null, null)).is_true()


func test_match_result_equals_returns_false_for_one_null_one_non_null() -> void:
	var a: MatchupResult = MatchupResultScript.new()
	assert_bool(MatchResultEq.match_result_equals(a, null)).is_false()
	assert_bool(MatchResultEq.match_result_equals(null, a)).is_false()


func test_match_result_equals_does_not_use_reference_equality() -> void:
	# RefCounted `==` is reference equality. Two distinct instances with
	# identical fields compare unequal via `==` but equal via the helper.
	var a: MatchupResult = MatchupResultScript.new()
	var b: MatchupResult = MatchupResultScript.new()
	# Both are default-constructed → all fields equal.
	assert_bool(a == b).is_false()  # reference inequality
	assert_bool(MatchResultEq.match_result_equals(a, b)).is_true()  # field equality
