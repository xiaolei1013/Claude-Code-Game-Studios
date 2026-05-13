extends Node

## SceneManager — rank-8 Foundation autoload.
##
## NOTE: No `class_name` — autoload scripts cannot declare `class_name`
## when the autoload name matches the class, or Godot raises
## "Class X hides an autoload singleton". The autoload is globally
## accessible as `SceneManager`; tests that need a fresh instance use
## `preload("res://src/core/scene_manager/scene_manager.gd").new()`.
##
## Owns the persistent root scene (MainRoot.tscn) and orchestrates all
## screen transitions and modal overlays for Lantern Guild.
##
## State machine: UNINITIALIZED → IDLE (on DataRegistry.registry_ready)
## → TRANSITIONING (when a screen-swap tween is active, Story 003/005)
## → PAUSED (when a modal overlay is open with pause_on_open=true, Story 007)
##
## ADR-0007: Persistent root scene architecture + screen routing
## ADR-0003: Autoload Rank Table (rank 8; zero-arg _init invariant)
## ADR-0003 Amendment #1: signal SUBSCRIPTION across any rank pair at _ready() is safe
## ADR-0003 Amendment #3 Claim 4 [VERIFIED]: autoload _init MUST have zero required params

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## Four-state machine for the SceneManager lifecycle.
##
## UNINITIALIZED: Engine booted; DataRegistry.registry_ready has NOT yet fired.
##   All request_screen calls are stored in _queued_request (last-write-wins).
##   No transitions or node-swaps occur until the state advances.
## IDLE: DataRegistry is READY; SceneManager is ready to accept screen requests.
##   request_screen calls are processed normally (Story 003 implements the body).
## TRANSITIONING: A screen-swap tween is in progress (Story 005).
##   Incoming request_screen calls queue at max depth 1 (ADR-0007 §Back-to-back).
## PAUSED: A modal overlay with pause_on_open=true is open (Story 007).
##   get_tree().paused is true; TickSystem is protected by PROCESS_MODE_ALWAYS.
##
## TR-scene-manager-012 — ADR-0007
enum State { UNINITIALIZED, IDLE, TRANSITIONING, PAUSED }

## Transition animations available for screen changes.
##
## CROSS_FADE: Simultaneous fade-out/in of outgoing/incoming screens (default).
## SLIDE_UP: Incoming screen slides in from the bottom.
## SLIDE_LEFT: Incoming screen slides in from the right.
## SLIDE_DOWN: Incoming screen slides in from the top.
## FADE_TO_BLACK: Fade to black then reveal the new screen.
## PUSH_MODAL: Modal stack push animation (lightweight, no full black).
## CEREMONY: Full AnimationPlayer ceremony (used for victory/unlock moments).
##
## ADR-0007 §Tween for 5 standard transitions + AnimationPlayer for CEREMONY
enum TransitionType { CROSS_FADE, SLIDE_UP, SLIDE_LEFT, SLIDE_DOWN, FADE_TO_BLACK, PUSH_MODAL, CEREMONY }

## Transition input policy for back-to-back requests while TRANSITIONING.
##
## BLOCK (0): Silent-drop policy — new requests while in TRANSITIONING are silently
##   discarded. This is the ONLY wired path in MVP.
## QUEUE_ONE (1): Queues at most one pending request (last-write-wins); fires after
##   the active transition completes. QUEUE_ONE is DECLARED but not recommended
##   for MVP — emits push_warning if selected.
##
## TR-scene-manager-029 — ADR-0007
enum InputPolicy { BLOCK, QUEUE_ONE }

# ---------------------------------------------------------------------------
# Screen PackedScene constants — preloaded at boot (<10MB total per TR-022)
# ---------------------------------------------------------------------------

## Preloaded PackedScene for each of the 7 MVP screens.
## These constants cause a parse-time error if any .tscn is missing — the hard fail
## mode per TR-scene-manager-022 (missing registry entries must assert-fail).
## ADR-0007 §screen_registry
const _SCREEN_MAIN_MENU: PackedScene = preload("res://assets/screens/main_menu/main_menu.tscn")
const _SCREEN_GUILD_HALL: PackedScene = preload("res://assets/screens/guild_hall/guild_hall.tscn")
const _SCREEN_RECRUITMENT: PackedScene = preload("res://assets/screens/recruitment/recruitment.tscn")
const _SCREEN_FORMATION_ASSIGNMENT: PackedScene = preload("res://assets/screens/formation_assignment/formation_assignment.tscn")
const _SCREEN_DUNGEON_RUN_VIEW: PackedScene = preload("res://assets/screens/dungeon_run_view/dungeon_run_view.tscn")
const _SCREEN_VICTORY_MOMENT: PackedScene = preload("res://assets/screens/victory_moment/victory_moment.tscn")
const _SCREEN_RETURN_TO_APP: PackedScene = preload("res://assets/screens/return_to_app/return_to_app.tscn")
const _SCREEN_MATCHUP_ASSIGNMENT: PackedScene = preload("res://assets/screens/matchup_assignment/matchup_assignment.tscn")
## Sprint 21+ Prestige V1.0 / Story 3 UI (Slice B) — Hall of Retired Heroes.
## Reachable from Guild Hall when `HeroRoster.get_prestige_count() > 0`.
## Per `design/gdd/prestige-system.md` §F + AC-PR-13.
const _SCREEN_HALL_OF_RETIRED_HEROES: PackedScene = preload("res://assets/screens/hall_of_retired_heroes/hall_of_retired_heroes.tscn")

## Path to the scene manager tuning-knob config resource.
## Loaded at _ready() time; consumed by Stories 005/009.
## TR-scene-manager-037
const _CONFIG_PATH: String = "res://assets/data/config/scene_manager_config.tres"

# ---------------------------------------------------------------------------
# Overlay PackedScene constants — preloaded at boot.
# These constants cause a parse-time error if any .tscn is missing — matching
# the hard-fail mode applied to screen registry entries (TR-scene-manager-022).
# ADR-0007 §push_overlay / §pop_overlay
# ---------------------------------------------------------------------------

## Preloaded PackedScene for the Settings overlay.
const _OVERLAY_SETTINGS: PackedScene = preload("res://assets/overlays/settings/settings.tscn")

## Preloaded PackedScene for the Confirm Save overlay.
const _OVERLAY_CONFIRM_SAVE: PackedScene = preload("res://assets/overlays/confirm_save/confirm_save.tscn")

## Preloaded PackedScene for the Hero Detail overlay.
const _OVERLAY_HERO_DETAIL: PackedScene = preload("res://assets/overlays/hero_detail/hero_detail.tscn")

# ---------------------------------------------------------------------------
# Transition timing constants (milliseconds → seconds for Tween API).
#
# These are the "full-motion" defaults (Story 009 wires reduce_motion clamp to 50ms).
# Config knobs from scene_manager_config.tres override these at runtime (Story 005).
# Story 009 (reduce_motion) is OUT OF SCOPE for this story — these constants are the
# live "unreduced" timing path.
#
# TR-scene-manager-023 / TR-scene-manager-024 — ADR-0007
# ---------------------------------------------------------------------------

## Cross-fade total: 75ms fade-out + 10ms overlap hold + 75ms fade-in = 150ms.
## TR-scene-manager-023 — linear alpha on TransitionLayer's full-screen ColorRect.
const _CROSSFADE_DEFAULT_MS: int = 150

## Half-duration for each alpha ramp leg of cross-fade (75ms each).
const _CROSSFADE_HALF_MS: float = 0.075

## Overlap hold duration at peak opacity (ms → seconds).
const _CROSSFADE_OVERLAP_S: float = 0.010

## Slide transitions: 180ms ease_out_quad. TR-scene-manager-024.
const _SLIDE_DEFAULT_MS: int = 180

