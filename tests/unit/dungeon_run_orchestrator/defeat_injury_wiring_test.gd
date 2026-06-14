# Tests for GDD #34 Phase 3 (Defeat & Injury System / ADR-0021): the orchestrator
# wiring that INJURES the dispatched formation when a foreground run is DEFEATED
# (AC-34-04/05). Companion to defeat_wiring_test.gd (which covers the zero-loot /
# run_defeated side); this suite covers _end_run_defeated -> _apply_defeat_injuries
# -> HeroRoster.injure_heroes.
#
# Injury wiring contract:
#   - Every hero in run_snapshot.formation_snapshot.instance_ids is injured to a
#     wall-clock recovery instant = TickSystem.now_ms() + injury_recovery_seconds*1000.
#   - Injuries are applied BEFORE run_defeated is emitted (subscribers see the
#     injured roster).
#   - A WINNING run never injures (control).
#   - Empty/absent formation ids → safe no-op.
#
# These tests mutate the LIVE /root/HeroRoster autoload, so they snapshot+restore
# it via HeroRosterTestFixture (memory: feedback_test_isolation_live_autoload).
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")


# Spy resolver — proves a winning-run control never injures while still calling
# combat normally.
class _SpyCombatResolver extends RefCounted:
	func emit_events_in_range(_snapshot: Variant, _tick_lo: int, _tick_hi: int) -> Variant:
		return null


var _roster_snapshot: Dictionary = {}


func before_test() -> void:
	_roster_snapshot = HeroRosterFixture.snapshot_via_save_data()
	HeroRosterFixture.reset_hero_roster()


func after_test() -> void:
	HeroRosterFixture.restore_via_load_save_data(_roster_snapshot)


# Returns the live HeroRoster autoload, or null if absent (lean test env).
func _roster() -> Node:
	return get_tree().root.get_node_or_null("HeroRoster")


# Inject a synthetic HeroInstance straight into the live roster's _heroes —
# bypasses DataRegistry so the test stays independent of class registration.
func _inject_hero(roster: Node, id: int) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = "warrior"
	fake.display_name = "Test Hero %d" % id
	fake.current_level = 1
	fake.injured_until = 0
	roster._heroes[id] = fake
	return fake


func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


# Builds a run_snapshot whose formation_snapshot freezes the given ids, mirroring
# what _build_run_snapshot produces at dispatch.
func _snapshot_with_ids(ids: Array) -> RunSnapshot:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.floor_id = "forest_reach_dungeon_01_floor_1"
	snap.current_tick = 0
	snap.last_emitted_tick = 0
	snap.formation_snapshot = {"instance_ids": ids, "heroes": []}
	return snap


# ===========================================================================
# Group A: _end_run_defeated injures the dispatched formation (AC-34-04)
# ===========================================================================

func test_defeat_injures_every_formation_hero() -> void:
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var h1: RefCounted = _inject_hero(roster, 1)
	var h2: RefCounted = _inject_hero(roster, 2)
	var h3: RefCounted = _inject_hero(roster, 3)

	var orch: Node = _make_orch()
	orch.run_snapshot = _snapshot_with_ids([1, 2, 3])

	var before_ms: int = TickSystem.now_ms()
	orch._end_run_defeated()
	var after_ms: int = TickSystem.now_ms()

	var recovery_ms: int = int(roster.injury_recovery_seconds()) * 1000
	# Each hero's recovery instant must sit in [before+recovery, after+recovery].
	for hero: RefCounted in [h1, h2, h3]:
		assert_int(hero.injured_until).is_greater_equal(before_ms + recovery_ms)
		assert_int(hero.injured_until).is_less_equal(after_ms + recovery_ms)
		# And the query agrees the hero is injured right now.
		assert_bool(roster.is_hero_injured(int(hero.instance_id), after_ms)).is_true()


