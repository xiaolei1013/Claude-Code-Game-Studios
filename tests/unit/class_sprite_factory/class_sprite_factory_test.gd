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
