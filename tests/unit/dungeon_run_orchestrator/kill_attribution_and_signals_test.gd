# Tests for Sprint 8 dungeon-run-orchestrator Story 006 (S8-S3 carryover from S7-S5):
#   - attribute_kill_gold(tier, advantaged, losing_run) formula
#   - 4 owned signals: enemy_killed / boss_killed / floor_cleared_first_time /
#     validation_failed (the last was already declared in Story 003)
#   - Per-kill emission: enemy_killed once per kill, boss_killed when is_boss
#   - first_clear once-per-dispatch gating via run_snapshot.floor_clear_emitted
#   - Economy.add_gold routing for kill attribution
#
# Covers: TR-orchestrator-014 (kill-gold formula),
#         TR-orchestrator-018 (Economy.add_gold routing; orchestrator pre-applies
#                              losing_run loot factor),
#         TR-orchestrator-022 (boss_killed fires regardless of queue position;
#                              floor_cleared_first_time gated by floor_clear_emitted),
#         TR-orchestrator-025 (4 owned signals declared with exact arity).
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const KillEventScript = preload("res://src/core/combat/kill_event.gd")
const CombatTickEventsScript = preload("res://src/core/combat/combat_tick_events.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")


func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


func _make_kill_event(tier: int, archetype: StringName, is_boss: bool = false,
		enemy_id: StringName = &"e1", kill_tick: int = 1) -> RefCounted:
	var ke: KillEvent = KillEventScript.new()
	ke.tier = tier
	ke.archetype = archetype
	ke.is_boss = is_boss
	ke.enemy_id = enemy_id
	ke.kill_tick = kill_tick
	return ke


func _make_tick_events(kills: Array[KillEvent], first_clear: bool = false) -> RefCounted:
	var ev: CombatTickEvents = CombatTickEventsScript.new()
	ev.kills = kills
	ev.first_clear_in_range = first_clear
	return ev


# Spy state for signal verification.
var _spy_enemy_killed_calls: Array = []  # Array of {tier, archetype, advantaged}
var _spy_boss_killed_calls: Array = []   # Array of enemy_id strings
var _spy_floor_cleared_calls: Array = [] # Array of {floor_index, biome_id, losing_run}
var _spy_validation_failed_calls: Array = []


func _on_enemy_killed(tier: int, archetype: String, advantaged: bool) -> void:
	_spy_enemy_killed_calls.append({"tier": tier, "archetype": archetype, "advantaged": advantaged})


func _on_boss_killed(enemy_id: String) -> void:
	_spy_boss_killed_calls.append(enemy_id)


func _on_floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool) -> void:
	_spy_floor_cleared_calls.append({
		"floor_index": floor_index,
		"biome_id": biome_id,
		"losing_run": losing_run,
	})


func _on_validation_failed(reason: String, payload: Dictionary) -> void:
	_spy_validation_failed_calls.append({"reason": reason, "payload": payload})


func _reset_spies() -> void:
	_spy_enemy_killed_calls.clear()
	_spy_boss_killed_calls.clear()
	_spy_floor_cleared_calls.clear()
	_spy_validation_failed_calls.clear()


# ===========================================================================
# Group A: TR-014 — attribute_kill_gold formula
# ===========================================================================

func test_attribute_kill_gold_tier1_advantaged_winning_returns_7() -> void:
	# floori(5 * 1.5 * 1.0) = floori(7.5) = 7
	var orch: Node = _make_orch()
	assert_int(orch.attribute_kill_gold(1, true, false)).is_equal(7)


func test_attribute_kill_gold_tier1_disadvantaged_winning_returns_3() -> void:
	# floori(5 * 0.7 * 1.0) = floori(3.5) = 3
	var orch: Node = _make_orch()
	assert_int(orch.attribute_kill_gold(1, false, false)).is_equal(3)


func test_attribute_kill_gold_tier5_advantaged_losing_returns_75() -> void:
	# floori(100 * 1.5 * 0.5) = 75
	var orch: Node = _make_orch()
	assert_int(orch.attribute_kill_gold(5, true, true)).is_equal(75)


