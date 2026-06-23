## SpriteSheetAnimator — drives a target [TextureRect] through a fixed array of
## frame textures at a constant FPS, producing a looping idle animation.
##
## Lives as a child [Node] of the [TextureRect] it animates (attached by
## [method ClassSpriteFactory.animate]). Pure presentation — it only swaps
## [member TextureRect.texture]; it holds no game state and is safe to free at
## any time. When given 0 or 1 frames it disables its own processing so idle
## cards cost nothing per frame.
##
## The frame textures are sliced from the committed per-class sprite sheets
## (assets/art/classes/<id>/…, original AI ship art via tools/asset-pipeline). When a
## sheet is absent the factory never attaches an animator at all, so an art-less slot
## costs nothing. Beyond the looping idle, the same node plays a ONE-SHOT action pose
## (attack / victory / defeat — [method play_oneshot]) on a HUMAN-frequency reaction
## beat (never the 20 Hz tick, ADR-0025 §C.9), then reverts to the idle loop or holds
## the final frame; see Story 012.
class_name SpriteSheetAnimator
extends Node

## Emitted when a one-shot action play ([method play_oneshot]) completes — after the
## animator has reverted to the idle loop ([code]hold_last == false[/code]) or settled on
## the held final frame ([code]hold_last == true[/code]). Lets a consumer chain on action
## completion; the dungeon view's reaction beats do not require it, but it makes the
## one-shot lifecycle observable and unit-testable.
signal oneshot_finished

## The TextureRect whose [member TextureRect.texture] is cycled. Set in [method setup].
var _target: TextureRect = null

## Ordered frame textures (typically AtlasTextures over one sprite sheet).
var _frames: Array = []

## Playback rate in frames per second. Clamped to a small positive floor in
## [method setup] so a zero/negative fps can never divide-by-zero in [method _process].
var _fps: float = 6.0

## Time accumulator (seconds) toward the next frame advance.
var _accum: float = 0.0

## Index of the currently-displayed frame.
var _idx: int = 0

## Idle baseline recorded at [method setup] so a one-shot action can revert to the
## looping idle when it finishes (Story 012). [member _frames] / [member _fps] hold the
## ACTIVE set (the idle, or an in-flight action one-shot); these hold the idle to restore.
var _idle_frames: Array = []
var _idle_fps: float = 6.0

## True while a one-shot action ([method play_oneshot]) is playing: [method _process] then
## advances WITHOUT wrapping and finishes at the last frame instead of looping the idle.
var _oneshot: bool = false

## When a one-shot finishes: true HOLDS its final frame (the held defeat slump); false
## reverts to the looping idle baseline (attack / victory return to the breathing idle).
var _oneshot_hold_last: bool = false


## Configures (or reconfigures) the animator. Idempotent — calling it again with
## a new frame set restarts playback from frame 0, which is what re-rendering a
## reused card (e.g. a recruit pool slot whose class changed) needs.
##
## [param target] is the TextureRect to drive; [param frames] the ordered frame
## textures; [param fps] the playback rate. Single-frame (or empty) sets the one
## frame and disables [method _process] so static cards are free.
func setup(target: TextureRect, frames: Array, fps: float = 6.0) -> void:
	_target = target
	_frames = frames
	_fps = maxf(0.1, fps)
	_accum = 0.0
	_idx = 0
	# Record the idle baseline so a one-shot action ([method play_oneshot]) can revert to
	# it on finish, and clear any in-flight one-shot state (Story 012).
	_idle_frames = frames
	_idle_fps = _fps
	_oneshot = false
	_oneshot_hold_last = false
	if _target != null and not _frames.is_empty():
		_target.texture = _frames[0]
	# Only burn a per-frame _process when there is something to animate.
	set_process(_target != null and _frames.size() > 1)


## Pauses ([param enabled] = false) or resumes the looping idle WITHOUT re-running
## [method setup] or losing the current frame index — resuming continues from the
## frame it paused on. Reflects a COARSE run-state change (e.g. the dungeon run
## ending freezes every hero's idle on the pose it holds under the run-end overlay),
## driven by a HUMAN-frequency orchestrator signal, NEVER the 20 Hz combat tick
## (ADR-0025 §C.9). Respects the static-card invariant: a ≤1-frame (or art-less)
## animator stays unprocessed even when [param enabled] is true, so it never burns
## a per-frame _process for a slot with nothing to animate.
func set_animating(enabled: bool) -> void:
	set_process(enabled and _target != null and _frames.size() > 1)


