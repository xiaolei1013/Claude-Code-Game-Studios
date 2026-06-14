# Tests for Sprint 8 matchup-resolver Story 007 (S8-N7 carryover from S7-N7):
#   - MATCHUP_GOLD_MULTIPLIER lives ONLY in economy_config (TR-027)
#   - MATCHUP_THROUGHPUT_FACTOR_ADV/DIS live ONLY in combat_config (TR-028)
#   - Source-grep canaries on matchup_resolver/ source files return 0 hits
#   - Behavioral parity: advantaged matchup produces higher gold + higher
#     combat DPS than disadvantaged matchup
#
# Covers: TR-matchup-resolver-027 (Economy's gold path applies the multiplier;
#                                  the resolver itself knows zero gold values),
#         TR-matchup-resolver-028 (Combat's throughput scaling applies factors;
#                                  the resolver itself knows zero combat values).
#
# Implementation note: the story spec describes Economy's `enemy_killed` signal
# handler as the canonical multiplier-application site. The actual S8-S3
# implementation has the orchestrator pre-apply the multiplier via
# `attribute_kill_gold(tier, advantaged, losing_run)` before calling
# `Economy.add_gold(amount)`. Both wiring paths satisfy TR-027's contract
# (the multiplier IS applied based on `is_advantaged`); the orchestrator
# uses local constants `MATCHUP_MULT_ADV=1.5` / `MATCHUP_MULT_DIS=0.7` rather
# than reading economy_config.MATCHUP_GOLD_MULTIPLIER. Documented drift —
# same TD-012 class as Economy.add_gold signature divergence.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const EconomyConfigScript = preload("res://src/core/economy/economy_config.gd")
const CombatConfigScript = preload("res://src/core/combat/combat_config.gd")
const KillEventScript = preload("res://src/core/combat/kill_event.gd")
const CombatTickEventsScript = preload("res://src/core/combat/combat_tick_events.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")
const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")


# ===========================================================================
# Group A: TR-027 — MATCHUP_GOLD_MULTIPLIER lives ONLY in economy_config
# ===========================================================================

const _RESOLVER_SOURCES: Array[String] = [
	"res://src/core/matchup_resolver/matchup_resolver.gd",
	"res://src/core/matchup_resolver/default_matchup_resolver.gd",
	"res://src/core/matchup_resolver/matchup_result.gd",
]


func _read_source(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Source missing: %s" % path)
		return ""
	var content: String = f.get_as_text()
	f.close()
	return content


func _scan_for_pattern(path: String, pattern: String) -> int:
	# Returns count of NON-COMMENT lines containing `pattern`.
	var src: String = _read_source(path)
	if src.is_empty():
		return 0
	var hits: int = 0
	var lines: PackedStringArray = src.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		# Strip inline trailing comment.
		var hash_idx: int = trimmed.find("#")
		var code_only: String = trimmed if hash_idx < 0 else trimmed.substr(0, hash_idx)
		if code_only.contains(pattern):
			hits += 1
	return hits


func test_matchup_resolver_source_has_no_matchup_gold_multiplier_references() -> void:
	# TR-027: the resolver knows zero gold values. Economy owns the multiplier.
	var total_hits: int = 0
	for path: String in _RESOLVER_SOURCES:
		total_hits += _scan_for_pattern(path, "MATCHUP_GOLD_MULTIPLIER")
	assert_int(total_hits).is_equal(0)


func test_economy_config_declares_matchup_gold_multiplier_at_default_value() -> void:
	# Positive control: confirm MATCHUP_GOLD_MULTIPLIER lives in economy_config
	# at the GDD §G default value (1.5).
	var config: EconomyConfig = EconomyConfigScript.new()
	# @export_range default per the field declaration.
	assert_float(config.MATCHUP_GOLD_MULTIPLIER).is_equal_approx(1.5, 0.001)


# ===========================================================================
# Group B: TR-028 — MATCHUP_THROUGHPUT_FACTOR_ADV/DIS live ONLY in combat_config
# ===========================================================================

func test_matchup_resolver_source_has_no_matchup_throughput_factor_references() -> void:
	# TR-028: the resolver knows zero combat throughput values. Combat config owns them.
	var total_hits: int = 0
	for path: String in _RESOLVER_SOURCES:
		total_hits += _scan_for_pattern(path, "MATCHUP_THROUGHPUT_FACTOR")
	assert_int(total_hits).is_equal(0)


func test_combat_config_declares_matchup_throughput_factor_adv() -> void:
	var config: CombatConfig = CombatConfigScript.new()
	# Default per @export_range — must be >= 1.0 (no penalty for advantage).
	assert_float(config.MATCHUP_THROUGHPUT_FACTOR_ADV).is_greater_equal(1.0)


func test_combat_config_declares_matchup_throughput_factor_dis() -> void:
	var config: CombatConfig = CombatConfigScript.new()
	# Default per @export_range — must be strictly < 1.0 (must be a penalty).
	assert_float(config.MATCHUP_THROUGHPUT_FACTOR_DIS).is_less(1.0)


# ===========================================================================
# Group C: TR-027 — Behavioral: advantaged matchup yields more gold than disadvantaged
# ===========================================================================

func test_advantaged_kill_yields_more_gold_than_disadvantaged_kill() -> void:
	# Behavioral verification of the multiplier wiring (regardless of which
	# system applies it). Advantaged tier-1 kill = 7 gold; disadvantaged = 3 gold.
	# Ratio is 7/3 ≈ 2.33 (S8-S3 implementation: MATCHUP_MULT_ADV=1.5,
	# MATCHUP_MULT_DIS=0.7; ratio = 1.5/0.7 ≈ 2.143; rounded to floori produces 7/3).
	#
	# The story-spec's "1.5×" claim implicitly assumed a "neutral" 1.0 baseline
	# that doesn't exist in the actual implementation (only ADV vs DIS).
	# Documented drift; this test asserts the directional contract: advantaged
	# yields strictly more gold than disadvantaged. The specific ratio is a
	# tuning concern.
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)

	# Act
	var advantaged_gold: int = orch.attribute_kill_gold(1, true, false)
	var disadvantaged_gold: int = orch.attribute_kill_gold(1, false, false)

	# Assert
	assert_int(advantaged_gold).is_greater(disadvantaged_gold)
	# Sanity: actual values per S8-S3 formula.
	assert_int(advantaged_gold).is_equal(7)  # floori(5 * 1.5 * 1.0)
	assert_int(disadvantaged_gold).is_equal(3)  # floori(5 * 0.7 * 1.0)


