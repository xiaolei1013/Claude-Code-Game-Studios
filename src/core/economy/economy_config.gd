class_name EconomyConfig
extends GameData

## EconomyConfig — single source of truth for all Economy tuning knobs.
##
## All 26 design-tunable balance constants live here as [code]@export[/code]
## fields, loaded at startup from [code]assets/data/config/economy_config.tres[/code]
## via [DataRegistry]. No economy balance value is hardcoded in [Economy] —
## every constant below is a field on this resource.
##
## Usage: [code]var cfg: EconomyConfig = DataRegistry.resolve("config", "economy_config") as EconomyConfig[/code]
##
## Call [method _validate] after any programmatic mutation to verify schema
## constraints. The method returns an empty array on a valid instance.
##
## ADR-0011: Resource schema + per-resource [method _validate] pattern.
## ADR-0013: Single-source-of-truth tuning knobs; no hardcoded balance in economy.gd.
## ADR-0006: DataRegistry boot-scan loads this file from assets/data/config/.
##
## NOTE: [member id] and [member display_name] are inherited from [GameData].
## Do NOT redeclare them here.

# ---------------------------------------------------------------------------
# Section: Drip income (TR-economy-006 / GDD §D.1 / §G rows BASE_DRIP[1..5])
# ---------------------------------------------------------------------------

## First-launch starting gold per Onboarding GDD #29 §C.1 + §D.1.
##
## Set just below recruit_cost(warrior, 0) = 150 so the first-session player
## MUST dispatch to earn the recruit gap (forces the cozy first-action loop).
## Above 150 lets the player skip the first dispatch + recruit immediately,
## which violates the Onboarding §B Player Fantasy.
## Below 50 makes Recruit feel out of reach for too many runs.
## Safe range: 50–200. Default 100 per Onboarding GDD §G.
##
## NOT YET wired into Economy.load_save_data (which is currently stubbed).
## Sprint 14+ Onboarding implementation (S14-S3) closes the wiring AC-29-03:
## first-launch with empty save dict initializes _gold_balance to STARTING_GOLD.
## Returning-launch with persisted gold_balance restores the saved value.
##
## GDD §G rows: STARTING_GOLD (Onboarding GDD #29).
@export_range(0, 1000) var STARTING_GOLD: int = 100

## Gold drip per tick indexed by floor (0-based; access as BASE_DRIP[floor_index - 1]).
##
## Size MUST be 5 (one entry per MVP floor, 1–5).
## Defaults: floor 1 = 2, floor 2 = 4, floor 3 = 7, floor 4 = 12, floor 5 = 8.
## Note: floor 5 is intentionally lower than floor 4 — non-monotonic pending
## full revalidation (Pass-3B 2026-04-20 — preserves "10–14 days to max" pillar).
## Safe range per entry: 1–30 (see §G per-row ranges for per-floor safe ranges).
## GDD §G rows: BASE_DRIP[1] through BASE_DRIP[5].
@export var BASE_DRIP: Array[int] = [2, 4, 7, 12, 8]

## Per-tick drip multiplier for matchup-advantaged formations.
##
## Applied multiplicatively to the base drip when the active formation has a
## class-vs-biome advantage. Default 1.0 = disabled (no bonus).
## Safe range: 1.0 – 1.3.
## GDD §G row: MATCHUP_DRIP_BONUS.
@export_range(1.0, 1.3, 0.05) var MATCHUP_DRIP_BONUS: float = 1.0

# ---------------------------------------------------------------------------
# Section: Kill gold (TR-economy-007 / GDD §D.2 / §G rows MATCHUP_GOLD_MULTIPLIER)
# ---------------------------------------------------------------------------

