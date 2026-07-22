extends Control

## Dome-style terrain interaction laboratory.
## Paint/dig a block map and preview exposed faces, front walls and resource layers.

const MAP_SIZE := Vector2i(15, 11)
const CELL_SIZE := 32
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const BITS := [1, 2, 4, 8]

enum Mode { DIG, ADD_GEM, DAMAGE }
var mode := Mode.DIG
var blocks: Dictionary = {}
var gems: Dictionary = {}
var damage: Dictionary = {}

func _ready() -> void:
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			blocks[Vector2i(x, y)] = true
	# starter tunnel
	for p in [Vector2i(7,5), Vector2i(8,5), Vector2i(9,5), Vector2i(8,6), Vector2i(8,7)]:
		blocks[p] = false
	queue_redraw()

func _draw() -> void:
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var p := Vector2i(x,y)
			var rect := Rect2(p * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
			if blocks.get(p, false):
				draw_rect(rect, Color("3b3456"))
				var mask := exposure_mask(p)
				if mask != 0:
					draw_exposed(rect, mask)
			else:
				draw_rect(rect, Color("11101a"))
			if gems.has(p):
				draw_circle(rect.get_center(), 5 + gems[p] * 2, Color("9b63ff"))
			if damage.has(p):
				draw_line(rect.position, rect.end, Color("f0d5ff"), damage[p])
			draw_rect(rect, Color("171526"), false, 1)

func exposure_mask(p: Vector2i) -> int:
	var mask := 0
	for i in 4:
		if not blocks.get(p + DIRS[i], true):
			mask |= BITS[i]
	return mask

func draw_exposed(rect: Rect2, mask: int) -> void:
	var c := Color("746b99")
	if mask & 1: draw_line(rect.position, Vector2(rect.end.x, rect.position.y), c, 3)
	if mask & 2: draw_line(Vector2(rect.end.x, rect.position.y), rect.end, c, 3)
	if mask & 4: draw_line(Vector2(rect.position.x, rect.end.y), rect.end, c, 3)
	if mask & 8: draw_line(rect.position, Vector2(rect.position.x, rect.end.y), c, 3)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		apply_at(event.position)

func apply_at(pos: Vector2) -> void:
	var p := Vector2i(pos / CELL_SIZE)
	if not blocks.has(p): return
	match mode:
		Mode.DIG: blocks[p] = false
		Mode.ADD_GEM: gems[p] = gems.get(p,0)+1
		Mode.DAMAGE: damage[p] = min(damage.get(p,0)+1,3)
	queue_redraw()
