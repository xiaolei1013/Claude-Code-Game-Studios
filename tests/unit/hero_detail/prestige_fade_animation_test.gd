# Sprint 21+ Prestige V1.0 Story 3 UI (Slice C) — hero-fade-to-Hall
# animation tests + AC-PR-18 reduce-motion variant.
#
# Per `design/gdd/prestige-system.md` §C.2 + AC-PR-18.
#
# Test groups:
#   A — Reduce-motion path (instant-cut; no fade tween)
#   B — Default path (tween created; in-flight flag toggles)
#   C — Fade lifecycle hygiene (re-entry guard, on_exit cleanup,
#       on_enter modulate reset)
#   D — Failure-path recovery (autoload rejection resets modulate)
extends GdUnitTestSuite

const HeroDetailModalScene = preload("res://assets/screens/hero_detail/hero_detail_modal.tscn")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

var _injected_hero_ids: Array[int] = []


func _make_modal() -> Node:
	var modal: Node = HeroDetailModalScene.instantiate()
	add_child(modal)
	auto_free(modal)
	return modal


func _inject_hero(id: int, class_id: String, level: int, display_name: String = "") -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = class_id
	fake.display_name = display_name if display_name != "" else "TestHero%d" % id
	fake.current_level = level
	fake.xp = 0
	HeroRoster._heroes[id] = fake
	_injected_hero_ids.append(id)
	return fake


func _force_orchestrator_state(state_value: int) -> void:
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	if orch != null:
		orch.state = state_value
		orch.run_snapshot = null


func _set_reduce_motion(enabled: bool) -> void:
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")
	if sm != null:
		sm.reduce_motion = enabled


func before_test() -> void:
	_force_orchestrator_state(0)  # NO_RUN
	_set_reduce_motion(false)


func after_test() -> void:
	_force_orchestrator_state(0)
	_set_reduce_motion(false)
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()
	HeroRoster._prestige_count = 0
	HeroRoster._prestige_multiplier = 1.0
	HeroRoster._retired_hero_records.clear()


# ===========================================================================
# Group A — Reduce-motion path (AC-PR-18)
# ===========================================================================

func test_confirm_with_reduce_motion_calls_autoload_synchronously_no_tween() -> void:
	# AC-PR-18: with reduce_motion=true, confirm tap MUST call
	# prestige_hero on the same frame (no tween scheduled), and
	# _prestige_fade_in_flight remains false.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_set_reduce_motion(true)
	_inject_hero(900, "warrior", HeroRoster.level_cap(), "Theron")
	_inject_hero(901, "mage", 1)

	var modal: Node = _make_modal()
	modal.set_target_hero(900)
	modal.on_enter()
	modal._on_prestige_pressed()

	assert_int(HeroRoster._prestige_count).is_equal(0)
	modal._on_prestige_confirm_pressed()

	# Synchronous: count advanced; no tween was created; flag is clean.
	assert_int(HeroRoster._prestige_count).is_equal(1)
	assert_object(modal._prestige_fade_tween).is_null()
	assert_bool(modal._prestige_fade_in_flight).is_false()
	# DetailPanel modulate is unchanged (still fully opaque) — fade
	# was skipped per reduce-motion.
	assert_float(modal._detail_panel.modulate.a).is_equal(1.0)


# ===========================================================================
# Group B — Default path (tween created; flag toggles)
# ===========================================================================

func test_confirm_default_path_creates_tween_and_sets_in_flight_flag() -> void:
	# Without reduce_motion, confirm tap creates a Tween and flips the
	# in-flight guard true. The autoload mutation is deferred until the
	# tween-completion callback fires.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_set_reduce_motion(false)
	_inject_hero(902, "warrior", HeroRoster.level_cap(), "Theron")
	_inject_hero(903, "mage", 1)

	var modal: Node = _make_modal()
	modal.set_target_hero(902)
	modal.on_enter()
	modal._on_prestige_pressed()

	assert_int(HeroRoster._prestige_count).is_equal(0)
	modal._on_prestige_confirm_pressed()

	# Tween created; flag set; autoload NOT yet called (deferred to
	# tween completion).
	assert_object(modal._prestige_fade_tween).is_not_null()
	assert_bool(modal._prestige_fade_in_flight).is_true()
	assert_int(HeroRoster._prestige_count).is_equal(0)