## Base gold burst per enemy kill, keyed by enemy tier (1, 2, 3).
##
## Formula: kill_bonus = floori(BASE_KILL[enemy_tier] × matchup_multiplier)
## Defaults: {1: 10, 2: 35, 3: 80}.
## All values MUST be > 0.
## GDD §D.2 BASE_KILL table; TR-economy-007.
@export var BASE_KILL: Dictionary = {1: 10, 2: 35, 3: 80}

## Per-kill gold bonus multiplier when the active class counters the enemy type.
##
## Applied to BASE_KILL on a matchup-advantage kill.
## Default 1.5 = 50% bonus on countered kills.
## Safe range: 1.0 – 2.5.
## GDD §G row: MATCHUP_GOLD_MULTIPLIER.
@export_range(1.0, 2.5, 0.05) var MATCHUP_GOLD_MULTIPLIER: float = 1.5

# ---------------------------------------------------------------------------
# Section: Recruit costs (TR-economy-008 / GDD §D.3 / §G rows BASE_RECRUIT + RECRUIT_RATIO)
# ---------------------------------------------------------------------------

## Base recruit cost for the FIRST copy of a class, keyed by tier (1, 2).
##
## Formula: recruit_cost(N) = floori(BASE_RECRUIT[tier] × RECRUIT_RATIO^copies_owned)
## Defaults: {1: 150, 2: 8000}.
## All values MUST be > 0.
## GDD §G rows: BASE_RECRUIT[tier_1], BASE_RECRUIT[tier_2].
@export var BASE_RECRUIT: Dictionary = {1: 150, 2: 8000}

## Geometric escalation factor for each additional copy of the same class.
##
## Must be strictly > 1.0 — a value of 1.0 means no escalation.
## Safe range: 1.2 – 2.5.
## GDD §G row: RECRUIT_RATIO.
@export_range(1.01, 2.5, 0.01) var RECRUIT_RATIO: float = 1.8

# ---------------------------------------------------------------------------
# Section: Level costs (TR-economy-009 / GDD §D.4 / §G rows BASE_LEVEL + LEVEL_RATIO + LEVEL_CAP)
# ---------------------------------------------------------------------------

## Base leveling cost from L1 → L2 for each hero tier (1, 2).
##
## Formula: level_cost(tier, level) = floori(BASE_LEVEL[tier] × LEVEL_RATIO^(level - 1))
## Defaults: {1: 40, 2: 600}.
## All values MUST be > 0.
## GDD §G rows: BASE_LEVEL[tier_1], BASE_LEVEL[tier_2].
@export var BASE_LEVEL: Dictionary = {1: 40, 2: 600}

## Geometric escalation factor per hero level.
##
## Applied per level: each additional level costs LEVEL_RATIO× the previous.
## Safe range: 1.3 – 2.0.
## GDD §G row: LEVEL_RATIO.
@export_range(1.3, 2.0, 0.05) var LEVEL_RATIO: float = 1.6

## Maximum hero level in MVP.
##
## Heroes cannot be leveled past this value. Returns sentinel -1 in
## [method Economy.level_cost] when current_level >= LEVEL_CAP (Story 008).
## Must be >= 1.
## Safe range: 10 – 20.
## GDD §G row: LEVEL_CAP.
@export_range(1, 20) var LEVEL_CAP: int = 15

# ---------------------------------------------------------------------------
# Section: Floor-clear bonuses (TR-economy-010 / GDD §D.5 / §G rows FLOOR_CLEAR_BONUS[1..5])
# ---------------------------------------------------------------------------

## One-shot gold rewards for first-clearing each floor, keyed by floor index (1–5).
##
## Economy credits these via [method Economy.try_award_floor_clear] using the
## monotonic-credit-gap contract (ADR-0002 — same floor can never be credited
## more than its stored value; partial LOSING clears leave the remainder as a
## "reclaim hook" on the next WIN clear).
## Defaults: {1: 500, 2: 1200, 3: 3000, 4: 7500, 5: 18000}.
## All values MUST be > 0.
## GDD §G rows: FLOOR_CLEAR_BONUS[1] through FLOOR_CLEAR_BONUS[5].
@export var FLOOR_CLEAR_BONUS: Dictionary = {
	1: 500,
	2: 1200,
	3: 3000,
	4: 7500,
	5: 18000,
}

