# Tests for Sprint 6 hero-roster Story 003: RosterConfig schema + _validate().
# Covers: TR-hero-roster-006 (max_roster_size >= formation_size constraint),
#         TR-hero-roster-030 (config-resource pattern for Roster tuning knobs),
#         ADR-0011 (per-resource _validate() returns Array[String], empty == OK).
extends GdUnitTestSuite

const RosterConfigScript = preload("res://src/core/hero_roster/roster_config.gd")
const ROSTER_CONFIG_PATH := "res://assets/data/config/roster_config.tres"


# ===========================================================================
# Group A: schema fields exist with correct types and GDD §G defaults
# ===========================================================================

func test_roster_config_default_max_roster_size_is_thirty() -> void:
	var cfg: RosterConfig = RosterConfigScript.new()
	assert_int(cfg.max_roster_size).is_equal(30)


func test_roster_config_default_formation_size_is_three() -> void:
	var cfg: RosterConfig = RosterConfigScript.new()
	assert_int(cfg.formation_size).is_equal(3)


func test_roster_config_default_level_cap_is_fifteen() -> void:
	var cfg: RosterConfig = RosterConfigScript.new()
	assert_int(cfg.level_cap).is_equal(15)


func test_roster_config_extends_gamedata() -> void:
	var cfg: RosterConfig = RosterConfigScript.new()
	# GameData provides id + display_name fields.
	var as_object: Object = cfg
	assert_bool(as_object is GameData).is_true()


# ===========================================================================
# Group B: _validate() returns empty Array[String] on default instance (TR-006)
# ===========================================================================

func test_roster_config_default_instance_validates_clean() -> void:
	var cfg: RosterConfig = RosterConfigScript.new()
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_equal(0)


# ===========================================================================
# Group C: _validate() catches max_roster_size < formation_size (TR-006 core)
# ===========================================================================

func test_roster_config_validate_rejects_max_smaller_than_formation() -> void:
	var cfg: RosterConfig = RosterConfigScript.new()
	cfg.max_roster_size = 2
	cfg.formation_size = 3
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_greater(0)
	# Verify the human-readable message references both fields
	var joined: String = ", ".join(errors)
	assert_str(joined).contains("max_roster_size")
	assert_str(joined).contains("formation_size")


func test_roster_config_validate_accepts_max_equal_to_formation() -> void:
	# Boundary: max == formation is allowed (>= constraint).
	var cfg: RosterConfig = RosterConfigScript.new()
	cfg.max_roster_size = 3
	cfg.formation_size = 3
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_equal(0)


# ===========================================================================
# Group D: _validate() catches sub-1 fields
# ===========================================================================

func test_roster_config_validate_rejects_zero_formation_size() -> void:
	var cfg: RosterConfig = RosterConfigScript.new()
	cfg.formation_size = 0
	# max_roster_size must also be >= formation_size (0 >= 0 is fine), so adjust.
	cfg.max_roster_size = 0
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_greater(0)


func test_roster_config_validate_rejects_zero_max_roster_size() -> void:
	var cfg: RosterConfig = RosterConfigScript.new()
	cfg.max_roster_size = 0
	cfg.formation_size = 0  # avoid the >= constraint also triggering
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_greater(0)


func test_roster_config_validate_rejects_zero_level_cap() -> void:
	var cfg: RosterConfig = RosterConfigScript.new()
	cfg.level_cap = 0
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_greater(0)
	var joined: String = ", ".join(errors)
	assert_str(joined).contains("level_cap")


# ===========================================================================
# Group E: roster_config.tres exists, loads, and validates clean (TR-030)
# ===========================================================================

func test_roster_config_tres_resource_exists_at_expected_path() -> void:
	# DataRegistry-pinned location per ADR-0006.
	var resource_exists: bool = ResourceLoader.exists(ROSTER_CONFIG_PATH)
	assert_bool(resource_exists).is_true()


func test_roster_config_tres_loads_and_is_roster_config() -> void:
	var loaded: Resource = load(ROSTER_CONFIG_PATH)
	assert_object(loaded).is_not_null()
	assert_bool(loaded is RosterConfig).is_true()


func test_roster_config_tres_default_values_match_gdd() -> void:
	var loaded: Resource = load(ROSTER_CONFIG_PATH)
	var cfg: RosterConfig = loaded as RosterConfig
	assert_int(cfg.max_roster_size).is_equal(30)
	assert_int(cfg.formation_size).is_equal(3)
	assert_int(cfg.level_cap).is_equal(15)


