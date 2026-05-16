## Hero Detail Modal — read-only-ish modal showing per-hero stats with a
## Level-Up button when affordable.
##
## Sprint 16 S16-M2 candidate scaffold (pre-emptively authored 2026-05-07
## per the established cadence). Ships the contract layer + minimal .tscn
## layout per Roster / Hero Detail Screen GDD #22 §C.1 / §C.2 / §C.5 / §C.6.
## Visual polish (anchors + final theme variation tuning + portrait
## sourcing) deferred to post-`/design-review` of GDD #22.
##
## Lifecycle (per GDD §C.2; S14-M6 update — SceneManager now drives the
## Screen lifecycle hooks):
##   1. Caller (Guild Hall HeroCard tap) instantiates the modal scene
##   2. Caller calls set_target_hero(instance_id) BEFORE show_modal
##   3. Caller calls SceneManager.show_modal(self)
##   4. SceneManager.show_modal calls self.on_enter() automatically;
##      on_enter resolves hero + class via HeroRoster + DataRegistry,
##      subscribes to signals, renders all panels
##   5. Player taps LevelUp / Close / DimBackdrop → calls SceneManager.hide_modal(self)
##   6. SceneManager.hide_modal calls self.on_exit() automatically (before
##      queue_free); on_exit disconnects signal handlers
##
## Atomic Level-Up transaction (per GDD §C.6):
##   try_spend(cost, "level_up") → on success → set_hero_level(id, +1)
##   No rollback handling needed — single-writer pattern per Recruitment §E.
extends Screen

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")
# Sprint 23 S23-S3 — programmatic ClassPortrait placeholders (third carry).
const ClassPortraitFactoryScript = preload("res://src/ui/class_portrait_factory.gd")

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

# Prestige V1.0 — Slice C — AC-PR-18 hero-fade-to-Hall animation.
# Cozy default: the DetailPanel fades from full opacity to 0 over a
# brief window before HeroRoster.prestige_hero is called. The
# autoload's hero_removed signal then auto-dismisses the modal via
# the existing _on_hero_removed handler. Reduce-motion path skips
# the tween and calls prestige_hero immediately (instant-cut).
const PRESTIGE_FADE_DURATION_SEC: float = 0.28

# Active fade tween. Captured so on_exit can kill it if the modal is
# dismissed mid-fade (e.g., user taps the close button between
# Confirm and the tween-completion callback firing).
var _prestige_fade_tween: Tween = null

# Re-entrancy guard: once a confirm tap has started the fade, ignore
# subsequent confirm/cancel taps until the fade resolves. Prevents
# double-tap mis-fires that would call prestige_hero twice (the second
# call would be a no-op because the hero is already removed, but the
# defensive flag keeps the UI state consistent).
var _prestige_fade_in_flight: bool = false

# Tap-debounce grace from on_enter (per GDD §C.9).
const TAP_GRACE_MS: int = 200
var _enter_time_msec: int = 0

# Cached level-up cost per render (per GDD §C.5 / §D.3 cost-stability).
var _cached_level_up_cost: int = -1


# Node references — assumed via @onready (.tscn defines the tree).
@onready var _dim_backdrop: ColorRect = $DimBackdrop
## DetailPanel modulate is tweened during the prestige fade (Slice C —
## AC-PR-18 hero-fade-to-Hall animation). Originally reserved for the
## Sprint 17 S17-M2 modal slide-in animation polish; the prestige
## fade is the first live consumer.
@onready var _detail_panel: PanelContainer = $DetailPanel
## Class portrait — Sprint 23 S23-S3 wires the programmatic 96×96 placeholder
## per `class_id` via `ClassPortraitFactory`. When real product art arrives
## (HeroClass.portrait_path → actual PNG), `_refresh_header` will prefer the
## file path and fall back to the factory texture if absent.
@onready var _class_portrait: TextureRect = $DetailPanel/ContentVBox/HeaderRow/ClassPortrait
@onready var _display_name_label: Label = $DetailPanel/ContentVBox/HeaderRow/HeaderLabels/DisplayNameLabel
@onready var _class_name_label: Label = $DetailPanel/ContentVBox/HeaderRow/HeaderLabels/ClassNameLabel
@onready var _owned_count_label: Label = $DetailPanel/ContentVBox/HeaderRow/HeaderLabels/OwnedCountLabel
@onready var _counter_archetype_label: Label = $DetailPanel/ContentVBox/HeaderRow/HeaderLabels/CounterArchetypeLabel
@onready var _level_value_label: Label = $DetailPanel/ContentVBox/StatsBlock/LevelRow/LevelValueLabel
@onready var _xp_label: Label = $DetailPanel/ContentVBox/StatsBlock/XPRow/XPLabel
@onready var _xp_progress_bar: ProgressBar = $DetailPanel/ContentVBox/StatsBlock/XPRow/XPProgressBar
@onready var _level_up_button: Button = $DetailPanel/ContentVBox/ActionRow/LevelUpButton
@onready var _close_button: Button = $DetailPanel/ContentVBox/ActionRow/CloseButton

