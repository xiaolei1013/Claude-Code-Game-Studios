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

# Snapshot of the live SceneManager.reduce_motion flag, saved in before_test and
# restored in after_test so motion-vs-snap toggles never leak across tests.
# reduce_motion is a plain var (scene_manager.gd:312) — direct assignment does
# NOT persist to user://settings.cfg (only set_reduce_motion() does), mirroring
# reduce_motion_clamp_test.gd's "bypass ConfigFile" pattern.
var _saved_reduce_motion: bool = false


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


func before_test() -> void:
	# Default every test to the reduce_motion snap path so the existing contract
	# tests create no ceremony tweens; the motion-path tests (Group G) opt back
	# in with SceneManager.reduce_motion = false explicitly.
	_saved_reduce_motion = SceneManager.reduce_motion
	SceneManager.reduce_motion = true


func after_test() -> void:
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()
	# Reset orchestrator state so subsequent tests don't see stale data.
	DungeonRunOrchestrator.run_snapshot = null
	DungeonRunOrchestrator._dispatched_floor_index = 0
	DungeonRunOrchestrator._dispatched_biome_id = ""
	# Restore the live reduce_motion flag snapshotted in before_test.
	SceneManager.reduce_motion = _saved_reduce_motion


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
	# floor_id format must match orchestrator.gd's _build_run_snapshot —
	# Victory Moment parses it back out to get floor_index + biome_id.
	snap.floor_id = "%s_floor_%d" % [biome_id, floor_index]
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


