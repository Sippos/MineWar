extends Control

signal state_changed(summary: String)

const MAP_SIZE := Vector2i(15, 11)
const CELL_SIZE := 40
const TILE_SOURCE_SIZE := 64
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const BITS: Array[int] = [1, 2, 4, 8]

const BASE_PATH := "res://assets/sprites/world/terrain/bricks/Easy_Brick.png"
const EDGE_PATH := "res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas.png"
const FRONT_PATH := "res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front.png"
const DAMAGE_1_PATH := "res://assets/sprites/world/terrain/damage/First_Hitting.png"
const DAMAGE_2_PATH := "res://assets/sprites/world/terrain/damage/Second_Hitting.png"
const FRONT_DAMAGE_1_PATH := "res://assets/sprites/world/terrain/front_damage/First-Hit-Front.png"
const FRONT_DAMAGE_2_PATH := "res://assets/sprites/world/terrain/front_damage/Next-Hit-Front.png"
const GEM_PATH := "res://assets/sprites/world/terrain/gem_overlays/minewars_buried_gem_overlays_exact_256x128.png"
const SAVE_PATH := "res://tools/sprite_lab/source/terrain_interaction_lab_map.json"

# Tool values are intentionally stable so saved lab maps remain compatible.
enum Tool {
	DIG,
	RESTORE,
	GEM_HINT,
	GEM_REVEALED,
	GEM_RICH,
	DAMAGE,
	CLEAR_DETAIL,
	PLAYER_LIGHT
}

enum LightingMode {
	NEUTRAL,
	MINE,
	PLAYER,
	DARK
}

var current_tool: int = Tool.DIG
var lighting_mode: int = LightingMode.MINE
var show_grid := true
var show_front_walls := true
var show_gems := true
var show_damage := true
var show_cluster_links := true
var shell_mode := true
var use_real_assets := true

var blocks: Dictionary = {}
var gems: Dictionary = {}
var damage: Dictionary = {}
var selected_cell := Vector2i(-1, -1)
var hovered_cell := Vector2i(-1, -1)
var player_light_cell := Vector2i(7, 6)
var dragging := false
var drag_button := MOUSE_BUTTON_LEFT
var last_drag_cell := Vector2i(-1, -1)

var base_texture: Texture2D
var edge_texture: Texture2D
var front_texture: Texture2D
var damage_1_texture: Texture2D
var damage_2_texture: Texture2D
var front_damage_1_texture: Texture2D
var front_damage_2_texture: Texture2D
var gem_texture: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE.x * CELL_SIZE, MAP_SIZE.y * CELL_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_assets()
	apply_template("Starter Tunnel")

func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("Terrain Interaction Lab missing asset: %s" % path)
		return null
	return load(path) as Texture2D

func _load_assets() -> void:
	base_texture = _load_texture(BASE_PATH)
	edge_texture = _load_texture(EDGE_PATH)
	front_texture = _load_texture(FRONT_PATH)
	damage_1_texture = _load_texture(DAMAGE_1_PATH)
	damage_2_texture = _load_texture(DAMAGE_2_PATH)
	front_damage_1_texture = _load_texture(FRONT_DAMAGE_1_PATH)
	front_damage_2_texture = _load_texture(FRONT_DAMAGE_2_PATH)
	gem_texture = _load_texture(GEM_PATH)

func set_tool(value: int) -> void:
	current_tool = clampi(value, Tool.DIG, Tool.PLAYER_LIGHT)
	_emit_state()

func set_lighting_mode(value: int) -> void:
	lighting_mode = clampi(value, LightingMode.NEUTRAL, LightingMode.DARK)
	queue_redraw()
	_emit_state()

func set_option(option_name: String, value: bool) -> void:
	match option_name:
		"grid": show_grid = value
		"fronts": show_front_walls = value
		"gems": show_gems = value
		"damage": show_damage = value
		"links": show_cluster_links = value
		"shell": shell_mode = value
		"assets": use_real_assets = value
	queue_redraw()
	_emit_state()

