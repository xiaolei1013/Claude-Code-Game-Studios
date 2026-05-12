# Economy first-launch STARTING_GOLD seed tests, per Onboarding GDD #29
# §C.1 + §D.1 + AC-29-03.
#
# Test groups:
#   A — _on_first_launch seeds _gold_balance to STARTING_GOLD when _config present
#   B — _on_first_launch emits gold_changed with reason "first_launch_seed"
#   C — _on_first_launch handles null _config defensively (push_error, no emit)
#   D — first_launch signal subscription wired at _ready (live autoload check)
extends GdUnitTestSuite

const EconomyScript = preload("res://src/core/economy/economy.gd")
const EconomyConfigScript = preload("res://src/core/economy/economy_config.gd")


# ---------------------------------------------------------------------------
# Hygiene barrier — snapshot/restore live Economy state per recruitment_try_recruit_test.gd
# precedent. Critical because emitting first_launch on the live autoload would
# otherwise contaminate gold balance across tests.
# ---------------------------------------------------------------------------

var _snapshot_economy: Dictionary = {}


func before_test() -> void:
	var economy: Node = get_tree().root.get_node_or_null("Economy")
	_snapshot_economy = economy.get_save_data() if economy != null else {}


func after_test() -> void:
	var economy: Node = get_tree().root.get_node_or_null("Economy")
	if economy != null and not _snapshot_economy.is_empty():
		economy.load_save_data(_snapshot_economy)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Builds a standalone Economy + EconomyConfig + minimal sl_stub so the
## first-launch path can be exercised in isolation from /root/SaveLoadSystem.
## Returns the Economy instance with _config already injected.
func _make_isolated_economy(starting_gold: int = 100) -> Node:
	var cfg: EconomyConfig = EconomyConfigScript.new()
	cfg.STARTING_GOLD = starting_gold
	var econ: Node = EconomyScript.new()
	add_child(econ)
	auto_free(econ)
	# Bypass _ready's DataRegistry path by directly assigning _config — the
	# test target is _on_first_launch's behavior, not the wiring (Group D
	# covers the wiring assertion separately against the live autoload).
	econ.set("_config", cfg)
	return econ


# ---------------------------------------------------------------------------
# Spy infrastructure for gold_changed
# ---------------------------------------------------------------------------

var _gold_changed_calls: Array[Dictionary] = []


func _on_gold_changed_spy(new_balance: int, delta: int, reason: String) -> void:
	_gold_changed_calls.append({
		"new_balance": new_balance,
		"delta": delta,
		"reason": reason,
	})


# ===========================================================================
# Group A — _on_first_launch seeds _gold_balance to STARTING_GOLD
# ===========================================================================

func test_first_launch_seeds_gold_balance_to_starting_gold() -> void:
	# Arrange — isolated Economy with STARTING_GOLD = 100; _gold_balance = 0 default.
	var econ: Node = _make_isolated_economy(100)
	assert_int(int(econ.get("_gold_balance"))).is_equal(0)

	# Act — fire the first_launch handler directly.
	econ.call("_on_first_launch")

	# Assert — _gold_balance now = STARTING_GOLD.
	assert_int(int(econ.get("_gold_balance"))).is_equal(100)


func test_first_launch_seeds_with_custom_starting_gold_value() -> void:
	# AC: STARTING_GOLD is data-driven via EconomyConfig; the seed uses
	# whatever value is configured.
	var econ: Node = _make_isolated_economy(250)
	econ.call("_on_first_launch")
	assert_int(int(econ.get("_gold_balance"))).is_equal(250)


func test_first_launch_does_not_touch_lifetime_gold_earned() -> void:
	# AC: STARTING_GOLD is a gift, not earned — _lifetime_gold_earned stays 0.
	var econ: Node = _make_isolated_economy(100)
	econ.call("_on_first_launch")
	assert_int(int(econ.get("_lifetime_gold_earned"))).is_equal(0)


# ===========================================================================
# Group B — _on_first_launch emits gold_changed with reason "first_launch_seed"
# ===========================================================================

func test_first_launch_emits_gold_changed_with_seed_reason() -> void:
	var econ: Node = _make_isolated_economy(100)
	_gold_changed_calls.clear()
	econ.gold_changed.connect(_on_gold_changed_spy)

	econ.call("_on_first_launch")

	assert_int(_gold_changed_calls.size()).is_equal(1)
	var call: Dictionary = _gold_changed_calls[0]
	assert_int(int(call["new_balance"])).is_equal(100)
	assert_int(int(call["delta"])).is_equal(100)
	assert_str(String(call["reason"])).is_equal("first_launch_seed")

	if econ.gold_changed.is_connected(_on_gold_changed_spy):
		econ.gold_changed.disconnect(_on_gold_changed_spy)


# ===========================================================================
# Group C — _on_first_launch handles null _config defensively
# ===========================================================================

func test_first_launch_with_null_config_pushes_error_and_does_not_emit() -> void:
	# Arrange — economy with _config explicitly null (simulates DataRegistry boot failure).
	var econ: Node = EconomyScript.new()
	add_child(econ)
	auto_free(econ)
	econ.set("_config", null)

	_gold_changed_calls.clear()
	econ.gold_changed.connect(_on_gold_changed_spy)

	# Act — _on_first_launch should log push_error and return cleanly.
	econ.call("_on_first_launch")

	# Assert — no emit, no mutation. _gold_balance stays at default 0.
	assert_int(_gold_changed_calls.size()).is_equal(0)
	assert_int(int(econ.get("_gold_balance"))).is_equal(0)

	if econ.gold_changed.is_connected(_on_gold_changed_spy):
		econ.gold_changed.disconnect(_on_gold_changed_spy)


# ===========================================================================
# Group D — first_launch signal subscription wired at _ready (live autoload)
# ===========================================================================

func test_live_economy_autoload_is_connected_to_save_load_first_launch() -> void:
	# Verifies the canonical wiring per ADR-0003 §Signal Subscription rule.
	# If SaveLoadSystem.first_launch fires at boot (cold-start), Economy's
	# handler runs.
	var economy: Node = get_tree().root.get_node_or_null("Economy")
	var sl: Node = get_tree().root.get_node_or_null("SaveLoadSystem")
	assert_object(economy).is_not_null()
	assert_object(sl).is_not_null()
	assert_bool(sl.has_signal("first_launch")).is_true()

	# The economy._ready subscription pattern uses
	# `sl.first_launch.connect(_on_first_launch)`. Verify the connection exists.
	assert_bool(sl.first_launch.is_connected(Callable(economy, "_on_first_launch"))).override_failure_message(
		"Economy must subscribe to SaveLoadSystem.first_launch at _ready "
		+ "so first-launch (no save file) initializes _gold_balance to STARTING_GOLD. "
		+ "Connection NOT found — Onboarding GDD #29 AC-29-03 wiring contract violated."
	).is_true()