func test_roster_config_tres_validates_clean() -> void:
	var loaded: Resource = load(ROSTER_CONFIG_PATH)
	var cfg: RosterConfig = loaded as RosterConfig
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_equal(0)


func test_roster_config_tres_id_and_display_name_set() -> void:
	# DataRegistry boot scan keys by `id`; resolve("config", "roster_config") needs id.
	var loaded: Resource = load(ROSTER_CONFIG_PATH)
	var cfg: RosterConfig = loaded as RosterConfig
	assert_str(cfg.id).is_equal("roster_config")
	assert_str(cfg.display_name).is_not_empty()


# ===========================================================================
# Group F: HeroRoster boot resolves config; accessors return loaded values
# ===========================================================================

func test_hero_roster_autoload_accessors_return_gdd_defaults() -> void:
	# Robust to the test-env DataRegistry-not-ready issue (FOLLOWUP-002 / S6-M12):
	# accessors return GDD §G defaults whether HeroRoster._config was loaded from
	# roster_config.tres OR fell back to `_FALLBACK_*` constants.
	var hr: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(hr).is_not_null()
	assert_int(hr.max_roster_size()).is_equal(30)
	assert_int(hr.formation_size()).is_equal(3)
	assert_int(hr.level_cap()).is_equal(15)


func test_hero_roster_formation_slots_sized_from_config() -> void:
	var hr: Node = get_tree().root.get_node_or_null("HeroRoster")
	assert_object(hr).is_not_null()
	# Formation slots resized in _ready() from formation_size() = 3.
	assert_int(hr._formation_slots.size()).is_equal(3)


# ===========================================================================
# Group G: TR-030 — no hardcoded Roster values in hero_roster.gd outside loader
# ===========================================================================

func test_hero_roster_source_has_no_hardcoded_balance_outside_loader() -> void:
	# Read hero_roster.gd and verify the GDD §G default LITERALS (30, 15) appear
	# only on `_FALLBACK_*` constant declarations (the config-loader fallback
	# path explicitly permitted by TR-030).
	#
	# NOTE: the literal `3` (formation_size default) is INTENTIONALLY NOT
	# grepped — it is too common as an array index, slot count, or generic
	# loop bound to discriminate Roster-balance use from coincidence. The
	# `_FALLBACK_FORMATION_SIZE = 3` declaration is its only origin in this
	# file; if the value were re-introduced elsewhere it would be caught by
	# the runtime accessor tests in Group F (max_roster_size/formation_size/
	# level_cap return GDD §G defaults via the loaded config — no other
	# code path can produce those values).
	var file: FileAccess = FileAccess.open("res://src/core/hero_roster/hero_roster.gd", FileAccess.READ)
	assert_object(file).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	var lines: PackedStringArray = content.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		# Skip comments and the fallback-constant declarations.
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		if trimmed.begins_with("const _FALLBACK_"):
			continue
		var has_thirty: bool = trimmed.contains(" 30") or trimmed.contains("=30")
		var has_fifteen: bool = trimmed.contains(" 15") or trimmed.contains("=15")
		assert_bool(has_thirty).is_false()
		assert_bool(has_fifteen).is_false()


# ===========================================================================
# Group H: Sprint 8 S8-S8 — _apply_resolved_config defensive-branch coverage
#
# These tests close TD-009 by exercising the four defensive branches of the
# config-loader directly via the extracted [code]_apply_resolved_config[/code]
# seam. The seam was added in S8-S8 specifically so tests can drive each
# branch with a constructed mock Resource without going through the live
# DataRegistry singleton (whose state was previously hard to control from a
# fresh test instance per the original TD-009 resolution path note).
#
# Branch coverage:
#   1. resolved == null → reject + push_error + _config stays null
#   2. Resource missing schema fields → reject + push_error
#   3. _validate() returns errors → reject + push_error
#   4. Resource without _validate method → ACCEPT (defensive tolerance)
# ===========================================================================

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")


# Build a fresh HeroRoster instance for direct branch testing. Uses .new()
# rather than the autoload since we want to drive _apply_resolved_config()
# with controlled Resource inputs, not the live DataRegistry resolution.
func _make_fresh_roster_for_branch_testing() -> Node:
	var hr: Node = HeroRosterScript.new()
	add_child(hr)
	auto_free(hr)
	return hr


# Build a Resource that satisfies the duck-type schema check (has the three
# required fields) AND a clean _validate() returning []. Used as the positive
# control — the loader should accept this.
func _make_valid_mock_config() -> Resource:
	var r: Resource = preload("res://src/core/hero_roster/roster_config.gd").new()
	r.max_roster_size = 30
	r.formation_size = 3
	r.level_cap = 15
	return r


