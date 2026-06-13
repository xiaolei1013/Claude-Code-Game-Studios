# Sprint 28 — AudioCue wiring contract (ADR-0022, supersedes ADR-0016 silent-MVP).
#
# Proves the audio-asset wiring end-to-end WITHOUT requiring any imported audio
# file: a programmatic AudioCue (a GameData subclass carrying `id` + an in-memory
# AudioStreamWAV) is saved to a fixture tree, DataRegistry boots against it, and
# AudioRouter's resolve path extracts a playable AudioStream.
#
# This is the regression test ADR-0016's migration plan lacked. It would have
# caught that:
#   (a) a bare AudioStream .tres fails DataRegistry boot integrity (no `id` →
#       ERROR_INVALID_ID), and
#   (b) play_sfx / play_music's old `as AudioStream` cast cannot read an
#       id-carrying wrapper resource.
# See ADR-0022 and src/core/audio_router/audio_cue.gd.
#
# Fixture strategy mirrors resolve_api_and_typed_accessors_test.gd: programmatic
# .tres via ResourceSaver under res://tests/fixtures/, torn down in after_test().
extends GdUnitTestSuite

const DataRegistryScript = preload("res://src/core/data_registry/data_registry.gd")
const AudioRouterScript = preload("res://src/core/audio_router/audio_router.gd")
const AudioCueScript = preload("res://src/core/audio_router/audio_cue.gd")
const DataRegistryFixtures = preload("res://tests/fixtures/data_registry/fixture_helpers.gd")

const FIXTURE_ROOT: String = "res://tests/fixtures/data_registry/audio_cue/"


func after_test() -> void:
	DataRegistryFixtures.cleanup(FIXTURE_ROOT)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Writes an AudioCue .tres (wrapping an in-memory AudioStreamWAV — no asset
## import needed) at FIXTURE_ROOT/<category>/<cue_id>.tres.
func _write_audio_cue(category: String, cue_id: String) -> void:
	var dir_path: String = FIXTURE_ROOT + category
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var cue: AudioCueScript = AudioCueScript.new()
	cue.id = cue_id
	cue.display_name = cue_id
	cue.stream = AudioStreamWAV.new()  # in-memory placeholder stream
	var err: int = ResourceSaver.save(cue, "%s/%s.tres" % [dir_path, cue_id])
	assert_int(err).is_equal(OK)


## Boots a fresh DataRegistry pointed at FIXTURE_ROOT (idiom from
## resolve_api_and_typed_accessors_test.gd::_boot_registry).
func _boot_registry() -> Node:
	var dr: Node = DataRegistryScript.new()
	dr.data_root_path = FIXTURE_ROOT.trim_suffix("/")
	dr.min_content_count = {}
	dr._ready()
	return dr


func _make_router() -> Node:
	var router: Node = AudioRouterScript.new()
	add_child(router)
	auto_free(router)
	return router


# ===========================================================================
# Group A — AudioCue resource shape
# ===========================================================================

func test_audio_cue_carries_id_and_references_a_stream() -> void:
	# Arrange + Act
	var cue: AudioCueScript = AudioCueScript.new()
	cue.id = "ui_tap"
	cue.stream = AudioStreamWAV.new()

	# Assert — carries the DataRegistry `id` contract ...
	assert_bool("id" in cue).is_true()
	assert_str(cue.id).is_equal("ui_tap")
	# ... and references a playable stream.
	assert_bool("stream" in cue).is_true()
	assert_object(cue.stream).is_not_null()
	assert_bool(cue.stream is AudioStream).is_true()


# ===========================================================================
# Group B — DataRegistry indexes AudioCue (closes the ADR-0016 migration gap)
# ===========================================================================

func test_data_registry_resolves_sfx_audio_cue_to_playable_stream() -> void:
	# Arrange
	_write_audio_cue("sfx", "ui_tap")
	var dr: Node = _boot_registry()
	auto_free(dr)

	# Act
	var resolved: Resource = dr.resolve("sfx", "ui_tap")

	# Assert — AudioCue indexed (NOT rejected as ERROR_INVALID_ID) ...
	assert_object(resolved).is_not_null()
	assert_str(resolved.id).is_equal("ui_tap")
	# ... and exposes a non-null playable stream.
	assert_object(resolved.stream).is_not_null()
	assert_bool(resolved.stream is AudioStream).is_true()


func test_data_registry_resolves_music_audio_cue_to_playable_stream() -> void:
	# Arrange
	_write_audio_cue("music", "guild_hall_bed")
	var dr: Node = _boot_registry()
	auto_free(dr)

	# Act
	var resolved: Resource = dr.resolve("music", "guild_hall_bed")

	# Assert
	assert_object(resolved).is_not_null()
	assert_str(resolved.id).is_equal("guild_hall_bed")
	assert_object(resolved.stream).is_not_null()


# ===========================================================================
# Group C — AudioRouter._stream_from_resolved extraction contract
# ===========================================================================

func test_stream_from_resolved_null_returns_null() -> void:
	var router: Node = _make_router()
	assert_object(router._stream_from_resolved(null)).is_null()


func test_stream_from_resolved_audio_cue_returns_inner_stream() -> void:
	# Arrange
	var router: Node = _make_router()
	var cue: AudioCueScript = AudioCueScript.new()
	var inner: AudioStream = AudioStreamWAV.new()
	cue.stream = inner

	# Act
	var got: AudioStream = router._stream_from_resolved(cue)

	# Assert — the wrapper's inner stream is returned (identity).
	assert_object(got).is_not_null()
	assert_bool(got == inner).is_true()


func test_stream_from_resolved_bare_audiostream_returned_as_is() -> void:
	# Arrange
	var router: Node = _make_router()
	var bare: AudioStream = AudioStreamWAV.new()

	# Act + Assert — tolerant of a bare stream resource.
	assert_bool(router._stream_from_resolved(bare) == bare).is_true()


func test_stream_from_resolved_non_audio_resource_returns_null() -> void:
	# A resolved resource with no `stream` property must not crash — returns null.
	var router: Node = _make_router()
	var other: Resource = Resource.new()
	assert_object(router._stream_from_resolved(other)).is_null()


func test_stream_from_resolved_audio_cue_with_null_stream_returns_null() -> void:
	# ADR-0022 silent-skip contract: an AudioCue whose asset is not yet sourced
	# (stream left at its null default) resolves to null — NOT a crash. The router
	# treats null as "asset not yet sourced" and skips playback silently. Without
	# this the defensive branch the doc comment promises could regress unnoticed.
	# Arrange
	var router: Node = _make_router()
	var cue: AudioCueScript = AudioCueScript.new()
	cue.id = "not_yet_sourced"
	# cue.stream intentionally left at its null default.

	# Act + Assert
	assert_object(router._stream_from_resolved(cue)).is_null()