## Fade-to-black: 300ms total = 150ms fade-out + 50ms hold + 100ms fade-in.
## TR-scene-manager-024.
const _FADE_TO_BLACK_DEFAULT_MS: int = 300

## Push-modal: 180ms ease_out_quad (slide-in from top of viewport).
const _PUSH_MODAL_DEFAULT_MS: int = 180

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted before entering `dungeon_run_view` AND after exiting `victory_moment`.
##
## SceneManager fires this before entering or after exiting specific screens so
## SaveLoadSystem can persist player state across scene boundaries.
## Only these two transitions trigger it — no other transitions fire this signal.
##
## [param reason] is a human-readable description of the trigger context
## (e.g., "pre_dungeon_entry", "post_victory_exit").
##
## Story 008 implements emission. ADR-0007 §scene_boundary_persist
signal scene_boundary_persist(reason: String)

## Emitted at the start of the tween callback during a screen swap (at peak opacity /
## mid-transition) so consumers can react before the incoming screen's on_enter fires.
## Audio System subscribes here to begin music crossfade with visual lead time.
##
## [param new_screen_id] is the identifier of the incoming screen.
## [param old_screen_id] is the identifier of the outgoing screen (empty string
## if there was no previous screen).
##
## TR-scene-manager-003 / TR-scene-manager-034 — ADR-0007
signal screen_changed(new_screen_id: String, old_screen_id: String)

## Emitted after the tween finishes and state returns to IDLE.
##
## [param screen_id] is the screen that is now active.
## [param transition_type] is the [enum TransitionType] value (as int) used.
##
## TR-scene-manager-003 — ADR-0007
signal transition_complete(screen_id: String, transition_type: int)

# ---------------------------------------------------------------------------
# Public state (read-only by convention; only SceneManager writes these)
# ---------------------------------------------------------------------------

## Current lifecycle state. Starts UNINITIALIZED; advances to IDLE when
## DataRegistry.registry_ready fires.
##
## Callers may read this value freely. Only SceneManager's internal methods
## write it — there is no public setter on this story's scope.
##
## TR-scene-manager-009 — ADR-0007
var state: State = State.UNINITIALIZED

## The Control node currently occupying ScreenContainer, or null if no screen
## is active. Populated by the swap callback on each successful screen swap.
var current_screen: Control = null

## The identifier string of the currently active screen, or "" if none.
## Matches the screen_id argument passed to the last successful request_screen.
var current_screen_id: String = ""

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Screen registry mapping string IDs to their preloaded PackedScenes.
## Populated at _ready() from the preloaded constants above.
## TR-scene-manager-022 — ADR-0007
var _screen_registry: Dictionary = {
	"main_menu": _SCREEN_MAIN_MENU,
	"guild_hall": _SCREEN_GUILD_HALL,
	"recruitment": _SCREEN_RECRUITMENT,
	"formation_assignment": _SCREEN_FORMATION_ASSIGNMENT,
	"dungeon_run_view": _SCREEN_DUNGEON_RUN_VIEW,
	"victory_moment": _SCREEN_VICTORY_MOMENT,
	"return_to_app": _SCREEN_RETURN_TO_APP,
	"matchup_assignment": _SCREEN_MATCHUP_ASSIGNMENT,
	"hall_of_retired_heroes": _SCREEN_HALL_OF_RETIRED_HEROES,
}

## Placeholder queue slot for requests arriving while in UNINITIALIZED state.
##
## Populated by request_screen when state == UNINITIALIZED (last-write-wins).
## Also used while TRANSITIONING for back-to-back queue at depth 1 (ADR-0007).
## Drained by _drain_queued_request_if_any() at end of _on_transition_finished.
##
## Structure when populated: {"screen_id": String, "transition": int}
## Structure when empty: {}
##
## AC H-06 — ADR-0007
var _queued_request: Dictionary = {}

## Loaded scene manager config resource (tuning knobs for transition timing etc.).
## Consumed by Stories 005/009; this story only loads and stores it.
## If the .tres is missing, push_warning but do not fail-stop.
## TR-scene-manager-037 — ADR-0007
var _config: Resource = null

## Active tween reference for the leak-guard pattern (ADR-0007 Risks Note 2).
## kill() any valid prior reference before each create_tween() call to prevent
## orphan tweens modulating freed nodes.
##
## Tweens are created on _get_transition_layer() (PROCESS_MODE_ALWAYS) so they
## are never frozen by a mid-transition pause race condition.
## ADR-0007
var _active_transition_tween: Tween = null

## The transition type currently in flight; emitted with transition_complete signal.
## Set at the top of _execute_transition; read in _on_transition_finished.
var _current_transition_type: int = TransitionType.CROSS_FADE

## For AC H-01 structural verification: total authored duration of the last
## cross-fade tween in milliseconds (sum of all tween segments authored at
## create-tween time). Exposed for test inspection via
## _get_last_crossfade_total_duration_ms(). Debug-only.
var _last_crossfade_authored_ms: int = 0

# ---------------------------------------------------------------------------
# Modal overlay state — Story 007
# ---------------------------------------------------------------------------

## Counter-based pause guard — prevents race-condition stuck-pause (ADR-0007 Risks row 7).
## Tree is paused IFF _modal_pause_count > 0. Direct writes to get_tree().paused are
## FORBIDDEN outside this module (control-manifest enforced).
var _modal_pause_count: int = 0

# Tracks the last value WE wrote to get_tree().paused. Used by _apply_pause_state
# to detect external tampering — if get_tree().paused differs from this on entry,
# something outside SceneManager touched it (ForbiddenPattern get_tree_paused_external_write).
# Initialized to false matching the engine default.
var _last_applied_pause_state: bool = false

## Map of overlay_id -> Control instance.
## Used to check duplicate pushes and resolve pop targets.
var _active_overlays: Dictionary = {}

## Map of overlay_id -> PackedScene (populated at _ready() from preload constants).
## Adding a new overlay requires a new preload constant AND an entry here.
## TR-scene-manager-007 — ADR-0007
var _overlay_registry: Dictionary = {}

## Queued modal push if a push_overlay arrives during TRANSITIONING.
## Drained by _drain_queued_modal_if_any() in _on_transition_finished.
## Structure when populated: {"overlay_id": String, "pause_on_open": bool}
## Structure when empty: {}
## ADR-0007 Risks row 4 — queued modals execute in IDLE regardless of save_failed outcome.
var _queued_modal: Dictionary = {}

# ---------------------------------------------------------------------------
# Freestanding modal state — Story 009 / ADR-0014
# ---------------------------------------------------------------------------

## Caller-owned modal instances currently shown via show_modal().
##
## Distinct from _active_overlays (registry-based push_overlay). The caller
## passes the Control instance directly; SceneManager hosts it in OverlayLayer
## but does NOT free or manage its data lifecycle.
##
## ADR-0014 §State container — OfflineProgressionEngine owns _progress_modal
var _active_freestanding_modals: Array[Control] = []

# ---------------------------------------------------------------------------
# Accessibility — reduce_motion — Story 009 / ADR-0007
# ---------------------------------------------------------------------------

## When true, all standard transition durations are clamped to REDUCE_MOTION_CLAMP_MS.
##
## Default is false. Persisted to user://settings.cfg via ConfigFile (interim path;
## migrates to Save/Load envelope when Settings GDD #30 lands — see OQ-7 comment in
## _load_interim_settings() and set_reduce_motion()).
##
## TR-scene-manager-027 — ADR-0007
var reduce_motion: bool = false

## Duration all standard transitions are clamped to when reduce_motion is true.
## CEREMONY instant-cut is handled separately (Story 006 scope, documented below).
## TR-scene-manager-027 — ADR-0007
const REDUCE_MOTION_CLAMP_MS: int = 50

