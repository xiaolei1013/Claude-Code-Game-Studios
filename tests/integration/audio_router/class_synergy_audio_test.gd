# Sprint 21 S21-S2 / Class Synergy V1.0 Story 3 — audio + locale integration.
#
# Per design/gdd/class-synergy-system.md §C.4 + AC-CS-14 + AC-CS-15:
# AudioRouter subscribes to class_synergy_detected_signal (FormationAssignment)
# + class_synergy_dispatched_signal (DungeonRunOrchestrator). Detection chime
# is throttled to 1 play per 2.0s window (AC-CS-14); dispatch chime is
# unthrottled (rate-limited by orchestrator's DISPATCH_DEBOUNCE_MS).
#
# Locale keys (AC-CS-15): 6 new keys in assets/locale/en.csv.
#
# Test groups:
#   A — Signal declarations on FormationAssignment + DungeonRunOrchestrator
#   B — FormationAssignment.notify_synergy_detected emit contract
#       (idempotent on empty; emits on non-empty)
#   C — AudioRouter detection chime throttle (AC-CS-14)
#   D — Locale keys present in en.csv (AC-CS-15)
#       (key-existence check via TranslationServer)
extends GdUnitTestSuite

const FormationAssignmentScript = preload("res://src/core/formation_assignment/formation_assignment.gd")
const DungeonRunOrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const AudioRouterScript = preload("res://src/core/audio_router/audio_router.gd")


func _make_fa() -> Node:
	var fa: Node = FormationAssignmentScript.new()
	add_child(fa)
	auto_free(fa)
	return fa


func _make_orch() -> Node:
	var orch: Node = DungeonRunOrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


func _make_router() -> Node:
	var router: Node = AudioRouterScript.new()
	add_child(router)
	auto_free(router)
	return router


# ===========================================================================
# Group A — Signal declarations
# ===========================================================================

func test_formation_assignment_declares_class_synergy_detected_signal() -> void:
	var fa: Node = _make_fa()
	assert_bool(fa.has_signal("class_synergy_detected_signal")).is_true()


func test_dungeon_run_orchestrator_declares_class_synergy_dispatched_signal() -> void:
	var orch: Node = _make_orch()
	assert_bool(orch.has_signal("class_synergy_dispatched_signal")).is_true()


# ===========================================================================
# Group B — notify_synergy_detected emit contract
# ===========================================================================

var _detected_emissions: Array[String] = []


func _on_detected(synergy_id: String) -> void:
	_detected_emissions.append(synergy_id)


func test_notify_synergy_detected_emits_when_synergy_id_is_non_empty() -> void:
	# Arrange
	var fa: Node = _make_fa()
	_detected_emissions.clear()
	fa.class_synergy_detected_signal.connect(_on_detected)

	# Act
	fa.notify_synergy_detected("steel_wall")

	# Assert
	assert_int(_detected_emissions.size()).is_equal(1)
	assert_str(_detected_emissions[0]).is_equal("steel_wall")


func test_notify_synergy_detected_no_emit_when_synergy_id_is_empty() -> void:
	# Idempotent on empty — no signal emit, no error.
	var fa: Node = _make_fa()
	_detected_emissions.clear()
	fa.class_synergy_detected_signal.connect(_on_detected)

	fa.notify_synergy_detected("")

	assert_int(_detected_emissions.size()).is_equal(0)


func test_notify_synergy_detected_emits_for_each_v10_synergy_id() -> void:
	var fa: Node = _make_fa()
	_detected_emissions.clear()
	fa.class_synergy_detected_signal.connect(_on_detected)

	fa.notify_synergy_detected("steel_wall")
	fa.notify_synergy_detected("arcane_elite")
	fa.notify_synergy_detected("triple_threat")

	assert_int(_detected_emissions.size()).is_equal(3)
	assert_str(_detected_emissions[0]).is_equal("steel_wall")
	assert_str(_detected_emissions[1]).is_equal("arcane_elite")
	assert_str(_detected_emissions[2]).is_equal("triple_threat")


# ===========================================================================
# Group C — AudioRouter throttle behavior (AC-CS-14)
# ===========================================================================

func test_audio_router_detection_chime_throttle_state_field_exists() -> void:
	# Structural check — the throttle state field exists and initializes to its
	# "never played" sentinel (-_CLASS_SYNERGY_DETECTED_THROTTLE_MS) so the first
	# chime is never suppressed at low engine uptime (fixed in commit cefecad; a
	# test-injectable clock seam now exists via _throttle_now_override_ms).
	var router: Node = _make_router()
	assert_bool("_class_synergy_detected_last_played_ms" in router).is_true()
	assert_int(router._class_synergy_detected_last_played_ms).is_equal(
		-AudioRouterScript._CLASS_SYNERGY_DETECTED_THROTTLE_MS)


func test_audio_router_detection_chime_throttle_constant_matches_2s() -> void:
	# Per `class-synergy-system.md` §G + AC-CS-14: throttle window = 2.0s.
	# Constant lives on the AudioRouter script.
	const EXPECTED_MS: int = 2000
	assert_int(AudioRouterScript._CLASS_SYNERGY_DETECTED_THROTTLE_MS).is_equal(EXPECTED_MS)


