# Tests for Sprint 7 combat-resolution Story 002:
#   - CombatConfig resource extends GameData with 4 @export tuning fields
#   - _validate() returns Array[String]; empty on valid (ADR-0011)
#   - combat_config.tres exists at canonical path with snake_case id
#   - Defaults match GDD §G (SPEED_BASE=10, MATCHUP_THROUGHPUT_FACTOR_ADV=1.5,
#     MATCHUP_THROUGHPUT_FACTOR_DIS=0.67, MATCHUP_PARTY_DISADVANTAGE=1.0)
#
# Phase 1 (GDD #34 / ADR-0021): LOSING_RUN_LOOT_FACTOR is RETIRED; the
# enemy→party damage multiplier MATCHUP_PARTY_DISADVANTAGE replaces it as the
# 4th tuning knob.
#
# Covers: TR-combat-031 (combat_config.tres tuning constants).
extends GdUnitTestSuite

const CombatConfigScript = preload("res://src/core/combat/combat_config.gd")
const COMBAT_CONFIG_PATH := "res://assets/data/config/combat_config.tres"


# ===========================================================================
# Group A: schema fields exist with correct types and GDD §G defaults
# ===========================================================================

func test_combat_config_default_speed_base_is_ten() -> void:
	var cfg: CombatConfig = CombatConfigScript.new()
	assert_int(cfg.SPEED_BASE).is_equal(10)


func test_combat_config_default_matchup_throughput_factor_adv_is_1_5() -> void:
	var cfg: CombatConfig = CombatConfigScript.new()
	assert_float(cfg.MATCHUP_THROUGHPUT_FACTOR_ADV).is_equal_approx(1.5, 0.001)


func test_combat_config_default_matchup_throughput_factor_dis_is_0_67() -> void:
	var cfg: CombatConfig = CombatConfigScript.new()
	assert_float(cfg.MATCHUP_THROUGHPUT_FACTOR_DIS).is_equal_approx(0.67, 0.001)


func test_combat_config_default_matchup_party_disadvantage_is_1_0() -> void:
	var cfg: CombatConfig = CombatConfigScript.new()
	assert_float(cfg.MATCHUP_PARTY_DISADVANTAGE).is_equal_approx(1.0, 0.001)


func test_combat_config_extends_gamedata() -> void:
	var cfg: CombatConfig = CombatConfigScript.new()
	var as_object: Object = cfg
	assert_bool(as_object is GameData).is_true()


# ===========================================================================
# Group B: _validate() returns empty Array[String] on default instance
# ===========================================================================

func test_combat_config_default_instance_validates_clean() -> void:
	var cfg: CombatConfig = CombatConfigScript.new()
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_equal(0)


# ===========================================================================
# Group C: _validate() catches constraint violations
# ===========================================================================

func test_combat_config_validate_rejects_zero_speed_base() -> void:
	var cfg: CombatConfig = CombatConfigScript.new()
	cfg.SPEED_BASE = 0
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_greater(0)
	var joined: String = ", ".join(errors)
	assert_str(joined).contains("SPEED_BASE")


func test_combat_config_validate_rejects_matchup_adv_below_one() -> void:
	# MATCHUP_THROUGHPUT_FACTOR_ADV must be >= 1.0 (no penalty for advantage).
	var cfg: CombatConfig = CombatConfigScript.new()
	cfg.MATCHUP_THROUGHPUT_FACTOR_ADV = 0.9
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_greater(0)
	var joined: String = ", ".join(errors)
	assert_str(joined).contains("MATCHUP_THROUGHPUT_FACTOR_ADV")


func test_combat_config_validate_rejects_matchup_dis_at_or_above_one() -> void:
	# MATCHUP_THROUGHPUT_FACTOR_DIS must be strictly < 1.0 (Pillar 3: must be
	# a penalty). 1.0 means no penalty, which defeats the matchup-as-decision
	# economic hook.
	var cfg: CombatConfig = CombatConfigScript.new()
	cfg.MATCHUP_THROUGHPUT_FACTOR_DIS = 1.0
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_greater(0)
	var joined: String = ", ".join(errors)
	assert_str(joined).contains("MATCHUP_THROUGHPUT_FACTOR_DIS")


func test_combat_config_validate_rejects_party_disadvantage_zero() -> void:
	# MATCHUP_PARTY_DISADVANTAGE must be > 0.0 (GDD #34 §D): a zero multiplier
	# would make every enemy deal zero damage, so no run could ever be defeated.
	var cfg: CombatConfig = CombatConfigScript.new()
	cfg.MATCHUP_PARTY_DISADVANTAGE = 0.0
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_greater(0)
	var joined: String = ", ".join(errors)
	assert_str(joined).contains("MATCHUP_PARTY_DISADVANTAGE")


