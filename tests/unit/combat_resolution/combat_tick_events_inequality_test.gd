# Tests for US-032 (test-coverage-backfill):
#   - CombatTickEvents.equals — per-field inequality short-circuit branches
#     not covered by Group-C in value_types_and_equals_test.gd. Group-C
#     covers happy (matching kills array -> true), null edge,
#     first_clear_in_range mismatch, and kills size mismatch; this suite
#     closes the remaining 2 short-circuit branches:
#       * loop_completed_ticks mismatch (line 49-50, Array[int] != compare)
#       * kills per-element KillEvent.equals mismatch (line 53-55, same-size
#         arrays where at-least-one element differs structurally)
#
# Mirrors US-029 combat_batch_result_inequality_test.gd and US-031
# combat_run_snapshot_inequality_test.gd shape: one test per uncovered
# field, each constructing two instances differing on EXACTLY ONE field
# and asserting equals() returns false.
#
# Covers: TR-combat-014 (CombatTickEvents 3 fields + equals walk),
#         TR-combat-013 (per-element KillEvent.equals walk in kills array).
extends GdUnitTestSuite

const KillEventScript = preload("res://src/core/combat/kill_event.gd")
const CombatTickEventsScript = preload("res://src/core/combat/combat_tick_events.gd")


# ---------------------------------------------------------------------------
# Per-field inequality short-circuit branches of equals()
# ---------------------------------------------------------------------------

func test_combat_tick_events_equals_returns_false_on_loop_completed_ticks_mismatch() -> void:
	# Line 49-50: `if loop_completed_ticks != other.loop_completed_ticks: return false`
	# Array[int] == is structural in GDScript 4 — same-size-different-values
	# is sufficient to drive the != branch to true.
	var a: CombatTickEvents = CombatTickEventsScript.new()
	a.loop_completed_ticks = [10, 20]
	var b: CombatTickEvents = CombatTickEventsScript.new()
	b.loop_completed_ticks = [10, 21]  # same size, second value differs
	assert_bool(a.equals(b)).is_false()


func test_combat_tick_events_equals_returns_false_on_kills_element_mismatch() -> void:
	# Line 53-55: per-element KillEvent.equals walk. Same-size kills arrays
	# where at least one element is structurally different from the parallel
	# element (NOT reference-different; reference-different field-equal
	# events compare equal — see Group-B test_kill_event_reference_different_
	# field_equal_yields_equals_true).
	var k1: KillEvent = KillEventScript.new()
	k1.enemy_id = &"e1"
	k1.kill_tick = 10
	var k2: KillEvent = KillEventScript.new()
	k2.enemy_id = &"e2"  # enemy_id differs from k1
	k2.kill_tick = 10

	var a: CombatTickEvents = CombatTickEventsScript.new()
	a.kills = [k1]
	var b: CombatTickEvents = CombatTickEventsScript.new()
	b.kills = [k2]  # same size as a.kills, but element structurally differs

	assert_bool(a.equals(b)).is_false()
