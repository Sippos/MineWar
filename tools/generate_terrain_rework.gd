extends Node

const LEVEL_PATH := "res://scenes/world/mine/level.tscn"

func _ready() -> void:
	_write("res://assets/environment/ground/blue_mine_ground.svg", _ground_svg())
	_write("res://assets/sprites/world/terrain/bricks/Easy_Brick_Rework.svg", _easy_brick_svg())
	_write("res://assets/sprites/world/terrain/bricks/Medium_Brick_Rework.svg", _medium_brick_svg())
	_write("res://assets/sprites/world/terrain/bricks/Hard_Brick_Rework.svg", _hard_brick_svg())
	_write("res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas_Rework.svg", _edge_atlas_svg("#a49bd7", "#7770a6", "#302d49"))
	_write("res://assets/sprites/world/terrain/edges/Medium_Edge_Atlas_Rework.svg", _edge_atlas_svg("#8e8bbd", "#676486", "#29283b"))
	_write("res://assets/sprites/world/terrain/edges/Hard_Edge_Atlas_Rework.svg", _edge_atlas_svg("#797b9f", "#55566f", "#222330"))
	_write("res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front-Rework.svg", _front_wall_svg("#565078", "#6d6794", "#302d49", "#171625"))
	_write("res://assets/sprites/world/terrain/front_walls/Medium-Brick-Front-Rework.svg", _front_wall_svg("#47455f", "#5e5b78", "#29283b", "#151521"))
	_write("res://assets/sprites/world/terrain/front_walls/Hard-Brick-Front-Rework.svg", _front_wall_svg("#39394d", "#4c4d65", "#222330", "#11121c"))
	_write("res://assets/sprites/world/terrain/damage/First_Hitting_Rework.svg", _damage_svg(false))
	_write("res://assets/sprites/world/terrain/damage/Second_Hitting_Rework.svg", _damage_svg(true))
	_write("res://assets/sprites/world/terrain/front_damage/First-Hit-Front-Rework.svg", _front_damage_svg(false))
	_write("res://assets/sprites/world/terrain/front_damage/Next-Hit-Front-Rework.svg", _front_damage_svg(true))
	_patch_level_scene()
	print("Generated and connected the MineWars terrain rework assets.")
	get_tree().quit(0)

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return
	file.store_string(content)
	file.close()

func _ground_svg() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128" shape-rendering="crispEdges">
<rect width="128" height="128" fill="#465d6b"/>
<path fill="#405562" d="M12 15h18v4h8v7h-5v5H16v-4H9v-7h3zM74 9h21v4h9v8h-6v5H80v-4h-9v-8h3zM43 48h20v4h8v8h-5v5H48v-4h-9v-8h4zM93 55h17v4h8v7h-5v5H97v-4h-8v-7h4zM14 83h21v4h8v8h-6v5H20v-4h-9v-8h3zM61 91h19v4h8v7h-5v6H66v-5h-9v-7h4zM100 99h17v4h7v8h-5v5h-15v-4h-8v-8h4z"/>
<path fill="#536d79" d="M19 18h8v3h-8zm62-5h9v3h-9zM48 52h10v3H48zm51 7h8v3h-8zM21 87h9v3h-9zm47 8h8v3h-8zm39 8h7v3h-7z"/>
<path fill="#6e9294" d="M7 39h3v2H7zm30-7h2v2h-2zm47 2h3v2h-3zm27 8h2v2h-2zM29 67h3v2h-3zm41 7h2v2h-2zm45 5h3v2h-3zM8 111h3v2H8zm41 7h2v2h-2zm43-1h3v2h-3z"/>
<path fill="#354953" d="M0 63h6v2H0zm122 63h6v2h-6zM63 0h2v6h-2zm62 61h3v2h-3z"/>
</svg>"""

func _easy_brick_svg() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="crispEdges">
<rect width="64" height="64" fill="#565078"/>
<path fill="#67618a" d="M7 9h7v4h4v5h-5v3H6v-4H3v-5h4zM35 7h8v4h5v5h-4v4h-8v-3h-5v-6h4zM18 31h9v4h4v5h-5v4h-8v-3h-5v-6h5zM43 35h8v4h5v5h-4v4h-8v-3h-5v-6h4zM6 52h7v3h4v4h-4v3H6v-3H2v-4h4z"/>
<path fill="#77709b" d="M9 11h4v3H9zm28-2h4v3h-4zM20 33h5v3h-5zm25 4h4v3h-4zM8 54h3v2H8z"/>
<path fill="#443f61" d="M24 7h3v2h-3zM54 17h4v2h-4zM4 28h3v2H4zM34 27h4v2h-4zM57 51h3v2h-3zM29 55h4v2h-4z"/>
</svg>"""

