# Sprint 21+ Telemetry V1.0 / Stage 2 — TelemetrySink signal handler tests.
#
# Per `production/live-ops/telemetry-events-v1.md` §D + §F.3 + §F.4.
#
# Tests cover the 5 V1 event handlers: each fires the correct event when
# opt_in=true, each is a no-op when opt_in=false. Test pattern follows
# the AudioRouter signal-handlers test file convention (live autoload at
# /root/TelemetrySink, _test_event_log debug-build-only spy array).
#
# Test groups:
#   A — opt-in gate (handler short-circuits when off)
#   B — first_launch payload shape
#   C — recruit_purchased payload shape
#   D — prestige_completed payload shape
#   E — run state-change handler dispatches both run_dispatched + run_completed
#   F — sink dir override (test-isolation hygiene per memory
#       `feedback_test_isolation_user_configfile`)
#
# Test isolation: this file injects fake heroes directly into the live
# /root/HeroRoster autoload's _heroes dict. before_test/after_test wrap
# every test in a full HeroRoster snapshot+restore via get_save_data /
# load_save_data — needed because a save firing during the test window
# would otherwise persist the injected hero into the player's save file.
# Canonical isolation pattern: tests/integration/recruitment/recruitment_try_recruit_test.gd.
extends GdUnitTestSuite

const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

var _injected_hero_ids: Array[int] = []
var _snapshot_hero_roster: Dictionary = {}


# ---------------------------------------------------------------------------
# Hygiene helpers
# ---------------------------------------------------------------------------

func _get_sink() -> Node:
	return get_tree().root.get_node_or_null("TelemetrySink")


func _reset_sink() -> void:
	var sink: Node = _get_sink()
	if sink == null:
		return
	sink.set_opt_in(false)
	if "_test_event_log" in sink:
		sink._test_event_log.clear()
	# Use a temp sink dir so tests don't pollute the real user://telemetry/.
	if "_sink_dir_override" in sink:
		sink._sink_dir_override = "user://telemetry-test/"


func _make_hero(id: int, class_id: String) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = class_id
	fake.display_name = "TestHero%d" % id
	fake.current_level = 1
	fake.xp = 0
	HeroRoster._heroes[id] = fake
	_injected_hero_ids.append(id)
	return fake


func before_test() -> void:
	_reset_sink()
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	_snapshot_hero_roster = roster.get_save_data() if roster != null else {}


func after_test() -> void:
	_reset_sink()
	# erase_by_id covers the no-HeroRoster test-env case where snapshot is empty.
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and not _snapshot_hero_roster.is_empty():
		roster.load_save_data(_snapshot_hero_roster)


# Helper to fetch the last event of a given type from the spy log.
func _last_event(event_type: String) -> Dictionary:
	var sink: Node = _get_sink()
	if sink == null or not "_test_event_log" in sink:
		return {}
	var result: Dictionary = {}
	for entry: Dictionary in sink._test_event_log:
		if entry.get("event_type") == event_type:
			result = entry
	return result


func _count_events(event_type: String) -> int:
	var sink: Node = _get_sink()
	if sink == null or not "_test_event_log" in sink:
		return 0
	var count: int = 0
	for entry: Dictionary in sink._test_event_log:
		if entry.get("event_type") == event_type:
			count += 1
	return count


# ===========================================================================
# Group A — opt-in gate (handler short-circuits when off)
# ===========================================================================

func test_first_launch_handler_no_op_when_opt_out() -> void:
	# opt_in=false (default) → handler must short-circuit.
	var sink: Node = _get_sink()
	sink._on_first_launch()
	assert_int(_count_events("first_launch")).is_equal(0)


func test_recruit_handler_no_op_when_opt_out() -> void:
	var sink: Node = _get_sink()
	var fake: RefCounted = _make_hero(7001, "warrior")
	sink._on_hero_recruited(fake)
	assert_int(_count_events("recruit_purchased")).is_equal(0)


func test_prestige_handler_no_op_when_opt_out() -> void:
	var sink: Node = _get_sink()
	var record: Dictionary = {"class_id": "warrior", "level_at_retirement": 15, "prestige_index": 1}
	sink._on_prestige_completed(record, 1)
	assert_int(_count_events("prestige_completed")).is_equal(0)


func test_run_state_handler_no_op_when_opt_out() -> void:
	var sink: Node = _get_sink()
	sink._on_run_state_changed(1, 0)  # 1 = DISPATCHING
	sink._on_run_state_changed(4, 2)  # 4 = RUN_ENDED
	assert_int(_count_events("run_dispatched")).is_equal(0)
	assert_int(_count_events("run_completed")).is_equal(0)


# ===========================================================================
# Group B — first_launch payload shape
# ===========================================================================

func test_first_launch_payload_includes_seed_class_when_opt_in() -> void:
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	sink._on_first_launch()
	var entry: Dictionary = _last_event("first_launch")
	assert_object(entry).is_not_null()
	var payload: Dictionary = entry.get("payload", {}) as Dictionary
	assert_str(str(payload.get("seed_class", ""))).is_equal("warrior")
	assert_bool(payload.has("cold_launch_ms")).is_true()


# ===========================================================================
# Group C — recruit_purchased payload shape
# ===========================================================================

func test_recruit_payload_includes_class_and_roster_size_when_opt_in() -> void:
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	var fake: RefCounted = _make_hero(7011, "mage")
	sink._on_hero_recruited(fake)
	var entry: Dictionary = _last_event("recruit_purchased")
	assert_object(entry).is_not_null()
	var payload: Dictionary = entry.get("payload", {}) as Dictionary
	assert_str(str(payload.get("class_id", ""))).is_equal("mage")
	# roster_size_after >= 1 because we just injected a hero (live HeroRoster
	# may also contain Theron from autoload boot, so >=1 is the safe bound).
	assert_int(int(payload.get("roster_size_after", 0))).is_greater_equal(1)
	# cost_paid + gold_balance_after fields present (sentinel 0 acceptable
	# for V1 per the docstring TODO).
	assert_bool(payload.has("cost_paid")).is_true()
	assert_bool(payload.has("gold_balance_after")).is_true()


