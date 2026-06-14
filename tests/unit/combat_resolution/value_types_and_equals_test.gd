# Tests for Sprint 7 combat-resolution Story 001:
#   - CombatResolver base class (RefCounted, stateless, instance methods only)
#   - 4 value types (KillEvent, CombatTickEvents, CombatBatchResult,
#     CombatRunSnapshot) — each with equals() field-by-field deep comparison
#
# Covers: TR-combat-001 (CombatResolver class_name + RefCounted + stateless),
#         TR-combat-013 (KillEvent 5 fields + equals deep-equality),
#         TR-combat-014 (CombatTickEvents 3 fields + equals),
#         TR-combat-015 (CombatBatchResult 7 fields + equals),
#         TR-combat-016 (Dictionary equality via key-by-key dict_equals),
#         TR-combat-017 (Float fields compared via is_equal_approx),
#         TR-combat-028 (is_boss flag propagated regardless of position).
extends GdUnitTestSuite

const CombatResolverScript = preload("res://src/core/combat/combat_resolver.gd")
const KillEventScript = preload("res://src/core/combat/kill_event.gd")
const CombatTickEventsScript = preload("res://src/core/combat/combat_tick_events.gd")
const CombatBatchResultScript = preload("res://src/core/combat/combat_batch_result.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")


# ===========================================================================
# Group A: CombatResolver base — instantiation, RefCounted, stateless
# ===========================================================================

func test_combat_resolver_can_be_instantiated_via_new() -> void:
	var inst: RefCounted = CombatResolverScript.new()
	assert_object(inst).is_not_null()


func test_combat_resolver_is_refcounted_not_resource() -> void:
	var inst: RefCounted = CombatResolverScript.new()
	var as_object: Object = inst
	assert_bool(as_object is RefCounted).is_true()
	assert_bool(as_object is Resource).is_false()


func test_combat_resolver_class_name_resolves() -> void:
	var inst: CombatResolver = CombatResolverScript.new() as CombatResolver
	assert_object(inst).is_not_null()


