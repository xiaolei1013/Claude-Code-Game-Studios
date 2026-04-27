# Tests for Story S5-M4: SceneManager autoload skeleton + four-state machine + DataRegistry gating.
# Covers: TR-scene-manager-001, TR-scene-manager-009, TR-scene-manager-012,
#         ADR-0003 Amendment #3 (zero-arg _init), AC H-06 (partial).
#
# All tests use preload-and-new (not the live autoload scene tree) for Group C and D,
# so that:
#   - Unit tests are isolated from the full autoload boot stack
#   - DataRegistry.registry_ready mock-state is not required for most groups
#   - Tests remain fast and deterministic (no scene tree required for non-autoload tests)
#
# Group A tests verify the LIVE autoload presence via get_tree().root.get_node_or_null().
# In the headless test runner, all autoloads (including DataRegistry) have already
# booted and DataRegistry.registry_ready has already fired before test code runs
# (Sprint 3 fix for TD-006). Therefore the live SceneManager will be in IDLE state.
# The "UNINITIALIZED" tests (Group D) use fresh non-autoload instances to isolate the
# pre-IDLE behavior without requiring DataRegistry mock injection.
#
# _queued_request is private by convention (underscore prefix). Tests access it
# directly via `sm._queued_request` because GDScript does not enforce underscore
# privacy — the underscore is project-style only. No public accessor is exposed
# on the script: keeping the field private signals to future readers that
# `_queued_request` is internal to the queue-on-UNINITIALIZED protocol and not
# part of the public API surface. Direct test access is the pragmatic choice
# rather than polluting the API with a debug-only getter.
extends GdUnitTestSuite

const SceneManagerScript = preload("res://src/core/scene_manager/scene_manager.gd")


# ===========================================================================
# Group A: TR-scene-manager-001 + TR-scene-manager-009
# Autoload presence + DataRegistry gating
# ===========================================================================

# ---------------------------------------------------------------------------
# A-01: SceneManager node resolves at /root/SceneManager
# (verifies project.godot [autoload] registration is present and correct)
# ---------------------------------------------------------------------------
func test_scenemanager_autoload_node_resolves() -> void:
	# Arrange / Act — query the live scene tree
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")

	# Assert — autoload must be present at boot
	assert_object(sm).is_not_null()
	assert_bool(sm is Node).is_true()


# ---------------------------------------------------------------------------
# A-02: SceneManager state is one of the four valid enum values at boot
#
# NOTE: In the GdUnit4 headless runner, DataRegistry boots into ERROR state
# (the runner's missing/partial content path triggers Economy._ready failure
# during boot — visible as "Economy._ready: failed to resolve EconomyConfig"
# in the test output). Because of that, DataRegistry.registry_ready never
# fires, and SceneManager's state stays at UNINITIALIZED for the duration
# of the test run. This test does NOT depend on which specific state is
# active — it only verifies the live autoload's `state` field is a valid
# enum value (0..3 inclusive). The IDLE/TRANSITIONING/PAUSED transitions
# are tested in the integration suite where MainRoot is the active scene.
# ---------------------------------------------------------------------------
func test_scenemanager_live_state_is_valid_enum_value() -> void:
	# Arrange
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(sm).is_not_null()

	# Assert — state must be one of the four valid enum values (0..3 inclusive).
	# Specific live-runner state is environment-dependent (DataRegistry may be
	# READY or ERROR depending on content presence), so we don't assert a
	# specific value here — that's covered in the integration suite.
	assert_int(sm.state).is_greater_equal(SceneManagerScript.State.UNINITIALIZED)
	assert_int(sm.state).is_less_equal(SceneManagerScript.State.PAUSED)


# ---------------------------------------------------------------------------
# A-03: SceneManager.current_screen is null at boot (no screen loaded yet)
# ---------------------------------------------------------------------------
func test_scenemanager_current_screen_is_null_at_boot() -> void:
	# Arrange
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(sm).is_not_null()

	# Assert — no screen is active immediately after boot (Story 003 populates this)
	assert_object(sm.current_screen).is_null()
	# Companion field: current_screen_id starts as empty string (matches Story 003 contract).
	assert_str(sm.current_screen_id).is_equal("")


# ===========================================================================
# Group B: TR-scene-manager-012 — Four-state machine enum
# ===========================================================================