func test_attribute_kill_gold_unmapped_tier_returns_zero() -> void:
	# Unmapped tier (e.g., tier=99) → BASE_KILL.get returns 0 → 0 gold.
	var orch: Node = _make_orch()
	assert_int(orch.attribute_kill_gold(99, true, false)).is_equal(0)


func test_attribute_kill_gold_disadvantaged_losing_halves_again() -> void:
	# tier=2: floori(10 * 0.7 * 0.5) = floori(3.5) = 3
	var orch: Node = _make_orch()
	assert_int(orch.attribute_kill_gold(2, false, true)).is_equal(3)


# ===========================================================================
# Group B: TR-025 — 4 owned signals declared with exact arity
# ===========================================================================

func test_orchestrator_declares_validation_failed_signal() -> void:
	var orch: Node = _make_orch()
	var sigs: Array = orch.get_signal_list()
	var found: bool = false
	for s: Dictionary in sigs:
		if s.get("name", "") == "validation_failed":
			found = true
			# Exact arity: 2 args (reason: String, payload: Dictionary).
			assert_int((s.get("args", []) as Array).size()).is_equal(2)
	assert_bool(found).is_true()


func test_orchestrator_declares_enemy_killed_signal_with_three_args() -> void:
	var orch: Node = _make_orch()
	var sigs: Array = orch.get_signal_list()
	var found: bool = false
	for s: Dictionary in sigs:
		if s.get("name", "") == "enemy_killed":
			found = true
			assert_int((s.get("args", []) as Array).size()).is_equal(3)
	assert_bool(found).is_true()


func test_orchestrator_declares_boss_killed_signal_with_one_arg() -> void:
	var orch: Node = _make_orch()
	var sigs: Array = orch.get_signal_list()
	var found: bool = false
	for s: Dictionary in sigs:
		if s.get("name", "") == "boss_killed":
			found = true
			assert_int((s.get("args", []) as Array).size()).is_equal(1)
	assert_bool(found).is_true()


func test_orchestrator_declares_floor_cleared_first_time_signal_with_three_args() -> void:
	var orch: Node = _make_orch()
	var sigs: Array = orch.get_signal_list()
	var found: bool = false
	for s: Dictionary in sigs:
		if s.get("name", "") == "floor_cleared_first_time":
			found = true
			assert_int((s.get("args", []) as Array).size()).is_equal(3)
	assert_bool(found).is_true()


# ===========================================================================
# Group C: enemy_killed emission — once per kill event
# ===========================================================================

func test_enemy_killed_fires_once_per_kill_event() -> void:
	# Arrange — orchestrator with run_snapshot + combat_snapshot pre-built.
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch.run_snapshot.losing_run = false
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {&"bruiser": true}
	orch.enemy_killed.connect(_on_enemy_killed)
	var events: RefCounted = _make_tick_events([
		_make_kill_event(1, &"bruiser"),
		_make_kill_event(2, &"bruiser"),
		_make_kill_event(3, &"bruiser"),
	])

	# Act
	orch._process_kill_events(events)

	# Assert — 3 emissions, one per kill.
	assert_int(_spy_enemy_killed_calls.size()).is_equal(3)


func test_enemy_killed_carries_correct_advantaged_flag_from_matchup_cache() -> void:
	# matchup_cache says bruiser=true; caster=false. enemy_killed reflects each.
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {&"bruiser": true, &"caster": false}
	orch.enemy_killed.connect(_on_enemy_killed)
	var events: RefCounted = _make_tick_events([
		_make_kill_event(1, &"bruiser"),
		_make_kill_event(1, &"caster"),
	])

	# Act
	orch._process_kill_events(events)

	# Assert
	assert_int(_spy_enemy_killed_calls.size()).is_equal(2)
	assert_bool(bool(_spy_enemy_killed_calls[0]["advantaged"])).is_true()
	assert_bool(bool(_spy_enemy_killed_calls[1]["advantaged"])).is_false()


func test_enemy_killed_carries_correct_tier_and_archetype() -> void:
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	orch.enemy_killed.connect(_on_enemy_killed)
	var events: RefCounted = _make_tick_events([
		_make_kill_event(2, &"caster"),
	])

	# Act
	orch._process_kill_events(events)

	# Assert
	assert_int(int(_spy_enemy_killed_calls[0]["tier"])).is_equal(2)
	assert_str(str(_spy_enemy_killed_calls[0]["archetype"])).is_equal("caster")


