# Tests for Story 003: _process(delta) forbidden-as-economy-input and
# wall-clock single call site.
#
# Covers:
#   TR-time-002 — Wall clock read via Time.get_unix_time_from_system() at a
#                 single call site (INV-1 grep invariant, tested structurally)
#   TR-time-006 — _process(delta) forbidden as economy input (structural check)
#   TR-time-021 — All internal wall-clock reads route through
#                 _read_wall_clock_unix_time() for mock propagation
#
# Static-analysis tests (Tests 1 and 4) read GDScript source via FileAccess and
# perform string inspection.  They act as in-engine "CI grep" equivalents and
# fail the suite if the invariants are violated.  These tests are intentionally
# fragile to regressions — that fragility is the feature.
extends GdUnitTestSuite

const TickSystemScript = preload("res://src/core/tick_system/tick_system.gd")
const TICK_SYSTEM_SRC_PATH: String = "res://src/core/tick_system/tick_system.gd"
const SRC_ROOT: String = "res://src"

# ---------------------------------------------------------------------------
# Helper: recursively collect all .gd file paths under a res:// directory.
# Returns an Array[String] of absolute res:// paths.
# ---------------------------------------------------------------------------
func _collect_gd_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = dir_path + "/" + entry
		if dir.current_is_dir():
			var sub_files: Array[String] = _collect_gd_files(full_path)
			result.append_array(sub_files)
		elif entry.ends_with(".gd"):
			result.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return result


# ---------------------------------------------------------------------------
# Helper: count non-comment occurrences of a search string in a file.
# A line is considered a comment if its first non-whitespace characters are
# "#" (covers both "#" and "##" doc comments in GDScript).
# Returns the count of matching non-comment lines.
# ---------------------------------------------------------------------------
func _count_code_occurrences(file_path: String, search: String) -> int:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return 0
	var count: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		var stripped: String = line.strip_edges()
		# Skip blank lines and comment lines
		if stripped.begins_with("#"):
			continue
		if search in stripped:
			count += 1
	file.close()
	return count


# ---------------------------------------------------------------------------
# Test 1 — TR-time-002 / INV-1: Wall-clock single call site (static grep).
#
# This is a structural source-inspection test that acts as an in-engine
# equivalent of:
#   grep -rn "Time.get_unix_time_from_system" src/
# The invariant: exactly ONE non-comment code line in all of src/ contains
# this string, and it must be inside tick_system.gd.
#
# Note: comment lines (starting with # or ##) are excluded because they are
# documentation of the invariant, not violations of it.
# ---------------------------------------------------------------------------
func test_wall_clock_single_call_site_exactly_one_in_src() -> void:
	# Arrange
	const SEARCH: String = "Time.get_unix_time_from_system"
	var gd_files: Array[String] = _collect_gd_files(SRC_ROOT)
	assert_bool(gd_files.size() > 0).is_true()  # sanity: src/ must have files

	# Act — count non-comment occurrences across all .gd files in src/
	var total_count: int = 0
	var match_file: String = ""
	for path in gd_files:
		var hits: int = _count_code_occurrences(path, SEARCH)
		if hits > 0:
			total_count += hits
			match_file = path

	# Assert — exactly one hit, and it must be in tick_system.gd
	assert_int(total_count).is_equal(1)
	assert_bool(match_file.ends_with("tick_system.gd")).is_true()


# ---------------------------------------------------------------------------
# Test 2 — TR-time-021: _read_wall_clock_unix_time() returns a plausible
# int64 and caches the result in _last_wall_ts.
#
# Verifies runtime behaviour of the routing function:
#   - Returns an int > 1_700_000_000 (post-2023 epoch sanity, comfortably
#     true through at least 2033)
#   - _last_wall_ts equals the returned value after the call
# ---------------------------------------------------------------------------
func test_read_wall_clock_unix_time_returns_plausible_epoch_and_caches() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	const MIN_EPOCH: int = 1_700_000_000  # Nov 2023 — always < real wall clock

	# Act
	var result: int = ts._read_wall_clock_unix_time()

	# Assert — result is a plausible Unix timestamp
	assert_int(result).is_greater(MIN_EPOCH)

	# Assert — _last_wall_ts cache was updated to the returned value
	assert_int(ts._last_wall_ts).is_equal(result)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 3 — TR-time-021 (continued): Two successive calls are monotonically
