# Regression test for Sprint 18 post-S18-M4 wiring: losing_run is now
# computed from combat_snapshot.hp_bonus_factor via the combat resolver's
# `survived` predicate. Was always-false since S7-M13 because the
# orchestrator hardcoded hp_bonus_factor = 1.0.
#
# Player-facing significance: prior to this wiring, the LOSING_RUN_LOOT_FACTOR
# = 0.5 mechanic was dead code — every dispatch was a WIN. The S18-M4 playtest
# surfaced the question "do we have failed dispatch if defeated?" which led to
# discovering the unwired scaffolding. This test pins the wiring so the
# losing_run state can't silently regress back to always-false.
#
# Test isolation: uses a spy combat resolver that implements the three
# methods the wiring needs (formation_total_hp, hp_bonus_factor, survived)
# with controllable return values. This lets us pin the wiring contract
# without depending on real HeroClass / Floor resources.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")


# Spy combat resolver — implements the three methods the LOSING-run wiring
# needs (formation_total_hp + hp_bonus_factor + survived) plus the existing
# methods _build_combat_snapshot requires (formation_dps_per_tick,
# build_matchup_cache). Returns controllable values so each test pins one
# scenario.
class SpyCombatResolverWithHP extends RefCounted:
	var spy_formation_total_hp: int = 0
	var spy_hp_bonus_factor: float = 1.0
	var spy_survived: bool = true

	func formation_dps_per_tick(_formation: Array) -> float:
		return 1.0

	func formation_total_hp(_formation: Array, _error_logger: Callable = Callable()) -> int:
		return spy_formation_total_hp

	func hp_bonus_factor(_formation_hp: int, _enemy_attack: int) -> float:
		return spy_hp_bonus_factor

	func survived(_hp_bonus_factor_value: float) -> bool:
		return spy_survived

	func build_matchup_cache(_formation: Array, _archetypes: Array, _matchup_resolver: Variant) -> Dictionary:
		return {}

	# Required because dispatch() transitions to ACTIVE_FOREGROUND which
	# subscribes the orchestrator to TickSystem.tick_fired. If a tick fires
	# between dispatch and the assertion, the orchestrator calls
	# emit_events_in_range. Stub returns a no-op event payload so the
	# orchestrator's _process_kill_events sees an empty list (no kills,
	# no first-clear emit, no side effects).
	func emit_events_in_range(_snapshot: Variant, _tick_lo: int, _tick_hi: int) -> Variant:
		return {"events": [], "first_clear_in_range": false}


# Build a fresh orchestrator with the spy resolver injected.
func _make_orch_with_spy(spy: SpyCombatResolverWithHP) -> Node:
	var orch: Node = OrchestratorScript.new()
	orch.set_combat_resolver(spy)
	add_child(orch)
	auto_free(orch)
	return orch


# Minimal formation — three stub heroes with class_id + current_level.
# The spy resolver doesn't read these (returns canned hp values), but
# dispatch validates the formation is non-empty per AC-ORC-07.
func _stub_formation() -> Array:
	return [
		{"class_id": "warrior", "current_level": 1, "instance_id": 1},
		{"class_id": "mage", "current_level": 1, "instance_id": 2},
		{"class_id": "rogue", "current_level": 1, "instance_id": 3},
	]


# ===========================================================================
# Group A: LOSING-run condition wiring (post-S18-M4)
# ===========================================================================

func test_dispatch_sets_losing_run_true_when_survived_returns_false() -> void:
	# A formation with low HP versus a high-threat floor produces
	# hp_bonus_factor < 0.5 → survived = false → losing_run = true.
	var spy: SpyCombatResolverWithHP = SpyCombatResolverWithHP.new()
	spy.spy_formation_total_hp = 10  # weak formation
	spy.spy_hp_bonus_factor = 0.2  # 10 / 50 = 0.2 (well below the 0.5 threshold)
	spy.spy_survived = false
	var orch: Node = _make_orch_with_spy(spy)

	orch.dispatch(_stub_formation(), 1, "forest_reach")

	assert_object(orch.run_snapshot).is_not_null()
	assert_bool(orch.run_snapshot.losing_run).is_true()


