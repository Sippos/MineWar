extends Node2D

## Draws one editable cave-corner replacement around an empty tile.
## The two shallow cave-color masks remove the square ends of adjacent straight
## borders, then the authored corner frame reconnects them with a curve.

const TILE_SIZE := 64.0
const LOGICAL_SIZE := 32.0
const CORNER_RADIUS := 10.0
const BORDER_MASK_DEPTH := 4.0
const CAVE_COLOR := Color("111725")

var atlas_texture: Texture2D
var atlas_region := Rect2()
var corner_frame := 0

func configure(texture: Texture2D, region: Rect2, frame: int) -> void:
	atlas_texture = texture
	atlas_region = region
	corner_frame = frame
	queue_redraw()

func _draw() -> void:
	if atlas_texture == null:
		return
	var half := TILE_SIZE * 0.5
	var tile_rect := Rect2(Vector2(-half, -half), Vector2(TILE_SIZE, TILE_SIZE))
	var radius := TILE_SIZE * (CORNER_RADIUS / LOGICAL_SIZE)
	var depth := TILE_SIZE * (BORDER_MASK_DEPTH / LOGICAL_SIZE)
	match corner_frame:
		0:
			draw_rect(Rect2(Vector2(-half, -half - depth), Vector2(radius, depth + 1.0)), CAVE_COLOR)
			draw_rect(Rect2(Vector2(-half - depth, -half), Vector2(depth + 1.0, radius)), CAVE_COLOR)
		1:
			draw_rect(Rect2(Vector2(half - radius, -half - depth), Vector2(radius, depth + 1.0)), CAVE_COLOR)
			draw_rect(Rect2(Vector2(half - 1.0, -half), Vector2(depth + 1.0, radius)), CAVE_COLOR)
		2:
			draw_rect(Rect2(Vector2(half - radius, half - 1.0), Vector2(radius, depth + 1.0)), CAVE_COLOR)
			draw_rect(Rect2(Vector2(half - 1.0, half - radius), Vector2(depth + 1.0, radius)), CAVE_COLOR)
		3:
			draw_rect(Rect2(Vector2(-half, half - 1.0), Vector2(radius, depth + 1.0)), CAVE_COLOR)
			draw_rect(Rect2(Vector2(-half - depth, half - radius), Vector2(depth + 1.0, radius)), CAVE_COLOR)
	draw_texture_rect_region(atlas_texture, tile_rect, atlas_region)
