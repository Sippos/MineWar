@tool
extends McpTestSuite

const GEM_SCRIPT := preload("res://scripts/gameplay/collectibles/gems/gem.gd")
const RAIL_ITEM_SCRIPT := preload("res://scripts/gameplay/collectibles/rail_items/rail_item.gd")
const PLAYER_SCRIPT := preload("res://player.gd")

class FakeCarrier:
	extends CharacterBody2D
	var carried_gems: Array = []

class FakeRailWorld:
	extends Node2D
	var refreshed_cells: Array[Vector2i] = []
	var minecart_refreshes := 0

	func update_rail_autotile(cell: Vector2i) -> void:
		refreshed_cells.append(cell)

	func refresh_minecart_paths() -> void:
		minecart_refreshes += 1

func suite_name() -> String:
	return "collectible_characterization"

func _new_player() -> CharacterBody2D:
	var source := FileAccess.get_file_as_string("res://player.gd")
	var script := GDScript.new()
	script.source_code = source
	assert_eq(script.reload(), OK, "Fresh player.gd source must compile")
	return script.new() as CharacterBody2D

func _make_gem(script: Script) -> RigidBody2D:
	var gem := script.new() as RigidBody2D
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	gem.add_child(sprite)
	var pickup_area := Area2D.new()
	pickup_area.name = "PickupArea"
	gem.add_child(pickup_area)
	return gem

func _make_carrier(scene_root: Node) -> FakeCarrier:
	var carrier := FakeCarrier.new()
	scene_root.add_child(carrier)
	track(carrier)
	return carrier

func _make_rail_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(64, 64)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 15)
	return tile_set

func test_gem_tether_is_exclusive_and_untether_resets_owner() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	assert_false(scene_root == null, "An edited scene is required")
	if scene_root == null:
		return
	var first := _make_carrier(scene_root)
	var second := _make_carrier(scene_root)
	var gem := _make_gem(GEM_SCRIPT)
	scene_root.add_child(gem)
	track(gem)
	gem._ready()

	assert_true(gem.tether_to(first))
	assert_eq(gem.tethered_to, first)
	assert_false(gem.tether_to(second), "A gem already carried by another player must reject pickup")
	assert_eq(gem.tethered_to, first)

	gem.untether()
	assert_eq(gem.tethered_to, null)
	assert_true(gem.freeze)
	assert_eq(gem.linear_velocity, Vector2.ZERO)

func test_gem_carry_slot_comes_from_carrier_order() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	assert_false(scene_root == null, "An edited scene is required")
	if scene_root == null:
		return
	var carrier := _make_carrier(scene_root)
	var first := _make_gem(GEM_SCRIPT)
	var second := _make_gem(GEM_SCRIPT)
	scene_root.add_child(first)
	scene_root.add_child(second)
	track(first)
	track(second)
	carrier.carried_gems = [first, second]
	first.tethered_to = carrier
	second.tethered_to = carrier

	assert_eq(first._get_carry_slot(), 0)
	assert_eq(second._get_carry_slot(), 1)

func test_player_deposit_deletes_gems_but_retains_rail_items() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	assert_false(scene_root == null, "An edited scene is required")
	if scene_root == null:
		return
	var player := _new_player()
	track(player)
	var gem := _make_gem(GEM_SCRIPT)
	var rail_item := _make_gem(RAIL_ITEM_SCRIPT)
	scene_root.add_child(gem)
	scene_root.add_child(rail_item)
	track(gem)
	track(rail_item)
	player.carried_gems = [gem, rail_item]

	var deposited: int = player.deposit_gems()

	assert_eq(deposited, 1)
	assert_true(gem.is_queued_for_deletion(), "Normal gems are consumed by deposit")
	assert_false(rail_item.is_queued_for_deletion(), "Rail items remain carried at the base")
	assert_eq(player.carried_gems.size(), 1)
	assert_eq(player.carried_gems[0], rail_item)

func test_strength_grants_free_carry_allowance_before_overload_penalty() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	assert_false(scene_root == null, "An edited scene is required")
	if scene_root == null:
		return
	var player := _new_player()
	track(player)
	var carried: Array[Node] = []
	for index in range(3):
		var gem := Node.new()
		gem.name = "CarryTestGem%d" % index
		track(gem)
		carried.append(gem)
	player.carried_gems = carried

	player.strength = 1
	assert_eq(player.get_free_carry_allowance(), 1)
	assert_eq(player.get_carry_load(), 3)
	assert_eq(player.get_carry_overload(), 2)
	assert_eq(player.get_weight_penalty(), 0.3)

	player.strength = 4
	assert_eq(player.get_free_carry_allowance(), 2)
	assert_eq(player.get_carry_overload(), 1)
	assert_eq(player.get_weight_penalty(), 0.15)

	player.strength = 7
	assert_eq(player.get_free_carry_allowance(), 3)
	assert_eq(player.get_carry_overload(), 0)
	assert_eq(player.get_weight_penalty(), 0.0)

func test_rail_item_untether_places_tile_and_frees_item() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	assert_false(scene_root == null, "An edited scene is required")
	if scene_root == null:
		return
	var world := FakeRailWorld.new()
	world.name = "World"
	scene_root.add_child(world)
	track(world)

	var rail_layer := TileMapLayer.new()
	rail_layer.name = "RailLayer"
	rail_layer.tile_set = _make_rail_tileset()
	world.add_child(rail_layer)
	var block_layer := TileMapLayer.new()
	block_layer.name = "BlockLayer"
	block_layer.tile_set = TileSet.new()
	block_layer.tile_set.tile_size = Vector2i(64, 64)
	world.add_child(block_layer)

	var item := _make_gem(RAIL_ITEM_SCRIPT)
	world.add_child(item)
	item.global_position = rail_layer.to_global(rail_layer.map_to_local(Vector2i.ZERO))
	item.tethered_to = _make_carrier(scene_root)

	assert_false(item.should_deposit_as_gem())
	item.untether()

	assert_eq(rail_layer.get_cell_source_id(Vector2i.ZERO), 15)
	assert_eq(world.minecart_refreshes, 1)
	assert_true(world.refreshed_cells.has(Vector2i.ZERO))
	assert_true(item.is_queued_for_deletion())