## Plays [param frames] ONCE at [param fps] (an action pose — attack / victory / defeat),
## then either reverts to the looping idle baseline recorded at [method setup]
## ([param hold_last] = false — attack / victory: the party resumes breathing) or HOLDS
## the final frame ([param hold_last] = true — defeat: the party stays slumped under the
## run-end overlay). Emits [signal oneshot_finished] on completion. Unlike the idle loop,
## the one-shot does NOT wrap — it advances to the last frame and stops. Reflects a
## HUMAN-frequency reaction beat (kill / floor-clear / defeat), NEVER the 20 Hz combat
## tick (ADR-0025 §C.9). Defensive: an empty [param frames] leaves the idle untouched and
## reports finished at once; a single-frame action shows that frame then finishes.
func play_oneshot(frames: Array, fps: float = 6.0, hold_last: bool = false) -> void:
	if _target == null:
		return
	if frames.is_empty():
		# No action art — do not disturb the idle. Still report finished so a caller
		# chaining on the signal proceeds (the dungeon view only calls this when art
		# exists, so this branch is purely defensive).
		oneshot_finished.emit()
		return
	_oneshot = true
	_oneshot_hold_last = hold_last
	_frames = frames
	_fps = maxf(0.1, fps)
	_idx = 0
	_accum = 0.0
	_target.texture = _frames[0]
	if _frames.size() > 1:
		set_process(true)
	else:
		# A single action frame is already shown; finish immediately on the caller's
		# terms (hold it, or revert to idle).
		_finish_oneshot()


## Instantly displays [param frame] and stops processing — the reduce_motion terminal
## path (e.g. the held defeat pose for a class WITH action art), where the STATE is shown
## without any animation (GDD #35 §C.8). Clears any in-flight one-shot so a later
## [method set_animating] resume reasons about a clean state.
func show_static_frame(frame: Texture2D) -> void:
	_oneshot = false
	if _target != null and frame != null:
		_target.texture = frame
	set_process(false)


## Completes the current one-shot: HOLDS the final frame (stops processing) when
## [member _oneshot_hold_last], else reverts to the looping idle baseline recorded at
## [method setup] and resumes it. Emits [signal oneshot_finished] last, so a listener
## observes the settled state.
func _finish_oneshot() -> void:
	_oneshot = false
	if _oneshot_hold_last:
		# Hold the final action frame (e.g. the defeat slump) — stop advancing.
		set_process(false)
	else:
		# Revert to the looping idle baseline (attack / victory return to breathing).
		_frames = _idle_frames
		_fps = _idle_fps
		_idx = 0
		_accum = 0.0
		if _target != null and not _frames.is_empty():
			_target.texture = _frames[0]
		set_process(_target != null and _frames.size() > 1)
	oneshot_finished.emit()


## Advances the animation. Uses a while-loop drain so a long frame (or a paused tab
## resuming) catches up rather than skipping frames, and only writes the texture when the
## frame index actually changes. A one-shot ([member _oneshot]) advances toward the last
## frame and finishes there (no wrap); the idle loop wraps forever.
func _process(delta: float) -> void:
	if _target == null or _frames.size() <= 1:
		return
	_accum += delta
	var frame_time: float = 1.0 / _fps
	var changed: bool = false
	if _oneshot:
		# One-shot: advance toward the final frame, NEVER wrapping; finish at the end.
		while _accum >= frame_time and _idx < _frames.size() - 1:
			_accum -= frame_time
			_idx += 1
			changed = true
		if changed:
			_target.texture = _frames[_idx]
		if _idx >= _frames.size() - 1:
			_finish_oneshot()
		return
	# Looping idle: drain + wrap (unchanged from the idle-only animator).
	while _accum >= frame_time:
		_accum -= frame_time
		_idx = (_idx + 1) % _frames.size()
		changed = true
	if changed:
		_target.texture = _frames[_idx]
