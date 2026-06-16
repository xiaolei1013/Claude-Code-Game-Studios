## offline_forbidden_patterns_ci_grep_test.gd — S12-M5 CI Enforcement
##
## Enforces the forbidden pattern `per_chunk_domain_signal_emission_during_offline_replay`
## per ADR-0014 §Constraints. Verifies that domain signals are guarded by
## _is_offline_replay checks in Economy, Orchestrator, and OfflineProgressionEngine.
##
## Grep-based validation: scans source files for unguarded .emit() calls.

extends GdUnitTestSuite

# === Grep Helpers ===

func _read_file(path: String) -> String:
	## Read a file and return its contents as a string.
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open file: %s (error %d)" % [path, FileAccess.get_open_error()])
		return ""
	return file.get_as_text()


func _extract_method_body(source: String, method_name: String) -> String:
	## CODE REVIEW 2026-06-16 (I22): indentation-aware method-body extraction.
	## GDScript scopes by INDENT, not braces — the prior brace-counting helper never
	## scoped a method (and was dead code). Capture every line AFTER `func <method>`
	## up to the next TOP-LEVEL `func` (column 0), so guard assertions are scoped to
	## the SPECIFIC method instead of matching anywhere in the whole file (the prior
	## file-wide `.contains` could not catch a guard removed from one method).
	var lines: PackedStringArray = source.split("\n")
	var body: PackedStringArray = PackedStringArray()
	var in_method: bool = false
	for line: String in lines:
		if not in_method:
			if line.begins_with("func %s" % method_name) or line.begins_with("static func %s" % method_name):
				in_method = true
			continue
		# End of the method at the next top-level (column-0) func declaration.
		if line.begins_with("func ") or line.begins_with("static func "):
			break
		body.append(line)
	return "\n".join(body)


# === Group A: Economy Signal Suppression Guards ===

func test_economy_add_gold_emit_guarded() -> void:
	## Economy.add_gold must guard gold_changed.emit() with the _is_offline_replay
	## check INSIDE the method (`if _is_offline_replay: accumulate; else: emit`).
	## Method-scoped: catches a guard removed from add_gold specifically.
	var source = _read_file("res://src/core/economy/economy.gd")
	var body: String = _extract_method_body(source, "add_gold")
	assert_str(body).is_not_empty()
	assert_bool(body.contains("gold_changed.emit")).is_true()
	assert_bool(body.contains("_is_offline_replay")).is_true()


func test_economy_try_spend_emit_guarded() -> void:
	## Economy.try_spend must guard gold_changed.emit() with the suppression flag
	## inside the method body.
	var source = _read_file("res://src/core/economy/economy.gd")
	var body: String = _extract_method_body(source, "try_spend")
	assert_str(body).is_not_empty()
	assert_bool(body.contains("gold_changed.emit")).is_true()
	assert_bool(body.contains("_is_offline_replay")).is_true()


func test_economy_try_award_floor_clear_emit_guarded() -> void:
	## Economy.try_award_floor_clear must guard first_clear_awarded.emit() with the
	## suppression flag inside the method body.
	var source = _read_file("res://src/core/economy/economy.gd")
	var body: String = _extract_method_body(source, "try_award_floor_clear")
	assert_str(body).is_not_empty()
	assert_bool(body.contains("first_clear_awarded.emit")).is_true()
	assert_bool(body.contains("_is_offline_replay")).is_true()


# === Group B: Orchestrator Signal Suppression Guards ===

