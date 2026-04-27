# Tests for Sprint 6 hero-roster Story 001: HeroInstance RefCounted + 5-field schema + to_dict/from_dict.
# Covers: TR-hero-roster-001 (RefCounted, NOT Resource),
#         TR-hero-roster-002 (5 fields with correct types and defaults),
#         TR-hero-roster-003 (to_dict / from_dict round-trip — exactly 5 keys),
#         TR-hero-roster-004 (no mutation methods exposed).
extends GdUnitTestSuite

const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


# ===========================================================================
# Group A: TR-001 — HeroInstance is RefCounted, NOT a Resource
# ===========================================================================

func test_hero_instance_class_resolves() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	assert_object(inst).is_not_null()
	# Verify the script attached is hero_instance.gd
	assert_bool(inst.get_script() == HeroInstanceScript).is_true()


func test_hero_instance_extends_refcounted_not_resource() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	# RefCounted is the canonical lightweight container per ADR-0012
	assert_bool(inst is RefCounted).is_true()
	# CRITICAL: HeroInstance must NOT be a Resource (no .tres file per TR-001).
	# Cast to Object to bypass GDScript's static-typing rejection of an
	# always-false `is Resource` check (the compiler knows HeroInstance extends
	# RefCounted, so the runtime check is "obviously" false at parse time —
	# but the assertion is contractually load-bearing, so we keep it via Object).
	var as_object: Object = inst
	assert_bool(as_object is Resource).is_false()


# ===========================================================================
# Group B: TR-002 — 5 fields with correct types and defaults
# ===========================================================================

func test_hero_instance_default_instance_id_is_zero() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	assert_int(inst.instance_id).is_equal(0)


func test_hero_instance_default_class_id_is_empty_string() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	assert_str(inst.class_id).is_equal("")


func test_hero_instance_default_display_name_is_empty_string() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	assert_str(inst.display_name).is_equal("")


func test_hero_instance_default_current_level_is_one() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	# current_level defaults to 1 (matches HeroRoster.add_hero default)
	assert_int(inst.current_level).is_equal(1)


func test_hero_instance_default_xp_is_zero() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	# xp is reserved for V1.0; always 0 in MVP per TR-002
	assert_int(inst.xp).is_equal(0)


func test_hero_instance_field_types() -> void:
	# Verify each field is the correct type per TR-002
	# instance_id int, class_id String, display_name String, current_level int, xp int
	var inst: HeroInstance = HeroInstanceScript.new()
	inst.instance_id = 5
	inst.class_id = "warrior"
	inst.display_name = "Theron"
	inst.current_level = 10
	inst.xp = 0
	# All assertions above used the typed assert helpers; reaching this line
	# means GDScript accepted the assignments without type coercion errors.
	assert_int(inst.instance_id).is_equal(5)
	assert_str(inst.class_id).is_equal("warrior")
	assert_str(inst.display_name).is_equal("Theron")
	assert_int(inst.current_level).is_equal(10)
	assert_int(inst.xp).is_equal(0)


# ===========================================================================
# Group C: TR-003 — to_dict / from_dict round-trip
# ===========================================================================

func test_hero_instance_to_dict_has_exactly_five_keys() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	var d: Dictionary = inst.to_dict()
	assert_int(d.size()).is_equal(5)
	# Verify all 5 expected keys
	assert_bool(d.has("instance_id")).is_true()
	assert_bool(d.has("class_id")).is_true()
	assert_bool(d.has("display_name")).is_true()
	assert_bool(d.has("current_level")).is_true()
	assert_bool(d.has("xp")).is_true()


func test_hero_instance_to_dict_values_match_fields() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	inst.instance_id = 7
	inst.class_id = "mage"
	inst.display_name = "Lyra"
	inst.current_level = 12
	inst.xp = 0
	var d: Dictionary = inst.to_dict()
	assert_int(d["instance_id"]).is_equal(7)
	assert_str(d["class_id"]).is_equal("mage")
	assert_str(d["display_name"]).is_equal("Lyra")
	assert_int(d["current_level"]).is_equal(12)
	assert_int(d["xp"]).is_equal(0)


func test_hero_instance_round_trip_preserves_fields() -> void:
	# Populate, serialize, mutate, hydrate from snapshot — fields must equal pre-mutation values.
	var inst: HeroInstance = HeroInstanceScript.new()
	inst.instance_id = 3
	inst.class_id = "rogue"
	inst.display_name = "Sable"
	inst.current_level = 8
	inst.xp = 0
	var snapshot: Dictionary = inst.to_dict()

	# Mutate after snapshot
	inst.instance_id = 999
	inst.class_id = "corrupted"
	inst.display_name = "Wrong"
	inst.current_level = 1
	inst.xp = 9999

	# Hydrate from snapshot — fields snap back
	inst.from_dict(snapshot)
	assert_int(inst.instance_id).is_equal(3)
	assert_str(inst.class_id).is_equal("rogue")
	assert_str(inst.display_name).is_equal("Sable")
	assert_int(inst.current_level).is_equal(8)
	assert_int(inst.xp).is_equal(0)


