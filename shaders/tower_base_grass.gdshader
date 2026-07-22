shader_type canvas_item;
render_mode blend_mix;

// ── Living grass blades on the tower base — varied length, arc, thickness ──
// Overlay on the tower Sprite2D. Blades grow in the bottom band; they curve
// sideways, vary in length, the whole edge can arc, and blade THICKNESS is
// adjustable (thin stalks vs fat tufts).

uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform sampler2D gradient_tex : filter_nearest;

uniform float band_bottom = 1.0;
uniform float band_height = 0.09;   // max blade height (UV fraction)
uniform float arc = 0.0;            // + = dome, - = dip
uniform float blade_freq = 22.0;    // blade density (more = more, narrower blades)
uniform float blade_thickness = 0.5;// 0..1 : thin stalks .. fat tufts
uniform float length_var = 0.7;     // length variation
uniform float fine_detail = 0.35;   // fine short/tall variation
uniform float bend_amount = 0.9;
uniform float sway_speed = 0.6;
uniform float shadow_tone = 0.15;
uniform float light_tone = 0.55;
uniform float streak_scale = 24.0;
uniform float streak_width = 0.45;
uniform float grass_alpha = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	float h = clamp((band_bottom - UV.y) / band_height, 0.0, 2.0);

	float sway = sin(TIME * sway_speed + UV.x * 30.0);
	float lean = texture(noise_tex, vec2(UV.x * blade_freq * 0.5, 0.5)).r - 0.5;
	float bendx = (lean + sway * 0.3) * bend_amount * h * h * band_height;
	float bx = UV.x + bendx;

	// Blade height field: coarse + fine octaves.
	float coarse = texture(noise_tex, vec2(bx * blade_freq, 0.5)).r;
	float fine   = texture(noise_tex, vec2(bx * blade_freq * 3.7, 0.5)).r;
	float profile = clamp(coarse + (fine - 0.5) * fine_detail, 0.0, 1.0);

	// THICKNESS: turn the smooth profile into blades of controllable width.
	// A per-blade phase 0..1 across each blade; keep only the middle slice whose
	// width = blade_thickness. Thin -> narrow stalks, wide -> fat tufts.
	float phase = fract(bx * blade_freq);
	float half_w = clamp(blade_thickness, 0.05, 1.0) * 0.5;
	float blade_mask = step(abs(phase - 0.5), half_w); // 1 inside blade, 0 in the gap

	float this_height = band_height * (1.0 - length_var * (1.0 - profile));
	float arc_off = arc * (1.0 - 4.0 * (UV.x - 0.5) * (UV.x - 0.5));
	float top = band_bottom - this_height - arc_off;

	bool in_band = (tex.a > 0.3) && (UV.y > top) && (UV.y < band_bottom) && (blade_mask > 0.5);

	if (in_band) {
		float diag = (bx + UV.y) * streak_scale - TIME * 0.15;
		float cyc = fract(diag);
		float t = (cyc < streak_width) ? light_tone : shadow_tone;
		vec3 col = texture(gradient_tex, vec2(clamp(t, 0.0, 1.0), 0.5)).rgb;
		COLOR = vec4(col, grass_alpha);
	} else {
		COLOR = tex;
	}
}
