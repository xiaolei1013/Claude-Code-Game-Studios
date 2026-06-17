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


## Formation Presets V1.0 (formation-presets.md §C.5) — fired AFTER a new preset
## is appended via [method save_preset]. UI subscribes to refresh the preset
## dropdown. [param preset_id] is the new monotonic id (never reused);
## [param preset_name] is the stored, post-truncation name.
##
## design/gdd/formation-presets.md §C.5 step 6 + AC-FP-02.
@warning_ignore("unused_signal")
signal preset_saved(preset_id: int, preset_name: String)

## Formation Presets V1.0 (formation-presets.md §C.4) — fired AFTER a preset is
## resolved into a positional formation via [method recall_preset]. Recall does
## NOT mutate HeroRoster (AC-FP-04); this signal carries the resolved formation
## for the screen's edit buffer. [param formation] is a positional Array of
## length formation_size(); each entry is a HeroInstance or null (empty slot or
## a hero removed since the preset was saved).
##
## design/gdd/formation-presets.md §C.4 + AC-FP-04 + §J Story 4.
@warning_ignore("unused_signal")
signal preset_recalled(preset_id: int, formation: Array)

## Formation Presets V1.0 (formation-presets.md §C.6) — fired AFTER a preset is
## removed via [method delete_preset]. UI subscribes to refresh the dropdown +
## reset its selection to "(none)".
##
## design/gdd/formation-presets.md §C.6 step 3 + AC-FP-06.
@warning_ignore("unused_signal")
signal preset_deleted(preset_id: int)


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
# Save/Load consumer surface — Formation Presets V1.0 (formation-presets.md)
# ---------------------------------------------------------------------------

## Serializes named formation presets for the Save/Load envelope.
##
## Live formation SLOTS remain owned by HeroRoster (its §C Rule 10); this
## namespace persists only the V1.0 preset list + the monotonic id counter.
## The live current formation is NOT duplicated here.
##
## Returns a JSON-safe dictionary:
## [codeblock]
## {
##   "presets": [
##     {"id": 1, "name": "Fire Team", "created_at_unix": 0, "slot_hero_ids": [12, 0, 7]},
##     ...
##   ],
##   "next_preset_id": 4,
## }
## [/codeblock]
##
## Each preset is deep-copied so external mutation of the returned dict cannot
## corrupt internal state. [code]slot_hero_ids[/code] entries are HeroInstance
## ids or the 0 empty-slot sentinel.
##
## design/gdd/formation-presets.md §C.1 (schema) + §C.7 (persistence) + AC-FP-01.
func get_save_data() -> Dictionary:
	var presets_out: Array = []
	for p: Dictionary in _presets:
		presets_out.append({
			"id": int(p.get("id", 0)),
			"name": String(p.get("name", "")),
			"created_at_unix": int(p.get("created_at_unix", 0)),
			"slot_hero_ids": (p.get("slot_hero_ids", []) as Array).duplicate(),
		})
	return {
		"presets": presets_out,
		"next_preset_id": _next_preset_id,
	}


