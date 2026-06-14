## CombatBatchResult — output of [CombatResolver.compute_offline_batch].
##
## Six-field RefCounted (no .free() needed). Offline-replay aggregate; carries
## per-archetype + per-tier kill counts (NOT per-event Array — TR-combat-023
## avoids retaining 15k+ KillEvent records for long offline runs).
##
## Fields (TR-combat-015):
##   - [member kills_by_archetype]: [code]Dictionary[StringName, int][/code]
##     — count of enemies killed per archetype. Used by Economy to apply the
##     matchup multiplier per killed-enemy archetype against the snapshot's
##     matchup_cache.
##   - [member kills_by_tier]: [code]Dictionary[int, int][/code] — count of
##     kills per tier (1, 2, 3). Drives Economy's [code]BASE_KILL[tier][/code]
##     gold lookup aggregation.
##   - [member loops_completed]: int — full enemy_list rotations completed in
##     this batch.
##   - [member first_clear_tick]: int — absolute tick of the first floor-clear
##     within this batch, or [code]-1[/code] if no clear landed. Orchestrator
##     deduplicates per-dispatch (TR-018).
##   - [member won]: bool — the run verdict from the two-sided HP race
##     ([code]CombatResolver.compute_run_outcome[/code], GDD #34 §D). Defaults
##     true; [code]false[/code] means the party was defeated before the floor
##     cleared, in which case the orchestrator forfeits all loot for this batch
##     (GDD #34 §F, AC-34-08). Same source the foreground path uses, so offline
##     and foreground agree by construction (ADR-0021).
##   - [member final_tick]: int — absolute tick of the last event in this batch.
##     Equals [code]snapshot.dispatched_at_tick + tick_budget[/code] when the
##     batch consumes the full budget.
##
## Equality contract: [method equals] does field-by-field comparison with
## [method dict_equals] for Dictionaries (TR-combat-016 — hash-based equality
## is forbidden for correctness; key-by-key walk is required). All scalar
## fields are int/bool, so they compare exactly (no float tolerance needed
## since the Phase-1 hp_bonus_factor field was removed — ADR-0021).
##
## ADR-0010: Combat Resolver Snapshot + Parity (CombatBatchResult schema)
class_name CombatBatchResult extends RefCounted

## Count of kills per archetype across the batch.
var kills_by_archetype: Dictionary = {}

## Count of kills per tier (1, 2, 3) across the batch.
var kills_by_tier: Dictionary = {}

## Number of complete enemy_list rotations finished in the batch.
var loops_completed: int = 0

## Absolute tick of the first floor-clear within the batch; -1 if none.
var first_clear_tick: int = -1

## Run verdict from the two-sided HP race (GDD #34 §D). Defaults true; false
## means the party was defeated before the floor cleared → loot forfeited.
var won: bool = true

## Absolute tick of the last event in this batch.
var final_tick: int = 0


## Field-by-field equality with TR-016 dict_equals (NOT hash-based) and
## TR-017 is_equal_approx for floats.
##
## TR-combat-013 / TR-combat-015 / TR-combat-016 / TR-combat-017 — ADR-0010
func equals(other: CombatBatchResult) -> bool:
	if other == null:
		return false
	if loops_completed != other.loops_completed:
		return false
	if first_clear_tick != other.first_clear_tick:
		return false
	if won != other.won:
		return false
	if final_tick != other.final_tick:
		return false
	if not dict_equals(kills_by_archetype, other.kills_by_archetype):
		return false
	if not dict_equals(kills_by_tier, other.kills_by_tier):
		return false
	return true


## Key-by-key dictionary equality walk. TR-combat-016 forbids hash-based
## equality (Godot's [code]==[/code] on Dictionary uses internal hash
## comparison which can produce unexpected non-equality for structurally-
## equal but differently-ordered dicts). Walk both key sets and compare
## values pair-wise.
##
## Static so the helper is callable from test code without instantiating
## CombatBatchResult.
##
## TR-combat-016 — ADR-0010
static func dict_equals(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k: Variant in a:
		if not b.has(k):
			return false
		if a[k] != b[k]:
			return false
	return true
