## Hero Detail Modal — read-only-ish modal showing per-hero stats with a
## Level-Up button when affordable.
##
## Sprint 16 S16-M2 candidate scaffold (pre-emptively authored 2026-05-07
## per the established cadence). Ships the contract layer + minimal .tscn
## layout per Roster / Hero Detail Screen GDD #22 §C.1 / §C.2 / §C.5 / §C.6.
## Visual polish (anchors + final theme variation tuning + portrait
## sourcing) deferred to post-`/design-review` of GDD #22.
##
## Lifecycle (per GDD §C.2):
##   1. Caller (Guild Hall HeroCard tap) instantiates the modal scene
##   2. Caller calls set_target_hero(instance_id) BEFORE show_modal
##   3. Caller calls SceneManager.show_modal(self)
##   4. on_enter resolves hero + class via HeroRoster + DataRegistry,
##      subscribes to signals, renders all panels
##   5. Player taps LevelUp / Close / DimBackdrop to dismiss
##   6. on_exit disconnects signal handlers
##
## Atomic Level-Up transaction (per GDD §C.6):
##   try_spend(cost, "level_up") → on success → set_hero_level(id, +1)
##   No rollback handling needed — single-writer pattern per Recruitment §E.
extends Screen

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")

# ---------------------------------------------------------------------------
# Pre-show setter (per GDD §C.2)
# ---------------------------------------------------------------------------

## Target hero's instance_id. Set by caller (Guild Hall HeroCard tap)
## BEFORE SceneManager.show_modal(self). Default 0 is the "uninitialized"
## sentinel — modal auto-dismisses if on_enter sees this value (race
## condition: caller showed modal without calling set_target_hero first).
var _target_instance_id: int = 0

# Resolved hero + class state — populated in on_enter.
var _hero: RefCounted = null
var _class_data: Resource = null


# Toast linger / fade — matches formation_assignment + Recruit Screen
# GDD #21 §G precedent.
const TOAST_LINGER_MS: int = 3000
const TOAST_FADE_SEC: float = 0.6

# Tap-debounce grace from on_enter (per GDD §C.9).
const TAP_GRACE_MS: int = 200
var _enter_time_msec: int = 0

# Cached level-up cost per render (per GDD §C.5 / §D.3 cost-stability).
var _cached_level_up_cost: int = -1


# Node references — assumed via @onready (.tscn defines the tree).
@onready var _dim_backdrop: ColorRect = $DimBackdrop
@onready var _detail_panel: PanelContainer = $DetailPanel
@onready var _class_portrait: TextureRect = $DetailPanel/HeaderRow/ClassPortrait
@onready var _display_name_label: Label = $DetailPanel/HeaderRow/HeaderLabels/DisplayNameLabel
@onready var _class_name_label: Label = $DetailPanel/HeaderRow/HeaderLabels/ClassNameLabel
@onready var _owned_count_label: Label = $DetailPanel/HeaderRow/HeaderLabels/OwnedCountLabel
@onready var _level_value_label: Label = $DetailPanel/StatsBlock/LevelRow/LevelValueLabel
@onready var _xp_label: Label = $DetailPanel/StatsBlock/XPRow/XPLabel
@onready var _xp_progress_bar: ProgressBar = $DetailPanel/StatsBlock/XPRow/XPProgressBar
@onready var _level_up_button: Button = $DetailPanel/ActionRow/LevelUpButton
@onready var _close_button: Button = $DetailPanel/ActionRow/CloseButton


# ---------------------------------------------------------------------------
# Public API — set_target_hero (per GDD §C.2 step 2)
# ---------------------------------------------------------------------------

## Sets the target hero by instance_id. Caller MUST call this BEFORE
## SceneManager.show_modal(self) — on_enter relies on the field being
## populated.
##
## Hero Leveling GDD #22 §C.2.
func set_target_hero(instance_id: int) -> void:
	_target_instance_id = instance_id


# ---------------------------------------------------------------------------
# Screen lifecycle (per GDD §C.2)
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Touch-feedback wired in _ready (one-time, .tscn-defined Buttons).
	UIFrameworkScript.wire_touch_feedback(_level_up_button)
	UIFrameworkScript.wire_touch_feedback(_close_button)


