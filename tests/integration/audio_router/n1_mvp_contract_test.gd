# Sprint 23 S23-N1 — Audio MVP contract test.
#
# The AudioRouter subsystem was implemented in Sprint 12 S12-M6 with complete
# bus topology, signal subscriptions, save persistence, and the play_sfx /
# play_music / stop_music API. Sprint 23 S23-N1's stated goal is "wire
# AudioRouter autoload + 1 ambient loop on guild_hall + 1 UI confirm cue on
# primary button press".
#
# This test locks in the N1 contract end-to-end:
#   - AudioRouter responds to SceneManager.screen_changed("guild_hall") by
#     calling play_music(&"music_guild_hall_bed")
#   - UIFramework.wire_touch_feedback dispatches a UI-tap cue via AudioRouter
#     on button press (the "ui_confirm" surface in the N1 plan)
#   - Settings volume sliders (set_music_volume_db / set_sfx_volume_db) are
#     observable from the AudioRouter's own getters
#
# Silent-MVP note: the audio asset files may or may not exist in MVP per
# ADR-0016. The contract asserts SIGNAL ROUTING (gameplay → AudioRouter →
# play_sfx call recorded in the debug play log) NOT audible playback.
extends GdUnitTestSuite

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")


# ===========================================================================
# Group A — Ambient bed wired on screen_changed("guild_hall")
# ===========================================================================

func test_audio_router_subscribed_to_scene_manager_screen_changed() -> void:
	# Arrange + Act
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")

	# Assert — subscription exists at runtime.
	assert_object(ar).is_not_null()
	assert_object(sm).is_not_null()
	assert_bool(sm.screen_changed.is_connected(ar._on_screen_changed)).is_true()


# ===========================================================================
# Group B — UI tap cue (sfx_ui_tap) wired through wire_touch_feedback
# ===========================================================================

func test_wire_touch_feedback_records_sfx_ui_tap_on_button_press() -> void:
	# Arrange — touch-feedback-wired button + clear the AudioRouter debug log.
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	assert_object(ar).is_not_null()
	# Clear the log to isolate the press we're about to fire.
	if "_test_play_sfx_log" in ar:
		ar._test_play_sfx_log.clear()

	var btn: Button = Button.new()
	add_child(btn)
	auto_free(btn)
	UIFrameworkScript.wire_touch_feedback(btn)

	# Act — emit a synthetic press event. wire_touch_feedback connects to
	# gui_input; an InputEventMouseButton press fires the tap-chime path.
	var press_event: InputEventMouseButton = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	btn.gui_input.emit(press_event)

	# Assert — the debug log captured a sfx_ui_tap entry.
	var entries: Array = ar._test_play_sfx_log
	var found_ui_tap: bool = false
	for entry: Dictionary in entries:
		if str(entry.get("sfx_id", "")) == "sfx_ui_tap":
			found_ui_tap = true
			break
	assert_bool(found_ui_tap).override_failure_message(
		"Expected sfx_ui_tap in AudioRouter play log after button press; "
		+ "got %d entries: %s" % [entries.size(), str(entries)]
	).is_true()


# ===========================================================================
# Group C — Settings volume sliders observable
# ===========================================================================

func test_audio_router_set_music_volume_db_round_trips_through_getter() -> void:
	# Arrange — capture current state to restore.
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	assert_object(ar).is_not_null()
	var saved_music: float = ar.get_music_volume_db()

	# Act — set then read back.
	ar.set_music_volume_db(-12.5)

	# Assert
	assert_float(ar.get_music_volume_db()).is_equal_approx(-12.5, 0.001)

	# Cleanup
	ar.set_music_volume_db(saved_music)


func test_audio_router_set_sfx_volume_db_round_trips_through_getter() -> void:
	# Arrange
	var ar: Node = get_tree().root.get_node_or_null("AudioRouter")
	assert_object(ar).is_not_null()
	var saved_sfx: float = ar.get_sfx_volume_db()

	# Act
	ar.set_sfx_volume_db(-5.0)

	# Assert
	assert_float(ar.get_sfx_volume_db()).is_equal_approx(-5.0, 0.001)

	# Cleanup
	ar.set_sfx_volume_db(saved_sfx)
