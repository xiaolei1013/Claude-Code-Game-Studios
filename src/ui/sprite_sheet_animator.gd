## SpriteSheetAnimator — drives a target [TextureRect] through a fixed array of
## frame textures at a constant FPS, producing a looping idle animation.
##
## Lives as a child [Node] of the [TextureRect] it animates (attached by
## [method ClassSpriteFactory.animate]). Pure presentation — it only swaps
## [member TextureRect.texture]; it holds no game state and is safe to free at
## any time. When given 0 or 1 frames it disables its own processing so idle
## cards cost nothing per frame.
##
## This is a demo-build helper: the frame textures come from the local Octopath
## placeholder sprite sheets (see design/art/demo-asset-manifest.md). When those
## assets are absent the factory never attaches an animator at all.
class_name SpriteSheetAnimator
extends Node

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
	if _target != null and not _frames.is_empty():
		_target.texture = _frames[0]
	# Only burn a per-frame _process when there is something to animate.
	set_process(_target != null and _frames.size() > 1)


## Advances the animation. Uses a while-loop drain so a long frame (or a paused
## tab resuming) catches up rather than skipping the wrap math, and only writes
## the texture when the frame index actually changes.
func _process(delta: float) -> void:
	if _target == null or _frames.size() <= 1:
		return
	_accum += delta
	var frame_time: float = 1.0 / _fps
	var changed: bool = false
	while _accum >= frame_time:
		_accum -= frame_time
		_idx = (_idx + 1) % _frames.size()
		changed = true
	if changed:
		_target.texture = _frames[_idx]
