# Integration tests for Story 012: DungeonRunView Screen
#
# Covers acceptance criteria:
#   AC-1: Live tick display — TickLabel refreshes when GameTime.tick_fired emits.
#   AC-2: Live kill_count display — KillCountLabel refreshes on tick_fired.
#   AC-3: Run-end overlay appears when orchestrator state transitions to RUN_ENDED.
#   AC-5: Lifecycle hygiene — on_exit disconnects tick + state_changed subscriptions.
#   AC-8: Screen routed via SceneManager (structural: file presence + extends Screen).
#   Manifest: no change_scene_to_* calls; no hardcoded Color() literals.
#
# Test isolation pattern (Story 011 lesson applied directly):
#   In headless tests a fresh SceneManagerScript.new() interacts with the live
#   autoload's first-launch routing, leaving current_screen_id pointing at
#   "guild_hall" instead of the requested target. We bypass SceneManager for
#   behavior-level tests by instantiating the screen directly via PackedScene,
#   adding it as a child, and calling on_enter() manually.
#   AC-8 routing is verified structurally: file exists + instance extends Screen.
#   The 7-screen registry already includes "dungeon_run_view" per Story 003's
#   tests/integration/scene_manager/request_screen_and_node_swap_test.gd.
#
# Signal spy pattern:
#   Array[T] is a reference type in GDScript; lambdas that mutate Array[T] by
#   index (spy[0] += 1) correctly update the shared state. Used here for
#   counting signal emissions from within lambdas.
#
# Orchestrator state isolation:
#   before_test() snapshots orchestrator save_data and resets relevant fields.
#   after_test() restores the snapshot and clears injected state.
#   Because DungeonRunOrchestrator.run_snapshot is a public var we can directly
#   assign a fresh RunSnapshot to seed test state without going through dispatch.
#
# ADR-0007: Screen lifecycle contract
# ADR-0008: UI Framework tap-target + focus suppression
# Story 012: DungeonRunView — live tick + kill_count display + RUN_ENDED overlay
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const DUNGEON_RUN_VIEW_SCENE_PATH: String = "res://assets/screens/dungeon_run_view/dungeon_run_view.tscn"
const DUNGEON_RUN_VIEW_GD_PATH: String = "res://assets/screens/dungeon_run_view/dungeon_run_view.gd"

const DungeonRunStateScript = preload("res://src/core/dungeon_run_orchestrator/dungeon_run_state.gd")
const RunSnapshotScript = preload("res://src/core/dungeon_run_orchestrator/run_snapshot.gd")
const CombatRunSnapshotScript = preload("res://src/core/combat/combat_run_snapshot.gd")

# ---------------------------------------------------------------------------
# Per-test state snapshots for isolation
# ---------------------------------------------------------------------------

## Snapshot of DungeonRunOrchestrator fields before each test.
var _orch_state_snapshot: int = DungeonRunStateScript.State.NO_RUN
var _orch_run_snapshot_snapshot: RunSnapshot = null
var _orch_last_dispatch_ms_snapshot: int = 0
## Phase 4 watchable-battle tests seed _combat_snapshot to drive the HP bar +
## enemy-depletion count; snapshot + restore so it never leaks between tests.
var _orch_combat_snapshot_snapshot: RefCounted = null
## Phase 4 defeat-routing tests flip _run_won to false to exercise the
## defeat → guild_hall fork; snapshot + restore (and reset to the WIN default in
## before_test) so a defeated verdict never leaks into the win-path tests.
var _orch_run_won_snapshot: bool = true
## Dispatched biome/floor drive the "Enemies ahead" lineup; snapshot + restore
## so a lineup test's mutation never leaks into another test.
var _orch_dispatched_biome_snapshot: String = ""
var _orch_dispatched_floor_snapshot: int = 0

## Snapshots of SceneManager state modified by tests.
## Story 013 adds _on_state_changed → request_screen("main_menu") on RUN_ENDED.
## Tests that emit state_changed(RUN_ENDED) must pre-arm SceneManager.state =
## TRANSITIONING (so request_screen queues rather than crashing via
## _execute_transition → _get_screen_container assert-crash without MainRoot).
## These snapshots allow after_test() to restore SM state cleanly.
var _sm_state_snapshot: SceneManager.State = SceneManager.State.UNINITIALIZED
var _sm_queued_request_snapshot: Dictionary = {}
var _sm_current_screen_id_snapshot: String = ""


# ---------------------------------------------------------------------------
# Test lifecycle
# ---------------------------------------------------------------------------

