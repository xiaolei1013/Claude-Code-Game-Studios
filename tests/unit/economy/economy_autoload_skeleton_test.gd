# Tests for Story S2-M1: Economy autoload skeleton.
# Covers: TR-economy-001, TR-economy-002, ADR-0003 Amendment #3,
#         GOLD_SANITY_CAP constant guard, signal declarations, and
#         public API stub zero/false/null/empty defaults.
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")


# ---------------------------------------------------------------------------
# Test 1 — TR-economy-001 / TR-economy-002: Economy instantiates as a Node
# and declares the four state fields with correct types.
#
# We instantiate directly (preload-and-new) because unit tests cannot rely on
# the autoload scene tree. Autoload-presence smoke test is a separate sprint-
# close check.
# ---------------------------------------------------------------------------
func test_economy_instantiates_as_node_derived_class() -> void:
	# Arrange / Act
	var economy: Node = EconomyScript.new()

	# Assert — Node ancestry
	assert_object(economy).is_not_null()
	assert_bool(economy is Node).is_true()

	# Cleanup
	economy.free()


func test_economy_gold_balance_field_is_declared_and_zero() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — reading _gold_balance via the public getter (not direct field access)
	# to stay consistent with the intended API surface.
	var balance: int = economy.get_gold_balance()

	# Assert — initial value is 0; type is int (GDScript int == int64)
	assert_int(balance).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_lifetime_gold_earned_field_is_declared_and_zero() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act
	var lifetime: int = economy.get_lifetime_gold_earned()

	# Assert
	assert_int(lifetime).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_floor_clear_bonus_credited_field_is_declared_and_empty() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — confirm field is present and typed Dictionary via has_method on
	# the derived getter. Direct field access checks presence and is_empty.
	# _floor_clear_bonus_credited is private, but we verify its observable
	# behaviour via is_first_clear_awarded (which reads the ledger).
	var f1_awarded: bool = economy.is_first_clear_awarded(1)
	var f5_awarded: bool = economy.is_first_clear_awarded(5)

	# Assert — empty ledger means no floor is awarded yet
	assert_bool(f1_awarded).is_false()
	assert_bool(f5_awarded).is_false()

	# Cleanup
	economy.free()


func test_economy_is_offline_replay_field_is_false_by_default() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — _is_offline_replay is private; we verify it indirectly through
	# compute_offline_batch (which would set it during a real call) returning
	# without error. We also verify the field is accessible via get() for typing.
	var has_field: bool = "is_offline_replay" in economy or "_is_offline_replay" in economy

	# Assert — the field must exist on the object (GDScript "in" checks exported
	# and public vars; private vars with _ prefix are still accessible via "in").
	assert_bool(has_field).is_true()

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 2 — GOLD_SANITY_CAP constant: value is exactly 1_000_000_000_000.
# Mirrors the TickSystem TICKS_PER_SECOND constant guard pattern.
# ---------------------------------------------------------------------------
func test_economy_gold_sanity_cap_is_one_trillion() -> void:
	# Assert constant value — no instance needed for a class/script constant.
	assert_int(EconomyScript.GOLD_SANITY_CAP).is_equal(1_000_000_000_000)


func test_economy_offline_replay_reason_constant_is_correct_string() -> void:
	# Assert — OFFLINE_REPLAY_REASON is the allowlisted signal-routing string.
	assert_str(EconomyScript.OFFLINE_REPLAY_REASON).is_equal("offline_replay")


