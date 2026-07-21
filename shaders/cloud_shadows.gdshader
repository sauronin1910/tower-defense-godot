shader_type canvas_item;
render_mode blend_mix;

// ── Cloud shadows ──
// Invisible clouds, visible shadows: a tileable noise texture scrolls slowly
// across the whole map. Where the noise is dark, the ground is dimmed a little;
// where it's light, nothing happens. No cloud is drawn — only its shadow.
// This sits on a full-map ColorRect ABOVE the ground/road, BELOW the towers.

uniform sampler2D cloud_tex : filter_linear, repeat_enable;
uniform vec2 rect_world_origin = vec2(-1248.0, -384.0);
uniform vec2 rect_world_size = vec2(4512.0, 2592.0);

uniform float cloud_scale = 1400.0;   // world px per noise tile (bigger = larger clouds)
uniform vec2  cloud_dir = vec2(1.0, 0.3); // drift direction
uniform float cloud_speed = 12.0;     // world px per second
uniform float shadow_strength = 0.22; // max dimming (0 = none, 1 = black)
uniform float coverage = 0.5;         // noise threshold: higher = fewer/smaller shadows
uniform float softness = 0.25;        // edge softness of the shadow

void fragment() {
	vec2 world = rect_world_origin + UV * rect_world_size;
	vec2 dir = normalize(cloud_dir);
	vec2 uv = (world + dir * TIME * cloud_speed) / cloud_scale;
	float n = texture(cloud_tex, uv).r;

	// Map noise so that dark regions (n < coverage) become shadow. smoothstep
	// gives a soft edge instead of a hard cutoff.
	float shadow = smoothstep(coverage + softness, coverage - softness, n);

	COLOR = vec4(0.0, 0.0, 0.0, shadow * shadow_strength);
}
