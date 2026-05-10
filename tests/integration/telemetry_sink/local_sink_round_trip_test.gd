# Sprint 21+ Telemetry V1.0 / Stage 2 — local-sink JSONL round-trip integration test.
#
# Per `production/live-ops/telemetry-events-v1.md` §C.4 (local-only sink) +
# §D (envelope schema) + §F.6 (test contract).
#
# Verifies the end-to-end path: opt_in=true → handler builds payload →
# envelope wrapped → appended to JSONL → re-read → parses back to the
# same envelope shape with the expected fields.
#
# Uses path-override per project memory `feedback_test_isolation_user_configfile`
# to write into `user://telemetry-test/` instead of the real sink directory.
extends GdUnitTestSuite

const _TEST_SINK_DIR: String = "user://telemetry-test-roundtrip/"


func _get_sink() -> Node:
	return get_tree().root.get_node_or_null("TelemetrySink")


func _today_filename() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "events-%04d-%02d-%02d.jsonl" % [int(d["year"]), int(d["month"]), int(d["day"])]


func _clear_test_sink() -> void:
	# Best-effort cleanup. DirAccess.open + directory walk would be more
	# thorough; for a single rotating filename, direct remove is fine.
	if DirAccess.dir_exists_absolute(_TEST_SINK_DIR):
		var dir: DirAccess = DirAccess.open(_TEST_SINK_DIR)
		if dir != null:
			dir.list_dir_begin()
			var name: String = dir.get_next()
			while name != "":
				if not dir.current_is_dir():
					DirAccess.remove_absolute(_TEST_SINK_DIR + name)
				name = dir.get_next()
			dir.list_dir_end()


func before_test() -> void:
	var sink: Node = _get_sink()
	if sink != null:
		sink.set_opt_in(false)
		sink._sink_dir_override = _TEST_SINK_DIR
		if "_test_event_log" in sink:
			sink._test_event_log.clear()
	_clear_test_sink()


func after_test() -> void:
	var sink: Node = _get_sink()
	if sink != null:
		sink.set_opt_in(false)
		sink._sink_dir_override = ""
	_clear_test_sink()


# ===========================================================================
# Round-trip: emit → file → parse
# ===========================================================================

func test_jsonl_round_trip_first_launch_event_writes_and_parses() -> void:
	# Arrange
	var sink: Node = _get_sink()
	sink.set_opt_in(true)

	# Act — fire the handler. Handler builds payload + envelope, appends JSONL.
	sink._on_first_launch()

	# Assert — the day's file exists and contains a parseable envelope.
	var path: String = _TEST_SINK_DIR + _today_filename()
	assert_bool(FileAccess.file_exists(path)).is_true()

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(file).is_not_null()
	var line: String = file.get_line()
	file.close()

	var parsed: Variant = JSON.parse_string(line)
	assert_bool(parsed is Dictionary).is_true()
	var env: Dictionary = parsed as Dictionary

	# Envelope shape per §D.
	assert_int(int(env.get("schema_version", 0))).is_equal(1)
	assert_bool(env.has("timestamp_unix")).is_true()
	assert_bool(env.has("session_id")).is_true()
	assert_str(str(env.get("session_id", ""))).is_not_equal("")
	assert_str(str(env.get("event_type", ""))).is_equal("first_launch")
	assert_bool(env.has("payload")).is_true()
	var payload: Dictionary = env.get("payload", {}) as Dictionary
	assert_str(str(payload.get("seed_class", ""))).is_equal("warrior")


func test_jsonl_round_trip_appends_multiple_events_to_same_file() -> void:
	# Two emissions in the same calendar day land in the same file as
	# distinct lines. Daily rotation does NOT split intra-day.
	var sink: Node = _get_sink()
	sink.set_opt_in(true)

	sink._on_first_launch()
	sink._on_first_launch()

	var path: String = _TEST_SINK_DIR + _today_filename()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var line_count: int = 0
	while not file.eof_reached():
		var l: String = file.get_line()
		if l != "":
			line_count += 1
	file.close()

	assert_int(line_count).is_equal(2)


func test_jsonl_no_write_when_opt_out() -> void:
	# Defense in depth: even if the test fixture left files lying around,
	# opt_in=false means no NEW write happens. Verify by checking the file
	# does not exist after a handler call when opt-out.
	var sink: Node = _get_sink()
	sink.set_opt_in(false)

	sink._on_first_launch()

	var path: String = _TEST_SINK_DIR + _today_filename()
	assert_bool(FileAccess.file_exists(path)).is_false()


func test_session_id_consistent_across_events_in_same_session() -> void:
	# The within-session correlation contract per §C.2: every event in a
	# single launch shares the same session_id.
	var sink: Node = _get_sink()
	sink.set_opt_in(true)

	sink._on_first_launch()
	sink._on_first_launch()

	var path: String = _TEST_SINK_DIR + _today_filename()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var session_ids: Array[String] = []
	while not file.eof_reached():
		var l: String = file.get_line()
		if l == "":
			continue
		var parsed: Variant = JSON.parse_string(l)
		if parsed is Dictionary:
			session_ids.append(str((parsed as Dictionary).get("session_id", "")))
	file.close()

	assert_int(session_ids.size()).is_equal(2)
	assert_str(session_ids[0]).is_equal(session_ids[1])
