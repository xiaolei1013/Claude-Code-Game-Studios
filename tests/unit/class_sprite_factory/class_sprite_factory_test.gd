# ClassSpriteFactory tests — the idle-sprite frame builder consumed by the
# Recruit pool cards and Hero Detail modal.
#
# Three contracts under test:
#   - Pure math: `slice_sheet(sheet, count)` is exercised with SYNTHETIC textures,
#     so the region geometry is deterministic and independent of any on-disk asset.
#   - Negative path: `get_idle_frames` returns empty for the empty / missing class
#     (caller keeps its still portrait), which is stable everywhere.
#   - Real-art path (Sprint 28 AI class sprites): a committed class loads its real
#     4-frame idle strip and slices into FRAME_COUNT equal columns. This is the
#     regression net against a reverted ResourceLoader.exists guard, a path typo,
#     the strip files slipping back out of version control, or an import-dims drift
#     that would misalign the 4-cell slice.
extends GdUnitTestSuite

const ClassSpriteFactoryScript = preload("res://src/ui/class_sprite_factory.gd")

# A class id with committed real art (Sprint 28) at
# assets/art/classes/<id>/sprite.png — a 4-frame idle strip authored by the asset
# pipeline at the manifest-pinned 768×432 (images.class_sprites[].size in full.json).
const _REAL_ART_CLASS_ID: String = "warrior"

# Manifest-pinned strip dimensions; frame width is STRIP_WIDTH / FRAME_COUNT.
const _STRIP_WIDTH: int = 768
const _STRIP_HEIGHT: int = 432


func before_test() -> void:
	ClassSpriteFactoryScript._clear_cache_for_tests()


func after_test() -> void:
	ClassSpriteFactoryScript._clear_cache_for_tests()


## Builds a synthetic [width]×[height] texture so the slicing math is testable
## without any on-disk asset.
func _make_sheet(width: int, height: int) -> Texture2D:
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


# ===========================================================================
# Group A — slice_sheet region math
# ===========================================================================

func test_slice_sheet_four_frames_returns_four_frames() -> void:
	# Arrange — a 40×10 strip split into 4 columns of 10px.
	var sheet: Texture2D = _make_sheet(40, 10)

	# Act
	var frames: Array = ClassSpriteFactoryScript.slice_sheet(sheet, 4)

	# Assert
	assert_int(frames.size()).is_equal(4)


func test_slice_sheet_regions_are_contiguous_equal_columns() -> void:
	# Arrange
	var sheet: Texture2D = _make_sheet(40, 10)

	# Act
	var frames: Array = ClassSpriteFactoryScript.slice_sheet(sheet, 4)

	# Assert — each frame is a 10×10 window stepping across the strip.
	for i: int in range(4):
		var atlas: AtlasTexture = frames[i] as AtlasTexture
		assert_object(atlas).is_not_null()
		assert_float(atlas.region.position.x).is_equal_approx(float(i * 10), 0.001)
		assert_float(atlas.region.position.y).is_equal_approx(0.0, 0.001)
		assert_float(atlas.region.size.x).is_equal_approx(10.0, 0.001)
		assert_float(atlas.region.size.y).is_equal_approx(10.0, 0.001)


func test_slice_sheet_frames_share_the_source_atlas() -> void:
	# All frames must window the SAME underlying sheet (one GPU texture).
	var sheet: Texture2D = _make_sheet(40, 10)
	var frames: Array = ClassSpriteFactoryScript.slice_sheet(sheet, 4)
	for frame: Variant in frames:
		assert_object((frame as AtlasTexture).atlas).is_same(sheet)


func test_slice_sheet_uneven_width_floors_frame_width() -> void:
	# 42 / 4 = 10 (floored). The strip needn't be perfectly divisible — frames
	# are floor-width and the trailing remainder is simply not windowed.
	var sheet: Texture2D = _make_sheet(42, 10)
	var frames: Array = ClassSpriteFactoryScript.slice_sheet(sheet, 4)
	assert_int(frames.size()).is_equal(4)
	assert_float((frames[0] as AtlasTexture).region.size.x).is_equal_approx(10.0, 0.001)


# ===========================================================================
# Group B — slice_sheet defensive paths
# ===========================================================================

