## ReturnToApp — cozy offline-gains summary screen. S13-M2 / Story 9.
##
## Shown automatically by [OfflineProgressionEngine] after a replay completes
## (seconds_credited > 0). The autoload emits [signal offline_rewards_collected],
## caches the summary in [method OfflineProgressionEngine.last_summary], then
## calls SceneManager.request_screen("return_to_app", SLIDE_DOWN).
##
## Late-subscriber pattern: this screen may be instantiated AFTER the signal
## already fired (SLIDE_DOWN transition takes ~300 ms). on_enter() reads the
## cached summary via [method OfflineProgressionEngine.last_summary] AND connects
## to the signal for live re-render if a second replay somehow fires while the
## screen is active.
##
## Null-summary fallback: if shown via ad-hoc navigation (no cached summary),
## a graceful "no recent rewards" placeholder is displayed. This unblocks QA /
## debug screen navigation without requiring a real replay.
##
## UX-POLISH DEFERRED (Sprint 14+):
##   - Cozy/ceremonial aesthetic (animated coin icon, parchment reveal, staggered
##     label entries, celebration particle burst).
##   - Idle ambient sound loop while screen is displayed.
##   - "Hours away" badge overlay (hero portraits in armor + clock motif).
##   - Floor-by-floor breakdown carousel (scrollable, per GDD §J fantasy 1).
##   - Animated counter tick-up for gold_earned (0 → final value, ~1.5 s).
##   This sprint delivers engineering-wired layout only.
##
## Governing GDD: design/gdd/offline-progression-engine.md §J Story 9.
## Governing ADRs: ADR-0014 (OfflineSummary fields, forbidden pattern),
##                 ADR-0007 (Screen lifecycle), ADR-0008 (UIFramework).
extends Screen

# ---------------------------------------------------------------------------
# Preload
# ---------------------------------------------------------------------------

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")

# ---------------------------------------------------------------------------
# @onready node references — matched to return_to_app.tscn node names.
# All are typed; Godot 4.6 parse-time-null on mismatch gives a clear error.
# ---------------------------------------------------------------------------

## PanelContainer styled as parchment via UIFramework.apply_parchment_panel.
@onready var _summary_panel: PanelContainer = $SummaryPanel

## Screen title — tr("return_to_app_title").
@onready var _header_label: Label = $SummaryPanel/VBoxContainer/HeaderLabel

## Minutes-elapsed subhead — "You were away for %d minutes."
@onready var _elapsed_subhead: Label = $SummaryPanel/VBoxContainer/ElapsedSubhead

## "+%d gold earned" row.
@onready var _gold_row: Label = $SummaryPanel/VBoxContainer/GoldRow

## "%d enemies defeated" row.
@onready var _kills_row: Label = $SummaryPanel/VBoxContainer/KillsRow

## "%d floors cleared" row.
@onready var _floors_row: Label = $SummaryPanel/VBoxContainer/FloorsRow

## Offline-cap advisory — shown only when seconds_clipped > 0.
@onready var _cap_notice: Label = $SummaryPanel/VBoxContainer/CapNotice

## Fallback label shown when there is no cached summary (debug navigation).
@onready var _no_summary_label: Label = $SummaryPanel/VBoxContainer/NoSummaryLabel

## Dismiss button — routes back to guild_hall via SceneManager.
@onready var _acknowledge_button: Button = $SummaryPanel/VBoxContainer/AcknowledgeButton

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Holds seconds_clipped from _on_cap_reached if that signal fires before
## _render_summary is called. Merged into the cap notice row in _render_summary.
var _pending_seconds_clipped: int = 0


# ---------------------------------------------------------------------------
# Built-in lifecycle
# ---------------------------------------------------------------------------

## Apply parchment theme and touch feedback at scene-ready time.
## Note: signal connections are in on_enter() per ADR-0007.
func _ready() -> void:
	UIFrameworkScript.apply_parchment_panel(_summary_panel)
	_acknowledge_button.text = tr("return_to_app_acknowledge_button")
	_cap_notice.visible = false
	_no_summary_label.visible = false