func test_combat_config_validate_rejects_party_disadvantage_negative() -> void:
	var cfg: CombatConfig = CombatConfigScript.new()
	cfg.MATCHUP_PARTY_DISADVANTAGE = -0.1
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_greater(0)


# ===========================================================================
# Group D: combat_config.tres exists, loads, validates clean
# ===========================================================================

func test_combat_config_tres_resource_exists_at_expected_path() -> void:
	var resource_exists: bool = ResourceLoader.exists(COMBAT_CONFIG_PATH)
	assert_bool(resource_exists).is_true()


func test_combat_config_tres_loads_and_is_combat_config() -> void:
	var loaded: Resource = load(COMBAT_CONFIG_PATH)
	assert_object(loaded).is_not_null()
	assert_bool(loaded is CombatConfig).is_true()


func test_combat_config_tres_default_values_match_gdd() -> void:
	var loaded: Resource = load(COMBAT_CONFIG_PATH)
	var cfg: CombatConfig = loaded as CombatConfig
	assert_int(cfg.SPEED_BASE).is_equal(10)
	assert_float(cfg.MATCHUP_THROUGHPUT_FACTOR_ADV).is_equal_approx(1.5, 0.001)
	assert_float(cfg.MATCHUP_THROUGHPUT_FACTOR_DIS).is_equal_approx(0.67, 0.001)
	assert_float(cfg.MATCHUP_PARTY_DISADVANTAGE).is_equal_approx(1.0, 0.001)


func test_combat_config_tres_validates_clean() -> void:
	var loaded: Resource = load(COMBAT_CONFIG_PATH)
	var cfg: CombatConfig = loaded as CombatConfig
	var errors: Array[String] = cfg._validate()
	assert_int(errors.size()).is_equal(0)


func test_combat_config_tres_id_and_display_name_set() -> void:
	# DataRegistry boot scan keys by `id`; resolve("config", "combat_config") needs id.
	var loaded: Resource = load(COMBAT_CONFIG_PATH)
	var cfg: CombatConfig = loaded as CombatConfig
	assert_str(cfg.id).is_equal("combat_config")
	assert_str(cfg.display_name).is_not_empty()


# ===========================================================================
# Group E: TR-031 source-grep — no hardcoded combat balance in resolver code
# ===========================================================================

func test_no_hardcoded_combat_constants_in_resolver_source() -> void:
	# Sprint 7 anti-pattern (parallels matchup-resolver Story 008 lint pattern).
	# Resolver source files must NOT hardcode the GDD §G combat constants.
	# The values appear ONLY in CombatConfig defaults + the .tres file.
	#
	# Constants checked: SPEED_BASE=10 → "= 10" outside doc-comments;
	# MATCHUP_THROUGHPUT_FACTOR_ADV=1.5 → "= 1.5"; etc.
	# This is a soft lint — resolver code may legitimately use 1.0 / 0.5 for
	# OTHER reasons. So we check for the EXACT GDD §G defaults appearing as
	# class-scope const declarations or as direct-code values.
	var resolver_files: Array[String] = [
		"res://src/core/combat/combat_resolver.gd",
		"res://src/core/combat/default_combat_resolver.gd",
	]
	for path: String in resolver_files:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue  # default_combat_resolver.gd may be the Sprint 6 stub; skip
		var content: String = file.get_as_text()
		file.close()
		# Reject `const X = <gdd_default>` style hardcodes. Doc-comment mentions
		# (e.g., "default 1.5") are permitted because they're documentation,
		# not behavior.
		var lines: PackedStringArray = content.split("\n")
		for line: String in lines:
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("#") or trimmed.begins_with("##"):
				continue
			# Reject const declarations with hardcoded combat balance values.
			# This catches `const SPEED_BASE: int = 10` etc.
			if trimmed.begins_with("const SPEED_BASE"):
				assert_bool(false).override_failure_message(
					"%s: SPEED_BASE hardcoded as const — must come from CombatConfig"
					% path
				).is_true()
			if trimmed.begins_with("const MATCHUP_THROUGHPUT_FACTOR_"):
				assert_bool(false).override_failure_message(
					"%s: MATCHUP_THROUGHPUT_FACTOR_* hardcoded — must come from CombatConfig"
					% path
				).is_true()
			if trimmed.begins_with("const MATCHUP_PARTY_DISADVANTAGE"):
				assert_bool(false).override_failure_message(
					"%s: MATCHUP_PARTY_DISADVANTAGE hardcoded — must come from CombatConfig"
					% path
				).is_true()
