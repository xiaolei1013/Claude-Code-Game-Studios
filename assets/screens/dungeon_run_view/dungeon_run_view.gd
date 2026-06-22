## DungeonRunView — live tick + kill_count display + RUN_ENDED overlay + auto-route.
##
## Presentation-layer screen (extends Screen) that subscribes to two signals
## while active:
##   1. [signal TickSystem.tick_fired] at 20 Hz → refreshes tick + kill_count
##      labels O(1) from [member DungeonRunOrchestrator.run_snapshot] (no allocs).
##   2. [signal DungeonRunOrchestrator.state_changed] → detects RUN_ENDED,
##      shows the run-end overlay (Story 012 AC-6 preferred path), and
##      auto-routes via [method SceneManager.request_screen] (Story 013 AC-1/AC-7).
##      Defeat & Injury Phase 4 (GDD #34 §I) forks this route on the run verdict:
##      a WIN routes to victory_moment; a DEFEAT shows a distinct defeat overlay
##      and routes to guild_hall (the injured-party recovery surface).
##   3. [signal DungeonRunOrchestrator.run_defeated] → the dedicated DEFEAT moment;
##      surfaces the distinct defeat overlay the instant the run is lost (Phase 4).
##
## A watchable-battle read-model (Phase 4) also polls four orchestrator getters
## each tick (current_party_hp / max_party_hp / enemies_remaining / enemy_total)
## to drive a party HP bar + enemy-depletion count so the two-sided HP race is
## visible in real time.
##
## Acceptance Criteria (8 ACs from Story 012, Sprint 8 S8-M2):
##   AC-1: Live tick display — refreshes on every tick_fired; lags ≤1 tick.
##   AC-2: Live kill_count display — same refresh policy as AC-1.
##   AC-3: Run-end overlay — appears when state transitions to RUN_ENDED;
##         non-blocking (does not freeze the tree or require player input).
##   AC-4: ≥30 FPS while per-tick refresh is active (deferred to S8-M4 smoke).
##   AC-5: Lifecycle hygiene — on_exit disconnects ALL subscriptions; no leaked
##         tick connection after leaving this screen.
##   AC-6: RUN_ENDED detection via DungeonRunOrchestrator.state_changed signal.
##   AC-7: No hardcoded Color literals; no per-screen Theme; no interactive
##         Controls with FOCUS_ALL; suppress_keyboard_focus called in on_enter().
##   AC-8: Screen is reached via SceneManager.request_screen("dungeon_run_view");
##         no SceneTree.change_scene_to_* calls anywhere in this file.
##
## Acceptance Criteria (7 ACs from Story 013, Sprint 8 S8-M3):
##   AC-1: Auto-route on RUN_ENDED — calls SceneManager.request_screen("victory_moment",
##         CROSS_FADE) exactly once after RUN_ENDED is detected.
##   AC-2: Transition completes within ≤500 ms total wall-clock time.
##   AC-3: RUN_END_DWELL_MS = 1500 ms (Sprint 9 S9-M2 polish; valid range [0, 2000]).
##         Supersedes Story 013 Sprint 8 AC-3 range [0, 350] — playtest evidence
##         (S8-M5) showed sub-2s run durations registered 1/5 on Pillar 2.
##   AC-4: Tick subscription disconnects cleanly after route fires (on_exit path).
##   AC-5: Idempotent — _routed flag prevents request_screen from being called twice.
##   AC-6: No bypass of SceneManager (no SceneTree.change_scene_to_*).
##   AC-7: request_screen("victory_moment", CROSS_FADE) is the sole screen-change call.
##
## Governing ADRs:
##   ADR-0007: Screen lifecycle contract (on_enter/on_exit/on_pause/on_resume).
##   ADR-0008: UI Framework (tap-target enforcement, keyboard focus suppression,
##             no hardcoded Color literals, parchment theme cascade).
##
## PERFORMANCE NOTE — _on_tick_fired runs at 20 Hz (HOT PATH):
##   - O(1): two label.text = str(int) calls + one null-check.
##   - No allocations. No format strings (%d / String.format). No tr() calls.
##   - Static prefix labels ("Tick:", "Kills:") set once in on_enter(), not here.
##
## PROCESS MODE NOTE (ADR-0007 Risks Note 4):
##   This screen inherits PROCESS_MODE_PAUSABLE from ScreenContainer. When a
##   modal overlay opens (get_tree().paused = true), _on_tick_fired naturally
##   stops firing — correct behavior; overlay closes before ticks resume.
##
## Story 012 — Sprint 8 S8-M2 | Story 013 — Sprint 8 S8-M3
## Sprint 10 S10-M4: subscribes to HeroRoster.hero_leveled and surfaces a level-up
## toast for the felt-progression moment (first time a hero levels up after a run).
## Toast auto-dismisses after LEVEL_UP_TOAST_LIFETIME_SEC.
extends Screen

# ---------------------------------------------------------------------------
# Preload
# ---------------------------------------------------------------------------

const UIFrameworkScript = preload("res://src/ui/ui_framework.gd")
const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const WireframeKitScript = preload("res://src/ui/wireframe_kit.gd")
# Demo enemy sprites for the "Enemies ahead" lineup (no-op without demo assets).
const EnemySpriteFactoryScript = preload("res://src/ui/enemy_sprite_factory.gd")
# Hero class sprites for the party diorama (Hero Combat Presence epic, GDD #35).
# Preloaded (not called via the global class_name) so the static get_idle_frames
# call never races the cold-load class registry — same pattern as the enemy
# factory above and the _biome_background typed-as-ColorRect note.
const ClassSpriteFactoryScript = preload("res://src/ui/class_sprite_factory.gd")
const VfxKitScript = preload("res://src/ui/vfx_kit.gd")

## VFX particle textures (committed product art). All loaded best-effort in
## on_enter via _ensure_vfx_texture; each tolerates a missing texture (un-imported
## on a fresh clone before the asset import runs → null → VfxKit no-ops, no crash).
## GDD #27 OQ-27-1 event→texture taxonomy: kill→gold-sparkle, level-up→parchment-
## shimmer, first floor-clear→lantern-glow.
const VFX_BURST_TEXTURE_PATH: String = "res://assets/vfx/particles/gold_sparkle.png"
const VFX_LEVELUP_TEXTURE_PATH: String = "res://assets/vfx/particles/parchment_shimmer.png"
const VFX_FLOOR_CLEAR_TEXTURE_PATH: String = "res://assets/vfx/particles/lantern_glow.png"

## VFX burst layer — created in on_enter, freed in on_exit. All event bursts
## (kill, level-up, floor-clear) spawn into it via VfxKit so they never pollute
## the screen's direct children (e.g. the _live_toast_count() scan).
var _vfx_layer: Node2D = null
## Cached burst textures (each may be null — see the *_TEXTURE_PATH consts).
var _vfx_burst_texture: Texture2D = null
var _vfx_levelup_texture: Texture2D = null
var _vfx_floor_clear_texture: Texture2D = null

# ---------------------------------------------------------------------------
# Constants (Story 013)
# ---------------------------------------------------------------------------

## Dwell duration in milliseconds between showing the run-end overlay and
## auto-routing to victory_moment.
##
## Sprint 9 S9-M2 polish: bumped from 0 to 1500 ms to ensure ≥2 s perceived
## run duration (Story 013 AC-3 spec deviation). Playtest S8-M5 showed
## sub-2 s runs scored 1/5 on Pillar 2 ("run feels meaningful"). Valid range
## is now [0, 2000]; the Story 013 Sprint 8 constraint of [0, 350] is
## superseded by playtest evidence. See sprint-9.md S9-M2 closure note.
const RUN_END_DWELL_MS: int = 1500

