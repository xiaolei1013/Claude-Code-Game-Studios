# FormationAssignment — Sprint 12 Story 1 / Sprint 11 S11-X9 implementation.
#
# Per design/gdd/formation-assignment-system.md §C.1: a thin controller that
# translates UI-side browse + commit intents into HeroRoster mutations + signal
# emissions. Owns NO persistent state in MVP — formation state lives in
# HeroRoster._formation_slots. Save consumer surface is empty per §C.6 +
# Save/Load Rule 10 deferral.
#
# ADR-0003 rank 11 (between FloorUnlock rank 10 and rank 14
# DungeonRunOrchestrator). ADR-0001 mid-run reassignment policy is owned by
# DungeonRunOrchestrator's _on_formation_reassigned handler — this system only
# fires the signal at the right time with the right payload.
extends Node


# ---------------------------------------------------------------------------
# Signals — per formation-assignment-system.md §C.1 declaration block
# ---------------------------------------------------------------------------

## Read-intent informational signal. Fires from [method browse]. The
## DungeonRunOrchestrator IGNORES this signal per
## design/gdd/dungeon-run-orchestrator.md §C.7. UI consumers (Roster Detail
## Screen, Class Detail Screen) may subscribe for "player is looking at their
## formation" hooks.
##
## formation-assignment-system.md §C.1 line 93.
signal formation_browse_opened(formation: Array[HeroInstance])

## Write-intent signal. Fires from [method commit] AFTER the HeroRoster
## mutation has been written. Subscribers that act on formation changes
## (DungeonRunOrchestrator per ADR-0001, Economy for formation_strength
## recompute, etc.) connect here.
##
## Order of operations within commit():
##   1. Validate new_formation length.
##   2. Write to HeroRoster.set_formation_slot() per slot index.
##   3. Emit this signal AFTER all writes complete.
##
## This ordering guarantees subscribers see HeroRoster in its post-mutation
## state when their handlers fire (load-bearing for ADR-0001's
## end-run-restart-with-new-formation flow).
##
## formation-assignment-system.md §C.1 line 105 + §D commit ordering invariant.
signal formation_reassignment_committed(new_formation: Array[HeroInstance])


# ---------------------------------------------------------------------------
# Public API — per formation-assignment-system.md §C.1
# ---------------------------------------------------------------------------

## Called by the Formation Assignment Screen on screen-open. Emits the
## informational signal so the Orchestrator (which ignores it) and any other
## subscribers that want a "browse intent" hook can react. Does NOT mutate
## HeroRoster._formation_slots.
##
## Idempotent: calling browse twice in a row is fine — both calls emit.
##
## [param formation]: Array[HeroInstance] of the heroes currently displayed
##   in the formation slots (matches HeroRoster.get_formation_heroes()).
##   Provided for subscriber convenience; the signal payload mirrors it.
##
## formation-assignment-system.md §C.1 line 53.
func browse(formation: Array[HeroInstance]) -> void:
	formation_browse_opened.emit(formation)


## Called by the Formation Assignment Screen on confirmed player intent
## (commit-button press, NOT panel open). Writes to HeroRoster via
## set_formation_slot() AND emits the write-intent signal. The signal-emit
## site is the single point where formation_reassignment_committed fires —
## no other code path emits it.
##
## Per ADR-0001: when the Orchestrator state is ACTIVE_FOREGROUND or
## OFFLINE_REPLAY, this signal triggers run-end + restart with the new
## formation. The screen's confirm dialog (gated by
## MID_RUN_REASSIGN_WARNING_ENABLED) fires BEFORE this method is called;
## cancellation simply does not call commit().
##
## [param new_formation]: Array[HeroInstance] of the new formation slot
##   contents. Order matters: index 0 is slot 0, index 1 is slot 1, etc.
##   Empty slots are represented by null HeroInstance entries.
##
## Validates the new_formation array length against HeroRoster.formation_size()
## (= 3 in MVP) before writing. Mismatch → push_error + no signal emit.
##
## formation-assignment-system.md §C.1 line 65 + §D commit ordering invariant.
func commit(new_formation: Array[HeroInstance]) -> void:
	# Step 1: validate new_formation length against HeroRoster.formation_size().
	var roster: Node = get_node_or_null("/root/HeroRoster")
	if roster == null:
		push_error("FormationAssignment.commit: /root/HeroRoster not present — cannot validate or write")
		return
	var formation_size: int = int(roster.call("formation_size"))
	if new_formation.size() != formation_size:
		push_error(
			"FormationAssignment.commit: new_formation size %d != formation_size %d — no write, no emit"
			% [new_formation.size(), formation_size]
		)
		return

	# Step 2: write to HeroRoster.set_formation_slot per slot index.
	# Single-writer enforcement per §C.5: this is the ONLY production caller
	# of HeroRoster.set_formation_slot outside HeroRoster's own internal use.
	for slot_index: int in range(formation_size):
		var hero: HeroInstance = new_formation[slot_index]
		var hero_id: int = 0  # 0 = empty slot per HeroRoster._formation_slots convention
		if hero != null:
			hero_id = hero.instance_id
		roster.call("set_formation_slot", slot_index, hero_id)

	# Step 3: emit the write-intent signal AFTER all writes complete.
	# Subscribers see HeroRoster in its post-mutation state.
	formation_reassignment_committed.emit(new_formation)