func test_slice_sheet_null_sheet_returns_empty() -> void:
	assert_int(ClassSpriteFactoryScript.slice_sheet(null, 4).size()).is_equal(0)


func test_slice_sheet_zero_count_returns_empty() -> void:
	var sheet: Texture2D = _make_sheet(40, 10)
	assert_int(ClassSpriteFactoryScript.slice_sheet(sheet, 0).size()).is_equal(0)


func test_slice_sheet_negative_count_returns_empty() -> void:
	var sheet: Texture2D = _make_sheet(40, 10)
	assert_int(ClassSpriteFactoryScript.slice_sheet(sheet, -2).size()).is_equal(0)


func test_slice_sheet_narrower_than_count_returns_empty() -> void:
	# A 2px-wide sheet cannot yield 4 one-px-plus columns — guard returns empty
	# rather than producing zero-width regions.
	var sheet: Texture2D = _make_sheet(2, 10)
	assert_int(ClassSpriteFactoryScript.slice_sheet(sheet, 4).size()).is_equal(0)


# ===========================================================================
# Group C — get_idle_frames asset-absent behavior (CI-stable)
# ===========================================================================

func test_get_idle_frames_empty_class_returns_empty() -> void:
	assert_int(ClassSpriteFactoryScript.get_idle_frames("").size()).is_equal(0)


func test_get_idle_frames_missing_class_returns_empty() -> void:
	# No sprite sheet on disk for a bogus class → graceful empty (caller keeps
	# its still portrait). This is the production / non-demo path.
	assert_int(ClassSpriteFactoryScript.get_idle_frames("not_a_real_class_xyz").size()).is_equal(0)


func test_get_idle_frames_caches_result_for_repeat_calls() -> void:
	# Same Array instance returned on the second call (cache hit).
	var first: Array = ClassSpriteFactoryScript.get_idle_frames("")
	var second: Array = ClassSpriteFactoryScript.get_idle_frames("")
	assert_bool(first == second).is_true()


# ===========================================================================
# Group D — animate() defensive contract
# ===========================================================================

func test_animate_null_target_does_not_crash() -> void:
	# Should simply return — exercised for the defensive guard.
	ClassSpriteFactoryScript.animate(null, "warrior")
	assert_bool(true).is_true()


func test_animate_absent_sheet_attaches_no_animator() -> void:
	# With no demo sheet for the class, animate() must NOT attach an animator —
	# the caller's still texture stays untouched.
	var rect: TextureRect = TextureRect.new()
	add_child(rect)
	auto_free(rect)

	ClassSpriteFactoryScript.animate(rect, "not_a_real_class_xyz")

	assert_object(rect.get_node_or_null("_IdleAnimator")).is_null()


# ===========================================================================
# Group E — real-art binding (Sprint 28 — AI class idle strips)
# ===========================================================================

func test_real_art_class_loads_and_windows_quarter_width_columns() -> void:
	# Arrange + Act — "warrior" has a committed 4-frame strip at
	# assets/art/classes/warrior/sprite.png; get_idle_frames loads + slices it.
	var frames: Array = ClassSpriteFactoryScript.get_idle_frames(_REAL_ART_CLASS_ID)
	var expected_w: float = float(_STRIP_WIDTH) / float(ClassSpriteFactoryScript.FRAME_COUNT)

	# Assert — the real strip slices into FRAME_COUNT equal cells. An empty/short
	# array means the strip is missing/unimported or the ResourceLoader.exists guard
	# regressed (e.g. reverted to FileAccess, which fails in exported builds); this
	# leading count assert also stops a zero-frame strip from vacuously passing the
	# loop below. A wrong frame WIDTH means the import dims drifted off the
	# manifest-pinned 768×432, which would misalign every cell and jitter the loop.
	assert_int(frames.size()).is_equal(ClassSpriteFactoryScript.FRAME_COUNT)
	for i: int in range(frames.size()):
		var atlas: AtlasTexture = frames[i] as AtlasTexture
		assert_object(atlas).is_not_null()
		assert_float(atlas.region.position.x).is_equal_approx(expected_w * float(i), 0.5)
		assert_float(atlas.region.size.x).is_equal_approx(expected_w, 0.5)
		assert_float(atlas.region.size.y).is_equal_approx(float(_STRIP_HEIGHT), 0.5)


