shader_type canvas_item;

// Warm rim on border / front-face tiles near the player.
// Independent of PointLight2D occluders (those block real light on solid cells).
// Only lifts non-dark border pixels so the dark mass interior stays dark.

uniform vec2 player_world_pos = vec2(0.0);
uniform float rim_radius = 220.0;
uniform float rim_strength = 1.25;
uniform vec4 rim_tint : source_color = vec4(1.0, 0.84, 0.55, 1.0);
uniform float dark_cutoff = 0.12; // pixels darker than this stay untouched

varying vec2 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a < 0.01) {
		discard;
	}

	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	// Skip pure dark mass pixels — only rim/speckle/edge art gets the warm lift.
	float edge_mask = smoothstep(dark_cutoff, dark_cutoff + 0.18, luma);

	float d = distance(v_world_pos, player_world_pos);
	float falloff = 1.0 - smoothstep(rim_radius * 0.15, rim_radius, d);
	float boost = falloff * rim_strength * edge_mask * col.a;

	col.rgb = mix(col.rgb, col.rgb * rim_tint.rgb * 1.6, boost * 0.7);
	col.rgb += rim_tint.rgb * boost * 0.28;
	COLOR = col;
}
