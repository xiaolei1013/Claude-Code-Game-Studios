# Regression guard for the gold-counter pulse TRIGGER policy (Sprint 29 S29-1).
#
# The VFX GDD (#27 §F) lists the pulse triggers as {recruit, level_up, floor_clear,
# kill}. That list is WRONG against the shipped Economy: floor_clear and per-kill
# earns are both emitted as the generic "add_gold" reason — the SAME reason the
# foreground idle drip credits EVERY tick (economy.gd _on_tick) — so a literal
# wiring would have made the HUD throb continuously through any active run.
# UIFramework.is_gold_pulse_reason() encodes the corrected policy: pulse only on
# the discrete, player-initiated SPEND reasons Economy actually emits. These tests
# pin that vocabulary so re-introducing the GDD's earn reasons fails loudly.
extends GdUnitTestSuite


func test_is_gold_pulse_reason_spend_reasons_pulse() -> void:
	# Arrange — the exact spend reasons emitted by hero_detail_modal.gd ("level_up")
	# and recruitment.gd (the "recruit_<class_id>" prefix + "recruit_pool_refresh").
	var spend_reasons: Array[String] = [
		"level_up",
		"recruit_warrior",
		"recruit_mage",
		"recruit_pool_refresh",
	]

	# Act / Assert — every discrete player spend must pulse the counter.
	for reason: String in spend_reasons:
		assert_bool(UIFramework.is_gold_pulse_reason(reason)).is_true() \
			.override_failure_message(
				"'%s' is a discrete player spend and must pulse the gold counter." % reason)


func test_is_gold_pulse_reason_earn_and_system_reasons_do_not_pulse() -> void:
	# Arrange — the earn + system reasons Economy emits that must STAY silent.
	# "add_gold" is the load-bearing case: it fires on every idle tick and once per
	# kill, so pulsing on it would strobe the HUD throughout a run.
	var silent_reasons: Array[String] = [
		"add_gold",
		"first_launch_seed",
		"offline_replay",
		"offline_replay_aggregate",
		"",
	]

	# Act / Assert — none of these are discrete player actions; none may pulse.
	for reason: String in silent_reasons:
		assert_bool(UIFramework.is_gold_pulse_reason(reason)).is_false() \
			.override_failure_message(
				"'%s' is an earn/system reason and must NOT pulse the gold counter." % reason)


func test_pulse_gold_on_reason_does_not_pulse_on_idle_drip_reason() -> void:
	# Arrange — a fresh label has no font_color override; pulse_gold_counter sets one
	# while a pulse is in flight, so its absence after the call proves no pulse ran.
	var label: Label = Label.new()
	auto_free(label)

	# Act — the per-tick idle drip credits "add_gold"; the gate must swallow it.
	UIFramework.pulse_gold_on_reason(label, "add_gold")

	# Assert — no pulse started, so no transient font_color override exists.
	assert_bool(label.has_theme_color_override("font_color")).is_false() \
		.override_failure_message(
			"pulse_gold_on_reason must be a no-op for the 'add_gold' idle-drip reason — "
			+ "it left a font_color override, meaning a pulse was wrongly started.")