# Prestige V1.0 — Story 3 UI (Slice A) — `prestige-system.md` §C.1 + §C.2
# + AC-PR-19 + AC-PR-20. The Prestige button is mutually exclusive with
# LevelUpButton: one OR the other shows depending on hero level vs cap.
@onready var _prestige_button: Button = $DetailPanel/ContentVBox/ActionRow/PrestigeButton
@onready var _prestige_confirmation: Control = $PrestigeConfirmation
@onready var _prestige_confirm_backdrop: ColorRect = $PrestigeConfirmation/ConfirmDimBackdrop
@onready var _prestige_confirm_body_label: Label = $PrestigeConfirmation/ConfirmPanel/ConfirmContent/ConfirmBodyLabel
@onready var _prestige_confirm_button: Button = $PrestigeConfirmation/ConfirmPanel/ConfirmContent/ConfirmButtonRow/ConfirmButton
@onready var _prestige_cancel_button: Button = $PrestigeConfirmation/ConfirmPanel/ConfirmContent/ConfirmButtonRow/CancelButton


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
	UIFrameworkScript.wire_touch_feedback(_prestige_button)
	UIFrameworkScript.wire_touch_feedback(_prestige_confirm_button)
	UIFrameworkScript.wire_touch_feedback(_prestige_cancel_button)


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
	# Prestige confirmation flow handlers.
	if not _prestige_button.pressed.is_connected(_on_prestige_pressed):
		_prestige_button.pressed.connect(_on_prestige_pressed)
	if not _prestige_confirm_button.pressed.is_connected(_on_prestige_confirm_pressed):
		_prestige_confirm_button.pressed.connect(_on_prestige_confirm_pressed)
	if not _prestige_cancel_button.pressed.is_connected(_on_prestige_cancel_pressed):
		_prestige_cancel_button.pressed.connect(_on_prestige_cancel_pressed)
	if not _prestige_confirm_backdrop.gui_input.is_connected(_on_prestige_confirm_backdrop_input):
		_prestige_confirm_backdrop.gui_input.connect(_on_prestige_confirm_backdrop_input)

	# Confirmation overlay starts hidden every show.
	_prestige_confirmation.visible = false

	# Reset fade state on every show. on_enter is the canonical re-entry
	# point per Screen GDD §C.2 ("treat each call as a fresh
	# initialization"); a stale modulate from a prior modal show would
	# render the panel invisible.
	_detail_panel.modulate.a = 1.0
	_prestige_fade_in_flight = false
	_prestige_fade_tween = null

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
	if _prestige_button != null and _prestige_button.pressed.is_connected(_on_prestige_pressed):
		_prestige_button.pressed.disconnect(_on_prestige_pressed)
	if _prestige_confirm_button != null and _prestige_confirm_button.pressed.is_connected(_on_prestige_confirm_pressed):
		_prestige_confirm_button.pressed.disconnect(_on_prestige_confirm_pressed)
	if _prestige_cancel_button != null and _prestige_cancel_button.pressed.is_connected(_on_prestige_cancel_pressed):
		_prestige_cancel_button.pressed.disconnect(_on_prestige_cancel_pressed)
	if _prestige_confirm_backdrop != null and _prestige_confirm_backdrop.gui_input.is_connected(_on_prestige_confirm_backdrop_input):
		_prestige_confirm_backdrop.gui_input.disconnect(_on_prestige_confirm_backdrop_input)
	# Kill any in-flight fade tween so its bound callback cannot fire on
	# a being-freed node. The tween itself is auto-killed when its bound
	# Node leaves the tree, but explicit kill is the documented pattern.
	if _prestige_fade_tween != null:
		_prestige_fade_tween.kill()
		_prestige_fade_tween = null
	_prestige_fade_in_flight = false


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
	_refresh_prestige_button()