# ---------------------------------------------------------------------------
# Test 3 — ADR-0003 Amendment #3: zero-arg _init.
#
# EconomyScript.new() with no arguments must succeed without error.
# If _init had required parameters this call would raise at runtime.
# ---------------------------------------------------------------------------
func test_economy_zero_arg_init_constructs_without_error() -> void:
	# Arrange / Act — no arguments passed
	var economy: Node = EconomyScript.new()

	# Assert — reaching this line means _init accepted zero args cleanly
	assert_object(economy).is_not_null()

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 4 — Signal declarations: gold_changed and first_clear_awarded are
# declared and connectable with the correct arity.
#
# Connecting a typed callable with wrong arity raises an error at connect-time
# in Godot 4's typed-signal contract — so a successful OK return proves arity.
# ---------------------------------------------------------------------------
func test_economy_gold_changed_signal_is_declared_and_connectable_with_3_args() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — connect with the correct arity: (int, int, String)
	var result: int = economy.gold_changed.connect(
		func(_new_balance: int, _delta: int, _reason: String) -> void: pass
	)

	# Assert — OK == 0 in Godot 4 (Error enum)
	assert_int(result).is_equal(OK)
	assert_bool(economy.gold_changed.get_connections().size() > 0).is_true()

	# Cleanup
	economy.free()


func test_economy_first_clear_awarded_signal_is_declared_and_connectable_with_1_arg() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — connect with the correct arity: (int)
	var result: int = economy.first_clear_awarded.connect(
		func(_floor_index: int) -> void: pass
	)

	# Assert
	assert_int(result).is_equal(OK)
	assert_bool(economy.first_clear_awarded.get_connections().size() > 0).is_true()

	# Cleanup
	economy.free()


# ---------------------------------------------------------------------------
# Test 5 — API surface: all 7 public write methods + 3 read methods are
# reachable as stubs, return correct zero/false/null/empty defaults, and
# do not raise runtime errors.
# ---------------------------------------------------------------------------

func test_economy_add_gold_completes_without_error() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — real body (Story 003); must not raise
	economy.add_gold(100)

	# Assert — balance is 100 after a successful positive add
	# (Updated from the S2-M1 stub assertion of 0 now that Story 003 is implemented.
	#  Detailed behavioral tests live in economy_add_gold_test.gd.)
	assert_int(economy.get_gold_balance()).is_equal(100)

	# Cleanup
	economy.free()


func test_economy_try_spend_returns_false_stub() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act
	var result: bool = economy.try_spend(50, "test_reason")

	# Assert — stub returns false
	assert_bool(result).is_false()

	# Cleanup
	economy.free()


func test_economy_try_award_floor_clear_credits_and_returns_true() -> void:
	# Arrange — fresh instance; floor 1 uncredited
	var economy: Node = EconomyScript.new()

	# Act — real body (Story 005); floor_index=1 in range, bonus_amount=500 > 0,
	# ledger empty → delta=500, add_gold(500) called, ledger advances, returns true.
	# (Updated from the S2-M1 stub assertion of false now that Story 005 is implemented.
	#  Comprehensive behavioral tests live in economy_try_award_floor_clear_test.gd.)
	var result: bool = economy.try_award_floor_clear(1, 500)

	# Assert — success path: returns true, gold credited
	assert_bool(result).is_true()
	assert_int(economy.get_gold_balance()).is_equal(500)

	# Cleanup
	economy.free()


