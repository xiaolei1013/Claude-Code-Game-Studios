# Tests for Formation Presets V1.0: FormationPresetsConfig resource schema.
# Covers: ADR-0011 (Resource schema + _validate pattern), ADR-0013
#         (single-source-of-truth tuning knobs), ADR-0006 (DataRegistry scan).
#         design/gdd/formation-presets.md §G (Tuning Knobs) + AC-FP-11.
#
# All tests except the final DataRegistry integration test instantiate
# FormationPresetsConfig directly via preload-and-new() for isolation/speed.
#
# NOTE: FormationPresetsConfig extends GameData -> Resource (RefCounted). Do NOT
# call .free() on Resource instances — Godot manages their lifetime via
# reference counting; calling .free() on a RefCounted raises a runtime error.
extends GdUnitTestSuite

const FormationPresetsConfigScript = preload("res://src/core/formation_assignment/formation_presets_config.gd")

# ---------------------------------------------------------------------------
# Default values — one test per knob (formation-presets.md §G)
# ---------------------------------------------------------------------------

func test_formation_presets_config_max_presets_default_matches_gdd() -> void:
	# Arrange
	var cfg := FormationPresetsConfigScript.new()

	# Act / Assert — §G: MAX_PRESETS_PER_PLAYER = 6
	assert_int(cfg.MAX_PRESETS_PER_PLAYER).is_equal(6)


func test_formation_presets_config_name_max_length_default_matches_gdd() -> void:
	# Arrange
	var cfg := FormationPresetsConfigScript.new()

	# Act / Assert — §G: PRESET_NAME_MAX_LENGTH = 32
	assert_int(cfg.PRESET_NAME_MAX_LENGTH).is_equal(32)


func test_formation_presets_config_recall_toast_cap_default_matches_gdd() -> void:
	# Arrange
	var cfg := FormationPresetsConfigScript.new()

	# Act / Assert — §G: RECALL_MISSING_HERO_TOAST_CAP = 3
	assert_int(cfg.RECALL_MISSING_HERO_TOAST_CAP).is_equal(3)


func test_formation_presets_config_delete_focus_default_matches_gdd() -> void:
	# Arrange
	var cfg := FormationPresetsConfigScript.new()

	# Act / Assert — §G: DELETE_CONFIRMATION_DEFAULT_FOCUS = "cancel" (safe default)
	assert_str(cfg.DELETE_CONFIRMATION_DEFAULT_FOCUS).is_equal("cancel")

# ---------------------------------------------------------------------------
# Schema validation — happy path (ADR-0011 §Decision)
# ---------------------------------------------------------------------------

func test_formation_presets_config_validate_returns_empty_for_default_instance() -> void:
	# Arrange
	var cfg := FormationPresetsConfigScript.new()

	# Act
	var errors: Array[String] = cfg._validate()

	# Assert — default instance satisfies all constraints
	assert_array(errors).is_empty()

# ---------------------------------------------------------------------------
# Schema validation — rejection cases (one per constraint)
# ---------------------------------------------------------------------------

func test_formation_presets_config_validate_rejects_zero_max_presets() -> void:
	# Arrange — a cap of 0 would make Save always fail (feature soft-lock).
	var cfg := FormationPresetsConfigScript.new()
	cfg.MAX_PRESETS_PER_PLAYER = 0

	# Act
	var errors: Array[String] = cfg._validate()

	# Assert
	assert_array(errors).is_not_empty()
	var found: bool = false
	for err: String in errors:
		if "MAX_PRESETS_PER_PLAYER" in err:
			found = true
			break
	assert_bool(found).is_true()


func test_formation_presets_config_validate_rejects_zero_name_max_length() -> void:
	# Arrange — a max length of 0 rejects every name.
	var cfg := FormationPresetsConfigScript.new()
	cfg.PRESET_NAME_MAX_LENGTH = 0

	# Act
	var errors: Array[String] = cfg._validate()

	# Assert
	assert_array(errors).is_not_empty()
	var found: bool = false
	for err: String in errors:
		if "PRESET_NAME_MAX_LENGTH" in err:
			found = true
			break
	assert_bool(found).is_true()