func _refresh_header() -> void:
	if _hero == null or _class_data == null:
		return
	# Sprint 23 S23-S3 — ClassPortrait placeholder. 96×96 programmatic
	# colored block per class_id; the .tscn has no texture set, so this is
	# the first surface to render the class identity visually.
	if _class_portrait != null:
		_class_portrait.texture = ClassPortraitFactoryScript.get_portrait_texture(_hero.class_id)
	# DisplayNameLabel — immutable per ADR-0012.
	_display_name_label.text = _hero.display_name
	# ClassNameLabel — locale-aware via display_name_key (when class.tres
	# defines it; fallback to class_id capitalized for MVP).
	_class_name_label.text = _resolve_class_display_name()
	# OwnedCountLabel — locale-format via tr.
	var copies: int = HeroRoster.get_copies_owned(_hero.class_id)
	_owned_count_label.text = tr("hero_detail_owned_format") % [copies, _resolve_class_display_name().to_lower()]
	# CounterArchetypeLabel — Sprint 17: surface this class's counter
	# archetype so the player knows what each hero is good against.
	# Pairs with the Matchup Assignment "Recommended: <class>" hint (PR
	# #84): biome shows what to bring; hero shows what they counter.
	# Defensive: if the class has no counter_archetype set, the label
	# stays empty (rendered hidden via implicit zero-height layout).
	var counter: String = String(_class_data.counter_archetype) if "counter_archetype" in _class_data else ""
	if counter != "":
		_counter_archetype_label.text = "Strong vs: %s" % counter
	else:
		_counter_archetype_label.text = ""


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
	_level_up_button.text = tr("hero_detail_level_up_format") % UIFrameworkScript.format_short_number(cost)
	_level_up_button.disabled = (Economy.get_gold_balance() < cost)


# ---------------------------------------------------------------------------
# Prestige V1.0 — Story 3 UI (Slice A) — `prestige-system.md` §C.1 + §C.2
# + AC-PR-19 + AC-PR-20.
#
# Visibility tri-state on the at-cap hero:
#   - eligible          → button shown + enabled
#   - active-run        → button shown + disabled + tooltip (AC-PR-19)
#   - last-hero / max   → button hidden (AC-PR-20 + PRESTIGE_MAX cap)
#
# Below cap → button always hidden (LevelUpButton owns the row instead).
# ---------------------------------------------------------------------------

func _refresh_prestige_button() -> void:
	if _hero == null:
		_prestige_button.visible = false
		return
	var cap: int = HeroRoster.level_cap()
	if _hero.current_level < cap:
		# Below cap — LevelUpButton handles the row, prestige stays hidden.
		_prestige_button.visible = false
		return
	# Hero at cap. is_prestige_eligible already encodes all 6 checks; if it
	# returns true, the button is shown + enabled. If false, the failure
	# reason determines hidden vs disabled-with-tooltip.
	if HeroRoster.is_prestige_eligible(_hero.instance_id):
		_prestige_button.visible = true
		_prestige_button.disabled = false
		_prestige_button.tooltip_text = ""
		_prestige_button.text = tr("prestige_button_label")
		return
	# Ineligible at cap. Distinguish active-run (show disabled) from
	# last-hero / prestige-max (hide entirely). Per GDD §E.1 + §E.2.
	if _is_orchestrator_in_active_run():
		_prestige_button.visible = true
		_prestige_button.disabled = true
		_prestige_button.tooltip_text = tr("prestige_disabled_active_run_tooltip")
		_prestige_button.text = tr("prestige_button_label")
	else:
		# Last hero, prestige cap, or other no-show reason.
		_prestige_button.visible = false


## Returns [code]true[/code] if [code]DungeonRunOrchestrator.state[/code] is
## non-zero (any state other than NO_RUN). Defensive null-check for test envs
## without the orchestrator autoload registered. Mirrors the duck-typed read
## in [code]HeroRoster.is_prestige_eligible[/code] so the UI gating decision
## stays consistent with the autoload-side eligibility decision.
func _is_orchestrator_in_active_run() -> bool:
	var orch: Node = get_node_or_null("/root/DungeonRunOrchestrator")
	if orch == null or not ("state" in orch):
		return false
	return int(orch.get("state")) != 0


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
# Interaction — Prestige confirmation flow (per `prestige-system.md` §C.1
# + §C.2 + AC-PR-06..09).
#
# Tap flow:
#   1. PrestigeButton tap   → _on_prestige_pressed
#   2. Confirmation overlay → renders cozy-register modal body via tr()
#   3. ConfirmButton tap    → _on_prestige_confirm_pressed
#                              → HeroRoster.prestige_hero(id)
#                              → autoload emits hero_removed →
#                                _on_hero_removed auto-dismisses this
#                                modal (no manual dismiss needed)
#   4. CancelButton tap     → _on_prestige_cancel_pressed (overlay only)
#   5. Backdrop tap         → cancel (same as CancelButton)
#
# Reduce-motion / hero-fade animation (AC-PR-18) is Slice C scope — the
# confirm path here is synchronous; the player sees the modal disappear
# the moment the autoload emits hero_removed.
# ---------------------------------------------------------------------------

