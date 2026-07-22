shader_type canvas_item;

// 0.0 means no damage (fully transparent).
// 1.0 means complete damage (show whole crack texture).
// You can use COLOR.a to drive this (e.g., by changing the modulate alpha of the tile/sprite),
// or you can set this uniform directly via code if applied to an individual Sprite2D.
uniform float damage_progress : hint_range(0.0, 1.0) = 0.0;
uniform bool use_color_alpha_as_damage = true;

// Tweak this to control how sharp the transition is from edge to center
uniform float edge_sharpness : hint_range(0.0, 1.0) = 0.2;

// The size of the tile in pixels (used to correctly calculate the center if UV is from an atlas).
// If your crack texture is exactly the size of one tile (e.g. 64x64), this isn't strictly necessary 
// but helps if the texture size changes or if it's packed in an atlas.
uniform vec2 tile_size = vec2(64.0, 64.0);

void fragment() {
	vec4 crack_color = texture(TEXTURE, UV);
	
	// Determine damage progress
	float current_damage = damage_progress;
	if (use_color_alpha_as_damage) {
		current_damage = COLOR.a; // Assume COLOR.a encodes the damage progress
	}
	
	// If no damage, don't show anything
	if (current_damage <= 0.01) {
		COLOR = vec4(0.0);
	} else if (current_damage >= 0.99) {
		// Show full cracks but tinted by the base color if needed
		COLOR = crack_color;
		COLOR.rgb *= COLOR.rgb;
	} else {
		// Calculate local UV for the tile (handles cases where the tile is in an atlas)
		// Assuming the texture size is a multiple of tile_size.
		vec2 texture_size_px = vec2(textureSize(TEXTURE, 0));
		vec2 pixel_pos = UV * texture_size_px;
		vec2 local_uv = mod(pixel_pos, tile_size) / tile_size;
		
		// Distance from the center of the tile
		vec2 center_uv = local_uv * 2.0 - 1.0; // range -1 to 1
		
		// max(abs(x), abs(y)) gives a square distance, fitting tile borders nicely.
		// Use length(center_uv) if you prefer a circular reveal.
		float dist = max(abs(center_uv.x), abs(center_uv.y));
		
		// When damage is 0.0, threshold is > 1.0 (nothing shown).
		// When damage is 1.0, threshold is <= 0.0 (everything shown).
		float reveal_threshold = 1.0 - current_damage;
		
		// Smooth reveal starting from the edges
		float mask = smoothstep(reveal_threshold - edge_sharpness, reveal_threshold + edge_sharpness, dist);
		
		COLOR = crack_color;
		COLOR.a *= mask;
	}
}