func _medium_brick_svg() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="crispEdges">
<rect width="64" height="64" fill="#47455f"/>
<path fill="#56546f" d="M4 7h14v4h5v8h-4v5H7v-4H2v-9h2zM31 4h13v4h7v7h-5v6H34v-4h-6V9h3zM12 31h12v4h6v8h-5v6H14v-4H8v-9h4zM39 29h14v5h6v8h-5v6H42v-4h-7v-9h4zM25 51h13v4h6v7H21v-7h4z"/>
<path fill="#686680" d="M7 9h8v3H7zm27-3h7v3h-7zM15 33h7v3h-7zm27-2h8v3h-8zM28 53h7v3h-7z"/>
<path fill="#343347" d="M22 18h5v2h-5zM52 9h5v2h-5zM2 27h6v2H2zM31 25h4v2h-4zM56 53h5v2h-5zM7 56h5v2H7z"/>
</svg>"""

func _hard_brick_svg() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="crispEdges">
<rect width="64" height="64" fill="#39394d"/>
<path fill="#46475e" d="M0 7h18v5h9v4h12v-5h25v8H45v5H27v-4H11v4H0zM0 33h14v-5h17v5h16v-4h17v8H51v5H33v-4H19v5H0zM0 52h22v-5h17v5h25v8H43v4H20v-4H0z"/>
<path fill="#565870" d="M4 9h11v3H4zm32 5h15v3H36zM17 30h10v3H17zm31 1h12v3H48zM7 54h13v3H7zm34 0h14v3H41z"/>
<path fill="#242532" d="M25 0h3v11h-3zm17 18h3v12h-3zM13 39h3v13h-3zm36 39h3v13h-3z"/>
</svg>"""

func _edge_atlas_svg(highlight: String, middle: String, shadow: String) -> String:
	var parts: PackedStringArray = PackedStringArray(["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"256\" height=\"256\" viewBox=\"0 0 256 256\" shape-rendering=\"crispEdges\">"])
	for index in range(16):
		var ox := (index % 4) * 64
		var oy := (index / 4) * 64
		parts.append("<g transform=\"translate(%d %d)\">" % [ox, oy])
		if index & 1:
			parts.append("<rect x=\"0\" y=\"0\" width=\"64\" height=\"8\" fill=\"%s\"/>" % shadow)
			parts.append("<rect x=\"0\" y=\"0\" width=\"64\" height=\"4\" fill=\"%s\"/>" % highlight)
			parts.append("<rect x=\"8\" y=\"4\" width=\"10\" height=\"3\" fill=\"%s\"/>" % middle)
			parts.append("<rect x=\"36\" y=\"4\" width=\"14\" height=\"3\" fill=\"%s\"/>" % middle)
		if index & 2:
			parts.append("<rect x=\"56\" y=\"0\" width=\"8\" height=\"64\" fill=\"%s\"/>" % shadow)
			parts.append("<rect x=\"60\" y=\"0\" width=\"4\" height=\"64\" fill=\"%s\"/>" % highlight)
			parts.append("<rect x=\"57\" y=\"10\" width=\"3\" height=\"11\" fill=\"%s\"/>" % middle)
			parts.append("<rect x=\"57\" y=\"39\" width=\"3\" height=\"13\" fill=\"%s\"/>" % middle)
		if index & 4:
			parts.append("<rect x=\"0\" y=\"56\" width=\"64\" height=\"8\" fill=\"%s\"/>" % shadow)
			parts.append("<rect x=\"0\" y=\"60\" width=\"64\" height=\"4\" fill=\"%s\"/>" % highlight)
			parts.append("<rect x=\"11\" y=\"57\" width=\"12\" height=\"3\" fill=\"%s\"/>" % middle)
			parts.append("<rect x=\"40\" y=\"57\" width=\"10\" height=\"3\" fill=\"%s\"/>" % middle)
		if index & 8:
			parts.append("<rect x=\"0\" y=\"0\" width=\"8\" height=\"64\" fill=\"%s\"/>" % shadow)
			parts.append("<rect x=\"0\" y=\"0\" width=\"4\" height=\"64\" fill=\"%s\"/>" % highlight)
			parts.append("<rect x=\"4\" y=\"12\" width=\"3\" height=\"10\" fill=\"%s\"/>" % middle)
			parts.append("<rect x=\"4\" y=\"40\" width=\"3\" height=\"12\" fill=\"%s\"/>" % middle)
		if (index & 1) and (index & 8): parts.append("<rect x=\"4\" y=\"4\" width=\"8\" height=\"8\" fill=\"%s\"/>" % middle)
		if (index & 1) and (index & 2): parts.append("<rect x=\"52\" y=\"4\" width=\"8\" height=\"8\" fill=\"%s\"/>" % middle)
		if (index & 4) and (index & 8): parts.append("<rect x=\"4\" y=\"52\" width=\"8\" height=\"8\" fill=\"%s\"/>" % middle)
		if (index & 4) and (index & 2): parts.append("<rect x=\"52\" y=\"52\" width=\"8\" height=\"8\" fill=\"%s\"/>" % middle)
		parts.append("</g>")
	parts.append("</svg>")
	return "\n".join(parts)

