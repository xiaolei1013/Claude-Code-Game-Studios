# US-004 — Economy.get_config() public-surface coverage.
#
# Per ADR-0013 §Requirements: Economy.get_config() is the single source of
# truth for tuning knobs (BASE_DRIP, BASE_RECRUIT, FLOOR_CLEAR_BONUS, etc.).
# Consumers call this getter rather than reading the private _config field.
#
# This test closes the test-coverage-backfill audit gap for US-004: the
# pre-existing economy/ suite covers all other public functions but did not
# directly exercise the get_config() accessor. Other public methods
# (recruit_cost, level_cost, compute_offline_batch) hit `_config` indirectly,
# but the accessor itself had no direct happy-path nor null-state edge case.
#
# Test groups:
#   - Happy path against /root/Economy: returns the registered EconomyConfig
#     (BASE_RECRUIT non-empty, identity equality on repeat calls).
#   - Edge — pre-_ready path: a fresh Economy.new() not added to the tree
#     has _config == null; get_config() returns null without raising
#     (matches the documented boot-failure semantic on src/core/economy/
#     economy.gd:170-175).
#   - Edge — explicit-null override: simulating the post-_ready DataRegistry-
#     miss path, get_config() returns null after _config is reset to null.
#   - Pure-accessor invariant: get_config() does not mutate state.
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")
const EconomyConfigScript = preload("res://src/core/economy/economy_config.gd")


# ===========================================================================
# Happy path — live autoload after boot resolves the registered config
# ===========================================================================

func test_get_config_after_ready_returns_registered_economy_config_instance() -> void:
	# Arrange — /root/Economy has run _ready and resolved EconomyConfig from
	# DataRegistry per ADR-0013 §Requirements.
	var economy: Node = get_tree().root.get_node_or_null("Economy")

	# Act
	var cfg: EconomyConfig = economy.get_config()

	# Assert — the returned config is non-null, of the right type, and carries
	# populated BASE_RECRUIT (proves DataRegistry resolution actually completed).
	assert_object(cfg).is_not_null()
	assert_bool(cfg is EconomyConfig).is_true()
	assert_bool(cfg.BASE_RECRUIT.size() > 0).is_true()


func test_get_config_returns_same_instance_on_repeat_calls() -> void:
	# Arrange
	var economy: Node = get_tree().root.get_node_or_null("Economy")

	# Act — two calls in succession
	var cfg_a: EconomyConfig = economy.get_config()
	var cfg_b: EconomyConfig = economy.get_config()

	# Assert — identity equality: both calls return the same cached instance.
	# Per ADR-0013 §Requirements get_config is a pure accessor over the resolved
	# field; it MUST NOT re-resolve from DataRegistry on each call.
	assert_object(cfg_a).is_same(cfg_b)


# ===========================================================================
# Edge — pre-_ready: bare Economy.new() instance has null _config
# ===========================================================================

func test_get_config_before_ready_returns_null_without_raising() -> void:
	# Arrange — preload-and-new path used by other unit tests; instance is NOT
	# added to the tree, so _ready has not fired and _config is its initializer
	# default (null).
	var economy: Node = EconomyScript.new()
	auto_free(economy)

	# Act — calling get_config on a pre-_ready instance must not raise.
	var cfg: EconomyConfig = economy.get_config()

	# Assert — null is the documented return (src/core/economy/economy.gd:170-175).
	assert_object(cfg).is_null()


# ===========================================================================
# Edge — post-_ready DataRegistry-miss: explicit null override
# ===========================================================================

func test_get_config_after_explicit_null_override_returns_null() -> void:
	# Arrange — same pattern as economy_recruit_cost_test.gd
	# test_recruit_cost_null_config_returns_minus_one. add_child triggers _ready
	# which populates _config; nulling AFTER add_child simulates the
	# DataRegistry-resolve-returned-null branch on src/core/economy/
	# economy.gd:222-227.
	var economy: Node = EconomyScript.new()
	add_child(economy)
	auto_free(economy)
	economy._config = null

	# Act
	var cfg: EconomyConfig = economy.get_config()

	# Assert
	assert_object(cfg).is_null()


# ===========================================================================
# Pure-accessor invariant
# ===========================================================================

func test_get_config_does_not_mutate_gold_balance_or_lifetime() -> void:
	# Arrange — capture pre-call state from the live autoload.
	var economy: Node = get_tree().root.get_node_or_null("Economy")
	var gold_before: int = economy.get_gold_balance()
	var lifetime_before: int = economy.get_lifetime_gold_earned()

	# Act
	economy.get_config()
	economy.get_config()
	economy.get_config()

	# Assert — pure accessor; no side effects on Economy state.
	assert_int(economy.get_gold_balance()).is_equal(gold_before)
	assert_int(economy.get_lifetime_gold_earned()).is_equal(lifetime_before)


func test_get_config_returns_handed_seeded_config_via_field_override() -> void:
	# Arrange — simulate the unit-test pattern from economy_recruit_cost_test
	# (test_recruit_cost_tier_not_in_base_recruit_returns_minus_one): hand-seed
	# a synthetic EconomyConfig and verify get_config returns the seeded
	# instance (NOT the autoload-registered one).
	var economy: Node = EconomyScript.new()
	add_child(economy)
	auto_free(economy)
	var cfg: EconomyConfig = EconomyConfigScript.new()
	cfg.BASE_RECRUIT = {1: 999, 2: 8000}
	cfg.RECRUIT_RATIO = 1.8
	economy._config = cfg

	# Act
	var observed: EconomyConfig = economy.get_config()

	# Assert — identity equality with the seeded instance + value passthrough.
	assert_object(observed).is_same(cfg)
	assert_int(observed.BASE_RECRUIT[1]).is_equal(999)
