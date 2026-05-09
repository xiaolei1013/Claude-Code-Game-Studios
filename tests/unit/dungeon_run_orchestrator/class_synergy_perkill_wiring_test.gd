# Sprint 21 / Class Synergy V1.0 Story 4 (per-kill wiring) — verifies the
# orchestrator's _process_kill_events loop correctly wires synergy_id from
# RunSnapshot through attribute_kill_gold + the XP multiplier.
#
# This test exercises the SAME loop body as kill_attribution_and_signals_test.gd
# but with run_snapshot.synergy_id set to each V1.0 first-pass synergy id +
# verifies the resulting per-kill outputs honor the synergy multiplier.
#
# Test groups:
#   A — Steel Wall + bruiser kills: gold ×1.25 vs no-synergy baseline
#   B — Triple Threat: gold ×1.15 unconditional (any archetype)
#   C — Arcane Elite: gold unchanged, XP ×1.20 (verified via per-tick output)
#   D — No synergy / unknown synergy: baseline output
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const KillEventScript = preload("res://src/core/combat/kill_event.gd")
const CombatTickEventsScript = preload("res://src/core/combat/combat_tick_events.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")


func _make_orch() -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	return orch


func _make_kill(tier: int, archetype: StringName) -> RefCounted:
	var ke: KillEvent = KillEventScript.new()
	ke.tier = tier
	ke.archetype = archetype
	ke.is_boss = false
	ke.enemy_id = &"e1"
	ke.kill_tick = 1
	return ke


func _make_events(kills: Array[KillEvent]) -> RefCounted:
	var ev: CombatTickEvents = CombatTickEventsScript.new()
	ev.kills = kills
	ev.first_clear_in_range = false
	return ev


func _setup_orch_with_synergy(synergy_id: String, archetype_advantaged: StringName = &"bruiser") -> Node:
	var orch: Node = _make_orch()
	orch.run_snapshot = RunSnapshotScript.new()
	orch.run_snapshot.losing_run = false
	orch.run_snapshot.synergy_id = synergy_id
	orch._combat_snapshot = CombatRunSnapshotScript.new()
	# Set the archetype as advantaged so attribute_kill_gold gives the
	# 1.5× matchup multiplier baseline.
	orch._combat_snapshot.matchup_cache = {archetype_advantaged: true}
	return orch


# ===========================================================================
# Group A — Steel Wall (3 Warriors) gold ×1.25 vs bruiser
# ===========================================================================

func test_steel_wall_bruiser_kills_apply_1_25_gold_multiplier() -> void:
	if get_node_or_null("/root/Economy") == null:
		push_warning("Skipped: Economy autoload not present")
		return
	# Baseline: 3 tier-1 advantaged bruiser kills, no synergy
	# floori(5 × 1.5 × 1.0) = 7 each → 21 total
	#
	# With Steel Wall: floori(5 × 1.5 × 1.0 × 1.25) = floori(9.375) = 9 each → 27 total
	# Delta: +6 gold for the synergy-active path.
	var orch_baseline: Node = _setup_orch_with_synergy("")
	var orch_steel: Node = _setup_orch_with_synergy("steel_wall")
	var economy: Node = orch_baseline.get_node_or_null("/root/Economy")

	# Run baseline
	var pre_a: int = int(economy._gold_balance)
	orch_baseline._process_kill_events(_make_events([
		_make_kill(1, &"bruiser"),
		_make_kill(1, &"bruiser"),
		_make_kill(1, &"bruiser"),
	]))
	var baseline_delta: int = int(economy._gold_balance) - pre_a

	# Run Steel Wall
	var pre_b: int = int(economy._gold_balance)
	orch_steel._process_kill_events(_make_events([
		_make_kill(1, &"bruiser"),
		_make_kill(1, &"bruiser"),
		_make_kill(1, &"bruiser"),
	]))
	var steel_delta: int = int(economy._gold_balance) - pre_b

	# Assert: baseline 21, steel_wall 27.
	assert_int(baseline_delta).is_equal(21)
	assert_int(steel_delta).is_equal(27)
	assert_int(steel_delta).is_greater(baseline_delta)


func test_steel_wall_skirmisher_kills_no_multiplier() -> void:
	# AC-CS-07: Steel Wall + non-bruiser archetype = no multiplier (1.0).
	if get_node_or_null("/root/Economy") == null:
		push_warning("Skipped: Economy autoload not present")
		return
	var orch_baseline: Node = _setup_orch_with_synergy("", &"skirmisher")
	var orch_steel: Node = _setup_orch_with_synergy("steel_wall", &"skirmisher")
	var economy: Node = orch_baseline.get_node_or_null("/root/Economy")

	var pre_a: int = int(economy._gold_balance)
	orch_baseline._process_kill_events(_make_events([_make_kill(1, &"skirmisher")]))
	var baseline_delta: int = int(economy._gold_balance) - pre_a

	var pre_b: int = int(economy._gold_balance)
	orch_steel._process_kill_events(_make_events([_make_kill(1, &"skirmisher")]))
	var steel_delta: int = int(economy._gold_balance) - pre_b

	# Both deltas equal — Steel Wall doesn't apply to skirmisher kills.
	assert_int(steel_delta).is_equal(baseline_delta)


# ===========================================================================
# Group B — Triple Threat (1+1+1) gold ×1.15 unconditional
# ===========================================================================

