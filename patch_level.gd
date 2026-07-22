extends SceneTree

func _init():
	var file = FileAccess.open("res://scenes/world/mine/level.tscn", FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	if content.find("id=\"tex_edge_unmineable\"") == -1:
		var hard_ext = "[ext_resource type=\"Texture2D\" path=\"res://assets/sprites/world/terrain/dome/Hard_Border_Atlas.png\" id=\"tex_edge_hard\"]"
		var unmineable_ext = hard_ext + "\n[ext_resource type=\"Texture2D\" path=\"res://assets/sprites/world/terrain/dome/Unmineable_Border_Atlas.png\" id=\"tex_edge_unmineable\"]"
		content = content.replace(hard_ext, unmineable_ext)

	if content.find("id=\"Source_edge_unmineable\"") == -1:
		var hard_src = "[sub_resource type=\"TileSetAtlasSource\" id=\"Source_edge_hard\"]\ntexture = ExtResource(\"tex_edge_hard\")\ntexture_region_size = Vector2i(64, 64)\n0:0/0 = 0\n1:0/0 = 0\n2:0/0 = 0\n3:0/0 = 0\n0:1/0 = 0\n1:1/0 = 0\n2:1/0 = 0\n3:1/0 = 0\n0:2/0 = 0\n1:2/0 = 0\n2:2/0 = 0\n3:2/0 = 0\n0:3/0 = 0\n1:3/0 = 0\n2:3/0 = 0\n3:3/0 = 0\n"
		var unmineable_src = hard_src + "\n[sub_resource type=\"TileSetAtlasSource\" id=\"Source_edge_unmineable\"]\ntexture = ExtResource(\"tex_edge_unmineable\")\ntexture_region_size = Vector2i(64, 64)\n0:0/0 = 0\n1:0/0 = 0\n2:0/0 = 0\n3:0/0 = 0\n0:1/0 = 0\n1:1/0 = 0\n2:1/0 = 0\n3:1/0 = 0\n0:2/0 = 0\n1:2/0 = 0\n2:2/0 = 0\n3:2/0 = 0\n0:3/0 = 0\n1:3/0 = 0\n2:3/0 = 0\n3:3/0 = 0\n"
		content = content.replace(hard_src, unmineable_src)

	if content.find("sources/17 = SubResource(\"Source_edge_unmineable\")") == -1:
		var insert_after = "sources/16 = SubResource(\"Source_bedrock\")"
		content = content.replace(insert_after, insert_after + "\nsources/17 = SubResource(\"Source_edge_unmineable\")")

	file = FileAccess.open("res://scenes/world/mine/level.tscn", FileAccess.WRITE)
	file.store_string(content)
	file.close()
	print("Patched level.tscn")
	quit()
