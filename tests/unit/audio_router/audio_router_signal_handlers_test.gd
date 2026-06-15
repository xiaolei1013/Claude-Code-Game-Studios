# AudioRouter signal handler tests — S12-M6 Stories 3-5.
#
# Covers:
#   AC-AS-13: pitch_scale formula correctness for tiers 1..5 (F.1).
#   AC-AS-06: gold chime throttle drops 2nd+ calls within 250 ms.
#   AC-AS-05: level-up chime fires normally; suppressed during hydration.
#   AC-AS-07/08: stinger overlap dropped; biome bed swap fires play_music.
#   E.7:  gold_changed delta<=0 does not play or touch throttle.
#   E.6:  5 enemy_killed in one frame → 5 plays (no throttle on kill chime).
#   E.3:  second _play_stinger drops with warning while first is in flight.
#
# Test pattern: live AudioRouter autoload at /root/AudioRouter.
# _test_play_sfx_log is a public debug-build-only array populated by play_sfx;
# tests inspect it without needing actual audio device / AudioStreamPlayer.
# Each test clears the log in arrange, then asserts in assert.
#
# Hygiene barrier: before_test + after_test reset the autoload state so tests
# are order-independent (S10-S4 hygiene-barrier pattern).
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Hygiene helpers
# ---------------------------------------------------------------------------

func _get_ar() -> Node:
	return get_tree().root.get_node_or_null("AudioRouter")


func _reset_audio_router() -> void:
	var ar: Node = _get_ar()
	if ar == null:
		return
	ar.set_master_muted(false)
	ar.set_master_volume_db(0.0)
	ar.set_music_volume_db(-8.0)
	ar.set_sfx_volume_db(-3.0)
	# Clear debug log.
	if "_test_play_sfx_log" in ar:
		ar._test_play_sfx_log.clear()
	# Pin the throttle clock to a fixed, high value so the gold/synergy/prestige
	# windows are deterministic regardless of engine-boot timing. Real engine
	# uptime mis-fires the 2.0s windows in dir-scoped runs (see audio_router.gd
	# _throttle_now_override_ms). With the clock pinned far above any window, the
	# last-played clocks below reset cleanly to 0 and the first call always plays.
	if "_throttle_now_override_ms" in ar:
		ar._throttle_now_override_ms = 100000
	# Reset gold throttle clock so tests start from a clean state.
	if "_gold_chime_last_played_ms" in ar:
		ar._gold_chime_last_played_ms = 0
	# Reset class-synergy detection throttle clock.
	if "_class_synergy_detected_last_played_ms" in ar:
		ar._class_synergy_detected_last_played_ms = 0
	# Reset prestige throttle clock (Sprint 21+ silent-MVP wiring).
	if "_prestige_completed_last_played_ms" in ar:
		ar._prestige_completed_last_played_ms = 0
	# Reset the advantage-chime one-shot-per-run latch so the §C.2 chime tests are
	# order-independent (the latch is a live-autoload bool that persists otherwise).
	if "_advantage_chime_fired_this_run" in ar:
		ar._advantage_chime_fired_this_run = false


func before_test() -> void:
	_reset_audio_router()