func _reset_solid() -> void:
	blocks.clear()
	gems.clear()
	damage.clear()
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			blocks[Vector2i(x, y)] = true

func _dig_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if _in_bounds(cell):
			blocks[cell] = false
			gems.erase(cell)
			damage.erase(cell)

func apply_template(template_name: String) -> void:
	_reset_solid()
	match template_name:
		"Solid Mass":
			pass
		"Starter Tunnel":
			_dig_cells([
				Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6),
				Vector2i(8, 5), Vector2i(9, 5), Vector2i(6, 5),
				Vector2i(8, 6), Vector2i(9, 6)
			])
		"Vertical Shaft":
			var shaft: Array[Vector2i] = []
			for y in range(1, MAP_SIZE.y - 1):
				shaft.append(Vector2i(7, y))
				shaft.append(Vector2i(8, y))
			_dig_cells(shaft)
		"Horizontal Tunnel":
			var tunnel: Array[Vector2i] = []
			for x in range(1, MAP_SIZE.x - 1):
				tunnel.append(Vector2i(x, 5))
				tunnel.append(Vector2i(x, 6))
			_dig_cells(tunnel)
		"Large Room":
			var room: Array[Vector2i] = []
			for y in range(3, 8):
				for x in range(3, 12):
					room.append(Vector2i(x, y))
			_dig_cells(room)
		"Staircase":
			var stairs: Array[Vector2i] = []
			for step in range(8):
				stairs.append(Vector2i(3 + step, 2 + step))
				stairs.append(Vector2i(3 + step, 3 + step))
			_dig_cells(stairs)
		"Pillars / Overhang":
			var cave: Array[Vector2i] = []
			for y in range(2, 9):
				for x in range(2, 13):
					cave.append(Vector2i(x, y))
			_dig_cells(cave)
			for p in [Vector2i(5, 4), Vector2i(5, 5), Vector2i(9, 5), Vector2i(9, 6), Vector2i(10, 3)]:
				blocks[p] = true
		"Gem Vein":
			apply_template("Large Room")
			for p in [Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6), Vector2i(3, 2), Vector2i(4, 2)]:
				gems[p] = 2
			gems[Vector2i(2, 5)] = 3
			gems[Vector2i(11, 7)] = 1
		"Motherlode":
			apply_template("Large Room")
			for p in [Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(12, 5), Vector2i(12, 6)]:
				gems[p] = 2
			gems[Vector2i(2, 5)] = 3
			gems[Vector2i(4, 2)] = 3
	selected_cell = Vector2i(-1, -1)
	queue_redraw()
	_emit_state()

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y

func _is_solid(cell: Vector2i) -> bool:
	# Outside the authored test map is treated as solid earth, matching a mine mass.
	if not _in_bounds(cell):
		return true
	return bool(blocks.get(cell, true))

func exposure_mask(cell: Vector2i) -> int:
	if not _is_solid(cell):
		return 0
	var mask := 0
	for index in range(4):
		if not _is_solid(cell + DIRS[index]):
			mask |= BITS[index]
	return mask

func front_connection_state(cell: Vector2i) -> int:
	if not _is_solid(cell) or _is_solid(cell + Vector2i.DOWN):
		return 0
	var state := 0
	var left := cell + Vector2i.LEFT
	var right := cell + Vector2i.RIGHT
	if _is_solid(left) and not _is_solid(left + Vector2i.DOWN):
		state |= 1
	if _is_solid(right) and not _is_solid(right + Vector2i.DOWN):
		state |= 2
	return state

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))

func _projected_front_rect(cell: Vector2i) -> Rect2:
	# Mirrors the live TileSet contract: the wall is authored on the empty cell below
	# and shifted upward by half a tile via texture_origin = (0, 32).
	var below_rect := _cell_rect(cell + Vector2i.DOWN)
	return Rect2(below_rect.position + Vector2(0.0, -CELL_SIZE * 0.5), below_rect.size)