## Lifetime in seconds for the S10-M4 level-up toast. AC: "auto-dismisses ~3s".
## Pattern: 0–2.4 s held visible at full alpha; 2.4–3.0 s fade-out via Tween.
const LEVEL_UP_TOAST_LIFETIME_SEC: float = 3.0
const LEVEL_UP_TOAST_FADE_START_SEC: float = 2.4

## Hero levels that earn an emphasized "milestone" toast (vs the routine
## per-level toast). 15 is the level cap, so it doubles as the max-level beat.
const _MILESTONE_LEVELS: Array[int] = [10, 15]

## Emphasized-toast font size (vs the theme-default routine toast).
const _MILESTONE_TOAST_FONT_SIZE: int = 20

# ---------------------------------------------------------------------------
# @onready node references (matched to .tscn node names)
# ---------------------------------------------------------------------------

## Live tick counter label — value updated per tick in _on_tick_fired.
@onready var _tick_label: Label = $StatsPanel/TickRow/TickLabel

## Live kill count label — value updated per tick in _on_tick_fired.
@onready var _kill_count_label: Label = $StatsPanel/KillCountRow/KillCountLabel

## Hidden when the run-end overlay is shown — both panels are anchored at
## center 50% so without hiding, the live tick/kill labels render through
## the overlay's transparent PanelContainer background.
@onready var _stats_panel: VBoxContainer = $StatsPanel

## Run-end overlay container. Hidden by default; shown when state → RUN_ENDED.
@onready var _run_end_overlay: Control = $RunEndOverlay

## Label inside the overlay that receives the final kill_count summary text.
@onready var _run_end_label: Label = $RunEndOverlay/RunEndLabel

## Sprint 19 S19-M3 — HD-2D pipeline biome background layer (GDD #26 + ADR-0019).
## Set to the active run's biome on on_enter so the diorama register reflects
## where the player is dispatched. Falls back to forest_reach if no run is
## currently dispatched (idle DRV — possible via dev navigation).
##
## Typed as ColorRect (BiomeBackground's base class) because the `class_name
## BiomeBackground` global registration is not guaranteed at script-parse time
## in Godot 4.6 — the registry can be cold-loaded after this file's parse.
## Method calls (set_biome) dispatch dynamically and resolve correctly.
@onready var _biome_background: ColorRect = $BiomeBackground

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Set to true after _show_run_end_overlay fires so _on_state_changed is
## idempotent (overlay shows exactly once per screen lifetime, even if
## state_changed fires more than once with RUN_ENDED — defensive guard).
var _overlay_shown: bool = false

## Set to true after request_screen("victory_moment") fires so _on_state_changed
## is idempotent on the routing side (AC-5 Story 013). Guards against a second
## request_screen call if state_changed emits RUN_ENDED more than once while
## the transition is in flight (which would trigger a push_warning from
## SceneManager's TRANSITIONING queue-overwrite guard).
## Distinct from _overlay_shown — they guard different concerns.
var _routed: bool = false

## Lantern Guild mock wireframe (feat/ui-wireframe-core-loop) — greybox HUD state.
var _wire_built: bool = false
var _float_layer: Control = null

## Watchable-battle read-model widgets (Defeat & Injury Phase 4, GDD #34 §I).
## Built additively inside the wireframe HUD; refreshed per tick from the
## orchestrator's party-HP + enemy-lineup getters so the player can WATCH the
## two-sided HP race deplete in real time (and read the defeat moment, L4).
## All three are null until [method _build_wireframe_once] runs; every refresh
## path null-guards them.
var _party_hp_bar: ProgressBar = null
var _party_hp_label: Label = null
var _enemies_remaining_label: Label = null

## Party diorama layer (Hero Combat Presence epic, GDD #35 · Story 005 · ADR-0025).
## A dedicated, additive Control holding one hero sprite per OCCUPIED formation
## slot — the party the player dispatched, rendered center-stage below the enemy
## lineup. Built once in [method _build_wireframe_once]; null until then. Story 006
## attaches the idle SpriteSheetAnimator to each slot; Stories 008–009 fire the
## reaction beats. See [method _build_party_diorama].
var _party_diorama_layer: Control = null


# ---------------------------------------------------------------------------
# Built-in lifecycle (_ready — tap-target + label localisation)
# ---------------------------------------------------------------------------

## Sets localized static prefix text on the two prefix labels.
## These are set once and never changed — they must NOT be set inside
## _on_tick_fired (HOT PATH) because tr() + string assignment allocates.
##
## No interactive Controls exist on this screen in Sprint 8 VS so
## assert_tap_target_min is not called here; suppress_keyboard_focus is
## called in on_enter() after the tree is fully ready.
func _ready() -> void:
	# Localized static prefix labels — written exactly once per lifetime.
	$StatsPanel/TickRow/TickPrefixLabel.text = tr("tick_label_prefix")
	$StatsPanel/KillCountRow/KillCountPrefixLabel.text = tr("kill_count_label_prefix")
	$HeaderLabel.text = tr("dungeon_run_view_title")

	# Ensure overlay is hidden at scene-ready time (redundant with .tscn default
	# but makes the intent explicit for code readers).
	_run_end_overlay.visible = false
	_overlay_shown = false


# ---------------------------------------------------------------------------
# Screen lifecycle hooks (ADR-0007 — all four MUST be declared)
# ---------------------------------------------------------------------------

