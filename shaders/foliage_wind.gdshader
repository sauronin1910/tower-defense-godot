shader_type canvas_item;

// Sways the top of a plant sideways while the base stays planted. World position
// feeds the phase so neighbouring trees don't bend in lockstep.

uniform float wind_strength = 4.0;   // max sideways shift, in texture pixels
uniform float wind_speed = 1.2;
uniform float wind_scale = 0.004;    // how much neighbours differ; smaller = more in sync
uniform float root_height = 0.35;    // bottom fraction that must not move at all

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float height = 1.0 - UV.y;        // 0 at the bottom of the sprite, 1 at the top
	float bend = clamp((height - root_height) / max(1.0 - root_height, 0.001), 0.0, 1.0);
	bend *= bend;                     // trunk barely moves, canopy moves most

	float phase = (world_pos.x + world_pos.y) * wind_scale;
	float offset = sin(TIME * wind_speed + phase) * wind_strength * bend;

	vec2 uv = UV + vec2(offset / float(textureSize(TEXTURE, 0).x), 0.0);
	// Outside the sprite there's nothing to sample — clamping would smear the
	// edge pixel into a streak, so draw nothing instead.
	if (uv.x < 0.0 || uv.x > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv);
	}
}