# Sprint 21 S21-M1 / Class Synergy V1.0 first-pass — Story 1 detection tests.
#
# Per design/gdd/class-synergy-system.md §C.1 + §D.1 + AC-CS-01..05:
# detection is a pure function over the multiset of class_id strings in the
# formation. Returns the active synergy id String, or "" if no synergy
# matches OR any slot is empty.
#
# Test groups:
#   A — heroes-path detection (Dictionary path; no autoload dep)
#       AC-CS-01: 3 Warriors → "steel_wall"
#       AC-CS-02: 3 Mages    → "arcane_elite"
#       AC-CS-03: 1+1+1 mix  → "triple_threat"
#       AC-CS-04: 2+1 mix    → ""
#       AC-CS-05: empty slot → ""
#   B — order independence (sorted-multiset comparison)
#   C — defensive handling (missing keys, wrong types, partial dicts)
#   D — RunSnapshot.synergy_id field round-trip via to_dict / from_dict
#   E — RunSnapshot.synergy_id forward-compat (V1.5+ unknown id; missing field)
extends GdUnitTestSuite

const FormationAssignmentScript = preload("res://src/core/formation_assignment/formation_assignment.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")


func _make_fa() -> Node:
	var fa: Node = FormationAssignmentScript.new()
	add_child(fa)
	auto_free(fa)
	return fa


func _heroes_dict(class_ids: Array[String]) -> Dictionary:
	var heroes: Array[Dictionary] = []
	var instance_ids: Array[int] = []
	var next_id: int = 100
	for cid: String in class_ids:
		heroes.append({"instance_id": next_id, "class_id": cid})
		instance_ids.append(next_id)
		next_id += 1
	return {"instance_ids": instance_ids, "heroes": heroes}


# ===========================================================================
# Group A — heroes-path detection (AC-CS-01..05)
# ===========================================================================

func test_detect_active_synergy_three_warriors_returns_steel_wall() -> void:
	var fa: Node = _make_fa()
	var formation: Array[String] = ["warrior", "warrior", "warrior"]
	var snapshot: Dictionary = _heroes_dict(formation)

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("steel_wall")


func test_detect_active_synergy_three_mages_returns_arcane_elite() -> void:
	var fa: Node = _make_fa()
	var formation: Array[String] = ["mage", "mage", "mage"]
	var snapshot: Dictionary = _heroes_dict(formation)

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("arcane_elite")


func test_detect_active_synergy_one_plus_one_plus_one_returns_triple_threat() -> void:
	var fa: Node = _make_fa()
	var formation: Array[String] = ["warrior", "mage", "rogue"]
	var snapshot: Dictionary = _heroes_dict(formation)

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("triple_threat")


func test_detect_active_synergy_two_plus_one_returns_empty() -> void:
	var fa: Node = _make_fa()
	# 2 Warriors + 1 Mage: V1.0 first-pass does not include 2+1 mixes.
	var formation: Array[String] = ["warrior", "warrior", "mage"]
	var snapshot: Dictionary = _heroes_dict(formation)

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("")


func test_detect_active_synergy_three_rogues_returns_empty() -> void:
	# Note: 3 Rogues is NOT a V1.0 first-pass synergy (only 3W, 3M, and 1+1+1).
	# 3 Rogues IS a V1.5+ candidate but explicitly not in the first-pass roster.
	var fa: Node = _make_fa()
	var formation: Array[String] = ["rogue", "rogue", "rogue"]
	var snapshot: Dictionary = _heroes_dict(formation)

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("")


func test_detect_active_synergy_empty_slot_class_id_returns_empty() -> void:
	# AC-CS-05: any slot with empty class_id → no synergy possible.
	var fa: Node = _make_fa()
	var snapshot: Dictionary = {
		"heroes": [
			{"instance_id": 1, "class_id": "warrior"},
			{"instance_id": 2, "class_id": ""},  # Empty slot — no synergy
			{"instance_id": 3, "class_id": "warrior"},
		]
	}

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("")


# ===========================================================================
# Group B — order independence (sorted-multiset comparison)
# ===========================================================================

