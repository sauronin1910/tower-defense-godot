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
uniform float band_scale = 240.0;   // world px between streaks
uniform float shadow_band = 0.10;   // 0..1 width of the shadow stripe
uniform float light_band  = 0.16;   // 0..1 width of the light stripe (first)
uniform vec2 band_dir = vec2(1.0, -1.0); // straight diagonal
uniform float band_speed = 35.0;
void fragment() {
	vec2 world_real = rect_world_origin + UV * rect_world_size;
	vec2 mask_uv = (world_real - mask_world_origin) / mask_world_size;
	if (mask_uv.x < 0.0 || mask_uv.x > 1.0 || mask_uv.y < 0.0 || mask_uv.y > 1.0) {
		discard;
	}
	if (texture(road_mask, mask_uv).r < 0.5) {
		discard;
	}
	// Chunky pixel grid
	vec2 world = floor(world_real / pixel_size) * pixel_size;
	// Band coordinate — straight, but each perpendicular column is nudged by noise
	// so pixel edges look frayed instead of ruler-perfect.
	vec2 dir = normalize(band_dir);
	vec2 perp = vec2(-dir.y, dir.x);
	float across = dot(world, perp);
	float n = texture(noise_tex, vec2(across / 400.0, 0.5)).r;
	float along = dot(world, dir) - TIME * band_speed + (n - 0.5) * fray_amount;
	float phase = fract(along / band_scale); // 0..1 across one cycle
	// Two-tone streak profile across the cycle: light | shadow | (rest = ground)
	// Light comes first, then the shadow edge — no gap between them.
	float light_end2  = light_band;
	float shadow_end2 = light_band + shadow_band;
	// Sample gradient at texel centers: 3 pixels → centers at u = 1/6, 3/6, 5/6
	if (phase < light_end2) {
		vec3 col = texture(gradient_tex, vec2(5.0/6.0, 0.5)).rgb; // rightmost = light first
		COLOR = vec4(col, light_alpha);
	} else if (phase < shadow_end2) {
		vec3 col = texture(gradient_tex, vec2(1.0/6.0, 0.5)).rgb; // leftmost = shadow last
		COLOR = vec4(col, shadow_alpha);
	} else {
		discard;
	}
}