func test_confirm_default_path_completes_prestige_after_tween_finishes() -> void:
	# End-to-end: after letting the tween run to completion (await
	# finished signal), prestige_hero has been called and the autoload
	# count advanced.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_set_reduce_motion(false)
	# Warm TickSystem for retirement_unix_ts capture.
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	if ts != null and ts.has_method("_read_wall_clock_unix_time"):
		ts._read_wall_clock_unix_time()
	_inject_hero(904, "warrior", HeroRoster.level_cap(), "Theron")
	_inject_hero(905, "mage", 1)

	var modal: Node = _make_modal()
	modal.set_target_hero(904)
	modal.on_enter()
	modal._on_prestige_pressed()
	modal._on_prestige_confirm_pressed()

	# Run the tween to completion. The tween is auto-started; await
	# finished blocks until the tween-completion callback fires.
	var tween: Tween = modal._prestige_fade_tween
	assert_object(tween).is_not_null()
	await tween.finished

	# Post-tween: prestige_hero ran; count advanced; flag cleared.
	assert_int(HeroRoster._prestige_count).is_equal(1)
	assert_bool(modal._prestige_fade_in_flight).is_false()


# ===========================================================================
# Group C — Lifecycle hygiene
# ===========================================================================

func test_re_entry_guard_blocks_double_confirm_tap_during_fade() -> void:
	# Defensive: a double-tap on Confirm during the in-flight fade must
	# NOT enqueue a second prestige call. The first tap starts the fade;
	# the second tap is a no-op (re-entrancy guard).
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_set_reduce_motion(false)
	_inject_hero(906, "warrior", HeroRoster.level_cap(), "Theron")
	_inject_hero(907, "mage", 1)

	var modal: Node = _make_modal()
	modal.set_target_hero(906)
	modal.on_enter()
	modal._on_prestige_pressed()
	modal._on_prestige_confirm_pressed()  # first tap — starts fade
	var tween_after_first: Tween = modal._prestige_fade_tween

	modal._on_prestige_confirm_pressed()  # second tap — should be no-op

	# Same tween reference (no second one created). Flag still true.
	assert_object(modal._prestige_fade_tween).is_same(tween_after_first)
	assert_bool(modal._prestige_fade_in_flight).is_true()


func test_on_enter_resets_modulate_and_fade_state() -> void:
	# Modal re-entry contract: every on_enter MUST reset DetailPanel
	# alpha to 1.0 and clear in-flight flag. This guards against a
	# future code path (e.g., a recycled modal scene) that would
	# otherwise show an invisible panel.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_inject_hero(908, "warrior", HeroRoster.level_cap(), "Theron")
	_inject_hero(909, "mage", 1)

	var modal: Node = _make_modal()
	# Simulate stale state from a prior fade — directly mutate before
	# on_enter to verify reset.
	modal.set_target_hero(908)
	modal.on_enter()
	modal._detail_panel.modulate.a = 0.0  # corrupted by hypothetical bug
	modal._prestige_fade_in_flight = true

	modal.on_enter()  # re-enter

	assert_float(modal._detail_panel.modulate.a).is_equal(1.0)
	assert_bool(modal._prestige_fade_in_flight).is_false()


# ===========================================================================
# Group D — Failure-path recovery
# ===========================================================================

func test_autoload_rejection_resets_modulate_so_modal_recovers() -> void:
	# Race: between the player's Confirm tap (which started the fade)
	# and the tween-completion callback firing, the orchestrator
	# transitioned to ACTIVE_FOREGROUND. HeroRoster.prestige_hero now
	# rejects (returns false). The modal must restore alpha=1.0 so the
	# panel is visible to the player + refresh the button to its new
	# disabled state.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_set_reduce_motion(false)
	_inject_hero(910, "warrior", HeroRoster.level_cap(), "Theron")
	_inject_hero(911, "mage", 1)

	var modal: Node = _make_modal()
	modal.set_target_hero(910)
	modal.on_enter()
	modal._on_prestige_pressed()
	modal._on_prestige_confirm_pressed()

	# Race: orchestrator goes active mid-fade.
	_force_orchestrator_state(2)  # ACTIVE_FOREGROUND

	# Run tween to completion → _execute_prestige fires → autoload
	# returns false → modal recovers.
	var tween: Tween = modal._prestige_fade_tween
	assert_object(tween).is_not_null()
	await tween.finished

	# State unchanged. Alpha restored. Button now disabled (active-run
	# guard surfaces).
	assert_int(HeroRoster._prestige_count).is_equal(0)
	assert_float(modal._detail_panel.modulate.a).is_equal(1.0)
	assert_bool(modal._prestige_button.disabled).is_true()
