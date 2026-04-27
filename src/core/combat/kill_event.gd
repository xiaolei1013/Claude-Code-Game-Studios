## KillEvent — single-enemy kill record emitted by [CombatResolver].
##
## Five-field RefCounted (no .free() needed). Produced by Combat's foreground
## entry point [code]emit_events_in_range[/code] (Story 006); aggregated by
## the offline batch path [code]compute_offline_batch[/code] (Story 007) via
## per-archetype + per-tier dictionaries rather than retained as Array events.
##
## Fields (TR-combat-013):
##   - [member enemy_id]: stable [StringName] from the floor's enemy_list.
##     Identifies the specific enemy instance within the loop schedule.
##   - [member archetype]: [StringName] for matchup-cache lookup. The
##     resolver does NOT recompute matchup per kill — it consults the snapshot's
##     matchup_cache built at DISPATCHING.
##   - [member tier]: int 1..3. Drives Economy's [code]BASE_KILL[tier][/code]
##     gold lookup (the gold value lives in EconomyConfig, not here).
##   - [member is_boss]: true iff this enemy is the floor's boss. Drives the
##     boss-fanfare signal (orchestrator-side; combat just propagates the bit
##     per TR-028, regardless of mid-queue position).
##   - [member kill_tick]: absolute tick the enemy dies at. ALWAYS >= 1 per
##     TR-025 (ceili of base_hp / effective_dps cannot produce tick 0).
##
## Equality contract (TR-combat-013): [method equals] is field-by-field deep
## comparison. RefCounted reference-equality (`==`) is NOT what tests want
## when they need to compare two KillEvent records produced by separate calls.
## Use [method equals] instead of `==` in test assertions.
##
## ADR-0010: Combat Resolver Snapshot + Parity (KillEvent schema)
class_name KillEvent extends RefCounted

## Stable identifier for the enemy instance within the loop schedule.
var enemy_id: StringName = &""

## Enemy archetype — used for matchup-cache lookup at the orchestrator-side
## kill-attribution stage. The resolver does NOT call MatchupResolver per kill.
var archetype: StringName = &""

## Enemy tier (1, 2, or 3). Drives Economy's BASE_KILL[tier] gold lookup.
var tier: int = 1

## True iff this enemy is the floor's boss. Per TR-028, the bit propagates
## regardless of the enemy's position in the kill schedule.
var is_boss: bool = false

## Absolute tick the enemy dies at. ALWAYS >= 1 (TR-025: ceili guarantees
## this floor — no instant-kill tick-0 events).
var kill_tick: int = 0


## Field-by-field equality. RefCounted ref-equality is NOT structural;
## tests must use this method when comparing KillEvent records from separate
## calls (e.g., parity tests comparing foreground vs offline kill streams).
##
## Returns false on null [param other] (defensive against partial parity
## stream lengths during AC-COMBAT-22 verification).
##
## TR-combat-013 — ADR-0010
func equals(other: KillEvent) -> bool:
	if other == null:
		return false
	return (
		enemy_id == other.enemy_id
		and archetype == other.archetype
		and tier == other.tier
		and is_boss == other.is_boss
		and kill_tick == other.kill_tick
	)
