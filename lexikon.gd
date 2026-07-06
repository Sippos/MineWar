extends Control

@onready var back_button = $VBoxContainer/TopBar/BackButton
@onready var heroes_grid = $VBoxContainer/ScrollContainer/VBoxContainer/HeroesGrid
@onready var monsters_grid = $VBoxContainer/ScrollContainer/VBoxContainer/MonstersGrid

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	populate_heroes()
	populate_monsters()
	back_button.call_deferred("grab_focus")

func populate_heroes() -> void:
	for hero_name in Global.hero_data.keys():
		var tex_path = Global.hero_data[hero_name]["walk"]
		var is_unlocked = Global.unlocked_heroes.has(hero_name)
		create_entry(heroes_grid, hero_name, tex_path, is_unlocked)

func populate_monsters() -> void:
	for monster_name in Global.monster_data.keys():
		var tex_path = Global.monster_data[monster_name]
		var is_seen = Global.seen_monsters.has(monster_name)
		create_entry(monsters_grid, monster_name, tex_path, is_seen)

func create_entry(parent: Control, name: String, tex_path: String, is_visible: bool) -> void:
	var vbox = VBoxContainer.new()
	parent.add_child(vbox)
	
	var tex_rect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(64, 64)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var tex = load(tex_path)
	if tex:
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		# Assuming 8x8 grid spritesheets
		var frame_width = tex.get_width() / 8
		var frame_height = tex.get_height() / 8
		if frame_width > 0 and frame_height > 0:
			atlas.region = Rect2(0, 0, frame_width, frame_height)
		tex_rect.texture = atlas
		
	if not is_visible:
		tex_rect.modulate = Color(0, 0, 0, 1) # Silhouette
		
	vbox.add_child(tex_rect)
	
	var label = Label.new()
	label.text = name if is_visible else "???"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