## Hydrates named formation presets from a Save/Load payload.
##
## Defensive against three real hazards:
##   1. [b]Pre-V1.0 saves[/b] (AC-FP-09): missing keys → empty preset list +
##      [code]next_preset_id = 1[/code]. No migration step required; the absent
##      namespace simply hydrates to defaults.
##   2. [b]JSON int→float round-trip[/b]: [JSON] returns every number as
##      TYPE_FLOAT, so every id / slot id / timestamp is [code]int()[/code]-cast
##      and reads accept both TYPE_INT and TYPE_FLOAT.
##   3. [b]Slot-count drift[/b] (AC-FP-10): a preset whose [code]slot_hero_ids[/code]
##      length != [code]formation_size()[/code] (e.g. saved when the formation was
##      a different size) is discarded with a single push_warning — never loaded
##      into a malformed state.
##
## [code]next_preset_id[/code] is restored to [code]max(persisted, highest loaded
## id + 1)[/code] so the monotonic-never-reused invariant (AC-FP-08) survives even
## a hand-edited or partially-corrupt save.
##
## design/gdd/formation-presets.md §C.7 + AC-FP-08 + AC-FP-09 + AC-FP-10.
func load_save_data(d: Dictionary) -> void:
	# Reset to pre-V1.0 defaults first; a missing/empty namespace stays here.
	_presets = []
	_next_preset_id = 1
	if d == null or d.is_empty():
		return

	var size: int = _formation_size()
	var highest_loaded_id: int = 0

	var raw_presets_v: Variant = d.get("presets", [])
	if raw_presets_v is Array:
		for entry_v: Variant in (raw_presets_v as Array):
			if not (entry_v is Dictionary):
				continue
			var entry: Dictionary = entry_v as Dictionary

			# slot_hero_ids — int()-cast each element (JSON floats), guard non-Array.
			var raw_slots_v: Variant = entry.get("slot_hero_ids", [])
			if not (raw_slots_v is Array):
				push_warning(
					"[FormationAssignment] load_save_data: preset id %s has non-Array slot_hero_ids; discarded"
					% str(entry.get("id", "?"))
				)
				continue
			var slots: Array[int] = []
			for s_v: Variant in (raw_slots_v as Array):
				slots.append(int(s_v) if (s_v is int or s_v is float) else 0)

			# AC-FP-10: discard presets whose slot count drifted from formation_size().
			if slots.size() != size:
				push_warning(
					"[FormationAssignment] load_save_data: discarding preset '%s' (id %s): slot_hero_ids length %d != formation_size %d"
					% [str(entry.get("name", "?")), str(entry.get("id", "?")), slots.size(), size]
				)
				continue

			var pid: int = int(entry.get("id", 0)) if _is_number(entry.get("id", 0)) else 0
			var name_v: Variant = entry.get("name", "")
			var pname: String = String(name_v) if name_v is String else ""
			var created_v: Variant = entry.get("created_at_unix", 0)
			var created: int = int(created_v) if _is_number(created_v) else 0

			_presets.append({
				"id": pid,
				"name": pname,
				"created_at_unix": created,
				"slot_hero_ids": slots,
			})
			if pid > highest_loaded_id:
				highest_loaded_id = pid

	# Restore the monotonic counter; never below highest loaded id + 1, never < 1.
	var raw_next_v: Variant = d.get("next_preset_id", 0)
	var next_from_save: int = int(raw_next_v) if _is_number(raw_next_v) else 0
	_next_preset_id = maxi(maxi(next_from_save, highest_loaded_id + 1), 1)


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


# ===========================================================================
# Formation Presets V1.0 (design/gdd/formation-presets.md, GDD #33)
#
# Lets the player save / name / recall up to MAX_PRESETS_PER_PLAYER 3-slot
# formation lineups. This autoload owns the preset DATA + persistence; the
# PresetsRow UI (separate story) drives it through the public API below.
#
# Encapsulation contract (AC-FP-12): _presets and _next_preset_id are private.
# All access goes through save_preset / recall_preset / delete_preset /
# get_presets — enforced by formation_presets_encapsulation_ci_grep_test.gd.
# ===========================================================================

## DataRegistry category + id for the tuning-knob resource (ADR-0006 boot-scan).
const _CONFIG_CATEGORY: String = "config"
const _CONFIG_ID: String = "formation_presets_config"

## Safe defaults used when DataRegistry resolution fails (e.g. early-sprint
## ERROR state, or the .tres is missing). MUST mirror
## assets/data/config/formation_presets_config.tres so behaviour is identical
## whether the config resolves or not. design/gdd/formation-presets.md §G.
const _FALLBACK_MAX_PRESETS_PER_PLAYER: int = 6
const _FALLBACK_PRESET_NAME_MAX_LENGTH: int = 32
const _FALLBACK_RECALL_MISSING_HERO_TOAST_CAP: int = 3
const _FALLBACK_DELETE_CONFIRMATION_DEFAULT_FOCUS: String = "cancel"