func _lighting_modulate(cell: Vector2i, exposed: bool) -> Color:
	var base := Color.WHITE
	match lighting_mode:
		LightingMode.NEUTRAL:
			base = Color.WHITE
		LightingMode.MINE:
			base = Color(0.60, 0.63, 0.76, 1.0)
		LightingMode.DARK:
			base = Color(0.27, 0.29, 0.40, 1.0)
		LightingMode.PLAYER:
			var distance := Vector2(cell).distance_to(Vector2(player_light_cell))
			var strength := clampf(1.0 - distance / 6.5, 0.0, 1.0)
			base = Color(0.29, 0.31, 0.43, 1.0).lerp(Color(1.05, 0.90, 0.73, 1.0), strength)
	if shell_mode:
		if exposed:
			base *= Color(0.92, 0.92, 1.0, 1.0)
		else:
			# The underground mass itself acts as the occlusion layer.
			base *= Color(0.40, 0.42, 0.53, 1.0)
	return base

func _draw_real_base(cell: Vector2i, rect: Rect2, mask: int) -> void:
	var modulate := _lighting_modulate(cell, mask != 0)
	if base_texture != null:
		draw_texture_rect(base_texture, rect, false, modulate)
	else:
		draw_rect(rect, Color("514967") * modulate)
	if mask != 0 and edge_texture != null:
		var atlas_position := Vector2i(mask % 4, mask / 4) * TILE_SOURCE_SIZE
		draw_texture_rect_region(edge_texture, rect, Rect2(Vector2(atlas_position), Vector2(TILE_SOURCE_SIZE, TILE_SOURCE_SIZE)), modulate)

func _draw_placeholder_base(cell: Vector2i, rect: Rect2, mask: int) -> void:
	var modulate := _lighting_modulate(cell, mask != 0)
	draw_rect(rect, Color("514967") * modulate)
	if mask == 0:
		return
	var edge_color := Color("8e84ad") * modulate
	var shadow_color := Color("242035") * modulate
	if (mask & 1) != 0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5)), shadow_color)
		draw_line(rect.position + Vector2(0, 5), Vector2(rect.end.x, rect.position.y + 5), edge_color, 3)
	if (mask & 2) != 0:
		draw_rect(Rect2(Vector2(rect.end.x - 5, rect.position.y), Vector2(5, rect.size.y)), shadow_color)
		draw_line(Vector2(rect.end.x - 5, rect.position.y), Vector2(rect.end.x - 5, rect.end.y), edge_color, 3)
	if (mask & 4) != 0:
		draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 5), Vector2(rect.size.x, 5)), shadow_color)
	if (mask & 8) != 0:
		draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), shadow_color)
		draw_line(rect.position + Vector2(5, 0), Vector2(rect.position.x + 5, rect.end.y), edge_color, 3)

func _draw_damage_for(cell: Vector2i, rect: Rect2, front := false) -> void:
	if not show_damage:
		return
	var stage := int(damage.get(cell, 0))
	if stage <= 0:
		return
	var texture: Texture2D
	if front:
		texture = front_damage_1_texture if stage == 1 else front_damage_2_texture
	else:
		texture = damage_1_texture if stage == 1 else damage_2_texture
	if use_real_assets and texture != null:
		draw_texture_rect(texture, rect, false, _lighting_modulate(cell, true))
	else:
		var width := 2.0 + float(stage)
		draw_line(rect.position + Vector2(rect.size.x * 0.47, 0), rect.position + Vector2(rect.size.x * 0.38, rect.size.y * 0.35), Color("1d192a"), width)
		draw_line(rect.position + Vector2(rect.size.x * 0.38, rect.size.y * 0.35), rect.position + Vector2(rect.size.x * 0.60, rect.size.y * 0.72), Color("1d192a"), width)
		if stage >= 2:
			draw_line(rect.position + Vector2(rect.size.x * 0.40, rect.size.y * 0.36), rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.52), Color("1d192a"), 2)
		if stage >= 3:
			draw_circle(rect.position + Vector2(rect.size.x * 0.60, rect.size.y * 0.72), 5, Color("171625"))