func on_enter() -> void:
	_enter_time_msec = Time.get_ticks_msec()

	# Step 1: resolve hero from HeroRoster (defensive — hero may have been
	# removed between caller's tap and modal show per GDD §E.1).
	if _target_instance_id == 0 or not HeroRoster._heroes.has(_target_instance_id):
		push_warning(
			"[HeroDetailModal] target hero unknown (id=%d); auto-dismissing"
			% _target_instance_id
		)
		_dismiss()
		return
	_hero = HeroRoster._heroes[_target_instance_id]

	# Step 2: resolve class via DataRegistry (defensive — orphan class
	# per GDD §E.2).
	_class_data = DataRegistry.resolve("classes", _hero.class_id)
	if _class_data == null:
		push_warning(
			"[HeroDetailModal] class '%s' unresolvable; auto-dismissing"
			% _hero.class_id
		)
		_dismiss()
		return

	# Step 3: connect signals (idempotent — checks before connect).
	if not HeroRoster.hero_leveled.is_connected(_on_hero_leveled):
		HeroRoster.hero_leveled.connect(_on_hero_leveled)
	if not HeroRoster.hero_removed.is_connected(_on_hero_removed):
		HeroRoster.hero_removed.connect(_on_hero_removed)
	if not HeroRoster.hero_recruited.is_connected(_on_hero_recruited):
		HeroRoster.hero_recruited.connect(_on_hero_recruited)
	if not Economy.gold_changed.is_connected(_on_gold_changed):
		Economy.gold_changed.connect(_on_gold_changed)

	# Step 4: button + backdrop input.
	if not _level_up_button.pressed.is_connected(_on_level_up_pressed):
		_level_up_button.pressed.connect(_on_level_up_pressed)
	if not _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.connect(_on_close_pressed)
	if not _dim_backdrop.gui_input.is_connected(_on_backdrop_input):
		_dim_backdrop.gui_input.connect(_on_backdrop_input)

	# Step 5: initial render.
	_refresh_all()


func on_exit() -> void:
	# Disconnect all signals + button handlers + backdrop input.
	if HeroRoster.hero_leveled.is_connected(_on_hero_leveled):
		HeroRoster.hero_leveled.disconnect(_on_hero_leveled)
	if HeroRoster.hero_removed.is_connected(_on_hero_removed):
		HeroRoster.hero_removed.disconnect(_on_hero_removed)
	if HeroRoster.hero_recruited.is_connected(_on_hero_recruited):
		HeroRoster.hero_recruited.disconnect(_on_hero_recruited)
	if Economy.gold_changed.is_connected(_on_gold_changed):
		Economy.gold_changed.disconnect(_on_gold_changed)
	if _level_up_button != null and _level_up_button.pressed.is_connected(_on_level_up_pressed):
		_level_up_button.pressed.disconnect(_on_level_up_pressed)
	if _close_button != null and _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.disconnect(_on_close_pressed)
	if _dim_backdrop != null and _dim_backdrop.gui_input.is_connected(_on_backdrop_input):
		_dim_backdrop.gui_input.disconnect(_on_backdrop_input)


func on_pause() -> void:
	pass  # Modal is not pausable per GDD §C.2.


func on_resume() -> void:
	pass


# ---------------------------------------------------------------------------
# Render — header / stats / level-up button (per GDD §C.3 / §C.4 / §C.5)
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_header()
	_refresh_stats()
	_refresh_level_up_button()


func _refresh_header() -> void:
	if _hero == null or _class_data == null:
		return
	# DisplayNameLabel — immutable per ADR-0012.
	_display_name_label.text = _hero.display_name
	# ClassNameLabel — locale-aware via display_name_key (when class.tres
	# defines it; fallback to class_id capitalized for MVP).
	_class_name_label.text = _resolve_class_display_name()
	# OwnedCountLabel — locale-format via tr.
	var copies: int = HeroRoster.get_copies_owned(_hero.class_id)
	_owned_count_label.text = tr("hero_detail_owned_format") % [copies, _resolve_class_display_name().to_lower()]


func _refresh_stats() -> void:
	if _hero == null:
		return
	var cap: int = HeroRoster.level_cap()
	_level_value_label.text = "%d" % _hero.current_level
	if _hero.current_level >= cap:
		# At LEVEL_CAP — XP display reads "MAX LEVEL".
		_xp_label.text = tr("hero_detail_xp_capped")
		_xp_progress_bar.value = 1.0
	else:
		var threshold: int = HeroRoster.xp_threshold(_hero.current_level)
		_xp_label.text = tr("hero_detail_xp_format") % [_hero.xp, threshold]
		_xp_progress_bar.value = clampf(float(_hero.xp) / float(threshold), 0.0, 1.0)


func _refresh_level_up_button() -> void:
	if _hero == null or _class_data == null:
		return
	var cap: int = HeroRoster.level_cap()
	if _hero.current_level >= cap:
		# Hide button at LEVEL_CAP per GDD §C.5 — no negative-feedback state.
		_level_up_button.visible = false
		_cached_level_up_cost = -1
		return
	_level_up_button.visible = true
	# Resolve cost via Economy.level_cost(tier, current_level) per ADR-0013.
	var tier: int = int(_class_data.get("tier")) if "tier" in _class_data else 1
	var cost: int = Economy.level_cost(tier, _hero.current_level)
	_cached_level_up_cost = cost
	# NOTE: Recruit Screen GDD #21 + Hero Detail GDD #22 reference
	# UIFramework.format_short_number which does NOT exist as of 2026-05-07
	# (additional cross-GDD gap not flagged in the original sweep). For
	# the scaffold, format the cost as a plain int string. The formatter
	# polish can land alongside Recruit Screen UI implementation in
	# Sprint 16 — it's a shared dependency.
	_level_up_button.text = tr("hero_detail_level_up_format") % str(cost)
	_level_up_button.disabled = (Economy.get_gold_balance() < cost)


