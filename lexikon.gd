extends Control

func _ready():
	var back_btn = $VBoxContainer/TopBar/BackButton
	if not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
		
	populate_heroes()
	populate_monsters()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://menu.tscn")

func populate_heroes():
	for hero_name in Global.hero_data.keys():
		var is_unlocked = Global.unlocked_heroes.has(hero_name)
		var texture_path = Global.hero_data[hero_name]["walk"]
		var icon = create_icon(texture_path, is_unlocked)
		$VBoxContainer/ScrollContainer/VBoxContainer/HeroesGrid.add_child(icon)

func populate_monsters():
	for monster_name in Global.monster_data.keys():
		var is_seen = Global.seen_monsters.has(monster_name)
		var texture_path = Global.monster_data[monster_name]
		var icon = create_icon(texture_path, is_seen)
		$VBoxContainer/ScrollContainer/VBoxContainer/MonstersGrid.add_child(icon)

func create_icon(texture_path: String, is_revealed: bool) -> Control:
	var tex = load(texture_path)
	var rect = TextureRect.new()
	rect.custom_minimum_size = Vector2(80, 80)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if tex == null:
		return rect
		
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	# Assume 8x8 grid for most spritesheets
	var frame_width = tex.get_width() / 8
	var frame_height = tex.get_height() / 8
	atlas.region = Rect2(0, 0, frame_width, frame_height)
	
	rect.texture = atlas
	
	if not is_revealed:
		rect.modulate = Color(0, 0, 0, 1) # Black silhouette
		
	return rect
