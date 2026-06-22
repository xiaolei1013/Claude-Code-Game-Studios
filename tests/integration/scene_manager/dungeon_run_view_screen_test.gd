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
const HeroRosterFixture = preload("res://tests/helpers/hero_roster_test_fixture.gd")

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
## Snapshot of HeroRoster state — the party-diorama tests (Story 005) seed a
## known formation; snapshot+restore so the seeding never leaks into the
## orchestrator/lineup tests (feedback_test_isolation_live_autoload memory).
var _hero_roster_snapshot: Dictionary = {}

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

	# Snapshot HeroRoster so the party-diorama tests' formation seeding (Story 005)
	# never leaks into other tests. Restored in after_test.
	_hero_roster_snapshot = HeroRosterFixture.snapshot_via_save_data()


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

	# Restore HeroRoster (party-diorama test isolation, Story 005).
	HeroRosterFixture.restore_via_load_save_data(_hero_roster_snapshot)


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


# ===========================================================================
# Hero Combat Presence — party diorama (GDD #35, Story 005, ADR-0025).
#
# The screen renders one idle-frame-0 sprite per OCCUPIED formation slot in an
# additive, input-transparent PartyDioramaLayer (sibling on the root — NOT a
# reparent of WirePartyHud). The slot COUNT is DATA-DRIVEN from
# HeroRoster.get_formation_heroes() — never hardcoded to 3 (the dominant
# "scaffolded-but-unwired / magic-constant" bug class this epic must avoid).
# Aggregate HP stays the sole HP readout; these sprites are presence only.
#
# Each test reset+seeds a known formation BEFORE navigating (the diorama builds
# in on_enter → _build_wireframe_once, reading the roster at build time). The
# shared before_test/after_test snapshot+restore the live HeroRoster autoload.
# ===========================================================================

