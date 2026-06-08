class_name VfxKit
extends RefCounted
## Reusable one-shot particle-burst helper — the cozy-fantasy "juice" layer
## (GDD #27 VFX System, OQ-27-1 taxonomy). Pure + DI-friendly: callers pass
## [code]reduce_motion[/code] so the kit needs no autoload, and the palette colors
## are named constants (DESIGN.md §Color / Art Bible §4) so screens reference
## [code]VfxKit.LANTERN_GOLD[/code] instead of embedding raw [code]Color()[/code]
## literals (honours the dungeon_run_view AC-7 "no hardcoded Color literals" rule).
##
## [b]reduce_motion[/b]: when true the kit emits NOTHING (snap-replace) per
## GDD #27 OQ-27-3 — the underlying state change still happens; only the motion
## is suppressed. This is the accessible default the cozy register mandates.
##
## CPUParticles2D (not GPUParticles2D) is used deliberately: deterministic,
## cheap on Steam Deck / mobile integrated GPUs, and instanced per-event with an
## auto-free-on-finish lifecycle (GDD #27 §F "emit + auto-free pattern").

## DESIGN.md §Color (Art Bible §4 locked palette). Defined here so screen scripts
## never embed Color() literals — they pass these named constants to the kit.
const LANTERN_GOLD: Color = Color(0.949, 0.722, 0.231, 1.0)   ## #F2B83B — reward / progression highlight.
const GUILD_AMBER: Color = Color(0.784, 0.529, 0.165, 1.0)    ## #C8872A — interactive / kill feedback.
const MOSS_SAGE: Color = Color(0.478, 0.549, 0.369, 1.0)      ## #7A8C5E — nature / level-up accent.

## Default burst tuning (Art Bible §7 Animation Feel: ≤300 ms frequent,
## ≤1500 ms ceremonial). Callers may override per event.
const DEFAULT_AMOUNT: int = 10
const DEFAULT_LIFETIME: float = 0.6


## Spawns a one-shot [CPUParticles2D] burst as a child of [param parent] at
## [param local_position], auto-freeing when the emission + lifetime completes.
##
## Returns the spawned node, or [code]null[/code] when [param reduce_motion] is
## true (snap-replace) or any input is invalid (null/freed parent, non-positive
## amount/lifetime, null texture). Callers may ignore the return value — the node
## frees itself.
##
## [param parent]: a [Node2D]/[Control]/[CanvasItem] already in the tree.
## [param local_position]: burst origin in [param parent]'s local space.
## [param texture]: particle sprite (e.g. res://assets/art/demo/vfx/vfx_aura_a.png).
## [param tint]: per-particle color — pass a VfxKit palette constant.
## [param amount]: particle count (Steam Deck budget: keep ≤ ~24 per burst).
## [param lifetime]: seconds each particle lives.
## [param reduce_motion]: pass [code]SceneManager.reduce_motion[/code]; true → no emission.
##
## GDD #27 §F (emit + auto-free) + OQ-27-3 (reduce_motion snap-replace).
static func spawn_burst(
		parent: Node,
		local_position: Vector2,
		texture: Texture2D,
		tint: Color,
		amount: int = DEFAULT_AMOUNT,
		lifetime: float = DEFAULT_LIFETIME,
		reduce_motion: bool = false) -> CPUParticles2D:
	# Accessibility: reduce_motion suppresses all particle motion (snap-replace).
	if reduce_motion:
		return null
	if parent == null or not is_instance_valid(parent):
		return null
	if texture == null:
		return null
	if amount <= 0 or lifetime <= 0.0:
		return null

	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.texture = texture
	burst.position = local_position
	burst.amount = amount
	burst.lifetime = lifetime
	burst.one_shot = true            # a single burst, not a continuous stream
	burst.explosiveness = 1.0        # all particles emit at once
	burst.direction = Vector2(0.0, -1.0)  # drift upward — cozy float
	burst.spread = 180.0
	burst.initial_velocity_min = 20.0
	burst.initial_velocity_max = 60.0
	burst.gravity = Vector2(0.0, 40.0)    # gentle settle back down
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.0
	burst.color = tint
	burst.z_index = 50               # above UI ground; below modal overlays

	parent.add_child(burst)
	# Auto-free once the one-shot emission + particle lifetime completes.
	burst.finished.connect(burst.queue_free)
	burst.emitting = true
	return burst