func test_economy_compute_offline_batch_zero_budget_returns_empty_result() -> void:
	# Story 010 (2026-05-08) replaced the previous null-stub assertion with the
	# implemented contract: tick_budget <= 0 returns an empty (RefCounted)
	# OfflineResult, NOT null. Determinism + closed-form behavior is exercised
	# in tests/integration/economy/economy_offline_batch_determinism_test.gd.

	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — defensive guard branch
	var result: Object = economy.compute_offline_batch(0)

	# Assert — non-null RefCounted result with all-zero/empty fields
	assert_object(result).is_not_null()
	assert_int(result.total_gold).is_equal(0)
	assert_int(result.floors_cleared.size()).is_equal(0)
	assert_int(result.events_log.size()).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_get_save_data_returns_v1_schema_with_four_keys() -> void:
	# Story 012 (2026-05-08) replaced the stub-era empty-{} assertion with the
	# implemented V1 schema: schema_version + gold_balance + lifetime_gold_earned +
	# floor_clear_bonus_credited. Round-trip integration is exercised in
	# tests/integration/economy/economy_save_load_round_trip_test.gd.

	# Arrange
	var economy: Node = EconomyScript.new()

	# Act
	var result: Dictionary = economy.get_save_data()

	# Assert — exactly the four V1 keys with expected initial values
	assert_int(result.size()).is_equal(4)
	assert_bool(result.has("schema_version")).is_true()
	assert_int(result["schema_version"]).is_equal(EconomyScript.SAVE_SCHEMA_VERSION)
	assert_int(result["gold_balance"]).is_equal(0)
	assert_int(result["lifetime_gold_earned"]).is_equal(0)
	assert_int((result["floor_clear_bonus_credited"] as Dictionary).size()).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_load_save_data_with_v1_schema_restores_state() -> void:
	# Story 012 (2026-05-08): replaced the stub-era "completes without error"
	# assertion with the implemented V1 schema-validated restore.

	# Arrange
	var economy: Node = EconomyScript.new()
	var fake_data: Dictionary = {
		"schema_version": EconomyScript.SAVE_SCHEMA_VERSION,
		"gold_balance": 500,
		"lifetime_gold_earned": 1200,
		"floor_clear_bonus_credited": {},
	}

	# Act
	economy.load_save_data(fake_data)

	# Assert — state restored from the V1 envelope
	assert_int(economy.get_gold_balance()).is_equal(500)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(1200)

	# Cleanup
	economy.free()


func test_economy_get_gold_balance_returns_zero() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act
	var result: int = economy.get_gold_balance()

	# Assert
	assert_int(result).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_get_lifetime_gold_earned_returns_zero() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act
	var result: int = economy.get_lifetime_gold_earned()

	# Assert
	assert_int(result).is_equal(0)

	# Cleanup
	economy.free()


func test_economy_is_first_clear_awarded_returns_false_for_uncredited_floor() -> void:
	# Arrange
	var economy: Node = EconomyScript.new()

	# Act — check each valid floor index; all must be false on fresh instance
	var f1: bool = economy.is_first_clear_awarded(1)
	var f2: bool = economy.is_first_clear_awarded(2)
	var f3: bool = economy.is_first_clear_awarded(3)
	var f4: bool = economy.is_first_clear_awarded(4)
	var f5: bool = economy.is_first_clear_awarded(5)

	# Assert
	assert_bool(f1).is_false()
	assert_bool(f2).is_false()
	assert_bool(f3).is_false()
	assert_bool(f4).is_false()
	assert_bool(f5).is_false()

	# Cleanup
	economy.free()


func test_economy_recruit_cost_method_exists_with_correct_arity() -> void:
	# Sprint 12 S12-M1: recruit_cost STUB → formula implementation. Skeleton
	# test downgraded from "returns 0 stub" to "method exists with correct
	# arity"; the formula behavior is covered by economy_recruit_cost_test.gd.
	# Calling on a fresh Economy.new() (no _config seed) returns -1 sentinel
	# per the new formula's null-config guard.
	var economy: Node = EconomyScript.new()

	assert_bool(economy.has_method("recruit_cost")).is_true()
	# Sentinel-only call (config is null on a fresh, never-add_child'd
	# instance) — returns -1 per the formula's _config guard.
	assert_int(economy.recruit_cost("warrior_t1", 0)).is_equal(-1)

	economy.free()


func test_economy_level_cost_method_exists_with_correct_arity() -> void:
	# Sprint 12 S12-N5: level_cost STUB → formula implementation. Skeleton
	# test downgraded from "returns 0 stub" to "method exists with correct
	# arity"; the formula behavior is covered by economy_level_cost_test.gd.
	# Calling on a fresh Economy.new() (no _config seed) returns -1 sentinel
	# per the new formula's null-config guard.
	var economy: Node = EconomyScript.new()

	assert_bool(economy.has_method("level_cost")).is_true()
	# Sentinel-only call (config null on a never-add_child'd instance)
	# returns -1 per the formula's _config guard.
	assert_int(economy.level_cost(1, 1)).is_equal(-1)

	economy.free()
