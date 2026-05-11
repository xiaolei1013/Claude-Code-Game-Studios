# Tests for US-033 (test-coverage-backfill):
#   - KillEvent.equals — per-field inequality short-circuit branches not
#     covered by Group-B in value_types_and_equals_test.gd. Group-B covers
#     happy (field-by-field match), null edge, kill_tick mismatch, and
#     is_boss mismatch; this suite closes the remaining 3 short-circuit
#     branches of the 5-field `and`-chain at kill_event.gd:60-65:
#       * enemy_id mismatch (line 61)
#       * archetype mismatch (line 62)
#       * tier mismatch (line 63)
#
# Mirrors US-029 combat_batch_result_inequality_test.gd, US-031
# combat_run_snapshot_inequality_test.gd, and US-032
# combat_tick_events_inequality_test.gd shape: one test per uncovered
# field, each constructing two instances differing on EXACTLY ONE field
# and asserting equals() returns false.
#
# Covers: TR-combat-013 (KillEvent 5 fields + equals deep-equality walk).
extends GdUnitTestSuite

const KillEventScript = preload("res://src/core/combat/kill_event.gd")


# ---------------------------------------------------------------------------
# Per-field inequality short-circuit branches of equals()
# ---------------------------------------------------------------------------

func test_kill_event_equals_returns_false_on_enemy_id_mismatch() -> void:
	# kill_event.gd:61 — `enemy_id == other.enemy_id` short-circuits the
	# `and`-chain when enemy_id values differ.
	var a: KillEvent = KillEventScript.new()
	a.enemy_id = &"goblin_a"
	a.archetype = &"bruiser"
	a.tier = 2
	a.is_boss = false
	a.kill_tick = 42

	var b: KillEvent = KillEventScript.new()
	b.enemy_id = &"goblin_b"  # only enemy_id differs
	b.archetype = &"bruiser"
	b.tier = 2
	b.is_boss = false
	b.kill_tick = 42

	assert_bool(a.equals(b)).is_false()


func test_kill_event_equals_returns_false_on_archetype_mismatch() -> void:
	# kill_event.gd:62 — `archetype == other.archetype` short-circuits when
	# archetype values differ. Matchup-cache lookup correctness depends on
	# this branch returning false for parity-stream comparisons.
	var a: KillEvent = KillEventScript.new()
	a.enemy_id = &"goblin_a"
	a.archetype = &"bruiser"
	a.tier = 2
	a.is_boss = false
	a.kill_tick = 42

	var b: KillEvent = KillEventScript.new()
	b.enemy_id = &"goblin_a"
	b.archetype = &"caster"  # only archetype differs
	b.tier = 2
	b.is_boss = false
	b.kill_tick = 42

	assert_bool(a.equals(b)).is_false()


func test_kill_event_equals_returns_false_on_tier_mismatch() -> void:
	# kill_event.gd:63 — `tier == other.tier` short-circuits when tier
	# values differ. Tier drives Economy BASE_KILL[tier] gold lookup; an
	# undetected tier divergence would corrupt parity-stream gold totals.
	var a: KillEvent = KillEventScript.new()
	a.enemy_id = &"goblin_a"
	a.archetype = &"bruiser"
	a.tier = 1
	a.is_boss = false
	a.kill_tick = 42

	var b: KillEvent = KillEventScript.new()
	b.enemy_id = &"goblin_a"
	b.archetype = &"bruiser"
	b.tier = 3  # only tier differs
	b.is_boss = false
	b.kill_tick = 42

	assert_bool(a.equals(b)).is_false()