## Called by SceneManager after this screen becomes current_screen.
##
## Connects two signals:
##   1. GameTime.tick_fired → _on_tick_fired (20 Hz hot path).
##   2. DungeonRunOrchestrator.state_changed → _on_state_changed.
##
## Performs an immediate _refresh_display() so labels show the current snapshot
## even before the first tick fires. Calls UIFramework.suppress_keyboard_focus
## to enforce the single-focus-mode strategy (ADR-0008).
func on_enter() -> void:
	# Reset both idempotency guards for this screen visit (Story 012 + Story 013).
	_overlay_shown = false
	_routed = false
	_run_end_overlay.visible = false

	# Sprint 19 S19-M3 — set the biome background to match the active dispatch.
	# Pass the dispatched floor_index so the boss floor renders with a darkened
	# palette per BiomeBackground's per-floor modulation. Regular floors render
	# at baseline. get_dispatched_biome_id() returns "" when no run is active
	# (e.g. dev nav into DRV); BiomeBackground falls back to forest_reach per
	# its own contract (GDD #26 §E + AC-26-12).
	if _biome_background != null:
		_biome_background.set_biome(
			DungeonRunOrchestrator.get_dispatched_biome_id(),
			DungeonRunOrchestrator.get_dispatched_floor_index()
		)

	# Subscribe to tick_fired — 20 Hz hot path.
	# Idempotent via is_connected guard (defensive; SceneManager guarantees
	# only one on_enter per lifetime but guard costs nothing).
	if not TickSystem.tick_fired.is_connected(_on_tick_fired):
		TickSystem.tick_fired.connect(_on_tick_fired)

	# Subscribe to state_changed — preferred RUN_ENDED detection path (AC-6).
	if not DungeonRunOrchestrator.state_changed.is_connected(_on_state_changed):
		DungeonRunOrchestrator.state_changed.connect(_on_state_changed)

	# Defeat & Injury Phase 4 (GDD #34 §I): subscribe run_defeated so the DEFEAT
	# moment surfaces its own distinct overlay (NOT the victory run-end overlay).
	# Fires the instant the run is lost, just before the FSM transition to
	# RUN_ENDED. The ROUTE decision (guild_hall vs victory_moment) lives in
	# _on_state_changed, which consults was_last_run_defeated() so it stays
	# correct even if this signal is missed. Disconnected in on_exit.
	if not DungeonRunOrchestrator.run_defeated.is_connected(_on_run_defeated):
		DungeonRunOrchestrator.run_defeated.connect(_on_run_defeated)

	# Sprint 10 S10-M4: subscribe to HeroRoster.hero_leveled so the orchestrator's
	# stub XP grant on floor-clear surfaces a player-visible toast. Disconnected
	# in on_exit (AC-5 lifecycle hygiene). Idempotent via is_connected guard.
	if not HeroRoster.hero_leveled.is_connected(_on_hero_leveled):
		HeroRoster.hero_leveled.connect(_on_hero_leveled)

	# Felt-progression: a gate floor cleared THIS run can unlock a new region.
	# biome_unlocked fires while this screen is live (the player is watching the
	# run), so the toast surfaces here — the guild_hall subscription rarely sees
	# it because the hall isn't the active screen mid-run. Disconnected in on_exit.
	if FloorUnlock.has_signal("biome_unlocked") and not FloorUnlock.biome_unlocked.is_connected(_on_biome_unlocked):
		FloorUnlock.biome_unlocked.connect(_on_biome_unlocked)

	# VFX: create the shared burst container + load the three event textures
	# (committed product art); subscribe the kill + first-floor-clear feedback
	# signals. (level-up rides the existing hero_leveled subscription above.)
	# All disconnected + freed in on_exit (AC-5 lifecycle hygiene).
	if _vfx_layer == null:
		_vfx_layer = Node2D.new()
		_vfx_layer.name = "VfxBurstLayer"
		add_child(_vfx_layer)
	_vfx_burst_texture = _ensure_vfx_texture(_vfx_burst_texture, VFX_BURST_TEXTURE_PATH)
	_vfx_levelup_texture = _ensure_vfx_texture(_vfx_levelup_texture, VFX_LEVELUP_TEXTURE_PATH)
	_vfx_floor_clear_texture = _ensure_vfx_texture(_vfx_floor_clear_texture, VFX_FLOOR_CLEAR_TEXTURE_PATH)
	if not DungeonRunOrchestrator.enemy_killed.is_connected(_on_enemy_killed_vfx):
		DungeonRunOrchestrator.enemy_killed.connect(_on_enemy_killed_vfx)
	# First-time floor clear → ceremonial lantern-glow (GDD #27 OQ-27-1, frontier
	# beat). No existing screen consumes this signal for feedback, so wire it here
	# where the player is watching the run.
	if not DungeonRunOrchestrator.floor_cleared_first_time.is_connected(_on_floor_cleared_vfx):
		DungeonRunOrchestrator.floor_cleared_first_time.connect(_on_floor_cleared_vfx)

	# Initial render — snap labels to the current snapshot (covers the case
	# where this screen is shown after DISPATCHING has already begun and ticks
	# have already advanced the snapshot before on_enter fires).
	_refresh_display()

	# Single-focus-mode strategy: suppress keyboard/gamepad focus on all Controls.
	UIFrameworkScript.suppress_keyboard_focus(self)

	# Lantern Guild mock wireframe (feat/ui-wireframe-core-loop): build the
	# greybox live-Expedition HUD once.
	_build_wireframe_once()

	# Story 013 (Sprint 13 S13-S1) replaces the prior on_enter early-detection
	# hotfix with an orchestrator-level buffered-replay pattern. The Sprint 8
	# S8-M4 + Sprint 9 S9-M2 hotfixes were screen-level workarounds for the
	# during-transition race; the orchestrator now buffers state_changed
	# emissions while SceneManager.state == TRANSITIONING and replays them
	# at SceneManager.transition_complete time, so the slow-path
	# _on_state_changed handler (below) handles BOTH the during-transition
	# fast path AND the normal mid-run path identically.
	#
	# Removed:
	#   - on_enter early-detection block (`if state == RUN_ENDED: ...`)
	#   - _deferred_run_end_route() helper
	# Both became redundant once the orchestrator owns the deferral.
	# See production/epics/dungeon-run-orchestrator/story-013-...md for spec.


## Called by SceneManager BEFORE queue_free. Disconnects ALL signals connected
## in on_enter. After this returns, no orphaned connections remain.
##
## AC-5: GameTime.tick_fired.is_connected(<handler>) == false after on_exit.
func on_exit() -> void:
	# Disconnect tick_fired — primary lifecycle signal for AC-5.
	if TickSystem.tick_fired.is_connected(_on_tick_fired):
		TickSystem.tick_fired.disconnect(_on_tick_fired)

	# Disconnect state_changed.
	if DungeonRunOrchestrator.state_changed.is_connected(_on_state_changed):
		DungeonRunOrchestrator.state_changed.disconnect(_on_state_changed)

	# Defeat & Injury Phase 4: mirror the on_enter run_defeated subscription.
	if DungeonRunOrchestrator.run_defeated.is_connected(_on_run_defeated):
		DungeonRunOrchestrator.run_defeated.disconnect(_on_run_defeated)

	# Sprint 10 S10-M4: mirror the on_enter hero_leveled subscription.
	if HeroRoster.hero_leveled.is_connected(_on_hero_leveled):
		HeroRoster.hero_leveled.disconnect(_on_hero_leveled)

	# Mirror the on_enter biome_unlocked subscription.
	if FloorUnlock.has_signal("biome_unlocked") and FloorUnlock.biome_unlocked.is_connected(_on_biome_unlocked):
		FloorUnlock.biome_unlocked.disconnect(_on_biome_unlocked)

	# VFX: mirror the on_enter subscriptions + tear down the burst layer.
	if DungeonRunOrchestrator.enemy_killed.is_connected(_on_enemy_killed_vfx):
		DungeonRunOrchestrator.enemy_killed.disconnect(_on_enemy_killed_vfx)
	if DungeonRunOrchestrator.floor_cleared_first_time.is_connected(_on_floor_cleared_vfx):
		DungeonRunOrchestrator.floor_cleared_first_time.disconnect(_on_floor_cleared_vfx)
	if _vfx_layer != null:
		_vfx_layer.queue_free()
		_vfx_layer = null
		_vfx_burst_texture = null
		_vfx_levelup_texture = null
		_vfx_floor_clear_texture = null


## Called by SceneManager when a modal overlay opens on top of this screen.
## No per-screen animations to suspend in Sprint 8 VS.
##
## PROCESS MODE NOTE: ScreenContainer is PROCESS_MODE_PAUSABLE, so
## _on_tick_fired naturally stops firing when get_tree().paused == true.
## on_pause() does not need to manually disconnect the tick subscription.
func on_pause() -> void:
	pass


## Called by SceneManager when the modal overlay closes.
## Snaps labels to the current snapshot in case ticks fired during pause
## (they should not under PROCESS_MODE_PAUSABLE, but this is a safety net
## for any environment where process mode differs from production).
func on_resume() -> void:
	_refresh_display()


# ---------------------------------------------------------------------------
# Per-tick handler — HOT PATH at 20 Hz (O(1) — no allocations allowed)
# ---------------------------------------------------------------------------

