# Tests for Sprint 8 hero-roster Story 008 (S8-S5 carryover from S7-S7):
#   - seed_first_launch_state() creates exactly 1 Warrior at id=1, name="Theron"
#   - Hero placed in formation slot 0
#   - Emits hero_recruited exactly once (NOT suppressed even with _suppress_signals)
#   - Refuses on non-empty roster (push_warning, no mutation)
#   - Hardcoded "Theron" — deterministic across reinstalls (TR-021)
#
# Covers: TR-hero-roster-020 (seed creates 1 Warrior at id=1 in slot 0;
#                              hero_recruited fires exactly once),
#         TR-hero-roster-021 (display_name is hardcoded "Theron", NOT from
#                              random pool; reinstalls produce identical state).
#
# Each test uses a fresh HeroRoster instance for isolation. The fresh instance
# still consults the live DataRegistry singleton — when DataRegistry is in ERROR
# state (FOLLOWUP-002), success-path tests skip with push_warning per the
# precedent in `add_hero_and_signals_test.gd`.
extends GdUnitTestSuite

const HeroRosterScript = preload("res://src/core/hero_roster/hero_roster.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
const SEED_CLASS_ID := "warrior"
const SEED_NAME := "Theron"


# Build a fresh HeroRoster Node + add to scene tree so _ready() runs.
func _make_fresh_roster() -> Node:
	var hr: Node = HeroRosterScript.new()
	add_child(hr)
	auto_free(hr)
	return hr


func _data_registry_can_resolve_warrior() -> bool:
	return DataRegistry.resolve("classes", SEED_CLASS_ID) != null


# Signal spy state for hero_recruited.
var _spy_recruited_count: int = 0
var _spy_recruited_instance: RefCounted = null


func _on_hero_recruited(instance: RefCounted) -> void:
	_spy_recruited_count += 1
	_spy_recruited_instance = instance


# ===========================================================================
# Group A: TR-020 — seed creates exactly 1 Warrior at id=1
# ===========================================================================

func test_seed_first_launch_state_creates_exactly_one_hero() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped: DataRegistry cannot resolve 'warrior' class")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()

	# Act
	hr.seed_first_launch_state()

	# Assert — exactly one hero in roster.
	assert_int(hr._heroes.size()).is_equal(1)


func test_seed_first_launch_state_assigns_warrior_class_id() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()

	# Act
	hr.seed_first_launch_state()

	# Assert
	assert_str(hr._heroes[1].class_id).is_equal(SEED_CLASS_ID)


func test_seed_first_launch_state_assigns_instance_id_1() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()

	# Act
	hr.seed_first_launch_state()

	# Assert — instance lives at key 1; _next_instance_id advances to 2.
	assert_bool(hr._heroes.has(1)).is_true()
	assert_int(hr._heroes[1].instance_id).is_equal(1)
	assert_int(hr._next_instance_id).is_equal(2)


func test_seed_first_launch_state_sets_current_level_to_1() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()

	# Act
	hr.seed_first_launch_state()

	# Assert
	assert_int(hr._heroes[1].current_level).is_equal(1)
	assert_int(hr._heroes[1].xp).is_equal(0)


# ===========================================================================
# Group B: TR-020 — formation slot 0 placement
# ===========================================================================

func test_seed_first_launch_state_places_hero_in_formation_slot_0() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()

	# Act
	hr.seed_first_launch_state()

	# Assert — slot 0 holds the seeded hero's instance_id.
	assert_int(hr._formation_slots[0]).is_equal(1)


func test_seed_first_launch_state_other_formation_slots_remain_empty() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()

	# Act
	hr.seed_first_launch_state()

	# Assert — slots 1 and 2 (formation_size=3) stay at 0.
	for i: int in range(1, hr._formation_slots.size()):
		assert_int(hr._formation_slots[i]).is_equal(0)


# ===========================================================================
# Group C: TR-020 — hero_recruited fires exactly once
# ===========================================================================

func test_seed_first_launch_state_emits_hero_recruited_exactly_once() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	_spy_recruited_count = 0
	_spy_recruited_instance = null
	var hr: Node = _make_fresh_roster()
	hr.hero_recruited.connect(_on_hero_recruited)

	# Act
	hr.seed_first_launch_state()

	# Assert
	assert_int(_spy_recruited_count).is_equal(1)
	assert_object(_spy_recruited_instance).is_not_null()


func test_seed_first_launch_state_emits_hero_recruited_with_seed_instance() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	_spy_recruited_count = 0
	_spy_recruited_instance = null
	var hr: Node = _make_fresh_roster()
	hr.hero_recruited.connect(_on_hero_recruited)

	# Act
	hr.seed_first_launch_state()

	# Assert — the emitted instance is the seeded hero (display_name match).
	assert_str(_spy_recruited_instance.display_name).is_equal(SEED_NAME)
	assert_str(_spy_recruited_instance.class_id).is_equal(SEED_CLASS_ID)


func test_seed_first_launch_state_emits_signal_even_when_suppress_signals_true() -> void:
	# TR-020: signal emission is NOT gated on _suppress_signals — the player's
	# first hero deserves a HUD reaction even in scripted-test contexts.
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	_spy_recruited_count = 0
	var hr: Node = _make_fresh_roster()
	hr._suppress_signals = true  # force suppression on for this test
	hr.hero_recruited.connect(_on_hero_recruited)

	# Act
	hr.seed_first_launch_state()

	# Assert — signal still fired despite suppression flag.
	assert_int(_spy_recruited_count).is_equal(1)


# ===========================================================================
# Group D: TR-021 — hardcoded "Theron" name
# ===========================================================================

func test_seed_first_launch_state_assigns_hardcoded_theron_name() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()

	# Act
	hr.seed_first_launch_state()

	# Assert — string equality, NOT regex match.
	assert_str(hr._heroes[1].display_name).is_equal(SEED_NAME)


func test_seed_first_launch_state_two_fresh_rosters_produce_identical_seed_name() -> void:
	# TR-021 reinstall reproducibility: two fresh seeds must produce the same
	# display_name "Theron". This is the deterministic-for-QA invariant.
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange + Act
	var hr_a: Node = _make_fresh_roster()
	var hr_b: Node = _make_fresh_roster()
	hr_a.seed_first_launch_state()
	hr_b.seed_first_launch_state()

	# Assert
	assert_str(hr_a._heroes[1].display_name).is_equal(hr_b._heroes[1].display_name)
	assert_str(hr_a._heroes[1].display_name).is_equal(SEED_NAME)


func test_seed_first_launch_state_uses_seed_name_constant_not_generated_name() -> void:
	# Defensive: the _generate_name placeholder returns "Hero N" (Story 009
	# placeholder). Verify the seed bypasses that path entirely — display_name
	# must be exactly "Theron", NOT "Hero 1".
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange
	var hr: Node = _make_fresh_roster()

	# Act
	hr.seed_first_launch_state()

	# Assert
	assert_str(hr._heroes[1].display_name).is_not_equal("Hero 1")


# ===========================================================================
# Group E: seed safety — refuses on non-empty roster
# ===========================================================================

func test_seed_first_launch_state_refuses_on_non_empty_roster() -> void:
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange — pre-populate with one hero via add_hero. add_hero uses
	# randi() to pick from the warrior name pool, which CAN include
	# "Theron" — leading to a flaky `is_not_equal("Theron")` assertion
	# below. Force the display_name to a known-distinct sentinel so the
	# test asserts the seed-didn't-overwrite behavior deterministically.
	var hr: Node = _make_fresh_roster()
	var pre_existing: RefCounted = hr.add_hero(SEED_CLASS_ID)
	assert_object(pre_existing).is_not_null()
	const _SENTINEL_NAME: String = "PreExistingNotTheron"
	pre_existing.display_name = _SENTINEL_NAME

	# Act — should refuse and log a push_warning; no mutation.
	hr.seed_first_launch_state()

	# Assert — roster size unchanged.
	assert_int(hr._heroes.size()).is_equal(1)
	# The pre-existing hero's display_name is the sentinel — verifies the
	# seed didn't overwrite the pre-existing hero (which would have set
	# display_name to SEED_NAME = "Theron").
	assert_str(hr._heroes[1].display_name).is_equal(_SENTINEL_NAME)


func test_seed_first_launch_state_refuses_on_already_seeded_roster() -> void:
	# Calling seed twice should be idempotent in the no-op sense: second call
	# refuses with push_warning.
	if not _data_registry_can_resolve_warrior():
		push_warning("Skipped")
		return
	# Arrange — first seed succeeds.
	var hr: Node = _make_fresh_roster()
	hr.seed_first_launch_state()
	assert_int(hr._heroes.size()).is_equal(1)
	var first_seed_id: int = hr._next_instance_id

	# Act — second seed should refuse.
	hr.seed_first_launch_state()

	# Assert — roster unchanged; _next_instance_id unchanged.
	assert_int(hr._heroes.size()).is_equal(1)
	assert_int(hr._next_instance_id).is_equal(first_seed_id)


# ===========================================================================
# Group F: structural — seed constants exposed for QA inspection
# ===========================================================================

func test_seed_constants_exist_at_expected_values() -> void:
	# TR-021 deterministic-for-QA: the seed constants must be inspectable by
	# QA tooling (and unchanged across reinstalls). Verify they exist at the
	# class-script level with the canonical values.
	assert_str(HeroRosterScript.SEED_HERO_CLASS_ID).is_equal("warrior")
	assert_str(HeroRosterScript.SEED_HERO_NAME).is_equal("Theron")
	assert_int(HeroRosterScript.SEED_HERO_INSTANCE_ID).is_equal(1)
	assert_int(HeroRosterScript.SEED_FORMATION_SLOT).is_equal(0)