func before_test() -> void:
	# Snapshot orchestrator fields so we can restore them after the test.
	_orch_state_snapshot = DungeonRunOrchestrator.state
	_orch_run_snapshot_snapshot = DungeonRunOrchestrator.run_snapshot
	_orch_last_dispatch_ms_snapshot = DungeonRunOrchestrator._last_dispatch_ms

	# Reset orchestrator to a clean NO_RUN state for test isolation.
	# Direct field write bypasses _set_state so state_changed does NOT fire
	# during setup (avoids polluting any test's signal spy).
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.NO_RUN
	DungeonRunOrchestrator.run_snapshot = null
	DungeonRunOrchestrator._last_dispatch_ms = 0

	# Snapshot + clear the combat snapshot (Phase 4 watchable-battle read-model).
	_orch_combat_snapshot_snapshot = DungeonRunOrchestrator._combat_snapshot
	DungeonRunOrchestrator._combat_snapshot = null

	# Snapshot + reset the run verdict to the WIN default (Phase 4 defeat-routing).
	# Defeat tests set _run_won = false; resetting here keeps the win-path tests
	# correct regardless of execution order.
	_orch_run_won_snapshot = DungeonRunOrchestrator._run_won
	DungeonRunOrchestrator._run_won = true

	# Snapshot dispatched biome/floor (mutated by the enemy-lineup tests).
	_orch_dispatched_biome_snapshot = DungeonRunOrchestrator._dispatched_biome_id
	_orch_dispatched_floor_snapshot = DungeonRunOrchestrator._dispatched_floor_index

	# Snapshot SceneManager state (Story 013 adds auto-route on RUN_ENDED which
	# writes SceneManager._queued_request; after_test() must restore it).
	_sm_state_snapshot = SceneManager.state
	_sm_queued_request_snapshot = SceneManager._queued_request.duplicate()
	_sm_current_screen_id_snapshot = SceneManager.current_screen_id


func after_test() -> void:
	# Restore SceneManager state.
	SceneManager.state = _sm_state_snapshot
	SceneManager._queued_request = _sm_queued_request_snapshot.duplicate()
	SceneManager.current_screen_id = _sm_current_screen_id_snapshot

	# Restore orchestrator fields.
	DungeonRunOrchestrator.state = _orch_state_snapshot
	DungeonRunOrchestrator.run_snapshot = _orch_run_snapshot_snapshot
	DungeonRunOrchestrator._last_dispatch_ms = _orch_last_dispatch_ms_snapshot
	DungeonRunOrchestrator._dispatched_biome_id = _orch_dispatched_biome_snapshot
	DungeonRunOrchestrator._dispatched_floor_index = _orch_dispatched_floor_snapshot
	DungeonRunOrchestrator._combat_snapshot = _orch_combat_snapshot_snapshot
	DungeonRunOrchestrator._run_won = _orch_run_won_snapshot


# ---------------------------------------------------------------------------
# Helper: navigate_to_dungeon_run_view_screen
#
# Bypass SceneManager — see Story 011 closure note for rationale. Instantiates
# the packed scene, adds it as a child of the test suite, awaits one frame for
# @onready vars to resolve, then calls on_enter() manually.
# ---------------------------------------------------------------------------