# ---------------------------------------------------------------------------
# Section: Engineering ceiling (GDD §G row: GOLD_SANITY_CAP)
# ---------------------------------------------------------------------------

## Engineering ceiling on the gold balance (1 trillion).
##
## Matches the structural constant [constant Economy.GOLD_SANITY_CAP] in
## economy.gd — two locations is intentional per ADR-0013: the economy.gd
## constant is the compile-time engineering guard; this field is the
## design-tunable knob with the same default.
## All tuning above 100_000_000 is safe; do not lower below that threshold.
## GDD §G row: GOLD_SANITY_CAP.
@export var GOLD_SANITY_CAP: int = 1_000_000_000_000

# ---------------------------------------------------------------------------
# Section: Offline progression cap (GDD §G row: offline_cap_seconds)
# ---------------------------------------------------------------------------

## Maximum creditable offline time in seconds (default 8 hours = 28800 s).
##
## Ticks accrued beyond this window are discarded at the next app open.
## Capping at 8h balances fairness (sleep + commute credit) against FOMO
## (avoiding uncapped accrual that trivialises the pacing pillar).
## Safe range: 14400 (4 h) – 43200 (12 h).
## GDD §G row: offline_cap_seconds.
@export_range(14400, 43200, 900) var offline_cap_seconds: int = 28800

# ---------------------------------------------------------------------------
# Section: Display thresholds (GDD §G rows: DISPLAY_K/M/B/T_THRESHOLD)
# ---------------------------------------------------------------------------

## Gold amount at which the display switches from raw number to K notation.
##
## E.g. threshold 1000 means 1000 displays as "1K".
## Must be < DISPLAY_M_THRESHOLD.
## Safe range: 500 – 2000.
## GDD §G row: DISPLAY_K_THRESHOLD.
@export_range(500, 2000) var DISPLAY_K_THRESHOLD: int = 1_000

## Gold amount at which the display switches from K notation to M notation.
##
## Must be > DISPLAY_K_THRESHOLD and < DISPLAY_B_THRESHOLD.
## Safe range: 500_000 – 2_000_000.
## GDD §G row: DISPLAY_M_THRESHOLD.
@export var DISPLAY_M_THRESHOLD: int = 1_000_000

## Gold amount at which the display switches from M notation to B notation.
##
## Must be > DISPLAY_M_THRESHOLD and < DISPLAY_T_THRESHOLD.
## GDD §G row: DISPLAY_B_THRESHOLD.
@export var DISPLAY_B_THRESHOLD: int = 1_000_000_000

