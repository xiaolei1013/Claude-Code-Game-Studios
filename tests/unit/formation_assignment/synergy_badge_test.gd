# Sprint 21+ Class Synergy V1.0 / Story 4 — UI badge live-preview tests.
#
# Per `design/gdd/class-synergy-system.md` §C.2 + §C.4 + AC-CS-15 + AC-CS-17.
#
# Tests cover the screen-side wiring that translates formation slot mutations
# into badge visibility + label text + glow tween + reduce-motion variant
# selection. The autoload-side detection function (FormationAssignment
# .detect_active_synergy) is exercised by class_synergy_detection_test.gd;
# this file owns the screen-side rendering contract.
#
# Test groups:
#   A — Visibility on synergy detect / hide
#   B — Localized text rendering ("DisplayName: Effect")
#   C — State de-dup (composition-multiset stable → no re-trigger)
#   D — Reduce-motion variant (AC-CS-17): instant alpha, no tween, alt theme
#   E — Tween cleanup on on_exit
extends GdUnitTestSuite

const FormationAssignmentScene = preload("res://assets/screens/formation_assignment/formation_assignment.tscn")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")

var _injected_hero_ids: Array[int] = []
var _saved_reduce_motion: bool = false


func _make_screen() -> Node:
	var screen: Node = FormationAssignmentScene.instantiate()
	add_child(screen)
	auto_free(screen)
	return screen


func _inject_hero(id: int, class_id: String) -> void:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = class_id
	fake.display_name = "TestHero%d" % id
	fake.current_level = 1
	fake.xp = 0
	HeroRoster._heroes[id] = fake
	_injected_hero_ids.append(id)


func _set_formation(slot0_id: int, slot1_id: int, slot2_id: int) -> void:
	# Direct field write — bypasses set_formation_slot's auto-clear so test
	# fixtures can reach any composition. The screen reads via
	# get_formation_slot which does not validate writes.
	# Typed local per project memory `project_typed_collection_test_fixtures`:
	# HeroRoster._formation_slots is Array[int] and rejects untyped literals.
	var slots: Array[int] = [slot0_id, slot1_id, slot2_id]
	HeroRoster._formation_slots = slots


func _set_reduce_motion(enabled: bool) -> void:
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")
	if sm != null and "reduce_motion" in sm:
		sm.reduce_motion = enabled


func before_test() -> void:
	# Snapshot reduce_motion so test ordering doesn't bleed state.
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")
	if sm != null and "reduce_motion" in sm:
		_saved_reduce_motion = bool(sm.get("reduce_motion"))
	_set_reduce_motion(false)
	# Reset formation explicitly — autoload boot may seed Theron into slot 0.
	# Group A's "no synergy" test needs an empty formation as the precondition.
	_set_formation(0, 0, 0)


func after_test() -> void:
	# Reset injected heroes + formation + reduce_motion.
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()
	var empty: Array[int] = [0, 0, 0]
	HeroRoster._formation_slots = empty
	_set_reduce_motion(_saved_reduce_motion)


# ===========================================================================
# Group A — Visibility on synergy detect / hide
# ===========================================================================

func test_synergy_badge_hidden_when_no_synergy() -> void:
	# Empty formation (no heroes assigned to slots) → badge hidden.
	# Cozy-register: don't surface the synergy area until there's something
	# to show.
	var screen: Node = _make_screen()
	screen.on_enter()

	assert_bool(screen._synergy_badge.visible).is_false()
	assert_str(screen._current_synergy_id).is_equal("")


func test_synergy_badge_visible_when_three_warriors_form_steel_wall() -> void:
	# 3-warrior composition → Steel Wall synergy → badge visible.
	# AC-CS-01 detection accuracy + screen-side rendering contract.
	_inject_hero(901, "warrior")
	_inject_hero(902, "warrior")
	_inject_hero(903, "warrior")
	_set_formation(901, 902, 903)

	var screen: Node = _make_screen()
	screen.on_enter()

	assert_bool(screen._synergy_badge.visible).is_true()
	assert_str(screen._current_synergy_id).is_equal("steel_wall")


func test_synergy_badge_hides_when_composition_breaks_synergy() -> void:
	# Steel Wall active, then one slot edited to a Mage → synergy lost,
	# badge hides. Verifies the live-preview re-evaluates on slot changes.
	_inject_hero(911, "warrior")
	_inject_hero(912, "warrior")
	_inject_hero(913, "warrior")
	_inject_hero(914, "mage")
	_set_formation(911, 912, 913)

	var screen: Node = _make_screen()
	screen.on_enter()
	assert_bool(screen._synergy_badge.visible).is_true()

	# Break the composition: slot 2 → mage. 2-warrior + 1-mage = no synergy.
	_set_formation(911, 912, 914)
	screen._refresh_formation_panel()

	assert_bool(screen._synergy_badge.visible).is_false()
	assert_str(screen._current_synergy_id).is_equal("")