func _navigate_to_dungeon_run_view_screen() -> Control:
	# Bypass SceneManager — see Story 011 closure note for rationale.
	var packed: PackedScene = load(DUNGEON_RUN_VIEW_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var screen: Control = packed.instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	if screen.has_method("on_enter"):
		screen.on_enter()
	return screen


# ---------------------------------------------------------------------------
# Helper: seed a fresh RunSnapshot on the orchestrator for AC-1 / AC-2 tests.
# ---------------------------------------------------------------------------

func _seed_run_snapshot(current_tick: int, kill_count: int) -> RunSnapshot:
	var snap: RunSnapshot = RunSnapshotScript.new()
	snap.current_tick = current_tick
	snap.last_emitted_tick = current_tick
	snap.kill_count = kill_count
	DungeonRunOrchestrator.run_snapshot = snap
	return snap


# ---------------------------------------------------------------------------
# Helper: seed the watchable-battle combat snapshot (Phase 4) on the orchestrator.
# Worked example (mirrors party_hp_curve_test.gd): dispatched_at=100, two enemies
# a(dmg 20) + b(dmg 10), both advantaged; party_damage_by(T)=20*min(T,2)+10*min(T,5);
# party_hp=100 -> rel 0 reads 100, rel 2 reads 40. enemy_total = 2 * loops.
# ---------------------------------------------------------------------------

func _seed_combat_snapshot(party_hp: int, loops: int = 1) -> RefCounted:
	var snap: RefCounted = CombatRunSnapshotScript.new()
	snap.formation_dps_per_tick = 10.0
	snap.formation_total_hp = party_hp
	snap.dispatched_at_tick = 100
	snap.loops_per_run = loops
	var cache: Dictionary = {&"goblin": true}
	snap.matchup_cache = cache
	var enemies: Array = [
		{"id": &"a", "archetype": &"goblin", "tier": 1, "is_boss": false,
			"base_hp": 30, "base_attack": 180, "base_speed": 10},
		{"id": &"b", "archetype": &"goblin", "tier": 1, "is_boss": false,
			"base_hp": 45, "base_attack": 90, "base_speed": 10},
	]
	snap.enemy_list = enemies
	DungeonRunOrchestrator._combat_snapshot = snap
	return snap


# ===========================================================================
# Structural: screen extends Screen base class
# ===========================================================================

func test_dungeon_run_view_screen_extends_screen_base_class() -> void:
	# Arrange
	var packed: PackedScene = load(DUNGEON_RUN_VIEW_SCENE_PATH) as PackedScene
	assert_object(packed).is_not_null()

	# Act
	var screen: Control = packed.instantiate() as Control
	assert_object(screen).is_not_null()

	# Assert
	assert_bool(screen is Screen).is_true()

	# Cleanup
	screen.free()


# ===========================================================================
# Structural: screen declares all four lifecycle hooks
# ===========================================================================

func test_dungeon_run_view_screen_declares_all_four_lifecycle_hooks() -> void:
	# Arrange
	var packed: PackedScene = load(DUNGEON_RUN_VIEW_SCENE_PATH) as PackedScene
	var screen: Control = packed.instantiate() as Control
	assert_object(screen).is_not_null()

	# Assert
	assert_bool(screen.has_method("on_enter")).is_true()
	assert_bool(screen.has_method("on_exit")).is_true()
	assert_bool(screen.has_method("on_pause")).is_true()
	assert_bool(screen.has_method("on_resume")).is_true()

	# Cleanup
	screen.free()


# ===========================================================================
# AC-1: TickLabel refreshes on tick_fired
# ===========================================================================

func test_dungeon_run_view_screen_tick_label_refreshes_on_tick_fired() -> void:
	# Arrange — seed orchestrator with tick=5 before navigating.
	var snap: RunSnapshot = _seed_run_snapshot(5, 0)

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var tick_label: Label = screen.get_node_or_null("StatsPanel/TickRow/TickLabel") as Label
	assert_object(tick_label).is_not_null()

	# Pre-assert: label reflects the seeded tick at on_enter time.
	assert_str(tick_label.text).is_equal("5")

	# Act — advance the snapshot to tick=6 and emit tick_fired.
	snap.current_tick = 6
	snap.kill_count = 0
	DungeonRunOrchestrator.run_snapshot = snap
	TickSystem.tick_fired.emit(6)
	await get_tree().process_frame

	# Assert — label now shows "6".
	assert_str(tick_label.text).is_equal("6")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# AC-2: KillCountLabel refreshes on tick_fired
# ===========================================================================

func test_dungeon_run_view_screen_kill_count_label_refreshes_on_tick_fired() -> void:
	# Arrange — seed orchestrator with kill_count=2.
	var snap: RunSnapshot = _seed_run_snapshot(1, 2)

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var kill_label: Label = screen.get_node_or_null("StatsPanel/KillCountRow/KillCountLabel") as Label
	assert_object(kill_label).is_not_null()

	# Pre-assert: label reflects the seeded kill_count at on_enter time.
	assert_str(kill_label.text).is_equal("2")

	# Act — advance snapshot to kill_count=3 and emit tick_fired.
	snap.current_tick = 2
	snap.kill_count = 3
	DungeonRunOrchestrator.run_snapshot = snap
	TickSystem.tick_fired.emit(2)
	await get_tree().process_frame

	# Assert
	assert_str(kill_label.text).is_equal("3")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# AC-1 / AC-2 edge: null run_snapshot — no crash, handler returns early
# ===========================================================================

func test_dungeon_run_view_screen_tick_fired_with_null_snapshot_no_crash() -> void:
	# Arrange — ensure run_snapshot is null.
	DungeonRunOrchestrator.run_snapshot = null

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var tick_label: Label = screen.get_node_or_null("StatsPanel/TickRow/TickLabel") as Label
	assert_object(tick_label).is_not_null()

	# Act — emit tick_fired with a null snapshot; must not crash.
	TickSystem.tick_fired.emit(1)
	await get_tree().process_frame

	# Assert — label still shows "0" (defensive reset from _refresh_display).
	assert_str(tick_label.text).is_equal("0")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# AC-3: Run-end overlay shows when state transitions to RUN_ENDED
# ===========================================================================

func test_dungeon_run_view_screen_run_end_overlay_shows_on_run_ended() -> void:
	# Arrange — seed orchestrator with kill_count=7 in ACTIVE_FOREGROUND.
	var snap: RunSnapshot = _seed_run_snapshot(10, 7)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var overlay: Control = screen.get_node_or_null("RunEndOverlay") as Control
	assert_object(overlay).is_not_null()

	# Pre-assert: overlay is hidden.
	assert_bool(overlay.visible).is_false()

	# Pre-arm SceneManager to TRANSITIONING so Story 013's auto-route
	# (request_screen("main_menu")) queues into _queued_request rather than
	# calling _execute_transition, which assert-crashes without MainRoot.
	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — simulate state transition to RUN_ENDED by emitting state_changed.
	# (Directly drives _on_state_changed without going through _set_state, which
	# would also trigger _exit_active_foreground and TickSystem.tick_fired
	# disconnect — this isolation is cleaner for a UI behavior test.)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)
	await get_tree().process_frame

	# Assert — overlay is now visible.
	assert_bool(overlay.visible).is_true()

	# Assert — overlay text contains the kill count ("7").
	var run_end_label: Label = screen.get_node_or_null("RunEndOverlay/RunEndLabel") as Label
	assert_object(run_end_label).is_not_null()
	assert_str(run_end_label.text).contains("7")

	# Assert — orchestrator state is RUN_ENDED.
	assert_int(DungeonRunOrchestrator.state).is_equal(DungeonRunStateScript.State.RUN_ENDED)

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# AC-3 edge: run_end overlay idempotent — shows only once on repeated signals
# ===========================================================================

func test_dungeon_run_view_screen_run_end_overlay_idempotent() -> void:
	# Arrange
	var snap: RunSnapshot = _seed_run_snapshot(5, 3)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var overlay: Control = screen.get_node_or_null("RunEndOverlay") as Control
	assert_object(overlay).is_not_null()

	# Pre-arm SceneManager to TRANSITIONING so Story 013's auto-route
	# (request_screen("main_menu")) queues rather than assert-crashing
	# on _execute_transition without MainRoot.
	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — emit state_changed twice with RUN_ENDED.
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)
	await get_tree().process_frame

	# Assert — overlay is visible (not double-hidden or in a bad state).
	assert_bool(overlay.visible).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# AC-5: on_exit disconnects tick subscription
