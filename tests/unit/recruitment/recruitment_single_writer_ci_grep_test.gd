# Sprint 12 — AC-RC-14 single-writer CI grep enforcement.
#
# Per design/gdd/recruitment-system.md §C.5 + AC-RC-14: HeroRoster.add_hero
# has at most ONE production caller across the whole src/ tree, located in
# `src/core/recruitment/recruitment.gd`. Tests + HeroRoster's own internal
# bootstrap (seed_first_launch_state) are exempt.
#
# This is a structural source-inspection test that acts as the in-engine
# equivalent of:
#   grep -rn "add_hero" src/ | grep -v hero_roster.gd | grep -v "##"
#
# The invariant: exactly ONE file under src/ outside hero_roster.gd
# contains non-comment lines mentioning add_hero, and that file is
# `src/core/recruitment/recruitment.gd`.
#
# Mirrors the tick_system single-call-site test pattern. The fragility to
# regression is the feature: any new HeroRoster.add_hero caller fails CI.
#
# Forbidden-pattern entry: `add_hero_outside_recruitment` (per ADR-0003
# forbidden-patterns registry, mirroring `formation_slot_write_outside_formation_assignment`
# from S11-X2's symmetric pattern).
extends GdUnitTestSuite

const SRC_ROOT: String = "res://src"


# ---------------------------------------------------------------------------
# Helper: recursively collect all .gd file paths under a res:// directory.
# Mirrors the tick_system test's helper exactly.
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
# Helper: returns true if any non-comment line in the file mentions the
# search string. Comment lines (starting with # or ##) are excluded.
# ---------------------------------------------------------------------------
func _file_has_code_mention(file_path: String, search: String) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	while not file.eof_reached():
		var line: String = file.get_line()
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		if search in stripped:
			file.close()
			return true
	file.close()
	return false


# ===========================================================================
# Test 1 — AC-RC-14: HeroRoster.add_hero has exactly one production caller
# ===========================================================================

func test_add_hero_has_exactly_one_production_caller_outside_hero_roster() -> void:
	# Arrange — collect all .gd files under src/, excluding hero_roster.gd
	# (the definition file). The seed_first_launch_state() call is internal
	# to hero_roster.gd and exempt per §C.5.
	var all_gd_files: Array[String] = _collect_gd_files(SRC_ROOT)
	assert_bool(all_gd_files.size() > 0).is_true()  # sanity: src/ has files

	# Filter out hero_roster.gd (definition) and hero_instance.gd (sibling
	# RefCounted whose doc-comments mention HeroRoster.add_hero — but those
	# are ## doc lines filtered by _file_has_code_mention).
	var caller_files: Array[String] = []
	for path: String in all_gd_files:
		# hero_roster.gd is the canonical definition file; skip outright.
		if path.ends_with("hero_roster.gd"):
			continue
		# Look for any non-comment mention of "add_hero" — the call shape
		# is either `HeroRoster.add_hero(` (direct autoload call) or
		# `roster.call("add_hero",` (Node-typed call). Both contain the
		# literal substring "add_hero" in their code line.
		if _file_has_code_mention(path, "add_hero"):
			caller_files.append(path)

	# Assert — exactly one caller file, and it must be recruitment.gd.
	assert_int(caller_files.size()).is_equal(1)
	assert_bool(caller_files[0].ends_with("recruitment.gd")).is_true()


# ===========================================================================
# Test 2 — AC-FA-12 sibling: HeroRoster.set_formation_slot has exactly one
# production caller (FormationAssignment.commit). Mirrors the AC-RC-14
# pattern for the FormationAssignment single-writer enforcement per
# formation-assignment-system.md §C.5.
#
# Co-located with AC-RC-14 because the two enforcement contracts are
# parallel; future authors looking at one will find the other.
# ===========================================================================

func test_set_formation_slot_has_exactly_one_production_caller_outside_hero_roster() -> void:
	var all_gd_files: Array[String] = _collect_gd_files(SRC_ROOT)
	var caller_files: Array[String] = []
	for path: String in all_gd_files:
		if path.ends_with("hero_roster.gd"):
			continue
		if _file_has_code_mention(path, "set_formation_slot"):
			caller_files.append(path)

	# Expected: exactly one caller in src/core/formation_assignment/.
	# (S11-X9 closure note documents this single-writer contract.)
	assert_int(caller_files.size()).is_equal(1)
	assert_bool(caller_files[0].ends_with("formation_assignment.gd")).is_true()
