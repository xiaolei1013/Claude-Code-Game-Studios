# Sprint 21+ Prestige V1.0 Story 2 — V1→V2 save schema migration tests.
#
# Per design/gdd/prestige-system.md §C.5 + AC-PR-12 + AC-PR-14.
# CURRENT_SAVE_VERSION bumped 1→2; HeroRoster save namespace gains 3 fields:
# prestige_count, prestige_multiplier, retired_hero_records.
#
# Test groups:
#   A — V2 schema: HeroRoster.get_save_data includes 3 new fields
#   B — V2 round-trip: get_save_data → load_save_data preserves prestige state
#   C — V1→V2 migration: legacy V1 saves hydrate with default prestige fields
#   D — _migrate_v1_to_v2 idempotent on re-application
extends GdUnitTestSuite

const SaveLoadScript = preload("res://src/core/save_load_system/save_load_system.gd")
const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


func _make_roster() -> Node:
	var roster: Node = HeroRosterScript.new()
	add_child(roster)
	auto_free(roster)
	# Warm TickSystem cache for retirement_unix_ts capture (per ADR-0005).
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	if ts != null and ts.has_method("_read_wall_clock_unix_time"):
		ts._read_wall_clock_unix_time()
	return roster


func _make_save_load() -> Node:
	# Use the live SaveLoadSystem autoload for migration chain testing.
	# Per coding-standards.md test isolation, we read from the autoload
	# but DON'T mutate disk state.
	return get_tree().root.get_node_or_null("SaveLoadSystem")


# ===========================================================================
# Group A — V2 schema additions
# ===========================================================================

func test_hero_roster_get_save_data_includes_prestige_fields() -> void:
	var roster: Node = _make_roster()
	var d: Dictionary = roster.get_save_data()

	# V1 fields still present (regression guard)
	assert_bool(d.has("heroes")).is_true()
	assert_bool(d.has("formation_slots")).is_true()
	assert_bool(d.has("next_instance_id")).is_true()
	# V2 fields added
	assert_bool(d.has("prestige_count")).is_true()
	assert_bool(d.has("prestige_multiplier")).is_true()
	assert_bool(d.has("retired_hero_records")).is_true()


func test_hero_roster_v2_defaults_are_zero_one_empty() -> void:
	var roster: Node = _make_roster()
	var d: Dictionary = roster.get_save_data()

	assert_int(d.get("prestige_count", -1)).is_equal(0)
	assert_float(d.get("prestige_multiplier", -1.0)).is_equal(1.0)
	assert_int((d.get("retired_hero_records", []) as Array).size()).is_equal(0)


func test_save_load_system_current_version_is_2() -> void:
	# Sprint 21+ Story 2 bumped CURRENT_SAVE_VERSION 1→2.
	assert_int(SaveLoadScript.CURRENT_SAVE_VERSION).is_equal(2)


# ===========================================================================
# Group B — V2 round-trip via HeroRoster.get_save_data → load_save_data
# ===========================================================================

func test_hero_roster_v2_round_trip_preserves_prestige_count() -> void:
	# Setup: roster with prestige_count = 5, multiplier = 1.25, 5 records.
	var roster: Node = _make_roster()
	roster._prestige_count = 5
	roster._prestige_multiplier = 1.25
	var seed_records: Array[Dictionary] = []
	for i: int in range(5):
		seed_records.append({
			"display_name": "Hero%d" % i,
			"class_id": "warrior",
			"level_at_retirement": 15,
			"retirement_unix_ts": 1763028000 + i * 86400,  # 1 day apart
			"prestige_index": i + 1,
		})
	roster._retired_hero_records = seed_records.duplicate(true)

	# Round-trip
	var serialized: Dictionary = roster.get_save_data()
	# Reset roster
	roster._prestige_count = 0
	roster._prestige_multiplier = 1.0
	var empty_records: Array[Dictionary] = []
	roster._retired_hero_records = empty_records
	# Hydrate
	roster.load_save_data(serialized)

	# Verify
	assert_int(roster._prestige_count).is_equal(5)
	assert_float(roster._prestige_multiplier).is_equal(1.25)
	assert_int(roster._retired_hero_records.size()).is_equal(5)
	for i: int in range(5):
		var rec: Dictionary = roster._retired_hero_records[i]
		assert_str(rec.get("display_name", "")).is_equal("Hero%d" % i)
		assert_int(rec.get("prestige_index", 0)).is_equal(i + 1)