# ===========================================================================

func test_dungeon_run_view_screen_on_exit_disconnects_tick_subscription() -> void:
	# Arrange — navigate to screen (which connects tick_fired in on_enter).
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Pre-assert: tick_fired is connected while the screen is active.
	assert_bool(TickSystem.tick_fired.is_connected(screen._on_tick_fired)).is_true()

	# Act — call on_exit directly (mirrors SceneManager calling it before queue_free).
	screen.on_exit()

	# Assert — tick subscription is disconnected.
	assert_bool(TickSystem.tick_fired.is_connected(screen._on_tick_fired)).is_false()

	# Verify: emitting tick_fired after on_exit produces no push_error (no
	# orphaned connection). This is a behavioural assertion — if the connection
	# is still live it would call into a freed object and push_error in debug.
	# Here we just emit and await; the absence of engine errors is the assertion.
	TickSystem.tick_fired.emit(99)
	await get_tree().process_frame

	# Cleanup
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# AC-5 extension: on_exit disconnects state_changed subscription
# ===========================================================================

func test_dungeon_run_view_screen_on_exit_disconnects_state_changed_subscription() -> void:
	# Arrange
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Pre-assert: state_changed is connected while the screen is active.
	assert_bool(
		DungeonRunOrchestrator.state_changed.is_connected(screen._on_state_changed)
	).is_true()

	# Act
	screen.on_exit()

	# Assert — state_changed subscription is disconnected.
	assert_bool(
		DungeonRunOrchestrator.state_changed.is_connected(screen._on_state_changed)
	).is_false()

	# Cleanup
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# VFX particle wiring (GDD #27 OQ-27-1): level-up shimmer + first-floor-clear
# glow. The kill-burst is covered by vfx_kit_test (VfxKit.spawn_burst) + manual
# screenshot; these guard the SCREEN-side wiring — the connection hygiene that
# stops the floor-clear signal from leaking or going unwired, and the losing-run
# gate. reduce_motion is set false (snapshot+restored) so VfxKit actually emits.
# ===========================================================================

## Counts the live CPUParticles2D bursts under the VFX layer. A burst is "live"
## until VfxKit's finished→queue_free fires (well after these synchronous asserts).
func _count_particles(layer: Node) -> int:
	if layer == null:
		return 0
	var n: int = 0
	for child: Node in layer.get_children():
		if child is CPUParticles2D:
			n += 1
	return n