func test_party_diorama_layer_present_and_input_transparent() -> void:
	# Arrange — clean roster with one hero so the diorama has something to build.
	HeroRosterFixture.reset_hero_roster()
	var classes: Array[String] = ["warrior"]
	HeroRosterFixture.seed_heroes(classes)

	# Act
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Assert — the additive layer exists, is input-transparent (read-only
	# spectator view — z_index does NOT gate input picking, so the WHOLE subtree
	# must be MOUSE_FILTER_IGNORE), and sits on the sharp z=1 plane (in front of
	# the tilt-shift DoF at z=-1, behind stats/header z=2 + run-end overlay z=5).
	var layer: Control = screen.get_node_or_null("PartyDioramaLayer") as Control
	assert_object(layer).override_failure_message(
		"Story 005 must add a PartyDioramaLayer sibling on the screen root"
	).is_not_null()
	assert_int(layer.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(layer.z_index).is_equal(1)

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_party_diorama_renders_one_sprite_per_occupied_slot_data_driven() -> void:
	# Arrange — a known 3-hero formation (the fixture seeds slots 0..2).
	HeroRosterFixture.reset_hero_roster()
	var classes: Array[String] = ["warrior", "mage", "rogue"]
	HeroRosterFixture.seed_heroes(classes)

	# Act
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer

	# Assert — exactly one slot per occupied formation hero. The expected count is
	# READ FROM the roster (get_formation_heroes().size()), proving the render is
	# data-driven rather than a literal — with a sanity pin that the seed made 3.
	assert_object(row).is_not_null()
	var expected: int = HeroRoster.get_formation_heroes().size()
	assert_int(expected).is_equal(3)
	assert_int(row.get_child_count()).override_failure_message(
		"party diorama must render one sprite per occupied formation slot"
	).is_equal(expected)

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_party_diorama_slot_count_tracks_formation_not_hardcoded() -> void:
	# Arrange — a TWO-hero formation. A hardcoded-3 implementation fails here.
	HeroRosterFixture.reset_hero_roster()
	var classes: Array[String] = ["warrior", "mage"]
	HeroRosterFixture.seed_heroes(classes)

	# Act
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer

	# Assert — two slots, proving the count follows the formation, not a constant.
	assert_object(row).is_not_null()
	assert_int(row.get_child_count()).override_failure_message(
		"diorama slot count must follow the formation size, not a hardcoded 3"
	).is_equal(2)

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_party_diorama_empty_formation_renders_no_slots() -> void:
	# Arrange — empty roster: no heroes recruited, no formation slots filled.
	HeroRosterFixture.reset_hero_roster()

	# Act — must not crash; the layer + row still build but render zero sprites.
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer

	# Assert — the row exists (the diorama scaffolding is always built) with zero
	# hero slots (an empty formation renders nothing — UX spec).
	assert_object(row).is_not_null()
	assert_int(row.get_child_count()).is_equal(0)

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_party_diorama_slot_stashes_class_id_and_loads_idle_frame() -> void:
	# Arrange — a single warrior so we can assert the slot's class binding + art.
	HeroRosterFixture.reset_hero_roster()
	var classes: Array[String] = ["warrior"]
	HeroRosterFixture.seed_heroes(classes)

	# Act
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer
	assert_object(row).is_not_null()
	assert_int(row.get_child_count()).is_equal(1)
	var slot: TextureRect = row.get_child(0) as TextureRect

	# Assert — the slot is a TextureRect, input-transparent, stashes its class_id
	# (so Story 006 can attach the idle animator without re-reading the roster),
	# and shows the warrior idle frame 0 (the committed class sprite.png loads via
	# ResourceLoader — the .ctex is regenerated in CI from the committed PNG).
	assert_object(slot).is_not_null()
	assert_int(slot.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_str(String(slot.get_meta(&"hero_class_id", ""))).is_equal("warrior")
	assert_object(slot.texture).override_failure_message(
		"warrior idle frame 0 should load from assets/art/classes/warrior/sprite.png"
	).is_not_null()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Hero idle animation — looping breathing idle (GDD #35, Story 006, ADR-0025).
#
# Each occupied slot gets a SpriteSheetAnimator child (&"_IdleAnimator", attached
# by ClassSpriteFactory.animate) that cycles the class idle frames from its OWN
# _process. This is the "two clocks, never the tick" rule made concrete: the idle
# loop is a free-running _process on a SEPARATE node, structurally decoupled from
# the 20 Hz `_on_tick_fired` hot path (ADR-0025 §C.9 zero-alloc gate). Story 010
# adds the reduce_motion build-time suppression (§C.8 / AC-35-07): with the flag on,
# _build_party_diorama freezes the idle (set_animating(false)) so each slot holds a
# static frame 0 — heroes stay fully visible, no frame advances. See the
# "reduce_motion suppression sweep" section below for that coverage.
# ===========================================================================

func test_party_diorama_hero_slot_runs_idle_animation() -> void:
	# Arrange — a warrior (its committed 4-frame idle strip > 1 frame → the
	# animator should be live).
	HeroRosterFixture.reset_hero_roster()
	var classes: Array[String] = ["warrior"]
	HeroRosterFixture.seed_heroes(classes)

	# Act
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer
	assert_object(row).is_not_null()
	assert_int(row.get_child_count()).is_equal(1)
	var slot: TextureRect = row.get_child(0) as TextureRect
	assert_object(slot).is_not_null()

	# Assert — Story 006 attached a SpriteSheetAnimator (&"_IdleAnimator") AS A
	# CHILD OF THE SLOT (not the tick path), and it is driving its OWN _process
	# (4 idle frames > 1 → setup() called set_process(true)). The animator being a
	# processing node under the slot IS the "two clocks, never the tick" guarantee.
	var animator: Node = slot.get_node_or_null("_IdleAnimator")
	assert_object(animator).override_failure_message(
		"Story 006 must attach a SpriteSheetAnimator (_IdleAnimator) to each hero slot"
	).is_not_null()
	assert_bool(animator is SpriteSheetAnimator).override_failure_message(
		"the idle animator child must be a SpriteSheetAnimator"
	).is_true()
	assert_bool(animator.is_processing()).override_failure_message(
		"the idle animator should drive its own _process loop (a multi-frame idle)"
	).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_party_diorama_idle_animation_advances_the_frame() -> void:
	# Arrange — a warrior slot with its idle animator.
	HeroRosterFixture.reset_hero_roster()
	var classes: Array[String] = ["warrior"]
	HeroRosterFixture.seed_heroes(classes)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer
	assert_object(row).is_not_null()
	var slot: TextureRect = row.get_child(0) as TextureRect
	assert_object(slot).is_not_null()
	var animator: Node = slot.get_node_or_null("_IdleAnimator")
	assert_object(animator).is_not_null()

	# Pre-assert — the slot currently shows an idle frame.
	var frame_before: Texture2D = slot.texture
	assert_object(frame_before).is_not_null()

	# Act — drive the animator one frame-step deterministically. At IDLE_FPS = 6
	# a frame lasts ~0.167 s; a single 0.2 s step advances exactly one frame
	# (0.2 < 2 × 0.167). We call _process directly so the assertion is timing-
	# independent — no real-frame await race against the engine's own _process.
	animator._process(0.2)

	# Assert — the displayed texture advanced to a DIFFERENT idle frame, proving
	# the loop is live (not a one-shot frame-0 stamp). With a 4-frame strip one
	# step always changes the index ((i+1) % 4 != i), so this holds wherever the
	# free-running loop happened to be when we captured frame_before.
	assert_bool(slot.texture != frame_before).override_failure_message(
		"the idle animator should advance the slot texture past the captured frame"
	).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Story 007 — 20 Hz hot-path zero-(hero-)alloc guard + coarse run-state reflection
# (GDD #35 §C.9 / AC-35-06 [BLOCKING] / ADR-0025).
#
# AC-35-06 [BLOCKING]: as Stories 005/006/007 put heroes + animators on screen,
# `_on_tick_fired` must add NO hero-animation work (no tween, node creation,
# factory idle-attach, diorama walk, or per-hero roster read). The idle loop is a
# free-running _process on each SpriteSheetAnimator; coarse run-state changes (e.g.
# RUN_ENDED freezing the idle) ride human-frequency signals — never the tick.
#
# tests/perf/ is NOT in CI, and a timing test cannot prove the ABSENCE of allocation
# on a UI screen. So the CI-blocking form of the "Story-012 per-tick budget test" is
# this SOURCE-level guard: assert the hot-path function body contains none of the
# hero/alloc tokens — proving the decoupling structurally + deterministically.
# Mirrors the existing manifest greps (no change_scene / no Color literal above).
# ===========================================================================

## Extracts the source lines of [param func_name]'s body from [param gd_path],
## stripping inline comments so comment prose cannot trip a token check. The body
## runs from the line after the `func` signature up to the next column-0 `func` or
## `#` (section separator / next doc block) — every in-body statement is indented,
## so a column-0 hash reliably marks the end of the body in this file's style.
func _extract_function_body(gd_path: String, func_name: String) -> String:
	var fa: FileAccess = FileAccess.open(gd_path, FileAccess.READ)
	if fa == null:
		return ""
	var signature: String = "func %s(" % func_name
	var body: String = ""
	var inside: bool = false
	while not fa.eof_reached():
		var line: String = fa.get_line()
		if inside:
			# A column-0 `func`/`#` ends the body (every body statement is indented).
			if line.begins_with("func ") or line.begins_with("#"):
				break
			body += line.split("#")[0] + "\n"
		elif line.begins_with(signature):
			inside = true
	fa.close()
	return body


func test_on_tick_fired_adds_no_hero_animation_work() -> void:
	# AC-35-06 [BLOCKING]: the 20 Hz hot path must gain NO hero/animation work.
	# Arrange — extract the live `_on_tick_fired` body from the screen source.
	var body: String = _extract_function_body(DUNGEON_RUN_VIEW_GD_PATH, "_on_tick_fired")
	assert_bool(body.is_empty()).override_failure_message(
		"could not locate _on_tick_fired in %s" % DUNGEON_RUN_VIEW_GD_PATH
	).is_false()

	# Hot-path ops that animating the heroes must NEVER introduce into the tick.
	# Each would mean per-hero / animation work leaked onto the 20 Hz tick (§C.9).
	var forbidden: Array[String] = [
		"create_tween",         # no tween allocation on the tick
		".new(",                # no object / node construction
		"add_child",            # no node creation
		"animate(",             # no ClassSpriteFactory idle-attach
		"set_animating",        # the run-state reflection is human-frequency, not the tick
		"_set_party_idle",      # ditto — the diorama-walk helper
		"_party_diorama",       # no diorama node access
		"_make_hero_slot",      # no slot building
		"get_idle_frames",      # no frame slicing
		"get_formation_heroes", # no per-hero roster walk
		"_IdleAnimator",        # no animator lookup
	]

	# Assert — none of the forbidden hero/alloc tokens appear in the tick body.
	var violations: Array[String] = []
	for token: String in forbidden:
		if body.contains(token):
			violations.append(token)
	assert_int(violations.size()).override_failure_message(
		"_on_tick_fired (20 Hz hot path) must add no hero-animation work " +
		"(ADR-0025 §C.9 / AC-35-06) — found forbidden token(s): %s" % str(violations)
	).is_equal(0)


func test_run_ended_freezes_party_idle_animation() -> void:
	# Coarse run-state reflection (GDD #35 §C.4): entering RUN_ENDED freezes every
	# hero's idle loop — on a human-frequency signal, not the tick.
	# Arrange — a two-warrior party (committed 4-frame art → live animators).
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer
	assert_object(row).is_not_null()
	assert_int(row.get_child_count()).is_equal(2)

	# Precondition — both idle animators are running after on_enter (Story 006).
	for slot: Node in row.get_children():
		var anim_pre: Node = slot.get_node_or_null("_IdleAnimator")
		assert_object(anim_pre).is_not_null()
		assert_bool(anim_pre.is_processing()).override_failure_message(
			"the idle animator should be live before the run ends"
		).is_true()

	# Act — drive the RUN_ENDED transition through the REAL handler. Pre-set _routed
	# so the handler runs the §C.4 freeze then short-circuits before the overlay /
	# dwell-await / route — isolating the reflection (and proving the freeze is NOT
	# gated by the idempotency guard: it must fire even on a replayed RUN_ENDED).
	screen._routed = true
	screen._on_state_changed(
		DungeonRunStateScript.State.RUN_ENDED,
		DungeonRunStateScript.State.ACTIVE_FOREGROUND)

	# Assert — every hero idle is now frozen (the held pose for the run-end overlay).
	for slot: Node in row.get_children():
		var anim_post: Node = slot.get_node_or_null("_IdleAnimator")
		assert_object(anim_post).is_not_null()
		assert_bool(anim_post.is_processing()).override_failure_message(
			"RUN_ENDED must freeze every hero idle loop (GDD #35 §C.4 baseline transition)"
		).is_false()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Story 008 — kill / boss reaction beats (GDD #35 §C.4 / §D.5, ADR-0025).
#
# A normal kill (enemy_killed) and a boss kill (boss_killed) — BOTH human-frequency
# orchestrator signals, NEVER the 20 Hz tick — punch + brightness-flash the whole
# party diorama via a create_tween() beat (party-aggregate; GDD §C.5 / OQ-35-1).
# The Story 007 source guard (test_on_tick_fired_adds_no_hero_animation_work) already
# proves no beat work leaks onto the tick; these tests pin the BEAT path itself:
#   • wiring hygiene — connected on_enter, disconnected on_exit
#   • plays when motion is enabled (kill + boss)
#   • suppressed by reduce_motion, read AT BEAT TIME (ADR-0025 §C.8; precedent AC-PR-18)
#   • coalesced within BEAT_THROTTLE_MS (anti-strobe, §D.5) via the injectable clock seam
#   • suppressed for an empty party (no slots to animate)
#   • end-to-end: emitting enemy_killed routes through the connection to a real beat
#   • lifecycle: on_exit kills the active beat tween (no tween outlives the screen)
#
# The tween's internal phase shape (out-punch → settle) is cosmetic/advisory and is
# NOT pinned here — these target the GATING logic + lifecycle (ADR-0025 validation).
# ===========================================================================

## Drives one normal-kill beat through the gated entry point and returns whether a
## tween was actually started. Pulls the real KILL_BEAT_* constants from the screen
## script (get_script_constant_map) so the test never hardcodes the punch/duration —
## only the CLOCK + reduce_motion gates are under test here, not the tween's shape.
func _kill_beat_gate(screen: Control) -> bool:
	var consts: Dictionary = screen.get_script().get_script_constant_map()
	return screen._try_party_strike_beat(
		float(consts["KILL_BEAT_SCALE_PUNCH"]), int(consts["KILL_BEAT_MS"]))


func test_kill_and_boss_beats_connected_on_enter_disconnected_on_exit() -> void:
	# Arrange — navigate (on_enter connects both reaction-beat handlers).
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Pre-assert: both beats are wired while the screen is active. enemy_killed has
	# TWO distinct consumers (the existing gold-burst VFX + this new hero beat); we
	# guard the BEAT connection specifically (the scaffolded-but-unwired net).
	assert_bool(
		DungeonRunOrchestrator.enemy_killed.is_connected(screen._on_enemy_killed_beat)
	).override_failure_message(
		"enemy_killed must drive the hero strike beat while dungeon_run_view is active"
	).is_true()
	assert_bool(
		DungeonRunOrchestrator.boss_killed.is_connected(screen._on_boss_killed_beat)
	).override_failure_message(
		"boss_killed must drive the hero strike beat while dungeon_run_view is active"
	).is_true()

	# Act
	screen.on_exit()

	# Assert — both subscriptions disconnected (no orphaned connection / leak).
	assert_bool(
		DungeonRunOrchestrator.enemy_killed.is_connected(screen._on_enemy_killed_beat)
	).is_false()
	assert_bool(
		DungeonRunOrchestrator.boss_killed.is_connected(screen._on_boss_killed_beat)
	).is_false()

	# Cleanup
	screen.queue_free()
	await get_tree().process_frame


func test_enemy_kill_beat_starts_strike_tween_when_motion_enabled() -> void:
	# Arrange — a two-warrior party so the diorama has slots to animate.
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# reduce_motion OFF so the beat is allowed; deterministic clock so the throttle
	# never interferes (first beat always clears the -BEAT_THROTTLE_MS init).
	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)
	screen._beat_clock_override_ms = 1000

	# Pre-assert: no beat tween yet.
	assert_object(screen._active_beat_tween).is_null()

	# Act — a normal kill arrives via the real handler.
	screen._on_enemy_killed_beat(1, "goblin", false)

	# Assert — a live beat tween was created for the party (cosmetic shape unchecked).
	assert_object(screen._active_beat_tween).override_failure_message(
		"a normal kill should start a party strike-beat tween when motion is enabled"
	).is_not_null()
	assert_bool(screen._active_beat_tween.is_valid()).is_true()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_boss_kill_beat_starts_strike_tween_when_motion_enabled() -> void:
	# Arrange — a two-warrior party.
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)
	screen._beat_clock_override_ms = 1000

	# Act — a boss kill arrives via the real handler.
	screen._on_boss_killed_beat("forest_warden")

	# Assert — a live beat tween was created (the boss beat shares the gated path).
	assert_object(screen._active_beat_tween).override_failure_message(
		"a boss kill should start a party strike-beat tween when motion is enabled"
	).is_not_null()
	assert_bool(screen._active_beat_tween.is_valid()).is_true()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_strike_beat_suppressed_when_reduce_motion_enabled() -> void:
	# Arrange — a party present (so the empty-party gate is NOT what suppresses).
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	screen._beat_clock_override_ms = 1000

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	assert_object(sm).is_not_null()
	var prior_rm: bool = bool(sm.get("reduce_motion"))

	# Act + Assert (suppressed) — reduce_motion ON: the gate returns false, reads the
	# flag AT BEAT TIME (ADR-0025 §C.8), and starts NO tween. A suppressed beat must
	# also leave the throttle clock untouched so it never "uses up" the window.
	sm.set("reduce_motion", true)
	assert_bool(_kill_beat_gate(screen)).override_failure_message(
		"reduce_motion must suppress the strike beat (no tween)"
	).is_false()
	assert_object(screen._active_beat_tween).is_null()

	# Act + Assert (allowed) — flip reduce_motion OFF at the SAME clock: the beat now
	# fires, proving reduce_motion (not the clock / slots) was the gate. The suppressed
	# call above did not stamp _last_beat_ms, so the init window still clears here.
	sm.set("reduce_motion", false)
	assert_bool(_kill_beat_gate(screen)).override_failure_message(
		"clearing reduce_motion must let the strike beat fire at the same clock"
	).is_true()
	assert_object(screen._active_beat_tween).is_not_null()

	# Cleanup
	sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_strike_beats_coalesce_within_throttle_window() -> void:
	# Anti-strobe coalescing (GDD #35 §D.5): a new beat is suppressed if the previous
	# VISIBLE beat began < BEAT_THROTTLE_MS ago, measured on the injectable clock seam.
	# Arrange — party present, reduce_motion OFF (isolate the CLOCK gate).
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)

	# Sanity pin: the 1119/1120 boundary below is derived from a 120 ms window. If the
	# throttle is ever retuned, this pin flags that the boundary values need updating.
	var consts: Dictionary = screen.get_script().get_script_constant_map()
	assert_int(int(consts["BEAT_THROTTLE_MS"])).is_equal(120)

	# Act + Assert — t=1000: first beat fires (clears the -120 init window).
	screen._beat_clock_override_ms = 1000
	assert_bool(_kill_beat_gate(screen)).override_failure_message(
		"the first beat must fire (no prior visible beat within the window)"
	).is_true()

	# t=1119: 119 ms later (< 120) — coalesced away (anti-strobe).
	screen._beat_clock_override_ms = 1119
	assert_bool(_kill_beat_gate(screen)).override_failure_message(
		"a beat 119 ms after the last must be suppressed (within the 120 ms window)"
	).is_false()

	# t=1120: exactly 120 ms after the FIRST visible beat (the suppressed one did not
	# move the clock) — the window has elapsed, so this beat fires again.
	screen._beat_clock_override_ms = 1120
	assert_bool(_kill_beat_gate(screen)).override_failure_message(
		"a beat exactly 120 ms after the last visible beat must fire again"
	).is_true()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_strike_beat_suppressed_for_empty_party() -> void:
	# Arrange — an EMPTY roster: the diorama row builds but holds zero hero slots.
	HeroRosterFixture.reset_hero_roster()
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Motion ON + a clear clock so neither reduce_motion nor the throttle is the gate.
	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)
	screen._beat_clock_override_ms = 1000

	# Act + Assert — with no slots to animate, the beat is a no-op (false, no tween).
	assert_bool(_kill_beat_gate(screen)).override_failure_message(
		"an empty party must not start a beat tween (nothing to animate)"
	).is_false()
	assert_object(screen._active_beat_tween).is_null()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_enemy_killed_signal_emission_triggers_beat_end_to_end() -> void:
	# End-to-end: the on_enter CONNECTION must actually route a live enemy_killed
	# emission to a real beat (not just be wired in isolation).
	# Arrange — party present, motion ON, deterministic clock.
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)
	screen._beat_clock_override_ms = 1000

	# Act — emit the orchestrator signal exactly as combat does (tier, archetype,
	# advantaged). The screen's connected handler must turn this into a beat.
	DungeonRunOrchestrator.enemy_killed.emit(1, "goblin", false)
	await get_tree().process_frame

	# Assert — a live beat tween exists, proving the signal → handler → tween path.
	assert_object(screen._active_beat_tween).override_failure_message(
		"emitting enemy_killed should route through the connection to a real beat"
	).is_not_null()
	assert_bool(screen._active_beat_tween.is_valid()).is_true()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_on_exit_kills_active_beat_tween() -> void:
	# Lifecycle hygiene (ADR-0025): no beat tween may outlive the screen.
	# Arrange — a party + a started beat.
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)
	screen._beat_clock_override_ms = 1000
	screen._on_enemy_killed_beat(1, "goblin", false)
	assert_object(screen._active_beat_tween).override_failure_message(
		"precondition: a beat tween should be active before on_exit"
	).is_not_null()

	# Act — leave the screen.
	screen.on_exit()

	# Assert — the active beat tween was killed AND the handle cleared (no dangling
	# tween fighting the next screen's transforms / no leak on a freed screen).
	assert_object(screen._active_beat_tween).override_failure_message(
		"on_exit must kill and clear the active beat tween"
	).is_null()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Story 009 — terminal reaction beats: victory cheer / defeat slump
