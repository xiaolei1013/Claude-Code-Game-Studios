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
## This is the run-DURATION / watchability dial. SPEED_BASE sits in the
## denominator of BOTH the party's kill throughput (Σ atk×spd / SPEED_BASE) AND
## the enemy→party damage rate (Σ atk×spd / SPEED_BASE), so scaling it stretches
## the whole two-sided HP race in TIME without changing who wins — it is
## outcome-invariant. Higher = longer (slower) clears; lower = snappier clears.
## Win/lose is governed by enemy stats + matchup, never by SPEED_BASE.
##
## Phase 2 (GDD #34 §D.7 calibration): raised from the Phase-1 placeholder of 10
## (which collapsed every floor to a sub-second "instant combat" blur) to 90, the
## value that lands Forest Reach floor clears in the watchable ~3–4 s window
## empirically verified by floor_calibration_test.gd. Must be >= 1.
## Safe range: 60 – 150 (run-duration only; re-tune freely, it cannot flip a
## verdict). GDD §G row: SPEED_BASE.
@export_range(1, 150) var SPEED_BASE: int = 90


# ---------------------------------------------------------------------------
# Matchup multipliers (TR-combat-007 / GDD §G rows MATCHUP_THROUGHPUT_FACTOR)
# ---------------------------------------------------------------------------

## Per-enemy throughput multiplier for matchup-advantaged kills.
##
## Applied to [code]formation_dps_per_tick[/code] when the enemy's archetype is
## in the snapshot's matchup_cache as advantaged.
## Default 1.5 = 50% boost on advantaged kills.
## Safe range: 1.0 – 3.0.
## GDD §G row: MATCHUP_THROUGHPUT_FACTOR_ADV.
@export_range(1.0, 3.0, 0.05) var MATCHUP_THROUGHPUT_FACTOR_ADV: float = 1.5

## Per-enemy throughput multiplier for matchup-DISADVANTAGED kills.
##
## Applied to [code]formation_dps_per_tick[/code] when the enemy's archetype is
## NOT in the snapshot's matchup_cache as advantaged.
## Default 0.67 ≈ 33% throughput penalty on neutral/bad-matchup kills.
## Safe range: 0.1 – 0.99 (must be strictly < 1.0; 1.0 = no penalty = wrong).
## GDD §G row: MATCHUP_THROUGHPUT_FACTOR_DIS.
@export_range(0.1, 0.99, 0.01) var MATCHUP_THROUGHPUT_FACTOR_DIS: float = 0.67


# ---------------------------------------------------------------------------
# Enemy → party damage multiplier (GDD #34 §D / §G row MATCHUP_PARTY_DISADVANTAGE)
# ---------------------------------------------------------------------------

## Flat multiplier applied to the enemy → party damage rate in the two-sided
## HP race (GDD #34 §D): each still-alive enemy deals
## [code](enemy.attack * enemy.speed) / SPEED_BASE * MATCHUP_PARTY_DISADVANTAGE[/code]
## per tick to the shared party HP pool.
##
## Default 1.0 = neutral (Phase 1). Phase 2 calibration raises this (GDD §G
## suggests ~1.25) so a mismatched party takes meaningfully more damage and
## can be defeated even on a floor it would otherwise out-DPS. Values > 1.0
## make defeats more likely; values < 1.0 make the party tankier.
## Safe range: 0.5 – 3.0.
## GDD §G row: MATCHUP_PARTY_DISADVANTAGE.
@export_range(0.5, 3.0, 0.05) var MATCHUP_PARTY_DISADVANTAGE: float = 1.0

# Phase 1 (GDD #34 / ADR-0021): LOSING_RUN_LOOT_FACTOR (half-loot on a losing
# run) is RETIRED. The pivot replaces the losing-run-with-half-loot state with a
# binary WIN (full loot) / DEFEAT (zero loot) outcome from the two-sided HP race.


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
##   4. [member MATCHUP_PARTY_DISADVANTAGE] > 0.0
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

	if MATCHUP_PARTY_DISADVANTAGE <= 0.0:
		errors.append(
			"MATCHUP_PARTY_DISADVANTAGE must be > 0.0; got %f"
			% MATCHUP_PARTY_DISADVANTAGE
		)

	return errors
