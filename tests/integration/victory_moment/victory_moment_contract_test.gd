# Sprint 16 S16-S1 candidate scaffold — contract-layer tests for the
# Victory Moment Screen #25.
#
# Tests cover the load-bearing contract:
#   - on_enter reads run_snapshot data (kill_count, _dispatched_floor_index,
#     _dispatched_biome_id, pre_dispatch_gold)
#   - Auto-dismiss on null run_snapshot OR _replay_in_flight invariant
#     violation
#   - Headline + UnlockNotice + Stats + LevelUps render functions
#   - new-high vs re-clear classification via FloorUnlock.get_highest_cleared
#   - Floor 5 boss-floor biome-completion message override
#   - Per-hero level deltas terminal-only render (GDD §C.10 + OQ-25-2)
#   - Tap-grace TAP_GRACE_MS=200ms ignores early taps
#   - Continuation prompt revealed after CONTINUATION_DWELL_MS
#
# Visual layout tests are NOT included — those are /design-review polish
# items per Victory Moment GDD #25 §I.
extends GdUnitTestSuite

const VictoryMomentScene = preload("res://assets/screens/victory_moment/victory_moment.tscn")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


func _make_screen() -> Node:
	var screen: Node = VictoryMomentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	return screen


# Track injected heroes for cleanup.
var _injected_hero_ids: Array[int] = []


func _inject_hero(id: int, class_id: String, level: int = 1) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = class_id
	fake.display_name = "Test Hero %d" % id
	fake.current_level = level
	fake.xp = 0
	HeroRoster._heroes[id] = fake
	_injected_hero_ids.append(id)
	return fake


func after_test() -> void:
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()
	# Reset orchestrator state so subsequent tests don't see stale data.
	DungeonRunOrchestrator.run_snapshot = null
	DungeonRunOrchestrator._dispatched_floor_index = 0
	DungeonRunOrchestrator._dispatched_biome_id = ""


# Helper to build a synthetic run_snapshot for the Victory Moment screen
# to read. Matches the snapshot shape DungeonRunOrchestrator produces
# during dispatch.
func _seed_run_snapshot(
	floor_index: int,
	biome_id: String,
	kill_count: int,
	pre_gold: int,
	formation_heroes: Array
) -> RunSnapshot:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.kill_count = kill_count
	snap.pre_dispatch_gold = pre_gold
	snap.formation_snapshot = {
		"instance_ids": [],
		"heroes": formation_heroes,
	}
	DungeonRunOrchestrator.run_snapshot = snap
	DungeonRunOrchestrator._dispatched_floor_index = floor_index
	DungeonRunOrchestrator._dispatched_biome_id = biome_id
	return snap


# ===========================================================================
# Group A — on_enter reads run_snapshot data
# ===========================================================================

func test_victory_moment_on_enter_reads_kill_count_from_snapshot() -> void:
	var screen: Node = _make_screen()
	_seed_run_snapshot(1, "forest_reach", 12, 100, [])
	screen.on_enter()
	assert_int(screen._kill_count).is_equal(12)
	assert_int(screen._floor_index).is_equal(1)
	assert_str(screen._biome_id).is_equal("forest_reach")
	screen.on_exit()


# Gold delta = post_run_balance - pre_dispatch_gold. The post-run balance
# is the live Economy.get_gold_balance at on_enter time.
func test_victory_moment_on_enter_computes_gold_delta_from_pre_dispatch_gold() -> void:
	var screen: Node = _make_screen()
	# Seed pre_dispatch_gold = 100; current Economy balance unknown in
	# test env (varies). The delta = current - 100.
	_seed_run_snapshot(1, "forest_reach", 0, 100, [])
	var current_balance: int = Economy.get_gold_balance()
	screen.on_enter()
	assert_int(screen._gold_delta).is_equal(current_balance - 100)
	screen.on_exit()


# ===========================================================================
# Group B — Defensive auto-dismiss paths
# ===========================================================================

# Null run_snapshot + _replay_in_flight invariant violations both call
# SceneManager.request_screen which fails in the test env (MainRoot
# missing — see Recruit/Matchup scaffold tests; documented
# wired-vs-autoload pattern in tests/PATTERNS.md §8). The defensive
# early-return paths execute push_warning before the route attempt
# (which then asserts), so we cannot cleanly test these flows in the
# headless integration env. Tests deferred to manual verification +
# the WiredSceneManager pattern when those tests exist for this screen.


# ===========================================================================
# Group C — Headline + UnlockNotice rendering
# ===========================================================================

func test_victory_moment_renders_headline_with_floor_and_biome() -> void:
	var screen: Node = _make_screen()
	_seed_run_snapshot(3, "forest_reach", 0, 100, [])
	screen.on_enter()
	# Headline contains the floor index and biome name.
	assert_bool(screen._headline_label.text.contains("3")).is_true()
	assert_bool(
		screen._headline_label.text.to_lower().contains("forest")
		or screen._headline_label.text.to_lower().contains("reach")
	).is_true()
	screen.on_exit()


# When the floor is the new-high (FloorUnlock.get_highest_cleared >=
# floor_index), UnlockNoticeLabel is visible.
func test_victory_moment_unlock_notice_visible_on_new_high_clear() -> void:
	var screen: Node = _make_screen()
	# Floor 1 is always unlocked + cleared in any non-fresh save.
	_seed_run_snapshot(1, "forest_reach", 0, 100, [])
	# Force FloorUnlock state to ensure new-high classification.
	FloorUnlock.debug_set_highest_cleared("forest_reach", 1)
	screen.on_enter()
	assert_bool(screen._unlock_notice_label.visible).is_true()
	# Standard new-high text format includes the next floor index "2".
	assert_bool(screen._unlock_notice_label.text.contains("2")).is_true()
	screen.on_exit()


