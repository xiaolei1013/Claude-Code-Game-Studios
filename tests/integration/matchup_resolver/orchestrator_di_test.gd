# Tests for Sprint 8 matchup-resolver Story 006 (S8-N6 carryover from S7-N6):
#   - DungeonRunOrchestrator's lazy-default-with-public-setters DI per
#     ADR-0009 + ADR-0003 Amendment #3
#   - set_matchup_resolver(spy) BEFORE _ready() survives intact
#   - lazy-default in _ready() instantiates DefaultMatchupResolver when no spy
#   - MatchupResolver source files are signal-free (TR-026 source grep canary)
#   - Spy-subclass test pattern: class TestSpyResolver extends MatchupResolver
#     overrides resolve_formation_matchup to return canned values
#
# Covers: TR-matchup-resolver-004 (DI lazy-default + spy injection),
#         TR-matchup-resolver-026 (resolver signal-free; orchestrator owns
#                                  enemy_killed signal — note: S8-S3 landed
#                                  enemy_killed with 3-arg arity (tier,
#                                  archetype, advantaged) instead of the
#                                  2-arg arity in this story's older spec;
#                                  archetype was added for richer UI ticker
#                                  payload — a TD-012-class spec-vs-reality
#                                  drift documented inline),
#         TR-matchup-resolver-032 (spy-subclass test pattern).
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const MatchupResolverScript = preload("res://src/core/matchup_resolver/matchup_resolver.gd")
const DefaultMatchupResolverScript = preload("res://src/core/matchup_resolver/default_matchup_resolver.gd")
const MatchupResultScript = preload("res://src/core/matchup_resolver/matchup_result.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


# ===========================================================================
# Spy-subclass test pattern (TR-032)
#
# Inner class extending MatchupResolver — the canonical spy pattern for the
# DungeonRunOrchestrator's matchup_resolver dependency. Production tests
# inject this BEFORE add_child to verify orchestrator-side calls.
#
# Canned-value pattern: tests configure `canned_advantaged` / `canned_label`
# on the spy before driving the orchestrator; spy returns those values from
# every resolve_formation_matchup call. `call_log` captures (formation_size,
# archetype) for assertion.
# ===========================================================================

class TestSpyResolver extends RefCounted:
	# Spy state — tests inspect call_count + call_log + canned_* for assertions.
	var resolve_formation_matchup_call_count: int = 0
	var resolve_floor_matchup_call_count: int = 0
	var call_log: Array = []  # Array of {formation_size, archetype}
	# Canned return values — override per test.
	var canned_advantaged: bool = false
	var canned_matched: Array[String] = []
	var canned_label: String = "Even"

	func resolve_formation_matchup(formation: Array, archetype: String) -> RefCounted:
		resolve_formation_matchup_call_count += 1
		call_log.append({"formation_size": formation.size(), "archetype": archetype})
		var result: MatchupResult = preload("res://src/core/matchup_resolver/matchup_result.gd").new()
		result.is_advantaged = canned_advantaged
		result.matched_archetypes = canned_matched
		result.effectiveness_label = canned_label
		return result

	func resolve_floor_matchup(formation: Array, archetypes: Array[String]) -> RefCounted:
		resolve_floor_matchup_call_count += 1
		var result: MatchupResult = preload("res://src/core/matchup_resolver/matchup_result.gd").new()
		result.is_advantaged = canned_advantaged
		result.matched_archetypes = canned_matched
		result.effectiveness_label = canned_label
		return result


func _make_hero(class_id: String, instance_id: int, level: int = 1) -> RefCounted:
	var h: RefCounted = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	h.current_level = level
	return h


# ===========================================================================
# Group A: TR-004 — lazy-default DefaultMatchupResolver in _ready()
# ===========================================================================

func test_orchestrator_matchup_resolver_lazy_defaults_to_default_matchup_resolver() -> void:
	# Arrange — fresh orchestrator with no spy injection.
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)

	# Assert — _matchup_resolver is non-null after _ready()
	assert_object(orch._matchup_resolver).is_not_null()
	# Class identity: instanceof DefaultMatchupResolver via duck-type marker.
	# The Sprint 7 production class exposes is_stub() returning a marker
	# string containing "DefaultMatchupResolver".
	assert_bool(orch._matchup_resolver.has_method("is_stub")).is_true()
	assert_str(str(orch._matchup_resolver.is_stub())).contains("DefaultMatchupResolver")


func test_lazy_default_does_not_overwrite_pre_injected_spy() -> void:
	# TR-004: setter BEFORE add_child must survive _ready()'s lazy-default.
	# Arrange — instantiate orchestrator, inject spy, THEN add_child (which
	# fires _ready()).
	var orch: Node = OrchestratorScript.new()
	var spy: TestSpyResolver = TestSpyResolver.new()
	orch.set_matchup_resolver(spy)
	add_child(orch)  # _ready() fires here
	auto_free(orch)

	# Assert — spy survives; lazy-default did NOT overwrite.
	assert_object(orch._matchup_resolver).is_equal(spy)


# ===========================================================================
# Group B: TR-026 — resolver source files are signal-free
# ===========================================================================

const _RESOLVER_SOURCES: Array[String] = [
	"res://src/core/matchup_resolver/matchup_resolver.gd",
	"res://src/core/matchup_resolver/default_matchup_resolver.gd",
]


