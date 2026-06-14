## CombatRunSnapshot — frozen-at-DISPATCHING input to [CombatResolver].
##
## RefCounted value type holding the immutable run state Combat needs to
## produce deterministic kill streams. Distinct from [RunSnapshot] (the
## orchestrator's per-dispatch FSM state, ADR-0014) — CombatRunSnapshot is
## a tighter, combat-specific projection used as the input parameter to
## [code]emit_events_in_range[/code] and [code]compute_offline_batch[/code].
##
## All fields are populated at DISPATCHING (Story 004 of dungeon-run-
## orchestrator wires the population) and NEVER mutated mid-run. Combat is
## a pure function of this snapshot + the tick range — the same snapshot
## passed twice produces field-equal results (TR-021).
##
## Fields:
##   - [member formation_dps_per_tick]: float — `sum(hero.attack * hero.speed) / SPEED_BASE`
##     computed at DISPATCHING. Range [0.0, 2.31] for MVP heroes.
##   - [member matchup_cache]: [code]Dictionary[StringName, bool][/code] —
##     per-archetype is_advantaged lookup, built once at DISPATCHING by
##     calling [MatchupResolver.resolve_formation_matchup] per distinct floor
##     enemy archetype (TR-combat-012; ≤5 calls per MVP floor).
##   - [member formation_total_hp]: int — `sum(hero.HP(level))` across the
##     formation, computed at DISPATCHING. The shared party HP pool consumed
##     by the two-sided HP race (GDD #34 §D / §E.3). Resets each loop.
##   - [member enemy_list]: [code]Array[Dictionary][/code] — per-floor enemy
##     definitions sourced from [code]Floor.enemy_list[/code]. Each entry
##     carries `id` (StringName), `archetype` (StringName), `tier` (int),
##     `is_boss` (bool), `base_hp` (int), `base_attack` (int), `base_speed`
##     (int — drives the enemy → party damage rate per GDD #34 §D).
##   - [member dispatched_at_tick]: int — absolute tick at DISPATCHING entry.
##     Tick math is anchored here (TR-combat-026: closed-form schedule is
##     time-anchored; clock-rewind / frame-drop recovers via the range arg).
##   - [member loops_per_run]: int — derived loop budget for the run; combat
##     iterates this many enemy_list rotations before a floor-clear marker.
##
## Frozen contract: callers MUST treat this as a read-only handle. Combat does
## NOT mutate it. The dictionary + array fields are NOT duplicated by Combat
## (callers are responsible for passing immutable refs); however, the
## orchestrator's snapshot-build code (Story 004 of orchestrator epic)
## SHOULD deep-copy from the live HeroRoster + Floor before producing this.
##
## ADR-0010: Combat Resolver Snapshot + Parity (immutable input contract)
## ADR-0021: §Phase 1 — formation_total_hp drives the two-sided HP race; the
##           legacy hp_bonus_factor DPS-throttle field is RETIRED (GDD #34).
class_name CombatRunSnapshot extends RefCounted

## Formation DPS per tick — pre-computed at DISPATCHING.
## Range [0.0, 2.31] for MVP heroes (FORMATION_SIZE=3, attack≤11, speed≤7).
var formation_dps_per_tick: float = 0.0

## Formation total HP — pre-computed at DISPATCHING. The shared party HP pool
## the two-sided HP race draws down (GDD #34 §D); resets each loop (§E.3).
var formation_total_hp: int = 0

## Per-archetype matchup_advantaged lookup — built once at DISPATCHING via
## [code]MatchupResolver.resolve_formation_matchup[/code] per distinct
## archetype on the floor (TR-combat-012; ≤5 calls per MVP floor).
var matchup_cache: Dictionary = {}

## Per-floor enemy definitions, ordered as they appear in the loop schedule.
## Each entry: { id: StringName, archetype: StringName, tier: int,
##               is_boss: bool, base_hp: int, base_attack: int, base_speed: int }
var enemy_list: Array = []

## Absolute tick at DISPATCHING entry. All combat math is time-anchored from here.
var dispatched_at_tick: int = 0

## Loop budget — number of enemy_list rotations before floor-clear.
var loops_per_run: int = 0


## Field-by-field equality with TR-016 dict_equals + TR-017 is_equal_approx.
##
## TR-combat-013 / TR-combat-016 / TR-combat-017 — ADR-0010
func equals(other: CombatRunSnapshot) -> bool:
	if other == null:
		return false
	if dispatched_at_tick != other.dispatched_at_tick:
		return false
	if loops_per_run != other.loops_per_run:
		return false
	if formation_total_hp != other.formation_total_hp:
		return false
	if not is_equal_approx(formation_dps_per_tick, other.formation_dps_per_tick):
		return false
	# enemy_list is Array of Dicts — element-by-element comparison.
	if enemy_list.size() != other.enemy_list.size():
		return false
	for i: int in range(enemy_list.size()):
		var a: Dictionary = enemy_list[i] as Dictionary
		var b: Dictionary = other.enemy_list[i] as Dictionary
		if not CombatBatchResult.dict_equals(a, b):
			return false
	# matchup_cache is Dictionary[StringName, bool] — direct dict_equals.
	if not CombatBatchResult.dict_equals(matchup_cache, other.matchup_cache):
		return false
	return true