# (GDD #35 §C.4 / §D.2 / §D.4 / §E.5 / §E.7 / §E.9 / §E.11 / §H, ADR-0025 / ADR-0021).
#
# The run's two punctuation moments, each on a HUMAN-FREQUENCY orchestrator signal
# (NEVER the 20 Hz tick — the Story 007 source guard already proves the tick stays
# clean):
#   • floor_cleared_first_time (losing_run == false) → VICTORY cheer (out-and-back)
#   • run_defeated                                   → DEFEAT slump (one-way, held)
# Both animate the hero SPRITES only and NEVER route — the route + idle-freeze stay
# with _on_state_changed(RUN_ENDED) (§E.5: the slump is "not a second independent
# route decision"). These tests pin: wiring hygiene; the beat plays / is suppressed
# under the documented gates; the precedence latch (victory>boss>kill, §E.9); the
# duration cap (< RUN_END_DWELL_MS so the beat completes under the overlay, AC-35-04);
# reduce_motion read AT BEAT TIME with the defeat slump shown as an INSTANT static
# pose (heroes visible + dimmed, §C.8); and the empty-party no-op (§E.7). Tween
# internal shape is cosmetic/advisory and is NOT pinned (Story 008 precedent).
# ===========================================================================

func test_terminal_beats_connected_on_enter_disconnected_on_exit() -> void:
	# Wiring hygiene (the scaffolded-but-unwired net). Arrange — navigate (on_enter
	# connects both terminal-beat handlers).
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Pre-assert: both terminal beats are wired. Each signal has TWO consumers now
	# (floor_cleared_first_time → glow VFX + this victory beat; run_defeated → the
	# defeat overlay + this slump beat); guard the BEAT connections specifically.
	assert_bool(
		DungeonRunOrchestrator.floor_cleared_first_time.is_connected(screen._on_floor_cleared_beat)
	).override_failure_message(
		"floor_cleared_first_time must drive the hero victory beat while dungeon_run_view is active"
	).is_true()
	assert_bool(
		DungeonRunOrchestrator.run_defeated.is_connected(screen._on_run_defeated_beat)
	).override_failure_message(
		"run_defeated must drive the hero defeat slump while dungeon_run_view is active"
	).is_true()

	# Act
	screen.on_exit()

	# Assert — both subscriptions disconnected (no orphaned connection / leak).
	assert_bool(
		DungeonRunOrchestrator.floor_cleared_first_time.is_connected(screen._on_floor_cleared_beat)
	).is_false()
	assert_bool(
		DungeonRunOrchestrator.run_defeated.is_connected(screen._on_run_defeated_beat)
	).is_false()

	# Cleanup
	screen.queue_free()
	await get_tree().process_frame


