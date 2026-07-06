extends SceneTree

func _init():
	var layer = TileMapLayer.new()
	layer.tile_set = TileSet.new()
	layer.tile_set.tile_size = Vector2i(64, 64)
	print("local_to_map(32, 64) = ", layer.local_to_map(Vector2(32, 64)))
	print("local_to_map(32, 63) = ", layer.local_to_map(Vector2(32, 63)))
	quit()