func test_detect_active_synergy_mix_in_any_order_returns_triple_threat() -> void:
	var fa: Node = _make_fa()
	# Permutation 1: W M R
	var snap1: Dictionary = _heroes_dict(["warrior", "mage", "rogue"])
	# Permutation 2: R W M
	var snap2: Dictionary = _heroes_dict(["rogue", "warrior", "mage"])
	# Permutation 3: M R W
	var snap3: Dictionary = _heroes_dict(["mage", "rogue", "warrior"])

	assert_str(fa.detect_active_synergy(snap1)).is_equal("triple_threat")
	assert_str(fa.detect_active_synergy(snap2)).is_equal("triple_threat")
	assert_str(fa.detect_active_synergy(snap3)).is_equal("triple_threat")


# ===========================================================================
# Group C — defensive handling
# ===========================================================================

func test_detect_active_synergy_missing_both_keys_returns_empty() -> void:
	var fa: Node = _make_fa()
	var snapshot: Dictionary = {}

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("")


func test_detect_active_synergy_only_two_heroes_returns_empty() -> void:
	# FORMATION_SIZE = 3 per hero-roster.md §C.10. Anything else → no synergy.
	var fa: Node = _make_fa()
	var snapshot: Dictionary = _heroes_dict(["warrior", "warrior"])

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("")


func test_detect_active_synergy_four_heroes_returns_empty() -> void:
	var fa: Node = _make_fa()
	var snapshot: Dictionary = _heroes_dict(["warrior", "warrior", "warrior", "warrior"])

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("")


func test_detect_active_synergy_non_dictionary_hero_returns_empty() -> void:
	var fa: Node = _make_fa()
	var snapshot: Dictionary = {
		"heroes": ["not_a_dict", "also_not_a_dict", "still_not"]
	}

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("")


func test_detect_active_synergy_pure_function_no_state_change() -> void:
	# Calling detect_active_synergy multiple times on the same snapshot
	# returns the same result + does NOT mutate any state. Per AC-CS-20
	# performance budget assumption (pure function, idempotent).
	var fa: Node = _make_fa()
	var snapshot: Dictionary = _heroes_dict(["warrior", "warrior", "warrior"])

	var r1: String = fa.detect_active_synergy(snapshot)
	var r2: String = fa.detect_active_synergy(snapshot)
	var r3: String = fa.detect_active_synergy(snapshot)

	assert_str(r1).is_equal("steel_wall")
	assert_str(r2).is_equal("steel_wall")
	assert_str(r3).is_equal("steel_wall")
	# Snapshot dict is unchanged.
	var heroes_after: Variant = snapshot.get("heroes", [])
	assert_int((heroes_after as Array).size()).is_equal(3)


# ===========================================================================
# Group D — RunSnapshot.synergy_id field round-trip
# ===========================================================================

func test_run_snapshot_synergy_id_default_empty_string() -> void:
	var snap: RunSnapshot = RunSnapshotScript.new()
	assert_str(snap.synergy_id).is_equal("")


func test_run_snapshot_synergy_id_round_trip_via_to_dict_from_dict() -> void:
	# AC-CS-12: save round-trip preserves synergy_id verbatim.
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.synergy_id = "steel_wall"

	var serialized: Dictionary = snap.to_dict()
	assert_str(serialized.get("synergy_id", "")).is_equal("steel_wall")

	var restored: RunSnapshot = RunSnapshotScript.new()
	restored.from_dict(serialized)
	assert_str(restored.synergy_id).is_equal("steel_wall")


func test_run_snapshot_synergy_id_equals_includes_synergy_field() -> void:
	# equals() must consider synergy_id (so save round-trip parity tests
	# correctly catch a synergy_id round-trip regression).
	var a: RunSnapshot = RunSnapshotScript.new()
	a.synergy_id = "arcane_elite"
	var b: RunSnapshot = RunSnapshotScript.new()
	b.synergy_id = "arcane_elite"
	assert_bool(a.equals(b)).is_true()

	b.synergy_id = "steel_wall"
	assert_bool(a.equals(b)).is_false()


# ===========================================================================
# Group E — forward-compat (AC-CS-18)
# ===========================================================================