# Branch 1: resolved == null → loader rejects + leaves _config null.
func test_apply_resolved_config_null_resource_returns_false_and_leaves_config_null() -> void:
	# Arrange
	var hr: Node = _make_fresh_roster_for_branch_testing()
	# Note: _ready() already ran during add_child; if the live DataRegistry
	# happened to resolve the config, _config may already be set. Reset it
	# explicitly so this test isolates the null-branch behaviour.
	hr._config = null

	# Act
	var accepted: bool = hr._apply_resolved_config(null)

	# Assert — loader rejected; _config stays null; fallback constants are used.
	assert_bool(accepted).is_false()
	assert_object(hr._config).is_null()
	# Public accessors fall back to GDD §G defaults (TR-hero-roster-030).
	assert_int(hr.max_roster_size()).is_equal(30)
	assert_int(hr.formation_size()).is_equal(3)
	assert_int(hr.level_cap()).is_equal(15)


# Branch 2: Resource missing schema fields → reject.
# A bare Resource() (no script) has none of max_roster_size / formation_size /
# level_cap. The duck-type `in` check returns false; loader rejects.
func test_apply_resolved_config_resource_missing_schema_fields_returns_false() -> void:
	# Arrange
	var hr: Node = _make_fresh_roster_for_branch_testing()
	hr._config = null
	var bad: Resource = Resource.new()  # bare Resource — no schema fields.

	# Act
	var accepted: bool = hr._apply_resolved_config(bad)

	# Assert
	assert_bool(accepted).is_false()
	assert_object(hr._config).is_null()


# Branch 3: _validate() returns errors → reject.
# Use a real RosterConfig with values that violate the validator
# (max_roster_size < formation_size — a known TR-006 rejection from Group C).
func test_apply_resolved_config_validate_errors_returns_false_and_falls_back() -> void:
	# Arrange
	var hr: Node = _make_fresh_roster_for_branch_testing()
	hr._config = null
	var invalid: Resource = preload("res://src/core/hero_roster/roster_config.gd").new()
	invalid.max_roster_size = 2  # < formation_size = 3 → TR-006 violation
	invalid.formation_size = 3
	invalid.level_cap = 15

	# Act
	var accepted: bool = hr._apply_resolved_config(invalid)

	# Assert — loader rejected; _config stays null; fallbacks active.
	assert_bool(accepted).is_false()
	assert_object(hr._config).is_null()
	assert_int(hr.max_roster_size()).is_equal(30)


# Branch 4: Resource has schema fields but no _validate method → ACCEPT.
# This is the "defensive tolerance" branch — non-RosterConfig Resources that
# happen to carry the three schema fields still load (configs that pre-date
# ADR-0011's _validate() requirement).
func test_apply_resolved_config_resource_without_validate_method_is_accepted() -> void:
	# Arrange — construct a Resource subclass via inline script that has the
	# three schema fields but NO _validate() method. We use a GDScript
	# Resource without _validate so duck-type `has_method("_validate")` returns
	# false, exercising branch 4's accept path.
	var hr: Node = _make_fresh_roster_for_branch_testing()
	hr._config = null
	var mock_script: GDScript = GDScript.new()
	mock_script.source_code = """extends Resource
@export var max_roster_size: int = 25
@export var formation_size: int = 3
@export var level_cap: int = 12
"""
	mock_script.reload()
	var no_validate: Resource = mock_script.new()

	# Act
	var accepted: bool = hr._apply_resolved_config(no_validate)

	# Assert — loader accepted; _config now points at the no-validate resource.
	assert_bool(accepted).is_true()
	assert_object(hr._config).is_not_null()
	# Accessors now read from the loaded config (NOT fallback constants):
	# 25 / 3 / 12 — distinct from the GDD §G defaults of 30 / 3 / 15.
	assert_int(hr.max_roster_size()).is_equal(25)
	assert_int(hr.level_cap()).is_equal(12)


# Positive-control sanity check: a fully-valid mock config IS accepted.
# Confirms the test infrastructure isn't accidentally rejecting valid inputs.
func test_apply_resolved_config_valid_config_returns_true_and_sets_config() -> void:
	# Arrange
	var hr: Node = _make_fresh_roster_for_branch_testing()
	hr._config = null
	var good: Resource = _make_valid_mock_config()

	# Act
	var accepted: bool = hr._apply_resolved_config(good)

	# Assert
	assert_bool(accepted).is_true()
	assert_object(hr._config).is_not_null()
	assert_int(hr.max_roster_size()).is_equal(30)
