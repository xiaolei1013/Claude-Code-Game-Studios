# Tests for GDD #34 Phase 5 (Defeat & Injury System / ADR-0021): the orchestrator
# wiring that INJURES the dispatched formation when an OFFLINE-replay run is
# DEFEATED (AC-34-04/05), with the recovery clock anchored at the OFFLINE WINDOW
# START — NOT at resume.
#
# Offline-injury contract (Model B — GDD #34 §E.3/§E.5):
#   - compute_offline_batch resolves the WIN/DEFEAT verdict ONCE on the first
#     chunk (same compute_run_outcome the foreground dispatch uses). On DEFEAT it
#     injures every hero in run_snapshot.formation_snapshot.instance_ids.
#   - The recovery instant anchors at the WINDOW START, not at resume:
#         until_ms = window_start_ms + injury_recovery_seconds() * 1000
#     where window_start_ms = _offline_window_start_ms (set by the engine to
#     now - elapsed*1000), or TickSystem.now_ms() when unset (foreground parity).
#   - Consequence (E.5 wall-clock recovery): for a LONG absence where the window
#     start + recovery already elapsed, heroes are HEALTHY at resume. For a SHORT
#     absence they are still injured. This is the headline correctness property.
#   - A WINNING offline run never injures (control).
#   - The injury fires at most ONCE per replay cycle (verdict cached first chunk).
#
# These tests mutate the LIVE /root/HeroRoster autoload, so they snapshot+restore
# it via HeroRosterFixture (memory: feedback_test_isolation_live_autoload). The
# offline-batch harness (defeat spy resolver + set_offline_replay_inputs) mirrors
# offline_batch_feeder_test.gd; the injury assertions mirror
# defeat_injury_wiring_test.gd.
extends GdUnitTestSuite

const OrchestratorScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd")
const CombatBatchResultScript = preload("res://src/core/combat/combat_batch_result.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")


# Spy resolver: returns kills proportional to the window, like offline_batch_feeder.
class _SpyResolver extends RefCounted:
	func compute_offline_batch(_snapshot: Variant, tick_budget: int) -> RefCounted:
		var r: RefCounted = CombatBatchResultScript.new()
		r.kills_by_tier = {1: int(tick_budget / 100)}
		r.loops_completed = int(tick_budget / 300)
		r.first_clear_tick = -1
		return r


# Minimal verdict stand-in: the offline verdict path reads only `.won`.
class _DefeatOutcome extends RefCounted:
	var won: bool = false
	var clear_tick: int = -1
	var defeat_tick: int = 5


# Spy resolver reporting DEFEAT (compute_run_outcome → won=false).
class _DefeatSpyResolver extends _SpyResolver:
	func compute_run_outcome(_snapshot: Variant) -> RefCounted:
		return _DefeatOutcome.new()


# A fixed, large, production-realistic wall-clock (Unix seconds ≈ 2033). The bare
# test env never seeds TickSystem's wall clock, so now_ms() would return 0 — which
# makes a "long absence" window-start (now - recovery - slack) go NEGATIVE and trip
# the production `> 0` "is-set" guard. In production now_ms() is a real Unix ms
# (~1.7e12) so the guard is sound; we seed the same realism here, deterministically.
const _FIXED_NOW_S: int = 2_000_000_000

var _roster_snapshot: Dictionary = {}
var _wall_ts_snapshot: int = 0


func before_test() -> void:
	_roster_snapshot = HeroRosterFixture.snapshot_via_save_data()
	HeroRosterFixture.reset_hero_roster()
	_wall_ts_snapshot = TickSystem._last_wall_ts
	TickSystem._last_wall_ts = _FIXED_NOW_S  # now_ms() → _FIXED_NOW_S * 1000


func after_test() -> void:
	HeroRosterFixture.restore_via_load_save_data(_roster_snapshot)
	TickSystem._last_wall_ts = _wall_ts_snapshot


# Returns the live HeroRoster autoload, or null if absent (lean test env).
func _roster() -> Node:
	return get_tree().root.get_node_or_null("HeroRoster")


# Injects a synthetic HeroInstance into the live roster's _heroes (so
# injure_heroes can find it) and returns it for use as the offline formation.
func _inject_hero(roster: Node, id: int) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = "warrior"
	fake.display_name = "Test Hero %d" % id
	fake.current_level = 1
	fake.injured_until = 0
	roster._heroes[id] = fake
	return fake


# Builds an orchestrator wired with the given resolver and a one-hero offline
# formation whose id is also present in the live roster.
func _make_offline_orch(resolver: RefCounted, hero: RefCounted) -> Node:
	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	orch.set_combat_resolver(resolver)
	orch.set_offline_replay_inputs([hero], 1, "")
	return orch


# ===========================================================================
# Group A: offline DEFEAT injures the formation, anchored at window-start
# ===========================================================================