# ===========================================================================
# Group F — get_action_frames disk-first loader (Story 011 art · Story 012 loader)
#
# Mirrors get_idle_frames' disk-first / empty-fallback contract for the action
# poses (attack / hit / victory / defeat). Story 011's per-class action art is now
# rendered + committed, so a real (class, pose) lookup loads + slices FRAME_COUNT
# frames from disk (see the all-classes windowing test + the does-not-collide test).
# The empty "caller-falls-back-to-its-cosmetic-tween" fallback — Story 012's "real
# frames where art exists, tween where it doesn't" contract — is still fully exercised
# via the empty-arg guards and the missing-sheet (bogus class) path.
# ===========================================================================

func test_get_action_frames_empty_class_returns_empty() -> void:
	assert_int(ClassSpriteFactoryScript.get_action_frames(
		"", ClassSpriteFactoryScript.POSE_ATTACK).size()).is_equal(0)


func test_get_action_frames_empty_pose_returns_empty() -> void:
	# A real class id but no pose → empty (the (class, pose) pair is incomplete).
	assert_int(ClassSpriteFactoryScript.get_action_frames(
		_REAL_ART_CLASS_ID, "").size()).is_equal(0)


func test_get_action_frames_missing_sheet_returns_empty() -> void:
	# No attack.png on disk for a bogus class → graceful empty (caller keeps its
	# cosmetic tween). The production / art-not-yet-authored path.
	assert_int(ClassSpriteFactoryScript.get_action_frames(
		"not_a_real_class_xyz", ClassSpriteFactoryScript.POSE_ATTACK).size()).is_equal(0)


func test_get_action_frames_caches_result_for_repeat_calls() -> void:
	# Same Array instance returned on the second call (cache hit under the
	# composite "<class>/<pose>" key).
	var first: Array = ClassSpriteFactoryScript.get_action_frames(
		_REAL_ART_CLASS_ID, ClassSpriteFactoryScript.POSE_ATTACK)
	var second: Array = ClassSpriteFactoryScript.get_action_frames(
		_REAL_ART_CLASS_ID, ClassSpriteFactoryScript.POSE_ATTACK)
	assert_bool(first == second).is_true()


func test_get_action_frames_does_not_collide_with_idle_cache() -> void:
	# The real-art class now has BOTH a committed idle sprite.png AND committed action
	# sheets (Story 011). The composite "<class>/<pose>" action key must load the action
	# sheet's OWN frames — never the idle frames cached under the bare "<class>" key. Both
	# caches populated AND distinct is a stronger isolation net than the original empty-
	# action case: a cache-key collision would make get_action_frames hand back the SAME
	# array the idle loader cached, which the inequality assert below catches.
	var idle: Array = ClassSpriteFactoryScript.get_idle_frames(_REAL_ART_CLASS_ID)
	var action: Array = ClassSpriteFactoryScript.get_action_frames(
		_REAL_ART_CLASS_ID, ClassSpriteFactoryScript.POSE_ATTACK)
	assert_int(idle.size()).is_equal(ClassSpriteFactoryScript.FRAME_COUNT)
	assert_int(action.size()).is_equal(ClassSpriteFactoryScript.FRAME_COUNT)
	# No cache-key collision: the action key returns its own distinct frames (sliced from
	# attack.png), not the idle array (sliced from sprite.png) cached under the bare key.
	assert_bool(idle == action).is_false()


# Canonical roster class ids with committed real art (Sprint 28 idle + Story 011 action
# sheets) under assets/art/classes/<id>/. Mirrors the asset-pipeline manifest roster
# (images.class_sprites / class_action_sprites in full.json). The exact set IS the point:
# this list is the asset-presence contract — a missing or renamed sheet must fail loudly.
const _ALL_ART_CLASS_IDS: Array[String] = [
	"warrior", "mage", "rogue", "cleric", "archer", "berserker", "paladin",
]