func test_run_snapshot_synergy_id_missing_field_defaults_to_empty() -> void:
	# AC-CS-12 + AC-CS-18: legacy V1 saves (pre-Class-Synergy) hydrate
	# cleanly with synergy_id defaulting to "" (no synergy).
	var snap: RunSnapshot = RunSnapshotScript.new()
	# Construct a minimal dict without the synergy_id key (mimics a legacy
	# pre-Class-Synergy save).
	var legacy_dict: Dictionary = {
		"formation_snapshot": {},
		"floor_id": "",
		"current_tick": 0,
		"last_emitted_tick": 0,
		"losing_run": false,
		"floor_clear_emitted": false,
		"matchup_cache": {},
		"kill_schedule": [],
		"loop_counter": 0,
		"kill_count": 0,
		"floor_was_valid": true,
		# synergy_id intentionally absent
	}

	snap.from_dict(legacy_dict)

	assert_str(snap.synergy_id).is_equal("")


func test_run_snapshot_synergy_id_v15_unknown_id_round_trips_verbatim() -> void:
	# AC-CS-18: a hypothetical V1.5 synergy_id ("veteran_squad") loaded
	# by V1.0 build's RunSnapshot is preserved verbatim in the field.
	# The resolver's switch (in DungeonRunOrchestrator's per-kill formula)
	# is the layer that returns 1.0 for unknown ids — RunSnapshot just stores.
	var snap: RunSnapshot = RunSnapshotScript.new()
	var v15_dict: Dictionary = {"synergy_id": "veteran_squad"}

	snap.from_dict(v15_dict)

	assert_str(snap.synergy_id).is_equal("veteran_squad")


# ===========================================================================
# Group F — instance_ids-only fallback path (live HeroRoster autoload lookup)
#
# These tests lock in the contract that detect_active_synergy resolves
# instance_ids through HeroRoster.get_all_heroes() when the heroes key is
# absent. Pre-2026-05-10 the fallback called a non-existent
# HeroRoster.get_hero(id) method and silently returned ""; CI surfaced this
# during synergy_badge_test.gd Story 4 implementation. The fix uses the
# canonical instance_id → HeroInstance lookup-map idiom (same pattern as
# DungeonRunOrchestrator.snapshot_formation_for_run + the screen's
# _refresh_formation_panel display_name lookup).
# ===========================================================================

const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

var _injected_hero_ids: Array[int] = []


func _inject_hero_into_live_roster(id: int, class_id: String) -> void:
	# Inject directly into HeroRoster._heroes so get_all_heroes() returns
	# the test fixture. Cleanup in after_test.
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = class_id
	fake.display_name = "TestHero%d" % id
	fake.current_level = 1
	fake.xp = 0
	HeroRoster._heroes[id] = fake
	_injected_hero_ids.append(id)


func after_test() -> void:
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()


func test_detect_active_synergy_instance_ids_only_resolves_via_live_roster() -> void:
	# instance_ids-only snapshot (no heroes key) → fallback path resolves
	# via HeroRoster.get_all_heroes() lookup map → returns the correct
	# synergy id. This was a silent dead path pre-2026-05-10.
	var fa: Node = _make_fa()
	_inject_hero_into_live_roster(8901, "warrior")
	_inject_hero_into_live_roster(8902, "warrior")
	_inject_hero_into_live_roster(8903, "warrior")
	var snapshot: Dictionary = {"instance_ids": [8901, 8902, 8903]}

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("steel_wall")


func test_detect_active_synergy_instance_ids_only_returns_empty_for_unknown_id() -> void:
	# Defensive: if any instance_id is missing from the live roster, the
	# fallback returns "" (not crash). Mirrors the behavior the heroes
	# path has for empty class_id.
	var fa: Node = _make_fa()
	_inject_hero_into_live_roster(8911, "warrior")
	_inject_hero_into_live_roster(8912, "warrior")
	# 8913 NOT injected — third slot's id is unknown to HeroRoster.
	var snapshot: Dictionary = {"instance_ids": [8911, 8912, 8913]}

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("")


func test_detect_active_synergy_instance_ids_only_returns_empty_for_zero_slot() -> void:
	# Empty-slot guard mirrors AC-CS-05 for the heroes path.
	var fa: Node = _make_fa()
	_inject_hero_into_live_roster(8921, "warrior")
	_inject_hero_into_live_roster(8922, "warrior")
	var snapshot: Dictionary = {"instance_ids": [8921, 8922, 0]}

	var result: String = fa.detect_active_synergy(snapshot)

	assert_str(result).is_equal("")