func _gem_src_rect(frame: int) -> Rect2:
	return Rect2(Vector2((frame % 4) * TILE_SOURCE_SIZE, (frame / 4) * TILE_SOURCE_SIZE), Vector2(TILE_SOURCE_SIZE, TILE_SOURCE_SIZE))

func _draw_gem_frame(frame: int, rect: Rect2, cell: Vector2i) -> void:
	if use_real_assets and gem_texture != null:
		draw_texture_rect_region(gem_texture, rect, _gem_src_rect(frame), _lighting_modulate(cell, true))
	else:
		var center := rect.get_center()
		var size := 3.0 + float(frame == 7) * 3.0
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -size * 2.0),
			center + Vector2(size, -size * 0.2),
			center + Vector2(0, size * 2.0),
			center + Vector2(-size, -size * 0.2)
		]), Color("9b63ff"))

func _draw_gem_on_block(cell: Vector2i, rect: Rect2, mask: int) -> void:
	if not show_gems or not gems.has(cell) or mask == 0:
		return
	var state := clampi(int(gems[cell]), 1, 3)
	if state == 1:
		_draw_gem_frame(6, rect, cell)
		return
	# A standalone block can reveal several faces. Do not suppress side faces just
	# because a front wall is also visible.
	if (mask & 1) != 0:
		_draw_gem_frame(0 if ((cell.x + cell.y) & 1) == 0 else 1, rect, cell)
	if (mask & 8) != 0:
		_draw_gem_frame(2, rect, cell)
	if (mask & 2) != 0:
		_draw_gem_frame(3, rect, cell)
	if state >= 3:
		_draw_gem_frame(7, rect, cell)

func _draw_gem_on_front(cell: Vector2i, rect: Rect2) -> void:
	if not show_gems or not gems.has(cell):
		return
	var state := clampi(int(gems[cell]), 1, 3)
	if state == 1:
		_draw_gem_frame(6, rect, cell)
	elif state == 2:
		_draw_gem_frame(4 if ((cell.x + cell.y) & 1) == 0 else 5, rect, cell)
	else:
		_draw_gem_frame(4 if ((cell.x + cell.y) & 1) == 0 else 5, rect, cell)
		_draw_gem_frame(7, rect, cell)

func _draw_cluster_links() -> void:
	if not show_gems or not show_cluster_links:
		return
	for raw_cell in gems.keys():
		var cell: Vector2i = raw_cell
		if exposure_mask(cell) == 0:
			continue
		for direction_value: Variant in [Vector2i.RIGHT, Vector2i.DOWN]:
			var direction: Vector2i = direction_value
			var neighbor: Vector2i = cell + direction
			if gems.has(neighbor) and exposure_mask(neighbor) != 0:
				var from := _cell_rect(cell).get_center()
				var to := _cell_rect(neighbor).get_center()
				draw_line(from, to, Color(0.52, 0.30, 0.92, 0.45), 5.0)

