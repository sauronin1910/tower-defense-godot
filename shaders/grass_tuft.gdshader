shader_type canvas_item;
render_mode blend_mix;

// ── Grass ring around a tower's base ──
// A ring/rim of grass hugging the whole perimeter of the tower base, with a
// trembling outer edge and fuzzy "vusiki" — the same living-edge look as the
// road, but wrapped around the foot of the tower. Drawn on a small ColorRect
// centered on the base, under the sprite, above the shadow.
//
// UV (0..1) maps to the rect; center is the base. The grass forms an elliptical
// ring: dense near a base radius, fading in toward the center and trembling out
// at the edge. The ellipse is squashed vertically (top-down-ish view).

uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform sampler2D gradient_tex : filter_nearest;

uniform float ring_radius = 0.7;    // where the grass ring sits (0..1 of half-size)
uniform float ring_softness = 0.35; // how wide/soft the ring band is
uniform float vertical_ratio = 0.5; // squash the ellipse vertically (<1 = flatter)
uniform float edge_jitter = 0.15;   // vusiki wobble amount
uniform float edge_speed = 0.5;     // wobble drift speed
uniform float edge_scale = 8.0;     // wobble frequency around the ring
uniform float grass_alpha = 1.0;    // opacity
uniform float tone = 0.4;           // gradient tone (0=shadow .. 1=light)

void fragment() {
	// Centered coords, -1..1. Squash Y so the ring is an ellipse seen at an angle.
	vec2 p = (UV - vec2(0.5)) * 2.0;
	p.y /= vertical_ratio;

	float dist = length(p);
	float angle = atan(p.y, p.x); // -PI..PI around the ring

	// Trembling outer boundary: wobble the ring radius by angle + time (vusiki).
	float en = texture(noise_tex, vec2(angle / 6.2831 * edge_scale + TIME * edge_speed, 0.5)).r;
	float outer = ring_radius + (en - 0.5) * edge_jitter;
	float inner = outer - ring_softness;

	// Keep grass only in the ring band [inner .. outer]; discard elsewhere.
	if (dist > outer || dist < inner) {
		discard;
	}

	vec3 col = texture(gradient_tex, vec2(clamp(tone, 0.0, 1.0), 0.5)).rgb;
	COLOR = vec4(col, grass_alpha);
}
