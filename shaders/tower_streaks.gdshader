shader_type canvas_item;
render_mode blend_mix;

// ── Light-streak overlay for towers ──
// The same diagonal light streaks that sweep the grass also pass over the tower
// sprite. World position is passed from the vertex stage via a varying — the
// reliable way to get canvas world coords in a canvas_item shader.

uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform float pixel_size = 12.0;
uniform float band_scale = 240.0;
uniform float light_width = 60.0;
uniform vec2 band_dir = vec2(1.0, -1.0);
uniform float band_speed = 35.0;
uniform float fray_amount = 40.0;
uniform float streak_strength = 0.18;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) {
		COLOR = tex;
	} else {
		vec2 world = floor(world_pos / pixel_size) * pixel_size;
		vec2 dir = normalize(band_dir);
		vec2 perp = vec2(-dir.y, dir.x);
		float across = dot(world, perp);
		float n = texture(noise_tex, vec2(across / 400.0, 0.5)).r;
		float along = dot(world, dir) + (n - 0.5) * fray_amount;
		float cycle = mod(along, band_scale);
		vec3 col = tex.rgb;
		if (cycle < light_width) {
			col = mix(tex.rgb, vec3(1.0), streak_strength);
		}
		COLOR = vec4(col, tex.a);
	}
}