func test_audio_router_detection_chime_handler_advances_throttle_clock() -> void:
	# Direct handler invocation when the throttle window has elapsed:
	# the clock advances. Set the prior clock to a value far in the past
	# (older than _CLASS_SYNERGY_DETECTED_THROTTLE_MS) so the first invocation
	# passes the throttle check.
	var router: Node = _make_router()
	# Simulate "throttle window already elapsed" by backdating the clock.
	# Time.get_ticks_msec() returns msec since Godot startup; a backdate of
	# -10_000_000 is guaranteed to be outside the throttle window.
	router._class_synergy_detected_last_played_ms = -10_000_000
	var clock_before: int = router._class_synergy_detected_last_played_ms

	router._on_class_synergy_detected("steel_wall")

	# After invocation, the clock advanced to the current Time.get_ticks_msec().
	var clock_after: int = router._class_synergy_detected_last_played_ms
	assert_int(clock_after).is_greater(clock_before)


func test_audio_router_detection_chime_handler_throttles_within_window() -> void:
	# Direct handler invocation: a second call within the throttle window
	# does NOT update the clock (because the throttle suppresses the play).
	var router: Node = _make_router()
	# Backdate first to ensure the first call passes the throttle.
	router._class_synergy_detected_last_played_ms = -10_000_000
	router._on_class_synergy_detected("steel_wall")
	var clock_after_first: int = router._class_synergy_detected_last_played_ms

	# Immediately re-invoke — within the 2s throttle window.
	router._on_class_synergy_detected("arcane_elite")
	var clock_after_second: int = router._class_synergy_detected_last_played_ms

	# Clock did NOT advance (throttle suppressed the play).
	assert_int(clock_after_second).is_equal(clock_after_first)


func test_audio_router_detection_chime_first_call_at_low_uptime_plays() -> void:
	# Regression for the throttle flake fixed in commit cefecad (and the latent
	# product bug behind it): with the last-played clock at its "never played"
	# sentinel, the FIRST detection chime must play even when engine uptime is
	# below the 2.0s window. The old code initialized last-played to 0, so
	# (uptime - 0) < 2000ms wrongly suppressed the first chime within 2s of boot
	# — a silent miss for any player who triggered a synergy that early. We pin a
	# low uptime via the injectable clock seam and assert the play path ran (the
	# throttle clock advanced to the injected "now").
	var router: Node = _make_router()
	# "Never played" — mirrors the production member initializer.
	router._class_synergy_detected_last_played_ms = -1_000_000
	router._throttle_now_override_ms = 50  # 50ms since boot, far below the 2.0s window

	router._on_class_synergy_detected("steel_wall")

	# The first call was NOT throttled: the clock advanced to the injected now.
	assert_int(router._class_synergy_detected_last_played_ms).is_equal(50)


# ===========================================================================
# Group D — Locale keys present in en.csv (AC-CS-15)
# ===========================================================================

func test_class_synergy_badge_keys_present_in_en_csv() -> void:
	# AC-CS-15: 6 new keys per GDD §C.4. Verify each via TranslationServer
	# (LocaleLoader resolves via TranslationServer.add_translation at boot).
	# If a key is missing, tr() returns the key string verbatim — so the
	# test checks that tr(key) does NOT equal the key itself OR is the
	# expected English value.
	#
	# In headless test env, LocaleLoader autoload may or may not have
	# loaded the CSV depending on test order. Check via filesystem read
	# of en.csv as the authoritative source.
	var csv_path: String = "res://assets/locale/en.csv"
	var content: String = FileAccess.get_file_as_string(csv_path)
	assert_bool(content.contains("class_synergy_badge_steel_wall")).is_true()
	assert_bool(content.contains("class_synergy_badge_arcane_elite")).is_true()
	assert_bool(content.contains("class_synergy_badge_triple_threat")).is_true()


func test_class_synergy_effect_keys_present_in_en_csv() -> void:
	var csv_path: String = "res://assets/locale/en.csv"
	var content: String = FileAccess.get_file_as_string(csv_path)
	assert_bool(content.contains("class_synergy_effect_steel_wall")).is_true()
	assert_bool(content.contains("class_synergy_effect_arcane_elite")).is_true()
	assert_bool(content.contains("class_synergy_effect_triple_threat")).is_true()


func test_class_synergy_locale_values_match_gdd_writer_lock() -> void:
	# Per GDD §C.4 the values are writer-locked. Verify the canonical
	# strings in en.csv match the GDD spec.
	var csv_path: String = "res://assets/locale/en.csv"
	var content: String = FileAccess.get_file_as_string(csv_path)
	# Badge labels (display names)
	assert_bool(content.contains("class_synergy_badge_steel_wall,Steel Wall")).is_true()
	assert_bool(content.contains("class_synergy_badge_arcane_elite,Arcane Elite")).is_true()
	assert_bool(content.contains("class_synergy_badge_triple_threat,Triple Threat")).is_true()
	# Effect summaries
	assert_bool(content.contains("class_synergy_effect_steel_wall,+25% gold vs bruisers")).is_true()
	assert_bool(content.contains("class_synergy_effect_arcane_elite,+20% XP from all kills")).is_true()
	assert_bool(content.contains("class_synergy_effect_triple_threat,+15% gold from all kills")).is_true()
