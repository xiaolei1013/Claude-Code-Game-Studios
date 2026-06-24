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
const WireframeKitScript = preload("res://src/ui/wireframe_kit.gd")
var _wire_built: bool = false

# ---------------------------------------------------------------------------
# @onready node references — matched to return_to_app.tscn node names.
# All are typed; Godot 4.6 parse-time-null on mismatch gives a clear error.
# ---------------------------------------------------------------------------

## PanelContainer styled as parchment via UIFramework.apply_parchment_panel.
@onready var _summary_panel: PanelContainer = $SummaryPanel
# Sprint 22 S22-M3: BiomeBackground at z=-1 (cozy tavern preset).
@onready var _biome_background: ColorRect = $BiomeBackground

## Screen title — tr("return_to_app_title").
@onready var _header_label: Label = $SummaryPanel/VBoxContainer/HeaderLabel

## Minutes-elapsed subhead — "You were away for %d minutes."
@onready var _elapsed_subhead: Label = $SummaryPanel/VBoxContainer/ElapsedSubhead

## "Driven back at Floor %d — your guild is recovering." offline-defeat notice.
## Shown only when the offline window ended in DEFEAT (summary "_defeated_at_floor"
## meta is set by OfflineProgressionEngine). GDD #34 Phase 5 / AC-34-10.
@onready var _defeat_notice_row: Label = $SummaryPanel/VBoxContainer/DefeatNoticeRow

## "+%d gold earned" row.
@onready var _gold_row: Label = $SummaryPanel/VBoxContainer/GoldRow

## "%d enemies defeated" row.
@onready var _kills_row: Label = $SummaryPanel/VBoxContainer/KillsRow

## "%d floors cleared" row.
@onready var _floors_row: Label = $SummaryPanel/VBoxContainer/FloorsRow

## "New region unlocked: %s" celebration row. Shown only when the offline window
## unlocked one or more biomes (summary "_biomes_unlocked" meta is non-empty).
@onready var _region_unlock_row: Label = $SummaryPanel/VBoxContainer/RegionUnlockRow

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
	_region_unlock_row.visible = false
	_defeat_notice_row.visible = false


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

	# Sprint 22 S22-M3: render the cozy tavern BiomeBackground. Return-to-App
	# is the player coming back to the guild after offline time; the tavern
	# warm-amber preset reinforces "welcome back, you are home."
	if _biome_background != null:
		_biome_background.set_biome("guild_hall_tavern")

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

	# Lantern Guild mock wireframe: "while you were away" framing (greybox).
	_build_wireframe_once()


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

	# Offline-defeat notice — surfaces the floor the formation was driven back at
	# when the offline window ended in DEFEAT (set by OfflineProgressionEngine via
	# the "_defeated_at_floor" meta). Rendered before the rewards rows so the
	# narrative reads "away N min → driven back at Floor X → but still earned …".
	_render_defeat_notice_row(summary)

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

	# Region-unlock row — surfaces biomes the offline window unlocked (set by
	# OfflineProgressionEngine via the "_biomes_unlocked" meta snapshot-diff).
	# Reuses the in-game biome_unlocked_toast_format string for one consistent
	# "new region unlocked" voice across the toast and this summary.
	_render_region_unlock_row(summary)

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

	# Audio quick-win (Sprint 29 S29-6): one chime as the summary settles. The cue
	# is chosen by _select_return_cue (cap-precedence, mutually exclusive — see
	# there). Reuses `clipped` computed just above. Fires once per entry on the cold
	# path and again on any live re-render (a genuine new reward). AudioRouter no-ops
	# under headless, so tests stay silent. Audio is not motion — intentionally NOT
	# reduce_motion-gated.
	_play_audio_cue(_select_return_cue(clipped))


## Renders the "new region unlocked" celebration row from the summary's
## "_biomes_unlocked" meta (a typed Array[String] of biome ids set by
## OfflineProgressionEngine's snapshot-diff). Maps each biome id to its
## localizable display name via BiomeDungeonDatabase, joining multiples with
## a comma. Hides the row when the meta is absent or empty.
##
## Defensive against malformed meta (non-Array, non-String elements, unknown
## biome ids): unknown ids fall back to the raw id so the player still sees a
## non-empty celebration rather than a blank row.
func _render_region_unlock_row(summary: OfflineProgressionEngine.OfflineSummary) -> void:
	if not summary.has_meta("_biomes_unlocked"):
		_region_unlock_row.visible = false
		return
	var raw: Variant = summary.get_meta("_biomes_unlocked")
	if not (raw is Array) or (raw as Array).is_empty():
		_region_unlock_row.visible = false
		return

	var names: Array[String] = []
	for biome_id_v: Variant in (raw as Array):
		var biome_id: String = String(biome_id_v)
		if biome_id == "":
			continue
		var display: String = biome_id
		var biome: Biome = BiomeDungeonDatabase.get_biome_by_id(biome_id)
		if biome != null and String(biome.display_name) != "":
			display = String(biome.display_name)
		names.append(display)

	if names.is_empty():
		_region_unlock_row.visible = false
		return

	_region_unlock_row.text = UIFrameworkScript.format_localized(
		"biome_unlocked_toast_format", [", ".join(names)]
	)
	_region_unlock_row.visible = true


