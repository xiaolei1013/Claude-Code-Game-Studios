# Tests for Story S5-M3: MainRoot.tscn persistent-root scene + four CanvasLayer children.
# Covers: TR-scene-manager-002 (CanvasLayer composition + layer values),
#         TR-scene-manager-019 (process mode assignments),
#         ADR-0008 theme cascade (parchment_theme.tres preload wiring).
#
# Integration test — loads MainRoot.tscn, instantiates it into the scene tree,
# waits one process frame so _ready() fires, then asserts composition and state.
# Each test group is self-contained: the scene instance is added and freed
# within the test body to guarantee isolation.
#
# ADR-0007: Persistent root scene architecture (CanvasLayer child contract)
# ADR-0008: Parchment theme preload cascade
extends GdUnitTestSuite

const MAIN_ROOT_SCENE_PATH: String = "res://src/core/scene_manager/MainRoot.tscn"


# ---------------------------------------------------------------------------
# Helper — instantiate MainRoot.tscn into the scene tree and await _ready().
# Caller is responsible for calling root_inst.queue_free() after assertions.
# ---------------------------------------------------------------------------
func _load_main_root() -> Control:
	var packed: PackedScene = load(MAIN_ROOT_SCENE_PATH) as PackedScene
	assert_object(packed).is_not_null()

	var inst: Control = packed.instantiate() as Control
	assert_object(inst).is_not_null()

	add_child(inst)
	await get_tree().process_frame
	return inst


# ===========================================================================
# Group A: TR-scene-manager-002 — CanvasLayer composition and layer values
# ===========================================================================

