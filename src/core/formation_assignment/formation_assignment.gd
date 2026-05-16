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

## Class Synergy V1.0 first-pass (Sprint 21 S21-S2 / Story 3) — live-preview
## signal fired when a synergy is detected on a formation slot edit.
##
## Per `class-synergy-system.md` §C.4 audio integration: AudioRouter subscribes
## and fires `sfx_class_synergy_detected` (warm chime) with a ≥2.0s throttle
## (per audio-system.md §F suppress_window pattern). The throttle prevents
## rapid slot-toggling spam.
##
## EMITTED BY: [method notify_synergy_detected] — called from the
## formation_assignment screen's live-preview path (Story 4 wires the screen
## integration). The pure [method detect_active_synergy] does NOT emit
## (kept side-effect-free per AC-CS-20 perf assumption).
##
## [param synergy_id]: the detected synergy id String — one of "steel_wall",
##   "arcane_elite", "triple_threat" (V1.0 first-pass roster). Empty string
##   "" is NOT emitted — callers gate on a non-empty detection result.
##
## design/gdd/class-synergy-system.md §C.4 + AC-CS-14 + AC-CS-15.
@warning_ignore("unused_signal")
signal class_synergy_detected_signal(synergy_id: String)


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
	# Single-writer enforcement per §C.5. AC-FA-08: abort on first
	# set_formation_slot false return (unknown hero_id); leaves HeroRoster
	# in a partial-write state for the screen to re-query.
	for slot_index: int in range(formation_size):
		var hero: HeroInstance = new_formation[slot_index]
		var hero_id: int = 0  # 0 = empty slot per HeroRoster._formation_slots convention
		if hero != null:
			hero_id = hero.instance_id
		var ok: bool = roster.call("set_formation_slot", slot_index, hero_id)
		if not ok:
			push_error(
				"FormationAssignment.commit: set_formation_slot rejected slot %d hero_id %d — aborting; no further writes; no signal emit"
				% [slot_index, hero_id]
			)
			return

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


# ---------------------------------------------------------------------------
# Class Synergy V1.0 first-pass — Sprint 21 S21-M1 (Story 1) implementation.
#
# Per design/gdd/class-synergy-system.md §C.1 + §D.1: detection is a pure
# function over the multiset of class_id strings in the formation. Returns
# the active synergy id String, or "" if no synergy matches OR any slot
# is empty (no partial-synergy detection in V1.0 first-pass).
#
# Three V1.0 first-pass synergies:
#   - "steel_wall"     : 3 Warriors  → ×1.25 kill gold vs bruisers (cond.)
#   - "arcane_elite"   : 3 Mages     → ×1.20 kill XP unconditional
#   - "triple_threat"  : 1W+1M+1R    → ×1.15 kill gold unconditional
# ---------------------------------------------------------------------------

## V1.0 first-pass synergy id constants. Stable strings for the synergy
## resolver switch (per `class-synergy-system.md` §D.2/D.3) + RunSnapshot.
## V1.5+ may extend the synergy roster; the resolver returns 1.0 for
## unknown synergy_ids per AC-CS-18 forward-compat.
const SYNERGY_STEEL_WALL: String = "steel_wall"
const SYNERGY_ARCANE_ELITE: String = "arcane_elite"
const SYNERGY_TRIPLE_STRIKE: String = "triple_strike"
const SYNERGY_TRIPLE_THREAT: String = "triple_threat"
# Tier-2 class synergies — mono-class 3-of-a-kind for each tier-2 class.
# Structurally parallel to the V1 mono-class set (Steel Wall / Arcane Elite
# / Triple Strike): conditional gold vs counter archetype for combat-shape
# classes; XP boost for the support shape.
const SYNERGY_BASTION: String = "bastion"  # 3 paladins, conditional gold vs caster
const SYNERGY_VOLLEY: String = "volley"    # 3 archers, conditional gold vs swarm
const SYNERGY_FRENZY: String = "frenzy"    # 3 berserkers, conditional gold vs bruiser
const SYNERGY_VIGIL: String = "vigil"      # 3 clerics, unconditional XP (support investment)