## ConfigFile path for the reduce_motion interim persistence. Defaults to
## the production user-data path; tests override to an isolated path so a
## leaked file from a prior test run doesn't contaminate a fresh _ready().
##
## When Settings/Accessibility GDD #30 lands, this whole interim path
## migrates to the Save/Load envelope (OQ-7 in story-009).
var _settings_cfg_path: String = "user://settings.cfg"

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

## Zero-arg _init required by ADR-0003 Amendment #3:
## Godot autoload Nodes cannot receive constructor arguments.
## Claim 4 [VERIFIED] — autoload.md (2026-04-22).
func _init() -> void:
	pass


## Loads config, then subscribes to DataRegistry.registry_ready.
##
## Config load is done first (BEFORE DataRegistry connect) so the resource is
## available for any signal handler that fires immediately in the late-subscription
## fallback path.
##
## Signal subscription across any rank pair at _ready() is safe per
## ADR-0003 Amendment #1 (autoload.md Claim 1 [VERIFIED]).
## SceneManager is rank 8; DataRegistry is rank 1 — state read of
## DataRegistry.state at this point is safe (M=1 < N=8).
##
## Defensive late-subscription fallback: if DataRegistry reached READY
## before SceneManager._ready() ran (e.g. if rank order ever regresses or
## during testing where order is non-canonical), check the state directly
## and call the handler. In the normal forward-rank boot path this check
## is a no-op (DataRegistry is READY by the time SceneManager._ready() fires
## because rank 1 < rank 8; the signal has already been emitted and we would
## have missed it — hence the explicit check is load-bearing for correctness).
##
## TR-scene-manager-009 — ADR-0003 Amendment #1
func _ready() -> void:
	# Load config first — available before any signal fires (TR-scene-manager-037).
	_config = load(_CONFIG_PATH)
	if _config == null:
		push_warning(
			"[SceneManager] scene_manager_config.tres not found at '%s'. Transition tuning knobs unavailable until Stories 005/009 create it." % _CONFIG_PATH
		)

	# Load accessibility settings (reduce_motion) before DataRegistry ready so the
	# flag is available for the very first transition. Synchronous; never crashes.
	# TR-scene-manager-027 — ADR-0007
	_load_interim_settings()

	# Populate overlay registry from preload constants.
	# Adding a new overlay requires a new preload constant AND an entry here.
	# TR-scene-manager-007 — ADR-0007
	_overlay_registry = {
		"settings": _OVERLAY_SETTINGS,
		"confirm_save": _OVERLAY_CONFIRM_SAVE,
		"hero_detail": _OVERLAY_HERO_DETAIL,
	}

	DataRegistry.registry_ready.connect(_on_registry_ready)
	if DataRegistry.state == DataRegistry.State.READY:
		# Late-subscription fallback: signal already fired (or DataRegistry rank
		# regressed below SceneManager rank in a future edit). Transition now.
		_on_registry_ready()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Requests a screen change to the given screen identifier.
##
## This is the SOLE external API for screen changes (ADR-0007 / TR-scene-manager-010).
## Never call SceneTree.change_scene_to_packed() / change_scene_to_file() — forbidden.
##
## State handling:
## - UNINITIALIZED: stores request in _queued_request (last-write-wins); deferred until
##   DataRegistry.registry_ready fires and state becomes IDLE.
## - TRANSITIONING: queues request at depth 1 (last-write-wins); fires push_warning
##   on overwrite; processed after current transition completes.
## - IDLE, same screen: push_warning only; no transition; returns immediately.
## - IDLE, different screen: executes transition via _execute_transition.
##
## [param screen_id] is the content-addressable identifier of the target screen
## (e.g., "guild_hall", "dungeon_run_view"). Must match a registered screen resource.
## [param transition] is a [enum TransitionType] value (default: CROSS_FADE).
##
## Example:
##   SceneManager.request_screen("guild_hall")
##   SceneManager.request_screen("dungeon_run_view", SceneManager.TransitionType.FADE_TO_BLACK)
##
## TR-scene-manager-001, TR-scene-manager-010 — ADR-0007
func request_screen(screen_id: String, transition: int = TransitionType.CROSS_FADE) -> void:
	if state == State.UNINITIALIZED:
		# Store request for deferred processing on IDLE transition.
		# Last-write-wins: a rapid second call before IDLE overwrites the first.
		# Drained by _on_registry_ready when registry_ready fires.
		_queued_request = {"screen_id": screen_id, "transition": transition}
		return
	if state == State.TRANSITIONING:
		# Back-to-back transition queuing: max depth 1 (ADR-0007 §Back-to-back).
		# Full max-1 semantics and edge-case verification locked in Story 010.
		if not _queued_request.is_empty():
			push_warning("[SceneManager] Overwriting queued request '%s' with '%s'" %
				[_queued_request.get("screen_id", ""), screen_id])
		_queued_request = {"screen_id": screen_id, "transition": transition}
		return
	if screen_id == current_screen_id:
		# AC H-03: Same-screen request is a silent no-op — push_warning only.
		push_warning("[SceneManager] Same-screen request '%s' — no-op" % screen_id)
		return
	_execute_transition(screen_id, transition)


## Pushes a modal overlay onto OverlayLayer.
##
## When [param pause_on_open] is true, increments [member _modal_pause_count] and sets
## [code]get_tree().paused = true[/code]. Counter-based per ADR-0007 Risks row 7 to prevent
## stuck-pause when overlapping overlays open and close.
##
## During TRANSITIONING, the request is queued in [member _queued_modal] and drained
## by [method _on_transition_finished]. During UNINITIALIZED, logs [code]push_warning[/code]
## and ignores the call.
##
## Sets metadata [code]"scene_manager_pause_on_open"[/code] on the overlay instance so
## [method pop_overlay] can reverse the exact pause action (regardless of arg passed at pop).
##
## [param overlay_id] is the registered overlay identifier.
## [param pause_on_open] if true, increments pause counter and sets get_tree().paused.
##
## Example:
##   SceneManager.push_overlay("settings")
##   SceneManager.push_overlay("hero_detail", false)
##
## TR-scene-manager-007 — ADR-0007
func push_overlay(overlay_id: String, pause_on_open: bool = true) -> void:
	if state == State.UNINITIALIZED:
		push_warning("[SceneManager] push_overlay before registry_ready — ignored")
		return
	if state == State.TRANSITIONING:
		_queued_modal = {"overlay_id": overlay_id, "pause_on_open": pause_on_open}
		return
	# Duplicate-push guard — release-safe (push_error + early return rather than
	# debug-only assert). A debug-only assert would silently orphan the previous
	# overlay instance + double-increment the counter in release builds.
	if _active_overlays.has(overlay_id):
		push_error("[SceneManager] Overlay '%s' already active — duplicate push ignored" % overlay_id)
		return
	var packed: PackedScene = _overlay_registry.get(overlay_id)
	if packed == null:
		push_error("[SceneManager] Unknown overlay_id '%s' — must be registered in _overlay_registry" % overlay_id)
		return
	var overlay: Control = packed.instantiate() as Control
	if overlay == null:
		push_error("[SceneManager] Failed to instantiate overlay '%s'" % overlay_id)
		return
	# Store pause_on_open on the overlay so pop_overlay can reverse the exact action
	# without relying on the caller passing the same argument at pop time.
	overlay.set_meta("scene_manager_pause_on_open", pause_on_open)
	var overlay_layer: CanvasLayer = _get_overlay_layer()
	if overlay_layer == null:
		push_error("[SceneManager] OverlayLayer not found; aborting push_overlay")
		overlay.free()
		return
	overlay_layer.add_child(overlay)
	# Capture pre-push state to decide whether on_pause should fire:
	# Per story line 151 contract — on_pause fires only on the OUTERMOST push
	# (transitioning IDLE → PAUSED). Subsequent nested pushes do not re-fire on_pause.
	var was_idle_before_push: bool = (state == State.IDLE)
	_active_overlays[overlay_id] = overlay
	# Per Story 004: Screen base class enforces on_pause; direct call safe (CI grep enforced).
	if was_idle_before_push and current_screen != null:
		current_screen.on_pause()
	state = State.PAUSED
	if pause_on_open:
		_modal_pause_count += 1
		_apply_pause_state()


