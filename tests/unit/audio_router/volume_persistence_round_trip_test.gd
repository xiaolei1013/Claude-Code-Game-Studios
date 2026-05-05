# Sprint 11 S11-S3: AudioRouter volume-persistence round-trip tests.
#
# Covers AC-AS-09 from audio-system.md §H:
#   "AudioRouter.set_master_volume_db(-12) followed by
#    SaveLoadSystem.request_full_persist('audio_settings_changed'),
#    app restart, SaveLoadSystem load + AudioRouter.load_save_data(d)
#    invocation results in AudioServer.get_bus_volume_db('Master') == -12
#    (±0.01 dB). Defaults apply only on first launch / corrupt save /
#    per-field corruption (defaults applied via d.get('master_volume_db', 0.0)
#    fallback)."
#
# Pure-unit scope: tests AudioRouter.get_save_data → load_save_data → AudioServer
# round-trip directly (without SaveLoadSystem). The SaveLoadSystem-side
# integration (request_full_persist enumerates CONSUMER_PATHS, includes
# /root/AudioRouter, calls its get_save_data, persists, load reads back,
# calls load_save_data) is exercised by the existing request_full_persist
# tests + the sentinel test that locks the CONSUMER_PATHS membership.
extends GdUnitTestSuite

const AudioRouterScript = preload("res://src/core/audio_router/audio_router.gd")
const _BUS_MASTER: StringName = &"Master"
const _BUS_MUSIC: StringName = &"Music"
const _BUS_SFX: StringName = &"SFX"


func _make_audio_router() -> Node:
	var ar: Node = AudioRouterScript.new()
	add_child(ar)
	auto_free(ar)
	return ar


func before_test() -> void:
	# Hygiene barrier: reset AudioServer Master to 0 dB before each test
	# so prior-test residue does not leak. Mirrors the S10-S4 reset pattern.
	var master_idx: int = AudioServer.get_bus_index(_BUS_MASTER)
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, 0.0)


# ===========================================================================
# Group A — round-trip behavior (the AC-AS-09 contract)
# ===========================================================================

func test_master_volume_set_then_save_load_round_trip_preserves_value() -> void:
	# Arrange — AudioRouter A: set master to -12.
	var ar_a: Node = _make_audio_router()
	ar_a.set_master_volume_db(-12.0)

	# Act 1 — capture save data from A.
	var data: Dictionary = ar_a.get_save_data()

	# Sanity: save dict carries the changed value.
	assert_float(float(data["master_volume_db"])).is_equal_approx(-12.0, 0.001)

	# Act 2 — fresh AudioRouter B (simulating app restart) loads A's data.
	var ar_b: Node = _make_audio_router()
	# Sanity: AudioRouter B's defaults haven't been mutated yet.
	assert_float(ar_b.get_master_volume_db()).is_equal_approx(0.0, 0.001)

	ar_b.load_save_data(data)

	# Assert — AudioRouter B reflects the loaded value AND has applied to
	# AudioServer (load_save_data calls _apply_to_audio_server internally).
	assert_float(ar_b.get_master_volume_db()).is_equal_approx(-12.0, 0.001)
	var master_idx: int = AudioServer.get_bus_index(_BUS_MASTER)
	assert_float(AudioServer.get_bus_volume_db(master_idx)).is_equal_approx(-12.0, 0.01)


func test_music_volume_round_trip() -> void:
	var ar_a: Node = _make_audio_router()
	ar_a.set_music_volume_db(-15.0)

	var data: Dictionary = ar_a.get_save_data()

	var ar_b: Node = _make_audio_router()
	ar_b.load_save_data(data)

	assert_float(ar_b.get_music_volume_db()).is_equal_approx(-15.0, 0.001)
	var music_idx: int = AudioServer.get_bus_index(_BUS_MUSIC)
	if music_idx >= 0:
		assert_float(AudioServer.get_bus_volume_db(music_idx)).is_equal_approx(-15.0, 0.01)


func test_sfx_volume_round_trip() -> void:
	var ar_a: Node = _make_audio_router()
	ar_a.set_sfx_volume_db(-6.0)

	var data: Dictionary = ar_a.get_save_data()

	var ar_b: Node = _make_audio_router()
	ar_b.load_save_data(data)

	assert_float(ar_b.get_sfx_volume_db()).is_equal_approx(-6.0, 0.001)
	var sfx_idx: int = AudioServer.get_bus_index(_BUS_SFX)
	if sfx_idx >= 0:
		assert_float(AudioServer.get_bus_volume_db(sfx_idx)).is_equal_approx(-6.0, 0.01)