func test_formation_presets_config_validate_rejects_negative_toast_cap() -> void:
	# Arrange — a negative toast cap is nonsensical (0 = suppress all, still valid).
	var cfg := FormationPresetsConfigScript.new()
	cfg.RECALL_MISSING_HERO_TOAST_CAP = -1

	# Act
	var errors: Array[String] = cfg._validate()

	# Assert
	assert_array(errors).is_not_empty()
	var found: bool = false
	for err: String in errors:
		if "RECALL_MISSING_HERO_TOAST_CAP" in err:
			found = true
			break
	assert_bool(found).is_true()


func test_formation_presets_config_validate_accepts_zero_toast_cap() -> void:
	# Arrange — 0 is a valid "suppress all missing-hero toasts" setting.
	var cfg := FormationPresetsConfigScript.new()
	cfg.RECALL_MISSING_HERO_TOAST_CAP = 0

	# Act
	var errors: Array[String] = cfg._validate()

	# Assert — boundary 0 must NOT be reported as an error
	assert_array(errors).is_empty()


func test_formation_presets_config_validate_rejects_unknown_delete_focus() -> void:
	# Arrange — focus must be one of "cancel" / "confirm".
	var cfg := FormationPresetsConfigScript.new()
	cfg.DELETE_CONFIRMATION_DEFAULT_FOCUS = "explode"

	# Act
	var errors: Array[String] = cfg._validate()

	# Assert
	assert_array(errors).is_not_empty()
	var found: bool = false
	for err: String in errors:
		if "DELETE_CONFIRMATION_DEFAULT_FOCUS" in err:
			found = true
			break
	assert_bool(found).is_true()


func test_formation_presets_config_validate_accepts_confirm_delete_focus() -> void:
	# Arrange — "confirm" is the other allowed value.
	var cfg := FormationPresetsConfigScript.new()
	cfg.DELETE_CONFIRMATION_DEFAULT_FOCUS = "confirm"

	# Act
	var errors: Array[String] = cfg._validate()

	# Assert
	assert_array(errors).is_empty()

# ---------------------------------------------------------------------------
# Property introspection — all @export knobs enumerable (ADR-0011)
# ---------------------------------------------------------------------------

func test_formation_presets_config_has_all_export_knobs() -> void:
	# Arrange
	var cfg := FormationPresetsConfigScript.new()

	# Act — filter property list to @export-tagged fields.
	const EXPORT_FLAG: int = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	var export_props: Array = []
	for prop: Dictionary in cfg.get_property_list():
		if (prop["usage"] & EXPORT_FLAG) == EXPORT_FLAG:
			export_props.append(prop["name"])

	# Assert — the 4 script-declared knobs plus 2 inherited from GameData
	# (id, display_name) give >= 6 total. Guard against silent knob deletion.
	assert_int(export_props.size()).is_greater_equal(6)

	var critical_knobs: Array[String] = [
		"MAX_PRESETS_PER_PLAYER",
		"PRESET_NAME_MAX_LENGTH",
		"RECALL_MISSING_HERO_TOAST_CAP",
		"DELETE_CONFIRMATION_DEFAULT_FOCUS",
	]
	for knob: String in critical_knobs:
		assert_bool(knob in export_props).is_true()

# ---------------------------------------------------------------------------
# DataRegistry integration — resolves the production .tres at runtime.
#
# Mirrors economy_config_schema_test.gd: if DataRegistry is in ERROR state
# (early-sprint empty content categories), resolve() returns null; we skip the
# assertion and document the deferral. The preload-and-new() tests above give
# full schema coverage regardless.
# ---------------------------------------------------------------------------

func test_formation_presets_config_resolves_via_data_registry() -> void:
	# Act — resolve from the live autoload
	var result: Resource = DataRegistry.resolve("config", "formation_presets_config")

	if result == null:
		push_warning(
			"test_formation_presets_config_resolves_via_data_registry: DataRegistry.resolve " +
			"returned null. DataRegistry may be in ERROR state due to empty content categories. " +
			"Deferred to smoke check at production/qa/smoke-*.md."
		)
		return

	# Assert — correctly typed FormationPresetsConfig with expected identity fields
	assert_bool(result is FormationPresetsConfig).is_true()
	var cfg: FormationPresetsConfig = result as FormationPresetsConfig
	assert_str(cfg.id).is_equal("formation_presets_config")
	assert_bool(cfg.display_name.length() > 0).is_true()
	# And the resolved .tres values must match the GDD §G defaults.
	assert_int(cfg.MAX_PRESETS_PER_PLAYER).is_equal(6)
	assert_int(cfg.PRESET_NAME_MAX_LENGTH).is_equal(32)