# ===========================================================================
# Group B — Localized text rendering
# ===========================================================================

func test_synergy_badge_renders_localized_display_name_and_effect() -> void:
	# AC-CS-15: badge text routes through tr() for both display name and
	# effect summary. Verify both strings appear in the rendered text.
	_inject_hero(921, "warrior")
	_inject_hero(922, "warrior")
	_inject_hero(923, "warrior")
	_set_formation(921, 922, 923)

	var screen: Node = _make_screen()
	screen.on_enter()

	var text: String = screen._synergy_badge.text
	# Locale en.csv: class_synergy_badge_steel_wall = "Steel Wall"
	#                class_synergy_effect_steel_wall = "+25% gold vs bruisers"
	assert_str(text).contains("Steel Wall")
	assert_str(text).contains("bruisers")


func test_synergy_badge_renders_arcane_elite_for_three_mages() -> void:
	# Same rendering contract for the second synergy roster entry.
	_inject_hero(931, "mage")
	_inject_hero(932, "mage")
	_inject_hero(933, "mage")
	_set_formation(931, 932, 933)

	var screen: Node = _make_screen()
	screen.on_enter()

	assert_str(screen._current_synergy_id).is_equal("arcane_elite")
	assert_str(screen._synergy_badge.text).contains("Arcane Elite")


# ===========================================================================
# Group C — State de-dup (composition stable → no re-trigger)
# ===========================================================================

func test_synergy_badge_does_not_re_trigger_when_composition_unchanged() -> void:
	# Slot 0 ↔ slot 2 swap of two warriors (still 3-warrior multiset) →
	# _current_synergy_id stays "steel_wall"; the screen short-circuits and
	# does NOT re-tween or re-fire the audio chime. The audio throttle is
	# a backstop, not the primary de-dup.
	_inject_hero(941, "warrior")
	_inject_hero(942, "warrior")
	_inject_hero(943, "warrior")
	_set_formation(941, 942, 943)

	var screen: Node = _make_screen()
	screen.on_enter()
	var first_tween: Tween = screen._synergy_badge_tween

	# Swap slots 0 and 2 — same multiset, same synergy_id.
	_set_formation(943, 942, 941)
	screen._refresh_formation_panel()

	# State unchanged: same synergy_id, same tween reference (not re-created).
	assert_str(screen._current_synergy_id).is_equal("steel_wall")
	assert_object(screen._synergy_badge_tween).is_same(first_tween)


# ===========================================================================
# Group D — Reduce-motion variant (AC-CS-17)
# ===========================================================================

func test_reduce_motion_skips_glow_tween_and_uses_alt_theme_variation() -> void:
	# AC-CS-17: badge appears at full alpha instantly, no glow tween,
	# theme variation = class_synergy_badge_active_reduced_motion.
	_set_reduce_motion(true)
	_inject_hero(951, "warrior")
	_inject_hero(952, "warrior")
	_inject_hero(953, "warrior")
	_set_formation(951, 952, 953)

	var screen: Node = _make_screen()
	screen.on_enter()

	assert_bool(screen._synergy_badge.visible).is_true()
	assert_float(screen._synergy_badge.modulate.a).is_equal(1.0)
	assert_object(screen._synergy_badge_tween).is_null()
	assert_str(str(screen._synergy_badge.theme_type_variation)).is_equal(
		"class_synergy_badge_active_reduced_motion"
	)


func test_full_motion_uses_animated_theme_variation_and_creates_tween() -> void:
	# Default path (reduce_motion = false): badge starts at alpha 0, tween
	# fades to 1 over SYNERGY_BADGE_GLOW_DURATION_SEC, animated theme variant.
	_set_reduce_motion(false)
	_inject_hero(961, "warrior")
	_inject_hero(962, "warrior")
	_inject_hero(963, "warrior")
	_set_formation(961, 962, 963)

	var screen: Node = _make_screen()
	screen.on_enter()

	assert_bool(screen._synergy_badge.visible).is_true()
	assert_object(screen._synergy_badge_tween).is_not_null()
	assert_str(str(screen._synergy_badge.theme_type_variation)).is_equal(
		"class_synergy_badge_active"
	)


# ===========================================================================
# Group E — Tween cleanup on on_exit
# ===========================================================================

func test_on_exit_kills_in_flight_synergy_badge_tween() -> void:
	# Defensive: if the player navigates away mid-glow, the tween's
	# bound modulate target (the about-to-be-freed Label) must be
	# unbound. Mirrors the toast tween cleanup contract.
	_inject_hero(971, "warrior")
	_inject_hero(972, "warrior")
	_inject_hero(973, "warrior")
	_set_formation(971, 972, 973)

	var screen: Node = _make_screen()
	screen.on_enter()
	assert_object(screen._synergy_badge_tween).is_not_null()

	screen.on_exit()
	assert_object(screen._synergy_badge_tween).is_null()
