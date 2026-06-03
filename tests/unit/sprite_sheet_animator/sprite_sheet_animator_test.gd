# SpriteSheetAnimator tests — the per-frame texture cycler that drives idle hero
# sprites over a TextureRect.
#
# _process timing is exercised by calling _process(delta) directly with a
# controlled delta (deterministic — no real frame clock, no tree pumping). Frame
# textures are synthetic ImageTextures so the suite is asset-independent.
extends GdUnitTestSuite

const SpriteSheetAnimatorScript = preload("res://src/ui/sprite_sheet_animator.gd")


func _make_frames(count: int) -> Array:
	var frames: Array = []
	for i: int in range(count):
		var img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		# Distinct fill per frame so identity comparisons are meaningful.
		img.fill(Color(float(i) / 10.0, 0.0, 0.0, 1.0))
		frames.append(ImageTexture.create_from_image(img))
	return frames


func _make_target() -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	add_child(rect)
	auto_free(rect)
	return rect


func _make_animator() -> Node:
	var anim: Node = SpriteSheetAnimatorScript.new()
	add_child(anim)
	auto_free(anim)
	return anim


# ===========================================================================
# Group A — setup() initial state
# ===========================================================================

func test_setup_shows_first_frame() -> void:
	# Arrange
	var target: TextureRect = _make_target()
	var frames: Array = _make_frames(4)
	var anim: Node = _make_animator()

	# Act
	anim.setup(target, frames, 6.0)

	# Assert — frame 0 is displayed immediately.
	assert_object(target.texture).is_same(frames[0])


func test_setup_multi_frame_enables_processing() -> void:
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(4), 6.0)
	assert_bool(anim.is_processing()).is_true()


func test_setup_single_frame_disables_processing() -> void:
	# One frame has nothing to animate — _process must be off (free idle cards).
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(1), 6.0)
	assert_bool(anim.is_processing()).is_false()


func test_setup_empty_frames_disables_processing_and_does_not_crash() -> void:
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, [], 6.0)
	assert_bool(anim.is_processing()).is_false()


# ===========================================================================
# Group B — _process frame advance (deterministic timing)
# ===========================================================================

func test_process_advances_one_frame_after_one_interval() -> void:
	# Arrange — 6 fps → 1/6 s per frame.
	var target: TextureRect = _make_target()
	var frames: Array = _make_frames(4)
	var anim: Node = _make_animator()
	anim.setup(target, frames, 6.0)

	# Act — exactly one frame interval elapses.
	anim._process(1.0 / 6.0)

	# Assert — advanced to frame 1.
	assert_object(target.texture).is_same(frames[1])


func test_process_wraps_around_to_first_frame() -> void:
	# 4 frames at 6 fps; 4 intervals → index wraps 0→1→2→3→0.
	var target: TextureRect = _make_target()
	var frames: Array = _make_frames(4)
	var anim: Node = _make_animator()
	anim.setup(target, frames, 6.0)

	anim._process(4.0 / 6.0)  # four intervals in one big delta (catch-up drain)

	assert_object(target.texture).is_same(frames[0])


func test_process_sub_interval_delta_does_not_advance() -> void:
	# Less than one interval accumulated → still on frame 0.
	var target: TextureRect = _make_target()
	var frames: Array = _make_frames(4)
	var anim: Node = _make_animator()
	anim.setup(target, frames, 6.0)

	anim._process(1.0 / 60.0)  # one render frame, well under 1/6 s

	assert_object(target.texture).is_same(frames[0])


func test_process_accumulates_across_calls() -> void:
	# Two half-interval deltas sum to one interval → advance once.
	var target: TextureRect = _make_target()
	var frames: Array = _make_frames(4)
	var anim: Node = _make_animator()
	anim.setup(target, frames, 6.0)

	anim._process(1.0 / 12.0)
	anim._process(1.0 / 12.0)

	assert_object(target.texture).is_same(frames[1])
