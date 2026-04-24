class_name DataRegistryFixtures
extends RefCounted

## Shared test fixture helpers for DataRegistry unit and integration tests.
##
## Programmatically writes .tres fixture trees rooted under a caller-provided
## path, then tears them down via [method cleanup] on teardown. Keeps
## fixture-authoring logic out of the test files and prevents
## hand-edited .tres files from drifting as the GameData schema evolves.
##
## Callers are expected to:
##   1. Declare a per-test FIXTURE_ROOT under res://tests/fixtures/data_registry/
##   2. Call [method write] in before_test or at the top of each test
##   3. Call [method cleanup] in after_test
##
## Usage:
##   [codeblock]
##   const DataRegistryFixtures = preload("res://tests/fixtures/data_registry/fixture_helpers.gd")
##   const FIXTURE_ROOT := "res://tests/fixtures/data_registry/my_test/"
##
##   func after_test() -> void:
##       DataRegistryFixtures.cleanup(FIXTURE_ROOT)
##
##   func test_something() -> void:
##       DataRegistryFixtures.write(FIXTURE_ROOT, {
##           "classes": [{"id": "hero_warrior", "display_name": "Warrior"}],
##           "enemies": [],
##       })
##       ...
##   [/codeblock]

const TestContentType = preload("res://tests/fixtures/data_registry/test_content_type.gd")


## Creates the fixture directory tree and saves the provided content map.
##
## [param root]: res:// path ending in "/", rooted under tests/fixtures/ for isolation.
## [param fixture_map]: Dictionary of shape
##   [code]{"category": [{"id": "...", "display_name": "..."}, ...]}[/code].
## All categories present as keys have their directories created even when the
## value array is empty — simulates the "empty category" scenario.
##
## File names derive from the resource's [code]id[/code] field; empty-id
## entries save under [code]unnamed.tres[/code] which the DataRegistry
## boot scan will reject as an InvalidId.
static func write(root: String, fixture_map: Dictionary) -> void:
	for category: String in fixture_map:
		var dir_path: String = root + category
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
		for entry: Dictionary in fixture_map[category]:
			var res: TestContentType = TestContentType.new()
			res.id = entry.get("id", "")
			res.display_name = entry.get("display_name", "")
			var filename: String = res.id if res.id != "" else "unnamed"
			ResourceSaver.save(res, "%s/%s.tres" % [dir_path, filename])


## Recursively removes a fixture directory tree.
##
## Deletes all files and subdirectories under [param root], then removes
## [param root] itself. Safe to call on a non-existent path — returns silently
## if the directory does not exist.
##
## [param root]: res:// path (trailing slash optional).
static func cleanup(root: String) -> void:
	_remove_dir_recursive(root.trim_suffix("/"))


static func _remove_dir_recursive(path: String) -> void:
	var da: DirAccess = DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	var entry: String = da.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = da.get_next()
			continue
		var full: String = path + "/" + entry
		if da.current_is_dir():
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full))
		entry = da.get_next()
	da.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
