# Story 015 — calm-surface reduce_motion wiring guard (structural source test).
#
# ClassSpriteFactory.animate() grew a `reduce_motion` 4th param (§C.8 + the binding
# ui-code rule "all animations respect motion prefs"). The factory unit test proves
# the param freezes the idle; the recruit integration test proves ONE surface threads
# it. This test closes the gap for the OTHER three: it asserts EVERY calm portrait
# surface passes `_is_reduce_motion_enabled()` INTO its animate() call — not merely
# that the helper exists somewhere in the file.
#
# This is the in-engine equivalent of grepping each surface for a reduce_motion arg
# inside the animate() parens. The fragility IS the feature: the dominant bug class in
# this project is "scaffolded-but-unwired" (a call site silently drops the new arg and
# falls back to the default). If any of these four call sites loses the flag, the
# portrait would loop under reduce_motion and this test fails in CI — before a human
# ever has to notice the violation in a playtest.
#
# The dungeon in-scene slot (dungeon_run_view) is intentionally NOT in this list: it
# leaves reduce_motion at the default and gates its idle EXTERNALLY (Story 010's
# _set_party_idle_animating freeze), so it correctly uses the 3-arg call.
extends GdUnitTestSuite

# The four calm portrait/thumbnail surfaces that animate a hero idle and must
# therefore honour reduce_motion by threading the per-surface accessibility read.
const CALM_SURFACES: Array[String] = [
	"res://assets/screens/recruitment/recruitment.gd",
	"res://assets/screens/hero_detail/hero_detail_modal.gd",
	"res://assets/screens/codex/codex_modal.gd",
	"res://assets/screens/start_menu/start_menu.gd",
]

# The call token (the preloaded factory const is `ClassSpriteFactoryScript` in every
# surface) and the accessibility-read token expected inside the call's argument list.
const ANIMATE_CALL: String = "ClassSpriteFactoryScript.animate("
const REDUCE_MOTION_ARG: String = "_is_reduce_motion_enabled"


# Reads a file with comment-only lines removed, so a doc comment that mentions
# `ClassSpriteFactory.animate()` can never be mistaken for the real call.
func _read_code_only(file_path: String) -> String:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var out: String = ""
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.strip_edges().begins_with("#"):
			continue
		out += line + "\n"
	file.close()
	return out


# Returns the substring spanning a single `animate( ... )` call starting at
# [param call_start] (the index of ANIMATE_CALL), by walking forward and matching
# the opening paren to its close with depth counting. Returns "" if unbalanced.
func _extract_call_args(code: String, call_start: int) -> String:
	var open_paren: int = code.find("(", call_start)
	if open_paren == -1:
		return ""
	var depth: int = 0
	var i: int = open_paren
	while i < code.length():
		var ch: String = code[i]
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0:
				return code.substr(open_paren, i - open_paren + 1)
		i += 1
	return ""


func test_every_calm_surface_threads_reduce_motion_into_animate_call() -> void:
	# Sanity: the list is non-empty (guards against an accidental empty constant
	# vacuously passing the per-surface loop below).
	assert_int(CALM_SURFACES.size()).is_equal(4)

	for surface: String in CALM_SURFACES:
		var code: String = _read_code_only(surface)
		# The surface file must exist and be readable.
		assert_str(code).override_failure_message(
			"Calm surface not readable: %s" % surface).is_not_empty()

		# It must contain a real (non-comment) animate() call.
		var call_start: int = code.find(ANIMATE_CALL)
		assert_int(call_start).override_failure_message(
			"%s has no ClassSpriteFactoryScript.animate( call" % surface).is_greater_equal(0)

		# And the accessibility read must appear INSIDE that call's argument list —
		# i.e. it is PASSED to animate(), not merely defined elsewhere in the file.
		var call_args: String = _extract_call_args(code, call_start)
		assert_str(call_args).override_failure_message(
			"%s animate() call has unbalanced parens" % surface).is_not_empty()
		assert_bool(call_args.contains(REDUCE_MOTION_ARG)).override_failure_message(
			"%s does not pass %s into its animate() call — reduce_motion unwired (§C.8)"
			% [surface, REDUCE_MOTION_ARG]).is_true()


func test_every_calm_surface_defines_the_reduce_motion_helper() -> void:
	# Companion guard: the threaded arg must resolve to a real method. Each surface
	# defines its own `func _is_reduce_motion_enabled()` (the factory stays autoload-
	# free; the read lives at the surface, re-evaluated per render — §E.6).
	for surface: String in CALM_SURFACES:
		var code: String = _read_code_only(surface)
		assert_bool(code.contains("func _is_reduce_motion_enabled(")).override_failure_message(
			"%s threads _is_reduce_motion_enabled() but does not define it" % surface).is_true()
