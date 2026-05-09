# Sprint 21+ Prestige V1.0 Story 3 UI (Slice A) — Hero Detail Modal
# prestige button visibility + confirmation flow tests.
#
# Per `design/gdd/prestige-system.md` §C.1 + §C.2 + AC-PR-19 + AC-PR-20.
# Mirrors the integration test pattern in
# `tests/integration/hero_detail/hero_detail_modal_contract_test.gd`
# (synthetic hero injection into HeroRoster._heroes; cleanup via
# after_test). Lives under tests/unit because the assertions are
# button-state predicates, not full screen-flow integration.
#
# Test groups:
#   A — Visibility tri-state (eligible / active-run / last-hero)
#   B — Tap → confirmation flow (open + cancel + confirm)
#   C — Tap-time eligibility re-check (race-window guard)
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
	# Hygiene: drive the live DungeonRunOrchestrator state for the
	# active-run-guard tests. State enum: NO_RUN=0, DISPATCHING=1,
	# ACTIVE_FOREGROUND=2 per dungeon_run_state.gd.
	var orch: Node = get_tree().root.get_node_or_null("DungeonRunOrchestrator")
	if orch != null:
		orch.state = state_value
		orch.run_snapshot = null


func before_test() -> void:
	_force_orchestrator_state(0)  # NO_RUN baseline


func after_test() -> void:
	# Reset orchestrator + remove injected heroes + zero prestige state.
	_force_orchestrator_state(0)
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()
	HeroRoster._prestige_count = 0
	HeroRoster._prestige_multiplier = 1.0
	HeroRoster._retired_hero_records.clear()


# ===========================================================================
# Group A — Visibility tri-state
# ===========================================================================

func test_prestige_button_hidden_when_hero_below_cap() -> void:
	# Below cap → LevelUpButton owns the row, PrestigeButton hidden.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_inject_hero(801, "warrior", HeroRoster.level_cap() - 1)
	_inject_hero(802, "mage", 1)  # filler so AC-PR-20 isn't the false-cause

	var modal: Node = _make_modal()
	modal.set_target_hero(801)
	modal.on_enter()

	assert_bool(modal._prestige_button.visible).is_false()
	# LevelUpButton remains visible at below-cap.
	assert_bool(modal._level_up_button.visible).is_true()


func test_prestige_button_visible_and_enabled_when_at_cap_eligible() -> void:
	# At cap + 2 heroes + NO_RUN → button shown + enabled.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_inject_hero(803, "warrior", HeroRoster.level_cap())
	_inject_hero(804, "mage", 1)

	var modal: Node = _make_modal()
	modal.set_target_hero(803)
	modal.on_enter()

	assert_bool(modal._prestige_button.visible).is_true()
	assert_bool(modal._prestige_button.disabled).is_false()
	# LevelUpButton hides at cap (existing GDD §C.5 contract).
	assert_bool(modal._level_up_button.visible).is_false()


func test_prestige_button_disabled_with_tooltip_during_active_run() -> void:
	# AC-PR-19: active-run guard. Button shown + disabled + tooltip.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_inject_hero(805, "warrior", HeroRoster.level_cap())
	_inject_hero(806, "mage", 1)
	_force_orchestrator_state(2)  # ACTIVE_FOREGROUND

	var modal: Node = _make_modal()
	modal.set_target_hero(805)
	modal.on_enter()

	assert_bool(modal._prestige_button.visible).is_true()
	assert_bool(modal._prestige_button.disabled).is_true()
	# Tooltip is set to the localized string (tr() may return the key if
	# translations didn't load — but the tooltip should be NON-empty).
	assert_bool(modal._prestige_button.tooltip_text.length() > 0).is_true()


func test_prestige_button_hidden_when_last_hero() -> void:
	# AC-PR-20: last-hero protection. Roster size <= 1 → button hidden.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_inject_hero(807, "warrior", HeroRoster.level_cap())
	# No filler — _injected_hero_ids has only id 807, but HeroRoster._heroes
	# may still contain the live first-launch seed (Theron at id 1) from
	# autoload boot. To enforce a true "1 hero" scenario, we drop all
	# OTHER heroes from the roster for this test.
	# Strategy: snapshot existing IDs, remove them, restore in cleanup.
	var other_ids: Array[int] = []
	for live_id: int in HeroRoster._heroes.keys():
		if live_id != 807:
			other_ids.append(live_id)
	# Stash the live entries into _injected_hero_ids tracker so after_test
	# does NOT erase them (we'll restore manually).
	var stashed: Dictionary = {}
	for live_id: int in other_ids:
		stashed[live_id] = HeroRoster._heroes[live_id]
		HeroRoster._heroes.erase(live_id)
	assert_int(HeroRoster._heroes.size()).is_equal(1)

	var modal: Node = _make_modal()
	modal.set_target_hero(807)
	modal.on_enter()

	assert_bool(modal._prestige_button.visible).is_false()
	# Restore — re-add live heroes back into the roster so other tests
	# using the autoload don't suffer cross-test contamination.
	for live_id: int in stashed.keys():
		HeroRoster._heroes[live_id] = stashed[live_id]


