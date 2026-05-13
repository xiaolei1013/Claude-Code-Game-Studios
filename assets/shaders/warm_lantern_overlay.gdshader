// Warm-lantern overlay — soft amber vignette for the cozy register.
//
// Per design/gdd/hd-2d-rendering-pipeline.md OQ-26-2 (warm-lantern overlay
// color grade) + game-concept.md Pillar 4 Visual Identity Anchor: pull the
// screen corners toward an amber warmth, leaving the center neutral. The
// resulting feel is "lantern in a tavern" — soft, warm, intimate.
//
// Sprint 15 N2 preview shader. ADR-0017 §Decision defers the full HD-2D
// pipeline (including tilt-shift DoF) to the Vertical Slice tier; this
// shader ships as ready-to-deploy infrastructure for that work + an opt-in
// preview on the Guild Hall via the WarmLanternOverlay ColorRect.
//
// Usage: attach as ShaderMaterial to a full-rect ColorRect with
// mouse_filter = MOUSE_FILTER_IGNORE and a high z_index so it composites
// on top of the screen content without blocking input. The shader's
// fragment output writes to COLOR alpha; the underlying ColorRect's
// color is replaced entirely — set it to anything.
//
// Performance note: trivial fragment shader (length + smoothstep). Steam
// Deck 1280×800 frame budget per .claude/docs/technical-preferences.md
// is unaffected.

shader_type canvas_item;

// Amber warmth that pulls the corners toward this color. Default is a
// soft incandescent tone (R 1.0, G 0.65, B 0.35) — matches the parchment-
// theme palette's "lantern gold" reward color used by the prestige toast.
uniform vec4 warm_color : source_color = vec4(1.0, 0.65, 0.35, 1.0);

// Inner radius: distance from center (0..~1 corner-to-corner) below which
// no warmth is applied. Lower = more screen tinted; higher = warmth
// confined to corners.
uniform float vignette_radius : hint_range(0.0, 1.0) = 0.55;

// Soft edge from inner radius outward. Larger = smoother falloff.
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.45;

// Multiplier on the final vignette alpha. 0 = invisible, 1 = full warm-
// color punch in the corners. Default 0.35 = subtle cozy bias.
uniform float intensity : hint_range(0.0, 1.0) = 0.35;


void fragment() {
	// Distance from screen center on a 0..~1 scale (corners ≈ 1.0).
	vec2 centered = UV - vec2(0.5);
	float d = length(centered) * 2.0;

	// Soft vignette mask: 0 inside radius, ramps to 1 toward the corners.
	float mask = smoothstep(vignette_radius, vignette_radius + vignette_softness, d);

	// Output the warm color with alpha = mask × intensity × warm_color.a.
	// Center stays fully transparent (no warmth); corners get the warm wash.
	// The underlying screen content composites through cleanly.
	COLOR = vec4(warm_color.rgb, mask * intensity * warm_color.a);
}
