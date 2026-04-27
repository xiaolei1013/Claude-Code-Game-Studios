## CombatTickEvents — output of [CombatResolver.emit_events_in_range].
##
## Three-field RefCounted (no .free() needed). Foreground per-tick emission;
## carries every [KillEvent] that landed in the half-open tick range
## [code](tick_lo, tick_hi][/code] passed to the resolver.
##
## Fields (TR-combat-014):
##   - [member kills]: [code]Array[KillEvent][/code] — every kill in the
##     range, ordered by [code]kill_tick[/code] ascending. Empty when no
##     enemies died in the range.
##   - [member loop_completed_ticks]: [code]Array[int][/code] — ticks at
##     which a complete enemy_list rotation finished. The orchestrator uses
##     these to advance [code]loops_executed[/code] and to drive boss-spawn
##     events per loop boundary.
##   - [member first_clear_in_range]: true iff a floor-clear lands inside
##     this window. Combat reports a marker per call; orchestrator owns the
##     once-per-dispatch idempotency flag (TR-018) — combat is stateless.
##
## Equality contract: [method equals] does field-by-field deep comparison.
## [code]Array[KillEvent][/code] equality walks element-by-element via
## [method KillEvent.equals] (NOT `==` — RefCounted ref-equality is wrong
## for parity tests).
##
## ADR-0010: Combat Resolver Snapshot + Parity (CombatTickEvents schema)
class_name CombatTickEvents extends RefCounted

## All kills in this tick range, ordered by kill_tick ascending.
var kills: Array[KillEvent] = []

## Ticks at which a complete enemy_list rotation finished within this range.
var loop_completed_ticks: Array[int] = []

## True iff a floor-clear marker landed inside this range. Orchestrator owns
## the once-per-dispatch idempotency flag (TR-018); combat is stateless and
## reports the marker every call where it occurs.
var first_clear_in_range: bool = false


## Field-by-field equality. Walks [member kills] element-by-element via
## [method KillEvent.equals] (RefCounted [code]==[/code] is reference-equality;
## structurally-equal events from separate calls would otherwise compare unequal).
##
## TR-combat-013 / TR-combat-014 — ADR-0010
func equals(other: CombatTickEvents) -> bool:
	if other == null:
		return false
	if first_clear_in_range != other.first_clear_in_range:
		return false
	if loop_completed_ticks != other.loop_completed_ticks:
		return false  # Array[int] == is structural in GDScript 4
	if kills.size() != other.kills.size():
		return false
	for i: int in range(kills.size()):
		if not kills[i].equals(other.kills[i]):
			return false
	return true
