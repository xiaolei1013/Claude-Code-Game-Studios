# Sprint 21+ Telemetry V1.0 / Stage 2 — TelemetrySink autoload skeleton tests.
#
# Per `production/live-ops/telemetry-events-v1.md` §F.1 + §F.2.
#
# Test groups:
#   A — autoload presence + class shape
#   B — opt-in default + setter/getter contract
#   C — save consumer surface (get_save_data + load_save_data round-trip)
#   D — session_id is present + non-empty after _ready
#   E — set_opt_in is hot — does NOT require autoload reboot
extends GdUnitTestSuite


func _get_sink() -> Node:
	return get_tree().root.get_node_or_null("TelemetrySink")


func before_test() -> void:
	# Reset opt-in to default before each test (next test starts clean).
	var sink: Node = _get_sink()
	if sink != null:
		sink.set_opt_in(false)


func after_test() -> void:
	var sink: Node = _get_sink()
	if sink != null:
		sink.set_opt_in(false)


# ===========================================================================
# Group A — autoload presence
# ===========================================================================

func test_telemetry_sink_autoload_present() -> void:
	var sink: Node = _get_sink()
	assert_object(sink).is_not_null()


func test_telemetry_sink_has_public_methods() -> void:
	var sink: Node = _get_sink()
	assert_bool(sink.has_method("set_opt_in")).is_true()
	assert_bool(sink.has_method("is_opt_in")).is_true()
	assert_bool(sink.has_method("get_save_data")).is_true()
	assert_bool(sink.has_method("load_save_data")).is_true()


# ===========================================================================
# Group B — opt-in default + setter/getter
# ===========================================================================

func test_opt_in_default_is_false_per_cozy_register() -> void:
	# Per taxonomy doc §C.1: opt-in default OFF. Players opt in actively
	# or we collect nothing.
	var sink: Node = _get_sink()
	assert_bool(sink.is_opt_in()).is_false()


func test_set_opt_in_true_flips_getter() -> void:
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	assert_bool(sink.is_opt_in()).is_true()


func test_set_opt_in_false_resets_getter() -> void:
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	sink.set_opt_in(false)
	assert_bool(sink.is_opt_in()).is_false()


# ===========================================================================
# Group C — save consumer surface round-trip
# ===========================================================================

func test_get_save_data_returns_telemetry_opt_in_field() -> void:
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	var d: Dictionary = sink.get_save_data()
	assert_bool(d.has("telemetry_opt_in")).is_true()
	assert_bool(bool(d["telemetry_opt_in"])).is_true()


func test_load_save_data_restores_opt_in_true() -> void:
	var sink: Node = _get_sink()
	sink.load_save_data({"telemetry_opt_in": true})
	assert_bool(sink.is_opt_in()).is_true()


func test_load_save_data_missing_field_defaults_false() -> void:
	# Pre-V1 saves don't have the field. Load must default to false
	# (cozy-register-respecting opt-in default).
	var sink: Node = _get_sink()
	sink.set_opt_in(true)  # set ON first
	sink.load_save_data({})  # load missing-field dict
	assert_bool(sink.is_opt_in()).is_false()


func test_save_load_round_trip_preserves_opt_in_state() -> void:
	var sink: Node = _get_sink()
	sink.set_opt_in(true)
	var payload: Dictionary = sink.get_save_data()
	sink.set_opt_in(false)  # mutate
	sink.load_save_data(payload)  # restore
	assert_bool(sink.is_opt_in()).is_true()


# ===========================================================================
# Group D — session_id present
# ===========================================================================

func test_session_id_is_present_after_ready() -> void:
	var sink: Node = _get_sink()
	# session_id is a private field; access via the underscore-prefixed name
	# to lock in the contract that _ready generated one.
	assert_bool("_session_id" in sink).is_true()
	assert_str(str(sink._session_id)).is_not_equal("")


# ===========================================================================
# Group E — set_opt_in is hot (no reboot required)
# ===========================================================================

func test_opt_in_flip_takes_effect_without_reboot() -> void:
	# Per taxonomy doc §F.2 hot-reload-safe contract: handler entry guard
	# reads the live opt_in field per-event. Verifying via the public
	# is_opt_in() check after a flip is sufficient at this layer.
	var sink: Node = _get_sink()
	assert_bool(sink.is_opt_in()).is_false()
	sink.set_opt_in(true)
	assert_bool(sink.is_opt_in()).is_true()
	sink.set_opt_in(false)
	assert_bool(sink.is_opt_in()).is_false()