# ---------------------------------------------------------------------------
# Screen lifecycle hooks (ADR-0007 — all four MUST be declared)
# ---------------------------------------------------------------------------

## Called by SceneManager after this screen becomes current_screen.
##
## 1. Connects to OfflineProgressionEngine signals (idempotent via is_connected).
## 2. Reads the cached summary via OfflineProgressionEngine.last_summary().
## 3. Renders the summary (or fallback if null).
## 4. Wires the acknowledge button and suppresses keyboard focus.
func on_enter() -> void:
	# Reset transient state for this visit.
	_pending_seconds_clipped = 0
	_cap_notice.visible = false

	# Connect to OfflineProgressionEngine signals for live re-render while active.
	# Idempotent via is_connected guard — safe across screen re-use if SM keeps it
	# alive (currently SM frees on each transition, but guard costs nothing).
	if not OfflineProgressionEngine.offline_rewards_collected.is_connected(
		_on_offline_rewards_collected
	):
		OfflineProgressionEngine.offline_rewards_collected.connect(
			_on_offline_rewards_collected
		)

	if not OfflineProgressionEngine.cap_reached.is_connected(_on_cap_reached):
		OfflineProgressionEngine.cap_reached.connect(_on_cap_reached)

	# Wire the acknowledge button (idempotent via UIFramework meta sentinel for
	# touch feedback; Button.pressed guard via is_connected).
	UIFrameworkScript.wire_touch_feedback(_acknowledge_button)
	if not _acknowledge_button.pressed.is_connected(_on_acknowledge_button_pressed):
		_acknowledge_button.pressed.connect(_on_acknowledge_button_pressed)

	# Single-focus-mode strategy — ADR-0008.
	UIFrameworkScript.suppress_keyboard_focus(self)

	# Late-subscriber pattern: read cached summary written BEFORE the signal fired.
	var summary: OfflineProgressionEngine.OfflineSummary = (
		OfflineProgressionEngine.last_summary()
	)
	if summary != null:
		_render_summary(summary)
	else:
		_render_no_summary_fallback()


## Called by SceneManager BEFORE queue_free. Disconnects all signals connected
## in on_enter. Defensive is_connected guard — safe if on_enter never ran
## (e.g., if the node is freed in an error recovery path).
func on_exit() -> void:
	if OfflineProgressionEngine.offline_rewards_collected.is_connected(
		_on_offline_rewards_collected
	):
		OfflineProgressionEngine.offline_rewards_collected.disconnect(
			_on_offline_rewards_collected
		)

	if OfflineProgressionEngine.cap_reached.is_connected(_on_cap_reached):
		OfflineProgressionEngine.cap_reached.disconnect(_on_cap_reached)

	if _acknowledge_button.pressed.is_connected(_on_acknowledge_button_pressed):
		_acknowledge_button.pressed.disconnect(_on_acknowledge_button_pressed)


## Called by SceneManager when a modal opens on top of this screen.
## No animations to suspend in the S13-M2 engineering-wired layout.
func on_pause() -> void:
	pass


## Called by SceneManager when the modal closes.
## No display refresh needed — the layout is static once rendered.
func on_resume() -> void:
	pass


# ---------------------------------------------------------------------------
# Render helpers
# ---------------------------------------------------------------------------