## Per-tick handler wired to [signal TickSystem.tick_fired].
##
## HOT PATH CONTRACT:
##   - Defensive null-check on run_snapshot; early-return if null.
##   - Two [code]label.text = str(int)[/code] assignments.
##   - Zero allocations. Zero format strings. Zero tr() calls.
##   - No signal re-emits, no call_deferred.
##
## AC-1: _tick_label.text updated to str(run_snapshot.current_tick).
## AC-2: _kill_count_label.text updated to str(run_snapshot.kill_count).
##
## [param tick_number] is the absolute TickSystem tick counter; not used
## directly (the snapshot's current_tick field mirrors it after each advance).
func _on_tick_fired(_tick_number: int) -> void:
	# Defensive: run_snapshot is null when state is NO_RUN or early DISPATCHING.
	var orch_snapshot: RunSnapshot = DungeonRunOrchestrator.run_snapshot
	if orch_snapshot == null:
		return

	# HOT PATH: two str(int) label writes — the cheap O(1) tick/kill readout.
	_tick_label.text = str(orch_snapshot.current_tick)
	_kill_count_label.text = str(orch_snapshot.kill_count)

	# Watchable-battle HP bar + enemy depletion (Defeat & Injury Phase 4). Polls
	# the orchestrator getters each tick — this rebuilds a small per-loop kill
	# schedule array per call, an acceptable cost at 20 Hz for an idle game with
	# a handful of enemies (the project is "never CPU-bound", per the perf budget).
	_refresh_battle_status()


# ---------------------------------------------------------------------------
# State-change handler — run-end overlay detection (AC-3 / AC-6)
# ---------------------------------------------------------------------------

## Handles [signal DungeonRunOrchestrator.state_changed].
##
## When [param new_state] == RUN_ENDED this is the SOLE run-end routing decision
## point. It consults [method DungeonRunOrchestrator.was_last_run_defeated] and
## forks:
##   - WIN   → victory run-end overlay (Story 012) + route to victory_moment
##             (Story 013 AC-1).
##   - DEFEAT→ distinct defeat overlay (GDD #34 §I) + route to guild_hall, the
##             injured-party recovery surface (Phase 3 already shows injured
##             cards there). NEVER victory_moment.
##
## Reading the verdict from the getter (rather than only from the run_defeated
## signal) keeps routing correct even when run_defeated was missed — e.g. a very
## short doomed run whose defeat fired before this screen subscribed, replayed by
## SceneManager at transition_complete. [method _on_run_defeated] still shows the
## defeat overlay early when the signal IS observed; here it is re-shown
## idempotently as the fallback.
##
## Two distinct idempotency guards cooperate here:
##   [member _overlay_shown] — prevents either overlay from being shown twice.
##   [member _routed]        — prevents request_screen from being called twice
##                             (AC-5 Story 013; a second call while TRANSITIONING
##                             would overwrite the queue with push_warning).
##
## If [const RUN_END_DWELL_MS] > 0 an awaited one-shot Timer gates the route
## call, making this handler async. The [member _routed] flag is set BEFORE
## the await so any re-entrant emission during the dwell is a no-op.
## Sprint 9 S9-M2: default RUN_END_DWELL_MS = 1500 — overlay holds for 1.5 s
## before the cross-fade fires.
##
## AC-7 Story 013: request_screen(...) is the sole screen-change call — no
## SceneTree.change_scene_to_* call anywhere in this handler.
func _on_state_changed(new_state: int, _old_state: int) -> void:
	if new_state != DungeonRunStateScript.State.RUN_ENDED:
		return

	# Baseline transition (GDD #35 §C.4 / ADR-0025): the run is over — freeze every
	# hero's looping idle so the party holds its pose under the run-end overlay. This
	# is the coarse, HUMAN-frequency hero-state reflection (NOT the 20 Hz tick); the
	# terminal victory/slump beat that plays over the frozen pose is Story 009. Placed
	# BEFORE the _routed idempotency guard so the freeze fires on every RUN_ENDED entry
	# (incl. a transition-replayed duplicate) — set_animating(false) is idempotent.
	_set_party_idle_animating(false)

	if _routed:
		return  # AC-5 idempotency — route already requested; ignore duplicate.
	_routed = true

	# Fork on the run verdict. was_last_run_defeated() survives into RUN_ENDED
	# (reset only at the next dispatch), so it is authoritative here even if the
	# run_defeated signal was missed during a transition-replay.
	var defeated: bool = DungeonRunOrchestrator.was_last_run_defeated()
	if defeated:
		# Defeat moment — normally already shown by _on_run_defeated; _show_defeat_
		# overlay is idempotent so this is a harmless re-show on the fallback path.
		_show_defeat_overlay(DungeonRunOrchestrator.get_dispatched_floor_index())
	else:
		# Victory run-end overlay (Story 012). _overlay_shown guards double-show.
		var final_kills: int = 0
		if DungeonRunOrchestrator.run_snapshot != null:
			final_kills = DungeonRunOrchestrator.run_snapshot.kill_count
		_show_run_end_overlay(final_kills)

	# Optional dwell before routing (AC-3 Story 013, expanded by Sprint 9 S9-M2).
	# RUN_END_DWELL_MS = 1500 (Sprint 9 S9-M2) — await holds the overlay for ≥1500 ms.
	if RUN_END_DWELL_MS > 0:
		await get_tree().create_timer(RUN_END_DWELL_MS / 1000.0).timeout

	# DEFEAT → guild_hall recovery surface; WIN → victory_moment (Story 013 AC-1).
	var destination: String = "guild_hall" if defeated else "victory_moment"
	SceneManager.request_screen(destination, SceneManager.TransitionType.CROSS_FADE)


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

## Reads the current [member DungeonRunOrchestrator.run_snapshot] and updates
## both labels to the current values. Used for the initial render in on_enter()
## and for the safety snap in on_resume().
##
## Defensive null-check: if run_snapshot is null, resets labels to "0".
func _refresh_display() -> void:
	var orch_snapshot: RunSnapshot = DungeonRunOrchestrator.run_snapshot
	if orch_snapshot == null:
		_tick_label.text = "0"
		_kill_count_label.text = "0"
		_refresh_battle_status()
		return
	_tick_label.text = str(orch_snapshot.current_tick)
	_kill_count_label.text = str(orch_snapshot.kill_count)
	_refresh_battle_status()


## Refreshes the watchable-battle party HP bar + enemy-depletion count from the
## orchestrator read-model getters (Defeat & Injury Phase 4, GDD #34 §I). Pure
## display — reads four getters, writes the bar value + two numeric labels. All
## widgets are null until [method _build_wireframe_once] runs, so every write is
## null-guarded; the call is a harmless no-op before the HUD is built.
##
## Truthful bar: [method DungeonRunOrchestrator.current_party_hp] delegates to the
## resolver's defeat-verdict curve, so the bar reaches 0 exactly at the run's
## defeat_tick (ADR-0021). The numeric "cur/max" + "remaining/total" labels keep
## the readout colorblind-safe (never color-only).
func _refresh_battle_status() -> void:
	var cur_hp: int = DungeonRunOrchestrator.current_party_hp()
	var max_hp: int = DungeonRunOrchestrator.max_party_hp()
	var remaining: int = DungeonRunOrchestrator.enemies_remaining()
	var total: int = DungeonRunOrchestrator.enemy_total()
	if _party_hp_bar != null:
		_party_hp_bar.max_value = maxf(1.0, float(max_hp))
		_party_hp_bar.value = float(cur_hp)
	if _party_hp_label != null:
		_party_hp_label.text = "HP %d/%d" % [cur_hp, max_hp]
	if _enemies_remaining_label != null:
		_enemies_remaining_label.text = "Enemies %d/%d" % [remaining, total]


