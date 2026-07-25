shader_type canvas_item;
render_mode blend_mix;

// ── Decor overlay: wind sway + grass fringe at the base ──
// One shader for all hand-placed decor, because a CanvasItem has a single
// material slot and trees need both effects at once.
//   * wind_strength = 0   -> rocks, crystals, stumps (fringe only)
//   * wind_strength > 0   -> trees, tall bushes (canopy sways too)
// Grass grows in the bottom band of the sprite's OPAQUE pixels: blades point up,
// curve sideways, vary in length, and the whole edge can bow into an arc.
// Set as_shadow = true on a DUPLICATE of this material for cast shadows, so the
// silhouette stays black instead of showing green grass.

uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform sampler2D gradient_tex : filter_nearest;

// ── Wind (leave strength at 0 for rock-like decor) ──
uniform float wind_strength = 0.0;  // sideways shift in texture pixels
uniform float wind_speed = 1.2;
uniform float wind_scale = 0.004;   // neighbour variation; smaller = more in sync
uniform float root_height = 0.35;   // bottom fraction that never moves

// ── Grass fringe ──
uniform bool grass_enabled = true;
uniform float band_bottom = 1.0;
uniform float band_height = 0.09;   // max blade height (UV fraction)
uniform float arc = 0.0;            // + = dome, - = dip
uniform float blade_freq = 22.0;    // blade density
uniform float blade_thickness = 0.5;// 0..1 : thin stalks .. fat tufts
uniform float length_var = 0.7;     // length variation
uniform float fine_detail = 0.35;   // fine short/tall variation
uniform float bend_amount = 0.9;    // blades curve sideways
uniform float sway_speed = 0.6;
uniform float shadow_tone = 0.15;
uniform float light_tone = 0.55;
uniform float streak_scale = 24.0;
uniform float streak_width = 0.45;
uniform float grass_alpha = 1.0;

// Cast shadows reuse this material; then everything renders as flat black.
uniform bool as_shadow = false;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv = UV;
	bool outside = false;

	// ── Wind: shift the upper part sideways, keep the base planted ──
	if (wind_strength > 0.001) {
		float height = 1.0 - UV.y;
		float bend = clamp((height - root_height) / max(1.0 - root_height, 0.001), 0.0, 1.0);
		bend *= bend;
		float wphase = (world_pos.x + world_pos.y) * wind_scale;
		float shift = sin(TIME * wind_speed + wphase) * wind_strength * bend;
		uv.x += shift / float(textureSize(TEXTURE, 0).x);
		// Nothing to sample outside the sprite — clamping would smear the edge
		// pixel into a streak, so draw nothing there.
		if (uv.x < 0.0 || uv.x > 1.0) {
			outside = true;
		}
	}

	if (outside) {
		COLOR = vec4(0.0);
	} else {
		vec4 tex = texture(TEXTURE, uv);

		// ── Grass fringe along the bottom of the opaque pixels ──
		bool in_band = false;
		vec3 grass = vec3(0.0);
		if (grass_enabled && tex.a > 0.3) {
			float h = clamp((band_bottom - UV.y) / band_height, 0.0, 2.0);

			// Blades lean sideways more the higher up they are, and sway in time.
			float sway = sin(TIME * sway_speed + UV.x * 30.0);
			float lean = texture(noise_tex, vec2(UV.x * blade_freq * 0.5, 0.5)).r - 0.5;
			float bendx = (lean + sway * 0.3) * bend_amount * h * h * band_height;
			float bx = UV.x + bendx;

			// Two noise octaves for blade height: coarse blades + fine detail.
			float coarse = texture(noise_tex, vec2(bx * blade_freq, 0.5)).r;
			float fine = texture(noise_tex, vec2(bx * blade_freq * 3.7, 0.5)).r;
			float profile = clamp(coarse + (fine - 0.5) * fine_detail, 0.0, 1.0);

			// Thickness: keep only the middle slice of each blade's phase.
			float bphase = fract(bx * blade_freq);
			float half_w = clamp(blade_thickness, 0.05, 1.0) * 0.5;
			float blade_mask = step(abs(bphase - 0.5), half_w);

			float this_height = band_height * (1.0 - length_var * (1.0 - profile));
			float arc_off = arc * (1.0 - 4.0 * (UV.x - 0.5) * (UV.x - 0.5));
			float top = band_bottom - this_height - arc_off;

			if (UV.y > top && UV.y < band_bottom && blade_mask > 0.5) {
				in_band = true;
				float diag = (bx + UV.y) * streak_scale - TIME * 0.15;
				float t = (fract(diag) < streak_width) ? light_tone : shadow_tone;
				grass = texture(gradient_tex, vec2(clamp(t, 0.0, 1.0), 0.5)).rgb;
			}
		}

		if (as_shadow) {
			// Silhouette only: grass counts as part of the shape.
			float a = in_band ? grass_alpha : tex.a;
			COLOR = vec4(0.0, 0.0, 0.0, a);
		} else if (in_band) {
			COLOR = vec4(grass, grass_alpha);
		} else {
			COLOR = tex;
		}
	}
}
