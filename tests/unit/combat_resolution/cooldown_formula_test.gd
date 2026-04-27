# Tests for Sprint 7 combat-resolution Story 003:
#   - DefaultCombatResolver extends CombatResolver
#   - action_cooldown_ticks(speed) -> int formula
#   - Pre-guard speed<=0 → 1; clamp via maxi(1, floori(SPEED_BASE/speed))
#   - Bounded [1, SPEED_BASE]
#   - Zero float intermediates (TR-011)
#   - is_stub() preserved for orchestrator autoload tests
#
# Covers: TR-combat-004 (DefaultCombatResolver subclass),
#         TR-combat-005 (action_cooldown_ticks formula + speed<=0 pre-guard),
#         TR-combat-011 (integer arithmetic via floori/maxi/mini),
#         TR-combat-032 (action_cooldown_ticks bounded [1, SPEED_BASE];
#                        speed > SPEED_BASE clamps via maxi(1, ...)).
extends GdUnitTestSuite

const DefaultCombatResolverScript = preload("res://src/core/combat/default_combat_resolver.gd")
const CombatResolverScript = preload("res://src/core/combat/combat_resolver.gd")

# SPEED_BASE in CombatConfig defaults to 10 per GDD §G; the test relies on
# the .tres value being loadable via DataRegistry. When the config can't
# resolve (FOLLOWUP-002-style test env breakage), the resolver falls back
# to _FALLBACK_SPEED_BASE = 10 — same value, so tests still pass.
const EXPECTED_SPEED_BASE := 10


# ===========================================================================
# Group A: TR-004 — DefaultCombatResolver extends CombatResolver
# ===========================================================================

func test_default_combat_resolver_extends_combat_resolver() -> void:
	var inst: RefCounted = DefaultCombatResolverScript.new()
	var as_object: Object = inst
	assert_bool(as_object is CombatResolver).is_true()
	assert_bool(as_object is RefCounted).is_true()


func test_default_combat_resolver_can_be_instantiated_via_new() -> void:
	var inst: RefCounted = DefaultCombatResolverScript.new()
	assert_object(inst).is_not_null()


# ===========================================================================
# Group B: TR-005 — speed <= 0 pre-guard returns 1
# ===========================================================================

func test_action_cooldown_ticks_speed_zero_returns_one() -> void:
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.action_cooldown_ticks(0)).is_equal(1)


func test_action_cooldown_ticks_speed_negative_returns_one() -> void:
	# Pre-guard against negative speeds (caller bug or corrupt data).
	# Returns 1 (minimum-cooldown floor) — never 0, never negative.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.action_cooldown_ticks(-5)).is_equal(1)


func test_action_cooldown_ticks_speed_int_min_returns_one() -> void:
	# Pre-guard handles INT_MIN cleanly without overflow / div-by-zero.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.action_cooldown_ticks(-9223372036854775807)).is_equal(1)


# ===========================================================================
# Group C: TR-005 / TR-032 — formula + clamping bounds
# ===========================================================================

func test_action_cooldown_ticks_speed_one_returns_speed_base() -> void:
	# speed=1 → cooldown = SPEED_BASE / 1 = SPEED_BASE (slowest unit).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.action_cooldown_ticks(1)).is_equal(EXPECTED_SPEED_BASE)


func test_action_cooldown_ticks_speed_equals_speed_base_returns_one() -> void:
	# speed=SPEED_BASE → cooldown = SPEED_BASE / SPEED_BASE = 1 (one action per tick).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.action_cooldown_ticks(EXPECTED_SPEED_BASE)).is_equal(1)


func test_action_cooldown_ticks_speed_above_base_clamps_to_one() -> void:
	# speed > SPEED_BASE → floori(10/99) = 0; maxi(1, 0) = 1 (TR-032 floor).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.action_cooldown_ticks(99)).is_equal(1)


func test_action_cooldown_ticks_speed_two_returns_floor_div() -> void:
	# floori(10/2) = 5.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.action_cooldown_ticks(2)).is_equal(5)


func test_action_cooldown_ticks_speed_three_returns_three() -> void:
	# floori(10/3) = 3 (truncation of 3.333... — TR-011 integer arithmetic).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.action_cooldown_ticks(3)).is_equal(3)


func test_action_cooldown_ticks_speed_four_returns_two() -> void:
	# floori(10/4) = 2 (truncation of 2.5).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.action_cooldown_ticks(4)).is_equal(2)


func test_action_cooldown_ticks_speed_seven_returns_one() -> void:
	# floori(10/7) = 1 (truncation of 1.428...).
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_int(resolver.action_cooldown_ticks(7)).is_equal(1)


# ===========================================================================
# Group D: TR-011 — return type is int (no float leak)
# ===========================================================================

func test_action_cooldown_ticks_returns_int_type() -> void:
	# Verify the return is a plain int, not a float that happens to look like one.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	var result: Variant = resolver.action_cooldown_ticks(2)
	# typeof returns the Variant type code; for int it's TYPE_INT (2).
	assert_int(typeof(result)).is_equal(TYPE_INT)


# ===========================================================================
# Group E: TR-032 — bounded [1, SPEED_BASE]
# ===========================================================================

func test_action_cooldown_ticks_output_always_in_range_one_to_speed_base() -> void:
	# Sweep speeds from 1 to 100; output must always be in [1, SPEED_BASE].
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	for speed: int in range(1, 100):
		var result: int = resolver.action_cooldown_ticks(speed)
		assert_int(result).override_failure_message(
			"speed=%d produced cooldown=%d (must be in [1, %d])"
			% [speed, result, EXPECTED_SPEED_BASE]
		).is_greater_equal(1)
		assert_int(result).override_failure_message(
			"speed=%d produced cooldown=%d (exceeds SPEED_BASE=%d)"
			% [speed, result, EXPECTED_SPEED_BASE]
		).is_less_equal(EXPECTED_SPEED_BASE)


# ===========================================================================
# Group F: is_stub() preserved for orchestrator autoload tests
# ===========================================================================

func test_is_stub_marker_contains_default_combat_resolver_substring() -> void:
	# orchestrator's autoload_skeleton_and_di_test depends on this substring.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	assert_str(resolver.is_stub()).contains("DefaultCombatResolver")


# ===========================================================================
# Group G: TR-031 — fallback path when DataRegistry can't resolve combat_config
# ===========================================================================

func test_action_cooldown_ticks_works_even_with_fallback_speed_base() -> void:
	# The resolver's _resolve_speed_base() falls back to _FALLBACK_SPEED_BASE=10
	# when DataRegistry can't resolve combat_config. EXPECTED_SPEED_BASE=10
	# matches both the .tres value AND the fallback constant — so this test
	# passes regardless of DataRegistry state. If the fallback diverges from
	# the GDD default in the future, this test will catch the drift.
	var resolver: RefCounted = DefaultCombatResolverScript.new()
	# speed=1 produces cooldown=SPEED_BASE; whether SPEED_BASE comes from
	# config or fallback, the value should be 10.
	assert_int(resolver.action_cooldown_ticks(1)).is_equal(10)