## Detects which V1.0 first-pass class synergy is active for a given formation
## composition. Returns the synergy id String, or [code]""[/code] if no
## synergy matches OR any slot is empty.
##
## Per `class-synergy-system.md` §C.1 + §D.1: pure function over the multiset
## of class_id strings. Order of slots does NOT matter (sort-based comparison).
## No partial-synergy detection — all 3 slots must be filled. No tier or level
## consideration — only class_id composition.
##
## [param formation_snapshot]: a Dictionary with the same shape as
## [code]RunSnapshot.formation_snapshot[/code] — either
## [code]{ "heroes": Array[Dictionary] }[/code] (each hero dict has
## [code]class_id[/code]) OR [code]{ "instance_ids": Array[int] }[/code]
## (resolved via [code]/root/HeroRoster.get_hero[/code]).
##
## When [code]heroes[/code] is present + non-empty, that path wins (avoids
## the autoload lookup; cleaner test path). Otherwise [code]instance_ids[/code]
## resolves through HeroRoster.
##
## Returns [code]""[/code] under any of:
##   - formation_snapshot is missing both keys
##   - resolved class_ids count != 3 (FORMATION_SIZE per `hero-roster.md`)
##   - any slot is empty (instance_id == 0 in instance_ids path; missing
##     class_id in heroes path)
##   - any HeroRoster lookup returns null (unresolvable instance_id)
##   - the sorted class_ids multiset doesn't match any V1.0 synergy
##
## Idempotent: safe to call every slot edit (no signal emit, no state
## change). O(1) — sort + 3 comparisons.
##
## Per AC-CS-01..05 detection accuracy. AC-CS-20 perf budget <1ms p99.
##
## design/gdd/class-synergy-system.md §C.1 + §D.1 + AC-CS-01..05.
func detect_active_synergy(formation_snapshot: Dictionary) -> String:
	var class_ids: Array[String] = []

	# Path 1: heroes Array[Dictionary] (test-friendly; no autoload dep).
	var heroes_v: Variant = formation_snapshot.get("heroes", [])
	if heroes_v is Array and not (heroes_v as Array).is_empty():
		for hero_v: Variant in (heroes_v as Array):
			if not (hero_v is Dictionary):
				return ""
			var hero_dict: Dictionary = hero_v as Dictionary
			var cid: String = String(hero_dict.get("class_id", ""))
			if cid == "":
				return ""
			class_ids.append(cid)
	else:
		# Path 2: instance_ids Array[int] resolved via HeroRoster autoload.
		# Builds an instance_id → HeroInstance lookup map from
		# [code]get_all_heroes()[/code] (HeroRoster has no single-hero-by-id
		# getter; the lookup-map idiom is the canonical pattern, also used
		# by [DungeonRunOrchestrator.snapshot_formation_for_run] and the
		# formation_assignment screen's _refresh helpers).
		var ids_v: Variant = formation_snapshot.get("instance_ids", [])
		if not (ids_v is Array):
			return ""
		var ids: Array = ids_v as Array
		if ids.is_empty():
			return ""
		var roster: Node = get_node_or_null("/root/HeroRoster")
		if roster == null or not roster.has_method("get_all_heroes"):
			return ""
		var hero_map: Dictionary = {}
		for hero_v: Variant in roster.call("get_all_heroes"):
			# HeroInstance is RefCounted with instance_id + class_id fields.
			# Object.get works for property access on RefCounted instances.
			hero_map[int(hero_v.get("instance_id"))] = hero_v
		for instance_id_v: Variant in ids:
			var instance_id: int = int(instance_id_v)
			if instance_id == 0:
				return ""
			if not hero_map.has(instance_id):
				return ""
			var hero: Object = hero_map[instance_id]
			var cid_v: Variant = hero.get("class_id")
			if not (cid_v is String):
				return ""
			var cid: String = cid_v as String
			if cid == "":
				return ""
			class_ids.append(cid)

	# FORMATION_SIZE guard (must be exactly 3 per hero-roster.md §C.10).
	if class_ids.size() != 3:
		return ""

	class_ids.sort()  # Canonical multiset comparison.

	# Match against V1.0 first-pass synergy roster. Order of comparisons
	# matters only for readability — each pattern is mutually exclusive
	# under the sorted-multiset comparison.
	var sorted_warrior: Array[String] = ["warrior", "warrior", "warrior"]
	if class_ids == sorted_warrior:
		return SYNERGY_STEEL_WALL
	var sorted_mage: Array[String] = ["mage", "mage", "mage"]
	if class_ids == sorted_mage:
		return SYNERGY_ARCANE_ELITE
	# Triple Strike: 3 Rogues. Added in the 2026-05-14 GDD re-review to close
	# the 3-Rogue asymmetric-class-treatment gap; structurally parallel to
	# Steel Wall (×1.25 gold, conditional on archetype counter — armored for
	# Rogue per assets/data/classes/rogue.tres counter_archetype).
	var sorted_rogue: Array[String] = ["rogue", "rogue", "rogue"]
	if class_ids == sorted_rogue:
		return SYNERGY_TRIPLE_STRIKE
	# Triple Threat: 1 Warrior + 1 Mage + 1 Rogue. Sorted alphabetically:
	# ["mage", "rogue", "warrior"].
	var sorted_mix: Array[String] = ["mage", "rogue", "warrior"]
	if class_ids == sorted_mix:
		return SYNERGY_TRIPLE_THREAT

	# Tier-2 mono-class synergies. Same sorted-multiset comparison shape
	# as the V1 mono-class set above.
	var sorted_paladin: Array[String] = ["paladin", "paladin", "paladin"]
	if class_ids == sorted_paladin:
		return SYNERGY_BASTION
	var sorted_archer: Array[String] = ["archer", "archer", "archer"]
	if class_ids == sorted_archer:
		return SYNERGY_VOLLEY
	var sorted_berserker: Array[String] = ["berserker", "berserker", "berserker"]
	if class_ids == sorted_berserker:
		return SYNERGY_FRENZY
	var sorted_cleric: Array[String] = ["cleric", "cleric", "cleric"]
	if class_ids == sorted_cleric:
		return SYNERGY_VIGIL

	# No synergy matches (e.g., 2W+1M, 2W+1R, 2M+1R — V1.0 first-pass does
	# not include 2+1 mixes; V1.5+ may extend).
	return ""


## Class Synergy V1.0 (Sprint 21 S21-S2 / Story 3) — public emit surface
## for the live-preview signal.
##
## Called by the formation_assignment screen's slot-edit path (Story 4)
## after computing the active synergy via [method detect_active_synergy].
## Emits [signal class_synergy_detected_signal] only when [param synergy_id]
## is non-empty. AudioRouter subscribes for the cozy chime cue with a 2.0s
## throttle (per audio-system.md §F + AC-CS-14).
##
## Idempotent: calling with [code]synergy_id == ""[/code] is a no-op (no
## signal emit). The screen's live-preview path can call this on every
## slot edit without conditional gating; the no-op makes empty-formation
## edits cheap.
##
## design/gdd/class-synergy-system.md §C.4 + AC-CS-14.
func notify_synergy_detected(synergy_id: String) -> void:
	if synergy_id == "":
		return
	class_synergy_detected_signal.emit(synergy_id)