func after_test() -> void:
	_reset_audio_router()
	# Restore the production clock source so the live /root/AudioRouter autoload
	# is not left pinned to the test override (100000ms) for any subsequent suite
	# or in-session production code (live-autoload state-leak guard).
	var ar: Node = _get_ar()
	if ar != null and "_throttle_now_override_ms" in ar:
		ar._throttle_now_override_ms = -1


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the _test_play_sfx_log array from the live AudioRouter (or empty
## if the field is absent / not debug build).
func _play_log() -> Array:
	var ar: Node = _get_ar()
	if ar == null or "_test_play_sfx_log" not in ar:
		return []
	return ar._test_play_sfx_log


## Count how many log entries match the given sfx_id.
func _count_plays(sfx_id: StringName) -> int:
	var count: int = 0
	for entry: Dictionary in _play_log():
		if entry.get("sfx_id") == sfx_id:
			count += 1
	return count


## Get the last log entry for the given sfx_id, or empty dict if none.
func _last_play(sfx_id: StringName) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in _play_log():
		if entry.get("sfx_id") == sfx_id:
			result = entry
	return result


# ===========================================================================
# AC-AS-13 — Tier-modulated kill chime pitch matches Formula F.1
# pitch_scale(tier) = 1.0 + (3 - tier) * 0.10
# ===========================================================================

func test_enemy_killed_tier1_pitch_scale_is_1_point_20() -> void:
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	# Act
	ar._on_enemy_killed(1, "goblin", false)

	# Assert: play_sfx called with pitch_scale ≈ 1.20
	var entry: Dictionary = _last_play(&"sfx_combat_enemy_kill")
	assert_float(float(entry.get("pitch_scale", 0.0))).is_equal_approx(1.20, 0.001)


func test_enemy_killed_tier2_pitch_scale_is_1_point_10() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	ar._on_enemy_killed(2, "orc", false)
	var entry: Dictionary = _last_play(&"sfx_combat_enemy_kill")
	assert_float(float(entry.get("pitch_scale", 0.0))).is_equal_approx(1.10, 0.001)


func test_enemy_killed_tier3_pitch_scale_is_1_point_00() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	ar._on_enemy_killed(3, "troll", false)
	var entry: Dictionary = _last_play(&"sfx_combat_enemy_kill")
	assert_float(float(entry.get("pitch_scale", 0.0))).is_equal_approx(1.00, 0.001)


func test_enemy_killed_tier4_pitch_scale_is_0_point_90() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	ar._on_enemy_killed(4, "dragon", false)
	var entry: Dictionary = _last_play(&"sfx_combat_enemy_kill")
	assert_float(float(entry.get("pitch_scale", 0.0))).is_equal_approx(0.90, 0.001)


func test_enemy_killed_tier5_pitch_scale_is_0_point_80() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	ar._on_enemy_killed(5, "ancient_wyrm", true)
	var entry: Dictionary = _last_play(&"sfx_combat_enemy_kill")
	assert_float(float(entry.get("pitch_scale", 0.0))).is_equal_approx(0.80, 0.001)


# ===========================================================================
# E.6 — 5 enemy kills in same frame → 5 plays (no throttle on kill chime)
# ===========================================================================

func test_five_enemy_kills_produce_five_play_entries() -> void:
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	# Act — 5 sequential kills (same frame simulation; no await needed)
	ar._on_enemy_killed(1, "a", false)
	ar._on_enemy_killed(2, "b", false)
	ar._on_enemy_killed(3, "c", false)
	ar._on_enemy_killed(3, "d", false)
	ar._on_enemy_killed(4, "e", false)

	# Assert: 5 separate play_sfx calls recorded
	assert_int(_count_plays(&"sfx_combat_enemy_kill")).is_equal(5)


# ===========================================================================
# AC-AS-06 — Gold chime throttle: ≤4 plays per second
# ===========================================================================

func test_gold_chime_throttle_drops_rapid_second_call() -> void:
	# Arrange: reset throttle clock to far-past so first call always fires.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	ar._gold_chime_last_played_ms = 0  # ensure first call passes throttle

	# Act — two rapid calls with delta > 0
	ar._on_gold_changed(100, 10, "add_gold")
	ar._on_gold_changed(110, 10, "add_gold")  # within 250 ms → throttled

	# Assert: only one play recorded for the rapid burst
	assert_int(_count_plays(&"sfx_reward_gold_collected")).is_equal(1)


func test_gold_chime_fires_again_after_throttle_window() -> void:
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	# Set throttle clock to force first call to pass, second to be far future.
	ar._gold_chime_last_played_ms = 0
	ar._on_gold_changed(100, 10, "add_gold")
	assert_int(_count_plays(&"sfx_reward_gold_collected")).is_equal(1)

	# Simulate 300 ms elapsed by forcing the clock back 300 ms — relative to the
	# injected throttle clock (_throttle_now_ms), not real engine uptime, so the
	# window math stays deterministic regardless of boot timing (mirrors the
	# prestige sibling test_prestige_completed_throttle_releases_after_window).
	ar._gold_chime_last_played_ms = ar._throttle_now_ms() - 300

	# Act
	ar._on_gold_changed(110, 10, "add_gold")

	# Assert: second call after throttle window fires.
	assert_int(_count_plays(&"sfx_reward_gold_collected")).is_equal(2)


# ===========================================================================
# E.7 — Gold changed with delta ≤ 0 skips chime and does not touch throttle
# ===========================================================================

func test_gold_changed_zero_delta_does_not_play_chime() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	ar._on_gold_changed(100, 0, "routing_event")
	assert_int(_count_plays(&"sfx_reward_gold_collected")).is_equal(0)


func test_gold_changed_negative_delta_does_not_play_chime() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	ar._on_gold_changed(90, -10, "refund")
	assert_int(_count_plays(&"sfx_reward_gold_collected")).is_equal(0)


func test_gold_changed_negative_delta_does_not_touch_throttle_clock() -> void:
	# Arrange: record throttle clock BEFORE the negative-delta call.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var clock_before: int = ar._gold_chime_last_played_ms

	# Act: negative delta call.
	ar._on_gold_changed(90, -5, "refund")

	# Assert: throttle clock unchanged.
	assert_int(ar._gold_chime_last_played_ms).is_equal(clock_before)


# ===========================================================================
# AC-AS-05 — Level-up chime: normal fire vs. hydration suppression
# ===========================================================================

func test_hero_leveled_fires_chime_when_not_suppressed() -> void:
	# Arrange: ensure HeroRoster exists and suppress flag is false.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and "_suppress_signals" in roster:
		roster._suppress_signals = false

	# Act
	ar._on_hero_leveled(1001, 1, 2)

	# Assert: level-up chime played once.
	assert_int(_count_plays(&"sfx_reward_level_up_chime")).is_equal(1)


func test_hero_leveled_suppressed_during_hydration() -> void:
	# Arrange: set HeroRoster._suppress_signals = true to simulate hydration.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster == null or "_suppress_signals" not in roster:
		# HeroRoster not present or field missing — cannot test suppression.
		# Skip gracefully; AC-AS-05 requires suppression hook to be in place.
		assert_bool(true).is_true()
		return

	var saved_flag: bool = roster._suppress_signals
	roster._suppress_signals = true

	# Act
	ar._on_hero_leveled(1001, 1, 2)

	# Assert: chime NOT played.
	assert_int(_count_plays(&"sfx_reward_level_up_chime")).is_equal(0)

	# Cleanup
	roster._suppress_signals = saved_flag


# ===========================================================================
# AC-AS-05 — Level-up chime: volume_mult is 1.2 per §C.2
# ===========================================================================

func test_hero_leveled_volume_mult_is_1_point_2() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	if roster != null and "_suppress_signals" in roster:
		roster._suppress_signals = false

	ar._on_hero_leveled(1001, 2, 3)
	var entry: Dictionary = _last_play(&"sfx_reward_level_up_chime")
	assert_float(float(entry.get("volume_mult", 0.0))).is_equal_approx(1.2, 0.001)


# ===========================================================================
# E.3 / AC-AS-07 — Stinger overlap dropped
# ===========================================================================

func test_play_stinger_overlap_drops_second_call_with_warning() -> void:
	# Arrange: manually set a fake stinger player node to simulate one in flight.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	# Install a fake AudioStreamPlayer as the current stinger.
	var fake_stinger: AudioStreamPlayer = AudioStreamPlayer.new()
	fake_stinger.name = "music_fake_stinger"
	ar.add_child(fake_stinger)
	ar._current_stinger_player = fake_stinger

	# Act: try to play a second stinger — should drop.
	# We can't easily assert push_warning() output, but we CAN assert that
	# _current_stinger_player still points to the original (not replaced).
	ar._play_stinger(&"music_floor_clear_stinger")

	# Assert: stinger player is still the original fake node (not replaced).
	assert_object(ar._current_stinger_player).is_same(fake_stinger)

	# Cleanup
	ar._current_stinger_player = null
	fake_stinger.queue_free()


# ===========================================================================
# AC-AS-08 — Biome bed swap fires play_music on state_changed
# ===========================================================================

func test_run_state_active_foreground_triggers_biome_music() -> void:
	# Arrange: ensure DungeonRunOrchestrator has _dispatched_biome_id set.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	if orch == null or "_dispatched_biome_id" not in orch:
		# Can't test without orchestrator field — skip gracefully.
		assert_bool(true).is_true()
		return

	var saved_biome: String = str(orch._dispatched_biome_id)
	orch._dispatched_biome_id = "forest_reach"

	# Capture current ambient id before the call.
	var ambient_before: StringName = ar._current_ambient_id

	# Act: simulate transition to ACTIVE_FOREGROUND (state = 2).
	ar._on_run_state_changed(2, 0)

	# Assert: current ambient id changed to forest_reach bed.
	assert_str(str(ar._current_ambient_id)).is_equal("music_forest_reach_bed")

	# Cleanup
	orch._dispatched_biome_id = saved_biome
	ar.stop_music(0)  # immediate stop, no fade
	ar._current_ambient_id = ambient_before


func test_run_state_run_ended_returns_to_guild_hall_bed() -> void:
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	# Act: simulate RUN_ENDED (state = 4).
	ar._on_run_state_changed(4, 2)

	# Assert: guild hall bed selected.
	assert_str(str(ar._current_ambient_id)).is_equal("music_guild_hall_bed")

	# Cleanup
	ar.stop_music(0)
	ar._current_ambient_id = &""


func test_run_state_active_foreground_unknown_biome_falls_back_to_guild_hall() -> void:
	# Arrange: empty biome_id in orchestrator.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	if orch == null or "_dispatched_biome_id" not in orch:
		assert_bool(true).is_true()
		return

	var saved_biome: String = str(orch._dispatched_biome_id)
	orch._dispatched_biome_id = ""

	# Act
	ar._on_run_state_changed(2, 0)

	# Assert: falls back to guild hall
	assert_str(str(ar._current_ambient_id)).is_equal("music_guild_hall_bed")

	# Cleanup
	orch._dispatched_biome_id = saved_biome
	ar.stop_music(0)
	ar._current_ambient_id = &""


# ===========================================================================
# Floor clear — both SFX and Stinger wired (Story 5)
# ===========================================================================

func test_floor_cleared_plays_fanfare_sfx() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_floor_cleared_first_time(0, "forest_reach", false)

	assert_int(_count_plays(&"sfx_reward_floor_clear_fanfare")).is_equal(1)


func test_floor_cleared_fanfare_volume_mult_is_1_point_4() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_floor_cleared_first_time(0, "forest_reach", false)

	var entry: Dictionary = _last_play(&"sfx_reward_floor_clear_fanfare")
	assert_float(float(entry.get("volume_mult", 0.0))).is_equal_approx(1.4, 0.001)


# ===========================================================================
# Boss kill — distinct sample, volume_mult 1.4 (Story 3)
# ===========================================================================

func test_boss_killed_plays_boss_kill_sfx() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_boss_killed("ancient_wyrm")

	assert_int(_count_plays(&"sfx_combat_boss_kill")).is_equal(1)


func test_boss_killed_volume_mult_is_1_point_4() -> void:
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_boss_killed("lich_king")

	var entry: Dictionary = _last_play(&"sfx_combat_boss_kill")
	assert_float(float(entry.get("volume_mult", 0.0))).is_equal_approx(1.4, 0.001)


# ===========================================================================
# Prestige V1.0 (Sprint 21+ silent-MVP wiring) — completion fanfare handler
# Per audio-system.md §J: warm sting on retirement action; throttled 2.0s.
# ===========================================================================

func test_prestige_completed_handler_fires_play_sfx_with_volume_1_point_2() -> void:
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var record: Dictionary = {
		"display_name": "Theron",
		"class_id": "warrior",
		"level_at_retirement": 15,
		"prestige_index": 1,
	}

	# Act
	ar._on_prestige_completed(record, 1)

	# Assert: play_sfx called with the prestige cue id and volume_mult 1.2
	var entry: Dictionary = _last_play(&"sfx_prestige_completed")
	assert_int(_count_plays(&"sfx_prestige_completed")).is_equal(1)
	assert_float(float(entry.get("volume_mult", 0.0))).is_equal_approx(1.2, 0.001)


func test_prestige_completed_throttle_drops_rapid_second_call() -> void:
	# Defensive throttle: two emissions within 2.0s window → only the first plays.
	# Per audio-system.md §J prestige_audio_suppress_window_seconds = 2.0.
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var record: Dictionary = {
		"display_name": "Theron",
		"class_id": "warrior",
		"level_at_retirement": 15,
		"prestige_index": 1,
	}

	# Act — two back-to-back emissions inside the throttle window.
	ar._on_prestige_completed(record, 1)
	ar._on_prestige_completed(record, 2)

	# Assert: only one play_sfx entry was recorded.
	assert_int(_count_plays(&"sfx_prestige_completed")).is_equal(1)


func test_prestige_completed_throttle_releases_after_window() -> void:
	# Two emissions separated by manually advancing the throttle clock past the
	# window → both play. Verifies the throttle is window-based, not single-shot.
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var record: Dictionary = {
		"display_name": "Mira",
		"class_id": "mage",
		"level_at_retirement": 15,
		"prestige_index": 1,
	}

	# Act — first emission, then rewind the throttle clock past the 2s window.
	ar._on_prestige_completed(record, 1)
	# Move the clock back 3s (relative to the injected throttle clock) so the
	# next call is past the throttle window.
	ar._prestige_completed_last_played_ms = ar._throttle_now_ms() - 3000
	ar._on_prestige_completed(record, 2)

	# Assert: both plays recorded.
	assert_int(_count_plays(&"sfx_prestige_completed")).is_equal(2)


func test_prestige_completed_plays_at_low_engine_uptime() -> void:
	# Regression for the CI-green / local-dir-scoped-red prestige flake AND the
	# latent product bug behind it: a prestige fired while the throttle clock is
	# below the 2.0s window must still play its fanfare. Seed the last-played
	# clock to its production "never played" state (a value far in the past) and
	# pin the clock to 50ms ("just booted"); the first call must NOT be throttled.
	# Before the fix, last-played reset to 0 + an uptime below the window
	# suppressed this first call (0 plays).
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	ar._test_play_sfx_log.clear()
	# "Never played" — older than any throttle window, mirroring the production
	# member initializer (-_PRESTIGE_COMPLETED_THROTTLE_MS).
	ar._prestige_completed_last_played_ms = -1_000_000
	ar._throttle_now_override_ms = 50  # 50ms since boot, far below the 2.0s window
	var record: Dictionary = {
		"display_name": "Bram",
		"class_id": "warrior",
		"level_at_retirement": 12,
		"prestige_index": 1,
	}

	# Act
	ar._on_prestige_completed(record, 1)

	# Assert: the fanfare plays despite the clock (50ms) being below the window.
	assert_int(_count_plays(&"sfx_prestige_completed")).is_equal(1)


func test_audio_router_subscribes_to_prestige_completed_signal_at_ready() -> void:
	# Subscription contract: AudioRouter._ready() must connect HeroRoster's
	# prestige_completed_signal → _on_prestige_completed handler so emissions
	# from gameplay code reach the audio path without manual wiring.
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(roster).is_not_null()
	assert_bool(roster.has_signal("prestige_completed_signal")).is_true()

	# Assert: signal is connected to the handler.
	assert_bool(roster.prestige_completed_signal.is_connected(ar._on_prestige_completed)).is_true()


# ===========================================================================
# Demo music wiring — boss-floor bed + victory bed
# (Demo asset wiring: boss/victory music triggers)
# ===========================================================================

const _RunSnapshotForMusic = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")


func test_run_state_active_foreground_boss_floor_plays_boss_bed() -> void:
	# Arrange: dispatched to forest_reach floor 5 (is_boss_floor = true).
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	if orch == null or "_dispatched_biome_id" not in orch:
		assert_bool(true).is_true()
		return

	var saved_biome: String = str(orch._dispatched_biome_id)
	var saved_snapshot: Variant = orch.run_snapshot
	orch._dispatched_biome_id = "forest_reach"
	var snap: Variant = _RunSnapshotForMusic.new()
	snap.floor_id = "forest_reach_f5"
	orch.run_snapshot = snap

	# Act
	ar._on_run_state_changed(2, 0)

	# Assert: boss bed, NOT the forest_reach biome bed.
	assert_str(str(ar._current_ambient_id)).is_equal("music_boss_bed")

	# Cleanup
	orch._dispatched_biome_id = saved_biome
	orch.run_snapshot = saved_snapshot
	ar.stop_music(0)
	ar._current_ambient_id = &""


func test_run_state_active_foreground_non_boss_floor_plays_biome_bed() -> void:
	# Guard: a non-boss floor with a live snapshot must still take the biome bed
	# (the boss check must not false-positive).
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	if orch == null or "_dispatched_biome_id" not in orch:
		assert_bool(true).is_true()
		return

	var saved_biome: String = str(orch._dispatched_biome_id)
	var saved_snapshot: Variant = orch.run_snapshot
	orch._dispatched_biome_id = "forest_reach"
	var snap: Variant = _RunSnapshotForMusic.new()
	snap.floor_id = "forest_reach_f1"  # is_boss_floor = false
	orch.run_snapshot = snap

	# Act
	ar._on_run_state_changed(2, 0)

	# Assert
	assert_str(str(ar._current_ambient_id)).is_equal("music_forest_reach_bed")

	# Cleanup
	orch._dispatched_biome_id = saved_biome
	orch.run_snapshot = saved_snapshot
	ar.stop_music(0)
	ar._current_ambient_id = &""


func test_screen_changed_victory_moment_plays_victory_bed() -> void:
	# Arrange: not in an active run, victory_moment screen appears.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	var saved_state: int = 0
	if orch != null and "state" in orch:
		saved_state = int(orch.state)
		orch.state = 4  # RUN_ENDED — not ACTIVE_FOREGROUND, so the music path runs.

	# Act
	ar._on_screen_changed("victory_moment", "dungeon_run_view")

	# Assert
	assert_str(str(ar._current_ambient_id)).is_equal("music_victory_bed")

	# Cleanup
	if orch != null and "state" in orch:
		orch.state = saved_state
	ar.stop_music(0)
	ar._current_ambient_id = &""


func test_screen_changed_non_victory_screen_plays_guild_hall_bed() -> void:
	# Guard: a non-victory, non-dungeon screen still returns to the guild bed.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	var saved_state: int = 0
	if orch != null and "state" in orch:
		saved_state = int(orch.state)
		orch.state = 4

	# Act
	ar._on_screen_changed("recruitment", "guild_hall")

	# Assert
	assert_str(str(ar._current_ambient_id)).is_equal("music_guild_hall_bed")

	# Cleanup
	if orch != null and "state" in orch:
		orch.state = saved_state
	ar.stop_music(0)
	ar._current_ambient_id = &""


# ===========================================================================
# §C.2 — Panel-open SFX fires on screen entry (ADR-0022 asset now sourced)
# OQ-AS-6 deferral closed: ui_panel_open.tres wraps the generated cue, so the
# previously skipped panel-open trigger is now wired in _on_screen_changed.
# ===========================================================================

func test_screen_changed_plays_panel_open_sfx() -> void:
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	# Act: any non-empty screen entry should fire the panel-open whoosh.
	ar._on_screen_changed("recruitment", "guild_hall")

	# Assert: exactly one panel-open play recorded.
	assert_int(_count_plays(&"sfx_ui_panel_open")).is_equal(1)

	# Cleanup (the call also runs the music path).
	ar.stop_music(0)
	ar._current_ambient_id = &""


func test_screen_changed_panel_open_volume_mult_is_0_point_9() -> void:
	# §C.2 / _CUE_VOLUME_MULT_MAP: panel whoosh sits at 0.9, just under the tap chime.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_screen_changed("formation_editor", "guild_hall")

	var entry: Dictionary = _last_play(&"sfx_ui_panel_open")
	assert_float(float(entry.get("volume_mult", 0.0))).is_equal_approx(0.9, 0.001)

	# Cleanup
	ar.stop_music(0)
	ar._current_ambient_id = &""


func test_screen_changed_empty_screen_id_skips_panel_open_sfx() -> void:
	# Guard: the boot / no-op transition (empty new_screen_id) must NOT whoosh.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_screen_changed("", "guild_hall")

	assert_int(_count_plays(&"sfx_ui_panel_open")).is_equal(0)

	# Cleanup
	ar.stop_music(0)
	ar._current_ambient_id = &""


# ===========================================================================
# §C.2 — Panel-close SFX fires for the OUTGOING screen (ADR-0022 asset sourced)
# Mirror of the panel-open whoosh: the old screen folding away gets its own cue,
# guarded so the boot transition (no prior screen) stays silent.
# ===========================================================================

func test_screen_changed_plays_panel_close_sfx() -> void:
	# Arrange
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	# Act: a transition WITH a prior screen should fire the close whoosh.
	ar._on_screen_changed("recruitment", "guild_hall")

	# Assert: exactly one panel-close play recorded for the outgoing screen.
	assert_int(_count_plays(&"sfx_ui_panel_close")).is_equal(1)

	# Cleanup (the call also runs the music path).
	ar.stop_music(0)
	ar._current_ambient_id = &""


func test_screen_changed_panel_close_volume_mult_is_0_point_9() -> void:
	# §C.2 / _CUE_VOLUME_MULT_MAP: the close whoosh matches the open whoosh at 0.9
	# so neither side of a screen swap is louder than the other.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_screen_changed("formation_editor", "guild_hall")

	var entry: Dictionary = _last_play(&"sfx_ui_panel_close")
	assert_float(float(entry.get("volume_mult", 0.0))).is_equal_approx(0.9, 0.001)

	# Cleanup
	ar.stop_music(0)
	ar._current_ambient_id = &""


func test_screen_changed_empty_old_screen_id_skips_panel_close_sfx() -> void:
	# Guard: the boot transition (empty old_screen_id, no prior screen folding away)
	# must NOT fire the close whoosh — only the open whoosh for the first screen.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_screen_changed("guild_hall", "")

	assert_int(_count_plays(&"sfx_ui_panel_close")).is_equal(0)

	# Cleanup
	ar.stop_music(0)
	ar._current_ambient_id = &""


# ===========================================================================
# §C.2 — Combat advantage chime: one-shot-per-run on first advantaged kill
# Latch re-arms on ACTIVE_FOREGROUND entry (new run dispatched).
# ===========================================================================

func test_advantaged_kill_plays_advantage_chime_once() -> void:
	# Arrange: fresh run latch (reset in before_test).
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	# Act: a kill carrying a favourable matchup.
	ar._on_enemy_killed(2, "orc", true)

	# Assert: the advantage chime played exactly once.
	assert_int(_count_plays(&"sfx_combat_advantage_chime")).is_equal(1)


func test_advantage_chime_volume_mult_is_0_point_8() -> void:
	# §C.2 / _CUE_VOLUME_MULT_MAP: the chime sits at 0.8, under the kill chime.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_enemy_killed(2, "orc", true)

	var entry: Dictionary = _last_play(&"sfx_combat_advantage_chime")
	assert_float(float(entry.get("volume_mult", 0.0))).is_equal_approx(0.8, 0.001)


func test_non_advantaged_kill_does_not_play_advantage_chime() -> void:
	# Guard: a kill with no matchup edge must NOT fire the chime.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_enemy_killed(2, "orc", false)

	assert_int(_count_plays(&"sfx_combat_advantage_chime")).is_equal(0)


func test_advantage_chime_fires_only_once_across_multiple_advantaged_kills() -> void:
	# The latch makes the chime once-per-run: 3 advantaged kills → 1 chime
	# (unlike the kill chime, which overlaps per E.6).
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	ar._on_enemy_killed(1, "a", true)
	ar._on_enemy_killed(2, "b", true)
	ar._on_enemy_killed(3, "c", true)

	assert_int(_count_plays(&"sfx_combat_advantage_chime")).is_equal(1)


func test_advantage_chime_rearms_on_active_foreground() -> void:
	# A new run (ACTIVE_FOREGROUND entry) must re-arm the latch so the next run's
	# first advantaged kill fires the chime again — proving it is per-run, not
	# once-ever.
	var ar: Node = _get_ar()
	assert_object(ar).is_not_null()

	# Run 1: first advantaged kill fires the chime.
	ar._on_enemy_killed(2, "orc", true)
	assert_int(_count_plays(&"sfx_combat_advantage_chime")).is_equal(1)

	# New run dispatched — re-arms the latch (also runs the music path).
	ar._on_run_state_changed(2, 0)

	# Run 2: first advantaged kill fires the chime again → 2 total.
	ar._on_enemy_killed(2, "orc", true)
	assert_int(_count_plays(&"sfx_combat_advantage_chime")).is_equal(2)

	# Cleanup the music side-effect of the state change.
	ar.stop_music(0)
	ar._current_ambient_id = &""