func _draw() -> void:
	var full_rect := Rect2(Vector2.ZERO, Vector2(MAP_SIZE.x * CELL_SIZE, MAP_SIZE.y * CELL_SIZE))
	draw_rect(full_rect, Color("11101a"))

	# 1. Solid underground mass and exposed shell.
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			if _is_solid(cell):
				var mask := exposure_mask(cell)
				if use_real_assets:
					_draw_real_base(cell, rect, mask)
				else:
					_draw_placeholder_base(cell, rect, mask)
			else:
				# Free tunnel space is readable cave darkness, not a blanket fog tile.
				draw_rect(rect, Color("151925"))

	# 2. Prototype cumulative links sit behind the actual vein art.
	_draw_cluster_links()

	# 3. Projected front walls are drawn into the free cell below their source block.
	if show_front_walls:
		for y in range(MAP_SIZE.y):
			for x in range(MAP_SIZE.x):
				var cell := Vector2i(x, y)
				if not _is_solid(cell) or _is_solid(cell + Vector2i.DOWN):
					continue
				var front_rect := _projected_front_rect(cell)
				if use_real_assets and front_texture != null:
					draw_texture_rect(front_texture, front_rect, false, _lighting_modulate(cell, true))
				else:
					draw_rect(Rect2(front_rect.position, Vector2(front_rect.size.x, front_rect.size.y * 0.42)), Color("4c435f") * _lighting_modulate(cell, true))
					draw_line(front_rect.position + Vector2(0, front_rect.size.y * 0.42), front_rect.position + Vector2(front_rect.size.x, front_rect.size.y * 0.42), Color("242035"), 4)
				_draw_damage_for(cell, front_rect, true)
				_draw_gem_on_front(cell, front_rect)

	# 4. Top/left/right gem faces and block damage remain attached to the solid cell.
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			if not _is_solid(cell):
				continue
			var mask := exposure_mask(cell)
			var rect := _cell_rect(cell)
			_draw_damage_for(cell, rect, false)
			_draw_gem_on_block(cell, rect, mask)

	# 5. Light marker, selection and grid are editor-only diagnostics.
	if lighting_mode == LightingMode.PLAYER:
		var light_center := _cell_rect(player_light_cell).get_center()
		draw_circle(light_center, 8, Color("ffe0a0"))
		draw_circle(light_center, 14, Color(1.0, 0.8, 0.45, 0.55), false, 2)
	if _in_bounds(selected_cell):
		draw_rect(_cell_rect(selected_cell).grow(-2), Color("8eeeff"), false, 3)
	if _in_bounds(hovered_cell):
		draw_rect(_cell_rect(hovered_cell).grow(-5), Color(1, 1, 1, 0.35), false, 1)
	if show_grid:
		for x in range(MAP_SIZE.x + 1):
			var px := float(x * CELL_SIZE)
			draw_line(Vector2(px, 0), Vector2(px, MAP_SIZE.y * CELL_SIZE), Color(0.05, 0.04, 0.08, 0.30), 1)
		for y in range(MAP_SIZE.y + 1):
			var py := float(y * CELL_SIZE)
			draw_line(Vector2(0, py), Vector2(MAP_SIZE.x * CELL_SIZE, py), Color(0.05, 0.04, 0.08, 0.30), 1)

func _cell_from_position(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))

func _apply_tool(cell: Vector2i, button: int) -> void:
	if not _in_bounds(cell):
		return
	selected_cell = cell
	if button == MOUSE_BUTTON_RIGHT:
		# Right-click is a fast local reset: restore the block and clear diagnostics.
		blocks[cell] = true
		gems.erase(cell)
		damage.erase(cell)
		queue_redraw()
		_emit_state()
		return
	match current_tool:
		Tool.DIG:
			blocks[cell] = false
			gems.erase(cell)
			damage.erase(cell)
		Tool.RESTORE:
			blocks[cell] = true
		Tool.GEM_HINT:
			blocks[cell] = true
			gems[cell] = 1
		Tool.GEM_REVEALED:
			blocks[cell] = true
			gems[cell] = 2
		Tool.GEM_RICH:
			blocks[cell] = true
			gems[cell] = 3
		Tool.DAMAGE:
			blocks[cell] = true
			damage[cell] = posmod(int(damage.get(cell, 0)), 3) + 1
		Tool.CLEAR_DETAIL:
			gems.erase(cell)
			damage.erase(cell)
		Tool.PLAYER_LIGHT:
			player_light_cell = cell
	queue_redraw()
	_emit_state()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		hovered_cell = _cell_from_position(motion.position)
		if dragging:
			var cell := _cell_from_position(motion.position)
			if cell != last_drag_cell:
				last_drag_cell = cell
				_apply_tool(cell, drag_button)
		queue_redraw()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT and mouse.button_index != MOUSE_BUTTON_RIGHT:
			return
		if mouse.pressed:
			dragging = true
			drag_button = mouse.button_index
			last_drag_cell = _cell_from_position(mouse.position)
			_apply_tool(last_drag_cell, drag_button)
		else:
			dragging = false
			last_drag_cell = Vector2i(-1, -1)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		dragging = false
		hovered_cell = Vector2i(-1, -1)
		queue_redraw()