func test_triple_threat_kills_apply_1_15_gold_multiplier_unconditionally() -> void:
	if get_node_or_null("/root/Economy") == null:
		push_warning("Skipped: Economy autoload not present")
		return
	# Tier-1 advantaged: floori(5 × 1.5 × 1.0 × 1.15) = floori(8.625) = 8
	# 3 kills → 24 total (vs 21 baseline).
	var orch_baseline: Node = _setup_orch_with_synergy("")
	var orch_triple: Node = _setup_orch_with_synergy("triple_threat")
	var economy: Node = orch_baseline.get_node_or_null("/root/Economy")

	var pre_a: int = int(economy._gold_balance)
	orch_baseline._process_kill_events(_make_events([
		_make_kill(1, &"bruiser"),
		_make_kill(1, &"bruiser"),
		_make_kill(1, &"bruiser"),
	]))
	var baseline_delta: int = int(economy._gold_balance) - pre_a

	var pre_b: int = int(economy._gold_balance)
	orch_triple._process_kill_events(_make_events([
		_make_kill(1, &"bruiser"),
		_make_kill(1, &"bruiser"),
		_make_kill(1, &"bruiser"),
	]))
	var triple_delta: int = int(economy._gold_balance) - pre_b

	assert_int(baseline_delta).is_equal(21)
	assert_int(triple_delta).is_equal(24)


func test_triple_threat_applies_to_skirmisher_kills_too() -> void:
	# AC-CS-08: Triple Threat is unconditional — applies to all archetypes.
	if get_node_or_null("/root/Economy") == null:
		push_warning("Skipped: Economy autoload not present")
		return
	var orch_baseline: Node = _setup_orch_with_synergy("", &"skirmisher")
	var orch_triple: Node = _setup_orch_with_synergy("triple_threat", &"skirmisher")
	var economy: Node = orch_baseline.get_node_or_null("/root/Economy")

	var pre_a: int = int(economy._gold_balance)
	orch_baseline._process_kill_events(_make_events([_make_kill(2, &"skirmisher")]))
	var baseline_delta: int = int(economy._gold_balance) - pre_a

	var pre_b: int = int(economy._gold_balance)
	orch_triple._process_kill_events(_make_events([_make_kill(2, &"skirmisher")]))
	var triple_delta: int = int(economy._gold_balance) - pre_b

	# Triple Threat applies → triple_delta > baseline_delta even for skirmisher.
	assert_int(triple_delta).is_greater(baseline_delta)


# ===========================================================================
# Group C — Arcane Elite (3 Mages) gold unchanged, XP ×1.20
# ===========================================================================

func test_arcane_elite_does_not_modify_gold() -> void:
	# AC-CS-09: Arcane Elite affects XP only; gold path unchanged.
	if get_node_or_null("/root/Economy") == null:
		push_warning("Skipped: Economy autoload not present")
		return
	var orch_baseline: Node = _setup_orch_with_synergy("")
	var orch_arcane: Node = _setup_orch_with_synergy("arcane_elite")
	var economy: Node = orch_baseline.get_node_or_null("/root/Economy")

	var pre_a: int = int(economy._gold_balance)
	orch_baseline._process_kill_events(_make_events([
		_make_kill(2, &"caster"),
		_make_kill(2, &"caster"),
	]))
	var baseline_delta: int = int(economy._gold_balance) - pre_a

	var pre_b: int = int(economy._gold_balance)
	orch_arcane._process_kill_events(_make_events([
		_make_kill(2, &"caster"),
		_make_kill(2, &"caster"),
	]))
	var arcane_delta: int = int(economy._gold_balance) - pre_b

	# Gold deltas equal — Arcane Elite doesn't touch gold.
	assert_int(arcane_delta).is_equal(baseline_delta)


# ===========================================================================
# Group D — No synergy / unknown synergy: baseline (AC-CS-11 + AC-CS-18)
# ===========================================================================

func test_unknown_synergy_id_falls_back_to_baseline_in_kill_loop() -> void:
	# AC-CS-18: V1.5+ synergy_id loaded by V1.0 build → 1.0 multiplier.
	if get_node_or_null("/root/Economy") == null:
		push_warning("Skipped: Economy autoload not present")
		return
	var orch_baseline: Node = _setup_orch_with_synergy("")
	var orch_v15: Node = _setup_orch_with_synergy("veteran_squad")
	var economy: Node = orch_baseline.get_node_or_null("/root/Economy")

	var pre_a: int = int(economy._gold_balance)
	orch_baseline._process_kill_events(_make_events([_make_kill(1, &"bruiser")]))
	var baseline_delta: int = int(economy._gold_balance) - pre_a

	var pre_b: int = int(economy._gold_balance)
	orch_v15._process_kill_events(_make_events([_make_kill(1, &"bruiser")]))
	var v15_delta: int = int(economy._gold_balance) - pre_b

	# Unknown V1.5 synergy_id treated as no-synergy baseline.
	assert_int(v15_delta).is_equal(baseline_delta)


func test_steel_wall_does_not_affect_xp_only_synergies_path() -> void:
	# Cross-check: Steel Wall is a gold synergy; the XP resolver returns 1.0
	# for it. So XP per kill should be unchanged vs no-synergy.
	# This is verified at the resolver level in PR #28's class_synergy_formula_test.gd
	# Group D; here we just sanity-check the orchestrator-side wiring.
	var orch: Node = _make_orch()
	# The orchestrator's _resolve_synergy_xp_multiplier is private but
	# accessible via attribute_kill_xp's documented contract.
	# Steel Wall + tier 2 = 10 × 2 × 1.0 = 20 (baseline, no XP boost from Steel Wall)
	# Arcane Elite + tier 2 = 10 × 2 × 1.20 = 24
	var steel_xp: int = orch.attribute_kill_xp(2, "steel_wall")
	var arcane_xp: int = orch.attribute_kill_xp(2, "arcane_elite")
	var no_synergy_xp: int = orch.attribute_kill_xp(2)

	assert_int(steel_xp).is_equal(no_synergy_xp)  # 20
	assert_int(arcane_xp).is_greater(no_synergy_xp)  # 24 > 20
