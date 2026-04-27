# Tests for Story 002: GameData abstract base and archetype/role constant sets.
# Covers: TR-data-loading-004, TR-data-loading-005, ADR-0011.
#
# Test inventory:
#   1. GameData class is registered with id and display_name fields (TR-data-loading-004)
#   2. EnemyArchetypes MVP_SET, ALL_SET contents and is_valid/is_mvp methods (ADR-0011)
#   3. ClassRoles ALL_SET contents and is_valid method (ADR-0011)
#   4. GameData inheritance contract — subclass inherits id/display_name without
#      redeclaration (TR-data-loading-005, authoring convention)
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Internal test-only subclass used by Test 4.
# Declared at file scope so GdUnit4 can resolve it during collection.
# This is the only place a GameData subclass is permissible in this file.
# ---------------------------------------------------------------------------
class TestGameDataSubclass extends GameData:
	@export var custom_field: String = ""


# ---------------------------------------------------------------------------
# Test 1 — TR-data-loading-004:
#   GameData class is registered via class_name, carries @abstract annotation,
#   and declares the two inherited fields id and display_name typed as String.
#
# @abstract semantics prevent direct instantiation; we verify the class
# identifier resolves and its property list includes both exported fields.
# Full end-to-end subclass loading is deferred to AC-DLS-01 / Story 003.
# ---------------------------------------------------------------------------
func test_game_data_class_is_registered_with_id_and_display_name_fields() -> void:
	# Arrange — GameData is registered globally via class_name; no instantiation needed
	# to inspect the script's property list. We use a concrete subclass proxy to access
	# inherited properties without triggering the @abstract instantiation guard.
	var instance: TestGameDataSubclass = TestGameDataSubclass.new()

	# Act — retrieve property list from the concrete instance (inherits GameData fields)
	var props: Array[Dictionary] = instance.get_property_list()
	var prop_names: Array[String] = []
	for p: Dictionary in props:
		prop_names.append(p["name"])

	# Assert — both inherited fields must be present in the property list
	assert_bool(prop_names.has("id")).is_true()
	assert_bool(prop_names.has("display_name")).is_true()

	# Assert — field types are String (Variant.Type.TYPE_STRING == 4)
	var id_prop: Dictionary = {}
	var display_name_prop: Dictionary = {}
	for p: Dictionary in props:
		if p["name"] == "id":
			id_prop = p
		elif p["name"] == "display_name":
			display_name_prop = p

	assert_int(id_prop.get("type", -1)).is_equal(TYPE_STRING)
	assert_int(display_name_prop.get("type", -1)).is_equal(TYPE_STRING)

	# Assert — default values are empty strings (as authored in GameData)
	assert_str(instance.id).is_equal("")
	assert_str(instance.display_name).is_equal("")

	# No cleanup needed — GameData extends Resource (RefCounted); freed by refcounting.


# ---------------------------------------------------------------------------
# Test 2 — ADR-0011 (EnemyArchetypes):
#   MVP_SET and ALL_SET contain exactly the specified archetypes in the
#   specified order. is_valid and is_mvp are case-sensitive.
# ---------------------------------------------------------------------------
func test_enemy_archetypes_sets_and_validators_match_adr_0011_spec() -> void:
	# Arrange — static access; no instantiation needed

	# Act / Assert — MVP_SET exact contents and order
	assert_int(EnemyArchetypes.MVP_SET.size()).is_equal(3)
	assert_str(EnemyArchetypes.MVP_SET[0]).is_equal("bruiser")
	assert_str(EnemyArchetypes.MVP_SET[1]).is_equal("caster")
	assert_str(EnemyArchetypes.MVP_SET[2]).is_equal("armored")

	# Act / Assert — ALL_SET exact contents and order
	assert_int(EnemyArchetypes.ALL_SET.size()).is_equal(6)
	assert_str(EnemyArchetypes.ALL_SET[0]).is_equal("bruiser")
	assert_str(EnemyArchetypes.ALL_SET[1]).is_equal("caster")
	assert_str(EnemyArchetypes.ALL_SET[2]).is_equal("armored")
	assert_str(EnemyArchetypes.ALL_SET[3]).is_equal("beast")
	assert_str(EnemyArchetypes.ALL_SET[4]).is_equal("construct")
	assert_str(EnemyArchetypes.ALL_SET[5]).is_equal("incorporeal")

	# Act / Assert — is_valid: known archetypes return true
	assert_bool(EnemyArchetypes.is_valid("bruiser")).is_true()
	assert_bool(EnemyArchetypes.is_valid("beast")).is_true()
	assert_bool(EnemyArchetypes.is_valid("incorporeal")).is_true()

	# Act / Assert — is_valid: unknown or wrong-case strings return false
	assert_bool(EnemyArchetypes.is_valid("TANK")).is_false()
	assert_bool(EnemyArchetypes.is_valid("flying")).is_false()
	assert_bool(EnemyArchetypes.is_valid("")).is_false()
	assert_bool(EnemyArchetypes.is_valid("Bruiser")).is_false()

	# Act / Assert — is_mvp: MVP archetypes return true
	assert_bool(EnemyArchetypes.is_mvp("bruiser")).is_true()
	assert_bool(EnemyArchetypes.is_mvp("caster")).is_true()
	assert_bool(EnemyArchetypes.is_mvp("armored")).is_true()

	# Act / Assert — is_mvp: V1.0 archetypes and wrong-case strings return false
	assert_bool(EnemyArchetypes.is_mvp("beast")).is_false()
	assert_bool(EnemyArchetypes.is_mvp("construct")).is_false()
	assert_bool(EnemyArchetypes.is_mvp("incorporeal")).is_false()
	assert_bool(EnemyArchetypes.is_mvp("Bruiser")).is_false()
	assert_bool(EnemyArchetypes.is_mvp("")).is_false()