func _front_wall_svg(base: String, detail: String, shadow: String, void_color: String) -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="crispEdges">
<rect width="64" height="34" fill="%s"/>
<path fill="%s" d="M0 0h64v4H0zM7 9h10v4h5v5H8v-3H3v-4h4zM34 7h11v4h6v5H38v-3h-7v-4h3zM20 23h10v4h5v5H23v-3h-7v-4h4zM47 22h9v4h5v6H50v-3h-7v-5h4z"/>
<rect y="30" width="64" height="8" fill="%s"/>
<rect y="38" width="64" height="26" fill="%s"/>
<path fill="#0c0c14" d="M0 46h9v18H0zm17-5h10v23H17zm19 8h9v15h-9zm17-6h11v21H53z"/>
</svg>""" % [base, detail, shadow, void_color]

func _damage_svg(heavy: bool) -> String:
	if heavy:
		return """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="crispEdges">
<path fill="#242132" d="M29 0h5v13l7 7v8l9 6v6l14 8v8H51l-8-7h-8l-5-8-9 6-8-3-7 9H0V51l10-12 9-2 7-7-4-9 7-8z"/>
<path fill="#b0a8cf" d="M30 0h2v14l7 7v8l9 6v3l-11-7-7-10-6 10-10 8-2-2 10-10 5-8zM0 53h7l7-9 7 2 8-6 2 3-9 8-8-2-6 9H0z"/>
</svg>"""
	return """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="crispEdges">
<path fill="#292638" d="M31 0h4v15l7 7-3 3-8-8zM18 22h4l5 8-3 3-5-7-8 6-2-3zM45 34h4l5 8-3 3-5-7-8 6-2-3zM24 46h4v18h-4z"/>
<path fill="#aaa3c8" d="M32 0h2v15l6 6-2 2-6-7zM19 23h2l5 7-2 1-5-6-7 5-1-2z"/>
</svg>"""

func _front_damage_svg(heavy: bool) -> String:
	if heavy:
		return """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="crispEdges">
<path fill="#211f2d" d="M29 0h5v10l8 6v7l11 5v7H42l-7-6h-8l-6-7-8 5-8-4-5 6V19l10-7 10 2 9-8z"/>
<path fill="#aaa3c8" d="M30 0h2v11l8 6v6l10 5v3l-12-6-7-9-7 8-9-5-8 6-2-2 10-8 9 5 6-8z"/>
</svg>"""
	return """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="crispEdges">
<path fill="#292638" d="M31 0h4v11l7 6-3 3-8-7zM18 17h4l5 7-3 3-5-6-8 5-2-3zM45 25h4l5 7-3 3-5-6-8 5-2-3z"/>
<path fill="#aaa3c8" d="M32 0h2v11l6 5-2 2-6-6z"/>
</svg>"""

func _patch_level_scene() -> void:
	var text := FileAccess.get_file_as_string(LEVEL_PATH)
	var replacements := {
		"res://assets/sprites/world/terrain/damage/First_Hitting.png": "res://assets/sprites/world/terrain/damage/First_Hitting_Rework.svg",
		"res://assets/sprites/world/terrain/damage/Second_Hitting.png": "res://assets/sprites/world/terrain/damage/Second_Hitting_Rework.svg",
		"res://assets/sprites/world/terrain/bricks/Easy_Brick.png": "res://assets/sprites/world/terrain/bricks/Easy_Brick_Rework.svg",
		"res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas.png": "res://assets/sprites/world/terrain/edges/Easy_Edge_Atlas_Rework.svg",
		"res://assets/sprites/world/terrain/edges/Hard_Edge_Atlas.png": "res://assets/sprites/world/terrain/edges/Hard_Edge_Atlas_Rework.svg",
		"res://assets/sprites/world/terrain/edges/Medium_Edge_Atlas.png": "res://assets/sprites/world/terrain/edges/Medium_Edge_Atlas_Rework.svg",
		"res://assets/sprites/world/terrain/front_damage/First-Hit-Front.png": "res://assets/sprites/world/terrain/front_damage/First-Hit-Front-Rework.svg",
		"res://assets/sprites/world/terrain/front_damage/Next-Hit-Front.png": "res://assets/sprites/world/terrain/front_damage/Next-Hit-Front-Rework.svg",
		"res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front.png": "res://assets/sprites/world/terrain/front_walls/Easy_Brick-Front-Rework.svg",
		"res://assets/sprites/world/terrain/front_walls/Hard-Brick-Front.png": "res://assets/sprites/world/terrain/front_walls/Hard-Brick-Front-Rework.svg",
		"res://assets/sprites/world/terrain/front_walls/Medium-Brick-Front.png": "res://assets/sprites/world/terrain/front_walls/Medium-Brick-Front-Rework.svg",
		"res://assets/sprites/world/terrain/bricks/Hard_Brick.png": "res://assets/sprites/world/terrain/bricks/Hard_Brick_Rework.svg",
		"res://assets/sprites/world/terrain/bricks/Medium_Brick.png": "res://assets/sprites/world/terrain/bricks/Medium_Brick_Rework.svg"
	}
	for old_path: String in replacements:
		text = text.replace(old_path, replacements[old_path])
	_write(LEVEL_PATH, text)