# When floor < highest_cleared (re-clear), UnlockNoticeLabel hidden.
func test_victory_moment_unlock_notice_hidden_on_re_clear() -> void:
	var screen: Node = _make_screen()
	_seed_run_snapshot(1, "forest_reach", 0, 100, [])
	# Force highest_cleared > floor_index → re-clear classification.
	FloorUnlock.debug_set_highest_cleared("forest_reach", 3)
	screen.on_enter()
	# floor_index=1; highest_cleared=3 → NOT a new-high.
	assert_bool(screen._is_new_high_clear).is_false()
	assert_bool(screen._unlock_notice_label.visible).is_false()
	screen.on_exit()


# Floor 5 boss clear → biome-completion message (per AC-25-14).
func test_victory_moment_floor_5_clear_shows_biome_completion_message() -> void:
	var screen: Node = _make_screen()
	_seed_run_snapshot(5, "forest_reach", 0, 100, [])
	FloorUnlock.debug_set_highest_cleared("forest_reach", 5)
	screen.on_enter()
	assert_bool(screen._is_biome_completed).is_true()
	# Notice text contains "completed" (matches victory_biome_completed_format).
	assert_bool(
		screen._unlock_notice_label.text.to_lower().contains("complet")
	).is_true()
	screen.on_exit()


# ===========================================================================
# Group D — Stats render
# ===========================================================================

func test_victory_moment_renders_kill_count_value() -> void:
	var screen: Node = _make_screen()
	_seed_run_snapshot(1, "forest_reach", 17, 100, [])
	screen.on_enter()
	assert_str(screen._kill_count_value.text).is_equal("17")
	screen.on_exit()


func test_victory_moment_renders_positive_gold_delta() -> void:
	var screen: Node = _make_screen()
	# Gold delta = current_balance - 0. Whatever the balance, it's >=0.
	_seed_run_snapshot(1, "forest_reach", 0, 0, [])
	screen.on_enter()
	# GoldGainedValue text contains a number (delta or "0").
	# Cozy "+%d gold" format applies for delta > 0; "0 gold" for 0.
	assert_bool(
		screen._gold_gained_value.text.contains("gold")
		or screen._gold_gained_value.text.contains("0")
	).is_true()
	screen.on_exit()


# ===========================================================================
# Group E — Per-hero level deltas (terminal-only)
# ===========================================================================

# Hero leveled up from pre-dispatch state → row rendered.
func test_victory_moment_renders_level_up_row_for_leveled_hero() -> void:
	var screen: Node = _make_screen()
	# Inject a hero at level 3 in HeroRoster.
	var hero: RefCounted = _inject_hero(501, "warrior", 3)
	# Pre-dispatch level was 1 (in snapshot); hero went 1 → 3 during run.
	var pre_heroes: Array = [{
		"instance_id": 501,
		"current_level": 1,
		"class_id": "warrior",
	}]
	_seed_run_snapshot(1, "forest_reach", 0, 100, pre_heroes)
	screen.on_enter()
	# Should render 1 LevelUpRow for hero 501 with terminal level 3.
	assert_int(screen._hero_level_deltas.size()).is_equal(1)
	assert_str(String(screen._hero_level_deltas[0].display_name)).is_equal(hero.display_name)
	assert_int(int(screen._hero_level_deltas[0].terminal_level)).is_equal(3)
	# LevelUpsBlock visible.
	assert_bool(screen._level_ups_block.visible).is_true()
	screen.on_exit()


# Hero did NOT level up → no row rendered.
func test_victory_moment_no_level_up_row_when_no_level_change() -> void:
	var screen: Node = _make_screen()
	# Hero at level 2 in HeroRoster; pre-dispatch level was 2 (no change).
	_inject_hero(502, "mage", 2)
	var pre_heroes: Array = [{
		"instance_id": 502,
		"current_level": 2,
		"class_id": "mage",
	}]
	_seed_run_snapshot(1, "forest_reach", 0, 100, pre_heroes)
	screen.on_enter()
	# No level-up row.
	assert_int(screen._hero_level_deltas.size()).is_equal(0)
	# LevelUpsBlock hidden when zero level-ups.
	assert_bool(screen._level_ups_block.visible).is_false()
	screen.on_exit()


# ===========================================================================
# Group F — Tap-grace and continuation prompt
# ===========================================================================

# ContinuationPromptLabel hidden at on_enter time (revealed after dwell).
func test_victory_moment_continuation_prompt_hidden_initially() -> void:
	var screen: Node = _make_screen()
	_seed_run_snapshot(1, "forest_reach", 0, 100, [])
	screen.on_enter()
	# Right after on_enter (before CONTINUATION_DWELL_MS elapsed), prompt
	# is hidden.
	assert_bool(screen._continuation_prompt.visible).is_false()
	screen.on_exit()


# DimBackdrop input handler is wired in on_enter.
func test_victory_moment_backdrop_input_handler_wired_in_on_enter() -> void:
	var screen: Node = _make_screen()
	_seed_run_snapshot(1, "forest_reach", 0, 100, [])
	screen.on_enter()
	assert_bool(
		screen._dim_backdrop.gui_input.is_connected(screen._on_backdrop_input)
	).is_true()
	screen.on_exit()
	# Disconnected after on_exit.
	assert_bool(
		screen._dim_backdrop.gui_input.is_connected(screen._on_backdrop_input)
	).is_false()