## Last-resort formation size used only when HeroRoster is unreachable at
## load time (mirrors HeroRoster._FALLBACK_FORMATION_SIZE). Drives the
## AC-FP-10 slot-count validation.
const _FALLBACK_FORMATION_SIZE: int = 3

## Resolved FormationPresetsConfig (null until _load_config runs / on failure).
var _presets_config: Resource = null

## The saved presets, in insertion order. Each entry is a Dictionary of shape
## {id:int, name:String, created_at_unix:int, slot_hero_ids:Array[int]}.
## PRIVATE — see the encapsulation contract above.
var _presets: Array[Dictionary] = []

## Monotonic id counter. The id of the NEXT preset to be created; never reused,
## never decremented on delete (AC-FP-08). Starts at 1.
var _next_preset_id: int = 1

## Test seam (dependency injection). When set, [method recall_preset] and the
## load-time formation-size check resolve heroes / size through this node
## instead of the live [code]/root/HeroRoster[/code] autoload, so preset tests
## stay isolated from live roster + save state. Production leaves this null.
var _roster_override: Node = null


func _ready() -> void:
	_load_config()


## Resolves the FormationPresetsConfig from DataRegistry. On any failure the
## autoload keeps its [code]_FALLBACK_*[/code] safe defaults (graceful
## degradation per engine-code rules). design/gdd/formation-presets.md §G.
func _load_config() -> void:
	var registry: Node = get_node_or_null("/root/DataRegistry")
	if registry == null or not registry.has_method("resolve"):
		return  # No registry (e.g. isolated test) — keep fallback consts.
	var resolved: Resource = registry.call("resolve", _CONFIG_CATEGORY, _CONFIG_ID)
	_apply_resolved_config(resolved)


## Validates and applies a resolved config resource. Returns true if applied,
## false if rejected (and fallback consts are retained). Mirrors the
## HeroRoster._apply_resolved_config 4-branch guard so behaviour is uniform
## across config consumers. Public-ish so tests can drive the branches with a
## stub resource without booting DataRegistry.
func _apply_resolved_config(resolved: Resource) -> bool:
	# Branch 1: null — DataRegistry miss (ERROR state / absent file). Keep defaults.
	if resolved == null:
		return false
	# Branch 2: wrong schema — duck-type the required knobs before trusting it.
	if not ("MAX_PRESETS_PER_PLAYER" in resolved and "PRESET_NAME_MAX_LENGTH" in resolved):
		push_error(
			"[FormationAssignment] resolved config lacks FormationPresetsConfig schema; using fallback defaults"
		)
		return false
	# Branch 3: present but invalid — run the resource's own _validate().
	if resolved.has_method("_validate"):
		var errors: Array = resolved.call("_validate")
		if not errors.is_empty():
			push_error(
				"[FormationAssignment] FormationPresetsConfig validation failed: %s; using fallback defaults"
				% ", ".join(errors)
			)
			return false
	# Branch 4: valid — adopt it.
	_presets_config = resolved
	return true


# ---------------------------------------------------------------------------
# Config accessors — resolve from _presets_config, fall back to consts.
# ---------------------------------------------------------------------------

## Hard cap on saved presets (formation-presets.md §C.2 + §G).
func max_presets() -> int:
	if _presets_config != null and "MAX_PRESETS_PER_PLAYER" in _presets_config:
		return int(_presets_config.get("MAX_PRESETS_PER_PLAYER"))
	return _FALLBACK_MAX_PRESETS_PER_PLAYER


## Maximum preset-name length in characters (formation-presets.md §C.1 + §G).
func preset_name_max_length() -> int:
	if _presets_config != null and "PRESET_NAME_MAX_LENGTH" in _presets_config:
		return int(_presets_config.get("PRESET_NAME_MAX_LENGTH"))
	return _FALLBACK_PRESET_NAME_MAX_LENGTH


