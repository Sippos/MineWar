shader_type canvas_item;

// Wall faces ignore PointLight2D / occluder shadows (unshaded).
// Tunnel floor still gets real light + shadow.
// Near the player: dark atlas → lit atlas (borders + stones).
// CanvasModulate still multiplies the whole canvas, so near the player we
// boost slightly to fight the ambient darken.

render_mode unshaded;

uniform vec2 player_world_pos = vec2(0.0);
uniform float rim_radius = 160.0;
uniform float rim_strength = 0.85;
uniform vec4 rim_tint : source_color = vec4(1.0, 0.90, 0.65, 1.0);
// Inverse of typical ambient_tint so lit faces don't stay muddy
uniform float ambient_compensate = 1.18;
uniform vec4 base_ambient : source_color = vec4(0.12, 0.1, 0.15, 1.0);
uniform float biome_depth_start = 1152.0; // Depth 18
uniform float biome_depth_max = 2560.0;   // Depth 40
uniform vec4 biome_tint : source_color = vec4(0.35, 0.38, 0.45, 1.0);

varying vec2 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 dark = texture(TEXTURE, UV);
	if (dark.a < 0.01) {
		discard;
	}

	float d = distance(v_world_pos, player_world_pos);
	float falloff = 1.0 - smoothstep(rim_radius * 0.1, rim_radius, d);
	falloff = clamp(falloff * rim_strength, 0.0, 1.0);

	// Compute edge mask based on the artist's drawn border brightness (luma).
	float luma = dot(dark.rgb, vec3(0.299, 0.587, 0.114));
	float is_edge = smoothstep(0.12, 0.28, luma);

	// Apply a gentle warm glow to the drawn border rim, avoiding blowout
	float edge_boost = falloff * is_edge * dark.a;
	dark.rgb = mix(dark.rgb, dark.rgb * rim_tint.rgb * 1.5, edge_boost * 0.6);
	dark.rgb += rim_tint.rgb * edge_boost * 0.15; 

	vec3 light_color = mix(base_ambient.rgb, vec3(ambient_compensate), falloff);
	dark.rgb *= light_color;

	// Apply depth tint
	float depth_factor = clamp((v_world_pos.y - biome_depth_start) / (biome_depth_max - biome_depth_start), 0.0, 1.0);
	dark.rgb = mix(dark.rgb, dark.rgb * biome_tint.rgb * 1.8, depth_factor * 0.85);

	COLOR = dark;
}