## Pops a modal overlay from OverlayLayer.
##
## Reads the [code]"scene_manager_pause_on_open"[/code] metadata to reverse exactly the
## pause action that [method push_overlay] set. Avoids the developer passing a different
## [param pause_on_open] at pop time silently corrupting the counter.
##
## When the LAST overlay closes (state returns to IDLE), calls [code]on_resume()[/code]
## on the current screen. If other overlays remain, state stays PAUSED.
##
## A stray pop (overlay_id not in [member _active_overlays]) logs [code]push_warning[/code]
## and no-ops. Counter is clamped to 0 via [code]maxi()[/code] to enforce the
## never-negative invariant (ADR-0007 Risks row 7).
##
## [param overlay_id] is the identifier of the overlay to close.
##
## Example:
##   SceneManager.pop_overlay("settings")
##
## TR-scene-manager-007 — ADR-0007
func pop_overlay(overlay_id: String) -> void:
	if not _active_overlays.has(overlay_id):
		push_warning("[SceneManager] pop_overlay '%s' — not active; no-op" % overlay_id)
		return
	var overlay: Control = _active_overlays[overlay_id]
	_active_overlays.erase(overlay_id)
	var was_pausing: bool = overlay.get_meta("scene_manager_pause_on_open", true)
	overlay.queue_free()
	if was_pausing:
		_modal_pause_count = maxi(0, _modal_pause_count - 1)
		_apply_pause_state()
	if _active_overlays.is_empty():
		state = State.IDLE
		# Per Story 004: Screen base class enforces on_resume; direct call safe (CI grep enforced).
		if current_screen != null:
			current_screen.on_resume()
	# If overlays remain, state stays PAUSED; on_resume defers until last pop.


## Shows a caller-owned modal Control on OverlayLayer.
##
## Distinct from push_overlay: the caller instantiates and owns the modal
## (per ADR-0014 §State container). SceneManager hosts it in OverlayLayer and
## tracks it in _active_freestanding_modals but does NOT own its data lifecycle.
##
## Does NOT increment _modal_pause_count and does NOT call get_tree().paused = true.
## The offline replay tick loop must remain running (ADR-0014: replay path bypasses
## tick_fired but the modal's UI animations must render).
##
## Lifecycle (S14-M6 hardening, after PR #58 regression class):
## If the modal exposes on_enter(), SceneManager calls it AFTER add_child + tracking
## + current_screen.on_pause() + state transition to PAUSED. This matches the
## request_screen contract (screen_changed → on_enter) so callers of show_modal
## get the same lifecycle guarantees as request_screen callers. Modals that do
## not implement on_enter (e.g., plain Control instances) are unaffected.
##
## Example:
##   SceneManager.show_modal(_progress_modal)  # OfflineProgressionEngine call site
##   # SceneManager calls _progress_modal.on_enter() automatically — caller must
##   # NOT call it again or signal handlers will double-connect.
##
## ADR-0014 §Time-gated UX — TR-scene-manager-009
func show_modal(modal: Control) -> void:
	assert(modal != null, "[SceneManager] show_modal received null modal")
	var overlay_layer: CanvasLayer = _get_overlay_layer()
	if overlay_layer == null:
		push_error("[SceneManager] show_modal: OverlayLayer not found; aborting")
		return
	overlay_layer.add_child(modal)
	_active_freestanding_modals.append(modal)
	# Notify current screen it is pausing (visual indication; not a tree pause).
	if current_screen != null:
		current_screen.on_pause()
	state = State.PAUSED
	# Do NOT increment _modal_pause_count — offline replay does not pause the tree.
	# (replay path bypasses tick_fired per ADR-0005; UI animations on the modal
	# must continue rendering while replay batches process.)
	# S14-M6: call the modal's on_enter AFTER add_child + tracking + state transition
	# so the modal can rely on being in the tree + SceneManager.state == PAUSED.
	# Type-guarded via `is Screen` (not has_method — tween_transitions F-01 forbids
	# has_method in this file). Plain Control modals are unaffected.
	if modal is Screen:
		(modal as Screen).on_enter()


## Hides and frees a caller-owned modal that was previously shown via show_modal.
##
## No-ops with push_warning if the modal was never tracked (prevents double-free).
## Transitions state back to IDLE and calls on_resume() only when BOTH
## _active_freestanding_modals AND _active_overlays are empty — i.e., if
## push_overlay has stacked overlays on top, state stays PAUSED.
##
## Lifecycle (S14-M6 hardening): if the modal exposes on_exit(), SceneManager
## calls it BEFORE queue_free so the modal can disconnect signal handlers and
## kill in-flight tweens before its node is freed. Symmetric with show_modal's
## auto on_enter call. Duck-typed via has_method.
##
## Example:
##   SceneManager.hide_modal(_progress_modal)  # called on offline_rewards_collected
##
## ADR-0014 §Time-gated UX — TR-scene-manager-009
func hide_modal(modal: Control) -> void:
	if not _active_freestanding_modals.has(modal):
		push_warning("[SceneManager] hide_modal: modal not tracked; no-op")
		return
	# S14-M6: call the modal's on_exit BEFORE queue_free so it can disconnect
	# signal handlers + kill tweens while the node is still valid. Type-guarded
	# via `is Screen` (tween_transitions F-01 forbids has_method here).
	if modal is Screen:
		(modal as Screen).on_exit()
	_active_freestanding_modals.erase(modal)
	modal.queue_free()
	if _active_freestanding_modals.is_empty() and _active_overlays.is_empty():
		state = State.IDLE
		if current_screen != null:
			current_screen.on_resume()
	# If push_overlay overlays remain, state stays PAUSED; on_resume defers until last close.


## Sets the reduce_motion accessibility flag and persists it to user://settings.cfg.
##
## Idempotent on no-change. If the ConfigFile save fails, push_warning with error code
## but the in-memory value is still updated (runtime takes effect immediately).
##
## OQ-7 migration note: when Settings/Accessibility GDD #30 lands, migrate
## reduce_motion read/write from user://settings.cfg to the Save/Load envelope under
## a "settings" namespace. On first boot after migration: read both paths; write only
## to envelope; delete ConfigFile entry after first successful envelope save with the
## field present.
##
## Example:
##   SceneManager.set_reduce_motion(true)   # called from Settings overlay (GDD #30)
##
## TR-scene-manager-027 — ADR-0007
func set_reduce_motion(value: bool) -> void:
	if reduce_motion == value:
		return
	reduce_motion = value
	var cfg := ConfigFile.new()
	# Load existing file to preserve unrelated keys; ignore error (file may not exist yet).
	cfg.load(_settings_cfg_path)
	cfg.set_value("accessibility", "reduce_motion", value)
	var save_err: Error = cfg.save(_settings_cfg_path)
	if save_err != OK:
		push_warning("[SceneManager] Failed to persist reduce_motion to user://settings.cfg (err=%d)" % save_err)


## Returns the total authored duration of the last cross-fade tween in milliseconds.
##
## This is a structural AC H-01 probe: it reflects the authored segment durations
## (75ms + 10ms + 75ms = 150ms), not wall-clock elapsed time. Use this in unit and
## integration tests to assert the tween was AUTHORED at 150ms even if headless
## runner virtual timing compresses actual execution.
##
## Debug-build only — returns -1 in Release builds.
## TR-scene-manager-032 — ADR-0007
func _get_last_crossfade_total_duration_ms() -> int:
	if not OS.is_debug_build():
		return -1
	return _last_crossfade_authored_ms

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