# Regression (playtest 2026-06-03): the player could not tap to continue.
# CenterPanel (PanelContainer, mouse_filter=STOP) draws ABOVE DimBackdrop and
# consumes every tap over the ceremony content — including the "Tap to continue"
# prompt, which lives INSIDE CenterPanel. STOP controls do not bubble to parents,
# so neither the root nor the (behind-the-panel) DimBackdrop gui_input ever fired
# for taps on the content. The old "handler_wired" test passed because it only
# checked signal connection on DimBackdrop — never that a tap over the content
# actually routes anywhere. Fix: a top-most full-rect STOP TapCatcher wired to
# _on_backdrop_input. This asserts that routing contract.
func test_victory_moment_tap_catcher_covers_content_above_panel() -> void:
	var screen: Node = _make_screen()
	_seed_run_snapshot(1, "forest_reach", 3, 100, [])
	screen.on_enter()

	var catcher: Control = screen.get_node_or_null("TapCatcher") as Control
	assert_object(catcher).is_not_null().override_failure_message(
		"on_enter must add a top-most TapCatcher. Without it, CenterPanel (STOP) "
		+ "eats every tap over the content and the player is stuck on the screen."
	)
	# Wired to the continue handler.
	assert_bool(catcher.gui_input.is_connected(screen._on_backdrop_input)).is_true() \
		.override_failure_message("TapCatcher.gui_input must route to _on_backdrop_input.")
	# STOP so it actually catches taps (PASS/IGNORE would defeat the purpose).
	assert_int(catcher.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	# Ordered after CenterPanel among root children → drawn on top → receives
	# taps over the panel.
	assert_int(catcher.get_index()).is_greater(screen._center_panel.get_index()) \
		.override_failure_message("TapCatcher must draw above CenterPanel to catch its taps.")
	# Full-rect: spans the whole screen, so it covers the prompt and all content.
	assert_float(catcher.anchor_left).is_equal(0.0)
	assert_float(catcher.anchor_top).is_equal(0.0)
	assert_float(catcher.anchor_right).is_equal(1.0)
	assert_float(catcher.anchor_bottom).is_equal(1.0)

	screen.on_exit()
	# Disconnected after on_exit (mirrors the DimBackdrop lifecycle).
	assert_bool(catcher.gui_input.is_connected(screen._on_backdrop_input)).is_false()


# ===========================================================================
# Group G — Entrance ceremony (GDD §C.6): reduce_motion snap vs animated path.
#
# reduce_motion is the live SceneManager flag; before_test defaults it to true
# (snap), so these tests set it explicitly per case. The DimBackdrop resting
# alpha is captured from the .tscn in _ready (shipped 0.75, tuned over the S22
# biome bg — the GDD §G 0.4 predates that bg), so we assert against the captured
# _dim_target_alpha rather than a hardcoded literal.
# ===========================================================================

# G-01: reduce_motion ON → DimBackdrop snaps straight to its resting alpha and
# NO fade/reveal tweens are created (§C.6 reduce_motion).
func test_victory_moment_reduce_motion_snaps_dim_backdrop_no_tweens() -> void:
	var screen: Node = _make_screen()
	SceneManager.reduce_motion = true
	_seed_run_snapshot(1, "forest_reach", 3, 100, [])
	screen.on_enter()
	assert_float(screen._dim_backdrop.color.a).is_equal(screen._dim_target_alpha)
	assert_bool(screen._dim_tween == null).is_true()
	assert_bool(screen._reveal_tween == null).is_true()
	screen.on_exit()


# G-02: reduce_motion OFF → DimBackdrop fade + staggered reveal tweens are
# created and live; on_exit kills and clears them (no tween leak past the screen).
func test_victory_moment_motion_on_creates_and_clears_ceremony_tweens() -> void:
	var screen: Node = _make_screen()
	SceneManager.reduce_motion = false
	_seed_run_snapshot(1, "forest_reach", 3, 100, [])
	screen.on_enter()
	assert_bool(screen._dim_tween != null).is_true()
	assert_bool(screen._reveal_tween != null).is_true()
	assert_bool(screen._dim_tween.is_valid()).is_true()
	assert_bool(screen._reveal_tween.is_valid()).is_true()
	screen.on_exit()
	# on_exit → _kill_ceremony_tweens clears the handles.
	assert_bool(screen._dim_tween == null).is_true()
	assert_bool(screen._reveal_tween == null).is_true()
	# Exiting before the ~1.5s dwell ever fires must leave no orphaned pulse
	# either — the fast tap-through path (the pulse is born only at the dwell).
	assert_bool(screen._pulse_tween == null).is_true()


# G-03: reduce_motion ON → continuation prompt is static at full alpha after the
# dwell, with NO pulse tween (§C.6 reduce_motion).
func test_victory_moment_reduce_motion_continuation_prompt_static_no_pulse() -> void:
	var screen: Node = _make_screen()
	SceneManager.reduce_motion = true
	_seed_run_snapshot(1, "forest_reach", 0, 100, [])
	screen.on_enter()
	screen._on_continuation_dwell_elapsed()
	assert_bool(screen._continuation_prompt.visible).is_true()
	assert_float(screen._continuation_prompt.modulate.a).is_equal(1.0)
	assert_bool(screen._pulse_tween == null).is_true()
	screen.on_exit()


# G-04: reduce_motion OFF → continuation prompt pulses (looping tween created +
# live); on_exit kills it.
func test_victory_moment_motion_on_continuation_prompt_pulses() -> void:
	var screen: Node = _make_screen()
	SceneManager.reduce_motion = false
	_seed_run_snapshot(1, "forest_reach", 0, 100, [])
	screen.on_enter()
	screen._on_continuation_dwell_elapsed()
	assert_bool(screen._continuation_prompt.visible).is_true()
	assert_bool(screen._pulse_tween != null).is_true()
	assert_bool(screen._pulse_tween.is_valid()).is_true()
	screen.on_exit()
	assert_bool(screen._pulse_tween == null).is_true()


# ===========================================================================
# Group H — Victory audio cue selection (GDD §F / §C.1 R5).
#
# _select_victory_cue is pure (no AudioRouter dependency), so the
# new-high-vs-re-clear split is unit-testable directly. Audio is NOT
# reduce_motion-gated — it fires on the valid path in on_enter regardless.
# ===========================================================================

# H-01: new-high clear → the milestone fanfare cue; and the two cues differ
# (the load-bearing split — exact ids are a retune-able taste call).
func test_victory_moment_select_cue_new_high_returns_milestone_fanfare() -> void:
	var screen: Node = _make_screen()
	var new_high_cue: StringName = screen._select_victory_cue(true)
	var re_clear_cue: StringName = screen._select_victory_cue(false)
	assert_str(String(new_high_cue)).is_equal("sfx_reward_class_unlock_fanfare")
	# The split must be real — new-high and re-clear are distinct cues.
	assert_bool(new_high_cue != re_clear_cue).is_true()


# H-02: re-clear → the warm settle chime (cozy "quieter confirmation").
func test_victory_moment_select_cue_re_clear_returns_settle_chime() -> void:
	var screen: Node = _make_screen()
	assert_str(String(screen._select_victory_cue(false))).is_equal("sfx_reward_level_up_chime")


# ===========================================================================
# Group I — Edge cases (GDD §E)
# ===========================================================================

# E.3: zero kills renders "0" (data honesty — the row is NOT hidden).
func test_victory_moment_zero_kills_renders_zero() -> void:
	var screen: Node = _make_screen()
	_seed_run_snapshot(1, "forest_reach", 0, 100, [])
	screen.on_enter()
	assert_str(screen._kill_count_value.text).is_equal("0")
	screen.on_exit()


# E.10 (grace half): a tap inside the TAP_GRACE_MS window is ignored — the early
# return fires BEFORE _continue_to_guild_hall, so SceneManager.request_screen
# (which needs MainRoot, absent headless — see Group B) is never reached and the
# screen survives. The post-grace dismiss itself is a playtest item (Group B).
func test_victory_moment_tap_within_grace_is_ignored() -> void:
	var screen: Node = _make_screen()
	_seed_run_snapshot(1, "forest_reach", 3, 100, [])
	screen.on_enter()
	# Guarantee we are inside the grace window regardless of test-runner timing.
	screen._enter_time_msec = Time.get_ticks_msec()
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	screen._on_backdrop_input(ev)
	# No navigation attempted → screen still valid (no partial-state crash).
	assert_bool(is_instance_valid(screen)).is_true()
	screen.on_exit()