# ===========================================================================
# Group D: TR-022 — boss_killed fires only on is_boss kills
# ===========================================================================

func test_boss_killed_fires_when_is_boss_true() -> void:
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	orch.boss_killed.connect(_on_boss_killed)
	var events: RefCounted = _make_tick_events([
		_make_kill_event(3, &"boss_archetype", true, &"forest_warden", 21),
	])

	# Act
	orch._process_kill_events(events)

	# Assert
	assert_int(_spy_boss_killed_calls.size()).is_equal(1)
	assert_str(str(_spy_boss_killed_calls[0])).is_equal("forest_warden")


func test_boss_killed_does_not_fire_for_non_boss_kills() -> void:
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	orch.boss_killed.connect(_on_boss_killed)
	var events: RefCounted = _make_tick_events([
		_make_kill_event(1, &"bruiser", false),
		_make_kill_event(1, &"bruiser", false),
	])

	# Act
	orch._process_kill_events(events)

	# Assert
	assert_int(_spy_boss_killed_calls.size()).is_equal(0)


func test_boss_killed_fires_regardless_of_queue_position() -> void:
	# TR-022: boss_killed fires for is_boss=true even mid-queue (not only the
	# last enemy of the floor).
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	orch.boss_killed.connect(_on_boss_killed)
	# Boss in the MIDDLE of the kill stream (not at the end).
	var events: RefCounted = _make_tick_events([
		_make_kill_event(1, &"bruiser", false, &"e1"),
		_make_kill_event(2, &"bruiser", true, &"mid_boss"),
		_make_kill_event(1, &"bruiser", false, &"e3"),
	])

	# Act
	orch._process_kill_events(events)

	# Assert — boss_killed fired with the mid-queue boss.
	assert_int(_spy_boss_killed_calls.size()).is_equal(1)
	assert_str(str(_spy_boss_killed_calls[0])).is_equal("mid_boss")


func test_boss_killed_fires_for_each_boss_in_event_batch() -> void:
	# Multi-boss edge: a single tick batch with 2 boss kills → 2 emissions.
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	orch.boss_killed.connect(_on_boss_killed)
	var events: RefCounted = _make_tick_events([
		_make_kill_event(2, &"bruiser", true, &"boss_a"),
		_make_kill_event(3, &"bruiser", true, &"boss_b"),
	])

	# Act
	orch._process_kill_events(events)

	# Assert
	assert_int(_spy_boss_killed_calls.size()).is_equal(2)


# ===========================================================================
# Group E: TR-022 — floor_cleared_first_time once-per-dispatch idempotency
# ===========================================================================

func test_floor_cleared_first_time_fires_on_first_clear() -> void:
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch.run_snapshot.losing_run = false
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	orch._dispatched_floor_index = 1
	orch._dispatched_biome_id = "forest_reach"
	orch.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	orch.floor_cleared_first_time.connect(_on_floor_cleared_first_time)
	var events: RefCounted = _make_tick_events([], true)  # first_clear_in_range = true

	# Act
	orch._process_kill_events(events)

	# Assert — signal fired with dispatch context.
	assert_int(_spy_floor_cleared_calls.size()).is_equal(1)
	assert_int(int(_spy_floor_cleared_calls[0]["floor_index"])).is_equal(1)
	assert_str(str(_spy_floor_cleared_calls[0]["biome_id"])).is_equal("forest_reach")
	assert_bool(bool(_spy_floor_cleared_calls[0]["losing_run"])).is_false()


func test_floor_cleared_first_time_does_not_fire_twice_within_same_dispatch() -> void:
	# TR-018 idempotency: orchestrator's floor_clear_emitted flag prevents
	# re-emission. Combat reports the marker per-call; only the FIRST crossing
	# emits the orchestrator-side fanfare.
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	orch._dispatched_floor_index = 1
	orch._dispatched_biome_id = "forest_reach"
	orch.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	orch.floor_cleared_first_time.connect(_on_floor_cleared_first_time)

	# Act — first call: floor_clear fires; state flips to RUN_ENDED.
	orch._process_kill_events(_make_tick_events([], true))
	# Reset to ACTIVE_FOREGROUND for a second call (simulating a second
	# emit_events_in_range call that reports the same marker — Combat is
	# stateless and reports it again every time the range covers it).
	orch.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	orch._process_kill_events(_make_tick_events([], true))

	# Assert — signal fired exactly once across both calls.
	assert_int(_spy_floor_cleared_calls.size()).is_equal(1)
	# Idempotency flag set on the snapshot.
	assert_bool(orch.run_snapshot.floor_clear_emitted).is_true()


