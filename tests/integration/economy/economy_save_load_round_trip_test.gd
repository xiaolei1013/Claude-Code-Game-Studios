# Tests for Story 012: Economy.get_save_data + Economy.load_save_data round-trip.
# Covers: AC H-11 (round-trip equality), AC H-11 reclaim path,
#         schema_version field + version-mismatch handling,
#         signal-quiet during restore, malformed/missing keys defensive paths,
#         post-restore tick + spend pipeline still works.
#
# Round-trip strategy:
#   The unit-level round-trip is direct dict-to-dict (no JSON envelope):
#       data = A.get_save_data()
#       B.load_save_data(data)
#   This exercises the schema-version contract + key/value coercions without
#   booting SaveLoadSystem. JSON-round-trip type coercion (TYPE_FLOAT for ints,
#   String dict keys) is exercised by a dedicated test that explicitly converts
#   the dict via JSON.stringify + JSON.parse_string before load.
#
# Signal-quiet verification:
#   Tests connect spies to gold_changed + first_clear_awarded BEFORE calling
#   load_save_data. Per the implementation, the hydration assigns to private
#   fields directly (NOT via add_gold), so neither signal can fire during the
#   call — the contract is satisfied without flag-flipping.
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")
const EconomyConfigScript = preload("res://src/core/economy/economy_config.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Boots a fresh Economy instance with a synthetic EconomyConfig injected
## (skips DataRegistry boot path so the test focuses on save/load semantics).
##
## Typed-collection note (per project memory `project_typed_collection_test_fixtures`):
## EconomyConfig.BASE_DRIP is declared `Array[int]`; assigning a generic Array
## literal at runtime fails with "Invalid assignment of property". An explicit
## typed local is required.
func _make_economy() -> Node:
	var economy: Node = EconomyScript.new()
	var cfg: Resource = EconomyConfigScript.new()
	var base_drip: Array[int] = [2, 4, 7, 12, 8]
	cfg.BASE_DRIP = base_drip
	cfg.MATCHUP_DRIP_BONUS = 1.0
	economy._config = cfg
	return economy


# ---------------------------------------------------------------------------
# Test 1 — AC H-11: full round-trip equality
#   12345 gold + 98765 lifetime + 3-key partial ledger restores exactly.
# ---------------------------------------------------------------------------
func test_h11_round_trip_preserves_gold_lifetime_and_ledger_exactly() -> void:
	# Arrange — author state on instance A
	var economy_a: Node = _make_economy()
	economy_a._gold_balance = 12345
	economy_a._lifetime_gold_earned = 98765
	var ledger_init: Dictionary[String, int] = {"forest_reach_f1": 500, "forest_reach_f2": 1200, "forest_reach_f3": 1500}
	economy_a._floor_clear_bonus_credited = ledger_init

	# Act — serialize → deserialize on a fresh instance B
	var data: Dictionary = economy_a.get_save_data()
	var economy_b: Node = _make_economy()
	economy_b.load_save_data(data)

	# Assert — gold + lifetime exact
	assert_int(economy_b.get_gold_balance()).is_equal(12345)
	assert_int(economy_b.get_lifetime_gold_earned()).is_equal(98765)

	# Assert — ledger has exactly 3 keys (forest_reach_f1, _f2, _f3 → 500, 1200, 1500)
	# F4 + F5 must NOT be present (absent != zero in this contract).
	# Sprint 17 schema v2: keys are "<biome_id>_f<idx>" strings.
	var ledger: Dictionary = economy_b._floor_clear_bonus_credited
	assert_int(ledger.size()).is_equal(3)
	assert_int(int(ledger["forest_reach_f1"])).is_equal(500)
	assert_int(int(ledger["forest_reach_f2"])).is_equal(1200)
	assert_int(int(ledger["forest_reach_f3"])).is_equal(1500)
	assert_bool(ledger.has("forest_reach_f4")).is_false()
	assert_bool(ledger.has("forest_reach_f5")).is_false()

	# Cleanup
	economy_a.free()
	economy_b.free()


# ---------------------------------------------------------------------------
# Test 2 — AC H-11 boundary: empty ledger round-trips correctly
# ---------------------------------------------------------------------------
func test_h11_round_trip_empty_ledger_round_trips_to_empty() -> void:
	# Arrange
	var economy_a: Node = _make_economy()
	economy_a._gold_balance = 100
	economy_a._lifetime_gold_earned = 100
	# leave _floor_clear_bonus_credited as the default {} typed dict

	# Act
	var data: Dictionary = economy_a.get_save_data()
	var economy_b: Node = _make_economy()
	economy_b.load_save_data(data)

	# Assert
	assert_int(economy_b._floor_clear_bonus_credited.size()).is_equal(0)
	assert_int(economy_b.get_gold_balance()).is_equal(100)

	# Cleanup
	economy_a.free()
	economy_b.free()


# ---------------------------------------------------------------------------
# Test 3 — AC H-11 boundary: very large gold values near GOLD_SANITY_CAP round-trip exactly
# ---------------------------------------------------------------------------
func test_h11_round_trip_gold_at_sanity_cap_preserves_exact_value() -> void:
	# Arrange — exactly at the cap (1 trillion)
	var economy_a: Node = _make_economy()
	economy_a._gold_balance = EconomyScript.GOLD_SANITY_CAP
	economy_a._lifetime_gold_earned = EconomyScript.GOLD_SANITY_CAP * 2  # lifetime is unclamped

	# Act
	var data: Dictionary = economy_a.get_save_data()
	var economy_b: Node = _make_economy()
	economy_b.load_save_data(data)

	# Assert
	assert_int(economy_b.get_gold_balance()).is_equal(EconomyScript.GOLD_SANITY_CAP)
	assert_int(economy_b.get_lifetime_gold_earned()).is_equal(EconomyScript.GOLD_SANITY_CAP * 2)

	# Cleanup
	economy_a.free()
	economy_b.free()


# ---------------------------------------------------------------------------
# Test 4 — AC H-11 reclaim path: post-restore try_award_floor_clear credits delta
#   F3 was LOSING-half-credited at 1500. WIN re-clear at 3000 should credit
#   delta=1500. ledger advances to 3000. first_clear_awarded must NOT re-fire
#   (already credited pre-save — already > 0 in restored ledger).
# ---------------------------------------------------------------------------
func test_h11_reclaim_path_post_restore_credit_the_gap_no_first_clear_re_emit() -> void:
	# Arrange — restore state with F3 partially credited at 1500
	var economy_a: Node = _make_economy()
	economy_a._gold_balance = 12345
	economy_a._lifetime_gold_earned = 98765
	var ledger_init: Dictionary[String, int] = {"forest_reach_f1": 500, "forest_reach_f2": 1200, "forest_reach_f3": 1500}
	economy_a._floor_clear_bonus_credited = ledger_init

	var data: Dictionary = economy_a.get_save_data()
	var economy_b: Node = _make_economy()
	economy_b.load_save_data(data)

	var first_clear_emissions: Array[int] = []
	economy_b.first_clear_awarded.connect(func(biome_id: String, floor_index: int) -> void:
			first_clear_emissions.append(floor_index)
	)

	# Act — WIN at F3 with bonus_amount=3000 (delta = 3000 - 1500 = 1500)
	var awarded: bool = economy_b.try_award_floor_clear("forest_reach", 3, 3000)

	# Assert — credit-the-gap semantic, ledger advances, first_clear_awarded NOT re-fired
	assert_bool(awarded).is_true()
	assert_int(economy_b.get_gold_balance()).is_equal(12345 + 1500)
	assert_int(int(economy_b._floor_clear_bonus_credited["forest_reach_f3"])).is_equal(3000)
	# first_clear_awarded did NOT fire because already > 0 pre-save (already credited milestone)
	assert_int(first_clear_emissions.size()).is_equal(0)

	# Cleanup
	economy_a.free()
	economy_b.free()


# ---------------------------------------------------------------------------
# Test 5 — AC: signal-quiet during restore
#   Both gold_changed and first_clear_awarded MUST stay silent throughout
#   load_save_data, even when restoring from zero-state to large balance.
# ---------------------------------------------------------------------------
func test_load_save_data_is_signal_quiet_zero_emissions_on_either_signal() -> void:
	# Arrange — large delta from initial-zero to restored 12345
	var economy_a: Node = _make_economy()
	economy_a._gold_balance = 12345
	economy_a._lifetime_gold_earned = 98765
	var ledger_init: Dictionary[String, int] = {"forest_reach_f1": 500, "forest_reach_f3": 1500}
	economy_a._floor_clear_bonus_credited = ledger_init
	var data: Dictionary = economy_a.get_save_data()

	var economy_b: Node = _make_economy()
	var gold_emissions: Array[int] = []
	var first_clear_emissions: Array[int] = []
	economy_b.gold_changed.connect(
		func(_new_balance: int, _delta: int, _reason: String) -> void:
			gold_emissions.append(1)
	)
	economy_b.first_clear_awarded.connect(
		func(_floor_index: int) -> void:
			first_clear_emissions.append(1)
	)

	# Act
	economy_b.load_save_data(data)

	# Assert — zero emissions on either signal
	assert_int(gold_emissions.size()).is_equal(0)
	assert_int(first_clear_emissions.size()).is_equal(0)
	# Sanity — state was actually restored
	assert_int(economy_b.get_gold_balance()).is_equal(12345)

	# Cleanup
	economy_a.free()
	economy_b.free()


# ---------------------------------------------------------------------------
# Test 6 — AC: schema_version mismatch (V0) aborts load with state unchanged
# ---------------------------------------------------------------------------
func test_load_save_data_with_unsupported_schema_version_v0_aborts_and_preserves_state() -> void:
	# Arrange — pre-load state we expect to survive the failed load
	var economy: Node = _make_economy()
	economy._gold_balance = 999
	economy._lifetime_gold_earned = 999
	var ledger_init: Dictionary[String, int] = {"forest_reach_f1": 100}
	economy._floor_clear_bonus_credited = ledger_init

	var bad_data: Dictionary = {
		"schema_version": 0,
		"gold_balance": 12345,
		"lifetime_gold_earned": 98765,
		"floor_clear_bonus_credited": {},
	}

	# Act
	economy.load_save_data(bad_data)

	# Assert — pre-load state intact (load aborted)
	assert_int(economy.get_gold_balance()).is_equal(999)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(999)
	assert_int(economy._floor_clear_bonus_credited.size()).is_equal(1)
	assert_int(int(economy._floor_clear_bonus_credited["forest_reach_f1"])).is_equal(100)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 7 — AC: schema_version mismatch (V3 future version) also aborts
# ---------------------------------------------------------------------------
func test_load_save_data_with_future_schema_version_v3_aborts_and_preserves_state() -> void:
	# Arrange
	var economy: Node = _make_economy()
	economy._gold_balance = 555

	var future_data: Dictionary = {
		"schema_version": 3,
		"gold_balance": 12345,
		"lifetime_gold_earned": 98765,
		"floor_clear_bonus_credited": {},
	}

	# Act
	economy.load_save_data(future_data)

	# Assert
	assert_int(economy.get_gold_balance()).is_equal(555)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 8 — AC: missing schema_version aborts with state unchanged
# ---------------------------------------------------------------------------
func test_load_save_data_with_missing_schema_version_aborts_and_preserves_state() -> void:
	# Arrange
	var economy: Node = _make_economy()
	economy._gold_balance = 777

	var bad_data: Dictionary = {
		# schema_version intentionally absent
		"gold_balance": 12345,
		"lifetime_gold_earned": 98765,
		"floor_clear_bonus_credited": {},
	}

	# Act
	economy.load_save_data(bad_data)

	# Assert
	assert_int(economy.get_gold_balance()).is_equal(777)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 9 — AC: missing optional keys default to safe values (load still succeeds)
#   schema_version present, but gold/lifetime/ledger all absent. Per the
#   ADR-0004 partial-data convention, defaults apply rather than aborting.
# ---------------------------------------------------------------------------
func test_load_save_data_with_only_schema_version_applies_safe_defaults() -> void:
	# Arrange — pre-load state must be overwritten by defaults (load succeeded)
	var economy: Node = _make_economy()
	economy._gold_balance = 777
	economy._lifetime_gold_earned = 777
	var ledger_init: Dictionary[String, int] = {"forest_reach_f1": 100}
	economy._floor_clear_bonus_credited = ledger_init

	var minimal_data: Dictionary = {
		"schema_version": EconomyScript.SAVE_SCHEMA_VERSION,
	}

	# Act
	economy.load_save_data(minimal_data)

	# Assert — defaults applied across the board
	assert_int(economy.get_gold_balance()).is_equal(0)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(0)
	assert_int(economy._floor_clear_bonus_credited.size()).is_equal(0)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 10 — AC: forward-compat — extra unknown keys are tolerated
# ---------------------------------------------------------------------------
func test_load_save_data_tolerates_extra_unknown_keys_for_forward_compat() -> void:
	# Arrange
	var economy: Node = _make_economy()
	var data: Dictionary = {
		"schema_version": EconomyScript.SAVE_SCHEMA_VERSION,
		"gold_balance": 500,
		"lifetime_gold_earned": 1000,
		"floor_clear_bonus_credited": {},
		# Unknown keys a future schema might add
		"future_field_xyz": "some_value",
		"another_future_field": [1, 2, 3],
	}

	# Act
	economy.load_save_data(data)

	# Assert — known keys hydrated, unknown keys silently ignored (no error, no abort)
	assert_int(economy.get_gold_balance()).is_equal(500)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(1000)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 11 — AC: post-restore try_spend works correctly (no "uninitialized" state)
# ---------------------------------------------------------------------------
func test_post_restore_try_spend_deducts_gold_normally() -> void:
	# Arrange
	var economy_a: Node = _make_economy()
	economy_a._gold_balance = 1000
	economy_a._lifetime_gold_earned = 5000
	var data: Dictionary = economy_a.get_save_data()

	var economy_b: Node = _make_economy()
	economy_b.load_save_data(data)

	# Act — post-restore spend
	var spent: bool = economy_b.try_spend(300, "test_spend")

	# Assert — spend works, balance updates correctly
	assert_bool(spent).is_true()
	assert_int(economy_b.get_gold_balance()).is_equal(700)

	# Cleanup
	economy_a.free()
	economy_b.free()


# ---------------------------------------------------------------------------
# Test 12 — AC: post-restore add_gold works correctly + emits gold_changed
#   Verifies that after a signal-quiet restore, the next foreground add_gold
#   emits gold_changed normally (the restore did not break the signal path).
# ---------------------------------------------------------------------------
func test_post_restore_add_gold_emits_gold_changed_normally() -> void:
	# Arrange
	var economy_a: Node = _make_economy()
	economy_a._gold_balance = 100
	var data: Dictionary = economy_a.get_save_data()

	var economy_b: Node = _make_economy()
	economy_b.load_save_data(data)

	var emissions: Array[Array] = []
	economy_b.gold_changed.connect(
		func(new_balance: int, delta: int, reason: String) -> void:
			emissions.append([new_balance, delta, reason])
	)

	# Act
	economy_b.add_gold(50)

	# Assert — exactly one emission for the post-restore add
	assert_int(emissions.size()).is_equal(1)
	assert_int(emissions[0][0]).is_equal(150)
	assert_int(emissions[0][1]).is_equal(50)
	assert_str(emissions[0][2]).is_equal("add_gold")

	# Cleanup
	economy_a.free()
	economy_b.free()


# ---------------------------------------------------------------------------
# Test 13 — JSON round-trip type-safety: ledger keys round-trip through
#   JSON (where int keys become String keys and ints become floats).
#   This is the production code path through SaveLoadSystem's JSON envelope.
# ---------------------------------------------------------------------------
func test_load_save_data_after_json_round_trip_coerces_string_keys_and_float_values() -> void:
	# Arrange — author state, serialize through JSON to simulate envelope round-trip
	var economy_a: Node = _make_economy()
	economy_a._gold_balance = 12345
	economy_a._lifetime_gold_earned = 98765
	var ledger_init: Dictionary[String, int] = {"forest_reach_f1": 500, "forest_reach_f3": 1500}
	economy_a._floor_clear_bonus_credited = ledger_init
	var data: Dictionary = economy_a.get_save_data()
	var json_str: String = JSON.stringify(data)
	var round_tripped: Variant = JSON.parse_string(json_str)
	assert_object(round_tripped).is_not_null()

	# Confirm JSON did the type-mangling we expect (sanity — guards against future
	# Godot JSON behavior changes)
	var rt_dict: Dictionary = round_tripped as Dictionary
	# Numeric values come back as TYPE_FLOAT after JSON round-trip
	assert_int(typeof(rt_dict["gold_balance"])).is_equal(TYPE_FLOAT)
	# Dict keys come back as String after JSON round-trip
	for key: Variant in (rt_dict["floor_clear_bonus_credited"] as Dictionary):
		assert_int(typeof(key)).is_equal(TYPE_STRING)
		break  # one is enough to confirm the contract

	# Act
	var economy_b: Node = _make_economy()
	economy_b.load_save_data(rt_dict)

	# Assert — load_save_data coerced the JSON-mangled types back into the typed shape
	assert_int(economy_b.get_gold_balance()).is_equal(12345)
	assert_int(economy_b.get_lifetime_gold_earned()).is_equal(98765)
	assert_int(economy_b._floor_clear_bonus_credited.size()).is_equal(2)
	assert_int(int(economy_b._floor_clear_bonus_credited["forest_reach_f1"])).is_equal(500)
	assert_int(int(economy_b._floor_clear_bonus_credited["forest_reach_f3"])).is_equal(1500)

	# Cleanup
	economy_a.free()
	economy_b.free()


# ---------------------------------------------------------------------------
# Test 14 — Defensive: corrupt save with negative gold_balance clamps to 0
# ---------------------------------------------------------------------------
func test_load_save_data_with_negative_gold_balance_clamps_to_zero() -> void:
	# Arrange
	var economy: Node = _make_economy()
	var corrupt_data: Dictionary = {
		"schema_version": EconomyScript.SAVE_SCHEMA_VERSION,
		"gold_balance": -999,
		"lifetime_gold_earned": 0,
		"floor_clear_bonus_credited": {},
	}

	# Act
	economy.load_save_data(corrupt_data)

	# Assert — clamped to 0 with push_warning (warning is observable via the
	# manual log; we assert the state-side outcome here)
	assert_int(economy.get_gold_balance()).is_equal(0)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 15 — Defensive: corrupt save with gold > GOLD_SANITY_CAP clamps to cap
# ---------------------------------------------------------------------------
func test_load_save_data_with_gold_exceeding_sanity_cap_clamps_to_cap() -> void:
	# Arrange
	var economy: Node = _make_economy()
	var corrupt_data: Dictionary = {
		"schema_version": EconomyScript.SAVE_SCHEMA_VERSION,
		"gold_balance": EconomyScript.GOLD_SANITY_CAP + 999_999,
		"lifetime_gold_earned": 0,
		"floor_clear_bonus_credited": {},
	}

	# Act
	economy.load_save_data(corrupt_data)

	# Assert
	assert_int(economy.get_gold_balance()).is_equal(EconomyScript.GOLD_SANITY_CAP)

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 16 — get_save_data returns a deep copy (caller mutations don't bleed back)
# ---------------------------------------------------------------------------
func test_get_save_data_returns_deep_copy_caller_mutation_does_not_leak_into_economy() -> void:
	# Arrange
	var economy: Node = _make_economy()
	var ledger_init: Dictionary[String, int] = {"forest_reach_f1": 500}
	economy._floor_clear_bonus_credited = ledger_init

	# Act — caller mutates the returned dict's nested ledger.
	# Sprint 17 schema v2 detail: the returned ledger is now a typed
	# Dictionary[String, int], so the synthetic mutation key must also be
	# a String. Use "hack_f99" so it's distinguishable from any biome's
	# legitimate "<biome_id>_f<idx>" key.
	var data: Dictionary = economy.get_save_data()
	(data["floor_clear_bonus_credited"] as Dictionary)["hack_f99"] = 999_999

	# Assert — Economy's internal ledger is untouched
	assert_bool(economy._floor_clear_bonus_credited.has("hack_f99")).is_false()
	assert_int(economy._floor_clear_bonus_credited.size()).is_equal(1)

	# Cleanup
	economy.free()