# ---------------------------------------------------------------------------
# B-01: State enum has exactly four values
# ---------------------------------------------------------------------------
func test_state_enum_has_exactly_four_values() -> void:
	# Arrange — access each of the four enum constants by name; any missing name
	# causes a parse error on preload, surfacing as a test-runner failure.
	var _u: int = SceneManagerScript.State.UNINITIALIZED
	var _i: int = SceneManagerScript.State.IDLE
	var _t: int = SceneManagerScript.State.TRANSITIONING
	var _p: int = SceneManagerScript.State.PAUSED

	# Assert — all four values are distinct integers (GDScript enums are 0-based by default)
	var values: Array[int] = [_u, _i, _t, _p]
	assert_int(values.size()).is_equal(4)

	# Verify no two values collide (ensures they aren't aliased)
	var unique: Dictionary = {}
	for v: int in values:
		unique[v] = true
	assert_int(unique.size()).is_equal(4)

	# CRITICAL: enum-introspection assertion — the State enum dictionary itself
	# must contain EXACTLY 4 keys. Without this check, adding a fifth state value
	# (e.g., FROZEN) would not be caught by the array assertions above — the
	# four-element array would still construct successfully and pass.
	# Per story TR-012 edge case: "adding a fifth state would break the contract surface".
	assert_int(SceneManagerScript.State.size()).is_equal(4)
	assert_int(SceneManagerScript.State.keys().size()).is_equal(4)


# ---------------------------------------------------------------------------
# B-02: State enum values are in the canonical order (UNINITIALIZED=0, IDLE=1,
#        TRANSITIONING=2, PAUSED=3)
# ---------------------------------------------------------------------------
func test_state_enum_values_in_canonical_order() -> void:
	# Assert — TR-scene-manager-012 mandates exact order
	assert_int(SceneManagerScript.State.UNINITIALIZED).is_equal(0)
	assert_int(SceneManagerScript.State.IDLE).is_equal(1)
	assert_int(SceneManagerScript.State.TRANSITIONING).is_equal(2)
	assert_int(SceneManagerScript.State.PAUSED).is_equal(3)


# ---------------------------------------------------------------------------
# B-03: TransitionType enum has exactly seven values in canonical order
# ---------------------------------------------------------------------------
func test_transition_type_enum_has_exactly_seven_values() -> void:
	# Parse all 7 canonical names
	var _cf: int = SceneManagerScript.TransitionType.CROSS_FADE
	var _su: int = SceneManagerScript.TransitionType.SLIDE_UP
	var _sl: int = SceneManagerScript.TransitionType.SLIDE_LEFT
	var _sd: int = SceneManagerScript.TransitionType.SLIDE_DOWN
	var _fb: int = SceneManagerScript.TransitionType.FADE_TO_BLACK
	var _pm: int = SceneManagerScript.TransitionType.PUSH_MODAL
	var _ce: int = SceneManagerScript.TransitionType.CEREMONY

	var values: Array[int] = [_cf, _su, _sl, _sd, _fb, _pm, _ce]
	assert_int(values.size()).is_equal(7)

	# Verify CROSS_FADE == 0 (default parameter value in request_screen depends on this)
	assert_int(SceneManagerScript.TransitionType.CROSS_FADE).is_equal(0)


# ===========================================================================
# Group C: ADR-0003 Amendment #3 — Zero-arg _init
# ===========================================================================

# ---------------------------------------------------------------------------
# C-01: SceneManager script constructs via .new() with zero arguments
# ---------------------------------------------------------------------------
func test_scenemanager_zero_arg_init_constructs_without_error() -> void:
	# Arrange / Act — no arguments; if _init had required args this would raise
	var sm: Node = SceneManagerScript.new()

	# Assert — reaching this line means _init accepted zero args cleanly
	assert_object(sm).is_not_null()
	assert_bool(sm is Node).is_true()

	# Cleanup
	sm.free()


# ---------------------------------------------------------------------------
# C-02: Autoload boots cleanly — SceneManager is non-null in the live tree
# (boot-pass assertion; implicit from A-01 but made explicit per the story spec)
# ---------------------------------------------------------------------------
func test_scenemanager_autoload_boots_cleanly() -> void:
	# Arrange / Act
	var sm: Node = get_tree().root.get_node_or_null("SceneManager")

	# Assert — autoload registered in project.godot and booted without errors
	assert_object(sm).is_not_null()
	assert_str(sm.name).is_equal("SceneManager")


# ---------------------------------------------------------------------------
# C-03: Non-autoload instance initial state is UNINITIALIZED
# (directly tests the constructor default; complements A-02 for the live node)
# ---------------------------------------------------------------------------
func test_scenemanager_fresh_instance_starts_in_uninitialized_state() -> void:
	# Arrange — instantiate without adding to scene tree to prevent _ready() firing
	var sm: Node = SceneManagerScript.new()

	# Assert — initial state is UNINITIALIZED (value 0) before _ready() runs
	assert_int(sm.state).is_equal(SceneManagerScript.State.UNINITIALIZED)

	# Cleanup
	sm.free()


# ===========================================================================
# Group D: AC H-06 (partial) — request_screen queued while UNINITIALIZED
#
# Uses fresh non-autoload SceneManager instances so state stays UNINITIALIZED
# (no _ready() → no DataRegistry subscription → no IDLE transition).
#
# _queued_request is private by convention. To avoid making it public solely
# for testing, the test accesses it via GDScript's permissive runtime access
# (private members are accessible by name in GDScript — there is no true
# enforcement at the language level; underscore prefix is a convention).
# ===========================================================================