func test_offline_defeat_injures_formation_short_window() -> void:
	# A short absence: window start ≈ now, so window_start + recovery is in the
	# future → the hero is injured at resume.
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var hero: RefCounted = _inject_hero(roster, 1)
	var orch: Node = _make_offline_orch(_DefeatSpyResolver.new(), hero)

	var now_ms: int = TickSystem.now_ms()
	orch.set_offline_window_start_ms(now_ms)  # short window: started "now"
	orch.compute_offline_batch(600)

	assert_bool(roster.is_hero_injured(1, now_ms)).override_failure_message(
		"a short-window offline defeat must leave the hero injured at resume"
	).is_true()
	# until ≈ now + recovery (anchored at window start = now).
	var recovery_ms: int = int(roster.injury_recovery_seconds()) * 1000
	assert_int(hero.injured_until).is_greater_equal(now_ms + recovery_ms - 5000)
	assert_int(hero.injured_until).is_less_equal(now_ms + recovery_ms + 5000)


func test_offline_defeat_long_absence_hero_recovered_at_resume() -> void:
	# THE headline E.5 property: an absence longer than the recovery duration means
	# the window-start-anchored recovery has ALREADY elapsed → the hero is healthy
	# at resume, even though the doomed run injured them.
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var hero: RefCounted = _inject_hero(roster, 1)
	var orch: Node = _make_offline_orch(_DefeatSpyResolver.new(), hero)

	var now_ms: int = TickSystem.now_ms()
	var recovery_ms: int = int(roster.injury_recovery_seconds()) * 1000
	# Window started (recovery + 10 min) ago → window_start + recovery is in the past.
	orch.set_offline_window_start_ms(now_ms - recovery_ms - 600_000)
	orch.compute_offline_batch(600)

	assert_bool(roster.is_hero_injured(1, now_ms)).override_failure_message(
		"a long offline absence must let window-start-anchored recovery elapse — healthy at resume (E.5)"
	).is_false()
	# The injury WAS applied (anchored in the past), it just already elapsed.
	assert_int(hero.injured_until).override_failure_message(
		"injury must still have been written (anchored at window start), just elapsed"
	).is_greater(0)
	assert_int(hero.injured_until).is_less(now_ms)


func test_offline_defeat_without_window_start_anchors_at_now() -> void:
	# Fallback parity: when the engine did not set a window start (default 0), the
	# anchor is now_ms() — identical to the foreground path → injured at resume.
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var hero: RefCounted = _inject_hero(roster, 1)
	var orch: Node = _make_offline_orch(_DefeatSpyResolver.new(), hero)

	var before_ms: int = TickSystem.now_ms()
	orch.compute_offline_batch(600)  # no set_offline_window_start_ms call
	var after_ms: int = TickSystem.now_ms()

	var recovery_ms: int = int(roster.injury_recovery_seconds()) * 1000
	assert_bool(roster.is_hero_injured(1, after_ms)).is_true()
	assert_int(hero.injured_until).is_greater_equal(before_ms + recovery_ms)
	assert_int(hero.injured_until).is_less_equal(after_ms + recovery_ms)


# ===========================================================================
# Group B: controls — win never injures; injury fires once
# ===========================================================================

func test_offline_win_does_not_injure() -> void:
	# The _SpyResolver lacks compute_run_outcome → the verdict defaults to WIN, so
	# no injury is applied (control for the defeat path).
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var hero: RefCounted = _inject_hero(roster, 1)
	var orch: Node = _make_offline_orch(_SpyResolver.new(), hero)

	orch.set_offline_window_start_ms(TickSystem.now_ms())
	orch.compute_offline_batch(600)

	assert_bool(roster.is_hero_injured(1, TickSystem.now_ms())).is_false()
	assert_int(hero.injured_until).is_equal(0)


func test_offline_defeat_injures_at_most_once_across_chunks() -> void:
	# The verdict (and thus the injury) is computed ONCE on the first chunk; later
	# chunks of the same doomed window must NOT re-fire the injury. Proven via the
	# heroes_injured signal emission count.
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var hero: RefCounted = _inject_hero(roster, 1)
	var orch: Node = _make_offline_orch(_DefeatSpyResolver.new(), hero)

	var emit_count: Array = [0]
	roster.heroes_injured.connect(
		func(_ids: Array, _until_ms: int) -> void:
			emit_count[0] += 1
	)

	orch.set_offline_window_start_ms(TickSystem.now_ms())
	orch.compute_offline_batch(600)
	orch.compute_offline_batch(600)
	orch.compute_offline_batch(600)

	assert_int(emit_count[0]).override_failure_message(
		"offline defeat must injure exactly once per replay (verdict cached on first chunk)"
	).is_equal(1)


func test_offline_defeat_empty_formation_is_noop() -> void:
	# An empty offline formation → no instance_ids → injury is a safe no-op (and
	# the roster's lone bystander hero stays healthy).
	var roster: Node = _roster()
	if roster == null:
		push_warning("Skipped: HeroRoster autoload not present")
		return
	var bystander: RefCounted = _inject_hero(roster, 1)

	var orch: Node = OrchestratorScript.new()
	add_child(orch)
	auto_free(orch)
	orch.set_combat_resolver(_DefeatSpyResolver.new())
	orch.set_offline_replay_inputs([], 1, "")  # empty formation

	orch.set_offline_window_start_ms(TickSystem.now_ms())
	orch.compute_offline_batch(600)

	assert_int(bystander.injured_until).is_equal(0)