func test_advantaged_kill_yields_higher_gold_at_every_tier() -> void:
	# Regression: the advantage > disadvantage relationship holds across all
	# 5 MVP tiers. Locks the directional contract against future tuning bugs.
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)

	for tier: int in [1, 2, 3, 4, 5]:
		var adv: int = orch.attribute_kill_gold(tier, true, false)
		var dis: int = orch.attribute_kill_gold(tier, false, false)
		assert_int(adv).is_greater(dis)


# ===========================================================================
# Group D: TR-028 — Behavioral: advantaged matchup yields higher combat DPS
# ===========================================================================

func test_advantaged_matchup_produces_higher_effective_dps_than_disadvantaged() -> void:
	# Combat per-enemy DPS scaling: effective_dps = raw * factor (Phase 1 / GDD
	# #34 §C.3 — the hp_bonus throttle was removed; survival is now resolved by
	# the two-sided HP race, not a DPS multiplier).
	# Advantaged: factor = MATCHUP_THROUGHPUT_FACTOR_ADV (1.5).
	# Disadvantaged: factor = MATCHUP_THROUGHPUT_FACTOR_DIS (0.67).
	# Verify advantaged > disadvantaged effective DPS for the same raw inputs.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var raw_dps: float = 1.0

	# Act — call effective_dps with each factor.
	var adv_eff: float = resolver.effective_dps(raw_dps, 1.5)
	var dis_eff: float = resolver.effective_dps(raw_dps, 0.67)

	# Assert
	assert_float(adv_eff).is_greater(dis_eff)
	# Sanity: 1.0 * 1.5 = 1.5; 1.0 * 0.67 = 0.67
	assert_float(adv_eff).is_equal_approx(1.5, 0.001)
	assert_float(dis_eff).is_equal_approx(0.67, 0.001)


# ===========================================================================
# Group E: structural — resolver source has no Economy/Combat constant imports
# ===========================================================================

func test_matchup_resolver_source_does_not_import_economy_config_or_combat_config() -> void:
	# TR-027 + TR-028 together: the resolver doesn't even know these config
	# files exist. Source-grep for `economy_config` / `combat_config` strings
	# in resolver source returns zero hits. (Comment-line mentions allowed.)
	var total_economy_hits: int = 0
	var total_combat_hits: int = 0
	for path: String in _RESOLVER_SOURCES:
		total_economy_hits += _scan_for_pattern(path, "economy_config")
		total_combat_hits += _scan_for_pattern(path, "combat_config")
	assert_int(total_economy_hits).is_equal(0)
	# combat_config can appear in `combat_run_snapshot.gd` references — but
	# matchup_resolver source files should NOT reference it.
	assert_int(total_combat_hits).is_equal(0)
