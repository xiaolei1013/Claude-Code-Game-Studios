## ClassSpriteFactory — builds a looping idle animation for a hero class from
## its sprite sheet and (optionally) attaches it to a [TextureRect].
##
## The sheet lives at [code]assets/art/classes/[class_id]/sprite.png[/code] — a
## horizontal strip of [constant FRAME_COUNT] equal-width frames. Sprint 28: these
## are original AI-generated 4-frame idle strips (768×432, locked-palette cozy
## pixel-art look, authored via tools/asset-pipeline). Each frame becomes an
## [AtlasTexture] window over the shared sheet, so all frames share a single GPU texture.
##
## When the sheet is absent for a class (art not yet authored), [method get_idle_frames]
## returns an empty array and [method animate] is a no-op, leaving whatever still
## texture the caller already set (a [ClassPortraitFactory] portrait or block).
## This mirrors ClassPortraitFactory's disk-first / null-fallback contract.
##
## Pure-utility, static-callable, frame-cache keyed by class_id.
class_name ClassSpriteFactory
extends RefCounted

## Frame count of the idle strips (tools/asset-pipeline authors 4-cell sheets).
const FRAME_COUNT: int = 4

## Default idle playback rate. 6 fps reads as a calm "breathing" idle at the
## cozy register, not a frenetic loop.
const IDLE_FPS: float = 6.0

## Default ACTION playback rate (attack / victory / defeat one-shots). Faster than
## the breathing idle so a reaction pose reads as a deliberate beat, not idle drift.
## Story 014 may make this per-class / per-pose data-driven; one rate is enough for
## the Story 012 frames-vs-tween machinery (the action art does not exist yet).
const ACTION_FPS: float = 12.0

## Canonical action-pose ids. Each names a per-class action sprite sheet authored by
## the asset pipeline (manifest images.class_action_sprites in full.json), shipped at
## [code]assets/art/classes/<class_id>/<pose>.png[/code] beside the idle sprite.png.
## Single source of truth for "which action poses exist"; the beat→pose mapping lives
## in the consumer (dungeon_run_view's reaction beats). NOTE: combat is party-AGGREGATE
## and emits no per-hero "hit" signal — [constant POSE_HIT] art is authored-ahead
## (GDD #35 §5 / art-bible) but has no firing beat in this epic.
const POSE_ATTACK: String = "attack"
const POSE_HIT: String = "hit"
const POSE_VICTORY: String = "victory"
const POSE_DEFEAT: String = "defeat"

## Name of the animator child node attached to a driven TextureRect. Stable so
## [method animate] can find-and-reuse it across re-renders instead of stacking
## duplicate animators on a reused card. Public + the single source of truth:
## external consumers (e.g. dungeon_run_view's run-state idle freeze, Story 007)
## look the animator up by this exact name instead of re-declaring the literal.
const ANIMATOR_NODE_NAME: StringName = &"_IdleAnimator"

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
		# ResourceLoader.exists (NOT FileAccess.file_exists): export strips the
		# source .png and ships only the imported .ctex, which ResourceLoader sees
		# but FileAccess does not — so this also resolves real art in EXPORTED builds.
		if ResourceLoader.exists(path):
			var sheet: Texture2D = load(path) as Texture2D
			frames = slice_sheet(sheet, FRAME_COUNT)
	_frames_cache[class_id] = frames
	return frames


## Returns the ordered ACTION frames for [param class_id]'s [param pose] (one of the
## [code]POSE_*[/code] ids), or an empty array when the class/pose is empty or its sheet
## is absent — the art-not-yet-authored path, where the caller falls back to its cosmetic
## tween (Story 012's "real frames where art exists" contract). Cached per (class_id, pose)
## under a composite key, so it never collides with [method get_idle_frames]'s bare
## class_id key. Mirrors the idle loader exactly: same [member ResourceLoader] existence
## guard (resolves real art in EXPORTED builds, where the source .png is stripped), same
## [constant FRAME_COUNT] equal-column slice over a single shared sheet.
static func get_action_frames(class_id: String, pose: String) -> Array:
	if class_id.is_empty() or pose.is_empty():
		return []
	var cache_key: String = "%s/%s" % [class_id, pose]
	if _frames_cache.has(cache_key):
		return _frames_cache[cache_key]
	var frames: Array = []
	var path: String = "res://assets/art/classes/%s/%s.png" % [class_id, pose]
	if ResourceLoader.exists(path):
		var sheet: Texture2D = load(path) as Texture2D
		frames = slice_sheet(sheet, FRAME_COUNT)
	_frames_cache[cache_key] = frames
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
	var anim: Node = target.get_node_or_null(NodePath(String(ANIMATOR_NODE_NAME)))
	if anim == null:
		anim = SpriteSheetAnimatorScript.new()
		anim.name = ANIMATOR_NODE_NAME
		target.add_child(anim)
	anim.setup(target, frames, fps)


## Clears the frame cache. Tests + editor reload only; not reachable from gameplay.
static func _clear_cache_for_tests() -> void:
	_frames_cache.clear()