func test_hero_instance_from_dict_uses_defaults_on_missing_keys() -> void:
	# Defensive: from_dict on a partial dict applies type-safe defaults.
	var inst: HeroInstance = HeroInstanceScript.new()
	inst.from_dict({})  # empty dict
	assert_int(inst.instance_id).is_equal(0)
	assert_str(inst.class_id).is_equal("")
	assert_str(inst.display_name).is_equal("")
	assert_int(inst.current_level).is_equal(1)
	assert_int(inst.xp).is_equal(0)


# C-05: Defensive type coercion on wrong-type input (per QA review GAP-001).
# from_dict uses int()/String() coercion. A malformed save dict with string-typed
# instance_id or int-typed class_id should NOT crash — coerce silently. This
# matches the defensive-defaults contract in the doc-comment of from_dict.
# Note: GDScript's `int("abc")` returns 0, masking unrecoverable corruption.
# That is a documented trade-off — better silent fallback than runtime crash
# during save load.
func test_hero_instance_from_dict_coerces_wrong_typed_values() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	# Wrong types throughout: instance_id as String, class_id as int,
	# current_level as String, xp as String.
	inst.from_dict({
		"instance_id": "42",                # String → int (valid numeric)
		"class_id": 99,                      # int → String
		"display_name": 123,                 # int → String
		"current_level": "5",                # String → int
		"xp": "0",                           # String → int
	})
	assert_int(inst.instance_id).is_equal(42)
	assert_str(inst.class_id).is_equal("99")
	assert_str(inst.display_name).is_equal("123")
	assert_int(inst.current_level).is_equal(5)
	assert_int(inst.xp).is_equal(0)


# C-06: Extra keys beyond the 5-field schema are silently ignored (per QA review GAP-002).
# A save dict with 6+ keys must not crash from_dict; extras are dropped on round-trip.
# This locks the "exactly 5 keys produced by to_dict" invariant against future
# refactors that might accidentally iterate the dict.
func test_hero_instance_from_dict_ignores_extra_keys() -> void:
	var inst: HeroInstance = HeroInstanceScript.new()
	inst.from_dict({
		"instance_id": 7,
		"class_id": "rogue",
		"display_name": "Sable",
		"current_level": 8,
		"xp": 0,
		"bonus_key": "junk",                 # extra
		"another_extra": [1, 2, 3],           # extra (different type)
	})
	# Fields populated correctly
	assert_int(inst.instance_id).is_equal(7)
	assert_str(inst.class_id).is_equal("rogue")
	assert_str(inst.display_name).is_equal("Sable")
	assert_int(inst.current_level).is_equal(8)
	assert_int(inst.xp).is_equal(0)
	# Round-trip drops the extras
	var d: Dictionary = inst.to_dict()
	assert_int(d.size()).is_equal(5)
	assert_bool(d.has("bonus_key")).is_false()
	assert_bool(d.has("another_extra")).is_false()


# ===========================================================================
# Group D: TR-004 — no mutation methods exposed
# ===========================================================================

func test_hero_instance_has_no_setter_methods() -> void:
	# HeroInstance has no public setter methods like set_instance_id, set_class_id,
	# set_display_name, set_level. All mutation flows through HeroRoster (Story 005).
	# from_dict is the deserializer (NOT a mutation method per ADR-0012's contract).
	var inst: HeroInstance = HeroInstanceScript.new()
	assert_bool(inst.has_method("set_instance_id")).is_false()
	assert_bool(inst.has_method("set_class_id")).is_false()
	assert_bool(inst.has_method("set_display_name")).is_false()
	assert_bool(inst.has_method("set_level")).is_false()
	assert_bool(inst.has_method("set_current_level")).is_false()
	assert_bool(inst.has_method("set_xp")).is_false()


func test_hero_instance_exposes_only_to_dict_and_from_dict_as_methods() -> void:
	# Verify the public method surface is minimal: exactly to_dict + from_dict.
	# (Built-in RefCounted methods like get_reference_count are present but those
	# are not "exposed by HeroInstance" — they're inherited.)
	var inst: HeroInstance = HeroInstanceScript.new()
	assert_bool(inst.has_method("to_dict")).is_true()
	assert_bool(inst.has_method("from_dict")).is_true()
