shader_type canvas_item;
render_mode blend_mix;
// ── Straight pixelated light streaks with a 2-tone profile ──
// Diagonal bands travel across the grass. Each band is STRAIGHT (no wobble),
// chunky-pixelated, and has two tones across it: a bright highlight then a
// shadow edge — like a hand-shaded pixel-art streak. Road skipped via mask.
uniform sampler2D road_mask : filter_linear;
uniform vec2 mask_world_origin = vec2(-1248.0, -384.0);
uniform vec2 mask_world_size = vec2(4512.0, 2592.0);
uniform vec2 rect_world_origin = vec2(-1248.0, -384.0);
uniform vec2 rect_world_size = vec2(4512.0, 2592.0);
// palette from gradient.png (left=shadow, right=light)
uniform sampler2D gradient_tex : filter_nearest;
uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform float fray_amount = 40.0;
// world-px jitter on streak edges (0 = perfectly straight)
uniform float shadow_alpha = 0.30;
uniform float light_alpha  = 0.34;
uniform float pixel_size = 12.0;    // chunky pixel grid (bigger = blockier)
uniform float band_scale = 240.0;    // world px between streaks (SPACING only now)
uniform float light_width = 60.0;    // world px — thickness of the light stripe
uniform float shadow_width = 12.0;   // world px — thickness of the shadow edge
uniform vec2 band_dir = vec2(1.0, -1.0); // straight diagonal
uniform float band_speed = 35.0;
uniform float bend_amount = 60.0;      // how far streaks curve sideways (world px)
uniform float bend_wavelength = 500.0; // length of one curve (bigger = gentler bend)
// ── Animated (trembling) mask edge ──
uniform float edge_jitter = 0.12;   // how much the edge wobbles (0 = static)
uniform float edge_speed = 0.6;     // wobble speed
uniform float edge_scale = 0.2;    // size of the wobble ripples along the edge
uniform float edge_band_width = 1.3;   // thickness of the dark rim (mask units)
uniform float edge_band_alpha = 1.55;   // darkness of the rim
void fragment() {
	vec2 world_real = rect_world_origin + UV * rect_world_size;
	vec2 mask_uv = (world_real - mask_world_origin) / mask_world_size;
	if (mask_uv.x < 0.0 || mask_uv.x > 1.0 || mask_uv.y < 0.0 || mask_uv.y > 1.0) {
		discard;
	}
	// Living edge: wobble the mask threshold over time with noise so the grass
	// boundary trembles instead of sitting still.
	float en = texture(noise_tex, vec2(
		(world_real.x + world_real.y) * edge_scale + TIME * edge_speed, 0.5)).r;
	float edge_threshold = 0.35 + (en - 0.5) * edge_jitter;
	float mask_val = texture(road_mask, mask_uv).r;
	if (mask_val < edge_threshold) {
		discard;
	}
	bool in_rim = mask_val < edge_threshold + edge_band_width;
	// Chunky pixel grid
	vec2 world = floor(world_real / pixel_size) * pixel_size;
	// Band coordinate — straight, but each perpendicular column is nudged by noise
	// so pixel edges look frayed instead of ruler-perfect.
	vec2 dir = normalize(band_dir);
	vec2 perp = vec2(-dir.y, dir.x);
	float across = dot(world, perp);
	float n = texture(noise_tex, vec2(across / 400.0, 0.5)).r;
	// Gentle wave: bend the streak sideways with a slow sine along its length,
	// so the bands curve organically instead of being ruler-straight.
	float wave = sin(across / bend_wavelength) * bend_amount;
	float along = dot(world, dir) - TIME * band_speed + (n - 0.5) * fray_amount + wave;
	// band_scale = distance between streaks (period). The streak widths below are
	// in absolute world pixels, so changing the spacing no longer changes the
	// streak thickness or the pixel look.
	float cycle = mod(along, band_scale); // 0..band_scale — position within one period
	float light_end2  = light_width;
	float shadow_end2 = light_width + shadow_width;
	// Rim appears ONLY where a light streak meets the road edge (not the whole
	// perimeter): intersection of "in a light streak" AND "at the edge".
	if (cycle < light_end2) {
		if (in_rim) {
			vec3 rim = texture(gradient_tex, vec2(1.0/6.0, 0.5)).rgb; // dark tone
			COLOR = vec4(rim, edge_band_alpha);
		} else {
			vec3 col = texture(gradient_tex, vec2(5.0/6.0, 0.5)).rgb; // light
			COLOR = vec4(col, light_alpha);
		}
	} else if (cycle < shadow_end2) {
		vec3 col = texture(gradient_tex, vec2(1.0/6.0, 0.5)).rgb; // shadow
		COLOR = vec4(col, shadow_alpha);
	} else {
		discard;
	}
}
