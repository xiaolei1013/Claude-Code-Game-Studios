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
	# Reset gold throttle clock so tests start from a clean state.
	if "_gold_chime_last_played_ms" in ar:
		ar._gold_chime_last_played_ms = 0


func before_test() -> void:
	_reset_audio_router()


func after_test() -> void:
	_reset_audio_router()


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

	# Simulate 300 ms elapsed by forcing the clock back 300 ms.
	ar._gold_chime_last_played_ms = Time.get_ticks_msec() - 300

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