# ---------------------------------------------------------------------------
# Save/Load consumer surface — empty in MVP per Rule 10 deferral
# ---------------------------------------------------------------------------

## MVP: empty payload. Formation state is persisted by HeroRoster per its
## §C Rule 10 (the formation slots are co-located with the hero list inside
## Roster's save namespace). FormationAssignment's save namespace is reserved
## for V1.0 features (named formation presets, formation-history undo).
##
## Returning {} satisfies the Save/Load consumer contract surface without
## persisting any state.
##
## formation-assignment-system.md §C.6 + §C.1 line 118.
func get_save_data() -> Dictionary:
	return {}


## MVP: no-op. No state to hydrate. V1.0 fills this in alongside named-preset
## persistence.
##
## formation-assignment-system.md §C.6 + §C.1 line 122.
func load_save_data(_d: Dictionary) -> void:
	pass


# ---------------------------------------------------------------------------
# Sprint 15 S15-N1 — Matchup Assignment Screen #23 set_target / get_target
# accessor pair.
#
# The Matchup Assignment Screen (#23) is a sub-screen of formation_assignment
# that lets the player browse biomes + select a floor. It pushes the
# selection back via this autoload's set_target setter; formation_assignment
# screen reads via get_target on its own on_enter to update the hard-coded
# Sprint-8-VS biome+floor fields per Matchup Assignment GDD §C.5.
#
# The selection is session-only — NOT persisted via get_save_data. The
# formation_assignment screen's hard-coded fields (forest_reach floor 1)
# are the cold-launch fallback. Every successful matchup-assignment
# selection writes a new target here; every dispatch that completes
# resets the target to the "current default" (the hard-coded fallback)
# on RUN_ENDED — but that reset is the screen's responsibility, not this
# autoload's. This autoload simply stores whatever was last set.
# ---------------------------------------------------------------------------

## Last Matchup-Assignment-Screen target written via [method set_target].
## Empty Dictionary [code]{}[/code] when no target has been written this
## session. Schema (when populated):
##   - [code]biome_id[/code]: String
##   - [code]floor_index[/code]: int (1-5 in MVP)
##
## Read by [method get_target] (returns deep copy). Read by
## formation_assignment screen on its on_enter to update its display.
##
## NOT persisted in [method get_save_data] — session-only. Cold-launch
## reads {} → formation_assignment falls back to its hard-coded
## (forest_reach, 1) defaults.
##
## Sprint 15 S15-N1 — Matchup Assignment Screen #23 OQ-23-4 dependency.
var _matchup_target: Dictionary = {}


## Sets the active matchup-assignment target — the (biome_id, floor_index)
## pair the player just selected on the Matchup Assignment Screen (#23).
## Subsequent calls overwrite the prior value; no validation is performed
## here (the screen is responsible for ensuring the floor is unlocked +
## the biome exists per `floor_unlock_system.md` + `biome_dungeon_database.md`).
##
## Empty / null biome_id is rejected with push_warning (defensive against
## screen-side bugs); floor_index < 1 is rejected similarly.
##
## Matchup Assignment Screen GDD #23 §C.5 + §F (selection sink).
##
## Sprint 15 S15-N1.
func set_target(biome_id: String, floor_index: int) -> void:
	if biome_id == "":
		push_warning(
			"[FormationAssignment] set_target: empty biome_id rejected; target unchanged"
		)
		return
	if floor_index < 1:
		push_warning(
			"[FormationAssignment] set_target: floor_index %d < 1 rejected; target unchanged"
			% floor_index
		)
		return
	_matchup_target = {
		"biome_id": biome_id,
		"floor_index": floor_index,
	}


## Returns a deep copy of the currently-set matchup-assignment target.
## Returns an empty Dictionary [code]{}[/code] when no target has been
## written this session — formation_assignment screen treats this as
## "use hard-coded fallback (forest_reach, 1)" per Matchup Assignment
## GDD #23 §C.5 step 3.
##
## Returns a deep copy so callers can mutate the result without
## contaminating the cached target.
##
## Sprint 15 S15-N1.
func get_target() -> Dictionary:
	return _matchup_target.duplicate(true)