func test_orchestrator_process_kill_events_emit_guarded() -> void:
	## Orchestrator._process_kill_events must guard floor_cleared_first_time.emit()
	## with the suppression flag inside the method (`if _is_offline_replay:
	## accumulate into _offline_pending_first_clears; else: emit`). Method-scoped.
	var source = _read_file("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
	var body: String = _extract_method_body(source, "_process_kill_events")
	assert_str(body).is_not_empty()
	assert_bool(body.contains("floor_cleared_first_time.emit")).is_true()
	assert_bool(body.contains("_is_offline_replay")).is_true()


# === Group C: Exceptions to the Rule ===

func test_economy_flush_offline_signals_exception_allowed() -> void:
	## Economy.flush_offline_signals is the post-replay aggregate emit location.
	## This is the ONE exception to the suppression rule.
	var source = _read_file("res://src/core/economy/economy.gd")
	assert_that(source).is_not_empty()

	# Verify flush_offline_signals exists and emits (no guard needed there).
	assert_that(source).contains("func flush_offline_signals")
	assert_that(source).contains("gold_changed.emit")


func test_orchestrator_flush_offline_signals_exception_allowed() -> void:
	## Orchestrator.flush_offline_signals is the post-replay aggregate emit location.
	var source = _read_file("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
	assert_that(source).is_not_empty()

	assert_that(source).contains("func flush_offline_signals")
	assert_that(source).contains("floor_cleared_first_time.emit")


# === Group D: OfflineProgressionEngine Flag Management ===

func test_offline_engine_sets_economy_flag_true() -> void:
	## OfflineProgressionEngine.run_offline_replay sets Economy._is_offline_replay = true.
	var source = _read_file("res://src/core/offline_progression_engine/offline_progression_engine.gd")
	assert_that(source).is_not_empty()

	assert_that(source).contains("economy._is_offline_replay = true")


func test_offline_engine_sets_orchestrator_flag_true() -> void:
	## OfflineProgressionEngine.run_offline_replay sets Orchestrator._is_offline_replay = true.
	var source = _read_file("res://src/core/offline_progression_engine/offline_progression_engine.gd")
	assert_that(source).is_not_empty()

	assert_that(source).contains("orchestrator._is_offline_replay = true")


func test_offline_engine_clears_flags_before_flush() -> void:
	## Flags are cleared FALSE before calling flush_offline_signals.
	var source = _read_file("res://src/core/offline_progression_engine/offline_progression_engine.gd")
	assert_that(source).is_not_empty()

	assert_that(source).contains("economy._is_offline_replay = false")
	assert_that(source).contains("orchestrator._is_offline_replay = false")
	assert_that(source).contains("flush_offline_signals")


# === Group E: Audit — No Unguarded Emits in Replay Path ===

func test_no_direct_gold_changed_emit_during_replay_path() -> void:
	## Spot-check: gold_changed.emit is either guarded or in flush_offline_signals.
	var source = _read_file("res://src/core/economy/economy.gd")

	# Count unguarded gold_changed.emit calls (heuristic: look for .emit not in same line as if guard).
	var lines = source.split("\n")
	for i in range(lines.size()):
		var line = lines[i]
		if "gold_changed.emit" in line:
			# Check if this line or preceding lines have the guard.
			# Implementation uses `if _is_offline_replay: accumulate; else: emit`
			# (semantically equivalent to `if not _is_offline_replay: emit`).
			# Either form counts as guarded.
			var has_guard = false
			for j in range(maxi(0, i - 5), i + 1):
				if "_is_offline_replay" in lines[j]:
					has_guard = true
					break
			# If emit is found, it should be guarded or in flush method.
			if not has_guard:
				# This is permitted only in flush_offline_signals.
				var in_flush = false
				for j in range(maxi(0, i - 10), i + 1):
					if "func flush_offline_signals" in lines[j]:
						in_flush = true
						break
				assert_that(in_flush).override_failure_message("Unguarded gold_changed.emit at line %d" % (i + 1)).is_true()


# === Group F: extractor is genuinely method-scoped (guards the I22 guard) ===

func test_extract_method_body_is_method_scoped_not_file_wide() -> void:
	## Proves _extract_method_body scopes to ONE method, so the guard assertions
	## above can actually catch a guard removed from a specific method. add_gold's
	## body must contain gold_changed.emit but NOT first_clear_awarded.emit (which
	## lives only in try_award_floor_clear) nor the next method's `func try_spend`
	## header — if extraction were file-wide, both would leak in.
	var source = _read_file("res://src/core/economy/economy.gd")
	var add_gold_body: String = _extract_method_body(source, "add_gold")
	assert_bool(add_gold_body.contains("gold_changed.emit")).is_true()
	assert_bool(add_gold_body.contains("first_clear_awarded.emit")).is_false()
	assert_bool(add_gold_body.contains("func try_spend")).is_false()