func test_floor_cleared_first_time_connected_on_enter_disconnected_on_exit() -> void:
	# Arrange
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Pre-assert: the floor-clear feedback is wired while the screen is active.
	# (Regression net: the signal had NO screen-side consumer before this — the
	# exact "scaffolded-but-unwired" gap this wiring closes.)
	assert_bool(
		DungeonRunOrchestrator.floor_cleared_first_time.is_connected(screen._on_floor_cleared_vfx)
	).override_failure_message(
		"floor_cleared_first_time must be connected while dungeon_run_view is active"
	).is_true()

	# Act
	screen.on_exit()

	# Assert — subscription disconnected (no orphaned connection / leak).
	assert_bool(
		DungeonRunOrchestrator.floor_cleared_first_time.is_connected(screen._on_floor_cleared_vfx)
	).is_false()

	# Cleanup
	screen.queue_free()
	await get_tree().process_frame


func test_floor_clear_burst_respects_losing_run_gate() -> void:
	# Arrange
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)  # ensure VfxKit emits (snap-replace off)

	# Act + Assert — a LOSING-run clear is gated (the floor stays the retry
	# target → no celebration burst).
	screen.call("_on_floor_cleared_vfx", 5, "forest_reach", true)
	assert_int(_count_particles(screen._vfx_layer)).override_failure_message(
		"losing-run floor clear must NOT spawn a celebration burst"
	).is_equal(0)

	# Act + Assert — a WINNING-run first clear spawns exactly one lantern-glow
	# burst. This also nets the committed lantern_glow asset (winning→1 requires
	# the texture to load; CI regenerates the .ctex from the committed PNG).
	screen.call("_on_floor_cleared_vfx", 5, "forest_reach", false)
	assert_int(_count_particles(screen._vfx_layer)).override_failure_message(
		"winning-run first floor clear should spawn exactly one lantern-glow burst"
	).is_equal(1)

	# Cleanup — restore live autoload state (test isolation).
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_level_up_spawns_parchment_shimmer_burst() -> void:
	# Arrange
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)

	# Act — a routine level-up. (Nets the regenerated parchment_shimmer asset:
	# the shimmer rides the existing hero_leveled toast handler.)
	screen.call("_on_hero_leveled", 7001, 4, 5)

	# Assert — exactly one shimmer burst in the VFX layer. The level-up Label
	# toast lives directly under the screen, not the layer, so it is not counted.
	assert_int(_count_particles(screen._vfx_layer)).override_failure_message(
		"a level-up should spawn one parchment-shimmer burst into the VFX layer"
	).is_equal(1)

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# AC-8: Routed via SceneManager.request_screen (structural file + extends check)
# ===========================================================================

func test_dungeon_run_view_screen_routed_via_request_screen() -> void:
	# AC-8 — verified structurally. The 7-screen registry including
	# "dungeon_run_view" is already verified by Story 003's test at
	# tests/integration/scene_manager/request_screen_and_node_swap_test.gd.
	# Here we verify: the packed scene exists, can be instantiated, and
	# the instance extends Screen (the on_enter/on_exit lifecycle contract
	# expected by SceneManager).
	var packed: PackedScene = load(DUNGEON_RUN_VIEW_SCENE_PATH) as PackedScene
	assert_object(packed).is_not_null()

	var instance: Node = packed.instantiate()
	assert_object(instance).is_not_null()
	assert_bool(instance is Screen).is_true()
	assert_bool(instance.has_method("on_enter")).is_true()

	instance.queue_free()


# ===========================================================================
# Manifest: no SceneTree.change_scene_to_* calls in dungeon_run_view.gd
# ===========================================================================

func test_dungeon_run_view_screen_no_change_scene_calls() -> void:
	# Grep dungeon_run_view.gd for forbidden scene-change APIs.
	var forbidden: Array[String] = [
		"change_scene_to_packed",
		"change_scene_to_file",
	]
	var fa: FileAccess = FileAccess.open(DUNGEON_RUN_VIEW_GD_PATH, FileAccess.READ)
	assert_object(fa).is_not_null()
	var violations: Array[String] = []
	var line_num: int = 0
	while not fa.eof_reached():
		var line: String = fa.get_line()
		line_num += 1
		for pattern: String in forbidden:
			if line.contains(pattern):
				violations.append("line %d: %s" % [line_num, line.strip_edges()])
	fa.close()
	assert_int(violations.size()).is_equal(0)


# ===========================================================================
# Manifest: no hardcoded Color() literals in dungeon_run_view.gd
# ===========================================================================

func test_dungeon_run_view_screen_no_hardcoded_color_literals() -> void:
	var fa: FileAccess = FileAccess.open(DUNGEON_RUN_VIEW_GD_PATH, FileAccess.READ)
	assert_object(fa).is_not_null()
	var violations: Array[String] = []
	var line_num: int = 0
	while not fa.eof_reached():
		var line: String = fa.get_line()
		line_num += 1
		# Match Color( with at least one number argument — avoid matching Color.RED etc.
		if line.contains("Color(") and line.contains(","):
			violations.append("line %d: %s" % [line_num, line.strip_edges()])
	fa.close()
	assert_int(violations.size()).is_equal(0)