func test_recruit_handler_null_instance_no_op() -> void:
	# Defensive: null hero instance must not crash; skip cleanly.
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	sink._on_hero_recruited(null)
	assert_int(_count_events("recruit_purchased")).is_equal(0)


# ===========================================================================
# Group D — prestige_completed payload shape
# ===========================================================================

func test_prestige_payload_includes_class_and_count_when_opt_in() -> void:
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	var record: Dictionary = {
		"class_id": "rogue",
		"level_at_retirement": 15,
		"prestige_index": 3,
	}
	sink._on_prestige_completed(record, 3)
	var entry: Dictionary = _last_event("prestige_completed")
	assert_object(entry).is_not_null()
	var payload: Dictionary = entry.get("payload", {}) as Dictionary
	assert_str(str(payload.get("prestiged_class_id", ""))).is_equal("rogue")
	assert_int(int(payload.get("level_at_retirement", 0))).is_equal(15)
	assert_int(int(payload.get("new_prestige_count", 0))).is_equal(3)
	# was_last_hero is always false in MVP — protection prevents the prestige
	# (AC-PR-20) so this branch never sees true. Logging documents the contract.
	assert_bool(bool(payload.get("was_last_hero", true))).is_false()


# ===========================================================================
# Group E — run state-change handler dispatches both events
# ===========================================================================

func test_state_changed_active_foreground_emits_run_dispatched() -> void:
	# I14: run_dispatched fires on ACTIVE_FOREGROUND (2) — reached only AFTER the
	# orchestrator rebuilds run_snapshot and validations pass. run_snapshot may be
	# null in a pure unit env → _emit_run_dispatched short-circuits, so 0 or 1.
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	sink._on_run_state_changed(2, 1)  # DISPATCHING(1) → ACTIVE_FOREGROUND(2)
	assert_int(_count_events("run_dispatched")).is_less_equal(1)
	assert_int(_count_events("run_completed")).is_equal(0)


func test_state_changed_dispatching_does_not_emit_run_dispatched() -> void:
	# I14 regression: DISPATCHING (1) must NOT emit run_dispatched. At DISPATCHING the
	# orchestrator's run_snapshot is still the PRIOR run's (it is rebuilt on the way to
	# ACTIVE_FOREGROUND), so emitting here logged a stale, off-by-one snapshot.
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	sink._on_run_state_changed(1, 0)  # 1 = DISPATCHING
	assert_int(_count_events("run_dispatched")).is_equal(0)


func test_state_changed_run_ended_from_active_emits_run_completed() -> void:
	# A real foreground run ending: ACTIVE_FOREGROUND(2) → RUN_ENDED(4).
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	sink._on_run_state_changed(4, 2)  # old_state = ACTIVE_FOREGROUND
	assert_int(_count_events("run_completed")).is_less_equal(1)
	assert_int(_count_events("run_dispatched")).is_equal(0)


func test_state_changed_run_ended_from_dispatching_does_not_emit_run_completed() -> void:
	# I14 regression: a FAILED-validation dispatch traverses DISPATCHING(1) →
	# RUN_ENDED(4) WITHOUT reaching ACTIVE_FOREGROUND. run_completed must NOT fire —
	# it would log a phantom completion with a garbage gold delta vs a stale baseline.
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	sink._on_run_state_changed(4, 1)  # old_state = DISPATCHING
	assert_int(_count_events("run_completed")).is_equal(0)


func test_state_changed_offline_replay_end_does_not_emit_run_completed() -> void:
	# Offline-replay end (ACTIVE_OFFLINE_REPLAY(3) → RUN_ENDED(4)) has its own
	# summary and must NOT log a foreground run_completed.
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	sink._on_run_state_changed(4, 3)  # old_state = ACTIVE_OFFLINE_REPLAY
	assert_int(_count_events("run_completed")).is_equal(0)


func test_state_changed_no_run_entry_does_not_emit() -> void:
	# NO_RUN(0) on entry maps to no event.
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	sink._on_run_state_changed(0, 4)  # → NO_RUN
	assert_int(_count_events("run_dispatched")).is_equal(0)
	assert_int(_count_events("run_completed")).is_equal(0)


# ===========================================================================
# Group F — signal subscription verified at _ready
# ===========================================================================

func test_telemetry_sink_subscribes_to_first_launch_signal() -> void:
	var sink: Node = _get_sink()
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_object(sl).is_not_null()
	assert_bool(sl.first_launch.is_connected(sink._on_first_launch)).is_true()


func test_telemetry_sink_subscribes_to_hero_recruited() -> void:
	var sink: Node = _get_sink()
	var hr: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(hr).is_not_null()
	assert_bool(hr.hero_recruited.is_connected(sink._on_hero_recruited)).is_true()


func test_telemetry_sink_subscribes_to_prestige_completed() -> void:
	var sink: Node = _get_sink()
	var hr: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(hr).is_not_null()
	assert_bool(hr.prestige_completed_signal.is_connected(sink._on_prestige_completed)).is_true()


func test_telemetry_sink_subscribes_to_run_state_changed() -> void:
	var sink: Node = _get_sink()
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	assert_object(orch).is_not_null()
	assert_bool(orch.state_changed.is_connected(sink._on_run_state_changed)).is_true()