## Loads accessibility settings from user://settings.cfg at boot time.
##
## Reads the [accessibility] section reduce_motion key. Defaults to false on missing
## or malformed file — emits push_warning on load errors other than missing file so
## that malformed files are surfaced without crashing boot.
##
## Called once from _ready() BEFORE DataRegistry.registry_ready connects so the flag
## is available for the very first transition.
##
## OQ-7 migration note: when Settings/Accessibility GDD #30 lands, migrate this read
## to the Save/Load envelope. Until then, user://settings.cfg is the mandated interim
## path (ADR-0007 §OQ-7 — never write to the Save/Load envelope in MVP).
##
## TR-scene-manager-027 — ADR-0007
func _load_interim_settings() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(_settings_cfg_path)
	if err == OK:
		reduce_motion = bool(cfg.get_value("accessibility", "reduce_motion", false))
	elif err != ERR_FILE_NOT_FOUND:
		# Malformed file — warn but do not crash. Defaults (reduce_motion = false) stand.
		push_warning("[SceneManager] _load_interim_settings: could not parse user://settings.cfg (err=%d); defaults applied" % err)
	# ERR_FILE_NOT_FOUND is the expected first-launch path — silent, no warning.


## Executes a screen transition by dispatching to the appropriate tween-based
## transition handler.
##
## This is the tween-driven replacement for the former call_deferred path.
## All five standard transitions use create_tween() on TransitionLayer.
## CEREMONY falls back to CROSS_FADE (Story 006 owns CEREMONY via AnimationPlayer).
##
## Lifecycle order (AC H-02, TR-scene-manager-033):
##   old_screen.on_exit() → tween start → swap callback (screen_changed emitted,
##   new_screen added, on_enter called) → tween end → _on_transition_finished
##   (state=IDLE, transition_complete emitted, drain queued request)
##
## Per Story 004: all screens extend Screen base class with the four hooks declared
## (CI-enforced via tools/ci/check_screen_hooks.sh). Direct method calls are safe.
## Duck-typing guards (has_method) removed — Story 004 enforces the contract.
##
## TR-scene-manager-003, TR-scene-manager-004 — ADR-0007
func _execute_transition(screen_id: String, transition: int) -> void:
	assert(state == State.IDLE, "_execute_transition requires IDLE state")
	assert(_screen_registry.has(screen_id),
		"[SceneManager] Unknown screen_id '%s' — not in _screen_registry" % screen_id)

	state = State.TRANSITIONING
	_current_transition_type = transition

	# Snapshot outgoing before any modification.
	var old_screen: Control = current_screen
	var old_id: String = current_screen_id

	# Story 008 (S11-M1): scene_boundary_persist emission. The signal fires only
	# on the two specific transitions called out in the signal's contract
	# (declaration above): "before entering dungeon_run_view AND after exiting
	# victory_moment". Other transitions DO NOT fire it.
	#
	# Persist timing — synchronous (Sprint 11 reality, S11-M3b clarification
	# 2026-05-05). Trace the chain: `scene_boundary_persist.emit(reason)` blocks
	# (Godot signal emission is synchronous) → `SaveLoadSystem._on_scene_boundary_persist`
	# runs → `request_full_persist` runs → file I/O (FileAccess.open / store_buffer
	# / DirAccess.rename_absolute) is synchronous → `save_completed` (or
	# `save_failed`) emits → control returns up the chain to this site. By the
	# time `emit()` returns here, the save is already on disk and the result
	# signal has already fired. **No SceneManager-side `await` is needed for
	# correctness** with the current synchronous-I/O architecture.
	#
	# The Save/Load GDD Rule 5 row 5 "async-signal pattern" is a Sprint 12+
	# guidance for the case where file I/O moves off the main thread (to avoid
	# blocking the ~50 ms write duration). When that optimization lands, this
	# emit point gets `await SaveLoadSystem.save_completed` (or the multi-
	# signal race helper). For MVP synchronous I/O, the existing synchronous
	# emit is the right shape.
	if screen_id == "dungeon_run_view":
		scene_boundary_persist.emit("pre_dungeon_entry")

	# AC H-02: on_exit fires BEFORE tween start — synchronous, never deferred.
	# Per Story 004: direct call is safe (all screens extend Screen base class).
	if old_screen != null:
		old_screen.on_exit()
		old_screen.queue_free()

	# Story 008 emission for "post_victory_exit" — fires AFTER victory_moment's
	# on_exit hook so SaveLoadSystem can persist the just-finalized victory state.
	if old_id == "victory_moment":
		scene_boundary_persist.emit("post_victory_exit")

	# Instantiate incoming screen.
	var packed: PackedScene = _screen_registry.get(screen_id) as PackedScene
	assert(packed != null,
		"[SceneManager] _screen_registry.get('%s') returned null" % screen_id)
	var new_screen: Control = packed.instantiate() as Control
	assert(new_screen != null,
		"[SceneManager] packed.instantiate() returned null for '%s'" % screen_id)

	# Dispatch to the correct transition handler by type.
	match transition:
		TransitionType.CROSS_FADE:
			_transition_cross_fade(old_screen, old_id, new_screen, screen_id)
		TransitionType.SLIDE_UP, TransitionType.SLIDE_DOWN, TransitionType.SLIDE_LEFT:
			_transition_slide(old_screen, old_id, new_screen, screen_id, transition)
		TransitionType.FADE_TO_BLACK:
			_transition_fade_to_black(old_screen, old_id, new_screen, screen_id)
		TransitionType.PUSH_MODAL:
			_transition_push_modal(old_screen, old_id, new_screen, screen_id)
		TransitionType.CEREMONY:
			# Story 006 owns CEREMONY via AnimationPlayer — out of scope for this story.
			# When Story 006's real CEREMONY dispatcher ships, it must branch here:
			#   if reduce_motion:
			#       _instant_ceremony_cut(new_screen_callable)
			#       return
			# Until then there is nothing to cut to, so the fallback to CROSS_FADE is
			# correct. The reduce_motion instant-cut branch is DECLARED in Story 009
			# (ADR-0007 §CEREMONY reduce_motion) but not wired until Story 006 ships.
			# TR-scene-manager-036 — ADR-0007
			push_warning("[SceneManager] CEREMONY transition not yet implemented (Story 006); falling back to CROSS_FADE")
			_transition_cross_fade(old_screen, old_id, new_screen, screen_id)
		_:
			push_error("[SceneManager] Unknown transition type: %d; falling back to CROSS_FADE" % transition)
			_transition_cross_fade(old_screen, old_id, new_screen, screen_id)