# ---------------------------------------------------------------------------
# Sprint 10 S10-M4 — level-up toast (felt-progression moment)
# ---------------------------------------------------------------------------

## Handles [signal HeroRoster.hero_leveled] while the dungeon_run_view is
## active. Resolves the hero's display_name from HeroRoster, formats a
## localized toast string, and shows a transient Label that fades out and
## queue_frees itself after [const LEVEL_UP_TOAST_LIFETIME_SEC].
##
## Multiple level-ups in close succession (e.g., a 3-hero formation all
## leveling on the same floor clear) each get their own toast, vertically
## stacked just below the header.
##
## Localization key: [code]"hero_level_up_toast_format"[/code]; falls back to
## "%s reached level %d!" plain-format when the locale doesn't define the key.
##
## ADR-0008 §Touch parity: this toast is purely informational — no input
## required to dismiss. mouse_filter is IGNORE so it never blocks tap-through.
func _on_hero_leveled(instance_id: int, _old_level: int, new_level: int) -> void:
	# Resolve display_name from the live roster. Defensive: if the hero is no
	# longer in the roster (mid-run remove), skip the toast.
	var display_name: String = ""
	for hero: Variant in HeroRoster.get_all_heroes():
		if hero == null:
			continue
		if "instance_id" in hero and int(hero.get("instance_id")) == instance_id:
			if "display_name" in hero:
				display_name = String(hero.get("display_name"))
			break
	if display_name.is_empty():
		display_name = str(instance_id)

	# Milestone levels (10, cap-15) earn an emphasized toast; routine levels get
	# the standard one. Both auto-dismiss + stack via the shared spawner.
	var is_milestone: bool = new_level in _MILESTONE_LEVELS
	var loc_key: String = "hero_milestone_toast_format" if is_milestone else "hero_level_up_toast_format"
	var text: String = UIFrameworkScript.format_localized(loc_key, [display_name, new_level])
	_spawn_run_toast(text, "LevelUpToast_%d" % instance_id, is_milestone)

	# GDD #27 OQ-27-1: a parchment-shimmer accompanies the level-up toast, spawned
	# at the toast anchor (top-centre). MOSS_SAGE is the level-up accent tint;
	# milestones burst a little brighter/larger. VfxKit no-ops on reduce_motion or
	# a missing texture, so this is safe even before the asset imports.
	if _vfx_layer != null:
		var shimmer_amount: int = 14 if is_milestone else 9
		VfxKitScript.spawn_burst(
			_vfx_layer, size * Vector2(0.5, 0.2), _vfx_levelup_texture,
			VfxKitScript.MOSS_SAGE, shimmer_amount, 0.7, _reduce_motion())


## Felt-progression: a new region unlocked mid-run (a gate floor cleared). Shows
## an emphasized toast naming the region. Defensive — skips if the biome can't be
## resolved (data drift). Mirrors guild_hall._on_biome_unlocked, but fires here
## where the player is actually watching when the unlock happens.
func _on_biome_unlocked(biome_id: String) -> void:
	var biome: Variant = DataRegistry.resolve("biomes", biome_id)
	if biome == null or not ("display_name" in biome):
		return
	var display_name: String = String(biome.get("display_name"))
	if display_name.is_empty():
		return
	var text: String = UIFrameworkScript.format_localized(
		"biome_unlocked_toast_format", [display_name]
	)
	_spawn_run_toast(text, "BiomeUnlockToast", true)


## Spawns a self-fading, self-freeing toast Label anchored top-center. Stacks
## below any live toasts. [param emphasized] bumps the font size + tints it the
## WireframeKit accent (gold) for milestone / unlock beats. The owning Tween is
## parented to the toast so it auto-cleans if the screen exits mid-fade.
func _spawn_run_toast(text: String, node_name: String, emphasized: bool) -> void:
	var toast: Label = Label.new()
	toast.name = node_name
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# S10-N1: hoisted safe-format pattern — caller already formatted the text.
	toast.text = text
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(0, 56 + _live_toast_count() * 28)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if emphasized:
		toast.add_theme_font_size_override("font_size", _MILESTONE_TOAST_FONT_SIZE)
		toast.add_theme_color_override("font_color", WireframeKitScript.ACCENT)
	add_child(toast)

	# Held visible for FADE_START_SEC, then fade modulate.a 1.0 → 0.0 over the
	# remaining lifetime, then queue_free. Tween owned by the toast so it
	# auto-cleans if the screen exits early (Tween freed with parent).
	var tween: Tween = toast.create_tween()
	tween.tween_interval(LEVEL_UP_TOAST_FADE_START_SEC)
	tween.tween_property(
		toast, "modulate:a", 0.0,
		LEVEL_UP_TOAST_LIFETIME_SEC - LEVEL_UP_TOAST_FADE_START_SEC
	)
	tween.tween_callback(toast.queue_free)


## S28-N1: spawns a kill-feedback gold-burst when an enemy dies mid-run. Matchup-
## advantaged kills burst brighter Lantern Gold; neutral kills Guild Amber; higher
## tiers burst bigger (GDD #27 OQ-27-1 "gold-coin-burst sized by tier"). Origin is
## the diorama centre — a feel-default that playtest tuning (S28-M1) will refine.
## reduce_motion suppresses the burst (VfxKit snap-replace, OQ-27-3). No-op when the
## gitignored demo texture is absent (CI / fresh clone).
func _on_enemy_killed_vfx(tier: int, _archetype: String, advantaged: bool) -> void:
	if _vfx_layer == null or _vfx_burst_texture == null:
		return
	var tint: Color = VfxKitScript.LANTERN_GOLD if advantaged else VfxKitScript.GUILD_AMBER
	var amount: int = clampi(6 + tier * 2, 6, 20)
	var origin: Vector2 = size * Vector2(0.5, 0.42)
	VfxKitScript.spawn_burst(
		_vfx_layer, origin, _vfx_burst_texture, tint, amount, 0.55, _reduce_motion())


## GDD #27 OQ-27-1: the first-time clear of a floor earns a ceremonial lantern-glow
## (the frontier fantasy beat). Skipped on a losing run — the floor stays as the
## retry target, so there is no celebration. Bigger + longer than the kill burst
## (Art Bible §7: ≤1500 ms ceremonial). VfxKit no-ops on reduce_motion or a missing
## texture (CI / fresh clone before import).
func _on_floor_cleared_vfx(_floor_index: int, _biome_id: String, losing_run: bool) -> void:
	if _vfx_layer == null or _vfx_floor_clear_texture == null or losing_run:
		return
	VfxKitScript.spawn_burst(
		_vfx_layer, size * Vector2(0.5, 0.42), _vfx_floor_clear_texture,
		VfxKitScript.LANTERN_GOLD, 16, 1.0, _reduce_motion())


