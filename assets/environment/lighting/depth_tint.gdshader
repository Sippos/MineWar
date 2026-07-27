shader_type canvas_item;

uniform float biome_depth_start = 1152.0; // Depth 18
uniform float biome_depth_max = 2560.0;   // Depth 40
uniform vec4 biome_tint : source_color = vec4(0.35, 0.38, 0.45, 1.0); // Slate tint

varying vec2 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	
	float depth_factor = clamp((v_world_pos.y - biome_depth_start) / (biome_depth_max - biome_depth_start), 0.0, 1.0);
	
	// Mix towards a darker, slate color
	base_color.rgb = mix(base_color.rgb, base_color.rgb * biome_tint.rgb * 1.8, depth_factor * 0.85);
	
	COLOR = base_color;
}
