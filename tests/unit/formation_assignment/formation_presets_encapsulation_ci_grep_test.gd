## formation_presets_encapsulation_ci_grep_test.gd — AC-FP-12 CI enforcement.
##
## Enforces the Formation Presets encapsulation contract
## (design/gdd/formation-presets.md AC-FP-12): the private preset state —
## `_presets` (the list) and `_next_preset_id` (the monotonic counter) — must
## NEVER be accessed from outside src/core/formation_assignment/. All callers
## (including the PresetsRow UI) go through the public API:
## save_preset / recall_preset / delete_preset / get_presets.
##
## Grep-based validation: recursively scans every .gd under res://src and
## res://assets and asserts no MEMBER ACCESS of the private fields appears.
##
## The forbidden tokens are `._presets` and `._next_preset_id` (member access
## with a leading dot) — NOT bare `_presets`. This is deliberate: the public
## accessor `max_presets()` contains the substring `_presets`, so a naive
## `_presets` grep would false-positive on every legitimate `fa.max_presets()`
## call. The leading dot scopes the match to instance member access.
extends GdUnitTestSuite

const _OWNING_MODULE: String = "src/core/formation_assignment"
const _FORBIDDEN_TOKENS: Array[String] = ["._presets", "._next_preset_id"]


func _read_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open file: %s (error %d)" % [path, FileAccess.get_open_error()])
		return ""
	return file.get_as_text()


## Recursively collects every .gd file path under [param root] into [param out].
## Skips hidden entries (e.g. .godot import cache) defensively.
func _collect_gd_files(root: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = root.path_join(entry)
		if dir.current_is_dir():
			_collect_gd_files(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


# ===========================================================================
# Group A — the scan itself
# ===========================================================================

func test_no_external_access_to_private_preset_state() -> void:
	var files: PackedStringArray = PackedStringArray()
	_collect_gd_files("res://src", files)
	_collect_gd_files("res://assets", files)

	var violations: Array[String] = []
	for path: String in files:
		if path.contains(_OWNING_MODULE):
			continue  # the owning module is allowed to touch its own state
		var source: String = _read_file(path)
		var lines: PackedStringArray = source.split("\n")
		for i: int in range(lines.size()):
			for token: String in _FORBIDDEN_TOKENS:
				if token in lines[i]:
					violations.append("%s:%d  %s" % [path, i + 1, lines[i].strip_edges()])

	# NOTE: parenthesize the whole concatenation before `%`. In GDScript `%`
	# binds tighter than `+`, so `"a" + "b" % [x, y]` would apply the format to
	# only the last literal (one %s) against two args → "not all arguments
	# converted". The parens make both %s placeholders share one format call.
	assert_array(violations).override_failure_message(
		("Formation-preset private state ('._presets' / '._next_preset_id') accessed " +
		"outside %s/ — violates the AC-FP-12 encapsulation contract. Use the public API " +
		"(save_preset / recall_preset / delete_preset / get_presets). Violations:\n%s")
		% [_OWNING_MODULE, "\n".join(violations)]
	).is_empty()


# ===========================================================================
# Group B — guard the guard
# ===========================================================================

func test_gd_file_collector_actually_finds_sources() -> void:
	# If the walker silently scanned nothing, the scan above would vacuously
	# pass. src/ holds many .gd files; lock a conservative floor.
	var files: PackedStringArray = PackedStringArray()
	_collect_gd_files("res://src", files)
	assert_int(files.size()).is_greater(10)


func test_owning_module_actually_defines_private_state() -> void:
	# If the fields were renamed/removed, the scan would silently pass forever.
	# Lock that the private state still exists with the expected names.
	var source: String = _read_file("res://src/core/formation_assignment/formation_assignment.gd")
	assert_str(source).is_not_empty()
	assert_bool(source.contains("var _presets")).is_true()
	assert_bool(source.contains("var _next_preset_id")).is_true()


func test_public_accessor_is_not_a_false_positive() -> void:
	# Proves the token choice: 'max_presets' (public) contains 'presets' but
	# NOT '._presets', so legitimate public-API calls never trip the scan.
	var public_call: String = "var n: int = fa.max_presets()"
	for token: String in _FORBIDDEN_TOKENS:
		assert_bool(token in public_call).is_false()