## Best-effort load of a committed VFX texture, idempotent. Returns [param cached]
## unchanged when already loaded; otherwise loads via ResourceLoader.exists — NOT
## FileAccess.file_exists, which falsely reports "missing" in an exported build
## where the source .png is stripped and only the imported .ctex is packed. A
## genuinely absent / un-imported texture yields null and VfxKit no-ops (no crash).
func _ensure_vfx_texture(cached: Texture2D, path: String) -> Texture2D:
	if cached != null:
		return cached
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Live accessibility preference; true → VfxKit suppresses all emission (snap-
## replace, GDD #27 OQ-27-3). Safe before the SceneManager autoload exists.
func _reduce_motion() -> bool:
	var sm: Node = get_node_or_null("/root/SceneManager")
	return sm != null and bool(sm.get("reduce_motion"))


## Counts currently-live toasts (level-up + biome-unlock) so newly-spawned
## toasts stack instead of overlapping. A toast is "live" until queue_freed.
func _live_toast_count() -> int:
	var n: int = 0
	for child: Node in get_children():
		if child is Label and child.name.contains("Toast"):
			n += 1
	return n


## Shows the run-end overlay with a localized summary containing the final
## kill_count. Sets [member _overlay_shown] so subsequent calls are no-ops.
##
## [param final_kill_count] is read from the snapshot at the moment of
## RUN_ENDED detection — not re-read later (snapshot may be cleared).
##
## Localization key: [code]"run_complete_kill_count_format"[/code].
## Sprint 8 EN value: "Run Complete — %d kills".
##
## AC-3: overlay visible and non-blocking (does not freeze the tree;
## requires no player input to continue — Story 013 owns the auto-route).
func _show_run_end_overlay(final_kill_count: int) -> void:
	if _overlay_shown:
		return
	_overlay_shown = true
	# S10-N1: hoisted safe-format pattern via UIFramework.format_localized.
	_run_end_label.text = UIFrameworkScript.format_localized(
		"run_complete_kill_count_format", [final_kill_count]
	)
	if _stats_panel != null:
		_stats_panel.visible = false
	_run_end_overlay.visible = true


# ---------------------------------------------------------------------------
# Defeat moment — distinct run-end surface (Defeat & Injury Phase 4, GDD #34 §I)
# ---------------------------------------------------------------------------

## Handles [signal DungeonRunOrchestrator.run_defeated] — the dedicated DEFEAT
## moment (GDD #34 §I / ADR-0021 AC-34-04/05). Fires the instant the in-flight
## run is lost, just BEFORE the FSM transition to RUN_ENDED, so the defeat overlay
## appears on the same frame the player's party is driven back.
##
## This handler shows the overlay only — the screen ROUTE (to guild_hall, not
## victory_moment) is owned by [method _on_state_changed], which fires immediately
## afterward in the same call stack and consults
## [method DungeonRunOrchestrator.was_last_run_defeated] so routing stays correct
## even if this signal was never observed (transition-replay of a short run).
func _on_run_defeated(floor_index: int, _biome_id: String) -> void:
	_show_defeat_overlay(floor_index)


## Shows the DEFEAT moment overlay (GDD #34 §I) — distinct copy from the victory
## run-end overlay, reusing the same RunEndOverlay container + label (one overlay
## surface, two messages). Cozy, non-punishing framing per the game's tone:
## "Driven back at Floor N — your guild is recovering." Idempotent via
## [member _overlay_shown] so the signal path and the _on_state_changed fallback
## path never double-show or fight over the label text.
func _show_defeat_overlay(floor_index: int) -> void:
	if _overlay_shown:
		return
	_overlay_shown = true
	_run_end_label.text = UIFrameworkScript.format_localized(
		"run_defeat_floor_format", [floor_index]
	)
	if _stats_panel != null:
		_stats_panel.visible = false
	_run_end_overlay.visible = true


# ===========================================================================
# Lantern Guild mock wireframe — greybox live Expedition HUD
# (feat/ui-wireframe-core-loop)
#
# Recreates the mock's Expedition layout (party HUD top-left, run stats +
# Return-to-Hall top-right, expedition progress bottom-right, channel-light
# lantern bottom-center, event feed mid-left) at greybox fidelity, built
# additively over the existing display-only nodes. The real tick/kill labels
# are kept and repositioned into the run-stats HUD.
#
# NO Color() literals in this file — all colors route through WireframeKit
# constants (dungeon_run_view_screen_test greps this file for Color literals).
# ===========================================================================

const _WIRE_Z: int = 1


func _place(node: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, orr: float, ob: float) -> void:
	if node == null:
		return
	node.anchor_left = al
	node.anchor_top = at
	node.anchor_right = ar
	node.anchor_bottom = ab
	node.offset_left = ol
	node.offset_top = ot
	node.offset_right = orr
	node.offset_bottom = ob


func _build_wireframe_once() -> void:
	if _wire_built:
		return
	_wire_built = true
	_reposition_existing_nodes_drv()
	_build_party_hud()
	_build_enemy_lineup_drv()
	_build_party_diorama()
	_build_run_stats_hud()
	_build_progress_panel()
	_build_activity_feed_drv()
	_build_lantern_drv()
	var layer: Control = WireframeKitScript.float_layer()
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_float_layer = layer

	# Snap the watchable-battle widgets to the current run state now that they
	# exist (on_enter's earlier _refresh_display ran before this build, so the
	# bar/labels were still null then).
	_refresh_battle_status()


func _reposition_existing_nodes_drv() -> void:
	var header: Label = get_node_or_null("HeaderLabel") as Label
	if header != null:
		_place(header, 0, 0, 1, 0, 0.0, 14.0, 0.0, 54.0)
		header.z_index = 2
	# Real live tick/kill labels → top-right, over the run-stats backing panel.
	if _stats_panel != null:
		_place(_stats_panel, 1, 0, 1, 0, -232.0, 48.0, -28.0, 112.0)
		_stats_panel.z_index = 2
	# Keep the run-end overlay above the wireframe HUD when it shows.
	if _run_end_overlay != null:
		_run_end_overlay.z_index = 5


## Top-left: party HUD — real formation heroes with placeholder HP.
func _build_party_hud() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Party")
	panel.name = "WirePartyHud"
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 0, 0, 0, 0, 14.0, 14.0, 324.0, 232.0)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)

	# Watchable-battle aggregate party HP bar (Defeat & Injury Phase 4, GDD #34 §I).
	# The combat resolver models party HP as a SINGLE pool driving the two-sided
	# race, so one aggregate bar is the truthful representation — per-hero bars
	# would be a fiction the model can't back. Built BEFORE the formation tiles +
	# the empty-party early-return so the bar exists even on a dev-nav idle DRV.
	# A numeric "cur/max" label rides alongside the bar so the readout stays
	# colorblind-safe (never color-only) per the UI accessibility contract.
	var hp_wrap: VBoxContainer = VBoxContainer.new()
	hp_wrap.name = "PartyHpRow"
	hp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_wrap.add_theme_constant_override("separation", 2)
	_party_hp_label = WireframeKitScript.caption("HP —/—", WireframeKitScript.TEXT, 12)
	_party_hp_label.name = "PartyHpLabel"
	hp_wrap.add_child(_party_hp_label)
	_party_hp_bar = ProgressBar.new()
	_party_hp_bar.name = "PartyHpBar"
	_party_hp_bar.custom_minimum_size = Vector2(0, 14)
	_party_hp_bar.show_percentage = false
	_party_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_hp_bar.max_value = 100.0
	_party_hp_bar.value = 100.0
	hp_wrap.add_child(_party_hp_bar)
	body.add_child(hp_wrap)

	var party: Array = []
	if HeroRoster != null:
		party = HeroRoster.get_formation_heroes()
	if party.is_empty():
		body.add_child(WireframeKitScript.caption(
			"No party on this expedition.", WireframeKitScript.MUTED))
		return
	for h: Variant in party:
		if h == null:
			continue
		var nm: String = "Hero"
		if "display_name" in h:
			nm = String(h.display_name)
		var lvl: int = 0
		if "current_level" in h:
			lvl = int(h.current_level)
		var cls: String = ""
		if "class_id" in h:
			cls = String(h.class_id)
		body.add_child(WireframeKitScript.list_tile(
			nm, "%s · Lv %d" % [cls, lvl], "HP"))


