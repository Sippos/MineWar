extends SceneTree
func _init():
	var layer = TileMapLayer.new()
	layer.tile_set = TileSet.new()
	layer.tile_set.tile_size = Vector2i(64, 64)
	var pos = layer.map_to_local(Vector2i(0, 0))
	print("map_to_local(0,0) = ", pos)
	quit()