# ===========================================================================
# Enemy lineup — "Enemies ahead" shows the dispatched floor's enemy_list
# (Demo asset wiring: dungeon-run enemy lineup)
# ===========================================================================

## Recursively concatenates all Label text under [param node] for content asserts.
func _gather_text(node: Node) -> String:
	var out: String = ""
	if node is Label:
		out += (node as Label).text + " "
	for child: Node in node.get_children():
		out += _gather_text(child)
	return out


func test_enemy_lineup_shows_dispatched_floor_enemies() -> void:
	# Arrange — dispatch context: forest_reach floor 1 (hollow_brute ×3 + glowmoth ×1).
	DungeonRunOrchestrator._dispatched_biome_id = "forest_reach"
	DungeonRunOrchestrator._dispatched_floor_index = 1

	# Act
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var panel: Node = screen.find_child("WireEnemyLineup", true, false)

	# Assert — the lineup exists and names the floor-1 enemies + the ×3 count.
	assert_object(panel).is_not_null()
	var text: String = _gather_text(panel)
	assert_str(text).contains("Hollow Brute")
	assert_str(text).contains("Glowmoth")
	assert_str(text).contains("×3")


func test_enemy_lineup_quiet_when_no_run_dispatched() -> void:
	# Arrange — no dispatched biome (cleared state).
	DungeonRunOrchestrator._dispatched_biome_id = ""
	DungeonRunOrchestrator._dispatched_floor_index = 0

	# Act
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	var panel: Node = screen.find_child("WireEnemyLineup", true, false)

	# Assert — panel present but shows the quiet fallback, no enemy names.
	assert_object(panel).is_not_null()
	var text: String = _gather_text(panel)
	assert_str(text).contains("quiet")
	assert_bool(text.contains("Hollow Brute")).is_false()


# ===========================================================================
# Felt-progression toasts — milestone level-up + live biome-unlock
# (Felt-progression polish)
# ===========================================================================

## Finds the first live toast Label under the screen whose name starts with the
## given prefix ("LevelUpToast_" / "BiomeUnlockToast").
func _find_toast(screen: Node, prefix: String) -> Label:
	for child: Node in screen.get_children():
		if child is Label and (child as Label).name.begins_with(prefix):
			return child as Label
	return null


func test_milestone_level_spawns_emphasized_toast() -> void:
	# Arrange
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Act — level 10 is a milestone (no roster hero needed; id-text fallback).
	screen.call("_on_hero_leveled", 4242, 9, 10)

	# Assert — a level toast spawned and is emphasized (font-size override).
	var toast: Label = _find_toast(screen, "LevelUpToast_")
	assert_object(toast).is_not_null()
	assert_bool(toast.has_theme_font_size_override("font_size")).override_failure_message(
		"milestone level toast should be emphasized (font-size override)"
	).is_true()


func test_routine_level_spawns_plain_toast() -> void:
	# Arrange
	var screen: Control = await _navigate_to_dungeon_run_view_screen()

	# Act — level 2 is NOT a milestone.
	screen.call("_on_hero_leveled", 4243, 1, 2)

	# Assert — a level toast spawned and is NOT emphasized.
	var toast: Label = _find_toast(screen, "LevelUpToast_")
	assert_object(toast).is_not_null()
	assert_bool(toast.has_theme_font_size_override("font_size")).is_false()


func test_biome_unlock_spawns_live_toast_naming_the_region() -> void:
	# Arrange
	var screen: Control = await _navigate_to_dungeon_run_view_screen()

	# Act — unlock a real biome (ember_wastes resolves via DataRegistry).
	screen.call("_on_biome_unlocked", "ember_wastes")

	# Assert — a biome-unlock toast spawned naming the region.
	var toast: Label = _find_toast(screen, "BiomeUnlockToast")
	assert_object(toast).is_not_null()
	assert_str(toast.text).contains("Ember Wastes")


# ===========================================================================
# Watchable battle — party HP bar + enemy-depletion count (Defeat & Injury
# Phase 4, GDD #34 §I). The bar/labels poll the orchestrator read-model
# getters (current_party_hp/max_party_hp/enemies_remaining/enemy_total), which
# delegate the HP curve to the resolver's defeat-verdict math.
# ===========================================================================