## Populates all visible fields from [param summary].
##
## Reads _kills_by_tier from summary's meta (set by OfflineProgressionEngine
## during replay accumulation). Falls back to 0 kills if meta is absent
## (empty replay, cold-start test fixture, or pre-ADR-0014 data).
##
## Merges _pending_seconds_clipped with summary.seconds_clipped so the cap
## notice renders correctly even if cap_reached fired before this call.
func _render_summary(summary: OfflineProgressionEngine.OfflineSummary) -> void:
	_no_summary_label.visible = false

	# Header.
	_header_label.text = tr("return_to_app_title")

	# Elapsed subhead — convert seconds to whole minutes (intentional truncation).
	@warning_ignore("integer_division")
	var minutes_away: int = int(summary.seconds_credited / 60)
	_elapsed_subhead.text = UIFrameworkScript.format_localized(
		"return_to_app_seconds_credited_format", [minutes_away]
	)

	# Gold row.
	_gold_row.text = UIFrameworkScript.format_localized(
		"return_to_app_gold_earned_format", [summary.gold_earned]
	)

	# Kills row — sum across all tiers from _kills_by_tier meta.
	var total_kills: int = 0
	if summary.has_meta("_kills_by_tier"):
		var kills_by_tier: Dictionary = summary.get_meta("_kills_by_tier")
		for tier: Variant in kills_by_tier.keys():
			total_kills += int(kills_by_tier[tier])
	_kills_row.text = UIFrameworkScript.format_localized(
		"return_to_app_kills_format", [total_kills]
	)

	# Floors row — count of floors_cleared_in_window entries.
	_floors_row.text = UIFrameworkScript.format_localized(
		"return_to_app_floors_format", [summary.floors_cleared_in_window.size()]
	)

	# Cap notice — show if any seconds were clipped (from summary or cached signal).
	var clipped: int = maxi(summary.seconds_clipped, _pending_seconds_clipped)
	if clipped > 0:
		# Intentional s→h truncation (cap-reached notice shows whole hours).
		@warning_ignore("integer_division")
		var hours_capped: int = int(clipped / 3600)
		_cap_notice.text = UIFrameworkScript.format_localized(
			"return_to_app_cap_reached_notice_format", [hours_capped]
		)
		_cap_notice.visible = true
	else:
		_cap_notice.visible = false


## Renders a graceful fallback when no cached summary exists.
##
## Should not occur in production (OfflineProgressionEngine always routes via
## request_screen only when seconds_credited > 0 and _last_summary is set).
## Displayed when the screen is navigated to directly via debug tooling or
## ad-hoc request_screen calls without a prior replay.
func _render_no_summary_fallback() -> void:
	_header_label.text = tr("return_to_app_title")
	_elapsed_subhead.text = ""
	_gold_row.text = ""
	_kills_row.text = ""
	_floors_row.text = ""
	_cap_notice.visible = false
	_no_summary_label.text = tr("return_to_app_no_summary_fallback")
	_no_summary_label.visible = true


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Handles [signal OfflineProgressionEngine.offline_rewards_collected].
##
## Called when a new replay completes while this screen is already on screen
## (e.g., a second offline-elapsed event fires after an aggressive background
## session). Re-renders the summary with the new data.
##
## [param summary]: the newly completed OfflineSummary.
func _on_offline_rewards_collected(
	summary: OfflineProgressionEngine.OfflineSummary
) -> void:
	_render_summary(summary)


## Handles [signal OfflineProgressionEngine.cap_reached].
##
## Fires BEFORE offline_rewards_collected when elapsed > cap. Caches the
## clipped seconds so _render_summary can display the cap notice even when
## summary.seconds_clipped is 0 (defensive: should always match, but guard
## covers any ordering edge case). Also triggers an advisory log.
##
## [param seconds_clipped]: max(0, elapsed - cap). Always > 0 here.
func _on_cap_reached(seconds_clipped: int) -> void:
	push_warning(
		"ReturnToApp: cap_reached signal received — seconds_clipped=%d. "
		% seconds_clipped
		+ "Cap notice will be shown on next _render_summary call."
	)
	_pending_seconds_clipped = seconds_clipped


## Handles the AcknowledgeButton pressed signal. Routes to guild_hall via
## SceneManager.request_screen (no SceneTree.change_scene_to_* per ADR-0007).
func _on_acknowledge_button_pressed() -> void:
	SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)