func test_victory_beat_plays_on_floor_cleared_and_does_not_route() -> void:
	# AC-35-04 [BLOCKING]: a first-time floor clear plays the victory cheer. The beat
	# animates the heroes ONLY — it must NOT show the run-end overlay or route (those stay
	# with _on_state_changed, §E.5). Arrange — a two-warrior party, motion ON.
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)

	# Pre-assert: clean slate — no beat, not routed, no overlay, latch clear.
	assert_object(screen._active_beat_tween).is_null()
	assert_bool(screen._routed).is_false()
	assert_bool(screen._overlay_shown).is_false()
	assert_bool(screen._terminal_beat_played).is_false()

	# Act — a first-time floor clear arrives via the real handler (winning run).
	screen._on_floor_cleared_beat(2, "forest_reach", false)

	# Assert — a live victory tween was started (cosmetic shape unchecked)...
	assert_object(screen._active_beat_tween).override_failure_message(
		"a first-time floor clear should start a victory cheer tween when motion is enabled"
	).is_not_null()
	assert_bool(screen._active_beat_tween.is_valid()).is_true()
	# ...the latch is set (this run's terminal motion has played)...
	assert_bool(screen._terminal_beat_played).is_true()
	# ...but the beat is NOT a route decision: no overlay shown, not routed (§E.5).
	assert_bool(screen._routed).override_failure_message(
		"the victory beat must NOT route — that stays with _on_state_changed(RUN_ENDED)"
	).is_false()
	assert_bool(screen._overlay_shown).override_failure_message(
		"the victory beat must NOT show the run-end overlay — that stays with _on_state_changed"
	).is_false()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_terminal_beat_durations_complete_within_run_end_dwell() -> void:
	# AC-35-04 / AC-35-05: both terminal beats must complete UNDER the run-end overlay,
	# before the auto-route fires — i.e. each duration < RUN_END_DWELL_MS (the dwell the
	# route awaits). A pure constant-relationship pin (no scene needed); flags a retune that
	# would let a beat outlive the dwell and get cut off by the screen change.
	var script: GDScript = load(DUNGEON_RUN_VIEW_GD_PATH) as GDScript
	assert_object(script).is_not_null()
	var consts: Dictionary = script.get_script_constant_map()
	var victory_ms: int = int(consts["VICTORY_BEAT_MS"])
	var slump_ms: int = int(consts["DEFEAT_SLUMP_MS"])
	var dwell_ms: int = int(consts["RUN_END_DWELL_MS"])

	assert_int(dwell_ms).override_failure_message(
		"RUN_END_DWELL_MS (%d) must exceed VICTORY_BEAT_MS (%d) so the cheer completes under the overlay" % [dwell_ms, victory_ms]
	).is_greater(victory_ms)
	assert_int(dwell_ms).override_failure_message(
		"RUN_END_DWELL_MS (%d) must exceed DEFEAT_SLUMP_MS (%d) so the slump completes under the overlay" % [dwell_ms, slump_ms]
	).is_greater(slump_ms)


