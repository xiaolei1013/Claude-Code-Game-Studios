# Formation Presets V1.0 — data-layer + persistence tests.
#
# Covers design/gdd/formation-presets.md acceptance criteria:
#   AC-FP-01  save/load round-trip through a JSON stringify/parse cycle
#   AC-FP-02  name validation (empty → reject; over-max → truncate)
#   AC-FP-03  preset cap rejection (no silent overwrite)
#   AC-FP-04  recall does NOT mutate the roster
#   AC-FP-05  recall resolves positional heroes; missing hero → null
#   AC-FP-06  delete removes + returns false on unknown id
#   AC-FP-08  monotonic id — never reused after delete
#   AC-FP-09  pre-V1.0 save (missing keys) → defaults
#   AC-FP-10  preset with slot count != formation_size() discarded on load
#
# Roster-dependent paths (recall, load-time size check) use the _roster_override
# DI seam with a StubRoster so tests stay isolated from the live /root/HeroRoster
# autoload + save state (project memory: test isolation via injectable seam).
#
# Signal capture follows the project idiom (commit_test.gd): class-level spy
# fields cleared in before_test() per memory feedback_gdunit4_spy_state_not_auto_cleared,
# named handler methods, fa.signal.connect(handler).
extends GdUnitTestSuite

const FormationAssignmentScript = preload("res://src/core/formation_assignment/formation_assignment.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


# --- Stub roster (DI seam target) -------------------------------------------

class StubRoster extends Node:
	var heroes_by_id: Dictionary = {}
	var formation_size_value: int = 3
	var set_slot_calls: int = 0

	func formation_size() -> int:
		return formation_size_value

	func get_hero_by_id(instance_id: int) -> Object:
		var found: Variant = heroes_by_id.get(instance_id, null)
		return found as Object

	# Present so AC-FP-04 can prove recall never writes through the roster.
	func set_formation_slot(_slot_index: int, _hero_id: int) -> bool:
		set_slot_calls += 1
		return true

	func register(hero: HeroInstance) -> void:
		heroes_by_id[hero.instance_id] = hero


# --- Signal spies (cleared per-test) ----------------------------------------

var _saved_calls: Array[Array] = []      # each = [preset_id, preset_name]
var _recalled_calls: Array[Array] = []   # each = [preset_id, formation]
var _deleted_calls: Array[int] = []      # each = preset_id


func before_test() -> void:
	_saved_calls.clear()
	_recalled_calls.clear()
	_deleted_calls.clear()


func _on_preset_saved(preset_id: int, preset_name: String) -> void:
	_saved_calls.append([preset_id, preset_name])


func _on_preset_recalled(preset_id: int, formation: Array) -> void:
	_recalled_calls.append([preset_id, formation])


func _on_preset_deleted(preset_id: int) -> void:
	_deleted_calls.append(preset_id)


# --- Helpers ----------------------------------------------------------------

func _make_fa() -> Node:
	var fa: Node = FormationAssignmentScript.new()
	add_child(fa)
	auto_free(fa)
	return fa


func _make_hero(instance_id: int, class_id: String) -> HeroInstance:
	var h: HeroInstance = HeroInstanceScript.new()
	h.instance_id = instance_id
	h.class_id = class_id
	return h


func _make_stub_roster(formation_size: int = 3) -> StubRoster:
	var stub := StubRoster.new()
	stub.formation_size_value = formation_size
	add_child(stub)
	auto_free(stub)
	return stub


# Build a typed Array[int] from a plain literal — typed collections reject
# untyped literal assignment at runtime (project memory).
func _slots(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in values:
		out.append(int(v))
	return out


# ===========================================================================
# AC-FP-02 — name validation
# ===========================================================================

func test_save_preset_empty_name_rejected() -> void:
	var fa: Node = _make_fa()
	var id: int = fa.save_preset("Tank", _slots([1, 2, 3]))
	assert_int(id).is_greater(0)  # sanity: a real name saves

	# A blank/whitespace-only name strips to empty → rejected, returns 0.
	var rejected: int = fa.save_preset("   ", _slots([4, 5, 6]))
	assert_int(rejected).is_equal(0)
	assert_int(fa.get_presets().size()).is_equal(1)  # only the first survived


func test_save_preset_over_max_length_truncates() -> void:
	var fa: Node = _make_fa()
	var max_len: int = fa.preset_name_max_length()
	var long_name: String = "x".repeat(max_len + 10)

	var id: int = fa.save_preset(long_name, _slots([1, 2, 3]))

	assert_int(id).is_greater(0)  # truncated, NOT rejected
	var presets: Array = fa.get_presets()
	assert_str(presets[0]["name"]).has_length(max_len)


# ===========================================================================
# AC-FP-03 — preset cap
# ===========================================================================

func test_save_preset_rejects_when_at_cap() -> void:
	var fa: Node = _make_fa()
	var cap: int = fa.max_presets()

	for i: int in range(cap):
		var id: int = fa.save_preset("P%d" % i, _slots([1, 2, 3]))
		assert_int(id).is_greater(0)
	assert_int(fa.get_presets().size()).is_equal(cap)

	# One past the cap → rejected (no silent overwrite, no rotation).
	var overflow: int = fa.save_preset("overflow", _slots([1, 2, 3]))
	assert_int(overflow).is_equal(0)
	assert_int(fa.get_presets().size()).is_equal(cap)


# ===========================================================================
# AC-FP-08 — monotonic id, never reused after delete
# ===========================================================================

func test_delete_then_save_does_not_reuse_id() -> void:
	var fa: Node = _make_fa()
	var id1: int = fa.save_preset("A", _slots([1, 2, 3]))
	var id2: int = fa.save_preset("B", _slots([4, 5, 6]))
	assert_int(id2).is_equal(id1 + 1)

	assert_bool(fa.delete_preset(id1)).is_true()

	var id3: int = fa.save_preset("C", _slots([7, 8, 9]))
	# id3 continues the sequence; it must NOT recycle the freed id1.
	assert_int(id3).is_equal(id2 + 1)
	assert_bool(id3 != id1).is_true()


# ===========================================================================
# AC-FP-06 — delete
# ===========================================================================

func test_delete_preset_removes_and_returns_true() -> void:
	var fa: Node = _make_fa()
	var id1: int = fa.save_preset("A", _slots([1, 2, 3]))
	assert_int(fa.get_presets().size()).is_equal(1)

	var ok: bool = fa.delete_preset(id1)

	assert_bool(ok).is_true()
	assert_int(fa.get_presets().size()).is_equal(0)


func test_delete_unknown_id_returns_false() -> void:
	var fa: Node = _make_fa()
	assert_bool(fa.delete_preset(999)).is_false()


# ===========================================================================
# AC-FP-04 / AC-FP-05 — recall (via the DI roster seam)
# ===========================================================================

func test_recall_preset_resolves_positional_heroes() -> void:
	var stub := _make_stub_roster(3)
	stub.register(_make_hero(12, "warrior"))
	stub.register(_make_hero(7, "mage"))
	var fa: Node = _make_fa()
	fa._roster_override = stub

	var id: int = fa.save_preset("Mix", _slots([12, 0, 7]))
	var formation: Array = fa.recall_preset(id)

	assert_int(formation.size()).is_equal(3)
	assert_int(formation[0].instance_id).is_equal(12)
	assert_object(formation[1]).is_null()          # 0 sentinel → empty slot
	assert_int(formation[2].instance_id).is_equal(7)


func test_recall_preset_missing_hero_resolves_null() -> void:
	var stub := _make_stub_roster(3)
	stub.register(_make_hero(12, "warrior"))  # hero 7 NOT registered (dismissed)
	var fa: Node = _make_fa()
	fa._roster_override = stub

	var id: int = fa.save_preset("Mix", _slots([12, 0, 7]))
	var formation: Array = fa.recall_preset(id)

	assert_int(formation.size()).is_equal(3)
	assert_int(formation[0].instance_id).is_equal(12)
	assert_object(formation[1]).is_null()
	assert_object(formation[2]).is_null()          # 7 no longer exists


func test_recall_preset_does_not_mutate_roster() -> void:
	var stub := _make_stub_roster(3)
	stub.register(_make_hero(12, "warrior"))
	var fa: Node = _make_fa()
	fa._roster_override = stub

	var id: int = fa.save_preset("X", _slots([12, 0, 0]))
	fa.recall_preset(id)

	# AC-FP-04: recall is read-only w.r.t. the roster — no slot writes.
	assert_int(stub.set_slot_calls).is_equal(0)


func test_recall_unknown_id_returns_empty() -> void:
	var fa: Node = _make_fa()
	assert_array(fa.recall_preset(999)).is_empty()


# ===========================================================================
# AC-FP-09 — pre-V1.0 save (missing keys) hydrates defaults
# ===========================================================================

func test_load_save_data_missing_keys_initializes_defaults() -> void:
	var fa: Node = _make_fa()
	# Seed some state, then load a pre-V1.0 payload → must reset to defaults.
	fa.save_preset("A", _slots([1, 2, 3]))
	fa.load_save_data({})

	assert_int(fa.get_presets().size()).is_equal(0)
	assert_int(fa.get_save_data()["next_preset_id"]).is_equal(1)


# ===========================================================================
# AC-FP-10 — slot-count drift discarded on load
# ===========================================================================

func test_load_save_data_discards_preset_with_wrong_slot_count() -> void:
	var stub := _make_stub_roster(3)
	var fa: Node = _make_fa()
	fa._roster_override = stub  # formation_size() == 3, isolated from live roster

	# One valid (len 3) preset + one malformed (len 2) preset.
	var payload: Dictionary = {
		"presets": [
			{"id": 1, "name": "Good", "created_at_unix": 0, "slot_hero_ids": [1, 2, 3]},
			{"id": 2, "name": "Bad", "created_at_unix": 0, "slot_hero_ids": [1, 2]},
		],
		"next_preset_id": 3,
	}
	fa.load_save_data(payload)

	var presets: Array = fa.get_presets()
	assert_int(presets.size()).is_equal(1)
	assert_str(presets[0]["name"]).is_equal("Good")
	# Monotonic counter from the payload is preserved (AC-FP-08).
	assert_int(fa.get_save_data()["next_preset_id"]).is_equal(3)


# ===========================================================================
# AC-FP-01 — save/load round-trip through a JSON stringify/parse cycle
#
# This is the load-bearing persistence test: JSON.parse_string returns every
# number as TYPE_FLOAT, so it exercises the int()-cast path in load_save_data.
# ===========================================================================

func test_save_load_round_trip_through_json_preserves_presets() -> void:
	var fa: Node = _make_fa()
	var id_a: int = fa.save_preset("Fire Team", _slots([12, 0, 7]), 1000)
	var id_b: int = fa.save_preset("Tank Wall", _slots([3, 4, 5]), 2000)
	var payload: Dictionary = fa.get_save_data()

	# Simulate the real save-file round-trip: ints become floats through JSON.
	var json_str: String = JSON.stringify(payload)
	var parsed: Variant = JSON.parse_string(json_str)
	assert_bool(parsed is Dictionary).is_true()

	# Hydrate a FRESH instance from the round-tripped payload.
	var stub := _make_stub_roster(3)
	var fa2: Node = _make_fa()
	fa2._roster_override = stub
	fa2.load_save_data(parsed as Dictionary)

	var presets: Array = fa2.get_presets()
	assert_int(presets.size()).is_equal(2)

	# Preset A — full field fidelity.
	assert_int(presets[0]["id"]).is_equal(id_a)
	assert_str(presets[0]["name"]).is_equal("Fire Team")
	assert_int(presets[0]["created_at_unix"]).is_equal(1000)
	var slots_a: Array = presets[0]["slot_hero_ids"] as Array
	assert_int(slots_a.size()).is_equal(3)
	assert_int(slots_a[0]).is_equal(12)
	assert_int(slots_a[1]).is_equal(0)
	assert_int(slots_a[2]).is_equal(7)
	# The JSON float→int cast must hold: slot ids are TYPE_INT after load.
	assert_int(typeof(slots_a[0])).is_equal(TYPE_INT)

	# Preset B + monotonic counter survive the round-trip.
	assert_int(presets[1]["id"]).is_equal(id_b)
	assert_int(fa2.get_save_data()["next_preset_id"]).is_equal(id_b + 1)


# ===========================================================================
# Encapsulation behaviour — get_presets returns a deep copy; save snapshots
# (supports AC-FP-12; the static grep guard lives in the CI grep test).
# ===========================================================================

func test_get_presets_returns_deep_copy() -> void:
	var fa: Node = _make_fa()
	fa.save_preset("A", _slots([1, 2, 3]))

	var presets: Array = fa.get_presets()
	presets[0]["name"] = "HACKED"
	presets[0]["slot_hero_ids"][0] = 999

	# Internal state must be untouched by mutation of the returned copy.
	var fresh: Array = fa.get_presets()
	assert_str(fresh[0]["name"]).is_equal("A")
	assert_int(fresh[0]["slot_hero_ids"][0]).is_equal(1)


func test_save_preset_snapshots_slot_array_defensively() -> void:
	var fa: Node = _make_fa()
	var slots: Array[int] = _slots([1, 2, 3])
	fa.save_preset("A", slots)

	slots[0] = 999  # mutate the caller's array AFTER saving

	var presets: Array = fa.get_presets()
	assert_int(presets[0]["slot_hero_ids"][0]).is_equal(1)  # snapshot unaffected


# ===========================================================================
# Signal contract — save / recall / delete each emit once with the right id
# ===========================================================================

func test_save_preset_emits_preset_saved() -> void:
	var fa: Node = _make_fa()
	fa.preset_saved.connect(_on_preset_saved)

	var id: int = fa.save_preset("Hello", _slots([1, 2, 3]))

	assert_int(_saved_calls.size()).is_equal(1)
	assert_int(_saved_calls[0][0]).is_equal(id)
	assert_str(_saved_calls[0][1]).is_equal("Hello")


func test_rejected_save_does_not_emit_preset_saved() -> void:
	var fa: Node = _make_fa()
	fa.preset_saved.connect(_on_preset_saved)

	fa.save_preset("", _slots([1, 2, 3]))  # empty name → rejected

	assert_int(_saved_calls.size()).is_equal(0)


func test_recall_preset_emits_preset_recalled() -> void:
	var stub := _make_stub_roster(3)
	stub.register(_make_hero(12, "warrior"))
	var fa: Node = _make_fa()
	fa._roster_override = stub
	fa.preset_recalled.connect(_on_preset_recalled)

	var id: int = fa.save_preset("X", _slots([12, 0, 0]))
	fa.recall_preset(id)

	assert_int(_recalled_calls.size()).is_equal(1)
	assert_int(_recalled_calls[0][0]).is_equal(id)


func test_delete_preset_emits_preset_deleted() -> void:
	var fa: Node = _make_fa()
	fa.preset_deleted.connect(_on_preset_deleted)
	var id: int = fa.save_preset("A", _slots([1, 2, 3]))

	fa.delete_preset(id)

	assert_int(_deleted_calls.size()).is_equal(1)
	assert_int(_deleted_calls[0]).is_equal(id)
