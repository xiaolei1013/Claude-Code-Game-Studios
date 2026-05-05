# Sprint 11 S11-S2: AudioRouter autoload skeleton + bus layout + signal-sub tests.
#
# Verifies:
#   - Autoload exists at /root/AudioRouter (rank 16 per ADR-0003 Amendment #5).
#   - audio_bus_layout.tres registered: 8 buses present in the expected hierarchy.
#   - Default volumes per audio-system.md §C.1 + §G.
#   - Volume API round-trip: set_*_volume_db writes through to AudioServer.
#   - Mute behavior: set_master_muted(true) drives Master to -INF.
#   - Save consumer round-trip: get_save_data → load_save_data restores volumes.
#   - Signal subscriptions wired at _ready() for the 6 signal sources required
#     by audio-system.md §F (SceneManager, DungeonRunOrchestrator state/kill/
#     boss/floor-clear, HeroRoster, Economy).
#
# Sprint 11 S11-S2 scope is SKELETON only; signal handler bodies are STUBS and
# play_sfx / play_music return cleanly without effect. Sprint 12+ Story 3-5
# implements actual cue plays.
#
# Test pattern: read the live AudioRouter autoload + AudioServer state. The
# autoload is shared across all tests in this run; before_test resets volumes
# to defaults so no test contaminates another (S10-S4 hygiene-barrier pattern).
extends GdUnitTestSuite

const AudioRouterScript = preload("res://src/core/audio_router/audio_router.gd")


# ---------------------------------------------------------------------------
# Hygiene barrier per S10-S4 lesson — reset live autoload to defaults
# before AND after each test so this suite is order-independent.
# ---------------------------------------------------------------------------

func _reset_audio_router_to_defaults() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	if ar == null:
		return
	# Defaults from audio_router.gd _DEFAULT_* constants.
	ar.set_master_muted(false)
	ar.set_master_volume_db(0.0)
	ar.set_music_volume_db(-8.0)
	ar.set_sfx_volume_db(-3.0)


func before_test() -> void:
	_reset_audio_router_to_defaults()


func after_test() -> void:
	_reset_audio_router_to_defaults()


# ===========================================================================
# Group A — autoload + bus hierarchy
# ===========================================================================

func test_audio_router_autoload_resolves_at_root() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	assert_object(ar).is_not_null()
	# Verify the script attached is audio_router.gd.
	assert_bool(ar.get_script() == AudioRouterScript).is_true()


func test_audio_router_registered_in_project_godot() -> void:
	# Per ADR-0003 §Editing Protocol, lockstep edits must include project.godot.
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load("res://project.godot")
	assert_int(err).is_equal(OK)
	var path: String = cfg.get_value("autoload", "AudioRouter", "")
	assert_str(path).is_equal("*res://src/core/audio_router/audio_router.gd")


func test_audio_router_appears_after_dungeon_run_orchestrator_in_project_godot() -> void:
	# Rank 16 = appended after rank 15 OfflineProgressionEngine, but
	# OfflineProgressionEngine is not yet registered as an autoload (Sprint 12+).
	# So in the current project.godot, AudioRouter sits after DungeonRunOrchestrator
	# (rank 14) which is the last currently-registered autoload.
	var file: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var idx_orch: int = content.find("DungeonRunOrchestrator=")
	var idx_audio: int = content.find("AudioRouter=")
	assert_int(idx_orch).is_greater(0)
	assert_int(idx_audio).is_greater(idx_orch)


func test_audio_bus_layout_registers_all_eight_buses() -> void:
	# Lock the 8-bus hierarchy from audio_bus_layout.tres.
	# AudioServer.get_bus_count() returns >= 8 (other systems may register
	# additional buses dynamically, but we authored 8 in the layout).
	assert_int(AudioServer.get_bus_count()).is_greater_equal(8)
	# Resolve each named bus.
	assert_int(AudioServer.get_bus_index("Master")).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index("Music")).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index("Music/Ambient")).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index("Music/Stinger")).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index("SFX")).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index("SFX/UI")).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index("SFX/Combat")).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index("SFX/Reward")).is_greater_equal(0)


# ===========================================================================
# Group B — default volumes per audio-system.md §G
# ===========================================================================

func test_audio_router_master_default_is_zero_db() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	assert_float(ar.get_master_volume_db()).is_equal_approx(0.0, 0.001)


func test_audio_router_music_default_is_minus_eight_db() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	assert_float(ar.get_music_volume_db()).is_equal_approx(-8.0, 0.001)


func test_audio_router_sfx_default_is_minus_three_db() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	assert_float(ar.get_sfx_volume_db()).is_equal_approx(-3.0, 0.001)


func test_audio_router_master_default_is_unmuted() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	assert_bool(ar.is_master_muted()).is_false()


# ===========================================================================
# Group C — volume API round-trip to AudioServer
# ===========================================================================

func test_audio_router_set_master_volume_db_writes_to_audio_server() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	ar.set_master_volume_db(-12.0)
	var bus_idx: int = AudioServer.get_bus_index("Master")
	assert_float(AudioServer.get_bus_volume_db(bus_idx)).is_equal_approx(-12.0, 0.001)


func test_audio_router_set_music_volume_db_writes_to_audio_server() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	ar.set_music_volume_db(-15.0)
	var bus_idx: int = AudioServer.get_bus_index("Music")
	assert_float(AudioServer.get_bus_volume_db(bus_idx)).is_equal_approx(-15.0, 0.001)


