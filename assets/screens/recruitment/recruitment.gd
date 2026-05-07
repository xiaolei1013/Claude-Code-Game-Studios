## Recruit Screen — pool browser + recruit/refresh interaction surface.
##
## Sprint 16 S16-M1 candidate scaffold (pre-emptively authored 2026-05-07
## per the established cadence). Ships the contract layer + minimal .tscn
## layout per Recruit Screen GDD #21 §C.1 / §C.2 / §C.4 / §C.5 / §C.6.
## Visual polish (anchors + theme variations + portrait sourcing + final
## copy + toast UI) deferred to post-`/design-review` of GDD #21.
##
## Drift fixes from Cross-GDD Consistency Sweep 2026-05-07 applied:
## - try_recruit returns RecruitOutcome enum, NOT bool (match-on-enum path)
## - HeroRoster.hero_recruited 1-arg subscriber (NOT Recruitment's 3-arg
##   signal — both fire on recruit; screen subscribes to the roster-side
##   signal because it cares about the new HeroInstance shape)
## - Recruitment.get_refreshes_today() public accessor used (S16-N1 ✓
##   shipped this commit's predecessor)
extends Screen

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")
const RecruitmentScript = preload("res://src/core/recruitment/recruitment.gd")


# Layout: POOL_SIZE PoolEntry rows pre-defined in the .tscn (3 rows for
# MVP per Recruitment.POOL_SIZE = 3). Each row exposes named child nodes
# the .gd populates.
var POOL_SIZE: int = RecruitmentScript.POOL_SIZE


@onready var _pool_panel: PanelContainer = $PoolPanel
@onready var _pool_entries: Array[Control] = [
	$PoolPanel/PoolVBox/PoolEntry0,
	$PoolPanel/PoolVBox/PoolEntry1,
	$PoolPanel/PoolVBox/PoolEntry2,
]
@onready var _gold_counter: Label = $HeaderBar/HeaderHBox/GoldCounter
@onready var _back_button: Button = $HeaderBar/HeaderHBox/BackButton
@onready var _refresh_pool_button: Button = $FooterBar/RefreshPoolButton


# Per-tier XP cache (engine-code-rule pattern — pre-cache instead of
# resolving costs in render loop).
var _is_rendering: bool = false


func _ready() -> void:
	# Touch-feedback wired in _ready (one-time, .tscn-defined Buttons).
	# Per-row RecruitButtons are wired in on_enter (signal-bind per row).
	UIFrameworkScript.wire_touch_feedback(_back_button)
	UIFrameworkScript.wire_touch_feedback(_refresh_pool_button)


func on_enter() -> void:
	# Step 1: connect autoload signals (idempotent).
	if not Recruitment.pool_refreshed.is_connected(_on_pool_refreshed):
		Recruitment.pool_refreshed.connect(_on_pool_refreshed)
	# Drift-fix sweep: subscribe to HeroRoster's 1-arg hero_recruited (NOT
	# Recruitment's 3-arg). Per Recruit Screen GDD §F + the Cross-GDD
	# Consistency Sweep 2026-05-07 §hero_recruited disambiguation.
	if not HeroRoster.hero_recruited.is_connected(_on_hero_recruited):
		HeroRoster.hero_recruited.connect(_on_hero_recruited)
	if not Economy.gold_changed.is_connected(_on_gold_changed):
		Economy.gold_changed.connect(_on_gold_changed)

	# Step 2: button handlers.
	if not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if not _refresh_pool_button.pressed.is_connected(_on_refresh_pressed):
		_refresh_pool_button.pressed.connect(_on_refresh_pressed)
	# Per-row Recruit buttons — bind pool_index per row.
	for i: int in range(POOL_SIZE):
		var entry: Control = _pool_entries[i]
		var button: Button = entry.get_node("RecruitButton") as Button
		UIFrameworkScript.wire_touch_feedback(button)
		var bound_handler: Callable = _on_recruit_pressed.bind(i)
		if not button.pressed.is_connected(bound_handler):
			button.pressed.connect(bound_handler)

	# Step 3: initial render.
	_refresh_all()


func on_exit() -> void:
	if Recruitment.pool_refreshed.is_connected(_on_pool_refreshed):
		Recruitment.pool_refreshed.disconnect(_on_pool_refreshed)
	if HeroRoster.hero_recruited.is_connected(_on_hero_recruited):
		HeroRoster.hero_recruited.disconnect(_on_hero_recruited)
	if Economy.gold_changed.is_connected(_on_gold_changed):
		Economy.gold_changed.disconnect(_on_gold_changed)
	if _back_button != null and _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.disconnect(_on_back_pressed)
	if _refresh_pool_button != null and _refresh_pool_button.pressed.is_connected(_on_refresh_pressed):
		_refresh_pool_button.pressed.disconnect(_on_refresh_pressed)


func on_pause() -> void:
	pass


func on_resume() -> void:
	pass


# ---------------------------------------------------------------------------
# Render — per GDD §C.3 / §C.4
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_gold_counter()
	_refresh_pool_panel()
	_refresh_refresh_button_cost()


func _refresh_gold_counter() -> void:
	if _gold_counter == null:
		return
	# str() format until UIFramework.format_short_number lands (cross-GDD
	# sweep additional gap noted in S16-M2 commit).
	_gold_counter.text = "%d gold" % Economy.get_gold_balance()


func _refresh_pool_panel() -> void:
	var pool: Array[String] = Recruitment.get_recruit_pool()
	for i: int in range(POOL_SIZE):
		var entry: Control = _pool_entries[i]
		if i >= pool.size():
			# Empty pool slot — hide the row per GDD §C.9 empty-pool
			# placeholder (placeholder rendering is .tscn-deferred polish).
			entry.visible = false
			continue
		entry.visible = true
		_render_pool_entry(entry, i, pool[i])