## Cap on missing-hero toasts per recall (formation-presets.md §C.4 + §G).
func recall_missing_hero_toast_cap() -> int:
	if _presets_config != null and "RECALL_MISSING_HERO_TOAST_CAP" in _presets_config:
		return int(_presets_config.get("RECALL_MISSING_HERO_TOAST_CAP"))
	return _FALLBACK_RECALL_MISSING_HERO_TOAST_CAP


## Default-focused button in the delete-confirm modal (formation-presets.md §C.6 + §G).
func delete_confirmation_default_focus() -> String:
	if _presets_config != null and "DELETE_CONFIRMATION_DEFAULT_FOCUS" in _presets_config:
		return String(_presets_config.get("DELETE_CONFIRMATION_DEFAULT_FOCUS"))
	return _FALLBACK_DELETE_CONFIRMATION_DEFAULT_FOCUS


# ---------------------------------------------------------------------------
# Public preset API
# ---------------------------------------------------------------------------

## Saves a new named preset from a formation snapshot.
##
## The caller supplies the snapshot (typically
## [code]HeroRoster.get_formation_slot(i)[/code] for each slot) and an optional
## informational [param created_at_unix] timestamp — keeping this method pure
## and deterministic for tests (no wall-clock read inside).
##
## Validation (formation-presets.md §C.5):
##   - [param preset_name] is stripped; an empty result is REJECTED → returns 0.
##   - A name longer than [method preset_name_max_length] is TRUNCATED (not
##     rejected) to that many characters, then saved.
##   - If the preset count is already at [method max_presets], the save is
##     REJECTED → returns 0 (no silent overwrite, no auto-rotation).
##
## On success: appends the preset, advances the monotonic id counter, emits
## [signal preset_saved], and returns the new id (always > 0).
##
## [b]Example[/b]
## [codeblock]
## var slots: Array[int] = [roster.get_formation_slot(0), roster.get_formation_slot(1), roster.get_formation_slot(2)]
## var id := fa.save_preset("Fire Team", slots)
## if id == 0:
##     show_toast("Couldn't save — name empty or preset list full")
## [/codeblock]
##
## design/gdd/formation-presets.md §C.5 + AC-FP-02 + AC-FP-03 + AC-FP-08.
func save_preset(preset_name: String, slot_hero_ids: Array[int], created_at_unix: int = 0) -> int:
	# §C.5 step 1: validate name. Empty (after strip) → reject.
	var clean_name: String = preset_name.strip_edges()
	if clean_name == "":
		push_warning("[FormationAssignment] save_preset: empty name rejected; no preset saved")
		return 0
	# Over max length → truncate (char-accurate; Godot String is UTF-32 internally).
	var max_len: int = preset_name_max_length()
	if clean_name.length() > max_len:
		clean_name = clean_name.substr(0, max_len)

	# §C.5 step 2: validate cap.
	if _presets.size() >= max_presets():
		push_warning(
			"[FormationAssignment] save_preset: preset cap (%d) reached; '%s' not saved"
			% [max_presets(), clean_name]
		)
		return 0

	# §C.5 steps 3-4: copy the snapshot defensively into a typed array.
	var slots_copy: Array[int] = []
	for s: int in slot_hero_ids:
		slots_copy.append(s)

	# §C.5 step 5: construct + append, then advance the monotonic counter.
	var new_id: int = _next_preset_id
	_presets.append({
		"id": new_id,
		"name": clean_name,
		"created_at_unix": created_at_unix,
		"slot_hero_ids": slots_copy,
	})
	_next_preset_id += 1

	# §C.5 step 6: emit.
	preset_saved.emit(new_id, clean_name)
	return new_id