func _on_prestige_pressed() -> void:
	# Defensive: re-verify eligibility at tap time. Between the render
	# pass and the tap, the orchestrator state could have flipped (e.g.,
	# a tick fired a dispatch). Re-check rather than relying on stale
	# button state.
	if _hero == null:
		return
	if not HeroRoster.is_prestige_eligible(_hero.instance_id):
		# Refresh the button so its state matches the new reality.
		_refresh_prestige_button()
		return
	_show_prestige_confirmation()


func _on_prestige_confirm_pressed() -> void:
	if _hero == null:
		_hide_prestige_confirmation()
		return
	if _prestige_fade_in_flight:
		# Re-entrancy guard: a fade is already running; ignore the tap.
		return
	# Capture id before the call — _hero will be torn down by the
	# hero_removed signal handler the moment prestige_hero succeeds.
	var id: int = _hero.instance_id
	_hide_prestige_confirmation()
	# AC-PR-18: reduce-motion variant skips the fade and runs prestige
	# synchronously. Default path (reduce_motion = false) tweens the
	# DetailPanel modulate.a from 1.0 → 0.0 over PRESTIGE_FADE_DURATION_SEC,
	# then calls the autoload from the tween-completion callback.
	if _is_reduce_motion_enabled():
		_execute_prestige(id)
		return
	_prestige_fade_in_flight = true
	_prestige_fade_tween = create_tween()
	_prestige_fade_tween.tween_property(
		_detail_panel, "modulate:a", 0.0, PRESTIGE_FADE_DURATION_SEC
	)
	_prestige_fade_tween.tween_callback(_execute_prestige.bind(id))


## Synchronous prestige action. Called either directly (reduce-motion
## path) or as a tween-completion callback (default path). Resets fade
## state on prestige_hero rejection so the modal can recover (e.g., a
## race-condition rejection from the autoload-side guard).
func _execute_prestige(id: int) -> void:
	_prestige_fade_in_flight = false
	_prestige_fade_tween = null
	var ok: bool = HeroRoster.prestige_hero(id)
	if not ok:
		# Defensive: prestige_hero rejected (race with state change).
		# The modal remains; reset modulate so it's visible again, then
		# refresh button state to reflect new reality.
		_detail_panel.modulate.a = 1.0
		_refresh_prestige_button()


## Reads [code]SceneManager.reduce_motion[/code] defensively. Test envs
## without the SceneManager autoload registered get the false default
## (full-motion) — matches the existing pattern used elsewhere in this
## file for autoload null-checks.
func _is_reduce_motion_enabled() -> bool:
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm == null:
		return false
	if not ("reduce_motion" in sm):
		return false
	return bool(sm.get("reduce_motion"))


func _on_prestige_cancel_pressed() -> void:
	# Cancel returns to the detail view — modal stays open, no autoload
	# call. Cozy-register: undoing a tap is a free, friction-free action.
	_hide_prestige_confirmation()


func _on_prestige_confirm_backdrop_input(event: InputEvent) -> void:
	# Backdrop tap = cancel. Same tap-grace as the main backdrop.
	var is_mouse_press: bool = event is InputEventMouseButton and event.pressed
	var is_touch_press: bool = event is InputEventScreenTouch and event.pressed
	if is_mouse_press or is_touch_press:
		_hide_prestige_confirmation()


func _show_prestige_confirmation() -> void:
	if _hero == null:
		return
	# Format the cozy-register body text with the hero's display name.
	# The `prestige_confirmation_modal_body` value in en.csv contains
	# embedded commas (so it MUST stay RFC-4180-quoted in the CSV — see
	# `prestige_v1_story3_logic_test.gd::test_prestige_modal_body_resolves_full_string_via_tr`)
	# AND a literal "+5%" which would collide with Godot's `%` operator.
	# Use String.replace instead of `%` so the literal % stays intact.
	var body: String = tr("prestige_confirmation_modal_body").replace(
		"%s", _hero.display_name
	)
	_prestige_confirm_body_label.text = body
	_prestige_confirmation.visible = true


func _hide_prestige_confirmation() -> void:
	_prestige_confirmation.visible = false


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
	# Prestige button must also re-render: a level-up that crosses the
	# cap boundary flips LevelUpButton off and PrestigeButton on.
	_refresh_stats()
	_refresh_level_up_button()
	_refresh_prestige_button()


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