## Cross-fade transition: 150ms total = 75ms alpha 0→1 + 10ms hold + 75ms alpha 1→0.
##
## Swap occurs at peak opacity (75ms mark) so there is no visible cut.
## Uses the TransitionLayer's ColorRect (modulate.a) for the fade.
## Linear easing per TR-scene-manager-023.
##
## Authored duration: 75 + 10 + 75 = 150ms — structural AC H-01 probe stores this.
##
## [param old_screen] outgoing screen (already had on_exit called; queue_free'd above).
## [param old_id] identifier of the outgoing screen.
## [param new_screen] incoming screen (instantiated but not yet added to tree).
## [param screen_id] identifier of the incoming screen.
##
## TR-scene-manager-020, TR-scene-manager-023, TR-scene-manager-032 — ADR-0007
func _transition_cross_fade(
		_old_screen: Control,
		old_id: String,
		new_screen: Control,
		screen_id: String) -> void:
	var rect: ColorRect = _get_transition_color_rect()
	if rect == null:
		push_error("[SceneManager] CROSS_FADE: TransitionLayer/Fade not found; aborting")
		_abort_transition_to_new_screen(new_screen, screen_id, old_id)
		return

	# Honor per-screen override (TR-028); fallback to config / 150ms default.
	# Split per cross-fade contract: half_s + overlap_s + half_s = total_s.
	# _CROSSFADE_OVERLAP_S = 0.010 (10ms hold at peak opacity).
	var total_ms: int = _get_crossfade_duration_ms(new_screen)
	var overlap_s: float = _CROSSFADE_OVERLAP_S
	var half_s: float = (float(total_ms) / 1000.0 - overlap_s) / 2.0
	# Record authored total for AC H-01 structural test (TR-023: default 150ms).
	_last_crossfade_authored_ms = total_ms

	# Ensure ColorRect starts fully transparent.
	rect.modulate.a = 0.0

	# Leak guard: kill prior valid tween before creating a new one (ADR-0007 Risks Note 2).
	if _active_transition_tween != null and _active_transition_tween.is_valid():
		_active_transition_tween.kill()

	# Create tween on PROCESS_MODE_ALWAYS node so it is never frozen by a pause race.
	var transition_layer: CanvasLayer = _get_transition_layer()
	assert(transition_layer != null, "[SceneManager] TransitionLayer required for tween")
	_active_transition_tween = transition_layer.create_tween()

	# Capture timing start for evidence logging (debug-build only).
	var start_ms: int = Time.get_ticks_msec()

	# Phase 1: fade up 0→1 over half_s (linear).
	_active_transition_tween.tween_property(rect, "modulate:a", 1.0, half_s)
	_active_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_active_transition_tween.set_trans(Tween.TRANS_LINEAR)

	# Swap callback fires at peak opacity (fully opaque ColorRect hides the cut).
	# AC H-02 contract: screen_changed emitted before on_enter.
	_active_transition_tween.tween_callback(func() -> void:
		var sc: Node = _get_screen_container()
		if sc == null:
			push_error("[SceneManager] _transition_cross_fade swap: ScreenContainer not found")
			return
		sc.add_child(new_screen)
		current_screen = new_screen
		current_screen_id = screen_id
		# screen_changed BEFORE on_enter (TR-scene-manager-034; Audio System crossfade lead).
		screen_changed.emit(screen_id, old_id)
		# Per Story 004: direct call safe (all screens extend Screen base class).
		new_screen.on_enter()
	)

	# Hold at peak opacity for the overlap window.
	_active_transition_tween.tween_interval(overlap_s)

	# Phase 2: fade down 1→0 over half_s (linear).
	_active_transition_tween.tween_property(rect, "modulate:a", 0.0, half_s)

	# When fully settled, finalize state and emit transition_complete.
	_active_transition_tween.finished.connect(
		func() -> void:
			_log_crossfade_timing(start_ms, Time.get_ticks_msec())
			_on_transition_finished(),
		CONNECT_ONE_SHOT
	)


