# Settings overlay — telemetry opt-in toggle wiring.
#
# Per `production/live-ops/telemetry-events-v1.md` §C.1 + §F.5: the Settings
# overlay has a "Share anonymous diagnostic data" CheckButton wired to
# TelemetrySink.set_opt_in / is_opt_in. Default OFF (cozy register + privacy
# first). Reset to Defaults must restore the OFF state regardless of prior
# state.
#
# Test groups:
#   A — telemetry CheckButton initializes from TelemetrySink.is_opt_in()
#   B — toggling the CheckButton writes through TelemetrySink.set_opt_in()
#   C — Reset to Defaults restores opt-out (false) per §C.1 privacy-first
#
# S16-M1 candidate, pulled forward into Sprint 15 once Must-Have autonomous
# scope was exhausted on the human playtest gate.
extends GdUnitTestSuite

const SettingsOverlayScene: PackedScene = preload(
	"res://assets/overlays/settings/settings.tscn"
)


# ---------------------------------------------------------------------------
# Hygiene barrier — snapshot/restore TelemetrySink opt-in state.
# ---------------------------------------------------------------------------

var _snapshot_opt_in: bool = false


func before_test() -> void:
	_snapshot_opt_in = TelemetrySink.is_opt_in()


func after_test() -> void:
	TelemetrySink.set_opt_in(_snapshot_opt_in)


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

func _make_overlay_in_tree() -> Control:
	var overlay: Control = SettingsOverlayScene.instantiate() as Control
	add_child(overlay)
	auto_free(overlay)
	return overlay


# ===========================================================================
# Group A — initialization from TelemetrySink
# ===========================================================================

# A-01: when TelemetrySink.is_opt_in() returns false, the CheckButton seeds OFF.
func test_telemetry_check_initializes_off_when_opt_in_is_false() -> void:
	TelemetrySink.set_opt_in(false)
	var overlay: Control = _make_overlay_in_tree()
	var check: CheckButton = overlay.get_node("Panel/VBox/TelemetryRow/TelemetryCheck")
	assert_bool(check.button_pressed).is_false()


# A-02: when TelemetrySink.is_opt_in() returns true, the CheckButton seeds ON.
func test_telemetry_check_initializes_on_when_opt_in_is_true() -> void:
	TelemetrySink.set_opt_in(true)
	var overlay: Control = _make_overlay_in_tree()
	var check: CheckButton = overlay.get_node("Panel/VBox/TelemetryRow/TelemetryCheck")
	assert_bool(check.button_pressed).is_true()


# ===========================================================================
# Group B — toggling writes through TelemetrySink
# ===========================================================================

# B-01: toggling the CheckButton from OFF→ON calls TelemetrySink.set_opt_in(true).
func test_telemetry_check_toggle_off_to_on_writes_to_telemetry_sink() -> void:
	TelemetrySink.set_opt_in(false)
	var overlay: Control = _make_overlay_in_tree()
	var check: CheckButton = overlay.get_node("Panel/VBox/TelemetryRow/TelemetryCheck")
	check.button_pressed = true
	check.toggled.emit(true)
	assert_bool(TelemetrySink.is_opt_in()).is_true()


# B-02: toggling the CheckButton from ON→OFF calls TelemetrySink.set_opt_in(false).
func test_telemetry_check_toggle_on_to_off_writes_to_telemetry_sink() -> void:
	TelemetrySink.set_opt_in(true)
	var overlay: Control = _make_overlay_in_tree()
	var check: CheckButton = overlay.get_node("Panel/VBox/TelemetryRow/TelemetryCheck")
	check.button_pressed = false
	check.toggled.emit(false)
	assert_bool(TelemetrySink.is_opt_in()).is_false()


# ===========================================================================
# Group C — Reset to Defaults restores opt-out per §C.1 privacy-first
# ===========================================================================

# C-01: Reset button restores TelemetrySink to opt-out (false) even if it
# was previously ON. The privacy-first default must survive a Reset.
func test_reset_button_restores_telemetry_to_opt_out() -> void:
	# Arrange — telemetry is ON.
	TelemetrySink.set_opt_in(true)
	var overlay: Control = _make_overlay_in_tree()
	var reset: Button = overlay.get_node("Panel/VBox/ButtonRow/ResetButton")

	# Act.
	reset.pressed.emit()

	# Assert — telemetry flipped to OFF.
	assert_bool(TelemetrySink.is_opt_in()).override_failure_message(
		"Reset must restore telemetry to opt-out (privacy-first default)"
	).is_false()
	# Checkbox UI also reflects the reset.
	var check: CheckButton = overlay.get_node("Panel/VBox/TelemetryRow/TelemetryCheck")
	assert_bool(check.button_pressed).is_false()