func test_party_hp_bar_reflects_combat_snapshot_on_enter() -> void:
	# Arrange — full HP at dispatch tick (rel 0 -> no damage yet).
	_seed_combat_snapshot(100, 1)
	_seed_run_snapshot(100, 0)  # current_tick == dispatched_at -> rel 0

	# Act
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var bar: ProgressBar = screen.find_child("PartyHpBar", true, false) as ProgressBar
	var label: Label = screen.find_child("PartyHpLabel", true, false) as Label

	# Assert — bar reads full, numeric label reads "HP 100/100".
	assert_object(bar).is_not_null()
	assert_float(bar.max_value).is_equal(100.0)
	assert_float(bar.value).is_equal(100.0)
	assert_object(label).is_not_null()
	assert_str(label.text).is_equal("HP 100/100")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_party_hp_bar_depletes_on_tick() -> void:
	# Arrange — start full at dispatch tick.
	_seed_combat_snapshot(100, 1)
	var snap: RunSnapshot = _seed_run_snapshot(100, 0)

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var bar: ProgressBar = screen.find_child("PartyHpBar", true, false) as ProgressBar
	var label: Label = screen.find_child("PartyHpLabel", true, false) as Label
	assert_object(bar).is_not_null()
	assert_float(bar.value).is_equal(100.0)

	# Act — advance to current_tick 102 (rel 2 -> party_damage_by(2)=60 -> 40 HP).
	snap.current_tick = 102
	snap.last_emitted_tick = 102
	DungeonRunOrchestrator.run_snapshot = snap
	TickSystem.tick_fired.emit(102)
	await get_tree().process_frame

	# Assert — bar dropped to 40, label tracks it.
	assert_float(bar.value).is_equal(40.0)
	assert_str(label.text).is_equal("HP 40/100")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_enemies_remaining_label_reflects_kills() -> void:
	# Arrange — 2 enemies * 3 loops = 6 total; 1 killed -> 5 remaining.
	_seed_combat_snapshot(100, 3)
	_seed_run_snapshot(100, 1)

	# Act
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var label: Label = screen.find_child("EnemiesRemainingLabel", true, false) as Label

	# Assert
	assert_object(label).is_not_null()
	assert_str(label.text).is_equal("Enemies 5/6")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_party_hp_bar_safe_with_no_combat_snapshot() -> void:
	# Arrange — dev-nav idle DRV: no combat snapshot, no run.
	DungeonRunOrchestrator._combat_snapshot = null
	DungeonRunOrchestrator.run_snapshot = null

	# Act — must not crash; bar present but reads a safe 0/clamped-max.
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var bar: ProgressBar = screen.find_child("PartyHpBar", true, false) as ProgressBar
	var label: Label = screen.find_child("PartyHpLabel", true, false) as Label
	var enemies_label: Label = screen.find_child("EnemiesRemainingLabel", true, false) as Label

	# Assert — widgets exist, HP reads 0/0, enemies read 0/0 (view hides/ignores).
	assert_object(bar).is_not_null()
	assert_float(bar.value).is_equal(0.0)
	assert_str(label.text).is_equal("HP 0/0")
	assert_object(enemies_label).is_not_null()
	assert_str(enemies_label.text).is_equal("Enemies 0/0")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Defeat moment + correct routing (Defeat & Injury Phase 4, GDD #34 §I / L4).
# A WIN routes to victory_moment; a DEFEAT shows a distinct defeat overlay and
# routes to guild_hall (the injured-party recovery surface). The route decision
# reads DungeonRunOrchestrator.was_last_run_defeated() so it stays correct even
# when the run_defeated signal is missed (transition-replay of a short run).
#
# The route fires after RUN_END_DWELL_MS (1500 ms) — the awaiting tests wait
# 1.7 s so the screen's own dwell timer fires (and its coroutine completes)
# within the test boundary, before after_test restores SceneManager state.
# ===========================================================================

func test_run_defeated_emits_distinct_defeat_overlay() -> void:
	# Arrange — navigate (no RUN_ENDED, so no auto-route coroutine is spawned).
	_seed_run_snapshot(8, 1)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var overlay: Control = screen.get_node_or_null("RunEndOverlay") as Control
	var run_label: Label = screen.get_node_or_null("RunEndOverlay/RunEndLabel") as Label
	assert_object(overlay).is_not_null()
	assert_object(run_label).is_not_null()
	assert_bool(overlay.visible).is_false()

	# Act — the dedicated defeat moment fires for floor 4.
	DungeonRunOrchestrator.run_defeated.emit(4, "forest_reach")
	await get_tree().process_frame

	# Assert — overlay visible with the DEFEAT copy (names floor "4"), NOT the
	# victory "Run Complete" copy.
	assert_bool(overlay.visible).is_true()
	assert_str(run_label.text).contains("4")
	assert_bool(run_label.text.contains("Run Complete")).is_false()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_defeat_verdict_routes_to_guild_hall() -> void:
	# Arrange — a DEFEATED run in ACTIVE_FOREGROUND (verdict already a loss).
	var snap: RunSnapshot = _seed_run_snapshot(10, 2)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	DungeonRunOrchestrator._run_won = false
	DungeonRunOrchestrator._dispatched_floor_index = 3

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var overlay: Control = screen.get_node_or_null("RunEndOverlay") as Control
	var run_label: Label = screen.get_node_or_null("RunEndOverlay/RunEndLabel") as Label
	assert_object(overlay).is_not_null()

	# Pre-arm SceneManager → TRANSITIONING so the route queues into _queued_request
	# rather than calling _execute_transition (assert-crashes without MainRoot).
	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — defeat moment, then the FSM transition to RUN_ENDED (mirrors
	# orchestrator._end_run_defeated: run_defeated emits BEFORE _set_state).
	DungeonRunOrchestrator.run_defeated.emit(3, "forest_reach")
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)

	# Assert (synchronous) — the DEFEAT overlay is shown and the RUN_ENDED
	# transition did NOT overwrite it with the victory "Run Complete" copy.
	assert_bool(overlay.visible).is_true()
	assert_str(run_label.text).contains("3")
	assert_bool(run_label.text.contains("Run Complete")).is_false()

	# Wait out the RUN_END_DWELL_MS = 1500 dwell so the route fires.
	await get_tree().create_timer(1.7).timeout

	# Assert — routed to guild_hall (recovery surface), NOT victory_moment.
	assert_str(String(SceneManager._queued_request.get("screen_id", ""))).is_equal("guild_hall")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_defeat_routes_to_guild_hall_even_without_run_defeated_signal() -> void:
	# Arrange — DEFEATED verdict, but the run_defeated signal is NEVER emitted
	# (simulates a transition-replay where the view subscribed too late to catch
	# it). Routing must still fork to guild_hall via was_last_run_defeated().
	var snap: RunSnapshot = _seed_run_snapshot(10, 1)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND
	DungeonRunOrchestrator._run_won = false
	DungeonRunOrchestrator._dispatched_floor_index = 2

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var overlay: Control = screen.get_node_or_null("RunEndOverlay") as Control
	var run_label: Label = screen.get_node_or_null("RunEndOverlay/RunEndLabel") as Label
	assert_object(overlay).is_not_null()

	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — ONLY the RUN_ENDED transition (no run_defeated signal).
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)

	# Assert (synchronous) — the fallback path detected the defeat and showed the
	# DEFEAT overlay (floor "2"), not the victory copy.
	assert_bool(overlay.visible).is_true()
	assert_str(run_label.text).contains("2")
	assert_bool(run_label.text.contains("Run Complete")).is_false()

	# Wait out the dwell so the route fires.
	await get_tree().create_timer(1.7).timeout

	# Assert — still routes to guild_hall on the signal-missed fallback path.
	assert_str(String(SceneManager._queued_request.get("screen_id", ""))).is_equal("guild_hall")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_win_verdict_routes_to_victory_moment() -> void:
	# Arrange — a WON run (default _run_won = true, reset in before_test). The
	# defeat fork must NOT change the win path (regression guard).
	var snap: RunSnapshot = _seed_run_snapshot(10, 7)
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.ACTIVE_FOREGROUND

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var overlay: Control = screen.get_node_or_null("RunEndOverlay") as Control
	var run_label: Label = screen.get_node_or_null("RunEndOverlay/RunEndLabel") as Label
	assert_object(overlay).is_not_null()

	SceneManager.state = SceneManager.State.TRANSITIONING
	SceneManager._queued_request = {}

	# Act — RUN_ENDED with no defeat verdict → victory path.
	DungeonRunOrchestrator.state = DungeonRunStateScript.State.RUN_ENDED
	DungeonRunOrchestrator.run_snapshot = snap
	DungeonRunOrchestrator.state_changed.emit(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND
	)

	# Assert (synchronous) — the victory run-end overlay (names the kill count "7").
	assert_bool(overlay.visible).is_true()
	assert_str(run_label.text).contains("7")

	# Wait out the dwell so the route fires.
	await get_tree().create_timer(1.7).timeout

	# Assert — routed to victory_moment (win path unchanged by the Phase 4 fork).
	assert_str(String(SceneManager._queued_request.get("screen_id", ""))).is_equal("victory_moment")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_on_exit_disconnects_run_defeated_subscription() -> void:
	# Arrange — navigate (on_enter connects run_defeated).
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Pre-assert: run_defeated is connected while the screen is active.
	assert_bool(
		DungeonRunOrchestrator.run_defeated.is_connected(screen._on_run_defeated)
	).is_true()

	# Act
	screen.on_exit()

	# Assert — run_defeated subscription is disconnected (AC-5 lifecycle hygiene).
	assert_bool(
		DungeonRunOrchestrator.run_defeated.is_connected(screen._on_run_defeated)
	).is_false()

	# Cleanup
	screen.queue_free()
	await get_tree().process_frame