func test_real_art_action_sheets_load_for_every_class_and_pose() -> void:
	# The Story 011 wiring net (the dominant "scaffolded-but-unwired" bug class): EVERY
	# class × EVERY action pose must resolve a committed sheet on disk and slice into
	# FRAME_COUNT equal columns. A missing / misnamed sheet, an unimported PNG, or an
	# import-dims drift off the manifest-pinned 768×432 fails here — proving all 28 action
	# sheets (7 classes × 4 poses) are present, named, and window correctly, so a reaction
	# beat plays real frames instead of silently falling back to the cosmetic tween.
	var expected_w: float = float(_STRIP_WIDTH) / float(ClassSpriteFactoryScript.FRAME_COUNT)
	var poses: Array[String] = [
		ClassSpriteFactoryScript.POSE_ATTACK,
		ClassSpriteFactoryScript.POSE_HIT,
		ClassSpriteFactoryScript.POSE_VICTORY,
		ClassSpriteFactoryScript.POSE_DEFEAT,
	]
	for class_id: String in _ALL_ART_CLASS_IDS:
		for pose: String in poses:
			var frames: Array = ClassSpriteFactoryScript.get_action_frames(class_id, pose)
			assert_int(frames.size()).override_failure_message(
				"%s/%s.png must load + slice into FRAME_COUNT frames (missing / unimported sheet?)" % [class_id, pose]
			).is_equal(ClassSpriteFactoryScript.FRAME_COUNT)
			for i: int in range(frames.size()):
				var atlas: AtlasTexture = frames[i] as AtlasTexture
				assert_object(atlas).override_failure_message(
					"%s/%s frame %d must be an AtlasTexture window" % [class_id, pose, i]
				).is_not_null()
				assert_float(atlas.region.size.x).override_failure_message(
					"%s/%s frame %d width must be STRIP_WIDTH / FRAME_COUNT (import-dims drift?)" % [class_id, pose, i]
				).is_equal_approx(expected_w, 0.5)
				assert_float(atlas.region.size.y).is_equal_approx(float(_STRIP_HEIGHT), 0.5)


# ===========================================================================
# Group G — Story 014: in-scene ↔ portrait speed differential + per-class non-reuse
#
# GDD #35 §D.7 + §G: the dungeon in-scene hero breathes at the full IDLE_FPS;
# the SAME idle on a calm portrait/thumbnail surface (recruit / hero-detail /
# codex / start-menu) plays at PORTRAIT_IDLE_FPS = IDLE_FPS × 0.5 = 3.0 fps
# (art-bible §8.1 "meditative, not restless"). The differential is exercised
# BEHAVIOURALLY through a real-art animator, not by reading the rate back —
# proving the cadence the player actually sees. art-bible §8.1 also forbids one
# class reusing another's idle motion; the code-boundary guarantee of that is
# that each class loads its OWN distinct sheet (keyed on class_id).
# ===========================================================================

# A SECOND class with committed real art (alongside _REAL_ART_CLASS_ID) — used
# to prove two classes window two DIFFERENT sheets (non-reuse invariant).
const _REAL_ART_CLASS_ID_2: String = "mage"


func test_portrait_idle_fps_ratio_is_half() -> void:
	# §G knob: portrait tier animates at 0.5× the in-scene rate (safe range 0.25–1.0).
	assert_float(ClassSpriteFactoryScript.PORTRAIT_IDLE_FPS_RATIO).is_equal_approx(0.5, 0.0001)


func test_portrait_idle_fps_is_idle_fps_times_ratio() -> void:
	# Derived rate is a single source of truth: IDLE_FPS (6.0) × 0.5 = 3.0 fps,
	# never a hardcoded 3.0 at a call site (§D.7).
	assert_float(ClassSpriteFactoryScript.PORTRAIT_IDLE_FPS).is_equal_approx(
		ClassSpriteFactoryScript.IDLE_FPS * ClassSpriteFactoryScript.PORTRAIT_IDLE_FPS_RATIO, 0.0001)
	assert_float(ClassSpriteFactoryScript.PORTRAIT_IDLE_FPS).is_equal_approx(3.0, 0.0001)