## Gold amount at which the display switches from B notation to T notation.
##
## Matches [member GOLD_SANITY_CAP] by design — the display ceiling equals
## the engineering ceiling in MVP.
## GDD §G row: DISPLAY_T_THRESHOLD.
@export var DISPLAY_T_THRESHOLD: int = 1_000_000_000_000

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Validates all schema constraints for this EconomyConfig instance.
##
## Returns an empty [Array][String] if the instance is valid; returns a
## non-empty list of human-readable violation strings if any constraint fails.
##
## Called by tests and (once data-registry epic Story 008 lands) by
## DataRegistry's per-type validator dispatch. An empty return == OK.
##
## Enforced constraints:
##   1. [member BASE_DRIP] length == 5
##   2. All [member BASE_DRIP] values >= 0
##   3. [member MATCHUP_GOLD_MULTIPLIER] > 0.0
##   4. [member RECRUIT_RATIO] > 1.0 (strictly — 1.0 = no escalation, invalid)
##   5. [member LEVEL_CAP] >= 1
##   6. All values in [member BASE_KILL], [member BASE_RECRUIT],
##      [member BASE_LEVEL], and [member FLOOR_CLEAR_BONUS] > 0
##   7. Display thresholds form a strictly increasing sequence (K < M < B < T)
##
## ADR-0011 §Decision — per-resource _validate() pattern.
func _validate() -> Array[String]:
	var errors: Array[String] = []

	# Constraint 1: BASE_DRIP length == 5
	if BASE_DRIP.size() != 5:
		errors.append(
			"BASE_DRIP must have exactly 5 entries (one per floor 1-5); "
			+ "got %d" % BASE_DRIP.size()
		)

	# Constraint 2: all BASE_DRIP values >= 0
	for i: int in range(BASE_DRIP.size()):
		if BASE_DRIP[i] < 0:
			errors.append(
				"BASE_DRIP[%d] must be >= 0; got %d" % [i, BASE_DRIP[i]]
			)

	# Constraint 3: MATCHUP_GOLD_MULTIPLIER > 0.0
	if MATCHUP_GOLD_MULTIPLIER <= 0.0:
		errors.append(
			"MATCHUP_GOLD_MULTIPLIER must be > 0.0; got %f" % MATCHUP_GOLD_MULTIPLIER
		)

	# Constraint 4: RECRUIT_RATIO > 1.0 (strictly)
	if RECRUIT_RATIO <= 1.0:
		errors.append(
			"RECRUIT_RATIO must be > 1.0 (strictly); got %f" % RECRUIT_RATIO
		)

	# Constraint 5: LEVEL_CAP >= 1
	if LEVEL_CAP < 1:
		errors.append(
			"LEVEL_CAP must be >= 1; got %d" % LEVEL_CAP
		)

	# Constraint 6: all table values > 0
	for tier: int in BASE_KILL:
		if BASE_KILL[tier] <= 0:
			errors.append(
				"BASE_KILL[%d] must be > 0; got %d" % [tier, BASE_KILL[tier]]
			)
	for tier: int in BASE_RECRUIT:
		if BASE_RECRUIT[tier] <= 0:
			errors.append(
				"BASE_RECRUIT[%d] must be > 0; got %d" % [tier, BASE_RECRUIT[tier]]
			)
	for tier: int in BASE_LEVEL:
		if BASE_LEVEL[tier] <= 0:
			errors.append(
				"BASE_LEVEL[%d] must be > 0; got %d" % [tier, BASE_LEVEL[tier]]
			)
	for floor_idx: int in FLOOR_CLEAR_BONUS:
		if FLOOR_CLEAR_BONUS[floor_idx] <= 0:
			errors.append(
				"FLOOR_CLEAR_BONUS[%d] must be > 0; got %d"
				% [floor_idx, FLOOR_CLEAR_BONUS[floor_idx]]
			)

	# Constraint 7: display thresholds are strictly increasing (K < M < B < T)
	if not (DISPLAY_K_THRESHOLD < DISPLAY_M_THRESHOLD):
		errors.append(
			"DISPLAY_K_THRESHOLD (%d) must be < DISPLAY_M_THRESHOLD (%d)"
			% [DISPLAY_K_THRESHOLD, DISPLAY_M_THRESHOLD]
		)
	if not (DISPLAY_M_THRESHOLD < DISPLAY_B_THRESHOLD):
		errors.append(
			"DISPLAY_M_THRESHOLD (%d) must be < DISPLAY_B_THRESHOLD (%d)"
			% [DISPLAY_M_THRESHOLD, DISPLAY_B_THRESHOLD]
		)
	if not (DISPLAY_B_THRESHOLD < DISPLAY_T_THRESHOLD):
		errors.append(
			"DISPLAY_B_THRESHOLD (%d) must be < DISPLAY_T_THRESHOLD (%d)"
			% [DISPLAY_B_THRESHOLD, DISPLAY_T_THRESHOLD]
		)

	return errors