func test_defeat_recovery_instant_uses_config_seconds() -> void:
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var h1: RefCounted = _inject_hero(roster, 1)

	var orch: Node = _make_orch()
	orch.run_snapshot = _snapshot_with_ids([1])

	var before_ms: int = TickSystem.now_ms()
	orch._end_run_defeated()

	# injured_until - before ≈ injury_recovery_seconds * 1000 (default 1800s).
	var recovery_ms: int = int(roster.injury_recovery_seconds()) * 1000
	var elapsed_offset: int = h1.injured_until - before_ms
	assert_int(elapsed_offset).is_greater_equal(recovery_ms)
	# A generous upper bound guards against an accidental double-scale (×1000²).
	assert_int(elapsed_offset).is_less(recovery_ms + 60_000)


func test_defeat_injures_before_emitting_run_defeated() -> void:
	# Ordering guarantee: a run_defeated subscriber must already see the injured
	# roster when the signal fires (model mutated before notification).
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	_inject_hero(roster, 1)

	var orch: Node = _make_orch()
	orch.run_snapshot = _snapshot_with_ids([1])
	orch._dispatched_floor_index = 2
	orch._dispatched_biome_id = "forest_reach"

	var injured_at_emit: Array = [false]
	orch.run_defeated.connect(
		func(_floor_index: int, _biome_id: String) -> void:
			injured_at_emit[0] = roster.is_hero_injured(1, TickSystem.now_ms())
	)
	orch._end_run_defeated()
	assert_bool(injured_at_emit[0]).is_true()


# ===========================================================================
# Group B: integrated tick path — reaching the defeat tick injures (AC-34-04)
# ===========================================================================

func test_tick_reaching_defeat_tick_injures_formation() -> void:
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var h1: RefCounted = _inject_hero(roster, 1)

	var orch: Node = _make_orch()
	orch.run_snapshot = _snapshot_with_ids([1])
	orch._run_won = false
	orch._run_defeat_tick = 5
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	# Ticks before the defeat tick: still healthy.
	for n: int in [1, 2, 3, 4]:
		orch._on_tick_fired(n)
	assert_bool(roster.is_hero_injured(1, TickSystem.now_ms())).is_false()

	# Reaching the defeat tick triggers _end_run_defeated → injury.
	orch._on_tick_fired(5)
	assert_bool(roster.is_hero_injured(1, TickSystem.now_ms())).is_true()
	assert_int(h1.injured_until).is_greater(0)


# ===========================================================================
# Group C: controls — win never injures; empty/unknown ids are safe no-ops
# ===========================================================================

func test_winning_run_does_not_injure() -> void:
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var h1: RefCounted = _inject_hero(roster, 1)

	var orch: Node = _make_orch()
	orch.set_combat_resolver(_SpyCombatResolver.new())
	orch.run_snapshot = _snapshot_with_ids([1])
	orch._run_won = true  # WIN path never routes through _end_run_defeated
	orch._set_state(DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	orch._on_tick_fired(5)
	assert_bool(roster.is_hero_injured(1, TickSystem.now_ms())).is_false()
	assert_int(h1.injured_until).is_equal(0)


func test_defeat_with_empty_formation_snapshot_is_noop() -> void:
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var h1: RefCounted = _inject_hero(roster, 1)

	var orch: Node = _make_orch()
	# Snapshot present but no formation ids → injury wiring is a safe no-op.
	orch.run_snapshot = _snapshot_with_ids([])
	orch._end_run_defeated()
	assert_int(h1.injured_until).is_equal(0)


func test_defeat_with_unknown_id_does_not_crash() -> void:
	# A frozen id that no longer exists in the roster (desync) is tolerated:
	# injure_heroes skips it; the present hero is still injured.
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var h1: RefCounted = _inject_hero(roster, 1)

	var orch: Node = _make_orch()
	orch.run_snapshot = _snapshot_with_ids([1, 999])  # 999 is unknown
	orch._end_run_defeated()
	assert_bool(roster.is_hero_injured(1, TickSystem.now_ms())).is_true()
	assert_bool(roster.is_hero_injured(999, TickSystem.now_ms())).is_false()
	assert_int(h1.injured_until).is_greater(0)
