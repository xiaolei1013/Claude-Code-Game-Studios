## CombatRunOutcome — the WIN / DEFEAT verdict for a single dungeon run.
##
## Produced by [method DefaultCombatResolver.compute_run_outcome] from a
## [CombatRunSnapshot]. The SAME method is called by BOTH the foreground
## dispatch path and the offline batch path, so the verdict is identical
## across both — parity by construction (GDD #34 §D, ADR-0021).
##
## The verdict models the two-sided HP race (GDD #34 §D): the party deals
## DPS that kills enemies sequentially (focus-fire) while the still-alive
## enemies deal damage back to the shared party HP pool. Because party HP
## resets each loop (GDD §E.3) and every loop is identical, the run verdict
## equals the single-loop verdict — a party that survives one loop survives
## all loops, and a party that wipes does so in the first loop.
##
## Fields:
##   - [member won]: true → party cleared the floor (survived to the last
##     enemy death); false → party HP reached 0 strictly before the clear.
##   - [member clear_tick]: absolute tick (anchored at
##     [code]snapshot.dispatched_at_tick[/code]) at which a single loop's
##     last enemy dies — the floor-clear instant on a WIN; informational on
##     a DEFEAT (the clear the party did NOT reach).
##   - [member defeat_tick]: absolute tick at which cumulative enemy damage
##     first meets-or-exceeds party HP. [code]-1[/code] when [member won] is
##     true.
##
## RefCounted value type (no .free() needed). Mirrors the [CombatBatchResult]
## idiom: typed fields + an [method equals] for deterministic test assertions.
##
## GDD #34 §D — ADR-0021
class_name CombatRunOutcome
extends RefCounted

## True iff the party cleared the floor before its HP pool reached 0.
var won: bool = true

## Absolute tick (anchored at dispatched_at_tick) of the single-loop floor
## clear. On a WIN this is when the floor clears; on a DEFEAT it is the clear
## the party failed to reach.
var clear_tick: int = 0

## Absolute tick at which cumulative enemy damage first >= party HP. -1 on a WIN.
var defeat_tick: int = -1


## Field-by-field equality for deterministic test assertions.
func equals(other: CombatRunOutcome) -> bool:
	if other == null:
		return false
	return (
		won == other.won
		and clear_tick == other.clear_tick
		and defeat_tick == other.defeat_tick
	)