## Slide transition: 180ms ease_out_quad.
##
## The incoming screen is positioned off-screen then slides into place.
## Swap happens at tween start (incoming replaces outgoing immediately, then slides in).
##
## SLIDE_UP:   new screen starts below viewport (positive Y offset), slides up.
## SLIDE_DOWN: new screen starts above viewport (negative Y offset), slides down.
## SLIDE_LEFT: new screen starts right of viewport (positive X offset), slides left.
##
## [param transition] is the specific slide variant (SLIDE_UP / SLIDE_DOWN / SLIDE_LEFT).
##
## TR-scene-manager-020, TR-scene-manager-024 — ADR-0007
func _transition_slide(
		_old_screen: Control,
		old_id: String,
		new_screen: Control,
		screen_id: String,
		transition: int) -> void:
	var sc: Node = _get_screen_container()
	if sc == null:
		push_error("[SceneManager] SLIDE: ScreenContainer not found; aborting")
		_abort_transition_to_new_screen(new_screen, screen_id, old_id)
		return

	# Get viewport size to calculate start offset.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# Determine starting position offset based on slide direction.
	var start_offset: Vector2 = Vector2.ZERO
	match transition:
		TransitionType.SLIDE_UP:
			start_offset = Vector2(0.0, viewport_size.y)
		TransitionType.SLIDE_DOWN:
			start_offset = Vector2(0.0, -viewport_size.y)
		TransitionType.SLIDE_LEFT:
			start_offset = Vector2(viewport_size.x, 0.0)

	# Add screen to ScreenContainer BEFORE tween (swap-first approach).
	# Screen is positioned off-screen; tween brings it into view.
	sc.add_child(new_screen)
	new_screen.position = start_offset
	current_screen = new_screen
	current_screen_id = screen_id

	# screen_changed BEFORE on_enter (TR-scene-manager-034).
	screen_changed.emit(screen_id, old_id)
	# Per Story 004: direct call safe (all screens extend Screen base class).
	new_screen.on_enter()

	# Leak guard: kill prior valid tween before creating a new one.
	if _active_transition_tween != null and _active_transition_tween.is_valid():
		_active_transition_tween.kill()

	# Create tween on PROCESS_MODE_ALWAYS node (not frozen by pause race).
	var transition_layer: CanvasLayer = _get_transition_layer()
	assert(transition_layer != null, "[SceneManager] TransitionLayer required for slide tween")
	_active_transition_tween = transition_layer.create_tween()

	var slide_duration_s: float = _get_slide_duration_ms(new_screen) / 1000.0

	# Slide from off-screen to origin (Vector2.ZERO).
	_active_transition_tween.tween_property(
		new_screen, "position", Vector2.ZERO, slide_duration_s
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_active_transition_tween.finished.connect(_on_transition_finished, CONNECT_ONE_SHOT)


## Fade-to-black transition: 300ms total = 150ms fade-out + 50ms hold + 100ms fade-in.
##
## Screen swap occurs while fully opaque (at peak black).
## Linear easing per TR-scene-manager-024.
##
## [param old_screen] outgoing screen (already on_exit called; queue_free'd).
## [param old_id] identifier of the outgoing screen.
## [param new_screen] incoming screen (instantiated but not yet in tree).
## [param screen_id] identifier of the incoming screen.
##
## TR-scene-manager-020, TR-scene-manager-024 — ADR-0007
func _transition_fade_to_black(
		_old_screen: Control,
		old_id: String,
		new_screen: Control,
		screen_id: String) -> void:
	var rect: ColorRect = _get_transition_color_rect()
	if rect == null:
		push_error("[SceneManager] FADE_TO_BLACK: TransitionLayer/Fade not found; aborting")
		_abort_transition_to_new_screen(new_screen, screen_id, old_id)
		return

	rect.modulate.a = 0.0

	# Leak guard.
	if _active_transition_tween != null and _active_transition_tween.is_valid():
		_active_transition_tween.kill()

	var transition_layer: CanvasLayer = _get_transition_layer()
	assert(transition_layer != null, "[SceneManager] TransitionLayer required for tween")
	_active_transition_tween = transition_layer.create_tween()

	var fade_out_s: float = 0.150   # 150ms
	var hold_s: float = 0.050       # 50ms hold (swap occurs here)
	var fade_in_s: float = 0.100    # 100ms

	# Phase 1: fade to black (0→1 over 150ms, linear).
	_active_transition_tween.tween_property(rect, "modulate:a", 1.0, fade_out_s)
	_active_transition_tween.set_trans(Tween.TRANS_LINEAR)

	# Hold (swap during hold — fully opaque, no visible cut).
	_active_transition_tween.tween_callback(func() -> void:
		var sc: Node = _get_screen_container()
		if sc == null:
			push_error("[SceneManager] FADE_TO_BLACK swap: ScreenContainer not found")
			return
		sc.add_child(new_screen)
		current_screen = new_screen
		current_screen_id = screen_id
		# screen_changed BEFORE on_enter (TR-scene-manager-034).
		screen_changed.emit(screen_id, old_id)
		# Per Story 004: direct call safe.
		new_screen.on_enter()
	)
	_active_transition_tween.tween_interval(hold_s)

	# Phase 2: fade from black (1→0 over 100ms, linear).
	_active_transition_tween.tween_property(rect, "modulate:a", 0.0, fade_in_s)

	_active_transition_tween.finished.connect(_on_transition_finished, CONNECT_ONE_SHOT)


## Push-modal transition: 180ms ease_out_quad, slides new screen in from top.
##
## Used as the timing reference for Story 007's modal overlay push/pop bodies.
## For this story, the full overlay API (push_overlay/pop_overlay) is NOT
## implemented (Story 007 scope) — this helper provides the tween shape only.
##
## [param transition] = PUSH_MODAL (always for this helper).
##
## TR-scene-manager-020, TR-scene-manager-024 — ADR-0007
func _transition_push_modal(
		_old_screen: Control,
		old_id: String,
		new_screen: Control,
		screen_id: String) -> void:
	var sc: Node = _get_screen_container()
	if sc == null:
		push_error("[SceneManager] PUSH_MODAL: ScreenContainer not found; aborting")
		_abort_transition_to_new_screen(new_screen, screen_id, old_id)
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# Slide in from top of viewport.
	sc.add_child(new_screen)
	new_screen.position = Vector2(0.0, -viewport_size.y)
	current_screen = new_screen
	current_screen_id = screen_id

	screen_changed.emit(screen_id, old_id)
	new_screen.on_enter()

	# Leak guard.
	if _active_transition_tween != null and _active_transition_tween.is_valid():
		_active_transition_tween.kill()

	var transition_layer: CanvasLayer = _get_transition_layer()
	assert(transition_layer != null, "[SceneManager] TransitionLayer required for modal tween")
	_active_transition_tween = transition_layer.create_tween()

	var push_duration_s: float = _get_push_modal_duration_ms(new_screen) / 1000.0

	_active_transition_tween.tween_property(
		new_screen, "position", Vector2.ZERO, push_duration_s
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_active_transition_tween.finished.connect(_on_transition_finished, CONNECT_ONE_SHOT)


## Handles tween.finished: resets state to IDLE, emits transition_complete, drains queues.
##
## Called via CONNECT_ONE_SHOT on _active_transition_tween.finished for every transition.
## Drain order: screen request first, then modal push — per ADR-0007 Risks row 4
## ("Queued modals execute in IDLE regardless of save_failed outcome").
##
## ADR-0007 §Tween-driven swap flow
func _on_transition_finished() -> void:
	state = State.IDLE
	transition_complete.emit(current_screen_id, _current_transition_type)
	_drain_queued_request_if_any()
	_drain_queued_modal_if_any()


## Aborts a transition when a critical scene-tree node is missing.
##
## Performs a graceful fallback: adds the new screen instantly (no tween), updates
## state to IDLE, and emits the required signals. This avoids getting stuck in
## TRANSITIONING state when TransitionLayer or ScreenContainer is missing.
##
## Should only occur in unit-test environments where MainRoot nodes are partial.
func _abort_transition_to_new_screen(
		new_screen: Control,
		screen_id: String,
		old_id: String) -> void:
	var sc: Node = _get_screen_container()
	if sc != null:
		sc.add_child(new_screen)
	current_screen = new_screen
	current_screen_id = screen_id
	screen_changed.emit(screen_id, old_id)
	new_screen.on_enter()
	state = State.IDLE
	transition_complete.emit(screen_id, _current_transition_type)
	_drain_queued_request_if_any()


## Drains the _queued_request slot if populated, re-invoking _execute_transition.
##
## Called at end of _on_transition_finished so back-to-back requests queued during a
## TRANSITIONING state are processed immediately after the previous swap completes.
## Also available for push_overlay abort paths (Story 007).
## Intentionally simple — full max-1 semantics locked in Story 010.
##
## ADR-0007 §Back-to-back transitions
func _drain_queued_request_if_any() -> void:
	if _queued_request.is_empty():
		return
	var pending: Dictionary = _queued_request.duplicate()
	_queued_request = {}
	_execute_transition(pending.get("screen_id", "") as String, pending.get("transition", TransitionType.CROSS_FADE) as int)


## Drains the _queued_modal slot if populated, invoking push_overlay.
##
## Called at end of _on_transition_finished AFTER _drain_queued_request_if_any.
## Queued modals execute in IDLE regardless of save_failed outcome
## (ADR-0007 Risks row 4).
##
## TR-scene-manager-007 — ADR-0007
func _drain_queued_modal_if_any() -> void:
	if _queued_modal.is_empty():
		return
	var pending: Dictionary = _queued_modal.duplicate()
	_queued_modal = {}
	push_overlay(pending.get("overlay_id", "") as String, pending.get("pause_on_open", true) as bool)


## Centralized helper: pause state derived from _modal_pause_count.
##
## Never write get_tree().paused directly — always go through this helper.
## This is the ONLY legitimate write site for get_tree().paused in the project
## (ForbiddenPattern "get_tree_paused_external_write" enforced by control-manifest).
##
## Defensive canary: if the tree's pause state diverges from what the counter
## implies, a push_error is logged to detect external tampering.
##
## ADR-0007 Risks row 7 counter invariant
func _apply_pause_state() -> void:
	var should_pause: bool = (_modal_pause_count > 0)
	# Defensive canary: compare get_tree().paused to the value WE last wrote.
	# If they differ, an external code path touched get_tree().paused between
	# our writes — that's the ForbiddenPattern "get_tree_paused_external_write".
	# Reading get_tree().paused AFTER the write would always agree with what we
	# just wrote — useless. Tracking "last value we authored" is the only way
	# to catch foreign writes since our last call.
	# Story spec line 111 — drift detection on entry of helper.
	var current_paused: bool = get_tree().paused
	if current_paused != _last_applied_pause_state:
		push_error("[SceneManager] Pause drift detected: tree.paused=%s but our last write was %s — external write to get_tree().paused (ForbiddenPattern)" % [
			current_paused, _last_applied_pause_state
		])
	get_tree().paused = should_pause
	_last_applied_pause_state = should_pause


## Lazy resolver for OverlayLayer child of MainRoot (per-call, per ADR-0003 hot-reload).
##
## OverlayLayer is PROCESS_MODE_ALWAYS; overlays added to it continue animating
## while the rest of the tree is paused (desired per ADR-0007 §Modal overlay API).
##
## A missing MainRoot or OverlayLayer is a fatal configuration error.
## TR-scene-manager-007 — ADR-0007
func _get_overlay_layer() -> CanvasLayer:
	var main_root: Node = get_tree().root.get_node_or_null("MainRoot")
	if main_root == null:
		push_error("[SceneManager] FATAL: MainRoot not found at /root/MainRoot")
		return null
	return main_root.get_node_or_null("OverlayLayer") as CanvasLayer


## Handles the DataRegistry.registry_ready signal.
##
## Advances state from UNINITIALIZED to IDLE. Drains _queued_request if a
## request was queued while UNINITIALIZED (caller-requested route wins).
## Otherwise auto-routes to guild_hall as the default boot screen.
##
## The return_to_app branch is documented here but NOT auto-routed — it is
## triggered post-boot by OfflineProgressionEngine.offline_rewards_collected
## per ADR-0014. Story 009 wires that receiver.
##
## ADR-0003 Amendment #1: subscription from any rank is safe at _ready() time.
## ADR-0007: UNINITIALIZED → IDLE boundary + first-launch routing.
## TR-scene-manager-038 — AC H-06
func _on_registry_ready() -> void:
	# UNINITIALIZED → IDLE boundary.
	state = State.IDLE

	# Guard: skip the initial transition when MainRoot is absent (test-env path).
	# Sprint 7 Story M1 / TD-010: in headless unit-test environments, MainRoot
	# is not present in the scene tree. _execute_transition → _get_screen_container
	# would assertion-fail with `[SceneManager] MainRoot is required but missing`.
	# Production wiring guarantees MainRoot.tscn is the main scene; this guard is
	# a NO-OP in production but keeps SceneManager from crashing tests that boot
	# autoloads without the MainRoot scene attached (e.g., DataRegistry skeleton
	# tests in `tests/unit/data_registry/autoload_skeleton_and_state_machine_test.gd`).
	if get_tree().root.get_node_or_null("MainRoot") == null:
		push_warning(
			"[SceneManager] _on_registry_ready: MainRoot absent — skipping initial transition. "
			+ "This is the documented test-env path (TD-010). Production must register MainRoot.tscn "
			+ "as the main scene in project.godot."
		)
		return

	# If a request was queued while UNINITIALIZED, drain it first (caller-requested route wins).
	if not _queued_request.is_empty():
		var pending: Dictionary = _queued_request.duplicate()
		_queued_request = {}
		_execute_transition(pending.get("screen_id", "") as String, pending.get("transition", TransitionType.CROSS_FADE) as int)
		return

	# Default boot route: guild_hall.
	# TickSystem rank 0 < SceneManager rank (≥8) — state read at _ready is safe (ADR-0003).
	# offline_elapsed_seconds fires asynchronously; for the boot-sync path, the return_to_app
	# branch is documented here and fully wired when OfflineProgressionEngine.offline_rewards_collected
	# triggers a post-boot request_screen("return_to_app", SLIDE_DOWN) — see Story 009.
	# For MVP this story defaults to guild_hall on every clean launch.
	_execute_transition("guild_hall", TransitionType.CROSS_FADE)


## Returns the TransitionLayer CanvasLayer child of MainRoot, or null if missing.
##
## Resolved per-call — never cached — to remain hot-reload safe (ADR-0003).
## TransitionLayer is PROCESS_MODE_ALWAYS; tweens created on it are never frozen
## by pause races (ADR-0007 Engine Notes on TWEEN_PAUSE_BOUND).
##
## A missing TransitionLayer is a fatal configuration error.
func _get_transition_layer() -> CanvasLayer:
	var main_root: Node = get_tree().root.get_node_or_null("MainRoot")
	if main_root == null:
		push_error("[SceneManager] FATAL: MainRoot not found at /root/MainRoot.")
		return null
	return main_root.get_node_or_null("TransitionLayer") as CanvasLayer


## Returns the Fade ColorRect child of TransitionLayer, or null if missing.
##
## Used by CROSS_FADE and FADE_TO_BLACK transitions to animate alpha.
## Resolved per-call for hot-reload safety (ADR-0003).
func _get_transition_color_rect() -> ColorRect:
	var tl: CanvasLayer = _get_transition_layer()
	if tl == null:
		return null
	return tl.get_node_or_null("Fade") as ColorRect


## Returns the ScreenContainer child of MainRoot, or null if MainRoot is missing.
##
## Lazily resolves the node path on each call (never cached — hot-reload safety
## per ADR-0003 §Key interfaces). A missing MainRoot is a fatal configuration
## error that must never be silenced.
##
## Example:
##   var sc: Node = _get_screen_container()
##   if sc == null: return  # error already emitted
func _get_screen_container() -> Node:
	var main_root: Node = get_tree().root.get_node_or_null("MainRoot")
	if main_root == null:
		push_error("[SceneManager] FATAL: MainRoot not found at /root/MainRoot. " +
			"Ensure MainRoot.tscn is set as the main scene in project.godot.")
		assert(false, "[SceneManager] MainRoot is required but missing from the scene tree.")
		return null
	return main_root.get_node_or_null("ScreenContainer")


## Returns the cross-fade duration for the given incoming screen (milliseconds).
##
## Priority: reduce_motion clamp > per-screen transition_override_ms > config default > hardcoded constant.
## When reduce_motion is true the clamp short-circuits all other logic — the 50ms value
## is returned regardless of per-screen overrides or config knobs (ADR-0007 §reduce_motion).
## Negative values are clamped to 0 with push_warning.
##
## [param incoming_screen] the incoming screen node; may be null.
##
## TR-scene-manager-027 — ADR-0007
func _get_crossfade_duration_ms(incoming_screen: Control) -> int:
	if reduce_motion:
		return REDUCE_MOTION_CLAMP_MS
	if incoming_screen != null and "transition_override_ms" in incoming_screen:
		var override_ms: int = incoming_screen.transition_override_ms
		if override_ms < 0:
			push_warning("[SceneManager] transition_override_ms < 0 on '%s'; clamped to 0" % incoming_screen.name)
			override_ms = 0
		if override_ms > 0:
			return override_ms
	if _config != null and "default_crossfade_ms" in _config:
		return _config.get("default_crossfade_ms") as int
	return _CROSSFADE_DEFAULT_MS


## Returns the slide duration for the given incoming screen (milliseconds).
##
## When reduce_motion is true, returns REDUCE_MOTION_CLAMP_MS regardless of other knobs.
## TR-scene-manager-027 — ADR-0007
func _get_slide_duration_ms(incoming_screen: Control) -> int:
	if reduce_motion:
		return REDUCE_MOTION_CLAMP_MS
	if incoming_screen != null and "transition_override_ms" in incoming_screen:
		var override_ms: int = incoming_screen.transition_override_ms
		if override_ms > 0:
			return override_ms
	if _config != null and "slide_duration_ms" in _config:
		return _config.get("slide_duration_ms") as int
	return _SLIDE_DEFAULT_MS


## Returns the fade-to-black duration for the given incoming screen (milliseconds).
##
## When reduce_motion is true, returns REDUCE_MOTION_CLAMP_MS regardless of other knobs.
## TR-scene-manager-027 — ADR-0007
func _get_fade_to_black_duration_ms(incoming_screen: Control) -> int:
	if reduce_motion:
		return REDUCE_MOTION_CLAMP_MS
	if incoming_screen != null and "transition_override_ms" in incoming_screen:
		var override_ms: int = incoming_screen.transition_override_ms
		if override_ms > 0:
			return override_ms
	if _config != null and "fade_to_black_ms" in _config:
		return _config.get("fade_to_black_ms") as int
	return _FADE_TO_BLACK_DEFAULT_MS


## Returns the push-modal duration for the given incoming screen (milliseconds).
##
## When reduce_motion is true, returns REDUCE_MOTION_CLAMP_MS regardless of other knobs.
## TR-scene-manager-027 — ADR-0007
func _get_push_modal_duration_ms(incoming_screen: Control) -> int:
	if reduce_motion:
		return REDUCE_MOTION_CLAMP_MS
	if incoming_screen != null and "transition_override_ms" in incoming_screen:
		var override_ms: int = incoming_screen.transition_override_ms
		if override_ms > 0:
			return override_ms
	if _config != null and "push_modal_ms" in _config:
		return _config.get("push_modal_ms") as int
	return _PUSH_MODAL_DEFAULT_MS


## Logs cross-fade timing to stdout with a structured prefix for CI capture.
##
## Gate: OS.is_debug_build() only. Production is a no-op.
##
## Timing is logged to print() (not file I/O) because:
##   - Exports do not have write access to res://production/qa/evidence/
##   - user:// paths are OS-specific and may not be accessible in CI
##   - CI can grep stdout for [SCENE_MANAGER_TIMING] prefix to collect evidence
##
## Evidence line format: [SCENE_MANAGER_TIMING] start=X end=Y duration=Z PASS|FAIL
##
## AC H-01 uses the structural probe (_get_last_crossfade_total_duration_ms)
## as the primary assertion. This log provides supplementary wall-clock evidence.
##
## TR-scene-manager-032 — ADR-0007
func _log_crossfade_timing(start_ms: int, end_ms: int) -> void:
	if not OS.is_debug_build():
		return
	var duration_ms: int = end_ms - start_ms
	var pass_status: String = "PASS" if (duration_ms >= 140 and duration_ms <= 160) else "FAIL_OR_HEADLESS_COMPRESSED"
	print("[SCENE_MANAGER_TIMING] start=%d end=%d duration=%d status=%s" % [
		start_ms, end_ms, duration_ms, pass_status
	])
