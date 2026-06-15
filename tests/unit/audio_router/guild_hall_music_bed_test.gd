# Sprint 28 — Guild Hall music bed real-asset net (ADR-0022).
#
# audio_cue_resolve_test.gd proves the GENERIC wiring contract with in-memory
# fixtures (no import needed). This suite proves the REAL shipped asset:
# assets/data/music/guild_hall_bed.tres loads, carries the DataRegistry id the
# AudioRouter resolve path expects, and — critically — wraps a LOOPING ogg.
#
# Why the loop assertion matters: play_music() does not force looping in code
# (stingers must NOT loop), so an ambient bed loops only if its .ogg import has
# loop=true. A bed imported with loop=false would play ~30s once and then leave
# the home screen permanently silent. This is the regression test for that bug.
#
# CI imports assets first (tests.yml "Prime Godot project import" → --import),
# so load() of the real committed resource resolves; precedent: biome_background
# tests load real .png assets the same way.
extends GdUnitTestSuite

const BED_TRES_PATH: String = "res://assets/data/music/guild_hall_bed.tres"


# AudioRouter requests &"music_guild_hall_bed"; play_music strips the "music_"
# prefix and resolves DataRegistry category "music" with id "guild_hall_bed".
# The shipped cue id MUST match that stripped id or the home-screen bed is silent.
func test_guild_hall_bed_cue_id_matches_audio_router_resolve_id() -> void:
	# Arrange + Act
	assert_bool(ResourceLoader.exists(BED_TRES_PATH)).is_true()
	var cue: Resource = load(BED_TRES_PATH)

	# Assert — AudioCue shape + the exact resolve id.
	assert_object(cue).is_not_null()
	assert_bool("id" in cue).is_true()
	assert_str(cue.id).is_equal("guild_hall_bed")


func test_guild_hall_bed_cue_wraps_a_non_null_stream() -> void:
	# Arrange + Act
	var cue: Resource = load(BED_TRES_PATH)

	# Assert — the wrapper references a playable stream (not "asset not sourced").
	assert_object(cue).is_not_null()
	assert_bool("stream" in cue).is_true()
	assert_object(cue.stream).is_not_null()
	assert_bool(cue.stream is AudioStream).is_true()


func test_guild_hall_bed_stream_loops() -> void:
	# Regression for the silent-after-30s bug: an ambient bed must loop. play_music
	# does not set loop in code, so this depends entirely on the .ogg import flag.
	# Arrange + Act
	var cue: Resource = load(BED_TRES_PATH)
	var stream: AudioStream = cue.stream

	# Assert — the imported ogg is a looping AudioStreamOggVorbis.
	assert_bool(stream is AudioStreamOggVorbis).is_true()
	assert_bool(stream.loop).is_true()
