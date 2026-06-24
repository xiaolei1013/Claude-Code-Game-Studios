# Regression guard for the reward-FLOAT trigger policy (Sprint 30 S30-S1).
#
# dungeon_run_view floats a rising "+N gold" on a gold-crediting kill and a "Lv N"
# on hero_leveled (GDD #27 OQ-27-1 reward beats). UIFramework.should_float_reward()
# is the PURE gate, kept beside is_gold_pulse_reason so the policy is one testable
# predicate decoupled from the screen scene. It floats ONLY those two discrete,
# human-frequency beats — never the per-tick "add_gold" idle drip, and never a
# per-hit/damage event (the resolver aggregates DPS and emits no per-hit signal,
# ADR-0025 §C.5, so floating one would be a fiction the resolver can't back). A
# zero-gold kill (unknown tier → base 0) also stays silent. These tests pin that
# vocabulary so a regression — e.g. floating the idle drip — fails loudly.
extends GdUnitTestSuite


func test_should_float_reward_positive_gold_kill_floats() -> void:
	# Arrange / Act / Assert — a kill that credited gold floats a "+N" number.
	assert_bool(UIFramework.should_float_reward("gold_kill", 5)).is_true() \
		.override_failure_message(
			"a kill crediting 5 gold must float a +N reward number.")


func test_should_float_reward_zero_or_negative_gold_kill_does_not_float() -> void:
	# Arrange — a zero-gold kill (e.g. an unknown tier → base 0) earns no float;
	# a negative amount is defensive (should never occur, must stay silent).
	var no_float_amounts: Array[int] = [0, -3]

	# Act / Assert
	for amount: int in no_float_amounts:
		assert_bool(UIFramework.should_float_reward("gold_kill", amount)).is_false() \
			.override_failure_message(
				"a gold_kill crediting %d gold must NOT float a reward number." % amount)


func test_should_float_reward_level_up_always_floats() -> void:
	# Arrange — level_up is a discrete reward beat; it floats regardless of the
	# (ignored) amount arg, including the default 0.
	var amounts: Array[int] = [0, 1, 99]

	# Act / Assert
	for amount: int in amounts:
		assert_bool(UIFramework.should_float_reward("level_up", amount)).is_true() \
			.override_failure_message(
				"a hero level-up must always float, independent of amount (%d)." % amount)
	# And the no-arg form (default amount) must also float.
	assert_bool(UIFramework.should_float_reward("level_up")).is_true() \
		.override_failure_message("level_up must float with the default amount arg.")


func test_should_float_reward_non_reward_events_do_not_float() -> void:
	# Arrange — the idle drip's "add_gold" reason, per-hit/damage events (none exist
	# to subscribe to — ADR-0025 §C.5), and the empty event must all stay silent,
	# even with a positive amount (the event_type, not the amount, gates these).
	var silent_events: Array[String] = ["add_gold", "per_hit", "damage", "first_launch_seed", ""]

	# Act / Assert
	for event: String in silent_events:
		assert_bool(UIFramework.should_float_reward(event, 99)).is_false() \
			.override_failure_message(
				"'%s' is not a discrete reward beat and must NOT float." % event)
