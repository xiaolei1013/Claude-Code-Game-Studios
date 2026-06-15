# Sprint 28 — Dungeon/boss/victory music beds + floor-clear stinger real-asset net (ADR-0022).
#
# Companion to guild_hall_music_bed_test.gd (which covers the home-screen bed).
# This suite proves the 9 REAL shipped music assets the AudioRouter triggers:
#   - 6 biome beds, one per real biome data id. AudioRouter resolves the cue id
#     dynamically as "music_" + biome_id + "_bed" (_on_run_state_changed), so the
#     shipped cue ids MUST match the biome ids in assets/data/biomes/*.tres.
#   - boss_bed   (boss-floor override, _on_run_state_changed)
#   - victory_bed (victory_moment screen, _on_screen_changed)
#   - floor_clear_stinger (one-shot reward stinger, _on_floor_cleared_first_time)
#
# Each AudioCue .tres must load, carry the DataRegistry id the resolve path expects,
# and have the CORRECT loop flag. play_music() does NOT set loop in code, so the
# flag depends entirely on each .ogg's import setting:
#   - beds MUST loop — a bed imported loop=false plays ~30 s once then leaves the
#     screen permanently silent (the guild-hall silent-after-30s regression).
#   - the stinger MUST NOT loop — §C.3 requires a "settled tail; it ends; it does
#     not pulse, repeat, or escalate". A looping reward stinger would repeat forever.
#
# CI imports assets first (tests.yml "Prime Godot project import" → --import), so
# load() of the real committed resources resolves; precedent: guild_hall_music_bed
# and biome_background tests load real committed assets the same way.
extends GdUnitTestSuite

# DataRegistry id (cue prefix stripped) -> should_loop. The .tres lives at
# assets/data/music/<id>.tres. Beds loop; the floor-clear stinger does not.
const MUSIC_CUES: Dictionary = {
	"forest_reach_bed": true,
	"frostmire_bed": true,
	"sunken_ruins_bed": true,
	"whispering_crags_bed": true,
	"ember_wastes_bed": true,
	"hollow_stair_bed": true,
	"boss_bed": true,
	"victory_bed": true,
	"floor_clear_stinger": false,
}


func _tres_path(cue_id: String) -> String:
	return "res://assets/data/music/%s.tres" % cue_id


# AudioRouter requests &"music_<id>"; play_music strips the "music_" prefix and
# resolves DataRegistry category "music" with that id. The shipped cue id MUST
# match or the cue is silent. (Biome beds additionally must match a real biome id.)
func test_all_music_cue_tres_exist_and_carry_matching_id() -> void:
	for cue_id: String in MUSIC_CUES:
		var path: String = _tres_path(cue_id)
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"Missing AudioCue .tres for '%s' at %s" % [cue_id, path]).is_true()
		var cue: Resource = load(path)
		assert_object(cue).is_not_null()
		assert_bool("id" in cue).is_true()
		assert_str(cue.id).override_failure_message(
			"Cue id mismatch at %s" % path).is_equal(cue_id)


func test_all_music_cues_wrap_non_null_stream() -> void:
	for cue_id: String in MUSIC_CUES:
		var cue: Resource = load(_tres_path(cue_id))
		assert_object(cue).is_not_null()
		assert_bool("stream" in cue).is_true()
		assert_object(cue.stream).override_failure_message(
			"Null stream for %s — asset not sourced" % cue_id).is_not_null()
		assert_bool(cue.stream is AudioStream).is_true()


func test_beds_loop_and_stinger_does_not() -> void:
	# Regression for the silent-after-30s bug (beds) and the runaway-stinger bug
	# (stinger). Depends entirely on each .ogg's import loop flag.
	for cue_id: String in MUSIC_CUES:
		var should_loop: bool = MUSIC_CUES[cue_id]
		var cue: Resource = load(_tres_path(cue_id))
		var stream: AudioStream = cue.stream
		assert_bool(stream is AudioStreamOggVorbis).override_failure_message(
			"%s stream is not an AudioStreamOggVorbis" % cue_id).is_true()
		assert_bool(stream.loop == should_loop).override_failure_message(
			"%s loop flag is %s, expected %s" % [cue_id, stream.loop, should_loop]).is_true()