# ===========================================================================
# Group B — Confirmation flow
# ===========================================================================

func test_prestige_button_press_opens_confirmation_overlay() -> void:
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_inject_hero(808, "warrior", HeroRoster.level_cap(), "Theron")
	_inject_hero(809, "mage", 1)

	var modal: Node = _make_modal()
	modal.set_target_hero(808)
	modal.on_enter()
	# Pre-condition: confirmation overlay hidden.
	assert_bool(modal._prestige_confirmation.visible).is_false()

	modal._on_prestige_pressed()

	assert_bool(modal._prestige_confirmation.visible).is_true()
	# Body label populated with the cozy-register copy + hero name.
	assert_bool(modal._prestige_confirm_body_label.text.contains("Theron")).is_true()


func test_prestige_cancel_hides_confirmation_without_calling_autoload() -> void:
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_inject_hero(810, "warrior", HeroRoster.level_cap())
	_inject_hero(811, "mage", 1)

	var modal: Node = _make_modal()
	modal.set_target_hero(810)
	modal.on_enter()
	modal._on_prestige_pressed()
	assert_bool(modal._prestige_confirmation.visible).is_true()

	modal._on_prestige_cancel_pressed()

	# Overlay hidden. Autoload state UNCHANGED.
	assert_bool(modal._prestige_confirmation.visible).is_false()
	assert_int(HeroRoster._prestige_count).is_equal(0)
	# Hero still in the roster (cancel ≠ retire).
	assert_bool(HeroRoster._heroes.has(810)).is_true()


func test_prestige_confirm_calls_autoload_and_advances_count() -> void:
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	# Warm TickSystem so retirement_unix_ts capture works.
	var ts: Node = get_tree().root.get_node_or_null("TickSystem")
	if ts != null and ts.has_method("_read_wall_clock_unix_time"):
		ts._read_wall_clock_unix_time()
	_inject_hero(812, "warrior", HeroRoster.level_cap(), "Theron")
	_inject_hero(813, "mage", 1)
	assert_int(HeroRoster._prestige_count).is_equal(0)

	var modal: Node = _make_modal()
	modal.set_target_hero(812)
	modal.on_enter()
	modal._on_prestige_pressed()
	modal._on_prestige_confirm_pressed()

	# Autoload mutated: hero retired, count advanced, record appended.
	assert_int(HeroRoster._prestige_count).is_equal(1)
	assert_bool(HeroRoster._heroes.has(812)).is_false()
	assert_int(HeroRoster._retired_hero_records.size()).is_equal(1)


# ===========================================================================
# Group C — Tap-time eligibility re-check
# ===========================================================================

func test_prestige_press_no_ops_when_eligibility_flips_after_render() -> void:
	# Race: button rendered eligible, then orchestrator transitions to
	# DISPATCHING before the tap fires. The press handler MUST re-check
	# eligibility and refuse to open the confirmation overlay (instead
	# refreshing the button state to disabled+tooltip).
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: warrior class not registered")
		return
	_inject_hero(814, "warrior", HeroRoster.level_cap())
	_inject_hero(815, "mage", 1)

	var modal: Node = _make_modal()
	modal.set_target_hero(814)
	modal.on_enter()
	# Render passes with NO_RUN — button is enabled.
	assert_bool(modal._prestige_button.visible).is_true()
	assert_bool(modal._prestige_button.disabled).is_false()

	# Race: orchestrator transitions to DISPATCHING.
	_force_orchestrator_state(1)

	modal._on_prestige_pressed()

	# Confirmation overlay was NOT shown. Button refreshed to disabled.
	assert_bool(modal._prestige_confirmation.visible).is_false()
	assert_bool(modal._prestige_button.disabled).is_true()