# ---------------------------------------------------------------------------
# Test 3 — ADR-0011 (ClassRoles):
#   ALL_SET contains exactly the 6 specified roles in order.
#   is_valid is case-sensitive.
# ---------------------------------------------------------------------------
func test_class_roles_all_set_and_validator_match_adr_0011_spec() -> void:
	# Arrange — static access; no instantiation needed

	# Act / Assert — ALL_SET exact contents and order
	assert_int(ClassRoles.ALL_SET.size()).is_equal(6)
	assert_str(ClassRoles.ALL_SET[0]).is_equal("tank")
	assert_str(ClassRoles.ALL_SET[1]).is_equal("striker")
	assert_str(ClassRoles.ALL_SET[2]).is_equal("precision")
	assert_str(ClassRoles.ALL_SET[3]).is_equal("support")
	assert_str(ClassRoles.ALL_SET[4]).is_equal("ranged")
	assert_str(ClassRoles.ALL_SET[5]).is_equal("commander")

	# Act / Assert — is_valid: known roles return true
	assert_bool(ClassRoles.is_valid("tank")).is_true()
	assert_bool(ClassRoles.is_valid("striker")).is_true()
	assert_bool(ClassRoles.is_valid("precision")).is_true()
	assert_bool(ClassRoles.is_valid("support")).is_true()
	assert_bool(ClassRoles.is_valid("ranged")).is_true()
	assert_bool(ClassRoles.is_valid("commander")).is_true()

	# Act / Assert — is_valid: unknown, wrong-case, or empty strings return false
	assert_bool(ClassRoles.is_valid("healer")).is_false()
	assert_bool(ClassRoles.is_valid("")).is_false()
	assert_bool(ClassRoles.is_valid("Tank")).is_false()
	assert_bool(ClassRoles.is_valid("STRIKER")).is_false()
	assert_bool(ClassRoles.is_valid("berserker")).is_false()


# ---------------------------------------------------------------------------
# Test 4 — TR-data-loading-005 (authoring convention):
#   A concrete subclass of GameData inherits id and display_name without
#   redeclaration. Subclass may add its own @export fields alongside the
#   inherited ones. snake_case-id regex enforcement is Story 005's job.
# ---------------------------------------------------------------------------
func test_game_data_subclass_inherits_id_and_display_name_without_redeclaration() -> void:
	# Arrange
	var instance: TestGameDataSubclass = TestGameDataSubclass.new()

	# Act — both inherited fields default to empty string
	assert_str(instance.id).is_equal("")
	assert_str(instance.display_name).is_equal("")

	# Act — inherited fields are writable and readable (no shadowing)
	instance.id = "test_subclass_id"
	instance.display_name = "Test Subclass"

	# Assert — writes are reflected correctly
	assert_str(instance.id).is_equal("test_subclass_id")
	assert_str(instance.display_name).is_equal("Test Subclass")

	# Assert — subclass-specific field is independent and unaffected
	assert_str(instance.custom_field).is_equal("")
	instance.custom_field = "custom_value"
	assert_str(instance.custom_field).is_equal("custom_value")

	# Assert — inherited fields were not reset by writing to custom_field
	assert_str(instance.id).is_equal("test_subclass_id")

	# No cleanup needed — GameData subclasses extend Resource (RefCounted).