func test_audio_router_set_sfx_volume_db_writes_to_audio_server() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	ar.set_sfx_volume_db(2.5)
	var bus_idx: int = AudioServer.get_bus_index("SFX")
	assert_float(AudioServer.get_bus_volume_db(bus_idx)).is_equal_approx(2.5, 0.001)


# ===========================================================================
# Group D — mute behavior (audio-system.md §E.5: hard mute, no fade)
# ===========================================================================

func test_audio_router_set_master_muted_drives_master_to_neg_inf() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	ar.set_master_volume_db(-6.0)  # explicit non-default to confirm mute overrides
	ar.set_master_muted(true)
	var bus_idx: int = AudioServer.get_bus_index("Master")
	# AudioServer represents -INF as a very large negative; check < -100 dB.
	assert_float(AudioServer.get_bus_volume_db(bus_idx)).is_less(-100.0)


func test_audio_router_unmute_restores_cached_volume() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	ar.set_master_volume_db(-6.0)
	ar.set_master_muted(true)
	# Now unmute — Master returns to -6.0.
	ar.set_master_muted(false)
	var bus_idx: int = AudioServer.get_bus_index("Master")
	assert_float(AudioServer.get_bus_volume_db(bus_idx)).is_equal_approx(-6.0, 0.001)


# ===========================================================================
# Group E — save consumer round-trip
# ===========================================================================

func test_audio_router_get_save_data_returns_canonical_schema() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	ar.set_master_volume_db(-4.0)
	ar.set_music_volume_db(-10.0)
	ar.set_sfx_volume_db(0.5)
	ar.set_master_muted(true)

	var data: Dictionary = ar.get_save_data()
	# Lock the canonical key set (audio-system.md §C.7).
	assert_bool(data.has("master_volume_db")).is_true()
	assert_bool(data.has("music_volume_db")).is_true()
	assert_bool(data.has("sfx_volume_db")).is_true()
	assert_bool(data.has("master_muted")).is_true()
	assert_float(float(data["master_volume_db"])).is_equal_approx(-4.0, 0.001)
	assert_float(float(data["music_volume_db"])).is_equal_approx(-10.0, 0.001)
	assert_float(float(data["sfx_volume_db"])).is_equal_approx(0.5, 0.001)
	assert_bool(bool(data["master_muted"])).is_true()


func test_audio_router_load_save_data_restores_state() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")

	var saved: Dictionary = {
		"master_volume_db": -6.5,
		"music_volume_db": -12.0,
		"sfx_volume_db": 1.5,
		"master_muted": false,
	}
	ar.load_save_data(saved)

	assert_float(ar.get_master_volume_db()).is_equal_approx(-6.5, 0.001)
	assert_float(ar.get_music_volume_db()).is_equal_approx(-12.0, 0.001)
	assert_float(ar.get_sfx_volume_db()).is_equal_approx(1.5, 0.001)
	assert_bool(ar.is_master_muted()).is_false()


func test_audio_router_load_save_data_falls_back_to_defaults_on_missing_fields() -> void:
	# audio-system.md §E.2: per-field defensive defaults on missing keys.
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")

	# Pass an empty dict; all fields should fall back to defaults.
	ar.load_save_data({})

	assert_float(ar.get_master_volume_db()).is_equal_approx(0.0, 0.001)
	assert_float(ar.get_music_volume_db()).is_equal_approx(-8.0, 0.001)
	assert_float(ar.get_sfx_volume_db()).is_equal_approx(-3.0, 0.001)
	assert_bool(ar.is_master_muted()).is_false()


# ===========================================================================
# Group F — signal subscriptions wired at _ready (audio-system.md §F)
# ===========================================================================

func test_audio_router_subscribed_to_scene_manager_screen_changed() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(sm).is_not_null()
	assert_bool(sm.screen_changed.is_connected(ar._on_screen_changed)).is_true()


func test_audio_router_subscribed_to_dungeon_run_orchestrator_signals() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	assert_object(orch).is_not_null()
	assert_bool(orch.state_changed.is_connected(ar._on_run_state_changed)).is_true()
	assert_bool(orch.enemy_killed.is_connected(ar._on_enemy_killed)).is_true()
	assert_bool(orch.boss_killed.is_connected(ar._on_boss_killed)).is_true()
	assert_bool(orch.floor_cleared_first_time.is_connected(ar._on_floor_cleared_first_time)).is_true()


func test_audio_router_subscribed_to_hero_roster_hero_leveled() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	var roster: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(roster).is_not_null()
	assert_bool(roster.hero_leveled.is_connected(ar._on_hero_leveled)).is_true()


func test_audio_router_subscribed_to_economy_gold_changed() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	var econ: Node = get_tree().root.get_node_or_null("Economy")
	assert_object(econ).is_not_null()
	assert_bool(econ.gold_changed.is_connected(ar._on_gold_changed)).is_true()


# ===========================================================================
# Group G — manual cue API stubs (Sprint 11 STUBs; Sprint 12+ implements)
# ===========================================================================

func test_audio_router_play_sfx_does_not_crash_on_unknown_id() -> void:
	# Sprint 11 S11-S2: STUB. The body is `pass`; just verifies it's callable
	# without crashing. Sprint 12+ Story 3 replaces with actual cue play.
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	ar.play_sfx(&"sfx_unknown_test_id")
	assert_bool(true).is_true()


func test_audio_router_play_music_does_not_crash_on_unknown_id() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	ar.play_music(&"music_unknown_test_id")
	assert_bool(true).is_true()


func test_audio_router_stop_music_does_not_crash() -> void:
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	ar.stop_music()
	assert_bool(true).is_true()