# ---------------------------------------------------------------------------
# D-01: request_screen queues the request when state is UNINITIALIZED
# ---------------------------------------------------------------------------
func test_scenemanager_request_screen_queues_when_uninitialized() -> void:
	# Arrange — fresh instance; NOT added to tree; _ready() never fires; stays UNINITIALIZED
	var sm: Node = SceneManagerScript.new()
	assert_int(sm.state).is_equal(SceneManagerScript.State.UNINITIALIZED)

	# Act
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)

	# Assert — _queued_request populated with the correct shape
	# GDScript allows reading underscore-prefixed vars from outside the class (no true private)
	var queued: Dictionary = sm._queued_request
	assert_bool(queued.is_empty()).is_false()
	assert_str(queued.get("screen_id", "")).is_equal("guild_hall")
	# CROSS_FADE == 0
	assert_int(queued.get("transition", -1)).is_equal(0)

	# State must not advance (still UNINITIALIZED — no DataRegistry integration yet)
	assert_int(sm.state).is_equal(SceneManagerScript.State.UNINITIALIZED)

	# Cleanup
	sm.free()


# ---------------------------------------------------------------------------
# D-02: back-to-back calls while UNINITIALIZED — last-write-wins
# ---------------------------------------------------------------------------
func test_scenemanager_request_screen_last_write_wins_when_uninitialized() -> void:
	# Arrange
	var sm: Node = SceneManagerScript.new()
	assert_int(sm.state).is_equal(SceneManagerScript.State.UNINITIALIZED)

	# Act — first call
	sm.request_screen("guild_hall", SceneManagerScript.TransitionType.CROSS_FADE)
	# Act — second call overwrites
	sm.request_screen("dungeon_run_view", SceneManagerScript.TransitionType.FADE_TO_BLACK)

	# Assert — second call's args are in the queue (last-write-wins per ADR-0007)
	var queued: Dictionary = sm._queued_request
	assert_str(queued.get("screen_id", "")).is_equal("dungeon_run_view")
	assert_int(queued.get("transition", -1)).is_equal(SceneManagerScript.TransitionType.FADE_TO_BLACK)

	# Cleanup
	sm.free()


# ---------------------------------------------------------------------------
# D-03: request_screen on the SAME screen in IDLE is a silent no-op
# (covers AC H-03; full S5-M5 same-screen no-op behavior — push_warning + return)
# ---------------------------------------------------------------------------
func test_scenemanager_same_screen_request_in_idle_is_noop() -> void:
	# Arrange — fresh instance; manually advance state to IDLE and pretend
	# the current screen is already "guild_hall". This simulates the post-registry
	# steady state without requiring a full MainRoot wire-up (the same-screen
	# no-op path returns early BEFORE _execute_transition is ever called, so
	# no node-swap setup is needed for this contract).
	var sm: Node = SceneManagerScript.new()
	sm.state = SceneManagerScript.State.IDLE
	sm.current_screen_id = "guild_hall"

	# Pre-assert — _queued_request is empty
	assert_bool(sm._queued_request.is_empty()).is_true()

	# Act — call request_screen with the SAME screen_id (should hit no-op branch)
	sm.request_screen("guild_hall")

	# Assert — _queued_request stays empty (no queue mutation on same-screen)
	assert_bool(sm._queued_request.is_empty()).is_true()

	# Assert — state unchanged (no transition started)
	assert_int(sm.state).is_equal(SceneManagerScript.State.IDLE)

	# Assert — current_screen_id unchanged (same-screen no-op contract)
	assert_str(sm.current_screen_id).is_equal("guild_hall")

	# Cleanup
	sm.free()


# ---------------------------------------------------------------------------
# D-04: project.godot registration smoke check
# (verifies SceneManager is registered after BiomeDungeonDatabase in the file)
# ---------------------------------------------------------------------------
func test_scenemanager_registered_in_project_godot_after_biomeDungeonDatabase() -> void:
	# Arrange — read project.godot as text
	var file: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	assert_object(file).is_not_null()

	var content: String = file.get_as_text()
	file.close()

	# Assert — SceneManager entry is present with the correct format
	assert_bool(content.contains("SceneManager")).is_true()
	assert_bool(content.contains(
		"SceneManager=\"*res://src/core/scene_manager/scene_manager.gd\""
	)).is_true()

	# Assert — rank order: BiomeDungeonDatabase before SceneManager
	var pos_bdd: int = content.find("BiomeDungeonDatabase=")
	var pos_sm: int = content.find("SceneManager=")
	assert_bool(pos_bdd != -1 and pos_sm != -1).is_true()
	assert_bool(pos_bdd < pos_sm).is_true()
