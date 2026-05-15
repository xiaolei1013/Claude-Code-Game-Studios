# Sprint 21 S21-M2 — Recruit Screen theme implementation contract tests.
#
# Per design/ux/recruit-screen.md (UX-RS-04/08/09/10/11 affordability +
# cross-fade) + design/ux/interaction-patterns.md patterns #14
# (Affordability Gating) and #15 (Pool Entry Card).
#
# Test groups:
#   A — Theme has LedgerRowPanel variation defined (pattern #15 container)
#   B — RecruitButton modulate.a reflects affordability (pattern #14)
#   C — RefreshPoolButton modulate.a reflects affordability (pattern #14)
#   D — Cross-fade animation method exists + reduce-motion bypass works
extends GdUnitTestSuite

const RecruitmentScene := preload("res://assets/screens/recruitment/recruitment.tscn")

const PARCHMENT_THEME_PATH: String = "res://assets/ui/parchment_theme.tres"


# ===========================================================================
# Group A — Theme has LedgerRowPanel variation (pattern #15 Pool Entry Card)
# ===========================================================================

func test_parchment_theme_defines_ledger_row_panel_variation() -> void:
	# Pattern #15 (Pool Entry Card): container styling uses Guild-Ledger-Entry
	# visual register but base_type PanelContainer for non-button containers.
	# Sprint 21 S21-M2 ships this as deferred infrastructure (theme variation
	# only; .tscn application deferred to Sprint 22 polish).
	var theme: Theme = load(PARCHMENT_THEME_PATH) as Theme
	assert_object(theme).is_not_null()

	var base: StringName = theme.get_type_variation_base(&"LedgerRowPanel")
	assert_str(str(base)).override_failure_message(
		"LedgerRowPanel theme variation must extend &\"PanelContainer\" per "
		+ "interaction-patterns.md #15. Got: '%s'" % str(base)
	).is_equal("PanelContainer")


func test_parchment_theme_ledger_row_panel_has_panel_stylebox() -> void:
	# Sprint 22 polish that wraps PoolEntries needs the "panel" StyleBox slot
	# populated; this test guards against accidental variation drift.
	var theme: Theme = load(PARCHMENT_THEME_PATH) as Theme
	var stylebox: StyleBox = theme.get_stylebox("panel", &"LedgerRowPanel")
	assert_object(stylebox).override_failure_message(
		"LedgerRowPanel must define a 'panel' StyleBox slot (reuses the "
		+ "`ledger_row` sub_resource shared with LedgerRow)."
	).is_not_null()


# ===========================================================================
# Group B — RecruitButton modulate.a reflects affordability (pattern #14)
# ===========================================================================

func test_recruit_button_modulate_alpha_full_when_affordable() -> void:
	# Pattern #14 (Affordability Gating): affordable state shows 100% opacity.
	# Set up: give the player enough gold to afford the cheapest pool entry.
	# Recruit cost is class-data-driven; 10000 gold is comfortably above any
	# MVP recruit cost in the data files.
	Economy._gold_balance = 10000

	var instance: Node = RecruitmentScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()
	await get_tree().process_frame

	var entry: Control = instance.get_node("PoolPanel/PoolVBox/PoolEntry0") as Control
	if not entry.visible:
		# Empty pool in test env — skip this assertion path (defensive).
		return
	var btn: Button = entry.get_node("RecruitButton") as Button
	assert_object(btn).is_not_null()
	assert_float(btn.modulate.a).override_failure_message(
		"RecruitButton.modulate.a must be 1.0 when affordable per Affordability "
		+ "Gating pattern #14. Got: %f" % btn.modulate.a
	).is_equal_approx(1.0, 0.001)


func test_recruit_button_modulate_alpha_dimmed_when_unaffordable() -> void:
	# Pattern #14: unaffordable state shows 40% opacity. Zero out gold to
	# force unaffordable on all pool entries.
	Economy._gold_balance = 0

	var instance: Node = RecruitmentScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()
	await get_tree().process_frame

	var entry: Control = instance.get_node("PoolPanel/PoolVBox/PoolEntry0") as Control
	if not entry.visible:
		return
	var btn: Button = entry.get_node("RecruitButton") as Button
	assert_float(btn.modulate.a).override_failure_message(
		"RecruitButton.modulate.a must be 0.4 when unaffordable per Affordability "
		+ "Gating pattern #14. Got: %f" % btn.modulate.a
	).is_equal_approx(0.4, 0.001)


# ===========================================================================
# Group C — RefreshPoolButton modulate.a reflects affordability
# ===========================================================================

func test_refresh_pool_button_modulate_alpha_full_when_affordable() -> void:
	Economy._gold_balance = 100000

	var instance: Node = RecruitmentScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()
	await get_tree().process_frame

	var btn: Button = instance.get_node("FooterBar/RefreshPoolButton") as Button
	assert_float(btn.modulate.a).override_failure_message(
		"RefreshPoolButton.modulate.a must be 1.0 when affordable. Got: %f"
		% btn.modulate.a
	).is_equal_approx(1.0, 0.001)


func test_refresh_pool_button_modulate_alpha_dimmed_when_unaffordable() -> void:
	Economy._gold_balance = 0

	var instance: Node = RecruitmentScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()
	await get_tree().process_frame

	var btn: Button = instance.get_node("FooterBar/RefreshPoolButton") as Button
	assert_float(btn.modulate.a).override_failure_message(
		"RefreshPoolButton.modulate.a must be 0.4 when unaffordable. Got: %f"
		% btn.modulate.a
	).is_equal_approx(0.4, 0.001)


# ===========================================================================
# Group D — Cross-fade animation: reduce-motion bypass leaves entries at 1.0
# ===========================================================================

func test_play_pool_cross_fade_reduce_motion_skips_tween() -> void:
	# Reduce-motion path: entries should be fully visible (modulate.a = 1.0)
	# without any tween animation. Mock SceneManager.reduce_motion = true.
	var sm: Node = Engine.get_main_loop().root.get_node_or_null("SceneManager")
	var prior_value: bool = false
	var had_prop: bool = sm != null and ("reduce_motion" in sm)
	if had_prop:
		prior_value = bool(sm.get("reduce_motion"))
		sm.set("reduce_motion", true)

	var instance: Node = RecruitmentScene.instantiate()
	add_child(instance)
	auto_free(instance)
	instance.on_enter()
	await get_tree().process_frame

	# Manually invoke the cross-fade — same call path the pool_refreshed
	# signal triggers.
	instance._play_pool_cross_fade()
	# Reduce-motion path is synchronous (no tween); modulate.a is set immediately.
	for i: int in range(3):
		var entry: Control = instance.get_node("PoolPanel/PoolVBox/PoolEntry%d" % i) as Control
		assert_float(entry.modulate.a).override_failure_message(
			"PoolEntry%d.modulate.a must be 1.0 in reduce-motion path. Got: %f"
			% [i, entry.modulate.a]
		).is_equal_approx(1.0, 0.001)

	if had_prop:
		sm.set("reduce_motion", prior_value)