# ---------------------------------------------------------------------------
# Interaction — Level-Up press (per GDD §C.6)
# ---------------------------------------------------------------------------

func _on_level_up_pressed() -> void:
	if _hero == null or _class_data == null:
		return
	var cap: int = HeroRoster.level_cap()
	if _hero.current_level >= cap:
		push_warning("[HeroDetailModal] level-up press at LEVEL_CAP; no-op")
		return

	# Resolve cost at tap time per cost-stability invariant.
	var tier: int = int(_class_data.get("tier")) if "tier" in _class_data else 1
	var cost: int = Economy.level_cost(tier, _hero.current_level)

	# Atomic transaction: try_spend FIRST, then set_hero_level.
	if not Economy.try_spend(cost, "level_up"):
		# Insufficient gold — toast the player + re-render gating.
		_show_toast(tr("recruit_error_insufficient_gold"))  # reuse the recruit error toast
		_refresh_level_up_button()
		return
	# Spend succeeded. Increment level.
	HeroRoster.set_hero_level(_hero.instance_id, _hero.current_level + 1)
	# hero_leveled signal fires via set_hero_level; subscribers
	# (_on_hero_leveled here, plus AudioRouter chime, plus dungeon_run_view
	# toast if visible) react. _refresh_all is called via _on_hero_leveled.


# ---------------------------------------------------------------------------
# Dismissal (per GDD §C.7)
# ---------------------------------------------------------------------------

func _on_close_pressed() -> void:
	_dismiss()


func _on_backdrop_input(event: InputEvent) -> void:
	# Tap-grace: ignore taps in the first TAP_GRACE_MS post-on_enter.
	if Time.get_ticks_msec() - _enter_time_msec < TAP_GRACE_MS:
		return
	# Accept mouse-button-pressed OR touch-pressed events.
	var is_mouse_press: bool = event is InputEventMouseButton and event.pressed
	var is_touch_press: bool = event is InputEventScreenTouch and event.pressed
	if is_mouse_press or is_touch_press:
		_dismiss()


func _dismiss() -> void:
	SceneManager.hide_modal(self)


# ---------------------------------------------------------------------------
# Signal handlers (per GDD §C.2)
# ---------------------------------------------------------------------------

func _on_hero_leveled(_id: int, _old: int, _new: int) -> void:
	# Re-render stats + level-up button on any level change.
	# _hero.current_level is already updated by HeroRoster before signal
	# fires (per HeroRoster signal-after-mutation invariant).
	_refresh_stats()
	_refresh_level_up_button()


func _on_hero_removed(id: int, _class_id: String, _display_name: String) -> void:
	# Auto-dismiss if THIS hero was removed (V1.0+ retire UI scenario per
	# GDD §C.8).
	if id == _target_instance_id:
		push_warning("[HeroDetailModal] target hero removed; auto-dismissing")
		_dismiss()


func _on_hero_recruited(_instance: RefCounted) -> void:
	# A hero of the same class was recruited — refresh OwnedCountLabel.
	_refresh_header()


func _on_gold_changed(_new_balance: int, _delta: int, _reason: String) -> void:
	# Gold mutation — refresh LevelUpButton affordability gating.
	_refresh_level_up_button()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Resolves the locale-aware class display name. Reads from
## class_data.display_name_key when present; falls back to a capitalized
## class_id for MVP / orphan-resource scenarios.
func _resolve_class_display_name() -> String:
	if _class_data != null and "display_name_key" in _class_data:
		var key: String = String(_class_data.display_name_key)
		if key != "":
			return tr(key)
	# Fallback — capitalize the class_id.
	if _hero != null:
		return _hero.class_id.capitalize()
	return ""


## Toast helper — placeholder MVP scaffold. Sprint 16+ can refine via the
## formation_assignment toast pattern; for now, push_warning surfaces the
## message in dev consoles. Per GDD §G the toast linger is 3.0s + 0.6s
## fade; that wiring lives in the .tscn (deferred to /design-review polish).
func _show_toast(message: String) -> void:
	# Scaffold: log to console; .tscn-side ToastLabel wiring is a
	# /design-review polish item per GDD §G + §I OQ-22-7.
	push_warning("[HeroDetailModal] toast: %s" % message)