# non-decreasing.  Wall clocks should never go backward in a test run.
# ---------------------------------------------------------------------------
func test_read_wall_clock_unix_time_successive_calls_non_decreasing() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act
	var first: int = ts._read_wall_clock_unix_time()
	var second: int = ts._read_wall_clock_unix_time()

	# Assert — second call >= first call (monotonic in practice)
	assert_int(second).is_greater_equal(first)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 4 (part A) — TR-time-021: now_ms() uses cached _last_wall_ts and
# returns 0 before any _read_wall_clock_unix_time() call.
#
# Given: fresh TickSystem with _last_wall_ts == 0 (no wall-clock read yet)
# When:  now_ms() is called
# Then:  returns 0
# ---------------------------------------------------------------------------
func test_now_ms_returns_zero_before_wall_clock_read() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()
	# _last_wall_ts starts at 0 per field initialiser — no wall-clock read yet

	# Act
	var result: int = ts.now_ms()

	# Assert
	assert_int(result).is_equal(0)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 4 (part B) — TR-time-021: now_ms() returns _last_wall_ts * 1000
# after a wall-clock read, confirming the cached-routing contract.
# ---------------------------------------------------------------------------
func test_now_ms_returns_last_wall_ts_times_1000_after_read() -> void:
	# Arrange
	var ts: Node = TickSystemScript.new()

	# Act — trigger a wall-clock read to populate _last_wall_ts
	var unix_seconds: int = ts._read_wall_clock_unix_time()
	var ms_result: int = ts.now_ms()

	# Assert — now_ms must equal _last_wall_ts * 1000 (cached, not a fresh read)
	assert_int(ms_result).is_equal(unix_seconds * 1000)
	assert_int(ms_result).is_equal(ts._last_wall_ts * 1000)

	# Cleanup
	ts.free()


# ---------------------------------------------------------------------------
# Test 5 — TR-time-006: _process(delta) does not leak delta into economy-
# style formulas (structural source-code inspection).
#
# This is a STATIC ANALYSIS test.  It reads the _process() function body from
# tick_system.gd and verifies:
#   1. The exact accumulator line is present:
#        _tick_accumulator_seconds += delta
#   2. The string "delta *" is absent (delta multiplied into a formula — the
#      canonical economy-input violation).
#   3. The string "delta +" does NOT appear on a line that also lacks
#      "_tick_accumulator_seconds" (guards against other additive uses).
#
# These checks are coarse by design (Sprint 1 — Economy/Orchestrator don't
# exist yet).  Their purpose is to catch accidental regression if someone
# later adds economy math inside _process.
# ---------------------------------------------------------------------------
func test_process_delta_not_used_as_economy_input_structural_check() -> void:
	# Arrange — read the _process function body from the source file
	var file: FileAccess = FileAccess.open(TICK_SYSTEM_SRC_PATH, FileAccess.READ)
	assert_object(file).is_not_null()

	var in_process_func: bool = false
	var process_body_lines: Array[String] = []
	while not file.eof_reached():
		var line: String = file.get_line()
		var stripped: String = line.strip_edges()
		# Detect entry into _process function
		if stripped.begins_with("func _process("):
			in_process_func = true
			continue
		# Detect exit: next top-level func / class section ends _process scope
		if in_process_func:
			if stripped.begins_with("func ") or stripped.begins_with("# ---"):
				break
			process_body_lines.append(stripped)
	file.close()

	# Assert — we found a non-empty _process body
	assert_bool(process_body_lines.size() > 0).is_true()

	# Assert — the accumulator line is present (confirms delta's only legal use)
	var accumulator_line_found: bool = false
	for body_line in process_body_lines:
		if "_tick_accumulator_seconds += delta" in body_line:
			accumulator_line_found = true
			break
	assert_bool(accumulator_line_found).is_true()

	# Assert — "delta *" never appears (economy-formula multiplication violation)
	for body_line in process_body_lines:
		var is_comment: bool = body_line.begins_with("#")
		if not is_comment:
			assert_bool("delta *" in body_line).is_false()

	# Assert — "delta +" never appears outside the accumulator line
	# (guards against additive economy-input violations)
	for body_line in process_body_lines:
		var is_comment: bool = body_line.begins_with("#")
		if not is_comment and "delta +" in body_line:
			# Only acceptable if it's the known accumulator line itself
			assert_bool("_tick_accumulator_seconds" in body_line).is_true()
