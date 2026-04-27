class_name SceneManagerConfig
extends GameData

## SceneManagerConfig — tuning knobs for SceneManager transitions and input policy.
##
## Loaded from [code]assets/data/config/scene_manager_config.tres[/code]. Mirrors
## the EconomyConfig + RosterConfig pattern so all `.tres` files in
## `assets/data/config/` are GameData-extending resources with stable `id` fields
## — DataRegistry's boot scan requires every resource have a non-empty
## snake_case `id` (ADR-0011 §Load-Time Validation Semantics) and transitions
## to ERROR via `InvalidId` when one is missing.
##
## TR-scene-manager-037 / GDD §G Tuning Knobs.
## ADR-0011: per-resource `_validate()` pattern.
##
## Sprint 7 Story M1 (TD-010 cleanup). Replaces the prior plain-Resource form
## of `scene_manager_config.tres` which lacked an `id` and triggered the
## DataRegistry boot-scan ERROR transition documented in TD-010 + FOLLOWUP-002.

# All timing values in milliseconds. Safe ranges per GDD §G.

## Cross-fade total duration in ms. Safe range: 80–300. Default 150.
@export_range(80, 300) var default_crossfade_ms: int = 150

## Slide transition duration in ms. Safe range: 100–300. Default 180.
@export_range(100, 300) var slide_duration_ms: int = 180

## Fade-to-black total duration in ms. Safe range: 200–500. Default 300.
@export_range(200, 500) var fade_to_black_ms: int = 300

## Push-modal slide duration in ms. Default 180 (same as slide).
@export_range(100, 500) var push_modal_ms: int = 180

## Touch feedback scale (per TR-scene-manager-026). Owned by screen nodes,
## NOT by SceneManager — this field surfaces the design knob in one place.
@export_range(1.0, 1.5, 0.01) var touch_feedback_scale: float = 1.05

## Touch feedback pulse duration in ms (owned by screen nodes per ADR-0008).
@export_range(40, 200) var touch_feedback_ms: int = 80

## Transition input policy: 0 = BLOCK (silent drop), 1 = QUEUE_ONE
## (declared, push_warning if used). MVP defaults to 0.
@export_range(0, 1) var transition_input_policy: int = 0


## No-op validator — all fields use @export_range so the editor enforces
## validity at authoring time. Returns empty Array per ADR-0011 contract.
func _validate() -> Array[String]:
	return []