func _render_pool_entry(entry: Control, pool_index: int, class_id: String) -> void:
	var class_name_label: Label = entry.get_node("EntryDetails/ClassNameLabel") as Label
	var cost_label: Label = entry.get_node("EntryDetails/CostLabel") as Label
	var owned_label: Label = entry.get_node("EntryDetails/OwnedLabel") as Label
	var recruit_button: Button = entry.get_node("RecruitButton") as Button

	# Resolve class via DataRegistry (defensive — orphan class per §C.4 step 2.b).
	var class_data: Resource = DataRegistry.resolve("classes", class_id)
	if class_data == null:
		# Hide row + push_warning per defensive contract.
		entry.visible = false
		push_warning("[RecruitScreen] orphan class_id '%s' — hiding row" % class_id)
		return

	# ClassNameLabel — locale-aware via display_name_key when present;
	# fallback to capitalized class_id for MVP.
	if "display_name_key" in class_data and String(class_data.display_name_key) != "":
		class_name_label.text = tr(String(class_data.display_name_key))
	else:
		class_name_label.text = class_id.capitalize()

	# CostLabel via Recruitment.get_recruit_cost(pool_index).
	var cost: int = Recruitment.get_recruit_cost(pool_index)
	cost_label.text = "%d gold" % cost  # str() until format_short_number lands

	# OwnedLabel via HeroRoster.get_copies_owned.
	var copies: int = HeroRoster.get_copies_owned(class_id)
	owned_label.text = tr("recruit_owned_format") % copies

	# RecruitButton affordability gating.
	var affordable: bool = Economy.get_gold_balance() >= cost and cost > 0
	recruit_button.disabled = not affordable
	recruit_button.text = tr("dispatch_button") if false else "Recruit"  # Placeholder; tr key is "recruit_button" candidate post-/design-review


func _refresh_refresh_button_cost() -> void:
	if _refresh_pool_button == null:
		return
	var refreshes_today: int = Recruitment.get_refreshes_today()
	var cost: int = Recruitment.refresh_cost(refreshes_today)
	_refresh_pool_button.text = "Refresh Pool — %d gold" % cost
	_refresh_pool_button.disabled = Economy.get_gold_balance() < cost


# ---------------------------------------------------------------------------
# Interactions — per GDD §C.5 (recruit) / §C.6 (refresh) / Back nav
# ---------------------------------------------------------------------------

# Drift fix from Cross-GDD Consistency Sweep 2026-05-07 — try_recruit
# returns RecruitOutcome enum (NOT bool). Match-on-enum path.
func _on_recruit_pressed(pool_index: int) -> void:
	if pool_index < 0 or pool_index >= POOL_SIZE:
		push_warning(
			"[RecruitScreen] pool_index %d out of [0, %d) — race condition"
			% [pool_index, POOL_SIZE]
		)
		return
	# Match on the enum return value.
	var outcome: int = int(Recruitment.try_recruit(pool_index))
	match outcome:
		RecruitmentScript.RecruitOutcome.SUCCESS:
			# Signals (HeroRoster.hero_recruited 1-arg + Recruitment.hero_recruited
			# 3-arg + Economy.gold_changed) fire from try_recruit's atomic
			# dispatch. Screen subscribers re-render automatically.
			pass
		RecruitmentScript.RecruitOutcome.INSUFFICIENT_GOLD:
			_show_toast(tr("recruit_error_insufficient_gold"))
		RecruitmentScript.RecruitOutcome.ROSTER_FULL:
			_show_toast(tr("recruit_error_roster_full"))
		RecruitmentScript.RecruitOutcome.UNRESOLVABLE_CLASS_ID:
			_show_toast(tr("recruit_error_unresolvable_class"))
		RecruitmentScript.RecruitOutcome.INVALID_POOL_INDEX:
			# Defensive race; visibility check should prevent.
			push_warning("[RecruitScreen] try_recruit INVALID_POOL_INDEX")


func _on_refresh_pressed() -> void:
	# Per GDD §C.6: read cost via accessor pair; gate via affordability.
	# refresh_pool_paid handles the try_spend internally.
	if not Recruitment.refresh_pool_paid():
		# Returned false — most likely insufficient gold race.
		_show_toast(tr("recruit_error_insufficient_gold"))


func _on_back_pressed() -> void:
	SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)


# ---------------------------------------------------------------------------
# Signal handlers — re-render on autoload state changes
# ---------------------------------------------------------------------------

func _on_pool_refreshed(_new_pool: Array[String]) -> void:
	_refresh_pool_panel()
	_refresh_refresh_button_cost()


# Drift fix: subscribe to HeroRoster's 1-arg hero_recruited (NOT
# Recruitment's 3-arg). Per Cross-GDD Consistency Sweep 2026-05-07.
func _on_hero_recruited(_instance: RefCounted) -> void:
	# A new hero of this class joined the roster — refresh the affected
	# entry's cost (jumps per ADR-0013 next-copy formula) + owned-count.
	_refresh_pool_panel()


func _on_gold_changed(_new_balance: int, _delta: int, _reason: String) -> void:
	# Gold mutation — refresh counter + every RecruitButton's affordability
	# gating + RefreshPoolButton's gating.
	_refresh_gold_counter()
	_refresh_pool_panel()
	_refresh_refresh_button_cost()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Toast helper — placeholder MVP scaffold per GDD §I OQ-21-X. Sprint 16+
# can refine via the formation_assignment toast pattern; for now,
# push_warning surfaces the message in dev consoles. Real Toast UI
# wiring (ToastLabel + Tween fade) is .tscn-side polish deferred to
# post-/design-review.
func _show_toast(message: String) -> void:
	push_warning("[RecruitScreen] toast: %s" % message)
