# AC-29-14: No tutorial overlay text exists in the codebase.
#
# The cozy register is enforced by ABSENCE of tutorial copy — the player
# discovers the game through the UI itself, not through "Click here" hints
# or "Welcome!" splashes. Per Onboarding GDD #29 §H AC-29-14.
#
# This is a CI-grep style test mirroring AC-FA-09, AC-FA-12, AC-RC-14, and
# the ADR-0014 forbidden-patterns suite. Scans assets/ + src/ for the
# 4 canonical forbidden phrases. Locale CSVs are exempt (they don't ship
# as production text rendering surfaces).
extends GdUnitTestSuite

const FORBIDDEN_PHRASES: Array[String] = [
	"Click here",
	"Tap to begin",
	"Welcome!",
	"Press to dispatch",
]


func test_no_tutorial_overlay_copy_in_production_source() -> void:
	var hits: Array[String] = []
	for phrase: String in FORBIDDEN_PHRASES:
		_scan_dir_for_phrase("res://src/", phrase, hits)
		_scan_dir_for_phrase("res://assets/screens/", phrase, hits)
		_scan_dir_for_phrase("res://assets/overlays/", phrase, hits)
	assert_int(hits.size()).override_failure_message(
		"AC-29-14 violation: tutorial overlay copy found in production code. "
		+ "The cozy register is enforced by absence of these phrases. Hits: %s"
		% str(hits)
	).is_equal(0)


func _scan_dir_for_phrase(path: String, phrase: String, hits: Array[String]) -> void:
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
			_scan_dir_for_phrase(entry_path + "/", phrase, hits)
		elif entry.ends_with(".gd") or entry.ends_with(".tscn"):
			var f: FileAccess = FileAccess.open(entry_path, FileAccess.READ)
			if f != null:
				var contents: String = f.get_as_text()
				f.close()
				# Strip comment lines so doc-comments about WHY this rule exists
				# don't false-positive (this file itself mentions the phrases).
				var lines: PackedStringArray = contents.split("\n")
				for raw_line: String in lines:
					var line: String = raw_line.strip_edges()
					if line.begins_with("#") or line.begins_with(";"):
						continue
					if line.contains(phrase):
						hits.append("%s — phrase: %s" % [entry_path, phrase])
						break
		entry = dir.get_next()
	dir.list_dir_end()