## Renders the "Driven back at Floor X — your guild is recovering." offline-defeat
## notice from the summary's "_defeated_at_floor" meta (an int floor index set by
## OfflineProgressionEngine when an offline-replay window ended in DEFEAT). Reuses
## the run_defeat_floor_format string the live dungeon-run defeat overlay uses
## (dungeon_run_view._show_defeat_overlay) so the offline and foreground defeat
## voices read identically. Hides the row when the meta is absent (a WINNING
## window, the common case) or malformed.
##
## Defensive against a non-int meta: typeof-guards the read (memory:
## project_dict_get_default_only_on_missing_key — a defaulted meta read can still
## return a present-but-wrong-typed value) and hides the row rather than crash.
func _render_defeat_notice_row(summary: OfflineProgressionEngine.OfflineSummary) -> void:
	if not summary.has_meta("_defeated_at_floor"):
		_defeat_notice_row.visible = false
		return
	var raw: Variant = summary.get_meta("_defeated_at_floor", 0)
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		_defeat_notice_row.visible = false
		return
	var floor_index: int = int(raw)
	if floor_index <= 0:
		_defeat_notice_row.visible = false
		return
	_defeat_notice_row.text = UIFrameworkScript.format_localized(
		"run_defeat_floor_format", [floor_index]
	)
	_defeat_notice_row.visible = true


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
	_region_unlock_row.visible = false
	_defeat_notice_row.visible = false
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


# ---------------------------------------------------------------------------
# Audio
# ---------------------------------------------------------------------------

## Selects the return-to-app chime by cap state. Pure (no I/O) so the
## cap-precedence decision is unit-testable without the audio singleton.
## Mutually exclusive by design: a capped return ([param clipped_seconds] > 0,
## the guild reached its offline ceiling) gets the distinct "threshold reached"
## cue; a normal return gets the warm welcome-back chime. The exact cues are a
## taste call the audio director can retune — only the cap-vs-normal split is
## load-bearing here.
func _select_return_cue(clipped_seconds: int) -> StringName:
	if clipped_seconds > 0:
		return &"sfx_prestige_completed"
	return &"sfx_reward_level_up_chime"


## Plays a one-shot SFX cue through the AudioRouter autoload, mirroring the
## recruitment screen's defensive idiom (UI sounds route via AudioRouter). No-ops
## when the autoload is absent (headless tests) or lacks play_sfx, so this never
## crashes a test that runs without the audio singleton.
func _play_audio_cue(cue: StringName) -> void:
	var router: Node = get_node_or_null("/root/AudioRouter")
	if router == null or not router.has_method("play_sfx"):
		return
	router.play_sfx(cue)


# ===========================================================================
# Lantern Guild mock wireframe — greybox "while you were away" framing
# Additive: eyebrow above the header, the elapsed subhead enlarged into the
# mock's "clock", and a flavour quote above the acknowledge button. Build once.
# ===========================================================================

func _build_wireframe_once() -> void:
	if _wire_built:
		return
	_wire_built = true
	var vbox: Node = get_node_or_null("SummaryPanel/VBoxContainer")
	if vbox == null:
		return
	var eyebrow: Label = WireframeKitScript.eyebrow("· While you were away ·", WireframeKitScript.ACCENT)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(eyebrow)
	vbox.move_child(eyebrow, 0)

	# Enlarge the elapsed subhead into the mock's "the candle did not go out" clock.
	if _elapsed_subhead != null:
		_elapsed_subhead.add_theme_font_size_override("font_size", 30)
		_elapsed_subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if _acknowledge_button != null:
		var quote: Label = WireframeKitScript.caption(
			"The Guild kept the candle. The heroes kept walking.",
			WireframeKitScript.MUTED, 12)
		quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(quote)
		vbox.move_child(quote, _acknowledge_button.get_index())
