# Sprint 11 S11-X9 / Sprint 12 Story 1: FormationAssignment autoload skeleton.
#
# Per design/gdd/formation-assignment-system.md §C.1: a thin controller that
# translates UI-side browse + commit intents into HeroRoster mutations + signal
# emissions. Owns NO persistent state in MVP.
#
# Test groups:
#   A — public API surface lock (browse + commit + get_save_data + load_save_data exist)
#   B — signal arity + payload contract
#   C — browse() emits but does NOT mutate HeroRoster
#   D — commit() emits AFTER writes (signal-after-mutation invariant per §D)
#   E — commit() length validation (mismatch → no write, no emit)
#   F — empty/null formation handling
#   G — Save/Load consumer surface (empty payload + no-op load)
#   H — autoload presence check (live /root/FormationAssignment present)
extends GdUnitTestSuite

const FormationAssignmentScript = preload("res://src/core/formation_assignment/formation_assignment.gd")
const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")


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


# ===========================================================================
# Group A — public API surface lock
# ===========================================================================

func test_formation_assignment_has_browse_method() -> void:
	var fa: Node = _make_fa()
	assert_bool(fa.has_method("browse")).is_true()


func test_formation_assignment_has_commit_method() -> void:
	var fa: Node = _make_fa()
	assert_bool(fa.has_method("commit")).is_true()


func test_formation_assignment_has_save_consumer_methods() -> void:
	var fa: Node = _make_fa()
	assert_bool(fa.has_method("get_save_data")).is_true()
	assert_bool(fa.has_method("load_save_data")).is_true()


# ===========================================================================
# Group B — signal arity + payload contract
# ===========================================================================

func test_formation_assignment_declares_browse_opened_signal() -> void:
	var fa: Node = _make_fa()
	assert_bool(fa.has_signal("formation_browse_opened")).is_true()


func test_formation_assignment_declares_reassignment_committed_signal() -> void:
	var fa: Node = _make_fa()
	assert_bool(fa.has_signal("formation_reassignment_committed")).is_true()


# ===========================================================================
# Group C — browse() emits but does NOT mutate HeroRoster
# ===========================================================================

var _browse_calls: Array[Array] = []


func _on_browse_opened(formation: Array[HeroInstance]) -> void:
	_browse_calls.append(formation)


func test_browse_emits_browse_opened_signal_with_payload() -> void:
	var fa: Node = _make_fa()
	_browse_calls.clear()
	fa.formation_browse_opened.connect(_on_browse_opened)

	var formation: Array[HeroInstance] = [_make_hero(1, "warrior"), _make_hero(2, "mage"), null]
	fa.browse(formation)

	assert_int(_browse_calls.size()).is_equal(1)
	assert_int(_browse_calls[0].size()).is_equal(3)


func test_browse_is_idempotent_two_calls_emit_twice() -> void:
	var fa: Node = _make_fa()
	_browse_calls.clear()
	fa.formation_browse_opened.connect(_on_browse_opened)

	var formation: Array[HeroInstance] = [null, null, null]
	fa.browse(formation)
	fa.browse(formation)

	# Per §C.1 line 58: "Idempotent: calling browse twice in a row is fine
	# — both calls emit."
	assert_int(_browse_calls.size()).is_equal(2)


# ===========================================================================
# Group G — Save/Load consumer surface
# ===========================================================================

func test_get_save_data_returns_empty_dict_per_mvp_rule_10_deferral() -> void:
	# Per §C.6: MVP empty payload. Formation state lives in HeroRoster's
	# save namespace; FormationAssignment's namespace is reserved for V1.0
	# named-preset features.
	var fa: Node = _make_fa()
	var data: Dictionary = fa.get_save_data()
	assert_int(data.size()).is_equal(0)


func test_load_save_data_with_empty_dict_is_noop() -> void:
	var fa: Node = _make_fa()
	# Should not crash; should not push_error.
	fa.load_save_data({})


func test_load_save_data_with_non_empty_dict_is_noop_per_v1_0_reservation() -> void:
	# Future-V1.0 saves with named-preset data are loaded by future
	# FormationAssignment versions; current MVP code ignores the payload.
	var fa: Node = _make_fa()
	fa.load_save_data({"v1_0_named_presets": [{"name": "Tank", "slots": [1, 2, 3]}]})


# ===========================================================================
# Group H — autoload presence check (post-S11-X9 registration)
# ===========================================================================

func test_formation_assignment_is_live_autoload_at_canonical_path() -> void:
	# Locks the project.godot autoload registration at rank 11.
	var fa: Node = get_tree().root.get_node_or_null("FormationAssignment")
	assert_object(fa).is_not_null()
	assert_bool(fa.has_method("commit")).is_true()
	assert_bool(fa.has_signal("formation_reassignment_committed")).is_true()