## Center, upper-middle: the enemies on the current floor — the diorama focal
## point the party is dispatched against. A horizontal row of sprite + name +
## ×count cells, resolved from the dispatched biome/floor's enemy_list. Enemy
## sprites come from the demo pack (EnemySpriteFactory); absent → greybox box.
func _build_enemy_lineup_drv() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Enemies ahead")
	panel.name = "WireEnemyLineup"
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 0.5, 0, 0.5, 0, -280.0, 188.0, 280.0, 384.0)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)

	# Watchable-battle live lineup-depletion count (Defeat & Injury Phase 4, GDD
	# #34 §I): "Enemies remaining / total", polled per tick. Distinct from the
	# static sprite cells below (which show WHAT is on the floor) — this numeric
	# readout shows HOW MANY are left as the party focus-fires through them.
	# Added before the empty-list early-return so the count is always present.
	_enemies_remaining_label = WireframeKitScript.caption("Enemies —/—", WireframeKitScript.TEXT, 13)
	_enemies_remaining_label.name = "EnemiesRemainingLabel"
	_enemies_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_enemies_remaining_label)

	var enemies: Array = _resolve_floor_enemies()
	if enemies.is_empty():
		body.add_child(WireframeKitScript.caption(
			"The way ahead is quiet.", WireframeKitScript.MUTED))
		return

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	for entry: Dictionary in enemies:
		row.add_child(_make_enemy_cell(entry))


## One enemy cell: sprite thumbnail (or greybox), name, and ×count when >1.
func _make_enemy_cell(entry: Dictionary) -> Control:
	var cell: VBoxContainer = VBoxContainer.new()
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.custom_minimum_size = Vector2(84, 0)
	cell.add_theme_constant_override("separation", 2)

	var tex: Texture2D = EnemySpriteFactoryScript.get_sprite(String(entry.get("enemy_id", "")))
	if tex != null:
		var slot: TextureRect = TextureRect.new()
		slot.custom_minimum_size = Vector2(60, 60)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.texture = tex
		cell.add_child(slot)
	else:
		cell.add_child(WireframeKitScript.placeholder_box("", Vector2(60, 60)))

	var name_lbl: Label = WireframeKitScript.caption(
		String(entry.get("display_name", "")), WireframeKitScript.TEXT, 11)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(84, 0)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cell.add_child(name_lbl)

	var cnt: int = int(entry.get("count", 1))
	if cnt > 1:
		var cnt_lbl: Label = WireframeKitScript.caption(
			"×%d" % cnt, WireframeKitScript.MUTED, 11)
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(cnt_lbl)
	return cell


## Resolves the dispatched floor's enemy roster as
## [{enemy_id, count, display_name}]. Empty when no run is dispatched or the
## biome/floor cannot be resolved. Defensive duck-typing throughout — the screen
## must never crash on missing content.
func _resolve_floor_enemies() -> Array:
	var out: Array = []
	if BiomeDungeonDatabase == null:
		return out
	var biome_id: String = DungeonRunOrchestrator.get_dispatched_biome_id()
	var floor_index: int = DungeonRunOrchestrator.get_dispatched_floor_index()
	if biome_id == "":
		return out

	var biome: Variant = BiomeDungeonDatabase.get_biome_by_id(biome_id)
	if biome == null or not ("dungeons" in biome) or (biome.dungeons as Array).is_empty():
		return out
	var dungeon: Variant = biome.dungeons[0]
	if dungeon == null or not ("floors" in dungeon) or (dungeon.floors as Array).is_empty():
		return out

	var target: Variant = null
	for f: Variant in dungeon.floors:
		if f != null and ("floor_index" in f) and int(f.floor_index) == floor_index:
			target = f
			break
	if target == null:
		target = dungeon.floors[0]  # defensive: fall back to the first floor
	if not ("enemy_list" in target):
		return out

	for entry: Variant in target.enemy_list:
		var data: Dictionary = entry as Dictionary
		var eid: String = String(data.get("enemy_id", ""))
		if eid == "":
			continue
		out.append({
			"enemy_id": eid,
			"count": int(data.get("count", 1)),
			"display_name": _enemy_display_name(eid),
		})
	return out


## Localized-ish display name for an enemy id, via DataRegistry; falls back to
## a capitalized id when the enemy resource or its display_name is unavailable.
func _enemy_display_name(enemy_id: String) -> String:
	if DataRegistry != null and DataRegistry.has_method("resolve"):
		var ed: Variant = DataRegistry.resolve("enemies", enemy_id)
		if ed != null and ("display_name" in ed) and String(ed.display_name) != "":
			return String(ed.display_name)
	return enemy_id.capitalize()


# ===========================================================================
# Party diorama — the front line of heroes the player dispatched
# (Hero Combat Presence epic, GDD #35 · Story 005 · ADR-0025)
#
# Renders one sprite per OCCUPIED formation slot — the count is data-driven from
# HeroRoster.get_formation_heroes() and is NEVER assumed to be 3 — as a centered
# HBox of TextureRects on a dedicated, additive PartyDioramaLayer Control. The
# layer is a SIBLING of the wireframe HUD panels (add_child on root), NOT a
# reparent of WirePartyHud: the screen's node structure stays hard-path-stable
# (the screen test binds nodes by path; restructure additively, never reparent).
#
# Read-only spectacle (GDD #35 §B.2): every node in the subtree is
# MOUSE_FILTER_IGNORE so it can never steal a tap — z_index does NOT gate Godot
# input picking, so the read-only contract is enforced by mouse_filter, not z.
# The plane sits at z = _PARTY_DIORAMA_Z: in front of the tilt-shift DoF (z = -1)
# and the biome (z = 0), behind the stats/header (z = 2) and the run-end overlay
# (z = 5). Theme cascade (ADR-0008) is preserved — every node is a Control, so no
# type="Node" intermediate silently breaks inheritance.
#
# Story 005 renders the STATIC idle frame 0 (or nothing when the class art is
# absent — ClassSpriteFactory's null-fallback contract; the slot still reserves
# its layout space). Story 006 attaches the SpriteSheetAnimator to each slot to
# drive the _process idle loop — NOT in _on_tick_fired (the 20 Hz zero-alloc hot
# path, ADR-0025 §C.9). Each slot stashes its class_id via set_meta so that
# wiring needs no roster re-fetch.
# ===========================================================================

## On-screen display size (px) of each hero sprite — the square bounding box the
## idle frame is fit into (KEEP_ASPECT_CENTERED). UX spec default 72 (range 48–96).
const _HERO_SPRITE_DISPLAY_PX: int = 72

## Horizontal gap (px) between adjacent hero sprites in the front-line row.
const _HERO_SLOT_SEPARATION_PX: int = 24

## Canvas z of the party diorama plane — the sharp focal subjects. In front of
## the tilt-shift DoF (z = -1) + biome (z = 0); behind stats/header (z = 2) and
## the run-end overlay (z = 5). Matches the enemy lineup's _WIRE_Z plane.
const _PARTY_DIORAMA_Z: int = 1

## Metadata key under which each hero slot stashes its class_id, so Story 006's
## idle-animation wiring drives the right sheet without re-reading the roster.
const _HERO_SLOT_CLASS_META: StringName = &"hero_class_id"