func test_losing_run_floor_clear_plays_no_victory_and_does_not_latch() -> void:
	# A floor cleared on a LOSING run earns no celebration (it stays the retry target),
	# mirroring the lantern-glow VFX gate — AND must NOT latch, so the run_defeated slump
	# that follows still plays (bug guard: a losing clear silently eating the slump).
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)

	# Act 1 — a first-time floor clear on a LOSING run.
	screen._on_floor_cleared_beat(2, "forest_reach", true)

	# Assert — no victory tween, and the latch is still clear.
	assert_object(screen._active_beat_tween).override_failure_message(
		"a losing-run floor clear must not play a victory cheer"
	).is_null()
	assert_bool(screen._terminal_beat_played).override_failure_message(
		"a losing-run floor clear must NOT latch — the run_defeated slump must still be able to play"
	).is_false()

	# Act 2 — the run is then lost: the slump must play (the latch was left clear).
	screen._on_run_defeated_beat(2, "forest_reach")
	assert_object(screen._active_beat_tween).override_failure_message(
		"after a losing-run floor clear, run_defeated must still play the defeat slump"
	).is_not_null()
	assert_bool(screen._active_beat_tween.is_valid()).is_true()
	assert_bool(screen._terminal_beat_played).is_true()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_defeat_slump_plays_on_run_defeated_coordinated_with_overlay_no_route() -> void:
	# AC-35-05 [BLOCKING]: run_defeated plays the defeat slump, coordinated WITH the defeat
	# overlay (both consume run_defeated), and the slump is NOT a route decision (§E.5) — the
	# route stays with _on_state_changed(RUN_ENDED). End-to-end: emit the REAL signal so BOTH
	# connected consumers fire (overlay + slump), proving the on_enter connection routes it.
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)

	# Pre-assert: clean slate.
	assert_object(screen._active_beat_tween).is_null()
	assert_bool(screen._overlay_shown).is_false()
	assert_bool(screen._routed).is_false()

	# Act — the run is lost (emit exactly as the orchestrator does, just before RUN_ENDED).
	DungeonRunOrchestrator.run_defeated.emit(4, "crypt_depths")
	await get_tree().process_frame

	# Assert — the slump tween plays (signal → _on_run_defeated_beat → tween)...
	assert_object(screen._active_beat_tween).override_failure_message(
		"run_defeated should route through the connection to a real defeat slump tween"
	).is_not_null()
	assert_bool(screen._active_beat_tween.is_valid()).is_true()
	# ...coordinated WITH the defeat overlay (the other run_defeated consumer fired)...
	assert_bool(screen._overlay_shown).override_failure_message(
		"the defeat slump must be coordinated with the defeat overlay (both consume run_defeated)"
	).is_true()
	# ...and the slump is NOT a route decision (§E.5): _on_state_changed owns the route.
	assert_bool(screen._routed).override_failure_message(
		"the defeat slump must NOT route — that is _on_state_changed(RUN_ENDED)'s job (no double-route)"
	).is_false()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_victory_supersedes_boss_strike_then_latch_blocks_late_kill() -> void:
	# AC-35-13 [BLOCKING]: a boss strike then a first-time floor clear → the victory cheer
	# SUPERSEDES the in-flight boss beat (only ONE terminal motion, §E.9 victory>boss>kill);
	# a kill arriving AFTER is then suppressed by the terminal latch (no late strike overrides
	# the terminal motion). Arrange — party present, motion ON, deterministic clock.
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)
	screen._beat_clock_override_ms = 1000

	# Act 1 — a boss kill starts a strike beat.
	screen._on_boss_killed_beat("forest_warden")
	var boss_tween: Tween = screen._active_beat_tween
	assert_object(boss_tween).override_failure_message(
		"precondition: the boss kill should start a strike beat"
	).is_not_null()
	assert_bool(boss_tween.is_valid()).is_true()

	# Act 2 — a first-time floor clear: the victory cheer supersedes the boss strike.
	screen._on_floor_cleared_beat(3, "forest_reach", false)

	# Assert — the boss tween was KILLED and a DIFFERENT (victory) tween is now active.
	assert_bool(boss_tween.is_valid()).override_failure_message(
		"the victory cheer must supersede (kill) the in-flight boss strike (§E.9)"
	).is_false()
	assert_object(screen._active_beat_tween).is_not_null()
	assert_bool(screen._active_beat_tween.is_valid()).is_true()
	assert_bool(screen._active_beat_tween != boss_tween).override_failure_message(
		"the active tween after victory must be the new cheer, not the killed boss beat"
	).is_true()
	var victory_tween: Tween = screen._active_beat_tween

	# Act 3 — a late normal kill arrives AFTER the terminal beat. Advance the clock well past
	# the throttle so coalescing can NOT be the gate — isolating the latch as the suppressor.
	screen._beat_clock_override_ms = 5000
	screen._on_enemy_killed_beat(1, "goblin", false)

	# Assert — the late kill did nothing: the victory tween is untouched (still the active one).
	assert_bool(screen._active_beat_tween == victory_tween).override_failure_message(
		"a kill after the terminal beat must be suppressed by the latch — the victory tween stays active"
	).is_true()
	assert_bool(screen._active_beat_tween.is_valid()).is_true()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_victory_beat_suppressed_by_reduce_motion_heroes_stay_visible() -> void:
	# AC-35-07/08: reduce_motion suppresses the victory cheer (no tween); the heroes stay
	# visible (a victory's terminal state IS rest — nothing to apply). reduce_motion is set
	# AFTER on_enter, so the beat reading it true also proves the read-at-beat-time (suppress
	# direction). Arrange — party present so the empty-party gate is NOT what suppresses.
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	assert_object(sm).is_not_null()
	var prior_rm: bool = bool(sm.get("reduce_motion"))
	sm.set("reduce_motion", true)

	# Act — a first-time floor clear under reduce_motion.
	screen._on_floor_cleared_beat(2, "forest_reach", false)

	# Assert — NO tween (suppressed), latch still set (the terminal moment happened), and
	# every hero stays fully visible at rest (alpha 1.0).
	assert_object(screen._active_beat_tween).override_failure_message(
		"reduce_motion must suppress the victory tween (no animation)"
	).is_null()
	assert_bool(screen._terminal_beat_played).is_true()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer
	assert_object(row).is_not_null()
	for slot: Node in row.get_children():
		var c: Control = slot as Control
		assert_float(c.modulate.a).override_failure_message(
			"heroes must stay fully visible under reduce_motion (no fade)"
		).is_equal(1.0)

	# Cleanup
	sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_defeat_slump_static_under_reduce_motion_visible_and_dimmed() -> void:
	# §C.8 / AC-35-07/08: under reduce_motion the defeat slump is shown as an INSTANT static
	# pose — NO tween, but the terminal STATE is applied (heroes sit slumped + dimmed) and
	# they stay VISIBLE (alpha 1.0; never a fade-to-nothing). Arrange — party present.
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	assert_object(sm).is_not_null()
	var prior_rm: bool = bool(sm.get("reduce_motion"))
	sm.set("reduce_motion", true)

	# Pull the slump constants so the test never hardcodes the pose values.
	var consts: Dictionary = screen.get_script().get_script_constant_map()
	var slump_x: float = float(consts["DEFEAT_SLUMP_SCALE_X"])
	var slump_y: float = float(consts["DEFEAT_SLUMP_SCALE_Y"])
	var dim: float = float(consts["DEFEAT_SLUMP_DIM"])

	# Act — the run is lost under reduce_motion.
	screen._on_run_defeated_beat(4, "crypt_depths")

	# Assert — NO tween (static path), but the slump pose IS applied + heroes stay visible.
	assert_object(screen._active_beat_tween).override_failure_message(
		"reduce_motion must NOT animate the slump (no tween) — it applies a static pose (§C.8)"
	).is_null()
	assert_bool(screen._terminal_beat_played).is_true()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer
	assert_object(row).is_not_null()
	for slot: Node in row.get_children():
		var c: Control = slot as Control
		assert_float(c.scale.x).override_failure_message(
			"the static slump must apply the slump X-scale instantly"
		).is_equal_approx(slump_x, 0.001)
		assert_float(c.scale.y).override_failure_message(
			"the static slump must apply the slump Y-scale instantly"
		).is_equal_approx(slump_y, 0.001)
		assert_float(c.modulate.r).override_failure_message(
			"the static slump must dim the heroes (modulate < 1.0)"
		).is_equal_approx(dim, 0.001)
		assert_float(c.modulate.a).override_failure_message(
			"the slumped party must stay visible (alpha 1.0) — never a fade (§C.8)"
		).is_equal(1.0)

	# Cleanup
	sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_terminal_beat_reads_reduce_motion_at_beat_time_not_on_enter() -> void:
	# ADR-0025 §C.8 / AC-35-08 (allow direction): the flag is read AT BEAT TIME, never cached
	# at on_enter. Navigate with reduce_motion ON, then CLEAR it: the victory cheer must
	# ANIMATE — proving the beat read the LIVE (false) value, not the on_enter (true) value
	# (which would have suppressed it).
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)

	var sm: Node = get_node_or_null("/root/SceneManager")
	assert_object(sm).is_not_null()
	var prior_rm: bool = bool(sm.get("reduce_motion"))
	sm.set("reduce_motion", true)  # ON for the whole of on_enter

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	# Flip OFF after on_enter, then fire the beat.
	sm.set("reduce_motion", false)
	screen._on_floor_cleared_beat(2, "forest_reach", false)

	# Assert — the beat ANIMATED (read reduce_motion=false at beat time, not the cached true).
	assert_object(screen._active_beat_tween).override_failure_message(
		"the terminal beat must read reduce_motion AT BEAT TIME — clearing it after on_enter must let the cheer animate"
	).is_not_null()
	assert_bool(screen._active_beat_tween.is_valid()).is_true()

	# Cleanup
	sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_terminal_beats_no_op_for_empty_party() -> void:
	# §E.7: a terminal beat on an EMPTY party is a no-op (no tween, no crash) — the diorama
	# row exists but holds zero hero slots. Covers BOTH victory and defeat.
	HeroRosterFixture.reset_hero_roster()
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)

	# Act + Assert — victory on an empty party: no tween.
	screen._on_floor_cleared_beat(2, "forest_reach", false)
	assert_object(screen._active_beat_tween).override_failure_message(
		"an empty party must not start a victory tween (nothing to animate)"
	).is_null()

	# Reset the latch so the defeat path is reachable in the same test (a run cannot both
	# win and lose; we reset only to exercise the empty-party gate on BOTH terminal paths).
	screen._terminal_beat_played = false

	# Act + Assert — defeat on an empty party: no tween, no crash.
	screen._on_run_defeated_beat(2, "forest_reach")
	assert_object(screen._active_beat_tween).override_failure_message(
		"an empty party must not start a defeat slump tween (nothing to animate)"
	).is_null()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_on_exit_kills_active_terminal_beat_tween() -> void:
	# Lifecycle hygiene (ADR-0025 §C.7): a terminal beat shares the _active_beat_tween handle,
	# so on_exit must kill + clear it too (no victory/slump tween outlives the screen).
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()

	var sm: Node = screen.get_node_or_null("/root/SceneManager")
	var prior_rm: bool = bool(sm.get("reduce_motion")) if sm != null else false
	if sm != null:
		sm.set("reduce_motion", false)

	# Arrange — a started victory tween.
	screen._on_floor_cleared_beat(2, "forest_reach", false)
	assert_object(screen._active_beat_tween).override_failure_message(
		"precondition: a victory tween should be active before on_exit"
	).is_not_null()

	# Act — leave the screen.
	screen.on_exit()

	# Assert — the active terminal tween was killed AND the handle cleared.
	assert_object(screen._active_beat_tween).override_failure_message(
		"on_exit must kill and clear the active terminal beat tween"
	).is_null()

	# Cleanup
	if sm != null:
		sm.set("reduce_motion", prior_rm)
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# reduce_motion suppression sweep — Story 010 (GDD #35 §C.8 / AC-35-07, AC-35-08).
#
# The single, consolidated guarantee: when reduce_motion is ON, NO hero-animation
# surface moves. Every surface is covered by an individual gate already (the idle at
# build time, the strike/boss/terminal beats at beat time); this section asserts the
# WHOLE set together so no future surface can be added without a reduce_motion gate.
#
# Invariants under reduce_motion:
#   • Idle loop frozen — each _IdleAnimator has _process disabled and holds frame 0.
#   • Strike + boss beats suppressed — _try_party_strike_beat returns false, no tween.
#   • Terminal beats suppressed — victory/defeat apply INSTANT state, never a tween.
#   • Heroes stay FULLY PRESENT and VISIBLE (all K slots, modulate.a == 1.0) — the
#     accessibility contract removes motion, NEVER the party (§C.8).
# ===========================================================================