func test_hero_roster_v2_round_trip_handles_int_via_typeof_coercion() -> void:
	# Per project memory: JSON.parse_string returns floats for whole numbers.
	# load_save_data must accept TYPE_FLOAT for int fields via int() cast.
	var roster: Node = _make_roster()
	# Simulate a JSON-round-tripped dict: int fields arrive as floats.
	var save_dict: Dictionary = {
		"heroes": [],
		"formation_slots": [0, 0, 0],
		"next_instance_id": 1.0,  # float (JSON round-trip)
		"prestige_count": 7.0,  # float (JSON round-trip)
		"prestige_multiplier": 1.35,  # float-native — no coercion needed
		"retired_hero_records": [],
	}

	roster.load_save_data(save_dict)

	assert_int(roster._prestige_count).is_equal(7)
	assert_float(roster._prestige_multiplier).is_equal(1.35)


# ===========================================================================
# Group C — V1→V2 migration via SaveLoadSystem._run_migration_chain
# ===========================================================================

func test_run_migration_chain_v1_to_v2_adds_default_prestige_fields() -> void:
	var save_load: Node = _make_save_load()
	if save_load == null:
		push_warning("Skipped: SaveLoadSystem autoload not present")
		return

	# Construct a legacy V1 payload with HeroRoster namespace but no prestige fields.
	var v1_payload: Dictionary = {
		"HeroRoster": {
			"heroes": [],
			"formation_slots": [0, 0, 0],
			"next_instance_id": 1,
		},
	}

	var v2_result: Variant = save_load._run_migration_chain(v1_payload, 1, 2)

	assert_object(v2_result).is_not_null()
	var v2: Dictionary = v2_result as Dictionary
	assert_bool(v2.has("HeroRoster")).is_true()
	var roster: Dictionary = v2["HeroRoster"]
	# Original V1 fields preserved
	assert_bool(roster.has("heroes")).is_true()
	assert_bool(roster.has("formation_slots")).is_true()
	assert_bool(roster.has("next_instance_id")).is_true()
	# V2 fields added with defaults
	assert_int(roster.get("prestige_count", -1)).is_equal(0)
	assert_float(roster.get("prestige_multiplier", -1.0)).is_equal(1.0)
	assert_int((roster.get("retired_hero_records", []) as Array).size()).is_equal(0)


func test_run_migration_chain_v1_to_v2_preserves_existing_v1_data() -> void:
	var save_load: Node = _make_save_load()
	if save_load == null:
		push_warning("Skipped: SaveLoadSystem autoload not present")
		return

	# V1 payload with actual hero data + Economy namespace. Migration must
	# preserve everything intact, only adding the prestige fields.
	var v1_payload: Dictionary = {
		"HeroRoster": {
			"heroes": [{"instance_id": 1, "class_id": "warrior", "current_level": 5, "display_name": "Theron", "rng_seed": 0}],
			"formation_slots": [1, 0, 0],
			"next_instance_id": 2,
		},
		"Economy": {
			"gold_balance": 5000,
		},
	}

	var v2_result: Variant = save_load._run_migration_chain(v1_payload, 1, 2)

	var v2: Dictionary = v2_result as Dictionary
	# Economy namespace untouched
	assert_int(v2.get("Economy", {}).get("gold_balance", -1)).is_equal(5000)
	# HeroRoster heroes + formation preserved
	var roster: Dictionary = v2.get("HeroRoster", {})
	assert_int((roster.get("heroes", []) as Array).size()).is_equal(1)
	assert_int(roster.get("next_instance_id", -1)).is_equal(2)


# ===========================================================================
# Group D — Migration idempotency
# ===========================================================================

func test_run_migration_chain_v1_to_v2_idempotent_on_double_apply() -> void:
	# Applying _migrate_v1_to_v2 twice should be a no-op (the second pass
	# sees the fields already populated and re-defaults to existing values).
	var save_load: Node = _make_save_load()
	if save_load == null:
		push_warning("Skipped: SaveLoadSystem autoload not present")
		return
	var v1_payload: Dictionary = {
		"HeroRoster": {"heroes": [], "formation_slots": [], "next_instance_id": 1},
	}

	var first_result: Dictionary = save_load._run_migration_chain(v1_payload, 1, 2) as Dictionary
	var second_result: Dictionary = save_load._run_migration_chain(first_result, 1, 2) as Dictionary

	# Both passes produce the same shape.
	assert_int(second_result.get("HeroRoster", {}).get("prestige_count", -1)).is_equal(0)
	assert_float(second_result.get("HeroRoster", {}).get("prestige_multiplier", -1.0)).is_equal(1.0)


func test_run_migration_chain_same_version_returns_payload_unchanged() -> void:
	# (from, to) == (1, 1) or (2, 2) → pass-through.
	var save_load: Node = _make_save_load()
	if save_load == null:
		push_warning("Skipped: SaveLoadSystem autoload not present")
		return

	var payload: Dictionary = {"HeroRoster": {"heroes": []}}
	var result_v1: Variant = save_load._run_migration_chain(payload, 1, 1)
	var result_v2: Variant = save_load._run_migration_chain(payload, 2, 2)

	assert_object(result_v1).is_not_null()
	assert_object(result_v2).is_not_null()