func test_dispatch_sets_losing_run_false_when_survived_returns_true() -> void:
	# A formation with sufficient HP versus the floor produces
	# hp_bonus_factor >= 0.5 → survived = true → losing_run = false.
	var spy: SpyCombatResolverWithHP = SpyCombatResolverWithHP.new()
	spy.spy_formation_total_hp = 100  # strong formation
	spy.spy_hp_bonus_factor = 1.0  # saturated at the ceiling
	spy.spy_survived = true
	var orch: Node = _make_orch_with_spy(spy)

	orch.dispatch(_stub_formation(), 1, "forest_reach")

	assert_object(orch.run_snapshot).is_not_null()
	assert_bool(orch.run_snapshot.losing_run).is_false()


func test_dispatch_sets_losing_run_false_at_inclusive_boundary() -> void:
	# Pin the 0.5 inclusive boundary contract per TR-009: hp_bonus_factor == 0.5
	# counts as survived (NOT losing). This is the boundary the explicit-bool
	# field semantics in dungeon-run-orchestrator.md §B4 protect against
	# float drift on save/load.
	var spy: SpyCombatResolverWithHP = SpyCombatResolverWithHP.new()
	spy.spy_formation_total_hp = 25
	spy.spy_hp_bonus_factor = 0.5  # exactly the boundary
	spy.spy_survived = true  # 0.5 counts as survived (inclusive)
	var orch: Node = _make_orch_with_spy(spy)

	orch.dispatch(_stub_formation(), 1, "forest_reach")

	assert_object(orch.run_snapshot).is_not_null()
	assert_bool(orch.run_snapshot.losing_run).is_false()


# ===========================================================================
# Group B: hp_bonus_factor is propagated to the combat snapshot
# ===========================================================================

func test_combat_snapshot_carries_real_hp_bonus_factor_not_placeholder() -> void:
	# Pre-fix: the orchestrator hardcoded snap.hp_bonus_factor = 1.0
	# unconditionally. Post-fix: the snapshot carries the resolver-computed
	# value. This test pins the propagation so a future refactor can't silently
	# regress to the always-1.0 placeholder.
	var spy: SpyCombatResolverWithHP = SpyCombatResolverWithHP.new()
	spy.spy_formation_total_hp = 30
	spy.spy_hp_bonus_factor = 0.75
	spy.spy_survived = true
	var orch: Node = _make_orch_with_spy(spy)

	orch.dispatch(_stub_formation(), 1, "forest_reach")

	assert_object(orch._combat_snapshot).is_not_null()
	assert_float(orch._combat_snapshot.hp_bonus_factor).is_equal_approx(0.75, 0.001)


# ===========================================================================
# Group C: backward-compat — resolvers without the new methods leave losing_run false
# ===========================================================================

class SpyResolverMinimal extends RefCounted:
	# Spies without formation_total_hp / hp_bonus_factor / survived.
	# This is the pre-Sprint-18 spy shape (only formation_dps_per_tick + build_matchup_cache).
	func formation_dps_per_tick(_formation: Array) -> float:
		return 1.0

	func build_matchup_cache(_formation: Array, _archetypes: Array, _matchup_resolver: Variant) -> Dictionary:
		return {}


func test_dispatch_keeps_losing_run_false_when_resolver_lacks_survived() -> void:
	# Defensive: existing tests use minimal spies that don't implement
	# `survived`. The post-S18-M4 wiring guards via has_method() so those
	# tests don't regress — losing_run stays at the RunSnapshot default false.
	var minimal_spy: SpyResolverMinimal = SpyResolverMinimal.new()
	var orch: Node = OrchestratorScript.new()
	orch.set_combat_resolver(minimal_spy)
	add_child(orch)
	auto_free(orch)

	orch.dispatch(_stub_formation(), 1, "forest_reach")

	assert_object(orch.run_snapshot).is_not_null()
	assert_bool(orch.run_snapshot.losing_run).is_false()
