## HeroRoster test-isolation fixture helpers.
##
## Sprint 24 S24-S3 — consolidates ~5+ sites of repeated test setup boilerplate
## that mutate live `/root/HeroRoster` state. Per the project memory entry
## `feedback_test_isolation_live_autoload.md`: tests mutating autoload state
## must snapshot+restore via get_save_data/load_save_data, not just erase-by-id
## (save persistence leakage risk).
##
## ## Usage pattern (canonical)
##
## ```gdscript
## extends GdUnitTestSuite
##
## const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")
##
## var _snapshot: Dictionary = {}
##
## func before_test() -> void:
##     _snapshot = HeroRosterFixture.snapshot_via_save_data()
##     HeroRosterFixture.reset_hero_roster()
##
## func after_test() -> void:
##     HeroRosterFixture.restore_via_load_save_data(_snapshot)
##
## func test_my_thing() -> void:
##     # Arrange — seed 3 warriors (Steel Wall trigger)
##     var ids: Array[int] = HeroRosterFixture.seed_warriors(3)
##     # ... act + assert ...
## ```
##
## ## Why this exists
##
## Pre-existing sites do this boilerplate inline:
## ```gdscript
## func before_test() -> void:
##     HeroRoster._prestige_count = 0
##     HeroRoster._prestige_multiplier = 1.0
##     HeroRoster._retired_hero_records.clear()
##
## func after_test() -> void:
##     HeroRoster._prestige_count = 0
##     # ... etc
## ```
##
## The duplication multiplies the surface for forgetting-to-reset bugs. Each
## time a new HeroRoster field is added, every test file's reset block must
## be updated. The helper centralizes the contract.
##
## ## Engine note
##
## Snapshot uses `get_save_data()` which is the canonical autoload save-consumer
## surface (per save-load-system.md). Restore uses `load_save_data(snapshot)`
## which fully rebuilds state from the dict (clears existing state first per
## the contract in `hero_roster.gd::load_save_data`).
##
## This is a static-method helper class — no instance state, safe to call
## directly via the class reference (`HeroRosterFixture.reset_hero_roster()`).
class_name HeroRosterTestFixture
extends RefCounted


## Snapshots the live HeroRoster autoload state via `get_save_data()`.
##
## Returns an opaque Dictionary that can be passed back to
## [method restore_via_load_save_data] to fully restore the autoload state.
## The dict is a deep-copy via `Dictionary.duplicate(true)` so subsequent
## mutations of the live autoload do not affect the snapshot.
##
## Returns an empty Dictionary if the HeroRoster autoload is missing
## (defensive — should never happen in test envs that have project.godot
## autoloads wired).
static func snapshot_via_save_data() -> Dictionary:
	var roster: Node = _get_hero_roster()
	if roster == null:
		return {}
	var data: Dictionary = roster.get_save_data()
	return data.duplicate(true)


## Restores the live HeroRoster autoload state from a snapshot returned by
## [method snapshot_via_save_data]. Calls `load_save_data(snapshot)` which
## fully rebuilds the autoload's `_heroes`, `_prestige_count`, etc. per the
## save-consumer contract.
##
## Defensive: silently no-ops if HeroRoster is missing or snapshot is empty.
static func restore_via_load_save_data(snapshot: Dictionary) -> void:
	var roster: Node = _get_hero_roster()
	if roster == null or snapshot.is_empty():
		return
	roster.load_save_data(snapshot)


## Resets the HeroRoster autoload to a known clean state:
## - `_heroes.clear()`
## - `_prestige_count = 0`
## - `_prestige_multiplier = 1.0`
## - `_retired_hero_records.clear()`
## - `_formation_slots = [0, 0, 0]`
## - `_next_instance_id = 1`
##
## Equivalent to `load_save_data({heroes: [], formation_slots: [0, 0, 0],
## next_instance_id: 1, prestige_count: 0, prestige_multiplier: 1.0,
## retired_hero_records: []})` but cheaper (no dict serialization round-trip).
##
## Defensive: silently no-ops if HeroRoster is missing.
static func reset_hero_roster() -> void:
	var roster: Node = _get_hero_roster()
	if roster == null:
		return
	# Use load_save_data with the canonical "empty fresh save" shape. This
	# routes through the autoload's own state-reset path, keeping the helper
	# decoupled from private-field names that might rename in future refactors.
	roster.load_save_data({
		"heroes": [],
		"formation_slots": [0, 0, 0],
		"next_instance_id": 1,
		"prestige_count": 0,
		"prestige_multiplier": 1.0,
		"retired_hero_records": [],
	})


## Adds [param count] warriors to the roster and assigns each to a formation
## slot (slots 0..count-1, capped at formation_size). Returns the array of
## instance_ids in insertion order.
##
## Use after [method reset_hero_roster] to seed a known-clean warrior-only
## roster — the Steel Wall composition trigger for synergy tests.
##
## Defensive: returns empty Array if HeroRoster is missing or `add_hero`
## returns null (e.g., DataRegistry doesn't have "warrior" registered).
static func seed_warriors(count: int) -> Array[int]:
	var ids: Array[int] = []
	var roster: Node = _get_hero_roster()
	if roster == null:
		return ids
	for i: int in range(count):
		var inst: RefCounted = roster.call("add_hero", "warrior") as RefCounted
		if inst == null:
			break
		ids.append(int(inst.get("instance_id")))
	# Assign to formation slots in order (capped at formation_size).
	var slot_count: int = roster.call("formation_size") as int
	for slot: int in range(min(ids.size(), slot_count)):
		roster.call("set_formation_slot", slot, ids[slot])
	return ids


## Adds heroes of the given class_ids in order; returns instance_ids.
## Useful for seeding mixed compositions (e.g., 1+1+1 Triple Threat) without
## the per-class-call boilerplate.
##
## Example: `seed_heroes(["warrior", "mage", "rogue"]) -> [1, 2, 3]`
##
## Slot assignment mirrors [method seed_warriors] — each hero is placed in
## the corresponding formation slot in insertion order.
static func seed_heroes(class_ids: Array[String]) -> Array[int]:
	var ids: Array[int] = []
	var roster: Node = _get_hero_roster()
	if roster == null:
		return ids
	for class_id: String in class_ids:
		var inst: RefCounted = roster.call("add_hero", class_id) as RefCounted
		if inst == null:
			break
		ids.append(int(inst.get("instance_id")))
	var slot_count: int = roster.call("formation_size") as int
	for slot: int in range(min(ids.size(), slot_count)):
		roster.call("set_formation_slot", slot, ids[slot])
	return ids


## Returns the HeroRoster autoload Node, or null if absent.
static func _get_hero_roster() -> Node:
	# Goldot autoload lookup via SceneTree root path. The autoload is registered
	# in project.godot at /root/HeroRoster. Tests run in a SceneTree, so
	# Engine.get_main_loop() is the canonical path.
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		return tree.root.get_node_or_null("HeroRoster")
	return null
