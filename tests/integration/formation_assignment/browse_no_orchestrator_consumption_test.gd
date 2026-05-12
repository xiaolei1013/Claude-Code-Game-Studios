# AC-FA-09 cross-system invariant: formation_browse_opened is NOT consumed by
# DungeonRunOrchestrator. Enforced via CI-grep on the orchestrator source
# rather than a behavioral dispatch fixture — the assertion is equivalent
# (a system that doesn't reference the signal cannot consume it) and avoids
# Economy + FloorUnlock + DataRegistry + run_snapshot setup. Mirrors the
# AC-FA-12 single-writer + ADR-0014 forbidden-patterns CI-grep style.
extends GdUnitTestSuite

const ORCHESTRATOR_SOURCE_PATH: String = "res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd"


# ===========================================================================
# Group A — CI grep: orchestrator source has no formation_browse_opened reference
# ===========================================================================

func test_orchestrator_source_has_no_formation_browse_opened_reference() -> void:
	# Arrange — read the orchestrator source file.
	var file: FileAccess = FileAccess.open(ORCHESTRATOR_SOURCE_PATH, FileAccess.READ)
	assert_object(file).override_failure_message(
		"Could not open orchestrator source at %s" % ORCHESTRATOR_SOURCE_PATH
	).is_not_null()
	var src: String = file.get_as_text()
	file.close()

	# Strip comments + docstrings to allow mentioning the signal in commentary
	# (which is documentation, not consumption). The forbidden pattern is a
	# code-level reference: `connect`, `disconnect`, `is_connected`, or direct
	# signal-handler method names referencing the signal.
	#
	# Robust approach: scan line-by-line, ignore lines that start with `#`
	# (after stripping leading whitespace). Then check the remaining code for
	# `formation_browse_opened`.
	var stripped: PackedStringArray = PackedStringArray()
	for raw_line: String in src.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("#"):
			continue
		stripped.append(line)
	var code_only: String = "\n".join(stripped)

	# AC-FA-09 invariant: zero code-level references to formation_browse_opened
	# in the orchestrator source. If this fails, the Orchestrator is consuming
	# the read-intent signal — a contract violation per §C.7.
	assert_bool(code_only.contains("formation_browse_opened")).override_failure_message(
		"AC-FA-09 violation: dungeon_run_orchestrator.gd contains a code-level reference to "
		+ "formation_browse_opened. Per formation-assignment-system.md §C.1 + dungeon-run-orchestrator.md §C.7, "
		+ "the Orchestrator MUST NOT consume this read-intent signal."
	).is_false()


# ===========================================================================
# Group B — behavioral: browse() does not mutate orchestrator state
# ===========================================================================

func test_browse_does_not_mutate_orchestrator_state_or_run_snapshot() -> void:
	# Arrange — capture Orchestrator state before browse. NO_RUN is the
	# cold-launch default state; we don't need to force ACTIVE_FOREGROUND for
	# this behavioral check — the invariant "browse doesn't touch orchestrator"
	# holds in any state.
	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	assert_object(fa).is_not_null()
	assert_object(orch).is_not_null()

	var pre_state: int = int(orch.get("state"))
	var pre_snapshot: Variant = orch.get("run_snapshot")

	# Act — call browse with an empty formation (irrelevant to AC-FA-09;
	# what matters is that browse() does not reach into the Orchestrator).
	var empty_formation: Array[HeroInstance] = [null, null, null]
	fa.call("browse", empty_formation)

	# Assert — Orchestrator state and run_snapshot identical to pre-browse.
	var post_state: int = int(orch.get("state"))
	var post_snapshot: Variant = orch.get("run_snapshot")
	assert_int(post_state).is_equal(pre_state)
	assert_bool(post_snapshot == pre_snapshot).is_true()


# ===========================================================================
# Group C — formation_browse_opened signal has no consumers in src/
# ===========================================================================

func test_formation_browse_opened_has_zero_production_consumers() -> void:
	# Stronger AC-FA-09 corollary: no production code (src/) should subscribe
	# to formation_browse_opened in MVP. Per OQ-FA-3, the signal is documented
	# as a hook for future V1.0 UI consumers but has zero subscribers in MVP.
	# Tests + commentary are fine; production code subscriptions are not.
	#
	# This test walks src/ looking for `formation_browse_opened.connect(` —
	# the canonical Godot subscription pattern. If any production code adds
	# such a subscription, this test fails (catches contract drift).
	var hits: Array[String] = _scan_src_for_pattern("formation_browse_opened.connect(")

	# The autoload's own signal declaration is `signal formation_browse_opened`
	# — that doesn't contain `.connect(`. Test/commentary mentions also don't.
	# In MVP, this set must be empty.
	assert_int(hits.size()).override_failure_message(
		"AC-FA-09 / OQ-FA-3 corollary violation: production code in src/ contains "
		+ "%d subscription(s) to formation_browse_opened. Files: %s. "
		+ "MVP has zero subscribers; V1.0 UI consumers go through formation_reassignment_committed."
		% [hits.size(), str(hits)]
	).is_equal(0)


func _scan_src_for_pattern(pattern: String) -> Array[String]:
	var hits: Array[String] = []
	_scan_dir_recursive("res://src/", pattern, hits)
	return hits


func _scan_dir_recursive(path: String, pattern: String, hits: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var entry_path: String = path + entry
		if dir.current_is_dir():
			_scan_dir_recursive(entry_path + "/", pattern, hits)
		elif entry.ends_with(".gd"):
			var f: FileAccess = FileAccess.open(entry_path, FileAccess.READ)
			if f != null:
				var contents: String = f.get_as_text()
				f.close()
				# Strip comment lines so docstring mentions don't false-positive.
				var lines: PackedStringArray = contents.split("\n")
				for raw_line: String in lines:
					var line: String = raw_line.strip_edges()
					if line.begins_with("#"):
						continue
					if line.contains(pattern):
						hits.append(entry_path)
						break  # one hit per file is sufficient
		entry = dir.get_next()
	dir.list_dir_end()
