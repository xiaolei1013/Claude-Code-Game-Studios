# Sprint 8 S8-N3 (matchup-resolver Story 008 / TR-matchup-resolver-033):
# field-by-field equality helper for MatchupResult.
#
# RefCounted equality (`==`) in Godot 4.x is REFERENCE equality — two
# MatchupResult instances with byte-identical fields will compare unequal
# unless they're the same object reference. Tests that compare resolver
# outputs from separate calls MUST use this helper.
#
# Usage in tests:
#   const MatchResultEq = preload("res://tests/fixtures/match_result_eq.gd")
#   var a := resolver.resolve_formation_matchup(...)
#   var b := resolver.resolve_formation_matchup(...)
#   assert_bool(MatchResultEq.match_result_equals(a, b)).is_true()
#
# Why a helper instead of `MatchupResult.equals()` method:
#   The MatchupResult value type is intentionally minimal (no behavior); the
#   equality semantic lives in test fixtures so the production class stays
#   pure-data. Compare with CombatBatchResult which does have its own
#   equals() — that's a heavier value type that owns its parity contract.
class_name MatchResultEq


## Field-by-field equality for [MatchupResult]. Returns true iff `a` and `b`
## are both null OR both non-null with byte-equal field contents. Comparing
## one null and one non-null returns false.
##
## Field comparison order (cheapest first):
##   1. is_advantaged (bool — direct ==)
##   2. effectiveness_label (String — direct ==)
##   3. matched_archetypes (Array[String] — element-by-element via Godot's
##      Array `==` which IS structural for typed arrays of primitives)
##
## TR-matchup-resolver-033 — ADR-0009
static func match_result_equals(a: RefCounted, b: RefCounted) -> bool:
	if a == null and b == null:
		return true
	if a == null or b == null:
		return false
	# Duck-type the three fields. Returning false on any field mismatch lets
	# the assertion failure message stay informative when callers wrap this
	# with `assert_bool(...)`.
	if not ("is_advantaged" in a and "is_advantaged" in b):
		return false
	if bool(a.get("is_advantaged")) != bool(b.get("is_advantaged")):
		return false
	if not ("effectiveness_label" in a and "effectiveness_label" in b):
		return false
	if str(a.get("effectiveness_label")) != str(b.get("effectiveness_label")):
		return false
	if not ("matched_archetypes" in a and "matched_archetypes" in b):
		return false
	# Array[String] structural equality via Godot's `==` (per Godot 4.x docs:
	# typed Arrays of primitives compare element-by-element).
	var a_arch: Array = a.get("matched_archetypes") as Array
	var b_arch: Array = b.get("matched_archetypes") as Array
	if a_arch.size() != b_arch.size():
		return false
	for i: int in range(a_arch.size()):
		if str(a_arch[i]) != str(b_arch[i]):
			return false
	return true