func test_animate_portrait_tier_is_slower_than_in_scene() -> void:
	# The differential made observable: a delta LARGER than one in-scene frame
	# interval (1/6s ≈ 0.167) but SMALLER than one portrait interval (1/3s ≈ 0.333)
	# advances the in-scene animator yet leaves the portrait animator on frame 0.
	# Both load the SAME real warrior idle frames — only the fps arg differs.
	var mid_delta: float = 0.25  # 0.167 < 0.25 < 0.333

	var in_scene: TextureRect = TextureRect.new()
	add_child(in_scene)
	auto_free(in_scene)
	ClassSpriteFactoryScript.animate(in_scene, _REAL_ART_CLASS_ID)  # default = full IDLE_FPS
	var in_scene_frame0: Texture2D = in_scene.texture

	var portrait: TextureRect = TextureRect.new()
	add_child(portrait)
	auto_free(portrait)
	ClassSpriteFactoryScript.animate(portrait, _REAL_ART_CLASS_ID, ClassSpriteFactoryScript.PORTRAIT_IDLE_FPS)
	var portrait_frame0: Texture2D = portrait.texture

	var in_scene_anim: SpriteSheetAnimator = in_scene.get_node_or_null(
		String(ClassSpriteFactoryScript.ANIMATOR_NODE_NAME)) as SpriteSheetAnimator
	var portrait_anim: SpriteSheetAnimator = portrait.get_node_or_null(
		String(ClassSpriteFactoryScript.ANIMATOR_NODE_NAME)) as SpriteSheetAnimator
	assert_object(in_scene_anim).is_not_null()
	assert_object(portrait_anim).is_not_null()

	in_scene_anim._process(mid_delta)
	portrait_anim._process(mid_delta)

	# In-scene advanced (full speed); portrait held frame 0 (half speed).
	assert_object(in_scene.texture).is_not_same(in_scene_frame0)
	assert_object(portrait.texture).is_same(portrait_frame0)


func test_animate_portrait_tier_advances_after_a_full_portrait_interval() -> void:
	# The portrait tier is SLOWER, not frozen: once a full portrait interval
	# (1/PORTRAIT_IDLE_FPS ≈ 0.333s) elapses it advances one frame.
	var portrait: TextureRect = TextureRect.new()
	add_child(portrait)
	auto_free(portrait)
	ClassSpriteFactoryScript.animate(portrait, _REAL_ART_CLASS_ID, ClassSpriteFactoryScript.PORTRAIT_IDLE_FPS)
	var frame0: Texture2D = portrait.texture
	var anim: SpriteSheetAnimator = portrait.get_node_or_null(
		String(ClassSpriteFactoryScript.ANIMATOR_NODE_NAME)) as SpriteSheetAnimator
	assert_object(anim).is_not_null()

	anim._process(0.5)  # > 1/PORTRAIT_IDLE_FPS (0.333) → one frame advances
	assert_object(portrait.texture).is_not_same(frame0)


func test_distinct_classes_load_distinct_idle_sheets() -> void:
	# art-bible §8.1: "No hero may reuse another hero's secondary idle motion."
	# Code-boundary guarantee: each class loads its OWN sprite sheet, so two classes'
	# idle frames window DIFFERENT source textures — no class can animate with
	# another's frames. (The secondary-motion CONTENT is authored INTO each class's
	# distinct strip; the loader's per-class keying enforces non-reuse.) Regression
	# net for a cache-key collision or a shared-sheet refactor.
	var warrior: Array = ClassSpriteFactoryScript.get_idle_frames(_REAL_ART_CLASS_ID)
	var mage: Array = ClassSpriteFactoryScript.get_idle_frames(_REAL_ART_CLASS_ID_2)
	assert_int(warrior.size()).is_equal(ClassSpriteFactoryScript.FRAME_COUNT)
	assert_int(mage.size()).is_equal(ClassSpriteFactoryScript.FRAME_COUNT)
	var warrior_sheet: Texture2D = (warrior[0] as AtlasTexture).atlas
	var mage_sheet: Texture2D = (mage[0] as AtlasTexture).atlas
	assert_object(warrior_sheet).is_not_same(mage_sheet)


# ===========================================================================
# Group H — Story 015: reduce_motion suppression + shared-atlas perf budget
#
# GDD #35 §C.8 + the binding ui-code rule ("all animations respect motion
# prefs"): animate(reduce_motion=true) must hold the hero PRESENT but STILL —
# the animator attaches, displays frame 0, and disables its per-frame _process,
# so a reduce_motion slot costs nothing per frame yet the hero is still shown
# (AC-35-07: "motion suppressed, presence kept, all K visible"). The flag is
# PASSED IN (the four calm portrait surfaces thread their own SceneManager read),
# keeping the factory autoload-free — mirrors VfxKit.spawn_burst's reduce_motion.
#
# Perf budget (AC-35-06 / §F): K on-screen heroes of one class window ONE shared
# sheet texture — the draw-call/VRAM cost scales with CLASS COUNT, not hero count.
# ===========================================================================