func test_master_muted_round_trip() -> void:
	var ar_a: Node = _make_audio_router()
	ar_a.set_master_volume_db(-4.0)
	ar_a.set_master_muted(true)

	var data: Dictionary = ar_a.get_save_data()
	assert_bool(bool(data["master_muted"])).is_true()

	var ar_b: Node = _make_audio_router()
	ar_b.load_save_data(data)

	assert_bool(ar_b.is_master_muted()).is_true()
	# Mute = -INF on Master bus per audio-system.md §E.5 (no fade).
	var master_idx: int = AudioServer.get_bus_index(_BUS_MASTER)
	assert_float(AudioServer.get_bus_volume_db(master_idx)).is_less(-100.0)


func test_all_four_fields_round_trip_in_one_load() -> void:
	# Realistic Settings-screen flow: player tweaks all 4 knobs, save persists,
	# app restarts, all 4 restore in one load_save_data call.
	var ar_a: Node = _make_audio_router()
	ar_a.set_master_volume_db(-3.0)
	ar_a.set_music_volume_db(-9.0)
	ar_a.set_sfx_volume_db(-5.0)
	ar_a.set_master_muted(false)

	var data: Dictionary = ar_a.get_save_data()

	var ar_b: Node = _make_audio_router()
	ar_b.load_save_data(data)

	assert_float(ar_b.get_master_volume_db()).is_equal_approx(-3.0, 0.001)
	assert_float(ar_b.get_music_volume_db()).is_equal_approx(-9.0, 0.001)
	assert_float(ar_b.get_sfx_volume_db()).is_equal_approx(-5.0, 0.001)
	assert_bool(ar_b.is_master_muted()).is_false()


# ===========================================================================
# Group B — defaults on missing / corrupt fields (AC-AS-09 second clause)
# ===========================================================================

func test_load_with_empty_dict_applies_all_defaults() -> void:
	# First-launch / corrupt-save scenario per audio-system.md §E.2.
	var ar: Node = _make_audio_router()
	# Pre-mutate so we can verify defaults overwrite.
	ar.set_master_volume_db(-50.0)
	ar.set_master_muted(true)

	ar.load_save_data({})

	# Defaults per audio-system.md §C.1 (master=0, music=-8, sfx=-3).
	assert_float(ar.get_master_volume_db()).is_equal_approx(0.0, 0.001)
	assert_float(ar.get_music_volume_db()).is_equal_approx(-8.0, 0.001)
	assert_float(ar.get_sfx_volume_db()).is_equal_approx(-3.0, 0.001)
	assert_bool(ar.is_master_muted()).is_false()


func test_load_with_partial_dict_uses_defaults_for_missing_fields() -> void:
	# Per-field corruption: only master_volume_db survives the save read;
	# music + sfx + mute fall back to defaults.
	var ar: Node = _make_audio_router()
	ar.load_save_data({"master_volume_db": -7.0})

	assert_float(ar.get_master_volume_db()).is_equal_approx(-7.0, 0.001)
	# Missing fields → defaults.
	assert_float(ar.get_music_volume_db()).is_equal_approx(-8.0, 0.001)
	assert_float(ar.get_sfx_volume_db()).is_equal_approx(-3.0, 0.001)
	assert_bool(ar.is_master_muted()).is_false()


# ===========================================================================
# Group C — CONSUMER_PATHS membership lock (S11-S3 lockstep)
# ===========================================================================

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")


func test_audio_router_is_registered_in_save_load_consumer_paths() -> void:
	# Locks the S11-S3 lockstep edit. AudioRouter must be in CONSUMER_PATHS
	# so request_full_persist enumeration includes it for AC-AS-09 round-trip.
	var paths: PackedStringArray = SaveLoadScript.CONSUMER_PATHS
	var has_audio: bool = false
	for path: String in paths:
		if path == "/root/AudioRouter":
			has_audio = true
			break
	assert_bool(has_audio).is_true()


func test_audio_router_is_last_in_consumer_paths_order() -> void:
	# AudioRouter rank 16 = last autoload + last in CONSUMER_PATHS by
	# convention. Adding it last preserves index-3 crash-point semantics
	# for existing happy-path-deferral tests.
	var paths: PackedStringArray = SaveLoadScript.CONSUMER_PATHS
	assert_str(paths[paths.size() - 1]).is_equal("/root/AudioRouter")