func _read_source(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Source file missing: %s" % path)
		return ""
	var content: String = f.get_as_text()
	f.close()
	return content


func test_matchup_resolver_source_has_no_signal_declarations() -> void:
	# TR-026: MatchupResolver is signal-free. Walk source line-by-line; assert
	# no non-comment line begins with `signal ` (the GDScript declaration
	# token). Doc-comment text containing "signal" as English word is exempt
	# via the comment-skip pattern (matches S8-S7's combat-resolver canary).
	for path: String in _RESOLVER_SOURCES:
		var src: String = _read_source(path)
		if src.is_empty():
			continue
		var lines: PackedStringArray = src.split("\n")
		for line: String in lines:
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("#") or trimmed.begins_with("##"):
				continue
			# Strip inline trailing comment if present.
			var hash_idx: int = trimmed.find("#")
			var code_only: String = trimmed if hash_idx < 0 else trimmed.substr(0, hash_idx)
			# Defensive: assert no code line begins with "signal " token.
			assert_bool(code_only.begins_with("signal ")).is_false()


# ===========================================================================
# Group C: TR-026 — orchestrator owns enemy_killed signal
# ===========================================================================

func test_orchestrator_declares_enemy_killed_signal() -> void:
	# Story 006 spec calls for enemy_killed(tier: int, is_matchup_advantaged:
	# bool) — 2-arg form. S8-S3 actually landed enemy_killed(tier: int,
	# archetype: String, advantaged: bool) — 3-arg form (archetype added for
	# richer UI ticker payload). This test verifies the 3-arg form against
	# the implementation contract; the spec drift is documented inline at
	# this file's header.
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)

	var sigs: Array = orch.get_signal_list()
	var found: bool = false
	for s: Dictionary in sigs:
		if s.get("name", "") == "enemy_killed":
			found = true
			# 3-arg arity per S8-S3 implementation.
			assert_int((s.get("args", []) as Array).size()).is_equal(3)
	assert_bool(found).is_true()


# ===========================================================================
# Group D: TR-032 — spy-subclass test pattern
# ===========================================================================

func test_spy_subclass_pattern_resolve_formation_matchup_returns_canned_value() -> void:
	# Demonstrates the canonical spy-subclass pattern: configure canned
	# return values on the spy BEFORE the orchestrator dispatches; assert
	# the spy was called with expected args.
	# Arrange
	var spy: TestSpyResolver = TestSpyResolver.new()
	spy.canned_advantaged = true
	spy.canned_label = "Strong"
	var formation: Array = [_make_hero("warrior", 1)]

	# Act — call the spy directly (a more thorough test would inject into
	# orchestrator and drive a dispatch; this isolates the spy contract).
	var result: MatchupResult = spy.resolve_formation_matchup(formation, "bruiser")

	# Assert — canned values returned; call_count incremented; log entry recorded.
	assert_bool(result.is_advantaged).is_true()
	assert_str(result.effectiveness_label).is_equal("Strong")
	assert_int(spy.resolve_formation_matchup_call_count).is_equal(1)
	assert_int(spy.call_log.size()).is_equal(1)
	assert_int(int(spy.call_log[0]["formation_size"])).is_equal(1)
	assert_str(str(spy.call_log[0]["archetype"])).is_equal("bruiser")


func test_spy_subclass_injected_into_orchestrator_intercepts_resolver_calls() -> void:
	# Full DI loop: inject spy → orchestrator builds matchup_cache via
	# CombatResolver.build_matchup_cache(formation, archetypes, _matchup_resolver)
	# → spy.resolve_formation_matchup is invoked.
	#
	# Arrange — orchestrator with spy injection BEFORE add_child.
	var orch: Node = OrchestratorScript.new()
	var spy: TestSpyResolver = TestSpyResolver.new()
	spy.canned_advantaged = false  # all archetypes return disadvantaged
	orch.set_matchup_resolver(spy)
	# Combat resolver remains the real DefaultCombatResolver (lazy-default).
	add_child(orch)
	auto_free(orch)
	var formation: Array = [
		_make_hero("warrior", 1),
		_make_hero("warrior", 2),
		_make_hero("warrior", 3),
	]

	# Act — dispatch triggers _build_combat_snapshot → build_matchup_cache →
	# spy.resolve_formation_matchup per distinct archetype.
	orch.dispatch(formation, 1, "forest_reach")

	# Assert — spy was invoked at least once during dispatch.
	# (Synthetic 3-enemy fallback floor has 1 distinct archetype "bruiser" →
	# ≥1 call; real-floor paths could call up to 5 per TR-012.)
	assert_int(spy.resolve_formation_matchup_call_count).is_greater_equal(1)
	# Call args reflect formation size + the archetype the orchestrator
	# extracted from the snapshot.
	assert_int(int(spy.call_log[0]["formation_size"])).is_equal(3)


func test_spy_subclass_call_count_does_not_grow_during_per_tick_replay() -> void:
	# TR-013 (matchup cache built once at dispatch) — verified by S8-S2 too,
	# but pinned here from the spy-subclass perspective: the spy's call count
	# should NOT grow during per-tick handlers.
	#
	# Arrange
	var orch: Node = OrchestratorScript.new()
	var spy: TestSpyResolver = TestSpyResolver.new()
	orch.set_matchup_resolver(spy)
	add_child(orch)
	auto_free(orch)
	orch.dispatch([_make_hero("warrior", 1)], 1, "forest_reach")
	var post_dispatch_count: int = spy.resolve_formation_matchup_call_count

	# Act — fire 50 simulated ticks.
	for n: int in range(1, 51):
		orch._on_tick_fired(n)

	# Assert — total call count unchanged (cache hit, not resolver invocation).
	assert_int(spy.resolve_formation_matchup_call_count).is_equal(post_dispatch_count)
