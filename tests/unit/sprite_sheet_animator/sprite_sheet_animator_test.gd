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


# ===========================================================================
# Group C — set_animating() pause/resume (Story 007 run-state reflection)
#
# set_animating reflects a COARSE run-state change (e.g. the dungeon run ending
# freezes hero idles) on a human-frequency signal — it toggles _process WITHOUT
# re-running setup or losing the frame index. It respects the static-card
# invariant: a ≤1-frame animator stays unprocessed even when resumed.
# ===========================================================================

func test_set_animating_false_stops_processing() -> void:
	# Arrange — a live multi-frame animator (processing).
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(4), 6.0)
	assert_bool(anim.is_processing()).is_true()

	# Act — pause the idle loop.
	anim.set_animating(false)

	# Assert — _process is off (the frozen pose costs nothing per frame).
	assert_bool(anim.is_processing()).is_false()


func test_set_animating_true_resumes_processing() -> void:
	# Arrange — a paused multi-frame animator.
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(4), 6.0)
	anim.set_animating(false)
	assert_bool(anim.is_processing()).is_false()

	# Act — resume.
	anim.set_animating(true)

	# Assert — _process is back on.
	assert_bool(anim.is_processing()).is_true()


func test_set_animating_true_keeps_single_frame_static() -> void:
	# A 1-frame (or art-less) slot has nothing to animate — resuming must NOT turn
	# on _process (the static-card invariant; art-less heroes cost 0 per frame).
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(1), 6.0)
	assert_bool(anim.is_processing()).is_false()

	anim.set_animating(true)

	assert_bool(anim.is_processing()).is_false()


func test_set_animating_resume_continues_from_paused_frame() -> void:
	# Pause/resume must PRESERVE the frame index (it is not a setup() restart).
	# Arrange — advance to frame 1, then pause.
	var target: TextureRect = _make_target()
	var frames: Array = _make_frames(4)
	var anim: Node = _make_animator()
	anim.setup(target, frames, 6.0)
	anim._process(1.0 / 6.0)               # → frame 1
	assert_object(target.texture).is_same(frames[1])
	anim.set_animating(false)

	# Act — resume and advance one more interval.
	anim.set_animating(true)
	anim._process(1.0 / 6.0)               # → frame 2 (continues; does NOT restart at 0)

	# Assert — advanced to frame 2, proving the index survived the pause.
	assert_object(target.texture).is_same(frames[2])


# ===========================================================================
# Group D — play_oneshot() action poses (Story 012 — frames-where-art-exists)
#
# A one-shot plays an ACTION pose (attack / victory / defeat) ONCE at ACTION_FPS,
# advancing toward its last frame WITHOUT wrapping, then either reverts to the
# looping idle baseline (hold_last = false: attack / victory resume breathing) or
# HOLDS the final frame (hold_last = true: the defeat slump stays). Driven on a
# human-frequency reaction beat, NEVER the 20 Hz tick (ADR-0025 §C.9). Timing is
# exercised by direct _process(delta) injection — fully deterministic.
# ===========================================================================

func test_play_oneshot_shows_first_action_frame() -> void:
	# Arrange — a live idle, then an action one-shot over a DISTINCT frame set.
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(4), 6.0)
	var action: Array = _make_frames(3)

	# Act
	anim.play_oneshot(action, 12.0, false)

	# Assert — the action's first frame shows immediately (idle is superseded).
	assert_object(target.texture).is_same(action[0])


func test_play_oneshot_advances_through_action_frames() -> void:
	# 3 action frames at 12 fps → 1/12 s per frame; one interval → frame 1.
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(4), 6.0)
	var action: Array = _make_frames(3)
	anim.play_oneshot(action, 12.0, false)

	anim._process(1.0 / 12.0)

	assert_object(target.texture).is_same(action[1])


func test_play_oneshot_does_not_wrap_holds_last_when_hold_last() -> void:
	# hold_last = true (the defeat slump). A delta large enough to wrap an idle loop
	# must instead STOP on the final action frame (no wrap to frame 0) and disable
	# processing — the held pose costs nothing per frame under the run-end overlay.
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(4), 6.0)
	var action: Array = _make_frames(3)
	anim.play_oneshot(action, 12.0, true)

	anim._process(10.0)  # far past the whole action — would wrap a looping idle

	assert_object(target.texture).is_same(action[2])  # last frame, NOT action[0]
	assert_bool(anim.is_processing()).is_false()