func test_reduce_motion_idle_suppressed_static_and_heroes_visible() -> void:
	# AC-35-07 (idle core): reduce_motion ON at build → every hero holds a single static
	# frame (frame 0, _process disabled) yet stays fully present and visible. A 3-warrior
	# party so we also prove the data-driven count (all K=3 slots) survives suppression.
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(3)

	var sm: Node = get_node_or_null("/root/SceneManager")
	assert_object(sm).is_not_null()
	var prior_rm: bool = bool(sm.get("reduce_motion"))
	sm.set("reduce_motion", true)  # ON before on_enter builds the diorama

	# Act — navigate (on_enter → _build_party_diorama reads reduce_motion at build time).
	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer
	assert_object(row).is_not_null()

	# Assert — all K slots present, each frozen on a static frame 0, fully visible.
	assert_int(row.get_child_count()).override_failure_message(
		"reduce_motion must NOT drop heroes — all 3 occupied slots stay present (§C.8)"
	).is_equal(3)
	for slot: Node in row.get_children():
		var animator: SpriteSheetAnimator = slot.get_node_or_null(
			"_IdleAnimator") as SpriteSheetAnimator
		assert_object(animator).override_failure_message(
			"a committed-art warrior must still get its idle animator (just frozen)"
		).is_not_null()
		assert_bool(animator.is_processing()).override_failure_message(
			"reduce_motion must disable the idle animator's _process (no looping idle)"
		).is_false()
		assert_int(animator._idx).override_failure_message(
			"a frozen idle must hold the single static frame 0 (no frame ever advanced)"
		).is_equal(0)
		var c: Control = slot as Control
		assert_float(c.modulate.a).override_failure_message(
			"heroes must remain fully visible under reduce_motion (alpha 1.0, never faded)"
		).is_equal(1.0)

	# Cleanup
	sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_reduce_motion_full_sweep_no_surface_animates_heroes_visible() -> void:
	# AC-35-07 (anchor): the consolidated guarantee — under reduce_motion NO surface moves.
	# Exercise idle + strike + boss + victory in one run and assert each is inert (frozen /
	# no tween), then assert every hero is still fully visible. Strike + boss fire BEFORE the
	# terminal beat so the terminal latch is clear and reduce_motion (gate 1) is provably the
	# suppressor — not the latch (gate 0).
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(2)

	var sm: Node = get_node_or_null("/root/SceneManager")
	assert_object(sm).is_not_null()
	var prior_rm: bool = bool(sm.get("reduce_motion"))
	sm.set("reduce_motion", true)

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	screen._beat_clock_override_ms = 1000  # deterministic clock; RM, not the throttle, is the gate

	# (1) Idle frozen at build.
	for slot: Node in screen._party_hero_slots():
		var animator: SpriteSheetAnimator = slot.get_node_or_null(
			"_IdleAnimator") as SpriteSheetAnimator
		assert_object(animator).is_not_null()
		assert_bool(animator.is_processing()).override_failure_message(
			"reduce_motion must freeze the idle loop (sweep: idle surface)"
		).is_false()

	# (2) Normal-kill strike beat suppressed (latch clear → RM is the gate).
	assert_bool(_kill_beat_gate(screen)).override_failure_message(
		"reduce_motion must suppress the strike beat (sweep: enemy_killed surface)"
	).is_false()
	assert_object(screen._active_beat_tween).is_null()

	# (3) Boss-kill strike beat suppressed.
	screen._on_boss_killed_beat("forest_warden")
	assert_object(screen._active_beat_tween).override_failure_message(
		"reduce_motion must suppress the boss strike beat (sweep: boss_killed surface)"
	).is_null()

	# (4) Victory terminal beat suppressed — instant, no tween (latch now sets).
	screen._on_floor_cleared_beat(2, "forest_reach", false)
	assert_object(screen._active_beat_tween).override_failure_message(
		"reduce_motion must suppress the victory cheer (sweep: terminal surface)"
	).is_null()
	assert_bool(screen._terminal_beat_played).is_true()

	# (5) After the full sweep, every hero is still fully present and visible.
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer
	assert_object(row).is_not_null()
	assert_int(row.get_child_count()).is_equal(2)
	for slot: Node in row.get_children():
		assert_float((slot as Control).modulate.a).override_failure_message(
			"no suppressed surface may fade the heroes — alpha stays 1.0 (§C.8)"
		).is_equal(1.0)

	# Cleanup
	sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