func test_combat_resolver_source_has_zero_class_scope_vars() -> void:
	# Stateless invariant TR-001 + TR-027.
	var file: FileAccess = FileAccess.open("res://src/core/combat/combat_resolver.gd", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var lines: PackedStringArray = content.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		assert_bool(trimmed.begins_with("var ")).override_failure_message(
			"combat_resolver.gd contains class-scope var: '%s'" % trimmed
		).is_false()


func test_combat_resolver_source_has_zero_signal_declarations() -> void:
	# TR-030 reaffirmed: Combat emits no signals; orchestrator owns emission.
	var file: FileAccess = FileAccess.open("res://src/core/combat/combat_resolver.gd", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var lines: PackedStringArray = content.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		assert_bool(trimmed.begins_with("signal ")).override_failure_message(
			"combat_resolver.gd contains signal declaration: '%s'" % trimmed
		).is_false()


# ===========================================================================
# Group B: KillEvent — schema + defaults + equals (TR-013, TR-028)
# ===========================================================================

func test_kill_event_default_fields() -> void:
	var k: KillEvent = KillEventScript.new()
	assert_str(str(k.enemy_id)).is_equal("")
	assert_str(str(k.archetype)).is_equal("")
	assert_int(k.tier).is_equal(1)
	assert_bool(k.is_boss).is_false()
	assert_int(k.kill_tick).is_equal(0)


func test_kill_event_equals_field_by_field_match() -> void:
	var a: KillEvent = KillEventScript.new()
	a.enemy_id = &"goblin_a"
	a.archetype = &"bruiser"
	a.tier = 2
	a.is_boss = false
	a.kill_tick = 42

	var b: KillEvent = KillEventScript.new()
	b.enemy_id = &"goblin_a"
	b.archetype = &"bruiser"
	b.tier = 2
	b.is_boss = false
	b.kill_tick = 42

	assert_bool(a.equals(b)).is_true()


func test_kill_event_equals_returns_false_on_field_mismatch() -> void:
	var a: KillEvent = KillEventScript.new()
	a.enemy_id = &"goblin_a"
	a.kill_tick = 42

	var b: KillEvent = KillEventScript.new()
	b.enemy_id = &"goblin_a"
	b.kill_tick = 43  # different

	assert_bool(a.equals(b)).is_false()


func test_kill_event_equals_returns_false_against_null() -> void:
	var a: KillEvent = KillEventScript.new()
	assert_bool(a.equals(null)).is_false()


func test_kill_event_reference_different_field_equal_yields_equals_true() -> void:
	# RefCounted == is reference-equality. equals() is structural.
	var a: KillEvent = KillEventScript.new()
	a.kill_tick = 5
	var b: KillEvent = KillEventScript.new()
	b.kill_tick = 5
	assert_bool(a == b).is_false()  # reference-different
	assert_bool(a.equals(b)).is_true()  # field-equal


func test_kill_event_is_boss_flag_propagates_regardless_of_position() -> void:
	# TR-028: is_boss is a per-event field; not derived from queue position.
	var k1: KillEvent = KillEventScript.new()
	k1.is_boss = true
	var k2: KillEvent = KillEventScript.new()
	k2.is_boss = false
	# Both can coexist in the same kill schedule; equals() distinguishes them.
	assert_bool(k1.equals(k2)).is_false()


# ===========================================================================
# Group C: CombatTickEvents — schema + defaults + equals (TR-014)
# ===========================================================================

func test_combat_tick_events_default_fields() -> void:
	var e: CombatTickEvents = CombatTickEventsScript.new()
	assert_int(e.kills.size()).is_equal(0)
	assert_int(e.loop_completed_ticks.size()).is_equal(0)
	assert_bool(e.first_clear_in_range).is_false()


func test_combat_tick_events_equals_with_matching_kills_array() -> void:
	var k1: KillEvent = KillEventScript.new()
	k1.enemy_id = &"e1"
	k1.kill_tick = 10
	var k2: KillEvent = KillEventScript.new()
	k2.enemy_id = &"e1"
	k2.kill_tick = 10

	var a: CombatTickEvents = CombatTickEventsScript.new()
	a.kills = [k1]
	a.loop_completed_ticks = [10]
	a.first_clear_in_range = false

	var b: CombatTickEvents = CombatTickEventsScript.new()
	b.kills = [k2]  # reference-different but field-equal KillEvent
	b.loop_completed_ticks = [10]
	b.first_clear_in_range = false

	assert_bool(a.equals(b)).is_true()


func test_combat_tick_events_equals_returns_false_on_first_clear_mismatch() -> void:
	var a: CombatTickEvents = CombatTickEventsScript.new()
	a.first_clear_in_range = true
	var b: CombatTickEvents = CombatTickEventsScript.new()
	b.first_clear_in_range = false
	assert_bool(a.equals(b)).is_false()


func test_combat_tick_events_equals_returns_false_on_kills_size_mismatch() -> void:
	var k1: KillEvent = KillEventScript.new()
	var a: CombatTickEvents = CombatTickEventsScript.new()
	a.kills = [k1]
	var b: CombatTickEvents = CombatTickEventsScript.new()
	b.kills = []
	assert_bool(a.equals(b)).is_false()


func test_combat_tick_events_equals_returns_false_against_null() -> void:
	var a: CombatTickEvents = CombatTickEventsScript.new()
	assert_bool(a.equals(null)).is_false()


# ===========================================================================
# Group D: CombatBatchResult — schema + defaults + equals + dict_equals
# ===========================================================================

func test_combat_batch_result_default_fields() -> void:
	var r: CombatBatchResult = CombatBatchResultScript.new()
	assert_int(r.kills_by_archetype.size()).is_equal(0)
	assert_int(r.kills_by_tier.size()).is_equal(0)
	assert_int(r.loops_completed).is_equal(0)
	assert_int(r.first_clear_tick).is_equal(-1)
	assert_bool(r.won).is_true()
	assert_int(r.final_tick).is_equal(0)


func test_combat_batch_result_equals_field_by_field() -> void:
	var a: CombatBatchResult = CombatBatchResultScript.new()
	a.kills_by_archetype = {&"bruiser": 5, &"caster": 2}
	a.kills_by_tier = {1: 4, 2: 3}
	a.loops_completed = 3
	a.first_clear_tick = 100
	a.won = true
	a.final_tick = 500

	var b: CombatBatchResult = CombatBatchResultScript.new()
	b.kills_by_archetype = {&"bruiser": 5, &"caster": 2}
	b.kills_by_tier = {1: 4, 2: 3}
	b.loops_completed = 3
	b.first_clear_tick = 100
	b.won = true
	b.final_tick = 500

	assert_bool(a.equals(b)).is_true()


func test_combat_batch_result_dict_equals_static_helper() -> void:
	# TR-016 — Dictionary equality via key-by-key dict_equals (NOT hash).
	var a: Dictionary = {&"bruiser": 5, &"caster": 2}
	var b: Dictionary = {&"caster": 2, &"bruiser": 5}  # same content, different insertion order
	assert_bool(CombatBatchResultScript.dict_equals(a, b)).is_true()


func test_combat_batch_result_dict_equals_returns_false_on_size_mismatch() -> void:
	var a: Dictionary = {&"bruiser": 5}
	var b: Dictionary = {&"bruiser": 5, &"caster": 2}
	assert_bool(CombatBatchResultScript.dict_equals(a, b)).is_false()


func test_combat_batch_result_dict_equals_returns_false_on_value_mismatch() -> void:
	var a: Dictionary = {&"bruiser": 5}
	var b: Dictionary = {&"bruiser": 4}
	assert_bool(CombatBatchResultScript.dict_equals(a, b)).is_false()


func test_combat_batch_result_equals_returns_false_against_null() -> void:
	var r: CombatBatchResult = CombatBatchResultScript.new()
	assert_bool(r.equals(null)).is_false()


# ===========================================================================
# Group E: CombatRunSnapshot — schema + defaults + equals
# ===========================================================================

func test_combat_run_snapshot_default_fields() -> void:
	var s: CombatRunSnapshot = CombatRunSnapshotScript.new()
	assert_float(s.formation_dps_per_tick).is_equal_approx(0.0, 0.001)
	assert_int(s.formation_total_hp).is_equal(0)
	assert_int(s.matchup_cache.size()).is_equal(0)
	assert_int(s.enemy_list.size()).is_equal(0)
	assert_int(s.dispatched_at_tick).is_equal(0)
	assert_int(s.loops_per_run).is_equal(0)


func test_combat_run_snapshot_equals_field_by_field() -> void:
	var a: CombatRunSnapshot = CombatRunSnapshotScript.new()
	a.formation_dps_per_tick = 1.5
	a.formation_total_hp = 240
	a.matchup_cache = {&"bruiser": true}
	a.enemy_list = [{"id": &"e1", "tier": 1}]
	a.dispatched_at_tick = 100
	a.loops_per_run = 5

	var b: CombatRunSnapshot = CombatRunSnapshotScript.new()
	b.formation_dps_per_tick = 1.5
	b.formation_total_hp = 240
	b.matchup_cache = {&"bruiser": true}
	b.enemy_list = [{"id": &"e1", "tier": 1}]
	b.dispatched_at_tick = 100
	b.loops_per_run = 5

	assert_bool(a.equals(b)).is_true()


func test_combat_run_snapshot_equals_returns_false_on_dispatched_at_tick_mismatch() -> void:
	var a: CombatRunSnapshot = CombatRunSnapshotScript.new()
	a.dispatched_at_tick = 100
	var b: CombatRunSnapshot = CombatRunSnapshotScript.new()
	b.dispatched_at_tick = 101
	assert_bool(a.equals(b)).is_false()


func test_combat_run_snapshot_equals_returns_false_on_matchup_cache_mismatch() -> void:
	var a: CombatRunSnapshot = CombatRunSnapshotScript.new()
	a.matchup_cache = {&"bruiser": true}
	var b: CombatRunSnapshot = CombatRunSnapshotScript.new()
	b.matchup_cache = {&"bruiser": false}
	assert_bool(a.equals(b)).is_false()


func test_combat_run_snapshot_equals_returns_false_against_null() -> void:
	var s: CombatRunSnapshot = CombatRunSnapshotScript.new()
	assert_bool(s.equals(null)).is_false()
