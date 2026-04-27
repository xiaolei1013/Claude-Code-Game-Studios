class_name CombatConfig
extends GameData

## CombatConfig — single source of truth for Combat Resolution tuning knobs.
##
## All Combat balance constants live here as [code]@export[/code] fields,
## loaded at startup from [code]assets/data/config/combat_config.tres[/code]
## via [DataRegistry]. No combat balance value is hardcoded in
## [CombatResolver] subclasses — every constant below is a field on this
## resource.
##
## Usage:
##   [code]var cfg: CombatConfig = DataRegistry.resolve("config", "combat_config") as CombatConfig[/code]
##
## Call [method _validate] after any programmatic mutation to verify schema
## constraints. The method returns an empty array on a valid instance.
##
## ADR-0010: Combat Resolver Snapshot + Parity (consumes these knobs)
## ADR-0011: Resource schema + per-resource [method _validate] pattern.
## ADR-0013: Single-source-of-truth tuning knobs; no hardcoded balance in resolver code.
##
## NOTE: [member id] and [member display_name] are inherited from [GameData].
## Do NOT redeclare them here.

# ---------------------------------------------------------------------------
# Speed / cooldown (TR-combat-005, TR-combat-032 / GDD §G row SPEED_BASE)
# ---------------------------------------------------------------------------

## Reference speed value. action_cooldown_ticks(speed) = maxi(1, floori(SPEED_BASE / speed)).
##
## Default 10 per GDD §G. Higher values lengthen the cooldown for a given
## speed (slower combat); lower values shorten it. Must be >= 1.
## Safe range: 5 – 20.
## GDD §G row: SPEED_BASE.
@export_range(1, 50) var SPEED_BASE: int = 10


# ---------------------------------------------------------------------------
# Matchup multipliers (TR-combat-007 / GDD §G rows MATCHUP_THROUGHPUT_FACTOR)
# ---------------------------------------------------------------------------

## Per-enemy throughput multiplier for matchup-advantaged kills.
##
## Applied to [code]formation_dps_per_tick * hp_bonus_factor[/code] when the
## enemy's archetype is in the snapshot's matchup_cache as advantaged.
## Default 1.5 = 50% boost on advantaged kills.
## Safe range: 1.0 – 3.0.
## GDD §G row: MATCHUP_THROUGHPUT_FACTOR_ADV.
@export_range(1.0, 3.0, 0.05) var MATCHUP_THROUGHPUT_FACTOR_ADV: float = 1.5

## Per-enemy throughput multiplier for matchup-DISADVANTAGED kills.
##
## Applied to [code]formation_dps_per_tick * hp_bonus_factor[/code] when the
## enemy's archetype is NOT in the snapshot's matchup_cache as advantaged.
## Default 0.67 ≈ 33% throughput penalty on neutral/bad-matchup kills.
## Safe range: 0.1 – 0.99 (must be strictly < 1.0; 1.0 = no penalty = wrong).
## GDD §G row: MATCHUP_THROUGHPUT_FACTOR_DIS.
@export_range(0.1, 0.99, 0.01) var MATCHUP_THROUGHPUT_FACTOR_DIS: float = 0.67


# ---------------------------------------------------------------------------
# Losing-run loot factor (GDD §G row LOSING_RUN_LOOT_FACTOR / Pillar 3 hook)
# ---------------------------------------------------------------------------

## Multiplier applied to per-kill gold when the run is LOSING (survived=false
## per TR-009 hp_bonus_factor < 0.5). Default 0.5 = half loot on losing runs.
## Safe range: 0.0 – 1.0 (0.0 = no loot on losing; 1.0 = no penalty).
## Reasonable values: 0.3 – 0.7.
## GDD §G row: LOSING_RUN_LOOT_FACTOR.
@export_range(0.0, 1.0, 0.05) var LOSING_RUN_LOOT_FACTOR: float = 0.5


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Validates all schema constraints for this CombatConfig instance.
##
## Returns an empty [Array][String] if the instance is valid; returns a
## non-empty list of human-readable violation strings if any constraint fails.
##
## Enforced constraints:
##   1. [member SPEED_BASE] >= 1
##   2. [member MATCHUP_THROUGHPUT_FACTOR_ADV] >= 1.0 (no penalty for advantage)
##   3. [member MATCHUP_THROUGHPUT_FACTOR_DIS] strictly < 1.0 (must be a penalty;
##      1.0 would mean disadvantaged kills throughput == neutral, defeating
##      Pillar 3 — TR-005 / TR-019 of matchup-resolver)
##   4. [member LOSING_RUN_LOOT_FACTOR] in [0.0, 1.0]
##
## ADR-0011 §Decision — per-resource _validate() pattern.
func _validate() -> Array[String]:
	var errors: Array[String] = []

	if SPEED_BASE < 1:
		errors.append("SPEED_BASE must be >= 1; got %d" % SPEED_BASE)

	if MATCHUP_THROUGHPUT_FACTOR_ADV < 1.0:
		errors.append(
			"MATCHUP_THROUGHPUT_FACTOR_ADV must be >= 1.0; got %f"
			% MATCHUP_THROUGHPUT_FACTOR_ADV
		)

	if MATCHUP_THROUGHPUT_FACTOR_DIS >= 1.0:
		errors.append(
			"MATCHUP_THROUGHPUT_FACTOR_DIS must be strictly < 1.0; got %f"
			% MATCHUP_THROUGHPUT_FACTOR_DIS
		)

	if LOSING_RUN_LOOT_FACTOR < 0.0 or LOSING_RUN_LOOT_FACTOR > 1.0:
		errors.append(
			"LOSING_RUN_LOOT_FACTOR must be in [0.0, 1.0]; got %f"
			% LOSING_RUN_LOOT_FACTOR
		)

	return errors