func test_idle_animates_when_motion_enabled_gate_is_conditional() -> void:
	# Negative control for the Story 010 build gate: with reduce_motion explicitly OFF, the
	# idle MUST animate (every animator processing). Pairs with the suppression test above to
	# prove the gate is CONDITIONAL on reduce_motion — a guard against anyone inverting or
	# unconditionally applying the freeze (which would silently kill the idle for everyone).
	HeroRosterFixture.reset_hero_roster()
	HeroRosterFixture.seed_warriors(3)

	var sm: Node = get_node_or_null("/root/SceneManager")
	assert_object(sm).is_not_null()
	var prior_rm: bool = bool(sm.get("reduce_motion"))
	sm.set("reduce_motion", false)  # explicitly OFF — the gate must NOT fire

	var screen: Control = await _navigate_to_dungeon_run_view_screen()
	assert_object(screen).is_not_null()
	var row: HBoxContainer = screen.get_node_or_null(
		"PartyDioramaLayer/PartyFrontLine") as HBoxContainer
	assert_object(row).is_not_null()
	assert_int(row.get_child_count()).is_equal(3)

	# Assert — motion enabled → every idle animator is live (the gate did NOT freeze them).
	for slot: Node in row.get_children():
		var animator: SpriteSheetAnimator = slot.get_node_or_null(
			"_IdleAnimator") as SpriteSheetAnimator
		assert_object(animator).is_not_null()
		assert_bool(animator.is_processing()).override_failure_message(
			"with reduce_motion OFF the idle gate must NOT fire — animators stay live"
		).is_true()

	# Cleanup
	sm.set("reduce_motion", prior_rm)
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame
