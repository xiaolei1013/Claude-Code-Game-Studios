## ClassSpriteFactory — builds a looping idle animation for a hero class from
## its demo sprite sheet and (optionally) attaches it to a [TextureRect].
##
## The sheet lives at [code]assets/art/classes/[class_id]/sprite.png[/code] — a
## horizontal strip of [constant FRAME_COUNT] equal-width frames produced by
## tools/demo-asset-setup.py (see design/art/demo-asset-manifest.md). Each frame
## becomes an [AtlasTexture] window over the shared sheet, so all frames share a
## single GPU texture.
##
## DEMO-BUILD ONLY: when the sheet is absent (production art not yet delivered,
## or any non-demo build — the demo assets are gitignored), [method get_idle_frames]
## returns an empty array and [method animate] is a no-op, leaving whatever still
## texture the caller already set (a [ClassPortraitFactory] portrait or block).
## This mirrors ClassPortraitFactory's disk-first / generate-fallback contract.
##
## Pure-utility, static-callable, frame-cache keyed by class_id.
class_name ClassSpriteFactory
extends RefCounted

## Frame count of the demo idle strips (tools/demo-asset-setup.py assembles 4).
const FRAME_COUNT: int = 4

## Default idle playback rate. 6 fps reads as a calm "breathing" idle at the
## cozy register, not a frenetic loop.
const IDLE_FPS: float = 6.0

## Name of the animator child node attached to a driven TextureRect. Stable so
## [method animate] can find-and-reuse it across re-renders instead of stacking
## duplicate animators on a reused card.
const _ANIMATOR_NODE_NAME: StringName = &"_IdleAnimator"

const SpriteSheetAnimatorScript = preload("res://src/ui/sprite_sheet_animator.gd")

## Module-level cache: class_id → Array of frame Texture2Ds. Frames are immutable
## AtlasTextures over an immutable sheet, so caching is safe for the session.
static var _frames_cache: Dictionary = {}


## Returns the ordered idle frames for [param class_id], or an empty array when
## the class is empty or its sprite sheet is absent. Cached after first build.
static func get_idle_frames(class_id: String) -> Array:
	if _frames_cache.has(class_id):
		return _frames_cache[class_id]
	var frames: Array = []
	if not class_id.is_empty():
		var path: String = "res://assets/art/classes/%s/sprite.png" % class_id
		if FileAccess.file_exists(path):
			var sheet: Texture2D = load(path) as Texture2D
			frames = slice_sheet(sheet, FRAME_COUNT)
	_frames_cache[class_id] = frames
	return frames


## Slices a horizontal sprite [param sheet] into [param frame_count] equal-width
## [AtlasTexture] frames. Pure function (no disk access) so the slicing math is
## unit-testable with a synthetic texture. Returns an empty array on a null sheet,
## a non-positive count, or a sheet too narrow to hold one column per frame.
static func slice_sheet(sheet: Texture2D, frame_count: int) -> Array:
	var frames: Array = []
	if sheet == null or frame_count <= 0 or sheet.get_width() < frame_count:
		return frames
	var frame_w: int = sheet.get_width() / frame_count
	var frame_h: int = sheet.get_height()
	for i: int in range(frame_count):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.append(atlas)
	return frames


## Attaches (or reuses) a [SpriteSheetAnimator] on [param target] that loops the
## class's idle frames at [param fps]. No-op when [param target] is null or the
## sheet is absent — in the latter case the caller's existing still texture stays.
## Idempotent across re-renders: a reused card keeps its single named animator and
## is just reconfigured for the (possibly new) class.
static func animate(target: TextureRect, class_id: String, fps: float = IDLE_FPS) -> void:
	if target == null:
		return
	var frames: Array = get_idle_frames(class_id)
	if frames.is_empty():
		return
	var anim: Node = target.get_node_or_null(NodePath(String(_ANIMATOR_NODE_NAME)))
	if anim == null:
		anim = SpriteSheetAnimatorScript.new()
		anim.name = _ANIMATOR_NODE_NAME
		target.add_child(anim)
	anim.setup(target, frames, fps)


## Clears the frame cache. Tests + editor reload only; not reachable from gameplay.
static func _clear_cache_for_tests() -> void:
	_frames_cache.clear()