func test_dispatched_floor_index_and_biome_id_reset_on_run_ended_transition() -> void:
	# Sprint 8 S8-S3 follow-up (code-review): the doc comments on
	# _dispatched_floor_index / _dispatched_biome_id promise "Reset to 0/'' on
	# RUN_ENDED". Without this, a stale floor_cleared_first_time payload could
	# leak from a prior dispatch into the next. Verify the reset wires through
	# _exit_active_foreground when the FSM transitions out of ACTIVE_FOREGROUND.
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	orch._dispatched_floor_index = 7
	orch._dispatched_biome_id = "forest_reach"
	orch.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	# Act — first_clear → RUN_ENDED transition (calls _exit_active_foreground).
	orch._process_kill_events(_make_tick_events([], true))

	# Assert — fields zeroed by the exit hook.
	assert_int(orch._dispatched_floor_index).is_equal(0)
	assert_str(orch._dispatched_biome_id).is_equal("")


func test_floor_cleared_first_time_carries_losing_run_flag_correctly() -> void:
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch.run_snapshot.losing_run = true  # below 0.5 hp_bonus → losing
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	orch._dispatched_floor_index = 3
	orch._dispatched_biome_id = "forest_reach"
	orch.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	orch.floor_cleared_first_time.connect(_on_floor_cleared_first_time)

	# Act
	orch._process_kill_events(_make_tick_events([], true))

	# Assert
	assert_bool(bool(_spy_floor_cleared_calls[0]["losing_run"])).is_true()
	assert_int(int(_spy_floor_cleared_calls[0]["floor_index"])).is_equal(3)


# ===========================================================================
# Group F: TR-018 — Economy.add_gold routing
# ===========================================================================

func test_economy_add_gold_called_for_each_kill_with_attributed_amount() -> void:
	# Spy Economy via the autoload — capture _gold_balance delta to verify
	# add_gold is being called. Each kill at tier=1 advantaged=true → 7 gold.
	# 3 kills → +21 to balance.
	if not Engine.has_singleton("Economy") and get_node_or_null("/root/Economy") == null:
		push_warning("Skipped: Economy autoload not present in test env")
		return
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch.run_snapshot.losing_run = false
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {&"bruiser": true}
	var economy: Node = orch.get_node_or_null("/root/Economy")
	if economy == null:
		push_warning("Skipped: Economy autoload not reachable")
		return
	# Capture pre-call gold balance.
	var pre: int = int(economy._gold_balance)

	# Act — 3 advantaged tier-1 kills → 7 each.
	orch._process_kill_events(_make_tick_events([
		_make_kill_event(1, &"bruiser"),
		_make_kill_event(1, &"bruiser"),
		_make_kill_event(1, &"bruiser"),
	]))

	# Assert — Economy gained 21 (3 × 7).
	var post: int = int(economy._gold_balance)
	assert_int(post - pre).is_equal(21)


func test_economy_add_gold_skipped_for_zero_amount_kills() -> void:
	# Unmapped tier → 0 gold → Economy.add_gold guard prevents a 0-amount call
	# (Economy itself rejects amount<=0 with push_error; orchestrator pre-checks
	# `gold > 0` before calling so the push_error doesn't fire).
	if get_node_or_null("/root/Economy") == null:
		push_warning("Skipped: Economy autoload not present")
		return
	_reset_spies()
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	orch._combat_snapshot.matchup_cache = {}
	var economy: Node = orch.get_node_or_null("/root/Economy")
	var pre: int = int(economy._gold_balance)

	# Act — tier=99 unmapped → 0 gold; orchestrator skips add_gold.
	orch._process_kill_events(_make_tick_events([
		_make_kill_event(99, &"unknown_archetype"),
	]))

	# Assert — Economy balance unchanged.
	assert_int(int(economy._gold_balance) - pre).is_equal(0)