func selected_summary() -> String:
	if not _in_bounds(selected_cell):
		return "Select a cell to inspect its exposure mask and projected front-wall state."
	var solid := _is_solid(selected_cell)
	var mask := exposure_mask(selected_cell)
	var gem_state := int(gems.get(selected_cell, 0))
	var damage_state := int(damage.get(selected_cell, 0))
	var front_state := front_connection_state(selected_cell) if solid and not _is_solid(selected_cell + Vector2i.DOWN) else -1
	return "cell %s  •  %s  •  mask %02d [T%d R%d B%d L%d]  •  front %s  •  gem %d  •  damage %d" % [
		str(selected_cell),
		"SOLID" if solid else "TUNNEL",
		mask,
		1 if (mask & 1) != 0 else 0,
		1 if (mask & 2) != 0 else 0,
		1 if (mask & 4) != 0 else 0,
		1 if (mask & 8) != 0 else 0,
		str(front_state) if front_state >= 0 else "none",
		gem_state,
		damage_state
	]

func _emit_state() -> void:
	state_changed.emit(selected_summary())

func save_map() -> Error:
	var block_rows: Array[String] = []
	var gem_entries: Array[Dictionary] = []
	var damage_entries: Array[Dictionary] = []
	for y in range(MAP_SIZE.y):
		var row := ""
		for x in range(MAP_SIZE.x):
			row += "#" if _is_solid(Vector2i(x, y)) else "."
		block_rows.append(row)
	for raw_cell in gems.keys():
		var cell: Vector2i = raw_cell
		gem_entries.append({"x": cell.x, "y": cell.y, "state": int(gems[cell])})
	for raw_cell in damage.keys():
		var cell: Vector2i = raw_cell
		damage_entries.append({"x": cell.x, "y": cell.y, "stage": int(damage[cell])})
	var document := {
		"version": 1,
		"map_size": [MAP_SIZE.x, MAP_SIZE.y],
		"block_rows": block_rows,
		"gems": gem_entries,
		"damage": damage_entries,
		"player_light": [player_light_cell.x, player_light_cell.y]
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document, "  "))
	file.close()
	return OK

func load_map() -> Error:
	if not FileAccess.file_exists(SAVE_PATH):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	var document: Dictionary = parsed
	var rows_value: Variant = document.get("block_rows", [])
	if not rows_value is Array:
		return ERR_INVALID_DATA
	_reset_solid()
	var rows: Array = rows_value
	for y in range(mini(rows.size(), MAP_SIZE.y)):
		var row := String(rows[y])
		for x in range(mini(row.length(), MAP_SIZE.x)):
			blocks[Vector2i(x, y)] = row.substr(x, 1) == "#"
	for entry_value in document.get("gems", []):
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
			if _in_bounds(cell):
				gems[cell] = clampi(int(entry.get("state", 1)), 1, 3)
	for entry_value in document.get("damage", []):
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
			if _in_bounds(cell):
				damage[cell] = clampi(int(entry.get("stage", 1)), 1, 3)
	var light_value: Variant = document.get("player_light", [7, 6])
	if light_value is Array and light_value.size() >= 2:
		player_light_cell = Vector2i(int(light_value[0]), int(light_value[1]))
	queue_redraw()
	_emit_state()
	return OK