# ---------------------------------------------------------------------------
# A-01: Root node named "MainRoot" must resolve; must be a Control
# (MainRoot extends Control so theme property exists for cascade per ADR-0008)
# ---------------------------------------------------------------------------
func test_mainroot_node_resolves() -> void:
	# Arrange / Act
	var inst: Control = await _load_main_root()

	# Assert — scene loaded; root is a Control
	assert_object(inst).is_not_null()
	assert_str(inst.name).is_equal("MainRoot")
	assert_bool(inst is Control).is_true()

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# A-02: PersistentHUDLayer is a CanvasLayer child with layer == 10
# ---------------------------------------------------------------------------
func test_persistent_hud_layer_present_with_correct_layer() -> void:
	# Arrange
	var inst: Control = await _load_main_root()

	# Act
	var hud: CanvasLayer = inst.get_node_or_null("PersistentHUDLayer") as CanvasLayer

	# Assert — child exists and is typed CanvasLayer with layer = 10
	assert_object(hud).is_not_null()
	assert_bool(hud is CanvasLayer).is_true()
	assert_int(hud.layer).is_equal(10)

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# A-03: ScreenContainer must be a plain Node, NOT a CanvasLayer
# (regression guard — it is the screen-swap target; must not be a CanvasLayer)
# ---------------------------------------------------------------------------
func test_screen_container_is_node_not_canvaslayer() -> void:
	# Arrange
	var inst: Control = await _load_main_root()

	# Act
	var sc: Node = inst.get_node_or_null("ScreenContainer")

	# Assert — child exists, is a Node, and is definitively NOT a CanvasLayer
	assert_object(sc).is_not_null()
	assert_bool(sc is Node).is_true()
	assert_bool(sc is CanvasLayer).is_false()

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# A-04: TransitionLayer is a CanvasLayer with layer == 100
# ---------------------------------------------------------------------------
func test_transition_layer_present_with_correct_layer() -> void:
	# Arrange
	var inst: Control = await _load_main_root()

	# Act
	var tl: CanvasLayer = inst.get_node_or_null("TransitionLayer") as CanvasLayer

	# Assert
	assert_object(tl).is_not_null()
	assert_bool(tl is CanvasLayer).is_true()
	assert_int(tl.layer).is_equal(100)

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# A-05: OverlayLayer is a CanvasLayer with layer == 110
# ---------------------------------------------------------------------------
func test_overlay_layer_present_with_correct_layer() -> void:
	# Arrange
	var inst: Control = await _load_main_root()

	# Act
	var ol: CanvasLayer = inst.get_node_or_null("OverlayLayer") as CanvasLayer

	# Assert
	assert_object(ol).is_not_null()
	assert_bool(ol is CanvasLayer).is_true()
	assert_int(ol.layer).is_equal(110)

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# A-06: Canvas layer strict ordering — PersistentHUDLayer < TransitionLayer < OverlayLayer
# (regression guard: inverted layer would break compositing z-order)
# ---------------------------------------------------------------------------
func test_canvas_layer_strict_ordering() -> void:
	# Arrange
	var inst: Control = await _load_main_root()
	var hud: CanvasLayer = inst.get_node_or_null("PersistentHUDLayer") as CanvasLayer
	var tl: CanvasLayer = inst.get_node_or_null("TransitionLayer") as CanvasLayer
	var ol: CanvasLayer = inst.get_node_or_null("OverlayLayer") as CanvasLayer

	assert_object(hud).is_not_null()
	assert_object(tl).is_not_null()
	assert_object(ol).is_not_null()

	# Assert — strict ordering (10 < 100 < 110)
	assert_bool(hud.layer < tl.layer).is_true()
	assert_bool(tl.layer < ol.layer).is_true()

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# A-07: TransitionLayer child Fade is a ColorRect (full-rect anchor)
# ---------------------------------------------------------------------------
func test_transition_layer_fade_child_is_color_rect() -> void:
	# Arrange
	var inst: Control = await _load_main_root()
	var tl: CanvasLayer = inst.get_node_or_null("TransitionLayer") as CanvasLayer
	assert_object(tl).is_not_null()

	# Act
	var fade: ColorRect = tl.get_node_or_null("Fade") as ColorRect

	# Assert — Fade child exists and is a ColorRect
	assert_object(fade).is_not_null()
	assert_bool(fade is ColorRect).is_true()

	# Assert — starts transparent (modulate.a == 0.0) with black color
	assert_float(fade.modulate.a).is_equal(0.0)
	assert_float(fade.color.r).is_equal(0.0)
	assert_float(fade.color.g).is_equal(0.0)
	assert_float(fade.color.b).is_equal(0.0)

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# A-08: TransitionLayer child InputBlock is a Control with MOUSE_FILTER_IGNORE
# (Story 005 will activate it; placeholder must default to IGNORE per ADR-0007)
# ADR-0007/ADR-0008: only MOUSE_FILTER_IGNORE cascades to children in 4.5+
# ---------------------------------------------------------------------------
func test_transition_layer_input_block_has_mouse_filter_ignore() -> void:
	# Arrange
	var inst: Control = await _load_main_root()
	var tl: CanvasLayer = inst.get_node_or_null("TransitionLayer") as CanvasLayer
	assert_object(tl).is_not_null()

	# Act
	var input_block: Control = tl.get_node_or_null("InputBlock") as Control

	# Assert — InputBlock exists and has MOUSE_FILTER_IGNORE (value 2)
	assert_object(input_block).is_not_null()
	assert_bool(input_block is Control).is_true()
	assert_int(input_block.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group B: TR-scene-manager-019 — Process mode assignments
# ===========================================================================

# ---------------------------------------------------------------------------
# B-01: PersistentHUDLayer process_mode == PROCESS_MODE_ALWAYS (value 3)
# ---------------------------------------------------------------------------
func test_persistent_hud_process_mode_always() -> void:
	# Arrange
	var inst: Control = await _load_main_root()
	var hud: CanvasLayer = inst.get_node_or_null("PersistentHUDLayer") as CanvasLayer
	assert_object(hud).is_not_null()

	# Assert — exact equality; PROCESS_MODE_ALWAYS = 3
	assert_int(hud.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# B-02: ScreenContainer process_mode == PROCESS_MODE_PAUSABLE (value 1)
# Screens added to ScreenContainer will pause on get_tree().paused = true.
# ---------------------------------------------------------------------------
func test_screen_container_process_mode_pausable() -> void:
	# Arrange
	var inst: Control = await _load_main_root()
	var sc: Node = inst.get_node_or_null("ScreenContainer")
	assert_object(sc).is_not_null()

	# Assert — exact equality; PROCESS_MODE_PAUSABLE = 2
	assert_int(sc.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# B-03: TransitionLayer process_mode == PROCESS_MODE_ALWAYS (value 3)
# Must keep running during modal pause to animate fade-to-black etc.
# ---------------------------------------------------------------------------
func test_transition_layer_process_mode_always() -> void:
	# Arrange
	var inst: Control = await _load_main_root()
	var tl: CanvasLayer = inst.get_node_or_null("TransitionLayer") as CanvasLayer
	assert_object(tl).is_not_null()

	# Assert
	assert_int(tl.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# B-04: OverlayLayer process_mode == PROCESS_MODE_ALWAYS (value 3)
# Modals render on top; must continue while game is paused.
# ---------------------------------------------------------------------------
func test_overlay_layer_process_mode_always() -> void:
	# Arrange
	var inst: Control = await _load_main_root()
	var ol: CanvasLayer = inst.get_node_or_null("OverlayLayer") as CanvasLayer
	assert_object(ol).is_not_null()

	# Assert
	assert_int(ol.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# B-05: No CanvasLayer has PROCESS_MODE_INHERIT on root
#
# PROCESS_MODE_INHERIT (value 0) on a CanvasLayer whose ancestor is root would
# silently behave as ALWAYS — but is architecturally ambiguous. All three
# CanvasLayers MUST have explicit PROCESS_MODE_ALWAYS, not rely on inherit.
# This guards against a misconfiguration that "works" but violates the spec.
# ---------------------------------------------------------------------------
func test_no_inherit_mode_on_canvas_layers() -> void:
	# Arrange
	var inst: Control = await _load_main_root()
	var hud: CanvasLayer = inst.get_node_or_null("PersistentHUDLayer") as CanvasLayer
	var tl: CanvasLayer = inst.get_node_or_null("TransitionLayer") as CanvasLayer
	var ol: CanvasLayer = inst.get_node_or_null("OverlayLayer") as CanvasLayer

	assert_object(hud).is_not_null()
	assert_object(tl).is_not_null()
	assert_object(ol).is_not_null()

	# Assert — none of the three CanvasLayers use PROCESS_MODE_INHERIT (0)
	assert_int(hud.process_mode).is_not_equal(Node.PROCESS_MODE_INHERIT)
	assert_int(tl.process_mode).is_not_equal(Node.PROCESS_MODE_INHERIT)
	assert_int(ol.process_mode).is_not_equal(Node.PROCESS_MODE_INHERIT)

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group C: ADR-0008 theme cascade — Parchment theme preload wiring
# ===========================================================================

# ---------------------------------------------------------------------------
# C-01: After _ready() fires, theme property is a non-null Theme instance
# (main_root.gd _ready() calls: theme = preload("res://assets/ui/parchment_theme.tres"))
# ---------------------------------------------------------------------------
func test_main_root_theme_is_loaded() -> void:
	# Arrange / Act — _ready() fires during await process_frame inside _load_main_root()
	var inst: Control = await _load_main_root()

	# Assert — theme must be a non-null Theme resource
	assert_object(inst.theme).is_not_null()
	assert_bool(inst.theme is Theme).is_true()

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# C-02: Theme resource path matches the canonical ADR-0008 preload path
# (load-bearing path commitment — renaming the .tres must fail this test)
# ---------------------------------------------------------------------------
func test_main_root_theme_resource_path_matches_canonical_path() -> void:
	# Arrange
	var inst: Control = await _load_main_root()
	assert_object(inst.theme).is_not_null()

	# Act
	var path: String = inst.theme.resource_path

	# Assert — canonical path per ADR-0008
	assert_str(path).is_equal("res://assets/ui/parchment_theme.tres")

	# Cleanup
	inst.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# C-03: parchment_theme.tres file exists and loads as a Theme resource
# (decoupled from the scene — verifies the .tres is loadable standalone)
# ---------------------------------------------------------------------------
func test_parchment_theme_tres_loads_as_theme_resource() -> void:
	# Act — direct resource load outside the scene context
	var theme_res: Theme = load("res://assets/ui/parchment_theme.tres") as Theme

	# Assert — must load without error and be a Theme
	assert_object(theme_res).is_not_null()
	assert_bool(theme_res is Theme).is_true()


# ---------------------------------------------------------------------------
# C-04: Theme load failure surfaces — if path is wrong, preload raises at parse;
# verify the placeholder file is actually present at the canonical path so the
# boot preload never silently returns null.
# ---------------------------------------------------------------------------
func test_theme_canonical_path_file_exists() -> void:
	# Act — FileAccess check; load() caches so we use FileAccess for presence
	var file_exists: bool = FileAccess.file_exists("res://assets/ui/parchment_theme.tres")

	# Assert — file must exist for preload in main_root.gd to succeed at boot
	assert_bool(file_exists).is_true()


# ===========================================================================
# Group D: project.godot main-scene wiring (story AC #3)
# ===========================================================================

# ---------------------------------------------------------------------------
# D-01: project.godot [application] run/main_scene points at MainRoot.tscn
# (story AC #3 — covers the integration boundary between scene + boot config)
# ---------------------------------------------------------------------------
func test_project_godot_main_scene_is_mainroot() -> void:
	# Arrange — load project.godot via ConfigFile parser
	var cfg: ConfigFile = ConfigFile.new()
	var load_err: int = cfg.load("res://project.godot")

	# Assert — file parses cleanly
	assert_int(load_err).is_equal(OK)

	# Act — read run/main_scene under [application]
	var main_scene: String = cfg.get_value("application", "run/main_scene", "")

	# Assert — exact match against the canonical MainRoot.tscn path
	assert_str(main_scene).is_equal("res://src/core/scene_manager/MainRoot.tscn")
