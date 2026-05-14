// Tilt-shift depth-of-field — fake-miniature look for HD-2D scenes.
//
// Per design/gdd/hd-2d-rendering-pipeline.md + game-concept.md Pillar 4
// Visual Identity Anchor: a horizontal sharp band across the focus_y line
// with progressive Gaussian blur toward the top and bottom edges. The
// resulting feel is "diorama on a tabletop" — the focal action stays
// crisp while the periphery softens to a painted-miniature register.
//
// Sprint 18 N1 (3-sprint carry: S16-N2 → S17-N4 → S18-N1) per
// production/sprints/sprint-18.md. ADR-0017 §Decision: full HD-2D
// pipeline deferred to Vertical Slice tier; this shader ships as
// ready-to-deploy infrastructure layered above content and below the
// warm-lantern overlay. Composes cleanly with warm_lantern_overlay.gdshader
// (this runs first, lantern runs on top).
//
// Usage: place a BackBufferCopy node above the scene content, then a
// full-rect ColorRect with this ShaderMaterial attached, mouse_filter =
// MOUSE_FILTER_IGNORE, and a z_index between content (0) and any warm-
// lantern overlay (1). The shader samples the screen via the
// `screen_texture` uniform (hint_screen_texture — Godot 4.x pattern;
// the legacy 3.x `screen_texture` builtin was removed in 4.0) and
// overwrites COLOR with the blurred sample.
//
// Performance: 9-tap single-pass Gaussian (no separable two-pass needed —
// blur strength is small per .claude/rules/shader-code.md "minimize
// texture samples"; max 9 samples per fragment). Steam Deck 1280×800 at
// 60fps budget per .claude/docs/technical-preferences.md remains intact.
// Compatible with Forward+ 2D on Vulkan / Metal / D3D12 per Godot 4.6
// defaults.

shader_type canvas_item;

// Godot 4.x screen-content sampler. `hint_screen_texture` tells the
// renderer to bind the prior BackBufferCopy result to this uniform.
// `filter_linear_mipmap` gives clean bilinear interpolation at the
// blur sample offsets without mip artifacts at edge.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// Vertical position of the sharp focus band (0 = top of screen, 1 =
// bottom). Default 0.5 = perfect middle. Tune per-scene so the focal
// action sits in the band.
uniform float focus_y : hint_range(0.0, 1.0) = 0.5;

// Half-height of the fully-sharp region around focus_y (in UV space).
// 0.0 = no sharp band (everything blurs); 0.5 = top/bottom completely
// sharp. Default 0.2 = ~40% of vertical screen stays sharp.
uniform float focus_height : hint_range(0.0, 0.5) = 0.2;

// Max blur sample offset at the screen edges, in UV space. 0.0 disables
// blur; 0.01 ≈ subtle smear; 0.04 ≈ obvious diorama feel. Default
// 0.015 = perceptible but not soup.
uniform float blur_strength : hint_range(0.0, 0.05) = 0.015;

// Soft falloff from the sharp band into the blur zone. Lower = harder
// edge (less natural); higher = gentler ramp (more painterly). Default
// 0.25 = roughly half the screen between sharp and max-blur.
uniform float falloff_softness : hint_range(0.01, 1.0) = 0.25;

// Master toggle for runtime preview. 1.0 = effect on, 0.0 = pass-through
// (cheap — short-circuits the 9-tap loop). Bound to settings or
// reduce_motion-style accessibility flag in scene code.
uniform float enabled : hint_range(0.0, 1.0) = 1.0;


// 9-tap Gaussian weights, centered. Sigma ≈ 1.5 sample units.
// Pre-baked for performance; total sums to 1.0.
const float WEIGHTS[9] = float[](
	0.05, 0.09, 0.12, 0.15, 0.18, 0.15, 0.12, 0.09, 0.05
);

// Sample-offset multipliers (in units of `radius`).
const float OFFSETS[9] = float[](
	-4.0, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0
);


void fragment() {
	// Distance from focus_y, normalized so 0.0 = on the focus line and
	// 1.0 = at the screen edge. Used as the master blur factor.
	float dy = abs(UV.y - focus_y);

	// Subtract the sharp band's half-height — values inside the band
	// become negative (clamped to 0 by smoothstep below). Outside the
	// band, the ramp climbs toward 1.0 at falloff_softness distance.
	float ramp = smoothstep(0.0, falloff_softness, dy - focus_height);

	// Final blur radius for this fragment. Inside the focus band ramp=0
	// → radius=0 → single texture tap (the center weight dominates).
	// At full blur edges ramp=1 → radius=blur_strength.
	float radius = ramp * blur_strength * enabled;

	// Pass-through when radius is effectively zero (most fragments
	// inside the focus rect). `return` is illegal in Godot 4.x
	// fragment processors, so use an if/else branch — the GPU still
	// short-circuits the loop on this path.
	if (radius < 0.0001) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		// 9-tap blur along the Y axis. Vertical-only blur is sufficient
		// for the tilt-shift look (the focal contrast is on Y; adding
		// horizontal blur doubles cost without proportional perceived
		// effect at this strength).
		vec4 accum = vec4(0.0);
		for (int i = 0; i < 9; i++) {
			vec2 offset = vec2(0.0, OFFSETS[i] * radius);
			accum += texture(screen_texture, SCREEN_UV + offset) * WEIGHTS[i];
		}
		COLOR = accum;
	}
}
