# CI guard: PanelContainer single-child invariant.
#
# Godot's PanelContainer is a single-child layout primitive — it sizes itself
# to its child and clips/anchors that child to fill. Adding multiple direct
# children to a PanelContainer stacks them at (0, 0) of the panel rect with
# no layout, producing the "all labels overlapping" visual bug that surfaced
# in PR #69 on the Hero Detail modal.
#
# The fix is always the same: wrap the children in a VBoxContainer (or
# HBoxContainer, depending on intent) and put the wrapper as the PanelContainer's
# single child. See tests/PATTERNS.md §14.
#
# This test scans every .tscn file in assets/ and src/ and asserts that no
# PanelContainer has more than one direct child. If you ship a regression,
# this test prints the offending file + node path so you know exactly where
# to insert the missing VBoxContainer.
#
# Per CI grep pattern from tests/integration/formation_assignment/
# browse_no_orchestrator_consumption_test.gd Group A — same shape.
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers — parse .tscn header lines for node name + type + parent.
# ---------------------------------------------------------------------------

const NODE_LINE_REGEX: String = '^\\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?'


func _scan_tscn_for_panel_container_violations(file_path: String) -> Array[String]:
	var violations: Array[String] = []
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return violations
	var text: String = file.get_as_text()
	file.close()

	# Pass 1: identify every PanelContainer's full path + count its direct
	# children (where direct-child means parent attribute equals this panel's
	# full path).
	var regex: RegEx = RegEx.new()
	regex.compile(NODE_LINE_REGEX)

	var panel_paths: Dictionary[String, bool] = {}
	var children_count: Dictionary[String, int] = {}

	for line: String in text.split("\n"):
		var m: RegExMatch = regex.search(line)
		if m == null:
			continue
		var node_name: String = m.get_string(1)
		var typ: String = m.get_string(2)
		var parent: String = m.get_string(3) if m.get_group_count() >= 3 else ""

		# Build the full path from root.
		var full_path: String = ""
		if parent == "" or parent == ".":
			full_path = node_name
		else:
			full_path = parent + "/" + node_name

		# Track PanelContainers.
		if typ == "PanelContainer":
			panel_paths[full_path] = true

		# Count children by their parent attribute. A child of "DetailPanel"
		# has parent="DetailPanel"; a child of root has parent="." (skip those
		# from the count target since root cannot be a PanelContainer that
		# fails the invariant directly).
		if parent != "" and parent != ".":
			children_count[parent] = children_count.get(parent, 0) + 1

	# Pass 2: check each PanelContainer.
	for panel_path: String in panel_paths:
		var count: int = children_count.get(panel_path, 0)
		if count > 1:
			violations.append(
				"%s: PanelContainer '%s' has %d direct children (must have <= 1; wrap in VBoxContainer)"
				% [file_path, panel_path, count]
			)

	return violations


# ---------------------------------------------------------------------------
# Test — scan every .tscn in assets/ + src/ for violations.
# ---------------------------------------------------------------------------

func test_no_panel_container_has_multiple_direct_children() -> void:
	var scene_paths: Array[String] = []
	_collect_tscn_recursive("res://assets", scene_paths)
	_collect_tscn_recursive("res://src", scene_paths)

	# Sanity: we should find at least one .tscn (otherwise the test is
	# silently passing because it found nothing to scan).
	assert_int(scene_paths.size()).override_failure_message(
		"No .tscn files found under assets/ or src/ — test infrastructure is broken"
	).is_greater_equal(1)

	var all_violations: Array[String] = []
	for path: String in scene_paths:
		var v: Array[String] = _scan_tscn_for_panel_container_violations(path)
		all_violations.append_array(v)

	# If the failure message is too long it gets truncated; print each line
	# explicitly so the developer sees every offender even when there are many.
	if not all_violations.is_empty():
		for violation: String in all_violations:
			push_error(violation)

	assert_int(all_violations.size()).override_failure_message(
		"PanelContainer single-child invariant violated in %d location(s). See pushed errors. "
		+ "Fix by wrapping the PanelContainer's children in a VBoxContainer (see tests/PATTERNS.md §14)."
		% all_violations.size()
	).is_equal(0)


# ---------------------------------------------------------------------------
# Helper — recursively collect .tscn paths under a res:// directory.
# ---------------------------------------------------------------------------

func _collect_tscn_recursive(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = dir_path + "/" + entry
		if dir.current_is_dir():
			_collect_tscn_recursive(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