## Resolves a saved preset into a positional formation WITHOUT mutating the
## roster (AC-FP-04). The UI takes the returned array into its edit buffer and
## only writes through [method commit] when the player confirms.
##
## Returns a positional [Array] of length [method _formation_size]; each entry
## is the live [HeroInstance] for that slot's saved id, or [code]null[/code]
## when the slot was empty (the 0 sentinel) or the referenced hero no longer
## exists (dismissed / prestiged since the preset was saved — §J Story 4).
## The UI surfaces a missing-hero toast for the nulls, capped by
## [method recall_missing_hero_toast_cap].
##
## An unknown [param preset_id] returns an empty [Array] (and warns) so the
## caller can no-op gracefully.
##
## design/gdd/formation-presets.md §C.4 + AC-FP-04 + AC-FP-05.
func recall_preset(preset_id: int) -> Array:
	var preset: Dictionary = _find_preset(preset_id)
	if preset.is_empty():
		push_warning(
			"[FormationAssignment] recall_preset: no preset with id %d; returning empty formation"
			% preset_id
		)
		return []

	var roster: Node = _roster()
	var can_resolve: bool = roster != null and roster.has_method("get_hero_by_id")
	var slots: Array = preset.get("slot_hero_ids", []) as Array
	var formation: Array = []  # positional; HeroInstance or null per slot
	for slot_id_v: Variant in slots:
		var slot_id: int = int(slot_id_v)
		if slot_id == 0 or not can_resolve:
			formation.append(null)
			continue
		# get_hero_by_id returns the HeroInstance, or null if it no longer exists.
		formation.append(roster.call("get_hero_by_id", slot_id))

	# AC-FP-04: NO roster write here — recall only populates the edit buffer.
	preset_recalled.emit(preset_id, formation)
	return formation


## Deletes the preset with [param preset_id]. Returns true if one was removed,
## false if no preset had that id.
##
## Per §C.6 the monotonic [member _next_preset_id] is NOT decremented — ids are
## never reused, so a later save still gets a fresh id (AC-FP-08). Emits
## [signal preset_deleted] on success.
##
## design/gdd/formation-presets.md §C.6 + AC-FP-06 + AC-FP-08.
func delete_preset(preset_id: int) -> bool:
	for i: int in range(_presets.size()):
		if int(_presets[i].get("id", 0)) == preset_id:
			_presets.remove_at(i)
			preset_deleted.emit(preset_id)
			return true
	push_warning("[FormationAssignment] delete_preset: no preset with id %d" % preset_id)
	return false


## Returns a deep copy of all presets in insertion order, so callers can read
## (and freely mutate their copy) without touching internal state — the
## encapsulation contract (AC-FP-12). Each entry mirrors the §C.1 schema.
##
## design/gdd/formation-presets.md §C.1 + AC-FP-12.
func get_presets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in _presets:
		out.append({
			"id": int(p.get("id", 0)),
			"name": String(p.get("name", "")),
			"created_at_unix": int(p.get("created_at_unix", 0)),
			"slot_hero_ids": (p.get("slot_hero_ids", []) as Array).duplicate(),
		})
	return out


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Returns the stored preset dict for [param preset_id], or an empty dict if
## none matches. Returns the LIVE internal dict (not a copy) — callers within
## this file must not leak it past their scope.
func _find_preset(preset_id: int) -> Dictionary:
	for p: Dictionary in _presets:
		if int(p.get("id", 0)) == preset_id:
			return p
	return {}


## Current formation size, resolved from HeroRoster (or the test seam), falling
## back to [constant _FALLBACK_FORMATION_SIZE] when the roster is unreachable
## (e.g. load_save_data running in an isolated test before a roster exists).
func _formation_size() -> int:
	var roster: Node = _roster()
	if roster != null and roster.has_method("formation_size"):
		return int(roster.call("formation_size"))
	return _FALLBACK_FORMATION_SIZE


## Resolves the HeroRoster node — the injected [member _roster_override] when
## set (tests), else the live [code]/root/HeroRoster[/code] autoload.
func _roster() -> Node:
	if _roster_override != null:
		return _roster_override
	return get_node_or_null("/root/HeroRoster")


## True when [param v] is a JSON-safe number (TYPE_INT or TYPE_FLOAT). Used to
## guard [code]int()[/code] casts on untyped save-dict reads — a present-but-null
## value would otherwise crash the cast (project memory: dict-get null passthrough).
func _is_number(v: Variant) -> bool:
	return v is int or v is float