func test_animate_reduce_motion_freezes_idle_on_static_frame_zero() -> void:
	# Arrange — a real-art class so an animator actually attaches.
	var rect: TextureRect = TextureRect.new()
	add_child(rect)
	auto_free(rect)
	var frames: Array = ClassSpriteFactoryScript.get_idle_frames(_REAL_ART_CLASS_ID)
	assert_int(frames.size()).is_equal(ClassSpriteFactoryScript.FRAME_COUNT)

	# Act — animate under reduce_motion.
	ClassSpriteFactoryScript.animate(
		rect, _REAL_ART_CLASS_ID, ClassSpriteFactoryScript.IDLE_FPS, true)

	# Assert — animator present (hero is shown) but frozen: _process disabled and
	# holding frame 0. Presence without motion.
	var anim: SpriteSheetAnimator = rect.get_node_or_null(
		String(ClassSpriteFactoryScript.ANIMATOR_NODE_NAME)) as SpriteSheetAnimator
	assert_object(anim).is_not_null()
	assert_bool(anim.is_processing()).is_false()
	assert_object(rect.texture).is_same(frames[0])


func test_animate_motion_enabled_runs_idle_conditional_control() -> void:
	# Control for the freeze test above: the SAME call with reduce_motion=false
	# leaves the idle running (per-frame _process enabled). Proves the freeze is
	# caused by the flag, not by the slot being inert.
	var rect: TextureRect = TextureRect.new()
	add_child(rect)
	auto_free(rect)

	ClassSpriteFactoryScript.animate(
		rect, _REAL_ART_CLASS_ID, ClassSpriteFactoryScript.IDLE_FPS, false)

	var anim: SpriteSheetAnimator = rect.get_node_or_null(
		String(ClassSpriteFactoryScript.ANIMATOR_NODE_NAME)) as SpriteSheetAnimator
	assert_object(anim).is_not_null()
	assert_bool(anim.is_processing()).is_true()


func test_animate_reduce_motion_defaults_to_motion_enabled() -> void:
	# The 4th param defaults false: the pre-Story-015 3-arg call sites (the dungeon
	# in-scene slot, which gates its idle externally via Story 010) keep looping.
	# Regression net against the default flipping and silently freezing everything.
	var rect: TextureRect = TextureRect.new()
	add_child(rect)
	auto_free(rect)

	ClassSpriteFactoryScript.animate(
		rect, _REAL_ART_CLASS_ID, ClassSpriteFactoryScript.PORTRAIT_IDLE_FPS)

	var anim: SpriteSheetAnimator = rect.get_node_or_null(
		String(ClassSpriteFactoryScript.ANIMATOR_NODE_NAME)) as SpriteSheetAnimator
	assert_object(anim).is_not_null()
	assert_bool(anim.is_processing()).is_true()


func test_idle_frames_share_one_atlas_for_draw_call_budget() -> void:
	# AC-35-06 / §F perf budget, made concrete: EVERY frame of a class windows the
	# SAME underlying sheet texture. So K on-screen heroes of one class reference K
	# AtlasTextures over ONE sheet — draw-call/VRAM cost scales with the number of
	# distinct CLASSES on screen, not the hero count. Regression net for a slicing
	# refactor that allocates a sheet per frame (which would multiply VRAM by
	# FRAME_COUNT and break the min-spec budget this story validates).
	var frames: Array = ClassSpriteFactoryScript.get_idle_frames(_REAL_ART_CLASS_ID)
	assert_int(frames.size()).is_equal(ClassSpriteFactoryScript.FRAME_COUNT)
	var sheet: Texture2D = (frames[0] as AtlasTexture).atlas
	assert_object(sheet).is_not_null()
	for frame: Variant in frames:
		var atlas: AtlasTexture = frame as AtlasTexture
		assert_object(atlas).is_not_null()
		assert_object(atlas.atlas).is_same(sheet)