func test_play_oneshot_reverts_to_idle_when_not_hold_last() -> void:
	# hold_last = false (attack / victory). On completion the animator reverts to the
	# idle baseline recorded at setup() — frame 0 of the IDLE set, not the action set.
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	var idle: Array = _make_frames(4)
	anim.setup(target, idle, 6.0)
	anim.play_oneshot(_make_frames(3), 12.0, false)

	anim._process(10.0)  # drive the one-shot to completion

	assert_object(target.texture).is_same(idle[0])     # reverted to the idle baseline
	assert_bool(anim.is_processing()).is_true()        # idle loop resumed


func test_play_oneshot_revert_resumes_idle_loop() -> void:
	# After reverting (hold_last = false), the idle loop runs normally from frame 0:
	# one idle interval (1/6 s) advances idle 0 → 1, proving breathing resumed.
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	var idle: Array = _make_frames(4)
	anim.setup(target, idle, 6.0)
	anim.play_oneshot(_make_frames(3), 12.0, false)
	anim._process(10.0)                                # finish → revert to idle[0]
	assert_object(target.texture).is_same(idle[0])

	anim._process(1.0 / 6.0)                           # one idle interval

	assert_object(target.texture).is_same(idle[1])     # idle advanced (and at idle fps)


func test_play_oneshot_emits_oneshot_finished() -> void:
	# The signal fires on completion — connected via a lambda flag so the assertion
	# is deterministic (the _process drive emits synchronously; no clock wait).
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(4), 6.0)
	var fired: Array = [false]
	anim.oneshot_finished.connect(func() -> void: fired[0] = true)
	anim.play_oneshot(_make_frames(3), 12.0, false)

	anim._process(10.0)  # drive to completion

	assert_bool(fired[0]).is_true()


func test_play_oneshot_empty_frames_emits_finished_and_leaves_idle() -> void:
	# Defensive: no action art → do NOT disturb the idle, but still report finished so
	# a caller chaining on the signal proceeds. (The dungeon view only calls this when
	# art exists, so this is the belt-and-braces path.)
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	var idle: Array = _make_frames(4)
	anim.setup(target, idle, 6.0)
	var fired: Array = [false]
	anim.oneshot_finished.connect(func() -> void: fired[0] = true)

	anim.play_oneshot([], 12.0, false)

	assert_bool(fired[0]).is_true()                    # reported finished
	assert_object(target.texture).is_same(idle[0])     # idle texture untouched
	assert_bool(anim.is_processing()).is_true()        # idle loop still running


func test_play_oneshot_single_frame_hold_displays_and_stops() -> void:
	# A single-frame action (hold_last = true) shows that one frame and finishes
	# immediately — nothing to advance, processing stays off (held pose).
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(4), 6.0)
	var action: Array = _make_frames(1)

	anim.play_oneshot(action, 12.0, true)

	assert_object(target.texture).is_same(action[0])
	assert_bool(anim.is_processing()).is_false()


func test_play_oneshot_null_target_does_not_crash() -> void:
	# No setup() (target null) → play_oneshot returns without touching anything.
	var anim: Node = _make_animator()
	anim.play_oneshot(_make_frames(3), 12.0, false)
	assert_bool(true).is_true()


# ===========================================================================
# Group E — show_static_frame() (Story 012 — reduce_motion terminal pose)
#
# Instantly displays one frame and stops processing — the reduce_motion held pose
# (e.g. the final defeat frame for a class WITH action art), where the terminal
# STATE is shown without ANY animation (GDD #35 §C.8).
# ===========================================================================

func test_show_static_frame_displays_and_stops_processing() -> void:
	# Arrange — a live idle (processing on).
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	anim.setup(target, _make_frames(4), 6.0)
	assert_bool(anim.is_processing()).is_true()
	var held: Texture2D = _make_frames(1)[0]

	# Act
	anim.show_static_frame(held)

	# Assert — the held frame shows and per-frame processing is off.
	assert_object(target.texture).is_same(held)
	assert_bool(anim.is_processing()).is_false()


func test_show_static_frame_null_keeps_texture_and_stops_processing() -> void:
	# Defensive: a null frame leaves the current texture untouched but still stops
	# processing (a class without action art keeps whatever it was showing, frozen).
	var target: TextureRect = _make_target()
	var anim: Node = _make_animator()
	var idle: Array = _make_frames(4)
	anim.setup(target, idle, 6.0)

	anim.show_static_frame(null)

	assert_object(target.texture).is_same(idle[0])     # unchanged
	assert_bool(anim.is_processing()).is_false()