## Center-stage: the party's heroes — one sprite per OCCUPIED formation slot,
## rendered as a centered front-line row placed just below the enemy lineup, on a
## dedicated additive PartyDioramaLayer. Count is data-driven from
## HeroRoster.get_formation_heroes() (empty slots render nothing). Idempotent
## within a screen instance via [member _party_diorama_layer] (the parent
## [method _build_wireframe_once] is itself guarded by _wire_built).
func _build_party_diorama() -> void:
	if _party_diorama_layer != null:
		return
	var layer: Control = Control.new()
	layer.name = "PartyDioramaLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = _PARTY_DIORAMA_Z
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_party_diorama_layer = layer

	# Centered front-line row, placed just below the enemy lineup (which occupies
	# y≈188–384 at the same 0.5-anchored 560 px-wide band). Offsets per the UX
	# spec "Hero Combat Presence (GDD #35)" section; Story 014 polish may refine
	# the ground-line against live 1280×800.
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PartyFrontLine"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _HERO_SLOT_SEPARATION_PX)
	layer.add_child(row)
	_place(row, 0.5, 0, 0.5, 0, -280.0, 408.0, 280.0, 540.0)

	# One sprite per OCCUPIED formation slot — count is data-driven (never 3).
	if HeroRoster == null:
		return
	var party: Array = HeroRoster.get_formation_heroes()
	for h: Variant in party:
		if h == null:
			continue  # empty formation slot → renders nothing (UX spec)
		var cls: String = ""
		if "class_id" in h:
			cls = String(h.class_id)
		row.add_child(_make_hero_slot(cls, row.get_child_count()))


## Builds one hero sprite slot: a TextureRect playing the class's looping idle
## animation (the calm "breathing" idle). Square [const _HERO_SPRITE_DISPLAY_PX]
## box, aspect-preserved + nearest-neighbour for the cozy pixel-art register,
## read-only (MOUSE_FILTER_IGNORE). The class_id is stashed via set_meta so the
## animator wiring (and later reaction beats) need not re-read the roster.
##
## Story 006: [method ClassSpriteFactory.animate] attaches a [SpriteSheetAnimator]
## child (&"_IdleAnimator") that cycles the idle frames from its OWN _process —
## NEVER the 20 Hz tick hot path (ADR-0025 §C.9 — animation is _process-driven on
## a separate node, the tick handler gains nothing). animate() also sets the
## static frame 0, and is a no-op when the class art is absent (get_idle_frames
## returns [], the texture stays null) — the slot still reserves its layout box
## (the factory's null-fallback contract, mirrored from the enemy-lineup greybox
## path). The animator disables its own _process for ≤1-frame sheets, so an
## art-less class costs nothing per frame.
func _make_hero_slot(class_id: String, index: int) -> TextureRect:
	var slot: TextureRect = TextureRect.new()
	slot.name = "HeroSprite_%d" % index
	slot.custom_minimum_size = Vector2(_HERO_SPRITE_DISPLAY_PX, _HERO_SPRITE_DISPLAY_PX)
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta(_HERO_SLOT_CLASS_META, class_id)
	ClassSpriteFactoryScript.animate(slot, class_id)
	return slot


## Reflects a COARSE run-state change onto the party diorama by pausing or resuming
## every hero's looping idle (GDD #35 §C.4 "baseline transition", ADR-0025 §C.9).
## Called ONLY from human-frequency signal handlers (e.g. [method _on_state_changed]
## on RUN_ENDED) — NEVER from [method _on_tick_fired]; the 20 Hz hot path must stay
## free of any per-hero work. Walks the front-line slots and toggles each slot's
## [SpriteSheetAnimator] child via [method SpriteSheetAnimator.set_animating], which
## itself honours the static-card invariant (≤1-frame / art-less slots never animate).
## Fully defensive: a no-op before the diorama is built or when the party is empty.
func _set_party_idle_animating(enabled: bool) -> void:
	if _party_diorama_layer == null:
		return
	var row: Node = _party_diorama_layer.get_node_or_null("PartyFrontLine")
	if row == null:
		return
	for slot: Node in row.get_children():
		var animator: SpriteSheetAnimator = slot.get_node_or_null(
			NodePath(String(ClassSpriteFactoryScript.ANIMATOR_NODE_NAME))) as SpriteSheetAnimator
		if animator != null:
			animator.set_animating(enabled)


## Top-right: run stats backing panel + Return-to-Hall. The real StatsPanel
## (Tick/Kills) is repositioned to overlay this panel's body.
func _build_run_stats_hud() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Run")
	panel.name = "WireRunStats"
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 1, 0, 1, 0, -250.0, 14.0, -14.0, 120.0)

	var btn: Button = Button.new()
	btn.name = "WireReturnButton"
	btn.text = "Return to Hall"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(150, 44)
	btn.z_index = 2
	add_child(btn)
	_place(btn, 1, 0, 1, 0, -164.0, 132.0, -14.0, 176.0)
	btn.pressed.connect(_on_wire_return_pressed)


## Bottom-right: expedition progress (placeholder bar — no clean run % yet).
func _build_progress_panel() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Expedition progress")
	panel.name = "WireProgress"
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 1, 1, 1, 1, -300.0, -118.0, -14.0, -14.0)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 42.0
	body.add_child(bar)
	body.add_child(WireframeKitScript.caption(
		"tick-driven · wireframe placeholder", WireframeKitScript.MUTED, 10))


## Mid-left: live combat event feed (static flavour lines for the wireframe).
func _build_activity_feed_drv() -> void:
	var panel: PanelContainer = WireframeKitScript.section_panel("Event log")
	panel.name = "WireActivityFeed"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = _WIRE_Z
	add_child(panel)
	_place(panel, 0, 0, 0, 1, 14.0, 244.0, 324.0, -120.0)
	var body: VBoxContainer = WireframeKitScript.body_of(panel)
	for line: String in [
		"A blade finds a skeleton in the dark.",
		"A relic clatters out of the floor.",
		"The lantern flares. The party sees clearly.",
		"The party descends to depth 3.",
	]:
		var l: Label = WireframeKitScript.caption("· " + line, WireframeKitScript.MUTED, 12)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(l)


## Bottom-center: the channel-light lantern (idle-clicker target).
func _build_lantern_drv() -> void:
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.name = "WireLantern"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 8)
	wrap.z_index = 2
	add_child(wrap)
	_place(wrap, 0.5, 1, 0.5, 1, -150.0, -210.0, 150.0, -16.0)

	var cap_top: Label = WireframeKitScript.eyebrow(
		"Channel light · click the lantern", WireframeKitScript.ACCENT)
	cap_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(cap_top)

	var center_row: HBoxContainer = HBoxContainer.new()
	center_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(center_row)
	center_row.add_child(WireframeKitScript.lantern_button(_on_lantern_pressed_drv))

	var note: Label = WireframeKitScript.caption(
		"Wireframe — click feedback only; channel-light economy TBD",
		WireframeKitScript.MUTED, 10)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(note)


func _on_lantern_pressed_drv() -> void:
	if _float_layer == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var animate: bool = not (SceneManager != null and SceneManager.reduce_motion)
	WireframeKitScript.spawn_float(
		_float_layer, "+ light",
		Vector2(vp.x * 0.5 - 28.0 + randf_range(-26.0, 26.0), vp.y - 210.0),
		animate)


func _on_wire_return_pressed() -> void:
	SceneManager.request_screen("guild_hall", SceneManager.TransitionType.CROSS_FADE)
