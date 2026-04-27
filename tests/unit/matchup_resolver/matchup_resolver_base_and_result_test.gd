# Tests for Sprint 7 matchup-resolver Story 001:
#   - MatchupResolver base class (RefCounted, stateless, instance methods only).
#   - MatchupResult value type (2 typed fields).
#
# Covers: TR-matchup-resolver-001 (class_name MatchupResolver extends RefCounted),
#         TR-matchup-resolver-002 (instance methods, NOT static — class is
#                                   instantiable via .new()),
#         TR-matchup-resolver-005 / TR-030 (zero class-scope vars + zero
#                                            signals — structural shape lint),
#         TR-matchup-resolver-006 (MatchupResult value type with 2 fields),
#         TR-matchup-resolver-007 (matched_archetypes typed `Array[String]` —
#                                   compile-time exclusion of HeroInstance/int).
extends GdUnitTestSuite

const MatchupResolverScript = preload("res://src/core/matchup_resolver/matchup_resolver.gd")
const MatchupResultScript = preload("res://src/core/matchup_resolver/matchup_result.gd")


# ===========================================================================
# Group A: TR-001 / TR-002 — MatchupResolver instantiable, RefCounted
# ===========================================================================

func test_matchup_resolver_can_be_instantiated_via_new() -> void:
	var inst: RefCounted = MatchupResolverScript.new()
	assert_object(inst).is_not_null()


func test_matchup_resolver_is_refcounted_not_resource() -> void:
	# RefCounted lifecycle is automatic — never .free() resolver instances.
	# NOT a Resource (.tres) — resolver is logic, not data.
	var inst: RefCounted = MatchupResolverScript.new()
	var as_object: Object = inst
	assert_bool(as_object is RefCounted).is_true()
	assert_bool(as_object is Resource).is_false()


func test_matchup_resolver_class_name_resolves() -> void:
	# The class_name registry should resolve MatchupResolver as a known type.
	var inst: MatchupResolver = MatchupResolverScript.new() as MatchupResolver
	assert_object(inst).is_not_null()


# ===========================================================================
# Group B: TR-005 / TR-030 — structural shape (zero vars, zero signals)
# ===========================================================================

func test_matchup_resolver_source_has_zero_class_scope_vars() -> void:
	# Stateless invariant: source must not contain any `var ` declarations
	# at file scope (excluding doc-comments which start with `##`).
	var file: FileAccess = FileAccess.open("res://src/core/matchup_resolver/matchup_resolver.gd", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var lines: PackedStringArray = content.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		# Reject any non-comment line declaring a class-scope var.
		assert_bool(trimmed.begins_with("var ")).override_failure_message(
			"matchup_resolver.gd contains a class-scope var declaration: '%s'" % trimmed
		).is_false()


func test_matchup_resolver_source_has_zero_signal_declarations() -> void:
	# Stateless invariant: zero signals (TR-030 + TR-026 — Orchestrator owns
	# all signal emission to Economy/UI; resolver is signal-free).
	var file: FileAccess = FileAccess.open("res://src/core/matchup_resolver/matchup_resolver.gd", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var lines: PackedStringArray = content.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		assert_bool(trimmed.begins_with("signal ")).override_failure_message(
			"matchup_resolver.gd contains a signal declaration: '%s'" % trimmed
		).is_false()


func test_matchup_resolver_source_has_no_static_func_on_public_api() -> void:
	# Public API is instance methods only (TR-002). Private static helpers
	# (e.g., `_is_class_counter` if Story 002 chooses to make it static)
	# may be permitted IF underscore-prefixed.
	#
	# Lint walks the file line-by-line skipping comments — naive
	# `content.contains("static func")` would false-positive on doc-comments
	# that mention the phrase (e.g., "must contain no static func declarations").
	var file: FileAccess = FileAccess.open("res://src/core/matchup_resolver/matchup_resolver.gd", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var lines: PackedStringArray = content.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		assert_bool(trimmed.begins_with("static func")).override_failure_message(
			"matchup_resolver.gd line declares static func: '%s'" % trimmed
		).is_false()


func test_matchup_resolver_get_property_list_has_no_class_scope_data() -> void:
	# Runtime structural check: get_property_list() should return zero
	# class-scope `var` entries beyond the engine's defaults (script_path,
	# global_class, etc., which are NOT user vars).
	var inst: RefCounted = MatchupResolverScript.new()
	var user_vars: Array[String] = []
	for prop: Dictionary in inst.get_property_list():
		var prop_name: String = prop.get("name", "")
		var usage: int = prop.get("usage", 0)
		# Filter to user-defined script vars: usage flag PROPERTY_USAGE_SCRIPT_VARIABLE = 4096
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and not prop_name.begins_with("_"):
			user_vars.append(prop_name)
	assert_int(user_vars.size()).override_failure_message(
		"MatchupResolver should have zero user-script vars; found: %s" % str(user_vars)
	).is_equal(0)


# ===========================================================================
# Group C: TR-006 — MatchupResult schema
# ===========================================================================

func test_matchup_result_can_be_instantiated_via_new() -> void:
	var r: MatchupResult = MatchupResultScript.new()
	assert_object(r).is_not_null()


func test_matchup_result_is_refcounted() -> void:
	var r: MatchupResult = MatchupResultScript.new()
	var as_object: Object = r
	assert_bool(as_object is RefCounted).is_true()
	assert_bool(as_object is Resource).is_false()


func test_matchup_result_default_is_advantaged_is_false() -> void:
	var r: MatchupResult = MatchupResultScript.new()
	assert_bool(r.is_advantaged).is_false()


func test_matchup_result_default_matched_archetypes_is_empty_array() -> void:
	var r: MatchupResult = MatchupResultScript.new()
	assert_int(r.matched_archetypes.size()).is_equal(0)


# ===========================================================================
# Group D: TR-007 — matched_archetypes is typed Array[String]
# ===========================================================================

func test_matchup_result_matched_archetypes_accepts_strings() -> void:
	var r: MatchupResult = MatchupResultScript.new()
	r.matched_archetypes.append("bruiser")
	r.matched_archetypes.append("caster")
	assert_int(r.matched_archetypes.size()).is_equal(2)
	assert_str(r.matched_archetypes[0]).is_equal("bruiser")
	assert_str(r.matched_archetypes[1]).is_equal("caster")


func test_matchup_result_is_advantaged_can_be_set_to_true() -> void:
	var r: MatchupResult = MatchupResultScript.new()
	r.is_advantaged = true
	assert_bool(r.is_advantaged).is_true()
